#if defined _bb_misc_included
  #endinput
#endif
#define _bb_misc_included

#include "include/zm/zm_debug.inc"

#include "include/stocks/misc_stocks.inc"
#include "include/stocks/string_utils.inc"

#include "include/bb/bb_i18n.inc"

/**
 * Registers and logs a console command. {@code command} will automatically be
 * prefixed with {@code "bb."}.
 * 
 * @param command  The command, which when typed in the console, will call the
 *                   function specified by {@code callback}. The command will
 *                   automatically be prepended with {@code "zm."}, so commands
 *                   are of the format {@code "zm.${command}"}. Additionally,
 *                   multiple aliases can be entered, separated by a comma,
 *                   e.g., {@code "cmd,command"}.
 * @param callback The name of the function to call when the command is executed
 * @param desc     A brief description of the command
 * @param access   The required privileges to execute the command
 * 
 * @return The idenfitifier assigned to the command by {@link #register_concmd},
 *         or {@code 0} on failure. If multiple aliases are registered at once,
 *         then the identifier for the first successfully registered one is
 *         returned.
 * 
 * @throws IllegalArgumentException if {@code command} or {@code callback} is
 *         empty.
 */
stock bb_registerConCmd(const command[], const callback[], const desc[],
                        const access = ADMIN_CFG) {
  new bb[8], lang = LANG_SERVER;
  LookupLangKey(bb, charsmax(bb), BB_NAME_SHORT, lang);
  strtolower(bb);
#if defined DEBUG_COMMANDS
  return registerConCmd(bb, command, callback, desc, access, true);
#else
  return registerConCmd(bb, command, callback, desc, access, false);
#endif
}
