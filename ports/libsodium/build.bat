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
set BUILD_DIR=%SRC_DIR%\builds\msvc\vs2022
set C_OPTS=-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm -utf-8
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
rmdir /s /q bin
rmdir /s /q obj
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
set PLAT=x64
if "%ARCH%"=="x86" set PLAT=Win32
cd "%BUILD_DIR%" && msbuild libsodium.sln /p:Configuration=DynRelease          ^
  /p:Platform=%PLAT% /p:PlatformToolset=v143 /p:UseEnv=true                    ^
  /p:SkipUWP=true
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if not exist "%PREFIX%\include" mkdir "%PREFIX%\include"
if not exist "%PREFIX%\lib" mkdir "%PREFIX%\lib"
for /f "delims=" %%i in ('dir /b /s "%SRC_DIR%\bin\*.dll"') do (
    xcopy /Y /F /I %%i "%PREFIX%\bin"
)
for /f "delims=" %%i in ('dir /b /s "%SRC_DIR%\bin\*.lib"') do (
    xcopy /Y /F /I %%i "%PREFIX%\lib"
)
xcopy /Y /F /I "%SRC_DIR%\src\libsodium\include\sodium.h" "%PREFIX%\include"
if not exist "%PREFIX%\include\sodium" mkdir "%PREFIX%\include\sodium"
xcopy /Y /F /I "%SRC_DIR%\src\libsodium\include\sodium\*.h" "%PREFIX%\include\sodium"
exit /b 0

:end
