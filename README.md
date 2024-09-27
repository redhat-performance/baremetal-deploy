# MESSAGE
This repository is used by limited team who does IPI based installations, for other generic deployment [jetlag](https://github.com/redhat-performance/jetlag) is recommended. 

## JetSki
JetSki inherits roles from [upstream](https://github.com/openshift-kni/baremetal-deploy) and aims to provide a consistent, seamless OpenShift installation experience on bare metal in Red Hat's Shared Labs.

_**Table of Contents**_

<!-- TOC -->
- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Features of JetSki](#features-of-jetski)
- [Deployment Architecture](#deployment-architecture)
- [Tour of the Ansible Playbook](#tour-of-the-ansible-playbook)
- [Running the Ansible Playbook](#running-the-ansible-playbook)
- [Containerized JetSki](#containerized-jetski)
- [Versions Tested](#versions-tested)
- [Contributing](#contributing)
- [Limitations](#limitations)
- [Additional Material/Advanced Usage](#additional-materialadvanced-usage)
- [Troubleshooting](#troubleshooting)
<!-- /TOC -->

## Introduction

For contributions to the ansible-ipi-install roles please visit the [ansible-collection-redhatci-ocp](https://github.com/redhatci/ansible-collection-redhatci-ocp) repository.

## Installation artifacts

This Ansible playbook and set of Ansible roles are aimed at providing a cluster of Red Hat OpenShift 4 (`IPI`) in the Red Hat shared labs with as little user input and intervention as possible.

- [Performance](features/performance/). Performance-related features like Hugepages, real-time kernel, CPU Manager and Topology Manager.
- [Bonding](features/bonding/). A helper script to create bonding devices with ignition and/or NMstate.
- [DPDK](features/dpdk/). Example workload that uses DPDK libraries for packet processing.
- [Kubernetes NMstate](features/kubernetes-nmstate/). Node-networking configuration driven by Kubernetes and executed by NMstate.
- [Kubernetes NMstate day1](features/kubernetes-nmstate/day1/). Node-networking configuration driven by Kubernetes and executed by NMstate during the deployment of a cluster, by adding settings to install-config.yaml
- [PTP](features/ptp). This operator manages cluster-wide Precision Time Protocol (PTP) configuration.
- [SCTP](features/sctp). These assets enable Stream Control Transmission Protocol (SCTP) in the RHCOS
  worker nodes.
- [SR-IOV](features/sriov). The SR-IOV Network Operator creates and manages the components of the SR-IOV stack.
- [CNV](features/cnv). Container Native Virtualization is an add-on to OpenShift Container Platform that allows you to run and manage virtual machine workloads alongside container workloads.

## Prerequisites
The playbook is intended to be run from outside the cluster of machines you wish to deploy on, from a host we will refer to as `jumphost` for the purposes of this discussion. It could even be a user's laptop or some Virtual Machine. The host from which the the playbook is run from (`jumphost`) must satisfy the following requirements

* Ansible >= 2.9
* Python 3.6+ 
* Fedora/CentOS/RHEL (preferably Fedora 30+)
* Passwordless sudo for user running the playbook on the ansible control node (host where the playbooks are being run from), since certain package installs are done
* Install ansible collection `ansible-galaxy collection install -r requirements.yml` on your local machine

Passwordless sudo can be setup as below:
```
echo "username ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/username
chmod 0440 /etc/sudoers.d/username
```
The `username` should be the user with which the playbook is run.

The playbook has been most extensively tested running from a Fedora 30 `jumphost`.

The servers used for the OpenShift deployment itself are recommended to satisfy the following requirements. 

- Best Practice Minimum Setup: 6 Physical servers (1 provision node, 3 master and 2 worker nodes)
- Minimum Setup: 4 Physical servers (1 provision node, 3 master nodes)
- Each server needs a minimum 2 backend NICs (most hardware in the shared labs has atleast 3 backedn NICs)
- Each server should have a RAID-1 configured and initialized (should already be done in the shared labs)
- Each server must have IPMI configured (should already be done in the shared labs)

##  Features of JetSki
* Dynamic generation of inventory for a seamless deployment experience 
* Minimum variables needed for deployment, meaning more heavy lifting done by  the automation, resulting in lower margin of error and lesser time spent by user populating the inventory
* Low barrier of entry, no need for user to even simply copy keys for ansible to run against provisioner host, everything is done by the playbook
* Consistent user experience with everything being orchestrated through one playbook
* Can be run from outside the cluster, from a user's laptop or any `jumphost`
* Automatic detection of python interpreter on provisioner node
* Re-Images Provisioner node as needed through Foreman
* Prepares the the provisioner node for subsequent run of the installer
* Tightly integrated with lab automation, uses some metadata provided by the Lab Wiki along with automated network discovery for dynamic inventory generation
* Modular architecture, inherits roles from [upstream](https://github.com/openshift-kni/baremetal-deploy) without changing them, only adding roles that run before them, to setup the inventory and required parameters for the success of those roles
* Supports scaling up of a cluster(deployed using JetSki)

##  Deployment Architecture
For end-to-end automation and easy deployment, JetSki makes certain assumptions. The first node in your lab allocation is deployed as the provisioner host and the next 3 nodes are deployed as masters. The rest of the nodes are deployed as workers depending on how many workers were requested by user (by default all remaining nodes are deployed as workers unless otherwise specified by `worker_count` variable in `ansible-ipi-install/group_vars/all.yml`). `dnsmasq` is also setup on the provisioner to provide `DNS` and `DHCP` for the baremetal interfaces of the OpenShift nodes.

## Tour of the Ansible Playbook

The `ansible-ipi-install`  directory consists of three main sub-directories in addition to the main playbook `playbook-jetski.yml` that is used to kick off the installation. They are:

- `group_vars` - Contains the `all.yml` which holds the bare minimum variables needed for install
- `inventory` - contains the file `jetski/hosts` that has advanced variables for customized installation
- `roles` - contains 9 roles: `bootstrap`, `prepare-kni`, `add-provisioner`, `network-discovery`, `set-deployment-facts`, `shared-labs-prep`,`node_prep` `installer`, `scale-bootstrap`, `scale-node-prep` and `scale-worker`. 
- downloads 2 roles from the collectoins `redhatci.ocp` - `node_prep` and `installer`, `node_prep` handles all the prerequisites that the provisioner node requires prior to running the installer. The `installer` role handles extracting the installer, setting up the manifests, and running the Red Hat OpenShift installation.

The purpose served by each role can be summarized as follows:
* `bootstrap` - This role does a **lot** of heavy lifting for seamless deployment in the shared labs. On a high level, this role is responsible for installing needed packages on the `jumphost`, obtaining the list of nodes in your lab allocation dynamically, setting some variables required in inventory as ansible facts (like list of master nodes, worker nodes, mgmt interfaces), copying keys of the `jumphost` to the provisioner, rebuilding the provisioner if needed and finally adding the master and worker nodes to the in-memory dynamic inventory of ansible. This role runs on the `jumphost` aka `localhost`.
* `prepare-kni` -  Prepares the `kni` user and related artifacts on the provisioner node. This role runs on the provisioner host.
* `add-provisioner` - Adds provsioner host to the dynamic in-memory inventory. This role runs on the `jumphost` aka `localhost`.
* `network-discovery` - Set several important variables for the inventory including the NICs and MACs to be used for the provisioning and baremetal networks. Some of the MAC details are obtained from an inventory automatically generated on the Lab Wiki which the network-discovery role uses to further set all variables needed for proper networking. This role runs on the provisioner host.
* `set-deployment-facts` - This role is used to set some of the facts registered on the jumphost on to the provisioner host for use in future roles. This role runs on the provisioner host.
* `shared-labs-prep` - Creates the BM bridge, powers on nodes, sets boot order etc. This role runs on the provisioner host.
* `node_prep` - Prepares the provisioner node for the OpenShift Installer by installing needed packages, creating necessary directories etc. This role runs on the provisioner host.
* `installer` - Actually drives the OpenShift Installer. This role runs on the provisioner host.

Scale Up worker roles
* `scale-bootstrap` - This role is similar to **boostrap**, but runs only during scale up worker playbook execution, it is responsible for gathering inventory details from the file `ocpdeployednodeinv.json` and `ocpnondeployednodeinv.json`. It validates the input `worker_count` with the available non deployed nodes.
* `scale-node-prep` - This role is similar to **shared-labs-prep**, runs only during scale up worker playbook execution, it is responsible for setting up the boot order on the new worker nodes.
* `scale-worker` - This is the main role which does all openshift operations, it creates BMC scecret, BMH objects for new host and scale worker machinesets. 

The tree structure is shown below:

```sh
├── ansible.cfg
├── filter_plugins
│   ├── deprecate_me.py
│   └── warn_me.py
├── group_vars
│   └── all.yml
├── inventory
│   ├── jetski
│   │   └── hosts
│   └── upstream
│       └── hosts
├── OWNERS
├── playbook-jetski.yml
├── playbook-jetski-scaleup.yml
├── playbook.yml
└── roles
    ├── add-provisioner
    │   └── tasks
    │       └── main.yml
    ├── bootstrap
    │   ├── files
    │   │   ├── Dockerfile
    │   │   └── foreman.yml.j2
    │   ├── tasks
    │   │   ├── 01_install_packages.yml
    │   │   ├── 05_ssh_keys.yml
    │   │   ├── 10_load_inv.yml
    │   │   ├── 20_reprovision_nodes.yml
    │   │   ├── 25_copykeys.yml
    │   │   ├── 30_get_interpreter.yml
    │   │   ├── 40_prepare_provisioning.yml
    │   │   ├── 50_add_ocp_inventory.yml
    │   │   ├── 55_add_ocp_masters.yml
    │   │   ├── 60_add_ocp_workers.yml
    │   │   └── main.yml
    │   ├── templates
    │   │   └── node_inv.j2
    │   └── vars
    │       └── main.yml
    ├── network-discovery
    │   └── tasks
    │       └── main.yml
    ├── prepare-kni
    │   └── tasks
    │       └── main.yml
    ├── scale-bootstrap
    │   └── tasks
    │       ├── main.yml
    │       └── 10_load_old_inv.yml
    ├── scale-node-prep
    │   ├── tasks
    │   │   └── main.yml
    │   └── vars
    │       └── main.yml
    ├── scale-worker
    │   ├── defaults
    │   │   └── main.yml
    │   └── tasks
    │       ├── 01_dns_update.yml
    │       ├── 10_bmc_secrets.yml
    │       ├── 20_create_bmh.yml
    │       ├── 30_scale_machinesets.yml
    │       └── main.yml
    ├── set-deployment-facts
    │   └── tasks
    │       └── main.yml
    └── shared-labs-prep
        ├── defaults
        │   └── main.yml
        ├── library
        │   └── nmcli.py -> ../../node-prep/library/nmcli.py
        ├── tasks
        │   ├── 10_redfish_queue.yml
        │   └── main.yml
        ├── templates
        │   ├── ocp4-lab.dnsmasq.conf.j2
        │   └── ocp4-lab.ifcfg-template.j2
        ├── tests
        │   ├── inventory
        │   └── test.yml
        └── vars
            └── main.yml
```

## Running the Ansible Playbook

The TL;DR version is 

```sh
$ ansible-playbook -i inventory/jetski/hosts playbook-jetski.yml
```

However, for the playbook to successfully execute certain variables have to be set at a minimum in `ansible-ipi-install/group_vars/all.yml`.

The following are the detailed steps to successfully run the Ansible playbook.

### The `ansible.cfg` file

While the `ansible.cfg` may vary upon your environment a sample is provided in the repository. The default `ansible.cfg` supplied in this repository should work in the shared labs. This is purely infromational, **modifications are not necessary.**

```ini
[defaults]
inventory=./inventory
remote_user=kni
callback_whitelist = profile_tasks

[privilege_escalation]
become_method=sudo
```
### Modifying the `ansible-ipi-install/group_vars/all.yml` file

This is the most important file to modify for a successful install of OpenShift in the Red Hat Shared Labs. Some variables can be left default, but the most important ones to be filled out are
* `cloud_name`
* `lab_name`
* `ansible_ssh_password`
* `version`
* `build`
* `pullsecret`
* `foreman_url` (Used to rebuild provisioning host aka first host in your allocation with RHEL 8.1)

Here's a sample:
```yml
# Your allocation name/number in the shared labs
cloud_name: cloud00
# Lab name, typically can be alias or scale
lab_name: scale
# Default root password to your nodes in the lab allocation so that keys can be added automatically for ansible to run
ansible_ssh_pass: password
# Location of the private key of the user running the ansible playbook, leave default
ansible_ssh_key: "{{ ansible_user_dir }}/.ssh/id_rsa"
# The version of the openshift-installer, undefined or empty results in the playbook failing with error message.
# Values accepted: 'latest-4.3', 'latest-4.4', explicit version i.e. 4.3.0-0.nightly-2019-12-09-035405
# For reference, https://amd64.ocp.releases.ci.openshift.org/ and https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/
version: "4.4.4"
# Enter whether the build should use 'dev' (nightly builds) or 'ga' for Generally Available version of OpenShift
# Empty value results in playbook failing with error message.
build: "ga"
# Your pull secret as is, https://cloud.redhat.com/openshift/install
pullsecret: 
# This variable is used to point to the foreman server that is used to reimage nodes. This variables is useful in two cases
# 1. When the first node in your allocation (provisioning host) is not having RHEL 8.1 OS, it is automatically rebuilt with 
# RHEL 8.1 as the OCP installer expects the provisioning host to be RHEL 8.1. In some other cases, maybe when you have an 
# existing cluster and are trying to reinstall etc, it might be better to start with a clean provisioning host, in which case this variable
# is also used to reimage the provisioning host in spite of it having RHEL 8.1 on it. This variable changes depending on the lab you are
# using as each lab has its own foreman server. This URL can be deduced from the lab allocation email you receive when your allocation is
# ready. It will be under the paragraph "You can also view/manage your hosts via Foreman:" in the email. It is important to use an https
# prefix even if url in the email has http. Also, the url in email might have the '/hosts' path appended, we can remove 'hosts' from url 
# and have it be https://foreman.example.com for example. If you are having trouble figuring out this variable please look for the 
# pastebins under the "Modifying the ansible-ipi-install/group_vars/all.yml file" section in README.md
foreman_url: https://foreman.example.com/
# Choose a provisioner node from the allocated cloud, this is optional.
# Same thing can also be achieved by editing ocpinv.json file and reorder the nodes list. 
# https://github.com/redhat-performance/JetSki#changing-node-rolesexcluding-nodes-in-your-allocation-from-the-deployment
# If not specified, it will pick the first node in your cloud as provisioner(preferred)
# Make sure the specified server hostname doesn't not contain 'mgmt-' or '-drac'.
# provisioner_hostname: ""
# The automation automatically rebuilds provisioner node to RHEL 8.1 if not already RHEL 8.1 (see foreman_url variable)
# However you can also force a reprovsioning of the provisioner node for redeployment scenarios
rebuild_provisioner: false
# Number of workers desired, by default all hosts in your allocation except 1 provisioner and 3 masters are used workers
# However that behaviour can be overrided by explicitly setting the desired number of workers here. For a masters only deploy,
# set worker_count to 0
# Update this variable to scale up your existing cluster, provided lab allocation is sufficient to scale up to this count. 
# If not mentioned for a scale up execution, it includes all node available in the inventory `ocpnondeployednodeinv.json`
# If mentioned, this value should be final worker count and cannot be less than existing worker_count.
worker_count: 0
# set to true to deploy with jumbo frames
jumbo_mtu: false
# set to true only if you requested a public routable VLAN for your cloud in scale lab
routable_api: false
```

Here's a sample all.yml for the scale lab with the pull secret and password scraped: http://pastebin.test.redhat.com/962541

Here's a sample all.yml for the ALIAS lab with the pull secret and password scraped: http://pastebin.test.redhat.com/962544 

If you're a part of the [redhat-performance](https://github.com/redhat-performance) GitHub organization, you can also access the samples here: https://github.com/redhat-performance/JetSki-Configs/tree/master/jetski

### Modifying the `ansible-ipi-install/inventory/jetski/hosts` file

The bare minimum variables to get a successful install are listed in `ansible-ipi-install/group_vars/all.yml`. Typically, correctly filling `ansible-ipi-install/group_vars/all.yml` should suffice for the shared labs use case, but in cases where some advanced configuration is needed and to fully utilize the options supported by the installer and the [`upstream playbooks`]([https://github.com/openshift-kni/baremetal-deploy](https://github.com/openshift-kni/baremetal-deploy)), the `ansible-ipi-install/inventory/jetski/hosts` can be edited and used as an inventory file. For example, the `SDN` for OpenShift can be set using the `network_type` variable in the inventory. While editing the hosts file is optional the file **needs** to be passed to the ansible playbook invocation command using `-i inventory/jetski/hosts`. This is because it contains some default variables required for the installation.

Below is a sample of the `ansible-ipi-install/inventory/jetski/hosts`:

```ini
[all:vars]

###############################################################################
# Required configuration variables for IPI on Baremetal Installations         #
###############################################################################

# (Optional) Set the provisioning bridge name. Default value is 'provisioning'.
#provisioning_bridge=provisioning

# (Optional) Set the baremetal bridge name. Default value is 'baremetal'.
#baremetal_bridge=baremetal

# (Optional) Activation-key for proper setup of subscription-manager, empty value skips registration
#activation_key=""

# (Optional) Activation-key org_id for proper setup of subscription-manager, empty value skips registration
#org_id=""

# The directory used to store the cluster configuration files (install-config.yaml, pull-secret.txt, metal3-config.yaml)
dir="{{ ansible_user_dir }}/clusterconfigs"

# (Optional) Fully disconnected installs require manually downloading the release.txt file and hosting the file
# on a webserver accessible to the provision host. The release.txt file can be downloaded at
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/{{ version }}/release.txt (for DEV version)
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}/release.txt (for GA version)
# Example of hosting the release.txt on your example.com webserver under the 'latest-4.3' version directory.
# http://example.com:<port>/latest-4.3/release.txt
# Provide the webserver URL as shown below if using fully disconnected
#webserver_url=http://example.com:<port>

# Provisioning IP address (default value)
prov_ip=172.22.0.3

# (Optional) Provisioning network configuration overrides (4.4+)
prov_bootstrap_ip=172.22.0.2
prov_dhcp_range="172.22.0.10,172.22.0.254"

# (Optional) Enable playbook to pre-download RHCOS images prior to cluster deployment and use them as a local
# cache. Default is false.
#cache_enabled=True

# (Optional) The port exposed on the caching webserver. Default is port 8080.
#webserver_caching_port=8080

# (Optional) Enable IPv6 addressing instead of IPv4 addressing on both provisioning and baremetal network
ipv6_enabled=False

# (Optional) When ipv6_enabled is set to True, but want IPv4 addressing on provisioning network
# Default is false.
#ipv4_provisioning=True

# (Optional) When ipv6_enabled is set to True, but want IPv4 addressing on baremetal network
#ipv4_baremetal=True

# (Optional) A list of clock servers to be used in chrony by the masters and workers
#clock_servers=["pool.ntp.org","clock.redhat.com"]

# (Optional) Provide HTTP proxy settings
#http_proxy=http://USERNAME:PASSWORD@proxy.example.com:8080

# (Optional) Provide HTTPS proxy settings
#https_proxy=https://USERNAME:PASSWORD@proxy.example.com:8080

# (Optional) comma-separated list of hosts, IP Addresses, or IP ranges in CIDR format
# excluded from proxying
# NOTE: OpenShift does not accept '*' as a wildcard attached to a domain suffix
# i.e. *.example.com
# Use '.' as the wildcard for a domain suffix as shown in the example below.
# i.e. .example.com
#no_proxy_list="172.22.0.0/24,.example.com"

# The default installer timeouts for the bootstrap and install processes may be too short for some baremetal
# deployments. The variables below can be used to extend those timeouts.

# (Optional) Increase bootstrap process timeout by N iterations.
increase_bootstrap_timeout=2

# (Optional) Increase install process timeout by N iterations.
increase_install_timeout=2

######################################
# Vars regarding install-config.yaml #
######################################

# Base domain, i.e. example.com
domain="myocp4.com"
# Name of the cluster, i.e. openshift
cluster="test"
# Note: Under some conditions, it may be useful to randomize the cluster name. For instance,
# when redeploying an existing environment this can help avoid VRID conflicts. You can
# set the cluster_random boolean below to true to append a random number to you cluster name.
cluster_random=true
# The public CIDR address, i.e. 10.1.1.0/21
extcidrnet="192.168.222.0/24"

# NOTE: For the RH shared labs, the VIPs below are automated w/ variables
#       based on the extcidrnet above.

# An IP reserved on the baremetal network. 
dnsvip="{{ extcidrnet | next_nth_usable(2) }}"
# An IP reserved on the baremetal network for the API endpoint. 
# (Optional) If not set, a DNS lookup verifies that api.<clustername>.<domain> provides an IP
apivip="{{ extcidrnet | next_nth_usable(3) }}"
# An IP reserved on the baremetal network for the Ingress endpoint.
# (Optional) If not set, a DNS lookup verifies that *.apps.<clustername>.<domain> provides an IP
ingressvip="{{ extcidrnet | next_nth_usable(4) }}"
# The master hosts provisioning nic
# (Optional) If not set, the prov_nic will be used
#masters_prov_nic=""
# Network Type (OpenShiftSDN or OVNKubernetes). Playbook defaults to OVNKubernetes.
# Uncomment below for OpenShiftSDN
network_type="OVNKubernetes"
# (Optional) A URL to override the default operating system image for the bootstrap node.
# The URL must contain a sha256 hash of the image.
# See https://github.com/openshift/installer/blob/master/docs/user/metal/customization_ipi.md
#   Example https://mirror.example.com/images/qemu.qcow2.gz?sha256=a07bd...
#bootstraposimage=""
# (Optional) A URL to override the default operating system image for the cluster nodes.
# The URL must contain a sha256 hash of the image.
# See https://github.com/openshift/installer/blob/master/docs/user/metal/customization_ipi.md
# Example https://mirror.example.com/images/metal.qcow2.gz?sha256=3b5a8...
#clusterosimage=""

# Registry Host
#   Define a host here to create or use a local copy of the installation registry
#   Used for disconnected installation
# [registry_host]
# registry.example.com

# [registry_host:vars]
# The following cert_* variables are needed to create the certificates
#   when creating a disconnected registry. They are not needed to use
#   an existing disconnected registry.
# cert_country=US  # two letters country
# cert_state=MyState
# cert_locality=MyCity
# cert_organization=MyCompany
# cert_organizational_unit=MyDepartment

# The port exposed on the disconnected registry host can be changed from
# the default 5000 to something else by changing the following variable.
# registry_port=5000

# The directory the mirrored registry files are written to can be modified from teh default /opt/registry by changing the following variable.
# registry_dir="/opt/registry"

# The following two variables must be set to use an existing disconnected registry.
#
# Specify a file that contains extra auth tokens to include in the
#   pull-secret if they are not already there.
# disconnected_registry_auths_file=/path/to/registry-auths.json

# Specify a file that contains the addition trust bundle and image
#   content sources for the local registry. The contents of this file
#   will be appended to the install-config.yml file.
# disconnected_registry_mirrors_file=/path/to/install-config-appends.json
```

### The Ansible `playbook-jetski.yml`

The Ansible playbook generates the list of hosts it is operating against automatically based on your lab allocation and runs through the `roles` to give you an OpenShift on baremetal install. No modification of these roles or the playboo is necessary. All modifications of variables may be done within the `ansible-ipi-install/group_vars/all.yml` and `ansible-ipi-install/inventory/hosts` files. Please note that if the same variable is defined in `ansible-ipi-install/group_vars/all.yml` and `ansible-ipi-install/inventory/hosts`, the value in `ansible-ipi-install/group_vars/all.yml` will take precedence. A sample file for inventory is located at `ansible-ipi-install/inventory/jetski/hosts`.

Sample `playbook-jetski.yml`:

```yml
---
- name: IPI on Baremetal Installation Playbook -- Red Hat Shared Labs Edition
  hosts: localhost
  roles:
    - { role: bootstrap }

- hosts: provisioner
  roles:
    - { role: prepare-kni, ssh_path: /root/.ssh}

- hosts: localhost
  roles:
    - { role: add-provisioner }

- hosts: provisioner
  roles:
    - { role: network-discovery }
    - { role: set-deployment-facts }
    - { role: shared-labs-prep }
    - { role: node-prep }
    - { role: installer }
  environment:
    http_proxy: "{{ http_proxy }}"
    https_proxy: "{{ https_proxy }}"
    no_proxy: "{{ no_proxy_list }}"

- name: Finishing IPI on Baremetal Installation 
  hosts: provisioner
  tasks: 
    - name: Create directory
      file:
        state: directory
        path: "{{ ansible_facts['user_dir'] }}/scale-worker"

    - name: Writing Deployed node content to a file
      copy:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpdeployednodeinv.json"
        content: "{{ ocp_deploying_node_content | to_nice_json }}"
      when: ocp_deploying_node_content.nodes | length > 0   

    - name: Writing available non Deployed node content to a file
      copy:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpnondeployednodeinv.json"
        content: "{{ nondeploying_worker_nodes_content | to_nice_json }}"
      when: nondeploying_worker_nodes_content.nodes | length > 0

    - name: Deleting non Deployed node content
      file:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpnondeployednodeinv.json"
        state: absent
      when: nondeploying_worker_nodes_content.nodes | length == 0    
```


### Running the `playbook-jetski.yml`

With the `playbook-jetski.yml` set and in-place, run the `playbook-jetski.yml`

```sh
$ cd ansible-ipi-install/
$ ansible-playbook -i inventory/jetski/hosts playbook-jetski.yml
```

## Verifying Installation

Once the playbook has successfully completed, verify that your environment is up and running. 

1. Log into the provisioner node (typically the first node in you lab assignment)

```sh
ssh kni@provisioner.example.com
```

2. Export the `kubeconfig` file located in the `~/clusterconfigs/auth` directory

```sh
export KUBECONFIG=~/clusterconfigs/auth/kubeconfig
```

3. Verify the nodes in the OpenShift cluster

```sh
[kni@provioner~]$ oc get nodes
NAME                                         STATUS   ROLES           AGE   VERSION
master-0.openshift.example.com               Ready    master          19h   v1.16.2
master-1.openshift.example.com               Ready    master          19h   v1.16.2
master-2.openshift.example.com               Ready    master          19h   v1.16.2
worker-0.openshift.example.com               Ready    worker          19h   v1.16.2
```
### The Ansible `playbook-jetski-scaleup.yml`

This playbook scales up worker nodes to the desired `worker_count` mentioned in `ansible-ipi-install/group_vars/all.yml` make sure to update the worker_count before execution. This playbook reads the current cluster size and available nodes from `ocpdeployednodeinv.json` and `ocpnondeployednodeinv.json`(originally created by `playbook-jetski.yml`) stored in provisioner node `/home/kni/scale-worker/` directory. 

Sample `playbook-jetski-scaleup.yml`:

```yml
---
- name: IPI on Baremetal Installation Playbook -- Red Hat Shared Labs JetSki Edition
  hosts: orchestration
  roles:
    - { role: scale-bootstrap }

- hosts: provisioner
  tasks:
    - name: set facts needed for OCP deployment on the provisioning host
      set_fact:
        "{{ item }}": "{{ hostvars[groups['orchestration'][0]][item] }}"
      with_items:
        - worker_fqdns
        - lab_ipmi_user
        - lab_ipmi_password
        - scale_worker_node
        - worker_count
        - dell_nodes
        - supermicro_nodes
        - ocp_deploying_node_content
        - nondeploying_worker_nodes_content
        
- hosts: provisioner
  roles:
    - { role: scale-node-prep }
    - { role: scale-worker }

- name: Finishing IPI on Baremetal Installation 
  hosts: provisioner
  tasks:
    - block:
        - name: Update ocp_nondeplopyed_node_content
          set_fact:
            ocp_deploying_node_content: "{{ ocp_deploying_node_content | combine({'nodes': ocp_deploying_node_content.nodes|difference(failed_nodes)}, recursive=True) }}"

        - name: Update ocp_nondeplopyed_node_content
          set_fact:
            nondeploying_worker_nodes_content: "{{ nondeploying_worker_nodes_content | combine({'nodes': nondeploying_worker_nodes_content.nodes|union(failed_nodes)}, recursive=True) }}"
      when:
        - failed_nodes is defined
        - failed_nodes | length > 0
        
    - name: Writing Deployed node content to a file
      copy:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpdeployednodeinv.json"
        content: "{{ ocp_deploying_node_content | to_nice_json }}"
      when: ocp_deploying_node_content.nodes | length > 0   

    - name: Writing available non Deployed node content to a file
      copy:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpnondeployednodeinv.json"
        content: "{{ nondeploying_worker_nodes_content | to_nice_json }}"
      when: nondeploying_worker_nodes_content.nodes | length > 0

    - name: Deleting non Deployed node content
      file:
        dest: "{{ ansible_facts['user_dir'] }}/scale-worker/ocpnondeployednodeinv.json"
        state: absent
      when: nondeploying_worker_nodes_content.nodes | length == 0
```


### Running the `playbook-jetski.yml`

With the `playbook-jetski-scaleup.yml` set and in-place, run the `playbook-jetski-scaleup.yml`

```sh
$ ansible-playbook -i inventory/jetski/hosts playbook-jetski-scaleup.yml
```

## Verifying Installation

Once the playbook has successfully completed, verify that your environment is up and running. 

1. Log into the provisioner node (typically the first node in you lab assignment)

```sh
ssh kni@provisioner.example.com
```

2. Export the `kubeconfig` file located in the `~/clusterconfigs/auth` directory

```sh
export KUBECONFIG=~/clusterconfigs/auth/kubeconfig
```

3. Verify the new worker nodes in the OpenShift cluster

```sh
[kni@provioner~]$ oc get nodes
NAME                                         STATUS   ROLES           AGE   VERSION
master-0.openshift.example.com               Ready    master          19h   v1.16.2
master-1.openshift.example.com               Ready    master          19h   v1.16.2
master-2.openshift.example.com               Ready    master          19h   v1.16.2
worker-0.openshift.example.com               Ready    worker          19h   v1.16.2
worker-1.openshift.example.com               Ready    worker          19h   v1.16.2
```

## Containerized JetSki


### Building

To run JetSki in a container, you need the image.

You can build and run the image with podman. You only need podman installed.
If you have Docker installed instead of Podman, you can create an alias that makes the podman command run Docker.

The convenience script command to build it is:
```sh
./build-jetski-container.sh
```

If that does not work for you, you can build the image manually using the Dockerfile in the project root directory.

Alternatively, if the container is on an image repository, you can pull it from there.


### Configuration

The run script mentioned below uses the local computer's copy of the file `ansible-ipi-install/group-vars/all.yml` and `ansible-ipi-install/inventory/jetski/hosts`
You must configure that file as requested in the above section. [Containerized JetSki](#containerized-jetski)

### Running

The convenience script command run the image is:
```sh
./run-jetski-container.sh
```

You may manually run it with Docker or Podman, as long as you pass in the applicable configuration files.

## Versions Tested
Deployment of OCP 4.3, 4.4, 4.5 and 4.6 has been tested with this playbook.

## Contributing
We follow the standard GitHub process for PRs. One thing you need to note is that if your changes affect the `node-prep` or `installer` roles, the PR needs to be submitted against [baremetal-deploy](https://github.com/openshift-kni/baremetal-deploy) as JetSki uses those roles as is by rebasing, for maintainability.

## Limitations
* Designed for and tested only on Red Hat's Scale and ALIAS labs
* THe provisioner node and the three master nodes are expected to be of the same type with the same NIC configurations.

## Additional Material/Advanced Usage
For additional reading material and advanced usage of all the options provided by `ansible-ipi-install/inventory/jetski/hosts` please refer to [https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install](https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install) and [upstream docs]([https://openshift-kni.github.io/baremetal-deploy/](https://openshift-kni.github.io/baremetal-deploy/)). The playbook provided in this repo contantly aims to support everything supported [upstream](https://github.com/openshift-kni/baremetal-deploy/tree/master/ansible-ipi-install) which is made possible by the modular architecture of using upstream roles as is without change and only having extra roles that run before the upstream roles.

### Changing Node roles/Excluding nodes in your allocation from the deployment

By default, JetSki deploys a minimum of 3 masters and number of workers defined by `worker_count` in `ansible-ipi-install/group_vars/all.yml`. If `worker_count` is not defined, it deploys all the remaining nodes in your allocation (apart from the 1 provisioner host and 3 master nodes) as worker nodes. The nodes assigned to each role are also fixed in the sense that the first node in your allocation always becomes the provisioner host, the next 3 become the OpenShift masters and the remaining become workers. However, if you want to assign specific nodes to specific roles or keep a few nodes of your allocation out of the deployment, it can be achieved by changing the `ocpinv.json` file that is downloaded tothe `ansible-ipi-install` directory, when you are running the playbook from `localhost`. It's a little bit hackish, but here's what you would do

Initially, kick off the JetSki playbook run and after running for a few seconds you would see these tasks

```sh

TASK [bootstrap : check ocpinv file available] ***********************************************************************************************************************************************************************************************
Wednesday 01 July 2020  13:52:42 -0400 (0:00:00.199)       0:00:06.601 ******** 
ok: [localhost]

TASK [bootstrap : Download ocpninv.json] *****************************************************************************************************************************************************************************************************
Wednesday 01 July 2020  13:52:42 -0400 (0:00:00.332)       0:00:06.933 ******** 
skipping: [localhost]

TASK [bootstrap : Download ocpinv.json] ******************************************************************************************************************************************************************************************************
Wednesday 01 July 2020  13:52:42 -0400 (0:00:00.193)       0:00:07.127 ******** 
changed: [localhost]
```

As soon as the `Download ocpinv.json` task completes successfully, you can exit out of the playbook by using `ctrl+c` and then manually edit the `ocpinv.json` file. The file is a JSON dictionary which has a list of dictionaries under the `nodes` key, each of which represents a node in your lab allocation. By changing the order of nodes/removing nodes from here you are able to assign nodes to a particular role/remove them from deployment. Be careful to ensure that it is still a valid JSON after your edits. For example, if I want to ensure that a specific node in my allocation becomes the provisioner, I would move the dictionary representing that node  to the first position in the `nodes` list, or if I wanted to ensure specific nodes become OpenShift masters, I would put them in the 2,3 and 4 positions in the list, or if I wanted to exclude a few nodes, I would totally remove them from the list of `nodes`. After these changes, JetSki will consume the edited `ocpinv.json` instead of quads inventory order on every execution.

### Rerunning a failed scaleup worker job

In case of any failure during a scaleup play, make sure you remove all faulty nodes as well as other nodes which are not `provisioned` yet in the cluster and re-run the script from ansible node. 

Scaling down from 2 to 1,

```sh
oc get nodes
oc adm cordon <node_name>
oc adm drain <node_name> --force=true

oc get machinesets -n openshift-machine-api
oc scale --replicas=1 machineset <machineset> -n openshift-machine-api

# Check active worker nodes, it would have been reduced to 1
oc get nodes  
oc get machinesets

oc delete bmh <host_name> -n openshift-machine-api 
```

Wait till you the see the cluster back to normal state with reduced worker node, then re-run the playbook. 

This approach will not work if you want to rebuild a node after a successful playbook execution, because after a successful execution `ocpnondeployednodeinv.json` will be update to latest or removed. 
Re-run might use the update inventory.

### Public Routable API

By default the the Kuberentes API is only accessible from the provisioner node as the cluster does not have any lab routable IPs and the IPs are only routable from within the cluster. Along with your allocation in Scale Lab, you are able to request for  public routable IP addresses, in which case you can use the `routable_api` option to access your baremetal cluster from outside on the lab/provosioner host as long as you are on VPN. To do this, you need to set `routable_api` in `group_vars/all.yml` to `true` and along with that the `inventory/jetski/hosts` has to use the information from http://wiki.rdu2.scalelab.redhat.com/vlans/ for your cloud and look like below.

For example, if the the VLAN wiki page has details as follow:
```
605	10.1.54.0/24	255.255.255.0	10.1.54.254	254	smalleni	746	cloud37
```

My `inventory/jetski/hosts` should have the following content
```
######################################
# Vars regarding install-config.yaml #
######################################

# Base domain, i.e. example.com
domain="rdu2.scalelab.redhat.com"
# Name of the cluster, i.e. openshift
cluster="vlan605"
# Note: Under some conditions, it may be useful to randomize the cluster name. For instance,
# when redeploying an existing environment this can help avoid VRID conflicts. You can
# set the cluster_random boolean below to true to append a random number to you cluster name.
cluster_random=false
# The public CIDR address, i.e. 10.1.1.0/21
extcidrnet="10.1.54.0/24"
```

### Tips

* Make sure to change the root password of your provisioner host after the deployment, since all the hosts in the lab have the same password by default and JetSki picks the nodes to install OpenShift on based on the `cloud_name` field in `ansible-ipi-install/group_vars/all.yml`, it would otherwise be trivial for someone to accidentally re-install over your already installed cluster by supplying the wrong `cloud_name` in `ansible-ipi-install/group_vars/all.yml`.

## Troubleshooting

Once the playbook reaches the task

```sh
TASK [installer : Deploy OpenShift Cluster]
```

The control is passed to the OpenShift installer and any failure in the deployment of OpenShift after that point is either due to hardware issues or installer issues itself. It is not a JetSki failure.

Something that has worked out well in the past is to keep the consoles of all three of your master nodes open during deployment, so that you can observe if any one node is misbehaving when compared to the others. There are 3 boots total before the masters fully become operational and cluster operators start rolling out.

* First PXE boot into RHEL 8.1 for introspection and download of CoreOS image
* Then second boot to disk to boot into CoreOS image and run OSTree
* One final reboot and the node should come up as master-0 or master-1 or master-2 at the prompt

Deployments usually fail if the above three steps do not happen. Sometimes, a node might not boot to disk and be stuck in a PXE loop even when asked to boot to hard disk by the installer or it might be stuck at the OS selection menu when asked to boot to disk. These among several other issues have been seen with hardware in the past and it is worth keeping an eye on the console and intervening if needed for a successful deploy. This is beyond the scope of the playbook or for that matter even the installer.
