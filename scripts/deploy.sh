#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# Проверка 4: наличие index.html
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл ${LOCAL_DIR}index.html отсутствует." >&2
    exit 1
fi

# Проверка 5: незафиксированные изменения
if [[ -n "$(git status --porcelain | grep -v 'site/')" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения." >&2
    exit 1
fi

# Проверка 3: синхронизация
rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/" -e "ssh -o BatchMode=yes"

if [[ -n "${DRY_RUN}" ]]; then
    exit 0
fi

# Проверка 6: доступность ресурса
if ! curl -f --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null 2>&1; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен." >&2
    exit 1
fi

echo "Успешно доставлен коммит: $(git rev-parse --short HEAD)"
exit 0
