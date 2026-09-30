importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-messaging-compat.js');
importScripts('/firebase-config.js');

if (self.FIREBASE_CONFIG) {
  firebase.initializeApp(self.FIREBASE_CONFIG);
  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || 'Sprout';
    const body = payload.notification?.body || '';
    return self.registration.showNotification(title, { body });
  });
}
