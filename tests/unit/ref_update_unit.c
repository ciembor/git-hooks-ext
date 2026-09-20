#define _POSIX_C_SOURCE 200809L

#include "../../src/ref_update.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uintptr_t allocations[7];
static bool released[7];
static size_t allocation_count;
static bool unexpected_free;

static void *record_allocation(void *ptr)
{
	if (!ptr)
		exit(1);
	allocations[allocation_count++] = (uintptr_t)ptr;
	return ptr;
}

/* Only ref_update.c is compiled with free redirected to this function. */
void ghe_test_free(void *ptr)
{
	size_t i;

	for (i = 0; i < allocation_count; i++) {
		if (allocations[i] == (uintptr_t)ptr) {
			unexpected_free = unexpected_free || released[i];
			released[i] = true;
			break;
		}
	}
	if (ptr && i == allocation_count)
		unexpected_free = true;
	free(ptr);
}

static int test_free_updates(void)
{
	struct updates updates = { 0 };
	size_t i;

	updates.len = 2;
	updates.cap = 2;
	updates.items = record_allocation(calloc(updates.cap, sizeof(*updates.items)));
	for (i = 0; i < updates.len; i++) {
		updates.items[i].old_value = record_allocation(strdup("old"));
		updates.items[i].new_value = record_allocation(strdup("new"));
		updates.items[i].refname = record_allocation(strdup("refs/heads/topic"));
	}

	free_updates(&updates);
	for (i = 0; i < allocation_count; i++) {
		if (!released[i]) {
			fprintf(stderr, "free_updates: allocation %zu was not released\n", i);
			return 1;
		}
	}
	return unexpected_free ? 1 : 0;
}

int main(void)
{
	if (strcmp(short_refname("refs/other/value"), "other/value") != 0)
		return 1;
	if (strcmp(short_refname("main-worktree/"), "main-worktree/") != 0)
		return 1;
	if (strcmp(ref_kind_name(REF_OTHER), "ref") != 0)
		return 1;
	if (!ref_kind_supports_rename(REF_BRANCH) ||
	    !ref_kind_supports_rename(REF_REMOTE_BRANCH) ||
	    !ref_kind_supports_rename(REF_TAG) ||
	    !ref_kind_supports_rename(REF_NOTE) ||
	    ref_kind_supports_rename(REF_GENERIC))
		return 1;
	if (!ref_value_is_symbolic("ref:refs/heads/main") ||
	    ref_value_is_symbolic("ref:") || ref_value_is_symbolic("object"))
		return 1;
	if (!ref_value_is_zero("0000000000000000000000000000000000000000") ||
	    !ref_value_is_zero("0000000000000000000000000000000000000000000000000000000000000000") ||
	    ref_value_is_zero("0000000000000000000000000000000000000001") ||
	    ref_value_is_zero("0000"))
		return 1;
	if (strcmp(ref_update_name((enum update_kind)42), "updated") != 0)
		return 1;
	return test_free_updates();
}
