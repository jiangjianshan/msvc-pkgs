#!/bin/bash

usage()
{
  echo "\
  Script for building open source libraries on Windows,

  Usage: [$0] [options]

  Required Options:
  --ports       : The value of ports to be build, the available value is 'all' or
                  the script name without extension can be found in %FWD%\ports.
                  The delimiter is comma or space. 

  Optional Options:
  --help        : Display this help
  --arch        : Build and test x86 or x64 variant
  --prefix      : Install root location of bin, include, lib, share etc. the
               default value is $FWD/$ARCH. Also some special prefix can
               be set in here for some ports, the delimiter is colon combining
               equal for different prefix
  --cflags      : CFLAGS is for flags for the C++ compiler.
               The default rules in make, CFLAGS is only passed when compiling 
               and linking C.
               This customized CFLAGS added to default CFLAGS
  --cxxflags    : CXXFLAGS is for flags for the C++ compiler.
               The default rules in make, CXXFLAGS is only passed when compiling 
               and linking C++.
               This customized CXXFLAGS added to default CXXFLAGS
  --cppflags    : CPPFLAGS is supposed to be for flags for the C PreProcessor. 
               The default rules in make pass CPPFLAGS to just about everything.
               This customized CPPFLAGS will be added to default CPPFLAGS
  --ldflags     : Extra flags to give to compilers when they are supposed to invoke 
               the linker.
               This customized LDFLAGS will be added to defaults LDFLAGS
  --libs        : Library flags or names given to compilers when they are supposed 
               to invoke the linker
               This customized LIBS will be added to defaults LIBS

  Example:
    [$0] --arch x86 --ports libiconv,gettext
    [$0] --arch x64
    [$0] --ports perl --prefix "D:\Perl"
    [$0] --ports libiconv,gettext
    [$0] --ports libiconv gettext"
}

display_info()
{
  echo [$0] Initializing Visual Studio command-line environment...
  echo "Visual C++ Tools Version                               : $VCToolsVersion"
  echo "Visual C++ Install Directory                           : $VCINSTALLDIR"
  echo "Windows SDK Install Directory                          : $WindowsSdkDir"
  echo "Windows SDK version                                    : $WindowsSDKVersion"
  echo "Visual Studio command-line environment initialized for : $ARCH"
  echo [$0] Setting CUDA and CUDNN Toochain environment
  echo "CUDA version                                           : $CUDA_VERSION"
  echo "CUDNN Version                                          : $CUDNN_VERSION"
  echo [$0] Display information
  printf "%-18s: %-80s\n" "DEPENDS" "$DEPENDS"
  printf "%-18s: %-80s\n" "ARCH" "$ARCH"
  printf "%-18s: %-80s\n" "HOST_ARCH" "$HOST_ARCH"
  printf "%-18s: %-80s\n" "FWD" "$FWD"
  printf "%-18s: %-80s\n" "FWD_M" "$FWD_M"
  printf "%-18s: %-80s\n" "FWD_W" "$FWD_W"
  printf "%-18s: %-80s\n" "PREFIX" "$PREFIX"
  printf "%-18s: %-80s\n" "PREFIX_M" "$PREFIX_M"
  printf "%-18s: %-80s\n" "PREFIX_W" "$PREFIX_W"
  printf "%-18s: %-80s\n" "TAGS_DIR" "$TAGS_DIR"
  printf "%-18s: %-80s\n" "TAGS_DIR_M" "$TAGS_DIR_M"
  printf "%-18s: %-80s\n" "TAGS_DIR_W" "$TAGS_DIR_W"
  printf "%-18s: %-80s\n" "PATCHES_DIR" "$PATCHES_DIR"
  printf "%-18s: %-80s\n" "PKGS_DIR" "$PKGS_DIR"
  printf "%-18s: %-80s\n" "PKG_NAME" "$PKG_NAME"
  printf "%-18s: %-80s\n" "PKG_VER" "$PKG_VER"
  printf "%-18s: %-80s\n" "PKG_URL" "$PKG_URL"
  printf "%-18s: %-80s\n" "SRC_DIR" "$SRC_DIR"
  printf "%-18s: %-80s\n" "SRC_DIR_M" "$SRC_DIR_M"
  printf "%-18s: %-80s\n" "SRC_DIR_W" "$SRC_DIR_W"
  printf "%-18s: %-80s\n" "BUILD_DIR" "$BUILD_DIR"
  printf "%-18s: %-80s\n" "BUILD_DIR_M" "$BUILD_DIR_M"
  printf "%-18s: %-80s\n" "BUILD_DIR_W" "$BUILD_DIR_W"
  printf "%-18s: %-80s\n" "LOGS_DIR" "$LOGS_DIR"
  printf "%-18s: %-80s\n" "LOG_FILE" "$LOG_FILE"
  printf "%-18s: %-80s\n" "PKG_CONFIG_PATH" "$PKG_CONFIG_PATH"
  printf "%-18s: %-80s\n" "PKG_CONFIG_PATH_M" "$PKG_CONFIG_PATH_M"
  printf "%-18s: %-80s\n" "CMAKE_PREFIX_PATH" "$PREFIX_PATH_M"
}

