{ lib }:
let
  languages = import ./languages.nix { inherit lib; };
  targetTypes = import ./targetTypes.nix { inherit lib; };
in
{
  validateProject = projectIR:
    let
      validateTargetType = name: target:
        if !(lib.hasAttr target.type targetTypes.registry)
        then throw "Validation Error [Project: ${projectIR.name}]: Target '${name}' specifies an unknown type '${target.type}'."
        else true;

      allOutputs = lib.mapAttrsToList (n: t: { inherit n; inherit (t) output; }) projectIR.targets;
      duplicateOutputs = lib.filter (x: (lib.length (lib.filter (y: y.output == x.output) allOutputs)) > 1) allOutputs;
      _validateDuplicates = if lib.length duplicateOutputs > 0 
        then throw "Validation Error [Project: ${projectIR.name}]: Duplicate output destination path target detected for '${(lib.head duplicateOutputs).output}'"
        else true;

      validateSources = name: target:
        map (src: 
          if !(lib.hasAttr src.extension languages.registry)
          then throw "Validation Error [Target: ${name}]: File '${src.sourceFile}' maps to an unsupported extension registry type '${src.extension}'."
          else true
        ) target.processedSources;

      validateDepsExist = name: target:
        map (dep:
          if !(lib.hasAttr dep projectIR.targets)
          then throw "Validation Error [Target: ${name}]: Declared dependency relationship target '${dep}' cannot be found."
          else true
        ) target.dependencies;

      checkCycles = current: visited:
        if lib.elem current visited
        then throw "Validation Error [Project: ${projectIR.name}]: Cyclic dependency chain detected tracking path: ${lib.concatStringsSep " -> " (visited ++ [current])}"
        else 
          let 
            target = projectIR.targets.${current};
          in map (dep: checkCycles dep (visited ++ [current])) target.dependencies;

      _validateCycles = lib.mapAttrsToList (name: target: checkCycles name []) projectIR.targets;

    in
      lib.deepSeq (lib.mapAttrsToList validateTargetType projectIR.targets)
      (lib.deepSeq (lib.mapAttrsToList validateSources projectIR.targets)
      (lib.deepSeq (lib.mapAttrsToList validateDepsExist projectIR.targets)
      projectIR));
}
