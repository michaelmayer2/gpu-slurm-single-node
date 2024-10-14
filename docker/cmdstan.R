# Data generation
n <- 250000
k <- 20
X <- matrix(rnorm(n * k), ncol = k)
y <- rbinom(n, size = 1, prob = plogis(3 * X[,1] - 2 * X[,2] + 1))
mdata <- list(k = k, n = n, y = y, X = X)

# CPU run

# Compile the model 
cmdstanr::set_cmdstan_path("/opt/cmdstan/cpu/cmdstan-2.35.0")
mod_cpu <- cmdstanr::cmdstan_model("model.stan",compile=FALSE)
mod_cpu$exe_file("model-cpu")
mod_cpu$compile()


# Run the model
#time_cpu<-system.time(fit_cpu <- mod_cpu$sample(data = mdata, chains = 4, parallel_chains = 4, refresh = 0))


# Compile the model 
cmdstanr::set_cmdstan_path("/opt/cmdstan/gpu/cmdstan-2.35.0")
mod_gpu <- cmdstanr::cmdstan_model("model.stan",compile=FALSE)
mod_gpu$exe_file("model-gpu")
#mod_gpu$compile(cpp_options = list("LDFLAGS+= -lOpenCL",stan_opencl = TRUE))
mod_gpu$compile(cpp_options = list(stan_opencl = TRUE))

## Run the model
#time_gpu<-system.time(fit_gpu <- mod_gpu$sample(data = mdata, chains = 4, parallel_chains = 4, refresh = 0))

# Compare CPU with GPU
#time_cpu/time_gpu
