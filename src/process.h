#ifndef GIT_HOOKS_EXT_PROCESS_H
#define GIT_HOOKS_EXT_PROCESS_H

#include <stddef.h>

int process_run(const char *file, char **argv);
/* Returns an owned first output line, or NULL on failure. */
char *process_read_line(const char *command);
/* Reads binary output, appends a trailing NUL, and returns zero on success. */
int process_read_all(const char *command, char **output, size_t *output_len);

#endif
