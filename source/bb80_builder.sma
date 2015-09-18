#pragma dynamic 8192

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <cvar_util>
#include <xs>

#include "include/bb/bb_builder_const.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_game.inc"
#include "include/bb/bb_zones.inc"
#include "include/bb/bb_territories.inc"
#include "include/bb/bb_zombies.inc"
#include "include/bb/bb_colorchat.inc"
#include "include/bb/bb_commands.inc"
#include "include/bb/bb_colors.inc"

#define PLUGIN_VERSION "0.0.1"

#define FLAGS_OVERRIDE	ADMIN_RCON
#define FLAGS_BUILD		ADMIN_BAN
#define FLAGS_LOCK		ADMIN_SLAY

#define LOCK_MAX 16

static const BB_OBJECT[] = "bb_object";
static const BB_OBJECT_RAW[] = "bb_object_";
static const BB_ILLUSIONARY[] = "bb_illusionary";
static const BB_TERRITORY[] = "bb_territory";

static const Float:NULL_ORIGIN[] = { 0.0, 0.0, 0.0 };

static const Float:DEFAULT_COLOR[] = { 135.0, 206.0, 235.0 };
static const Float:DEFAULT_RENDERAMT = 150.0

static const Float:LOCKED_COLOR[] = { 125.0, 0.0, 0.0 };
static const Float:LOCKED_RENDERAMT = 225.0;

static const LOCK_OBJECT[] = "buttons/lightswitch2.wav";
static const LOCK_FAIL[] = "buttons/button10.wav";

static const GRAB_START[] = "bb/block_grab.wav";
static const GRAB_STOP[] = "bb/block_drop.wav";

static g_iBarrier;
static g_iHudSync;

static BB_COLOR:COLOR_TEXTURED;
static BB_COLOR:COLOR_RAINBOW;
static BB_COLOR:g_rainbowColor[MAX_PLAYERS+1];

static g_iResetEnt;
static g_iShowMovers;
static g_iFixedMovementUnits;
static g_iRotatableObject;
static g_iLockBlocks;
static Float:g_fBuildDelay;
static Float:g_fMaxEntDist;
static Float:g_fMinEntDist;
static Float:g_fMinEntDistSet;
static Float:g_fPushPullRate;

enum _:eMoveTypes (<<=1) {
	move_Unmovable = 0,
	move_Movable = 1,
	move_Rotatable,
	move_Flippable,
	move_Moving
}

static Float:g_fOrigin1[3];
static Float:g_fOrigin2[3];
static Float:g_fOrigin3[3];

enum _:player_t {
	Float:player_BuildDelay,
	Float:player_EntDist,
	Float:player_EntOffset[3],
	player_OwnedEnt,
	player_PSet
	//player_LockedNum,
	//player_LockedList[LOCK_MAX]
}

static g_playerFields[MAX_PLAYERS+1][player_t];

static g_flagHoldMode;
static g_flagFixedMoving;
static g_flagBuildBanned;
static g_flagAutoLock;

enum {
	reset_NoResetting = 0,
	reset_OnlyUnlocked,
	reset_All
}

enum {
	rotate_Rotatable = 1,
	rotate_Flippable
}

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Builder]", "Gives users the ability to move entities", PLUGIN_VERSION);
	
	precache_sound(LOCK_OBJECT);
	precache_sound(LOCK_FAIL);
	precache_sound(GRAB_START);
	precache_sound(GRAB_STOP);
}

public bb_fw_init_post() {
	bb_command_register("fixed", "fwCommandFixed", _, "Enables/Disables fixed object movements");
	bb_command_register("fixedmoving", "fwCommandFixed");
	
	bb_command_register("hold", "fwCommandHold", _, "Enables/Disables having to hold '+use' when moving an object");
	bb_command_register("holdmoving", "fwCommandHold");
}

