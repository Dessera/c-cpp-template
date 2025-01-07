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
            inherit (pkgs) lib;
            stdenv = pkgs.llvmPackages_19.libcxxStdenv;

            findPath =
              reg: base:
              let
                match = path: if (builtins.match reg path) != null then path else null;
                # ugly but works
                appendAbsPath =
                  base: sub:
                  lib.concatStringsSep "/" [
                    base
                    sub
                  ];
                go =
                  path:
                  let
                    entries = builtins.attrNames (
                      lib.filterAttrs (name: type: type == "directory") (builtins.readDir path)
                    );
                    absEntries = map (appendAbsPath path) entries;
                    matches = builtins.filter (m: m != null) (map match absEntries);
                  in
                  matches ++ builtins.concatLists (map go absEntries);
              in
              go base;

            codium = withSystem system ({ inputs', ... }: inputs'.nixcode.packages.c_cpp);
          in
          {
            packages.default = pkgs.callPackage ./default.nix { inherit stdenv; };
            devShells.default =
              pkgs.mkShell.override
                {
                  inherit stdenv;
                }
                rec {
                  inputsFrom = [ self'.packages.default ];

                  packages =
                    (with pkgs; [
                      nixd
                      nixfmt-rfc-style
                      mesonlsp
                      clang-tools
                    ])
                    ++ [
                      codium
                    ];

                  # shit, but seriously i have no idea:(
                  # only supports gcc & clang, to find compiler builtin library
                  CPATH = builtins.concatStringsSep ":" (
                    [
                      (lib.makeIncludePath [ stdenv.cc.libc ])
                    ]
                    ++ (
                      if stdenv.cc.isGNU then
                        (findPath ".*/lib/gcc/.*([0-9\.]+)/include" stdenv.cc.cc.outPath)
                      else if stdenv.cc.isClang then
                        [ "${stdenv.cc}/resource-root/include" ]
                      else
                        [ ]
                    )
                  );
                  C_INCLUDE_PATH = CPATH;

                  # to find libstdcxx or libcxx
                  CPLUS_INCLUDE_PATH = lib.concatStringsSep ":" (
                    (
                      let
                        incBase = if stdenv.cc.libcxx == null then stdenv.cc.cc.stdenv.cc.cc else stdenv.cc.libcxx.dev;
                      in
                      findPath ".*/include/c[\+]{2}/([\.0-9a-zA-Z_-]+)(/[^/]+-[^/]+)?" incBase.outPath
                    )
                    ++ [
                      CPATH
                    ]
                  );
                };
          };
      }
    );
}
