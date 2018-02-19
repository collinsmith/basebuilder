#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>
#include <reapi>

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_locker.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_CMDSTART
  #define DEBUG_LOCKING
#else
  //#define DEBUG_CMDSTART
  //#define DEBUG_LOCKING
#endif

#define EXTENSION_NAME "Locker (Controller)"
#define VERSION_STRING "1.0.0"

#define MAX_LOCKS_DISABLED -1
//#define FLAGS_GRAB_IGNORE_LOCKED ADMIN_SLAY

static Float: fMaxEntDist;
static iMaxLockable;

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
      .desc = "Default controller for object locking/unlocking");

  createCvars();

  new pcvar;
  new const cvar[] = "bb_builder_maxGrabDistance";
  pcvar = get_cvar_pointer(cvar);
  if (!pcvar) {
    logw("%s cvar was not found!", cvar);
    fMaxEntDist = 1024.0;
  } else {
    bind_pcvar_float(pcvar, fMaxEntDist);
  }

  register_forward(FM_CmdStart, "onCmdStart");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

#define CREATE_CVAR(%1,%2,%3,%4) \
    name = %1;\
    LookupLangKey(desc, charsmax(desc), name, lang);\
    pcvar = create_cvar(name, #%3, _, desc,\
        .has_min = true, .min_val = %2, .has_max = false);\
    bind_pcvar_num(pcvar, %4);

createCvars() {
  new lang = LANG_SERVER;
  new pcvar, name[32], desc[256];
  CREATE_CVAR("bb_maxLocks",-1.0,10,iMaxLockable)
}

#undef CREATE_CVAR

public onCmdStart(id, uc, randseed) {
  if (!is_user_alive(id)) {
    return FMRES_IGNORED;
  } else if (bb_getGameState() != BuildPhase) {
    return FMRES_IGNORED;
  }

  new const buttons = get_uc(uc, UC_Buttons);
  new const oldbuttons = pev(id, pev_oldbuttons);
  if (!bb_isUserGrabbing(id) && (buttons & IN_RELOAD) && !(oldbuttons & IN_RELOAD)) {
#if defined DEBUG_CMDSTART
    logd("%N pressed IN_RELOAD", id);
#endif
    new entity, body;
    get_user_aiming(id, entity, body, floatround(fMaxEntDist));
    bb_toggleLock(entity, id);
    return FMRES_IGNORED;
  }

  return FMRES_IGNORED;
}

public bb_onBeforeLocked(const id, const entity) {
  switch (iMaxLockable) {
    case MAX_LOCKS_DISABLED: return PLUGIN_CONTINUE;
    case 0: return PLUGIN_HANDLED;
    default: {
      if (bb_getUserLockedNum(id) >= iMaxLockable) {
        new reason[128];
        formatex(reason, charsmax(reason), "%L",
            id, "CANNOT_LOCK_MORE_THAN_X", iMaxLockable);
        bb_setBlockLockReason(reason);
        return PLUGIN_HANDLED;
      }
    }
  }

  return PLUGIN_CONTINUE;
}

public bb_onBeforeGrabbed(const id, const entity) {
  new const locker = bb_getLocker(entity);
  if (locker) {
#if defined FLAGS_GRAB_IGNORE_LOCKED
    new const adminFlags = get_user_flags(id);
    if (!(adminFlags & FLAGS_GRAB_IGNORE_LOCKED)) {
#endif
#if defined DEBUG_LOCKING
      logd("Grab blocked for %N! locked by %N", id, locker);
#endif
      new reason[128], lang = id;
      LookupLangKey(reason, charsmax(reason), "CANNOT_MOVE_LOCKED_OBJECTS", lang);
      bb_setBlockGrabReason(reason);
      return PLUGIN_HANDLED;
#if defined FLAGS_GRAB_IGNORE_LOCKED
    }
#endif
  }

  return PLUGIN_CONTINUE;
}