public plugin_init() {
	register_forward(FM_CmdStart, "fwCmdStart");
	register_forward(FM_PlayerPreThink, "fwPlayerPreThink");
	register_forward(FM_TraceLine, "fwTraceline", 1);
	register_forward(FM_AddToFullPack, "fwAddToFullPack", 1);
	
	g_iResetEnt = CvarRegister("bb_build_resetEnts", "1", "0-no resetting, 1-reset all", _, true, 0.0, true, 1.0);
	CvarCache(g_iResetEnt, CvarType_Int, g_iResetEnt);
	
	g_iShowMovers = CvarRegister("bb_build_showMovers", "1", "1-show movers, 0-don't show movers", _, true, 0.0, true, 1.0);
	CvarCache(g_iShowMovers, CvarType_Int, g_iShowMovers);
	
	g_iLockBlocks = CvarRegister("bb_build_lockBlocks", "1-enable block locking, 0-disable block locking", "1", _, true, 0.0, true, 1.0);
	CvarCache(g_iLockBlocks, CvarType_Int, g_iLockBlocks);
	
	g_iFixedMovementUnits = CvarRegister("bb_build_fixedMovementUnits", "8", "Unit movement scale to fix to", _, true, 2.0, true, 32.0);
	CvarCache(g_iFixedMovementUnits, CvarType_Int, g_iFixedMovementUnits);	

	g_iRotatableObject = CvarRegister("bb_build_rotatableObject", "1", "2-rotate/flip, 1-rotate only, 0-no rotate/flip", _, true, 0.0, true, 2.0);
	CvarCache(g_iRotatableObject, CvarType_Int, g_iRotatableObject);
	
	new g_pCvar = CvarRegister("bb_build_buildDelay", "0.35", "Minimum time a player must wait before moving objects", _, true, 0.0, true, 5.0);
	CvarCache(g_pCvar, CvarType_Float, g_fBuildDelay);

	g_pCvar = CvarRegister("bb_build_maxEntDist", "1024.0", "Maximum distance you can push an entity", _, true, 256.0, true, 2048.0);
	CvarCache(g_pCvar, CvarType_Float, g_fMaxEntDist);
	
	g_pCvar = CvarRegister("bb_build_minEntDist", "32.0", "Minimum distance you can pull an entity", _, true, 16.0, true, 256.0);
	CvarCache(g_pCvar, CvarType_Float, g_fMinEntDist);
	
	g_pCvar = CvarRegister("bb_build_minEntDistSet", "64.0", "Sets block to this distance if grabbed to close", _, true, 16.0, true, 64.0);
	CvarCache(g_pCvar, CvarType_Float, g_fMinEntDistSet);

	g_pCvar = CvarRegister("bb_build_pushPullRate", "4.0", "How fast/slow an entity can be pushed or pulled", _, true, 1.0, true, 32.0);
	CvarCache(g_pCvar, CvarType_Float, g_fPushPullRate);
	
	g_iHudSync = CreateHudSyncObj();
	
	g_iBarrier = bb_game_getBarrier();
	if (g_iBarrier == null) {
		set_fail_state("Place [Builder] after [Game] in plugins.ini");
	}
	
	new ent = -1, size = entity_count();
	new szTarget[16], szClass[10];
	for (ent = get_maxplayers(); ent < size; ent++) {
		if (!is_valid_ent(ent)) {
			continue;
		}
		
		entity_get_string(ent, EV_SZ_classname, szClass, 9);
		if (!equal(szClass, "func_wall")) {
			continue;
		}
		
		entity_get_string(ent, EV_SZ_targetname, szTarget, 15);
		if (!equal(szTarget, BB_OBJECT_RAW, 10)) {
			SetMoveType(ent, move_Unmovable);
			continue;
		}
		
		SetMoveType(ent, read_flags(szTarget[10]));
		if (GetMoveType(ent) == move_Unmovable) {
			continue;
		}
		
		entity_set_string(ent, EV_SZ_classname, BB_OBJECT);
		
		entity_get_vector(ent, EV_VEC_mins, g_fOrigin1);
		EntSetMins(ent,g_fOrigin1);
		entity_get_vector(ent, EV_VEC_maxs, g_fOrigin2);
		EntSetMaxs(ent,g_fOrigin2);
		entity_get_vector(ent, EV_VEC_origin, g_fOrigin3);
		EntSetOffset(ent,g_fOrigin3);
		
		UnclaimBlock(ent);
		
		if (g_iRotatableObject == rotate_Flippable && GetMoveType(ent)&move_Flippable) {
			entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
			entity_set_size(ent, g_fOrigin1, g_fOrigin2);
		}
	}

	ent = -1;
	while ((ent = find_ent_by_tname(ent, BB_ILLUSIONARY)) != 0) {
		SetMoveType(ent, move_Unmovable);
		entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
	}
	
	COLOR_TEXTURED	= bb_color_registerColor("Textured",	Float:{000.0, 000.0, 000.0},	175.0,	ADMIN_BAN);
	COLOR_RAINBOW	= bb_color_registerColor("Rainbow",		Float:{000.0, 000.0, 000.0},	175.0,	ADMIN_BAN);
}

