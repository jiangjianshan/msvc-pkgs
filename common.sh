#!/bin/bash

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
  printf "%-18s: %-80s\n" "CMAKE_PREFIX_PATH" "$PREFIX_PATH_M"
  printf "%-18s: %-80s\n" "INCLUDES" "$INCLUDES"
  printf "%-18s: %-80s\n" "MESON_LDFLAGS" "$MESON_LDFLAGS"
  printf "%-18s: %-80s\n" "AUTOCONF_LDFLAGS" "$AUTOCONF_LDFLAGS"
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
        eval "$FWD/ports/$p.sh ${SAVE_ARGS//--rebuild/}" || print_error
      else
        echo [$0] Missing build script for package $p
        print_error
      fi
    done
  fi
}

build_decision()
{
  local name=$1
  if [ -z "$name" ]; then
    name=$PKG_NAME
  fi
  if [ -n "$REBUILD" ] || [ -n "$REBUILDALL" ]; then
    echo [$0] Build port $name because rebuild request
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
  local name=$1
  if [ -z "$name" ]; then
    name=$PKG_NAME
  fi
  if [ ! -f $OK_FILE ]; then touch $OK_FILE; fi
  grep -Eqw "$ARCH+\s+$name\s+.+" $OK_FILE
  if [ "$?" != "0" ]; then
    # save build result if it hasn't been successful build yet but now it is OK
    printf "%-4s %-26s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M">> $OK_FILE
  else
    old_arch=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $1}' | awk '$1=$1'`
    old_pkg_ver=`grep -Eo "\w+\s+$name\s+.+" $OK_FILE | awk '{print $3}' | awk '$1=$1'`
    if [ "$old_arch" == "$ARCH" ] && [ "$old_pkg_ver" != "$PKG_VER" ]; then
      replaced_line="`printf "%-4s %-26s %-12s %-60s\n" $ARCH "$name" "$PKG_VER" "$PREFIX_M"`"
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

check_arch()
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
}

default_settings()
{
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
          PREFIX_PATH_M="$old_prefix;$PREFIX_PATH_M"
        fi
      fi
    done < $OK_FILE
  fi
  # For pkg-config from cygwin
  array=($(echo $PREFIX_PATH_M | tr ";" "\n"))
  for p in ${array[@]}; do
    if [ -d "$p/lib/pkgconfig" ]; then
      if [ -z "$PKG_CONFIG_PATH" ]; then
        PKG_CONFIG_PATH="$p/lib/pkgconfig"
      else
        PKG_CONFIG_PATH="$p/lib/pkgconfig;$PKG_CONFIG_PATH"
      fi
    fi
    # NOTE:
    # 1. Don't add $p/bin to PATH here and never do that, especially 
    #    the path of custom build of Perl. If do that, autoconf and
    #    automake will use windows's Perl but not cygwin's Perl. This
    #    will cause the configuration of prcoess fail
    if [ -d "$p/include" ]; then
      INCLUDE="$p"'\include;'"$INCLUDE"
      if [ -z "$INCLUDES" ]; then
        INCLUDES='-I'"$p"'/include'
      else
        INCLUDES='-I'"$p"'/include '"$INCLUDES"
      fi
    fi
    if [ -d "$p/lib" ]; then
      LIB="$p"'\lib;'"$LIB"
      if [ -z "$MESON_LDFLAGS" ]; then
        MESON_LDFLAGS='/LIBPATH:'"$p"'/lib'
      else
        MESON_LDFLAGS='/LIBPATH:'"$p"'/lib,'"$MESON_LDFLAGS"
      fi
      if [ -z "AUTOCONF_LDFLAGS" ]; then
        AUTOCONF_LDFLAGS='-L'"$p"'/lib'
      else
        AUTOCONF_LDFLAGS='-L'"$p"'/lib '"$AUTOCONF_LDFLAGS"
      fi
    fi
  done
  if [ -n "$CUDA_PATH" ]; then
    NV_COMPUTE=$(deviceQuery | awk '/CUDA Capability Major/{print $(NF)}')
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
PKG_PREFIX=$(echo ${PKG_NAME//-/_} | tr a-z A-Z)_PREFIX
HOST_ARCH=
PREFIX_M=
PREFIX_W=
YASM_OBJ_FMT=
FWD_M=`cygpath -m $FWD`
FWD_W=`cygpath -w $FWD`
SRC_DIR_M=`cygpath -m $SRC_DIR`
SRC_DIR_W=`cygpath -w $SRC_DIR`
TAGS_DIR_M=`cygpath -m $TAGS_DIR`
TAGS_DIR_W=`cygpath -w $TAGS_DIR`
if [ -n "$BUILD_DIR" ]; then BUILD_DIR_M=`cygpath -m $BUILD_DIR`; fi
if [ -n "$BUILD_DIR" ]; then BUILD_DIR_W=`cygpath -w $BUILD_DIR`; fi

. $FWD/args-parser.sh
check_arch
. $FWD/compiler.sh
default_settings
