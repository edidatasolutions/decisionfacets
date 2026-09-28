# Contributing to decisionfacets

Thank you for your interest in decisionfacets. Bug reports, questions,
suggestions and code contributions are all welcome.

## Getting help

- Start with the documentation: the package website
  (<https://edidatasolutions.github.io/decisionfacets/>), the vignette
  ([`vignette("decisionfacets")`](https://edidatasolutions.github.io/decisionfacets/articles/decisionfacets.md))
  and the help pages (`?df_...`).
- For questions about using the package, open an issue at
  <https://github.com/edidatasolutions/decisionfacets/issues> and
  describe what you are trying to do.

## Reporting a bug

Please open an issue at
<https://github.com/edidatasolutions/decisionfacets/issues> with:

1.  A short description of the problem and what you expected instead.
2.  A **minimal reproducible example**. The package’s simulation
    function
    ([`df_simulate()`](https://edidatasolutions.github.io/decisionfacets/reference/df_simulate.md))
    is usually the easiest way to create example data without sharing
    real examinee records.
3.  The output of
    [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).

**Never post real candidate, examinee or item data in an issue.** If a
problem only appears with confidential data, describe it in general
terms, or email the maintainer (address in the `DESCRIPTION` file) to
discuss how to share it safely.

## Suggesting a feature

Open an issue describing the use case (the measurement problem you need
to solve), not only the proposed function. Methodological suggestions
with references are especially welcome.

## Contributing code

1.  Open an issue first to discuss the change, unless it is a small fix
    (typos, documentation).
2.  Fork the repository and create a branch for your change.
3.  Follow the existing style: base R in `Imports`, the `df_` function
    prefix, roxygen2 documentation with runnable `@examples`.
4.  Add or update tests in `tests/test-core.R`. New statistical methods
    should come with a known-truth check (simulate from the model,
    recover the truth); see `inst/validation/` for the pattern used
    throughout the package.
5.  Run `R CMD check` (for example `devtools::check()`) and make sure it
    passes with no errors or warnings.
6.  Open a pull request describing what changed and why. The automated
    checks run on Windows, macOS and Linux.

## Code of conduct

Please be respectful and constructive. Harassment or personal attacks
are not tolerated in issues, pull requests or any other project space.
