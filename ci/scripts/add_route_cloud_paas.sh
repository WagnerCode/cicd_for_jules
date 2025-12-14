#!/bin/bash

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

























#########################################################################################################################################################
## Скрипты развертывания Pangolin в Cloud
# Скрипт для прописывания маршрутов в Magic Router и VPC для обеспечения связности между 3мя проектами - проверяется существование/создается 14 маршрутов
# PaaS - создающиеся ВМ Pangolin
# GIS - пользовательские ВМ, с которых будет происходить работа с Pangolin
# Infra - тут находится gitlab-runner с которого производится развертывание кластера Pangolin и Jump-hostы для управления кластером Pangolin
##########################################################################################################################################################
# Выставляем переменные - часть из них должна быть вытащена из конфига предыдущего этапа
keyid_paas=$CLOUDRU_KEY_ID # ключ сервисного аккаунта для доступа в проект PaaS (права на создание/удаление ВМ, групп безопасности, подсетей)
secret_paas=$CLOUDRU_SECRET # секрет сервисного аккаунта для доступа в проект PaaS (права на создание/удаление ВМ, групп безопасности, подсетей)
#key_id_gis="xxx" # ключ сервисного аккаунта для доступа в проект GIS (административные права на magic router, vpc)
#secret_gis="xxx" # секрет сервисного аккаунта для доступа в проект GIS (административные права на magic router, vpc)
#keyid_infra="xxx" # ключ сервисного аккаунта для доступа в проект INFRA (административные права на magic router, vpc)
#secret_infra="xxx" секрет сервисного аккаунта для доступа в проект INFRA (административные права на magic router, vpc)
$project_id_paas=$CLOUDRU_PROJECT_ID # id проекта PaaS
#project_id_runner="e579b668-e24d-4b99-b04c-41db78f1b780" # id проекта INFRA
#project_id_infra="e579b668-e24d-4b99-b04c-41db78f1b780" # id проекта INFRA
#project_id_gis="e5a9803e-d1bd-4989-804c-651e3bbdcf06" # id проекта GIS
# runner и jumphost находятся в одном и том же проекте
#magic_router_id_paas="6d0a709a-771d-42de-ada8-db2db099f05e" # id magic router PaaS
#magic_router_id_infra="b9a8a0c1-2ae0-414f-b9f5-d78d921e8013" # id magic router Infra
#magic_router_id_gis="0fa255f0-1679-4392-bdae-0de5d33b5431" # id magic router GIS
#vpcConnectionId_paas="0a33b05d-c98f-446e-82f8-6ee6ca2cd0ed" # id ссылки на собственную VPC в magic router PaaS
#vpcConnectionId_infra="92a6d825-885c-4769-aa94-239ae9a151a8" # id ссылки на собственную VPC в magic router Infra
#vpcConnectionId_gis="68302a5e-6594-4141-9699-d9c459dd6675" # id ссылки на собственную VPC в magic router GIS
#vpc_id_paas="52a7f145-8c13-44d9-ba19-cecc4c244d44" # id VPC в проекте PaaS
#vpc_id_infra="efabf9d4-e387-43cb-b548-b05647c6c63c" # id VPC в проекте Infra
#vpc_id_gis="37664457-a42a-47d0-ae2b-a23145ff47b3" # id VPC в проекте PaaS
#magicRouterConnectionId_infra_to_paas="68cbef0e-ad4f-4416-b320-38d3a6e51ef4" # id Magic Link от Infra в сторону PaaS
#magicRouterConnectionId_gis_to_paas="43edbe65-a144-47ca-a25e-7719e63a3756" # id Magic Link от GIS в сторону PaaS
#magicRouterConnectionId_paas_to_gis="5e63d503-bf5b-44a5-b32d-5c1f6fffd14b" # id Magic Link от PaaS в сторону GIS
#magicRouterConnectionId_paas_to_infra="17c0a3d9-6eba-4890-9cf6-ed8f83438535" # id Magic Link от PaaS в сторону Infra
azName_paas="ru.AZ-1" # Зона доступности PaaS при настройке маршрутов
azName_gis="ru.AZ-1" # Зона доступности GIS при настройке маршрутов
azName_infra="ru.AZ-1" # Зона доступности Infra при настройке маршрутов
PROJECT_NAME=$GIS_PROJECT_NAME
CLUSTER_NUMBER=$CLUSTER_NUMBER
# вытаскиваем подсети из переменных окружения
subnet_paas=$CLUSTER_SUBNET
subnet_gis=$USERS_SUBNET
subnet_runner=$INFRA_SUBNET_GITLAB
subnet_jumphost=$INFRA_SUBNET_JUMPHOST
# описания маршрутов
description_mr_paas="L3 Route to subnet $subnet_paas for $PROJECT_NAME on PAAS MR to PAAS - corax"
description_vpc_infra="L3 Route to subnet $subnet_paas for $PROJECT_NAME on INFRA VPC to infra MR - corax"
description_vpc_gis="L3 Route to subnet $subnet_paas for $PROJECT_NAME on GIS VPC to GIS MR - corax"
description_mr_infra="L3 Route to subnet $subnet_paas for $PROJECT_NAME on INFRA MR to PAAS MR - corax"
description_mr_gis2paas="L3 Route to subnet $subnet_paas for $PROJECT_NAME on GIS MR to PAAS MR - corax"
description_vpc_paas_gis="L3 Route to subnet $subnet_gis for $PROJECT_NAME on PAAS VPC to PAAS MR - corax"
description_vpc_paas_jump="L3 Route to subnet $subnet_jumphost for $PROJECT_NAME on PAAS VPC to PAAS MR - corax"
description_mr_paas_jump="L3 Route to subnet $subnet_jumphost for $PROJECT_NAME on PAAS MR to INFRA MR - corax"
description_mr_paas_gis="L3 Route to subnet $subnet_gis for $PROJECT_NAME on PAAS MR to INFRA MR - corax"
description_mr_paas_runner="L3 Route to subnet $subnet_runner for $PROJECT_NAME on PAAS MR to INFRA MR - corax"
description_mr_infra_runner="L3 Route to subnet $subnet_runner for $PROJECT_NAME on INFRA MR to INFRA vpc - corax"
description_mr_infra_jumphost="L3 Route to subnet $subnet_jumphost for $PROJECT_NAME on INFRA MR to INFRA VPC - corax"
description_mr_gis="L3 Route to subnet $subnet_gis for $PROJECT_NAME on GIS MR to GIS VPC - corax"

