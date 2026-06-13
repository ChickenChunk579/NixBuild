{ lib }:
{
  name = "make";

  generate = projectIR:
    let
      genTargetRules = name: target:
        let
          incFlags = lib.concatMapStringsSep " " (d: "-I${d}") target.includeDirs;
          libDirs = lib.concatMapStringsSep " " (d: "-L${d}") target.libraryDirs;
          libs = lib.concatMapStringsSep " " (l: "-l${l}") target.libraries;
          ldFlagsAll = lib.concatStringsSep " " target.ldflags;

          objFiles = map (src: src.objectFile) target.processedSources;
          objListStr = lib.concatStringsSep " " objFiles;

          depOutputs = map (d: projectIR.targets.${d}.output) target.dependencies;
          depOutputsStr = lib.concatStringsSep " " depOutputs;

          depFiles = map (src: lib.substring 0 ((lib.stringLength src.objectFile) - 2) src.objectFile + ".d") target.processedSources;
          depListStr = lib.concatStringsSep " " depFiles;

          srcRules = lib.zipListsWith (src: depFile:
            let
              localFlags = lib.concatStringsSep " " target.${src.langFlagsKey};
              toolLabel = if src.compilerTool == "g++" || src.compilerTool == "clang++" then "CXX"
                          else if src.compilerTool == "as" then "AS"
                          else "CC";
            in
            ''
${src.objectFile}: ${src.sourceFile}
	@mkdir -p $(dir $@)
	@$(call LOG,${toolLabel},$< -> $@)
	@${src.compilerTool} ${localFlags} ${incFlags} -MMD -MP -MF ${depFile} -c $< -o $@
''
          ) target.processedSources depFiles;

          truncatedInputs = if (builtins.length objFiles) > 10 then 
                              (lib.concatStringsSep ", " (lib.take 10 objFiles)) + ", ..."
                            else 
                              lib.concatStringsSep ", " objFiles;

          linkRule = if target.type == "executable" then ''
${target.output}: ${objListStr} ${depOutputsStr}
	@mkdir -p $(dir $@)
	@$(call LOG,LD,${truncatedInputs} -> $@)
	@${projectIR.toolchain.cc} ${objListStr} ${depOutputsStr} ${libDirs} ${libs} ${ldFlagsAll} -o $@
''
          else if target.type == "shared-library" then ''
${target.output}: ${objListStr} ${depOutputsStr}
	@mkdir -p $(dir $@)
	@$(call LOG,LD,${truncatedInputs} -> $@)
	@${projectIR.toolchain.cc} -shared ${objListStr} ${depOutputsStr} ${libDirs} ${libs} ${ldFlagsAll} -o $@
''
          else if target.type == "static-library" then ''
${target.output}: ${objListStr}
	@mkdir -p $(dir $@)
	@$(call LOG,AR,${truncatedInputs} -> $@)
	@${projectIR.toolchain.ar} rcs $@ ${objListStr}
''
          else ''
'';
        in
          {
            rules = lib.concatStringsSep "" srcRules + linkRule;
            inherit depListStr;
          };

      allTargetOutputs = lib.mapAttrsToList (n: t: t.output) projectIR.targets;
      processedTargets = lib.mapAttrsToList genTargetRules projectIR.targets;
      
      allTargetRules = map (t: t.rules) processedTargets;
      allDepFilesStr = lib.concatStringsSep " " (lib.filter (s: s != "") (map (t: t.depListStr) processedTargets));

      makefileContent = ''
.PHONY: all clean

START_TIME := $(shell perl -MTime::HiRes=time -e 'print time')

CLR_TIME  := \033[36m
CLR_TOOL  := \033[1;35m
CLR_TEXT  := \033[0m
CLR_RESET := \033[0m

define LOG
	@NOW=$$(perl -MTime::HiRes=time -e 'print time'); \
	DIFF=$$(echo "$$NOW - $(START_TIME)" | bc 2>/dev/null || perl -e "print $$NOW - $(START_TIME)"); \
	MIN=$$(printf "%.0f" $$(echo "$$DIFF / 60" | bc 2>/dev/null || perl -e "print int($$DIFF / 60)")); \
	SEC=$$(printf "%.0f" $$(echo "$$DIFF % 60" | bc 2>/dev/null || perl -e "print int($$DIFF % 60)")); \
	MS=$$(printf "%03d" $$(echo "($$DIFF * 1000) % 1000" | bc 2>/dev/null || perl -e "print int(($$DIFF * 1000) % 1000)")); \
	printf "$(CLR_TIME)[%02d:%02d:%s]$(CLR_RESET) $(CLR_TOOL)[%s]$(CLR_RESET) $(CLR_TEXT)%s$(CLR_RESET)\n" $$MIN $$SEC $$MS "$(1)" "$(2)"
endef

NIX_FILES := $(shell find flake.nix nb/ -type f 2>/dev/null)
TIME_STAMP_FILE := build/.nixbuild.time

all: $(TIME_STAMP_FILE) ${lib.concatStringsSep " " allTargetOutputs}

${lib.concatStringsSep "\n" allTargetRules}
clean:
	@$(call LOG,RM,build/)
	@rm -rf build/

ifneq ($(MAKECMDGOALS),clean)
-include ${allDepFilesStr}
endif

$(TIME_STAMP_FILE): $(NIX_FILES)
	@mkdir -p $(dir $@)
	@$(call LOG,NIX,flake.nix.#makefile)
	@nix build .#makefile
	@touch $@
'';
    in {
      files = {
        "Makefile" = makefileContent;
      };
    };
}
