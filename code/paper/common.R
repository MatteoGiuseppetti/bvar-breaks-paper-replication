# Reused mathematical functions: extracts from thesis script (line endings normalized).
# See docs/PAPER_CODE_MAP.md for the original source locations.

# Original BVAR_thesis_full_code.R lines 10-62 (verbatim)
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


# Original BVAR_thesis_full_code.R lines 94-321 (verbatim)
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


# Original BVAR_thesis_full_code.R lines 672-675 (verbatim)
label_to_gamma <- function(label) {
  as.integer(strsplit(label, split = "")[[1]])
}

