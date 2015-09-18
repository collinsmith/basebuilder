#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <cvar_util>
#include <cs_maxspeed_api>

#include "include/bb/bb_core.inc"
#include "include/bb/classes/class_t.inc"
#include "include/bb/bb_playermodels.inc"
#include "include/bb/bb_handmodels.inc"
#include "include/bb/bb_zombies.inc"
#include "include/bb/bb_colorchat.inc"
#include "include/bb/bb_commands.inc"
#include "include/bb/bb_game.inc"

#define PLUGIN_VERSION "0.0.1"

#define GRAVITY_BARRIER_MIN -10.0
#define GRAVITY_BARRIER_MAX 10.0

static Array:g_classList;
static Trie:g_classTrie;
static g_classNum;

static BB_CLASS:g_curTempClass;
static g_tempClass[class_t];

static BB_CLASS:g_curClass[MAX_PLAYERS+1] = { BB_CLASS:null, ... };
static BB_CLASS:g_nextClass[MAX_PLAYERS+1] = { BB_CLASS:null, ... };

static Float:g_fGravity;

static g_classMenu = null;
static g_classMenuItemHandle;

static g_flagNextClassSet;

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Classes]", "Adds zombie classes into Base Builder", PLUGIN_VERSION);
	
	g_classList = ArrayCreate(class_t, 8);
	g_classTrie = TrieCreate();
	g_classNum = 0;
	g_curTempClass = BB_CLASS:null;
	
	register_dictionary("common.txt");g_classMenuItemHandle
	g_classMenu = menu_create("Choose a class:", "classMenuHandle");
	g_classMenuItemHandle = menu_makecallback("classMenuItemHandle");
}

public bb_fw_init_post() {
	bb_command_register("class", "fwCommandClass", "abcef", "Opens the class menu");
	bb_command_register("changeclass", "fwCommandClass");
}

public fwCommandClass(id) {
	showClassMenu(id, true);
}

public plugin_init() {
	new g_pCvar = get_cvar_pointer("sv_gravity");
	CvarCache(g_pCvar, CvarType_Float, g_fGravity);
}

public plugin_natives() {
	register_library("BB_Classes");
	
	register_native("bb_class_registerClass", "_registerClass", 0);
	register_native("bb_class_getClassNum", "_getClassNum", 0);
	register_native("bb_class_refresh", "_refresh", 0);
	
	register_native("bb_class_getClassName", "_getClassName", 0);
	register_native("bb_class_getClassHealth", "_getClassHealth", 0);
	
	register_native("bb_class_getUserClass", "_getUserClass", 0);
	register_native("bb_class_getUserNextClass", "_getUserNextClass", 0);
	register_native("bb_class_setUserNextClass", "_setUserNextClass", 0);
	
	register_native("bb_class_showClassMenu", "_showClassMenu", 0);
}

public client_disconnect(id) {
	g_curClass[id] = BB_CLASS:null;
	g_nextClass[id] = BB_CLASS:null;
	flagUnset(g_flagNextClassSet,id);
}

public bb_fw_zm_cure(id, curer) {
	g_curClass[id] = BB_CLASS:null;
	flagUnset(g_flagNextClassSet,id);
}

public bb_fw_zm_infect(id, infector) {
	flagUnset(g_flagNextClassSet,id);
}

public bb_fw_zm_refresh(id, bool:isZombie) {
	if (isZombie) {
		refresh(id);
	} else {
		setUserHealth(id, 100.0);
		setUserGravity(id, 1.0);
		cs_set_player_maxspeed_auto(id, 1.0);
		bb_mdl_resetModel(id);
		bb_handmdl_resetModel(id);
	}
}

//native bb_class_refresh(id);
public _refresh(plugin, params) {
	if (params != 1) {
		return;
	}
	
	new id = get_param(1);
	if (!bb_zm_isUserZombie(id)) {
		return;
	}
	
	refresh(id);
}

