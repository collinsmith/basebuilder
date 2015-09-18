#pragma dynamic 8192

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cvar_util>
#include <xs>

#include "include/fm_item_stocks.inc"
#include "include/bb/bb_game_const.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_zombies.inc"
#include "include/bb/bb_builder.inc"
#include "include/bb/bb_colorchat.inc"
#include "include/bb/bb_commands.inc"
#include "include/bb/bb_colors.inc"
#include "include/bb/bb_classes.inc"
#include "include/bb/bb_territories.inc"

static const BB_BARRIER[] = "bb_barrier";
static const BB_CLOCK[] = "bb_clock";
static const BB_CLOCK_DIGIT[] = "bb_clockdigit";
static const INFO_TARGET[] = "info_target";

#define FLAGS_SWAP		ADMIN_SLAY
#define FLAGS_REVIVE	ADMIN_SLAY
#define FLAGS_CLOCK		ADMIN_CVAR

#define HUD_FRIEND_HEIGHT 0.35

#if cellbits == 32
	#define OFFSET_BUYZONE 235
#else
	#define OFFSET_BUYZONE 268
#endif

static const Float:BARRIER_COLOR[] = { 0.0, 0.0, 0.0 };
static const Float:BARRIER_RENDERAMT = 150.0

static const Float:DIGIT_OFFS_MULTIPLIER[4] = {0.725, 0.275, 0.3, 0.75};
static const Float:CLOCK_SIZE[2] = {80.0, 32.0};
static const Float:TITLE_SIZE = 16.0;

static const CLOCK_FACE[] = "sprites/bb/clock_face.spr";
static const CLOCK_DIGIT[] = "sprites/bb/clock_digit.spr";

static const WIN_ZOMBIES[] = "bb/win_zombies2.wav";
static const WIN_BUILDERS[] = "bb/win_builders2.wav";

static const PHASE_PREP[] = "bb/phase_prep.wav";
static const PHASE_BUILD[] = "bb/phase_build.wav";

static const PHASE_RELEASE[][] = {
	"bb/round_start1.wav",
	"bb/round_start2.wav"
}

enum (+= 5039) {
	task_HudHealth = 514229,
	task_RespawnUser
}

static BB_GAMESTATE:g_gameState = BB_GAMESTATE_INVALID;

static g_iBarrier = null;
static g_iHudSync1;
static g_iHudSync2;

static g_iInstaKill;
static Float:g_fRespawnDelay;
static g_iBuildTime;
static g_iPrepTime;
static g_iCountDownSecs;
static g_iCountDownTenth;
static g_iCountingEnt;

enum _:eForwardedEvents {
	fwReturn,
	fwNewRound,
	fwRoundStart,
	fwRoundEnd,
	fwBuildPhaseStart,
	fwPrepPhaseStart,
	fwZombiesReleased
};

static g_fw[eForwardedEvents];

static g_flagFriend;
static g_flagZombie;

static const g_szWpnEntNames[][] = {
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};

static g_Menu_Clocks;
static g_Menu_SecWeapon;
static g_Menu_PrimWeapon;

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Game]", "Manages the gameplay of Base Builder", BB_PLUGIN_VERSION);
	
	precache_model(CLOCK_FACE);
	precache_model(CLOCK_DIGIT);
	
	precache_sound(WIN_ZOMBIES);
	precache_sound(WIN_BUILDERS);
	precache_sound(PHASE_BUILD);
	precache_sound(PHASE_PREP);
	
	for (new i = 0; i < sizeof PHASE_RELEASE; i++) {
		precache_sound(PHASE_RELEASE[i]);
	}
	
	loadClocks();
}

public bb_fw_init_post() {
	new ent = create_entity("info_bomb_target");
	entity_set_origin(ent, Float:{8192.0,8192.0,8192.0})
	
	ent = create_entity("info_map_parameters");
	DispatchKeyValue(ent, "buying", "3");
	DispatchKeyValue(ent, "bombradius", "1");
	DispatchSpawn(ent);
	
	server_cmd("mp_maxrounds 4");
	
	bb_command_register("respawn", "fwCommandRespawn", "abcdef", "Respawns you if possible");
	bb_command_register("fixspawn", "fwCommandRespawn");
	
	bb_command_register("pause", "fwCommandPause", "abcdef", "Pauses the countdown timer", ADMIN_CVAR);
	
	bb_command_register("swap", "fwCommandSwap", "abcdef", "Swaps a user's team", FLAGS_SWAP);
	bb_command_register("revive", "fwCommandRevive", "abcdef", "Revives a user", FLAGS_REVIVE);
	bb_command_register("clocks", "fwCommandClocks", "abcde", "Opens the clock menu", FLAGS_CLOCK);
}

public fwCommandRespawn(id, player, message[]) {
	if (g_gameState == BB_GAMESTATE_BUILDPHASE && !flagGet(g_flagZombie,id)) {
		bb_zm_respawnUser(id, true);
	} else if (flagGet(g_flagZombie,id)) {
		if (pev(id, pev_health) == bb_class_getClassHealth(bb_class_getUserClass(id)) || !is_user_alive(id)) {
			bb_zm_respawnUser(id, true);
		} else {
			bb_printColor(id, "%L", id, "FAIL_SPAWN");
		}
	}
}

