#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='libidn2 libunistring pkg-config'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=libpsl
PKG_VER=0.21.5
PKG_URL=https://github.com/rockdaboot/$PKG_NAME.git
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME
BUILD_DIR=$FWD/builds/$PKG_NAME

. $FWD/common.sh

clean_build()
{
  echo [$0] Cleaning $PKG_NAME $PKG_VER
  cd $CWD
  if [ -d "$BUILD_DIR" ]; then
    if [ "$BUILD_DIR" != "$SRC_DIR" ]; then
      rm -rf $BUILD_DIR
    else
      pushd $BUILD_DIR
      ninja clean
      popd
    fi
  fi
}

prepare_package()
{
  clean_build
  clean_log
  create_dirs
  check_depends
  display_info
  cd $PKGS_DIR
  if [ ! -d "$SRC_DIR" ]; then
    git clone --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf $SRC_DIR
    git clone --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
  else
    cd $SRC_DIR
    local branch_ver=`git name-rev --name-only HEAD | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'`
    if [ "$PKG_VER" == "$branch_ver" ]; then
      echo [$0] Branch version is $branch_ver 
      for m in `git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(modified content\))'`; do
        rm -rfv $m
      done
      git submodule update --init --recursive
    else
      cd $PKGS_DIR
      echo [$0] Deleting the old branch version $branch_ver
      rm -rf $SRC_DIR 
      echo [$0] Cloning the new branch version $PKG_VER
      git clone --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
    fi
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  check_triplet
  cd $SRC_DIR
  OPTIONS='-MD -fp:precise -diagnostics:column -wd4819 -openmp:llvm'
  DEFINES="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE -Dstrcasecmp=stricmp"
  export PKG_CONFIG="`where pkg-config.exe` --msvc-syntax"
  # https://mesonbuild.com/Builtin-options.html
  # https://mesonbuild.com/Commands.html
  # NOTE:
  # 1. Don't use '-L' or '-LIBPATH' in c_link_args or cpp_link_args, you have to use
  #    '/LIBPATH'. Otherwise meson will not insert /LIBPATH just after '/link' and
  #    throw out and error so that can't find third party
  meson setup $BUILD_DIR_M                                                                     \
    --buildtype=release                                                                        \
    --prefix="$PREFIX_M"                                                                       \
    --mandir="$PREFIX_M/share/man"                                                             \
    --cmake-prefix-path="$PREFIX_PATH_M"                                                       \
    -Dc_std=c17                                                                                \
    -Dc_args="$OPTIONS $DEFINES $INCLUDES"                                                     \
    -Dc_link_args="$MESON_LDFLAGS"                                                             \
    -Dcpp_std=c++17                                                                            \
    -Dcpp_args="-EHsc $OPTIONS $DEFINES $INCLUDES"                                             \
    -Dcpp_link_args="$MESON_LDFLAGS"                                                           \
    -Dc_winlibs="Ole32.lib,User32.lib"                                                         \
    -Dcpp_winlibs="Ole32.lib,User32.lib" > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  ninja -j$(nproc) > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  ninja install > >(build_log) 2>&1 || print_error
  clean_build
  build_ok
}

process_build()
{
  prepare_package
  configure_package
  build_package
  install_package
}

build_decision
