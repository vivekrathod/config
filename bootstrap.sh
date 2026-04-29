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

restore_archive() {
    local name="$1" dest="$2" label="$3"
    local archive="/Volumes/Office/${name}.tar.gz"
    if [[ ! -f "$archive" ]]; then
        warn "No backup found for $label ($archive) — skipping"
        return
    fi
    mkdir -p "$dest"
    tar xzf "$archive" -C "$dest" --strip-components=1
    ok "$label restored"
}

run_step_1() {
    step "Step 1 — Restore SSH Keys"
    check_office_disk
    restore_archive "ssh" "$HOME/.ssh" "SSH keys"
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/github_work_ed25519 \
               ~/.ssh/github_personal_ed25519 \
               ~/.ssh/azure_gitserver_rsa.pem \
               ~/.ssh/id_rsa 2>/dev/null || true
    chmod 644 ~/.ssh/*.pub 2>/dev/null || true
    ok "SSH key permissions set"
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
    restore_archive "credentials" "$HOME/.credentials" "Credentials"
    chmod 700 ~/.credentials
    chmod 600 ~/.credentials/secrets.sh 2>/dev/null || true
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

    restore_archive "openclaw"            "$HOME/.openclaw"                                       "OpenClaw config"
    restore_archive "openclaw-app-identity" "$HOME/Library/Application Support/OpenClaw/identity" "OpenClaw app identity"
    chmod 600 ~/Library/Application\ Support/OpenClaw/identity/*.json 2>/dev/null || true

    for workspace in clawd clawd-coder clawd-travel; do
        restore_archive "$workspace" "$HOME/$workspace" "OpenClaw workspace (~/$workspace)"
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
    restore_archive "filezilla" "$HOME/.config/filezilla"      "FileZilla config"
    restore_archive "remmina"   "$HOME/.local/share/remmina"   "Remmina RDP connections"
}

run_step_13() {
    step "Step 13 — Restore Claude Code & Cursor Config"
    check_office_disk

    restore_archive "claude-code"  "$HOME/.claude"                                        "Claude Code dir"
    restore_archive "cursor-home"  "$HOME/.cursor"                                        "Cursor home config"
    restore_archive "cursor-user"  "$HOME/Library/Application Support/Cursor/User"        "Cursor Library settings"

    # claude.json is a single file, not an archive
    if [[ -f /Volumes/Office/claude.json ]]; then
        cp /Volumes/Office/claude.json ~/.claude.json
        ok "Claude MCP config restored to ~/.claude.json"
    else
        warn "No claude.json backup found — skipping"
    fi

    info "Launch Cursor and sign into Settings Sync to restore extensions"
}

run_step_14() {
    step "Step 14 — Manual Steps (cannot be automated)"
    echo ""
    echo "  These require you to do them by hand:"
    echo ""
    echo "  □  Terminal font:   Terminal → Settings → Profiles → Basic → Font → 0xProto Nerd Font Mono, size 14"
    echo "  □  VS Code:         Sign in to Settings Sync (built into VS Code)"
    echo "  □  Cursor:          Sign in to Settings Sync to restore extensions"
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

ALL_STEPS=(1 2 3 4 5 6 7 8 9 10 11 12 13 14)

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
        14) run_step_14 ;;
    esac
done
