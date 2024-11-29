nix-shell -p curl --run "bash <(curl -s https://raw.githubusercontent.com/S1M1S/bootstrap-dotfiles/refs/heads/main/nix-clone-dotfiles)";

nix-shell -p git-crypt --run "cd '~/dotfiles/nix'; nixos-rebuild switch --flake .";
