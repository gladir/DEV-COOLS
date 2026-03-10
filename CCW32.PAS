{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur C vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  CCW32.PAS - Compilateur C vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de CC8086.PAS et les exemples
  SAMPLES\C\*

  CCW32 est un compilateur C ciblant l assembleur Intel 80386
  pour Windows 32 bits. Il prend en entree des fichiers .C
  en langage C (compatible avec le sous-ensemble supporte par
  CC8086.PAS) et produit de l assembleur 80386 compatible
  MASM pour Windows 32 bits (PE). Toutes les donnees entieres
  sont 32 bits (int = 4 octets, pointeurs = 4 octets).

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              AsmOutput, ObjOnly, OptLevel, OptSpeed, OptSize,
              CStandard, DLLMode, LinkFiles, LinkCount)
            ParseArgs : analyser argv (source.c [sortie.exe] [-v] [-d]
              [-w] [-obj] [-asm] [-dll] [-O0..-O3] [-Ot] [-Os]
              [-std=...] [fichier.lib] [fichier.obj])
            -obj : produire uniquement un fichier .OBJ (COFF)
            -asm : produire egalement un fichier .ASM lisible
            Par defaut : produire un .EXE (PE Windows 32 bits)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .c du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h ou /?)
            Supporter le linkage de fichiers .LIB et .OBJ externes
              specifies dans les parametres de la ligne de commande
              (ex: CCW32 source.c mylib.lib helper.obj)
            Parametre de norme C : supporter les differentes normes
              du langage C via un parametre de ligne de commande :
              C (1972), K&R C (1978), C POSIX (1988),
              ANSI C / ANSI X3.159-1989 / C89 (1989), C90 /
              ISO/IEC 9899:1990 (1990), C95 /
              ISO/IEC 9899:1990/AMD 1:1995 (1995),
              C99 (1999), C11 (2011), C18 (2018)
            Parametres d optimisation : niveau d optimisation
              (ex: -O0, -O1, -O2, -O3) et choix entre optimiser
              pour la vitesse (-Ot) ou reduire la taille (-Os)
            Parametre -dll : permettre de creer des .DLL en plus
              de .EXE (par defaut : .EXE)

  TODO 02 - LEXEUR (TOKENS C) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets "abc"
              Sequences d echappement : \n \t \r \0 \\ \" \' \x41
            LexScanCharLit : caractere entre apostrophes 'A' '\n' '\0'
            LexScanHexNumber : entiers hexadecimaux 0xFF 0XAB
            LexScanOctalNumber : entiers octaux 077
            Commentaires : /* ... */ (multi-lignes) et // (ligne)
            Mots-cles : auto break case char const continue default
              do double else enum extern float for goto if int long
              register return short signed sizeof static struct
              switch typedef union unsigned void volatile while
            Operateurs multi-caracteres : ++ -- += -= *= /= %= &=
              |= ^= <<= >>= == != <= >= && || << >> -> ##
            Ponctuation : ( ) [ ] { } ; , . : ? ~ ! # ...
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - PREPROCESSEUR (#define, #include, #if) [IMPLEMENTE]
            #define NOM valeur : definition de macro simple
            #define NOM(args) valeur : macro avec parametres (optionnel)
            #undef NOM : suppression de macro
            #include "fichier" : inclusion de fichier local
            #include <fichier> : inclusion de fichier systeme (stub)
            En-tetes C standard integres en built-in dans le compilateur
              (pas de fichier externe necessaire, le compilateur reconnait
              ces en-tetes et injecte les declarations correspondantes) :
              assert.h  : macro assert()
              ctype.h   : isalpha, isdigit, isalnum, isspace, toupper,
                           tolower, isupper, islower, isprint, ...
              errno.h   : variable errno, constantes EDOM, ERANGE
              float.h   : constantes FLT_MAX, FLT_MIN, DBL_MAX, ...
              limits.h  : constantes CHAR_BIT, CHAR_MAX, INT_MAX,
                           INT_MIN, LONG_MAX, LONG_MIN, UINT_MAX, ...
              locale.h  : struct lconv, setlocale, localeconv (stubs)
              math.h    : sin, cos, tan, sqrt, pow, exp, log, fabs,
                           ceil, floor, fmod, ... (stubs ou approx)
              setjmp.h  : jmp_buf, setjmp, longjmp (stubs)
              signal.h  : signal, raise, SIG_DFL, SIG_IGN, SIGINT,
                           SIGTERM, SIGABRT, ... (stubs)
              stdarg.h  : va_list, va_start, va_arg, va_end
              stddef.h  : NULL, size_t, ptrdiff_t, offsetof
              stdio.h   : printf, scanf, putchar, getchar, puts, gets,
                           fopen, fclose, fread, fwrite, fprintf,
                           fscanf, fgets, fputs, feof, FILE, stdin,
                           stdout, stderr, EOF, ...
              stdlib.h  : malloc, free, calloc, realloc, exit, abort,
                           atoi, atol, rand, srand, abs, labs, ...
              string.h  : strlen, strcpy, strcat, strcmp, strncpy,
                           strncat, strncmp, memcpy, memset, memcmp,
                           strchr, strrchr, strstr, ...
              time.h    : time, clock, difftime, mktime, struct tm,
                           time_t, clock_t, localtime, asctime, ...
            #ifdef NOM / #ifndef NOM : compilation conditionnelle
            #if expression : evaluation d expression constante
            #elif expression : branche alternative
            #else : branche par defaut
            #endif : fin de bloc conditionnel
            Expansion de macros dans le code source
            Protection contre les inclusions circulaires
            Pile d inclusions (max MAX_INCLUDE_DEPTH)

  TODO 04 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..4294967295 (32 bits non signe)
            Entiers hexadecimaux : 0xFF -> valeur 32 bits
            Entiers octaux : 077 -> valeur 32 bits
            Suffixes entiers : u/U (unsigned), l/L (long), ul/UL
            Flottants : 3.14, 1.0e10 (reconnus, tronques en entier)
            Caracteres : 'A' -> valeur ordinale 32 bits
              Echappement : '\n'=10, '\t'=9, '\r'=13, '\0'=0,
                '\\'=92, '\''=39, '\"'=34, '\x41'=65
            Chaines : "abc" -> pointeur vers donnees .DATA avec label
              Concatenation implicite : "abc" "def" -> "abcdef"
            Constantes entieres : enum et #define
            Expressions constantes : sizeof, alignof, ternaire const

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR, SC_PARAM, SC_FUNC, SC_TYPE,
              SC_FIELD, SC_ENUM_VAL, SC_LABEL, SC_STATIC,
              SC_EXTERNAL, SC_TYPEDEF, SC_GLOBAL
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              Scope, ScopeId, IsGlobal, IsExternal, IsStatic
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Portees : globale (fichier), locale (fonction), bloc {}
            Prefixes de mangling : _CCV_ (var), _CCF_ (func),
              _CCK_ (chaine const), _CCRT_ (runtime), _CCL_ (label),
              _CCA_ (tableau), _CCS_ (struct), _CCU_ (union),
              _CCE_ (enum)
            Fonctions standard C pre-enregistrees en built-in dans
              la table des symboles (le compilateur les reconnait
              automatiquement lorsqu elles apparaissent dans le
              code source C, sans declaration explicite requise) :
              abort, abs, acos, asctime, asin, assert, atan, atan2,
              atexit, atof, atoi, atol, bsearch, calloc, ceil,
              clearerr, clock, cos, cosh, ctime, difftime, div,
              exit, exp, fabs, fclose, feof, ferror, fflush, fgetc,
              fgetpos, fgets, floor, fmod, fopen, fprintf, fputc,
              fputs, fread, free, freopen, frexp, fscanf, fseek,
              fsetpos, ftell, fwrite, getc, getchar, getenv, gets,
              gmtime, isalnum, isalpha, iscntrl, isdigit, isgraph,
              islower, isprint, ispunct, isspace, isupper, isxdigit,
              labs, ldexp, ldiv, localtime, log, log10, longjmp,
              malloc, memchr, memcmp, memcpy, memmove, memset,
              mktime, modf, perror, pow, printf, putc, putchar,
              puts, qsort, raise, rand, realloc, remove, rename,
              rewind, scanf, setbuf, setjmp, setvbuf, signal, sin,
              sinh, sprintf, sqrt, srand, sscanf, strcat, strchr,
              strcmp, strcpy, strcspn, strerror, strftime, strlen,
              strncat, strncmp, strncpy, strpbrk, strrchr, strspn,
              strstr, strtod, strtok, strtol, strtoul, system, tan,
              tanh, time, tmpfile, tmpnam, tolower, toupper, ungetc,
              va_arg, va_end, va_start, vfprintf, vprintf, vsprintf

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TKP_VOID, TKP_CHAR (8 bits signe),
              TKP_UCHAR (8 bits non signe), TKP_SHORT (16 bits),
              TKP_USHORT (16 bits non signe), TKP_INT (32 bits signe),
              TKP_UINT (32 bits non signe), TKP_LONG (32 bits signe),
              TKP_ULONG (32 bits non signe), TKP_FLOAT (stub entier),
              TKP_DOUBLE (stub entier), TKP_POINTER (32 bits),
              TKP_ARRAY, TKP_STRUCT, TKP_UNION, TKP_ENUM,
              TKP_FUNC (pointeur de fonction)
            TypeTab, TypeInit : enregistrer types primitifs et utilisateur
            TypeSizeof : void=0, char=1, short=2, int=4, long=4,
              float=4, double=8, pointer=4
            TypeCompatible : verification de compatibilite d affectation
            TypeCoerce : conversions implicites (char->int, short->int)
            TypeResolve : resolution de typedef
            Qualificateurs : const, volatile, signed, unsigned
            Types primitifs predefinis : char, short, int, long,
              float, double, void, unsigned char/short/int/long

  TODO 07 - EMETTEUR DE CODE ASM 80386
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _CCL_NNNNN)
            Prefixes 32 bits : _CCV_ (variable), _CCF_ (fonction),
              _CCK_ (chaine const), _CCRT_ (runtime), _CCL_ (label)
            EmitHeader : .386 / .MODEL FLAT, STDCALL
              EXTRN _ExitProcess@4:NEAR
              EXTRN _GetStdHandle@4:NEAR
              EXTRN _WriteFile@20:NEAR
              EXTRN _ReadFile@20:NEAR
              EXTRN _GetProcessHeap@0:NEAR
              EXTRN _HeapAlloc@12:NEAR
              EXTRN _HeapFree@12:NEAR
              .DATA section et .CODE section
            EmitProlog : PUSH EBP / MOV EBP,ESP / SUB ESP,locals
            EmitEpilog : MOV ESP,EBP / POP EBP / RET
            EmitDataSeg : ecrire .DATA avec toutes les entrees DataTab

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_STRUCT/DK_ZERO), IntVal, StrVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddDWord, DataAddByte,
              DataAddArray, DataAddStruct : variantes d ajout
            Variables globales (hors de toute fonction) :
              DD/DB dans .DATA avec label _CCV_nom
            Variables static : DD dans .DATA, persistantes entre appels
            Constantes chaines : DB "abc",0 dans .DATA avec label _CCK_N
            Tampons I/O : INBUF (256 octets), NUMBUF (16 octets)
            Variables de handles : HSTDOUT, HSTDIN, HHEAP (DWORD)

  TODO 09 - VARIABLES ET DECLARATIONS
            Variables globales : segment .DATA, acces par [_CCV_nom]
            Variables locales : pile EBP, acces [EBP-offset]
            Parametres de fonction : [EBP+8+...] (convention cdecl)
            Declaration : type nom [= init]; (avec initialiseur opt.)
            Declarations multiples : int a, b, c;
            Classes d entreposage : auto, static, extern, register
            Qualificateurs : const, volatile
            Portee de bloc : { int x = 0; ... } (variable locale au bloc)
            Initialisation globale : donnees dans .DATA
            Initialisation locale : MOV [EBP-offset], valeur

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, ident, appel
            Acces variable globale : MOV EAX,[_CCV_nom]
            Acces variable locale : MOV EAX,[EBP-offset]
            Acces parametre : MOV EAX,[EBP+offset]
            Appel de fonction : CALL _CCF_nom -> resultat dans EAX
              Convention cdecl : appelant nettoie la pile (ADD ESP,n)
            Parentheses : (expr) pour forcer la precedence
            Conversion de type : (type)expr (cast explicite)
            sizeof(type) : taille du type en octets -> constante
            sizeof(expr) : taille du type de l expression
            Acces membre struct : expr.membre -> offset fixe
            Acces membre via pointeur : expr->membre -> deref + offset
            Acces tableau : expr[index] -> base + index*sizeof(elem)
            Post-increment/decrement : expr++ expr--
            Pre-increment/decrement : ++expr --expr
            Adresse de : &expr -> LEA EAX,[var]
            Dereferencement : *expr -> MOV EAX,[EAX]

  TODO 11 - OPERATEURS ET PRECEDENCE
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique 32 bits : ADD/SUB/IMUL/IDIV pour +, -, *, /
            Modulo : IDIV -> resultat dans EDX (reste) pour %
            Decalages : SHL/SHR pour << >>
            Comparaison : CMP + SETcc pour == != < <= > >=
            Logique AND : && (court-circuit, JZ vers false)
            Logique OR  : || (court-circuit, JNZ vers true)
            Logique NOT : !expr -> TEST EAX,EAX / SETZ AL / MOVZX
            Complement bit a bit : ~expr -> NOT EAX
            ET bit a bit : & -> AND EAX, valeur
            OU bit a bit : | -> OR EAX, valeur
            OU exclusif   : ^ -> XOR EAX, valeur
            Negation unaire : -expr -> NEG EAX
            Ternaire : cond ? expr1 : expr2 (labels + JZ)
            Virgule : expr1, expr2 -> evaluer les deux, garder expr2
            Precedence (du plus fort au plus faible) :
              1. () [] -> . ++ -- (postfixe)
              2. ++ -- + - ! ~ * & sizeof (type) (prefixe/unaire)
              3. * / % (multiplicatif)
              4. + - (additif)
              5. << >> (decalage)
              6. < <= > >= (relationnel)
              7. == != (egalite)
              8. & (ET bit a bit)
              9. ^ (OU exclusif)
              10. | (OU bit a bit)
              11. && (ET logique)
              12. || (OU logique)
              13. ?: (ternaire)
              14. = += -= *= /= %= &= |= ^= <<= >>= (affectation)
              15. , (virgule)

  TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES
            Affectation simple : var = expr -> MOV [var], EAX
            Affectation composee += : var += expr -> ADD [var], EAX
            Affectation composee -= : var -= expr -> SUB [var], EAX
            Affectation composee *= : var *= expr -> IMUL + MOV
            Affectation composee /= : var /= expr -> IDIV + MOV
            Affectation composee %= : var %= expr -> IDIV + MOV EDX
            Affectation composee &= : var &= expr -> AND [var], EAX
            Affectation composee |= : var |= expr -> OR [var], EAX
            Affectation composee ^= : var ^= expr -> XOR [var], EAX
            Affectation composee <<= : var <<= expr -> SHL [var], CL
            Affectation composee >>= : var >>= expr -> SHR [var], CL
            Post-increment ++ : val = var; var += 1 -> MOV + INC
            Post-decrement -- : val = var; var -= 1 -> MOV + DEC
            Pre-increment ++ : var += 1; val = var -> INC + MOV
            Pre-decrement -- : var -= 1; val = var -> DEC + MOV
            Affectation de struct : copie par REP MOVSD
            Affectation de pointeur : copie d adresse (MOV)

  TODO 13 - INSTRUCTIONS DE CONTROLE (if / else)
            ParseIfStmt : if (cond) stmt [else stmt]
              Emission TEST EAX,EAX / JZ pour condition fausse
              Labels : _CCL_ELSE_N, _CCL_ENDIF_N
              if imbriques : else if (cond) stmt ...
            ParseCompoundStmt : { stmt; stmt; ... }
              Bloc d instructions avec portee locale
              SymEnterScope / SymLeaveScope pour variables de bloc
            ParseExprStmt : expr; (expression comme instruction)
            Instruction vide : ; (no-op)

  TODO 14 - BOUCLES (for / while / do-while)
            ParseForStmt : for (init; cond; incr) stmt
              Trois expressions optionnelles separees par ;
              init : declaration ou expression
              cond : expression booleenne (boucle infinie si absente)
              incr : expression d increment
              Labels : _CCL_FTEST_N, _CCL_FINCR_N, _CCL_FEND_N
            ParseWhileStmt : while (cond) stmt
              Labels : _CCL_WTEST_N, _CCL_WEND_N
            ParseDoWhileStmt : do stmt while (cond);
              Labels : _CCL_DBEG_N, _CCL_DEND_N
            LoopPush / LoopPop : pile de labels pour break/continue
            break : saut vers la fin de la boucle englobante
            continue : saut vers l increment/test de la boucle

  TODO 15 - SWITCH / CASE / DEFAULT
            ParseSwitchStmt : switch (expr) { case val: stmts }
              Expression de controle : entier dans EAX
              case valeur : branche pour une valeur (CMP + JE)
              case val1 ... valN : valeurs multiples (CMP successifs)
              default : branche par defaut
              break : sortie du switch (JMP vers fin)
              Fall-through : sans break, execution continue
              Labels : _CCL_CASE_N, _CCL_CDEF_N, _CCL_CEND_N
            SwitchPush / SwitchPop : pile pour switch imbriques
              (max MAX_SWITCH_NEST niveaux d imbrication)

  TODO 16 - FONCTIONS ET PROTOTYPES
            ParseFuncDecl : prototype (declaration avancee)
              type nom(type1 param1, type2 param2, ...);
            ParseFuncDef : definition complete avec corps
              type nom(type1 param1, type2 param2, ...) { corps }
            Convention cdecl : appelant nettoie la pile
              Parametres empiles de droite a gauche (PUSH)
              Offsets : [EBP+8], [EBP+12], [EBP+16], ...
              Valeur de retour dans EAX
            Variables locales : [EBP-4], [EBP-8], ...
            Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,n
            Epilogue : MOV ESP,EBP / POP EBP / RET
            main() : point d entree du programme (_CCF_main)
            Appel de fonction : evaluer args, PUSH, CALL, ADD ESP,n
            Fonctions void : pas de valeur de retour
            Fonctions extern : declaration sans corps (EXTRN dans asm)
            Fonctions static : visibles uniquement dans le fichier

  TODO 17 - POINTEURS ET ADRESSES
            Declaration : type *nom; (pointeur vers type)
              Taille : 4 octets (DWORD, adresse 32 bits)
            Dereferencement : *p -> MOV EAX,[EAX]
            Adresse de : &var -> LEA EAX,[var]
            Arithmetique de pointeurs :
              p + n -> ADD EAX, n * taille_elem
              p - n -> SUB EAX, n * taille_elem
              p1 - p2 -> SUB + division par taille_elem
              p++ -> ADD [var], taille_elem
              p-- -> SUB [var], taille_elem
            Affectation : p = &var ou p = malloc(...)
            Pointeur NULL : void-ptr 0 -> EAX=0
            Pointeur void-ptr : pointeur generique (cast implicite)
            Pointeurs de fonction : type ptr-func(args)
              Appel indirect : CALL DWORD PTR [pf]
            Comparaison de pointeurs : == != < > <= >=
            Acces via pointeur : p->membre (deref + offset)

  TODO 18 - TABLEAUX
            Declaration : type nom[taille]; (tableau a taille fixe)
              Taille = nombre_elements * sizeof(type)
              Acces : base + index * sizeof(type) -> adresse element
            Tableaux multi-dimensionnels : type nom[dim1][dim2];
              Linearisation : (i*dim2 + j) * sizeof(type)
            Initialisation : int a[] = {1, 2, 3};
              Taille deduite du nombre d elements
              Donnees dans .DATA pour variables globales
            Initialisation partielle : int a[10] = {1, 2};
              Elements manquants initialises a zero
            Chaines comme tableaux : char s[] = "hello";
              Equivalent a char s[] = {'h','e','l','l','o','\0'};
            Passage de tableau a fonction : decay en pointeur
              nom equivalent a &nom[0]
            Acces tableau via pointeur : *(p+i) equivalent p[i]
            sizeof(tableau) : taille totale en octets

  TODO 19 - STRUCTURES ET UNIONS
            struct nom { type1 champ1; type2 champ2; };
              Taille = somme des sizeof(Ti) avec alignement
              Acces champ : offset fixe depuis debut du struct
            union nom { type1 champ1; type2 champ2; };
              Taille = max des sizeof(Ti) (chevauchement memoire)
              Acces champ : offset 0 pour tous les champs
            struct anonyme : struct { ... } var;
            Structures imbriquees : struct contenant struct
            Membres tableaux : struct { int tab[10]; };
            Membres pointeurs : struct { struct node *next; };
            Declaration et definition combinees :
              struct point { int x, y; } p1;
            Affectation de struct : copie complete (REP MOVSD)
            Passage de struct a fonction : copie sur la pile
            Retour de struct : copie dans zone appelant
            Pointeur vers struct : struct point *pp;
              Acces : pp->x equivalent deref pp.x

  TODO 20 - ENUMERATIONS ET TYPEDEF
            enum nom { VAL1, VAL2, VAL3 };
              Chaque valeur = constante entiere (0, 1, 2, ...)
              Valeurs explicites : enum { A=5, B=10, C };
                C prend la valeur suivante (11)
              Taille : 4 octets (DWORD 32 bits)
              Utilisable dans switch/case et expressions
            enum anonyme : enum { ... } var;
            typedef ancien_type nouveau_nom;
              typedef int BOOL;
              typedef struct point Point;
              typedef int *IntPtr;
              typedef void FuncPtrType(int, int);
            TypeResolve : resolution recursive de typedef
            find_typedef, add_typedef : gestion de la table typedef

  TODO 21 - CHAINES ET ENTREES/SORTIES (printf, scanf)
            Chaines C : terminaison par '\0' (ASCIIZ)
              Stockage : DB "abc",0 dans .DATA
              Variable char* : pointeur vers chaine
            printf(fmt, ...) : sortie formatee vers stdout
              %d : entier signe (CALL _CCRT_PRINTINT)
              %u : entier non signe
              %x : entier hexadecimal
              %c : caractere (CALL _CCRT_PRINTCHAR)
              %s : chaine (CALL _CCRT_PRINTSTR)
              %% : caractere % litteral
              \n : nouvelle ligne (CALL _CCRT_PRINTCRLF)
            scanf(fmt, ...) : entree formatee depuis stdin
              %d : lire entier (CALL _CCRT_READINT)
              %s : lire chaine (CALL _CCRT_READSTR)
              %c : lire caractere (CALL _CCRT_READCHAR)
            putchar(c) : ecrire un caractere (CALL _CCRT_PRINTCHAR)
            getchar() : lire un caractere -> EAX
            puts(s) : ecrire chaine + newline

  TODO 22 - GOTO, BREAK, CONTINUE, RETURN
            goto label; : saut inconditionnel vers label
              label: stmt; -> definition du label
              Verification : label defini dans la meme fonction
              Table de labels (max MAX_GOTO_LABELS par fonction)
            break; : sortie de la boucle ou switch englobant
              JMP vers label de fin de boucle/switch
              Erreur si utilise hors d une boucle ou switch
            continue; : passage a l iteration suivante
              JMP vers label d increment/test de la boucle
              Erreur si utilise hors d une boucle
            return expr; : retour de fonction avec valeur
              MOV EAX, valeur -> JMP vers epilogue
            return; : retour de fonction void (sans valeur)
              JMP vers epilogue

  TODO 23 - OPERATEUR TERNAIRE, CAST ET SIZEOF
            Operateur ternaire : cond ? expr1 : expr2
              TEST EAX,EAX / JZ vers faux
              Evaluer expr1 -> JMP vers fin
              Label faux : evaluer expr2
              Label fin : resultat dans EAX
              Ternaire imbrique : a ? b ? c : d : e
            Cast explicite : (type)expr
              (int)c : promotion char -> int (MOVSX)
              (char)i : troncature int -> char (AND 0xFF)
              void-ptr p : conversion pointeur generique
              (unsigned)i : reinterpretation signe -> non signe
              Casts entre pointeurs de types differents
            sizeof : taille en octets d un type ou expression
              sizeof(int) -> 4
              sizeof(char) -> 1
              sizeof(struct point) -> taille totale
              sizeof(tableau) -> nombre_elements * sizeof(elem)
              sizeof(pointeur) -> 4
              Evalue a la compilation (constante)

  TODO 24 - RUNTIME MINIMAL WIN32
            _CCRT_PRINTSTR(ESI=msg) : WriteFile sur hStdOut
            _CCRT_PRINTINT(EAX=n) : conversion + WriteFile
            _CCRT_PRINTCRLF : ecriture CR+LF
            _CCRT_PRINTCHAR(EAX=c) : afficher un caractere
            _CCRT_PRINTUINT(EAX=n) : afficher entier non signe
            _CCRT_PRINTHEX(EAX=n) : afficher entier en hexadecimal
            _CCRT_NUMTOSTR(EAX=n, EDI=buf) : entier -> ASCII (itoa)
            _CCRT_STRTONUM(ESI=str) : ASCII -> entier -> EAX (atoi)
            _CCRT_STRLEN(ESI=str) : longueur ASCIIZ -> EAX
            _CCRT_STRCMP(ESI=s1, EDI=s2) : comparaison -> drapeaux
            _CCRT_STRCPY(ESI=src, EDI=dst) : copie de chaine
            _CCRT_STRCAT(ESI=s1, EDI=s2) : concatenation -> EAX=ptr
            _CCRT_READINT -> EAX : lire entier depuis stdin
            _CCRT_READSTR(EDI=buf) : lire ligne depuis stdin
            _CCRT_READCHAR -> EAX : lire un caractere
            _CCRT_READLN : consommer jusqu au prochain CR+LF
            _CCRT_MALLOC(EAX=taille) : HeapAlloc -> EAX=ptr
            _CCRT_FREE(EAX=ptr) : HeapFree
            _CCRT_MEMCPY(ESI=src, EDI=dst, ECX=len) : copie memoire
            _CCRT_MEMSET(EDI=dst, EAX=val, ECX=len) : remplissage
            _CCRT_PANIC(ESI=msg) : affiche message + ExitProcess(1)
            Heap Win32 : GetProcessHeap + HeapAlloc / HeapFree
            Handles : hStdOut, hStdIn via GetStdHandle

  TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES
            Generation PE (.EXE Windows 32 bits) :
              DOS stub + signature PE + en-tete COFF + en-tete optionnel
              Sections : .text (code), .rdata (imports), .data (donnees)
              Table d imports : kernel32.dll (ExitProcess, GetStdHandle,
                WriteFile, ReadFile, GetProcessHeap, HeapAlloc,
                HeapFree)
              Point d entree : _CCF_main
            Generation COFF (.OBJ) : option -obj
              En-tete COFF + sections .text/.data + table symboles
              Relocations pour les references externes
            Generation ASM (.ASM) : option -asm
              Fichier assembleur MASM lisible en plus du binaire
            EmitClose : finalisation du fichier de sortie
            Run : pipeline complet LexInit -> Parse -> Emit -> Binary
            Fichiers SAMPLES\C\*.c existants :
              hello8086.c, simple8086.c, basic_test.c, simple_test.c,
              minimal_test.c, if_test.c, for_test.c, while_zero.c,
              switch_test.c, function_test.c, return_test.c,
              pointer_test.c, struct_test.c, enum_test.c,
              typedef_complete_test.c, extern_test.c, define_test.c,
              include_test.c, array_test.c, goto_test.c,
              sizeof_test.c, bitwise_test.c, ternary_operator_test.c,
              break_continue_test.c, expression_test.c,
              static_test.c, volatile_test.c, address_test.c,
              dereference_test.c, long_types_test.c
            Smoke tests : CCW32.EXE -v SAMPLES\C\*.c

  ============================================================ *)

