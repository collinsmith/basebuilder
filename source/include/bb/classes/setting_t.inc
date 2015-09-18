#if defined _setting_t_included
	#endinput
#endif
#define _setting_t_included

#define setting_Name_length		31

#define BB_SETTING: any:
enum BB_SETTING:setting_t {
	setting_Name[setting_Name_length+1],
	setting_Default
};