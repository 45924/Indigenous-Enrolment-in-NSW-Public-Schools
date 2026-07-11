# libraries
library(tidyverse)
library(scales)      
library(sf)          
library(leaflet)    
library(htmlwidgets) 

# read files
path <- "NSW government school locations and student enrolment numbers.csv"
raw  <- read_csv(path, show_col_types = FALSE)
cat("Imported", nrow(raw), "schools and", ncol(raw), "columns\n")

# Data Preparation
remoteness_levels <- c("Major Cities of Australia",
                       "Inner Regional Australia",
                       "Outer Regional Australia",
                       "Remote Australia",
                       "Very Remote Australia")

schools <- raw %>%
  mutate(
    # "np" and blanks -> NA, then to numeric
    Indigenous_pct = na_if(Indigenous_pct, "np"),
    LBOTE_pct      = na_if(LBOTE_pct,      "np"),
    Indigenous_pct = as.numeric(Indigenous_pct),
    LBOTE_pct      = as.numeric(LBOTE_pct),
    
    # order remoteness from city to very remote so every plot reads left-to-right
    ASGS_remoteness = factor(ASGS_remoteness, levels = remoteness_levels),
    
    # shorten labels for compact axes
    remoteness_short = fct_recode(ASGS_remoteness,
                                  "Major\nCities"  = "Major Cities of Australia",
                                  "Inner\nRegional"= "Inner Regional Australia",
                                  "Outer\nRegional"= "Outer Regional Australia",
                                  "Remote"         = "Remote Australia",
                                  "Very\nRemote"   = "Very Remote Australia"),
    
    # estimated Indigenous student count (FTE) where the % is published
    indigenous_fte = Indigenous_pct / 100 * latest_year_enrolment_FTE,
    
    # flag suppressed Indigenous figures (used to colour the maps)
    indigenous_suppressed = is.na(Indigenous_pct)
  )

# A clean analysis frame for charts that need a published Indigenous %
schools_pub <- schools %>% filter(!is.na(Indigenous_pct))

cat("Indigenous % published for", nrow(schools_pub),
    "schools; suppressed (<=5 students) for",
    sum(schools$indigenous_suppressed), "\n")

dir.create("figures", showWarnings = FALSE)

# VISUALISATION 1: WHERE NSW PUBLIC SCHOOLS ARE
#   Every school plotted; colour = Indigenous enrolment, size = total enrolment.
pal <- colorNumeric(palette = "magma", domain = c(0, 100), reverse = TRUE)

popup_html <- function(name, town, fte, ind) {
  paste0("<b>", name, "</b><br/>", town,
         "<br/>Enrolment (FTE): ", ifelse(is.na(fte), "n/a", round(fte)),
         "<br/>Indigenous: ", ifelse(is.na(ind), "not published", paste0(ind, "%")))
}

map <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  setView(lng = 147, lat = -32.5, zoom = 6) %>%
  
  # suppressed schools (toggle on/off)
  addCircleMarkers(
    data = filter(schools, indigenous_suppressed),
    lng = ~Longitude, lat = ~Latitude,
    radius = 3, color = "grey", stroke = FALSE, fillOpacity = 0.5,
    group = "Suppressed (<=5 students)",
    popup = ~popup_html(School_name, Town_suburb, latest_year_enrolment_FTE, Indigenous_pct)
  ) %>%
  
  # published schools, coloured by Indigenous %, sized by enrolment
  addCircleMarkers(
    data = schools_pub,
    lng = ~Longitude, lat = ~Latitude,
    radius = ~scales::rescale(sqrt(latest_year_enrolment_FTE), to = c(2, 12)),
    color = ~pal(Indigenous_pct), stroke = FALSE, fillOpacity = 0.8,
    group = "Indigenous % (published)",
    popup = ~popup_html(School_name, Town_suburb, latest_year_enrolment_FTE, Indigenous_pct)
  ) %>%
  addLegend("bottomright", pal = pal, values = c(0, 100),
            title = "Indigenous<br/>enrolment (%)", opacity = 0.9) %>%
  addLayersControl(
    overlayGroups = c("Indigenous % (published)", "Suppressed (<=5 students)"),
    options = layersControlOptions(collapsed = FALSE)
  )
map 

# VISUALISATION 2 — DISTRIBUTION OF STUDENT ENROLMENTS
median_fte <- median(schools$latest_year_enrolment_FTE, na.rm = TRUE)

