#include <amxmodx>
#include <cs_weap_models_api>

#include "include/bb/bb_core.inc"
#include "include/bb/bb_precache.inc"
#include "include/bb/bb_handmodels_const.inc"

#define PLUGIN_VERSION "0.0.1"

static Array:g_modelList;
static Trie:g_modelTrie;
static g_modelNum;

static g_szModel[32];
static g_szTempModel[128];

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Hand Models]", "Manages the hand models", PLUGIN_VERSION);
	
	g_modelList = ArrayCreate(32, 8);
	g_modelTrie = TrieCreate();
	g_modelNum = 0;
}

public plugin_natives() {
	register_library("BB_HandModels");
	
	register_native("bb_handmdl_registerModel", "_registerModel", 0);
	register_native("bb_handmdl_getModelByName", "_getModelByName", 0);
	
	register_native("bb_handmdl_setModel", "_setModel", 0);
	register_native("bb_handmdl_resetModel", "_resetModel", 0);
}

public bb_fw_zm_infect(id, infector) {
	cs_set_player_weap_model(id, CSW_KNIFE, "");
}

public bb_fw_zm_cure(id, curer) {
	cs_reset_player_weap_model(id, CSW_KNIFE);
}

//native BB_HANDMODEL:bb_handmdl_registerModel(const model[]);
public BB_HANDMODEL:_registerModel(plugin, params) {
	if (params != 1) {
		return BB_HANDMODEL:null;
	}
	
	get_string(1, g_szModel, 31);
	if (g_szModel[0] == '^0') {
		return BB_HANDMODEL:null;
	}
	
	if (g_modelList == Invalid_Array) {
		return BB_HANDMODEL:null;
	}
	
	new szTemp[32];
	copy(szTemp, 31, g_szModel);
	new BB_HANDMODEL:model = modelExists(szTemp);
	if (model != BB_HANDMODEL:null) {
		return model;
	}
	
	formatex(g_szTempModel, 127, "models/%s%s.mdl", BB_HANDMODEL_PATH, g_szModel);
	if (!bb_precacheModel(g_szTempModel)) {
		return ZP_HANDMODEL:null;
	}
	
	ArrayPushString(g_modelList, g_szModel);
	TrieSetCell(g_modelTrie, szTemp, g_modelNum);
	g_modelNum++;
	return BB_HANDMODEL:(g_modelNum-1);
}

//native BB_HANDMODEL:bb_handmdl_getModelByName(const model[]);
public BB_HANDMODEL:_getModelByName(plugin, params) {
	if (params != 1) {
		return BB_HANDMODEL:null;
	}
	
	get_string(1, g_szTempModel, 31);
	return modelExists(g_szTempModel);
}

BB_HANDMODEL:modelExists(modelName[]) {
	new model;
	strtolower(modelName);
	if (TrieGetCell(g_modelTrie, modelName, model)) {
		return BB_HANDMODEL:model;
	}
	
	return BB_HANDMODEL:null;
}

//native bb_handmdl_setModel(id, BB_HANDMODEL:model);
public _setModel(plugin, params) {
	if (params != 2) {
		return;
	}
	
	ArrayGetString(g_modelList, get_param(2), g_szModel, 31);
	formatex(g_szTempModel, 127, "models/%s%s.mdl", BB_HANDMODEL_PATH, g_szModel);
	cs_set_player_view_model(get_param(1), CSW_KNIFE, g_szTempModel);
}

//native bb_handmdl_resetModel(id);
public _resetModel(plugin, params) {
	if (params != 1) {
		return;
	}
	
	cs_reset_player_view_model(get_param(1), CSW_KNIFE);
}