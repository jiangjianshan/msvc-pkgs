#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='gnulib libiconv gettext'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=sed
PKG_VER=4.9
PKG_URL=https://ftp.gnu.org/pub/gnu/$PKG_NAME/$PKG_NAME-$PKG_VER.tar.gz
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
      make distclean
      popd
    fi
  fi
}

autoreconf_package()
{
  pushd $SRC_DIR
  echo [$0] Generating configure at the top-level
  aclocal -I m4                                                      \
    && autoconf                                                      \
    && touch ChangeLog                                               \
    && automake --add-missing --copy                                 \
    && rm -rf autom4te.cache configure~                              \
    || print_error
  popd
}

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR
  patch -Np1 -i $PATCHES_DIR/001-sed-4.9-fix-missing-getopt.diff
  $GNULIB_SRCDIR/gnulib-tool --copy-file m4/sys_cdefs_h.m4
  $GNULIB_SRCDIR/gnulib-tool --copy-file m4/getopt.m4
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt_int.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt1.c
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt.c
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt.in.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt-pfx-core.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt-pfx-ext.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt-cdefs.in.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt-core.h
  $GNULIB_SRCDIR/gnulib-tool --copy-file lib/getopt-ext.h
  popd
  autoreconf_package
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
  # 1. Don't add CPP="$FWD/wrapper/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... ''
  $SRC_DIR/configure --build=$BUILD_TRIPLET                          \
    --host=$HOST_TRIPLET                                             \
    --prefix="$PREFIX"                                               \
    --libdir="$PREFIX/lib"                                           \
    --mandir="$PREFIX/share/man"                                     \
    --enable-threads=windows                                         \
    --without-selinux                                                \
    AR="$FWD/wrapper/ar-lib lib -nologo"                             \
    CC="$FWD/wrapper/compile cl -nologo"                             \
    CFLAGS="$OPTIONS"                                                \
    CPPFLAGS="$DEFINES $INCLUDES"                                    \
    CXX="$FWD/wrapper/compile cl -nologo"                            \
    CXXFLAGS="-EHsc $OPTIONS"                                        \
    LD="link -nologo"                                                \
    LDFLAGS="$AUTOCONF_LDFLAGS"                                      \
    LIBS="-lbcrypt"                                                  \
    NM="dumpbin -nologo -symbols"                                    \
    RANLIB=":"                                                       \
    RC="$FWD/wrapper/windres-rc rc -nologo"                          \
    STRIP=":"                                                        \
    WINDRES="$FWD/wrapper/windres-rc rc -nologo"                     \
    gt_cv_locale_zh_CN=none > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  # fix .a to .lib on Makefile
  sed -i 's|libsed.a|libsed.lib|g' Makefile
  sed -i 's|libver.a|libver.lib|g' Makefile
  sed -i 's|libsed.a|libsed.lib|g' gnulib-tests/Makefile
  sed -i 's|libtests.a|libtests.lib|g' gnulib-tests/Makefile
  make -j$(nproc) > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  make install > >(build_log) 2>&1 || print_error
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
