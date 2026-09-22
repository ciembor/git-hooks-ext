#ifndef GIT_HOOKS_EXT_HOOK_MANAGE_H
#define GIT_HOOKS_EXT_HOOK_MANAGE_H

int list_event_hooks(const char *scope);
int show_event_hook(const char *scope, const char *name);
int remove_event_hook(const char *scope, const char *name);

#endif
