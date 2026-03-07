# ----------------- GPG helpers -----------------

# Parse GPG secret keys into tab-separated rows for table display.
# Output format: keyid \t algo \t size \t created \t expires \t uid
# Uses --with-colons format: sec lines have key metadata, uid lines have user ID.
gpg_key_rows() {
  gpg --list-secret-keys --with-colons --fixed-list-mode --keyid-format=long 2>/dev/null \
  | awk -F: '
      $1=="sec" {
        keyid=$5; algo=$4; size=$3; created=$6; expires=$7; uid=""; next
      }
      $1=="uid" && keyid!="" && uid=="" {
        uid=$10
        print keyid "\t" algo "\t" size "\t" created "\t" expires "\t" uid
        keyid=""; algo=""; size=""; created=""; expires=""; uid=""
        next
      }
    '
}

# Convert GPG algorithm number to human-readable name.
# Numbers are from RFC 4880 Section 9.1 (Public-Key Algorithms).
gpg_algo_name() {
  case "$1" in
    1)  printf 'RSA' ;;      # RSA (Encrypt or Sign)
    16) printf 'Elgamal' ;;  # Elgamal (Encrypt-Only)
    17) printf 'DSA' ;;      # DSA (Sign-Only)
    18) printf 'ECDH' ;;     # Elliptic Curve Diffie-Hellman
    19) printf 'ECDSA' ;;    # Elliptic Curve DSA
    22) printf 'EdDSA' ;;    # Edwards-curve DSA (Ed25519)
    *)  printf 'algo:%s' "$1" ;;  # Unknown, show raw number
  esac
}

# Format a Unix timestamp to YYYY-MM-DD, or '-' if empty.
# Falls back to raw timestamp if date command fails (e.g., BSD).
gpg_format_date() {
  ts="$1"
  [ -z "$ts" ] && { printf '-'; return; }
  formatted="$(date -d "@$ts" '+%Y-%m-%d' 2>/dev/null)" && { printf '%s' "$formatted"; return; }
  # fallback: just show timestamp
  printf '%s' "$ts"
}

# ----------------- GPG table selection -----------------

