#include <amxmodx>
#include <amxmisc>
#include <logger>
#include <reapi>

#include "include/stocks/precache_stocks.inc"

#include "include/bb/basebuilder.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "Announcer"
#define VERSION_STRING "1.0.0"

static const PHASE_BUILD[] = "bb/phase_build.wav";
static const PHASE_PREP[]  = "bb/phase_prep.wav";
static const PHASE_RELEASE[][] = {
  "bb/round_start1.wav",
  "bb/round_start2.wav"
};

static const BUILDERS_WIN[][] = {
  "bb/win_builders2.wav"
};
static const ZOMBIES_WIN[][] = {
  "bb/win_zombies2.wav"
};

static const BLOCK_GRAB[] = "bb/block_grab.wav";
static const BLOCK_DROP[] = "bb/block_drop.wav";

public zm_onPrecache() {
  precacheSound(PHASE_BUILD);
  precacheSound(PHASE_PREP);
  for (new i = 0; i < sizeof PHASE_RELEASE; i++) {
    precacheSound(PHASE_RELEASE[i]);
  }
  for (new i = 0; i < sizeof BUILDERS_WIN; i++) {
    precacheSound(BUILDERS_WIN[i]);
  }
  for (new i = 0; i < sizeof ZOMBIES_WIN; i++) {
    precacheSound(ZOMBIES_WIN[i]);
  }
  precacheSound(BLOCK_GRAB);
  precacheSound(BLOCK_DROP);
}

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
      .desc = "Announces BB events, such as phase changes");

  register_event_ex("TextMsg", "onBuildersWin", RegisterEvent_Global, "2=Builders_Win");
  register_event_ex("TextMsg", "onZombiesWin", RegisterEvent_Global, "2=Zombies_Win");
}

public onBuildersWin() {
  rg_send_audio(0, BUILDERS_WIN[random(sizeof BUILDERS_WIN)]);
}

public onZombiesWin() {
  rg_send_audio(0, ZOMBIES_WIN[random(sizeof ZOMBIES_WIN)]);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public bb_onGameStateChanged(const GameState: fromState, const GameState: toState) {
  switch (toState) {
    case BuildPhase: {
      rg_send_audio(0, PHASE_BUILD);
      // TODO: Configure with correct time
      // TODO: Create bb_getRoundTime() + bb_getPrepTime()
      //client_cmd(0, "spk \"perimeter defense failure in %s minutes\"", "three");
    }
    case PrepPhase:  {
      rg_send_audio(0, PHASE_PREP);
      // TODO: Configure with correct time
      // TODO: Create bb_getRoundTime()
      //client_cmd(0, "spk \"containment breach in %s seconds\"", "thirty");
    }
    case Released:   rg_send_audio(0, PHASE_RELEASE[random(sizeof PHASE_RELEASE)]);
  }
}

public bb_onRoundTimerUpdated(const timeleft, const GameState: gameState) {
  static mins, secs, tens;
  if (gameState == RoundStarting) {
    return;
  }

  tens = timeleft % 10;
  if (tens == 0) {
    mins = timeleft / 600;
    secs = timeleft % 600 / 10;
    announce(0, mins, secs);
  }
}

public bb_onRespawnTimerUpdated(const id, const timeleft) {
  static secs, tens;
  tens = timeleft % 10;
  if (tens == 0) {
    secs = timeleft / 10;
    announce(id, 0, secs);
  }
}

announce(id, mins, secs) {
  if (mins && !secs) {
    new timelength[32];
    num_to_word(mins, timelength, charsmax(timelength));
    client_cmd(id, "spk \"fvox/%s minutes remaining\"", timelength);
  } else if (!mins && secs == 30) {
    new timelength[32];
    num_to_word(secs, timelength, charsmax(timelength));
    client_cmd(id, "spk \"fvox/%s seconds remaining\"", timelength);
  } else if (!mins && secs < 11) {
    new timelength[32];
    num_to_word(secs, timelength, charsmax(timelength));
    client_cmd(id, "spk \"fvox/%s\"", timelength);
  }
}

public bb_onGrabbed(const id, const entity) {
  rg_send_audio(id, BLOCK_GRAB);
}

public bb_onDropped(const id, const entity) {
  rg_send_audio(id, BLOCK_DROP);
}
