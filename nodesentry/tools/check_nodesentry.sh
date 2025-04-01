#!/bin/bash

# Инициализация ассоциативного массива для группировки по модулям
declare -A group

while read -r svc; do
  status=$(systemctl is-active "$svc")
  mod=$(echo "$svc" | sed 's/^nodesentry-\(balance-\)\?\(.*\)\.service$/\2/')
  type=$(echo "$svc" | grep -q balance && echo "balance" || echo "main")

  # Цвет статуса
  if [ "$status" = "active" ]; then
    color="\033[0;32m"
  elif [ "$status" = "failed" ]; then
    color="\033[0;31m"
  else
    color="\033[1;33m"
  fi

  key="🧩 $mod"
  line="  $(printf '%-8s' "$type"): $(printf '%-40s' "$svc")  ${color}${status}\033[0m"

  group["$key"]+="${line}\n"
done < <(systemctl list-units --type=service | grep nodesentry | awk '{print $1}')

# Печать
for key in "${!group[@]}"; do
  echo -e "$key:\n${group[$key]}"
done

# Проверка наличия сервисов
if [ ${#group[@]} -eq 0 ]; then
  echo -e "\033[1;33mНет запущенных сервисов NodeSentry.\033[0m"
fi

echo -e "\nДля просмотра логов используйте: journalctl -u <имя_сервиса> -f"