#!/usr/bin/env python3
"""
Генератор inventory.ini для деплой ноды (localhost)
Используется для запуска playbook.yaml только на деплой ноде
"""
import os
import sys

def generate_deploy_inventory(deploy_host, deploy_user):
    """Генерация inventory.ini только для деплой ноды"""

    inventory_content = [
        "[deploy]",
        f"localhost    ansible_connection=local",
        "",
        "[all:vars]",
        "ansible_python_interpreter=/usr/bin/python3",
        ""
    ]

    return "\n".join(inventory_content)

if __name__ == "__main__":
    deploy_host = os.environ.get('DEPLOY_NODE_HOST', 'localhost')
    deploy_user = os.environ.get('DEPLOY_NODE_USER', 'root')

    print("=== Генерация inventory для деплой ноды ===", file=sys.stderr)
    print(f"Deploy host: {deploy_host}", file=sys.stderr)
    print(f"Deploy user: {deploy_user}", file=sys.stderr)

    inventory = generate_deploy_inventory(deploy_host, deploy_user)

    print(inventory)