public plugin_natives() {
	register_library("BB_Builder");
	
	register_native("bb_build_resetEntities", "_resetEntities", 0);
	register_native("bb_build_resetEntity", "_resetEntity", 0);
	
	register_native("bb_build_forceUserDrop", "_forceUserDrop", 0);
}

public fwCommandFixed(id, player, message[]) {
	flagToggle(g_flagFixedMoving,id);
	bb_printColor(id, "You have just^x03 %sabled^x04 fixed^x01 moving", flagGet(g_flagFixedMoving,id) ? "en" : "dis");
}

public fwCommandHold(id, player, message[]) {
	flagToggle(g_flagHoldMode,id);
	bb_printColor(id, "You have just^x03 %sabled^x04 hold^x01 moving", flagGet(g_flagHoldMode,id) ? "en" : "dis");
}

public client_disconnect(id) {
	forceUserDrop(id);
	flagUnset(g_flagHoldMode,id);
	flagUnset(g_flagFixedMoving,id);
	flagUnset(g_flagBuildBanned,id);
	flagUnset(g_flagAutoLock,id);
	
	/*if (g_playerFields[id][player_LockedNum] == 0) {
		return;
	}
	
	new ent;
	g_playerFields[id][player_LockedNum] = 0;
	for (new i = 0; i < LOCK_MAX; i++) {
		ent = g_playerFields[id][player_LockedList][i];
		if (!ent) {
			continue;
		}
		
		entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
		UnlockBlock(ent);
	}*/
}

public bb_fw_zm_infect(id) {
	forceUserDrop(id);
}

public bb_fw_zm_playerDeath(killer, victim) {
	forceUserDrop(victim);
}

public bb_fw_game_newRound() {
	if (g_iResetEnt != reset_NoResetting) {
		resetEntities();
	}
}

//native bb_build_resetEntities(id);
public _resetEntities(plugin, params) {
	if (params != 0) {
		return;
	}
	
	resetEntities();
}

resetEntities() {
	/*if (g_iResetEnt != reset_OnlyUnlocked) {
		for (new i = 0; i <= MAX_PLAYERS; i++) {
			g_playerFields[i][player_LockedNum] = 0;
			arrayset(g_playerFields[i][player_LockedList], 0, LOCK_MAX);
		}
	}*/
	
	new ent = -1;
	while ((ent = find_ent_by_class(ent, BB_OBJECT)) != 0) {
		/*if (IsBlockLocked(ent) && g_iResetEnt == reset_OnlyUnlocked) {
			continue;
		}*/
		
		resetEntity(ent)
	}
}

public bb_fw_game_prepPhaseStart() {
	new ent = -1;
	while ((ent = find_ent_by_class(ent, BB_OBJECT)) != 0) {
		UnlockBlock(ent);
		entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
	}
}

public bb_fw_color_colorSelected(id, BB_COLOR:color) {
	/*if (g_playerFields[id][player_LockedNum] == 0) {
		return;
	}
	
	new ent, Float:renderamt;
	bb_color_getColor(color, g_fOrigin1, renderamt);
	for (new i = 0; i < LOCK_MAX; i++) {
		ent = g_playerFields[id][player_LockedList][i];
		if (!ent) {
			continue;
		}
		
		if (color == COLOR_TEXTURED) {
			entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture);
		} else if (color == COLOR_RAINBOW) {
			g_rainbowColor[id] = random(bb_color_getColorNum()-2);
			bb_color_getColor(g_rainbowColor[id], g_fOrigin1, renderamt);
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
		} else {
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
		}
		
		entity_set_float(ent, EV_FL_renderamt, LOCKED_RENDERAMT);
	}*/
}

