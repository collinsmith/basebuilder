#if defined _bb_zones_const_included
	#endinput
#endif
#define _bb_zones_const_included

#include "include/bb/bb_core_const.inc"

/******************************************************************************************************************************
Data/Definitions
******************************************************************************************************************************/

/**
 * Represents the different zone types within Base Builder.
 */
enum BB_ZONE_TYPE {
	BB_ZONE_INVALID = null,	// Represents an invalid zone (no zone)
	BB_ZONE_TERRITORY = 0,	// Represents a normal territory zone
	BB_ZONE_BUILDER_SPAWN,	// Represents a builder spawn zone
	BB_ZONE_ZOMBIE_SPAWN	// Represents a zombie spawn zone
}