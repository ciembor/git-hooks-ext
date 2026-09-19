#define _POSIX_C_SOURCE 200809L

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hook_config.h"
#include "hook_install.h"
#include "ref_events.h"
#include "ref_update.h"
#include "worktree.h"

static void usage(FILE *stream)
{
	fprintf(stream,
		"usage: git-hooks-ext reference-transaction <state> [--dry-run]\n"
		"       git-hooks-ext install [--local|--global|--system|--legacy]\n"
		"       git-hooks-ext add [--local|--global|--system] <event> <name> <command> [args...]\n"
			"       git-hooks-ext worktree <command> [args...]\n"
			"       git-hooks-ext events\n"
			"       git-hooks-ext --version\n");
}

static const char *supported_events[] = {
	"branch-created",
	"branch-deleted",
	"branch-updated",
	"branch-renamed",
	"remote-branch-created",
	"remote-branch-deleted",
	"remote-branch-updated",
	"remote-branch-renamed",
	"tag-created",
	"tag-deleted",
	"tag-updated",
	"tag-renamed",
	"stash-created",
	"stash-deleted",
	"stash-updated",
	"note-created",
	"note-deleted",
	"note-updated",
	"note-renamed",
	"worktree-created",
	"worktree-removed",
	"worktree-moved",
	"worktree-locked",
	"worktree-unlocked",
	"worktree-pruned",
	"worktree-repaired",
	NULL
};

static bool is_scope(const char *arg)
{
	return strcmp(arg, "--local") == 0 || strcmp(arg, "--global") == 0 ||
	       strcmp(arg, "--system") == 0;
}

static bool is_supported_event(const char *event)
{
	int i;

	for (i = 0; supported_events[i]; i++) {
		if (strcmp(event, supported_events[i]) == 0)
			return true;
	}
	return false;
}

static int cmd_events(int argc, char **argv)
{
	int i;

	(void)argv;
	if (argc != 0) {
		usage(stderr);
		return 2;
	}

	for (i = 0; supported_events[i]; i++)
		printf("%s\n", supported_events[i]);
	return 0;
}

static int cmd_reference_transaction(int argc, char **argv)
{
	const char *state;
	bool dry_run = false;
	struct updates updates = { 0 };
	int status;
	int i;

	if (argc < 1) {
		usage(stderr);
		return 2;
	}

	state = argv[0];
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--dry-run") == 0)
			dry_run = true;
		else {
			usage(stderr);
			return 2;
		}
	}

	if (strcmp(state, "committed") != 0)
		return 0;

	status = read_updates(&updates);
	if (!status)
		status = process_ref_events(&updates, dry_run);
	free_updates(&updates);
	return status;
}

static int cmd_install(int argc, char **argv, const char *argv0)
{
	const char *scope = "--local";

	if (argc > 1) {
		usage(stderr);
		return 2;
	}
	if (argc == 1) {
		if (strcmp(argv[0], "--legacy") == 0)
			return install_legacy_bridge(argv0);
		if (!is_scope(argv[0])) {
			usage(stderr);
			return 2;
		}
		scope = argv[0];
	}
	return configure_hook_bridge(scope);
}

static int cmd_add(int argc, char **argv)
{
	const char *scope = "--local";
	const char *event;
	const char *name;

	if (argc > 0 && is_scope(argv[0])) {
		scope = argv[0];
		argc--;
		argv++;
	}
	if (argc < 3) {
		usage(stderr);
		return 2;
	}

	event = argv[0];
	name = argv[1];
	if (!is_supported_event(event)) {
		fprintf(stderr, "git-hooks-ext: unknown event '%s'\n", event);
		fprintf(stderr, "Run 'git-hooks-ext events' to list supported events.\n");
		return 2;
	}

	return configure_event_hook(scope, event, name, argc - 2, argv + 2);
}

int main(int argc, char **argv)
{
	if (argc == 2 && strcmp(argv[1], "--version") == 0) {
		puts("git-hooks-ext " GIT_HOOKS_EXT_VERSION);
		return 0;
	}
	if (argc < 2) {
		usage(stderr);
		return 2;
	}

	if (strcmp(argv[1], "reference-transaction") == 0)
		return cmd_reference_transaction(argc - 2, argv + 2);
	if (strcmp(argv[1], "install") == 0)
		return cmd_install(argc - 2, argv + 2, argv[0]);
	if (strcmp(argv[1], "add") == 0)
		return cmd_add(argc - 2, argv + 2);
	if (strcmp(argv[1], "events") == 0)
		return cmd_events(argc - 2, argv + 2);
	if (strcmp(argv[1], "worktree") == 0)
		return cmd_worktree(argc - 2, argv + 2);

	usage(stderr);
	return 2;
}
