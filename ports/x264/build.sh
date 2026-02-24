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
C_OPTS='-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

clean_stage()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$SRC_DIR" && [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
}

prepare_stage()
{
  echo "Preparing $PKG_NAME $PKG_VER"
  cd "$SRC_DIR"
  sed                                                                            \
    -e 's|IMPLIBNAME=libx264\.dll\.lib|IMPLIBNAME=x264.lib|g'                    \
    -e 's|SONAME=libx264-$API\.dll|SONAME=x264-$API.dll|g'                       \
    -i configure
  chmod +x configure
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
  CC=cl ../configure --host="$HOST_TRIPLET"                                    \
    --prefix="$PREFIX"                                                         \
    --bindir="$PREFIX/bin"                                                     \
    --includedir="$PREFIX/include"                                             \
    --libdir="$PREFIX/lib"                                                     \
    --enable-static                                                            \
    --enable-shared                                                            \
    --extra-cflags="$C_OPTS $C_DEFS"
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
build_stage
install_stage
clean_stage
