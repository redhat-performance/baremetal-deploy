#FROM registry.access.redhat.com/ubi8/ubi
FROM centos:8

ENV ansible_dir=/root/JetSki/ansible-ipi-install
ENV IN_CONTAINER=true

RUN yum -y install python3 --nodocs
RUN pip3 install ansible
RUN yum -y install epel-release --nodocs
RUN yum --enablerepo=epel -y install sshpass
RUN yum -y install openssh-clients --nodocs
RUN yum -y install git --nodocs
RUN pip3 install jmespath

# Hammercli
# epel-release is needed, but was installed above.
RUN yum install -y https://yum.theforeman.org/releases/2.1/el8/x86_64/foreman-release.rpm
RUN yum install -y https://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli-2.1.0-1.el8.noarch.rpm 
RUN yum install -y http://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli_foreman-2.1.0-2.el8.noarch.rpm

RUN yum install -y rubygem-hammer_cli \
	rubygem-hammer_cli_foreman

RUN pip3 install j2cli

# Done with hammercli. Next badfish
# Source: https://github.com/redhat-performance/badfish/blob/master/Dockerfile

RUN git clone https://github.com/redhat-performance/badfish /root/badfish

WORKDIR /root/badfish
RUN pip3 install -r requirements.txt
RUN python3 setup.py build
RUN python3 setup.py install

ADD https://api.github.com/repos/jaredoconnell/JetSki/git/refs/heads/containerized version.json
RUN git clone --single-branch --branch master https://github.com/redhat-performance/JetSki.git /root/JetSki

# Done. Now run it.
ENTRYPOINT ansible-playbook -vvv -i $ansible_dir/inventory/jetski/hosts $ansible_dir/playbook-jetski.yml
#ENTRYPOINT /bin/bash

