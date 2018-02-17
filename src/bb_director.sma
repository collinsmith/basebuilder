#define _bb_director_included

#include <amxmodx>
#include <amxmisc>
#include <logger>
#include <reapi>

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/cs_weapon_restrictions/cs_weapon_restrictions.inc"

#include "include/commands/commands.inc"

#include "include/zm/zm_classes.inc"
#include "include/zm/zm_teams.inc"

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_guns_menu.inc"
#include "include/bb/bb_zones.inc"
#include "include/bb/bb_director_consts.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  #define DEBUG_ASSERTIONS
  #define DEBUG_GAMESTATE
  //#define DEBUG_BARRIER
  //#define DEBUG_ROUNDTIMER
  //#define DEBUG_RESPAWNTIMER
  //#define DEBUG_SWAP
  //#define DEBUG_GRABBING
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_ASSERTIONS
  #define DEBUG_GAMESTATE
  //#define DEBUG_BARRIER
  //#define DEBUG_ROUNDTIMER
  //#define DEBUG_RESPAWNTIMER
  //#define DEBUG_SWAP
  //#define DEBUG_GRABBING
#endif

#define EXTENSION_NAME "Director"
#define VERSION_STRING "1.0.0"

//#define FLAGS_GRAB_IGNORE_TEAM ADMIN_RCON
//#define FLAGS_GRAB_IGNORE_STATE ADMIN_BAN

//#define FAST_TIMER 10
#define TIMER_THINK_DELAY 0.100

static GameState: gameState = Invalid_GameState;
static stock GameState: operator=(value) return GameState:(value);

static barrier = 0;

static roundTimer = 0;
static roundTime = 0;
static bool: paused = false;

static respawnTimer = 0;
static respawnTime[MAX_PLAYERS + 1] = { 0, ... };

static ZM_Team: pActualTeam[MAX_PLAYERS + 1];

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
      .desc = "Manages Base Builder game state");

  setupBarrier();
  createCvars();
  createEntities();
  registerCommands();

  //register_event_ex("HLTV", "onHLTV", RegisterEvent_Global, "1=0", "2=0");
  //register_logevent("onRoundStartLogged", 2, "1=Round_Start");
  //register_logevent("onRoundEndLogged", 2, "1=Round_End");
  RegisterHookChain(RG_CSGameRules_RestartRound, "onRestartRound");
  RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "onRoundFreezeEnd");
  RegisterHookChain(RG_RoundEnd, "onRoundEnded");

  set_member_game(m_bCTCantBuy, true);
  set_member_game(m_bTCantBuy, true);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

/*******************************************************************************
 * CVars
 ******************************************************************************/

static Float: fBarrierColor[3];
static Float: fBarrierRenderAmt;
static iBuildTime;
static iPrepTime;
static iSurviveTime;
static iRespawnTime;

#define CREATE_CVAR_COLOR(%1,%2,%3,%4,%5,%6) \
    name = %1;\
    LookupLangKey(desc, charsmax(desc), name, lang);\
    pcvar = create_cvar(name, #%4, _, desc,\
        .has_min = true, .min_val = %2, .has_max = true, .max_val = %3);\
    bind_pcvar_float(pcvar, %5);\
    hook_cvar_change(pcvar, %6);

