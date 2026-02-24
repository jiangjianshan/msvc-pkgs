#!/bin/bash
#
# Build script for the current library.
#
# This script is designed to be invoked by `mpt.bat` using the command `mpt <library_name>`.
# It relies on specific environment variables set by the `mpt` process to function correctly.
#
# Environment Variables Provided by `mpt` (in addition to system variables):
#   ARCH          - Target architecture to build for. Valid values: `x64` or `x86`.
#   PKG_NAME      - Name of the current library being built.
#   PKG_VER       - Version of the current library being built.
#   ROOT_DIR      - Root directory of the msvc-pkg project.
#   SRC_DIR       - Source code directory of the current library.
#   PREFIX        - **Actual installation path prefix** for the *current* library after successful build.
#   PREFIX_PATH   - List of installation directory prefixes for third-party dependencies.
#
#   For each direct dependency `{Dependency}` of the current library:
#     {Dependency}_PREFIX - Actual installation path of the dependency `{Dependency}`.
#     {Dependency}_SRC - Source code directory of the dependency `{Dependency}`.
#     {Dependency}_VER - Version of the dependency `{Dependency}`.
. $ROOT_DIR/compiler.sh $ARCH
BUILD_DIR=$SRC_DIR/build${ARCH//x/}
C_OPTS='-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8 -Zc:__cplusplus'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -D_TIMEVAL_DEFINED'

clean_stage()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

prepare_stage()
{
  echo "Preparing $PKG_NAME $PKG_VER"
  cd "$SRC_DIR"
  export GNULIB_SRCDIR=$ROOT_DIR/buildtrees/sources/gnulib
  GNULIB_TOOL=$GNULIB_SRCDIR/gnulib-tool
  GNULIB_MODULES='
    vasprintf
    ftruncate
    getrusage
    gettimeofday
    strsignal
    sys_resource-h
    sys_time-h
    sys_utsname-h
    unistd-h
    uname
  '
  if [ ! -f "config/m4/gnulib-cache.m4" ] || [ configure.ac -nt "config/m4/gnulib-cache.m4" ]; then
    $GNULIB_TOOL --lib=libgrt --source-base=src --m4-base=config/m4 --without-tests \
      --no-vc-files --makefile-name=Makefile.gnulib --libtool \
      --import $GNULIB_MODULES
    WANT_AUTOCONF='2.69' WANT_AUTOMAKE='1.16' autoreconf -ifv
    rm -rfv autom4te.cache
    find . -name "*~" -type f -print -exec rm -rfv {} \;
  fi
}

configure_stage()
{
  echo "Configuring $PKG_NAME $PKG_VER"
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
  if [[ "$ARCH" == "x86" ]]; then
    HOST_TRIPLET=i686-w64-mingw32
  elif [[ "$ARCH" == "x64" ]]; then
    HOST_TRIPLET=x86_64-w64-mingw32
  fi
  # NOTE:
  # 1. Don't use CPP="$ROOT_DIR/wrappers/compile cl -nologo -EP" here,
  #    it will cause checking absolute name of standard files is empty.
  #    e.g. checking absolute name of <fcntl.h> ... '', but we can use
  #    CPP="$ROOT_DIR/wrappers/compile cl -nologo -E"
  # 2. Don't use 'compile cl -nologo' but 'compile cl'. Because configure
  #    on some libraries will detect whether is msvc compiler according to
  #    '*cl | cl.exe'
  # 3. Taken care of the logic of func_resolve_sysroot() and func_replace_sysroot()
  #    in ltmain.sh, otherwise may have '-L=*' in the filed of 'dependency_libs' in
  #    *.la. So don't set --with-sysroot if --libdir has been set
  # TODO:
  # 1. MPI compiler can't be detected if enable option '--enable-mpi'
  AR="$ROOT_DIR/wrappers/ar-lib lib -nologo"                                   \
  CC="$ROOT_DIR/wrappers/compile cl"                                           \
  CFLAGS="$C_OPTS"                                                             \
  CPP="$ROOT_DIR/wrappers/compile cl -E"                                       \
  CPPFLAGS="$C_DEFS"                                                           \
  CXX="$ROOT_DIR/wrappers/compile cl"                                          \
  CXXFLAGS="-EHsc $C_OPTS"                                                     \
  CXXCPP="$ROOT_DIR/wrappers/compile cl -E"                                    \
  DLLTOOL="link -verbose -dll"                                                 \
  LD="link -nologo"                                                            \
  NM="dumpbin -nologo -symbols"                                                \
  PKG_CONFIG="/usr/bin/pkg-config"                                             \
  RANLIB=":"                                                                   \
  RC="$ROOT_DIR/wrappers/windres-rc rc -nologo"                                \
  STRIP=":"                                                                    \
  WINDRES="$ROOT_DIR/wrappers/windres-rc rc -nologo"                           \
  ../configure --host="$HOST_TRIPLET"                                          \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --datarootdir="$PREFIX/share"                                              \
    --enable-static                                                            \
    --enable-shared                                                            \
    --enable-threads=windows                                                   \
    gl_cv_func_free_preserves_errno=yes                                        \
    lt_cv_deplibs_check_method=${lt_cv_deplibs_check_method='pass_all'}        \
    gt_cv_locale_zh_CN=none || exit 1
}

patch_stage()
{
  cd "$BUILD_DIR"
  # FIXME:
  # To solve following issue
  # libtool: warning: undefined symbols not allowed in x86_64-w64-mingw32
  # shared libraries; building static only
  if [ -f "libtool" ]; then
    sed -e "s/\(allow_undefined=\)yes/\1no/" -i libtool
    chmod +x libtool
  fi
}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make -j$(nproc) || exit 1
}

install_stage()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make install || exit 1
}

prepare_stage
clean_stage
configure_stage
patch_stage
build_stage
install_stage
clean_stage
