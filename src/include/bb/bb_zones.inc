#if defined _bb_zones_included
    #endinput
#endif
#define _bb_zones_included

#include "include/bb/bb_zones_consts.inc"

forward bb_onTouchTerritory(const id, const entity);
forward bb_onTouchBuilderSpawn(const id, const entity);
forward bb_onTouchZombieSpawn(const id, const entity);

native Zone: bb_getTouching(const entity);
native bool: bb_isTouching(const entity, const Zone: zoneType);
