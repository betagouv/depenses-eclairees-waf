# AGENTS.md

Read `README.md` first for project context, architecture, environment
variables and testing.

## Adding an application

Add an entry to the `apps` array at the top of `servers.conf.erb`; the
loop renders its rate limit, upstream and `server` block:

1. `name` must be unique: it drives the `limit_req_zone`, `upstream`
   and zone names.
2. `title` is only the section banner comment.
3. `host` and `upstream` come from `<APP>_HOST` and
   `<APP>_UPSTREAM_SERVER`.
4. `login_path` comes from `<APP>_ADMIN_LOGIN_PATH` or `<APP>_LOGIN_PATH`.
5. `rules` is `<app>_rules.txt` when CRS breaks the app, else `nil`.

Add defaults for any new env var to `test/render-config.sh`.

## Conventions

- Env var naming: `<APP>_HOST`, `<APP>_UPSTREAM_SERVER`,
  `<APP>_ADMIN_LOGIN_PATH` or `<APP>_LOGIN_PATH`. Add a default to
  `test/render-config.sh` when the app needs one, otherwise an unset
  var renders an empty `location` and breaks `nginx -t`.
- `SecRule` ids must be unique across the process. Reserved ranges:
  1000-1099 Metabase, 2000-2099 n8n.
- A new rules file must be added to the `COPY` list in `test/Dockerfile`.
- ModSecurity concatenates the rules files of a server, so every rules
  file must end with a newline or the next file's first line is merged.
- `common_rules.txt` is shared and loaded for every app before the
  per-app file; keep its rules narrow and scoped to specific cookies.
- Comments in the nginx config are expected; keep them short.
- Indentation in `servers.conf.erb` is 4 spaces.

## Testing

Run `docker build -t waf -f test/Dockerfile .` then
`docker run --rm waf nginx -T` before finishing; it prints the generated
config and fails fast on a bad template. Run `docker run --rm waf` to
start nginx.
