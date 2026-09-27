#' Fit a many-facet Rasch rating scale model
#'
#' @param data A `df_data` object.
#' @param engine `"tam"` (marginal ML via `TAM::tam.mml.mfr`, the default when
#'   TAM is installed) or `"jmle"` (built-in joint maximum likelihood, the
#'   FACETS approach).
#' @param max_iter,tol Convergence controls; `tol = NULL` uses each engine's
#'   default (1e-4 for TAM, 1e-6 for JMLE).
#' @return A `df_fit` object: `$data`, `$par` (named `theta`, `delta`,
#'   `lambda`, `tau`; for TAM also `theta_prior`, the fitted population
#'   mean and SD), `$engine`, `$converged`, `$iterations`, and for TAM the
#'   fitted `$model`.
#' @details Both engines report parameters in the same parameterization:
#'   item difficulties and rater severities centered at 0, thresholds centered
#'   at 0, and person measures on the resulting logit scale. For TAM,
#'   `par$theta` holds EAPs.
#'
#'   JMLE person measures are clamped to [-7, 7], so extreme scores get a
#'   finite but arbitrary measure. JMLE's known small-sample spread inflation
#'   is not corrected.
#' @examples
#' sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
#' fit <- df_fit(sim$data, engine = "jmle")
#' cor(fit$par$lambda, sim$par$lambda[names(fit$par$lambda)])
#' \donttest{
#' if (requireNamespace("TAM", quietly = TRUE)) {
#'   fit_tam <- df_fit(sim$data, engine = "tam")
#'   fit_tam$par$tau
#' }
#' }
#' @export
df_fit <- function(data, engine = NULL, max_iter = 1000, tol = NULL) {
  if (is.null(engine))
    engine <- if (requireNamespace("TAM", quietly = TRUE)) "tam" else "jmle"
  engine <- match.arg(engine, c("tam", "jmle"))
  if (is.null(tol)) tol <- if (engine == "tam") 1e-4 else 1e-6
  if (!inherits(data, "df_data")) data <- df_data(data)
  fit <- switch(engine,
    tam = tam_mfrm(data, attr(data, "K"), max_iter, tol),
    jmle = jmle_mfrm(data, attr(data, "K"), max_iter, tol))
  structure(c(list(data = data, engine = engine), fit), class = "df_fit")
}

# TAM adapter. Parameters are read from the category intercepts (AXsi) of each
# item x rater pseudo-item rather than from xsi.facets labels, so the result
# does not depend on TAM's step parameterization or identification constraint:
#   AXsi[ij, k] - AXsi[ij, k-1] = a_ij + tau_k,   a_ij = delta_i + lambda_j + c
tam_mfrm <- function(d, K, max_iter, tol) {
  if (!requireNamespace("TAM", quietly = TRUE))
    stop("engine = 'tam' needs the TAM package: install.packages('TAM')")
  w <- stats::reshape(d, idvar = c("person", "rater"), timevar = "item",
                      direction = "wide")
  items <- sort(unique(d$item))
  resp <- w[paste0("score.", items)]
  names(resp) <- items
  mod <- TAM::tam.mml.mfr(resp, facets = data.frame(rater = w$rater),
                          pid = w$person, formulaA = ~ item + rater + step,
                          control = list(progress = FALSE, maxiter = max_iter,
                                         conv = tol))

  raters <- sort(unique(d$rater))
  key <- expand.grid(item = items, rater = raters, stringsAsFactors = FALSE)
  key$label <- paste0(key$item, "-rater", key$rater)
  pseudo <- key[match(mod$item$item, key$label), ]
  if (anyNA(pseudo$item)) stop("Could not map TAM pseudo-items to item x rater cells.")

  # mod$item's AXsi_.Cat columns are row-aligned with the pseudo-item labels and
  # in difficulty orientation: P(k) proportional to exp(k * theta - AXsi_k).
  # (mod$AXsi itself has the opposite sign.)
  ax <- cbind(0, as.matrix(mod$item[paste0("AXsi_.Cat", 1:K)]))
  steps <- matrix(t(apply(ax, 1, diff)), ncol = K)
  a <- rowMeans(steps)
  tau <- colMeans(steps - a)
  lmfit <- stats::lm(a ~ item + rater, data = pseudo,
                     contrasts = list(item = "contr.sum", rater = "contr.sum"))
  if (max(abs(stats::residuals(lmfit))) > 1e-4)
    warning("TAM intercepts are not additive in item + rater; check the model.")
  cf <- stats::coef(lmfit)
  eff <- function(prefix, lv) {
    b <- cf[grep(paste0("^", prefix), names(cf))]
    stats::setNames(c(b, -sum(b)), lv)
  }
  shift <- cf[["(Intercept)"]]

  person <- mod$person
  list(
    par = list(
      theta = stats::setNames(person$EAP - shift, person$pid),
      delta = eff("item", items),
      lambda = eff("rater", raters),
      tau = tau,
      theta_prior = c(mean = drop(mod$beta) - shift, sd = sqrt(drop(mod$variance)))
    ),
    converged = mod$iter < max_iter, iterations = mod$iter, model = mod
  )
}

