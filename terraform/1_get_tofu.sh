#!/bin/bash
# Скриптом выкачивается и распаковывается opentofu
curl --proto '=https' --tlsv1.2 -fsSL https://github.com/opentofu/opentofu/releases/download/v1.10.6/tofu_1.10.6_amd64.rpm -o tofu_1.10.6_amd64.rpm
echo "rpm2cpio tofu_1.10.6_amd64.rpm | cpio -idmv" > unpackrpm.sh
chmod +x unpackrpm.sh
./unpackrpm.sh
cp ./usr/bin/tofu .
./tofu version
