import { api, login } from './client.mjs';

const ADM = '@request.auth.role = "admin"';
const REG = '@request.auth.role = "registrar"';
const DOC = '@request.auth.role = "doctor"';
const AUTH = '@request.auth.id != ""';
const AUTO = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

const text = (name, extra = {}) => ({ name, type: 'text', ...extra });
const num = (name, extra = {}) => ({ name, type: 'number', ...extra });
const date = (name, extra = {}) => ({ name, type: 'date', ...extra });
const deletedAt = () => date('deletedAt');
const rel = (name, collectionId, extra = {}) => ({
  name,
  type: 'relation',
  collectionId,
  maxSelect: 1,
  minSelect: 0,
  cascadeDelete: false,
  ...extra,
});

async function findCollection(name) {
  try {
    return await api('GET', `/api/collections/${name}`);
  } catch {
    return null;
  }
}

async function upsert(def) {
  const existing = await findCollection(def.name);
  if (existing) {
    return api('PATCH', `/api/collections/${existing.id}`, def);
  }
  return api('POST', '/api/collections', def);
}

async function main() {
  await login();

  const users = await api('GET', '/api/collections/users');
  const userFields = users.fields.filter((f) => f.name !== 'role');
  await api('PATCH', `/api/collections/${users.id}`, {
    fields: [
      ...userFields.map((f) =>
        f.name === 'name' ? { ...f, required: true, max: 100 } : f,
      ),
      {
        name: 'role',
        type: 'select',
        required: true,
        maxSelect: 1,
        values: ['admin', 'doctor', 'registrar'],
      },
    ],
    listRule: `${ADM} || id = @request.auth.id`,
    viewRule: `${ADM} || id = @request.auth.id || ${AUTH}`,
    createRule: '',
    updateRule: `${ADM} || (id = @request.auth.id && @request.body.role:isset = false)`,
    deleteRule: ADM,
    manageRule: ADM,
    authToken: { duration: 900 },
    passwordAuth: { enabled: true, identityFields: ['email'] },
  });

  const specializations = await upsert({
    name: 'specializations',
    type: 'base',
    fields: [text('name', { required: true, min: 2, max: 60 }), text('description', { max: 255 }), deletedAt(), ...AUTO],
    indexes: ['CREATE UNIQUE INDEX idx_specializations_name ON specializations (name COLLATE NOCASE)'],
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADM,
    updateRule: ADM,
    deleteRule: ADM,
  });

  const cabinets = await upsert({
    name: 'cabinets',
    type: 'base',
    fields: [
      text('number', { required: true, min: 1, max: 10 }),
      num('floor', { required: true, min: 1, max: 10, onlyInt: true }),
      text('equipment', { max: 255 }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: ['CREATE UNIQUE INDEX idx_cabinets_number ON cabinets (number COLLATE NOCASE)'],
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADM,
    updateRule: ADM,
    deleteRule: ADM,
  });

  const categories = await upsert({
    name: 'service_categories',
    type: 'base',
    fields: [text('name', { required: true, min: 2, max: 60 }), text('description', { max: 255 }), deletedAt(), ...AUTO],
    indexes: ['CREATE UNIQUE INDEX idx_service_categories_name ON service_categories (name COLLATE NOCASE)'],
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADM,
    updateRule: ADM,
    deleteRule: ADM,
  });

  const services = await upsert({
    name: 'services',
    type: 'base',
    fields: [
      text('name', { required: true, min: 2, max: 120 }),
      rel('category', categories.id, { required: true, minSelect: 1 }),
      num('price', { min: 0, max: 1000000 }),
      num('durationMin', { required: true, min: 10, max: 480, onlyInt: true }),
      text('description', { max: 500 }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: ['CREATE UNIQUE INDEX idx_services_name ON services (name COLLATE NOCASE)'],
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADM,
    updateRule: ADM,
    deleteRule: ADM,
  });

  const patients = await upsert({
    name: 'patients',
    type: 'base',
    fields: [
      text('fullName', { required: true, min: 2, max: 100 }),
      date('birthDate', { required: true }),
      text('phone', { required: true, min: 7, max: 20 }),
      { name: 'email', type: 'email', required: false },
      text('address', { max: 255 }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: ["CREATE UNIQUE INDEX idx_patients_email ON patients (email COLLATE NOCASE) WHERE email != ''"],
    listRule: null,
    viewRule: null,
    createRule: `${ADM} || ${REG}`,
    updateRule: `${ADM} || ${REG}`,
    deleteRule: ADM,
  });

  const cards = await upsert({
    name: 'patient_cards',
    type: 'base',
    fields: [
      rel('patient', patients.id, { required: true, minSelect: 1, cascadeDelete: true }),
      text('number', { required: true, pattern: '^K-\\d{6}$' }),
      text('allergies', { max: 500 }),
      text('notes', { max: 2000 }),
      date('openedOn', { required: true }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: [
      'CREATE UNIQUE INDEX idx_patient_cards_patient ON patient_cards (patient)',
      'CREATE UNIQUE INDEX idx_patient_cards_number ON patient_cards (number COLLATE NOCASE)',
    ],
    listRule: null,
    viewRule: null,
    createRule: `${ADM} || ${REG}`,
    updateRule: null,
    deleteRule: ADM,
  });

  const doctors = await upsert({
    name: 'doctors',
    type: 'base',
    fields: [
      text('fullName', { required: true, min: 2, max: 100 }),
      rel('specialization', specializations.id, { required: true, minSelect: 1 }),
      rel('cabinet', cabinets.id),
      rel('user', users.id),
      num('experienceYears', { required: true, min: 0, max: 60, onlyInt: true }),
      text('phone', { max: 20 }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: ["CREATE UNIQUE INDEX idx_doctors_user ON doctors (user) WHERE user != ''"],
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADM,
    updateRule: ADM,
    deleteRule: ADM,
  });

  const docOwn = `${DOC} && doctor.user = @request.auth.id`;
  const docNoSchedule = [
    'patient',
    'doctor',
    'services',
    'startAt',
    'endAt',
    'total',
    'discountPercent',
  ]
    .map((f) => `@request.body.${f}:isset = false`)
    .join(' && ');

  const appointments = await upsert({
    name: 'appointments',
    type: 'base',
    fields: [
      rel('patient', patients.id, { required: true, minSelect: 1 }),
      rel('doctor', doctors.id, { required: true, minSelect: 1 }),
      rel('services', services.id, { required: true, minSelect: 1, maxSelect: 20 }),
      date('startAt', { required: true }),
      date('endAt', { required: true }),
      { name: 'status', type: 'select', required: true, maxSelect: 1, values: ['planned', 'done', 'cancelled'] },
      num('discountPercent', { min: 0, max: 100 }),
      num('total', { min: 0 }),
      text('complaints', { max: 1000 }),
      text('diagnosis', { max: 2000 }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: [
      'CREATE INDEX idx_appointments_start ON appointments (startAt)',
      'CREATE INDEX idx_appointments_doctor ON appointments (doctor)',
      'CREATE INDEX idx_appointments_patient ON appointments (patient)',
    ],
    listRule: `${ADM} || ${REG} || (${docOwn})`,
    viewRule: `${ADM} || ${REG} || (${docOwn})`,
    createRule: `${ADM} || ${REG}`,
    updateRule: `${ADM} || ${REG} || (${docOwn} && ${docNoSchedule})`,
    deleteRule: ADM,
  });

  const payments = await upsert({
    name: 'payments',
    type: 'base',
    fields: [
      rel('appointment', appointments.id, { required: true, minSelect: 1 }),
      num('amount', { required: true, min: 1, max: 10000000 }),
      { name: 'method', type: 'select', required: true, maxSelect: 1, values: ['cash', 'card', 'transfer'] },
      date('paidAt', { required: true }),
      deletedAt(),
      ...AUTO,
    ],
    indexes: ['CREATE INDEX idx_payments_appointment ON payments (appointment)'],
    listRule: `${ADM} || ${REG}`,
    viewRule: `${ADM} || ${REG}`,
    createRule: REG,
    updateRule: REG,
    deleteRule: ADM,
  });

  const docPatient = `${DOC} && appointments_via_patient.doctor.user ?= @request.auth.id`;
  const docCard = `${DOC} && patient.appointments_via_patient.doctor.user ?= @request.auth.id`;
  await api('PATCH', `/api/collections/${patients.id}`, {
    listRule: `${ADM} || ${REG} || (${docPatient})`,
    viewRule: `${ADM} || ${REG} || (${docPatient})`,
  });
  await api('PATCH', `/api/collections/${cards.id}`, {
    listRule: `${ADM} || ${REG} || (${docCard})`,
    viewRule: `${ADM} || ${REG} || (${docCard})`,
    updateRule: `${ADM} || ${REG} || (${docCard})`,
  });

  console.log('Схема применена:', [specializations, cabinets, categories, services, patients, cards, doctors, appointments, payments].map((c) => c.name).join(', '));
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
