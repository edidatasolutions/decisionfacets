# Two measurement models share the same downstream machinery:
#
# Many-facet Rasch rating scale model (ordinal scores 0..K):
#   log P(X = k) / P(X = k - 1) = theta_n - delta_i - lambda_j - tau_k,  k = 1..K
# The distribution of a raw total over a panel's (item, rater) cells is
# computed exactly by recursive convolution.
#
# Linear many-facet model (continuous scores, e.g. 0-100):
#   X = theta_n - delta_i - lambda_j + e,   e ~ N(0, sigma^2)
# theta_n is on the score scale; delta and lambda are centered at 0. The raw
# total over m cells is normal with mean m * theta - sum(delta + lambda) and
# variance m * sigma^2.

is_continuous <- function(par) identical(par$model, "linear")

# Category probabilities. eta = theta - delta - lambda (vector); tau = K thresholds.
# Returns a length(eta) x (K + 1) matrix.
mfrm_probs <- function(eta, tau) {
  K <- length(tau)
  cs <- c(0, cumsum(tau))
  num <- outer(eta, 0:K) - matrix(cs, length(eta), K + 1, byrow = TRUE)
  num <- num - apply(num, 1, max)
  e <- exp(num)
  e / rowSums(e)
}

# Cells scored for one candidate when every panel rater scores every item.
panel_cells <- function(items, raters) {
  expand.grid(item = items, rater = raters, stringsAsFactors = FALSE)
}

# Exact raw-total distribution at each theta (ordinal model only).
# Returns length(theta) x (Tmax + 1).
score_dist <- function(theta, cells, par) {
  K <- length(par$tau)
  D <- matrix(1, length(theta), 1)
  for (o in seq_len(nrow(cells))) {
    eta <- theta - par$delta[[cells$item[o]]] - par$lambda[[cells$rater[o]]]
    P <- mfrm_probs(eta, par$tau)
    new <- matrix(0, length(theta), ncol(D) + K)
    for (k in 0:K) {
      cols <- k + seq_len(ncol(D))
      new[, cols] <- new[, cols] + D * P[, k + 1]
    }
    D <- new
  }
  D
}

# Expected raw total over a panel's cells at each theta.
expected_total <- function(theta, cells, par) {
  if (is_continuous(par))
    return(nrow(cells) * theta - sum(par$delta[cells$item] + par$lambda[cells$rater]))
  K <- length(par$tau)
  out <- numeric(length(theta))
  for (o in seq_len(nrow(cells))) {
    eta <- theta - par$delta[[cells$item[o]]] - par$lambda[[cells$rater[o]]]
    out <- out + drop(mfrm_probs(eta, par$tau) %*% (0:K))
  }
  out
}

# Highest attainable raw total for a set of cells (Inf for continuous scores).
max_total <- function(cells, par) {
  if (is_continuous(par)) Inf else nrow(cells) * length(par$tau)
}

# P(raw total >= raw_cut) at each theta.
pass_prob <- function(theta, cells, par, raw_cut) {
  if (is_continuous(par)) {
    mu <- expected_total(theta, cells, par)
    return(stats::pnorm((mu - raw_cut) / (par$sigma * sqrt(nrow(cells)))))
  }
  D <- score_dist(theta, cells, par)
  if (raw_cut <= 0) return(rep(1, length(theta)))
  if (raw_cut > ncol(D) - 1) return(rep(0, length(theta)))
  rowSums(D[, (raw_cut + 1):ncol(D), drop = FALSE])
}

# Grid posterior of theta for each person given their observed responses.
# Returns an n_person x length(grid) matrix of weights (rows sum to 1).
theta_posterior <- function(d, par, persons, grid, prior_mean, prior_sd) {
  offset <- outer(-(par$delta[d$item] + par$lambda[d$rater]), grid, "+")
  if (is_continuous(par)) {
    ll <- -0.5 * ((d$score - offset) / par$sigma)^2
  } else {
    K <- length(par$tau)
    cs <- c(0, cumsum(par$tau))
    terms <- lapply(0:K, function(k) k * offset - cs[k + 1])
    mx <- Reduce(pmax, terms)
    lse <- mx + log(Reduce(`+`, lapply(terms, function(t) exp(t - mx))))
    ll <- d$score * offset - cs[d$score + 1] - lse
  }
  LL <- rowsum(ll, d$person)[persons, , drop = FALSE]
  LL <- sweep(LL, 2, stats::dnorm(grid, prior_mean, prior_sd, log = TRUE), "+")
  W <- exp(LL - apply(LL, 1, max))
  W / rowSums(W)
}
