#if defined _bb_zombies_included
	#endinput
#endif
#define _bb_zombies_included

#pragma reqlib BB_Zombies
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Zombies
#endif

#include "include/bb/bb_zombies_const.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called when applying a user's traits.
 * 
 * @param id			Player index calling event
 * @param isZombie		True if they are a zombie, otherwise false
 */
forward bb_fw_zm_refresh(id, bool:isZombie);

/**
 * Called when a player is being infected and becoming a zombie. Return
 * BB_RET_BLOCK to block the infection.
 * 
 * @param id			Player index being infected
 * @param infector		Player index infecting, -1 if no player
 */
forward bb_fw_zm_infect_pre(id, infector);

/**
 * Called when a player is being infected just before actually becoming
 * a zombie.
 * 
 * @param id			Player index being infected
 * @param infector		Player index infecting, -1 if no player
 */
forward bb_fw_zm_infect(id, infector);

/**
 * Called when a player is being infected after becoming a zombie.
 * 
 * @param id			Player index being infected
 * @param infector		Player index infecting, -1 if no player
 */
forward bb_fw_zm_infect_post(id, infector);

/**
 * Called when a player is being cured and becoming a human. Return
 * BB_RET_BLOCK to block the cure.
 * 
 * @param id			Player index being cured
 * @param curer			Player index curing, -1 if no player
 */
forward bb_fw_zm_cure_pre(id, curer);

/**
 * Called when a player is being cured just before actually becoming
 * a human.
 * 
 * @param id			Player index being cured
 * @param curer			Player index curing, -1 if no player
 */
forward bb_fw_zm_cure(id, curer);

/**
 * Called when a player is being cured after becoming a human.
 * 
 * @param id			Player index being cured
 * @param curer			Player index curing, -1 if no player
 */
forward bb_fw_zm_cure_post(id, curer);

/**
 * Called when a player spawns.
 * 
 * @param id			Player index spawning
 * @param isZombie		True if the player is a zombie, otherwise false
 */
forward bb_fw_zm_playerSpawn(id, bool:isZombie);

/**
 * Called when a player is killed.
 * 
 * @param killer		Player index who killed the victim
 * @param victim		Player index of dead player
 */
forward bb_fw_zm_playerDeath(killer, victim);

/**
 * Called when a player uses the change team command and is blocked.
 * 
 * @note				This is primarily meant to be used to trigger
 * 						the menu to open.
 * 
 * @param id			Player index who tried to change teams
 */
forward bb_fw_zm_blockTeamChange(id);

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Revives a user.
 * 
 * @param id			Player index to revive
 * @param force			True to force a respawn, otherwise false will only respawn
 * 						the user if they are dead
 */
native bb_zm_respawnUser(id, bool:force = false);

/**
 * Infects a player and attempts to turn them into a zombie.
 * 
 * @param id			Player index to infect
 * @param infector		Player index infecting the above player, -1 if not a player
 * @param blockable		True to make this infection blockable by other plugins
 * 						via an antivirus or such, otherwise false
 * @return				BB_STATE_INVALID	Implies player is dead or otherwise cannot be changed
 * 						BB_STATE_CHANGE		Implies that the player's state has been changed
 * 						BB_STATE_NOCHANGE	Implies that the player's state cannot be changed
 */
native BB_PLAYERSTATE:bb_zm_infectUser(id, infector = -1, bool:blockable = true);

/**
 * Cures a player and attempts to turn them into a human.
 * 
 * @param id			Player index to cure
 * @param infector		Player index curing the above player, -1 if not a player
 * @param blockable		True to make this cure blockable by other plugins
 * 						via an supervirus or such, otherwise false
 * @return				BB_STATE_INVALID	Implies player is dead or otherwise cannot be changed
 * 						BB_STATE_CHANGE		Implies that the player's state has been changed
 * 						BB_STATE_NOCHANGE	Implies that the player's state cannot be changed
 */
native BB_PLAYERSTATE:bb_zm_cureUser(id, curer = -1, bool:blockable = true);

/**
 * Retrieves whether or not a player is currently connected.
 * 
 * @param id			Player index to check
 * @return				True if the player is connected, otherwise false
 */
native bool:bb_zm_isUserConnected(id);

/**
 * Retrieves whether or not a player is currently alive.
 * 
 * @param id			Player index to check
 * @return				True if the player is alive, otherwise false
 */
native bool:bb_zm_isUserAlive(id);

/**
 * Retrieves whether or not a player is currently a zombie.
 * 
 * @param id			Player index to check
 * @return				True if the player is a zombie, otherwise false
 */
native bool:bb_zm_isUserZombie(id);

/**
 * Checks if a player is on the correct team and then fixes their
 * team if it needs to be changed.
 * 
 * @param id			Player index whose infection to fix
 */
native bb_zm_fixInfection(id);