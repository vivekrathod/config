#!/usr/bin/env bash
# =============================================================================
# Mac Backup Script — run BEFORE reimaging or periodically to keep the
# Office external disk up to date.
#
# Everything is stored as a .tar.gz archive so Unix permissions, symlinks,
# and file metadata are fully preserved inside the archive, with no exFAT
# compatibility issues.
#
# Usage:
#   bash backup.sh           — back up everything
#   bash backup.sh --dry-run — show what would be archived, without writing
# =============================================================================

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

OFFICE=/Volumes/Office

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()  { echo -e "\n${BOLD}${GREEN}▶ $1${NC}"; }
info()  { echo -e "  ${CYAN}$1${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠  $1${NC}"; }
ok()    { echo -e "  ${GREEN}✓  $1${NC}"; }
skip()  { echo -e "  ${YELLOW}–  skipped: $1 not found${NC}"; }
die()   { echo -e "\n${RED}✗ $1${NC}\n"; exit 1; }

COPIED=()
SKIPPED=()
WARNED=()

# ── Helpers ───────────────────────────────────────────────────────────────────

# Archive a directory → $OFFICE/<name>.tar.gz
# Safe to re-run: just overwrites the archive with a fresh one.
archive_dir() {
    local src="$1" name="$2" label="$3"
    local archive="$OFFICE/${name}.tar.gz"
    if [[ ! -d "$src" ]]; then
        skip "$label ($src)"
        SKIPPED+=("$label")
        return
    fi
    info "$label  →  ${name}.tar.gz"
    if [[ "$DRY_RUN" == false ]]; then
        COPYFILE_DISABLE=1 tar czf "$archive" \
            --exclude='.#lk*' \
            --exclude='*.sock' \
            --exclude='.DS_Store' \
            -C "$(dirname "$src")" "$(basename "$src")"
    fi
    ok "$label"
    COPIED+=("$label")
}

# Copy a single file → $OFFICE/<name>
archive_file() {
    local src="$1" name="$2" label="$3"
    if [[ ! -f "$src" ]]; then
        skip "$label ($src)"
        SKIPPED+=("$label")
        return
    fi
    info "$label  →  $name"
    if [[ "$DRY_RUN" == false ]]; then
        cp -p "$src" "$OFFICE/$name"
    fi
    ok "$label"
    COPIED+=("$label")
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Mac Backup Script${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}  DRY RUN — nothing will be written${NC}"

[[ -d "$OFFICE" ]] || die "Office disk not mounted at $OFFICE. Plug it in and try again."
ok "Office disk found at $OFFICE"

# Warn if nix config has uncommitted/unpushed changes
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

# Warn about ~/SOURCE folders with no git remote
step "Checking SOURCE project git remotes"
SOURCE_NO_REMOTE=()
for dir in "$HOME/SOURCE"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    if [[ ! -d "$dir/.git" ]]; then
        SOURCE_NO_REMOTE+=("$name (no git)")
    elif ! git -C "$dir" remote | grep -q .; then
        SOURCE_NO_REMOTE+=("$name (git, no remote)")
    fi
done
if [[ ${#SOURCE_NO_REMOTE[@]} -gt 0 ]]; then
    warn "These SOURCE folders have no git remote and will be archived:"
    for item in "${SOURCE_NO_REMOTE[@]}"; do info "  ~/SOURCE/$item"; done
    WARNED+=("SOURCE folders without remotes: ${SOURCE_NO_REMOTE[*]}")
else
    ok "All SOURCE projects have git remotes (or ~/SOURCE doesn't exist)"
fi

# =============================================================================
# SECTION 1 — Security & Credentials
# =============================================================================
step "Security & Credentials"

archive_dir "$HOME/.ssh"         "ssh"           "SSH keys (~/.ssh)"
archive_dir "$HOME/.gnupg"       "gnupg"         "GPG keys (~/.gnupg)"
archive_dir "$HOME/.credentials" "credentials"   "Credentials (~/.credentials)"

# =============================================================================
# SECTION 2 — AI Coding Tools
# =============================================================================
step "AI Coding Tools"

archive_dir  "$HOME/.claude"        "claude-code"        "Claude Code dir (~/.claude)"
archive_file "$HOME/.claude.json"   "claude.json"        "Claude MCP config (~/.claude.json)"
archive_dir  "$HOME/.cursor"        "cursor-home"        "Cursor home (~/.cursor)"
archive_dir  "$HOME/Library/Application Support/Cursor/User" \
                                    "cursor-user"        "Cursor Library settings"

# =============================================================================
# SECTION 3 — Dev Tools
# =============================================================================
step "Dev Tool Config"

archive_file "$HOME/.docker/config.json"  "docker-config.json"  "Docker registry auth"
archive_dir  "$HOME/.config/filezilla"    "filezilla"           "FileZilla config"
archive_dir  "$HOME/.local/share/remmina" "remmina"             "Remmina RDP connections"

# =============================================================================
# SECTION 4 — OpenClaw
# =============================================================================
step "OpenClaw"

archive_dir "$HOME/.openclaw"  "openclaw"  "OpenClaw config (~/.openclaw)"
archive_dir "$HOME/Library/Application Support/OpenClaw/identity" \
                               "openclaw-app-identity"  "OpenClaw app identity"

for workspace in clawd clawd-coder clawd-travel; do
    archive_dir "$HOME/$workspace" "$workspace" "OpenClaw workspace (~/$workspace)"
done

# =============================================================================
# SECTION 5 — Source Code (no-remote folders only)
# =============================================================================
step "Source Code (folders without git remotes)"

for name in "${SOURCE_NO_REMOTE[@]:-}"; do
    [[ -z "$name" ]] && continue
    # Extract just the dir name (strip the " (no git)" suffix)
    dirname="${name%% (*}"
    archive_dir "$HOME/SOURCE/$dirname" "source-${dirname}" "SOURCE/$dirname"
done

archive_dir "$HOME/IdeaProjects" "ideaprojects" "IdeaProjects"

# =============================================================================
# SECTION 6 — Notes & Personal Data
# =============================================================================
step "Notes & Personal Data"

archive_dir "$HOME/JoplinBackup"           "joplin-export"  "Joplin exports (~/JoplinBackup)"
archive_dir "$HOME/.config/joplin-desktop" "joplin-app"     "Joplin app database"

# =============================================================================
# SECTION 7 — Manifest
# =============================================================================
step "Writing backup manifest"

if [[ "$DRY_RUN" == false ]]; then
    {
        echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Machine: $(scutil --get ComputerName 2>/dev/null || hostname)"
        echo ""
        echo "Archives written to: $OFFICE"
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
    } > "$OFFICE/backup-manifest.txt"
    ok "Manifest written to $OFFICE/backup-manifest.txt"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}Backup complete.${NC}"
echo -e "  Copied:  ${#COPIED[@]} items"
echo -e "  Skipped: ${#SKIPPED[@]} items (not present on this machine)"
[[ ${#WARNED[@]} -gt 0 ]] && echo -e "  ${YELLOW}Warnings: ${#WARNED[@]} — see above${NC}"
[[ "$DRY_RUN" == true ]]  && echo -e "\n${YELLOW}  Dry run only. Re-run without --dry-run to write archives.${NC}"
echo ""
