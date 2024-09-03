# ~/.config/nix/flake.nix

{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = {pkgs, ... }: {

        services.nix-daemon.enable = true;
        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility. please read the changelog
        # before changing: `darwin-rebuild changelog`.
        system.stateVersion = 4;

        # The platform the configuration will be used on.
        # If you're on an Intel system, replace with "x86_64-darwin"
        nixpkgs.hostPlatform = "aarch64-darwin";

        # allow Unfree packages like vscode 
        nixpkgs.config = { allowUnfree = true; };

        # Declare the user that will be running `nix-darwin`.
        users.users.vrathod = {
            name = "vrathod";
            home = "/Users/vrathod";
        };

        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true;
	
        # install nix packages
        environment.systemPackages = [ ];
        
        # install homebrew apps/packages
        homebrew = {
            enable = true;
            onActivation.cleanup = "uninstall";

            taps = [];
            brews = [ "cowsay" ];
            casks = [ "google-chrome" "whatsapp@beta" "sublime-merge" "joplin" "microsoft-remote-desktop"];
        };

        # enable touch id when using sudo
        security.pam.enableSudoTouchIdAuth = true;
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
        home.packages = with pkgs; [
            pkgs.nerdfonts
            pkgs.oh-my-zsh
            pkgs.neofetch 
            pkgs.vim 
            pkgs.vscode
            pkgs.git
            pkgs.git-lfs
            pkgs.warp-terminal
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
  darwinConfigurations."MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
            configuration
            home-manager.darwinModules.home-manager  {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.verbose = true;
                home-manager.users.vrathod = homeconfig;
            }
        ];
    };
  };
}
