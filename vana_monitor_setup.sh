cat > vana_monitor_setup.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/nodesentry_setup.log"
MONITOR_LOG="/var/log/nodesentry_monitor.log"
PY_SCRIPT="/root/node_monitor.py"
SERVICE_FILE="/etc/systemd/system/nodesentry.service"
LOG_PATH="/root/.hyperlane/logs/latest.log"
BOT_TOKEN="7243235590:AAGc3MkrJtOW8O7EiMJlOcSGI3-4tS9Hzdc"
CHAT_ID="479750930"

exec &> >(tee -a "$LOG_FILE")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "🔧 Установка зависимостей"
apt update && apt install -y python3 python3-pip
pip3 install requests

log "📄 Создание скрипта мониторинга"
cat > "$PY_SCRIPT" << PYEOF
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

KEYWORDS = ["ERROR", "panic", "fail", "unreachable"]

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
🚨 <b>NodeSentry: ошибка в логах</b>

🧩 <b>Источник:</b> <code>{node_name}</code>
🕓 <b>Время:</b> <i>{now}</i>

📄 <b>Сообщение:</b>
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
    except Exception as e:
        print("Ошибка отправки:", e)

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
            if any(k in line for k in KEYWORDS):
                msg = format_message(line, node_name)
                send_alert(msg)
                with open("${MONITOR_LOG}", "a") as logf:
                    logf.write(f"[{datetime.now()}] {node_name} => {line}")

if __name__ == "__main__":
    monitor()
PYEOF

log "🛠 Создание systemd-сервиса"
cat > "$SERVICE_FILE" << EOF2
[Unit]
Description=NodeSentry Monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 $PY_SCRIPT
Restart=always
RestartSec=5
StandardOutput=append:$MONITOR_LOG
StandardError=append:$MONITOR_LOG

[Install]
WantedBy=multi-user.target
EOF2

log "🚀 Активация systemd-сервиса"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable nodesentry.service
systemctl restart nodesentry.service

log "✅ Установка завершена. NodeSentry работает как сервис."
EOF
