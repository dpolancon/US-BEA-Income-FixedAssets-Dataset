############################################################
# 00_config_provider.R - Chapter 2 provider configuration
############################################################

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

ch2_provider_root <- function() {
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  marker <- file.path(root, "US-BEA-Income-FixedAssets-Dataset.Rproj")
  if (!file.exists(marker)) stop("Run scripts from the repository root.")
  root
}

ch2_provider_paths <- function(root = ch2_provider_root()) {
  list(
    root = root,
    menu = file.path(root, "data", "provider_menu"),
    raw = file.path(root, "data", "raw", "provider"),
    docs = file.path(root, "docs"),
    menu_csv = file.path(root, "data", "provider_menu", "ch2_master_variable_menu.csv"),
    metadata_csv = file.path(root, "data", "provider_menu", "ch2_master_variable_metadata.csv"),
    status_csv = file.path(root, "data", "provider_menu", "ch2_provider_fetch_status.csv"),
    bea_discovery_csv = file.path(root, "data", "provider_menu", "ch2_bea_table_discovery.csv"),
    fred_candidates_csv = file.path(root, "data", "provider_menu", "ch2_fred_fallback_candidates.csv")
  )
}

ensure_ch2_provider_dirs <- function(paths = ch2_provider_paths()) {
  invisible(lapply(
    c(paths$menu, paths$raw, paths$docs),
    dir.create, recursive = TRUE, showWarnings = FALSE
  ))
}

provider_timestamp <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
}

empty_character <- function(n = 1L) rep("", n)