print_error()
{
  echo [$0] Error, see build-$PKG_NAME.log for more details.
  exit 1
}

build_log()
{
  tee -a "$LOG_FILE"
}

create_dirs()
{
  if [ ! -d "$TAGS_DIR" ]; then mkdir -p $TAGS_DIR; fi
  if [ ! -d "$PKGS_DIR" ]; then mkdir -p $PKGS_DIR; fi
  if [ ! -d "$LOGS_DIR" ]; then mkdir -p $LOGS_DIR; fi
  if [ ! -d "$PREFIX" ]; then mkdir -p $PREFIX; fi
  if [ ! -d "$PREFIX/bin" ]; then mkdir -p "$PREFIX/bin"; fi
  if [ ! -d "$PREFIX/include" ]; then mkdir -p "$PREFIX/include"; fi
  if [ ! -d "$PREFIX/lib" ]; then mkdir -p "$PREFIX/lib"; fi
  if [ ! -d "$PREFIX/share" ]; then mkdir -p "$PREFIX/share"; fi
}

clean_log()
{
  if [ -f "$LOG_FILE" ]; then rm -rf "$LOG_FILE"; fi
}

check_depends()
{
  cd $FWD/ports
  if [ -n "$DEPENDS" ]; then
    local depends_array=($DEPENDS)
    for p in "${depends_array[@]}"; do
      echo [$0] Searching dependency $p on $ARCH
      if [ ! -f $OK_FILE ]; then touch $OK_FILE; fi
      if [ -f "$p.sh" ]; then
        eval "$FWD/ports/$p.sh $SAVE_ARGS" || print_error
      else
        echo [$0] Missing build script for package $p
        print_error
      fi
    done
  fi
}

build_decision()
{
  local name=${1,,}
  if [ -z "$name" ]; then
    name=${PKG_NAME,,}
  fi
  if [ "$PKG_VER" == "git" ]; then
    echo [$0] Build port $name because it is using git and may have new commit
    process_build
  else
    grep -Eqw "$ARCH+\s+$name\s+.+" $OK_FILE
    if [ "$?" != "0" ]; then
      echo [$0] Build port $name because it was not successful build yet
      process_build
    else
      old_arch=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $1}' | awk '$1=$1'`
      old_pkg_ver=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $3}' | awk '$1=$1'`
      if [ "$old_arch" == "$ARCH" ] && [ "$old_pkg_ver" != "$PKG_VER" ]; then
        echo [$0] Build port $name because previous version is older than current one
        process_build
      else
        echo [$0] Port $name was installed, not need to build
      fi
    fi
  fi
}

