# ============================================================
# 30_data_crossvalidation_shaikh_v2.R
# Cross-validate Shaikh_canonical_series_v1.csv against
# Shaikh (2016) Appendix 6.8 Data Tables (Corrected)
#
# v2: fixes lowercase 'year', handles transposed xlsx layout
# ============================================================

library(here)
library(dplyr)
library(tidyr)
library(readxl)

cat("\n========================================\n")
cat("  DATA CROSS-VALIDATION v2: Shaikh (2016)\n")
cat("========================================\n\n")

# --- 0. Paths ---
path_canon  <- here("data", "raw", "Shaikh_canonical_series_v1.csv")
path_shaikh <- here("data", "raw", "_Appendix6.8DataTablesCorrected.xlsx")

stopifnot(
  "Canonical CSV not found" = file.exists(path_canon),
  "Shaikh xlsx not found"   = file.exists(path_shaikh)
)

# --- 1. Load canonical CSV ---
canon <- read.csv(path_canon, stringsAsFactors = FALSE)
cat("== CANONICAL CSV ==\n")
cat("Dimensions:", nrow(canon), "x", ncol(canon), "\n")
cat("Year range:", range(canon$year, na.rm = TRUE), "\n")
cat("Columns:\n")
cat(" ", paste(names(canon), collapse = ", "), "\n\n")

# Quick sanity: print a few key values
cat("Spot checks:\n")
cat("  KGCcorp[year==1947]:", canon$KGCcorp[canon$year == 1947], "\n")
cat("  KGCcorp[year==2011]:", canon$KGCcorp[canon$year == 2011], "\n")
cat("  VAcorp[year==1947]: ", canon$VAcorp[canon$year == 1947], "\n")
cat("  GVAcorp[year==1947]:", canon$GVAcorp[canon$year == 1947], "\n")
cat("  Py[year==1947]:     ", canon$Py[canon$year == 1947], "\n")
cat("  Py[year==2009]:     ", canon$Py[canon$year == 2009], "\n\n")

# --- 2. Helper: read a transposed Shaikh sheet ---
# Shaikh sheets are wide: rows = variables, columns = years
# Column 1 = Description, Column 2 = Source, Column 3 = Variable,
# then year columns (numeric names like "1947", "1948", ...)
read_shaikh_sheet <- function(path, sheet_name) {
  df <- tryCatch(
    read_excel(path, sheet = sheet_name, col_names = TRUE),
    error = function(e) {
      cat("  [ERROR reading", sheet_name, ":", e$message, "]\n")
      return(NULL)
    }
  )
  if (is.null(df) || nrow(df) == 0) return(NULL)
  
  # Find the Variable column (could be named "Variable", "...3", or similar)
  # Strategy: look for a column whose values look like variable names
  var_col <- NULL
  for (cn in names(df)) {
    vals <- as.character(df[[cn]])
    vals <- vals[!is.na(vals)]
    # Variable names typically contain letters and no spaces, or known patterns
    if (any(grepl("^[A-Z][A-Za-z]", vals)) && !any(grepl("^(Description|Source|All|New|Appendix)", vals))) {
      var_col <- cn
      break
    }
  }
  
  # Also try explicit "Variable" or position 3
  if (is.null(var_col)) {
    if ("Variable" %in% names(df)) {
      var_col <- "Variable"
    } else if (ncol(df) >= 3) {
      # Check if column 3 has variable-name-like content
      vals3 <- as.character(df[[3]])
      if (any(grepl("corp|Corp|bea|BEA|IGC|KNC|KGC|VAcorp|GVA|Py|pKN", vals3, ignore.case = TRUE))) {
        var_col <- names(df)[3]
      }
    }
  }
  
  if (is.null(var_col)) {
    cat("  [No Variable column identified in", sheet_name, "]\n")
    return(NULL)
  }
  
  # Identify year columns: names that are numeric (4-digit)
  year_cols <- grep("^\\d{4}$", names(df), value = TRUE)
  # Also catch "1946...5" style names from readxl deduplication
  year_cols2 <- grep("^\\d{4}\\.{3}\\d+$", names(df), value = TRUE)
  
  if (length(year_cols) == 0 && length(year_cols2) == 0) {
    cat("  [No year columns found in", sheet_name, "]\n")
    return(NULL)
  }
  
  # Use clean year columns only
  all_year_cols <- year_cols
  
  # Extract variable names
  var_names <- as.character(df[[var_col]])
  
  cat("  Sheet:", sheet_name, "\n")
  cat("  Variable column:", var_col, "\n")
  cat("  Year columns:", length(all_year_cols),
      "(", min(all_year_cols), "-", max(all_year_cols), ")\n")
  cat("  Variables found:\n")
  for (v in var_names[!is.na(var_names)]) {
    cat("    -", v, "\n")
  }
  cat("\n")
  
  # Pivot to long format: one row per (Variable, Year)
  result <- list()
  for (i in seq_len(nrow(df))) {
    vname <- var_names[i]
    if (is.na(vname) || vname == "" || grepl("^(Description|Source|Variable)$", vname)) next
    vals <- as.numeric(unlist(df[i, all_year_cols]))
    years <- as.numeric(all_year_cols)
    result[[vname]] <- data.frame(
      year = years,
      value = vals,
      stringsAsFactors = FALSE
    )
  }
  
  return(result)
}

