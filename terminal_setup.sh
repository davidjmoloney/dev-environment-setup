#!/usr/bin/env bash
set -euo pipefail

# Defaults
AUTO_YES=false
CONFIG_PATH="./terminator_config"   # override with --config-path

# ---------- Helpers ----------
log() { printf "[*] %s\n" "$*" ; }
warn() { printf "[!] %s\n" "$*" >&2 ; }
die() { printf "[x] %s\n" "$*" >&2 ; exit 1; }

prompt_yes() {
  # $1 = prompt message
  # returns 0 for yes, 1 for no
  local msg="${1:-Proceed?} [Y/n]: "
  if "$AUTO_YES"; then
    log "$msg (auto-yes)"
    return 0
  fi
  read -r -p "$msg" reply || true
  case "${reply:-Y}" in
    Y|y|"" ) return 0 ;;
    N|n ) return 1 ;;
    * ) return 0 ;;
  esac
}

ensure_dir() { mkdir -p "$1"; }

timestamp() { date +"%Y%m%d_%H%M%S"; }

# ---------- Operations ----------
install_terminator() {
  if command -v terminator >/dev/null 2>&1; then
    log "Terminator already installed."
    return 0
  fi
  log "Installing Terminator..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y terminator
  else
    die "apt-get not found. This script targets Ubuntu/Debian."
  fi
  log "Terminator installation complete."
}

load_terminator_config() {
  local src="$CONFIG_PATH"
  [[ -f "$src" ]] || die "Config file not found at: $src (use --config-path to set it)"
  local dst_dir="$HOME/.config/terminator"
  local dst="$dst_dir/config"
  ensure_dir "$dst_dir"

  if [[ -f "$dst" ]]; then
    local bak="${dst}.bak.$(timestamp)"
    log "Backing up existing Terminator config to: $bak"
    cp -f "$dst" "$bak"
  fi

  log "Installing Terminator config to: $dst"
  cp -f "$src" "$dst"
  log "Done."
}

set_shell_prompt() {
    warn "Skipping host name setting in shell prompt. Script is to be completed"
#   local bashrc="$HOME/.bashrc"
#   [[ -f "$bashrc" ]] || touch "$bashrc"

#   local start_mark="# >>> dev-setup prompt start"
#   local end_mark="# <<< dev-setup prompt end"
#   local tmp="$(mktemp)"

#   # Managed block content (use single quotes in PS1 to avoid escaping hell)
#   cat >"$tmp" <<'EOF'
# # >>> dev-setup prompt start
# # Minimal username:path prompt
# PS1='\u:\w \$ '
# # <<< dev-setup prompt end
# EOF

#   # If block exists, replace it; otherwise append
#   if grep -qF "$start_mark" "$bashrc"; then
#     log "Updating managed prompt block in $bashrc"
#     # Replace between markers
#     awk -v start="$start_mark" -v end="$end_mark" '
#       BEGIN {inblk=0}
#       {
#         if ($0==start) {print; inblk=1; next}
#         if ($0==end)   {inblk=0; next}
#         if (!inblk) print
#       }
#       END { }
#     ' "$bashrc" > "${bashrc}.tmp.replace"
#     # Append fresh block to the end (ensures a single clean block at end)
#     cat "$tmp" >> "${bashrc}.tmp.replace"
#     mv "${bashrc}.tmp.replace" "$bashrc"
#   else
#     log "Appending managed prompt block to $bashrc"
#     printf "\n" >> "$bashrc"
#     cat "$tmp" >> "$bashrc"
#   fi
#   rm -f "$tmp"
#   log "Prompt configured to: \\u:\\w \\$"

#   # shellcheck disable=SC1090
#   # Note: sourcing a file in a subshell won't change the parent shell.
#   # If you want it to affect your current terminal, 'source' this script.
#   log "Sourcing ~/.bashrc (this affects only the current shell if script is sourced)"
#   source "$HOME/.bashrc" || true
}

reload_bashrc() {
  # shellcheck disable=SC1090
  log "Sourcing ~/.bashrc"
  source "$HOME/.bashrc" || true
}

# ---------- CLI parsing ----------
DO_INSTALL=false
DO_LOADCFG=false
DO_SETPROMPT=false
DO_RELOAD=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

No flags -> interactive mode with prompts (default Y). 
Flags -> run selected operations non-interactively.

Options:
  --install-terminator       Run only the Terminator installation
  --load-terminator-config   Run only loading the Terminator config
  --set-shell-prompt         Run only the PS1 prompt configuration
  --reload-bashrc            Run only 'source ~/.bashrc'
  --config-path PATH         Path to 'terminator_config' (default: ./terminator_config)
  -y                         Assume 'Yes' to all prompts (non-interactive)
  -h, --help                 Show this help

Examples:
  $(basename "$0") -y --install-terminator --set-shell-prompt
  $(basename "$0") --config-path ~/dotfiles/terminator_config --load-terminator-config
  $(basename "$0")            # interactive prompts (defaults to Yes)
EOF
}

while (( "$#" )); do
  case "$1" in
    --install-terminator) DO_INSTALL=true ;;
    --load-terminator-config) DO_LOADCFG=true ;;
    --set-shell-prompt) DO_SETPROMPT=true ;;
    --reload-bashrc) DO_RELOAD=true ;;
    --config-path)
      shift || die "Missing value for --config-path"
      CONFIG_PATH="$1"
      ;;
    -y) AUTO_YES=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use -h for help)" ;;
  esac
  shift
done

# ---------- Execution logic ----------
if $DO_INSTALL || $DO_LOADCFG || $DO_SETPROMPT || $DO_RELOAD; then
  # Non-interactive targeted runs
  $DO_INSTALL   && install_terminator
  $DO_LOADCFG   && load_terminator_config
  $DO_SETPROMPT && set_shell_prompt
  $DO_RELOAD    && reload_bashrc
  exit 0
fi

# Interactive mode (defaults: Yes)
if prompt_yes "Install Terminator?"; then
  install_terminator
else
  log "Skipped Terminator installation."
fi

if prompt_yes "Load local terminator_config into ~/.config/terminator/config?"; then
  load_terminator_config
else
  log "Skipped Terminator config."
fi

if prompt_yes "Change shell prompt in ~/.bashrc to 'devel-style' (username:path)?"; then
  set_shell_prompt
else
  log "Skipped shell prompt changes."
fi

# Always offer to reload at the end
if prompt_yes "Reload ~/.bashrc now?"; then
  reload_bashrc
else
  log "Skipped reloading ~/.bashrc."
fi
