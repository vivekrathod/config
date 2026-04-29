#!/usr/bin/env bash
# =============================================================================
# Restore Test Script — verifies backup archives without extracting them.
# Uses 'tar tzf' (list only) so no extra disk space is needed.
#
# Usage: bash test-restore.sh
# =============================================================================

set -euo pipefail

OFFICE=/Volumes/Office

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓  $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠  $1${NC}"; }
fail() { echo -e "  ${RED}✗  $1${NC}"; FAILURES+=("$1"); }

FAILURES=()

[[ -d "$OFFICE" ]] || { echo -e "${RED}Office disk not mounted at $OFFICE${NC}"; exit 1; }

echo -e "\n${BOLD}Restore Test — listing archive contents (no extraction, no disk space used)${NC}"

# ── Helpers ───────────────────────────────────────────────────────────────────

check_archive() {
    local name="$1" label="$2"; shift 2
    local expected=("$@")
    local archive="$OFFICE/${name}.tar.gz"

    echo ""
    echo -e "${BOLD}$label${NC}"

    if [[ ! -f "$archive" ]]; then
        fail "Missing: ${name}.tar.gz"
        return
    fi

    # Check the archive is readable and get its file list
    local listing
    if ! listing=$(tar tzf "$archive" 2>/dev/null); then
        fail "${name}.tar.gz — corrupt or unreadable"
        return
    fi

    local size
    size=$(du -sh "$archive" | cut -f1)
    ok "Archive OK ($size)"

    for f in "${expected[@]}"; do
        [[ -z "$f" ]] && continue
        if echo "$listing" | grep -q "$f"; then
            ok "  found: $f"
        else
            fail "  MISSING inside archive: $f"
        fi
    done
}

check_file() {
    local name="$1" label="$2"
    echo ""
    echo -e "${BOLD}$label${NC}"
    if [[ -f "$OFFICE/$name" ]]; then
        local size
        size=$(du -sh "$OFFICE/$name" | cut -f1)
        ok "File present ($size)"
    else
        fail "Missing: $name"
    fi
}

# =============================================================================
echo -e "\n── Security & Credentials ──────────────────────────────────────────"

check_archive "ssh" "SSH keys (~/.ssh)" \
    "github_work_ed25519" "github_personal_ed25519" "config"

check_archive "credentials" "Credentials (~/.credentials)" \
    "secrets.sh"

# =============================================================================
echo -e "\n── AI Coding Tools ─────────────────────────────────────────────────"

check_archive "claude-code" "Claude Code (~/.claude)" \
    "settings.json"

check_file "claude.json" "Claude MCP config (~/.claude.json)"

check_archive "cursor-home" "Cursor home (~/.cursor)" ""
check_archive "cursor-user" "Cursor Library settings" "settings.json"

# =============================================================================
echo -e "\n── OpenClaw ────────────────────────────────────────────────────────"

check_archive "openclaw" "OpenClaw config (~/.openclaw)" \
    "openclaw.json"

check_archive "openclaw-app-identity" "OpenClaw app identity" ""

for workspace in clawd clawd-coder clawd-travel; do
    if [[ -f "$OFFICE/${workspace}.tar.gz" ]]; then
        check_archive "$workspace" "OpenClaw workspace (~/$workspace)" "MEMORY.md"
    else
        warn "No archive for ~/$workspace (skipped — may not exist)"
    fi
done

# =============================================================================
echo -e "\n── Dev Tools ───────────────────────────────────────────────────────"

check_archive "filezilla" "FileZilla config" "filezilla.xml"
check_archive "remmina"   "Remmina RDP connections" ""
check_file    "docker-config.json" "Docker registry auth"

# =============================================================================
echo ""
echo -e "────────────────────────────────────────────────────────────────────"
if [[ ${#FAILURES[@]} -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}All checks passed. Your backup is complete and readable.${NC}"
else
    echo -e "${BOLD}${RED}${#FAILURES[@]} issue(s) found:${NC}"
    for f in "${FAILURES[@]}"; do
        echo -e "  ${RED}✗  $f${NC}"
    done
    echo ""
    echo "  Re-run 'bash ~/.config/nix/backup.sh' to fix missing archives."
fi
echo ""
