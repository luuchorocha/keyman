# ----------------- Main -----------------

main_menu() {
  init_colors

  while :; do
    ui_screen "Main Menu"
    ui_println ""
    ui_menu_row "1" "SSH keys" "Inspect, create, and remove SSH key pairs"
    ui_menu_row "2" "GPG keys" "Inspect, create, export, and delete signing keys"
    ui_println ""
    ui_println "  ${C_DIM}0${C_RST}  ${C_DIM}|${C_RST}  ${C_DIM}Exit${C_RST}"
    ui_println ""
    ui_line

    ui_prompt_select "Select"

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
