const DEPENDENTS = {
  specializations: [['doctors', 'specialization', 'врачи']],
  cabinets: [['doctors', 'cabinet', 'врачи']],
  service_categories: [['services', 'category', 'услуги']],
  services: [['appointments', 'services', 'приёмы']],
  patients: [['appointments', 'patient', 'приёмы']],
  doctors: [['appointments', 'doctor', 'приёмы']],
  appointments: [['payments', 'appointment', 'оплаты']],
};

function titleOf(record) {
  return (
    record.getString('fullName') ||
    record.getString('name') ||
    record.getString('number') ||
    record.id
  );
}

function countLinked(collection, id, includeDeleted) {
  const parts = [];
  let total = 0;
  for (const [dep, field, label] of DEPENDENTS[collection] || []) {
    const filter = includeDeleted
      ? `${field}.id ?= {:id}`
      : `${field}.id ?= {:id} && deletedAt = ''`;
    const found = $app.findRecordsByFilter(dep, filter, '', 1000, 0, { id });
    if (found.length > 0) {
      total += found.length;
      parts.push(`${label}: ${found.length}`);
    }
  }
  return { total, parts };
}

function guardDelete(record, includeDeleted) {
  const { total, parts } = countLinked(record.collection().name, record.id, includeDeleted);
  if (total > 0) {
    throw new ApiError(
      409,
      `Запись «${titleOf(record)}» удалить нельзя: на неё ссылаются другие записи (${total}). ${parts.join(', ')}.`,
      { count: total },
    );
  }
}

function timeLabel(record) {
  const pad = (n) => String(n).padStart(2, '0');
  const part = (field) => {
    const d = new Date(record.getDateTime(field).string().replace(' ', 'T'));
    const local = new Date(d.getTime() + 3 * 3600000);
    return `${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}`;
  };
  return `${part('startAt')}–${part('endAt')}`;
}

function findOverlap(record) {
  const start = record.getDateTime('startAt').string();
  const end = record.getDateTime('endAt').string();
  const doctorId = record.getString('doctor');
  const patientId = record.getString('patient');
  const doctor = $app.findRecordById('doctors', doctorId);
  const cabinetId = doctor.getString('cabinet');

  const base =
    "status != 'cancelled' && deletedAt = '' && id != {:id} && startAt < {:end} && endAt > {:start}";
  const params = { id: record.id || 'new', start, end, doctor: doctorId, patient: patientId, cabinet: cabinetId };

  const checks = [
    ['doctor', 'Врач занят в это время', `${base} && doctor = {:doctor}`],
    ['patient', 'Пациент уже записан на это время', `${base} && patient = {:patient}`],
  ];
  if (cabinetId) {
    checks.push(['cabinet', 'Кабинет занят в это время', `${base} && doctor.cabinet = {:cabinet}`]);
  }

  for (const [kind, text, filter] of checks) {
    const found = $app.findRecordsByFilter('appointments', filter, 'startAt', 1, 0, params);
    if (found.length > 0) {
      return { kind, message: `${text}: существует приём ${timeLabel(found[0])}.`, id: found[0].id };
    }
  }
  return null;
}

function discountFor(patientId, excludeId) {
  const done = $app.findRecordsByFilter(
    'appointments',
    "patient = {:patient} && status = 'done' && deletedAt = '' && id != {:id}",
    '',
    1000,
    0,
    { patient: patientId, id: excludeId || 'new' },
  );
  if (done.length >= 10) return 15;
  if (done.length >= 5) return 10;
  return 0;
}

function prepareAppointment(record, original) {
  const changed = (field) => !original || String(record.get(field)) !== String(original.get(field));
  const scheduleChanged =
    changed('startAt') || changed('endAt') || changed('doctor') || changed('patient') || changed('status') || changed('deletedAt');
  const costChanged = changed('services') || changed('patient');

  const start = record.getDateTime('startAt');
  const end = record.getDateTime('endAt');
  if (end.unix() <= start.unix()) {
    throw new BadRequestError('Ошибка валидации', {
      endAt: new ValidationError('invalid_range', 'Окончание приёма должно быть позже начала.'),
    });
  }

  if (scheduleChanged && record.getString('status') !== 'cancelled' && record.getString('deletedAt') === '') {
    const overlap = findOverlap(record);
    if (overlap) {
      throw new ApiError(409, overlap.message, { kind: overlap.kind, appointment: overlap.id });
    }
  }

  if (costChanged) {
    let sum = 0;
    for (const id of record.getStringSlice('services')) {
      sum += $app.findRecordById('services', id).getFloat('price');
    }
    const discount = discountFor(record.getString('patient'), record.id);
    record.set('discountPercent', discount);
    record.set('total', Math.round((sum * (100 - discount)) / 100));
  }
}

function preparePayment(record) {
  const appointment = $app.findRecordById('appointments', record.getString('appointment'));
  if (appointment.getString('status') === 'cancelled') {
    throw new ApiError(409, 'Приём отменён: оплату принять нельзя.', {});
  }
  const others = $app.findRecordsByFilter(
    'payments',
    "appointment = {:appointment} && deletedAt = '' && id != {:id}",
    '',
    1000,
    0,
    { appointment: appointment.id, id: record.id || 'new' },
  );
  let paid = 0;
  for (const p of others) paid += p.getFloat('amount');
  const rest = appointment.getFloat('total') - paid;
  if (record.getString('deletedAt') === '' && record.getFloat('amount') > rest) {
    throw new ApiError(
      409,
      `Сумма оплат превышает стоимость приёма. Осталось оплатить: ${rest} ₽.`,
      { rest },
    );
  }
}

module.exports = { guardDelete, prepareAppointment, preparePayment, DEPENDENTS };
