#' Plottwist dataset
#'
#' @description
#' The plottwist dataset contains samples for evaluating language models' ability
#' to detect issues in messy data when plotting. Each sample defines a multi-turn
#' conversation where the model loads a dataset, answers a warm-up question, and
#' then creates a plot that reveals a data quality issue.
#'
#' The dataset is a tibble with one row per sample, containing:
#' * `id`: Unique identifier for the sample.
#' * `input`: A list-column where each element is a tibble with:
#'   - `turns`: A list of character vectors. Each character vector contains
#'     alternative phrasings for a single user turn; one is chosen at random
#'     per evaluation run.
#'   - `data_file`: Path to the data file, relative to
#'     `system.file(package = "plottwist")`.
#' * `target`: Description of the data issue the model should detect.
#'
#' @format A tibble with columns `id`, `input`, and `target`.
#'
#' @examples
#' pt_dataset
#'
#' # View the input for the first sample
#' pt_dataset$input[[1]]
#'
"pt_dataset"