refresh(id) {
	if (flagGet(g_flagNextClassSet,id) && bb_game_getGameState() == BB_GAMESTATE_RELEASE) {
		return;
	}
	
	if (g_nextClass[id] == BB_CLASS:null) {
		applyClass(id, BB_CLASS:0);
		showClassMenu(id, false);
		return;
	}
	
	applyClass(id, g_nextClass[id]);
	flagSet(g_flagNextClassSet,id);
}

applyClass(id, BB_CLASS:class) {
	reloadClass(class);
	setUserHealth(id, g_tempClass[class_Health]);
	setUserGravity(id, g_tempClass[class_Gravity]);
	cs_set_player_maxspeed_auto(id, g_tempClass[class_Speed]);
	bb_mdl_setModel(id, BB_MODEL:g_tempClass[class_Model]);
	bb_handmdl_setModel(id, BB_HANDMODEL:g_tempClass[class_HandModel]);
	
	g_curClass[id] = class;
}

reloadClass(class) {
	if (g_curTempClass == class) {
		return;
	}
	
	g_curTempClass = class;
	ArrayGetArray(g_classList, g_curTempClass, g_tempClass);
}

/*native BB_CLASS:bb_class_registerClass(
	const name[],
	const description[],
	const model[],
	const handModel[] = "v_bloodyhands",
	const Float:health = 2000.0,
	const Float:speed = 1.0,
	const Float:gravity = 1.0,
	const cost = 0,
	const levelReq = 0
);*/
public BB_CLASS:_registerClass(plugin, params) {
	if (params != 9) {
		return BB_CLASS:null;
	}
	
	get_string(1, g_tempClass[class_Name], class_Name_length);
	
	new szTemp[class_Name_length+1];
	copy(szTemp, class_Name_length, g_tempClass[class_Name]);
	new BB_CLASS:class = classExists(szTemp);
	if (class != BB_CLASS:null) {
		return class;
	}
	
	get_string(2, g_tempClass[class_Desc], class_Desc_length);
	
	new szModels[32];
	get_string(3, szModels, 31);
	g_tempClass[class_Model] = any:bb_mdl_registerModel(szModels);
	if (g_tempClass[class_Model] == null) {
		return BB_CLASS:null;
	}
	
	get_string(4, szModels, 31);
	g_tempClass[class_HandModel] = any:bb_handmdl_registerModel(szModels);
	if (g_tempClass[class_HandModel] == null) {
		return BB_CLASS:null;
	}
	
	g_tempClass[class_Health] = any:get_param_f(5);
	g_tempClass[class_Speed] = any:get_param_f(6);
	g_tempClass[class_Gravity] = any:get_param_f(7);
	g_tempClass[class_Cost] = get_param(8);
	g_tempClass[class_LevelReq] = get_param(9);
	
	new szItemConcatonation[64];
	formatex(szItemConcatonation, 63, "%s [\y%s\w]", g_tempClass[class_Name], g_tempClass[class_Desc]);
	menu_additem(g_classMenu, szItemConcatonation, _, _, g_classMenuItemHandle);
	
	ArrayPushArray(g_classList, g_tempClass);
	TrieSetCell(g_classTrie, szTemp, g_classNum);
	g_curTempClass = g_classNum;
	g_classNum++;
	return g_curTempClass;
}

BB_CLASS:classExists(className[]) {
	new class;
	strtolower(className);
	if (TrieGetCell(g_classTrie, className, class)) {
		return BB_CLASS:class;
	}
	
	return BB_CLASS:null;
}

//native bb_class_getClassName(BB_CLASS:class, string[], length);
public _getClassName(plugin, params) {
	if (params != 3) {
		return;
	}
	
	ArrayGetArray(g_classList, get_param(1), g_tempClass);
	set_string(2, g_tempClass[class_Name], get_param(3));
}

//native bb_class_getClassNum();
public _getClassNum(plugin, params) {
	if (params != 0) {
		return 0;
	}
	
	return g_classNum;
}

