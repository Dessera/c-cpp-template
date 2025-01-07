{
  description = "Standard C/C++ development environment with meson";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixcode = {
      url = "github:Dessera/nixcode";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        systems = [ "x86_64-linux" ];

        perSystem =
          {
            self',
            pkgs,
            system,
            ...
          }:
          let
            stdenv = pkgs.gcc14Stdenv;

            clang-tools = pkgs.callPackage ./.nix-support/clang-tools.nix {
              inherit stdenv;
            };

            codium = withSystem system ({ inputs', ... }: inputs'.nixcode.packages.c_cpp);
          in
          {
            packages.default = pkgs.callPackage ./default.nix { inherit stdenv; };
            devShells.default =
              pkgs.mkShell.override
                {
                  inherit stdenv;
                }
                {
                  inputsFrom = [ self'.packages.default ];

                  packages =
                    (with pkgs; [
                      nixd
                      nixfmt-rfc-style
                      mesonlsp
                    ])
                    ++ [
                      clang-tools
                      codium
                    ];
                };
          };
      }
    );
}
