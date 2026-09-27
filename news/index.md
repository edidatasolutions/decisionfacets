# Changelog

## decisionfacets 0.1.0

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
