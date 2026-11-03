# Wasserkraft CH – story map

Suggested repository: **`hydrosuisse/wasserkraft-storymap`**
→ published at **https://hydrosuisse.github.io/wasserkraft-storymap/**

A static story page in the style of an ArcGIS StoryMap (standard theme "Summit"),
built with R Markdown and mapgl. Three parts are embedded and load separately,
only when the reader scrolls near them:

| Part | Where it lives | Updates |
|---|---|---|
| Story (text, cover, maps, map tour) | `index.Rmd` → GitHub Pages | on every push |
| Chart "Füllstände der Speicherseen" | `charts/speicherseen.html` (built by `build.R`) | daily (GitHub Actions) |
| Chart "Stromproduktion und Landesverbrauch" | `charts/produktion.html` (built by `build.R`) | daily (GitHub Actions) |
| Dashboard "Wasserkraft und Spotpreise" | unchanged at https://hydrosuisse.shinyapps.io/wasserkraft-ch/ | as before |

The story page itself needs no server and appears immediately. The two charts
are plain HTML pages and also load instantly. Only the dashboard needs a few
seconds to start on shinyapps.io; until then a loading notice is shown.

## Files

```
index.Rmd                   the story: text, order of sections, maps, embeds
build.R                     builds everything into _site/
R/storymap.R                story blocks: sm_header, sm_cover, sm_nav, sm_map,
                            sm_sidecar/sm_slide, sm_frame, sm_image, sm_credits
R/bfe_charts.R              BFE data download + the two plotly charts
assets/storymap.css/.js     story styling (Summit) and behaviour
assets/chart.css/.js        chart pages: dashboard look, Frutiger, auto-height
assets/fonts/               place licensed Frutiger web fonts here (optional)
data/kraftwerke.csv         example points for the map (approximate – replace)
data/snapshot/              last good BFE data (fallback, updated by the workflow)
.github/workflows/build-deploy.yml   daily build + deploy to GitHub Pages
```

## Set up on GitHub

1. Create the repository `hydrosuisse/wasserkraft-storymap` and push these files.
2. *Settings → Pages → Build and deployment → Source:* **GitHub Actions**.
3. *Settings → Actions → General → Workflow permissions:* **Read and write**
   (so the workflow can save the data snapshot).
4. Run the workflow once (*Actions → Build and deploy story → Run workflow*).
   After that it runs on every push and every morning.

## Build locally

```r
install.packages(c("rmarkdown", "mapgl", "sf", "plotly", "htmltools", "jsonlite"))
source("build.R")
servr::httd("_site")        # or open _site/index.html via any local web server
```

## The BFE charts

* Data come from the JSON endpoints the Energie-Dashboard uses itself
  (`https://energiedashboard.admin.ch/api/strom/...`). These are not a documented
  public API; if the BFE changes them, the build keeps using the last snapshot
  and the log says "not reachable". Adjust `bfe_api` / endpoints in `R/bfe_charts.R`.
* Colours, stacking order, legend and axes imitate the dashboard. Labels are German.
* Source attribution "Bundesamt für Energie BFE" is shown under each chart (required by the OGD terms).

## Frutiger

The charts use Frutiger like the Energie-Dashboard where possible. Frutiger is a commercial font
and may not be copied from admin.ch. It is used

1. automatically on computers where it is installed (common in the federal administration), or
2. for everyone, if hydrosuisse owns a web-font licence: put the files as
   `assets/fonts/FrutigerNeue-Regular.woff2` and `assets/fonts/FrutigerNeue-Bold.woff2`.

Otherwise the charts fall back to Roboto.
To use Frutiger for the story text too, set `--sm-font-head` in `assets/storymap.css` to
`"Frutiger Web", "Frutiger LT Com", Roboto, sans-serif` and copy the `@font-face` rules from `assets/chart.css`.

## Embedding the dashboard

`sm_frame()` in `index.Rmd` loads the shinyapps.io app in a frame with a fixed height
(`height = "1300px"`, `height_mobile = "1900px"`). The app is on another domain,
so it cannot report its height. Adjust these values if the dashboard grows or shrinks.
The free shinyapps.io plan has a monthly limit of active hours. Each story visit that reaches
the dashboard counts towards it.
