#include <amxmodx>
#include "include/md5_gamekey.inc"

#include "include/bb/bb_core.inc"
#include "include/bb/bb_credits_const.inc"

static bool:g_bValidKey;

public bb_fw_init() {
	bb_core_registerPlugin(BB_CR_PLUGIN_NAME, "Adds credit functionality into Base Builder", BB_CR_PLUGIN_VERSION);
	
	new szGameKey[34], szFilePath[32];
	get_user_ip(0, szGameKey, 33, 1);
	new len = copy(szFilePath, 31, BB_HOME_DIR);
	len += copy(szFilePath[len], 31, BB_GAME_KEY_FILE);
	g_bValidKey = gamekey_validateKey(szFilePath, szGameKey)
	if (g_bValidKey) {
		server_print("Game key validated [%s]", szGameKey);
	} else {
		set_fail_state("Invalid game key");
	}
}

public plugin_natives() {
	register_library("BB_Credits_80");
	
	register_native("bb_cr_isEnabled",	"_isEnabled", 0);
}

//native bool:bb_cr_isEnabled();
public bool:_isEnabled(plugin, params) {
	if (params != 0) {
		return false;
	}
	
	return g_bValidKey;
}