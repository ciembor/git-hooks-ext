#define _XOPEN_SOURCE 700

#include "hook_install.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "coverage.h"
#include "git_runner.h"
#include "shell_command.h"

#define LEGACY_BRIDGE_MARKER "# git-hooks-ext legacy bridge\n"

static char *installed_program(const char *argv0)
{
	char resolved[PATH_MAX];
	char *program;

	if (coverage_fail("GHE_TEST_INSTALLED_PROGRAM_STRDUP_FAIL"))
		return NULL;
	if (strchr(argv0, '/') && !coverage_fail("GHE_TEST_REALPATH_FAIL") &&
	    realpath(argv0, resolved))
		return strdup(resolved);
	if (strchr(argv0, '/'))
		return strdup(argv0);
	program = strdup("git-hooks-ext");
	return program;
}

static int write_bridge(const char *hook_path, const char *argv0)
{
	FILE *hook;
	char *program;
	char *quoted_program;

	hook = fopen(hook_path, "w");
	if (coverage_fail("GHE_TEST_FOPEN_FAIL")) {
		if (hook)
			fclose(hook);
		hook = NULL;
	}
	if (!hook) {
		perror(hook_path);
		return 1;
	}

	program = installed_program(argv0);
	if (!program) {
		perror("strdup");
		fclose(hook);
		return 1;
	}
	quoted_program = shell_quote(program);
	free(program);

	if (coverage_fail("GHE_TEST_FPUTS_FAIL") ||
	    fputs("#!/bin/sh\n" LEGACY_BRIDGE_MARKER "exec ", hook) == EOF ||
	    fputs(quoted_program, hook) == EOF ||
	    fputs(" reference-transaction \"$@\"\n", hook) == EOF) {
		perror(hook_path);
		free(quoted_program);
		fclose(hook);
		return 1;
	}
	free(quoted_program);
	if (fclose(hook) != 0 || coverage_fail("GHE_TEST_FCLOSE_FAIL")) {
		perror(hook_path);
		return 1;
	}
	if (coverage_fail("GHE_TEST_CHMOD_FAIL") || chmod(hook_path, 0755) < 0) {
		perror(hook_path);
		return 1;
	}
	return 0;
}

int install_legacy_bridge(const char *argv0)
{
	char *hooks_dir;
	char *hook_path;
	int status;

	hooks_dir = git_hook_path(NULL);
	if (!hooks_dir) {
		fprintf(stderr, "git-hooks-ext: failed to resolve hooks path\n");
		return 1;
	}
	if (coverage_fail("GHE_TEST_MKDIR_FAIL") ||
	    (mkdir(hooks_dir, 0777) == -1 && access(hooks_dir, F_OK) != 0)) {
		perror(hooks_dir);
		free(hooks_dir);
		return 1;
	}
	hook_path = git_hook_path_join(hooks_dir, "reference-transaction");
	free(hooks_dir);
	if (!hook_path) {
		fprintf(stderr, "git-hooks-ext: failed to resolve hooks path\n");
		return 1;
	}
	status = write_bridge(hook_path, argv0);
	free(hook_path);
	return status;
}

int remove_legacy_bridge(void)
{
	char *hook_path;
	FILE *hook;
	char line[sizeof(LEGACY_BRIDGE_MARKER)];
	int close_failed;
	int unlink_failed;
	int status = 0;

	hook_path = git_hook_path("reference-transaction");
	if (!hook_path) {
		fprintf(stderr, "git-hooks-ext: failed to resolve hooks path\n");
		return 1;
	}
	if (coverage_fail("GHE_TEST_LEGACY_OPEN_FAIL")) {
		errno = EACCES;
		hook = NULL;
	} else
		hook = fopen(hook_path, "r");
	if (!hook) {
		if (access(hook_path, F_OK) == 0) {
			perror(hook_path);
			status = 1;
		}
		free(hook_path);
		return status;
	}
	if (!fgets(line, sizeof(line), hook) ||
	    !fgets(line, sizeof(line), hook) ||
	    strcmp(line, LEGACY_BRIDGE_MARKER) != 0) {
		fclose(hook);
		free(hook_path);
		return 0;
	}
	close_failed = coverage_fail("GHE_TEST_LEGACY_CLOSE_FAIL");
	if (fclose(hook) != 0 || close_failed) {
		perror(hook_path);
		status = 1;
	} else {
		unlink_failed = coverage_fail("GHE_TEST_LEGACY_UNLINK_FAIL");
		if (unlink_failed || unlink(hook_path) != 0) {
			if (unlink_failed)
			errno = EPERM;
			perror(hook_path);
			status = 1;
		}
	}
	free(hook_path);
	return status;
}