attemptUserGrab(id) {
	if (g_playerFields[id][player_OwnedEnt]) {
		forceUserDrop(id);
		return;
	}
	
	if (bb_zm_isUserZombie(id) && !access(id, FLAGS_OVERRIDE)) {
		return;
	}
	
	if (bb_game_getGameState() != BB_GAMESTATE_BUILDPHASE && !access(id, FLAGS_BUILD)) {
		client_print(id, print_center, "%L", id, "BUILD_CANNOT");
		return;
	}
	
	if (flagGet(g_flagBuildBanned,id)) {
		client_print(id, print_center, "%L", id, "BUILD_BAN");
		bb_playSound(id, LOCK_FAIL);
		return;
	}

	new Float:fGameTime = get_gametime();
	if ((g_playerFields[id][player_BuildDelay]+g_fBuildDelay) > fGameTime) {
		client_print(id, print_center, "%L", id, "BUILD_WAIT", g_playerFields[id][player_BuildDelay]+g_fBuildDelay-fGameTime);
		return;
	} else {
		g_playerFields[id][player_BuildDelay] = _:fGameTime;
	}

	new ent, bodypart, Float:distance;
	distance = get_user_aiming(id, ent, bodypart, floatround(g_fMaxEntDist));
	if (!is_valid_ent(ent) || GetMoveType(ent) == move_Unmovable || IsMovingEnt(ent)) {
		return;
	}
	
	if (IsBlockLocked(ent)) {
		return;
	}
	
	if (!bb_ter_canMoveBlock(id, ent)) {
		client_print(id, print_center, "%L", id, "FAIL_TER_MOVE");
		return;
	}
	
	entity_get_vector(id, EV_VEC_origin, g_fOrigin2);
	get_aim_origin(id, g_fOrigin2, g_fOrigin3);
	entity_get_vector(ent, EV_VEC_origin, g_fOrigin1);
	
	for (new i = 0; i < 3; i++) {
		g_playerFields[id][player_EntOffset][i] = _:(g_fOrigin1[i]-g_fOrigin3[i]);
	}
	
	g_playerFields[id][player_EntDist] = _:distance;
	
	if (g_fMinEntDist > 0.0) {
		if (g_playerFields[id][player_EntDist] < g_fMinEntDist) {
			g_playerFields[id][player_EntDist] = _:g_fMinEntDistSet;
		}
	}

	new BB_COLOR:color = bb_color_getUserColor(id);
	if (color != BB_COLOR:null) {
		if (color == COLOR_TEXTURED) {
			bb_color_getColor(COLOR_TEXTURED, g_fOrigin1, distance);
			entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture);
		} else if (color == COLOR_RAINBOW) {
			g_rainbowColor[id] = random(bb_color_getColorNum()-2);
			bb_color_getColor(g_rainbowColor[id], g_fOrigin1, distance);
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
		} else {
			bb_color_getColor(color, g_fOrigin1, distance);
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
		}
		
		entity_set_float(ent, EV_FL_renderamt, distance);
	} else {
		entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
		entity_set_vector(ent, EV_VEC_rendercolor, DEFAULT_COLOR);
		entity_set_float(ent, EV_FL_renderamt, DEFAULT_RENDERAMT);
	}
	
	MovingEnt(ent);
	SetEntMover(ent, id);
	g_playerFields[id][player_OwnedEnt] = ent;
	bb_playSound(id, GRAB_START);
}

//native bool:bb_build_forceUserDrop(id);
public bool:_forceUserDrop(plugin, params) {
	if (params != 1) {
		return false;
	}
	
	return forceUserDrop(get_param(1));
}

