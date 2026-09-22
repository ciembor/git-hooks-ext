#define _POSIX_C_SOURCE 200809L

#include "git_runner.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "coverage.h"
#include "process.h"

int run_git(char **argv)
{
	return process_run("git", argv);
}

int git_config_hooks_supported(void)
{
	char *version;
	unsigned int major;
	unsigned int minor;
	int supported;

	version = process_read_line("git --version");
	if (!version)
		return -1;
	if (sscanf(version, "git version %u.%u", &major, &minor) != 2) {
		free(version);
		return -1;
	}
	supported = major > 2 || (major == 2 && minor >= 54);
	free(version);
	return supported;
}

static bool config_hooks_supported(void)
{
	int status;

	if (coverage_fail("GHE_TEST_CONFIG_HOOKS_UNSUPPORTED"))
		return false;
	if (coverage_fail("GHE_TEST_CONFIG_HOOKS_SUPPORTED"))
		return true;
	status = system("git hook run --allow-unknown-hook-name --ignore-missing git-hooks-ext-probe -- >/dev/null 2>&1");
	return status == 0;
}

char *git_hook_path_join(const char *hooks_dir, const char *hook_name)
{
	char *path;
	size_t len;

	if (!hook_name)
		return strdup(hooks_dir);

	len = strlen(hooks_dir) + strlen(hook_name) + 2;
	path = malloc(len);
	if (coverage_fail("GHE_TEST_JOIN_HOOK_PATH_MALLOC_FAIL")) {
		free(path);
		path = NULL;
	}
	if (!path)
		return NULL;
	snprintf(path, len, "%s/%s", hooks_dir, hook_name);
	return path;
}

char *git_hook_path(const char *hook_name)
{
	char *hooks_dir;
	char *path;

	hooks_dir = process_read_line("git rev-parse --git-path hooks");
	if (!hooks_dir)
		return NULL;
	path = git_hook_path_join(hooks_dir, hook_name);
	free(hooks_dir);
	return path;
}

static int git_hook_run_event(const char *event, size_t hook_argc,
			      const char **hook_args)
{
	char **argv;
	size_t argc = 0;
	size_t i;
	int status;

	argv = calloc(8 + hook_argc, sizeof(*argv));
	if (coverage_fail("GHE_TEST_HOOK_RUN_CALLOC_FAIL")) {
		free(argv);
		argv = NULL;
	}
	if (!argv) {
		perror("calloc");
		return 1;
	}

	argv[argc++] = "git";
	argv[argc++] = "hook";
	argv[argc++] = "run";
	argv[argc++] = "--allow-unknown-hook-name";
	argv[argc++] = "--ignore-missing";
	argv[argc++] = (char *)event;
	argv[argc++] = "--";
	for (i = 0; i < hook_argc; i++)
		argv[argc++] = (char *)hook_args[i];
	argv[argc] = NULL;

	status = run_git(argv);
	free(argv);
	return status;
}

static int run_legacy_hook(const char *legacy_event, size_t hook_argc,
			   const char **hook_args, bool *ran)
{
	char *hook_path;
	char **argv;
	size_t argc = 0;
	size_t i;
	int status;

	*ran = false;
	hook_path = git_hook_path(legacy_event);
	if (!hook_path)
		return 0;
	if (access(hook_path, X_OK) != 0) {
		free(hook_path);
		return 0;
	}
	*ran = true;

	argv = calloc(2 + hook_argc, sizeof(*argv));
	if (coverage_fail("GHE_TEST_LEGACY_CALLOC_FAIL")) {
		free(argv);
		argv = NULL;
	}
	if (!argv) {
		perror("calloc");
		free(hook_path);
		return 1;
	}

	argv[argc++] = hook_path;
	for (i = 0; i < hook_argc; i++)
		argv[argc++] = (char *)hook_args[i];
	argv[argc] = NULL;

	status = process_run(hook_path, argv);
	free(argv);
	free(hook_path);
	return status;
}

int emit_hook_event(bool dry_run, const char *event,
		    size_t hook_argc, const char **hook_args)
{
	size_t i;
	int status;
	bool ran_legacy;

	if (dry_run) {
		printf("%s", event);
		for (i = 0; i < hook_argc; i++)
			printf(" %s", hook_args[i]);
		putchar('\n');
		return 0;
	}

	status = run_legacy_hook(event, hook_argc, hook_args, &ran_legacy);
	if (status || ran_legacy)
		return status;

	if (!config_hooks_supported())
		return 0;

	status = git_hook_run_event(event, hook_argc, hook_args);
	if (status)
		return status;
	return 0;
}
