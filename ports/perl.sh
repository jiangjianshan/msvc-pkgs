#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=perl
PKG_VER=5.38.2
PKG_URL=https://www.cpan.org/src/${PKG_VER%%.*}.0/$PKG_NAME-$PKG_VER.tar.gz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR/win32

. $FWD/common.sh

clean_build()
{
  echo [$0] Cleaning $PKG_NAME $PKG_VER
  cd $CWD
  if [ -d $BUILD_DIR ]; then
    cd $BUILD_DIR
    nmake clean CCTYPE=MSVC143 INST_DRV= INST_TOP=$PREFIX_W INST_HTML="$PREFIX_W\\share\\html" > >(build_log) 2>&1
  fi
}

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR
  patch -Np1 -i $PATCHES_DIR/001-perl-5.38.2-fix-nmake-makefiles-errors-on-cygwin.diff
  popd
}

prepare_package()
{
  clean_build
  clean_log
  create_dirs
  check_depends
  display_info

  local archive=$PKG_NAME-$PKG_VER.tar.gz
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
  nmake CCTYPE=MSVC143 INST_DRV= INST_TOP=$PREFIX_W INST_HTML="$PREFIX_W\\share\\html" > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  nmake install CCTYPE=MSVC143 INST_DRV= INST_TOP=$PREFIX_W INST_HTML="$PREFIX_W\\share\\html" > >(build_log) 2>&1 || print_error
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
