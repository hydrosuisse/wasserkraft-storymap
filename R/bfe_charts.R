# -----------------------------------------------------------------------------
# bfe_charts.R — two Energie-Dashboard (BFE) charts rebuilt with plotly,
# imitating the dashboard's look (colours, stacking order, legend, axes).
#
#  * Füllstände Speicherseen  energiedashboard.admin.ch/strom/fuellstaende-speicherseen
#  * Produktion & Verbrauch   energiedashboard.admin.ch/strom/produktion
#
# Data: the same JSON endpoints the dashboard loads. They are downloaded when
# the site is built (GitHub Actions, daily). Each successful download is kept in
# data/snapshot/ and committed, so a build still works if the API is briefly down.
# Attribution required: "Bundesamt für Energie BFE, energiedashboard.admin.ch".
# -----------------------------------------------------------------------------

library(plotly)
library(htmltools)

bfe_api <- "https://energiedashboard.admin.ch/api/strom"

# Download one endpoint; on failure fall back to the last good snapshot.
bfe_data <- function(endpoint, snapshot_dir = "data/snapshot") {
  dir.create(snapshot_dir, showWarnings = FALSE, recursive = TRUE)
  snap <- file.path(snapshot_dir, paste0(gsub("[^A-Za-z0-9]+", "_", endpoint), ".json"))
  tmp <- tempfile(fileext = ".json")
  tryCatch({
    utils::download.file(paste0(bfe_api, "/", endpoint), tmp, quiet = TRUE,
                         mode = "wb", method = "libcurl",
                         headers = c(Accept = "application/json",
                                     `User-Agent` = "hydrosuisse wasserkraft-storymap (GitHub Actions)"))
    jsonlite::fromJSON(tmp)                     # validate before replacing
    file.copy(tmp, snap, overwrite = TRUE)
    message("BFE API: ", endpoint, " updated")
  }, error = function(e) {
    message("BFE API: ", endpoint, " not reachable (", conditionMessage(e),
            ") - using snapshot ", snap)
  })
  if (!file.exists(snap)) stop("No data for ", endpoint, " and no snapshot in ", snap)
  jsonlite::fromJSON(snap)
}

# ---- shared look (Energie-Dashboard) -----------------------------------------
# Frutiger (as in the dashboard): used if installed on the reader's computer
# ("Frutiger LT Com", "Frutiger Neue", "Frutiger") or if licensed web-font files are
# placed in assets/fonts/ (see assets/chart.css). Otherwise Roboto is used.
bfe_font <- list(family = "'Frutiger Web', 'Frutiger LT Com', 'Frutiger Neue', Frutiger, Roboto, 'Helvetica Neue', Arial, sans-serif",
                 size = 11, color = "#000000")
bfe_bg <- "#F9FAFB"

# ---- language of the chart labels: "de" (default) or "fr" ------------------------
# build.R sets bfe_lang <- "fr" before writing the French chart pages (charts/fr/).
bfe_lang <- "de"
bfe_fr <- c(
  "Min / Max der letzten 10 Jahre" = "Min / max des 10 dernières années",
  "Min / Max 10 Jahre" = "Min / max 10 ans",
  "Mittelwert" = "Moyenne",
  "Aktuell" = "Actuel",
  "Minimum plus Wasserreserve" = "Minimum plus réserve hydroélectrique",
  "Historisches Minimum" = "Minimum historique",
  "Laufwasser" = "Fil de l\u2019eau",
  "Kernenergie" = "Nucléaire",
  "Photovoltaik" = "Photovoltaïque",
  "Wind" = "Éolien",
  "Speicherwasser" = "Accumulation",
  "Thermische (inkl. KVA)" = "Thermique (y c. UIOM)",
  "Nettoimport" = "Importations nettes",
  "Nettoexport" = "Exportations nettes",
  "Landesverbrauch" = "Consommation nationale",
  "Landesproduktion" = "Production nationale",
  "Nettoexport (Produktion > Verbrauch)" = "Exportations nettes (production > consommation)",
  "Nettoimport (Verbrauch > Produktion)" = "Importations nettes (consommation > production)",
  "Export" = "Exportation",
  "Saldo (Export \u2013 Import)" = "Solde (exportations \u2013 importations)",
  "Gesamt" = "Tout",
  "Jahre" = "ans",
  "Landesproduktion und Landesverbrauch" = "Production et consommation nationales",
  "Nettoexport (+) nach Energieträger, anteilig zum Produktionsmix, und Nettoimport (\u2013)" =
    "Exportations nettes (+) par agent énergétique, au prorata du mix de production, et importations nettes (\u2013)",
  "Stand" = "État",
  "Daten" = "Données",
  "Bundesamt für Energie BFE" = "Office fédéral de l\u2019énergie OFEN"
)
tl <- function(x) if (identical(bfe_lang, "fr") && !is.na(bfe_fr[x])) unname(bfe_fr[x]) else x

