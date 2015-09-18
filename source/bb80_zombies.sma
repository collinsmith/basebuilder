#pragma dynamic 128

#include <amxmodx>
#include <hamsandwich>
#include <cs_team_changer>
#include <cs_weap_restrict_api>

#include "include/bb/bb_core.inc"
#include "include/bb/bb_zombies_const.inc"
#include "include/bb/bb_commands.inc"

#define PLUGIN_VERSION "0.0.1"

#define AUTO_TEAM_JOIN_DELAY 0.1

#define ZOMBIE_ALLOWED_WEAPONS (1<<CSW_KNIFE)
#define ZOMBIE_DEFAULT_WEAPON CSW_KNIFE

static BB_TEAM:g_actualTeam[MAX_PLAYERS+1] = { BB_TEAM_UNASSIGNED, ... };

enum _:ePluginTasks (+= 5039) {
	task_AutoJoin = 514229,
	task_RespawnUser
}

enum _:player_t {
	player_Connected,
	player_Alive,
	player_Zombie,
	player_FirstTeam
};

static g_iPlayerInfo[player_t];

enum _:eForwardedEvents {
	fwReturn,
	fwPlayerDeath,
	fwPlayerSpawn,
	fwBlockTeamChange,
	fwUserInfectPre, fwUserInfect, fwUserInfectPost,
	fwUserCurePre, fwUserCure, fwUserCurePost,
	fwRefresh
};

static g_fw[eForwardedEvents];

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Zombies]", "Controls who is a zombie and who isn't", PLUGIN_VERSION);
}

