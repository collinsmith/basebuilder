#if defined _bb_zones_included
	#endinput
#endif
#define _bb_zones_included

#pragma reqlib BB_Zones
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Zones
#endif

#include "include/bb/bb_zones_const.inc"

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Retrieves the index of the entity (if any) for the zone that
 * a specified entity is in contact with.
 * 
 * @param ent			Entity index to check intersection with
 * @return				Entity index of intersecting zone.
 */
native bb_zone_isWithinZone(ent);

/**
 * Retrieves the BB_ZONE_TYPE representation for the type of zone
 * an entity is.
 * 
 * @param ent			Entity index to check
 * @return				BB_ZONE_TYPE return representing the zone type
 * 						BB_ZONE_INVALID			// Represents an invalid zone (no zone)
 * 						BB_ZONE_TERRITORY		// Represents a normal territory zone
 * 						BB_ZONE_BUILDER_SPAWN	// Represents a builder spawn zone
 * 						BB_ZONE_ZOMBIE_SPAWN	// Represents a zombie spawn zone
 */
native BB_ZONE_TYPE:bb_zone_getZoneType(ent);