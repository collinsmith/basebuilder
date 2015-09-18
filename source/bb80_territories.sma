#pragma dynamic 2048

#include <amxmodx>
#include <engine>
#include <cvar_util>

#include "include/bb/classes/territory_t.inc"
#include "include/bb/bb_builder.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_zones.inc"
#include "include/bb/bb_game.inc"
#include "include/bb/bb_zombies.inc"
//#include "include/bb/bb_colors.inc"
#include "include/bb/bb_commands.inc"
#include "include/bb/bb_colorchat.inc"

#define PLUGIN_VERSION "0.0.1"

#define task_ClaimTimer 8675309
#define CLAIM_BASE_TIME 5.0

static const BB_TERRITORY[] = "bb_territory";

static g_Menu_Claim;
static g_Menu_FriendInvite;
static g_Menu_Territory;

static g_curTerritory[MAX_PLAYERS+1] = { null, ... };
static g_nextTerritory[MAX_PLAYERS+1] = { null, ... };

static Float:g_fEnterTime[MAX_PLAYERS+1] = { 0.0, ... };
static g_softKillTer[MAX_PLAYERS+1] = { null, ... };

static g_territoryNum;
static Array:g_territoryList;
static g_tempTerritory[territory_t];

static flag_OpenClaimMenu;

enum _:forward_t {
	fwReturn,
	fwTerAddPlayer,
	fwTerRemovePlayer
};

static g_fw[forward_t];

static g_iBlockHumanRatio;
#define MAX_ALLOWED_CLAIM (g_tempTerritory[territory_NumPlayers] * g_iBlockHumanRatio)

static g_iHumanZombieRatio;
static g_iMaxTerritoryNum;

static Float:g_fSoftKillTime;

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Territories]", "Manages and creates territories", PLUGIN_VERSION);
}

public bb_fw_init_post() {
	bb_command_register("territories", "showTerritoryMenu", "abde", "Opens the territories menu");
	bb_command_register("termenu", "showTerritoryMenu");
}

