#!/bin/bash

set -e

# === Цвета ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Основные пути ===
ROOT_DIR="/root/nodesentry"
MONITOR_DIR="$ROOT_DIR/monitors"
TEMPLATE_FILE="$ROOT_DIR/nodesentry.service.template"
CONFIG_FILE="$ROOT_DIR/config.yaml"

mkdir -p "$MONITOR_DIR"

# === Проверка зависимостей ===
echo -e "${BLUE}Проверка зависимостей...${NC}"

check_dep() {
  command -v "$1" >/dev/null 2>&1 && echo -e "[${GREEN}✔${NC}] $1" || {
    echo -e "[${RED}✘${NC}] $1 не установлен"
    MISSING=true
  }
}

MISSING=false
check_dep python3
check_dep pip3

if ! python3 -c "import requests" 2>/dev/null; then
  echo -e "[${RED}✘${NC}] Модуль Python 'requests' не установлен"
  MISSING=true
fi

if ! python3 -c "import yaml" 2>/dev/null; then
  echo -e "[${RED}✘${NC}] Модуль Python 'pyyaml' не установлен"
  MISSING=true
fi

if [ "$MISSING" = true ]; then
  echo -e "${RED}Пожалуйста, установите недостающие зависимости и запустите снова.${NC}"
  exit 1
else
  echo -e "${GREEN}Все зависимости на месте.${NC}"
fi

# === config.yaml ===
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${YELLOW}Ввод Telegram CHAT_ID (BOT_TOKEN уже задан):${NC}"
  BOT_TOKEN="7243235590:AAGc3MkrJtOW8O7EiMJlOcSGI3-4tS9Hzdc"
  echo -e "
${BLUE}ℹ️ Бот уже создан: используем общего бота @NodeSentry_bot${NC}"
echo -e "${YELLOW}📥 Чтобы получать уведомления:${NC}"
echo -e " - Найдите и откройте в Telegram: ${GREEN}@NodeSentry_bot${NC}"
echo -e " - Нажмите кнопку ${GREEN}Start${NC}"
echo -e "
${YELLOW}🔎 Как узнать ваш CHAT_ID:${NC}"
echo -e " - Перешлите любое сообщение боту: ${GREEN}@getidsbot${NC}"
echo -e " - Он ответит вам вашим CHAT_ID"
echo ""
read -p "Введите ваш CHAT_ID: " CHAT_ID

  cat <<EOF > "$CONFIG_FILE"
telegram:
  bot_token: "$BOT_TOKEN"
  chat_id: "$CHAT_ID"

node_map:
  "192.168.1.100": "Нода_1"
  "192.168.1.101": "Нода_2"
  "192.168.1.102": "Нода_3"
EOF
  echo -e "${GREEN}Файл config.yaml создан в $CONFIG_FILE${NC}"
fi

# === Шаблон systemd ===
if [ ! -f "$TEMPLATE_FILE" ]; then
  cat <<EOF > "$TEMPLATE_FILE"
[Unit]
Description=NodeSentry Monitor: {{MODULE_NAME}}
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /root/nodesentry/monitors/{{FILENAME}}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo -e "${GREEN}Создан шаблон $TEMPLATE_FILE${NC}"
fi

# === Установка initverse ===
install_initverse_monitor() {
  MODULE="initverse"
  FILE="$MONITOR_DIR/initverse_monitor.py"
  RAW_URL="https://raw.githubusercontent.com/Gansa1os/Node/main/nodesentry/monitors/initverse_monitor.py"
  SERVICE_FILE="/etc/systemd/system/nodesentry-$MODULE.service"

  echo -e "${BLUE}Скачиваем монитор $MODULE...${NC}"
  curl -sSf -o "$FILE" "$RAW_URL" || {
    echo -e "${RED}Не удалось скачать $MODULE. Проверь ссылку.${NC}"
    exit 1
  }

  echo -e "${BLUE}Создаём systemd-сервис...${NC}"
  sed "s|{{MODULE_NAME}}|$MODULE|g; s|{{FILENAME}}|${MODULE}_monitor.py|g" \
    "$TEMPLATE_FILE" > "$SERVICE_FILE"

  echo -e "${BLUE}Активируем сервис...${NC}"
  systemctl daemon-reload
  systemctl enable "nodesentry-$MODULE.service"
  systemctl restart "nodesentry-$MODULE.service"

  echo -e "${GREEN}Модуль $MODULE установлен и запущен!${NC}"
}

# === Удаление модулей ===
remove_module_menu() {
  echo -e "\n${YELLOW}Удаление модуля мониторинга${NC}"

  MODULES=()
  for f in "$MONITOR_DIR"/*_monitor.py; do
    [ -e "$f" ] || continue
    MODULE=$(basename "$f" _monitor.py)
    MODULES+=("$MODULE")
  done

  if [ ${#MODULES[@]} -eq 0 ]; then
    echo -e "${RED}Нет установленных модулей.${NC}"
    return
  fi

  echo "Выберите модуль для удаления:"
  select MODULE in "${MODULES[@]}" "Отмена"; do
    case "$REPLY" in
      ''|*[!0-9]*) echo "Нужно ввести число." ;;
      *)
        if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le ${#MODULES[@]} ]; then
          remove_selected_module "$MODULE"
          break
        elif [ "$REPLY" -eq $(( ${#MODULES[@]} + 1 )) ]; then
          echo "Отмена."
          break
        else
          echo "Неверный выбор."
        fi
        ;;
    esac
  done
}

remove_selected_module() {
  MODULE="$1"
  SERVICE="nodesentry-$MODULE.service"
  FILE="$MONITOR_DIR/${MODULE}_monitor.py"
  SERVICE_PATH="/etc/systemd/system/$SERVICE"

  echo -e "${BLUE}Удаляем: $MODULE${NC}"

  systemctl stop "$SERVICE" 2>/dev/null || true
  systemctl disable "$SERVICE" 2>/dev/null || true
  [ -f "$SERVICE_PATH" ] && rm -f "$SERVICE_PATH" && echo "Удалён: $SERVICE_PATH"
  [ -f "$FILE" ] && rm -f "$FILE" && echo "Удалён: $FILE"

  systemctl daemon-reload
  echo -e "${GREEN}Модуль $MODULE удалён.${NC}"
}

# === Главное меню ===
while true; do
  echo ""
  echo -e "${BLUE}NodeSentry — главное меню${NC}"
  echo "1) Установить мониторинг initverse"
  echo "2) Удалить модуль мониторинга"
  echo "0) Выход"
  read -p "Выберите опцию (цифрой): " choice

  case $choice in
    1) install_initverse_monitor ;;
    2) remove_module_menu ;;
    0) echo -e "${YELLOW}Выход...${NC}"; exit 0 ;;
    *) echo -e "${RED}Неверный выбор${NC}" ;;
  esac

done
