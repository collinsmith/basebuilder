#define _bb_builder_included

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <logger>
#include <xs>

#include "include/stocks/param_stocks.inc"

#include "include/zm/zm_teams.inc"

#include "include/bb/bb_builder_consts.inc"
#include "include/bb/bb_builder_macros.inc"
#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_GRABBING
  //#define DEBUG_CMDSTART
  //#define DEBUG_PUSHPULL
  #define DEBUG_RESET
  //#define DEBUG_BLOCKED
#else
  //#define DEBUG_GRABBING
  //#define DEBUG_CMDSTART
  //#define DEBUG_PUSHPULL
  //#define DEBUG_RESET
  //#define DEBUG_BLOCKED
#endif

#define EXTENSION_NAME "Builder"
#define VERSION_STRING "1.0.0"

// ENABLE_ROTATION_ROLL only works if ENABLE_ROTATION_YAW is set
/** Enables rotating grabbed objects, seems to work okay */
#define ENABLE_ROTATION_YAW
/** Enables rotating grabbed objects on their roll axis. The engine seems to
    hate this. Disabled as it does not work okay (collisions are bad) */
//#define ENABLE_ROTATION_ROLL


#define PFLAG_TOGGLE_GRAB 0x00000001

const DEFAULT_FLAGS = 0;

static fwReturn = 0;
static onBeforeGrabbed = INVALID_HANDLE;
static onGrabBlocked = INVALID_HANDLE;
static onGrabbed = INVALID_HANDLE;
static onDropped = INVALID_HANDLE;
static onReset = INVALID_HANDLE;
static onResetAll = INVALID_HANDLE;
static onPush = INVALID_HANDLE;
static onPull = INVALID_HANDLE;

enum player_t {
  Float: BuildDelay,
  Float: EntDist,
  Float: EntOffset[3],
  OwnedEnt,
  PSet,
};

static pState[MAX_PLAYERS + 1][player_t];

static pFlags[MAX_PLAYERS + 1];

static Float: fMinEntDist, Float: fMaxEntDist;
static Float: fEntResetDist;
static Float: fPushPullRate;

#if defined ENABLE_ROTATION_YAW
static RotationMode;
#define RotationMode_Rotatable 1
#define RotationMode_Flippable 2
#endif

static Float: fOrigin1[3];
static Float: fOrigin2[3];
static Float: fOrigin3[3];

static blockedReason[256];

public plugin_natives() {
  register_library("bb_builder");

  register_native("bb_resetAll", "native_resetAll", 0);
  register_native("bb_reset", "native_reset", 0);
  register_native("bb_drop", "native_drop", 0);
  register_native("bb_isInPlayerPVS", "native_isInPlayerPVS", 0);
  register_native("bb_setBlockedReason", "native_setBlockedReason", 0);
}

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

  createCvars();

  register_forward(FM_CmdStart, "onCmdStart");
  register_forward(FM_PlayerPreThink, "onPlayerPreThink");
  register_forward(FM_AddToFullPack, "onAddToFullPack", 1);

  prepareEntities();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

#define CREATE_CVAR(%1,%2,%3,%4,%5) \
  name = %1;\
  LookupLangKey(desc, charsmax(desc), name, lang);\
  pcvar = create_cvar(name, #%4, _, desc,\
      .has_min = true, .min_val = %2, .has_max = true, .max_val = %3);\
  bind_pcvar_num(pcvar, %5);

#define CREATE_CVAR_F(%1,%2,%3,%4,%5) \
  name = %1;\
  LookupLangKey(desc, charsmax(desc), name, lang);\
  pcvar = create_cvar(name, #%4, _, desc,\
      .has_min = true, .min_val = %2, .has_max = true, .max_val = %3);\
  bind_pcvar_float(pcvar, %5);

