test_that("random_system_prompt() returns a string", {
  set.seed(1)
  expect_snapshot(cat(random_system_prompt()))
})

test_that("random_system_prompt() is reproducible with same seed", {
  set.seed(1)
  first <- random_system_prompt()
  set.seed(1)
  second <- random_system_prompt()
  expect_equal(first, second)
})
