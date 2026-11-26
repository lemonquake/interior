// Sleep — game page: live squad count, download sizes and versions, release notes, the image viewer, reveal on scroll.
(function () {
  "use strict";

  // Header turns solid once the hero is behind it.
  var top = document.querySelector(".top");
  function onScroll() { top.classList.toggle("solid", window.scrollY > 40); }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Sections drift in as they come into view.
  var reveal = document.querySelectorAll(".chapter-head, .wide, .features article, .gallery a, .faces figure, .boss, .mosaic a, .dl-card, .howto, .pitch-grid > div");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px" });
    reveal.forEach(function (el, i) {
      el.classList.add("reveal");
      el.style.transitionDelay = (i % 6) * 60 + "ms";
      io.observe(el);
    });
  }

  // Click a picture: see it full size. Esc, click or × closes it.
  var layer = document.querySelector("[data-zoom-layer]");
  var big = layer.querySelector("img");
  function closeZoom() { layer.hidden = true; big.removeAttribute("src"); document.body.style.overflow = ""; }
  document.querySelectorAll("[data-zoom]").forEach(function (a) {
    a.addEventListener("click", function (ev) {
      ev.preventDefault();
      var img = a.querySelector("img");
      big.src = a.getAttribute("href");
      big.alt = img ? img.alt : "";
      layer.hidden = false;
      document.body.style.overflow = "hidden";
    });
  });
  layer.addEventListener("click", closeZoom);
  document.addEventListener("keydown", function (ev) { if (ev.key === "Escape" && !layer.hidden) closeZoom(); });

  function size(n) {
    if (!n) return "";
    return n >= 1e9 ? (n / 1e9).toFixed(2) + " GB" : n >= 1e6 ? Math.round(n / 1e6) + " MB" : Math.max(1, Math.round(n / 1e3)) + " KB";
  }
  function text(el, value) { if (el) el.textContent = value; }

  // Squads out tonight, from the relay.
  var live = document.querySelector("[data-live]");
  function refreshLive() {
    fetch("api/rooms", { cache: "no-store" }).then(function (r) { return r.json(); }).then(function (d) {
      var rooms = (d.rooms || []).length;
      var players = d.players || 0;
      live.classList.add("on");
      text(live.querySelector("[data-live-text]"), rooms === 0
        ? "Server online. No squads out right now: host the first one."
        : rooms + (rooms === 1 ? " squad" : " squads") + " out tonight · " + players + (players === 1 ? " survivor" : " survivors") + " playing");
    }).catch(function () {
      live.classList.remove("on");
      text(live.querySelector("[data-live-text]"), "Couldn't reach the Sleep server just now.");
    });
  }
  refreshLive();
  setInterval(refreshLive, 30000);

  // What can be downloaded, its version and size, and the latest release notes.
  fetch("downloads/index.json", { cache: "no-store" }).then(function (r) { return r.json(); }).then(function (d) {
    if (d.launcher) {
      document.querySelectorAll('[data-dl-meta="launcher"]').forEach(function (el) {
        el.textContent = "Launcher " + d.launcher.version + " · " + (d.game ? "game " + d.game.version + ", " + size(d.game.size) : "installs and updates the game");
      });
      document.querySelectorAll('[data-dl-meta-long="launcher"]').forEach(function (el) {
        el.textContent = "Windows 10 or 11, 64-bit" + (d.game ? " · game " + d.game.version + " (" + size(d.game.size) + ")" : "");
      });
    }
    if (d.android) {
      document.querySelectorAll('[data-dl="android"]').forEach(function (el) { el.classList.remove("soon"); el.setAttribute("href", el.getAttribute("data-href")); });
      document.querySelectorAll("[data-apk-label]").forEach(function (el) { el.textContent = "Download the APK"; });
      document.querySelectorAll('[data-dl-meta="android"]').forEach(function (el) { el.textContent = "APK " + d.android.version + " · " + size(d.android.size); });
      document.querySelectorAll('[data-dl-meta-long="android"]').forEach(function (el) { el.textContent = "Android 7.0 or newer · " + d.android.version + " (" + size(d.android.size) + ")"; });
    }
    var notes = document.querySelector("[data-notes]");
    if (d.game && notes) {
      text(document.querySelector("[data-game-version]"), "Version " + d.game.version + " · " + (d.game.published || "").slice(0, 10));
      notes.innerHTML = "";
      (d.game.notes || []).slice(0, 8).forEach(function (n) {
        var li = document.createElement("li");
        li.textContent = n;
        notes.appendChild(li);
      });
    }
  }).catch(function () {});
})();
