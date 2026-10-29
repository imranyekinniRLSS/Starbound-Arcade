#include <windows.h>
#include <iostream>

int main() {
    HMODULE h = LoadLibraryA("dll1.dll");
    if (!h) {
        std::cerr << "Failed to load DLL\n";
        return 1;
    }

    using AddFunc = int(*)(int, int);
    AddFunc addFunc = reinterpret_cast<AddFunc>(
        GetProcAddress(h, "add")
    );

    if (!addFunc) {
        std::cerr << "Function not found\n";
        FreeLibrary(h);
        return 1;
    }

    std::cout << "Result: " << addFunc(5, 7) << std::endl;
    FreeLibrary(h);
    return 0;
}