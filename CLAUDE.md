# Nix Configuration Context for Claude Code

## Overview

This is a **nix-darwin** configuration with **home-manager** integration for macOS.

## Key Files

- **Flake file:** `/Users/vrathod/.config/nix/flake.nix`
- **Vim config:** `/Users/vrathod/.config/nix/vim_configuration`

## Configuration Structure

The `flake.nix` contains:

1. **nix-darwin system configuration** - macOS system-level settings
2. **Homebrew management** - taps, brews, casks, and Mac App Store apps
3. **home-manager configuration** - user-level packages and dotfiles

## Homebrew Section

Located in the `configuration` block:

```nix
homebrew = {
  enable = true;
  onActivation.cleanup = "uninstall";
  onActivation.autoUpdate = true;
  taps = [];
  brews = [ ... ];      # CLI tools (cowsay, mas, stripe-cli)
  casks = [ ... ];      # GUI apps (chrome, docker, vscode, xquartz, etc.)
  masApps = { ... };    # Mac App Store apps (by ID)
};
```

## Home Manager Packages

Located in the `homeconfig` block under `home.packages`:
- Nerd fonts, oh-my-zsh, neofetch
- Development tools: vim, vscode, git, gh, fnm
- .NET SDKs with version switching functions
- Python, JetBrains IDEA, DBeaver, etc.

## Shell Configuration

Both zsh and bash are configured with:
- **Aliases:** `switch`, `update`, `claude`
- **.NET SDK switching:** `dotnet8`, `dotnet9`, `dotnet10`, `dotnet8-x64`, `dotnet10-x64`
- **fnm** for Node.js version management
- **SSH keys** auto-loaded on shell startup

## Common Commands

```bash
# Apply configuration changes
switch                  # alias for: sudo darwin-rebuild switch --flake ~/.config/nix

# Update everything (Homebrew + Nix)
update                  # upgrades casks and runs switch

# Switch .NET versions
dotnet8                 # ARM64 .NET 8
dotnet10                # ARM64 .NET 10 (default)
dotnet8-x64             # x64 .NET 8 (Rosetta)
dotnet10-x64            # x64 .NET 10 (Rosetta)
```

## Adding Packages

- **Homebrew CLI tools:** Add to `brews = [ ... ]`
- **Homebrew GUI apps:** Add to `casks = [ ... ]`
- **Mac App Store apps:** Add to `masApps = { "Name" = APP_ID; }`
- **Nix packages:** Add to `home.packages = [ pkgs.PACKAGE ]`

After changes, run `switch` to apply.

## SSH Keys

Keys are stored in `~/.ssh/` with descriptive names:

| Key File | Purpose | Host Alias |
|----------|---------|------------|
| `github_work_ed25519` | GitHub work account (VRathod_TWH) | `github.com` |
| `github_personal_ed25519` | GitHub personal account (vivekrathod) | `github-personal` |
| `azure_gitserver_rsa.pem` | Azure git server | `git-server` |
| `id_rsa` | Legacy fallback | - |

SSH config is managed via `programs.ssh.extraConfig` in the flake.

## Git Remote

This config repo is hosted at: `git@github-personal:vivekrathod/config.git`

## Terminal.app Font

The flake configures Terminal.app to use **0xProto Nerd Font Mono** (size 14) via a home-manager activation script. The PostScript name is `0xProtoNFM-Regular`.
