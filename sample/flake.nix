{
  description = "NixBuild Sample Project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixbuild.url = "github:ChickenChunk579/NixBuild";
  };

  outputs = { self, nixpkgs, nixbuild }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});

      myProject = nixbuild.lib.mkProject {
        name = "my-local-project";

        toolchain = {
          cc = "gcc";
          ar = "ar";
        };

        globalFlags = {
          cflags = [ "-O2" "-Wall" "-Wextra" ];
        };

        targets = {
          foo = {
            type = "static-library";
            sources = [ "src/lib.c" ];
            includeDirs = [ "include" ];
          };

          app = {
            type = "executable";
            sources = [ "src/main.c" ];
            includeDirs = [ "include" ];
            dependencies = [ "foo" ];
          };
        };
      };

    in {
      packages = forEachSystem (pkgs: {
        makefile = nixbuild.generators.${pkgs.system}.make myProject;
        ninja = nixbuild.generators.${pkgs.system}.ninja myProject;
        default = self.packages.${pkgs.system}.ninja;
      });

      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ ninja gnumake gcc ];
        };
      });
    };
}
