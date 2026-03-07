# ----------------- CLI helpers -----------------

check_arguments() {
  case ${1:-} in
    '') ;;
    -h|--help) printf '%s\n' "$HELP_TEXT"; exit 0 ;;
    -v|--version) printf 'keyman %s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown option: %s\nRun: %s --help\n' "$1" "$0" >&2; exit 2 ;;
  esac
}
