#include "shell_command.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "coverage.h"

static size_t quoted_length(const char *s)
{
	size_t len = 2;
	size_t i;

	for (i = 0; s[i]; i++)
		len += s[i] == '\'' ? 4 : 1;
	return len;
}

static char *write_quoted(char *out, const char *s)
{
	size_t i;

	*out++ = '\'';
	for (i = 0; s[i]; i++) {
		if (s[i] == '\'') {
			memcpy(out, "'\\''", 4);
			out += 4;
		} else {
			*out++ = s[i];
		}
	}
	*out++ = '\'';
	return out;
}

static char *command_buffer(size_t len, const char *failure)
{
	char *buffer = malloc(len);

	(void)failure;
	if (coverage_fail(failure)) {
		free(buffer);
		buffer = NULL;
	}
	if (!buffer) {
		perror("malloc");
		exit(1);
	}
	return buffer;
}

char *shell_quote(const char *s)
{
	char *quoted = command_buffer(quoted_length(s) + 1,
				      "GHE_TEST_SHELL_QUOTE_MALLOC_FAIL");

	*write_quoted(quoted, s) = '\0';
	return quoted;
}

char *shell_join_command(int argc, char **argv)
{
	size_t len = 1;
	char *command;
	char *out;
	int i;

	for (i = 0; i < argc; i++)
		len += quoted_length(argv[i]) + (i != 0);
	command = command_buffer(len, "GHE_TEST_JOIN_COMMAND_MALLOC_FAIL");
	out = command;
	for (i = 0; i < argc; i++) {
		if (i)
			*out++ = ' ';
		out = write_quoted(out, argv[i]);
	}
	*out = '\0';
	return command;
}
