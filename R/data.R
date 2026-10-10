#' Standardize rater-mediated score data
#'
#' @param x A data frame in long format, one row per person x item x rater score.
#' @param person,item,rater,score Column names in `x`.
#' @param scale `"ordinal"` for rating categories (integers, analyzed with the
#'   many-facet Rasch rating scale model), `"continuous"` for scores such as
#'   0-100 (analyzed with the linear many-facet model), or `"auto"`: continuous
#'   when scores are not all integers or take more than 20 distinct values.
#' @return A `df_data` data frame with character ids and scores. Ordinal scores
#'   are 0-based integers and attribute `K` is the highest category;
#'   continuous scores are kept as they are. Attribute `scale` records the
#'   choice.
#' @examples
#' raw <- data.frame(cand = c("A", "A", "B", "B"), task = "T1",
#'                   examiner = c("R1", "R2", "R1", "R2"), rating = c(3, 4, 2, 2))
#' df_data(raw, person = "cand", item = "task", rater = "examiner", score = "rating")
#'
#' # Scores on a 0-100 scale
#' pct <- data.frame(cand = c("A", "B", "C"), case = "C1", examiner = "E1",
#'                   score = c(72.5, 64, 88))
#' df_data(pct, person = "cand", item = "case", rater = "examiner",
#'         scale = "continuous")
#' @export
df_data <- function(x, person = "person", item = "item", rater = "rater",
                    score = "score", scale = c("auto", "ordinal", "continuous")) {
  scale <- match.arg(scale)
  out <- data.frame(
    person = as.character(x[[person]]),
    item   = as.character(x[[item]]),
    rater  = as.character(x[[rater]]),
    score  = as.numeric(x[[score]]),
    stringsAsFactors = FALSE
  )
  if (anyNA(out)) stop("Missing values are not supported yet; drop unscored cells.")
  if (anyDuplicated(out[c("person", "item", "rater")]))
    stop("Duplicate person x item x rater rows.")
  integer_scores <- all(out$score == round(out$score))
  if (scale == "auto") {
    scale <- if (!integer_scores || length(unique(out$score)) > 20) "continuous" else "ordinal"
    if (scale == "continuous")
      message("Treating scores as continuous (", length(unique(out$score)),
              " distinct values); use scale = 'ordinal' for rating categories.")
  }
  if (scale == "continuous")
    return(structure(out, class = c("df_data", "data.frame"), scale = "continuous", K = NA))

  if (!integer_scores) stop("Ordinal scores must be integers; use scale = 'continuous'.")
  out$score <- as.integer(out$score)
  if (min(out$score) > 0) {
    message("Shifting scores so the lowest category is 0 (was ", min(out$score), ").")
    out$score <- out$score - min(out$score)
  }
  K <- max(out$score)
  missing_cat <- setdiff(0:K, out$score)
  if (length(missing_cat))
    warning("Unobserved categories: ", paste(missing_cat, collapse = ", "),
            ". Thresholds adjacent to them are poorly determined.")
  structure(out, class = c("df_data", "data.frame"), scale = "ordinal", K = K)
}