# Действия
echo "Прописываем маршруты в Cloud"
echo "Подсеть PAAS: $subnet_paas"
echo "Подсеть GIS: $subnet_gis"
echo "Подсеть runner: $subnet_runner"
echo "Подсеть Jumphost: $subnet_jumphost"

echo "================================================================="
echo "====Работаем с MR PAAS!!!===="
echo "MR routes on PAAS:"
echo "Получаем токен для доступа к MR PaaS"
token=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${keyid_paas}\", 'secret': \"${secret_paas}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request token, exitcode = $exitcode, return data = $token"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from response"
token=$(echo $token|jq -r '.access_token')
echo "Получаем список маршрутов в MR paas"
list_routes_mr_paas=$(curl -sSL --fail-with-body --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request list, exitcode = $exitcode, return data = $list_routes_mr_paas"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_paas $subnet_paas в MR PAAS"
#echo $list
#list=$(echo $list|jq \".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt\")
route_paas_mr_exists_paas=$(echo $list_routes_mr_paas|jq ".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt")
echo $route_paas_mr_exists_paas
if [ ! -z  "${route_paas_mr_exists_paas:-}" ]; then
    echo "[DEBUG] Маршрут для subnet_paas $subnet_paas уже есть, создан ${route_paas_mr_exists_paas}"
    echo "Переменная ACTION = $ACTION"
    if [ "$ACTION" = "destroy" ]; then
      echo "[DEBUG] Маршрут должен быть удален для $subnet_paas"
      route_paas_id=$(echo $list_routes_mr_paas |jq -r ".routes[] | select(.subnet == \"${subnet_paas}\") | .id")
      echo "[DEBUG] Удаляем маршрут для $subnet_paas"
      route_paas_mr_delete_paas=$(curl -sSL --fail-with-body -X DELETE --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static/${route_paas_id}" --header "Authorization: Bearer $token" 2>&1)
      exitcode_del=$?
      if [ "$exitcode_del" -ne 0 ]; then
        echo "[ERROR] running request, exitcode = $exitcode_del, return data = $route_paas_mr_delete_paas"
        exit $exitcode_del
      else
      echo "[OK], удаление маршрута для $subnet_paas успешно"
      echo "$route_paas_mr_delete_paas"
      fi
    else
      echo "Маршрут для $subnet_paas не трогаем, продолжаем"
    fi
else
  if [ ! "$ACTION" = "destroy" ]; then
    echo "[DEBUG] Маршрут не существует, но выбран ACTION НЕ destroy, нужно создать маршрут"
    echo "[DEBUG] Создаем маршрут для subnet_paas $subnet_paas в MR Paas nexthop vpc"
    route_paas_mr_create_paas=$(curl -ivk -s -f -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"vpcConnectionId\": \"${vpcConnectionId_paas}\", \"magicRouterId\": \"${magic_router_id_paas}\", \"azName\":\"${azName_paas}\", \"description\": \"${description_mr_paas}\", \"subnet\": \"${subnet_paas}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_paas_mr_create_paas"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_paas_mr_create_paas
    echo "[DEBUG] Маршрут для subnet_paas $subnet_paas в MR Paas nexthop vpc создан"
  else
    echo "Маршрут не существует, но выбран ACTION=destroy, ничего не делаем"
  fi
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_jumphost $subnet_jumphost в MR PAAS"
route_mr_paas_exists_jumphost=$(echo $list_routes_mr_paas|jq ".routes[] | select(.subnet == \"${subnet_jumphost}\") | .createdAt")
echo $route_mr_paas_exists_jumphost
if [ ! -z  "${route_mr_paas_exists_jumphost:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_paas_exists_jumphost}"
else
    echo "[DEBUG] Создаем маршрут subnet_jumphost $subnet_jumphost в MR paas nexthop mr infra"
    echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_jump}\", \"subnet\": \"${subnet_jumphost}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_infra}\"}}""
    route_mr_paas_create_jump=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_paas_jump}\", \"subnet\": \"${subnet_jumphost}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_infra}\"}}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_mr_paas_create_jump"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_paas_create_jump
    echo "[DEBUG] Маршрут в MR PAAS для subnet_jumphost $subnet_jumphost nexthop mr infra создан "
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_gis $subnet_gis в MR PAAS"
route_mr_paas_exists_gis=$(echo $list_routes_mr_paas|jq ".routes[] | select(.subnet == \"${subnet_gis}\") | .createdAt")
echo $route_mr_paas_exists_gis
if [ ! -z  "${route_mr_paas_exists_gis:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_paas_exists_gis}"
else
    echo "[DEBUG] Создаем маршрут subnet_gis $subnet_gis в MR paas nexthop mr"
    echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_paas_gis}\", \"subnet\": \"${subnet_gis}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_gis}\"}}""
    route_mr_paas_create_gis=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_paas_gis}\", \"subnet\": \"${subnet_gis}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_gis}\"}}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_mr_paas_create_gis"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_paas_create_gis
    echo "[DEBUG] Маршрут в MR PAAS для subnet_gis $subnet_gis nexthop mr создан "
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_runner $subnet_runner в MR PAAS"
route_mr_paas_exists_runner=$(echo $list_routes_mr_paas|jq ".routes[] | select(.subnet == \"${subnet_runner}\") | .createdAt")
echo $route_mr_paas_exists_runner
if [ ! -z  "${route_mr_paas_exists_runner:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_paas_exists_runner}"
else
    echo "[DEBUG] Создаем маршрут subnet_runner $subnet_runner в MR paas nexthop mr infra"
    echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_jump}\", \"subnet\": \"${subnet_runner}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_infra}\"}}""
    route_mr_paas_create_runner=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_paas}/routes/static" --header "Authorization: Bearer $token" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_paas}\", \"description\": \"${description_mr_paas_runner}\", \"subnet\": \"${subnet_runner}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_paas_to_infra}\"}}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_mr_paas_create_runner"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_paas_create_runner
    echo "[DEBUG] Маршрут в MR PAAS для subnet_runner $subnet_runner nexthop mr infra создан "
