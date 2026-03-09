# ----------------- UI helpers -----------------

ui_line() {
  ui_println "${C_DIM}────────────────────────────────────────────────────────────────────────────────────────────────────${C_RST}"
}

ui_section() {
  ui_println ""
  ui_println "  ${C_CYN}${C_BOLD}$1${C_RST}"
  ui_println "  ${C_DIM}────────────────────────────────────────────────────────────────────────────────────────────────${C_RST}"
}

ui_clear() {
  tty_available || return 0

  if command -v tput >/dev/null 2>&1; then
    tput clear >/dev/tty 2>/dev/null && return 0
  fi
  if command -v clear >/dev/null 2>&1; then
    clear >/dev/tty 2>/dev/null && return 0
  fi
  printf '\033[2J\033[H' >/dev/tty
}

ui_screen() {
  title="$1"

  ui_clear
  ui_println ""
  ui_println "  ${C_CYN}${C_BOLD}🔑 keyman${C_RST}  ${C_DIM}v$VERSION${C_RST}"
  ui_line

  if [ -n "$title" ]; then
    ui_println ""
    ui_println "  ${C_BLU}${C_BOLD}$title${C_RST}"
  fi
}

# ----------------- Prompts -----------------

read_line_input() {
  if tty_available; then
    IFS= read -r REPLY </dev/tty || REPLY=''
  else
    IFS= read -r REPLY || REPLY=''
  fi
  REPLY="$(printf '%s' "$REPLY" | tr -d '\r')"
}

restore_tty() {
  [ -n "${TTY_STATE_SAVED:-}" ] || return 0
  if tty_available; then
    stty "$TTY_STATE_SAVED" </dev/tty 2>/dev/null || stty sane </dev/tty 2>/dev/null || true
  fi
  TTY_STATE_SAVED=''
}

read_key_input() {
  key=''

  if ! tty_available; then
    return 1
  fi
  if ! command -v stty >/dev/null 2>&1; then
    return 1
  fi

  TTY_STATE_SAVED="$(stty -g </dev/tty 2>/dev/null || printf '')"
  [ -n "$TTY_STATE_SAVED" ] || return 1

  if ! stty -icanon min 1 time 0 -echo </dev/tty 2>/dev/null; then
    restore_tty
    return 1
  fi

  if key="$(dd bs=1 count=1 2>/dev/null </dev/tty)"; then
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
