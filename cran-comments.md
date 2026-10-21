## Submission

This is an update of decisionfacets (0.1.0 -> 0.2.0).

It adds support for oral examinations in which each case is scored by a
different examiner, and for continuous scores such as 0-100 through a linear
many-facet model (new `df_data(scale = )`, `df_fit(engine = "linear")`,
`df_simulate(design = "per_item", scale = "continuous")`), a mean-score
decision rule (`df_cut(value, "raw_mean")`), a check that the rating network
is connected, and a small synthetic data set, `oral_exam`. Results for the
existing designs are unchanged. Details are in NEWS.md.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release, oldrel-1)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

* Timing of this update: this release adds the examination design that oral
  certification examinations commonly use (one examiner per case, 0-100
  scores), which the first release could not analyze.
* "Andrich" (flagged as possibly misspelled) is the author of the cited
  reference (Andrich, 1978).

## Reverse dependencies

There are no reverse dependencies.

## Notes for the reviewer

* 'TAM' is in Suggests. It is used only when `df_fit(engine = "tam")` is requested or TAM is installed; otherwise a built-in estimator is used. The example that uses TAM is wrapped in `\donttest{}` and guarded by `requireNamespace()`.
* `oral_exam` is fully synthetic; the script that generates it is in the source repository (`data-raw/`, excluded from the build).
* Longer known-truth validation scripts are in `inst/validation/` and are not run during checks.
