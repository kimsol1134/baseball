#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rustup_home="$repository_root/.toolchains/rustup"
cargo_home="$repository_root/.toolchains/cargo"

if [ ! -x "$cargo_home/bin/cargo" ]; then
  mkdir -p "$repository_root/.toolchains"
  temporary_directory=$(mktemp -d)
  installer="$temporary_directory/rustup-init.sh"
  trap 'rm -f "$installer"; rmdir "$temporary_directory" 2>/dev/null || true' EXIT

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$installer"
  RUSTUP_HOME="$rustup_home" CARGO_HOME="$cargo_home" \
    sh "$installer" -y --profile minimal --no-modify-path
fi

RUSTUP_HOME="$rustup_home" CARGO_HOME="$cargo_home" \
  "$cargo_home/bin/rustup" component add rustfmt

RUSTUP_HOME="$rustup_home" CARGO_HOME="$cargo_home" \
  "$cargo_home/bin/cargo" --version
