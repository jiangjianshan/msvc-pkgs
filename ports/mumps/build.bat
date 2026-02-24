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

call "%ROOT_DIR%\compiler.bat" %ARCH% oneapi
set BUILD_DIR=%SRC_DIR%\build%ARCH:x=%
set C_OPTS=-diagnostics:column -MD -nologo -utf-8 -W0 -Xclang -O2 -fopenmp -fms-extensions -fms-hotpatch -fms-compatibility -fms-compatibility-version=%MSC_VER%
set C_DEFS=-DWIN32 -D_WIN32_WINNT=_WIN32_WINNT_WIN10 -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE -D_CRT_NONSTDC_NO_WARNINGS -D_USE_MATH_DEFINES
set F_OPTS=-MD -nologo -Qdiag-disable:10448 -Qopenmp -Qopenmp-simd -fpp

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
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i CMakeLists.txt
pushd cmake
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i install.cmake
popd
pushd parmetis\cmake
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i install.cmake
popd
pushd parmetis\METIS\cmake
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i install.cmake
popd
pushd parmetis\METIS\GKlib\cmake
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i install.cmake
popd
pushd scalapack
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i CMakeLists.txt
popd
pushd scalapack\cmake
sed -e "s|DESTINATION cmake|DESTINATION lib/cmake/${PROJECT_NAME}|g" -i install.cmake
popd
exit /b 0

:configure_stage
echo "Configuring %PKG_NAME% %PKG_VER%"
mkdir "%BUILD_DIR%" && cd "%BUILD_DIR%"
cmake -G "Ninja"                                                               ^
  -DBUILD_SINGLE=ON                                                            ^
  -DBUILD_DOUBLE=ON                                                            ^
  -DBUILD_COMPLEX=ON                                                           ^
  -DBUILD_COMPLEX16=ON                                                         ^
  -DCMAKE_BUILD_TYPE=Release                                                   ^
  -DCMAKE_C_COMPILER=clang-cl                                                  ^
  -DCMAKE_C_FLAGS="%C_OPTS% %C_DEFS%"                                          ^
  -DCMAKE_Fortran_COMPILER=ifx                                                 ^
  -DCMAKE_Fortran_FLAGS="%F_OPTS%"                                             ^
  -DCMAKE_INSTALL_PREFIX="%PREFIX%"                                            ^
  -DFLEX_ROOT="%WINFLEXBISON_PREFIX:\=/%"                                      ^
  -DBISON_ROOT="%WINFLEXBISON_PREFIX:\=/%"                                     ^
  -DLAPACK_ROOT="%LAPACK_PREFIX:\=/%"                                          ^
  -DSCALAPACK_ROOT="%SCALAPACK_PREFIX:\=/%"                                    ^
  -DMUMPS_openmp=ON                                                            ^
  -DMUMPS_parallel=ON                                                          ^
  -DMUMPS_ptscotch=ON                                                          ^
  -DMUMPS_scalapack=ON                                                         ^
  -DMUMPS_scotch=ON                                                            ^
  -DMUMPS_BUILD_TESTING=OFF                                                    ^
  -Dgemmt=ON                                                                   ^
  .. || exit 1
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
