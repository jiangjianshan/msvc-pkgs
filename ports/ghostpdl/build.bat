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
set BUILD_DIR=%SRC_DIR%\build
rem NOTE:
rem 1. Don't use '-openmp:llvm' or '-openmp:experimental' for ghostpdl, because openmp version of msvc is too low
set C_OPTS=-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -utf-8
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set CL=-MP %C_OPTS% %C_DEFS%

call :clean_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
if exist "bin" rmdir /s /q "bin"
if "%ARCH%"=="x64" (
  if exist "windows\obj64" rmdir /s /q "windows\obj64"
  if exist "obj64" rmdir /s /q "obj64"
) else (
  if exist "windows\obj32" rmdir /s /q "windows\obj32"
  if exist "obj32" rmdir /s /q "obj32"
)
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%" && msbuild windows/GhostPDL.sln /p:Configuration=Release        ^
  /p:Platform=%ARCH% /p:PlatformToolset=v143 /p:UseEnv=true                    ^
  /p:SkipUWP=true || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include\ghostscript" mkdir "%PREFIX%\include\ghostscript"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
if not exist "%PREFIX%\share\Resource" mkdir "%PREFIX%\share\Resource"
copy /Y bin\*.exe "%PREFIX%\bin"
copy /Y bin\*.dll "%PREFIX%\bin"
copy /Y bin\*.lib "%PREFIX%\lib"
xcopy /Y /S "%SRC_DIR%\Resource" "%PREFIX%\share\Resource"
set _SUFFIX=64
if "%ARCH%"=="x86" set _SUFFIX=32
if not exist "%PREFIX%\lib\gpcl6.lib" (
  mklink "%PREFIX%\lib\gpcl6.lib" "%PREFIX%\lib\gpcl6dll%_SUFFIX%.lib"
)
if not exist "%PREFIX%\lib\gpdf.lib" (
  mklink "%PREFIX%\lib\gpdf.lib" "%PREFIX%\lib\gpdfdll%_SUFFIX%.lib"
)
if not exist "%PREFIX%\lib\gpdl.lib" (
  mklink "%PREFIX%\lib\gpdl.lib" "%PREFIX%\lib\gpdldll%_SUFFIX%.lib"
)
if not exist "%PREFIX%\lib\gs.lib" (
  mklink "%PREFIX%\lib\gs.lib" "%PREFIX%\lib\gsdll%_SUFFIX%.lib"
)
if not exist "%PREFIX%\lib\gxps.lib" (
  mklink "%PREFIX%\lib\gxps.lib" "%PREFIX%\lib\gxpsdll%_SUFFIX%.lib"
)
copy /Y "%SRC_DIR%\psi\iapi.h" "%PREFIX%\include\ghostscript\iapi.h"
copy /Y "%SRC_DIR%\psi\ierrors.h" "%PREFIX%\include\ghostscript\ierrors.h"
copy /Y "%SRC_DIR%\base\gserrors.h" "%PREFIX%\include\ghostscript\gserrors.h"
copy /Y "%SRC_DIR%\devices\gdevdsp.h" "%PREFIX%\include\ghostscript\gdevdsp.h"
copy /Y "%SRC_DIR%\pcl\pl\plapi.h" "%PREFIX%\include\ghostscript\plapi.h"
exit /b 0

:end