public plugin_init() {
	register_clcmd("chooseteam", "blockTeamChange");
	register_clcmd("jointeam", "blockTeamChange");
	register_message(get_user_msgid("ShowMenu"), "msgShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "msgShowVGUIMenu");
	register_message(get_user_msgid("TeamInfo"), "msgTeamInfo");
	
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);
	
	register_concmd("zombie.dump", "dumpPlayerInfo");

	RegisterHam(Ham_Spawn, "player", "ham_PlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed, "player", "ham_PlayerKilled", 0);
	
	g_fw[fwUserInfectPre]	= CreateMultiForward("bb_fw_zm_infect_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_fw[fwUserInfect]		= CreateMultiForward("bb_fw_zm_infect", ET_IGNORE, FP_CELL, FP_CELL);
	g_fw[fwUserInfectPost]	= CreateMultiForward("bb_fw_zm_infect_post", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_fw[fwUserCurePre]		= CreateMultiForward("bb_fw_zm_cure_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_fw[fwUserCure]		= CreateMultiForward("bb_fw_zm_cure", ET_IGNORE, FP_CELL, FP_CELL);
	g_fw[fwUserCurePost]	= CreateMultiForward("bb_fw_zm_cure_post", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_fw[fwPlayerSpawn]		= CreateMultiForward("bb_fw_zm_playerSpawn", ET_IGNORE, FP_CELL, FP_CELL);
	g_fw[fwPlayerDeath]		= CreateMultiForward("bb_fw_zm_playerDeath", ET_IGNORE, FP_CELL, FP_CELL);
	g_fw[fwBlockTeamChange]	= CreateMultiForward("bb_fw_zm_blockTeamChange", ET_IGNORE, FP_CELL);
	
	g_fw[fwRefresh]	= CreateMultiForward("bb_fw_zm_refresh", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives() {
	register_library("BB_Zombies");
	
	register_native("bb_zm_respawnUser", "_respawnUser", 0);
	register_native("bb_zm_fixInfection", "_fixInfection", 0);
	
	register_native("bb_zm_infectUser", "_infectUser", 0);
	register_native("bb_zm_cureUser", "_cureUser", 0);
	
	register_native("bb_zm_isUserConnected", "_isUserConnected", 0);
	register_native("bb_zm_isUserAlive", "_isUserAlive", 0);
	register_native("bb_zm_isUserZombie", "_isUserZombie", 0);
}

public dumpPlayerInfo(id) {
	new size = get_playersnum(), szTemp[32];
	if (size) {
		for (new i = 1; i <= size; i++) {
			szTemp[0] = '^0';
			get_user_name(i, szTemp, 31);
			console_print(id, "%d. %c, %s", i, flagGet(g_iPlayerInfo[player_Zombie],i) ? 'Z' : 'H', szTemp);
		}
		
		return PLUGIN_HANDLED;
	}
	
	console_print(id, "No players found");
	return PLUGIN_HANDLED;
}

public client_putinserver(id) {
	flagSet(g_iPlayerInfo[player_Connected],id);
}

public client_disconnect(id) {
	remove_task(id+task_AutoJoin);
	remove_task(id+task_RespawnUser);
	
	flagUnset(g_iPlayerInfo[player_Connected],id);
	flagUnset(g_iPlayerInfo[player_Alive],id);
	flagUnset(g_iPlayerInfo[player_Zombie],id);
	flagUnset(g_iPlayerInfo[player_FirstTeam],id);
	g_actualTeam[id] = BB_TEAM_UNASSIGNED;
}

public ham_PlayerSpawn_Post(id) {
	if (!is_user_alive(id)) {
		flagUnset(g_iPlayerInfo[player_Alive],id);
		return HAM_IGNORED;
	}
	
	flagSet(g_iPlayerInfo[player_Alive],id);
	ExecuteForward(g_fw[fwRefresh], g_fw[fwReturn], id, flagGetBool(g_iPlayerInfo[player_Zombie],id));
	ExecuteForward(g_fw[fwPlayerSpawn], g_fw[fwReturn], id, flagGetBool(g_iPlayerInfo[player_Zombie],id));
	return HAM_HANDLED;
}

public ham_PlayerKilled(killer, victim, shouldgib) {
	if (is_user_alive(victim)) {
		return HAM_IGNORED;
	}
	
	show_menu(victim, 0, "^n", 1);
	flagUnset(g_iPlayerInfo[player_Alive],victim);
	ExecuteForward(g_fw[fwPlayerDeath], g_fw[fwReturn], killer, victim);
	return HAM_HANDLED;
}

public blockTeamChange(id) {
	new BB_TEAM:curTeam = BB_TEAM:get_user_team(id);
	if (curTeam == BB_TEAM_SPECTATOR || curTeam == BB_TEAM_UNASSIGNED) {
		return PLUGIN_CONTINUE;
	}
	
	ExecuteForward(g_fw[fwBlockTeamChange], g_fw[fwReturn], id);
	return PLUGIN_HANDLED;
}

//native BB_PLAYERSTATE:bb_zm_infectUser(id, infector, bool:blockable);
public BB_PLAYERSTATE:_infectUser(plugin, params)  {
	if (params != 3) {
		return BB_STATE_INVALID;
	}
	
	new id = get_param(1);
	if (!flagGet(g_iPlayerInfo[player_Connected],id)) {
		return BB_STATE_INVALID;
	}
	
	if (flagGet(g_iPlayerInfo[player_Zombie],id)) {
		ExecuteForward(g_fw[fwRefresh], g_fw[fwReturn], id, true);
		return BB_STATE_NOCHANGE;
	}
	
	infectUser(id, get_param(2), bool:get_param(3));
	return BB_STATE_CHANGE;
}

infectUser(id, infector, bool:blockable) {
	ExecuteForward(g_fw[fwUserInfectPre], g_fw[fwReturn], id, infector);
	if (blockable && g_fw[fwReturn] == BB_RET_BLOCK) {
		return;
	}
	
	show_menu(id, 0, "^n", 1);
	ExecuteForward(g_fw[fwUserInfect], g_fw[fwReturn], id, infector);
	
	flagSet(g_iPlayerInfo[player_Zombie],id);
	cs_set_team(id, BB_TEAM_ZOMBIE);
	cs_set_player_weap_restrict(id, true, ZOMBIE_ALLOWED_WEAPONS, ZOMBIE_DEFAULT_WEAPON);
	ExecuteForward(g_fw[fwRefresh], g_fw[fwReturn], id, true);
	
	ExecuteForward(g_fw[fwUserInfectPost], g_fw[fwReturn], id, infector);
}

//native BB_PLAYERSTATE:bb_zm_cureUser(id, curer, bool:blockable);
public BB_PLAYERSTATE:_cureUser(plugin, params)  {
	if (params != 3) {
		return BB_STATE_INVALID;
	}
	
	new id = get_param(1);
	if (!flagGet(g_iPlayerInfo[player_Connected],id)) {
		return BB_STATE_INVALID;
	}
	
	if (!flagGet(g_iPlayerInfo[player_Zombie],id)) {
		ExecuteForward(g_fw[fwRefresh], g_fw[fwReturn], id, false);
		return BB_STATE_NOCHANGE;
	}
	
	cureUser(id, get_param(2), bool:get_param(3));
	return BB_STATE_CHANGE;
}

cureUser(id, curer, bool:blockable) {
	ExecuteForward(g_fw[fwUserCurePre], g_fw[fwReturn], id, curer);
	if (blockable && g_fw[fwReturn] == BB_RET_BLOCK) {
		return;
	}
	
	show_menu(id, 0, "^n", 1);
	ExecuteForward(g_fw[fwUserCure], g_fw[fwReturn], id, curer);
	
	flagUnset(g_iPlayerInfo[player_Zombie],id);
	cs_set_team(id, BB_TEAM_HUMAN);
	cs_set_player_weap_restrict(id, false, ZOMBIE_ALLOWED_WEAPONS, ZOMBIE_DEFAULT_WEAPON);
	ExecuteForward(g_fw[fwRefresh], g_fw[fwReturn], id, false);
	
	ExecuteForward(g_fw[fwUserCurePost], g_fw[fwReturn], id, curer);
}

//native bool:bb_zm_isUserConnected(id);
public bool:_isUserConnected(plugin, params) {
	return flagGetBool(g_iPlayerInfo[player_Connected],get_param(1));
}

//native bool:bb_zm_isUserAlive(id);
public bool:_isUserAlive(plugin, params) {
	return flagGetBool(g_iPlayerInfo[player_Alive],get_param(1));
}

//native bool:bb_zm_isUserZombie(id);
public bool:_isUserZombie(plugin, params) {
	return flagGetBool(g_iPlayerInfo[player_Zombie],get_param(1));
}

//native bb_zm_respawnUser(id, bool:force);
public _respawnUser(plugin, params) {
	if (params != 2) {
		return;
	}
	
	respawnUser(get_param(1), bool:get_param(2));
}

respawnUser(id, bool:force) {
	if (flagGetBool(g_iPlayerInfo[player_Alive],id) && !force) {
		return;
	}
	
	ExecuteHamB(Ham_CS_RoundRespawn, id);
}

public msgShowMenu(const msgID, const msgDest, const id) {
	if (get_user_team(id)) {
		return PLUGIN_CONTINUE;
	}

	new szMenuTextCode[13];
	get_msg_arg_string(4, szMenuTextCode, 12);
	if (!equal(szMenuTextCode, "#Team_Select")) {
		return PLUGIN_CONTINUE;
	}

	new szParamMenuMsgID[2];
	szParamMenuMsgID[0] = msgID;
	set_task(AUTO_TEAM_JOIN_DELAY, "forceTeamJoin", id+task_AutoJoin, szParamMenuMsgID, 1);
	return PLUGIN_HANDLED;
}

public msgShowVGUIMenu(const msgID, const msgDest, const id) {
	if (get_msg_arg_int(1) != 2 || get_user_team(id)) { 
		return PLUGIN_CONTINUE;
	}
		
	new szParamMenuMsgID[2];
	szParamMenuMsgID[0] = msgID;
	set_task(AUTO_TEAM_JOIN_DELAY, "forceTeamJoin", id+task_AutoJoin, szParamMenuMsgID, 1);
	return PLUGIN_HANDLED;
}

public forceTeamJoin(params[], id) {
	id -= task_AutoJoin;
	if (get_user_team(id)) {
		return;
	}

	new msgBlock = get_msg_block(params[0]);
	set_msg_block(params[0], BLOCK_SET);
	engclient_cmd(id, "jointeam", "5");
	engclient_cmd(id, "joinclass", "5");
	set_msg_block(params[0], msgBlock);
	set_task(1.0, "respawnUserTask", id+task_RespawnUser);
}

public respawnUserTask(taskid) {
	taskid -= task_RespawnUser;
	respawnUser(taskid, false);
	if (!flagGet(g_iPlayerInfo[player_Alive],taskid)) {
		set_task(1.0, "respawnUserTask", taskid+task_RespawnUser);
	}
}

public msgTeamInfo(const msgID, const msgDest) {
	if (msgDest != MSG_ALL && msgDest != MSG_BROADCAST) {
		return;
	}
	
	new team[2];
	get_msg_arg_string(2, team, 1)
	new id = get_msg_arg_int(1);
	if (!flagGet(g_iPlayerInfo[player_FirstTeam],id) && (team[0] == 'T' || team[0] == 'C')) {
		flagSet(g_iPlayerInfo[player_FirstTeam],id);
		g_actualTeam[id] = team[0] == 'T' ? BB_TEAM_ZOMBIE : BB_TEAM_HUMAN;
		if (g_actualTeam[id] == BB_TEAM_ZOMBIE) {
			infectUser(id, -1, false);
		} else {
			cureUser(id, -1, false);
		}
	} else if (team[0] == 'S') {
		user_kill(id);
		g_actualTeam[id] = BB_TEAM_SPECTATOR;
		flagUnset(g_iPlayerInfo[player_FirstTeam],id);
	}
}

//native bb_zm_fixInfection(id);
public bool:_fixInfection(plugin, params) {
	static id;
	id = get_param(1);
	if (g_actualTeam[id] == BB_TEAM_UNASSIGNED || g_actualTeam[id] == BB_TEAM_SPECTATOR) {
		return;
	}
	
	g_actualTeam[id] = g_actualTeam[id] == BB_TEAM_HUMAN ? BB_TEAM_ZOMBIE : BB_TEAM_HUMAN;
	if (flagGet(g_iPlayerInfo[player_Zombie],id) && g_actualTeam[id] == BB_TEAM_HUMAN) {
		cureUser(id, -1, false);
	} else if (!flagGet(g_iPlayerInfo[player_Zombie],id) && g_actualTeam[id] == BB_TEAM_ZOMBIE) {
		infectUser(id, -1, false);
	}
}