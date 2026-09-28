#define _POSIX_C_SOURCE 200809L

#include "git_runner.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "coverage.h"
#include "process.h"

static bool verbose_enabled(void)
{
	char *value = process_read_line("git config --bool --get git-hooks-ext.verbose");
	bool enabled = value && strcmp(value, "true") == 0;

	free(value);
	return enabled;
}

static void announce_hook(const char *event, const char *name)
{
	fprintf(stderr, "[git-hooks-ext] %s ➠ %s\n", event, name);
}

static void announce_config_hooks(const char *event)
{
	const char command[] =
		"git config --get-regexp '^hook\\..*\\.event$' || test $? -eq 1";
	const char prefix[] = "hook.";
	const char suffix[] = ".event";
	char *output;
	char *line;
	size_t output_len;

	if (process_read_all(command, &output, &output_len))
		return;
	line = output;
	while (*line) {
		char *next = strchr(line, '\n');
		char *separator = strchr(line, ' ');
		size_t key_len;

		if (next)
			*next = '\0';
		if (separator) {
			*separator = '\0';
			key_len = strlen(line);
			if (strcmp(separator + 1, event) == 0 &&
			    key_len > strlen(prefix) + strlen(suffix) &&
			    strncmp(line, prefix, strlen(prefix)) == 0 &&
			    strcmp(line + key_len - strlen(suffix), suffix) == 0) {
				size_t name_len = key_len - strlen(prefix) - strlen(suffix);
				char *name = strndup(line + strlen(prefix), name_len);

				if (name) {
					announce_hook(event, name);
					free(name);
				}
			}
		}
		if (!next)
			break;
		line = next + 1;
	}
	free(output);
}

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
			   const char **hook_args, bool verbose, bool *ran)
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
	if (verbose)
		announce_hook(legacy_event, legacy_event);

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
	bool verbose;

	if (dry_run) {
		printf("%s", event);
		for (i = 0; i < hook_argc; i++)
			printf(" %s", hook_args[i]);
		putchar('\n');
		return 0;
	}

	verbose = verbose_enabled();
	status = run_legacy_hook(event, hook_argc, hook_args, verbose, &ran_legacy);
	if (status || ran_legacy)
		return status;

	if (!config_hooks_supported())
		return 0;
	if (verbose)
		announce_config_hooks(event);

	status = git_hook_run_event(event, hook_argc, hook_args);
	if (status)
		return status;
	return 0;
}
