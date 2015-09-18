#include <amxmodx>
#include <cs_player_models_api>

#include "include/bb/bb_core.inc"
#include "include/bb/bb_precache.inc"

#define PLUGIN_VERSION "0.0.1"

static Array:g_modelList;
static Trie:g_modelTrie;
static g_modelNum;

static g_szTempModel[32];

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Player Models]", "Manages the player models", PLUGIN_VERSION);
	
	g_modelList = ArrayCreate(32, 8);
	g_modelTrie = TrieCreate();
	g_modelNum = 0;
}

public plugin_natives() {
	register_library("BB_PlayerModels");
	
	register_native("bb_mdl_registerModel", "_registerModel", 0);
	register_native("bb_mdl_getModelByName", "_getModelByName", 0);
	
	register_native("bb_mdl_setModel", "_setModel", 0);
	register_native("bb_mdl_resetModel", "_resetModel", 0);
}

//native BB_MODEL:bb_mdl_registerModel(const model[]);
public BB_MODEL:_registerModel(plugin, params) {
	if (params != 1) {
		return BB_MODEL:null;
	}
	
	get_string(1, g_szTempModel, 31);
	if (g_szTempModel[0] == '^0') {
		return BB_MODEL:null;
	}
	
	if (g_modelList == Invalid_Array) {
		return BB_MODEL:null;
	}
	
	new szModel[32];
	copy(szModel, 31, g_szTempModel);
	new BB_MODEL:model = modelExists(szModel);
	if (model != BB_MODEL:null) {
		return model;
	}
	
	if (!bb_precachePlayerModel(g_szTempModel)) {
		return BB_MODEL:null;
	}
	
	ArrayPushString(g_modelList, g_szTempModel);
	TrieSetCell(g_modelTrie, szModel, g_modelNum);
	g_modelNum++;
	return BB_MODEL:(g_modelNum-1);
}

//native BB_MODEL:bb_mdl_getModelByName(const model[]);
public BB_MODEL:_getModelByName(plugin, params) {
	if (params != 1) {
		return BB_MODEL:null;
	}
	
	get_string(1, g_szTempModel, 31);
	return modelExists(g_szTempModel);
}

BB_MODEL:modelExists(modelName[]) {
	new model;
	strtolower(modelName);
	if (TrieGetCell(g_modelTrie, modelName, model)) {
		return BB_MODEL:model;
	}
	
	return BB_MODEL:null;
}

//native bb_mdl_setModel(id, BB_MODEL:model);
public _setModel(plugin, params) {
	if (params != 2) {
		return;
	}
	
	ArrayGetString(g_modelList, get_param(2), g_szTempModel, 31);
	cs_set_player_model(get_param(1), g_szTempModel);
}

//native bb_mdl_resetModel(id);
public _resetModel(plugin, params) {
	if (params != 1) {
		return;
	}
	
	cs_reset_player_model(get_param(1));
}