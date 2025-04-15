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
    """Получение баланса кошелька Vana через curl"""
    try:
        print(f"Запрос баланса для адреса: {address}")
        
        # Формируем команду curl с необходимыми заголовками и куками
        cmd = f"""curl -s -H "User-Agent: Mozilla/5.0" -H "Accept: */*" -H "Referer: https://moksha.vanascan.io/address/{address}" "https://moksha.vanascan.io/api/v2/addresses/{address}" """
        
        # Выполняем команду
        result = os.popen(cmd).read()
        
        # Проверяем, что ответ не пустой
        if not result.strip():
            print("Ошибка API: пустой ответ")
            return Decimal("0")
            
        # Выводим первые 200 символов ответа для диагностики
        print(f"Ответ API (первые 200 символов): {result[:200]}")
        
        # Пробуем распарсить JSON
        data = json.loads(result)
        
        # Проверяем наличие поля coin_balance
        if "coin_balance" not in data:
            print(f"Ошибка: поле 'coin_balance' отсутствует в ответе")
            return Decimal("0")
            
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
    try:
        print(f"Запуск проверки баланса Vana: {datetime.now()}")
        
        config = load_config()
        wallet = config.get("wallet_address")
        if not wallet:
            print("⚠️ Wallet address не задан в config.yaml")
            return

        print(f"Адрес кошелька из конфигурации: {wallet}")
        
        ip = os.popen("hostname -I | awk '{print $1}'").read().strip()
        node_name = get_node_name(ip, config.get("node_map", {}))
        bot_token = config["telegram"]["bot_token"]
        chat_id = config["telegram"]["chat_id"]

        print(f"Настройки: IP={ip}, Нода={node_name}, CHAT_ID={chat_id}")
        
        while True:
            try:
                print(f"Проверка времени последней проверки: {datetime.now()}")
                last = load_last_check()
                now = datetime.now()

                if last:
                    seconds_since_last = (now - last).total_seconds()
                    print(f"Последняя проверка: {last}, прошло {seconds_since_last} секунд из {CHECK_INTERVAL_HOURS * 3600} необходимых")
                else:
                    print("Первая проверка (предыдущих не было)")
                
                if not last or (now - last).total_seconds() >= CHECK_INTERVAL_HOURS * 3600:
                    print(f"Начинаем проверку баланса для {wallet}")
                    
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

                    print("Сохраняем время проверки")
                    save_last_check()
                else:
                    print(f"Еще не время для проверки, ждем {CHECK_INTERVAL_HOURS} часов с момента последней проверки")

                print(f"Ожидание 1 час до следующей проверки времени")
                await asyncio.sleep(3600)  # Проверка каждый час (вдруг сервер перезапущен)
            except Exception as e:
                print(f"Ошибка в основном цикле: {e}")
                await asyncio.sleep(3600)  # Ждем час и пробуем снова
    except Exception as e:
        print(f"Критическая ошибка в main: {e}")

if __name__ == "__main__":
    asyncio.run(main())