bfe_layout <- function(p, ...) {
  p |>
    layout(
      font = bfe_font,
      paper_bgcolor = bfe_bg, plot_bgcolor = bfe_bg,
      hovermode = "x unified",
      hoverlabel = list(bgcolor = "#FFFFFF", bordercolor = "#CCCCCC",
                        font = list(family = bfe_font$family, size = 12, color = "#000")),
      legend = list(orientation = "h", x = 0, xanchor = "left", y = -0.12,
                    yanchor = "top", font = list(size = 11), itemclick = "toggle",
                    itemdoubleclick = "toggleothers", traceorder = "normal"),
      ...
    ) |>
    config(locale = if (identical(bfe_lang, "fr")) "fr" else "de-CH", displaylogo = FALSE, responsive = TRUE,
           modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d",
                                      "zoomIn2d", "zoomOut2d", "toggleSpikelines",
                                      "hoverClosestCartesian", "hoverCompareCartesian"))
}

bfe_xaxis <- function(...) {
  list(title = "", showgrid = FALSE, zeroline = FALSE,
       showline = TRUE, linecolor = "#333333", linewidth = 1,
       ticks = "outside", tickcolor = "#333333", ticklen = 4,
       hoverformat = if (identical(bfe_lang, "fr")) "%-d %B %Y" else "%-d. %B %Y", ...)
}
bfe_yaxis <- function(...) {
  list(title = "", gridcolor = "#DDDDDD", gridwidth = 1, zeroline = FALSE,
       showline = FALSE, ticks = "", ...)
}

