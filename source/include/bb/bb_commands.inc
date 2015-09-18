#if defined _bb_cmds_included
	#endinput
#endif
#define _bb_cmds_included

#pragma reqlib BB_Commands
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib BB_Commands
#endif

#include "include/bb/classes/command_t.inc"

/******************************************************************************************************************************
Forwards
******************************************************************************************************************************/

/**
 * Forwarded when a command is determined valid and should be sent.  At
 * this time, returning BB_RET_BLOCK will prevent that command from
 * executing.
 *
 * @note cid		This value can be retrieved when registering a
 *					command, or by using bb_get_cid_by_name(command[])
 *
 * @param id		The player index forwarding this event.
 * @param cid		The function command index that is being executed.
 */
forward bb_fw_command_pre(id, cid);

/**
 * Forwarded when a command is sent to a player.
 *
 * @note cid		This value can be retrieved when registering a
 *					command, or by using bb_get_cid_by_name(command[])
 *
 * @param id		The player index forwarding this event.
 * @param cid		The function command index that is being executed.
 */
forward bb_fw_command_post(id, cid);

/******************************************************************************************************************************
Natives
******************************************************************************************************************************/

/**
 * Native used to register a new command into the BB command
 * structure.  Once a handle is registered once, you need only register
 * any commands under that same handle again since the flags and 
 * description will not (and should not) need to change.
 *
 * @example: To register a new command with 1 variation
 *		bb_register_command("mycommand1", "forwardMyCommand", "abcdef", "An example command");
 *		bb_register_command("mycommand2", "forwardMyCommand");
 *
 * @note flags:	a - Execute only on say all
 *				b - Execute only on say_team
 *				c - Execute only if zombie
 *				d - Execute only if human
 *				e - Execute only if alive
 *				f - Execute only if dead
 *
 * @note return 	>=0 cid of the command
 *		 			-1 Command already exists with this name
 *		 			-2 Handle could not be found
 *
 * @param command		The words that will execute the given handle.
 * @param handle		The name of the PUBLIC function to execute when 
 *							the command is entered successfully.
 * @param flags			The flags describing the conditions under which
 *							this command will be executed.
 * @param description	A brief description to the purpose of this command.
 * @return				The cid (command id) of the function tied to this 
 *							command.
 */
native bb_command_register(const command[], const handle[], const flags[] = "abcdef", const description[] = "", const adminFlags = ADMIN_ALL);

/**
 * Native used to retrieve the function id that this command is tied to.
 *
 * @param command		The command to get the cid from.  This would be
 * 							a command used ingame, such as "cmdlist" or
 * 							"commands".
 * @return				The cid of this function, -1 if no function found.
 */
native bb_command_getCIDByName(const command[]);