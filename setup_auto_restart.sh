#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Установка авто-ресуректа и авто-очистки логов...${NC}"

# Создаём auto_restart.sh
cat << 'EOF' > /root/auto_restart.sh
#!/bin/bash

LOGFILE="/var/log/docker_auto_restart.log"

# --- ОЧИСТКА ЛОГОВ ---
# Очистка системных логов (systemd)
journalctl --vacuum-time=3d

# Удаление всех .log файлов в /var/log старше 3 дней
find /var/log -type f -name "*.log" -mtime +3 -exec rm -f {} \;

# --- ПЕРЕЗАПУСК КОНТЕЙНЕРОВ ---
while true; do
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') Проверка Exited-контейнеров ===" | tee -a "$LOGFILE"

    stopped_containers=$(docker ps -aq -f status=exited)

    if [ -z "$stopped_containers" ]; then
        echo "Нет остановленных контейнеров." | tee -a "$LOGFILE"
    else
        for id in $stopped_containers; do
            name=$(docker inspect --format='{{.Name}}' "$id" | sed 's|/||')
            echo "🔁 Перезапуск контейнера [$name] ($id)" | tee -a "$LOGFILE"

            docker start "$id" >> "$LOGFILE" 2>&1
            sleep 3

            status=$(docker inspect -f '{{.State.Status}}' "$id")
            if [[ "$status" == "running" ]]; then
                echo "✅ Контейнер [$name] запущен." | tee -a "$LOGFILE"
            else
                echo "⚠️ Контейнер [$name] всё ещё не работает." | tee -a "$LOGFILE"
            fi
        done
    fi

    echo "Следующая проверка через 5 минут..."
    echo "" >> "$LOGFILE"
    sleep 300
done
EOF

chmod +x /root/auto_restart.sh
echo -e "${GREEN}✅ Скрипт /root/auto_restart.sh создан и активен.${NC}"

# Создаём systemd-сервис
cat << EOF > /etc/systemd/system/auto_restart.service
[Unit]
Description=Auto Restart Docker Containers + Log Cleanup
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/bin/bash /root/auto_restart.sh
Restart=always
RestartSec=10
StandardOutput=append:/var/log/docker_auto_restart.log
StandardError=append:/var/log/docker_auto_restart.log

[Install]
WantedBy=multi-user.target
EOF

# Активируем сервис
systemctl daemon-reload
systemctl enable auto_restart.service
systemctl restart auto_restart.service

echo -e "${GREEN}✅ Сервис auto_restart.service перезапущен и включен в автозагрузку.${NC}"
echo -e "${GREEN}📄 Логи скрипта: /var/log/docker_auto_restart.log${NC}"
