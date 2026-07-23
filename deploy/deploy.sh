#!/bin/bash
SOURCED=false && [ "$0" = "$BASH_SOURCE" ] || SOURCED=true

if ! $SOURCED; then
  set -euo pipefail
  IFS=$'\n\t'
fi

is_remote_path() {
  local value="$1"

  # Require at least one slash after the colon
  if [[ "$value" =~ ^([^@:/]+@)?[^:/]+:/ ]]; then
      return 0
  else
      return 1
  fi
}

# Returns: "<host>\t<dir>" on stdout if remote, else returns 1.
# Accepts: host:/path, user@host:/path, host:rel/path
parse_remote_path() {
  local value="$1"

  # Match: [user@]host:dir
  if [[ "$value" =~ ^([^@:/]+@)?([^:/]+):(.+)$ ]]; then
    local user_prefix="${BASH_REMATCH[1]}"  # "user@" or empty
    local host="${BASH_REMATCH[2]}"
    local dir="${BASH_REMATCH[3]}"

    # host_for_ssh should include user@ if present
    local host_for_ssh="${user_prefix}${host}"

    printf '%s\t%s\n' "$host_for_ssh" "$dir"
    return 0
  fi

  return 1
}

# Create remote directory for a remote path (mkdir -p).
# Usage: ensure_remote_dir "user@host:/some/dir"
ensure_remote_dir() {
  local remote="$1"
  local parsed host dir

  parsed="$(parse_remote_path "$remote")" || {
    echo "Not a remote path: $remote" >&2
    return 1
  }

  # Split tab-separated output into host and dir
  IFS=$'\t' read -r host dir <<< "$parsed"

  # Create directory safely (handles spaces etc.)
  ssh -- "$host" "mkdir -pv -- $dir"
}


scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
repo_dir="$(realpath "$scriptdir/..")"

# shellcheck disable=SC1090
source "$scriptdir/.env"

(
  cd "$repo_dir"
  if is_remote_path "$TARGET_DIR"; then
    # Remote path
    ensure_remote_dir "$TARGET_DIR"
  else
    # Local path
    mkdir -pv "$TARGET_DIR"
  fi

  rsync -av \
        --exclude-from='deploy/.deployignore' \
        --no-owner \
        --no-group \
        --no-perms \
        --omit-dir-times \
          . \
          "$TARGET_DIR"
)

exit 0
