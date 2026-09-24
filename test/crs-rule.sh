#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: crs-rule.sh [options] [<rule-id>]

Print a CRS rule as deployed, from a version-keyed local cache filled
from the coreruleset GitHub release tarball.

The CRS version is the one in the ModSecurity log line, e.g.
[ver "OWASP_CRS/4.25.1"] -> 4.25.1. Without --version, the latest such
version found in logs.txt is used.

Options:
    -v, --version X.Y.Z   CRS version to fetch
    -p, --path            print the cached rules directory instead of a
                          rule (rule-id optional)
    -r, --refresh         drop the cached copy and fetch it again
    -h, --help

Cache: test/.cache/crs/github-vX.Y.Z/ (override with CRS_CACHE_DIR).

Examples:
    test/crs-rule.sh 930130
    test/crs-rule.sh 930130 --version 4.29.0
    test/crs-rule.sh --path
EOF
    exit "${1:-1}"
}

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cache_root=${CRS_CACHE_DIR:-"$root/test/.cache/crs"}

command -v rg >/dev/null 2>&1 || { printf 'error: rg is required\n' >&2; exit 1; }

version=
path_only=0
refresh=0
rule_id=
while [ $# -gt 0 ]; do
    case $1 in
        -v|--version)
            [ $# -ge 2 ] || usage
            version=$2
            shift 2
            ;;
        -p|--path) path_only=1; shift ;;
        -r|--refresh) refresh=1; shift ;;
        -h|--help) usage 0 ;;
        -*) printf 'error: unknown option: %s\n' "$1" >&2; usage ;;
        *)
            [ -z "$rule_id" ] || usage
            rule_id=$1
            shift
            ;;
    esac
done

[ -n "$rule_id" ] || [ "$path_only" = 1 ] || usage
if [ "$path_only" = 1 ]; then
    :
elif [ -z "$rule_id" ]; then
    usage
fi
if [ -n "$rule_id" ] && ! [[ $rule_id =~ ^[0-9]+$ ]]; then
    printf 'error: rule id must be numeric: %s\n' "$rule_id" >&2
    exit 1
fi

if [ -z "$version" ]; then
    logs=$root/logs.txt
    [ -r "$logs" ] || { printf 'error: %s not readable, pass --version\n' "$logs" >&2; exit 1; }
    version=$( { rg -o --no-filename '\[ver "OWASP_CRS/[0-9]+\.[0-9]+\.[0-9]+"\]' "$logs" \
        | tail -1 | rg -o '[0-9]+\.[0-9]+\.[0-9]+'; } || true )
    [ -n "$version" ] || {
        printf 'error: no OWASP_CRS version in %s, pass --version\n' "$logs" >&2
        exit 1
    }
fi

dir=$cache_root/github-v$version
if [ "$refresh" = 1 ]; then
    rm -rf -- "$dir"
fi
if [ ! -d "$dir/rules" ]; then
    command -v curl >/dev/null 2>&1 || { printf 'error: curl is required\n' >&2; exit 1; }
    command -v tar >/dev/null 2>&1 || { printf 'error: tar is required\n' >&2; exit 1; }
    printf 'fetching CRS v%s...\n' "$version" >&2
    tmp=$(mktemp -d)
    trap 'rm -rf -- "$tmp"' EXIT
    url="https://github.com/coreruleset/coreruleset/archive/refs/tags/v$version.tar.gz"
    curl -fsSL "$url" -o "$tmp/crs.tar.gz" || {
        printf 'error: cannot fetch %s\n' "$url" >&2
        exit 1
    }
    mkdir -p -- "$dir"
    tar -xzf "$tmp/crs.tar.gz" --strip-components=1 -C "$dir"
    rm -rf -- "$tmp"
    trap - EXIT
fi

if [ "$path_only" = 1 ]; then
    printf '%s\n' "$dir/rules"
    exit 0
fi

printf '# source: CRS %s (github v%s)\n' "$version" "$version" >&2
cd -- "$dir/rules"
rg -n -B 1 -A 30 --no-heading "^[[:space:]]*\"id:$rule_id," . || {
    printf 'error: rule %s not found in CRS %s\n' "$rule_id" "$version" >&2
    exit 1
}