gpg_choose_signing_key() {
  require_cmd gpg gnupg || return 1

  rows="$(gpg_key_rows)"
  if [ -z "$rows" ]; then
    err "No GPG keys found."
    return 1
  fi

  tmp="$(mktemp_safe)" || return 1
  printf '%s\n' "$rows" >"$tmp"
  count="$(wc -l <"$tmp" 2>/dev/null | tr -d '[:space:]')"
  is_int "$count" || count=0

  ui_section "Available GPG Keys"
  ui_println ""
  ui_println "  ${C_DIM}#${C_RST}   ${C_BOLD}Key ID${C_RST}              ${C_BOLD}Algorithm${C_RST}     ${C_BOLD}Created${C_RST}       ${C_BOLD}Expires${C_RST}       ${C_BOLD}User ID${C_RST}"
  ui_println "  ${C_DIM}──  ──────────────────  ────────────  ────────────  ────────────  ──────────────────────────────────────${C_RST}"

  i=1
  while IFS= read -r row; do
    keyid="$(printf '%s' "$row" | awk -F'\t' '{print $1}')"
    algo_num="$(printf '%s' "$row" | awk -F'\t' '{print $2}')"
    size="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
    created_ts="$(printf '%s' "$row" | awk -F'\t' '{print $4}')"
    expires_ts="$(printf '%s' "$row" | awk -F'\t' '{print $5}')"
    uid="$(printf '%s' "$row" | awk -F'\t' '{print $6}')"

    algo="$(gpg_algo_name "$algo_num")"
    [ -n "$size" ] && algo="${algo}/${size}"
    created="$(gpg_format_date "$created_ts")"
    expires="$(gpg_format_date "$expires_ts")"

    # Variables with _t suffix are truncated for table display
    keyid_t="$(truncate "$keyid" 18)"
    algo_t="$(truncate "$algo" 12)"
    uid_t="$(truncate "$uid" 38)"

    # Color expires based on status
    exp_color="$C_GRN"
    [ "$expires" = "-" ] && exp_color="$C_DIM"

    ui_println "$(printf '  %s%-2d%s  %-18s  %s%-12s%s  %s%-12s%s  %s%-12s%s  %s' "$C_CYN" "$i" "$C_RST" "$keyid_t" "$C_MAG" "$algo_t" "$C_RST" "$C_DIM" "$created" "$C_RST" "$exp_color" "$expires" "$C_RST" "$uid_t")"
    i=$((i + 1))
  done <"$tmp"

  ui_println ""
  ui_line
  while :; do
    prompt "  ${C_CYN}▸${C_RST} Select by number (or paste key id/fingerprint/email): "
    ans="$(strip_wrapping_quotes "$REPLY")"
    ans="$(trim "$ans")"

    [ -n "$ans" ] || { rm -f "$tmp"; return 1; }

    sel_num="$(printf '%s' "$ans" | sed 's/^\([0-9][0-9]*\).*$/\1/')"
    if is_int "$sel_num"; then
      if [ "$sel_num" -ge 1 ] 2>/dev/null && [ "$sel_num" -le "$count" ] 2>/dev/null; then
        picked="$(sed -n "${sel_num}p" "$tmp" 2>/dev/null || true)"
        rm -f "$tmp"
        [ -n "$picked" ] || return 1
        printf '%s' "$picked" | awk -F'\t' '{print $1}'
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

# ----------------- GPG operations -----------------

gpg_list_and_show_keys() {
  ui_screen "GPG · Key Details"
  require_cmd gpg gnupg || { pause; return 1; }

  key="$(gpg_choose_signing_key)" || { pause; return 1; }

  ui_screen "GPG · Key Details"

  ui_section "Key Information"
  ui_println ""
  gpg --list-secret-keys --keyid-format=long "$key" 2>/dev/null | while IFS= read -r line; do ui_println "  $line"; done

  ui_section "Fingerprint"
  ui_println ""
  gpg --fingerprint "$key" 2>/dev/null | while IFS= read -r line; do ui_println "  $line"; done

  pubkey="$(gpg --armor --export "$key" 2>/dev/null)"
  ui_section "ASCII-Armored Public Key"
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

  pause
}

gpg_generate_signing_key() {
  ui_screen "GPG · Create Signing Key"
  require_cmd gpg gnupg || { pause; return 1; }

  ui_section "Create New GPG Key"
  ui_println ""
  ui_println "  This runs GPG's full interactive key generation flow."
  ui_println "  You'll be prompted to select key type, size, and expiration."
  ui_println ""

  if ! confirm "Start 'gpg --full-generate-key' now?"; then
    info "Cancelled."
    pause
    return 0
  fi

  audit_log "action=gpg_create_key"
  gpg --full-generate-key
  ui_println ""
  ok "Key generation finished."
  pause
}

gpg_delete_signing_key() {
  ui_screen "GPG · Delete Signing Key"
  require_cmd gpg gnupg || { pause; return 1; }

  key="$(gpg_choose_signing_key)" || { pause; return 1; }

  ui_screen "GPG · Delete Signing Key"

  ui_section "Key to Delete"
  ui_println ""
  gpg --list-secret-keys --keyid-format=long "$key" 2>/dev/null | while IFS= read -r line; do ui_println "  ${C_RED}$line${C_RST}"; done
  gpg --fingerprint "$key" 2>/dev/null | while IFS= read -r line; do ui_println "  ${C_RED}$line${C_RST}"; done
  ui_println ""
  warn "Deleting a signing key does not remove existing signatures from old commits/tags."
  warn "It only removes your local ability to sign with that key."
  ui_println ""

  if ! confirm "Proceed with deletion?"; then
    info "Cancelled."
    pause
    return 0
  fi

  audit_log "action=gpg_delete_key keyid=$key"
  del_ok=0
  if gpg --help 2>/dev/null | grep -q 'delete-secret-and-public-key'; then
    if gpg --delete-secret-and-public-key "$key"; then
      del_ok=1
    fi
  else
    warn "Your gpg does not advertise '--delete-secret-and-public-key'; using two-step deletion."
    secret_del=0
    public_del=0
    if gpg --delete-secret-keys "$key" 2>/dev/null || gpg --delete-secret-key "$key" 2>/dev/null; then
      secret_del=1
    fi
    if gpg --delete-keys "$key" 2>/dev/null || gpg --delete-key "$key" 2>/dev/null; then
      public_del=1
    fi
    [ "$secret_del" -eq 1 ] && [ "$public_del" -eq 1 ] && del_ok=1
    [ "$secret_del" -eq 0 ] && warn "Secret key deletion may have failed."
    [ "$public_del" -eq 0 ] && warn "Public key deletion may have failed."
  fi

  if [ "$del_ok" -eq 1 ]; then
    ok "Key deleted successfully."
  else
    warn "Delete command(s) finished (check for errors above)."
  fi
  pause
}

# ----------------- GPG menu -----------------

gpg_menu() {
  while :; do
    ui_screen "GPG Keys"
    ui_println ""
    ui_println "  ${C_CYN}1${C_RST}  ${C_DIM}│${C_RST}  Show key details"
    ui_println "  ${C_CYN}2${C_RST}  ${C_DIM}│${C_RST}  Create a new key"
    ui_println "  ${C_CYN}3${C_RST}  ${C_DIM}│${C_RST}  Delete a key"
    ui_println ""
    ui_println "  ${C_DIM}0${C_RST}  ${C_DIM}│${C_RST}  ${C_DIM}Back${C_RST}"
    ui_println ""
    ui_line

    prompt "  ${C_CYN}▸${C_RST} Select: "

    case "$REPLY" in
      1) gpg_list_and_show_keys ;;
      2) gpg_generate_signing_key ;;
      3) gpg_delete_signing_key ;;
      0) return 0 ;;
      *)
        warn "Unknown option."
        pause
        ;;
    esac
  done
}
