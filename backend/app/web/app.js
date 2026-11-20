"use strict";
// ALLEN web client. Same agent API as the Android app, but only the 3 browser-safe tools work.
const $ = (id) => document.getElementById(id);
const log = $("log");
const store = {
  get: (k, d = "") => { try { return localStorage.getItem(k) ?? d; } catch { return d; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch {} },
};
let sttLang = store.get("sttLang", "bn-BD");
let busy = false, sessionId = null, pendingCall = null;

function add(cls, text, link) {
  const d = document.createElement("div");
  d.className = "m " + cls;
  d.textContent = text;
  if (link) {
    const a = document.createElement("a");
    a.className = "go"; a.href = link; a.target = "_blank"; a.rel = "noopener noreferrer";
    a.textContent = "Open ↗";
    d.appendChild(document.createElement("br")); d.appendChild(a);
  }
  log.appendChild(d); log.scrollTop = log.scrollHeight;
}

function speak(text, lang) {
  if (!("speechSynthesis" in window) || !text) return;
  const u = new SpeechSynthesisUtterance(text);
  u.lang = lang === "bn" ? "bn-BD" : "en-US";
  speechSynthesis.cancel(); speechSynthesis.speak(u);
}

async function api(path, body) {
  const r = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer " + store.get("token") },
    body: JSON.stringify(body),
  });
  if (r.status === 401) { store.set("token", ""); await register(); return api(path, body); }
  if (!r.ok) throw new Error("HTTP " + r.status);
  return r.json();
}

async function register() {
  let id = store.get("deviceId");
  if (!id) { id = "web-" + crypto.randomUUID(); store.set("deviceId", id); }
  const r = await fetch("/v1/auth/device", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ device_id: id, registration_code: store.get("code") }),
  });
  if (r.status === 403) { $("dlg").showModal(); throw new Error("Registration code lagbe (⚙ e dien)"); }
  if (!r.ok) throw new Error("register HTTP " + r.status);
  store.set("token", (await r.json()).token);
}

// ---- tools (browser-safe subset) ----
const APP_URLS = {
  youtube: "https://m.youtube.com", facebook: "https://m.facebook.com", instagram: "https://www.instagram.com",
  messenger: "https://www.messenger.com", whatsapp: "https://web.whatsapp.com", gmail: "https://mail.google.com",
  maps: "https://maps.google.com", spotify: "https://open.spotify.com", telegram: "https://web.telegram.org",
  tiktok: "https://www.tiktok.com", twitter: "https://x.com", x: "https://x.com", google: "https://www.google.com",
};

function openLink(url) {
  add("ai", url, url);          // always show a tappable link: iOS blocks popups that are not from a tap
  try { window.open(url, "_blank", "noopener"); } catch {}
}

async function runTool(c) {
  const a = c.args || {};
  if (c.name === "open_app") {
    const key = String(a.name || "").toLowerCase().trim();
    const url = APP_URLS[key] || "https://www.google.com/search?q=" + encodeURIComponent(key);
    openLink(url);
    return { ok: true, message: "Shown a link to the user (a website cannot launch apps). They must tap it." };
  }
  if (c.name === "open_url") {
    if (!/^https?:\/\//i.test(a.url || "")) return { ok: false, message: "only http(s) urls" };
    openLink(a.url);
    return { ok: true, message: "Link shown to the user; they must tap it." };
  }
  if (c.name === "search_in_app") {
    const q = encodeURIComponent(a.query || "");
    const url = a.app === "youtube" ? "https://m.youtube.com/results?search_query=" + q : "https://www.google.com/search?q=" + q;
    openLink(url);
    return { ok: true, message: "Search link shown; auto-play is not possible on web." };
  }
  return { ok: false, message: "not_supported_on_ios" };
}

// ---- agent loop ----
async function handle(step) {
  sessionId = step.session_id;
  for (const s of step.say || []) { add("ai", s.text); speak(s.text, s.lang); }
  if (step.status === "tool_calls") {
    const results = [];
    for (const c of step.tool_calls) results.push({ id: c.id, ...(await runTool(c)) });
    return handle(await api(`/v1/agent/${sessionId}/result`, { results }));
  }
  if (step.status === "confirm" || step.status === "ask_user") {
    pendingCall = { id: step.call_id, kind: step.status };
    const q = step.preview || step.question || "?";
    add("ai", q); speak(q, step.lang);
    if (step.status === "confirm") { $("cq").textContent = q; $("confirm").classList.add("on"); }
    return;
  }
  if (step.status === "done" && step.summary) { add("ai", step.summary); speak(step.summary, step.lang); }
  if (step.status === "error") add("sys", "Error: " + (step.error || "unknown"));
  sessionId = null; pendingCall = null;
}

async function answer(text, confirmed) {
  const p = pendingCall; pendingCall = null; $("confirm").classList.remove("on");
  await handle(await api(`/v1/agent/${sessionId}/result`, {
    results: [{ id: p.id, ok: true, message: p.kind === "confirm" && confirmed !== undefined ? (confirmed ? "confirmed" : "declined") : text }],
  }));
}

async function submit(text) {
  text = text.trim(); if (!text || busy) return;
  busy = true; $("txt").value = "";
  add("me", text);
  try {
    if (!store.get("token")) await register();
    if (pendingCall && pendingCall.kind === "ask_user") await answer(text);
    else await handle(await api("/v1/agent/command", { transcript: text, locale: /[ঀ-৿]/.test(text) ? "bn" : "en", device_caps: { platform: "web" } }));
  } catch (e) { add("sys", String(e.message || e)); }
  busy = false;
}

// ---- voice input ----
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
let rec = null;
$("mic").onclick = () => {
  if (!SR) return add("sys", "Ei browser-e voice input nai. Likhe din.");
  if (rec) { rec.stop(); return; }
  rec = new SR(); rec.lang = sttLang; rec.interimResults = false; rec.maxAlternatives = 1;
  $("mic").classList.add("rec");
  rec.onresult = (e) => submit(e.results[0][0].transcript);
  rec.onerror = (e) => add("sys", "Mic error: " + e.error);
  rec.onend = () => { rec = null; $("mic").classList.remove("rec"); };
  rec.start();
};
function paintLang() { $("lang").textContent = sttLang === "bn-BD" ? "বাংলা" : "English"; }
$("lang").onclick = () => { sttLang = sttLang === "bn-BD" ? "en-US" : "bn-BD"; store.set("sttLang", sttLang); paintLang(); };
$("send").onclick = () => submit($("txt").value);
$("txt").onkeydown = (e) => { if (e.key === "Enter") submit($("txt").value); };
$("yes").onclick = () => answer("", true);
$("no").onclick = () => answer("", false);
$("cfg").onclick = () => $("dlg").showModal();
$("dlg").onclose = () => { store.set("code", $("code").value); store.set("token", ""); };
paintLang();
add("sys", "ALLEN ready. Bangla, English ba Banglish-e bolun.");
if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
