#!/bin/bash
set -e

OUTPUT_DIR="${1:-${RUNNER_WORKDIR}}"

cat > "${OUTPUT_DIR}/ansible.cfg" << 'CFG_END'
[defaults]
roles_path = ./roles
host_key_checking = False
CFG_END

echo "remote_user = ${ANSIBLE_USER}" >> "${OUTPUT_DIR}/ansible.cfg"

cat >> "${OUTPUT_DIR}/ansible.cfg" << 'CFG_END'
private_key_file = ./ssh_private_key
CFG_END

echo "stdout_callback = ${ANSIBLE_STDOUT_CALLBACK}" >> "${OUTPUT_DIR}/ansible.cfg"
echo "force_color = ${ANSIBLE_FORCE_COLOR}" >> "${OUTPUT_DIR}/ansible.cfg"

cat >> "${OUTPUT_DIR}/ansible.cfg" << 'CFG_END'

[inventory]
enable_plugins = script, ini, yaml

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
CFG_END

echo "✓ Файл ansible.cfg сгенерирован"