createCvars() {
  new lang = LANG_SERVER;
  new pcvar, name[32], desc[256];
  CREATE_CVAR_F("bb_builder_minGrabDistance",16.0,256.0,32.0,fMinEntDist)
  CREATE_CVAR_F("bb_builder_maxGrabDistance",256.0,2048.0,1024.0,fMaxEntDist)
  CREATE_CVAR_F("bb_builder_grabResetDistance",0.0,64.0,16.0,fEntResetDist)
  CREATE_CVAR_F("bb_builder_pushPullRate",1.0,512.0,256.0,fPushPullRate)
#if defined ENABLE_ROTATION_YAW
  CREATE_CVAR("bb_builder_rotationMode",0.0,2.0,2,RotationMode)
#endif
}

#undef CREATE_CVAR
#undef CREATE_CVAR_F

prepareEntities() {
  new bb_object_[16];
  new const bb_object_len = copy(bb_object_, charsmax(bb_object_), BB_OBJECT_RAW);

  new target[16], class[10], len;
  new const count = entity_count();
  for (new entity = MaxClients + 1; entity < count; entity++) {
    if (!is_valid_ent(entity)) {
      continue;
    }

    entity_get_string(entity, EV_SZ_classname, class, charsmax(class));
    if (!equal(class, "func_wall")) {
      continue;
    } else if (equal(class, BB_IGNORE[0])) {
      continue;
    }

    entity_get_string(entity, EV_SZ_targetname, target, charsmax(target));
    // This is not compatible with all old maps
    //if (!equal(target, BB_OBJECT_RAW, 10)) {
    //  server_print("%d target=%s", entity, target);
    //  SetMoveType(entity, UNMOVABLE);
    //  continue;
    //}

    if (equal(target, BB_OBJECT_RAW, 10)) {
      SetMoveType(entity, read_flags(target[10]));
    } else {
      // TODO: Make sure this change is compatible with old maps
      SetMoveType(entity, MOVABLE);
      len = bb_object_len + get_flags(GetMoveType(entity), bb_object_[bb_object_len], charsmax(bb_object_)-bb_object_len);
      bb_object_[len] = EOS;
      entity_set_string(entity, EV_SZ_targetname, bb_object_);
    }

    if (GetMoveType(entity) == UNMOVABLE) {
      continue;
    }

    cs_set_ent_class(entity, BB_OBJECT);

    entity_get_vector(entity, EV_VEC_origin, fOrigin3);
    EntSetOffset(entity, fOrigin3);

#if defined ENABLE_ROTATION_YAW && defined ENABLE_ROTATION_ROLL
    entity_get_vector(entity, EV_VEC_mins, fOrigin1);
    EntSetMins(entity, fOrigin1);
    entity_get_vector(entity, EV_VEC_maxs, fOrigin2);
    EntSetMaxs(entity, fOrigin2);
    if (RotationMode == RotationMode_Flippable && (GetMoveType(entity) & FLIPPABLE)) {
      entity_set_int(entity, EV_INT_solid, SOLID_BBOX);
      entity_set_size(entity, fOrigin1, fOrigin2);
    }
#endif
  }
}

public client_putinserver(id) {
  pFlags[id] = DEFAULT_FLAGS;
}

public client_disconnected(id) {
  drop(id);
  pFlags[id] = 0;
}

