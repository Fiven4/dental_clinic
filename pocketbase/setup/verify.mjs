import { BASE } from './client.mjs';

async function call(method, path, body, token) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, data: text ? JSON.parse(text) : null };
}

async function auth(email, password) {
  const r = await call('POST', '/api/collections/users/auth-with-password', { identity: email, password });
  return r.data.token;
}

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok });
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}${detail ? ' — ' + detail : ''}`);
}

const admin = await auth('admin@clinic.test', 'Admin123!');
const reg = await auth('registrar@clinic.test', 'Registrar123!');
const doc = await auth('doctor@clinic.test', 'Doctor123!');
const doc2 = await auth('doctor2@clinic.test', 'Doctor123!');

let r = await call('GET', '/api/collections/appointments/records?perPage=1', null, doc);
check('врач видит свои приёмы', r.status === 200 && r.data.totalItems > 0, `всего ${r.data.totalItems}`);
const allAppts = await call('GET', '/api/collections/appointments/records?perPage=1', null, reg);
check('регистратор видит все приёмы', allAppts.data.totalItems > r.data.totalItems, `${allAppts.data.totalItems} > ${r.data.totalItems}`);

r = await call('GET', '/api/collections/users/records', null, reg);
check('регистратор видит только себя в users', r.data.totalItems === 1);
r = await call('GET', '/api/collections/users/records', null, admin);
check('админ видит всех пользователей', r.data.totalItems >= 9, `${r.data.totalItems}`);

r = await call('GET', '/api/collections/payments/records?perPage=1', null, doc);
check('врач не видит оплаты', r.status === 200 && r.data.totalItems === 0 || r.status === 403, `status ${r.status}`);

r = await call('POST', '/api/collections/users/records', {
  email: `new.user.${Date.now()}@clinic.test`, password: 'Password123', passwordConfirm: 'Password123', name: 'Новый Сотрудник', role: 'admin',
});
check('регистрация принудительно даёт роль registrar', r.status === 200 && r.data.role === 'registrar', `role=${r.data.role}`);
if (r.status === 200) await call('DELETE', `/api/collections/users/records/${r.data.id}`, null, admin);

r = await call('POST', '/api/collections/users/records', {
  email: 'registrar@clinic.test', password: 'Password123', passwordConfirm: 'Password123', name: 'Дубль', role: 'registrar',
});
check('дубликат почты даёт ошибку поля email', r.status === 400 && r.data.data.email, JSON.stringify(r.data.data));

const patients = await call('GET', '/api/collections/patients/records?perPage=5', null, reg);
const doctors = await call('GET', '/api/collections/doctors/records?perPage=10&expand=cabinet', null, reg);
const services = await call('GET', '/api/collections/services/records?perPage=5', null, reg);
const d0 = doctors.data.items[0];
const when = new Date(Date.UTC(2026, 11, 20, 8, 0, 0));
const fmt = (d) => d.toISOString().replace('T', ' ');
const base = {
  patient: patients.data.items[0].id,
  doctor: d0.id,
  services: [services.data.items[3].id],
  startAt: fmt(when),
  endAt: fmt(new Date(when.getTime() + 3600000)),
  status: 'planned',
};
r = await call('POST', '/api/collections/appointments/records', base, reg);
check('регистратор создаёт приём', r.status === 200, `total=${r.data.total}`);
const apptId = r.data.id;
const total = r.data.total;

r = await call('POST', '/api/collections/appointments/records', { ...base, patient: patients.data.items[1].id, startAt: fmt(new Date(when.getTime() + 1800000)), endAt: fmt(new Date(when.getTime() + 5400000)) }, reg);
check('пересечение по врачу даёт 409', r.status === 409, r.data.message);

r = await call('POST', '/api/collections/appointments/records', { ...base, endAt: base.startAt }, reg);
check('окончание раньше начала даёт 400 в поле endAt', r.status === 400 && r.data.data.endAt);

r = await call('POST', '/api/collections/appointments/records', base, doc);
check('врач не может создавать приём', r.status === 403 || r.status === 400, `status ${r.status}`);

r = await call('POST', '/api/collections/payments/records', { appointment: apptId, amount: total + 100, method: 'cash', paidAt: fmt(new Date()) }, reg);
check('оплата больше стоимости даёт 409', r.status === 409, r.data.message);
r = await call('POST', '/api/collections/payments/records', { appointment: apptId, amount: total, method: 'card', paidAt: fmt(new Date()) }, reg);
check('полная оплата принимается', r.status === 200);
r = await call('POST', '/api/collections/payments/records', { appointment: apptId, amount: total, method: 'cash', paidAt: fmt(new Date()) }, admin);
check('админ не принимает оплаты', r.status === 403 || r.status === 400, `status ${r.status}`);

r = await call('DELETE', `/api/collections/services/records/${services.data.items[3].id}`, null, admin);
check('услуга со ссылками не удаляется (409)', r.status === 409, r.data.message);
r = await call('PATCH', `/api/collections/doctors/records/${d0.id}`, { deletedAt: fmt(new Date()) }, admin);
check('логическое удаление врача с приёмами даёт 409', r.status === 409, r.data.message);
r = await call('DELETE', `/api/collections/patients/records/${patients.data.items[0].id}`, null, reg);
check('регистратор не удаляет физически', r.status === 403 || r.status === 404, `status ${r.status}`);

r = await call('PATCH', `/api/collections/appointments/records/${apptId}`, { diagnosis: 'Осмотр' }, doc2);
check('врач не видит чужой приём (404)', r.status === 404, `status ${r.status}`);

const own = await call('GET', '/api/collections/appointments/records?perPage=1&filter=(status="planned")', null, doc);
const ownId = own.data.items[0].id;
r = await call('PATCH', `/api/collections/appointments/records/${ownId}`, { diagnosis: 'Проверка', status: 'done' }, doc);
check('врач заполняет диагноз своего приёма', r.status === 200);
r = await call('PATCH', `/api/collections/appointments/records/${ownId}`, { startAt: fmt(when) }, doc);
check('врач не меняет расписание', r.status === 400 || r.status === 403 || r.status === 404, `status ${r.status}`);

r = await call('GET', '/api/collections/appointments/records?perPage=1&sort=-startAt&filter=(deletedAt="")&expand=patient,doctor,services', null, reg);
check('expand и фильтр по пустой дате работают', r.status === 200 && r.data.items[0].expand.patient);

await call('DELETE', `/api/collections/payments/records/${(await call('GET', '/api/collections/payments/records?perPage=1&sort=-created', null, admin)).data.items[0].id}`, null, admin);
await call('DELETE', `/api/collections/appointments/records/${apptId}`, null, admin);
const users = await call('GET', '/api/collections/users/records?filter=(email="new.user@clinic.test")', null, admin);
for (const u of users.data.items) await call('DELETE', `/api/collections/users/records/${u.id}`, null, admin);

const failed = results.filter((x) => !x.ok).length;
console.log(`\nПроверок: ${results.length}, провалено: ${failed}`);
process.exit(failed ? 1 : 0);
