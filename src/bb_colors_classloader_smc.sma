#include <amxmodx>
#include <logger>

#include "include/classloader/classloader.inc"

#include "include/stocks/param_stocks.inc"

#include "include/bb/basebuilder.inc"
#include "include/bb/bb_colors.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_LOADER
  #define DEBUG_PARSER
#else
  //#define DEBUG_LOADER
  //#define DEBUG_PARSER
#endif

#define EXTENSION_NAME "BB Colors Class Loader: smc"
#define VERSION_STRING "1.0.0"

static Trie: color;
static colorsLoaded;

public zm_onInit() {
  LoadLogger(bb_getPluginId());
  cl_registerClassLoader("onLoadClass", "smc");
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
      .desc = "Loads colors from SMC files");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onLoadClass(const path[], const extension[]) {
  // TODO: This can maybe be cleaned up a bit
  new tmp[PLATFORM_MAX_PATH];
  getFileParentPath(tmp, charsmax(tmp), path);
  getFileName(tmp, charsmax(tmp), tmp);
  if (!equal(tmp, "colors")) {
    return;
  }
  
#if defined DEBUG_LOADER
  logd("Attempting to parse \"%s\" as an SMC class file...", path);
#endif

  colorsLoaded = 0;
  new SMCParser: parser = SMC_CreateParser();
  SMC_SetReaders(parser, "onKeyValue", "onNewSection", "onEndSection");

  new line, col;
  new SMCError: error = SMC_ParseFile(parser, path, line, col);
  SMC_DestroyParser(parser);
  if (error) {
    new errorMsg[256];
    SMC_GetErrorString(error, errorMsg, charsmax(errorMsg));
    loge("Error at line %d, col %d: %s", line, col, errorMsg);
    return;
  }

#if defined DEBUG_LOADER
  logd("Loaded %d colors", colorsLoaded);
#endif
}

public SMCResult: onNewSection(SMCParser: handle, const name[]) {
  if (color) {
    loge("color definitions cannot contain inner-sections");
    return SMCParse_HaltFail;
  }

  color = TrieCreate();
  TrieSetString(color, BB_COLOR_NAME, name);
#if defined DEBUG_PARSER
  logd("creating new color: %d [%s]", color, name);
#endif
  return SMCParse_Continue;
}

stock Float: operator=(value) return float(value);

public SMCResult: onEndSection(SMCParser: handle) {
#if defined DEBUG_PARSER
  logd("registering color %d", color);
#endif
  
  new name[32];
  TrieGetString(color, BB_COLOR_NAME, name, charsmax(name));

  new value[32];
  if (TrieGetString(color, BB_COLOR_ARGB, value, charsmax(value))) {
    new const argb = parseColor(value);
    logd("argb=%X", argb); 
    
    new Float: rgb[3];
    rgb[0] = r(argb);
    rgb[1] = g(argb);
    rgb[2] = b(argb);
    TrieSetArray(color, BB_COLOR_RGB, rgb, sizeof rgb);
#if defined DEBUG_PARSER
    logd("rgb={%.0f,%.0f,%.0f}", rgb[0], rgb[1], rgb[2]); 
#endif
    
    new Float: alpha = a(argb);
    TrieSetCell(color, BB_COLOR_ALPHA, alpha);
#if defined DEBUG_PARSER
    logd("alpha=%.0f", alpha); 
#endif
  } else {
  // TODO: Support for rgb/alpha too, argb takes precedence and overrides settings
    loge("Unknown color: %s", name);
    return SMCParse_HaltFail;
  }
  
  bb_registerColor(color);
  colorsLoaded++;
  color = Invalid_Trie;
  return SMCParse_Continue;
}

strtolong(const str[], &len) {
  new num = 0;
  for (len = 0; str[len] != EOS; len++) {
    new c = str[len];
    if ('a' <= c <= 'f') {
      c = c - 'a' + 10;
      num = (num << 4) | c;
    } else if ('A' <= c <= 'F') {
      c = c - 'A' + 10;
      num = (num << 4) | c;
    } else if ('0' <= c <= '9') {
      c -= '0';
      num = (num << 4) | c;
    }
  }
  
  return num;
}

parseColor(str[]) {
  if (str[0] == '#') {
    new len;
    new color = strtolong(str[1], len);
    //new color = strtol(str[1], len, .base = 16);
    if (len == 6) {
      color |= 0xFF000000;
    } else if (len != 8) {
      ThrowIllegalArgumentException("Unknown color: %s", str);
      return 0;
    }
    
    return color;
  } else {
    // TODO: support named colors?
  }
  
  ThrowIllegalArgumentException("Unknown color: %s", str);
  return 0;
}

a(const color) {
  return color >>> 24;
}

r(const color) {
  return (color >> 16) & 0xFF;
}

g(const color) {
  return (color >> 8) & 0xFF;
}

b(const color) {
  return color & 0xFF;
}

public SMCResult: onKeyValue(SMCParser: handle, const key[], const value[]) {
  if (!color) {
    loge("cannot have key-value pair outside of section");
    return SMCParse_HaltFail;
  }

  TrieSetString(color, key, value);
#if defined DEBUG_PARSER
  logd("%d [%s]=\"%s\"", color, key, value);
#endif
  return SMCParse_Continue;
}
