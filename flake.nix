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

        commonDeps = with pkgs; [
          git
          git-crypt
          gnupg
          vim
        ];

        platformDeps = if pkgs.stdenv.isDarwin
          then [ pkgs.pinentry-curses ]
          else [ pkgs.pinentry-curses ];

      in {
        packages.default = pkgs.stdenv.mkDerivation {
          name = "bootstrap-dotfiles";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          installPhase = ''
            mkdir -p $out/bin
            cp ${./script.sh} $out/bin/bootstrap-dotfiles
            chmod +x $out/bin/bootstrap-dotfiles

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
      });
}
