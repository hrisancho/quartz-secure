#!/bin/bash

# Скрипт для настройки HTTPS с Let's Encrypt через Docker

# Проверка наличия домена
if [ -z "$1" ]; then
    echo "Ошибка: Не указано доменное имя."
    echo "Использование: $0 <домен> <email>"
    echo "Пример: $0 example.com admin@example.com"
    exit 1
fi

# Проверка наличия почты для администратора 
if [ -z "$2" ]; then
    echo "Ошибка: Не указан email администратора."
    echo "Использование: $0 <домен> <email>"
    echo "Пример: $0 example.com admin@example.com (email будет использоваться для уведомлений от Let's Encrypt)"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "Настройка HTTPS для домена $DOMAIN с email $EMAIL"

# Создать .env файл с доменом
echo "Создание .env файла с DOMAIN_NAME=$DOMAIN"
echo "DOMAIN_NAME=$DOMAIN" > .env
echo ".env файл создан успешно"

# Создание директорий для сертификатов
echo "Создание директорий ./letsencrypt и ./var-www-certbot..."
mkdir -p letsencrypt var-www-certbot

# Остановка контейнеров, если они запущены, чтобы освободить порт 80
echo "Попытка остановить существующие контейнеры (если запущены)..."
if command -v docker-compose &> /dev/null; then
    docker-compose down --remove-orphans -v
    docker system prune -af
else
    docker compose down --remove-orphans -v
    docker system prune -af
fi

# Получение сертификата через Docker
echo "Получение/обновление сертификата Let's Encrypt через Docker для домена $DOMAIN..."
echo "Используется email: $EMAIL"
docker run --rm -i -p 80:80 \
  -v "$(pwd)/letsencrypt:/etc/letsencrypt:rw" \
  -v "$(pwd)/var-www-certbot:/var/www/certbot:rw" \
  certbot/certbot certonly --standalone --force-renewal \
  --email "$EMAIL" --agree-tos --no-eff-email -d "$DOMAIN"

CERTBOT_EXIT_CODE=$?

