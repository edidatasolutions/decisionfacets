# Known-truth validation of df_counterfactual().
# Simulates an administration and computes counterfactuals four ways:
#   truth   - true parameters, true theta (what actually happened to each candidate)
#   oracle  - true parameters, theta integrated over its posterior
#             (the best any estimate can do from 8 ratings per candidate)
#   tam     - TAM marginal-ML estimates
#   jmle    - built-in JMLE estimates
# and compares flags under each decision rule.
library(decisionfacets)

sim <- df_simulate(n_persons = 1000, n_items = 4, n_raters = 12,
                   raters_per_person = 2, n_cat = 5, severity_sd = 0.6, seed = 2026)
fits <- list(tam = df_fit(sim$data, engine = "tam"),
             jmle = df_fit(sim$data, engine = "jmle"))
for (e in names(fits))
  cat(sprintf("%-4s converged: %s in %d iterations; severity recovery r = %.3f\n", e,
              fits[[e]]$converged, fits[[e]]$iterations,
              cor(fits[[e]]$par$lambda, sim$par$lambda[names(fits[[e]]$par$lambda)])))
cat("\n")

# Same substantive standard expressed three ways: a mean rating of 2 per cell.
theta_cut <- asNamespace("decisionfacets")$resolve_cut(df_cut(2, "fair_average"), sim$par)$theta
cuts <- list(raw_total = df_cut(2 * 4 * 2, "raw_total"),
             fair_average = df_cut(2, "fair_average"),
             measure = df_cut(theta_cut, "measure"))

agree <- function(ref, x) {
  c(flags = sum(x$rater_dependent),
    sens = if (any(ref$rater_dependent)) mean(x$rater_dependent[ref$rater_dependent]) else NA,
    ppv = if (any(x$rater_dependent)) mean(ref$rater_dependent[x$rater_dependent]) else NA,
    r_adv = cor(ref$advantage, x$advantage))
}
rows <- list()
for (rule in names(cuts)) {
  cf <- list(truth = df_counterfactual(sim, cuts[[rule]]),
             oracle = df_counterfactual(sim, cuts[[rule]], theta = "posterior"),
             tam = df_counterfactual(fits$tam, cuts[[rule]]),
             jmle = df_counterfactual(fits$jmle, cuts[[rule]]))
  for (m in names(cf)) {
    a_truth <- agree(cf$truth, cf[[m]])
    a_oracle <- agree(cf$oracle, cf[[m]])
    rows[[length(rows) + 1]] <- data.frame(
      rule = rule, method = m, flags = a_truth[["flags"]],
      lenient_pass = sum(cf[[m]]$direction %in% "lenient_panel_pass"),
      harsh_fail = sum(cf[[m]]$direction %in% "harsh_panel_fail"),
      sens_vs_truth = round(a_truth[["sens"]], 2), ppv_vs_truth = round(a_truth[["ppv"]], 2),
      r_adv_vs_truth = round(a_truth[["r_adv"]], 3),
      r_adv_vs_oracle = round(a_oracle[["r_adv"]], 3))
  }
}
print(do.call(rbind, rows), row.names = FALSE)

cat("\nMost rater-dependent candidates under raw totals (TAM):\n")
print(df_counterfactual(fits$tam, cuts$raw_total), n = 8)

# Misclassification attribution: truth vs TAM, raw totals vs measures.
cat("\n")
for (rule in c("raw_total", "measure")) {
  s_t <- summary(df_attribute(df_counterfactual(sim, cuts[[rule]])))
  s_e <- summary(df_attribute(df_counterfactual(fits$tam, cuts[[rule]])))
  cat("Attribution,", rule, "\n")
  print(data.frame(component = s_t$component,
                   truth = round(s_t$expected_count, 1),
                   tam = c(round(s_e$expected_count, 1), NA)[seq_len(nrow(s_t))]),
        row.names = FALSE, right = FALSE)
  cat("\n")
}
