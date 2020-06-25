ansible_dir=/root/JetSki/ansible-ipi-install

podman run -it \
	-v ./ansible-ipi-install/group_vars/all.yml:$ansible_dir/group_vars/all.yml:Z \
	-t localhost/with-centos
	#/bin/bash
	#ansible-playbook -vvv -i $ansible_dir/inventory/jetski/hosts $ansible_dir/playbook-jetski.yml
