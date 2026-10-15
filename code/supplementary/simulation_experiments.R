# ================================================================
# PART 1: Simulation study (DGP recovery, break/lag selection, MCMC)
# ================================================================


# 0. Numerical helper functions
rm(list = ls())
set.seed(123)

# Log of Cholesky's determinant
logdet_chol <- function(M) {
  M <- (M + t(M)) / 2
  ch <- tryCatch(chol(M), error = function(e) NULL)
  if (is.null(ch)) return(NA_real_)
  2 * sum(log(diag(ch)))
}
make_pd <- function(S, eps = 1e-8) {
  S <- (S + t(S)) / 2
  ev <- eigen(S, symmetric = TRUE, only.values = TRUE)$values
  minev <- min(ev)
  if (minev <= eps) {
    S <- S + diag(eps - minev + eps, nrow(S))
  }
  S
}
# Logarithm of the multivariate gamma function
log_multigamma <- function(a, n) {
  n * (n - 1) / 4 * log(pi) +
    sum(lgamma(a + (1 - seq_len(n)) / 2))
}
# Summing probabilities working with logarithms
log_sum_exp <- function(x) {
  bad <- is.na(x) | (is.infinite(x) & x > 0)
  if (any(bad)) {
    stop("log_sum_exp(): NA/NaN/+Inf detected; invalid states must be -Inf.")
  }
  x <- x[is.finite(x)]
  if (length(x) == 0) return(-Inf)
  m <- max(x)
  m + log(sum(exp(x - m)))
}
# Average of values in log space
log_mean_exp <- function(x) {
  log_sum_exp(x) - log(length(x))
}
# Readable label for a lag model
gamma_label <- function(gamma) {
  paste0(gamma, collapse = "")
}
# Build model space
make_gamma_grid <- function(pmax) {
  grid <- expand.grid(rep(list(0:1), pmax))
  mat <- as.matrix(grid)
  storage.mode(mat) <- "integer"
  colnames(mat) <- paste0("lag", seq_len(pmax))
  rownames(mat) <- apply(mat, 1, gamma_label)
  mat
}
# Multivariate normal simulation
rmvnorm_one <- function(mu, Sigma) {
  as.numeric(mu + t(chol(Sigma)) %*% rnorm(length(mu)))
}
# 1. DGP simulation: bivariate BVAR with one true break

simulate_bvar_break <- function(T, # Number obs returned
                                tau0,
                                pmax, # Max number of lag
                                c_list, # List of intercepts
                                A_list, # Nested list of autoregressive matrices
                                Sigma_list, # List of shock's cov matrix
                                burnin = 200) # Number of discarded initial simulated observations
  {
  n <- length(c_list[[1]]) #Number of variables
  TT <- T + burnin
  
  y_all <- matrix(0, nrow = TT + pmax, ncol = n)
  
  for (tt in (pmax + 1):(TT + pmax)) {
    obs <- tt - pmax - burnin
    s <- if (obs <= tau0) 1L else 2L
    
    mu <- c_list[[s]]
    for (ell in seq_len(pmax)) {
      mu <- mu + as.numeric(A_list[[s]][[ell]] %*% y_all[tt - ell, ])
    }
    y_all[tt, ] <- rmvnorm_one(mu, Sigma_list[[s]])
  }
  
  y <- y_all[(burnin + pmax + 1):(burnin + pmax + T), , drop = FALSE]
  colnames(y) <- paste0("y", seq_len(n))
  y
}

companion_radius <- function(A_list_regime, n) {
  p <- length(A_list_regime)
  C <- matrix(0, n * p, n * p)
  for (k in seq_len(p)) {
    C[1:n, ((k - 1) * n + 1):(k * n)] <- A_list_regime[[k]]
  }
  if (p > 1) {
    C[(n + 1):(n * p), 1:(n * (p - 1))] <- diag(n * (p - 1))
  }
  max(Mod(eigen(C, only.values = TRUE)$values))
}
# 2. Design matrix and blockwise lag selection

build_full_design <- function(y_full, pmax, T0 = pmax) {
  T <- nrow(y_full)
  n <- ncol(y_full)
  
  if (T0 < pmax) {
    stop("T0 must be >= pmax to have the required initial lags.")
  }
  if (T0 >= T) {
    stop("T0 must be smaller than the full sample length.")
  }
  
  t_index <- (T0 + 1):T
  N <- length(t_index)
  
  Y <- y_full[t_index, , drop = FALSE]
  Xfull <- matrix(1, nrow = N, ncol = 1 + n * pmax)
  
  coln <- "const"
  for (ell in seq_len(pmax)) {
    cols <- 1 + seq.int((ell - 1) * n + 1, ell * n)
    Xfull[, cols] <- y_full[t_index - ell, , drop = FALSE] 
    coln <- c(coln, paste0(colnames(y_full), "_L", ell))
  }
  colnames(Xfull) <- coln
  
  list(Y = Y, Xfull = Xfull, t_index = t_index)
}

select_X_from_gamma <- function(Xfull, gamma, n, pmax) {
  cols <- 1L
  for (ell in seq_len(pmax)) {
    if (gamma[ell] == 1L) {
      cols <- c(cols, 1L + seq.int((ell - 1) * n + 1, ell * n))
    }
  }
  Xfull[, cols, drop = FALSE]
}
# 3. Minnesota-style MNIW prior calibrated on the training sample

make_prior_info <- function(train_y,
                            pmax,
                            lambda_const = 10,
                            lambda_lag = 0.40,
                            lambda_decay = 1,
                            own_lag_mean = 0,
                            nu0_extra = 2) {
  n <- ncol(train_y)
  T0 <- nrow(train_y)
  
  if (T0 < 3) {
    stop("Training sample is too short to calibrate the prior.")
  }
  
  Y1 <- train_y[2:T0, , drop = FALSE]
  X1 <- cbind(1, train_y[1:(T0 - 1), , drop = FALSE])
  
  XtX <- crossprod(X1) + 1e-8 * diag(ncol(X1))
  A_hat <- solve(XtX, crossprod(X1, Y1))
  E_hat <- Y1 - X1 %*% A_hat
  
  df <- max(T0 - 1 - (1 + n), 1)
  Sigma_hat <- make_pd(crossprod(E_hat) / df)
  
  sigma2 <- diag(Sigma_hat)
  sigma2[!is.finite(sigma2) | sigma2 <= 0] <- 1
  
  nu0 <- n + nu0_extra
  if (nu0 <= n + 1) {
    stop("nu0 must be greater than n + 1 to have a finite IW mean.")
  }
  S0 <- make_pd((nu0 - n - 1) * Sigma_hat)
  
  list(
    n = n,
    pmax = pmax,
    T0 = T0,
    sigma2 = sigma2,
    Sigma_hat = Sigma_hat,
    lambda_const = lambda_const,
    lambda_lag = lambda_lag,
    lambda_decay = lambda_decay,
    own_lag_mean = own_lag_mean,
    nu0 = nu0,
    S0 = S0
  )
}

prior_mniw_for_gamma <- function(gamma, prior_info) {
  n <- prior_info$n
  pmax <- prior_info$pmax
  
  reg_info <- data.frame(type = "const", lag = 0L, pred = NA_integer_)
  
  for (ell in seq_len(pmax)) {
    if (gamma[ell] == 1L) {
      reg_info <- rbind(
        reg_info,
        data.frame(type = "lag", lag = ell, pred = seq_len(n))
      )
    }
  }
  
  q <- nrow(reg_info) 
  B0 <- matrix(0, nrow = q, ncol = n)
  V0_diag <- numeric(q)
  
  V0_diag[1] <- prior_info$lambda_const^2
  
  if (q > 1) {
    for (r in 2:q) {
      ell <- reg_info$lag[r]
      pred <- reg_info$pred[r]

      V0_diag[r] <- prior_info$lambda_lag^2 /
        (ell^(2 * prior_info$lambda_decay) * prior_info$sigma2[pred])
      
      if (ell == 1L) {
        B0[r, pred] <- prior_info$own_lag_mean
      }
    }
  }
  
  list(
    B0 = B0,
    V0 = diag(V0_diag, q),
    nu0 = prior_info$nu0,
    S0 = prior_info$S0,
    reg_info = reg_info
  )
}
# 4. Closed-form MNIW marginal likelihood

log_marginal_mniw <- function(Y, X, B0, V0, S0, nu0) {
  N <- nrow(Y)
  n <- ncol(Y)
  q <- ncol(X)
  
  if (nrow(B0) != q || ncol(B0) != n) {
    stop("Inconsistent dimensions across X, Y and B0.")
  }
  
  V0_inv <- solve(V0)
  Vn_inv <- V0_inv + crossprod(X)
  Vn <- solve(Vn_inv)
  
  Bn <- Vn %*% (V0_inv %*% B0 + crossprod(X, Y))
  
  Sn <- S0 + crossprod(Y) + t(B0) %*% V0_inv %*% B0 -
    t(Bn) %*% Vn_inv %*% Bn
  Sn <- make_pd(Sn)
  
  nu_n <- nu0 + N
  
  ld_Vn <- logdet_chol(Vn)
  ld_V0 <- logdet_chol(V0)
  ld_S0 <- logdet_chol(S0)
  ld_Sn <- logdet_chol(Sn)
  
  if (any(is.na(c(ld_Vn, ld_V0, ld_S0, ld_Sn)))) {
    return(-Inf)
  }
  
  # Integrated MNIW formula: constant pi^{-N*n/2}
  out <- - N * n / 2 * log(pi) +
    n / 2 * (ld_Vn - ld_V0) +
    nu0 / 2 * ld_S0 -
    nu_n / 2 * ld_Sn +
    log_multigamma(nu_n / 2, n) -
    log_multigamma(nu0 / 2, n)
  
  as.numeric(out)
}
# 5. Scan of lag models within a segment

scan_segment_lags <- function(Y_segment,
                              Xfull_segment,
                              gamma_grid,
                              prior_info) {
  J <- nrow(gamma_grid)
  logv <- rep(NA_real_, J)
  names(logv) <- rownames(gamma_grid)
  
  for (j in seq_len(J)) {
    gamma <- gamma_grid[j, ]
    Xj <- select_X_from_gamma(
      Xfull = Xfull_segment,
      gamma = gamma,
      n = prior_info$n,
      pmax = prior_info$pmax
    )
    pr <- prior_mniw_for_gamma(gamma, prior_info)
    
    logv[j] <- log_marginal_mniw(
      Y = Y_segment,
      X = Xj,
      B0 = pr$B0,
      V0 = pr$V0,
      S0 = pr$S0,
      nu0 = pr$nu0
    )
  }
  
  denom <- log_sum_exp(logv)
  
  scan <- data.frame(
    gamma = names(logv),
    logmarg = as.numeric(logv),
    postprob_segment = exp(logv - denom),
    stringsAsFactors = FALSE
  )
  scan <- scan[order(scan$logmarg, decreasing = TRUE), ]
  rownames(scan) <- NULL
  
  list(logmarg = logv, scan = scan)
}
# 6. BVAR analogue of facchange() for a fixed break

bvar_facchange_onebreak <- function(y,
                                    tau,
                                    pmax,
                                    gamma_grid,
                                    prior_info) {
  T0 <- prior_info$T0
  full <- build_full_design(y, pmax, T0 = T0)
  
  keep1 <- full$t_index <= tau
  keep2 <- full$t_index > tau
  
  if (sum(keep1) <= 0 || sum(keep2) <= 0) {
    stop("Invalid break: at least one segment is empty after initial lags.")
  }
  
  scan1 <- scan_segment_lags(
    Y_segment = full$Y[keep1, , drop = FALSE],
    Xfull_segment = full$Xfull[keep1, , drop = FALSE],
    gamma_grid = gamma_grid,
    prior_info = prior_info
  )
  
  scan2 <- scan_segment_lags(
    Y_segment = full$Y[keep2, , drop = FALSE],
    Xfull_segment = full$Xfull[keep2, , drop = FALSE],
    gamma_grid = gamma_grid,
    prior_info = prior_info
  )
  
  pair_logmarg <- outer(scan1$logmarg, scan2$logmarg, "+")
  dimnames(pair_logmarg) <- list(
    gamma_regime1 = names(scan1$logmarg),
    gamma_regime2 = names(scan2$logmarg)
  )
  
  integrated_logmarg <- log_mean_exp(as.vector(pair_logmarg))
  
  pair_postprob <- exp(pair_logmarg - log_sum_exp(as.vector(pair_logmarg)))
  
  pair_table <- as.data.frame(as.table(pair_logmarg), stringsAsFactors = FALSE)
  names(pair_table) <- c("gamma1", "gamma2", "logmarg_pair")
  pair_table$postprob_pair <- as.vector(pair_postprob)
  pair_table <- pair_table[order(pair_table$logmarg_pair, decreasing = TRUE), ]
  rownames(pair_table) <- NULL
  
  list(
    tau = tau,
    logmarg = integrated_logmarg,
    scanls = list(regime1 = scan1$scan, regime2 = scan2$scan),
    logmargls = list(regime1 = scan1$logmarg, regime2 = scan2$logmarg),
    pair_logmarg = pair_logmarg,
    pair_postprob = pair_postprob,
    pair_table = pair_table,
    best_pair = pair_table[1, ],
    nobs_segment = c(regime1 = sum(keep1), regime2 = sum(keep2))
  )
}
# 7. Candidate-break scan

