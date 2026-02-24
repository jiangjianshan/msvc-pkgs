@echo off
setlocal enabledelayedexpansion
rem
rem Build script for the current library.
rem
rem This script is designed to be invoked by `mpt.bat` using the command `mpt <library_name>`.
rem It relies on specific environment variables set by the `mpt` process to function correctly.
rem
rem Environment Variables Provided by `mpt` (in addition to system variables):
rem   ARCH          - Target architecture to build for. Valid values: `x64` or `x86`.
rem   PKG_NAME      - Name of the current library being built.
rem   PKG_VER       - Version of the current library being built.
rem   ROOT_DIR      - Root directory of the msvc-pkg project.
rem   SRC_DIR       - Source code directory of the current library.
rem   PREFIX        - **Actual installation path prefix** for the *current* library after successful build.
rem   PREFIX_PATH   - List of installation directory prefixes for third-party dependencies.
rem
rem   For each direct dependency `{Dependency}` of the current library:
rem     {Dependency}_PREFIX - Actual installation path of the dependency `{Dependency}`.
rem     {Dependency}_SRC - Source code directory of the dependency `{Dependency}`.
rem     {Dependency}_VER - Version of the dependency `{Dependency}`.

call "%ROOT_DIR%\compiler.bat" %ARCH%
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8
set C_DEFS=-DWIN32 -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -D_SILENCE_NONFLOATING_COMPLEX_DEPRECATION_WARNING

call :prepare_stage
call :clean_stage
call :configure_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
exit /b 0

:prepare_stage
echo "Preparing %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
rem Fix system_libs of llvm-config has wrongly link to zstd.dll.lib but not zstd.lib
pushd llvm\lib\Support
sed                                                                                                                  ^
  -e "s|\${zstd_target} PROPERTY LOCATION_\${build_type}|${zstd_target} PROPERTY IMPORTED_IMPLIB_${build_type}|g"    ^
  -e "s|\${zstd_target} PROPERTY LOCATION|${zstd_target} PROPERTY IMPORTED_IMPLIB|g"                                 ^
  -i CMakeLists.txt
popd
rem Fix SyntaxWarning invalid escape sequence if use python 3.12
pushd llvm\utils
sed -e "s/re.match(\"/re.match(r\"/g" -i extract_symbols.py
popd
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                                                   ^
  -DCMAKE_BUILD_TYPE=Release                                                                       ^
  -DCMAKE_C_COMPILER=cl                                                                            ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                                              ^
  -DCMAKE_CXX_COMPILER=cl                                                                          ^
  -DCMAKE_CXX_FLAGS="%C_OPTS% %C_DEFS%"                                                            ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                                                ^
  -DCMAKE_POLICY_DEFAULT_CMP0074=OLD                                                               ^
  -DCMAKE_POLICY_DEFAULT_CMP0116=OLD                                                               ^
  -DCLANG_DEFAULT_CXX_STDLIB=libc++                                                                ^
  -DCLANG_DEFAULT_LINKER=lld                                                                       ^
  -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy                                                             ^
  -DCLANG_DEFAULT_OPENMP_RUNTIME=libomp                                                            ^
  -DCLANG_DEFAULT_RTLIB=compiler-rt                                                                ^
  -DCLANG_ENABLE_OBJC_REWRITER=OFF                                                                 ^
  -DLIBCXX_USE_COMPILER_RT=ON                                                                      ^
  -DLLVM_BUILD_DOCS=OFF                                                                            ^
  -DLLVM_BUILD_EXAMPLES=OFF                                                                        ^
  -DLLVM_BUILD_LLVM_C_DYLIB=ON                                                                     ^
  -DLLVM_BUILD_LLVM_DYLIB=ON                                                                       ^
  -DLLVM_BUILD_TESTS=OFF                                                                           ^
  -DLLVM_ENABLE_PROJECTS="clang;lld"                                                               ^
  -DLLVM_ENABLE_RTTI=ON                                                                            ^
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;openmp"                                               ^
  -DLLVM_INCLUDE_DOCS=OFF                                                                          ^
  -DLLVM_INCLUDE_EXAMPLES=OFF                                                                      ^
  -DLLVM_INCLUDE_TESTS=OFF                                                                         ^
  -DLLVM_INSTALL_UTILS=ON                                                                          ^
  -DLLVM_LINK_LLVM_DYLIB=ON                                                                        ^
  -DLLVM_LIT_ARGS=-v                                                                               ^
  -DLLVM_OPTIMIZED_TABLEGEN=ON                                                                     ^
  -DLLVM_TARGETS_TO_BUILD=all                                                                      ^
  -DCLANG_ENABLE_BOOTSTRAP=ON                                                                      ^
  -DCLANG_BOOTSTRAP_PASSTHROUGH="CMAKE_BUILD_TYPE;CMAKE_INSTALL_LIBDIR;CMAKE_POLICY_DEFAULT_CMP0074;CMAKE_POLICY_DEFAULT_CMP0116;CLANG_DEFAULT_CXX_STDLIB;CLANG_DEFAULT_LINKER;CLANG_DEFAULT_OBJCOPY;CLANG_DEFAULT_OPENMP_RUNTIME;CLANG_DEFAULT_RTLIB;CLANG_ENABLE_OBJC_REWRITER;LIBCXX_USE_COMPILER_RT;LLVM_BUILD_DOCS;LLVM_BUILD_EXAMPLES;LLVM_BUILD_LLVM_C_DYLIB;LLVM_BUILD_LLVM_DYLIB;LLVM_BUILD_TESTS;LLVM_ENABLE_RTTI;LLVM_INCLUDE_DOCS;LLVM_INCLUDE_EXAMPLES;LLVM_INCLUDE_TESTS;LLVM_INSTALL_UTILS;LLVM_LINK_LLVM_DYLIB;LLVM_LIT_ARGS;LLVM_OPTIMIZED_TABLEGEN;LLVM_TARGETS_TO_BUILD" ^
  -DBOOTSTRAP_LLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;lld;polly;mlir;flang"             ^
  -DBOOTSTRAP_LLVM_ENABLE_RUNTIMES="compiler-rt;openmp;libcxx;libclc;flang-rt"                     ^
  -DBOOTSTRAP_LLVM_ENABLE_LLD=ON                                                                   ^
  ../llvm || exit 1
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja stage2 || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja stage2-install || exit 1
exit /b 0

:end
