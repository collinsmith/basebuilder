#if defined _bb_builder_included
    #endinput
#endif
#define _bb_builder_included

#include "include/bb/bb_builder_consts.inc"
#include "include/bb/bb_builder_macros.inc"

forward bb_onBeforeGrabbed(const id, const entity);
forward bb_onGrabBlocked(const id, const entity, const reason[]);
forward bb_onGrabbed(const id, const entity);
forward bb_onDropped(const id, const entity);
forward bb_onPush(const id, const entity, const bool: maxDist);
forward bb_onPull(const id, const entity, const bool: minDist);
forward bb_onReset(const entity);
forward bb_onResetAll();

native bool: bb_reset(const entity);
native bb_resetAll();
native bool: bb_drop(const id);
native bool: bb_isInPlayerPVS(const id, const entity);
native bb_setBlockedReason(const reason[]);
