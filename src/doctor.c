#define _POSIX_C_SOURCE 200809L

#include "doctor.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "git_runner.h"
#include "process.h"

static const char *events[] = {
	"branch-created", "branch-deleted", "branch-updated", "branch-renamed",
	"remote-branch-created", "remote-branch-deleted", "remote-branch-updated",
	"remote-branch-renamed", "remote-head-created", "remote-head-deleted",
	"remote-head-updated", "tag-created", "tag-deleted", "tag-updated",
	"tag-renamed", "stash-created", "stash-deleted", "stash-updated",
	"note-created", "note-deleted", "note-updated", "note-renamed",
	"replace-created", "replace-deleted", "replace-updated", "prefetch-created",
	"prefetch-deleted", "prefetch-updated", "bisect-ref-created",
	"bisect-ref-deleted", "bisect-ref-updated", "rewritten-ref-created",
	"rewritten-ref-deleted", "rewritten-ref-updated", "worktree-ref-created",
	"worktree-ref-deleted", "worktree-ref-updated", "head-updated",
	"head-attached", "head-detached", "head-switched", "root-ref-created",
	"root-ref-deleted", "root-ref-updated", "ref-created", "ref-deleted",
	"ref-updated", "worktree-created", "worktree-removed", "worktree-moved",
	"worktree-locked", "worktree-unlocked", "worktree-pruned", "worktree-repaired",
	NULL
};

static bool at_least(unsigned int major, unsigned int minor, unsigned int patch,
		     unsigned int required_major, unsigned int required_minor,
		     unsigned int required_patch)
{
	if (major != required_major)
		return major > required_major;
	if (minor != required_minor)
		return minor > required_minor;
	return patch >= required_patch;
}

static const char *event_status(const char *event, unsigned int major,
				unsigned int minor, unsigned int patch)
{
	if (strcmp(event, "branch-renamed") == 0 ||
	    strcmp(event, "head-detached") == 0 ||
	    strcmp(event, "remote-branch-deleted") == 0 ||
	    strcmp(event, "stash-updated") == 0 ||
	    strcmp(event, "note-updated") == 0)
		return "affected by Git bug";
	if (strcmp(event, "branch-deleted") == 0 || strcmp(event, "tag-deleted") == 0) {
		if (!at_least(major, minor, patch, 2, 28, 0))
			return "requires Git 2.28+";
		return at_least(major, minor, patch, 2, 31, 0) ?
			"affected by Git bug" : "supported";
	}
	if (strcmp(event, "remote-branch-renamed") == 0)
		return at_least(major, minor, patch, 2, 55, 0) ? "supported" :
			"requires Git 2.55+";
	if (strncmp(event, "remote-head-", strlen("remote-head-")) == 0 ||
	    strncmp(event, "head-", strlen("head-")) == 0 ||
	    strncmp(event, "root-ref-", strlen("root-ref-")) == 0)
		return at_least(major, minor, patch, 2, 54, 0) ? "supported" :
			"requires Git 2.54+";
	if (strncmp(event, "prefetch-", strlen("prefetch-")) == 0)
		return at_least(major, minor, patch, 2, 32, 0) ? "supported" :
			"requires Git 2.32+";
	if (strncmp(event, "worktree-", strlen("worktree-")) == 0 &&
	    strstr(event, "worktree-ref-") != event)
		return at_least(major, minor, patch, 2, 39, 3) ? "supported" :
			"requires Git 2.39.3+";
	return at_least(major, minor, patch, 2, 28, 0) ? "supported" :
		"requires Git 2.28+";
}

static const char *config_bridge_status(void)
{
	char *event = process_read_line("git config --get hook.git-hooks-ext.event");
	char *command = process_read_line("git config --get hook.git-hooks-ext.command");
	const char *status = "no";

	if (event && command && strcmp(event, "reference-transaction") == 0 &&
	    strcmp(command, "git-hooks-ext reference-transaction") == 0)
		status = "yes";
	free(event);
	free(command);
	return status;
}

static const char *legacy_bridge_status(void)
{
	char *path = git_hook_path("reference-transaction");
	const char *status;

	if (!path)
		return "unknown";
	status = access(path, X_OK) == 0 ? "yes" : "no";
	free(path);
	return status;
}

int run_doctor(void)
{
	char *version;
	char *backend;
	char *git_dir;
	unsigned int major;
	unsigned int minor;
	unsigned int patch = 0;
	int config_hooks;
	int i;

	git_dir = process_read_line("git rev-parse --git-dir");
	if (!git_dir) {
		fprintf(stderr, "git-hooks-ext: doctor must be run inside a Git repository\n");
		return 1;
	}
	free(git_dir);
	version = process_read_line("git --version");
	if (!version || sscanf(version, "git version %u.%u.%u", &major, &minor,
				       &patch) < 2) {
		fprintf(stderr, "git-hooks-ext: failed to determine the Git version\n");
		free(version);
		return 1;
	}
	backend = at_least(major, minor, patch, 2, 45, 0) ?
		process_read_line("git rev-parse --show-ref-format") : strdup("files");
	config_hooks = git_config_hooks_supported();
	printf("Git version:              %s\n", version + strlen("git version "));
	printf("Ref backend:              %s\n", backend ? backend : "unknown");
	printf("Config-based hooks:       %s\n",
	       config_hooks > 0 ? "supported" : "not supported");
	printf("Bridge installed:         %s\n",
	       strcmp(config_bridge_status(), "yes") == 0 ? "yes (config-based)" :
	       strcmp(legacy_bridge_status(), "yes") == 0 ? "yes (legacy)" : "no");
	printf("Legacy bridge:            %s\n\n", legacy_bridge_status());
	for (i = 0; events[i]; i++)
		printf("%-25s %s\n", events[i], event_status(events[i], major, minor, patch));
	free(backend);
	free(version);
	return 0;
}
