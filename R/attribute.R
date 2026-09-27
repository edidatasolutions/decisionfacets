#' Attribute misclassification to measurement error vs. rater assignment
#'
#' A decision is a misclassification when it disagrees with the candidate's
#' standing against the intended standard, `theta >= theta_standard`: the
#' measure-scale cut for measure-based rules, or for `raw_total` the ability at
#' which an average panel's expected total equals the raw cut. For each
#' candidate the probability of misclassification is computed under three
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
  if (is.null(it)) stop("Recompute the counterfactual with this version of decisionfacets.")

  below <- it$pts < it$theta_standard
  wrong <- function(C) C * below + (1 - C) * !below   # rows of C are pts
  to_person <- if (is.null(it$W)) function(C) C else function(C) it$W %*% C
  n <- nrow(counterfactual)
  pick_obs <- function(C) to_person(C)[cbind(seq_len(n), it$obs_index)]

  out <- data.frame(
    person = counterfactual$person,
    panel = counterfactual$panel,
    pass_observed = counterfactual$pass_observed,
    p_true_pass = drop(to_person(matrix(as.numeric(!below)))),
    err_observed = pick_obs(wrong(it$C_obs)),
    err_average = drop(to_person(matrix(wrong(it$c_avg)))),
    err_random = rowMeans(to_person(wrong(it$C))),
    stringsAsFactors = FALSE
  )
  out$assignment <- out$err_observed - out$err_average
  out$false_pass <- pick_obs(it$C_obs * below)
  out$false_fail <- pick_obs((1 - it$C_obs) * !below)
  if (it$known_truth) out$realized_error <- out$pass_observed == below
  structure(out, class = c("df_attribution", "data.frame"),
            cut = attr(counterfactual, "cut"), theta_standard = it$theta_standard,
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
  cat("<df_attribution> rule =", cut$decision_rule, "| cut =", cut$value,
      "| standard at theta =", round(attr(x, "theta_standard"), 3),
      "| n =", nrow(x), "\n\n")
  s <- summary(x)
  s$expected_count <- round(s$expected_count, 1)
  s$per_1000 <- round(s$per_1000, 1)
  print(s, row.names = FALSE, right = FALSE)
  invisible(x)
}
