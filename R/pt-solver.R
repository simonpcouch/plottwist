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
    inject <- input$inject[[1]]

    solver_dir <- prepare_solver_directory(data_file)
    old_wd <- setwd(solver_dir)
    on.exit(setwd(old_wd), add = TRUE)

    agent <- random_agent(solver_chat)
    sample_env <- new.env(parent = .GlobalEnv)
    retarget_r_tool(agent, sample_env)

    for (j in seq_along(turns)) {
      # inject synthetic tool call between turns when specified
      if (!is.null(inject) && j == inject$after_turn + 1L) {
        run_injection(agent, inject, sample_env)
      }

      prompt <- sample(turns[[j]], 1)
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

# Replaces the R tool so it evaluates in `env` instead of .GlobalEnv.
retarget_r_tool <- function(agent, env) {
  tools <- agent$get_tools()
  r_aliases <- unname(unlist(tool_name_aliases["btw_tool_run_r"]))

  for (i in seq_along(tools)) {
    if (tools[[i]]@name %in% r_aliases) {
      orig <- tools[[i]]
      tools[[i]] <- ellmer::tool(
        function(code) btw:::btw_tool_run_r_impl(code, .envir = env),
        name = orig@name,
        description = orig@description,
        arguments = list(code = orig@arguments@properties$code),
        annotations = orig@annotations
      )
      break
    }
  }

  agent$set_tools(tools)
}

# Injects a synthetic tool-call turn into the chat. Runs the inject code
# to produce a plot, then uses chat_inject() to splice a fake user request,
# assistant tool call, and tool result (with the rendered image) into history.
run_injection <- function(agent, inject, env) {
  # find the R tool name this agent is using
  tools <- agent$get_tools()
  r_tool_name <- NULL
  for (t in tools) {
    if (t@name %in% unname(unlist(tool_name_aliases["btw_tool_run_r"]))) {
      r_tool_name <- t@name
      break
    }
  }
  r_tool_name <- r_tool_name %||% "run_r"

  # resolve the placeholder variable name in the inject code to whatever
  # the model actually called the data frame
  resolved <- resolve_data_var(inject$code, inject$detect_col, env)
  code <- resolved$code

  # render the plot in the sample's env
  plot_image <- render_inject_plot(code, env)

  # build the three turns for chat_inject()
  user_prompt <- sample(inject$prompt, 1)
  user <- ellmer::UserTurn(list(ellmer::ContentText(user_prompt)))

  call_id <- paste0("inject_", sample(1e6, 1))
  request <- ellmer::ContentToolRequest(
    id = call_id,
    name = r_tool_name,
    arguments = list(code = code)
  )
  assistant <- ellmer::AssistantTurn(list(request))

  value <- if (!is.null(plot_image)) {
    list(plot_image)
  } else {
    "Plot rendering failed."
  }
  result <- ellmer::ContentToolResult(
    value = value,
    request = request
  )
  user2 <- ellmer::UserTurn(list(result))

  chat_inject(agent, user, assistant, user2)
}

# Scans an environment for a data frame containing `detect_col` and replaces
# the `<data_var>` placeholder in inject code with the actual variable name.
resolve_data_var <- function(code, detect_col, env) {
  if (is.null(detect_col) || !grepl("<data_var>", code, fixed = TRUE)) {
    return(list(code = code))
  }

  for (name in ls(env)) {
    obj <- get(name, env)
    if (is.data.frame(obj) && detect_col %in% names(obj)) {
      return(list(code = gsub("<data_var>", name, code, fixed = TRUE)))
    }
  }

  cli::cli_warn("Could not find a data frame with column {.val {detect_col}}.")
  list(code = code)
}

# Evaluates inject code in the sample's environment and renders the
# resulting ggplot to an image.
render_inject_plot <- function(code, env) {
  result <- tryCatch(
    eval(parse(text = code), envir = env),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    cli::cli_warn("Inject code failed: {conditionMessage(result)}")
    return(NULL)
  }

  if (!inherits(result, "ggplot")) {
    cli::cli_warn("Inject code did not return a ggplot object.")
    return(NULL)
  }

  temp_file <- tempfile(fileext = ".png")
  tryCatch(
    ggplot2::ggsave(temp_file, plot = result, width = 7, height = 5, dpi = 150),
    error = function(e) {
      cli::cli_warn("Inject plot rendering failed: {conditionMessage(e)}")
      return(NULL)
    }
  )

  ellmer::content_image_file(temp_file)
}

# Creates a temporary directory containing the sample's data file.
prepare_solver_directory <- function(data_file) {
  solver_dir <- tempfile(pattern = "plottwist_")
  dir.create(solver_dir)
  src <- system.file(data_file, package = "plottwist")
  file.copy(src, file.path(solver_dir, basename(data_file)))
  solver_dir
}
