#include <amxmodx>
#include <amxmisc>
#include <logger>
#include <reapi>

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_MAPNAME
#else
  //#define DEBUG_MAPNAME
#endif

#define EXTENSION_NAME "Mapname Fixer"
#define VERSION_STRING "1.0.0"

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
      .desc = "Removes version numbers from BB maps");

  fixMapname();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

fixMapname() {
#if defined DEBUG_MAPNAME
  logd("Fixing mapname...");
#endif

  new mapname[32];
  rh_get_mapname(mapname, charsmax(mapname), .type = MNT_SET);
#if defined DEBUG_MAPNAME
  logd("mapname=%s", mapname);
#endif
  if (!equali(mapname, "bb_", 3)) {
#if defined DEBUG_MAPNAME
    logd("Mapname does not start with \"bb_\", ignoring");
#endif
    return;
  }

  new len = strlen(mapname) - 1;
  while (isdigit(mapname[len]) && len >= 0) len--;
  mapname[len + 1] = EOS;
#if defined DEBUG_MAPNAME
  logd("mapname set to \"%s\"", mapname);
#endif
  rh_set_mapname(mapname);
}
