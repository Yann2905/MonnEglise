// ============================================================================
//  Edge Function : backup-db
// ============================================================================
//  Backup quotidien de toutes les tables métier vers Supabase Storage.
//  • Dump JSON de chaque table
//  • Upload dans le bucket privé "backups" sous backup-YYYY-MM-DD.json
//  • Cleanup automatique des fichiers > 30 jours
//  • Protégé par un secret pour éviter les déclenchements anonymes
//
//  Variables d'env à configurer (Supabase Dashboard → Edge Functions → Secrets) :
//    BACKUP_SECRET = un mot de passe long et aléatoire (ex: 64 chars)
//
//  Déploiement :
//    supabase functions deploy backup-db --no-verify-jwt
//    supabase secrets set BACKUP_SECRET="long-random-secret-here"
//
//  Pour déclencher manuellement (ou via cron-job.org) :
//    curl "https://[ref].supabase.co/functions/v1/backup-db?secret=XYZ"
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BACKUP_SECRET = Deno.env.get("BACKUP_SECRET") ?? "";

const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Tables à sauvegarder (ordre important pour restauration : pas de FK violation)
const TABLES = [
  "churches",
  "users",
  "families",
  "family_members",
  "services",
  "sermons",
  "attendance",
  "absences",
  "notifications",
  "device_tokens",
];

const BUCKET = "backups";
const RETENTION_DAYS = 30;

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // ─── Authentification par secret ───
  const url = new URL(req.url);
  const providedSecret = url.searchParams.get("secret") ?? req.headers.get("x-backup-secret");
  if (!BACKUP_SECRET || providedSecret !== BACKUP_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const startedAt = Date.now();
  console.log("🗄️ backup-db start");

  try {
    // ─── 1. Dump toutes les tables ───
    const dump: Record<string, any[]> = {};
    const counts: Record<string, number> = {};

    for (const table of TABLES) {
      const { data, error } = await supa.from(table).select("*");
      if (error) {
        console.error(`❌ ${table}: ${error.message}`);
        dump[table] = [];
        counts[table] = 0;
      } else {
        dump[table] = data ?? [];
        counts[table] = data?.length ?? 0;
        console.log(`✓ ${table}: ${counts[table]} rows`);
      }
    }

    const payload = {
      version: 1,
      created_at: new Date().toISOString(),
      counts,
      tables: dump,
    };

    const json = JSON.stringify(payload);
    const sizeKb = Math.round(json.length / 1024);
    console.log(`📦 dump size: ${sizeKb} KB`);

    // ─── 2. Upload vers Storage ───
    const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const filename = `backup-${date}.json`;
    const { error: uploadError } = await supa.storage
      .from(BUCKET)
      .upload(filename, json, {
        contentType: "application/json",
        upsert: true, // remplace si même jour
      });
    if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);
    console.log(`✓ uploaded ${filename}`);

    // ─── 3. Cleanup fichiers > RETENTION_DAYS ───
    const { data: files } = await supa.storage.from(BUCKET).list("", { limit: 1000 });
    const cutoff = Date.now() - RETENTION_DAYS * 86_400_000;
    const toDelete: string[] = [];
    for (const f of files ?? []) {
      const ts = new Date(f.created_at ?? 0).getTime();
      if (ts < cutoff) toDelete.push(f.name);
    }
    let deleted = 0;
    if (toDelete.length > 0) {
      const { error: delError } = await supa.storage.from(BUCKET).remove(toDelete);
      if (!delError) deleted = toDelete.length;
      console.log(`🧹 deleted ${deleted} old backup(s)`);
    }

    const durationMs = Date.now() - startedAt;
    return new Response(
      JSON.stringify({
        ok: true,
        filename,
        size_kb: sizeKb,
        counts,
        retention_days: RETENTION_DAYS,
        deleted_old: deleted,
        duration_ms: durationMs,
      }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("💥 backup-db crash:", String(e));
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
