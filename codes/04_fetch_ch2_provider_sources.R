############################################################
# 04_fetch_ch2_provider_sources.R - Fetch/cache BEA sources
############################################################

rm(list = ls())
source("codes/00_config_provider.R")

paths <- ch2_provider_paths()
ensure_ch2_provider_dirs(paths)

if (!file.exists(paths$menu_csv)) {
  stop("Build the master menu first with codes/03_build_ch2_master_variable_menu.R.")
}
menu <- utils::read.csv(paths$menu_csv, stringsAsFactors = FALSE, check.names = FALSE)
direct <- unique(menu[
  menu$fetch_status == "direct_bea" &
    nzchar(menu$bea_dataset) &
    nzchar(menu$bea_table_name),
  c("bea_dataset", "bea_table_name"),
  drop = FALSE
])

key <- Sys.getenv("BEA_API_KEY")
for (i in seq_len(nrow(direct))) {
  dataset <- direct$bea_dataset[i]
  table <- direct$bea_table_name[i]
  if (nzchar(key)) {
    message("Fetching ", dataset, "/", table)
    frequency <- if (dataset == "NIPA") "A" else NULL
    data <- fetch_bea_table(dataset, table, year = "ALL", frequency = frequency)
    path <- write_preserving_snapshot(data, dataset, table, paths)
    message("Raw snapshot: ", path)
    Sys.sleep(0.5)
  } else {
    path <- find_latest_bea_snapshot(dataset, table, paths)
    if (is.null(path)) {
      message("No API key and no preserved snapshot for ", dataset, "/", table)
    } else {
      data <- standardize_bea_snapshot(path, dataset, table)
      message("Using preserved snapshot for ", dataset, "/", table,
              " (", nrow(data), " rows): ", path)
    }
  }
}

if (!nzchar(key)) {
  message("BEA_API_KEY is not set; no live BEA requests were made.")
}
