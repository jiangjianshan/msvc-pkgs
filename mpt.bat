@echo off
rem
rem MSVC-PKG Main Entry Batch Script - Windows Environment Configuration and Bootstrap
rem
rem Provides the primary execution environment for the MSVC-PKG package management system.
rem Configures Windows environment variables, validates dependencies, and initializes
rem the Python-based package management toolchain with proper system configuration.

setlocal enabledelayedexpansion

rem Configure MSYS2 compatibility environment variables
rem These settings ensure proper symbolic link handling and path inheritance
set LOGONSERVER=\\LOCALHOST

rem Native Windows symbolic link support
set MSYS=winsymlinks:nativestrict

rem Inherit system PATH in MSYS2 environment
set MSYS2_PATH_TYPE=inherit

rem NOTE:
rem MSYSTEM environment variable intentionally not set
rem This prevents interference with MSYS2 toolchain detection while maintaining
rem compatibility with packages that inspect MSYSTEM for build configuration
rem Some packages (e.g., gobject-introspection) use MSYSTEM to determine compiler
rem behavior, but all build.bat scripts execute outside MSYS2 environment
rem set MSYSTEM=MINGW64

rem Configure Python runtime environment
rem Prevent .pyc file generation to avoid clutter and potential version conflicts
set PYTHONDONTWRITEBYTECODE=1

rem Ensure UTF-8 encoding for all Python input/output operations
set PYTHONIOENCODING=utf-8

rem Set internationalization and localization variables
rem Uniform UTF-8 locale settings for consistent text processing
set LANG=en_US.UTF-8
set LC_ALL=en_US.UTF-8
set LC_CTYPE=en_US.UTF-8

rem Disable GObject introspection cache to prevent stale binding issues
set GI_SCANNER_DISABLE_CACHE=1

set GOPATH=%~dp0go
set GOBIN=%GOPATH%\bin

rem  https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg query HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled >nul 2>&1 || (
  reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1
)

set missing=
rem Verify Python installation exists and is accessible
python --version >nul 2>&1 || (
    echo Python not found. You can download it from 'https://www.python.org/downloads/'
    set missing=1
)

rem Verify Git installation exists and is accessible
git --version >nul 2>&1 || (
    echo Git not found. You can download it from 'https://git-scm.com/install/windows/'
    set missing=1
)

if "%missing%" equ "1" (
    pause
    exit 0
)

rem Get root location of Git for windows
set GIT_ROOT=
for /f "delims=" %%a in ('where git') do for %%b in ("%%~dpa..") do set "GIT_ROOT=%%~fb"

rem Verify meson installation exists and is accessible
meson --version >nul 2>&1 || (
    python -m pip install meson
)

rem Check for required Python packages using importlib
rem Installs missing dependencies automatically if not present
python -c "import importlib.util as i;exit(any(not i.find_spec(m) for m in('pygments','yaml','rich','requests')))" >nul 2>&1 || (
    echo Installing required Python packages...
    python -m pip install --upgrade pip Pygments PyYAML rich requests
)

for %%i in ("%~dp0.") do set "ROOT_DIR=%%~fi"
set "ORIG_PATH=%PATH%"
rem IMPORTANT: PATH Order for Git Bash Environment
rem
rem When using Git for Windows, the order of Git-related paths in the %PATH% environment variable
rem is critical for proper system detection in configure scripts.
rem
rem The path "C:\Program Files\Git\bin" must appear BEFORE "C:\Program Files\Git\usr\bin" in %PATH%.
rem
rem Reason:
rem - "C:\Program Files\Git\bin\bash.exe" is the main Git Bash entry point that properly sets
rem   the %MSYSTEM% environment variable to "MINGW64"
rem - "C:\Program Files\Git\usr\bin\bash.exe" is a plain bash shell that does NOT set %MSYSTEM%
rem
rem If the paths are in the wrong order, bash scripts executed via bash.exe will have:
rem - %MSYSTEM% unset or incorrectly set
rem - config.guess and config.sub will fail to detect the correct build type
rem - Result: "checking build system type... x86_64-pc-msys" (incorrect)
rem - Instead of: "checking build system type... x86_64-pc-mingw64" (correct)
rem
rem This path ordering ensures that configure scripts and build tools correctly identify
rem the system as MinGW64 rather than MSYS, which is essential for proper library linking
rem and compilation flags.
rem
set "PATH=%PATH%;%ROOT_DIR%\bin;%GIT_ROOT%\bin;%GIT_ROOT%\usr\bin"
python main.py %*
set "PATH=%ORIG_PATH%"
