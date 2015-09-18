#if defined _plugin_t_included
	#endinput
#endif
#define _plugin_t_included

#define plugin_Name_length		31
#define plugin_Desc_length		127
#define plugin_Version_length	15

#define BB_PLUGIN: any:
enum BB_PLUGIN:plugin_t {
	plugin_Name[plugin_Name_length+1],
	plugin_Desc[plugin_Desc_length+1],
	plugin_Version[plugin_Version_length+1]
};