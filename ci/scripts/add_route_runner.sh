#/bin/bash
###################################################
## Скрипты развертывания Pangolin в Cloud
# Скрипт по созданию маршрута в ОС gitlab-runner'а
# Использует переменные окружения
# Пример
# CLUSTER_SUBNET=10.0.12.16/28
# RUNNER_GW=172.18.0.1
###################################################
echo "block with route - begin"

if [ -z  "${RUNNER_GW:-}" ]; then
  echo "[FATAL] Дефолтный шлюз не определен в переменных, надо выставить переменную окружения RUNNER_GW"
fi
if [ -z  "${CLUSTER_SUBNET:-}" ]; then
  echo "[FATAL] Подсеть не определена в переменных, надо выставить переменную окружения CLUSTER_SUBNET"
fi
echo "[DEBUG] Найдены переменные окружения"
echo "[DEBUG] CLUSTER_SUBNET = $CLUSTER_SUBNET"
echo "[DEBUG] RUNNER_GW = $RUNNER_GW"
echo "[DEBUG] Печатаем таблицу маршрутов до "
ROUTE_PRINT=$(netstat -rn)
if [ -z  "${ROUTE_PRINT:-}" ]; then
  echo "[DEBUG] ошибка запуска netstat"
  exit 1
fi
echo $ROUTE_PRINT
CLUSTER_SUBNET_NOMASK=$(echo $CLUSTER_SUBNET|awk -F'/' '{print $1}')
if [ -z  "${CLUSTER_SUBNET_NOMASK:-}" ]; then
  echo "[DEBUG] Не удалось извлечь IP из подсети $CLUSTER_SUBNET"
  exit 1
else
  echo "[DEBUG] проверяем есть ли маршрут"
  ROUTE_EXIST=$(netstat -rn|grep $CLUSTER_SUBNET_NOMASK|wc -l)
  if [ "${ROUTE_EXIST:-}" -gt 0 ]; then
    echo "[DEBUG] маршрут уже есть для подсети $CLUSTER_SUBNET_NOMASK"
  else
    echo "[DEBUG] добавляем маршрут - gitlab-runner должен работать как сервис в ОС"
    echo "command: sudo /bin/route add -net $CLUSTER_SUBNET gw $RUNNER_GW"
    ROUTE_CREATE=$(sudo /bin/route add -net $CLUSTER_SUBNET gw $RUNNER_GW)
    # if [ -z  "${ROUTE_CREATE:-}" ]; then
    #   echo "[DEBUG] ошибка запуска route add"
    #   exit 1
    # fi
    echo "[DEBUG] Печатаем таблицу маршрутов после "
    netstat -rn
  fi
fi
echo
echo "block with route - end"