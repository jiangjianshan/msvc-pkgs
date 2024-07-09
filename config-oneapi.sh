#!/bin/bash

ONEAPI_ROOT='C:\Program Files (x86)\Intel\oneAPI'

# C++ Compiler
CMPLR_ROOT="${ONEAPI_ROOT}"'compiler\latest'
PATH=`cygpath -u "${CMPLR_ROOT}"`/bin:"$PATH"
PATH=`cygpath -u "${CMPLR_ROOT}"`/lib/ocloc:"$PATH"
PATH=`cygpath -u "${CMPLR_ROOT}"`/bin/compiler:"$PATH"
INCLUDE="${CMPLR_ROOT}"'\include;'"$INCLUDE"
if [ "$ARCH" == "x86" ]; then
    PATH=`cygpath -u "${CMPLR_ROOT}"`/bin32:"$PATH"
    LIB="${CMPLR_ROOT}"'\lib32;'"$LIB"
    PKG_CONFIG_PATH="${CMPLR_ROOT}"'\lib32\pkgconfig;'"$PKG_CONFIG_PATH"
else
    LIB="${CMPLR_ROOT}"'\lib\clang\18\lib\windows;'"${CMPLR_ROOT}"'\opt\compiler\lib;'"${CMPLR_ROOT}"'\lib;'"$LIB"
    PKG_CONFIG_PATH="${CMPLR_ROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"
fi
OCL_ICD_FILENAMES="${OCL_ICD_FILENAMES}"';'"${CMPLR_ROOT}"'\bin\intelocl64_emu.dll;'"${CMPLR_ROOT}"'\bin\intelocl64.dll'
CMAKE_PREFIX_PATH="${CMPLR_ROOT}"';'"$CMAKE_PREFIX_PATH"

# OCLOC
OCLOC_ROOT="${ONEAPI_ROOT}"'\ocloc\latest'
OCL_ICD_FILENAMES="${CMPLR_ROOT}"'/bin/intelocl64_emu.dll;'"${CMPLR_ROOT}"'/bin/intelocl64.dll'
PATH=`cygpath -u "${OCLOC_ROOT}"`/bin:"$PATH"
INCLUDE="${OCLOC_ROOT}"'\include;'"$INCLUDE"

# DPL
DPL_ROOT="${ONEAPI_ROOT}"'\dpl\latest'
PKG_CONFIG_PATH="${DPL_ROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"
CMAKE_PREFIX_PATH="${DPL_ROOT}"'\lib\cmake\oneDPL;'"$CMAKE_PREFIX_PATH"

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

# TBB
TBBROOT="${ONEAPI_ROOT}"'\tbb\latest'
PATH=`cygpath -u "${TBBROOT}"`/bin:"$PATH"
INCLUDE="${TBBROOT}"'\include;'"$INCLUDE"
LIB="${TBBROOT}"'\lib;'"$LIB"
PKG_CONFIG_PATH="${TBBROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"
CMAKE_PREFIX_PATH="${TBBROOT}"';'"$CMAKE_PREFIX_PATH"

# IPP
IPPROOT="${ONEAPI_ROOT}"'\ipp\latest'
PATH=`cygpath -u "${IPPROOT}"`/bin:"$PATH"
INCLUDE="${IPPROOT}"'\include;'"$INCLUDE"
LIB="${IPPROOT}"'\lib;'"$LIB"
CMAKE_PREFIX_PATH="${IPPROOT}"'\lib\cmake\ipp;'"$CMAKE_PREFIX_PATH"

# IPPCP
IPPCRYPTOROOT="${ONEAPI_ROOT}"'\ippcp\latest'
PATH=`cygpath -u "${IPPCRYPTOROOT}"`/bin:"$PATH"
INCLUDE="${IPPCRYPTOROOT}"'\include;'"$INCLUDE"
LIB="${IPPCRYPTOROOT}"'\lib;'"$LIB"
PKG_CONFIG_PATH="${IPPCRYPTOROOT}"'\lib\pkgconfig;'"$PKG_CONFIG_PATH"

# Fortran Compiler
IFORT_COMPILER24="${ONEAPI_ROOT}"'\compiler\2024.2'

export PATH INCLUDE LIB ONEAPI_ROOT I_MPI_ROOT MKLROOT
