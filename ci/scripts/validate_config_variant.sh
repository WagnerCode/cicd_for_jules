#!/bin/bash
# ============================================================================
# Скрипт валидации варианта конфигурации кластера
# ============================================================================

set -e

VARIANT="${CLUSTER_CONFIG_VARIANT:-standard}"
VALID_VARIANTS="standard alternative custom"

echo "=========================================="
echo "ВАЛИДАЦИЯ ВАРИАНТА КОНФИГУРАЦИИ"
echo "=========================================="
echo ""
echo "Выбранный вариант: ${VARIANT}"
echo ""

# Проверка что вариант входит в список валидных
if [[ ! " ${VALID_VARIANTS} " =~ " ${VARIANT} " ]]; then
    echo "❌ ERROR: Неверный вариант конфигурации '${VARIANT}'"
    echo ""
    echo "Доступные варианты:"
    echo "  - standard: Стандартная конфигурация для production"
    echo "  - alternative: Альтернативная конфигурация с увеличенными таймаутами"
    echo "  - custom: Кастомная конфигурация для отладки"
    echo ""
    exit 1
fi

echo "✓ Вариант конфигурации валиден"
echo ""

# Проверка наличия файла конфигурации
CONFIG_FILE="files/group_vars_all_${VARIANT}.j2"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ ERROR: Файл конфигурации не найден: ${CONFIG_FILE}"
    echo ""
    echo "Убедитесь, что файл существует в репозитории"
    exit 1
fi

echo "✓ Файл конфигурации найден: ${CONFIG_FILE}"
echo ""

# Вывод размера файла
FILE_SIZE=$(stat -c%s "${CONFIG_FILE}" 2>/dev/null || stat -f%z "${CONFIG_FILE}" 2>/dev/null || echo "unknown")
echo "Размер файла: ${FILE_SIZE} bytes"
echo ""

# Вывод описания выбранного варианта
echo "--- Описание варианта '${VARIANT}' ---"
case "${VARIANT}" in
    standard)
        echo "Стандартная конфигурация для production окружения"
        echo "- wait_for_start: 20 секунд"
        echo "- cleanLog: false, cleanData: false"
        echo "- Стабильные настройки для надежной работы"
        ;;
    alternative)
        echo "Альтернативная конфигурация для тестового окружения"
        echo "- wait_for_start: 30 секунд (увеличено)"
        echo "- cleanLog: false, cleanData: true (для zookeeper)"
        echo "- Подходит для тестирования с очисткой данных"
        ;;
    custom)
        echo "Кастомная конфигурация для отладки и разработки"
        echo "- wait_for_start: 60 секунд (максимум)"
        echo "- cleanLog: true, cleanData: true (для всех компонентов)"
        echo "- Кастомные пути для логов и данных"
        echo "- Полная очистка при каждой установке"
        ;;
esac
echo ""

echo "=========================================="
echo "✅ ВАЛИДАЦИЯ УСПЕШНО ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "Будет использован файл: ${CONFIG_FILE}"
echo ""

exit 0
