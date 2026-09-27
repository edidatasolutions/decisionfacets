#' Counterfactual pass probabilities: would this candidate have passed with
#' different raters?
#'
#' For each candidate, computes the probability of passing a re-rating under
#' (a) the observed panel, (b) a panel of average-severity raters, and (c) a
#' panel drawn at random from the rater pool, all under the same decision rule.
#' Probabilities are exact (recursive convolution of the model's category
#' probabilities); the only approximation is sampling panels when the pool is
#' too large to enumerate.
#'
#' @param object A `df_fit` (estimated parameters) or `df_sim` (true parameters).
#' @param cut A `df_cut`.
#' @param theta How candidate ability enters: `"posterior"` integrates over the
#'   grid posterior given the candidate's observed ratings (the default for a
#'   `df_fit`, so probabilities include measurement error); `"point"` plugs in
#'   `object$par$theta` (the default for a `df_sim`, giving the known truth).
#' @param max_panels Enumerate all rater panels when there are at most this many;
#'   otherwise sample this many panels.
#' @param flag_delta Minimum rater advantage (see below) for a flag.
#' @param grid Theta grid for the posterior.
#' @param prior_mean,prior_sd Normal prior for the posterior; default to the
#'   fitted population prior when the fit supplies one (`par$theta_prior`),
#'   otherwise the mean and SD of the person estimates.
#' @param seed Optional seed for panel sampling.
#' @return A `df_counterfactual` data frame, one row per candidate:
#'   `person`, `panel`, `total`, `raw_cut`, `pass_observed` (actual decision),
#'   `p_observed`, `p_average`, `p_random`, `p_min`, `p_max` (worst and best
#'   panel in the pool), `delta` (= p_observed - p_random),
#'   `advantage`, `direction` and `rater_dependent`.
#'
#'   `advantage` is how much the assigned panel pushed the candidate toward
#'   the outcome they actually received: `delta` for a pass, `-delta` for a
#'   fail. Equivalently, it is the increase in the probability that a re-rating
#'   would reverse the decision when the observed panel is swapped for a random
#'   one; decision reversals from measurement error alone cancel out.
#'   `rater_dependent` is `advantage >= flag_delta`, and `direction` labels
#'   flagged cases `"lenient_panel_pass"` (board's false-pass exposure) or
#'   `"harsh_panel_fail"` (the appeal case).
#' @examples
#' sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
#' fit <- df_fit(sim$data, engine = "jmle")
#' cf <- df_counterfactual(fit, df_cut(12, "raw_total"))
#' cf                 # most rater-dependent candidates first
#' summary(cf)
#' # Known truth: the same analysis with the true parameters
#' summary(df_counterfactual(sim, df_cut(12, "raw_total")))
#' @export
df_counterfactual <- function(object, cut, theta = c("auto", "posterior", "point"),
                              max_panels = 2000, flag_delta = 0.2,
                              grid = seq(-6, 6, by = 0.1),
                              prior_mean = NULL, prior_sd = NULL, seed = NULL) {
  theta <- match.arg(theta)
  if (theta == "auto") theta <- if (inherits(object, "df_sim")) "point" else "posterior"
  par <- object$par; d <- object$data
  cut <- resolve_cut(cut, par)
  items <- names(par$delta); pool <- names(par$lambda)
  info <- person_panels(d)
  persons <- info$person
  sizes <- unique(lengths(strsplit(info$panel, "|", fixed = TRUE)))
  if (length(sizes) != 1) stop("MVP assumes all candidates have the same panel size.")
  r <- sizes

  # Pass curves are evaluated at candidates' thetas (point) or on a grid
  # (posterior) and then mapped to candidates. Curves are kept so that
  # df_attribute() can reuse them.
  W <- NULL
  if (theta == "point") {
    pts <- par$theta[persons]
    to_person <- function(C) C
  } else {
    prior <- par$theta_prior
    if (is.null(prior)) prior <- c(mean = mean(par$theta), sd = stats::sd(par$theta))
    if (is.null(prior_mean)) prior_mean <- prior[["mean"]]
    if (is.null(prior_sd)) prior_sd <- prior[["sd"]]
    W <- theta_posterior(d, par, persons, grid, prior_mean, prior_sd)
    pts <- grid
    to_person <- function(C) W %*% C
  }
  raw_curve <- function(raters, p = par) {
    cells <- panel_cells(items, raters)
    pass_prob(pts, cells, p, raw_cut_for_panel(cut, cells, p))
  }
  split_key <- function(key) strsplit(key, "|", fixed = TRUE)[[1]]

  # Random panel: enumerate the pool when feasible, else sample.
  if (choose(length(pool), r) <= max_panels) {
    panels <- utils::combn(pool, r, simplify = FALSE)
  } else {
    if (!is.null(seed)) set.seed(seed)
    panels <- replicate(max_panels, sample(pool, r), simplify = FALSE)
  }
  keys <- vapply(panels, function(p) paste(sort(p), collapse = "|"), "")
  C <- matrix(vapply(panels, raw_curve, numeric(length(pts))),
              nrow = length(pts), dimnames = list(NULL, keys))
  M <- to_person(C)

  # Observed panels: reuse enumerated curves when available.
  obs_keys <- unique(info$panel)
  C_obs <- vapply(obs_keys, function(k)
    if (k %in% keys) C[, k] else raw_curve(split_key(k)), numeric(length(pts)))
  C_obs <- matrix(C_obs, nrow = length(pts), dimnames = list(NULL, obs_keys))
  obs_index <- match(info$panel, obs_keys)
  p_obs <- to_person(C_obs)[cbind(seq_along(persons), obs_index)]

  # Average panel: r raters of severity 0.
  par_avg <- par
  par_avg$lambda <- c(par$lambda, .avg = 0)
  c_avg <- raw_curve(rep(".avg", r), par_avg)
  p_avg <- drop(to_person(matrix(c_avg)))

  # The intended standard on the logit scale: where an average panel's
  # expected raw total meets the raw cut, or the measure-scale cut directly.
  theta_standard <- if (cut$decision_rule == "raw_total") {
    avg_cells <- panel_cells(items, rep(".avg", r))
    if (cut$value <= 0 || cut$value >= nrow(avg_cells) * length(par$tau))
      stop("raw_total cut must lie strictly inside the score range.")
    stats::uniroot(function(t) expected_total(t, avg_cells, par_avg) - cut$value,
                   c(-15, 15), tol = 1e-10)$root
  } else cut$theta

  cls <- df_classify(object, cut)
  out <- data.frame(
    cls,
    pass_observed = cls$pass,
    p_observed = p_obs,
    p_average = p_avg,
    p_random = rowMeans(M),
    p_min = apply(M, 1, min),
    p_max = apply(M, 1, max),
    stringsAsFactors = FALSE
  )
  out$pass <- NULL
  out$delta <- out$p_observed - out$p_random
  out$advantage <- ifelse(out$pass_observed, out$delta, -out$delta)
  out$rater_dependent <- out$advantage >= flag_delta
  out$direction <- ifelse(!out$rater_dependent, NA_character_,
                          ifelse(out$pass_observed, "lenient_panel_pass", "harsh_panel_fail"))
  structure(out, class = c("df_counterfactual", "data.frame"),
            cut = cut, theta_mode = theta, n_panels = length(panels),
            enumerated = length(panels) == choose(length(pool), r),
            internals = list(pts = pts, W = W, C = C, C_obs = C_obs,
                             obs_index = obs_index, c_avg = c_avg,
                             theta_standard = theta_standard,
                             known_truth = inherits(object, "df_sim") && theta == "point"))
}

