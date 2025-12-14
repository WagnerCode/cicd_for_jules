#!/bin/bash
# ============================================================================
# Скрипт подготовки конфигурации в зависимости от режима безопасности
# ============================================================================

set -e

echo "=========================================="
echo "ПОДГОТОВКА КОНФИГУРАЦИИ ПО РЕЖИМУ БЕЗОПАСНОСТИ"
echo "=========================================="
echo ""

SECURITY_MODE="${CLUSTER_SECURITY_MODE:-plaintext}"
WORK_DIR="${RUNNER_WORKDIR}"

echo "Режим безопасности: ${SECURITY_MODE}"
echo "Рабочая директория: ${WORK_DIR}"
echo ""

# Валидация режима
if [[ "${SECURITY_MODE}" != "plaintext" && "${SECURITY_MODE}" != "ssl" ]]; then
    echo "❌ ERROR: Неверный режим безопасности '${SECURITY_MODE}'"
    echo "Доступные режимы: plaintext, ssl"
    exit 1
fi

# Создание директории для конфигурации режима безопасности
SECURITY_CONFIG_DIR="${WORK_DIR}/security_config"
mkdir -p "${SECURITY_CONFIG_DIR}"

echo "=== Копирование конфигурации для режима ${SECURITY_MODE} ==="
CONFIG_SOURCE="ci/configs/group_vars_${SECURITY_MODE}.yaml"

if [ ! -f "${CONFIG_SOURCE}" ]; then
    echo "❌ ERROR: Файл конфигурации не найден: ${CONFIG_SOURCE}"
    exit 1
fi

# Копируем выбранную конфигурацию
cp "${CONFIG_SOURCE}" "${SECURITY_CONFIG_DIR}/group_vars_security.yaml"
echo "✓ Конфигурация ${SECURITY_MODE} скопирована"
echo ""

# Если SSL режим - копируем сертификаты
if [ "${SECURITY_MODE}" == "ssl" ]; then
    echo "=== Копирование SSL сертификатов ==="

    CERT_DIR="ci/configs/certificates"
    SSL_DIR="${SECURITY_CONFIG_DIR}/ssl"
    mkdir -p "${SSL_DIR}"

    # Проверка наличия сертификатов
    if [ ! -f "${CERT_DIR}/kafka.keystore.jks" ]; then
        echo "❌ ERROR: Не найден kafka.keystore.jks"
        exit 1
    fi

    if [ ! -f "${CERT_DIR}/kafka.truststore.jks" ]; then
        echo "❌ ERROR: Не найден kafka.truststore.jks"
        exit 1
    fi

    # Копируем сертификаты
    cp "${CERT_DIR}/kafka.keystore.jks" "${SSL_DIR}/"
    cp "${CERT_DIR}/kafka.truststore.jks" "${SSL_DIR}/"

    echo "✓ SSL сертификаты скопированы в ${SSL_DIR}/"
    echo ""

    # Создание README для сертификатов
    cat > "${SSL_DIR}/README.txt" << 'EOF'
SSL Certificates for Corax Cluster

These certificates will be deployed to: /pub/opt/Apache/kafka/ssl/

Files:
- kafka.keystore.jks: Private key and certificate
- kafka.truststore.jks: Trusted CA certificates

Passwords are configured in ci/variables.yml:
- SSL_KEYSTORE_PASSWORD
- SSL_TRUSTSTORE_PASSWORD
- SSL_KEY_PASSWORD

IMPORTANT: In production, use GitLab CI/CD Variables with "Masked" type
to securely store passwords!
EOF

    echo "✓ Создан README.txt для сертификатов"
    echo ""
fi

# Создание манифеста конфигурации безопасности
echo "=== Создание манифеста конфигурации безопасности ==="
cat > "${SECURITY_CONFIG_DIR}/security_manifest.txt" << EOF
========================================
КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ КЛАСТЕРА
========================================

Режим безопасности: ${SECURITY_MODE}
Дата генерации: $(date '+%Y-%m-%d %H:%M:%S')
Pipeline ID: ${CI_PIPELINE_ID:-N/A}
Пользователь: ${GITLAB_USER_LOGIN:-N/A}

Параметры:
- Конфигурация: ${CONFIG_SOURCE}
- Режим: ${SECURITY_MODE^^}

EOF

if [ "${SECURITY_MODE}" == "ssl" ]; then
    cat >> "${SECURITY_CONFIG_DIR}/security_manifest.txt" << EOF
SSL Параметры:
- Сертификаты: включены
- KeyStore: kafka.keystore.jks
- TrustStore: kafka.truststore.jks
- Путь на целевых нодах: /pub/opt/Apache/kafka/ssl/
- Протокол: SSL/TLS
- ZooKeeper: mTLS с аутентификацией
- wait_for_start: 120 секунд

ВАЖНО: Убедитесь, что пароли сертификатов надежно хранятся
в GitLab CI/CD Variables с типом "Masked"!

EOF
else
    cat >> "${SECURITY_CONFIG_DIR}/security_manifest.txt" << EOF
PLAINTEXT Параметры:
- Шифрование: отключено
- Протокол: PLAINTEXT
- ZooKeeper: без аутентификации
- wait_for_start: 20 секунд

⚠️  ВНИМАНИЕ: Этот режим не использует шифрование!
Подходит только для dev/test окружений.

EOF
fi

cat >> "${SECURITY_CONFIG_DIR}/security_manifest.txt" << EOF
========================================
Файлы конфигурации:
EOF

ls -lh "${SECURITY_CONFIG_DIR}" >> "${SECURITY_CONFIG_DIR}/security_manifest.txt"

echo "✓ Манифест создан: ${SECURITY_CONFIG_DIR}/security_manifest.txt"
echo ""

# Вывод манифеста
cat "${SECURITY_CONFIG_DIR}/security_manifest.txt"

echo ""
echo "=========================================="
echo "✅ КОНФИГУРАЦИЯ ПОДГОТОВЛЕНА"
echo "=========================================="
echo ""
echo "Режим: ${SECURITY_MODE}"
echo "Директория: ${SECURITY_CONFIG_DIR}"
if [ "${SECURITY_MODE}" == "ssl" ]; then
    echo "Сертификаты: готовы к развертыванию"
fi
echo ""

exit 0
