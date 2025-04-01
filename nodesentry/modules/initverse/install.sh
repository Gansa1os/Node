#!/bin/bash

set -e

MODULE="initverse"
ROOT_DIR="/root/nodesentry"
MODULE_DIR="$ROOT_DIR/modules/$MODULE"
CONFIG_FILE="$ROOT_DIR/config.yaml"
TEMPLATE_FILE="$ROOT_DIR/nodesentry.service.template"

SERVICE_MONITOR="/etc/systemd/system/nodesentry-$MODULE.service"

__install_initverse() {
  echo "📦 Установка модуля: initverse"
  
  # Создаем директорию модуля
  mkdir -p "$MODULE_DIR"
  
  # Скачиваем файл монитора
  curl -sSf -o "$MODULE_DIR/initverse_monitor.py" "https://raw.githubusercontent.com/Gansa1os/Node/main/nodesentry/modules/initverse/initverse_monitor.py"
  chmod +x "$MODULE_DIR/initverse_monitor.py"
}

# Вызываем функцию установки
__install_initverse

# === Создание systemd-сервиса ===
echo "⚙️ Создаём systemd-сервис: $SERVICE_MONITOR"
sed "s|{{MODULE_NAME}}|$MODULE|g; s|{{FILENAME}}|initverse_monitor.py|g" \
  "$TEMPLATE_FILE" > "$SERVICE_MONITOR"

# === Активация сервиса ===
echo "🚀 Активируем сервис..."
systemctl daemon-reload
systemctl enable "nodesentry-$MODULE.service"
systemctl restart "nodesentry-$MODULE.service"

echo "✅ Модуль $MODULE установлен и запущен!"