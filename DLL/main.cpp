#include <iostream>

extern "C" __declspec(dllimport) int add(int a, int b);

int main() {
    int result = add(10, 20);
    std::cout << "Result: " << result << std::endl;
    return 0;
}