import { mkdirSync, writeFileSync } from 'node:fs';
import { api, login } from './client.mjs';

await login();
const list = await api('GET', '/api/collections?perPage=200&sort=name');
const collections = list.items.filter((c) => !c.name.startsWith('_') || c.name === '_pb_users_auth_');
const byId = new Map(list.items.map((c) => [c.id, c.name]));

const clean = (c) => {
  const copy = { ...c };
  return copy;
};

const docs = new URL('../../docs/', import.meta.url);
mkdirSync(docs, { recursive: true });
writeFileSync(new URL('pb_schema.json', docs), JSON.stringify(collections.map(clean), null, 2));

const simple = {};
for (const c of collections) {
  if (c.system && c.name !== 'users') continue;
  const unique = [];
  for (const index of c.indexes || []) {
    if (!/UNIQUE/i.test(index)) continue;
    const m = index.match(/\(([^)]+)\)/);
    if (!m) continue;
    const columns = m[1].split(',').map((s) => s.trim().replace(/[`"]/g, ''));
    unique.push({ columns, nonEmpty: /WHERE/i.test(index) });
  }
  simple[c.name] = {
    fields: c.fields
      .filter((f) => !f.system || f.name === 'id')
      .map((f) => ({
        name: f.name,
        type: f.type,
        required: !!f.required,
        min: f.min ?? null,
        max: f.max ?? null,
        pattern: f.pattern || null,
        values: f.values || null,
        multiple: (f.maxSelect || 1) > 1,
        collection: f.type === 'relation' ? byId.get(f.collectionId) : null,
        onlyInt: !!f.onlyInt,
      })),
    unique,
  };
}
writeFileSync(
  new URL('../../assets/demo_schema.json', import.meta.url),
  JSON.stringify(simple, null, 1),
);
console.log('Экспортировано коллекций:', Object.keys(simple).join(', '));
