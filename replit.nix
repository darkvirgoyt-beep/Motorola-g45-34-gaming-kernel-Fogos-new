{pkgs}: {
  deps = [
    pkgs.python312Packages.flask
    pkgs.gcc
    pkgs.glibc
    pkgs.libelf
    pkgs.elfutils
    pkgs.perl
    pkgs.python3
    pkgs.zip
    pkgs.ncurses
    pkgs.openssl
    pkgs.bison
    pkgs.flex
    pkgs.bc
    pkgs.binutils
    pkgs.llvm
    pkgs.lld
    pkgs.clang
  ];
}
