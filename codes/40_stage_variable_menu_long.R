############################################################
# 40_stage_variable_menu_long.R - Stage provider menu long
############################################################

rm(list = ls())
source("codes/10_bea_api_helpers.R")

paths <- provider_paths()
ensure_provider_dirs(paths)
manifest <- provider_manifest()
write_locked_manifest(manifest, paths)

numeric_line <- grepl("^[0-9]+$", manifest$bea_line)
direct <- manifest[numeric_line & grepl("^(FAA|T)", manifest$bea_table), , drop = FALSE]

staged_parts <- list()
for (table in unique(direct$bea_table)) {
  source_object <- read_provider_table(table, paths)
  if (is.null(source_object)) {
    message("No provider raw snapshot or legacy cache for ", table)
    next
  }

  source_data <- source_object$data
  required_columns <- c("year", "line_number", "line_desc", "value")
  missing_columns <- setdiff(required_columns, names(source_data))
  if (length(missing_columns) > 0L) {
    stop("Source ", source_object$path, " lacks: ",
         paste(missing_columns, collapse = ", "))
  }
  source_data$year <- as.integer(source_data$year)
  source_data$line_number <- as.integer(source_data$line_number)
  source_data$value <- suppressWarnings(as.numeric(source_data$value))

  table_manifest <- direct[direct$bea_table == table, , drop = FALSE]
  for (i in seq_len(nrow(table_manifest))) {
    spec <- table_manifest[i, , drop = FALSE]
    line <- as.integer(spec$bea_line)
    observations <- source_data[source_data$line_number == line, , drop = FALSE]
    if (nrow(observations) == 0L) {
      message("Mapped line missing: ", spec$variable_id, " (", table, " L", line, ")")
      next
    }

    actual_desc <- as.character(observations$line_desc)
    out <- data.frame(
      date = sprintf("%04d-12-31", observations$year),
      year = observations$year,
      value = observations$value,
      variable_id = spec$variable_id,
      canonical_name = spec$canonical_name,
      source_system = spec$source_system,
      bea_dataset = spec$bea_dataset,
      bea_table = spec$bea_table,
      bea_line = spec$bea_line,
      bea_line_description = actual_desc,
      series_code = if ("series_code" %in% names(observations)) {
        ifelse(is.na(observations$series_code), "not_provided", observations$series_code)
      } else {
        spec$series_code
      },
      sector_boundary = spec$sector_boundary,
      asset_block = spec$asset_block,
      account_boundary = spec$account_boundary,
      frequency = spec$frequency,
      unit = spec$unit,
      price_basis = spec$price_basis,
      stock_flow_type = spec$stock_flow_type,
      role_tag = spec$role_tag,
      priority = spec$priority,
      required_for_downstream_object = spec$required_for_downstream_object,
      download_date = source_object$download_date,
      vintage = if (source_object$source == "provider_raw_snapshot") {
        paste0(
          "BEA API snapshot downloaded ", source_object$download_date,
          "; release vintage not separately exposed in API observation rows"
        )
      } else {
        spec$vintage
      },
      source_url_or_query = spec$source_url_or_query,
      status = "staged",
      notes = spec$notes,
      source_file = gsub("\\\\", "/", source_object$path),
      aggregation_group = spec$aggregation_group,
      stringsAsFactors = FALSE
    )
    staged_parts[[length(staged_parts) + 1L]] <- out
  }
}

if (length(staged_parts) == 0L) {
  stop("No variables could be staged.")
}

staged <- do.call(rbind, staged_parts)
staged <- staged[order(staged$variable_id, staged$year), , drop = FALSE]
staged_path <- file.path(paths$staged, "us_bea_variable_menu_long.csv")
utils::write.csv(staged, staged_path, row.names = FALSE, na = "")

ledger <- manifest
ledger$row_count <- 0L
ledger$coverage_start <- "not_staged"
ledger$coverage_end <- "not_staged"
ledger$staged_source_file <- "not_staged"

for (i in seq_len(nrow(ledger))) {
  observations <- staged[staged$variable_id == ledger$variable_id[i], , drop = FALSE]
  if (nrow(observations) > 0L) {
    ledger$row_count[i] <- nrow(observations)
    ledger$coverage_start[i] <- as.character(min(observations$year, na.rm = TRUE))
    ledger$coverage_end[i] <- as.character(max(observations$year, na.rm = TRUE))
    ledger$download_date[i] <- observations$download_date[1]
    ledger$bea_line_description[i] <- observations$bea_line_description[1]
    ledger$staged_source_file[i] <- observations$source_file[1]
    ledger$status[i] <- "staged"
  } else if (ledger$status[i] == "staged") {
    ledger$status[i] <- "requires_manual_mapping"
    ledger$notes[i] <- paste(
      ledger$notes[i],
      "The locked mapping had no readable raw snapshot or cached extract during this run."
    )
  }
}

ledger_path <- file.path(paths$metadata, "us_bea_source_provenance_ledger.csv")
utils::write.csv(ledger, ledger_path, row.names = FALSE, na = "")

message("Locked manifest: ", file.path(paths$metadata, "us_bea_variable_menu_locked.csv"))
message("Staged menu: ", staged_path, " (", nrow(staged), " rows)")
message("Provenance ledger: ", ledger_path, " (", nrow(ledger), " variables)")
