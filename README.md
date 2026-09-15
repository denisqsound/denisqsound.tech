# denisqsound.tech

Личный сайт: блог и статьи. Zola → статика → nginx в контейнере на Oracle A1.

## Разработка

```sh
brew install zola
zola serve          # http://127.0.0.1:1111
```

Контент — Markdown в `content/`:

- `content/articles/` — длинные статьи
- `content/blog/` — короткие заметки
- `content/about.md` — страница «обо мне»

Front matter записи:

```toml
+++
title = "Заголовок"
date = 2026-09-15
description = "Однострочник для списков и og:description."
[taxonomies]
tags = ["тег"]
+++
```

Черновик: `draft = true` — не попадёт в сборку.

## Деплой на oracle

Пререквизиты на хосте (уже настроено): docker-сеть `edge`, edge-proxy на 80/443.

```sh
./deploy/deploy.sh
```

Что делает скрипт:

1. `docker build --platform linux/arm64` → тег `denisqsound-web:<git-sha>`
2. `docker save | ssh oracle docker load`
3. Копирует `compose.yml`, `setup-edge.sh`, `renew-cert-denisqsound.sh`, `edge-proxy/*.conf` в `/opt/denisqsound/`
4. `docker compose up -d` — контейнер `denisqsound-web` в сети `edge`
5. `setup-edge.sh` — ставит vhost'ы в `/opt/edge-proxy/conf.d/` и перечитывает edge-proxy

### Первый запуск / TLS

DNS `denisqsound.tech` и `www.denisqsound.tech` (A-записи, reg.ru) должны указывать на `158.180.21.218`. Пока записи не обновились, `setup-edge.sh` ставит только :80-виртхост (ACME + редирект); после переключения DNS повторный запуск `deploy.sh` (или `sudo bash /opt/denisqsound/setup-edge.sh` на хосте) выпустит сертификат через certbot и включит TLS-виртхост.

Перевыпуск вручную: `sudo bash /opt/denisqsound/renew-cert-denisqsound.sh`. Учётки Let's Encrypt живут в `/opt/edge-proxy/letsencrypt/`; `--keep-until-expiring` делает скрипт безопасным для крона.

## Файлы

| Путь | Назначение |
|---|---|
| `Dockerfile` | multi-stage: zola (debian, официальный бинарь) → `nginx:1.29-alpine` |
| `docker/nginx.conf` | внутриконтейнерный статик-vhost |
| `deploy/compose.yml` | unit для хоста: сеть `edge`, restart unless-stopped |
| `deploy/edge-proxy/` | vhost'ы edge-proxy (`54` — HTTP/ACME, `55` — TLS) |
| `deploy/setup-edge.sh` | идемпотентная установка vhost'ов + выпуск серта |
| `deploy/renew-cert-denisqsound.sh` | certbot standalone через edge-сеть |
