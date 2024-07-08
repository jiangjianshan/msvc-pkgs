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
  --rebuild                : Rebuild current package even it has been successful build yet
  --rebuil-all             : Rebuild current package including its dependencies even they have been
                        successful build yet

  Example:
    [$0] --arch x86 --ports gmp,gettext
    [$0] --arch x64
    [$0] --ports perl --prefix "D:\Perl"
    [$0] --llvm-project-prefix "D:\LLVM" --lua-prefix "D:\Lua" --ruby-prefix "D:\Ruby"
    [$0] --ports gmp,gettext
    [$0] --ports gmp gettext"
}

ARCH=
PORTS=
PREFIX=
REBUILD=
REBUILDALL=
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
      desired_value=`cygpath -u "$1"`
      export ${desired_var_name^^}=$desired_value
      shift ;;
    --*-prefix=* )
      pkg_name=`expr "x$1" : 'x--\(.*\)-prefix=.*'`
      arg=`echo "X$1" | sed -e "s/^X--$pkg_name-prefix=//"`
      desired_var_name="${pkg_name/-/_}_prefix"
      desired_value=`cygpath -u "$arg"`
      export ${desired_var_name^^}=$desired_value
      shift ;;
    --rebuild )
      REBUILD=1
      shift ;;
    --rebuild-all )
      REBUILDALL=1
      shift ;;
    * )
      shift ;;
  esac
done

