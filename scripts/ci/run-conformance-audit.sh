#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

resolve_audit_bin() {
  if [[ -n "${CONFORMANCE_AUDIT_BIN:-}" && -x "${CONFORMANCE_AUDIT_BIN}" ]]; then
    echo "${CONFORMANCE_AUDIT_BIN}"
    return 0
  fi

  local candidates=(
    "${ROOT_DIR}/.conformance-runner/bin/conformance-audit"
    "${ROOT_DIR}/../backend_security_and_conformance_tests/bin/conformance-audit"
    "${ROOT_DIR}/../backend_boilerplate_conformance_tests/bin/conformance-audit"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  if command -v conformance-audit >/dev/null 2>&1; then
    command -v conformance-audit
    return 0
  fi

  local src_dirs=(
    "${ROOT_DIR}/.conformance-runner"
    "${ROOT_DIR}/../backend_security_and_conformance_tests"
    "${ROOT_DIR}/../backend_boilerplate_conformance_tests"
  )
  if command -v go >/dev/null 2>&1; then
    for src_dir in "${src_dirs[@]}"; do
      if [[ -f "${src_dir}/cmd/conformance-audit/main.go" ]]; then
        mkdir -p "${src_dir}/bin"
        (cd "${src_dir}" && go build -o bin/conformance-audit ./cmd/conformance-audit) >&2
        echo "${src_dir}/bin/conformance-audit"
        return 0
      fi
    done
  fi

  echo "Error: conformance-audit binary not found. Set CONFORMANCE_AUDIT_BIN or build ../backend_boilerplate_conformance_tests." >&2
  return 1
}

AUDIT_BIN="$(resolve_audit_bin)"

STAGES="sast,graph,pentest,load"
HAS_URL=false

args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  arg="${args[$i]}"
  case "${arg}" in
    --stages=*)
      STAGES="${arg#--stages=}"
      ;;
    --stages)
      if ((i + 1 < ${#args[@]})); then
        STAGES="${args[$((i + 1))]}"
      fi
      ;;
    --url=*|--url)
      HAS_URL=true
      ;;
  esac
done

is_static_only() {
  local remaining="$1"
  local stage=""
  while [[ -n "${remaining}" ]]; do
    if [[ "${remaining}" == *,* ]]; then
      stage="${remaining%%,*}"
      remaining="${remaining#*,}"
    else
      stage="${remaining}"
      remaining=""
    fi
    case "${stage}" in
      sast|graph) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

if is_static_only "${STAGES}" && [[ "${HAS_URL}" == "false" ]]; then
  exec "${AUDIT_BIN}" \
    --target "${ROOT_DIR}" \
    --manifest "${ROOT_DIR}/boilerplate.manifest.json" \
    "$@"
fi

if [[ "${SKIP_APP_BOOT:-false}" == "true" ]]; then
  exec "${AUDIT_BIN}" \
    --target "${ROOT_DIR}" \
    --manifest "${ROOT_DIR}/boilerplate.manifest.json" \
    "$@"
fi

USER_PORT="${PORT:-}"
USER_DATABASE_URL="${DATABASE_URL:-}"
USER_REDIS_URL="${REDIS_URL:-}"
USER_SECRET_KEY_BASE="${SECRET_KEY_BASE:-}"
USER_ACCESS_TOKEN_SECRET="${ACCESS_TOKEN_SECRET:-}"
USER_REFRESH_TOKEN_SECRET="${REFRESH_TOKEN_SECRET:-}"

if [[ -f "${ROOT_DIR}/.env.conformance.example" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env.conformance.example"
  set +a
fi

export MIX_ENV="${MIX_ENV:-prod}"
export PHX_SERVER=true
export PHX_HOST="${PHX_HOST:-127.0.0.1}"
export PORT="${USER_PORT:-${PORT:-4000}}"
export DATABASE_URL="${USER_DATABASE_URL:-${DATABASE_URL:-ecto://postgres:postgres@127.0.0.1:5432/phx_backend_boilerplate_conformance}}"
export REDIS_URL="${USER_REDIS_URL:-${REDIS_URL:-redis://127.0.0.1:6379/2}}"
export POOL_SIZE="${POOL_SIZE:-10}"
export STRIPE_SKIP="${STRIPE_SKIP:-true}"
export RECAPTCHA_SECRET_KEY="${RECAPTCHA_SECRET_KEY:-conformance-recaptcha-placeholder}"
export CLOUDWATCH_LOGS_ENABLED=false
export CLOUDWATCH_METRICS_ENABLED=false
export OTEL_TRACES_ENABLED=false
export CORS_ORIGINS="${CORS_ORIGINS:-http://localhost:3000,http://127.0.0.1:3000}"

gen_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 48
  else
    head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

export SECRET_KEY_BASE="${USER_SECRET_KEY_BASE:-$(gen_secret)}"
export ACCESS_TOKEN_SECRET="${USER_ACCESS_TOKEN_SECRET:-$(gen_secret)}"
export REFRESH_TOKEN_SECRET="${USER_REFRESH_TOKEN_SECRET:-$(gen_secret)}"

APP_PID=""

cleanup() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" 2>/dev/null; then
    kill "${APP_PID}" 2>/dev/null || true
    wait "${APP_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

RELEASE_DIR="${CONFORMANCE_RELEASE_DIR:-${ROOT_DIR}/_build/${MIX_ENV}/rel/phx_backend_boilerplate}"
RELEASE_BIN="${RELEASE_DIR}/bin/phx_backend_boilerplate"

if [[ "${SKIP_APP_BUILD:-false}" != "true" ]]; then
  mix deps.get --only "${MIX_ENV}"
  mix compile
  mix assets.deploy
  mix release --overwrite
fi

CONFORMANCE_APP_CMD="${CONFORMANCE_APP_CMD:-}"
if [[ -n "${CONFORMANCE_APP_CMD}" ]]; then
  # Allow tests to inject a stub server command
  # shellcheck disable=SC2086
  ${CONFORMANCE_APP_CMD} > /tmp/phx-conformance.log 2>&1 &
  APP_PID=$!
else
  if [[ ! -x "${RELEASE_BIN}" ]]; then
    echo "Error: Phoenix release binary not found at ${RELEASE_BIN}. Run with SKIP_APP_BUILD=false or build the release first." >&2
    exit 1
  fi

  "${RELEASE_DIR}/bin/migrate" > /tmp/phx-conformance-migrate.log 2>&1 || {
    echo "Error: Database migration failed. Logs:" >&2
    cat /tmp/phx-conformance-migrate.log >&2 || true
    exit 1
  }

  "${RELEASE_DIR}/bin/server" > /tmp/phx-conformance.log 2>&1 &
  APP_PID=$!
fi

HEALTH_URL="http://127.0.0.1:${PORT}/health"
READY=false
for _ in $(seq 1 45); do
  if ! kill -0 "${APP_PID}" 2>/dev/null; then
    echo "Error: Phoenix app exited prematurely. Logs:" >&2
    cat /tmp/phx-conformance.log >&2 || true
    exit 1
  fi
  HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' "${HEALTH_URL}" || true)"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    READY=true
    break
  fi
  sleep 1
done

if [[ "${READY}" != "true" ]]; then
  echo "Error: Timed out waiting for ${HEALTH_URL}. Logs:" >&2
  cat /tmp/phx-conformance.log >&2 || true
  exit 1
fi

# Warm up BEAM schedulers, Bandit connection pools, and allocators before RSS baseline sampling.
for _ in $(seq 1 200); do
  curl -s -o /dev/null "${HEALTH_URL}" || true
done
sleep 1

# Resolve the BEAM VM PID if the release wrapper forked a child beam.smp process.
TARGET_PID="${APP_PID}"
if command -v pgrep >/dev/null 2>&1; then
  BEAM_PID="$(pgrep -P "${APP_PID}" -f beam.smp 2>/dev/null | head -n 1 || true)"
  if [[ -n "${BEAM_PID}" ]]; then
    TARGET_PID="${BEAM_PID}"
  fi
fi

export CONFORMANCE_TARGET_PID="${TARGET_PID}"

AUDIT_HELP="$("${AUDIT_BIN}" --help 2>&1 || true)"
EXTRA_AUDIT_ARGS=()
if grep -qE '(^|[[:space:]])--?pid([[:space:]=]|$)' <<< "${AUDIT_HELP}"; then
  EXTRA_AUDIT_ARGS+=(--pid "${TARGET_PID}")
fi

"${AUDIT_BIN}" \
  --target "${ROOT_DIR}" \
  --manifest "${ROOT_DIR}/boilerplate.manifest.json" \
  --url "http://127.0.0.1:${PORT}" \
  ${EXTRA_AUDIT_ARGS[@]+"${EXTRA_AUDIT_ARGS[@]}"} \
  "$@"
