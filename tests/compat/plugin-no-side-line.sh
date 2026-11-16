#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# tests/compat/plugin-no-side-line.sh
#
# No PLUGIN file has a side: line. The parts a plugin has are those its
# server-*, client-* and tools-* lines declare (SPEC.md, Planned: a plugin
# has up to three parts); a side: line said the same thing a second time,
# and called the tools part "client".

set -euo pipefail
# shellcheck source=tests/lib/xymonapi.sh
. "$(dirname "$0")/../lib/xymonapi.sh"

ROOT=$(find_root)
found=
for f in "$ROOT"/plugins/*/PLUGIN; do
	if grep -q '^side:' "$f"; then found="$found ${f#"$ROOT"/}"; fi
done
[ -z "$found" ] || fail "a side: line, which the parts a plugin declares replace, is in:$found"

pass "no PLUGIN file has a side: line"
