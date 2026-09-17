# AGENTS.md

Read `README.md` first for project context, architecture, environment
variables and testing.

## Adding an application block

Copy an existing block (e.g. SFTP/GESEC) and keep the same structure:

1. `limit_req_zone` for the login endpoint.
2. `upstream` with `resolve`, `keepalive 16`, and a `zone`.
3. `server` with `server_name`, `listen`, `charset`.
4. `modsecurity on;` and, if CRS breaks the app,
   `modsecurity_rules_file /app/<app>_rules.txt;`.
5. `proxy_http_version 1.1; proxy_set_header Connection "";` plus
   `X-Forwarded-Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`.
6. A rate-limited login `location` and a catch-all `location /`.

## Conventions

- Env var naming: `<APP>_HOST`, `<APP>_UPSTREAM_SERVER`,
  `<APP>_ADMIN_LOGIN_PATH` or `<APP>_LOGIN_PATH`. Add a default to
  `test/render-config.sh` when the app needs one, otherwise an unset
  var renders an empty `location` and breaks `nginx -t`.
- `SecRule` ids must be unique across the process. Reserved ranges:
  1000-1099 Metabase, 2000-2099 n8n.
- A new rules file must be added to the `COPY` list in `test/Dockerfile`.
- Comments in the nginx config are expected; keep them short.
- Indentation in `servers.conf.erb` is 4 spaces.

## Testing

Run `docker build -t waf -f test/Dockerfile .` then
`docker run --rm waf nginx -T` before finishing; it prints the generated
config and fails fast on a bad template. Run `docker run --rm waf` to
start nginx.
