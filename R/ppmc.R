#' Posterior predictive model checks for assessing model fit
#'
#' For models estimated with `method = "mcmc"`, use the posterior distributions
#' to compute expected distributions for fit statistics and compare to values
#' in the observed data.
#'
#' @param model A [measrfit] object.
#' @param ndraws The number of posterior draws to base the checks on. Must be
#'   less than or equal to the total number of posterior draws retained in the
#'   estimated model. If `NULL` (the default) the total number from the
#'   estimated model is used.
#' @param probs The percentiles to be computed by the [stats::quantile()]
#'   function for summarizing the posterior distributions of the specified fit
#'   statistics.
#' @param return_draws Proportion of posterior draws for each specified fit
#'   statistic to be returned. This does not affect the calculation of the
#'   posterior predictive checks, but can be useful for visualizing the fit
#'   statistics. For example, if `ndraws = 500`, `return_draws = 0.2`, and
#'   `model_fit = "raw_score"`, then the raw score chi-square will be computed
#'   500 times (once for each draw) and 100 of those values (0.2 * 500) will be
#'   returned. If `0` (the default), only summaries of the posterior are
#'   returned (no individual samples).
#' @param model_fit The posterior predictive model checks to compute for an
#'   evaluation of model-level fit. If `NULL`, no model-level checks are
#'   computed. See details.
#' @param item_fit The posterior predictive model checks to compute for an
#'   evaluation of item-level fit. If `NULL`, no item-level checks are computed.
#'   Multiple checks can be provided in order to calculate more than one check
#'   simultaneously (e.g., `item_fit = c("conditional_prob", "odds_ratio")`).
#'   See details.
#' @param force If all requested \acronym{PPMC}s have already been added to the
#'   model object using [add_fit()], should they be recalculated. Default is
#'   `FALSE`.
#'
#' @details
#' Posterior predictive model checks (PPMCs) use the posterior distribution of
#' an estimated model to compute different statistics. This creates an expected
#' distribution of the given statistic, *if our estimated parameters are
#' correct*. We then compute the statistic in our observed data and compare the
#' observed value to the expected distribution. Observed values that fall
#' outside of the expected distributions indicate incompatibility between the
#' estimated model and the observed data.
#'
#' We currently support PPMCs at the model and item level. At the model level,
#' we calculate the expected raw score distribution (`model_fit = "raw_score"`),
#' as described by Thompson (2019) and Park et al. (2015).
#'
#' At the item level, we can calculate the conditional probability that a
#' respondent in each class provides a correct response (`item_fit =
#' "conditional_prob"`) as described by Thompson (2019) and Sinharay & Almond
#' (2007) or the overall proportion correct for an item (`item_fit = "pvalue"`),
#' as described by Thompson (2019). We can also calculate the odds ratio for
#' each pair of items (`item_fit = "odds_ratio"`) as described by Park et al.
#' (2015) and Sinharay et al. (2006).
#'
#' @return A list with two elements, "model_fit" and "item_fit". If either
#'   `model_fit = NULL` or `item_fit = NULL` in the function call, this will be
#'   a one-element list, with the null criteria excluded. Each list element, is
#'   itself a list with one element for each specified \acronym{PPMC} containing
#'   a [tibble][tibble::tibble-package]. For example if
#'   `item_fit = c("conditional_prob", "odds_ratio")`, the "item_fit" element
#'   will be a list of length two, where each element is a tibble containing the
#'   results of the \acronym{PPMC}. All tibbles follow the same general
#'   structure:
#'
#'   \itemize{
#'   \item `obs_{ppmc}`: The value of the relevant statistic in the observed
#'     data.
#'   \item `ppmc_mean`: The mean of the `ndraws` posterior samples calculated
#'     for the given statistic.
#'   \item Quantile columns: 1 column for each value of `probs`, providing the
#'     corresponding quantiles of the `ndraws` posterior samples calculated for
#'     the given statistic.
#'   \item `samples`: A list column, where each element contains a vector of
#'     length `(ndraws * return_draws)`, representing samples from the
#'     posterior distribution of the calculated statistic. This column is
#'     excluded if `return_draws = 0`.
#'   \item `ppp`: The posterior predictive p-value. This is the proportion of
#'     posterior samples for calculated statistic that are greater than the
#'     observed value. Values very close to 0 or 1 indicate incompatibility
#'     between the fitted model and the observed data.
#'   }
#'
#' @references Park, J. Y., Johnson, M. S., Lee, Y-S. (2015). Posterior
#'   predictive model checks for cognitive diagnostic models. *International
#'   Journal of Quantitative Research in Education, 2*(3-4), 244-264.
#'   \doi{10.1504/IJQRE.2015.071738}
#' @references Sinharay, S., & Almond, R. G. (2007). Assessing fit of cognitive
#'   diagnostic models. *Educational and Psychological Measurement, 67*(2),
#'   239-257. \doi{10.1177/0013164406292025}
#' @references Sinharay, S., Johnson, M. S., & Stern, H. S. (2006). Posterior
#'   predictive assessment of item response theory models. *Applied
#'   Psychological Measurement, 30*(4), 298-321.
#'   \doi{10.1177/0146621605285517}
#' @references Thompson, W. J. (2019). *Bayesian psychometrics for diagnostic
#'   assessments: A proof of concept* (Research Report No. 19-01). University
#'   of Kansas; Accessible Teaching, Learning, and Assessment Systems.
#'   \doi{10.35542/osf.io/jzqs8}
#'
#' @export
#' @examplesIf measr_examples()
#' mdm_dina <- measr_dcm(
#'   data = mdm_data, missing = NA, qmatrix = mdm_qmatrix,
#'   resp_id = "respondent", item_id = "item", type = "dina",
#'   method = "mcmc", seed = 63277, backend = "rstan",
#'   iter = 700, warmup = 500, chains = 2, refresh = 0
#' )
#'
#' fit_ppmc(mdm_dina, model_fit = "raw_score", item_fit = NULL)
fit_ppmc <- function(model, ndraws = NULL, probs = c(0.025, 0.975),
                     return_draws = 0,
                     model_fit = c("raw_score"),
                     item_fit = c("conditional_prob", "odds_ratio", "pvalue"),
                     force = FALSE) {
  model <- check_model(model, required_class = "measrdcm", name = "object")
  total_draws <- posterior::ndraws(posterior::as_draws(model))
  ndraws <- check_integer(ndraws, lb = 1, ub = total_draws,
                          name = "ndraws", allow_null = TRUE)
  probs <- check_double(probs, lb = 0, ub = 1, inclusive = TRUE, name = "probs")
  return_draws <- check_double(return_draws, lb = 0, ub = 1, inclusive = TRUE,
                               name = "return_draws")
  model_fit <- if (!is.null(model_fit)) {
    rlang::arg_match(model_fit, multiple = TRUE)
  }
  item_fit <- if (!is.null(item_fit)) {
    rlang::arg_match(item_fit, multiple = TRUE)
  }

  # check for existing fit analyses
  check_ppmc <- existing_ppmc_check(model = model, method = "ppmc",
                                    dots = list(ndraws = ndraws,
                                                probs = probs,
                                                return_draws = return_draws,
                                                model_fit = model_fit,
                                                item_fit = item_fit),
                                    overwrite = force)
  if (!check_ppmc$run && !force) {
    requested <- list(model_fit = model_fit,
                      item_fit = item_fit)
    requested[sapply(requested, is.null)] <- NULL

    res <- mapply(
      function(x, nm, model) {
        element <- model$fit$ppmc[[nm]][x]
        rlang::set_names(element, nm = x)
        return(element)
      },
      requested, names(requested),
      MoreArgs = list(model = model), SIMPLIFY = FALSE, USE.NAMES = TRUE
    )

    return(res)
  }


  if (length(model_fit) == 0 && length(item_fit) == 0) return(list())

  clean_qmatrix <- model$data$qmatrix %>%
    dplyr::select(-"item_id") %>%
    dplyr::rename_with(~glue::glue("att{1:(ncol(model$data$qmatrix) - 1)}"))
  stan_data <- create_stan_data(dat = model$data$data, qmat = clean_qmatrix,
                                type = model$type)

  stan_draws <- get_mcmc_draws(model, ndraws = ndraws)

  stan_pars <- create_stan_gqs_params(backend = model$backend,
                                      draws = stan_draws)
  stan_pars$data <- stan_data

  # compile model -----
  stan_mod <- create_stan_function(backend = model$backend,
                                   method = "gqs",
                                   code = gqs_script(full_data = TRUE),
                                   precompiled = stanmodels$gqs_ppmc,
                                   pars = stan_pars,
                                   silent = 2)
  out <- utils::capture.output( #nolint
    gqs_model <- do.call(stan_mod$func, stan_mod$pars)
  )
  all_draws <- posterior::as_draws_array(gqs_model)

  # organize ppmc data
  post_data <- posterior::subset_draws(all_draws, variable = "y_rep") %>%
    posterior::as_draws_df() %>%
    tibble::as_tibble() %>%
    tidyr::pivot_longer(cols = -c(".chain", ".iteration", ".draw")) %>%
    tidyr::separate_wider_regex(
      cols = "name",
      patterns = c("y_rep\\[", obs = "\\d+", "\\]")) %>%
    dplyr::mutate(obs = as.integer(.data$obs)) %>%
    dplyr::left_join(model$data$data %>%
                       dplyr::mutate(obs = seq_len(dplyr::n()),
                                     resp = as.integer(.data$resp_id),
                                     item = as.integer(.data$item_id)) %>%
                       dplyr::select("obs", "resp", "item"),
                     by = "obs", relationship = "many-to-one")

  # calculate raw score distribution
  model_level_fit <- if (!is.null(model_fit)) {
    ppmc_model_fit(model = model,
                   post_data = post_data,
                   probs = probs,
                   return_draws = return_draws,
                   type = check_ppmc$args$model_fit)
  } else {
    NULL
  }

  item_level_fit <- if (!is.null(item_fit)) {
    resp_prob <- extract_class_probs(model = gqs_model,
                                     attr = ncol(clean_qmatrix),
                                     method = model$method)
    pi_draws <- posterior::subset_draws(stan_draws, variable = "pi")

    ppmc_item_fit(model = model,
                  post_data = post_data,
                  attr = ncol(clean_qmatrix),
                  resp_prob = resp_prob,
                  pi_draws = pi_draws,
                  probs = probs,
                  return_draws = return_draws,
                  type = check_ppmc$args$item_fit)
  } else {
    NULL
  }

  ret_list <- if (is.null(model$fit$ppmc)) {
    list(model_fit = model_level_fit,
         item_fit = item_level_fit)
  } else {
    model$fit$ppmc$model_fit[names(model_level_fit)] <- NULL
    model$fit$ppmc$item_fit[names(item_level_fit)] <- NULL

    utils::modifyList(model$fit$ppmc,
                      list(model_fit = model_level_fit,
                           item_fit = item_level_fit))
  }

  ret_list <- list(model_fit = ret_list$model_fit[model_fit],
                   item_fit = ret_list$item_fit[item_fit])

  ret_list[sapply(ret_list, is.null)] <- NULL

  return(ret_list)
}


