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
    config(locale = "de-CH", displaylogo = FALSE, responsive = TRUE,
           modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d",
                                      "zoomIn2d", "zoomOut2d", "toggleSpikelines",
                                      "hoverClosestCartesian", "hoverCompareCartesian"))
}

bfe_xaxis <- function(...) {
  list(title = "", showgrid = FALSE, zeroline = FALSE,
       showline = TRUE, linecolor = "#333333", linewidth = 1,
       ticks = "outside", tickcolor = "#333333", ticklen = 4,
       hoverformat = "%-d. %B %Y", ...)
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
  mon <- c("Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez")
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
              name = "Min / Max der letzten 10 Jahre", legendgroup = "band",
              customdata = ~fiveYearMin,
              hovertemplate = "Min / Max 10 Jahre: %{customdata:.1f} – %{y:.1f} %<extra></extra>") |>
    add_trace(y = ~fiveYearMittelwert, type = "scatter", mode = "lines",
              line = list(color = col$mittel, width = 1.5), name = "Mittelwert",
              hovertemplate = "Mittelwert: %{y:.1f} %<extra></extra>") |>
    add_trace(y = ~speicherstandProzent, type = "scatter", mode = "lines",
              line = list(color = col$aktuell, width = 4), name = "Aktuell",
              connectgaps = FALSE, customdata = ~speicherstandGWh,
              hovertemplate = "Aktuell: %{y:.1f} % (%{customdata:,.0f} GWh)<extra></extra>") |>
    add_trace(y = ~historicalMinWithReserves, type = "scatter", mode = "lines",
              line = list(color = col$reserve, width = 1.5),
              name = "Minimum plus Wasserreserve", connectgaps = FALSE,
              hovertemplate = "Minimum plus Wasserreserve: %{y:.1f} %<extra></extra>") |>
    add_trace(y = ~historicalMin, type = "scatter", mode = "lines",
              line = list(color = col$histmin, width = 1.5),
              name = "Historisches Minimum",
              hovertemplate = "Historisches Minimum: %{y:.1f} %<extra></extra>") |>
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
      fillcolor = s[2], name = s[1],
      legendrank = as.numeric(s[3]),
      hovertemplate = paste0(s[1], ": %{y:.1f} GWh<extra></extra>")
    )
  }
  p <- p |> add_trace(
    y = ~stromverbrauch, type = "scatter", mode = "lines",
    line = list(color = "#000000", width = 2), name = "Landesverbrauch",
    legendrank = 1,
    hovertemplate = "Landesverbrauch: %{y:.1f} GWh<extra></extra>"
  )

  last  <- max(d$date[!is.na(d$eigenproduktion)])
  start <- seq(last, by = paste0("-", years, " years"), length.out = 2)[2]
  yrs   <- rev(seq(as.integer(format(last, "%Y")) - 2, as.integer(format(last, "%Y"))))
  yr_range <- function(y) list(as.character(as.Date(paste0(y, "-01-01"))),
                               as.character(min(as.Date(paste0(y, "-12-31")), last)))
  buttons <- c(
    list(list(label = "Gesamt", method = "relayout",
              args = list(list(xaxis.range = as.character(range(d$date)))))),
    lapply(rev(yrs), function(y) list(label = as.character(y), method = "relayout",
                                      args = list(list(xaxis.range = yr_range(y))))),
    list(list(label = paste(years, "Jahre"), method = "relayout",
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

# Write one chart as a standalone page (embedded in the story via sm_frame()).
# The page reports its height to the story so the frame fits exactly.
bfe_chart_page <- function(chart, file, title, updated = Sys.Date()) {
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
      tags$link(rel = "stylesheet", href = "../assets/chart.css")
    ),
    tags$main(class = "bfe-chart", chart),
    tags$p(class = "bfe-stand",
           sprintf("Stand: %s · Daten: Bundesamt für Energie BFE, ",
                   format(as.Date(updated), "%d.%m.%Y")),
           tags$a(href = "https://energiedashboard.admin.ch", target = "_blank",
                  rel = "noopener", "energiedashboard.admin.ch")),
    tags$script(src = "../assets/chart.js")
  )
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  htmltools::save_html(page, file, libdir = "lib", lang = "de")
  invisible(file)
}
