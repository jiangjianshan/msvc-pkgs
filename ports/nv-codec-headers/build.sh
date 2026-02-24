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
BUILD_DIR=$SRC_DIR
C_OPTS='-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8'
C_DEFS='-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX'

clean_stage()
{
  echo "Cleaning $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && rm -rfv *.obj *.exe *.lib *.dll *.exp *.pdb
}

build_stage()
{
  echo "Building $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make -j$(nproc) PREFIX=$PREFIX || exit 1
}

install_stage()
{
  echo "Installing $PKG_NAME $PKG_VER"
  cd "$BUILD_DIR" && make install PREFIX=$PREFIX || exit 1
  sed -E "s|^(prefix=).*|\1${PREFIX}|" -i "${PREFIX}/lib/pkgconfig/ffnvcodec.pc"
}

build_stage
install_stage
clean_stage
