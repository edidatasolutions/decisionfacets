library(decisionfacets)
ns <- asNamespace("decisionfacets")

# 1. Model primitives are proper distributions -----------------------------
P <- ns$mfrm_probs(c(-3, 0, 2.5), c(-1, 0, 1))
stopifnot(all(abs(rowSums(P) - 1) < 1e-12))

sim <- df_simulate(n_persons = 50, n_items = 3, n_raters = 6, seed = 1)
cells <- ns$panel_cells(names(sim$par$delta), c("R01", "R02"))
D <- ns$score_dist(c(-1, 0, 1), cells, sim$par)
stopifnot(all(abs(rowSums(D) - 1) < 1e-12), ncol(D) == 3 * 2 * 4 + 1)

# 2. Exact pass probability matches brute-force Monte Carlo ------------------
set.seed(2)
th <- 0.3; raw_cut <- 13; n_rep <- 20000
eta <- th - sim$par$delta[cells$item] - sim$par$lambda[cells$rater]
Pc <- ns$mfrm_probs(eta, sim$par$tau)
totals <- replicate(n_rep, sum(apply(Pc, 1, function(p) sample.int(5, 1, prob = p) - 1)))
p_mc <- mean(totals >= raw_cut)
p_exact <- ns$pass_prob(th, cells, sim$par, raw_cut)
stopifnot(abs(p_mc - p_exact) < 4 * sqrt(p_exact * (1 - p_exact) / n_rep))

# 3. Decision rules: severity adjustment moves the raw cut the right way -----
harsh <- names(sort(sim$par$lambda, decreasing = TRUE))[1:2]
lenient <- names(sort(sim$par$lambda))[1:2]
items <- names(sim$par$delta)
meas <- ns$resolve_cut(df_cut(0, "measure"), sim$par)
rc_harsh <- ns$raw_cut_for_panel(meas, ns$panel_cells(items, harsh), sim$par)
rc_len <- ns$raw_cut_for_panel(meas, ns$panel_cells(items, lenient), sim$par)
stopifnot(rc_harsh < rc_len)
raw <- ns$resolve_cut(df_cut(12, "raw_total"), sim$par)
stopifnot(ns$raw_cut_for_panel(raw, ns$panel_cells(items, harsh), sim$par) == 12)
# fair average cut maps back to the same logit
fa <- ns$resolve_cut(df_cut(2, "fair_average"), sim$par)
fa_at <- mean(vapply(sim$par$delta, function(dl)
  sum(ns$mfrm_probs(fa$theta - dl, sim$par$tau) * 0:4), 0))
stopifnot(abs(fa_at - 2) < 1e-6)

# 4. Known-truth recovery: estimated counterfactuals track the true ones -----
sim <- df_simulate(n_persons = 600, n_items = 4, n_raters = 10,
                   raters_per_person = 2, severity_sd = 0.6, seed = 42)
engines <- c("jmle", if (requireNamespace("TAM", quietly = TRUE)) "tam")
cut <- df_cut(16, "raw_total")
truth <- df_counterfactual(sim, cut)
# Oracle: true parameters, but theta integrated over its posterior like an estimate.
oracle <- df_counterfactual(sim, cut, theta = "posterior")
for (eng in engines) {
  fit <- df_fit(sim$data, engine = eng)
  stopifnot(fit$converged,
            abs(mean(fit$par$delta)) < 1e-8, abs(mean(fit$par$lambda)) < 1e-8,
            cor(fit$par$lambda, sim$par$lambda[names(fit$par$lambda)]) > 0.95,
            cor(fit$par$delta, sim$par$delta[names(fit$par$delta)]) > 0.95,
            # JMLE stretches the logit scale when persons have few ratings
            # (~16% here), so for it only check threshold order.
            if (eng == "tam") max(abs(fit$par$tau - sim$par$tau)) < 0.15
            else !is.unsorted(fit$par$tau),
            cor(fit$par$theta[names(sim$par$theta)], sim$par$theta) > 0.8)
  est <- df_counterfactual(fit, cut)
  stopifnot(identical(truth$person, est$person),
            identical(truth$pass_observed, est$pass_observed),
            cor(truth$p_observed, est$p_observed) > 0.9,
            cor(truth$delta, est$delta) > 0.9,
            cor(oracle$advantage, est$advantage) > 0.95)
}

# Flag: advantage is delta signed toward the observed outcome.
stopifnot(all.equal(truth$advantage, ifelse(truth$pass_observed, truth$delta, -truth$delta)),
          all(truth$rater_dependent == (truth$advantage >= 0.2)),
          all(truth$direction[truth$rater_dependent & truth$pass_observed] == "lenient_panel_pass"),
          all(truth$direction[truth$rater_dependent & !truth$pass_observed] == "harsh_panel_fail"))

# Under the measure rule severity is modeled out, so on average the random
# panel is close to the observed one; under raw totals it is not.
theta_cut <- ns$resolve_cut(df_cut(16 / 8, "fair_average"), sim$par)$theta
truth_m <- df_counterfactual(sim, df_cut(theta_cut, "measure"))
stopifnot(mean(abs(truth_m$delta)) < mean(abs(truth$delta)))

# 5. Attribution ----------------------------------------------------------
att <- df_attribute(truth)
true_pass <- unname(sim$par$theta[att$person] >= attr(att, "theta_standard"))
stopifnot(
  all.equal(att$err_observed, att$false_pass + att$false_fail),
  all.equal(att$err_observed, ifelse(true_pass, 1 - truth$p_observed, truth$p_observed)),
  all.equal(att$err_average, ifelse(true_pass, 1 - truth$p_average, truth$p_average)),
  all.equal(att$assignment, att$err_observed - att$err_average),
  all(att$realized_error == (att$pass_observed != true_pass))
)
# Expected misclassifications match realized ones (known truth).
e <- att$err_observed
stopifnot(abs(sum(att$realized_error) - sum(e)) < 4 * sqrt(sum(e * (1 - e))))
# Severity adjustment removes most of the assignment harm.
att_m <- df_attribute(truth_m)
stopifnot(sum(pmax(att_m$assignment, 0)) < 0.5 * sum(pmax(att$assignment, 0)))
# Estimated decomposition tracks the true one.
att_est <- df_attribute(df_counterfactual(df_fit(sim$data), cut))
s_true <- summary(att); s_est <- summary(att_est)
tr3 <- s_true$expected_count[1:3]; es3 <- s_est$expected_count[1:3]
stopifnot(all(abs(es3 - tr3) < pmax(0.25 * abs(tr3), 5)))
stopifnot(inherits(try(df_attribute(truth, "halo"), silent = TRUE), "try-error"))

cat("All core tests passed.\n")