build_ok()
{
  local name=${1,,}
  if [ -z "$name" ]; then
    name=${PKG_NAME,,}
  fi
  if [ ! -f $OK_FILE ]; then touch $OK_FILE; fi
  grep -Eqw "$ARCH+\s+$name\s+.+" $OK_FILE
  if [ "$?" != "0" ]; then
    # save build result if it hasn't been successful build yet but now it is OK
    printf "%-4s %-16s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M">> $OK_FILE
  else
    old_arch=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $1}' | awk '$1=$1'`
    old_pkg_ver=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $3}' | awk '$1=$1'`
    if [ "$old_arch" == "$ARCH" ] && [ "$old_pkg_ver" != "$PKG_VER" ]; then
      replaced_line="`printf "%-4s %-16s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M"`"
      sed                                                            \
        -e "s|.\+\s\+$name\s\+.\+|$replaced_line|g"                 \
      $OK_FILE > $OK_FILE-t
      mv $OK_FILE-t $OK_FILE
    fi
  fi
  sort -n -k 2 $OK_FILE > $OK_FILE-t
  mv $OK_FILE-t $OK_FILE
}

check_triplet()
{
  cd $FWD
  if [ ! -f "config.guess" ]; then
    echo [$0] Downloading config.guess
    wget --no-check-certificate "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" \
      -O config.guess
  fi
  BUILD_TRIPLET=$(sh "config.guess")
  if [ "$ARCH" == "x86" ]; then
    HOST_TRIPLET=i686-w64-mingw32
    LLVM_TRIPLET=i686-pc-windows-msvc
  elif [ "$ARCH" == "x64" ]; then
    HOST_TRIPLET=x86_64-w64-mingw32
    LLVM_TRIPLET=x86_64-pc-windows-msvc
  else
    echo [$0] Please specify parameter ARCH to build, e.g. x86 or x64
    print_error
  fi
}

default_settings()
{
  case `uname -m` in
    x86_64 )
      HOST_ARCH=x64  # or AMD64 or Intel64 or whatever
      ;;
    i*86 )
      HOST_ARCH=x86  # or IA32 or Intel32 or whatever
      ;;
    * )
      # leave HOST_ARCH as-is
      ;;
  esac
  if [ -z "$ARCH" ]; then
    ARCH=x64
  fi
  if [ -n "${!PKG_PREFIX}" ]; then
    PREFIX=$(cygpath -u "${!PKG_PREFIX}")
  fi
  if [ -z "$PREFIX" ]; then
    if [ "$ARCH" == "x86" ]; then
      PREFIX="$FWD/x86"
    else
      PREFIX="$FWD/x64"
    fi
  fi
  if [ "$ARCH" == "x86" ]; then
    YASM_OBJ_FMT=win32
  else
    YASM_OBJ_FMT=win64
  fi
  PREFIX_M=`cygpath -m $PREFIX`
  PREFIX_W=`cygpath -w $PREFIX`
  if [ -f $OK_FILE ]; then
    while read -a line; do 
      old_arch=${line[0]}
      old_prefix=${line[3]}
      if [[ "$old_arch" == "$ARCH" ]] && [[ "$PREFIX_PATH_M" != *"$old_prefix"* ]]; then
        if [ -z "$PREFIX_PATH_M" ]; then
          PREFIX_PATH_M="$old_prefix"
        else
          PREFIX_PATH_M="$PREFIX_PATH_M;$old_prefix"
        fi
        if [ -z "$PREFIX_PATH_W" ]; then
          PREFIX_PATH_W=`cygpath -w "$old_prefix"`
        else
          PREFIX_PATH_W="$PREFIX_PATH_W;`cygpath -w "$old_prefix"`"
        fi
        if [ -z "$PREFIX_PATH" ]; then
          PREFIX_PATH=`cygpath -u "$old_prefix"`
        else
          PREFIX_PATH="$PREFIX_PATH:`cygpath -u "$old_prefix"`"
        fi
      fi
    done < $OK_FILE
  fi
  # For pkg-config from cygwin
  array=($(echo $PREFIX_PATH | tr ":" "\n"))
  for p in ${array[@]}; do
    if [ -d "$p/lib/pkgconfig" ]; then
      if [ -z "$PKG_CONFIG_PATH" ]; then
        PKG_CONFIG_PATH="$p/lib/pkgconfig"
      else
        PKG_CONFIG_PATH="$PKG_CONFIG_PATH;$p/lib/pkgconfig"
      fi
    fi
  done
  # For pkg-config from compiled
  array=($(echo $PREFIX_PATH_M | tr ";" "\n"))
  for p in ${array[@]}; do
    if [ -d "$p/lib/pkgconfig" ]; then
      if [ -z "$PKG_CONFIG_PATH_M" ]; then
        PKG_CONFIG_PATH_M="$p/lib/pkgconfig"
      else
        PKG_CONFIG_PATH_M="$PKG_CONFIG_PATH_M;$p/lib/pkgconfig"
      fi
    fi
  done
  if [ -z "$CPPFLAGS" ]; then
    CPPFLAGS='-I'"${PREFIX_PATH//:/\/include -I}"'/include'
  else
    CPPFLAGS="$CPPFLAGS"' -I'"${PREFIX_PATH//:/\/include -I}"'/include'
  fi
  LDFLAGS='-L'"${PREFIX_PATH//:/\/lib -L}"'/lib'
  if [ -z "$CPPFLAGS_M" ]; then
    CPPFLAGS_M='-I'"${PREFIX_PATH_M//;/\/include -I}"'/include'
  else
    CPPFLAGS_M="$CPPFLAGS_M"' -I'"${PREFIX_PATH_M//;/\/include -I}"'/include'
  fi
  LDFLAGS_M='-L'"${PREFIX_PATH_M//;/\/lib -L}"'/lib'
  if [ -z "$INCLUDE" ]; then
    INCLUDE="${PREFIX_PATH_W//;/\\include;}"'\include'
  else
    INCLUDE="$INCLUDE""${PREFIX_PATH_W//;/\\include;}"'\include'
  fi
  if [ -z "$LIB" ]; then
    LIB="${PREFIX_PATH_W//;/\\lib;}"'\lib'
  else
    LIB="$LIB""${PREFIX_PATH_W//;/\\lib;}"'\lib'
  fi
}

