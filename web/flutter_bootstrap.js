// Custom bootstrap: load Flutter WITHOUT registering a service worker, so the
// browser never serves a stale cached build. Combined with no-cache headers on
// index.html / main.dart.js (firebase.json), every visit gets the live deploy.
//
// Returning visitors may still have an OLD service worker registered from
// before this file existed — that old SW would keep serving its stale cache
// forever since nothing here re-registers a new one. Actively unregister any
// leftover service workers and wipe their caches so every browser self-heals
// to the live build on next load, no manual cache-clear needed.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((regs) => {
    for (const r of regs) r.unregister();
  });
}
if (window.caches) {
  caches.keys().then((keys) => keys.forEach((k) => caches.delete(k)));
}

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
