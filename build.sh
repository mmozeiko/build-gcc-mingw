#!/bin/bash

set -eux

ZSTD_VERSION=1.5.7
ZSTD_SHA256=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3

GMP_VERSION=6.3.0
GMP_SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898

MPFR_VERSION=4.2.2
MPFR_SHA256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01

MPC_VERSION=1.4.1
MPC_SHA256=91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931

ISL_VERSION=0.27
ISL_SHA256=6d8babb59e7b672e8cb7870e874f3f7b813b6e00e6af3f8b04f7579965643d5c

EXPAT_VERSION=2.8.0
EXPAT_SHA256=a37bfae0aa9775bd8521ebd85dc456d486f0ff31138f6c91fd902ea732624542

BINUTILS_VERSION=2.46.0
BINUTILS_SHA256=d75a94f4d73e7a4086f7513e67e439e8fcdcbb726ffe63f4661744e6256b2cf2

GCC_VERSION=16.1.0
GCC_SHA256=50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79

MINGW_VERSION=14.0.0
MINGW_SHA256=6eaf921d9eb987d3820b364ea9775bc19b965ec81490b6fdd716526c28e1995c

GDB_VERSION=17.1
GDB_SHA256=14996f5f74c9f68f5a543fdc45bca7800207f91f92aeea6c2e791822c7c6d876

MAKE_VERSION=4.4.1
MAKE_SHA256=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3

ARCH=${1:-x86_64}
CRT=${2:-ucrt}

if [ "${CRT}" == "ucrt" ]; then
  EXTRA_CRT_ARGS="--with-default-msvcrt=ucrt"
elif [ "${CRT}" == "msvcrt" ]; then
  EXTRA_CRT_ARGS="--with-default-msvcrt=msvcrt-os"
else
  exit 1
fi

if [ "${ARCH}" == "i686" ]; then
  EXTRA_CRT_ARGS="${EXTRA_CRT_ARGS} --disable-lib64"
  EXTRA_GCC_ARGS="--disable-sjlj-exceptions --with-dwarf2"
elif [ "${ARCH}" == "x86_64" ]; then
  EXTRA_CRT_ARGS="${EXTRA_CRT_ARGS} --disable-lib32"
  EXTRA_GCC_ARGS=
else
  exit 1
fi

NAME=gcc-v${GCC_VERSION}-mingw-v${MINGW_VERSION}-${CRT}-${ARCH}
TARGET=${ARCH}-w64-mingw32

function get()
{
  mkdir -p ${SOURCE} && pushd ${SOURCE}
  FILE="${1##*/}"
  echo "$2 ${FILE}" | sha256sum -c - || rm -f ${FILE}
  if [ ! -f "${FILE}" ]; then
    curl -fL "$1" -o ${FILE}
    echo "$2 ${FILE}" | sha256sum -c -
    case "${1##*.}" in
    gz|tgz)
      tar --warning=none -xzf ${FILE}
      ;;
    bz2)
      tar --warning=none -xjf ${FILE}
      ;;
    xz)
      tar --warning=none -xJf ${FILE}
      ;;
    *)
      exit 1
      ;;
    esac
  fi
  popd
}

# by default place output in current folder
OUTPUT="${OUTPUT:-`pwd`}"

# place where source code is downloaded & unpacked
SOURCE=`pwd`/source

# place where build for specific target is done
BUILD=`pwd`/build-${CRT}/${TARGET}

# place where bootstrap compiler is built
BOOTSTRAP=`pwd`/bootstrap-${CRT}/${TARGET}

# place where build dependencies are installed
PREFIX=`pwd`/prefix-${CRT}/${TARGET}

# final installation folder
FINAL=`pwd`/${NAME}

get https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz                  ${ZSTD_SHA256}
get https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz                                                            ${GMP_SHA256}
get https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz                                                         ${MPFR_SHA256}
get https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.xz                                                            ${MPC_SHA256}
get https://libisl.sourceforge.io/isl-${ISL_VERSION}.tar.xz                                                          ${ISL_SHA256}
get https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz     ${EXPAT_SHA256}
get https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz                                             ${BINUTILS_SHA256}
get https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz                                         ${GCC_SHA256}
get https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 ${MINGW_SHA256}
get https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz                                                            ${GDB_SHA256}
get https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz                                                         ${MAKE_SHA256}

