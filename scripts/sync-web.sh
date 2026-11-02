#!/usr/bin/env bash
# 把开发源 web/index.html 同步到仓库根目录（GitHub Pages 入口）
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cp "$HERE/web/index.html" "$HERE/index.html"
echo "synced: web/index.html -> index.html ($(wc -c < "$HERE/index.html") bytes)"