ppmc_model_fit <- function(model, post_data, probs, return_draws, type) {
  raw_score <- if ("raw_score" %in% type) {
    ppmc_rawscore_chisq(model = model, post_data = post_data,
                        probs = probs, return_draws = return_draws)
  } else {
    NULL
  }

  mod_res <- list(raw_score = raw_score)
  mod_res[sapply(mod_res, is.null)] <- NULL

  return(mod_res)
}

ppmc_rawscore_chisq <- function(model, post_data, probs, return_draws) {
  raw_score_post <- dtplyr::lazy_dt(post_data) %>%
    dplyr::summarize(raw_score = sum(.data$value), .by = c("resp", ".draw")) %>%
    dplyr::count(.data$.draw, .data$raw_score) %>%
    tibble::as_tibble() %>%
    tidyr::complete(.data$.draw, raw_score = 0:nrow(model$data$qmatrix),
                    fill = list(n = 0L))

  exp_raw_scores <- raw_score_post %>%
    dplyr::summarize(exp_resp = mean(.data$n), .by = "raw_score") %>%
    dplyr::mutate(exp_resp = sapply(.data$exp_resp,
                                    function(.x) max(.x, 0.0001)))

  chisq_ppmc <- raw_score_post %>%
    dplyr::left_join(exp_raw_scores, by = c("raw_score"),
                     relationship = "many-to-one") %>%
    dplyr::mutate(piece = ((.data$n - .data$exp_resp) ^ 2) / .data$exp_resp) %>%
    dplyr::summarize(chisq = sum(.data$piece), .by = ".draw")

  chisq_obs <- model$data$data %>%
    dplyr::summarize(raw_score = sum(.data$score), .by = "resp_id") %>%
    dplyr::count(.data$raw_score) %>%
    tidyr::complete(raw_score = 0:nrow(model$data$qmatrix),
                    fill = list(n = 0L)) %>%
    dplyr::left_join(exp_raw_scores, by = "raw_score",
                     relationship = "one-to-one") %>%
    dplyr::mutate(piece = ((.data$n - .data$exp_resp) ^ 2) / .data$exp_resp) %>%
    dplyr::summarize(chisq = sum(.data$piece)) %>%
    dplyr::pull("chisq")

  raw_score_res <- tibble::tibble(obs_chisq = chisq_obs,
                                  ppmc_mean = mean(chisq_ppmc$chisq),
                                  bounds = list(
                                    tibble::as_tibble_row(
                                      stats::quantile(chisq_ppmc$chisq,
                                                      probs = probs,
                                                      na.rm = TRUE)
                                    )
                                  ),
                                  ppp = mean(chisq_ppmc$chisq > chisq_obs)) %>%
    tidyr::unnest("bounds")

  if (return_draws > 0) {
    raw_score_res <- raw_score_res %>%
      dplyr::mutate(
        rawscore_samples = list(raw_score_post %>%
                                  tidyr::nest(raw_scores = -".draw") %>%
                                  dplyr::slice_sample(prop = return_draws) %>%
                                  dplyr::select(-".draw")),
        chisq_samples = list(chisq_ppmc %>%
                         dplyr::slice_sample(prop = return_draws) %>%
                         dplyr::pull("chisq")),
        .before = "ppp")
  }

  return(raw_score_res)
}

