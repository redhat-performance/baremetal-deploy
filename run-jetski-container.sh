ansible_dir=/root/JetSki/ansible-ipi-install

podman run -it \
	-v ./ansible-ipi-install/group_vars/all.yml:$ansible_dir/group_vars/all.yml:Z \
	-t localhost/jetski
