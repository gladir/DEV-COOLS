#define DEBUG 1
#define PLATFORM_X86 1

int main() {
    int result = 0;
    
#if DEBUG
    // This should be included when DEBUG is defined and non-zero
    result = result + 10;
#else
    // This should be skipped
    result = result + 1;
#endif

#ifdef PLATFORM_X86
    // This should be included when PLATFORM_X86 is defined
    result = result + 100;
#endif

#ifndef PLATFORM_ARM
    // This should be included when PLATFORM_ARM is NOT defined
    result = result + 1000;
#endif

#if DEBUG
    // First condition
    result = result + 1;
#elif 0
    // This should be skipped because DEBUG is true
    result = result + 2;
#else
    // This should also be skipped
    result = result + 3;
#endif

    return result;
}
