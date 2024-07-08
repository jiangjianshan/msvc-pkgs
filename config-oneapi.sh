#!/bin/bash

ONEAPI_ROOT='C:\Program Files (x86)\Intel\oneAPI'

# MPI
I_MPI_ROOT="${ONEAPI_ROOT}"'\mpi\latest'
PATH=`cygpath -u "${I_MPI_ROOT}"`/opt/mpi/libfabric/bin:"$PATH"
PATH=`cygpath -u "${I_MPI_ROOT}"`/bin:"$PATH"
INCLUDE="${I_MPI_ROOT}"'\include;'"$INCLUDE"
LIB="${I_MPI_ROOT}"'\lib;'"$LIB"
PKG_CONFIG_PATH="${I_MPI_ROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"
CMAKE_PREFIX_PATH="${I_MPI_ROOT}""$CMAKE_PREFIX_PATH"

# MKL
MKLROOT="${ONEAPI_ROOT}"'\mkl\latest'
PATH=`cygpath -u "${MKLROOT}"`/bin:"$PATH"
INCLUDE="${MKLROOT}"'\include;'"$INCLUDE"
LIB="${MKLROOT}"'\lib;'"$LIB"
PKG_CONFIG_PATH="${MKLROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"
CMAKE_PREFIX_PATH="${MKLROOT}"';'"$CMAKE_PREFIX_PATH"

export PATH INCLUDE LIB ONEAPI_ROOT I_MPI_ROOT MKLROOT
