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
bfe_chart_page(bfe_produktion_chart(produktion, years = 5), "_site/charts/produktion.html",
               title = "Stromproduktion und Landesverbrauch",
               updated = produktion$currentEntry$date)

# 2) Story ---------------------------------------------------------------------
rmarkdown::render("index.Rmd", quiet = TRUE, encoding = "UTF-8")
invisible(file.rename("index.html", "_site/index.html"))
invisible(file.copy("libs", "_site", recursive = TRUE)); unlink("libs", recursive = TRUE)
invisible(file.copy("assets", "_site", recursive = TRUE))

message("Done: _site/index.html")
