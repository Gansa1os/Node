#!/usr/bin/env python3

import requests
import yaml
import asyncio
import os
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
    url = f"https://moksha.vanascan.io/api/v2/addresses/{address}"
    
    # Расширенные заголовки на основе примера запроса
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36",
        "Accept": "*/*",
        "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7",
        "Referer": f"https://moksha.vanascan.io/address/{address}",
        "Origin": "https://moksha.vanascan.io",
        "authority": "moksha.vanascan.io",
        "sec-ch-ua": '"Google Chrome";v="135", "Not-A.Brand";v="8", "Chromium";v="135"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-origin"
    }
    
    # Куки из примера
    cookies = {
        "chakra-ui-color-mode": "light",
        "chakra-ui-color-mode-hex": "#FFFFFF",
        "indexing_alert": "false",
        "address_format": "base16"
    }
    
    try:
        print(f"Запрос баланса для адреса: {address}")
        response = requests.get(url, headers=headers, cookies=cookies)
        print(f"API ответ: статус {response.status_code}")
        
        # Проверяем статус ответа
        if response.status_code != 200:
            print(f"Ошибка API: статус {response.status_code}, текст: {response.text[:100]}")
            return Decimal("0")
            
        # Проверяем, что ответ не пустой
        if not response.text.strip():
            print("Ошибка API: пустой ответ")
            return Decimal("0")
            
        # Выводим первые 200 символов ответа для диагностики
        print(f"Ответ API (первые 200 символов): {response.text[:200]}")
            
        # Пробуем распарсить JSON
        data = response.json()
        
        # Проверяем наличие поля coin_balance
        if "coin_balance" not in data:
            print(f"Ошибка: поле 'coin_balance' отсутствует в ответе. Полный ответ: {response.text}")
            return Decimal("0")
            
        raw = data.get("coin_balance", "0")
        balance = Decimal(raw) / Decimal(10**18)
        print(f"Баланс получен: {balance} VANA (raw: {raw})")
        return balance
    except requests.exceptions.RequestException as e:
        print(f"Ошибка запроса: {e}")
        return Decimal("0")
    except (ValueError, requests.exceptions.JSONDecodeError) as e:
        print(f"Ошибка декодирования JSON: {e}")
        print(f"Ответ сервера: {response.text[:200]}")
        return Decimal("0")
    except Exception as e:
        print(f"Неизвестная ошибка: {e}")
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
                print(f"[{now}] Баланс: {balance:.2f} VANA")

                # Отправляем алерт если баланс ниже порога или равен 0 (возможная ошибка API)
                if balance <= BALANCE_THRESHOLD:
                    print(f"Баланс ниже порога ({BALANCE_THRESHOLD} VANA), отправляем алерт")
                    send_telegram_alert(bot_token, chat_id, node_name, wallet, balance)
                else:
                    print(f"Баланс в норме ({balance:.2f} VANA), порог: {BALANCE_THRESHOLD} VANA")
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