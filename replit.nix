{pkgs}: {
  deps = [
    pkgs.gcc-arm-embedded
    pkgs.ccache
    pkgs.unzip
    pkgs.zip
    pkgs.python3
    pkgs.rsync
    pkgs.cpio
    pkgs.elfutils
    pkgs.bc
    pkgs.openssl
    pkgs.bison
    pkgs.flex
    pkgs.lld
    pkgs.llvm
    pkgs.clang
  ];
}
