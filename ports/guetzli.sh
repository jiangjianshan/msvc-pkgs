#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='libpng'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=guetzli
PKG_VER=1.0.1
PKG_URL=https://github.com/google/guetzli/archive/refs/tags/v$PKG_VER.tar.gz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
# NOTE:
# 1. Make the root of build directories and source directories are exactly the same.
#    Otherwise cygwin path will cause most header files can't be found during compiling
BUILD_DIR=$SRC_DIR

. $FWD/common.sh

clean_build()
{
  echo [$0] Cleaning $PKG_NAME $PKG_VER
  cd $CWD
  if [ -d "$BUILD_DIR" ]; then
    pushd $BUILD_DIR
    rm -rf bin obj
    popd
  fi
}

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR
  patch -Np1 -i $PATCHES_DIR/001-guetzli-1.0.1-fix-link-error.diff
  popd
}

prepare_package()
{
  clean_build
  clean_log
  create_dirs
  check_depends
  display_info

  local archive=$PKG_NAME-$PKG_VER.tgz
  cd $TAGS_DIR
  if [ ! -f "$archive" ]; then
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  elif ! gzip -t "$archive" &>/dev/null; then
    echo [$0] "File $archive is corrupted, redownload it again"
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  fi
  if [ ! -d "$SRC_DIR" ]; then
    cd $PKGS_DIR
    tar -xzvf $TAGS_DIR/$archive || print_error
    patch_package
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cmd /c "msbuild guetzli.sln /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v143 /p:UseEnv=true /p:SkipUWP=true" > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cp -rv bin/x86_64/Release/guetzli.exe $PREFIX_M/bin > >(build_log) 2>&1 || print_error
  clean_build
  build_ok
}

process_build()
{
  prepare_package
  build_package
  install_package
}

build_decision
