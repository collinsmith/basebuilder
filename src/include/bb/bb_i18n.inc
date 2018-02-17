#if defined _bb_i18n_included
  #endinput
#endif
#define _bb_i18n_included

#include <amxconst>

/** The dictionary file of Base Builder. */
#define BB_DICTIONARY "zm_basebuilder.txt"

/** {@code "Base Builder"} */
stock const BB_NAME[] = "BB_NAME";
/** {@code "BB"} */
stock const BB_NAME_SHORT[] = "BB_NAME_SHORT";
/** {@code "Map not supported. Barrier entity could not be located."} */
stock const BARRIER_NOT_FOUND[]="BARRIER_NOT_FOUND";
/** {@code "pushing..."} */
stock const PUSHING[] = "PUSHING";
/** {@code "pulling..."} */
stock const PULLING[] = "PULLING";
/** {@code "Maximum distance reached!"} */
stock const PUSHED_MAX_DIST[] = "PUSHED_MAX_DIST";
/** {@code "Minimum distance reached!"} */
stock const PUSHED_MIN_DIST[] = "PUSHED_MIN_DIST";
/** {@code "Please don't place objects in walls!"} */
stock const CANNOT_BUILD_IN_MAP[] = "CANNOT_BUILD_IN_MAP";
/** {@code "The timer has been paused"} */
stock const TIMER_PAUSED[] = "TIMER_PAUSED";
/** {@code "The timer has resumed"} */
stock const TIMER_RESUMED[] = "TIMER_RESUMED";
/** {@code "You will respawn in %.1f seconds"} */
stock const RESPAWN_IN_X[] = "RESPAWN_IN_X";

/**
 * Returns the path to the Base Builder dictionary.
 */
stock bb_getDictionary(dst[], len) {
  return copy(dst, len, BB_DICTIONARY);
}
