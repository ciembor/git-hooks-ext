#define _POSIX_C_SOURCE 200809L
#ifdef __APPLE__
#define _DARWIN_C_SOURCE
#endif

#include "ref_snapshot.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "process.h"
#include "shell_command.h"
#include "coverage.h"

static void *snapshot_allocate(size_t length, const char *failure)
{
	(void)failure;
	if (coverage_fail(failure))
		return NULL;
	return malloc(length);
}

static char *read_ref_value(const char *refname)
{
	const char quiet_suffix[] = " 2>/dev/null";
	const char missing_suffix[] =
		"; result=$?; if test \"$result\" = 1; then printf -- '-\\n'; else exit \"$result\"; fi";
	char *arguments[] = { "git", "symbolic-ref", "--quiet", "--no-recurse", "--",
		(char *)refname };
	char *command = shell_join_command(6, arguments);
	char *quiet = snapshot_allocate(strlen(command) + sizeof(quiet_suffix),
					"GHE_TEST_SNAPSHOT_SYMBOLIC_COMMAND_ALLOC_FAIL");
	char *value;

	if (!quiet || coverage_fail("GHE_TEST_SNAPSHOT_READ_FAIL")) {
		free(quiet);
		free(command);
		return NULL;
	}
	sprintf(quiet, "%s%s", command, quiet_suffix);
	free(command);
	value = process_read_line(quiet);
	free(quiet);
	if (value) {
		char *symbolic = snapshot_allocate(strlen(value) + 5, "GHE_TEST_SNAPSHOT_VALUE_ALLOC_FAIL");

		if (symbolic)
			sprintf(symbolic, "ref:%s", value);
		free(value);
		return symbolic;
	}
	arguments[1] = "rev-parse";
	arguments[2] = "--verify";
	arguments[3] = "--quiet";
	arguments[4] = "--end-of-options";
	command = shell_join_command(6, arguments);
	quiet = snapshot_allocate(strlen(command) + sizeof(missing_suffix),
				  "GHE_TEST_SNAPSHOT_OID_COMMAND_ALLOC_FAIL");
	if (!quiet) {
		free(command);
		return NULL;
	}
	sprintf(quiet, "%s%s", command, missing_suffix);
	value = process_read_line(quiet);
	free(quiet);
	free(command);
	return value;
}

static uint64_t hash_field(uint64_t hash, const char *field)
{
	const unsigned char *cursor = (const unsigned char *)field;

	do {
		hash = (hash ^ *cursor) * UINT64_C(1099511628211);
	} while (*cursor++);
	return hash;
}

static char *snapshot_path(const struct updates *updates)
{
	char *directory;
	char *path;
	struct stat info;
	uint64_t hash = UINT64_C(14695981039346656037);
	size_t i;
	bool needed = false;

	for (i = 0; i < updates->len; i++)
		if (ref_value_is_zero(updates->items[i].old_value))
			needed = true;
	if (!needed)
		return NULL;

	directory = process_read_line("git rev-parse --git-path git-hooks-ext-state 2>/dev/null");
	if (!directory)
		return NULL;
	if ((mkdir(directory, 0700) < 0 && errno != EEXIST) ||
	    lstat(directory, &info) < 0 || !S_ISDIR(info.st_mode) ||
	    info.st_uid != getuid() || (info.st_mode & 0077)) {
		fprintf(stderr, "git-hooks-ext: cannot use private snapshot directory %s\n", directory);
		free(directory);
		return NULL;
	}
	for (i = 0; i < updates->len; i++) {
		const struct ref_update *update = &updates->items[i];

		hash = hash_field(hash, update->old_value);
		hash = hash_field(hash, update->new_value);
		hash = hash_field(hash, update->refname);
	}
	path = snapshot_allocate(strlen(directory) + 64, "GHE_TEST_SNAPSHOT_PATH_ALLOC_FAIL");
	if (path)
		sprintf(path, "%s/%ld-%016" PRIx64, directory, (long)getppid(), hash);
	free(directory);
	return path;
}

static char *transaction_record(const struct ref_update *update)
{
	size_t length = strlen(update->old_value) + strlen(update->new_value) +
		strlen(update->refname) + 4;
	char *record = snapshot_allocate(length, "GHE_TEST_SNAPSHOT_RECORD_ALLOC_FAIL");

	if (record)
		snprintf(record, length, "%s %s %s\n", update->old_value,
			 update->new_value, update->refname);
	return record;
}

