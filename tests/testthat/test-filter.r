context("Filter")

test_that("filter fails if inputs incorrect length (#156)", {
  expect_error(filter(tbl_df(mtcars), c(F, T)))
  expect_error(filter(group_by(mtcars, am), c(F, T)))
})

test_that("filter gives useful error message when given incorrect input", {
  expect_error(filter(tbl_df(mtcars), `_x`), "not found")
})

test_that("filter gives UTF-8 encoded column names (#2441)", {
  df <- data_frame(a = factor(1:3)) %>% rename("\u5e78" := a)
  expect_error(filter(df, `<U+798F>`), "object '<U\\+798F>' not found")
})

test_that("filter complains in inputs are named", {
  expect_error(filter(mtcars, x = 1), "takes unnamed arguments")
  expect_error(filter(mtcars, x = 1 & y > 2), "takes unnamed arguments")
})

test_that("filter handles passing ...", {
  df <- data.frame(x = 1:4)

  f <- function(...) {
    x1 <- 4
    f1 <- function(y) y
    filter(df, ..., f1(x1) > x)
  }
  g <- function(...) {
    x2 <- 2
    f(x > x2, ...)
  }
  res <- g()
  expect_equal(res$x, 3L)

  df <- group_by(df, x)
  res <- g()
  expect_equal(res$x, 3L)

})

test_that("filter handles simple symbols", {
  df <- data.frame(x = 1:4, test = rep(c(T, F), each = 2))
  res <- filter(df, test)

  gdf <- group_by(df, x)
  res <- filter(gdf, test)

  h <- function(data) {
    test2 <- c(T, T, F, F)
    filter(data, test2)
  }
  expect_equal(h(df), df[1:2, ])

  f <- function(data, ...) {
    one <- 1
    filter(data, test, x > one, ...)
  }
  g <- function(data, ...) {
    four <- 4
    f(data, x < four, ...)
  }
  res <- g(df)
  expect_equal(res$x, 2L)
  expect_equal(res$test, TRUE)

  res <- g(gdf)
  expect_equal(res$x, 2L)
  expect_equal(res$test, TRUE)

})

test_that("filter handlers scalar results", {
  expect_equivalent(filter(mtcars, min(mpg) > 0), mtcars)
  expect_equal(filter(group_by(mtcars, cyl), min(mpg) > 0), group_by(mtcars, cyl))
})

test_that("filter propagates attributes", {
  date.start <- ISOdate(2010, 01, 01, 0)
  test <- data.frame(Date = ISOdate(2010, 01, 01, 1:10))
  test2 <- test %>% filter(Date < ISOdate(2010, 01, 01, 5))
  expect_equal(test$Date[1:4], test2$Date)
})

test_that("filter fails on integer indices", {
  expect_error(filter(mtcars, 1:2))
  expect_error(filter(group_by(mtcars, cyl), 1:2))
})

test_that("filter discards NA", {
  temp <- data.frame(
    i = 1:5,
    x = c(NA, 1L, 1L, 0L, 0L)
  )
  res <- filter(temp, x == 1)
  expect_equal(nrow(res), 2L)
})

test_that("date class remains on filter (#273)", {
  x1 <- x2 <- data.frame(
    date = seq.Date(as.Date("2013-01-01"), by = "1 days", length.out = 2),
    var = c(5, 8)
  )
  x1.filter <- x1 %>% filter(as.Date(date) > as.Date("2013-01-01"))
  x2$date <- x2$date + 1
  x2.filter <- x2 %>% filter(as.Date(date) > as.Date("2013-01-01"))

  expect_equal(class(x1.filter$date), "Date")
  expect_equal(class(x2.filter$date), "Date")
})

test_that("filter handles $ correctly (#278)", {
  d1 <- tbl_df(data.frame(
    num1 = as.character(sample(1:10, 1000, T)),
    var1 = runif(1000),
    stringsAsFactors = FALSE))
  d2 <- data.frame(num1 = as.character(1:3), stringsAsFactors = FALSE)

  res1 <- d1 %>% filter(num1 %in% c("1", "2", "3"))
  res2 <- d1 %>% filter(num1 %in% d2$num1)
  expect_equal(res1, res2)
})

test_that("filter returns the input data if no parameters are given", {
  expect_equivalent(filter(mtcars), mtcars)
})

test_that("$ does not end call traversing. #502", {
  # Suppose some analysis options are set much earlier in the script
  analysis_opts <- list(min_outcome = 0.25)

  # Generate some dummy data
  d <- expand.grid(Subject = 1:3, TrialNo = 1:2, Time = 1:3) %>% tbl_df %>%
    arrange(Subject, TrialNo, Time) %>%
    mutate(Outcome = (1:18 %% c(5, 7, 11)) / 10)

  # Do some aggregation
  trial_outcomes <- d %>% group_by(Subject, TrialNo) %>%
    summarise(MeanOutcome = mean(Outcome))

  left  <- filter(trial_outcomes, MeanOutcome < analysis_opts$min_outcome)
  right <- filter(trial_outcomes, analysis_opts$min_outcome > MeanOutcome)

  expect_equal(left, right)

})

test_that("GroupedDataFrame checks consistency of data (#606)", {
  df1 <- data_frame(
   g = rep(1:2, each = 5),
   x = 1:10
  ) %>% group_by(g)
  attr(df1, "group_sizes") <- c(2, 2)

  expect_error(df1 %>% filter(x == 1), "corrupt 'grouped_df'")
})

