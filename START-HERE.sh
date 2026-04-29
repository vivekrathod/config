#!/usr/bin/env bash
# =============================================================================
# START HERE after a reimage.
# Run this from the Office disk:
#
#   bash /Volumes/Office/START-HERE.sh
#
# This copies the bootstrap script to your Desktop so it's easy to run,
# then kicks off step 1 (SSH keys).
# =============================================================================

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "\n${BOLD}Mac Restore — Starting up${NC}"
echo ""
echo "  Office disk : /Volumes/Office"
echo "  Machine     : $(scutil --get ComputerName 2>/dev/null || hostname)"
echo ""

# Copy scripts to Desktop so they're easy to reach during restore
cp /Volumes/Office/bootstrap.sh ~/Desktop/bootstrap.sh
chmod +x ~/Desktop/bootstrap.sh
echo -e "${GREEN}✓  bootstrap.sh copied to ~/Desktop${NC}"

echo ""
echo -e "${YELLOW}Starting step 1 — restoring SSH keys...${NC}"
echo ""

bash /Volumes/Office/bootstrap.sh 1

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  bash ~/Desktop/bootstrap.sh 2    # Xcode CLT"
echo "  bash ~/Desktop/bootstrap.sh 3    # Install Determinate Nix  (needs new terminal after)"
echo "  bash ~/Desktop/bootstrap.sh 4    # Install Homebrew          (needs new terminal after)"
echo "  bash ~/Desktop/bootstrap.sh 5    # Clone config repo"
echo "  bash ~/Desktop/bootstrap.sh 6    # Run nix-darwin            (needs new terminal after)"
echo "  bash ~/Desktop/bootstrap.sh 7    # ...continue through 14"
echo ""
echo "  Full guide: https://github.com/vivekrathod/config"
echo ""
