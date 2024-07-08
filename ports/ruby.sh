#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='openssl libffi'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=ruby
PKG_VER=3.3.1
PKG_URL=https://cache.ruby-lang.org/pub/ruby/`echo ${PKG_VER} | cut -d. -f1`.`echo ${PKG_VER} | cut -d. -f2`/$PKG_NAME-$PKG_VER.tar.gz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
# NOTE: When compiling ruby from source tarball by hand, if you got executable host ruby is required. use --with-baseruby option. 
#       Then this can be the reason.
#       make distclean (assume you configure'ed once) then configure and make, got executable host ruby is required. 
#       use --with-baseruby option distclean cleans out some file generated from erb, which requiring a existing ruby.
BUILD_DIR=$SRC_DIR

. $FWD/common.sh

clean_build()
{
  cd $CWD
  if [ -d "$BUILD_DIR" ]; then
    cd $BUILD_DIR
    rm -rf .ext
    rm -rf x64-mswin64_140
    rm -rf *.exp *.lib *.obj *.pdb *.so *.time *.status Makefile
  fi
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
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cmd /c ".\\win32\\configure.bat --prefix=$PREFIX_W --with-opt-dir=$PREFIX_W --disable-install-doc" > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cmd /c "nmake" || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cmd /c "nmake install" > >(build_log) 2>&1 || print_error
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
