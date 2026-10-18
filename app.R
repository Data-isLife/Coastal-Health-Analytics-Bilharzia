# Coastal Kenya Bilharzia Analytics Hub
# Analysis uses Project data.csv only. The individual file is exposed only as a download.

library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x[1])) y else x
clean_column_names <- function(x) {
  nms <- trimws(names(x))
  missing <- is.na(nms) | !nzchar(nms)
  nms[missing] <- paste0("unnamed_", which(missing))
  names(x) <- make.unique(nms, sep = "_")
  x
}
as_num <- function(x) suppressWarnings(as.numeric(as.character(x)))
as_binary <- function(x) {
  z <- tolower(trimws(as.character(x)))
  out <- suppressWarnings(as.numeric(z))
  out[z %in% c("yes", "positive", "pos", "true")] <- 1
  out[z %in% c("no", "negative", "neg", "false")] <- 0
  out[is.na(out) | !out %in% c(0, 1)] <- NA_real_
  out
}

project_file <- "Project data.csv"
if (!file.exists(project_file)) stop("Project data.csv must be in the same folder as app.R.")
source_data <- clean_column_names(read.csv(project_file, check.names = FALSE, stringsAsFactors = FALSE))
required <- c("County", "Sub_County", "Longitude", "Latitude", "Age", "Gender", "anyshito", "Water_Source", "Toilet")
missing_columns <- setdiff(required, names(source_data))
if (length(missing_columns)) stop(paste("Project data.csv is missing required columns:", paste(missing_columns, collapse = ", ")))
boundary_file <- "coastal_counties.csv"
if (!file.exists(boundary_file)) stop("coastal_counties.csv must be beside app.R to draw the offline coastal map.")
coast_map <- read.csv(boundary_file, stringsAsFactors = FALSE)
coast_map$polygon_group <- interaction(coast_map$County, coast_map$polygon_id, drop = TRUE)

# Standardized analysis frame. ChildID is intentionally excluded from analysis views.
dat <- data.frame(
  County = trimws(as.character(source_data$County)),
  Sub_County = trimws(as.character(source_data$Sub_County)),
  Longitude = as_num(source_data$Longitude),
  Latitude = as_num(source_data$Latitude),
  Age = as_num(source_data$Age),
  Gender = trimws(as.character(source_data$Gender)),
  Outcome = as_binary(source_data$anyshito),
  Water = trimws(as.character(source_data$Water_Source)),
  Toilet = trimws(as.character(source_data$Toilet)),
  check.names = FALSE
)
# Normalize the two expected gender categories and prevent other labels leaking into the app.
dat$Gender <- ifelse(tolower(dat$Gender) == "male", "Male",
                     ifelse(tolower(dat$Gender) == "female", "Female", NA_character_))
for (nm in c("County", "Sub_County", "Water", "Toilet")) {
  dat[[nm]][is.na(dat[[nm]]) | !nzchar(dat[[nm]])] <- "Missing / not recorded"
  dat[[nm]][dat[[nm]] == "NA"] <- "Missing / not recorded"
}

all_counties <- sort(unique(dat$County))
all_subcounties <- sort(unique(dat$Sub_County))
all_genders <- c("Male", "Female")
all_water <- sort(unique(dat$Water))
all_toilet <- sort(unique(dat$Toilet))
age_values <- dat$Age[is.finite(dat$Age)]
age_min <- if (length(age_values)) floor(min(age_values)) else 0
age_max <- if (length(age_values)) ceiling(max(age_values)) else 0