bool:forceUserDrop(id) {
	new ent = g_playerFields[id][player_OwnedEnt];
	if (!ent) {
		return false;
	}

	if (IsBlockLocked(ent)) {
		new BB_COLOR:color = bb_color_getUserColor(id);
		if (color != BB_COLOR:null) {
			if (color == COLOR_TEXTURED) {
				new Float:renderamt;
				bb_color_getColor(color, g_fOrigin1, renderamt);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture);
			} else if (color == COLOR_RAINBOW) {
				bb_color_getColor(g_rainbowColor[id], g_fOrigin1);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
				entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
			} else {
				bb_color_getColor(color, g_fOrigin1);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
				entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
			}
		} else {
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, LOCKED_COLOR);
		}
		
		entity_set_float(ent, EV_FL_renderamt, LOCKED_RENDERAMT);
	} else {
		entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
	}
	
	UnmovingEnt(ent);
	UnsetEntMover(ent);
	SetLastMover(ent,id);
	g_playerFields[id][player_OwnedEnt] = 0;
	bb_playSound(id, GRAB_STOP);
	
	
	if (!engfunc(EngFunc_CheckVisibility, ent, g_playerFields[id][player_PSet])) {
		client_print(id, print_center, "%L", id, "FAIL_BUILD_IN_MAP");
		bb_ter_unclaimBlock(ent);
		resetEntity(ent);
		return true;
	}
	
	new zoneEnt = bb_zone_isWithinZone(ent);
	new BB_ZONE_TYPE:zoneType = bb_zone_getZoneType(zoneEnt);
	if (zoneType != BB_ZONE_INVALID) {
		if (zoneType == BB_ZONE_BUILDER_SPAWN || zoneType == BB_ZONE_ZOMBIE_SPAWN) {
			client_print(id, print_center, "%L", id, "FAIL_SPAWN_BUILD");
			bb_ter_unclaimBlock(ent);
			resetEntity(ent);
		} else if (zoneType == BB_ZONE_TERRITORY) {
			if (bb_ter_belongsToTerritory(id, zoneEnt)) {
				if (GetBlockClaimer(ent) == null) {
					bb_ter_claimBlock(zoneEnt, ent);
				}
			} else if (bb_ter_isClaimed(zoneEnt)) {
				client_print(id, print_center, "%L", id, "FAIL_TER_BUILD");
				resetEntity(ent);
			}
		}
	} else if (GetBlockClaimer(ent) != null) {
		bb_ter_unclaimBlock(ent);
	}
	
	return true;
}

//native bool:bb_build_resetEntity(ent);
public bool:_resetEntity(plugin, params) {
	if (params != 1) {
		return false;
	}
	
	return resetEntity(get_param(1));
}

bool:resetEntity(ent) {
	UnmovingEnt(ent);
	UnlockBlock(ent);
	UnsetEntMover(ent);
	UnsetLastMover(ent);
	bb_ter_unclaimBlock(ent);
	
	entity_set_vector(ent, EV_VEC_angles, NULL_ORIGIN);
	entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
	
	EntGetMins(ent,g_fOrigin1);
	EntGetMaxs(ent,g_fOrigin2);
	entity_set_size(ent, g_fOrigin1, g_fOrigin2);
	EntGetOffset(ent,g_fOrigin1);
	entity_set_origin(ent, g_fOrigin1);
	return true;
}

public attemptUserLock(id) {
	if (bb_zm_isUserZombie(id)) {
		return PLUGIN_HANDLED;
	}
	
	new BB_GAMESTATE:gameState = bb_game_getGameState();
	if (gameState != BB_GAMESTATE_BUILDPHASE) {
		if (gameState == BB_GAMESTATE_PREPPHASE) {
			client_print(id, print_center, "%L", id, "FAIL_LOCK");
		}
		
		return PLUGIN_HANDLED;
	}
	
	new ent, body;
	get_user_aiming(id, ent, body, floatround(g_fMaxEntDist));
	if (GetMoveType(ent) == move_Unmovable || IsMovingEnt(ent)) {
		return PLUGIN_HANDLED;
	}
	
	if (GetBlockClaimer(ent) == null || GetBlockClaimer(ent) != bb_ter_getUserTerritory(id)) {
		client_print(id, print_center, "%L", id, "FAIL_LOCK_NOT_OWNED");
		return PLUGIN_HANDLED;
	}
	
	if (IsBlockLocked(ent)) {
		entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
		bb_playSound(id, LOCK_OBJECT);
		UnlockBlock(ent);
	} else {
		new BB_COLOR:color = bb_color_getUserColor(id);
		if (color != BB_COLOR:null) {
			if (color == COLOR_TEXTURED) {
				new Float:renderamt;
				bb_color_getColor(color, g_fOrigin1, renderamt);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture);
			} else if (color == COLOR_RAINBOW) {
				bb_color_getColor(g_rainbowColor[id], g_fOrigin1);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
				entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
			} else {
				bb_color_getColor(color, g_fOrigin1);
				entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
				entity_set_vector(ent, EV_VEC_rendercolor, g_fOrigin1);
			}
		} else {
			entity_set_int(ent, EV_INT_rendermode, kRenderTransColor);
			entity_set_vector(ent, EV_VEC_rendercolor, LOCKED_COLOR);
		}

		entity_set_float(ent, EV_FL_renderamt, LOCKED_RENDERAMT);
		bb_playSound(id, LOCK_OBJECT);
		LockBlock(ent);
	}
	
	return PLUGIN_HANDLED;
}

