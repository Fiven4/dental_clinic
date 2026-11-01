import 'filter_query.dart';

const specializationsSpec = QuerySpec(
  sortFields: {'name', 'created'},
  defaultSort: 'name',
);

const cabinetsSpec = QuerySpec(
  sortFields: {'number', 'floor'},
  defaultSort: 'number',
  filterKeys: {'floor'},
);

const categoriesSpec = QuerySpec(
  sortFields: {'name', 'created'},
  defaultSort: 'name',
);

const servicesSpec = QuerySpec(
  sortFields: {'name', 'price', 'durationMin', 'category'},
  defaultSort: 'name',
  filterKeys: {'category', 'priceMin', 'priceMax', 'durationMax'},
);

const doctorsSpec = QuerySpec(
  sortFields: {'fullName', 'experienceYears', 'specialization', 'cabinet'},
  defaultSort: 'fullName',
  filterKeys: {'specialization', 'cabinet', 'experienceMin'},
);

const patientsSpec = QuerySpec(
  sortFields: {'fullName', 'birthDate', 'created'},
  defaultSort: 'fullName',
  filterKeys: {'ageGroup', 'hasCard', 'hasEmail'},
);

const cardsSpec = QuerySpec(
  sortFields: {'number', 'patient', 'openedOn'},
  defaultSort: 'number',
  filterKeys: {'hasAllergies', 'openedFrom', 'openedTo', 'patient'},
);

const appointmentsSpec = QuerySpec(
  sortFields: {'startAt', 'patient', 'doctor', 'status', 'total'},
  defaultSort: 'startAt',
  defaultAscending: false,
  filterKeys: {'status', 'doctor', 'patient', 'category', 'from', 'to'},
);

const paymentsSpec = QuerySpec(
  sortFields: {'paidAt', 'amount', 'method'},
  defaultSort: 'paidAt',
  defaultAscending: false,
  filterKeys: {'method', 'doctor', 'appointment', 'from', 'to'},
);

const usersSpec = QuerySpec(
  sortFields: {'name', 'email', 'role', 'created'},
  defaultSort: 'name',
  filterKeys: {'role'},
);
