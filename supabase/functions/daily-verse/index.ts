// ============================================================================
//  Edge Function : daily-verse
// ============================================================================
//  Envoie une notification "Verset du jour" à tous les utilisateurs
//  (1× par jour le matin via cron-job.org).
//
//  Variables d'env :
//    BACKUP_SECRET (réutilisé pour protéger l'endpoint)
//
//  Déploiement :
//    supabase functions deploy daily-verse --no-verify-jwt
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SECRET = Deno.env.get("BACKUP_SECRET") ?? "";

const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Mêmes versets que dans le composant DailyVerse côté client
const VERSES = [
  { ref: 'Jean 3:16', text: "Car Dieu a tant aimé le monde qu'il a donné son Fils unique." },
  { ref: 'Psaumes 23:1', text: "L'Éternel est mon berger : je ne manquerai de rien." },
  { ref: 'Philippiens 4:13', text: 'Je puis tout par celui qui me fortifie.' },
  { ref: 'Romains 8:28', text: 'Toutes choses concourent au bien de ceux qui aiment Dieu.' },
  { ref: 'Proverbes 3:5', text: "Confie-toi en l'Éternel de tout ton cœur." },
  { ref: 'Jérémie 29:11', text: "Je connais les projets que j'ai formés sur vous, projets de paix." },
  { ref: 'Ésaïe 41:10', text: "Ne crains rien, car je suis avec toi." },
  { ref: 'Matthieu 11:28', text: 'Venez à moi, vous tous qui êtes fatigués, je vous donnerai du repos.' },
  { ref: 'Psaumes 46:1', text: 'Dieu est pour nous un refuge et un appui.' },
  { ref: '1 Corinthiens 13:4', text: 'La charité est patiente, elle est pleine de bonté.' },
  { ref: 'Galates 5:22', text: 'Le fruit de l\'Esprit, c\'est l\'amour, la joie, la paix.' },
  { ref: 'Hébreux 11:1', text: 'La foi est une ferme assurance des choses qu\'on espère.' },
  { ref: 'Apocalypse 21:4', text: 'Il essuiera toute larme de leurs yeux.' },
  { ref: 'Psaumes 27:1', text: "L'Éternel est ma lumière et mon salut." },
  { ref: 'Matthieu 5:16', text: 'Que votre lumière luise devant les hommes.' },
  { ref: 'Romains 12:12', text: 'Réjouissez-vous en espérance. Persévérez dans la prière.' },
  { ref: 'Éphésiens 2:8', text: "C'est par la grâce que vous êtes sauvés." },
  { ref: 'Psaumes 119:105', text: 'Ta parole est une lampe à mes pieds.' },
  { ref: 'Jean 14:27', text: 'Je vous laisse la paix, je vous donne ma paix.' },
  { ref: 'Romains 15:13', text: "Que le Dieu de l'espérance vous remplisse de joie et de paix." },
  { ref: 'Psaumes 34:18', text: "L'Éternel est près de ceux qui ont le cœur brisé." },
  { ref: 'Matthieu 6:33', text: 'Cherchez premièrement le royaume de Dieu.' },
  { ref: 'Psaumes 37:4', text: "Fais de l'Éternel tes délices." },
  { ref: 'Romains 5:8', text: 'Christ est mort pour nous pendant que nous étions encore pécheurs.' },
  { ref: 'Colossiens 3:23', text: 'Tout ce que vous faites, faites-le de bon cœur, comme pour le Seigneur.' },
  { ref: 'Matthieu 7:7', text: 'Demandez, et l\'on vous donnera ; cherchez, et vous trouverez.' },
  { ref: 'Ésaïe 40:31', text: "Ceux qui se confient en l'Éternel renouvellent leur force." },
];

function getTodayVerse() {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now.getTime() - start.getTime()) / 86_400_000);
  return VERSES[dayOfYear % VERSES.length];
}

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  if (!SECRET || url.searchParams.get("secret") !== SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: cors });
  }

  try {
    const v = getTodayVerse();
    const title = '📖 Verset du jour';
    const message = `« ${v.text} » — ${v.ref}`;

    // Récupère tous les users
    const { data: users } = await supa.from("users").select("id");
    const ids = ((users as { id: string }[] | null) ?? []).map((u) => u.id);
    if (!ids.length) return new Response(JSON.stringify({ ok: true, sent: 0 }), { headers: cors });

    // Insert notifs (DB)
    const rows = ids.map((rid) => ({
      title,
      message,
      type: "system",
      sender_id: ids[0], // arbitraire — pas de "sender" pour ce système
      receiver_id: rid,
      is_read: false,
      metadata: { kind: "daily_verse", reference: v.ref },
    }));
    await supa.from("notifications").insert(rows);

    // Push via send-push
    try {
      await supa.functions.invoke("send-push", {
        body: { title, message, user_ids: ids, data: { type: "daily_verse" } },
      });
    } catch (e) {
      console.warn("send-push from daily-verse failed:", e);
    }

    return new Response(JSON.stringify({ ok: true, verse: v, sent: ids.length }), {
      status: 200,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