# ---- Füllstände Speicherseen -------------------------------------------------
# region: "totalCH", "graubuenden", "wallis", "tessin", "uebrigCH"
bfe_speicherseen_chart <- function(data, region = "totalCH", height = 460) {
  d <- data[[region]]$entries
  d$date <- as.Date(d$date)

  # monthly ticks, year shown under the first and last three months (as in the dashboard)
  mon <- if (identical(bfe_lang, "fr"))
    c("janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc.") else
    c("Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez")
  tv <- seq(as.Date(format(min(d$date), "%Y-%m-01")), max(d$date), by = "month")
  tv <- tv[tv >= min(d$date) - 3]
  show_year <- seq_along(tv) <= 3 | seq_along(tv) > length(tv) - 3
  ticks <- list(vals = as.character(tv),
                text = paste0(mon[as.integer(format(tv, "%m"))],
                              ifelse(show_year, paste0("<br>", format(tv, "%Y")), "")))

  col <- list(band = "rgba(0,45,243,0.15)", aktuell = "#002DF3",
              mittel = "#A6A6A6", reserve = "#EB9F46", histmin = "#C76043")

  plot_ly(d, x = ~date, height = height) |>
    add_trace(y = ~fiveYearMin, type = "scatter", mode = "lines",
              line = list(width = 0, color = col$band), hoverinfo = "skip",
              showlegend = FALSE, legendgroup = "band") |>
    add_trace(y = ~fiveYearMax, type = "scatter", mode = "lines",
              fill = "tonexty", fillcolor = col$band,
              line = list(width = 0, color = col$band),
              name = tl("Min / Max der letzten 10 Jahre"), legendgroup = "band",
              customdata = ~fiveYearMin,
              hovertemplate = paste0(tl("Min / Max 10 Jahre"), ": %{customdata:.1f} – %{y:.1f} %<extra></extra>")) |>
    add_trace(y = ~fiveYearMittelwert, type = "scatter", mode = "lines",
              line = list(color = col$mittel, width = 1.5), name = tl("Mittelwert"),
              hovertemplate = paste0(tl("Mittelwert"), ": %{y:.1f} %<extra></extra>")) |>
    add_trace(y = ~speicherstandProzent, type = "scatter", mode = "lines",
              line = list(color = col$aktuell, width = 4), name = tl("Aktuell"),
              connectgaps = FALSE, customdata = ~speicherstandGWh,
              hovertemplate = paste0(tl("Aktuell"), ": %{y:.1f} % (%{customdata:,.0f} GWh)<extra></extra>")) |>
    add_trace(y = ~historicalMinWithReserves, type = "scatter", mode = "lines",
              line = list(color = col$reserve, width = 1.5),
              name = tl("Minimum plus Wasserreserve"), connectgaps = FALSE,
              hovertemplate = paste0(tl("Minimum plus Wasserreserve"), ": %{y:.1f} %<extra></extra>")) |>
    add_trace(y = ~historicalMin, type = "scatter", mode = "lines",
              line = list(color = col$histmin, width = 1.5),
              name = tl("Historisches Minimum"),
              hovertemplate = paste0(tl("Historisches Minimum"), ": %{y:.1f} %<extra></extra>")) |>
    bfe_layout(
      xaxis = bfe_xaxis(tickmode = "array", tickvals = ticks$vals, ticktext = ticks$text,
                        range = range(d$date) + c(-3, 3)),
      yaxis = bfe_yaxis(range = c(0, 102), ticksuffix = "%", dtick = 20,
                        fixedrange = TRUE),
      margin = list(l = 44, r = 16, t = 20, b = 10)
    )
}

# ---- Produktion und Landesverbrauch -----------------------------------------
bfe_produktion_chart <- function(data, years = 5, height = 420) {
  d <- data$entries
  d$date <- as.Date(d$date)

  # stacked bottom -> top as in the dashboard; legend order as in the dashboard
  series <- list(
    flusskraft    = c("Laufwasser",              "#1B84CB", 8),
    kernkraft     = c("Kernenergie",             "#FCCC32", 7),
    photovoltaik  = c("Photovoltaik",            "#ED652E", 6),
    wind          = c("Wind",                    "#C740B9", 5),
    speicherkraft = c("Speicherwasser",          "#59BBA4", 4),
    thermische    = c("Thermische (inkl. KVA)",  "#209F4A", 3),
    nettoimporte  = c("Nettoimport",             "#EB9F46", 2)
  )

  p <- plot_ly(d, x = ~date, height = height)
  for (k in names(series)) {
    s <- series[[k]]
    y <- d[[k]]
    if (k == "nettoimporte") y <- pmax(y, 0)    # net exports are not stacked
    p <- p |> add_trace(
      y = y, type = "scatter", mode = "none", stackgroup = "produktion",
      fillcolor = s[2], name = tl(s[1]),
      legendrank = as.numeric(s[3]),
      hovertemplate = paste0(tl(s[1]), ": %{y:.1f} GWh<extra></extra>")
    )
  }
  p <- p |> add_trace(
    y = ~stromverbrauch, type = "scatter", mode = "lines",
    line = list(color = "#000000", width = 2), name = tl("Landesverbrauch"),
    legendrank = 1,
    hovertemplate = paste0(tl("Landesverbrauch"), ": %{y:.1f} GWh<extra></extra>")
  )

  last  <- max(d$date[!is.na(d$eigenproduktion)])
  start <- seq(last, by = paste0("-", years, " years"), length.out = 2)[2]
  yrs   <- rev(seq(as.integer(format(last, "%Y")) - 2, as.integer(format(last, "%Y"))))
  yr_range <- function(y) list(as.character(as.Date(paste0(y, "-01-01"))),
                               as.character(min(as.Date(paste0(y, "-12-31")), last)))
  buttons <- c(
    list(list(label = tl("Gesamt"), method = "relayout",
              args = list(list(xaxis.range = as.character(range(d$date)))))),
    lapply(rev(yrs), function(y) list(label = as.character(y), method = "relayout",
                                      args = list(list(xaxis.range = yr_range(y))))),
    list(list(label = paste(years, tl("Jahre")), method = "relayout",
              args = list(list(xaxis.range = as.character(c(start, last))))))
  )

  p |>
    bfe_layout(
      xaxis = bfe_xaxis(range = as.character(c(start, last))),
      yaxis = bfe_yaxis(ticksuffix = " GWh", rangemode = "tozero"),
      updatemenus = list(list(
        type = "buttons", direction = "right", showactive = TRUE,
        active = length(buttons) - 1, buttons = buttons,
        x = 0, xanchor = "left", y = 1.03, yanchor = "bottom",
        bgcolor = "#E6E9EC", bordercolor = bfe_bg, borderwidth = 0,
        font = list(size = 12, color = "#000"), pad = list(r = 6, t = 0, l = 0)
      )),
      margin = list(l = 64, r = 16, t = 52, b = 10)
    )
}

