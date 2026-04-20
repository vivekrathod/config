# Mac Bootstrap Guide

Steps to fully restore this machine after a reimage. Follow them in order.

---

## Before You Reimage — Back Up to the Office Disk

Run the backup script (plug in the Office disk first):

```bash
bash ~/.config/nix/backup.sh
```

This covers everything: SSH keys, GPG keys, credentials, Claude Code, Cursor, OpenClaw, FileZilla, Remmina, Docker auth, Joplin, and SOURCE folders that have no git remote. It also checks if your nix config has uncommitted changes and warns you before you wipe.

To preview what will be copied without actually writing anything:

```bash
bash ~/.config/nix/backup.sh --dry-run
```

After the script finishes, check `/Volumes/Office/backup-manifest.txt` to confirm everything was captured.

---

### What the script backs up (manual reference)

The commands below are what `backup.sh` runs — kept here for reference if you ever need to copy a single item by hand:

```bash
# SSH keys
cp -r ~/.ssh /Volumes/Office/.ssh

# All credentials (secrets.sh, Jira, Azure, personal docs)
cp -rp ~/.credentials /Volumes/Office/credentials-backup

# OpenClaw — entire config dir (agents, credentials, skills, memory, identity)
cp -rp ~/.openclaw /Volumes/Office/openclaw-backup

# OpenClaw app identity (in Library, separate from ~/.openclaw)
mkdir -p /Volumes/Office/openclaw-app-identity
cp -r ~/Library/Application\ Support/OpenClaw/identity/. /Volumes/Office/openclaw-app-identity/

# OpenClaw agent workspaces (contain agent memory, work docs, scripts)
cp -rp ~/clawd /Volumes/Office/clawd-backup 2>/dev/null || true
cp -rp ~/clawd-coder /Volumes/Office/clawd-coder-backup 2>/dev/null || true
cp -rp ~/clawd-travel /Volumes/Office/clawd-travel-backup 2>/dev/null || true

# Claude Code — global settings, custom commands, global CLAUDE.md memory
cp -rp ~/.claude /Volumes/Office/claude-code-backup
# Claude Code — MCP server config (separate loose file, contains all MCP server definitions)
cp ~/.claude.json /Volumes/Office/claude.json.backup

# Cursor — home dir config + Library user settings/keybindings/snippets
cp -rp ~/.cursor /Volumes/Office/cursor-home-backup
cp -rp ~/Library/Application\ Support/Cursor/User /Volumes/Office/cursor-user-backup

# FileZilla saved FTP servers
cp -rp ~/.config/filezilla /Volumes/Office/filezilla-backup

# Remmina RDP connections (personal PC at 192.168.50.40)
cp -rp ~/.local/share/remmina /Volumes/Office/remmina-backup
```

> **Note on size:** `~/.openclaw` is roughly 50–60MB including session history. If space is tight, see the OpenClaw section below for a minimal backup option.

---

## 1. Restore SSH Keys

