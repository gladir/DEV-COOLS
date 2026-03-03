#define ENABLED 1

int main() {
#ifdef ENABLED
    int x = 5;
#endif
    
#ifndef DISABLED  
    int y = 10;
#endif

#if ENABLED
    int z = 15;
#else
    int z = 0;
#endif
    
    return x + y + z;
}
