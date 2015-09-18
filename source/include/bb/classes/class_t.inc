#if defined _class_t_included
	#endinput
#endif
#define _class_t_included

#define class_Name_length		31
#define class_Desc_length		127

#define BB_CLASS: any:
enum _:class_t {
	class_Name[class_Name_length+1],
	class_Desc[class_Desc_length+1],
	Float:class_Health,
	Float:class_Speed,
	Float:class_Gravity,
	BB_MODEL:class_Model,
	BB_HANDMODEL:class_HandModel,
	class_Cost,
	class_LevelReq
};