public plugin_init() {
	register_touch(BB_TERRITORY, "player", "fwTouch");
	
	g_iBlockHumanRatio = CvarRegister("bb_ter_blockHumanRatio", "7", "Number of blocks each human gets", _, true, 5.0, true, 15.0);
	CvarCache(g_iBlockHumanRatio, CvarType_Int, g_iBlockHumanRatio);	
	
	g_iHumanZombieRatio = CvarRegister("bb_ter_humanZombieRatio", "4", "For each zombie, humans have this many in a base", _, true, 3.0, true, 8.0);
	CvarCache(g_iHumanZombieRatio, CvarType_Int, g_iHumanZombieRatio);
	
	new g_pCvar = CvarRegister("bb_ter_softKillTime", "10.0", "Time to effect player not in their base", _, true, 0.0, true, 15.0);
	CvarCache(g_pCvar, CvarType_Float, g_fSoftKillTime);
	
	g_fw[fwTerAddPlayer] = CreateMultiForward("bb_fw_ter_addPlayerToTer", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_fw[fwTerRemovePlayer] = CreateMultiForward("bb_fw_ter_removePlayerFromTer", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	
	g_territoryList = ArrayCreate(territory_t, 16);
	
	g_Menu_Claim = menu_create("Do you want to claim this territory?", "claimMenuHandler");
	menu_setprop(g_Menu_Claim, MPROP_PERPAGE, 0);
	menu_additem(g_Menu_Claim, "Yes");
	menu_additem(g_Menu_Claim, "Yes and befriend all inside");
	menu_additem(g_Menu_Claim, "No");
	
	g_Menu_FriendInvite = menu_create("Would you like to join this territory?", "friendInviteHandler");
	menu_setprop(g_Menu_FriendInvite, MPROP_PERPAGE, 0);
	menu_additem(g_Menu_FriendInvite, "Yes");
	menu_additem(g_Menu_FriendInvite, "No");
	menu_setprop(g_Menu_FriendInvite, MPROP_EXIT, MEXIT_NEVER);
	
	g_Menu_Territory = menu_create("Territory Menu", "territoryMenuHandler");
	menu_additem(g_Menu_Territory, "Befriend Player");
	menu_item_setcall(g_Menu_Territory, 0, menu_makecallback("befriendCallback"));
	menu_additem(g_Menu_Territory, "Leave Territory");
	
	new ent = -1;
	while ((ent = find_ent_by_class(ent, BB_TERRITORY)) != 0) {
		g_tempTerritory[territory_Parent] = ent;
		ArrayPushArray(g_territoryList, g_tempTerritory);
		SetChild(ent, g_territoryNum);
		g_territoryNum++;
	}
}

public plugin_natives() {
	register_library("BB_Territories");
	
	register_native("bb_ter_belongsToTerritory", "_belongsToTerritory", 0);
	register_native("bb_ter_isClaimed", "_isClaimed", 0);
	register_native("bb_ter_getUserTerritory", "_getUserTerritory", 0);
	register_native("bb_ter_formatPartnerNames", "_formatPartnerNames", 0);
	
	register_native("bb_ter_unclaimBlock", "_unclaimBlock", 0);
	register_native("bb_ter_claimBlock", "_claimBlock", 0);
	register_native("bb_ter_canMoveBlock", "_canMoveBlock", 0);
}

public fwTouch(terEnt, id) {
	if (bb_zm_isUserZombie(id)) {
		return PLUGIN_CONTINUE;
	}
	
	new territory = GetChild(terEnt);
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	if (g_curTerritory[id] != null || g_nextTerritory[id] != null) {
		if (!belongsToTerritory(id, terEnt) && g_tempTerritory[territory_Owner] && g_tempTerritory[territory_Owner] != id) {
			new Float:gameTime = get_gametime();
			if (g_softKillTer[id] != terEnt) {
				g_softKillTer[id] = terEnt;
				g_fEnterTime[id] = gameTime + g_fSoftKillTime;
			} else if (g_fEnterTime[id] < gameTime) {
				if (bb_game_getGameState() == BB_GAMESTATE_RELEASE) {
					bb_printColor(id, "You've been infected for being in someone else's territory.");
					bb_zm_infectUser(id, -1, false);
					bb_zm_respawnUser(id, true);
				} else {
					bb_printColor(id, "You've been repawned for being in someone else's territory.");
					bb_zm_respawnUser(id, true);
				}
				
				g_softKillTer[id] = null;
			} else {
				client_print(id, print_center, "Get out of this territory. You have %.1f seconds before you will be punished", g_fEnterTime[id]-gameTime);
			}
		}
		
		return PLUGIN_CONTINUE;
	}
	
	if (g_tempTerritory[territory_Owner] || g_tempTerritory[territory_MenuIgnore] == id) {
		return PLUGIN_CONTINUE;
	}
	
	showClaimMenu(id, territory);
	set_task(CLAIM_BASE_TIME, "claimTerritoryTask", id+task_ClaimTimer);
	return PLUGIN_CONTINUE;
}

public client_disconnect(id) {
	removeFromTerritory(id);
	g_nextTerritory[id] = null;
	remove_task(id+task_ClaimTimer);
	flagUnset(flag_OpenClaimMenu,id);
	g_softKillTer[id] = null;
}

public bb_fw_game_buildPhaseStart() {
	for (new i = 0; i < g_territoryNum; i++) {
		ArrayGetArray(g_territoryList, i, g_tempTerritory);
		g_tempTerritory[territory_MenuIgnore] = 0;
		ArraySetArray(g_territoryList, i, g_tempTerritory);
	}
	
	new players[32], num;
	get_players(players, num, "e", "T");
	g_iMaxTerritoryNum = clamp(num / g_iHumanZombieRatio, 2);
	bb_printColor(0, "%L", LANG_PLAYER, "TER_NEWMAX", g_iMaxTerritoryNum);
}

public bb_fw_zm_infect(id, infector) {
	g_softKillTer[id] = null;
	removeFromTerritory(id);
	if (flagGet(flag_OpenClaimMenu,id) && g_nextTerritory[id]) {
		menu_cancel(id);
		ArrayGetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
		g_tempTerritory[territory_Owner] = 0;
		ArraySetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
		g_nextTerritory[id] = null;
		flagUnset(flag_OpenClaimMenu,id);
	}
}

public bb_fw_zm_cure(id, curer) {
	//removeFromTerritory(id);
}

public claimTerritoryTask(taskid) {
	taskid -= task_ClaimTimer;
	if (flagGet(flag_OpenClaimMenu,taskid) && g_nextTerritory[taskid] != null) {
		menu_cancel(taskid);
		ArrayGetArray(g_territoryList, g_nextTerritory[taskid], g_tempTerritory);
		g_tempTerritory[territory_Owner] = 0;
		g_tempTerritory[territory_MenuIgnore] = taskid;
		ArraySetArray(g_territoryList, g_nextTerritory[taskid], g_tempTerritory);
		g_nextTerritory[taskid] = null;
		bb_printColor(taskid, "%L", taskid, "FAIL_TER_CLAIM");
		flagUnset(flag_OpenClaimMenu,taskid);
	}
}

showClaimMenu(id, territory) {
	if (bb_zm_isUserZombie(id)) {
		return;
	}
	
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	g_tempTerritory[territory_Owner] = id;
	ArraySetArray(g_territoryList, territory, g_tempTerritory);
	
	g_nextTerritory[id] = territory;
	menu_display(id, g_Menu_Claim);
	flagSet(flag_OpenClaimMenu,id);
}

public claimMenuHandler(id, menu, item) {
	ArrayGetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
	if (item == MENU_EXIT) {
		g_tempTerritory[territory_Owner] = 0;
		ArraySetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
		g_nextTerritory[id] = null;
		flagUnset(flag_OpenClaimMenu,id);
		return PLUGIN_HANDLED;
	}
	
	switch (item) {
		case 0: {
			addToTerritory(id, g_nextTerritory[id]);
			g_tempTerritory[territory_MenuIgnore] = 0;
			ArraySetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
			bb_printColor(id, "%L", id, "TER_CLAIMED");
		}
		case 1: {
			addToTerritory(id, g_nextTerritory[id]);
			bb_printColor(id, "%L", id, "TER_CLAIMED");
			g_tempTerritory[territory_MenuIgnore] = 0;
			ArraySetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
			
			new terEnt = g_tempTerritory[territory_Parent];
			new players[32], player, num;
			get_players(players, num, "ae", "CT");
			for (new i; i < num; i++) {
				player = players[i];
				if (id != player && bb_zone_isWithinZone(player) == terEnt) {
					showFriendInviteMenu(player, g_curTerritory[id]);
				}
			}
		}
		case 2: {
			g_tempTerritory[territory_Owner] = 0;
			g_tempTerritory[territory_MenuIgnore] = id;
			ArraySetArray(g_territoryList, g_nextTerritory[id], g_tempTerritory);
			g_nextTerritory[id] = null;
		}
	}

	remove_task(id+task_ClaimTimer);
	flagUnset(flag_OpenClaimMenu,id);
	return PLUGIN_HANDLED;
}

showFriendInviteMenu(id, territory) {
	if (g_nextTerritory[id] != null) {
		return;
	}
	
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	g_nextTerritory[id] = territory;
	menu_display(id, g_Menu_FriendInvite);
}

public befriendCallback(id, menu, item) {
	ArrayGetArray(g_territoryList, g_curTerritory[id], g_tempTerritory);
	if (g_tempTerritory[territory_Owner] == id) {
		return ITEM_ENABLED;
	}
	
	return ITEM_DISABLED;
}

public friendInviteHandler(id, menu, item) {
	switch (item) {
		case 0: {
			if (removeFromTerritory(id)) {
				bb_printColor(id, "%L", id, "TER_LEFT");
			}
			
			if (addToTerritory(id, g_nextTerritory[id])) {
				bb_printColor(id, "%L", id, "TER_BEFRIENDED");
			} else {
				bb_printColor(id, "%L", id, "TER_FULL");
			}
		}
		case 1: {
			g_nextTerritory[id] = null;
		}
	}
	
	return PLUGIN_HANDLED;
}

public showTerritoryMenu(id) {
	if (g_curTerritory[id] == null) {
		bb_printColor(id, "%L", id, "FAIL_TER_MENU");
		return;
	}
	
	menu_display(id, g_Menu_Territory);
}



public territoryMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		return PLUGIN_HANDLED;
	}
	
	switch (item) {
		case 0: {
			showBefriendMenu(id);
		}
		case 1: {
			if (removeFromTerritory(id)) {
				bb_printColor(id, "%L", id, "TER_LEFT");
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

//native bool:bb_ter_belongsToTerritory(id, terEnt);
public bool:_belongsToTerritory(plugin, params) {
	if (params != 2) {
		return false;
	}
	
	return belongsToTerritory(get_param(1), get_param(2));
}

bool:belongsToTerritory(id, terEnt) {
	ArrayGetArray(g_territoryList, GetChild(terEnt), g_tempTerritory);
	return flagGetBool(g_tempTerritory[territory_Players],id);
}

public showBefriendMenu(id) {
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	new menu = menu_create("Which player would you like to befriend?", "befriendMenuHandler");
	new szName[32], szTempid[2];
	new players[32], num, player;
	get_players(players, num, "e", "CT");
	for (new i = 0; i < num; i++) {
		player = players[i];
		if (player == id) {
			continue;
		}
		
		get_user_name(player, szName, 31);
		szTempid[0] = player;
		menu_additem(menu, szName, szTempid);
    }
	
	menu_display(id, menu, 0);
}

public befriendMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new player, szTempid[2];
	menu_item_getinfo(menu, item, player, szTempid, 1, _, _, player);
	player = szTempid[0];
	if (bb_zm_isUserAlive(player) && !bb_zm_isUserZombie(player)) {
		showFriendInviteMenu(player, g_curTerritory[id]);
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

//native bool:bb_ter_isClaimed(terEnt);
public bool:_isClaimed(plugin, params) {
	if (params != 1) {
		return false;
	}
	
	new territory = GetChild(get_param(1));
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	return g_tempTerritory[territory_Owner] > 0;
}

bool:addToTerritory(id, territory) {
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	if (g_tempTerritory[territory_NumPlayers] == g_iMaxTerritoryNum) {
		return false;
	}
	
	flagSet(g_tempTerritory[territory_Players],id);
	g_tempTerritory[territory_NumPlayers]++;
	g_curTerritory[id] = territory;
	g_nextTerritory[id] = null;
	ArraySetArray(g_territoryList, territory, g_tempTerritory);
	ExecuteForward(g_fw[fwTerAddPlayer], g_fw[fwReturn], id, territory, g_tempTerritory[territory_NumPlayers]);
	return true;
}

removeFromTerritory(id) {
	if (g_curTerritory[id] == null) {
		return false;
	}
	
	ArrayGetArray(g_territoryList, g_curTerritory[id], g_tempTerritory);
	flagUnset(g_tempTerritory[territory_Players],id);
	g_tempTerritory[territory_NumPlayers]--;
	
	if (g_tempTerritory[territory_Owner] == id) {
		g_tempTerritory[territory_Owner] = 0;
		for (new i = 1; i <= cellbits; i++) {
			if (flagGet(g_tempTerritory[territory_Players],i)) {
				g_tempTerritory[territory_Owner] = i;
				break;
			}
		}
	}
	
	if (g_tempTerritory[territory_NumPlayers] == 0) {
		g_tempTerritory[territory_NumClaimed] = 0;
		
		new ent;
		for (new i = 0; i < MAX_TER_CLAIM; i++) {
			ent = g_tempTerritory[territory_Claimed][i];
			bb_build_resetEntity(ent);
			UnclaimBlock(ent);
			g_tempTerritory[territory_Claimed][i] = 0;
		}
		
		ArraySetArray(g_territoryList, g_curTerritory[id], g_tempTerritory);
	}
	
	new tempTer = g_curTerritory[id];
	g_curTerritory[id] = null;
	ExecuteForward(g_fw[fwTerRemovePlayer], g_fw[fwReturn], id, tempTer, g_tempTerritory[territory_NumPlayers]);
	ArraySetArray(g_territoryList, tempTer, g_tempTerritory);
	return true;
}

//native bool:bb_ter_unclaimBlock(ent);
public bool:_unclaimBlock(plugin, params) {
	if (params != 1) {
		return false;
	}
	
	return unclaimBlock(get_param(1));
}

bool:unclaimBlock(ent) {
	new territory = GetBlockClaimer(ent);
	if (territory == null) {
		return false;
	}
	
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	for (new i = 0; i < MAX_TER_CLAIM; i++) {
		if (g_tempTerritory[territory_Claimed][i] != ent) {
			continue;
		}
		
		UnclaimBlock(ent);
		g_tempTerritory[territory_Claimed][i] = 0;
		g_tempTerritory[territory_NumClaimed]--;
		for (new i = 1; i <= cellbits; i++) {
			if (flagGet(g_tempTerritory[territory_Players],i)) {
				client_print(i, print_center, "%L", i, "TER_CLAIM_LOST", g_tempTerritory[territory_NumClaimed], MAX_ALLOWED_CLAIM);
			}
		}
		
		ArraySetArray(g_territoryList, territory, g_tempTerritory);
		return true;
	}
	
	return false;
}

//native bool:bb_ter_claimBlock(terEnt, ent);
public _claimBlock(plugin, params) {
	if (params != 2) {
		return false;
	}
	
	new ent = get_param(2);
	unclaimBlock(ent);
	new territory = GetChild(get_param(1));
	new maxClaim = MAX_ALLOWED_CLAIM;
	ArrayGetArray(g_territoryList, territory, g_tempTerritory);
	if (g_tempTerritory[territory_NumClaimed] < maxClaim) {
		for (new i = 0; i < MAX_TER_CLAIM; i++) {
			if (g_tempTerritory[territory_Claimed][i]) {
				continue;
			}
			
			g_tempTerritory[territory_Claimed][i] = ent;
			break;
		}
		
		g_tempTerritory[territory_NumClaimed]++;
		ClaimBlock(ent,territory);
		for (new i = 1; i <= cellbits; i++) {
			if (flagGet(g_tempTerritory[territory_Players],i)) {
				client_print(i, print_center, "%L", i, "TER_CLAIM_NEW", g_tempTerritory[territory_NumClaimed], maxClaim);
			}
		}
		
		ArraySetArray(g_territoryList, territory, g_tempTerritory);
		return true;
	}
	
	for (new i = 1; i <= cellbits; i++) {
		if (flagGet(g_tempTerritory[territory_Players],i)) {
			client_print(i, print_center, "%L", i, "TER_CLAIM_MAX", maxClaim);
		}
	}	
	
	return false;
}

//native bool:bb_ter_canMoveBlock(id, ent);
public bool:_canMoveBlock(plugin, params) {
	if (params != 2) {
		return false;
	}
	
	new territory = GetBlockClaimer(get_param(2));
	if (territory == null) {
		return true;
	}
	
	return territory == g_curTerritory[get_param(1)];
}

//native bb_ter_getUserTerritory(id);
public _getUserTerritory(plugin, params) {
	if (params != 1) {
		return null;
	}
	
	return g_curTerritory[get_param(1)];
}

//native bb_ter_formatPartnerNames(id, string[], length);
public _formatPartnerNames(plugin, params) {
	if (params != 3) {
		return;
	}
	
	new id = get_param(1);
	if (g_curTerritory[id] == null) {
		return;
	}
	
	new len = 0;
	static szName[32];
	static szTemp[128];
	ArrayGetArray(g_territoryList, g_curTerritory[id], g_tempTerritory);
	for (new i = 1; i <= cellbits; i++) {
		if (i != id && flagGet(g_tempTerritory[territory_Players],i)) {
			get_user_name(i, szName, 31);
			len += formatex(szTemp[len], 127-len, "%s, ", szName);
		}
	}
	
	if (len) {
		szTemp[len-2] = '^0';
	}
	
	set_string(2, szTemp, get_param(3));
}