#!/usr/bin/env python3

import subprocess
import re
import requests
from datetime import datetime, timedelta
import yaml

CONFIG_PATH = "/root/nodesentry/config.yaml"

with open(CONFIG_PATH, "r") as f:
    config = yaml.safe_load(f)

BOT_TOKEN = config["telegram"]["bot_token"]
CHAT_ID = config["telegram"]["chat_id"]
NODE_MAP = config.get("node_map", {})

IP = subprocess.getoutput("hostname -I | awk '{print $1}'")
NODE_NAME = NODE_MAP.get(IP, IP)

# Антиспам: сохраняем последние отправки
last_sent = {}

# Паттерны нормальных логов (не отправлять)
NORMAL_PATTERNS = [
    r"Authorized worker",
    r"Accepted \d+ ms",
    r"Job: .*",
    r"\d+:\d+ A\d+:R\d+ \d+\.\d+ Kh - cp0 \d+\.\d+, cp1 \d+\.\d+",
    r"Using CPU",
    r"Established connection to",
    r"Extranonce set to",
    r"Epoch : \d+ Difficulty :",
    r"Selected pool",
]

def is_normal_log(line):
    for pattern in NORMAL_PATTERNS:
        if re.search(pattern, line):
            return True
    return False

def send_telegram_alert(message):
    now = datetime.now()
    key = message.strip()[:100]  # Укорачиваем для антиспама

    if key in last_sent and now - last_sent[key] < timedelta(hours=1):
        return  # Пропустить повторное сообщение в течение часа

    last_sent[key] = now

    alert = f"""
🚨 NodeSentry: ошибка в логах

🧩 Источник: {NODE_NAME}
🕓 Время: {now.strftime('%Y-%m-%d %H:%M:%S')}

📄 Сообщение от initverse:
{message.strip()}"""

    try:
        requests.post(
            f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
            data={"chat_id": CHAT_ID, "text": alert}
        )
    except Exception as e:
        print("Ошибка отправки в Telegram:", e)

# Чтение логов
process = subprocess.Popen(
    ["journalctl", "-u", "initverse.service", "-f", "--output=short-iso"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
)

for line in process.stdout:
    if not is_normal_log(line):
        send_telegram_alert(line)
