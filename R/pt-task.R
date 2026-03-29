#' The plottwist task
#'
#' Combines [pt_dataset], [pt_solver], and [pt_scorer] into a [vitals::Task]
#' for evaluating language models' ability to detect and fix data quality
#' issues that show up in plots.
#'
#' @param epochs Number of evaluation epochs to run. Default is 1.
#' @param dir Directory for logging evaluation results. Default is
#'   `vitals::vitals_log_dir()`.
#' @param samples Row indices from `pt_dataset` to evaluate. Default is
#'   all rows.
#'
#' @return A [vitals::Task] object. Call `$eval(solver_chat = chat)` to run
#'   the evaluation, where `chat` is an ellmer Chat object. The scorer uses
#'   Claude Sonnet 4.6 by default; pass `scorer_chat` to override.
#'
#' @seealso [pt_dataset], [pt_solver], [pt_scorer], [vitals::Task]
#'
#' @export
pt_task <- function(
    epochs = 1,
    dir = vitals::vitals_log_dir(),
    samples = seq_len(nrow(pt_dataset))
) {
  vitals::Task$new(
    dataset = pt_dataset[samples, ],
    solver = pt_solver,
    scorer = pt_scorer,
    epochs = epochs,
    name = "plottwist",
    dir = dir
  )
}
