#include <amxmodx>
#include <logger>

#include "include/zm/zombies.inc"

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/bb/bb_i18n.inc"
#include "include/bb/bb_misc.inc"
#include "include/bb/bb_version.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_NATIVES
#else
  //#define DEBUG_NATIVES
#endif

#define EXTENSION_NAME "Base Builder"
#define VERSION_STRING "1.0.0"

static Logger: logger = Invalid_Logger;

public plugin_natives() {
  register_library("zm_basebuilder");

  register_native("bb_getLogger", "native_getLogger");
}

public zm_onInit() {
  logger = LoggerCreate();
#if defined ZM_COMPILE_FOR_DEBUG
  LoggerSetVerbosity(logger, Severity_Lowest);
#endif

  new dictionary[32];
  bb_getDictionary(dictionary, charsmax(dictionary));
  register_dictionary(dictionary);
#if defined DEBUG_I18N
  LoggerLogDebug(logger, "Registering dictionary file \"%s\"", dictionary);
#endif
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  
  new buildId[32];
  bb_getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = name,
      .version = buildId,
      .desc = "Base Builder ZM");

#if defined DEBUG_COMMANDS
  LoggerLogDebug(logger, "Registering console commands...");
#endif
  registerConCmds();
}

registerConCmds() {
  bb_registerConCmd(
      .command = "version",
      .callback = "onPrintVersion",
      .desc = "Prints the version info of BB",
      .access = ADMIN_ALL,
      .logger = logger);
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

//native Logger: zm_getLogger();
public Logger: native_getLogger(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams, logger)) {
    return Invalid_Logger;
  }
#endif

  if (!logger) {
    ThrowIllegalStateException(.msg = "Calling zm_getLogger before logger has been initialized");
    return Invalid_Logger;
  }

  return logger;
}
