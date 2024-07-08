#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=giflib
PKG_VER=5.2.2
PKG_URL=https://sourceforge.net/projects/giflib/files/$PKG_NAME-$PKG_VER.tar.gz
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
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
      rm -rfv *.o *.obj *.exp *.lib *.dll *.exe
      popd
    fi
  fi
}

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR
  patch -Np1 -i $PATCHES_DIR/001-giflib-5.2.2-fix-issue-of-missing-getopt.diff
  patch -Np1 -i $PATCHES_DIR/002-giflib-5.2.2-fix-unresolved-external-symbol-strtok_r.diff
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
  cl /nologo /MD /O2 /c /D_WIN32 *.c > >(build_log) 2>&1 || print_error
  echo [$0] Buildling libgif.lib/gif.dll/gif.lib
  local sources='dgif_lib.c egif_lib.c gifalloc.c gif_err.c gif_font.c gif_hash.c openbsd-reallocarray.c'
  local objects=${sources//.c/.obj}
  link /NOLOGO /DLL /IMPLIB:gif.lib /OUT:gif.dll $objects > >(build_log) 2>&1 || print_error
  lib /OUT:libgif.lib $objects > >(build_log) 2>&1 || print_error
  echo [$0] Building libutil.lib/util.dll/util.lib
  local usources='qprintf.c quantize.c getarg.c'
  local uobjects=${usources//.c/.obj}
  link /NOLOGO /DLL /IMPLIB:util.lib /OUT:util.dll $uobjects libgif.lib > >(build_log) 2>&1 || print_error
  lib /OUT:libutil.lib $uobjects > >(build_log) 2>&1 || print_error
  echo [$0] Building .exe
  link /NOLOGO /OUT:gif2rgb.exe gif2rgb.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifbuild.exe gifbuild.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:giffix.exe giffix.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:giftext.exe giftext.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:giftool.exe giftool.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifclrmp.exe gifclrmp.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifbg.exe gifbg.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifcolor.exe gifcolor.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifecho.exe gifecho.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:giffilter.exe giffilter.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifhisto.exe gifhisto.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifinto.exe gifinto.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifsponge.exe gifsponge.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
  link /NOLOGO /OUT:gifwedge.exe gifwedge.obj getopt.obj libgif.lib libutil.lib > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  cp -rv *.exe $PREFIX/bin
  cp -rv *.lib $PREFIX/lib
  cp -rv *.dll $PREFIX/bin
  cp -rv gif_lib.h $PREFIX/include
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
