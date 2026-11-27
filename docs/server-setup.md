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

## 8. Веб-сервер
- Устанавливаемый пакет: `nginx`
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site`
- Каталог ресурса: `/var/www/devops-site`, владелец `devops`, права `755` для каталога и `644` для файлов.
- Пути к сертификату и ключу: `/etc/ssl/certs/devops.crt` (права `644`), `/etc/ssl/private/devops.key` (права `600`, владелец `root`).
- Команда формирования сертификата: 
`sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия сертификата: 365 дней.

## 9. Контейнеризация
- Способ установки Docker Engine: из официального репозитория Docker (docker-ce), версия 29.9.1.
- Участники группы docker: пользователь devops.
- Расположение проекта на сервере: `/home/devops/app`.
- Расположение файла .env: `/home/devops/app/.env`, права `600`, владелец devops.
- Публикуемые порты: `127.0.0.1:5000` (только для локального доступа).
- Именованные тома: `app_db_data` (для хранения данных PostgreSQL).
- Конфигурация обратного прокси-сервера: Nginx, директивы `location /app/` (proxy_pass на `127.0.0.1:5000`).




## 10. Ansible

**Примечание.** Разделы 1–9 описывают состояние после практических работ № 5–9 (SSH на 2222, hardening `99-hardening.conf`, статический сайт с TLS, локальный Docker-образ с `.env` и томами). В практической работе № 11 конфигурация сервера описана декларативно средствами Ansible и **часть параметров изменена**: SSH возвращён на порт 22 (Host-only, без NAT-проброса), hardening выполняется через `00-ansible-hardening.conf`, Nginx работает как reverse proxy на `127.0.0.1:5000`, приложение берётся из GHCR по полному SHA, HTTPS в этой работе не настраивается. Актуальное состояние — раздел 10.


### Расположение проекта

Проект Ansible находится в каталоге `ansible/` репозитория `Dev_Ops_KURS3`


### Управляющий и управляемый узлы

- **Управляющий узел:** Ubuntu (WSL) на хостовой машине, с установленными `ansible` (core ≥ 2.16) и `sshpass`. Коллекции: `community.docker`, `community.general`, `ansible.posix`.
- **Управляемый узел:** Ubuntu Server 24.04 в VirtualBox, Host-only адрес `192.168.56.101`, SSH на порту 22.

Модель работы — push: управляющий узел читает inventory, подключается к управляемому по SSH, передаёт и выполняет модули. Постоянный агент на управляемом узле не требуется.

### Inventory

- `ansible/inventory/bootstrap.ini` — первичный запуск от пользователя `student` по паролю (`--ask-pass --ask-become-pass`).
- `ansible/inventory/prod.ini` — последующие запуски от пользователя `devops` по ключу `~/.ssh/devops_vm`, без интерактивного ввода.

### Учётные записи bootstrap и prod

- **bootstrap (`student`):** первичный доступ по паролю, используется только для первого прогона. После настройки SSH парольная аутентификация отключается; `student` остаётся в `AllowUsers` для доступа по ключу и через консоль VM как резерв.
- **prod (`devops`):** создаётся ролью `ssh`, получает ключ `~/.ssh/devops_vm.pub`, `sudo` с `NOPASSWD` и группу `docker`. Используется для всех последующих запусков, включая CI.

Пароли и закрытый ключ в документ не включаются.

### Роли и их ответственность

| Роль | Ответственность |
|---|---|
| `base` | Проверка ОС (Ubuntu 24.04 amd64), базовые пакеты (`python3-requests`, `python3-debian`), официальный репозиторий Docker, установка Docker Engine, включение службы |
| `ssh` | Пользователь `devops`, SSH-ключ, `NOPASSWD`, hardening SSH (`00-ansible-hardening.conf`), UFW (22/tcp, 80/tcp, `deny incoming`) |
| `nginx` | Пакет Nginx, reverse proxy на `127.0.0.1:5000`, отключение default-сайта, включение сайта приложения |
| `app` | Загрузка образа по SHA, запуск контейнера (порт только на `127.0.0.1`), health-check через `uri` |

Порядок ролей в `site.yml`: `base → ssh → nginx → app`.

Handlers: `ssh` → `Restart SSH` (при изменении hardening-конфига); `nginx` → `Validate Nginx before reload` (`nginx -t`) и `Reload Nginx` (оба на событие `Reload Nginx`). В `ansible.cfg` включён `force_handlers = True`, поэтому уведомлённые handlers выполняются даже при отказе более поздней задачи.

### Образ GHCR

- Адрес: `ghcr.io/kartohkaa/devops-ci-app`
- Полный SHA: `4ccb29b2f70bd937772cd5c8ae0d725a39d4ee63`
- Тег `latest` не используется: конфигурация сервера связана с проверенным исходником (образ опубликован CI в ПР № 10).

### Порт контейнера

Контейнер публикуется как `127.0.0.1:5000:5000` — только на loopback. Docker открывает опубликованные порты своими iptables-правилами раньше UFW, поэтому привязка к `127.0.0.1` исключает прямой обход Nginx. Внешний доступ — только через Nginx на `:80` (разрешён UFW).

### Health endpoint

- `http://127.0.0.1:5000/health` — прямой health-check контейнера (используется ролью `app` и `verify.yml`).
- `http://192.168.56.101/health` — проверка цепочки «клиент → Nginx → контейнер» с управляющего узла.

Ожидаемый ответ: `HTTP 200`, тело `{"status":"ok", ...}`.

### Команды первичного и повторного запусков

Первичный запуск (bootstrap, от `student` по паролю):

```bash
cd ansible
ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass

