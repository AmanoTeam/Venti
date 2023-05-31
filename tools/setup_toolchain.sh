#!/bin/bash

set -eu

declare -r VENTI_HOME='/tmp/venti-toolchain'

if [ -d "${VENTI_HOME}" ]; then
	PATH+=":${VENTI_HOME}/bin"
	export VENTI_HOME \
		PATH
	return 0
fi

declare -r VENTI_CROSS_TAG="$(jq --raw-output '.tag_name' <<< "$(curl --retry 10 --retry-delay 3 --silent --url 'https://api.github.com/repos/AmanoTeam/Venti/releases/latest')")"
declare -r VENTI_CROSS_TARBALL='/tmp/venti.tar.xz'
declare -r VENTI_CROSS_URL="https://github.com/AmanoTeam/Venti/releases/download/${VENTI_CROSS_TAG}/x86_64-linux-gnu.tar.xz"

curl --retry 10 --retry-delay 3 --silent --location --url "${VENTI_CROSS_URL}" --output "${VENTI_CROSS_TARBALL}"
tar --directory="$(dirname "${VENTI_CROSS_TARBALL}")" --extract --file="${VENTI_CROSS_TARBALL}"

rm "${VENTI_CROSS_TARBALL}"

mv '/tmp/unknown-unknown-dragonfly' "${VENTI_HOME}"

PATH+=":${VENTI_HOME}/bin"

export VENTI_HOME \
	PATH
