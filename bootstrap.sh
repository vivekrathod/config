#!/usr/bin/env bash
# =============================================================================
# Mac Bootstrap Script — run this after a reimage
# Usage: bash bootstrap.sh [STEP]
#   bash bootstrap.sh        — runs all steps in order (interactive)
#   bash bootstrap.sh 1      — start from step 1 (SSH keys)
#   bash bootstrap.sh 7      — resume from step 7 (restore secrets)
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()    { echo -e "\n${BOLD}${GREEN}▶ $1${NC}"; }
info()    { echo -e "  ${CYAN}$1${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠  $1${NC}"; }
ok()      { echo -e "  ${GREEN}✓  $1${NC}"; }
die()     { echo -e "\n${RED}✗ $1${NC}\n"; exit 1; }
pause()   { echo -e "\n${YELLOW}Press Enter to continue, or Ctrl-C to stop...${NC}"; read -r; }
confirm() { echo -e "\n${YELLOW}$1 [y/N]${NC} "; read -r REPLY; [[ "$REPLY" =~ ^[Yy]$ ]]; }

START_STEP=${1:-1}

# ── Prerequisite: Office disk ─────────────────────────────────────────────────
check_office_disk() {
    if [[ ! -d /Volumes/Office ]]; then
        die "Office disk not found at /Volumes/Office. Plug in the external disk and try again."
    fi
    ok "Office disk is mounted at /Volumes/Office"
}

# =============================================================================
# PHASE 1 — Runs before Nix or Homebrew exist (steps 1–2)
# =============================================================================

