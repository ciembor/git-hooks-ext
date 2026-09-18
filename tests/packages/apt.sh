#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
command -v podman >/dev/null 2>&1 || {
	printf 'Install Podman; on macOS also initialize/start podman machine.\n' >&2
	exit 1
}
podman info >/dev/null
dist=${DIST_DIR:-$root/dist/debian}
mkdir -p "$dist"
dist=$(CDPATH= cd "$dist" && pwd)
image=${DEBIAN_TEST_IMAGE:-localhost/git-hooks-ext-debian-test:bookworm}
podman build -f "$root/packaging/debian/Containerfile" -t "$image" "$root"
container="git-hooks-ext-apt-test-$$"
if podman container exists "$container"; then
	printf 'Test container already exists: %s\n' "$container" >&2
	exit 1
fi
cleanup() {
	status=$?
	trap - EXIT
	if podman container exists "$container"; then
		podman rm -f "$container" || status=1
	fi
	exit "$status"
}
trap cleanup EXIT
podman run --name "$container" "$image"
podman cp "$container:/packages/." "$dist"
podman rm "$container"
