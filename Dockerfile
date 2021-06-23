FROM quay.io/centos/centos:8
ENV DISABLE_PODMAN=true
ENV rhel_version=8

ENV ansible_version=<2.10

ENV foreman_version=2.4
ENV foreman_url=https://yum.theforeman.org/releases/$foreman_version/el$rhel_version/x86_64/foreman-release.rpm

ENV ipmitool_version=1.8.18-17
ENV ipmitool_rpm=ipmitool-$ipmitool_version.el$rhel_version.x86_64.rpm
ENV ipmitool_url=http://mirror.centos.org/centos/$rhel_version/AppStream/x86_64/os/Packages/$ipmitool_rpm

RUN dnf -y upgrade && \
    dnf -y install --nodocs python3 python3-pip python3-dns gcc platform-python-devel openssh-clients git && \
    dnf -y install --nodocs https://dl.fedoraproject.org/pub/epel/epel-release-latest-$rhel_version.noarch.rpm && \
    dnf -y install --nodocs --enablerepo=epel sshpass && \
    dnf -y install --nodocs $ipmitool_url && \
    dnf -y install --nodocs $foreman_url && \
    dnf -y install --nodocs rubygem-hammer_cli rubygem-hammer_cli_foreman

RUN useradd jetski --home-dir /jetski --create-home --user-group
USER jetski
WORKDIR /jetski

ENV PATH=/jetski/.local/bin:${PATH}
ENV BADFISH_DIR=/jetski/badfish
ENV JETSKI_DIR=/jetski/JetSki
ENV ANSIBLE_DIR=${JETSKI_DIR}/ansible-ipi-install

RUN git clone --single-branch --branch master https://github.com/redhat-performance/badfish ${BADFISH_DIR} && \
    git --git-dir ${BADFISH_DIR}/.git show-ref --verify refs/heads/master && \
    git clone --single-branch --branch master https://github.com/redhat-performance/JetSki.git ${JETSKI_DIR} && \
    git --git-dir ${JETSKI_DIR}/.git show-ref --verify refs/heads/master

RUN python3 -m pip install --user --upgrade pip && \
    python3 -m pip install --user "ansible${ansible_version}" j2cli jmespath netaddr && \
    python3 -m pip install --user -r "${BADFISH_DIR}/requirements.txt" && \
    ansible-galaxy collection install ansible.utils containers.podman

WORKDIR ${BADFISH_DIR}

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
