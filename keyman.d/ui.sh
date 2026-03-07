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

prompt() {
  ui_print "$1"
  if tty_available; then
    IFS= read -r REPLY </dev/tty || REPLY=''
  else
    IFS= read -r REPLY || REPLY=''
  fi
  REPLY="$(printf '%s' "$REPLY" | tr -d '\r')"
}

menu_prompt() {
  prompt "$1"
  REPLY="$(printf '%s' "$REPLY" | tr '[:upper:]' '[:lower:]')"
}

pause() {
  prompt "Press Enter to continue... "
}

confirm() {
  prompt "$1 [y/N]: "
  case "$(trim "$REPLY")" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
