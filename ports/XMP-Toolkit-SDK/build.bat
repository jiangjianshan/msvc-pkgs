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
set C_OPTS=-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX
set CL=-MP %C_OPTS% %C_DEFS%

call :clean_stage
call :configure_stage
call :build_stage
call :install_stage
call :clean_stage
goto :end

:clean_stage
echo "Cleaning %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
if exist "%SRC_DIR%\libraries\windows_x64\Release" (
  rmdir /s /q "%SRC_DIR%\libraries\windows_x64\Release"
)
if exist "%SRC_DIR%\XMPFiles\build\vc17" (
  rmdir /s /q "%SRC_DIR%\XMPFiles\build\vc17"
)
if exist "%SRC_DIR%\XMPCore\build\vc17" (
  rmdir /s /q "%SRC_DIR%\XMPCore\build\vc17"
)
if exist "%SRC_DIR%\build\vc17" (
  rmdir /s /q "%SRC_DIR%\build\vc17"
)
echo 1| GenerateXMPToolkitSDK_win.bat
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
echo 2| GenerateXMPToolkitSDK_win.bat
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%\vc17\dynamic\windows_x64"
msbuild XMPToolkitSDK64.sln /p:Configuration=Release /p:Platform=%ARCH%        ^
  /p:PlatformToolset=v143 /p:UseEnv=true /p:SkipUWP=true || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
cd "%SRC_DIR%\public" && (
  xcopy /Y /F /I include "%PREFIX%\include"
  cd libraries\windows_x64\Release
  xcopy /Y /F /I *.dll "%PREFIX%\bin"
  xcopy /Y /F /I *.lib "%PREFIX%\lib"
)
exit /b 0

:end
