#if defined _bb_entity_consts_included
    #endinput
#endif
#define _bb_entity_consts_included

#include <engine>

#define UNMOVABLE 0
#define MOVABLE   0x00000001
#define ROTATABLE 0x00000002
#define FLIPPABLE 0x00000004
#define MOVING    0x00000008

#define IUSER_MOVETYPE   EV_INT_iuser1

#define GetEntMoveType(%1)     entity_get_int(%1,IUSER_MOVETYPE)
#define SetEntMoveType(%1,%2)  entity_set_int(%1,IUSER_MOVETYPE,%2)
#define IsEntMovable(%1)       (GetEntMoveType(%1)>UNMOVABLE)

#define SetEntMoving(%1)       SetEntMoveType(%1,(GetEntMoveType(%1)|MOVING))
#define ResetEntMoving(%1)     SetEntMoveType(%1,(GetEntMoveType(%1)&~MOVING))
#define IsEntMoving(%1)        (GetEntMoveType(%1)&MOVING)

#define VUSER_OFFSET     EV_VEC_vuser1
#define VUSER_MINS       EV_VEC_vuser2
#define VUSER_MAXS       EV_VEC_vuser3

#define GetEntOffset(%1,%2)    entity_get_vector(%1,VUSER_OFFSET,%2)
#define SetEntOffset(%1,%2)    entity_set_vector(%1,VUSER_OFFSET,%2)

#define GetEntMins(%1,%2)      entity_get_vector(%1,VUSER_MINS,%2)
#define SetEntMins(%1,%2)      entity_set_vector(%1,VUSER_MINS,%2)

#define GetEntMaxs(%1,%2)      entity_get_vector(%1,VUSER_MAXS,%2)
#define SetEntMaxs(%1,%2)      entity_set_vector(%1,VUSER_MAXS,%2)

#define EUSER_OWNER      EV_ENT_owner
#define EUSER_MOVER      EV_ENT_euser1
#define EUSER_LAST_MOVER EV_ENT_euser2
#define EUSER_LOCKER     EV_ENT_euser3

#define GetEntOwner(%1)        entity_get_edict(%1,EUSER_OWNER)
#define SetEntOwner(%1,%2)     entity_set_edict(%1,EUSER_OWNER,%2)
#define ResetEntOwner(%1)      SetEntOwner(%1,0)
#define IsEntOwned(%1)         (GetEntOwner(%1)>0)

#define GetEntMover(%1)        entity_get_edict(%1,EUSER_MOVER)
#define SetEntMover(%1,%2)     entity_set_edict(%1,EUSER_MOVER,%2)
#define ResetEntMover(%1)      SetEntMover(%1,0)

#define GetEntLastMover(%1)    entity_get_edict(%1,EUSER_LAST_MOVER)
#define SetEntLastMover(%1,%2) entity_set_edict(%1,EUSER_LAST_MOVER,%2)
#define ResetEntLastMover(%1)  SetEntLastMover(%1,0)

#define GetEntLocker(%1)       entity_get_edict(%1,EUSER_LOCKER)
#define SetEntLocker(%1,%2)    entity_set_edict(%1,EUSER_LOCKER,%2)
#define ResetEntLocker(%1)     SetEntLocker(%1,0)
#define IsEntLocked(%1)        (GetEntLocker(%1)>0)

stock const BB_OBJECT[] = "bb_object";
stock const BB_OBJECT_RAW[] = "bb_object_";
stock const BB_ILLUSIONARY[] = "bb_illusionary";
stock const BB_TERRITORY[] = "bb_territory";
stock const BB_TIMER[] = "bb_timer";

stock const BB_BARRIER[][] = { "bb_barrier", "barrier", "Barrier" };
stock const BB_IGNORE[][] = { "bb_ignore", "ignore", "blockers" };
stock const BB_BUILDER_SPAWN[] = "bb_builder_spawn";
stock const BB_ZOMBIE_SPAWN[] = "bb_zombie_spawn";
