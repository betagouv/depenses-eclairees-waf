# depenses-eclairees-waf

nginx + ModSecurity reverse proxy in front of the depenses-eclairees
applications, packaged as a Scalingo nginx-buildpack app.

## How it works

`servers.conf.erb` is an ERB template with one `server` block per proxied
application. At container start, `test/render-config.sh` compiles it to
`/etc/nginx/conf.d/default.conf` before nginx starts. Never edit a
generated `default.conf`: the template is the source of truth.

Per-application ModSecurity exceptions live in `<app>_rules.txt`, loaded
with `modsecurity_rules_file`. Every rules file must also be added to the
`COPY` list in `test/Dockerfile`, otherwise startup fails.

## Scalingo variables

    BUILDPACK_URL=https://github.com/Scalingo/nginx-buildpack.git
    ENABLE_MODSECURITY=true

Upstream servers (`host:port`), one per application:

| Variable | Default |
| --- | --- |
| `METABASE_UPSTREAM_SERVER` | `metabase:3000` |
| `N8N_UPSTREAM_SERVER` | `n8n:5678` |
| `DEPEC_WEB_UPSTREAM_SERVER` | `depec-web:8000` |
| `GESEC_WEB_UPSTREAM_SERVER` | `gesec-web:8000` |
| `SFTP_WEB_UPSTREAM_SERVER` | `sftp-web:8000` |

Public hosts:

| Variable | Default |
| --- | --- |
| `METABASE_HOST` | `metabase.local` |
| `N8N_HOST` | `n8n.local` |
| `DEPEC_WEB_HOST` | `depec-web.local` |
| `GESEC_WEB_HOST` | `gesec-web.local` |
| `SFTP_WEB_HOST` | `sftp-web.local` |

Rate-limited login paths:

| Variable | Default |
| --- | --- |
| `N8N_LOGIN_PATH` | `/rest/login` |
| `DEPEC_WEB_ADMIN_LOGIN_PATH` | `/admin/login` |
| `GESEC_WEB_ADMIN_LOGIN_PATH` | `/admin/login` |
| `SFTP_WEB_ADMIN_LOGIN_PATH` | `/admin/login` |

Metabase's login path is hardcoded as `/auth/login` in `servers.conf.erb`.

## Testing

No ruby/nginx locally; use Docker. The test image lives in `test/`, so
build it from the repository root where the config files are:

    docker build -t waf -f test/Dockerfile .
    docker run --rm waf nginx -T

The image is based on `owasp/modsecurity-crs:nginx` and installs
`test/render-config.sh` as a late `/docker-entrypoint.d/` hook, so the
command above prints the generated config and runs the config test. A bad
template therefore fails fast without a real upstream. Run
`docker run --rm waf` (optionally with `-p 8080:8080`) to start nginx.
