#if defined _bb_i18n_included
  #endinput
#endif
#define _bb_i18n_included

#include <amxconst>

/** The dictionary file of Base Builder. */
#define BB_DICTIONARY "zm_basebuilder.txt"

/** The name of BB (default: {@code "Base Builder"}). */
stock const BB_NAME[] = "BB_NAME";
/** The short name of BB (default: {@code "BB"}). */
stock const BB_NAME_SHORT[] = "BB_NAME_SHORT";

/**
 * Returns the path to the Base Builder dictionary.
 */
stock bb_getDictionary(dst[], len) {
  return copy(dst, len, BB_DICTIONARY);
}
