library(ARDL)
library(dynlm)
library(dplyr)
library(here)
library(knitr)
library(kableExtra)
source("codes/10_config.R")
source("codes/99_utils.R")

# ── output path  ───────────────────────────────────────────────────────────
out_dir <- here::here("output", "CriticalReplication", "S0_manualOverride","ardl_nodummy")


# ── Data ──────────────────────────────────────────────────────────────
df <- readr::read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types = FALSE)

build_data <- function(df) {
  df |>
    filter(year >= 1947, year <= 2011) |>
    mutate(
      lnY   = log(VAcorp / (Py / 100)),
      lnK   = log(KGCcorp / (Py / 100)),
      trend = row_number()
    )
}

df  <- build_data(df)
df_ts <- ts(df |> select(lnY, lnK,trend),
            start = 1947, frequency = 1)


#Lag Selection Order 
ardl_S0v1_bic <- auto_ardl(lnY ~ lnK, data = df_ts, max_order = c(5,5), selection = "BIC")
ardl_S0v1_aic <- auto_ardl(lnY ~ lnK, data = df_ts, max_order = c(5,5), selection = "AIC")
AIC <- ardl_S0v1_aic$top_orders
BIC <- ardl_S0v1_bic$top_orders

#Merge of CU measures and shaikh data 
AIC_BIC_top5 <- AIC |> dplyr::left_join(BIC, by = c("lnY","lnK"))
AIC_BIC_top5 <- round(AIC_BIC_top5[1:5,],2)
print(AIC_BIC_top5)
readr::write_csv(AIC_BIC_top5, file.path(out_dir, "AIC_BIC_top5_nodummy.csv"))

#Run ARDL
ardl_s0v1 <- ardl(lnY ~ lnK, data = df_ts, order = c(1,3))
summary(ardl_s0v1)


# Including the constant term in the long-run relationship (restricted constant)
ardl_s0v1_bft2 <- bounds_f_test(ardl_s0v1, case = 2,  exact = TRUE, pvalue = TRUE)

# Including the constant term in the short-run relationship (unrestricted constant)
ardl_s0v1_bft3 <-bounds_f_test(ardl_s0v1, case = 3, exact = TRUE,  pvalue = TRUE)


#Objects to build a boudn testing table recursively 
bound_testing_table <- round(rbind(ardl_s0v1_bft2$tab,ardl_s0v1_bft3$tab),3)

####### Checking for trend cases ######## 

#Check lag order for trend inclusion 
ardl_S0v1_bic <- auto_ardl(lnY ~ lnK + trend(lnY), data = df_ts, max_order = c(5,5), selection = "BIC")
ardl_S0v1_aic <- auto_ardl(lnY ~ lnK + trend(lnY), data = df_ts, max_order = c(5,5), selection = "AIC")
AIC <- ardl_S0v1_aic$top_orders
BIC <- ardl_S0v1_bic$top_orders
AIC_BIC_top5 <- AIC |> dplyr::left_join(BIC, by = c("lnY","lnK"))
AIC_BIC_top5 <- round(AIC_BIC_top5[1:5,],2)
print(AIC_BIC_top5)
readr::write_csv(AIC_BIC_top5, file.path(out_dir, "AIC_BIC_top5_trend_nodummy.csv"))

#Trend holds AIC (p,1) = (1,3)
ardl_s0v1t <- ardl(lnY ~ lnK + trend(lnY), data = df_ts, order = c(1,3))
summary(ardl_s0v1t)

# Including the constant term in the short-run relationship (unrestricted constant)
ardl_s0v1_bft4 <-bounds_f_test(ardl_s0v1t, case = 4, exact = TRUE,  pvalue = TRUE)

# For the model with constant and trend (unrestricted constant and unrestricted trend)
ardl_s0v1_bft5 <-bounds_f_test(ardl_s0v1t, case = 5, exact = TRUE,  pvalue = TRUE)


