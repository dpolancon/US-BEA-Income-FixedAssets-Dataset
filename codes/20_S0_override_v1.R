library(ARDL)
library(dynlm)
library(dplyr)
library(here)
source("codes/10_config.R")
source("codes/99_utils.R")

# ── Logging ───────────────────────────────────────────────────────────
out_dir <- here::here("output", "CriticalReplication", "S0_manualOverride")


LOG <- function(...) {
  txt <- paste0(capture.output(cat(...)), collapse = "\n")
  cat(txt, "\n")
  cat(txt, "\n", file = log_file, append = TRUE)
}

LOG_PRINT <- function(x) {
  txt <- paste0(capture.output(print(x)), collapse = "\n")
  cat(txt, "\n")
  cat(txt, "\n", file = log_file, append = TRUE)
}

# ── Data ──────────────────────────────────────────────────────────────
df <- readr::read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types = FALSE)

build_data <- function(df) {
  df |>
    filter(year >= 1947, year <= 2011) |>
    mutate(
      lnY   = log(VAcorp / (Py / 100)),
      lnK   = log(KGCcorp / (Py / 100)),
      d1956 = as.integer(year >= 1956),
      d1974 = as.integer(year >= 1974),
      d1980 = as.integer(year >= 1980),
      trend = row_number()
    )
}

# =====================================================================
#  REPLICATION 1: ARDL(2,4) — NO TREND
# =====================================================================

LOG("=" |> strrep(65))
LOG("REPLICATION 1: ARDL(2,4) — NO TREND")
LOG("=" |> strrep(65))

df_w  <- build_data(df)
df_ts <- ts(df_w |> select(lnY, lnK, d1956, d1974, d1980),
            start = 1947, frequency = 1)

# ── Step 1: ARDL estimation ──────────────────────────────────────────

ardl_dynlm <- dynlm(lnY ~ L(lnY, 1) + L(lnY, 2) +
                      lnK + L(lnK, 1) + L(lnK, 2) + L(lnK, 3) + L(lnK, 4) +
                      d1956 + d1974 + d1980,
                    data = df_ts, start = 1947, end = 2011)

LOG("\n--- ARDL(2,4) no-trend ---")
LOG_PRINT(summary(ardl_dynlm))

# Cross-check with ARDL package
ardl_pkg <- ardl(lnY ~ lnK | d1956 + d1974 + d1980,
                 data = df_ts, order = c(2, 4),
                 start = 1947, end = 2011)
LOG("dynlm vs ARDL pkg match:", all.equal(coef(ardl_dynlm), coef(ardl_pkg), tolerance = 1e-8))

# ── Step 2: Long-run multipliers ─────────────────────────────────────

cc        <- coef(ardl_dynlm)
gamma_sum <- cc["L(lnY, 1)"] + cc["L(lnY, 2)"]
phi_sum   <- cc["lnK"] + cc["L(lnK, 1)"] + cc["L(lnK, 2)"] + cc["L(lnK, 3)"] + cc["L(lnK, 4)"]
denom     <- 1 - gamma_sum

a     <- cc["(Intercept)"] / denom
c1_lr <- cc["d1956"] / denom
c2_lr <- cc["d1974"] / denom
c3_lr <- cc["d1980"] / denom
theta <- phi_sum / denom

LOG("\n--- Long-run multipliers (no trend) ---")
LOG("1 - sum(gamma) =", denom)
LOG("a (intercept)  =", a)
LOG("d1956 (long-run) =", c1_lr)
LOG("d1974 (long-run) =", c2_lr)
LOG("d1980 (long-run) =", c3_lr)
LOG("theta (K elasticity) =", theta)

# ── Step 3: ECT construction ─────────────────────────────────────────

df_w <- df_w |>
  mutate(
    ECT_raw  = lnY - (a + c1_lr * d1956 + c2_lr * d1974 + c3_lr * d1980 + theta * lnK),
    ECT_mean = mean(lnY - (a + c1_lr * d1956 + c2_lr * d1974 + c3_lr * d1980 + theta * lnK)),
    ECT      = ECT_raw - ECT_mean
  )
df_w1 <- df_w
df_ts_ect <- ts(df_w |> select(lnY, lnK, d1956, d1974, d1980, ECT),
                start = 1947, frequency = 1)

# ── Step 4: Restricted ECM (no trend) ────────────────────────────────

recm_r1 <- dynlm(d(lnY) ~ L(d(lnY), 1) + L(d(lnY), 2) +
                   d(lnK) + L(d(lnK), 1) + L(d(lnK), 2) + L(d(lnK), 3) + L(d(lnK), 4) +
                   L(ECT, 1),
                 data = df_ts_ect, start = 1947, end = 2011)

LOG("\n--- RECM (no trend) ---")
LOG_PRINT(summary(recm_r1))
LOG("pi_y (speed of adjustment) =", coef(recm_r1)["L(ECT, 1)"])


# =====================================================================
#  REPLICATION 2: ARDL(2,4) — WITH TREND
# =====================================================================

LOG("\n\n")
LOG("=" |> strrep(65))
LOG("REPLICATION 2: ARDL(2,4) — WITH TREND")
LOG("=" |> strrep(65))

df_w  <- build_data(df)
df_ts <- ts(df_w |> select(lnY, lnK, d1956, d1974, d1980),
            start = 1947, frequency = 1)

# ── Step 1: ARDL estimation ──────────────────────────────────────────

