#pragma dynamic 2048

#include <amxmodx>
#include <amxmisc>
#include <cvar_util>

#include "include/bb/classes/command_t.inc"
#include "include/bb/bb_core.inc"
#include "include/bb/bb_zombies.inc"
#include "include/bb/bb_colorchat.inc"

#define PLUGIN_VERSION "0.0.1"

native bb_command_register(const command[], const handle[], const flags[] = "abcdef", const description[] = "", const adminLevel = ADMIN_ALL);

static Array:g_aFunctions;
static Trie:g_tCommands;
static Array:g_aFunctionNames;
static g_functionNum;
static g_tempCommand[command_t];

enum (<<=1) {
	SAY_ALL = 1,
	SAY_TEAM,
	ZOMBIE_ONLY,
	HUMAN_ONLY,
	ALIVE_ONLY,
	DEAD_ONLY
}

static Trie:g_tPrefixes;

static g_szTempString[32];
static g_szCommandListMotD[256];
static g_szCommandTable[1792];
static g_szCommandList[192];

static g_pcvar_prefix;

enum _:eForwardedEvents {
	fwReturn = 0,
	fwCommandEnteredPre,
	fwCommandEnteredPost
};

static g_fw[eForwardedEvents];

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Commands]", "Add a command manager into Base Builder", PLUGIN_VERSION);
	
	g_aFunctions = ArrayCreate(command_t, 8);
	g_aFunctionNames = ArrayCreate(1);
	for (new i; i < get_pluginsnum(); i++) {
		new Trie:tempTrie = TrieCreate();
		ArrayPushCell(g_aFunctionNames, tempTrie);
	}
	
	g_tCommands = TrieCreate();
	g_tPrefixes = TrieCreate();
	
	g_pcvar_prefix = CvarRegister("bb_command_prefixes", "/.!", "A list of all symbols that preceed commands");
	CvarHookChange(g_pcvar_prefix, "hookPrefixesAltered");
	
	new szPrefixes[32], c[2], i;
	get_pcvar_string(g_pcvar_prefix, szPrefixes, 31);
	while (szPrefixes[i] != '^0') {
		c[0] = szPrefixes[i];
		TrieSetCell(g_tPrefixes, c, i);
		i++;
	}
	
	register_dictionary("basebuilder.txt");
	refreshCommandMotD();
	constructCommandTable();
}

public bb_fw_init_post() {
	bb_command_register("commands", "displayCommandList", "abcdef", "Displays a printed list of all commands");
	bb_command_register("cmds", "displayCommandList");
	
	bb_command_register("commandlist", "displayCommandMotD", "abcdef", "Displays a detailed list of all commands");
	bb_command_register("cmdlist", "displayCommandMotD");
}

