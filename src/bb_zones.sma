#define _bb_zones_included

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <logger>
#include <xs>

#include "include/stocks/param_stocks.inc"

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_builder.inc"
#include "include/bb/bb_zones_consts.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_ZONES
  //#define DEBUG_TOUCHING
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_ZONES
  //#define DEBUG_TOUCHING
#endif

#define EXTENSION_NAME "Zones"
#define VERSION_STRING "1.0.0"

static fwReturn = 0;
static onTouchTerritory = INVALID_HANDLE;
static onTouchBuilderSpawn = INVALID_HANDLE;
static onTouchZombieSpawn = INVALID_HANDLE;
static onEnterZone = INVALID_HANDLE;
static onExitZone = INVALID_HANDLE;

static Zone: pState[MAX_PLAYERS + 1];

public plugin_natives() {
  register_library("bb_zones");

  register_native("bb_isTouching", "native_isTouching", 0);
  register_native("bb_getTouching", "native_getTouching", 0);
}

public zm_onInit() {
  LoadLogger(bb_getPluginId());
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  
  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages zones and zone touch events");

  createForwards();

  register_touch(BB_TERRITORY, "player", "fw_onTouchTerritory");
  register_touch(BB_BUILDER_SPAWN, "player", "fw_onTouchBuilderSpawn");
  register_touch(BB_ZOMBIE_SPAWN, "player", "fw_onTouchZombieSpawn");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

createForwards() {
  createOnTouchTerritory();
  createOnTouchBuilderSpawn();
  createOnTouchZombieSpawn();
}

createOnTouchTerritory() {
#if defined DEBUG_FORWARDS
  assert onTouchTerritory == INVALID_HANDLE;
  logd("Creating forward for bb_onTouchTerritory");
#endif
  onTouchTerritory = CreateMultiForward("bb_onTouchTerritory", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  logd("onTouchTerritory = %d", onTouchTerritory);
#endif
}

createOnTouchBuilderSpawn() {
#if defined DEBUG_FORWARDS
  assert onTouchBuilderSpawn == INVALID_HANDLE;
  logd("Creating forward for bb_onTouchBuilderSpawn");
#endif
  onTouchBuilderSpawn = CreateMultiForward("bb_onTouchBuilderSpawn", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  logd("onTouchBuilderSpawn = %d", onTouchBuilderSpawn);
#endif
}

createOnTouchZombieSpawn() {
#if defined DEBUG_FORWARDS
  assert onTouchZombieSpawn == INVALID_HANDLE;
  logd("Creating forward for bb_onTouchZombieSpawn");
#endif
  onTouchZombieSpawn = CreateMultiForward("bb_onTouchZombieSpawn", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  logd("onTouchZombieSpawn = %d", onTouchZombieSpawn);
#endif
}

bb_onEnterZone(const id, const zone, const Zone: type) {
  if (onEnterZone == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onEnterZone");
#endif
    onEnterZone = CreateMultiForward(
        "bb_onEnterZone", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onEnterZone = %d", onEnterZone);
#endif
  }

#if defined DEBUG_FORWARDS && defined DEBUG_RESPAWNTIMER
  logd("Forwarding bb_onEnterZone(%d, %d, %d) for %N", id, zone, type, id);
#endif
  ExecuteForward(onEnterZone, _, id, zone, type);
}

bb_onExitZone(const id, const zone, const Zone: type) {
  if (onExitZone == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onExitZone");
#endif
    onExitZone = CreateMultiForward(
        "bb_onExitZone", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onExitZone = %d", onExitZone);
#endif
  }

#if defined DEBUG_FORWARDS && defined DEBUG_RESPAWNTIMER
  logd("Forwarding bb_onExitZone(%d, %d, %d) for %N", id, zone, type, id);
#endif
  ExecuteForward(onExitZone, _, id, zone, type);
}

public client_disconnected(id) {
  pState[id] = Zone_None;
}

public fw_onTouchTerritory(entity, id) {
#if defined DEBUG_ZONES
  logd("%N touched %d (%s)", id, entity, BB_TERRITORY);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onTouchTerritory(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onTouchTerritory, fwReturn, id, entity);
  pState[id] |= Territory;
}

public fw_onTouchBuilderSpawn(entity, id) {
#if defined DEBUG_ZONES
  logd("%N touched %d (%s)", id, entity, BB_BUILDER_SPAWN);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onTouchBuilderSpawn(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onTouchBuilderSpawn, fwReturn, id, entity);
  pState[id] |= BuilderSpawn;
}

public fw_onTouchZombieSpawn(entity, id) {
#if defined DEBUG_ZONES
  logd("%N touched %d (%s)", id, entity, BB_ZOMBIE_SPAWN);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onTouchZombieSpawn(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onTouchZombieSpawn, fwReturn, id, entity);
  pState[id] |= ZombieSpawn;
}

bool: isWithin(entity1, entity2) {
  static Float: entity1Origin[3], Float: entity1Mins[3], Float: entity1Maxs[3];
  entity_get_vector(entity1, EV_VEC_origin, entity1Origin);
  entity_get_vector(entity1, EV_VEC_mins, entity1Mins);
  xs_vec_add(entity1Origin, entity1Mins, entity1Mins);
  entity_get_vector(entity1, EV_VEC_maxs, entity1Maxs);
  xs_vec_add(entity1Origin, entity1Maxs, entity1Maxs);

  static Float: entity2Origin[3], Float: entity2OriginMins[3], Float: entity2OriginMaxs[3];
  entity_get_vector(entity2, EV_VEC_origin, entity2Origin);
  entity_get_vector(entity2, EV_VEC_mins, entity2OriginMins);
  xs_vec_add(entity2Origin, entity2OriginMins, entity2OriginMins);
  entity_get_vector(entity2, EV_VEC_maxs, entity2OriginMaxs);
  xs_vec_add(entity2Origin, entity2OriginMaxs, entity2OriginMaxs);

  return (entity1Mins[0] < entity2OriginMaxs[0]) && (entity1Maxs[0] > entity2OriginMins[0])
      && (entity1Mins[1] < entity2OriginMaxs[1]) && (entity1Maxs[1] > entity2OriginMins[1])
      && (entity1Mins[2] < entity2OriginMaxs[2]) && (entity1Maxs[2] > entity2OriginMins[2]);
}

bool: isWithinAny(entity, const classname[]) {
  new zone = MaxClients;
  while ((zone = cs_find_ent_by_class(zone, classname)) != 0) {
#if defined DEBUG_TOUCHING
    logd("Checking %d within %s #%d", entity, classname, zone);
#endif
    if (isWithin(entity, zone)) {
      return true;
    }
  }

  return false;
}

bool: isTouching(entity, Zone: zoneType) {
  if ((zoneType & BuilderSpawn) == BuilderSpawn) {
    if (isWithinAny(entity, BB_BUILDER_SPAWN)) {
      return true;
    }
  }
  if ((zoneType & ZombieSpawn) == ZombieSpawn) {
    if (isWithinAny(entity, BB_ZOMBIE_SPAWN)) {
      return true;
    }
  }
  if ((zoneType & Territory) == Territory) {
    if (isWithinAny(entity, BB_TERRITORY)) {
      return true;
    }
  }

  return false;
}

Zone: getTouching(entity) {
  new Zone: touching = Zone_None;

  new zone = MaxClients;
  while ((zone = cs_find_ent_by_class(zone, BB_BUILDER_SPAWN)) != 0) {
    if (isWithin(entity, zone)) {
      touching |= BuilderSpawn;
      break;
    }
  }

  zone = MaxClients;
  while ((zone = cs_find_ent_by_class(zone, BB_ZOMBIE_SPAWN)) != 0) {
    if (isWithin(entity, zone)) {
      touching |= ZombieSpawn;
      break;
    }
  }

  zone = MaxClients;
  while ((zone = cs_find_ent_by_class(zone, BB_TERRITORY)) != 0) {
    if (isWithin(entity, zone)) {
      touching |= Territory;
      break;
    }
  }

  return touching;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native bool: bb_isTouching(const entity, const Zone: zoneType);
public bool: native_isTouching(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return;
  }
#endif

  new const entity = get_param(1);
  new const Zone: zoneType = Zone:(get_param(2));
  if (isValidId(entity)) {
    new const id = entity;
    if (!is_user_connected(id)) {
      ThrowIllegalArgumentException("Player with id is not connected: %d", id);
      return false;
    }

    return (pState[id] & zoneType) != Zone_None;
  }

  return isTouching(entity, zoneType);
}

//native Zone: bb_getTouching(const entity);
public Zone: native_getTouching(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return;
  }
#endif

  new const entity = get_param(1);
  if (isValidId(entity)) {
    new const id = entity;
    if (!is_user_connected(id)) {
      ThrowIllegalArgumentException("Player with id is not connected: %d", id);
      return Zone_None;
    }

    return pState[id];
  }
  
  return getTouching(entity);
}
