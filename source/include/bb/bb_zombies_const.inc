#if defined _bb_zm_const_included
	#endinput
#endif
#define _bb_zm_const_included

/******************************************************************************************************************************
Data/Definitions
******************************************************************************************************************************/

/**
 * Player state returns types.
 */
enum BB_PLAYERSTATE {
	BB_STATE_INVALID = 2000,	// Implies player is dead or otherwise cannot be changed
	BB_STATE_CHANGE,			// Implies that the player's state has been changed
	BB_STATE_NOCHANGE			// Implies that the player's state cannot be changed
};