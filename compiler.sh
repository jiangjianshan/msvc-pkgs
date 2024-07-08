#!/bin/bash
#
# NOTE: Avoid to be sourced multiple times
#
[ "$sourced_compiler_sh" != "" ] && return || sourced_compiler_sh=.
export sourced_compiler_sh
. $FWD/config-msvc.sh
. $FWD/config-oneapi.sh
. $FWD/config-cuda.sh
