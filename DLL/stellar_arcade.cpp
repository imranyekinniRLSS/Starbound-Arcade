#include "stellar_core.h"

#include <conio.h>
#include <windows.h>

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>

namespace {
using ResetFunction = void(*)(StellarGameState*, unsigned int);
using SetDifficultyFunction = int(*)(StellarGameState*, int);
using StepFunction = void(*)(StellarGameState*, int);

std::string getExecutableDirectory() {
    char executablePath[MAX_PATH] = {};
    const DWORD length = GetModuleFileNameA(nullptr, executablePath, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) {
        return {};
    }

    std::string path(executablePath, length);
    const size_t separator = path.find_last_of("\\/");
    path.resize(separator == std::string::npos ? 0 : separator + 1);
    return path;
}

int chooseDifficulty() {
    std::system("cls");
    std::cout << "NEBULA RUN: DEEP SPACE\n\n"
        << "Choose a difficulty:\n"
        << "  1. Easy\n"
        << "  2. Normal\n"
        << "  3. Hard\n"
        << "  Q. Quit\n";
    while (true) {
        const int key = _getch();
        if (key == '1') return STELLAR_EASY;
        if (key == '2') return STELLAR_NORMAL;
        if (key == '3') return STELLAR_HARD;
        if (key == 'q' || key == 'Q') return -1;
    }
}

bool saveHighScore(const std::string& path, int highScore) {
    std::ofstream file(path, std::ios::trunc);
    if (!file) return false;
    file << highScore << '\n';
    file.close();
    return file.good();
}

void render(const StellarGameState& state, HANDLE console, int highScore, bool soundEnabled, bool highScoreSaveFailed) {
    char screen[STELLAR_HEIGHT][STELLAR_WIDTH];
    for (int y = 0; y < STELLAR_HEIGHT; ++y) {
        for (int x = 0; x < STELLAR_WIDTH; ++x) {
            screen[y][x] = (x == 0 || x == STELLAR_WIDTH - 1 || y == 0 || y == STELLAR_HEIGHT - 1)
                ? '#'
                : ' ';
        }
    }

    for (int i = 0; i < state.rockCount; ++i) {
        const char rockGlyph = state.rockType[i] == 1 ? 'v' : state.rockType[i] == 2 ? '@' : 'O';
        screen[state.rockY[i]][state.rockX[i]] = rockGlyph;
    }
    for (int i = 0; i < state.shotCount; ++i) {
        screen[state.shotY[i]][state.shotX[i]] = '|';
    }
    if (state.powerupActive && state.powerupY > 0 && state.powerupY < STELLAR_HEIGHT - 1) {
        screen[state.powerupY][state.powerupX] = '+';
    }
    screen[STELLAR_HEIGHT - 2][state.playerX] = state.shieldTicks > 0 ? '*' : '^';

    COORD origin = {0, 0};
    SetConsoleCursorPosition(console, origin);
    std::cout << "             NEBULA RUN: DEEP SPACE             \n";
    std::cout << " Score: " << state.score << " / " << STELLAR_WIN_SCORE
              << "    Best: " << highScore
              << "    Hull: " << state.lives
              << "    " << (state.difficulty == STELLAR_EASY ? "Easy" : state.difficulty == STELLAR_HARD ? "Hard" : "Normal")
              << "    Sound: " << (soundEnabled ? "On" : "Off") << '\n';
    std::cout << " A/D or arrows: move   Space: fire   P: pause   M: sound   Q: quit\n";
    std::cout << " Copyright (c) 2026 Starbound Developing Ink. All rights reserved.\n";
    for (int y = 0; y < STELLAR_HEIGHT; ++y) {
        std::cout.write(screen[y], STELLAR_WIDTH);
        std::cout << '\n';
    }

    if (state.paused) {
        std::cout << "Paused. Press P to resume or Q to quit.                   \n";
    } else if (state.gameOver) {
        std::cout << (state.won ? "Sector cleared! You win! " : "Ship lost. Game over. ");
        std::cout << "Press R to play again or Q to quit.          \n";
    } else {
        std::cout << (state.shieldTicks > 0
            ? "Shield active! Collect + for a shield.                    \n"
            : "Blast asteroids. Fast v, armored @, shield +.           \n");
    }
    if (highScoreSaveFailed) {
        std::cout << "Could not save the high score beside the game.          \n";
    }
    std::cout.flush();
}

int readCommand(bool& quit, bool& soundEnabled) {
    if (!_kbhit()) {
        return STELLAR_NO_COMMAND;
    }

    const int key = _getch();
    if (key == 0 || key == 224) {
        const int arrow = _getch();
        if (arrow == 75) {
            return STELLAR_MOVE_LEFT;
        }
        if (arrow == 77) {
            return STELLAR_MOVE_RIGHT;
        }
        return STELLAR_NO_COMMAND;
    }

    if (key == 'a' || key == 'A') {
        return STELLAR_MOVE_LEFT;
    }
    if (key == 'd' || key == 'D') {
        return STELLAR_MOVE_RIGHT;
    }
    if (key == ' ') {
        return STELLAR_FIRE;
    }
    if (key == 'p' || key == 'P') {
        return STELLAR_TOGGLE_PAUSE;
    }
    if (key == 'm' || key == 'M') {
        soundEnabled = !soundEnabled;
        return STELLAR_NO_COMMAND;
    }
    if (key == 'q' || key == 'Q') {
        quit = true;
    }
    return STELLAR_NO_COMMAND;
}
}

