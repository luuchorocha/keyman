# ----------------- SSH helpers -----------------

# Ensure SSH_DIR exists with secure permissions (700).
# Prompts user for confirmation before creating.
ssh_dir_ensure() {
  if [ ! -d "$SSH_DIR" ]; then
    ui_screen "SSH"
    warn "SSH directory '$SSH_DIR' does not exist."
    if confirm "Create it with 700 permissions?"; then
      umask 077  # Restrict permissions for new directory
      mkdir -p "$SSH_DIR" || return 1
      chmod 700 "$SSH_DIR" || true
      ok "Created '$SSH_DIR'."
      pause
    else
      return 1
    fi
  fi
  return 0
}

ssh_list_pub_keys() {
  [ -d "$SSH_DIR" ] || return 0
  find "$SSH_DIR" -maxdepth 1 -type f -name '*.pub' 2>/dev/null | LC_ALL=C sort
}

ssh_normalize_key_paths() {
  inp="$(expand_tilde_home "$(strip_wrapping_quotes "$1")")"

  if [ -n "$inp" ] && [ "${inp#/}" = "$inp" ]; then
    if [ -f "$SSH_DIR/$inp" ]; then
      inp="$SSH_DIR/$inp"
    fi
  fi

  pub=''
  priv=''

  case "$inp" in
    *.pub)
      pub="$inp"
      priv="${inp%".pub"}"
      ;;
    *)
      if [ -f "$inp" ] && [ -f "$inp.pub" ]; then
        priv="$inp"
        pub="$inp.pub"
      elif [ -f "$inp.pub" ]; then
        priv="$inp"
        pub="$inp.pub"
      else
        pub="$inp"
        priv="${inp%".pub"}"
      fi
      ;;
  esac

  printf '%s|%s' "$pub" "$priv"
}

# Print the fingerprint of an SSH public key file.
# Tries SHA256 first, falls back to default hash if unavailable.
ssh_print_fingerprint() {
  pub="$1"
  [ -f "$pub" ] || { warn "Public key file not found: $pub"; return 1; }

  require_cmd ssh-keygen openssh-client || return 1

  # Try SHA256 fingerprint (modern ssh-keygen)
  if fingerprint="$(ssh-keygen -l -E sha256 -f "$pub" 2>&1)"; then
    printf '%s\n' "$fingerprint"
    return 0
  fi

  # Fallback for older ssh-keygen without -E flag
  warn "Could not compute SHA256 fingerprint (ssh-keygen -E may be unsupported). Falling back."
  if fingerprint="$(ssh-keygen -l -f "$pub" 2>&1)"; then
    printf '%s\n' "$fingerprint"
    return 0
  fi

  err "Failed to compute fingerprint."
  printf '%s\n' "$fingerprint"
  return 1
}

# ----------------- SSH table selection -----------------

