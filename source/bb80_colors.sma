#pragma dynamic 2048

#include <amxmodx>
#include <amxmisc>
#include <cvar_util>

#include "include/bb/classes/color_t.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_game.inc"
#include "include/bb/bb_zombies.inc"
#include "include/bb/bb_commands.inc"
#include "include/bb/bb_colorchat.inc"

#define PLUGIN_VERSION "0.0.1"

static Array:g_colorList;
static Trie:g_colorTrie;
static g_colorNum;

static g_tempColor[color_t];

static BB_COLOR:g_curColor[MAX_PLAYERS+1] = { BB_COLOR:null, ... };

static g_iColorOwners;

static g_colorMenu = null;
static g_colorMenuItemCallback;

enum _:eForwardedEvents {
	fwReturn,
	fwColorSelected
};

static g_fw[eForwardedEvents];

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Colors]", "Manages the users' colors", PLUGIN_VERSION);
	
	g_colorList = ArrayCreate(color_t, 32);
	g_colorTrie = TrieCreate();
	g_colorNum = 0;
	
	register_dictionary("common.txt");
	g_colorMenu = menu_create("Choose a color:", "colorMenuHandle");
	g_colorMenuItemCallback = menu_makecallback("colorMenuItemCallback");
}

public bb_fw_init_post() {
	bb_command_register("random", "fwCommandRandom", "abde", "Randomizes your color");
	
	bb_command_register("colors", "fwCommandColorMenu", "abde", "Opens the menu to change colors");
	bb_command_register("changecolor", "fwCommandColorMenu");
	
	bb_command_register("color", "fwCommandMyColor", "abde", "Tells you what your color is currently");
	bb_command_register("mycolor", "fwCommandMyColor");
	
	bb_command_register("whois", "fwCommandWhois", "abcdef", "Checks whoever is a specified color");
}

