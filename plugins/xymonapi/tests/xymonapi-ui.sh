#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# plugins/xymonapi/tests/xymonapi-ui.sh
#
# The API serves a directory of web pages at /xymon/ui/, beside the API
# those pages read, so that one address gives both: the directory
# XYMONAPI_UI names, or xymon-ui beside the plugins when that exists.
#
#   - a file of the directory is answered as it is, and the directory
#     itself with its index.html;
#   - each answer carries Cache-Control: no-cache, so that a browser asks
#     again after the files were replaced, and one asked again with the
#     ETag it was given is answered 304;
#   - a file that is not there is the API's own not_found, and nothing
#     outside the directory is reached through it;
#   - with a password set the pages ask for it as every other path does;
#   - set empty, or with no directory to serve, /xymon/ui/ is not found;
#   - a setting that names no directory stops the API, which says so.
#
# Skips where the API cannot run (tests/lib/xymonapi.sh). Needs the xymon
# client of the Xymon tree in XYMON_SRC (for a free port), curl, and Apache's
# htpasswd for the part with a password.

set -euo pipefail
# shellcheck source=tests/lib/xymonapi.sh
. "$(dirname "$0")/../../../tests/lib/xymonapi.sh"

ROOT=$(find_root)

require_bin XYMONCLIENT "$XYMON_SRC/common/xymon"
command -v curl >/dev/null 2>&1 || skip "curl is not installed"

work=$(mktempdir)
register_cleanup 'stop_process "$API_PID"'

mkdir -p "$work/ui/js"
printf '<!DOCTYPE html><title>the pages</title>\n' > "$work/ui/index.html"
printf 'export const here = 1;\n' > "$work/ui/js/app.js"
printf 'not for a browser\n' > "$work/secret"

# ui PATH [CURL OPTION...] -- the status of PATH under the API's own address.
ui() { local path=$1; shift; curl -s --max-time 30 -o "$work/body" -D "$work/head" -w '%{http_code}' "$@" "http://127.0.0.1:$API_PORT$path"; }
# header NAME -- the value of that header in the last answer, or nothing.
header() { tr -d '\r' < "$work/head" | grep -i "^$1: " | cut -d' ' -f2- || true; }

# No xymond is needed: the pages are files.
export XYMON="$XYMONCLIENT" XYMSRV="127.0.0.1:1"

# 1. A directory named by XYMONAPI_UI.
export XYMONAPI_UI="$work/ui"
start_api
assert_contains "serving the web pages in $work/ui" "$(cat "$work/api.log")" "the log says which directory is served"

assert_equal "200" "$(ui /xymon/ui/)" "/xymon/ui/ with XYMONAPI_UI"
assert_contains 'the pages' "$(cat "$work/body")" "is the directory's index.html"
assert_equal "no-cache" "$(header cache-control)" "and a browser is told to ask again"

assert_equal "200" "$(ui /xymon/ui/js/app.js)" "a file of the directory"
assert_contains 'export const here' "$(cat "$work/body")" "is answered as it is"
assert_equal "no-cache" "$(header cache-control)" "with the same Cache-Control"
etag=$(header etag)
[ -n "$etag" ] || fail "a file is answered without an ETag: $(cat "$work/head")"
assert_equal "304" "$(ui /xymon/ui/js/app.js -H "If-None-Match: $etag")" "asked again with its ETag, the file is not sent again"

assert_equal "404" "$(ui /xymon/ui/js/none.js)" "a file that is not there"
assert_contains '"error":"not_found"' "$(cat "$work/body")" "is the API's own not_found"
assert_equal "404" "$(ui /xymon/ui/..%2Fsecret)" "a path out of the directory"
assert_not_contains 'not for a browser' "$(cat "$work/body")" "reaches nothing outside it"

# The API's own answers are left as they were.
ui /xymon/api/v1/health > /dev/null
assert_equal "" "$(header cache-control)" "an answer of the API carries no Cache-Control of the pages"
stop_process "$API_PID"; API_PID=""

# 2. With a password, the pages ask for it too.
if command -v htpasswd >/dev/null 2>&1; then
	htpasswd -cb "$work/htpasswd" alice secret 2>/dev/null
	XYMONAPI_PASSWD="$work/htpasswd" start_api
	assert_equal "401" "$(ui /xymon/ui/)" "the pages without a user, where a password is set"
	assert_equal "200" "$(ui /xymon/ui/ -u alice:secret)" "and with one"
	stop_process "$API_PID"; API_PID=""
fi

# 3. Set empty: no pages.
XYMONAPI_UI="" start_api
assert_equal "404" "$(ui /xymon/ui/)" "/xymon/ui/ with XYMONAPI_UI set empty"
assert_not_contains "serving the web pages" "$(cat "$work/api.log")" "and the log says nothing of pages"
stop_process "$API_PID"; API_PID=""

# 4. Not a directory: the API does not start, and says which setting.
rc=0
XYMONAPI_UI="$work/no-such-directory" XYMONAPI_LISTEN="127.0.0.1:$API_PORT" \
	"$ROOT/plugins/xymonapi/xymonapi.sh" > "$work/bad.log" 2>&1 || rc=$?
assert_equal "1" "$rc" "the API with an XYMONAPI_UI that is no directory"
assert_contains "XYMONAPI_UI=$work/no-such-directory is not a directory" "$(cat "$work/bad.log")" "and says so"

pass "the API serves the pages of XYMONAPI_UI at /xymon/ui/ with Cache-Control: no-cache, behind its password, and none when the setting is empty"
