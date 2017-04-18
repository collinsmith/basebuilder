#include <amxmodx>
#include <logger>

#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "Base Builder"
#define VERSION_STRING "1.0.0"

static Logger: logger = Invalid_Logger;

public zm_onInit() {
  logger = LoggerCreate();
#if defined ZM_COMPILE_FOR_DEBUG
  LoggerSetVerbosity(logger, Severity_Lowest);
#endif
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);
  
  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Core of Base Builder");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len - 1, "%s [%s]", VERSION_STRING, __DATE__);
}

stock 
