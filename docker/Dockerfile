FROM rockylinux:9

RUN dnf install -y 'dnf-command(config-manager)' epel-release
RUN crb enable
RUN dnf config-manager --add-repo \
  https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && dnf clean expire-cache
#RUN dnf install -y glibc-devel 
RUN dnf install -y cuda-toolkit-12-4
RUN dnf install -y libcudnn8

RUN echo -e 'export PATH=/usr/local/cuda/bin:\$PATH \n\
export LIBRARY_PATH=/usr/local/cuda/lib64:$LIBRARY_PATH \n\
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' > /etc/profile.d/cuda.sh

ENV R_VERSION="4.3.2"

RUN yum install -y sudo https://cdn.rstudio.com/r/rhel-9/pkgs/R-${R_VERSION}-1-1.x86_64.rpm 

ENV PATH=/usr/local/cuda/bin:$PATH
ENV LIBRARY_PATH=/usr/local/cuda/lib64
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64

RUN mkdir -p /opt/cmdstan/codes
COPY install.R /opt/cmdstan/codes

RUN /opt/R/${R_VERSION}/bin/Rscript /opt/cmdstan/codes/install.R

COPY cmdstan.R /opt/cmdstan/codes

RUN useradd -m -s /bin/bash cmdstanuser

USER cmdstanuser
WORKDIR /home/cmdstanuser
RUN curl -O https://raw.githubusercontent.com/stan-dev/cmdstanr/master/vignettes/articles-online-only/opencl-files/bernoulli_logit_glm.stan
RUN mv bernoulli_logit_glm.stan model.stan
RUN /opt/R/${R_VERSION}/bin/Rscript /opt/cmdstan/codes/cmdstan.R
