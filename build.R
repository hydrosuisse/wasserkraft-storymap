# Build the whole site into _site/  (run locally or by GitHub Actions)
#   Rscript build.R
# Preview: servr::httd("_site")  or  python3 -m http.server -d _site

# read all sources as UTF-8 regardless of the machine's locale
Sys.setlocale("LC_CTYPE", "C.UTF-8")
options(encoding = "UTF-8")
source("R/bfe_charts.R", encoding = "UTF-8")

unlink("_site", recursive = TRUE)
dir.create("_site/charts", recursive = TRUE)

# 1) BFE charts: fresh data (fallback: data/snapshot/), one page each ----------
speicher <- bfe_data("v2/fuellungsgrad-speicherseen")
bfe_chart_page(bfe_speicherseen_chart(speicher), "_site/charts/speicherseen.html",
               title = "Füllstände der Speicherseen",
               updated = speicher$totalCH$currentEntry$date)

produktion <- bfe_data("strom-produktion-import-verbrauch")

bfe_chart_page(bfe_produktion_handel_chart(produktion, years = 5), "_site/charts/produktion.html",
               title = "Landesproduktion, Landesverbrauch und Aussenhandel",
               updated = produktion$currentEntry$date)

bfe_chart_page(bfe_produktion_chart(produktion, years = 5), "_site/charts/produktion_bfe.html",
               title = "Stromproduktion nach Energieträger",
               updated = produktion$currentEntry$date)

# 1b) the same charts with French labels, in charts/fr/ ---------------------------
dir.create("_site/charts/fr", recursive = TRUE)
bfe_lang <- "fr"
bfe_chart_page(bfe_speicherseen_chart(speicher), "_site/charts/fr/speicherseen.html",
               title = "Niveaux de remplissage des lacs d\u2019accumulation",
               updated = speicher$totalCH$currentEntry$date, assets = "../../assets")
bfe_chart_page(bfe_produktion_handel_chart(produktion, years = 5), "_site/charts/fr/produktion.html",
               title = "Production et consommation nationales, commerce extérieur",
               updated = produktion$currentEntry$date, assets = "../../assets")
bfe_chart_page(bfe_produktion_chart(produktion, years = 5), "_site/charts/fr/produktion_bfe.html",
               title = "Production d\u2019électricité par agent énergétique",
               updated = produktion$currentEntry$date, assets = "../../assets")
bfe_lang <- "de"

# 2) Story ---------------------------------------------------------------------
rmarkdown::render("index.Rmd", quiet = TRUE, encoding = "UTF-8")
invisible(file.rename("index.html", "_site/index.html"))
invisible(file.copy("libs", "_site", recursive = TRUE)); unlink("libs", recursive = TRUE)
invisible(file.copy("assets", "_site", recursive = TRUE))

# 3) French version -> _site/fr/  (German stays at the root, without /de) -------
# It shares assets/, libs/ and charts/ with the German page, so the relative
# paths in the HTML get one "../" in front.
rmarkdown::render("index_fr.Rmd", quiet = TRUE, encoding = "UTF-8")
dir.create("_site/fr", showWarnings = FALSE)
html <- readLines("index_fr.html", encoding = "UTF-8", warn = FALSE)
html <- gsub('((src|href|data-src|data-full)=")(assets|libs|charts|data)/', "\\1../\\3/", html)
html <- gsub("url\\((['\"]?)(assets|libs)/", "url(\\1../\\2/", html)
writeLines(html, "_site/fr/index.html", useBytes = TRUE)
unlink("index_fr.html")
# libs/ from the French render only adds what the German render already copied
if (dir.exists("libs")) {
  invisible(file.copy(list.files("libs", full.names = TRUE), "_site/libs", recursive = TRUE, overwrite = FALSE))
  unlink("libs", recursive = TRUE)
}

message("Done: _site/index.html and _site/fr/index.html")
