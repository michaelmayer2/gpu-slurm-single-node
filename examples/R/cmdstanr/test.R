# https://mc-stan.org/cmdstanr/articles/articles-online-only/opencl.html

# prerequisites
# install cmdstan 
cmdstanr::install_cmdstan()

# set OpenCL flag for compilation
cpp_options = list(
  "LDFLAGS+= -lOpenCL"
)

# rebuild cmdstan with OpenCL enabled
cmdstanr::cmdstan_make_local(cpp_options = cpp_options)
cmdstanr::rebuild_cmdstan()

# Get STAN model
write(RCurl::getURI("https://raw.githubusercontent.com/stan-dev/cmdstanr/master/vignettes/articles-online-only/opencl-files/bernoulli_logit_glm.stan"),"model.stan")

# Generate some fake data
n <- 250000
k <- 20
X <- matrix(rnorm(n * k), ncol = k)
y <- rbinom(n, size = 1, prob = plogis(3 * X[,1] - 2 * X[,2] + 1))
mdata <- list(k = k, n = n, y = y, X = X)

# Compile and run model on the GPU using OpenCL
mod_cl <- cmdstanr::cmdstan_model("model.stan",
                        cpp_options = list(stan_opencl = TRUE))

fit_cl <- mod_cl$sample(data = mdata, chains = 4, parallel_chains = 4,
                        opencl_ids = c(0, 0), refresh = 0)

# Compile and run the same model on the CPU
mod_cpu <- cmdstanr::cmdstan_model("model.stan", force_recompile = TRUE)
fit_cpu <- mod_cpu$sample(data = mdata, chains = 4, parallel_chains = 4, refresh = 0)

# Display the ratio of elapsed time for running the model on CPU and GPU
fit_cpu$time()$total / fit_cl$time()$total