# ---- Produktion, Landesverbrauch und Aussenhandel (two panels) ---------------
# Top:    Landesproduktion (solid) against Landesverbrauch incl. storage pumps
#         (dotted); the gap is grey for net export, orange for net import.
# Bottom: net trade per day. Net exports (up) are split by source in proportion
#         to that day's domestic production mix; net imports (down) in one colour.
#         Export share of source k on day t:  export_t * prod_k,t / sum_k prod_k,t
bfe_produktion_handel_chart <- function(data, years = 5, height = 620) {
  d <- data$entries
  d$date <- as.Date(d$date)

  # sources, bottom -> top, colours as in the Energie-Dashboard
  src <- list(
    flusskraft    = c("Laufwasser",             "#1B84CB"),
    kernkraft     = c("Kernenergie",            "#FCCC32"),
    photovoltaik  = c("Photovoltaik",           "#ED652E"),
    wind          = c("Wind",                   "#C740B9"),
    speicherkraft = c("Speicherwasser",         "#59BBA4"),
    thermische    = c("Thermische (inkl. KVA)", "#209F4A")
  )
  prod_mat <- sapply(names(src), function(k) { v <- d[[k]]; v[is.na(v)] <- 0; v })
  produktion <- rowSums(prod_mat)
  has_data <- !is.na(d$nettoimporte) & !is.na(d$stromverbrauch) & produktion > 0
  d <- d[has_data, ]; prod_mat <- prod_mat[has_data, , drop = FALSE]
  produktion <- produktion[has_data]

  nettoexport <- -d$nettoimporte                       # + = export, - = import
  export  <- pmax(nettoexport, 0)
  import  <- pmin(nettoexport, 0)
  anteil  <- prod_mat / produktion                     # daily production mix
  export_mat <- anteil * export                        # export by source

  # --- top panel: Landesproduktion vs. Landesverbrauch, gap filled ---
  # grey  = production above consumption (net export)
  # orange = consumption above production (net import, same colour as below)
  # Hover: one row "Nettoexport: … GWh" or "Nettoimport: … GWh" per day (see hover_trace).
  verbrauch <- d$stromverbrauch
  unten <- pmin(produktion, verbrauch)
  gwh <- function(x) paste0(formatC(x, format = "f", digits = 1, decimal.mark = ","), " GWh")
  ist_export <- produktion >= verbrauch
  fill_trace <- function(p, upper, colour, name, group) {
    p |>
      add_trace(y = unten, type = "scatter", mode = "lines",           # lower edge
                line = list(width = 0, color = "rgba(0,0,0,0)"),
                hoverinfo = "skip", showlegend = FALSE, legendgroup = group) |>
      add_trace(y = upper, type = "scatter", mode = "lines", fill = "tonexty",
                fillcolor = colour, line = list(width = 0, color = colour),
                hoverinfo = "skip", name = tl(name), legendgroup = group)
  }
  # hover-only rows: values only on the days where the area exists (NA elsewhere),
  # with a small square in the area's colour in front of the text
  hover_trace <- function(p, aktiv, wert, colour, label, group) {
    p |> add_trace(
      y = ifelse(aktiv, pmax(produktion, verbrauch), NA), type = "scatter", mode = "lines",
      line = list(width = 0, color = "rgba(0,0,0,0)"), showlegend = FALSE, legendgroup = group,
      name = tl(label), connectgaps = FALSE,
      text = paste0("<span style='color:", colour, "'>\u25A0</span> <b>", tl(label), ": ", gwh(wert), "</b>"),
      hovertemplate = "%{text}<extra></extra>")
  }
  top <- plot_ly(x = d$date) |>
    fill_trace(ifelse(ist_export, produktion, unten), "#BDBDBD",
               "Nettoexport (Produktion > Verbrauch)", "export_area") |>
    fill_trace(ifelse(!ist_export, verbrauch, unten), "#EB9F46",
               "Nettoimport (Verbrauch > Produktion)", "import") |>
    hover_trace(ist_export, produktion - verbrauch, "#9E9E9E", "Nettoexport", "export_area") |>
    hover_trace(!ist_export, verbrauch - produktion, "#EB9F46", "Nettoimport", "import") |>
    add_trace(y = produktion, type = "scatter", mode = "lines",
              line = list(color = "#000000", width = 1.5), name = tl("Landesproduktion"),
              legendgroup = "prodline",
              hovertemplate = paste0(tl("Landesproduktion"), ": %{y:.1f} GWh<extra></extra>")) |>
    add_trace(y = verbrauch, type = "scatter", mode = "lines",
              line = list(color = "#000000", width = 1.5, dash = "dot"),
              name = tl("Landesverbrauch"), legendgroup = "verbrauch",
              hovertemplate = paste0(tl("Landesverbrauch"), ": %{y:.1f} GWh<extra></extra>"))

  # --- bottom panel ---
  bottom <- plot_ly(x = d$date)
  for (k in names(src)) {
    bottom <- bottom |> add_trace(
      y = export_mat[, k], type = "scatter", mode = "none", stackgroup = "export",
      fillcolor = src[[k]][2], name = tl(src[[k]][1]), legendgroup = k,
      hovertemplate = paste0(tl("Export"), " ", tl(src[[k]][1]), ": %{y:.1f} GWh<extra></extra>")
    )
  }
  bottom <- bottom |>
    add_trace(y = import, type = "scatter", mode = "none", fill = "tozeroy",
              fillcolor = "#EB9F46", name = tl("Nettoimport"), legendgroup = "import",
              showlegend = FALSE,
              hovertemplate = paste0(tl("Nettoimport"), ": %{y:.1f} GWh<extra></extra>")) |>
    # invisible: only adds the balance to the hover box
    add_trace(y = nettoexport, type = "scatter", mode = "lines",
              line = list(width = 0, color = "rgba(0,0,0,0)"), showlegend = FALSE,
              name = "Saldo", hovertemplate = paste0(tl("Saldo (Export \u2013 Import)"), ": %{y:.1f} GWh<extra></extra>"))

  # --- range buttons (as in the dashboard) ---
  last  <- max(d$date)
  start <- seq(last, by = paste0("-", years, " years"), length.out = 2)[2]
  yrs   <- seq(as.integer(format(last, "%Y")) - 2, as.integer(format(last, "%Y")))
  rng <- function(a, b) list(xaxis.range = as.character(c(a, b)))
  buttons <- c(
    list(list(label = tl("Gesamt"), method = "relayout", args = list(rng(min(d$date), last)))),
    lapply(yrs, function(y) list(label = as.character(y), method = "relayout",
      args = list(rng(as.Date(paste0(y, "-01-01")), min(as.Date(paste0(y, "-12-31")), last))))),
    list(list(label = paste(years, tl("Jahre")), method = "relayout", args = list(rng(start, last))))
  )

  panel_title <- function(text, y) list(
    text = text, x = 0, xref = "paper", xanchor = "left", y = y, yref = "paper",
    yanchor = "bottom", showarrow = FALSE, font = list(size = 12, color = "#000")
  )

  p <- subplot(top, bottom, nrows = 2, shareX = TRUE, heights = c(0.5, 0.5),
               margin = 0.07)
  p$height <- height
  p <- p |>
    bfe_layout(
      xaxis  = bfe_xaxis(range = as.character(c(start, last))),
      yaxis  = bfe_yaxis(ticksuffix = " GWh", rangemode = "tozero"),
      yaxis2 = bfe_yaxis(ticksuffix = " GWh", zeroline = TRUE, zerolinecolor = "#333333",
                         zerolinewidth = 1),
      annotations = list(
        panel_title(paste0("<b>", tl("Landesproduktion und Landesverbrauch"), "</b>"), 1.0),
        panel_title(paste0("<b>", tl("Nettoexport (+) nach Energieträger, anteilig zum Produktionsmix, und Nettoimport (\u2013)"), "</b>"), 0.465)
      ),
      updatemenus = list(list(
        type = "buttons", direction = "right", showactive = TRUE,
        active = length(buttons) - 1, buttons = buttons,
        x = 0, xanchor = "left", y = 1.06, yanchor = "bottom",
        bgcolor = "#E6E9EC", bordercolor = bfe_bg, borderwidth = 0,
        font = list(size = 12, color = "#000"), pad = list(r = 6, t = 0, l = 0)
      )),
      legend = list(orientation = "h", x = 0, xanchor = "left", y = -0.06,
                    yanchor = "top", font = list(size = 11), traceorder = "normal"),
      margin = list(l = 64, r = 16, t = 70, b = 10)
    )

  # plotly stores hoverinfo = "skip" once per day; in "x unified" hover that still
  # leaves empty rows (grey/orange swatches without text). Make it one scalar value.
  p <- plotly_build(p)
  for (i in seq_along(p$x$data)) {
    h <- p$x$data[[i]]$hoverinfo
    if (!is.null(h) && length(h) > 1 && isTRUE(all(unlist(h) == "skip", na.rm = TRUE))) p$x$data[[i]]$hoverinfo <- "skip"
  }
  p
}

