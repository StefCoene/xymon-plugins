#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/compat/plugin-web-snippet.sh
#
# A plugin's web server snippets, the conf: line of its PLUGIN, are
# installed in ext/PLUGIN, where removing the plugin, or ext/PLUGIN by hand,
# takes them away; the web server includes them in a way that skips a file
# that is gone. An admin's edit survives an install. A snippet an older version shipped, found
# unedited, takes this version's -- recognised under any tree, its path
# put back as @XYMONHOME@; an edited one is kept, and said to differ. A tree whose path a web server's
# configuration may not take as it is is said.
#
# Installed into a scratch directory. That Apache's IncludeOptional and the
# wildcard include of nginx and lighttpd skip a missing file is the web
# servers' own behaviour, not run here.

set -euo pipefail
# shellcheck source=tests/lib/xymonapi.sh
. "$(dirname "$0")/../lib/xymonapi.sh"

ROOT=$(find_root)
work=$(mktempdir)
home=$work/server
server_tree "$home"
snippets=$(sed -n 's/^conf: *//p' "$ROOT/plugins/xymonapi/PLUGIN")
[ -n "$snippets" ] || fail "plugins/xymonapi/PLUGIN names no snippet"

install() { "$ROOT/install.sh" install-server xymonapi XYMONHOME="$home" MANDIR="$work/man" >"$work/$1.log" 2>&1 \
	|| fail "install-server ($1) failed: $(tail -n 5 "$work/$1.log")"; }

# A snippet as shipped, @XYMONHOME@ filled in as the task file's is.
shipped() { sed -e "s|@XYMONHOME@|$2|g" "$1"; }
install first
for c in $snippets; do
	shipped "$ROOT/plugins/xymonapi/$c" "$home" > "$work/shipped"
	cmp -s "$work/shipped" "$home/ext/xymonapi/$c" || fail "[S16] $c is not in ext/xymonapi as shipped, @XYMONHOME@ filled in"
	grep -q '@XYMONHOME@' "$home/ext/xymonapi/$c" && fail "[S16] $c still names @XYMONHOME@"
done
assert_contains "IncludeOptional" "$(cat "$work/first.log")" "[S16] the install says to include it with IncludeOptional"

echo "# the admin's port" >> "$home/ext/xymonapi/xymonapi-nginx.conf"
cp "$home/ext/xymonapi/xymonapi-nginx.conf" "$work/edited"
install again
cmp -s "$work/edited" "$home/ext/xymonapi/xymonapi-nginx.conf" || fail "[S16] an install undid the admin's edit to the nginx snippet"
[ -e "$home/ext/.xymonapi.xymonapi-nginx.conf" ] && fail "[S16] the snippet set aside was left in ext/"

"$ROOT/install.sh" uninstall-server xymonapi XYMONHOME="$home" MANDIR="$work/man" >/dev/null 2>&1 || fail "uninstall-server failed"
for c in $snippets; do
	[ -e "$home/ext/xymonapi/$c" ] && fail "[S16] uninstall-server left $c"
done

# A kept snippet that is, byte for byte, one an older version shipped --
# its PLUGIN file's conf-stock line gives it by cksum -- was never edited:
# the install puts this version's in its place. One edited is kept, and
# said to differ. Run from a copy of the checkout, its PLUGIN file given
# such a line for a made-up older nginx snippet.
repo=$work/repo
mkdir -p "$repo"
cp -R "$ROOT/install.sh" "$ROOT/LICENSE" "$ROOT/plugins" "$repo/"
printf '# an older version of the nginx snippet\nlocation /xymon/api/ { proxy_pass http://127.0.0.1:1986/xymon/api/; }\n' > "$work/stock-old"
echo "conf-stock: xymonapi-nginx.conf $(cksum < "$work/stock-old" | cut -d' ' -f1,2)" >> "$repo/plugins/xymonapi/PLUGIN"
home2=$work/server2
server_tree "$home2"
install2() { "$repo/install.sh" install-server xymonapi XYMONHOME="$home2" MANDIR="$work/man2" >"$work/$1.log" 2>&1 \
	|| fail "install-server ($1) failed: $(tail -n 5 "$work/$1.log")"; }
