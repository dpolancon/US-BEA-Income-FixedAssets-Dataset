############################################################
# 01_discover_bea_metadata.R - Discover BEA table metadata
############################################################

rm(list = ls())
source("codes/00_config_provider.R")

paths <- ch2_provider_paths()
ensure_ch2_provider_dirs(paths)

key <- Sys.getenv("BEA_API_KEY")
if (nzchar(key)) {
  discovered <- do.call(rbind, lapply(c("NIPA", "FixedAssets"), function(dataset) {
    message("Discovering BEA ", dataset, " table metadata")
    result <- discover_bea_tables(dataset)
    Sys.sleep(0.5)
    result
  }))
} else {
  snapshots <- list.files(
    paths$raw,
    pattern = "^(NIPA|FixedAssets)_[A-Za-z0-9]+\\.csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  parsed <- regexec(
    "^(NIPA|FixedAssets)_([A-Za-z0-9]+)\\.csv$",
    basename(snapshots)
  )
  matches <- regmatches(basename(snapshots), parsed)
  valid <- lengths(matches) == 3L
  matches <- matches[valid]
  snapshots <- snapshots[valid]
  if (length(matches) == 0L) {
    discovered <- data.frame(
      bea_dataset = character(), key = character(),
      description = character(), retrieved_at = character()
    )
  } else {
    descriptions <- c(
      T11400 = "NIPA Table 1.14 corporate business income and product accounts",
      T71100 = "NIPA Table 7.11 imputed interest",
      FAAt401 = "Fixed Assets Table 4.1 current-cost net stock",
      FAAt402 = "Fixed Assets Table 4.2 net-stock chain-type quantity indexes",
      FAAt404 = "Fixed Assets Table 4.4 current-cost depreciation",
      FAAt407 = "Fixed Assets Table 4.7 current-cost investment",
      FAAt701 = "Fixed Assets Table 7.1 government current-cost net stock",
      FAAt702 = "Fixed Assets Table 7.2 government net-stock quantity indexes",
      FAAt703 = "Fixed Assets Table 7.3 government current-cost depreciation",
      FAAt705 = "Fixed Assets Table 7.5 government current-cost investment",
      FAAt707 = "Fixed Assets Table 7.7 government current-cost average age"
    )
    keys <- vapply(matches, `[[`, character(1), 3)
    datasets <- vapply(matches, `[[`, character(1), 2)
    discovered <- data.frame(
      bea_dataset = datasets,
      key = keys,
      description = ifelse(
        keys %in% names(descriptions),
        unname(descriptions[keys]),
        "Preserved provider snapshot; live metadata discovery requires BEA_API_KEY"
      ),
      retrieved_at = basename(dirname(snapshots)),
      stringsAsFactors = FALSE
    )
    discovered <- unique(discovered)
  }
  message("BEA_API_KEY is not set; discovered tables from preserved provider snapshots.")
}

discovered <- discovered[order(discovered$bea_dataset, discovered$key), , drop = FALSE]
utils::write.csv(discovered, paths$bea_discovery_csv, row.names = FALSE, na = "")
message("BEA table discovery: ", paths$bea_discovery_csv, " (", nrow(discovered), " rows)")
