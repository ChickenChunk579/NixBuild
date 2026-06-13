{ lib }:
{
  name = "ninja";

  generate = projectIR:
    let
      header = ''
ninja_required_version = 1.3
builddir = build
'';

      rules = ''
rule cc_compile
  command = $compiler $flags $includes -MMD -MT $out -MF $out.d -c $in -o $out
  description = CC $out
  depfile = $out.d
  deps = gcc

rule ar_archive
  command = rm -f $out && $ar rcs $out $in
  description = AR $out

rule link_exec
  command = $compiler $in $libdirs $libs $ldflags -o $out
  description = LINK $out
'';

      genTargetStatements = name: target:
        let
          incFlags = lib.concatMapStringsSep " " (d: "-I${d}") target.includeDirs;
          libDirs = lib.concatMapStringsSep " " (d: "-L${d}") target.libraryDirs;
          libs = lib.concatMapStringsSep " " (l: "-l${l}") target.libraries;
          ldFlagsAll = lib.concatStringsSep " " target.ldflags;

          objStatements = map (src:
            let
              localFlags = lib.concatStringsSep " " target.${src.langFlagsKey};
            in
            ''
build ${src.objectFile}: cc_compile ${src.sourceFile}
  compiler = ${src.compilerTool}
  flags = ${localFlags}
  includes = ${incFlags}
''
          ) target.processedSources;

          objFiles = map (src: src.objectFile) target.processedSources;
          objListStr = lib.concatStringsSep " " objFiles;

          depOutputs = map (d: projectIR.targets.${d}.output) target.dependencies;
          explicitDepStr = if lib.length depOutputs > 0 
                           then " " + lib.concatStringsSep " " depOutputs 
                           else "";

          linkStatement = if target.type == "executable" then ''
build ${target.output}: link_exec ${objListStr}${explicitDepStr}
  compiler = ${projectIR.toolchain.cc}
  libdirs = ${libDirs}
  libs = ${libs}
  ldflags = ${ldFlagsAll}
''
          else if target.type == "shared-library" then ''
build ${target.output}: link_exec ${objListStr}${explicitDepStr}
  compiler = ${projectIR.toolchain.cc}
  libdirs = ${libDirs}
  libs = ${libs}
  ldflags = -shared ${ldFlagsAll}
''
          else if target.type == "static-library" then ''
build ${target.output}: ar_archive ${objListStr}
  ar = ${projectIR.toolchain.ar}
''
          else "";
        in
          lib.concatStringsSep "" objStatements + linkStatement;

      targetBlocks = lib.mapAttrsToList genTargetStatements projectIR.targets;
      allOutputs = lib.mapAttrsToList (n: t: t.output) projectIR.targets;
      defaultStatement = "\ndefault " + lib.concatStringsSep " " allOutputs + "\n";

      ninjaContent = header + rules + lib.concatStringsSep "\n" targetBlocks + defaultStatement;
    in {
      files = {
        "build.ninja" = ninjaContent;
      };
    };
}
