#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=lua
PKG_VER=5.4.6
PKG_URL=https://www.lua.org/ftp/$PKG_NAME-$PKG_VER.tar.gz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$SRC_DIR/src

. $FWD/common.sh

clean_build()
{
  echo [$0] Cleaning $PKG_NAME $PKG_VER
  cd $CWD
  if [ -d "$BUILD_DIR" ]; then
    pushd $BUILD_DIR
    rm -rfv *.o *.obj *.exp *.lib *.dll *.exe
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

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  local pkg_ver_trim=`echo ${PKG_VER%.*} | awk -F "." '{print $1 $2}'`
  local all_obj=$(ls *.c)
  local base_obj=`echo $all_obj | sed -e 's|lua[a-z]*.c\s*||g'`
  # modified from https://blog.spreendigital.de/2020/05/21/how-to-compile-lua-5-4-0-for-windows/
  cl /nologo /MD /O2 /c /DLUA_COMPAT_5_3 /DLUA_BUILD_AS_DLL /D_CRT_DECLARE_NONSTDC_NAMES /D_CRT_NONSTDC_NO_DEPRECATE *.c > >(build_log) 2>&1 || print_error
  link /NOLOGO /DLL /IMPLIB:lua.lib /OUT:lua$pkg_ver_trim.dll ${base_obj//.c/.obj} > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:lua.exe lua.obj lua.lib > >(build_log) 2>&1 || print_error
  lib /OUT:liblua.lib ${base_obj//.c/.obj} > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:luac.exe luac.obj liblua.lib > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cp -rv *.exe $PREFIX/bin
  cp -rv *.lib $PREFIX/lib
  cp -rv *.dll $PREFIX/bin
  cp -rv lauxlib.h $PREFIX/include
  cp -rv lua*.h $PREFIX/include
  cp -rv lua*.hpp $PREFIX/include
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
