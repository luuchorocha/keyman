# ----------------- Main -----------------

main_menu() {
  init_colors

  while :; do
    ui_screen ""
    ui_println ""
    ui_println "  ${C_CYN}1${C_RST}  ${C_DIM}│${C_RST}  ${C_BOLD}SSH Keys${C_RST}   ${C_DIM}─────${C_RST}  Manage SSH key pairs"
    ui_println "  ${C_CYN}2${C_RST}  ${C_DIM}│${C_RST}  ${C_BOLD}GPG Keys${C_RST}   ${C_DIM}─────${C_RST}  Manage GPG signing keys"
    ui_println ""
    ui_println "  ${C_DIM}0${C_RST}  ${C_DIM}│${C_RST}  ${C_DIM}Quit${C_RST}"
    ui_println ""
    ui_line

    menu_prompt "  ${C_CYN}▸${C_RST} Select: "

    case "$REPLY" in
      1) ssh_menu ;;
      2) gpg_menu ;;
      0|q|Q) exit 0 ;;
      *)
        warn "Unknown option."
        pause
        ;;
    esac
  done
}