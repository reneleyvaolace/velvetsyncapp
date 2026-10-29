import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const { email, redirectTo } = await req.json()
    if (!email) {
      return new Response(JSON.stringify({ error: 'email is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const resendApiKey = Deno.env.get('RESEND_API_KEY')!

    if (!resendApiKey) {
      console.error('send-reset-email: RESEND_API_KEY no configurada')
      return new Response(JSON.stringify({ error: 'server_misconfigured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Generar un token de recuperación usando Supabase Auth admin
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    })

    const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: redirectTo || `${Deno.env.get('SUPABASE_URL')}/auth/callback`,
    })

    if (error) {
      console.error('send-reset-email: Supabase error:', error.message)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Enviar el correo usando Resend
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Velvet Sync <onboarding@resend.dev>',
        to: [email],
        subject: 'Restablecer tu contraseña - Velvet Sync',
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Restablecer contraseña</title>
          </head>
          <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0D0D12; color: #FFFFFF;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" style="padding: 40px 20px;">
                  <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #1A1A2E; border-radius: 16px; border: 1px solid #33334D;">
                    <tr>
                      <td align="center" style="padding: 40px 30px 30px 30px;">
                        <h1 style="color: #E91E63; font-size: 28px; margin: 0 0 20px 0; letter-spacing: 2px;">Velvet Sync</h1>
                        <p style="color: #B0B0C0; font-size: 16px; margin: 0 0 30px 0; line-height: 1.5;">Has solicitado restablecer tu contraseña. Haz clic en el botón de abajo para crear una nueva contraseña:</p>
                        <table width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td align="center">
                              <a href="${data?.url || '#'}" style="display: inline-block; background-color: #E91E63; color: #FFFFFF; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: bold; font-size: 16px;">Restablecer contraseña</a>
                            </td>
                          </tr>
                        </table>
                        <p style="color: #808090; font-size: 14px; margin: 30px 0 0 0; line-height: 1.5;">Si no solicitaste este cambio, puedes ignorar este mensaje de forma segura.</p>
                        <p style="color: #808090; font-size: 14px; margin: 10px 0 0 0;">Este enlace expirará en 24 horas.</p>
                      </td>
                    </tr>
                    <tr>
                      <td align="center" style="padding: 20px 30px; border-top: 1px solid #33334D;">
                        <p style="color: #66667A; font-size: 12px;">Velvet Sync - Protocolo Love Spouse 8154</p>
                        <p style="color: #66667A; font-size: 12px;">© 2026 Velvet Sync. Todos los derechos reservados.</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
      }),
    })

    if (!resendResponse.ok) {
      const errorText = await resendResponse.text()
      console.error('send-reset-email: Resend error:', errorText)
      return new Response(JSON.stringify({ error: 'error_enviando_correo', detail: errorText }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const resendData = await resendResponse.json()
    console.log('send-reset-email: Correo enviado a', email, resendData)

    return new Response(JSON.stringify({ success: true, email }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('send-reset-email: error inesperado:', e)
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
