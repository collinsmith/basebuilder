#if defined _bb_director_const_included
    #endinput
#endif
#define _bb_director_const_included

/** Message sent when the builder team wins */
stock const Builders_Win[] = "Builders_Win";
/** Message sent when the zombie team wins */
stock const Zombies_Win[] = "Zombies_Win";

/**
 * Defines constants used to represent the current state of a Base Builder round.
 */
enum GameState {
  /** The game state has not yet been set up */
  Invalid_GameState = 0,
  /** The game is preparing to start, during freeze time */
  RoundStarting,
  /** Zombies are locked up and the Humans can start building their bases */
  BuildPhase,
  /** Zombies are locked up and Humans must test their bases */
  PrepPhase,
  /** Zombies are released and round begins */
  Released,
  /** The time limit has expired and a new round is about to begin */
  RoundEnding
}

stock const GAME_STATES[GameState][] = {
  "Invalid_GameState", "RoundStarting", "BuildPhase", "PrepPhase", "Released", "RoundEnding"
};
