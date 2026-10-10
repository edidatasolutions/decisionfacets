# decisionfacets

[![CRAN status](https://www.r-pkg.org/badges/version/decisionfacets)](https://CRAN.R-project.org/package=decisionfacets)

**Would this candidate have passed with a different set of raters?**

Decision accuracy and consistency for rater-mediated exams (oral exams, OSCEs,
essay and constructed-response scoring), built on the many-facet Rasch rating
scale model for rating categories and, in the development version, a linear
many-facet model for continuous scores such as 0-100.

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

### Oral examinations: one examiner per case, scores 0-100 (development version)

Many oral certification exams score each case with a different examiner on a
0-100 scale. The development version handles that design directly:

```r
d   <- df_data(oral_exam, person = "candidate", item = "case",
               rater = "examiner", scale = "continuous")  # synthetic example data
fit <- df_fit(d)                                         # linear many-facet model
cf  <- df_counterfactual(fit, df_cut(70, "raw_mean"))    # pass if the mean score reaches 70
cf
df_attribute(cf)
```

Each counterfactual reassignment draws, for every case, an examiner qualified
for that case, never the same examiner twice for one candidate. `oral_exam` is
fully synthetic: 300 candidates, 12 cases, 48 examiners.

## Installation

From CRAN:

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
| `raw_total`, `raw_mean` | yes, directly |
| `fair_average`, `measure` | no; only through measurement precision |

Internally every rule reduces to a raw-total cut that depends on the panel
(harsher panels get lower cuts under measure-based rules), so pass
probabilities are computed exactly: by convolving category probabilities for
rating categories, and from the normal distribution for continuous scores.

## Scoring designs

| design | example | counterfactual panel |
|---|---|---|
| crossed | 2 raters score all 4 tasks for each candidate | a random set of raters from the pool (enumerated when feasible) |
| one examiner per case *(development version)* | each of 12 oral cases is scored by a different examiner | for each case, a random examiner qualified for that case |

`df_fit()` stops if the rating network is disconnected, because examiner
severities would then not be on a common scale.

## What each candidate gets

`df_counterfactual()` returns pass probabilities under the observed panel, an
average-severity panel, and a random panel from the pool (enumerated when
feasible), plus the best and worst panel. `advantage` is how far the assigned
panel pushed the candidate toward the outcome they received; candidates with
`advantage >= 0.2` are flagged `lenient_panel_pass` or `harsh_panel_fail`.

`df_attribute()` splits expected misclassifications into measurement error
(present even with average raters), rater assignment (observed minus average),
and the expected cost of the random assignment design.

## Validation (known truth, 100 replications)

1,000 candidates, 4 items, 12 raters (severity SD 0.6), 2 raters per candidate,
cut = mean rating of 2. Means over 100 replications:

- Raw totals: 176 truly rater-dependent candidates per 1,000. TAM flags 169,
  recovering 71% of true flags (75% of TAM's flags are real). An oracle with
  the true parameters also recovers 71%, so the remaining gap is measurement
  error from 8 ratings per candidate, not estimation error.
- Expected misclassifications per 1,000: 160 under raw totals (116 measurement,
  44 rater assignment) versus 117 under the measure rule (assignment about 1).
  TAM estimates: 160 / 116 / 44. Realized errors in the simulation: 160.
- Under measure-based and fair-average rules, no candidate is flagged as
  rater-dependent.

### One examiner per case, scores 0-100 (development version)

400 candidates; 6 or 12 cases each, scored by one examiner per case; examiner
severity SD 2, 4 or 6 score points; 4 or 10 qualified examiners per case;
residual SD 8; pass if the mean score reaches 70. 50 replications per
condition (600 data sets; `inst/validation/assignment_study.R`):

| examiner severity SD | examiner-dependent candidates | share of misclassifications due to examiners | true flags recovered from estimates |
|---|---|---|---|
| 2 points | under 0.2% | 2% | (too few to judge) |
| 4 points | 2-4% | 7-9% | 31-38% |
| 6 points | 5-10% | 13-14% | 50-58% |

- Severity spread drives everything (it explains 70% of the variance in the
  number of examiner-dependent candidates). Twelve cases dilute examiner
  effects more than six, so fewer candidates depend on their examiners.
- Examiner severities are recovered with correlation 0.84-0.99 (lowest when
  examiners barely differ) and RMSE of about 1 point; the residual SD is
  estimated at 7.9 (true 8).
- Expected misclassifications are calibrated: they differ from those that
  actually occurred by -0.3 per data set on average, and the estimated
  examiner component is within 0.2 of the truth.
- Severity-adjusted scoring (`measure`, `fair_average`) removes examiner
  dependence entirely.
- Individual flags are harder than in two-rater panels: with many examiners
  per candidate the examiner effect on any one decision is small relative to
  measurement error, so estimates find 31-58% of truly examiner-dependent
  candidates, and 60-71% of their flags are correct. The program-level
  decomposition remains accurate.

## Status

| layer | functions | status |
|---|---|---|
| data / model | `df_data`, `df_fit` (TAM, JMLE; linear for continuous scores), `df_rater_effects` | done |
| decision | `df_cut` (incl. `raw_mean`), `df_classify` | done |
| flagship | `df_counterfactual`, `df_attribute` (severity) | done |
| forward-looking | `df_simulate` done; `df_design`, `df_evaluate_design` | stubs |
| monitoring / output | `df_drift`, `df_report` | stubs |

Current limits: crossed designs need equal panel sizes; no missing ratings
within a candidate's assignment; severity only (no halo or drift terms); the
continuous model uses a single residual SD for all examiners and ignores the
bounds of the score scale. With few ratings per person, JMLE stretches the
logit scale (~15% in validation); prefer TAM.

## Getting help and contributing

Questions and bug reports: https://github.com/edidatasolutions/decisionfacets/issues. See
[CONTRIBUTING.md](.github/CONTRIBUTING.md) for how to report problems, get
help, or contribute code.
