#!/bin/bash
set -e

OUTPUT_DIR="${1:-${RUNNER_WORKDIR}}"
mkdir -p "${OUTPUT_DIR}/group_vars"

cat > "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'
# ============================================================================
# Corax Cluster Configuration
# Сгенерировано автоматически GitLab CI/CD Pipeline
# ============================================================================

# Временные директории
tmp_dir: /tmp/installer

# Параметры запуска
wait_for_start: 20
customJavaPath: false

# Настройки безопасности
security: PLAINTEXT__ZK_PLAIN_NO_AUTH__KAFKA_PLAINTEXT_NO_AUTH

# Пользователи и группы
kafka_user: kafka
kafka_group: kafka
zookeeper_user: kafka
zookeeper_group: kafka

# Настройки сервисов
enabled_service: true

# ============================================================================
# Kafka Configuration
# ============================================================================
kafka:
  distr: distrib.zip
YAML_END

# Добавляем переменные окружения через echo
echo "  installdir: ${KAFKA_INSTALL_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"
echo "  logdir: ${KAFKA_INSTALL_DIR}/logs" >> "${OUTPUT_DIR}/group_vars/all.yaml"
echo "  datadir: ${KAFKA_DATA_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

cat >> "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'
  cleanLog: false
  cleanData: false

# ============================================================================
# Zookeeper Configuration
# ============================================================================
zookeeper:
  distr: distrib.zip
YAML_END

echo "  installdir: ${KAFKA_INSTALL_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"
echo "  logdir: ${KAFKA_INSTALL_DIR}/logs" >> "${OUTPUT_DIR}/group_vars/all.yaml"
echo "  datadir: ${ZOOKEEPER_DATA_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

cat >> "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'
  cleanLog: false
  cleanData: false

# ============================================================================
# Corax Schema Registry Configuration
# ============================================================================
crxsr:
  distr: distrib.zip
YAML_END

echo "  installdir: ${KAFKA_INSTALL_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

cat >> "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'
  cleanLog: false
  prop_var:
YAML_END

echo "    \"server_port\": ${CRXSR_PORT}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

cat >> "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'

# ============================================================================
# Corax UI Configuration
# ============================================================================
crxui:
  distr: distrib.zip
YAML_END

echo "  installdir: ${KAFKA_INSTALL_DIR}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

cat >> "${OUTPUT_DIR}/group_vars/all.yaml" << 'YAML_END'
  cleanLog: false
  cleanData: false
YAML_END

echo "  server.port: ${CRXUI_PORT}" >> "${OUTPUT_DIR}/group_vars/all.yaml"

echo "✓ Файл group_vars/all.yaml сгенерирован"
