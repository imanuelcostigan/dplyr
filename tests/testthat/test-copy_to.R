context("copy_to")

test_that("src_local only overwrites if overwrite = TRUE", {
  env <- new.env(parent = emptyenv())
  env$x <- 1

  src_env <- src_df(env = env)

  expect_error(
    copy_to(src_env, tibble(x = 1), name = "x"),
    "Object with name `x` already exists"
  )

  df <- tibble(x = 1)
  copy_to(src_env, df, name = "x", overwrite = TRUE)
  expect_equal(env$x, df)
})
