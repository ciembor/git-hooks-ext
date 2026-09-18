#!/bin/sh
set -eu

test_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_root=$(CDPATH= cd "$test_root/.." && pwd)
runner="$test_root/run.sh"

bin=${GIT_HOOKS_EXT_BIN:-$project_root/git-hooks-ext}
ref_update_unit=${GIT_HOOKS_EXT_REF_UPDATE_UNIT:-$test_root/.build/ref_update_unit}
runtime_unit=${GIT_HOOKS_EXT_RUNTIME_UNIT:-$test_root/.build/runtime_unit}

. "$test_root/lib/harness.sh"
. "$test_root/lib/assertions.sh"
. "$test_root/lib/fixtures.sh"
. "$test_root/harness.sh"
. "$test_root/unit/run.sh"
for suite in "$test_root"/integration/*.sh; do
	. "$suite"
done

if test "${1:-}" = --run-test; then
	test "$#" -eq 3 || exit 2
	TEST_DIR=$3
	"$2"
	exit 0
fi
test "$#" -eq 0 || exit 2

tmp=$(mktemp -d "${TMPDIR:-/tmp}/git-hooks-ext-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

register_harness_tests
register_unit_tests
register_ref_events_tests
register_cli_tests
register_install_tests
register_hook_runner_tests
register_coverage_tests
test_finish
