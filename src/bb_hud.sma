#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <logger>
#include <reapi>

#include "include/zm/zm_classes.inc"
#include "include/zm/zm_teams.inc"

#include "include/bb/bb_builder.inc"
#include "include/bb/bb_director.inc"
#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_CHANNELS
  //#define DEBUG_HEALTH
  #define DEBUG_ASSERTIONS
  #define DEBUG_PAUSETIMER
#else
  //#define DEBUG_CHANNELS
  //#define DEBUG_HEALTH
  //#define DEBUG_ASSERTIONS
  //#define DEBUG_PAUSETIMER
#endif

#define EXTENSION_NAME "HUD"
#define VERSION_STRING "1.0.0"

//#define DISPLAY_HEALTH_HUD
#define DISPLAY_HEALTH_PERCENT
//#define ANNOUNCE_USES_DHUD
//#define FLAGS_SHOW_TRACELINE ADMIN_SLAY

#define TASK_DISPLAY_HEALTH 1000

#define HUD_CROSSHAIR_AMMO_WEAPONS 1
#define HUD_FLASHLIGHT             2
#define HUD_RADAR_HEALTH_ARMOR     8
#define HUD_TIMER                  16
#define HUD_MONEY                  32
#define HUD_CROSSHAIR              64
static const HideWeaponFlags =
      HUD_FLASHLIGHT
    | HUD_MONEY;

static timerSync;
static respawnSync;
static announceSync;
static tracelineSync;
#if defined DISPLAY_HEALTH_HUD
static healthSync;
#endif

static RoundTime;
static HideWeapon;

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
      .desc = "Displays HUD info and manages HUD channels");

  timerSync = CreateHudSyncObj();
#if defined DEBUG_CHANNELS
  logd("timerSync=%d", timerSync);
#endif

  respawnSync = CreateHudSyncObj();
#if defined DEBUG_CHANNELS
  logd("respawnSync=%d", respawnSync);
#endif

  announceSync = CreateHudSyncObj();
#if defined DEBUG_CHANNELS
  logd("announceSync=%d", announceSync);
#endif

  tracelineSync = CreateHudSyncObj();
#if defined DEBUG_CHANNELS
  logd("tracelineSync=%d", tracelineSync);
#endif

#if defined DISPLAY_HEALTH_HUD
  healthSync = CreateHudSyncObj();
#if defined DEBUG_CHANNELS
  logd("healthSync=%d", healthSync);
#endif
#endif

  new Health = get_user_msgid("Health");
  new const healthHandle = register_message(Health, "onHealth");
  if (!healthHandle) {
    loge("register_message(Health, \"onHealth\") returned 0");
  }

  RoundTime = get_user_msgid("RoundTime");
  new const roundTimeHandle = register_message(RoundTime, "onRoundTime");
  if (!roundTimeHandle) {
    loge("register_message(RoundTime, \"onRoundTime\") returned 0");
  }

  HideWeapon = get_user_msgid("HideWeapon");
  new const hideWeaponHandle = register_message(HideWeapon, "onHideWeapon");
  if (!hideWeaponHandle) {
    loge("register_message(HideWeapon, \"onHideWeapon\") returned 0");
  }

#if defined DISPLAY_HEALTH_HUD
  register_event_ex("Health", "evHealth",
      RegisterEvent_Single | RegisterEvent_OnlyAlive | RegisterEvent_OnlyHuman,
      "1>0");
#endif
  register_event_ex("ResetHUD", "evResetHUD", RegisterEvent_Single);

  register_forward(FM_TraceLine, "onTraceLine", 1);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

#if defined DISPLAY_HEALTH_HUD
public zm_onAfterApply(id) {
  evHealth(id);
}
#endif

public zm_onKilled(const victim, const killer) {
#if defined DISPLAY_HEALTH_HUD
  remove_task(victim + TASK_DISPLAY_HEALTH);
#endif
}

#if defined DISPLAY_HEALTH_HUD
public evHealth(id) {
  if (id > TASK_DISPLAY_HEALTH) {
    id -= TASK_DISPLAY_HEALTH;
  }

  new const health = floatround(entity_get_float(id, EV_FL_health));
#if defined DEBUG_HEALTH
  logd("health for %N is %d", id, health);
#endif

  set_hudmessage(255, 0, 0, -1.0, 0.9, 0, 0.0, 5.0, 0.0, 0.0);
  ShowSyncHudMsg(id, healthSync, "%L", id, "HUD_HEALTH", health);
  
  // TODO: Replace with set_task_ex
  remove_task(id + TASK_DISPLAY_HEALTH);
  set_task(4.9, "evHealth", id + TASK_DISPLAY_HEALTH);
}
#endif

