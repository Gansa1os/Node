#!/bin/bash

# === Конфигурация ===
LOG_PATH="/root/.hyperlane/logs/latest.log"  # ← Измени на нужный путь, если другой
BOT_TOKEN="7243235590:AAGc3MkrJtOW8O7EiMJlOcSGI3-4tS9Hzdc"
CHAT_ID="479750930"

# === IP → Нода ===
read -r -d '' NODE_MAP << EOM
37.46.23.83:Нода_1
185.183.247.56:Нода_2
62.171.145.237:Нода_8
EOM

# === Установка зависимостей ===
apt update && apt install -y python3 python3-pip
pip3 install requests

# === Создание Python-скрипта ===
cat > /root/node_monitor.py << EOF
import requests
import time
import socket
from datetime import datetime

BOT_TOKEN = "${BOT_TOKEN}"
CHAT_ID = "${CHAT_ID}"
LOG_FILE = "${LOG_PATH}"

NODE_MAP = {
    "37.46.23.83": "Нода_1",
    "185.183.247.56": "Нода_2",
    "62.171.145.237": "Нода_8"
}

KEYWORDS = ["ERROR", "panic", "failed", "unreachable"]

def get_ip():
    try:
        return requests.get('https://api.ipify.org').text.strip()
    except:
        return "неизвестный IP"

def get_node_name(ip):
    return NODE_MAP.get(ip, f"Неизвестная нода ({ip})")

def format_message(line, node_name):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return f"""
🚨 <b>NodeSentry: ошибка в логах</b>

🧩 <b>Источник:</b> <code>{node_name}</code>
🕓 <b>Время:</b> <i>{now}</i>

📄 <b>Сообщение:</b>
<code>{line.strip()}</code>
""".strip()

def send_alert(message):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": message,
        "parse_mode": "HTML"
    }
    try:
        requests.post(url, json=payload)
    except:
        pass

def monitor():
    ip = get_ip()
    node_name = get_node_name(ip)
    with open(LOG_FILE, "r") as f:
        f.seek(0, 2)  # Перемотка в конец
        while True:
            line = f.readline()
            if not line:
                time.sleep(1)
                continue
            if any(keyword in line for keyword in KEYWORDS):
                msg = format_message(line, node_name)
                send_alert(msg)

if __name__ == "__main__":
    monitor()
EOF

# === Создание systemd-сервиса ===
cat > /etc/systemd/system/nodesentry.service << EOF
[Unit]
Description=NodeSentry log monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/node_monitor.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# === Запуск сервиса ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable nodesentry.service
systemctl restart nodesentry.service

echo "✅ NodeSentry установлен и запущен как systemd-сервис."
