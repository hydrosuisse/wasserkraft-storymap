# -----------------------------------------------------------------------------
# storymap.R — helpers that recreate ArcGIS StoryMaps blocks (Summit theme)
# with htmltools + mapgl. Everything renders to static HTML, so the result can
# be hosted on GitHub Pages.
#
# Blocks:
#   sm_header()   white header bar with logo
#   sm_cover()    full-screen cover image with centred gradient title panel
#   sm_nav()      sticky navigation bar with section links
#   sm_map()      inline map block (mapgl widget) with caption
#   sm_image()    image block with caption
#   sm_sidecar()  "docked sidecar" / map tour: sticky map, scrolling text slides
#   sm_slide()    one slide of a sidecar, with the map view to fly to
#   sm_credits()  "Quellen" / credits table, sm_credit() for one row
#   sm_footer()   small footer
# -----------------------------------------------------------------------------

library(htmltools)

# Summit theme colours (ArcGIS StoryMaps standard theme reference)
summit <- list(
  background = "#FFFFFF",
  heading    = "#002625",
  paragraph  = "#304E4E",
  caption    = "#3D6665",
  accent1    = "#087F9B",
  accent2    = "#FC3B36",
  accent3    = "#126057"
)

# swisstopo light base map (free vector tiles, no API key).
# Alternative: mapgl::carto_style("positron") — close to Esri "Human Geography Light".
swisstopo_light <- "https://vectortiles.geo.admin.ch/styles/ch.swisstopo.lightbasemap.vt/style.json"

# swisstopo base map in colour: place names, relief shading, contour lines.
# Used for the 3D map tour (draped over swisstopo terrain, see sm_sidecar()).
swisstopo_color <- "https://vectortiles.geo.admin.ch/styles/ch.swisstopo.basemap.vt/style.json"

sm_header <- function(logo = NULL, logo_text = NULL, logo_href = NULL,
                      logo_alt = "") {
  brand <- if (!is.null(logo)) {
    tags$img(src = logo, alt = logo_alt, class = "sm-logo")
  } else {
    tags$span(class = "sm-logo-text", logo_text)
  }
  if (!is.null(logo_href)) brand <- tags$a(href = logo_href, target = "_blank",
                                           rel = "noopener", brand)
  tags$header(class = "sm-header", brand)
}

sm_cover <- function(title, summary = NULL, byline = NULL, date = NULL,
                     image, image_alt = "", credit = NULL) {
  tags$section(
    class = "sm-cover",
    tags$img(class = "sm-cover-img", src = image, alt = image_alt),
    tags$div(class = "sm-cover-gradient"),
    tags$div(
      class = "sm-cover-panel",
      tags$h1(class = "sm-cover-title", title),
      if (!is.null(summary)) tags$p(class = "sm-cover-summary", summary),
      if (!is.null(byline) || !is.null(date)) tags$p(
        class = "sm-cover-meta",
        byline, if (!is.null(byline) && !is.null(date)) HTML(" &middot; "), date
      )
    ),
    if (!is.null(credit)) tags$span(class = "sm-cover-credit", credit),
    tags$a(class = "sm-cover-scroll", href = "#sm-start",
           `aria-label` = "Weiterlesen", HTML("&#8964;"))
  )
}

# links: named character vector, names = section ids, values = labels
# e.g. c(einleitung = "Einleitung", karte = "Übersichtskarte")
sm_nav <- function(links) {
  tags$nav(
    class = "sm-nav", id = "sm-start", `aria-label` = "Inhalt",
    tags$ul(lapply(names(links), function(id) {
      tags$li(tags$a(href = paste0("#", id), `data-target` = id, links[[id]]))
    }))
  )
}

# width: "standard" (text column), "wide" (like StoryMaps "float/wide"),
#        "full" (edge to edge)
sm_map <- function(map, caption = NULL, width = c("wide", "standard", "full"),
                   height = "70vh") {
  width <- match.arg(width)
  map$height <- height
  tags$figure(
    class = paste0("sm-block sm-", width, " sm-map"),
    tags$div(class = "sm-map-frame", style = paste0("height:", height, ";"), map),
    if (!is.null(caption)) tags$figcaption(class = "sm-caption", HTML(caption))
  )
}

# zoom = TRUE: click opens the image enlarged (same viewer as sm_slide_image)
sm_image <- function(src, caption = NULL, alt = "",
                     width = c("standard", "wide", "full"), zoom = FALSE) {
  width <- match.arg(width)
  img <- tags$img(src = src, alt = alt, loading = "lazy")
  if (zoom) img <- tags$button(type = "button", class = "sm-zoom", `data-full` = src,
                               `aria-label` = paste("Bild vergrössern:", alt), img,
                               tags$span(class = "sm-zoom-icon", `aria-hidden` = "true",
                                         HTML("&#x2922;")))
  tags$figure(
    class = paste0("sm-block sm-", width, " sm-image"),
    img,
    if (!is.null(caption)) tags$figcaption(class = "sm-caption", HTML(caption))
  )
}

