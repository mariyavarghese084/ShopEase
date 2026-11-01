// Firebase Cloud Messaging Background Service Worker for ShopEase (AÈRA Luxury Fragrances)
// Uses Firebase v10 compat libraries for service worker compatibility.
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

// Initialize Firebase with the ShopEase project web configuration
firebase.initializeApp({
  apiKey: "AIzaSyAzFiVlomwvbldoyIqmbBWR4JjcQlS5_VE",
  authDomain: "shopease-59a47.firebaseapp.com",
  projectId: "shopease-59a47",
  storageBucket: "shopease-59a47.firebasestorage.app",
  messagingSenderId: "1039678576985",
  appId: "1:1039678576985:web:e475d87365cff37ecf1448",
  measurementId: "G-R26RYKE3JF"
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background push messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[ShopEase:firebase-messaging-sw.js] Received background message: ', payload);

  const title = (payload.notification && payload.notification.title) ||
                (payload.data && payload.data.title) ||
                'AÈRA ShopEase Announcement';

  const body = (payload.notification && payload.notification.body) ||
               (payload.data && payload.data.body) ||
               'You have an update from ShopEase.';

  const options = {
    body: body,
    icon: 'favicon.png',
    badge: 'icons/Icon-192.png',
    data: payload.data || {},
    tag: (payload.data && (payload.data.requestId || payload.data.id)) || 'shopease-notification',
    renotify: true
  };

  return self.registration.showNotification(title, options);
});

// Focus active browser tab or open window when user clicks notification
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const targetRoute = (event.notification.data && event.notification.data.targetRoute) || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetRoute);
      }
    })
  );
});

