# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объём памяти: 2048 МБ
- Количество ядер: 2
- Объём диска: 25 ГБ (динамически расширяемый)

## 2. Сетевые интерфейсы
- Адаптер 1 (NAT): 10.0.2.15 — доступ в интернет
- Адаптер 2 (Host-only): 192.168.56.101 — доступ с хоста

## 3. Правило проброса портов
- Порт хоста: 2222
- Порт гостя: 2222

## 4. Учётные записи
- student — администратор (sudo), пароль
- devops — администратор (sudo), аутентификация по SSH-ключу

## 5. Служба SSH
- Порт: 2222
- Файл конфигурации: /etc/ssh/sshd_config.d/99-hardening.conf
- Изменённые директивы:
  - Port 2222
  - PermitRootLogin no
  - PasswordAuthentication no
  - PubkeyAuthentication yes
  - PermitEmptyPasswords no
  - MaxAuthTries 3
  - LoginGraceTime 30
  - AllowUsers devops
  - X11Forwarding no
  - ClientAliveInterval 300
  - ClientAliveCountMax 2

## 6. Правила межсетевого экрана
- Политики по умолчанию: deny (incoming), allow (outgoing)
- Правила:
  - 2222/tcp LIMIT (SSH)
  - 80/tcp ALLOW (HTTP)
  - 443/tcp ALLOW (HTTPS)

## 7. Снимки состояния
- 01-clean-install — чистая установка
- 02-keys-configured — после настройки ключей
- 03-ssh-hardened — после hardening SSH

## 9. Контейнеризация
- Способ установки Docker Engine: из официального репозитория Docker (docker-ce), версия 29.9.1.
- Участники группы docker: пользователь devops.
- Расположение проекта на сервере: `/home/devops/app`.
- Расположение файла .env: `/home/devops/app/.env`, права `600`, владелец devops.
- Публикуемые порты: `127.0.0.1:5000` (только для локального доступа).
- Именованные тома: `app_db_data` (для хранения данных PostgreSQL).
- Конфигурация обратного прокси-сервера: Nginx, директивы `location /app/` (proxy_pass на `127.0.0.1:5000`).
