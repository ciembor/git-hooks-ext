#define _POSIX_C_SOURCE 200809L

#include "hook_config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "coverage.h"
#include "git_runner.h"
#include "shell_command.h"

static char *xmalloc(size_t size)
{
	char *ptr = malloc(size);
	if (coverage_fail("GHE_TEST_XMALLOC_FAIL")) {
		free(ptr);
		ptr = NULL;
	}
	if (!ptr) {
		perror("malloc");
		exit(1);
	}
	return ptr;
}

static char *hook_config_key(const char *name, const char *field)
{
	char *key = xmalloc(strlen("hook..") + strlen(name) + strlen(field) + 1);

	sprintf(key, "hook.%s.%s", name, field);
	return key;
}

static int configure_hook(const char *scope, const char *name,
			  const char *event, const char *command)
{
	char *event_key = hook_config_key(name, "event");
	char *command_key = hook_config_key(name, "command");
	char *config_event[] = {
		"git", "config", (char *)scope, event_key, (char *)event, NULL
	};
	char *config_command[] = {
		"git", "config", (char *)scope, command_key, (char *)command, NULL
	};
	int status = run_git(config_event);

	if (!status)
		status = run_git(config_command);
	free(event_key);
	free(command_key);
	return status;
}

int configure_hook_bridge(const char *scope)
{
	return configure_hook(scope, "git-hooks-ext", "reference-transaction",
			      "git-hooks-ext reference-transaction");
}

int configure_event_hook(const char *scope, const char *event,
			 const char *name, int argc, char **argv)
{
	char *command = shell_join_command(argc, argv);
	int status = configure_hook(scope, name, event, command);

	free(command);
	return status;
}