# --- 3. Read all data sheets ---
cat("========================================\n")
cat("  READING SHAIKH APPENDIX SHEETS\n")
cat("========================================\n\n")

data_sheets <- c(
  "Appndx 6.8.II.1",
  "Appndx 6.8.II.3",
  "Appndx 6.8.II.5",
  "Appndx 6.8.II.7"
)

shaikh_vars <- list()  # flat lookup: variable_name -> data.frame(year, value)
for (s in data_sheets) {
  sheet_data <- read_shaikh_sheet(path_shaikh, s)
  if (!is.null(sheet_data)) {
    for (vname in names(sheet_data)) {
      # If duplicate variable across sheets, later sheet wins (II.7 is final)
      shaikh_vars[[vname]] <- sheet_data[[vname]]
    }
  }
}

cat("Total Shaikh variables loaded:", length(shaikh_vars), "\n")
cat("Variable names:\n")
for (v in names(shaikh_vars)) {
  n_valid <- sum(!is.na(shaikh_vars[[v]]$value))
  cat("  ", v, "(", n_valid, "obs)\n")
}

# --- 4. Helper: compare canonical column vs Shaikh variable ---
compare_series <- function(canon_df, shaikh_long, canon_col, shaikh_varname, label) {
  if (!canon_col %in% names(canon_df)) {
    cat("\n  [SKIP", label, "- column", canon_col, "not in canonical CSV]\n")
    return(NULL)
  }
  if (!shaikh_varname %in% names(shaikh_long)) {
    cat("\n  [SKIP", label, "- variable", shaikh_varname, "not in Shaikh data]\n")
    return(NULL)
  }
  
  d1 <- data.frame(year = canon_df$year, canon = as.numeric(canon_df[[canon_col]]))
  d2 <- shaikh_long[[shaikh_varname]]
  names(d2) <- c("year", "shaikh")
  
  merged <- merge(d1, d2, by = "year")
  merged <- merged[complete.cases(merged), ]
  
  if (nrow(merged) == 0) {
    cat("\n  [SKIP", label, "- no overlapping years with valid data]\n")
    return(NULL)
  }
  
  merged$abs_diff <- abs(merged$canon - merged$shaikh)
  merged$pct_diff <- ifelse(
    merged$shaikh != 0,
    100 * merged$abs_diff / abs(merged$shaikh),
    NA
  )
  merged$ratio <- ifelse(
    merged$shaikh != 0,
    merged$canon / merged$shaikh,
    NA
  )
  
  cat("\n===", label, "===\n")
  cat("  Canon col:", canon_col, " | Shaikh var:", shaikh_varname, "\n")
  cat("  Overlap:", nrow(merged), "years (",
      min(merged$year), "-", max(merged$year), ")\n")
  
  # Exact match test
  exact <- all(merged$abs_diff < 0.01, na.rm = TRUE)
  near  <- all(merged$abs_diff < 0.1, na.rm = TRUE)
  cat("  EXACT MATCH (tol=0.01):", exact, "\n")
  if (!exact) cat("  NEAR MATCH  (tol=0.10):", near, "\n")
  
  if (!exact) {
    cat("  Max abs diff:", round(max(merged$abs_diff, na.rm=T), 4),
        "in year", merged$year[which.max(merged$abs_diff)], "\n")
    cat("  Mean pct diff:", round(mean(merged$pct_diff, na.rm=T), 4), "%\n")
    cat("  Max pct diff:", round(max(merged$pct_diff, na.rm=T), 4), "%\n")
    
    r <- merged$ratio[!is.na(merged$ratio)]
    cat("  Ratio (canon/shaikh):\n")
    cat("    mean:", round(mean(r), 6), "\n")
    cat("    SD:  ", round(sd(r), 6), "\n")
    cat("    range:", round(range(r), 6), "\n")
    
    if (sd(r) < 0.005) {
      cat("  >> DIAGNOSIS: LEVEL SHIFT (constant ratio ~",
          round(mean(r), 4), ") → release/base-year difference\n")
    } else {
      cat("  >> DIAGNOSIS: DIVERGENT → construction or vintage difference\n")
      early <- merged$ratio[merged$year <= 1977]
      late  <- merged$ratio[merged$year > 1977]
      if (length(early) > 2 && length(late) > 2) {
        cat("    Pre-1977 ratio SD:", round(sd(early, na.rm=T), 6), "\n")
        cat("    Post-1977 ratio SD:", round(sd(late, na.rm=T), 6), "\n")
      }
    }
    
    # Print worst 5 years
    worst <- merged[order(-merged$pct_diff), ][1:min(5, nrow(merged)), ]
    cat("  Worst 5 years:\n")
    print(worst[, c("year", "canon", "shaikh", "pct_diff", "ratio")], row.names = FALSE)
  }
  
  invisible(merged)
}