# Проверка успешного получения сертификата
if [ $CERTBOT_EXIT_CODE -ne 0 ] || [ ! -f "letsencrypt/live/$DOMAIN/fullchain.pem" ]; then # Проверяем конкретный файл
    echo "---------------------------------------------------------------------"
    echo "ОШИБКА: Не удалось получить/обновить сертификат для домена $DOMAIN."
    echo "Код выхода Certbot: $CERTBOT_EXIT_CODE."
    if [ -f "letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "Файл letsencrypt/live/$DOMAIN/fullchain.pem существует, но код выхода Certbot был не 0."
    else
        echo "Файл letsencrypt/live/$DOMAIN/fullchain.pem НЕ существует."
    fi
    echo "Возможные причины:"
    echo "  - Неправильно указан домен или он не указывает на IP этого сервера."
    echo "  - Порт 80 занят другим процессом, который не удалось остановить."
    echo "  - Достигнуты лимиты на запросы сертификатов Let's Encrypt."
    echo "  - Проблемы с сетевым подключением или DNS."
    echo "Проверьте логи выше для получения детальной информации от Certbot."
    # Попытаемся показать логи, если есть
    if [ -d "$(pwd)/letsencrypt/logs" ]; then
        LATEST_LOG=$(ls -t "$(pwd)/letsencrypt/logs" | head -n 1)
        if [ ! -z "$LATEST_LOG" ]; then
            echo "Последние логи Certbot ($(pwd)/letsencrypt/logs/$LATEST_LOG):"
            cat "$(pwd)/letsencrypt/logs/$LATEST_LOG"
        fi
    fi
    echo "---------------------------------------------------------------------"
    exit 1
fi

echo "Сертификаты успешно получены/обновлены для домена $DOMAIN"
ls -la "$(pwd)/letsencrypt/live/$DOMAIN/"

# Проверяем, запущен ли контейнер
CONTAINER_RUNNING=false
if command -v docker-compose &> /dev/null; then
    if docker-compose ps -q webserver &> /dev/null; then
        CONTAINER_RUNNING=true
    fi
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    if docker compose ps -q webserver &> /dev/null; then
        CONTAINER_RUNNING=true
    fi
fi

if [ "$CONTAINER_RUNNING" = true ]; then
    echo "Контейнер уже запущен. Перезагрузка Nginx для применения новых сертификатов..."
    if command -v docker-compose &> /dev/null; then
        docker-compose exec webserver nginx -s reload
    else
        docker compose exec webserver nginx -s reload
    fi
    echo "Nginx перезагружен. Сертификаты должны быть применены."
else
    echo "Контейнер не запущен. Запуск контейнера с использованием .env файла..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d --build
    else
        docker compose up -d --build
    fi
    echo "Контейнер запущен с новыми сертификатами."
fi

# Настройка автоматического обновления сертификатов
echo "Настройка автоматического обновления сертификатов..."
RENEW_SCRIPT_PATH="$(pwd)/renew-cert.sh"
cat > "$RENEW_SCRIPT_PATH" << EOF
#!/bin/bash
# Скрипт для автоматического обновления SSL сертификатов Let's Encrypt

echo "-------------------------------------------------"
echo "Запуск скрипта обновления сертификатов: \$(date)"

# Переход в директорию проекта
PROJECT_DIR=\$(cd \$(dirname "\$0") && pwd)
cd "\$PROJECT_DIR" || exit 1

echo "Рабочая директория: \$PROJECT_DIR"

# Загружаем переменные окружения из .env файла
if [ -f .env ]; then
    export \$(cat .env | grep -v '^#' | xargs)
    echo "Загружен домен из .env: \$DOMAIN_NAME"
else
    echo "ОШИБКА: .env файл не найден!"
    exit 1
fi

# Обновление сертификата Let's Encrypt
echo "Обновление сертификата для домена \$DOMAIN_NAME..."
docker run --rm -p 80:80 \
  -v "\$PROJECT_DIR/letsencrypt:/etc/letsencrypt:rw" \
  -v "\$PROJECT_DIR/var-www-certbot:/var/www/certbot:rw" \
  certbot/certbot renew --quiet

RENEW_EXIT_CODE=\$?

if [ \$RENEW_EXIT_CODE -ne 0 ]; then
    echo "ОШИБКА при обновлении сертификата. Код выхода: \$RENEW_EXIT_CODE. Логи выше."
    exit 1
else
    echo "Сертификат успешно обновлен (или не требовал обновления)."
    
    # Перезагрузка Nginx в контейнере (если он запущен)
    if command -v docker-compose &> /dev/null && docker-compose ps -q webserver &> /dev/null; then
        echo "Перезагрузка Nginx в контейнере..."
        docker-compose exec -T webserver nginx -s reload
        echo "Nginx перезагружен."
    elif command -v docker &> /dev/null && docker compose ps -q webserver &> /dev/null; then
        echo "Перезагрузка Nginx в контейнере..."
        docker compose exec -T webserver nginx -s reload
        echo "Nginx перезагружен."
    else
        echo "Контейнер не запущен, перезагрузка Nginx не требуется."
    fi
fi

echo "Процесс обновления сертификата завершен: \$(date)"
echo "-------------------------------------------------"
EOF

chmod +x "$RENEW_SCRIPT_PATH"

# Добавление задачи в crontab для автоматического обновления
echo "Добавление задачи в crontab для автоматического обновления..."
CRON_JOB="0 2 * * * \"$RENEW_SCRIPT_PATH\" >> \"$RENEW_SCRIPT_PATH.log\" 2>&1"
(crontab -l 2>/dev/null | grep -Fv "$RENEW_SCRIPT_PATH" || true) | { cat; echo "$CRON_JOB"; } | crontab -

echo "Задача для cron добавлена/обновлена: $CRON_JOB"

echo "---------------------------------------------------------------------"
echo "НАСТРОЙКА HTTPS ЗАВЕРШЕНА УСПЕШНО для домена $DOMAIN!"
echo " "
echo "Для последующих запусков используйте команду (из корня проекта):"
echo "  docker-compose up -d --build"
echo "Домен будет автоматически загружен из .env файла"
echo " "