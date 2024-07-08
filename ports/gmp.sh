#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='yasm'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=gmp
PKG_VER=6.3.0
PKG_URL=https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz
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

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR

  # NOTE: 
  # 1. gmp only can build static or shared library but not both together, so that don't
  #    patch ltmain.sh to change the name of library
  # XXX: libtool don't have options can set the naming style of static and 
  #      shared library. Here is only a workaround.
  # echo [$0] Patching ltmain.sh at the top-level
  # sed                                                                                                \
  #   -e "s|old_library='\$old_library'|old_library='lib\$old_library'|g"                              \
  #   -e 's|oldlibs="$output_objdir/$libname.$libext|oldlibs="$output_objdir/lib$libname.$libext|g'    \
  #   -e 's|oldlibs " $output_objdir/$libname.$libext|oldlibs " $output_objdir/lib$libname.$libext|g'  \
  #   ltmain.sh > ltmain.sh-t
  # mv ltmain.sh-t ltmain.sh
  echo [$0] Patching configure in the top-level
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    -e 's|.dll.lib|.lib|g'                                                                           \
    -e 's|#include "$srcdir\/gmp-h.in"|#include "gmp-h.in"|g'                                        \
    -e 's|#include "$srcdir\/gmp-impl.h"|#include "gmp-impl.h"|g'                                    \
    -e 's|#include \\"$srcdir\/gmp-h.in\\"|#include \\"gmp-h.in\\"|g'                                \
    configure > configure-t
  mv configure-t configure
  chmod +x configure

  pushd doc
  echo [$0] Patching gmp.info-1 in doc
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    gmp.info-1 > gmp.info-1-t
  mv gmp.info-1-t gmp.info-1
  echo [$0] Patching gmp.texi in doc
  sed                                                                                                \
    -e 's|.dll.def|.def|g'                                                                           \
    gmp.texi > gmp.texi-t
  mv gmp.texi-t gmp.texi
  popd

  popd
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
  # 1. Don't put CYGWIN before tar command, otherwise some .tar.* will not be 
  #    extracted successful
  export CYGWIN="winsymlinks:nativestrict"
  # NOTE:
  # 1. Don't add CPP="$FWD/wrapper/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... ''
  # 2. Don't set CFLAGS for gmp, because yasm also use this flags. If 
  #    there are some flags are unknown for yasm, the configuration will
  #    fail
  # TODO: It will have LNK2005 issue when using option '--disable-static
  #       --enable-shared'
  $SRC_DIR/configure --build=$BUILD_TRIPLET                          \
    --host=$HOST_TRIPLET                                             \
    --prefix="$PREFIX"                                               \
    --libdir="$PREFIX/lib"                                           \
    --mandir="$PREFIX/share/man"                                     \
    --enable-cxx=yes                                                 \
    AR="$FWD/wrapper/ar-lib lib -nologo"                             \
    AS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                      \
    CC="$FWD/wrapper/compile cl -nologo"                             \
    CC_FOR_BUILD="$FWD/wrapper/compile cl -nologo"                   \
    CCAS="yasm -Xvc -f $YASM_OBJ_FMT -rraw -pgas"                    \
    CPPFLAGS="$DEFINES $INCLUDES -I$SRC_DIR -I$BUILD_DIR"            \
    CXX="$FWD/wrapper/compile cl -nologo"                            \
    CXXFLAGS="-EHsc $OPTIONS"                                        \
    DLLTOOL='link.exe -verbose -dll'                                 \
    LD="link -nologo"                                                \
    LDFLAGS="$AUTOCONF_LDFLAGS"                                      \
    NM="dumpbin -nologo -symbols"                                    \
    RANLIB=":"                                                       \
    RC="$FWD/wrapper/windres-rc rc -nologo"                          \
    STRIP=":"                                                        \
    WINDRES="$FWD/wrapper/windres-rc rc -nologo"                     \
    ac_cv_func_vsnprintf=yes                                         \
    ac_cv_header_sstream=yes                                         \
    ac_cv_type_std__locale=yes                                       \
    gmp_cv_asm_w32=".word"                                           \
    gt_cv_locale_zh_CN=none > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
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
