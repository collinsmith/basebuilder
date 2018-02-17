#include <amxmodx>
#include <cstrike>
#include <engine>
#include <logger>

#include "include/zm/zombies.inc"

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/bb/bb_entity_consts.inc"
#include "include/bb/bb_i18n.inc"
#include "include/bb/bb_misc.inc"
#include "include/bb/bb_version.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_ENTITIES
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_ENTITIES
#endif

#define EXTENSION_NAME "Base Builder"
#define VERSION_STRING "1.0.0"

//#define CREATE_BOMBZONE

static bbPluginId = INVALID_PLUGIN_ID;

public plugin_natives() {
  register_library("zm_basebuilder");

  register_native("bb_getPluginId", "native_getPluginId");
}

public zm_onInit() {
#if defined ZM_COMPILE_FOR_DEBUG
  SetGlobalLoggerVerbosity(DebugLevel);
  SetLoggerVerbosity(DebugLevel);
#endif

  new status[16];
  get_plugin(-1, .status = status, .len5 = charsmax(status));
  if (!equal(status, "debug")) {
    SetLoggerFormat(LogMessage, "[%5v] [%t] %s");
  }

  new dictionary[32];
  bb_getDictionary(dictionary, charsmax(dictionary));
  register_dictionary(dictionary);
#if defined DEBUG_I18N
  logd("Registered dictionary \"%s\"", dictionary);
#endif
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");
  
  new buildId[32];
  bb_getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = name,
      .version = buildId,
      .desc = "Base Builder ZM");

  logi("Launching %s v%s...", EXTENSION_NAME, buildId);
  logi("Copyright (C) Collin \"Tirant\" Smith");

  new desc[256];
  formatex(desc, charsmax(desc), "The version of %L used", LANG_SERVER, BB_NAME);
  create_cvar("bb_version", buildId, FCVAR_SPONLY, desc);

  createEntities();
  registerConCmds();
}

registerConCmds() {
#if defined DEBUG_COMMANDS
  logd("Registering console commands...");
#endif
  
  bb_registerConCmd(
      .command = "version",
      .callback = "onPrintVersion",
      .desc = "Prints the version info of BB",
      .access = ADMIN_ALL);
}

createEntities() {
#if defined CREATE_BOMBZONE
#if defined DEBUG_ENTITIES
  logd("Creating info_bomb_target");
#endif
  new info_bomb_target = cs_create_entity("info_bomb_target");
  entity_set_origin(info_bomb_target, Float: { 8192.0, 8192.0, 8192.0 });

#if defined DEBUG_ENTITIES
  logd("Creating info_map_parameters");
#endif
  new info_map_parameters = cs_create_entity("info_map_parameters");
  DispatchKeyValue(info_map_parameters, "buying", "3");
  DispatchKeyValue(info_map_parameters, "bombradius", "1");
  DispatchSpawn(info_map_parameters);
#endif
}

stock findOrCreateEntity(const class_name[]) {
  new const ent = cs_find_ent_by_class(MaxClients, class_name);
  if (!ent) {
    return cs_create_entity(class_name);
  }

  return ent;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onPrintVersion(id) {
  new buildId[32];
  bb_getBuildId(buildId, charsmax(buildId));
  console_print(id, "%L (%L) v%s", id, BB_NAME, id, BB_NAME_SHORT, buildId);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native bb_getPluginId();
public native_getPluginId(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {
    return INVALID_PLUGIN_ID;
  }
#endif

  if (bbPluginId == INVALID_PLUGIN_ID) {
    bbPluginId = get_plugin(-1);
  }
  
  return bbPluginId;
}
