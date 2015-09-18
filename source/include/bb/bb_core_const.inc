#if defined _bb_core_const_included
	#endinput
#endif
#define _bb_core_const_included

/******************************************************************************************************************************
Data/Definitions
******************************************************************************************************************************/

/**
 * Representation for invalid data.
 */
#define null any:cellmin
#define NULL null

/**
 * Return types for the Base Builder core.
 */
#define BB_RETURN: any:
enum BB_RETURN: {
	BB_RET_CONTINUE = 1000,	// Implies operation should continue
	BB_RET_BLOCK,			// Implies operation should be blocked
	BB_RET_SUCCESS,			// Implies that the operation was a success
	BB_RET_ERROR			// Implies there was some kind of error
};

/**
 * Team constants used throughout the plugin.
 */
#define BB_TEAM: any:
enum BB_TEAM:ZP_TEAM_size {
	BB_TEAM_UNASSIGNED = 0,
	BB_TEAM_ZOMBIE,
	BB_TEAM_HUMAN,
	BB_TEAM_SPECTATOR
};

/**
 * Basic macros used for bitsum manipulations.
 */
#define flagGetBool(%1,%2)			(!!flagGet(%1,%2))
#define flagGet(%1,%2)				(%1 & (1<<(%2&31)))
#define flagSet(%1,%2)				(%1 |= (1<<(%2&31)))
#define flagUnset(%1,%2)			(%1 &= ~(1<<(%2&31)))
#define flagToggle(%1,%2)			(%1 ^= (1<<(%2&31)))

/**
 * Defined value for the maximum number of players.
 */
#define MAX_PLAYERS 32

/**
 * Defined value for the version of this plugin.
 */
#define BB_VERSION 8.0.0

/**
 * String representation for the name of this plugin.
 */
stock const BB_PLUGIN_NAME[] = "Base Builder";

/**
 * String representation for the version of this plugin. (Should match BB_VERSION)
 */
stock const BB_PLUGIN_VERSION[] = "8.0.0"

/**
 * String representation for the path of the BB home folder through amxmodx/configs/
 */
stock const BB_HOME_DIR[] = "bb/";

/**
 * Defined macro to make typing sound commands easier.
 * 
 * @param %1		Player index to play sound for
 * @param %2		Path to the sound to play
 */
#define bb_playSound(%1,%2) client_cmd(%1,"spk %s",%2)

/******************************************************************************************************************************
Stocks
******************************************************************************************************************************/

/**
 * Fills a given string with the home directory of Base Builder.
 * 
 * @param string		The string to place the path into
 * @param length		The maximum length of the string
 * @return				The total length of this path
 */
stock bb_getHomeDir(string[], length) {
	new curLen = get_configsdir(string, length);
	string[curLen++] = '/';
	return curLen+copy(string[curLen], length, BB_HOME_DIR);
}