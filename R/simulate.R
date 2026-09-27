#' Simulate a rater-mediated administration with known truth
#'
#' Each candidate is scored on every item by a panel of `raters_per_person`
#' raters drawn at random from the pool.
#'
#' @param n_persons,n_items,n_raters Facet sizes.
#' @param raters_per_person Panel size per candidate.
#' @param n_cat Number of score categories (scores 0..n_cat-1).
#' @param theta_mean,theta_sd Candidate ability distribution.
#' @param item_sd,severity_sd SDs of item difficulty and rater severity (both centered).
#' @param tau Category thresholds; defaults to equally spaced on [-1.5, 1.5].
#' @param seed Optional RNG seed.
#' @return A `df_sim` object: `$data` (a `df_data`) and `$par`, the true
#'   parameters (`theta`, `delta`, `lambda`, `tau`, all named).
#' @examples
#' sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
#' head(sim$data)
#' sim$par$lambda   # true rater severities
#' @export
df_simulate <- function(n_persons = 500, n_items = 4, n_raters = 12,
                        raters_per_person = 2, n_cat = 5,
                        theta_mean = 0, theta_sd = 1,
                        item_sd = 0.5, severity_sd = 0.5,
                        tau = NULL, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  K <- n_cat - 1
  if (is.null(tau)) tau <- seq(-1.5, 1.5, length.out = K)
  stopifnot(length(tau) == K, raters_per_person <= n_raters)
  pid <- sprintf("P%04d", seq_len(n_persons))
  iid <- sprintf("I%02d", seq_len(n_items))
  rid <- sprintf("R%02d", seq_len(n_raters))
  center <- function(v) v - mean(v)
  par <- list(
    theta  = stats::setNames(stats::rnorm(n_persons, theta_mean, theta_sd), pid),
    delta  = stats::setNames(center(stats::rnorm(n_items, 0, item_sd)), iid),
    lambda = stats::setNames(center(stats::rnorm(n_raters, 0, severity_sd)), rid),
    tau    = tau - mean(tau)
  )
  rows <- lapply(pid, function(p) {
    cells <- panel_cells(iid, sample(rid, raters_per_person))
    cells$person <- p
    cells
  })
  d <- do.call(rbind, rows)
  eta <- par$theta[d$person] - par$delta[d$item] - par$lambda[d$rater]
  P <- mfrm_probs(eta, par$tau)
  d$score <- apply(P, 1, function(p) sample.int(K + 1, 1, prob = p) - 1L)
  structure(list(data = df_data(d), par = par), class = "df_sim")
}