public onHealth(msgid, dest, id) {
  if(!is_user_alive(id)) {
    return PLUGIN_CONTINUE;
  }

  static hp;
  hp = get_msg_arg_int(1);

#if defined DISPLAY_HEALTH_PERCENT
  new const Class: class = zm_getUserClass(id);
  if (!class) {
    if(hp > 255 && (hp % 256) == 0) {
      set_msg_arg_int(1, ARG_BYTE, ++hp);
    }
  } else {
    // TODO: assert hasProperty
    static value[8];
    zm_getClassProperty(class, ZM_CLASS_HEALTH, value, charsmax(value));
    new const Float: health = entity_get_float(id, EV_FL_health);
    new const Float: maxHealth = str_to_float(value);
    new const percent = floatround(health / maxHealth * 100, floatround_ceil);
    set_msg_arg_int(1, ARG_BYTE, percent);
#if defined DEBUG_HEALTH
    logd("%N maxHealth=%.0f; health=%.0f; percent=%.2f; final=%d",
        id, maxHealth, health, health / maxHealth, percent);
#endif
  }
#else
  if(hp > 255 && (hp % 256) == 0) {
    set_msg_arg_int(1, ARG_BYTE, ++hp);
  }
#endif

  return PLUGIN_CONTINUE;
}

public onRoundTime(msgid, dest, id) {
  set_msg_arg_int(1, ARG_SHORT, bb_getRoundTime() / 10 + 1);
}

public bb_onRoundTimerUpdated(const timeleft, const GameState: gameState) {
  static mins, secs, tens;
  mins = timeleft / 600;
  secs = timeleft % 600 / 10;
  tens = timeleft % 10;

  static timer[32], len;
  len = formatex(timer, charsmax(timer), "%d:%02d.%d", mins, secs, tens);
  timer[len] = EOS;
  
  set_hudmessage(246, 100, 175, -1.0, 0.00, 0, 0.0, 1.0, 0.0, 0.0);
  ShowSyncHudMsg(0, timerSync, "%L", LANG_PLAYER, "HUD_TIMER",
      LANG_PLAYER, GAME_STATES[gameState], timer);
  
  if (tens == 0) {
    broadcastRoundTime(timeleft / 10 + 1);
  }
}

public bb_onGameStateChanged(const GameState: fromState, const GameState: toState) {
  if (toState == Released) {
#if defined ANNOUNCE_USES_DHUD
    set_dhudmessage(246, 100, 175, -1.0, 0.35, 0, 0.0, 5.0, 0.0, 0.0);
    show_dhudmessage(0, "%L", LANG_PLAYER, "RELEASE_ANNOUNCE");
#else
    set_hudmessage(246, 100, 175, -1.0, 0.35, 0, 0.0, 5.0, 0.0, 0.0);
    ShowSyncHudMsg(0, announceSync, "%L", LANG_PLAYER, "RELEASE_ANNOUNCE");
#endif
  }

  broadcastRoundTime();
}

broadcastRoundTime(timeleft = 0) {
  message_begin(MSG_BROADCAST, RoundTime); {
    write_short(timeleft ? timeleft : bb_getRoundTime() / 10 + 1);
  } message_end();
}

static pauseTimer = -1;

public bb_onPause() {
  if (is_nullent(pauseTimer)) {
    pauseTimer = rg_create_entity("info_target");
    set_entvar(pauseTimer, var_classname, BB_TIMER);
#if defined DEBUG_PAUSETIMER
    logd("pauseTimer=%d", pauseTimer);
#endif
  }
  
#if defined DEBUG_ASSERTIONS
  assert !is_nullent(pauseTimer);
#endif
  SetThink(pauseTimer, "onPauseTimerThink");
  onPauseTimerThink();
}

public onPauseTimerThink() {
  broadcastRoundTime();
  bb_onRoundTimerUpdated(bb_getRoundTime(), bb_getGameState());
  set_entvar(pauseTimer, var_nextthink, halflife_time() + 0.9);
}

public bb_onResume() {
  SetThink(pauseTimer, "");
  broadcastRoundTime();
}

