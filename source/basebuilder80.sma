#include <amxmodx>
#include <amxmisc>
#include <cvar_util>
#include <fakemeta>
#include <engine>

#include "include/bb/classes/plugin_t.inc"
#include "include/bb/classes/setting_t.inc"
#include "include/bb/bb_core_const.inc"
#include "include/bb/bb_classes.inc"

static Array:g_pluginList;
static g_pluginNum;

static Array:g_settingList;
static Trie:g_settingTrie;
static g_settingNum;

enum _:eForwardedEvents {
	fwReturn,
	fwPluginInit
};

static g_fw[eForwardedEvents];

static g_szModName[32];

public plugin_precache() {	
	register_plugin(BB_PLUGIN_NAME, BB_PLUGIN_VERSION, "Tirant");
	
	new szBBHomeDir[64];
	bb_getHomeDir(szBBHomeDir, 63);
	mkdir(szBBHomeDir);
	
	server_print("================================================================");
	server_print("Launching Base Builder v%s written by Tirant...", BB_PLUGIN_VERSION);
	
	g_pluginList = ArrayCreate(plugin_t, 16);
	g_pluginNum = 0;
	
	g_settingList = ArrayCreate(setting_t, 8);
	g_settingTrie = TrieCreate();
	g_settingNum = 0;
	
	g_fw[fwPluginInit] = CreateMultiForward("bb_fw_init", ET_IGNORE);
	ExecuteForward(g_fw[fwPluginInit], g_fw[fwReturn]);
	DestroyForward(g_fw[fwPluginInit]);
	g_fw[fwPluginInit] = null;
	
	new fwPluginInitPost = CreateMultiForward("bb_fw_init_post", ET_IGNORE);
	ExecuteForward(fwPluginInitPost, g_fw[fwReturn]);
	DestroyForward(fwPluginInitPost);
	fwPluginInitPost = null;
		
	server_print("DONE");
	server_print("================================================================");
	
	if (bb_class_getClassNum() == 0) {
		set_fail_state("No classes were loaded, plugin shutting down.");
	}
}

public plugin_init() {
	register_plugin(BB_PLUGIN_NAME, BB_PLUGIN_VERSION, "Tirant");
	CvarRegister("bb_version", BB_PLUGIN_VERSION, "The current version of Base Builder being used", FCVAR_SPONLY|FCVAR_SERVER);
	set_cvar_string("bb_version", BB_PLUGIN_VERSION);
	
	new len = formatex(g_szModName, 31, "%s", BB_PLUGIN_NAME);
	formatex(g_szModName[len], 4, " %s", BB_PLUGIN_VERSION);
	register_forward(FM_GetGameDescription, "fw_getGameDescription");
}

public plugin_cfg() {
	new szConfigsDir[64];
	get_configsdir(szConfigsDir, 63);
	server_cmd("exec %s/basebuilder.cfg", szConfigsDir);
}

public plugin_natives() {
	register_library("Base_Builder_80");
	
	register_native("bb_core_registerPlugin",	"_registerPlugin",	0);
	register_native("bb_core_getPluginList",	"_getPluginList",	0);
	register_native("bb_core_getPluginNum",		"_getPluginNum",	0);
	
	register_native("bb_core_registerSetting",		"_registerSetting",	0);
}

public fw_getGameDescription() {
	forward_return(FMV_STRING, g_szModName)
	return FMRES_SUPERCEDE;
}

//native Array:bb_core_getPluginList();
public Array:_getPluginList(plugin, params) {
	if (params != 0) {
		return Array:null;
	}
	
	return g_pluginList;
}

//native bb_core_getPluginNum();
public _getPluginNum(plugin, params) {
	if (params != 0) {
		return null;
	}
	
	return g_pluginNum;
}

//native bb_core_registerPlugin(const name[], const description[], const version[]);
public BB_PLUGIN:_registerPlugin(plugin, params) {
	if (params != 2) {
		return BB_PLUGIN:null;
	}
	
	if (g_fw[fwPluginInit] == null) {
		return BB_PLUGIN:null;
	}
	
	new tempPlugin[plugin_t];
	get_string(1, tempPlugin[plugin_Name], plugin_Name_length);
	get_string(2, tempPlugin[plugin_Desc], plugin_Desc_length);
	get_string(3, tempPlugin[plugin_Version], plugin_Version_length);
	
	server_print("Found %s", tempPlugin[plugin_Name]);
	
	ArrayPushArray(g_pluginList, tempPlugin);
	g_pluginNum++;
	return BB_PLUGIN:(g_pluginNum-1);
}

public BB_SETTING:_registerSetting(plugin, params) {
	if (params != 2) {
		return BB_SETTING:null;
	}
	
	if (g_fw[fwPluginInit] == null) {
		return BB_SETTING:null;
	}
	
	new tempSetting[setting_t];
	get_string(1, tempSetting[setting_Name], setting_Name_length);
	tempSetting[setting_Default] = get_param(2);
	
	ArrayPushArray(g_settingList, tempSetting);
	g_settingNum++;
	return BB_SETTING:(g_settingNum-1);
}