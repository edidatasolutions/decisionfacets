# Fit a many-facet Rasch rating scale model

Fit a many-facet Rasch rating scale model

## Usage

``` r
df_fit(data, engine = NULL, max_iter = 1000, tol = NULL)
```

## Arguments

- data:

  A \`df_data\` object.

- engine:

  \`"tam"\` (marginal ML via \`TAM::tam.mml.mfr\`, the default when TAM
  is installed) or \`"jmle"\` (built-in joint maximum likelihood, the
  FACETS approach).

- max_iter, tol:

  Convergence controls; \`tol = NULL\` uses each engine's default (1e-4
  for TAM, 1e-6 for JMLE).

## Value

A \`df_fit\` object: \`\$data\`, \`\$par\` (named \`theta\`, \`delta\`,
\`lambda\`, \`tau\`; for TAM also \`theta_prior\`, the fitted population
mean and SD), \`\$engine\`, \`\$converged\`, \`\$iterations\`, and for
TAM the fitted \`\$model\`.

## Details

Both engines report parameters in the same parameterization: item
difficulties and rater severities centered at 0, thresholds centered at
0, and person measures on the resulting logit scale. For TAM,
\`par\$theta\` holds EAPs.

JMLE person measures are clamped to \[-7, 7\], so extreme scores get a
finite but arbitrary measure. JMLE's known small-sample spread inflation
is not corrected.

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
