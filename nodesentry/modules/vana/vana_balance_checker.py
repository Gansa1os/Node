#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import yaml
import time
from decimal import Decimal
import subprocess
from datetime import datetime
import re

CONFIG_PATH = "/root/nodesentry/config.yaml"
BALANCE_THRESHOLD = Decimal("5.0")

def escape_md(text):
    """
    Экранирует символы для MarkdownV2, чтобы Telegram не выдал ошибку парсинга.
    """
    return re.sub(r'([_*\[\]()~`>#+=|{}.!\\-])', r'\\\1', text)

def load_config():
    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f)

def get_balance(address: str) -> Decimal:
    url = f"https://moksha.vanascan.io/api/v2/addresses/{address}"
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        raw = data.get("coin_balance", "0")
        return Decimal(raw) / Decimal(10**18)
    except Exception as e:
        print(f"❌ Ошибка при получении баланса: {e}")
        return Decimal("0")

def get_node_name(ip, node_map):
    return node_map.get(ip, ip)

def send_telegram_alert(bot_token, chat_id, node_name, address, balance):
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    escaped_node = escape_md(node_name)
    escaped_address = escape_md(address)
    escaped_balance = escape_md(f"{balance:.6f} VANA")
    escaped_time = escape_md(now)

    message = (
        "🚨 *NodeSentry: низкий баланс*\n\n"
        f"🧩 *Источник:* {escaped_node}\n"
        f"🕓 *Время:* {escaped_time}\n\n"
        f"📄 *Баланс по адресу:*\n`{escaped_address}`\n"
        f"💰 *Остаток:* `{escaped_balance}`\n\n"
        "🔗 [Кран](https://faucet.vana.org/)"
    )

    try:
        response = requests.post(
            f"https://api.telegram.org/bot{bot_token}/sendMessage",
            data={
                "chat_id": chat_id,
                "text": message,
                "parse_mode": "MarkdownV2"
            },
            timeout=10
        )
        print("Ответ Telegram:", response.status_code, response.text)
        if response.status_code == 200:
            print(f"✅ Уведомление отправлено: {datetime.now()}")
        else:
            print(f"❌ Ошибка Telegram API: {response.text}")
    except Exception as e:
        print(f"❌ Ошибка отправки в Telegram: {e}")

def main():
    print(">>> STARTED vana_balance_checker.py")
    config = load_config()
    wallet = config.get("wallet_address", "").strip()
    bot_token = config["telegram"]["bot_token"]
    chat_id = config["telegram"]["chat_id"]
    node_map = config.get("node_map", {})

    try:
        ip = subprocess.getoutput("hostname -I | awk '{print $1}'")
    except:
        ip = "unknown"

    node_name = get_node_name(ip, node_map)

    while True:
        balance = get_balance(wallet)
        print(f"[{datetime.now()}] Баланс: {balance:.6f} VANA")
        if balance <= BALANCE_THRESHOLD:
            send_telegram_alert(bot_token, chat_id, node_name, wallet, balance)
        else:
            print(f"Баланс в норме (>{BALANCE_THRESHOLD} VANA)")

        time.sleep(3600)

if __name__ == "__main__":
    main()