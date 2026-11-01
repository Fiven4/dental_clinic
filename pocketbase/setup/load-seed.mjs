import { readFileSync } from 'node:fs';
import { api, login } from './client.mjs';

const seed = JSON.parse(readFileSync(new URL('./seed.json', import.meta.url), 'utf8'));

const today = new Date();
const base = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
const iso = (ms) => new Date(ms).toISOString().replace('T', ' ');
const dayStart = (offset) => base + offset * 86400000;

async function wipe() {
  for (const name of ['payments', 'appointments', 'patient_cards', 'patients', 'doctors', 'services', 'service_categories', 'cabinets', 'specializations']) {
    const list = await api('GET', `/api/collections/${name}/records?perPage=500&fields=id`);
    for (const item of list.items) {
      await api('DELETE', `/api/collections/${name}/records/${item.id}`);
    }
  }
  const users = await api('GET', '/api/collections/users/records?perPage=200&fields=id');
  for (const u of users.items) await api('DELETE', `/api/collections/users/records/${u.id}`);
}

async function create(collection, body) {
  return api('POST', `/api/collections/${collection}/records`, body);
}

async function main() {
  await login();
  await wipe();

  const userIds = {};
  for (const u of seed.users) {
    const r = await create('users', {
      email: u.email,
      password: u.password,
      passwordConfirm: u.password,
      name: u.name,
      role: u.role,
      emailVisibility: true,
      verified: true,
    });
    userIds[u.email] = r.id;
  }

  const specs = [];
  for (const s of seed.specializations) specs.push((await create('specializations', s)).id);
  const cabs = [];
  for (const c of seed.cabinets) cabs.push((await create('cabinets', c)).id);
  const cats = [];
  for (const c of seed.categories) cats.push((await create('service_categories', c)).id);
  const svcs = [];
  for (const s of seed.services) svcs.push((await create('services', { ...s, category: cats[s.category] })).id);

  const docs = [];
  for (const d of seed.doctors) {
    docs.push(
      (
        await create('doctors', {
          fullName: d.fullName,
          specialization: specs[d.specialization],
          cabinet: cabs[d.cabinet],
          user: userIds[d.userEmail],
          experienceYears: d.experienceYears,
          phone: d.phone,
        })
      ).id,
    );
  }

  const pats = [];
  for (const p of seed.patients) pats.push((await create('patients', p)).id);

  for (const c of seed.patientCards) {
    await create('patient_cards', {
      patient: pats[c.patient],
      number: c.number,
      allergies: c.allergies,
      notes: c.notes,
      openedOn: iso(dayStart(c.openedDayOffset)),
    });
  }

  const sorted = seed.appointments
    .map((a, index) => ({ a, index }))
    .sort((x, y) => x.a.dayOffset - y.a.dayOffset || x.a.startMin - y.a.startMin);

  const apptIds = new Map();
  for (const { a, index } of sorted) {
    const start = dayStart(a.dayOffset) + a.startMin * 60000;
    const r = await create('appointments', {
      patient: pats[a.patient],
      doctor: docs[a.doctor],
      services: a.services.map((i) => svcs[i]),
      startAt: iso(start),
      endAt: iso(start + a.durationMin * 60000),
      status: a.status,
      complaints: a.complaints,
      diagnosis: a.diagnosis,
    });
    apptIds.set(index, r);
  }

  let payCount = 0;
  for (const p of seed.payments) {
    const appt = apptIds.get(p.appointment);
    const original = seed.appointments[p.appointment];
    const amount = Math.max(1, Math.round(appt.total * p.share));
    if (appt.total <= 0) continue;
    await create('payments', {
      appointment: appt.id,
      amount,
      method: p.method,
      paidAt: iso(dayStart(original.dayOffset) + (original.startMin + original.durationMin) * 60000),
    });
    payCount++;
  }

  console.log(`Загружено: пользователей ${seed.users.length}, приёмов ${apptIds.size}, оплат ${payCount}`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
