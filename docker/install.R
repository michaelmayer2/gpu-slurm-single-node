## Prerequisites (one-time setup)
options(repos="https://packagemanager.posit.co/cran/__linux__/rhel9/latest")
install.packages("pak")
options(repos=c('https://stan-dev.r-universe.dev', getOption("repos")))
pak::pak(c('cmdstanr','parallelly'))

library(cmdstanr)
cpu_dir<-"/opt/cmdstan/cpu"
dir.create(cpu_dir,recursive=TRUE)
cmdstanr::install_cmdstan(
  version = "2.35.0", 
  dir = cpu_dir,
  cores = parallelly::availableCores()
  )


## Prerequisites (one-time setup)
gpu_dir<- "/opt/cmdstan/gpu"

cpp_options = list(stan_opencl = TRUE, "LDFLAGS+= -lOpenCL")
  
dir.create(gpu_dir,recursive=TRUE)
cmdstanr::install_cmdstan(
  version = "2.35.0",
  dir = gpu_dir,
  cpp_options = cpp_options,
  cores = parallelly::availableCores()
)


