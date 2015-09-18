#if defined _bb_classes_included
	#endinput
#endif
#define _bb_classes_included

#pragma reqlib BB_Classes
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Classes
#endif

#include "include/bb/classes/class_t.inc"
#include "include/bb/bb_handmodels.inc"
#include "include/bb/bb_playermodels.inc"

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Registers a class with Base Builder for use.
 * 
 * @param name			Name of the class
 * @param description	Brief description of the class
 * @param model			Player model this class uses
 * @param handModel		Knife model this class uses
 * @param health		Max health for this class
 * @param speed			Maxspeed multiplier for this class
 * @param gravity		Gravity multiplier for this class
 * @param cost			The cost to use this class
 * @param levelReq		Level requirement to use this class
 * @return				BB_CLASS index of this class, BB_CLASS:null
 * 						for invalid class
 */
native BB_CLASS:bb_class_registerClass(
	const name[],
	const description[],
	const model[],
	const handModel[] = "v_bloodyhands",
	const Float:health = 2000.0,
	const Float:speed = 1.0,
	const Float:gravity = 1.0,
	const cost = 0,
	const levelReq = 0
);

/**
 * Retrieves the name of a class.
 * 
 * @param class			Index of class to get name for
 * @param string		String to place result into
 * @param length		Max length of the result
 */
native bb_class_getClassName(BB_CLASS:class, string[], length);

/**
 * Retrieves the health of a class.
 * 
 * @param class			Index of class to get health for
 * @return				Health of the class, Float:null for no class
 */
native Float:bb_class_getClassHealth(BB_CLASS:class);

/**
 * Opens the class menu for a user to select a next class. This will then
 * be set as the users next class any automatically loaded if possible.
 * 
 * @param id			Player index to open menu for
 * @param exitable		True to make this menu exitable, otherwise false
 */
native bb_class_showClassMenu(id, bool:exitable = true);

/**
 * Retrieves the total number of classes registered within
 * the Base Builder cache.
 * 
 * @return				The number of zombie classes in Base Builder
 */
native bb_class_getClassNum();

/**
 * Retrieves a user's current class.
 * 
 * @param id			Player index to retrieve data for
 * @return				User's current class, BB_CLASS:null for none
 */
native BB_CLASS:bb_class_getUserClass(id);

/**
 * Retrieves a user's current next class.
 * 
 * @param id			Player index to retrieve data for
 * @return				User's current next class, BB_CLASS:null for none
 */
native BB_CLASS:bb_class_getUserNextClass(id);

/**
 * Sets a user's next class, which will be loaded upon the next
 * infection or bb_class_refresh(id) event.
 * 
 * @param id			Player index to set data for
 * @param classes		Next class for this user
 * @return				The old next class this user had
 */
native BB_CLASS:bb_class_setUserNextClass(id, BB_CLASS:class);

/**
 * Swaps data between a user's current class and next class, effectively
 * loading that information and altering the players traits.
 * 
 * @param id			Player index to refresh
 */
native bb_class_refresh(id);