public fwCmdStart(id, uc_handle, randseed) {
	if (!is_user_alive(id)) {
		return FMRES_IGNORED;
	}

	new button = get_uc(uc_handle , UC_Buttons);
	new oldbutton = pev(id, pev_oldbuttons);
	if ((button&IN_USE) && !(oldbutton&IN_USE)) {
		if (flagGet(g_flagHoldMode,id)) {
			attemptUserGrab(id);
		} else if (!g_playerFields[id][player_OwnedEnt]) {
			attemptUserGrab(id);
		}
	} else if ((oldbutton&IN_USE) && !(button&IN_USE) && g_playerFields[id][player_OwnedEnt] && !flagGet(g_flagHoldMode,id)) {
		forceUserDrop(id);
	} else if (g_iLockBlocks && !g_playerFields[id][player_OwnedEnt] && (button&IN_RELOAD) && !(oldbutton&IN_RELOAD)) {
		attemptUserLock(id);
	}

	return FMRES_IGNORED;
}

public fwPlayerPreThink(id) {
	static ent;
	ent = g_playerFields[id][player_OwnedEnt];
	if (!ent) {
		return FMRES_IGNORED;
	}

	static buttons, oldbutton;
	buttons = pev(id, pev_button);
	oldbutton = pev(id, pev_oldbuttons);
	if (buttons&IN_ATTACK) {
		g_playerFields[id][player_EntDist] += g_fPushPullRate;
		if (g_playerFields[id][player_EntDist] > g_fMaxEntDist) {
			g_playerFields[id][player_EntDist] = _:g_fMaxEntDist;
			client_print(id, print_center, "%L", id, "ENT_MAX_DIST");
		} else {
			client_print(id, print_center, "%L", id, "ENT_PUSHING");
		}
	} else if (buttons&IN_ATTACK2) {
		g_playerFields[id][player_EntDist] -= g_fPushPullRate;
		if (g_playerFields[id][player_EntDist] < g_fMinEntDist) {
			g_playerFields[id][player_EntDist] = _:g_fMinEntDist;
			client_print(id, print_center, "%L", id, "ENT_MIN_DIST");
		} else {
			client_print(id, print_center, "%L", id, "ENT_PULLING");
		}
	} else if (g_iRotatableObject && (buttons&IN_RELOAD) && !(oldbutton&IN_RELOAD) && (GetMoveType(ent)&move_Rotatable)) {
		entity_get_vector(ent, EV_VEC_angles, g_fOrigin1);
		g_fOrigin1[1] += 90.0;
		entity_set_vector(ent, EV_VEC_angles, g_fOrigin1);

		if (g_iRotatableObject == rotate_Flippable) {
			entity_get_vector(ent, EV_VEC_mins, g_fOrigin2);
			entity_get_vector(ent, EV_VEC_maxs, g_fOrigin3);
			swap(g_fOrigin2, 0, 1);
			swap(g_fOrigin3, 0, 1);
			entity_set_size(ent, g_fOrigin2, g_fOrigin3);
		}
	} else if (g_iRotatableObject == rotate_Flippable && (buttons&IN_SCORE) && !(oldbutton&IN_SCORE) && (GetMoveType(ent)&move_Flippable)) {
		entity_get_vector(ent, EV_VEC_angles, g_fOrigin1);
		g_fOrigin1[2] += 90.0;
		entity_set_vector(ent, EV_VEC_angles, g_fOrigin1);
		
		entity_get_vector(ent, EV_VEC_mins, g_fOrigin2);
		entity_get_vector(ent, EV_VEC_maxs, g_fOrigin3);
		if (floatround(g_fOrigin1[1])%180 == 0) {
			swap(g_fOrigin2, 1, 2);
			swap(g_fOrigin3, 1, 2);
		} else {
			swap(g_fOrigin2, 0, 2);
			swap(g_fOrigin3, 0, 2);
		}
		
		entity_set_size(ent, g_fOrigin2, g_fOrigin3);
	}
	
	entity_get_vector(id, EV_VEC_origin, g_fOrigin1);
	get_aim_origin(id, g_fOrigin1, g_fOrigin2);
	
	static Float:fLength;
	fLength = get_distance_f(g_fOrigin2, g_fOrigin1);
	if (fLength == 0.0) {
		fLength = 1.0;
	}

	g_fOrigin3[0] = (g_fOrigin1[0] + (g_fOrigin2[0] - g_fOrigin1[0]) * g_playerFields[id][player_EntDist] / fLength) + g_playerFields[id][player_EntOffset][0];
	g_fOrigin3[1] = (g_fOrigin1[1] + (g_fOrigin2[1] - g_fOrigin1[1]) * g_playerFields[id][player_EntDist] / fLength) + g_playerFields[id][player_EntOffset][1];
	g_fOrigin3[2] = (g_fOrigin1[2] + (g_fOrigin2[2] - g_fOrigin1[2]) * g_playerFields[id][player_EntDist] / fLength) + g_playerFields[id][player_EntOffset][2];

	if (flagGet(g_flagFixedMoving,id)) {
		g_fOrigin3[0] = g_fOrigin3[0] - float(floatround(g_fOrigin3[0], floatround_floor) % g_iFixedMovementUnits);
		g_fOrigin3[1] = g_fOrigin3[1] - float(floatround(g_fOrigin3[1], floatround_floor) % g_iFixedMovementUnits);
		g_fOrigin3[2] = g_fOrigin3[2] - float(floatround(g_fOrigin3[2], floatround_floor) % g_iFixedMovementUnits);
	}
	
	entity_set_origin(ent, g_fOrigin3);
	return FMRES_IGNORED;
}

