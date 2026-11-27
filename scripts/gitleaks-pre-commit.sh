#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/.gitleaks.toml"
NATIVE_ARGS=(protect --staged --redact --no-banner --config "${CONFIG_FILE}")
DOCKER_ARGS=(protect --staged --redact --no-banner --config /repo/.gitleaks.toml)
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.21.2}"
GITLEAKS_TMP_STAGE=""

cleanup_tmp_stage() {
  if [[ -n "${GITLEAKS_TMP_STAGE}" && -d "${GITLEAKS_TMP_STAGE}" ]]; then
    rm -rf "${GITLEAKS_TMP_STAGE}"
    GITLEAKS_TMP_STAGE=""
  fi
}

trap cleanup_tmp_stage EXIT

print_docker_mount_help() {
  cat <<'EOF' >&2

Docker could not mount this repository path (common on macOS when the repo lives under ~/Documents).

Fix (recommended):
  brew install gitleaks

Or allow Docker to access Documents:
  System Settings -> Privacy & Security -> Files and Folders -> Docker -> enable Documents
  (Docker Desktop may also need a restart after changing permissions)
EOF
}

is_docker_mount_denied() {
  local stderr_file="$1"
  grep -qE 'operation not permitted|mkdir /host_mnt' "${stderr_file}" 2>/dev/null
}

run_docker_gitleaks() {
  local -a docker_run_args=("$@")
  local stderr_file
  stderr_file="$(mktemp)"
  local exit_code=0

  set +e
  docker run --rm "${docker_run_args[@]}" 2>"${stderr_file}"
  exit_code=$?
  set -e

  if [[ "${exit_code}" -ne 0 ]]; then
    if is_docker_mount_denied "${stderr_file}"; then
      rm -f "${stderr_file}"
      return 125
    fi
    cat "${stderr_file}" >&2
    rm -f "${stderr_file}"
    exit "${exit_code}"
  fi

  rm -f "${stderr_file}"
  return 0
}

rsync_repo_for_scan() {
  local destination="$1"
  if ! command -v rsync >/dev/null 2>&1; then
    echo "rsync is required to stage the repo under /tmp for Docker Gitleaks." >&2
    exit 1
  fi

  rsync -a \
    --exclude _build \
    --exclude deps \
    --exclude priv/plts \
    --exclude .worktrees \
    "${ROOT_DIR}/" "${destination}/"
}

stage_repo_under_tmp() {
  local worktree_name="${1:-}"
  GITLEAKS_TMP_STAGE="$(mktemp -d /tmp/gitleaks-precommit.XXXXXX)"
  local repo_mount="${GITLEAKS_TMP_STAGE}/repo"

  mkdir -p "${repo_mount}"
  rsync_repo_for_scan "${repo_mount}"

  if [[ -n "${worktree_name}" ]]; then
    local git_mount="${GITLEAKS_TMP_STAGE}/git"
    mkdir -p "${git_mount}"
    GIT_COMMON="$(cd "$(git -C "${ROOT_DIR}" rev-parse --git-common-dir)" && pwd -P)"
    rsync -a "${GIT_COMMON}/" "${git_mount}/"
    printf 'gitdir: /git/worktrees/%s\n' "${worktree_name}" >"${repo_mount}/.git"
    printf '%s\n%s' "${repo_mount}" "${git_mount}"
    return
  fi

  printf '%s\n' "${repo_mount}"
}

run_gitleaks_docker_normal() {
  local repo_mount="$1"
  local -a run_args=(
    -v "${repo_mount}:/repo"
    -w /repo
    "${GITLEAKS_IMAGE}"
    "${DOCKER_ARGS[@]}"
  )
  run_docker_gitleaks "${run_args[@]}"
}

run_gitleaks_docker_worktree() {
  local repo_mount="$1"
  local git_mount="$2"
  local worktree_name="$3"
  local -a run_args=(
    -v "${repo_mount}:/repo"
    -v "${git_mount}:/git"
    -e "GIT_DIR=/git/worktrees/${worktree_name}"
    -e GIT_COMMON_DIR=/git
    -e GIT_WORK_TREE=/repo
    -w /repo
    "${GITLEAKS_IMAGE}"
    "${DOCKER_ARGS[@]}"
  )
  run_docker_gitleaks "${run_args[@]}"
}

run_gitleaks_with_docker_fallbacks() {
  local is_worktree=0
  local worktree_name=""
  GIT_DIR="$(cd "$(git -C "${ROOT_DIR}" rev-parse --git-dir)" && pwd -P)"
  GIT_COMMON="$(cd "$(git -C "${ROOT_DIR}" rev-parse --git-common-dir)" && pwd -P)"

  if [[ "${GIT_DIR}" != "${GIT_COMMON}" ]]; then
    is_worktree=1
    worktree_name="$(basename "${GIT_DIR}")"
  fi

  if [[ "${is_worktree}" -eq 0 ]]; then
    if run_gitleaks_docker_normal "${ROOT_DIR}"; then
      return 0
    fi
  else
    if run_gitleaks_docker_worktree "${ROOT_DIR}" "${GIT_COMMON}" "${worktree_name}"; then
      return 0
    fi
  fi

  local stage_paths
  if [[ "${is_worktree}" -eq 1 ]]; then
    stage_paths="$(stage_repo_under_tmp "${worktree_name}")"
    local repo_mount git_mount
    repo_mount="$(printf '%s\n' "${stage_paths}" | sed -n '1p')"
    git_mount="$(printf '%s\n' "${stage_paths}" | sed -n '2p')"
    if run_gitleaks_docker_worktree "${repo_mount}" "${git_mount}" "${worktree_name}"; then
      return 0
    fi
  else
    stage_paths="$(stage_repo_under_tmp)"
    repo_mount="$(printf '%s\n' "${stage_paths}" | sed -n '1p')"
    if run_gitleaks_docker_normal "${repo_mount}"; then
      return 0
    fi
  fi

  print_docker_mount_help
  exit 125
}

if command -v gitleaks >/dev/null 2>&1; then
  cd "${ROOT_DIR}"
  exec gitleaks "${NATIVE_ARGS[@]}"
fi

if command -v docker >/dev/null 2>&1; then
  run_gitleaks_with_docker_fallbacks
  exit 0
fi

cat <<'EOF' >&2
gitleaks is required for pre-commit secrets scanning but was not found.

Install one of:
  brew install gitleaks
  # or use Docker (zricethezav/gitleaks:v8.21.2) and ensure `docker` is on PATH

Then re-run your commit.
EOF
exit 1
