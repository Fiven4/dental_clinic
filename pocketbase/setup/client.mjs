export const BASE = process.env.PB_URL ?? 'http://127.0.0.1:8090';
export const ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL ?? 'admin@clinic.local';
export const ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD ?? 'Admin12345!';

let token = null;

export async function api(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: token } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    throw new Error(`${method} ${path} -> ${res.status} ${JSON.stringify(data)}`);
  }
  return data;
}

export async function login() {
  const data = await api('POST', '/api/collections/_superusers/auth-with-password', {
    identity: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
  });
  token = data.token;
}