# One slide of a sidecar. `...` is the narrative (tags or markdown via
# htmltools::HTML(markdown::mark(...)) ). The map flies to center/zoom/etc.
# `show` / `hide`: layer ids to switch on/off when the slide becomes active.
sm_slide <- function(..., title = NULL, center = NULL, zoom = NULL,
                     pitch = NULL, bearing = NULL, show = NULL, hide = NULL,
                     duration = 2500) {
  view <- Filter(Negate(is.null), list(
    center = center, zoom = zoom, pitch = pitch, bearing = bearing,
    duration = duration
  ))
  tags$div(
    class = "sm-slide",
    `data-view` = jsonlite::toJSON(view, auto_unbox = TRUE),
    `data-show` = if (length(show)) paste(show, collapse = " "),
    `data-hide` = if (length(hide)) paste(hide, collapse = " "),
    tags$div(
      class = "sm-slide-card",
      if (!is.null(title)) tags$h3(title),
      ...
    )
  )
}

# Image inside a slide (or anywhere): shown as a thumbnail below the text,
# opens enlarged on click (Esc or click outside closes it). Several sm_slide_image()
# in one slide appear side by side; in the enlarged view, arrows page through them.
#   src     image file, e.g. "assets/rossens.jpg"
#   caption text under the image and in the enlarged view (HTML allowed)
#   alt     short description for screen readers (always fill in)
#   full    optional larger file for the enlarged view (default: src)
sm_slide_image <- function(src, caption = NULL, alt = "", full = src) {
  tags$figure(
    class = "sm-slide-figure",
    tags$button(
      type = "button", class = "sm-zoom", `data-full` = full,
      `aria-label` = paste("Bild vergrössern:", if (nzchar(alt)) alt else "Bild"),
      tags$img(src = src, alt = alt, loading = "lazy"),
      tags$span(class = "sm-zoom-icon", `aria-hidden` = "true", HTML("&#x2922;"))
    ),
    if (!is.null(caption)) tags$figcaption(class = "sm-caption", HTML(caption))
  )
}

# Docked sidecar: narrative on the left (or right), map pinned on the other side.
# terrain: NULL (flat) or "swisstopo" = 3D relief from swisstopo's terrain model
#   (ch.swisstopo.terrain.3d). It is loaded in the browser with the plugin in
#   assets/vendor/ and served to MapLibre as a 256 px raster-dem up to zoom 14
#   (about 7 m per pixel in Switzerland) - the finest level swisstopo publishes
#   for this layer. Coarser levels are used automatically when zoomed out.
# exaggeration: vertical exaggeration of the relief (1 = true scale).
.sm_counter <- new.env()
sm_sidecar <- function(map, ..., panel = c("left", "right"),
                       terrain = NULL, exaggeration = 1.3) {
  panel <- match.arg(panel)
  if (is.null(map$elementId)) {
    .sm_counter$n <- (if (is.null(.sm_counter$n)) 0 else .sm_counter$n) + 1
    map$elementId <- paste0("sm-tour-", .sm_counter$n)
  }
  map_id <- map$elementId
  map$width <- "100%"
  map$height <- "100%"
  tags$section(
    class = paste0("sm-sidecar sm-panel-", panel),
    `data-map` = map_id,
    `data-terrain` = terrain,
    `data-exaggeration` = if (!is.null(terrain)) exaggeration,
    tags$div(class = "sm-sidecar-media", map),
    tags$div(class = "sm-sidecar-narrative", ...)
  )
}

# Embed another page (chart page, Shiny app, ...) in a frame that
#  * loads only when the reader scrolls near it (lazy),
#  * shows a loading placeholder until the page is there,
#  * fits its height automatically if the embedded page reports it
#    (auto_height = TRUE; the BFE chart pages do this via assets/chart.js),
#    otherwise uses `height` (desktop) / `height_mobile` (< 860 px wide).
#  `load`: "lazy" = when the reader scrolls near it;
#          "after_page" = `delay_ms` after the story page has finished loading
#          (or earlier, if the reader scrolls to it first).
sm_frame <- function(src, title, height = "600px", height_mobile = height,
                     auto_height = FALSE, load = c("lazy", "after_page"),
                     delay_ms = 2000, caption = NULL, source = NULL,
                     loading_text = "Wird geladen …",
                     open_label = "In neuem Fenster öffnen",
                     width = c("wide", "standard", "full")) {
  width <- match.arg(width)
  load <- match.arg(load)
  tags$figure(
    class = paste0("sm-block sm-", width, " sm-frame"),
    tags$div(
      class = "sm-frame-box",
      style = sprintf("--sm-frame-h:%s;--sm-frame-h-mobile:%s;", height, height_mobile),
      tags$div(class = "sm-frame-loading", tags$span(class = "sm-spinner"),
               tags$span(loading_text)),
      tags$iframe(`data-src` = src, title = title, allow = "fullscreen",
                  `data-auto-height` = if (auto_height) "true",
                  `data-load` = load,
                  `data-delay` = if (load == "after_page") delay_ms)
    ),
    tags$figcaption(
      class = "sm-caption",
      if (!is.null(caption)) HTML(caption),
      if (!is.null(caption)) tags$br(),
      tags$span(class = "sm-source",
                if (!is.null(source)) HTML(paste0(source, " · ")),
                tags$a(href = src, target = "_blank", rel = "noopener", open_label))
    )
  )
}

sm_credit <- function(content, attribution) {
  tags$tr(tags$td(HTML(content)), tags$td(HTML(attribution)))
}

sm_credits <- function(...) {
  tags$table(class = "sm-credits", tags$tbody(...))
}

sm_footer <- function(text = NULL) {
  tags$footer(class = "sm-footer", if (!is.null(text)) HTML(text))
}
