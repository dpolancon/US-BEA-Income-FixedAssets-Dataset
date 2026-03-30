rm(list = ls())

library(here)
library(readxl)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(ARDL)
library(ggplot2)

source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))

# Locked toggles
WINDOW_TAG   <- "shaikh_window"
ORDER        <- c(2, 4)
DUMMY_YEARS  <- c(1956L, 1974L, 1980L)
EXACT_TEST   <- FALSE

# Paste the helper functions from the script directly:
# make_step_dummies(), rebase_to_year_to_100(), extract_bt(),
# stars_from_p(), get_lr_table_with_scaled_dummies(),
# extract_lr_row(), extract_alpha_from_uecm(), compute_u_from_lr()


df_raw <- readxl::read_excel(here::here(CONFIG$data_shaikh), 
                             sheet = CONFIG$data_shaikh_sheet)


rebase_to_year_to_100 <- function(p_vec, year_vec, base_year, strict = TRUE) {
  idx <- which(year_vec == base_year)
  if (length(idx) != 1) {
    msg <- paste0("Base year ", base_year, " not uniquely present in price index series.")
    if (strict) stop(msg) else {
      warning(msg, " Falling back to first observation in provided series.")
      idx <- 1
    }
  }
  p0 <- p_vec[idx]
  if (!is.finite(p0) || p0 <= 0) stop("Invalid base-year price index value.")
  100 * (p_vec / p0)
}

make_step_dummies <- function(df, years) {
  for (yy in years) df[[paste0("d", yy)]] <- as.integer(df$year >= yy)
  df
}

extract_lr_row <- function(lr_full, term) {
  if (is.null(lr_full) || !("Term" %in% names(lr_full))) 
    return(list(est = NA_real_, p = NA_real_))
  rr <- lr_full[lr_full$Term == term, , drop = FALSE]
  if (nrow(rr) == 0) return(list(est = NA_real_, p = NA_real_))
  p_col <- intersect(c("Pr(>|t|)", "Pr...t..", "p.value", "p_value"), names(rr))[1]
  list(
    est = suppressWarnings(as.numeric(rr$Estimate[1])),
    p   = if (!is.na(p_col)) suppressWarnings(as.numeric(rr[[p_col]][1])) else NA_real_
  )
}

get_lr_table_with_scaled_dummies <- function(fit_ardl, lnY_name = "lnY", 
                                             dummy_names = character()) {
  lr_mult <- ARDL::multipliers(fit_ardl, type = "lr")
  coefs <- coef(fit_ardl)
  phi_names <- grep(paste0("^L\\(", lnY_name, ","), names(coefs), value = TRUE)
  den <- 1 - sum(coefs[phi_names])
  
  dummy_table <- NULL
  if (length(dummy_names)) {
    gamma_sr <- coefs[dummy_names]
    dummy_lr <- gamma_sr / den
    vc <- vcov(fit_ardl)
    se_lr <- numeric(length(dummy_names))
    for (j in seq_along(dummy_names)) {
      dname   <- dummy_names[j]
      gamma_j <- coefs[dname]
      param_names <- c(dname, phi_names)
      idx  <- match(param_names, names(coefs))
      grad <- numeric(length(param_names))
      grad[1]  <- 1 / den
      grad[-1] <- gamma_j / den^2
      V_sub    <- vc[idx, idx, drop = FALSE]
      se_lr[j] <- sqrt(as.numeric(t(grad) %*% V_sub %*% grad))
    }
    t_lr <- as.numeric(dummy_lr) / se_lr
    p_lr <- 2 * pt(abs(t_lr), df = df.residual(fit_ardl), lower.tail = FALSE)
    dummy_table <- data.frame(
      Term         = dummy_names,
      Estimate     = as.numeric(dummy_lr),
      `Std. Error` = se_lr,
      `t value`    = t_lr,
      `Pr(>|t|)`   = p_lr,
      stringsAsFactors = FALSE
    )
    names(dummy_table) <- names(lr_mult)
  }
  
  lr_full_table <- if (!is.null(dummy_table)) rbind(lr_mult, dummy_table) else lr_mult
  list(lr_full_table = lr_full_table, den = den)
}

