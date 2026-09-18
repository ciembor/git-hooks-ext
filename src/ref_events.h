#ifndef GIT_HOOKS_EXT_REF_EVENTS_H
#define GIT_HOOKS_EXT_REF_EVENTS_H

#include <stdbool.h>

#include "ref_update.h"

int process_ref_events(struct updates *updates, bool dry_run);

#endif