ppmc_item_fit <- function(model, post_data, attr, resp_prob, pi_draws, probs,
                          return_draws, type) {
  cond_prob <- if ("conditional_prob" %in% type) {
    ppmc_conditional_probs(model = model, attr = attr, resp_prob = resp_prob,
                           pi_draws = pi_draws, probs = probs,
                           return_draws = return_draws)
  } else {
    NULL
  }
  odds_ratio <- if ("odds_ratio" %in% type) {
    ppmc_odds_ratio(model = model, post_data = post_data, probs, return_draws)
  } else {
    NULL
  }
  pvalue <- if ("pvalue" %in% type) {
    ppmc_item_pvalue(model = model, post_data = post_data, probs, return_draws)
  } else {
    NULL
  }

  item_res <- list(conditional_prob = cond_prob,
                   odds_ratio = odds_ratio,
                   pvalue = pvalue)
  item_res[sapply(item_res, is.null)] <- NULL

  return(item_res)
}

ppmc_conditional_probs <- function(model, attr, resp_prob, pi_draws, probs,
                                   return_draws) {
  all_profiles <- profile_labels(attributes = attr)

  obs_class <- resp_prob %>%
    dplyr::mutate(dplyr::across(dplyr::where(posterior::is_rvar),
                                ~lapply(.x,
                                        function(x) {
                                          posterior::as_draws_df(x) %>%
                                            tibble::as_tibble()
                                        })
                                )) %>%
    tidyr::unnest(-"resp_id", names_sep = "_") %>%
    dplyr::select("resp_id",
                  dplyr::all_of(paste0(all_profiles$class[1], "_",
                                       c(".chain", ".iteration", ".draw"))),
                  dplyr::ends_with("_x")) %>%
    dplyr::rename_with(function(x) {
      x <- sub("_x", "", x)
      x <- sub("\\[[0-9,]*\\]_", "", x)
    }) %>%
    tidyr::pivot_longer(cols = -c("resp_id", ".chain", ".iteration", ".draw"),
                        names_to = "class_label",
                        values_to = "prob") %>%
    dtplyr::lazy_dt() %>%
    dplyr::mutate(max_class = .data$prob == max(.data$prob),
                  .by = c(".draw", "resp_id")) %>%
    dplyr::filter(.data$max_class) %>%
    dplyr::group_by(.data$.draw, .data$resp_id) %>%
    dplyr::slice_sample(n = 1) %>%
    dplyr::ungroup() %>%
    dplyr::left_join(all_profiles, by = c("class_label" = "class"),
                     relationship = "many-to-one") %>%
    dplyr::select(".draw", "resp_id", class = "class_id") %>%
    tibble::as_tibble()

  obs_cond_pval <- model$data$data %>%
    dplyr::mutate(resp_id = as.integer(.data$resp_id),
                  item_id = as.integer(.data$item_id)) %>%
    dplyr::left_join(obs_class, by = "resp_id",
                     relationship = "many-to-many") %>%
    dplyr::summarize(obs_cond_pval = mean(.data$score),
                     .by = c("item_id", "class")) %>%
    dplyr::arrange(.data$item_id, .data$class)

  cond_pval_res <- pi_draws %>%
    posterior::as_draws_df() %>%
    tibble::as_tibble() %>%
    tidyr::pivot_longer(-c(".chain", ".iteration", ".draw"),
                        names_to = c("i", "c"), values_to = "pi",
                        names_pattern = "pi\\[([0-9]*),([0-9]*)\\]",
                        names_transform = list(
                          i = ~as.integer(.x),
                          c = ~as.integer(.x)
                        )) %>%
    dplyr::select(-c(".chain", ".iteration", ".draw")) %>%
    tidyr::nest(cond_pval = "pi") %>%
    dplyr::arrange(.data$i, .data$c) %>%
    dplyr::left_join(obs_cond_pval, by = c("i" = "item_id",
                                           "c" = "class"),
                     relationship = "one-to-one") %>%
    dplyr::mutate(ppmc_mean = vapply(.data$cond_pval, function(.x) mean(.x$pi),
                                     double(1)),
                  bounds = lapply(.data$cond_pval,
                                  function(.x, probs) {
                                    tibble::as_tibble_row(
                                      stats::quantile(.x$pi,
                                                      probs = probs,
                                                      na.rm = TRUE)
                                    )
                                  },
                                  probs = probs),
                  ppp = mapply(function(exp, obs) {
                                 mean(exp$pi > obs)
                               },
                               .data$cond_pval, .data$obs_cond_pval)) %>%
    tidyr::unnest("bounds")

  if (return_draws > 0) {
    cond_pval_res <- cond_pval_res %>%
      dplyr::mutate(
        samples = lapply(.data$cond_pval,
                         function(.x) {
                           .x %>%
                             dplyr::slice_sample(prop = return_draws) %>%
                             dplyr::pull("pi")
                         }),
        .before = "ppp")
  }

  cond_pval_res <- cond_pval_res %>%
    dplyr::select(-"cond_pval") %>%
    dplyr::rename(item_id = "i", class_id = "c") %>%
    dplyr::left_join(all_profiles, by = "class_id",
                     relationship = "many-to-one") %>%
    dplyr::left_join(model$data$qmatrix %>%
                       dplyr::select(item = "item_id") %>%
                       dplyr::mutate(item_id = as.integer(.data$item)),
                     by = "item_id", relationship = "many-to-one") %>%
    dplyr::select(-"item_id", -"class_id") %>%
    dplyr::relocate("item", "class", .before = 1) %>%
    dplyr::rename(!!model$data$item_id := "item")

  return(cond_pval_res)
}

