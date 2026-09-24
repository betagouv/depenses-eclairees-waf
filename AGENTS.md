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

## Updating the n8n `/rest/` exemption

`n8n_rules.txt` rule 2004 exempts the RCE/SQLi/PHP/LFI tags on `ARGS` and
`ARGS_NAMES` for all of `/rest/`, except an exclusion list (login, account
recovery, SSO/OAuth callbacks, api-keys, e2e/debug, instance-ai gateway).
n8n adds routes over time: recheck the list after every n8n upgrade.

1. Deployed version: `GET https://<n8n-host>/rest/settings` (`versionCli`),
   or the n8n image tag.
2. List upstream routes for that tag (URL-encode `@` as `%40`):

       curl -s "https://api.github.com/repos/n8n-io/n8n/git/trees/n8n%40<version>?recursive=1" \
         | jq -r '.tree[].path' | grep -E 'cli/src/.*\.ts$'

3. Public routes are those registered with `skipAuth` /
   `allowUnauthenticated`, plus static routers (e.g. `/rest/ph`). Look at:
   - `packages/cli/src/controllers/*.controller.ts` (`@RestController`,
     `@Get/@Post/@Put/@Patch/@Delete`)
   - `packages/cli/src/server.ts` and `abstract-server.ts` (non-decorated
     mounts)
   - `packages/cli/src/middlewares/*auth*.ts` (how auth is applied)
   - `packages/cli/src/modules/**` (SSO, instance-ai, agents, source
     control, external secrets...)

       rg -n "skipAuth|allowUnauthenticated" packages/cli/src
       rg -n "@(Get|Post|Put|Patch|Delete)\(" packages/cli/src/controllers

4. Diff with the exclusion regex in rule 2004: add any new unauthenticated
   account/SSO/test route that receives user input. Everything else under
   `/rest/` stays exempted.
5. Validate: `docker build -t waf -f test/Dockerfile .` then
   `docker run --rm waf nginx -T` (ModSecurity compiles the regex at
   startup, a bad one fails fast). Smoke test: an exempt route with a
   `{"credentials":{...}}` body must not return 403, and `/rest/login`
   with an SQLi payload must still return 403.

## Conventions

- Env var naming: `<APP>_HOST`, `<APP>_UPSTREAM_SERVER`,
  `<APP>_ADMIN_LOGIN_PATH` or `<APP>_LOGIN_PATH`. Add a default to
  `test/render-config.sh` when the app needs one, otherwise an unset
  var renders an empty `location` and breaks `nginx -t`.
- `SecRule` ids must be unique across the process. Reserved ranges:
  1000-1099 Metabase, 2000-2099 n8n.
- Use CRS rule ids (`ruleRemoveById`, `ruleRemoveTargetById`) when exactly
  one rule or target must be exempted; use tags (`ruleRemoveByTag`,
  `ruleRemoveTargetByTag`) only for whole-group exceptions.
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