#' @export
summary.df_counterfactual <- function(object, ...) {
  cut <- attr(object, "cut")
  data.frame(
    decision_rule = cut$decision_rule,
    cut = cut$value,
    n = nrow(object),
    pass_rate_observed = mean(object$pass_observed),
    expected_pass_rate_random_panel = mean(object$p_random),
    mean_abs_delta = mean(abs(object$delta)),
    n_rater_dependent = sum(object$rater_dependent),
    n_lenient_panel_pass = sum(object$direction %in% "lenient_panel_pass"),
    n_harsh_panel_fail = sum(object$direction %in% "harsh_panel_fail"),
    n_panel_sensitive = sum(object$p_max - object$p_min >= 0.5)
  )
}

#' @export
print.df_counterfactual <- function(x, n = 10, ...) {
  cut <- attr(x, "cut")
  cat("<df_counterfactual> rule =", cut$decision_rule, "| cut =", cut$value,
      "| theta =", attr(x, "theta_mode"), "|", attr(x, "n_panels"),
      if (attr(x, "enumerated")) "panels (all)" else "panels (sampled)", "\n")
  cat(sum(x$rater_dependent), "of", nrow(x), "candidates flagged as rater-dependent\n\n")
  top <- x[order(-x$advantage), ][seq_len(min(n, nrow(x))), ]
  print(format(as.data.frame(top), digits = 3), row.names = FALSE)
  invisible(x)
}
