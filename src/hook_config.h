#ifndef GIT_HOOKS_EXT_HOOK_CONFIG_H
#define GIT_HOOKS_EXT_HOOK_CONFIG_H

int configure_hook_bridge(const char *scope);
int remove_hook_bridge(const char *scope);
int configure_event_hook(const char *scope, const char *event,
			 const char *name, int argc, char **argv);

#endif
