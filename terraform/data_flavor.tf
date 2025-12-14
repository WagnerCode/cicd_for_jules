data "cloudru_evolution_flavor" "kafka_broker_flavor" {
  filter {
    cpu              = var.kafka_broker_cpu
    ram              = var.kafka_broker_ram
    oversubscription = var.kafka_broker_oversubscription
  }
}
