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

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

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

         taps = [];
         brews = [ "cowsay" ];
         casks = [ "google-chrome" "whatsapp@beta" "sublime-merge" "joplin" "microsoft-remote-desktop" "zoom" "docker" "db-browser-for-sqlite" "discord"];
        };
      
      # required for homebrew enablement - apparently tells homebrew to run under this user
      system.primaryUser = "vrathod";

      # enable touch id when using sudo
      security.pam.services.sudo_local.touchIdAuth = true;

    };

    # home-manager config
    homeconfig = {pkgs, ...}: 
    let
      dotnet8Path = "${pkgs.dotnet-sdk_8}/share/dotnet";
      dotnet9Path = "${pkgs.dotnet-sdk_9}/share/dotnet";
      # x64 .NET SDK 8 - will be downloaded and installed at runtime
      dotnet8X64Path = "$HOME/.dotnet-x64";
    in
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
            pkgs.warp-terminal
            pkgs.nodejs_20
	    # Default .NET SDK 8 - use dotnet8()/dotnet9()/dotnet8-x64() functions to switch versions
	    pkgs.dotnet-sdk_8
	    # Note: x64 .NET SDK 8 is available via the dotnet8-x64() function
	   # pkgs.dotnet-sdk
           # pkgs.docker
           # pkgs.docker-compose
           # pkgs.colima
	    pkgs.grype
	    pkgs.jq #command line json parser?
	    pkgs.gitkraken
	   # pkgs.sqlitebrowser
	    pkgs.jetbrains.idea-community
	    # Python with common packages
	    pkgs.python3
	    pkgs.python3Packages.pip
	    pkgs.python3Packages.virtualenv
	    pkgs.python3Packages.setuptools
        ];

	home.sessionVariables = {
            EDITOR = "vim";
            # Default to .NET 8 - can be overridden with dotnet8/dotnet9 functions
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
              IdentityFile ~/.ssh/id_ed25519_github_personal
              IdentitiesOnly yes
            
            # Work GitHub account (VRathod_TWH) - default github.com
            Host github.com
              HostName github.com
              User git
              IdentityFile ~/.ssh/id_ed25519
              IdentitiesOnly yes
              
            # Fallback identity files
            IdentityFile ~/.ssh/id_ed25519
            IdentityFile ~/.ssh/id_ed25519_github_personal
            IdentityFile ~/.ssh/id_rsa
          '';
        };
	  
   	programs.zsh = {
    	   enable = true;
           shellAliases = {
              switch = "sudo darwin-rebuild switch --flake ~/.config/nix";
           };
           
           initContent = ''
             # .NET SDK paths (computed by Nix)
             DOTNET8_PATH="${dotnet8Path}"
             DOTNET9_PATH="${dotnet9Path}"
             DOTNET8_X64_PATH="${dotnet8X64Path}"
             
             # .NET SDK switching functions
             dotnet8() {
               if [[ -d "$DOTNET8_PATH" ]]; then
                 export DOTNET_ROOT="$DOTNET8_PATH"
                 # Remove any existing dotnet from PATH and add the new one
                 export PATH="$DOTNET8_PATH:$(echo $PATH | sed -E 's|[^:]*dotnet[^:]*:||g')"
                 echo "Switched to .NET SDK 8 (DOTNET_ROOT=$DOTNET_ROOT)"
                 if command -v dotnet > /dev/null 2>&1; then
                   dotnet --version
                 else
                   echo "Warning: dotnet command not found in PATH"
                 fi
               else
                 echo "Error: .NET SDK 8 not found at $DOTNET8_PATH"
                 return 1
               fi
             }
             
             dotnet9() {
               if [[ -d "$DOTNET9_PATH" ]]; then
                 export DOTNET_ROOT="$DOTNET9_PATH"
                 # Remove any existing dotnet from PATH and add the new one
                 export PATH="$DOTNET9_PATH:$(echo $PATH | sed -E 's|[^:]*dotnet[^:]*:||g')"
                 echo "Switched to .NET SDK 9 (DOTNET_ROOT=$DOTNET_ROOT)"
                 if command -v dotnet > /dev/null 2>&1; then
                   dotnet --version
                 else
                   echo "Warning: dotnet command not found in PATH"
                 fi
               else
                 echo "Error: .NET SDK 9 not found at $DOTNET9_PATH"
                 return 1
               fi
             }
             
             dotnet8-x64() {
               # Check if x64 .NET SDK 8 is already installed
               if [[ ! -d "$DOTNET8_X64_PATH" || ! -f "$DOTNET8_X64_PATH/dotnet" ]]; then
                 echo "x64 .NET SDK 8 not found. Installing..."
                 echo "Creating directory: $DOTNET8_X64_PATH"
                 mkdir -p "$DOTNET8_X64_PATH"
                 
                 echo "Downloading and installing .NET SDK 8 x64 for macOS using Microsoft's installer..."
                 # Use Microsoft's official installer script
                 local installer_url="https://dot.net/v1/dotnet-install.sh"
                 local temp_installer="/tmp/dotnet-install.sh"
                 
                 if command -v curl >/dev/null 2>&1; then
                   curl -L "$installer_url" -o "$temp_installer"
                   chmod +x "$temp_installer"
                   
                   # Install .NET SDK 8.0 for x64 architecture
                   "$temp_installer" --channel 8.0 --architecture x64 --install-dir "$DOTNET8_X64_PATH" --no-path
                   
                   rm "$temp_installer"
                   echo "Installation completed."
                 else
                   echo "Error: curl not found. Cannot download .NET SDK installer."
                   return 1
                 fi
               fi
               
               if [[ -d "$DOTNET8_X64_PATH" && -f "$DOTNET8_X64_PATH/dotnet" ]]; then
                 export DOTNET_ROOT="$DOTNET8_X64_PATH"
                 # Remove any existing dotnet from PATH and add the new one
                 export PATH="$DOTNET8_X64_PATH:$(echo $PATH | sed -E 's|[^:]*dotnet[^:]*:||g')"
                 echo "Switched to .NET SDK 8 x64 (DOTNET_ROOT=$DOTNET_ROOT)"
                 if command -v dotnet > /dev/null 2>&1; then
                   dotnet --version
                   echo "Architecture: x86_64 (running under Rosetta 2)"
                 else
                   echo "Warning: dotnet command not found in PATH"
                 fi
               else
                 echo "Error: .NET SDK 8 x64 installation failed"
                 return 1
               fi
             }
             
             # Show current dotnet version and DOTNET_ROOT
             dotnet-version() {
               echo "Current DOTNET_ROOT: $DOTNET_ROOT"
               echo "Available SDK paths:"
               echo "  .NET 8 (ARM64): $DOTNET8_PATH"
               echo "  .NET 8 (x64): $DOTNET8_X64_PATH"
               echo "  .NET 9: $DOTNET9_PATH"
               if command -v dotnet >/dev/null 2>&1; then
                 echo "dotnet --version: $(dotnet --version)"
                 echo "dotnet --info:"
                 dotnet --info | head -10
               else
                 echo "dotnet command not found in PATH"
               fi
             }
             # Initialize with .NET 8 by default
             dotnet8 > /dev/null 2>&1
             
             # Add SSH keys to agent on shell startup
             ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github_personal 2>/dev/null || true
             ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>/dev/null || true
           '';
	    

           oh-my-zsh = {
             enable = true;
             plugins = [ "git" "ssh-agent"];
             theme = "agnoster";
           };
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
        
        # Configure Terminal.app font using AppleScript
        home.activation.configureTerminalFont = {
          after = [ "writeBoundary" ];
          before = [ ];
          data = ''
            echo "Configuring Terminal.app font..."
            
            # Use AppleScript to configure Terminal.app (most reliable method)
            $DRY_RUN_CMD /usr/bin/osascript -e '
            tell application "Terminal"
              # Create or get the NixDev settings set
              try
                set mySettings to first settings set whose name is "NixDev"
              on error
                set mySettings to (make new settings set with properties {name:"NixDev"})
              end try
              
              # Configure the settings (AppleScript uses 0-65535 for RGB values)
              tell mySettings
                set font name to "0xProto Nerd Font Mono"
                set font size to 14
                set background color to {0, 0, 0}              # Black background
                set cursor color to {65535, 65535, 65535}      # White cursor  
                set normal text color to {52428, 52428, 52428} # Light gray text (204/255 * 65535)
                set bold text color to {65535, 65535, 65535}   # White bold text
              end tell
              
              # Set as default
              set default settings to mySettings
              set startup settings to mySettings
            end tell'
            
            echo "Terminal.app configured with 0xProto Nerd Font Mono 14pt"
            echo "Profile: NixDev (dark theme with nerd font)"
          '';
        };
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
