#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <logger>
#include <reapi>

#include "include/stocks/param_stocks.inc"

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_LOCKEDLIST
  //#define DEBUG_LOCKING
#else
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_LOCKEDLIST
  //#define DEBUG_LOCKING
#endif

#define EXTENSION_NAME "Locker"
#define VERSION_STRING "1.0.0"

static Array: locked[MAX_PLAYERS + 1] = { Invalid_Array, ... };

static fwReturn;
static blockedReason[256];

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
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public bb_onGameStateChanged(const GameState: fromState, const GameState: toState) {
  if (fromState == BuildPhase) {
    new players[MAX_PLAYERS], num, player;
    get_players_ex(players, num);
    for (new i = 0; i < num; i++) {
      player = players[i];
      unlockAll(player);
    }
  }
}

public client_disconnected(id) {
  if (locked[id]) {
    unlockAll(id, .destroy = true);
  }
}

unlockAll(id, bool: destroy = false) {
  if (!locked[id]) {
    return;
  }

#if defined DEBUG_LOCKEDLIST
  logd("releasing locked list for %N", id);
#endif
  new entity;
  new const Array: tmp = locked[id];
  new const size = ArraySize(tmp);
  for (new i = 0; i < size; i++) {
    entity = ArrayGetCell(tmp, 0);
    setLocker(entity, id, false);
  }

  if (destroy) {
#if defined DEBUG_LOCKEDLIST
    logd("destroying locked list for %N", id);
#endif
    ArrayDestroy(locked[id]);
    assert locked[id] == Invalid_Array;
  }
}

getLocker(entity) {
  assert is_valid_ent(entity);
  return GetEntLocker(entity);
}

setLocker(entity, id, bool: b, bool: blockable = true) {
  assert is_valid_ent(entity);
  assert is_valid_ent(id);
  new const locker = GetEntLocker(entity);
  if (locker && locker != id) {
    return;
  } else if (locker == id && b) {
    return;
  }

  if (b) {
    if (blockable) {
      fwReturn = bb_onBeforeLocked(id, entity);
      if (fwReturn) {
#if defined DEBUG_LOCKING
        logd("%N's lock was blocked by another extension: \"%s\"", id, blockedReason);
#endif
        bb_onLockBlocked(id, entity, blockedReason);
        return;
      }
    }
    
    if (!locked[id]) {
      locked[id] = ArrayCreate(.reserved = 16);
#if defined DEBUG_LOCKEDLIST
      assert locked[id];
      logd("Initialized locked[%N] container as cellarray %d", id, locked[id]);
#endif
    }

    ArrayPushCell(locked[id], entity);
    SetEntLocker(entity, id);
    bb_onLocked(id, entity);
#if defined DEBUG_LOCKING
    logd("%N locked %d", id, entity);
#endif
  } else {
#if defined DEBUG_LOCKEDLIST
    assert locked[id];
#endif
    new index = ArrayFindValue(locked[id], entity);
    ArrayDeleteItem(locked[id], index);
    ResetEntLocker(entity);
    bb_onUnlocked(id, entity);
#if defined DEBUG_LOCKING
    logd("%N unlocked %d", id, entity);
#endif
  }
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

static onBeforeLocked = INVALID_HANDLE;
static onLockBlocked = INVALID_HANDLE;
static onLocked = INVALID_HANDLE;
static onUnlocked = INVALID_HANDLE;

bb_onBeforeLocked(const id, const entity) {
  if (onBeforeLocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onBeforeLocked");
#endif
    onBeforeLocked = CreateMultiForward(
        "bb_onBeforeLocked", ET_STOP,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onBeforeLocked = %d", onBeforeLocked);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onBeforeLocked(%d, %d) for %N", id, entity, id);
#endif
  blockedReason[0] = EOS;
  ExecuteForward(onBeforeLocked, fwReturn, id, entity);
  return fwReturn;
}

bb_onLockBlocked(const id, const entity, reason[]) {
  if (onLockBlocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onLockBlocked");
#endif
    onLockBlocked = CreateMultiForward(
        "bb_onLockBlocked", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    logd("onLockBlocked = %d", onLockBlocked);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onLockBlocked(%d, %d, reason=\"%s\") for %N", id, entity, reason, id);
#endif
  ExecuteForward(onLockBlocked, _, id, entity, reason);
  return fwReturn;
}

bb_onLocked(const id, const entity) {
  if (onLocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onLocked");
#endif
    onLocked = CreateMultiForward(
        "bb_onLocked", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onLocked = %d", onLocked);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onLocked(%d, %d) for %N", id, entity, id);
#endif
  ExecuteForward(onLocked, _, id, entity);
}

bb_onUnlocked(const id, const entity) {
  if (onUnlocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onUnlocked");
#endif
    onUnlocked = CreateMultiForward(
        "bb_onUnlocked", ET_CONTINUE,
        FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onUnlocked = %d", onUnlocked);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onUnlocked(%d, %d) for %N", id, entity, id);
#endif
  ExecuteForward(onUnlocked, _, id, entity);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

stock bool: operator=(value) return bool:(value);

public plugin_natives() {
  register_library("bb_locker");

  register_native("bb_getLocker", "native_getLocker");
  register_native("bb_setLocker", "native_setLocker");

  register_native("bb_getUserLockedNum", "native_getUserLockedNum");
  register_native("bb_getUserLocked", "native_getUserLocked");

  register_native("bb_setBlockLockReason", "native_setBlockLockReason");
}

//native bb_getLocker(const entity);
public native_getLocker(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return false;
  }
#endif

  new const entity = get_param(1);
  return getLocker(entity);
}

//native bb_setLocker(const entity, const id, const bool: b, const bool: blockable = true);
public native_setLocker(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(4, numParams)) {
    return;
  }
#endif

  new const entity = get_param(1);
  new const id = get_param(2);
  new const bool: b = get_param(3);
  new const bool: blockable = get_param(4);
  if (!is_user_connected(id)) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return;
  }

  setLocker(entity, id, b, blockable);
}

//native bb_getUserLockedNum(const id);
public native_getUserLockedNum(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return 0;
  }
#endif

  new const id = get_param(1);
  if (!is_user_connected(id)) {
    return 0;
  } else if (!locked[id]) {
    return 0;
  }

  return ArraySize(locked[id]);
}

//native Array: bb_getUserLocked(const id);
public Array: native_getUserLocked(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return Invalid_Array;
  }
#endif

  new const id = get_param(1);
  if (!is_user_connected(id)) {
    return Invalid_Array;
  }

  if (!locked[id]) {
    return ArrayCreate(.reserved = 0);
  }

  return ArrayClone(locked[id]);
}

//native bb_setBlockLockReason(const reason[]);
public native_setBlockLockReason(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return;
  }
#endif

  new len = get_string(1, blockedReason, charsmax(blockedReason));
  blockedReason[len] = EOS;
#if defined DEBUG_NATIVES
  logd("blockedReason=%s", blockedReason);
#endif
}
