#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='libiconv'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=gettext
PKG_VER=0.22.5
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

patch_package()
{
  echo [$0] Patching package $PKG_NAME $PKG_VER
  pushd $SRC_DIR

  # XXX: libtool don't have options can set the naming style of static and 
  #      shared library. Here is only a workaround.
  echo [$0] Patching ltmain.sh in build-aux
  pushd build-aux
  sed                                                                                                \
    -e "s|old_library='\$old_library'|old_library='lib\$old_library'|g"                              \
    -e 's|oldlibs="$output_objdir/$libname.$libext|oldlibs="$output_objdir/lib$libname.$libext|g'    \
    -e 's|oldlibs " $output_objdir/$libname.$libext|oldlibs " $output_objdir/lib$libname.$libext|g'  \
    ltmain.sh > ltmain.sh-t
  mv ltmain.sh-t ltmain.sh
  popd

  echo [$0] Patching ltmain.sh in gettext-tools/examples/hello-c++-kde/admin
  pushd gettext-tools/examples/hello-c++-kde/admin
  sed                                                                                                \
    -e "s|old_library='\$old_library'|old_library='lib\$old_library'|g"                              \
    -e 's|oldlibs="$output_objdir/$libname.$libext|oldlibs="$output_objdir/lib$libname.$libext|g'    \
    -e 's|oldlibs " $output_objdir/$libname.$libext|oldlibs " $output_objdir/lib$libname.$libext|g'  \
    ltmain.sh > ltmain.sh-t
  mv ltmain.sh-t ltmain.sh
  popd

  echo [$0] Patching ltmain.sh in libtextstyle/build-aux
  pushd libtextstyle/build-aux
  sed                                                                                                \
    -e "s|old_library='\$old_library'|old_library='lib\$old_library'|g"                              \
    -e 's|oldlibs="$output_objdir/$libname.$libext|oldlibs="$output_objdir/lib$libname.$libext|g'    \
    -e 's|oldlibs " $output_objdir/$libname.$libext|oldlibs " $output_objdir/lib$libname.$libext|g'  \
    ltmain.sh > ltmain.sh-t
  mv ltmain.sh-t ltmain.sh
  popd

  echo [$0] Patching configure in top level
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure

  echo [$0] Patching configure in gettext-runtime
  pushd gettext-runtime
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
  popd

  echo [$0] Patching configure in gettext-runtime/intl
  pushd gettext-runtime/intl
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
  popd

  echo [$0] Patching configure in gettext-runtime/libasprintf
  pushd gettext-runtime/libasprintf
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
  popd

  echo [$0] Patching configure in gettext-tools
  pushd gettext-tools
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
  popd

  echo [$0] Patching configure in gettext-tools/examples
  pushd gettext-tools/examples
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
  popd

  echo [$0] Patching configure in libtextstyle
  pushd libtextstyle
  sed                                                                                                \
    -e "s|library_names_spec='\$libname.dll.lib'|library_names_spec='\$libname.lib'|g"               \
    -e 's|$tool_output_objdir$libname.dll.lib|$tool_output_objdir$libname.lib|g'                     \
    configure > configure-t
  mv configure-t configure
  chmod +x configure
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
  # 2. with below options, ncurses which version is 6.2 need to add 
  #    '--with-shared' configuation option if not use '--disable-curses'
  # 3. If want to generate libintl-8.dll, please don't use '--disable-nls'
  #    option
  $SRC_DIR/configure --build=$BUILD_TRIPLET                                    \
    --host=$HOST_TRIPLET                                                       \
    --prefix="$PREFIX"                                                         \
    --libdir="$PREFIX/lib"                                                     \
    --mandir="$PREFIX/share/man"                                               \
    --enable-static                                                            \
    --enable-shared                                                            \
    --enable-relocatable                                                       \
    --enable-threads=windows                                                   \
    --disable-java                                                             \
    --disable-csharp                                                           \
    --disable-openmp                                                           \
    --disable-curses                                                           \
    --with-included-libxml                                                     \
    --with-included-libunistring                                               \
    --with-included-gettext                                                    \
    --with-included-libintl                                                    \
    --with-included-glib                                                       \
    --with-included-libcroco                                                   \
    --without-emacs                                                            \
    --without-cvs                                                              \
    --without-git                                                              \
    --without-bzip2                                                            \
    --without-xz                                                               \
    AR="$FWD/wrapper/ar-lib lib -nologo"                                       \
    CC="$FWD/wrapper/compile cl -nologo"                                       \
    CFLAGS="$OPTIONS"                                                          \
    CPPFLAGS="$DEFINES $INCLUDES"                                              \
    CXX="$FWD/wrapper/compile cl -nologo"                                      \
    CXXFLAGS="-EHsc $OPTIONS"                                                  \
    DLLTOOL='link.exe -verbose -dll'                                           \
    LD="link -nologo"                                                          \
    LDFLAGS="$AUTOCONF_LDFLAGS"                                                \
    NM="dumpbin -nologo -symbols"                                              \
    RANLIB=":"                                                                 \
    RC="$FWD/wrapper/windres-rc rc -nologo"                                    \
    STRIP=":"                                                                  \
    WINDRES="$FWD/wrapper/windres-rc rc -nologo"                               \
    gt_cv_locale_zh_CN=none > >(build_log) 2>&1 || print_error

  # Patch Makefiles
  echo [$0] Patching Makefile in gettext-runtime/gnulib-lib
  pushd gettext-runtime/gnulib-lib
  sed                                                                          \
    -e 's|libgrt.a|libgrt.lib|g'                                               \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in gettext-runtime/intl
  pushd gettext-runtime/intl
  sed                                                                          \
    -e 's|libintl.a|libintl.lib|g'                                             \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd


  echo [$0] Patching Makefile in gettext-runtime/src
  pushd gettext-runtime/src
  sed                                                                          \
    -e 's|libgrt.a|libgrt.lib|g'                                               \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in gettext-runtime/intl/gnulib-lib
  pushd gettext-runtime/intl/gnulib-lib
  sed                                                                          \
    -e 's|libintl.a|libintl.lib|g'                                             \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in gettext-tools/src
  pushd gettext-tools/src
  sed                                                                          \
    -e 's|libgrep.a|libgrep.lib|g'                                             \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in gettext-tools/libgrep
  pushd gettext-tools/libgrep
  sed                                                                          \
    -e 's|libgrep.a|libgrep.lib|g'                                             \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in gettext-tools/gnulib-tests
  pushd gettext-tools/gnulib-tests
  sed                                                                          \
    -e 's|libtests.a|libtests.lib|g'                                           \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd

  echo [$0] Patching Makefile in libtextstyle/tests
  pushd libtextstyle/tests
  sed                                                                          \
    -e 's|libtests.a|libtests.lib|g'                                           \
    Makefile > Makefile-t
  mv Makefile-t Makefile
  popd
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
  # Fix libtool: warning: '../intl/libintl.la' has not been installed
  cp -v gettext-runtime/intl/.libs/libintl.lai $PREFIX/lib/libintl.la
  cd $PREFIX/bin
  # Fix 0xc0000022 issue
  chmod 755 intl-8.dll
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
