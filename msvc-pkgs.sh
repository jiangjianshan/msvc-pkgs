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
  --help                   : Display this help
  --arch                   : Build and test x86 or x64 variant
  --list                   : List available ports
  --prefix                 : Install root location of bin, include, lib, share etc. the
                        default value is $FWD/$ARCH. Also some special prefix can
                        be set in here for some ports, the delimiter is colon combining
                        equal for different prefix
  --[package name]-prefix  : Install root location of bin, include, lib, share etc for specify
                        package name, e.g. --llvm-project-prefix means set the install prefix
                        of package llvm-project
  --cflags                 : CFLAGS is for flags for the C++ compiler.
                        The default rules in make, CFLAGS is only passed when compiling 
                        and linking C.
                        This customized CFLAGS added to default CFLAGS
  --cxxflags               : CXXFLAGS is for flags for the C++ compiler.
                        The default rules in make, CXXFLAGS is only passed when compiling 
                        and linking C++.
                        This customized CXXFLAGS added to default CXXFLAGS
  --cppflags               : CPPFLAGS is supposed to be for flags for the C PreProcessor. 
                        The default rules in make pass CPPFLAGS to just about everything.
                        This customized CPPFLAGS will be added to default CPPFLAGS
  --ldflags                : Extra flags to give to compilers when they are supposed to invoke 
                        the linker.
                        This customized LDFLAGS will be added to defaults LDFLAGS
  --libs                   : Library flags or names given to compilers when they are supposed 
                        to invoke the linker
                        This customized LIBS will be added to defaults LIBS

  Example:
    [$0] --arch x86 --ports libiconv,gettext
    [$0] --arch x64
    [$0] --ports perl --prefix "D:\Perl"
    [$0] --llvm-project-prefix "D:\LLVM" --lua-prefix "D:\Lua" --ruby-prefix "D:\Ruby"
    [$0] --ports libiconv,gettext
    [$0] --ports libiconv gettext"
}

list_ports()
{
  echo [$0] Avaiable ports:
  cd $CWD/ports
  for p in `ls *.sh | grep -wv gnulib.sh`; do
    echo $p
  done
}

build_ports()
{
  cd $CWD/ports
  if [ -n "$PORTS" ]; then
    array=($(echo $PORTS | tr "," "\n"))
    for p in ${array[@]}; do
      ./$p.sh $SAVE_ARGS
    done
  else
    # If not specify --ports, then will build all those packages haven't been
    # build before or build fail before.
    for p in `ls *.sh | sed -e 's|.sh||'`; do
      ./$p.sh $SAVE_ARGS
    done
  fi
}

FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
if [ -z ${OK_FILE+x} ]; then
  OK_FILE=$CWD/build-ok.txt
  if [ ! -f $OK_FILE ]; then touch $OK_FILE; fi
fi
PORTS=
PREFIX=
SAVE_ARGS="$@"
while test $# -gt 0; do
  case "$1" in
    -h | --help )
      usage
      exit $? ;;
    --list )
      list_ports
      exit $? ;;
    --ports )
      shift
      if test $# = 0; then
        echo "missing argument for --ports"
        exit 1
      fi
      while [ $# -gt 0 ]; do 
        case "$1" in
          --* )
            break
            ;;
          * )
            if [ -z $PORTS ]; then
              PORTS=$1
            else
              PORTS=$PORTS,$1
            fi
            shift ;;
        esac
      done
      ;;
    --ports=* )
      arg=`echo "X$1" | sed -e 's/^X--ports=//'`
      PORTS=$arg
      shift 
      while [ $# -gt 0 ]; do 
        case "$1" in
          --* )
            break
            ;;
          * )
            if [ -z $PORTS ]; then
              PORTS=$1
            else
              PORTS=$PORTS,$1
            fi
            shift ;;
        esac
      done
      ;;
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
    --*-prefix )
      pkg_name=`expr "x$1" : 'x--\(.*\)-prefix'`
      shift
      if test $# = 0; then
        echo "missing argument for --*-prefix"
        exit 1
      fi
      desired_var_name="${pkg_name/-/_}_prefix"
      desired_value="$1"
      export ${desired_var_name^^}=$desired_value
      shift ;;
    --*-prefix=* )
      pkg_name=`expr "x$1" : 'x--\(.*\)-prefix=.*'`
      arg=`echo "X$1" | sed -e "s/^X--$pkg_name-prefix=//"`
      desired_var_name="${pkg_name/-/_}_prefix"
      desired_value="$arg"
      export ${desired_var_name^^}=$desired_value
      shift ;;
    * )
      shift ;;
  esac
done

build_ports
