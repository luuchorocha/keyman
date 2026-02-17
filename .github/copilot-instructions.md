# Copilot Instructions for keyman

## Project Overview

**keyman** is a POSIX-compliant shell (`/bin/sh`) interactive TUI for managing SSH and GPG keys. It runs entirely in the terminal with a menu-driven interface.

## Architecture

```
keyman              # Entry point: loads modules, parses args, starts main_menu
keyman.d/           # Module directory (sourced via `load()`)
├── core.sh         # Utilities: colors, logging, clipboard, helpers
├── ui.sh           # Screen drawing: ui_screen(), prompts, confirm()
├── help.sh         # HELP_TEXT constant
├── menu.sh         # main_menu() orchestration
├── ssh.sh          # SSH operations: list, create, delete, show details
└── gpg.sh          # GPG operations: list, create, delete, export
```

**Data flow**: User input → menu functions → operation functions → external commands (`ssh-keygen`, `gpg`) → UI feedback via `ui_println()`.

## Critical Conventions

### POSIX Shell Compliance
- **No bashisms**: Use `[ ]` not `[[ ]]`, `$(...)` not backticks, `printf` over `echo -e`
- **No arrays**: Use newline-separated strings with `while read` loops
- Always `set -u` (undefined variables error)

### Security Conventions
- **Temp files**: Always use `mktemp_safe()` which applies `chmod 600` — never create temp files manually
- **Path validation**: Before destructive operations, verify paths are within expected directories:
  ```sh
  case "$path" in
    "$SSH_DIR"/*) : ;;  # Safe — inside SSH_DIR
    *) warn "Refusing to delete outside SSH_DIR"; return 1 ;;
  esac
  ```
- **Directory creation**: Use `umask 077` before `mkdir` for key directories (see `ssh_dir_ensure()`)
- **Audit logging**: Call `audit_log "action=... key=..."` for create/delete operations
- **Confirmations**: Always use `confirm()` before destructive actions (delete, overwrite)

### IO Model (core.sh)
- **UI output**: Goes to `/dev/tty` (or `stderr` if unavailable) — never `stdout`
- **Return values**: Always via `stdout` only — enables clean command substitution
- Pattern: `result="$(function_call)"` captures stdout; UI messages visible to user

```sh
# CORRECT: UI to tty, return value to stdout
ui_println "Select a key..."        # User sees this
printf '%s' "$selected_key"         # Caller captures this

# WRONG: mixing concerns
echo "Select a key: $key"           # Breaks command substitution
```

### UI Functions (ui.sh)
- `ui_screen "Title"` — Clear screen, draw header with title
- `ui_section "Name"` — Section header with cyan bold text
- `ui_println`, `ui_print` — Output to tty/stderr
- `prompt "text"` — Sets `$REPLY` variable
- `confirm "question"` — Returns 0/1 for yes/no

### Logging (core.sh)
- Status messages: `info()`, `ok()`, `warn()`, `err()` with unicode icons
- Security audit: `audit_log "action=... key=..."` (when `KEYMAN_LOG` is set)

### Menu Pattern
Each module follows this structure:
```sh
# 1. Helpers: module_helper_function()
# 2. Table selection: module_choose_item() — displays table, returns selection
# 3. Operations: module_operation() — ui_screen(), do work, pause
# 4. Menu loop: module_menu() — while loop with case statement
```

### Key Paths
- SSH keys: `$SSH_DIR` (default `~/.ssh`), always use `ssh_normalize_key_paths()`
- GPG keys: Referenced by key ID from `gpg --list-secret-keys --with-colons`

## Testing & Running

```sh
./keyman              # Interactive mode
./keyman --help       # Show help
./keyman --version    # Show version

# Environment variables
SSH_DIR=~/.ssh        # Override SSH directory
NO_COLOR=1            # Disable colors
KEYMAN_LOG=syslog     # Audit to syslog
KEYMAN_LOG=/tmp/km.log # Audit to file
```

## Adding New Features

1. **New operation**: Add function in appropriate module, call from menu's `case`
2. **New key type**: Extend the existing module (ssh.sh or gpg.sh)
3. **New module**: Create `keyman.d/newmodule.sh`, add `load "newmodule.sh"` in main script

### Checklist for new functions
- [ ] Use `ui_screen "Title"` at function start
- [ ] Check dependencies with `require_cmd cmd package-hint`
- [ ] Validate user input with `is_int()`, `trim()`, `strip_wrapping_quotes()`
- [ ] Use `confirm()` before destructive operations
- [ ] Add `audit_log()` for security-sensitive actions
- [ ] End with `pause` to let user see output
