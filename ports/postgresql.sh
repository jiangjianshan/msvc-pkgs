#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='gettext icu libxml2 libxslt lz4 tcl tk perl xz'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=PostgreSQL
PKG_VER=16.3
PKG_URL=https://github.com/postgres/postgres/archive/refs/tags/REL_${PKG_VER/./_}.tar.gz
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
    mv postgres-REL_${PKG_VER/./_} $PKG_NAME-$PKG_VER
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  check_triplet
  PERL_PREFIX=`grep -E "\w+\s+perl\s+.+" $OK_FILE | awk '{print substr($0, index($0, $4))}' | awk '{$1=$1};1'`
  export PKG_CONFIG="`where pkg-config.exe` --msvc-syntax"
  cd $SRC_DIR
  # https://mesonbuild.com/Builtin-options.html
  # https://mesonbuild.com/Commands.html
  # NOTE:
  # 1. Don't use '-L' or '-LIBPATH' in c_link_args or cpp_link_args, you have to use
  #    '/LIBPATH'. Otherwise meson will not insert /LIBPATH just after '/link' and
  #    throw out and error so that can't find third party
  meson setup $BUILD_DIR_M                                                                           \
    --buildtype=release                                                                              \
    --prefix="$PREFIX_M"                                                                             \
    --mandir="$PREFIX_M/share/man"                                                                   \
    --cmake-prefix-path="$PREFIX_PATH_M"                                                             \
    -DPERL="${PERL_PREFIX//\//\\}"'\bin\perl.exe'                                                    \
    -Dllvm=disabled                                                                                  \
    -Dc_args="$OPTIONS $DEFINES $INCLUDES"                                                           \
    -Dc_link_args="$MESON_LDFLAGS"                                                                   \
    -Dcpp_args="-EHsc $OPTIONS $DEFINES $INCLUDES"                                                   \
    -Dcpp_link_args="$MESON_LDFLAGS"                                                                 \
    -Dc_winlibs="Advapi32.lib,Ole32.lib,Shell32.lib,User32.lib"                                      \
    -Dcpp_winlibs="Advapi32.lib,Ole32.lib,Shell32.lib,User32.lib" > >(build_log) 2>&1 || print_error
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
