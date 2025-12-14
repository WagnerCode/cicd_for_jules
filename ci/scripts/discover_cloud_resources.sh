#!/bin/bash
#########################################################################################
# Скрипт автоматического обнаружения Cloud.ru ресурсов
#########################################################################################

# Функция получения токена
get_token() {
    local keyid=$1
    local secret=$2
    
    token=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token' \
        --header 'Content-Type: application/json' \
        --data "{\"keyId\": \"${keyid}\", \"secret\": \"${secret}\"}" 2>&1)
    
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
        echo "[ERROR] Не удалось получить токен: $token"
        return 1
    fi
    
    echo "$token" | jq -r '.access_token'
}

# Функция получения списка Magic Routers в проекте
get_magic_routers() {
    local project_id=$1
    local token=$2
    
    curl -sSL --fail-with-body \
        --location "https://magic-router.api.cloud.ru/v1/magicRouters?projectId=${project_id}" \
        --header "Authorization: Bearer $token" 2>&1
}

# Функция получения VPC ID
get_vpcs() {
    local project_id=$1
    local token=$2
    
    curl -sSL --fail-with-body \
        --location "https://vpc.api.cloud.ru/v1/vpcs?projectId=${project_id}" \
        --header "Authorization: Bearer $token" 2>&1
}

# Функция получения VPC connections для Magic Router
get_vpc_connections() {
    local magic_router_id=$1
    local token=$2
    
    curl -sSL --fail-with-body \
        --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id}/connections/vpc" \
        --header "Authorization: Bearer $token" 2>&1
}

# Функция получения Magic Router connections
get_magic_router_connections() {
    local magic_router_id=$1
    local token=$2
    
    curl -sSL --fail-with-body \
        --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id}/connections/magicRouter" \
        --header "Authorization: Bearer $token" 2>&1
}

#########################################################################################
# ОСНОВНАЯ ЛОГИКА
#########################################################################################

# Проверяем обязательные переменные

project_id_paas=$CLOUDRU_PROJECT_ID
keyid_paas=$CLOUDRU_KEY_ID
secret_paas=$CLOUDRU_SECRET

if [ -z "$keyid_paas" ] || [ -z "$secret_paas" ]; then
    echo "[ERROR] Не заданы keyid_paas или secret_paas"
    exit 1
fi

# Получаем токены для всех проектов
echo "[INFO] Получение токенов аутентификации..."
TOKEN_PAAS=$(get_token "$keyid_paas" "$secret_paas")
TOKEN_INFRA=$(get_token "$keyid_infra" "$secret_infra")

TOKEN_GIS=""
# Проверяем, что заданы ВСЕ три необходимые переменные для GIS
if [ -n "$project_id_gis" ] && [ -n "$key_id_gis" ] && [ -n "$secret_gis" ]; then
    echo "[INFO] Обнаружены переменные для GIS. Получаем токен..."
    TOKEN_GIS=$(get_token "$key_id_gis" "$secret_gis")
    
    if [ -z "$TOKEN_GIS" ]; then
        echo "[WARNING] Переменные GIS заданы, но токен получить не удалось. Пропускаем GIS."
    else
        echo "[OK] Токен GIS получен успешно."
    fi
else
    echo "[INFO] Переменные GIS (ProjectID/Key/Secret) не заданы или не полные. Пропуск настройки GIS."
fi


echo "================================================================="
echo "[INFO] === Обработка проекта PaaS: $project_id_paas ==="

echo "[INFO] Поиск VPC с именем 'Default' в проекте PaaS..."
vpcs_paas=$(get_vpcs "$project_id_paas" "$TOKEN_PAAS")
# ИЩЕМ VPC ИМЕННО С ИМЕНЕМ "Default"
vpc_id_paas=$(echo "$vpcs_paas" | jq -r '.vpcs[] | select(.name == "Default") | .id // empty')

if [ -z "$vpc_id_paas" ]; then
    echo "[ERROR] В проекте PaaS НЕ НАЙДЕН VPC с именем 'Default'. Прерывание."
    exit 1
else
    echo "[OK] Найден VPC 'Default' в проекте PaaS. ID: $vpc_id_paas"
fi

echo "[INFO] Поиск Magic Router в проекте PaaS..."
magic_routers_paas=$(get_magic_routers "$project_id_paas" "$TOKEN_PAAS")
# Предполагаем, что в проекте один Magic Router, берем первый. Можно усложнить, если их несколько.
magic_router_id_paas=$(echo "$magic_routers_paas" | jq -r '.magicRouters[0].id // empty')

if [ -z "$magic_router_id_paas" ]; then
    echo "[ERROR] В проекте PaaS не найден Magic Router. Прерывание."
    exit 1