bvar_changescan_onebreak <- function(y,
                                     tau_grid,
                                     pmax,
                                     gamma_grid,
                                     prior_info,
                                     verbose = TRUE) {
  fits <- vector("list", length(tau_grid))
  names(fits) <- as.character(tau_grid)
  
  break_summary <- data.frame(
    tau = tau_grid,
    logmarg = NA_real_,
    best_gamma1 = NA_character_,
    best_gamma2 = NA_character_,
    stringsAsFactors = FALSE
  )
  
  for (i in seq_along(tau_grid)) {
    tau <- tau_grid[i]
    if (verbose && (i %% 10 == 1 || i == length(tau_grid))) {
      cat("Evaluating tau", tau, "(", i, "of", length(tau_grid), ")\n")
    }
    
    fit <- bvar_facchange_onebreak(
      y = y,
      tau = tau,
      pmax = pmax,
      gamma_grid = gamma_grid,
      prior_info = prior_info
    )
    
    fits[[i]] <- fit
    break_summary$logmarg[i] <- fit$logmarg
    break_summary$best_gamma1[i] <- fit$best_pair$gamma1
    break_summary$best_gamma2[i] <- fit$best_pair$gamma2
  }
  
  break_summary$postprob_tau <- exp(
    break_summary$logmarg - log_sum_exp(break_summary$logmarg)
  )
  break_summary <- break_summary[order(break_summary$tau), ]
  rownames(break_summary) <- NULL
  
  list(break_summary = break_summary, fits = fits)
}
# 8. Simulation parameters


T0_len <- 200
T_est <- 4000
T_sim <- T0_len + T_est

tau_est <- 2000
tau0 <- T0_len + tau_est

pmax <- 3
n <- 2

zeroA <- matrix(0, n, n)

A11 <- matrix(c(0.45,  0.10,
                -0.05,  0.35), nrow = n, byrow = TRUE)
A13 <- matrix(c(0.18,  0.00,
                0.08, -0.15), nrow = n, byrow = TRUE)

A22 <- matrix(c(-0.35, 0.15,
                0.10, 0.25), nrow = n, byrow = TRUE)

c_list <- list(
  c(0.00,  0.00),
  c(0.20, -0.10)
)

A_list <- list(
  list(A11, zeroA, A13),
  list(zeroA, A22, zeroA)
)

Sigma_list <- list(
  matrix(c(1.00,  0.30,
           0.30,  1.00), nrow = n, byrow = TRUE),
  matrix(c(0.70, -0.20,
           -0.20,  1.20), nrow = n, byrow = TRUE)
)

true_gamma1 <- c(1L, 0L, 1L)
true_gamma2 <- c(0L, 1L, 0L)

rho1 <- companion_radius(A_list[[1]], n)
rho2 <- companion_radius(A_list[[2]], n)
cat(sprintf("Spectral radius, regime 1: %.4f  stable: %s\n",
            rho1, if (rho1 < 1) "YES" else "NO"))
cat(sprintf("Spectral radius, regime 2: %.4f  stable: %s\n\n",
            rho2, if (rho2 < 1) "YES" else "NO"))

y <- simulate_bvar_break(
  T = T_sim,
  tau0 = tau0,
  pmax = pmax,
  c_list = c_list,
  A_list = A_list,
  Sigma_list = Sigma_list,
  burnin = 200
)

# Training sample separated from the likelihood.
train_y <- y[1:T0_len, , drop = FALSE]
y_full <- y

cat("Data dimension:", dim(y_full), "\n")
cat("Training sample: t = 1,...,", T0_len, "\n", sep = "")
cat("Estimation sample: t = ", T0_len + 1, ",...,", T_sim, "\n", sep = "")
cat("True break in the full sample, tau0:", tau0, "\n")
cat("True break in the estimation sample, tau_est:", tau_est, "\n")
cat("True gamma, regime 1:", gamma_label(true_gamma1), "\n")
cat("True gamma, regime 2:", gamma_label(true_gamma2), "\n\n")

cat("Sample mean in the estimation sample:\n")
print(round(colMeans(y_full[(T0_len + 1):T_sim, , drop = FALSE]), 5))
cat("Sample standard deviation in the estimation sample:\n")
print(round(apply(y_full[(T0_len + 1):T_sim, , drop = FALSE], 2, sd), 5))
# 9. known break, tau = tau0

gamma_grid <- make_gamma_grid(pmax)

prior_info <- make_prior_info(
  train_y = train_y,
  pmax = pmax,
  lambda_const = 10,
  lambda_lag = 0.40,
  lambda_decay = 1,
  own_lag_mean = 0,
  nu0_extra = 2
)

out_known <- bvar_facchange_onebreak(
  y = y_full,
  tau = tau0,
  pmax = pmax,
  gamma_grid = gamma_grid,
  prior_info = prior_info
)

cat("Observations in the estimation segments:", out_known$nobs_segment, "\n")
cat("Integrated log marginal likelihood:", out_known$logmarg, "\n\n")

cat("Top 10 pairs (gamma1, gamma2) among the 64 combinations:\n")
print(head(out_known$pair_table, 10))

cat("Top models, regime 1:\n")
print(head(out_known$scanls$regime1, 8))
cat("\nTop models, regime 2:\n")
print(head(out_known$scanls$regime2, 8))

cat("True regime 1:", gamma_label(true_gamma1),
    " | best:", out_known$scanls$regime1$gamma[1], "\n")
cat("True regime 2:", gamma_label(true_gamma2),
    " | best:", out_known$scanls$regime2$gamma[1], "\n\n")

top5_pairs <- head(out_known$pair_table, 5)
pair_labels <- paste0(top5_pairs$gamma1, ",", top5_pairs$gamma2)

op <- par(no.readonly = TRUE)
par(mar = c(7, 5, 3, 2))
bp <- barplot(
  top5_pairs$postprob_pair,
  names.arg = pair_labels,
  las = 2,
  ylab = "Posterior probability",
  main = "Top 5 posterior probabilities: 64 joint lag combinations\n(break fixed at the true value)"
)
text(bp, top5_pairs$postprob_pair, labels = round(top5_pairs$postprob_pair, 3),
     pos = 3, cex = 0.8)
par(op)
# 10. break varying around the true value

tau_grid <- (tau0 - 50):(tau0 + 50)

# Minimum-segment-length check in the estimation sample.
n_min <- 200
full_des <- build_full_design(y_full, pmax, T0 = T0_len)
tau_grid <- tau_grid[
  sapply(tau_grid, function(tau) {
    k1 <- sum(full_des$t_index <= tau)
    k2 <- sum(full_des$t_index > tau)
    k1 >= n_min && k2 >= n_min
  })
]

out_breakscan <- bvar_changescan_onebreak(
  y = y_full,
  tau_grid = tau_grid,
  pmax = pmax,
  gamma_grid = gamma_grid,
  prior_info = prior_info,
  verbose = TRUE
)

bs <- out_breakscan$break_summary
bs$tau_est <- bs$tau - T0_len

best_ind <- which.max(bs$logmarg)
best_tau <- bs$tau[best_ind]
best_tau_est <- bs$tau_est[best_ind]

cat("True absolute break tau0:", tau0, "\n")
cat("True break in the estimation sample, tau_est:", tau_est, "\n")
cat("Estimated absolute break:", best_tau, "\n")
cat("Estimated break in the estimation sample:", best_tau_est, "\n")
cat("Error relative to tau_est:", best_tau_est - tau_est, "\n\n")

cat("Top 10 candidate breaks:\n")
top10 <- bs[order(bs$logmarg, decreasing = TRUE), ]
top10$dist_tau_est <- top10$tau_est - tau_est
print(head(top10[, c("tau", "tau_est", "dist_tau_est", "logmarg",
                     "postprob_tau", "best_gamma1", "best_gamma2")], 10))

# Posterior summary for tau.
tau_post_mean <- sum(bs$tau_est * bs$postprob_tau)
tau_post_sd <- sqrt(sum((bs$tau_est - tau_post_mean)^2 * bs$postprob_tau))
cdf <- cumsum(bs$postprob_tau[order(bs$tau_est)])
tau_sorted <- sort(bs$tau_est)
ci_lo <- tau_sorted[which(cdf >= 0.025)[1]]
ci_hi <- tau_sorted[which(cdf >= 0.975)[1]]

cat(sprintf("Posterior mean: %.2f\n", tau_post_mean))
cat(sprintf("Posterior SD: %.2f\n", tau_post_sd))
cat(sprintf("CI 95%%: [%d, %d]\n", ci_lo, ci_hi))
cat("True tau_est in the 95% CI:", if (tau_est >= ci_lo && tau_est <= ci_hi) "YES" else "NO", "\n\n")

op <- par(no.readonly = TRUE)
par(mar = c(5, 5, 3, 2))
plot(
  bs$tau_est,
  bs$logmarg,
  type = "l",
  lwd = 2,
  xlab = "Break in estimation sample",
  ylab = expression(log~m(Y~"|"~tau[est])),
  main = "Break scan: marginal likelihood integrated over lags"
)
abline(v = tau_est, lty = 2, lwd = 2, col = "red")
abline(v = best_tau_est, lty = 3, lwd = 2, col = "red")
legend("bottomright", legend = c("true break", "MAP estimate"),
       lty = c(2, 3), lwd = 2, col = "red", bty = "n", cex = 0.85)
par(op)

# Plot: discrete posterior over candidate breaks.
op <- par(no.readonly = TRUE)
par(mar = c(5, 5, 3, 2))
plot(
  bs$tau_est,
  bs$postprob_tau,
  type = "h",
  lwd = 2,
  xlab = "Break in estimation sample",
  ylab = "Discrete posterior probability",
  main = "Posterior over candidate breaks"
)
abline(v = tau_est, lty = 2, lwd = 2, col = "red")
abline(v = best_tau_est, lty = 3, lwd = 2, col = "red")
legend("topleft", legend = c("true break", "MAP estimate"),
       lty = c(2, 3), lwd = 2, col = "red", bty = "n", cex = 0.85)
par(op)
# 11. Final reusable object

results <- list(
  y_full = y_full,
  train_y = train_y,
  true = list(
    T0_len = T0_len,
    T_est = T_est,
    T_sim = T_sim,
    tau_est = tau_est,
    tau0 = tau0,
    pmax = pmax,
    gamma1 = true_gamma1,
    gamma2 = true_gamma2,
    A_list = A_list,
    Sigma_list = Sigma_list
  ),
  gamma_grid = gamma_grid,
  prior_info = prior_info,
  known_break = out_known,
  break_scan = out_breakscan,
  break_summary = bs
)
# 12. Utility functions reused by the general live MCMC (Section 18)

label_to_gamma <- function(label) {
  as.integer(strsplit(label, split = "")[[1]])
}

flip_gamma_label <- function(gamma_label_current, pmax) {
  g <- label_to_gamma(gamma_label_current)
  ell <- sample(seq_len(pmax), size = 1)
  g[ell] <- 1L - g[ell]
  
  list(
    gamma_label = gamma_label(g),
    flipped_lag = ell
  )
}

posterior_distance <- function(p_exact, p_mcmc) {
  p_exact <- as.numeric(p_exact)
  p_mcmc <- as.numeric(p_mcmc)
  
  l1 <- sum(abs(p_exact - p_mcmc))
  tv <- 0.5 * l1
  max_abs <- max(abs(p_exact - p_mcmc))
  rmse <- sqrt(mean((p_exact - p_mcmc)^2))
  
  corr <- suppressWarnings(cor(p_exact, p_mcmc))
  if (!is.finite(corr)) corr <- NA_real_
  
  data.frame(
    L1_distance = l1,
    total_variation = tv,
    max_abs_error = max_abs,
    RMSE = rmse,
    correlation = corr
  )
}

compute_convergence_diagnostics_general <- function(chains, m) {
  n_draws_min <- min(sapply(chains, function(z) nrow(z$breaks_draws)))
  
  rhat_per_break <- numeric(m)
  ess_bulk_per_break <- numeric(m)
  ess_tail_per_break <- numeric(m)
  
  for (k in seq_len(m)) {
    mat_k <- sapply(chains, function(z) z$breaks_draws[seq_len(n_draws_min), k])
    rhat_per_break[k] <- posterior::rhat(mat_k)
    ess_bulk_per_break[k] <- posterior::ess_bulk(mat_k)
    ess_tail_per_break[k] <- posterior::ess_tail(mat_k)
  }
  
  names(rhat_per_break) <- paste0("tau", seq_len(m))
  names(ess_bulk_per_break) <- paste0("tau", seq_len(m))
  names(ess_tail_per_break) <- paste0("tau", seq_len(m))
  
  list(
    Rhat = rhat_per_break,
    ESS_bulk = ess_bulk_per_break,
    ESS_tail = ess_tail_per_break
  )
}

compute_gamma_diagnostics_general <- function(chains, n_regimes, pmax) {
  n_draws_min <- min(sapply(chains, function(z) nrow(z$gammas_draws)))
  
  pip <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  rhat <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  ess_bulk <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  ess_tail <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  min_transitions <- matrix(NA_integer_, nrow = n_regimes, ncol = pmax)
  
  for (s in seq_len(n_regimes)) {
    for (ell in seq_len(pmax)) {
      
      ind_mat <- sapply(chains, function(z) {
        labs <- z$gammas_draws[seq_len(n_draws_min), s]
        as.integer(substr(labs, ell, ell))
      })
      
      pip[s, ell] <- mean(ind_mat)
      rhat[s, ell] <- posterior::rhat(ind_mat)
      ess_bulk[s, ell] <- posterior::ess_bulk(ind_mat)
      ess_tail[s, ell] <- posterior::ess_tail(ind_mat)
      
      transitions_per_chain <- apply(ind_mat, 2, function(col) sum(diff(col) != 0L))
      min_transitions[s, ell] <- min(transitions_per_chain)
    }
  }
  
  reg_names <- paste0("regime", seq_len(n_regimes))
  lag_names <- paste0("lag", seq_len(pmax))
  dimnames(pip) <- dimnames(rhat) <- dimnames(ess_bulk) <- dimnames(ess_tail) <-
    dimnames(min_transitions) <- list(reg_names, lag_names)
  
  list(PIP = pip, Rhat = rhat, ESS_bulk = ess_bulk, ESS_tail = ess_tail,
       MinTransitions = min_transitions)
}
# 13. Extension: simulated BVAR with two structural breaks
# 13.1 General simulation with multiple breaks

