############################################################
# 99_utils.R — Shared utilities for Chapter 1 pipeline
############################################################

`%||%` <- function(x, y) if (is.null(x)) y else x

# ------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------
now_stamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# ------------------------------------------------------------------
# Safe I/O helpers
# ------------------------------------------------------------------
safe_write_csv <- function(df, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, path, row.names = FALSE)
}

# ------------------------------------------------------------------
# BEA API wrapper (used by 56_fetch_bea_extension.R)
# ------------------------------------------------------------------
bea_get <- function(dataset, tablename, frequency = "A",
                    year = "X", api_key = Sys.getenv("BEA_API_KEY")) {
  resp <- httr::GET(
    "https://apps.bea.gov/api/data",
    query = list(
      UserID       = api_key,
      method       = "GetData",
      datasetname  = dataset,
      tablename    = tablename,
      frequency    = frequency,
      year         = year,
      ResultFormat = "JSON"
    )
  )
  httr::stop_for_status(resp)
  dat <- httr::content(resp, as = "parsed")$BEAAPI$Results$Data
  df  <- dplyr::bind_rows(lapply(dat, as.data.frame, stringsAsFactors = FALSE))
  df$DataValue <- as.numeric(gsub(",", "", df$DataValue))
  df
}
