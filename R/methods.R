#' Posterior draws of respondent proficiency
#'
#' Calculate posterior draws of respondent proficiency. Optionally retain all
#' posterior draws or return only summaries of the distribution for each
#' respondent.
#'
#' @param object An object of class `measrdcm`. Generated from [measr_dcm()].
#' @param newdata Optional new data. If not provided, the data used to estimate
#'   the model is scored. If provided, `newdata` should be a data frame with 1
#'   row per respondent and 1 column per item. All items that appear in
#'   `newdata` should appear in the data used to estimate `object`.
#' @param resp_id Optional. Variable name of a column in `newdata` that
#'   contains respondent identifiers. `NULL` (the default) indicates that no
#'   identifiers are present in the data, and row numbers will be used as
#'   identifiers. If `newdata` is not specified and the data used to estimate
#'   the model is scored, the `resp_id` is taken from the original data.
#' @param missing An `R` expression specifying how missing data in `data` is
#'   coded (e.g., `NA`, `"."`, `-99`, etc.). The default is `NA`.
#' @param summary Should summary statistics be returned instead of the raw
#'   posterior draws? Only relevant if the model was estimated with
#'   `method = "mcmc"`. Default is `FALSE`.
#' @param probs The percentiles to be computed by the [stats::quantile()]
#'   function. Only relevant if the model was estimated with `method = "mcmc"`.
#'   Only used if `summary` is `TRUE`.
#' @param force If respondent estimates have already been added to the model
#'   object with [add_respondent_estimates()], should they be recalculated.
#'   Default is `FALSE`.
#' @param ... Unused.
#'
#' @return A list with two elements: `class_probabilities` and
#'   `attribute_probabilities`.
#'
#'   If summary is `FALSE`, each element is a tibble with the number of rows
#'   equal to the number of draws in `object` with columns: `.chain`,
#'   `.iteration`, `.draw`, the respondent identifier, and one column of
#'   probabilities for each of the possible classes.
#'
#'   If summary is `TRUE`, each element is a tibble with one row per respondent
#'   and class or attribute, and columns of the respondent identifier, `class`
#'   or `attribute`, `mean`, and one column for every value specified in
#'   `probs`.
#' @export
predict.measrdcm <- function(object, newdata = NULL, resp_id = NULL,
                             missing = NA, summary = TRUE,
                             probs = c(0.025, 0.975), force = FALSE, ...) {
  model <- check_model(object, required_class = "measrdcm", name = "object")

  if ((!is.null(model$respondent_estimates) &&
       length(model$respondent_estimates) > 0) &&
      !force && summary) {
    return(model$respondent_estimates)
  }

  summary <- check_logical(summary, allow_na = FALSE, name = "summary")
  probs <- check_double(probs, lb = 0, ub = 1, inclusive = TRUE, name = "probs")
  if (!is.null(newdata)) {
    resp_id <- check_character(resp_id, name = "resp_id", allow_null = TRUE)
    score_data <- check_newdata(newdata, identifier = resp_id, model = model,
                                missing = missing, name = "newdata")
    resp_lookup <- score_data %>%
      dplyr::rename(orig_resp = "resp_id") %>%
      dplyr::mutate(resp_id = as.integer(.data$orig_resp)) %>%
      dplyr::distinct(.data$orig_resp, .data$resp_id)
  } else {
    score_data <- model$data$data
    resp_lookup <- model$data$data %>%
      dplyr::rename(orig_resp = "resp_id") %>%
      dplyr::mutate(resp_id = as.integer(.data$orig_resp)) %>%
      dplyr::distinct(.data$orig_resp, .data$resp_id)
  }
  attr_lookup <- tibble::tibble(real_names = colnames(model$data$qmatrix)) %>%
    dplyr::filter(.data$real_names != "item_id") %>%
    dplyr::mutate(att_id = paste0("att", seq_len(dplyr::n())))

  clean_qmatrix <- model$data$qmatrix %>%
    dplyr::select(-"item_id") %>%
    dplyr::rename_with(~glue::glue("att{1:(ncol(model$data$qmatrix) - 1)}"))
  stan_data <- create_stan_data(dat = score_data, qmat = clean_qmatrix,
                                type = model$type)
  stan_draws <- switch(model$method,
                       "mcmc" = get_mcmc_draws(model),
                       "optim" = get_optim_draws(model))

  stan_pars <- create_stan_gqs_params(backend = model$backend,
                                      draws = stan_draws)
  stan_pars$data <- stan_data

  # compile model -----
  stan_mod <- create_stan_function(backend = model$backend,
                                   method = "gqs",
                                   code = gqs_script(),
                                   precompiled = stanmodels$gqs_probs,
                                   pars = stan_pars,
                                   silent = 2)
  out <- utils::capture.output( #nolint
    gqs_model <- do.call(stan_mod$func, stan_mod$pars)
  )

  # get mastery information -----
  ret_list <- calculate_probs(model = gqs_model,
                              qmat = clean_qmatrix,
                              method = model$method,
                              resp_lookup = resp_lookup,
                              attr_lookup = attr_lookup,
                              resp_id = model$data$resp_id)

  if (!summary) {
    no_summary_list <- calculate_probs_no_summary(ret_list = ret_list,
                                                  method = model$method)
    return(no_summary_list)
  }

  summary_list <- calculate_probs_summary(ret_list = ret_list,
                                          probs = probs,
                                          id = model$data$resp_id,
                                          method = model$method)
  return(summary_list)
}