fi
echo "================================================================="
echo "====Работаем с VPC PAAS!!!===="
echo "VPC routes on PAAS:"
echo "Получаем токен для доступа к VPC PAAS"
token_paas=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${keyid_paas}\", 'secret': \"${secret_paas}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $token_paas"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from response"
token_paas=$(echo $token_paas|jq -r '.access_token')
echo "Получаем список маршрутов в VPC PAAS"
list_routes_vpc_paas=$(curl -sSL --fail-with-body --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $list_routes_vpc_paas"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_gis $subnet_gis в VPC paas"
route_vpc_paas_exists_gis=$(echo $list_routes_vpc_paas|jq ".routes[] | select(.subnet == \"${subnet_gis}\") | .createdAt")
echo $route_vpc_paas_exists_gis
if [ ! -z  "${route_vpc_paas_exists_gis:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_vpc_paas_exists_gis}"
else
    echo "[DEBUG] Создаем маршрут в VPC paas"
    route_vpc_paas_create_gis=$(curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_paas}\", \"projectId\": \"${project_id_paas}\",  \"subnet\": \"${subnet_gis}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_paas}\"}, \"azName\": \"${azName_paas}\"}},  \"description\": \"${description_vpc_paas_gis}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_paas_create_gis"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    #echo $route_paas_create
    echo "[DEBUG] Маршрут в VPC PAAS создан "
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_jumphost $subnet_jumphost в VPC paas"
route_vpc_paas_exists_jump=$(echo $list_routes_vpc_paas|jq ".routes[] | select(.subnet == \"${subnet_jumphost}\") | .createdAt")
echo $route_vpc_paas_exists_jump
if [ ! -z  "${route_vpc_paas_exists_jump:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_vpc_paas_exists_jump}"
else
    echo "[DEBUG] Создаем маршрут в VPC paas"
    #echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_paas}\", \"projectId\": \"${project_id_paas}\",  \"subnet\": \"${subnet_jumphost}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_paas}\"}, \"azName\": \"${azName_paas}\"}},  \"description\": \"${description_vpc_paas_jump}\"}" "
    route_vpc_paas_create_jump=$(curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_paas}\", \"projectId\": \"${project_id_paas}\",  \"subnet\": \"${subnet_jumphost}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_paas}\"}, \"azName\": \"${azName_paas}\"}},  \"description\": \"${description_vpc_paas_jump}\"}" 2>&1)
    exitcode=$?
    #echo $route_vpc_paas_create_jump
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_paas_create_jump"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    #echo $route_paas_create
    echo "[DEBUG] Маршрут в VPC PAAS создан "
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_runner $subnet_runner в VPC paas"
route_vpc_paas_exists_runner=$(echo $list_routes_vpc_paas|jq ".routes[] | select(.subnet == \"${subnet_runner}\") | .createdAt")
echo $route_vpc_paas_exists_runner
if [ ! -z  "${route_vpc_paas_exists_runner:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_vpc_paas_exists_runner}"
else
    echo "[DEBUG] Создаем маршрут в VPC paas"
    #echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_paas}\", \"projectId\": \"${project_id_paas}\",  \"subnet\": \"${subnet_runner}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_paas}\"}, \"azName\": \"ru.AZ-1\"}},  \"description\": \"${description_vpc_paas_jump}\"}" "
    route_vpc_paas_create_jump=$(curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_paas}/routes/static" --header "Authorization: Bearer $token_paas" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_paas}\", \"projectId\": \"${project_id_paas}\",  \"subnet\": \"${subnet_runner}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_paas}\"}, \"azName\": \"${azName_paas}\"}},  \"description\": \"${description_vpc_paas_jump}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_paas_create_runner"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    #echo $route_paas_create
    echo "[DEBUG] Маршрут к subnet_runner в VPC PAAS создан "
fi

echo "================================================================="
echo "====Работаем с VPC INFRA!!!===="
echo "VPC routes on infra:"
echo "Получаем токен для доступа к VPC Infra"
token_infra=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${keyid_infra}\", 'secret': \"${secret_infra}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $token_infra"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from responce"
token_infra=$(echo $token_infra|jq -r '.access_token')
echo "Получаем список маршрутов в VPC infra"
list_routes_vpc_infra=$(curl -sSL --fail-with-body --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $list_routes_vpc_infra"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_paas $subnet_paas в VPC infra"
route_vpc_infra_exists=$(echo $list_routes_vpc_infra|jq ".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt")
echo $route_vpc_infra_exists
if [ ! -z  "${route_vpc_infra_exists:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_vpc_infra_exists}"
else
    echo "[DEBUG] Создаем маршрут в VPC infra"
    route_vpc_infra_create=$(curl -sSL --fail-with-body -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_infra}\", \"projectId\": \"${project_id_infra}\",  \"subnet\": \"${subnet_paas}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_infra}\"}, \"azName\": \"${azName_infra}\"}},  \"description\": \"${description_vpc_infra}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_infra_create"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    #echo $route_paas_create
    echo "[DEBUG] Маршрут в VPC Infra создан "
fi
echo "================================================================="
echo "====Работаем с MR INFRA!!!===="
echo "Magic Router routes on infra:"
echo "Получаем токен для доступа к MR Infra"
token_infra=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${keyid_infra}\", 'secret': \"${secret_infra}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $token_infra"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from responce"
token_infra=$(echo $token_infra|jq -r '.access_token')

echo "Получаем список маршрутов в MR infra"
list_routes_mr_infra=$(curl -sSL --fail-with-body --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $list_routes_mr_infra"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_paas $subnet_paas в MR infra"
route_mr_infra_exists=$(echo $list_routes_mr_infra|jq ".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt")
echo $route_mr_infra_exists
if [ ! -z  "${route_mr_infra_exists:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_infra_exists}"
else
    echo "[DEBUG] Создаем маршрут в MR infra"
    #echo "будем запускать curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_infra}\", \"description\": \"${description_vpc_infra}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_infra_to_paas}\"}}""
    route_mr_infra_create=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_infra}\", \"description\": \"${description_vpc_infra}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_infra_to_paas}\"}}" 2>&1)
    echo $route_mr_infra_create
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_infra_create"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_infra_create
    echo "[DEBUG] Маршрут в MR Infra создан "
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_runner $subnet_runner в MR infra"
route_mr_infra_exists_runner=$(echo $list_routes_mr_infra|jq ".routes[] | select(.subnet == \"${subnet_runner}\") | .createdAt")
echo $route_mr_infra_exists_runner
if [ ! -z  "${route_mr_infra_exists_runner:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_infra_exists_runner}"
else
    echo "[DEBUG] Создаем маршрут в MR infra"
    echo "будем запускать curl -sSL --fail-with-bodyv -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"vpcConnectionId\": \"${vpcConnectionId_infra}\", \"magicRouterId\": \"${magic_router_id_infra}\", \"azName\":\"${azName_paas}\", \"description\": \"${description_mr_infra_runner}\", \"subnet\": \"${subnet_runner}\"}""
    route_mr_infra_create_runner=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"vpcConnectionId\": \"${vpcConnectionId_infra}\", \"magicRouterId\": \"${magic_router_id_infra}\", \"azName\":\"${azName_paas}\", \"description\": \"${description_mr_infra_runner}\", \"subnet\": \"${subnet_runner}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_infra_create_runner"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_infra_create_runner
    echo "[DEBUG] Маршрут в MR Infra создан "
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_jumphost $subnet_jumphost в MR infra"
route_mr_infra_exists_jumphost=$(echo $list_routes_mr_infra|jq ".routes[] | select(.subnet == \"${subnet_jumphost}\") | .createdAt")
echo $route_mr_infra_exists_jumphost
if [ ! -z  "${route_mr_infra_exists_jumphost:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_infra_exists_jumphost}"
else
    echo "[DEBUG] Создаем маршрут в MR infra"
    #route_mr_infra_create=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_infra}\", \"description\": \"${description_vpc_infra}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_infra_to_paas}\"}}" 2>&1)
    route_mr_infra_create_jumphost=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_infra}/routes/static" --header "Authorization: Bearer $token_infra" --header "Content-Type: application/json" --data "{ \"vpcConnectionId\": \"${vpcConnectionId_infra}\", \"magicRouterId\": \"${magic_router_id_infra}\", \"azName\":\"${azName_paas}\", \"description\": \"${description_mr_infra_jumphost}\", \"subnet\": \"${subnet_jumphost}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_infra_create_jumphost"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_infra_create_jumphost
    echo "[DEBUG] Маршрут в MR Infra создан "
fi
echo "================================================================="
echo "====Работаем с MRGIS!!!===="
echo "Magic Router routes on GIS:"
echo "Получаем токен для доступа к MR GIS"
token_gis=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${key_id_gis}\", 'secret': \"${secret_gis}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $token_gis"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from responce"
token_gis=$(echo $token_gis|jq -r '.access_token')

echo "Получаем список маршрутов в MR GIS"
list_routes_mr_gis=$(curl -sSL --fail-with-body --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $list_routes_mr_gis"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_paas $subnet_paas в MR GIS"
route_mr_gis_exists=$(echo $list_routes_mr_gis|jq ".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt")
echo $route_mr_gis_exists
if [ ! -z  "${route_mr_gis_exists:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_git_exists}"
else
    echo "[DEBUG] Создаем маршрут в MR infra"
    #echo "будем запускать curl -sSL --fail-with-bodyiv -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_gis}\", \"description\": \"${description_mr_gis2paas}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_gis}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_gis_to_paas}\"}}" "
    route_mr_gis2paas_create=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_gis}\", \"description\": \"${description_mr_gis2paas}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_gis}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_gis_to_paas}\"}}")
    exitcode=$?
    echo $route_mr_gis2paas_create
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_mr_gis2paas_create"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_gis2paas_create
    echo "[DEBUG] Маршрут в MR GIS создан "
fi

echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_gis $subnet_gis в MR GIS"
route_mr_gis_exists_gis=$(echo $list_routes_mr_gis|jq ".routes[] | select(.subnet == \"${subnet_gis}\") | .createdAt")
echo $route_mr_gis_exists_gis
if [ ! -z  "${route_mr_gis_exists_gis:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_mr_gis_exists_gis}"
else
    echo "[DEBUG] Создаем маршрут в MR GIS nexthop vpc gis"
    #route_mr_gis2paas_create=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" --header "Content-Type: application/json" --data "{ \"magicRouterId\": \"${magic_router_id_gis}\", \"description\": \"${description_mr_gis2paas}\", \"subnet\": \"${subnet_paas}\", \"nextHopMagicRouter\": {\"azName\": \"${azName_paas}\", \"magicRouterConnectionId\": \"${magicRouterConnectionId_gis_to_paas}\"}}" 2>&1)
    route_mr_gis_create_gis=$(curl -sSL --fail-with-body -X POST --location "https://magic-router.api.cloud.ru/v1/magicRouters/${magic_router_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" --header "Content-Type: application/json" --data "{ \"vpcConnectionId\": \"${vpcConnectionId_gis}\", \"magicRouterId\": \"${magic_router_id_gis}\", \"azName\":\"${azName_gis}\", \"description\": \"${description_mr_gis}\", \"subnet\": \"${subnet_gis}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_mr_gis_create_gis"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_mr_gis2paas_create
    echo "[DEBUG] Маршрут в MR GIS создан "
fi
echo "!!!!GIS Magic Router end!!!!"
echo "================================================================="
echo "!!!!GIS VPC begin!!!!"
echo "VPC routes on GIS:"
echo "Получаем токен для доступа к VPC GIS"
token_gis=$(curl -sSL --fail-with-body --location 'https://iam.api.cloud.ru/api/v1/auth/token'  --header 'Content-Type: application/json' --data "{ 'keyId': \"${key_id_gis}\", 'secret': \"${secret_gis}\" }" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $token_gis"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "extract token from responce"
token_gis=$(echo $token_gis|jq -r '.access_token')
echo "Получаем список маршрутов в VPC GIS"
list_routes_vpc_gis=$(curl -sSL --fail-with-body --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" 2>&1)
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "[ERROR] running request, exitcode = $exitcode, return data = $list_routes_vpc_gis"
  exit $exitcode
else
  echo "[OK], use result"
fi
echo "-----------------------------------------------------------------"
echo "Ищем есть ли уже наша подсеть subnet_paas $subnet_paas в VPC GIS"
route_vpc_gis_exists=$(echo $list_routes_vpc_gis|jq ".routes[] | select(.subnet == \"${subnet_paas}\") | .createdAt")
echo $route_vpc_gis_exists
if [ ! -z  "${route_vpc_gis_exists:-}" ]; then
    echo "[DEBUG] Маршрут уже есть, создан ${route_vpc_gis_exists}"
else
    echo "[DEBUG] Создаем маршрут в VPC gis"
    route_vpc_gis_create=$(curl -ivk  -X POST --location "https://vpc.api.cloud.ru/v1/vpcs/${vpc_id_gis}/routes/static" --header "Authorization: Bearer $token_gis" --header "Content-Type: application/json" --data "{ \"vpcId\": \"${vpc_id_gis}\", \"projectId\": \"${project_id_gis}\",  \"subnet\": \"${subnet_paas}\", \"nextHop\": {\"magicRouter\": {\"magicRouter\": {\"id\": \"${magic_router_id_gis}\"}, \"azName\": \"${azName_gis}\"}},  \"description\": \"${description_vpc_gis}\"}" 2>&1)
    exitcode=$?
    if [ "$exitcode" -ne 0 ]; then
      echo "[ERROR] running request, exitcode = $exitcode, return data = $route_vpc_gis_create"
      exit $exitcode
    else
      echo "[OK], use result"
    fi
    echo $route_vpc_gis_create
    echo "[DEBUG] Маршрут в VPC GIS создан "
fi
echo "!!!!GIS VPC end!!!!"
echo "================================================================="