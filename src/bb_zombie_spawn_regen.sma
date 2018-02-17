#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <logger>

#include "include/stocks/flag_stocks.inc"

#include "include/zm/zm_teams.inc"
#include "include/zm/zm_classes.inc"

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_zones.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_HEALING
#else
  //#define DEBUG_HEALING
#endif

#define EXTENSION_NAME "Zombie Spawn Regen"
#define VERSION_STRING "1.0.0"

static pHealing;
static Float: fRegenRate;

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
      .desc = "Regens Zombies' health when within Zombie Spawn");

  createCvars();
}

createCvars() {
  new lang = LANG_SERVER;
  new pcvar, name[32], desc[256];
  name = "bb_spawnRegenRate";
  LookupLangKey(desc, charsmax(desc), name, lang);
  pcvar = create_cvar(name, "1.0", _, desc,
      .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1000.0);
  bind_pcvar_float(pcvar, fRegenRate);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public bb_onTouchZombieSpawn(const id, const entity) {
  if (!zm_isUserZombie(id) || fRegenRate <= 0.0) {
    return;
  }

  new const Class: class = zm_getUserClass(id);
  if (class == Invalid_Trie) {
    return;
  }

  static value[8];
  new const bool: hasProperty = zm_getClassProperty(class, ZM_CLASS_HEALTH, value, charsmax(value));
  if (!hasProperty) {
    return;
  }

  new const Float: maxHealth = str_to_float(value);
  new const Float: health = entity_get_float(id, EV_FL_health);
  if (health < maxHealth) { 
    new const Float: regenedHealth = health + fRegenRate;
    entity_set_float(id, EV_FL_health, floatmin(maxHealth, regenedHealth));
    if (!isFlagSet(pHealing, id)) {
      setFlag(pHealing, id);
      client_cmd(id, "spk \"items/medcharge4\"");
#if defined DEBUG_HEALING
      logd("starting heal on %N", id);
#endif
    }
  } else if (isFlagSet(pHealing, id)) {
    unsetFlag(pHealing, id);
    client_cmd(id, "stopsound");
    client_cmd(id, "spk \"buttons/blip2\"");
#if defined DEBUG_HEALING
    logd("stopping heal on %N", id);
#endif
  }
}

public client_disconnected(id) {
  unsetFlag(pHealing, id);
}

public zm_onKilled(const victim, const killer) {
  if (isFlagSet(pHealing, victim)) {
    unsetFlag(pHealing, victim);
    client_cmd(victim, "stopsound");
  }
}
