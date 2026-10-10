#' Counterfactual pass probabilities: would this candidate have passed with
#' different raters?
#'
#' For each candidate, computes the probability of passing a re-rating under
#' (a) the observed raters, (b) raters of average severity, and (c) raters
#' drawn at random from the pool, all under the same decision rule.
#'
#' Two scoring designs are supported:
#' \describe{
#'   \item{crossed}{Every rater on a candidate's panel scores every item. The
#'     random panel is a random set of raters from the pool, enumerated when
#'     feasible.}
#'   \item{assignment}{Any other pattern, typically one examiner per case. The
#'     random assignment draws, for each of the candidate's items, an examiner
#'     at random from those who scored that item, without reusing an
#'     examiner for the same candidate when an alternative exists.
#'     Assignments are sampled.}
#' }
#' Probabilities are exact given an assignment (recursive convolution for
#' ordinal scores, the normal distribution for continuous scores); the only
#' approximation is sampling assignments when they cannot be enumerated.
#'
#' @param object A `df_fit` (estimated parameters) or `df_sim` (true parameters).
#' @param cut A `df_cut`.
#' @param theta How candidate ability enters: `"posterior"` integrates over the
#'   grid posterior given the candidate's observed ratings (the default for a
#'   `df_fit`, so probabilities include measurement error); `"point"` plugs in
#'   `object$par$theta` (the default for a `df_sim`, giving the known truth).
#' @param max_panels Enumerate all rater panels when there are at most this many;
#'   otherwise sample this many panels or assignments.
#' @param flag_delta Minimum rater advantage (see below) for a flag.
#' @param grid Theta grid for the posterior. Defaults to `seq(-6, 6, by = 0.1)`
#'   for ordinal scores and a grid spanning six prior SDs for continuous scores.
#' @param prior_mean,prior_sd Normal prior for the posterior; default to the
#'   fitted population prior when the fit supplies one (`par$theta_prior`),
#'   otherwise the mean and SD of the person estimates.
#' @param seed Optional seed for panel sampling.
#' @return A `df_counterfactual` data frame, one row per candidate:
#'   `person`, `panel`, `total`, `raw_cut`, `pass_observed` (actual decision),
#'   `p_observed`, `p_average`, `p_random`, `p_min`, `p_max` (worst and best
#'   panel in the pool or among sampled assignments), `delta`
#'   (= p_observed - p_random), `advantage`, `direction` and `rater_dependent`.
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
#'
#' # One examiner per case, continuous 0-100 scores
#' oral <- df_simulate(n_persons = 150, n_items = 6, n_raters = 18,
#'                     design = "per_item", raters_per_item = 6,
#'                     scale = "continuous", seed = 2)
#' summary(df_counterfactual(oral, df_cut(70, "raw_mean"), seed = 1))
#' @export
df_counterfactual <- function(object, cut, theta = c("auto", "posterior", "point"),
                              max_panels = 2000, flag_delta = 0.2, grid = NULL,
                              prior_mean = NULL, prior_sd = NULL, seed = NULL) {
  theta <- match.arg(theta)
  if (theta == "auto") theta <- if (inherits(object, "df_sim")) "point" else "posterior"
  par <- object$par; d <- object$data
  cut <- resolve_cut(cut, par)
  info <- person_panels(d)
  persons <- info$person
  design <- data_design(d)
  cells_obs <- person_cells(d, persons)

  # Pass curves are evaluated at candidates' thetas (point) or on a grid
  # (posterior) and then mapped to candidates. Curves are kept so that
  # df_attribute() can reuse them.
  W <- NULL
  if (theta == "point") {
    pts <- par$theta[persons]
  } else {
    prior <- par$theta_prior
    if (is.null(prior)) prior <- c(mean = mean(par$theta), sd = stats::sd(par$theta))
    if (is.null(prior_mean)) prior_mean <- prior[["mean"]]
    if (is.null(prior_sd)) prior_sd <- prior[["sd"]]
    if (is.null(grid)) grid <- if (is_continuous(par))
      seq(prior_mean - 6 * prior_sd, prior_mean + 6 * prior_sd, length.out = 241)
      else seq(-6, 6, by = 0.1)
    W <- theta_posterior(d, par, persons, grid, prior_mean, prior_sd)
    pts <- grid
  }
  person_vals <- function(C, idx) {
    C <- as.matrix(C)
    if (is.null(W)) C[idx, , drop = FALSE] else W[idx, , drop = FALSE] %*% C
  }
  curve <- function(cells, p = par)
    pass_prob(pts, cells, p, raw_cut_for_panel(cut, cells, p))
  par_avg <- par
  par_avg$lambda <- c(par$lambda, .avg = 0)
  avg_cells <- function(items) data.frame(item = items, rater = ".avg", stringsAsFactors = FALSE)

  # Observed assignments (one curve per distinct panel key).
  obs_keys <- unique(info$panel)
  C_obs <- vapply(obs_keys, function(k) curve(cells_obs[[match(k, info$panel)]]),
                  numeric(length(pts)))
  C_obs <- matrix(C_obs, nrow = length(pts), dimnames = list(NULL, obs_keys))
  obs_index <- match(info$panel, obs_keys)
  p_obs <- vapply(seq_along(persons), function(n)
    drop(person_vals(C_obs[, obs_index[n]], n)), numeric(1))

  if (!is.null(seed)) set.seed(seed)
  groups <- list(); enumerated <- TRUE; n_panels <- NA_integer_
  p_avg <- p_rand <- p_min <- p_max <- numeric(length(persons))

  if (design == "crossed") {
    items <- names(par$delta)
    pool <- names(par$lambda)
    r <- unique(lengths(strsplit(info$panel, "|", fixed = TRUE)))
    if (length(r) != 1) stop("Crossed designs need the same panel size for all candidates.")
    if (choose(length(pool), r) <= max_panels) {
      panels <- utils::combn(pool, r, simplify = FALSE)
    } else {
      panels <- replicate(max_panels, sample(pool, r), simplify = FALSE)
      enumerated <- FALSE
    }
    keys <- vapply(panels, function(p) paste(sort(p), collapse = "|"), "")
    C <- matrix(vapply(panels, function(p) curve(panel_cells(items, p)), numeric(length(pts))),
                nrow = length(pts), dimnames = list(NULL, keys))
    a_cells <- panel_cells(items, rep(".avg", r))
    groups[[1]] <- list(members = seq_along(persons), C = C,
                        c_avg = curve(a_cells, par_avg),
                        theta_standard = theta_standard_for(cut, a_cells, par_avg))
    n_panels <- length(panels)
  } else {
    eligible <- lapply(split(d$rater, d$item), unique)
    for (s in unique(info$itemset)) {
      members <- which(info$itemset == s)
      items <- strsplit(s, "|", fixed = TRUE)[[1]]
      C <- vapply(seq_len(max_panels), function(b)
        curve(draw_assignment(items, eligible)), numeric(length(pts)))
      C <- matrix(C, nrow = length(pts))
      a_cells <- avg_cells(items)
      groups[[length(groups) + 1]] <- list(members = members, C = C,
                                           c_avg = curve(a_cells, par_avg),
                                           theta_standard = theta_standard_for(cut, a_cells, par_avg))
    }
    enumerated <- FALSE; n_panels <- max_panels
  }

  for (g in groups) {
    M <- person_vals(g$C, g$members)
    p_rand[g$members] <- rowMeans(M)
    p_min[g$members] <- apply(M, 1, min)
    p_max[g$members] <- apply(M, 1, max)
    p_avg[g$members] <- drop(person_vals(g$c_avg, g$members))
  }

  cls <- df_classify(object, cut)
  out <- data.frame(
    cls,
    pass_observed = cls$pass,
    p_observed = p_obs,
    p_average = p_avg,
    p_random = p_rand,
    p_min = p_min,
    p_max = p_max,
    stringsAsFactors = FALSE
  )
  out$pass <- NULL
  out$delta <- out$p_observed - out$p_random
  out$advantage <- ifelse(out$pass_observed, out$delta, -out$delta)
  out$rater_dependent <- out$advantage >= flag_delta
  out$direction <- ifelse(!out$rater_dependent, NA_character_,
                          ifelse(out$pass_observed, "lenient_panel_pass", "harsh_panel_fail"))
  structure(out, class = c("df_counterfactual", "data.frame"),
            cut = cut, theta_mode = theta, design = design, n_panels = n_panels,
            enumerated = enumerated,
            internals = list(pts = pts, W = W, C_obs = C_obs, obs_index = obs_index,
                             groups = groups,
                             known_truth = inherits(object, "df_sim") && theta == "point"))
}

