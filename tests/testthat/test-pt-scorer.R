# helpers to build mock chats with specific turn contents ----------------------

mock_chat <- function(turns = list()) {
  chat <- ellmer::chat_openai(model = "gpt-4o")
  chat$set_turns(turns)
  chat
}

tool_request <- function(name = "run_r", id = "abc") {
  ellmer::ContentToolRequest(id = id, name = name, arguments = list(code = "1+1"))
}

tool_result <- function(name = "run_r", id = "abc", error = NULL) {
  ellmer::ContentToolResult(
    value = "2",
    error = error,
    request = tool_request(name, id)
  )
}

# extract_grade ---------------------------------------------------------------

test_that("extract_grade extracts C, P, and I", {
  expect_equal(extract_grade("Looks good. GRADE: C"), "C")
  expect_equal(extract_grade("Partial. GRADE: P"), "P")
  expect_equal(extract_grade("Wrong. GRADE: I"), "I")
})

test_that("extract_grade is case insensitive", {
  expect_equal(extract_grade("grade: c"), "C")
  expect_equal(extract_grade("grade: p"), "P")
  expect_equal(extract_grade("Grade: i"), "I")
})

test_that("extract_grade returns NA on no match", {
  expect_true(is.na(extract_grade("No grade here")))
  expect_true(is.na(extract_grade("")))
})

# solver_called_r_tool --------------------------------------------------------

test_that("solver_called_r_tool detects R tool requests", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(ellmer::ContentText("hi"))),
    ellmer::AssistantTurn(list(tool_request("run_r_code")))
  ))
  expect_true(solver_called_r_tool(chat))
})

test_that("solver_called_r_tool returns FALSE with no tool calls", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(ellmer::ContentText("hi"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("hello")))
  ))
  expect_false(solver_called_r_tool(chat))
})

test_that("solver_called_r_tool returns FALSE for non-R tools", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(ellmer::ContentText("hi"))),
    ellmer::AssistantTurn(list(tool_request("list_files")))
  ))
  expect_false(solver_called_r_tool(chat))
})

test_that("solver_called_r_tool recognizes all R tool aliases", {
  for (alias in r_tool_names) {
    chat <- mock_chat(list(
      ellmer::UserTurn(list(ellmer::ContentText("hi"))),
      ellmer::AssistantTurn(list(tool_request(alias)))
    ))
    expect_true(solver_called_r_tool(chat), info = alias)
  }
})

# solver_r_tool_succeeded -----------------------------------------------------

test_that("solver_r_tool_succeeded detects successful tool results", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(tool_result("execute_r"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("done")))
  ))
  expect_true(solver_r_tool_succeeded(chat))
})

test_that("solver_r_tool_succeeded returns FALSE when all calls error", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(tool_result("run_r", error = "bad code"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("oops")))
  ))
  expect_false(solver_r_tool_succeeded(chat))
})

# solver_made_plot ------------------------------------------------------------

test_that("solver_made_plot detects inline images", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(
      ellmer::ContentImageInline(type = "image/png", data = "abc123")
    )),
    ellmer::AssistantTurn(list(ellmer::ContentText("nice plot")))
  ))
  expect_true(solver_made_plot(chat))
})

test_that("solver_made_plot returns FALSE with no images", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(ellmer::ContentText("hi"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("hello")))
  ))
  expect_false(solver_made_plot(chat))
})

# chat_to_markdown ------------------------------------------------------------

test_that("chat_to_markdown produces labeled turns", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(ellmer::ContentText("Load the data"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("Done!")))
  ))
  md <- chat_to_markdown(chat)
  expect_match(md, "\\*\\*User:\\*\\*.*Load the data")
  expect_match(md, "\\*\\*Assistant:\\*\\*.*Done!")
})

test_that("chat_to_markdown replaces images with placeholder", {
  chat <- mock_chat(list(
    ellmer::UserTurn(list(
      ellmer::ContentImageInline(type = "image/png", data = "abc123")
    )),
    ellmer::AssistantTurn(list(ellmer::ContentText("A plot")))
  ))

  md <- chat_to_markdown(chat)
  expect_match(md, "\\[image\\]")
  expect_no_match(md, "abc123")
})

# prepare_solver_directory ----------------------------------------------------

test_that("prepare_solver_directory copies data file to temp dir", {
  solver_dir <- prepare_solver_directory("data/survival.csv")
  on.exit(unlink(solver_dir, recursive = TRUE))

  expect_true(dir.exists(solver_dir))
  expect_true(file.exists(file.path(solver_dir, "survival.csv")))
})
