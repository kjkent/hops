{
  description = "Development environment for hops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    shellPlatforms = [ "x86_64-linux" ];

    mkShellSpec = system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      default = pkgs.mkShell {
        name = "hops-dev-env";
        nativeBuildInputs = with pkgs; [
          nixd
          nixfmt-rfc-style
          git

          opentofu
        ];

        shellHook = ''
          clear
          echo "🚀 Development environment initialized!"
          echo ""
          echo "Project: hops"
        '';
      };
    };
  in with nixpkgs.lib; {
    devShells = genAttrs shellPlatforms mkShellSpec;
  };
}