void capture_ref_snapshot(const struct updates *updates)
{
	char *path = snapshot_path(updates);
	FILE *snapshot;
	int descriptor;
	size_t i;

	if (!path)
		return;
	unlink(path);
	descriptor = coverage_fail("GHE_TEST_SNAPSHOT_OPEN_FAIL") ? -1 :
		open(path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0600);
	snapshot = descriptor < 0 || coverage_fail("GHE_TEST_SNAPSHOT_FDOPEN_FAIL") ?
		NULL : fdopen(descriptor, "w");
	if (!snapshot) {
		if (descriptor >= 0)
			close(descriptor);
		fprintf(stderr, "git-hooks-ext: cannot capture ref snapshot %s\n", path);
		free(path);
		return;
	}
	for (i = 0; i < updates->len; i++) {
		const struct ref_update *update = &updates->items[i];
		char *record = transaction_record(update);
		char *value = ref_value_is_zero(update->old_value) ?
			read_ref_value(update->refname) : NULL;

		if (!record || coverage_fail("GHE_TEST_SNAPSHOT_WRITE_FAIL") ||
		    fputs(record, snapshot) == EOF ||
		    fprintf(snapshot, "%s\n", value ? value : "-") < 0) {
			free(record);
			free(value);
			break;
		}
		free(record);
		free(value);
	}
	if (fclose(snapshot) != 0 || coverage_fail("GHE_TEST_SNAPSHOT_CLOSE_FAIL") ||
	    i != updates->len) {
		fprintf(stderr, "git-hooks-ext: incomplete ref snapshot %s\n", path);
		unlink(path);
	}
	free(path);
}

static bool valid_ref_value(const char *value)
{
	size_t length = strlen(value);

	return ref_value_is_symbolic(value) ||
	       ((length == 40 || length == 64) &&
		strspn(value, "0123456789abcdef") == length);
}

static void restore_old_value(struct ref_update *update, const char *value)
{
	char *current;
	char *copy;

	if (!ref_value_is_zero(update->old_value) || !valid_ref_value(value))
		return;
	/* Packed-ref maintenance also reports zero -> zero without deleting the ref. */
	if (ref_value_is_zero(update->new_value)) {
		current = read_ref_value(update->refname);
		if (!current)
			return;
		if (strcmp(current, "-") != 0) {
			free(current);
			return;
		}
		free(current);
	}
	copy = snapshot_allocate(strlen(value) + 1, "GHE_TEST_SNAPSHOT_OLD_ALLOC_FAIL");
	if (!copy)
		return;
	strcpy(copy, value);
	free(update->old_value);
	update->old_value = copy;
	update->update_kind = ref_value_is_zero(update->new_value) ?
		UPDATE_DELETE : UPDATE_UPDATE;
}

static bool read_snapshot_line(FILE *snapshot, char **line, size_t *capacity)
{
	ssize_t length = getline(line, capacity, snapshot);

	return length > 0 && (*line)[length - 1] == '\n' &&
	       !memchr(*line, '\0', (size_t)length);
}

static bool snapshot_matches(FILE *snapshot, const struct updates *updates)
{
	char *line = NULL;
	size_t capacity = 0;
	size_t i;
	bool matches = true;

	for (i = 0; i < updates->len && matches; i++) {
		char *record = transaction_record(&updates->items[i]);

		matches = record && read_snapshot_line(snapshot, &line, &capacity) &&
			strcmp(record, line) == 0;
		free(record);
		if (matches)
			matches = read_snapshot_line(snapshot, &line, &capacity);
	}
	if (matches)
		matches = fgetc(snapshot) == EOF && !ferror(snapshot);
	free(line);
	return fseek(snapshot, 0, SEEK_SET) == 0 && matches;
}

void restore_ref_snapshot(struct updates *updates)
{
	char *path = snapshot_path(updates);
	FILE *snapshot;
	char *line = NULL;
	size_t capacity = 0;
	size_t i;

	if (!path)
		return;
	snapshot = fopen(path, "r");
	/* Consume before dispatch: hooks may themselves start ref transactions. */
	unlink(path);
	free(path);
	if (!snapshot)
		return;
	if (!snapshot_matches(snapshot, updates)) {
		fclose(snapshot);
		return;
	}
	for (i = 0; i < updates->len; i++) {
		struct ref_update *update = &updates->items[i];
		char *record = transaction_record(update);
		bool matches = record && read_snapshot_line(snapshot, &line, &capacity) &&
			strcmp(record, line) == 0;

		free(record);
		if (!matches || coverage_fail("GHE_TEST_SNAPSHOT_RESTORE_READ_FAIL") ||
		    !read_snapshot_line(snapshot, &line, &capacity))
			break;
		line[strcspn(line, "\n")] = '\0';
		restore_old_value(update, line);
	}
	free(line);
	fclose(snapshot);
}

void discard_ref_snapshot(const struct updates *updates)
{
	char *path = snapshot_path(updates);

	if (path)
		unlink(path);
	free(path);
}
