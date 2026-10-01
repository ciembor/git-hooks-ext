#ifndef GIT_HOOKS_EXT_REF_SNAPSHOT_H
#define GIT_HOOKS_EXT_REF_SNAPSHOT_H

#include "ref_update.h"

void capture_ref_snapshot(const struct updates *updates);
void restore_ref_snapshot(struct updates *updates);
void discard_ref_snapshot(const struct updates *updates);

#endif