# Write one chart as a standalone page (embedded in the story via sm_frame()).
# The page reports its height to the story so the frame fits exactly.
bfe_chart_page <- function(chart, file, title, updated = Sys.Date(), assets = "../assets") {
  chart$sizingPolicy$browser$fill <- FALSE      # no viewport-filling inside the frame
  chart$sizingPolicy$browser$padding <- 0
  chart$width <- "100%"
  page <- tagList(
    tags$head(
      tags$meta(charset = "utf-8"),
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$title(title),
      tags$link(rel = "stylesheet",
                href = "https://fonts.googleapis.com/css2?family=Roboto:wght@400;500&display=swap"),
      tags$link(rel = "stylesheet", href = file.path(assets, "chart.css"))
    ),
    tags$main(class = "bfe-chart", chart),
    tags$p(class = "bfe-stand",
           sprintf(if (identical(bfe_lang, "fr")) "%s\u00A0: %s · %s\u00A0: %s, " else "%s: %s · %s: %s, ",
                   tl("Stand"), format(as.Date(updated), "%d.%m.%Y"), tl("Daten"), tl("Bundesamt für Energie BFE")),
           tags$a(href = "https://energiedashboard.admin.ch", target = "_blank",
                  rel = "noopener", "energiedashboard.admin.ch")),
    tags$script(src = file.path(assets, "chart.js"))
  )
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  htmltools::save_html(page, file, libdir = "lib", lang = if (identical(bfe_lang, "fr")) "fr" else "de")
  invisible(file)
}
