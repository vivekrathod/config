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
         casks = [ "google-chrome" "whatsapp@beta" "sublime-merge" "joplin" "microsoft-remote-desktop" "zoom" "docker" "db-browser-for-sqlite"];
        };
      
      # required for homebrew enablement - apparently tells homebrew to run under this user
      system.primaryUser = "vrathod";

      # enable touch id when using sudo
      security.pam.services.sudo_local.touchIdAuth = true;

    };

    # home-manager config
    homeconfig = {pkgs, ...}: {
        # this is internal compatibility configuration 
        # for home-manager, don't change this!
        home.stateVersion = "23.05";
        
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
	    pkgs.dotnet-sdk_8
	   # pkgs.dotnet-sdk
           # pkgs.docker
           # pkgs.docker-compose
           # pkgs.colima
	    pkgs.grype
	    pkgs.jq #command line json parser?
	    pkgs.gitkraken
	   # pkgs.sqlitebrowser
	    pkgs.jetbrains.idea-community
        ];

	home.sessionVariables = {
            EDITOR = "vim";
        };
    
        #configure dotfile for config as required
        home.file.".vimrc".source = ./vim_configuration;
	  
   	programs.zsh = {
    	   enable = true;
           shellAliases = {
              switch = "darwin-rebuild switch --flake ~/.config/nix";
           };
	    

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
