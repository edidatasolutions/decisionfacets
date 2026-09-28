---
title: 'decisionfacets: Counterfactual pass probabilities for rater-mediated exams'
tags:
  - R
  - psychometrics
  - many-facet Rasch model
  - classification accuracy
  - licensure
authors:
  - name: Daniel Edi
    orcid: 0000-0001-5475-819X
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 27 September 2026
bibliography: paper.bib
---

<!-- DRAFT. Verify every reference and number before submission. Check the
journal's policy on disclosing AI-assisted software and writing. -->

# Summary

Oral examinations, objective structured clinical examinations and
essay-scored certifications rely on human raters who differ in severity. The
many-facet Rasch model [@linacre1989; @eckes2015] estimates those
differences, but boards must defend *decisions*, and the question they are
asked on appeal is whether a candidate would have passed with different
raters. `decisionfacets` answers it. For every candidate, it computes the
probability of passing a re-rating by the observed panel, by an
average-severity panel and by a random panel from the rater pool, under an
explicit decision rule (raw total, fair average or Rasch measure). It then
splits expected misclassification into measurement error and rater
assignment. Pass probabilities are exact, obtained by convolving the rating
scale model's [@andrich1978] category probabilities. Models are fitted with
'TAM' [@tam] or a built-in joint maximum likelihood estimator.

# Statement of need

R has mature many-facet Rasch estimation [@tam] and IRT-based
classification-accuracy methods [@rudner2001; @lee2010], but nothing connects
them to rater effects on individual decisions. Commercial facets software
reports rater severity, not its consequences for pass/fail outcomes. Boards
therefore defend decisions with ad hoc scripts. `decisionfacets` makes the
decision rule an explicit argument, because how much severity matters depends
on it: under raw-total scoring severity passes directly into decisions, while
under severity-adjusted measures it affects only precision. The package
serves licensure and certification programs and K-12 constructed-response
scoring.

# Validation

The package ships a known-truth validation (`inst/validation`). In a
simulation with 1,000 candidates, 12 raters of varying severity and two
raters per candidate, 14.7% of candidates were rater-dependent under
raw-total scoring and none under severity-adjusted scoring. Estimates from
'TAM' recovered the true flags as well as an oracle that knows the true item
and rater parameters (75% vs 76% of true flags). The attribution of expected
misclassification (156 per 1,000; 114 measurement, 42 rater assignment)
matched the truth.

# Acknowledgements

Software development and drafting were assisted by Claude (Anthropic). The author designed the methods, reviewed and validated all code and results, and takes full responsibility for the content.

# References
