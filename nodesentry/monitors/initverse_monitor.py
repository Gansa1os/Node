#!/usr/bin/env python3

import subprocess
import re
import requests
from datetime import datetime, timedelta
import yaml

# === Загрузка конфигурации ===
with open("/root/nodesentry/config.yaml", "r") as f:
    config = yaml.safe_load(f)

BOT_TOKEN = config["telegram"]["bot_token"]
CHAT_ID = config["telegram"]["chat_id"]
NODE_MAP = config["node_map"]

# === Имя текущего узла ===
IP = subprocess.getoutput("hostname -I | awk '{print $1}'")
NODE_NAME = NODE_MAP.get(IP, IP)

# === Паттерны нормального поведения ===
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

# === Антиспам хранилище ===
last_sent = {}

# === Функция отправки в Telegram ===
def send_telegram_alert(message):
    now = datetime.now()
    key = message.strip()[:100]

    if key in last_sent and now - last_sent[key] < timedelta(hours=1):
        return

    last_sent[key] = now

    alert = f"""🚨 NodeSentry: ошибка в логах

🧩 Источник: {NODE_NAME}
🕓 Время: {now.strftime('%Y-%m-%d %H:%M:%S')}

📄 Сообщение от initverse:
{message}"""

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    try:
        requests.post(url, data={"chat_id": CHAT_ID, "text": alert})
    except Exception as e:
        print("Ошибка отправки в Telegram:", e)

# === Запуск мониторинга журнала systemd ===
process = subprocess.Popen(
    ["journalctl", "-fu", "initverse.service", "--output=short-iso"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
)

for line in process.stdout:
    if not any(re.search(pattern, line) for pattern in NORMAL_PATTERNS):
        send_telegram_alert(line.strip())
