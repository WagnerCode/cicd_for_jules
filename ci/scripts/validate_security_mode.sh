#!/bin/bash
# ============================================================================
# Скрипт валидации режима безопасности кластера
# ============================================================================

set -e

MODE="${CLUSTER_SECURITY_MODE:-plaintext}"

echo "=========================================="
echo "ВАЛИДАЦИЯ РЕЖИМА БЕЗОПАСНОСТИ"
echo "=========================================="
echo ""
echo "Выбранный режим: ${MODE}"
echo ""

# Проверка что режим входит в список валидных
if [[ "${MODE}" != "plaintext" && "${MODE}" != "ssl" ]]; then
    echo "❌ ERROR: Неверный режим безопасности '${MODE}'"
    echo ""
    echo "Доступные режимы:"
    echo "  - plaintext: Без шифрования (для dev/test окружений)"
    echo "  - ssl: С полным шифрованием и сертификатами (для production)"
    echo ""
    exit 1
fi

echo "✓ Режим безопасности валиден"
echo ""

# Проверка наличия файла конфигурации
CONFIG_FILE="ci/configs/group_vars_${MODE}.yaml"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ ERROR: Файл конфигурации не найден: ${CONFIG_FILE}"
    echo ""
    echo "Убедитесь, что файл существует в репозитории"
    exit 1
fi

echo "✓ Файл конфигурации найден: ${CONFIG_FILE}"
echo ""

# Если SSL режим - проверяем наличие сертификатов
if [ "${MODE}" == "ssl" ]; then
    echo "=== Проверка SSL сертификатов ==="

    CERT_DIR="ci/configs/certificates"

    if [ ! -f "${CERT_DIR}/kafka.keystore.jks" ]; then
        echo "❌ ERROR: Отсутствует файл ${CERT_DIR}/kafka.keystore.jks"
        echo ""
        echo "Для SSL режима необходимы сертификаты!"
        echo "Поместите файлы kafka.keystore.jks и kafka.truststore.jks в директорию ${CERT_DIR}/"
        exit 1
    fi

    if [ ! -f "${CERT_DIR}/kafka.truststore.jks" ]; then
        echo "❌ ERROR: Отсутствует файл ${CERT_DIR}/kafka.truststore.jks"
        echo ""
        echo "Для SSL режима необходимы сертификаты!"
        echo "Поместите файлы kafka.keystore.jks и kafka.truststore.jks в директорию ${CERT_DIR}/"
        exit 1
    fi

    # Проверка что файлы не являются заглушками
    KEYSTORE_SIZE=$(stat -c%s "${CERT_DIR}/kafka.keystore.jks" 2>/dev/null || stat -f%z "${CERT_DIR}/kafka.keystore.jks" 2>/dev/null || echo "0")
    TRUSTSTORE_SIZE=$(stat -c%s "${CERT_DIR}/kafka.truststore.jks" 2>/dev/null || stat -f%z "${CERT_DIR}/kafka.truststore.jks" 2>/dev/null || echo "0")

    if [ "${KEYSTORE_SIZE}" -lt "100" ]; then
        echo "⚠️  WARNING: Файл kafka.keystore.jks слишком мал (${KEYSTORE_SIZE} bytes)"
        echo "Возможно, это заглушка. Убедитесь, что используете реальный JKS файл!"
        echo ""
    fi

    if [ "${TRUSTSTORE_SIZE}" -lt "100" ]; then
        echo "⚠️  WARNING: Файл kafka.truststore.jks слишком мал (${TRUSTSTORE_SIZE} bytes)"
        echo "Возможно, это заглушка. Убедитесь, что используете реальный JKS файл!"
        echo ""
    fi

    echo "✓ SSL сертификаты найдены"
    echo "  - kafka.keystore.jks (${KEYSTORE_SIZE} bytes)"
    echo "  - kafka.truststore.jks (${TRUSTSTORE_SIZE} bytes)"
    echo ""
fi

# Вывод описания выбранного режима
echo "--- Описание режима '${MODE}' ---"
case "${MODE}" in
    plaintext)
        echo "Режим без шифрования"
        echo "- Протокол: PLAINTEXT"
        echo "- ZooKeeper: Без аутентификации"
        echo "- Kafka: Без шифрования и аутентификации"
        echo "- Назначение: Dev/Test окружения"
        echo "- wait_for_start: 20 секунд"
        ;;
    ssl)
        echo "Режим с полным шифрованием"
        echo "- Протокол: SSL/TLS"
        echo "- ZooKeeper: mTLS с аутентификацией"
        echo "- Kafka: SSL с аутентификацией"
        echo "- Сертификаты: Требуются JKS файлы"
        echo "- Назначение: Production окружения"
        echo "- wait_for_start: 120 секунд (увеличено для SSL)"
        ;;
esac
echo ""

echo "=========================================="
echo "✅ ВАЛИДАЦИЯ УСПЕШНО ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "Будет использован режим: ${MODE}"
echo "Конфигурация: ${CONFIG_FILE}"
echo ""

exit 0
