#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/compat/plugin-mandir-homebrew.sh
#
# With no MANDIR given, a server install puts its manual page under
# /usr/share/man, which macOS lets no one write -- unless Homebrew installed
# that Xymon, its XYMONHOME under brew --prefix: then under Homebrew's
# share/man, where man looks. A brew whose prefix XYMONHOME is not under
# changes nothing. A brew of the test's own stands for Homebrew's.

set -euo pipefail
# shellcheck source=tests/lib/xymonapi.sh
. "$(dirname "$0")/../lib/xymonapi.sh"

ROOT=$(find_root)
work=$(mktempdir)
mkdir -p "$work/bin"
printf '#!/bin/sh\n[ "$1" = --prefix ] && echo "%s/brew"\n' "$work" > "$work/bin/brew"
chmod 755 "$work/bin/brew"

home=$work/brew/opt/xymon-server/server
server_tree "$home"
env -u MANDIR PATH="$work/bin:$PATH" "$ROOT/xymon-plugin" install --server xymonapi XYMONHOME="$home" > "$work/install.log" 2>&1 \
	|| fail "install-server under Homebrew's prefix failed: $(tail -n 5 "$work/install.log")"
[ -L "$work/brew/share/man/man8/xymonapi.8" ] || fail "the manual page is not under Homebrew's share/man"

# Outside the prefix, MANDIR stays /usr/share/man: staged, to look.
other=$work/other
server_tree "$work/stage$other"
env -u MANDIR PATH="$work/bin:$PATH" "$ROOT/xymon-plugin" install --server xymonapi XYMONHOME="$other" DESTDIR="$work/stage" > "$work/other.log" 2>&1 \
	|| fail "install-server outside the prefix failed: $(tail -n 5 "$work/other.log")"
[ -L "$work/stage/usr/share/man/man8/xymonapi.8" ] || fail "outside Homebrew's prefix, the manual page is not under /usr/share/man"

pass "with no MANDIR, a Xymon Homebrew installed gets its manual pages under Homebrew's share/man, any other under /usr/share/man"
