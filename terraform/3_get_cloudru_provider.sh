#!/bin/bash
echo "Выкачиваем terraform provider (from local)"
mkdir -p .terraform.d/plugins/cloud.ru/cloudru/cloud/1.5.0/linux_amd64/
cp -n /opt/localrepo/terraform/providers/cloud.ru/cloudru/cloud/1.5.0/linux_amd64/terraform-provider-cloud_1.5.0_linux_amd64 .terraform.d/plugins/cloud.ru/cloudru/cloud/1.5.0/linux_amd64/
chmod +x .terraform.d/plugins/cloud.ru/cloudru/cloud/1.5.0/linux_amd64/terraform-provider-cloud_1.5.0_linux_amd64

##!/bin/bash
# Скриптом выкачивается и распаковывается провайдер
#curl -L --create-dirs -o .terraform.d/plugins/cloud.ru/cloudru/cloud/1.6.0/linux_amd64/terraform-provider-cloud_1.6.0_linux_amd64 https://github.com/CLOUDdotRu/evo-terraform/releases/download/1.6.0/terraform-provider-cloud_1.6.0_linux_amd64 && chmod +x .terraform.d/plugins/cloud.ru/cloudru/cloud/1.6.0/linux_amd64/terraform-provider-cloud_1.6.0_linux_amd64