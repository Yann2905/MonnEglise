// Service worker pour Firebase Cloud Messaging (Web push)
// DOIT être placé à la racine du dossier `web/`
// — Doit utiliser la version SDK compatible avec firebase-messaging-web

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCDH4u5_DtAB9lwN_emU45Ecf90mhzsC4I',
  appId: '1:1001792393824:web:72184bfb3a44aa7c542905',
  messagingSenderId: '1001792393824',
  projectId: 'moneglise-8c5c8',
  authDomain: 'moneglise-8c5c8.firebaseapp.com',
  storageBucket: 'moneglise-8c5c8.firebasestorage.app',
});

const messaging = firebase.messaging();

// Notification background (onglet inactif / app fermée)
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'MonÉglise';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
  };
  self.registration.showNotification(title, options);
});
