#!/bin/bash
#
# @author: Anthony Cros
# 
# usage: ./main.sh /path/to/cross/compiler [%y%m%d%H%M%S-like timestamp]
#
# notes:
# - if you don't have one yet, run xcompiler.sh to create a cross-compiler first (sole mandatory argument of the script)
# - you can optionally pass a timestamp (acts as unique identifier) to re-use, mostly to avoid re-downloading (workspace is then expected to be manually cleaned up)
# - miniupnpc is currently broken
#
# TODO:
# - libjson RPC CPP seems to contact github somehow...
# - homogenize dependency install dirs
# - use log dir and parse logs
# - check signatures (see https://www.cryptopp.com/)
# - traps
# - homogenize hack sanity checks
# - generalize to more target architectures
# - options to turn on/off components/steps (e.g. download_all, cmake, ...)
# - generalize GMP/MHD build (exact same steps)
# - MHD: address warnings
# - make checks
# - associative array for each component's property (base dir, version, ...)
 
# ===========================================================================
set -e
if [ ! -f "./setup.sh" ]; then echo "ERROR: wrong pwd"; exit 1; fi

# ===========================================================================
CROSS_COMPILER_ROOT_DIR="${1?}" && shift # e.g. "/home/tony/x-tools/arm-unknown-linux-gnueabi"

TIMESTAMP=$1
TIMESTAMP=${TIMESTAMP:=$(date '+%y%m%d%H%M%S')}

source ./setup.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"

# ===========================================================================

cd ${INITIAL_DIR?}               && pwd && git log -1 --format="%h"
cd ${WEBTHREE_HELPERS_BASE_DIR?} && pwd && git log -1 --format="%h"
cd ${LIBWEB3CORE_BASE_DIR?}      && pwd && git log -1 --format="%h"
cd ${LIBETHEREUM_BASE_DIR?}      && pwd && git log -1 --format="%h"
cd ${WEBTHREE_BASE_DIR?}         && pwd && git log -1 --format="%h"
cd ${INITIAL_DIR?}

# ===========================================================================
# init:
mkdir -p ${BASE_DIR?}
mkdir -p ${SOURCES_DIR?} ${WORK_DIR?} ${LOGS_DIR?} ${INSTALLS_DIR?} ${BACKUPS_DIR?}

# ===========================================================================
# downloads
./download.sh \
  "${CMAKE?}:${JSONCPP?}:${BOOST?}:${LEVELDB?}:${CRYPTOPP?}:${GMP?}:${CURL?}:${LIBJSON_RPC_CPP?}:${MHD?}" \
  "${CROSS_COMPILER_ROOT_DIR?}" \
  "${TIMESTAMP?}"

# ===========================================================================
# cmake:
mkdir -p ${CMAKE_INSTALL_DIR?}
get_cmake_toolchain_file_content > ${CMAKE_TOOLCHAIN_FILE?}
echo && tree -L 1 ${BASE_DIR?} && \
  echo -e "\n\n${CMAKE_TOOLCHAIN_FILE?}:\n$(cat ${CMAKE_TOOLCHAIN_FILE?})\n"

# ===========================================================================
# libweb3core dependencies cross-compilation
export_cross_compiler
sanity_check_cross_compiler

./boost.sh     "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./jsoncpp.sh   "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./leveldb.sh   "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./cryptopp.sh  "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./gmp.sh       "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"

./curl.sh            "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./mhd.sh             "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}" #cp -r ~/eth/151103215114/installs/libmicrohttpd ~/eth/${TIMESTAMP?}/installs/
./libjson-rpc-cpp.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}" # needs both curl and mhd

./libscrypt.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"
./secp256k1.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"

# ---------------------------------------------------------------------------
# webthree-helpers hack (for libethereum):
clone ${WEBTHREE_HELPERS_BASE_DIR?} ${WEBTHREE_HELPERS_WORK_DIR?} # clones without cd-ing
generic_hack \
  ${WEBTHREE_HELPERS_WORK_DIR?}/cmake/UseEth.cmake \
  '!/Eth::ethash-cl Cpuid/'
generic_hack \
  ${WEBTHREE_HELPERS_WORK_DIR?}/cmake/UseDev.cmake \
  '!/Miniupnpc/'

# ---------------------------------------------------------------------------
./libweb3core.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}"


# ===========================================================================
# libethereum dependencies cross-compilation
export_cross_compiler
sanity_check_cross_compiler

./libethereum.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}" # requires libweb3core


# ===========================================================================
# webthree dependencies cross-compilation
export_cross_compiler
sanity_check_cross_compiler

./webthree.sh "${CROSS_COMPILER_ROOT_DIR?}" "${TIMESTAMP?}" # requires libweb3core and libethereum


# ===========================================================================
printf '=%.0s' {1..75} && echo
tree -L 4 ${LIBWEB3CORE_INSTALL_DIR?}
tree -L 4 ${LIBETHEREUM_INSTALL_DIR?}
tree -L 4 ${WEBTHREE_INSTALL_DIR?}

# ===========================================================================
# produces a packaged-up file (will spit out instructions on how to use it)
./package.sh \
  ${TIMESTAMP?} \
  ${INSTALLS_DIR?} \
  ${WEBTHREE_INSTALL_DIR?}/usr/local/bin

# ===========================================================================
echo "done."

# ===========================================================================