jmle_mfrm <- function(d, K, max_iter, tol) {
  pf <- factor(d$person); itf <- factor(d$item); rf <- factor(d$rater)
  pi <- as.integer(pf); ii <- as.integer(itf); ri <- as.integer(rf)
  th <- numeric(nlevels(pf)); de <- numeric(nlevels(itf)); la <- numeric(nlevels(rf))
  tau <- seq(-1, 1, length.out = K)
  x <- d$score
  n_ge <- vapply(1:K, function(h) sum(x >= h), numeric(1))
  clamp <- function(v, lim) pmax(pmin(v, lim), -lim)
  moments <- function() {
    P <- mfrm_probs(th[pi] - de[ii] - la[ri], tau)
    E <- drop(P %*% (0:K))
    list(P = P, r = x - E, V = drop(P %*% (0:K)^2) - E^2)
  }
  converged <- FALSE
  for (it in seq_len(max_iter)) {
    old <- c(th, de, la, tau)
    m <- moments()
    th <- clamp(th + clamp(drop(rowsum(m$r, pi) / rowsum(m$V, pi)), 1), 7)
    m <- moments()
    de <- de - clamp(drop(rowsum(m$r, ii) / rowsum(m$V, ii)), 1)
    de <- de - mean(de)
    m <- moments()
    la <- la - clamp(drop(rowsum(m$r, ri) / rowsum(m$V, ri)), 1)
    la <- la - mean(la)
    m <- moments()
    Pge <- vapply(1:K, function(h) rowSums(m$P[, (h + 1):(K + 1), drop = FALSE]),
                  numeric(nrow(m$P)))
    Pge <- matrix(Pge, ncol = K)
    tau <- tau + clamp((colSums(Pge) - n_ge) / colSums(Pge * (1 - Pge)), 1)
    tau <- tau - mean(tau)
    if (max(abs(c(th, de, la, tau) - old)) < tol) { converged <- TRUE; break }
  }
  if (!converged) warning("JMLE did not converge in ", max_iter, " iterations.")
  list(
    par = list(
      theta  = stats::setNames(th, levels(pf)),
      delta  = stats::setNames(de, levels(itf)),
      lambda = stats::setNames(la, levels(rf)),
      tau    = tau
    ),
    converged = converged, iterations = it
  )
}

#' Rater severity estimates
#'
#' @param object A `df_fit` or `df_sim`.
#' @return A data frame of rater ids and severities (logits, centered at 0;
#'   positive = harsher).
#' @examples
#' sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
#' df_rater_effects(sim)
#' @export
df_rater_effects <- function(object) {
  data.frame(rater = names(object$par$lambda), severity = unname(object$par$lambda))
}
