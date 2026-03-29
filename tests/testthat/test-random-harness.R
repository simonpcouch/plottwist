test_that("random_harness() always includes a run_r alias", {
  set.seed(1)
  harness <- random_harness()
  run_aliases <- tool_name_aliases[["btw_tool_run_r"]]
  expect_true(any(names(harness) %in% run_aliases))
})

test_that("random_harness() returns only aliased names", {
  set.seed(1)
  harness <- random_harness()
  all_aliases <- unlist(tool_name_aliases)
  expect_true(all(names(harness) %in% all_aliases))
})

test_that("random_harness() @name matches list name", {
  set.seed(1)
  harness <- random_harness()
  tool_names <- unname(vapply(harness, function(t) t@name, character(1)))
  expect_equal(tool_names, names(harness))
})

test_that("random_harness() is reproducible with same seed", {
  set.seed(1)
  first <- names(random_harness())
  set.seed(1)
  second <- names(random_harness())
  expect_equal(first, second)
})
