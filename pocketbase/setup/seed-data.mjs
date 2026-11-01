import { writeFileSync } from 'node:fs';

function mulberry32(a) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rnd = mulberry32(20261101);
const pick = (list) => list[Math.floor(rnd() * list.length)];
const chance = (p) => rnd() < p;
const between = (a, b) => a + Math.floor(rnd() * (b - a + 1));

const specializations = [
  { name: 'Терапевт', description: 'Лечение кариеса, пульпита, реставрация зубов' },
  { name: 'Ортодонт', description: 'Исправление прикуса, брекет-системы, элайнеры' },
  { name: 'Хирург-имплантолог', description: 'Удаление зубов, имплантация, костная пластика' },
  { name: 'Ортопед', description: 'Коронки, виниры, протезирование' },
  { name: 'Детский стоматолог', description: 'Лечение и профилактика у детей' },
  { name: 'Гигиенист', description: 'Профессиональная чистка и отбеливание' },
];

const cabinets = [
  { number: '101', floor: 1, equipment: 'Стоматологическая установка, радиовизиограф' },
  { number: '102', floor: 1, equipment: 'Стоматологическая установка, микроскоп' },
  { number: '103', floor: 1, equipment: 'Установка для гигиены, пескоструйный аппарат' },
  { number: '201', floor: 2, equipment: 'Операционная, конусно-лучевой томограф' },
  { number: '202', floor: 2, equipment: 'Ортопедический кабинет, 3D-сканер' },
  { number: '104', floor: 1, equipment: 'Детский кабинет, игровая зона' },
];

const categories = [
  { name: 'Диагностика', description: 'Осмотр, снимки, консультации' },
  { name: 'Терапия', description: 'Лечение зубов' },
  { name: 'Хирургия', description: 'Удаление и имплантация' },
  { name: 'Ортопедия', description: 'Протезирование' },
  { name: 'Ортодонтия', description: 'Исправление прикуса' },
  { name: 'Гигиена', description: 'Чистка и отбеливание' },
];

const services = [
  ['Первичная консультация', 0, 800, 30],
  ['Осмотр и план лечения', 0, 0, 20],
  ['Прицельный снимок зуба', 0, 500, 10],
  ['Панорамный снимок', 0, 1500, 15],
  ['Лечение кариеса', 1, 4500, 60],
  ['Лечение пульпита (один канал)', 1, 7500, 90],
  ['Пломба светоотверждаемая', 1, 3500, 45],
  ['Лечение каналов (повторное)', 1, 9500, 90],
  ['Удаление зуба простое', 2, 3000, 30],
  ['Удаление зуба мудрости', 2, 7500, 60],
  ['Имплантация (системa Osstem)', 2, 38000, 90],
  ['Синус-лифтинг', 2, 28000, 90],
  ['Коронка металлокерамическая', 3, 14000, 60],
  ['Коронка циркониевая', 3, 28000, 60],
  ['Винир керамический', 3, 32000, 90],
  ['Снятие слепка', 3, 1500, 20],
  ['Установка брекет-системы', 4, 45000, 120],
  ['Коррекция брекетов', 4, 3500, 30],
  ['Изготовление элайнеров', 4, 90000, 60],
  ['Профессиональная гигиена', 5, 5500, 60],
  ['Отбеливание Zoom', 5, 18000, 90],
  ['Покрытие фторлаком', 5, 1800, 20],
  ['Герметизация фиссур', 5, 2500, 30],
  ['Лечение молочного зуба', 1, 3800, 45],
];

const specCategories = {
  0: [0, 1],
  1: [0, 4],
  2: [0, 2],
  3: [0, 3],
  4: [0, 1, 5],
  5: [0, 5],
};

