# ============================================================
# GLOBAL SILENCERS (must be VERY first)
# ============================================================
sink("/dev/null", type = "message")   # only silence messages, not stdout
options(warn = -1)                    # suppress warnings
suppressPackageStartupMessages({
  library(nflreadr)
  library(dplyr)
  library(jsonlite)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)


# ============================================================
# GLOBAL SAFETY OPTIONS
# ============================================================
options(timeout = 600)  # allow long downloads


# ============================================================
# FILE-BASED PBP CACHE
# ============================================================
cache_file <- function(season) {
  paste0("pbp_cache_", season, ".rds")
}

load_pbp_cached <- function(season) {
  f <- cache_file(season)

  if (file.exists(f)) {
    return(readRDS(f))
  }

  pbp <- nflreadr::load_pbp(season)
  saveRDS(pbp, f)
  return(pbp)
}


# ============================================================
# NAME NORMALIZATION
# ============================================================
normalize_passer <- function(name) {
  if (is.na(name)) return(NA)

  name <- gsub("\\(.*?\\)", "", name)
  name <- trimws(gsub("\\s+", " ", name))

  if (grepl("^[A-Z]\\.[A-Za-z]+$", name)) return(name)

  parts <- unlist(strsplit(name, " "))
  if (length(parts) >= 2) {
    first <- substr(parts[1], 1, 1)
    last  <- parts[length(parts)]
    return(paste0(first, ".", last))
  }

  return(name)
}


# ============================================================
# MODE: LIST ALL QBs FOR A SEASON
# ============================================================
if (length(args) == 2 && args[1] == "list") {

  season <- as.numeric(args[2])
  pbp <- load_pbp_cached(season)

  possible_cols <- c(
    "passer_player_name", "passer_name", "passer",
    "name", "player_name", "qb", "passer_full_name"
  )

  passer_col <- NULL
  for (col in possible_cols) {
    if (col %in% names(pbp) &&
        any(!is.na(pbp[[col]]) & pbp[[col]] != "")) {
      passer_col <- col
      break
    }
  }

  if (is.null(passer_col)) {
    cat(toJSON(list(error = "No valid passer column found in PBP"), auto_unbox = TRUE))
    flush.console()
    quit(save = "no", status = 0, runLast = FALSE)
  }

  qbs <- pbp %>%
    filter(!is.na(.data[[passer_col]])) %>%
    group_by(.data[[passer_col]]) %>%
    summarise(attempts = sum(pass_attempt == 1, na.rm = TRUE)) %>%
    filter(attempts >= 300) %>%
    arrange(desc(attempts))

  qb_names <- qbs[[passer_col]]

  cat(toJSON(qb_names, auto_unbox = TRUE))
  flush.console()
  quit(save = "no", status = 0, runLast = FALSE)
}


# ============================================================
# NORMAL MODE (single QB) — 5-METRIC VERSION
# ============================================================
qb_input_raw <- args[1]
season <- as.integer(args[2])

qb_input <- normalize_passer(qb_input_raw)

pbp <- tryCatch(load_pbp_cached(season), error = function(e) NULL)

if (is.null(pbp)) {
  cat(toJSON(list(error = paste("Failed to load PBP for season", season)), auto_unbox = TRUE))
  flush.console()
  quit(save = "no", status = 0, runLast = FALSE)
}

possible_cols <- c(
  "passer_player_name", "passer_name", "passer",
  "name", "player_name", "qb", "passer_full_name"
)

passer_col <- NULL
for (col in possible_cols) {
  if (col %in% names(pbp) &&
      any(!is.na(pbp[[col]]) & pbp[[col]] != "")) {
    passer_col <- col
    break
  }
}

if (is.null(passer_col)) {
  cat(toJSON(list(error = "No valid passer column found in PBP"), auto_unbox = TRUE))
  flush.console()
  quit(save = "no", status = 0, runLast = FALSE)
}

pbp[[passer_col]] <- sapply(pbp[[passer_col]], normalize_passer)

passer_data <- pbp %>% filter(.data[[passer_col]] == qb_input)

if (nrow(passer_data) == 0) {
  cat(toJSON(list(error = paste("QB not found:", qb_input_raw)), auto_unbox = TRUE))
  flush.console()
  quit(save = "no", status = 0, runLast = FALSE)
}

true_name <- qb_input

# PASSING STATS
attempts     <- sum(passer_data$pass_attempt,    na.rm = TRUE)
completions  <- sum(passer_data$complete_pass,   na.rm = TRUE)
yards        <- sum(passer_data$passing_yards,   na.rm = TRUE)
td           <- sum(passer_data$pass_touchdown,  na.rm = TRUE)
ints         <- sum(passer_data$interception,    na.rm = TRUE)
sacks        <- sum(passer_data$sack,            na.rm = TRUE)
sack_yards   <- sum(passer_data$sack_yards,      na.rm = TRUE)

epa <- mean(passer_data$epa, na.rm = TRUE)
if (is.na(epa) || is.nan(epa)) epa <- 0

comp_pct <- ifelse(attempts > 0, completions / attempts * 100, 0)
td_pct   <- ifelse(attempts > 0, td / attempts * 100, 0)
int_pct  <- ifelse(attempts > 0, ints / attempts * 100, 0)
sack_pct <- ifelse(attempts + sacks > 0, sacks / (attempts + sacks) * 100, 0)

# SAFE SCORING
scale_score <- function(x, min_val, max_val) {
  if (is.na(x) || is.nan(x)) return(0)
  if (max_val == min_val) return(0)

  score <- (x - min_val) / (max_val - min_val) * 10
  score <- pmax(pmin(score, 10), 0)

  if (is.na(score) || is.nan(score)) return(0)
  return(score)
}

# 5-METRIC SCORES
comp_score <- scale_score(comp_pct, 55, 70)
td_score   <- scale_score(td_pct, 2.5, 7.0)
int_score  <- scale_score(10 - int_pct, 0, 10)
sack_score <- scale_score(10 - sack_pct, 0, 10)
epa_score  <- scale_score(epa, -0.1, 0.3)

# 5-METRIC WEIGHTED QB SCORE
qb_score <- (
  comp_score * 0.25 +
  td_score   * 0.25 +
  int_score  * 0.20 +
  sack_score * 0.15 +
  epa_score  * 0.15
)

qb_tier <- dplyr::case_when(
  qb_score >= 8.5 ~ "Great",
  qb_score >= 7.0 ~ "Good",
  qb_score >= 5.5 ~ "Fair",
  qb_score >= 4.0 ~ "Average",
  TRUE            ~ "Poor"
)

result <- list(
  qb_name = true_name,
  season  = season,

  comp_pct = comp_pct,
  td_pct = td_pct,
  int_pct = int_pct,
  sack_pct = sack_pct,
  epa_per_play = epa,

  comp_score = comp_score,
  td_score = td_score,
  int_score = int_score,
  sack_score = sack_score,
  epa_score = epa_score,

  qb_score = qb_score,
  qb_tier = qb_tier
)

cat(toJSON(result, auto_unbox = TRUE))
flush.console()
quit(save = "no", status = 0, runLast = FALSE)

