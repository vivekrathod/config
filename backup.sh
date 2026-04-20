#!/usr/bin/env bash
# =============================================================================
# Mac Backup Script — run this BEFORE reimaging or periodically to keep the
# Office external disk up to date.
#
# Usage:
#   bash backup.sh          — backs up everything
#   bash backup.sh --dry-run — shows what would be copied without copying
# =============================================================================

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()    { echo -e "\n${BOLD}${GREEN}▶ $1${NC}"; }
info()    { echo -e "  ${CYAN}$1${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠  $1${NC}"; }
ok()      { echo -e "  ${GREEN}✓  $1${NC}"; }
skip()    { echo -e "  ${YELLOW}–  $1 (skipped — source not found)${NC}"; }
die()     { echo -e "\n${RED}✗ $1${NC}\n"; exit 1; }

COPIED=()
SKIPPED=()
WARNED=()

# ── Helpers ───────────────────────────────────────────────────────────────────
backup_dir() {
    local src="$1" dest="$2" label="$3"
    if [[ ! -e "$src" ]]; then
        skip "$label"
        SKIPPED+=("$label")
        return
    fi
    info "$label  →  $dest"
    if [[ "$DRY_RUN" == false ]]; then
        rm -rf "$dest"
        cp -rp "$src" "$dest"
    fi
    ok "$label"
    COPIED+=("$label")
}

backup_file() {
    local src="$1" dest="$2" label="$3"
    if [[ ! -f "$src" ]]; then
        skip "$label"
        SKIPPED+=("$label")
        return
    fi
    info "$label  →  $dest"
    if [[ "$DRY_RUN" == false ]]; then
        cp -p "$src" "$dest"
    fi
    ok "$label"
    COPIED+=("$label")
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Mac Backup Script${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}  DRY RUN — nothing will be written${NC}"

if [[ ! -d /Volumes/Office ]]; then
    die "Office disk not mounted at /Volumes/Office. Plug it in and try again."
fi
ok "Office disk found at /Volumes/Office"

# Warn if nix config has unpushed changes
step "Checking nix config git status"
NIX_DIR="$HOME/.config/nix"
if [[ -d "$NIX_DIR/.git" ]]; then
    DIRTY=$(cd "$NIX_DIR" && git status --porcelain 2>/dev/null)
    AHEAD=$(cd "$NIX_DIR" && git log @{u}.. --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ -n "$DIRTY" ]]; then
        warn "~/.config/nix has uncommitted changes — commit and push before reimaging!"
        WARNED+=("nix config has uncommitted changes")
    elif [[ "$AHEAD" -gt 0 ]]; then
        warn "~/.config/nix has $AHEAD unpushed commit(s) — push before reimaging!"
        WARNED+=("nix config has unpushed commits")
    else
        ok "nix config is clean and up to date with origin"
    fi
fi

# Warn about SOURCE folders with no git remote
step "Checking SOURCE project git remotes"
SOURCE_NO_REMOTE=()
for dir in "$HOME/SOURCE"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    if [[ ! -d "$dir/.git" ]]; then
        SOURCE_NO_REMOTE+=("$name (no git at all)")
    elif ! git -C "$dir" remote | grep -q .; then
        SOURCE_NO_REMOTE+=("$name (git repo but no remote)")
    fi
