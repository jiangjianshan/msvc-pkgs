#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='perl zlib'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=xapian-core
PKG_VER=1.4.25
PKG_URL=https://oligarchy.co.uk/xapian/$PKG_VER/$PKG_NAME-$PKG_VER.tar.xz
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

  # XXX: libtool don't have options can set the naming style of static and 
  #      shared library. Here is only a workaround.
  echo [$0] Patching ltmain.sh in top level
  sed                                                                                                         \
    -e "s|old_library='\$old_library'|old_library='lib\$old_library'|g"                                       \
    -e 's|oldlibs="$output_objdir/$libname.$libext|oldlibs="$output_objdir/lib$libname.$libext|g'             \
    -e 's|oldlibs " $output_objdir/$libname.$libext|oldlibs " $output_objdir/lib$libname.$libext|g'           \
    ltmain.sh > ltmain.sh-t
  mv ltmain.sh-t ltmain.sh

  echo [$0] Patching configure in top level
  sed                                                                                                         \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"                        \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                              \
    configure > configure-t
  mv configure-t configure
  chmod +x configure

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
  DEFINES="-DWIN32 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE"
  # Fix the issue of 'Warning: linker path does not have real file for library -lz' on Windows 10
  export lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}
  # NOTE:
  # 1. Don't add CPP="$FWD/wrapper/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... ''
  $SRC_DIR/configure --build=$BUILD_TRIPLET                          \
    --host=$HOST_TRIPLET                                             \
    --prefix="$PREFIX"                                               \
    --libdir="$PREFIX/lib"                                           \
    --mandir="$PREFIX/share/man"                                     \
    --enable-static                                                  \
    --enable-shared                                                  \
    --enable-werror                                                  \
    AR="$FWD/wrapper/ar-lib lib -nologo"                             \
    AS="$FWD/wrapper/as-ml ml64 -nologo"                             \
    CC="$FWD/wrapper/compile cl -nologo"                             \
    CC_FOR_BUILD="$FWD/wrapper/compile cl -nologo"                   \
    CFLAGS="$OPTIONS"                                                \
    CPPFLAGS="$DEFINES $INCLUDES"                                    \
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
    gt_cv_locale_zh_CN=none > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  # Fix error C2017: illegal escape sequence
  pushd include/xapian
  sed                                                                \
    -e 's|\\\\|\\|g'                                                 \
    version.h > version.h-t
  mv version.h-t version.h
  popd
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
