#if defined _command_t_included
	#endinput
#endif
#define _command_t_included

#define command_Name_length 31
#define command_Desc_length 63

#define BB_COMMAND: _:
enum BB_COMMAND:command_t {
	command_Name[command_Name_length+1],	// Name
	command_Desc[command_Desc_length+1],	// Description
	command_PluginID,						// Plugin ID #
	command_FuncID,							// Function ID #
	command_Flags,							// Flags for activation
	command_AdminFlags,						// Admin flags needed
	command_NameLen							// Length of the command
};