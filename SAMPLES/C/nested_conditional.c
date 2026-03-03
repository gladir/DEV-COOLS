#define DEBUG 1
#define PLATFORM_X86 1

int main() {
    int result = 0;
    
#ifdef DEBUG
    // Debug mode is enabled
#if PLATFORM_X86
    // X86 debug code
    result = result + 100;
#else
    // Other platform debug code
    result = result + 50;
#endif
#else
    // Release mode
    result = result + 10;
#endif

#ifndef FEATURE_DISABLED
    // This feature is not disabled, so include it
    result = result + 1000;
#endif

#if DEBUG > 0
    // This should be true since DEBUG is 1
    result = result + 1;
#elif DEBUG == 0
    // This should be skipped
    result = result + 2;
#else
    // This should also be skipped
    result = result + 3;
#endif

    return result;
}
