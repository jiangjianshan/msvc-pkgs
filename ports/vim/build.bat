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
set BUILD_DIR=%SRC_DIR%\src
rem NOTE: Don't add '-utf-8' to build this library, otherwise will have the issue "'/utf-8' and '/source-charset:utf-8' command-line options are incompatible"
set C_OPTS=-diagnostics:column -experimental:c11atomics -fp:precise -MD -nologo -openmp:llvm
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
nmake -f Make_mvc.mak clean
for /f "delims=" %%i in ('dir /b /a:d ^| findstr "Obj"') do rmdir /s /q %%i
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%"
for /f "tokens=2" %%v in ('python --version 2^>nul') do (
  set "python_version=%%v"
)
for /f "delims=" %%p in ('where python 2^>nul') do (
  set "python_exe=%%p"
  set "python_root=!python_exe:\python.exe=!"
)
for /f "tokens=1,2 delims=." %%a in ("%python_version%") do (
  set "python_short_version=%%a%%b"
)
for /f "tokens=1,2 delims=." %%a in ("%LUA_VER%") do (
  set lua_short_version=%%a%%b
)
for /f "tokens=1,2 delims=." %%a in ("%PERL_VER%") do (
  set perl_short_version=%%a%%b
)
for /f "tokens=1,2 delims=." %%a in ("%RUBY_VER%") do (
  set "ruby_short_version=%%a%%b"
  set "ruby_long_version=%%a.%%b.0"
)
for /f "tokens=1,2 delims=." %%a in ("%TCL_VER%") do (
  set "tcl_short_version=%%a%%b"
  set "tcl_long_version=%%a.%%b"
)
set "GETTEXT_PATH=!GETTEXT_PREFIX!\bin"

echo "Building GUI version of %PKG_NAME% %PKG_VER%"
nmake -f Make_mvc.mak GUI=yes OLE=yes DIRECTX=yes FEATURES=HUGE IME=yes        ^
  MBYTE=yes ICONV=yes GETTEXT=yes DEBUG=no TERMINAL=yes USE_MSVCRT=yes         ^
  PYTHON3=%python_root% DYNAMIC_PYTHON3=yes PYTHON3_VER=%python_short_version% ^
  LUA=%LUA_PREFIX% DYNAMIC_LUA=yes LUA_VER=%lua_short_version%                 ^
  PERL=%PERL_PREFIX% DYNAMIC_PERL=yes PERL_VER=%perl_short_version%            ^
  RUBY=%RUBY_PREFIX% DYNAMIC_RUBY=yes RUBY_VER=%ruby_short_version%            ^
  RUBY_API_VER_LONG=%ruby_long_version% DYNAMIC_SODIUM=yes                     ^
  TCL=%TCL_PREFIX% DYNAMIC_TCL=yes TCL_VER=%tcl_short_version%                 ^
  TCL_VER_LONG=%tcl_long_version% SODIUM=%SODIUM_PREFIX% || exit 1

echo "Building Console version of %PKG_NAME% %PKG_VER%"
nmake -f Make_mvc.mak GUI=no OLE=no DIRECTX=no FEATURES=HUGE IME=yes           ^
  MBYTE=yes ICONV=yes GETTEXT=yes DEBUG=no TERMINAL=yes USE_MSVCRT=yes         ^
  PYTHON3=%python_root% DYNAMIC_PYTHON3=yes PYTHON3_VER=%python_short_version% ^
  LUA=%LUA_PREFIX% DYNAMIC_LUA=yes LUA_VER=%lua_short_version%                 ^
  PERL=%PERL_PREFIX% DYNAMIC_PERL=yes PERL_VER=%perl_short_version%            ^
  RUBY=%RUBY_PREFIX% DYNAMIC_RUBY=yes RUBY_VER=%ruby_short_version%            ^
  RUBY_API_VER_LONG=%ruby_long_version% DYNAMIC_SODIUM=yes                     ^
  TCL=%TCL_PREFIX% DYNAMIC_TCL=yes TCL_VER=%tcl_short_version%                 ^
  TCL_VER_LONG=%tcl_long_version% SODIUM=%SODIUM_PREFIX% || exit 1