int main() {
    const std::string executableDirectory = getExecutableDirectory();
    if (executableDirectory.empty()) {
        std::cerr << "Could not determine the executable path.\n";
        return 1;
    }

    const std::string dllPath = executableDirectory + "stellar_core.dll";
    HMODULE library = LoadLibraryA(dllPath.c_str());
    if (!library) {
        std::cerr << "Could not load " << dllPath << " (Windows error "
                  << GetLastError() << ").\n";
        return 1;
    }

    const auto reset = reinterpret_cast<ResetFunction>(
        GetProcAddress(library, "stellar_reset"));
    const auto setDifficulty = reinterpret_cast<SetDifficultyFunction>(
        GetProcAddress(library, "stellar_set_difficulty"));
    const auto step = reinterpret_cast<StepFunction>(
        GetProcAddress(library, "stellar_step"));
    if (!reset || !setDifficulty || !step) {
        std::cerr << "The game DLL is missing a required function.\n";
        FreeLibrary(library);
        return 1;
    }

    HANDLE console = GetStdHandle(STD_OUTPUT_HANDLE);
    if (console == INVALID_HANDLE_VALUE || console == nullptr) {
        std::cerr << "Could not access the console.\n";
        FreeLibrary(library);
        return 1;
    }

    CONSOLE_CURSOR_INFO cursorInfo = {};
    if (GetConsoleCursorInfo(console, &cursorInfo)) {
        cursorInfo.bVisible = FALSE;
        SetConsoleCursorInfo(console, &cursorInfo);
    }

    StellarGameState state = {};
    int highScore = 0;
    const std::string highScorePath = executableDirectory + "stellar_highscore.txt";
    {
        std::ifstream scoreFile(highScorePath);
        if (scoreFile >> highScore && highScore < 0) {
            highScore = 0;
        }
    }

    int difficulty = chooseDifficulty();
    if (difficulty < 0) {
        cursorInfo.bVisible = TRUE;
        SetConsoleCursorInfo(console, &cursorInfo);
        FreeLibrary(library);
        return 0;
    }
    reset(&state, GetTickCount());
    if (!setDifficulty(&state, difficulty)) {
        std::cerr << "Could not set the selected game difficulty.\n";
        FreeLibrary(library);
        return 1;
    }
    std::system("cls");

    bool quit = false;
    bool soundEnabled = true;
    bool highScoreSaveFailed = false;
    while (!quit) {
        if (state.gameOver) {
            render(state, console, highScore, soundEnabled, highScoreSaveFailed);
            while (!_kbhit()) {
                Sleep(30);
            }
            const int key = _getch();
            if (key == 'q' || key == 'Q') {
                quit = true;
            } else if (key == 'r' || key == 'R') {
                difficulty = chooseDifficulty();
                if (difficulty < 0) {
                    quit = true;
                    continue;
                }
                reset(&state, GetTickCount());
                if (!setDifficulty(&state, difficulty)) {
                    std::cerr << "Could not set the selected game difficulty.\n";
                    quit = true;
                }
            }
            continue;
        }

        const int previousScore = state.score;
        const int previousLives = state.lives;
        const int previousShield = state.shieldTicks;
        const int command = readCommand(quit, soundEnabled);
        if (quit) {
            break;
        }

        step(&state, command);
        if (state.score > previousScore) {
            if (state.score > highScore) {
                highScore = state.score;
                highScoreSaveFailed = !saveHighScore(highScorePath, highScore);
            }
            if (soundEnabled) Beep(880, 35);
        } else if (state.lives < previousLives) {
            if (soundEnabled) Beep(220, 80);
        } else if (state.shieldTicks > previousShield && soundEnabled) {
            Beep(1200, 45);
        }
        render(state, console, highScore, soundEnabled, highScoreSaveFailed);
        Sleep(100);
    }

    cursorInfo.bVisible = TRUE;
    SetConsoleCursorInfo(console, &cursorInfo);
    FreeLibrary(library);
    return 0;
}
