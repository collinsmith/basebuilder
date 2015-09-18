#if defined _bb_colors_included
	#endinput
#endif
#define _bb_colors_included

#pragma reqlib BB_Colors
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Colors
#endif

#include "include/bb/classes/color_t.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Called when a player is given a new color.
 * 
 * @param id			Player index who got the new color
 * @param color			Color index of color
 */
forward bb_fw_color_colorSelected(id, BB_COLOR:color);

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Registers a new colors into Base Builder.
 * 
 * @param name			Name of the color
 * @param color			RGB color code
 * @param renderamt		Render amount of this color
 * @param adminFlags	Admin flags required to use this color
 * @return				BB_COLOR index of color, BB_COLOR:null for no color
 */
native BB_COLOR:bb_color_registerColor(const name[], const Float:color[3], const Float:renderamt, const adminFlags);

/**
 * Retrieves the color index for a given color name.
 * 
 * @param name			Name of the color
 * @return				Index of this color, BB_COLOR:null for no color
 */
native BB_COLOR:bb_color_getColorByName(const name[]);

/**
 * Retrieves the name of a color.
 * 
 * @param color			Index of the color
 * @param string		String to place name into
 * @param length		Max length of result
 */
native bb_color_getColorName(BB_COLOR:color, string[], length);

/**
 * Retrieves the color information for a specified color and places
 * it in the second and third parameters. Also retrieves owner.
 * 
 * @param color			Index of the color
 * @param &rgb			RGB values of the color
 * @param &renderamt	Renderamy of the color
 * @return				The owner of this color
 */
native bb_color_getColor(BB_COLOR:color, Float:rgb[3]={0.0,0.0,0.0}, &Float:renderamt=0.0);

/**
 * Displays the colors menu to a specified player.
 * 
 * @param id			Player index to display menu to
 * @param exitable		True to make this menu exitable, otherwise false
 */
native bb_color_showColorMenu(id, bool:exitable);

/**
 * Retrieves a user's current color.
 * 
 * @param id			Player index to retrieve color from
 * @return				Current color this user has
 */
native BB_COLOR:bb_color_getUserColor(id);

/**
 * Retrieves the owner for a specific color.
 * 
 * @param color			Color index to search
 * @return				Owner of the specified color
 */
native bb_color_getColorOwner(BB_COLOR:color);

/**
 * Retrieves the total number of colors registered within Base Builder.
 * 
 * @return				Number of colors registered
 */
native bb_color_getColorNum();