#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
. "$root/packaging/common.sh"
package_version
base=${1:?Specify a Debian or Ubuntu image}
podman run --rm -i --entrypoint /bin/sh \
  -v "$root/tests/packages:/checks:ro" -e "VERSION=$version" "$base" -s <<'SH'
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
mkdir /packages
cd /packages
url="https://github.com/ciembor/git-hooks-ext/releases/download/v$VERSION"
curl -fL --retry 3 -O "$url/git-hooks-ext_${VERSION}-1_$(dpkg --print-architecture).deb"
curl -fL --retry 3 -O "$url/SHA256SUMS"
sha256sum --check --ignore-missing SHA256SUMS
/bin/sh /checks/apt-install.sh
SH
