############################################################
# 30_fetch_income_accounts_menu.R - Fetch provider NIPA menu
############################################################

rm(list = ls())
source("codes/10_bea_api_helpers.R")

paths <- provider_paths()
ensure_provider_dirs(paths)

tables <- c("T11400", "T71100")
key <- Sys.getenv("BEA_API_KEY")

if (!nzchar(key)) {
  message("BEA_API_KEY is not set. No live NIPA fetch attempted.")
  message("Staging will use auditable cached extracts where available.")
  quit(save = "no", status = 0)
}

for (table in tables) {
  message("Fetching NIPA/", table)
  data <- fetch_bea_table("NIPA", table, year = "X", api_key = key)
  path <- write_raw_snapshot(data, "NIPA", table, paths)
  message("Preserved raw snapshot: ", path)
}
