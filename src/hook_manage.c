#define _POSIX_C_SOURCE 200809L

#include "hook_manage.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "git_runner.h"
#include "process.h"
#include "shell_command.h"

static char *hook_key(const char *name, const char *field)
{
	char *key = malloc(strlen("hook..") + strlen(name) + strlen(field) + 1);

	if (!key) {
		perror("malloc");
		return NULL;
	}
	sprintf(key, "hook.%s.%s", name, field);
	return key;
}

static char *read_config_value(const char *scope, const char *key)
{
	char *quoted_key;
	char *command;
	char *value;
	size_t command_len;

	quoted_key = shell_quote(key);
	if (!quoted_key)
		return NULL;
	command_len = strlen("git config  --get ") + strlen(scope) +
		strlen(quoted_key) + 1;
	command = malloc(command_len);
	if (!command) {
		perror("malloc");
		free(quoted_key);
		return NULL;
	}
	snprintf(command, command_len, "git config %s --get %s", scope, quoted_key);
	value = process_read_line(command);
	free(command);
	free(quoted_key);
	return value;
}

static int print_hook(const char *scope, const char *name, const char *event)
{
	char *command_key = hook_key(name, "command");
	char *command;

	if (!command_key)
		return 1;
	command = read_config_value(scope, command_key);
	free(command_key);
	printf("%-20s %-18s %s\n", name, event,
	       command ? command : "<missing command>");
	free(command);
	return 0;
}

int list_event_hooks(const char *scope)
{
	char command[128];
	char *output;
	size_t output_len;
	char *line;
	int status;

	snprintf(command, sizeof(command),
		 "git config %s --get-regexp '^hook\\..*\\.event$' || test $? -eq 1",
		 scope);
	status = process_read_all(command, &output, &output_len);
	if (status) {
		fprintf(stderr, "git-hooks-ext: failed to read hook configuration\n");
		return status;
	}
	printf("%-20s %-18s %s\n", "NAME", "EVENT", "COMMAND");
	line = output;
	while (*line) {
		char *next = strchr(line, '\n');
		char *separator = strchr(line, ' ');
		char *name;
		size_t key_len;

		if (next)
			*next = '\0';
		if (separator) {
			*separator = '\0';
			key_len = strlen(line);
			if (key_len > strlen("hook..event") &&
			    strncmp(line, "hook.", strlen("hook.")) == 0 &&
			    strcmp(line + key_len - strlen(".event"), ".event") == 0) {
				name = strndup(line + strlen("hook."),
					       key_len - strlen("hook.") - strlen(".event"));
				if (!name) {
					perror("strndup");
					free(output);
					return 1;
				}
				if (strcmp(name, "git-hooks-ext") != 0)
					status = print_hook(scope, name, separator + 1);
				free(name);
				if (status) {
					free(output);
					return status;
				}
			}
		}
		if (!next)
			break;
		line = next + 1;
	}
	free(output);
	return 0;
}

int show_event_hook(const char *scope, const char *name)
{
	char *event_key = hook_key(name, "event");
	char *event;
	int status;

	if (!event_key)
		return 1;
	if (strcmp(name, "git-hooks-ext") == 0) {
		fprintf(stderr, "git-hooks-ext: use 'git-hooks-ext doctor' to inspect the bridge\n");
		free(event_key);
		return 2;
	}
	event = read_config_value(scope, event_key);
	free(event_key);
	if (!event) {
		fprintf(stderr, "git-hooks-ext: hook '%s' is not configured in %s\n", name,
			scope);
		return 1;
	}
	printf("%-20s %-18s %s\n", "NAME", "EVENT", "COMMAND");
	status = print_hook(scope, name, event);
	free(event);
	return status;
}

static int remove_config_key(const char *scope, char *key)
{
	char *argv[] = { "git", "config", (char *)scope, "--unset-all", key, NULL };
	int status = run_git(argv);

	return status == 5 ? 0 : status;
}

int remove_event_hook(const char *scope, const char *name)
{
	char *event_key;
	char *command_key;
	char *event;
	char *hook_command;
	int status;

	if (strcmp(name, "git-hooks-ext") == 0) {
		fprintf(stderr, "git-hooks-ext: use 'git-hooks-ext uninstall' to remove the bridge\n");
		return 2;
	}
	event_key = hook_key(name, "event");
	command_key = hook_key(name, "command");
	if (!event_key || !command_key) {
		free(event_key);
		free(command_key);
		return 1;
	}
	event = read_config_value(scope, event_key);
	hook_command = read_config_value(scope, command_key);
	if (!event && !hook_command) {
		fprintf(stderr, "git-hooks-ext: hook '%s' is not configured in %s\n", name,
			scope);
		free(event_key);
		free(command_key);
		return 1;
	}
	free(event);
	free(hook_command);
	status = remove_config_key(scope, event_key);
	if (!status)
		status = remove_config_key(scope, command_key);
	free(event_key);
	free(command_key);
	return status;
}
