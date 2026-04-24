#!/usr/bin/env bash

set -eu

declare -r workdir="${PWD}"

declare -r system_image='/tmp/dragonflybsd.iso'
declare -r system_image_compressed='/tmp/dragonflybsd.iso.bz2'
declare -r system_directory='/tmp/dragonflybsd'

declare -r triplet='x86_64-unknown-dragonfly'

declare -r sysroot_directory="${workdir}/${triplet}"
declare -r tarball_filename="${sysroot_directory}.tar.xz"

[ -d "${sysroot_directory}" ] || mkdir "${sysroot_directory}"

echo "- Generating sysroot for ${triplet}"

if [ -f "${tarball_filename}" ]; then
	echo "+ Already exists. Stop"
	exit '0'
fi

declare url='https://mirror-master.dragonflybsd.org/iso-images/dfly-x86_64-6.4.2_REL.iso.bz2'

echo "- Fetching data from ${url}"

curl \
	--url "${url}" \
	--retry '30' \
	--retry-all-errors \
	--retry-delay '0' \
	--retry-max-time '0' \
	--location \
	--silent \
	--output "${system_image_compressed}"

cd "$(dirname "${system_image_compressed}")"

bzip2 --decompress "${system_image_compressed}"

[ -d "${system_directory}" ] || mkdir "${system_directory}"

sudo mount -o loop,ro "${system_image}" "${system_directory}"

echo "- Unpacking ${system_image}"

cp --recursive "${system_directory}/lib" "${sysroot_directory}"
cp --recursive "${system_directory}/usr/lib" "${sysroot_directory}"
cp --recursive "${system_directory}/usr/include" "${sysroot_directory}"

sudo umount "${system_directory}"

unlink "${system_image}"

rm \
	--force \
	--recursive \
	"${sysroot_directory}/lib/gcc"* \
	"${sysroot_directory}/lib/debug" \
	"${sysroot_directory}/lib/i18n" \
	"${sysroot_directory}/lib/profile" \
	"${sysroot_directory}/lib/security" \
	"${sysroot_directory}/include/c++"

cd "${sysroot_directory}/lib"

find . -type l | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln --symbolic $(basename "$11") $(basename "$9")"}'  | bash

ln \
	--symbolic \
	--force \
	--relative \
	'./priv/lib'*'.so'* \
	'./'

echo "- Creating tarball at ${tarball_filename}"

tar --directory="$(dirname "${sysroot_directory}")" --create --file=- "$(basename "${sysroot_directory}")" | xz --threads='0' --extreme --compress -9 > "${tarball_filename}"
sha256sum "${tarball_filename}" | sed "s|$(dirname "${sysroot_directory}")/||" > "${tarball_filename}.sha256"
