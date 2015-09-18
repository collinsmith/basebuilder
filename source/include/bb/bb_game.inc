#if defined _bb_game_included
	#endinput
#endif
#define _bb_game_included

#pragma reqlib BB_Game
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Game
#endif

#include "include/bb/bb_game_const.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called on a new round event (before freeze time).
 */
forward bb_fw_game_newRound();

/**
 * Called when a round starts (after freeze time).
 */
forward bb_fw_game_roundStart();

/**
 * Called when a round ends.
 */
forward bb_fw_game_roundEnd();

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Retrieves the current state of the game.
 * 
 * @return				Base Builder's current round state.
 * 						BB_GAMESTATE_INVALID	// Implies the game is between rounds
 * 						BB_GAMESTATE_BUILDPHASE	// Implies build phase
 * 						BB_GAMESTATE_PREPPHASE	// Implies preparation phase
 * 						BB_GAMESTATE_RELEASE	// Implies zombies have been released
 * 						BB_GAMESTATE_ROUNDEND	// Implies the round has ended and waiting for new one to begin
 */
native BB_GAMESTATE:bb_game_getGameState();

/**
 * Retrieves the index of the barrier entity.
 * 
 * @return				Barrier ent index, null for none
 */
native bb_game_getBarrier();