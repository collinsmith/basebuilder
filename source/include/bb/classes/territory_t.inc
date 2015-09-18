#if defined _territory_t_included
	#endinput
#endif
#define _territory_t_included

#define MAX_TER_PLAYERS 4
#define TER_PLAYER_MULT 7
#define MAX_TER_CLAIM 28

#define BB_TERRITORY: any:
enum BB_TERRITORY:territory_t {
	territory_Owner,
	territory_Parent,
	territory_Players,
	territory_NumPlayers,
	territory_Claimed[MAX_TER_CLAIM],
	territory_NumClaimed,
	territory_MenuIgnore
};