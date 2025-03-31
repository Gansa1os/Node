#!/bin/bash

set -e

# === Цвета ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Пути ===
ROOT_DIR="/root/nodesentry"
TEMPLATE_FILE="$ROOT_DIR/nodesentry.service.template"
CONFIG_FILE="$ROOT_DIR/config.yaml"
MODULES_DIR="$ROOT_DIR/modules"

mkdir -p "$MODULES_DIR"

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
  echo -e "\n${BLUE}ℹ️ Бот уже создан: используем общего бота @NodeSentry_bot${NC}"
  echo -e "${YELLOW}📥 Чтобы получать уведомления:${NC}"
  echo -e " - Найдите и откройте в Telegram: ${GREEN}@NodeSentry_bot${NC}"
  echo -e " - Нажмите кнопку ${GREEN}Start${NC}"
  echo -e "\n${YELLOW}🔎 Как узнать ваш CHAT_ID:${NC}"
  echo -e " - Перешлите любое сообщение боту: ${GREEN}@getidsbot${NC}"
  echo -e " - Он ответит вам вашим CHAT_ID"
  echo ""
  read -p "Введите ваш CHAT_ID: " CHAT_ID

  cat <<EOF > "$CONFIG_FILE"
telegram:
  bot_token: "$BOT_TOKEN"
  chat_id: "$CHAT_ID"

node_map:
  "37.46.23.83": "Нода_1"
  "185.183.247.56": "Нода_2"
  "62.171.145.237": "Нода_8"
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
ExecStart=/usr/bin/python3 /root/nodesentry/modules/{{MODULE_NAME}}/{{FILENAME}}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo -e "${GREEN}Создан шаблон $TEMPLATE_FILE${NC}"
fi

# === Удаление модуля ===
remove_selected_module() {
  MODULE="$1"
  SERVICE1="nodesentry-$MODULE.service"
  SERVICE2="nodesentry-balance-$MODULE.service"
  MODULE_DIR="$MODULES_DIR/$MODULE"
  SERVICE_PATH1="/etc/systemd/system/$SERVICE1"
  SERVICE_PATH2="/etc/systemd/system/$SERVICE2"

  echo -e "${BLUE}Удаляем: $MODULE${NC}"

  systemctl stop "$SERVICE1" 2>/dev/null || true
  systemctl disable "$SERVICE1" 2>/dev/null || true
  [ -f "$SERVICE_PATH1" ] && rm -f "$SERVICE_PATH1" && echo "Удалён: $SERVICE_PATH1"

  systemctl stop "$SERVICE2" 2>/dev/null || true
  systemctl disable "$SERVICE2" 2>/dev/null || true
  [ -f "$SERVICE_PATH2" ] && rm -f "$SERVICE_PATH2" && echo "Удалён: $SERVICE_PATH2"

  [ -d "$MODULE_DIR" ] && rm -rf "$MODULE_DIR" && echo "Удалена папка: $MODULE_DIR"

  systemctl daemon-reload
  echo -e "${GREEN}Модуль $MODULE полностью удалён.${NC}"
}

remove_module_menu() {
  echo -e "\n${YELLOW}Удаление модуля мониторинга${NC}"

  MODULES=()
  for d in "$MODULES_DIR"/*/; do
    MODULE=$(basename "$d")
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

# === Установка initverse ===
install_initverse() {
  INSTALLER_URL="https://raw.githubusercontent.com/Gansa1os/Node/main/nodesentry/modules/initverse/install.sh"
  INSTALLER_PATH="/tmp/initverse_install.sh"

  curl -sSf -o "$INSTALLER_PATH" "$INSTALLER_URL" || {
    echo -e "${RED}Не удалось скачать install.sh для initverse.${NC}"
    exit 1
  }

  source "$INSTALLER_PATH"
  install_initverse
}

# === Установка vana ===
install_vana() {
  INSTALLER_URL="https://raw.githubusercontent.com/Gansa1os/Node/main/nodesentry/modules/vana/install.sh"
  INSTALLER_PATH="/tmp/vana_install.sh"

  curl -sSf -o "$INSTALLER_PATH" "$INSTALLER_URL" || {
    echo -e "${RED}Не удалось скачать install.sh для vana.${NC}"
    exit 1
  }

  source "$INSTALLER_PATH"
  install_vana
}

# === Главное меню ===
while true; do
  echo ""
  echo -e "${BLUE}NodeSentry — главное меню${NC}"
  echo "1) Установить мониторинг initverse"
  echo "2) Установить мониторинг vana"
  echo "3) Удалить модуль мониторинга"
  echo "0) Выход"
  read -p "Выберите опцию (цифрой): " choice

  case $choice in
    1) install_initverse ;;
    2) install_vana ;;
    3) remove_module_menu ;;
    0) echo -e "${YELLOW}Выход...${NC}"; exit 0 ;;
    *) echo -e "${RED}Неверный выбор${NC}" ;;
  esac
done