Program CCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE ET OPTIONS                          }
{ ============================================================ }

Const
  CCW32_VERSION = '0.1';
  CCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  MAX_LINK_FILES = 20;

  { Niveaux d optimisation }
  OPT_NONE       = 0;   { -O0 : aucune optimisation             }
  OPT_BASIC      = 1;   { -O1 : optimisations de base           }
  OPT_ADVANCED   = 2;   { -O2 : optimisations avancees          }
  OPT_AGGRESSIVE = 3;   { -O3 : optimisations agressives        }

Type
  TString = String;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.c)                  }
    OutFile   : TString;   { fichier sortie (.exe, .obj, .dll)    }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : afficher les avertissements     }
    AsmOutput : Boolean;   { -asm : produire aussi un .ASM        }
    ObjOnly   : Boolean;   { -obj : produire seulement un .OBJ    }
    DLLMode   : Boolean;   { -dll : produire un .DLL              }
    OptLevel  : Integer;   { 0..3 : niveau d optimisation         }
    OptSpeed  : Boolean;   { -Ot : optimiser pour la vitesse      }
    OptSize   : Boolean;   { -Os : optimiser pour la taille       }
    CStandard : TString;   { norme C cible (C89, C99, C11, C18)   }
    LinkFiles : Array[0..MAX_LINK_FILES - 1] Of TString;
    LinkCount : Integer;   { nombre de fichiers .LIB/.OBJ a lier  }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  StrLowerCase := Tmp;
