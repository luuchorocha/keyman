# ----------------- UI module (self-contained terminal layer) -----------------
#
# Owns everything that touches the terminal: device resolution, colors, raw
# output, status logging, layout, and input (line + single keypress).
# Call ui_init() once at startup before any other ui_* function.
#
# Invariant: UI output NEVER goes to stdout. stdout is reserved for function
# return values so command substitution stays reliable. UI is written to the
# terminal (or stderr as a fallback) and never pollutes captured output.

# Resolved terminal devices (set by init_io). Empty => not interactive.
UI_OUT=''
UI_IN=''

# ----------------- Terminal resolution -----------------

# True when /dev/tty can actually be opened for both reading and writing.
# /dev/tty is the controlling terminal and survives I/O redirection, so it is
# preferred when reachable. We probe by attempting the open and discarding it,
# NOT by testing permission bits with [ -r ]/[ -w ]: a process with no
# controlling terminal passes the bit check yet fails the open with ENXIO,
# and a root-locked node (mode 0600) fails with EACCES. Both must be caught,
# so init_io can fall back to the standard descriptors and keep keyman
# interactive without root.
# NOTE: the probes run in subshells. ':' is a POSIX special built-in, and a
# redirection error on a special built-in makes a non-interactive shell exit;
# the subshell confines that exit so a failed open just yields a non-zero
# status here instead of killing keyman.
dev_tty_usable() {
  ( : >/dev/tty ) 2>/dev/null && ( : </dev/tty ) 2>/dev/null
}

# Resolve UI_OUT/UI_IN once. The fallbacks keep keyman interactive even when
# /dev/tty cannot be opened, as long as one of our std fds is a real terminal.
init_io() {
  # Output: controlling terminal, else stderr. Never stdout (see invariant).
  if dev_tty_usable; then
    UI_OUT='/dev/tty'
  elif [ -t 2 ]; then
    UI_OUT='/dev/stderr'
  else
    UI_OUT=''
  fi

  # Input: controlling terminal, else stdin.
  if dev_tty_usable; then
    UI_IN='/dev/tty'
  elif [ -t 0 ]; then
    UI_IN='/dev/stdin'
  else
    UI_IN=''
  fi
}

# True when there is a terminal to draw on.
tty_available() { [ -n "${UI_OUT:-}" ]; }

# Initialize the whole UI layer. Call once, before any other ui_* function.
ui_init() {
  init_io
  init_colors
}

# ----------------- Output -----------------

ui_print() {
  if [ -n "${UI_OUT:-}" ]; then
    printf '%s' "$*" >"$UI_OUT"
  else
    printf '%s' "$*" >&2
  fi
}

ui_println() {
  if [ -n "${UI_OUT:-}" ]; then
    printf '%s\n' "$*" >"$UI_OUT"
  else
    printf '%s\n' "$*" >&2
  fi
}

# ----------------- Colors -----------------

supports_color() {
  [ -n "$NO_COLOR" ] && return 1
  tty_available || return 1
  [ "${TERM:-}" = 'dumb' ] && return 1
  return 0
}

# Initialize semantic color roles and legacy aliases.
init_colors() {
  if supports_color; then
    UI_STYLE_BOLD="$(printf '\033[1m')"
    UI_STYLE_DIM="$(printf '\033[2m')"
    UI_STYLE_UNDERLINE="$(printf '\033[4m')"
    UI_STYLE_RESET="$(printf '\033[0m')"
    UI_COLOR_ACCENT="$(printf '\033[36m')"
    UI_COLOR_INFO="$(printf '\033[34m')"
    UI_COLOR_SUCCESS="$(printf '\033[32m')"
    UI_COLOR_WARNING="$(printf '\033[33m')"
    UI_COLOR_DANGER="$(printf '\033[31m')"
    UI_COLOR_MUTED="$UI_STYLE_DIM"
    UI_COLOR_DETAIL="$(printf '\033[35m')"
  else
    UI_STYLE_BOLD=''
    UI_STYLE_DIM=''
    UI_STYLE_UNDERLINE=''
    UI_STYLE_RESET=''
    UI_COLOR_ACCENT=''
    UI_COLOR_INFO=''
    UI_COLOR_SUCCESS=''
    UI_COLOR_WARNING=''
    UI_COLOR_DANGER=''
    UI_COLOR_MUTED=''
    UI_COLOR_DETAIL=''
  fi

  C_BOLD=$UI_STYLE_BOLD
  C_DIM=$UI_STYLE_DIM
  C_ULINE=$UI_STYLE_UNDERLINE
  C_RED=$UI_COLOR_DANGER
  C_GRN=$UI_COLOR_SUCCESS
  C_YEL=$UI_COLOR_WARNING
  C_BLU=$UI_COLOR_INFO
  C_MAG=$UI_COLOR_DETAIL
  C_CYN=$UI_COLOR_ACCENT
  C_WHT=''
  C_RST=$UI_STYLE_RESET
}

