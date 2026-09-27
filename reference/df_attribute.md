# Attribute misclassification to measurement error vs. rater assignment

A decision is a misclassification when it disagrees with the candidate's
standing against the intended standard, \`theta \>= theta_standard\`:
the measure-scale cut for measure-based rules, or for \`raw_total\` the
ability at which an average panel's expected total equals the raw cut.
For each candidate the probability of misclassification is computed
under three panels, and the expected number of wrong decisions is split
into:

- measurement:

  Error expected with an average-severity panel. It comes from having a
  finite number of ratings and no rater can remove it.

- assignment:

  Observed-panel error minus average-panel error: what the raters
  actually assigned added (or, if negative, removed). Reported net and
  as gross harm and gross benefit, because lenient raters can rescue a
  truly passing borderline candidate while wrongly passing another.

- design:

  Random-panel error minus average-panel error: what the random
  assignment design costs in expectation, before anyone is scored.
  \`df_design()\` will try to reduce this.

## Usage

``` r
df_attribute(counterfactual, components = "severity")
```

## Arguments

- counterfactual:

  A \`df_counterfactual\`.

- components:

  Rater effects to separate. Only \`"severity"\` is estimable from the
  current model (no halo or drift terms yet).

## Value

A \`df_attribution\` data frame, one row per candidate: \`person\`,
\`panel\`, \`pass_observed\`, \`p_true_pass\` (probability the candidate
truly meets the standard), \`err_observed\`, \`err_average\`,
\`err_random\`, \`assignment\` (= err_observed - err_average),
\`false_pass\` and \`false_fail\` (the two parts of err_observed), and
\`realized_error\` when the counterfactual was computed from known
truth. \`summary()\` gives the aggregate decomposition.

## Details

With estimated parameters, error probabilities integrate over each
candidate's ability posterior. Net components are well recovered in
simulation, but the gross harm/benefit split and the false-pass /
false-fail split are attenuated by posterior shrinkage; report them from
estimates with that caveat.

## Examples

``` r
sim <- df_simulate(n_persons = 200, n_items = 3, n_raters = 6, seed = 1)
cf <- df_counterfactual(sim, df_cut(12, "raw_total"))
df_attribute(cf)
#> <df_attribution> rule = raw_total | cut = 12 | standard at theta = 0.001 | n = 200 
#> 
#>  component                                        expected_count per_1000
#>  expected misclassifications (observed panels)    40.7           203.3   
#>    measurement error (average panel)              29.6           147.8   
#>    rater assignment, net (observed - average)     11.1            55.5   
#>      gross harm (panels that added error)         17.6            88.1   
#>      gross benefit (panels that removed error)    -6.5           -32.6   
#>    of which false passes                          28.1           140.6   
#>    of which false fails                           12.5            62.7   
#>  random-assignment design cost (random - average) 10.5            52.4   
#>  realized misclassifications (known truth)        40.0           200.0   
```