ssh_table_and_select_pub() {
  pubs="$(ssh_list_pub_keys)"
  [ -n "$pubs" ] || return 1

  tmp="$(mktemp_safe)" || return 1
  printf '%s\n' "$pubs" >"$tmp"
  count="$(wc -l <"$tmp" 2>/dev/null | tr -d '[:space:]')"
  is_int "$count" || count=0

  ui_section "Available SSH Keys"
  ui_println ""
  ui_println "  ${C_DIM}#${C_RST}   ${C_BOLD}File${C_RST}                                                  ${C_BOLD}Type${C_RST}          ${C_BOLD}Comment${C_RST}                          ${C_BOLD}Private${C_RST}"
  ui_println "  ${C_DIM}──  ────────────────────────────────────────────────────  ────────────  ───────────────────────────────  ───────${C_RST}"

  i=1
  while IFS= read -r pub; do
    [ -n "$pub" ] || continue

    priv="${pub%".pub"}"
    private="no"
    [ -f "$priv" ] && private="yes"

    type="(unknown)"
    comment=""

    if [ -r "$pub" ]; then
      type="$(awk 'NR==1{print $1; exit}' "$pub" 2>/dev/null || printf '%s' "(unknown)")"
      comment="$(awk 'NR==1{print $3; exit}' "$pub" 2>/dev/null || true)"
    fi

    # Variables with _t suffix are truncated for table display
    pub_t="$(truncate "$pub" 54)"
    type_t="$(truncate "$type" 12)"
    comment_t="$(truncate "$comment" 31)"

    priv_color="${C_RED}no${C_RST}"
    [ "$private" = "yes" ] && priv_color="${C_GRN}yes${C_RST}"

    ui_println "$(printf '  %s%-2d%s  %-54s  %s%-12s%s  %s%-31s%s  %s' "$C_CYN" "$i" "$C_RST" "$pub_t" "$C_MAG" "$type_t" "$C_RST" "$C_DIM" "$comment_t" "$C_RST" "$priv_color")"
    i=$((i + 1))
  done <"$tmp"

  ui_println ""
  ui_line
  while :; do
    prompt "  ${C_CYN}▸${C_RST} Select by number (or paste a key path): "
    ans="$(strip_wrapping_quotes "$REPLY")"
    ans="$(trim "$ans")"

    [ -n "$ans" ] || { rm -f "$tmp"; return 1; }

    sel_num="$(printf '%s' "$ans" | sed 's/^\([0-9][0-9]*\).*$/\1/')"
    if is_int "$sel_num"; then
      if [ "$sel_num" -ge 1 ] 2>/dev/null && [ "$sel_num" -le "$count" ] 2>/dev/null; then
        line="$(sed -n "${sel_num}p" "$tmp" 2>/dev/null || true)"
        rm -f "$tmp"
        [ -n "$line" ] || return 1
        printf '%s' "$line"
        return 0
      fi
      warn "Selection out of range (1-$count). Try again."
      continue
    fi

    rm -f "$tmp"
    printf '%s' "$ans"
    return 0
  done
}

ssh_choose_pub() {
  pubs="$(ssh_list_pub_keys)"
  if [ -z "$pubs" ]; then
    err "No SSH keys found under '$SSH_DIR'."
    return 1
  fi

  ssh_table_and_select_pub
}

# ----------------- SSH operations -----------------

ssh_show_details() {
  ui_screen "SSH · Key Details"
  require_cmd ssh-keygen openssh-client || { pause; return 1; }

  sel="$(ssh_choose_pub)" || { pause; return 1; }

  paths="$(ssh_normalize_key_paths "$sel")"
  pub="${paths%%|*}"
  priv="${paths#*|}"

  ui_screen "SSH · Key Details"

  ui_section "Key Paths"
  ui_println ""
  ui_println "  ${C_DIM}Public :${C_RST}  $pub"
  ui_println "  ${C_DIM}Private:${C_RST}  $priv"

  if [ -f "$pub" ]; then
    ui_section "Fingerprint"
    ui_println ""
    ssh_print_fingerprint "$pub" | while IFS= read -r line; do ui_println "  $line"; done

    pubkey="$(cat "$pub")"
    ui_section "Public Key"
    ui_println ""
    printf '%s\n' "$pubkey" | while IFS= read -r line; do ui_println "  ${C_DIM}$line${C_RST}"; done
    ui_println ""

    if clipboard_available; then
      if confirm "Copy public key to clipboard?"; then
        if clipboard_copy "$pubkey"; then
          ok "Copied to clipboard."
        else
          warn "Failed to copy to clipboard."
        fi
      fi
    fi
  else
    ui_println ""
    warn "Public key file not found at '$pub'."
    warn "If you only have the private key, you can recreate the public key with:"
    ui_println "    ${C_DIM}ssh-keygen -y -f \"$priv\" > \"$priv.pub\"${C_RST}"
  fi

  pause
}

