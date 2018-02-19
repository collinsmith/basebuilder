#if defined _bb_colors_included
    #endinput
#endif
#define _bb_colors_included

#include "include/bb/bb_colors_consts.inc"

#pragma reqlib bb_colors

forward bb_onColorRegistered(const name[], const Trie: color);
forward bb_onColorChanged(const id, const Color: color, const name[]);

native bool: bb_registerColor(const Trie: color, const bool: replace = true);
native bool: bb_isColorRegistered(const Trie: color);
native bb_getNumColors();
native Array: bb_getColors(const Array: dst = Invalid_Array);
native Color: bb_findColor(const name[]);

native Color: bb_getUserColor(const id);
native Color: bb_setUserColor(const id, const Color: color);
