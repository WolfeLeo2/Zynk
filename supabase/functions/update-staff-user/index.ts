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
      data: { user: caller },
    } = await supabaseClient.auth.getUser()

    if (!caller) throw new Error('Not authenticated')

    // 3. Verify they are an Owner
    const { data: callerProfile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('*')
      .eq('user_id', caller.id)
      .single()

    if (profileError || !callerProfile) throw new Error('Profile not found')

    if (callerProfile.role !== 'Owner') {
      throw new Error('Unauthorized: You must be an Owner to update staff metadata.')
    }

    // 4. Initialize Admin Client (Service Role)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const {
      user_id,
      name,
      branch_id,
      branch_ids,
      role,
    } = await req.json()

    if (!user_id) throw new Error('Missing target user_id')

    // 5. Update ONLY Auth Metadata
    // We let the client handle the 'profiles' and 'profile_branches' tables 
    // via PowerSync to avoid duplicate key conflicts during sync.
    const { error: authUpdateError } = await supabaseAdmin.auth.admin.updateUserById(
      user_id,
      {
        user_metadata: {
          role: role || 'Cashier',
          display_name: name,
        },
        app_metadata: {
          role: role || 'Cashier',
          branch_id: branch_id,
          branch_ids: branch_ids,
        },
      }
    )

    if (authUpdateError) throw authUpdateError

    return new Response(
      JSON.stringify({ message: 'Staff auth metadata updated successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
