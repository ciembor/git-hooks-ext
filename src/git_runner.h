#ifndef GIT_HOOKS_EXT_GIT_RUNNER_H
#define GIT_HOOKS_EXT_GIT_RUNNER_H

#include <stdbool.h>
#include <stddef.h>

int run_git(char **argv);
/* Caller owns returned paths; NULL hook_name selects the directory. */
char *git_hook_path(const char *hook_name);
char *git_hook_path_join(const char *hooks_dir, const char *hook_name);
int emit_hook_event(bool dry_run, const char *event,
		    size_t hook_argc, const char **hook_args);

#endif
