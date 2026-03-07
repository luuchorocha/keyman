# ----------------- IO model -----------------

# UI output: /dev/tty when available, otherwise stderr.
# Return values: stdout ONLY (so command substitution is reliable).

tty_available() { [ -r /dev/tty ] && [ -w /dev/tty ]; }

ui_print() {
  if tty_available; then
    printf '%s' "$*" >/dev/tty
  else
    printf '%s' "$*" >&2
  fi
}

ui_println() {
  if tty_available; then
    printf '%s\n' "$*" >/dev/tty
  else
    printf '%s\n' "$*" >&2
  fi
}

trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

# ----------------- Colors -----------------

supports_color() {
  [ -n "$NO_COLOR" ] && return 1
  tty_available || return 1
  [ "${TERM:-}" = 'dumb' ] && return 1
  return 0
}

# Initialize color escape codes. Call once at startup.
# Sets C_BOLD, C_DIM, C_RED, etc. to ANSI codes or empty strings.
init_colors() {
  if supports_color; then
    C_BOLD="$(printf '\033[1m')"
    C_DIM="$(printf '\033[2m')"
    C_ULINE="$(printf '\033[4m')"
    C_RED="$(printf '\033[31m')"
    C_GRN="$(printf '\033[32m')"
    C_YEL="$(printf '\033[33m')"
    C_BLU="$(printf '\033[34m')"
    C_MAG="$(printf '\033[35m')"
    C_CYN="$(printf '\033[36m')"
    C_WHT="$(printf '\033[37m')"
    C_RST="$(printf '\033[0m')"
  else
    C_BOLD='' C_DIM='' C_ULINE='' C_RED='' C_GRN='' C_YEL='' C_BLU='' C_MAG='' C_CYN='' C_WHT='' C_RST=''
  fi
}

# ----------------- Logging -----------------

info() { ui_println "  ${C_CYN}ℹ${C_RST}  $*"; }
ok() { ui_println "  ${C_GRN}✓${C_RST}  $*"; }
warn() { ui_println "  ${C_YEL}⚠${C_RST}  $*"; }
err() { ui_println "  ${C_RED}✗${C_RST}  $*"; }

# Audit logging for security-sensitive operations (create, delete).
# Controlled by KEYMAN_LOG env var:
#   - 'syslog': log via logger(1) to auth.info facility
#   - <path>:  append to specified file
#   - empty:   disabled (no-op)
audit_log() {
  [ -z "$KEYMAN_LOG" ] && return 0
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
  user="${USER:-$(id -un 2>/dev/null || echo unknown)}"
  msg="[keyman] [$timestamp] user=$user $*"
  case "$KEYMAN_LOG" in
    syslog)
      if command -v logger >/dev/null 2>&1; then
        logger -t keyman -p auth.info "user=$user $*"
      fi
      ;;
    *)  # Treat as file path
      printf '%s\n' "$msg" >>"$KEYMAN_LOG" 2>/dev/null || true
      ;;
  esac
}

# ----------------- Utilities -----------------

require_cmd() {
  cmd="$1"
  pkg_hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing dependency: '$cmd'."
    [ -n "$pkg_hint" ] && err "Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y $pkg_hint"
    return 1
  fi
  return 0
}

is_int() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Create a secure temporary file with restricted permissions.
# Always use this instead of mktemp directly to ensure 600 mode.
# Returns: path to temp file on stdout.
mktemp_safe() {
  if ! command -v mktemp >/dev/null 2>&1; then
    err "Required command 'mktemp' not found."
    return 1
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/keyman.XXXXXX")" || return 1
  chmod 600 "$tmp" 2>/dev/null || true  # Ensure only owner can read/write
  printf '%s' "$tmp"
}

strip_wrapping_quotes() {
  s="$(trim "$1")"
  case "$s" in
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
  esac
  printf '%s' "$s"
}

expand_tilde_home() {
  case "$1" in
    ~*) printf '%s' "$HOME${1#\~}" ;;
    *)  printf '%s' "$1" ;;
  esac
}

# Truncate string to n characters, adding "..." suffix if truncated.
# Used for table columns to ensure alignment.
truncate() {
  s="$1"
  n="$2"
  printf '%s' "$s" | awk -v n="$n" '{
    if (length($0) <= n) { print $0; next }  # Fits, no truncation
    if (n <= 3) { print substr($0,1,n); next }  # Too short for ellipsis
    print substr($0,1,n-3) "..."  # Truncate with ellipsis
  }'
}

# ----------------- Clipboard -----------------

clipboard_copy() {
  text="$1"
  if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$text" | xclip -selection clipboard 2>/dev/null && return 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    printf '%s' "$text" | xsel --clipboard --input 2>/dev/null && return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy 2>/dev/null && return 0
  fi
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$text" | pbcopy 2>/dev/null && return 0
  fi
  return 1
}

clipboard_available() {
  command -v xclip >/dev/null 2>&1 && return 0
  command -v xsel >/dev/null 2>&1 && return 0
  command -v wl-copy >/dev/null 2>&1 && return 0
  command -v pbcopy >/dev/null 2>&1 && return 0
  return 1
}