const doctors = [
  { fullName: 'Соколова Анна Петровна', specialization: 0, cabinet: 0, experienceYears: 12, phone: '+7 495 100-20-01', userEmail: 'doctor@clinic.test' },
  { fullName: 'Громов Дмитрий Игоревич', specialization: 1, cabinet: 1, experienceYears: 9, phone: '+7 495 100-20-02', userEmail: 'doctor2@clinic.test' },
  { fullName: 'Рябов Михаил Сергеевич', specialization: 2, cabinet: 3, experienceYears: 15, phone: '+7 495 100-20-03', userEmail: 'doctor3@clinic.test' },
  { fullName: 'Ефимова Ольга Викторовна', specialization: 3, cabinet: 4, experienceYears: 11, phone: '+7 495 100-20-04', userEmail: 'doctor4@clinic.test' },
  { fullName: 'Белова Татьяна Николаевна', specialization: 4, cabinet: 5, experienceYears: 7, phone: '+7 495 100-20-05', userEmail: 'doctor5@clinic.test' },
  { fullName: 'Орлова Екатерина Андреевна', specialization: 5, cabinet: 2, experienceYears: 5, phone: '+7 495 100-20-06', userEmail: 'doctor6@clinic.test' },
];

const users = [
  { name: 'Смирнова Елена Александровна', email: 'admin@clinic.test', password: 'Admin123!', role: 'admin' },
  { name: 'Кузнецова Наталья Владимировна', email: 'registrar@clinic.test', password: 'Registrar123!', role: 'registrar' },
  { name: 'Попова Ирина Сергеевна', email: 'registrar2@clinic.test', password: 'Registrar123!', role: 'registrar' },
  ...doctors.map((d) => ({
    name: d.fullName,
    email: d.userEmail,
    password: 'Doctor123!',
    role: 'doctor',
  })),
];

const maleSurnames = ['Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Попов', 'Васильев', 'Морозов', 'Новиков', 'Фёдоров', 'Волков', 'Алексеев', 'Лебедев', 'Семёнов', 'Егоров', 'Павлов', 'Козлов', 'Степанов', 'Николаев', 'Орлов', 'Андреев'];
const maleNames = ['Александр', 'Дмитрий', 'Максим', 'Сергей', 'Андрей', 'Алексей', 'Артём', 'Илья', 'Кирилл', 'Михаил', 'Никита', 'Матвей'];
const malePatr = ['Александрович', 'Дмитриевич', 'Сергеевич', 'Андреевич', 'Алексеевич', 'Игоревич', 'Михайлович', 'Николаевич'];
const femaleNames = ['Анна', 'Мария', 'Елена', 'Ольга', 'Наталья', 'Ирина', 'Екатерина', 'Татьяна', 'Светлана', 'Юлия', 'Дарья', 'Алиса'];
const femalePatr = ['Александровна', 'Дмитриевна', 'Сергеевна', 'Андреевна', 'Алексеевна', 'Игоревна', 'Михайловна', 'Николаевна'];
const translit = { Иванов: 'ivanov', Петров: 'petrov', Сидоров: 'sidorov', Кузнецов: 'kuznetsov', Попов: 'popov', Васильев: 'vasilev', Морозов: 'morozov', Новиков: 'novikov', Фёдоров: 'fedorov', Волков: 'volkov', Алексеев: 'alekseev', Лебедев: 'lebedev', Семёнов: 'semenov', Егоров: 'egorov', Павлов: 'pavlov', Козлов: 'kozlov', Степанов: 'stepanov', Николаев: 'nikolaev', Орлов: 'orlov', Андреев: 'andreev' };

const patients = [];
const usedNames = new Set();
while (patients.length < 40) {
  const female = chance(0.55);
  const surname = pick(maleSurnames);
  const fullName = female
    ? `${surname}а ${pick(femaleNames)} ${pick(femalePatr)}`
    : `${surname} ${pick(maleNames)} ${pick(malePatr)}`;
  if (usedNames.has(fullName)) continue;
  usedNames.add(fullName);
  const index = patients.length + 1;
  const birthYear = between(1950, 2018);
  patients.push({
    fullName,
    birthDate: `${birthYear}-${String(between(1, 12)).padStart(2, '0')}-${String(between(1, 28)).padStart(2, '0')}`,
    phone: `+7 9${between(10, 99)} ${between(100, 999)}-${between(10, 99)}-${between(10, 99)}`,
    email: chance(0.8) ? `${translit[surname]}${index}@mail.test` : '',
    address: chance(0.6) ? `г. Москва, ул. ${pick(['Ленина', 'Мира', 'Садовая', 'Парковая', 'Школьная', 'Лесная'])}, д. ${between(1, 80)}, кв. ${between(1, 120)}` : '',
  });
}

