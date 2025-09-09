#!/usr/bin/env bash
set -euo pipefail

# --- helper functions ---
ask_yes_no () {
  # usage: ask_yes_no "Prompt" "Y"|"N"
  local prompt default reply
  prompt="$1"
  default="${2:-Y}"
  local suffix="[Y/n]"
  [[ "$default" =~ ^[Nn]$ ]] && suffix="[y/N]"
  while true; do
    read -r -p "$prompt $suffix " reply || true
    reply="${reply:-$default}"
    case "$reply" in
      [Yy]) return 0 ;;
      [Nn]) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

echo "==> Installing git via apt..."
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git
else
  echo "Error: apt-get not found. This script expects a Debian/Ubuntu system." >&2
  exit 1
fi

echo
echo "==> Configuring global git username and email"
while true; do
  read -r -p "Enter your git user.name (e.g., Jane Doe): " GIT_USER || true
  [[ -n "${GIT_USER:-}" ]] && break
  echo "Username cannot be empty."
done

while true; do
  read -r -p "Enter your git user.email (e.g., jane@example.com): " GIT_EMAIL || true
  [[ -n "${GIT_EMAIL:-}" ]] && break
  echo "Email cannot be empty."
done

git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"
echo "Configured:"
echo "  user.name  = $(git config --global user.name)"
echo "  user.email = $(git config --global user.email)"

echo
if ask_yes_no "Would you like to set up permanent git aliases?" "Y"; then
  echo "==> Setting global git aliases"
  git config --global alias.lg 'log --oneline --graph --decorate --all'
  git config --global alias.st 'status'
  git config --global alias.co 'checkout'
  git config --global alias.br 'branch'
  git config --global alias.cm 'commit -m'

  echo
  echo "Aliases configured (global):"
  git config --global --get-regexp '^alias\.' | sed 's/^alias\.//'
else
  echo "Skipped alias setup."
fi

echo
if ask_yes_no "Do you want to generate a NEW SSH key (ed25519)?" "Y"; then
  echo "==> Generating a new SSH key (ed25519)"

  # Determine default file path without overwriting existing keys
  SSH_DIR="${HOME}/.ssh"
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  DEFAULT_KEY_PATH="${SSH_DIR}/id_ed25519"
  KEY_PATH="$DEFAULT_KEY_PATH"

  if [[ -f "$DEFAULT_KEY_PATH" || -f "${DEFAULT_KEY_PATH}.pub" ]]; then
    echo "An ed25519 key already exists at ${DEFAULT_KEY_PATH}(.pub)."
    TS="$(date +%Y%m%d-%H%M%S)"
    KEY_PATH="${SSH_DIR}/id_ed25519_${TS}"
    echo "Using a new filename to avoid overwrite: $KEY_PATH"
  fi

  # Optional passphrase prompt (empty by default)
  read -r -p "Optional passphrase (leave empty for none): " -s PASSPHRASE || true
  echo

  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH" -N "${PASSPHRASE:-}"

  # Ensure permissions
  chmod 600 "$KEY_PATH"
  chmod 644 "${KEY_PATH}.pub"

  echo
  echo "Public key (${KEY_PATH}.pub):"
  echo "------------------------------------------------------------"
  cat "${KEY_PATH}.pub"
  echo "------------------------------------------------------------"
  echo
  echo "Copy the above public key and add it to your Git hosting (e.g., GitHub → Settings → SSH and GPG keys)."

  # Offer to add to ssh-agent (optional but handy)
  if ask_yes_no "Add the key to ssh-agent now?" "Y"; then
    # Start agent if not running
    if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
      eval "$(ssh-agent -s)"
    fi
    ssh-add "$KEY_PATH" || {
      echo "Note: If this failed, you may need to run 'eval \"\$(ssh-agent -s)\"' in your shell first."
    }
  fi

  read -r -p "Press Enter after you've copied the key to continue..." _
else
  echo "Skipped SSH key generation."
fi

echo
echo "✅ All done!"
