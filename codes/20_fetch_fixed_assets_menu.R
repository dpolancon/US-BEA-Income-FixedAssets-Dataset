############################################################
# 20_fetch_fixed_assets_menu.R - Fetch provider fixed assets
############################################################

rm(list = ls())
source("codes/10_bea_api_helpers.R")

paths <- provider_paths()
ensure_provider_dirs(paths)

tables <- c("FAAt401", "FAAt402", "FAAt404", "FAAt407",
            "FAAt701", "FAAt702", "FAAt703", "FAAt705")
key <- Sys.getenv("BEA_API_KEY")

if (!nzchar(key)) {
  message("BEA_API_KEY is not set. No live fixed-assets fetch attempted.")
  message("Staging will use auditable cached extracts where available.")
  quit(save = "no", status = 0)
}

for (table in tables) {
  message("Fetching FixedAssets/", table)
  data <- fetch_bea_table("FixedAssets", table, year = "ALL", api_key = key)
  path <- write_raw_snapshot(data, "FixedAssets", table, paths)
  message("Preserved raw snapshot: ", path)
}
