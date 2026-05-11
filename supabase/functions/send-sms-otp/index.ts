/**
 * ────────────────────────────────────────────────────────────────────────────
 * EDGE FUNCTION : send-sms-otp
 * ────────────────────────────────────────────────────────────────────────────
 * Hook Supabase "Send SMS Hook" — appelé par Supabase Auth quand il veut
 * envoyer un SMS d'OTP (à la place de Twilio).
 *
 * Reçoit en POST un payload signé :
 *   {
 *     user: { id, phone, ... },
 *     sms:  { otp, phone, ... }
 *   }
 *
 * On envoie le SMS via le provider local (LeTexto / Allo SMS CI / etc.) et
 * on retourne 200. Si le provider échoue → 500 et Supabase retournera
 * l'erreur à l'app.
 *
 * Variables d'env à définir (Dashboard → Edge Functions → Secrets) :
 *   SEND_SMS_HOOK_SECRET  — fourni par Supabase quand tu actives le hook
 *   SMS_PROVIDER          — 'letexto' | 'africastalking' | 'generic'
 *   SMS_API_KEY           — clé API du provider
 *   SMS_API_USER          — username / app id (selon provider)
 *   SMS_FROM              — sender ID (ex: 'MonEglise', max 11 caractères)
 * ────────────────────────────────────────────────────────────────────────────
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0'

// ── ENV ─────────────────────────────────────────────────────────────────────
const HOOK_SECRET    = Deno.env.get('SEND_SMS_HOOK_SECRET') ?? ''
const SMS_PROVIDER   = Deno.env.get('SMS_PROVIDER')         ?? 'letexto'
const SMS_API_KEY    = Deno.env.get('SMS_API_KEY')          ?? ''
const SMS_API_USER   = Deno.env.get('SMS_API_USER')         ?? ''
const SMS_FROM       = Deno.env.get('SMS_FROM')             ?? 'MonEglise'

// ── HANDLER ─────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  const rawPayload = await req.text()
  const headers    = Object.fromEntries(req.headers)

  // 1. Vérifier la signature du hook (sécurité)
  let body: HookPayload
  try {
    const cleanSecret = HOOK_SECRET.replace('v1,whsec_', '')
    const wh = new Webhook(cleanSecret)
    body = wh.verify(rawPayload, headers) as HookPayload
  } catch (e) {
    console.error('❌ Signature invalide :', e)
    return json({ error: 'invalid_signature' }, 401)
  }

  const phone = body.user?.phone || body.sms?.phone
  const otp   = body.sms?.otp
  if (!phone || !otp) {
    return json({ error: 'missing_phone_or_otp' }, 400)
  }

  const message = `MonEglise : Votre code de vérification est ${otp}. Ne le partagez pas. Valide 10 min.`

  // 2. Envoyer via le provider configuré
  try {
    switch (SMS_PROVIDER) {
      case 'letexto':         await sendViaLeTexto(phone, message); break
      case 'africastalking':  await sendViaAfricasTalking(phone, message); break
      case 'generic':         await sendViaGeneric(phone, message); break
      default:
        return json({ error: `provider_unknown:${SMS_PROVIDER}` }, 500)
    }
    console.log(`✅ SMS OTP envoyé à ${phone} via ${SMS_PROVIDER}`)
    return json({}, 200)
  } catch (e) {
    console.error('❌ Erreur envoi SMS :', e)
    return json(
      { error: { http_code: 500, message: `Échec envoi SMS : ${e}` } },
      500,
    )
  }
})

// ── PROVIDERS ───────────────────────────────────────────────────────────────

/**
 * LeTexto — https://www.letexto.com (API REST documentée).
 * Adapte l'URL et le format selon la doc actuelle reçue à l'inscription.
 */
async function sendViaLeTexto(phone: string, message: string) {
  const res = await fetch('https://api.letexto.com/v1/sms/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SMS_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      from:       SMS_FROM,
      to:         phone,            // format international +225...
      message:    message,
    }),
  })
  if (!res.ok) {
    const txt = await res.text()
    throw new Error(`LeTexto ${res.status} : ${txt}`)
  }
}

/**
 * Africa's Talking — https://africastalking.com (sandbox + prod).
 */
async function sendViaAfricasTalking(phone: string, message: string) {
  const res = await fetch(
    'https://api.africastalking.com/version1/messaging',
    {
      method: 'POST',
      headers: {
        'apiKey':       SMS_API_KEY,
        'Accept':       'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        username: SMS_API_USER,
        to:       phone,
        message,
        from:     SMS_FROM,
      }),
    },
  )
  if (!res.ok) {
    const txt = await res.text()
    throw new Error(`AT ${res.status} : ${txt}`)
  }
}

/**
 * Generic — pour n'importe quelle API REST simple. Adapte selon ton provider.
 * Ex : Allo SMS CI, Bigmover, ou ton provider local.
 */
async function sendViaGeneric(phone: string, message: string) {
  const res = await fetch('https://API_DE_TON_PROVIDER/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SMS_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      sender:    SMS_FROM,
      recipient: phone,
      text:      message,
    }),
  })
  if (!res.ok) {
    const txt = await res.text()
    throw new Error(`Generic ${res.status} : ${txt}`)
  }
}

// ── HELPERS ─────────────────────────────────────────────────────────────────
function json(data: unknown, status: number) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// ── TYPES ───────────────────────────────────────────────────────────────────
type HookPayload = {
  user?: { id: string; phone?: string }
  sms?:  { otp: string; phone: string; sms_type?: string }
}
