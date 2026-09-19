#define _POSIX_C_SOURCE 200809L

#include "worktree.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "coverage.h"
#include "git_runner.h"
#include "process.h"

struct worktree {
	char *path;
	char *head;
	char *branch;
	char *lock_reason;
	bool locked;
	bool matched;
};

struct worktrees {
	struct worktree *items;
	size_t len;
	size_t capacity;
};

static void free_worktree(struct worktree *worktree)
{
	free(worktree->path);
	free(worktree->head);
	free(worktree->branch);
	free(worktree->lock_reason);
}

static void free_worktrees(struct worktrees *worktrees)
{
	size_t i;

	for (i = 0; i < worktrees->len; i++)
		free_worktree(&worktrees->items[i]);
	free(worktrees->items);
	memset(worktrees, 0, sizeof(*worktrees));
}

static char *worktree_strndup(const char *value, size_t len)
{
	char *copy = strndup(value, len);

	if (coverage_fail("GHE_TEST_WORKTREE_STRNDUP_FAIL")) {
		free(copy);
		copy = NULL;
	}
	if (!copy) {
		perror("strndup");
		exit(1);
	}
	return copy;
}

static void set_field(char **field, const char *value, size_t len)
{
	char *copy = worktree_strndup(value, len);

	free(*field);
	*field = copy;
}

static void finish_worktree(struct worktrees *worktrees,
			    struct worktree *worktree)
{
	struct worktree *grown;

	if (!worktree->path)
		return;
	if (!worktree->head)
		set_field(&worktree->head, "", 0);
	if (!worktree->branch)
		set_field(&worktree->branch, "", 0);
	if (!worktree->lock_reason)
		set_field(&worktree->lock_reason, "", 0);
	if (worktrees->len == worktrees->capacity) {
		size_t capacity = worktrees->capacity ? worktrees->capacity * 2 : 4;

		grown = realloc(worktrees->items, capacity * sizeof(*grown));
		if (coverage_fail("GHE_TEST_WORKTREE_REALLOC_FAIL")) {
			free(grown);
			grown = NULL;
		}
		if (!grown) {
			perror("realloc");
			exit(1);
		}
		worktrees->items = grown;
		worktrees->capacity = capacity;
	}
	worktrees->items[worktrees->len++] = *worktree;
	memset(worktree, 0, sizeof(*worktree));
}

static bool token_has_value(const char *token, const char *prefix)
{
	size_t prefix_len = strlen(prefix);

	return strncmp(token, prefix, prefix_len) == 0 && token[prefix_len] != '\0';
}

static int parse_worktrees(char *data, size_t data_len,
			   struct worktrees *worktrees)
{
	struct worktree current = { 0 };
	char *cursor = data;
	char *end = data + data_len;

	while (cursor < end) {
		char *nul = memchr(cursor, '\0', (size_t)(end - cursor));
		size_t token_len;

		if (!nul) {
			fprintf(stderr, "git-hooks-ext: invalid worktree list output\n");
			free_worktree(&current);
			return 1;
		}
		token_len = (size_t)(nul - cursor);
		if (token_len == 0) {
			finish_worktree(worktrees, &current);
		} else if (strcmp(cursor, "worktree ") == 0) {
			fprintf(stderr, "git-hooks-ext: invalid worktree list output\n");
			free_worktree(&current);
			return 1;
		} else if (token_has_value(cursor, "worktree ")) {
			if (current.path) {
				fprintf(stderr, "git-hooks-ext: invalid worktree list output\n");
				free_worktree(&current);
				return 1;
			}
			set_field(&current.path, cursor + 9, token_len - 9);
		} else if (token_has_value(cursor, "HEAD ")) {
			set_field(&current.head, cursor + 5, token_len - 5);
		} else if (token_has_value(cursor, "branch ")) {
			set_field(&current.branch, cursor + 7, token_len - 7);
		} else if (token_len == 6 && memcmp(cursor, "locked", 6) == 0) {
			current.locked = true;
			set_field(&current.lock_reason, "", 0);
		} else if (token_has_value(cursor, "locked ")) {
			const char *reason = cursor + 7;
			size_t reason_len = token_len - 7;

			current.locked = true;
			set_field(&current.lock_reason, reason, reason_len);
		}
		cursor = nul + 1;
	}
	if (current.path)
		finish_worktree(worktrees, &current);
	free_worktree(&current);
	return 0;
}

static int load_worktrees(struct worktrees *worktrees)
{
	char *output;
	size_t output_len;
	int status;

	if (process_read_all("git worktree list --porcelain -z", &output,
			     &output_len)) {
		fprintf(stderr, "git-hooks-ext: failed to list worktrees\n");
		return 1;
	}
	status = parse_worktrees(output, output_len, worktrees);
	free(output);
	if (status)
		free_worktrees(worktrees);
	return status;
}

static struct worktree *find_path(struct worktrees *worktrees,
				  const char *path)
{
	size_t i;

	for (i = 0; i < worktrees->len; i++) {
		if (strcmp(worktrees->items[i].path, path) == 0)
			return &worktrees->items[i];
	}
	return NULL;
}

static bool same_identity(const struct worktree *left,
			  const struct worktree *right)
{
	return strcmp(left->head, right->head) == 0 &&
	       strcmp(left->branch, right->branch) == 0;
}

