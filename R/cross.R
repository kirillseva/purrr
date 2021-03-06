#' Produce all combinations of list elements
#'
#' \code{cross()} returns the product set of the elements of \code{.x}
#' and \code{.y}. It is similar to \code{expand.grid()} but it returns
#' a list. By default, the cartesian product is returned in wide
#' format. This makes it more amenable to mapping
#' operations. Switching \code{.wide} to \code{FALSE} turns the output
#' to the long format, the equivalent to \code{expand.grid()}'s
#' outputs.
#'
#' \code{cross3()} takes three three arguments instead of two and
#' returns the cartesian product of the elements of the three
#' objects. \code{cross_n()} takes a list \code{.l} and returns the
#' cartesian product of all its elements. If \code{.l} is a data
#' frame, \code{cross_n()} returns a data frame.
#'
#' When the number of combinations is large and the individual elements
#' are heavy memory-wise, it is often useful to filter unwanted
#' combinations on the fly. \code{.filter} must be a predicate
#' function that takes the same number of arguments as the number of
#' crossed objects (2 for \code{cross()}, 3 for \code{cross3()},
#' \code{length(.l)} for \code{cross_n()}) and returns \code{TRUE} or
#' \code{FALSE}. The combinations where the predicate function returns
#' \code{TRUE} will be removed from the result.
#' @seealso \code{\link{expand.grid}()}
#' @param .x,.y,.z Lists or atomic vectors.
#' @param .l A list of lists or atomic vectors. Alternatively, a data frame.
#' @param .filter A predicate function that takes the same number of
#' arguments as the number of variables to be combined.
#' @return \code{cross()} and \code{cross3()} always return a
#' list. \code{cross_n()} returns a list if \code{.l} is a list and a
#' data frame if \code{.l} is a data frame. For lists, each element is
#' one combination so that the list can be directly mapped over. For
#' data frames, each row represents one combination.
#' @export
#' @examples
#' # We build all combinations of names, greetings and separators from our
#' # list of data and pass each one to paste()
#' data <- list(
#'   id = c("John", "Jane"),
#'   greeting = c("Hello.", "Bonjour."),
#'   sep = c("! ", "... ")
#' )
#'
#' data %>% 
#'   cross_n() %>%
#'   map(smash(paste))
#'
#' # If we start with a data frame instead, we'll get a data frame in
#' # long format, as with expand.grid(). We have three columns id,
#' # greeting and sep, with each row a particular combination
#' df <- data %>% dplyr::as_data_frame()
#' args <- cross_n(df)
#'
#' # The long format can also be obtained with a list by unzipping
#' # then flattening each element.
#' data %>%
#'   cross_n() %>%
#'   unzip() %>%
#'   map(flatten)
#'
#' # This format is often less pratical for functional programming
#' # because applying a function to the combinations requires a loop
#' out <- vector("list", length = nrow(args))
#' for (i in seq_along(out))
#'   out[[i]] <- map(args, i) %>% map_call("paste")
#' out
#' 
#' # In this case, the combinations could be manipulated using dplyr
#' args %>% dplyr::do(
#'   map_call(., "paste") %>% dplyr::data_frame()
#' )
#'
#' # Unwanted combinations can be filtered out with a predicate function
#' filter <- function(x, y) x >= y
#' cross(1:5, 1:5, .filter = filter) %>% str()
#'
#' # To give names to the components of the combinations, we map
#' # setNames() on the product:
#' seq_len(3) %>%
#'   cross(., ., .filter = function(x, y) x == y) %>%
#'   map(setNames, c("x", "y"))
#' 
#' # We can also encapsulate the arguments in a named list before
#' # crossing:
#' seq_len(3) %>%
#'   list(x = ., y = .) %>%
#'   cross_n(.filter = function(x, y) x == y)
cross <- function(.x, .y, .filter = NULL) {
  cross_n(list(.x, .y), .filter = .filter)
}

#' @export
#' @rdname cross
cross3 <- function(.x, .y, .z, .filter = NULL) {
  cross_n(list(.x, .y, .z), .filter = .filter)
}


#' @export
#' @rdname cross
cross_n <- function(.l, .filter = NULL) {
  n <- length(.l)
  lengths <- lapply(.l, length)
  names <- names(.l)

  factors <- cumprod(lengths)
  total_length <- factors[n]
  factors <- c(1, factors[-n])

  out <- replicate(total_length, vector("list", n), simplify = FALSE)

  for (i in seq_along(out)) {
    for (j in seq_len(n)) {
      index <- floor((i - 1) / factors[j]) %% length(.l[[j]]) + 1
      out[[i]][[j]] <- .l[[j]][[index]]
    }
    names(out[[i]]) <- names

    # Filter out unwanted elements. We set them to NULL instead of
    # completely removing them so we don't mess up the loop indexing.
    # NULL elements are removed later on.
    if (!is.null(.filter)) {
      is_to_filter <- do.call(".filter", unname(out[[i]]))
      if (!is.logical(is_to_filter) || !length(is_to_filter) == 1) {
        stop("The filter function must return TRUE or FALSE", call. = FALSE)
      }
      if (is_to_filter) {
        out[i] <- list(NULL)
      }
    }
  }

  # Remove filtered elements
  out <- compact(out)

  # Return product in long format if .l is a data frame
  if (is.data.frame(.l)) {
    out %>%
      unzip() %>%
      lapply(flatten) %>%
      dplyr::as_data_frame()
  } else {
    out
  }
}
