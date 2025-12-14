#!/usr/bin/env python3
"""
Генератор inventory.ini из JSON конфигурации нод
"""
import json
import os
import sys

def generate_inventory(nodes_json, ansible_user):
    """Генерация inventory.ini из JSON списка нод"""
    try:
        nodes = json.loads(nodes_json)
    except json.JSONDecodeError as e:
        print(f"ERROR: Некорректный JSON в CORAX_NODES: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(nodes, list):
        print("ERROR: CORAX_NODES должен быть JSON массивом", file=sys.stderr)
        sys.exit(1)

    # Структура для хранения хостов по ролям
    roles_hosts = {
        'kafka': [],
        'zookeeper': [],
        'crxsr': [],
        'crxui': []
    }

    # Заполнение ролей
    for node in nodes:
        name = node.get('name', 'unknown')
        host = node.get('host', '')
        user = node.get('user', ansible_user)
        roles = node.get('roles', [])

        if not host:
            print(f"WARNING: Нода {name} не имеет IP адреса", file=sys.stderr)
            continue

        host_line = f"{name}       ansible_host={host}         ansible_user={user}"

        for role in roles:
            if role in roles_hosts:
                roles_hosts[role].append(host_line)
            else:
                print(f"WARNING: Неизвестная роль '{role}' для ноды {name}", file=sys.stderr)

    # Генерация inventory
    inventory_content = []
    for role in ['kafka', 'zookeeper', 'crxsr', 'crxui']:
        inventory_content.append(f"[{role}]")
        if roles_hosts[role]:
            for host in roles_hosts[role]:
                inventory_content.append(host)
        else:
            inventory_content.append(f"# No hosts defined for {role} role")
        inventory_content.append("")

    return "\n".join(inventory_content)

if __name__ == "__main__":
    nodes_json = os.environ.get('CORAX_NODES', '[]')
    ansible_user = os.environ.get('ANSIBLE_USER', 'user1')

    print("=== Генерация inventory.ini ===", file=sys.stderr)
    print(f"Ansible user: {ansible_user}", file=sys.stderr)

    inventory = generate_inventory(nodes_json, ansible_user)

    # Подсчет нод
    nodes = json.loads(nodes_json)
    print(f"Обработано нод: {len(nodes)}", file=sys.stderr)

    print(inventory)
