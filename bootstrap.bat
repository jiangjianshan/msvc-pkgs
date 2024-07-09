@echo off

setlocal enabledelayedexpansion

:: Fix error C2226: syntax error: unexpected type 'llvm::sys::UnicodeCharRange'
powershell -command "Set-WinSystemLocale -SystemLocale en-US"

:: https://docs.python.org/3/using/windows.html#removing-the-max-path-limitation
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t reg_DWORD /d 1

set OLDPATH=%PATH%
set PATH=C:\cygwin64\bin;%PATH%
echo [%~nx0] Checking wget whether has been installed
call :check_wget || goto :end
echo [%~nx0] Checking VC Build Tools whether has been installed
call :check_vcbuildtools vs_buildTools || goto :end
echo [%~nx0] Checking CUDA and CUDNN whether has been installed
call :check_cuda || goto :end
echo [%~nx0] Checking Intel OneAPI whether has been installed
call :check_oneapi || goto :end
echo [%~nx0] Checking Python whether has been installed
call :check_python || goto :end
echo [%~nx0] Checking meson whether has been installed
call :check_meson || goto :end
echo [%~nx0] Checking Git whether has been installed
call :check_git || goto :end
echo [%~nx0] Checking CMake whether has been installed
call :check_cmake || goto :end
echo [%~nx0] Checking Ninja whether has been installed
call :check_ninja || goto :end
echo [%~nx0] Checking Cygwin whether has been installed
call :check_cygwin || goto :end
goto :end

::==============================================================================
:: Check wget whether has been installed. If not, install it automatically
::==============================================================================
:check_wget
where wget >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] wget is missing, you can download the newest version from https://eternallybored.org/misc/wget
  goto :end
)
exit /b 0

::==============================================================================
:: Check Visual C++ Build Tools whether has been installed. If not, install it
:: automatically
::==============================================================================
:check_vcbuildtools
set vsinstall=
if "%VSINSTALLDIR%" neq "" (
  set "vsinstall=%VSINSTALLDIR%"
) else (
  if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" goto :install_vcbuildtools
  for /f "delims=" %%r in ('^""%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -nologo -latest -products "*" -all -property installationPath^"') do set vsinstall=%%r
)
if exist "%vsinstall%\VC\Auxiliary\Build\vcvarsall.bat" exit /b 0
:install_vcbuildtools
  cd /d %~dp0
  :: Download the Build Tools bootstrapper
  if "%1"=="vs_community" set vsinstaller=vs_community.exe
  if "%1"=="vs_buildTools" set vsinstaller=vs_buildTools.exe
  if not exist "!vsinstaller!" curl -SL -o !vsinstaller! https://aka.ms/vs/17/release/!vsinstaller! || goto :end
  :: https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
  :: https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
  :: https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
  if "%1"=="vs_community" (
    !vsinstaller!                                                                         ^
      --includeRecommended                                                                ^
      --wait                                                                              ^
      --passive                                                                           ^
      --norestart                                                                                  ^
      --removeOos true                                                                    ^
      --downloadThenInstall	                                                              ^
      --addProductLang En-us                                                              ^
      --add Microsoft.VisualStudio.Workload.NativeDesktop                                 ^
      --add Microsoft.Net.Component.4.8.1.TargetingPack                                   ^
      --add Microsoft.VisualStudio.Component.Windows10SDK.20348                           ^
      --add Microsoft.VisualStudio.Component.VC.ATL                                       ^
      --add Microsoft.VisualStudio.Component.VC.ATLMFC                                    ^
      --add Microsoft.VisualStudio.Component.VC.ASAN                                      ^
      --remove Component.Microsoft.VisualStudio.LiveShare.2022                            ^
      --remove Microsoft.VisualStudio.ComponentGroup.WebToolsExtensions                   ^
      --remove Microsoft.VisualStudio.Component.Debugger.JustInTime                       ^
      --remove Microsoft.VisualStudio.Component.IntelliCode                               ^
      --remove Microsoft.VisualStudio.Component.NuGet                                     ^
      --remove Microsoft.VisualStudio.Component.JavaScript.TypeScript                     ^
      --remove Microsoft.VisualStudio.Component.Roslyn.LanguageServices                   ^
      --remove Microsoft.VisualStudio.Component.TypeScript.TSServer                       ^
      --remove Component.VisualStudio.GitHub.Copilot                                      ^
      --remove Microsoft.VisualStudio.Component.VC.DiagnosticTools                        ^
      --remove Microsoft.VisualStudio.Component.SecurityIssueAnalysis                     ^
      --remove Microsoft.VisualStudio.Component.Windows11Sdk.WindowsPerformanceToolkit    ^
      --remove Microsoft.VisualStudio.Component.CppBuildInsights                          ^
      --remove Microsoft.VisualStudio.Component.VC.TestAdapterForBoostTest                ^
      --remove Microsoft.VisualStudio.Component.VC.TestAdapterForGoogleTest               ^
      --remove Microsoft.VisualStudio.Component.Vcpkg                                     ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22621                        ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22000                        ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22621                        ^
      --remove Microsoft.VisualStudio.Component.Windows10SDK.18362                        ^
      --remove Microsoft.VisualStudio.Component.Windows10SDK.19041                        ^
      --remove Microsoft.VisualStudio.Component.VC.CMake.Project	                        ^
      --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
  ) else (
    !vsinstaller!                                                                         ^
      --includeRecommended                                                                ^
      --wait                                                                              ^
      --passive                                                                           ^
      --norestart		                                                                       ^
      --removeOos true                                                                    ^
      --downloadThenInstall	                                                              ^
      --addProductLang En-us                                                              ^
      --add Microsoft.VisualStudio.Workload.VCTools                                       ^
      --add Microsoft.Net.Component.4.8.1.TargetingPack	                                  ^
      --add Microsoft.VisualStudio.Component.Windows10SDK.20348	                          ^
      --add Microsoft.VisualStudio.Component.VC.ATL	                                      ^
      --add Microsoft.VisualStudio.Component.VC.ATLMFC                                    ^
      --add Microsoft.VisualStudio.Component.VC.ASAN                                      ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22621                        ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22000                        ^
      --remove Microsoft.VisualStudio.Component.Windows11SDK.22621                        ^
      --remove Microsoft.VisualStudio.Component.Windows10SDK.18362                        ^
      --remove Microsoft.VisualStudio.Component.Windows10SDK.19041                        ^
      --remove Microsoft.VisualStudio.Component.VC.CMake.Project	                        ^
      --remove Microsoft.VisualStudio.Component.TestTools.BuildTools
  )
  :: cleanup
  del /q !vsinstaller!
)
exit /b 0