test_that("filter uses the white list (#566)", {
  datesDF <- read.csv(stringsAsFactors = FALSE, text = "
X
2014-03-13 16:08:19
2014-03-13 16:16:23
2014-03-13 16:28:28
2014-03-13 16:28:54
")

  datesDF$X <- as.POSIXlt(datesDF$X)
  expect_error(
    filter(datesDF, X > as.POSIXlt("2014-03-13")),
    "column 'X' has unsupported class|POSIXct, not POSIXlt.*'X'"
  )
})

test_that("filter handles complex vectors (#436)", {
  d <- data.frame(x = 1:10, y = 1:10 + 2i)
  expect_equal(filter(d, x < 4)$y, 1:3 + 2i)
  expect_equal(filter(d, Re(y) < 4)$y, 1:3 + 2i)
})

test_that("%in% works as expected (#126)", {
  df <- data_frame(a = c("a", "b", "ab"), g = c(1, 1, 2))

  res <- df %>% filter(a %in% letters)
  expect_equal(nrow(res), 2L)

  res <- df %>% group_by(g) %>% filter(a %in% letters)
  expect_equal(nrow(res), 2L)

})

test_that("row_number does not segfault with example from #781", {
  z <- data.frame(a = c(1, 2, 3))
  b <- "a"
  res <- z %>% filter(row_number(b) == 2)
  expect_equal(nrow(res), 0L)
})

test_that("filter does not alter expression (#971)", {
  my_filter <- ~ am == 1
  expect_equal(my_filter[[2]][[2]], as.name("am"))
})

test_that("hybrid evaluation handles $ correctly (#1134)", {
  df <- data_frame(x = 1:10, g = rep(1:5, 2))
  res <- df %>% group_by(g) %>% filter(x > min(df$x))
  expect_equal(nrow(res), 9L)
})

test_that("filter correctly handles empty data frames (#782)", {
  res <- data_frame() %>% filter(F)
  expect_equal(nrow(res), 0L)
  expect_equal(length(names(res)), 0L)
})

test_that("filter(.,TRUE,TRUE) works (#1210)", {
  df <- data.frame(x = 1:5)
  res <- filter(df, TRUE, TRUE)
  expect_equal(res, df)
})

test_that("filter, slice and arrange preserves attributes (#1064)", {
  df <- structure(
      data.frame(x = 1:10, g1 = rep(1:2, each = 5), g2 = rep(1:5, 2)),
      meta = "this is important"
  )
  res <- filter(df, x < 5) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- filter(df, x < 5, x > 4) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- df %>% slice(1:50) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- df %>% arrange(x) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- df %>% summarise(n()) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- df %>% group_by(g1) %>% summarise(n()) %>% attr("meta")
  expect_equal(res, "this is important")

  res <- df %>% group_by(g1, g2) %>% summarise(n()) %>% attr("meta")
  expect_equal(res, "this is important")

})

test_that("filter works with rowwise data (#1099)", {
  df <- data_frame(First = c("string1", "string2"), Second = c("Sentence with string1", "something"))
  res <- df %>% rowwise() %>% filter(grepl(First, Second, fixed = TRUE))
  expect_equal(nrow(res), 1L)
  expect_equal(df[1, ], res)
})

test_that("grouped filter handles indices (#880)", {
  res <- iris %>% group_by(Species) %>% filter(Sepal.Length > 5)
  res2 <- mutate(res, Petal = Petal.Width * Petal.Length)
  expect_equal(nrow(res), nrow(res2))
  expect_equal(attr(res, "indices"), attr(res2, "indices"))
})

test_that("filter(FALSE) drops indices", {
  out <- mtcars %>%
    group_by(cyl) %>%
    filter(FALSE) %>%
    attr("indices")
  expect_identical(out, list())
})

test_that("filter handles S4 objects (#1366)", {
  env <- environment()
  Numbers <- suppressWarnings(setClass(
    "Numbers", slots = c(foo = "numeric"), contains = "integer", where = env
  ))
  on.exit(removeClass("Numbers", where = env))

  df <- data.frame(x = Numbers(1:10, foo = 10))
  res <- filter(df, x > 3)
  expect_true(isS4(res$x))
  expect_is(res$x, "Numbers")
  expect_equal(res$x@foo, 10)
})

test_that("hybrid lag and default value for string columns work (#1403)", {
  res <- mtcars %>%
    mutate(xx = LETTERS[gear]) %>%
    filter(xx == lag(xx, default = "foo"))
  xx <- LETTERS[mtcars$gear]
  ok <- xx == lag(xx, default = "foo")
  expect_equal(xx[ok], res$xx)

  res <- mtcars %>%
    mutate(xx = LETTERS[gear]) %>%
    filter(xx == lead(xx, default = "foo"))
  xx <- LETTERS[mtcars$gear]
  ok <- xx == lead(xx, default = "foo")
  expect_equal(xx[ok], res$xx)
})

# .data and .env tests now in test-hybrid-traverse.R

test_that("filter fails gracefully on raw columns (#1803)", {
  df <- data_frame(a = 1:3, b = as.raw(1:3))
  expect_error(filter(df, a == 1), "unsupported type")
  expect_error(filter(df, b == 1), "unsupported type")
})