ppmc_odds_ratio <- function(model, post_data, probs, return_draws) {
  obs_or <- model$data$data %>%
    dplyr::mutate(resp_id = as.integer(.data$resp_id),
                  item_id = as.integer(.data$item_id)) %>%
    tidyr::pivot_wider(names_from = "item_id", values_from = "score") %>%
    dplyr::select(-"resp_id") %>%
    pw_or() %>%
    dplyr::rename(obs_or = "or")

  or_res <- post_data %>%
    dplyr::select(-"obs") %>%
    tidyr::pivot_wider(names_from = "item",
                       values_from = "value") %>%
    dplyr::select(-"resp") %>%
    tidyr::nest(dat = !dplyr::starts_with(".")) %>%
    dplyr::mutate(dat = lapply(.data$dat, pw_or)) %>%
    tidyr::unnest("dat") %>%
    tidyr::nest(samples = -c("item_1", "item_2")) %>%
    dplyr::left_join(obs_or, by = c("item_1", "item_2"),
                     relationship = "one-to-one") %>%
    dplyr::mutate(ppmc_mean = vapply(.data$samples, function(.x) mean(.x$or),
                                     double(1)),
                  bounds = lapply(.data$samples,
                                  function(.x, probs) {
                                    tibble::as_tibble_row(
                                      stats::quantile(.x$or,
                                                      probs = probs,
                                                      na.rm = TRUE)
                                    )
                                  },
                                  probs = probs),
                  ppp = mapply(function(exp, obs) {
                    mean(exp$or > obs)
                  },
                  .data$samples, .data$obs_or)) %>%
    tidyr::unnest("bounds")

  if (return_draws > 0) {
    or_res <- or_res %>%
      dplyr::relocate("samples", .before = "ppp") %>%
      dplyr::mutate(
        samples = lapply(.data$samples,
                         function(x) {
                           x %>%
                             dplyr::slice_sample(prop = return_draws) %>%
                             dplyr::pull("or")
                         }))
  } else {
    or_res <- dplyr::select(or_res, -"samples")
  }

  or_res <- or_res %>%
    dplyr::left_join(model$data$qmatrix %>%
                       dplyr::select(item = "item_id") %>%
                       dplyr::mutate(item_id = as.integer(.data$item)),
                     by = c("item_1" = "item_id"),
                     relationship = "many-to-one") %>%
    dplyr::left_join(model$data$qmatrix %>%
                       dplyr::select(item = "item_id") %>%
                       dplyr::mutate(item_id = as.integer(.data$item)),
                     by = c("item_2" = "item_id"),
                     relationship = "many-to-one") %>%
    dplyr::select(-"item_1", -"item_2") %>%
    dplyr::rename(item_1 = "item.x", item_2 = "item.y") %>%
    dplyr::relocate("item_1", "item_2", .before = 1)

  return(or_res)
}