# --- 5. Run comparisons ---
cat("\n========================================\n")
cat("  SERIES COMPARISONS\n")
cat("========================================\n")

# Print available Shaikh variable names for matching
cat("\nAvailable Shaikh variables for matching:\n")
cat(paste(names(shaikh_vars), collapse = "\n"), "\n\n")

# Attempt automatic matching — adjust these if variable names differ
# Common patterns in Shaikh's xlsx: KGCcorp, KNCcorp, VAcorp, GVAcorp, Py, pKN
candidates <- list(
  list(canon = "KGCcorp",     shaikh_patterns = c("KGCcorp", "KGCCorpNew", "KGCcorpnew")),
  list(canon = "KNCcorpbea",  shaikh_patterns = c("KNCcorpbea", "KNCcorp")),
  list(canon = "VAcorp",      shaikh_patterns = c("VAcorp", "VACorpAdj", "VACorp")),
  list(canon = "GVAcorp",     shaikh_patterns = c("GVAcorp", "GVACorpAdj", "GVACorpNew")),
  list(canon = "Py",          shaikh_patterns = c("Py", "py", "GDP_deflator")),
  list(canon = "pKN",         shaikh_patterns = c("pKN", "pKNcorp", "PKN")),
  list(canon = "IGCcorpbea",  shaikh_patterns = c("IGCcorpbea", "IGCcorp", "IGC")),
  list(canon = "DEPCcorp",    shaikh_patterns = c("DEPCcorp", "dcorpnew", "dcorp")),
  list(canon = "INVcorp",     shaikh_patterns = c("INVcorp", "INV")),
  list(canon = "Rcorp",       shaikh_patterns = c("Rcorp", "rcorp")),
  list(canon = "uK",          shaikh_patterns = c("uK", "uk", "uKcorp", "CU"))
)

available <- names(shaikh_vars)
for (cand in candidates) {
  match_found <- FALSE
  for (pat in cand$shaikh_patterns) {
    # Try exact match first
    if (pat %in% available) {
      compare_series(canon, shaikh_vars, cand$canon, pat,
                     paste0(cand$canon, " vs ", pat))
      match_found <- TRUE
      break
    }
    # Try case-insensitive grep
    hits <- grep(paste0("^", pat, "$"), available, ignore.case = TRUE, value = TRUE)
    if (length(hits) > 0) {
      compare_series(canon, shaikh_vars, cand$canon, hits[1],
                     paste0(cand$canon, " vs ", hits[1]))
      match_found <- TRUE
      break
    }
  }
  if (!match_found) {
    cat("\n  [NO MATCH for canonical", cand$canon, "]\n")
  }
}

# --- 6. KGCcorp_1947 anchor ---
cat("\n========================================\n")
cat("  KGCcorp_1947 ANCHOR CHECK\n")
cat("========================================\n")
K1947 <- canon$KGCcorp[canon$year == 1947]
cat("  Canonical KGCcorp_1947:", K1947, "\n")
cat("  Expected (memory):      170.58 Bn\n")
if (!is.na(K1947)) {
  cat("  Match (tol=0.5):", abs(K1947 - 170.58) < 0.5, "\n")
  cat("  Difference:", round(K1947 - 170.58, 4), "\n")
}
# Also check Shaikh's own value if available
if ("KGCcorp" %in% names(shaikh_vars)) {
  sk <- shaikh_vars[["KGCcorp"]]
  sk1947 <- sk$value[sk$year == 1947]
  if (length(sk1947) > 0 && !is.na(sk1947)) {
    cat("  Shaikh KGCcorp_1947:", sk1947, "\n")
  }
}

