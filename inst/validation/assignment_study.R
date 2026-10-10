# Known-truth validation for one-examiner-per-case designs with continuous
# (0-100) scores. Factors: cases per candidate (6, 12) x examiner severity SD
# (2, 4, 6 score points) x qualified examiners per case (4, 10). Fixed: 400
# candidates, ability SD 7, case SD 4, residual SD 8, pass mark = mean score 70,
# examiner pool = 4 x cases. Progress goes to assignment_progress.log.
# Usage: Rscript inst/validation/assignment_study.R [n_reps] [n_workers]
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) >= 1) as.integer(args[1]) else 50
n_workers <- if (length(args) >= 2) as.integer(args[2]) else max(1, parallel::detectCores() - 2)
out_dir <- if (dir.exists("inst/validation")) "inst/validation" else "."
log_file <- normalizePath(file.path(out_dir, "assignment_progress.log"), mustWork = FALSE)
cat("", file = log_file)

design <- expand.grid(cases = c(6, 12), severity_sd = c(2, 4, 6), per_case = c(4, 10))
design$cell <- seq_len(nrow(design))
jobs <- merge(design, data.frame(rep = seq_len(n_reps)))
jobs$seed <- 310000 + jobs$cell * 1000 + jobs$rep

one_job <- function(j, log_file) {
  suppressPackageStartupMessages(library(decisionfacets))
  t0 <- Sys.time()
  sim <- df_simulate(n_persons = 400, n_items = j$cases, n_raters = 4 * j$cases,
                     design = "per_item", raters_per_item = j$per_case, scale = "continuous",
                     continuous = list(center = 72, theta_sd = 7, item_sd = 4,
                                       severity_sd = j$severity_sd, sigma = 8),
                     seed = j$seed)
  fit <- df_fit(sim$data)
  cut <- df_cut(70, "raw_mean")
  tr <- df_counterfactual(sim, cut, max_panels = 500, seed = j$seed)
  es <- df_counterfactual(fit, cut, max_panels = 500, seed = j$seed)
  a_t <- summary(df_attribute(tr))$expected_count
  a_e <- summary(df_attribute(es))$expected_count
  m_t <- summary(df_attribute(df_counterfactual(sim, df_cut(70, "measure"), max_panels = 200,
                                                 seed = j$seed)))$expected_count
  lam <- sim$par$lambda[names(fit$par$lambda)]
  dep <- tr$rater_dependent
  out <- data.frame(j[c("cell", "cases", "severity_sd", "per_case", "rep", "seed")],
    converged = fit$converged,
    r_severity = stats::cor(fit$par$lambda, lam),
    severity_rmse = sqrt(mean((fit$par$lambda - lam)^2)),
    sigma_hat = fit$par$sigma,
    dep_truth = sum(dep), dep_est = sum(es$rater_dependent),
    sens = if (any(dep)) mean(es$rater_dependent[dep]) else NA,
    ppv = if (any(es$rater_dependent)) mean(dep[es$rater_dependent]) else NA,
    r_advantage = stats::cor(tr$advantage, es$advantage),
    expected = a_t[1], measurement = a_t[2], assign = a_t[3], realized = a_t[9],
    assign_est = a_e[3], expected_est = a_e[1],
    measure_assign = m_t[3], measure_expected = m_t[1])
  cat(sprintf("%s cell %d rep %d done in %.0fs\n", format(Sys.time(), "%H:%M:%S"), j$cell, j$rep,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))), file = log_file, append = TRUE)
  out
}

t0 <- Sys.time()
cl <- parallel::makeCluster(n_workers)
invisible(parallel::clusterCall(cl, function(p) .libPaths(c(p, .libPaths())), .libPaths()[1]))
res <- do.call(rbind, parallel::parLapplyLB(cl, split(jobs, seq_len(nrow(jobs))), one_job, log_file = log_file))
parallel::stopCluster(cl)
saveRDS(res, file.path(out_dir, "assignment_results.rds"))

keys <- c("cases", "severity_sd", "per_case")
res$share_assign <- res$assign / res$expected
f <- function(v, d = 1) sprintf(paste0("%.", d, "f"), v)
agg <- stats::aggregate(res[c("r_severity", "severity_rmse", "sigma_hat", "dep_truth", "dep_est", "sens",
                              "ppv", "r_advantage", "expected", "measurement", "assign", "share_assign",
                              "realized", "assign_est", "measure_assign")],
                        res[keys], mean, na.rm = TRUE)
cat(sprintf("Conditions: %d | replications per condition: %d | %.1f minutes | converged: %.3f\n\n",
            nrow(design), n_reps, as.numeric(difftime(Sys.time(), t0, units = "mins")), mean(res$converged)))
cat("Per-condition means (400 candidates; counts per 400; pass mark mean 70)\n")
print(format(agg, digits = 3), row.names = FALSE)
cat("\nPooled: expected - realized misclassifications per data set:",
    f(mean(res$expected - res$realized), 2), "(SD", f(stats::sd(res$expected - res$realized), 2), ")",
    "| estimated - true assignment component:", f(mean(res$assign_est - res$assign), 2),
    "| max |measure-rule assignment|:", f(max(abs(res$measure_assign)), 3), "\n")
eta2 <- function(v) {
  d <- res[!is.na(res[[v]]), ]; d[keys] <- lapply(d[keys], factor)
  a <- stats::anova(stats::lm(stats::as.formula(paste(v, "~ (cases + severity_sd + per_case)^2")), d))
  stats::setNames(round(a[["Sum Sq"]] / sum(a[["Sum Sq"]]), 3), rownames(a))
}
cat("\nEta-squared\n")
print(do.call(rbind, lapply(c(dep_truth = "dep_truth", share_assign = "share_assign",
                             sens = "sens", r_severity = "r_severity"), eta2)))
