sc <- function(x){
  Filter(Negate(is.null), x)
}

return_obj <- function(x, y){
  y <- err_hand(y)
  x <- match.arg(x, c('response', 'list', 'table', 'data.frame'))
  if (x == 'response') {
    y
  } else {
    if (x == 'list') {
      jsonlite::fromJSON(y, simplifyVector = FALSE, flatten = TRUE)
    } else {
      jsonlite::fromJSON(y, flatten = TRUE)
    }
  }
}

flatten_df <- function(x) {
  if (NROW(x) == 0) {
    x
  }
  else {
    for (i in seq_len(NCOL(x))) {
      if (class(x[,i]) == "list") {
        z <- unlist(x[,i])
        if (length(z) != NROW(x)) z <- rep(NA_character_, NROW(x))
        x[,i] <- z
      }
    }
    x
  }
}

# check if stupid single left bracket returned
err_hand <- function(z) {
  tmp <- httr::content(z, "text")
  if (identical(tmp, "[")) {
    q <- httr::parse_url(z$request$opts$url)$query
    q <- paste0("\n - ", paste(names(q), q, sep = "="), collapse = "")
    stop("The following query had no results:\n", q, call. = FALSE)
  } else {
    tmp
  }
}

give_noiter <- function(as, url, endpt, args, ...) {
  tmp <- return_obj(as, query(paste0(url, endpt), args, ...))
  switch(as,
         table = as_data_frame(flatten_df(tmp)),
         list = tmp,
         response = tmp)
}

give <- function(as, url, endpt, args, ...) {
  iter <- get_iter(args)
  if (length(iter) == 0) {
    tmp <- return_obj(as, query(paste0(url, endpt), args, ...))
  } else {
    tmp <- lapply(iter[[1]], function(w) {
      args[[ names(iter) ]] <- w
      return_obj(as, query(paste0(url, endpt), args, ...))
    })
    if (as == "table") {
      tmp <- tmp[vapply(tmp, length, numeric(1)) != 0]
      tmp <- plyr::rbind.fill(tmp)
    }
  }
  switch(as,
         table = as_data_frame(flatten_df(tmp)),
         list = tmp,
         response = tmp)
}

give_cg <- function(as, url, endpt, args, ...) {
  iter <- get_iter(args)
  if (length(iter) == 0) {
    tmp <- return_obj(as, query(paste0(url, endpt), args, ...))
    found <- tmp$num_found
  } else {
    tmp <- lapply(iter[[1]], function(w) {
      args[[ names(iter) ]] <- w
      return_obj(as, query(paste0(url, endpt), args, ...))
    })
    found <- as.list(stats::setNames(sapply(tmp, function(z) {
      zz <- z$num_found
      if (is.null(zz)) z$count
    }), iter[[1]]))
    if (as == "table") {
      res <- lapply(tmp, "[[", "results")
      res <- Filter(function(x) !(is.null(x) || length(x) == 0), res)
      for (i in seq_along(res)) {
        res[[i]][names(iter)] <- iter[[1]][i]
      }
      res <- res[vapply(res, length, numeric(1)) != 0]
      tmp <- rbind.fill(res)
    }
  }
  structure(switch(as,
         table = if (length(iter) == 0) {
           as_data_frame(flatten_df(tmp$results))
         } else {
           as_data_frame(flatten_df(tmp))
         },
         list = tmp,
         response = tmp), found = found)
}

one_vec <- function(x) {
  lens <- x[vapply(x, length, 1) > 1]
  if (length(lens) > 1) {
    stop("Only one parameter can be vectorized per function call", call. = FALSE)
  }
}

get_iter <- function(z) {
  z[vapply(z, length, 1) > 1]
}

check_key <- function(x){
  tmp <- if (is.null(x)) {
    Sys.getenv("SUNLIGHT_LABS_KEY", "")
  } else {
    x
  }

  if (tmp == "") {
    getOption("SunlightLabsKey", stop("need an API key for Sunlight Labs"))
  } else {
    tmp
  }
}

cgurl <- function() 'https://congress.api.sunlightfoundation.com'
cwurl <- function() 'http://capitolwords.org/api'
ieurl <- function() 'http://transparencydata.com/api/1.0'
osurl <- function() 'http://openstates.org/api/v1'
rtieurl <- function() "http://realtime.influenceexplorer.com/api/"