static bool:g_paused = false;

public fwCommandPause(id, player, message[]) {
	if (g_gameState != BB_GAMESTATE_BUILDPHASE && g_gameState != BB_GAMESTATE_PREPPHASE) {
		return;
	}
	
	g_paused = !g_paused;
	bb_printColor(id, "You've paused/unpaused to timer");
}

public fwCommandSwap(id, player, message[]) {
	if (!player) {
		bb_printColor(id, "%L", id, "FAIL_TARGET", message);
		return;
	}
	
	if (flagGet(g_flagZombie,player)) {
		bb_zm_cureUser(player, -1, false);
	} else {
		bb_zm_infectUser(player, -1, false);
	}
	
	bb_zm_respawnUser(player, true);
	
	set_hudmessage(246, 100, 175, -1.0, 0.35, 0, 0.0, 10.0, 0.0, 0.0);
	ShowSyncHudMsg(player, g_iHudSync1, "%L", player, "PLAYER_SWAP");
	
	new szPlayerName[32];
	get_user_name(player, szPlayerName, 31);
	bb_printColor(0, "%L", LANG_PLAYER, "ADMIN_SWAP", szPlayerName, flagGet(g_flagZombie,player) ? "zombie" : "builder");
}

public fwCommandRevive(id, player, message[]) {
	if (!player) {
		bb_printColor(id, "%L", id, "FAIL_TARGET", message);
		return;
	}
	
	bb_zm_respawnUser(player, true);
	
	set_hudmessage(246, 100, 175, -1.0, 0.35, 0, 0.0, 10.0, 0.0, 0.0);
	ShowSyncHudMsg(player, g_iHudSync1, "%L", player, "PLAYER_REVIVE");
	
	new szPlayerName[32];
	get_user_name(player, szPlayerName, 31);
	bb_printColor(0, "%L", LANG_PLAYER, "ADMIN_REVIVE", szPlayerName);
}

public fwCommandClocks(id, player, message) {
	showClockMenu(id);
}

public plugin_init() {
	register_event("HLTV", "eventRoundStart", "a", "1=0", "2=0");
	register_logevent("logeventRoundStart", 2, "1=Round_Start");
	register_logevent("logeventRoundEnd", 2, "1=Round_End");
	
	register_message(get_user_msgid("TextMsg"), "msgRoundEnd");
	register_message(get_user_msgid("StatusIcon"), "msgStatusIcon");
	register_message(get_user_msgid("Health"), "msgHealth");
	
	register_event("StatusValue", "ev_SetTeam", "be", "1=1");
	register_event("StatusValue", "ev_ShowStatus", "be", "1=2", "2!0");
	register_event("StatusValue", "ev_HideStatus", "be", "1=1", "2=0");
	register_event("Health", "ev_Health", "be", "1>0");
	register_event("AmmoX", "ev_AmmoX", "be", "1=1", "1=2", "1=3", "1=4", "1=5", "1=6", "1=7", "1=8", "1=9", "1=10");
	
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage");
	
	register_forward(FM_ClientKill, "fwSuicide");
	
	g_Menu_Clocks = menu_create("Base Builder Clocks", "clockMenuHandler");
	menu_additem(g_Menu_Clocks, "Create Build Time Clock");
	menu_additem(g_Menu_Clocks, "Delete Clock");
	menu_additem(g_Menu_Clocks, "Make Clock Larger");
	menu_additem(g_Menu_Clocks, "Make Clock Smaller");
	menu_additem(g_Menu_Clocks, "Save Clocks");
	
	new szTemp[32];
	g_Menu_SecWeapon = menu_create("Choose a Secondary Weapon:", "weaponMenuHandler");
	menu_setprop(g_Menu_SecWeapon, MPROP_EXIT, MEXIT_NEVER);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_P228]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_P228]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_USP]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_USP]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_GLOCK18]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_GLOCK18]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_DEAGLE]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_DEAGLE]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_FIVESEVEN]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_FIVESEVEN]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_ELITE]);
	menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_ELITE]);
	
	g_Menu_PrimWeapon = menu_create("Choose a Primary Weapon:", "weaponMenuHandler");
	menu_setprop(g_Menu_PrimWeapon, MPROP_EXIT, MEXIT_NEVER);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SCOUT]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SCOUT]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_XM1014]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_XM1014]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_MAC10]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_MAC10]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AUG]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AUG]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_UMP45]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_UMP45]);
	//formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SG550]);
	//menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SG550]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_GALIL]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_GALIL]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_FAMAS]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_FAMAS]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AWP]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AWP]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_MP5NAVY]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_MP5NAVY]);
	//formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M249]);
	//menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M249]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M3]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M3]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M4A1]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M4A1]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_TMP]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_TMP]);
	//formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_G3SG1]);
	//menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_G3SG1]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SG552]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SG552]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AK47]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AK47]);
	formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_P90]);
	menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_P90]);
	
	g_fw[fwNewRound] = CreateMultiForward("bb_fw_game_newRound", ET_IGNORE);
	g_fw[fwRoundStart] = CreateMultiForward("bb_fw_game_roundStart", ET_IGNORE);
	g_fw[fwRoundEnd] = CreateMultiForward("bb_fw_game_roundEnd", ET_IGNORE);
	
	g_fw[fwBuildPhaseStart] = CreateMultiForward("bb_fw_game_buildPhaseStart", ET_IGNORE);
	g_fw[fwPrepPhaseStart] = CreateMultiForward("bb_fw_game_prepPhaseStart", ET_IGNORE);
	g_fw[fwZombiesReleased] = CreateMultiForward("bb_fw_game_zombiesReleased", ET_IGNORE);
	
	g_iBuildTime = CvarRegister("bb_game_buildTime", "150", "The amount of time humans are given to build", _, true, 30.0, true, 600.0);
	CvarCache(g_iBuildTime, CvarType_Int, g_iBuildTime);
	
	g_iPrepTime = CvarRegister("bb_game_prepTime", "40", "The amount of time humans are given return to their bases and test them", _, true, 20.0, true, 60.0);
	CvarCache(g_iPrepTime, CvarType_Int, g_iPrepTime);
	
	g_iInstaKill = CvarRegister("bb_game_instantKill", "0", "Enable/Disable zombie instant kill on humans", _, true, 0.0, true, 1.0);
	CvarCache(g_iInstaKill, CvarType_Int, g_iInstaKill);
	
	new pCvar = CvarRegister("bb_game_respawnDelay", "5.0", "Time for dead zombie to be respawned", _, true, 0.1, true, 10.0);
	CvarCache(pCvar, CvarType_Float, g_fRespawnDelay);
	
	g_iHudSync1 = CreateHudSyncObj();
	g_iHudSync2 = CreateHudSyncObj();
	
	g_iBarrier = find_ent_by_tname(-1, BB_BARRIER);
	if (g_iBarrier == 0) {
		set_fail_state("Barrier entity could not be located");
	}
	
	entity_set_string(g_iBarrier, EV_SZ_classname, BB_BARRIER);
	
	g_iCountingEnt = create_entity("info_target");
	entity_set_string(g_iCountingEnt, EV_SZ_classname, "bb_counter");
	register_think("bb_counter", "countDown");
	
	set_pev(g_iBarrier, pev_rendermode, kRenderTransColor);
	set_pev(g_iBarrier, pev_rendercolor, BARRIER_COLOR);
	set_pev(g_iBarrier, pev_renderamt, BARRIER_RENDERAMT);
	
	register_dictionary("basebuilder.txt");
}

