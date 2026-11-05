#!/usr/bin/env bash
# Copies Libs/Pergamino into an addon folder: tools/vendor.sh /path/to/MyAddon
# Then add `Libs\Pergamino\Pergamino.lua` as the first file of the addon's TOC.
set -euo pipefail
dest="${1:?addon folder}"
src="$(cd "$(dirname "$0")/.." && pwd)/Libs/Pergamino"
mkdir -p "$dest/Libs"
rm -rf "$dest/Libs/Pergamino"
cp -r "$src" "$dest/Libs/Pergamino"
echo "Pergamino $(grep -o 'local VERSION = [0-9]*' "$src/Pergamino.lua" | grep -o '[0-9]*') copiada en $dest/Libs/Pergamino"
