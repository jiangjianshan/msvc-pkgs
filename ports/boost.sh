#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='icu libiconv libjpeg-turbo libpng libtiff openssl zlib zstd'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=boost
PKG_VER=1.85.0
PKG_URL=https://github.com/boostorg/$PKG_NAME.git
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
    git clone --recurse-submodules --shallow-submodules -b $PKG_NAME-$PKG_VER $PKG_URL || print_error
  elif [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf $SRC_DIR
    git clone --recurse-submodules --shallow-submodules -b $PKG_NAME-$PKG_VER $PKG_URL || print_error
  else
    cd $SRC_DIR
    local branch_ver=`git name-rev --name-only HEAD | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'`
    if [ "$PKG_VER" == "$branch_ver" ]; then
      echo [$0] Branch version is $branch_ver 
      for m in `git status | grep -oP '(?<=modified:\s{3}).*(?=\s{1}\(modified content\))'`; do
        rm -rfv $m
      done
      git submodule update --init --recursive || print_error
    else
      cd $PKGS_DIR
      echo [$0] Deleting the old branch version $branch_ver
      rm -rf $SRC_DIR 
      echo [$0] Cloning the new branch version $PKG_VER
      git clone --recurse-submodules --shallow-submodules -b $PKG_NAME-$PKG_VER $PKG_URL || print_error
    fi
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
  python -m pip install --upgrade numpy
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  check_triplet
  cd $BUILD_DIR
  OPTIONS='-MD -fp:precise -diagnostics:column -wd4819 -openmp:llvm'
  DEFINES="-DWIN32 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE"
  # NOTE:
  # 1. Don't install cygwin's cmake because it will use gcc-like compile
  #    command. To use windows's cmake, here have to use 'cygpath -m' to
  #    convert path to windows path but not cygwin path
  # 2. Don't set cmake generator to 'Unix Makefiles' if use MSYS2 shell
  # 3. Can't use '-D_WIN32_WINNT=$WIN32_TARGET' option, it will cause error
  #    C3861
  # TODO:
  # 1. If enable BOOST_ENABLE_PYTHON, it will have "libs\python\src\numpy\dtype.cpp(101,83): error C2039: 'elsize': is not a member of '_PyArray_Descr'"
  cmake -G "Ninja"                                                                                             \
    -DBUILD_SHARED_LIBS=ON                                                                                     \
    -DBOOST_ENABLE_MPI=ON                                                                                      \
    -DBOOST_ENABLE_PYTHON=OFF                                                                                  \
    -DCMAKE_BUILD_TYPE=Release                                                                                 \
    -DCMAKE_C_COMPILER=cl                                                                                      \
    -DCMAKE_C_FLAGS="$OPTIONS $DEFINES $INCLUDES"                                                              \
    -DCMAKE_CXX_COMPILER=cl                                                                                    \
    -DCMAKE_CXX_FLAGS="-std:c++20 -EHsc $OPTIONS $DEFINES $INCLUDES"                                           \
    -DCMAKE_INSTALL_PREFIX="$PREFIX_M"                                                                         \
    -DCMAKE_POLICY_DEFAULT_CMP0148=OLD                                                                         \
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH_M"                                                                       \
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
  # NOTE: 
  # 1. Don't put CYGWIN before tar command, otherwise some .tar.* will not be 
  #    extracted successful
  export CYGWIN="winsymlinks:nativestrict"
  if [ ! -d "$PREFIX/include/boost" ]; then
    ln -vs $PREFIX/include/boost-1_85/boost $PREFIX/include/boost
  fi
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