ui <- page_navbar(
  title = "Coastal Health Analytics",
  id = "page",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#145a66", secondary = "#537d76", font_scale = 0.94),
  header = tagList(
    tags$head(tags$style(HTML(".bslib-page-navbar > .container-fluid {max-width: 1600px;} .value-box {min-height: 125px;} .app-note {color:#52636a;font-size:.92rem;} .filter-heading {font-weight:700;color:#145a66;}"))),
    p(class = "app-note px-3 pt-2", "Explore cleaned survey results. Choose filters, then select Apply to refresh every chart, summary and download.")
  ),
  sidebar = sidebar(
    width = 310, open = "desktop",
    h5(class = "filter-heading", "Analysis filters"),
    selectInput("county", "County", choices = c("All counties", all_counties)),
    uiOutput("subcounty_ui"),
    checkboxGroupInput("gender", "Gender", choices = all_genders, selected = all_genders, inline = TRUE),
    sliderInput("age", "Age range", min = age_min, max = age_max,
                value = c(age_min, age_max), step = 1),
    checkboxInput("include_missing_age", "Include records with missing age", value = TRUE),
    selectInput("water", "Water source (recorded value)", choices = c("All", all_water)),
    selectInput("toilet", "Toilet (recorded value)", choices = c("All", all_toilet)),
    actionButton("apply", "Apply filters", class = "btn-primary w-100"),
    br(), br(),
    actionButton("reset", "Reset filters", class = "btn-outline-secondary w-100")
  ),
  nav_panel("Overview", value = "overview",
    layout_column_wrap(width = 1/4,
      value_box("People screened", textOutput("kpi_n"), showcase = bs_icon("people-fill"), theme = "primary"),
      value_box("Bilharzia prevalence", textOutput("kpi_prev"), showcase = bs_icon("activity"), theme = "danger"),
      value_box("Positive records", textOutput("kpi_positive"), showcase = bs_icon("clipboard2-pulse"), theme = "warning"),
      value_box("Sub-counties represented", textOutput("kpi_locations"), showcase = bs_icon("geo-alt-fill"), theme = "success")
    ),
    layout_column_wrap(width = 1/2,
      card(card_header("Sub-county prevalence"), plotlyOutput("place_plot", height = "390px")),
      card(card_header("Bilharzia outcome by gender"), plotlyOutput("group_plot", height = "390px"))
    ),
    card(card_header("About this view"), p("The analysis uses Project data.csv only. Prevalence is the percentage of records with a known outcome that are positive for anyshito. Missing outcomes remain visible in record-count charts and tables."))
  ),
  nav_panel("Explore locations", value = "locations",
    layout_column_wrap(width = 1/2,
      card(card_header("Coastal county map with sub-county results"), plotlyOutput("map", height = "500px")),
      card(card_header("Location summary"), DTOutput("location_table"))
    ),
    p(class = "app-note", "County outlines and the map are bundled with the app. Points use the sub-county coordinates in Project data.csv. No map tiles, API key, or live map service are required.")
  ),
  nav_panel("Demographics & living conditions", value = "factors",
    layout_column_wrap(width = 1/2,
      card(card_header("Records by age and outcome"), plotlyOutput("age_plot", height = "360px")),
      card(card_header("Records by water source, toilet and outcome"), plotlyOutput("wash_plot", height = "360px"))
    ),
    card(card_header("Filtered cleaned records"), p(class = "app-note", "Child identifiers are excluded from this table."), DTOutput("records_table"))
  ),
  nav_panel("Data & methods", value = "methods",
    layout_column_wrap(width = 1/2,
      card(card_header("Downloads"),
        p("Download the cleaned records matching the applied filters."),
        downloadButton("download_clean", "Download filtered cleaned data", class = "btn-primary"),
        if (file.exists("Individual level data.csv")) tagList(
          br(), br(), p("The original individual-level file is available for download only; the app never uses it in its analysis."),
          downloadButton("download_original", "Download original individual-level data", class = "btn-outline-primary")
        )
      ),
      card(card_header("Data coverage"), tableOutput("coverage_table"))
    ),
    card(card_header("Interpretation and API information"),
      p("This app uses a local CSV and requires no API key or external data API. In Posit Cloud, upload the CSV files into the same project folder as app.R."),
      p("Project data.csv contains the bilharzia outcome anyshito. Other disease types are not available in this cleaned file, so the app does not infer or display them."),
      p("Water and toilet categories are shown as recorded because a coding dictionary was not included. Descriptive differences do not establish cause and effect."))
  ),
  nav_panel("Downloads", value = "downloads",
    card(card_header("Project documents"),
      p("Files added to the downloads folder are listed here for users to download."),
      uiOutput("document_downloads"))
  )
)