public ev_Health(taskid) {
	if (taskid > task_HudHealth) {
		taskid -= task_HudHealth;
	}
	
	if (!is_user_alive(taskid)) {
		return;
	}
	
	set_hudmessage(255, 255, 255, -1.0, 0.9, 0, 0.0, 5.0, 0.0, 0.0, 4);
	if (flagGet(g_flagZombie,taskid)) {
		show_hudmessage(taskid, "%L: %d", taskid, "HUD_HEALTH", floatround(entity_get_float(taskid, EV_FL_health)));
	} else {
		static szPartners[128];
		szPartners[0] = '^0';
		bb_ter_formatPartnerNames(taskid, szPartners, 127);
		show_hudmessage(taskid, "%L: %d^n%L: %s", taskid, "HUD_HEALTH",
				floatround(entity_get_float(taskid, EV_FL_health)), taskid,
				"BUILD_PARTERS", szPartners[0] == '^0' ? "NONE" : szPartners);
		
	}
	
	set_task(4.9, "ev_Health", taskid+task_HudHealth);
}

public msgHealth(msgid, dest, id) {
	if(!is_user_alive(id)) {
		return PLUGIN_CONTINUE;
	}
	
	static hp;
	hp = get_msg_arg_int(1);
	if(hp > 255 && (hp % 256) == 0) {
		set_msg_arg_int(1, ARG_BYTE, ++hp);
	}
	
	return PLUGIN_CONTINUE;
}

public ev_AmmoX(id) {
	set_pdata_int(id, 376 + read_data(1), 200, 5);
}

public weaponMenuHandler(id, menu, item) {
	if (item == MENU_EXIT || bb_zm_isUserZombie(id)) {
		return PLUGIN_HANDLED;
	}
	
	static szWeapon[32], trash;
	menu_item_getinfo(menu, item, trash, szWeapon, 31, _, _, trash);
	fm_give_item(id, szWeapon);
	
	if (menu == g_Menu_SecWeapon) {
		menu_display(id, g_Menu_PrimWeapon);
	}
	
	return PLUGIN_HANDLED;
}

public plugin_natives() {
	register_library("BB_Game");
	
	register_native("bb_game_getBarrier", "_getBarrier", 0);
	register_native("bb_game_getGameState", "_getGameState", 0);
}

