import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Initialize Client with User's Auth Context
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // 2. Get the Current User (The Caller)
    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) throw new Error('Not authenticated')

    // 3. Verify they are an 'Owner' or 'Manager' (Managers might need to create Cashiers)
    // For now, let's restrict to 'Owner' for high security, or 'Manager' if PRD allows.
    // PRD says: "Owner: Full access. Can invite staff." "Manager: ...cannot delete shop." 
    // Implicitly Managers might need to manage staff? Let's stick to Owner for now based on strict interpretation.
    const { data: callerProfile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('*')
      .eq('user_id', user.id)
      .single()

    if (profileError || !callerProfile) throw new Error('Profile not found')

    if (callerProfile.role !== 'Owner') {
      throw new Error('Unauthorized: You must be an Owner to create staff.')
    }

    // 4. Initialize Admin Client (Service Role) to create the new user
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email, name, branch_id, role, phone, address } = await req.json()

    if (!email || !name) throw new Error('Missing required fields: email, name')

    // 5. Invite the User via Email
    const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      email,
      {
        data: {
          tenant_id: callerProfile.tenant_id,
          role: role || 'Cashier',
          display_name: name
        }
      }
    )

    if (inviteError) throw inviteError

    const newUserId = inviteData.user.id;

    // 6. Create Profile for the new user
    const { error: insertError } = await supabaseAdmin
      .from('profiles')
      .insert({
        user_id: newUserId,
        tenant_id: callerProfile.tenant_id,
        branch_id: branch_id || callerProfile.branch_id,
        role: role || 'Cashier',
        display_name: name,
        phone,
        address
      })

    if (insertError) {
      // Rollback: Delete the user if profile creation fails to prevent orphan users
      await supabaseAdmin.auth.admin.deleteUser(newUserId)
      throw new Error('Failed to create profile: ' + insertError.message)
    }

    return new Response(
      JSON.stringify({ user: inviteData.user, message: 'Staff invited successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
