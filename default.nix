# Non-flake entry point: `nix-build -A contextFonts` (or -A minmath, ...).
{pkgs ? import <nixpkgs> {config.allowUnfree = true;}}:
import ./nix/packages.nix pkgs
