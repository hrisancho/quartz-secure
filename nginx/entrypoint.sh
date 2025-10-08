#!/bin/sh
set -e

# Путь к файлу сертификата
CERT_FILE="/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem"

# Директория для финального конфига
CONF_DIR="/etc/nginx/conf.d"
FINAL_CONF_FILE="${CONF_DIR}/default.conf"

echo ">> Запуск Nginx Entrypoint..."
echo ">> Проверка наличия сертификата для домена: ${DOMAIN_NAME}"

# Проверяем, существует ли файл сертификата
if [ -f "$CERT_FILE" ]; then
    echo ">> ✅ Сертификат найден. Активация HTTPS конфигурации."
    # Используем шаблон с HTTP и HTTPS
    TEMPLATE_FILE="/etc/nginx/templates/default.conf.template"
else
    echo ">> ⚠️ Сертификат НЕ найден. Активация конфигурации только для HTTP."
    echo ">> Для включения HTTPS, запустите скрипт https.sh и перезапустите контейнеры."
    # Используем шаблон только с HTTP
    TEMPLATE_FILE="/etc/nginx/templates/http-only.conf.template"
fi

# Подставляем переменные окружения (DOMAIN_NAME) в выбранный шаблон
# и создаем финальный конфигурационный файл для Nginx.
echo ">> Генерация файла конфигурации из шаблона: ${TEMPLATE_FILE}"
envsubst '$$DOMAIN_NAME' < "$TEMPLATE_FILE" > "$FINAL_CONF_FILE"

echo ">> Финальная конфигурация Nginx:"
cat "$FINAL_CONF_FILE"
echo "-------------------------------------"

# Запускаем команду, которая была передана в CMD (т.е. "nginx -g 'daemon off;'")
exec "$@"