// Kill switch. banancakes.vn used to serve the Flutter ordering app, whose
// service worker (this same URL) is still installed in returning customers'
// browsers and would keep serving them the cached app instead of this site.
// Browsers re-fetch this file on every visit; this version replaces the old
// worker, drops its caches, unregisters itself and reloads open tabs.
// Keep this file for good: a customer may come back after a year.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    var keys = await caches.keys();
    await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    await self.registration.unregister();
    var tabs = await self.clients.matchAll({ type: 'window' });
    tabs.forEach(function (tab) { tab.navigate(tab.url); });
  })());
});
