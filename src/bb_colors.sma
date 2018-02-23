#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>
#include <reapi>
#include <xs>

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_colors_consts.inc"
#include "include/bb/bb_locker.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  #define DEGUG_COLORS
  #define DEBUG_LOADERS
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEGUG_COLORS
  //#define DEBUG_LOADERS
#endif

#define EXTENSION_NAME "Colors"
#define VERSION_STRING "1.0.0"

#define COLORS_DICTIONARY "bb_colors.txt"

/** Log a warning if registering a color which will overwrite an existing one */
#define WARN_ON_COLOR_OVERWRITE
/** Throw an error if operating on a color which isn't registered */
#define ENFORCE_REGISTERED_COLORS_ONLY
/** Invalid_Trie is used to reset a user's color to "null" */
#define INVALID_TRIE_WILL_RESET_COLOR

static Trie: colors;

static key[32];
static value[256];

static Color: pColor[MAX_PLAYERS + 1];

stock Trie: toTrie(value) return Trie:(value);
stock Trie: operator=(value) return toTrie(value);

stock Array: toArray(value) return Array:(value);
stock Array: operator=(value) return toArray(value);

stock bool: operator=(value) return value > 0;

public zm_onInit() {
  LoadLogger(bb_getPluginId());
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  
  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages user colors");

  register_dictionary(COLORS_DICTIONARY);
#if defined DEBUG_I18N
  logd("Registering dictionary file \"%s\"", COLORS_DICTIONARY);
#endif

#if defined DEGUG_COLORS
  bb_registerConCmd(
      .command = "colors",
      .callback = "onPrintColors",
      .desc = "Lists all colors");
#endif
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

/*******************************************************************************
 * Commands
 ******************************************************************************/

#if defined DEGUG_COLORS
public onPrintColors(id) {
  console_print(id, "Colors:");
  //console_print(id, "%3s %24s %13s %s", "ID", "NAME", "COLOR", "RENDERAMT");

  new count = 0;
  if (colors) {
    new Snapshot: keySet = TrieSnapshotCreate(colors);
    count = TrieSnapshotLength(keySet);
    
    new maxName;
    for (new i = 0, len; i < count; i++) {
      len = TrieSnapshotKeyBufferSize(keySet, i);
      maxName = max(maxName, len);
    }

    new headerFmt[32];
    formatex(headerFmt, charsmax(headerFmt), "%%3s %%4s %%%ds %%s", maxName);
    console_print(id, headerFmt, "#", "TRIE", "NAME", "COLOR (argb)");

    new fmt[32];
    formatex(fmt, charsmax(fmt), "%%2d. %%-4d %%%ds %%s", maxName);

    for (new i = 0, len; i < count; i++) {
      len = TrieSnapshotGetKey(keySet, i, key, charsmax(key));

      new Trie: color;
      TrieGetCell(colors, key, color);

      TrieGetString(color, BB_COLOR_ARGB, value, charsmax(value), len);

      console_print(id, fmt, i + 1, color, key, value);
    }

    TrieSnapshotDestroy(keySet);
  }

  console_print(id, "%d colors registered.", count);
  return PLUGIN_HANDLED;
}
#endif

/*******************************************************************************
 * Code
 ******************************************************************************/

public client_disconnected(id) {
  pColor[id] = Invalid_Trie;
}

bool: isColorRegistered(const Trie: color) {
  if (!color || !colors) {
    return false;
  }
  
  new len;
  TrieGetString(color, BB_COLOR_NAME, key, charsmax(key), len);
  
  new Trie: mapping;
  new bool: containsKey = TrieGetCell(colors, key, mapping);
  return containsKey && mapping == color;
}

Color: getUserColor(id) {
  // TODO: assertions
  return pColor[id];
}

public bb_onGrabbed(const id, const entity) {
  new const Color: color = getUserColor(id);
  if (color) {
    new Float: rgb[3], Float: alpha;
    TrieGetArray(color, BB_COLOR_RGB, rgb, sizeof rgb);
    TrieGetCell(color, BB_COLOR_ALPHA, alpha);
    
    entity_set_int(entity, EV_INT_rendermode, kRenderTransColor);
    entity_set_vector(entity, EV_VEC_rendercolor, rgb);
    entity_set_float(entity, EV_FL_renderamt, alpha);
  }
}

public bb_onDropped(const id, const entity) {
  new const Color: color = getUserColor(id);
  if (color) {
    entity_set_int(entity, EV_INT_rendermode, kRenderNormal);
  }
}

public bb_onLocked(const id, const entity) {
  new const Color: color = getUserColor(id);
  if (color) {
    new Float: rgb[3];
    TrieGetArray(color, BB_COLOR_RGB, rgb, sizeof rgb);
    
    entity_set_int(entity, EV_INT_rendermode, kRenderTransColor);
    entity_set_vector(entity, EV_VEC_rendercolor, rgb);
    entity_set_float(entity, EV_FL_renderamt, 255.0);
  }
}

public bb_onUnlocked(const id, const entity) {
  new const Color: color = getUserColor(id);
  if (color) {
    entity_set_int(entity, EV_INT_rendermode, kRenderNormal);
  }
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

static onColorRegistered = INVALID_HANDLE;
static onColorChanged = INVALID_HANDLE;

bb_onColorRegistered(name[], Trie: color) {
  if (onColorRegistered == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onColorRegistered");
#endif
    onColorRegistered = CreateMultiForward(
        "bb_onColorRegistered", ET_CONTINUE,
        FP_STRING, FP_CELL);
#if defined DEBUG_FORWARDS
    logd("onColorRegistered = %d", onColorRegistered);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onColorRegistered for %s", name);
#endif
  ExecuteForward(onColorRegistered, _, name, color);
}

bb_onColorChanged(id, Color: color, name[]) {
  if (onColorChanged == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    logd("Creating forward for bb_onColorChanged");
#endif
    onColorChanged = CreateMultiForward(
        "bb_onColorChanged", ET_CONTINUE,
        FP_CELL, FP_CELL, FP_STRING);
#if defined DEBUG_FORWARDS
    logd("onColorChanged = %d", onColorChanged);
#endif
  }

#if defined DEBUG_FORWARDS
  logd("Forwarding bb_onColorChanged(%d, %d, %s)", id, color, name);
#endif
  ExecuteForward(onColorChanged, _, id, color, name);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("bb_colors");

  register_native("bb_registerColor", "native_registerColor");
  register_native("bb_isColorRegistered", "native_isColorRegistered");
  register_native("bb_getNumColors", "native_getNumColors");
  register_native("bb_getColors", "native_getColors");
  register_native("bb_findColor", "native_findColor");

  register_native("bb_getUserColor", "native_getUserColor");
  register_native("bb_setUserColor", "native_setUserColor");
}

//native bool: bb_registerColor(const Trie: color, const bool: replace = true);
public bool: native_registerColor(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return false;
  }
#endif

  new const Trie: color = get_param(1);
  if (!color) {
    ThrowIllegalArgumentException("Invalid color specified: %d", color);
    return false;
  }

  new bool: keyExists, len;
  keyExists = TrieGetString(color, BB_COLOR_NAME, key, charsmax(key), len);
  if (!keyExists) {
    ThrowIllegalArgumentException("celltrie %d must contain a value for \"%s\"", color, BB_COLOR_NAME);
    return false;
  } else if (len == 0) {
    ThrowIllegalArgumentException("celltrie %d cannot have an empty value for \"%s\"", color, BB_COLOR_NAME);
    return false;
  }

  if (!colors) {
    colors = TrieCreate();
#if defined DEBUG_COLORS
    assert colors;
    logd("Initialized colors container as celltrie %d", colors);
#endif
  }

  new Trie: oldColor;
  keyExists = TrieGetCell(colors, key, oldColor);
  parseResource(key, value, charsmax(value));

  new const bool: replace = get_param(2);
  if (keyExists) {
    if (!replace) {
      ThrowIllegalArgumentException("Color named [%s] \"%s\" already exists!", key, value);
      return false;
#if defined WARN_ON_COLOR_OVERWRITE
    } else {
      logw("Overwriting color [%s] \"%s\" (%d -> %d)", key, value, oldColor, color);
#endif
    }
  }

  TrieSetCell(colors, key, color, replace);

#if defined DEBUG_COLORS
  new dst[2048];
  TrieToString(color, dst, charsmax(dst));
  logd("Color: %s", dst);
  logd("Registered color [%s] \"%s\" as Trie: %d", key, value, color);
#endif
  
  bb_onColorRegistered(key, color);
  return true;
}

//native bool: bb_isColorRegistered(const Trie: color);
public bool: native_isColorRegistered(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return false;
  }
#endif

  new const Trie: color = get_param(1);
  return isColorRegistered(color);
}

//native bb_getNumColors();
public native_getNumColors(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {}
#endif

  if (!colors) {
    return 0;
  }

  return TrieGetSize(colors);
}

//native Array: bb_getColors(const Array: dst = Invalid_Array);
public Array: native_getColors(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return Invalid_Array;
  }
#endif

  new Array: dst = get_param(1);
  if (dst) {
#if defined DEBUG_NATIVES
    logd("clearing input cellarray %d", dst);
#endif
    ArrayClear(dst);
  } else {
    dst = ArrayCreate();
#if defined DEBUG_NATIVES
    logd("dst cellarray initialized as cellarray %d", dst);
#endif
  }
  
  if (!colors) {
    return dst;
  }

  new Snapshot: keySet = TrieSnapshotCreate(colors);
  new const count = TrieSnapshotLength(keySet);
  for (new i = 0, Trie: color; i < count; i++) {
    TrieSnapshotGetKey(keySet, i, key, charsmax(key));
    TrieGetCell(colors, key, color);
    ArrayPushCell(dst, color);
#if defined DEBUG_NATIVES
    logd("dst[%d]=%d:[%s]", i, color, key);
#endif
  }

  TrieSnapshotDestroy(keySet);
  return dst;
}

