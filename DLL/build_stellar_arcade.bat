@echo off
setlocal
cd /d "%~dp0"

where cl >nul 2>&1
if not errorlevel 1 goto build_msvc

where g++ >nul 2>&1
if errorlevel 1 (
    echo No C++ compiler found. Install Visual Studio C++ Build Tools or MinGW-w64.
    exit /b 1
)

g++ -std=c++17 -shared -static-libgcc -static-libstdc++ -DSTELLAR_CORE_EXPORTS stellar_core.cpp -o stellar_core.dll
if errorlevel 1 exit /b %errorlevel%

g++ -std=c++17 -static -static-libgcc -static-libstdc++ stellar_arcade.cpp -o stellar_arcade.exe
if errorlevel 1 exit /b %errorlevel%
goto build_complete

:build_msvc
cl /nologo /std:c++17 /EHsc /LD /D STELLAR_CORE_EXPORTS stellar_core.cpp /Fe:stellar_core.dll
if errorlevel 1 exit /b %errorlevel%

cl /nologo /std:c++17 /EHsc stellar_arcade.cpp /Fe:stellar_arcade.exe
if errorlevel 1 exit /b %errorlevel%

:build_complete
echo Build complete. Run stellar_arcade.exe to play.
