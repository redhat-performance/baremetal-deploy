FROM quay.io/centos/centos:8

ENV DISABLE_PODMAN=true

RUN dnf -y install python3.8 gcc platform-python-devel epel-release --nodocs
RUN dnf --enablerepo=epel -y install sudo sshpass openssh-clients git ipmitool ansible python3-dns python3-netaddr ipmitool --nodocs

RUN pip3.8 install update
RUN pip3.8 install click==7.1.2 idna==2.10 kubernetes==11.0.0 openshift==0.11.2 # due to apacke-airflow dependency version limit
RUN pip3.8 install jmespath psycopg2-binary apache-airflow[kubernetes] apache-airflow-providers-elasticsearch j2cli openshift netaddr

# Hammercli
# epel-release is needed, but was installed above.
RUN dnf install -y --skip-broken https://yum.theforeman.org/releases/2.1/el8/x86_64/foreman-release.rpm \
        https://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli-2.1.0-1.el8.noarch.rpm \
        http://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli_foreman-2.1.0-2.el8.noarch.rpm

RUN dnf install -y rubygem-hammer_cli rubygem-hammer_cli_foreman

# Done with hammercli. Next badfish
# Source: https://github.com/redhat-performance/badfish/blob/master/Dockerfile

RUN git clone https://github.com/redhat-performance/badfish /root/badfish

WORKDIR /root/badfish
RUN pip3.8 install -r requirements.txt

# Commented JetSki clone 
# ADD https://api.github.com/repos/redhat-performance/JetSki/git/refs/heads/master /root/JetSki-version.json
# RUN git clone --single-branch --branch master https://github.com/redhat-performance/JetSki.git /root/JetSki

# Add Airflow user and directories
ARG AIRFLOW_HOME=/opt/airflow
ARG AIRFLOW_UID="50000"
ARG AIRFLOW_GID="50000"
ARG AIRFLOW_USER_HOME_DIR=/home/airflow
ARG AIRFLOW_HOME=/opt/airflow

RUN groupadd --gid "${AIRFLOW_GID}" "airflow" && \
    useradd "airflow" --uid "${AIRFLOW_UID}" \
        --gid "${AIRFLOW_GID}" \
        --home "${AIRFLOW_USER_HOME_DIR}" && \
# Make Airflow files belong to the root group and are accessible. This is to accommodate the guidelines from
# OpenShift https://docs.openshift.com/enterprise/3.0/creating_images/guidelines.html
    mkdir -pv "${AIRFLOW_HOME}"; \
    mkdir -pv "${AIRFLOW_HOME}/dags"; \
    mkdir -pv "${AIRFLOW_HOME}/logs"; \
    chown -R "airflow:root" "${AIRFLOW_USER_HOME_DIR}" "${AIRFLOW_HOME}"; \
    find "${AIRFLOW_HOME}" -executable -print0 | xargs --null chmod g+x && \
        find "${AIRFLOW_HOME}" -print0 | xargs --null chmod g+rw

WORKDIR ${AIRFLOW_HOME}
RUN usermod -g 0 airflow -G ${AIRFLOW_GID}
RUN echo "airflow ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN update-alternatives --remove python /usr/libexec/no-python
RUN update-alternatives --remove python3 /usr/bin/python3.6
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1

RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

USER airflow
ENV AIRFLOW_HOME=/opt/airflow

# Done. Now run it.
# ENTRYPOINT ansible-playbook -i $ansible_dir/inventory/jetski/hosts $ansible_dir/playbook-jetski.yml
# ENTRYPOINT /bin/bash
