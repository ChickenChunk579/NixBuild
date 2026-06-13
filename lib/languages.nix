{ lib }:
{
  registry = {
    ".c"   = { compiler = "cc";  flags = "cflags";   lang = "C"; };
    ".cpp" = { compiler = "cxx"; flags = "cxxflags"; lang = "CXX"; };
    ".cc"  = { compiler = "cxx"; flags = "cxxflags"; lang = "CXX"; };
    ".cxx" = { compiler = "cxx"; flags = "cxxflags"; lang = "CXX"; };
    ".s"   = { compiler = "as";  flags = "asflags";  lang = "ASM"; };
    ".S"   = { compiler = "as";  flags = "asflags";  lang = "ASM"; };
    ".asm" = { compiler = "as";  flags = "asflags";  lang = "ASM"; };
  };
}
