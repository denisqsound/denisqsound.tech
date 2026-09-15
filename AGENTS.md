# AGENTS.md

## Сборка и проверка

- `zola serve --port 1111` — локальный превью-сервер
- `zola build` — сборка в `public/` (валидирует шаблоны и контент)
- `docker build --platform linux/arm64 -t denisqsound-web:test .` — проверка образа

## Деплой

- `./deploy/deploy.sh` — полный цикл на хост `oracle` (ssh-алиас, `DEPLOY_HOST` для переопределения)
- Хост: Oracle A1 aarch64. Образы только `linux/arm64` (Mac arm64 собирает нативно).
- Контейнер `denisqsound-web` живёт в docker-сети `edge`, порты наружу не публикует.
- TLS/маршрутизация: общий `edge-proxy` (Wallarm nginx). Vhost'ы: `/opt/edge-proxy/conf.d/54-denisqsound-http.conf` + `55-denisqsound.conf`; серты `/opt/edge-proxy/certs/denisqsound.{crt,key}`.
- TLS-конфиг ставить ТОЛЬКО после того, как сертификат существует — иначе `nginx -t` падает и блокирует reload'ы всех сайтов прокси. Это делает `setup-edge.sh`.

## Edge-proxy (Wallarm)

- Wallarm-режим и app_id задаются мапами по `$host` в `/opt/edge-proxy/nginx.conf` (`$wallarm_mode_by_host`, `$wallarm_application_id`). `denisqsound.tech`/`www` → app_id `1006`, режим `block`. Статистика: `docker exec edge-proxy wget -qO- http://127.0.0.8/wallarm-status`.
- **ЛОВУШКА**: `/opt/edge-proxy/nginx.conf` смонтирован в контейнер как файл-bind (ro). `sed -i` и любая правка через rename меняет inode — контейнер продолжает читать СТАРЫЙ файл, `nginx -t`/reload проходят, но правки не действуют. Безопасная правка: писать через существующий inode (`cat newfile > /opt/edge-proxy/nginx.conf`), а если inode уже разошлись — `docker restart edge-proxy` либо nsenter-write в смонтированный inode. Файлы в `conf.d/` этой проблеме не имеют (directory-mount) — `sed -i` там безопасен.

## Контент

- Блога нет — только статьи. Все новые тексты кладутся в `content/articles/` и появляются в списке автоматически.
- Статья-«страница» без обвязки сайта (как `static/harness-engineering/`) всё равно должна иметь запись в списке статей: стаб `content/articles/<slug>.md` с `template = "redirect.html"` и `[extra] redirect_to = "/<slug>/"`.

## Zola-специфика

- Zola 0.23, Tera v2: `concat`/`slice` фильтров нет — spread `[...a, ...b]` и срезы `a[:15]`; тесты только с kwargs.
- Подсветка кода: Giallo, `style = "class"`, генерит `giallo-light.css`/`giallo-dark.css` — ссылки в `base.html` через `media="(prefers-color-scheme: ...)"`.
- В Dockerfile zola ставится официальным бинарём (`debian:trixie-slim` stage); `apk add zola` даёт 0.20 и не подходит.
