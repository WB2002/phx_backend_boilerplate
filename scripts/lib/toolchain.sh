#!/usr/bin/env bash
# shellcheck shell=bash
# Make `mix` available in non-interactive subshells (Cursor hooks, git hooks, CI-like local runs).

toolchain_prepend_path() {
  local dir="$1"
  if [ -d "$dir" ]; then
    export PATH="$dir:$PATH"
  fi
}

if [ -x /opt/homebrew/bin/brew ]; then
  # shellcheck disable=SC1090
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  # shellcheck disable=SC1090
  eval "$(/usr/local/bin/brew shellenv)"
fi

toolchain_prepend_path /opt/homebrew/bin
toolchain_prepend_path /opt/homebrew/opt/elixir/bin
toolchain_prepend_path /usr/local/bin
toolchain_prepend_path /usr/local/opt/elixir/bin
toolchain_prepend_path "$HOME/.local/bin"
toolchain_prepend_path "$HOME/.asdf/shims"
toolchain_prepend_path "$HOME/.local/share/mise/shims"
toolchain_prepend_path "$HOME/.mise/shims"
toolchain_prepend_path "$HOME/.rtx/shims"

if [ -f "$HOME/.asdf/asdf.sh" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.asdf/asdf.sh"
fi

if command -v mise >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  eval "$(mise activate bash --shims 2>/dev/null || true)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  # shellcheck disable=SC1090
  eval "$("$HOME/.local/bin/mise" activate bash --shims 2>/dev/null || true)"
fi

if [ -n "${MIX_BIN:-}" ] && [ -x "$MIX_BIN" ]; then
  toolchain_prepend_path "$(dirname "$MIX_BIN")"
fi

if ! command -v mix >/dev/null 2>&1; then
  echo "error: mix is not on PATH." >&2
  echo "Install Elixir (asdf, mise, or Homebrew) or set MIX_BIN." >&2
  exit 127
fi
