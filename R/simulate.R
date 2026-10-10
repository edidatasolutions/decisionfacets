#' Simulate a rater-mediated administration with known truth
#'
#' Two scoring designs are available. In the `"crossed"` design each candidate
#' is scored on every item by a panel of `raters_per_person` raters drawn at
#' random from the pool. In the `"per_item"` design each item (for example an
#' oral-examination case) has its own set of `raters_per_item` qualified
#' examiners, and each of a candidate's items is scored by one examiner drawn
#' from that item's set, with no examiner scoring the same candidate twice
#' when it can be avoided.
#'
#' Scores are ordinal (many-facet Rasch rating scale model) or continuous
#' (linear many-facet model on a score scale such as 0-100).
#'
#' @param n_persons,n_items,n_raters Facet sizes.
#' @param raters_per_person Panel size per candidate (crossed design).
#' @param n_cat Number of score categories (ordinal scores 0..n_cat-1).
#' @param theta_mean,theta_sd Candidate ability distribution (ordinal: logits).
#' @param item_sd,severity_sd SDs of item difficulty and rater severity (both
#'   centered). For continuous scores they are on the score scale.
#' @param tau Category thresholds; defaults to equally spaced on [-1.5, 1.5].
#' @param design `"crossed"` or `"per_item"`.
#' @param raters_per_item Qualified examiners per item in the per-item design
#'   (default: all raters).
#' @param scale `"ordinal"` or `"continuous"`.
#' @param continuous Settings for continuous scores: `center` (mean score),
#'   `theta_sd`, `item_sd`, `severity_sd` and `sigma` (residual SD), all on
#'   the score scale, `bounds` (scores are truncated to this range) and
#'   `round` (round to whole points). They replace `theta_mean`, `theta_sd`,
#'   `item_sd` and `severity_sd` when `scale = "continuous"`.
#' @param seed Optional RNG seed.
#' @return A `df_sim` object: `$data` (a `df_data`) and `$par`, the true
#'   parameters (`theta`, `delta`, `lambda`, and `tau` or `sigma` and
#'   `model = "linear"`, all named).
#' @examples
#' sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
#' head(sim$data)
#' sim$par$lambda   # true rater severities
#'
#' # Oral examination: 8 cases, one examiner per case, scores 0-100
#' oral <- df_simulate(n_persons = 100, n_items = 8, n_raters = 24,
#'                     design = "per_item", raters_per_item = 6,
#'                     scale = "continuous", seed = 1)
#' head(oral$data)
#' @export
df_simulate <- function(n_persons = 500, n_items = 4, n_raters = 12,
                        raters_per_person = 2, n_cat = 5,
                        theta_mean = 0, theta_sd = 1,
                        item_sd = 0.5, severity_sd = 0.5,
                        tau = NULL, design = c("crossed", "per_item"),
                        raters_per_item = NULL, scale = c("ordinal", "continuous"),
                        continuous = list(), seed = NULL) {
  design <- match.arg(design); scale <- match.arg(scale)
  if (!is.null(seed)) set.seed(seed)
  pid <- sprintf("P%04d", seq_len(n_persons))
  iid <- sprintf("I%02d", seq_len(n_items))
  rid <- sprintf("R%02d", seq_len(n_raters))
  center <- function(v) v - mean(v)

  if (scale == "continuous") {
    cs <- utils::modifyList(list(center = 70, theta_sd = 8, item_sd = 4, severity_sd = 4,
                                 sigma = 8, bounds = c(0, 100), round = TRUE), continuous)
    par <- list(
      theta  = stats::setNames(stats::rnorm(n_persons, cs$center, cs$theta_sd), pid),
      delta  = stats::setNames(center(stats::rnorm(n_items, 0, cs$item_sd)), iid),
      lambda = stats::setNames(center(stats::rnorm(n_raters, 0, cs$severity_sd)), rid),
      sigma  = cs$sigma,
      model  = "linear"
    )
  } else {
    K <- n_cat - 1
    if (is.null(tau)) tau <- seq(-1.5, 1.5, length.out = K)
    stopifnot(length(tau) == K)
    par <- list(
      theta  = stats::setNames(stats::rnorm(n_persons, theta_mean, theta_sd), pid),
      delta  = stats::setNames(center(stats::rnorm(n_items, 0, item_sd)), iid),
      lambda = stats::setNames(center(stats::rnorm(n_raters, 0, severity_sd)), rid),
      tau    = tau - mean(tau)
    )
  }

  if (design == "crossed") {
    stopifnot(raters_per_person <= n_raters)
    rows <- lapply(pid, function(p) {
      cells <- panel_cells(iid, sample(rid, raters_per_person))
      cells$person <- p
      cells
    })
  } else {
    if (is.null(raters_per_item)) raters_per_item <- n_raters
    stopifnot(raters_per_item <= n_raters, raters_per_item >= 1)
    eligible <- lapply(stats::setNames(iid, iid), function(i) sample(rid, raters_per_item))
    rows <- lapply(pid, function(p) {
      cells <- draw_assignment(iid, eligible)
      cells$person <- p
      cells
    })
  }
  d <- do.call(rbind, rows)

  eta <- par$theta[d$person] - par$delta[d$item] - par$lambda[d$rater]
  if (scale == "continuous") {
    s <- eta + stats::rnorm(length(eta), 0, par$sigma)
    if (isTRUE(cs$round)) s <- round(s)
    if (!is.null(cs$bounds)) s <- pmin(pmax(s, cs$bounds[1]), cs$bounds[2])
    d$score <- unname(s)
    data <- df_data(d, scale = "continuous")
  } else {
    P <- mfrm_probs(eta, par$tau)
    d$score <- apply(P, 1, function(p) sample.int(length(par$tau) + 1, 1, prob = p) - 1L)
    data <- df_data(d)
  }
  structure(list(data = data, par = par), class = "df_sim")
}
