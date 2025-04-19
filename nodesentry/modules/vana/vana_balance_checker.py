#!/usr/bin/env python3

import requests
import yaml
import time
from decimal import Decimal
import subprocess
from datetime import datetime

CONFIG_PATH = "/root/nodesentry/config.yaml"
BALANCE_THRESHOLD = Decimal("5.0")

def load_config():
    with open(CONFIG_PATH, "r") as f:
        config = yaml.safe_load(f)
    return config

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
    message = f"""⚠️ NodeSentry: низкий баланс

🧩 Нода: {node_name}
🔑 Адрес: `{address}`
💰 Баланс: {balance:.6f} VANA

🔗 Пополнить через кран:
https://faucet.vana.org/"""
    try:
        response = requests.post(
            f"https://api.telegram.org/bot{bot_token}/sendMessage",
            data={"chat_id": chat_id, "text": message, "parse_mode": "Markdown"},
            timeout=10
        )
        if response.status_code == 200:
            print(f"✅ Уведомление отправлено: {datetime.now()}")
        else:
            print(f"❌ Telegram API ошибка: {response.text}")
    except Exception as e:
        print(f"❌ Ошибка отправки в Telegram: {e}")

def main():
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
