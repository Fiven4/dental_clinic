const DELETABLE = [
  'specializations',
  'cabinets',
  'service_categories',
  'services',
  'patients',
  'doctors',
  'appointments',
];

onRecordCreateRequest((e) => {
  const isAdmin =
    e.hasSuperuserAuth() || (e.auth && e.auth.getString('role') === 'admin');
  if (!isAdmin) {
    e.record.set('role', 'registrar');
  }
  e.next();
}, 'users');

onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.prepareAppointment(e.record, null);
  e.next();
}, 'appointments');

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.prepareAppointment(e.record, e.record.original());
  e.next();
}, 'appointments');

onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.preparePayment(e.record);
  e.next();
}, 'payments');

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.preparePayment(e.record);
  e.next();
}, 'payments');

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  const before = e.record.original().getString('deletedAt');
  const after = e.record.getString('deletedAt');
  if (before === '' && after !== '') {
    lib.guardDelete(e.record, false);
  }
  e.next();
}, ...DELETABLE);

onRecordDeleteRequest((e) => {
  const lib = require(`${__hooks}/lib.js`);
  lib.guardDelete(e.record, true);
  e.next();
}, ...DELETABLE);
