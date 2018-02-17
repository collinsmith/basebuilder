#if defined _basebuilder_included
  #endinput
#endif
#define _basebuilder_included

#pragma reqlib zm_basebuilder

#tryinclude <logger>

#include "include/zm/zombies.inc"

#include "include/bb/bb_entity_consts.inc"
#include "include/bb/bb_builder.inc"
#include "include/bb/bb_director.inc"
#include "include/bb/bb_i18n.inc"
#include "include/bb/bb_misc.inc"
#include "include/bb/bb_version.inc"

/*******************************************************************************
 * NATIVES
 ******************************************************************************/

/**
 * Returns the plugin ID of BB, or {@code INVALID_PLUGIN_ID} if an error
 * occurred. This is used by all core extensions. Extensions which log
 * a lot of information should use their own loggers instead.
 * 
 * @throws IllegalStateException if this function is called before the plugin
 *         has been initialized.
 */
native bb_getPluginId();
