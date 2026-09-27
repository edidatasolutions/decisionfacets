#' Define a pass/fail cut under an explicit decision rule
#'
#' The decision rule determines how rater severity can reach the decision:
#' \describe{
#'   \item{`raw_total`}{Pass if the summed observed ratings reach `value`.
#'     Severity passes straight through to the decision.}
#'   \item{`measure`}{Pass if the severity-adjusted Rasch measure (logits)
#'     reaches `value`. Severity is modeled out; only its effect on
#'     measurement precision remains.}
#'   \item{`fair_average`}{Pass if the FACETS-style fair average (expected
#'     mean rating per cell for an average rater) reaches `value`. It is
#'     monotone in the measure, so it behaves like `measure` with a
#'     transformed cut.}
#' }
#' @param value The cut score on the scale implied by `decision_rule`.
#' @param decision_rule One of `"raw_total"`, `"fair_average"`, `"measure"`.
#' @return A `df_cut` object (a list with `value` and `decision_rule`).
#' @examples
#' df_cut(16, "raw_total")        # pass if the summed ratings reach 16
#' df_cut(2, "fair_average")      # pass if the fair average reaches 2
#' df_cut(0.25, "measure")        # pass if the Rasch measure reaches 0.25 logits
#' @export
df_cut <- function(value, decision_rule = c("raw_total", "fair_average", "measure")) {
  structure(list(value = value, decision_rule = match.arg(decision_rule)),
            class = "df_cut")
}

# Put the cut on the logit scale when the rule is measure-based.
resolve_cut <- function(cut, par) {
  if (!inherits(cut, "df_cut")) stop("`cut` must come from df_cut().")
  cut$theta <- switch(cut$decision_rule,
    raw_total = NA_real_,
    measure = cut$value,
    fair_average = {
      K <- length(par$tau)
      fa <- function(t) mean(vapply(par$delta, function(dl)
        sum(mfrm_probs(t - dl, par$tau) * (0:K)), numeric(1)))
      if (cut$value <= 0 || cut$value >= K)
        stop("fair_average cut must lie strictly between 0 and ", K, ".")
      stats::uniroot(function(t) fa(t) - cut$value, c(-15, 15), tol = 1e-10)$root
    })
  cut
}

# Raw-total cut a given panel must be held to. For measure-based rules the
# (ML) measure is monotone in the raw total given the panel, so
# theta_hat >= theta_cut  <=>  total >= E_panel[total | theta_cut].
# Harsher panels get lower raw cuts: this is how severity adjustment works.
raw_cut_for_panel <- function(cut, cells, par) {
  if (cut$decision_rule == "raw_total") return(cut$value)
  ceiling(expected_total(cut$theta, cells, par) - 1e-8)
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
  info$raw_cut <- vapply(seq_len(nrow(info)), function(n)
    raw_cut_for_panel(cut, panel_cells(names(par$delta),
                                       strsplit(info$panel[n], "|", fixed = TRUE)[[1]]), par),
    numeric(1))
  info$pass <- info$total >= info$raw_cut
  info
}

# One row per person: panel key and raw total; checks the crossed design.
person_panels <- function(d) {
  persons <- unique(d$person)
  panel <- tapply(d$rater, d$person, function(r) paste(sort(unique(r)), collapse = "|"))
  n_items <- length(unique(d$item))
  size <- lengths(strsplit(panel, "|", fixed = TRUE))
  n_rows <- table(d$person)
  if (any(n_rows[names(size)] != size * n_items))
    stop("MVP assumes every panel rater scores every item for each candidate.")
  data.frame(person = persons, panel = unname(panel[persons]),
             total = unname(tapply(d$score, d$person, sum)[persons]),
             stringsAsFactors = FALSE)
}
