#if defined _bb_precache_included
	#endinput
#endif
#define _bb_precache_included

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

stock bool:bb_precachePlayerModel(model[]) {
	new temp[64];
	formatex(temp, 63, "models/player/%s/%s.mdl", model, model);
	return bb_precache(temp);
}

stock bool:bb_precacheModel(model[]) {
	if (file_exists(model)) {
		engfunc(EngFunc_PrecacheModel, model);
		return true;
	}
	
	return false;
}

stock bool:bb_precacheSound(sound[]) {
	new temp[64];
	formatex(temp, 63, "sound/%s", sound);
	return bb_precache(temp);
}

stock bool:bb_precache(file[]) {
	if (file_exists(file)) {
		engfunc(EngFunc_PrecacheGeneric, file);
		return true;
	}
	
	return false;
}