simulate_bvar_breaks <- function(T,
                                 breaks,
                                 pmax,
                                 c_list,
                                 A_list,
                                 Sigma_list,
                                 burnin = 200) {
  n <- length(c_list[[1]])
  m <- length(breaks)
  n_regimes <- m + 1L
  
  if (length(c_list) != n_regimes) {
    stop("c_list must have length m + 1.")
  }
  if (length(A_list) != n_regimes) {
    stop("A_list must have length m + 1.")
  }
  if (length(Sigma_list) != n_regimes) {
    stop("Sigma_list must have length m + 1.")
  }
  
  TT <- T + burnin
  y_all <- matrix(0, nrow = TT + pmax, ncol = n)
  
  for (tt in (pmax + 1):(TT + pmax)) {
    obs <- tt - pmax - burnin
    
    s <- sum(obs > breaks) + 1L
    s <- max(1L, min(s, n_regimes))
    
    mu <- c_list[[s]]
    
    for (ell in seq_len(pmax)) {
      mu <- mu + as.numeric(A_list[[s]][[ell]] %*% y_all[tt - ell, ])
    }
    
    y_all[tt, ] <- rmvnorm_one(mu, Sigma_list[[s]])
  }
  
  y <- y_all[(burnin + pmax + 1):(burnin + pmax + T), , drop = FALSE]
  colnames(y) <- paste0("y", seq_len(n))
  y
}
# 13.2 Segmentation and marginal likelihood for multiple breaks

make_segment_masks_from_breaks <- function(t_index, breaks) {
  breaks <- sort(as.integer(breaks))
  n_seg <- length(breaks) + 1L
  
  masks <- vector("list", n_seg)
  
  for (s in seq_len(n_seg)) {
    if (s == 1L) {
      masks[[s]] <- t_index <= breaks[1]
    } else if (s == n_seg) {
      masks[[s]] <- t_index > breaks[length(breaks)]
    } else {
      masks[[s]] <- t_index > breaks[s - 1L] & t_index <= breaks[s]
    }
  }
  
  names(masks) <- paste0("regime", seq_len(n_seg))
  masks
}

bvar_facchange_breaks <- function(y,
                                  breaks,
                                  pmax,
                                  gamma_grid,
                                  prior_info,
                                  full_design = NULL) {
  breaks <- sort(as.integer(breaks))
  n_seg <- length(breaks) + 1L
  gamma_labels <- rownames(gamma_grid)
  
  if (is.null(full_design)) {
    full_design <- build_full_design(y, pmax, T0 = prior_info$T0)
  }
  
  masks <- make_segment_masks_from_breaks(
    t_index = full_design$t_index,
    breaks = breaks
  )
  
  nobs_segment <- sapply(masks, sum)
  
  if (any(nobs_segment <= 0)) {
    stop("At least one segment is empty.")
  }
  
  scans <- vector("list", n_seg)
  logmargls <- vector("list", n_seg)
  
  for (s in seq_len(n_seg)) {
    scans[[s]] <- scan_segment_lags(
      Y_segment = full_design$Y[masks[[s]], , drop = FALSE],
      Xfull_segment = full_design$Xfull[masks[[s]], , drop = FALSE],
      gamma_grid = gamma_grid,
      prior_info = prior_info
    )
    
    logmargls[[s]] <- scans[[s]]$logmarg
  }
  
  names(scans) <- paste0("regime", seq_len(n_seg))
  names(logmargls) <- paste0("regime", seq_len(n_seg))
  
  # All J^(m+1) model combinations.
  combo_index <- expand.grid(
    rep(list(seq_along(gamma_labels)), n_seg),
    stringsAsFactors = FALSE
  )
  names(combo_index) <- paste0("g", seq_len(n_seg))
  
  combo_logmarg <- numeric(nrow(combo_index))
  
  for (r in seq_len(nrow(combo_index))) {
    tmp <- 0
    for (s in seq_len(n_seg)) {
      tmp <- tmp + logmargls[[s]][combo_index[r, s]]
    }
    combo_logmarg[r] <- tmp
  }
  
  combo_table <- data.frame(
    combo_index,
    logmarg_combo = combo_logmarg,
    stringsAsFactors = FALSE
  )
  
  for (s in seq_len(n_seg)) {
    combo_table[[paste0("gamma", s)]] <-
      gamma_labels[combo_table[[paste0("g", s)]]]
  }
  
  keep_cols <- c(paste0("gamma", seq_len(n_seg)), "logmarg_combo")
  combo_table <- combo_table[, keep_cols]
  
  combo_table$postprob_combo <- exp(
    combo_table$logmarg_combo - log_sum_exp(combo_table$logmarg_combo)
  )
  
  combo_table <- combo_table[
    order(combo_table$logmarg_combo, decreasing = TRUE),
  ]
  rownames(combo_table) <- NULL
  
  integrated_logmarg <- sum(sapply(logmargls, log_mean_exp))
  
  out <- list(
    breaks = breaks,
    logmarg = integrated_logmarg,
    scanls = lapply(scans, function(z) z$scan),
    logmargls = logmargls,
    combo_table = combo_table,
    best_combo = combo_table[1, ],
    nobs_segment = nobs_segment
  )
  
  out
}
# 13.3 Local exhaustive scan over two breaks

bvar_changescan_twobreak <- function(y,
                                     tau1_grid,
                                     tau2_grid,
                                     pmax,
                                     gamma_grid,
                                     prior_info,
                                     min_segment_length,
                                     verbose = TRUE,
                                     store_fits = TRUE) {
  full_design <- build_full_design(y, pmax, T0 = prior_info$T0)
  
  candidates <- expand.grid(
    tau1 = tau1_grid,
    tau2 = tau2_grid
  )
  
  candidates <- candidates[candidates$tau1 < candidates$tau2, ]
  
  # Minimum-segment-length check.
  valid <- apply(candidates, 1, function(z) {
    tau1 <- z[1]
    tau2 <- z[2]
    
    k1 <- sum(full_design$t_index <= tau1)
    k2 <- sum(full_design$t_index > tau1 & full_design$t_index <= tau2)
    k3 <- sum(full_design$t_index > tau2)
    
    all(c(k1, k2, k3) >= min_segment_length)
  })
  
  candidates <- candidates[valid, ]
  candidates <- candidates[order(candidates$tau1, candidates$tau2), ]
  rownames(candidates) <- NULL
  
  n_cand <- nrow(candidates)
  
  fits <- vector("list", n_cand)
  names(fits) <- paste(candidates$tau1, candidates$tau2, sep = "_")
  
  break_summary <- data.frame(
    tau1 = candidates$tau1,
    tau2 = candidates$tau2,
    logmarg = NA_real_,
    best_gamma1 = NA_character_,
    best_gamma2 = NA_character_,
    best_gamma3 = NA_character_,
    stringsAsFactors = FALSE
  )
  
  for (i in seq_len(n_cand)) {
    tau1 <- candidates$tau1[i]
    tau2 <- candidates$tau2[i]
    
    if (verbose && (i %% 50 == 1 || i == n_cand)) {
      cat("Evaluating pair", i, "of", n_cand,
          "| tau1 =", tau1,
          "| tau2 =", tau2, "\n")
    }
    
    fit <- bvar_facchange_breaks(
      y = y,
      breaks = c(tau1, tau2),
      pmax = pmax,
      gamma_grid = gamma_grid,
      prior_info = prior_info,
      full_design = full_design
    )
    
    if (store_fits) {
      fits[[i]] <- fit
    }
    
    break_summary$logmarg[i] <- fit$logmarg
    break_summary$best_gamma1[i] <- fit$best_combo$gamma1
    break_summary$best_gamma2[i] <- fit$best_combo$gamma2
    break_summary$best_gamma3[i] <- fit$best_combo$gamma3
  }
  
  break_summary$postprob_breaks <- exp(
    break_summary$logmarg - log_sum_exp(break_summary$logmarg)
  )
  
  break_summary <- break_summary[order(break_summary$tau1,
                                       break_summary$tau2), ]
  rownames(break_summary) <- NULL
  
  if (!store_fits) {
    best_i <- which.max(break_summary$logmarg)
    best_key <- paste(break_summary$tau1[best_i], break_summary$tau2[best_i],
                      sep = "_")
    fits[[best_key]] <- bvar_facchange_breaks(
      y = y,
      breaks = c(break_summary$tau1[best_i], break_summary$tau2[best_i]),
      pmax = pmax,
      gamma_grid = gamma_grid,
      prior_info = prior_info,
      full_design = full_design
    )
  }
  
  list(
    break_summary = break_summary,
    fits = fits,
    candidates = candidates
  )
}
# 13.4 Posterior summary for two breaks

summarise_twobreak_scan <- function(out_scan,
                                    T0,
                                    tau1_true_est,
                                    tau2_true_est,
                                    true_gamma_labels) {
  bs <- out_scan$break_summary
  
  bs$tau1_est <- bs$tau1 - T0
  bs$tau2_est <- bs$tau2 - T0
  
  best <- bs[which.max(bs$logmarg), ]
  top10 <- bs[order(bs$logmarg, decreasing = TRUE), ]
  top10 <- head(top10, 10)
  
  tau1_post <- aggregate(
    postprob_breaks ~ tau1 + tau1_est,
    data = bs,
    FUN = sum
  )
  tau1_post <- tau1_post[order(tau1_post$postprob_breaks,
                               decreasing = TRUE), ]
  names(tau1_post)[names(tau1_post) == "postprob_breaks"] <-
    "postprob_tau1"
  
  tau2_post <- aggregate(
    postprob_breaks ~ tau2 + tau2_est,
    data = bs,
    FUN = sum
  )
  tau2_post <- tau2_post[order(tau2_post$postprob_breaks,
                               decreasing = TRUE), ]
  names(tau2_post)[names(tau2_post) == "postprob_breaks"] <-
    "postprob_tau2"
  
  tau1_mean <- sum(bs$tau1_est * bs$postprob_breaks)
  tau2_mean <- sum(bs$tau2_est * bs$postprob_breaks)
  
  tau1_sd <- sqrt(sum((bs$tau1_est - tau1_mean)^2 * bs$postprob_breaks))
  tau2_sd <- sqrt(sum((bs$tau2_est - tau2_mean)^2 * bs$postprob_breaks))
  
  best_key <- paste(best$tau1, best$tau2, sep = "_")
  best_fit <- out_scan$fits[[best_key]]
  
  true_pair_mass_best_break <- NA_real_
  
  if (!is.null(best_fit)) {
    true_rows <- best_fit$combo_table$gamma1 == true_gamma_labels[1] &
      best_fit$combo_table$gamma2 == true_gamma_labels[2] &
      best_fit$combo_table$gamma3 == true_gamma_labels[3]
    
    true_pair_mass_best_break <- sum(best_fit$combo_table$postprob_combo[true_rows])
  }
  
  validation <- data.frame(
    metric = c(
      "tau1_true_est",
      "tau2_true_est",
      "tau1_mode_est",
      "tau2_mode_est",
      "tau1_error",
      "tau2_error",
      "tau1_post_mean",
      "tau2_post_mean",
      "tau1_post_sd",
      "tau2_post_sd",
      "best_gamma1",
      "best_gamma2",
      "best_gamma3",
      "true_gamma1",
      "true_gamma2",
      "true_gamma3",
      "true_gamma_combo_mass_at_best_break"
    ),
    value = c(
      tau1_true_est,
      tau2_true_est,
      best$tau1_est,
      best$tau2_est,
      best$tau1_est - tau1_true_est,
      best$tau2_est - tau2_true_est,
      tau1_mean,
      tau2_mean,
      tau1_sd,
      tau2_sd,
      best$best_gamma1,
      best$best_gamma2,
      best$best_gamma3,
      true_gamma_labels[1],
      true_gamma_labels[2],
      true_gamma_labels[3],
      true_pair_mass_best_break
    ),
    stringsAsFactors = FALSE
  )
  
  list(
    break_summary = bs,
    best = best,
    top10 = top10,
    tau1_post = tau1_post,
    tau2_post = tau2_post,
    best_fit = best_fit,
    validation = validation
  )
}
# 13.5 Plots for two breaks

