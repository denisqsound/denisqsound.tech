+++
title = "Как устроен этот сайт"
date = 2026-09-15
description = "Zola, один контейнер и общий edge-proxy: минимальная инфраструктура для личного сайта."
[taxonomies]
tags = ["инфраструктура", "zola", "docker"]
+++

Личный сайт не должен быть сложным. Здесь весь стек умещается в один Dockerfile и один скрипт деплоя.

## Стек

- **Zola** генерирует статику из Markdown. Один бинарь, никаких зависимостей в рантайме.
- **nginx** внутри контейнера раздаёт готовые файлы.
- **edge-proxy** на хосте принимает TLS и проксирует запросы в контейнер по внутренней docker-сети.

## Сборка

Образ собирается в два этапа: сначала Zola собирает `public/`, затем результат копируется в образ с nginx.

```dockerfile
FROM alpine:3.22 AS build
RUN apk add --no-cache zola
COPY . /site
RUN cd /site && zola build

FROM nginx:1.29-alpine
COPY --from=build /site/public /usr/share/nginx/html
```

Итоговый образ весит около 20 Мб. Внутри нет ни Node, ни Python: только nginx и статика.

## Деплой

Машина на Oracle A1 имеет aarch64, как и мой Mac, поэтому образ собирается локально и уезжает на хост через `docker save | ssh docker load`. Никакого registry, никакого CI: `deploy/deploy.sh` делает всё за один запуск.

TLS-сертификаты выпускает certbot-контейнер через HTTP-01: edge-proxy отдаёт ему `/.well-known/acme-challenge/`, всё остальное уходит в 301 на HTTPS.

> Минимум движущихся частей: если что-то сломается, сломается один контейнер со статикой, и чинить его будет не стыдно в два часа ночи.

Исходники лежат в репозитории [denisqsound.tech](https://github.com/denisqsound/denisqsound.tech).[^1]

[^1]: Включая конфиг vhost'а и скрипт выпуска сертификатов: инфраструктура тоже в git.
