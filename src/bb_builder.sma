#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>
#include <xs>

#include "include/bb/bb_builder_const.inc"
#include "include/bb/bb_builder_macros.inc"
#include "include/bb/basebuilder.inc"

#include "include/zm/zm_teams.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_GRABBING
  //#define DEBUG_CMDSTART
  #define DEBUG_PUSHPULL
#else
  //#define DEBUG_GRABBING
  //#define DEBUG_CMDSTART
  //#define DEBUG_PUSHPULL
#endif

#define EXTENSION_NAME "Builder"
#define VERSION_STRING "1.0.0"

// ENABLE_ROTATION_ROLL only works if ENABLE_ROTATION_YAW is set
/** Enables rotating grabbed objects, seems to work okay */
#define ENABLE_ROTATION_YAW
/** Enables rotating grabbed objects on their roll axis. The engine seems to
    hate this. Disabled as it does not work okay (collisions are bad) */
//#define ENABLE_ROTATION_ROLL

#define FLAGS_IGNORE_TEAM  ADMIN_RCON
#define FLAGS_IGNORE_STATE ADMIN_BAN

#define PFLAG_TOGGLE_GRAB 0x00000001

const DEFAULT_FLAGS = 0;

static Logger: logger = Invalid_Logger;

static fwReturn = 0;
static onBeforeGrabbed = INVALID_HANDLE;
static onGrabbed = INVALID_HANDLE;
static onDropped = INVALID_HANDLE;

enum player_t {
  Float: BuildDelay,
  Float: EntDist,
  Float: EntOffset[3],
  OwnedEnt,
  PSet,
}

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

public plugin_natives() {
  register_library("bb_builder");
}

public zm_onInit() {
  logger = bb_getLogger();
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

  register_event("HLTV", "eventRoundStart", "a", "1=0", "2=0");

  prepareEntities();
}

