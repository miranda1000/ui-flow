/* Force-included on Linux (see CMakeLists.txt).
 *
 * With glibc >= 2.38 headers, _GNU_SOURCE (always on in g++) redirects strtol & co. to
 * the C23 variants __isoc23_strtol..., which only exist in glibc 2.38+. Keeping the
 * classic symbols lets the binaries run on the same distributions as the Qt binaries
 * themselves (glibc 2.34+). The only difference is that "0b..." prefixes are not parsed. */
#ifndef UIFLOW_GLIBC_COMPAT_H
#define UIFLOW_GLIBC_COMPAT_H
#include <features.h>
#undef __GLIBC_USE_C2X_STRTOL
#define __GLIBC_USE_C2X_STRTOL 0
#endif
