#ifndef GIT_HOOKS_EXT_PROCESS_H
#define GIT_HOOKS_EXT_PROCESS_H

int process_run(const char *file, char **argv);
/* Returns an owned first output line, or NULL on failure. */
char *process_read_line(const char *command);

#endif