public eventRoundStart() {
  resetEntities();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

createCvars() {
  new lang_server = LANG_SERVER;
  new pcvar, name[32], desc[256];
  
  name = "bb_builder_minGrabDistance";
  LookupLangKey(desc, charsmax(desc), name, lang_server);
  pcvar = create_cvar(name, "32.0", _, desc,
      .has_min = true, .min_val = 16.0, .has_max = true, .max_val = 256.0);
  bind_pcvar_float(pcvar, fMinEntDist);
  
  name = "bb_builder_maxGrabDistance";
  LookupLangKey(desc, charsmax(desc), name, lang_server);
  pcvar = create_cvar(name, "1024.0", _, desc,
      .has_min = true, .min_val = 256.0, .has_max = true, .max_val = 2048.0);
  bind_pcvar_float(pcvar, fMaxEntDist);
  
  name = "bb_builder_grabResetDistance";
  LookupLangKey(desc, charsmax(desc), name, lang_server);
  pcvar = create_cvar(name, "64.0", _, desc,
      .has_min = true, .min_val = 16.0, .has_max = true, .max_val = 64.0);
  bind_pcvar_float(pcvar, fEntResetDist);
  
  name = "bb_builder_pushPullRate";
  LookupLangKey(desc, charsmax(desc), name, lang_server);
  pcvar = create_cvar(name, "128.0", _, desc,
      .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 512.0);
  bind_pcvar_float(pcvar, fPushPullRate);
  hook_cvar_change(pcvar, "var_change_callback");
  
#if defined ENABLE_ROTATION_YAW
  name = "bb_builder_rotationMode";
  LookupLangKey(desc, charsmax(desc), name, lang_server);
  RotationMode = create_cvar(name, "2", _, desc,
      .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 2.0);
  bind_pcvar_num(RotationMode, RotationMode);
#endif
}

public cvar_change_callback(pcvar, const old_value[], const new_value[]) {
  server_print("cvar %d changed %s=%s [%.2f]", pcvar, old_value, new_value, fPushPullRate);
}

prepareEntities() {
  new target[16], class[10];
  new const count = entity_count();
  for (new entity = MaxClients + 1; entity < count; entity++) {
    if (!is_valid_ent(entity)) {
      continue;
    }

    entity_get_string(entity, EV_SZ_classname, class, charsmax(class));
    if (!equal(class, "func_wall")) {
      continue;
    }

    entity_get_string(entity, EV_SZ_targetname, target, charsmax(target));
    if (!equal(target, BB_OBJECT_RAW, 10)) {
      SetMoveType(entity, UNMOVABLE);
      continue;
    }

    SetMoveType(entity, read_flags(target[10]));
    if (GetMoveType(entity) == UNMOVABLE) {
      continue;
    }

    entity_set_string(entity, EV_SZ_classname, BB_OBJECT);

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

zm_onBeforeGrabbed(id, entity) {
  if (onBeforeGrabbed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onBeforeGrabbed");
#endif
    onBeforeGrabbed = CreateMultiForward("zm_onBeforeGrabbed", ET_STOP, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onBeforeGrabbed = %d", onBeforeGrabbed);
#endif
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeGrabbed(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onBeforeGrabbed, fwReturn, id, entity);
  return fwReturn;
}

zm_onGrabbed(id, entity) {
  if (onGrabbed == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onGrabbed");
#endif
    onGrabbed = CreateMultiForward("zm_onGrabbed", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onGrabbed = %d", onGrabbed);
#endif
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onGrabbed(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onGrabbed, fwReturn, id, entity);
}

zm_onDropped(id, entity) {
  if (onDropped == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onDropped");
#endif
    onDropped = CreateMultiForward("zm_onDropped", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onDropped = %d", onDropped);
#endif
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onDropped(%d, entity=%d) for %N", id, entity, id);
#endif
  ExecuteForward(onDropped, fwReturn, id, entity);
}

resetEntities() {
  for (new entity; (entity = find_ent_by_class(entity, BB_OBJECT)) != 0;) {
    reset(entity);
  }
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
  return true;
}

grab(id, entity, &Float: distance = 0.0) {
  if (!is_valid_ent(entity) || GetMoveType(entity) == UNMOVABLE || IsMovingEnt(entity)) {
    return;
  }

#if defined DEBUG_GRABBING
  LoggerLogDebug(logger, "%N initiating grab on %d", id, entity);
#endif
  new const ownedEnt = pState[id][OwnedEnt];
  if (ownedEnt == entity) {
#if defined DEBUG_GRABBING
  LoggerLogDebug(logger, "%N has already grabbed %d", id, entity);
#endif
    return;
  } else if (ownedEnt) {
    drop(id);
    return;
  }

  new adminFlags = get_user_flags(id);
  if (zm_isUserZombie(id) && !(adminFlags & FLAGS_IGNORE_TEAM)) {
#if defined DEBUG_GRABBING
    LoggerLogDebug(logger, "%N is a zombie without grab override privileges", id);
#endif
    return;
  /*} else if (bb_getGameState() != BB_STATE_BUILDING && !(adminFlags & FLAGS_IGNORE_STATE)) {
    client_print(id, print_center, "%l", "NOT_BUILD_STATE");
    return;*/
  }

  fwReturn = zm_onBeforeGrabbed(id, entity);
  if (fwReturn == PLUGIN_HANDLED) {
#if defined DEBUG_GRABBING
    LoggerLogDebug(logger, "%N's grab was blocked by another extension", id);
#endif
    return;
  }

  entity_get_vector(id, EV_VEC_origin, fOrigin2);
  get_aim_origin(id, fOrigin2, fOrigin3);
  entity_get_vector(entity, EV_VEC_origin, fOrigin1);
  xs_vec_sub(fOrigin1, fOrigin3, pState[id][EntOffset]);

  if (distance < fEntResetDist) {
    distance = fEntResetDist;
#if defined DEBUG_GRABBING
    LoggerLogDebug(logger, "%N's entity distance reset to %.0f", id, distance);
#endif
  }
  
  pState[id][EntDist] = distance;

  MovingEnt(entity);
  SetEntMover(entity, id);
  pState[id][OwnedEnt] = entity;
  
  zm_onGrabbed(id, entity);
}

bool: drop(id) {
  new const entity = pState[id][OwnedEnt];
  if (!entity) {
    return false;
  }

#if defined DEBUG_GRABBING
  LoggerLogDebug(logger, "Forcing %N to drop %d", id, entity);
#endif
  
  UnmovingEnt(entity);
  UnsetEntMover(entity);
  SetLastMover(entity, id);
  pState[id][OwnedEnt] = 0;

  zm_onDropped(id, entity);
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
    LoggerLogDebug(logger, "%N pressed IN_USE", id);
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
    LoggerLogDebug(logger, "%N released IN_USE", id);
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
#if !defined DEBUG_PUSHPULL
      client_print(id, print_center, "%l", "PUSHED_MAX_DIST");
    } else {
      client_print(id, print_center, "%l", "PUSHING");
#endif
    }
    
#if defined DEBUG_PUSHPULL
    client_print(id, print_center, "%.0f (%f units/sec)", pState[id][EntDist], pushPull);
#endif
  } else if (buttons & IN_ATTACK2) {
    pState[id][EntDist] -= pushPull;
    if (pState[id][EntDist] < fMinEntDist) {
      pState[id][EntDist] = fMinEntDist;
#if !defined DEBUG_PUSHPULL
      client_print(id, print_center, "%l", "PUSHED_MIN_DIST");
    } else {
      client_print(id, print_center, "%l", "PULLING");
      client_print(id, print_center, "%.0f", pState[id][EntDist]);
#endif
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