const patientCards = patients.map((p, i) => ({
  patient: i,
  number: `K-${String(100001 + i)}`,
  allergies: chance(0.25) ? pick(['Лидокаин', 'Пенициллин', 'Латекс', 'Артикаин']) : '',
  notes: chance(0.3) ? pick(['Боится боли, нужна премедикация', 'Гипертония, контроль давления', 'Беременность, 2 триместр', 'Диабет 2 типа']) : '',
  openedDayOffset: -between(30, 900),
}));

const complaints = ['Боль при накусывании', 'Чувствительность к холодному', 'Профилактический осмотр', 'Кровоточивость дёсен', 'Скол пломбы', 'Желание отбелить зубы', 'Боль при жевании', 'Консультация по протезированию'];
const diagnoses = ['Кариес дентина, зуб 36. Проведено лечение, поставлена пломба.', 'Хронический пульпит, зуб 46. Каналы обработаны и запломбированы.', 'Гингивит лёгкой степени. Рекомендована гигиена и полоскание.', 'Профилактический осмотр: патологии не выявлено.', 'Удалён зуб 38 по показаниям. Рекомендации даны.', 'Скол коронки зуба 21. Выполнена реставрация.', 'Консультация: составлен план лечения.'];

const doctorServices = doctors.map((d) =>
  services.map((s, i) => [s, i]).filter(([s]) => specCategories[d.specialization].includes(s[1])).map(([, i]) => i),
);

const appointments = [];
const patientBusy = new Map();
const occupied = (patient, day, start, end) =>
  (patientBusy.get(`${patient}:${day}`) ?? []).some(([s, e]) => s < end && e > start);

for (let day = -28; day <= 10; day++) {
  const weekday = ((day + 6) % 7 + 7) % 7;
  const date = new Date(Date.UTC(2026, 10, 1 + day));
  const dow = date.getUTCDay();
  if (dow === 0) continue;
  doctors.forEach((doctor, di) => {
    const cabinetShift = doctor.cabinet;
    let cursor = 6 * 60 + (di % 2) * 15;
    const closing = (dow === 6 ? 13 : 15) * 60;
    while (cursor < closing - 30) {
      if (chance(0.82)) {
        cursor += 15 * between(1, 3);
        continue;
      }
      const picked = [];
      const pool = doctorServices[di];
      const count = chance(0.65) ? 1 : chance(0.7) ? 2 : 3;
      for (let k = 0; k < count; k++) {
        const s = pick(pool);
        if (!picked.includes(s)) picked.push(s);
      }
      const duration = Math.ceil(picked.reduce((sum, i) => sum + services[i][3], 0) / 15) * 15;
      if (cursor + duration > closing) break;
      let patient = between(0, patients.length - 1);
      let guard = 0;
      while (occupied(patient, day, cursor, cursor + duration) && guard++ < 30) {
        patient = between(0, patients.length - 1);
      }
      if (guard >= 30) {
        cursor += 15;
        continue;
      }
      const key = `${patient}:${day}`;
      patientBusy.set(key, [...(patientBusy.get(key) ?? []), [cursor, cursor + duration]]);
      const past = day < 0;
      const cancelled = chance(past ? 0.12 : 0.08);
      appointments.push({
        patient,
        doctor: di,
        services: picked,
        dayOffset: day,
        startMin: cursor,
        durationMin: duration,
        status: cancelled ? 'cancelled' : past ? 'done' : 'planned',
        complaints: pick(complaints),
        diagnosis: !cancelled && past ? pick(diagnoses) : '',
      });
      cursor += duration + 15 * between(0, 2);
      void cabinetShift;
      void weekday;
    }
  });
}

const payments = [];
const methods = ['cash', 'card', 'card', 'transfer'];
appointments.forEach((a, i) => {
  if (a.status !== 'done') return;
  const roll = rnd();
  if (roll < 0.1) return;
  payments.push({ appointment: i, share: roll < 0.2 ? 0.5 : 1, method: pick(methods) });
});

const seed = {
  users,
  specializations,
  cabinets,
  categories,
  services: services.map(([name, category, price, durationMin]) => ({ name, category, price, durationMin, description: '' })),
  doctors,
  patients,
  patientCards,
  appointments,
  payments,
};

writeFileSync(new URL('./seed.json', import.meta.url), JSON.stringify(seed, null, 1));
console.log(
  `Пациентов: ${patients.length}, приёмов: ${appointments.length}, оплат: ${payments.length}`,
);
