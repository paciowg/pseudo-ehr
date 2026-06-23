#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTGRES_DATA_DIR="${POSTGRES_DATA_DIR:-/opt/homebrew/var/postgresql@14}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
REQUIRED_BUNDLER_VERSION="${REQUIRED_BUNDLER_VERSION:-2.4.12}"
SKIP_INSTALL=false

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage: scripts/start_pseudo_ehr.sh [options]

Set up the local PseudoEHR environment, start PostgreSQL, prepare the Rails
database, and launch the app with ./bin/dev.

Options:
  --skip-install   Do not install missing Bundler, gems, or JavaScript packages
  -h, --help       Show this help text

Environment overrides:
  POSTGRES_DATA_DIR   PostgreSQL data directory (default: /opt/homebrew/var/postgresql@14)
  PGHOST              PostgreSQL host (default: 127.0.0.1)
  PGPORT              PostgreSQL port (default: 5432)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-install)
      SKIP_INSTALL=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

find_rbenv() {
  if command -v rbenv >/dev/null 2>&1; then
    command -v rbenv
  elif [[ -x /opt/homebrew/bin/rbenv ]]; then
    printf '%s\n' /opt/homebrew/bin/rbenv
  elif [[ -x "$HOME/.rbenv/bin/rbenv" ]]; then
    printf '%s\n' "$HOME/.rbenv/bin/rbenv"
  fi
}

wait_for_postgres() {
  local tries=30

  if ! command -v pg_isready >/dev/null 2>&1; then
    log "pg_isready not found; skipping PostgreSQL readiness check"
    return
  fi

  until pg_isready -q -h "$PGHOST" -p "$PGPORT"; do
    tries=$((tries - 1))
    if [[ "$tries" -le 0 ]]; then
      fail "PostgreSQL did not become ready at $PGHOST:$PGPORT"
    fi
    sleep 1
  done
}

start_postgres() {
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -q -h "$PGHOST" -p "$PGPORT"; then
    log "PostgreSQL is already running at $PGHOST:$PGPORT"
    return
  fi

  command -v pg_ctl >/dev/null 2>&1 || fail "pg_ctl was not found. Install/start PostgreSQL, then retry."
  [[ -d "$POSTGRES_DATA_DIR" ]] || fail "PostgreSQL data directory not found: $POSTGRES_DATA_DIR"

  log "Starting PostgreSQL from $POSTGRES_DATA_DIR"
  pg_ctl -D "$POSTGRES_DATA_DIR" start
  wait_for_postgres
}

cd "$APP_ROOT"

RBENV_BIN="$(find_rbenv || true)"
if [[ -n "$RBENV_BIN" ]]; then
  log "Loading rbenv from $RBENV_BIN"
  RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"
  export RBENV_ROOT
  export PATH="$RBENV_ROOT/shims:$PATH"

  set +e
  RBENV_INIT="$("$RBENV_BIN" init - bash 2>/dev/null)"
  RBENV_INIT_STATUS=$?
  if [[ "$RBENV_INIT_STATUS" -eq 0 && -n "$RBENV_INIT" ]]; then
    eval "$RBENV_INIT"
  fi
  set -e
fi

if [[ -f .ruby-version ]]; then
  expected_ruby="$(<.ruby-version)"
  current_ruby="$(ruby -e 'print RUBY_VERSION')"
  if [[ "$current_ruby" != "$expected_ruby" ]]; then
    fail "Ruby $expected_ruby is required, but current Ruby is $current_ruby. Check rbenv setup."
  fi
fi

log "Using Ruby $(ruby -e 'print RUBY_VERSION')"
unset BUNDLE_FORCE_RUBY_PLATFORM

if ! gem list bundler -i -v "$REQUIRED_BUNDLER_VERSION" --silent; then
  if [[ "$SKIP_INSTALL" == "true" ]]; then
    fail "Bundler $REQUIRED_BUNDLER_VERSION is not installed. Retry without --skip-install."
  fi

  log "Installing Bundler $REQUIRED_BUNDLER_VERSION"
  gem install bundler -v "$REQUIRED_BUNDLER_VERSION"
fi

log "Checking Ruby gems"
if ! bundle check; then
  if [[ "$SKIP_INSTALL" == "true" ]]; then
    fail "Ruby gems are missing. Retry without --skip-install."
  fi

  bundle install
fi

if [[ -f yarn.lock ]]; then
  command -v yarn >/dev/null 2>&1 || fail "yarn was not found. Install Yarn, then retry."
  if [[ ! -d node_modules ]]; then
    if [[ "$SKIP_INSTALL" == "true" ]]; then
      fail "node_modules is missing. Retry without --skip-install."
    fi

    log "Installing JavaScript packages"
    yarn install
  fi
fi

export PGHOST
export PGPORT
start_postgres

log "Preparing Rails database"
bundle exec rails db:prepare

log "Starting PseudoEHR at http://localhost:3000"
exec ./bin/dev
