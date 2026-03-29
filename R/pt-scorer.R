#' The plottwist scorer
#'
#' @description
#' Evaluates whether the model detected and fixed the data quality issue.
#'
#' The scorer applies deterministic checks before deferring to an LLM judge:
#' 1. Did the model call the R tool? If not, the sample is incorrect.
#' 2. Did at least one R tool call succeed? If not, incorrect.
#' 3. Did the model produce a plot (image content in the turns)? If not,
#'    incorrect.
#' 4. Otherwise, an LLM judge evaluates whether the model's response
#'    identifies and fixes the data issue described in `target`.
#'
#' @param samples The samples from a solver task, retrieved via
#'   `task$get_samples()`.
#' @param ... Additional arguments (currently unused).
#' @param scorer_chat An ellmer Chat object for the LLM judge.
#'
#' @return A list with `score` (ordered factor with levels `I` < `C`),
#'   `scorer_chat`, and `scorer_metadata`.
#'
#' @export
pt_scorer <- function(
    samples,
    ...,
    scorer_chat = ellmer::chat_anthropic(model = "claude-sonnet-4-6")
) {
  n <- nrow(samples)
  grades <- rep(NA_character_, n)
  explanations <- rep(NA_character_, n)

  # deterministic checks
  called_r <- purrr::map_lgl(samples$solver_chat, solver_called_r_tool)
  r_succeeded <- purrr::map_lgl(samples$solver_chat, solver_r_tool_succeeded)
  made_plot <- purrr::map_lgl(samples$solver_chat, solver_made_plot)

  grades[!called_r] <- "I"
  explanations[!called_r] <- "Model never called the R tool."

  grades[called_r & !r_succeeded] <- "I"
  explanations[called_r & !r_succeeded] <- "All R tool calls errored."

  grades[called_r & r_succeeded & !made_plot] <- "I"
  explanations[called_r & r_succeeded & !made_plot] <-
    "Model never produced a plot."

  # LLM judge for remaining samples
  needs_grading <- which(is.na(grades))
  scorer_chats <- vector("list", n)

  if (length(needs_grading) > 0) {
    prompts <- purrr::map_chr(needs_grading, function(i) {
      transcript <- chat_to_markdown(samples$solver_chat[[i]])
      format_scorer_prompt(transcript, samples$target[i])
    })

    responses <- ellmer::parallel_chat(
      scorer_chat$clone(),
      as.list(prompts)
    )

    for (j in seq_along(needs_grading)) {
      i <- needs_grading[j]
      response_text <- responses[[j]]$last_turn()@text
      grades[i] <- extract_grade(response_text)
      explanations[i] <- response_text
      scorer_chats[[i]] <- responses[[j]]
    }
  }

  # fill in mock chats for deterministically graded samples
  for (i in which(!is.na(grades) & !seq_len(n) %in% needs_grading)) {
    scorer_chats[[i]] <- mock_scorer_chat(scorer_chat, explanations[i])
  }

  list(
    score = factor(grades, levels = c("I", "C"), ordered = TRUE),
    scorer_chat = scorer_chats,
    scorer_metadata = as.list(explanations)
  )
}

# --- deterministic checks ---------------------------------------------------

r_tool_names <- c("run_r", "run_r_code", "execute_r", "execute_r_code")

solver_called_r_tool <- function(chat) {
  for (turn in chat$get_turns()) {
    if (!inherits(turn, "ellmer::AssistantTurn")) next
    for (content in turn@contents) {
      if (
        inherits(content, "ellmer::ContentToolRequest") &&
          content@name %in% r_tool_names
      ) {
        return(TRUE)
      }
    }
  }
  FALSE
}

solver_r_tool_succeeded <- function(chat) {
  for (turn in chat$get_turns()) {
    if (!inherits(turn, "ellmer::UserTurn")) next
    for (content in turn@contents) {
      if (
        inherits(content, "ellmer::ContentToolResult") &&
          content@request@name %in% r_tool_names &&
          is.null(content@error)
      ) {
        return(TRUE)
      }
    }
  }
  FALSE
}

solver_made_plot <- function(chat) {
  for (turn in chat$get_turns()) {
    for (content in turn@contents) {
      if (
        inherits(content, "ellmer::ContentImageInline") ||
          inherits(content, "ellmer::ContentImageRemote")
      ) {
        return(TRUE)
      }
    }
  }
  FALSE
}

# --- LLM judge --------------------------------------------------------------

format_scorer_prompt <- function(transcript, target) {
  glue::glue(
    "You are evaluating whether the assistant correctly identified and
fixed a data quality issue during a multi-turn conversation.

[BEGIN DATA]
************
[Target]: {target}
************
[Conversation Transcript]:
{transcript}
************
[END DATA]

The Target describes the data quality issue and what a correct fix looks like.
Does the conversation show the assistant identifying the issue and fixing it
(or proposing a fix)? The fix may appear in tool calls, code, or text.

{scorer_instructions()}"
  )
}

scorer_instructions <- function() {
  "After assessing the response, reply with 'GRADE: $LETTER' where
LETTER is one of C or I.
Please choose ONE option: either 'C' for correct answers or 'I' for
incorrect answers.
First **briefly** explain your reasoning, then end with GRADE: $LETTER.
Do not format the grading string and do not include any punctuation or
exposition after it."
}

extract_grade <- function(response) {
  match <- regmatches(
    response,
    regexec("(?i)GRADE\\s*:\\s*([CI])", response, perl = TRUE)
  )[[1]][2]

  if (is.na(match)) NA_character_ else toupper(match)
}

# --- transcript conversion ---------------------------------------------------

# Converts a Chat's turns into a markdown string for the LLM judge.
# Images are replaced with a placeholder; all other content uses
# ellmer's contents_markdown() method.
chat_to_markdown <- function(chat) {
  turns <- chat$get_turns()
  parts <- character(length(turns))

  for (i in seq_along(turns)) {
    turn <- turns[[i]]
    role <- if (inherits(turn, "ellmer::UserTurn")) "User" else "Assistant"

    contents <- vapply(turn@contents, function(content) {
      if (
        inherits(content, "ellmer::ContentImageInline") ||
          inherits(content, "ellmer::ContentImageRemote")
      ) {
        "[image]"
      } else {
        ellmer::contents_markdown(content) %||% ""
      }
    }, character(1))

    contents <- contents[nzchar(contents)]
    parts[i] <- paste0("**", role, ":** ", paste(contents, collapse = "\n\n"))
  }

  paste(parts, collapse = "\n\n")
}

mock_scorer_chat <- function(scorer_chat, explanation) {
  chat <- scorer_chat$clone()
  chat$set_turns(list(
    ellmer::UserTurn(
      contents = list(ellmer::ContentText("Automatically graded."))
    ),
    ellmer::AssistantTurn(
      contents = list(ellmer::ContentText(explanation))
    )
  ))
  chat
}
