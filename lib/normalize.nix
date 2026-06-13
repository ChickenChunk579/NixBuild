{ lib }:
let
  languages = import ./languages.nix { inherit lib; };
  targetTypes = import ./targetTypes.nix { inherit lib; };
in
{
  normalizeProject = userConfig:
    let
      name = userConfig.name or "unnamed-project";
      
      toolchain = {
        cc = userConfig.toolchain.cc or "cc";
        cxx = userConfig.toolchain.cxx or "cxx";
        ld = userConfig.toolchain.ld or "ld";
        ar = userConfig.toolchain.ar or "ar";
        as = userConfig.toolchain.as or "as";
        ranlib = userConfig.toolchain.ranlib or "ranlib";
        strip = userConfig.toolchain.strip or "strip";
      };

      globalFlags = {
        cflags = userConfig.globalFlags.cflags or [];
        cxxflags = userConfig.globalFlags.cxxflags or [];
        ldflags = userConfig.globalFlags.ldflags or [];
        asflags = userConfig.globalFlags.asflags or [];
      };

      layoutStrategy = userConfig.layoutStrategy or "flat";

      normalizeTarget = tName: tDef:
        let
          type = tDef.type or "executable";
          tTypeMeta = targetTypes.registry.${type} or { prefix = "build/"; extension = ""; };
          
          output = tDef.output or "${tTypeMeta.prefix}${tName}${tTypeMeta.extension}";

          cflags = globalFlags.cflags ++ (tDef.cflags or []);
          cxxflags = globalFlags.cxxflags ++ (tDef.cxxflags or []);
          ldflags = globalFlags.ldflags ++ (tDef.ldflags or []);
          asflags = globalFlags.asflags ++ (tDef.asflags or []);

          includeDirs = tDef.includeDirs or [];
          libraryDirs = tDef.libraryDirs or [];
          libraries = tDef.libraries or [];
          dependencies = tDef.dependencies or [];
          sources = tDef.sources or [];

          processedSources = map (src:
            let
              ext = "." + (last (lib.splitString "." src));
              last = l: lib.last l;
              langMeta = languages.registry.${ext} or { compiler = "cc"; flags = "cflags"; lang = "unknown"; };
              
              objName = if layoutStrategy == "hierarchical" 
                        then lib.replaceStrings ["../"] ["__."] src + ".o"
                        else (lib.replaceStrings ["/" "."] ["_" "_"] src) + ".o";
              objPath = "build/${tName}/${objName}";
            in {
              sourceFile = src;
              objectFile = objPath;
              compilerTool = toolchain.${langMeta.compiler};
              langFlagsKey = langMeta.flags;
              extension = ext;
            }
          ) sources;

        in {
          inherit type output cflags cxxflags ldflags asflags;
          inherit includeDirs libraryDirs libraries dependencies processedSources;
          name = tName;
        };

      targets = lib.mapAttrs normalizeTarget (userConfig.targets or {});
    in {
      inherit name toolchain globalFlags targets layoutStrategy;
      _isProjectIR = true;
    };
}