plot_twobreak_logmarg_surface <- function(summary_2b,
                                          tau1_true_est,
                                          tau2_true_est,
                                          label_suffix = "") {
  bs <- summary_2b$break_summary
  
  x <- sort(unique(bs$tau1_est))
  y <- sort(unique(bs$tau2_est))
  
  z <- matrix(NA_real_, nrow = length(x), ncol = length(y))
  
  for (i in seq_len(nrow(bs))) {
    ix <- match(bs$tau1_est[i], x)
    iy <- match(bs$tau2_est[i], y)
    z[ix, iy] <- bs$logmarg[i]
  }
  
  op <- par(no.readonly = TRUE)
  par(mar = c(5, 5, 3, 2))
  
  image(
    x = x,
    y = y,
    z = z,
    xlab = "Break 1 in estimation sample",
    ylab = "Break 2 in estimation sample",
    main = paste0("Two breaks: log marginal likelihood", label_suffix)
  )
  
  points(tau1_true_est, tau2_true_est, pch = 4, lwd = 2)
  points(summary_2b$best$tau1_est, summary_2b$best$tau2_est,
         pch = 1, lwd = 2)
  
  legend(
    "topleft",
    legend = c("true breaks", "maximum"),
    pch = c(4, 1),
    lwd = c(2, 2),
    bty = "n"
  )
  
  par(op)
}

plot_twobreak_marginals <- function(summary_2b,
                                    tau1_true_est,
                                    tau2_true_est,
                                    label_suffix = "") {
  op <- par(no.readonly = TRUE)
  
  par(mar = c(5, 5, 3, 2))
  plot(
    summary_2b$tau1_post$tau1_est,
    summary_2b$tau1_post$postprob_tau1,
    type = "h",
    lwd = 2,
    xlab = "Break 1 in estimation sample",
    ylab = "Marginal posterior",
    main = paste0("Marginal posterior of tau1", label_suffix)
  )
  abline(v = tau1_true_est, lty = 2, lwd = 2, col = "red")
  abline(v = summary_2b$best$tau1_est, lty = 3, lwd = 2, col = "red")
  legend("topleft", legend = c("true break", "MAP estimate"),
         lty = c(2, 3), lwd = 2, col = "red", bty = "n", cex = 0.85)
  
  par(mar = c(5, 5, 3, 2))
  plot(
    summary_2b$tau2_post$tau2_est,
    summary_2b$tau2_post$postprob_tau2,
    type = "h",
    lwd = 2,
    xlab = "Break 2 in estimation sample",
    ylab = "Marginal posterior",
    main = paste0("Marginal posterior of tau2", label_suffix)
  )
  abline(v = tau2_true_est, lty = 2, lwd = 2, col = "red")
  abline(v = summary_2b$best$tau2_est, lty = 3, lwd = 2, col = "red")
  legend("topleft", legend = c("true break", "MAP estimate"),
         lty = c(2, 3), lwd = 2, col = "red", bty = "n", cex = 0.85)
  
  par(op)
}
# 14. Execution: simulation with two breaks

set.seed(321)

T0_len_2b <- 200
T_est_2b <- 2400
T_sim_2b <- T0_len_2b + T_est_2b

tau1_est_2b <- 800
tau2_est_2b <- 1600

tau1_0_2b <- T0_len_2b + tau1_est_2b
tau2_0_2b <- T0_len_2b + tau2_est_2b

pmax_2b <- 3
n_2b <- 2

zeroA_2b <- matrix(0, n_2b, n_2b)

# Regime 1: gamma = 101
A1_L1_2b <- matrix(c(0.45,  0.10,
                     -0.05,  0.35), nrow = n_2b, byrow = TRUE)
A1_L3_2b <- matrix(c(0.18,  0.00,
                     0.08, -0.15), nrow = n_2b, byrow = TRUE)

# Regime 2: gamma = 010
A2_L2_2b <- matrix(c(-0.35, 0.15,
                     0.10, 0.25), nrow = n_2b, byrow = TRUE)

# Regime 3: gamma = 110
A3_L1_2b <- matrix(c(0.25, -0.10,
                     0.05,  0.30), nrow = n_2b, byrow = TRUE)
A3_L2_2b <- matrix(c(-0.15, 0.05,
                     0.08, -0.20), nrow = n_2b, byrow = TRUE)

c_list_2b <- list(
  c(0.00,  0.00),
  c(0.20, -0.10),
  c(-0.15, 0.15)
)

A_list_2b <- list(
  list(A1_L1_2b, zeroA_2b, A1_L3_2b),
  list(zeroA_2b, A2_L2_2b, zeroA_2b),
  list(A3_L1_2b, A3_L2_2b, zeroA_2b)
)

Sigma_list_2b <- list(
  matrix(c(1.00,  0.30,
           0.30,  1.00), nrow = n_2b, byrow = TRUE),
  matrix(c(0.70, -0.20,
           -0.20,  1.20), nrow = n_2b, byrow = TRUE),
  matrix(c(1.10,  0.15,
           0.15,  0.80), nrow = n_2b, byrow = TRUE)
)

true_gamma1_2b <- c(1L, 0L, 1L)
true_gamma2_2b <- c(0L, 1L, 0L)
true_gamma3_2b <- c(1L, 1L, 0L)

true_gamma_labels_2b <- c(
  gamma_label(true_gamma1_2b),
  gamma_label(true_gamma2_2b),
  gamma_label(true_gamma3_2b)
)

rho_2b <- sapply(seq_along(A_list_2b), function(s) {
  companion_radius(A_list_2b[[s]], n_2b)
})

cat("Spectral radii of the three regimes:\n")
print(round(rho_2b, 4))
cat("All stable:", if (all(rho_2b < 1)) "YES" else "NO", "\n\n")

y_2b <- simulate_bvar_breaks(
  T = T_sim_2b,
  breaks = c(tau1_0_2b, tau2_0_2b),
  pmax = pmax_2b,
  c_list = c_list_2b,
  A_list = A_list_2b,
  Sigma_list = Sigma_list_2b,
  burnin = 300
)

train_y_2b <- y_2b[1:T0_len_2b, , drop = FALSE]
y_full_2b <- y_2b

gamma_grid_2b <- make_gamma_grid(pmax_2b)

prior_info_2b <- make_prior_info(
  train_y = train_y_2b,
  pmax = pmax_2b,
  lambda_const = 10,
  lambda_lag = 0.40,
  lambda_decay = 1,
  own_lag_mean = 0,
  nu0_extra = 2
)

cat("Data dimension:", dim(y_full_2b), "\n")
cat("Training sample: 1,...,", T0_len_2b, "\n", sep = "")
cat("Estimation sample:", T0_len_2b + 1, ",...,", T_sim_2b, "\n")
cat("True absolute breaks:", tau1_0_2b, tau2_0_2b, "\n")
cat("True breaks in the estimation sample:", tau1_est_2b, tau2_est_2b, "\n")
cat("True gammas:", paste(true_gamma_labels_2b, collapse = ", "), "\n\n")
# 15. Known two-break case

out_known_2b <- bvar_facchange_breaks(
  y = y_full_2b,
  breaks = c(tau1_0_2b, tau2_0_2b),
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b
)

cat("Observations in the three segments:\n")
print(out_known_2b$nobs_segment)

cat("Log marginal likelihood integrated over the 512 models:\n")
print(out_known_2b$logmarg)

cat("Top 10 combinations (gamma1,gamma2,gamma3) with true breaks:\n")
print(head(out_known_2b$combo_table, 10))

cat("Recovery of true models with known breaks:\n")
cat("True regime 1:", true_gamma_labels_2b[1],
    "| best:", out_known_2b$scanls$regime1$gamma[1], "\n")
cat("True regime 2:", true_gamma_labels_2b[2],
    "| best:", out_known_2b$scanls$regime2$gamma[1], "\n")
cat("True regime 3:", true_gamma_labels_2b[3],
    "| best:", out_known_2b$scanls$regime3$gamma[1], "\n\n")
# 16. Local exhaustive scan over two breaks

radius_2b <- 15

tau1_grid_2b <- (tau1_0_2b - radius_2b):(tau1_0_2b + radius_2b)
tau2_grid_2b <- (tau2_0_2b - radius_2b):(tau2_0_2b + radius_2b)

min_segment_length_2b <- 200

out_scan_2b <- bvar_changescan_twobreak(
  y = y_full_2b,
  tau1_grid = tau1_grid_2b,
  tau2_grid = tau2_grid_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  min_segment_length = min_segment_length_2b,
  verbose = TRUE
)

summary_2b <- summarise_twobreak_scan(
  out_scan = out_scan_2b,
  T0 = T0_len_2b,
  tau1_true_est = tau1_est_2b,
  tau2_true_est = tau2_est_2b,
  true_gamma_labels = true_gamma_labels_2b
)

cat("True breaks in the estimation sample:",
    tau1_est_2b, tau2_est_2b, "\n")

cat("Estimated breaks in the estimation sample:",
    summary_2b$best$tau1_est,
    summary_2b$best$tau2_est, "\n")

cat("Errors:",
    summary_2b$best$tau1_est - tau1_est_2b,
    summary_2b$best$tau2_est - tau2_est_2b, "\n\n")

cat("Top 10 break pairs:\n")
print(summary_2b$top10[, c("tau1", "tau2",
                           "tau1_est", "tau2_est",
                           "logmarg", "postprob_breaks",
                           "best_gamma1", "best_gamma2", "best_gamma3")])

cat("Marginal posterior of tau1, top 10:\n")
print(head(summary_2b$tau1_post, 10))

cat("Marginal posterior of tau2, top 10:\n")
print(head(summary_2b$tau2_post, 10))

cat("Two-break validation:\n")
print(summary_2b$validation)

cat("Top 10 gamma combinations at the break maximum:\n")
print(head(summary_2b$best_fit$combo_table, 10))

# Main plots.
plot_twobreak_logmarg_surface(
  summary_2b = summary_2b,
  tau1_true_est = tau1_est_2b,
  tau2_true_est = tau2_est_2b
)

plot_twobreak_marginals(
  summary_2b = summary_2b,
  tau1_true_est = tau1_est_2b,
  tau2_true_est = tau2_est_2b
)
# 17. Save two-break results

results_2b <- list(
  y_full = y_full_2b,
  train_y = train_y_2b,
  true = list(
    T0_len = T0_len_2b,
    T_est = T_est_2b,
    T_sim = T_sim_2b,
    tau1_est = tau1_est_2b,
    tau2_est = tau2_est_2b,
    tau1_0 = tau1_0_2b,
    tau2_0 = tau2_0_2b,
    pmax = pmax_2b,
    gamma1 = true_gamma1_2b,
    gamma2 = true_gamma2_2b,
    gamma3 = true_gamma3_2b,
    gamma_labels = true_gamma_labels_2b,
    A_list = A_list_2b,
    Sigma_list = Sigma_list_2b
  ),
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  known_breaks = out_known_2b,
  scan = out_scan_2b,
  summary = summary_2b
)
# 18. General "live" MCMC for an arbitrary number of breaks m
# 18.1 Live (on-the-fly) regime marginal likelihood

regime_logmarg_live <- function(full_design, mask, gamma_label_regime,
                                prior_info) {
  
  gamma_vec <- label_to_gamma(gamma_label_regime)
  
  Y_seg <- full_design$Y[mask, , drop = FALSE]
  X_seg <- select_X_from_gamma(
    Xfull = full_design$Xfull[mask, , drop = FALSE],
    gamma = gamma_vec,
    n = prior_info$n,
    pmax = prior_info$pmax
  )
  
  pr <- prior_mniw_for_gamma(gamma_vec, prior_info)
  
  log_marginal_mniw(
    Y = Y_seg,
    X = X_seg,
    B0 = pr$B0,
    V0 = pr$V0,
    S0 = pr$S0,
    nu0 = pr$nu0
  )
}
# 18.2 Validity check for a general break vector

breaks_are_valid_general <- function(breaks, T0, T_end, min_segment_length,
                                     break_windows = NULL) {
  
  if (is.unsorted(breaks, strictly = TRUE)) return(FALSE)
  if (breaks[1] <= T0) return(FALSE)
  if (breaks[length(breaks)] >= T_end) return(FALSE)
  
  edges <- c(T0, breaks, T_end)
  seg_len <- diff(edges)
  
  if (!all(seg_len >= min_segment_length)) return(FALSE)
  
  if (!is.null(break_windows)) {
    for (k in seq_along(breaks)) {
      w <- break_windows[[k]]
      if (!is.null(w)) {
        if (breaks[k] < w[1] || breaks[k] > w[2]) return(FALSE)
      }
    }
  }
  
  TRUE
}
# 18.3 Local proposals for a general break vector and a general gamma vector

propose_break_local_general <- function(breaks_current, T0, T_end,
                                        min_segment_length,
                                        steps = c(-10, -5, -2, -1, 1, 2, 5, 10),
                                        break_windows = NULL) {
  
  m <- length(breaks_current)
  k <- sample.int(m, size = 1)
  step <- sample(steps, size = 1)
  
  breaks_new <- breaks_current
  breaks_new[k] <- breaks_current[k] + step
  
  valid <- breaks_are_valid_general(
    breaks = breaks_new,
    T0 = T0,
    T_end = T_end,
    min_segment_length = min_segment_length,
    break_windows = break_windows
  )
  
  if (!valid) {
    return(list(breaks_new = breaks_current, k = k, valid = FALSE))
  }
  
  list(breaks_new = breaks_new, k = k, valid = TRUE)
}

propose_gamma_flip_general <- function(gammas_current, pmax) {
  
  n_regimes <- length(gammas_current)
  s <- sample.int(n_regimes, size = 1)
  
  prop <- flip_gamma_label(gammas_current[s], pmax)
  
  gammas_new <- gammas_current
  gammas_new[s] <- prop$gamma_label
  
  list(gammas_new = gammas_new, regime = s, flipped_lag = prop$flipped_lag)
}
# 18.4 Live MCMC sampler for a general number of breaks