//native Trie: bb_findColor(const name[]);
public Trie: native_findColor(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return Invalid_Trie;
  }
#endif

  if (!colors) {
    logw("Calling zm_findColor before any colors have been registered");
    return Invalid_Trie;
  }

  new len = get_string(1, key, charsmax(key));
  key[len] = EOS;

  new Trie: color;
  new bool: keyExists = TrieGetCell(colors, key, color);
  if (!keyExists) {
    return Invalid_Trie;
  }

  return color;
}

//native Trie: bb_getUserColor(const id);
public Trie: native_getUserColor(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!is_user_connected(id)) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return Invalid_Trie;
  }
  
  return getUserColor(id);
}

//native Trie: bb_setUserColor(const id, const Trie: color);
public Trie: native_setUserColor(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!is_user_connected(id)) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return Invalid_Trie;
  }

  new const Trie: color = get_param(2);
#if !defined INVALID_TRIE_WILL_RESET_COLOR
  if (!color) {
    ThrowIllegalArgumentException("Invalid color specified: %d", color);
    return Invalid_Trie;
  }
#endif

#if defined ENFORCE_REGISTERED_COLORS_ONLY
#if defined INVALID_TRIE_WILL_RESET_COLOR
  if (color != Invalid_Trie && !isColorRegistered(color)) {
#else
  if (!isColorRegistered(color)) {
#endif
    ThrowIllegalArgumentException("Cannot assign player to an unregistered color: %d", color);
    return Invalid_Trie;
  }
#endif

  new const Trie: oldColor = pColor[id];
  if (color == oldColor) {
#if defined DEGUG_COLORS
    logd("color unchanged for %N, ignoring", id);
#endif
    return oldColor;
  }

#define newColorName key
#if defined INVALID_TRIE_WILL_RESET_COLOR
  if (color) {
    TrieGetString(color, BB_COLOR_NAME, newColorName, charsmax(newColorName));
  } else {
    copy(newColorName, charsmax(newColorName), NULL);
  }
#else
  TrieGetString(color, BB_COLOR_NAME, newColorName, charsmax(newColorName));
#endif

#if defined DEBUG_FORWARDS || defined DEGUG_COLORS
  new oldColorName[32];
  if (oldColor) {
    TrieGetString(oldColor, BB_COLOR_NAME, oldColorName, charsmax(oldColorName));
  } else {
    copy(oldColorName, charsmax(oldColorName), NULL);
  }
#endif

  pColor[id] = color;
  bb_onColorChanged(id, color, newColorName);

#if defined DEGUG_COLORS
  logd("%N changed color from %s to %s",
      id, oldColorName, newColorName);
#endif
#undef newColorName
  return oldColor;
}
