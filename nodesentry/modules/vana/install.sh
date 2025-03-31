#!/bin/bash

set -e

MODULE="vana"
ROOT_DIR="/root/nodesentry"
MODULE_DIR="$ROOT_DIR/modules/$MODULE"
CONFIG_FILE="$ROOT_DIR/config.yaml"
TEMPLATE_FILE="$ROOT_DIR/nodesentry.service.template"

SERVICE_MONITOR="/etc/systemd/system/nodesentry-$MODULE.service"
SERVICE_BALANCE="/etc/systemd/system/nodesentry-balance-$MODULE.service"

__install_vana() {
  echo "📦 Установка модуля: vana"
  ...
}
# === Проверка наличия wallet_address ===
if ! grep -q "wallet_address:" "$CONFIG_FILE"; then
  echo ""
  read -p "Введите адрес Hotkey (wallet_address): " WALLET_ADDRESS
  echo "wallet_address: \"$WALLET_ADDRESS\"" >> "$CONFIG_FILE"
  echo "✅ Адрес добавлен в config.yaml"
fi

# === Создание сервиса для логов ===
echo "⚙️ Создаём systemd-сервис: $SERVICE_MONITOR"
sed "s|{{MODULE_NAME}}|$MODULE|g; s|{{FILENAME}}|vana_monitor.py|g" \
  "$TEMPLATE_FILE" > "$SERVICE_MONITOR"

# === Создание сервиса для баланса ===
echo "⚙️ Создаём systemd-сервис: $SERVICE_BALANCE"
cat <<EOF > "$SERVICE_BALANCE"
[Unit]
Description=NodeSentry Balance Monitor: $MODULE
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $MODULE_DIR/vana_balance_checker.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# === Активация сервисов ===
echo "🚀 Активируем сервисы..."
systemctl daemon-reload
systemctl enable "nodesentry-$MODULE.service"
systemctl restart "nodesentry-$MODULE.service"
systemctl enable "nodesentry-balance-$MODULE.service"
systemctl restart "nodesentry-balance-$MODULE.service"

echo "✅ Модуль $MODULE и баланс-чекер установлены и запущены!"