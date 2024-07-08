#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='llvm-project'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=ccls
PKG_VER=0.20240202
PKG_URL=https://github.com/MaskRay/$PKG_NAME.git
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
    git clone --depth 1 --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf $SRC_DIR
    git clone --depth 1 --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
  else
    cd $SRC_DIR
    local branch_ver=`git name-rev --name-only HEAD | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'`
    if [ "$PKG_VER" == "$branch_ver" ]; then
      echo [$0] Branch version is $branch_ver 
      for m in `git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(modified content\))'`; do
        rm -rfv $m
      done
      git submodule update --init --recursive --depth 1
    else
      cd $PKGS_DIR
      echo [$0] Deleting the old branch version $branch_ver
      rm -rf $SRC_DIR 
      echo [$0] Cloning the new branch version $PKG_VER
      git clone --depth 1 --recurse-submodules --shallow-submodules -b $PKG_VER $PKG_URL || print_error
    fi
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  check_triplet
  cd $BUILD_DIR
  OPTIONS='-MD -fp:precise -diagnostics:column -wd4819 -openmp:llvm'
  DEFINES="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE"
  LLVM_PROJECT_PREFIX=`grep -E "\w+\s+llvm-project\s+.+" $OK_FILE | awk '{print substr($0, index($0, $4))}' | awk '{$1=$1};1'`
  export PATH=`cygpath -u "$LLVM_PROJECT_PREFIX"`/bin:$PATH
  # NOTE:
  # 1. Don't install cygwin's cmake because it will use gcc-like compile
  #    command. To use windows's cmake, here have to use 'cygpath -m' to
  #    convert path to windows path but not cygwin path
  # 2. Don't set cmake generator to 'Unix Makefiles' if use MSYS2 shell
  cmake -G "Ninja"                                                                                             \
    -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld-link                                                                 \
    -DCLANG_RESOURCE_DIR=$LLVM_PROJECT_PREFIX/lib/clang/18                                                     \
    -DCMAKE_INSTALL_PREFIX="$PREFIX_M"                                                                         \
    -DCMAKE_C_COMPILER=clang-cl                                                                                \
    -DCMAKE_C_FLAGS="$OPTIONS $DEFINES $INCLUDES"                                                              \
    -DCMAKE_CXX_COMPILER=clang-cl                                                                              \
    -DCMAKE_CXX_FLAGS="-EHsc $OPTIONS $DEFINES $INCLUDES"                                                      \
    -DCMAKE_BUILD_TYPE=Release                                                                                 \
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH_M"                                                                       \
    -DCMAKE_POLICY_DEFAULT_CMP0074=OLD                                                                         \
    $SRC_DIR_M > >(build_log) 2>&1 || print_error
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
