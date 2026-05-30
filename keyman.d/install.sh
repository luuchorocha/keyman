#!/bin/sh

set -eu

PREFIX="${PREFIX:-/usr/local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib}"
DESTDIR="${DESTDIR:-}"
APPDIR="${LIBDIR%/}/keyman"

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && cd .. && pwd)
SOURCE_APP="$SCRIPT_DIR/keyman"
SOURCE_LIBDIR="$SCRIPT_DIR/keyman.d"
MARKER_FILE=".keyman-install-marker"

echo "Installing keyman.. from $SCRIPT_DIR to $APPDIR"

usage() {
  cat <<EOF
Usage: ./install.sh

Install keyman into:
  $BINDIR/keyman
  $APPDIR

Environment overrides:
  PREFIX   Installation prefix (default: /usr/local)
  BINDIR   Launcher directory (default: PREFIX/bin)
  LIBDIR   Runtime directory parent (default: PREFIX/lib)
  DESTDIR  Optional staging root prepended at install time
EOF
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

say() {
  printf '%s\n' "$1"
}

join_destdir() {
  path="$1"

  if [ -n "$DESTDIR" ]; then
    case "$path" in
      /*) printf '%s%s\n' "${DESTDIR%/}" "$path" ;;
      *) printf '%s/%s\n' "${DESTDIR%/}" "$path" ;;
    esac
  else
    printf '%s\n' "$path"
  fi
}

shell_quote() {
  value="$1"
  printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

install_file() {
  src="$1"
  dst="$2"
  mode="$3"

  cp "$src" "$dst"
  chmod "$mode" "$dst"
}

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $arg"
      ;;
  esac
done

[ -f "$SOURCE_APP" ] || die "missing source script: $SOURCE_APP"
[ -d "$SOURCE_LIBDIR" ] || die "missing source directory: $SOURCE_LIBDIR"

case "$APPDIR" in
  '' | /)
    die "refusing unsafe runtime directory: $APPDIR"
    ;;
esac

staged_bindir=$(join_destdir "$BINDIR")
staged_appdir=$(join_destdir "$APPDIR")
staged_module_dir="$staged_appdir/keyman.d"
staged_launcher="$staged_bindir/keyman"
staged_runtime="$staged_appdir/keyman"
staged_marker="$staged_appdir/$MARKER_FILE"

mkdir -p "$staged_bindir" "$staged_module_dir"

install_file "$SOURCE_APP" "$staged_runtime" 755

for src in "$SOURCE_LIBDIR"/*; do
  [ -f "$src" ] || die "unsupported entry in keyman.d: $src"
  base=${src##*/}
  install_file "$src" "$staged_module_dir/$base" 644
done

printf '%s\n' 'installed-by=install.sh' >"$staged_marker"
chmod 644 "$staged_marker"

{
  printf '%s\n' '#!/bin/sh'
  printf '%s\n' 'set -u'
  printf '%s\n' '# keyman launcher installed by install.sh'
  printf 'KEYMAN_DIR=%s\n' "$(shell_quote "$APPDIR")"
  printf '%s\n' 'export KEYMAN_DIR'
  # shellcheck disable=SC2016
  printf '%s\n' 'exec "$KEYMAN_DIR/keyman" "$@"'
} >"$staged_launcher"
chmod 755 "$staged_launcher"

say "Installed keyman:"
say "  launcher: $staged_launcher"
say "  runtime:  $staged_appdir"
