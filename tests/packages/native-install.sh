#!/bin/sh
set -eu

case "$PACKAGE_FAMILY" in
  fedora)
    set -- /packages/git-hooks-ext-[0-9]*.rpm
    for package do
      case "$package" in *.src.rpm) continue ;; esac
      dnf install -y "$package"
    done
    ;;
  arch) pacman -U --noconfirm /packages/git-hooks-ext-[0-9]*.pkg.tar.zst ;;
  alpine) apk add --no-cache --allow-untrusted /packages/git-hooks-ext-*.apk ;;
  *) printf 'Unknown package family\n' >&2; exit 1 ;;
esac
/bin/sh /checks/smoke.sh /usr/bin/git-hooks-ext "${PACKAGE_VERSION:?Expected package version required}"
case "$PACKAGE_FAMILY" in
  fedora)
    dnf remove -y git-hooks-ext
    if rpm -q git-hooks-ext; then exit 1; fi
    ;;
  arch)
    pacman -R --noconfirm git-hooks-ext
    if pacman -Q git-hooks-ext; then exit 1; fi
    ;;
  alpine)
    apk del git-hooks-ext
    if apk info -e git-hooks-ext; then exit 1; fi
    ;;
esac
test ! -e /usr/bin/git-hooks-ext
printf '%s install, hooks and removal passed.\n' "$PACKAGE_FAMILY"
