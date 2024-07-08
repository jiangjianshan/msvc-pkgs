#!/bin/bash
#
# NOTICE: don't set PATH_SEPARATOR like below, it will cause issue that 'checking for
# grep that handles long lines and -e... configure: error: no acceptable grep could 
# be found'
# export PATH_SEPARATOR=";"

DEPENDS=
FWD=`dirname $(pwd)`
CWD=$(cd `dirname $0`; pwd)
PKG_NAME=gnulib
PKG_VER=git
PKG_URL=https://git.savannah.gnu.org/git/$PKG_NAME.git
PKGS_DIR=$FWD/pkgs
SRC_DIR=$PKGS_DIR/$PKG_NAME

. $FWD/common.sh

prepare_package()
{
  clean_log
  create_dirs
  check_depends
  display_info
  cd $PKGS_DIR
  if [ ! -d "$SRC_DIR" ]; then
    git clone --depth 1 --single-branch -b master $PKG_URL || print_error
    if [ -f $HOME/.zshrc ]; then echo "export GNULIB_SRCDIR=$SRC_DIR" >> $HOME/.zshrc; fi
    if [ -f $HOME/.bashrc ]; then echo "export GNULIB_SRCDIR=$SRC_DIR" >> $HOME/.bashrc; fi
  else
    echo [$0] Updating $PKG_NAME
    pushd $SRC_DIR
    git fetch origin master --depth 1
    git reset --hard origin/master
    popd
  fi
}

prepare_package
