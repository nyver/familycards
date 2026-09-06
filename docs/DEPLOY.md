# Развёртывание на VPS

Пошаговое развёртывание сервера (`server/`) на чистом VPS с Caddy в роли TLS-терминатора. Этот документ описывает только сервер — сборка мобильного клиента описана в `README.md` («Quick start: mobile client»).

## Требования

- VPS с Linux (Debian/Ubuntu) и белым IP.
- Домен, указывающий A-записью на VPS.
- Docker и Docker Compose **или** Go 1.23+ для сборки из исходников.
- Открытые порты 80 и 443 (Caddy получает сертификат Let's Encrypt по HTTP-01/TLS-ALPN).

## 1. Подготовка секретов

```bash
openssl rand -base64 32   # WALLET_JWT_SECRET
openssl rand -base64 24   # WALLET_BOOTSTRAP_TOKEN
openssl rand -base64 24   # WALLET_ADMIN_TOKEN (опционально, для /v1/admin/backup)
```

Сохраните значения — они понадобятся ниже.

## 2. Вариант A: Docker Compose

```bash
git clone <repo> familycards
cd familycards/deploy

cat > .env <<'EOF'
WALLET_JWT_SECRET=<вставьте сгенерированное значение>
WALLET_BOOTSTRAP_TOKEN=<вставьте сгенерированное значение>
WALLET_ADMIN_TOKEN=<вставьте сгенерированное значение>
WALLET_LOG_LEVEL=info
WALLET_ALLOW_INSECURE=false
EOF

docker compose up -d --build
```

`docker-compose.yml` собирает образ из `server/Dockerfile` (multi-stage, distroless, `CGO_ENABLED=0`), пробрасывает порт `127.0.0.1:8443:8443` и монтирует volume `wallet-data` под `/data`. Сервер слушает `:8443` внутри контейнера, а порт на хосте публикуется только на loopback — снаружи хоста ничего, кроме Caddy, обращаться к нему не должно.

Проверка:

```bash
curl -H "X-Forwarded-Proto: https" http://localhost:8443/v1/health
```

## 3. Вариант B: systemd без Docker

```bash
cd familycards/server
CGO_ENABLED=0 go build -o /opt/wallet/wallet ./cmd/wallet
useradd --system --home /opt/wallet --shell /usr/sbin/nologin wallet
mkdir -p /opt/wallet/data /etc/wallet
chown -R wallet:wallet /opt/wallet

cat > /etc/wallet/wallet.env <<'EOF'
WALLET_ADDR=127.0.0.1:8443
WALLET_DB_PATH=/opt/wallet/data/wallet.db
WALLET_BLOB_DIR=/opt/wallet/data/blobs
WALLET_JWT_SECRET=<вставьте сгенерированное значение>
WALLET_BOOTSTRAP_TOKEN=<вставьте сгенерированное значение>
WALLET_ADMIN_TOKEN=<вставьте сгенерированное значение>
WALLET_LOG_LEVEL=info
EOF
chmod 600 /etc/wallet/wallet.env

cp deploy/wallet.service /etc/systemd/system/wallet.service
systemctl daemon-reload
systemctl enable --now wallet
```

`deploy/wallet.service` намеренно биндит сервер только на `127.0.0.1` (через `WALLET_ADDR` в `wallet.env`) — снаружи хоста порт 8443 недоступен, единственный публичный вход — Caddy.

## 4. Caddy (TLS-терминатор)

```bash
apt install caddy   # или см. https://caddyserver.com/docs/install
cp deploy/Caddyfile /etc/caddy/Caddyfile
# отредактируйте домен внутри файла
systemctl reload caddy
```

Caddy автоматически получит сертификат Let's Encrypt при первом запросе к указанному домену и будет проставлять `X-Forwarded-Proto: https`, который сервер проверяет для отказа в незащищённых запросах.

Проверка снаружи:

```bash
curl https://wallet.example.com/v1/health
```

### Диагностика: `bind: address already in use` при старте Caddy

`journalctl -u caddy` показывает `listen tcp :443: bind: address already in use` — порт 443 уже занят другим процессом (частый случай на образах VPS с предустановленным nginx/apache или панелью управления). Сначала выясните, кто именно:

```bash
sudo ss -ltnp | grep ':443\|:80'
```

Если это лишний сервис — остановите и отключите его (`systemctl disable --now <service>`). Если порт 443 нужен другому сервису на этом же хосте и его нельзя освободить, Caddy можно указать слушать другой порт вместо 443 — добавьте `:PORT` после домена в `Caddyfile` (см. комментарий там же), например `wallet.example.com:8444 {`, и перезапустите `systemctl reload caddy`. Для выпуска сертификата Let's Encrypt в этом случае обязателен свободный порт 80 (ACME HTTP-01), даже если сам сайт слушает другой порт. В приложении тогда указывается адрес с портом явно: `https://wallet.example.com:8444`.

## 5. Первый запуск (bootstrap)

Bootstrap выполняется **из мобильного приложения** при первом запуске — вводится адрес сервера и `WALLET_BOOTSTRAP_TOKEN`. После успешного создания сейфа токен можно удалить из `wallet.env`/`.env` и перезапустить сервис — повторный bootstrap всё равно будет отклонён кодом 409, поскольку сервер проверяет наличие пользователей в базе, а не наличие токена.

## 6. Резервное копирование

### Ручной запуск

```bash
curl -X POST -H "X-Admin-Token: <WALLET_ADMIN_TOKEN>" https://wallet.example.com/v1/admin/backup
```

Создаёт консистентный снимок базы (`VACUUM INTO`) и `.tar.gz` каталога блобов в `<data>/backups/`.

### Автоматизация через cron

```bash
crontab -e -u wallet
```

```
0 3 * * * WALLET_URL=https://wallet.example.com WALLET_ADMIN_TOKEN=<...> WALLET_BACKUP_DIR=/opt/wallet/data/backups /opt/wallet/scripts/backup.sh >> /var/log/wallet-backup.log 2>&1
```

`scripts/backup.sh` вызывает `/v1/admin/backup` и хранит 14 последних копий каждого артефакта (базы и архива блобов), удаляя более старые.

### Восстановление

```bash
systemctl stop wallet
cp /opt/wallet/data/backups/wallet-<timestamp>.db /opt/wallet/data/wallet.db
tar -xzf /opt/wallet/data/backups/blobs-<timestamp>.tar.gz -C /opt/wallet/data/blobs
systemctl start wallet
```

## Диагностика: `mkdir /data/blobs: permission denied`

Образ собран на `gcr.io/distroless/static-debian12:nonroot` и работает под непривилегированным пользователем (UID 65532). Docker создаёт именованный volume при первом использовании от имени `root`; `Dockerfile` компенсирует это, копируя в образ пустой каталог `/data` с `--chown=65532:65532`, чтобы свежий volume наследовал верные права при инициализации — но это работает только для **вновь создаваемого** volume, собранного из **обновлённого** образа.

Если ошибка уже возникла (volume был создан старым образом до этого исправления), сам факт пересборки образа её не исправит — Docker не переинициализирует существующий volume. Два варианта:

- Volume ещё пустой (первый запуск ни разу не успел записать `wallet.db`) — можно просто пересоздать его:
  ```bash
  docker compose down
  docker volume rm familycards_wallet-data   # проверьте точное имя: docker volume ls
  docker compose up -d --build
  ```
- В volume уже есть данные — поправьте владельца на месте, не удаляя его:
  ```bash
  docker compose down
  docker run --rm -v familycards_wallet-data:/data alpine chown -R 65532:65532 /data
  docker compose up -d --build
  ```

## 7. Мониторинг

`GET /v1/health` возвращает `{"status","version","db_size","item_count"}` — подходит для внешнего аптайм-мониторинга. Сервер дополнительно пишет в лог структурированную почасовую сводку (`item_count`, `blob_count`, `db_size`) уровнем `info`.

## 8. TLS без Caddy

Сервер умеет терминировать TLS самостоятельно (`WALLET_TLS_MODE`), без Caddy или любого другого реверс-прокси перед собой. Режим по умолчанию (`off`, разделы 2–4 выше) остаётся полностью поддерживаемым и ничего не меняет в существующих развёртываниях.

Общий для всех трёх режимов ниже пререквизит — свободные порты 80 и 443 на хосте (443 — под HTTPS, 80 — под редирект/ACME-челлендж, если задан `WALLET_HTTP_ADDR`). Диагностика занятого порта — та же, что и для Caddy (см. раздел 4 выше): `sudo ss -ltnp | grep ':443\|:80'`, отключить лишний сервис или вернуться к варианту с Caddy на нестандартном порту.

### Режим `selfsigned` — без домена, без внешнего CA

Работает «из коробки» с `docker compose up`, ничего дополнительно готовить не нужно:

```bash
cd familycards/deploy
cat > .env <<'EOF'
WALLET_JWT_SECRET=<вставьте сгенерированное значение>
WALLET_BOOTSTRAP_TOKEN=<вставьте сгенерированное значение>
WALLET_TLS_MODE=selfsigned
EOF
docker compose up -d --build
```

См. закомментированный вариант `selfsigned` в `deploy/docker-compose.yml` — раскомментируйте нужный сервис вместо стандартного (с Caddy). Сервер сам выпускает сертификат при первом старте и сохраняет его в `WALLET_TLS_CACHE_DIR` (по умолчанию — каталог `certs` внутри тома `wallet-data`, поэтому сертификат переживает пересоздание контейнера).

Отпечаток SHA-256 выпущенного сертификата печатается в лог при каждом старте:

```bash
docker compose logs wallet | grep fingerprint
```

Дальше — раздел «Закрепление отпечатка в приложении» ниже.

### Режим `file` — свой сертификат/ключ

Для сертификата от любого источника (например, `certbot` в режиме `--standalone`/`--webroot`, или корпоративный CA):

```bash
WALLET_TLS_MODE=file
WALLET_TLS_CERT_FILE=/opt/wallet/tls/fullchain.pem
WALLET_TLS_KEY_FILE=/opt/wallet/tls/privkey.pem
```

Пара загружается один раз при старте. Продление сертификата (например, `certbot renew`) не подхватывается на лету — после обновления файлов на диске необходимо перезапустить сервис (`systemctl restart wallet` / `docker compose restart`), иначе сервер продолжит отдавать старый сертификат из памяти вплоть до его истечения.

### Режим `acme` — автоматический Let's Encrypt

Только для VPS с белым IP и доменом, указывающим на него (не сработает за NAT/для домашнего сервера):

```bash
WALLET_ADDR=:443
WALLET_HTTP_ADDR=:80
WALLET_TLS_MODE=acme
WALLET_TLS_DOMAINS=wallet.example.com
WALLET_TLS_ACME_EMAIL=you@example.com
```

Сертификат и ключ учётной записи ACME сохраняются в `WALLET_TLS_CACHE_DIR` и переиспользуются между перезапусками — повторный выпуск при каждом `docker compose restart`/`systemctl restart` не происходит. Продление Let's Encrypt (~каждые 60 дней) сервер выполняет сам, без вмешательства оператора — но см. предупреждение о закреплении отпечатка ниже.

Для systemd-варианта (без Docker) непривилегированному пользователю `wallet` нужно право биндить порты 80/443 — раскомментируйте `CapabilityBoundingSet=`/`AmbientCapabilities=CAP_NET_BIND_SERVICE` в `deploy/wallet.service` (в Docker-варианте это не требуется — порты пробрасываются наружу контейнера).

### Закрепление отпечатка в приложении

Собственная TLS-терминация без публичного CA (`selfsigned`, а также `file` с самоподписанным или внутренним сертификатом) требует закрепления (pinning) отпечатка на стороне мобильного приложения — иначе системные корневые центры сертификации отклонят соединение.

1. Прочитайте отпечаток из журнала сервера: `docker compose logs wallet | grep fingerprint` (Docker) или `journalctl -u wallet | grep fingerprint` (systemd).
2. В приложении на экране ввода адреса сервера (или в настройках → диагностика сервера → «Закрепить сертификат») либо вставьте отпечаток вручную, либо дождитесь предупреждения о непроверенном сертификате при первой попытке подключения и подтвердите показанное значение, сверив его с прочитанным на шаге 1.
3. Проверьте синхронизацию — она должна установить соединение по этому сертификату и только по нему.

**Не закрепляйте отпечаток сертификата, выпущенного публичным центром сертификации** (режим `acme`, либо `file` с сертификатом от Let's Encrypt/другого публичного CA) — такой сертификат периодически продлевается, отпечаток при этом меняется, и синхронизация встанет до тех пор, пока пин не будет обновлён вручную на каждом устройстве. Приложение предупреждает об этом при попытке закрепить такой сертификат, но решение можно принять и заранее: для `acme` закрепление просто не нужно, поскольку сертификат и так подписан доверенным публичным CA.

### Откат к Caddy

Вернуть `WALLET_TLS_MODE=off`, `WALLET_ADDR=127.0.0.1:8443` (или прежнее значение), убрать `WALLET_HTTP_ADDR`, перезапустить сервис и снова запустить Caddy (раздел 4 выше). Данные (`data/wallet.db`, `data/blobs/`) и содержимое `WALLET_TLS_CACHE_DIR` при этом не затрагиваются. В приложении закреплённый отпечаток (если был) нужно снять в настройках — иначе новый (Caddy-терминированный, доверенный системными CA) сертификат будет отклонён как несовпадающий с устаревшим пином.
