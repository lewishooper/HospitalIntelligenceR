# Figure and Table Standards Guide
## HospitalIntelligenceR — Publication Graphics and Tables
*docs/figure_standards.md | Established April 2026*

---

## Purpose

This guide governs the production of all publication-quality figures in
HospitalIntelligenceR. It applies to any figure intended for white papers,
personal reports, or external distribution. Exploratory figures embedded in
analytical scripts are exempt, but should migrate to these standards before
any graphic is used in a publication context.

This guide should be read alongside `docs/style_guide.md`, which governs
narrative tone and structure. Figures and text are jointly responsible for
making an argument — they should be designed together.

---

## 1. Architecture — Standalone Graphics Scripts

Publication figures live in dedicated scripts, separate from analytical scripts.

### Script naming convention

```
roles/strategy/scripts/fig_03b.R   # Theme trends figures
roles/strategy/scripts/fig_03c.R   # Hospital type × era figures
roles/strategy/scripts/fig_04a.R   # Homogeneity figures
roles/strategy/scripts/fig_04b.R   # Distinctive directions figures
roles/strategy/scripts/fig_utils.R # Shared theme, colours, label lookups
```

### Immutable inputs

Each graphics script reads from exactly two upstream sources, both of which
are treated as read-only:

| Input | Contents | Used for |
|-------|----------|----------|
| `strategy_master_analytical.csv` | One row per direction; plan metadata, dates, era, type group | Plan-level and trend figures |
| `strategy_classified.csv` | One row per direction; primary and secondary theme assignments | Theme-based figures |

**Rule:** Graphics scripts never write to any analytical CSV. They write only
to the figures output directory. If a figure requires a derived summary, that
summary is computed inside the graphics script and never saved as a file.

### Output directory

```
roles/strategy/outputs/figures/publication/
```

Exploratory figures from analytical scripts go to:

```
roles/strategy/outputs/figures/exploratory/
```

These are separate directories. Publication figures are never overwritten by
analytical script runs.

---

## 2. Output Specifications

| Parameter | Value |
|-----------|-------|
| Resolution | 300 DPI |
| Default dimensions | 7 × 5 inches (width × height) |
| File format | PNG (primary); PDF on request |
| Colour mode | Colour (greyscale fallback available — see Section 6) |

Wide figures (e.g. multi-panel comparisons across four type groups) may use
10 × 5 or 10 × 6 inches. Tall figures (e.g. ranked hospital lists) may use
7 × 8 or 7 × 10 inches. Exceptions should be noted in the script header.

Standard save call:

```r
ggsave(
  filename = file.path(FIG_DIR, "fig_name.png"),
  plot     = p,
  width    = 7,
  height   = 5,
  dpi      = 300,
  units    = "in"
)
```

---

## 3. Base Theme

All figures use `theme_linedraw()` as the base ggplot2 theme. This provides
a clean white background with crisp grid lines suitable for print and white
paper contexts.

### Standard theme block

Load `fig_utils.R` at the top of every graphics script. The shared theme
object is defined once there:

```r
# In fig_utils.R
base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title    = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10, colour = "grey40"),
    plot.caption  = element_text(size = 8, colour = "grey50", hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(size = 9),
    legend.text      = element_text(size = 8),
    axis.title       = element_text(size = 10),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = NA),
    strip.text       = element_text(face = "bold", size = 9)
  )
```

Apply to any figure with `+ base_theme`. Override individual elements
locally as needed — do not modify `fig_utils.R` for one-off adjustments.

### Typography

- Font family: sans-serif throughout (`base_family = "sans"`)
- Title: bold, 13pt
- Subtitle: regular, 10pt, grey40
- Axis titles: 10pt
- Axis text: 9pt
- Caption: 8pt, grey50, left-aligned
- Strip labels (facets): bold, 9pt

---

## 4. Text Elements

Every publication figure carries the following text elements:

| Element | Required | Notes |
|---------|----------|-------|
| Title | Yes | Short, declarative — states the finding, not the variable |
| Subtitle | Yes | One sentence providing context or method note |
| Axis titles | Yes | Always labelled; never rely on variable name defaults |
| Caption | Yes | Data source and n= |
| Legend title | Yes | Descriptive, not a variable name |

### Title convention

Titles state the finding, not the topic. Follow the same direct declarative
principle as the narrative style guide.

**Like this:**
> Workforce dominates Ontario hospital strategy across all plan eras

**Not like this:**
> Theme prevalence by era

### Caption convention

Standard caption format:

```
Source: HospitalIntelligenceR strategy extraction | n = [X] hospitals
```

For era-scoped figures, add the scope:

```
Source: HospitalIntelligenceR strategy extraction | Current era cohort: n = 68 hospitals
```

---

## 5. Colour

### General categorical data — Dark2

The default palette for categorical data (hospital type groups, themes,
era labels) is ColorBrewer **Dark2**. Dark2 provides 8 visually distinct,
print-safe colours with strong contrast on white backgrounds.

```r
# In fig_utils.R
scale_colour_brewer(palette = "Dark2")
scale_fill_brewer(palette = "Dark2")
```

Dark2 hex values for manual reference (in order):
`#1B9E77`, `#D95F02`, `#7570B3`, `#E7298A`, `#66A61E`, `#E6AB02`, `#A6761D`, `#666666`

The four hospital type groups map consistently across all figures. Colours are
drawn from Dark2 but assigned to maximise perceptual distance — teal, orange,
purple, and green are spread around the colour wheel with no two groups sharing
a warm/cool family:

| Type group | Colour | Hex |
|------------|--------|-----|
| Community — Large | Teal | #1B9E77 |
| Community — Small | Orange | #D95F02 |
| Teaching | Purple | #7570B3 |
| Specialty | Green | #66A61E |

This mapping is fixed. It must be consistent across all figures in all scripts.
Define it once in `fig_utils.R`:

```r
type_colours <- c(
  "Community — Large" = "#1B9E77",
  "Community — Small" = "#D95F02",
  "Teaching"          = "#7570B3",
  "Specialty"         = "#66A61E"
)
```

### Heatmaps and continuous diverging scales

For heatmaps and continuous data where direction matters (e.g. above/below
sector average, Jaccard similarity), use diverging spectra:

- **Red → Yellow** (`RdYlGn` reversed, or `YlOrRd`): for one-directional
  intensity (e.g. prevalence, count data where higher = more)
- **Red → Green** (`RdYlGn`): for diverging data with a meaningful midpoint
  (e.g. deviation from sector norm, where negative and positive have
  different interpretations)

```r
# One-directional intensity
scale_fill_distiller(palette = "YlOrRd", direction = 1)

# Diverging around a midpoint
scale_fill_distiller(palette = "RdYlGn", direction = 1)
```

Choose based on the underlying data structure, not aesthetic preference.
If the data has a natural zero or midpoint that separates meaningful
categories (above/below average), use the diverging palette.

---

## 6. Greyscale Fallback

When a greyscale version is required, do not redesign the figure. Instead:

1. Replace `scale_colour_brewer` / `scale_fill_brewer` with
   `scale_colour_grey` / `scale_fill_grey`
2. Add shape or linetype as a redundant encoding where colour was the
   only distinguishing feature
3. Save to a parallel `_greyscale` filename

```r
# Greyscale override
scale_fill_grey(start = 0.2, end = 0.8)
scale_colour_grey(start = 0.2, end = 0.8)
```

Greyscale versions are produced on demand, not by default.

---

## 7. Chart Type Conventions

These conventions follow Wilke (2019) *Fundamentals of Data Visualization*
and are calibrated to the data structures present in HospitalIntelligenceR.

| Data type | Preferred chart type | Avoid |
|-----------|---------------------|-------|
| Narrow-range integer counts per hospital | Dot strip + mean/SD overlay | Boxplot |
| Theme prevalence (% hospitals) | Horizontal bar or dot plot | Pie chart |
| Prevalence change across eras | Connected dot plot (slope-style) or grouped bar | Stacked bar |
| Pairwise similarity distribution | Histogram or density | Single summary stat only |
| Type group × theme cross-tab | Faceted bar or heatmap tile | 3D anything |
| Ranked hospital lists | Horizontal lollipop | Vertical bar with rotated labels |

**Y-axis rule:** Count and prevalence axes always start at zero. Jaccard
and proportion axes (0–1 bounded) may be zoomed if the data range warrants
it, but must be explicitly labelled with axis limits.

---

## 8. Figure Inventory (Strategy Role)

Figures to be produced for publication, by analytical module:

| Script | Figure | Type | Status |
|--------|--------|------|--------|
| fig_03b.R | Theme prevalence by era (% hospitals) | Connected dot / grouped bar | To build |
| fig_03b.R | WRK and RES trend highlight | Slope chart | To build |
| fig_03c.R | Theme prevalence by era × type group (WRK, RES) | Faceted bar | To build |
| fig_03c.R | Era × type composition | Stacked bar | To build |
| fig_04a.R | Theme breadth distribution by type group | Dot strip + mean/SD | To build |
| fig_04a.R | Within- vs between-type Jaccard by group and era | Grouped bar or dot plot | To build |
| fig_04a.R | Core profile alignment (% full match) | Horizontal bar | To build |
| fig_04b.R | Outlier score distribution | Dot strip or histogram | To build |
| fig_04b.R | Distinctive directions by theme and type | Heatmap tile | To build |

This inventory will expand as publication narratives are drafted and figure
needs become concrete. Status updates to this table do not require a full
document revision — edit in place.

---

## 9. CRAN Packages

All figures use CRAN packages only. The standard set:

```r
library(ggplot2)     # Core plotting
library(dplyr)       # Data preparation within graphics scripts
library(RColorBrewer) # Colour palettes
library(scales)      # Axis formatting (percent, comma)
library(ggtext)      # Rich text in titles/subtitles if needed
library(patchwork)   # Multi-panel figure composition
```

No non-CRAN packages. No bbplot or other external style packages.

---

## 10. Relationship to Analytical Scripts

Analytical scripts (`03b`, `03c`, `04a`, `04b`) contain exploratory figures
used during development and pipeline checking. Those figures remain in place
— they serve a diagnostic purpose and should not be removed.

Publication graphics scripts are additive and independent. They share no
output paths with analytical scripts. The same finding may be visualized
differently in the exploratory and publication versions — that is expected
and acceptable.

---

---

## 11. Table Standards

### Package

All publication tables use **`flextable`** (CRAN). `flextable` exports cleanly
to PNG, Word (`.docx`), and PDF without external browser dependencies, making
it the natural choice for white paper production.

```r
library(flextable)
library(officer)   # For Word integration if needed
```

### Output specifications

| Parameter | Value |
|-----------|-------|
| Format | PNG (primary); embed in Word via `officer` as needed |
| Resolution | 300 DPI (via `save_as_image()`) |
| Width | Fit to content; max 7 inches to match figure width standard |

Standard save call:

```r
save_as_image(ft, path = file.path(FIG_DIR, "tbl_name.png"), res = 300)
```

### Output directory

Publication tables go to the same directory as publication figures:

```
roles/strategy/outputs/figures/publication/
```

Use a `tbl_` prefix to distinguish from figure files (`fig_` prefix).

### Base table style

Define a standard table theme in `fig_utils.R` as a function:

```r
std_flextable <- function(ft) {
  ft %>%
    theme_vanilla() %>%
    font(fontname = "Arial", part = "all") %>%
    fontsize(size = 10, part = "body") %>%
    fontsize(size = 10, part = "header") %>%
    bold(part = "header") %>%
    bg(bg = "#F2F2F2", part = "header") %>%
    border_outer(part = "all", border = fp_border(color = "grey40", width = 1)) %>%
    border_inner_h(part = "body", border = fp_border(color = "grey80", width = 0.5)) %>%
    padding(padding = 4, part = "all") %>%
    set_table_properties(layout = "autofit")
}
```

Apply to any table with `ft <- flextable(df) %>% std_flextable()`.

### Colour use in tables

- **Header background:** grey (#F2F2F2) — neutral, print-safe
- **Row banding:** optional; use `bg(i = seq(2, nrow, 2), bg = "#FAFAFA")` for
  long tables where row tracking aids readability
- **Highlight cells:** use Dark2 type group colours (Section 5) when a cell
  value corresponds to a type group; otherwise avoid decorative colour in cells
- **Heatmap-style tables:** apply the same diverging colour conventions as
  Section 5 (red→green or red→yellow) using `bg()` with a colour scale function

### Text conventions in tables

- Column headers: title case, concise — never raw variable names
- Numeric cells: right-aligned; use `align(align = "right", part = "body", j = <numeric cols>)`
- Text cells: left-aligned
- Percentages: one decimal place (`scales::percent(x, accuracy = 0.1)`)
- Counts: comma-formatted for values ≥ 1,000
- Jaccard and proportion values: two decimal places

### Caption and source

Every publication table carries a caption below the table body:

```r
ft <- ft %>%
  add_footer_lines("Source: HospitalIntelligenceR strategy extraction | n = X hospitals") %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "grey50", part = "footer")
```

### Table inventory (Strategy Role)

| Script | Table | Contents | Status |
|--------|-------|----------|--------|
| fig_03b.R | tbl_03b_prevalence.png | Theme prevalence by era — % hospitals | To build |
| fig_03c.R | tbl_03c_type_era.png | Theme prevalence by type group and era | To build |
| fig_04a.R | tbl_04a_breadth.png | Theme breadth summary by type group | To build |
| fig_04a.R | tbl_04a_jaccard.png | Jaccard similarity summary by group and era | To build |
| fig_04a.R | tbl_04a_core_profile.png | Core profile by type group | To build |
| fig_04b.R | tbl_04b_outliers.png | Top outlier hospitals by score | To build |
| fig_04b.R | tbl_04b_distinctive.png | Distinctive directions sample | To build |

---

## 12. CRAN Packages — Full List

```r
# Figures
library(ggplot2)      # Core plotting
library(dplyr)        # Data preparation within graphics scripts
library(RColorBrewer) # Colour palettes
library(scales)       # Axis formatting (percent, comma)
library(ggtext)       # Rich text in titles/subtitles
library(patchwork)    # Multi-panel figure composition

# Tables
library(flextable)    # Publication tables
library(officer)      # Word document integration
```

No non-CRAN packages. No external browser dependencies.

---

*Last updated: April 2026*
*Reference: Wilke (2019) Fundamentals of Data Visualization | ColorBrewer 2.0 | flextable documentation*