SAVE_ARGS="$@"
WIN32_TARGET=_WIN32_WINNT_WIN10
TAGS_DIR=$FWD/tags
PATCHES_DIR=$FWD/patches
LOGS_DIR=$FWD/logs
LOG_FILE=$LOGS_DIR/build-$PKG_NAME.txt
BUILD_TRIPLET=
HOST_TRIPLET=
OK_FILE=$FWD/build-ok.txt
PKG_PREFIX=$(echo ${PKG_NAME/-/_} | tr a-z A-Z)_PREFIX
HOST_ARCH=
ARCH=
PREFIX=
PREFIX_M=
PREFIX_W=
YASM_OBJ_FMT=
PKG_CONFIG_PATH=
PKG_CONFIG_PATH_M=
CFLAGS='-fp:precise -diagnostics:column -wd4819 -MD -openmp:llvm'
CXXFLAGS='-EHsc -fp:precise -diagnostics:column -wd4819 -MD -openmp:llvm'
CPPFLAGS="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE"
CPPFLAGS_M="-DWIN32 -D_WIN32_WINNT=$WIN32_TARGET -D_CRT_DECLARE_NONSTDC_NAMES -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS -D_CRT_SECURE_NO_DEPRECATE"
LDFLAGS=
LIBS=
FWD_M=`cygpath -m $FWD`
FWD_W=`cygpath -w $FWD`
SRC_DIR_M=`cygpath -m $SRC_DIR`
SRC_DIR_W=`cygpath -w $SRC_DIR`
TAGS_DIR_M=`cygpath -m $TAGS_DIR`
TAGS_DIR_W=`cygpath -w $TAGS_DIR`
if [ -n "$BUILD_DIR" ]; then BUILD_DIR_M=`cygpath -m $BUILD_DIR`; fi
if [ -n "$BUILD_DIR" ]; then BUILD_DIR_W=`cygpath -w $BUILD_DIR`; fi