ardl_dynlm <- dynlm(lnY ~ trend(lnY) + L(lnY, 1) + L(lnY, 2) +
                      lnK + L(lnK, 1) + L(lnK, 2) + L(lnK, 3) + L(lnK, 4) +
                      d1956 + d1974 + d1980,
                    data = df_ts, start = 1947, end = 2011)

LOG("\n--- ARDL(2,4) with trend ---")
LOG_PRINT(summary(ardl_dynlm))

# Cross-check with ARDL package
ardl_pkg <- ardl(lnY ~ trend(lnY) + lnK | d1956 + d1974 + d1980,
                 data = df_ts, order = c(2, 4),
                 start = 1947, end = 2011)
LOG("dynlm vs ARDL pkg match:", all.equal(coef(ardl_dynlm), coef(ardl_pkg), tolerance = 1e-8))

# ── Step 2: Long-run multipliers ─────────────────────────────────────

cc        <- coef(ardl_dynlm)
gamma_sum <- cc["L(lnY, 1)"] + cc["L(lnY, 2)"]
phi_sum   <- cc["lnK"] + cc["L(lnK, 1)"] + cc["L(lnK, 2)"] + cc["L(lnK, 3)"] + cc["L(lnK, 4)"]
denom     <- 1 - gamma_sum

a     <- cc["(Intercept)"] / denom
b     <- cc["trend(lnY)"] / denom
c1_lr <- cc["d1956"] / denom
c2_lr <- cc["d1974"] / denom
c3_lr <- cc["d1980"] / denom
theta <- phi_sum / denom

LOG("\n--- Long-run multipliers (with trend) ---")
LOG("1 - sum(gamma) =", denom)
LOG("a (intercept)  =", a)
LOG("b (trend)      =", b)
LOG("d1956 (long-run) =", c1_lr)
LOG("d1974 (long-run) =", c2_lr)
LOG("d1980 (long-run) =", c3_lr)
LOG("theta (K elasticity) =", theta)

# ── Step 3: ECT construction (trend + dummies in long-run) ───────────

df_w <- df_w |>
  mutate(
    ECT_raw  = lnY - (a + b * trend + c1_lr * d1956 + c2_lr * d1974 + c3_lr * d1980 + theta * lnK),
    ECT_mean = mean(lnY - (a + b * trend + c1_lr * d1956 + c2_lr * d1974 + c3_lr * d1980 + theta * lnK)),
    ECT      = ECT_raw - ECT_mean
  )
df_w2 <- df_w
df_ts_ect <- ts(df_w |> select(lnY, lnK, d1956, d1974, d1980, ECT),
                start = 1947, frequency = 1)


# ── Step 4: Restricted ECM (with trend) ──────────────────────────────

recm_r2 <- dynlm(d(lnY) ~ trend(lnY) + L(d(lnY), 1) + L(d(lnY), 2) +
                   d(lnK) + L(d(lnK), 1) + L(d(lnK), 2) + L(d(lnK), 3) + L(d(lnK), 4) +
                   L(ECT, 1),
                 data = df_ts_ect, start = 1947, end = 2011)

LOG("\n--- RECM (with trend) ---")
LOG_PRINT(summary(recm_r2))
LOG("pi_y (speed of adjustment) =", coef(recm_r2)["L(ECT, 1)"])


# =====================================================================
#  COMPARISON SUMMARY
# =====================================================================

LOG("\n\n")
LOG("=" |> strrep(65))
LOG("COMPARISON SUMMARY")
LOG("=" |> strrep(65))

# Recover theta from each ARDL
cc1 <- coef(ardl(lnY ~ lnK | d1956 + d1974 + d1980,
                 data = df_ts, order = c(2, 4), start = 1947, end = 2011))
g1  <- cc1["L(lnY, 1)"] + cc1["L(lnY, 2)"]
p1  <- cc1["lnK"] + cc1["L(lnK, 1)"] + cc1["L(lnK, 2)"] + cc1["L(lnK, 3)"] + cc1["L(lnK, 4)"]

cc2 <- coef(ardl(lnY ~ trend(lnY) + lnK | d1956 + d1974 + d1980,
                 data = df_ts, order = c(2, 4), start = 1947, end = 2011))
g2  <- cc2["L(lnY, 1)"] + cc2["L(lnY, 2)"]
p2  <- cc2["lnK"] + cc2["L(lnK, 1)"] + cc2["L(lnK, 2)"] + cc2["L(lnK, 3)"] + cc2["L(lnK, 4)"]

LOG("")
LOG(sprintf("%-22s %-12s %-12s", "", "No Trend", "With Trend"))
LOG(sprintf("%-22s %-12.4f %-12.4f", "theta (LR mult.)", p1 / (1 - g1), p2 / (1 - g2)))
LOG(sprintf("%-22s %-12.4f %-12.4f", "pi_y (ECT coef.)", coef(recm_r1)["L(ECT, 1)"], coef(recm_r2)["L(ECT, 1)"]))
LOG(sprintf("%-22s %-12.4f %-12.4f", "1 - sum(gamma)", 1 - g1, 1 - g2))

export_cu <- function(df_w, label) {
  out <- df_w |> select(year, lnY, lnK, ECT_raw, ECT) |>
    mutate(cu = exp(ECT))
  fpath <- file.path(out_dir, paste0("cu_", label, ".csv"))
  readr::write_csv(out, fpath)
  LOG("Exported:", fpath)
}

export_cu(df_w1, "notrend_VAKG")
export_cu(df_w2, "trend_VAKG")


LOG("\n=== Done ===")