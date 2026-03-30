# ============================================================
# 24_manifest_runner.R
# Sole orchestrator + sole manifest writer for Chapter 1
# Critical Replication pipeline (S0/S1/S2).
#
# Script registry: 20_S0 → 21_S1 → 22_S2_m2 → 23_S2_m3 → 80_pack
# No stage script writes to the manifest. This file owns it.
#
# Date: 2026-03-11
# ============================================================

rm(list = ls())

# ---- helpers ---------------------------------------------------------------
iso_stamp <- function(x = Sys.time()) {
  format(x, "%Y-%m-%dT%H:%M:%S%z", tz = Sys.timezone())
}

safe_system <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) structure(conditionMessage(e), status = 1L)
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = as.character(out))
}

# ---- setup ----------------------------------------------------------------
source(here::here("codes", "10_config.R"))

run_start <- Sys.time()
run_stamp <- format(run_start, "%Y%m%d_%H%M%S")
run_id    <- paste0("ch1_", run_stamp)

tz_name <- Sys.timezone()
if (is.na(tz_name) || !nzchar(tz_name)) tz_name <- "UNKNOWN"

git_hash <- safe_system("git", c("rev-parse", "--short", "HEAD"))
git_hash_val <- if (git_hash$status == 0L) {
  trimws(paste(git_hash$output, collapse = "\n"))
} else {
  "UNAVAILABLE"
}

manifest_dir <- here::here(CONFIG$OUT_CR$manifest)
manifest_logs_dir <- file.path(manifest_dir, "logs")
dir.create(manifest_logs_dir, recursive = TRUE, showWarnings = FALSE)

sessioninfo_path <- file.path(manifest_logs_dir, "SESSIONINFO_ch1.txt")
writeLines(capture.output(sessionInfo()), con = sessioninfo_path)

# ---- smoke test: all registered scripts must exist -------------------------
script_plan <- data.frame(
  script = c(
    "20_S0_shaikh_faithful.R",
    "21_S1_ardl_geometry.R",
    "22_S2_vecm_bivariate.R",
    "23_S2_vecm_trivariate.R",
    "80_pack_ch1_replication.R"
  ),
  description = c(
    "S0: faithful ARDL(2,4) replication",
    "S1: ARDL specification geometry (500-spec lattice)",
    "S2 m=2: bivariate VECM system identification",
    "S2 m=3: trivariate VECM + rotation check",
    "Results packaging: strict consumer of S0/S1/S2 public CSVs"
  ),
  stringsAsFactors = FALSE
)

script_plan$path   <- file.path("codes", script_plan$script)
script_plan$exists <- vapply(
  script_plan$script,
  function(s) file.exists(here::here("codes", s)),
  logical(1)
)

# Pre-flight: all scripts must be present
missing_scripts <- script_plan$script[!script_plan$exists]
if (length(missing_scripts) > 0) {
  message("SMOKE TEST FAILED: missing scripts: ",
          paste(missing_scripts, collapse = ", "))
  message("Runner will proceed but mark missing scripts as failed.")
}

# Initialize status columns
script_plan$status      <- "not_run"
script_plan$exit_code   <- NA_integer_
script_plan$log_path    <- NA_character_
script_plan$reason_code <- NA_character_
script_plan$timestamp   <- NA_character_
script_plan$seed        <- if (!is.null(CONFIG$seed)) {
  as.character(CONFIG$seed)
} else {
  NA_character_
}
script_plan$git_hash <- git_hash_val

