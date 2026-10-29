# Native game and DLL

The native Nebula Run game loads `stellar_core.dll` from the same folder as
`stellar_arcade.exe`. The DLL exports the game reset, difficulty, and simulation
functions; keep `stellar_core.h`, `stellar_core.cpp`, and `stellar_arcade.cpp`
together when building.

From a Visual Studio Developer Command Prompt or a terminal with MinGW-w64 on
`PATH`, run:

```powershell
.\build_stellar_arcade.bat
```

The script builds both `stellar_core.dll` and `stellar_arcade.exe` beside the
sources. Run `.\stellar_arcade.exe` to play. The game saves its native high score
to `stellar_highscore.txt` in that same folder.

To run the native game-logic tests with MinGW-w64:

```powershell
g++ -std=c++17 stellar_core.cpp stellar_core_test.cpp -o stellar_core_test.exe
.\stellar_core_test.exe
```

`dll1.dll` is a separate basic export/import example and is not required by the
Nebula Run game.
