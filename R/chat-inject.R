# Injects a synthetic pair of turns into a chat's history and then 
# lets the model respond. The user and assistant turns are added 
# directly to the history, then user2 is submitted through ellmer's 
# private chat_impl() so the model sees it as a normal tool response 
# and reacts to it. user2 is a UserTurn containing only ContentToolResult 
# objects (no user text).
#
# This gives us an entry point to tell the model that it called the 
# run R code tool with known (to us) faulty code.
chat_inject <- function(chat, user, assistant, user2) {
  chat$add_turn(user = user, assistant = assistant, log_tokens = FALSE)

  private <- chat$.__enclos_env__$private
  coro::collect(private$chat_impl(
    user_turn = user2,
    stream = FALSE,
    echo = "none"
  ))

  invisible(chat$last_turn()@text)
}
