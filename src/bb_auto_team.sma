#include <logger>

#include "include/zm/zm_teams.inc"

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_AUTO_TEAM_JOIN
#else
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_AUTO_TEAM_JOIN
#endif

#define EXTENSION_NAME "Auto Team Join"
#define VERSION_STRING "1.0.0"

#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2
#define IMMUNITY_ACCESS_LEVEL ADMIN_IMMUNITY
//#define OBEY_IMMUNITY

static fwReturn = 0;
static onTeamChangeBlocked = INVALID_HANDLE;
static onAutoTeamJoined = INVALID_HANDLE;

static const chooseteam[] = "chooseteam";
static const jointeam[] = "jointeam";
static const joinclass[] = "joinclass";

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
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Automatically assigns teams and keeps track of \"correct\" team");

  new const onTeamChange[] = "onTeamChange";
  new const chooseteamHandle = register_clcmd(chooseteam, onTeamChange);
  if (!chooseteamHandle) {
    loge("register_clcmd(chooseteam, \"onTeamChange\") returned 0");
  }

  new const jointeamHandle = register_clcmd(jointeam, onTeamChange);
  if (!jointeamHandle) {
    loge("register_clcmd(jointeam, \"onTeamChange\") returned 0");
  }

  new const ShowMenu = get_user_msgid("ShowMenu");
  new const showMenuHandle = register_message(ShowMenu, "onShowMenu");
  if (!showMenuHandle) {
    loge("register_message(ShowMenu, \"onShowMenu\") returned 0");
  }

  new const VGUIMenu = get_user_msgid("VGUIMenu");
  new const vguiMenuHandle = register_message(VGUIMenu, "onVGUIMenu");
  if (!vguiMenuHandle) {
    loge("register_message(VGUIMenu, \"onVGUIMenu\") returned 0");
  }
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

bb_onTeamChangeBlocked(id) {
  if (onTeamChangeBlocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onTeamChangeBlocked");
#endif
    onTeamChangeBlocked = CreateMultiForward("bb_onTeamChangeBlocked", ET_CONTINUE, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onTeamChangeBlocked = %d", onTeamChangeBlocked);
#endif
  }
  
#if defined DEBUG_FORWARDS
  logd("Calling bb_onTeamChangeBlocked(%d) for %N", id, id);
#endif
  ExecuteForward(onTeamChangeBlocked, fwReturn, id);
}

bb_onAutoTeamJoined(id) {
  if (onAutoTeamJoined == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onAutoTeamJoined");
#endif
    onAutoTeamJoined = CreateMultiForward("bb_onAutoTeamJoined", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onAutoTeamJoined = %d", onAutoTeamJoined);
#endif
  }

  new const ZM_Team: team = zm_getUserTeam(id);
#if defined DEBUG_FORWARDS
  logd("Calling bb_onAutoTeamJoined(%d, %s) for %N", id, ZM_Team_Names[team], id);
#endif
  ExecuteForward(onAutoTeamJoined, fwReturn, id, team);
}

public onTeamChange(id) {
  new ZM_Team: team = zm_getUserTeam(id);
  if (team == ZM_TEAM_UNASSIGNED || team == ZM_TEAM_SPECTATOR) {
    return PLUGIN_CONTINUE;
  }

  bb_onTeamChangeBlocked(id);
  return PLUGIN_HANDLED;
}

bool: shouldAutoJoin(id) {
#if defined OBEY_IMMUNITY
  return !get_user_team(id) && !task_exists(id)
      && !(get_user_flags(id) & IMMUNITY_ACCESS_LEVEL);
#else
  return !get_user_team(id) && !task_exists(id);
#endif
}

public onShowMenu(const msgID, const msgDest, const id) {
  if (!shouldAutoJoin(id)) {
    return PLUGIN_CONTINUE;
  }
  
  static Team_Select[] = "#Team_Select";
  static text[sizeof Team_Select];
  get_msg_arg_string(4, text, charsmax(text));
  if (!equal(text, Team_Select)) {
    return PLUGIN_CONTINUE;
  }

#if defined DEBUG_AUTO_TEAM_JOIN
  logd("Creating auto join task for %N...", id);
#endif

  new params[2];
  params[0] = msgID;
  // TODO: Replace with set_task_ex
  set_task(AUTO_TEAM_JOIN_DELAY, "onForceTeamJoin", id, params, charsmax(params));
  return PLUGIN_HANDLED;
}

public onVGUIMenu(const msgID, const msgDest, const id) {
  if (get_msg_arg_int(1) != TEAM_SELECT_VGUI_MENU_ID || !shouldAutoJoin(id)) { 
    return PLUGIN_CONTINUE;
  }

#if defined DEBUG_AUTO_TEAM_JOIN
  logd("Creating auto join task for %N...", id);
#endif

  new params[2];
  params[0] = msgID;
  // TODO: Replace with set_task_ex
  set_task(AUTO_TEAM_JOIN_DELAY, "onForceTeamJoin", id, params, charsmax(params));
  return PLUGIN_HANDLED;
}

public onForceTeamJoin(params[], id) {
  if (get_user_team(id)) {
    return;
  }

  new const msgId = params[0];
  forceTeamJoin(id, msgId);
}

forceTeamJoin(const id, const msgId, const team[] = "5", const class[] = "5") {
  if (class[0] == '0') {
    engclient_cmd(id, jointeam, team);
    bb_onAutoTeamJoined(id);
    return;
  }

#if defined DEBUG_AUTO_TEAM_JOIN
  logd("Auto joining %N to team=%d, class=%d", id, team, class);
#endif

  static msgBlockFlags;
  msgBlockFlags = get_msg_block(msgId);
  set_msg_block(msgId, BLOCK_SET);
  engclient_cmd(id, jointeam, team);
  engclient_cmd(id, joinclass, class);
  set_msg_block(msgId, msgBlockFlags);

  bb_onAutoTeamJoined(id);
}
