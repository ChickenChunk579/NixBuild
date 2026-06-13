{ lib }:
{
  registry = {
    "executable"     = { prefix = "build/bin/"; extension = ""; };
    "static-library" = { prefix = "build/lib/lib"; extension = ".a"; };
    "shared-library" = { prefix = "build/lib/lib"; extension = ".so"; };
    "objects"        = { prefix = "build/"; extension = ""; };
  };
}
