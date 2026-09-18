#define _POSIX_C_SOURCE 200809L

#include "ref_update.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "coverage.h"

static char *xstrdup(const char *s)
{
	char *copy = strdup(s);
	if (coverage_fail("GHE_TEST_REF_STRDUP_FAIL")) {
		free(copy);
		copy = NULL;
	}
	if (!copy) {
		perror("strdup");
		exit(1);
	}
	return copy;
}

static int is_zero_value(const char *value)
{
	size_t len = strlen(value);

	return (len == 40 || len == 64) && strspn(value, "0") == len;
}

static enum ref_kind classify_ref(const char *refname)
{
	if (strncmp(refname, "refs/heads/", 11) == 0)
		return REF_BRANCH;
	if (strncmp(refname, "refs/remotes/", 13) == 0)
		return REF_REMOTE_BRANCH;
	if (strncmp(refname, "refs/tags/", 10) == 0)
		return REF_TAG;
	if (strcmp(refname, "refs/stash") == 0)
		return REF_STASH;
	if (strncmp(refname, "refs/notes/", 11) == 0)
		return REF_NOTE;
	return REF_OTHER;
}

const char *short_refname(const char *refname)
{
	if (strncmp(refname, "refs/heads/", 11) == 0)
		return refname + 11;
	if (strncmp(refname, "refs/remotes/", 13) == 0)
		return refname + 13;
	if (strncmp(refname, "refs/tags/", 10) == 0)
		return refname + 10;
	if (strcmp(refname, "refs/stash") == 0)
		return "stash";
	if (strncmp(refname, "refs/notes/", 11) == 0)
		return refname + 11;
	return refname;
}

const char *ref_kind_name(enum ref_kind kind)
{
	switch (kind) {
	case REF_BRANCH:
		return "branch";
	case REF_REMOTE_BRANCH:
		return "remote-branch";
	case REF_TAG:
		return "tag";
	case REF_STASH:
		return "stash";
	case REF_NOTE:
		return "note";
	case REF_OTHER:
		break;
	}
	return "ref";
}

const char *ref_update_name(enum update_kind kind)
{
	switch (kind) {
	case UPDATE_CREATE:
		return "created";
	case UPDATE_DELETE:
		return "deleted";
	case UPDATE_UPDATE:
		return "updated";
	}
	return "updated";
}

static void updates_push(struct updates *updates, struct ref_update update)
{
	if (updates->len == updates->cap) {
		size_t new_cap = updates->cap ? updates->cap * 2 : 8;
		struct ref_update *new_items =
			realloc(updates->items, new_cap * sizeof(*new_items));
		if (coverage_fail("GHE_TEST_REALLOC_FAIL")) {
			free(new_items);
			new_items = NULL;
		}
		if (!new_items) {
			perror("realloc");
			exit(1);
		}
		updates->items = new_items;
		updates->cap = new_cap;
	}
	updates->items[updates->len++] = update;
}

void free_updates(struct updates *updates)
{
	size_t i;

	for (i = 0; i < updates->len; i++) {
		free(updates->items[i].old_value);
		free(updates->items[i].new_value);
		free(updates->items[i].refname);
	}
	free(updates->items);
}

static int parse_line(char *line, struct ref_update *out)
{
	char *old_value;
	char *new_value;
	char *refname;
	char *end;
	char *first_space;
	char *second_space;

	end = strchr(line, '\n');
	if (end)
		*end = '\0';

	first_space = strchr(line, ' ');
	if (!first_space || first_space == line)
		return -1;
	*first_space = '\0';

	second_space = strchr(first_space + 1, ' ');
	if (!second_space || second_space == first_space + 1 ||
	    second_space[1] == '\0')
		return -1;
	*second_space = '\0';

	old_value = line;
	new_value = first_space + 1;
	refname = second_space + 1;
	if (strpbrk(old_value, "\t\r") || strpbrk(new_value, "\t\r") ||
	    strpbrk(refname, " \t\r"))
		return -1;

	out->old_value = xstrdup(old_value);
	out->new_value = xstrdup(new_value);
	out->refname = xstrdup(refname);
	out->ref_kind = classify_ref(refname);
	out->consumed = false;

	if (is_zero_value(old_value) && !is_zero_value(new_value))
		out->update_kind = UPDATE_CREATE;
	else if (!is_zero_value(old_value) && is_zero_value(new_value))
		out->update_kind = UPDATE_DELETE;
	else
		out->update_kind = UPDATE_UPDATE;

	return 0;
}

int read_updates(struct updates *updates)
{
	char *line = NULL;
	size_t line_cap = 0;
	ssize_t nread;
	int status = 0;

	while ((nread = getline(&line, &line_cap, stdin)) != -1) {
		struct ref_update update;

		if (memchr(line, '\0', (size_t)nread) || parse_line(line, &update) < 0) {
			fprintf(stderr, "git-hooks-ext: invalid reference-transaction input\n");
			status = 1;
			break;
		}
		updates_push(updates, update);
	}

	free(line);
	if (coverage_fail("GHE_TEST_STDIN_ERROR") || ferror(stdin)) {
		perror("stdin");
		return 1;
	}
	return status;
}