#define CREATE_CVAR_TIMER(%1,%2,%3) \
    name = %1;\
    LookupLangKey(desc, charsmax(desc), name, lang);\
    pcvar = create_cvar(name, #%2, _, desc, .has_min = true, .min_val = 0.0);\
    bind_pcvar_num(pcvar, %3);

createCvars() {
  new lang = LANG_SERVER;
  new pcvar, name[32], desc[256];
  CREATE_CVAR_COLOR("bb_barrierColor_r",0.0,255.0,0.0,fBarrierColor[0],"onBarrierColorChanged")
  CREATE_CVAR_COLOR("bb_barrierColor_g",0.0,255.0,0.0,fBarrierColor[1],"onBarrierColorChanged")
  CREATE_CVAR_COLOR("bb_barrierColor_b",0.0,255.0,0.0,fBarrierColor[2],"onBarrierColorChanged")
  CREATE_CVAR_COLOR("bb_barrierColor_a",50.0,255.0,150.0,fBarrierRenderAmt,"onBarrierColorChanged")

  CREATE_CVAR_TIMER("bb_buildTime",120.0,iBuildTime)
  CREATE_CVAR_TIMER("bb_prepTime",30.0,iPrepTime)
  CREATE_CVAR_TIMER("bb_surviveTime",150.0,iSurviveTime)
  CREATE_CVAR_TIMER("bb_zombieRespawnTime",5.0,iRespawnTime)
}

#undef CREATE_CVAR_COLOR
#undef CREATE_CVAR_TIMER

public onBarrierColorChanged() {
#if defined DEBUG_ASSERTIONS
  assert is_entity(barrier);
#endif
  set_entvar(barrier, var_rendercolor, fBarrierColor);
  if (isBarrierEnabled()) {
    set_entvar(barrier, var_renderamt, fBarrierRenderAmt);
  }
}

/*******************************************************************************
 * Code
 ******************************************************************************/

createEntities() {
#if defined DEBUG_ASSERTIONS
  assert roundTimer == 0;
#endif
  roundTimer = createTimer("onRoundTimerThink");
#if defined DEBUG_ASSERTIONS
  assert respawnTimer == 0;
#endif
  respawnTimer = createTimer("onRespawnTimerThink");
}

createTimer(const callback[]) {
  new const timer = rg_create_entity("info_target");
  set_entvar(timer, var_classname, BB_TIMER);
  SetThink(timer, callback);
  return timer;
}

public onRoundTimerThink() {
  if (paused) {
    setNextThink(roundTimer, 1.0);
    return;
  }

  roundTime--;
  if (roundTime >= 0) {
#if defined DEBUG_ROUNDTIMER
    logd("%d:%02d.%d", mins, secs, tens);
#endif
    bb_onRoundTimerUpdated(roundTime, gameState);
  } else {
    switch (gameState) {
      case BuildPhase: setGameState(PrepPhase);
      case PrepPhase: setGameState(Released);
      case Released: {
        rg_round_end(5.0, WINSTATUS_CTS, _, .message=Builders_Win);
        setGameState(RoundEnding);
      }
      default: {}
    }
  }

  setNextThink(roundTimer);
}

setNextThink(const entity, const Float: delay = TIMER_THINK_DELAY) {
  set_entvar(entity, var_nextthink, halflife_time() + delay);
}

_onGameStateChanged(const GameState: fromState, const GameState: toState) {
#pragma unused fromState
  switch (toState) {
    case RoundStarting: {
      setBarrierEnabled(true);
      roundTime = get_member_game(m_iIntroRoundTime) * 10;
      setNextThink(roundTimer);
    }
    case BuildPhase: {
      setBarrierEnabled(true);
#if defined FAST_TIMER
      roundTime = FAST_TIMER * 10;
#else
      roundTime = iBuildTime * 10;
#endif
      setNextThink(roundTimer);
    }
    case PrepPhase: {
      setBarrierEnabled(true);
#if defined FAST_TIMER
      roundTime = FAST_TIMER * 10;
#else
      roundTime = iPrepTime * 10;
#endif
      setNextThink(roundTimer);
      new players[MAX_PLAYERS], num, id;
      get_players_ex(players, num, GetPlayers_ExcludeDead | GetPlayers_MatchTeam, "CT");
      for (new i = 0; i < num; i++) {
        id = players[i];
        bb_drop(id);
        zm_respawn(id, true);
      }
    }
    case Released: {
      setBarrierEnabled(false);
#if defined FAST_TIMER
      roundTime = FAST_TIMER * 10;
#else
      roundTime = iSurviveTime * 10;
#endif
      setNextThink(roundTimer);
    }
    case RoundEnding: {
      setBarrierEnabled(true);
      roundTime = 0;
      bb_resetAll();
      swapTeams();
    }
  }
}

public onRespawnTimerThink() {
#if defined DEBUG_RESPAWNTIMER
  static secs, tens;
  static timer[32], len;
#endif
  static respawnTimeCache;
  for (new id = 1; id <= MaxClients; id++) {
    respawnTimeCache = --respawnTime[id];
    if (respawnTimeCache >= 0) {
#if defined DEBUG_RESPAWNTIMER
      secs = respawnTimeCache / 10;
      tens = respawnTimeCache % 10;

      len = formatex(timer, charsmax(timer), "%d.%d", secs, tens);
      timer[len] = EOS;
      
      logd("%N respawn in %s", id, timer);
#endif
      bb_onRespawnTimerUpdated(id, respawnTimeCache);
    }

    if (respawnTimeCache == 0) {
      zm_respawn(id);
    }
  }

  setNextThink(respawnTimer);
}

public zm_onSpawn(const id) {
  cancelRespawn(id);
  if (zm_isUserHuman(id)) {
    if (gameState == PrepPhase) {
      cs_resetWeaponRestrictions(id);
      bb_showGunsMenu(id);
    } else {
      cs_setWeaponRestrictions(id, CSI_KNIFE, CSI_KNIFE, false);
    }
  }
}

public zm_onKilled(const victim, const killer) {
  if (zm_isUserHuman(victim)) {
    static players[MAX_PLAYERS], num;
    get_players_ex(players, num, GetPlayers_ExcludeDead | GetPlayers_MatchTeam, "CT");
    if (num == 0) {
      rg_round_end(5.0, WINSTATUS_TERRORISTS, _, .message=Zombies_Win);
      setGameState(RoundEnding);
      return;
    }
  }

  zm_infect(victim, killer);
  respawn(victim, iRespawnTime);
}

public client_disconnected(id) {
  pActualTeam[id] = ZM_TEAM_UNASSIGNED;
  cancelRespawn(id);
}

cancelRespawn(id) {
  respawnTime[id] = 0;
}

respawn(id, delay) {
  respawnTime[id] = delay * 10;
  setNextThink(respawnTimer);
}

// FIXME: This is not called for the first round, possibly called on GAME_COMMENCING
/** Called at the start of the round, during freeze time */
public onRestartRound() {
  setGameState(RoundStarting);
  bb_onNewRound();
}

/** Called after freeze time has ended */
public onRoundFreezeEnd() {
  setGameState(BuildPhase);
  bb_onRoundStart();
}

/** Called when the round ends */
public onRoundEnded() {
  setGameState(RoundEnding);
  bb_onRoundEnd();
}

setupBarrier() {
#if defined DEBUG_ASSERTIONS
  assert barrier == 0;
#endif
#if defined DEBUG_BARRIER
  logd("Locating barrier entity...");
#endif
  barrier = findBarrier();
  if (!is_entity(barrier)) {
    new error[128], lang = LANG_SERVER;
    LookupLangKey(error, charsmax(error), "BARRIER_NOT_FOUND", lang);
    loge(error);
    set_fail_state(error);
    return;
  }

#if defined DEBUG_BARRIER
  logd("barrier=%d", barrier);
#endif
  set_entvar(barrier, var_rendermode, kRenderTransColor);
  setBarrierEnabled(false);
  bb_onBarrierSetup(barrier);
}

findBarrier() {
  return rg_find_ent_by_class(MaxClients, BB_BARRIER[0], true);
}

public bb_onAutoTeamJoined(const id, const ZM_Team: team) {
#if defined DEBUG_SWAP
  logd("%N joined %s", id, ZM_Team_Names[team]);
#endif
  pActualTeam[id] = team;
}

swapTeams() {
  new players[MAX_PLAYERS], num, player;
  get_players_ex(players, num, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
  for (new i = 0; i < num; i++) {
    player = players[i];
    fixTeam(player);
  }

  zm_printColor(0, "%L", LANG_PLAYER, "SWAP_TEAMS");
}

fixTeam(id) {
  static ZM_Team: team;
  team = pActualTeam[id];
  if (team == ZM_TEAM_UNASSIGNED || team == ZM_TEAM_SPECTATOR) {
    return;
  }

  team = team == ZM_TEAM_HUMAN ? ZM_TEAM_ZOMBIE : ZM_TEAM_HUMAN;
  pActualTeam[id] = team;
#if defined DEBUG_SWAP
  logd("swapping %N to %s", id, ZM_Team_Names[team]);
#endif
  if (team == ZM_TEAM_HUMAN) {
    zm_cure(id, .blockable = false);
  } else {
    assert team == ZM_TEAM_ZOMBIE;
    zm_infect(id, .blockable = false);
  }
}

public zm_onBeforeClassMenuDisplayed(const id, const bool: exitable) {
  if (zm_isUserHuman(id)) {
    return PLUGIN_HANDLED;
  }
  
  return PLUGIN_CONTINUE;
}

public zm_onInfected(const id, const infector) {
  // TODO: Configure default class
  new const Class: defaultClass = zm_findClass("@string/ZM_CLASS_CLASSIC");
  zm_setUserClass(id, defaultClass, true);
  logd("%N class auto set to %d", id, defaultClass);
}

public zm_onCured(const id, const curor) {
  zm_setUserClass(id, Invalid_Trie, true);
}

public bb_onBeforeGrabbed(const id, const entity) {
  if (gameState == Invalid_GameState) {
    return PLUGIN_CONTINUE;
  }

#if defined FLAGS_GRAB_IGNORE_TEAM || defined FLAGS_GRAB_IGNORE_STATE
  new const adminFlags = get_user_flags(id);
#endif
  if (zm_isUserZombie(id)) {
#if defined FLAGS_GRAB_IGNORE_TEAM
    if (!(adminFlags & FLAGS_GRAB_IGNORE_TEAM)) {
#endif
#if defined DEBUG_GRABBING
      logd("%N is a zombie without grab override privileges", id);
#endif
      return PLUGIN_HANDLED;
#if defined FLAGS_GRAB_IGNORE_TEAM
    }
#endif
  }

  if (gameState != BuildPhase) {
#if defined FLAGS_GRAB_IGNORE_STATE
    if (!(adminFlags & FLAGS_GRAB_IGNORE_STATE)) {
#endif
#if defined DEBUG_GRABBING
      logd("Grab blocked for %N! gameState != BuildPhase", id);
#endif
      new reason[128], lang = id;
      LookupLangKey(reason, charsmax(reason), "CANNOT_BUILD_NOW", lang);
      bb_setBlockedReason(reason);
      return PLUGIN_HANDLED;
#if defined FLAGS_GRAB_IGNORE_STATE
    }
#endif
  }

  return PLUGIN_CONTINUE;
}

public bb_onDropped(const id, const entity) {
  if (bb_isTouching(entity, BuilderSpawn|ZombieSpawn)) {
    bb_reset(entity);
    zm_printColor(id, "%l", "CANNOT_BUILD_IN_SPAWN");
    logd("reset %d because %N is an idiot and built in a spawn", entity, id);
  }
}

bool: isValidGameState(GameState: toState) {
  return Invalid_GameState < toState || toState <= RoundEnding;
}

GameState: getGameState() {
  return gameState;
}

GameState: setGameState(GameState: toState) {
#if defined DEBUG_ASSERTIONS
  assert isValidGameState(toState);
#endif
  if (gameState == toState) {
    return gameState;
  }
  
#if defined DEBUG_GAMESTATE
  logd("gameState %s -> %s", GAME_STATES[gameState], GAME_STATES[toState]);
#endif
  new const GameState: fromState = gameState;
  gameState = toState;
  _onGameStateChanged(fromState, toState);
  bb_onGameStateChanged(fromState, toState);
  return fromState;
}

bool: isBarrierEnabled() {
#if defined DEBUG_ASSERTIONS
  assert is_entity(barrier);
#endif
  return get_entvar(barrier, var_solid) == SOLID_BSP;
}

bool: setBarrierEnabled(bool: b) {
#if defined DEBUG_ASSERTIONS
  assert is_entity(barrier);
#endif
  new const bool: isEnabled = isBarrierEnabled();
  if (b) {
#if defined DEBUG_BARRIER
    logd("enabling barrier...");
#endif
    set_entvar(barrier, var_solid, SOLID_BSP);
    set_entvar(barrier, var_renderamt, fBarrierRenderAmt);
  } else {
#if defined DEBUG_BARRIER
    logd("disabling barrier...");
#endif
    set_entvar(barrier, var_solid, SOLID_NOT);
    set_entvar(barrier, var_renderamt, 0.0);
  }

  return isEnabled;
}

/*******************************************************************************
 * Client Commands
 ******************************************************************************/

stock registerCommand(const alias[], const callback[], const desc[], const adminFlags) {
  cmd_registerCommand(
      .alias = alias,
      .handle = callback,
      .desc = desc,
      .adminFlags = adminFlags);
  bb_registerConCmd(
      .command = alias,
      .callback = callback,
      .desc = desc,
      .access = adminFlags);
}

registerCommands() {
  registerCommand(
      .alias = "pause",
      .callback = "onPauseCmd",
      .desc = "Pauses the director",
      .adminFlags = ADMIN_ALL);

  registerCommand(
      .alias = "prep",
      .callback = "onPreparationCmd",
      .desc = "Ends the build phase and skips to preparation phase",
      .adminFlags = ADMIN_ALL);

  registerCommand(
      .alias = "release",
      .callback = "onReleaseCmd",
      .desc = "Ends the build and prep phases and releases the zombies",
      .adminFlags = ADMIN_ALL);

  registerCommand(
      .alias = "reset",
      .callback = "onResetCmd",
      .desc = "Resets entities to default state",
      .adminFlags = ADMIN_ALL);
}

public onPauseCmd(id) {
  if (gameState >= Released) {
    zm_printColor(id, "%l", "CANNOT_PAUSE");
    return PLUGIN_HANDLED;
  }

  setPaused(id, !paused);
  return PLUGIN_HANDLED;
}

bool: setPaused(id, bool: b) {
  if (paused == b) {
    return paused;
  }

  new const bool: oldValue = paused;
  paused = b;
  zm_printColor(0, "%L", LANG_PLAYER, b ? TIMER_PAUSED : TIMER_RESUMED);
  logi("%L by %N", LANG_SERVER, b ? TIMER_PAUSED : TIMER_RESUMED, id);
  b ? bb_onPause() : bb_onResume();
  return oldValue;
}

public onPreparationCmd(id) {
  if (gameState >= PrepPhase) {
    zm_printColor(id, "%l", "CANNOT_FORCE_PREPARATION");
    return PLUGIN_HANDLED;
  }

  setPaused(id, false);
  setGameState(PrepPhase);
  zm_printColor(0, "%L", LANG_PLAYER, "PREPARATION_BY_CMD");
  logi("%L by %N", LANG_SERVER, "PREPARATION_BY_CMD", id);
  return PLUGIN_HANDLED;
}

public onReleaseCmd(id) {
  if (gameState >= Released) {
    zm_printColor(id, "%l", "CANNOT_FORCE_RELEASE");
    return PLUGIN_HANDLED;
  }

  setPaused(id, false);
  setGameState(Released);
  zm_printColor(0, "%L", LANG_PLAYER, "RELEASED_BY_CMD");
  logi("%L by %N", LANG_SERVER, "RELEASED_BY_CMD", id);
  return PLUGIN_HANDLED;
}

public onResetCmd(id) {
  bb_resetAll();
  zm_printColor(0, "%L", LANG_PLAYER, "RESET_BY_CMD");
  logi("%L by %N", LANG_SERVER, "RESET_BY_CMD", id);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

static onGameStateChanged = INVALID_HANDLE;
static onBarrierSetup = INVALID_HANDLE;
static onNewRound = INVALID_HANDLE;
static onRoundStart = INVALID_HANDLE;
static onRoundEnd = INVALID_HANDLE;
static onPause = INVALID_HANDLE;
static onResume = INVALID_HANDLE;
static onRoundTimerUpdated = INVALID_HANDLE;
static onRespawnTimerUpdated = INVALID_HANDLE;

bb_onGameStateChanged(const GameState: fromState, const GameState: toState) {
  if (onGameStateChanged == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onGameStateChanged");
#endif
    onGameStateChanged = CreateMultiForward(
        "bb_onGameStateChanged", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onGameStateChanged = %d", onGameStateChanged);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onGameStateChanged");
#endif
  ExecuteForward(onGameStateChanged, _, fromState, toState);
}

bb_onBarrierSetup(const barrier) {
  if (onBarrierSetup == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onBarrierSetup");
#endif
    onBarrierSetup = CreateMultiForward(
        "bb_onBarrierSetup", ET_CONTINUE,
        FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onBarrierSetup = %d", onBarrierSetup);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onBarrierSetup");
#endif
  ExecuteForward(onBarrierSetup, _, barrier);
}

bb_onNewRound() {
  if (onNewRound == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onNewRound");
#endif
    onNewRound = CreateMultiForward("bb_onNewRound", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onNewRound = %d", onNewRound);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onNewRound");
#endif
  ExecuteForward(onNewRound);
}

bb_onRoundStart() {
  if (onRoundStart == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onRoundStart");
#endif
    onRoundStart = CreateMultiForward("bb_onRoundStart", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onRoundStart = %d", onRoundStart);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onRoundStart");
#endif
  ExecuteForward(onRoundStart);
}

bb_onRoundEnd() {
  if (onRoundEnd == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onRoundEnd");
#endif
    onRoundEnd = CreateMultiForward("bb_onRoundEnd", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onRoundEnd = %d", onRoundEnd);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onRoundEnd");
#endif
  ExecuteForward(onRoundEnd);
}

bb_onPause() {
  if (onPause == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onPause");
#endif
    onPause = CreateMultiForward("bb_onPause", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onPause = %d", onPause);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onPause");
#endif
  ExecuteForward(onPause);
}

bb_onResume() {
  if (onResume == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onResume");
#endif
    onResume = CreateMultiForward("bb_onResume", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onResume = %d", onResume);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onResume");
#endif
  ExecuteForward(onResume);
}

bb_onRoundTimerUpdated(const timeleft, const GameState: gameState) {
  if (onRoundTimerUpdated == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onRoundTimerUpdated");
#endif
    onRoundTimerUpdated = CreateMultiForward(
        "bb_onRoundTimerUpdated", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onRoundTimerUpdated = %d", onRoundTimerUpdated);
#endif
  }

#if defined DEBUG_FORWARDS && defined DEBUG_ROUNDTIMER
  logd("Forwarding bb_onRoundTimerUpdated(%d, %s)", timeleft, GAME_STATES[gameState]);
#endif
  ExecuteForward(onRoundTimerUpdated, _, timeleft, gameState);
}

bb_onRespawnTimerUpdated(const id, const timeleft) {
  if (onRespawnTimerUpdated == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onRespawnTimerUpdated");
#endif
    onRespawnTimerUpdated = CreateMultiForward(
        "bb_onRespawnTimerUpdated", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onRespawnTimerUpdated = %d", onRespawnTimerUpdated);
#endif
  }

#if defined DEBUG_FORWARDS && defined DEBUG_RESPAWNTIMER
  logd("Forwarding bb_onRespawnTimerUpdated(%d, %d)", id, timeleft);
#endif
  ExecuteForward(onRespawnTimerUpdated, _, id, timeleft);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("bb_director");

  register_native("bb_getGameState", "native_getGameState");
  register_native("bb_setGameState", "native_setGameState");

  register_native("bb_isBarrierEnabled", "native_isBarrierEnabled");
  register_native("bb_setBarrierEnabled", "native_setBarrierEnabled");

  register_native("bb_getRoundTime", "native_getRoundTime");
}

//native GameState: bb_getGameState();
public GameState: native_getGameState(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {}
#endif
  return getGameState();
}

//native GameState: bb_setGameState(const GameState: toState);
public GameState: native_setGameState(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {}
#endif
  
  new const GameState: toState = get_param(1);
  if (!isValidGameState(toState)) {
    ThrowIllegalArgumentException("Invalid toState specified: %d", toState);
    return getGameState();
  }
  
  return setGameState(toState);
}

//native bool: bb_isBarrierEnabled();
public bool: native_isBarrierEnabled(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {}
#endif
  return isBarrierEnabled();
}

//native bool: bb_setBarrierEnabled(const bool: b);
public bool: native_setBarrierEnabled(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {}
#endif

  new const bool: b = bool:(get_param(1));
  return setBarrierEnabled(b);
}

//native bb_getRoundTime();
public native_getRoundTime(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {}
#endif

  return roundTime;
}
