package_version() {
	version=$(cat "$root/VERSION")
	case "$version" in
		''|*[!0-9A-Za-z.+~-]*)
			printf 'Invalid package version: %s\n' "$version" >&2
			return 1 ;;
	esac
}
