#!/bin/sh
set -eu

case "$PACKAGE_FAMILY" in
  fedora)
    set -- /packages/git-hooks-ext-*.rpm
    for package do
      case "$package" in *.src.rpm) continue ;; esac
      dnf install -y "$package"
    done
    ;;
  arch) pacman -U --noconfirm /packages/*.pkg.tar.zst ;;
  alpine) apk add --no-cache --allow-untrusted /packages/git-hooks-ext-*.apk ;;
  *) printf 'Unknown package family\n' >&2; exit 1 ;;
esac
version=$(/usr/bin/git-hooks-ext --version)
version=${version#git-hooks-ext }
/bin/sh /checks/smoke.sh /usr/bin/git-hooks-ext "$version"
case "$PACKAGE_FAMILY" in
  fedora) dnf remove -y git-hooks-ext; ! rpm -q git-hooks-ext ;;
  arch) pacman -R --noconfirm git-hooks-ext; ! pacman -Q git-hooks-ext ;;
  alpine) apk del git-hooks-ext; ! apk info -e git-hooks-ext ;;
esac
test ! -e /usr/bin/git-hooks-ext
printf '%s install, hooks and removal passed.\n' "$PACKAGE_FAMILY"
