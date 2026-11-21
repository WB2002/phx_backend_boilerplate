#!/usr/bin/env bash
# shellcheck shell=bash
# Make `mix` available in non-interactive subshells (Cursor hooks, git hooks, CI-like local runs).

VERIFY_MIX_DOCKER_IMAGE="${VERIFY_MIX_DOCKER_IMAGE:-phx_backend_boilerplate:verify-mix}"

toolchain_prepend_path() {
  local dir="$1"
  if [ -d "$dir" ]; then
    export PATH="$dir:$PATH"
  fi
}

# Cursor hooks and other minimal subshells often omit Docker Desktop / Homebrew paths.
toolchain_prepend_path /Applications/Docker.app/Contents/Resources/bin
toolchain_prepend_path "$HOME/.docker/bin"
toolchain_prepend_path /opt/homebrew/sbin
toolchain_prepend_path /usr/sbin

toolchain_resolve_executable() {
  local name="$1"
  shift

  if [ -n "${!name:-}" ] && [ -x "${!name}" ]; then
    printf '%s\n' "${!name}"
    return 0
  fi

  if command -v "$1" >/dev/null 2>&1; then
    command -v "$1"
    return 0
  fi

  local candidate
  for candidate in "$@"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
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

DOCKER_BIN="${DOCKER_BIN:-}"
if resolved_docker="$(toolchain_resolve_executable DOCKER_BIN docker \
  /Applications/Docker.app/Contents/Resources/bin/docker \
  "$HOME/.docker/bin/docker" \
  /opt/homebrew/bin/docker \
  /usr/local/bin/docker)"; then
  DOCKER_BIN="$resolved_docker"
  export DOCKER_BIN
  toolchain_prepend_path "$(dirname "$DOCKER_BIN")"
fi

toolchain_docker() {
  if [ -z "${DOCKER_BIN:-}" ]; then
    echo "error: docker binary not found" >&2
    return 127
  fi
  "$DOCKER_BIN" "$@"
}

toolchain_ensure_verify_mix_image() {
  if toolchain_docker image inspect "$VERIFY_MIX_DOCKER_IMAGE" >/dev/null 2>&1; then
    return 0
  fi

  if [ -z "${DOCKER_BIN:-}" ]; then
    return 1
  fi

  local root="${TOOLCHAIN_ROOT:?TOOLCHAIN_ROOT must be set}"
  echo "verify: building $VERIFY_MIX_DOCKER_IMAGE (one-time)..." >&2
  toolchain_docker build -f "$root/scripts/Dockerfile.verify" -t "$VERIFY_MIX_DOCKER_IMAGE" "$root/scripts"
}

toolchain_prepare_docker_workdir() {
  local root="${TOOLCHAIN_ROOT:?}"

  if [ -n "${TOOLCHAIN_DOCKER_WORKDIR:-}" ]; then
    return 0
  fi

  TOOLCHAIN_DOCKER_WORKDIR="$(mktemp -d /tmp/phx-verify.XXXXXX)"
  export TOOLCHAIN_DOCKER_WORKDIR

  # Docker Desktop often cannot mount ~/Documents; verify uses /tmp instead.
  rsync -a \
    --exclude .git \
    --exclude .toolchain \
    "${root}/" "${TOOLCHAIN_DOCKER_WORKDIR}/"
}

toolchain_mix_docker() {
  local root="${TOOLCHAIN_ROOT:?TOOLCHAIN_ROOT must be set}"
  toolchain_ensure_verify_mix_image || return 127
  toolchain_prepare_docker_workdir

  local -a docker_env=(
    -e "HOME=/tmp"
  )
  local -a docker_run_opts=(
    --rm
    --user "$(id -u):$(id -g)"
    -v "${TOOLCHAIN_DOCKER_WORKDIR}:/app"
    -w /app
    --add-host=host.docker.internal:host-gateway
  )

  if [ "${1:-}" = "test" ]; then
    docker_env+=(
      -e "MIX_ENV=test"
      -e "PGPORT=5433"
      -e "DATABASE_URL=${DATABASE_URL:-ecto://postgres:postgres@host.docker.internal:5433/phx_backend_boilerplate_test}"
      -e "REDIS_URL=${REDIS_URL:-redis://host.docker.internal:6379/1}"
    )
  fi

  toolchain_docker run "${docker_run_opts[@]}" "${docker_env[@]}" \
    --entrypoint bash "$VERIFY_MIX_DOCKER_IMAGE" \
    -ec '
      mix local.hex --force >/dev/null 2>&1
      mix local.rebar --force >/dev/null 2>&1
      if [ ! -f deps/.verify_fetched ]; then
        mix deps.get
        mkdir -p deps && touch deps/.verify_fetched
      fi
      exec mix "$@"
    ' \
    -- "$@"
}

if command -v mix >/dev/null 2>&1; then
  :
elif [ -n "${DOCKER_BIN:-}" ] && [ -n "${TOOLCHAIN_ROOT:-}" ]; then
  mix() {
    toolchain_mix_docker "$@"
  }
  export -f mix
  export TOOLCHAIN_MIX_VIA_DOCKER=1
  echo "verify: using Docker image $VERIFY_MIX_DOCKER_IMAGE for mix (set MIX_BIN to use host mix)." >&2
else
  echo "error: mix is not on PATH and Docker is unavailable for verify fallback." >&2
  echo "Install Elixir (Homebrew, asdf, or mise), set MIX_BIN, or install Docker." >&2
  exit 127
fi