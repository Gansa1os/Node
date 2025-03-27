#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOGFILE="/var/log/system_cleanup.log"
SCRIPT_PATH="/usr/local/bin/system_cleanup.sh"
SERVICE_FILE="/etc/systemd/system/system_cleanup.service"
TIMER_FILE="/etc/systemd/system/system_cleanup.timer"

function install_cleanup {
    echo -e "${YELLOW}📦 Установка автозапуска системной очистки...${NC}"

    # Копируем этот скрипт в постоянное место
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

    # Создаём systemd-сервис
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Daily System Cleanup Script
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH run
EOF

    # Создаём таймер
    cat << EOF > "$TIMER_FILE"
[Unit]
Description=Run daily system cleanup

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable --now system_cleanup.timer

    echo -e "${GREEN}✅ Установка завершена. Очистка будет запускаться каждый день в 03:00.${NC}"
}

function run_cleanup {
    echo -e "${YELLOW}🔧 Запуск системной очистки...$(date)${NC}" | tee -a "$LOGFILE"

    echo "[Docker] Удаление неиспользуемых контейнеров, образов и volume'ов..." | tee -a "$LOGFILE"
    docker system prune -a --volumes -f >> "$LOGFILE" 2>&1

    echo "[APT] Очистка кеша и неиспользуемых пакетов..." | tee -a "$LOGFILE"
    sudo apt clean >> "$LOGFILE" 2>&1
    sudo apt autoremove -y >> "$LOGFILE" 2>&1

    echo "[Snap] Удаление старых версий..." | tee -a "$LOGFILE"
    sudo snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision" >> "$LOGFILE" 2>&1; done

    echo "[TMP] Очистка /tmp и /var/tmp..." | tee -a "$LOGFILE"
    sudo rm -rf /tmp/* /var/tmp/* >> "$LOGFILE" 2>&1

    echo "[LOGS] Очистка журналов старше 3 дней..." | tee -a "$LOGFILE"
    sudo journalctl --vacuum-time=3d >> "$LOGFILE" 2>&1

    echo "[LOGS] Удаление .log-файлов старше 3 дней..." | tee -a "$LOGFILE"
    find /var/log -type f -name "*.log" -mtime +3 -exec rm -f {} \; >> "$LOGFILE" 2>&1

    echo -e "${GREEN}✅ Очистка завершена: $(date)${NC}" | tee -a "$LOGFILE"
}

function uninstall_cleanup {
    echo -e "${YELLOW}🗑 Удаление скрипта и сервисов очистки...${NC}"
    systemctl stop system_cleanup.timer
    systemctl disable system_cleanup.timer
    rm -f "$SERVICE_FILE" "$TIMER_FILE" "$SCRIPT_PATH"
    systemctl daemon-reexec
    systemctl daemon-reload
    echo -e "${GREEN}✅ Удалено. Очистка больше не будет выполняться.${NC}"
}

function main_menu {
    while true; do
        echo -e "\n${YELLOW}=== Меню управления системной очисткой ===${NC}"
        echo "1) Установить автоочистку (ежедневно в 03:00)"
        echo "2) Удалить автоочистку и все связанные файлы"
        echo "3) Выйти"
        read -p "Выберите действие: " choice
        case $choice in
            1) install_cleanup; exit 0;;
            2) uninstall_cleanup; exit 0;;
            3) exit 0;;
            run) run_cleanup; exit 0;;
            *) echo "Неверный выбор. Попробуйте снова.";;
        esac
    done
}

# Поддержка режима run (для systemd)
if [[ "$1" == "run" ]]; then
    run_cleanup
else
    main_menu
fi