public plugin_init() {
	g_iColorOwners = CvarRegister("bb_color_colorOwners", "1", "1-colors limited to 1 person, 0-no ownership", _, true, 0.0, true, 1.0);
	CvarCache(g_iColorOwners, CvarType_Int, g_iColorOwners);
	
	g_fw[fwColorSelected] = CreateMultiForward("bb_fw_color_colorSelected", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives() {
	register_library("BB_Colors");
	
	register_native("bb_color_registerColor", "_registerColor", 0);
	register_native("bb_color_getColorNum", "_getColorNum", 0);
	register_native("bb_color_getColorByName", "_getColorByName", 0);
	register_native("bb_color_getColorName", "_getColorName", 0);
	register_native("bb_color_getColor", "_getColor", 0);
	register_native("bb_color_showColorMenu", "_showColorMenu", 0);
	
	register_native("bb_color_getUserColor", "_getUserColor", 0);
	register_native("bb_color_getColorOwner", "_getColorOwner", 0);
}

public fwCommandRandom(id, player, message[]) {
	giveRandomColor(id);
	bb_printColor(id, "%L", id, "COLOR_RANDOM", g_tempColor[color_Name]);
}

public fwCommandColorMenu(id, player, message[]) {
	showColorMenu(id, true);
}

public fwCommandMyColor(id, player, message[]) {
	ArrayGetArray(g_colorList, g_curColor[id], g_tempColor);
	bb_printColor(id, "%L", id, "COLOR_CURRENT", g_tempColor[color_Name]);
}

public fwCommandWhois(id, player, message[]) {
	if (!g_iColorOwners) {
		return;
	}
	
	new BB_COLOR:color = colorExists(message);
	if (color != BB_COLOR:null) {
		ArrayGetArray(g_colorList, color, g_tempColor);
		if (g_tempColor[color_Owner]) {
			new szPlayerName[32];
			get_user_name(g_tempColor[color_Owner], szPlayerName, 31)
			bb_printColor(id, "%L", id, "COLOR_OWNER", szPlayerName, g_tempColor[color_Name]);
		} else {
			bb_printColor(id, "%L", id, "COLOR_NONE", g_tempColor[color_Name]);
		}
	} else {
		bb_printColor(id, "%L", id, "COLOR_INVALID", message);
	}
}

public client_disconnect(id) {
	g_curColor[id] = BB_COLOR:null;
}

giveRandomColor(id) {
	if (g_curColor[id] != BB_COLOR:null) {
		ArrayGetArray(g_colorList, g_curColor[id], g_tempColor);
		g_tempColor[color_Owner] = 0;
		ArraySetArray(g_colorList, g_curColor[id], g_tempColor);
	}
	
	do {
		g_curColor[id] = random(g_colorNum);
		ArrayGetArray(g_colorList, g_curColor[id], g_tempColor);
	} while ((g_iColorOwners && g_tempColor[color_Owner]) || !access(id, g_tempColor[color_AdminFlags]));
	
	changeColor(id, g_curColor[id]);
	ExecuteForward(g_fw[fwColorSelected], g_fw[fwReturn], id, g_curColor[id]);
}

public bb_fw_zm_refresh(id, bool:isZombie) {
	if (isZombie || g_curColor[id] != null) {
		return;
	} else if (bb_game_getGameState() != BB_GAMESTATE_BUILDPHASE && bb_game_getGameState() != BB_GAMESTATE_ROUNDEND) {
		giveRandomColor(id);
		return;
	}
	
	giveRandomColor(id);
	showColorMenu(id, false);
}

public bb_fw_zm_infect(id, infector) {
	if (g_curColor[id] != null) {
		if (g_iColorOwners) {
			ArrayGetArray(g_colorList, g_curColor[id], g_tempColor);
			g_tempColor[color_Owner] = 0;
			ArraySetArray(g_colorList, g_curColor[id], g_tempColor);
		}
		
		g_curColor[id] = BB_COLOR:null;
	}
}

//native BB_COLOR:bb_color_registerColor(const name[], const Float:color[3], const Float:renderamt, const adminFlags);
public BB_COLOR:_registerColor(plugin, params) {
	if (params != 4) {
		return BB_COLOR:null;
	}
	
	get_string(1, g_tempColor[color_Name], color_Name_length);
	
	new szTemp[color_Name_length+1];
	copy(szTemp, color_Name_length, g_tempColor[color_Name]);
	new BB_COLOR:color = colorExists(szTemp);
	if (color != BB_COLOR:null) {
		return color;
	}
	
	get_array_f(2, g_tempColor[color_Color], 3);
	g_tempColor[color_RenderAmt] = _:get_param_f(3);
	g_tempColor[color_AdminFlags] = get_param(4);
	
	menu_additem(g_colorMenu, g_tempColor[color_Name], _, g_tempColor[color_AdminFlags], g_colorMenuItemCallback);
	
	ArrayPushArray(g_colorList, g_tempColor);
	TrieSetCell(g_colorTrie, szTemp, g_colorNum);
	g_colorNum++;
	return BB_COLOR:(g_colorNum-1);
}

//native BB_COLOR:bb_color_getColorByName(const colorName[]);
public BB_COLOR:_getColorByName(plugin, params) {
	if (params != 1) {
		return BB_COLOR:null;
	}
	
	new szTemp[color_Name_length+1];
	get_string(1, szTemp, color_Name_length);
	return colorExists(szTemp);
}

BB_COLOR:colorExists(colorName[]) {
	new color;
	strtolower(colorName);
	if (TrieGetCell(g_colorTrie, colorName, color)) {
		return BB_COLOR:color;
	}
	
	return BB_COLOR:null;
}

//native bb_color_getColorName(BB_COLOR:color, string[], length);
public _getColorName(plugin, params) {
	if (params != 3) {
		return;
	}
	
	ArrayGetArray(g_colorList, get_param(1), g_tempColor);
	set_string(2, g_tempColor[color_Name], get_param(3));
}

//native bb_color_getColor(BB_COLOR:color, Float:color[3], Float:renderamt);
public _getColor(plugin, params) {
	if (params != 3) {
		return 0;
	}
	
	ArrayGetArray(g_colorList, get_param(1), g_tempColor);
	set_array_f(2, g_tempColor[color_Color], 3);
	set_float_byref(3, g_tempColor[color_RenderAmt]);
	return g_tempColor[color_Owner];
}

//native bb_color_showColorMenu(id, bool:exitable);
public _showColorMenu(plugin, params) {
	if (params != 2) {
		return;
	}
	
	showColorMenu(get_param(1), bool:get_param(2));
}

showColorMenu(id, bool:exitable) {
	if (bb_zm_isUserZombie(id)) {
		return;
	}
	
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	new szMenu[32];
	formatex(szMenu, 31, "%L", id, "COLOR_MENU_NAME");	
	menu_setprop(g_colorMenu, MPROP_TITLE, szMenu);
	
	formatex(szMenu, 31, "%L", id, "BACK");
	menu_setprop(g_colorMenu, MPROP_BACKNAME, szMenu);
	formatex(szMenu, 31, "%L", id, "MORE");
	menu_setprop(g_colorMenu, MPROP_NEXTNAME, szMenu);
	if (exitable) {
		formatex(szMenu, 31, "%L", id, "EXIT");
		menu_setprop(g_colorMenu, MPROP_EXITNAME, szMenu);
	} else {
		menu_setprop(g_colorMenu, MPROP_EXIT, MEXIT_NEVER);
	}
	
	menu_display(id, g_colorMenu);
}

public colorMenuItemCallback(id, menu, color) {
	ArrayGetArray(g_colorList, color, g_tempColor);
	if (g_iColorOwners && g_tempColor[color_Owner] && g_tempColor[color_Owner] != id) {
		return ITEM_IGNORE;
	}
	
	if (!access(id, g_tempColor[color_AdminFlags])) {
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}

public colorMenuHandle(id, menu, color) {
	if (color == MENU_EXIT) {
		return PLUGIN_HANDLED;
	}
	
	changeColor(id, color);
	ArrayGetArray(g_colorList, color, g_tempColor);
	bb_printColor(id, "%L", id, "COLOR_SELECT", g_tempColor[color_Name]);
	ExecuteForward(g_fw[fwColorSelected], g_fw[fwReturn], id, color);
	return PLUGIN_HANDLED;
}

changeColor(id, BB_COLOR:color) {
	if (g_iColorOwners && g_curColor[id] > BB_COLOR:null) {
		ArrayGetArray(g_colorList, g_curColor[id], g_tempColor);
		g_tempColor[color_Owner] = 0;
		ArraySetArray(g_colorList, g_curColor[id], g_tempColor);
	}
	
	g_curColor[id] = color;
	ArrayGetArray(g_colorList, color, g_tempColor);
	g_tempColor[color_Owner] = id;
	ArraySetArray(g_colorList, color, g_tempColor);
}

//native BB_COLOR:bb_color_getUserColor(id);
public BB_COLOR:_getUserColor(plugin, params) {
	if (params != 1) {
		return BB_COLOR:null;
	}
	
	return g_curColor[get_param(1)];
}

//native bb_color_getColorOwner(BB_COLOR:color);
public _getColorOwner(plugin, params) {
	if (params != 1) {
		return 0;
	}
	
	ArrayGetArray(g_colorList, get_param(1), g_tempColor);
	return g_tempColor[color_Owner];
}

//native bb_color_getColorNum();
public _getColorNum(plugin, params) {
	if (params != 0) {
		return 0;
	}
	
	return g_colorNum;
}