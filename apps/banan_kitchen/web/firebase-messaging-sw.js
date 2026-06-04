/* Firebase Cloud Messaging service worker — handles web push while the
   Banan kitchen tab is in the background or closed. Must live at the web root. */
/* eslint-disable no-undef */
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: 'AIzaSyC5af81AJ4SNHl4dKRdsij2rBDsLP8ZjU8',
  authDomain: 'banan-f0229.firebaseapp.com',
  projectId: 'banan-f0229',
  storageBucket: 'banan-f0229.firebasestorage.app',
  messagingSenderId: '1020298007280',
  appId: '1:1020298007280:web:3ae7afd59fa074b43fe835',
  measurementId: 'G-V8FGQNH42X',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const n = payload.notification || {};
  const data = payload.data || {};
  self.registration.showNotification(n.title || 'Banan Bếp', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { link: (payload.fcmOptions && payload.fcmOptions.link) || data.link || '/' },
  });
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.link) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (const c of list) {
        if ('focus' in c) return c.focus();
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