End;

{ Retourne l extension d un chemin (avec le point, en minuscules) }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('CCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Var J : Integer;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.AsmOutput := False;
  Opts.ObjOnly   := False;
  Opts.DLLMode   := False;
  Opts.OptLevel  := OPT_NONE;
  Opts.OptSpeed  := False;
  Opts.OptSize   := False;
  Opts.CStandard := 'C99';
  Opts.LinkCount := 0;
  For J := 0 To MAX_LINK_FILES - 1 Do
    Opts.LinkFiles[J] := '';
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('CCW32 v', CCW32_VERSION, ' (', CCW32_DATE,
          ') - Compilateur C vers 80386 (Windows PE 32 bits)');
  WriteLn;
  WriteLn('Syntaxe : CCW32 <source.c> [sortie] [options] ',
          '[fichier.lib ...] [fichier.obj ...]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -dll           Produire un .DLL au lieu d''un .EXE');
  WriteLn;
  WriteLn('Optimisation :');
  WriteLn('  -O0            Pas d''optimisation (valeur par defaut)');
  WriteLn('  -O1            Optimisations de base');
  WriteLn('  -O2            Optimisations avancees');
  WriteLn('  -O3            Optimisations agressives (toutes)');
  WriteLn('  -Ot            Optimiser pour la vitesse');
  WriteLn('  -Os            Optimiser pour la taille');
  WriteLn;
  WriteLn('Norme C :');
  WriteLn('  -std=<norme>   Norme C cible : c89, c90, c95, c99 (defaut),');
  WriteLn('                 c11, c18, kr, posix');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Linkage :');
  WriteLn('  fichier.lib    Fichier de bibliotheque a lier');
  WriteLn('  fichier.obj    Fichier objet externe a lier');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  CCW32 hello.c');
  WriteLn('  CCW32 hello.c hello.exe -v');
  WriteLn('  CCW32 main.c -asm -O2');
  WriteLn('  CCW32 plugin.c -dll -Os');
  WriteLn('  CCW32 app.c mylib.lib helper.obj');
  WriteLn('  CCW32 projet.c -std=c11 -O2 -Ot');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
  UArg : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.AsmOutput := True
    Else If Arg = '-obj' Then
      Opts.ObjOnly := True
    Else If Arg = '-dll' Then
      Opts.DLLMode := True
    Else If Arg = '-O0' Then
      Opts.OptLevel := OPT_NONE
    Else If Arg = '-O1' Then
      Opts.OptLevel := OPT_BASIC
    Else If Arg = '-O2' Then
      Opts.OptLevel := OPT_ADVANCED
    Else If Arg = '-O3' Then
      Opts.OptLevel := OPT_AGGRESSIVE
    Else If Arg = '-Ot' Then
      Opts.OptSpeed := True
    Else If Arg = '-Os' Then
      Opts.OptSize := True
    Else If Copy(Arg, 1, 5) = '-std=' Then
    Begin
      UArg := StrUpperCase(Copy(Arg, 6, Length(Arg) - 5));
      If (UArg = 'C89') Or (UArg = 'ANSI') Then
        Opts.CStandard := 'C89'
      Else If UArg = 'C90' Then
        Opts.CStandard := 'C90'
      Else If UArg = 'C95' Then
        Opts.CStandard := 'C95'
      Else If UArg = 'C99' Then
        Opts.CStandard := 'C99'
      Else If UArg = 'C11' Then
        Opts.CStandard := 'C11'
      Else If UArg = 'C18' Then
        Opts.CStandard := 'C18'
      Else If (UArg = 'KR') Or (UArg = 'K&R') Then
        Opts.CStandard := 'KR'
      Else If UArg = 'POSIX' Then
        Opts.CStandard := 'POSIX'
      Else
        FatalError('Norme C inconnue: ' + Copy(Arg, 6, Length(Arg) - 5)
          + ' (valeurs: c89 c90 c95 c99 c11 c18 kr posix)');
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source, sortie, ou linkage }
      Ext := ExtractExt(Arg);
      If (Ext = '.lib') Or (Ext = '.obj') Then
      Begin
        If Opts.LinkCount >= MAX_LINK_FILES Then
          FatalError('Trop de fichiers de linkage (max '
            + IntToStr_(MAX_LINK_FILES) + ')');
        Opts.LinkFiles[Opts.LinkCount] := Arg;
        Inc(Opts.LinkCount);
      End
      Else If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else If Opts.OutFile = '' Then
        Opts.OutFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .c }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.c' Then
    WarnMsg('extension attendue .c, trouvee: ' + Ext);

  { -Ot et -Os sont mutuellement exclusifs }
  If Opts.OptSpeed And Opts.OptSize Then
    FatalError('-Ot et -Os sont mutuellement exclusifs');

  { -obj et -dll sont mutuellement exclusifs }
  If Opts.ObjOnly And Opts.DLLMode Then
    FatalError('-obj et -dll sont mutuellement exclusifs');

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.ObjOnly Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else If Opts.DLLMode Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.dll')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                       }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('CCW32 v', CCW32_VERSION, ' (', CCW32_DATE,
          ') - Compilateur C -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.AsmOutput Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  WriteLn('Norme    : ', Opts.CStandard);
  If Opts.OptLevel > OPT_NONE Then
    WriteLn('Optim    : -O', IntToStr_(Opts.OptLevel));
  If Opts.OptSpeed Then
    WriteLn('Strategie: vitesse (-Ot)');
  If Opts.OptSize Then
    WriteLn('Strategie: taille (-Os)');
  If Opts.DLLMode Then
    WriteLn('Format   : DLL');
  If Opts.LinkCount > 0 Then
    WriteLn('Linkage  : ', Opts.LinkCount, ' fichier(s) externe(s)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ============================================================ }
{ TODO 02 - LEXEUR (TOKENS C)                                 }
{ ============================================================ }

Const
  MAX_STR = 255;

Type
  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_FLOAT,
    TK_STRING,
    TK_CHAR,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TString;      { texte du token                     }
    IntVal  : LongInt;      { valeur entiere si TK_INTEGER/CHAR  }
    Line    : Integer;      { numero de ligne source (1-based)   }
    Col     : Integer;      { colonne dans la ligne (1-based)    }
  End;

Var
  { Lexeur }
  LexSrcF     : Text;       { handle du fichier source           }
  LexOpened   : Boolean;     { fichier ouvert ?                   }
  LexLine     : TString;    { ligne courante                     }
  LexLineNo   : Integer;    { numero de ligne courante           }
  LexColNo    : Integer;    { colonne courante dans LexLine      }
  LexEOF      : Boolean;    { fin de fichier atteinte ?          }
  CurToken    : TToken;     { token courant                      }

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function IsOctDigit(Ch : Char) : Boolean;
Begin
  IsOctDigit := (Ch >= '0') And (Ch <= '7');
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : mots-cles du langage C                           }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'auto')     Or (S = 'break')    Or (S = 'case')     Or
    (S = 'char')     Or (S = 'const')    Or (S = 'continue') Or
    (S = 'default')  Or (S = 'do')       Or (S = 'double')   Or
    (S = 'else')     Or (S = 'enum')     Or (S = 'extern')   Or
    (S = 'float')    Or (S = 'for')      Or (S = 'goto')     Or
    (S = 'if')       Or (S = 'int')      Or (S = 'long')     Or
    (S = 'register') Or (S = 'return')   Or (S = 'short')    Or
    (S = 'signed')   Or (S = 'sizeof')   Or (S = 'static')   Or
    (S = 'struct')   Or (S = 'switch')   Or (S = 'typedef')  Or
    (S = 'union')    Or (S = 'unsigned') Or (S = 'void')     Or
    (S = 'volatile') Or (S = 'while');
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug (option -d)                     }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_CHAR    : Write('CHAR(', T.IntVal, ')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextLine : lire la prochaine ligne du fichier source      }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    {$I-}
    ReadLn(LexSrcF, LexLine);
    {$I+}
    If IOResult <> 0 Then
    Begin
      LexEOF   := True;
      LexLine  := '';
      LexColNo := 1;
      Exit;
    End;
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ------------------------------------------------------------ }
{ LexInit / LexClose                                           }
{ ------------------------------------------------------------ }

Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind   := TK_EOF;
  CurToken.Val    := '';
  CurToken.IntVal := 0;
  CurToken.Line   := 0;
  CurToken.Col    := 0;
  LexNextLine;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexSkipLineComment : sauter un commentaire // jusqu en fin   }
{ de ligne                                                     }
{ ------------------------------------------------------------ }

Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ------------------------------------------------------------ }
{ LexSkipBlockComment : sauter un commentaire multi-lignes     }
{ ------------------------------------------------------------ }