echo "Building translations of %PKG_NAME% %PKG_VER%
pushd po
nmake -f Make_mvc.mak VIMRUNTIME=..\..\runtime install-all
popd
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%SRC_DIR%"
pushd src
for /f "tokens=1,2,3" %%a in ('findstr /r /c:"^#define VIM_VERSION_MAJOR" "version.h"') do (
    if "%%a"=="#define" if "%%b"=="VIM_VERSION_MAJOR" (
        set "vim_major=%%c"
    )
)
for /f "tokens=1,2,3" %%a in ('findstr /r /c:"^#define VIM_VERSION_MINOR" "version.h"') do (
    if "%%a"=="#define" if "%%b"=="VIM_VERSION_MINOR" (
        set "vim_minor=%%c"
    )
)
popd
set "VIM_RUNTIME_DIR=%PREFIX%\vim%vim_major%%vim_minor%"
if not exist "%VIM_RUNTIME_DIR%" mkdir "%VIM_RUNTIME_DIR%"
echo 1. Create a Vim "runtime" subdirectory named "vim91"
xcopy /Y /E /V /I /H /R /Q runtime\* %VIM_RUNTIME_DIR%
echo 2. Copy the new binaries into the "vim91" directory
copy /Y src\*.exe "%VIM_RUNTIME_DIR%"
copy /Y src\tee\tee.exe "%VIM_RUNTIME_DIR%"
copy /Y src\xxd\xxd.exe "%VIM_RUNTIME_DIR%"
echo 3. To install the "Edit with Vim" popup menu, you need both 32-bit and 64-bit
echo    versions of gvimext.dll.  They should be copied to "vim91\GvimExt32" and
echo    "vim91\GvimExt64" respectively.
powershell -Command "Get-Process | Where-Object { $_.Modules.FileName -like '*gvimext.dll' } | ForEach-Object { Write-Host 'Found process: PID='$_.Id' name='$_.ProcessName; Stop-Process -Id $_.Id -Force }" 2>nul
pushd "%BUILD_DIR%"
start /wait cmd /c ""%vcvarsall%" x86 && cd GvimExt && nmake -f Make_mvc.mak CPU=i386 WINVER=0x0A00 clean all"
popd
if not exist "%VIM_RUNTIME_DIR%\GvimExt32" mkdir "%VIM_RUNTIME_DIR%\GvimExt32"
copy /Y src\GvimExt\gvimext.dll %VIM_RUNTIME_DIR%\GvimExt32 || exit 1
pushd "%BUILD_DIR%"
start /wait cmd /c ""%vcvarsall%" x64 && cd GvimExt && nmake -f Make_mvc.mak CPU=AMD64 WINVER=0x0A00 clean all"
popd
if not exist "%VIM_RUNTIME_DIR%\GvimExt64" mkdir "%VIM_RUNTIME_DIR%\GvimExt64"
copy /Y src\GvimExt\gvimext.dll "%VIM_RUNTIME_DIR%\GvimExt64" || exit 1
echo 4. Copy gettext and iconv DLLs into the "vim91" directory
copy /Y "%LIBICONV_PREFIX%\bin\iconv-2.dll" "%VIM_RUNTIME_DIR%\GvimExt64" || exit 1
copy /Y "%GETTEXT_PREFIX%\bin\intl-8.dll" "%VIM_RUNTIME_DIR%\GvimExt64" || exit 1
if not exist "%LIBICONV_PREFIX:x86_64=i686%\bin\iconv-2.dll" (
  echo "Missing x86 variant of iconv-2.dll"
  echo "You should run 'mpt --arch x86 gettext' before 'mpt vim'"
  exit 1
)
if not exist "%GETTEXT_PREFIX:x86_64=i686%\bin\intl-8.dll" (
  echo "Missing x86 variant of iconv-2.dll"
  echo "You should run 'mpt --arch x86 gettext' before 'mpt vim'"
  exit 1
)
copy /Y "%LIBICONV_PREFIX:x86_64=i686%\bin\iconv-2.dll" %VIM_RUNTIME_DIR%\GvimExt32 || exit 1
copy /Y "%GETTEXT_PREFIX:x86_64=i686%\bin\intl-8.dll" %VIM_RUNTIME_DIR%\GvimExt32 || exit 1
copy /Y "%LIBICONV_PREFIX%\bin\iconv-2.dll" %VIM_RUNTIME_DIR% || exit 1
copy /Y "%GETTEXT_PREFIX%\bin\intl-8.dll" %VIM_RUNTIME_DIR% || exit 1
echo If vim has been installed before and here just rebuild it, The following step to install
echo Vim can be ignored:
echo ---------------
echo "cd" to your Vim installation subdirectory "vim%vim_major_minor%" and run the
echo "install.exe" program.  It will ask you a number of questions about
echo how you would like to have your Vim setup.  Among these are:
echo - You can tell it to write a "_vimrc" file with your preferences in the
echo   parent directory.
echo - It can also install an "Edit with Vim" entry in the Windows Explorer
echo   popup menu.
echo - You can have it create batch files, so that you can run Vim from the
echo   console or in a shell.  You can select one of the directories in your
echo   PATH or add the directory to PATH using the Windows Control Panel.
echo - Create entries for Vim on the desktop and in the Start menu.
exit /b 0

:end
