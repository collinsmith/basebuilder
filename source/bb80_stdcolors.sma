#include <amxmodx>

#include "include/bb/bb_core.inc"
#include "include/bb/bb_colors.inc"

#define PLUGIN_VERSION "0.0.1"

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Standard Colors]", "Registers standard colors with the color manager", PLUGIN_VERSION);
}

public bb_fw_init_post() {
	bb_color_registerColor("Red",			Float:{200.0, 000.0, 000.0},	100.0,	ADMIN_ALL);
	bb_color_registerColor("Red Orange",	Float:{255.0, 083.0, 073.0},	135.0,	ADMIN_ALL);
	bb_color_registerColor("Orange",		Float:{255.0, 117.0, 056.0},	140.0,	ADMIN_ALL);
	bb_color_registerColor("Yellow Orange",	Float:{255.0, 174.0, 066.0},	120.0,	ADMIN_ALL);
	bb_color_registerColor("Peach",			Float:{255.0, 207.0, 171.0},	140.0,	ADMIN_ALL);
	bb_color_registerColor("Yellow",		Float:{252.0, 232.0, 131.0},	125.0,	ADMIN_ALL);
	bb_color_registerColor("Lemon Yellow",	Float:{254.0, 254.0, 034.0},	100.0,	ADMIN_ALL);
	bb_color_registerColor("Jungle Green",	Float:{059.0, 176.0, 143.0},	125.0,	ADMIN_ALL);
	bb_color_registerColor("Yellow Green",	Float:{197.0, 227.0, 132.0},	135.0,	ADMIN_ALL);
	bb_color_registerColor("Green",			Float:{000.0, 150.0, 000.0},	100.0,	ADMIN_ALL);
	bb_color_registerColor("Aquamarine",	Float:{120.0, 219.0, 226.0},	125.0,	ADMIN_ALL);
	bb_color_registerColor("Baby Blue",		Float:{135.0, 206.0, 235.0},	150.0,	ADMIN_ALL);
	bb_color_registerColor("Sky Blue",		Float:{128.0, 218.0, 235.0},	090.0,	ADMIN_ALL);
	bb_color_registerColor("Blue",			Float:{000.0, 000.0, 255.0},	075.0,	ADMIN_ALL);
	bb_color_registerColor("Violet",		Float:{146.0, 110.0, 174.0},	175.0,	ADMIN_ALL);
	bb_color_registerColor("Hot Pink",		Float:{255.0, 105.0, 180.0},	150.0,	ADMIN_ALL);
	bb_color_registerColor("Magenta",		Float:{246.0, 100.0, 175.0},	175.0,	ADMIN_ALL);
	bb_color_registerColor("Mahogany",		Float:{205.0, 074.0, 076.0},	140.0,	ADMIN_ALL);
	bb_color_registerColor("Tan",			Float:{250.0, 167.0, 108.0},	140.0,	ADMIN_ALL);
	bb_color_registerColor("Light Brown",	Float:{234.0, 126.0, 093.0},	140.0,	ADMIN_ALL);
	bb_color_registerColor("Brown",			Float:{180.0, 103.0, 077.0},	165.0,	ADMIN_ALL);
	bb_color_registerColor("Gray",			Float:{149.0, 145.0, 140.0},	175.0,	ADMIN_ALL);
	bb_color_registerColor("Black",			Float:{000.0, 000.0, 000.0},	125.0,	ADMIN_ALL);
	bb_color_registerColor("White",			Float:{255.0, 255.0, 255.0},	125.0,	ADMIN_ALL);
}