# decisionfacets

**Would this candidate have passed with a different set of raters?**

Decision accuracy and consistency for rater-mediated exams (oral exams, OSCEs,
essay and constructed-response scoring), built on the many-facet Rasch rating
scale model.

```r
library(decisionfacets)

sim <- df_simulate(n_persons = 1000, n_items = 4, n_raters = 12,
                   raters_per_person = 2, severity_sd = 0.6, seed = 1)
fit <- df_fit(sim$data)                      # TAM if installed, else built-in JMLE

cut <- df_cut(16, decision_rule = "raw_total")
cf  <- df_counterfactual(fit, cut)           # per-candidate pass probabilities
cf                                           # most rater-dependent candidates first
df_attribute(cf)                             # measurement error vs rater assignment
```

## Installation

From CRAN (once released):

```r
install.packages("decisionfacets")
```

Development version from GitHub:

```r
install.packages("pak")
pak::pak("edidatasolutions/decisionfacets")
```

## The decision rule is the point

How much rater severity harms a candidate depends on what the board decides on:

| `decision_rule` | severity reaches the decision? |
|---|---|
| `raw_total` | yes, directly |
| `fair_average`, `measure` | no; only through measurement precision |

Internally every rule reduces to a raw-total cut that depends on the panel
(harsher panels get lower cuts under measure-based rules), so pass
probabilities are computed exactly by convolving category probabilities.

## What each candidate gets

`df_counterfactual()` returns pass probabilities under the observed panel, an
average-severity panel, and a random panel from the pool (enumerated when
feasible), plus the best and worst panel. `advantage` is how far the assigned
panel pushed the candidate toward the outcome they received; candidates with
`advantage >= 0.2` are flagged `lenient_panel_pass` or `harsh_panel_fail`.

`df_attribute()` splits expected misclassifications into measurement error
(present even with average raters), rater assignment (observed minus average),
and the expected cost of the random assignment design.

## Validation (known truth, `inst/validation/mvp_recovery.R`)

1,000 candidates, 4 items, 12 raters (severity SD 0.6), 2 raters per candidate,
cut = mean rating of 2:

- Raw totals: 147 truly rater-dependent candidates. TAM flags 140, recovering
  75% of true flags (79% of TAM's flags are real). An oracle with the true
  parameters recovers 76%, so the remaining gap is measurement error from 8
  ratings per candidate, not estimation error.
- Expected misclassifications per 1,000: 156 under raw totals (114 measurement,
  42 rater assignment) versus 116 under the measure rule (assignment about 2).
  TAM estimates: 157 / 119 / 39. Realized errors in the simulation: 147.

## Status

| layer | functions | status |
|---|---|---|
| data / model | `df_data`, `df_fit` (TAM, JMLE), `df_rater_effects` | done |
| decision | `df_cut`, `df_classify` | done |
| flagship | `df_counterfactual`, `df_attribute` (severity) | done |
| forward-looking | `df_simulate` done; `df_design`, `df_evaluate_design` | stubs |
| monitoring / output | `df_drift`, `df_report` | stubs |

Current design limits: every panel rater scores every item for a candidate,
panel sizes are equal, no missing ratings, severity only (no halo/drift terms).
With few ratings per person, JMLE stretches the logit scale (~16% in the tests);
prefer TAM.
