#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=pcre
PKG_VER=8.45
PKG_URL=https://sourceforge.net/projects/pcre/files/pcre/$PKG_VER/$PKG_NAME-$PKG_VER.tar.bz2
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME-$PKG_VER
BUILD_DIR=$FWD/builds/$PKG_NAME-$PKG_VER

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

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR
  patch -Np1 -i $PATCHES_DIR/001-pcre-8.45-fix-man-dir-output-location.diff
  popd
}

prepare_package()
{
  clean_build
  clean_log
  create_dirs
  check_depends
  display_info

  local archive=$PKG_NAME-$PKG_VER.tar.bz2
  cd $TAGS_DIR
  if [ ! -f "$archive" ]; then
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  elif ! bzip2 -t "$archive" &>/dev/null; then
    echo [$0] "File $archive is corrupted, redownload it again"
    wget --no-check-certificate $PKG_URL -O $archive || print_error
  fi
  if [ ! -d "$SRC_DIR" ]; then
    cd $PKGS_DIR
    tar -xjvf $TAGS_DIR/$archive || print_error
    patch_package
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
  # NOTE:
  # 1. Don't install cygwin's cmake because it will use gcc-like compile
  #    command. To use windows's cmake, here have to use 'cygpath -m' to
  #    convert path to windows path but not cygwin path
  # 2. Don't set cmake generator to 'Unix Makefiles' if use MSYS2 shell
  cmake -G "Ninja"                                                                                             \
    -DBUILD_SHARED_LIBS=ON                                                                                     \
    -DCMAKE_BUILD_TYPE=Release                                                                                 \
    -DCMAKE_C_COMPILER=cl                                                                                      \
    -DCMAKE_C_FLAGS="$OPTIONS $DEFINES $INCLUDES"                                                              \
    -DCMAKE_CXX_COMPILER=cl                                                                                    \
    -DCMAKE_CXX_FLAGS="-EHsc $OPTIONS $DEFINES $INCLUDES"                                                      \
    -DCMAKE_INSTALL_PREFIX="$PREFIX_M"                                                                         \
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH_M"                                                                       \
    -DCMAKE_POLICY_DEFAULT_CMP0026=OLD                                                                         \
    -DPCRE_BUILD_PCRE16=ON                                                                                     \
    -DPCRE_BUILD_PCRE32=ON                                                                                     \
    -DPCRE_BUILD_PCRE8=ON                                                                                      \
    -DPCRE_BUILD_PCRECPP=ON                                                                                    \
    -DPCRE_BUILD_PCREGREP=ON                                                                                   \
    -DPCRE_BUILD_TESTS=OFF                                                                                     \
    -DPCRE_NEWLINE=ANYCRLF                                                                                     \
    -DPCRE_STATIC_RUNTIME=OFF                                                                                  \
    -DPCRE_SUPPORT_BSR_ANYCRLF=ON                                                                              \
    -DPCRE_SUPPORT_JIT=ON                                                                                      \
    -DPCRE_SUPPORT_LIBBZ2=ON                                                                                   \
    -DPCRE_SUPPORT_LIBZ=ON                                                                                     \
    -DPCRE_SUPPORT_PCREGREP_JIT=OFF                                                                            \
    -DPCRE_SUPPORT_UNICODE_PROPERTIES=ON                                                                       \
    -DPCRE_SUPPORT_UTF=ON                                                                                      \
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