# ---- execute each script ---------------------------------------------------
for (i in seq_len(nrow(script_plan))) {
  log_file <- file.path(manifest_logs_dir,
                         sub("\\.R$", "_run.log", script_plan$script[i]))
  script_plan$log_path[i] <- file.path(
    "output/CriticalReplication/Manifest/logs", basename(log_file)
  )

  if (!isTRUE(script_plan$exists[i])) {
    writeLines(sprintf("MISSING SCRIPT: %s", script_plan$path[i]),
               con = log_file)
    script_plan$status[i]      <- "failed"
    script_plan$reason_code[i] <- "SCRIPT_MISSING"
    script_plan$exit_code[i]   <- NA_integer_
    script_plan$timestamp[i]   <- iso_stamp(Sys.time())
    next
  }

  cat(sprintf("[%s] Running %s ...\n", iso_stamp(), script_plan$script[i]))

  run <- tryCatch({
    Sys.setenv(CR_RUN_ID = run_id)
    safe_system(
      R.home("bin/Rscript"),
      c(shQuote(here::here("codes", script_plan$script[i])))
    )
  }, error = function(e) list(status = 1L, output = conditionMessage(e)))

  writeLines(run$output, con = log_file)
  script_plan$exit_code[i] <- run$status
  script_plan$timestamp[i] <- iso_stamp(Sys.time())

  hint_line <- grep("STAGE_STATUS_HINT:", run$output, value = TRUE)
  infeasible_hint <- any(grepl("infeasible_specs_skipped=true", hint_line,
                                fixed = TRUE))

  if (run$status == 0L && infeasible_hint) {
    script_plan$status[i]      <- "ok_with_infeasible_specs_skipped"
    script_plan$reason_code[i] <- "INFEASIBLE_SPECS_SKIPPED"
  } else if (run$status == 0L) {
    script_plan$status[i]      <- "ok"
    script_plan$reason_code[i] <- "OK"
  } else {
    script_plan$status[i]      <- "failed"
    script_plan$reason_code[i] <- "NONZERO_EXIT"
  }
}

# ---- deviation checks ------------------------------------------------------
deviations <- character()
if (any(!script_plan$exists)) {
  deviations <- c(deviations, sprintf(
    "Missing script(s): %s.",
    paste(script_plan$script[!script_plan$exists], collapse = ", ")
  ))
}
if (any(script_plan$status == "failed")) {
  deviations <- c(deviations, sprintf(
    "Failed script(s): %s.",
    paste(script_plan$script[script_plan$status == "failed"], collapse = ", ")
  ))
}
if (is.null(CONFIG$WINDOWS_LOCKED$shaikh_window)) {
  deviations <- c(deviations, "CONFIG$WINDOWS_LOCKED$shaikh_window is missing.")
}

# ---- output artifact index -------------------------------------------------
artifact_files <- character()
if (dir.exists(here::here("output"))) {
  all_outputs <- list.files(here::here("output"), recursive = TRUE,
                            full.names = TRUE)
  if (length(all_outputs) > 0L) {
    finfo <- file.info(all_outputs)
    artifact_files <- all_outputs[!is.na(finfo$mtime) &
                                    finfo$mtime >= run_start - 1]
    artifact_files <- normalizePath(artifact_files, winslash = "/",
                                    mustWork = FALSE)
    repo_root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)
    artifact_files <- sub(paste0("^", repo_root, "/"), "", artifact_files)
    artifact_files <- sort(unique(artifact_files))
  }
}

if (!length(artifact_files)) {
  deviations <- c(deviations, "No new/updated output artifacts detected.")
}

# ---- validate declared public artifacts ------------------------------------
# After execution, verify each stage's public outputs exist
public_contracts <- list(
  "20_S0_shaikh_faithful.R" = c(
    "output/CriticalReplication/S0_faithful/csv/S0_spec_report.csv",
    "output/CriticalReplication/S0_faithful/csv/S0_utilization_series.csv",
    "output/CriticalReplication/S0_faithful/csv/S0_fivecase_summary.csv"
  ),
  "21_S1_ardl_geometry.R" = c(
    "output/CriticalReplication/S1_geometry/csv/S1_lattice_full.csv",
    "output/CriticalReplication/S1_geometry/csv/S1_admissible.csv",
    "output/CriticalReplication/S1_geometry/csv/S1_frontier_F020.csv"
  ),
  "22_S2_vecm_bivariate.R" = c(
    "output/CriticalReplication/S2_vecm/csv/S2_m2_admissible.csv",
    "output/CriticalReplication/S2_vecm/csv/S2_m2_omega20.csv"
  ),
  "23_S2_vecm_trivariate.R" = c(
    "output/CriticalReplication/S2_vecm/csv/S2_m3_admissible.csv",
    "output/CriticalReplication/S2_vecm/csv/S2_m3_omega20.csv",
    "output/CriticalReplication/S2_vecm/csv/S2_rotation_check.csv"
  )
)

