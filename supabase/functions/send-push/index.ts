// ============================================================================
//  Edge Function : send-push
// ============================================================================
//  Reçoit { title, message, user_ids[], data? }
//  → récupère tous les tokens FCM correspondants depuis `device_tokens`
//  → envoie un push via l'API FCM HTTP v1 (par groupes de 500 max)
//
//  Variables d'env requises (à configurer dans Supabase) :
//    FCM_SERVICE_ACCOUNT_JSON   ← contenu JSON complet de la clé privée
//                                  du service account Firebase (à plat).
//                                  Récupère via Firebase Console →
//                                  Project Settings → Service accounts →
//                                  Generate new private key.
//
//  Déploiement :
//    supabase functions deploy send-push --no-verify-jwt
//    supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat sa.json)"
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface SendPushBody {
  title: string;
  message: string;
  user_ids: string[];
  data?: Record<string, string>;
  /** URL relative à ouvrir au clic sur la notif (ex: /admin/absence/abc) */
  link?: string;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!;
// URL absolue de l'icône PWA pour les notifs web (optionnel)
const WEB_PUSH_ICON_URL =
  Deno.env.get("WEB_PUSH_ICON_URL") ??
  "https://moneglise-ios.vercel.app/icons/icon-192.png";

const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ─── Helpers OAuth2 (Service Account → Bearer token pour FCM HTTP v1) ───
async function getAccessToken(): Promise<{ token: string; projectId: string }> {
  const sa = JSON.parse(SERVICE_ACCOUNT_JSON);
  const now = getNumericDate(0);
  const exp = getNumericDate(60 * 50); // 50 min

  // Convertit la clé PEM en CryptoKey
  const pem = sa.private_key as string;
  const pkcs8 = pemToBinary(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp,
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`OAuth2 failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  return { token: json.access_token, projectId: sa.project_id };
}

function pemToBinary(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr.buffer;
}

// ─── Handler HTTP ───
Deno.serve(async (req) => {
  console.log(`🚀 incoming ${req.method} request`);
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, content-type, apikey, x-client-info, x-supabase-auth",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = (await req.json()) as SendPushBody;
    console.log("📥 send-push body:", JSON.stringify(body));

    if (!body.title || !body.message || !Array.isArray(body.user_ids)) {
      console.error("❌ Invalid payload");
      return new Response(JSON.stringify({ error: "Invalid payload" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // 1. Récupère tous les tokens des destinataires
    const { data: tokens, error } = await supa
      .from("device_tokens")
      .select("token")
      .in("user_id", body.user_ids);

    console.log(`🔍 tokens lookup: found=${tokens?.length ?? 0}, error=${error?.message ?? "none"}`);

    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      console.log("⚠️ no tokens for user_ids:", body.user_ids);
      return new Response(JSON.stringify({ sent: 0, reason: "no_tokens" }), {
        status: 200,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // 2. Récupère le bearer FCM
    const { token: accessToken, projectId } = await getAccessToken();
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // Lien à embarquer (fallback /) → utilisé par le SW pour deep-link
    const link = body.link || "/";

    // 3. Envoie 1 message par token (HTTP v1 ne supporte plus le multicast)
    const results = await Promise.allSettled(
      tokens.map((t) =>
        fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: {
                title: body.title,
                body: body.message,
              },
              // FCM exige des strings pour data — on coerce
              // On ajoute le link dans data pour que tous les clients (Android natif,
              // iOS natif, Web SW) puissent le récupérer.
              data: Object.fromEntries(
                Object.entries({ ...(body.data ?? {}), link }).map(([k, v]) => [
                  k,
                  String(v),
                ]),
              ),
              android: {
                priority: "HIGH",
                notification: {
                  channel_id: "moneglise_default",
                  default_sound: true,
                  click_action: link, // deep-link Android natif
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    "mutable-content": 1,
                    // iOS native badge — +1 à chaque notif reçue
                    badge: 1,
                  },
                },
              },
              webpush: {
                headers: { TTL: "86400", Urgency: "high" },
                notification: {
                  icon: WEB_PUSH_ICON_URL,
                  badge: WEB_PUSH_ICON_URL,
                  vibrate: [200, 100, 200],
                  requireInteraction: false,
                },
                fcm_options: { link }, // fallback navigation pour le SW Firebase
              },
            },
          }),
        }).then(async (r) => ({
          ok: r.ok,
          status: r.status,
          body: r.ok ? null : await r.text(),
          token: t.token,
        })),
      ),
    );

    let sent = 0;
    const invalidTokens: string[] = [];
    for (const r of results) {
      if (r.status === "fulfilled") {
        if (r.value.ok) {
          sent++;
        } else if (
          r.value.status === 404 ||
          r.value.status === 400 ||
          (r.value.body ?? "").includes("NOT_FOUND") ||
          (r.value.body ?? "").includes("UNREGISTERED")
        ) {
          invalidTokens.push(r.value.token);
        }
      }
    }

    // 4. Cleanup : supprime les tokens invalides (UNREGISTERED)
    if (invalidTokens.length > 0) {
      await supa.from("device_tokens").delete().in("token", invalidTokens);
    }

    return new Response(
      JSON.stringify({
        sent,
        total: tokens.length,
        invalid_removed: invalidTokens.length,
      }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("💥 send-push crash:", String(e), (e as Error)?.stack);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
