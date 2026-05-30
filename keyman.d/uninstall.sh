#!/bin/sh

set -eu

PREFIX="${PREFIX:-/usr/local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib}"
DESTDIR="${DESTDIR:-}"
APPDIR="${LIBDIR%/}/keyman"
MARKER_FILE=".keyman-install-marker"

usage() {
  cat <<EOF
Usage: ./uninstall.sh

Remove the keyman installation created by install.sh.

Environment overrides:
  PREFIX   Installation prefix (default: /usr/local)
  BINDIR   Launcher directory (default: PREFIX/bin)
  LIBDIR   Runtime directory parent (default: PREFIX/lib)
  DESTDIR  Optional staging root prepended at uninstall time
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

case "$APPDIR" in
  */keyman) : ;;
  *)
    die "refusing unexpected runtime directory: $APPDIR"
    ;;
esac

staged_launcher=$(join_destdir "$BINDIR/keyman")
staged_appdir=$(join_destdir "$APPDIR")
staged_marker="$staged_appdir/$MARKER_FILE"
removed=0

if [ -e "$staged_launcher" ] && [ ! -f "$staged_launcher" ]; then
  die "refusing unexpected launcher type: $staged_launcher"
fi

if [ -f "$staged_launcher" ]; then
  if grep -Fqs '# keyman launcher installed by install.sh' "$staged_launcher"; then
    rm -f "$staged_launcher"
    say "Removed launcher: $staged_launcher"
    removed=1
  else
    die "refusing to remove unrecognized launcher: $staged_launcher"
  fi
fi

if [ -e "$staged_appdir" ] && [ ! -d "$staged_appdir" ]; then
  die "refusing unexpected runtime path: $staged_appdir"
fi

if [ -d "$staged_appdir" ]; then
  if [ -f "$staged_marker" ]; then
    rm -rf "$staged_appdir"
    say "Removed runtime: $staged_appdir"
    removed=1
  else
    die "refusing to remove unmarked runtime directory: $staged_appdir"
  fi
fi

if [ "$removed" -eq 0 ]; then
  say "No matching keyman installation found."
fi
