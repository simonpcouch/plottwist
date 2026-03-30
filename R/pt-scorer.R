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
#' @return A list with `score` (ordered factor with levels `I` < `P` < `C`),
#'   `scorer_chat`, and `scorer_metadata`. `C` (correct) means the model
#'   caught and fixed the issue on its own. `P` (partial) means it only
#'   fixed the issue after being nudged. `I` (incorrect) means it never
#'   fixed the issue.
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
    score = factor(grades, levels = c("I", "P", "C"), ordered = TRUE),
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
      if (is_image(content)) {
        return(TRUE)
      }
      # btw's run R tool nests images inside ContentToolResult$value
      if (inherits(content, "ellmer::ContentToolResult") && is.list(content@value)) {
        for (item in content@value) {
          if (is_image(item)) {
            return(TRUE)
          }
        }
      }
    }
  }
  FALSE
}

is_image <- function(content) {
  inherits(content, "ellmer::ContentImageInline") ||
    inherits(content, "ellmer::ContentImageRemote")
}

# --- LLM judge --------------------------------------------------------------

format_scorer_prompt <- function(transcript, target) {
  glue::glue(
    "You are evaluating whether the assistant correctly identified and
fixed a plot issue during a multi-turn conversation.

[BEGIN DATA]
************
[Target]: {target}
************
[Conversation Transcript]:
{transcript}
************
[END DATA]

The Target describes the plot issue and what a correct fix looks like.

This evaluation works as follows: the assistant is given a dataset and
asked to make a plot. The plot is injected into the conversation as a
synthetic tool call (the assistant did not actually write the code, but
it appears in the transcript as if it did). The plot contains an issue
described in the Target. After the injected plot, the user sends a
vague nudge like 'fix the plot' or 'there's an issue with the axes'
regardless of whether the assistant already noticed the problem.

Score the assistant as follows:
- C (correct): The assistant identified and fixed (or proposed fixing)
  the issue ON ITS OWN, before or without relying on the user's nudge.
  This means the assistant's first response after the injected plot
  already calls out the problem.
- P (partial): The assistant only identified and fixed the issue AFTER
  the user's nudge prompted it to look again.
- I (incorrect): The assistant never identified or fixed the issue.

Do not penalize the assistant for being confused by the nudge if it
had already caught the issue—the nudge is sent regardless.

{scorer_instructions()}"
  )
}

scorer_instructions <- function() {
  "After assessing the response, reply with 'GRADE: $LETTER' where
LETTER is one of C, P, or I.
Please choose ONE option: 'C' for correct (caught it unprompted),
'P' for partial (fixed only after the nudge), or 'I' for incorrect
(never fixed).
First **briefly** explain your reasoning, then end with GRADE: $LETTER.
Do not format the grading string and do not include any punctuation or
exposition after it."
}

extract_grade <- function(response) {
  match <- regmatches(
    response,
    regexec("(?i)GRADE\\s*:\\s*([CPI])", response, perl = TRUE)
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

    contents <- vapply(turn@contents, content_to_markdown, character(1))

    contents <- contents[nzchar(contents)]
    parts[i] <- paste0("**", role, ":** ", paste(contents, collapse = "\n\n"))
  }

  paste(parts, collapse = "\n\n")
}

# Converts a single Content object to markdown, replacing images with
# a placeholder. For tool results whose value is a list of content objects,
# renders each sub-item (replacing nested images too).
content_to_markdown <- function(content) {
  if (is_image(content)) {
    return("[image]")
  }

  if (inherits(content, "ellmer::ContentToolResult") && is.list(content@value)) {
    parts <- vapply(content@value, function(item) {
      if (is_image(item)) "[image]" else ellmer::contents_markdown(item) %||% ""
    }, character(1))
    return(paste(parts[nzchar(parts)], collapse = "\n\n"))
  }

  ellmer::contents_markdown(content) %||% ""
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