static int emit_entry(const char *event, const struct worktree *worktree)
{
	const char *args[] = {
		worktree->path, worktree->head, worktree->branch
	};

	return emit_hook_event(false, event, 3, args);
}

static int emit_added(struct worktrees *before, struct worktrees *after)
{
	size_t i;

	for (i = 0; i < after->len; i++) {
		struct worktree *item = &after->items[i];
		int status;

		if (find_path(before, item->path))
			continue;
		status = emit_entry("worktree-created", item);
		if (status)
			return status;
		if (item->locked) {
			const char *args[] = { item->path, item->lock_reason };

			status = emit_hook_event(false, "worktree-locked", 2, args);
			if (status)
				return status;
		}
	}
	return 0;
}

static int emit_removed(const char *event, struct worktrees *before,
			struct worktrees *after)
{
	size_t i;

	for (i = 0; i < before->len; i++) {
		struct worktree *item = &before->items[i];
		int status;

		if (find_path(after, item->path))
			continue;
		status = emit_entry(event, item);
		if (status)
			return status;
	}
	return 0;
}

static int emit_lock_changes(struct worktrees *before,
			     struct worktrees *after)
{
	size_t i;

	for (i = 0; i < before->len; i++) {
		struct worktree *old = &before->items[i];
		struct worktree *new = find_path(after, old->path);
		const char *args[2];
		int status;

		if (!new || old->locked == new->locked)
			continue;
		args[0] = new->path;
		if (new->locked) {
			args[1] = new->lock_reason;
			status = emit_hook_event(false, "worktree-locked", 2, args);
		} else {
			args[1] = old->lock_reason;
			status = emit_hook_event(false, "worktree-unlocked", 2, args);
		}
		if (status)
			return status;
	}
	return 0;
}

static struct worktree *find_added_match(struct worktrees *before,
					 struct worktrees *after,
					 struct worktree *old)
{
	size_t i;

	for (i = 0; i < after->len; i++) {
		struct worktree *candidate = &after->items[i];

		if (candidate->matched || find_path(before, candidate->path))
			continue;
		if (same_identity(old, candidate)) {
			candidate->matched = true;
			return candidate;
		}
	}
	return NULL;
}

static int emit_path_changes(const char *event, struct worktrees *before,
			     struct worktrees *after, bool include_old_path)
{
	size_t i;

	for (i = 0; i < before->len; i++) {
		struct worktree *old = &before->items[i];
		struct worktree *new;
		int status;

		if (find_path(after, old->path))
			continue;
		new = find_added_match(before, after, old);
		if (new) {
			if (include_old_path) {
				const char *args[] = {
					old->path, new->path, new->head, new->branch
				};

				status = emit_hook_event(false, event, 4, args);
			} else {
				status = emit_entry(event, new);
			}
			if (status)
				return status;
		}
	}
	return 0;
}

static bool mutates_worktrees(const char *subcommand)
{
	return strcmp(subcommand, "add") == 0 ||
	       strcmp(subcommand, "remove") == 0 ||
	       strcmp(subcommand, "move") == 0 ||
	       strcmp(subcommand, "lock") == 0 ||
	       strcmp(subcommand, "unlock") == 0 ||
	       strcmp(subcommand, "prune") == 0 ||
	       strcmp(subcommand, "repair") == 0;
}

static int emit_worktree_changes(const char *subcommand,
				 struct worktrees *before,
				 struct worktrees *after)
{
	if (strcmp(subcommand, "add") == 0)
		return emit_added(before, after);
	if (strcmp(subcommand, "remove") == 0)
		return emit_removed("worktree-removed", before, after);
	if (strcmp(subcommand, "move") == 0)
		return emit_path_changes("worktree-moved", before, after, true);
	if (strcmp(subcommand, "lock") == 0 ||
	    strcmp(subcommand, "unlock") == 0)
		return emit_lock_changes(before, after);
	if (strcmp(subcommand, "prune") == 0)
		return emit_removed("worktree-pruned", before, after);
	return emit_path_changes("worktree-repaired", before, after, false);
}

static int run_worktree(int argc, char **argv)
{
	char **git_argv = calloc((size_t)argc + 3, sizeof(*git_argv));
	int status;

	if (coverage_fail("GHE_TEST_WORKTREE_CALLOC_FAIL")) {
		free(git_argv);
		git_argv = NULL;
	}
	if (!git_argv) {
		perror("calloc");
		return 1;
	}
	git_argv[0] = "git";
	git_argv[1] = "worktree";
	memcpy(git_argv + 2, argv, (size_t)argc * sizeof(*argv));
	status = run_git(git_argv);
	free(git_argv);
	return status;
}

int cmd_worktree(int argc, char **argv)
{
	struct worktrees before = { 0 };
	struct worktrees after = { 0 };
	int status;

	if (argc == 0) {
		fprintf(stderr, "usage: git-hooks-ext worktree <command> [args...]\n");
		return 2;
	}
	if (!mutates_worktrees(argv[0]))
		return run_worktree(argc, argv);
	if (load_worktrees(&before))
		return 1;
	status = run_worktree(argc, argv);
	if (!status && load_worktrees(&after) == 0)
		status = emit_worktree_changes(argv[0], &before, &after);
	else if (!status)
		status = 1;
	free_worktrees(&before);
	free_worktrees(&after);
	return status;
}