::==============================================================================
:: Check CUDA whether has been installed. If not, install it automatically
::==============================================================================
:check_cuda
for /f "usebackq tokens=*" %%i in (`wmic path win32_VideoController get name ^| findstr "NVIDIA"`) do (
  set nv_gpu=%%i
)
if "%nv_gpu%" == "" (
  echo [%~nx0] You don't have NVIDIA GPU on your PC
) else (
  echo [%~nx0] You NVIDIA GPU is !nv_gpu!
  if "%CUDA_PATH%" == "" (
    echo [%~nx0] You don't have CUDA installed
    set CUDA_VERSION=12.5.1_555.85
    for /f "tokens=1-4 delims=." %%a in ("!CUDA_VERSION!") do set cuda_major=%%a
    for /f "tokens=1-4 delims=." %%a in ("!CUDA_VERSION!") do set cuda_major_minor=%%a.%%b
    :: https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
    if not exist "cuda_!CUDA_VERSION!_windows.exe" (
      echo [%~nx0] Downloading CUDA !CUDA_VERSION!, please wait ...
      wget https://developer.download.nvidia.com/compute/cuda/!CUDA_VERSION:_555.85=!/local_installers/cuda_!CUDA_VERSION!_windows.exe
    )
    echo [%~nx0] Installing CUDA !CUDA_VERSION!, please wait ...
    cuda_!CUDA_VERSION!_windows.exe -s cuda_profiler_api_!cuda_major_minor! cudart_!cuda_major_minor! cuobjdump_!cuda_major_minor! cupti_!cuda_major_minor! cuxxfilt_!cuda_major_minor! demo_suite_!cuda_major_minor! nvcc_!cuda_major_minor! nvdisasm_!cuda_major_minor! nvfatbin_!cuda_major_minor! nvjitlink_!cuda_major_minor! nvml_dev_!cuda_major_minor! nvprof_!cuda_major_minor! nvprune_!cuda_major_minor! nvrtc_!cuda_major_minor! nvrtc_dev_!cuda_major_minor! opencl_!cuda_major_minor! visual_profiler_!cuda_major_minor! sanitizer_!cuda_major_minor! thrust_!cuda_major_minor! cublas_!cuda_major_minor! cublas_dev_!cuda_major_minor! cufft_!cuda_major_minor! cufft_dev_!cuda_major_minor! curand_!cuda_major_minor! curand_dev_!cuda_major_minor! cusolver_!cuda_major_minor! cusolver_dev_!cuda_major_minor! cusparse_!cuda_major_minor! cusparse_dev_!cuda_major_minor! npp_!cuda_major_minor! npp_dev_!cuda_major_minor! nvjpeg_!cuda_major_minor! nvjpeg_dev_!cuda_major_minor! occupancy_calculator_!cuda_major_minor!
    del /q cuda_!CUDA_VERSION!_windows.exe
    echo [%~nx0] Done.

    set CUDNN_VERSION=9.2.1.18
    :: https://docs.nvidia.com/deeplearning/cudnn/latest/reference/support-matrix.html#support-matrix
    :: https://docs.nvidia.com/deeplearning/cudnn/latest/installation/windows.html
    if not exist "cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip" (
      echo [%~nx0] Downloading CUDNN !CUDNN_VERSION!, please wait ...
      wget https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip
    )
    powershell Expand-Archive -Path cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip -DestinationPath . > nul || pause
    if not exist "C:\Program Files\NVIDIA\CUDNN\v9.x\bin" mkdir "C:\Program Files\NVIDIA\CUDNN\v9.x\bin"
    if not exist "C:\Program Files\NVIDIA\CUDNN\v9.x\include" mkdir "C:\Program Files\NVIDIA\CUDNN\v9.x\include"
    if not exist "C:\Program Files\NVIDIA\CUDNN\v9.x\lib" mkdir "C:\Program Files\NVIDIA\CUDNN\v9.x\lib"
    pushd cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive
    xcopy /S /F /V bin\cudnn*.dll "C:\Program Files\NVIDIA\CUDNN\v9.x\bin"
    xcopy /S /F /V include\cudnn*.h "C:\Program Files\NVIDIA\CUDNN\v9.x\include"
    xcopy /S /F /V lib\x64\cudnn*.lib "C:\Program Files\NVIDIA\CUDNN\v9.x\lib"
    setx /m PATH "%PATH%;C:\Program Files\NVIDIA\CUDNN\v9.x\bin"
    rmdir /s /q bin
    rmdir /s /q include
    rmdir /s /q lib
    popd
    rmdir /s /q cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive
    del /q cudnn-windows-x86_64-!CUDNN_VERSION!_cuda!cuda_major!-archive.zip
    echo [%~nx0] Done.
  )
)
exit /b 0

