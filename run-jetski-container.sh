#!/usr/bin/env bash
set -e
SSH_KEY_FILE="${1}"
RELATIVE_PLAYBOOK_PATH=${2}

JETSKI_IMAGE=jetski
LOCAL_ANSIBLE_DIR="$(pwd)/ansible-ipi-install"
CONTAINER_ANSIBLE_DIR="/jetski/JetSki/ansible-ipi-install"

CRT=$(which podman)
if [[ -z "${CRT}" ]]; then
  echo "ERROR: No container runtime found, please install podman"
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  CRT="${CRT} --remote"
fi

if [[ -z "${RELATIVE_PLAYBOOK_PATH}" ]] || [[ ! -f "${RELATIVE_PLAYBOOK_PATH}" ]]; then
  echo "Must specify playbook from ansible-ipi-install"
  exit 1
fi

export SSH_PRIVATE_KEY_DATA=$(cat "${SSH_KEY_FILE}")
export JETSKI_CONFIG=$(cat "${LOCAL_ANSIBLE_DIR}/group_vars/all.yml")
export JETSKI_HOSTS=$(cat "${LOCAL_ANSIBLE_DIR}/inventory/jetski/hosts")

JETSKI_CONTAINER_ID=$(${CRT} create \
  -e SSH_PRIVATE_KEY_DATA \
	${JETSKI_IMAGE} "${RELATIVE_PLAYBOOK_PATH}" "${@:3}")

echo "JETSKI_CONTAINER_ID: ${JETSKI_CONTAINER_ID}"

COPY_ARRAY=(ocpinv.json ocpdeployednodeinv.json ocpnondeployednoneinv.json group_vars/all.yml inventory/jetski/hosts)
for filename in "${COPY_ARRAY[@]}"; do
  ${CRT} cp ${LOCAL_ANSIBLE_DIR}/${filename} ${JETSKI_IMAGE}:${CONTAINER_ANSIBLE_DIR}/${filename}
done

set +e
${CRT} run -it ${JETSKI_CONTAINER_ID}
EXIT_CODE=${?}
set -e

for filename in (ocpdeployednodeinv.json ocpnondeployednoneinv.json); do
  ${CRT} cp ${JETSKI_IMAGE}:${CONTAINER_ANSIBLE_DIR}/${filename} ${LOCAL_ANSIBLE_DIR}/${filename}
done

${CRT} rm ${JETSKI_CONTAINER_ID}
exit ${EXIT_CODE}
