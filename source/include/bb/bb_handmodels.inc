#if defined _bb_handmodels_included
	#endinput
#endif
#define _bb_handmodels_included

#pragma reqlib BB_HandModels
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_HandModels
#endif

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Registers and precaches a given model into the Base Builder cache.
 * 
 * @param model		Name of the model to load
 * @return			Index given to this model, BB_HANDMODEL:null for not found/error.
 */
native BB_HANDMODEL:bb_handmdl_registerModel(const model[]);

/**
 * Retrieves the model index for the model under a specified name.
 * 
 * @param model		Name of the model to look up
 * @return			Index of the model, BB_HANDMODEL:null for not found/error.
 */
native BB_HANDMODEL:bb_handmdl_getModelByName(const model[]);

/**
 * Sets a specified hand model index on a player.
 * 
 * @param id		Player index to set model onto
 * @param model		Hand model index to set
 */
native bb_handmdl_setModel(id, BB_HANDMODEL:model);

/**
 * Resets a user's hand model to their default one.
 * 
 * @param id		Player index to reset model for
 */
native bb_handmdl_resetModel(id);