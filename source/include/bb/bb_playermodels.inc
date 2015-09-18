#if defined _bb_playermodels_included
	#endinput
#endif
#define _bb_playermodels_included

#pragma reqlib BB_PlayerModels
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_PlayerModels
#endif

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Registers and precaches a given model into the Base Builder cache.
 * 
 * @param model		Name of the model to load
 * @return			Index given to this model, BB_MODEL:null for not found/error.
 */
native BB_MODEL:bb_mdl_registerModel(const model[]);

/**
 * Retrieves the model index for the model under a specified name.
 * 
 * @param model		Name of the model to look up
 * @return			Index of the model, BB_MODEL:null for not found/error.
 */
native BB_MODEL:bb_mdl_getModelByName(const model[]);

/**
 * Sets a specified model index on a player.
 * 
 * @param id		Player index to set model onto
 * @param model		Model index to set
 */
native bb_mdl_setModel(id, BB_MODEL:model);

/**
 * Resets a user's model to their default one.
 * 
 * @param id		Player index to reset model for
 */
native bb_mdl_resetModel(id);