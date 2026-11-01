const pocketBaseUrl = String.fromEnvironment(
  'PB_URL',
  defaultValue: 'http://127.0.0.1:8090',
);

const demoMode = bool.fromEnvironment('DEMO', defaultValue: false);