ssh_remove_pair() {
  ui_screen "SSH · Delete Key Pair"

  sel="$(ssh_choose_pub)" || { pause; return 1; }

  paths="$(ssh_normalize_key_paths "$sel")"
  pub="${paths%%|*}"
  priv="${paths#*|}"

  # Security: Validate paths are within SSH_DIR to prevent accidental deletion
  # of files outside the expected directory (path traversal protection).
  case "$pub" in
    "$SSH_DIR"/*) : ;;  # Safe - inside SSH_DIR
    *) ui_screen "SSH · Delete Key Pair"; warn "Refusing to delete outside SSH_DIR: $pub"; pause; return 1 ;;
  esac
  case "$priv" in
    "$SSH_DIR"/*) : ;;  # Safe - inside SSH_DIR
    *) ui_screen "SSH · Delete Key Pair"; warn "Refusing to delete outside SSH_DIR: $priv"; pause; return 1 ;;
  esac

  ui_screen "SSH · Delete Key Pair"

  ui_section "Key to Delete"
  ui_println ""
  ui_println "  ${C_DIM}Public :${C_RST}  ${C_RED}$pub${C_RST}"
  ui_println "  ${C_DIM}Private:${C_RST}  ${C_RED}$priv${C_RST}"

  if [ -f "$pub" ]; then
    ui_section "Fingerprint"
    ui_println ""
    ssh_print_fingerprint "$pub" | while IFS= read -r line; do ui_println "  $line"; done
    ui_println ""
  fi

  if ! confirm "Delete this SSH key pair?"; then
    info "Cancelled."
    pause
    return 0
  fi

  audit_log "action=ssh_delete_keypair pub=$pub priv=$priv"
  rm -f "$priv" "$pub" 2>/dev/null || true
  ok "Deleted (if they existed)."
  pause
}

ssh_create_key_interactive() {
  ui_screen "SSH · Create Key"
  require_cmd ssh-keygen openssh-client || { pause; return 1; }
  ssh_dir_ensure || { pause; return 1; }

  ui_screen "SSH · Create Key"

  ui_section "Key Types"
  ui_println ""
  ui_println "  ${C_GRN}ed25519${C_RST}  ${C_DIM}─${C_RST}  Recommended, modern, fast, secure"
  ui_println "  ${C_YEL}rsa${C_RST}      ${C_DIM}─${C_RST}  Legacy, widely compatible (4096-bit)"
  ui_println "  ${C_YEL}ecdsa${C_RST}    ${C_DIM}─${C_RST}  NIST curves, good performance"
  ui_println ""

  prompt "Key type [ed25519]: "
  ktype="$(trim "$REPLY")"
  ktype="${ktype:-ed25519}"

  case "$ktype" in
    ed25519|rsa|ecdsa) : ;;
    *) warn "Unknown type '$ktype', using ed25519."; ktype="ed25519" ;;
  esac

  if ! confirm "Create $ktype key now?"; then
    info "Cancelled."
    pause
    return 0
  fi

  audit_log "action=ssh_create_key type=$ktype"
  ssh-keygen -t "$ktype"
  ui_println ""
  ok "ssh-keygen finished."
  pause
}

# ----------------- SSH menu -----------------

ssh_menu() {
  while :; do
    ui_screen "SSH Keys"
    ui_println ""
    ui_println "  ${C_CYN}1${C_RST}  ${C_DIM}│${C_RST}  Show key details"
    ui_println "  ${C_CYN}2${C_RST}  ${C_DIM}│${C_RST}  Delete a key pair"
    ui_println "  ${C_CYN}3${C_RST}  ${C_DIM}│${C_RST}  Create a new key pair"
    ui_println ""
    ui_println "  ${C_DIM}0${C_RST}  ${C_DIM}│${C_RST}  ${C_DIM}Back${C_RST}"
    ui_println ""
    ui_line

    prompt "  ${C_CYN}▸${C_RST} Select: "

    case "$REPLY" in
      1) ssh_show_details ;;
      2) ssh_remove_pair ;;
      3) ssh_create_key_interactive ;;
      0) return 0 ;;
      *)
        warn "Unknown option."
        pause
        ;;
    esac
  done
}