p2 <- schools %>%
  filter(!is.na(latest_year_enrolment_FTE)) %>%
  ggplot(aes(latest_year_enrolment_FTE)) +
  geom_histogram(binwidth = 50, fill = "blue", colour = "white", boundary = 0) +
  geom_vline(xintercept = median_fte, linetype = "dashed", colour = "grey20") +
  annotate("text", x = median_fte + 40, y = Inf, vjust = 2, hjust = 0,
           label = paste0("Median = ", round(median_fte), " students"),
           colour = "grey20", size = 3.5) +
  scale_x_continuous(labels = comma, breaks = seq(0, 2500, 250)) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.05))) +
  labs(
    title    = "Distribution of total enrolment (full-time equivalent students)",
    x = "Student enrolment (FTE)", y = "Number of schools"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot", plot.caption.position = "plot"
  )
p2

# VISUALISATION 3: INDIGENOUS ENROLMENT BY REMOTENESS
remote_means <- schools_pub %>%
  group_by(remoteness_short) %>%
  summarise(mean_ind = mean(Indigenous_pct), n = n(), .groups = "drop")

p3 <- ggplot(schools_pub, aes(remoteness_short, Indigenous_pct,
                              fill = remoteness_short)) +
  geom_violin(colour = NA, alpha = 0.5, scale = "width") +
  geom_jitter(width = 0.12, size = 0.5, alpha = 0.25, colour = "red") +
  stat_summary(fun = mean, geom = "point", size = 3, colour = "black") +
  geom_text(data = remote_means,
            aes(remoteness_short, mean_ind, label = paste0(round(mean_ind), "%")),
            vjust = -1.2, fontface = "bold", size = 3.6, inherit.aes = FALSE) +
  scale_fill_viridis_d(option = "magma", direction = -1, end = 0.9, guide = "none") +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(0, 105)) +
  labs(
    title    = "Percentage of Aboriginal & Torres Strait Islander per school, by remoteness category",
    x = NULL, y = "Indigenous enrolment (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot", plot.caption.position = "plot"
  )
p3

# VISUALISATION 4: INDIGENOUS ENROLMENT (%) vs ICSEA VALUE
r_val <- cor(schools_pub$Indigenous_pct, schools_pub$ICSEA_value,
             use = "complete.obs")

p4 <- schools_pub %>%
  filter(!is.na(ICSEA_value)) %>%
  ggplot(aes(Indigenous_pct, ICSEA_value)) +
  geom_point(aes(colour = ASGS_remoteness), alpha = 0.55, size = 1.4) +
  geom_smooth(method = "lm", se = TRUE, colour = "black", linewidth = 0.9) +
  geom_hline(yintercept = 1000, linetype = "dotted", colour = "grey40") +
  annotate("text", x = 95, y = 1010, label = "National average (1000)",
           hjust = 1, size = 3, colour = "grey40") +
  annotate("text", x = 2, y = 660, hjust = 0, size = 3.8, fontface = "bold",
           label = paste0("r = ", round(r_val, 2))) +
  scale_colour_viridis_d(option = "magma", direction = -1, end = 0.9,
                         name = "Remoteness") +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  labs(
    title    = "Indigenous Enrollment (%) vs ICSEA Value",
    x = "Indigenous enrolment (%)", y = "ICSEA value"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    panel.grid.minor = element_blank(),
    plot.title.position = "plot", plot.caption.position = "plot"
  )
p4

# VISUALISATION 5: CONCENTRATION OF INDIGENOUS STUDENTS BY REMOTENESS
share_tbl <- schools %>%
  filter(!is.na(latest_year_enrolment_FTE)) %>%
  group_by(ASGS_remoteness) %>%
  summarise(all_fte = sum(latest_year_enrolment_FTE, na.rm = TRUE),
            ind_fte = sum(indigenous_fte,           na.rm = TRUE),
            .groups = "drop") %>%
  mutate(`All students`        = all_fte / sum(all_fte) * 100,
         `Indigenous students` = ind_fte / sum(ind_fte) * 100) %>%
  select(ASGS_remoteness, `All students`, `Indigenous students`) %>%
  pivot_longer(-ASGS_remoteness, names_to = "group", values_to = "share")

p5 <- ggplot(share_tbl, aes(x = share, y = fct_rev(ASGS_remoteness),
                            fill = group)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.65) +
  geom_text(aes(label = paste0(round(share), "%")),
            position = position_dodge(width = 0.7), hjust = -0.15, size = 3.2) +
  scale_fill_manual(values = c("All students" = "red",
                               "Indigenous students" = "blue"),
                    name = NULL) +
  scale_x_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.12))) +
  labs(
    title    = "ALL NSW PUBLIC STUDENTS VS INDIGENOUS STUDENTS, BY REMOTENESS",
    x = "Share of students", y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 16),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    plot.title.position = "plot", plot.caption.position = "plot"
  )
p5