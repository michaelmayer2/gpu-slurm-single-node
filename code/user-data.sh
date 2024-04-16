#!/bin/bash

exec > /var/log/user-data-install.log
exec 2>&1

setenforce permissive
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/sysconfig/selinux 
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
grubby --update-kernel ALL --args selinux=permissive

dnf install -y 'dnf-command(config-manager)' epel-release
crb enable
dnf config-manager --add-repo \
  https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
dnf clean expire-cache
dnf install -y dkms
dnf module install -y nvidia-driver:latest-dkms
dnf install -y cuda-toolkit-12-4
dnf install -y libcudnn8

cat << EOF > /etc/profile.d/cuda.sh
export PATH=/usr/local/cuda/bin:\$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
EOF

systemctl enable dkms
systemctl enable nvidia-persistenced

if [ -z $R_VERSION_LIST ]; then R_VERSION_LIST="3.8.19 3.9.19 3.10.14 3.11.8"; fi

# While CUDA seems to prefer JAVA 11, Binary R packages are typically compiled with Java 8 only. 
dnf -y install java-1.8.0-openjdk-devel

curl -O  https://raw.githubusercontent.com/sol-eng/singularity-rstudio/main/data/r-session-complete/centos7/scripts/run.R
curl -O  https://raw.githubusercontent.com/sol-eng/singularity-rstudio/main/data/r-session-complete/centos7/scripts/bioc.txt

for R_VERSION in $R_VERSION_LIST; do yum install -y https://cdn.rstudio.com/r/rhel-9/pkgs/R-${R_VERSION}-1-1.x86_64.rpm; done

for R_VERSION in $R_VERSION_LIST; do \
        export PATH=/opt/R/$R_VERSION/bin:$PATH && \
        export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk/ && \
        /opt/R/${R_VERSION}/bin/R CMD javareconf; done


# Python installation 

if [ -z $PYTHON_VERSION_LIST ]; then PYTHON_VERSION_LIST="3.8.19 3.9.19 3.10.14 3.11.8"; fi

for PYTHON_VERSION in $PYTHON_VERSION_LIST
do
    yum install -y https://cdn.rstudio.com/python/rhel-9/pkgs/python-${PYTHON_VERSION}-1-1.x86_64.rpm
done

# Python version to be used for jupyter install (last one of PYTHON_VERSION_LIST)
TMPVAR=($PYTHON_VERSION_LIST)
PYTHON_VERSION=${TMPVAR[@]: -1}
# JupyterLab Version selected 
JUPYTERLAB_VERSION=3.6.5

/opt/python/"${PYTHON_VERSION}"/bin/python -m venv /opt/python/jupyter \
    && /opt/python/jupyter/bin/pip install \
      jupyter \
      jupyterlab=="${JUPYTERLAB_VERSION}" \
      rsconnect_jupyter \
      rsconnect_python \
      rsp_jupyter \
      workbench_jupyterlab \
    && ln -s /opt/python/jupyter/bin/jupyter /usr/local/bin/jupyter \
    && /opt/python/jupyter/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter \
    && /opt/python/jupyter/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter \
    && /opt/python/jupyter/bin/jupyter-nbextension install --sys-prefix --py rsconnect_jupyter \
    && /opt/python/jupyter/bin/jupyter-nbextension enable --sys-prefix --py rsconnect_jupyter \
    && /opt/python/jupyter/bin/jupyter-serverextension enable --sys-prefix --py rsconnect_jupyter



if [ -z $SLURM_VERSION ]; then export SLURM_VERSION=23.11.5-1

dnf install -y git

groupadd -r --gid=105 munge
useradd -r -s /bin/bash -g munge --uid=105 munge

dnf install -y bash-completion mariadb-devel mariadb-server hdf5-devel munge munge-devel dbus-devel hwloc-devel readline-devel lua-devel man2html

if [ -f /usr/sbin/create-munge-key ]; then /usr/sbin/create-munge-key ; else /usr/sbin/mungekey -c -f; fi

