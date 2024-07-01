#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=nasm
PKG_VER=2.16.03
PKG_URL=https://www.nasm.us/pub/nasm/releasebuilds/$PKG_VER/$PKG_NAME-$PKG_VER.tar.xz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR

. $FWD/common.sh

clean_build()
{
  echo [$0] Cleaning $PKG_NAME $PKG_VER
  cd $CWD
  if [ -d $BUILD_DIR ]; then
    if [ "$BUILD_DIR" != "$SRC_DIR" ]; then
      rm -rf $BUILD_DIR
    else
      cd $BUILD_DIR
      nmake -f Mkfiles/msvc.mak clean > >(build_log) 2>&1 || print_error
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

  local archive=$PKG_NAME-$PKG_VER.tar.xz
  cd $TAGS_DIR
  if [ ! -f "$archive" ]; then
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  elif ! xz -t "$archive" &>/dev/null; then
    echo [$0] "File $archive is corrupted, redownload it again"
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  fi
  if [ ! -d "$SRC_DIR" ]; then
    cd $PKGS_DIR
    tar -xJvf $TAGS_DIR/$archive || print_error
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  nmake -f Mkfiles/msvc.mak prefix=$PREFIX_W > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cp -rv *.exe $PREFIX/bin > >(build_log) 2>&1 || print_error
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
