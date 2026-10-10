# Changelog

## decisionfacets (development version)

- Designs with one examiner per case (or any partially overlapping
  rating design) are now supported.
  [`df_counterfactual()`](https://edidatasolutions.github.io/decisionfacets/reference/df_counterfactual.md)
  compares each candidate’s observed examiners with random reassignments
  that draw, for each case, an examiner qualified for that case, without
  repeating an examiner for the same candidate.
  [`df_simulate()`](https://edidatasolutions.github.io/decisionfacets/reference/df_simulate.md)
  gains `design = "per_item"` and `raters_per_item`.
- Continuous scores (for example 0-100) are supported through a linear
  many-facet model,
  `score = ability - case difficulty - examiner severity + error`.
  [`df_data()`](https://edidatasolutions.github.io/decisionfacets/reference/df_data.md)
  gains `scale = c("auto", "ordinal", "continuous")`;
  [`df_fit()`](https://edidatasolutions.github.io/decisionfacets/reference/df_fit.md)
  uses the new `"linear"` engine for continuous scores;
  [`df_simulate()`](https://edidatasolutions.github.io/decisionfacets/reference/df_simulate.md)
  gains `scale = "continuous"`.
- New decision rule `df_cut(value, "raw_mean")`: pass if the mean
  observed rating reaches `value` (e.g. 70), convenient when candidates
  have different numbers of ratings.
- [`df_fit()`](https://edidatasolutions.github.io/decisionfacets/reference/df_fit.md)
  stops with a clear message when the rating network is disconnected,
  because rater severities would then not be comparable.
- New synthetic data set `oral_exam`: 300 candidates, 12 cases, one
  examiner per case, 0-100 scores.
- Results for the existing crossed designs with ordinal scores are
  unchanged.

## decisionfacets 0.1.0

CRAN release: 2026-10-07

- Initial release.
- Many-facet Rasch rating scale model fitting via ‘TAM’ (marginal ML) or
  built-in JMLE
  ([`df_fit()`](https://edidatasolutions.github.io/decisionfacets/reference/df_fit.md)).
- Explicit decision rules: raw total, fair average, measure
  ([`df_cut()`](https://edidatasolutions.github.io/decisionfacets/reference/df_cut.md),
  [`df_classify()`](https://edidatasolutions.github.io/decisionfacets/reference/df_classify.md)).
- Counterfactual pass probabilities under observed, average and random
  rater panels, with rater-dependence flags
  ([`df_counterfactual()`](https://edidatasolutions.github.io/decisionfacets/reference/df_counterfactual.md)).
- Attribution of expected misclassification to measurement error and
  rater assignment
  ([`df_attribute()`](https://edidatasolutions.github.io/decisionfacets/reference/df_attribute.md)).
- Known-truth simulation
  ([`df_simulate()`](https://edidatasolutions.github.io/decisionfacets/reference/df_simulate.md)).