export SLURM_PREFIX=/usr/local
mkdir -p $SLURM_PREFIX/etc/slurm && mkdir -p /tmp/build && cd /tmp/build \
    && bash -c "git clone --depth 1 -b slurm-\${SLURM_VERSION//./-} https://github.com/SchedMD/slurm.git" \
    && cd slurm \
    && echo "Configuring SLURM ${SLURM_VERSION}" \
    && bash -c "./configure --enable-debug --prefix=$SLURM_PREFIX --sysconfdir=$SLURM_PREFIX/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=$SLURM_PREFIX/lib64 --with-systemdsystemunitdir=/usr/lib/systemd/system/ >& $SLURM_PREFIX/etc/slurm/.configure.log"  \
    && echo "Building SLURM ${SLURM_VERSION}" \
    && bash -c "make -j 8 >& $SLURM_PREFIX/etc/slurm/.build.log" \
    && echo "Installing SLURM ${SLURM_VERSION}" \
    && bash -c "make -j 8 install >& $SLURM_PREFIX/etc/slurm/.install.log" \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && cd .. \
    && rm -rf slurm \
    && groupadd -r --gid=980 slurm \
    && useradd -r -g slurm --uid=985 slurm \
    && mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurm \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /var/spool/slurmctld \
    && chown -R slurm:slurm /var/*/slurm*

# make sure /usr/local/bin is in $PATH
echo "export PATH=/usr/local/bin:\$PATH" > /etc/profile.d/path-usr-local.sh

# Configure mariadb
systemctl enable mariadb
systemctl start mariadb

mysql_secure_installation << EOF

Y
Y
Testme1234
Testme1234
Y
Y
Y
Y
EOF

# SLURM configuration

mkdir -p /usr/local/etc/slurm/
cat << EOF > /usr/local/etc/slurm/slurm.conf
ClusterName=pwb
SlurmctldHost=localhost
ProctrackType=proctrack/cgroup
ReturnToService=1
SlurmctldPidFile=/var/run/slurm/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurm/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
StateSaveLocation=/var/spool/slurmctld
TaskPlugin=task/affinity,task/cgroup
InactiveLimit=0
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0
SchedulerType=sched/backfill
SelectType=select/cons_tres
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageTRES=gres/gpu,gres/shard
GresTypes=gpu,shard
JobCompType=jobcomp/none
JobAcctGatherFrequency=10
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log
#NodeName=localhost CPUs=8 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 Gres=gpu:1,shard:8 State=UNKNOWN
NodeName=localhost CPUs=8 Boards=1 Gres=gpu:v100:1,shard:8 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=2 RealMemory=61022 State=UNKNOWN
PartitionName=all Nodes=ALL Default=YES MaxTime=INFINITE State=UP
EOF

cat << EOF > /usr/local/etc/slurm/slurmdbd.conf
AuthType=auth/munge
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/var/run/slurm/slurmdbd.pid
DbdPort=6819
SlurmUser=slurm
StorageType=accounting_storage/mysql

DbdHost=localhost
StorageHost=localhost
StoragePort=3306
StorageLoc=slurm
StorageUser=root
StoragePass=Testme1234
EOF

cat << EOF > /usr/local/etc/slurm/gres.conf
AutoDetect=off
NodeName=localhost Name=gpu Type=v100 File=/dev/nvidia0
NodeName=localhost Name=shard Count=8
#p3.8xlarge
#NodeName=localhost Name=gpu Type=v100 File=/dev/nvidia0
#NodeName=localhost Name=gpu Type=v100 File=/dev/nvidia1
#NodeName=localhost Name=gpu Type=v100 File=/dev/nvidia3
#NodeName=localhost Name=gpu Type=v100 File=/dev/nvidia2
#NodeName=localhost Name=shard Count=8
EOF

cat << EOF > /usr/local/etc/slurm/cgroup.conf
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
EOF

chown slurm /usr/local/etc/slurm/slurmdbd.conf
chmod 0600 /usr/local/etc/slurm/slurmdbd.conf

systemctl enable munge
systemctl enable slurmctld 
systemctl enable slurmdbd
systemctl enable slurmd



# Workbench installation 

if [ -z $PWB_VERSION ]; then export PWB_VERSION=2024.04.0-daily-675.pro4; fi
yum -y install https://s3.amazonaws.com/rstudio-ide-build/server/rhel9/x86_64/rstudio-workbench-rhel-${PWB_VERSION}-x86_64.rpm

# Workbench setup

configdir="/etc/rstudio"

# Add SLURM integration 
myip=`curl http://checkip.amazonaws.com`

mkdir -p /opt/rstudio/shared-storage

cat > $configdir/launcher-env << EOF
RSTUDIO_DISABLE_PACKAGE_INSTALL_PROMPT=yes
SLURM_CONF=/usr/local/etc/slurm.conf
EOF
 
cat > $configdir/rserver.conf << EOF

# Launcher Config
launcher-address=127.0.0.1
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=Slurm
launcher-sessions-callback-address=http://${myip}:8787

# Disable R Versions scanning
#r-versions-scan=0

auth-pam-sessions-enabled=1
auth-pam-sessions-use-password=1

# Enable Admin Dashboard
admin-enabled=1
admin-group=rstudio-admins
admin-superuser-group=rstudio-superuser-admins
admin-monitor-log-use-server-time-zone=1
audit-r-console-user-limit-mb=200
audit-r-console-user-limit-months=3

# Enable Auditing
audit-r-console=all
audit-r-sessions=1
audit-r-sessions-limit-mb=512
audit-r-sessions-limit-months=6

EOF

cat > $configdir/launcher.conf<<EOF
[server]
address=127.0.0.1
port=5559
server-user=rstudio-server
admin-group=rstudio-server
authorization-enabled=1
thread-pool-size=4
enable-debug-logging=1

[cluster]
name=Slurm
type=Slurm

#[cluster]
#name=Local
#type=Local

EOF

#cat > $configdir/launcher.slurm.profiles.conf<<EOF 
#[*]
#default-cpus=1
#default-mem-mb=512
##max-cpus=2
#max-mem-mb=1024
#EOF

cat > $configdir/launcher.slurm.resources.conf<<EOF
[small]
name = "Small (1 cpu, 8 GB mem)"
cpus=1
mem-mb=7627
[medium]
name = "Medium (2 cpu, 16 GB mem)"
cpus=2
mem-mb=15255
[large]
name = "Large (4 cpu, 32 GB mem)"
cpus=4
mem-mb=30511
[xlarge]
name = "Large (8 cpu, 64 GB mem)"
cpus=4
mem-mb=61022
EOF

cat > $configdir/launcher.slurm.conf << EOF 
# Enable debugging
enable-debug-logging=1

# Basic configuration
slurm-service-user=slurm
slurm-bin-path=/usr/local/bin

# GPU specifics
enable-gres=1
#gpu-types=v100

EOF

cat > $configdir/jupyter.conf << EOF
jupyter-exe=/usr/local/bin/jupyter
notebooks-enabled=1
labs-enabled=1
EOF

# Install VSCode based on the PWB version.
if ( rstudio-server | grep configure-vs-code ); then rstudio-server configure-vs-code ; rstudio-server install-vs-code-ext; else rstudio-server install-vs-code /opt/rstudio/vscode/; fi
  
cat > $configdir/vscode.conf << EOF
enabled=1
exe=/usr/lib/rstudio-server/bin/code-server/bin/code-server
args=--verbose --host=0.0.0.0 
EOF

# Add sample user 
groupadd --gid 8787 rstudio
useradd -s /bin/bash -m --gid rstudio --uid 8787 rstudio
groupadd --gid 8788 rstudio-admins
groupadd --gid 8789 rstudio-superuser-admins
usermod -G rstudio-admins,rstudio-superuser-admins rstudio

# below SECRET string is a 10-digit random string that will be saved
rspasswd = `tr -dc A-Za-z0-9 < /dev/urandom | head -c 10; echo`
echo $rspasswd > /home/rstudio/.rstudio-pw
echo -e "$rspasswd\n$rspasswd" | passwd rstudio


# Install a couple of useful tools

yum install -y pciutils net-tools nc

# Structure systemctl order of running services

sed -i 's/After=.*/After=dkms.service/' /usr/lib/systemd/system/nvidia-persistenced.service 
sed -i 's/After=/&slurmdbd.service /' /usr/lib/systemd/system/slurmctld.service
sed -i 's/After=/&slurmctld.service /' /usr/lib/systemd/system/slurmd.service
sed -i '/After=.*/a ConditionPathExists=\/dev\/nvidia0' /usr/lib/systemd/system/slurmd.service
sed -i '/ExecReload=.*/a ExecStartPost=\/usr\/bin\/timeout 30 sh -c "while ! ss -H -t -l -n sport = \:6819 | grep -q ^LISTEN.*:6819; do sleep 1; done"' /usr/lib/systemd/system/slurmdbd.service
sed -i 's/After=/&rstudio-launcher.service /' /usr/lib/systemd/system/rstudio-server.service
sed -i 's/After=/&slurmctld.service /' /usr/lib/systemd/system/rstudio-launcher.service


# reboot 

reboot 



