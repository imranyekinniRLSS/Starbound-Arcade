#include "stellar_core.h"

#include <cassert>

int main() {
    StellarGameState state = {};
    stellar_reset(&state, 123);
    assert(state.playerX == STELLAR_WIDTH / 2);
    assert(state.lives == 3);
    assert(state.difficulty == STELLAR_NORMAL);
    assert(stellar_set_difficulty(&state, 9) == 0);
    assert(stellar_set_difficulty(&state, STELLAR_HARD) == 1);
    assert(state.difficulty == STELLAR_HARD);

    const int initialX = state.playerX;
    stellar_step(&state, STELLAR_TOGGLE_PAUSE);
    stellar_step(&state, STELLAR_MOVE_LEFT);
    assert(state.paused == 1);
    assert(state.tick == 0);
    assert(state.playerX == initialX);
    stellar_step(&state, STELLAR_TOGGLE_PAUSE);
    stellar_step(&state, STELLAR_MOVE_LEFT);
    assert(state.paused == 0);
    assert(state.tick == 1);
    assert(state.playerX == initialX - 1);

    stellar_reset(&state, 1);
    stellar_set_difficulty(&state, STELLAR_EASY);
    for (int tick = 0; tick < 5; ++tick) stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.rockCount == 0);
    stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.rockCount == 1);

    stellar_reset(&state, 1);
    stellar_set_difficulty(&state, STELLAR_HARD);
    for (int tick = 0; tick < 3; ++tick) stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.rockCount == 1);
    assert(state.rockY[0] == 2);

    stellar_reset(&state, 1);
    state.rockCount = 1;
    state.rockX[0] = state.playerX;
    state.rockY[0] = 5;
    state.rockType[0] = 2;
    state.rockHealth[0] = 2;
    state.shotCount = 1;
    state.shotX[0] = state.playerX;
    state.shotY[0] = 6;
    stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.rockCount == 1);
    assert(state.rockHealth[0] == 1);
    assert(state.score == 0);

    state.shotCount = 1;
    state.shotX[0] = state.playerX;
    state.shotY[0] = 7;
    stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.rockCount == 0);
    assert(state.score == 1);

    stellar_reset(&state, 1);
    state.powerupActive = 1;
    state.powerupX = state.playerX;
    state.powerupY = STELLAR_HEIGHT - 3;
    stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.powerupActive == 0);
    assert(state.shieldTicks > 0);
    assert(state.score == 1);

    stellar_reset(&state, 1);
    state.shieldTicks = 1;
    state.rockCount = 1;
    state.rockX[0] = state.playerX;
    state.rockY[0] = STELLAR_HEIGHT - 2;
    state.rockHealth[0] = 1;
    stellar_step(&state, STELLAR_NO_COMMAND);
    assert(state.lives == 3);
    assert(state.rockCount == 0);
    assert(state.shieldTicks == 0);
}
