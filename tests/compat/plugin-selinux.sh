#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/compat/plugin-selinux.sh
#
# A plugin's SELinux module, the selinux: line of its PLUGIN, NAME.cil: an
# install loads it with semodule where SELinux is active, and says how to
# set its boolean; an uninstall removes it, the module named after the
# plugin and no other, whatever the installed PLUGIN copy says; an update
# to a version without one removes it; where SELinux is not active, and
# under DESTDIR, nothing is loaded.
#
# selinuxenabled and semodule are stand-ins of the test's own, recording
# what they are asked; that semodule accepts xymonapi.cil is checked on an
# enforcing host, not here.

set -euo pipefail
# shellcheck source=tests/lib/xymonapi.sh
. "$(dirname "$0")/../lib/xymonapi.sh"

ROOT=$(find_root)
work=$(mktempdir)
mkdir -p "$work/bin"
# selinuxenabled exits as $work/enabled says; semodule logs its arguments.
printf '#!/bin/sh\nexit "$(cat %s/enabled)"\n' "$work" > "$work/bin/selinuxenabled"
printf '#!/bin/sh\necho "$*" >> %s/semodule.log\n' "$work" > "$work/bin/semodule"
chmod 755 "$work/bin/selinuxenabled" "$work/bin/semodule"
export PATH="$work/bin:$PATH"

home=$work/server
server_tree "$home"
run() { # ACTION LOG [ROOT] -- install.sh ACTION-server xymonapi
	"${3:-$ROOT}/install.sh" "$1-server" xymonapi XYMONHOME="$home" MANDIR="$work/man" </dev/null >"$work/$2.log" 2>&1 \
		|| fail "$1-server ($2) failed: $(tail -n 5 "$work/$2.log")"
}
log() { cat "$work/semodule.log" 2>/dev/null || true; }

# SELinux active: loaded, and the boolean named.
echo 0 > "$work/enabled"
run install active
assert_equal "-i $home/ext/xymonapi/xymonapi.cil" "$(log)" "[S23] where SELinux is active, the install loads the plugin's module"
assert_contains "setsebool -P xymonapi_relay on" "$(cat "$work/active.log")" "[S23] and says how to set its boolean"

# Uninstalled: removed, by the plugin's name, though the installed PLUGIN
# copy names another module.
: > "$work/semodule.log"
sed 's/^selinux: .*/selinux: httpd.cil/' "$home/ext/xymonapi/PLUGIN" > "$work/PLUGIN" && mv "$work/PLUGIN" "$home/ext/xymonapi/PLUGIN"
run uninstall gone
assert_equal "-r xymonapi" "$(log)" "[S23] the uninstall removes the module named after the plugin, and no other"

# SELinux not active: nothing loaded.
: > "$work/semodule.log"
echo 1 > "$work/enabled"
run install inactive
assert_equal "" "$(log)" "[S23] where SELinux is not active, nothing is loaded"
run uninstall inactive2

# Under DESTDIR: nothing loaded, and what to run said.
: > "$work/semodule.log"
echo 0 > "$work/enabled"
"$ROOT/install.sh" install-server xymonapi XYMONHOME=/srv/xymon DESTDIR="$work/stage" MANDIR=/usr/share/man </dev/null >"$work/stage.log" 2>&1 \
	|| fail "install-server under DESTDIR failed: $(tail -n 5 "$work/stage.log")"
assert_equal "" "$(log)" "[S23] under DESTDIR nothing is loaded"
assert_contains "semodule -i /srv/xymon/ext/xymonapi/xymonapi.cil" "$(cat "$work/stage.log")" "[S23] and the install says what to run on the installed system"

# An update to a version without a module removes the one loaded. A copy
# of the checkout plays that version.
next=$work/next
mkdir -p "$next"
cp -R "$ROOT/install.sh" "$ROOT/LICENSE" "$ROOT/plugins" "$next/"
sed '/^selinux: /d' "$next/plugins/xymonapi/PLUGIN" > "$work/PLUGIN" && mv "$work/PLUGIN" "$next/plugins/xymonapi/PLUGIN"
run install again
: > "$work/semodule.log"
run install next "$next"
assert_equal "-r xymonapi" "$(log)" "[S23] an update to a version without a module removes the one loaded"

pass "a plugin's SELinux module is loaded where SELinux is active, its boolean named, removed by its name with the plugin or by an update without it, and never loaded where SELinux is off or under DESTDIR"