mkdir -p ${BUILD}/x-binutils && pushd ${BUILD}/x-binutils
${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
  --prefix=${BOOTSTRAP}                          \
  --with-sysroot=${BOOTSTRAP}                    \
  --target=${TARGET}                             \
  --disable-plugins                              \
  --disable-nls                                  \
  --disable-shared                               \
  --disable-multilib                             \
  --disable-werror
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/x-mingw-w64-headers && pushd ${BUILD}/x-mingw-w64-headers
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
  --prefix=${BOOTSTRAP}                                           \
  --host=${TARGET}                                                \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
ln -sTf ${BOOTSTRAP} ${BOOTSTRAP}/mingw
popd

mkdir -p ${BUILD}/x-gcc && pushd ${BUILD}/x-gcc
${SOURCE}/gcc-${GCC_VERSION}/configure \
  --prefix=${BOOTSTRAP}                \
  --with-sysroot=${BOOTSTRAP}          \
  --target=${TARGET}                   \
  --enable-static                      \
  --disable-shared                     \
  --disable-lto                        \
  --disable-nls                        \
  --disable-multilib                   \
  --disable-werror                     \
  --disable-libgomp                    \
  --enable-tls                         \
  --enable-languages=c,c++             \
  --enable-threads=win32               \
  --enable-checking=release            \
  --enable-large-address-aware         \
  --enable-libstdcxx-threads           \
  --disable-libstdcxx-pch              \
  --disable-libstdcxx-verbose          \
  ${EXTRA_GCC_ARGS}
make -j`nproc` all-gcc
make install-gcc
popd

export PATH=${BOOTSTRAP}/bin:$PATH

mkdir -p ${BUILD}/x-mingw-w64-crt && pushd ${BUILD}/x-mingw-w64-crt
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
  --prefix=${BOOTSTRAP}                                       \
  --with-sysroot=${BOOTSTRAP}                                 \
  --host=${TARGET}                                            \
  --disable-dependency-tracking                               \
  --enable-warnings=0                                         \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/x-mingw-w64-winpthreads && pushd ${BUILD}/x-mingw-w64-winpthreads
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
  --prefix=${BOOTSTRAP}                                                         \
  --with-sysroot=${BOOTSTRAP}                                                   \
  --host=${TARGET}                                                              \
  --disable-dependency-tracking                                                 \
  --enable-static                                                               \
  --disable-shared                                                              \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

pushd ${BUILD}/x-gcc
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/zstd && pushd ${BUILD}/zstd
cmake ${SOURCE}/zstd-${ZSTD_VERSION}/build/cmake \
  -DCMAKE_BUILD_TYPE=Release                     \
  -DCMAKE_SYSTEM_NAME=Windows                    \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}               \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER      \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY       \
  -DCMAKE_C_COMPILER=${TARGET}-gcc               \
  -DCMAKE_CXX_COMPILER=${TARGET}-g++             \
  -DZSTD_BUILD_STATIC=ON                         \
  -DZSTD_BUILD_SHARED=OFF                        \
  -DZSTD_BUILD_PROGRAMS=OFF                      \
  -DZSTD_BUILD_CONTRIB=OFF                       \
  -DZSTD_BUILD_TESTS=OFF
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gmp && pushd ${BUILD}/gmp
${SOURCE}/gmp-${GMP_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --enable-fat                         \
  CC=${TARGET}-gcc                     \
  CFLAGS="-O2 -std=gnu17"
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mpfr && pushd ${BUILD}/mpfr
${SOURCE}/mpfr-${MPFR_VERSION}/configure \
  --prefix=${PREFIX}                     \
  --host=${TARGET}                       \
  --disable-shared                       \
  --enable-static                        \
  --with-gmp-build=${BUILD}/gmp
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mpc && pushd ${BUILD}/mpc
${SOURCE}/mpc-${MPC_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-{gmp,mpfr}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/isl && pushd ${BUILD}/isl
${SOURCE}/isl-${ISL_VERSION}/configure \
  --prefix=${PREFIX}                   \
  --host=${TARGET}                     \
  --disable-shared                     \
  --enable-static                      \
  --with-gmp-prefix=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/expat && pushd ${BUILD}/expat
${SOURCE}/expat-${EXPAT_VERSION}/configure \
  --prefix=${PREFIX}                       \
  --host=${TARGET}                         \
  --disable-shared                         \
  --enable-static                          \
  --without-examples                       \
  --without-tests
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/binutils && pushd ${BUILD}/binutils
${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
  --prefix=${FINAL}                              \
  --with-sysroot=${FINAL}                        \
  --host=${TARGET}                               \
  --target=${TARGET}                             \
  --enable-lto                                   \
  --enable-plugins                               \
  --enable-64-bit-bfd                            \
  --disable-nls                                  \
  --disable-multilib                             \
  --disable-werror                               \
  --with-{gmp,mpfr,mpc,isl}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mingw-w64-headers && pushd ${BUILD}/mingw-w64-headers
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
  --prefix=${FINAL}/${TARGET}                                     \
  --host=${TARGET}                                                \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
ln -sTf ${FINAL}/${TARGET} ${FINAL}/mingw
popd

mkdir -p ${BUILD}/mingw-w64-crt && pushd ${BUILD}/mingw-w64-crt
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
  --prefix=${FINAL}/${TARGET}                                 \
  --with-sysroot=${FINAL}/${TARGET}                           \
  --host=${TARGET}                                            \
  --disable-dependency-tracking                               \
  --enable-warnings=0                                         \
  ${EXTRA_CRT_ARGS}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gcc && pushd ${BUILD}/gcc
${SOURCE}/gcc-${GCC_VERSION}/configure \
  --prefix=${FINAL}                    \
  --with-sysroot=${FINAL}              \
  --target=${TARGET}                   \
  --host=${TARGET}                     \
  --disable-dependency-tracking        \
  --disable-nls                        \
  --disable-multilib                   \
  --disable-werror                     \
  --disable-shared                     \
  --enable-static                      \
  --enable-lto                         \
  --enable-tls                         \
  --enable-languages=c,c++,lto         \
  --enable-libgomp                     \
  --enable-threads=win32               \
  --enable-checking=release            \
  --enable-mingw-wildcard              \
  --enable-large-address-aware         \
  --enable-libstdcxx-threads           \
  --disable-libstdcxx-pch              \
  --disable-libstdcxx-verbose          \
  --disable-win32-registry             \
  --with-tune=intel                    \
  ${EXTRA_GCC_ARGS}                    \
  --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX}
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/mingw-w64-winpthreads && pushd ${BUILD}/mingw-w64-winpthreads
${SOURCE}/mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
  --prefix=${FINAL}/${TARGET}                                                   \
  --with-sysroot=${FINAL}/${TARGET}                                             \
  --host=${TARGET}                                                              \
  --disable-dependency-tracking                                                 \
  --disable-shared                                                              \
  --enable-static
make -j`nproc`
make install
popd

mkdir -p ${BUILD}/gdb && pushd ${BUILD}/gdb
${SOURCE}/gdb-${GDB_VERSION}/configure     \
  --prefix=${FINAL}                        \
  --host=${TARGET}                         \
  --enable-64-bit-bfd                      \
  --disable-werror                         \
  --disable-source-highlight               \
  --with-static-standard-libraries         \
  --with-libexpat-prefix=${PREFIX}         \
  --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX} \
  CFLAGS="-O2 -std=gnu17"                  \
  CXXFLAGS="-O2 -D_WIN32_WINNT=0x0600"
make -j`nproc`
cp gdb/.libs/gdb.exe gdbserver/gdbserver.exe ${FINAL}/bin/
popd

mkdir -p ${BUILD}/make && pushd ${BUILD}/make
${SOURCE}/make-${MAKE_VERSION}/configure \
  --prefix=${FINAL}                      \
  --host=${TARGET}                       \
  --disable-nls                          \
  --disable-rpath                        \
  --enable-case-insensitive-file-system  \
  CFLAGS="-O2 -std=gnu17"
make -j`nproc`
make install
popd

rm -rf ${FINAL}/bin/${TARGET}-*
rm -rf ${FINAL}/bin/ld.bfd.exe ${FINAL}/${TARGET}/bin/ld.bfd.exe
rm -rf ${FINAL}/lib/bfd-plugins/libdep.dll.a
rm -rf ${FINAL}/share

find ${FINAL} -name '*.exe' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.dll' -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.o'   -print0 | xargs -0 -n 8 -P 2 ${TARGET}-strip --strip-unneeded
find ${FINAL} -name '*.a'   -print0 | xargs -0 -n 8 -P `nproc` ${TARGET}-strip --strip-unneeded

rm ${FINAL}/mingw
7zr a -mx9 -mqs=on -mmt=on ${OUTPUT}/${NAME}.7z ${FINAL}

if [[ -v GITHUB_OUTPUT ]]; then
  echo "GCC_VERSION=${GCC_VERSION}"     >>${GITHUB_OUTPUT}
  echo "MINGW_VERSION=${MINGW_VERSION}" >>${GITHUB_OUTPUT}
  echo "GDB_VERSION=${GDB_VERSION}"     >>${GITHUB_OUTPUT}
  echo "MAKE_VERSION=${MAKE_VERSION}"   >>${GITHUB_OUTPUT}
fi
