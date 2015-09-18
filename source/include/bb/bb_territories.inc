#if defined _bb_territories_included
	#endinput
#endif
#define _bb_territories_included

#pragma reqlib BB_Territories
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Territories
#endif

#include "include/bb/classes/territory_t.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called when a player is added to a territory.
 * 
 * @param id			Player index added
 * @param territory		Territory added to
 * @param num			Number of players who are in the territory after added
 */
forward bb_fw_ter_addPlayerToTer(id, territory, num);

/**
 * Called when a player is removed from a territory.
 * 
 * @param id			Player index removed
 * @param territory		Territory removed from
 * @param num			Number of players who are in the territory after removed
 */
forward bb_fw_ter_removePlayerFromTer(id, territory, num);

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Retrieves a user's territory.
 * 
 * @param id			Player index to retrieve territory
 * @return				The current territory of this user. NULL for no territory.
 */
native bb_ter_getUserTerritory(id);

/**
 * Retrieves whether or not a user belongs to a specified territory.
 * 
 * @param id			Player index to check
 * @param terEnt		Territory entity to verify with
 * @return				True if the player is in this territory group, otherwise false
 */
native bool:bb_ter_belongsToTerritory(id, terEnt);

/**
 * Retrieves whether or not a territory has been claimed by anyone.
 * 
 * @param terEnt		Territory entity to check
 * @return				True if owned, otherwise false
 */
native bool:bb_ter_isClaimed(terEnt);

/**
 * Unclaims a block from the territory it belongs to.
 * 
 * @param ent			Entity to unclaim
 * @return				True if unclaimed, otherwise false
 */
native bool:bb_ter_unclaimBlock(ent);

/**
 * Claims a block to a territory and unclaims it from the one it belongs to.
 * 
 * @param terEnt		Territory entity to claim entity to
 * @param ent			Entity to claim
 * @return				True if claimed, otherwise false
 */
native bool:bb_ter_claimBlock(terEnt, ent);

/**
 * Checks whether or not a player can move a given entity.
 * 
 * @param id			Player index
 * @param ent			Entity to move
 * @return				True if the player has access, otherwise false
 */
native bool:bb_ter_canMoveBlock(id, ent);

/**
 * Copies a list of a users partners into a specified string.
 * 
 * @param id			Player index whose partners to retrieve
 * @param string		String to place list into
 * @param length		Max length of string to retrieve
 */
native bb_ter_formatPartnerNames(id, string[], length);