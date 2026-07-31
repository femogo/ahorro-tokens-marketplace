#!/usr/bin/env bash
# Lista los ficheros CLAUDE.md/CLAUDE.local.md relevantes para el directorio
# de trabajo actual, siguiendo cómo los descubre Claude Code (ver
# code.claude.com/docs/en/memory#how-claude-md-files-load):
#
# - "ancestros": el directorio actual y cada directorio padre hasta la raíz
#   del filesystem. Se cargan enteros en cada sesión (coste garantizado).
# - "anidados": subdirectorios bajo el directorio actual. Solo se cargan si
#   Claude llega a leer un fichero de esa subcarpeta durante la sesión (coste
#   no garantizado, no se debe sumar como always-on).
set -euo pipefail

start="$PWD"

echo "## ancestros"
dir="$start"
while true; do
  for name in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
    [ -f "$dir/$name" ] && echo "$dir/$name"
  done
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

echo "## anidados"
find "$start" -mindepth 2 \( -name .git -o -name node_modules \) -prune -o \
  \( -name "CLAUDE.md" -o -name "CLAUDE.local.md" \) -print 2>/dev/null
