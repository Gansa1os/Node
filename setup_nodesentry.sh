#!/bin/bash

# Цвета ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Сброс цвета

# Конфигурация
INSTALL_DIR="/root/nodesentry"
MONITORS_DIR="$INSTALL_DIR/monitors"
BOT_TOKEN="7243235590:AAGc3MkrJtOW8O7EiMJlOcSGI3-4tS9Hzdc"
CHAT_ID="479750930"
LOG_PATH="/root/.hyperlane/logs/latest.log"

function install_hyperlane() {
  echo -e "${CYAN}\n=========================="
  echo -e "\xF0\x9F\x9A\xA6 Установка Hyperlane Monitor${NC}"
  echo -e "${CYAN}==========================${NC}"

  mkdir -p "$MONITORS_DIR"

  cat > "$MONITORS_DIR/hyperlane_monitor.py" << EOF
import requests
import time
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
\xf0\x9f\x9a\xa8 <b>NodeSentry: ошибка в логах</b>

\xf0\x9f\xa7\xa9 <b>Источник:</b> <code>{node_name}</code>
\xf0\x9f\x95\x93 <b>Время:</b> <i>{now}</i>

\xf0\x9f\x93\x84 <b>Сообщение:</b>
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
        f.seek(0, 2)
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

  cat > /etc/systemd/system/nodesentry-hyperlane.service << EOF
[Unit]
Description=NodeSentry Hyperlane Monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 $MONITORS_DIR/hyperlane_monitor.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable nodesentry-hyperlane.service
  systemctl restart nodesentry-hyperlane.service

  echo -e "\n${GREEN}✅ Мониторинг Hyperlane успешно установлен и запущен.${NC}"
}

function uninstall_all() {
  echo -e "${RED}\n=========================="
  echo -e "\xF0\x9F\xA7\xA9 Удаление NodeSentry${NC}"
  echo -e "${RED}==========================${NC}"

  systemctl stop nodesentry-hyperlane.service 2>/dev/null
  systemctl disable nodesentry-hyperlane.service 2>/dev/null
  rm -f /etc/systemd/system/nodesentry-hyperlane.service
  rm -rf "$INSTALL_DIR"
  rm -rf /root/__pycache__

  systemctl daemon-reload
  echo -e "${GREEN}✅ NodeSentry полностью удалён.${NC}\n"
}

function main_menu() {
  while true; do
    echo -e "${PURPLE}=============================${NC}"
    echo -e "${YELLOW} 🚀 Установщик NodeSentry${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo -e "\n  1) 🛠 Установить мониторинг Hyperlane"
    echo -e "  2) 🧹 Удалить всё"
    echo -e "  3) ❌ Выйти"
    echo -ne "\n👉 ${CYAN}Выберите действие: ${NC}"
    read choice

    case $choice in
      1) install_hyperlane ;;
      2) uninstall_all ;;
      3) echo -e "${GREEN}👋 До свидания!${NC}"; exit 0 ;;
      *) echo -e "${RED}❗ Неверный выбор. Введите 1, 2 или 3.${NC}" ;;
    esac

    echo -e "\n${PURPLE}-------------------------------------------${NC}"
    echo -e "${GREEN}NodeSentry — защита твоих нод в Telegram${NC}"
    echo -e "${CYAN}t.me/cryptoforto${NC}"
    echo -e "${PURPLE}-------------------------------------------${NC}"
    echo -e "Нажмите Enter для продолжения..."
    read
    clear
  done
}

main_menu
