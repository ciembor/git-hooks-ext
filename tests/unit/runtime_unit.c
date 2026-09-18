#include "../../src/process.h"
#include "../../src/shell_command.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int check_line(const char *command, const char *expected)
{
	char *line = process_read_line(command);
	int failed = expected ? !line || strcmp(line, expected) != 0 : line != NULL;

	if (failed)
		fprintf(stderr, "unexpected output from: %s\n", command);
	free(line);
	return failed;
}

static int test_process_output(void)
{
	char expected[8193];

	memset(expected, 'x', sizeof(expected) - 1);
	expected[sizeof(expected) - 1] = '\0';
	return check_line("awk 'BEGIN { for (i = 0; i < 8192; i++) printf \"x\"; printf \"\\n\" }'", expected) ||
		check_line("printf 'tail'", "tail") ||
		check_line("printf '\\n'", "") ||
		check_line("true", NULL) ||
		check_line("printf 'ignored\\n'; exit 7", NULL);
}

static int test_shell_commands(void)
{
	char *args[] = { "one", "", "a'b" };
	char *quoted = shell_quote("a'b");
	char *command = shell_join_command(3, args);
	char *empty = shell_join_command(0, NULL);
	int failed = strcmp(quoted, "'a'\\''b'") != 0 ||
		strcmp(command, "'one' '' 'a'\\''b'") != 0 || strcmp(empty, "") != 0;

	free(quoted);
	free(command);
	free(empty);
	return failed;
}

int main(void)
{
	return test_process_output() || test_shell_commands();
}
