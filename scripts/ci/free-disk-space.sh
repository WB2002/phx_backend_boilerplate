#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_ACTIONS:-false}" != "true" ]]; then
  echo "free-disk-space: skipping (not running in GitHub Actions)"
  exit 0
fi

echo "== Disk usage before cleanup =="
df -h /

# Remove large unused pre-installed toolchains on GitHub ubuntu-latest runners.
# Keeps /opt/hostedtoolcache (Erlang/Elixir, Go, Python, CodeQL) and running service containers.
UNUSED_PATHS=(
  /usr/local/lib/android
  /usr/share/dotnet
  /opt/ghc
  /usr/local/.ghcup
  /usr/share/swift
  /usr/local/share/boost
  /usr/share/miniconda
  /usr/local/share/powershell
  /usr/local/julia*
)

sudo rm -rf "${UNUSED_PATHS[@]}"
sudo apt-get clean >/dev/null 2>&1 || true

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker image prune -af >/dev/null 2>&1 || true
fi

echo "== Disk usage after cleanup =="
df -h /
