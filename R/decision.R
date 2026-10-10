#' Define a pass/fail cut under an explicit decision rule
#'
#' The decision rule determines how rater severity can reach the decision:
#' \describe{
#'   \item{`raw_total`}{Pass if the summed observed ratings reach `value`.
#'     Severity passes straight through to the decision.}
#'   \item{`raw_mean`}{Pass if the mean observed rating reaches `value` (for
#'     example 70 on a 0-100 scale). Equivalent to `raw_total` with a cut of
#'     `value` times the number of ratings, which is convenient when
#'     candidates have different numbers of ratings.}
#'   \item{`measure`}{Pass if the severity-adjusted measure reaches `value`
#'     (logits for ordinal scores; score points for continuous scores).
#'     Severity is modeled out; only its effect on measurement precision
#'     remains.}
#'   \item{`fair_average`}{Pass if the FACETS-style fair average (expected
#'     mean rating per cell for an average rater) reaches `value`. It is
#'     monotone in the measure, so it behaves like `measure` with a
#'     transformed cut. For continuous scores it equals the measure.}
#' }
#' @param value The cut score on the scale implied by `decision_rule`.
#' @param decision_rule One of `"raw_total"`, `"raw_mean"`, `"fair_average"`,
#'   `"measure"`.
#' @return A `df_cut` object (a list with `value` and `decision_rule`).
#' @examples
#' df_cut(16, "raw_total")        # pass if the summed ratings reach 16
#' df_cut(70, "raw_mean")         # pass if the mean rating reaches 70
#' df_cut(2, "fair_average")      # pass if the fair average reaches 2
#' df_cut(0.25, "measure")        # pass if the measure reaches 0.25
#' @export
df_cut <- function(value, decision_rule = c("raw_total", "raw_mean", "fair_average", "measure")) {
  structure(list(value = value, decision_rule = match.arg(decision_rule)),
            class = "df_cut")
}

is_raw_rule <- function(cut) cut$decision_rule %in% c("raw_total", "raw_mean")

# Put the cut on the theta scale when the rule is measure-based.
resolve_cut <- function(cut, par) {
  if (!inherits(cut, "df_cut")) stop("`cut` must come from df_cut().")
  cut$theta <- switch(cut$decision_rule,
    raw_total = NA_real_,
    raw_mean = NA_real_,
    measure = cut$value,
    fair_average = {
      if (is_continuous(par)) {
        cut$value + mean(par$delta)
      } else {
        K <- length(par$tau)
        fa <- function(t) mean(vapply(par$delta, function(dl)
          sum(mfrm_probs(t - dl, par$tau) * (0:K)), numeric(1)))
        if (cut$value <= 0 || cut$value >= K)
          stop("fair_average cut must lie strictly between 0 and ", K, ".")
        stats::uniroot(function(t) fa(t) - cut$value, c(-15, 15), tol = 1e-10)$root
      }
    })
  cut
}

# Raw-total cut a given panel must be held to. For measure-based rules the
# (ML) measure is monotone in the raw total given the panel, so
# theta_hat >= theta_cut  <=>  total >= E_panel[total | theta_cut].
# Harsher panels get lower raw cuts: this is how severity adjustment works.
# Ordinal totals are integers, so cuts are rounded up; continuous ones are not.
raw_cut_for_panel <- function(cut, cells, par) {
  v <- switch(cut$decision_rule,
    raw_total = return(cut$value),
    raw_mean = cut$value * nrow(cells),
    expected_total(cut$theta, cells, par))
  if (is_continuous(par)) v else ceiling(v - 1e-8)
}

# The intended standard on the theta scale: for raw rules, the ability at
# which an average-severity panel's expected total meets the raw cut.
theta_standard_for <- function(cut, cells_avg, par_avg) {
  if (!is_raw_rule(cut)) return(cut$theta)
  target <- raw_cut_for_panel(cut, cells_avg, par_avg)
  if (is_continuous(par_avg))
    return((target + sum(par_avg$delta[cells_avg$item] + par_avg$lambda[cells_avg$rater])) /
             nrow(cells_avg))
  if (target <= 0 || target >= max_total(cells_avg, par_avg))
    stop("The raw cut must lie strictly inside the score range.")
  stats::uniroot(function(t) expected_total(t, cells_avg, par_avg) - target,
                 c(-15, 15), tol = 1e-10)$root
}

#' Classify candidates from their observed scores
#'
#' @param object A `df_fit` or `df_sim`.
#' @param cut A `df_cut`.
#' @return Data frame: `person`, `panel`, `total`, `raw_cut` (the raw total this
#'   candidate's panel had to reach), `pass`.
#' @examples
#' sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
#' head(df_classify(sim, df_cut(0, "measure")))
#' @export
df_classify <- function(object, cut) {
  par <- object$par; d <- object$data
  cut <- resolve_cut(cut, par)
  info <- person_panels(d)
  cells <- person_cells(d, info$person)
  info$raw_cut <- vapply(seq_len(nrow(info)), function(n)
    raw_cut_for_panel(cut, cells[[n]], par), numeric(1))
  info$pass <- info$total >= info$raw_cut - 1e-9
  info[c("person", "panel", "total", "raw_cut", "pass")]
}

# Scoring design. "crossed": every rater on a candidate's panel scores every
# item (all candidates take the same items). "assignment": any other pattern,
# for example one examiner per case.
data_design <- function(d) {
  items <- unique(d$item)
  per_person <- split(d[c("item", "rater")], d$person)
  crossed <- all(vapply(per_person, function(x) {
    r <- unique(x$rater)
    nrow(x) == length(items) * length(r) && setequal(unique(x$item), items)
  }, logical(1)))
  if (crossed) "crossed" else "assignment"
}

# The (item, rater) cells scored for each person, in `persons` order.
person_cells <- function(d, persons) {
  cl <- split(d[c("item", "rater")], d$person)[persons]
  lapply(cl, function(x) { rownames(x) <- NULL; x[order(x$item, x$rater), ] })
}

# One row per person: panel key, item-set key and raw total.
# Panel keys list raters for crossed designs ("R01|R02") and item=rater
# pairs otherwise ("C01=R07|C02=R03").
person_panels <- function(d) {
  persons <- unique(d$person)
  design <- data_design(d)
  cells <- person_cells(d, persons)
  panel <- vapply(cells, function(x)
    if (design == "crossed") paste(sort(unique(x$rater)), collapse = "|")
    else paste(x$item, x$rater, sep = "=", collapse = "|"), "")
  itemset <- vapply(cells, function(x) paste(sort(unique(x$item)), collapse = "|"), "")
  data.frame(person = persons, panel = unname(panel), itemset = unname(itemset),
             total = unname(tapply(d$score, d$person, sum)[persons]),
             stringsAsFactors = FALSE)
}
