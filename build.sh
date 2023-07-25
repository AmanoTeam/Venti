#!/bin/bash

set -eu

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.40'

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-master'

declare -r system_image='/tmp/dragonflybsd.iso'
declare -r system_image_compressed='/tmp/dragonflybsd.iso.bz2'
declare -r system_directory='/tmp/dragonflybsd'

declare -r triplet='x86_64-unknown-dragonfly'

declare -r optflags='-Os'
declare -r linkflags='-Wl,-s'

declare -r max_jobs="$(($(nproc) * 12))"

source "./submodules/obggcc/toolchains/${1}.sh"

declare -r toolchain_directory="/tmp/venti"

wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output-document="${mpfr_tarball}"
tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz' --output-document="${binutils_tarball}"
tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"

wget --no-verbose 'https://codeload.github.com/gcc-mirror/gcc/tar.gz/refs/heads/master' --output-document="${gcc_tarball}"
tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"

wget --no-verbose 'https://mirror-master.dragonflybsd.org/iso-images/dfly-x86_64-5.0.0_REL.iso.bz2'  --output-document="${system_image_compressed}"

pushd "$(dirname "${system_image_compressed}")"

bzip2 --decompress "${system_image_compressed}"

pushd

[ -d "${system_directory}" ] || mkdir "${system_directory}"

sudo mount -o loop "${system_image}" "${system_directory}"

[ -d "${toolchain_directory}/${triplet}" ] || mkdir --parent "${toolchain_directory}/${triplet}"

cp --recursive "${system_directory}/lib" "${toolchain_directory}/${triplet}"
cp --recursive "${system_directory}/usr/lib" "${toolchain_directory}/${triplet}"
cp --recursive "${system_directory}/usr/include" "${toolchain_directory}/${triplet}"

sudo umount "${system_directory}"

pushd "${toolchain_directory}/${triplet}/lib"

find . -type l | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln -s $(basename "$11") $(basename "$9")"}'  | bash

pushd

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

cd "${binutils_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--target="${triplet}" \
	--prefix="${toolchain_directory}" \
	--enable-gold \
	--enable-ld \
	--enable-lto \
	--disable-gprofng \
	--with-static-standard-libraries \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs="${max_jobs}"
make install

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

cd "${gcc_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--target="${triplet}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--with-mpc="${toolchain_directory}" \
	--with-mpfr="${toolchain_directory}" \
	--with-bugurl='https://github.com/AmanoTeam/Venti/issues' \
	--with-gcc-major-version-only \
	--with-pkgversion="Venti v0.3-${revision}" \
	--with-sysroot="${toolchain_directory}/${triplet}" \
	--with-native-system-header-dir='/include' \
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
	--enable-plugin \
	--enable-shared \
	--enable-threads='posix' \
	--enable-libssp \
	--enable-languages='c,c++' \
	--enable-ld \
	--enable-gold \
	--disable-libstdcxx-pch \
	--disable-werror \
	--disable-libgomp \
	--disable-bootstrap \
	--disable-multilib \
	--disable-nls \
	--without-headers \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="-Wl,-rpath-link,${OBGGCC_TOOLCHAIN}/${CROSS_COMPILE_TRIPLET}/lib ${linkflags}"

LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
	CFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	all --jobs="${max_jobs}"
make install

cd "${toolchain_directory}/${triplet}/bin"

for name in *; do
	rm "${name}"
	ln -s "../../bin/${triplet}-${name}" "${name}"
done

rm --recursive "${toolchain_directory}/share"
rm --recursive "${toolchain_directory}/lib/gcc/${triplet}/"*"/include-fixed"

patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
