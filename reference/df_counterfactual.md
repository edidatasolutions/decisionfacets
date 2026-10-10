# Counterfactual pass probabilities: would this candidate have passed with different raters?

For each candidate, computes the probability of passing a re-rating
under (a) the observed raters, (b) raters of average severity, and (c)
raters drawn at random from the pool, all under the same decision rule.

## Usage

``` r
df_counterfactual(
  object,
  cut,
  theta = c("auto", "posterior", "point"),
  max_panels = 2000,
  flag_delta = 0.2,
  grid = NULL,
  prior_mean = NULL,
  prior_sd = NULL,
  seed = NULL
)
```

## Arguments

- object:

  A \`df_fit\` (estimated parameters) or \`df_sim\` (true parameters).

- cut:

  A \`df_cut\`.

- theta:

  How candidate ability enters: \`"posterior"\` integrates over the grid
  posterior given the candidate's observed ratings (the default for a
  \`df_fit\`, so probabilities include measurement error); \`"point"\`
  plugs in \`object\$par\$theta\` (the default for a \`df_sim\`, giving
  the known truth).

- max_panels:

  Enumerate all rater panels when there are at most this many; otherwise
  sample this many panels or assignments.

- flag_delta:

  Minimum rater advantage (see below) for a flag.

- grid:

  Theta grid for the posterior. Defaults to \`seq(-6, 6, by = 0.1)\` for
  ordinal scores and a grid spanning six prior SDs for continuous
  scores.

- prior_mean, prior_sd:

  Normal prior for the posterior; default to the fitted population prior
  when the fit supplies one (\`par\$theta_prior\`), otherwise the mean
  and SD of the person estimates.

- seed:

  Optional seed for panel sampling.

## Value

A \`df_counterfactual\` data frame, one row per candidate: \`person\`,
\`panel\`, \`total\`, \`raw_cut\`, \`pass_observed\` (actual decision),
\`p_observed\`, \`p_average\`, \`p_random\`, \`p_min\`, \`p_max\` (worst
and best panel in the pool or among sampled assignments), \`delta\` (=
p_observed - p_random), \`advantage\`, \`direction\` and
\`rater_dependent\`.

\`advantage\` is how much the assigned panel pushed the candidate toward
the outcome they actually received: \`delta\` for a pass, \`-delta\` for
a fail. Equivalently, it is the increase in the probability that a
re-rating would reverse the decision when the observed panel is swapped
for a random one; decision reversals from measurement error alone cancel
out. \`rater_dependent\` is \`advantage \>= flag_delta\`, and
\`direction\` labels flagged cases \`"lenient_panel_pass"\` (board's
false-pass exposure) or \`"harsh_panel_fail"\` (the appeal case).

## Details

Two scoring designs are supported:

- crossed:

  Every rater on a candidate's panel scores every item. The random panel
  is a random set of raters from the pool, enumerated when feasible.

- assignment:

  Any other pattern, typically one examiner per case. The random
  assignment draws, for each of the candidate's items, an examiner at
  random from those who scored that item, without reusing an examiner
  for the same candidate when an alternative exists. Assignments are
  sampled.

Probabilities are exact given an assignment (recursive convolution for
ordinal scores, the normal distribution for continuous scores); the only
approximation is sampling assignments when they cannot be enumerated.

## Examples

``` r
sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
fit <- df_fit(sim$data, engine = "jmle")
cf <- df_counterfactual(fit, df_cut(12, "raw_total"))
cf                 # most rater-dependent candidates first
#> <df_counterfactual> rule = raw_total | cut = 12 | theta = posterior | 15 panels (all) 
#> 36 of 200 candidates flagged as rater-dependent
#> 
#>  person   panel total raw_cut pass_observed p_observed p_average p_random
#>   P0124 R01|R02    13      12          TRUE     0.7451     0.218    0.281
#>   P0116 R01|R02    15      12          TRUE     0.9042     0.452    0.464
#>   P0069 R02|R06    13      12          TRUE     0.7389     0.292    0.341
#>   P0156 R02|R06    13      12          TRUE     0.7389     0.292    0.341
#>   P0119 R03|R05     9      12         FALSE     0.1838     0.600    0.574
#>   P0173 R01|R02    16      12          TRUE     0.9489     0.586    0.565
#>   P0075 R02|R06    12      12          TRUE     0.6241     0.191    0.257
#>   P0057 R02|R05    13      12          TRUE     0.7339     0.363    0.396
#>   P0170 R03|R04     7      12         FALSE     0.0583     0.355    0.388
#>   P0073 R03|R06    10      12         FALSE     0.2889     0.650    0.613
#>   p_min p_max  delta advantage rater_dependent          direction
#>  0.0237 0.745  0.464     0.464            TRUE lenient_panel_pass
#>  0.0931 0.904  0.441     0.441            TRUE lenient_panel_pass
#>  0.0400 0.812  0.398     0.398            TRUE lenient_panel_pass
#>  0.0400 0.812  0.398     0.398            TRUE lenient_panel_pass
#>  0.1684 0.952 -0.391     0.391            TRUE   harsh_panel_fail
#>  0.1635 0.949  0.384     0.384            TRUE lenient_panel_pass
#>  0.0188 0.712  0.367     0.367            TRUE lenient_panel_pass
#>  0.0604 0.858  0.338     0.338            TRUE lenient_panel_pass
#>  0.0583 0.846 -0.329     0.329            TRUE   harsh_panel_fail
#>  0.2026 0.964 -0.324     0.324            TRUE   harsh_panel_fail
summary(cf)
#>   decision_rule cut   n pass_rate_observed expected_pass_rate_random_panel
#> 1     raw_total  12 200               0.57                       0.5535833
#>   mean_abs_delta n_rater_dependent n_lenient_panel_pass n_harsh_panel_fail
#> 1      0.1179387                36                   22                 14
#>   n_panel_sensitive
#> 1               107
# Known truth: the same analysis with the true parameters
summary(df_counterfactual(sim, df_cut(12, "raw_total")))
#>   decision_rule cut   n pass_rate_observed expected_pass_rate_random_panel
#> 1     raw_total  12 200               0.57                         0.53669
#>   mean_abs_delta n_rater_dependent n_lenient_panel_pass n_harsh_panel_fail
#> 1      0.1294924                40                   21                 19
#>   n_panel_sensitive
#> 1               118

# One examiner per case, continuous 0-100 scores
oral <- df_simulate(n_persons = 150, n_items = 6, n_raters = 18,
                    design = "per_item", raters_per_item = 6,
                    scale = "continuous", seed = 2)
summary(df_counterfactual(oral, df_cut(70, "raw_mean"), seed = 1))
#>   decision_rule cut   n pass_rate_observed expected_pass_rate_random_panel
#> 1      raw_mean  70 150          0.5533333                       0.5121212
#>   mean_abs_delta n_rater_dependent n_lenient_panel_pass n_harsh_panel_fail
#> 1     0.04193911                 4                    1                  3
#>   n_panel_sensitive
#> 1                39
```