run_mcmc_general_live <- function(full_design,
                                  prior_info,
                                  breaks_init,
                                  gammas_init,
                                  T0,
                                  T_end,
                                  min_segment_length,
                                  n_iter = 20000,
                                  seed = NULL,
                                  verbose = FALSE,
                                  break_windows = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  m <- length(breaks_init)
  n_regimes <- m + 1L
  
  if (length(gammas_init) != n_regimes) {
    stop("gammas_init must have length m + 1.")
  }
  if (!breaks_are_valid_general(breaks_init, T0, T_end, min_segment_length,
                                break_windows = break_windows)) {
    stop("breaks_init is not a valid break configuration (check break_windows if supplied).")
  }
  
  breaks_current <- as.integer(breaks_init)
  gammas_current <- as.character(gammas_init)
  
  masks_current <- make_segment_masks_from_breaks(
    t_index = full_design$t_index,
    breaks = breaks_current
  )
  
  regime_ll <- numeric(n_regimes)
  for (s in seq_len(n_regimes)) {
    regime_ll[s] <- regime_logmarg_live(
      full_design = full_design,
      mask = masks_current[[s]],
      gamma_label_regime = gammas_current[s],
      prior_info = prior_info
    )
  }
  total_ll <- sum(regime_ll)
  
  breaks_mat <- matrix(NA_integer_, nrow = n_iter, ncol = m)
  colnames(breaks_mat) <- paste0("tau", seq_len(m))
  
  gammas_mat <- matrix(NA_character_, nrow = n_iter, ncol = n_regimes)
  colnames(gammas_mat) <- paste0("gamma", seq_len(n_regimes))
  
  move_vec <- character(n_iter)
  logpost_vec <- numeric(n_iter)
  accepted_vec <- logical(n_iter)
  
  for (iter in seq_len(n_iter)) {
    
    accepted <- FALSE
    
    if (iter %% 2 == 1) {
      
      move <- "break"
      
      prop <- propose_break_local_general(
        breaks_current = breaks_current,
        T0 = T0,
        T_end = T_end,
        min_segment_length = min_segment_length,
        break_windows = break_windows
      )
      
      if (prop$valid) {
        
        masks_prop <- make_segment_masks_from_breaks(
          t_index = full_design$t_index,
          breaks = prop$breaks_new
        )
        
        touched <- unique(c(prop$k, prop$k + 1L))
        
        regime_ll_prop <- regime_ll
        for (s in touched) {
          regime_ll_prop[s] <- regime_logmarg_live(
            full_design = full_design,
            mask = masks_prop[[s]],
            gamma_label_regime = gammas_current[s],
            prior_info = prior_info
          )
        }
        
        total_prop <- total_ll - sum(regime_ll[touched]) + sum(regime_ll_prop[touched])
        
        log_alpha <- total_prop - total_ll
        
        if (log(runif(1)) < log_alpha) {
          breaks_current <- prop$breaks_new
          masks_current <- masks_prop
          regime_ll <- regime_ll_prop
          total_ll <- total_prop
          accepted <- TRUE
        }
      }
      
    } else {
      
      move <- "gamma"
      
      prop <- propose_gamma_flip_general(
        gammas_current = gammas_current,
        pmax = prior_info$pmax
      )
      
      s <- prop$regime
      
      new_ll_s <- regime_logmarg_live(
        full_design = full_design,
        mask = masks_current[[s]],
        gamma_label_regime = prop$gammas_new[s],
        prior_info = prior_info
      )
      
      total_prop <- total_ll - regime_ll[s] + new_ll_s
      
      log_alpha <- total_prop - total_ll
      
      if (log(runif(1)) < log_alpha) {
        gammas_current <- prop$gammas_new
        regime_ll[s] <- new_ll_s
        total_ll <- total_prop
        accepted <- TRUE
      }
    }
    
    breaks_mat[iter, ] <- breaks_current
    gammas_mat[iter, ] <- gammas_current
    move_vec[iter] <- move
    logpost_vec[iter] <- total_ll
    accepted_vec[iter] <- accepted
    
    if (verbose && iter %% 2000 == 0) {
      cat("Iteration", iter,
          "| breaks =", paste(breaks_current, collapse = ","),
          "| gammas =", paste(gammas_current, collapse = ","),
          "| logpost =", round(total_ll, 2), "\n")
    }
  }
  
  list(
    breaks_draws = breaks_mat,
    gammas_draws = gammas_mat,
    move = move_vec,
    logpost = logpost_vec,
    accepted = accepted_vec,
    acceptance = c(
      total = mean(accepted_vec),
      break_move = mean(accepted_vec[move_vec == "break"]),
      gamma_move = mean(accepted_vec[move_vec == "gamma"])
    ),
    init = list(breaks = breaks_init, gammas = gammas_init),
    m = m
  )
}
# 18.5 Multi-chain execution and diagnostics

