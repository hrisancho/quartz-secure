# Quartz Wiki Template

> **Публичный шаблон для создания корпоративной wiki на базе [Quartz v4](https://quartz.jzhao.xyz/)**

Этот репозиторий представляет собой готовое к развёртыванию решение для создания wiki-системы с использованием Docker, поддержкой HTTPS и автоматическим обновлением контента.

---

## 📋 Содержание

- [Возможности](#-возможности)
- [Быстрый старт](#-быстрый-старт)
- [Для разработчиков](#-для-разработчиков)
- [Развёртывание на сервере](#-развёртывание-на-сервере)
- [Автоматизация](#-автоматизация)
- [Управление контентом](#-управление-контентом)
- [Troubleshooting](#-troubleshooting)
- [Безопасность](#-безопасность)
- [Roadmap](#-roadmap)

---

## ✨ Возможности

- ✅ **Docker-based развёртывание** - нет необходимости устанавливать Node.js на сервер
- ✅ **Автоматическое HTTPS** - интеграция с Let's Encrypt
- ✅ **Автообновление контента** - синхронизация с GitHub через cron
- ✅ **Markdown-based** - простое создание контента
- ✅ **Zero-downtime updates** - обновления без простоя
- ✅ **Healthchecks** - автоматический мониторинг состояния

---

## 🚀 Быстрый старт

### Локальная разработка (без Docker)

Для редактирования контента локально вам нужен только текстовый редактор:

```bash
# Клонирование репозитория
git clone <your-repo-url> my-wiki
cd my-wiki

# Редактирование контента
cd content
# Создавайте и редактируйте .md файлы
```

### Локальная разработка (с Docker)

```bash
# Запуск локально
DOMAIN_NAME=localhost docker-compose up -d --build

# Сайт доступен по адресу http://localhost
```

---

## 👨‍💻 Для разработчиков

### Предварительные требования

- **Git**
- **Docker** и **Docker Compose**
- Текстовый редактор (VS Code, Vim, etc.)

### Структура проекта

```
.
├── content/              # Контент wiki (Markdown файлы)
├── quartz/              # Движок Quartz (не трогать без необходимости)
├── nginx/               # Конфигурация Nginx
│   ├── entrypoint.sh
│   ├── http-only.conf.template
│   └── default.conf.template
├── docker-compose.yml   # Docker Compose конфигурация
├── Dockerfile.app       # Dockerfile для Quartz приложения
├── Dockerfile.nginx     # Dockerfile для Nginx
└── https.sh             # Скрипт настройки HTTPS
```

### Работа с контентом

1. **Создание новой страницы:**
   ```bash
   cd content
   touch new-page.md
   ```

2. **Формат Markdown файла:**
   ```markdown
   ---
   title: Название страницы
   ---
   
   # Заголовок
   
   Ваш контент здесь...
   ```

3. **Коммит изменений:**
   ```bash
   git add content/
   git commit -m "Add new page"
   git push origin main
   ```

4. **Автоматическое обновление:** Если настроен cron (см. раздел "Автоматизация"), изменения появятся на сервере в течение минуты.

### GitHub Flow

Для крупных изменений используйте ветки:

```bash
# Создание новой ветки
git checkout -b feature/new-section

# Внесение изменений
# ...

# Коммит и push
git add .
git commit -m "Add new section"
git push origin feature/new-section

# Создайте Pull Request на GitHub
# После ревью и merge изменения автоматически попадут на сервер
```

---

## 🖥️ Развёртывание на сервере

### Предварительные требования

- **Сервер** с Ubuntu/Debian (минимум 1GB RAM, 1 CPU)
- **Доменное имя**, указывающее на IP сервера
- **Открытые порты:** 80, 443, 22 (SSH)

### Установка зависимостей

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
sudo apt install docker.io git -y

# Добавление текущего пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Включение Docker при старте системы
sudo systemctl enable docker.service
```

### Клонирование проекта

```bash
cd ~
git clone <your-repo-url> quartz-wiki
cd quartz-wiki
```

### Создание .env файла

```bash
# Скопировать шаблон
cp .env.example .env

# Отредактировать домен
nano .env
```

В файле `.env` замените `your.domain.com` на ваш реальный домен:
```bash
DOMAIN_NAME=my-awesome-wiki.com
```

### Создание необходимых директорий

```bash
mkdir -p letsencrypt var/logs
```

### Настройка HTTPS (Let's Encrypt)

**Важно:** Замените `your.domain.com` на ваш домен и `your@email.com` на ваш email.

```bash
chmod +x https.sh
./https.sh your.domain.com your@email.com
```

Скрипт автоматически:
1. Получит SSL сертификат от Let's Encrypt
2. Настроит автообновление сертификатов (каждую ночь в 2:00)
3. Запустит приложение с HTTPS

### Запуск приложения

```bash
# Если https.sh уже запустил приложение, пропустите этот шаг
# Иначе:
DOMAIN_NAME=your.domain.com docker-compose up -d --build
```

### Проверка

```bash
# Проверка статуса контейнеров
docker-compose ps

# Просмотр логов
docker-compose logs -f

# Ваш сайт должен быть доступен по адресу:
# https://your.domain.com
```

---

## ⚙️ Автоматизация

### Автообновление контента

Настройка автоматической синхронизации с GitHub:

```bash
# Сделать скрипт исполняемым
chmod +x quartz-update.sh

# Добавить задачу в crontab
crontab -e
```

Добавьте следующую строку (замените путь на ваш):

```cron
* * * * * cd /home/ubuntu/quartz-wiki && ./quartz-update.sh >> var/logs/quartz-update.log 2>&1
```

**Как это работает:**
- Каждую минуту проверяется наличие изменений в `content/` на GitHub
- При обнаружении изменений автоматически выполняется `git merge` и `docker-compose up -d --build`
- Домен автоматически загружается из `.env` файла
- Лог сохраняется в `var/logs/quartz-update.log`

### Автоматическая очистка Docker

Для предотвращения переполнения диска:

```bash
# Сделать скрипт исполняемым
chmod +x docker-cleanup.sh

# Добавить задачу в crontab
crontab -e
```

Добавьте следующую строку:

```cron
0 */6 * * * cd /home/ubuntu/quartz-wiki && ./docker-cleanup.sh >> var/logs/docker-cleanup.log 2>&1
```

**Что очищается (каждые 6 часов):**
- Остановленные контейнеры
- Неиспользуемые образы
- Неиспользуемые volumes
- Неиспользуемые сети

---

## 📝 Управление контентом

### Добавление новых страниц

1. Клонируйте репозиторий локально
2. Создайте `.md` файл в директории `content/`
3. Напишите контент в формате Markdown
4. Закоммитьте и запушьте изменения
5. Сервер автоматически обновится (если настроен cron)

### Структура контента

```
content/
├── index.md           # Главная страница
├── docs/              # Документация
│   ├── getting-started.md
│   └── api.md
└── projects/          # Проекты
    └── project-1.md
```

### Полезные ссылки

- [Markdown Guide](https://www.markdownguide.org/)
- [Quartz Documentation](https://quartz.jzhao.xyz/)

---

## 🔧 Troubleshooting

### Проблема: Контейнер quartz-app не запускается

**Симптомы:**
```
dependency failed to start: container quartz-app is unhealthy
```

**Решение:**
1. Проверьте логи:
   ```bash
   docker logs quartz-app
   ```

2. Увеличьте таймауты healthcheck в `docker-compose.yml`:
   ```yaml
   healthcheck:
     start_period: 120s  # Увеличьте с 60s
   ```

3. Проверьте доступность приложения:
   ```bash
   docker exec quartz-app curl -f http://localhost:8080/
   ```

### Проблема: Сайт недоступен по http://localhost

**Симптомы:**
- Браузер не открывает страницу
- "Connection refused" или "ERR_CONNECTION_REFUSED"

**Решение:**
1. Проверьте, запущены ли контейнеры:
   ```bash
   docker-compose ps
   ```

2. Проверьте логи Nginx:
   ```bash
   docker logs quartz-nginx
   ```

3. Проверьте конфигурацию Nginx:
   ```bash
   docker exec quartz-nginx cat /etc/nginx/conf.d/default.conf
   ```

4. Проверьте доступность app из nginx:
   ```bash
   docker exec quartz-nginx curl http://app:8080/
   ```

### Проблема: HTTPS не работает

**Симптомы:**
- "Your connection is not private"
- Сертификат не найден

**Решение:**
1. Проверьте наличие сертификата:
   ```bash
   ls -la letsencrypt/live/your.domain.com/
   ```

2. Перезапустите получение сертификата:
   ```bash
   ./https.sh your.domain.com your@email.com
   ```

3. Убедитесь, что домен указывает на ваш сервер:
   ```bash
   nslookup your.domain.com
   ```

### Проблема: Автообновление не работает

**Симптомы:**
- Изменения на GitHub не появляются на сайте

**Решение:**
1. Проверьте логи автообновления:
   ```bash
   tail -f var/logs/quartz-update.log
   ```

2. Проверьте crontab:
   ```bash
   crontab -l
   ```

3. Проверьте права на скрипт:
   ```bash
   chmod +x quartz-update.sh
   ```

4. Запустите скрипт вручную для проверки:
   ```bash
   DOMAIN_NAME=your.domain.com ./quartz-update.sh
   ```

### Проблема: Диск переполнен

**Симптомы:**
- "No space left on device"

**Решение:**
1. Проверьте использование диска:
   ```bash
   df -h
   ```

2. Очистите Docker:
   ```bash
   ./docker-cleanup.sh
   ```

3. Удалите старые логи:
   ```bash
   truncate -s 0 var/logs/*.log
   ```

---

## 🔒 Безопасность

### Базовая настройка Firewall (UFW)

```bash
# Установка UFW (если не установлен)
sudo apt install ufw -y

# Разрешить необходимые порты
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Включить firewall
sudo ufw enable

# Проверить статус
sudo ufw status
```

### Дополнительные рекомендации

1. **Регулярное обновление:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Мониторинг логов:**
   ```bash
   # Логи Nginx
   docker exec quartz-nginx tail -f /var/log/nginx/access.log
   
   # Логи приложения
   docker logs -f quartz-app
   ```

3. **Backup контента:**
   ```bash
   # Создать backup
   tar -czf wiki-backup-$(date +%Y%m%d).tar.gz content/
   
   # Восстановить из backup
   tar -xzf wiki-backup-20240101.tar.gz
   ```

### Планируемые улучшения безопасности

- [ ] Авторизация пользователей (JWT)
- [ ] Админ-панель для управления пользователями
- [ ] Rate limiting в Nginx
- [ ] Fail2Ban для защиты от brute-force

---

## 🗺️ Roadmap

### Текущая версия (v1.0)
- [x] Docker-based развёртывание
- [x] HTTPS поддержка
- [x] Автообновление контента
- [x] Healthchecks

### Планируется (v2.0)
- [ ] Авторизация пользователей (JWT токены)
- [ ] Админ-панель для управления:
  - [ ] Создание/удаление пользователей
  - [ ] Управление правами доступа
  - [ ] Просмотр статистики
- [ ] Share функционал (цепочки статей)
- [ ] Комментарии к статьям
- [ ] Версионирование контента
- [ ] Поиск по контенту
- [ ] Мониторинг (Prometheus + Grafana)

### Будущее (v3.0+)
- [ ] Multi-tenancy (несколько wiki на одном сервере)
- [ ] API для интеграций
- [ ] Webhooks для уведомлений
- [ ] Экспорт в PDF/EPUB

---

## 🤝 Contribution

Этот проект является форком Quartz v4. Для внесения вклада:

1. Форкните репозиторий
2. Создайте ветку для ваших изменений
3. Внесите изменения
4. Создайте Pull Request

### Обновление из upstream (Quartz v4)

Этот репозиторий поддерживает синхронизацию с оригинальным Quartz v4:

```bash
# Добавить upstream (один раз)
git remote add upstream https://github.com/jackyzha0/quartz.git

# Получить последние изменения
git fetch upstream

# Влить изменения в main
git checkout main
git merge upstream/v4

# Разрешить конфликты (если есть)
# ...

# Запушить обновления
git push origin main
```

---

## 📄 Лицензия

Этот проект лицензирован под [MIT License](LICENSE.txt).

Quartz v4 лицензирован под MIT License © [jackyzha0](https://github.com/jackyzha0).


---

**Создано на базе [Quartz v4](https://quartz.jzhao.xyz/) by [jackyzha0](https://github.com/jackyzha0)**