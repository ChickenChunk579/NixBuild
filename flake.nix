{
  description = "NixBuild - A modular, extensible meta-build generation framework";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
      
      lib = import ./lib/mkProject.nix { inherit (nixpkgs) lib; };
      
      generatorsList = [
        (import ./lib/generators/make.nix { inherit (nixpkgs) lib; })
        (import ./lib/generators/ninja.nix { inherit (nixpkgs) lib; })
      ];
      
      generators = nixpkgs.lib.listToAttrs (map (g: { name = g.name; value = g; }) generatorsList);

      mkGeneratorWrapper = pkgs: generator: projectInput:
        let
          projectIR = if projectInput ? _isProjectIR then projectInput else lib.mkProject projectInput;
          generationResult = generator.generate projectIR;
          
          buildFilesDrv = pkgs.stdenv.mkDerivation {
            name = "${projectIR.name}-${generator.name}-files";
            
            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;
            
            phases = [ "installPhase" ];
            
            installPhase = ''
              mkdir -p $out
            '' + (nixpkgs.lib.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList (filename: content: ''
              mkdir -p "$(dirname "$out/${filename}")"
              cat << 'EOF' > "$out/${filename}"
              ${content}
              EOF
            '') generationResult.files));
          };
        in buildFilesDrv;

    in {
      inherit lib;

      generators = forEachSystem (pkgs: 
        nixpkgs.lib.mapAttrs (name: gen: mkGeneratorWrapper pkgs gen) generators
      );

      checks = forEachSystem (pkgs: {
        exampleBuild = 
          let
            proj = self.lib.mkProject {
              name = "internal-validation-app";
              toolchain = { cc = "gcc"; cxx = "g++"; ar = "ar"; };
              targets = {
                mylib = {
                  type = "static-library";
                  sources = [ "src/lib.c" ];
                };
                app = {
                  type = "executable";
                  sources = [ "src/main.cpp" ];
                  dependencies = [ "mylib" ];
                };
              };
            };
          in self.generators.${pkgs.system}.ninja proj;
      });
    };
}