pw_or <- function(dat) {
  dat <- as.matrix(dat)
  p <- ncol(dat)
  ind <- t(utils::combn(p, 2))
  nind <- nrow(ind)
  or <- numeric(nind)

  for (i in 1:nind) {
    xtab <- table(dat[, ind[i, 1]], dat[, ind[i, 2]])
    n00 <- xtab[1, 1]
    n01 <- xtab[1, 2]
    n10 <- xtab[2, 1]
    n11 <- xtab[2, 2]
    or[i] <- (n00 * n11) / (n01 * n10)
  }
  pwor <- tibble::as_tibble(ind, .name_repair = ~c("item_1", "item_2")) %>%
    dplyr::mutate(or = or)
  return(pwor)
}

ppmc_item_pvalue <- function(model, post_data, probs, return_draws) {
  obs_pvalue <- model$data$data %>%
    dplyr::mutate(item = as.numeric(.data$item_id)) %>%
    dplyr::summarize(obs_pvalue = mean(.data$score),
                     .by = c("item", "item_id"))

  pval_res <- post_data %>%
    dplyr::summarize(pvalue = mean(.data$value),
                     .by = c(".chain", ".iteration", ".draw", "item")) %>%
    tidyr::nest(samples = -"item") %>%
    dplyr::left_join(obs_pvalue, by = "item", relationship = "one-to-one") %>%
    dplyr::mutate(ppmc_mean = vapply(.data$samples,
                                     function(.x) mean(.x$pvalue),
                                     double(1)),
                  bounds = lapply(.data$samples,
                                  function(.x, probs) {
                                    tibble::as_tibble_row(
                                      stats::quantile(.x$pvalue,
                                                      probs = probs,
                                                      na.rm = TRUE)
                                    )
                                  },
                                  probs = probs),
                  ppp = mapply(function(exp, obs) {
                    mean(exp$pvalue > obs)
                  },
                  .data$samples, .data$obs_pvalue)) %>%
    tidyr::unnest("bounds")

  if (return_draws > 0) {
    pval_res <- pval_res %>%
      dplyr::relocate("samples", .before = "ppp") %>%
      dplyr::mutate(
        samples = lapply(.data$samples,
                         function(x) {
                           x %>%
                             dplyr::slice_sample(prop = return_draws) %>%
                             dplyr::pull("pvalue")
                         }))
  } else {
    pval_res <- dplyr::select(pval_res, -"samples")
  }

  pval_res %>%
    dplyr::select(-"item") %>%
    dplyr::rename(!!model$data$item_id := "item_id")
}