done
if [[ ${#SOURCE_NO_REMOTE[@]} -gt 0 ]]; then
    warn "These SOURCE folders have no git remote — backing up to Office disk:"
    for item in "${SOURCE_NO_REMOTE[@]}"; do
        info "  ~/SOURCE/$item"
    done
    WARNED+=("SOURCE folders without remotes: ${SOURCE_NO_REMOTE[*]}")
else
    ok "All SOURCE projects have git remotes"
fi

# =============================================================================
# SECTION 1 — Security & Credentials
# =============================================================================
step "Security & Credentials"

backup_dir "$HOME/.ssh"          /Volumes/Office/.ssh                   "SSH keys (~/.ssh)"
backup_dir "$HOME/.gnupg"        /Volumes/Office/gnupg-backup           "GPG keys (~/.gnupg)"
backup_dir "$HOME/.credentials"  /Volumes/Office/credentials-backup     "Credentials (~/.credentials)"

# =============================================================================
# SECTION 2 — Developer Tools
# =============================================================================
step "Developer Tool Config"

backup_dir "$HOME/.claude"       /Volumes/Office/claude-code-backup     "Claude Code dir (~/.claude)"
backup_file "$HOME/.claude.json" /Volumes/Office/claude.json.backup     "Claude MCP config (~/.claude.json)"

backup_dir "$HOME/.cursor"       /Volumes/Office/cursor-home-backup     "Cursor home (~/.cursor)"
CURSOR_USER="$HOME/Library/Application Support/Cursor/User"
backup_dir "$CURSOR_USER"        /Volumes/Office/cursor-user-backup     "Cursor Library settings"

backup_file "$HOME/.docker/config.json" /Volumes/Office/docker-config.json.backup "Docker registry auth"

backup_dir "$HOME/.config/filezilla"         /Volumes/Office/filezilla-backup  "FileZilla config"
backup_dir "$HOME/.local/share/remmina"      /Volumes/Office/remmina-backup    "Remmina RDP connections"

# =============================================================================
# SECTION 3 — OpenClaw
# =============================================================================
step "OpenClaw"

backup_dir "$HOME/.openclaw"     /Volumes/Office/openclaw-backup        "OpenClaw config (~/.openclaw)"

OPENCLAW_ID="$HOME/Library/Application Support/OpenClaw/identity"
if [[ -d "$OPENCLAW_ID" ]]; then
    info "OpenClaw app identity  →  /Volumes/Office/openclaw-app-identity"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p /Volumes/Office/openclaw-app-identity
        cp -r "$OPENCLAW_ID/." /Volumes/Office/openclaw-app-identity/
        chmod 600 /Volumes/Office/openclaw-app-identity/*.json 2>/dev/null || true
    fi
    ok "OpenClaw app identity"
    COPIED+=("OpenClaw app identity")
else
    skip "OpenClaw app identity (Library)"
    SKIPPED+=("OpenClaw app identity")
fi

for workspace in clawd clawd-coder clawd-travel; do
    backup_dir "$HOME/$workspace" "/Volumes/Office/${workspace}-backup" "OpenClaw workspace (~/$workspace)"
done

# =============================================================================
# SECTION 4 — Source Code (no-remote folders only)
# =============================================================================
step "Source Code (folders without git remotes)"

NO_REMOTE_DIRS=(aa-miles dbss dockurr-windows-arm interview)
for name in "${NO_REMOTE_DIRS[@]}"; do
    src="$HOME/SOURCE/$name"
    backup_dir "$src" "/Volumes/Office/source-${name}-backup" "SOURCE/$name"
done

backup_dir "$HOME/IdeaProjects"  /Volumes/Office/ideaprojects-backup    "IdeaProjects"

# =============================================================================
# SECTION 5 — Notes & Personal Data
# =============================================================================
step "Notes & Personal Data"

backup_dir "$HOME/JoplinBackup"              /Volumes/Office/joplin-export-backup  "Joplin exports (~/JoplinBackup)"
backup_dir "$HOME/.config/joplin-desktop"    /Volumes/Office/joplin-app-backup     "Joplin app database"

# =============================================================================
# SECTION 6 — Write manifest
# =============================================================================
step "Writing backup manifest"

MANIFEST=/Volumes/Office/backup-manifest.txt
if [[ "$DRY_RUN" == false ]]; then
    {
        echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Machine: $(scutil --get ComputerName 2>/dev/null || hostname)"
        echo ""
        echo "Copied (${#COPIED[@]}):"
        for item in "${COPIED[@]}"; do echo "  + $item"; done
        echo ""
        echo "Skipped (${#SKIPPED[@]}):"
        for item in "${SKIPPED[@]}"; do echo "  - $item"; done
        if [[ ${#WARNED[@]} -gt 0 ]]; then
            echo ""
            echo "Warnings:"
            for item in "${WARNED[@]}"; do echo "  ! $item"; done
        fi
    } > "$MANIFEST"
    ok "Manifest written to $MANIFEST"
fi

# =============================================================================
# Summary
# =============================================================================
echo -e "\n${BOLD}${GREEN}Backup complete.${NC}"
echo -e "  Copied:  ${#COPIED[@]} items"
echo -e "  Skipped: ${#SKIPPED[@]} items"
[[ ${#WARNED[@]} -gt 0 ]] && echo -e "  ${YELLOW}Warnings: ${#WARNED[@]} — see above${NC}"
[[ "$DRY_RUN" == true ]]  && echo -e "\n${YELLOW}  This was a dry run. Re-run without --dry-run to actually copy.${NC}"
echo ""
