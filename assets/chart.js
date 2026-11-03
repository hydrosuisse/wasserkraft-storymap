/* chart.js — tell the story page how tall this chart page is, so the
   embedding frame fits without a scrollbar. */
(function () {
  // narrow screens: hide the range buttons (they don't fit), zoom still works
  function compact() {
    if (!window.Plotly) return;
    var narrow = window.innerWidth < 600;
    document.querySelectorAll(".js-plotly-plot").forEach(function (gd) {
      var menus = (gd.layout && gd.layout.updatemenus) || [];
      if (menus.length && menus[0].visible !== !narrow) {
        Plotly.relayout(gd, { "updatemenus[0].visible": !narrow, "margin.t": narrow ? 16 : 52 });
      }
    });
  }
  window.addEventListener("load", function () { setTimeout(compact, 300); });
  window.addEventListener("resize", compact);

  if (window.parent === window) return;
  var last = 0;
  function send() {
    var h = Math.ceil(document.body.getBoundingClientRect().height);
    if (h !== last) {
      last = h;
      window.parent.postMessage({ type: "sm-frame-height", height: h }, "*");
    }
  }
  window.addEventListener("load", send);
  window.addEventListener("resize", send);
  if (window.ResizeObserver) new ResizeObserver(send).observe(document.body);
  setTimeout(send, 500);
  setTimeout(send, 2000);
})();
