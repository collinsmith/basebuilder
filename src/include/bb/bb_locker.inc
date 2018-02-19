#if defined _bb_locker_included
    #endinput
#endif
#define _bb_locker_included

#pragma reqlib bb_locker

/*******************************************************************************
 * Forwards
 ******************************************************************************/

forward bb_onBeforeLocked(const id, const entity);
forward bb_onLockBlocked(const id, const entity, const reason[]);
forward bb_onLocked(const id, const entity);
forward bb_onUnlocked(const id, const entity);

/*******************************************************************************
 * Natives
 ******************************************************************************/

native bb_getLocker(const entity);
native bb_setLocker(const entity, const id, const bool: b, const bool: blockable = true);

native bb_setBlockLockReason(const reason[]);

native bb_getUserLockedNum(const id);
native Array: bb_getUserLocked(const id);

/*******************************************************************************
 * Stocks
 ******************************************************************************/

stock bool: bb_isLocked(const entity) {
  return bb_getLocker() > 0;
}

stock bool: bb_toggleLock(const entity, const id) {
  new const locker = bb_getLocker(entity);
  if (!locker) {
    bb_setLocker(entity, id, true);
  } else if (id == locker) {
    bb_setLocker(entity, id, false);
  }
}
