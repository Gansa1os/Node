#!/usr/bin/env python3

import subprocess
import re
import requests
from datetime import datetime
import yaml
import os

# === Пути ===
CONFIG_PATH = "/root/nodesentry/config.yaml"

# === Загрузка конфигурации ===
with open(CONFIG_PATH, "r") as f:
    config = yaml.safe_load(f)

BOT_TOKEN = config["telegram"]["bot_token"]
CHAT_ID = config["telegram"]["chat_id"]
NODE_MAP = config.get("node_map", {})

# === Имя текущего узла ===
IP = subprocess.getoutput("hostname -I | awk '{print $1}'")
NODE_NAME = NODE_MAP.get(IP, IP)

# === Ключевые слова (ошибки) ===
KEYWORDS = [
    "failed to perform ABCI query",
    "unauthorized",
    "mempool is full",
    "connection refused",
    "timeout",
    "could not broadcast",
    "failed to sign vote",
]

# === Отправка Telegram-уведомления ===
def send_telegram_alert(message):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    alert = f"""\ud83d\uded8 NodeSentry: ошибка в логах

\ud83e\uddf9 Источник: {NODE_NAME}
\ud83d\udd53 Время: {now}

\ud83d\udcc4 Сообщение от vana:
{message}"

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    try:
        requests.post(url, data={"chat_id": CHAT_ID, "text": alert})
    except Exception as e:
        print("Ошибка отправки в Telegram:", e)

# === Чтение логов из journalctl ===
process = subprocess.Popen(
    ["journalctl", "-u", "vana.service", "-f", "--output=short-iso"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
)

for line in process.stdout:
    if any(keyword in line for keyword in KEYWORDS):
        send_telegram_alert(line.strip())