::==============================================================================
:: Check Intel OneAPI whether has been installed. If not, install it automatically
::==============================================================================
:check_oneapi
set ONEAPI_ROOT="C:\Program Files (x86)\Intel\oneAPI"
if not exist "!ONEAPI_ROOT!" (
  :: https://www.intel.com/content/www/us/en/developer/articles/tool/oneapi-standalone-components.html
  if not exist "w_dpcpp-cpp-compiler_p_2024.2.0.491_offline.exe" (
    echo [%~nx0] Downloading Intel oneAPI DPC++/C++ Compiler
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7991e201-ca0f-4689-bdb6-1ed73a8246fd/w_dpcpp-cpp-compiler_p_2024.2.0.491_offline.exe
  )
  echo [%~nx0] Installing Intel oneAPI DPC++/C++ Compiler
  w_dpcpp-cpp-compiler_p_2024.2.0.491_offline.exe -a --silent --eula accept
  REM
  if not exist "w_oneDPL_p_2022.6.0.558_offline.exe" (
    echo [%~nx0] Downloading Intel oneAPI DPC++ Library
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/214e2200-1f4a-476b-81d7-8ffa2b5861c6/w_oneDPL_p_2022.6.0.558_offline.exe
  )
  echo [%~nx0] Installing Intel oneAPI DPC++ Library
  w_oneDPL_p_2022.6.0.558_offline.exe -a --silent --eula accept
  REM
  if not exist "w_fortran-compiler_p_2024.2.0.424_offline.exe" (
    echo [%~nx0] Downloading Intel Fortran Compiler Classic and Intel Fortran Compiler
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7feb5647-59dd-420d-8753-345d31e177dc/w_fortran-compiler_p_2024.2.0.424_offline.exe
  )
  echo [%~nx0] Installing Intel Fortran Compiler Classic and Intel Fortran Compiler
  w_fortran-compiler_p_2024.2.0.424_offline.exe -a --silent --eula accept
  REM
  if not exist "w_ipp_oneapi_p_2021.12.0.557_offline.exe" (
    echo [%~nx0] Downloading Intel Integrated Performance Primitives
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/2eb0644a-cc28-484f-891c-84dbdb1e3deb/w_ipp_oneapi_p_2021.12.0.557_offline.exe
  )
  echo [%~nx0] Installing Intel Integrated Performance Primitives
  w_ipp_oneapi_p_2021.12.0.557_offline.exe -a --silent --eula accept
  REM
  if not exist "w_ippcp_oneapi_p_2021.12.0.470_offline.exe" (
    echo [%~nx0] Downloading Intel Integrated Performance Primitives Cryptography
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/a16d94b7-2437-480e-82b9-c76c8d165772/w_ippcp_oneapi_p_2021.12.0.470_offline.exe
  )
  echo [%~nx0] Installing Intel Integrated Performance Primitives Cryptography
  w_ippcp_oneapi_p_2021.12.0.470_offline.exe -a --silent --eula accept
  REM
  if not exist "w_onemkl_p_2024.2.0.662_offline.exe" (
    echo [%~nx0] Downloading Intel MKL Library
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7816a8cf-2378-4d49-bfa6-6013a3d7be6a/w_onemkl_p_2024.2.0.662_offline.exe
  )
  echo [%~nx0] Installing Intel MKL Library
  w_onemkl_p_2024.2.0.662_offline.exe -a --silent --eula accept
  REM
  if not exist "w_mpi_oneapi_p_2021.13.0.717_offline.exe" (
    echo [%~nx0] Downloading Intel MPI Library
    wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/e20e3226-9264-41a0-bc18-6026d297e10d/w_mpi_oneapi_p_2021.13.0.717_offline.exe
  )
  echo [%~nx0] Installing Intel MPI Library
  w_mpi_oneapi_p_2021.13.0.717_offline.exe -a --silent --eula accept
  REM
  del /s /q *.exe
)
exit /b 0


