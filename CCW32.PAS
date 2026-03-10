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

  TODO 02 - LEXEUR (TOKENS C)
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

  TODO 03 - PREPROCESSEUR (#define, #include, #if)
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

{ ------------------------------------------------------------ }
{ Run (stub - sera implemente dans les TODOs suivants)         }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  { TODO 02+ : LexInit, Parse, Emit, Binary }
  WriteLn('CCW32: Compilation de ', Opts.SrcFile, ' ...');
  WriteLn('CCW32: (stub) Le compilateur n''est pas encore implemente.');
  WriteLn('CCW32: Les TODOs 02 a 25 restent a implementer.');
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
