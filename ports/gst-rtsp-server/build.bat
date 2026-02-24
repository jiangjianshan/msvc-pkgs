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
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX -D_INTL_CXX_NO_CLOBBER_STD_NAMESPACE

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

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%"
cd "%SRC_DIR%"
rem NOTE:
rem 1. Define GI_EXTRA_BASE_DLL_DIRS to fix following issue:
rem    ImportError: DLL load failed while importing _giscanner: The specified module could not be found
set "GI_EXTRA_BASE_DLL_DIRS=%LIBICONV_PREFIX:\=/%/bin;%LIBICONV_PREFIX:\=/%/lib;%GETTEXT_PREFIX:\=/%/bin;%GETTEXT_PREFIX:\=/%/lib;%PCRE2_PREFIX:\=/%/bin;%LIBFFI_PREFIX:\=/%/bin;%ZLIB_PREFIX:\=/%/bin"
set "GI_GIR_PATH=%GLIB_PREFIX:\=/%/share/gir-1.0"
meson setup "%BUILD_DIR%"                                                      ^
  --buildtype=release                                                          ^
  --prefix="%PREFIX%"                                                          ^
  --mandir="%PREFIX%\share\man"                                                ^
  -Dc_std=c17                                                                  ^
  -Dc_args="%C_OPTS% %C_DEFS%"                                                 ^
  -Dcpp_std=c++17                                                              ^
  -Dcpp_args="-EHsc %C_OPTS% %C_DEFS%"                                         ^
  -Dc_winlibs="Advapi32.lib,User32.lib,iconv.lib"                              ^
  -Dcpp_winlibs="Advapi32.lib,User32.lib,iconv.lib"                            ^
  -Dexamples=disabled                                                          ^
  -Dtests=disabled || exit 1
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja -j%NUMBER_OF_PROCESSORS% || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && ninja install || exit 1
exit /b 0

:end