public bb_onRespawnTimerUpdated(const id, const timeleft) {
  static secs, tens;
  secs = timeleft / 10;
  tens = timeleft % 10;

  static timer[32], len;
  len = formatex(timer, charsmax(timer), "%d.%d", secs, tens);
  timer[len] = EOS;

  set_hudmessage(246, 100, 175, -1.0, 0.40, 0, 0.0, 1.0, 0.0, 0.0);
  ShowSyncHudMsg(id, respawnSync, "%l", RESPAWN_IN_X, timer);
}

public zm_onSpawn(const id) {
  ClearSyncHud(id, respawnSync);
}

public evResetHUD(id) {
  message_begin(MSG_ONE, HideWeapon, .player = id); {
    write_byte(HideWeaponFlags);
  } message_end();
}

public onHideWeapon() {
  set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | HideWeaponFlags);
}

public bb_onPush(const id, const entity, const bool: maxDist) {
  set_hudmessage(246, 100, 175, -1.0, 0.40, 0, 0.0, 2.0, 0.0, 0.0);
  ShowSyncHudMsg(id, respawnSync, "%l", maxDist ? "PUSHED_MAX_DIST" : "PUSHING");
}

public bb_onPull(const id, const entity, const bool: minDist) {
  set_hudmessage(246, 100, 175, -1.0, 0.40, 0, 0.0, 2.0, 0.0, 0.0);
  ShowSyncHudMsg(id, respawnSync, "%l", minDist ? "PULLED_MIN_DIST" : "PULLING");
}

public bb_onGrabBlocked(const id, const entity, const reason[]) {
  if (isStringEmpty(reason)) {
    return;
  }

  set_hudmessage(246, 100, 175, -1.0, 0.40, 0, 0.0, 5.0, 0.0, 0.0);
  ShowSyncHudMsg(id, respawnSync, reason);
}

public onTraceLine(Float: start[3], Float: end[3], conditions, id, trace) {
  if (bb_getGameState() != BuildPhase) {
#if defined FLAGS_SHOW_TRACELINE
    if (!access(id, FLAGS_SHOW_TRACELINE)) {
#endif
      return FMRES_IGNORED;
#if defined FLAGS_SHOW_TRACELINE
    }
#endif
  }

  static ent, curMover, lastMover, szCurMover[32], szLastMover[32];
  ent = get_tr2(trace, TR_pHit);
  if (!is_valid_ent(ent)) {
    ClearSyncHud(id, tracelineSync);
    return FMRES_IGNORED;
  }

  static szFormattedHud[128], len;
  len = 0;
  if (GetMoveType(ent) != UNMOVABLE) {
    set_hudmessage(0, 50, 255, -1.0, 0.60, 0, 0.0, 3.0, 0.0, 0.5);
    curMover = GetEntMover(ent);
    lastMover = GetLastMover(ent);
    if (GetBlockClaimer(ent)) {
      len += formatex(szFormattedHud[len], 127-len, "%L", id, "HUD_CLAIMED");
    }	

    if (IsBlockLocked(ent)) {
      len += formatex(szFormattedHud[len], 127-len, " & %L", id, "HUD_LOCKER");
    }

    len += formatex(szFormattedHud[len], 127-len, "\n");

    if (curMover && lastMover) {
      get_user_name(curMover, szCurMover, 31);
      get_user_name(lastMover, szLastMover, 31);
      len += formatex(szFormattedHud[len], 127-len,
          "%l\n%l", "CURRENT_MOVER", szCurMover, "LAST_MOVER", szLastMover);
    } else if (curMover) {
      get_user_name(curMover, szCurMover, 31);
      len += formatex(szFormattedHud[len], 127-len,
          "%l\n%l", "CURRENT_MOVER", szCurMover, "LAST_MOVER", "NONE");
    } else if (lastMover) {
      get_user_name(lastMover, szLastMover, 31);
      len += formatex(szFormattedHud[len], 127-len,
          "%l\n%l", "CURRENT_MOVER", "NONE", "LAST_MOVER", szLastMover);
    } else {
      len += formatex(szFormattedHud[len], 127-len, "%l", "HASNT_BEEN_MOVED");
    }

    szFormattedHud[len] = EOS;
    ShowSyncHudMsg(id, tracelineSync, szFormattedHud);
  } else {
    ClearSyncHud(id, tracelineSync);
  }

  return FMRES_IGNORED;
}
