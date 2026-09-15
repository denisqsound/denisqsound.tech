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

## Zola-специфика

- Zola 0.23, Tera v2: `concat`/`slice` фильтров нет — spread `[...a, ...b]` и срезы `a[:15]`; тесты только с kwargs.
- Подсветка кода: Giallo, `style = "class"`, генерит `giallo-light.css`/`giallo-dark.css` — ссылки в `base.html` через `media="(prefers-color-scheme: ...)"`.
- В Dockerfile zola ставится официальным бинарём (`debian:trixie-slim` stage); `apk add zola` даёт 0.20 и не подходит.