compute_u_from_lr <- function(df, lnY_name, lnK_name, lr_full, dummy_names) {
  a_lr_vec <- lr_full$Estimate[lr_full$Term == "(Intercept)"]
  a_lr     <- if (length(a_lr_vec) > 0 && is.finite(a_lr_vec[1])) a_lr_vec[1] else 0
  theta_lr <- lr_full$Estimate[lr_full$Term == lnK_name]
  dummy_coef   <- if (length(dummy_names)) 
    lr_full$Estimate[match(dummy_names, lr_full$Term)] else numeric(0)
  dummy_effect <- if (length(dummy_names)) 
    rowSums(df[dummy_names] * dummy_coef) else 0
  lnY  <- df[[lnY_name]]
  lnK  <- df[[lnK_name]]
  lnYp <- a_lr + theta_lr * lnK + dummy_effect
  u    <- exp(lnY - lnYp)
  list(u = u, lnYp = lnYp, intercept = a_lr, theta = theta_lr)
}



p_ledger <- df_raw |>
  transmute(year = as.integer(.data[[CONFIG$year_col]]),
            p_raw = as.numeric(.data[[CONFIG$p_index]])) |>
  filter(is.finite(year), is.finite(p_raw), p_raw > 0) |>
  arrange(year) |>
  mutate(p2011 = rebase_to_year_to_100(p_raw, year, 2011L)) |>
  select(year, p2011)

w <- CONFIG$WINDOWS_LOCKED[[WINDOW_TAG]]

df0 <- df_raw |>
  transmute(
    year     = as.integer(.data[[CONFIG$year_col]]),
    Y_nom    = as.numeric(.data[[CONFIG$y_nom]]),
    K_nom    = as.numeric(.data[[CONFIG$k_nom]]),
    u_shaikh = if ("u_shaikh" %in% names(df_raw)) 
      as.numeric(.data[["u_shaikh"]]) else NA_real_
  ) |>
  filter(is.finite(year), is.finite(Y_nom), is.finite(K_nom)) |>
  arrange(year) |>
  left_join(p_ledger, by = "year") |>
  filter(year >= w[1], year <= w[2])

df0 <- make_step_dummies(df0, DUMMY_YEARS)
dummy_names <- paste0("d", DUMMY_YEARS)

df <- df0 |>
  mutate(
    p_scale = p2011 / 100,
    Y_real  = Y_nom / p_scale,
    K_real  = K_nom / p_scale,
    lnY     = log(Y_real),
    lnK     = log(K_real)
  )




# Quick OLS of the long-run relation
ols_lr <- lm(lnY ~ lnK, data = df)
summary(ols_lr)

# Mean of the cointegrating residual
mean_resid <- mean(residuals(ols_lr))
cat("Mean cointegrating residual:", round(mean_resid, 6), "\n")
cat("exp(mean residual):", round(exp(mean_resid), 4), "\n")
# This should be ~1 if OLS centers it. It will be by construction.
# What matters is what u_shaikh's mean is:
cat("Mean u_shaikh:", round(mean(df$u_shaikh, na.rm = TRUE), 4), "\n")

# The raw output-capital ratio over time
df$ratio_logdiffYK <- df$lnY - df$lnK
plot(df$year, df$ratio_YK, type = "l", 
     main = "ln(Y/K) over time", ylab = "lnY - lnK")


df$ratio_YK <- exp(df$lnY - df$lnK)
plot(df$year, df$ratio_YK, type = "l", 
     main = "Y/K over time", ylab = "lnY - lnK")



# How fast is lnK growing vs lnY in your data?
cat("lnK start:", round(df$lnK[1], 4), 
    "| lnK end:", round(df$lnK[nrow(df)], 4),
    "| growth:", round(df$lnK[nrow(df)] - df$lnK[1], 4), "\n")