install2 fresh
cp "$work/stock-old" "$home2/ext/xymonapi/xymonapi-nginx.conf"
install2 stock
shipped "$repo/plugins/xymonapi/xymonapi-nginx.conf" "$home2" > "$work/shipped"
cmp -s "$work/shipped" "$home2/ext/xymonapi/xymonapi-nginx.conf" \
	|| fail "[S16] an older version's snippet, unedited, was not replaced by this version's"
assert_contains "an older version's as shipped, is replaced" "$(cat "$work/stock.log")" "[S16] and the install says so"
{ cat "$work/stock-old"; echo "# the admin's"; } > "$home2/ext/xymonapi/xymonapi-nginx.conf"
cp "$home2/ext/xymonapi/xymonapi-nginx.conf" "$work/edited2"
install2 edited
cmp -s "$work/edited2" "$home2/ext/xymonapi/xymonapi-nginx.conf" || fail "[S16] an edited older snippet was replaced"
assert_contains "is kept as edited; this version's differs" "$(cat "$work/edited.log")" "[S16] and the install says it differs"
shipped "$repo/plugins/xymonapi/xymonapi-nginx.conf" "$home2" > "$home2/ext/xymonapi/xymonapi-nginx.conf"
install2 same
assert_not_contains "xymonapi-nginx.conf" "$(cat "$work/same.log")" "[S16] a snippet as this version ships it is not spoken of"

# This version's snippets, installed under two different trees, are both
# recognised later as shipped: a next version listing this one's template
# by cksum replaces them. The copy of the checkout plays the next version,
# its nginx snippet changed and this one's listed.
next=$work/next
mkdir -p "$next"
cp -R "$ROOT/install.sh" "$ROOT/LICENSE" "$ROOT/plugins" "$next/"
echo "conf-stock: xymonapi-nginx.conf $(cksum < "$ROOT/plugins/xymonapi/xymonapi-nginx.conf" | cut -d' ' -f1,2)" >> "$next/plugins/xymonapi/PLUGIN"
echo "# the next version's" >> "$next/plugins/xymonapi/xymonapi-nginx.conf"
for h in "$work/treeA" "$work/tree B"; do
	server_tree "$h"
	"$ROOT/install.sh" install-server xymonapi XYMONHOME="$h" MANDIR="$work/manA" >/dev/null 2>&1 || fail "install-server under $h failed"
	"$next/install.sh" install-server xymonapi XYMONHOME="$h" MANDIR="$work/manA" >"$work/next.log" 2>&1 || fail "the next version's install under $h failed"
	assert_contains "# the next version's" "$(cat "$h/ext/xymonapi/xymonapi-nginx.conf")" "[S16] this version's snippet under $h is recognised as shipped, and replaced"
done
assert_contains "holds characters a web server's configuration may not take" "$(cat "$work/next.log")" \
	"[S16] a tree whose path a web server may not take as it is is said"

# Under a tree whose path is also part of the snippets' text -- /xymon in
# /xymon/api/ -- an older version's snippet, unedited, is still recognised.
# DESTDIR stages the tree at /xymon.
"$repo/install.sh" install-server xymonapi XYMONHOME=/xymon DESTDIR="$work/stage" MANDIR=/usr/share/man >/dev/null 2>&1 \
	|| fail "install-server under DESTDIR at /xymon failed"
cp "$work/stock-old" "$work/stage/xymon/ext/xymonapi/xymonapi-nginx.conf"
"$repo/install.sh" install-server xymonapi XYMONHOME=/xymon DESTDIR="$work/stage" MANDIR=/usr/share/man >"$work/xymon.log" 2>&1 \
	|| fail "install-server under DESTDIR at /xymon failed"
shipped "$repo/plugins/xymonapi/xymonapi-nginx.conf" /xymon > "$work/shipped"
cmp -s "$work/shipped" "$work/stage/xymon/ext/xymonapi/xymonapi-nginx.conf" \
	|| fail "[S16] under /xymon, an older version's snippet was taken for edited"

pass "a plugin's web server snippets live in ext/PLUGIN, keep the admin's edits, go with the plugin, and an older version's, unedited, is replaced by this one's"