Procedure LexSkipBlockComment;
Begin
  Inc(LexColNo, 2);  { sauter / et * }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo, 2);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
  WarnMsg('commentaire /* non ferme a la fin du fichier');
End;

{ ------------------------------------------------------------ }
{ LexScanEscape : scanner une sequence d echappement C         }
{ Retourne la valeur ordinale du caractere echappe             }
{ ------------------------------------------------------------ }

Function LexScanEscape : Integer;
Var V : Integer;
    Count : Integer;
Begin
  { LexColNo pointe sur le caractere apres le \ }
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscape := Ord('\');
    Exit;
  End;
  Case LexLine[LexColNo] Of
    'n'  : Begin LexScanEscape := 10;  Inc(LexColNo); End;
    't'  : Begin LexScanEscape := 9;   Inc(LexColNo); End;
    'r'  : Begin LexScanEscape := 13;  Inc(LexColNo); End;
    '0'  : Begin LexScanEscape := 0;   Inc(LexColNo); End;
    '\' : Begin LexScanEscape := 92;  Inc(LexColNo); End;
    '"'  : Begin LexScanEscape := 34;  Inc(LexColNo); End;
    '''' : Begin LexScanEscape := 39;  Inc(LexColNo); End;
    'a'  : Begin LexScanEscape := 7;   Inc(LexColNo); End;
    'b'  : Begin LexScanEscape := 8;   Inc(LexColNo); End;
    'f'  : Begin LexScanEscape := 12;  Inc(LexColNo); End;
    'v'  : Begin LexScanEscape := 11;  Inc(LexColNo); End;
    '?'  : Begin LexScanEscape := 63;  Inc(LexColNo); End;
    'x', 'X' :
    Begin
      Inc(LexColNo);
      V := 0;
      Count := 0;
      While (LexColNo <= Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo]) And (Count < 2) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        Inc(Count);
      End;
      LexScanEscape := V And $FF;
    End;
  Else
    { Caractere inconnu apres \ : prendre le caractere tel quel }
    LexScanEscape := Ord(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanString : scanner une chaine C entre guillemets "..."  }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);  { sauter le guillemet ouvrant }
  While (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);  { sauter le guillemet fermant }
      Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);  { sauter le \ }
      If Length(S) < MAX_STR Then
        S := S + Chr(LexScanEscape And $FF);
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanCharLit : scanner un caractere C entre apostrophes    }
{ ------------------------------------------------------------ }

Procedure LexScanCharLit;
Var V : Integer;
Begin
  Inc(LexColNo);  { sauter l apostrophe ouvrante }
  V := 0;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '''') Then
  Begin
    If LexLine[LexColNo] = '\' Then
    Begin
      Inc(LexColNo);
      V := LexScanEscape;
    End
    Else
    Begin
      V := Ord(LexLine[LexColNo]);
      Inc(LexColNo);
    End;
  End;
  { Sauter l apostrophe fermante }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Inc(LexColNo);
  CurToken.Kind   := TK_CHAR;
  CurToken.Val    := Chr(V And $FF);
  CurToken.IntVal := V;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : scanner un identificateur ou un mot-cle       }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : scanner un entier decimal, hex (0x), octal   }
{ (0nnn), ou flottant                                          }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  Ch      : Char;
  NumStr  : TString;
  IsFloat : Boolean;
