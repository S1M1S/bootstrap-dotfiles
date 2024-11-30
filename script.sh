#!/usr/bin/env bash
set -euo pipefail

# CLI flags
NONINTERACTIVE=0
VERBOSE=0
PRIVATE_KEY=""
REPO_URL=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Bootstrap GPG and git-crypt setup

Options:
    -n, --non-interactive    Run without user interaction
    -k, --key FILE          Path to private key file
    -r, --repo URL          Git repository URL
    -v, --verbose           Enable verbose logging
    -h, --help             Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--non-interactive) NONINTERACTIVE=1 ;;
        -k|--key) PRIVATE_KEY="$2"; shift ;;
        -r|--repo) REPO_URL="$2"; shift ;;
        -v|--verbose) VERBOSE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

# Enhanced logging
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
debug() { [[ $VERBOSE -eq 1 ]] && log "DEBUG: $*"; }
error() { log "ERROR: $*" >&2; exit 1; }

# Cleanup function
cleanup() {
    local exit_code=$?
    debug "Running cleanup"
    [[ -f "$PRIVATE_KEY_TMP" ]] && shred -u "$PRIVATE_KEY_TMP" 2>/dev/null
    gpgconf --kill gpg-agent 2>/dev/null || true
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

# Main execution starts here
log "Starting setup..."

# Ensure required variables
REPO_URL=${REPO_URL:-"git@github.com:S1M1S/dotfiles.git"}
PRIVATE_KEY_TMP=${PRIVATE_KEY:-"$HOME/private_key"}
GNUPGHOME=${GNUPGHOME:-"$HOME/.gnupg"}
REPO_DIR="$HOME/dotfiles"

# Set up GPG environment
log "Setting up GPG environment"
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

# Create and secure GNUPGHOME
if [[ ! -d "$GNUPGHOME" ]]; then
    log "Creating $GNUPGHOME"
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"
fi

# Configure gpg-agent based on OS
log "Configuring gpg-agent"
cat > "$GNUPGHOME/gpg-agent.conf" <<EOF
enable-ssh-support
pinentry-program $(command -v pinentry-curses)
EOF

# Restart gpg-agent
log "Restarting gpg-agent"
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye || error "Failed to start gpg-agent"

# Handle private key
if [[ -z "$PRIVATE_KEY" ]]; then
    if [[ $NONINTERACTIVE -eq 0 ]]; then
        log "Opening vim to input private key"
        vim "$PRIVATE_KEY_TMP"
    else
        error "Private key required in non-interactive mode"
    fi
else
    log "Using provided private key"
    cp "$PRIVATE_KEY" "$PRIVATE_KEY_TMP"
fi

[[ ! -f "$PRIVATE_KEY_TMP" ]] && error "Private key file not found"

# Import private key
log "Importing private key"
gpg --import "$PRIVATE_KEY_TMP" || error "Failed to import private key"

# Configure SSH authentication
log "Setting up SSH authentication"
KEY_GRIP=$(gpg --with-keygrip --list-secret-keys | grep -A1 "\[AR\]" | grep Keygrip | awk '{print $3}')
[[ -z "$KEY_GRIP" ]] && error "No authentication key found"
echo "$KEY_GRIP" > "$GNUPGHOME/sshcontrol"

# Verify SSH setup
log "Verifying SSH setup"
ssh-add -l || error "SSH key not properly added"

# Clone and unlock repository
log "Cloning and unlocking repository"
if [[ ! -d "$REPO_DIR" ]]; then
    git clone "$REPO_URL" "$REPO_DIR" || error "Failed to clone repository"
fi

cd "$REPO_DIR" || error "Failed to change to repository directory"
git-crypt unlock || error "Failed to unlock repository"

log "Setup completed successfully"
