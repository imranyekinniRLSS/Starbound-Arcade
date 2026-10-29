 #pragma once

#ifdef STELLAR_CORE_EXPORTS
#define STELLAR_CORE_API extern "C" __declspec(dllexport)
#else
#define STELLAR_CORE_API extern "C"
#endif

constexpr int STELLAR_WIDTH = 42;
constexpr int STELLAR_HEIGHT = 18;
constexpr int STELLAR_MAX_ROCKS = 16;
constexpr int STELLAR_MAX_SHOTS = 8;
constexpr int STELLAR_WIN_SCORE = 20;

enum StellarCommand {
    STELLAR_NO_COMMAND,
    STELLAR_MOVE_LEFT,
    STELLAR_MOVE_RIGHT,
    STELLAR_FIRE,
    STELLAR_TOGGLE_PAUSE
};

enum StellarDifficulty {
    STELLAR_EASY,
    STELLAR_NORMAL,
    STELLAR_HARD
};

struct StellarGameState {
    int playerX;
    int score;
    int lives;
    int tick;
    int gameOver;
    int won;
    int paused;
    int difficulty;
    int shieldTicks;
    int rockCount;
    int rockX[STELLAR_MAX_ROCKS];
    int rockY[STELLAR_MAX_ROCKS];
    int rockType[STELLAR_MAX_ROCKS];
    int rockHealth[STELLAR_MAX_ROCKS];
    int shotCount;
    int shotX[STELLAR_MAX_SHOTS];
    int shotY[STELLAR_MAX_SHOTS];
    int powerupActive;
    int powerupX;
    int powerupY;
    unsigned int randomSeed;
    int nextShotTick;
};

STELLAR_CORE_API void stellar_reset(StellarGameState* state, unsigned int seed);
STELLAR_CORE_API int stellar_set_difficulty(StellarGameState* state, int difficulty);
STELLAR_CORE_API void stellar_step(StellarGameState* state, int command);
