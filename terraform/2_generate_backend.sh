#!/bin/bash
# Скриптом делаем из шаблона отдельный файл для стейта TF
sed s/CUSTOMENV/${TF_VAR_GIS_PROJECT_NAME}-${TF_VAR_CLUSTER_NUMBER}/ < backend.tf.template > backend.tf
cat backend.tf