else
    echo "[OK] Найден Magic Router PaaS. ID: $magic_router_id_paas"
    
    echo "[INFO] Поиск VPC Connection для VPC 'Default'..."
    vpc_conns_paas=$(get_vpc_connections "$magic_router_id_paas" "$TOKEN_PAAS")
    
    # ИЩЕМ VPC CONNECTION, СВЯЗАННЫЙ С НАШИМ 'Default' VPC ID
    # Мы передаем ID нашего VPC в jq и фильтруем по полю 'vpcId'
    vpcConnectionId_paas=$(echo "$vpc_conns_paas" | jq -r --arg default_vpc_id "$vpc_id_paas" '.vpcConnections[] | select(.vpcId == $default_vpc_id) | .id // empty')
    
    if [ -z "$vpcConnectionId_paas" ]; then
        echo "[ERROR] В Magic Router не найдена связь (VPC Connection) с VPC 'Default' (ID: $vpc_id_paas). Прерывание."
        exit 1
    else
        echo "[OK] Найден VPC Connection ID для VPC 'Default': $vpcConnectionId_paas"
    fi
fi


# Повторяем для INFRA

echo "================================================================="
echo "[INFO] === Обработка проекта INFRA: $project_id_infra ==="

echo "[INFO] Поиск VPC с именем 'Default' в проекте INFRA..."
vpcs_infra=$(get_vpcs "$project_id_infra" "$TOKEN_INFRA")
# ИЩЕМ VPC ИМЕННО С ИМЕНЕМ "Default"
vpc_id_infra=$(echo "$vpcs_infra" | jq -r '.vpcs[] | select(.name == "Default") | .id // empty')

if [ -z "$vpc_id_infra" ]; then
    echo "[ERROR] В проекте PaaS НЕ НАЙДЕН VPC с именем 'Default'. Прерывание."
    exit 1
else
    echo "[OK] Найден VPC 'Default' в проекте PaaS. ID: $vpc_id_infra"
fi


echo "[INFO] Поиск Magic Router в проекте INFRA..."
magic_routers_infra=$(get_magic_routers "$project_id_infra" "$TOKEN_INFRA")
magic_router_id_infra=$(echo "$magic_routers_infra" | jq -r '.magicRouters[0].id // empty')

if [ -z "$magic_router_id_infra" ]; then
    echo "[ERROR] В проекте INFRA не найден Magic Router. Прерывание."
    exit 1
else
    echo "[OK] Найден Magic Router INFRA. ID: $magic_router_id_infra"
    
    echo "[INFO] Поиск VPC Connection для VPC 'Default'..."
    vpc_conns_infra=$(get_vpc_connections "$magic_router_id_infra" "$TOKEN_INFRA")
    
    # ИЩЕМ VPC CONNECTION, СВЯЗАННЫЙ С НАШИМ 'Default' VPC ID
    # Мы передаем ID нашего VPC в jq и фильтруем по полю 'vpcId'
    vpcConnectionId_infra=$(echo "$vpc_conns_infra" | jq -r --arg default_vpc_id "$vpc_id_infra" '.vpcConnections[] | select(.vpcId == $default_vpc_id) | .id // empty')
    
    if [ -z "$vpcConnectionId_infra" ]; then
        echo "[ERROR] В Magic Router не найдена связь (VPC Connection) с VPC 'Default' (ID: $vpc_id_infra). Прерывание."
        exit 1
    else
        echo "[OK] Найден VPC Connection ID для VPC 'Default': $vpcConnectionId_infra"
    fi
fi


# Повторяем для GIS
if [ -n "$project_id_gis" ] && [ -n "$key_id_gis" ] && [ -n "$secret_gis" ]; then
    vpcs_gis=$(get_vpcs "$project_id_gis" "$TOKEN_GIS")
    # ИЩЕМ VPC ИМЕННО С ИМЕНЕМ "Default"
    vpc_id_gis=$(echo "$vpcs_gis" | jq -r '.vpcs[] | select(.name == "Default") | .id // empty')

    if [ -z "$vpc_id_gis" ]; then
        echo "[ERROR] В проекте GIS НЕ НАЙДЕН VPC с именем 'Default'. Прерывание."
        exit 1
    else
        echo "[OK] Найден VPC 'Default' в проекте PaaS. ID: $vpc_id_gis"
    fi


    echo "[INFO] Поиск Magic Router в проекте GIS..."
    magic_routers_gis=$(get_magic_routers "$project_id_gis" "$TOKEN_GIS")
    magic_router_id_gis=$(echo "$magic_routers_gis" | jq -r '.magicRouters[0].id // empty')




    if [ -z "$magic_router_id_gis" ]; then
        echo "[ERROR] В проекте INFRA не найден Magic Router. Прерывание."
        exit 1
    else
        echo "[OK] Найден Magic Router INFRA. ID: $magic_router_id_gis"
        
        echo "[INFO] Поиск VPC Connection для VPC 'Default'..."
        vpc_conns_gis=$(get_vpc_connections "$magic_router_id_gis" "$TOKEN_GIS")
        
        # ИЩЕМ VPC CONNECTION, СВЯЗАННЫЙ С НАШИМ 'Default' VPC ID
        # Мы передаем ID нашего VPC в jq и фильтруем по полю 'vpcId'
        vpcConnectionId_gis=$(echo "$vpc_conns_gis" | jq -r --arg default_vpc_id "$vpc_id_gis" '.vpcConnections[] | select(.vpcId == $default_vpc_id) | .id // empty')
        
        if [ -z "$vpcConnectionId_gis" ]; then
            echo "[ERROR] В Magic Router не найдена связь (VPC Connection) с VPC 'Default' (ID: $vpc_id_gis). Прерывание."
            exit 1
        else
            echo "[OK] Найден VPC Connection ID для VPC 'Default': $vpcConnectionId_gis"
        fi
    fi
