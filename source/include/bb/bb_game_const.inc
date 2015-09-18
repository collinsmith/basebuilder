#if defined _bb_game_const_included
	#endinput
#endif
#define _bb_game_const_included

/******************************************************************************************************************************
Data/Definitions
******************************************************************************************************************************/

/**
 * Represents the different game states within Base Builder.
 */
enum BB_GAMESTATE {
	BB_GAMESTATE_INVALID = 0,	// Implies the game is between rounds
	BB_GAMESTATE_BUILDPHASE,	// Implies build phase
	BB_GAMESTATE_PREPPHASE,		// Implies preparation phase
	BB_GAMESTATE_RELEASE,		// Implies zombies have been released
	BB_GAMESTATE_ROUNDEND		// Implies the round has ended and waiting for new one to begin
}