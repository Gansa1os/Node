#!/bin/bash

# 👉 По умолчанию — коммит "summary", можно задать свой
COMMIT_MESSAGE=${1:-summary}

echo "📦 Добавляю все файлы..."
git add .

echo "📝 Коммит с сообщением: $COMMIT_MESSAGE"
git commit -m "$COMMIT_MESSAGE"

echo "🚀 Отправляю в GitHub..."
git push

echo "✅ Готово!"
