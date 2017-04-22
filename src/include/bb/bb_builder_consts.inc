#if defined _bb_builder_const_included
  #endinput
#endif
#define _bb_builder_const_included

#define UNMOVABLE 0
#define MOVABLE   0x00000001
#define ROTATABLE 0x00000002
#define FLIPPABLE 0x00000004
#define MOVING    0x00000008

stock const BB_OBJECT[] = "bb_object";
stock const BB_OBJECT_RAW[] = "bb_object_";
stock const BB_ILLUSIONARY[] = "bb_illusionary";
stock const BB_TERRITORY[] = "bb_territory";

stock const BB_BARRIER[][] = { "bb_barrier", "barrier" };
stock const BB_IGNORE[][] = { "bb_ignore", "ignore" };


