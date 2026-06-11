############################################################
# 02_discover_fred_candidates.R - Search FRED fallbacks
############################################################

rm(list = ls())
source("codes/00_config_provider.R")

paths <- ch2_provider_paths()
ensure_ch2_provider_dirs(paths)

if (!file.exists(paths$menu_csv)) {
  message("Master menu is not present; building it before FRED discovery.")
  source("codes/03_build_ch2_master_variable_menu.R", local = new.env())
}
menu <- utils::read.csv(paths$menu_csv, stringsAsFactors = FALSE, check.names = FALSE)

columns <- c(
  "variable_id", "sector_scope", "search_text", "series_id", "title",
  "observation_start", "observation_end", "frequency", "units",
  "seasonal_adjustment", "source", "popularity", "notes", "retrieved_at"
)
search_rows <- menu[
  nzchar(menu$fred_search_text) &
    !menu$fetch_status %in% c("not_fetchable_parameter", "excluded_from_locked_menu"),
  c("variable_id", "sector_scope", "fred_search_text"),
  drop = FALSE
]

key <- Sys.getenv("FRED_API_KEY")
results <- list()
if (nzchar(key)) {
  for (i in seq_len(nrow(search_rows))) {
    spec <- search_rows[i, , drop = FALSE]
    message("Searching FRED for ", spec$variable_id)
    candidates <- search_fred_series(spec$fred_search_text, api_key = key)
    if (nrow(candidates) > 0L) {
      candidates$variable_id <- spec$variable_id
      candidates$sector_scope <- spec$sector_scope
      candidates$search_text <- spec$fred_search_text
      candidates <- candidates[, columns, drop = FALSE]
      results[[length(results) + 1L]] <- candidates
    }
    Sys.sleep(0.5)
  }
} else {
  message("FRED_API_KEY is not set; writing an empty candidate file with the locked schema.")
}

if (length(results) == 0L) {
  output <- as.data.frame(
    setNames(replicate(length(columns), character(), simplify = FALSE), columns),
    stringsAsFactors = FALSE
  )
  output$popularity <- integer()
} else {
  output <- do.call(rbind, results)
  output <- output[order(output$variable_id, -output$popularity), , drop = FALSE]
}

utils::write.csv(output, paths$fred_candidates_csv, row.names = FALSE, na = "")
message("FRED fallback candidates: ", paths$fred_candidates_csv,
        " (", nrow(output), " rows)")
