#if defined _bb_version_included
  #endinput
#endif
#define _bb_version_included

#include "include/bb/bb_version_codes.inc"
#include "include/zm/zm_debug.inc"

/** The version code of BB. */
#define BB_VERSION 9
/** The string representation for this version of BB. */
#define BB_VERSION_STRING "9.0.0"

/**
 * Returns the version code of BB.
 */
stock bb_getVersionId() {
  return BB_VERSION;
}

/**
 * Returns the string representation for the version of BB.
 */
stock bb_getVersion(version[], len) {
  return copy(version, len, BB_VERSION_STRING);
}

/**
 * Returns the build identifier string for the version of BB.
 */
stock bb_getBuildId(buildId[], len) {
#if defined ZM_COMPILE_FOR_DEBUG
  return formatex(buildId, len, "%s [%s] [DEBUG]", BB_VERSION_STRING, __DATE__);
#else
  return formatex(buildId, len, "%s [%s]", BB_VERSION_STRING, __DATE__);
#endif
}