fi


mr_conns_PAAS=$(get_magic_router_connections "$magic_router_id_paas" "$TOKEN_PAAS")

echo "[DEBUG] Raw JSON from PAAS connections:"
# echo $mr_conns_PAAS # Раскомментируйте для отладки

# ИСПРАВЛЕНИЕ 1: В JSON массив называется .magicRouterConnections, а не .connections
# ИСПРАВЛЕНИЕ 2: Фильтруем по .targetMrId (ID роутера назначения), сравнивая его с ID роутера Инфры
magicRouterConnectionId_paas_to_infra=$(echo "$mr_conns_PAAS" | jq -r --arg target "$magic_router_id_infra" '.magicRouterConnections[] | select(.targetMrId == $target) | .id // empty')

# Инициализируем переменную для ГИС пустым значением
magicRouterConnectionId_paas_to_gis=""

echo "[INFO] Connection PAAS -> INFRA ID: $magicRouterConnectionId_paas_to_infra"


# 2. Получаем список соединений для INFRA
mr_conns_INFRA=$(get_magic_router_connections "$magic_router_id_infra" "$TOKEN_INFRA")

# Ищем линк в сторону PAAS.
# Логика: В списке соединений Инфры ищем запись, где targetMrId == ID Роутера PAAS
magicRouterConnectionId_infra_to_paas=$(echo "$mr_conns_INFRA" | jq -r --arg target "$magic_router_id_paas" '.magicRouterConnections[] | select(.targetMrId == $target) | .id // empty')

echo "[INFO] Connection INFRA -> PAAS ID: $magicRouterConnectionId_infra_to_paas"


# 3. Блок для GIS (выполняется только если есть переменные)
if [ -n "$project_id_gis" ] && [ -n "$key_id_gis" ] && [ -n "$secret_gis" ] && [ -n "$TOKEN_GIS" ]; then
    
    # Ищем линк от PAAS к GIS (используем уже скачанный JSON от PAAS)
    magicRouterConnectionId_paas_to_gis=$(echo "$mr_conns_PAAS" | jq -r --arg target "$magic_router_id_gis" '.magicRouterConnections[] | select(.targetMrId == $target) | .id // empty')
    
    # Получаем соединения GIS
    mr_conns_GIS=$(get_magic_router_connections "$magic_router_id_gis" "$TOKEN_GIS")
    
    # Ищем линк от GIS к PAAS
    # Исправил опечатку в переменной MAGIC_ROUTER_ID__PAAS (было два подчеркивания)
    magicRouterConnectionId_gis_to_paas=$(echo "$mr_conns_GIS" | jq -r --arg target "$magic_router_id_paas" '.magicRouterConnections[] | select(.targetMrId == $target) | .id // empty')

    echo "[INFO] Connection PAAS -> GIS ID: $magicRouterConnectionId_paas_to_gis"
    echo "[INFO] Connection GIS -> PAAS ID: $magicRouterConnectionId_gis_to_paas"
fi

#########################################################################################
# ЭКСПОРТ ПЕРЕМЕННЫХ для использования в других скриптах пайплайна
#########################################################################################

# Сохраняем в файл, который будет источником для следующих job'ов
cat > cloud_resources.env << EOF
export magic_router_id_paas="$magic_router_id_paas"
export magic_router_id_infra="$magic_router_id_infra"
export magic_router_id_gis="$magic_router_id_gis"

export vpcConnectionId_paas="$vpcConnectionId_paas"
export vpcConnectionId_infra="$vpcConnectionId_infra"
export vpcConnectionId_gis="$vpcConnectionId_gis"

export vpc_id_paas="$vpc_id_paas"
export vpc_id_infra="$vpc_id_infra"
export vpc_id_gis="$vpc_id_gis"

export magicRouterConnectionId_infra_to_paas="$magicRouterConnectionId_infra_to_paas"
export magicRouterConnectionId_paas_to_infra="$magicRouterConnectionId_paas_to_infra"
                                            

export magicRouterConnectionId_paas_to_gis="$magicRouterConnectionId_paas_to_gis"
export magicRouterConnectionId_gis_to_paas="$magicRouterConnectionId_gis_to_paas"
EOF

echo "[SUCCESS] Ресурсы обнаружены и сохранены в cloud_resources.env"
cat cloud_resources.env
