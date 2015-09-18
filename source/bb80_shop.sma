/**
 * Base Builder 8
 * Author:	Collin "Tirant" Smith
 * Contact:	collinsmith65@hotmail.com
 * 
 * Table of Contents:
 * 
 * Constants.....................2667
 * Includes......................4625
 * Definitions...................3334
 * Structures....................7878
 * Variables.....................8274
 * Player Variables..............7529
 * Control Variables.............2668
 * Forwards......................3679
 */

#pragma dynamic 32768

//#define USES_MySql

native bb_registerPlayerModel(const model[]);
native bb_registerHandModel(const model[]);
 
native bb_registerClass(
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
 * Constants [2667]
 */
static const BB_PLUGIN_NAME[] = "Base Builder";
static const BB_PLUGIN_VERSION[] = "8.0.0"

static const BB_HOME_DIR[] = "bb/";
static const BB_HANDMODEL_DIR[] = "bb/hands/";
 
static SQL_VAULT_NAME[] = "Base_Builder_80";

#define VAULT_HOLDMOVE		0
#define VAULT_FIXEDMOVE		1
static const VAULT_STRING[][] = {
	"HOLDMOVE",
	"FIXEDMOVE"
};


static const BB_CLASS_OBJECT[]			= "bb_object";
static const BB_CLASS_OBJECT_RAW[]		= "bb_object_";
static const BB_CLASS_ILLUSIONARY[]		= "bb_illusionary";
static const BB_CLASS_TERRITORY[]		= "bb_territory";
static const BB_CLASS_SPAWN_ZOMBIE[]	= "bb_spawn_zombie";
static const BB_CLASS_SPAWN_BUILDER[]	= "bb_spawn_builder";
static const BB_CLASS_BARRIER[]			= "bb_barrier";
static const BB_CLASS_COUNTER[]			= "bb_counter";
static const BB_CLASS_CLOCK[]			= "bb_clock";
static const BB_CLASS_CLOCK_DIGIT[]		= "bb_clockdigit";
static const BB_CLASS_FUNC_WALL[]		= "func_wall";
static const BB_CLASS_INFO_TARGET[]		= "info_target";
static const BB_CLASS_BUYZONE[]			= "buyzone";

static const SPR_CLOCK_FACE[] = "sprites/bb/clock_face.spr";
static const SPR_CLOCK_DIGIT[] = "sprites/bb/clock_digit.spr";

static const SPR_LASER_LINE[] = "sprites/zbeam5.spr";

static const SND_WIN_ZOMBIES[] = "bb/win_zombies2.wav";
static const SND_WIN_BUILDERS[] = "bb/win_builders2.wav";

static const SND_PHASE_PREP[] = "bb/phase_prep.wav";
static const SND_PHASE_BUILD[] = "bb/phase_build.wav";
static const SND_PHASE_RELEASE[][] = {
	"bb/round_start1.wav",
	"bb/round_start2.wav"
};

static const SND_LOCK_OBJECT[] = "buttons/lightswitch2.wav";
static const SND_LOCK_FAIL[] = "buttons/button10.wav";

static const SND_GRAB_START[] = "bb/block_grab.wav";
static const SND_GRAB_STOP[] = "bb/block_drop.wav";

static const SND_INVITE_ARRIVE[] = "events/enemy_died.wav";
static const SND_INVITE_ACCEPT[] = "events/tutor_msg.wav";
static const SND_INVITE_DECLINE[] = "events/friend_died.wav";

static const Float:NULL_ORIGIN[] = { 0.0, 0.0, 0.0 };

static const Float:HUMAN_SPAWN_COLOR[] = { 0.0, 0.0, 200.0 };
static const Float:HUMAN_SPAWN_RENDERAMT = 150.0;

static const Float:ZOMBIE_SPAWN_COLOR[] = { 200.0, 0.0, 0.0 };
static const Float:ZOMBIE_SPAWN_RENDERAMT = 150.0;

static const Float:TERRITORY_NULL_COLOR[] = { 0.0, 150.0, 0.0 };
static const Float:TERRITORY_NULL_RENDERAMT = 66.0;

static const Float:BARRIER_COLOR[] = { 0.0, 0.0, 0.0 };
static const Float:BARRIER_RENDERAMT = 150.0;

static const Float:LOCKED_COLOR[] = { 125.0, 0.0, 0.0 };
static const Float:LOCKED_RENDERAMT = 225.0;

static const Float:DIGIT_OFFS_MULTIPLIER[4] = { 0.725, 0.275, 0.3, 0.75 };
static const Float:CLOCK_SIZE[2] = { 80.0, 32.0 };
static const Float:TITLE_SIZE = 16.0;

static const WEAPON_ENT[][] = {
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};

static const Float:COLOR_RGB[][3] = {
	{135.0, 206.0, 235.0},
	{200.0, 000.0, 000.0},
	{255.0, 083.0, 073.0},
	{255.0, 117.0, 056.0},
	{255.0, 174.0, 066.0},
	{255.0, 207.0, 171.0},
	{252.0, 232.0, 131.0},
	{254.0, 254.0, 034.0},
	{059.0, 176.0, 143.0},
	{197.0, 227.0, 132.0},
	{000.0, 150.0, 000.0},
	{120.0, 219.0, 226.0},
	{135.0, 206.0, 235.0},
	{128.0, 218.0, 235.0},
	{000.0, 000.0, 255.0},
	{146.0, 110.0, 174.0},
	{255.0, 105.0, 180.0},
	{246.0, 100.0, 175.0},
	{205.0, 074.0, 076.0},
	{250.0, 167.0, 108.0},
	{234.0, 126.0, 093.0},
	{180.0, 103.0, 077.0},
	{149.0, 145.0, 140.0},
	{000.0, 000.0, 000.0},
	{255.0, 255.0, 255.0}
}

static const Float:COLOR_RENDERAMT[] = {
	150.0, //NULL
	100.0, //Red
	135.0, //Red Orange
	140.0, //Orange
	120.0, //Yellow Orange
	140.0, //Peach
	125.0, //Yellow
	100.0, //Lemon Yellow
	125.0, //Jungle Green
	135.0, //Yellow Green
	100.0, //Green
	125.0, //Aquamarine
	150.0, //Baby Blue
	090.0, //Sky Blue
	075.0, //Blue
	175.0, //Violet
	150.0, //Hot Pink
	175.0, //Magenta
	140.0, //Mahogany
	140.0, //Tan
	140.0, //Light Brown
	165.0, //Brown
	175.0, //Gray
	125.0, //Black
	125.0, //White
	000.0, //Rainbow
	175.0  //Textured
}

static const COLOR_NAME[][] = {
	"NULL",
	"RED",
	"RED_ORANGE",
	"ORANGE",
	"YELLOW_ORANGE",
	"PEACH",
	"YELLOW",
	"LEMON_YELLOW",
	"JUNGLE_GREEN",
	"YELLOW_GREEN",
	"GREEN",
	"AQUAMARINE",
	"BABY_BLUE",
	"SKY_BLUE",
	"BLUE",
	"VIOLET",
	"HOT_PINK",
	"MAGENTA",
	"MAHOGANY",
	"TAN",
	"LIGHT_BROWN",
	"BROWN",
	"GRAY",
	"BLACK",
	"WHITE",
	"RAINBOW",
	"TEXTURED"
}

/**
 * Includes [4625]
 */
#include <amxmodx>
#include <amxmisc>
#include <cvar_util>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <xs>

#include <cs_team_changer>
#include <cs_maxspeed_api>
#include <cs_weap_models_api>
#include <cs_weap_restrict_api>
#include <cs_player_models_api>

//#include "include/tutor_messages.inc"
#include "include/colorchat.inc"
#include "include/fm_item_stocks.inc"
//#include "include/sqlvault_ex.inc"

/**
 * Definitions [3334]
 */
#define FLAGS_OVERRIDE			ADMIN_RCON
#define FLAGS_BUILD				ADMIN_BAN
//#define FLAGS_LOCK			ADMIN_SLAY
#define FLAGS_MODEDIT			ADMIN_RCON
#define FLAGS_ADMIN				ADMIN_SLAY

#define null cellmin
#define NULL null

#define MAX_PLAYERS 			32+1
#define COUNTDOWN_THINK_DELAY	0.105
#define HUD_FRIEND_HEIGHT		0.35
#define SELECT_SPHERE_RADIUS	128.0
#define TER_BBOX_INC			8.0
#define AUTO_TEAM_JOIN_DELAY	0.1
#define ZOMBIE_ALLOWED_WEAPONS	(1<<CSW_KNIFE)
#define ZOMBIE_DEFAULT_WEAPON	CSW_KNIFE
#define GRAVITY_BARRIER			10.0

//---------------------------------------------------------------------------

#define STATE_INVALID		null
#define STATE_ROUNDSTART	0
#define STATE_BUILDPHASE	1
#define STATE_PREPPHASE		2
#define STATE_RELEASEPHASE	3
#define STATE_ROUNDWON		4
#define STATE_ROUNDEND		5

//---------------------------------------------------------------------------

#define MOVE_UNMOVABLE		0
#define MOVE_MOVABLE		1
#define MOVE_ROTATEABLE		2
#define MOVE_MOVING			4

//---------------------------------------------------------------------------

#define TEAM_UNASSIGNED		0
#define TEAM_ZOMBIE			1
#define TEAM_HUMAN			2
#define TEAM_SPECTATOR		3

//---------------------------------------------------------------------------

#define PSTATE_NULL			null
#define PSTATE_NOCHANGE		0
#define PSTATE_CHANGE		1

//---------------------------------------------------------------------------

#define ZONE_NULL			null
#define ZONE_TERRITORY		0
#define ZONE_BUILDER_SPAWN	1
#define ZONE_ZOMBIE_SPAWN	2

//---------------------------------------------------------------------------

#define COMMAND_NULL		null
#define COMMAND_CMDS		0
#define COMMAND_ZONES		1
#define COMMAND_CLOCKS		2
#define COMMAND_COLORS		3
#define COMMAND_MYCOLOR		4
#define COMMAND_GUNS		5
#define COMMAND_SWAP		6
#define COMMAND_REVIVE		7
#define COMMAND_CLASS		8
#define COMMAND_TERRITORY	9
#define COMMAND_MENU		10
#define COMMAND_SETTINGS	11

//---------------------------------------------------------------------------

#define COLOR_NULL			0
#define COLOR_RED			1
#define COLOR_REDORANGE		2
#define COLOR_ORANGE		3
#define COLOR_YELLOWORANGE	4
#define COLOR_PEACH			5
#define COLOR_YELLOW		6
#define COLOR_LEMONYELLOW	7
#define COLOR_JUNGLEGREEN	8
#define COLOR_YELLOWGREEN	9
#define COLOR_GREEN			10
#define COLOR_AQUAMARINE	11
#define COLOR_BABYBLUE		12
#define COLOR_SKYBLUE		13
#define COLOR_BLUE			14
#define COLOR_VIOLET		15
#define COLOR_PINK			16
#define COLOR_MAGENTA		17
#define COLOR_MAHOGANY		18
#define COLOR_TAN			19
#define COLOR_LIGHTBROWN	20
#define COLOR_BROWN			21
#define COLOR_GRAY			22
#define COLOR_BLACK			23
#define COLOR_WHITE			24
#define COLOR_RAINBOW		25
#define COLOR_TEXTURED		26

//---------------------------------------------------------------------------

#define SAVE_STEAMID		0
#define SAVE_IP				1
#define SAVE_NAME			2

//---------------------------------------------------------------------------

#define flagGetBool(%1,%2)			(!!flagGet(%1,%2))
#define flagGet(%1,%2)				(%1 & (1<<(%2&31)))
#define flagSet(%1,%2)				(%1 |= (1<<(%2&31)))
#define flagUnset(%1,%2)			(%1 &= ~(1<<(%2&31)))
#define flagToggle(%1,%2)			(%1 ^= (1<<(%2&31)))

//---------------------------------------------------------------------------

#define SetUserOwnedEnt(%1,%2)		(g_ownedEnt[%1]=%2)
#define GetUserOwnedEnt(%1)			(g_ownedEnt[%1])
//#define SetUserOwnedEnt(%1,%2)	(entity_set_int(%1,EV_INT_iuser1,%2))
//#define GetUserOwnedEnt(%1)		(entity_get_int(%1,EV_INT_iuser1))

#define SetUserPSet(%1,%2)			(entity_set_int(%1,EV_INT_iuser2,%2))
#define GetUserPSet(%1)				(entity_get_int(%1,EV_INT_iuser2))

#define SetUserColor(%1,%2)			(entity_set_int(%1,EV_INT_iuser3,%2))
#define GetUserColor(%1)			(entity_get_int(%1,EV_INT_iuser3))
#define UserHasColor(%1)			(GetUserColor(%1)>COLOR_NULL)

#define SetUserRBColor(%1,%2)		(g_rbColor[%1]=%2)
#define GetUserRBColor(%1)			(g_rbColor[%1])

#define SetUserClass(%1,%2)			(entity_set_int(%1,EV_INT_iuser4,%2))
#define GetUserClass(%1)			(entity_get_int(%1,EV_INT_iuser4))
#define UserHasClass(%1)			(GetUserClass(%1)!=null)

#define SetUserNextClass(%1,%2)		(g_nextClass[%1]=%2)
#define GetUserNextClass(%1)		(g_nextClass[%1])
#define UserHasNextClass(%1)		(g_nextClass[%1]!=null)

#define SetUserBuildDelay(%1,%2)	(entity_set_float(%1,EV_FL_fuser1,%2))
#define GetUserBuildDelay(%1)		(entity_get_float(%1,EV_FL_fuser1))

#define SetUserEntDist(%1,%2)		(g_entDist[%1]=%2)
#define GetUserEntDist(%1)			(g_entDist[%1])
//#define SetUserEntDist(%1,%2)		(entity_set_float(%1,EV_FL_fuser2,%2))
//#define GetUserEntDist(%1)		(entity_get_float(%1,EV_FL_fuser2))

//#define GetUserOffset(%1,%2)		(xs_vec_copy(g_entOffset[id],%2))
//#define SetUserOffset(%1,%2)		(xs_vec_copy(%2,g_entOffset[id]))
//#define GetUserOffset(%1,%2)		(entity_get_vector(%1,EV_VEC_vuser4,%2))
//#define SetUserOffset(%1,%2)		(entity_set_vector(%1,EV_VEC_vuser4,%2))

//---------------------------------------------------------------------------

#define SetZoneType(%1,%2)			(entity_set_int(%1,EV_INT_iuser1,%2))
#define GetZoneType(%1)				(entity_get_int(%1,EV_INT_iuser1))

#define SetZonePlayers(%1,%2)		(entity_set_int(%1,EV_INT_iuser2,%2))
#define GetZonePlayers(%1)			(entity_get_int(%1,EV_INT_iuser2))
#define IsPlayerInZone(%1,%2)		(GetZonePlayers(%2)&(1<<%1))
#define IsZoneClaimed(%1)			(GetZoneOwner(%1)>0)

#define SetZoneOwner(%1,%2)			(entity_set_int(%1,EV_INT_iuser3,%2))
#define GetZoneOwner(%1)			(entity_get_int(%1,EV_INT_iuser3))

#define SetZoneChild(%1,%2)			(entity_set_int(%1,EV_INT_iuser4,%2))
#define GetZoneChild(%1)			(entity_get_int(%1,EV_INT_iuser4))

#define SetZoneSibling(%1,%2)		(entity_set_edict(%1,EV_ENT_owner,%2))
#define GetZoneSibling(%1)			(entity_get_edict(%1,EV_ENT_owner))

//---------------------------------------------------------------------------

#define SetEntMoveType(%1,%2)		(entity_set_int(%1,EV_INT_iuser1,%2))
#define GetEntMoveType(%1)			(entity_get_int(%1,EV_INT_iuser1))

#define SetEntMoving(%1)    		(SetEntMoveType(%1,(GetEntMoveType(%1)|MOVE_MOVING)))
#define SetEntUnmoving(%1)  		(SetEntMoveType(%1,(GetEntMoveType(%1)&~MOVE_MOVING)))
#define IsEntMoving(%1)   			(GetEntMoveType(%1)&MOVE_MOVING)

#define SetEntMover(%1,%2)			(entity_set_int(%1,EV_INT_iuser2,%2))
#define GetEntMover(%1)				(entity_get_int(%1,EV_INT_iuser2))

#define SetEntLastMover(%1,%2)		(entity_set_int(%1,EV_INT_iuser3,%2))
#define GetEntLastMover(%1)			(entity_get_int(%1,EV_INT_iuser3))

#define SetEntTerritory(%1,%2)		(entity_set_int(%1,EV_INT_iuser4,%2))
#define GetEntTerritory(%1)			(entity_get_int(%1,EV_INT_iuser4))
#define IsEntClaimed(%1)			(entity_get_int(%1,EV_INT_iuser4)!=ZONE_NULL)

#define SetEntLocked(%1)			(entity_set_float(%1,EV_FL_fuser1,1.0))
#define SetEntUnlocked(%1)			(entity_set_float(%1,EV_FL_fuser1,0.0))
#define IsEntLocked(%1)				(entity_get_float(%1,EV_FL_fuser1)==1.0)

#define GetEntOffset(%1,%2)			(entity_get_vector(%1,EV_VEC_vuser1,%2))
#define SetEntOffset(%1,%2)			(entity_set_vector(%1,EV_VEC_vuser1,%2))

//---------------------------------------------------------------------------

#define bb_playSound(%1,%2) client_cmd(%1,"spk %s",%2)

/**
 * Structures [7878]
 */
enum (+= 5039) {
	task_HudHealth = 514229,
	task_RespawnUser,
	task_AutoJoin,
	task_ClaimTimer,
	task_GetKey
};

#define TER_PLAYER_MULT	7
#define MAX_TER_CLAIM	28
enum _:territory_t {
	territory_Parent,
	territory_NumPlayers,
	territory_Claimed[MAX_TER_CLAIM],
	territory_NumClaimed,
	territory_MenuIgnore
};

static g_tempTerritory[territory_t];
static g_curTempTerritory;
static Array:g_territoryList;
static g_territoryNum;

static Trie:g_commandTrie;

static Array:g_playerModelList;
static Trie:g_playerModelTrie;
static g_playerModelNum;

static Array:g_handModelList;
static Trie:g_handModelTrie;
static g_handModelNum;

#define class_Name_length		31
#define class_Desc_length		127
enum _:class_t {
	class_Name[class_Name_length+1],
	class_Desc[class_Desc_length+1],
	Float:class_Health,
	Float:class_Speed,
	Float:class_Gravity,
	class_Model,
	class_HandModel,
	class_Cost,
	class_LevelReq
};

static g_tempClass[class_t];
static g_curTempClass;
static Array:g_classList;
static Trie:g_classTrie;
static g_classNum;

/**
 * Variables [8274]
 */
#define LENGTH_NAME 31
#define LENGTH_PATH 127
#define LENGTH_BUFFER 255
#define LENGTH_SMALLBUFFER 31
static g_szBuffer[LENGTH_BUFFER+1];
static g_szSmallBuffer[LENGTH_SMALLBUFFER+1];

static g_szHomeDir[LENGTH_PATH+1];
static g_szHomeDir_length;

static g_szModName[LENGTH_NAME+1];

static g_iVector1[3];
static Float:g_fVector1[3];
static Float:g_fVector2[3];
static Float:g_fVector3[3];

static g_iBarrier = null;
static g_iCounter = null;

static g_iCountDownSecs;
static g_iCountDownTenth;

static g_iCurEditor;
static g_iEditingZone;

static g_iMaxTerritoryNum;

static g_gameState = STATE_INVALID;

static g_flagConnected;
static g_flagAlive;
static g_flagZombie;
static g_flagFriend;
static g_flagHoldMode;
static g_flagFixedMoving;
static g_flagColorOwned;
static g_flagFirstTeam;
static g_flagHasUpdated;
static g_flagHasWeapons;
static g_flagOpenClaimMenu;

static g_Menu_Main;
static g_Menu_Main_Callback;
static g_Menu_Clocks;
static g_Menu_Zone;
static g_Menu_ZoneTeam;
static g_Menu_ZoneEditor;
static g_Menu_PrimWeapon;
static g_Menu_SecWeapon;
static g_Menu_Colors;
static g_Menu_Colors_Callback;
static g_Menu_Classes;
static g_Menu_Classes_Callback;
static g_Menu_Claim;
static g_Menu_FriendInvite;
static g_Menu_Territory;
static g_Menu_Territory_Callback;
static g_Menu_Settings;

static g_HudSync1;
static g_HudSync2;
static g_HudSync3;

static g_iLineSprite;

static SQLVault:g_SqlVault;

/**
 * Player Variables [7529]
 */
static g_ownedEnt[MAX_PLAYERS];
static Float:g_entOffset[MAX_PLAYERS][3];
static Float:g_entDist[MAX_PLAYERS];
static g_rbColor[MAX_PLAYERS];
static g_curTerritory[MAX_PLAYERS];
static g_nextTerritory[MAX_PLAYERS];
static g_actualTeam[MAX_PLAYERS];
static g_nextClass[MAX_PLAYERS];
static g_softKillTer[MAX_PLAYERS];
static Float:g_fEnterTime[MAX_PLAYERS];
static g_szAuthID[MAX_PLAYERS][35];

/**
 * Control Variables [2668]
 */
static g_iBuildTime;
static g_iPrepTime;
static g_iFixedMovementUnits;
static g_iHumanZombieRatio;
static g_iBlockHumanRatio;
#define MAX_ALLOWED_CLAIM (g_tempTerritory[territory_NumPlayers] * g_iBlockHumanRatio)
static g_iSavePruneDays;
static g_iSaveMode;

static Float:g_fGravity;
static Float:g_fBuildDelay;
static Float:g_fMaxEntDist;
static Float:g_fMinEntDist;
static Float:g_fMinEntDistSet;
static Float:g_fPushPullRate;
static Float:g_fSoftKillTime;
static Float:g_fClaimTime;
static Float:g_fRespawnDelay;

/**
 * Forwards [3679]
 */

static g_fwReturn;
static g_fwRegisterClasses;