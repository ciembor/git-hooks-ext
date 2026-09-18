test_ref_update_cleanup() {
	"$ref_update_unit"
}

test_runtime_helpers() {
	"$runtime_unit"
}

register_unit_tests() {
	test_expect_success "releases every reference update allocation" test_ref_update_cleanup
	test_expect_success "reads long process output and builds shell commands" test_runtime_helpers
}
