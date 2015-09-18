#if defined _bb_cr_included
	#endinput
#endif
#define _bb_cr_included

#pragma reqlib BB_Credits_80
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Credits_80
#endif

#include "include/bb/bb_credits_const.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Retrieves a boolean value for whether or not the Credits key was validated.
 * 
 * @return				True if validated, otherwise false
 */
native bool:bb_cr_isEnabled();