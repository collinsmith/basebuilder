#if defined _bb_zones_const_included
  #endinput
#endif
#define _bb_zones_const_included

enum Zone (<<=1) {
  Zone_None = 0,
  BuilderSpawn = 1,
  ZombieSpawn,
  Territory
}
