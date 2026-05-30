# keyman

`keyman` is a POSIX shell TUI for managing SSH and GPG keys from the terminal.

It provides a menu-driven interface for listing keys, inspecting details, creating new keys, exporting public keys, and deleting local keys when needed.

## Features

- Manage SSH key pairs under `SSH_DIR`.
- Show SSH key details, fingerprints, and public key contents.
- Create SSH keys with `ed25519`, `rsa`, or `ecdsa`.
- Manage local GPG signing keys.
- Show GPG key details, fingerprints, and ASCII-armored public keys.
- Create or delete GPG signing keys through `gpg`.
- Optional clipboard copy for exported public keys.
- Optional audit logging to syslog or a file.

## Navigation

- Menus react on a single keypress. You do not need to press `RETURN` to activate menu items.
- `0` exits the current menu, including the main menu.
- Confirmation prompts accept a single keypress. `y` confirms, anything else defaults to `No`.
- Free-form inputs such as paths, key IDs, and other typed values still use normal line input and require `RETURN`.

## Requirements

- POSIX shell at `/bin/sh`
- `ssh-keygen` from OpenSSH for SSH operations
- `gpg` for GPG operations
- `mktemp`

Optional clipboard support uses the first available tool from this list:

- `xclip`
- `xsel`
- `wl-copy`
- `pbcopy`

## Installation

Install `keyman` under `/usr/local`:

```sh
sudo ./install.sh
```

That installs:

- a launcher at `/usr/local/bin/keyman`
- the runtime at `/usr/local/lib/keyman`

After installation, run `keyman` from your `PATH`. The launcher exports
`KEYMAN_DIR` so the installed script can always find its bundled `keyman.d/`
runtime directory.

You can override the layout with environment variables:

```sh
PREFIX=/usr ./install.sh
DESTDIR=/tmp/pkg PREFIX=/usr ./install.sh
BINDIR=/opt/bin LIBDIR=/opt/lib ./install.sh
```

Supported installer variables:

- `PREFIX`: base install prefix. Default: `/usr/local`
- `BINDIR`: launcher directory. Default: `PREFIX/bin`
- `LIBDIR`: runtime parent directory. Default: `PREFIX/lib`
- `DESTDIR`: staging root for packaging installs. Default: unset

Remove an installed copy with the same layout settings you used for installation:

```sh
sudo ./uninstall.sh
PREFIX=/usr ./uninstall.sh
DESTDIR=/tmp/pkg PREFIX=/usr ./uninstall.sh
```

## Usage

Run the interactive UI from a source checkout:

```sh
./keyman
```

Run the installed launcher:

```sh
keyman
```

Show help:

```sh
./keyman --help
```

Show version:

```sh
./keyman --version
```

Show installer help:

```sh
./install.sh --help
./uninstall.sh --help
```

## Environment

- `SSH_DIR`: override the SSH directory. Default: `~/.ssh`
- `NO_COLOR`: disable colored output when set
- `KEYMAN_LOG`: enable audit logging. Use `syslog` or provide a file path. Default: disabled
- `KEYMAN_DIR`: override the detected project directory when launching from a wrapper or another location

## What It Does

### SSH

- List available public keys in the SSH directory
- Show file paths, fingerprints, and public key contents
- Create new key pairs
- Delete key pairs after confirmation

### GPG

- List available secret keys
- Show key details and fingerprints
- Export ASCII-armored public keys
- Start the interactive GPG key generation flow
- Delete local signing keys after confirmation

## Notes

- UI output is written to the terminal, while function return values stay on standard output so command substitution remains safe.
- Destructive actions are guarded by confirmation prompts.
- SSH key deletion is restricted to files inside `SSH_DIR`.
