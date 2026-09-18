#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
family=${1:?Specify fedora, arch or alpine}
case "$family" in fedora|arch|alpine) ;; *) exit 2 ;; esac
podman info >/dev/null
dist=${DIST_DIR:-$root/dist/$family}
mkdir -p "$dist"
dist=$(CDPATH= cd "$dist" && pwd)
image="localhost/git-hooks-ext-$family-test"
podman build -f "$root/packaging/$family/Containerfile" -t "$image" "$root"
container="git-hooks-ext-$family-test-$$"
if podman container exists "$container"; then exit 1; fi
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
