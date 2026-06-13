{ lib }:
let
  normalize = import ./normalize.nix { inherit lib; };
  validate = import ./validate.nix { inherit lib; };
in
{
  mkProject = userConfig: 
    let
      normalized = normalize.normalizeProject userConfig;
    in
      validate.validateProject normalized;
}
