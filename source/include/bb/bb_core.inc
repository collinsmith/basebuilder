#if defined _bb_core_included
	#endinput
#endif
#define _bb_core_included

#pragma reqlib Base_Builder_80
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib Base_Builder_80
#endif

#include "include/bb/bb_core_const.inc"
#include "include/bb/classes/plugin_t.inc"
#include "include/bb/classes/setting_t.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called upon initialization of the Base Builder core.
 * 
 * @note				Initialize all pertinent data structures here
 */
forward bb_fw_init();

/**
 * Called directly after initialization of the Base Builder core.
 * 
 * @note				Any cache/loading shouldbe done here
 */
forward bb_fw_init_post();

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Registers a new plugin into the Base Builder core.
 * 
 * @param name			The name of the sub-plugin
 * @param description	Brief description of what this sub-plugin does
 * @param version		String representation of the version of this sub-plugin.
 */
native BB_PLUGIN:bb_core_registerPlugin(const name[], const description[], const version[]);

/**
 * Retrieves the index of the cellarray for which the sub-plugin list
 * is stored. The sub-plugin information can, but should not be modified.
 * 
 * @return				Cellarray index for the sub-plugin list
 */
native Array:bb_core_getPluginList();

/**
 * Retrieves the total number of sub-plugins cached within the
 * Base Builder core.
 * 
 * @return				The number of sub-plugins cached.
 */
native bb_core_getPluginNum();