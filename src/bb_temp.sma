#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <logger>
#include <xs>

#include "include/bb/basebuilder.inc"

#define DEBUG_ENT_IDS
#define DEBUG_ZONES

#define EXTENSION_NAME "Temp"
#define VERSION_STRING "1.0.0"

#define TERRITORY_COLOR Float: { 255.0, 255.0, 255.0 }
#define TERRITORY_OPACITY 0.0

#if defined DEBUG_ENT_IDS
static g_iHudSync;
static g_fwOnTraceline;
#endif

static laser;

public zm_onPrecache() {
  laser = precache_model("sprites/zbeam5.spr");
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

#if defined DEBUG_ENT_IDS
  bb_registerConCmd(
      .command = "debugents",
      .callback = "onDebugEnts",
      .desc = "Outputs info for the target entity",
      .access = ADMIN_ALL);

  g_iHudSync = CreateHudSyncObj();
#endif

#if defined DEBUG_ZONES
  bb_registerConCmd(
      .command = "debugzones",
      .callback = "onDebugZones",
      .desc = "Draws zones",
      .access = ADMIN_ALL);
#endif
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onDebugEnts(id) {
  if (g_fwOnTraceline) {
    console_print(id, "Disabling debug ents");
    unregister_forward(FM_TraceLine, g_fwOnTraceline, 1);
    g_fwOnTraceline = 0;
  } else {
    console_print(id, "Enabling debug ents");
    g_fwOnTraceline = register_forward(FM_TraceLine, "onTraceline", 1);
  }
  
  return PLUGIN_HANDLED;
}

public onTraceline(Float:start[3], Float:end[3], conditions, id, trace) {	
  static ent;
  ent = get_tr2(trace, TR_pHit);
  if (!is_valid_ent(ent)) {
      ClearSyncHud(id, g_iHudSync);
      return FMRES_IGNORED;
  }

  static szFormattedHud[128], len;
  len = 0;
  set_hudmessage(0, 50, 255, -1.0, 0.60, 1, 0.01, 3.0, 0.01, 0.01);
  static classname[32], targetname[32];
  pev(ent, pev_classname, classname, 31);
  pev(ent, pev_targetname, targetname, 31);
  len += formatex(szFormattedHud[len], 127 - len, "%d", ent);
  len += formatex(szFormattedHud[len], 127 - len, "\nclassname: %s", classname);
  len += formatex(szFormattedHud[len], 127 - len, "\ntargetname: %s", targetname);
  ShowSyncHudMsg(id, g_iHudSync, szFormattedHud);

  return FMRES_IGNORED;
}

public onDebugZones(id) {
  console_print(id, "Enabling debug zone BBOXes");

  new zone = MaxClients;
  while ((zone = find_ent_by_class(zone, BB_TERRITORY)) > 0) {
    console_print(id, "Drawing %s=%d", BB_TERRITORY, zone);
    drawZone(id, zone);
  }
  
  zone = MaxClients;
  while ((zone = find_ent_by_class(zone, BB_BUILDER_SPAWN)) > 0) {
    console_print(id, "Drawing %s=%d", BB_BUILDER_SPAWN, zone);
    drawZone(id, zone);
  }
  
  zone = MaxClients;
  while ((zone = find_ent_by_class(zone, BB_ZOMBIE_SPAWN)) > 0) {
    console_print(id, "Drawing %s=%d", BB_ZOMBIE_SPAWN, zone);
    drawZone(id, zone);
  }

  return PLUGIN_HANDLED;
}

drawZone(id, ent) {
  new Float: origin[3], Float: mins[3], Float: maxs[3];
  entity_get_vector(ent, EV_VEC_origin, origin);
  entity_get_vector(ent, EV_VEC_mins, mins);
  entity_get_vector(ent, EV_VEC_maxs, maxs);
  drawBox(id, origin, mins, maxs);
}

#define DEBUG_ZONE_MSG(%1) logd("%s[]={%.0f,%.0f,%.0f}",#%1,%1[0],%1[1],%1[2])

drawBox(id, Float:origin[3], Float:mins[3], Float:maxs[3]) {
  new start[3], end[3];
  xs_vec_add(origin, mins, mins);
  xs_vec_add(origin, maxs, maxs);
  
  mins[0] += 8.0;
  mins[1] += 8.0;
  mins[2] += 8.0;
  maxs[0] -= 8.0;
  maxs[1] -= 8.0;
  maxs[2] -= 8.0;
  /*new const Float: offs[3] = { 8.0, ... };
  DEBUG_ZONE_MSG(mins);
  xs_vec_add(offs, mins, mins);
  DEBUG_ZONE_MSG(mins);
  DEBUG_ZONE_MSG(maxs);
  xs_vec_sub(offs, maxs, maxs);
  DEBUG_ZONE_MSG(maxs);*/

  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[2] = end[2];
  start[1] = end[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[2] = end[2];
  start[0] = end[0];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[0] = end[0];
  start[1] = end[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[2] = start[2];
  end[1] = start[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[2] = start[2];
  end[0] = start[0];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[0] = start[0];
  end[1] = start[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[2] = start[2];
  start[0] = end[0];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[2] = start[2];
  start[1] = end[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[2] = end[2];
  end[0] = start[0];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[2] = end[2];
  end[1] = start[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  start[0] = end[0];
  end[1] = start[1];
  drawLine(id, start, end);
  FVecIVec(mins, start);
  FVecIVec(maxs, end);
  end[0] = start[0];
  start[1] = end[1];
  drawLine(id, start, end);
}

drawLine(id, start[3], end[3]) {
  message_begin(MSG_ONE, SVC_TEMPENTITY, .player = id); {
  write_byte(TE_BEAMPOINTS);
  write_coord(start[0]);
  write_coord(start[1]);
  write_coord(start[2]);
  write_coord(end[0]);
  write_coord(end[1]);
  write_coord(end[2]);
  write_short(laser);
  write_byte(0);
  write_byte(0);
  write_byte(600);
  write_byte(25);
  write_byte(0);
  write_byte(255);
  write_byte(255);
  write_byte(255);
  write_byte(255);
  write_byte(0);
  } message_end();
}
