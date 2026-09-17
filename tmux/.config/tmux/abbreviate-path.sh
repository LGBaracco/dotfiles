#!/usr/bin/env bash
# Fish-style path: ~/p/t/directory (keep ~ and final segment full)
set -euo pipefail

path=${1-}
[[ -n $path ]] || exit 0

if [[ $path == "$HOME" || $path == "$HOME"/* ]]; then
  path="~${path#"$HOME"}"
fi

leading=
[[ $path == /* ]] && leading=/

IFS=/ read -ra parts <<<"$path"
out=()
last=$((${#parts[@]} - 1))

for i in "${!parts[@]}"; do
  part=${parts[$i]}
  [[ -n $part ]] || continue
  if ((i == last)) || [[ $part == '~' ]]; then
    out+=("$part")
  elif [[ $part == .* ]]; then
    out+=("${part:0:2}")
  else
    out+=("${part:0:1}")
  fi
done

(IFS=/; printf '%s%s\n' "$leading" "${out[*]}")
