#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <unity-project> <package.unitypackage> [...]" >&2
  exit 2
fi

project_path="$(cd "$1" && pwd)"
shift

for package_path in "$@"; do
  if [[ ! -f "$package_path" ]]; then
    echo "Unity package not found: $package_path" >&2
    exit 2
  fi

  unpack_path="$(mktemp -d)"
  trap 'rm -rf "$unpack_path"' EXIT
  tar -xzf "$package_path" -C "$unpack_path"

  while IFS= read -r pathname_file; do
    asset_path="$(tr -d '\r\n' < "$pathname_file")"
    if [[ "$asset_path" != Assets/* ]]; then
      echo "Refusing package entry outside Assets: $asset_path" >&2
      exit 3
    fi

    entry_path="$(dirname "$pathname_file")"
    destination="$project_path/$asset_path"
    if [[ -f "$entry_path/asset" ]]; then
      mkdir -p "$(dirname "$destination")"
      if [[ -f "$destination" ]] && ! cmp -s "$entry_path/asset" "$destination"; then
        echo "Conflicting package asset: $asset_path" >&2
        exit 4
      fi
      cp "$entry_path/asset" "$destination"
    else
      mkdir -p "$destination"
    fi

    if [[ -f "$entry_path/asset.meta" ]]; then
      meta_destination="$destination.meta"
      if [[ -f "$meta_destination" ]] && ! cmp -s "$entry_path/asset.meta" "$meta_destination"; then
        echo "Conflicting package metadata: $asset_path.meta" >&2
        exit 4
      fi
      cp "$entry_path/asset.meta" "$meta_destination"
    fi
  done < <(find "$unpack_path" -type f -name pathname | sort)

  rm -rf "$unpack_path"
  trap - EXIT
  echo "Imported $(basename "$package_path")"
done
