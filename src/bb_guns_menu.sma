#include <amxmodx>
#include <logger>
#include <reapi>

#include "include/stocks/param_stocks.inc"

#include "include/bb/basebuilder.inc"

#define EXTENSION_NAME "Guns Menu"
#define VERSION_STRING "1.0.0"

#define GUNS_DICTIONARY "zm_guns.txt"

static const g_szWpnEntNames[][] = {
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};

static g_Menu_SecWeapon;
static g_Menu_PrimWeapon;

public zm_onInit() {
  LoadLogger(bb_getPluginId());
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, BB_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");
  
  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = name,
      .version = buildId,
      .desc = "Manages the gun menu");

  register_dictionary(GUNS_DICTIONARY);
#if defined DEBUG_I18N
  logd("Registered dictionary \"%s\"", GUNS_DICTIONARY);
#endif

  createMenus();
  register_event_ex("AmmoX", "ev_AmmoX", RegisterEvent_Single | RegisterEvent_OnlyAlive);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public plugin_natives() {
  register_library("bb_guns_menu");

  register_native("bb_showGunsMenu", "native_showGunsMenu");
}

public ev_AmmoX(id) {
  set_member(id, m_rgAmmo, 200, read_data(1));
}

createMenus() {
  createPrimaryMenu();
  createSecondaryMenu();
}

createPrimaryMenu() {
  new szTemp[32];
  g_Menu_PrimWeapon = menu_create("Choose a Primary Weapon:", "weaponMenuHandler");
  menu_setprop(g_Menu_PrimWeapon, MPROP_EXIT, MEXIT_NEVER);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SCOUT]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SCOUT]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_XM1014]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_XM1014]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_MAC10]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_MAC10]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AUG]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AUG]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_UMP45]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_UMP45]);
  //formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SG550]);
  //menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SG550]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_GALIL]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_GALIL]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_FAMAS]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_FAMAS]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AWP]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AWP]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_MP5NAVY]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_MP5NAVY]);
  //formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M249]);
  //menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M249]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M3]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M3]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_M4A1]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_M4A1]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_TMP]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_TMP]);
  //formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_G3SG1]);
  //menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_G3SG1]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_SG552]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_SG552]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_AK47]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_AK47]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_P90]);
  menu_additem(g_Menu_PrimWeapon, szTemp, g_szWpnEntNames[CSW_P90]);
}

createSecondaryMenu() {
  new szTemp[32];
  g_Menu_SecWeapon = menu_create("Choose a Secondary Weapon:", "weaponMenuHandler");
  menu_setprop(g_Menu_SecWeapon, MPROP_EXIT, MEXIT_NEVER);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_P228]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_P228]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_USP]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_USP]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_GLOCK18]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_GLOCK18]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_DEAGLE]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_DEAGLE]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_FIVESEVEN]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_FIVESEVEN]);
  formatex(szTemp, 31, "%L", LANG_SERVER, g_szWpnEntNames[CSW_ELITE]);
  menu_additem(g_Menu_SecWeapon, szTemp, g_szWpnEntNames[CSW_ELITE]);
}

public weaponMenuHandler(id, menu, item) {
  if (item == MENU_EXIT) {
    return PLUGIN_HANDLED;
  }

  static weapon[32], trash;
  menu_item_getinfo(menu, item, trash, weapon, charsmax(weapon), _, _, trash);
  rg_give_item(id, weapon);

  if (menu == g_Menu_SecWeapon) {
    menu_display(id, g_Menu_PrimWeapon);
  }

  return PLUGIN_HANDLED;
}

bool: showGunsMenu(id) {
  menu_display(id, g_Menu_SecWeapon);
  return true;
}

//native bool: bb_showGunsMenu(const id);
public bool: native_showGunsMenu(plugin, numParams) {
  if (!numParamsEqual(1, numParams)) {
    return false;
  }

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  }

  return showGunsMenu(id);
}
