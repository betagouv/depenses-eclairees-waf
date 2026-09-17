# depenses-eclairees-waf

nginx + ModSecurity reverse proxy in front of the depenses-eclairees
applications, packaged as a Scalingo nginx-buildpack app.

## How it works

`servers.conf.erb` is an ERB template with one `server` block per proxied
application. At container start, `docker-entrypoint.sh` compiles it to
`/etc/nginx/conf.d/default.conf` and validates the result with `nginx -t`
before starting nginx. Never edit a generated `default.conf`: the template
is the source of truth.

Per-application ModSecurity exceptions live in `<app>_rules.txt`, loaded
with `modsecurity_rules_file`. Every rules file must also be added to the
`COPY` list in the `Dockerfile`, otherwise startup fails.

## Scalingo variables

    BUILDPACK_URL=https://github.com/Scalingo/nginx-buildpack.git
    ENABLE_MODSECURITY=true

Upstream servers (`host:port`), one per application:

| Variable | Default |
| --- | --- |
| `METABASE_UPSTREAM_SERVER` | `metabase:3000` |
| `N8N_UPSTREAM_SERVER` | `n8n:5678` |
| `DEPEC_WEB_UPSTREAM_SERVER` | - |
| `GESEC_WEB_UPSTREAM_SERVER` | - |
| `SFTP_WEB_UPSTREAM_SERVER` | - |

Public hosts:

| Variable | Default |
| --- | --- |
| `METABASE_HOST` | `metabase.local` |
| `N8N_HOST` | - |
| `DEPEC_WEB_HOST` | - |
| `GESEC_WEB_HOST` | - |
| `SFTP_WEB_HOST` | - |

Rate-limited login paths:

| Variable | Default |
| --- | --- |
| `N8N_LOGIN_PATH` | `/rest/login` |
| `DEPEC_WEB_ADMIN_LOGIN_PATH` | - |
| `GESEC_WEB_ADMIN_LOGIN_PATH` | - |
| `SFTP_WEB_ADMIN_LOGIN_PATH` | - |

Metabase's login path is hardcoded as `/auth/login` in `servers.conf.erb`.

## Testing

No ruby/nginx locally; use Docker. The entrypoint prints the generated
config and runs `nginx -t`, so a bad template fails fast without a real
upstream:

    docker build -t waf .
    docker run --rm waf
