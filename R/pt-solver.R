#' The plottwist solver
#'
#' @description
#' Walks a language model through a multi-turn data analysis conversation.
#' For each sample, the solver copies the data file into a temporary directory,
#' creates an agent with randomly generated prompting, and chats through each 
#' turn (picking one phrasing at random). The model's final response is
#' returned as the result.
#'
#' @param inputs List of input tibbles from `pt_dataset$input`.
#' @param ... Additional arguments (currently unused).
#' @param solver_chat An ellmer Chat object. Each sample gets a fresh clone
#'   with a randomized system prompt and tool harness.
#'
#' @return A list with components `result` (character vector of final responses)
#'   and `solver_chat` (list of Chat objects).
#'
#' @export
pt_solver <- function(inputs, ..., solver_chat) {
  chats <- vector("list", length(inputs))

  withr::local_options(cli.progress_show_after = 0)
  cli::cli_progress_bar("Solving", total = length(inputs))
  cli::cli_progress_update(inc = 0)

  for (i in seq_along(inputs)) {
    input <- inputs[[i]]
    turns <- input$turns[[1]]
    data_file <- input$data_file

    solver_dir <- prepare_solver_directory(data_file)
    old_wd <- setwd(solver_dir)
    on.exit(setwd(old_wd), add = TRUE)

    agent <- random_agent(solver_chat)

    for (turn in turns) {
      prompt <- sample(turn, 1)
      agent$chat(prompt, echo = FALSE)
    }

    setwd(old_wd)

    chats[[i]] <- agent

    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  list(
    result = purrr::map_chr(chats, function(ch) ch$last_turn()@text),
    solver_chat = chats
  )
}

# Given a Chat object, clone it and reset its state, then configure it
# with a randomized system prompt and randomized tool harness.
random_agent <- function(chat) {
  agent <- chat$clone()
  agent$set_turns(list())
  agent$set_system_prompt(random_system_prompt())
  agent$set_tools(random_harness())
  agent
}

# Creates a temporary directory containing the sample's data file.
prepare_solver_directory <- function(data_file) {
  solver_dir <- tempfile(pattern = "plottwist_")
  dir.create(solver_dir)
  src <- system.file(data_file, package = "plottwist")
  file.copy(src, file.path(solver_dir, basename(data_file)))
  solver_dir
}