Begin
  N       := 0;
  NumStr  := '';
  IsFloat := False;
  Ch      := LexLine[LexColNo];

  { Hexadecimal : 0x... ou 0X... }
  If (Ch = '0') And (LexColNo < Length(LexLine)) And
     ((LexLine[LexColNo + 1] = 'x') Or (LexLine[LexColNo + 1] = 'X')) Then
  Begin
    NumStr := '0x';
    Inc(LexColNo, 2);
    While (LexColNo <= Length(LexLine)) And
          IsHexDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 16 + HexVal(LexLine[LexColNo]);
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    { Suffixes u/U/l/L ignores }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'u') Or (LexLine[LexColNo] = 'U') Or
           (LexLine[LexColNo] = 'l') Or (LexLine[LexColNo] = 'L')) Do
      Inc(LexColNo);
    CurToken.Kind   := TK_INTEGER;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
    Exit;
  End;

  { Octal : commence par 0 suivi de chiffres octaux }
  If (Ch = '0') And (LexColNo < Length(LexLine)) And
     IsOctDigit(LexLine[LexColNo + 1]) Then
  Begin
    NumStr := '0';
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          IsOctDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 8 + (Ord(LexLine[LexColNo]) - Ord('0'));
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    { Suffixes }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'u') Or (LexLine[LexColNo] = 'U') Or
           (LexLine[LexColNo] = 'l') Or (LexLine[LexColNo] = 'L')) Do
      Inc(LexColNo);
    CurToken.Kind   := TK_INTEGER;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
    Exit;
  End;

  { Decimal (ou flottant) }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie fractionnaire .ddd }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And IsDigit(LexLine[LexColNo + 1]) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + '.';
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Exposant E[+-]ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Suffixes f/F/l/L/u/U }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = 'u') Or (LexLine[LexColNo] = 'U') Or
         (LexLine[LexColNo] = 'l') Or (LexLine[LexColNo] = 'L') Or
         (LexLine[LexColNo] = 'f') Or (LexLine[LexColNo] = 'F')) Do
    Inc(LexColNo);

  If IsFloat Then
  Begin
    CurToken.Kind   := TK_FLOAT;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;  { partie entiere tronquee }
  End
  Else
  Begin
    CurToken.Kind   := TK_INTEGER;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
  End;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : scanner principal - retourne le prochain      }
{ token dans CurToken                                          }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal := 0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne atteinte }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { EOF atteint }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    { Commentaire de ligne // }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexSkipLineComment

    { Commentaire de bloc /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
      LexSkipBlockComment

    { Chaine "..." }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    { Caractere '...' }
    Else If Ch = '''' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { --- Operateurs multi-caracteres (3 caracteres) --- }

    { <<= }
    Else If (Ch = '<') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<<=';
      Inc(LexColNo, 3); Scanning := False;
    End

    { >>= }
    Else If (Ch = '>') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>>=';
      Inc(LexColNo, 3); Scanning := False;
    End

    { ... (ellipsis) }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '...';
      Inc(LexColNo, 3); Scanning := False;
    End

    { --- Operateurs multi-caracteres (2 caracteres) --- }

    { ++ }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '+') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '++';
      Inc(LexColNo, 2); Scanning := False;
    End

    { -- }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '-') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '--';
      Inc(LexColNo, 2); Scanning := False;
    End

    { -> }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '->';
      Inc(LexColNo, 2); Scanning := False;
    End

    { += }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '+=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { -= }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '-=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { *= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '*=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { /= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '/=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { %= }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '%=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { &= }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '&=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { |= }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '|=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { ^= }
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '^=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '==';
      Inc(LexColNo, 2); Scanning := False;
    End

    { != }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '!=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>=';
      Inc(LexColNo, 2); Scanning := False;
    End

    { && }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '&') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '&&';
      Inc(LexColNo, 2); Scanning := False;
    End

    { || }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '||';
      Inc(LexColNo, 2); Scanning := False;
    End

    { << }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<<';
      Inc(LexColNo, 2); Scanning := False;
    End

    { >> }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>>';
      Inc(LexColNo, 2); Scanning := False;
    End

    { ## (token paste) }
    Else If (Ch = '#') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '#') Then
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '##';
      Inc(LexColNo, 2); Scanning := False;
    End

    { --- Operateurs et ponctuation simple (1 caractere) --- }

    { Operateurs unaires/binaires }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '%') Or (Ch = '&') Or (Ch = '|') Or (Ch = '^') Or
            (Ch = '<') Or (Ch = '>') Or (Ch = '=') Or (Ch = '!') Or
            (Ch = '~') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation }
    Else If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
            (Ch = '{') Or (Ch = '}') Or (Ch = ';') Or (Ch = ',') Or
            (Ch = '.') Or (Ch = ':') Or (Ch = '?') Or (Ch = '#') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ligne '
        + IntToStr_(LexLineNo) + ')');
      Inc(LexColNo);
    End;
  End;
End;

{ ============================================================ }
{ TODO 03 - PREPROCESSEUR (#define, #include, #if)             }
{ ============================================================ }

Const
  MAX_MACROS        = 512;   { nombre max de macros definies       }
  MAX_INCLUDE_DEPTH = 16;    { profondeur max d inclusions         }
  MAX_COND_DEPTH    = 32;    { profondeur max de #if imbriques     }
  MAX_MACRO_PARAMS  = 16;    { nombre max de parametres de macro   }

Type
  TMacro = Record
    Name    : TString;       { nom de la macro                     }
    Value   : TString;       { valeur de remplacement               }
    Defined : Boolean;       { macro active ?                       }
    HasArgs : Boolean;       { macro fonctionnelle ?                }
    NArgs   : Integer;       { nombre de parametres                 }
    Args    : Array[0..MAX_MACRO_PARAMS - 1] Of TString;
  End;

  TCondFrame = Record
    Active   : Boolean;      { branche courante active ?            }
    WasTrue  : Boolean;      { une branche a-t-elle ete active ?    }
    HadElse  : Boolean;      { #else deja rencontre ?               }
  End;

Const
  MAX_INC_LINES = 4096;      { nombre max de lignes injectees       }

Var
  { Table des macros }
  MacroTab   : Array[0..MAX_MACROS - 1] Of TMacro;
  MacroCount : Integer;

  { Buffer de lignes injectees (inclusions) }
  IncBuf     : Array[0..MAX_INC_LINES - 1] Of TString;
  IncBufCount : Integer;     { nombre de lignes dans le buffer      }
  IncBufPos  : Integer;      { position courante dans le buffer     }
  IncBufActive : Boolean;    { on lit du buffer au lieu du fichier   }

  { Pile de conditionnels }
  CondStack  : Array[0..MAX_COND_DEPTH - 1] Of TCondFrame;
  CondTop    : Integer;      { -1 = pas de conditionnel en cours    }

  { Nom du fichier source courant (pour messages d erreur) }
  CurFileName : TString;

{ ------------------------------------------------------------ }
{ Gestion des macros                                           }
{ ------------------------------------------------------------ }

Function MacroFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  MacroFind := -1;
  For I := 0 To MacroCount - 1 Do
    If MacroTab[I].Defined And (MacroTab[I].Name = Name) Then
    Begin
      MacroFind := I;
      Exit;
    End;
End;

Procedure MacroDefine(Const Name, Value : TString);
Var Idx : Integer;
Begin
  Idx := MacroFind(Name);
  If Idx >= 0 Then
  Begin
    MacroTab[Idx].Value   := Value;
    MacroTab[Idx].HasArgs := False;
    MacroTab[Idx].NArgs   := 0;
    Exit;
  End;
  If MacroCount >= MAX_MACROS Then
  Begin
    WarnMsg('trop de macros definies (max ' +
      IntToStr_(MAX_MACROS) + ')');
    Exit;
  End;
  MacroTab[MacroCount].Name    := Name;
  MacroTab[MacroCount].Value   := Value;
  MacroTab[MacroCount].Defined := True;
  MacroTab[MacroCount].HasArgs := False;
  MacroTab[MacroCount].NArgs   := 0;
  Inc(MacroCount);
End;

Procedure MacroUndef(Const Name : TString);
Var Idx : Integer;
Begin
  Idx := MacroFind(Name);
  If Idx >= 0 Then
    MacroTab[Idx].Defined := False;
End;

Function MacroIsDefined(Const Name : TString) : Boolean;
Begin
  MacroIsDefined := MacroFind(Name) >= 0;
End;

{ ------------------------------------------------------------ }
{ Fonctions auxiliaires pour le preprocesseur                   }
{ ------------------------------------------------------------ }

{ Sauter les espaces dans une chaine a partir de la position P }
Procedure PPSkipBlanks(Const S : TString; Var P : Integer);
Begin
  While (P <= Length(S)) And
        ((S[P] = ' ') Or (S[P] = #9)) Do
    Inc(P);
End;

{ Extraire un identificateur a partir de la position P }
Function PPReadIdent(Const S : TString; Var P : Integer) : TString;
Var R : TString;
Begin
  R := '';
  While (P <= Length(S)) And
        (((S[P] >= 'A') And (S[P] <= 'Z')) Or
         ((S[P] >= 'a') And (S[P] <= 'z')) Or
         ((S[P] >= '0') And (S[P] <= '9')) Or
         (S[P] = '_')) Do
  Begin
    If Length(R) < MAX_STR Then
      R := R + S[P];
    Inc(P);
  End;
  PPReadIdent := R;
End;

{ Extraire le reste de la ligne (valeur de macro) }
Function PPReadRest(Const S : TString; P : Integer) : TString;
Var R : TString;
    L : Integer;
Begin
  { Trim trailing whitespace }
  L := Length(S);
  While (L >= P) And ((S[L] = ' ') Or (S[L] = #9)) Do
    Dec(L);
  If P > L Then
    R := ''
  Else
    R := Copy(S, P, L - P + 1);
  PPReadRest := R;
End;

{ Evaluer une expression constante entiere simple pour #if     }
{ Supporte : nombres decimaux, identifiants (defined(X), ou   }
{ macro -> 0 si indéfinie), operateurs ! && || == != < > <= >= }
{ + - * / % , parentheses                                      }
Function PPEvalExpr(Const S : TString) : LongInt;  Forward;

{ Evaluer un atome (nombre, defined(), ident, parenthese) }
Function PPEvalAtom(Const S : TString; Var P : Integer) : LongInt;
Var
  Name : TString;
  V    : LongInt;
  Idx  : Integer;
  ErrC : Integer;
  Neg  : Boolean;
  Invt : Boolean;
Begin
  PPSkipBlanks(S, P);
  Neg  := False;
  Invt := False;

  { Operateur unaire - }
  If (P <= Length(S)) And (S[P] = '-') Then
  Begin
    Neg := True;
    Inc(P);
    PPSkipBlanks(S, P);
  End;

  { Operateur unaire ! }
  If (P <= Length(S)) And (S[P] = '!') Then
  Begin
    Invt := True;
    Inc(P);
    PPSkipBlanks(S, P);
  End;

  V := 0;

  If (P <= Length(S)) And (S[P] = '(') Then
  Begin
    Inc(P);
    V := PPEvalExpr(S);
    PPSkipBlanks(S, P);
    If (P <= Length(S)) And (S[P] = ')') Then Inc(P);
  End
  Else If (P <= Length(S)) And (S[P] >= '0') And (S[P] <= '9') Then
  Begin
    V := 0;
    While (P <= Length(S)) And (S[P] >= '0') And (S[P] <= '9') Do
    Begin
      V := V * 10 + (Ord(S[P]) - Ord('0'));
      Inc(P);
    End;
    { Skip suffixes L/U }
    While (P <= Length(S)) And
          ((S[P] = 'L') Or (S[P] = 'l') Or
           (S[P] = 'U') Or (S[P] = 'u')) Do
      Inc(P);
  End
  Else If (P <= Length(S)) And
          (((S[P] >= 'A') And (S[P] <= 'Z')) Or
           ((S[P] >= 'a') And (S[P] <= 'z')) Or
           (S[P] = '_')) Then
  Begin
    Name := PPReadIdent(S, P);
    If Name = 'defined' Then
    Begin
      PPSkipBlanks(S, P);
      If (P <= Length(S)) And (S[P] = '(') Then
      Begin
        Inc(P);
        PPSkipBlanks(S, P);
        Name := PPReadIdent(S, P);
        PPSkipBlanks(S, P);
        If (P <= Length(S)) And (S[P] = ')') Then Inc(P);
      End
      Else
      Begin
        PPSkipBlanks(S, P);
        Name := PPReadIdent(S, P);
      End;
      If MacroIsDefined(Name) Then V := 1 Else V := 0;
    End
    Else
    Begin
      Idx := MacroFind(Name);
      If Idx >= 0 Then
      Begin
        Val(MacroTab[Idx].Value, V, ErrC);
        If ErrC <> 0 Then V := 0;
      End
      Else
        V := 0;
    End;
  End;

  If Neg Then V := -V;
  If Invt Then
  Begin
    If V = 0 Then V := 1 Else V := 0;
  End;

  PPEvalAtom := V;
End;

{ Evaluer les operateurs binaires (simplifies) }
Function PPEvalExpr(Const S : TString) : LongInt;
Var
  P      : Integer;
  Left   : LongInt;
  Right  : LongInt;
  Op     : Char;
  Op2    : Char;
Begin
  P := 1;

  { Evaluation gauche-a-droite des operateurs binaires }
  Left := PPEvalAtom(S, P);

  While P <= Length(S) Do
  Begin
    PPSkipBlanks(S, P);
    If P > Length(S) Then Break;

    Op := S[P];
    Op2 := #0;
    If P < Length(S) Then Op2 := S[P + 1];

    { Operateurs a 2 caracteres }
    If (Op = '&') And (Op2 = '&') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If (Left <> 0) And (Right <> 0) Then Left := 1
      Else Left := 0;
    End
    Else If (Op = '|') And (Op2 = '|') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If (Left <> 0) Or (Right <> 0) Then Left := 1
      Else Left := 0;
    End
    Else If (Op = '=') And (Op2 = '=') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If Left = Right Then Left := 1 Else Left := 0;
    End
    Else If (Op = '!') And (Op2 = '=') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If Left <> Right Then Left := 1 Else Left := 0;
    End
    Else If (Op = '<') And (Op2 = '=') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If Left <= Right Then Left := 1 Else Left := 0;
    End
    Else If (Op = '>') And (Op2 = '=') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      If Left >= Right Then Left := 1 Else Left := 0;
    End
    { Operateurs a 1 caractere }
    Else If Op = '<' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      If Left < Right Then Left := 1 Else Left := 0;
    End
    Else If Op = '>' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      If Left > Right Then Left := 1 Else Left := 0;
    End
    Else If Op = '+' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left + Right;
    End
    Else If Op = '-' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left - Right;
    End
    Else If Op = '*' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left * Right;
    End
    Else If Op = '/' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      If Right <> 0 Then Left := Left Div Right
      Else Left := 0;
    End
    Else If Op = '%' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      If Right <> 0 Then Left := Left Mod Right
      Else Left := 0;
    End
    Else
      Break;
  End;

  PPEvalExpr := Left;
End;

{ ------------------------------------------------------------ }
{ Etat conditionnel : sommes-nous dans une branche active ?    }
{ ------------------------------------------------------------ }

Function PPIsActive : Boolean;
Var I : Integer;
Begin
  PPIsActive := True;
  For I := 0 To CondTop Do
    If Not CondStack[I].Active Then
    Begin
      PPIsActive := False;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ Expansion de macros dans une ligne                           }
{ ------------------------------------------------------------ }

Function PPExpandMacros(Const S : TString) : TString;
Var
  Result_ : TString;
  I       : Integer;
  Idx     : Integer;
  Name    : TString;
  Expanded : Boolean;
Begin
  Result_ := S;
  { Simple pass : chercher des identifiants et les remplacer   }
  { Note : on ne fait qu un seul passage pour eviter les       }
  { boucles infinies                                            }
  Expanded := True;
  While Expanded Do
  Begin
    Expanded := False;
    I := 1;
    While I <= Length(Result_) Do
    Begin
      { Sauter les chaines et caracteres }
      If (Result_[I] = '"') Then
      Begin
        Inc(I);
        While (I <= Length(Result_)) And (Result_[I] <> '"') Do
        Begin
          If Result_[I] = '\' Then Inc(I);
          Inc(I);
        End;
        If I <= Length(Result_) Then Inc(I);
      End
      Else If (Result_[I] = '''') Then
      Begin
        Inc(I);
        While (I <= Length(Result_)) And (Result_[I] <> '''') Do
        Begin
          If Result_[I] = '\' Then Inc(I);
          Inc(I);
        End;
        If I <= Length(Result_) Then Inc(I);
      End
      { Identifier ? }
      Else If ((Result_[I] >= 'A') And (Result_[I] <= 'Z')) Or
              ((Result_[I] >= 'a') And (Result_[I] <= 'z')) Or
              (Result_[I] = '_') Then
      Begin
        Name := '';
        Idx := I;
        While (I <= Length(Result_)) And
              (((Result_[I] >= 'A') And (Result_[I] <= 'Z')) Or
               ((Result_[I] >= 'a') And (Result_[I] <= 'z')) Or
               ((Result_[I] >= '0') And (Result_[I] <= '9')) Or
               (Result_[I] = '_')) Do
        Begin
          Name := Name + Result_[I];
          Inc(I);
        End;
        { Rechercher la macro }
        If MacroFind(Name) >= 0 Then
        Begin
          { Ne pas expander dans defined() }
          If Name = 'defined' Then
          Begin
            { skip }
          End
          Else
          Begin
            Result_ := Copy(Result_, 1, Idx - 1) +
                        MacroTab[MacroFind(Name)].Value +
                        Copy(Result_, I, Length(Result_) - I + 1);
            Expanded := True;
            Break;  { recommencer depuis le debut }
          End;
        End;
      End
      Else
        Inc(I);
    End;
  End;
  PPExpandMacros := Result_;
End;

{ ------------------------------------------------------------ }
{ En-tetes standard C built-in (stubs)                         }
{ On definit simplement des macros pour les constantes          }
{ ------------------------------------------------------------ }

Procedure PPIncludeBuiltin(Const Header : TString);
Begin
  If (Header = 'stdio.h') Or (Header = '<stdio.h>') Then
  Begin
    MacroDefine('EOF', '(-1)');
    MacroDefine('NULL', '((void*)0)');
    MacroDefine('BUFSIZ', '512');
    MacroDefine('FILENAME_MAX', '260');
    MacroDefine('FOPEN_MAX', '20');
    MacroDefine('_IOFBF', '0');
    MacroDefine('_IOLBF', '1');
    MacroDefine('_IONBF', '2');
    MacroDefine('SEEK_SET', '0');
    MacroDefine('SEEK_CUR', '1');
    MacroDefine('SEEK_END', '2');
    MacroDefine('stdin', '(&__stdin)');
    MacroDefine('stdout', '(&__stdout)');
    MacroDefine('stderr', '(&__stderr)');
    MacroDefine('_STDIO_H', '1');
  End
  Else If (Header = 'stdlib.h') Or (Header = '<stdlib.h>') Then
  Begin
    MacroDefine('NULL', '((void*)0)');
    MacroDefine('EXIT_SUCCESS', '0');
    MacroDefine('EXIT_FAILURE', '1');
    MacroDefine('RAND_MAX', '32767');
    MacroDefine('MB_CUR_MAX', '1');
    MacroDefine('_STDLIB_H', '1');
  End
  Else If (Header = 'string.h') Or (Header = '<string.h>') Then
  Begin
    MacroDefine('NULL', '((void*)0)');
    MacroDefine('_STRING_H', '1');
  End
  Else If (Header = 'stddef.h') Or (Header = '<stddef.h>') Then
  Begin
    MacroDefine('NULL', '((void*)0)');
    MacroDefine('offsetof', '__builtin_offsetof');
    MacroDefine('_STDDEF_H', '1');
  End
  Else If (Header = 'limits.h') Or (Header = '<limits.h>') Then
  Begin
    MacroDefine('CHAR_BIT', '8');
    MacroDefine('SCHAR_MIN', '(-128)');
    MacroDefine('SCHAR_MAX', '127');
    MacroDefine('UCHAR_MAX', '255');
    MacroDefine('CHAR_MIN', '(-128)');
    MacroDefine('CHAR_MAX', '127');
    MacroDefine('MB_LEN_MAX', '1');
    MacroDefine('SHRT_MIN', '(-32768)');
    MacroDefine('SHRT_MAX', '32767');
    MacroDefine('USHRT_MAX', '65535');
    MacroDefine('INT_MIN', '(-2147483647-1)');
    MacroDefine('INT_MAX', '2147483647');
    MacroDefine('UINT_MAX', '4294967295');
    MacroDefine('LONG_MIN', '(-2147483647L-1)');
    MacroDefine('LONG_MAX', '2147483647L');
    MacroDefine('ULONG_MAX', '4294967295UL');
    MacroDefine('_LIMITS_H', '1');
  End
  Else If (Header = 'float.h') Or (Header = '<float.h>') Then
  Begin
    MacroDefine('FLT_RADIX', '2');
    MacroDefine('FLT_DIG', '6');
    MacroDefine('FLT_MANT_DIG', '24');
    MacroDefine('FLT_MAX_EXP', '128');
    MacroDefine('FLT_MIN_EXP', '(-125)');
    MacroDefine('DBL_DIG', '15');
    MacroDefine('DBL_MANT_DIG', '53');
    MacroDefine('DBL_MAX_EXP', '1024');
    MacroDefine('DBL_MIN_EXP', '(-1021)');
    MacroDefine('_FLOAT_H', '1');
  End
  Else If (Header = 'errno.h') Or (Header = '<errno.h>') Then
  Begin
    MacroDefine('EDOM', '33');
    MacroDefine('ERANGE', '34');
    MacroDefine('errno', '(*__errno_location())');
    MacroDefine('_ERRNO_H', '1');
  End
  Else If (Header = 'assert.h') Or (Header = '<assert.h>') Then
  Begin
    MacroDefine('_ASSERT_H', '1');
  End
  Else If (Header = 'ctype.h') Or (Header = '<ctype.h>') Then
  Begin
    MacroDefine('_CTYPE_H', '1');
  End
  Else If (Header = 'math.h') Or (Header = '<math.h>') Then
  Begin
    MacroDefine('HUGE_VAL', '1e308');
    MacroDefine('M_PI', '3.14159265358979323846');
    MacroDefine('M_E', '2.71828182845904523536');
    MacroDefine('_MATH_H', '1');
  End
  Else If (Header = 'stdarg.h') Or (Header = '<stdarg.h>') Then
  Begin
    MacroDefine('_STDARG_H', '1');
  End
  Else If (Header = 'signal.h') Or (Header = '<signal.h>') Then
  Begin
    MacroDefine('SIGINT', '2');
    MacroDefine('SIGILL', '4');
    MacroDefine('SIGABRT', '6');
    MacroDefine('SIGFPE', '8');
    MacroDefine('SIGSEGV', '11');
    MacroDefine('SIGTERM', '15');
    MacroDefine('SIG_DFL', '0');
    MacroDefine('SIG_IGN', '1');
    MacroDefine('SIG_ERR', '(-1)');
    MacroDefine('_SIGNAL_H', '1');
  End
  Else If (Header = 'setjmp.h') Or (Header = '<setjmp.h>') Then
  Begin
    MacroDefine('_SETJMP_H', '1');
  End
  Else If (Header = 'locale.h') Or (Header = '<locale.h>') Then
  Begin
    MacroDefine('LC_ALL', '0');
    MacroDefine('LC_COLLATE', '1');
    MacroDefine('LC_CTYPE', '2');
    MacroDefine('LC_MONETARY', '3');
    MacroDefine('LC_NUMERIC', '4');
    MacroDefine('LC_TIME', '5');
    MacroDefine('_LOCALE_H', '1');
  End
  Else If (Header = 'time.h') Or (Header = '<time.h>') Then
  Begin
    MacroDefine('CLOCKS_PER_SEC', '1000');
    MacroDefine('NULL', '((void*)0)');
    MacroDefine('_TIME_H', '1');
  End;
  { En-tetes inconnus : ignorer silencieusement }
End;

{ ------------------------------------------------------------ }
{ Inclusion de fichier (#include "file")                       }
{ ------------------------------------------------------------ }

Procedure PPPushInclude(Const FileName : TString);
Var
  FullPath : TString;
  F        : Text;
  L        : TString;
Begin
  { Essayer le chemin tel quel d abord }
  FullPath := FileName;
  Assign(F, FullPath);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    { Essayer dans le repertoire du fichier source courant }
    FullPath := ExtractDir(CurFileName) + FileName;
    Assign(F, FullPath);
    {$I-}
    Reset(F);
    {$I+}
    If IOResult <> 0 Then
    Begin
      { Essayer dans le repertoire du fichier source principal }
      FullPath := ExtractDir(Opts.SrcFile) + FileName;
      Assign(F, FullPath);
      {$I-}
      Reset(F);
      {$I+}
      If IOResult <> 0 Then
      Begin
        WarnMsg('impossible d''ouvrir le fichier inclus: ' + FileName);
        Exit;
      End;
    End;
  End;

  { Lire tout le fichier dans le buffer }
  IncBufCount := 0;
  While (Not EOF(F)) And (IncBufCount < MAX_INC_LINES) Do
  Begin
    {$I-}
    ReadLn(F, L);
    {$I+}
    If IOResult <> 0 Then Break;
    IncBuf[IncBufCount] := L;
    Inc(IncBufCount);
  End;
  {$I-}
  Close(F);
  {$I+}
  If IOResult <> 0 Then ; { ignorer erreur }

  If IncBufCount = 0 Then Exit;

  { Activer la lecture depuis le buffer }
  IncBufPos    := 0;
  IncBufActive := True;
End;

{ ------------------------------------------------------------ }
{ Traitement des directives preprocesseur                      }
{ Retourne True si la ligne a ete traitee (et le lexeur doit   }
{ passer a la ligne suivante)                                  }
{ ------------------------------------------------------------ }

Function PPHandleDirective : Boolean;
Var
  P        : Integer;
  Dir      : TString;
  Name     : TString;
  Value    : TString;
  Expr     : TString;
  FileName : TString;
  Ch       : Char;
  Active   : Boolean;
Begin
  PPHandleDirective := False;

  { La ligne commence par # (apres des espaces) }
  P := 1;
  PPSkipBlanks(LexLine, P);
  If (P > Length(LexLine)) Or (LexLine[P] <> '#') Then Exit;
  Inc(P);  { sauter le # }
  PPSkipBlanks(LexLine, P);
  Dir := PPReadIdent(LexLine, P);

  Active := PPIsActive;

  { --- Directives conditionnelles (toujours traitees) --- }

  If Dir = 'ifdef' Then
  Begin
    PPSkipBlanks(LexLine, P);
    Name := PPReadIdent(LexLine, P);
    If CondTop >= MAX_COND_DEPTH - 1 Then
    Begin
      WarnMsg('imbrication conditionnelle trop profonde');
      PPHandleDirective := True;
      Exit;
    End;
    Inc(CondTop);
    If Active Then
    Begin
      CondStack[CondTop].Active  := MacroIsDefined(Name);
      CondStack[CondTop].WasTrue := CondStack[CondTop].Active;
    End
    Else
    Begin
      CondStack[CondTop].Active  := False;
      CondStack[CondTop].WasTrue := True;
    End;
    CondStack[CondTop].HadElse := False;
    PPHandleDirective := True;
    Exit;
  End;

  If Dir = 'ifndef' Then
  Begin
    PPSkipBlanks(LexLine, P);
    Name := PPReadIdent(LexLine, P);
    If CondTop >= MAX_COND_DEPTH - 1 Then
    Begin
      WarnMsg('imbrication conditionnelle trop profonde');
      PPHandleDirective := True;
      Exit;
    End;
    Inc(CondTop);
    If Active Then
    Begin
      CondStack[CondTop].Active  := Not MacroIsDefined(Name);
      CondStack[CondTop].WasTrue := CondStack[CondTop].Active;
    End
    Else
    Begin
      CondStack[CondTop].Active  := False;
      CondStack[CondTop].WasTrue := True;
    End;
    CondStack[CondTop].HadElse := False;
    PPHandleDirective := True;
    Exit;
  End;

  If Dir = 'if' Then
  Begin
    PPSkipBlanks(LexLine, P);
    Expr := PPExpandMacros(PPReadRest(LexLine, P));
    If CondTop >= MAX_COND_DEPTH - 1 Then
    Begin
      WarnMsg('imbrication conditionnelle trop profonde');
      PPHandleDirective := True;
      Exit;
    End;
    Inc(CondTop);
    If Active Then
    Begin
      CondStack[CondTop].Active  := PPEvalExpr(Expr) <> 0;
      CondStack[CondTop].WasTrue := CondStack[CondTop].Active;
    End
    Else
    Begin
      CondStack[CondTop].Active  := False;
      CondStack[CondTop].WasTrue := True;
    End;
    CondStack[CondTop].HadElse := False;
    PPHandleDirective := True;
    Exit;
  End;

  If Dir = 'elif' Then
  Begin
    If CondTop < 0 Then
    Begin
      WarnMsg('#elif sans #if correspondant');
      PPHandleDirective := True;
      Exit;
    End;
    If CondStack[CondTop].HadElse Then
      WarnMsg('#elif apres #else');
    PPSkipBlanks(LexLine, P);
    Expr := PPExpandMacros(PPReadRest(LexLine, P));
    { Verifier si le parent est actif }
    If CondTop = 0 Then
      Active := True
    Else
    Begin
      Active := True;
      If Not CondStack[CondTop - 1].Active Then
        Active := False;
    End;
    If Active And (Not CondStack[CondTop].WasTrue) And
       (PPEvalExpr(Expr) <> 0) Then
    Begin
      CondStack[CondTop].Active  := True;
      CondStack[CondTop].WasTrue := True;
    End
    Else
      CondStack[CondTop].Active := False;
    PPHandleDirective := True;
    Exit;
  End;

  If Dir = 'else' Then
  Begin
    If CondTop < 0 Then
    Begin
      WarnMsg('#else sans #if correspondant');
      PPHandleDirective := True;
      Exit;
    End;
    If CondStack[CondTop].HadElse Then
      WarnMsg('#else en double');
    CondStack[CondTop].HadElse := True;
    { Verifier si le parent est actif }
    If CondTop = 0 Then
      Active := True
    Else
    Begin
      Active := True;
      If Not CondStack[CondTop - 1].Active Then
        Active := False;
    End;
    If Active And (Not CondStack[CondTop].WasTrue) Then
      CondStack[CondTop].Active := True
    Else
      CondStack[CondTop].Active := False;
    PPHandleDirective := True;
    Exit;
  End;

  If Dir = 'endif' Then
  Begin
    If CondTop < 0 Then
      WarnMsg('#endif sans #if correspondant')
    Else
      Dec(CondTop);
    PPHandleDirective := True;
    Exit;
  End;

  { --- Les directives suivantes ne sont traitees que si actives --- }

  If Not Active Then
  Begin
    PPHandleDirective := True;
    Exit;
  End;

  { #define }
  If Dir = 'define' Then
  Begin
    PPSkipBlanks(LexLine, P);
    Name := PPReadIdent(LexLine, P);
    If Name = '' Then
    Begin
      WarnMsg('#define sans nom de macro');
      PPHandleDirective := True;
      Exit;
    End;
    { Verifier si macro fonctionnelle (parenthese sans espace) }
    If (P <= Length(LexLine)) And (LexLine[P] = '(') Then
    Begin
      { Macro fonctionnelle - on stocke la definition complete }
      { Pour simplifier, on traite comme une macro simple       }
      { en incluant les parametres dans la valeur               }
      Value := Copy(LexLine, P, Length(LexLine) - P + 1);
      { Trim trailing whitespace }
      While (Length(Value) > 0) And
            ((Value[Length(Value)] = ' ') Or
             (Value[Length(Value)] = #9)) Do
        Value := Copy(Value, 1, Length(Value) - 1);
      MacroDefine(Name, Value);
    End
    Else
    Begin
      PPSkipBlanks(LexLine, P);
      Value := PPReadRest(LexLine, P);
      MacroDefine(Name, Value);
    End;
    PPHandleDirective := True;
    Exit;
  End;

  { #undef }
  If Dir = 'undef' Then
  Begin
    PPSkipBlanks(LexLine, P);
    Name := PPReadIdent(LexLine, P);
    If Name <> '' Then
      MacroUndef(Name);
    PPHandleDirective := True;
    Exit;
  End;

  { #include }
  If Dir = 'include' Then
  Begin
    PPSkipBlanks(LexLine, P);
    If P > Length(LexLine) Then
    Begin
      WarnMsg('#include sans nom de fichier');
      PPHandleDirective := True;
      Exit;
    End;
    Ch := LexLine[P];
    If Ch = '"' Then
    Begin
      { Inclusion locale : #include "fichier" }
      Inc(P);
      FileName := '';
      While (P <= Length(LexLine)) And (LexLine[P] <> '"') Do
      Begin
        FileName := FileName + LexLine[P];
        Inc(P);
      End;
      { Essayer d ouvrir le fichier localement }
      PPPushInclude(FileName);
    End
    Else If Ch = '<' Then
    Begin
      { Inclusion systeme : #include <fichier> }
      Inc(P);
      FileName := '';
      While (P <= Length(LexLine)) And (LexLine[P] <> '>') Do
      Begin
        FileName := FileName + LexLine[P];
        Inc(P);
      End;
      { Utiliser les en-tetes built-in }
      PPIncludeBuiltin(FileName);
    End
    Else
    Begin
      WarnMsg('#include: format inattendu');
    End;
    PPHandleDirective := True;
    Exit;
  End;

  { #pragma - ignorer silencieusement }
  If Dir = 'pragma' Then
  Begin
    PPHandleDirective := True;
    Exit;
  End;

  { #error }
  If Dir = 'error' Then
  Begin
    PPSkipBlanks(LexLine, P);
    FatalError('#error: ' + PPReadRest(LexLine, P));
    PPHandleDirective := True;
    Exit;
  End;

  { #warning }
  If Dir = 'warning' Then
  Begin
    PPSkipBlanks(LexLine, P);
    WarnMsg('#warning: ' + PPReadRest(LexLine, P));
    PPHandleDirective := True;
    Exit;
  End;

  { #line - ignorer }
  If Dir = 'line' Then
  Begin
    PPHandleDirective := True;
    Exit;
  End;

  { Directive vide (#) ou inconnue }
  If Dir = '' Then
  Begin
    PPHandleDirective := True;
    Exit;
  End;

  WarnMsg('directive preprocesseur inconnue: #' + Dir);
  PPHandleDirective := True;
End;

{ ------------------------------------------------------------ }
{ Initialisation du preprocesseur                              }
{ ------------------------------------------------------------ }

Procedure PPInit;
Var I : Integer;
Begin
  MacroCount  := 0;
  For I := 0 To MAX_MACROS - 1 Do
    MacroTab[I].Defined := False;
  CondTop      := -1;
  IncBufCount  := 0;
  IncBufPos    := 0;
  IncBufActive := False;

  { Macros predefinies standard }
  MacroDefine('__CCW32__', '1');
  MacroDefine('__STDC__', '1');
  MacroDefine('__STDC_VERSION__', '199901L');
  MacroDefine('__i386__', '1');
  MacroDefine('__WIN32__', '1');
  MacroDefine('_WIN32', '1');
End;

{ ------------------------------------------------------------ }
{ LexNextTokenPP : wrapper autour de LexNextToken qui gere     }
{ le preprocesseur (directives et expansion de macros)         }
{ ------------------------------------------------------------ }

Procedure LexNextTokenPP;
Var
  P           : Integer;
  PPLineDone  : Boolean;
  SaveLine    : Integer;
Begin
  Repeat
    { === Si on est en mode buffer d inclusion === }
    If IncBufActive Then
    Begin
      { Si la ligne courante est epuisee, charger la suivante }
      While LexColNo > Length(LexLine) Do
      Begin
        If IncBufPos >= IncBufCount Then
        Begin
          { Buffer epuise }
          IncBufActive := False;
          Break;
        End;

        LexLine := IncBuf[IncBufPos];
        Inc(IncBufPos);
        Inc(TotalLines);
        LexColNo := 1;

        { Verifier si c est une directive preprocesseur }
        P := 1;
        PPSkipBlanks(LexLine, P);
        If (P <= Length(LexLine)) And (LexLine[P] = '#') Then
        Begin
          If PPHandleDirective Then
          Begin
            LexColNo := Length(LexLine) + 1;
            Continue;
          End;
        End;

        { Si branche inactive, sauter la ligne }
        If Not PPIsActive Then
        Begin
          LexColNo := Length(LexLine) + 1;
          Continue;
        End;

        { Expansion de macros }
        LexLine := PPExpandMacros(LexLine);
      End;

      { Si le buffer est epuise, retourner en mode fichier }
      If Not IncBufActive Then Continue;

      { Scanner un token depuis la ligne courante }
      LexNextToken;
      If CurToken.Kind <> TK_EOF Then
      Begin
        PrintToken(CurToken);
        Exit;
      End;
      { TK_EOF dans le buffer : forcer passage a la prochaine ligne }
      LexColNo := Length(LexLine) + 1;
      Continue;
    End;

    { === Mode normal : lecture du fichier === }
    PPLineDone := False;
    Repeat
      { Avancer a la prochaine ligne si fin de ligne atteinte }
      While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
        LexNextLine;

      If LexEOF Then
      Begin
        CurToken.Kind := TK_EOF;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := LexColNo;
        Exit;
      End;

      { On est au debut d une ligne (LexColNo = 1) ? }
      If LexColNo = 1 Then
      Begin
        { Verifier si c est une directive preprocesseur }
        P := 1;
        PPSkipBlanks(LexLine, P);
        If (P <= Length(LexLine)) And (LexLine[P] = '#') Then
        Begin
          If PPHandleDirective Then
          Begin
            LexColNo := Length(LexLine) + 1;
            { Si une inclusion a ete activee, traiter le buffer }
            If IncBufActive Then
            Begin
              PPLineDone := True;
              Continue;
            End;
            Continue;
          End;
        End;

        { Si branche inactive, sauter toute la ligne }
        If Not PPIsActive Then
        Begin
          LexColNo := Length(LexLine) + 1;
          Continue;
        End;

        { Expansion de macros dans la ligne courante }
        LexLine := PPExpandMacros(LexLine);
      End;

      PPLineDone := True;
    Until PPLineDone;

    { Si une inclusion buffer est active, retourner en haut }
    If IncBufActive Then Continue;

    { Sauvegarder le numero de ligne avant le scan }
    SaveLine := LexLineNo;

    { Scanner le prochain token }
    LexNextToken;

    { Si le lexeur a change de ligne (commentaire multi-lignes),   }
    { verifier si la nouvelle ligne est une directive               }
    If (CurToken.Kind <> TK_EOF) And (LexLineNo <> SaveLine) Then
    Begin
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '#') Then
      Begin
        LexColNo := 1;
        Continue;
      End;
    End;

    If CurToken.Kind = TK_EOF Then
    Begin
      PrintToken(CurToken);
      Exit;
    End;

    PrintToken(CurToken);
    Exit;
  Until False;
End;

{ ------------------------------------------------------------ }
{ Run : ouvre le fichier source, lexe et affiche les tokens     }
{ avec support du preprocesseur                                }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  WriteLn('CCW32: Compilation de ', Opts.SrcFile, ' ...');

  { Ouvrir le fichier source }
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  CurFileName := Opts.SrcFile;

  { Initialiser le preprocesseur et le lexeur }
  PPInit;
  LexInit;

  { Scanner tous les tokens via le preprocesseur }
  Repeat
    LexNextTokenPP;
  Until CurToken.Kind = TK_EOF;

  { Verifier les conditionnels non fermes }
  If CondTop >= 0 Then
    WarnMsg(IntToStr_(CondTop + 1) +
      ' directive(s) #if/#ifdef non fermee(s)');

  { Fermer le fichier source }
  LexClose;

  { TODO 04+ : Parse, Emit, Binary }
  WriteLn('CCW32: Lexer+PP OK (', TotalLines, ' lignes, ',
    MacroCount, ' macros)');
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Begin
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
