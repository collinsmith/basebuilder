#if defined _color_t_included
	#endinput
#endif
#define _color_t_included

#define color_Name_length 15

#define BB_COLOR: any:
enum BB_COLOR:color_t {
	color_Name[color_Name_length+1],
	Float:color_Color[3],
	Float:color_RenderAmt,
	color_AdminFlags,
	color_Owner
};