stock get_aim_origin(id, Float:start[3], Float:origin[3]) {
	static Float:view_ofs[3], Float:dest[3];
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

swap(Float:array[], id1, id2) {
	static Float:temp;
	temp = array[id1];
	array[id1] = array[id2];
	array[id2] = temp;
}

public fwTraceline(Float:start[3], Float:end[3], conditions, id, trace) {
	if (bb_game_getGameState() != BB_GAMESTATE_BUILDPHASE && !access(id, ADMIN_SLAY)) {
		return FMRES_IGNORED;
	}
	
	static ent, curMover, lastMover, szCurMover[32], szLastMover[32];
	ent = get_tr2(trace, TR_pHit);
	if (!is_valid_ent(ent)) {
		ClearSyncHud(id, g_iHudSync);
		return FMRES_IGNORED;
	}
	
	static szFormattedHud[128], len;
	len = 0;
	if (GetMoveType(ent) && ent != g_iBarrier && g_iShowMovers) {
		set_hudmessage(0, 50, 255, -1.0, 0.60, 1, 0.01, 3.0, 0.01, 0.01);
		curMover = GetEntMover(ent);
		lastMover = GetLastMover(ent);
		if (GetBlockClaimer(ent) != null) {
			len += formatex(szFormattedHud[len], 128-len, "%L", id, "HUD_CLAIMED");
		}	

		if (IsBlockLocked(ent)) {
			len += formatex(szFormattedHud[len], 128-len, " & %L", id, "HUD_LOCKER");
		}
		
		len += formatex(szFormattedHud[len], 128-len, "^n");
		
		if (curMover && lastMover) {
			get_user_name(curMover, szCurMover, 31);
			get_user_name(lastMover, szLastMover, 31);
			len += formatex(szFormattedHud[len], 128-len, "%L: %s^n%L: %s", id, "HUD_CURRENT", szCurMover, id, "HUD_LAST", szLastMover);
		} else if (curMover) {
			get_user_name(curMover, szCurMover, 31);
			len += formatex(szFormattedHud[len], 128-len, "%L: %s^n%L: %L", id, "HUD_CURRENT", szCurMover, id, "HUD_LAST", id, "HUD_NONE");
		} else if (lastMover) {
			get_user_name(lastMover, szLastMover, 31);
			len += formatex(szFormattedHud[len], 128-len, "%L: %L^n%L: %s", id, "HUD_CURRENT", id, "HUD_NONE", id, "HUD_LAST", szLastMover);
		} else {
			len += formatex(szFormattedHud[len], 128-len, "%L", id, "HUD_NOMOVER");
		}
		
		ShowSyncHudMsg(id, g_iHudSync, szFormattedHud);
	} else {
		ClearSyncHud(id, g_iHudSync);
	}
	
	return FMRES_IGNORED;
}

public fwAddToFullPack(es, e, ent, host, flags, player, set) {
	g_playerFields[host][player_PSet] = set;
	return FMRES_IGNORED;
}