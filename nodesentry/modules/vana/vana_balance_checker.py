#!/usr/bin/env python3

import requests
import yaml
import asyncio
import os
import json
import subprocess
from decimal import Decimal
from datetime import datetime

CONFIG_PATH = "/root/nodesentry/config.yaml"
MONITOR_DIR = "/root/nodesentry/modules/vana"
LAST_CHECK_PATH = f"{MONITOR_DIR}/.last_balance_check"
CHECK_INTERVAL_HOURS = 24
BALANCE_THRESHOLD = Decimal("5.0")

def load_config():
    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f)

def get_node_name(ip, node_map):
    return node_map.get(ip, ip)

def get_balance(address):
    """Получение баланса кошелька Vana"""
    url = f"https://moksha.vanascan.io/api/v2/addresses/{address}"

    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36",
        "Referer": f"https://moksha.vanascan.io/address/{address}",
        "Accept": "*/*",
    }

    cookies = {
        "chakra-ui-color-mode": "light",
        "chakra-ui-color-mode-hex": "#FFFFFF",
        "indexing_alert": "false",
        "address_format": "base16",
    }

    try:
        print(f"Запрос баланса для адреса: {address}")
        response = requests.get(url, headers=headers, cookies=cookies, timeout=10)
        print(f"Статус ответа: {response.status_code}")
        
        if response.status_code != 200:
            print(f"Ошибка: {response.text[:200]}")
            return Decimal("0")
        
        data = response.json()
        raw_balance = data.get("coin_balance", "0")
        balance = Decimal(raw_balance) / Decimal(10**18)
        print(f"Баланс получен: {balance:.6f} VANA")
        return balance
    except Exception as e:
        print(f"Ошибка при запросе: {e}")
        return Decimal("0")

def send_telegram_alert(bot_token, chat_id, node_name, address, balance):
    message = f"""⚠️ NodeSentry: низкий баланс

🧩 Нода: {node_name}
🔑 Адрес:  `{address}`
💰 Баланс: {balance:.2f} VANA

🔗 Пополнить через кран:
https://faucet.vana.org/"""

    try:
        requests.post(
            f"https://api.telegram.org/bot{bot_token}/sendMessage",
            data={"chat_id": chat_id, "text": message, "parse_mode": "Markdown"}
        )
        print(f"Отправлено уведомление о низком балансе: {balance} VANA")
    except Exception as e:
        print("Ошибка отправки Telegram:", e)

def load_last_check():
    if not os.path.exists(LAST_CHECK_PATH):
        return None
    try:
        with open(LAST_CHECK_PATH, "r") as f:
            return datetime.fromisoformat(f.read().strip())
    except:
        return None

def save_last_check():
    # Создаем директорию, если она не существует
    os.makedirs(os.path.dirname(LAST_CHECK_PATH), exist_ok=True)
    
    with open(LAST_CHECK_PATH, "w") as f:
        f.write(datetime.now().isoformat())

async def main():
    config = load_config()
    wallet = config.get("wallet_address")
    if not wallet:
        print("⚠️ Wallet address не задан в config.yaml")
        return

    ip = os.popen("hostname -I | awk '{print $1}'").read().strip()
    node_name = get_node_name(ip, config.get("node_map", {}))
    bot_token = config["telegram"]["bot_token"]
    chat_id = config["telegram"]["chat_id"]

    while True:
        last = load_last_check()
        now = datetime.now()

        if not last or (now - last).total_seconds() >= CHECK_INTERVAL_HOURS * 3600:
            try:
                balance = get_balance(wallet)
                print(f"[{now}] Баланс: {balance:.6f} VANA")

                # Отправляем алерт если баланс ниже или равен порогу
                if balance <= BALANCE_THRESHOLD:
                    print(f"Баланс ниже порога ({BALANCE_THRESHOLD} VANA), отправляем алерт")
                    send_telegram_alert(bot_token, chat_id, node_name, wallet, balance)
                else:
                    print(f"Баланс в норме ({balance:.6f} VANA), порог: {BALANCE_THRESHOLD} VANA")
            except Exception as e:
                print(f"Ошибка при проверке баланса: {e}")
                # Отправляем алерт о проблеме с проверкой баланса
                error_message = f"""⚠️ NodeSentry: ошибка проверки баланса

🧩 Нода: {node_name}
🔑 Адрес: `{wallet}`
❌ Ошибка: {str(e)}

🔗 Проверить вручную:
https://moksha.vanascan.io/address/{wallet}"""
                
                try:
                    requests.post(
                        f"https://api.telegram.org/bot{bot_token}/sendMessage",
                        data={"chat_id": chat_id, "text": error_message, "parse_mode": "Markdown"}
                    )
                except Exception as e2:
                    print(f"Ошибка отправки сообщения об ошибке: {e2}")

            save_last_check()

        await asyncio.sleep(3600)  # Проверка каждый час (вдруг сервер перезапущен)
        
if __name__ == "__main__":
    asyncio.run(main())