public plugin_init() {
	register_clcmd("say", "cmdSay");
	register_clcmd("say_team", "cmdSayTeam");
	
	/* Forwards */
	/// Executed before a command function is executed. Can be stopped.
	g_fw[fwCommandEnteredPre] = CreateMultiForward("bb_fw_command_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	/// Executed after a command function is executed. Can't be stopped.
	g_fw[fwCommandEnteredPost] = CreateMultiForward("bb_fw_command_post", ET_IGNORE, FP_CELL, FP_CELL);
}

public hookPrefixesAltered(handleCvar, const oldValue[], const newValue[], const cvarName[]) {
	TrieClear(g_tPrefixes);
	
	new i;
	while (newValue[i] != '^0') {
		TrieSetCell(g_tPrefixes, newValue[i], i);
		i++;
	}
	
	refreshCommandMotD();
}

public plugin_natives() {
	register_library("BB_Commands");
	
	register_native("bb_command_register", "_registerCommand", 0);
	register_native("bb_command_getCIDByName", "_getCIDByName", 0);
}

public cmdSay(id) {
	read_args(g_szTempString, 31);
	return forwardCommand(id, false, g_szTempString);
}

public cmdSayTeam(id) {
	read_args(g_szTempString, 31);
	return forwardCommand(id, true, g_szTempString);
}

/**
 * Private method used to help simplify checking of a command
 * to see if it is used with a correct prefix.
 *
 * @param id			The player index who entered the command.
 * @param teamCommand	True if it is a team command, false otherwise.
 * @param message		The message being sent.
 */
forwardCommand(id, bool:teamCommand, message[]) {
	strtolower(message);
	remove_quotes(message);
	
	new szTemp[2], i;
	szTemp[0] = message[0];
	if (!TrieGetCell(g_tPrefixes, szTemp, i)) {
		return PLUGIN_CONTINUE;
	}
	
	new szCommand[32];
	strbreak(message, szCommand, 31, message, 31);
	if (TrieGetCell(g_tCommands, szCommand[1], i)) {
		return executeCommand(i, id, teamCommand, message);
	}
	
	return PLUGIN_CONTINUE;
}

/**
 * Private method which takes a successful command and determines
 * whether or not the cirsumstances under which is was entered
 * obey the flags for the function tied into this command.
 *
 * @param cid			The unique command id to execute.
 * @param id			The player index to execute the command onto.
 * @param teamCommand	True if it is a team command, false otherwise.
 */
executeCommand(cid, id, bool:teamCommand, message[]) {
	ArrayGetArray(g_aFunctions, cid, g_tempCommand);
	
	new iFlags = g_tempCommand[command_Flags];
	if (!(iFlags&SAY_ALL) && !(iFlags&SAY_TEAM)) {
		return PLUGIN_CONTINUE;
	} else if ((iFlags&SAY_TEAM) && !teamCommand && !(iFlags&SAY_ALL)) {
		bb_printColor(id, "%L", id, "COMMAND_SAYTEAMONLY");
		return PLUGIN_HANDLED;
	} else if ((iFlags&SAY_ALL) && teamCommand && !(iFlags&SAY_TEAM)) {
		bb_printColor(id, "%L", id, "COMMAND_SAYALLONLY");
		return PLUGIN_HANDLED;
	}

	new isZombie = bb_zm_isUserZombie(id);
	if (!(iFlags&ZOMBIE_ONLY) && !(iFlags&HUMAN_ONLY)) {
		return PLUGIN_CONTINUE;
	} else if ((iFlags&HUMAN_ONLY) && isZombie && !(iFlags&ZOMBIE_ONLY)) {
		bb_printColor(id, "%L", id, "COMMAND_HUMANONLY");
		return PLUGIN_HANDLED;
	} else if ((iFlags&ZOMBIE_ONLY) && !isZombie && !(iFlags&HUMAN_ONLY)) {
		bb_printColor(id, "%L", id, "COMMAND_ZOMBIEONLY");
		return PLUGIN_HANDLED;
	}

	new isAlive = is_user_alive(id);
	if (!(iFlags&ALIVE_ONLY) && !(iFlags&DEAD_ONLY)) {
		return PLUGIN_CONTINUE;
	} else if ((iFlags&DEAD_ONLY) && isAlive && !(iFlags&ALIVE_ONLY)) {
		bb_printColor(id, "%L", id, "COMMAND_DEADONLY");
		return PLUGIN_HANDLED;
	} else if ((iFlags&ALIVE_ONLY) && !isAlive && !(iFlags&DEAD_ONLY)) {
		bb_printColor(id, "%L", id, "COMMAND_ALIVEONLY");
		return PLUGIN_HANDLED;
	}
	
	new iAdminFlags = g_tempCommand[command_AdminFlags];
	if (!access(id, iAdminFlags)) {
		bb_printColor(id, "%L", id, "COMMAND_ADMINFLAGS");
		return PLUGIN_HANDLED;
	}
	
	ExecuteForward(g_fw[fwCommandEnteredPre], g_fw[fwReturn], id, cid);
	if (g_fw[fwReturn] == BB_RET_BLOCK) {
		bb_printColor(id, "%L", id, "COMMAND_BLOCKED");
		return PLUGIN_HANDLED;
	}
	
	trim(message);
	new player = cmd_target(id, message, CMDTARGET_ALLOW_SELF);
	callfunc_begin_i(g_tempCommand[command_FuncID], g_tempCommand[command_PluginID]); {
	callfunc_push_int(id);
	callfunc_push_int(player);
	callfunc_push_str(message, false);
	} callfunc_end();
	
	ExecuteForward(g_fw[fwCommandEnteredPost], g_fw[fwReturn], id, cid);
	
	return PLUGIN_HANDLED;
}

/**
 * Public method used to display all initial command tied in with a function.
 * This method will not display duplicate commands tied into a single function.
 *
 * @param id		The player index to display the command list to.
 */
public displayCommandList(id) {
	static tempstring[sizeof g_szCommandList-2];
	add(tempstring, strlen(g_szCommandList)-2, g_szCommandList);
	bb_printColor(id, "^3%L^1: %s", id, "COMMANDS", tempstring);
}

/**
 * Public method used to display the command list MotD to a player.  This method
 * must combine all different pre-cached portions of the message including: the
 * header with prefixes, the command list table, and the footer.
 *
 * @param id		The player index to display the command list MotD to.
 */
public displayCommandMotD(id) {
	static szMotDText[2048];
	new len = formatex(szMotDText, 2047, g_szCommandListMotD);
	len += formatex(szMotDText[len], 2047, g_szCommandTable);
	len += formatex(szMotDText[len], 2047, "</table></blockquote></font></body></html>");
	show_motd(id, szMotDText, "BB Commands: Command List");
}

/**
 * Private method used to format the header and prefixes portion of the command
 * list MotD.  This is called whenever the command prefixes change.
 */
refreshCommandMotD() {
	new len = formatex(g_szCommandListMotD, 255, "<html><body bgcolor=^"#474642^"><font size=^"3^" face=^"courier new^" color=^"FFFFFF^">");
	len += formatex(g_szCommandListMotD[len], 255-len, "<center><h1>Base Builder Commands v%s</h1>By Tirant</center><br><br>", PLUGIN_VERSION);
	len += formatex(g_szCommandListMotD[len], 255-len, "%L: ", LANG_SERVER, "COMMAND_PREFIXES");
	get_pcvar_string(g_pcvar_prefix, g_szCommandListMotD[len], 255-len);
}

/**
 * Private method used to construct the initial header for the command table.
 * This method should only be called before commands are registered, because
 * this resets the entire command list table.
 */
constructCommandTable() {
	formatex(g_szCommandTable, 1791, "<br><br>%L:<blockquote>", LANG_SERVER, "COMMANDS");
	add(g_szCommandTable, 1791, "<STYLE TYPE=^"text/css^"><!--TD{color: ^"FFFFFF^"}---></STYLE><table><tr><td>Command:</td><td>&nbsp;&nbsp;Description:</td></tr>");
}

/**
 * Private method used to add a new function into all displays where it will
 * need to be displayed.
 *
 * @param command		The command that will execute the function.
 * @param description		The description to be displayed for this command.
 */
addCommandToTable(command[], description[]) {
	new tempstring[128];
	formatex(tempstring, 127, "<tr><td>%s</td><td>: %s</td></tr>", command, description);
	add(g_szCommandTable, 1791, tempstring);
	
	formatex(tempstring, 127, "%s, ", command);
	add(g_szCommandList, 191, tempstring);
}

/**
 * @see ZP_Commands.inc
 */
public BB_COMMAND:_registerCommand(iPlugin, iParams) {
	if (iParams != 5) {
		return BB_COMMAND:null;
	}
	
	new i;
	get_string(1, g_tempCommand[command_Name], command_Name_length);
	strtolower(g_tempCommand[command_Name]);
	if (TrieGetCell(g_tCommands, g_tempCommand[command_Name], i)) {
		return BB_COMMAND:null;
	}
	
	new szTemp[command_Name_length+1];
	get_string(2, szTemp, command_Name_length);

	new Trie:tempTrie;
	tempTrie = ArrayGetCell(g_aFunctionNames, iPlugin);
	if (TrieGetCell(tempTrie, szTemp, i)) {
		TrieSetCell(g_tCommands, g_tempCommand[command_Name], i);
		
		return BB_COMMAND:i;
	} else {
		g_tempCommand[command_FuncID] = get_func_id(szTemp, iPlugin);
		if (g_tempCommand[command_FuncID] < 0) {
			return BB_COMMAND:-2;
		}

		TrieSetCell(tempTrie, szTemp, g_functionNum);
		ArraySetCell(g_aFunctionNames, iPlugin, tempTrie);

		g_tempCommand[command_PluginID] = iPlugin;
		get_string(3, szTemp, 31);
		g_tempCommand[command_Flags] = read_flags(szTemp);
		get_string(4, g_tempCommand[command_Desc], command_Desc_length);
		g_tempCommand[command_AdminFlags] = get_param(5);
		
		ArrayPushArray(g_aFunctions, g_tempCommand);
		TrieSetCell(g_tCommands, g_tempCommand[command_Name], g_functionNum);
		
		addCommandToTable(g_tempCommand[command_Name], g_tempCommand[command_Desc]);
		
		g_functionNum++;
		return BB_COMMAND:(g_functionNum-1);
	}
	
	return BB_COMMAND:null;
}

/**
 * @see ZP_Commands.inc
 */
public BB_COMMAND:_getCIDByName(iPlugin, iParams) {
	if (iParams != 1) {
		return BB_COMMAND:null;
	}
	
	new i;
	get_string(1, g_szTempString, 31);
	if (TrieGetCell(g_tCommands, g_szTempString, i)) {
		return BB_COMMAND:i;
	}
	
	return BB_COMMAND:null;
}