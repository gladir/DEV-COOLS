* test_preproc.prg - Test du preprocesseur (TODO 22)
* #define, #ifdef, #ifndef, #else, #endif, #undef, #command, #translate

* --- Test 1 : #define simple ---
#define GREETING "Hello from preprocessor"
#define MAX_VALUE 100
? "Test 1: #define"
? GREETING
LOCAL n
n := MAX_VALUE
? "  MAX_VALUE =", n

* --- Test 2 : #define remplacement dans expression ---
#define OFFSET 10
LOCAL x
x := OFFSET + 5
? "Test 2: OFFSET + 5 =", x

* --- Test 3 : #ifdef / #endif ---
#define DEBUG_MODE
? "Test 3: #ifdef"
#ifdef DEBUG_MODE
? "  DEBUG_MODE est defini"
#endif

* --- Test 4 : #ifdef / #else / #endif ---
? "Test 4: #ifdef/#else"
#ifdef DEBUG_MODE
? "  Branche #ifdef (DEBUG_MODE defini)"
#else
? "  Branche #else (ne devrait pas s afficher)"
#endif

* --- Test 5 : #ifndef ---
? "Test 5: #ifndef"
#ifndef RELEASE_MODE
? "  RELEASE_MODE n est pas defini"
#else
? "  RELEASE_MODE est defini (ne devrait pas s afficher)"
#endif

* --- Test 6 : #undef ---
? "Test 6: #undef"
#undef DEBUG_MODE
#ifdef DEBUG_MODE
? "  DEBUG_MODE encore defini (ne devrait pas s afficher)"
#else
? "  DEBUG_MODE n est plus defini apres #undef"
#endif

* --- Test 7 : #ifdef imbrique ---
#define FEATURE_A
#define FEATURE_B
? "Test 7: #ifdef imbrique"
#ifdef FEATURE_A
? "  FEATURE_A actif"
#ifdef FEATURE_B
? "  FEATURE_B actif (imbrique)"
#endif
#endif

* --- Test 8 : #ifndef avec #define ensuite ---
? "Test 8: #ifndef puis #define"
#ifndef MY_CONST
#define MY_CONST 42
#endif
LOCAL c
c := MY_CONST
? "  MY_CONST =", c

* --- Test 9 : #command simple ---
#command DISPLAY <x> => ? <x>
? "Test 9: #command"
DISPLAY "  Texte via #command DISPLAY"

* --- Test 10 : #define sans valeur (flag) ---
? "Test 10: #define sans valeur"
#define HAS_FEATURE
#ifdef HAS_FEATURE
? "  HAS_FEATURE est defini (flag)"
#endif

* --- Fin ---
? "Tous les tests preprocesseur passes!"
RETURN
