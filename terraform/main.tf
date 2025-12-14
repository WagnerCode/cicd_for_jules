terraform {
  required_providers {
    cloudru  = {
      source  = "cloud.ru/cloudru/cloud"
      version = ">= 1.3.2"
    }
  }
}

variable "CLOUDRU_KEY_ID" {
  type = string
  sensitive = true
}

variable "CLOUDRU_SECRET" {
  type = string
  sensitive = true
}

variable "CLOUDRU_PROJECT_ID" {
  type = string
}

variable "USER_NAME" {
  type = string
  sensitive = true
}

variable "USER_PASS" {
  type = string
  sensitive = true
}

variable "USER_PUBLIC_KEY" {
  type = string
}


variable "GIS_PROJECT_NAME" {
  # example: Gorod
  type = string
}

variable "CLUSTER_NUMBER" {
#  example: 1
  type = string
}

variable "CLUSTER_SUBNET" {
  # 10.0.
  type = string
}

variable "CLUSTER_GATEWAY" {
  type = string
}


#variable "CLUSTER_VIP" {
#  type = string
#}



variable "USERS_SUBNET" {
  type = string
}

variable "INFRA_SUBNET_GITLAB" {
  type = string
}

variable "INFRA_SUBNET_JUMPHOST" {
  type = string
}
# 3 вышестоящих подсети на должны быть одинаковыми, иначе создание группы безопасности упадет с ошибкой

provider "cloudru" {
  project_id = "${var.CLOUDRU_PROJECT_ID}"
  auth_key_id = "${var.CLOUDRU_KEY_ID}"
  auth_secret = "${var.CLOUDRU_SECRET}"
  iam_endpoint = "iam.api.cloud.ru:443"
  k8s_endpoint = "mk8s.api.cloud.ru:443"
  evolution_endpoint = "https://compute.api.cloud.ru"
  cloudplatform_endpoint = "organization.api.cloud.ru:443"
  dbaas_endpoint = "dbaas.api.cloud.ru:443"
}


resource "cloudru_evolution_subnet" "coraxas_subnet" {
  name = "subnet-${var.GIS_PROJECT_NAME}-corax-${var.CLUSTER_NUMBER}"
  subnet_address = "${var.CLUSTER_SUBNET}"
  routed_network = true
  default_gateway = "${var.CLUSTER_GATEWAY}"
  dns_servers = ["8.8.8.8"]
  availability_zone {
    id = "7c99a597-8516-494f-a2c7-d7377048681e"
  }
}

resource "cloudru_evolution_security_group" "corax_security_group" {
  name = "sg-Corax-${var.GIS_PROJECT_NAME}-${var.CLUSTER_NUMBER}"
  description = "Группа безопасности для кластера ${var.GIS_PROJECT_NAME} ${var.CLUSTER_NUMBER}"
  availability_zone {
    id = "7c99a597-8516-494f-a2c7-d7377048681e"
  }
  rules {
    direction = "egress"
    ether_type = "IPv4"
    ip_protocol = "any"
    port_range = "any"
    remote_ip_prefix = "0.0.0.0/0"
  }

  rules {
    direction = "ingress"
    ether_type = "IPv4"
    ip_protocol = "any"
    port_range = "any"
    remote_ip_prefix = "${var.CLUSTER_SUBNET}"
    description = "Правило для связи внутри кластера"
  }
  rules {
    direction = "ingress"
    ether_type = "IPv4"
    ip_protocol = "any"
    port_range = "any"
    remote_ip_prefix = "${var.USERS_SUBNET}"
    description = "Доступ от пользователей БД"
  }
  rules {
    direction = "ingress"
    ether_type = "IPv4"
    ip_protocol = "any"
    port_range = "any"
    remote_ip_prefix = "${var.INFRA_SUBNET_GITLAB}"
    description = "Доступ от gitlab worker"
  }
  rules {
    direction = "ingress"
    ether_type = "IPv4"
    ip_protocol = "any"
    port_range = "any"
    remote_ip_prefix = "${var.INFRA_SUBNET_JUMPHOST}"
    description = "Доступ от jump хостов"
  }
}