bb_onBeforeGrabbed(id, entity) {
  if (onBeforeGrabbed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onBeforeGrabbed");
#endif
    onBeforeGrabbed = CreateMultiForward("bb_onBeforeGrabbed", ET_STOP, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onBeforeGrabbed = %d", onBeforeGrabbed);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onBeforeGrabbed(%d, entity=%d) for %N", id, entity, id);
#endif
  blockedReason[0] = EOS;
  ExecuteForward(onBeforeGrabbed, fwReturn, id, entity);
  return fwReturn;
}

bb_onGrabBlocked(id, entity, reason[]) {
  if (onGrabBlocked == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onGrabBlocked");
#endif
    onGrabBlocked = CreateMultiForward("bb_onGrabBlocked", ET_CONTINUE, FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    logd("onGrabBlocked = %d", onGrabBlocked);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onGrabBlocked(%d, entity=%d, reason=\"%s\") for %N", id, entity, reason, id);
#endif
  ExecuteForward(onGrabBlocked, fwReturn, id, entity, reason);
}

bb_onGrabbed(id, entity) {
  if (onGrabbed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onGrabbed");
#endif
    onGrabbed = CreateMultiForward("bb_onGrabbed", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onGrabbed = %d", onGrabbed);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onGrabbed(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onGrabbed, fwReturn, id, entity);
}

bb_onDropped(id, entity) {
  if (onDropped == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onDropped");
#endif
    onDropped = CreateMultiForward("bb_onDropped", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onDropped = %d", onDropped);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onDropped(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onDropped, fwReturn, id, entity);
}

bb_onReset(entity) {
  if (onReset == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onReset");
#endif
    onReset = CreateMultiForward("bb_onReset", ET_CONTINUE, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onReset = %d", onReset);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onReset(entity=%d)", entity);
#endif
  ExecuteForward(onReset, fwReturn, entity);
}

bb_onResetAll() {
  if (onResetAll == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onResetAll");
#endif
    onResetAll = CreateMultiForward("bb_onResetAll", ET_CONTINUE);
#if defined DEBUG_FORWARDS
    logd("onResetAll = %d", onResetAll);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onResetAll()");
#endif
  ExecuteForward(onResetAll, fwReturn);
}

bb_onPush(id, entity, bool: maxDist) {
  if (onPush == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onPush");
#endif
    onPush = CreateMultiForward(
        "bb_onPush", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onPush = %d", onPush);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onPush(%d, entity=%d, maxDist=%s) for %N",
      id, entity, maxDist ? TRUE : FALSE, id);
#endif
  ExecuteForward(onPush, fwReturn, id, entity, maxDist);
}

bb_onPull(id, entity, bool: minDist) {
  if (onPull == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onPull");
#endif
    onPull = CreateMultiForward(
        "bb_onPull", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onPull = %d", onPull);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onPull(%d, entity=%d, minDist=%s) for %N",
      id, entity, maxDist ? TRUE : FALSE, id);
#endif
  ExecuteForward(onPull, fwReturn, id, entity, minDist);
}

resetEntities() {
#if defined DEBUG_RESET
  logd("Resetting entities...");
#endif
  for (new entity; (entity = cs_find_ent_by_class(entity, BB_OBJECT)) != 0;) {
    reset(entity);
  }

  bb_onResetAll();
}

bool: reset(entity) {
  UnmovingEnt(entity);
  UnlockBlock(entity);
  UnsetEntMover(entity);
  UnsetLastMover(entity);

  entity_set_int(entity, EV_INT_rendermode, kRenderNormal);

  EntGetOffset(entity, fOrigin1);
  entity_set_origin(entity, fOrigin1);

#if defined ENABLE_ROTATION_YAW
  entity_set_vector(entity, EV_VEC_angles, NULL_VECTOR);
  
#if defined ENABLE_ROTATION_ROLL
  EntGetMins(entity, fOrigin1);
  EntGetMaxs(entity, fOrigin2);
  entity_set_size(entity, fOrigin1, fOrigin2);
#endif
#endif
  bb_onReset(entity);
  return true;
}

grab(id, entity, &Float: distance = 0.0) {
  if (!is_valid_ent(entity) || GetMoveType(entity) == UNMOVABLE || IsMovingEnt(entity)) {
    return;
  }

#if defined DEBUG_GRABBING
  logd("%N initiating grab on %d", id, entity);
#endif
  new const ownedEnt = pState[id][OwnedEnt];
  if (ownedEnt == entity) {
#if defined DEBUG_GRABBING
  logd("%N has already grabbed %d", id, entity);
#endif
    return;
  } else if (ownedEnt) {
    drop(id);
    return;
  }

  fwReturn = bb_onBeforeGrabbed(id, entity);
  if (fwReturn == PLUGIN_HANDLED) {
#if defined DEBUG_GRABBING || defined DEBUG_BLOCKED
    logd("%N's grab was blocked by another extension: \"%s\"", id, blockedReason);
#endif
    bb_onGrabBlocked(id, entity, blockedReason);
    return;
  }

  entity_get_vector(id, EV_VEC_origin, fOrigin2);
  get_aim_origin(id, fOrigin2, fOrigin3);
  entity_get_vector(entity, EV_VEC_origin, fOrigin1);
  xs_vec_sub(fOrigin1, fOrigin3, pState[id][EntOffset]);

  if (distance < fEntResetDist) {
    distance = fEntResetDist;
#if defined DEBUG_GRABBING
    logd("%N's entity distance reset to %.0f", id, distance);
#endif
  }
  
  pState[id][EntDist] = distance;

  MovingEnt(entity);
  SetEntMover(entity, id);
  pState[id][OwnedEnt] = entity;
  
  bb_onGrabbed(id, entity);
}

bool: drop(id) {
  new const entity = pState[id][OwnedEnt];
  if (!entity) {
    return false;
  }

#if defined DEBUG_GRABBING
  logd("Forcing %N to drop %d", id, entity);
#endif
  
  UnmovingEnt(entity);
  UnsetEntMover(entity);
  SetLastMover(entity, id);
  pState[id][OwnedEnt] = 0;

  bb_onDropped(id, entity);
  return true;
}

public onCmdStart(id, uc, randseet) {
  if (!is_user_alive(id)) {
    return FMRES_IGNORED;
  }

  new const buttons = get_uc(uc, UC_Buttons);
  new const oldbuttons = pev(id, pev_oldbuttons);
  new const bool: alreadyGrabbed = (pState[id][OwnedEnt] > 0);
  new const bool: isToggleGrabEnabled = (pFlags[id] & PFLAG_TOGGLE_GRAB) == PFLAG_TOGGLE_GRAB;
  if ((buttons & IN_USE) && !(oldbuttons & IN_USE)) {
#if defined DEBUG_CMDSTART
    logd("%N pressed IN_USE", id);
#endif
    if (isToggleGrabEnabled || !alreadyGrabbed) {
      new entity, body, Float: distance;
      distance = get_user_aiming(id, entity, body, floatround(fMaxEntDist));
      grab(id, entity, distance);
    }

    return FMRES_IGNORED;
  } else if ((oldbuttons & IN_USE) && !(buttons & IN_USE)
      && alreadyGrabbed && !isToggleGrabEnabled) {
#if defined DEBUG_CMDSTART
    logd("%N released IN_USE", id);
#endif
    drop(id);
    return FMRES_IGNORED;
  }

  // TODO: forward event for grab?
  return FMRES_IGNORED;
}

stock get_aim_origin(id, Float:start[3], Float:origin[3]) {
  static Float: view_ofs[3], Float: dest[3];
  entity_get_vector(id, EV_VEC_view_ofs, view_ofs);
  xs_vec_add(start, view_ofs, view_ofs);

  entity_get_vector(id, EV_VEC_v_angle, dest);
  engfunc(EngFunc_MakeVectors, dest);
  global_get(glb_v_forward, dest);
  xs_vec_mul_scalar(dest, 9999.0, dest);
  xs_vec_add(view_ofs, dest, dest);

  engfunc(EngFunc_TraceLine, view_ofs, dest, 0, id, 0);
  get_tr2(0, TR_vecEndPos, origin);

  return 1;
}

public onPlayerPreThink(id) {
  static entity;
  entity = pState[id][OwnedEnt];
  if (!entity) {
    return FMRES_IGNORED;
  }
  
  static Float: frametime, Float: pushPull;
  global_get(glb_frametime, frametime);
  pushPull = fPushPullRate * frametime;

  static buttons, oldbuttons;
  buttons = pev(id, pev_button);
  oldbuttons = pev(id, pev_oldbuttons);
  if (buttons & IN_ATTACK) {
    pState[id][EntDist] += pushPull;
    if (pState[id][EntDist] > fMaxEntDist) {
      pState[id][EntDist] = fMaxEntDist;
      bb_onPush(id, entity, true);
    } else {
      bb_onPush(id, entity, false);
    }
    
#if defined DEBUG_PUSHPULL
    client_print(id, print_center, "%.0f (%f units/sec)", pState[id][EntDist], pushPull);
#endif
  } else if (buttons & IN_ATTACK2) {
    pState[id][EntDist] -= pushPull;
    if (pState[id][EntDist] < fMinEntDist) {
      pState[id][EntDist] = fMinEntDist;
      bb_onPull(id, entity, true);
    } else {
      bb_onPull(id, entity, false);
    }
    
#if defined DEBUG_PUSHPULL
    client_print(id, print_center, "%.0f (%f units/sec)", pState[id][EntDist], pushPull);
#endif
#if defined ENABLE_ROTATION_YAW
  } else if (RotationMode
      && (buttons & IN_RELOAD) && !(oldbuttons & IN_RELOAD)
      && (GetMoveType(entity) & ROTATABLE)) {
    entity_get_vector(entity, EV_VEC_angles, fOrigin1);
    fOrigin1[1] += 90.0;
    entity_set_vector(entity, EV_VEC_angles, fOrigin1);

#if defined ENABLE_ROTATION_ROLL
    if (RotationMode == RotationMode_Flippable) {
      entity_get_vector(entity, EV_VEC_mins, fOrigin2);
      swap(fOrigin2, 0, 1);

      entity_get_vector(entity, EV_VEC_maxs, fOrigin3);
      swap(fOrigin3, 0, 1);

      entity_set_size(entity, fOrigin2, fOrigin3);
    }
  } else if (RotationMode == RotationMode_Flippable
      && (buttons & IN_SCORE) && !(oldbuttons & IN_SCORE)
      && (GetMoveType(entity) & FLIPPABLE)) {
    entity_get_vector(entity, EV_VEC_angles, fOrigin1);
    fOrigin1[2] += 90.0;
    entity_set_vector(entity, EV_VEC_angles, fOrigin1);

    entity_get_vector(entity, EV_VEC_mins, fOrigin2);
    entity_get_vector(entity, EV_VEC_maxs, fOrigin3);
    if (XS_FLEQ(fOrigin1[1], 0.0) || XS_FLEQ(fOrigin1[1], 180.0)) {
      swap(fOrigin2, 1, 2);
      swap(fOrigin3, 1, 2);
    } else {
      swap(fOrigin2, 0, 2);
      swap(fOrigin3, 0, 2);
    }

    entity_set_size(entity, fOrigin2, fOrigin3);
#endif
#endif
  }

  entity_get_vector(id, EV_VEC_origin, fOrigin1);
  get_aim_origin(id, fOrigin1, fOrigin2);
  
  static Float: fLength;
  fLength = floatmax(get_distance_f(fOrigin2, fOrigin1), 1.0);
  fLength = pState[id][EntDist] / fLength;
  
  xs_vec_sub(fOrigin2, fOrigin1, fOrigin2);
  xs_vec_mul_scalar(fOrigin2, fLength, fOrigin2);
  xs_vec_add(fOrigin1, fOrigin2, fOrigin3);
  xs_vec_add(fOrigin3, pState[id][EntOffset], fOrigin3);

  entity_set_origin(entity, fOrigin3);
  return FMRES_IGNORED;
}

stock swap(Float: array[], i, j) {
	static Float: temp;
	temp = array[i];
	array[i] = array[j];
	array[j] = temp;
}

public onAddToFullPack(es, e, entity, id, flags, player, set) {
  pState[id][PSet] = set;
  return FMRES_IGNORED;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native bool: bb_reset(entity);
public bool: native_reset(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return;
  }
#endif

  new const entity = get_param(1);
  return reset(entity);
}

//native bb_resetAlls();
public native_resetAll(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {
    return;
  }
#endif
	
  resetEntities();
}

//native bool: bb_drop(id);
public bool: native_drop(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  }

  return drop(id);
}

//native bool: bb_isInPlayerPVS(id, entity);
public bool: native_isInPlayerPVS(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  }

  new const entity = get_param(2);
  return bool:(engfunc(EngFunc_CheckVisibility, entity, pState[id][PSet]));
}

//native bb_setBlockedReason(const reason[]);
public native_setBlockedReason(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {}
#endif

  new len = get_string(1, blockedReason, charsmax(blockedReason));
  blockedReason[len] = EOS;
#if defined DEBUG_BLOCKED
  logd("blockedReason=%s", blockedReason);
#endif
}