server <- function(input, output, session) {
  applied <- reactiveVal(list(county = "All counties", subcounty = "All sub-counties",
    gender = all_genders, age = c(age_min, age_max), include_missing_age = TRUE,
    water = "All", toilet = "All"))

  output$subcounty_ui <- renderUI({
    counties <- input$county
    choices <- if (is.null(counties) || counties == "All counties") all_subcounties else
      sort(unique(dat$Sub_County[dat$County == counties]))
    selectInput("subcounty", "Sub-county", choices = c("All sub-counties", choices))
  })
  observeEvent(input$apply, {
    applied(list(county = input$county %||% "All counties",
      subcounty = input$subcounty %||% "All sub-counties",
      gender = input$gender %||% character(0), age = input$age %||% c(age_min, age_max),
      include_missing_age = isTRUE(input$include_missing_age),
      water = input$water %||% "All", toilet = input$toilet %||% "All"))
  }, ignoreInit = TRUE)
  observeEvent(input$reset, {
    updateSelectInput(session, "county", selected = "All counties")
    updateCheckboxGroupInput(session, "gender", selected = all_genders)
    updateSliderInput(session, "age", value = c(age_min, age_max))
    updateCheckboxInput(session, "include_missing_age", value = TRUE)
    updateSelectInput(session, "water", selected = "All")
    updateSelectInput(session, "toilet", selected = "All")
    applied(list(county = "All counties", subcounty = "All sub-counties", gender = all_genders,
      age = c(age_min, age_max), include_missing_age = TRUE, water = "All", toilet = "All"))
  })

  filtered <- reactive({
    f <- applied()
    d <- dat
    if (f$county != "All counties") d <- d[d$County == f$county, , drop = FALSE]
    if (f$subcounty != "All sub-counties") d <- d[d$Sub_County == f$subcounty, , drop = FALSE]
    if (length(f$gender)) d <- d[d$Gender %in% f$gender, , drop = FALSE] else d <- d[0, , drop = FALSE]
    d <- d[(is.na(d$Age) & f$include_missing_age) | (!is.na(d$Age) & d$Age >= f$age[1] & d$Age <= f$age[2]), , drop = FALSE]
    if (f$water != "All") d <- d[d$Water == f$water, , drop = FALSE]
    if (f$toilet != "All") d <- d[d$Toilet == f$toilet, , drop = FALSE]
    d
  })
  location_summary <- reactive({
    filtered() %>% group_by(County, Sub_County) %>% summarise(
      Screened = n(), Outcome_known = sum(!is.na(Outcome)), Positive = sum(Outcome == 1, na.rm = TRUE),
      Prevalence = if (sum(!is.na(Outcome)) == 0) NA_real_ else 100 * mean(Outcome == 1, na.rm = TRUE),
      Longitude = mean(Longitude, na.rm = TRUE), Latitude = mean(Latitude, na.rm = TRUE), .groups = "drop") %>%
      mutate(Prevalence_display = ifelse(is.na(Prevalence), "No outcome data", paste0(round(Prevalence, 1), "%")))
  })

  output$kpi_n <- renderText(format(nrow(filtered()), big.mark = ","))
  output$kpi_prev <- renderText({ d <- filtered(); n <- sum(!is.na(d$Outcome)); if (!n) "No outcome data" else paste0(round(100 * mean(d$Outcome == 1, na.rm = TRUE), 1), "%") })
  output$kpi_positive <- renderText(format(sum(filtered()$Outcome == 1, na.rm = TRUE), big.mark = ","))
  output$kpi_locations <- renderText(n_distinct(filtered()$Sub_County))

  output$place_plot <- renderPlotly({
    s <- location_summary()
    validate(need(nrow(s) > 0, "No records match the applied filters."))
    s$Plot_value <- ifelse(is.na(s$Prevalence), 0, s$Prevalence)
    s$Status <- ifelse(is.na(s$Prevalence), "No outcome data", "Outcome available")
    s <- head(s[order(s$Plot_value, decreasing = TRUE), ], 20)
    p <- ggplot(s, aes(x = reorder(Sub_County, Plot_value), y = Plot_value, fill = Status,
      text = paste0(Sub_County, ", ", County, "<br>Prevalence: ", Prevalence_display,
        "<br>Positive: ", Positive, "<br>Outcomes known: ", Outcome_known, "<br>Screened: ", Screened))) +
      geom_col() + coord_flip() + scale_fill_manual(values = c("Outcome available" = "#197c83", "No outcome data" = "#aab4b7")) +
      labs(x = NULL, y = "Prevalence (%)", fill = NULL) + theme_minimal(base_size = 12)
    ggplotly(p, tooltip = "text")
  })
  output$group_plot <- renderPlotly({
    d <- filtered() %>% filter(!is.na(Gender)) %>% mutate(Outcome_status = factor(ifelse(is.na(Outcome), "Missing outcome", ifelse(Outcome == 1, "Positive", "Negative")), levels = c("Negative", "Positive", "Missing outcome")))
    validate(need(nrow(d) > 0, "No gender records match the applied filters."))
    g <- d %>% count(Gender, Outcome_status, name = "Records")
    p <- ggplot(g, aes(Gender, Records, fill = Outcome_status, text = paste0(Gender, "<br>", Outcome_status, ": ", Records))) + geom_col() +
      scale_fill_manual(values = c("Negative" = "#57a773", "Positive" = "#c94c4c", "Missing outcome" = "#aab4b7")) +
      labs(x = NULL, y = "Records", fill = "Outcome") + theme_minimal(base_size = 12)
    ggplotly(p, tooltip = "text")
  })
  output$location_table <- renderDT({
    s <- location_summary() %>% select(County, Sub_County, Screened, Outcome_known, Positive, Prevalence_display)
    names(s)[names(s) == "Prevalence_display"] <- "Prevalence"
    datatable(s, rownames = FALSE, options = list(pageLength = 12, scrollX = TRUE))
  })
  output$map <- renderPlotly({
    d <- location_summary() %>% filter(is.finite(Longitude), is.finite(Latitude))
    p <- ggplot() +
      geom_polygon(data = coast_map, aes(Longitude, Latitude, group = polygon_group),
        fill = "#e7efeb", color = "#718782", linewidth = 0.35) +
      coord_quickmap(xlim = range(coast_map$Longitude, finite = TRUE),
        ylim = range(coast_map$Latitude, finite = TRUE), expand = FALSE, clip = "on") +
      scale_color_gradient(low = "#e3a43b", high = "#a93645", na.value = "#7c898d", name = "Prevalence (%)") +
      scale_size_continuous(range = c(2.5, 8), name = "Screened") +
      labs(x = "Longitude", y = "Latitude") +
      theme_minimal(base_size = 11) +
      theme(panel.grid = element_blank(), panel.background = element_rect(fill = "#f8faf9", color = NA),
        plot.background = element_rect(fill = "white", color = NA))
    if (nrow(d)) {
      p <- p + geom_point(data = d, aes(Longitude, Latitude, color = Prevalence, size = Screened,
        text = paste0("<b>", Sub_County, ", ", County, "</b><br>Prevalence: ", Prevalence_display,
          "<br>Positive: ", Positive, "<br>Outcomes known: ", Outcome_known, "<br>Screened: ", Screened)),
        alpha = 0.9, stroke = 0.8, shape = 21, fill = "#ffffff")
    }
    ggplotly(p, tooltip = "text") %>% layout(legend = list(orientation = "h", y = -0.15))
  })
  output$age_plot <- renderPlotly({
    d <- filtered() %>% filter(is.finite(Age)) %>% mutate(Outcome_status = factor(ifelse(is.na(Outcome), "Missing outcome", ifelse(Outcome == 1, "Positive", "Negative")), levels = c("Negative", "Positive", "Missing outcome")))
    validate(need(nrow(d) > 0, "No records with age are available for the applied filters."))
    g <- d %>% count(Age, Outcome_status, name = "Records")
    p <- ggplot(g, aes(x = factor(Age), y = Records, fill = Outcome_status,
      text = paste0("Age: ", Age, "<br>", Outcome_status, ": ", Records))) + geom_col() +
      scale_fill_manual(values = c("Negative" = "#57a773", "Positive" = "#c94c4c", "Missing outcome" = "#aab4b7")) +
      labs(x = "Age (years)", y = "Records", fill = "Outcome") + theme_minimal(base_size = 12)
    ggplotly(p, tooltip = "text")
  })
  output$wash_plot <- renderPlotly({
    d <- filtered() %>% mutate(
      Water_group = ifelse(is.na(Water) | Water == "Missing / not recorded", "Missing / not recorded", Water),
      Toilet_group = ifelse(is.na(Toilet) | Toilet == "Missing / not recorded", "Missing / not recorded", Toilet),
      Outcome_status = factor(ifelse(is.na(Outcome), "Missing outcome", ifelse(Outcome == 1, "Positive", "Negative")), levels = c("Negative", "Positive", "Missing outcome")),
      WASH_group = paste0("Water ", Water_group, " / Toilet ", Toilet_group))
    validate(need(nrow(d) > 0, "No records match the applied filters."))
    g <- d %>% count(WASH_group, Outcome_status, name = "Records")
    p <- ggplot(g, aes(x = reorder(WASH_group, Records), y = Records, fill = Outcome_status,
      text = paste0(WASH_group, "<br>", Outcome_status, ": ", Records))) + geom_col() + coord_flip() +
      scale_fill_manual(values = c("Negative" = "#57a773", "Positive" = "#c94c4c", "Missing outcome" = "#aab4b7")) +
      labs(x = NULL, y = "Records", fill = "Outcome") + theme_minimal(base_size = 11)
    ggplotly(p, tooltip = "text")
  })
  output$records_table <- renderDT({
    d <- filtered() %>% transmute(County, Sub_County, Age, Gender,
      Water_Source = Water, Toilet, anyshito = ifelse(is.na(Outcome), "Missing", ifelse(Outcome == 1, "Positive", "Negative")))
    datatable(d, rownames = FALSE, filter = "top", options = list(pageLength = 15, scrollX = TRUE, lengthMenu = c(10, 15, 25, 50)))
  })
  output$coverage_table <- renderTable({
    data.frame(Item = c("Analysis file", "Filtered records", "Counties", "Sub-counties", "Gender categories", "Outcome"),
      Value = c(project_file, nrow(filtered()), n_distinct(filtered()$County), n_distinct(filtered()$Sub_County), "Male and Female", "anyshito (Bilharzia)"),
      check.names = FALSE)
  }, striped = TRUE, bordered = FALSE, spacing = "s")
  output$download_clean <- downloadHandler(
    filename = function() paste0("project-data-filtered-", Sys.Date(), ".csv"),
    content = function(file) {
      d <- filtered() %>% transmute(County, Sub_County, Longitude, Latitude, Age, Gender,
        anyshito = Outcome, Water_Source = Water, Toilet)
      write.csv(d, file, row.names = FALSE, na = "")
    }
  )
  if (file.exists("Individual level data.csv")) {
    output$download_original <- downloadHandler(
      filename = function() "Individual-level-original-data.csv",
      content = function(file) file.copy("Individual level data.csv", file, overwrite = TRUE)
    )
  }
  output$document_downloads <- renderUI({
    download_dir <- "downloads"
    supported <- "\\.(pdf|docx|pptx|xlsx|csv|txt)$"
    files <- if (dir.exists(download_dir)) list.files(download_dir, pattern = supported,
      full.names = FALSE, recursive = FALSE, ignore.case = TRUE) else character(0)
    if (!length(files)) return(p("No downloadable documents have been added yet."))
    tagList(lapply(seq_along(files), function(i) {
      local({
        file_name <- files[[i]]
        output[[paste0("download_document_", i)]] <- downloadHandler(
          filename = function() file_name,
          content = function(file) file.copy(file.path(download_dir, file_name), file, overwrite = TRUE)
        )
      })
      downloadButton(paste0("download_document_", i), label = files[[i]], class = "btn-outline-primary")
    }))
  })
}

shinyApp(ui = ui, server = server)