# One random assignment of examiners to items: for each item, an examiner who
# scored that item, avoiding examiners already used for this candidate when
# an alternative exists.
draw_assignment <- function(items, eligible) {
  used <- character(0)
  rater <- character(length(items))
  for (k in sample(seq_along(items))) {
    pool <- eligible[[items[k]]]
    fresh <- setdiff(pool, used)
    cand <- if (length(fresh)) fresh else pool
    rater[k] <- if (length(cand) == 1) cand else sample(cand, 1)
    used <- c(used, rater[k])
  }
  data.frame(item = items, rater = rater, stringsAsFactors = FALSE)
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
  # Subsetting (e.g. head(), x[rows, ]) drops the attributes; print the rows plainly.
  if (is.null(cut)) {
    print(as.data.frame(unclass(x)), ...)
    return(invisible(x))
  }
  what <- if (identical(attr(x, "design"), "assignment")) "assignments" else "panels"
  cat("<df_counterfactual> rule =", cut$decision_rule, "| cut =", cut$value,
      "| theta =", attr(x, "theta_mode"), "|", attr(x, "n_panels"),
      if (isTRUE(attr(x, "enumerated"))) paste(what, "(all)") else paste(what, "(sampled)"), "\n")
  cat(sum(x$rater_dependent), "of", nrow(x), "candidates flagged as rater-dependent\n\n")
  top <- as.data.frame(x[order(-x$advantage), ][seq_len(min(n, nrow(x))), ])
  long <- nchar(top$panel) > 30
  top$panel[long] <- paste0(substr(top$panel[long], 1, 27), "...")
  print(format(top, digits = 3), row.names = FALSE)
  invisible(x)
}
