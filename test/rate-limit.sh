#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: rate-limit.sh <url-file>

The file lists one login URL per line. Blank lines and lines starting
with # are ignored, for example:

    https://metabase.example.com/auth/login
    https://n8n.example.com/rest/login

Responses 429 and 503 count as rate limited. Reports are expected to be
200, 302, 401, 403 or 404; any other status, or a curl failure, is an
error and fails the URL. A URL passes when some requests are rate
limited, some are answered normally and none errored.

Optional environment variables:

    REQUESTS        number of requests fired at each URL (default 10)
    REQUEST_METHOD  HTTP method used for the requests (default GET)
    CURL_TIMEOUT    curl timeout in seconds (default 10)
    PAUSE           seconds to wait between URLs (default 2)
    VERBOSE         set to 1 to print every HTTP status code
EOF
    exit "${1:-1}"
}

[ $# -eq 1 ] || usage
url_file=$1
[ -r "$url_file" ] || { echo "error: cannot read $url_file" >&2; usage; }
command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }

requests=${REQUESTS:-10}
method=${REQUEST_METHOD:-GET}
timeout=${CURL_TIMEOUT:-10}
pause=${PAUSE:-2}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

failed=0
total=0
index=0
while IFS= read -r url || [ -n "$url" ]; do
    url=${url%$'\r'}
    case $url in
        ''|'#'*) continue ;;
        http://*|https://*) ;;
        *) echo "error: not an http(s) URL: $url" >&2; exit 1 ;;
    esac
    total=$((total + 1))
    index=$((index + 1))

    status_dir="$tmp_dir/$index"
    mkdir -p "$status_dir"
    for i in $(seq 1 "$requests"); do
        (
            code=$(curl -sS -o /dev/null -X "$method" --max-time "$timeout" \
                -w '%{http_code}' "$url" 2>"$status_dir/$i.err" || true)
            printf '%s\n' "$code" > "$status_dir/$i"
        ) &
    done
    wait || true

    limited=0
    passed=0
    errors=0
    : > "$status_dir/errors"
    for i in $(seq 1 "$requests"); do
        status=$(cat "$status_dir/$i")
        case $status in
            429|503) limited=$((limited + 1)) ;;
            200|302|401|403|404) passed=$((passed + 1)) ;;
            000)
                errors=$((errors + 1))
                cat "$status_dir/$i.err" >> "$status_dir/errors"
                ;;
            *)
                errors=$((errors + 1))
                printf 'unexpected HTTP status: %s\n' "$status" >> "$status_dir/errors"
                ;;
        esac
        if [ "${VERBOSE:-0}" = "1" ]; then
            echo "  $status"
        fi
    done
    if [ "$errors" -gt 0 ]; then
        sort -u "$status_dir/errors" | grep . | sed 's/^/  error: /' || true
    fi

    if [ "$limited" -gt 0 ] && [ "$passed" -gt 0 ] && [ "$errors" -eq 0 ]; then
        result=PASS
    else
        result=FAIL
        failed=$((failed + 1))
    fi

    printf '%s: %s requests=%d limited=%d passed=%d errors=%d\n' \
        "$url" "$result" "$requests" "$limited" "$passed" "$errors"

    sleep "$pause"
done < "$url_file"

if [ "$total" -eq 0 ]; then
    echo "error: no URL found in $url_file" >&2
    exit 1
fi

if [ "$failed" -gt 0 ]; then
    printf 'FAIL: %d of %d URL(s) not rate limited\n' "$failed" "$total" >&2
    exit 1
fi
printf 'PASS: %d URL(s) rate limited\n' "$total"