# --- 7. Deflator sanity ---
cat("\n========================================\n")
cat("  DEFLATOR (Py) SANITY CHECK\n")
cat("========================================\n")
py47 <- canon$Py[canon$year == 1947]
py09 <- canon$Py[canon$year == 2009]
py11 <- canon$Py[canon$year == 2011]
cat("  Py[1947]:", py47, "\n")
cat("  Py[2009]:", py09, "\n")
cat("  Py[2011]:", py11, "\n")
cat("  Expected (NIPA 1.1.9 L1, 2012=100):\n")
cat("    1947 ~ 12.0,  2009 ~ 100.0,  2011 ~ 103.3\n")
if (!is.na(py47)) {
  if (py47 < 1) {
    cat("  >> Py stored as fraction (index/100)\n")
  } else if (py47 > 1 && py47 < 20) {
    cat("  >> Py stored as index (2012=100 scale)\n")
  } else if (py47 > 100) {
    cat("  >> Py stored as index, different base year\n")
  }
}

# --- 8. Variable opacity: l_ys = GVA or NVA? ---
cat("\n========================================\n")
cat("  VARIABLE OPACITY: l_ys IDENTIFICATION\n")
cat("========================================\n")
has_all <- all(c("VAcorp", "GVAcorp", "KGCcorp", "Py") %in% names(canon))
if (has_all) {
  # Determine Py scale
  py_max <- max(canon$Py, na.rm = TRUE)
  py_divisor <- ifelse(py_max > 10, 100, 1)
  cat("  Py max:", py_max, "→ divisor:", py_divisor, "\n")
  
  sub <- canon %>%
    filter(year >= 1947, year <= 2011) %>%
    mutate(
      l_ys_GVA = log(GVAcorp / (Py / py_divisor)),
      l_ys_NVA = log(VAcorp  / (Py / py_divisor)),
      l_ks     = log(KGCcorp / (Py / py_divisor)),
      R_NVA    = VAcorp / KGCcorp,
      R_GVA    = GVAcorp / KGCcorp
    )
  
  lm_GVA <- lm(l_ys_GVA ~ l_ks, data = sub)
  lm_NVA <- lm(l_ys_NVA ~ l_ks, data = sub)
  
  cat("\n  OLS theta (bivariate, full sample 1947-2011):\n")
  cat("    GVA hypothesis:", round(coef(lm_GVA)[2], 4), "\n")
  cat("    NVA hypothesis:", round(coef(lm_NVA)[2], 4), "\n")
  cat("    Shaikh ARDL LR: 0.6609\n\n")
  
  cat("  Profit rate diagnostic:\n")
  cat("    Mean VAcorp/KGCcorp  (R_net):", round(mean(sub$R_NVA, na.rm=T), 4), "\n")
  cat("    Mean GVAcorp/KGCcorp (R_gro):", round(mean(sub$R_GVA, na.rm=T), 4), "\n")
}

# --- 9. Scan for CU series ---
cat("\n========================================\n")
cat("  CAPACITY UTILIZATION SERIES SCAN\n")
cat("========================================\n")
cu_hits <- grep("uK|CU|cu|util|capac|uhat", names(shaikh_vars),
                ignore.case = TRUE, value = TRUE)
if (length(cu_hits) > 0) {
  cat("  Found CU variables:", paste(cu_hits, collapse = ", "), "\n")
  for (h in cu_hits) {
    sv <- shaikh_vars[[h]]
    sv <- sv[!is.na(sv$value), ]
    cat("    ", h, ":", nrow(sv), "obs, range",
        round(range(sv$value), 4), "\n")
  }
  # Compare against canonical uK if available
  if ("uK" %in% names(canon) && length(cu_hits) > 0) {
    cat("\n  Comparing canonical uK vs Shaikh CU series:\n")
    compare_series(canon, shaikh_vars, "uK", cu_hits[1],
                   paste0("uK vs ", cu_hits[1]))
  }
} else {
  cat("  No CU/utilization variables found in Shaikh sheets.\n")
}

cat("\n========================================\n")
cat("  DONE. Review output above.\n")
cat("========================================\n")