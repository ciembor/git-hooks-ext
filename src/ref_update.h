#ifndef GIT_HOOKS_EXT_REF_UPDATE_H
#define GIT_HOOKS_EXT_REF_UPDATE_H

#include <stdbool.h>
#include <stddef.h>

enum ref_kind {
	REF_BRANCH,
	REF_REMOTE_BRANCH,
	REF_TAG,
	REF_STASH,
	REF_NOTE,
	REF_OTHER
};

enum update_kind {
	UPDATE_CREATE,
	UPDATE_DELETE,
	UPDATE_UPDATE
};

struct ref_update {
	char *old_value;
	char *new_value;
	char *refname;
	enum ref_kind ref_kind;
	enum update_kind update_kind;
	bool consumed;
};

struct updates {
	struct ref_update *items;
	size_t len;
	size_t cap;
};

int read_updates(struct updates *updates);
void free_updates(struct updates *updates);

const char *ref_kind_name(enum ref_kind kind);
const char *ref_update_name(enum update_kind kind);
const char *short_refname(const char *refname);

#endif
