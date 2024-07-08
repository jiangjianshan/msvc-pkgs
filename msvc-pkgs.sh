#!/bin/bash

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
SAVE_ARGS="$@"

. $CWD/args-parser.sh
build_ports