run_step_1() {
    step "Step 1 — Restore SSH Keys"
    check_office_disk
    if [[ ! -d /Volumes/Office/.ssh ]]; then
        die "No .ssh backup found at /Volumes/Office/.ssh"
    fi
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    cp -r /Volumes/Office/.ssh/. ~/.ssh/
    chmod 600 ~/.ssh/github_work_ed25519 \
               ~/.ssh/github_personal_ed25519 \
               ~/.ssh/azure_gitserver_rsa.pem \
               ~/.ssh/id_rsa 2>/dev/null || true
    chmod 644 ~/.ssh/*.pub 2>/dev/null || true
    ok "SSH keys restored to ~/.ssh"
}

run_step_2() {
    step "Step 2 — Xcode Command Line Tools"
    if xcode-select -p &>/dev/null; then
        ok "Xcode command line tools already installed ($(xcode-select -p))"
    else
        info "Launching Xcode CLT installer — a dialog will appear. Install it, then come back and press Enter."
        xcode-select --install 2>/dev/null || true
        pause
        ok "Xcode CLT step done"
    fi
}

# =============================================================================
# PHASE 2 — Install Nix + Homebrew + nix-darwin (steps 3–6)
# Each of these modifies PATH, so the script prints the command and exits.
# Re-run with the next step number after each one completes.
# =============================================================================

run_step_3() {
    step "Step 3 — Install Determinate Nix"
    if command -v nix &>/dev/null; then
        ok "Nix already installed: $(nix --version)"
    else
        info "Run this, then open a NEW terminal window and re-run: bash bootstrap.sh 4"
        echo ""
        echo "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
        echo ""
        exit 0
    fi
}

run_step_4() {
    step "Step 4 — Install Homebrew"
    if command -v brew &>/dev/null; then
        ok "Homebrew already installed: $(brew --version | head -1)"
    else
        info "Run this, follow the prompts to add Homebrew to PATH, then open a NEW terminal and re-run: bash bootstrap.sh 5"
        echo ""
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        exit 0
    fi
}

run_step_5() {
    step "Step 5 — Clone Config Repo"
    if [[ -f ~/.config/nix/flake.nix ]]; then
        ok "Config repo already present at ~/.config/nix"
    else
        mkdir -p ~/.config
        info "Cloning config repo..."
        git clone https://github.com/vivekrathod/config.git ~/.config/nix
        ok "Cloned to ~/.config/nix"
    fi
}

run_step_6() {
    step "Step 6 — Run nix-darwin (this installs everything: Homebrew apps, nix packages, shell config)"
    if command -v darwin-rebuild &>/dev/null; then
        info "darwin-rebuild already exists — running switch to apply latest config..."
        sudo darwin-rebuild switch --flake ~/.config/nix
    else
        info "First-time run via 'nix run' — this will take a while..."
        cd ~/.config/nix
        nix run nix-darwin -- switch --flake ~/.config/nix
    fi
    info "Open a NEW terminal so all aliases and shell config take effect, then re-run: bash ~/.config/nix/bootstrap.sh 7"
    exit 0
}

# =============================================================================
# PHASE 3 — Restore data (steps 7–14)
# All of these are safe cp operations, no shell restarts needed.
# =============================================================================

run_step_7() {
    step "Step 7 — Restore Secrets (~/.credentials)"
    check_office_disk
    if [[ ! -d /Volumes/Office/credentials-backup ]]; then
        die "No credentials backup found at /Volumes/Office/credentials-backup"
    fi
    cp -rp /Volumes/Office/credentials-backup ~/.credentials
    chmod 700 ~/.credentials
    chmod 600 ~/.credentials/secrets.sh 2>/dev/null || true
    ok "Credentials restored to ~/.credentials"
}

run_step_8() {
    step "Step 8 — Node.js Versions via fnm"
    if ! command -v fnm &>/dev/null; then
        warn "fnm not found — make sure you opened a fresh shell after step 6 (exec zsh)"
        return
    fi
    fnm install 20.19.5
    fnm install 22.20.0
    fnm default 22
    ok "Node 20.19.5 and 22.20.0 installed; default set to 22"
    ok "Active: $(node --version)"
}

run_step_9() {
    step "Step 9 — Install OpenClaw CLI"
    if ! command -v node &>/dev/null; then
        warn "node not found — run step 8 first"
        return
    fi
    npm install -g openclaw@latest
    ok "OpenClaw CLI installed: $(openclaw --version 2>/dev/null || echo 'installed')"
}

run_step_10() {
    step "Step 10 — Restore OpenClaw Config"
    check_office_disk

    # Main config dir
    if [[ -d /Volumes/Office/openclaw-backup ]]; then
        cp -rp /Volumes/Office/openclaw-backup ~/.openclaw
        ok "~/.openclaw restored"
    else
        warn "No openclaw backup found at /Volumes/Office/openclaw-backup — skipping"
    fi

    # App identity (Library)
    if [[ -d /Volumes/Office/openclaw-app-identity ]]; then
        mkdir -p ~/Library/Application\ Support/OpenClaw/identity
        cp -r /Volumes/Office/openclaw-app-identity/. ~/Library/Application\ Support/OpenClaw/identity/
        chmod 600 ~/Library/Application\ Support/OpenClaw/identity/*.json 2>/dev/null || true
        ok "OpenClaw app identity restored"
    fi

    # Agent workspaces
    for workspace in clawd clawd-coder clawd-travel; do
        backup="/Volumes/Office/${workspace}-backup"
        if [[ -d "$backup" ]]; then
            cp -rp "$backup" ~/"$workspace"
            ok "~/$workspace restored"
        fi
    done

    info "Launch OpenClaw.app to verify. Google Gemini OAuth may prompt re-auth."
    info "GitHub Copilot token may have expired — run: openclaw auth github-copilot"
}

run_step_11() {
    step "Step 11 — Restore OpenClaw Gateway Service"
    if ! command -v openclaw &>/dev/null; then
        warn "openclaw CLI not found — run step 9 first"
        return
    fi
    openclaw gateway install --force
    openclaw gateway start
    sleep 3
    ok "Gateway service installed and started"
    openclaw gateway status
}

run_step_12() {
    step "Step 12 — Restore FileZilla & Remmina"
    check_office_disk

    if [[ -d /Volumes/Office/filezilla-backup ]]; then
        cp -rp /Volumes/Office/filezilla-backup ~/.config/filezilla
        ok "FileZilla config restored to ~/.config/filezilla"
    else
        warn "No FileZilla backup at /Volumes/Office/filezilla-backup — skipping"
    fi

    if [[ -d /Volumes/Office/remmina-backup ]]; then
        mkdir -p ~/.local/share/remmina
        cp -rp /Volumes/Office/remmina-backup/. ~/.local/share/remmina/
        ok "Remmina connections restored to ~/.local/share/remmina"
    else
        warn "No Remmina backup at /Volumes/Office/remmina-backup — skipping"
    fi
}

run_step_13() {
    step "Step 13 — Manual Steps (cannot be automated)"
    echo ""
    echo "  These require you to do them by hand:"
    echo ""
    echo "  □  Terminal font:   Terminal → Settings → Profiles → Basic → Font → 0xProto Nerd Font Mono, size 14"
    echo "  □  VS Code:         Sign in to Settings Sync (built into VS Code)"
    echo "  □  Cursor:          Re-install extensions manually"
    echo "  □  Warp:            Sign in to your Warp account"
    echo "  □  macOS prefs:     Dock, Finder, trackpad, keyboard — reconfigure to taste"
    echo ""
    ok "All done! Your Mac should be fully restored."
}

# =============================================================================
# Main — run steps from START_STEP onward
# =============================================================================

echo -e "\n${BOLD}Mac Bootstrap Script${NC}"
echo -e "Starting from step ${START_STEP}\n"

ALL_STEPS=(1 2 3 4 5 6 7 8 9 10 11 12 13)

for s in "${ALL_STEPS[@]}"; do
    if (( s < START_STEP )); then continue; fi

    case $s in
        1)  run_step_1  ;;
        2)  run_step_2  ;;
        3)  run_step_3  ;;
        4)  run_step_4  ;;
        5)  run_step_5  ;;
        6)  run_step_6  ;;
        7)  run_step_7  ;;
        8)  run_step_8  ;;
        9)  run_step_9  ;;
        10) run_step_10 ;;
        11) run_step_11 ;;
        12) run_step_12 ;;
        13) run_step_13 ;;
    esac
done