public bb_fw_zm_refresh(id, bool:isZombie) {
	ev_Health(id+task_HudHealth);
	
	if (isZombie) {
		fm_strip_user_weapons(id);
		fm_give_item(id, g_szWpnEntNames[CSW_KNIFE]);
	} else if (g_gameState == BB_GAMESTATE_BUILDPHASE || g_gameState == BB_GAMESTATE_ROUNDEND || g_gameState == BB_GAMESTATE_INVALID) {
		fm_strip_user_weapons(id);
	}
}

public bb_fw_zm_infect(id, infector) {
	flagSet(g_flagZombie,id);
}

public bb_fw_zm_cure(id, curer) {
	flagUnset(g_flagZombie,id);
}

public client_disconnect(id) {
	flagUnset(g_flagZombie,id);
	remove_task(id+task_HudHealth);
	remove_task(id+task_RespawnUser);
}

public bb_fw_zm_playerDeath(killer, victim) {
	if (!flagGet(g_flagZombie,victim)) {
		bb_zm_infectUser(victim, killer, true);
	}
	
	set_task(g_fRespawnDelay, "respawnUser", victim+task_RespawnUser);
	set_hudmessage(246, 100, 175, -1.0, 0.35, 0, 0.0, 10.0, 0.0, 0.0);
	ShowSyncHudMsg(victim, g_iHudSync1, "You will respawn in %.1f seconds", g_fRespawnDelay);
}

public respawnUser(taskid) {
	taskid -= task_RespawnUser;
	bb_zm_respawnUser(taskid, true);
}

public eventRoundStart() {
	g_iCountDownSecs = 0;
	g_iCountDownTenth = 0;
	g_gameState = BB_GAMESTATE_ROUNDEND;
	
	set_pev(g_iBarrier, pev_solid, SOLID_BSP);
	set_pev(g_iBarrier, pev_renderamt, BARRIER_RENDERAMT);
	
	ExecuteForward(g_fw[fwNewRound], g_fw[fwReturn]);
}

static bool:g_firstRound = true;

public logeventRoundStart() {
	set_pev(g_iBarrier, pev_solid, SOLID_BSP);
	set_pev(g_iBarrier, pev_renderamt, BARRIER_RENDERAMT);
	g_gameState = BB_GAMESTATE_BUILDPHASE;
	
	bb_printColor(0, "%L", LANG_PLAYER, "START_MESSAGE", BB_PLUGIN_NAME, BB_PLUGIN_VERSION);
	bb_printColor(0, "%L", LANG_PLAYER, "ROUND_MESSAGE");
	bb_printColor(0, "%L", LANG_PLAYER, "ROUND_MESSAGE2");
	
	if (!g_firstRound) {
		bb_playSound(0, PHASE_BUILD);
	}
	
	g_firstRound = false;
	
	g_iCountDownTenth = 0;
	g_iCountDownSecs = g_iBuildTime;
	entity_set_float(g_iCountingEnt, EV_FL_nextthink, halflife_time() + 0.105);
	
	ExecuteForward(g_fw[fwBuildPhaseStart], g_fw[fwReturn]);
	ExecuteForward(g_fw[fwRoundStart], g_fw[fwReturn]);
}

public countDown(ent) {
	if (g_paused) {
		entity_set_float(ent, EV_FL_nextthink, halflife_time() + 1.0);
		return PLUGIN_CONTINUE;
	}
	
	g_iCountDownTenth--;
	if (g_iCountDownTenth < 0) {
		g_iCountDownTenth = 9;
		g_iCountDownSecs--;
	}
	
	static mins, secs;
	mins = g_iCountDownSecs/60;
	secs = g_iCountDownSecs%60;
	if (g_iCountDownSecs >= 0) {
		new timeleftDigits[4], clock = -1;
		getTimeDigits(mins, secs, timeleftDigits);
		while ((clock = find_ent_by_class(clock, BB_CLOCK))) {
			setClockDigits(clock, timeleftDigits);
		}
		
		set_hudmessage(0, 200, 200, -1.0, 0.4, 0, 0.0, 0.5, 0.0, 0.0);
		switch (g_gameState) {
			case BB_GAMESTATE_BUILDPHASE:	ShowSyncHudMsg(0, g_iHudSync1, "%L - %d:%s%d.%d", LANG_PLAYER, "BUILD_TIMER", mins, (secs < 10 ? "0" : ""), secs, g_iCountDownTenth);
			case BB_GAMESTATE_PREPPHASE:	ShowSyncHudMsg(0, g_iHudSync1, "%L - %d:%s%d.%d", LANG_PLAYER, "PREP_TIMER", mins, (secs < 10 ? "0" : ""), secs, g_iCountDownTenth);
		}
	} else if (g_gameState == BB_GAMESTATE_BUILDPHASE && g_iPrepTime) {
			new players[32], num, player;
			get_players(players, num, "ae", "CT");
			for (new i = 0; i < num; i++) {
				player = players[i];
				bb_zm_respawnUser(player, true);
				bb_build_forceUserDrop(player);
				
				fm_give_item(player, g_szWpnEntNames[CSW_KNIFE]);
				menu_display(player, g_Menu_SecWeapon);	
			}
			
			set_hudmessage(255, 255, 255, -1.0, 0.40, 0, 1.0, 10.0, 0.1, 0.2);
			ShowSyncHudMsg(0, g_iHudSync1, "%L", LANG_PLAYER, "PREP_ANNOUNCE");
			bb_printColor(0, "%L", LANG_PLAYER, "PREP_ANNOUNCE2");
			bb_playSound(0, PHASE_PREP);
			
			g_gameState = BB_GAMESTATE_PREPPHASE;
			g_iCountDownSecs = g_iPrepTime;
			entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.105);

			new timeleftDigits[4], clock = -1;
			getTimeDigits(0, 0, timeleftDigits);
			while ((clock = find_ent_by_class(clock, BB_CLOCK))) {
				setClockDigits(clock, timeleftDigits);
			}
			
			ExecuteForward(g_fw[fwPrepPhaseStart], g_fw[fwReturn]);
	} else if (g_gameState == BB_GAMESTATE_BUILDPHASE || g_gameState == BB_GAMESTATE_PREPPHASE) {
		releaseZombies();
		new timeleftDigits[4], clock = -1;
		getTimeDigits(0, 0, timeleftDigits);
		while ((clock = find_ent_by_class(clock, BB_CLOCK))) {
			setClockDigits(clock, timeleftDigits);
		}
		
		return PLUGIN_HANDLED;
	}
	
	if (g_iCountDownTenth == 9) {
		if (mins && !secs) {
			new szTimer[32];
			num_to_word(mins, szTimer, 31);
			client_cmd(0, "spk ^"fvox/%s minutes remaining^"", szTimer);
		} else if (!mins && secs == 30) {
			new szTimer[32];
			num_to_word(secs, szTimer, 31);
			client_cmd(0, "spk ^"fvox/%s seconds remaining^"", szTimer);
		} else if (!mins && secs < 11) {
			new szTimer[32];
			num_to_word(secs, szTimer, 31);
			client_cmd(0, "spk ^"fvox/%s^"", szTimer);
		}
	}
	
	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.105);
	return PLUGIN_CONTINUE;
}

