#if defined _bb_builder_included
	#endinput
#endif
#define _bb_builder_included

#pragma reqlib BB_Builder
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Builder
#endif

#include "include/bb/bb_builder_const.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called when a user tries to lock an entity. To stop them, return BB_RET_BLOCK.
 * 
 * @param id			Player index attempting to lock a block
 * @param entity		Entity in question
 * @param locker		Owner of the entity
 * @return				BB_RET_BLOCK to block command, otherwise no return neccesary
 */
forward bb_fw_build_blockLock_pre(id, entity, locker);

/**
 * Called after a user locks an entity.
 * 
 * @param id			Player index who locked the entity
 * @param entity		Entity in question
 * @param oldLocker		Previous owner of the entity
 */
forward bb_fw_build_blockLock_post(id, entity, oldLocker);

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Resets all entities to their original locations.
 */
native bb_build_resetEntities();

/**
 * Resets a specified entity to its original location.
 * 
 * @param ent			Entity to reset
 * @return				Always true
 */
native bool:bb_build_resetEntity(ent);

/**
 * Forces a user to drop any entity they might be holding.
 * 
 * @param id			Player index to force command on
 * @return				True if an entity is dropped, otherwise false
 */
native bool:bb_build_forceUserDrop(id);