#Objects to build a boudn testing table recursively 
bound_testing_table <- round(rbind(bound_testing_table,ardl_s0v1_bft4$tab),3)
bound_testing_table <- round(rbind(bound_testing_table,ardl_s0v1_bft5$tab),3)


#Case 1 check 
ardl_S0v1_bic <- auto_ardl(lnY ~ lnK -1, data = df_ts, max_order = c(5,5), selection = "BIC")
ardl_S0v1_aic <- auto_ardl(lnY ~ lnK -1, data = df_ts, max_order = c(5,5), selection = "AIC")
AIC <- ardl_S0v1_aic$top_orders
BIC <- ardl_S0v1_bic$top_orders
AIC_BIC_top5 <- AIC |> dplyr::left_join(BIC, by = c("lnY","lnK"))
AIC_BIC_top5 <- round(AIC_BIC_top5[1:5,],2)
print(AIC_BIC_top5)
readr::write_csv(AIC_BIC_top5, file.path(out_dir, "AIC_BIC_top5_noconst_nodummy.csv"))


#NOTE ON LAG SELECTION: WE KEEP IN 1,3 to hold consistency, it remains in top 5 within top orders in BIC and AIC 
ardl_s0v1nc <- ardl(lnY ~ lnK -1, data = df_ts, order = c(1,3))
summary(ardl_s0v1nc)

# Including the constant term in the short-run relationship (unrestricted constant)
ardl_s0v1_bft1 <-bounds_f_test(ardl_s0v1nc, case = 1, exact = TRUE,  pvalue = TRUE)
bound_testing_table <- round(rbind(ardl_s0v1_bft1$tab,bound_testing_table),3)

rownames(bound_testing_table) <- c("Case 1","Case 2","Case 3","Case 4","Case 5")
colnames(bound_testing_table) <- c("F-stat","p-value")

#Bound testing table (p,q) = (1,3)
print(bound_testing_table)


#T bounds testing 
ardl_s0v1_btt1 <-bounds_t_test(ardl_s0v1nc, case = 1, exact = TRUE,  pvalue = TRUE)
ardl_s0v1_btt3 <-bounds_t_test(ardl_s0v1, case = 3, exact = TRUE,  pvalue = TRUE)
ardl_s0v1_btt5 <-bounds_t_test(ardl_s0v1t, case = 5, exact = TRUE,  pvalue = TRUE)


tbounds_testing_table <- data.frame(
  `t-stat`  = c(ardl_s0v1_btt1$tab$statistic, NA, ardl_s0v1_btt3$tab$statistic, NA, ardl_s0v1_btt5$tab$statistic),
  `p-value`  = c(ardl_s0v1_btt1$tab$p.value,  NA, ardl_s0v1_btt3$tab$p.value,  NA, ardl_s0v1_btt5$tab$p.value),
  check.names = FALSE
)
rownames(tbounds_testing_table) <- paste("Case", 1:5)
tbounds_testing_table <- round(tbounds_testing_table, 3)


#PSS2001 CI Bounds testing FAILURE OF ROBOUST CI 
PSS2001_CI_bounds_test <-cbind(bound_testing_table,tbounds_testing_table)
print(PSS2001_CI_bounds_test)
readr::write_csv(PSS2001_CI_bounds_test, file.path(out_dir, "PSS2001_CI_bounds_test_ardlnodummy.csv"))


#local: AIC BIC Contest 

# ── Read and tag ──────────────────────────────────────────────────────

ardl_nodummy <- here::here("output", "CriticalReplication", 
                           "S0_manualOverride", "ardl_nodummy")

aic_bic_table <- purrr::map_dfr(
  list(
    list(file = "AIC_BIC_top5_noconst_nodummy.csv", model_class = "no_const",    cases = "Case 1"),
    list(file = "AIC_BIC_top5_nodummy.csv",          model_class = "const",       cases = "Cases 2–3"),
    list(file = "AIC_BIC_top5_trend_nodummy.csv",   model_class = "const_trend", cases = "Cases 4–5")
  ),
  function(entry) {
    readr::read_csv(file.path(ardl_nodummy, entry$file), show_col_types = FALSE) |>
      dplyr::mutate(model_class = entry$model_class,
                    cases       = entry$cases)
  }
) |>
  dplyr::select(model_class, cases, lnY, lnK, AIC, BIC) |>
  dplyr::mutate(across(c(AIC, BIC), \(x) round(x, 3)))

