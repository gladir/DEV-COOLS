* preproc.prg - Exemple Clipper : #command, #define, #include
* Compilation : CLIPPER86 preproc.prg

* --- #define : constantes ---
#define APP_NAME "MonApplication"
#define APP_VERSION 1
#define MAX_ITEMS 100

? "Application :", APP_NAME
? "Version     :", APP_VERSION
? "Max items   :", MAX_ITEMS

* --- #define : remplacement dans expressions ---
#define OFFSET 50
LOCAL nVal
nVal := OFFSET + 25
? "OFFSET + 25 =", nVal

* --- #define sans valeur (flag) ---
#define DEBUG_MODE

* --- #ifdef / #endif ---
#ifdef DEBUG_MODE
? "Mode DEBUG actif"
#endif

* --- #ifdef / #else / #endif ---
#ifdef RELEASE_MODE
? "(ne s affiche pas)"
#else
? "Pas en mode RELEASE"
#endif

* --- #ifndef ---
#ifndef RELEASE_MODE
? "RELEASE_MODE non defini"
#endif

* --- #undef ---
#undef DEBUG_MODE
#ifdef DEBUG_MODE
? "(ne s affiche pas)"
#else
? "DEBUG_MODE desactive apres #undef"
#endif

* --- #ifdef imbrique ---
#define FEATURE_A
#define FEATURE_B
#ifdef FEATURE_A
? "FEATURE_A actif"
#ifdef FEATURE_B
? "  FEATURE_B aussi (imbrique)"
#endif
#endif

* --- #command : commande utilisateur ---
#command AFFICHE <x> => ? <x>
AFFICHE "Texte via #command"

* --- #command avec expression ---
#command DIRE <msg> => ? ">> " + <msg>
DIRE "Message personnalise"

* --- #define chaine / valeur ---
#define SALUT "Bonjour"
#define MONDE "le monde"
? SALUT

* --- #ifndef avec #define ---
#ifndef MY_CONST
#define MY_CONST 42
#endif
LOCAL c
c := MY_CONST
? "MY_CONST =", c

? "Fin de preproc.prg"
RETURN
