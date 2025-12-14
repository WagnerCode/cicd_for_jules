variable "kafka_broker_count" {
  type        = number
  description = "Количество брокеров Kafka."
  #default     = 3
}

variable "kafka_broker_ips" {
  type        = list(string)
  description = "Список IP-адресов для брокеров Kafka."
  #default     = ["10.88.12.21", "10.88.12.22", "10.88.12.23"]
}

variable "kafka_broker_cpu" {
  type        = number
  description = "Количество CPU для каждого брокера Kafka."
  default     = 2
}

variable "kafka_broker_ram" {
  type        = number
  description = "Объем RAM (ГБ) для каждого брокера Kafka."
  default     = 4
}

variable "kafka_broker_oversubscription" {
  type        = string
  description = "Гарантированная доля CPU для каждого брокера Kafka (например, '1:10' для 10%)."
  default     = "1:10"
}

variable "kafka_broker_boot_disk_size" {
  type        = number
  description = "Размер загрузочного диска (ГБ) для каждого брокера Kafka."
  default     = 40
}

variable "kafka_broker_disk_size" {
  type        = number
  description = "Размер дополнительного диска (ГБ) для каждого брокера Kafka."
  default     = 10
}
