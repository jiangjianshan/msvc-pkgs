#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS='cpp-httplib libffi libxml2 lua perl xz zlib zstd'
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=llvm-project
PKG_VER=18.1.8
PKG_URL=https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-$PKG_VER.tar.gz
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
  pushd $SRC_DIR/llvm/cmake
  patch -Np1 -i $PATCHES_DIR/001-llvm-project-18.1.8-fix-cmake-error-if-can-not-find-zstd-target.diff
  popd
  pushd $SRC_DIR/llvm/utils
  patch -Np0 -i $PATCHES_DIR/002-llvm-project-18.1.8-fix-SyntaxWarning-invalid-escape-sequence-if-use-python-3.12.diff
  popd
}

prepare_package()
{
  clean_build
  clean_log
  create_dirs
  check_depends
  display_info

  local archive=llvmorg-$PKG_VER.tar.gz
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
    mv ${PKG_NAME}-llvmorg-${PKG_VER} ${PKG_NAME}-${PKG_VER}
    patch_package
  fi
  if [ ! -d "$BUILD_DIR" ]; then mkdir -p "$BUILD_DIR"; fi
}

configure_package()
{
  echo [$0] Configuring $PKG_NAME $PKG_VER
  check_triplet
  cd $BUILD_DIR
  OPTIONS='-fp:precise -diagnostics:column -wd4819 -openmp:llvm'
  DEFINES="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING"
  bootstrap_cmake_options='CMAKE_BUILD_TYPE;CMAKE_INSTALL_PREFIX;CMAKE_PREFIX_PATH;CMAKE_POLICY_DEFAULT_CMP0076;CMAKE_POLICY_DEFAULT_CMP0114;CMAKE_POLICY_DEFAULT_CMP0116;CLANG_DEFAULT_CXX_STDLIB;CLANG_DEFAULT_RTLIB;CLANG_INCLUDE_DOCS;LLVM_BUILD_DOCS;LLVM_BUILD_EXAMPLES;LLVM_BUILD_TESTS;LLVM_BUILD_TOOLS;LLVM_BUILD_UTILS;LLVM_BUILD_LLVM_C_DYLIB;LLVM_ENABLE_DOXYGEN;LLVM_ENABLE_OCAMLDOC;LLVM_ENABLE_PLUGINS;LLVM_EXPORT_SYMBOLS_FOR_PLUGINS;LLVM_INCLUDE_DOCS;LLVM_INCLUDE_EXAMPLES;LLVM_INCLUDE_TESTS;LLVM_INCLUDE_TOOLS;LLVM_INCLUDE_UTILS;LLVM_INSTALL_UTILS;LLVM_ENABLE_PROJECTS;LLVM_ENABLE_RUNTIMES;LLVM_ENABLE_RTTI;LLVM_RUNTIME_TARGETS;LLVM_OPTIMIZED_TABLEGEN;LLVM_TARGETS_TO_BUILD;LIBCXX_USE_COMPILER_RT;Python3_EXECUTABLE'
  bootstrap_cmake_cxx_flags='-Xclang -O3 -march=native -fms-extensions -fms-compatibility -fms-compatibility-version=19.40'
  # NOTE:
  # 1. Don't install cygwin's cmake because it will use gcc-like compile
  #    command. To use windows's cmake, here have to use 'cygpath -m' to
  #    convert path to windows path but not cygwin path
  # 2. Don't set cmake generator to 'Unix Makefiles' if use MSYS2 shell
  cmake -G "Ninja"                                                                       \
    -DBOOTSTRAP_CMAKE_CXX_FLAGS="$bootstrap_cmake_cxx_flags $OPTIONS $DEFINES $INCLUDES" \
    -DCMAKE_BUILD_TYPE=Release                                                           \
    -DCMAKE_C_COMPILER=cl                                                                \
    -DCMAKE_CXX_COMPILER=cl                                                              \
    -DCMAKE_CXX_FLAGS="$OPTIONS $DEFINES $INCLUDES"                                      \
    -DCMAKE_INSTALL_PREFIX="$PREFIX_M"                                                   \
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH_M"                                                 \
    -DCMAKE_POLICY_DEFAULT_CMP0076=OLD                                                   \
    -DCMAKE_POLICY_DEFAULT_CMP0114=OLD                                                   \
    -DCMAKE_POLICY_DEFAULT_CMP0116=OLD                                                   \
    -DCLANG_DEFAULT_CXX_STDLIB=libc++                                                    \
    -DCLANG_DEFAULT_RTLIB=compiler-rt                                                    \
    -DCLANG_INCLUDE_DOCS=OFF                                                             \
    -DLLVM_BUILD_DOCS=OFF                                                                \
    -DLLVM_BUILD_EXAMPLES=OFF                                                            \
    -DLLVM_BUILD_TESTS=OFF                                                               \
    -DLLVM_BUILD_TOOLS=ON                                                                \
    -DLLVM_BUILD_UTILS=ON                                                                \
    -DLLVM_BUILD_LLVM_C_DYLIB=ON                                                         \
    -DLLVM_ENABLE_DOXYGEN=OFF                                                            \
    -DLLVM_ENABLE_OCAMLDOC=OFF                                                           \
    -DLLVM_ENABLE_PLUGINS=ON                                                             \
    -DLLVM_EXPORT_SYMBOLS_FOR_PLUGINS=ON                                                 \
    -DLLVM_INCLUDE_DOCS=OFF                                                              \
    -DLLVM_INCLUDE_EXAMPLES=OFF                                                          \
    -DLLVM_INCLUDE_TESTS=OFF                                                             \
    -DLLVM_INCLUDE_TOOLS=ON                                                              \
    -DLLVM_INCLUDE_UTILS=ON                                                              \
    -DLLVM_INSTALL_UTILS=ON                                                              \
    -DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;lld;mlir;flang;pstl;polly"      \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;openmp"                                   \
    -DLLVM_ENABLE_RTTI=ON                                                                \
    -DLLVM_OPTIMIZED_TABLEGEN=ON                                                         \
    -DLLVM_TARGETS_TO_BUILD=X86                                                          \
    -DLIBCXX_USE_COMPILER_RT=ON                                                          \
    -DPython3_EXECUTABLE="$(python -c 'import sys; print(sys.executable)')"              \
    -DCLANG_ENABLE_BOOTSTRAP=ON                                                          \
    -DCLANG_BOOTSTRAP_PASSTHROUGH="$bootstrap_cmake_options"                             \
    $SRC_DIR_M/llvm > >(build_log) 2>&1 || print_error
}

build_package()
{
  echo [$0] Building $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  ninja -j$(nproc) stage2 > >(build_log) 2>&1 || print_error
}

install_package()
{
  echo [$0] Installing $PKG_NAME $PKG_VER
  cd $BUILD_DIR
  ninja -j$(nproc) stage2-install > >(build_log) 2>&1 || print_error
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
