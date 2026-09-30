import admin from 'firebase-admin';

let ready = false;

export function messaging() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return null;
  if (!ready) {
    const credential = admin.credential.cert(JSON.parse(raw));
    if (!admin.apps.length) admin.initializeApp({ credential });
    ready = true;
  }
  return admin.messaging();
}
