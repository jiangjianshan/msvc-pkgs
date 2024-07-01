#!/bin/bash
#
# Set build environment of Visutal C++ Build Tools
#
if [ "$ARCH" == "x86" -o "$ARCH" == "x64" ]; then
  if [ "$HOST_ARCH" == "x86" ]; then
    WindowsSdkDir=`reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v "InstallationFolder" | grep "InstallationFolder" | cut -f13- -d" " | tr -d '\r'`
    WindowsSDKVersion=`reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v "ProductVersion" | grep "ProductVersion" | cut -f13- -d" " | tr -d '\r'`
  else
    WindowsSdkDir=`reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" /v "InstallationFolder" | grep "InstallationFolder" | cut -f13- -d" " | tr -d '\r'`
    WindowsSDKVersion=`reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" /v "ProductVersion" | grep "ProductVersion" | cut -f13- -d" " | tr -d '\r'`
  fi
  WindowsSDKVersion=$WindowsSDKVersion'.0'
  # for creating 32-bit or 64-bit binaries: through the following bash commands:
  # Set environment variables for using MSVC 14,
  # for creating native 32-bit or 64-bit Windows executables.

  # Windows tools
  PATH=`cygpath -u 'C:\Program Files (x86)\Windows Kits\10'`/bin/${WindowsSDKVersion}/${ARCH}:"$PATH"

  # Windows C library headers and libraries.
  WindowsCrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\ucrt'
  WindowsCrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\ucrt\'
  INCLUDE="${WindowsCrtIncludeDir};$INCLUDE"
  LIB="${WindowsCrtLibDir}${ARCH};$LIB"

  # Windows API headers and libraries.
  WindowsSdkIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\'
  WindowsSdkLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\um\'
  INCLUDE="${WindowsSdkIncludeDir}um;${WindowsSdkIncludeDir}shared;$INCLUDE"
  LIB="${WindowsSdkLibDir}${ARCH};$LIB"

  # Windows WinRT library headers and libraries.
  WindowsWinrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\winrt'
  WindowsWinrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\winrt\'
  INCLUDE="${WindowsWinrtIncludeDir};$INCLUDE"
  LIB="${WindowsWinrtLibDir}${ARCH};$LIB"

  # Windows CppWinRT library headers and libraries.
  WindowsCppWinrtIncludeDir='C:\Program Files (x86)\Windows Kits\10\Include\'"${WindowsSDKVersion}"'\cppwinrt'
  WindowsCppWinrtLibDir='C:\Program Files (x86)\Windows Kits\10\Lib\'"${WindowsSDKVersion}"'\cppwinrt\'
  INCLUDE="${WindowsCppWinrtIncludeDir};$INCLUDE"
  LIB="${WindowsCppWinrtLibDir}${ARCH};$LIB"

  # Visual C++ tools, headers and libraries.
  VSWHERE=`cygpath -u 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'`
  VSINSTALLDIR=`"$VSWHERE" -nologo -latest -products "*" -all -property installationPath | tr -d '\r'`
  VSINSTALLVERSION=`"$VSWHERE" -nologo -latest -products "*" -all -property installationVersion | tr -d '\r'`
  VCToolsVersion=`head -1 "${VSINSTALLDIR}"'\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt' | tr -d '\r'`
  VCINSTALLDIR="${VSINSTALLDIR}"'\VC\Tools\MSVC\'"${VCToolsVersion}"
  # build some project need VCTOOLSINSTALLDIR, e.g. perl
  VCTOOLSINSTALLDIR=${VCINSTALLDIR}
  PATH=`cygpath -u "${VCINSTALLDIR}"`/bin/Host${HOST_ARCH}/${ARCH}:"$PATH"
  INCLUDE="${VCINSTALLDIR}"'\include;'"${VCINSTALLDIR}"'\atlmfc\include;'"${INCLUDE}"
  LIB="${VCINSTALLDIR}"'\lib\'"${ARCH}"';'"${VCINSTALLDIR}"'\atlmfc\lib\'"${ARCH}"';'"${LIB}"

  # Universal CRT
  PATH=`cygpath -u "${WindowsSdkDir}"`Redist/ucrt/DLLs/$ARCH:"$PATH"

  # MSBuild
  if [ "$HOST_ARCH" == "x86" ]; then
    PATH=`cygpath -u "${VSINSTALLDIR}"`/MSBuild/Current/Bin:"$PATH"
  else
    PATH=`cygpath -u "${VSINSTALLDIR}"`/MSBuild/Current/Bin/amd64:"$PATH"
  fi
  # location of Microsoft.Cpp.Default.props
  PATH=$(dirname "$(find "$(cygpath -u "${VSINSTALLDIR}"'/MSBuild/Microsoft/VC')" -name "Microsoft.Cpp.Default.props")"):"$PATH"
fi

export INCLUDE LIB PATH VCINSTALLDIR WindowsSdkDir WindowsSDKVersion VSINSTALLDIR VCTOOLSINSTALLDIR VSINSTALLVERSION VCToolsVersion
