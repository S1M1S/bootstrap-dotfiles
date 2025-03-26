nix run github:s1m1s/bootstrap-dotfiles

nix-shell -p git-crypt --run "cd '~/dotfiles/nix'; nixos-rebuild switch --flake .";
