#include "ref_events.h"

#include "git_runner.h"

#include <stdio.h>
#include <string.h>

static void event_name(char *buf, size_t buf_len, enum ref_kind kind,
		       const char *action)
{
	snprintf(buf, buf_len, "%s-%s", ref_kind_name(kind), action);
}

static int emit_rename(bool dry_run, struct ref_update *deleted,
		       struct ref_update *created)
{
	char event[128];
	const char *args[5];

	event_name(event, sizeof(event), deleted->ref_kind, "renamed");
	args[0] = short_refname(deleted->refname);
	args[1] = short_refname(created->refname);
	args[2] = deleted->refname;
	args[3] = created->refname;
	args[4] = created->new_value;

	deleted->consumed = true;
	created->consumed = true;
	return emit_hook_event(dry_run, event, 5, args);
}

static int emit_update(bool dry_run, struct ref_update *update)
{
	char event[128];
	const char *args[4];

	event_name(event, sizeof(event), update->ref_kind,
		   ref_update_name(update->update_kind));
	args[0] = short_refname(update->refname);
	args[1] = update->refname;
	args[2] = update->old_value;
	args[3] = update->new_value;

	update->consumed = true;
	return emit_hook_event(dry_run, event, 4, args);
}

static struct ref_update *unique_rename_target(struct updates *updates,
					       struct ref_update *deleted)
{
	struct ref_update *match = NULL;
	size_t j;

	for (j = 0; j < updates->len; j++) {
		struct ref_update *created = &updates->items[j];

		if (created->consumed || created->ref_kind != deleted->ref_kind)
			continue;

		if (created != deleted && created->update_kind == UPDATE_DELETE &&
		    strcmp(deleted->old_value, created->old_value) == 0)
			return NULL;

		if (created->update_kind != UPDATE_CREATE)
			continue;

		if (strcmp(deleted->old_value, created->new_value) != 0)
			continue;

		if (match)
			return NULL;
		match = created;
	}
	return match;
}

int process_ref_events(struct updates *updates, bool dry_run)
{
	size_t i;
	int status = 0;

	for (i = 0; i < updates->len; i++) {
		struct ref_update *deleted = &updates->items[i];

		if (deleted->consumed || deleted->update_kind != UPDATE_DELETE ||
		    deleted->ref_kind == REF_OTHER)
			continue;

		struct ref_update *created = unique_rename_target(updates, deleted);
		if (created) {
			status = emit_rename(dry_run, deleted, created);
			if (status)
				return status;
		}
	}

	for (i = 0; i < updates->len; i++) {
		struct ref_update *update = &updates->items[i];

		if (update->consumed || update->ref_kind == REF_OTHER)
			continue;
		status = emit_update(dry_run, update);
		if (status)
			return status;
	}

	return 0;
}
