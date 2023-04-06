#!/bin/bash

set -e
set -u

declare -r revision="$(git rev-parse --short HEAD)"

declare -r toolchain_tarball="${PWD}/dragonfly-cross.tar.xz"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.40'

declare -r gcc_tarball='/tmp/gcc.tar.xz'
declare -r gcc_directory='/tmp/gcc-12.2.0'

declare -r system_image='/tmp/dragonflybsd.iso'
declare -r system_image_compressed='/tmp/dragonflybsd.iso.bz2'
declare -r system_directory='/tmp/dragonflybsd'

declare -r triple='x86_64-unknown-dragonfly'

declare -r cflags='-Os -s -DNDEBUG'

declare -r toolchain_directory="/tmp/unknown-unknown-dragonfly"

wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output-document="${mpfr_tarball}"
tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz' --output-document="${binutils_tarball}"
tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz' --output-document="${gcc_tarball}"
tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"

wget --no-verbose 'https://mirror-master.dragonflybsd.org/iso-images/dfly-x86_64-5.0.0_REL.iso.bz2'  --output-document="${system_image_compressed}"

pushd "$(dirname "${system_image_compressed}")"

bzip2 --decompress "${system_image_compressed}"

pushd

[ -d "${system_directory}" ] || mkdir "${system_directory}"

sudo mount -o loop "${system_image}" "${system_directory}"

[ -d "${toolchain_directory}/${triple}" ] || mkdir --parent "${toolchain_directory}/${triple}"

cp --recursive "${system_directory}/lib" "${toolchain_directory}/${triple}"
cp --recursive "${system_directory}/usr/lib" "${toolchain_directory}/${triple}"
cp --recursive "${system_directory}/usr/include" "${toolchain_directory}/${triple}"

sudo umount "${system_directory}"

pushd "${toolchain_directory}/${triple}/lib"

find . -xtype l | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln -s $(basename "$11") $(basename "$9")"}'  | bash

pushd

while read file; do
	sed -i "s/-O2/${cflags}/g" "${file}"
done <<< "$(find '/tmp' -type 'f' -regex '.*configure')"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

cd "${binutils_directory}/build"
rm --force --recursive ./*

../configure \
	--target="${triple}" \
	--prefix="${toolchain_directory}" \
	--enable-gold \
	--enable-ld

make all --jobs="$(nproc)"
make install

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

cd "${gcc_directory}/build"
rm --force --recursive ./*

../configure \
	--target="${triple}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--with-mpc="${toolchain_directory}" \
	--with-mpfr="${toolchain_directory}" \
	--with-system-zlib \
	--with-bugurl='https://github.com/AmanoTeam/dr4g0nflybsdcr0ss/issues' \
	--enable-__cxa_atexit \
	--enable-cet='auto' \
	--enable-checking='release' \
	--enable-default-ssp \
	--enable-gnu-indirect-function \
	--enable-gnu-unique-object \
	--enable-libstdcxx-backtrace \
	--enable-link-serialization='1' \
	--enable-linker-build-id \
	--enable-lto \
	--disable-multilib \
	--enable-plugin \
	--enable-shared \
	--enable-threads='posix' \
	--enable-libssp \
	--disable-libstdcxx-pch \
	--disable-werror \
	--enable-languages='c,c++' \
	--disable-libgomp \
	--disable-bootstrap \
	--without-headers \
	--enable-ld \
	--enable-gold \
	--with-pic \
	--with-gcc-major-version-only \
	--with-pkgversion="dr4g0nflybsdcr0ss v0.1-${revision}" \
	--with-sysroot="${toolchain_directory}/${triple}" \
	--with-native-system-header-dir='/include'

LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make CFLAGS_FOR_TARGET="${cflags} -fno-stack-protector" CXXFLAGS_FOR_TARGET="${cflags} -fno-stack-protector" all --jobs="$(nproc)"
make install

rm --recursive "${toolchain_directory}/lib/gcc/${triple}/12/include-fixed"

tar --directory="$(dirname "${toolchain_directory}")" --create --file=- "$(basename "${toolchain_directory}")" |  xz --threads=0 --compress -9 > "${toolchain_tarball}"
