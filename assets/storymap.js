/* storymap.js — navigation highlighting + sidecar map tours for mapgl maps.
   Static page; no server needed. */
(function () {
  "use strict";

  var reduceMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- sticky nav: shadow + active section ------------------------ */
  function initNav() {
    var nav = document.querySelector(".sm-nav");
    if (!nav) return;

    var sentinel = document.createElement("div");
    nav.parentNode.insertBefore(sentinel, nav);
    new IntersectionObserver(function (e) {
      nav.classList.toggle("is-stuck", !e[0].isIntersecting);
    }).observe(sentinel);

    var links = Array.prototype.slice.call(nav.querySelectorAll("a[data-target]"));
    var targets = links
      .map(function (a) { return document.getElementById(a.dataset.target); })
      .filter(Boolean);

    function update() {
      var line = window.innerHeight * 0.3;
      var current = null;
      targets.forEach(function (t) {
        if (t.getBoundingClientRect().top <= line) current = t.id;
      });
      links.forEach(function (a) {
        var on = a.dataset.target === current;
        a.classList.toggle("is-active", on);
        if (on && a.scrollIntoView && nav.scrollWidth > nav.clientWidth) {
          a.scrollIntoView({ block: "nearest", inline: "center" });
        }
      });
    }
    window.addEventListener("scroll", throttle(update, 100), { passive: true });
    update();
  }

  /* ---------- sidecar map tours ------------------------------------------ */
  // Resolve the maplibre/mapbox Map instance behind a mapgl htmlwidget.
  function whenMapReady(id, cb) {
    var tries = 0;
    (function poll() {
      var el = document.getElementById(id);
      var map = null;
      if (window.HTMLWidgets) {
        var w = HTMLWidgets.find("#" + id);
        if (w && typeof w.getMap === "function") map = w.getMap();
      }
      if (!map && el) map = el.map;
      if (map) {
        // mapgl adds its layers in the map's "load" handler; wait until idle
        if (map.loaded && map.loaded()) return cb(map);
        return map.once("idle", function () { cb(map); });
      }
      if (tries++ < 200) setTimeout(poll, 100);
    })();
  }

  function setVisibility(map, ids, value) {
    if (!ids) return;
    ids.split(/\s+/).forEach(function (layer) {
      if (layer && map.getLayer(layer)) {
        map.setLayoutProperty(layer, "visibility", value);
      }
    });
  }

  function applySlide(map, slide) {
    var view = {};
    try { view = JSON.parse(slide.dataset.view || "{}"); } catch (e) {}
    setVisibility(map, slide.dataset.hide, "none");
    setVisibility(map, slide.dataset.show, "visible");
    if (view.center || view.zoom != null) {
      var opts = {};
      ["center", "zoom", "pitch", "bearing"].forEach(function (k) {
        if (view[k] != null) opts[k] = view[k];
      });
      if (reduceMotion) map.jumpTo(opts);
      else { opts.duration = view.duration || 2500; opts.essential = true; map.flyTo(opts); }
    }
  }

  function initSidecars() {
    document.querySelectorAll(".sm-sidecar").forEach(function (sc) {
      var slides = sc.querySelectorAll(".sm-slide");
      var mapId = sc.dataset.map;
      var map = null, pending = null, active = null;

      whenMapReady(mapId, function (m) {
        map = m;
        if (map.resize) map.resize();
        if (pending) applySlide(map, pending);
      });

      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting || e.target === active) return;
          active = e.target;
          slides.forEach(function (s) { s.classList.toggle("is-active", s === active); });
          if (map) applySlide(map, active); else pending = active;
        });
      }, { rootMargin: "-45% 0px -45% 0px" });
      slides.forEach(function (s) { io.observe(s); });
      if (slides[0]) pending = slides[0];
    });
  }

  /* ---------- lazy frames (charts, Shiny app) ----------------------------- */
  function initFrames() {
    var frames = Array.prototype.slice.call(document.querySelectorAll(".sm-frame iframe[data-src]"));
    if (!frames.length) return;

    function load(ifr) {
      if (ifr.src) return;
      ifr.addEventListener("load", function () {
        ifr.closest(".sm-frame-box").classList.add("is-loaded");
      });
      ifr.src = ifr.dataset.src;
    }

    // frames with data-load="after_page": start `data-delay` ms after the page
    // (images, maps, scripts) has finished loading
    function afterPage() {
      frames.forEach(function (f) {
        if (f.dataset.load === "after_page") {
          setTimeout(function () { load(f); }, Number(f.dataset.delay || 2000));
        }
      });
    }
    if (document.readyState === "complete") afterPage();
    else window.addEventListener("load", afterPage);

    // scrolling: lazy frames start 800 px before they come into view;
    // after_page frames only if the reader actually reaches them before the delay
    if ("IntersectionObserver" in window) {
      function observer(margin) {
        var io = new IntersectionObserver(function (entries) {
          entries.forEach(function (e) {
            if (e.isIntersecting) { load(e.target); io.unobserve(e.target); }
          });
        }, { rootMargin: margin });
        return io;
      }
      var ioLazy = observer("800px 0px"), ioVisible = observer("0px");
      frames.forEach(function (f) {
        (f.dataset.load === "after_page" ? ioVisible : ioLazy).observe(f);
      });
    } else {
      frames.forEach(load);
    }

    // embedded pages report their height (assets/chart.js)
    window.addEventListener("message", function (ev) {
      var d = ev.data;
      if (!d || d.type !== "sm-frame-height" || !d.height) return;
      frames.forEach(function (f) {
        if (f.contentWindow === ev.source && f.dataset.autoHeight === "true") {
          f.closest(".sm-frame-box").style.height = d.height + "px";
        }
      });
    });
  }

  function throttle(fn, ms) {
    var t = 0;
    return function () {
      var now = Date.now();
      if (now - t > ms) { t = now; fn(); }
    };
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () { initNav(); initSidecars(); initFrames(); });
  } else { initNav(); initSidecars(); initFrames(); }
})();