Before anything else, restore your SSH keys from the **Office** external disk into `~/.ssh/`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp -r /Volumes/Office/.ssh/. ~/.ssh/
chmod 600 ~/.ssh/github_work_ed25519 ~/.ssh/github_personal_ed25519 ~/.ssh/azure_gitserver_rsa.pem ~/.ssh/id_rsa
chmod 644 ~/.ssh/*.pub
```

> **Tip:** Make sure the Office disk is mounted before running these commands. You should see it appear on your Desktop or in Finder under Locations.

---

## 2. Install Xcode Command Line Tools

```bash
xcode-select --install
```

Wait for the dialog to complete before continuing.

---

## 3. Install Determinate Nix

Your setup uses **Determinate Nix** (from [determinate.systems](https://determinate.systems)), not the standard nixos.org installer. The evidence is in `flake.nix` line 16: `nix.enable = false` with the comment `# let determinate manage nix` — this tells nix-darwin to step aside and let Determinate's own daemon manage everything. Determinate Nix also enables `nix-command` and `flakes` automatically, which is why the `nix.settings.experimental-features` line in the flake is dead code (it's ignored when `nix.enable = false`).

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Open a new terminal (or `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`) so `nix` is in your PATH.

---

## 4. Install Homebrew

Nix-darwin manages which Homebrew packages are installed, but Homebrew itself must be installed first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts to add Homebrew to your PATH (the installer will tell you the exact commands for Apple Silicon).

---

## 5. Clone This Config Repo

```bash
mkdir -p ~/.config
# Using HTTPS for initial clone (SSH isn't configured yet on the new machine)
git clone https://github.com/vivekrathod/config.git ~/.config/nix
# Or if SSH keys are already in place and github-personal alias is working:
# git clone git@github-personal:vivekrathod/config.git ~/.config/nix
```

---

## 6. Run nix-darwin for the First Time

The first run uses `nix run` since `darwin-rebuild` isn't installed yet:

```bash
cd ~/.config/nix
nix run nix-darwin -- switch --flake ~/.config/nix
```

> **Note:** The flake config is named `FLU-EN-9C973MY` (your current machine hostname). If your new machine has a different hostname, either rename it to match or update the `darwinConfigurations` key in `flake.nix` before running this command.
>
> To rename your Mac's hostname:
> ```bash
> sudo scutil --set HostName FLU-EN-9C973MY
> sudo scutil --set LocalHostName FLU-EN-9C973MY
> sudo scutil --set ComputerName FLU-EN-9C973MY
> ```

This step installs all Homebrew packages/casks, nix packages, sets up your shell config, dotfiles, SSH config, and git config.

---

## 7. Restore Secrets

All credentials live in `~/.credentials/` — secrets, Jira token, Azure key, and personal docs. Restore the whole directory from the Office disk:

```bash
cp -rp /Volumes/Office/credentials-backup ~/.credentials
chmod 700 ~/.credentials
chmod 600 ~/.credentials/secrets.sh
```

If you don't have a backup, create `secrets.sh` from the template and fill in the actual values:

```bash
mkdir -p ~/.credentials
cp ~/.config/nix/secrets.sh.template ~/.credentials/secrets.sh
vim ~/.credentials/secrets.sh
```

---

## 8. Open a Fresh Shell

```bash
exec zsh
```

Your aliases (`switch`, `update`, `claude`), oh-my-zsh, .NET switching functions, and fnm should all be active now.

---

## 9. Set Up Node.js Versions

fnm is installed by nix-darwin but Node versions themselves need to be re-installed manually. Pin the exact versions from your last working setup:

```bash
fnm install 20.19.5   # Node 20 LTS
fnm install 22.20.0   # Node 22 LTS (current default)
fnm default 22        # Set default — matches your pre-reimage config
```

Verify the default is set correctly:
```bash
fnm current   # should print v22.20.0
node --version
```

---

## 10. Install OpenClaw CLI

The Homebrew `openclaw` cask (installed in step 6) installs only the **GUI app** (`OpenClaw.app`). The `openclaw` CLI tool is a separate npm package and must be installed manually:

```bash
npm install -g openclaw@latest
```

Verify:
```bash
which openclaw        # should NOT be under fnm node-versions
openclaw --version
```

> **Note:** The CLI is installed into whichever Node version is currently active via fnm. Make sure `fnm default 22` is set before running this (step 9), so the CLI ends up in the right place.

---

## 11. Restore OpenClaw

OpenClaw is installed automatically (via the `openclaw` Homebrew cask in step 6), but its entire configuration — agents, AI provider credentials, WhatsApp/Telegram channels, custom skills, memory, and gateway token — lives in `~/.openclaw` and must be restored from backup.

### What's in your OpenClaw setup
- **3 agents:** Mac (main workspace `~/clawd`), Coder (`~/clawd-coder`), Travel (`~/clawd-travel`)
- **6 AI providers:** Anthropic, GitHub Copilot, Google Gemini (OAuth), Azure OpenAI, NVIDIA, MiniMax
- **Channels:** WhatsApp (bound to your number) and Telegram (bot configured)
- **Custom skills:** Feishu doc/drive/wiki/perm integrations, radha-absence-note
- **Local gateway** on port 18789 — token is what `OPENCLAW_GATEWAY_TOKEN` in your shell refers to

### Full restore (recommended)

```bash
# Restore entire config dir
cp -rp /Volumes/Office/openclaw-backup ~/.openclaw

# Restore app identity (in Library)
mkdir -p ~/Library/Application\ Support/OpenClaw/identity
cp -r /Volumes/Office/openclaw-app-identity/. ~/Library/Application\ Support/OpenClaw/identity/
chmod 600 ~/Library/Application\ Support/OpenClaw/identity/*.json

# Restore agent workspaces
cp -rp /Volumes/Office/clawd-backup ~/clawd 2>/dev/null || true
cp -rp /Volumes/Office/clawd-coder-backup ~/clawd-coder 2>/dev/null || true
cp -rp /Volumes/Office/clawd-travel-backup ~/clawd-travel 2>/dev/null || true
```

Then launch OpenClaw. All agents, providers, and channels should come back as-is.

### Minimal restore (if space was tight and you only backed up essentials)

If you couldn't back up everything, prioritise in this order:

| Path | What it contains | If lost |
|---|---|---|
| `~/.openclaw/openclaw.json` | Master config: all models, channels, gateway token | Must re-configure everything from scratch |
| `~/.openclaw/agents/*/agent/auth-profiles.json` | API keys for all AI providers | Must re-enter all API keys |
| `~/.openclaw/credentials/whatsapp/` | WhatsApp session | Must re-scan QR code to reconnect |
| `~/.openclaw/identity/` | Device private key + auth tokens | Must re-pair as a new device |
| `~/.openclaw/skills/` | Custom Feishu + absence note skills | Must recreate skills manually |
| `~/.openclaw/memory/` | Agent long-term memory | Agent loses accumulated context |
| `~/Library/Application Support/OpenClaw/identity/` | App-level device identity | Must re-authenticate in app |

### Post-restore notes

- **Google Gemini OAuth** will likely prompt you to re-authenticate the first time — the access token expires but the refresh token should handle it automatically.
- **GitHub Copilot token** may have expired — if it fails, run `openclaw auth github-copilot` to refresh.
- **Gateway token:** The `OPENCLAW_GATEWAY_TOKEN` in `~/.credentials/secrets.sh` must match the `gateway.auth.token` in `~/.openclaw/openclaw.json`. If you do a full restore, they'll match automatically. If you do a fresh install, update `secrets.sh` with the new token from `openclaw.json`.
- **Agent workspaces** (`~/clawd` etc.) are where agents write files — restore these if you want to preserve work the agents have done.

---

## 12. Restore FileZilla and Remmina

```bash
# FileZilla saved FTP servers
cp -rp /Volumes/Office/filezilla-backup ~/.config/filezilla

