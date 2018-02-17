#include <amxmodx>
#include <amxmisc>
#include <logger>

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_builder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_ENTITIES
#else
  //#define DEBUG_ENTITIES
#endif

#define EXTENSION_NAME "Reset PVS (in-wall)"
#define VERSION_STRING "1.0.0"

public zm_onInit() {
  LoadLogger(bb_getPluginId());
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

public bb_onDropped(const id, const entity) {
  if (!bb_isInPlayerPVS(id, entity)) {
    client_print(id, print_center, "%L", id, "CANNOT_BUILD_IN_MAP");
    bb_reset(entity);
  }
}