for (script_name in names(public_contracts)) {
  row_idx <- which(script_plan$script == script_name)
  if (length(row_idx) == 0 || script_plan$status[row_idx] != "ok") next

  expected <- public_contracts[[script_name]]
  missing_artifacts <- expected[!file.exists(here::here(expected))]

  if (length(missing_artifacts) > 0) {
    deviations <- c(deviations, sprintf(
      "CONTRACT WARNING: %s completed OK but missing public artifacts: %s",
      script_name, paste(basename(missing_artifacts), collapse = ", ")
    ))
  }
}

# ---- write manifest markdown -----------------------------------------------
manifest_md_path  <- file.path(manifest_dir, "RUN_MANIFEST_ch1.md")
manifest_csv_path <- file.path(manifest_dir, "RUN_MANIFEST_ch1.csv")

window_years <- CONFIG$WINDOWS_LOCKED$shaikh_window
window_label <- if (!is.null(window_years) && length(window_years) == 2L) {
  sprintf("%s-%s", window_years[[1]], window_years[[2]])
} else {
  "UNAVAILABLE"
}

md <- c(
  "# RUN MANIFEST — Chapter 1 Critical Replication",
  "",
  "## Run metadata",
  sprintf("- Run ID: `%s`", run_id),
  sprintf("- Timestamp: `%s`", iso_stamp(run_start)),
  sprintf("- Timezone: `%s`", tz_name),
  sprintf("- Git hash: `%s`", git_hash_val),
  sprintf("- Seed: `%s`",
          if (!is.null(CONFIG$seed)) as.character(CONFIG$seed) else "NA"),
  sprintf("- Machine/OS: `%s`",
          paste(names(Sys.info()), Sys.info(), collapse = "; ")),
  "",
  "## Input data and variable mapping",
  sprintf("- Dataset path: `%s`", CONFIG$data_shaikh),
  sprintf("- Shock type: `%s`", CONFIG$SHOCK_TYPE),
  sprintf("- Window lock: `shaikh_window` (%s)", window_label),
  "",
  "## Script execution log",
  "| Script | Description | Exists | Status | Exit | Reason | Log |",
  "|---|---|---|---|---|---|---|"
)

for (i in seq_len(nrow(script_plan))) {
  md <- c(md, sprintf(
    "| `%s` | %s | %s | %s | %s | %s | `%s` |",
    script_plan$script[i],
    script_plan$description[i],
    ifelse(isTRUE(script_plan$exists[i]), "yes", "no"),
    script_plan$status[i],
    ifelse(is.na(script_plan$exit_code[i]), "NA",
           as.character(script_plan$exit_code[i])),
    ifelse(is.na(script_plan$reason_code[i]), "NA",
           script_plan$reason_code[i]),
    script_plan$log_path[i]
  ))
}

md <- c(md, "", "## Output artifact index")
if (length(artifact_files)) {
  md <- c(md, paste0("- `", artifact_files, "`"))
} else {
  md <- c(md, "- No artifacts indexed.")
}

md <- c(md, "",
  "## Session snapshot",
  sprintf("- `sessionInfo()` → `%s`",
          file.path("output/CriticalReplication/Manifest/logs",
                    basename(sessioninfo_path))),
  "",
  "## Deviations / notes"
)
if (length(deviations)) {
  md <- c(md, paste0("- ", deviations))
} else {
  md <- c(md, "- None.")
}

writeLines(md, con = manifest_md_path)

# CSV manifest
csv_manifest <- script_plan[, c("script", "path", "description", "exists",
                                 "status", "exit_code", "reason_code",
                                 "log_path", "timestamp", "seed", "git_hash")]
csv_manifest$run_id         <- run_id
csv_manifest$run_started_at <- iso_stamp(run_start)
csv_manifest$timezone       <- tz_name
write.csv(csv_manifest, file = manifest_csv_path, row.names = FALSE)

message("Chapter 1 runner complete.")
message("Manifest written: ", manifest_md_path)
message("Manifest CSV written: ", manifest_csv_path)
