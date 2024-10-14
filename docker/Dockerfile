FROM rockylinux:9

RUN dnf install -y 'dnf-command(config-manager)' epel-release
RUN crb enable
RUN dnf config-manager --add-repo \
  https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && dnf clean expire-cache
RUN dnf install -y cuda-toolkit-12-4 libcudnn8

ENV R_VERSION="4.3.2"

RUN yum install -y sudo https://cdn.rstudio.com/r/rhel-9/pkgs/R-${R_VERSION}-1-1.x86_64.rpm 

ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LIBRARY_PATH=/usr/local/cuda/lib64
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64

RUN mkdir -p /opt/cmdstan/codes
COPY install.R /opt/cmdstan/codes

RUN /opt/R/${R_VERSION}/bin/Rscript /opt/cmdstan/codes/install.R

COPY cmdstan.R /opt/cmdstan/codes

RUN useradd -m -s /bin/bash cmdstanuser

USER cmdstanuser
WORKDIR /home/cmdstanuser
RUN curl -O https://raw.githubusercontent.com/stan-dev/cmdstanr/master/vignettes/articles-online-only/opencl-files/bernoulli_logit_glm.stan \
  && mv bernoulli_logit_glm.stan model.stan && /opt/R/${R_VERSION}/bin/Rscript /opt/cmdstan/codes/cmdstan.R

ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