# Remmina RDP connections (personal PC at 192.168.50.40)
mkdir -p ~/.local/share/remmina
cp -rp /Volumes/Office/remmina-backup/. ~/.local/share/remmina/
```

---

## 13. Restore Claude Code & Cursor Config

```bash
# Claude Code directory — global settings, custom slash commands, global CLAUDE.md memory
cp -rp /Volumes/Office/claude-code-backup ~/.claude

# Claude Code MCP config — all MCP server definitions (critical!)
cp /Volumes/Office/claude.json.backup ~/.claude.json

# Cursor home dir config
cp -rp /Volumes/Office/cursor-home-backup ~/.cursor

# Cursor Library config — settings.json, keybindings.json, snippets
mkdir -p ~/Library/Application\ Support/Cursor/User
cp -rp /Volumes/Office/cursor-user-backup/. ~/Library/Application\ Support/Cursor/User/
```

> **Cursor extensions:** Sign into Settings Sync inside Cursor after launching it — extensions restore automatically from the cloud.

---

## 14. Restore Personal Documents

`~/.credentials/driver-licenses.txt` is already restored as part of step 7 (it's in the same `credentials-backup` directory). No extra steps needed.

---

## 15. Manual Steps (Not Yet Automated)

These aren't managed by nix and need to be set up by hand after restore:

- **Terminal.app font:** Terminal → Settings → Profiles → Basic → Font → Change to `0xProto Nerd Font Mono`, size 14
- **VS Code extensions:** Sign in to the Settings Sync feature (built into VS Code) to restore extensions and settings automatically
- **Warp terminal:** Sign in to your Warp account to restore themes and settings
- **macOS preferences:** Dock layout, Finder settings, trackpad/keyboard settings — reconfigure to taste

---

## Ongoing Maintenance

```bash
# Apply any changes to flake.nix
switch

# Update everything (Homebrew casks + nix packages)
update
```

---

## What's Managed by This Config

| Category | Tool | What's covered |
|---|---|---|
| CLI tools | Homebrew brews | cowsay, mas, stripe-cli, gogcli, peekaboo, rtk |
| GUI apps | Homebrew casks | Chrome, WhatsApp, Sublime Merge, Joplin, RDP, Zoom, Docker, Discord, Notesnook, Claude, Cursor, OpenClaw, etc. |
| App Store | mas | Perplexity |
| Dev tools | Nix / home-manager | git, gh, vim, VS Code, Warp, fnm, .NET 8/9/10, Python, JetBrains IDEA, DBeaver, gitkraken, grype, jq, uv |
| Shell | home-manager | zsh + bash config, oh-my-zsh, aliases, .NET switching functions |
| Dotfiles | home-manager | `~/.vimrc`, `~/.ssh/config` |
| Git | home-manager | Username, email, LFS, default branch |
| Fonts | Nix | 0xProto Nerd Font Mono, Droid Sans Mono Nerd Font |
| Security | nix-darwin | TouchID for sudo |
