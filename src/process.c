#define _POSIX_C_SOURCE 200809L

#include "process.h"

#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

#include "coverage.h"

extern char **environ;

int process_run(const char *file, char **argv)
{
	pid_t pid;
	int status;
	int err;

	err = posix_spawnp(&pid, file, NULL, NULL, argv, environ);
	if (coverage_fail("GHE_TEST_SPAWN_FAIL"))
		err = ENOENT;
	if (err) {
		errno = err;
		perror(file);
		return 1;
	}
	if (coverage_fail("GHE_TEST_WAITPID_FAIL") ||
	    waitpid(pid, &status, 0) == (pid_t)-1) {
		perror("waitpid");
		return 1;
	}
	if (coverage_fail("GHE_TEST_PROCESS_SIGNALED"))
		status = SIGTERM;
	if (coverage_fail("GHE_TEST_PROCESS_UNKNOWN"))
		status = 0x7f;
	if (WIFEXITED(status))
		return WEXITSTATUS(status);
	if (WIFSIGNALED(status)) {
		fprintf(stderr, "git-hooks-ext: git hook run killed by signal %d\n",
			WTERMSIG(status));
		return 128 + WTERMSIG(status);
	}
	return 1;
}

char *process_read_line(const char *command)
{
	FILE *pipe;
	char *result;
	size_t len;
	size_t capacity = 128;

	pipe = popen(command, "r");
	if (coverage_fail("GHE_TEST_POPEN_FAIL")) {
		if (pipe)
			pclose(pipe);
		pipe = NULL;
	}
	if (!pipe)
		return NULL;

	result = malloc(capacity);
	if (coverage_fail("GHE_TEST_READ_COMMAND_MALLOC_FAIL")) {
		free(result);
		result = NULL;
	}
	if (!result) {
		pclose(pipe);
		return NULL;
	}
	if (getline(&result, &capacity, pipe) == -1) {
		free(result);
		pclose(pipe);
		return NULL;
	}
	if (pclose(pipe) != 0 || coverage_fail("GHE_TEST_PCLOSE_COMMAND_FAIL")) {
		free(result);
		return NULL;
	}

	len = strcspn(result, "\n");
	result[len] = '\0';
	return result;
}

int process_read_all(const char *command, char **output, size_t *output_len)
{
	FILE *pipe;
	char *result;
	size_t len = 0;
	size_t capacity = 1024;
	size_t read_len;

	*output = NULL;
	*output_len = 0;
	pipe = popen(command, "r");
	if (coverage_fail("GHE_TEST_READ_ALL_POPEN_FAIL")) {
		if (pipe)
			pclose(pipe);
		pipe = NULL;
	}
	if (!pipe)
		return 1;
	if (coverage_fail("GHE_TEST_READ_ALL_SMALL_BUFFER"))
		capacity = 8;
	result = malloc(capacity + 1);
	if (coverage_fail("GHE_TEST_READ_ALL_MALLOC_FAIL")) {
		free(result);
		result = NULL;
	}
	if (!result) {
		perror("malloc");
		pclose(pipe);
		return 1;
	}

	for (;;) {
		if (len == capacity) {
			char *grown;

			capacity *= 2;
			if (coverage_fail("GHE_TEST_READ_ALL_REALLOC_FAIL"))
				grown = NULL;
			else
				grown = realloc(result, capacity + 1);
			if (!grown) {
				perror("realloc");
				free(result);
				pclose(pipe);
				return 1;
			}
			result = grown;
		}
		read_len = fread(result + len, 1, capacity - len, pipe);
		len += read_len;
		if (read_len == 0)
			break;
	}
	if (ferror(pipe) || coverage_fail("GHE_TEST_READ_ALL_FREAD_FAIL")) {
		free(result);
		pclose(pipe);
		return 1;
	}
	if (pclose(pipe) != 0 || coverage_fail("GHE_TEST_READ_ALL_PCLOSE_FAIL")) {
		free(result);
		return 1;
	}
	result[len] = '\0';
	*output = result;
	*output_len = len;
	return 0;
}