run_multiple_chains_general_live <- function(seeds,
                                             full_design,
                                             prior_info,
                                             breaks_init,
                                             gammas_init,
                                             T0,
                                             T_end,
                                             min_segment_length,
                                             burnin,
                                             thin,
                                             n_iter = 20000,
                                             true_breaks_est = NULL,
                                             true_gamma_labels = NULL,
                                             break_windows = NULL) {
  
  m <- length(breaks_init)
  n_regimes <- m + 1L
  
  chains <- vector("list", length(seeds))
  rows <- vector("list", length(seeds))
  
  for (i in seq_along(seeds)) {
    cat("Running general live-MCMC chain", i, "with seed", seeds[i], "\n")
    
    mcmc_i <- run_mcmc_general_live(
      full_design = full_design,
      prior_info = prior_info,
      breaks_init = breaks_init,
      gammas_init = gammas_init,
      T0 = T0,
      T_end = T_end,
      min_segment_length = min_segment_length,
      n_iter = n_iter,
      seed = seeds[i],
      verbose = FALSE,
      break_windows = break_windows
    )
    
    keep <- seq_len(n_iter) > burnin
    
    keep_thin <- keep
    if (!is.null(thin) && thin > 1) {
      keep_thin <- keep_thin & ((seq_len(n_iter) - burnin) %% thin == 0)
    }
    
    chains[[i]] <- list(
      mcmc_out = mcmc_i,
      breaks_draws = mcmc_i$breaks_draws[keep, , drop = FALSE],
      gammas_draws = mcmc_i$gammas_draws[keep, , drop = FALSE],
      breaks_draws_thin = mcmc_i$breaks_draws[keep_thin, , drop = FALSE],
      gammas_draws_thin = mcmc_i$gammas_draws[keep_thin, , drop = FALSE]
    )
    
    row_i <- data.frame(
      chain = i,
      seed = seeds[i],
      acceptance_total = mcmc_i$acceptance["total"],
      acceptance_break = mcmc_i$acceptance["break_move"],
      acceptance_gamma = mcmc_i$acceptance["gamma_move"]
    )
    for (k in seq_len(m)) {
      row_i[[paste0("mean_tau", k)]] <- mean(chains[[i]]$breaks_draws[, k])
    }
    rows[[i]] <- row_i
  }
  
  chain_summary <- do.call(rbind, rows)
  rownames(chain_summary) <- NULL
  
  all_breaks <- do.call(rbind, lapply(chains, function(z) z$breaks_draws))
  all_gammas <- do.call(rbind, lapply(chains, function(z) z$gammas_draws))
  
  conv_diag <- compute_convergence_diagnostics_general(chains, m)
  rhat_per_break <- conv_diag$Rhat
  ess_bulk_per_break <- conv_diag$ESS_bulk
  ess_tail_per_break <- conv_diag$ESS_tail
  
  gamma_diag <- compute_gamma_diagnostics_general(chains, n_regimes, prior_info$pmax)
  
  break_summary_tab <- lapply(seq_len(m), function(k) {
    tab <- as.data.frame(table(all_breaks[, k]), stringsAsFactors = FALSE)
    names(tab) <- c("tau", "freq")
    tab$tau <- as.integer(tab$tau)
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(break_summary_tab) <- paste0("tau", seq_len(m))
  
  gamma_summary_tab <- lapply(seq_len(n_regimes), function(s) {
    tab <- as.data.frame(table(all_gammas[, s]), stringsAsFactors = FALSE)
    names(tab) <- c("gamma", "freq")
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(gamma_summary_tab) <- paste0("regime", seq_len(n_regimes))
  
  validation <- NULL
  if (!is.null(true_breaks_est) && !is.null(true_gamma_labels)) {
    rows_val <- lapply(seq_len(m), function(k) {
      data.frame(
        break_index = k,
        true_tau_est = true_breaks_est[k],
        posterior_mean_tau_est = mean(all_breaks[, k]) - T0,
        posterior_mode_tau_est = break_summary_tab[[k]]$tau[1] - T0,
        mass_within_pm5 = mean(abs(all_breaks[, k] - true_breaks_est[k] - T0) <= 5)
      )
    })
    tau_validation <- do.call(rbind, rows_val)
    
    gamma_validation <- data.frame(
      regime = seq_len(n_regimes),
      true_gamma = true_gamma_labels,
      posterior_mode_gamma = sapply(gamma_summary_tab, function(z) z$gamma[1]),
      mass_true_gamma = sapply(seq_len(n_regimes), function(s) {
        mean(all_gammas[, s] == true_gamma_labels[s])
      })
    )
    
    validation <- list(tau_validation = tau_validation,
                       gamma_validation = gamma_validation)
  }
  
  list(
    chains = chains,
    chain_summary = chain_summary,
    all_breaks = all_breaks,
    all_gammas = all_gammas,
    Rhat_breaks = rhat_per_break,
    ESS_bulk_breaks = ess_bulk_per_break,
    ESS_tail_breaks = ess_tail_per_break,
    gamma_PIP = gamma_diag$PIP,
    gamma_Rhat = gamma_diag$Rhat,
    gamma_ESS_bulk = gamma_diag$ESS_bulk,
    gamma_ESS_tail = gamma_diag$ESS_tail,
    gamma_min_transitions = gamma_diag$MinTransitions,
    break_summary_tab = break_summary_tab,
    gamma_summary_tab = gamma_summary_tab,
    validation = validation
  )
}
# 18.6 Plots for the general live MCMC

plot_general_mcmc_posteriors <- function(break_summary_tab, T0,
                                         true_breaks_est = NULL) {
  
  m <- length(break_summary_tab)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(m, 1), mar = c(4, 5, 2, 2))
  
  for (k in seq_len(m)) {
    tab <- break_summary_tab[[k]]
    plot(
      tab$tau - T0,
      tab$postprob,
      type = "h",
      lwd = 2,
      xlab = bquote(tau[.(k)]),
      ylab = "Posterior probability",
      main = paste0("MCMC posterior of break ", k)
    )
    if (!is.null(true_breaks_est)) {
      abline(v = true_breaks_est[k], lty = 2, lwd = 2, col = "red")
    }
    if (k == 1) {
      legend("topleft", legend = "true break", lty = 2, lwd = 2, col = "red", bty = "n", cex = 0.85)
    }
  }
  
  par(op)
}
# 18.7 Dispersed-start multi-chain sampler

run_multiple_chains_general_live_dispersed <- function(seeds,
                                                       breaks_init_list,
                                                       gammas_init_list,
                                                       full_design,
                                                       prior_info,
                                                       T0,
                                                       T_end,
                                                       min_segment_length,
                                                       burnin,
                                                       thin,
                                                       n_iter,
                                                       true_breaks_est = NULL,
                                                       true_gamma_labels = NULL,
                                                       break_windows = NULL) {
  
  if (length(seeds) != length(breaks_init_list)) {
    stop("seeds and breaks_init_list must have the same length.")
  }
  if (length(seeds) != length(gammas_init_list)) {
    stop("seeds and gammas_init_list must have the same length.")
  }
  
  m <- length(breaks_init_list[[1]])
  n_regimes <- m + 1L
  
  chains <- vector("list", length(seeds))
  rows <- vector("list", length(seeds))
  
  for (i in seq_along(seeds)) {
    cat("Running dispersed live-MCMC chain", i,
        "| seed =", seeds[i],
        "| init breaks =", paste(breaks_init_list[[i]], collapse = ","), "\n")
    
    mcmc_i <- run_mcmc_general_live(
      full_design = full_design,
      prior_info = prior_info,
      breaks_init = breaks_init_list[[i]],
      gammas_init = gammas_init_list[[i]],
      T0 = T0,
      T_end = T_end,
      min_segment_length = min_segment_length,
      n_iter = n_iter,
      seed = seeds[i],
      verbose = FALSE,
      break_windows = break_windows
    )

    keep <- seq_len(n_iter) > burnin
    
    keep_thin <- keep
    if (!is.null(thin) && thin > 1) {
      keep_thin <- keep_thin & ((seq_len(n_iter) - burnin) %% thin == 0)
    }
    
    chains[[i]] <- list(
      mcmc_out = mcmc_i,
      breaks_draws = mcmc_i$breaks_draws[keep, , drop = FALSE],
      gammas_draws = mcmc_i$gammas_draws[keep, , drop = FALSE],
      breaks_draws_thin = mcmc_i$breaks_draws[keep_thin, , drop = FALSE],
      gammas_draws_thin = mcmc_i$gammas_draws[keep_thin, , drop = FALSE],
      init_breaks = breaks_init_list[[i]],
      init_gammas = gammas_init_list[[i]]
    )
    
    row_i <- data.frame(
      chain = i,
      seed = seeds[i],
      init_breaks = paste(breaks_init_list[[i]], collapse = ","),
      acceptance_total = mcmc_i$acceptance["total"],
      acceptance_break = mcmc_i$acceptance["break_move"],
      acceptance_gamma = mcmc_i$acceptance["gamma_move"],
      stringsAsFactors = FALSE
    )
    for (k in seq_len(m)) {
      row_i[[paste0("mean_tau", k)]] <- mean(chains[[i]]$breaks_draws[, k])
    }
    rows[[i]] <- row_i
  }
  
  chain_summary <- do.call(rbind, rows)
  rownames(chain_summary) <- NULL
  
  all_breaks <- do.call(rbind, lapply(chains, function(z) z$breaks_draws))
  all_gammas <- do.call(rbind, lapply(chains, function(z) z$gammas_draws))
  
  conv_diag <- compute_convergence_diagnostics_general(chains, m)
  rhat_per_break <- conv_diag$Rhat
  ess_bulk_per_break <- conv_diag$ESS_bulk
  ess_tail_per_break <- conv_diag$ESS_tail
  
  gamma_diag <- compute_gamma_diagnostics_general(chains, n_regimes, prior_info$pmax)
  
  break_summary_tab <- lapply(seq_len(m), function(k) {
    tab <- as.data.frame(table(all_breaks[, k]), stringsAsFactors = FALSE)
    names(tab) <- c("tau", "freq")
    tab$tau <- as.integer(tab$tau)
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(break_summary_tab) <- paste0("tau", seq_len(m))
  
  gamma_summary_tab <- lapply(seq_len(n_regimes), function(s) {
    tab <- as.data.frame(table(all_gammas[, s]), stringsAsFactors = FALSE)
    names(tab) <- c("gamma", "freq")
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(gamma_summary_tab) <- paste0("regime", seq_len(n_regimes))

  per_chain_break_means <- do.call(rbind, lapply(seq_along(chains), function(i) {
    data.frame(
      chain = i,
      break_index = seq_len(m),
      init_value = breaks_init_list[[i]],
      posterior_mean = as.numeric(colMeans(chains[[i]]$breaks_draws))
    )
  }))
  rownames(per_chain_break_means) <- NULL
  
  validation <- NULL
  if (!is.null(true_breaks_est) && !is.null(true_gamma_labels)) {
    rows_val <- lapply(seq_len(m), function(k) {
      data.frame(
        break_index = k,
        true_tau_est = true_breaks_est[k],
        posterior_mean_tau_est = mean(all_breaks[, k]) - T0,
        posterior_mode_tau_est = break_summary_tab[[k]]$tau[1] - T0,
        mass_within_pm5 = mean(abs(all_breaks[, k] - true_breaks_est[k] - T0) <= 5)
      )
    })
    tau_validation <- do.call(rbind, rows_val)
    
    gamma_validation <- data.frame(
      regime = seq_len(n_regimes),
      true_gamma = true_gamma_labels,
      posterior_mode_gamma = sapply(gamma_summary_tab, function(z) z$gamma[1]),
      mass_true_gamma = sapply(seq_len(n_regimes), function(s) {
        mean(all_gammas[, s] == true_gamma_labels[s])
      })
    )
    
    validation <- list(tau_validation = tau_validation,
                       gamma_validation = gamma_validation)
  }
  
  list(
    chains = chains,
    chain_summary = chain_summary,
    per_chain_break_means = per_chain_break_means,
    all_breaks = all_breaks,
    all_gammas = all_gammas,
    Rhat_breaks = rhat_per_break,
    ESS_bulk_breaks = ess_bulk_per_break,
    ESS_tail_breaks = ess_tail_per_break,
    gamma_PIP = gamma_diag$PIP,
    gamma_Rhat = gamma_diag$Rhat,
    gamma_ESS_bulk = gamma_diag$ESS_bulk,
    gamma_ESS_tail = gamma_diag$ESS_tail,
    gamma_min_transitions = gamma_diag$MinTransitions,
    break_summary_tab = break_summary_tab,
    gamma_summary_tab = gamma_summary_tab,
    validation = validation
  )
}
# 18.8 Exact-marginal tables and comparison helper (reusable for any m)

make_exact_marginals_twobreak <- function(out_scan_2b, T0) {
  
  bs <- out_scan_2b$break_summary
  
  tau1_tab <- aggregate(postprob_breaks ~ tau1, data = bs, FUN = sum)
  names(tau1_tab) <- c("tau", "postprob")
  tau1_tab <- tau1_tab[order(tau1_tab$postprob, decreasing = TRUE), ]
  rownames(tau1_tab) <- NULL
  
  tau2_tab <- aggregate(postprob_breaks ~ tau2, data = bs, FUN = sum)
  names(tau2_tab) <- c("tau", "postprob")
  tau2_tab <- tau2_tab[order(tau2_tab$postprob, decreasing = TRUE), ]
  rownames(tau2_tab) <- NULL
  
  break_tabs <- list(tau1 = tau1_tab, tau2 = tau2_tab)
  
  all_combo <- vector("list", nrow(bs))
  for (i in seq_len(nrow(bs))) {
    key <- paste(bs$tau1[i], bs$tau2[i], sep = "_")
    fit <- out_scan_2b$fits[[key]]
    tab <- fit$combo_table[, c("gamma1", "gamma2", "gamma3", "postprob_combo")]
    tab$postprob_combo <- tab$postprob_combo * bs$postprob_breaks[i]
    all_combo[[i]] <- tab
  }
  all_combo <- do.call(rbind, all_combo)
  
  make_marginal <- function(col) {
    tab <- aggregate(all_combo$postprob_combo,
                     by = list(gamma = all_combo[[col]]), FUN = sum)
    names(tab) <- c("gamma", "postprob")
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  }
  
  gamma_tabs <- list(
    regime1 = make_marginal("gamma1"),
    regime2 = make_marginal("gamma2"),
    regime3 = make_marginal("gamma3")
  )
  
  list(break_tabs = break_tabs, gamma_tabs = gamma_tabs)
}

compare_live_vs_exact_marginals <- function(live_break_tab, live_gamma_tab,
                                            exact_break_tab, exact_gamma_tab,
                                            T0) {
  
  m <- length(live_break_tab)
  n_regimes <- length(live_gamma_tab)
  
  break_comparison <- vector("list", m)
  for (k in seq_len(m)) {
    live_k <- live_break_tab[[k]][, c("tau", "postprob")]
    names(live_k)[2] <- "postprob_live"
    exact_k <- exact_break_tab[[k]][, c("tau", "postprob")]
    names(exact_k)[2] <- "postprob_exact"
    
    cmp <- merge(exact_k, live_k, by = "tau", all = TRUE)
    cmp$postprob_exact[is.na(cmp$postprob_exact)] <- 0
    cmp$postprob_live[is.na(cmp$postprob_live)] <- 0
    cmp$tau_est <- cmp$tau - T0
    cmp <- cmp[order(cmp$tau_est), ]
    rownames(cmp) <- NULL
    
    break_comparison[[k]] <- cmp
  }
  names(break_comparison) <- names(live_break_tab)
  
  gamma_comparison <- vector("list", n_regimes)
  for (s in seq_len(n_regimes)) {
    live_s <- live_gamma_tab[[s]][, c("gamma", "postprob")]
    names(live_s)[2] <- "postprob_live"
    exact_s <- exact_gamma_tab[[s]][, c("gamma", "postprob")]
    names(exact_s)[2] <- "postprob_exact"
    
    cmp <- merge(exact_s, live_s, by = "gamma", all = TRUE)
    cmp$postprob_exact[is.na(cmp$postprob_exact)] <- 0
    cmp$postprob_live[is.na(cmp$postprob_live)] <- 0
    cmp <- cmp[order(cmp$postprob_exact, decreasing = TRUE), ]
    rownames(cmp) <- NULL
    
    gamma_comparison[[s]] <- cmp
  }
  names(gamma_comparison) <- names(live_gamma_tab)
  
  break_distance <- lapply(break_comparison, function(cmp) {
    posterior_distance(cmp$postprob_exact, cmp$postprob_live)
  })
  
  gamma_distance <- lapply(gamma_comparison, function(cmp) {
    posterior_distance(cmp$postprob_exact, cmp$postprob_live)
  })
  
  list(
    break_comparison = break_comparison,
    gamma_comparison = gamma_comparison,
    break_distance = break_distance,
    gamma_distance = gamma_distance
  )
}

make_exact_joint_tables_twobreak <- function(out_scan_2b) {
  
  bs <- out_scan_2b$break_summary
  
  tau_joint <- bs[, c("tau1", "tau2", "postprob_breaks")]
  names(tau_joint)[3] <- "postprob"
  
  all_combo <- vector("list", nrow(bs))
  for (i in seq_len(nrow(bs))) {
    key <- paste(bs$tau1[i], bs$tau2[i], sep = "_")
    fit <- out_scan_2b$fits[[key]]
    tab <- fit$combo_table[, c("gamma1", "gamma2", "gamma3", "postprob_combo")]
    tab$postprob_combo <- tab$postprob_combo * bs$postprob_breaks[i]
    all_combo[[i]] <- tab
  }
  all_combo <- do.call(rbind, all_combo)
  
  gamma_joint <- aggregate(
    postprob_combo ~ gamma1 + gamma2 + gamma3,
    data = all_combo,
    FUN = sum
  )
  names(gamma_joint)[4] <- "postprob"
  
  list(tau_joint = tau_joint, gamma_joint = gamma_joint)
}

make_live_joint_tables_twobreak <- function(all_breaks, all_gammas) {
  
  tau_key <- paste(all_breaks[, 1], all_breaks[, 2], sep = "_")
  tau_tab <- as.data.frame(table(tau_key), stringsAsFactors = FALSE)
  names(tau_tab) <- c("tau_key", "freq")
  tau_tab$postprob <- tau_tab$freq / sum(tau_tab$freq)
  tmp <- do.call(rbind, strsplit(tau_tab$tau_key, "_"))
  tau_tab$tau1 <- as.integer(tmp[, 1])
  tau_tab$tau2 <- as.integer(tmp[, 2])
  tau_joint <- tau_tab[, c("tau1", "tau2", "postprob")]
  
  gamma_key <- paste(all_gammas[, 1], all_gammas[, 2], all_gammas[, 3], sep = ",")
  gamma_tab <- as.data.frame(table(gamma_key), stringsAsFactors = FALSE)
  names(gamma_tab) <- c("gamma_key", "freq")
  gamma_tab$postprob <- gamma_tab$freq / sum(gamma_tab$freq)
  tmp2 <- do.call(rbind, strsplit(gamma_tab$gamma_key, ","))
  gamma_tab$gamma1 <- tmp2[, 1]
  gamma_tab$gamma2 <- tmp2[, 2]
  gamma_tab$gamma3 <- tmp2[, 3]
  gamma_joint <- gamma_tab[, c("gamma1", "gamma2", "gamma3", "postprob")]
  
  list(tau_joint = tau_joint, gamma_joint = gamma_joint)
}

compare_live_vs_exact_joint <- function(live_joint, exact_joint) {
  
  tau_cmp <- merge(
    exact_joint$tau_joint, live_joint$tau_joint,
    by = c("tau1", "tau2"), all = TRUE,
    suffixes = c("_exact", "_live")
  )
  tau_cmp$postprob_exact[is.na(tau_cmp$postprob_exact)] <- 0
  tau_cmp$postprob_live[is.na(tau_cmp$postprob_live)] <- 0
  tau_cmp <- tau_cmp[order(tau_cmp$postprob_exact, decreasing = TRUE), ]
  rownames(tau_cmp) <- NULL
  
  gamma_cmp <- merge(
    exact_joint$gamma_joint, live_joint$gamma_joint,
    by = c("gamma1", "gamma2", "gamma3"), all = TRUE,
    suffixes = c("_exact", "_live")
  )
  gamma_cmp$postprob_exact[is.na(gamma_cmp$postprob_exact)] <- 0
  gamma_cmp$postprob_live[is.na(gamma_cmp$postprob_live)] <- 0
  gamma_cmp <- gamma_cmp[order(gamma_cmp$postprob_exact, decreasing = TRUE), ]
  rownames(gamma_cmp) <- NULL
  
  list(
    tau_joint_comparison = tau_cmp,
    gamma_joint_comparison = gamma_cmp,
    tau_joint_distance = posterior_distance(tau_cmp$postprob_exact, tau_cmp$postprob_live),
    gamma_joint_distance = posterior_distance(gamma_cmp$postprob_exact, gamma_cmp$postprob_live)
  )
}
# 19. Live MCMC validation for the two-break case (m = 2)

full_design_2b <- build_full_design(y_full_2b, pmax_2b, T0 = T0_len_2b)

exact_marginals_2b <- make_exact_marginals_twobreak(
  out_scan_2b = results_2b$scan,
  T0 = T0_len_2b
)

exact_joint_2b <- make_exact_joint_tables_twobreak(
  out_scan_2b = results_2b$scan
)

break_windows_2b <- list(
  c(min(tau1_grid_2b), max(tau1_grid_2b)),
  c(min(tau2_grid_2b), max(tau2_grid_2b))
)

cat("Live MCMC restricted to the exact scan's support:\n")
cat("tau1 window:", break_windows_2b[[1]], "\n")
cat("tau2 window:", break_windows_2b[[2]], "\n\n")

# Shared-start run

breaks_init_2b <- c(tau1_0_2b - 5, tau2_0_2b + 5)
gammas_init_2b <- rep("111", 3)

n_iter_2b_live <- 20000
burnin_2b_live <- 4000
thin_2b_live <- 4
seeds_2b_live <- c(11, 22, 33, 44)

multi_mcmc_2b_shared <- run_multiple_chains_general_live(
  seeds = seeds_2b_live,
  full_design = full_design_2b,
  prior_info = prior_info_2b,
  breaks_init = breaks_init_2b,
  gammas_init = gammas_init_2b,
  T0 = T0_len_2b,
  T_end = T_sim_2b,
  min_segment_length = min_segment_length_2b,
  burnin = burnin_2b_live,
  thin = thin_2b_live,
  n_iter = n_iter_2b_live,
  true_breaks_est = c(tau1_est_2b, tau2_est_2b),
  true_gamma_labels = true_gamma_labels_2b,
  break_windows = break_windows_2b
)

cmp_shared_2b <- compare_live_vs_exact_marginals(
  live_break_tab = multi_mcmc_2b_shared$break_summary_tab,
  live_gamma_tab = multi_mcmc_2b_shared$gamma_summary_tab,
  exact_break_tab = exact_marginals_2b$break_tabs,
  exact_gamma_tab = exact_marginals_2b$gamma_tabs,
  T0 = T0_len_2b
)

live_joint_shared_2b <- make_live_joint_tables_twobreak(
  all_breaks = multi_mcmc_2b_shared$all_breaks,
  all_gammas = multi_mcmc_2b_shared$all_gammas
)
cmp_joint_shared_2b <- compare_live_vs_exact_joint(
  live_joint = live_joint_shared_2b,
  exact_joint = exact_joint_2b
)

cat("Shared-start live MCMC vs exact -- distance per break:\n")
print(cmp_shared_2b$break_distance)
cat("\nShared-start live MCMC vs exact -- distance per regime:\n")
print(cmp_shared_2b$gamma_distance)
cat("dependence between tau1 and tau2 directly, not just each alone):\n")
print(cmp_joint_shared_2b$tau_joint_distance)
cat("\nShared-start live MCMC vs exact -- JOINT (gamma1, gamma2, gamma3)\n")
cat("distance:\n")
print(cmp_joint_shared_2b$gamma_joint_distance)
cat("\nR-hat per break (shared-start):\n")
print(multi_mcmc_2b_shared$Rhat_breaks)
cat("\nBulk-ESS per break (shared-start):\n")
print(multi_mcmc_2b_shared$ESS_bulk_breaks)
cat("\nTail-ESS per break (shared-start):\n")
print(multi_mcmc_2b_shared$ESS_tail_breaks)
print(round(multi_mcmc_2b_shared$gamma_PIP, 3))
cat("\nR-hat per lag indicator, shared-start:\n")
print(round(multi_mcmc_2b_shared$gamma_Rhat, 3))
cat("\nBulk-ESS per lag indicator, shared-start:\n")
print(round(multi_mcmc_2b_shared$gamma_ESS_bulk, 1))
cat("\nTail-ESS per lag indicator, shared-start\n")
print(round(multi_mcmc_2b_shared$gamma_ESS_tail, 1))
cat("\nMinimum transitions per lag indicator across chains, shared-start\n")
print(multi_mcmc_2b_shared$gamma_min_transitions)
cat("Break recovery vs the true simulated DGP:\n")
print(multi_mcmc_2b_shared$validation$tau_validation)
cat("\nLag-model recovery vs the true simulated DGP:\n")
print(multi_mcmc_2b_shared$validation$gamma_validation)
cat("\n")

# Dispersed-start run
breaks_init_list_2b <- list(
  c(tau1_0_2b - 12, tau2_0_2b - 12),
  c(tau1_0_2b + 12, tau2_0_2b + 12),
  c(tau1_0_2b - 8,  tau2_0_2b + 8),
  c(tau1_0_2b + 8,  tau2_0_2b - 8)
)

gammas_init_list_2b <- list(
  rep("111", 3),
  rep("000", 3),
  c("101", "010", "110"),
  c("011", "001", "111")
)

seeds_2b_disp <- c(111, 222, 333, 444)

multi_mcmc_2b_disp <- run_multiple_chains_general_live_dispersed(
  seeds = seeds_2b_disp,
  breaks_init_list = breaks_init_list_2b,
  gammas_init_list = gammas_init_list_2b,
  full_design = full_design_2b,
  prior_info = prior_info_2b,
  T0 = T0_len_2b,
  T_end = T_sim_2b,
  min_segment_length = min_segment_length_2b,
  burnin = burnin_2b_live,
  thin = thin_2b_live,
  n_iter = n_iter_2b_live,
  true_breaks_est = c(tau1_est_2b, tau2_est_2b),
  true_gamma_labels = true_gamma_labels_2b,
  break_windows = break_windows_2b
)

cmp_disp_2b <- compare_live_vs_exact_marginals(
  live_break_tab = multi_mcmc_2b_disp$break_summary_tab,
  live_gamma_tab = multi_mcmc_2b_disp$gamma_summary_tab,
  exact_break_tab = exact_marginals_2b$break_tabs,
  exact_gamma_tab = exact_marginals_2b$gamma_tabs,
  T0 = T0_len_2b
)

live_joint_disp_2b <- make_live_joint_tables_twobreak(
  all_breaks = multi_mcmc_2b_disp$all_breaks,
  all_gammas = multi_mcmc_2b_disp$all_gammas
)
cmp_joint_disp_2b <- compare_live_vs_exact_joint(
  live_joint = live_joint_disp_2b,
  exact_joint = exact_joint_2b
)

cat("Dispersed-start live MCMC vs exact -- distance per break:\n")
print(cmp_disp_2b$break_distance)
cat("\nDispersed-start live MCMC vs exact -- distance per regime:\n")
print(cmp_disp_2b$gamma_distance)
cat("\nDispersed-start live MCMC vs exact -- JOINT (tau1, tau2) distance:\n")
print(cmp_joint_disp_2b$tau_joint_distance)
cat("\nDispersed-start live MCMC vs exact -- JOINT (gamma1, gamma2, gamma3)\n")
cat("distance:\n")
print(cmp_joint_disp_2b$gamma_joint_distance)
cat("\nR-hat per break (dispersed-start):\n")
print(multi_mcmc_2b_disp$Rhat_breaks)
cat("\nBulk-ESS per break (dispersed-start):\n")
print(multi_mcmc_2b_disp$ESS_bulk_breaks)
cat("\nTail-ESS per break (dispersed-start):\n")
print(multi_mcmc_2b_disp$ESS_tail_breaks)
cat("\nLag posterior inclusion probabilities (PIP), dispersed-start\n")
print(round(multi_mcmc_2b_disp$gamma_PIP, 3))
cat("\nR-hat per lag indicator, dispersed-start:\n")
print(round(multi_mcmc_2b_disp$gamma_Rhat, 3))
cat("\nBulk-ESS per lag indicator, dispersed-start:\n")
print(round(multi_mcmc_2b_disp$gamma_ESS_bulk, 1))
cat("\nTail-ESS per lag indicator, dispersed-start\n")
print(round(multi_mcmc_2b_disp$gamma_ESS_tail, 1))
cat("\nMinimum transitions per lag indicator across chains, dispersed-start\n")
print(multi_mcmc_2b_disp$gamma_min_transitions)
cat("Per-chain posterior mean by starting point:\n")
print(multi_mcmc_2b_disp$per_chain_break_means)
cat("\nBreak recovery vs the true simulated DGP:\n")
print(multi_mcmc_2b_disp$validation$tau_validation)
cat("\nLag-model recovery vs the true simulated DGP:\n")
print(multi_mcmc_2b_disp$validation$gamma_validation)

plot_exact_vs_mcmc_breaks <- function(break_comparison, true_breaks_est = NULL) {
  m <- length(break_comparison)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(m, 1), mar = c(4, 5, 2, 2))
  
  for (k in seq_len(m)) {
    cmp <- break_comparison[[k]]
    plot(cmp$tau_est, cmp$postprob_exact, type = "l", lwd = 2,
         xlab = bquote(tau[.(k)]), ylab = "Posterior probability",
         main = paste0("Exact vs MCMC posterior (dispersed-start), break ", k))
    lines(cmp$tau_est, cmp$postprob_live, lwd = 2, lty = 2, col = "red")
    if (!is.null(true_breaks_est)) abline(v = true_breaks_est[k], lty = 3, lwd = 2, col = "gray40")
    legend("topright", legend = c("exact", "MCMC (dispersed-start)", "true break"),
           lty = c(1, 2, 3), col = c("black", "red", "gray40"), lwd = 2, bty = "n", cex = 0.7)
  }
  
  par(op)
}

plot_exact_vs_mcmc_breaks(
  break_comparison = cmp_disp_2b$break_comparison,
  true_breaks_est = c(tau1_est_2b, tau2_est_2b)
)
 
# Saving

results_2b$mcmc_live <- list(
  full_design = full_design_2b,
  exact_marginals = exact_marginals_2b,
  exact_joint = exact_joint_2b,
  shared = list(
    multi_chain = multi_mcmc_2b_shared,
    comparison = cmp_shared_2b,
    comparison_joint = cmp_joint_shared_2b,
    settings = list(breaks_init = breaks_init_2b, gammas_init = gammas_init_2b,
                    seeds = seeds_2b_live, n_iter = n_iter_2b_live,
                    burnin = burnin_2b_live, thin = thin_2b_live,
                    break_windows = break_windows_2b,
                    min_segment_length = min_segment_length_2b)
  ),
  dispersed = list(
    multi_chain = multi_mcmc_2b_disp,
    comparison = cmp_disp_2b,
    comparison_joint = cmp_joint_disp_2b,
    settings = list(breaks_init_list = breaks_init_list_2b,
                    gammas_init_list = gammas_init_list_2b,
                    seeds = seeds_2b_disp, n_iter = n_iter_2b_live,
                    burnin = burnin_2b_live, thin = thin_2b_live,
                    break_windows = break_windows_2b,
                    min_segment_length = min_segment_length_2b)
  )
)
# 20. Selection of the number of breaks: m = 0, 1, 2
# 20.1 No-break model: m = 0

bvar_facchange_nobreak <- function(y,
                                   pmax,
                                   gamma_grid,
                                   prior_info) {
  
  full <- build_full_design(
    y_full = y,
    pmax = pmax,
    T0 = prior_info$T0
  )
  
  scan0 <- scan_segment_lags(
    Y_segment = full$Y,
    Xfull_segment = full$Xfull,
    gamma_grid = gamma_grid,
    prior_info = prior_info
  )
  
  integrated_logmarg <- log_mean_exp(scan0$logmarg)
  
  list(
    logmarg = integrated_logmarg,
    scan = scan0$scan,
    logmargls = scan0$logmarg,
    best_gamma = scan0$scan[1, ],
    nobs = nrow(full$Y)
  )
}
# 20.2 Summary of the one-break case on two-break data

summarise_onebreak_profile <- function(out_scan_1b,
                                       T0,
                                       true_tau1_est = NULL,
                                       true_tau2_est = NULL) {
  
  bs <- out_scan_1b$break_summary
  bs$tau_est <- bs$tau - T0
  
  best <- bs[which.max(bs$logmarg), ]
  
  top10 <- bs[order(bs$logmarg, decreasing = TRUE), ]
  top10 <- head(top10, 10)
  
  best_fit <- out_scan_1b$fits[[as.character(best$tau)]]
  
  out <- list(
    break_summary = bs,
    best = best,
    top10 = top10,
    best_fit = best_fit
  )
  
  if (!is.null(true_tau1_est) && !is.null(true_tau2_est)) {
    out$dist_from_true_breaks <- data.frame(
      selected_tau_est = best$tau_est,
      distance_from_tau1_true = best$tau_est - true_tau1_est,
      distance_from_tau2_true = best$tau_est - true_tau2_est
    )
  }
  
  out
}
# 20.3 Profile-selection table for m = 0, 1, 2

profile_select_number_breaks <- function(out_m0,
                                         summary_m1,
                                         summary_m2,
                                         prior_m = c("0" = 1/3,
                                                     "1" = 1/3,
                                                     "2" = 1/3)) {
  
  logmarg_m0 <- out_m0$logmarg
  logmarg_m1 <- summary_m1$best$logmarg
  logmarg_m2 <- summary_m2$best$logmarg
  
  log_prior <- log(prior_m[c("0", "1", "2")])
  
  profile_score <- c(
    logmarg_m0,
    logmarg_m1,
    logmarg_m2
  ) + log_prior
  
  profile_weight <- exp(profile_score - log_sum_exp(profile_score))
  
  tab <- data.frame(
    m = c(0L, 1L, 2L),
    profile_logmarg = c(logmarg_m0, logmarg_m1, logmarg_m2),
    log_prior_m = as.numeric(log_prior),
    profile_score = as.numeric(profile_score),
    delta_vs_best = as.numeric(profile_score - max(profile_score)),
    profile_weight = as.numeric(profile_weight),
    best_breaks_est = c(
      "-",
      as.character(summary_m1$best$tau_est),
      paste(summary_m2$best$tau1_est,
            summary_m2$best$tau2_est,
            sep = ", ")
    ),
    best_breaks_abs = c(
      "-",
      as.character(summary_m1$best$tau),
      paste(summary_m2$best$tau1,
            summary_m2$best$tau2,
            sep = ", ")
    ),
    best_gammas = c(
      as.character(out_m0$best_gamma$gamma),
      paste(summary_m1$best$best_gamma1,
            summary_m1$best$best_gamma2,
            sep = ", "),
      paste(summary_m2$best$best_gamma1,
            summary_m2$best$best_gamma2,
            summary_m2$best$best_gamma3,
            sep = ", ")
    ),
    stringsAsFactors = FALSE
  )
  
  tab_ranked <- tab[order(tab$profile_score, decreasing = TRUE), ]
  rownames(tab_ranked) <- NULL
  
  list(
    table_by_m = tab,
    table_ranked = tab_ranked,
    selected_m = tab$m[which.max(tab$profile_score)]
  )
}
# 21. Local preliminary check: selection of m = 0, 1, 2

# m = 0: no break

out_m0_2b <- bvar_facchange_nobreak(
  y = y_full_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b
)

cat("Integrated log marginal likelihood:", out_m0_2b$logmarg, "\n")
cat("Best gamma for m=0:", out_m0_2b$best_gamma$gamma, "\n\n")


tau_grid_m1_2b_raw <- (tau1_0_2b - radius_2b):(tau2_0_2b + radius_2b)

full_des_2b <- build_full_design(
  y_full = y_full_2b,
  pmax = pmax_2b,
  T0 = T0_len_2b
)

tau_grid_m1_2b <- tau_grid_m1_2b_raw[
  sapply(tau_grid_m1_2b_raw, function(tau) {
    k1 <- sum(full_des_2b$t_index <= tau)
    k2 <- sum(full_des_2b$t_index > tau)
    
    all(c(k1, k2) >= min_segment_length_2b)
  })
]

out_scan_m1_2b <- bvar_changescan_onebreak(
  y = y_full_2b,
  tau_grid = tau_grid_m1_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  verbose = TRUE
)

summary_m1_2b <- summarise_onebreak_profile(
  out_scan_1b = out_scan_m1_2b,
  T0 = T0_len_2b,
  true_tau1_est = tau1_est_2b,
  true_tau2_est = tau2_est_2b
)

cat("Best tau_est for m=1:", summary_m1_2b$best$tau_est, "\n")
cat("Best absolute tau for m=1:", summary_m1_2b$best$tau, "\n")
cat("Profile log marginal likelihood for m=1:",
    summary_m1_2b$best$logmarg, "\n")
cat("Best gamma for m=1:",
    summary_m1_2b$best$best_gamma1,
    summary_m1_2b$best$best_gamma2, "\n\n")

cat("Top 10 breaks for m=1:\n")
print(summary_m1_2b$top10[, c("tau", "tau_est", "logmarg",
                              "postprob_tau",
                              "best_gamma1", "best_gamma2")])


summary_m2_2b <- results_2b$summary

cat("Best tau1_est, tau2_est for m=2:",
    summary_m2_2b$best$tau1_est,
    summary_m2_2b$best$tau2_est, "\n")

cat("Profile log marginal likelihood for m=2:",
    summary_m2_2b$best$logmarg, "\n")

cat("Best gamma for m=2:",
    summary_m2_2b$best$best_gamma1,
    summary_m2_2b$best$best_gamma2,
    summary_m2_2b$best$best_gamma3, "\n\n")


selection_m_2b <- profile_select_number_breaks(
  out_m0 = out_m0_2b,
  summary_m1 = summary_m1_2b,
  summary_m2 = summary_m2_2b,
  prior_m = c("0" = 1/3, "1" = 1/3, "2" = 1/3)
)

cat("Table ranked by profile marginal likelihood:\n")
print(selection_m_2b$table_ranked)

cat("Selected number of breaks:", selection_m_2b$selected_m, "\n\n")

cat("Table in m = 0, 1, 2 order:\n")
print(selection_m_2b$table_by_m)

cat("Check against the simulated DGP:\n")
cat("True number of breaks: 2\n")
cat("Selected number:", selection_m_2b$selected_m, "\n")
cat("Correct selection:",
    if (selection_m_2b$selected_m == 2L) "YES" else "NO", "\n\n")

# 22. Save the local preliminary check

results_2b$model_selection <- list(
  m0 = out_m0_2b,
  m1_scan = out_scan_m1_2b,
  m1_summary = summary_m1_2b,
  m2_summary = summary_m2_2b,
  selection = selection_m_2b,
  tau_grid_m1 = tau_grid_m1_2b,
  prior_m = c("0" = 1/3, "1" = 1/3, "2" = 1/3)
)
# 23. Ex ante global selection of the number of breaks: m = 0, 1, 2
# 23.1 Helper functions for the global grid and refinement

make_global_tau_grid <- function(T0,
                                 T_end,
                                 min_segment_length,
                                 grid_step = 25) {
  
  tau_min <- T0 + min_segment_length
  tau_max <- T_end - min_segment_length
  
  seq(from = tau_min, to = tau_max, by = grid_step)
}

make_refined_grid_around <- function(center,
                                     radius,
                                     lower,
                                     upper,
                                     step = 1) {
  
  grid <- seq(
    from = max(lower, center - radius),
    to = min(upper, center + radius),
    by = step
  )
  
  as.integer(grid)
}

count_valid_twobreak_pairs <- function(tau_grid,
                                       T0,
                                       T_end,
                                       min_segment_length) {
  
  cand <- expand.grid(
    tau1 = tau_grid,
    tau2 = tau_grid
  )
  
  cand <- cand[cand$tau1 < cand$tau2, ]
  
  valid <- apply(cand, 1, function(z) {
    tau1 <- z[1]
    tau2 <- z[2]
    
    n1 <- tau1 - T0
    n2 <- tau2 - tau1
    n3 <- T_end - tau2
    
    all(c(n1, n2, n3) >= min_segment_length)
  })
  
  sum(valid)
}
# 23.2 Ex ante global-grid parameters

min_segment_global_2b <- 200
grid_step_global_2b <- 25
refine_radius_2b <- 30

tau_grid_global_2b <- make_global_tau_grid(
  T0 = T0_len_2b,
  T_end = T_sim_2b,
  min_segment_length = min_segment_global_2b,
  grid_step = grid_step_global_2b
)

cat("Ex ante global grid:\n")
cat("First absolute tau:", min(tau_grid_global_2b), "\n")
cat("Last absolute tau:", max(tau_grid_global_2b), "\n")
cat("Step:", grid_step_global_2b, "\n")
cat("Number of grid points:", length(tau_grid_global_2b), "\n")
cat("Number of valid m=2 pairs:",
    count_valid_twobreak_pairs(
      tau_grid = tau_grid_global_2b,
      T0 = T0_len_2b,
      T_end = T_sim_2b,
      min_segment_length = min_segment_global_2b
    ),
    "\n\n")
# 24. m = 0: no break

out_m0_global_2b <- bvar_facchange_nobreak(
  y = y_full_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b
)

cat("Log marginal likelihood for m=0:", out_m0_global_2b$logmarg, "\n")
cat("Best gamma for m=0:", out_m0_global_2b$best_gamma$gamma, "\n\n")
# 25. m = 1: global scan + refinement

out_scan_m1_global_2b <- bvar_changescan_onebreak(
  y = y_full_2b,
  tau_grid = tau_grid_global_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  verbose = TRUE
)

summary_m1_global_2b <- summarise_onebreak_profile(
  out_scan_1b = out_scan_m1_global_2b,
  T0 = T0_len_2b,
  true_tau1_est = tau1_est_2b,
  true_tau2_est = tau2_est_2b
)

cat("\nGlobal maximum for m=1:\n")
cat("tau_est:", summary_m1_global_2b$best$tau_est, "\n")
cat("absolute tau:", summary_m1_global_2b$best$tau, "\n")
cat("logmarg:", summary_m1_global_2b$best$logmarg, "\n")
cat("best gammas:",
    summary_m1_global_2b$best$best_gamma1,
    summary_m1_global_2b$best$best_gamma2, "\n\n")

cat("Local refinement for m=1 around the global maximum...\n")

tau_grid_m1_refined_2b <- make_refined_grid_around(
  center = summary_m1_global_2b$best$tau,
  radius = refine_radius_2b,
  lower = min(tau_grid_global_2b),
  upper = max(tau_grid_global_2b),
  step = 1
)

out_scan_m1_refined_2b <- bvar_changescan_onebreak(
  y = y_full_2b,
  tau_grid = tau_grid_m1_refined_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  verbose = TRUE
)

summary_m1_refined_2b <- summarise_onebreak_profile(
  out_scan_1b = out_scan_m1_refined_2b,
  T0 = T0_len_2b,
  true_tau1_est = tau1_est_2b,
  true_tau2_est = tau2_est_2b
)

cat("tau_est:", summary_m1_refined_2b$best$tau_est, "\n")
cat("absolute tau:", summary_m1_refined_2b$best$tau, "\n")
cat("logmarg:", summary_m1_refined_2b$best$logmarg, "\n")
cat("best gammas:",
    summary_m1_refined_2b$best$best_gamma1,
    summary_m1_refined_2b$best$best_gamma2, "\n\n")
# 26. m = 2: global scan + refinement

out_scan_m2_global_2b <- bvar_changescan_twobreak(
  y = y_full_2b,
  tau1_grid = tau_grid_global_2b,
  tau2_grid = tau_grid_global_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  min_segment_length = min_segment_global_2b,
  verbose = TRUE,
  store_fits = FALSE
)

summary_m2_global_2b <- summarise_twobreak_scan(
  out_scan = out_scan_m2_global_2b,
  T0 = T0_len_2b,
  tau1_true_est = tau1_est_2b,
  tau2_true_est = tau2_est_2b,
  true_gamma_labels = true_gamma_labels_2b
)

cat("tau1_est:", summary_m2_global_2b$best$tau1_est, "\n")
cat("tau2_est:", summary_m2_global_2b$best$tau2_est, "\n")
cat("absolute tau1:", summary_m2_global_2b$best$tau1, "\n")
cat("absolute tau2:", summary_m2_global_2b$best$tau2, "\n")
cat("logmarg:", summary_m2_global_2b$best$logmarg, "\n")
cat("best gammas:",
    summary_m2_global_2b$best$best_gamma1,
    summary_m2_global_2b$best$best_gamma2,
    summary_m2_global_2b$best$best_gamma3, "\n\n")

cat("Local refinement for m=2 around the global maximum...\n")

tau1_grid_m2_refined_2b <- make_refined_grid_around(
  center = summary_m2_global_2b$best$tau1,
  radius = refine_radius_2b,
  lower = min(tau_grid_global_2b),
  upper = max(tau_grid_global_2b),
  step = 1
)

tau2_grid_m2_refined_2b <- make_refined_grid_around(
  center = summary_m2_global_2b$best$tau2,
  radius = refine_radius_2b,
  lower = min(tau_grid_global_2b),
  upper = max(tau_grid_global_2b),
  step = 1
)

out_scan_m2_refined_2b <- bvar_changescan_twobreak(
  y = y_full_2b,
  tau1_grid = tau1_grid_m2_refined_2b,
  tau2_grid = tau2_grid_m2_refined_2b,
  pmax = pmax_2b,
  gamma_grid = gamma_grid_2b,
  prior_info = prior_info_2b,
  min_segment_length = min_segment_global_2b,
  verbose = TRUE,
  store_fits = FALSE
)

summary_m2_refined_2b <- summarise_twobreak_scan(
  out_scan = out_scan_m2_refined_2b,
  T0 = T0_len_2b,
  tau1_true_est = tau1_est_2b,
  tau2_true_est = tau2_est_2b,
  true_gamma_labels = true_gamma_labels_2b
)

cat("tau1_est:", summary_m2_refined_2b$best$tau1_est, "\n")
cat("tau2_est:", summary_m2_refined_2b$best$tau2_est, "\n")
cat("absolute tau1:", summary_m2_refined_2b$best$tau1, "\n")
cat("absolute tau2:", summary_m2_refined_2b$best$tau2, "\n")
cat("logmarg:", summary_m2_refined_2b$best$logmarg, "\n")
cat("best gammas:",
    summary_m2_refined_2b$best$best_gamma1,
    summary_m2_refined_2b$best$best_gamma2,
    summary_m2_refined_2b$best$best_gamma3, "\n\n")
# 27. Profile marginal likelihood comparison on the ex ante global grid

selection_m_global_2b <- profile_select_number_breaks(
  out_m0 = out_m0_global_2b,
  summary_m1 = summary_m1_refined_2b,
  summary_m2 = summary_m2_refined_2b,
  prior_m = c("0" = 1/3, "1" = 1/3, "2" = 1/3)
)

cat("Table ranked by profile score:\n")
print(selection_m_global_2b$table_ranked)

cat("Table in m = 0, 1, 2 order:\n")
print(selection_m_global_2b$table_by_m)

cat("Selected number of breaks:", selection_m_global_2b$selected_m, "\n")
cat("True number of breaks in the simulated DGP: 2\n")
cat("Correct selection:",
    if (selection_m_global_2b$selected_m == 2L) "YES" else "NO", "\n\n")

# 28. Save ex ante global-selection results

results_2b$model_selection_global <- list(
  settings = list(
    min_segment_global = min_segment_global_2b,
    grid_step_global = grid_step_global_2b,
    refine_radius = refine_radius_2b,
    tau_grid_global = tau_grid_global_2b
  ),
  m0 = out_m0_global_2b,
  m1_global_scan = out_scan_m1_global_2b,
  m1_global_summary = summary_m1_global_2b,
  m1_refined_scan = out_scan_m1_refined_2b,
  m1_refined_summary = summary_m1_refined_2b,
  m2_global_scan = out_scan_m2_global_2b,
  m2_global_summary = summary_m2_global_2b,
  m2_refined_scan = out_scan_m2_refined_2b,
  m2_refined_summary = summary_m2_refined_2b,
  selection = selection_m_global_2b,
  prior_m = c("0" = 1/3, "1" = 1/3, "2" = 1/3)
)
