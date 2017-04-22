#if defined _bb_builder_macros_included
  #endinput
#endif
#define _bb_builder_macros_included

#include <engine>

#include "include/bb/bb_builder_consts.inc"

#define ClaimBlock(%1,%2)   entity_set_int(%1, EV_INT_iuser1, %2)
#define UnclaimBlock(%1)    entity_set_int(%1, EV_INT_iuser1, null)
#define GetBlockClaimer(%1) entity_get_int(%1, EV_INT_iuser1)

#define SetEntMover(%1,%2)  entity_set_int(%1, EV_INT_iuser2, %2)
#define UnsetEntMover(%1)   entity_set_int(%1, EV_INT_iuser2, 0)
#define GetEntMover(%1)     entity_get_int(%1, EV_INT_iuser2)

#define SetLastMover(%1,%2) entity_set_int(%1, EV_INT_iuser3, %2)
#define UnsetLastMover(%1)  entity_set_int(%1, EV_INT_iuser3, 0)
#define GetLastMover(%1)    entity_get_int(%1, EV_INT_iuser3)

#define SetMoveType(%1,%2)  entity_set_int(%1, EV_INT_iuser4, %2)
#define ResetMoveType(%1)   entity_set_int(%1, EV_INT_iuser4, 0)
#define GetMoveType(%1)     entity_get_int(%1, EV_INT_iuser4)

#define SetChild(%1,%2)     entity_set_float(%1, EV_FL_fuser1, float(%2))
#define GetChild(%1)        floatround(entity_get_float(%1, EV_FL_fuser1))

#define LockBlock(%1)       entity_set_float(%1, EV_FL_fuser2, 1.0)
#define UnlockBlock(%1)     entity_set_float(%1, EV_FL_fuser2, 0.0)
#define IsBlockLocked(%1)   (entity_get_float(%1, EV_FL_fuser2) == 1.0)

#define MovingEnt(%1)       SetMoveType(%1, (GetMoveType(%1) | MOVING))
#define UnmovingEnt(%1)     SetMoveType(%1, (GetMoveType(%1) & ~MOVING))
#define IsMovingEnt(%1)     (GetMoveType(%1) & MOVING)

#define EntGetOffset(%1,%2) entity_get_vector(%1, EV_VEC_vuser1, %2)
#define EntSetOffset(%1,%2) entity_set_vector(%1, EV_VEC_vuser1, %2)

#define EntGetMins(%1,%2)   entity_get_vector(%1, EV_VEC_vuser2, %2)
#define EntSetMins(%1,%2)   entity_set_vector(%1, EV_VEC_vuser2, %2)

#define EntGetMaxs(%1,%2)   entity_get_vector(%1, EV_VEC_vuser3, %2)
#define EntSetMaxs(%1,%2)   entity_set_vector(%1, EV_VEC_vuser3, %2)
