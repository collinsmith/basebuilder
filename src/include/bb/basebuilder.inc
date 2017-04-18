#if defined _basebuilder_included
  #endinput
#endif
#define _basebuilder_included

#pragma reqlib zm_basebuilder

#tryinclude <logger>

#include "include/zm/zombies.inc"

#include "include/bb/bb_i18n.inc"
#include "include/bb/bb_misc.inc"
#include "include/bb/bb_version.inc"

native Logger: bb_getLogger();
