#include <amxmisc>
#include <logger>
#include <reapi>
#include <regex>

#include "include/commands/commands.inc"

#include "include/stocks/string_utils.inc"

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_VERSION
#else
  //#define DEBUG_VERSION
#endif

#define EXTENSION_NAME "Version"
#define VERSION_STRING "1.0.0"

static gameDescription[32];

public zm_onInit() {
  LoadLogger(bb_getPluginId());
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, VERSION_STRING, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Sets the game description string");
  
  configureModName();
  //register_forward(FM_GetGameDescription, "onGetGameDescription");

  new desc[256];
  formatex(desc, charsmax(desc), "The version of %L used", LANG_PLAYER, BB_NAME);
  cmd_registerCommand(
      .alias = "version",
      .handle = "onPrintVersion",
      .desc = desc);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

configureModName() {
  assert isStringEmpty(gameDescription);
#if defined DEBUG_VERSION
  logd("Configuring mod name (FM_GetGameDescription)");
#endif

  new const maxLen = charsmax(gameDescription);
  new len = formatex(gameDescription, maxLen, "%L ", LANG_SERVER, BB_NAME);

  new Regex: regex = regex_match(BB_VERSION_STRING, "^\\d+\\.\\d+");
  regex_substr(regex, 0, gameDescription[len], maxLen - len);
  regex_free(regex);
#if defined DEBUG_VERSION
  logd("Mod name set to \"%s\"", gameDescription);
#endif
  set_member_game(m_GameDesc, gameDescription);
}

/*public onGetGameDescription() {
  forward_return(FMV_STRING, gameDescription);
#if defined DEBUG_VERSION
  logd("gameDescription=\"%s\"", gameDescription);
#endif
  return FMRES_SUPERCEDE;
}*/

public onPrintVersion(id) {
  new buildId[32];
  bb_getBuildId(buildId, charsmax(buildId));
  zm_printColor(id, "%L (%L) v%s", id, BB_NAME, id, BB_NAME_SHORT, buildId);
  return PLUGIN_HANDLED;
}