# Исключаем для вынесения в общие для project настройки
#resource "cloudru_evolution_security_group" "runner_security_group" {
#  name = "sg-Infra-Gitlab-Runner-tf"
#  description = "Группа безопасности для связи с Gitlab Runner проекта Инфраструктурные сервисы ЕЦП tf"
#  availability_zone {
#    id = "7c99a597-8516-494f-a2c7-d7377048681e"
#  }
#  rules {
#    direction = "egress"
#    ether_type = "IPv4"
#    ip_protocol = "any"
#    port_range = "any"
#    remote_ip_prefix = "0.0.0.0/0"
#  }
#
#  rules {
#    direction = "ingress"
#    ether_type = "IPv4"
#    ip_protocol = "any"
#    port_range = "any"
#    remote_ip_prefix = "${var.INFRA_SUBNET_GITLAB}"
#    description = "Правило для связи до Gltlab Runner"
#  }
#}

#########################
##  Kafka Brokers  #####
#########################
resource "cloudru_evolution_compute" "kafka_broker" {
  count = var.kafka_broker_count
  name  = "kafka-broker-${count.index + 1}-${var.GIS_PROJECT_NAME}-${var.CLUSTER_NUMBER}"

  flavor_id = tolist(data.cloudru_evolution_flavor.kafka_broker_flavor.resources)[0].id

  availability_zone {
    name = "ru.AZ-1"
  }

  image {
    name       = "alt-server-sp_c10f2"
    host_name  = "kafka-broker-${count.index + 1}"
    user_name  = var.USER_NAME
    public_key = var.USER_PUBLIC_KEY
    password   = var.USER_PASS
    
  }

  boot_disk {
    name = "kafka-broker-${count.index + 1}-boot-${var.GIS_PROJECT_NAME}-${var.CLUSTER_NUMBER}"
    size = var.kafka_broker_boot_disk_size
    disk_type {
      id = local.demo_disk_type.id
    }
  }

  network_interfaces {

    subnet {
      name = cloudru_evolution_subnet.coraxas_subnet.name
    }
    security_groups {
      id = cloudru_evolution_security_group.corax_security_group.id
    }
    ip_address = var.kafka_broker_ips[count.index]
  }
  
  lifecycle {
    ignore_changes = [
      placement_group,
      image,
    ]
  }
}

resource "cloudru_evolution_disk" "kafka_broker_disk" {
  count = var.kafka_broker_count
  name  = "kafka-broker-${count.index + 1}-data-${var.GIS_PROJECT_NAME}-${var.CLUSTER_NUMBER}"
  size  = var.kafka_broker_disk_size

  availability_zone {
    id = local.demo_az.id
  }

  disk_type {
    id = local.demo_disk_type.id
  }
}

resource "cloudru_evolution_disk_attachment" "kafka_broker_disk_attachment" {
  count      = var.kafka_broker_count
  compute_id = cloudru_evolution_compute.kafka_broker[count.index].id
  disk_id    = cloudru_evolution_disk.kafka_broker_disk[count.index].id
}


#output "store" {
#      value = {
#        "node1" =  {
#            "metadatafromstore" = {
#                "ip" = cloudru_evolution_compute.pango_vm1.network_interfaces[*].ip_address
#                "users" = "user"
#                "group"        = "postgresql"
#            }
#        },
#        "node2" =  {
#            "metadatafromstore" = {
#                "ip" = cloudru_evolution_compute.pango_vm2.network_interfaces[*].ip_address
#                "users" = "user"
#                "group"        = "postgresql"
#            }
#        },
#        "arbiter" =  {
#            "metadatafromstore" = {
#                "ip" = cloudru_evolution_compute.pango_arbiter.network_interfaces[*].ip_address
#                "users" = "user"
#                "group"        = "postgresql"
#            }
#        },
#        "deploy" =  {
#            "metadatafromstore" = {
#                "ip" = cloudru_evolution_compute.pango_deploy.network_interfaces[*].ip_address
#                "users" = "user"
#                "group"        = "postgresql"
#            }
#        }
#      }
#    }

