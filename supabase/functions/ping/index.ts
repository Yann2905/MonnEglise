// ============================================================================
//  Edge Function : ping
// ============================================================================
//  Endpoint public qui :
//   1. Touche la DB (SELECT léger sur churches)
//   2. Renvoie 200 OK
//
//  Objectif : être pingée régulièrement par UptimeRobot (toutes les 5 min)
//  pour empêcher Supabase de mettre la DB en pause sur le free tier.
//
//  Déploiement :
//    supabase functions deploy ping --no-verify-jwt
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

Deno.serve(async (_req) => {
  try {
    // SELECT minimal pour réveiller la DB
    const { error } = await supa.from("churches").select("id").limit(1);
    if (error) throw error;
    return new Response(
      JSON.stringify({ ok: true, ts: new Date().toISOString() }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    // Même en cas d'erreur DB, on renvoie 200 — l'objectif est juste de
    // garder UptimeRobot content + d'avoir essayé de toucher la DB.
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
