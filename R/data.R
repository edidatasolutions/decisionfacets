#' Standardize rater-mediated score data
#'
#' @param x A data frame in long format, one row per person x item x rater score.
#' @param person,item,rater,score Column names in `x`.
#' @return A `df_data` data frame with character ids and 0-based integer scores;
#'   attribute `K` is the highest category.
#' @examples
#' raw <- data.frame(cand = c("A", "A", "B", "B"), task = "T1",
#'                   examiner = c("R1", "R2", "R1", "R2"), rating = c(3, 4, 2, 2))
#' df_data(raw, person = "cand", item = "task", rater = "examiner", score = "rating")
#' @export
df_data <- function(x, person = "person", item = "item", rater = "rater",
                    score = "score") {
  out <- data.frame(
    person = as.character(x[[person]]),
    item   = as.character(x[[item]]),
    rater  = as.character(x[[rater]]),
    score  = x[[score]],
    stringsAsFactors = FALSE
  )
  if (anyNA(out)) stop("Missing values are not supported yet; drop unscored cells.")
  if (any(out$score != round(out$score))) stop("Scores must be integers.")
  out$score <- as.integer(out$score)
  if (min(out$score) > 0) {
    message("Shifting scores so the lowest category is 0 (was ", min(out$score), ").")
    out$score <- out$score - min(out$score)
  }
  if (anyDuplicated(out[c("person", "item", "rater")]))
    stop("Duplicate person x item x rater rows.")
  K <- max(out$score)
  missing_cat <- setdiff(0:K, out$score)
  if (length(missing_cat))
    warning("Unobserved categories: ", paste(missing_cat, collapse = ", "),
            ". Thresholds adjacent to them are poorly determined.")
  structure(out, class = c("df_data", "data.frame"), K = K)
}
