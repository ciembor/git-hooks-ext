#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
. "$root/packaging/common.sh"
package_version
image=${DEBIAN_TEST_IMAGE:-localhost/git-hooks-ext-debian-test:bookworm}
release_url=${RELEASE_URL:-https://github.com/ciembor/git-hooks-ext/releases/download/v$version}
podman run --rm -i --entrypoint /bin/sh \
	-e "RELEASE_URL=$release_url" -e "VERSION=$version" "$image" -s <<'SH'
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl
mkdir /download
cd /download
arch=$(dpkg --print-architecture)
curl --fail --location --retry 3 -O "$RELEASE_URL/git-hooks-ext_${VERSION}-1_${arch}.deb"
curl --fail --location --retry 3 -O "$RELEASE_URL/SHA256SUMS"
sha256sum --check --ignore-missing SHA256SUMS
PACKAGE_DIR=/download /bin/sh /checks/apt-install.sh
SH
