#!/usr/bin/env python3
import os
import json
import sys

def get_env_var(var_name, default=None, required=False):
    value = os.environ.get(var_name, default)
    if required and value is None:
        print(f"Error: Required environment variable '{var_name}' is not set.")
        sys.exit(1)
    return value

def main():
    print("Generating terraform.tfvars...")

    # 1. Parse CORAX_NODES for Kafka Brokers
    corax_nodes_json = get_env_var("CORAX_NODES", required=True)
    try:
        corax_nodes = json.loads(corax_nodes_json)
    except json.JSONDecodeError as e:
        print(f"Error: Failed to parse CORAX_NODES JSON: {e}")
        sys.exit(1)

    kafka_broker_ips = []
    for node in corax_nodes:
        # Assuming all nodes in CORAX_NODES are kafka brokers or checking roles if needed.
        # Based on prototype, we just take all IPs or filter by role if specified.
        # For now, let's assume all nodes with 'kafka' role are brokers.
        if "roles" in node and "kafka" in node["roles"]:
             kafka_broker_ips.append(node["host"])
    
    # If no nodes specifically have 'kafka' role, maybe fallback to all nodes?
    # Let's stick to 'kafka' role filter for safety, or just all if specific logic isn't clear.
    # The user said "map CORAX_NODES (JSON) to kafka_broker_ips".
    if not kafka_broker_ips:
         print("Warning: No nodes with 'kafka' role found in CORAX_NODES. Using all nodes.")
         kafka_broker_ips = [node["host"] for node in corax_nodes]

    kafka_broker_count = len(kafka_broker_ips)

    # 2. Get other variables
    cloudru_project_id = get_env_var("CLOUDRU_PROJECT_ID", required=True)
    gis_project_name = get_env_var("GIS_PROJECT_NAME", required=True)
    cluster_number = get_env_var("CLUSTER_NUMBER", required=True)
    cluster_subnet = get_env_var("CLUSTER_SUBNET", required=True)
    cluster_gateway = get_env_var("CLUSTER_GATEWAY", required=True)
    users_subnet = get_env_var("USERS_SUBNET", required=True)
    infra_subnet_gitlab = get_env_var("INFRA_SUBNET_GITLAB", required=True)
    infra_subnet_jumphost = get_env_var("INFRA_SUBNET_JUMPHOST", required=True)

    # Resource vars with defaults
    kafka_broker_cpu = get_env_var("KAFKA_BROKER_CPU", "2")
    kafka_broker_ram = get_env_var("KAFKA_BROKER_RAM", "4")
    kafka_broker_oversubscription = get_env_var("KAFKA_BROKER_OVERSUBSCRIPTION", "1:10")
    kafka_broker_boot_disk_size = get_env_var("KAFKA_BROKER_BOOT_DISK_SIZE", "40")
    kafka_broker_disk_size = get_env_var("KAFKA_BROKER_DISK_SIZE", "10")
    
    # Sensitive vars (should be in env)
    cloudru_key_id = get_env_var("CLOUDRU_KEY_ID", required=True)
    cloudru_secret = get_env_var("CLOUDRU_SECRET", required=True)
    user_name = get_env_var("USER_NAME", required=True) # Mapping DEPLOY_NODE_USER to USER_NAME
    user_pass = get_env_var("USER_PASS", required=True) # Needs to be provided
    
    # SSH Key handling
    # USER_PUBLIC_KEY is needed. We might need to generate it from SSH_PRIVATE_KEY or expect it.
    # The pipeline templates generate a public key in ~/.ssh/id_rsa_corax.pub.
    # We can read it from there.
    user_public_key = ""
    pub_key_path = os.path.expanduser("~/.ssh/id_rsa_corax.pub")
    if os.path.exists(pub_key_path):
        with open(pub_key_path, "r") as f:
            user_public_key = f.read().strip()
    else:
        # Fallback or error? Let's try env var
        user_public_key = get_env_var("USER_PUBLIC_KEY", "")
        if not user_public_key:
             print(f"Error: Could not find public key at {pub_key_path} and USER_PUBLIC_KEY env var is not set.")
             sys.exit(1)

    # 3. Write terraform.tfvars
    tfvars_content = f"""
kafka_broker_count = {kafka_broker_count}
kafka_broker_ips = {json.dumps(kafka_broker_ips)}

kafka_broker_cpu = {kafka_broker_cpu}
kafka_broker_ram = {kafka_broker_ram}
kafka_broker_oversubscription = "{kafka_broker_oversubscription}"
kafka_broker_boot_disk_size = {kafka_broker_boot_disk_size}
kafka_broker_disk_size = {kafka_broker_disk_size}

CLOUDRU_PROJECT_ID = "{cloudru_project_id}"
GIS_PROJECT_NAME = "{gis_project_name}"
CLUSTER_NUMBER = "{cluster_number}"
CLUSTER_SUBNET = "{cluster_subnet}"
CLUSTER_GATEWAY = "{cluster_gateway}"
USERS_SUBNET = "{users_subnet}"
INFRA_SUBNET_GITLAB = "{infra_subnet_gitlab}"
INFRA_SUBNET_JUMPHOST = "{infra_subnet_jumphost}"

CLOUDRU_KEY_ID = "{cloudru_key_id}"
CLOUDRU_SECRET = "{cloudru_secret}"
USER_NAME = "{user_name}"
USER_PASS = "{user_pass}"
USER_PUBLIC_KEY = "{user_public_key}"
"""

    output_path = os.path.join("terraform", "terraform.tfvars")
    # Ensure directory exists (it should, but good practice)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, "w") as f:
        f.write(tfvars_content)
    
    print(f"Successfully generated {output_path}")
    print(tfvars_content)

if __name__ == "__main__":
    main()
