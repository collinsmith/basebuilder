#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <logger>
#include <reapi>

#include "include/stocks/precache_stocks.inc"

#include "include/zm/zm_teams.inc"

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_GRABBING
  //#define DEBUG_RESET
  //#define DEBUG_CMDSTART
#else
  //#define DEBUG_GRABBING
  //#define DEBUG_RESET
  //#define DEBUG_CMDSTART
#endif

#define EXTENSION_NAME "Builder: Locker"
#define VERSION_STRING "1.0.0"

#define FLAGS_GRAB_IGNORE_LOCKED ADMIN_SLAY
#define MAX_LOCKABLE 16

static const LOCKED_SOUND[] = "bb/block_locked.wav";

static Float: LOCKED_COLOR[3] = { 255.0, 0.0, 0.0 };
static Float: LOCKED_ALPHA = 150.0;

static Float: fMaxEntDist;
static numClaimed[MAX_PLAYERS + 1];

public zm_onPrecache() {
  precacheSound(LOCKED_SOUND);
}

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
      .desc = "Adds object locking/unlocking");

  register_forward(FM_CmdStart, "onCmdStart");

  new pcvar;
  pcvar = get_cvar_pointer("bb_builder_maxGrabDistance");
  if (!pcvar) {
    set_fail_state("bb_builder_maxGrabDistance was not found!");
  }

  bind_pcvar_float(pcvar, fMaxEntDist);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onCmdStart(id, uc, randseed) {
  if (!is_user_alive(id)) {
    return FMRES_IGNORED;
  }
  
  if (bb_getGameState() != BuildPhase) {
    return FMRES_IGNORED;
  }

  new const buttons = get_uc(uc, UC_Buttons);
  new const oldbuttons = pev(id, pev_oldbuttons);
  if (!bb_isUserGrabbing(id) && (buttons & IN_RELOAD) && !(oldbuttons & IN_RELOAD)) {
#if defined DEBUG_CMDSTART
    logd("%N pressed IN_RELOAD", id);
#endif
    new entity, body, Float: distance;
    distance = get_user_aiming(id, entity, body, floatround(fMaxEntDist));
    toggleLock(id, entity, distance);
    return FMRES_IGNORED;
  }

  return FMRES_IGNORED;
}

// TODO: forward event for lock?
toggleLock(id, entity, &Float: distance = 0.0) {
  if (!is_valid_ent(entity) || GetMoveType(entity) == UNMOVABLE || IsMovingEnt(entity)) {
    return;
  }

  if (zm_isUserZombie(id)) {
    return;
  }

#if defined DEBUG_GRABBING
  logd("%N initiating lock on %d", id, entity);
#endif
  new const locker = GetBlockClaimer(entity);
  if (locker == 0) {
    if (numClaimed[id] >= MAX_LOCKABLE) {
      zm_printColor(id, "You have already claimed %d objects!", numClaimed[id]);
#if defined DEBUG_GRABBING
      logd("%N's lock on %d was blocked, already locked %d objects", id, entity, numClaimed[id]);
#endif
      return;
    }

    if (lock(id, entity)) {
      numClaimed[id]++;
      rg_send_audio(id, LOCKED_SOUND);
    }
  } else if (id == locker) {
    if (unlock(entity)) {
      numClaimed[id]--;
      rg_send_audio(id, LOCKED_SOUND);
    }
  } else {
    // cannot lock other player's blocks!!!
#if defined DEBUG_GRABBING
    logd("%N's lock on %d was blocked, owned by %N", id, entity, locker);
#endif
  }
}

public bb_onBeforeGrabbed(const id, const entity) {
  new const locker = GetBlockClaimer(entity);
  if (locker != id) {
#if defined FLAGS_GRAB_IGNORE_LOCKED
    new const adminFlags = get_user_flags(id);
    if (!(adminFlags & FLAGS_GRAB_IGNORE_LOCKED)) {
#endif
#if defined DEBUG_GRABBING
      logd("Grab blocked for %N! locked by %N", id, locker);
#endif
      new reason[128], lang = id;
      LookupLangKey(reason, charsmax(reason), "CANNOT_BUILD_OBJECT_OWNED", lang);
      bb_setBlockedReason(reason);
      return PLUGIN_HANDLED;
#if defined FLAGS_GRAB_IGNORE_LOCKED
    }
#endif
  }

  return PLUGIN_CONTINUE;
}

public bb_onGrabbed(const id, const entity) {
}

public bb_onReset(const entity) {
  unlock(entity);
}

public client_disconnected(id) {
  if (bb_getGameState() == BuildPhase && numClaimed[id]) {
#if defined DEBUG_RESET
    logd("Resetting entities locked by %N", id);
#endif
    for (new entity; (entity = cs_find_ent_by_class(entity, BB_OBJECT)) != 0;) {
      if (GetBlockClaimer(entity) == id) {
        unlock(entity);
      }
    }

    numClaimed[id] = 0;
  }
}

public bb_onGameStateChanged(const GameState: fromState, const GameState: toState) {
  if (fromState == BuildPhase) {
#if defined DEBUG_RESET
    logd("Resetting entity lockers...");
#endif
    for (new entity; (entity = cs_find_ent_by_class(entity, BB_OBJECT)) != 0;) {
      unlock(entity);
    }
  }
}

unlock(entity) {
  static locker;
  locker = GetBlockClaimer(entity);
  if (locker) {
#if defined DEBUG_GRABBING
    logd("%d unlocked by %N", entity, locker);
#endif
    UnclaimBlock(entity);
    entity_set_int(entity, EV_INT_rendermode, kRenderNormal);
    return true;
  }

  return false;
}

bool: lock(id, entity) {
  new const locker = GetBlockClaimer(entity);
  if (id == locker) {
    return false;
  }

#if defined DEBUG_GRABBING
  logd("%d locked by %N", entity, id);
#endif
  ClaimBlock(entity, id);
  entity_set_int(entity, EV_INT_rendermode, kRenderTransColor);
  entity_set_vector(entity, EV_VEC_rendercolor, LOCKED_COLOR);
  entity_set_float(entity, EV_FL_renderamt, LOCKED_ALPHA);
  return true;
}
