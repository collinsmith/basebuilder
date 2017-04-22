#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <logger>

#include "include/zm/zombies.inc"

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/bb/bb_builder_consts.inc"
#include "include/bb/bb_i18n.inc"
#include "include/bb/bb_misc.inc"
#include "include/bb/bb_version.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_NATIVES
  #define DEBUG_ENTITIES
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_ENTITIES
#endif

#define EXTENSION_NAME "Base Builder"
#define VERSION_STRING "1.0.0"

#define BARRIER_COLOR Float: { 0.0, 0.0, 0.0 }
#define BARRIER_OPACITY 150.0

#define CHECK_FOR_UPDATES

static barrier;

public plugin_natives() {
  register_library("zm_basebuilder");

  register_native("bb_getLogger", "native_getLogger");
}

public zm_onInit() {
#if defined ZM_COMPILE_FOR_DEBUG
  LoggerSetVerbosity(This_Logger, Severity_Lowest);
#endif

  new dictionary[32];
  bb_getDictionary(dictionary, charsmax(dictionary));
  register_dictionary(dictionary);
#if defined DEBUG_I18N
  LoggerLogDebug("Registering dictionary file \"%s\"", dictionary);
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

#if defined DEBUG_COMMANDS
  LoggerLogDebug("Registering console commands...");
#endif
  registerConCmds();

  createEntities();

  register_event("HLTV", "onRoundStart", "a", "1=0", "2=0");
  register_logevent("onRoundStartLogged", 2, "1=Round_Start");
  register_logevent("onRoundEndLogged", 2, "1=Round_End");

  setupBarrier();
}

registerConCmds() {
  bb_registerConCmd(
      .command = "version",
      .callback = "onPrintVersion",
      .desc = "Prints the version info of BB",
      .access = ADMIN_ALL);
}

setupBarrier() {
#if defined DEBUG_ENTITIES
  LoggerLogDebug("Locating barrier entity...");
#endif
  barrier = findBarrier();
  if (!barrier) {
    new error[128], lang_server = LANG_SERVER;
    LookupLangKey(error, charsmax(error), "BARRIER_NOT_FOUND", lang_server);
    LoggerLogError(error);
    set_fail_state(error);
  }

#if defined DEBUG_ENTITIES
  LoggerLogDebug("barrier=%d", barrier);
#endif
  entity_set_string(barrier, EV_SZ_classname, BB_BARRIER[0]);
  set_pev(barrier, pev_rendermode, kRenderTransColor);
  set_pev(barrier, pev_rendercolor, BARRIER_COLOR);
  set_pev(barrier, pev_renderamt, BARRIER_OPACITY);
}

findBarrier() {
  for (new i = 0; i < sizeof BB_BARRIER; i++) {
    new barrier = find_ent_by_tname(MaxClients, BB_BARRIER[i]);
    if (barrier) {
      return barrier;
    }
  }

  return 0;
}

createEntities() {
#if defined DEBUG_ENTITIES
  LoggerLogDebug("Creating info_bomb_target");
#endif
  new info_bomb_target = findOrCreateEntity("info_bomb_target");
  entity_set_origin(info_bomb_target, Float: { 8192.0, 8192.0, 8192.0 });

#if defined DEBUG_ENTITIES
  LoggerLogDebug("Creating info_map_parameters");
#endif
  new info_map_parameters = findOrCreateEntity("info_bomb_target");
  DispatchKeyValue(info_map_parameters, "buying", "3");
  DispatchKeyValue(info_map_parameters, "bombradius", "1");
  DispatchSpawn(info_map_parameters);
}

stock findOrCreateEntity(const class_name[]) {
  new const ent = cs_find_ent_by_class(MaxClients, class_name);
  if (!ent) {
    return cs_create_entity(class_name);
  }

  return ent;
}

public onRoundStart() {
}

public onRoundStartLogged() {
}

public onRoundEndLogged() {
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

//native Logger: bb_getLogger();
public Logger: native_getLogger(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {
    return Invalid_Logger;
  }
#endif

  return LoggerGetThis();
}
