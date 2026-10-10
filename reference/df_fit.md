# Fit a many-facet measurement model

Ordinal scores are fitted with the many-facet Rasch rating scale model;
continuous scores (see \[df_data()\]) with the linear many-facet model
\`score = theta - delta - lambda + error\`, \`error ~ N(0, sigma^2)\`.

## Usage

``` r
df_fit(data, engine = NULL, max_iter = 1000, tol = NULL)
```

## Arguments

- data:

  A \`df_data\` object.

- engine:

  For ordinal scores: \`"tam"\` (marginal ML via \`TAM::tam.mml.mfr\`,
  the default when TAM is installed) or \`"jmle"\` (built-in joint
  maximum likelihood, the FACETS approach). For continuous scores:
  \`"linear"\` (least squares; the only option).

- max_iter, tol:

  Convergence controls; \`tol = NULL\` uses each engine's default (1e-4
  for TAM, 1e-6 for JMLE and linear).

## Value

A \`df_fit\` object: \`\$data\`, \`\$par\` (named \`theta\`, \`delta\`,
\`lambda\`, and \`tau\` for ordinal or \`sigma\` and \`model =
"linear"\` for continuous scores; for TAM and linear also
\`theta_prior\`, the population mean and SD), \`\$engine\`,
\`\$converged\`, \`\$iterations\`, and for TAM the fitted \`\$model\`.

## Details

All engines report item difficulties and rater severities centered at 0.
Ordinal person measures are on the logit scale (EAPs for TAM);
continuous person measures are on the score scale, so a measure is the
expected rating from an average-severity rater on an average item.

The rating network must be connected: every rater must be linked to
every other through shared candidates and items, or severities are not
comparable. \`df_fit()\` stops when it is not.

JMLE person measures are clamped to \[-7, 7\], so extreme scores get a
finite but arbitrary measure. JMLE's known small-sample spread inflation
is not corrected. The linear model ignores the bounds of the score scale
(e.g. 0 and 100), which matters only when many ratings sit at a bound.

## Examples

``` r
sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
fit <- df_fit(sim$data, engine = "jmle")
cor(fit$par$lambda, sim$par$lambda[names(fit$par$lambda)])
#> [1] 0.9958962
# \donttest{
if (requireNamespace("TAM", quietly = TRUE)) {
  fit_tam <- df_fit(sim$data, engine = "tam")
  fit_tam$par$tau
}
#> [1] -1.6106372 -0.5208191  0.5767848  1.5546715
# }
```
