#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MONITOR_SCRIPT="/root/vana_monitor.sh"
SERVICE_FILE="/etc/systemd/system/vana_monitor.service"
LOGFILE="/var/log/vana_monitor.log"
CHECK_INTERVAL=300

function install_monitor {
    echo -e "${YELLOW}📦 Установка мониторинга vana.service...${NC}"

    # Создаём скрипт мониторинга
    cat << EOF > "$MONITOR_SCRIPT"
#!/bin/bash
ERROR_PATTERNS=("ERROR" "RuntimeError" "Traceback" "exception")
while true; do
    echo "Проверка логов vana.service на ошибки..."
    LOGS=\$(journalctl -u vana.service --since "5 minutes ago" -n 50)
    ERROR_FOUND=false
    for PATTERN in "\${ERROR_PATTERNS[@]}"; do
        if echo "\$LOGS" | grep -i "\$PATTERN" > /dev/null; then
            echo "Найдена ошибка: \$PATTERN"
            ERROR_FOUND=true
            break
        fi
    done
    if [ "\$ERROR_FOUND" = true ]; then
        echo "Обнаружены ошибки в логах. Перезапуск vana.service..."
        systemctl restart vana.service
        if [ \$? -eq 0 ]; then
            echo "Служба успешно перезапущена. Ждём 30 секунд..."
            sleep 30
        else
            echo "Ошибка при перезапуске vana.service"
        fi
    else
        echo "Ошибок не найдено. Всё нормально."
    fi
    echo "Следующая проверка через $CHECK_INTERVAL секунд..."
    sleep $CHECK_INTERVAL
done
EOF

    chmod +x "$MONITOR_SCRIPT"

    # Создаём systemd-сервис
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Vana Service Monitor and Restart
After=network.target

[Service]
ExecStart=/bin/bash $MONITOR_SCRIPT
Restart=always
RestartSec=15
StandardOutput=append:$LOGFILE
StandardError=append:$LOGFILE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now vana_monitor.service

    echo -e "${GREEN}✅ Мониторинг запущен. Проверка каждые $CHECK_INTERVAL секунд.${NC}"
}

function uninstall_monitor {
    echo -e "${YELLOW}🗑 Удаление мониторинга vana.service...${NC}"
    systemctl stop vana_monitor.service
    systemctl disable vana_monitor.service
    rm -f "$SERVICE_FILE" "$MONITOR_SCRIPT"
    systemctl daemon-reload
    echo -e "${GREEN}✅ Мониторинг отключён и удалён.${NC}"
}

function main_menu {
    while true; do
        echo -e "\n${YELLOW}=== Меню управления мониторингом VANA ===${NC}"
        echo "1) Установить и запустить мониторинг"
        echo "2) Удалить мониторинг и файлы"
        echo "3) Выйти"
        read -p "Выберите действие: " choice
        case $choice in
            1) install_monitor; exit 0;;
            2) uninstall_monitor; exit 0;;
            3) exit 0;;
            *) echo "Неверный выбор. Попробуйте снова.";;
        esac
    done
}

main_menu
