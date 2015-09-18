#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <xs>

#include "include/bb/bb_zones_const.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_colorchat.inc"
#include "include/bb/bb_commands.inc"

#define PLUGIN_VERSION "0.0.1"

#define SELECT_SPHERE_RADIUS 128.0
#define TER_BBOX_INC 8.0

static const BB_SPAWN_ZOMBIE[] = "bb_spawn_zombie";
static const BB_SPAWN_BUILDER[] = "bb_spawn_builder";
static const BB_TERRITORY[] = "bb_territory";

static g_iCurEditor;
static g_iEditingZone;

static g_Menu_Creator;
static g_Menu_Team;
static g_Menu_Editor;

static g_iLaserSprite;

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Zone Maker]", "Loads/Creates zones used by this plugin", PLUGIN_VERSION);
	
	g_iLaserSprite = precache_model("sprites/zbeam5.spr");
	
	loadSpawns();
}

public bb_fw_init_post() {
	bb_command_register("zones", "fwCommandZones", "abcde", "Opens the zone editing menu", ADMIN_CVAR);
}

public fwCommandZones(id, player, message[]) {
	showZoneMenu(id);
}

public plugin_init() {
	g_iCurEditor = null;
	g_iEditingZone = null;
	
	g_Menu_Creator = menu_create("Zone Editor", "zoneMenuHandler");
	menu_setprop(g_Menu_Creator, MPROP_PERPAGE, 0);
	menu_additem(g_Menu_Creator, "Create by Aim");
	menu_additem(g_Menu_Creator, "Select by Aim");
	menu_addblank(g_Menu_Creator, 0);
	menu_additem(g_Menu_Creator, "Exit");
	
	g_Menu_Team = menu_create("Which team is this zone for?", "zoneTeamHandler");
	menu_setprop(g_Menu_Team, MPROP_PERPAGE, 0);
	menu_additem(g_Menu_Team, "Neutral Human");
	menu_additem(g_Menu_Team, "Human Spawn");
	menu_additem(g_Menu_Team, "Zombie Spawn");
	//menu_setprop(g_Menu_Team, MPROP_EXIT, MEXIT_NEVER);
	
	g_Menu_Editor = menu_create("Zone Editor [Editing]", "zoneEditorHandler");
	menu_setprop(g_Menu_Editor, MPROP_PERPAGE, 0);
	menu_additem(g_Menu_Editor, "Change Team");
	//menu_addblank(g_Menu_Editor);
	menu_additem(g_Menu_Editor, "Height +");
	menu_additem(g_Menu_Editor, "Height -");
	//menu_addblank(g_Menu_Editor);
	menu_additem(g_Menu_Editor, "Width +");
	menu_additem(g_Menu_Editor, "Width -");
	//menu_addblank(g_Menu_Editor);
	menu_additem(g_Menu_Editor, "Length +");
	menu_additem(g_Menu_Editor, "Length -");
	//menu_addblank(g_Menu_Editor);
	menu_additem(g_Menu_Editor, "Delete Zone");
	menu_addblank(g_Menu_Creator, 0);
	menu_additem(g_Menu_Editor, "Exit");
}

public plugin_natives() {
	register_library("BB_Zones");
	
	register_native("bb_zone_isWithinZone", "_isWithinZone", 0);
	register_native("bb_zone_getZoneType", "_getZoneType", 0);
}

public plugin_end() {
	saveSpawns();
}

public showZoneMenu(id) {
	if (!access(id, ADMIN_CVAR)) {
		return PLUGIN_HANDLED;
	}
	
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return PLUGIN_HANDLED;
	}
	
	if (is_user_connected(g_iCurEditor) && g_iCurEditor != id) {
		bb_printColor(id, "Someone else is already editing the zones!");
		return PLUGIN_HANDLED;
	}
	
	static zone;
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_SPAWN_BUILDER)) != 0) {
		solidifyZone(zone);
	}
	
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_SPAWN_ZOMBIE)) != 0) {
		solidifyZone(zone);
	}
	
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_TERRITORY)) != 0) {
		solidifyZone(zone);
	}
	
	g_iCurEditor = id;
	g_iEditingZone = null;
	menu_display(id, g_Menu_Creator);
	
	return PLUGIN_HANDLED;
}

solidifyZone(ent) {
	new Float:origin[3], Float:mins[3], Float:maxs[3];
	entity_get_vector(ent, EV_VEC_origin, origin);
	entity_get_vector(ent, EV_VEC_mins, mins);
	entity_get_vector(ent, EV_VEC_maxs, maxs);
	drawBox(origin, mins, maxs);
}

public zoneMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		g_iCurEditor = null;
		g_iEditingZone = null;
		return PLUGIN_HANDLED;
	}
	
	switch (item) {
		case 0: {
			new Float:origin[3];
			get_aim_origin(id, origin);
			g_iEditingZone = create_entity("info_target"); 
			entity_set_int(g_iEditingZone, EV_INT_solid, SOLID_TRIGGER);
			entity_set_origin(g_iEditingZone, origin);
			entity_set_size(g_iEditingZone, Float:{-128.0,-128.0,-128.0}, Float:{128.0,128.0,128.0});
			
			new Float:mins[3], Float:maxs[3];
			entity_get_vector(g_iEditingZone, EV_VEC_mins, mins);
			entity_get_vector(g_iEditingZone, EV_VEC_maxs, maxs);
			drawBox(origin, mins, maxs);
			
			showTeamMenu(id);
		}
		case 1: {
			new Float:origin[3];
			get_aim_origin(id, origin);
			
			new ents[2];
			find_sphere_class(0, BB_SPAWN_BUILDER, SELECT_SPHERE_RADIUS, ents, 1, origin);
			find_sphere_class(0, BB_SPAWN_ZOMBIE, SELECT_SPHERE_RADIUS, ents, 1, origin);
			find_sphere_class(0, BB_TERRITORY, SELECT_SPHERE_RADIUS, ents, 1, origin);
			if (ents[0]) {
				bb_printColor(id, "Found an entity!");
				g_iEditingZone = ents[0];
				new Float:origin[3], Float:mins[3], Float:maxs[3];
				entity_get_vector(g_iEditingZone, EV_VEC_origin, origin);
				entity_get_vector(g_iEditingZone, EV_VEC_mins, mins);
				entity_get_vector(g_iEditingZone, EV_VEC_maxs, maxs);
				drawBox(origin, mins, maxs);
				showEditorMenu(id);
				return PLUGIN_HANDLED;
			}
			
			g_iEditingZone = null;
			bb_printColor(id, "Failed to find target entity!");
			showZoneMenu(id);
			return PLUGIN_HANDLED;
		}
		case 2: {
			g_iCurEditor = null;
			g_iEditingZone = null;
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_HANDLED;
}

stock get_aim_origin(id, Float:origin[3]) {
	static Float:start[3], Float:view_ofs[3], Float:dest[3];
	entity_get_vector(id, EV_VEC_view_ofs, view_ofs);
	entity_get_vector(id, EV_VEC_origin, start);
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

showTeamMenu(id) {
	if (g_iCurEditor != id) {
		return;
	}

	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	menu_display(id, g_Menu_Team);
}


public zoneTeamHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		g_iCurEditor = null;
		g_iEditingZone = null;
		return PLUGIN_HANDLED;
	}
	
	switch (item) {
		case 0: {
			entity_set_string(g_iEditingZone, EV_SZ_classname, BB_TERRITORY);
			entity_set_string(g_iEditingZone, EV_SZ_targetname, BB_TERRITORY);
		}
		case 1: {
			entity_set_string(g_iEditingZone, EV_SZ_classname, BB_SPAWN_BUILDER);
			entity_set_string(g_iEditingZone, EV_SZ_targetname, BB_SPAWN_BUILDER);
		}
		case 2: {
			entity_set_string(g_iEditingZone, EV_SZ_classname, BB_SPAWN_ZOMBIE);
			entity_set_string(g_iEditingZone, EV_SZ_targetname, BB_SPAWN_ZOMBIE);
		}
	}

	showEditorMenu(id);
	return PLUGIN_HANDLED;
}

showEditorMenu(id) {
	if (g_iCurEditor != id) {
		return;
	}

	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	menu_display(id, g_Menu_Editor);
}

public zoneEditorHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		g_iCurEditor = null;
		g_iEditingZone = null;
		return PLUGIN_HANDLED;
	}
	
	new Float:origin[3], Float:mins[3], Float:maxs[3];
	entity_get_vector(g_iEditingZone, EV_VEC_origin, origin);
	entity_get_vector(g_iEditingZone, EV_VEC_mins, mins);
	entity_get_vector(g_iEditingZone, EV_VEC_maxs, maxs);
	switch (item) {
		case 0: {
			showTeamMenu(id);
		}
		case 1: {
			floatclamp(mins[2] -= TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[2] += TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 2: {
			floatclamp(mins[2] += TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[2] -= TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 3: {
			floatclamp(mins[0] -= TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[0] += TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 4: {
			floatclamp(mins[0] += TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[0] -= TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 5: {
			floatclamp(mins[1] -= TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[1] += TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 6: {
			floatclamp(mins[1] += TER_BBOX_INC, -TER_BBOX_INC, -1024.0);
			floatclamp(maxs[1] -= TER_BBOX_INC, TER_BBOX_INC, 1024.0);
			entity_set_size(g_iEditingZone, mins, maxs);
			drawBox(origin, mins, maxs);
			showEditorMenu(id);
		}
		case 7: {
			remove_entity(g_iEditingZone);
			g_iEditingZone = null;
			showZoneMenu(id);
		}
		case 8: {
			g_iEditingZone = null;
			showZoneMenu(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

//native bb_zone_isWithinZone(ent);
public _isWithinZone(plugin, params) {
	if (params != 1) {
		return null;
	}
	
	return isWithinZone(get_param(1));
}

isWithinZone(ent) {
	static zone;
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_SPAWN_BUILDER)) != 0) {
		if (isTouching(ent, zone)) {
			return zone;
		}
	}
	
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_SPAWN_ZOMBIE)) != 0) {
		if (isTouching(ent, zone)) {
			return zone;
		}
	}
	
	zone = -1;
	while ((zone = find_ent_by_class(zone, BB_TERRITORY)) != 0) {
		if (isTouching(ent, zone)) {
			return zone;
		}
	}
	
	return null;
}

bool:isTouching(ent, zone) {
	static Float:entOrigin[3], Float:entMins[3], Float:entMaxs[3];
	entity_get_vector(ent, EV_VEC_origin, entOrigin);
	entity_get_vector(ent, EV_VEC_mins, entMins);
	xs_vec_add(entOrigin, entMins, entMins);
	entity_get_vector(ent, EV_VEC_maxs, entMaxs);
	xs_vec_add(entOrigin, entMaxs, entMaxs);
	
	static Float:origin[3], Float:mins[3], Float:maxs[3];
	entity_get_vector(zone, EV_VEC_origin, origin);
	entity_get_vector(zone, EV_VEC_mins, mins);
	xs_vec_add(origin, mins, mins);
	entity_get_vector(zone, EV_VEC_maxs, maxs);
	xs_vec_add(origin, maxs, maxs);
	
	return		(entMins[0] < maxs[0]) && (entMaxs[0] > mins[0])
			&&	(entMins[1] < maxs[1]) && (entMaxs[1] > mins[1])
			&&	(entMins[2] < maxs[2]) && (entMaxs[2] > mins[2]);
}

//native BB_ZONE_TYPE:bb_zone_getZoneType(ent);
public BB_ZONE_TYPE:_getZoneType(plugin, params) {
	new zone = get_param(1);
	
	new ent = -1;
	while ((ent = find_ent_by_class(ent, BB_SPAWN_BUILDER)) != 0) {
		if (ent == zone) {
			return BB_ZONE_BUILDER_SPAWN;
		}
	}
	
	ent = -1;
	while ((ent = find_ent_by_class(ent, BB_SPAWN_ZOMBIE)) != 0) {
		if (ent == zone) {
			return BB_ZONE_ZOMBIE_SPAWN;
		}
	}
	
	ent = -1;
	while ((ent = find_ent_by_class(ent, BB_TERRITORY)) != 0) {
		if (ent == zone) {
			return BB_ZONE_TERRITORY;
		}
	}
	
	return BB_ZONE_INVALID;
}

loadSpawns() {
	new szMapFile[128];
	new len = get_configsdir(szMapFile, 127);
	szMapFile[len++] = '/';
	len += copy(szMapFile[len], 127-len, BB_HOME_DIR);
	len += copy(szMapFile[len], 127-len, "territories/");
	mkdir(szMapFile);
	len += get_mapname(szMapFile[len], 127-len);
	len += copy(szMapFile[len], 127-len, ".cfg");
	if (!file_exists(szMapFile)) {
		server_print("Failed to locate base spawn zone file");
		return;
	}
	
	new ent, szOrigin[3][16], szMins[3][16], szMaxs[3][16];
	new Float:origin[3], Float:mins[3], Float:maxs[3];
	new szLine[256], line;
	while ((line = read_file(szMapFile, line, szLine, 255, len)) != 0) {
		parse(szLine[1], 	szOrigin[0], 15, szOrigin[1], 15, szOrigin[2], 15,
							szMins[0], 15, szMins[1], 15, szMins[2], 15,
							szMaxs[0], 15, szMaxs[1], 15, szMaxs[2], 15);
		
		for (new i = 0; i < 3; i++) {
			origin[i]	= str_to_float(szOrigin[i]);
			mins[i]		= str_to_float(szMins[i]);
			maxs[i]		= str_to_float(szMaxs[i]);
		}
		
		ent = create_entity("info_target");
		entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);
		switch (szLine[0]) {
			case 'T': {
				entity_set_string(ent, EV_SZ_classname, BB_TERRITORY);
				entity_set_string(ent, EV_SZ_targetname, BB_TERRITORY);
			}
			case 'H': {
				entity_set_string(ent, EV_SZ_classname, BB_SPAWN_BUILDER);
				entity_set_string(ent, EV_SZ_targetname, BB_SPAWN_BUILDER);
			}
			case 'Z': {
				entity_set_string(ent, EV_SZ_classname, BB_SPAWN_ZOMBIE);
				entity_set_string(ent, EV_SZ_targetname, BB_SPAWN_ZOMBIE);
			}
		}
		
		entity_set_origin(ent, origin);
		entity_set_size(ent, mins, maxs);	
	}
}

saveSpawns() {
	new szMapFile[128];
	new len = get_configsdir(szMapFile, 127);
	szMapFile[len++] = '/';
	len += copy(szMapFile[len], 127-len, BB_HOME_DIR);
	len += copy(szMapFile[len], 127-len, "territories/");
	len += get_mapname(szMapFile[len], 127-len);
	len += copy(szMapFile[len], 127-len, ".cfg");
	
	new line = 0, ent = -1;
	new Float:origin[3], Float:mins[3], Float:maxs[3], szLine[256];
	while ((ent = find_ent_by_class(ent, BB_SPAWN_BUILDER)) != 0) {
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		formatex(szLine, 255, "H %f %f %f %f %f %f %f %f %f", origin[0], origin[1], origin[2], mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2]);
		write_file(szMapFile, szLine, line++);
	}
	
	ent = -1;
	while ((ent = find_ent_by_class(ent, BB_SPAWN_ZOMBIE)) != 0) {
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		formatex(szLine, 255, "Z %f %f %f %f %f %f %f %f %f", origin[0], origin[1], origin[2], mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2]);
		write_file(szMapFile, szLine, line++);
	}
	
	ent = -1;
	while ((ent = find_ent_by_class(ent, BB_TERRITORY)) != 0) {
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_mins, mins);
		entity_get_vector(ent, EV_VEC_maxs, maxs);
		formatex(szLine, 255, "T %f %f %f %f %f %f %f %f %f", origin[0], origin[1], origin[2], mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2]);
		write_file(szMapFile, szLine, line++);
	}
}

drawBox(Float:origin[3], Float:mins[3], Float:maxs[3]) {
	new start[3], end[3];
	xs_vec_add(origin, mins, mins);
	xs_vec_add(origin, maxs, maxs);

	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[2] = end[2];
	start[1] = end[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[2] = end[2];
	start[0] = end[0];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[0] = end[0];
	start[1] = end[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[2] = start[2];
	end[1] = start[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[2] = start[2];
	end[0] = start[0];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[0] = start[0];
	end[1] = start[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[2] = start[2];
	start[0] = end[0];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[2] = start[2];
	start[1] = end[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[2] = end[2];
	end[0] = start[0];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[2] = end[2];
	end[1] = start[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	start[0] = end[0];
	end[1] = start[1];
	drawLine(start, end);
	FVecIVec(mins, start);
	FVecIVec(maxs, end);
	end[0] = start[0];
	start[1] = end[1];
	drawLine(start, end);
}

drawLine(start[3], end[3]) {
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY); {
	write_byte(TE_BEAMPOINTS);
	write_coord(start[0]);
	write_coord(start[1]);
	write_coord(start[2]);
	write_coord(end[0]);
	write_coord(end[1]);
	write_coord(end[2]);
	write_short(g_iLaserSprite);
	write_byte(0);
	write_byte(0);
	write_byte(50);
	write_byte(25);
	write_byte(0);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	write_byte(0);
	} message_end();
}