::==============================================================================
:: Check ninja whether has been installed. If not, install it automatically
::==============================================================================
:check_ninja
where ninja >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] ninja is missing, you can download the newest version from https://github.com/ninja-build/ninja
  goto :end
)
exit /b 0


::==============================================================================
:: Check python whether has been installed, If not, install it automatically
::==============================================================================
:check_python
where python >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install python 3, you can download the newest installer from https://www.python.org/downloads/
  goto :end
)
exit /b 0

::==============================================================================
:: check cmake whether has been installed
::==============================================================================
:check_cmake
where cmake >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install cmake, you can download the newest installer from https://cmake.org/download/
  goto :end
)
exit /b 0

::==============================================================================
:: check git whether has been installed
::==============================================================================
:check_git
where git >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Please install git, you can download the newest installer from https://www.git-scm.com/download/win
  goto :end
)
exit /b 0


::==============================================================================
:: install cygwin if it is not exist
::==============================================================================
:check_cygwin
setlocal
set cygwin_url="https://www.cygwin.com/setup-x86_64.exe"
set cygwin_prefix="C:\cygwin64"
if not exist "!cygwin_prefix!" (
  if exist setup-x86_64.exe (
    echo [%~nx0] Delete the old version of setup-x86_64.exe
    del /s /q setup-x86_64.exe
  )
  echo [%~nx0] Download a new version of setup-x86_64.exe
  wget --no-check-certificate !cygwin_url! -O setup-x86_64.exe || goto :end
  echo [%~nx0] Installing cygwin
  :: see https://cygwin.com/faq/faq.html#faq.setup.cli
  setup-x86_64.exe -a x86_64 -d -g -r -n -N -q -O -s https://mirrors.tuna.tsinghua.edu.cn/cygwin/ -R !cygwin_prefix! -P "autoconf,automake,libtool,make,pkg-config,patch,flex,bison,dos2unix,gperf,zsh"
  echo [%~nx0] Removing all caches
  for /d /r %%i in (*mirrors.tuna.tsinghua.edu.cn*) do @rmdir /s /q "%%i"
  echo [%~nx0] Speeding up cygwin
  bash config-cygwin.sh
  sed -i 's/bash/zsh/g' "C:/cygwin64/Cygwin.bat"
  del /s /q setup-x86_64.exe
  echo [%~nx0] Done
  call ohmyzsh.bat
)
exit /b 0


::==============================================================================
:: check meson whether has been installed
::==============================================================================
:check_meson
where meson >nul 2>&1
if "%errorlevel%" neq "0" (
  echo [%~nx0] Installing meson
  python -m pip install --upgrade meson || goto :end
  echo [%~nx0] Done
)
exit /b 0

:end
set PATH=%OLDPATH%
set vsinstall=
set vswhere=
set vcvarsall=