//native BB_CLASS:bb_class_getUserClass(id);
public BB_CLASS:_getUserClass(plugin, params) {
	if (params != 1) {
		return BB_CLASS:null;
	}
	
	return g_curClass[get_param(1)];
}

//native BB_CLASS:bb_class_getUserNextClass(id);
public BB_CLASS:_getUserNextClass(plugin, params) {
	if (params != 1) {
		return BB_CLASS:null;
	}
	
	return g_nextClass[get_param(1)];
}

//native BB_CLASS:bb_class_setUserNextClass(id, BB_CLASS:class);
public BB_CLASS:_setUserNextClass(plugin, params) {
	if (params != 1) {
		return BB_CLASS:null;
	}
	
	return setUserNextClass(get_param(1), BB_CLASS:get_param(2));
}

setUserNextClass(id, BB_CLASS:class) {
	new BB_CLASS:oldNextClass = g_nextClass[id];
	g_nextClass[id] = class;
	
	if (bb_game_getGameState() == BB_GAMESTATE_BUILDPHASE || bb_game_getGameState() == BB_GAMESTATE_PREPPHASE) {
		applyClass(id, g_nextClass[id]);
	} else if (!flagGet(g_flagNextClassSet,id) && g_nextClass[id] != g_curClass[id]) {
		applyClass(id, g_nextClass[id]);
		flagSet(g_flagNextClassSet,id);
	}
	
	return oldNextClass;
}

setUserHealth(id, Float:health) {
	set_pev(id, pev_health, health);
}

//native Float:bb_class_getClassHealth(BB_CLASS:class);
public Float:_getClassHealth(plugin, params) {
	if (params != 1) {
		return Float:null;
	}
	
	reloadClass(BB_CLASS:get_param(1));
	return g_tempClass[class_Health];
}

setUserGravity(id, Float:gravity) {
	if (GRAVITY_BARRIER_MIN <= gravity <= GRAVITY_BARRIER_MAX) {
		set_pev(id, pev_gravity, gravity);
	} else {
		set_pev(id, pev_gravity, gravity/g_fGravity);
	}
}

//native bb_class_showClassMenu(id, bool:exitable);
public _showClassMenu(plugin, params) {
	if (params != 2) {
		return;
	}
	
	showClassMenu(get_param(1), bool:get_param(2));
}

showClassMenu(id, bool:exitable) {
	if (!bb_zm_isUserZombie(id)) {
		return;
	}
	
	new trash;
	if (player_menu_info(id, trash, trash)) {
		return;
	}
	
	new szMenu[32];
	formatex(szMenu, 31, "%L", id, "CLASS_MENU_NAME");
	menu_setprop(g_classMenu, MPROP_TITLE, szMenu);
	
	formatex(szMenu, 31, "%L", id, "BACK");
	menu_setprop(g_classMenu, MPROP_BACKNAME, szMenu);
	formatex(szMenu, 31, "%L", id, "MORE");
	menu_setprop(g_classMenu, MPROP_NEXTNAME, szMenu);
	if (exitable) {
		formatex(szMenu, 31, "%L", id, "EXIT");
		menu_setprop(g_classMenu, MPROP_EXITNAME, szMenu);
	} else {
		menu_setprop(g_classMenu, MPROP_EXIT, MEXIT_NEVER);
	}
	
	menu_display(id, g_classMenu);
}

public classMenuItemHandle(id, menu, class) {
	/*ArrayGetArray(g_classList, class, g_tempClass);
	if (bb_credits_getUserRank(id) < g_tempClass[class_LevelReq]) {
		return ITEM_DISABLED;
	}*/
	
	return ITEM_ENABLED;
}

public classMenuHandle(id, menu, class) {
	if (class == MENU_EXIT) {
		return PLUGIN_HANDLED;
	}
	
	ArrayGetArray(g_classList, class, g_tempClass);
	setUserNextClass(id, BB_CLASS:class);
	bb_printColor(id, "%L", id, "CLASS_SELECTED", g_tempClass[class_Name]);
	return PLUGIN_HANDLED;
}