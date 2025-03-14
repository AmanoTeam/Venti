#!/bin/bash

set -eu

declare -r workdir="${PWD}"

declare -r toolchain_directory='/tmp/venti'
declare -r share_directory="${toolchain_directory}/usr/local/share/venti"

declare -r environment="LD_LIBRARY_PATH=${toolchain_directory}/lib PATH=${PATH}:${toolchain_directory}/bin"

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.3.0'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.1'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r isl_tarball='/tmp/isl.tar.xz'
declare -r isl_directory='/tmp/isl-0.27'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-with-gold-2.44'

declare -r gcc_tarball='/tmp/gcc.tar.xz'
declare -r gcc_directory='/tmp/gcc-master'

declare -r triplet='x86_64-unknown-dragonfly'
declare -r sysroot_url="https://github.com/AmanoTeam/dragonfly-sysroot/releases/latest/download/${triplet}.tar.xz"

declare -r max_jobs='40'

# declare -r optlto="-flto=${max_jobs} -fno-fat-lto-objects"
# declare -r optfatlto="-flto=${max_jobs} -ffat-lto-objects"

declare -r optlto=""
declare -r optfatlto=""

declare -r pieflags='-fPIE'
declare -r optflags='-w -O2'
declare -r linkflags='-Wl,-s'

declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

set +u

if [ -z "${CROSS_COMPILE_TRIPLET}" ]; then
	declare CROSS_COMPILE_TRIPLET=''
fi

set -u

if ! [ -f "${gmp_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gmp_tarball}"
	
	tar \
		--directory="$(dirname "${gmp_directory}")" \
		--extract \
		--file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${mpfr_tarball}"
	
	tar \
		--directory="$(dirname "${mpfr_directory}")" \
		--extract \
		--file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${mpc_tarball}"
	
	tar \
		--directory="$(dirname "${mpc_directory}")" \
		--extract \
		--file="${mpc_tarball}"
fi

if ! [ -f "${isl_tarball}" ]; then
	curl \
		--url 'https://libisl.sourceforge.io/isl-0.27.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${isl_tarball}"
	
	tar \
		--directory="$(dirname "${isl_directory}")" \
		--extract \
		--file="${isl_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	curl \
		--url 'https://ftp.gnu.org/gnu/binutils/binutils-with-gold-2.44.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${binutils_tarball}"
	
	tar \
		--directory="$(dirname "${binutils_directory}")" \
		--extract \
		--file="${binutils_tarball}"
	
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-gold-Use-char16_t-char32_t-instead-of-uint16_.patch"
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Disable-annoying-linker-warnings.patch"
fi

if ! [ -f "${gcc_tarball}" ]; then
	curl \
		--url 'https://github.com/gcc-mirror/gcc/archive/refs/heads/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gcc_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_directory}")" \
		--extract \
		--file="${gcc_tarball}"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Fix-libgcc-build-on-arm.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Change-the-default-language-version-for-C-compilatio.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wimplicit-int-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wint-conversion-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-GCC-change-about-turning-Wimplicit-function-d.patch"
fi

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${optflags} ${optlto}" \
	CXXFLAGS="${optflags} ${optlto}" \
	LDFLAGS="${linkflags} ${optlto}"

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
	CFLAGS="${optflags} ${optlto}" \
	CXXFLAGS="${optflags} ${optlto}" \
	LDFLAGS="${linkflags} ${optlto}"

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
	CFLAGS="${optflags} ${optlto}" \
	CXXFLAGS="${optflags} ${optlto}" \
	LDFLAGS="${linkflags} ${optlto}"

make all --jobs
make install

[ -d "${isl_directory}/build" ] || mkdir "${isl_directory}/build"

cd "${isl_directory}/build"
rm --force --recursive ./*

../configure \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${toolchain_directory}" \
	--with-gmp-prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	CFLAGS="${pieflags} ${optflags}" \
	CXXFLAGS="${pieflags} ${optflags}" \
	LDFLAGS="-Wl,-rpath-link -Wl,${toolchain_directory}/lib ${linkflags}"

make all --jobs
make install

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
	--with-sysroot="${toolchain_directory}/${triplet}" \
	CFLAGS="${optflags} ${optlto}" \
	CXXFLAGS="${optflags} ${optlto}" \
	LDFLAGS="${linkflags} ${optlto}"

make all --jobs="${max_jobs}"
make install

cd "$(mktemp --directory)"

declare sysroot_file="${PWD}/${triplet}.tar.xz"
declare sysroot_directory="${PWD}/${triplet}"

curl \
	--url "${sysroot_url}" \
	--retry '30' \
	--retry-all-errors \
	--retry-delay '0' \
	--retry-max-time '0' \
	--location \
	--silent \
	--output "${sysroot_file}"

tar \
	--extract \
	--file="${sysroot_file}"

cp --recursive "${sysroot_directory}" "${toolchain_directory}"

rm --force --recursive "${PWD}"

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
	--with-isl="${toolchain_directory}" \
	--with-bugurl='https://github.com/AmanoTeam/Venti/issues' \
	--with-gcc-major-version-only \
	--with-pkgversion="Venti v0.7-${revision}" \
	--with-sysroot="${toolchain_directory}/${triplet}" \
	--with-native-system-header-dir='/include' \
	--with-default-libstdcxx-abi='new' \
	--includedir="${toolchain_directory}/${triplet}/include" \
	--enable-__cxa_atexit \
	--enable-cet='auto' \
	--enable-checking='release' \
	--enable-default-pie \
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
	--enable-libstdcxx-time='yes' \
	--disable-libsanitizer \
	--disable-fixincludes \
	--disable-libstdcxx-pch \
	--disable-werror \
	--disable-libgomp \
	--disable-bootstrap \
	--disable-multilib \
	--disable-nls \
	--without-headers \
	CFLAGS="${optflags} ${optfatlto}" \
	CXXFLAGS="${optflags} ${optfatlto}" \
	LDFLAGS="${linkflags} ${optfatlto}"

declare args=''

if (( is_native )); then
	args+="${environment}"
fi

env ${args} make \
	CFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
	all --jobs="${max_jobs}"
make install

cd "${toolchain_directory}/${triplet}/bin"

patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"

mkdir --parent "${share_directory}"

cp --recursive "${workdir}/tools/dev/"* "${share_directory}"
