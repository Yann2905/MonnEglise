// ============================================================================
//  Edge Function : delete-cloudinary
// ============================================================================
//  Supprime un fichier sur Cloudinary à partir de son public_id.
//  Reçoit : { public_id: "moneglise/xxx/sermons/yyy", resource_type?: "video" }
//
//  Secrets requis :
//    CLOUDINARY_CLOUD_NAME  ← visible sur dashboard Cloudinary
//    CLOUDINARY_API_KEY     ← Settings > API keys
//    CLOUDINARY_API_SECRET  ← idem (SECRET, ne JAMAIS commit)
//
//  Déploiement :
//    supabase functions deploy delete-cloudinary --no-verify-jwt
//    supabase secrets set CLOUDINARY_CLOUD_NAME=dglyns7yi
//    supabase secrets set CLOUDINARY_API_KEY=...
//    supabase secrets set CLOUDINARY_API_SECRET=...
// ============================================================================

const CLOUD_NAME = Deno.env.get("CLOUDINARY_CLOUD_NAME")!;
const API_KEY    = Deno.env.get("CLOUDINARY_API_KEY")!;
const API_SECRET = Deno.env.get("CLOUDINARY_API_SECRET")!;

interface DeleteBody {
  public_id: string;
  resource_type?: "image" | "video" | "raw";
}

/// SHA-1 d'une chaîne (Cloudinary attend SHA-1 hex pour la signature)
async function sha1Hex(input: string): Promise<string> {
  const buffer = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-1", buffer);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, content-type, apikey, x-client-info, x-supabase-auth",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = (await req.json()) as DeleteBody;
    if (!body.public_id) {
      return new Response(
        JSON.stringify({ error: "public_id requis" }),
        { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }
    const resourceType = body.resource_type ?? "video";
    const publicId = body.public_id;
    const timestamp = Math.floor(Date.now() / 1000);

    // Cloudinary signature : SHA-1("public_id=...&timestamp=..." + API_SECRET)
    const toSign = `public_id=${publicId}&timestamp=${timestamp}${API_SECRET}`;
    const signature = await sha1Hex(toSign);

    const form = new FormData();
    form.append("public_id", publicId);
    form.append("timestamp", String(timestamp));
    form.append("api_key", API_KEY);
    form.append("signature", signature);

    const url = `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/${resourceType}/destroy`;
    const res = await fetch(url, { method: "POST", body: form });
    const json = await res.json();

    return new Response(
      JSON.stringify(json),
      { status: res.ok ? 200 : 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
