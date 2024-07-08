#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='libiconv'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=ctags
PKG_VER=git
PKG_URL=https://github.com/universal-ctags/$PKG_NAME.git
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME
BUILD_DIR=$SRC_DIR

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
      nmake -f mk_mvc.mak clean
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
    git clone --depth 1 --single-branch -b master $PKG_URL || print_error
  else
    pushd $SRC_DIR
    git fetch origin master --depth 1
    git reset --hard origin/master
    popd
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  # MSVC warning C4819 warns some UTF-8 characters (e.g. copyright sign)
  nmake -f mk_mvc.mak WITH_ICONV=yes ICONV_DIR=$PREFIX_W > >(build_log) 2>&1 || print_error
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