public logeventRoundEnd() {
	g_iCountDownSecs = 0;
	g_iCountDownTenth = 0;
	
	if (g_gameState == BB_GAMESTATE_ROUNDEND) {
		g_gameState = BB_GAMESTATE_INVALID;
		new players[32], num, player;
		get_players(players, num);
		for (new i = 0; i < num; i++) {
			player = players[i];
			bb_zm_fixInfection(player);
		}
		
		bb_printColor(0, "%L", LANG_PLAYER, "SWAP_ANNOUNCE");
	}
	
	g_gameState = BB_GAMESTATE_INVALID;
	ExecuteForward(g_fw[fwRoundEnd], g_fw[fwReturn]);
	return PLUGIN_HANDLED;
}

releaseZombies() {
	g_iCountDownSecs = 0;
	g_iCountDownTenth = 0;
	g_gameState = BB_GAMESTATE_RELEASE;
	
	set_pev(g_iBarrier, pev_solid, SOLID_NOT);
	set_pev(g_iBarrier, pev_renderamt, 0.0);
	
	set_hudmessage(200, 0, 0, -1.0, 0.40, 0, 1.0, 10.0, 0.1, 0.2);
	ShowSyncHudMsg(0, g_iHudSync1, "%L", LANG_PLAYER, "RELEASE_ANNOUNCE");
	bb_playSound(0, PHASE_RELEASE[random(sizeof PHASE_RELEASE)]);
	ExecuteForward(g_fw[fwZombiesReleased], g_fw[fwReturn]);
}

