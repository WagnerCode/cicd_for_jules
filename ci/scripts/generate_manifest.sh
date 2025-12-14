#!/bin/bash
set -e

OUTPUT_DIR="${1:-${RUNNER_WORKDIR}}"

cat > "${OUTPUT_DIR}/config_manifest.json" << JSON_END
{
  "generated_at": "$(date -Iseconds)",
  "pipeline_id": "${CI_PIPELINE_ID}",
  "pipeline_url": "${CI_PIPELINE_URL}",
  "commit_sha": "${CI_COMMIT_SHA}",
  "commit_ref": "${CI_COMMIT_REF_NAME}",
  "runner_description": "${CI_RUNNER_DESCRIPTION}",
  "source_archive": "${CORAX_ARCHIVE}",
  "archive_location": "${DISTRIBS_DIR}/${CORAX_ARCHIVE}",
  "deploy_node_host": "${DEPLOY_NODE_HOST}",
  "deploy_node_user": "${DEPLOY_NODE_USER}",
  "ansible_user": "${ANSIBLE_USER}",
  "kfk_version": "${KFK_VERSION}",
  "corax_dir": "${CORAX_DIR}",
  "kafka_install_dir": "${KAFKA_INSTALL_DIR}",
  "kafka_data_dir": "${KAFKA_DATA_DIR}",
  "zookeeper_data_dir": "${ZOOKEEPER_DATA_DIR}",
  "crxui_port": ${CRXUI_PORT},
  "crxsr_port": ${CRXSR_PORT}
}
JSON_END

echo "✓ Манифест создан"
