#ifndef GIT_HOOKS_EXT_COVERAGE_H
#define GIT_HOOKS_EXT_COVERAGE_H

#ifdef GIT_HOOKS_EXT_COVERAGE_TEST
#include <stdlib.h>

#define coverage_fail(name) (getenv(name) != NULL)
#else
#define coverage_fail(name) 0
#endif

#endif
