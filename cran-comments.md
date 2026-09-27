## Submission

This is the first submission of decisionfacets.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release, oldrel-1)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Notes for the reviewer

* 'TAM' is in Suggests. It is used only when `df_fit(engine = "tam")` is requested
  or TAM is installed; otherwise a built-in estimator is used. The example that
  uses TAM is wrapped in `\donttest{}` and guarded by `requireNamespace()`.
* Longer known-truth validation scripts are in `inst/validation/` and are not
  run during checks.