assert_columns <- function(data, columns, object_name) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0L) {
    stop(object_name, " lacks required columns: ", paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

bea_request <- function(method, query = list(), api_key = Sys.getenv("BEA_API_KEY")) {
  if (!nzchar(api_key)) stop("BEA_API_KEY is not set.")
  if (!requireNamespace("httr", quietly = TRUE)) stop("Package 'httr' is required.")

  response <- httr::GET(
    "https://apps.bea.gov/api/data/",
    query = c(
      list(UserID = api_key, method = method, ResultFormat = "JSON"),
      query
    ),
    httr::timeout(120)
  )
  httr::stop_for_status(response)
  payload <- httr::content(response, as = "parsed", simplifyVector = FALSE)
  error <- payload$BEAAPI$Results$Error
  if (!is.null(error)) {
    stop(error$APIErrorDescription %||% error$APIErrorCode %||% "Unknown BEA API error.")
  }
  payload
}

discover_bea_tables <- function(dataset_name) {
  payload <- bea_request(
    "GetParameterValues",
    list(
      DataSetName = dataset_name,
      ParameterName = "TableName"
    )
  )
  records <- payload$BEAAPI$Results$ParamValue
  if (is.null(records)) records <- payload$BEAAPI$Results$ParameterValues
  if (is.null(records) || length(records) == 0L) {
    stop("No BEA table metadata returned for ", dataset_name, ".")
  }

  rows <- lapply(records, function(x) {
    data.frame(
      bea_dataset = dataset_name,
      key = as.character(x$Key %||% x$TableName %||% ""),
      description = as.character(x$Desc %||% x$Description %||% ""),
      retrieved_at = provider_timestamp(),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

fetch_bea_table <- function(dataset_name, table_name, year = "ALL", frequency = NULL) {
  query <- list(
    DataSetName = dataset_name,
    TableName = table_name,
    Year = year
  )
  if (!is.null(frequency)) query$Frequency <- frequency
  payload <- bea_request("GetData", query)
  records <- payload$BEAAPI$Results$Data
  if (is.null(records) || length(records) == 0L) {
    stop("No BEA data returned for ", dataset_name, "/", table_name, ".")
  }

  rows <- lapply(records, function(x) {
    raw_value <- as.character(x$DataValue %||% "")
    data.frame(
      dataset = dataset_name,
      table_name = table_name,
      series_code = as.character(x$SeriesCode %||% ""),
      line_number = suppressWarnings(as.integer(x$LineNumber %||% NA_character_)),
      line_description = as.character(x$LineDescription %||% ""),
      metric_name = as.character(x$METRIC_NAME %||% x$MetricName %||% ""),
      time_period = as.character(x$TimePeriod %||% ""),
      cl_unit = as.character(x$CL_UNIT %||% ""),
      unit_mult = as.character(x$UNIT_MULT %||% ""),
      data_value = suppressWarnings(as.numeric(gsub(",", "", raw_value, fixed = TRUE))),
      note_ref = as.character(x$NoteRef %||% ""),
      retrieved_at = provider_timestamp(),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

write_preserving_snapshot <- function(data, dataset_name, table_name,
                                      paths = ch2_provider_paths()) {
  out_dir <- file.path(paths$raw, format(Sys.Date(), "%Y-%m-%d"))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, paste0(dataset_name, "_", table_name, "_ch2.csv"))
  if (file.exists(out_path)) {
    message("Preserving existing raw snapshot: ", out_path)
    return(out_path)
  }
  utils::write.csv(data, out_path, row.names = FALSE, na = "")
  out_path
}

find_latest_bea_snapshot <- function(dataset_name, table_name,
                                     paths = ch2_provider_paths()) {
  patterns <- c(
    paste0("^", dataset_name, "_", table_name, "_ch2\\.csv$"),
    paste0("^", dataset_name, "_", table_name, "\\.csv$")
  )
  candidates <- unlist(lapply(patterns, function(pattern) {
    list.files(paths$raw, pattern = pattern, recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  candidates <- unique(candidates)
  if (length(candidates) == 0L) return(NULL)
  sort(candidates, decreasing = TRUE)[1]
}

standardize_bea_snapshot <- function(path, dataset_name, table_name) {
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (all(c("dataset", "table_name", "line_number", "line_description") %in% names(data))) {
    return(data)
  }
  if (all(c("year", "line_number", "line_desc", "value") %in% names(data))) {
    return(data.frame(
      dataset = dataset_name,
      table_name = table_name,
      series_code = as.character(data$series_code %||% empty_character(nrow(data))),
      line_number = suppressWarnings(as.integer(data$line_number)),
      line_description = as.character(data$line_desc),
      metric_name = "",
      time_period = as.character(data$year),
      cl_unit = as.character(data$unit %||% empty_character(nrow(data))),
      unit_mult = "",
      data_value = suppressWarnings(as.numeric(data$value)),
      note_ref = "",
      retrieved_at = basename(dirname(path)),
      stringsAsFactors = FALSE
    ))
  }
  stop("Unrecognized BEA snapshot schema: ", path)
}

search_fred_series <- function(search_text, api_key = Sys.getenv("FRED_API_KEY"),
                               limit = 10L) {
  if (!nzchar(api_key)) stop("FRED_API_KEY is not set.")
  if (!requireNamespace("httr", quietly = TRUE)) stop("Package 'httr' is required.")

  response <- httr::GET(
    "https://api.stlouisfed.org/fred/series/search",
    query = list(
      api_key = api_key,
      file_type = "json",
      search_text = search_text,
      limit = limit,
      order_by = "search_rank"
    ),
    httr::timeout(120)
  )
  httr::stop_for_status(response)
  payload <- httr::content(response, as = "parsed", simplifyVector = FALSE)
  records <- payload$seriess
  if (is.null(records) || length(records) == 0L) return(data.frame())

  rows <- lapply(records, function(x) {
    series_id <- as.character(x$id %||% "")
    series_notes <- as.character(x$notes %||% "")
    series_notes <- trimws(gsub(
      "[[:space:]]+",
      " ",
      series_notes
    ))
    inferred_source <- if (
      grepl("BEA$", series_id, ignore.case = TRUE) ||
        grepl("bea\\.gov|Bureau of Economic Analysis", series_notes,
              ignore.case = TRUE)
    ) {
      "U.S. Bureau of Economic Analysis"
    } else {
      "Source not established by FRED search response"
    }
    data.frame(
      series_id = series_id,
      title = as.character(x$title %||% ""),
      observation_start = as.character(x$observation_start %||% ""),
      observation_end = as.character(x$observation_end %||% ""),
      frequency = as.character(x$frequency %||% ""),
      units = as.character(x$units %||% ""),
      seasonal_adjustment = as.character(x$seasonal_adjustment %||% ""),
      source = inferred_source,
      popularity = suppressWarnings(as.integer(x$popularity %||% NA_character_)),
      notes = paste(
        "candidate_only_not_accepted;",
        "requires title, BEA origin, frequency, units, and sample-span review.",
        series_notes
      ),
      retrieved_at = provider_timestamp(),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

allowed_sector_scopes <- c("CORP", "NFC", "FC", "NA")
allowed_asset_scopes <- c("ME", "NRC", "ME_NRC", "IPP", "GOVTRANS",
                          "ALL_FIXED_ASSETS", "NA")
allowed_fetch_statuses <- c(
  "direct_bea", "fallback_fred", "constructed_sector_residual",
  "direct_fetch_available_but_not_used", "unresolved",
  "not_fetchable_parameter", "excluded_from_locked_menu",
  "derivable_from_bea_components"
)
allowed_construction_statuses <- c(
  "primitive_fetch", "fallback_constructed", "metadata_only",
  "not_constructed_here", "source_level_derived"
)
allowed_chapter2_roles <- c(
  "preferred_baseline_source", "robustness_source", "source_ingredient",
  "gpim_required_source", "gpim_parameter", "fallback_only",
  "validation_only", "excluded", "unresolved"
)
