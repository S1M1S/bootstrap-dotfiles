{
  description = "Bootstrap dotfiles setup script";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Common dependencies
        commonDeps = with pkgs; [
          git
          git-crypt
          gnupg
          vim
        ];
        
        # Platform-specific dependencies
        platformDeps = if pkgs.stdenv.isDarwin 
          then [ ] 
          else [ pkgs.pinentry-curses ];

        # Build script with improved error handling and logging
        bootstrap-script = pkgs.writeScriptBin "bootstrap-dotfiles" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          
          # Logging function
          log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
          
          # Cleanup function
          cleanup() {
            local exit_code=$?
            [[ -f "$PRIVATE_KEY" ]] && shred -u "$PRIVATE_KEY" 2>/dev/null
            exit "$exit_code"
          }
          trap cleanup EXIT
          
          ${builtins.readFile ./script.sh}
        '';

      in {
        packages.default = pkgs.symlinkJoin {
          name = "bootstrap-dotfiles";
          paths = [ bootstrap-script ] ++ commonDeps ++ platformDeps;
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/bootstrap-dotfiles \
              --prefix PATH : ${pkgs.lib.makeBinPath (commonDeps ++ platformDeps)}
          '';
        };

        devShell = pkgs.mkShell {
          buildInputs = commonDeps ++ platformDeps;
          shellHook = ''
            export GPG_TTY=$(tty)
            export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
          '';
        };

        checks = {
          test = pkgs.nixosTest {
            name = "bootstrap-dotfiles-test";
            nodes.machine = { ... }: {
              imports = [ self.nixosModule ];
              environment.systemPackages = [ self.packages.${system}.default ];
            };
            testScript = ''
              machine.succeed("bootstrap-dotfiles --version")
            '';
          };
        };
      });
}