while test $# -gt 0; do
  case "$1" in
    -h | --help )
      usage
      exit $? ;;
    --arch )
      shift
      if test $# = 0; then
        echo "missing argument for --arch"
      fi
      ARCH=$1
      shift ;;
    --arch=* )
      arg=`echo "X$1" | sed -e 's/^X--arch=//'`
      ARCH=$arg
      shift ;;
    --cflags )
      shift
      if test $# = 0; then
        echo "missing argument for --cflags"
      fi
      if [ -z "$CFLAGS" ]; then
        CFLAGS="$1"
      else
        CFLAGS="$CFLAGS $1"
      fi
      shift ;;
    --cflags=* )
      if [ -z "$CFLAGS" ]; then
        CFLAGS=`echo "X$1" | sed -e 's/^X--cflags=//'`
      else
        CFLAGS="$CFLAGS `echo "X$1" | sed -e 's/^X--cflags=//'`"
      fi
      shift ;;
    --cxxflags )
      shift
      if test $# = 0; then
        echo "missing argument for --cxxflags"
        exit 1
      fi
      if [ -z "$CXXFLAGS" ]; then
        CXXFLAGS="$1"
      else
        CXXFLAGS="$CXXFLAGS $1"
      fi
      shift ;;
    --cxxflags=* )
      if [ -z "$CXXFLAGS" ]; then
        CXXFLAGS=`echo "X$1" | sed -e 's/^X--cxxflags=//'`
      else
        CXXFLAGS="$CXXFLAGS `echo "X$1" | sed -e 's/^X--cxxflags=//'`"
      fi
      shift ;;
    --cppflags )
      shift
      if test $# = 0; then
        echo "missing argument for --cppflags"
        exit 1
      fi
      if [ -z "$CPPFLAGS" ]; then
        CPPFLAGS="$1"
      else
        CPPFLAGS="$CPPFLAGS $1"
      fi
      shift ;;
    --cppflags=* )
      if [ -z "$CPPFLAGS" ]; then
        CPPFLAGS=`echo "X$1" | sed -e 's/^X--cppflags=//'`
      else
        CPPFLAGS="$CPPFLAGS `echo "X$1" | sed -e 's/^X--cppflags=//'`"
      fi
      shift ;;
    --ldflags )
      shift
      if test $# = 0; then
        echo "missing argument for --ldflags"
        exit 1
      fi
      if [ -z "$LDFLAGS" ]; then
        LDFLAGS="$1"
      else
        LDFLAGS="$LDFLAGS $1"
      fi
      shift ;;
    --ldflags=* )
      if [ -z "$LDFLAGS" ]; then
        LDFLAGS=`echo "X$1" | sed -e 's/^X--ldflags=//'`
      else
        LDFLAGS="$LDFLAGS `echo "X$1" | sed -e 's/^X--ldflags=//'`"
      fi
      shift ;;
    --libs )
      shift
      if test $# = 0; then
        echo "missing argument for --libs"
        exit 1
      fi
      if [ -z "$LIBS" ]; then
        LIBS="$1"
      else
        LIBS="$LIBS $1"
      fi
      shift ;;
    --libs=* )
      if [ -z "$LIBS" ]; then
        LIBS=`echo "X$1" | sed -e 's/^X--libs=//'`
      else
        LIBS="$LIBS `echo "X$1" | sed -e 's/^X--libs=//'`"
      fi
      shift ;;
    --prefix )
      shift
      if test $# = 0; then
        echo "missing argument for --prefix"
        exit 1
      fi
      PREFIX=`cygpath -u $1`
      shift ;;
    --prefix=* )
      arg=`echo "X$1" | sed -e 's/^X--prefix=//'`
      PREFIX=`cygpath -u $arg`
      shift ;;
    * )
      shift ;;
  esac
done

default_settings
. $FWD/compiler.sh
export CPATH="$INCLUDE"
