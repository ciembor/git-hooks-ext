#ifndef GIT_HOOKS_EXT_SHELL_COMMAND_H
#define GIT_HOOKS_EXT_SHELL_COMMAND_H

/* Both functions return owned, shell-quoted strings. */
char *shell_quote(const char *s);
char *shell_join_command(int argc, char **argv);

#endif
