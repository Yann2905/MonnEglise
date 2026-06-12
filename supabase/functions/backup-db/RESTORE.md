# Restaurer un backup MonÉglise

## 1. Télécharger un backup

Va sur Supabase Dashboard → Storage → bucket `backups`. Tu vois la liste
`backup-YYYY-MM-DD.json`. Clique → Download.

## 2. Restauration

Le fichier JSON contient :
```json
{
  "version": 1,
  "created_at": "2026-06-11T18:00:00Z",
  "counts": { "users": 42, "families": 8, ... },
  "tables": {
    "churches": [...],
    "users": [...],
    "families": [...],
    ...
  }
}
```

### Option A — Restauration complète (perte de données entre le backup et maintenant)

⚠️ **Cette option efface les données actuelles.** À utiliser uniquement
si la DB est compromise (suppression accidentelle massive, corruption, etc.).

1. Charge le JSON dans un éditeur (VSCode)
2. Dans Supabase SQL Editor, exécute dans l'ordre :

```sql
-- ⛔ DANGER : efface tout
TRUNCATE
  device_tokens, notifications, absences, attendance,
  sermons, services, family_members, families, users, churches
RESTART IDENTITY CASCADE;
```

3. Pour chaque table dans l'ordre du fichier (`churches` → `users` → ...),
   utilise un script Node ou Python qui fait :

```js
import { createClient } from '@supabase/supabase-js';
const supa = createClient(URL, SERVICE_ROLE_KEY);

const backup = JSON.parse(fs.readFileSync('backup-2026-06-11.json', 'utf8'));
for (const table of ['churches','users','families','family_members',
                     'services','sermons','attendance','absences',
                     'notifications','device_tokens']) {
  const rows = backup.tables[table];
  if (rows.length === 0) continue;
  // Insert par batch de 500
  for (let i = 0; i < rows.length; i += 500) {
    const batch = rows.slice(i, i + 500);
    const { error } = await supa.from(table).insert(batch);
    if (error) console.error(table, error.message);
  }
  console.log(`✓ ${table}: ${rows.length}`);
}
```

### Option B — Restauration ciblée (juste quelques lignes)

Si tu as juste perdu une famille ou un user, ouvre le JSON dans VSCode,
copie l'objet/array concerné, et fais un INSERT manuel via SQL Editor.

## 3. Vérifier

Après restauration, vérifie via SQL Editor :
```sql
SELECT 'churches' AS t, count(*) FROM churches
UNION ALL SELECT 'users', count(*) FROM users
UNION ALL SELECT 'families', count(*) FROM families
-- etc.
```
