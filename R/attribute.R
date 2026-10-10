#' Attribute misclassification to measurement error vs. rater assignment
#'
#' A decision is a misclassification when it disagrees with the candidate's
#' standing against the intended standard, `theta >= theta_standard`: the
#' measure-scale cut for measure-based rules, or for raw rules the ability at
#' which an average-severity panel's expected total equals the raw cut. For
#' each candidate the probability of misclassification is computed under three
#' panels, and the expected number of wrong decisions is split into:
#' \describe{
#'   \item{measurement}{Error expected with an average-severity panel. It comes
#'     from having a finite number of ratings and no rater can remove it.}
#'   \item{assignment}{Observed-panel error minus average-panel error: what the
#'     raters actually assigned added (or, if negative, removed). Reported net
#'     and as gross harm and gross benefit, because lenient raters can rescue
#'     a truly passing borderline candidate while wrongly passing another.}
#'   \item{design}{Random-panel error minus average-panel error: what the
#'     random assignment design costs in expectation, before anyone is scored.
#'     `df_design()` will try to reduce this.}
#' }
#' @details With estimated parameters, error probabilities integrate over each
#'   candidate's ability posterior. Net components are well recovered in
#'   simulation, but the gross harm/benefit split and the false-pass /
#'   false-fail split are attenuated by posterior shrinkage; report them from
#'   estimates with that caveat.
#' @param counterfactual A `df_counterfactual`.
#' @param components Rater effects to separate. Only `"severity"` is estimable
#'   from the current model (no halo or drift terms yet).
#' @return A `df_attribution` data frame, one row per candidate: `person`,
#'   `panel`, `pass_observed`, `p_true_pass` (probability the candidate truly
#'   meets the standard), `err_observed`, `err_average`, `err_random`,
#'   `assignment` (= err_observed - err_average), `false_pass` and
#'   `false_fail` (the two parts of err_observed), and `realized_error` when the
#'   counterfactual was computed from known truth. `summary()` gives the
#'   aggregate decomposition.
#' @examples
#' sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
#' cf <- df_counterfactual(sim, df_cut(12, "raw_total"))
#' df_attribute(cf)
#' @export
df_attribute <- function(counterfactual, components = "severity") {
  if (!inherits(counterfactual, "df_counterfactual"))
    stop("`counterfactual` must come from df_counterfactual().")
  unsupported <- setdiff(components, "severity")
  if (length(unsupported))
    stop("Not estimable from the current model: ", paste(unsupported, collapse = ", "),
         ". Only 'severity' is supported until halo/drift terms are modeled.")
  it <- attr(counterfactual, "internals")
  if (is.null(it) || is.null(it$groups))
    stop("Recompute the counterfactual with this version of decisionfacets.")

  n <- nrow(counterfactual)
  person_vals <- function(C, idx) {
    C <- as.matrix(C)
    if (is.null(it$W)) C[idx, , drop = FALSE] else it$W[idx, , drop = FALSE] %*% C
  }
  p_true <- err_obs <- err_avg <- err_rand <- f_pass <- f_fail <- below_pt <- numeric(n)
  theta_std <- numeric(n)
  for (g in it$groups) {
    m <- g$members
    below <- it$pts < g$theta_standard
    wrong <- function(C) C * below + (1 - C) * !below   # rows of C are pts
    pick_obs <- function(C) person_vals(C, m)[cbind(seq_along(m), it$obs_index[m])]
    p_true[m] <- drop(person_vals(as.numeric(!below), m))
    err_obs[m] <- pick_obs(wrong(it$C_obs))
    err_avg[m] <- drop(person_vals(wrong(g$c_avg), m))
    err_rand[m] <- rowMeans(person_vals(wrong(g$C), m))
    f_pass[m] <- pick_obs(it$C_obs * below)
    f_fail[m] <- pick_obs((1 - it$C_obs) * !below)
    theta_std[m] <- g$theta_standard
    if (it$known_truth) below_pt[m] <- below[m]
  }
  out <- data.frame(
    person = counterfactual$person,
    panel = counterfactual$panel,
    pass_observed = counterfactual$pass_observed,
    p_true_pass = p_true,
    err_observed = err_obs,
    err_average = err_avg,
    err_random = err_rand,
    stringsAsFactors = FALSE
  )
  out$assignment <- out$err_observed - out$err_average
  out$false_pass <- f_pass
  out$false_fail <- f_fail
  if (it$known_truth) out$realized_error <- out$pass_observed == as.logical(below_pt)
  ts <- unique(theta_std)
  structure(out, class = c("df_attribution", "data.frame"),
            cut = attr(counterfactual, "cut"),
            theta_standard = if (length(ts) == 1) ts else theta_std,
            known_truth = it$known_truth)
}

#' @export
summary.df_attribution <- function(object, ...) {
  a <- object$assignment
  rows <- data.frame(
    component = c("expected misclassifications (observed panels)",
                  "  measurement error (average panel)",
                  "  rater assignment, net (observed - average)",
                  "    gross harm (panels that added error)",
                  "    gross benefit (panels that removed error)",
                  "  of which false passes", "  of which false fails",
                  "random-assignment design cost (random - average)"),
    expected_count = c(sum(object$err_observed), sum(object$err_average), sum(a),
                       sum(pmax(a, 0)), sum(pmin(a, 0)),
                       sum(object$false_pass), sum(object$false_fail),
                       sum(object$err_random - object$err_average)),
    stringsAsFactors = FALSE
  )
  if (isTRUE(attr(object, "known_truth")))
    rows <- rbind(rows, data.frame(component = "realized misclassifications (known truth)",
                                   expected_count = sum(object$realized_error)))
  rows$per_1000 <- 1000 * rows$expected_count / nrow(object)
  rows
}

#' @export
print.df_attribution <- function(x, ...) {
  cut <- attr(x, "cut")
  ts <- attr(x, "theta_standard")
  cat("<df_attribution> rule =", cut$decision_rule, "| cut =", cut$value,
      "| standard at theta =",
      if (length(ts) == 1) round(ts, 3) else "varies by item set",
      "| n =", nrow(x), "\n\n")
  s <- summary(x)
  s$expected_count <- round(s$expected_count, 1)
  s$per_1000 <- round(s$per_1000, 1)
  print(s, row.names = FALSE, right = FALSE)
  invisible(x)
}
