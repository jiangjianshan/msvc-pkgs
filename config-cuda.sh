#!/bin/bash
#
# Set INCLUDE and LIB of CUDA and CUDNN
#
if [ -n "${CUDA_PATH}" ]; then
  PATH=`cygpath -u "${CUDA_PATH}"`/bin:"$PATH"
  PATH=`cygpath -u "${CUDA_PATH}"`/extras/demo_suite:"$PATH"
  if nvcc --version 2&> /dev/null; then
    # Determine CUDA version using default nvcc binary
    CUDA_VERSION=$(nvcc --version | sed -n 's/^.*release \([0-9]\+\.[0-9]\+\).*$/\1/p')
  else
    echo [$0] Can not find the exact version of CUDA
    exit 1
  fi
  CUDAINSTALLDIR=${CUDA_PATH}
  INCLUDE="${CUDAINSTALLDIR}"'\include;'"$INCLUDE"
  LIB="${CUDAINSTALLDIR}"'\lib\'"$HOST_ARCH"';'"$LIB"
  CUDNN_VERSION_H=`find "$(cygpath -u "$CUDA_PATH")" -name "cudnn_version.h"`
  if [ -z "$CUDNN_VERSION_H" ]; then
    CUDNN_VERSION_H=`find "$(cygpath -u "C:\Program Files\NVIDIA\CUDNN")" -name "cudnn_version.h"`
  fi
  CUDNN_MAJOR=`cat "$CUDNN_VERSION_H" | grep "#define CUDNN_MAJOR" | tr -d '\r' | awk '{print $3}'`
  CUDNN_MINOR=`cat "$CUDNN_VERSION_H" | grep "#define CUDNN_MINOR" | tr -d '\r' | awk '{print $3}'`
  CUDNN_VERSION=${CUDNN_MAJOR}.${CUDNN_MINOR}
  CUDNNINSTALLDIR='C:\Program Files\NVIDIA\CUDNN\v'"$CUDNN_VERSION"
  INCLUDE="${CUDNNINSTALLDIR}"'\include\'"$CUDA_VERSION"';'"$INCLUDE"
  LIB="${CUDNNINSTALLDIR}"'\lib\'"$CUDA_VERSION"'\'"$HOST_ARCH"';'"$LIB"
fi

export PATH INCLUDE LIB CUDA_VERSION CUDNN_VERSION