cat("lnY start:", round(df$lnY[1], 4), 
    "| lnY end:", round(df$lnY[nrow(df)], 4),
    "| growth:", round(df$lnY[nrow(df)] - df$lnY[1], 4), "\n")

cat("lnK - lnY growth gap:", 
    round((df$lnK[nrow(df)] - df$lnK[1]) - 
            (df$lnY[nrow(df)] - df$lnY[1]), 4), "\n")

# What are the actual levels?
cat("\nlnK mean:", round(mean(df$lnK), 4), "\n")
cat("lnY mean:", round(mean(df$lnY), 4), "\n")
cat("lnY - lnK mean:", round(mean(df$lnY - df$lnK), 4), "\n")

# What deflated K and Y look like in levels
cat("\nK_real first obs:", round(df$K_real[1], 2), "\n")
cat("K_real last obs: ", round(df$K_real[nrow(df)], 2), "\n")
cat("Y_real first obs:", round(df$Y_real[1], 2), "\n")
cat("Y_real last obs: ", round(df$Y_real[nrow(df)], 2), "\n")

# Shaikh target: what lnK mean would give theta = 0.661?
# Under OLS: theta = Cov(lnY, lnK) / Var(lnK)
# The issue is Var(lnK) relative to Cov(lnY, lnK)
cat("\nVar(lnK):", round(var(df$lnK), 6), "\n")
cat("Cov(lnY, lnK):", round(cov(df$lnY, df$lnK), 6), "\n")
cat("Implied theta:", round(cov(df$lnY, df$lnK) / var(df$lnK), 4), "\n")


# What Var(lnK) would be needed to recover theta = 0.661?
target_theta <- 0.6609
needed_var_lnK <- cov(df$lnY, df$lnK) / target_theta
cat("Needed Var(lnK) for theta=0.661:", round(needed_var_lnK, 6), "\n")
cat("Your actual Var(lnK):           ", round(var(df$lnK), 6), "\n")
cat("Ratio (needed/actual):          ", round(needed_var_lnK / var(df$lnK), 4), "\n")

# Implied: how much larger would lnK range need to be?
# If Var scales as (range)^2/12 approximately:
cat("Implied lnK range multiplier:   ", 
    round(sqrt(needed_var_lnK / var(df$lnK)), 4), "\n")

# What does K_real look like relative to what it should be?
# If Shaikh's K starts 28% lower in 1947:
K_shaikh_approx_start <- df$K_real[1] * 0.72  # 28% lower
cat("\nYour K_real 1947:          ", round(df$K_real[1], 2), "\n")
cat("Shaikh K approx 1947:      ", round(K_shaikh_approx_start, 2), "\n")
cat("Your lnK 1947:             ", round(df$lnK[1], 4), "\n")
cat("Shaikh lnK approx 1947:    ", round(log(K_shaikh_approx_start), 4), "\n")
cat("lnK level shift at entry:  ", 
    round(df$lnK[1] - log(K_shaikh_approx_start), 4), "\n")




# Rescale K to match Shaikh's approximate 1947 entry
# Apply the 0.72 factor to the entire K series
# This shifts lnK down by 0.3285 uniformly throughout

df$lnK_rescaled <- df$lnK - (df$lnK[1] - log(df$K_real[1] * 0.72))

cat("lnK_rescaled start:", round(df$lnK_rescaled[1], 4), "\n")
cat("lnK_rescaled end:  ", round(df$lnK_rescaled[nrow(df)], 4), "\n")
cat("Var(lnK_rescaled): ", round(var(df$lnK_rescaled), 6), "\n")
# Var is unchanged by a level shift — confirms variance gap is separate
# from the level gap

# OLS with rescaled K
ols_rescaled <- lm(lnY ~ lnK_rescaled, data = df)
cat("\ntheta with rescaled K:", 
    round(coef(ols_rescaled)["lnK_rescaled"], 4), "\n")
cat("intercept:            ", 
    round(coef(ols_rescaled)["(Intercept)"], 4), "\n")
