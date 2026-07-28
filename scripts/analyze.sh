#!/usr/bin/env bash
# Static analysis for Studs, with the Roblox API actually loaded.
#
# Plain `luau-analyze` knows nothing about Roblox: every file reports
# "Unknown global 'game'" and it only ever catches syntax and scope errors.
# This runs luau-lsp instead, with the Roblox global type definitions and a
# Rojo sourcemap, so `require` paths and instance types resolve for real.
#
#   ./scripts/analyze.sh              # analyze src/
#   ./scripts/analyze.sh src/Foo.luau # analyze one file
#   ./scripts/analyze.sh --refresh    # re-download the type definitions first
#
# Refresh the definitions every month or two — they track live Roblox APIs.

set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="globalTypes.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

if [ "${1:-}" = "--refresh" ]; then
	shift
	echo "Refreshing $DEFS ..."
	curl -sSfL -o "$DEFS.tmp" "$DEFS_URL"
	mv "$DEFS.tmp" "$DEFS"
fi

if [ ! -f "$DEFS" ]; then
	echo "Missing $DEFS — fetching it (run with --refresh to update later)."
	curl -sSfL -o "$DEFS" "$DEFS_URL"
fi

rojo sourcemap default.project.json -o sourcemap.json

exec luau-lsp analyze \
	--sourcemap=sourcemap.json \
	--definitions="$DEFS" \
	"${@:-src/}"
