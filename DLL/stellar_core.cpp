#include "stellar_core.h"

namespace {
void removeRock(StellarGameState* state, int index) {
    --state->rockCount;
    state->rockX[index] = state->rockX[state->rockCount];
    state->rockY[index] = state->rockY[state->rockCount];
    state->rockType[index] = state->rockType[state->rockCount];
    state->rockHealth[index] = state->rockHealth[state->rockCount];
}

void removeShot(StellarGameState* state, int index) {
    --state->shotCount;
    state->shotX[index] = state->shotX[state->shotCount];
    state->shotY[index] = state->shotY[state->shotCount];
}

unsigned int nextRandom(StellarGameState* state) {
    state->randomSeed = state->randomSeed * 1664525u + 1013904223u;
    return state->randomSeed;
}
}

STELLAR_CORE_API void stellar_reset(StellarGameState* state, unsigned int seed) {
    if (!state) {
        return;
    }

    *state = {};
    state->playerX = STELLAR_WIDTH / 2;
    state->lives = 3;
    state->difficulty = STELLAR_NORMAL;
    state->randomSeed = seed ? seed : 1;
}

STELLAR_CORE_API int stellar_set_difficulty(StellarGameState* state, int difficulty) {
    if (!state) {
        return 0;
    }

    if (difficulty < STELLAR_EASY || difficulty > STELLAR_HARD) {
        return 0;
    }

    state->difficulty = difficulty;
    return 1;
}

STELLAR_CORE_API void stellar_step(StellarGameState* state, int command) {
    if (!state || state->gameOver) {
        return;
    }

    if (command == STELLAR_TOGGLE_PAUSE) {
        state->paused = !state->paused;
        return;
    }
    if (state->paused) {
        return;
    }

    ++state->tick;

    if (command == STELLAR_MOVE_LEFT && state->playerX > 1) {
        --state->playerX;
    } else if (command == STELLAR_MOVE_RIGHT && state->playerX < STELLAR_WIDTH - 2) {
        ++state->playerX;
    } else if (command == STELLAR_FIRE &&
        state->tick >= state->nextShotTick &&
        state->shotCount < STELLAR_MAX_SHOTS) {
        const int shot = state->shotCount++;
        state->shotX[shot] = state->playerX;
        state->shotY[shot] = STELLAR_HEIGHT - 3;
        state->nextShotTick = state->tick + 3;
    }

    if (state->powerupActive) {
        ++state->powerupY;
        if (state->powerupY >= STELLAR_HEIGHT - 2) {
            if (state->powerupX == state->playerX) {
                state->shieldTicks = 30;
                ++state->score;
            }
            state->powerupActive = 0;
        }
    }

    for (int i = 0; i < state->shotCount;) {
        --state->shotY[i];
        if (state->shotY[i] <= 0) {
            removeShot(state, i);
        } else {
            ++i;
        }
    }

    const int spawnInterval = state->difficulty == STELLAR_EASY ? 6
        : state->difficulty == STELLAR_HARD ? 3 : 4;
    if (state->tick % spawnInterval == 0 && state->rockCount < STELLAR_MAX_ROCKS) {
        const int rock = state->rockCount++;
        state->rockX[rock] = 1 + static_cast<int>(nextRandom(state) % (STELLAR_WIDTH - 2));
        state->rockY[rock] = 1;
        const unsigned int typeRoll = nextRandom(state) % 5;
        state->rockType[rock] = typeRoll == 0 ? 2 : typeRoll == 1 ? 1 : 0;
        state->rockHealth[rock] = state->rockType[rock] == 2 ? 2 : 1;
    }

    const int fallInterval = state->difficulty == STELLAR_EASY ? 3
        : state->difficulty == STELLAR_HARD ? 1 : 2;
    for (int i = 0; i < state->rockCount;) {
        if (state->rockType[i] == 1 || state->tick % fallInterval == 0) {
            ++state->rockY[i];
            if (state->rockY[i] >= STELLAR_HEIGHT - 1) {
                removeRock(state, i);
                continue;
            }
        }
        ++i;
    }

    for (int shot = 0; shot < state->shotCount;) {
        bool removed = false;
        for (int rock = 0; rock < state->rockCount; ++rock) {
            if (state->shotX[shot] == state->rockX[rock] &&
                state->shotY[shot] == state->rockY[rock]) {
                removeShot(state, shot);
                --state->rockHealth[rock];
                if (state->rockHealth[rock] <= 0) {
                    const int dropPowerup = nextRandom(state) % 6 == 0;
                    const int dropX = state->rockX[rock];
                    const int dropY = state->rockY[rock];
                    removeRock(state, rock);
                    ++state->score;
                    if (dropPowerup && !state->powerupActive) {
                        state->powerupActive = 1;
                        state->powerupX = dropX;
                        state->powerupY = dropY;
                    }
                }
                removed = true;
                break;
            }
        }
        if (!removed) {
            ++shot;
        }
    }

    for (int rock = 0; rock < state->rockCount;) {
        if (state->rockX[rock] == state->playerX &&
            state->rockY[rock] == STELLAR_HEIGHT - 2) {
            removeRock(state, rock);
            if (state->shieldTicks > 0) {
                state->shieldTicks = 0;
            } else {
                --state->lives;
                if (state->lives <= 0) {
                    state->gameOver = 1;
                }
            }
        } else {
            ++rock;
        }
    }

    if (state->shieldTicks > 0) {
        --state->shieldTicks;
    }
    if (state->score >= STELLAR_WIN_SCORE) {
        state->gameOver = 1;
        state->won = 1;
    }
}
