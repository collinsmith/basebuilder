#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <logger>

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_ENTITIES
  //#define DEBUG_ZONES
#else
  //#define DEBUG_ENTITIES
  //#define DEBUG_ZONES
#endif

#define EXTENSION_NAME "Compatibility"
#define VERSION_STRING "1.0.0"

public zm_onInit() {
  LoadLogger(bb_getPluginId());
  fixEntities();
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");
  
  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = name,
      .version = buildId,
      .desc = "");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

fixEntities() {
  fixBarrier();
  fixIgnore();
  fixZone(BB_BUILDER_SPAWN);
  fixZone(BB_ZOMBIE_SPAWN);
  fixZone(BB_TERRITORY);
}

fixBarrier() {
#if defined DEBUG_ENTITIES
  logd("Locating barrier entities...");
#endif
  new count = 0, first = 0;
  for (new i = 0; i < sizeof BB_BARRIER; i++) {
    new barrier = MaxClients;
    while ((barrier = find_ent_by_tname(barrier, BB_BARRIER[i])) > 0) {
#if defined DEBUG_ENTITIES
      logd("barrier=%d", barrier);
#endif
      cs_set_ent_class(barrier, BB_BARRIER[0]);
      count++;
      if (first == 0) {
        first = barrier;
      }
    }
  }

#if defined DEBUG_ENTITIES
  logd("%d barriers found", count);
#endif
  if (count > 1) {
    logw("%d barriers found, only %d will be used", count, first);
  }
}

fixIgnore() {
#if defined DEBUG_ENTITIES
  logd("Locating ignored entities...");
  new count = 0;
#endif
  for (new i = 0; i < sizeof BB_IGNORE; i++) {
    new ignore = MaxClients;
    while ((ignore = find_ent_by_tname(ignore, BB_IGNORE[i])) > 0) {
#if defined DEBUG_ENTITIES
      logd("ignore=%d", ignore);
      count++;
#endif
      cs_set_ent_class(ignore, BB_IGNORE[0]);
    }
  }

#if defined DEBUG_ENTITIES
  logd("%d ignored found", count);
#endif
}

logInfo(entity) {
#if !defined DEBUG_ENTITIES
#pragma unused logInfo
#endif
  new Float: origin[3], Float: mins[3], Float: maxs[3];
  entity_get_vector(entity, EV_VEC_origin, origin);
  entity_get_vector(entity, EV_VEC_mins, mins);
  entity_get_vector(entity, EV_VEC_maxs, maxs);
  logd("%d ORIGIN:{%.1f,%.1f,%.1f}, MINS:{%.1f,%.1f,%.1f}, MAXS:{%.1f,%.1f,%.1f}",
      entity,
      origin[0], origin[1], origin[2],
      mins[0], mins[1], mins[2],
      maxs[0], maxs[1], maxs[2]);
}

fixZone(const classname[]) {
#if defined DEBUG_ENTITIES
  logd("Locating %s entities...", classname);
#endif
  new count = 0;
  new entity = MaxClients;
  new Float: mins[3], Float: maxs[3];
  while ((entity = find_ent_by_tname(entity, classname)) > 0) {
#if defined DEBUG_ENTITIES
    logd("%s=%d", classname, entity);
    logInfo(entity);
#endif
    cs_set_ent_class(entity, classname);
    entity_set_int(entity, EV_INT_solid, SOLID_TRIGGER);

    entity_get_vector(entity, EV_VEC_mins, mins);
    entity_get_vector(entity, EV_VEC_maxs, maxs);
    entity_set_size(entity, mins, maxs);
    
#if !defined DEBUG_ZONES
    entity_set_int(entity, EV_INT_rendermode, kRenderTransColor);
    entity_set_vector(entity, EV_VEC_rendercolor, NULL_VECTOR);
    entity_set_float(entity, EV_FL_renderamt, 0.0);
#endif

    count++;
  }

#if defined DEBUG_ENTITIES
  logd("%d %s found", count, classname);
#endif
}
