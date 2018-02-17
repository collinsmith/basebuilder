#if defined _bb_director_included
    #endinput
#endif
#define _bb_director_included

#pragma reqlib bb_director

#include "include/bb/bb_director_consts.inc"

/*******************************************************************************
 * FORWARDS
 ******************************************************************************/

/**
 * Called when the barrier has been detected and basic configurations have been
 * performed.
 *
 * @param barrier Entity id of the barrier
 *
 * @noreturn
 */
forward bb_onBarrierSetup(const barrier);

/**
 * Called when the game state has been changed.
 * 
 * @param fromState Previous game state, or {@code Invalid_GameState} if there
 *                    was no previous game state
 * @param toState   Current game state
 * 
 * @noreturn
 */
forward bb_onGameStateChanged(const GameState: fromState, const GameState: toState);

/**
 * Called when a new round has begun, at the start of freeze time.
 * 
 * @noreturn
 */
forward bb_onNewRound();

/**
 * Called when a new round has begun, after freeze time, typically at the start
 * of the {@code BuildPhase} game state.
 * 
 * @noreturn
 */
forward bb_onRoundStart();

/**
 * Called when a round has ended, typically at the start of the
 * {@code RoundEnding} game state.
 * 
 * @noreturn
 */
forward bb_onRoundEnd();

/**
 * Called when the round timer has been paused. During this time, game states
 * will not progress automatically.
 * 
 * @noreturn
 */
forward bb_onPause();

/**
 * Called when the round timer has resumed.
 * 
 * @noreturn
 */
forward bb_onResume();

/**
 * Called when the round timer has been updated. The round timer will update
 * about once every tenth of a second.
 * 
 * @param timeleft  Time remaining on the round timer, in deciseconds
 * @param gameState Game state of Base Builder
 * 
 * @noreturn
 */
forward bb_onRoundTimerUpdated(const timeleft, const GameState: gameState);

/**
 * Called when the respawn timer has been updated for a given player.
 * The respawn timer will update about once every tenth of a second.
 * 
 * @param id       The player associated with this respawn timer
 * @param timeleft Time remaining until the player is respawned, in deciseconds
 */
forward bb_onRespawnTimerUpdated(const id, const timeleft);

/*******************************************************************************
 * NATIVES
 ******************************************************************************/
  
/**
 * Returns the current game state of Base Builder:
 *   {@code Invalid_GameState} - The game state has not yet been set up
 *   {@code RoundStarting} - The game is preparing to start, during freeze time
 *   {@code BuildPhase} - Zombies are locked up and the Humans can start building their bases
 *   {@code PrepPhase} - Zombies are locked up and Humans must test their bases
 *   {@code Released} - Zombies are released and round begins
 *   {@code RoundEnding} - The time limit has expired and a new round is about to begin
 */
native GameState: bb_getGameState();

/**
 * Changes the game state of Base Builder and returns the previous state.
 */
native GameState: bb_setGameState(const GameState: toState);

/**
 * Indicates whether or not the barrier is currently enabled. An enabled barrier
 * will be solid and prevent the zombie team from exiting their spawn area.
 */
native bool: bb_isBarrierEnabled();

/**
 * Sets whether or not the barrier should be enabled and returns the previous
 * state of the barrier, with {@code true} indicating that the barrier was
 * enabled.
 */
native bool: bb_setBarrierEnabled(const bool: b);

/**
 * Returns the amount of time remaining on the round timer, in deciseconds.
 */
native bb_getRoundTime();