# theta will be IDENTICAL — level shift doesn't change slope
# This confirms the variance gap, not the level gap, drives theta



scale_factor <- sqrt(needed_var_lnK / var(df$lnK))
cat("Scale factor:", round(scale_factor, 6), "\n")

df$lnK_stretched <- mean(df$lnK) + scale_factor * (df$lnK - mean(df$lnK))

cat("Var(lnK_stretched):", round(var(df$lnK_stretched), 6), "\n")
cat("Target Var(lnK):   ", round(needed_var_lnK, 6), "\n")

ols_stretched <- lm(lnY ~ lnK_stretched, data = df)
cat("theta with stretched K:", 
    round(coef(ols_stretched)["lnK_stretched"], 4), "\n")
cat("intercept:             ", 
    round(coef(ols_stretched)["(Intercept)"], 4), "\n")



# What scale factor actually needed?
actual_scale_needed <- 0.7698 / 0.6609
cat("Scale factor actually needed:", round(actual_scale_needed, 4), "\n")
cat("Var(lnK) ratio needed:       ", round(actual_scale_needed^2, 4), "\n")
cat("Var(lnK) needed:             ", 
    round(actual_scale_needed^2 * var(df$lnK), 6), "\n")

# Check: what does Cov(lnY, lnK) need to be?
# theta = Cov/Var = 0.661
# If Var is fixed at yours, Cov needs to be:
needed_cov <- 0.6609 * var(df$lnK)
cat("\nYour Cov(lnY, lnK):  ", round(cov(df$lnY, df$lnK), 6), "\n")
cat("Cov needed for 0.661:", round(needed_cov, 6), "\n")
cat("Cov gap:             ", round(cov(df$lnY, df$lnK) - needed_cov, 6), "\n")


library(readxl)
xl_path <- here::here("data/raw/_Appendix6.8DataTablesCorrected.xlsx")
sheets <- excel_sheets(xl_path)
sheets


for (s in sheets) {
  df_s <- tryCatch(read_excel(xl_path, sheet = s, n_max = 5), error = function(e) NULL)
  if (!is.null(df_s)) {
    cat("\n--- Sheet:", s, "---\n")
    print(names(df_s))
  }
}


df_I13 <- read_excel(xl_path, sheet = "Appndx6.8.I.1-3", skip = 5, col_names = FALSE)

# Rows are variables, columns are years — inspect the first 3 columns (labels)
df_I13[, 1:3]




# Find rows that mention "real", "price", "deflator", "constant", "chained"
label_col <- as.character(df_I13[[1]])
grep("real|price|deflat|constant|chain|pric|P|VA|value added", 
     label_col, ignore.case = TRUE, value = TRUE)



for (s in paste0("AppFig6.7.", 1:11)) {
  df_s <- tryCatch(
    read_excel(xl_path, sheet = s, col_names = FALSE, n_max = 10),
    error = function(e) NULL
  )
  if (!is.null(df_s)) {
    cat("\n--- Sheet:", s, "---\n")
    print(df_s[, 1:min(6, ncol(df_s))])
  } else {
    cat("\n--- Sheet:", s, "FAILED ---\n")
  }
}
#We are looking for a sheet that contains a column with log or real output that shows values around 6.5 in 1947 — because working backwards from Shaikh's intercept (2.178) and theta (0.661) with lnK_1947=6.60:
#lnYp_1947 = 2.178 + 0.661 × 6.60 = 6.54


df_II1 <- read_excel(xl_path, sheet = "Appndx 6.8.II.1", col_names = TRUE)

# First three columns are metadata — show all variable names
df_II1[, 1:3]


df_raw |>
  filter(year %in% c(1947, 1956, 1957, 1974, 1975, 1980, 1981, 2007, 2011)) |>
  mutate(
    GVAcorp  = VAcorp + DEPCcorp,
    Y_real   = GVAcorp / (pIGcorpbea / 100),
    lnY_GVA  = log(Y_real)
  ) |>
  select(year, VAcorp, DEPCcorp, GVAcorp, lnY_GVA)
