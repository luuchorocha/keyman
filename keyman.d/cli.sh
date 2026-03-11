#!/bin/sh

# ----------------- CLI helpers -----------------

parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            '') ;;
            -h | --help)
                printf '%s\n' "$HELP_TEXT"
                exit 0
                ;;
            -v | --version)
                printf 'keyman %s\n' "$VERSION"
                exit 0
                ;;
            *)
                printf 'error: unknown option: %s\nRun: %s --help\n' "$1" "$0" >&2
                exit 2
                ;;
        esac
    done
}
