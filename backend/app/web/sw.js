// Minimal service worker: app shell only. API calls are never cached.
const CACHE = "allen-shell-v1";
const SHELL = ["./", "app.js", "style.css", "manifest.webmanifest", "icon-192.png"];
self.addEventListener("install", (e) => e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL))));
self.addEventListener("activate", (e) =>
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))));
self.addEventListener("fetch", (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.pathname.startsWith("/v1/")) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
