#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=icu4c
PKG_VER=75_1
# NOTE:
# 1. Don't use the archive, it is missing the file '$srcdir/data/locales/root.txt'.
#    It will cause the content of data/rules.mk is empty, so that will throw out the
#    error: no rule to make target "out/tmp/dirs.timestamp" needed by "out/tmp/icudata.res"
PKG_URL=https://github.com/unicode-org/icu/releases/download/release-${PKG_VER//_/-}/$PKG_NAME-$PKG_VER-src.tgz
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
    rm -rf bin${ARCH/x/} include lib${ARCH/x/}
    popd
  fi
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
    mv icu $PKG_NAME-$PKG_VER
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cmd /c "msbuild source/allinone/allinone.sln /p:Configuration=Release /p:Platform=x64 /p:SkipUWP=true" > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cp -rv bin${ARCH/x/}/*.* $PREFIX_M/bin > >(build_log) 2>&1 || print_error
  cp -rv include/unicode $PREFIX_M/include > >(build_log) 2>&1 || print_error
  cp -rv lib${ARCH/x/}/*.lib $PREFIX_M/lib > >(build_log) 2>&1 || print_error
  clean_build
  build_ok icu
}

process_build()
{
  prepare_package
  build_package
  install_package
}

build_decision icu