# ----------------- Status logging -----------------

ui_info() { ui_println "  ${UI_COLOR_INFO}[i]${UI_STYLE_RESET} $*"; }
ui_success() { ui_println "  ${UI_COLOR_SUCCESS}[+]${UI_STYLE_RESET} $*"; }
ui_warning() { ui_println "  ${UI_COLOR_WARNING}[!]${UI_STYLE_RESET} $*"; }
ui_error() { ui_println "  ${UI_COLOR_DANGER}[x]${UI_STYLE_RESET} $*"; }

info() { ui_info "$@"; }
ok() { ui_success "$@"; }
warn() { ui_warning "$@"; }
err() { ui_error "$@"; }

# ----------------- Layout -----------------

ui_line() {
  ui_println "  ${C_DIM}-------------------------------------------------------------------------------${C_RST}"
}

ui_section() {
  ui_println ""
  ui_println "  ${C_CYN}${C_BOLD}$1${C_RST}"
  ui_println "  ${C_DIM}-----------------------------------------------------------------------${C_RST}"
}

ui_clear() {
  [ -n "${UI_OUT:-}" ] || return 0

  if command -v tput >/dev/null 2>&1; then
    tput clear >"$UI_OUT" 2>/dev/null && return 0
  fi
  if command -v clear >/dev/null 2>&1; then
    clear >"$UI_OUT" 2>/dev/null && return 0
  fi
  printf '\033[2J\033[H' >"$UI_OUT"
}

ui_screen() {
  title="$1"

  ui_clear
  ui_println ""
  ui_println "  ${C_CYN}${C_BOLD}keyman${C_RST}  ${C_DIM}v$VERSION${C_RST}"
  ui_println "  ${C_DIM}SSH and GPG key manager${C_RST}"
  ui_line

  if [ -n "$title" ]; then
    ui_println ""
    ui_println "  ${C_BLU}${C_BOLD}$title${C_RST}"
  fi
}

ui_menu_row() {
  key="$1"
  label="$2"
  detail="${3:-}"

  if [ -n "$detail" ]; then
    ui_println "  ${C_CYN}${C_BOLD}$key${C_RST}  ${C_DIM}|${C_RST}  ${C_BOLD}$label${C_RST}  ${C_DIM}- $detail${C_RST}"
  else
    ui_println "  ${C_CYN}${C_BOLD}$key${C_RST}  ${C_DIM}|${C_RST}  ${C_BOLD}$label${C_RST}"
  fi
}

# ----------------- Prompts / input -----------------

read_line_input() {
  if [ -n "${UI_IN:-}" ]; then
    IFS= read -r REPLY <"$UI_IN" || REPLY=''
  else
    IFS= read -r REPLY || REPLY=''
  fi
  REPLY="$(printf '%s' "$REPLY" | tr -d '\r')"
}

restore_tty() {
  [ -n "${TTY_STATE_SAVED:-}" ] || return 0
  if [ -n "${UI_IN:-}" ]; then
    stty "$TTY_STATE_SAVED" <"$UI_IN" 2>/dev/null || stty sane <"$UI_IN" 2>/dev/null || true
  fi
  TTY_STATE_SAVED=''
}

# Read a single keypress without waiting for Enter by putting the terminal in
# cbreak mode. Returns 1 when no terminal input is available so callers can
# fall back to line input.
read_key_input() {
  key=''

  [ -n "${UI_IN:-}" ] || return 1
  command -v stty >/dev/null 2>&1 || return 1

  TTY_STATE_SAVED="$(stty -g <"$UI_IN" 2>/dev/null || printf '')"
  [ -n "$TTY_STATE_SAVED" ] || return 1

  if ! stty -icanon min 1 time 0 -echo <"$UI_IN" 2>/dev/null; then
    restore_tty
    return 1
  fi

  if key="$(dd bs=1 count=1 2>/dev/null <"$UI_IN")"; then
    :
  else
    restore_tty
    return 1
  fi

  restore_tty
  REPLY="$(printf '%s' "$key" | tr -d '\r')"
  return 0
}

prompt() {
  ui_print "$1"
  read_line_input
}

prompt_key() {
  ui_print "$1"
  if read_key_input; then
    ui_println ""
  else
    read_line_input
  fi
}

menu_prompt() {
  prompt_key "$1"
  REPLY="$(printf '%s' "$REPLY" | tr '[:upper:]' '[:lower:]')"
}

ui_prompt_select() {
  menu_prompt "  ${C_CYN}>${C_RST} ${1:-Select}: "
}

pause() {
  prompt_key "Press any key to continue... "
}

confirm() {
  prompt_key "$1 [y/N]: "
  case "$(trim "$REPLY")" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
