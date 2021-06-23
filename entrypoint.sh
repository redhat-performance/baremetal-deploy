#!/usr/bin/env bash
set -e

if [[ -z "${SSH_PRIVATE_KEY_DATA}" ]]; then
  echo "ERROR: No SSH private key provided, exiting."
  exit 1
fi

mkdir -p "${HOME}/.ssh"
echo -e "${SSH_PRIVATE_KEY_DATA}" > "${HOME}/.ssh/id_rsa"
chmod 0600 -R "${HOME}/.ssh"

ssh-keygen -y -f "${HOME}/.ssh/id_rsa" > "${HOME}/.ssh/id_rsa.pub"
chmod 0600 "${HOME}/.ssh/id_rsa.pub"

ansible-playbook -i ${ANSIBLE_DIR}/inventory/jetski/hosts ${EXTRA_VARS} "${JETSKI_DIR}/${1}" "${@:2}"