public msgRoundEnd(const msgID, const msgDest, const msgEnt) {
	new szMessage[32];
	get_msg_arg_string(2, szMessage, 31);
	if (equal(szMessage[7], "terwin", 6) || equal(szMessage[7], "ctwin", 5) || equal(szMessage[7], "rounddraw", 9)) {
		return PLUGIN_HANDLED;
	}
	
	if (equal(szMessage[1], "Terrorists_Win", 14)) {
		g_gameState = BB_GAMESTATE_ROUNDEND;
		set_hudmessage(255, 255, 255, -1.0, 0.40, 0, 6.0, 6.0, 0.1, 0.2);
		ShowSyncHudMsg(0, g_iHudSync1, "%L", LANG_SERVER, "WIN_ZOMBIE");
		set_msg_arg_string(2, "");
		bb_playSound(0, WIN_ZOMBIES);
		return PLUGIN_HANDLED;
	} else if (equal(szMessage[1], "Target_Saved", 12) || equal(szMessage[1], "CTs_Win", 7)) {
		g_gameState = BB_GAMESTATE_ROUNDEND;
		set_hudmessage(255, 255, 255, -1.0, 0.40, 0, 6.0, 6.0, 0.1, 0.2);
		ShowSyncHudMsg(0, g_iHudSync1, "%L", LANG_SERVER, "WIN_BUILDER");
		set_msg_arg_string(2, "");
		bb_playSound(0, WIN_BUILDERS);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public msgStatusIcon(const msgID, const msgDest, const id) {
	static szMsg[8];
	get_msg_arg_string(2, szMsg, 7);
	if(equal(szMsg, "buyzone", 7)) {
		set_pdata_int(id, OFFSET_BUYZONE, get_pdata_int(id, OFFSET_BUYZONE) & ~1);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
} 

//native bb_game_getBarrier();
public _getBarrier(plugin, params) {
	if (params != 0) {
		return null;
	}
	
	return g_iBarrier;
}

//native BB_GAMESTATE:bb_game_getGameState();
public BB_GAMESTATE:_getGameState(plugin, params) {
	if (params != 0) {
		return BB_GAMESTATE_INVALID;
	}
	
	return g_gameState;
}

public ham_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits) {
	if (!is_user_alive(victim) || !is_user_connected(attacker)) {
		return HAM_IGNORED;
	}
	
	if (victim == attacker) {
		return HAM_SUPERCEDE;
	}
	
	if (g_gameState != BB_GAMESTATE_RELEASE) {
		return HAM_SUPERCEDE;
	}
		
	if (g_iInstaKill && flagGet(g_flagZombie,attacker) && !flagGet(g_flagZombie,victim)) {
		damage *= 99.0
	}
	
	SetHamParamFloat(4, damage)
	return HAM_HANDLED
}

public fwSuicide(id) {
	return FMRES_SUPERCEDE;
}

public ev_SetTeam(id) {
	if (read_data(2) == 1) {
		flagSet(g_flagFriend,id);
	} else {
		flagUnset(g_flagFriend,id);
	}
}

public ev_ShowStatus(id) {
	static szName[32], szColor[32], pid;
	pid = read_data(2);
	get_user_name(pid, szName, 31);
	if (flagGet(g_flagFriend,id)) {
		static clip, ammo, wpnid;
		wpnid = get_user_weapon(pid, clip, ammo);
		set_hudmessage(0, 225, 0, -1.0, HUD_FRIEND_HEIGHT, 1, 0.01, 3.0, 0.01, 0.01);
		if (flagGet(g_flagZombie,id)) {
			bb_class_getClassName(bb_class_getUserClass(pid), szColor, 31);
			ShowSyncHudMsg(id, g_iHudSync2, "%s^nClass: %s^nHealth: %d", szName, szColor, pev(pid, pev_health));
		} else if (g_gameState == BB_GAMESTATE_BUILDPHASE) {
			bb_color_getColorName(bb_color_getUserColor(pid), szColor, 31);
			ShowSyncHudMsg(id, g_iHudSync2, "%s^nColor: %s", szName, szColor);
		} else {
			bb_color_getColorName(bb_color_getUserColor(pid), szColor, 31);
			ShowSyncHudMsg(id, g_iHudSync2, "%s^nHealth: %d | Weapon: %L^nColor: %s", szName, pev(pid, pev_health), id, g_szWpnEntNames[wpnid], szColor);
		}
	} else {
		set_hudmessage(225, 0, 0, -1.0, HUD_FRIEND_HEIGHT, 1, 0.01, 3.0, 0.01, 0.01);
		if (flagGet(g_flagZombie,pid) || g_gameState != BB_GAMESTATE_BUILDPHASE) {
			ShowSyncHudMsg(id, g_iHudSync2, "%s", szName);
		} else {
			bb_color_getColorName(bb_color_getUserColor(pid), szColor, 31);
			ShowSyncHudMsg(id, g_iHudSync2, "%s^nColor: %s", szName, szColor);
		}
	}
}

public ev_HideStatus(id) {
	ClearSyncHud(id, g_iHudSync2);
}

showClockMenu(id) {
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	menu_display(id, g_Menu_Clocks);
}

public clockMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		return PLUGIN_HANDLED;
	}
	
	switch (item) {
		case 0: createClockAiming(id);
		case 1: deleteClockAiming(id);
		case 2: scaleClockAiming(id, 0.1);
		case 3: scaleClockAiming(id, -0.1);
		case 4: saveClocks(id);
	}
	
	showClockMenu(id);
	return PLUGIN_HANDLED;
}

