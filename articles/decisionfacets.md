# Would this candidate have passed with different raters?

Boards that run oral exams, OSCEs or essay-scored certifications must
defend individual pass/fail decisions. Rater severity is well studied;
what it *did* to decisions usually is not. decisionfacets answers that
question directly.

## A simulated administration

Every candidate is scored on four tasks by two raters drawn from a pool
of twelve whose severities differ. Because the data are simulated, the
true abilities and severities are known.

``` r

library(decisionfacets)
sim <- df_simulate(n_persons = 400, n_items = 4, n_raters = 12,
                   raters_per_person = 2, severity_sd = 0.6, seed = 2026)
head(sim$data)
#>   person item rater score
#> 1  P0001  I01   R07     4
#> 2  P0001  I02   R07     1
#> 3  P0001  I03   R07     2
#> 4  P0001  I04   R07     3
#> 5  P0001  I01   R04     1
#> 6  P0001  I02   R04     2
round(sim$par$lambda, 2)   # true rater severities (positive = harsher)
#>   R01   R02   R03   R04   R05   R06   R07   R08   R09   R10   R11   R12 
#> -0.57 -1.22  1.13  0.92  0.06 -0.87  0.29 -0.61  0.34  0.50  0.09 -0.06
```

## Fit the many-facet Rasch model

[`df_fit()`](https://edidatasolutions.github.io/decisionfacets/reference/df_fit.md)
uses ‘TAM’ when it is installed and a built-in joint maximum likelihood
estimator otherwise. We use the built-in one here so the vignette has no
dependencies.

``` r

fit <- df_fit(sim$data, engine = "jmle")
df_rater_effects(fit)
#>    rater    severity
#> 1    R01 -0.84684003
#> 2    R02 -1.39671568
#> 3    R03  1.47469290
#> 4    R04  1.17825056
#> 5    R05  0.13005088
#> 6    R06 -0.82904465
#> 7    R07  0.30772424
#> 8    R08 -0.81637738
#> 9    R09  0.55252850
#> 10   R10  0.61777896
#> 11   R11 -0.01314208
#> 12   R12 -0.35890621
```

## The decision rule is the point

The same substantive standard (an average rating of 2 per cell) can be
applied to raw totals or to severity-adjusted measures. Rater severity
reaches the decision only in the first case.

``` r

raw <- df_cut(2 * 4 * 2, "raw_total")
fa  <- df_cut(2, "fair_average")
```

## Counterfactual pass probabilities

For each candidate,
[`df_counterfactual()`](https://edidatasolutions.github.io/decisionfacets/reference/df_counterfactual.md)
gives the probability of passing a re-rating by the observed panel, by
an average-severity panel and by a random panel from the pool.
`advantage` is how far the assigned panel pushed the candidate toward
the outcome they received.

``` r

cf_raw <- df_counterfactual(fit, raw)
cf_raw
#> <df_counterfactual> rule = raw_total | cut = 16 | theta = posterior | 66 panels (all) 
#> 88 of 400 candidates flagged as rater-dependent
#> 
#>  person   panel total raw_cut pass_observed p_observed p_average p_random
#>   P0151 R03|R04    13      16         FALSE     0.1874    0.9253    0.844
#>   P0059 R03|R04    11      16         FALSE     0.0737    0.8044    0.729
#>   P0310 R03|R04    11      16         FALSE     0.0737    0.8044    0.729
#>   P0160 R03|R04    10      16         FALSE     0.0414    0.7110    0.656
#>   P0003 R01|R02    19      16          TRUE     0.8725    0.1980    0.285
#>   P0394 R03|R04    15      16         FALSE     0.3680    0.9777    0.920
#>   P0281 R03|R09    12      16         FALSE     0.1305    0.7363    0.674
#>   P0236 R03|R10    11      16         FALSE     0.0790    0.6529    0.613
#>   P0110 R02|R06    16      16          TRUE     0.6250    0.0487    0.127
#>   P0129 R04|R10    12      16         FALSE     0.1357    0.6806    0.633
#>     p_min p_max  delta advantage rater_dependent          direction
#>  1.87e-01 1.000 -0.657     0.657            TRUE   harsh_panel_fail
#>  7.37e-02 0.997 -0.655     0.655            TRUE   harsh_panel_fail
#>  7.37e-02 0.997 -0.655     0.655            TRUE   harsh_panel_fail
#>  4.14e-02 0.993 -0.615     0.615            TRUE   harsh_panel_fail
#>  8.39e-04 0.872  0.588     0.588            TRUE lenient_panel_pass
#>  3.68e-01 1.000 -0.552     0.552            TRUE   harsh_panel_fail
#>  4.60e-02 0.995 -0.544     0.544            TRUE   harsh_panel_fail
#>  2.79e-02 0.990 -0.534     0.534            TRUE   harsh_panel_fail
#>  3.73e-05 0.631  0.498     0.498            TRUE lenient_panel_pass
#>  3.18e-02 0.992 -0.497     0.497            TRUE   harsh_panel_fail
summary(cf_raw)
#>   decision_rule cut   n pass_rate_observed expected_pass_rate_random_panel
#> 1     raw_total  16 400                0.5                        0.527847
#>   mean_abs_delta n_rater_dependent n_lenient_panel_pass n_harsh_panel_fail
#> 1       0.142495                88                   35                 53
#>   n_panel_sensitive
#> 1               288
summary(df_counterfactual(fit, fa))
#>   decision_rule cut   n pass_rate_observed expected_pass_rate_random_panel
#> 1  fair_average   2 400              0.505                       0.5035176
#>   mean_abs_delta n_rater_dependent n_lenient_panel_pass n_harsh_panel_fail
#> 1      0.0133384                 0                    0                  0
#>   n_panel_sensitive
#> 1                 0
```

Under raw totals, a sizable share of candidates are rater-dependent;
under the fair average, essentially none are.

## Where do wrong decisions come from?

``` r

df_attribute(cf_raw)
#> <df_attribution> rule = raw_total | cut = 16 | standard at theta = 0.03 | n = 400 
#> 
#>  component                                        expected_count per_1000
#>  expected misclassifications (observed panels)    67.5           168.7   
#>    measurement error (average panel)              40.4           101.0   
#>    rater assignment, net (observed - average)     27.1            67.7   
#>      gross harm (panels that added error)         31.4            78.5   
#>      gross benefit (panels that removed error)    -4.3           -10.8   
#>    of which false passes                          36.0            89.9   
#>    of which false fails                           31.5            78.8   
#>  random-assignment design cost (random - average) 26.7            66.8
```

The decomposition separates error that no rater could remove
(measurement) from error added by the particular raters assigned, and
from the expected cost of random assignment.

## Checking against the truth

With the true parameters the same analysis gives the known answer, so
the estimates can be compared with it:

``` r

truth <- df_counterfactual(sim, raw)
cor(truth$advantage, cf_raw$advantage)
#> [1] 0.8805454
table(truth = truth$rater_dependent, estimated = cf_raw$rater_dependent)
#>        estimated
#> truth   FALSE TRUE
#>   FALSE   290   20
#>   TRUE     22   68
```