# ── Export ────────────────────────────────────────────────────────────

readr::write_csv(aic_bic_table, 
                 file.path(ardl_nodummy, "AIC_BIC_consolidated_nodummy.csv"))


# ── Read consolidated table ───────────────────────────────────────────
aic_bic_table <- readr::read_csv(
  file.path(ardl_nodummy, "AIC_BIC_consolidated_nodummy.csv"),
  show_col_types = FALSE
)

# ── Build LaTeX table ─────────────────────────────────────────────────

aic_bic_tex <- aic_bic_table |>
  dplyr::mutate(
    model_class = dplyr::case_when(
      model_class == "no_const"    ~ "No constant",
      model_class == "const"       ~ "Constant",
      model_class == "const_trend" ~ "Constant + trend"
    ),
    AIC = round(AIC, 2),
    BIC = round(BIC, 2)
  ) |>
  dplyr::rename(
    `Model class`  = model_class,
    `PSS cases`    = cases,
    `$p$`          = lnY,
    `$q$`          = lnK
  ) |>
  knitr::kable(
    format    = "latex",
    booktabs  = TRUE,
    linesep   = "",
    caption   = "Top-5 ARDL lag orders by model class.",
    label     = "tab:aic_bic_noD",
    align     = c("l", "l", "c", "c", "r", "r"),
    na        = "---"
  ) |>
  kableExtra::kable_styling(latex_options = c("hold_position")) |>
  kableExtra::pack_rows("No constant (Case 1)",       1,  5) |>
  kableExtra::pack_rows("Constant (Cases 2–3)",       6, 10) |>
  kableExtra::pack_rows("Constant + trend (Cases 4–5)", 11, 15) |>
  kableExtra::column_spec(1, bold = FALSE) |>
  kableExtra::footnote(
    general = "BIC penalises lag length more heavily than AIC. NA entries arise when BIC is undefined for the given sample--lag combination.",
    general_title = "Note:",
    footnote_as_chunk = TRUE,
    escape = FALSE
  )

# ── Export .tex ───────────────────────────────────────────────────────
writeLines(
  aic_bic_tex,
  file.path(ardl_nodummy, "AIC_BIC_consolidated_nodummy.tex")
)

# ── LaTeX export — PSS2001 bounds test table ──────────────────────────

PSS2001_CI_bounds_test |>
  as.data.frame() |>
  setNames(c("F.stat", "p.value.F", "t.stat", "p.value.t")) |>  # deduplicate first
  tibble::rownames_to_column("Case") |>
  knitr::kable(
    format   = "latex",
    booktabs = TRUE,
    linesep  = "",
    digits   = 3,
    col.names = c("Case", "$F$-stat", "$p$-value", "$t$-stat", "$p$-value"),  # display names here
    caption  = "PSS (2001) bounds test for cointegration, Cases I--V. ARDL(1,3). Exact $p$-values conditioned on $T=65$.",
    label    = "tab:pss2001_bounds_noD",
    align    = c("l", "r", "r", "r", "r"),
    na       = "---",
    escape   = FALSE
  ) |>
  kableExtra::kable_styling(latex_options = "hold_position") |>
  kableExtra::add_header_above(
    c(" " = 1, "F-bounds test" = 2, "t-bounds test" = 2)
  ) |>
  kableExtra::footnote(
    general = "t-bounds test is structurally undefined for Cases II and IV (PSS 2001). $p$-values computed via simulation with $R = 40{,}000$ bootstrap draws.",
    general_title = "Note:",
    footnote_as_chunk = TRUE,
    escape = FALSE
  ) |>
  writeLines(file.path(ardl_nodummy, "PSS2001_CI_bounds_test_nodummy.tex"))