createClockAiming(id) {
	new Float:vOrigin[3];
	get_aim_origin(id, vOrigin);
	new Float:vAngles[3], Float:vNormal[3];
	new bool:bSuccess = traceClockAngles(id, vAngles, vNormal, 1000.0);
	if (bSuccess) {
		if (vNormal[2] == 0.0) {
			bSuccess = createClock(vOrigin, vAngles, vNormal);
			if (bSuccess) {
				bb_printColor(id, "%L", id, "CLOCK_CREATED");
			}
		} else {
			bb_printColor(id, "%L", id, "CLOCK_NEEDS_VERTICAL");
		}
	} else {
		bb_printColor(id, "%L", id, "CLOCK_MOVE_CLOSER");
	}
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

bool:traceClockAngles(id, Float:vAngles[3], Float:vNormal[3], Float:fDistance) {
	new Float:vPlayerOrigin[3], Float:vViewOfs[3];
	entity_get_vector(id, EV_VEC_origin, vPlayerOrigin);
	entity_get_vector(id, EV_VEC_view_ofs, vViewOfs);
	xs_vec_add(vPlayerOrigin, vViewOfs, vPlayerOrigin);
	
	new Float:vAiming[3];
	entity_get_vector(id, EV_VEC_v_angle, vAngles);
	vAiming[0] = vPlayerOrigin[0] + floatcos(vAngles[1], degrees) * fDistance;
	vAiming[1] = vPlayerOrigin[1] + floatsin(vAngles[1], degrees) * fDistance;
	vAiming[2] = vPlayerOrigin[2] + floatsin(-vAngles[0], degrees) * fDistance;
	
	new trace = trace_normal(id, vPlayerOrigin, vAiming, vNormal);
	vector_to_angle(vNormal, vAngles);
	vAngles[1] += 180.0;
	if (vAngles[1] >= 360.0) {
		vAngles[1] -= 360.0;
	}
	
	return bool:trace;
}

bool:createClock(Float:vOrigin[3], Float:vAngles[3], Float:vNormal[3], Float:fScale = 1.0) {
	new clock = create_entity(INFO_TARGET);
	new digit[4];
	new bool:bFailed = false;
	
	for (new i = 0; i < 4 && !bFailed; i++) {
		digit[i] = create_entity(INFO_TARGET);
		if (!is_valid_ent(digit[i])) {
			bFailed = true;
			break;
		}
	}
	
	if (is_valid_ent(clock) && !bFailed) {
		vOrigin[0] += (vNormal[0] * 0.5);
		vOrigin[1] += (vNormal[1] * 0.5);
		vOrigin[2] += (vNormal[2] * 0.5);
		
		entity_set_string(clock, EV_SZ_classname, BB_CLOCK);
		entity_set_int(clock, EV_INT_solid, SOLID_NOT);
		entity_set_model(clock, CLOCK_FACE);
		entity_set_vector(clock, EV_VEC_angles, vAngles);
		entity_set_float(clock, EV_FL_scale, fScale);
		entity_set_origin(clock, vOrigin);
		
		entity_set_int(clock, EV_INT_iuser1, digit[0]);
		entity_set_int(clock, EV_INT_iuser2, digit[1]);
		entity_set_int(clock, EV_INT_iuser3, digit[2]);
		entity_set_int(clock, EV_INT_iuser4, digit[3]);
		
		new digitValues[4];
		for (new i = 0; i < 4; i++) {
			entity_set_string(digit[i], EV_SZ_classname, BB_CLOCK_DIGIT);
			entity_set_vector(digit[i], EV_VEC_angles, vAngles);
			entity_set_model(digit[i], CLOCK_DIGIT);
			entity_set_float(digit[i], EV_FL_scale, fScale);
			
			setDigitOrigin(i, digit[i], vOrigin, vNormal, fScale);
			getTimeDigits(0, 0, digitValues);
			setClockDigits(clock, digitValues);
		}
		
		return true;
	} else {
		if (is_valid_ent(clock)) {
			remove_entity(clock);
		}
		
		for (new i = 0; i < 4; i++) {
			if (is_valid_ent(digit[i])) {
				remove_entity(digit[i]);
			}
		}
	}
	
	return false;
}

setDigitOrigin(i, digit, Float:vOrigin[3], Float:vNormal[3], Float:fScale) {
	new Float:vDigitNormal[3];
	new Float:vPos[3];
	new Float:fVal;
	
	vDigitNormal = vNormal;
	if (i == 0 || i == 1) {
		vDigitNormal[0] = -vDigitNormal[0];
	}
	
	if (i == 2 || i == 3) {
		vDigitNormal[1] = -vDigitNormal[1];
	}
	
	fVal = (((CLOCK_SIZE[0] / 2) * DIGIT_OFFS_MULTIPLIER[i])) * fScale;
	vPos[0] = vOrigin[0] + (vDigitNormal[1] * fVal);
	vPos[1] = vOrigin[1] + (vDigitNormal[0] * fVal);
	vPos[2] = vOrigin[2] + vNormal[2] - ((TITLE_SIZE / 2.0 )* fScale);
	vPos[0] += (vNormal[0] * 0.5);
	vPos[1] += (vNormal[1] * 0.5);
	vPos[2] += (vNormal[2] * 0.5);
	entity_set_origin(digit, vPos);
}

getTimeDigits(mins, secs, digitValues[4]) {
	new digits[5];
	formatex(digits, 4, "%s%d%s%d", (mins < 10 ? "0" : ""), mins, (secs < 10 ? "0" : ""), secs);
	digitValues[0] = digits[0] - '0';
	digitValues[1] = digits[1] - '0';
	digitValues[2] = digits[2] - '0';
	digitValues[3] = digits[3] - '0';
}

setClockDigits(clock, digitValues[4]) {
	new digits[4];
	getClockDigits(clock, digits);
	entity_set_float(digits[0], EV_FL_frame, float(digitValues[0]));
	entity_set_float(digits[1], EV_FL_frame, float(digitValues[1]));
	entity_set_float(digits[2], EV_FL_frame, float(digitValues[2]));
	entity_set_float(digits[3], EV_FL_frame, float(digitValues[3]));
}

getClockDigits(clock, digit[4]) {
	digit[0] = entity_get_int(clock, EV_INT_iuser1);
	digit[1] = entity_get_int(clock, EV_INT_iuser2);
	digit[2] = entity_get_int(clock, EV_INT_iuser3);
	digit[3] = entity_get_int(clock, EV_INT_iuser4);
}

deleteClockAiming(id) {
	new clock = getClockAiming(id);
	if (clock) {
		deleteClock(clock);
		bb_printColor(id, "%L", id, "CLOCK_DELETED");
	}
}

getClockAiming(id) {
	new Float:vOrigin[3];
	get_aim_origin(id, vOrigin);
	new szTemp[32];
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, vOrigin, 2.0))) {
		entity_get_string(ent, EV_SZ_classname, szTemp, 31);
		if (equal(szTemp, BB_CLOCK)) {
			return ent;
		}
	}
	
	return 0;
}

