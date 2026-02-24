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
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES -DNOMINMAX

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
set with_cuda=
if exist "%CUDA_PATH%" set with_cuda=--cuda --hip-platform NVIDIA
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%" || exit 1
python ../buildbot/configure.py --cmake-gen "Ninja"                            ^
  -n %NUMBER_OF_PROCESSORS%                                                    ^
  -o "%BUILD_DIR%"                                                             ^
  -t Release                                                                   ^
  --native_cpu %with_cuda%                                                     ^
  --cmake-opt=-DCMAKE_C_COMPILER=cl                                            ^
  --cmake-opt=-DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                              ^
  --cmake-opt=-DCMAKE_CXX_COMPILER=cl                                          ^
  --cmake-opt=-DCMAKE_CXX_FLAGS="%C_OPTS% %C_DEFS%"                            ^
  --cmake-opt=-DCMAKE_POLICY_DEFAULT_CMP0053=OLD                               ^
  --cmake-opt=-DCMAKE_POLICY_DEFAULT_CMP0114=OLD                               ^
  --cmake-opt=-DCMAKE_POLICY_DEFAULT_CMP0116=OLD                               ^
  --cmake-opt=-DCMAKE_POLICY_DEFAULT_CMP0146=OLD                               ^
  --cmake-opt=-DBOOST_MP11_SOURCE_DIR="%BOOST_PREFIX%"                         ^
  --cmake-opt=-DBOOST_UNORDERED_SOURCE_DIR="%BOOST_PREFIX%"                    ^
  --cmake-opt=-DBOOST_ASSERT_SOURCE_DIR="%BOOST_PREFIX%"                       ^
  --cmake-opt=-DBOOST_CONFIG_SOURCE_DIR="%BOOST_PREFIX%"                       ^
  --cmake-opt=-DBOOST_CONTAINER_HASH_SOURCE_DIR="%BOOST_PREFIX%"               ^
  --cmake-opt=-DBOOST_CORE_SOURCE_DIR="%BOOST_PREFIX%"                         ^
  --cmake-opt=-DBOOST_DESCRIBE_SOURCE_DIR="%BOOST_PREFIX%"                     ^
  --cmake-opt=-DBOOST_PREDEF_SOURCE_DIR="%BOOST_PREFIX%"                       ^
  --cmake-opt=-DBOOST_STATIC_ASSERT_SOURCE_DIR="%BOOST_PREFIX%"                ^
  --cmake-opt=-DBOOST_THROW_EXCEPTION_SOURCE_DIR="%BOOST_PREFIX%"              ^
  || exit 1
exit /b 0

:build_stage
echo "Building %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && python ../buildbot/compile.py                              ^
  -j %NUMBER_OF_PROCESSORS% -o "%BUILD_DIR%" || exit 1
exit /b 0

:install_stage
echo "Installing %PKG_NAME% %PKG_VER%"
cd "%BUILD_DIR%" && xcopy /Y /F /S /I "install\*" "%PREFIX%" || exit 1
exit /b 0

:end
