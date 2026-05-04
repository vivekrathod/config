{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = { pkgs, ... }: {
     # let determinate manage nix
      nix.enable = false;	
 
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [
	  pkgs.vim
        ];

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # needed for home-manager (somehow uses this to decide the home dir and all)
      users.users.vrathod.home = /Users/vrathod;

      # needed to allow unfree packages like vscode
      nixpkgs.config.allowUnfree = true;

      # enable zsh
      programs.zsh.enable = true;
	
      # install homebrew apps/packages
      homebrew = {
         enable = true;
         onActivation.cleanup = "uninstall";
         onActivation.autoUpdate = true;

         taps = [ "steipete/tap" ];
         brews = [ "cowsay" "mas" "stripe-cli" "steipete/tap/gogcli" "steipete/tap/peekaboo" "rtk" ];
         casks = [ "google-chrome" "whatsapp@beta" "sublime-merge" "joplin" "microsoft-remote-desktop" "zoom" "docker-desktop" "db-browser-for-sqlite" "discord" "notesnook" "claude" "xquartz" "steipete/tap/codexbar" "cursor" "openclaw" ];
         masApps = {
           "Perplexity: Ask Anything" = 6714467650;
         };
        };
      
      # required for homebrew enablement - apparently tells homebrew to run under this user
      system.primaryUser = "vrathod";

      # enable touch id when using sudo
      security.pam.services.sudo_local.touchIdAuth = true;

    };

    # home-manager config
    homeconfig = { pkgs, config, ... }:
    {
        # this is internal compatibility configuration 
        # for home-manager, don't change this!
        home.stateVersion = "23.05";
        
        # needed to allow unfree packages like warp-terminal
        nixpkgs.config.allowUnfree = true;
        
	# Let home-manager install and manage itself.
        programs.home-manager.enable = true;

	# \todo enable nerdfont? 
        fonts.fontconfig.enable = true;
	
        # install packages that are not specific to macOS here as home-manager is cross-platform
        home.packages = [
	    pkgs.nerd-fonts._0xproto
            pkgs.nerd-fonts.droid-sans-mono
            pkgs.oh-my-zsh
            pkgs.neofetch
            pkgs.vim
            pkgs.vscode
            pkgs.git
            pkgs.git-lfs
            pkgs.gh # GitHub CLI
            pkgs.warp-terminal
            # Node.js version manager - use: fnm install 20, fnm use 22, fnm default 20, etc.
            pkgs.fnm
           # pkgs.docker
           # pkgs.docker-compose
           # pkgs.colima
	    pkgs.grype
	    pkgs.jq #command line json parser?
	    pkgs.gitkraken
	   # pkgs.sqlitebrowser
	    pkgs.jetbrains.idea-community
	    # Database tools
	    pkgs.dbeaver-bin
	    # Python tooling
	    pkgs.python3
	    pkgs.python3Packages.pip
	    pkgs.python3Packages.virtualenv
	    pkgs.python3Packages.setuptools
	    pkgs.uv
	    # PDF/OCR deps for nano-pdf
	    pkgs."poppler-utils"
	    pkgs.tesseract
        ];

	home.sessionVariables = {
            EDITOR = "vim";
        };
    
        #configure dotfile for config as required
        home.file.".vimrc".source = ./vim_configuration;
        
        # SSH configuration for automatic key loading
        programs.ssh = {
          enable = true;
          addKeysToAgent = "yes";
          extraConfig = ''
            UseKeychain yes
            
            # Personal GitHub account (vivekrathod)
            Host github-personal
              HostName github.com
              User git
              IdentityFile ~/.ssh/github_personal_ed25519
              IdentitiesOnly yes

            # Work GitHub account (VRathod_TWH) - default github.com
            Host github.com
              HostName github.com
              User git
              IdentityFile ~/.ssh/github_work_ed25519
              IdentitiesOnly yes

            # Azure git server
            Host git-server
              HostName 20.102.112.99
              User vivekrathod
              IdentityFile ~/.ssh/azure_gitserver_rsa.pem
              IdentitiesOnly yes

            # Fallback identity files
            IdentityFile ~/.ssh/github_work_ed25519
            IdentityFile ~/.ssh/github_personal_ed25519
            IdentityFile ~/.ssh/id_rsa
          '';
        };
	  
   	programs.zsh = {
    	   enable = true;
           shellAliases = {
              switch = "sudo darwin-rebuild switch --flake ~/.config/nix";
              update = "brew upgrade --cask && sudo darwin-rebuild switch --flake ~/.config/nix && echo '✅ System updated: Nix packages, Homebrew packages & casks, and macOS App Store apps'";
              claude = "/Users/vrathod/.claude/local/claude";
           };
           
           initContent = ''
             # Load local secrets (API tokens etc — not tracked in git)
             [ -f "$HOME/.credentials/secrets.sh" ] && source "$HOME/.credentials/secrets.sh"

             # Initialize fnm (Fast Node Manager) for Node.js version management
             eval "$(fnm env --use-on-cd)"

             
             # Add SSH keys to agent on shell startup
             ssh-add --apple-use-keychain ~/.ssh/github_personal_ed25519 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/github_work_ed25519 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>/dev/null || true
           '';
	    

           oh-my-zsh = {
             enable = true;
             plugins = [ "git" "ssh-agent"];
             theme = "agnoster";
           };
        };

        programs.bash = {
           enable = true;
           shellAliases = {
              switch = "sudo darwin-rebuild switch --flake ~/.config/nix";
              update = "brew upgrade --cask && sudo darwin-rebuild switch --flake ~/.config/nix && echo '✅ System updated: Nix packages, Homebrew packages & casks, and macOS App Store apps'";
           };
           
           initExtra = ''
             # Load local secrets (API tokens etc — not tracked in git)
             [ -f "$HOME/.credentials/secrets.sh" ] && source "$HOME/.credentials/secrets.sh"

             # Initialize fnm (Fast Node Manager) for Node.js version management
             eval "$(fnm env --use-on-cd)"

             
             # Add SSH keys to agent on shell startup
             ssh-add --apple-use-keychain ~/.ssh/github_personal_ed25519 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/github_work_ed25519 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>/dev/null || true
           '';
        };

        programs.git = {
            enable = true;
            lfs.enable = true;
            userName = "Vivek Rathod";
            userEmail = "vrathod@trustwave.com";
            ignores = [ ".DS_Store" ];
            extraConfig = {
                init.defaultBranch = "master";
                push.autoSetupRemote = true;
            };
        };
        
        # Note: Terminal.app font must be set manually
        # Go to Terminal > Settings > Profiles > Basic > Font > Change
        # Select "0xProto Nerd Font Mono" size 14
        # The font is installed via nerd-fonts in home.packages
   };
in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#FLU-EN-9C973MY
    darwinConfigurations."FLU-EN-9C973MY" = nix-darwin.lib.darwinSystem {
      modules = [ 
	configuration
	home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.vrathod = homeconfig; 

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
      ];
    };
  };
}