bool:deleteClock(clock) {
	new digit[4];
	digit[0] = entity_get_int(clock, EV_INT_iuser1);
	digit[1] = entity_get_int(clock, EV_INT_iuser2);
	digit[2] = entity_get_int(clock, EV_INT_iuser3);
	digit[3] = entity_get_int(clock, EV_INT_iuser4);

	if (is_valid_ent(digit[0])) remove_entity(digit[0]);
	if (is_valid_ent(digit[1])) remove_entity(digit[1]);
	if (is_valid_ent(digit[2])) remove_entity(digit[2]);
	if (is_valid_ent(digit[3])) remove_entity(digit[3]);
	
	remove_entity(clock);
	return true;
}

scaleClockAiming(id, Float:fScaleAmount) {
	new clock = getClockAiming(id);
	if (clock) {
		new digit[4];
		getClockDigits(clock, digit);
		new Float:vOrigin[3];
		new Float:vNormal[3];
		new Float:vAngles[3];
		
		new Float:fScale = entity_get_float(clock, EV_FL_scale);
		fScale += fScaleAmount;
		
		if (fScale > 0.01) {
			entity_set_float(clock, EV_FL_scale, fScale);
			entity_get_vector(clock, EV_VEC_origin, vOrigin);
			entity_get_vector(clock, EV_VEC_angles, vAngles);
			angle_vector(vAngles, ANGLEVECTOR_FORWARD, vNormal);		
			xs_vec_neg(vNormal, vNormal);
			for (new i = 0; i < 4; i++) {
				entity_set_float(digit[i], EV_FL_scale, fScale);
				setDigitOrigin(i, digit[i], vOrigin, vNormal, fScale);
			}
		}
	}
}

saveClocks(id) {
	new szMapFile[128];
	new len = get_configsdir(szMapFile, 127);
	szMapFile[len++] = '/';
	len += copy(szMapFile[len], 127-len, BB_HOME_DIR);
	len += copy(szMapFile[len], 127-len, "clocks/");
	len += get_mapname(szMapFile[len], 127-len);
	len += copy(szMapFile[len], 127-len, ".cfg");

	new line = 0, ent = -1;
	new Float:origin[3], Float:angles[3], Float:scale, szLine[128];
	while ((ent = find_ent_by_class(ent, BB_CLOCK))) {
		entity_get_vector(ent, EV_VEC_origin, origin);
		entity_get_vector(ent, EV_VEC_angles, angles);
		scale = entity_get_float(ent, EV_FL_scale);
		formatex(szLine, 127, "%f %f %f %f %f %f %f", origin[0], origin[1], origin[2], angles[0], angles[1], angles[2], scale);
		write_file(szMapFile, szLine, line++);
	}
	
	bb_printColor(id, "The clocks have been saved!");
}

loadClocks() {
	new szMapFile[128];
	new len = get_configsdir(szMapFile, 127);
	szMapFile[len++] = '/';
	len += copy(szMapFile[len], 127-len, BB_HOME_DIR);
	len += copy(szMapFile[len], 127-len, "clocks/");
	mkdir(szMapFile);
	len += get_mapname(szMapFile[len], 127-len);
	len += copy(szMapFile[len], 127-len, ".cfg");
	if (!file_exists(szMapFile)) {
		server_print("Failed to locate clock save file");
		return;
	}
	
	new szOrigin[3][16], szAngles[3][16], szScale[16];
	new Float:origin[3], Float:angles[3], Float:scale, Float:normal[3];
	new szLine[128], line;
	while ((line = read_file(szMapFile, line, szLine, 127, len)) != 0) {
		parse(szLine, 	szOrigin[0], 15, szOrigin[1], 15, szOrigin[2], 15,
						szAngles[0], 15, szAngles[1], 15, szAngles[2], 15,
						szScale, 15);
		
		for (new i = 0; i < 3; i++) {
			origin[i]	= str_to_float(szOrigin[i]);
			angles[i]	= str_to_float(szAngles[i]);
		}
		
		scale = str_to_float(szScale);
		angle_vector(angles, ANGLEVECTOR_FORWARD, normal);
		xs_vec_neg(normal, normal);
		createClock(origin, angles, normal, scale);
	}		
}