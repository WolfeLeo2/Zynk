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

        // 3. Verify Caller is Owner
        const { data: callerProfile, error: profileError } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('user_id', user.id)
            .single()

        if (profileError || !callerProfile || callerProfile.role !== 'Owner') {
            throw new Error('Unauthorized: You must be an Owner to reset passwords.')
        }

        const { user_id_to_reset, new_password } = await req.json()

        if (!user_id_to_reset || !new_password) throw new Error('Missing user_id_to_reset or new_password')

        // 4. Verify the Target User belongs to the SAME Tenant
        // We use the admin client to check the target's profile
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { data: targetProfile, error: targetError } = await supabaseAdmin
            .from('profiles')
            .select('tenant_id')
            .eq('user_id', user_id_to_reset)
            .single()

        if (targetError || !targetProfile) throw new Error('Target user not found')

        if (targetProfile.tenant_id !== callerProfile.tenant_id) {
            throw new Error('Unauthorized: Use belongs to a different tenant.')
        }

        // 5. Update the Password
        const { data: updateData, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
            user_id_to_reset,
            { password: new_password }
        )

        if (updateError) throw updateError

        return new Response(
            JSON.stringify({ message: 'Password updated successfully' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error: any) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        )
    }
})
