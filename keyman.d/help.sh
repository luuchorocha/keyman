# ----------------- Help -----------------

HELP_TEXT=$(cat <<EOF
keyman $VERSION — SSH and GPG manager

Usage:
  keyman            Run interactive UI
  keyman -h|--help  Show help
  keyman -v|--version  Show version

Installation:
  ./install.sh      Install to /usr/local by default (override PREFIX/BINDIR/LIBDIR/DESTDIR)
  ./uninstall.sh    Remove files installed by install.sh with the same overrides

Features:
  SSH:  List, show details, create (ed25519/rsa/ecdsa), delete key pairs
  GPG:  List, create, export public key, delete signing keys

Environment:
  SSH_DIR     Override SSH directory (default: ~/.ssh)
  NO_COLOR    Disable colors if set
  KEYMAN_LOG  Enable audit logging: 'syslog' or a file path

Dependencies: openssh-client, gnupg, mktemp (coreutils)
EOF
)
