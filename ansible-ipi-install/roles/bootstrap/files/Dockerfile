FROM centos:8
ARG foreman_url=https://foreman.example.com
RUN yum install -y epel-release \
        python3

RUN yum install -y https://yum.theforeman.org/releases/2.1/el8/x86_64/foreman-release.rpm
RUN yum install -y https://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli-2.1.0-1.el8.noarch.rpm 
RUN yum install -y http://yum.theforeman.org/releases/2.1/el8/x86_64/rubygem-hammer_cli_foreman-2.1.0-2.el8.noarch.rpm

RUN yum install -y rubygem-hammer_cli \
	rubygem-hammer_cli_foreman

RUN pip3 install j2cli
RUN  hammer --fetch-ca-cert ${foreman_url}
COPY foreman.yml.j2 /root/
RUN j2 /root/foreman.yml.j2 > /etc/hammer/cli.modules.d/foreman.yml
