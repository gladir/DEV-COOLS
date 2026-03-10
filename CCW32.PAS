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

  TODO 04 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
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

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_STRUCT/DK_ZERO), IntVal, StrVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddDWord, DataAddByte,
              DataAddArray, DataAddStruct, DataAddZero : variantes d ajout
            DataAddGlobalVar(nom, typeIdx) : cree _CCV_nom dans .DATA
            DataAddStaticVar(func, var, typeIdx) : cree _CCST_N dans .DATA
            ParseDataDecls : parcourt le TokenPool au niveau global
              (profondeur 0 de braces), identifie les declarations de
              variables globales et statiques, les ajoute au DataTab et
              au SymTab. Ignore les fonctions, typedef, struct/union/enum.
            Variables globales (hors de toute fonction) :
              DD/DB dans .DATA avec label _CCV_nom
            Variables static : DD dans .DATA, persistantes entre appels
            Constantes chaines : DB "abc",0 dans .DATA avec label _CCK_N
            Tampons I/O : INBUF (256 octets), NUMBUF (16 octets)
            Variables de handles : HSTDOUT, HSTDIN, HHEAP (DWORD)

  TODO 09 - VARIABLES ET DECLARATIONS [IMPLEMENTE]
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

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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

  TODO 11 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

  TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES [IMPLEMENTE]
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

  TODO 13 - INSTRUCTIONS DE CONTROLE (if / else) [IMPLEMENTE]
            ParseIfStmt : if (cond) stmt [else stmt]
              Emission TEST EAX,EAX / JZ pour condition fausse
              Labels : _CCL_ELSE_N, _CCL_ENDIF_N
              if imbriques : else if (cond) stmt ...
            ParseCompoundStmt : { stmt; stmt; ... }
              Bloc d instructions avec portee locale
              SymEnterScope / SymLeaveScope pour variables de bloc
            ParseExprStmt : expr; (expression comme instruction)
            Instruction vide : ; (no-op)

  TODO 14 - BOUCLES (for / while / do-while) [IMPLEMENTE]
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

  TODO 15 - SWITCH / CASE / DEFAULT [IMPLEMENTE]
            ParseSwitchStmt : switch (expr) { case val: stmts }
              Expression de controle : entier dans EAX, sauvee sur pile
              case valeur : branche pour une valeur (CMP + JE)
              case val1 ... valN : valeurs multiples (CMP successifs)
              default : branche par defaut
              break : sortie du switch (JMP vers fin)
              Fall-through : sans break, execution continue
              Labels : _CCL_CASE_N, _CCL_CDEF_N, _CCL_CEND_N
            SwitchPush / SwitchPop : pile pour switch imbriques
              (max 32 niveaux d imbrication)

  TODO 16 - FONCTIONS ET PROTOTYPES [IMPLEMENTE]
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
            EmitExternFuncs : emettre EXTRN pour les fonctions extern
              Parcourt FuncTab et SymTab apres ParseFuncDecls
              Emet EXTRN _nom:NEAR pour chaque extern utilisateur

  TODO 17 - POINTEURS ET ADRESSES [IMPLEMENTE]
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

  TODO 18 - TABLEAUX [IMPLEMENTE]
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

  TODO 19 - STRUCTURES ET UNIONS [IMPLEMENTE]
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

  TODO 20 - ENUMERATIONS ET TYPEDEF [IMPLEMENTE]
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

  TODO 21 - CHAINES ET ENTREES/SORTIES (printf, scanf) [IMPLEMENTE]
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

  TODO 22 - GOTO, BREAK, CONTINUE, RETURN [IMPLEMENTE]
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

  TODO 23 - OPERATEUR TERNAIRE, CAST ET SIZEOF [IMPLEMENTE]
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

  TODO 24 - RUNTIME MINIMAL WIN32 [IMPLEMENTE]
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

  TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES [IMPLEMENTE]
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

  { PE/COFF format constants (TODO 25) }
  PE_DOS_MAGIC    = $5A4D;       { 'MZ'                              }
  PE_PE_SIG       = $00004550;   { 'PE\0\0'                          }
  PE_MACHINE_I386 = $014C;       { i386                               }
  PE_OPT_SIZE     = 224;         { sizeof IMAGE_OPTIONAL_HEADER32     }
  PE_MAGIC_32     = $010B;       { PE32                               }
  PE_IMG_BASE     = $00400000;   { default image base                 }
  PE_SEC_ALIGN    = $1000;       { section alignment (4KB)            }
  PE_FILE_ALIGN   = $0200;       { file alignment (512)               }
  PE_SUBSYS_CUI   = 3;           { console subsystem                  }
  PE_SCN_TEXT     = $60000020;   { CODE | EXECUTE | READ              }
  PE_SCN_RDATA    = $40000040;   { INIT_DATA | READ                   }
  PE_SCN_BSS      = LongInt($C0000040);   { INIT_DATA | READ | WRITE (data section) }
  MAX_BIN_CODE    = 65536;       { 64 KB max code section             }
  MAX_BIN_DATA    = 65536;       { 64 KB max data section             }
  MAX_BIN_LBL     = 4096;        { max labels                         }
  MAX_BIN_FIX     = 8192;        { max fixups                         }
  PE_NUM_API      = 7;           { number of imported Win32 APIs      }
  COFF_RELOC_DIR32  = 6;         { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32  = 20;        { IMAGE_REL_I386_REL32               }

Type
  TString = String;

  { Types binaires (TODO 25) }
  TBinFixKind = (BFK_ABS32, BFK_REL32, BFK_IAT32);
  TBinFixup = Record
    Offset : LongInt;
    Kind   : TBinFixKind;
    Target : TString;
    InCode : Boolean;
  End;
  TBinLabel = Record
    Name   : TString;
    Offset : LongInt;
    InCode : Boolean;
  End;

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

  { Variables binaires (TODO 25) }
  BinCode     : Array[0..MAX_BIN_CODE - 1] of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] of Byte;
  BinDataLen  : LongInt;
  BinLabels   : Array[0..MAX_BIN_LBL - 1] of TBinLabel;
  BinLblCount : Integer;
  BinFixups   : Array[0..MAX_BIN_FIX - 1] of TBinFixup;
  BinFixCount : Integer;
  BinInCode   : Boolean;

Const
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20',
    '_ReadFile@20', '_GetProcessHeap@0', '_HeapAlloc@12',
    '_HeapFree@12'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
    'GetProcessHeap', 'HeapAlloc', 'HeapFree'
  );

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
{ Supporte : nombres decimaux, hex (0x), identifiants          }
{ (defined(X), ou macro -> 0 si indéfinie), operateurs         }
{ ! ~ && || == != < > <= >= << >> + - * / % & | ^, parentheses}
Function PPEvalExprP(Const S : TString; Var P : Integer) : LongInt;
  Forward;

{ Evaluer un atome (nombre, defined(), ident, parenthese) }
Function PPEvalAtom(Const S : TString; Var P : Integer) : LongInt;
Var
  Name : TString;
  V    : LongInt;
  Idx  : Integer;
  MacroPos : Integer;
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

  { Operateur unaire + }
  If (P <= Length(S)) And (S[P] = '+') Then
  Begin
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

  { Operateur unaire ~ (NOT bitwise) }
  If (P <= Length(S)) And (S[P] = '~') Then
  Begin
    Inc(P);
    V := PPEvalAtom(S, P);
    V := Not V;
    If Neg Then V := -V;
    PPEvalAtom := V;
    Exit;
  End;

  V := 0;

  If (P <= Length(S)) And (S[P] = '(') Then
  Begin
    Inc(P);
    V := PPEvalExprP(S, P);
    PPSkipBlanks(S, P);
    If (P <= Length(S)) And (S[P] = ')') Then Inc(P);
  End
  { Caractere 'x' ou '\n' }
  Else If (P <= Length(S)) And (S[P] = '''') Then
  Begin
    Inc(P);
    If (P <= Length(S)) And (S[P] = '\') Then
    Begin
      Inc(P);
      If P <= Length(S) Then
      Begin
        Case S[P] Of
          'n'  : V := 10;
          't'  : V := 9;
          'r'  : V := 13;
          '0'  : V := 0;
          '\' : V := 92;
          '''' : V := 39;
          '"'  : V := 34;
          'a'  : V := 7;
          'b'  : V := 8;
          'f'  : V := 12;
          'v'  : V := 11;
        Else
          V := Ord(S[P]);
        End;
        Inc(P);
      End;
    End
    Else If P <= Length(S) Then
    Begin
      V := Ord(S[P]);
      Inc(P);
    End;
    If (P <= Length(S)) And (S[P] = '''') Then Inc(P);
  End
  { Entier hexadecimal 0x... }
  Else If (P <= Length(S)) And (S[P] = '0') And
          (P < Length(S)) And
          ((S[P + 1] = 'x') Or (S[P + 1] = 'X')) Then
  Begin
    Inc(P, 2);
    While (P <= Length(S)) And IsHexDigit(S[P]) Do
    Begin
      V := V * 16 + HexVal(S[P]);
      Inc(P);
    End;
    While (P <= Length(S)) And
          ((S[P] = 'L') Or (S[P] = 'l') Or
           (S[P] = 'U') Or (S[P] = 'u')) Do
      Inc(P);
  End
  Else If (P <= Length(S)) And (S[P] >= '0') And (S[P] <= '9') Then
  Begin
    V := 0;
    While (P <= Length(S)) And (S[P] >= '0') And (S[P] <= '9') Do
    Begin
      V := V * 10 + (Ord(S[P]) - Ord('0'));
      Inc(P);
    End;
    { Skip suffixes L/U/f/F }
    While (P <= Length(S)) And
          ((S[P] = 'L') Or (S[P] = 'l') Or
           (S[P] = 'U') Or (S[P] = 'u') Or
           (S[P] = 'F') Or (S[P] = 'f')) Do
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
        { Evaluer la valeur de la macro recursivement }
        MacroPos := 1;
        V := PPEvalExprP(MacroTab[Idx].Value, MacroPos);
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

{ Evaluer les operateurs binaires avec position de lecture }
Function PPEvalExprP(Const S : TString; Var P : Integer) : LongInt;
Var
  Left   : LongInt;
  Right  : LongInt;
  Op     : Char;
  Op2    : Char;
Begin
  { Evaluation gauche-a-droite des operateurs binaires }
  Left := PPEvalAtom(S, P);

  While P <= Length(S) Do
  Begin
    PPSkipBlanks(S, P);
    If P > Length(S) Then Break;

    Op := S[P];
    If Op = ')' Then Break;  { fin de sous-expression parenthesee }
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
    Else If (Op = '<') And (Op2 = '<') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      Left := Left Shl Right;
    End
    Else If (Op = '>') And (Op2 = '>') Then
    Begin
      Inc(P, 2);
      Right := PPEvalAtom(S, P);
      Left := Left Shr Right;
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
    Else If (Op = '&') And (Op2 <> '&') Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left And Right;
    End
    Else If (Op = '|') And (Op2 <> '|') Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left Or Right;
    End
    Else If Op = '^' Then
    Begin
      Inc(P);
      Right := PPEvalAtom(S, P);
      Left := Left Xor Right;
    End
    Else
      Break;
  End;

  PPEvalExprP := Left;
End;

{ Wrapper : evaluer une expression PP depuis le debut d une chaine }
Function PPEvalExpr(Const S : TString) : LongInt;
Var P : Integer;
Begin
  P := 1;
  PPEvalExpr := PPEvalExprP(S, P);
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

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES                            }
{ ============================================================ }

Const
  MAX_DATA     = 512;   { nombre max d entrees dans le pool de donnees }
  MAX_TOKENS   = 16384; { nombre max de tokens stockes                  }

  { Prefixes de mangling pour les labels generes }
  CC_STR_PFX  = '_CCK_';   { string constants                         }
  CC_VAR_PFX  = '_CCV_';   { variables                                }
  CC_FUNC_PFX = '_CCF_';   { functions                                }
  CC_LBL_PFX  = '_CCL_';   { labels internes                          }
  CC_RT_PFX   = '_CCRT_';  { runtime routines                         }
  CC_ARR_PFX  = '_CCA_';   { arrays                                   }
  CC_STR_PFX2 = '_CCS_';   { structs                                  }
  CC_UNI_PFX  = '_CCU_';   { unions                                   }
  CC_ENM_PFX  = '_CCE_';   { enums                                    }
  CC_STA_PFX  = '_CCST_';  { static variables                         }

Type
  { Types d entrees dans le pool de donnees }
  TDataKind = (
    DK_STR,     { chaine ASCIIZ (DB 'xxx',0)                         }
    DK_DWORD,   { valeur 32 bits (DD nnn)                             }
    DK_BYTE,    { valeur 8 bits (DB nnn)                              }
    DK_ARRAY,   { tableau (DB ElemCount DUP(0))                       }
    DK_RES,     { espace reserve (DB Size DUP(0))                     }
    DK_STRUCT,  { structure (DB Size DUP(0))                          }
    DK_ZERO     { espace initialise a zero (DB Size DUP(0))          }
  );

  { Un enregistrement du pool de donnees }
  TDataRec = Record
    LblName   : TString;    { label ASM (ex: _CCK_1, _CCV_x)         }
    Kind      : TDataKind;  { type de donnee                           }
    IntVal    : LongInt;     { valeur entiere (pour DK_DWORD, DK_BYTE) }
    StrVal    : TString;     { contenu chaine (pour DK_STR)            }
    ElemCount : Integer;     { nombre d elements (pour DK_ARRAY)       }
    ElemSize  : Integer;     { taille d un element (pour DK_ARRAY)     }
  End;

  { Taille connue d un type C de base }
  TCSizeInfo = Record
    Name : TString;         { nom du type (int, char, long, etc.)      }
    Size : Integer;         { taille en octets                          }
  End;

Var
  { Pool de donnees (segment .DATA) }
  DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount  : Integer;
  DataEmittedCount : Integer; { nombre d entrees deja emises (TODO 21) }

  { Compteur de labels auto-generes }
  LabelGenSeq : Integer;

  { Pool de tokens (pour le parseur futur) }
  TokenPool  : Array[0..MAX_TOKENS - 1] Of TToken;
  TokenCount : Integer;

{ ------------------------------------------------------------ }
{ Table des tailles de types C de base (Win32, 32 bits)        }
{ ------------------------------------------------------------ }

Const
  MAX_CTYPE_SIZES = 18;
  CTypeSizes : Array[0..MAX_CTYPE_SIZES - 1] Of TCSizeInfo = (
    (Name: 'char';              Size: 1),
    (Name: 'signed char';       Size: 1),
    (Name: 'unsigned char';     Size: 1),
    (Name: 'short';             Size: 2),
    (Name: 'signed short';      Size: 2),
    (Name: 'unsigned short';    Size: 2),
    (Name: 'int';               Size: 4),
    (Name: 'signed int';        Size: 4),
    (Name: 'unsigned int';      Size: 4),
    (Name: 'signed';            Size: 4),
    (Name: 'unsigned';          Size: 4),
    (Name: 'long';              Size: 4),
    (Name: 'signed long';       Size: 4),
    (Name: 'unsigned long';     Size: 4),
    (Name: 'float';             Size: 4),
    (Name: 'double';            Size: 8),
    (Name: 'long double';       Size: 8),
    (Name: 'void';              Size: 0)
  );

{ ------------------------------------------------------------ }
{ DataInit : initialiser le pool de donnees                    }
{ ------------------------------------------------------------ }

Procedure DataInit;
Var I : Integer;
Begin
  DataCount   := 0;
  DataEmittedCount := 0;
  LabelGenSeq := 0;
  TokenCount  := 0;
  For I := 0 To MAX_DATA - 1 Do
  Begin
    DataTab[I].LblName   := '';
    DataTab[I].Kind      := DK_STR;
    DataTab[I].IntVal    := 0;
    DataTab[I].StrVal    := '';
    DataTab[I].ElemCount := 0;
    DataTab[I].ElemSize  := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ DataAdd : ajouter une entree generique dans le pool          }
{ ------------------------------------------------------------ }

Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString;
                 AElemCount : Integer; AElemSize : Integer) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    WarnMsg('pool de donnees plein (MAX_DATA=' + IntToStr_(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := AElemCount;
  DataTab[DataCount].ElemSize  := AElemSize;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ------------------------------------------------------------ }
{ DataAddStr : ajouter une chaine avec label auto-genere       }
{ Retourne le label (ex: _CCK_1)                               }
{ ------------------------------------------------------------ }

Function DataAddStr(Const S : TString) : TString;
Var Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := CC_STR_PFX + IntToStr_(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S, 0, 0);
  DataAddStr := Lbl;
End;

{ ------------------------------------------------------------ }
{ DataAddDWord : ajouter une valeur DWORD avec label           }
{ ------------------------------------------------------------ }

Function DataAddDWord(Const Lbl : TString; Val : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, Val, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddByte : ajouter une valeur BYTE avec label             }
{ ------------------------------------------------------------ }

Function DataAddByte(Const Lbl : TString; Val : Integer) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, Val, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddArray : ajouter un tableau avec label                 }
{ ------------------------------------------------------------ }

Function DataAddArray(Const Lbl : TString;
                      AElemCount : Integer;
                      AElemSize : Integer) : Integer;
Begin
  DataAddArray := DataAdd(Lbl, DK_ARRAY, 0, '', AElemCount, AElemSize);
End;

{ ------------------------------------------------------------ }
{ DataAddRes : ajouter un espace reserve avec label            }
{ ------------------------------------------------------------ }

Function DataAddRes(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddRes := DataAdd(Lbl, DK_RES, Size, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddStruct : ajouter une structure (DB Size DUP(0))       }
{ ------------------------------------------------------------ }

Function DataAddStruct(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddStruct := DataAdd(Lbl, DK_STRUCT, Size, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddZero : ajouter un espace initialise a zero            }
{ ------------------------------------------------------------ }

Function DataAddZero(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddZero := DataAdd(Lbl, DK_ZERO, Size, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataFindStr : rechercher si une chaine est deja dans le pool }
{ Retourne l index ou -1 si absente                            }
{ ------------------------------------------------------------ }

Function DataFindStr(Const S : TString) : Integer;
Var I : Integer;
Begin
  DataFindStr := -1;
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataFindStr := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ DataGetOrAddStr : retourne le label d une chaine existante   }
{ ou l ajoute si elle n existe pas encore                      }
{ ------------------------------------------------------------ }

Function DataGetOrAddStr(Const S : TString) : TString;
Var Idx : Integer;
Begin
  Idx := DataFindStr(S);
  If Idx >= 0 Then
    DataGetOrAddStr := DataTab[Idx].LblName
  Else
    DataGetOrAddStr := DataAddStr(S);
End;

{ ------------------------------------------------------------ }
{ CTypeSizeof : retourne la taille d un type C de base         }
{ Retourne -1 si le type est inconnu                           }
{ ------------------------------------------------------------ }

Function CTypeSizeof(Const TypeName : TString) : Integer;
Var I : Integer;
Begin
  CTypeSizeof := -1;
  For I := 0 To MAX_CTYPE_SIZES - 1 Do
    If CTypeSizes[I].Name = TypeName Then
    Begin
      CTypeSizeof := CTypeSizes[I].Size;
      Exit;
    End;
  { Pointeurs : tout type suivi de * a la taille d un pointeur }
  If (Length(TypeName) > 1) And (TypeName[Length(TypeName)] = '*') Then
  Begin
    CTypeSizeof := 4;  { 32 bits }
    Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ ConstEvalAtom : evaluer un atome dans une expression const   }
{ Supporte : entiers, sizeof(type), sizeof(expr), caracteres   }
{ ------------------------------------------------------------ }

Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
  Forward;

Function ConstEvalAtom(Const S : TString; Var Pos : Integer) : LongInt;
Var
  N    : LongInt;
  Neg  : Boolean;
  Id   : TString;
  Ch   : Char;
  Depth: Integer;
  TypeArg : TString;
  Size : Integer;
  MacroIdx : Integer;
  MacroPos : Integer;
Begin
  N := 0;

  { Sauter les blancs }
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
    Inc(Pos);

  If Pos > Length(S) Then
  Begin
    ConstEvalAtom := 0;
    Exit;
  End;

  { Operateur unaire - }
  Neg := False;
  If (Pos <= Length(S)) And (S[Pos] = '-') Then
  Begin
    Neg := True;
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { Operateur unaire + }
  If (Pos <= Length(S)) And (S[Pos] = '+') Then
  Begin
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { Operateur unaire ! (NOT logique) }
  If (Pos <= Length(S)) And (S[Pos] = '!') Then
  Begin
    Inc(Pos);
    N := ConstEvalAtom(S, Pos);
    If N = 0 Then N := 1 Else N := 0;
    ConstEvalAtom := N;
    Exit;
  End;

  { Operateur unaire ~ (NOT bitwise) }
  If (Pos <= Length(S)) And (S[Pos] = '~') Then
  Begin
    Inc(Pos);
    N := ConstEvalAtom(S, Pos);
    N := Not N;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Parentheses }
  If (Pos <= Length(S)) And (S[Pos] = '(') Then
  Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos);
    If (Pos <= Length(S)) And (S[Pos] = ')') Then
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Caractere 'x' ou '\n' }
  If (Pos <= Length(S)) And (S[Pos] = '''') Then
  Begin
    Inc(Pos);
    If (Pos <= Length(S)) And (S[Pos] = '\') Then
    Begin
      Inc(Pos);
      If Pos <= Length(S) Then
      Begin
        Ch := S[Pos];
        Inc(Pos);
        Case Ch Of
          'n'  : N := 10;
          't'  : N := 9;
          'r'  : N := 13;
          '0'  : N := 0;
          '\' : N := 92;
          '''' : N := 39;
          '"'  : N := 34;
          'a'  : N := 7;
          'b'  : N := 8;
          'f'  : N := 12;
          'v'  : N := 11;
        Else
          N := Ord(Ch);
        End;
      End;
    End
    Else If Pos <= Length(S) Then
    Begin
      N := Ord(S[Pos]);
      Inc(Pos);
    End;
    { Sauter le ' fermant }
    If (Pos <= Length(S)) And (S[Pos] = '''') Then
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Entier hexadecimal 0x... }
  If (Pos < Length(S)) And (S[Pos] = '0') And
     ((S[Pos + 1] = 'x') Or (S[Pos + 1] = 'X')) Then
  Begin
    Inc(Pos, 2);
    While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
    Begin
      N := N * 16 + HexVal(S[Pos]);
      Inc(Pos);
    End;
    { Sauter les suffixes }
    While (Pos <= Length(S)) And
          ((S[Pos] = 'u') Or (S[Pos] = 'U') Or
           (S[Pos] = 'l') Or (S[Pos] = 'L')) Do
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Entier octal 0... }
  If (Pos <= Length(S)) And (S[Pos] = '0') And
     (Pos < Length(S)) And IsOctDigit(S[Pos + 1]) Then
  Begin
    Inc(Pos);
    While (Pos <= Length(S)) And IsOctDigit(S[Pos]) Do
    Begin
      N := N * 8 + (Ord(S[Pos]) - Ord('0'));
      Inc(Pos);
    End;
    { Sauter les suffixes }
    While (Pos <= Length(S)) And
          ((S[Pos] = 'u') Or (S[Pos] = 'U') Or
           (S[Pos] = 'l') Or (S[Pos] = 'L')) Do
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Entier decimal }
  If (Pos <= Length(S)) And IsDigit(S[Pos]) Then
  Begin
    While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
    Begin
      N := N * 10 + (Ord(S[Pos]) - Ord('0'));
      Inc(Pos);
    End;
    { Sauter la partie flottante si present (tronquer) }
    If (Pos <= Length(S)) And (S[Pos] = '.') Then
    Begin
      Inc(Pos);
      While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
        Inc(Pos);
    End;
    { Sauter les suffixes }
    While (Pos <= Length(S)) And
          ((S[Pos] = 'u') Or (S[Pos] = 'U') Or
           (S[Pos] = 'l') Or (S[Pos] = 'L') Or
           (S[Pos] = 'f') Or (S[Pos] = 'F')) Do
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Identificateur : sizeof, alignof, ou constante definie }
  If (Pos <= Length(S)) And IsIdentStart(S[Pos]) Then
  Begin
    Id := '';
    While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
    Begin
      Id := Id + S[Pos];
      Inc(Pos);
    End;

    { sizeof(type) ou sizeof(expr) }
    If Id = 'sizeof' Then
    Begin
      While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
        Inc(Pos);
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        { Extraire l argument entre parentheses }
        TypeArg := '';
        Depth := 1;
        While (Pos <= Length(S)) And (Depth > 0) Do
        Begin
          If S[Pos] = '(' Then Inc(Depth)
          Else If S[Pos] = ')' Then
          Begin
            Dec(Depth);
            If Depth = 0 Then
            Begin
              Inc(Pos);
              Break;
            End;
          End;
          TypeArg := TypeArg + S[Pos];
          Inc(Pos);
        End;
        { Supprimer les espaces en tete et en queue }
        While (Length(TypeArg) > 0) And
              ((TypeArg[1] = ' ') Or (TypeArg[1] = #9)) Do
          Delete(TypeArg, 1, 1);
        While (Length(TypeArg) > 0) And
              ((TypeArg[Length(TypeArg)] = ' ') Or
               (TypeArg[Length(TypeArg)] = #9)) Do
          Delete(TypeArg, Length(TypeArg), 1);
        { Rechercher la taille du type }
        Size := CTypeSizeof(TypeArg);
        If Size >= 0 Then
          N := Size
        Else
          N := 4;  { par defaut : int = 4 octets sur Win32 }
      End
      Else
        N := 4;  { sizeof sans parentheses : taille par defaut }
      If Neg Then N := -N;
      ConstEvalAtom := N;
      Exit;
    End;

    { alignof / _Alignof }
    If (Id = 'alignof') Or (Id = '_Alignof') Then
    Begin
      While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
        Inc(Pos);
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        TypeArg := '';
        Depth := 1;
        While (Pos <= Length(S)) And (Depth > 0) Do
        Begin
          If S[Pos] = '(' Then Inc(Depth)
          Else If S[Pos] = ')' Then
          Begin
            Dec(Depth);
            If Depth = 0 Then
            Begin
              Inc(Pos);
              Break;
            End;
          End;
          TypeArg := TypeArg + S[Pos];
          Inc(Pos);
        End;
        { Pour Win32/x86, l alignement est egal a la taille (max 4) }
        While (Length(TypeArg) > 0) And
              ((TypeArg[1] = ' ') Or (TypeArg[1] = #9)) Do
          Delete(TypeArg, 1, 1);
        While (Length(TypeArg) > 0) And
              ((TypeArg[Length(TypeArg)] = ' ') Or
               (TypeArg[Length(TypeArg)] = #9)) Do
          Delete(TypeArg, Length(TypeArg), 1);
        Size := CTypeSizeof(TypeArg);
        If Size < 0 Then Size := 4;
        If Size > 4 Then Size := 4;  { alignement max 4 sur x86 }
        N := Size;
      End
      Else
        N := 4;
      If Neg Then N := -N;
      ConstEvalAtom := N;
      Exit;
    End;

    { Rechercher dans les macros #define }
    Begin
      MacroIdx := MacroFind(Id);
      If MacroIdx >= 0 Then
      Begin
        { Evaluer la valeur de la macro recursivement }
        MacroPos := 1;
        N := ConstEvalExpr(MacroTab[MacroIdx].Value, MacroPos);
      End
      Else
        N := 0;  { identifiant inconnu = 0 }
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Rien trouve }
  If Neg Then N := -N;
  ConstEvalAtom := N;
End;

{ ------------------------------------------------------------ }
{ ConstEvalExpr : evaluer une expression constante complete    }
{ Supporte : +, -, *, /, %, <<, >>, &, |, ^, ==, !=, <, >,    }
{   <=, >=, &&, ||, ternaire ? :                               }
{ ------------------------------------------------------------ }

Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
Var
  Left, Right : LongInt;
  Op : TString;
Begin
  Left := ConstEvalAtom(S, Pos);

  While Pos <= Length(S) Do
  Begin
    { Sauter les blancs }
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
    If Pos > Length(S) Then Break;

    { Detecter l operateur }
    Op := '';
    If S[Pos] = ')' Then Break;  { fin de sous-expression }
    If S[Pos] = ':' Then Break;  { partie ternaire }
    If S[Pos] = ',' Then Break;  { separateur }

    { Ternaire ? : }
    If S[Pos] = '?' Then
    Begin
      Inc(Pos);
      Right := ConstEvalExpr(S, Pos);
      { Sauter le : }
      While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
        Inc(Pos);
      If (Pos <= Length(S)) And (S[Pos] = ':') Then
        Inc(Pos);
      If Left <> 0 Then
        Left := Right
      Else
        Left := ConstEvalExpr(S, Pos);
      Continue;
    End;

    { Operateurs a 2 caracteres }
    If Pos < Length(S) Then
    Begin
      Op := S[Pos];
      Op := Op + S[Pos + 1];
      If (Op = '<<') Or (Op = '>>') Or (Op = '==') Or (Op = '!=') Or
         (Op = '<=') Or (Op = '>=') Or (Op = '&&') Or (Op = '||') Then
      Begin
        Inc(Pos, 2);
        Right := ConstEvalAtom(S, Pos);
        If Op = '<<' Then Left := Left Shl Right
        Else If Op = '>>' Then Left := Left Shr Right
        Else If Op = '==' Then Begin If Left = Right Then Left := 1
                                     Else Left := 0; End
        Else If Op = '!=' Then Begin If Left <> Right Then Left := 1
                                     Else Left := 0; End
        Else If Op = '<=' Then Begin If Left <= Right Then Left := 1
                                     Else Left := 0; End
        Else If Op = '>=' Then Begin If Left >= Right Then Left := 1
                                     Else Left := 0; End
        Else If Op = '&&' Then Begin If (Left <> 0) And (Right <> 0) Then
                                       Left := 1
                                     Else Left := 0; End
        Else If Op = '||' Then Begin If (Left <> 0) Or (Right <> 0) Then
                                       Left := 1
                                     Else Left := 0; End;
        Continue;
      End;
    End;

    { Operateurs a 1 caractere }
    Op := S[Pos];
    If (Op = '+') Or (Op = '-') Or (Op = '*') Or (Op = '/') Or
       (Op = '%') Or (Op = '&') Or (Op = '|') Or (Op = '^') Or
       (Op = '<') Or (Op = '>') Then
    Begin
      Inc(Pos);
      Right := ConstEvalAtom(S, Pos);
      If Op = '+' Then Left := Left + Right
      Else If Op = '-' Then Left := Left - Right
      Else If Op = '*' Then Left := Left * Right
      Else If Op = '/' Then
      Begin
        If Right <> 0 Then Left := Left Div Right
        Else Begin WarnMsg('division par zero dans expression constante');
                   Left := 0; End;
      End
      Else If Op = '%' Then
      Begin
        If Right <> 0 Then Left := Left Mod Right
        Else Begin WarnMsg('modulo par zero dans expression constante');
                   Left := 0; End;
      End
      Else If Op = '&' Then Left := Left And Right
      Else If Op = '|' Then Left := Left Or Right
      Else If Op = '^' Then Left := Left Xor Right
      Else If Op = '<' Then
      Begin If Left < Right Then Left := 1 Else Left := 0; End
      Else If Op = '>' Then
      Begin If Left > Right Then Left := 1 Else Left := 0; End;
      Continue;
    End;

    { Pas un operateur reconnu -> fin de l expression }
    Break;
  End;

  ConstEvalExpr := Left;
End;

{ ------------------------------------------------------------ }
{ ConstEval : evaluer une expression constante depuis une       }
{ chaine (point d entree principal)                            }
{ ------------------------------------------------------------ }

Function ConstEval(Const S : TString) : LongInt;
Var P : Integer;
Begin
  P := 1;
  ConstEval := ConstEvalExpr(S, P);
End;

{ ------------------------------------------------------------ }
{ TokenPoolInit : initialiser le pool de tokens                }
{ ------------------------------------------------------------ }

Procedure TokenPoolInit;
Begin
  TokenCount := 0;
End;

{ ------------------------------------------------------------ }
{ TokenPoolAdd : ajouter un token dans le pool                 }
{ ------------------------------------------------------------ }

Procedure TokenPoolAdd(Const T : TToken);
Begin
  If TokenCount >= MAX_TOKENS Then
  Begin
    WarnMsg('pool de tokens plein');
    Exit;
  End;
  TokenPool[TokenCount] := T;
  Inc(TokenCount);
End;

{ ------------------------------------------------------------ }
{ TokenPoolConcatStrings : concatener les chaines adjacentes   }
{ "abc" "def" -> "abcdef"                                      }
{ Parcourt le pool et fusionne les TK_STRING consecutifs       }
{ ------------------------------------------------------------ }

Procedure TokenPoolConcatStrings;
Var
  I, J, Dst : Integer;
  CatStr    : TString;
Begin
  If TokenCount <= 1 Then Exit;
  Dst := 0;
  I := 0;
  While I < TokenCount Do
  Begin
    If TokenPool[I].Kind = TK_STRING Then
    Begin
      { Debut d une sequence de chaines }
      CatStr := TokenPool[I].Val;
      J := I + 1;
      While (J < TokenCount) And (TokenPool[J].Kind = TK_STRING) Do
      Begin
        { Concatener les chaines adjacentes }
        If Length(CatStr) + Length(TokenPool[J].Val) <= MAX_STR Then
          CatStr := CatStr + TokenPool[J].Val
        Else
          WarnMsg('chaine concatenee trop longue, tronquee');
        Inc(J);
      End;
      { Enregistrer la chaine concatenee dans le pool de donnees }
      TokenPool[Dst] := TokenPool[I];
      TokenPool[Dst].Val := CatStr;
      Inc(Dst);
      I := J;
    End
    Else
    Begin
      If Dst <> I Then
        TokenPool[Dst] := TokenPool[I];
      Inc(Dst);
      Inc(I);
    End;
  End;
  TokenCount := Dst;
End;

{ ------------------------------------------------------------ }
{ TokenPoolRegisterStrings : enregistrer toutes les chaines du }
{ pool de tokens dans le pool de donnees, en leur attribuant   }
{ un label unique (_CCK_N) et en evitant les doublons          }
{ ------------------------------------------------------------ }

Procedure TokenPoolRegisterStrings;
Var I : Integer;
Begin
  For I := 0 To TokenCount - 1 Do
  Begin
    If TokenPool[I].Kind = TK_STRING Then
      DataGetOrAddStr(TokenPool[I].Val);
  End;
End;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                                 }
{ ============================================================ }

Const
  MAX_SYM   = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE = 64;   { profondeur max de scopes imbriques          }

Type
  TSymCat = (
    SC_VAR,         { variable locale ou globale                   }
    SC_PARAM,       { parametre de fonction                        }
    SC_FUNC,        { fonction                                     }
    SC_TYPE,        { type defini (typedef, struct tag, enum tag)   }
    SC_FIELD,       { champ de struct/union                        }
    SC_ENUM_VAL,    { valeur d enumeration                         }
    SC_LABEL,       { label (goto)                                 }
    SC_STATIC,      { variable static locale                       }
    SC_EXTERNAL,    { declaration extern                            }
    SC_TYPEDEF,     { alias de type (typedef)                      }
    SC_GLOBAL       { variable globale explicitement exportee       }
  );

  TSymRec = Record
    Name        : TString;     { nom original (minuscules)              }
    MangledName : TString;     { nom mangled pour emission ASM          }
    Cat         : TSymCat;     { categorie du symbole                   }
    TypeIdx     : Integer;     { index du type dans TypeTab (TODO 06)   }
    Offset      : Integer;     { offset stack ou data segment           }
    ScopeLevel  : Integer;     { niveau de scope (0 = global)           }
    ScopeId     : Integer;     { id unique du scope                     }
    IsGlobal    : Boolean;     { visible globalement ?                  }
    IsExternal  : Boolean;     { declare extern ?                       }
    IsStatic    : Boolean;     { stockage statique ?                    }
    ImmVal      : LongInt;     { valeur immediate (enum, const)         }
    ParamCount  : Integer;     { nombre de parametres (fonctions)       }
  End;

Var
  { Table des symboles }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount    : Integer;

  { Gestion des portees }
  CurScopeLevel : Integer;   { niveau de scope courant (0 = global)    }
  CurScopeId    : Integer;   { id du scope courant                     }
  ScopeIdSeq    : Integer;   { sequence pour generer des ids uniques    }

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles                  }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins; Forward;

Procedure SymInit;
Var I : Integer;
Begin
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_VAR;
    SymTab[I].TypeIdx     := -1;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].ScopeId     := 0;
    SymTab[I].IsGlobal    := False;
    SymTab[I].IsExternal  := False;
    SymTab[I].IsStatic    := False;
    SymTab[I].ImmVal      := 0;
    SymTab[I].ParamCount  := 0;
  End;
  SymRegisterBuiltins;
End;

{ ------------------------------------------------------------ }
{ SymMangle : generer un nom mangled pour un symbole            }
{ selon sa categorie                                           }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Begin
  Case Cat Of
    SC_VAR      : SymMangle := CC_VAR_PFX + Name;
    SC_PARAM    : SymMangle := CC_VAR_PFX + Name;
    SC_FUNC     : SymMangle := CC_FUNC_PFX + Name;
    SC_TYPE     : SymMangle := Name;
    SC_FIELD    : SymMangle := Name;
    SC_ENUM_VAL : SymMangle := CC_ENM_PFX + Name;
    SC_LABEL    : SymMangle := CC_LBL_PFX + Name;
    SC_STATIC   : SymMangle := CC_VAR_PFX + Name;
    SC_EXTERNAL : SymMangle := '_' + Name;
    SC_TYPEDEF  : SymMangle := Name;
    SC_GLOBAL   : SymMangle := '_' + Name;
  Else
    SymMangle := CC_VAR_PFX + Name;
  End;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : chercher un symbole dans un scope precis    }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel = Level) And
       ((Level = 0) Or (SymTab[I].ScopeId = CurScopeId)) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole du scope courant vers global   }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                    }
{ Retourne l index du symbole ajoute, ou -1 si erreur          }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Cat : TSymCat;
                TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' +
      IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Permettre la redefinition d un extern par une definition }
    If (SymTab[Dup].Cat = SC_EXTERNAL) And
       (Cat In [SC_FUNC, SC_VAR, SC_GLOBAL]) Then
    Begin
      SymTab[Dup].Cat       := Cat;
      SymTab[Dup].TypeIdx   := TIdx;
      SymTab[Dup].IsExternal := False;
      SymAdd := Dup;
      Exit;
    End
    { Permettre que func/var masque un type pre-declare }
    Else If (SymTab[Dup].Cat = SC_TYPE) And
            (Cat In [SC_FUNC, SC_VAR, SC_GLOBAL]) Then
    Begin
      { On laisse passer, le nouveau symbole sera ajoute }
    End
    Else
    Begin
      WarnMsg('symbole deja defini dans ce scope: ' + Lw);
      SymAdd := Dup;
      Exit;
    End;
  End;

  { Ajouter le symbole }
  SymTab[SymCount].Name        := Lw;
  SymTab[SymCount].MangledName := SymMangle(Lw, Cat);
  SymTab[SymCount].Cat         := Cat;
  SymTab[SymCount].TypeIdx     := TIdx;
  SymTab[SymCount].Offset      := 0;
  SymTab[SymCount].ScopeLevel  := CurScopeLevel;
  SymTab[SymCount].ScopeId     := CurScopeId;
  SymTab[SymCount].IsGlobal    := (CurScopeLevel = 0);
  SymTab[SymCount].IsExternal  := (Cat = SC_EXTERNAL);
  SymTab[SymCount].IsStatic    := (Cat = SC_STATIC);
  SymTab[SymCount].ImmVal      := 0;
  SymTab[SymCount].ParamCount  := 0;

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ SymEnterScope / SymLeaveScope : gestion des portees           }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WarnMsg('profondeur de scope maximale atteinte');
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;
End;

{ ------------------------------------------------------------ }
{ SymRegisterBuiltins : pre-enregistrer les fonctions standard }
{ C en tant que built-in dans la table des symboles            }
{ Le compilateur les reconnait automatiquement sans qu elles   }
{ soient declarees explicitement dans le code source.          }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins;

  Procedure RegFunc(Const Name : TString);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SC_FUNC, -1);
    If R >= 0 Then
    Begin
      SymTab[R].MangledName := '_' + Name;
      SymTab[R].IsExternal  := True;
    End;
  End;

Begin
  { stdio.h }
  RegFunc('clearerr'); RegFunc('fclose');  RegFunc('feof');
  RegFunc('ferror');   RegFunc('fflush');  RegFunc('fgetc');
  RegFunc('fgetpos');  RegFunc('fgets');   RegFunc('fopen');
  RegFunc('fprintf');  RegFunc('fputc');   RegFunc('fputs');
  RegFunc('fread');    RegFunc('freopen'); RegFunc('fscanf');
  RegFunc('fseek');    RegFunc('fsetpos'); RegFunc('ftell');
  RegFunc('fwrite');   RegFunc('getc');    RegFunc('getchar');
  RegFunc('gets');     RegFunc('perror');  RegFunc('printf');
  RegFunc('putc');     RegFunc('putchar'); RegFunc('puts');
  RegFunc('remove');   RegFunc('rename');  RegFunc('rewind');
  RegFunc('scanf');    RegFunc('setbuf');  RegFunc('setvbuf');
  RegFunc('sprintf');  RegFunc('sscanf');  RegFunc('tmpfile');
  RegFunc('tmpnam');   RegFunc('ungetc');  RegFunc('vfprintf');
  RegFunc('vprintf');  RegFunc('vsprintf');

  { stdlib.h }
  RegFunc('abort');    RegFunc('abs');     RegFunc('atexit');
  RegFunc('atof');     RegFunc('atoi');    RegFunc('atol');
  RegFunc('bsearch');  RegFunc('calloc');  RegFunc('div');
  RegFunc('exit');     RegFunc('free');    RegFunc('getenv');
  RegFunc('labs');     RegFunc('ldiv');    RegFunc('malloc');
  RegFunc('qsort');    RegFunc('rand');    RegFunc('realloc');
  RegFunc('srand');    RegFunc('strtod');  RegFunc('strtol');
  RegFunc('strtoul');  RegFunc('system');

  { string.h }
  RegFunc('memchr');   RegFunc('memcmp');  RegFunc('memcpy');
  RegFunc('memmove');  RegFunc('memset');  RegFunc('strcat');
  RegFunc('strchr');   RegFunc('strcmp');   RegFunc('strcpy');
  RegFunc('strcspn');  RegFunc('strerror');RegFunc('strlen');
  RegFunc('strncat');  RegFunc('strncmp'); RegFunc('strncpy');
  RegFunc('strpbrk');  RegFunc('strrchr'); RegFunc('strspn');
  RegFunc('strstr');   RegFunc('strtok');

  { math.h }
  RegFunc('acos');     RegFunc('asin');    RegFunc('atan');
  RegFunc('atan2');    RegFunc('ceil');    RegFunc('cos');
  RegFunc('cosh');     RegFunc('exp');     RegFunc('fabs');
  RegFunc('floor');    RegFunc('fmod');    RegFunc('frexp');
  RegFunc('ldexp');    RegFunc('log');     RegFunc('log10');
  RegFunc('modf');     RegFunc('pow');     RegFunc('sin');
  RegFunc('sinh');     RegFunc('sqrt');    RegFunc('tan');
  RegFunc('tanh');

  { time.h }
  RegFunc('asctime');  RegFunc('clock');   RegFunc('ctime');
  RegFunc('difftime'); RegFunc('gmtime');  RegFunc('localtime');
  RegFunc('mktime');   RegFunc('strftime');RegFunc('time');

  { ctype.h }
  RegFunc('isalnum');  RegFunc('isalpha'); RegFunc('iscntrl');
  RegFunc('isdigit');  RegFunc('isgraph'); RegFunc('islower');
  RegFunc('isprint');  RegFunc('ispunct'); RegFunc('isspace');
  RegFunc('isupper');  RegFunc('isxdigit');RegFunc('tolower');
  RegFunc('toupper');

  { signal.h }
  RegFunc('raise');    RegFunc('signal');

  { setjmp.h }
  RegFunc('longjmp');  RegFunc('setjmp');

  { assert.h }
  RegFunc('assert');

  { stdarg.h }
  RegFunc('va_start'); RegFunc('va_arg');  RegFunc('va_end');
End;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                                   }
{ ============================================================ }

Const
  MAX_TYPE    = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FIELDS  = 64;    { nombre max de champs par struct/union       }
  MAX_PARAMS  = 16;    { nombre max de parametres par type fonction   }

Type
  TTypeKind = (
    TKP_VOID,       { void : taille 0                              }
    TKP_CHAR,        { char : 8 bits signe                          }
    TKP_UCHAR,       { unsigned char : 8 bits non signe             }
    TKP_SHORT,       { short : 16 bits signe                        }
    TKP_USHORT,      { unsigned short : 16 bits non signe           }
    TKP_INT,         { int : 32 bits signe                          }
    TKP_UINT,        { unsigned int : 32 bits non signe             }
    TKP_LONG,        { long : 32 bits signe                         }
    TKP_ULONG,       { unsigned long : 32 bits non signe            }
    TKP_FLOAT,       { float : 32 bits (stub traite en entier)      }
    TKP_DOUBLE,      { double : 64 bits (stub traite en entier)     }
    TKP_POINTER,     { pointeur : 32 bits                           }
    TKP_ARRAY,       { tableau : BaseTypeIdx + ElemCount             }
    TKP_STRUCT,      { structure                                     }
    TKP_UNION,       { union                                         }
    TKP_ENUM,        { enumeration                                   }
    TKP_FUNC         { pointeur de fonction                          }
  );

  TFieldRec = Record
    Name     : TString;    { nom du champ                            }
    TypeIdx  : Integer;    { index du type du champ                   }
    Offset   : Integer;    { offset dans la struct/union               }
  End;

  TTypeRec = Record
    Kind        : TTypeKind;   { categorie du type                    }
    Name        : TString;     { nom du type (ex: 'int', 'myStruct')  }
    Size        : Integer;     { taille en octets                      }
    Align       : Integer;     { alignement en octets                  }
    IsUnsigned  : Boolean;     { type non signe ?                      }
    IsConst     : Boolean;     { qualificateur const ?                 }
    IsVolatile  : Boolean;     { qualificateur volatile ?              }
    BaseTypeIdx : Integer;     { type de base (pointeur, tableau, typedef) }
    ElemCount   : Integer;     { nombre d elements (tableau)            }
    Fields      : Array[0..MAX_FIELDS - 1] Of TFieldRec;
    FieldCount  : Integer;     { nombre de champs (struct/union)        }
    EnumCount   : Integer;     { nombre de valeurs (enum)               }
    ParamCount  : Integer;     { nombre de parametres (func)            }
    ParamTypes  : Array[0..MAX_PARAMS - 1] Of Integer;
    RetTypeIdx  : Integer;     { type de retour (func)                  }
  End;

Var
  { Table des types }
  TypeTab    : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount  : Integer;

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un type dans TypeTab, retourne l index     }
{ ------------------------------------------------------------ }

Function TypeAdd(AKind : TTypeKind; Const AName : TString;
                 ASize : Integer; AAlign : Integer;
                 AIsUnsigned : Boolean;
                 ABaseTypeIdx : Integer) : Integer;
Var I : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE=' + IntToStr_(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;
  TypeTab[TypeCount].Kind        := AKind;
  TypeTab[TypeCount].Name        := AName;
  TypeTab[TypeCount].Size        := ASize;
  TypeTab[TypeCount].Align       := AAlign;
  TypeTab[TypeCount].IsUnsigned  := AIsUnsigned;
  TypeTab[TypeCount].IsConst     := False;
  TypeTab[TypeCount].IsVolatile  := False;
  TypeTab[TypeCount].BaseTypeIdx := ABaseTypeIdx;
  TypeTab[TypeCount].ElemCount   := 0;
  TypeTab[TypeCount].FieldCount  := 0;
  TypeTab[TypeCount].EnumCount   := 0;
  TypeTab[TypeCount].ParamCount  := 0;
  TypeTab[TypeCount].RetTypeIdx  := -1;
  For I := 0 To MAX_FIELDS - 1 Do
  Begin
    TypeTab[TypeCount].Fields[I].Name    := '';
    TypeTab[TypeCount].Fields[I].TypeIdx := -1;
    TypeTab[TypeCount].Fields[I].Offset  := 0;
  End;
  For I := 0 To MAX_PARAMS - 1 Do
    TypeTab[TypeCount].ParamTypes[I] := -1;
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeInit : initialiser la table et enregistrer les types      }
{ primitifs de C (Win32 32 bits)                                }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind        := TKP_VOID;
    TypeTab[I].Name        := '';
    TypeTab[I].Size        := 0;
    TypeTab[I].Align       := 0;
    TypeTab[I].IsUnsigned  := False;
    TypeTab[I].IsConst     := False;
    TypeTab[I].IsVolatile  := False;
    TypeTab[I].BaseTypeIdx := -1;
    TypeTab[I].ElemCount   := 0;
    TypeTab[I].FieldCount  := 0;
    TypeTab[I].EnumCount   := 0;
    TypeTab[I].ParamCount  := 0;
    TypeTab[I].RetTypeIdx  := -1;
  End;

  { Index 0 : void (taille 0, align 0) }
  TypeAdd(TKP_VOID,   'void',           0, 0, False, -1);   { idx 0  }

  { Index 1 : char (8 bits signe) }
  TypeAdd(TKP_CHAR,   'char',           1, 1, False, -1);   { idx 1  }

  { Index 2 : signed char (8 bits signe, alias) }
  TypeAdd(TKP_CHAR,   'signed char',    1, 1, False, -1);   { idx 2  }

  { Index 3 : unsigned char (8 bits non signe) }
  TypeAdd(TKP_UCHAR,  'unsigned char',  1, 1, True,  -1);   { idx 3  }

  { Index 4 : short (16 bits signe) }
  TypeAdd(TKP_SHORT,  'short',          2, 2, False, -1);   { idx 4  }

  { Index 5 : signed short (alias) }
  TypeAdd(TKP_SHORT,  'signed short',   2, 2, False, -1);   { idx 5  }

  { Index 6 : unsigned short (16 bits non signe) }
  TypeAdd(TKP_USHORT, 'unsigned short', 2, 2, True,  -1);   { idx 6  }

  { Index 7 : int (32 bits signe) }
  TypeAdd(TKP_INT,    'int',            4, 4, False, -1);   { idx 7  }

  { Index 8 : signed int (alias) }
  TypeAdd(TKP_INT,    'signed int',     4, 4, False, -1);   { idx 8  }

  { Index 9 : unsigned int (32 bits non signe) }
  TypeAdd(TKP_UINT,   'unsigned int',   4, 4, True,  -1);   { idx 9  }

  { Index 10 : signed (alias de int) }
  TypeAdd(TKP_INT,    'signed',         4, 4, False, -1);   { idx 10 }

  { Index 11 : unsigned (alias de unsigned int) }
  TypeAdd(TKP_UINT,   'unsigned',       4, 4, True,  -1);   { idx 11 }

  { Index 12 : long (32 bits signe sous Win32) }
  TypeAdd(TKP_LONG,   'long',           4, 4, False, -1);   { idx 12 }

  { Index 13 : signed long (alias) }
  TypeAdd(TKP_LONG,   'signed long',    4, 4, False, -1);   { idx 13 }

  { Index 14 : unsigned long (32 bits non signe) }
  TypeAdd(TKP_ULONG,  'unsigned long',  4, 4, True,  -1);   { idx 14 }

  { Index 15 : float (32 bits, stub traite comme entier) }
  TypeAdd(TKP_FLOAT,  'float',          4, 4, False, -1);   { idx 15 }

  { Index 16 : double (64 bits, stub traite comme entier) }
  TypeAdd(TKP_DOUBLE, 'double',         8, 8, False, -1);   { idx 16 }

  { Index 17 : long double (alias double sous Win32) }
  TypeAdd(TKP_DOUBLE, 'long double',    8, 8, False, -1);   { idx 17 }

  { Index 18 : void* (pointeur generique) }
  TypeAdd(TKP_POINTER, 'void *',        4, 4, False, 0);    { idx 18 }

  { Index 19 : char* (pointeur vers char, courant en C) }
  TypeAdd(TKP_POINTER, 'char *',        4, 4, False, 1);    { idx 19 }

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types primitifs enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : trouver un type par son nom exact           }
{ Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const AName : TString) : Integer;
Var I : Integer;
Begin
  TypeFindByName := -1;
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = AName Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ TypeSizeofIdx : retourne la taille d un type par son index   }
{ ------------------------------------------------------------ }

Function TypeSizeofIdx(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeSizeofIdx := 4   { taille par defaut = int (32 bits) }
  Else
    TypeSizeofIdx := TypeTab[Idx].Size;
End;

{ ------------------------------------------------------------ }
{ TypeResolve : resoudre les typedef en suivant BaseTypeIdx     }
{ Retourne l index du type final (non-typedef)                 }
{ ------------------------------------------------------------ }

Function TypeResolve(Idx : Integer) : Integer;
Var Depth : Integer;
    Cur   : Integer;
Begin
  Cur   := Idx;
  Depth := 0;
  While (Cur >= 0) And (Cur < TypeCount) And (Depth < 32) Do
  Begin
    { Si ce n est pas un typedef (BaseTypeIdx pointe vers le type cible }
    { et Kind est le meme que le type original), on est arrive          }
    If TypeTab[Cur].BaseTypeIdx < 0 Then Break;
    { Si le type est un pointeur, array, struct, union, enum, func }
    { alors BaseTypeIdx designe le type element, pas un typedef     }
    If TypeTab[Cur].Kind In [TKP_POINTER, TKP_ARRAY, TKP_STRUCT,
       TKP_UNION, TKP_ENUM, TKP_FUNC] Then Break;
    { Sinon c est un typedef : suivre le lien }
    Cur := TypeTab[Cur].BaseTypeIdx;
    Inc(Depth);
  End;
  TypeResolve := Cur;
End;

{ ------------------------------------------------------------ }
{ TypeIsInteger : retourne True si le type est un type entier  }
{ (char, short, int, long, unsigned variants, enum)            }
{ ------------------------------------------------------------ }

Function TypeIsInteger(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
    TypeIsInteger := False
  Else
    TypeIsInteger := TypeTab[R].Kind In [TKP_CHAR, TKP_UCHAR,
      TKP_SHORT, TKP_USHORT, TKP_INT, TKP_UINT, TKP_LONG,
      TKP_ULONG, TKP_ENUM];
End;

{ ------------------------------------------------------------ }
{ TypeIsArithmetic : entier ou flottant                        }
{ ------------------------------------------------------------ }

Function TypeIsArithmetic(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
    TypeIsArithmetic := False
  Else
    TypeIsArithmetic := TypeTab[R].Kind In [TKP_CHAR, TKP_UCHAR,
      TKP_SHORT, TKP_USHORT, TKP_INT, TKP_UINT, TKP_LONG,
      TKP_ULONG, TKP_FLOAT, TKP_DOUBLE, TKP_ENUM];
End;

{ ------------------------------------------------------------ }
{ TypeIsPointer : retourne True si le type est un pointeur     }
{ ------------------------------------------------------------ }

Function TypeIsPointer(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
    TypeIsPointer := False
  Else
    TypeIsPointer := TypeTab[R].Kind = TKP_POINTER;
End;

{ ------------------------------------------------------------ }
{ TypeCoerce : determine le type resultat d une conversion     }
{ implicite entre deux types (promotion C standard)            }
{ Retourne l index du type promu                               }
{ ------------------------------------------------------------ }

Function TypeCoerce(IdxA, IdxB : Integer) : Integer;
Var RA, RB  : Integer;
    KA, KB  : TTypeKind;
    SA, SB  : Integer;
Begin
  RA := TypeResolve(IdxA);
  RB := TypeResolve(IdxB);

  { Si l un est invalide, retourner l autre }
  If (RA < 0) Or (RA >= TypeCount) Then Begin TypeCoerce := RB; Exit; End;
  If (RB < 0) Or (RB >= TypeCount) Then Begin TypeCoerce := RA; Exit; End;

  KA := TypeTab[RA].Kind;
  KB := TypeTab[RB].Kind;

  { double absorbe tout }
  If (KA = TKP_DOUBLE) Or (KB = TKP_DOUBLE) Then
  Begin
    TypeCoerce := TypeFindByName('double');
    Exit;
  End;

  { float absorbe les entiers }
  If (KA = TKP_FLOAT) Or (KB = TKP_FLOAT) Then
  Begin
    TypeCoerce := TypeFindByName('float');
    Exit;
  End;

  { Si un des deux est un pointeur, le resultat est un pointeur }
  If (KA = TKP_POINTER) Then Begin TypeCoerce := RA; Exit; End;
  If (KB = TKP_POINTER) Then Begin TypeCoerce := RB; Exit; End;

  { Promotion entiere standard C : tout ce qui est plus petit    }
  { que int est promu en int (char, short, enum)                 }
  SA := TypeTab[RA].Size;
  SB := TypeTab[RB].Size;

  { unsigned long + tout = unsigned long }
  If (KA = TKP_ULONG) Or (KB = TKP_ULONG) Then
  Begin
    TypeCoerce := TypeFindByName('unsigned long');
    Exit;
  End;

  { long + tout = long }
  If (KA = TKP_LONG) Or (KB = TKP_LONG) Then
  Begin
    { Si l autre est unsigned int, resultat = unsigned long }
    If (KA = TKP_UINT) Or (KB = TKP_UINT) Then
      TypeCoerce := TypeFindByName('unsigned long')
    Else
      TypeCoerce := TypeFindByName('long');
    Exit;
  End;

  { unsigned int + tout = unsigned int }
  If (KA = TKP_UINT) Or (KB = TKP_UINT) Then
  Begin
    TypeCoerce := TypeFindByName('unsigned int');
    Exit;
  End;

  { Sinon, promotion vers int }
  If (SA >= 4) And (SB >= 4) Then
  Begin
    { Les deux sont au moins int, garder le plus grand }
    If SA >= SB Then TypeCoerce := RA
    Else TypeCoerce := RB;
  End
  Else
    TypeCoerce := TypeFindByName('int');  { promotion vers int }
End;

{ ------------------------------------------------------------ }
{ TypeCompatible : verifie si une affectation dest := src est   }
{ compatible (au sens C : memes types ou conversion implicite) }
{ Retourne True si compatible                                  }
{ ------------------------------------------------------------ }

Function TypeCompatible(IdxDest, IdxSrc : Integer) : Boolean;
Var RD, RS : Integer;
    KD, KS : TTypeKind;
Begin
  RD := TypeResolve(IdxDest);
  RS := TypeResolve(IdxSrc);

  { Types invalides : on accepte pour ne pas bloquer }
  If (RD < 0) Or (RD >= TypeCount) Or
     (RS < 0) Or (RS >= TypeCount) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  KD := TypeTab[RD].Kind;
  KS := TypeTab[RS].Kind;

  { Meme type exact : toujours compatible }
  If RD = RS Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { void est compatible avec rien sauf void }
  If (KD = TKP_VOID) Or (KS = TKP_VOID) Then
  Begin
    TypeCompatible := (KD = TKP_VOID) And (KS = TKP_VOID);
    Exit;
  End;

  { Arithmetique vers arithmetique : toujours OK (avec conversion) }
  If TypeIsArithmetic(RD) And TypeIsArithmetic(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers pointeur : compatible (void* accepte tout) }
  If (KD = TKP_POINTER) And (KS = TKP_POINTER) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers entier : acceptable en C (avec warning) }
  If (KD = TKP_POINTER) And TypeIsInteger(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Entier vers pointeur : acceptable en C (avec warning) }
  If TypeIsInteger(RD) And (KS = TKP_POINTER) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Array vers pointeur : decay standard en C }
  If (KD = TKP_POINTER) And (KS = TKP_ARRAY) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Fonction vers pointeur de fonction }
  If (KD = TKP_POINTER) And (KS = TKP_FUNC) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Struct/Union : compatibles seulement si meme type exact }
  If (KD In [TKP_STRUCT, TKP_UNION]) And (KD = KS) Then
  Begin
    TypeCompatible := (TypeTab[RD].Name = TypeTab[RS].Name);
    Exit;
  End;

  TypeCompatible := False;
End;

{ ============================================================ }
{ TODO 07 - EMETTEUR DE CODE ASM 80386                         }
{ ============================================================ }

Var
  { Compteur global de labels auto-generes }
  EmitLabelSeq : Integer;
  HasMainFunc  : Boolean;     { True si la fonction main() existe       }

{ ------------------------------------------------------------ }
{ EmitOpen : ouvrir le fichier .ASM de sortie                  }
{ ------------------------------------------------------------ }

Procedure EmitOpen(Const AsmFile : TString);
Begin
  Assign(OutF, AsmFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier de sortie: ' + AsmFile);
  OutFOpen := True;
  EmitLabelSeq := 0;
End;

{ ------------------------------------------------------------ }
{ EmitClose : fermer le fichier de sortie                      }
{ ------------------------------------------------------------ }

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    If HasMainFunc Then
      WriteLn(OutF, 'END _main')
    Else
      WriteLn(OutF, 'END');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRaw : ecrire une ligne brute dans le fichier de sortie   }
{ ------------------------------------------------------------ }

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ------------------------------------------------------------ }
{ EmitLabel : ecrire un label suivi de ':'                     }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitInstr : ecrire une instruction avec 8 espaces d indent   }
{ ------------------------------------------------------------ }

Procedure EmitInstr(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', S);
End;

{ ------------------------------------------------------------ }
{ EmitComment : ecrire un commentaire ('; text')               }
{ ------------------------------------------------------------ }

Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

{ ------------------------------------------------------------ }
{ EmitBlankLine : ecrire une ligne vide                        }
{ ------------------------------------------------------------ }

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generer un label unique _CCL_NNNNN               }
{ ------------------------------------------------------------ }

Function LabelGen : TString;
Begin
  Inc(EmitLabelSeq);
  LabelGen := CC_LBL_PFX + IntToStr_(EmitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ EmitHeader : emettre l en-tete ASM pour un programme Win32   }
{ .386 / .MODEL FLAT, STDCALL / EXTRN / .DATA / .CODE         }
{ ------------------------------------------------------------ }

Procedure EmitHeader;
Begin
  EmitComment('CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits');
  EmitComment('Genere automatiquement a partir de : ' + Opts.SrcFile);
  EmitBlankLine;

  { Directive processeur et modele memoire }
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;

  { Declarations externes (imports Win32 kernel32.dll) }
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _ReadFile@20:NEAR');
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitRaw('EXTRN _HeapFree@12:NEAR');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitDataSeg : emettre le segment .DATA avec toutes les       }
{ entrees du DataTab (chaines, valeurs, tableaux, reserves)    }
{ ------------------------------------------------------------ }

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  C    : Char;
Begin
  EmitComment('--- Segment de donnees ---');
  EmitRaw('.DATA');
  EmitBlankLine;

  { Variables predefinies pour les handles et tampons I/O }
  EmitRaw('HSTDOUT  DD 0');
  EmitRaw('HSTDIN   DD 0');
  EmitRaw('HHEAP    DD 0');
  EmitRaw('NUMBUF   DB 16 DUP(0)');
  EmitRaw('INBUF    DB 256 DUP(0)');
  EmitRaw('BYTESWR  DD 0');
  EmitRaw('BYTESRD  DD 0');
  EmitRaw('CRLF     DB 13,10,0');
  EmitBlankLine;

  { Emettre chaque entree du DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_STR:
      Begin
        { Chaine ASCIIZ : DB 'contenu',0 }
        { Regrouper les caracteres imprimables dans des literals }
        { et les non-imprimables en valeurs numeriques           }
        S := '';
        J := 1;
        While J <= Length(DataTab[I].StrVal) Do
        Begin
          C := DataTab[I].StrVal[J];
          If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
          Begin
            { Debut ou continuation d un groupe imprimable }
            If S <> '' Then
              S := S + ',';
            S := S + '''';
            While (J <= Length(DataTab[I].StrVal)) Do
            Begin
              C := DataTab[I].StrVal[J];
              If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
              Begin
                S := S + C;
                Inc(J);
              End
              Else
                Break;
            End;
            S := S + '''';
          End
          Else
          Begin
            { Caractere non-imprimable -> valeur numerique }
            If S <> '' Then
              S := S + ',';
            S := S + IntToStr_(Ord(C));
            Inc(J);
          End;
        End;
        { Ajouter le terminateur nul }
        If S = '' Then
          S := '0'
        Else
          S := S + ',0';
        EmitRaw(DataTab[I].LblName + '  DB ' + S);
      End;

      DK_DWORD:
      Begin
        EmitRaw(DataTab[I].LblName + '  DD ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_BYTE:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_ARRAY:
      Begin
        If DataTab[I].ElemSize = 1 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount * DataTab[I].ElemSize) +
                  ' DUP(0)');
      End;

      DK_RES:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal) + ' DUP(0)');
      End;

      DK_STRUCT:
      Begin
        { Structure : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;

      DK_ZERO:
      Begin
        { Espace initialise a zero : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;
    End; { case }
  End;
  EmitBlankLine;
  DataEmittedCount := DataCount;
End;

{ ------------------------------------------------------------ }
{ EmitCodeSeg : emettre le debut du segment .CODE              }
{ ------------------------------------------------------------ }

Procedure EmitCodeSeg;
Begin
  EmitComment('--- Segment de code ---');
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitProlog : emettre le prologue d une fonction              }
{ PUSH EBP / MOV EBP,ESP / SUB ESP,locals                     }
{ ------------------------------------------------------------ }

Procedure EmitProlog(LocalSize : Integer);
Begin
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  If LocalSize > 0 Then
    EmitInstr('SUB ESP,' + IntToStr_(LocalSize));
End;

{ ------------------------------------------------------------ }
{ EmitEpilog : emettre l epilogue d une fonction               }
{ MOV ESP,EBP / POP EBP / RET                                 }
{ ------------------------------------------------------------ }

Procedure EmitEpilog;
Begin
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 08 - SEGMENT DE DONNEES ET STATIQUES                    }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ DataAddGlobalVar : ajouter une variable globale dans .DATA   }
{ Cree une entree _CCV_nom selon la taille du type             }
{ Retourne l index dans DataTab ou -1                          }
{ ------------------------------------------------------------ }

Function DataAddGlobalVar(Const VarName : TString;
                          TIdx : Integer;
                          InitVal : LongInt) : Integer;
Var
  Lbl  : TString;
  Size : Integer;
Begin
  Lbl  := CC_VAR_PFX + VarName;
  Size := TypeSizeofIdx(TIdx);
  If Size <= 1 Then
    DataAddGlobalVar := DataAdd(Lbl, DK_BYTE, InitVal, '', 0, 0)
  Else If Size <= 4 Then
    DataAddGlobalVar := DataAdd(Lbl, DK_DWORD, InitVal, '', 0, 0)
  Else
    DataAddGlobalVar := DataAdd(Lbl, DK_ZERO, Size, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddStaticVar : ajouter une variable static dans .DATA    }
{ Cree une entree _CCST_N avec label unique                    }
{ Retourne le label genere                                     }
{ ------------------------------------------------------------ }

Function DataAddStaticVar(Const VarName : TString;
                          TIdx : Integer;
                          InitVal : LongInt) : TString;
Var
  Lbl  : TString;
  Size : Integer;
Begin
  Inc(LabelGenSeq);
  Lbl  := CC_STA_PFX + IntToStr_(LabelGenSeq);
  Size := TypeSizeofIdx(TIdx);
  If Size <= 1 Then
    DataAdd(Lbl, DK_BYTE, InitVal, '', 0, 0)
  Else If Size <= 4 Then
    DataAdd(Lbl, DK_DWORD, InitVal, '', 0, 0)
  Else
    DataAdd(Lbl, DK_ZERO, Size, '', 0, 0);
  DataAddStaticVar := Lbl;
End;

{ ------------------------------------------------------------ }
{ IsTypeSpecifier : verifie si un token est un specificateur    }
{ de type C (int, char, short, long, float, double, void, etc) }
{ ------------------------------------------------------------ }

Function IsTypeSpecifier(Const S : TString) : Boolean;
Begin
  IsTypeSpecifier :=
    (S = 'int') Or (S = 'char') Or (S = 'short') Or (S = 'long') Or
    (S = 'float') Or (S = 'double') Or (S = 'void') Or
    (S = 'signed') Or (S = 'unsigned') Or
    (S = 'struct') Or (S = 'union') Or (S = 'enum');
End;

{ ------------------------------------------------------------ }
{ IsStorageClass : verifie si un token est une classe de       }
{ stockage C (static, extern, register, auto, typedef)         }
{ ------------------------------------------------------------ }

Function IsStorageClass(Const S : TString) : Boolean;
Begin
  IsStorageClass :=
    (S = 'static') Or (S = 'extern') Or (S = 'register') Or
    (S = 'auto') Or (S = 'typedef');
End;

{ ------------------------------------------------------------ }
{ IsQualifier : verifie si un token est un qualificateur       }
{ (const, volatile)                                            }
{ ------------------------------------------------------------ }

Function IsQualifier(Const S : TString) : Boolean;
Begin
  IsQualifier :=
    (S = 'const') Or (S = 'volatile');
End;

{ ------------------------------------------------------------ }
{ ParseDataDecls : parcourir le token pool et identifier les   }
{ declarations de variables globales et statiques au niveau 0  }
{                                                              }
{ Algorithme :                                                 }
{   1. Parcourir les tokens en suivant la profondeur de braces }
{   2. Au niveau 0, detecter les patterns de declaration       }
{      [storage-class] [qualificateur] type ident [= val] ;   }
{   3. Ignorer typedef, struct/union/enum definitions, et      }
{      declarations de fonctions (ident suivi de '(')          }
{   4. Ajouter les variables trouvees dans DataTab et SymTab   }
{ ------------------------------------------------------------ }

{ Forward declaration pour ParseStructDef (TODO 19) }
Function ParseStructDef(Var P : Integer;
                        Const TypeName : TString;
                        IsUnion : Boolean) : Integer; Forward;

{ Forward declaration pour ParseEnumDef (TODO 20) }
Function ParseEnumDef(Var P : Integer;
                      Const TypeName : TString) : Integer; Forward;

{ Forward declaration pour ParseTypeFromTokens (TODO 20) }
Function ParseTypeFromTokens(Var P : Integer) : Integer; Forward;

{ Forward declarations pour les fonctions d E/S (TODO 21) }
Procedure ParsePrintfCall; Forward;
Procedure ParseScanfCall; Forward;
Procedure ParsePutsCall; Forward;
Procedure ParsePutcharCall; Forward;
Procedure ParseGetcharCall; Forward;

Procedure ParseDataDecls;
Var
  I         : Integer;
  Depth     : Integer;   { profondeur de braces }
  IsStatic  : Boolean;
  IsExtern  : Boolean;
  TypeIdx   : Integer;
  TypeName  : TString;
  VarName   : TString;
  InitVal   : LongInt;
  HasInit   : Boolean;
  SymIdx    : Integer;
  Lbl       : TString;
  TypeSize  : Integer;
  IsPointer : Boolean;
  ArraySize : Integer;
  IsArray   : Boolean;
Begin
  Depth     := 0;
  I         := 0;

  While I < TokenCount Do
  Begin
    { --- Suivre la profondeur des accolades --- }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '{') Then
    Begin
      Inc(Depth);
      Inc(I);
      Continue;
    End;
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '}') Then
    Begin
      If Depth > 0 Then
        Dec(Depth);
      Inc(I);
      Continue;
    End;

    { --- Seules les declarations au niveau 0 nous interessent --- }
    If Depth > 0 Then
    Begin
      Inc(I);
      Continue;
    End;

    { === Niveau global (Depth = 0) === }
    { Verifier si c est le debut d une declaration potentielle }

    { --- Collecter les modificateurs --- }
    IsStatic   := False;
    IsExtern   := False;
    IsPointer  := False;
    IsArray    := False;
    ArraySize  := 0;
    TypeName   := '';
    TypeIdx    := -1;

    { Sauter les classes de stockage et qualificateurs }
    If (TokenPool[I].Kind = TK_KEYWORD) And IsStorageClass(TokenPool[I].Val) Then
    Begin
      If TokenPool[I].Val = 'static' Then
        IsStatic := True
      Else If TokenPool[I].Val = 'extern' Then
        IsExtern := True
      Else If TokenPool[I].Val = 'typedef' Then
      Begin
        { Parser le typedef : typedef <type> <nom> ; (TODO 20) }
        Inc(I); { sauter 'typedef' }
        If I >= TokenCount Then Break;
        { Sauter les qualificateurs apres typedef }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[I].Val) Do
          Inc(I);
        If I >= TokenCount Then Break;
        { Parser le type source }
        TypeIdx := ParseTypeFromTokens(I);
        If TypeIdx < 0 Then TypeIdx := TypeFindByName('int');
        { Sauter les qualificateurs apres le type }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[I].Val) Do
          Inc(I);
        { Gerer les pointeurs }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
              (TokenPool[I].Val = '*') Do
        Begin
          { Creer un type pointeur }
          TypeIdx := TypeAdd(TKP_POINTER, '', 4, 4, False, TypeIdx);
          Inc(I);
        End;
        { Nom du nouveau type (alias) }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_IDENT) Then
        Begin
          VarName := TokenPool[I].Val;
          Inc(I);
          { Enregistrer le typedef dans TypeTab }
          { Creer un type alias dont BaseTypeIdx pointe vers le type source }
          TypeSize := TypeSizeofIdx(TypeIdx);
          If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
          Begin
            If TypeTab[TypeIdx].Kind In [TKP_STRUCT, TKP_UNION, TKP_ENUM,
               TKP_POINTER, TKP_ARRAY, TKP_FUNC] Then
              { Pour struct/union/enum/ptr/array/func, le type est direct }
              SymIdx := TypeAdd(TypeTab[TypeIdx].Kind, VarName, TypeSize,
                TypeTab[TypeIdx].Align, TypeTab[TypeIdx].IsUnsigned,
                TypeTab[TypeIdx].BaseTypeIdx)
            Else
              { Pour les types de base, creer un alias via BaseTypeIdx }
              SymIdx := TypeAdd(TypeTab[TypeIdx].Kind, VarName, TypeSize,
                TypeTab[TypeIdx].Align, TypeTab[TypeIdx].IsUnsigned,
                TypeIdx);
            If SymIdx >= 0 Then
            Begin
              { Copier les champs pour struct/union }
              If TypeTab[TypeIdx].Kind In [TKP_STRUCT, TKP_UNION] Then
              Begin
                TypeTab[SymIdx].FieldCount := TypeTab[TypeIdx].FieldCount;
                TypeTab[SymIdx].Fields     := TypeTab[TypeIdx].Fields;
              End;
              { Copier EnumCount pour enum }
              If TypeTab[TypeIdx].Kind = TKP_ENUM Then
                TypeTab[SymIdx].EnumCount := TypeTab[TypeIdx].EnumCount;
            End;
          End
          Else
            SymIdx := TypeAdd(TKP_INT, VarName, 4, 4, False, TypeIdx);
          { Enregistrer dans SymTab aussi }
          SymAdd(VarName, SC_TYPEDEF, TypeIdx);
        End;
        { Avancer au ; }
        While (I < TokenCount) And
              Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do
          Inc(I);
        If I < TokenCount Then Inc(I);
        Continue;
      End
      Else If TokenPool[I].Val = 'auto' Then
      Begin
        { auto au niveau global : pas de stockage special, on continue }
      End
      Else If TokenPool[I].Val = 'register' Then
      Begin
        { register au niveau global : traite comme auto, on continue }
      End;
      Inc(I);
      If I >= TokenCount Then Break;
    End;

    { Sauter les qualificateurs (const, volatile) }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
          IsQualifier(TokenPool[I].Val) Do
    Begin
      Inc(I);
    End;
    If I >= TokenCount Then Break;

    { --- Verifier si c est un type de base --- }
    If Not ((TokenPool[I].Kind = TK_KEYWORD) And
            IsTypeSpecifier(TokenPool[I].Val)) And
       Not ((TokenPool[I].Kind = TK_KEYWORD) And
            ((TokenPool[I].Val = 'struct') Or (TokenPool[I].Val = 'union') Or
             (TokenPool[I].Val = 'enum'))) And
       Not ((TokenPool[I].Kind = TK_IDENT) And
            (TypeFindByName(TokenPool[I].Val) >= 0)) Then
    Begin
      { Pas un type connu : peut etre un typedef ou autre -> avancer }
      { Chercher le prochain ';' ou '{' au niveau 0 }
      While (I < TokenCount) Do
      Begin
        If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';') Then
        Begin
          Inc(I);
          Break;
        End;
        If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '{') Then
          Break;
        Inc(I);
      End;
      Continue;
    End;

    { --- Parser le type de base --- }
    { Gerer struct/union/enum : avancer au-dela du tag et de la definition }
    If (TokenPool[I].Val = 'struct') Or (TokenPool[I].Val = 'union') Or
       (TokenPool[I].Val = 'enum') Then
    Begin
      TypeName := TokenPool[I].Val;
      Inc(I);
      If I >= TokenCount Then Break;

      { Tag optionnel }
      If TokenPool[I].Kind = TK_IDENT Then
      Begin
        TypeName := TypeName + ' ' + TokenPool[I].Val;
        Inc(I);
        If I >= TokenCount Then Break;
      End;

      { Definition avec accolades ? (TODO 19 : parser les champs) }
      If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '{') Then
      Begin
        If (TypeName = 'enum') Or (Copy(TypeName, 1, 5) = 'enum ') Then
        Begin
          { Enum : parser la definition avec ParseEnumDef (TODO 20) }
          TypeIdx := ParseEnumDef(I, TypeName);
          If I >= TokenCount Then Break;
        End
        Else
        Begin
          { struct/union : parser la definition avec ParseStructDef }
          TypeIdx := ParseStructDef(I,
            TypeName,
            (TypeName = 'union') Or (Copy(TypeName, 1, 6) = 'union '));
        End;
      End;

      { Chercher le type dans TypeTab }
      If TypeIdx < 0 Then
        TypeIdx := TypeFindByName(TypeName);
      If TypeIdx < 0 Then
        TypeIdx := TypeFindByName('int'); { fallback }

      { Verifier s il y a un declarateur apres la definition }
      { Si on a directement ';' c est juste une definition sans variable }
      If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
         (TokenPool[I].Val = ';') Then
      Begin
        Inc(I);
        Continue;
      End;

      { Sinon, on continue pour parser la variable declaree apres }
    End
    Else
    Begin
      { Type de base simple : int, char, short, long, etc. }
      TypeName := TokenPool[I].Val;
      Inc(I);
      If I >= TokenCount Then Break;

      { Gerer les combinaisons : unsigned int, long int, etc. }
      If (TokenPool[I].Kind = TK_KEYWORD) And
         IsTypeSpecifier(TokenPool[I].Val) Then
      Begin
        { Ex: unsigned int, signed char, long int, short int, long double }
        TypeName := TypeName + ' ' + TokenPool[I].Val;
        Inc(I);
        If I >= TokenCount Then Break;

        { Encore un ? (ex: unsigned long int) }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
           IsTypeSpecifier(TokenPool[I].Val) Then
        Begin
          TypeName := TypeName + ' ' + TokenPool[I].Val;
          Inc(I);
          If I >= TokenCount Then Break;
        End;
      End;

      { Chercher le type dans TypeTab }
      TypeIdx := TypeFindByName(TypeName);
      If TypeIdx < 0 Then
      Begin
        { Essayer sans le prefix (ex: 'unsigned int' -> chercher 'unsigned') }
        TypeIdx := TypeFindByName('int'); { fallback a int }
      End;
    End;

    { --- Sauter les qualificateurs apres le type --- }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
          IsQualifier(TokenPool[I].Val) Do
    Begin
      Inc(I);
    End;
    If I >= TokenCount Then Break;

    { --- Verifier les pointeurs (*) --- }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
          (TokenPool[I].Val = '*') Do
    Begin
      IsPointer := True;
      Inc(I);
    End;
    If I >= TokenCount Then Break;

    { --- Le prochain token doit etre un identifiant --- }
    If TokenPool[I].Kind <> TK_IDENT Then
    Begin
      { Pas un identifiant : avancer au prochain ';' }
      While (I < TokenCount) And
            Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do
        Inc(I);
      If I < TokenCount Then Inc(I);
      Continue;
    End;

    VarName := TokenPool[I].Val;
    Inc(I);
    If I >= TokenCount Then Break;

    { --- Verifier si c est une fonction (suivi de '(') --- }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '(') Then
    Begin
      { C est une declaration/definition de fonction, pas une variable }
      { Avancer au-dela de la fonction }
      While (I < TokenCount) And
            Not ((TokenPool[I].Kind = TK_PUNCT) And
                 ((TokenPool[I].Val = ';') Or (TokenPool[I].Val = '{'))) Do
        Inc(I);
      If (I < TokenCount) And (TokenPool[I].Val = '{') Then
      Begin
        Inc(Depth);
        Inc(I);
      End
      Else If I < TokenCount Then
        Inc(I);
      Continue;
    End;

    { --- Verifier si c est un tableau (suivi de '[') --- }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '[') Then
    Begin
      IsArray := True;
      Inc(I);
      If I >= TokenCount Then Break;
      { Lire la taille du tableau }
      If TokenPool[I].Kind = TK_INTEGER Then
      Begin
        ArraySize := TokenPool[I].IntVal;
        Inc(I);
      End
      Else
        ArraySize := 1; { taille par defaut }
      { Avancer au ']' }
      While (I < TokenCount) And
            Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ']')) Do
        Inc(I);
      If I < TokenCount Then Inc(I);
    End;

    { --- Verifier l initialiseur (= valeur) --- }
    InitVal := 0;
    HasInit := False;
    If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
       (TokenPool[I].Val = '=') Then
    Begin
      HasInit := True;
      Inc(I);
      If I >= TokenCount Then Break;
      { Lire la valeur d initialisation (simple constante) }
      If TokenPool[I].Kind = TK_INTEGER Then
      Begin
        InitVal := TokenPool[I].IntVal;
        Inc(I);
      End
      Else If (TokenPool[I].Kind = TK_OP) And (TokenPool[I].Val = '-') Then
      Begin
        Inc(I);
        If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
        Begin
          InitVal := -TokenPool[I].IntVal;
          Inc(I);
        End;
      End
      Else If TokenPool[I].Kind = TK_CHAR Then
      Begin
        InitVal := TokenPool[I].IntVal;
        Inc(I);
      End
      Else
      Begin
        { Initialiseur complexe : avancer jusqu au ';' ou ',' }
        While (I < TokenCount) And
              Not ((TokenPool[I].Kind = TK_PUNCT) And
                   ((TokenPool[I].Val = ';') Or (TokenPool[I].Val = ','))) Do
          Inc(I);
      End;
    End;

    { --- Ignorer les extern (pas d emission dans .DATA) --- }
    If IsExtern Then
    Begin
      { extern : enregistrer le symbole mais pas de donnee }
      SymIdx := SymFind(VarName);
      If SymIdx < 0 Then
      Begin
        SymIdx := SymAdd(VarName, SC_EXTERNAL, TypeIdx);
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].IsExternal := True;
          SymTab[SymIdx].IsGlobal   := True;
        End;
      End;
      { Avancer au prochain ';' }
      While (I < TokenCount) And
            Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do
        Inc(I);
      If I < TokenCount Then Inc(I);
      Continue;
    End;

    { --- Ajouter la variable dans le DataTab et SymTab --- }
    If IsArray Then
    Begin
      TypeSize := TypeSizeofIdx(TypeIdx);
      If IsPointer Then TypeSize := 4;
      Lbl := CC_VAR_PFX + VarName;
      DataAddArray(Lbl, ArraySize, TypeSize);
      SymIdx := SymFind(VarName);
      If SymIdx < 0 Then
      Begin
        SymIdx := SymAdd(VarName, SC_VAR, TypeIdx);
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].MangledName := Lbl;
          SymTab[SymIdx].IsGlobal := Not IsStatic;
          SymTab[SymIdx].IsStatic := IsStatic;
        End;
      End;
    End
    Else If IsPointer Then
    Begin
      { Pointeur : toujours 4 octets (DD) }
      Lbl := CC_VAR_PFX + VarName;
      DataAddDWord(Lbl, InitVal);
      SymIdx := SymFind(VarName);
      If SymIdx < 0 Then
      Begin
        SymIdx := SymAdd(VarName, SC_VAR, TypeIdx);
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].MangledName := Lbl;
          SymTab[SymIdx].IsGlobal := Not IsStatic;
          SymTab[SymIdx].IsStatic := IsStatic;
        End;
      End;
    End
    Else
    Begin
      { Variable simple }
      Lbl := CC_VAR_PFX + VarName;
      DataAddGlobalVar(VarName, TypeIdx, InitVal);
      SymIdx := SymFind(VarName);
      If SymIdx < 0 Then
      Begin
        If IsStatic Then
          SymIdx := SymAdd(VarName, SC_STATIC, TypeIdx)
        Else
          SymIdx := SymAdd(VarName, SC_GLOBAL, TypeIdx);
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].MangledName := Lbl;
          SymTab[SymIdx].IsGlobal := Not IsStatic;
          SymTab[SymIdx].IsStatic := IsStatic;
          If HasInit Then
            SymTab[SymIdx].ImmVal := InitVal;
        End;
      End;
    End;

    { --- Gerer les declarations multiples (int a, b, c;) --- }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
          (TokenPool[I].Val = ',') Do
    Begin
      Inc(I);
      If I >= TokenCount Then Break;

      { Sauter les qualificateurs et pointeurs }
      IsPointer := False;
      While (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
            (TokenPool[I].Val = '*') Do
      Begin
        IsPointer := True;
        Inc(I);
      End;
      If I >= TokenCount Then Break;

      If TokenPool[I].Kind <> TK_IDENT Then Break;
      VarName := TokenPool[I].Val;
      Inc(I);
      If I >= TokenCount Then Break;

      { Tableau ? }
      IsArray   := False;
      ArraySize := 0;
      If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '[') Then
      Begin
        IsArray := True;
        Inc(I);
        If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
        Begin
          ArraySize := TokenPool[I].IntVal;
          Inc(I);
        End
        Else
          ArraySize := 1;
        While (I < TokenCount) And
              Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ']')) Do
          Inc(I);
        If I < TokenCount Then Inc(I);
      End;

      { Initialiseur ? }
      InitVal := 0;
      HasInit := False;
      If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
         (TokenPool[I].Val = '=') Then
      Begin
        HasInit := True;
        Inc(I);
        If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
        Begin
          InitVal := TokenPool[I].IntVal;
          Inc(I);
        End
        Else If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
                (TokenPool[I].Val = '-') Then
        Begin
          Inc(I);
          If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
          Begin
            InitVal := -TokenPool[I].IntVal;
            Inc(I);
          End;
        End
        Else
        Begin
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     ((TokenPool[I].Val = ';') Or (TokenPool[I].Val = ','))) Do
            Inc(I);
        End;
      End;

      { Ajouter cette variable aussi }
      If IsArray Then
      Begin
        TypeSize := TypeSizeofIdx(TypeIdx);
        If IsPointer Then TypeSize := 4;
        Lbl := CC_VAR_PFX + VarName;
        DataAddArray(Lbl, ArraySize, TypeSize);
      End
      Else If IsPointer Then
      Begin
        Lbl := CC_VAR_PFX + VarName;
        DataAddDWord(Lbl, InitVal);
      End
      Else
      Begin
        Lbl := CC_VAR_PFX + VarName;
        DataAddGlobalVar(VarName, TypeIdx, InitVal);
      End;

      SymIdx := SymFind(VarName);
      If SymIdx < 0 Then
      Begin
        If IsStatic Then
          SymIdx := SymAdd(VarName, SC_STATIC, TypeIdx)
        Else
          SymIdx := SymAdd(VarName, SC_GLOBAL, TypeIdx);
        If SymIdx >= 0 Then
        Begin
          SymTab[SymIdx].MangledName := Lbl;
          SymTab[SymIdx].IsGlobal := Not IsStatic;
          SymTab[SymIdx].IsStatic := IsStatic;
          If HasInit Then
            SymTab[SymIdx].ImmVal := InitVal;
        End;
      End;
    End;

    { --- Avancer au ';' --- }
    While (I < TokenCount) And
          Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';')) Do
      Inc(I);
    If I < TokenCount Then Inc(I);
  End;
End;

{ ============================================================ }
{ TODO 09 - VARIABLES ET DECLARATIONS                          }
{ ============================================================ }

Const
  MAX_FUNC  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LOCAL = {$IFDEF FPC}64{$ELSE}16{$ENDIF};

Type
  TLocalVar = Record
    Name      : TString;
    TypeIdx   : Integer;
    Offset    : Integer;     { offset base EBP (negatif pour locales) }
    Size      : Integer;
    IsStatic  : Boolean;
    StaticLbl : TString;
    InitVal   : LongInt;
    HasInit   : Boolean;
    IsPointer : Boolean;
    IsArray   : Boolean;
    ArraySize : Integer;
  End;

  TFuncInfo = Record
    Name       : TString;
    MangledName: TString;
    RetTypeIdx : Integer;
    ParamCount : Integer;
    ParamNames : Array[0..MAX_PARAMS - 1] Of TString;
    ParamTypes : Array[0..MAX_PARAMS - 1] Of Integer;
    ParamOfs   : Array[0..MAX_PARAMS - 1] Of Integer;
    LocalCount : Integer;
    Locals     : Array[0..MAX_LOCAL - 1] Of TLocalVar;
    LocalSize  : Integer;
    BodyStart  : Integer;
    BodyEnd    : Integer;
    IsStatic   : Boolean;
    IsForward  : Boolean;
    SymIdx     : Integer;
  End;

Var
  FuncTab   : Array[0..MAX_FUNC - 1] Of TFuncInfo;
  FuncCount : Integer;

{ ------------------------------------------------------------ }
{ ParseTypeFromTokens : parser un type C a partir du pool      }
{ Retourne l index dans TypeTab ou -1 si echec                 }
{ ------------------------------------------------------------ }

Function ParseTypeFromTokens(Var P : Integer) : Integer;
Var
  TName : TString;
  TIdx  : Integer;
Begin
  ParseTypeFromTokens := -1;
  If P >= TokenCount Then Exit;

  { Sauter les qualificateurs (const, volatile) }
  While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
        IsQualifier(TokenPool[P].Val) Do
    Inc(P);
  If P >= TokenCount Then Exit;

  { struct / union / enum }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     ((TokenPool[P].Val = 'struct') Or (TokenPool[P].Val = 'union') Or
      (TokenPool[P].Val = 'enum')) Then
  Begin
    TName := TokenPool[P].Val;
    Inc(P);
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      TName := TName + ' ' + TokenPool[P].Val;
      Inc(P);
    End;
    { Definition inline avec accolades ? (TODO 19) }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '{') Then
    Begin
      If (TName <> 'enum') And (Copy(TName, 1, 5) <> 'enum ') Then
      Begin
        TIdx := ParseStructDef(P, TName,
          (TName = 'union') Or (Copy(TName, 1, 6) = 'union '));
        ParseTypeFromTokens := TIdx;
        Exit;
      End
      Else
      Begin
        { Enum : parser la definition avec ParseEnumDef (TODO 20) }
        TIdx := ParseEnumDef(P, TName);
        If TIdx < 0 Then
        Begin
          TIdx := TypeFindByName(TName);
          If TIdx < 0 Then TIdx := TypeFindByName('int');
        End;
        ParseTypeFromTokens := TIdx;
        Exit;
      End;
    End;
    TIdx := TypeFindByName(TName);
    If TIdx < 0 Then
      TIdx := TypeFindByName('int');
    ParseTypeFromTokens := TIdx;
    Exit;
  End;

  { Type de base (int, char, short, long, void, float, double, signed, unsigned) }
  If (TokenPool[P].Kind = TK_KEYWORD) And IsTypeSpecifier(TokenPool[P].Val) Then
  Begin
    TName := TokenPool[P].Val;
    Inc(P);
    { Combinaisons : unsigned int, long int, unsigned long int, etc. }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       IsTypeSpecifier(TokenPool[P].Val) Then
    Begin
      TName := TName + ' ' + TokenPool[P].Val;
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
         IsTypeSpecifier(TokenPool[P].Val) Then
      Begin
        TName := TName + ' ' + TokenPool[P].Val;
        Inc(P);
      End;
    End;
    TIdx := TypeFindByName(TName);
    If TIdx < 0 Then
      TIdx := TypeFindByName('int');
    ParseTypeFromTokens := TIdx;
    Exit;
  End;

  { Typedef : identifiant qui correspond a un type connu }
  If TokenPool[P].Kind = TK_IDENT Then
  Begin
    TIdx := TypeFindByName(TokenPool[P].Val);
    If TIdx >= 0 Then
    Begin
      Inc(P);
      ParseTypeFromTokens := TIdx;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ SkipToMatchingBrace : trouver accolade fermante              }
{ Retourne l index de l accolade fermante ou TokenCount        }
{ ------------------------------------------------------------ }

Function SkipToMatchingBrace(StartIdx : Integer) : Integer;
Var
  D, J : Integer;
Begin
  D := 1;
  J := StartIdx + 1;
  While (J < TokenCount) And (D > 0) Do
  Begin
    If (TokenPool[J].Kind = TK_PUNCT) And (TokenPool[J].Val = '{') Then
      Inc(D)
    Else If (TokenPool[J].Kind = TK_PUNCT) And (TokenPool[J].Val = '}') Then
      Dec(D);
    If D > 0 Then Inc(J);
  End;
  SkipToMatchingBrace := J;
End;

{ ============================================================ }
{ TODO 19 - STRUCTURES ET UNIONS                               }
{ ParseStructDef, StructFieldFind, VarTypeIdx                  }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseStructDef : parser la definition d une struct ou union   }
{ P pointe sur le accolade d ouverture. Avance P apres.       }
{ TypeName est le nom du type (ex: struct Point).              }
{ IsUnion = True pour union (tous les champs a offset 0).      }
{ Retourne l index dans TypeTab ou -1 en cas d erreur.         }
{ ------------------------------------------------------------ }

Function ParseStructDef(Var P : Integer;
                        Const TypeName : TString;
                        IsUnion : Boolean) : Integer;
Var
  TIdx     : Integer;
  FIdx     : Integer;
  FTIdx    : Integer;
  FName    : TString;
  FIsPtr   : Boolean;
  FIsArr   : Boolean;
  FArrSz   : Integer;
  FSz      : Integer;
  CurOfs   : Integer;
  MaxSz    : Integer;
  TotalSz  : Integer;
  Depth    : Integer;
  Kind     : TTypeKind;
Begin
  ParseStructDef := -1;
  If (P >= TokenCount) Or
     Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '{')) Then
    Exit;

  { Determiner la categorie }
  If IsUnion Then Kind := TKP_UNION
  Else Kind := TKP_STRUCT;

  { Verifier si le type existe deja }
  TIdx := TypeFindByName(TypeName);
  If TIdx < 0 Then
  Begin
    { Creer le type avec taille 0, on la calculera apres }
    TIdx := TypeAdd(Kind, TypeName, 0, 4, False, -1);
    If TIdx < 0 Then Exit;
  End
  Else
  Begin
    { Mettre a jour le kind }
    TypeTab[TIdx].Kind := Kind;
    TypeTab[TIdx].FieldCount := 0;
  End;

  Inc(P); { sauter le '{' }

  CurOfs := 0;
  MaxSz  := 0;
  FIdx   := 0;

  { Parser les champs : type [*] nom [[ taille ]]; }
  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '}')) Do
  Begin
    If FIdx >= MAX_FIELDS Then
    Begin
      WarnMsg('trop de champs dans ' + TypeName);
      Break;
    End;

    { Sauter les qualificateurs }
    While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
          IsQualifier(TokenPool[P].Val) Do
      Inc(P);

    { Parser le type du champ }
    FTIdx := ParseTypeFromTokens(P);
    If FTIdx < 0 Then
    Begin
      (* Pas un type : avancer au ; ou accolade fermante *)
      While (P < TokenCount) And
            Not ((TokenPool[P].Kind = TK_PUNCT) And
                 ((TokenPool[P].Val = ';') Or (TokenPool[P].Val = '}'))) Do
        Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = ';') Then Inc(P);
      Continue;
    End;

    { Sauter les qualificateurs apres le type }
    While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
          IsQualifier(TokenPool[P].Val) Do
      Inc(P);

    { Boucle pour declaration multiples (int x, y;) }
    Repeat
      FIsPtr := False;
      FIsArr := False;
      FArrSz := 0;

      { Pointeur ? }
      While (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
            (TokenPool[P].Val = '*') Do
      Begin
        FIsPtr := True;
        Inc(P);
      End;

      { Nom du champ }
      If (P >= TokenCount) Or (TokenPool[P].Kind <> TK_IDENT) Then Break;
      FName := TokenPool[P].Val;
      Inc(P);

      { Tableau ? champ[taille] }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = '[') Then
      Begin
        FIsArr := True;
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
        Begin
          FArrSz := TokenPool[P].IntVal;
          Inc(P);
        End
        Else
          FArrSz := 1;
        While (P < TokenCount) And
              Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ']')) Do
          Inc(P);
        If P < TokenCount Then Inc(P);
      End;

      { Calculer la taille du champ }
      If FIsPtr Then
        FSz := 4
      Else If FIsArr Then
        FSz := TypeSizeofIdx(FTIdx) * FArrSz
      Else
        FSz := TypeSizeofIdx(FTIdx);
      If FSz < 1 Then FSz := 4;

      { Enregistrer le champ }
      TypeTab[TIdx].Fields[FIdx].Name    := FName;
      TypeTab[TIdx].Fields[FIdx].TypeIdx := FTIdx;

      If IsUnion Then
        TypeTab[TIdx].Fields[FIdx].Offset := 0
      Else
        TypeTab[TIdx].Fields[FIdx].Offset := CurOfs;

      Inc(FIdx);

      { Avancer l offset pour struct }
      If Not IsUnion Then
      Begin
        CurOfs := CurOfs + FSz;
        { Aligner a 4 octets }
        CurOfs := ((CurOfs + 3) Div 4) * 4;
      End;

      { Suivi du max pour union }
      If FSz > MaxSz Then MaxSz := FSz;

      { Virgule -> champ suivant du meme type }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ',') Then
      Begin
        Inc(P);
        Continue;
      End;

      Break;
    Until False;

    { Avancer au ';' }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And
               ((TokenPool[P].Val = ';') Or (TokenPool[P].Val = '}'))) Do
      Inc(P);
    If (P < TokenCount) And (TokenPool[P].Val = ';') Then Inc(P);
  End;

  (* Sauter le accolade fermante *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '}') Then
    Inc(P);

  { Calculer la taille totale }
  If IsUnion Then
    TotalSz := MaxSz
  Else
    TotalSz := CurOfs;
  { Aligner a 4 octets minimum }
  If TotalSz < 4 Then TotalSz := 4;
  TotalSz := ((TotalSz + 3) Div 4) * 4;

  TypeTab[TIdx].FieldCount := FIdx;
  TypeTab[TIdx].Size       := TotalSz;
  TypeTab[TIdx].Align      := 4;

  ParseStructDef := TIdx;
End;

{ ------------------------------------------------------------ }
{ StructFieldFind : chercher un champ par nom dans un type      }
{ struct/union. Retourne l index dans Fields[] ou -1.          }
{ ------------------------------------------------------------ }

Function StructFieldFind(TIdx : Integer; Const FName : TString) : Integer;
Var K : Integer;
Begin
  StructFieldFind := -1;
  If (TIdx < 0) Or (TIdx >= TypeCount) Then Exit;
  If Not (TypeTab[TIdx].Kind In [TKP_STRUCT, TKP_UNION]) Then Exit;
  For K := 0 To TypeTab[TIdx].FieldCount - 1 Do
    If TypeTab[TIdx].Fields[K].Name = FName Then
    Begin
      StructFieldFind := K;
      Exit;
    End;
End;

{ ============================================================ }
{ TODO 20 - ENUMERATIONS ET TYPEDEF                            }
{ ParseEnumDef                                                  }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseEnumDef : parser la definition d une enumeration         }
{ P pointe sur l accolade d ouverture '{'.                     }
{ TypeName est le nom du type (ex: 'enum color').              }
{ Enregistre chaque valeur comme SC_ENUM_VAL dans SymTab.      }
{ Retourne l index dans TypeTab ou -1 en cas d erreur.         }
{ ------------------------------------------------------------ }

Function ParseEnumDef(Var P : Integer;
                      Const TypeName : TString) : Integer;
Var
  TIdx     : Integer;
  CurVal   : LongInt;
  ValName  : TString;
  SI       : Integer;
  ECount   : Integer;
Begin
  ParseEnumDef := -1;
  If (P >= TokenCount) Or
     Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '{')) Then
    Exit;

  { Verifier si le type existe deja }
  TIdx := TypeFindByName(TypeName);
  If TIdx < 0 Then
  Begin
    { Creer le type enum : taille 4 octets (DWORD 32 bits) }
    TIdx := TypeAdd(TKP_ENUM, TypeName, 4, 4, False, -1);
    If TIdx < 0 Then Exit;
  End
  Else
  Begin
    TypeTab[TIdx].Kind := TKP_ENUM;
    TypeTab[TIdx].Size := 4;
  End;

  Inc(P); { sauter le '{' }

  CurVal := 0;
  ECount := 0;

  { Parser les valeurs : IDENT [= expr], IDENT [= expr], ... }
  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '}')) Do
  Begin
    { Sauter les virgules }
    If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Continue;
    End;

    { Attendre un identifiant }
    If TokenPool[P].Kind <> TK_IDENT Then
    Begin
      Inc(P);
      Continue;
    End;

    ValName := TokenPool[P].Val;
    Inc(P);

    { Valeur explicite ? IDENT = constante }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
       (TokenPool[P].Val = '=') Then
    Begin
      Inc(P); { sauter le '=' }
      { Evaluer l expression constante }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
      Begin
        CurVal := TokenPool[P].IntVal;
        Inc(P);
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_CHAR) Then
      Begin
        CurVal := TokenPool[P].IntVal;
        Inc(P);
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
              (TokenPool[P].Val = '-') Then
      Begin
        { Nombre negatif }
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
        Begin
          CurVal := -TokenPool[P].IntVal;
          Inc(P);
        End;
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        { Reference a une autre valeur enum ? }
        SI := SymFind(TokenPool[P].Val);
        If (SI >= 0) And (SymTab[SI].Cat = SC_ENUM_VAL) Then
          CurVal := SymTab[SI].ImmVal
        Else
          CurVal := 0;
        Inc(P);
      End;
    End;

    { Enregistrer la valeur dans SymTab }
    SI := SymAdd(ValName, SC_ENUM_VAL, TIdx);
    If SI >= 0 Then
      SymTab[SI].ImmVal := CurVal;

    Inc(ECount);
    Inc(CurVal); { auto-increment pour la prochaine valeur }
  End;

  (* Sauter le accolade fermante *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '}') Then
    Inc(P);

  TypeTab[TIdx].EnumCount := ECount;
  ParseEnumDef := TIdx;
End;

{ ------------------------------------------------------------ }

Procedure ParseFuncDecls;
Var
  I, J       : Integer;
  Depth      : Integer;
  FStatic    : Boolean;
  FExtern    : Boolean;
  RetTIdx    : Integer;
  FName      : TString;
  SaveI      : Integer;
  ParamOfs   : Integer;
  PCount     : Integer;
  PName      : TString;
  PTIdx      : Integer;
  BodyOpen   : Integer;
  BodyClose  : Integer;
  LSize      : Integer;
  LCount     : Integer;
  LStat      : Boolean;
  LTIdx      : Integer;
  LName      : TString;
  LInit      : LongInt;
  LHasInit   : Boolean;
  LIsPtr     : Boolean;
  LIsArr     : Boolean;
  LArrSz     : Integer;
  SymIdx     : Integer;
  FI         : Integer;
  SzAlign    : Integer;
Begin
  HasMainFunc := False;
  FuncCount   := 0;
  Depth       := 0;
  I           := 0;

  While I < TokenCount Do
  Begin
    { Suivre la profondeur des accolades }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '{') Then
    Begin
      Inc(Depth); Inc(I); Continue;
    End;
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '}') Then
    Begin
      If Depth > 0 Then Dec(Depth);
      Inc(I); Continue;
    End;
    If Depth > 0 Then Begin Inc(I); Continue; End;

    { Sauvegarder la position pour reculer si ce n est pas une fonction }
    SaveI := I;

    { --- Collecter les classes de stockage --- }
    FStatic := False;
    FExtern := False;
    While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
          IsStorageClass(TokenPool[I].Val) Do
    Begin
      If TokenPool[I].Val = 'static' Then FStatic := True
      Else If TokenPool[I].Val = 'extern' Then FExtern := True;
      Inc(I);
    End;
    If I >= TokenCount Then Break;

    { --- Parser le type de retour --- }
    RetTIdx := ParseTypeFromTokens(I);
    If RetTIdx < 0 Then
    Begin
      I := SaveI; Inc(I); Continue;
    End;

    { Sauter les qualificateurs apres le type }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
          IsQualifier(TokenPool[I].Val) Do
      Inc(I);
    If I >= TokenCount Then Break;

    { Sauter les pointeurs (*) sur le type de retour }
    While (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
          (TokenPool[I].Val = '*') Do
      Inc(I);
    If I >= TokenCount Then Break;

    { --- Identifiant de la fonction --- }
    If TokenPool[I].Kind <> TK_IDENT Then
    Begin
      I := SaveI; Inc(I); Continue;
    End;
    FName := TokenPool[I].Val;
    Inc(I);
    If I >= TokenCount Then Break;

    { --- Doit etre suivi de '(' --- }
    If Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '(')) Then
    Begin
      I := SaveI; Inc(I); Continue;
    End;
    Inc(I); { passer le '(' }

    { --- Parser la liste de parametres --- }
    PCount   := 0;
    ParamOfs := 8; { cdecl : premier parametre a EBP+8 }

    If FuncCount >= MAX_FUNC Then
    Begin
      WarnMsg('table des fonctions pleine');
      Break;
    End;
    FI := FuncCount;

    { Verifier (void) ou () }
    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
       (TokenPool[I].Val = ')') Then
    Begin
      Inc(I); { liste vide }
    End
    Else If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
            (TokenPool[I].Val = 'void') And
            (I + 1 < TokenCount) And (TokenPool[I + 1].Kind = TK_PUNCT) And
            (TokenPool[I + 1].Val = ')') Then
    Begin
      Inc(I, 2); { (void) }
    End
    Else
    Begin
      { Parser les parametres type [*] nom, ... }
      While (I < TokenCount) And (PCount < MAX_PARAMS) Do
      Begin
        { Sauter les qualificateurs }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[I].Val) Do
          Inc(I);

        PTIdx := ParseTypeFromTokens(I);
        If PTIdx < 0 Then PTIdx := TypeFindByName('int');

        { Sauter les qualificateurs apres le type }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[I].Val) Do
          Inc(I);

        { Sauter les pointeurs }
        While (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
              (TokenPool[I].Val = '*') Do
          Inc(I);

        { Nom du parametre (optionnel dans les prototypes) }
        PName := '';
        If (I < TokenCount) And (TokenPool[I].Kind = TK_IDENT) Then
        Begin
          PName := TokenPool[I].Val;
          Inc(I);
        End;

        { Sauter les array declarators [] dans les parametres }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = '[') Then
        Begin
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ']')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End;

        FuncTab[FI].ParamNames[PCount] := PName;
        FuncTab[FI].ParamTypes[PCount] := PTIdx;
        FuncTab[FI].ParamOfs[PCount]   := ParamOfs;
        Inc(ParamOfs, 4); { tous les params sont alignes a 4 octets }
        Inc(PCount);

        { Virgule ou ')' }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = ',') Then
        Begin
          Inc(I); Continue;
        End;

        { Gerer ... (varargs) }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = '.') Then
        Begin
          While (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                (TokenPool[I].Val = '.') Do
            Inc(I);
          Continue;
        End;

        Break;
      End;

      { Avancer au ')' }
      While (I < TokenCount) And
            Not ((TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ')')) Do
        Inc(I);
      If I < TokenCount Then Inc(I);
    End;

    { --- Prototype ou definition ? --- }
    If I >= TokenCount Then Break;

    FuncTab[FI].Name       := FName;
    FuncTab[FI].MangledName:= CC_FUNC_PFX + FName;
    FuncTab[FI].RetTypeIdx := RetTIdx;
    FuncTab[FI].ParamCount := PCount;
    FuncTab[FI].IsStatic   := FStatic;
    FuncTab[FI].LocalCount := 0;
    FuncTab[FI].LocalSize  := 0;
    FuncTab[FI].BodyStart  := 0;
    FuncTab[FI].BodyEnd    := 0;
    FuncTab[FI].IsForward  := True;
    FuncTab[FI].SymIdx     := -1;

    { Prototype (;) }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = ';') Then
    Begin
      FuncTab[FI].IsForward := True;

      { Enregistrer dans SymTab }
      SymIdx := SymFind(FName);
      If SymIdx < 0 Then
      Begin
        If FExtern Then
          SymIdx := SymAdd(FName, SC_EXTERNAL, RetTIdx)
        Else
          SymIdx := SymAdd(FName, SC_FUNC, RetTIdx);
      End;
      If SymIdx >= 0 Then
      Begin
        FuncTab[FI].SymIdx := SymIdx;
        SymTab[SymIdx].ParamCount := PCount;
        SymTab[SymIdx].MangledName := CC_FUNC_PFX + FName;
        If FExtern Then
        Begin
          SymTab[SymIdx].IsExternal := True;
          SymTab[SymIdx].MangledName := '_' + FName;
        End;
      End;

      Inc(FuncCount);
      Inc(I);
      If FName = 'main' Then HasMainFunc := True;
      Continue;
    End;

    { Definition (corps de la fonction) }
    If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '{') Then
    Begin
      BodyOpen  := I;
      BodyClose := SkipToMatchingBrace(I);

      FuncTab[FI].IsForward := False;
      FuncTab[FI].BodyStart := BodyOpen;
      FuncTab[FI].BodyEnd   := BodyClose;

      { Scanner le corps pour les declarations de variables locales }
      LSize  := 0;
      LCount := 0;
      J := BodyOpen + 1;

      While (J < BodyClose) And (LCount < MAX_LOCAL) Do
      Begin
        { Sauter les tokens non-declaration }
        { Une declaration locale commence par un storage-class, qualificateur,  }
        { type-specifier ou typedef-name en debut d instruction                 }

        { Detecter le debut d une declaration potentielle }
        LStat    := False;
        LIsPtr   := False;
        LIsArr   := False;
        LArrSz   := 0;
        LHasInit := False;
        LInit    := 0;

        { Sauter les classes de stockage }
        If (J < BodyClose) And (TokenPool[J].Kind = TK_KEYWORD) And
           IsStorageClass(TokenPool[J].Val) Then
        Begin
          If TokenPool[J].Val = 'static' Then LStat := True
          Else If TokenPool[J].Val = 'typedef' Then
          Begin
            { Sauter le typedef }
            While (J < BodyClose) And
                  Not ((TokenPool[J].Kind = TK_PUNCT) And
                       (TokenPool[J].Val = ';')) Do
              Inc(J);
            If J < BodyClose Then Inc(J);
            Continue;
          End;
          Inc(J);
          If J >= BodyClose Then Break;
        End;

        { Sauter les qualificateurs }
        While (J < BodyClose) And (TokenPool[J].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[J].Val) Do
          Inc(J);
        If J >= BodyClose Then Break;

        { Verifier si c est un type }
        If Not (((TokenPool[J].Kind = TK_KEYWORD) And
                 IsTypeSpecifier(TokenPool[J].Val)) Or
                ((TokenPool[J].Kind = TK_IDENT) And
                 (TypeFindByName(TokenPool[J].Val) >= 0))) Then
        Begin
          (* Pas une declaration : avancer au prochain ponctuation *)
          While (J < BodyClose) And
                Not ((TokenPool[J].Kind = TK_PUNCT) And
                     ((TokenPool[J].Val = ';') Or (TokenPool[J].Val = '{') Or
                      (TokenPool[J].Val = '}'))) Do
            Inc(J);
          If (J < BodyClose) And (TokenPool[J].Val = '{') Then
          Begin
            { Bloc imbrique : sauter }
            J := SkipToMatchingBrace(J);
            If J < BodyClose Then Inc(J);
          End
          Else If J < BodyClose Then
            Inc(J);
          Continue;
        End;

        { Parser le type }
        LTIdx := ParseTypeFromTokens(J);
        If LTIdx < 0 Then
        Begin
          { Pas un type valide, avancer }
          While (J < BodyClose) And
                Not ((TokenPool[J].Kind = TK_PUNCT) And
                     (TokenPool[J].Val = ';')) Do
            Inc(J);
          If J < BodyClose Then Inc(J);
          Continue;
        End;

        { Sauter les qualificateurs apres le type }
        While (J < BodyClose) And (TokenPool[J].Kind = TK_KEYWORD) And
              IsQualifier(TokenPool[J].Val) Do
          Inc(J);
        If J >= BodyClose Then Break;

        { Sauter les pointeurs }
        LIsPtr := False;
        While (J < BodyClose) And (TokenPool[J].Kind = TK_OP) And
              (TokenPool[J].Val = '*') Do
        Begin
          LIsPtr := True;
          Inc(J);
        End;
        If J >= BodyClose Then Break;

        { Identifiant }
        If TokenPool[J].Kind <> TK_IDENT Then
        Begin
          While (J < BodyClose) And
                Not ((TokenPool[J].Kind = TK_PUNCT) And
                     (TokenPool[J].Val = ';')) Do
            Inc(J);
          If J < BodyClose Then Inc(J);
          Continue;
        End;

        { Verifier que ce n est pas un appel de fonction (ident suivi de '(') }
        If (J + 1 < BodyClose) And (TokenPool[J + 1].Kind = TK_PUNCT) And
           (TokenPool[J + 1].Val = '(') Then
        Begin
          { C est un appel ou definition de sous-fonction, pas une decl locale }
          While (J < BodyClose) And
                Not ((TokenPool[J].Kind = TK_PUNCT) And
                     (TokenPool[J].Val = ';')) Do
            Inc(J);
          If J < BodyClose Then Inc(J);
          Continue;
        End;

        { --- Boucle pour declarations multiples (int a, b, c;) --- }
        Repeat
          LIsArr   := False;
          LArrSz   := 0;
          LHasInit := False;
          LInit    := 0;

          If (J >= BodyClose) Or (TokenPool[J].Kind <> TK_IDENT) Then Break;
          LName := TokenPool[J].Val;
          Inc(J);

          { Tableau ? }
          If (J < BodyClose) And (TokenPool[J].Kind = TK_PUNCT) And
             (TokenPool[J].Val = '[') Then
          Begin
            LIsArr := True;
            Inc(J);
            If (J < BodyClose) And (TokenPool[J].Kind = TK_INTEGER) Then
            Begin
              LArrSz := TokenPool[J].IntVal;
              Inc(J);
            End
            Else
              LArrSz := 1;
            While (J < BodyClose) And
                  Not ((TokenPool[J].Kind = TK_PUNCT) And
                       (TokenPool[J].Val = ']')) Do
              Inc(J);
            If J < BodyClose Then Inc(J);
          End;

          { Initialiseur ? }
          If (J < BodyClose) And (TokenPool[J].Kind = TK_OP) And
             (TokenPool[J].Val = '=') Then
          Begin
            LHasInit := True;
            Inc(J);
            If (J < BodyClose) And (TokenPool[J].Kind = TK_INTEGER) Then
            Begin
              LInit := TokenPool[J].IntVal;
              Inc(J);
            End
            Else If (J < BodyClose) And (TokenPool[J].Kind = TK_OP) And
                    (TokenPool[J].Val = '-') Then
            Begin
              Inc(J);
              If (J < BodyClose) And (TokenPool[J].Kind = TK_INTEGER) Then
              Begin
                LInit := -TokenPool[J].IntVal;
                Inc(J);
              End;
            End
            Else If (J < BodyClose) And (TokenPool[J].Kind = TK_CHAR) Then
            Begin
              LInit := TokenPool[J].IntVal;
              Inc(J);
            End
            Else
            Begin
              { Initialiseur complexe : avancer au ',' ou ';' }
              While (J < BodyClose) And
                    Not ((TokenPool[J].Kind = TK_PUNCT) And
                         ((TokenPool[J].Val = ';') Or
                          (TokenPool[J].Val = ','))) Do
                Inc(J);
            End;
          End;

          { Calculer la taille et l offset }
          If LCount < MAX_LOCAL Then
          Begin
            If LIsArr Then
            Begin
              If LIsPtr Then
                SzAlign := 4 * LArrSz
              Else
                SzAlign := TypeSizeofIdx(LTIdx) * LArrSz;
            End
            Else If LIsPtr Then
              SzAlign := 4
            Else
              SzAlign := TypeSizeofIdx(LTIdx);
            { Aligner a 4 octets minimum }
            If SzAlign < 4 Then SzAlign := 4;
            SzAlign := ((SzAlign + 3) Div 4) * 4;

            FuncTab[FI].Locals[LCount].Name      := LName;
            FuncTab[FI].Locals[LCount].TypeIdx    := LTIdx;
            FuncTab[FI].Locals[LCount].IsPointer  := LIsPtr;
            FuncTab[FI].Locals[LCount].IsArray    := LIsArr;
            FuncTab[FI].Locals[LCount].ArraySize  := LArrSz;
            FuncTab[FI].Locals[LCount].HasInit    := LHasInit;
            FuncTab[FI].Locals[LCount].InitVal    := LInit;
            FuncTab[FI].Locals[LCount].IsStatic   := LStat;

            If LStat Then
            Begin
              { Variable statique : allouee dans .DATA }
              FuncTab[FI].Locals[LCount].StaticLbl :=
                DataAddStaticVar(FName + '_' + LName, LTIdx, LInit);
              FuncTab[FI].Locals[LCount].Offset := 0;
              FuncTab[FI].Locals[LCount].Size   := SzAlign;
            End
            Else
            Begin
              LSize := LSize + SzAlign;
              FuncTab[FI].Locals[LCount].Offset := -LSize;
              FuncTab[FI].Locals[LCount].Size   := SzAlign;
              FuncTab[FI].Locals[LCount].StaticLbl := '';
            End;

            Inc(LCount);
          End;

          { Virgule -> declarateur suivant }
          If (J < BodyClose) And (TokenPool[J].Kind = TK_PUNCT) And
             (TokenPool[J].Val = ',') Then
          Begin
            Inc(J);
            { Sauter pointeurs pour le declarateur suivant }
            LIsPtr := False;
            While (J < BodyClose) And (TokenPool[J].Kind = TK_OP) And
                  (TokenPool[J].Val = '*') Do
            Begin
              LIsPtr := True;
              Inc(J);
            End;
            Continue;
          End;

          Break;
        Until False;

        { Avancer au ';' }
        While (J < BodyClose) And
              Not ((TokenPool[J].Kind = TK_PUNCT) And
                   (TokenPool[J].Val = ';')) Do
          Inc(J);
        If J < BodyClose Then Inc(J);
      End;

      FuncTab[FI].LocalCount := LCount;
      FuncTab[FI].LocalSize  := LSize;

      { Enregistrer dans SymTab }
      SymIdx := SymFind(FName);
      If SymIdx < 0 Then
        SymIdx := SymAdd(FName, SC_FUNC, RetTIdx);
      If SymIdx >= 0 Then
      Begin
        FuncTab[FI].SymIdx := SymIdx;
        SymTab[SymIdx].ParamCount  := PCount;
        SymTab[SymIdx].MangledName := CC_FUNC_PFX + FName;
        SymTab[SymIdx].Cat         := SC_FUNC;
        SymTab[SymIdx].IsStatic    := FStatic;
        SymTab[SymIdx].IsExternal  := False;
        SymTab[SymIdx].IsGlobal    := Not FStatic;
      End;

      Inc(FuncCount);
      If FName = 'main' Then HasMainFunc := True;

      { Sauter le corps dans le parcours principal }
      I := BodyClose + 1;
      Continue;
    End;

    { Ni ';' ni '{' : pas une fonction, avancer }
    Inc(I);
  End;
End;

{ ------------------------------------------------------------ }
{ GenVarRef : generer l operande MASM pour acceder a la valeur }
{ d une variable via son index dans SymTab                     }
{ ------------------------------------------------------------ }

Function GenVarRef(SIdx : Integer) : TString;
Var
  Sz   : Integer;
  Pfx  : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    GenVarRef := 'DWORD PTR [0]';
    Exit;
  End;

  Sz := TypeSizeofIdx(SymTab[SIdx].TypeIdx);
  If Sz <= 1 Then
    Pfx := 'BYTE PTR '
  Else If Sz <= 2 Then
    Pfx := 'WORD PTR '
  Else
    Pfx := 'DWORD PTR ';

  Case SymTab[SIdx].Cat Of
    SC_GLOBAL, SC_EXTERNAL, SC_STATIC:
      GenVarRef := Pfx + '[' + SymTab[SIdx].MangledName + ']';
    SC_VAR:
    Begin
      If SymTab[SIdx].IsGlobal Or (SymTab[SIdx].ScopeLevel = 0) Then
        GenVarRef := Pfx + '[' + SymTab[SIdx].MangledName + ']'
      Else If SymTab[SIdx].Offset < 0 Then
        GenVarRef := Pfx + '[EBP' + IntToStr_(SymTab[SIdx].Offset) + ']'
      Else
        GenVarRef := Pfx + '[EBP+' + IntToStr_(SymTab[SIdx].Offset) + ']';
    End;
    SC_PARAM:
      GenVarRef := Pfx + '[EBP+' + IntToStr_(SymTab[SIdx].Offset) + ']';
  Else
    GenVarRef := Pfx + '[' + SymTab[SIdx].MangledName + ']';
  End;
End;

{ ------------------------------------------------------------ }
{ GenVarAddr : generer l operande MASM pour l adresse d une    }
{ variable via son index dans SymTab                           }
{ ------------------------------------------------------------ }

Function GenVarAddr(SIdx : Integer) : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    GenVarAddr := 'OFFSET 0';
    Exit;
  End;

  Case SymTab[SIdx].Cat Of
    SC_GLOBAL, SC_EXTERNAL, SC_STATIC:
      GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName;
    SC_VAR:
    Begin
      If SymTab[SIdx].IsGlobal Or (SymTab[SIdx].ScopeLevel = 0) Then
        GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName
      Else If SymTab[SIdx].Offset < 0 Then
        GenVarAddr := 'EBP' + IntToStr_(SymTab[SIdx].Offset)
      Else
        GenVarAddr := 'EBP+' + IntToStr_(SymTab[SIdx].Offset);
    End;
    SC_PARAM:
      GenVarAddr := 'EBP+' + IntToStr_(SymTab[SIdx].Offset);
  Else
    GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName;
  End;
End;

{ ============================================================ }
{ TODO 10 - EXPRESSIONS PRIMAIRES                              }
{ ============================================================ }

Var
  EP              : Integer;  { Position curseur dans TokenPool pour expressions }
  CurFuncIdx      : Integer;  { Index de la fonction en cours de compilation     }
  EPEnd           : Integer;  { Borne fin pour le parsage d expressions          }
  LastPrimaryName : TString;  { Dernier ident charge par ParsePrimary (TODO 12)  }
  RetLbl          : TString;  { Label de retour de la fonction courante (TODO 13) }
  LoopBreakLbl    : Array[0..31] Of TString; { Pile labels break (TODO 14)  }
  LoopContLbl     : Array[0..31] Of TString; { Pile labels continue (TODO 14)}
  LoopTop         : Integer;  { Sommet de la pile de boucles (TODO 14)     }
  SwitchBreakLbl  : Array[0..31] Of TString; { Pile labels break switch (TODO 15) }
  SwitchTop       : Integer;  { Sommet de la pile de switch (TODO 15)      }
  GotoLblDef      : Array[0..63] Of TString; { Labels goto definis (TODO 22) }
  GotoLblDefCount : Integer;  { Nombre de labels goto definis (TODO 22)    }
  GotoLblUse      : Array[0..63] Of TString; { Labels goto utilises (TODO 22) }
  GotoLblUseCount : Integer;  { Nombre de labels goto utilises (TODO 22)   }

{ ------------------------------------------------------------ }
{ EPAtEnd : verifier si le curseur est en fin de zone           }
{ ------------------------------------------------------------ }

Function EPAtEnd : Boolean;
Begin
  EPAtEnd := (EP >= EPEnd);
End;

{ ------------------------------------------------------------ }
{ EPMatch : verifier et consommer un token ponctuation/op      }
{ ------------------------------------------------------------ }

Function EPMatch(Const S : TString) : Boolean;
Begin
  EPMatch := False;
  If EP >= EPEnd Then Exit;
  If ((TokenPool[EP].Kind = TK_PUNCT) Or (TokenPool[EP].Kind = TK_OP)) And
     (TokenPool[EP].Val = S) Then
  Begin
    Inc(EP);
    EPMatch := True;
  End;
End;

{ ------------------------------------------------------------ }
{ FindLocal : chercher une variable locale par nom              }
{ Retourne l index dans Locals[] ou -1                         }
{ ------------------------------------------------------------ }

Function FindLocal(FI : Integer; Const Name : TString) : Integer;
Var K : Integer;
Begin
  FindLocal := -1;
  For K := 0 To FuncTab[FI].LocalCount - 1 Do
    If FuncTab[FI].Locals[K].Name = Name Then
    Begin
      FindLocal := K;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ FindParam : chercher un parametre par nom                     }
{ Retourne l index dans ParamNames[] ou -1                     }
{ ------------------------------------------------------------ }

Function FindParam(FI : Integer; Const Name : TString) : Integer;
Var K : Integer;
Begin
  FindParam := -1;
  For K := 0 To FuncTab[FI].ParamCount - 1 Do
    If FuncTab[FI].ParamNames[K] = Name Then
    Begin
      FindParam := K;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ VarIsPointer : verifier si une variable est un pointeur      }
{ (TODO 17). Cherche dans les locales, parametres et globales. }
{ ------------------------------------------------------------ }

Function VarIsPointer(Const Name : TString) : Boolean;
Var
  LI, PI, SI, TI : Integer;
Begin
  VarIsPointer := False;

  { Chercher dans les locales }
  LI := FindLocal(CurFuncIdx, Name);
  If LI >= 0 Then
  Begin
    VarIsPointer := FuncTab[CurFuncIdx].Locals[LI].IsPointer;
    Exit;
  End;

  { Chercher dans les parametres }
  PI := FindParam(CurFuncIdx, Name);
  If PI >= 0 Then
  Begin
    TI := FuncTab[CurFuncIdx].ParamTypes[PI];
    If (TI >= 0) And (TI < TypeCount) Then
      VarIsPointer := TypeTab[TI].Kind = TKP_POINTER;
    Exit;
  End;

  { Chercher dans les symboles globaux }
  SI := SymFind(Name);
  If SI >= 0 Then
  Begin
    TI := SymTab[SI].TypeIdx;
    If (TI >= 0) And (TI < TypeCount) Then
      VarIsPointer := TypeTab[TI].Kind = TKP_POINTER;
  End;
End;

{ ------------------------------------------------------------ }
{ VarTypeIdx : retourner le TypeIdx d une variable (TODO 19)    }
{ Cherche dans locales, parametres et globales.                 }
{ ------------------------------------------------------------ }

Function VarTypeIdx(Const Name : TString) : Integer;
Var
  LI, PI, SI : Integer;
Begin
  VarTypeIdx := -1;

  { Locales }
  LI := FindLocal(CurFuncIdx, Name);
  If LI >= 0 Then
  Begin
    VarTypeIdx := FuncTab[CurFuncIdx].Locals[LI].TypeIdx;
    Exit;
  End;

  { Parametres }
  PI := FindParam(CurFuncIdx, Name);
  If PI >= 0 Then
  Begin
    VarTypeIdx := FuncTab[CurFuncIdx].ParamTypes[PI];
    Exit;
  End;

  { Globales }
  SI := SymFind(Name);
  If SI >= 0 Then
    VarTypeIdx := SymTab[SI].TypeIdx;
End;

{ ------------------------------------------------------------ }
{ VarIsStruct : verifier si une variable est struct/union       }
{ (TODO 19)                                                     }
{ ------------------------------------------------------------ }

Function VarIsStruct(Const Name : TString) : Boolean;
Var TI : Integer;
Begin
  VarIsStruct := False;
  TI := VarTypeIdx(Name);
  If (TI >= 0) And (TI < TypeCount) Then
    VarIsStruct := TypeTab[TI].Kind In [TKP_STRUCT, TKP_UNION];
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : emettre le code pour charger une variable dans   }
{ EAX (globale, locale, parametre)                             }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(Const Name : TString);
Var
  LI, PI, SI, TI : Integer;
Begin
  { Chercher dans les locales de la fonction courante }
  LI := FindLocal(CurFuncIdx, Name);
  If LI >= 0 Then
  Begin
    If FuncTab[CurFuncIdx].Locals[LI].IsStatic Then
      EmitInstr('MOV EAX,DWORD PTR [' +
        FuncTab[CurFuncIdx].Locals[LI].StaticLbl + ']')
    Else If FuncTab[CurFuncIdx].Locals[LI].IsArray Then
      EmitInstr('LEA EAX,[EBP' +
        IntToStr_(FuncTab[CurFuncIdx].Locals[LI].Offset) + ']')
    Else
    Begin
      { TODO 19 : si le type est struct/union, charger l adresse (LEA) }
      TI := FuncTab[CurFuncIdx].Locals[LI].TypeIdx;
      If (TI >= 0) And (TI < TypeCount) And
         (TypeTab[TI].Kind In [TKP_STRUCT, TKP_UNION]) Then
        EmitInstr('LEA EAX,[EBP' +
          IntToStr_(FuncTab[CurFuncIdx].Locals[LI].Offset) + ']')
      Else
        EmitInstr('MOV EAX,DWORD PTR [EBP' +
          IntToStr_(FuncTab[CurFuncIdx].Locals[LI].Offset) + ']');
    End;
    Exit;
  End;

  { Chercher dans les parametres }
  PI := FindParam(CurFuncIdx, Name);
  If PI >= 0 Then
  Begin
    EmitInstr('MOV EAX,DWORD PTR [EBP+' +
      IntToStr_(FuncTab[CurFuncIdx].ParamOfs[PI]) + ']');
    Exit;
  End;

  { Chercher dans les symboles globaux }
  SI := SymFind(Name);
  If SI >= 0 Then
  Begin
    { TODO 20 : si c est une constante enum, charger la valeur immediate }
    If SymTab[SI].Cat = SC_ENUM_VAL Then
    Begin
      EmitInstr('MOV EAX,' + IntToStr_(SymTab[SI].ImmVal));
      Exit;
    End;
    { TODO 19 : si le type est struct/union, charger l adresse }
    TI := SymTab[SI].TypeIdx;
    If (TI >= 0) And (TI < TypeCount) And
       (TypeTab[TI].Kind In [TKP_STRUCT, TKP_UNION]) Then
      EmitInstr('MOV EAX,OFFSET ' + SymTab[SI].MangledName)
    Else
      EmitInstr('MOV EAX,' + GenVarRef(SI));
    Exit;
  End;

  { Variable non trouvee }
  EmitComment('WARNING: variable non trouvee: ' + Name);
  EmitInstr('XOR EAX,EAX');
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : emettre le code pour stocker EAX dans une var   }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(Const Name : TString);
Var
  LI, PI, SI : Integer;
Begin
  LI := FindLocal(CurFuncIdx, Name);
  If LI >= 0 Then
  Begin
    If FuncTab[CurFuncIdx].Locals[LI].IsStatic Then
      EmitInstr('MOV DWORD PTR [' +
        FuncTab[CurFuncIdx].Locals[LI].StaticLbl + '],EAX')
    Else
      EmitInstr('MOV DWORD PTR [EBP' +
        IntToStr_(FuncTab[CurFuncIdx].Locals[LI].Offset) + '],EAX');
    Exit;
  End;

  PI := FindParam(CurFuncIdx, Name);
  If PI >= 0 Then
  Begin
    EmitInstr('MOV DWORD PTR [EBP+' +
      IntToStr_(FuncTab[CurFuncIdx].ParamOfs[PI]) + '],EAX');
    Exit;
  End;

  SI := SymFind(Name);
  If SI >= 0 Then
  Begin
    EmitInstr('MOV DWORD PTR [' + SymTab[SI].MangledName + '],EAX');
    Exit;
  End;

  EmitComment('WARNING: variable non trouvee pour stockage: ' + Name);
End;

{ ------------------------------------------------------------ }
{ GenLoadAddr : emettre LEA EAX pour l adresse d une variable   }
{ ------------------------------------------------------------ }

Procedure GenLoadAddr(Const Name : TString);
Var
  LI, PI, SI : Integer;
Begin
  LI := FindLocal(CurFuncIdx, Name);
  If LI >= 0 Then
  Begin
    If FuncTab[CurFuncIdx].Locals[LI].IsStatic Then
      EmitInstr('MOV EAX,OFFSET ' +
        FuncTab[CurFuncIdx].Locals[LI].StaticLbl)
    Else
      EmitInstr('LEA EAX,[EBP' +
        IntToStr_(FuncTab[CurFuncIdx].Locals[LI].Offset) + ']');
    Exit;
  End;

  PI := FindParam(CurFuncIdx, Name);
  If PI >= 0 Then
  Begin
    EmitInstr('LEA EAX,[EBP+' +
      IntToStr_(FuncTab[CurFuncIdx].ParamOfs[PI]) + ']');
    Exit;
  End;

  SI := SymFind(Name);
  If SI >= 0 Then
  Begin
    EmitInstr('MOV EAX,OFFSET ' + SymTab[SI].MangledName);
    Exit;
  End;

  EmitComment('WARNING: variable non trouvee pour adresse: ' + Name);
  EmitInstr('XOR EAX,EAX');
End;

{ ------------------------------------------------------------ }
{ Declarations Forward pour les expressions                    }
{ ------------------------------------------------------------ }

Procedure ParseExpr; Forward;
Procedure ParseExprPrec(MinPrec : Integer); Forward;
Procedure ParseUnary; Forward;

{ ------------------------------------------------------------ }
{ IsFuncName : verifier si un nom est celui d une fonction      }
{ connue dans FuncTab (TODO 17 : distinguer fonctions et       }
{ pointeurs de fonction).                                      }
{ ------------------------------------------------------------ }

Function IsFuncName(Const Name : TString) : Boolean;
Var K : Integer;
Begin
  IsFuncName := False;
  For K := 0 To FuncCount - 1 Do
    If FuncTab[K].Name = Name Then
    Begin
      IsFuncName := True;
      Exit;
    End;
  { Verifier aussi dans SymTab pour les fonctions externes }
  K := SymFind(Name);
  If (K >= 0) And (SymTab[K].Cat = SC_FUNC) Then
    IsFuncName := True;
End;

{ ------------------------------------------------------------ }
{ ParseFuncPtrCall : parser un appel indirect via pointeur de   }
{ fonction. Charge le pointeur, parse les arguments, et emet   }
{ CALL EAX (TODO 17).                                          }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParseFuncPtrCall(Const PtrName : TString);
Var
  ArgCount    : Integer;
  ArgStart    : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos   : Array[0..MAX_PARAMS - 1] Of Integer;
  Depth       : Integer;
  SaveEP      : Integer;
  SaveEnd     : Integer;
  K           : Integer;
Begin
  { Scanner les arguments pour trouver leurs bornes }
  ArgCount := 0;
  If Not EPAtEnd And Not ((TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')')) Then
  Begin
    ArgStart[0] := EP;
    Depth := 0;
    While Not EPAtEnd Do
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
        Inc(Depth)
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ')') Then
      Begin
        If Depth = 0 Then
        Begin
          ArgEndPos[ArgCount] := EP - 1;
          Inc(ArgCount);
          Break;
        End;
        Dec(Depth);
      End
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ',') And (Depth = 0) Then
      Begin
        ArgEndPos[ArgCount] := EP - 1;
        Inc(ArgCount);
        If ArgCount < MAX_PARAMS Then
          ArgStart[ArgCount] := EP + 1;
      End;
      Inc(EP);
    End;
  End;

  { Consommer le ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  { Evaluer et pousser les arguments de droite a gauche (cdecl) }
  SaveEP  := EP;
  SaveEnd := EPEnd;
  For K := ArgCount - 1 DownTo 0 Do
  Begin
    EP    := ArgStart[K];
    EPEnd := ArgEndPos[K] + 1;
    ParseExpr;
    EmitInstr('PUSH EAX');
  End;
  EP    := SaveEP;
  EPEnd := SaveEnd;

  { Charger le pointeur de fonction et appeler indirectement }
  GenLoadVar(PtrName);
  EmitInstr('CALL EAX');

  { Nettoyer la pile (convention cdecl) }
  If ArgCount > 0 Then
    EmitInstr('ADD ESP,' + IntToStr_(ArgCount * 4));
End;

{ ------------------------------------------------------------ }
{ ParseFuncCall : parser un appel de fonction f(args)           }
{ Le '(' a deja ete consomme. Convention cdecl : arguments     }
{ pousses droite a gauche, appelant nettoie la pile.           }
{ Resultat dans EAX.                                           }
{ ------------------------------------------------------------ }

Procedure ParseFuncCall(Const FuncName : TString);
Var
  ArgCount    : Integer;
  ArgStart    : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos   : Array[0..MAX_PARAMS - 1] Of Integer;
  Depth       : Integer;
  SaveEP      : Integer;
  SaveEnd     : Integer;
  K           : Integer;
  MangledName : TString;
  SymI        : Integer;
Begin
  { Scanner les arguments pour trouver leurs bornes }
  ArgCount := 0;
  If Not EPAtEnd And Not ((TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')')) Then
  Begin
    ArgStart[0] := EP;
    Depth := 0;
    While Not EPAtEnd Do
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
        Inc(Depth)
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ')') Then
      Begin
        If Depth = 0 Then
        Begin
          ArgEndPos[ArgCount] := EP - 1;
          Inc(ArgCount);
          Break;
        End;
        Dec(Depth);
      End
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ',') And (Depth = 0) Then
      Begin
        ArgEndPos[ArgCount] := EP - 1;
        Inc(ArgCount);
        If ArgCount < MAX_PARAMS Then
          ArgStart[ArgCount] := EP + 1;
      End;
      Inc(EP);
    End;
  End;

  { Consommer le ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  { Evaluer et pousser les arguments de droite a gauche (cdecl) }
  SaveEP  := EP;
  SaveEnd := EPEnd;
  For K := ArgCount - 1 DownTo 0 Do
  Begin
    EP    := ArgStart[K];
    EPEnd := ArgEndPos[K] + 1;
    ParseExpr;
    EmitInstr('PUSH EAX');
  End;
  EP    := SaveEP;
  EPEnd := SaveEnd;

  { Determiner le nom MASM de la fonction }
  SymI := SymFind(FuncName);
  If (SymI >= 0) And SymTab[SymI].IsExternal Then
    MangledName := '_' + FuncName
  Else
    MangledName := CC_FUNC_PFX + FuncName;

  EmitInstr('CALL ' + MangledName);

  { Nettoyer la pile (convention cdecl : appelant nettoie) }
  If ArgCount > 0 Then
    EmitInstr('ADD ESP,' + IntToStr_(ArgCount * 4));
End;

{ ============================================================ }
{ TODO 21 - CHAINES ET ENTREES/SORTIES (printf, scanf, etc.)   }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ CollectArgs : scanner les arguments d un appel de fonction    }
{ Le '(' a deja ete consomme. Consomme le ')' final.           }
{ ArgCount : nombre d arguments trouves (sortie)                }
{ ArgStart : indices debut de chaque argument dans TokenPool    }
{ ArgEndPos : indices fin de chaque argument dans TokenPool     }
{ ------------------------------------------------------------ }

Procedure CollectArgs(Var ArgCount : Integer;
                      Var ArgStart : Array Of Integer;
                      Var ArgEndPos : Array Of Integer);
Var
  Depth : Integer;
Begin
  ArgCount := 0;
  If Not EPAtEnd And Not ((TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')')) Then
  Begin
    ArgStart[0] := EP;
    Depth := 0;
    While Not EPAtEnd Do
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
        Inc(Depth)
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ')') Then
      Begin
        If Depth = 0 Then
        Begin
          ArgEndPos[ArgCount] := EP - 1;
          Inc(ArgCount);
          Break;
        End;
        Dec(Depth);
      End
      Else If (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ',') And (Depth = 0) Then
      Begin
        ArgEndPos[ArgCount] := EP - 1;
        Inc(ArgCount);
        If ArgCount < MAX_PARAMS Then
          ArgStart[ArgCount] := EP + 1;
      End;
      Inc(EP);
    End;
  End;
  { Consommer le ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ EvalArg : evaluer un argument dans ses bornes token           }
{ AStart, AEnd : indices debut/fin dans TokenPool               }
{ Sauvegarde/restaure EP/EPEnd. Resultat dans EAX.             }
{ ------------------------------------------------------------ }

Procedure EvalArg(AStart, AEnd : Integer);
Var
  SaveEP, SaveEnd : Integer;
Begin
  SaveEP  := EP;
  SaveEnd := EPEnd;
  EP    := AStart;
  EPEnd := AEnd + 1;
  ParseExpr;
  EP    := SaveEP;
  EPEnd := SaveEnd;
End;

{ ------------------------------------------------------------ }
{ ParsePrintfCall : gerer printf(fmt, ...)                     }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParsePrintfCall;
Var
  ArgCount  : Integer;
  ArgStart  : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos : Array[0..MAX_PARAMS - 1] Of Integer;
  Fmt       : TString;
  Lbl       : TString;
  Buf       : TString;
  I, ArgIdx : Integer;
  C         : Char;
Begin
  EmitComment('printf (TODO 21)');
  CollectArgs(ArgCount, ArgStart, ArgEndPos);

  { Le premier argument doit etre une chaine litterale }
  If ArgCount < 1 Then
  Begin
    WriteLn('CCW32: avertissement: printf() sans arguments');
    Exit;
  End;
  Fmt := TokenPool[ArgStart[0]].Val;

  ArgIdx := 1; { index du prochain argument variadique }
  I := 1;
  Buf := '';
  While I <= Length(Fmt) Do
  Begin
    C := Fmt[I];

    { Newline : chr(10) deja converti par le lexer }
    If C = Chr(10) Then
    Begin
      { Emettre le tampon accumule }
      If Buf <> '' Then
      Begin
        Lbl := DataGetOrAddStr(Buf);
        EmitInstr('MOV ESI,OFFSET ' + Lbl);
        EmitInstr('CALL _CCRT_PRINTSTR');
        Buf := '';
      End;
      EmitInstr('CALL _CCRT_PRINTCRLF');
      Inc(I);
    End

    { Tabulation : chr(9) deja converti par le lexer }
    Else If C = Chr(9) Then
    Begin
      If Buf <> '' Then
      Begin
        Lbl := DataGetOrAddStr(Buf);
        EmitInstr('MOV ESI,OFFSET ' + Lbl);
        EmitInstr('CALL _CCRT_PRINTSTR');
        Buf := '';
      End;
      Lbl := DataGetOrAddStr(Chr(9));
      EmitInstr('MOV ESI,OFFSET ' + Lbl);
      EmitInstr('CALL _CCRT_PRINTSTR');
      Inc(I);
    End

    { Retour chariot : chr(13) ignorer }
    Else If C = Chr(13) Then
    Begin
      Inc(I);
    End

    { Specificateur de format }
    Else If (C = '%') And (I < Length(Fmt)) Then
    Begin
      { Emettre le tampon accumule }
      If Buf <> '' Then
      Begin
        Lbl := DataGetOrAddStr(Buf);
        EmitInstr('MOV ESI,OFFSET ' + Lbl);
        EmitInstr('CALL _CCRT_PRINTSTR');
        Buf := '';
      End;

      Inc(I);
      C := Fmt[I];
      Case C Of
        'd':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('CALL _CCRT_PRINTINT');
          Inc(I);
        End;
        'u':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('CALL _CCRT_PRINTUINT');
          Inc(I);
        End;
        'x':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('CALL _CCRT_PRINTHEX');
          Inc(I);
        End;
        'c':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('CALL _CCRT_PRINTCHAR');
          Inc(I);
        End;
        's':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('MOV ESI,EAX');
          EmitInstr('CALL _CCRT_PRINTSTR');
          Inc(I);
        End;
        '%':
        Begin
          Lbl := DataGetOrAddStr('%');
          EmitInstr('MOV ESI,OFFSET ' + Lbl);
          EmitInstr('CALL _CCRT_PRINTSTR');
          Inc(I);
        End;
      Else
        { Specificateur inconnu : ignorer }
        Inc(I);
      End;
    End

    { Caractere litteral ordinaire }
    Else
    Begin
      Buf := Buf + C;
      Inc(I);
    End;
  End;

  { Emettre le reste du tampon }
  If Buf <> '' Then
  Begin
    Lbl := DataGetOrAddStr(Buf);
    EmitInstr('MOV ESI,OFFSET ' + Lbl);
    EmitInstr('CALL _CCRT_PRINTSTR');
  End;

  { Valeur de retour = 0 }
  EmitInstr('XOR EAX,EAX');
End;

{ ------------------------------------------------------------ }
{ ParseScanfCall : gerer scanf(fmt, ...)                       }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParseScanfCall;
Var
  ArgCount  : Integer;
  ArgStart  : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos : Array[0..MAX_PARAMS - 1] Of Integer;
  Fmt       : TString;
  I, ArgIdx : Integer;
  C         : Char;
Begin
  EmitComment('scanf (TODO 21)');
  CollectArgs(ArgCount, ArgStart, ArgEndPos);

  If ArgCount < 1 Then
  Begin
    WriteLn('CCW32: avertissement: scanf() sans arguments');
    Exit;
  End;
  Fmt := TokenPool[ArgStart[0]].Val;

  ArgIdx := 1;
  I := 1;
  While I <= Length(Fmt) Do
  Begin
    C := Fmt[I];
    If (C = '%') And (I < Length(Fmt)) Then
    Begin
      Inc(I);
      C := Fmt[I];
      Case C Of
        'd':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('PUSH EAX');
          EmitInstr('CALL _CCRT_READINT');
          EmitInstr('POP EDI');
          EmitInstr('MOV [EDI],EAX');
          Inc(I);
        End;
        's':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('MOV EDI,EAX');
          EmitInstr('CALL _CCRT_READSTR');
          Inc(I);
        End;
        'c':
        Begin
          If ArgIdx < ArgCount Then
          Begin
            EvalArg(ArgStart[ArgIdx], ArgEndPos[ArgIdx]);
            Inc(ArgIdx);
          End;
          EmitInstr('PUSH EAX');
          EmitInstr('CALL _CCRT_READCHAR');
          EmitInstr('POP EDI');
          EmitInstr('MOV BYTE PTR [EDI],AL');
          Inc(I);
        End;
      Else
        Inc(I);
      End;
    End
    Else
      Inc(I);
  End;

  EmitInstr('XOR EAX,EAX');
End;

{ ------------------------------------------------------------ }
{ ParsePutsCall : gerer puts(s)                                }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParsePutsCall;
Var
  ArgCount  : Integer;
  ArgStart  : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos : Array[0..MAX_PARAMS - 1] Of Integer;
Begin
  EmitComment('puts (TODO 21)');
  CollectArgs(ArgCount, ArgStart, ArgEndPos);

  If ArgCount >= 1 Then
    EvalArg(ArgStart[0], ArgEndPos[0]);

  EmitInstr('MOV ESI,EAX');
  EmitInstr('CALL _CCRT_PRINTSTR');
  EmitInstr('CALL _CCRT_PRINTCRLF');
  EmitInstr('XOR EAX,EAX');
End;

{ ------------------------------------------------------------ }
{ ParsePutcharCall : gerer putchar(c)                          }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParsePutcharCall;
Var
  ArgCount  : Integer;
  ArgStart  : Array[0..MAX_PARAMS - 1] Of Integer;
  ArgEndPos : Array[0..MAX_PARAMS - 1] Of Integer;
Begin
  EmitComment('putchar (TODO 21)');
  CollectArgs(ArgCount, ArgStart, ArgEndPos);

  If ArgCount >= 1 Then
    EvalArg(ArgStart[0], ArgEndPos[0]);

  EmitInstr('CALL _CCRT_PRINTCHAR');
End;

{ ------------------------------------------------------------ }
{ ParseGetcharCall : gerer getchar()                           }
{ Le '(' a deja ete consomme.                                  }
{ ------------------------------------------------------------ }

Procedure ParseGetcharCall;
Begin
  EmitComment('getchar (TODO 21)');
  { Consommer le ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  EmitInstr('CALL _CCRT_READCHAR');
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire                 }
{ Litteral entier, chaine, char, ident, appel, parentheses,    }
{ sizeof, cast.                                                }
{ Resultat dans EAX.                                           }
{ ------------------------------------------------------------ }

Procedure ParsePrimary;
Var
  Name     : TString;
  DataLbl  : TString;
  TIdx     : Integer;
  SzVal    : Integer;
  SaveEP   : Integer;
  CastIdx  : Integer;   { TODO 23 : index du type cible pour cast }
  CastKind : TTypeKind; { TODO 23 : kind du type cible pour cast  }
  IsPtr    : Boolean;    { TODO 23 : True si cast vers pointeur    }
Begin
  LastPrimaryName := '';

  If EPAtEnd Then
  Begin
    EmitInstr('XOR EAX,EAX');
    Exit;
  End;

  Case TokenPool[EP].Kind Of
    { --- Litteral entier --- }
    TK_INTEGER:
    Begin
      EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
      Inc(EP);
    End;

    { --- Litteral caractere --- }
    TK_CHAR:
    Begin
      EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
      Inc(EP);
    End;

    { --- Litteral chaine -> adresse de la constante --- }
    TK_STRING:
    Begin
      DataLbl := DataGetOrAddStr(TokenPool[EP].Val);
      EmitInstr('MOV EAX,OFFSET ' + DataLbl);
      Inc(EP);
    End;

    { --- Identifiant ou appel de fonction / pointeur de fonction --- }
    TK_IDENT:
    Begin
      Name := TokenPool[EP].Val;
      Inc(EP);

      { Appel de fonction ou pointeur de fonction si suivi de '(' }
      If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '(') Then
      Begin
        Inc(EP); { consommer '(' }
        { TODO 21 : fonctions d E/S speciales }
        If Name = 'printf' Then
          ParsePrintfCall
        Else If Name = 'scanf' Then
          ParseScanfCall
        Else If Name = 'puts' Then
          ParsePutsCall
        Else If Name = 'putchar' Then
          ParsePutcharCall
        Else If Name = 'getchar' Then
          ParseGetcharCall
        Else If IsFuncName(Name) Then
          ParseFuncCall(Name)         { appel direct (TODO 16) }
        Else
          ParseFuncPtrCall(Name);     { appel indirect via pointeur (TODO 17) }
      End
      Else
      Begin
        { Acces variable : globale, locale ou parametre }
        GenLoadVar(Name);
        LastPrimaryName := Name; { TODO 12 : memoriser pour post-inc/dec }
      End;
    End;

    { --- Mot-cle (sizeof) --- }
    TK_KEYWORD:
    Begin
      If TokenPool[EP].Val = 'sizeof' Then
      Begin
        Inc(EP);
        SzVal := 4; { defaut : taille d un int }
        If EPMatch('(') Then
        Begin
          SaveEP := EP;
          TIdx := ParseTypeFromTokens(EP);
          If TIdx >= 0 Then
          Begin
            { sizeof(type) }
            While Not EPAtEnd And (TokenPool[EP].Kind = TK_OP) And
                  (TokenPool[EP].Val = '*') Do
            Begin
              Inc(EP);
              TIdx := TypeFindByName('int'); { pointeur = 4 }
            End;
            SzVal := TypeSizeofIdx(TIdx);
          End
          Else
          Begin
            { sizeof(expr) : taille du type de l expression }
            EP := SaveEP;
            ParseExpr;
            SzVal := 4; { par defaut int = 4 octets }
          End;
          EPMatch(')');
        End;
        EmitInstr('MOV EAX,' + IntToStr_(SzVal));
      End
      Else
      Begin
        { Mot-cle inconnu dans expression : ignorer }
        EmitComment('WARNING: mot-cle inattendu dans expression: ' +
          TokenPool[EP].Val);
        EmitInstr('XOR EAX,EAX');
        Inc(EP);
      End;
    End;

    { --- Ponctuation : parentheses ou cast --- }
    TK_PUNCT:
    Begin
      If TokenPool[EP].Val = '(' Then
      Begin
        Inc(EP);

        { Verifier si c est un cast : (type) ou (type *) expr (TODO 23) }
        SaveEP := EP;
        TIdx := ParseTypeFromTokens(EP);
        { Consommer les * de pointeur avant le ')' }
        IsPtr := False;
        While (TIdx >= 0) And Not EPAtEnd And
              (TokenPool[EP].Kind = TK_OP) And
              (TokenPool[EP].Val = '*') Do
        Begin
          Inc(EP);
          IsPtr := True;
        End;
        If (TIdx >= 0) And Not EPAtEnd And
           (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ')') Then
        Begin
          { Cast : (type)expr ou (type *)expr (TODO 23) }
          CastIdx := TypeResolve(TIdx);
          Inc(EP); { consommer ')' }
          ParseUnary;
          { Emettre le code de conversion selon le type cible }
          If IsPtr Then
          Begin
            { Cast vers pointeur : no-op en 32 bits }
            EmitComment('cast vers pointeur (no-op)');
          End
          Else If (CastIdx >= 0) And (CastIdx < TypeCount) Then
          Begin
            CastKind := TypeTab[CastIdx].Kind;
            Case CastKind Of
              TKP_CHAR:
              Begin
                { (char)expr : extension signe 8 bits -> 32 bits }
                EmitInstr('MOVSX EAX,AL');
                EmitComment('cast (char)');
              End;
              TKP_UCHAR:
              Begin
                { (unsigned char)expr : troncature a 8 bits }
                EmitInstr('AND EAX,0FFh');
                EmitComment('cast (unsigned char)');
              End;
              TKP_SHORT:
              Begin
                { (short)expr : extension signe 16 bits -> 32 bits }
                EmitInstr('MOVSX EAX,AX');
                EmitComment('cast (short)');
              End;
              TKP_USHORT:
              Begin
                { (unsigned short)expr : troncature a 16 bits }
                EmitInstr('AND EAX,0FFFFh');
                EmitComment('cast (unsigned short)');
              End;
              { int, uint, long, ulong, void, pointer : no-op en 32 bits }
            End;
          End;
        End
        Else
        Begin
          { Parentheses normales : (expr) }
          EP := SaveEP;
          ParseExpr;
          EPMatch(')');
        End;
      End
      Else
      Begin
        EmitComment('WARNING: ponctuation inattendue: ' +
          TokenPool[EP].Val);
        EmitInstr('XOR EAX,EAX');
        Inc(EP);
      End;
    End;

  Else
    EmitComment('WARNING: token inattendu dans expression');
    EmitInstr('XOR EAX,EAX');
    Inc(EP);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : parser les operateurs postfixes apres un      }
{ primary : [] . -> ++ --                                      }
{ ------------------------------------------------------------ }

Procedure ParsePostfix;
Var
  Done   : Boolean;
  Name   : TString;
  MbrTI  : Integer;  { TypeIdx du struct pour acces membre (TODO 19) }
  MbrFI  : Integer;  { Index du champ dans Fields[] (TODO 19) }
  MbrOfs : Integer;  { Offset du champ (TODO 19) }
Begin
  ParsePrimary;

  Done := False;
  While Not Done And Not EPAtEnd Do
  Begin
    { Post-increment ++ (TODO 12/17 : stockage via LastPrimaryName, mise a l echelle pour pointeurs) }
    If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '++') Then
    Begin
      Inc(EP);
      If LastPrimaryName <> '' Then
      Begin
        EmitInstr('PUSH EAX');
        If VarIsPointer(LastPrimaryName) Then
          EmitInstr('ADD EAX,4')
        Else
          EmitInstr('INC EAX');
        GenStoreVar(LastPrimaryName);
        EmitInstr('POP EAX');
      End
      Else
      Begin
        EmitInstr('PUSH EAX');
        EmitInstr('INC EAX');
        EmitComment('; post-increment (expression, pas de stockage)');
        EmitInstr('POP EAX');
      End;
      LastPrimaryName := '';
    End
    { Post-decrement -- (TODO 12/17 : stockage via LastPrimaryName, mise a l echelle pour pointeurs) }
    Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '--') Then
    Begin
      Inc(EP);
      If LastPrimaryName <> '' Then
      Begin
        EmitInstr('PUSH EAX');
        If VarIsPointer(LastPrimaryName) Then
          EmitInstr('SUB EAX,4')
        Else
          EmitInstr('DEC EAX');
        GenStoreVar(LastPrimaryName);
        EmitInstr('POP EAX');
      End
      Else
      Begin
        EmitInstr('PUSH EAX');
        EmitInstr('DEC EAX');
        EmitComment('; post-decrement (expression, pas de stockage)');
        EmitInstr('POP EAX');
      End;
      LastPrimaryName := '';
    End
    { Acces tableau [index] }
    Else If (TokenPool[EP].Kind = TK_PUNCT) And
            (TokenPool[EP].Val = '[') Then
    Begin
      Inc(EP);
      EmitInstr('PUSH EAX');
      ParseExpr;
      EmitInstr('SHL EAX,2');
      EmitInstr('POP EBX');
      EmitInstr('ADD EAX,EBX');
      EmitInstr('MOV EAX,DWORD PTR [EAX]');
      EPMatch(']');
    End
    { Acces membre struct . (TODO 19) }
    Else If ((TokenPool[EP].Kind = TK_PUNCT) Or (TokenPool[EP].Kind = TK_OP)) And
            (TokenPool[EP].Val = '.') Then
    Begin
      Inc(EP);
      If Not EPAtEnd And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[EP].Val;
        Inc(EP);
        { EAX = adresse de la struct. Chercher le champ. }
        { Determiner le type de la struct via LastPrimaryName }
        MbrTI := VarTypeIdx(LastPrimaryName);
        MbrFI := StructFieldFind(MbrTI, Name);
        If MbrFI >= 0 Then
        Begin
          MbrOfs := TypeTab[MbrTI].Fields[MbrFI].Offset;
          If MbrOfs > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(MbrOfs));
          EmitInstr('MOV EAX,DWORD PTR [EAX]');
        End
        Else
          EmitComment('; WARNING: champ non trouve: .' + Name);
      End;
      LastPrimaryName := '';
    End
    { Acces membre via pointeur -> (TODO 19) }
    Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '->') Then
    Begin
      Inc(EP);
      { EAX = pointeur vers struct : dereferencer pour obtenir adresse struct }
      EmitInstr('MOV EAX,DWORD PTR [EAX]');
      If Not EPAtEnd And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[EP].Val;
        Inc(EP);
        { Chercher le type pointe }
        MbrTI := VarTypeIdx(LastPrimaryName);
        If (MbrTI >= 0) And (MbrTI < TypeCount) And
           (TypeTab[MbrTI].Kind = TKP_POINTER) Then
          MbrTI := TypeTab[MbrTI].BaseTypeIdx;
        MbrFI := StructFieldFind(MbrTI, Name);
        If MbrFI >= 0 Then
        Begin
          MbrOfs := TypeTab[MbrTI].Fields[MbrFI].Offset;
          If MbrOfs > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(MbrOfs));
          EmitInstr('MOV EAX,DWORD PTR [EAX]');
        End
        Else
          EmitComment('; WARNING: champ non trouve: ->' + Name);
      End;
      LastPrimaryName := '';
    End
    Else
      Done := True;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser les operateurs unaires prefixes           }
{ ++ -- + - ! ~ * & sizeof (cast)                             }
{ ------------------------------------------------------------ }

Procedure ParseUnary;
Var
  Name : TString;
Begin
  If EPAtEnd Then
  Begin
    EmitInstr('XOR EAX,EAX');
    Exit;
  End;

  { Pre-increment ++ (TODO 17 : mise a l echelle pour pointeurs) }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '++') Then
  Begin
    Inc(EP);
    If Not EPAtEnd And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[EP].Val;
      Inc(EP);
      GenLoadVar(Name);
      If VarIsPointer(Name) Then
        EmitInstr('ADD EAX,4')
      Else
        EmitInstr('INC EAX');
      GenStoreVar(Name);
    End
    Else
      ParseUnary;
  End
  { Pre-decrement -- (TODO 17 : mise a l echelle pour pointeurs) }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '--') Then
  Begin
    Inc(EP);
    If Not EPAtEnd And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[EP].Val;
      Inc(EP);
      GenLoadVar(Name);
      If VarIsPointer(Name) Then
        EmitInstr('SUB EAX,4')
      Else
        EmitInstr('DEC EAX');
      GenStoreVar(Name);
    End
    Else
      ParseUnary;
  End
  { Negation unaire - }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '-') Then
  Begin
    Inc(EP);
    ParseUnary;
    EmitInstr('NEG EAX');
  End
  { Plus unaire + (no-op) }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '+') Then
  Begin
    Inc(EP);
    ParseUnary;
  End
  { NOT logique ! }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '!') Then
  Begin
    Inc(EP);
    ParseUnary;
    EmitInstr('TEST EAX,EAX');
    EmitInstr('SETZ AL');
    EmitInstr('MOVZX EAX,AL');
  End
  { NOT bit a bit ~ }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '~') Then
  Begin
    Inc(EP);
    ParseUnary;
    EmitInstr('NOT EAX');
  End
  { Dereferencement * }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '*') Then
  Begin
    Inc(EP);
    ParseUnary;
    EmitInstr('MOV EAX,DWORD PTR [EAX]');
  End
  { Adresse de & }
  Else If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '&') Then
  Begin
    Inc(EP);
    If Not EPAtEnd And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[EP].Val;
      Inc(EP);
      GenLoadAddr(Name);
    End
    Else
    Begin
      ParseUnary;
      EmitComment('; & sur expression non-lvalue');
    End;
  End
  Else
    ParsePostfix;
End;

{ ============================================================ }
{ TODO 11 - OPERATEURS ET PRECEDENCE                          }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ BinOpPrec : retourner le niveau de precedence d un operateur  }
{ binaire C. 0 = pas un operateur binaire.                     }
{ Plus le nombre est eleve, plus l operateur lie fortement      }
{ (ex: * = 13 > + = 12, donc * s applique avant +).            }
{ ------------------------------------------------------------ }

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If (Op = '*') Or (Op = '/') Or (Op = '%') Then
    BinOpPrec := 13
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 12
  Else If (Op = '<<') Or (Op = '>>') Then
    BinOpPrec := 11
  Else If (Op = '<') Or (Op = '<=') Or
          (Op = '>') Or (Op = '>=') Then
    BinOpPrec := 10
  Else If (Op = '==') Or (Op = '!=') Then
    BinOpPrec := 9
  Else If Op = '&' Then
    BinOpPrec := 8
  Else If Op = '^' Then
    BinOpPrec := 7
  Else If Op = '|' Then
    BinOpPrec := 6
  Else If Op = '&&' Then
    BinOpPrec := 5
  Else If Op = '||' Then
    BinOpPrec := 4
  Else If Op = '?' Then
    BinOpPrec := 3
  Else If (Op = '=')   Or (Op = '+=')  Or (Op = '-=') Or
          (Op = '*=')  Or (Op = '/=')  Or (Op = '%=') Or
          (Op = '&=')  Or (Op = '|=')  Or (Op = '^=') Or
          (Op = '<<=') Or (Op = '>>=') Then
    BinOpPrec := 2
  Else If Op = ',' Then
    BinOpPrec := 1
  Else
    BinOpPrec := 0;
End;

{ ------------------------------------------------------------ }
{ BinOpIsRight : True si l operateur est associatif a droite    }
{ (affectation, ternaire)                                       }
{ ------------------------------------------------------------ }

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or
                  (Op = '*=')  Or (Op = '/=')  Or (Op = '%=')  Or
                  (Op = '&=')  Or (Op = '|=')  Or (Op = '^=')  Or
                  (Op = '<<=') Or (Op = '>>=') Or (Op = '?');
End;

{ ------------------------------------------------------------ }
{ IsAssignOp : True si l operateur est une affectation          }
{ ------------------------------------------------------------ }

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or
                (Op = '*=')  Or (Op = '/=')  Or (Op = '%=')  Or
                (Op = '&=')  Or (Op = '|=')  Or (Op = '^=')  Or
                (Op = '<<=') Or (Op = '>>=');
End;

{ ------------------------------------------------------------ }
{ EmitBinOp : emettre le code ASM pour EAX op EBX              }
{ Le resultat doit etre dans EAX.                               }
{ ------------------------------------------------------------ }

Procedure EmitBinOp(Const Op : TString);
Var
  LblTrue, LblEnd : TString;
Begin
  { Arithmetique }
  If Op = '+' Then
    EmitInstr('ADD EAX,EBX')
  Else If Op = '-' Then
    EmitInstr('SUB EAX,EBX')
  Else If Op = '*' Then
    EmitInstr('IMUL EAX,EBX')
  Else If Op = '/' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
  End
  Else If Op = '%' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
    EmitInstr('MOV EAX,EDX');
  End
  { Decalages }
  Else If Op = '<<' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SHL EAX,CL');
  End
  Else If Op = '>>' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SAR EAX,CL');
  End
  { Bit a bit }
  Else If Op = '&' Then
    EmitInstr('AND EAX,EBX')
  Else If Op = '|' Then
    EmitInstr('OR EAX,EBX')
  Else If Op = '^' Then
    EmitInstr('XOR EAX,EBX')
  { Comparaisons }
  Else If Op = '==' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '!=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JNE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JL ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JLE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JG ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JGE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else
    EmitComment('; operateur binaire inconnu: ' + Op);
End;

{ ------------------------------------------------------------ }
{ EmitCompoundOp : emettre les instructions pour l operateur    }
{ compose sur EAX (gauche) et EBX (droite). Resultat dans EAX. }
{ ------------------------------------------------------------ }

Procedure EmitCompoundOp(Const Op : TString);
Begin
  If Op = '+=' Then
    EmitInstr('ADD EAX,EBX')
  Else If Op = '-=' Then
    EmitInstr('SUB EAX,EBX')
  Else If Op = '*=' Then
    EmitInstr('IMUL EAX,EBX')
  Else If Op = '/=' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
  End
  Else If Op = '%=' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
    EmitInstr('MOV EAX,EDX');
  End
  Else If Op = '&=' Then
    EmitInstr('AND EAX,EBX')
  Else If Op = '|=' Then
    EmitInstr('OR EAX,EBX')
  Else If Op = '^=' Then
    EmitInstr('XOR EAX,EBX')
  Else If Op = '<<=' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SHL EAX,CL');
  End
  Else If Op = '>>=' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SAR EAX,CL');
  End;
End;

{ ------------------------------------------------------------ }
{ GenStoreVarCompound : emettre le code pour op= sur variable   }
{ EAX contient la valeur droite, effectue var op= EAX          }
{ ------------------------------------------------------------ }

Procedure GenStoreVarCompound(Const Name, Op : TString);
Begin
  EmitInstr('MOV EBX,EAX');
  GenLoadVar(Name);
  EmitCompoundOp(Op);
  GenStoreVar(Name);
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : parseur de Pratt pour expressions C           }
{ MinPrec = niveau de precedence minimal a capturer.            }
{ Le resultat est toujours dans EAX.                            }
{ ------------------------------------------------------------ }

Procedure ParseExprPrec(MinPrec : Integer);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  LblF     : TString;
  LblE     : TString;
Begin
  ParseUnary;

  While Not EPAtEnd Do
  Begin
    { Lire l operateur courant }
    Op := '';
    If TokenPool[EP].Kind = TK_OP Then
      Op := TokenPool[EP].Val
    Else If (TokenPool[EP].Kind = TK_PUNCT) And
            (TokenPool[EP].Val = ',') Then
      Op := ','
    Else If (TokenPool[EP].Kind = TK_PUNCT) And
            (TokenPool[EP].Val = '?') Then
      Op := '?';

    Prec := BinOpPrec(Op);
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    Inc(EP); { consommer l operateur }

    { --- Affectation : = et opérateurs composés --- }
    { Traité dans ParseBody pour les cas simples ident = expr }
    { Ici on gère le cas dans une expression (rare mais possible) }
    If IsAssignOp(Op) Then
    Begin
      { Note : les affectations simples (ident = expr) sont traitees   }
      { directement dans ParseBody. Ici on gere le cas ou une          }
      { affectation apparait dans une sous-expression. La verification }
      { de lvalue n est pas effectuee (limitation connue).             }
      EmitInstr('PUSH EAX');
      If BinOpIsRight(Op) Then
        NextPrec := Prec
      Else
        NextPrec := Prec + 1;
      ParseExprPrec(NextPrec);
      If Op = '=' Then
      Begin
        { La valeur droite est dans EAX, on ignore le gauche empile }
        EmitInstr('ADD ESP,4');
        EmitComment('; affectation dans expression');
      End
      Else
      Begin
        { Operateur compose dans expression : calculer }
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EAX');
        EmitCompoundOp(Op);
      End;
      Continue;
    End;

    { --- Court-circuit && (ET logique) --- }
    If Op = '&&' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      ParseExprPrec(Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      EmitInstr('MOV EAX,1');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('XOR EAX,EAX');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Court-circuit || (OU logique) --- }
    If Op = '||' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      ParseExprPrec(Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      EmitInstr('XOR EAX,EAX');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('MOV EAX,1');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Ternaire ?: --- }
    If Op = '?' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      { Branche vraie }
      ParseExprPrec(1);
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      { Consommer le ':' }
      If Not EPAtEnd And
         ((TokenPool[EP].Kind = TK_OP) Or
          (TokenPool[EP].Kind = TK_PUNCT)) And
         (TokenPool[EP].Val = ':') Then
        Inc(EP);
      { Branche fausse }
      ParseExprPrec(3);
      EmitLabel(LblE);
      Continue;
    End;

    { --- Virgule : evaluer les deux, garder la droite --- }
    If Op = ',' Then
    Begin
      { EAX contient la valeur gauche, on l ignore }
      ParseExprPrec(Prec + 1);
      Continue;
    End;

    { --- Operateurs binaires normaux --- }
    { Sauver la valeur gauche (EAX) sur la pile }
    EmitInstr('PUSH EAX');

    If BinOpIsRight(Op) Then
      NextPrec := Prec
    Else
      NextPrec := Prec + 1;
    ParseExprPrec(NextPrec);

    { EAX = droite, pile = gauche }
    EmitInstr('MOV EBX,EAX');
    EmitInstr('POP EAX');
    EmitBinOp(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : parser une expression complete                    }
{ Appelle ParseExprPrec avec la precedence minimale (1).        }
{ ------------------------------------------------------------ }

Procedure ParseExpr;
Begin
  ParseExprPrec(1);
End;

{ ============================================================ }
{ TODO 12 - AFFECTATIONS ET OPERATEURS COMPOSES               }
{ Les affectations composees (op=) et les increments/decrements }
{ sont geres dans ParseBody comme cas speciaux au niveau        }
{ statement. ParsePostfix utilise LastPrimaryName pour stocker  }
{ correctement les post-increment/decrement.                    }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseBody : parser et emettre le code du corps d une fonction }
{ Gere les declarations, return, expression-statements, et     }
{ les instructions de controle if/else (TODO 13).              }
{ Les boucles for/while/do-while (TODO 14).                    }
{ Le switch/case/default (TODO 15).                            }
{ ------------------------------------------------------------ }

{ ============================================================ }
{ TODO 13 - INSTRUCTIONS DE CONTROLE (if / else)               }
{ ParseStmt parse une instruction unique. ParseCompoundStmt    }
{ parse un bloc d instructions. ParseIfStmt gere if/else.      }
{ ============================================================ }

Procedure ParseStmt; Forward;
Procedure ParseCompoundStmt; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt; Forward;
Procedure ParseSimpleExprStmt; Forward;
Procedure ParseSwitchStmt; Forward;

{ ------------------------------------------------------------ }
{ ParseCompoundStmt : parser un bloc de code (accolades)        }
{ ------------------------------------------------------------ }

Procedure ParseCompoundStmt;
Begin
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '{') Then
    Inc(EP);
  While (EP < EPEnd) And
        Not ((TokenPool[EP].Kind = TK_PUNCT) And
             (TokenPool[EP].Val = '}')) Do
    ParseStmt;
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '}') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : parser if (cond) stmt [else stmt]               }
{ Le mot-cle 'if' a deja ete consomme.                          }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt;
Var
  LblElse, LblEnd : TString;
  HasElse         : Boolean;
Begin
  LblElse := LabelGen;
  LblEnd  := LabelGen;

  { Parser '(' condition ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '(') Then
    Inc(EP);

  ParseExpr;

  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  { Tester la condition : si faux, sauter au else/endif }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblElse);

  { Parser le bloc then }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '{') Then
    ParseCompoundStmt
  Else
    ParseStmt;

  { Verifier s il y a un else }
  HasElse := (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
             (TokenPool[EP].Val = 'else');

  If HasElse Then
  Begin
    Inc(EP); { consommer 'else' }
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblElse);

    { Parser le bloc else (peut etre un 'else if') }
    If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = '{') Then
      ParseCompoundStmt
    Else
      ParseStmt;

    EmitLabel(LblEnd);
  End
  Else
    EmitLabel(LblElse);
End;

{ ============================================================ }
{ TODO 14 - BOUCLES (for / while / do-while)                   }
{ ParseWhileStmt, ParseDoWhileStmt, ParseForStmt.             }
{ LoopPush/LoopPop gerent la pile break/continue.             }
{ ParseSimpleExprStmt gere les assignations simples sans ';'. }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ LoopPush : empiler les labels de la boucle courante          }
{ ------------------------------------------------------------ }

Procedure LoopPush(Const BrkLbl, ContLbl : TString);
Begin
  If LoopTop >= 32 Then
    FatalError('boucles imbriquees trop profondes (max 32)');
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  Inc(LoopTop);
End;

{ ------------------------------------------------------------ }
{ LoopPop : depiler les labels de la boucle courante           }
{ ------------------------------------------------------------ }

Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

{ ------------------------------------------------------------ }
{ ParseSimpleExprStmt : parser une instruction-expression      }
{ simple sans consommer le terminateur (; ou )).               }
{ Gere ident++/-- , ident op= expr, *ident op= expr.          }
{ ------------------------------------------------------------ }

Procedure ParseSimpleExprStmt;
Var
  Name, Op : TString;
  K, Depth : Integer;
  SaveEnd  : Integer;
Begin
  If EPAtEnd Then Exit;

  { ident++ / ident-- (TODO 17 : mise a l echelle pour pointeurs) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_OP) And
     ((TokenPool[EP + 1].Val = '++') Or
      (TokenPool[EP + 1].Val = '--')) Then
  Begin
    Name := TokenPool[EP].Val;
    GenLoadVar(Name);
    If VarIsPointer(Name) Then
    Begin
      If TokenPool[EP + 1].Val = '++' Then
        EmitInstr('ADD EAX,4')
      Else
        EmitInstr('SUB EAX,4');
    End
    Else
    Begin
      If TokenPool[EP + 1].Val = '++' Then
        EmitInstr('INC EAX')
      Else
        EmitInstr('DEC EAX');
    End;
    GenStoreVar(Name);
    Inc(EP, 2);
    Exit;
  End;

  { ident = expr / ident op= expr }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_OP) And
     IsAssignOp(TokenPool[EP + 1].Val) Then
  Begin
    Name := TokenPool[EP].Val;
    Op   := TokenPool[EP + 1].Val;
    Inc(EP, 2);
    ParseExpr;
    If Op = '=' Then
      GenStoreVar(Name)
    Else
      GenStoreVarCompound(Name, Op);
    Exit;
  End;

  { *ident = expr / *ident op= expr }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '*') And
     (EP + 2 < EPEnd) And (TokenPool[EP + 1].Kind = TK_IDENT) And
     (TokenPool[EP + 2].Kind = TK_OP) And
     IsAssignOp(TokenPool[EP + 2].Val) Then
  Begin
    Name := TokenPool[EP + 1].Val;
    Op   := TokenPool[EP + 2].Val;
    Inc(EP, 3);
    ParseExpr;
    If Op = '=' Then
    Begin
      EmitInstr('PUSH EAX');
      GenLoadVar(Name);
      EmitInstr('POP DWORD PTR [EAX]');
    End
    Else
    Begin
      EmitInstr('MOV EBX,EAX');
      GenLoadVar(Name);
      EmitInstr('PUSH EAX');
      EmitInstr('MOV EAX,DWORD PTR [EAX]');
      EmitCompoundOp(Op);
      EmitInstr('POP ECX');
      EmitInstr('MOV DWORD PTR [ECX],EAX');
    End;
    Exit;
  End;

  { ident[expr] = expr / ident[expr] op= expr (TODO 18) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_PUNCT) And
     (TokenPool[EP + 1].Val = '[') Then
  Begin
    Name := TokenPool[EP].Val;
    K := EP + 2;
    Depth := 1;
    While (K < EPEnd) And (Depth > 0) Do
    Begin
      If (TokenPool[K].Kind = TK_PUNCT) And (TokenPool[K].Val = '[') Then
        Inc(Depth)
      Else If (TokenPool[K].Kind = TK_PUNCT) And (TokenPool[K].Val = ']') Then
        Dec(Depth);
      If Depth > 0 Then Inc(K);
    End;
    If (Depth = 0) And (K + 1 < EPEnd) And
       (TokenPool[K + 1].Kind = TK_OP) And
       IsAssignOp(TokenPool[K + 1].Val) Then
    Begin
      Op := TokenPool[K + 1].Val;
      Inc(EP, 2);
      SaveEnd := EPEnd;
      EPEnd   := K;
      ParseExpr;
      EPEnd   := SaveEnd;
      EmitInstr('SHL EAX,2');
      EmitInstr('PUSH EAX');
      GenLoadVar(Name);
      EmitInstr('POP EBX');
      EmitInstr('ADD EAX,EBX');
      EmitInstr('PUSH EAX');
      EP := K + 2;
      If Op = '=' Then
      Begin
        ParseExpr;
        EmitInstr('POP ECX');
        EmitInstr('MOV DWORD PTR [ECX],EAX');
      End
      Else
      Begin
        EmitInstr('POP ECX');
        EmitInstr('PUSH ECX');
        EmitInstr('MOV EAX,DWORD PTR [ECX]');
        EmitInstr('PUSH EAX');
        ParseExpr;
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EAX');
        EmitCompoundOp(Op);
        EmitInstr('POP ECX');
        EmitInstr('MOV DWORD PTR [ECX],EAX');
      End;
      Exit;
    End;
  End;

  { Expression generale }
  ParseExpr;
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : parser while (cond) stmt                    }
{ Le mot-cle 'while' a deja ete consomme.                      }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt;
Var
  LblTest, LblEnd : TString;
Begin
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);

  EmitLabel(LblTest);

  { Parser '(' condition ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '(') Then
    Inc(EP);
  ParseExpr;
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblEnd);

  { Parser le corps }
  ParseStmt;

  EmitInstr('JMP ' + LblTest);
  EmitLabel(LblEnd);

  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseDoWhileStmt : parser do stmt while (cond) ;             }
{ Le mot-cle 'do' a deja ete consomme.                         }
{ ------------------------------------------------------------ }

Procedure ParseDoWhileStmt;
Var
  LblBeg, LblTest, LblEnd : TString;
Begin
  LblBeg  := LabelGen;
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);

  EmitLabel(LblBeg);

  { Parser le corps }
  ParseStmt;

  { Consommer 'while' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'while') Then
    Inc(EP);

  EmitLabel(LblTest);

  { Parser '(' condition ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '(') Then
    Inc(EP);
  ParseExpr;
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + LblBeg);
  EmitLabel(LblEnd);

  { Consommer ';' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);

  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : parser for (init; cond; incr) stmt            }
{ Le mot-cle 'for' a deja ete consomme.                        }
{ ------------------------------------------------------------ }

Procedure ParseForStmt;
Var
  LblTest, LblIncr, LblEnd : TString;
  IncrStart, IncrEnd        : Integer;
  SaveEP, OldEPEnd          : Integer;
  Name                      : TString;
  Depth                     : Integer;
Begin
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblIncr);

  { Consommer '(' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '(') Then
    Inc(EP);

  { --- Init --- }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
  Begin
    { Init vide }
    Inc(EP);
  End
  Else If (EP < EPEnd) And
          (((TokenPool[EP].Kind = TK_KEYWORD) And
            (IsTypeSpecifier(TokenPool[EP].Val) Or
             IsStorageClass(TokenPool[EP].Val) Or
             IsQualifier(TokenPool[EP].Val))) Or
           ((TokenPool[EP].Kind = TK_KEYWORD) And
            ((TokenPool[EP].Val = 'struct') Or
             (TokenPool[EP].Val = 'union') Or
             (TokenPool[EP].Val = 'enum')))) Then
  Begin
    { Declaration avec initialisation possible }
    { Sauter les mots-cles de type / qualificateurs / pointeurs }
    While (EP < EPEnd) And
          (((TokenPool[EP].Kind = TK_KEYWORD) And
            (IsTypeSpecifier(TokenPool[EP].Val) Or
             IsStorageClass(TokenPool[EP].Val) Or
             IsQualifier(TokenPool[EP].Val))) Or
           ((TokenPool[EP].Kind = TK_KEYWORD) And
            ((TokenPool[EP].Val = 'struct') Or
             (TokenPool[EP].Val = 'union') Or
             (TokenPool[EP].Val = 'enum'))) Or
           ((TokenPool[EP].Kind = TK_OP) And
            (TokenPool[EP].Val = '*'))) Do
      Inc(EP);
    { Devrait etre a l identifiant }
    If (EP < EPEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[EP].Val;
      Inc(EP);
      If (EP < EPEnd) And (TokenPool[EP].Kind = TK_OP) And
         (TokenPool[EP].Val = '=') Then
      Begin
        Inc(EP); { consommer '=' }
        ParseExpr;
        GenStoreVar(Name);
      End;
    End;
    { Avancer au ';' }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
  End
  Else
  Begin
    { Expression init }
    ParseSimpleExprStmt;
    { Avancer au ';' }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
  End;

  { --- Condition --- }
  EmitLabel(LblTest);
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
  Begin
    { Condition vide -> boucle infinie }
    Inc(EP);
  End
  Else
  Begin
    ParseExpr;
    EmitInstr('TEST EAX,EAX');
    EmitInstr('JZ ' + LblEnd);
    { Avancer au ';' }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
  End;

  { --- Sauver la position de l increment --- }
  IncrStart := EP;
  Depth := 0;
  While (EP < EPEnd) Do
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = '(') Then
      Inc(Depth)
    Else If (TokenPool[EP].Kind = TK_PUNCT) And
            (TokenPool[EP].Val = ')') Then
    Begin
      If Depth = 0 Then Break;
      Dec(Depth);
    End;
    Inc(EP);
  End;
  IncrEnd := EP;
  { Consommer ')' }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  { --- Corps --- }
  ParseStmt;

  { --- Emettre l increment --- }
  EmitLabel(LblIncr);
  If IncrStart < IncrEnd Then
  Begin
    SaveEP   := EP;
    OldEPEnd := EPEnd;
    EP       := IncrStart;
    EPEnd    := IncrEnd;
    ParseSimpleExprStmt;
    EP    := SaveEP;
    EPEnd := OldEPEnd;
  End;

  EmitInstr('JMP ' + LblTest);
  EmitLabel(LblEnd);

  LoopPop;
End;

{ ============================================================ }
{ TODO 15 - SWITCH / CASE / DEFAULT                            }
{ ParseSwitchStmt gere switch(expr) avec case val: stmts.     }
{ SwitchPush/SwitchPop gerent la pile break pour switch.       }
{ break dans un switch utilise SwitchBreakLbl en priorite.     }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ SwitchPush : empiler le label de fin du switch courant        }
{ ------------------------------------------------------------ }

Procedure SwitchPush(Const BrkLbl : TString);
Begin
  If SwitchTop >= 32 Then
    FatalError('switch imbriques trop profonds (max 32)');
  SwitchBreakLbl[SwitchTop] := BrkLbl;
  Inc(SwitchTop);
End;

{ ------------------------------------------------------------ }
{ SwitchPop : depiler le label de fin du switch courant         }
{ ------------------------------------------------------------ }

Procedure SwitchPop;
Begin
  If SwitchTop > 0 Then
    Dec(SwitchTop);
End;

{ ------------------------------------------------------------ }
{ ParseSwitchStmt : parser switch (expr) avec case ... default  }
{ Le mot-cle 'switch' a deja ete consomme.                     }
{ Strategie en deux passes :                                    }
{   Passe 1 : scanner les case/default, generer les labels,    }
{             emettre la chaine de CMP/JE.                      }
{   Passe 2 : revenir au debut, parser et emettre les corps.   }
{ Fall-through : sans break, execution continue au case suivant.}
{ ------------------------------------------------------------ }

Procedure ParseSwitchStmt;
Const
  MAX_CASE = 64;
Var
  LblEnd     : TString;
  LblDefault : TString;
  CaseLbls   : Array[0..63] Of TString;
  CaseVals   : Array[0..63] Of LongInt;
  CaseCount  : Integer;
  HasDefault : Boolean;
  BodyStart  : Integer;
  ScanEP     : Integer;
  Depth      : Integer;
  I          : Integer;
  K          : Integer;
  CaseVal    : LongInt;
Begin
  LblEnd     := LabelGen;
  CaseCount  := 0;
  HasDefault := False;
  LblDefault := '';

  { Parser '(' expression ')' }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '(') Then
    Inc(EP);

  ParseExpr;

  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ')') Then
    Inc(EP);

  { Sauvegarder la valeur de l expression dans ECX }
  EmitInstr('MOV ECX,EAX');
  EmitComment('switch (valeur dans ECX)');

  { Empiler le label de fin pour break }
  SwitchPush(LblEnd);

  { Consommer l accolade ouvrante }
  If Not EPAtEnd And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '{') Then
    Inc(EP);

  { Sauvegarder la position de debut du corps du switch }
  BodyStart := EP;

  { --- Passe 1 : scanner pour trouver tous les case/default --- }
  ScanEP := EP;
  Depth  := 0;
  While (ScanEP < EPEnd) And
        Not ((Depth = 0) And (TokenPool[ScanEP].Kind = TK_PUNCT) And
             (TokenPool[ScanEP].Val = '}')) Do
  Begin
    If (TokenPool[ScanEP].Kind = TK_PUNCT) And
       (TokenPool[ScanEP].Val = '{') Then
      Inc(Depth)
    Else If (TokenPool[ScanEP].Kind = TK_PUNCT) And
            (TokenPool[ScanEP].Val = '}') Then
      Dec(Depth);

    { Detecter case/default au niveau 0 (pas dans un bloc imbrique) }
    If Depth = 0 Then
    Begin
      If (TokenPool[ScanEP].Kind = TK_KEYWORD) And
         (TokenPool[ScanEP].Val = 'case') Then
      Begin
        Inc(ScanEP); { sauter 'case' }
        { Lire la valeur du case }
        CaseVal := 0;
        If ScanEP < EPEnd Then
        Begin
          If TokenPool[ScanEP].Kind = TK_INTEGER Then
          Begin
            CaseVal := TokenPool[ScanEP].IntVal;
            Inc(ScanEP);
          End
          Else If TokenPool[ScanEP].Kind = TK_CHAR Then
          Begin
            CaseVal := Ord(TokenPool[ScanEP].Val[1]);
            Inc(ScanEP);
          End
          Else If (TokenPool[ScanEP].Kind = TK_OP) And
                  (TokenPool[ScanEP].Val = '-') And
                  (ScanEP + 1 < EPEnd) And
                  (TokenPool[ScanEP + 1].Kind = TK_INTEGER) Then
          Begin
            CaseVal := -TokenPool[ScanEP + 1].IntVal;
            Inc(ScanEP, 2);
          End
          Else If (TokenPool[ScanEP].Kind = TK_IDENT) Then
          Begin
            { Constante enum ? (TODO 20) }
            K := SymFind(TokenPool[ScanEP].Val);
            If (K >= 0) And (SymTab[K].Cat = SC_ENUM_VAL) Then
              CaseVal := SymTab[K].ImmVal;
            Inc(ScanEP);
          End
          Else
            Inc(ScanEP);
        End;
        { Sauter ':' }
        If (ScanEP < EPEnd) And (TokenPool[ScanEP].Kind = TK_PUNCT) And
           (TokenPool[ScanEP].Val = ':') Then
          Inc(ScanEP);
        { Enregistrer ce case }
        If CaseCount < MAX_CASE Then
        Begin
          CaseVals[CaseCount] := CaseVal;
          CaseLbls[CaseCount] := LabelGen;
          Inc(CaseCount);
        End;
      End
      Else If (TokenPool[ScanEP].Kind = TK_KEYWORD) And
              (TokenPool[ScanEP].Val = 'default') Then
      Begin
        HasDefault := True;
        LblDefault := LabelGen;
        Inc(ScanEP); { sauter 'default' }
        If (ScanEP < EPEnd) And (TokenPool[ScanEP].Kind = TK_PUNCT) And
           (TokenPool[ScanEP].Val = ':') Then
          Inc(ScanEP);
      End
      Else
        Inc(ScanEP);
    End
    Else
      Inc(ScanEP);
  End;

  { --- Emettre la chaine de comparaisons --- }
  For I := 0 To CaseCount - 1 Do
  Begin
    EmitInstr('CMP ECX,' + IntToStr_(CaseVals[I]));
    EmitInstr('JE ' + CaseLbls[I]);
  End;
  If HasDefault Then
    EmitInstr('JMP ' + LblDefault)
  Else
    EmitInstr('JMP ' + LblEnd);

  { --- Passe 2 : revenir au debut et parser les corps --- }
  EP := BodyStart;
  I  := 0;
  While (EP < EPEnd) And
        Not ((TokenPool[EP].Kind = TK_PUNCT) And
             (TokenPool[EP].Val = '}')) Do
  Begin
    { --- case valeur : --- }
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (TokenPool[EP].Val = 'case') Then
    Begin
      Inc(EP); { consommer 'case' }
      { Sauter la valeur du case }
      If EP < EPEnd Then
      Begin
        If (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = '-') And
           (EP + 1 < EPEnd) And
           (TokenPool[EP + 1].Kind = TK_INTEGER) Then
          Inc(EP, 2)
        Else
          Inc(EP);
      End;
      { Consommer ':' }
      If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
        Inc(EP);
      { Emettre le label du case }
      If I < CaseCount Then
      Begin
        EmitLabel(CaseLbls[I]);
        Inc(I);
      End;
      { Instructions du case (fall-through si pas de break) }
      While (EP < EPEnd) And
            Not ((TokenPool[EP].Kind = TK_KEYWORD) And
                 ((TokenPool[EP].Val = 'case') Or
                  (TokenPool[EP].Val = 'default'))) And
            Not ((TokenPool[EP].Kind = TK_PUNCT) And
                 (TokenPool[EP].Val = '}')) Do
        ParseStmt;
    End

    { --- default : --- }
    Else If (TokenPool[EP].Kind = TK_KEYWORD) And
            (TokenPool[EP].Val = 'default') Then
    Begin
      Inc(EP); { consommer 'default' }
      { Consommer ':' }
      If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
        Inc(EP);
      EmitLabel(LblDefault);
      { Instructions du default }
      While (EP < EPEnd) And
            Not ((TokenPool[EP].Kind = TK_KEYWORD) And
                 ((TokenPool[EP].Val = 'case') Or
                  (TokenPool[EP].Val = 'default'))) And
            Not ((TokenPool[EP].Kind = TK_PUNCT) And
                 (TokenPool[EP].Val = '}')) Do
        ParseStmt;
    End

    Else
    Begin
      { Inattendu dans le switch, avancer }
      Inc(EP);
    End;
  End;

  { Consommer l accolade fermante }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = '}') Then
    Inc(EP);

  EmitLabel(LblEnd);
  SwitchPop;
End;

{ ------------------------------------------------------------ }
{ ParseStmt : parser une instruction unique                      }
{ Gere : vide, bloc, return, declaration, if, boucles, switch. }
{ ------------------------------------------------------------ }

Procedure ParseStmt;
Var
  Name    : TString;
  Op      : TString;
  Depth   : Integer;
  TIdx    : Integer;
  SaveEP  : Integer;
  K       : Integer;  { pour scan ahead ident[...] = expr (TODO 18) }
Begin
  If EP >= EPEnd Then Exit;

  { --- Instruction vide ; --- }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
  Begin
    Inc(EP);
    Exit;
  End;

  { --- Bloc imbrique --- }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '{') Then
  Begin
    ParseCompoundStmt;
    Exit;
  End;

  { --- return [expr] ; --- }
  If (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'return') Then
  Begin
    Inc(EP);
    If Not EPAtEnd And Not ((TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ';')) Then
      ParseExpr
    Else
      EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + RetLbl);
    While (EP < EPEnd) And Not ((TokenPool[EP].Kind = TK_PUNCT) And
          (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { --- Declarations de variables : deja traitees, les sauter --- }
  SaveEP := EP;

  { Sauter les classes de stockage }
  While (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
        IsStorageClass(TokenPool[EP].Val) Do
    Inc(EP);

  { Sauter les qualificateurs }
  While (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
        IsQualifier(TokenPool[EP].Val) Do
    Inc(EP);

  { Verifier si c est une declaration de type }
  If (EP < EPEnd) And
     (((TokenPool[EP].Kind = TK_KEYWORD) And
       IsTypeSpecifier(TokenPool[EP].Val)) Or
      ((TokenPool[EP].Kind = TK_KEYWORD) And
       ((TokenPool[EP].Val = 'struct') Or
        (TokenPool[EP].Val = 'union') Or
        (TokenPool[EP].Val = 'enum'))) Or
      ((TokenPool[EP].Kind = TK_IDENT) And
       (TypeFindByName(TokenPool[EP].Val) >= 0))) Then
  Begin
    TIdx := ParseTypeFromTokens(EP);
    If TIdx >= 0 Then
    Begin
      { Sauter les pointeurs }
      While (EP < EPEnd) And (TokenPool[EP].Kind = TK_OP) And
            (TokenPool[EP].Val = '*') Do
        Inc(EP);

      { Verifier que c est suivi d un identifiant -> declaration }
      If (EP < EPEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[EP].Val;
        Inc(EP);

        { Sauter les tableau declarators [] }
        If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = '[') Then
        Begin
          While (EP < EPEnd) And
                Not ((TokenPool[EP].Kind = TK_PUNCT) And
                     (TokenPool[EP].Val = ']')) Do
            Inc(EP);
          If EP < EPEnd Then Inc(EP);
        End;

        { Si suivi de '=' : initialiser avec l expression }
        If (EP < EPEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = '=') Then
        Begin
          Inc(EP); { sauter le '=' }
          (* Verifier si c est un initialiseur de bloc *)
          If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
             (TokenPool[EP].Val = '{') Then
          Begin
            { Initialiseur complexe : sauter }
            Depth := 1;
            Inc(EP);
            While (EP < EPEnd) And (Depth > 0) Do
            Begin
              If (TokenPool[EP].Kind = TK_PUNCT) And
                 (TokenPool[EP].Val = '{') Then Inc(Depth)
              Else If (TokenPool[EP].Kind = TK_PUNCT) And
                      (TokenPool[EP].Val = '}') Then Dec(Depth);
              Inc(EP);
            End;
          End
          Else
          Begin
            ParseExpr;
            GenStoreVar(Name);
          End;
        End;

        { Gerer les declarations multiples (int a=1, b=2;) }
        While (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
              (TokenPool[EP].Val = ',') Do
        Begin
          Inc(EP); { sauter la ',' }
          { Sauter les pointeurs }
          While (EP < EPEnd) And (TokenPool[EP].Kind = TK_OP) And
                (TokenPool[EP].Val = '*') Do
            Inc(EP);
          If (EP < EPEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
          Begin
            Name := TokenPool[EP].Val;
            Inc(EP);
            { Tableau ? }
            If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = '[') Then
            Begin
              While (EP < EPEnd) And
                    Not ((TokenPool[EP].Kind = TK_PUNCT) And
                         (TokenPool[EP].Val = ']')) Do
                Inc(EP);
              If EP < EPEnd Then Inc(EP);
            End;
            { Initialiseur ? }
            If (EP < EPEnd) And (TokenPool[EP].Kind = TK_OP) And
               (TokenPool[EP].Val = '=') Then
            Begin
              Inc(EP);
              If (EP < EPEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
                 (TokenPool[EP].Val = '{') Then
              Begin
                Depth := 1;
                Inc(EP);
                While (EP < EPEnd) And (Depth > 0) Do
                Begin
                  If (TokenPool[EP].Kind = TK_PUNCT) And
                     (TokenPool[EP].Val = '{') Then Inc(Depth)
                  Else If (TokenPool[EP].Kind = TK_PUNCT) And
                          (TokenPool[EP].Val = '}') Then Dec(Depth);
                  Inc(EP);
                End;
              End
              Else
              Begin
                ParseExpr;
                GenStoreVar(Name);
              End;
            End;
          End;
        End;

        { Avancer au ; }
        While (EP < EPEnd) And
              Not ((TokenPool[EP].Kind = TK_PUNCT) And
                   (TokenPool[EP].Val = ';')) Do
          Inc(EP);
        If EP < EPEnd Then Inc(EP);
        Exit;
      End;
    End;

    { Pas une declaration finalement, revenir }
    EP := SaveEP;
  End
  Else
    EP := SaveEP;

  { --- if (cond) stmt [else stmt] --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'if') Then
  Begin
    Inc(EP);
    ParseIfStmt;
    Exit;
  End;

  { --- while (cond) stmt --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'while') Then
  Begin
    Inc(EP);
    ParseWhileStmt;
    Exit;
  End;

  { --- do stmt while (cond) ; --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'do') Then
  Begin
    Inc(EP);
    ParseDoWhileStmt;
    Exit;
  End;

  { --- for (init; cond; incr) stmt --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'for') Then
  Begin
    Inc(EP);
    ParseForStmt;
    Exit;
  End;

  { --- switch (expr) avec case ... default --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'switch') Then
  Begin
    Inc(EP);
    ParseSwitchStmt;
    Exit;
  End;

  { --- break ; --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'break') Then
  Begin
    Inc(EP);
    If SwitchTop > 0 Then
      EmitInstr('JMP ' + SwitchBreakLbl[SwitchTop - 1])
    Else If LoopTop > 0 Then
      EmitInstr('JMP ' + LoopBreakLbl[LoopTop - 1])
    Else
      EmitComment('WARNING: break en dehors d''une boucle ou switch');
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { --- continue ; --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'continue') Then
  Begin
    Inc(EP);
    If LoopTop > 0 Then
      EmitInstr('JMP ' + LoopContLbl[LoopTop - 1])
    Else
      EmitComment('WARNING: continue en dehors d''une boucle');
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { --- goto label ; (TODO 22) --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'goto') Then
  Begin
    Inc(EP); { sauter 'goto' }
    If (EP < EPEnd) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[EP].Val;
      EmitInstr('JMP ' + CC_LBL_PFX + 'USR_' + Name);
      { Enregistrer le label utilise pour validation }
      If GotoLblUseCount < 64 Then
      Begin
        GotoLblUse[GotoLblUseCount] := Name;
        Inc(GotoLblUseCount);
      End;
      Inc(EP);
    End
    Else
      EmitComment('WARNING: goto sans label');
    { Avancer au ; }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { --- Mots-cles de controle : sauter (else) --- }
  If (EP < EPEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (TokenPool[EP].Val = 'else') Then
  Begin
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               ((TokenPool[EP].Val = ';') Or
                (TokenPool[EP].Val = '}'))) Do
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '{') Then
      Begin
        EP := SkipToMatchingBrace(EP);
        If EP < EPEnd Then Inc(EP);
      End
      Else
        Inc(EP);
    End;
    If (EP < EPEnd) And (TokenPool[EP].Val = ';') Then Inc(EP);
    Exit;
  End;

  { --- Labels (pour goto) : ident ':' (TODO 22) --- }
  If (EP + 1 < EPEnd) And (TokenPool[EP].Kind = TK_IDENT) And
     (TokenPool[EP + 1].Kind = TK_PUNCT) And
     (TokenPool[EP + 1].Val = ':') Then
  Begin
    Name := TokenPool[EP].Val;
    EmitLabel(CC_LBL_PFX + 'USR_' + Name);
    { Enregistrer le label defini pour validation }
    If GotoLblDefCount < 64 Then
    Begin
      GotoLblDef[GotoLblDefCount] := Name;
      Inc(GotoLblDefCount);
    End;
    Inc(EP, 2);
    Exit;
  End;

  { --- Expression statement : affectation et operateurs (TODO 12) --- }

  { Cas special : ident++ ; et ident-- ; (post-increment/decrement) (TODO 17) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_OP) And
     ((TokenPool[EP + 1].Val = '++') Or (TokenPool[EP + 1].Val = '--')) And
     ((EP + 2 >= EPEnd) Or
      ((TokenPool[EP + 2].Kind = TK_PUNCT) And
       (TokenPool[EP + 2].Val = ';'))) Then
  Begin
    Name := TokenPool[EP].Val;
    GenLoadVar(Name);
    If VarIsPointer(Name) Then
    Begin
      If TokenPool[EP + 1].Val = '++' Then
        EmitInstr('ADD EAX,4')
      Else
        EmitInstr('SUB EAX,4');
    End
    Else
    Begin
      If TokenPool[EP + 1].Val = '++' Then
        EmitInstr('INC EAX')
      Else
        EmitInstr('DEC EAX');
    End;
    GenStoreVar(Name);
    Inc(EP, 2);
    { Avancer au ; }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { Cas special : affectation simple et composee ident op= expr }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_OP) And
     IsAssignOp(TokenPool[EP + 1].Val) Then
  Begin
    Name := TokenPool[EP].Val;
    Op   := TokenPool[EP + 1].Val;
    Inc(EP, 2); { sauter ident et op= }
    ParseExpr;
    If Op = '=' Then
      GenStoreVar(Name)
    Else
      GenStoreVarCompound(Name, Op);
    { Avancer au ; }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { Cas special : dereferencement + affectation *ident op= expr }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '*') And
     (EP + 2 < EPEnd) And (TokenPool[EP + 1].Kind = TK_IDENT) And
     (TokenPool[EP + 2].Kind = TK_OP) And
     IsAssignOp(TokenPool[EP + 2].Val) Then
  Begin
    Name := TokenPool[EP + 1].Val;
    Op   := TokenPool[EP + 2].Val;
    Inc(EP, 3); { sauter * ident op= }
    ParseExpr;
    If Op = '=' Then
    Begin
      { *ident = expr : stocker la valeur a l adresse pointee }
      EmitInstr('PUSH EAX');
      GenLoadVar(Name);
      EmitInstr('POP DWORD PTR [EAX]');
    End
    Else
    Begin
      { *ident op= expr : charger la valeur pointee, appliquer op, stocker }
      EmitInstr('MOV EBX,EAX');      { EBX = valeur droite }
      GenLoadVar(Name);              { EAX = adresse (valeur du pointeur) }
      EmitInstr('PUSH EAX');         { sauver adresse }
      EmitInstr('MOV EAX,DWORD PTR [EAX]'); { EAX = valeur pointee }
      EmitCompoundOp(Op);            { EAX = resultat de l operation }
      EmitInstr('POP ECX');          { ECX = adresse }
      EmitInstr('MOV DWORD PTR [ECX],EAX'); { stocker resultat }
    End;
    { Avancer au ; }
    While (EP < EPEnd) And
          Not ((TokenPool[EP].Kind = TK_PUNCT) And
               (TokenPool[EP].Val = ';')) Do
      Inc(EP);
    If EP < EPEnd Then Inc(EP);
    Exit;
  End;

  { Cas special : affectation element de tableau ident[expr] = expr (TODO 18) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 1 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_PUNCT) And
     (TokenPool[EP + 1].Val = '[') Then
  Begin
    { Scanner pour trouver le ']' suivi d un operateur d affectation }
    Name := TokenPool[EP].Val;
    K := EP + 2;
    Depth := 1;
    While (K < EPEnd) And (Depth > 0) Do
    Begin
      If (TokenPool[K].Kind = TK_PUNCT) And (TokenPool[K].Val = '[') Then
        Inc(Depth)
      Else If (TokenPool[K].Kind = TK_PUNCT) And (TokenPool[K].Val = ']') Then
        Dec(Depth);
      If Depth > 0 Then Inc(K);
    End;
    { K pointe sur ']', K+1 devrait etre op= }
    If (Depth = 0) And (K + 1 < EPEnd) And
       (TokenPool[K + 1].Kind = TK_OP) And
       IsAssignOp(TokenPool[K + 1].Val) Then
    Begin
      Op := TokenPool[K + 1].Val;
      { Evaluer l index }
      Inc(EP, 2); { sauter ident et '[' }
      SaveEP  := EPEnd;
      EPEnd   := K; { borner a ']' }
      ParseExpr;
      EPEnd   := SaveEP;
      EmitInstr('SHL EAX,2');    { index * 4 (DWORD) }
      EmitInstr('PUSH EAX');     { sauver index * 4 }
      { Charger adresse base du tableau }
      GenLoadVar(Name);
      EmitInstr('POP EBX');      { EBX = index * 4 }
      EmitInstr('ADD EAX,EBX');  { EAX = adresse element }
      EmitInstr('PUSH EAX');     { sauver adresse element }
      { Sauter ']' et op= }
      EP := K + 2;
      If Op = '=' Then
      Begin
        { ident[expr] = expr : affecter a l element }
        ParseExpr;
        EmitInstr('POP ECX');
        EmitInstr('MOV DWORD PTR [ECX],EAX');
      End
      Else
      Begin
        { ident[expr] op= expr : lire, appliquer, stocker }
        EmitInstr('POP ECX');
        EmitInstr('PUSH ECX');
        EmitInstr('MOV EAX,DWORD PTR [ECX]'); { valeur actuelle }
        EmitInstr('PUSH EAX');
        ParseExpr;
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EAX');
        EmitCompoundOp(Op);
        EmitInstr('POP ECX');
        EmitInstr('MOV DWORD PTR [ECX],EAX');
      End;
      { Avancer au ; }
      While (EP < EPEnd) And
            Not ((TokenPool[EP].Kind = TK_PUNCT) And
                 (TokenPool[EP].Val = ';')) Do
        Inc(EP);
      If EP < EPEnd Then Inc(EP);
      Exit;
    End;
  End;

  { Cas special : affectation membre struct ident.field = expr (TODO 19) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 2 < EPEnd) And
     ((TokenPool[EP + 1].Kind = TK_OP) Or (TokenPool[EP + 1].Kind = TK_PUNCT)) And
     (TokenPool[EP + 1].Val = '.') And
     (TokenPool[EP + 2].Kind = TK_IDENT) Then
  Begin
    Name := TokenPool[EP].Val;
    TIdx := VarTypeIdx(Name);
    If (TIdx >= 0) And (TIdx < TypeCount) And
       (TypeTab[TIdx].Kind In [TKP_STRUCT, TKP_UNION]) Then
    Begin
      K := StructFieldFind(TIdx, TokenPool[EP + 2].Val);
      If (K >= 0) And (EP + 3 < EPEnd) And
         (TokenPool[EP + 3].Kind = TK_OP) And
         IsAssignOp(TokenPool[EP + 3].Val) Then
      Begin
        Op := TokenPool[EP + 3].Val;
        Inc(EP, 4); { sauter ident . field op= }
        If Op = '=' Then
        Begin
          ParseExpr;
          EmitInstr('PUSH EAX');
          GenLoadAddr(Name);
          If TypeTab[TIdx].Fields[K].Offset > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(TypeTab[TIdx].Fields[K].Offset));
          EmitInstr('POP DWORD PTR [EAX]');
        End
        Else
        Begin
          { ident.field op= expr }
          ParseExpr;
          EmitInstr('MOV EBX,EAX');
          GenLoadAddr(Name);
          If TypeTab[TIdx].Fields[K].Offset > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(TypeTab[TIdx].Fields[K].Offset));
          EmitInstr('PUSH EAX');
          EmitInstr('MOV EAX,DWORD PTR [EAX]');
          EmitCompoundOp(Op);
          EmitInstr('POP ECX');
          EmitInstr('MOV DWORD PTR [ECX],EAX');
        End;
        { Avancer au ; }
        While (EP < EPEnd) And
              Not ((TokenPool[EP].Kind = TK_PUNCT) And
                   (TokenPool[EP].Val = ';')) Do
          Inc(EP);
        If EP < EPEnd Then Inc(EP);
        Exit;
      End;
    End;
  End;

  { Cas special : affectation via ptr->field = expr (TODO 19) }
  If (TokenPool[EP].Kind = TK_IDENT) And (EP + 2 < EPEnd) And
     (TokenPool[EP + 1].Kind = TK_OP) And (TokenPool[EP + 1].Val = '->') And
     (TokenPool[EP + 2].Kind = TK_IDENT) Then
  Begin
    Name := TokenPool[EP].Val;
    TIdx := VarTypeIdx(Name);
    { Dereferencer le type pointeur pour obtenir le type struct }
    If (TIdx >= 0) And (TIdx < TypeCount) And
       (TypeTab[TIdx].Kind = TKP_POINTER) Then
      TIdx := TypeTab[TIdx].BaseTypeIdx;
    If (TIdx >= 0) And (TIdx < TypeCount) And
       (TypeTab[TIdx].Kind In [TKP_STRUCT, TKP_UNION]) Then
    Begin
      K := StructFieldFind(TIdx, TokenPool[EP + 2].Val);
      If (K >= 0) And (EP + 3 < EPEnd) And
         (TokenPool[EP + 3].Kind = TK_OP) And
         IsAssignOp(TokenPool[EP + 3].Val) Then
      Begin
        Op := TokenPool[EP + 3].Val;
        Inc(EP, 4); { sauter ident -> field op= }
        If Op = '=' Then
        Begin
          ParseExpr;
          EmitInstr('PUSH EAX');
          GenLoadVar(Name);  { EAX = pointeur }
          If TypeTab[TIdx].Fields[K].Offset > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(TypeTab[TIdx].Fields[K].Offset));
          EmitInstr('POP DWORD PTR [EAX]');
        End
        Else
        Begin
          ParseExpr;
          EmitInstr('MOV EBX,EAX');
          GenLoadVar(Name);
          If TypeTab[TIdx].Fields[K].Offset > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(TypeTab[TIdx].Fields[K].Offset));
          EmitInstr('PUSH EAX');
          EmitInstr('MOV EAX,DWORD PTR [EAX]');
          EmitCompoundOp(Op);
          EmitInstr('POP ECX');
          EmitInstr('MOV DWORD PTR [ECX],EAX');
        End;
        { Avancer au ; }
        While (EP < EPEnd) And
              Not ((TokenPool[EP].Kind = TK_PUNCT) And
                   (TokenPool[EP].Val = ';')) Do
          Inc(EP);
        If EP < EPEnd Then Inc(EP);
        Exit;
      End;
    End;
  End;

  { Expression statement generale }
  ParseExpr;

  { Avancer au ; }
  While (EP < EPEnd) And
        Not ((TokenPool[EP].Kind = TK_PUNCT) And
             (TokenPool[EP].Val = ';')) Do
    Inc(EP);
  If EP < EPEnd Then Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseBody : parser et emettre le code du corps d une fonction }
{ Initialise le contexte puis appelle ParseStmt en boucle.     }
{ ------------------------------------------------------------ }

Procedure ParseBody(FI : Integer);
Var
  OldFI : Integer;
  I, J  : Integer;
  Found : Boolean;
Begin
  OldFI      := CurFuncIdx;
  CurFuncIdx := FI;
  EP         := FuncTab[FI].BodyStart + 1;
  EPEnd      := FuncTab[FI].BodyEnd;

  { Generer un label de retour unique pour cette fonction }
  RetLbl    := LabelGen;
  LoopTop   := 0;
  SwitchTop := 0;
  GotoLblDefCount := 0;
  GotoLblUseCount := 0;

  While EP < EPEnd Do
    ParseStmt;

  { Verification des labels goto (TODO 22) }
  For I := 0 To GotoLblUseCount - 1 Do
  Begin
    Found := False;
    For J := 0 To GotoLblDefCount - 1 Do
    Begin
      If GotoLblUse[I] = GotoLblDef[J] Then
      Begin
        Found := True;
        Break;
      End;
    End;
    If Not Found Then
      EmitComment('WARNING: goto vers label non defini: ' + GotoLblUse[I]);
  End;

  { Label de retour de la fonction }
  EmitLabel(RetLbl);

  CurFuncIdx := OldFI;
End;

{ ============================================================ }
{ TODO 16 - FONCTIONS ET PROTOTYPES                            }
{ EmitExternFuncs emet les EXTRN pour les fonctions extern     }
{ utilisateur (declarations sans corps).                       }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ EmitExternFuncs : emettre EXTRN pour les fonctions extern    }
{ utilisateur declarees avec 'extern' et sans corps.           }
{ Parcourt FuncTab a la recherche de fonctions avec IsForward   }
{ et IsExternal dans SymTab.                                    }
{ ------------------------------------------------------------ }

Procedure EmitExternFuncs;
Var
  FI, SI : Integer;
  HasExtern : Boolean;
Begin
  HasExtern := False;
  For FI := 0 To FuncCount - 1 Do
  Begin
    If Not FuncTab[FI].IsForward Then Continue;
    SI := FuncTab[FI].SymIdx;
    If (SI >= 0) And SymTab[SI].IsExternal Then
    Begin
      If Not HasExtern Then
      Begin
        EmitComment('--- Imports utilisateur (extern) ---');
        HasExtern := True;
      End;
      EmitRaw('EXTRN _' + FuncTab[FI].Name + ':NEAR');
    End;
  End;
  If HasExtern Then
    EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitLateData : emettre les donnees ajoutees apres le         }
{ segment .DATA principal (chaines creees par printf, etc.)    }
{ ------------------------------------------------------------ }

Procedure EmitLateData;
Var
  I, J : Integer;
  S    : TString;
  C    : Char;
Begin
  If DataCount <= DataEmittedCount Then Exit;

  EmitBlankLine;
  EmitComment('--- Donnees supplementaires (TODO 21) ---');
  EmitRaw('.DATA');
  EmitBlankLine;

  For I := DataEmittedCount To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_STR:
      Begin
        S := '';
        J := 1;
        While J <= Length(DataTab[I].StrVal) Do
        Begin
          C := DataTab[I].StrVal[J];
          If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
          Begin
            If S <> '' Then
              S := S + ',';
            S := S + '''';
            While (J <= Length(DataTab[I].StrVal)) Do
            Begin
              C := DataTab[I].StrVal[J];
              If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
              Begin
                S := S + C;
                Inc(J);
              End
              Else
                Break;
            End;
            S := S + '''';
          End
          Else
          Begin
            If S <> '' Then
              S := S + ',';
            S := S + IntToStr_(Ord(C));
            Inc(J);
          End;
        End;
        If S = '' Then
          S := '0'
        Else
          S := S + ',0';
        EmitRaw(DataTab[I].LblName + '  DB ' + S);
      End;

      DK_DWORD:
        EmitRaw(DataTab[I].LblName + '  DD ' +
                IntToStr_(DataTab[I].IntVal));

      DK_BYTE:
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal));
    End;
  End;

  EmitBlankLine;
  EmitRaw('.CODE');
  EmitBlankLine;
  DataEmittedCount := DataCount;
End;

{ ------------------------------------------------------------ }
{ EmitRuntime : emettre les routines runtime _CCRT_*           }
{ Routines inline ASM pour printf/scanf/putchar/getchar/puts   }
{ ------------------------------------------------------------ }

Procedure EmitRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime I/O (TODO 21) ===');
  EmitBlankLine;

  { _CCRT_PRINTSTR : ESI = pointeur vers chaine ASCIIZ }
  EmitComment('--- _CCRT_PRINTSTR : afficher chaine ASCIIZ (ESI) ---');
  EmitLabel('_CCRT_PRINTSTR');
  EmitInstr('PUSHAD');
  EmitInstr('MOV EDI,ESI');
  EmitInstr('XOR ECX,ECX');
  EmitLabel('_CCRT_PS_LEN');
  EmitInstr('CMP BYTE PTR [EDI],0');
  EmitInstr('JE _CCRT_PS_GO');
  EmitInstr('INC EDI');
  EmitInstr('INC ECX');
  EmitInstr('JMP _CCRT_PS_LEN');
  EmitLabel('_CCRT_PS_GO');
  EmitInstr('CMP ECX,0');
  EmitInstr('JE _CCRT_PS_END');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitLabel('_CCRT_PS_END');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PRINTINT : EAX = entier signe }
  EmitComment('--- _CCRT_PRINTINT : afficher entier signe (EAX) ---');
  EmitLabel('_CCRT_PRINTINT');
  EmitInstr('PUSHAD');
  EmitInstr('MOV ESI,EAX');
  EmitInstr('LEA EDI,[NUMBUF+15]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV EBX,10');
  EmitInstr('TEST ESI,ESI');
  EmitInstr('JNS _CCRT_PI_POS');
  EmitInstr('NEG ESI');
  EmitLabel('_CCRT_PI_POS');
  EmitInstr('MOV EAX,ESI');
  EmitLabel('_CCRT_PI_LOOP');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');
  EmitInstr('ADD DL,48');
  EmitInstr('DEC EDI');
  EmitInstr('MOV [EDI],DL');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ _CCRT_PI_LOOP');
  { Ajouter le signe negatif si necessaire }
  EmitInstr('MOV EAX,[ESP+28]'); { EAX original depuis PUSHAD }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNS _CCRT_PI_PRINT');
  EmitInstr('DEC EDI');
  EmitInstr('MOV BYTE PTR [EDI],45');
  EmitInstr('INC ECX');
  EmitLabel('_CCRT_PI_PRINT');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PRINTUINT : EAX = entier non signe }
  EmitComment('--- _CCRT_PRINTUINT : afficher entier non signe (EAX) ---');
  EmitLabel('_CCRT_PRINTUINT');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[NUMBUF+15]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV EBX,10');
  EmitLabel('_CCRT_PU_LOOP');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');
  EmitInstr('ADD DL,48');
  EmitInstr('DEC EDI');
  EmitInstr('MOV [EDI],DL');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ _CCRT_PU_LOOP');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PRINTHEX : EAX = entier en hexadecimal }
  EmitComment('--- _CCRT_PRINTHEX : afficher entier en hexa (EAX) ---');
  EmitLabel('_CCRT_PRINTHEX');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[NUMBUF+15]');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('MOV EBX,16');
  EmitLabel('_CCRT_PH_LOOP');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');
  EmitInstr('CMP DL,10');
  EmitInstr('JB _CCRT_PH_DIG');
  EmitInstr('ADD DL,87'); { 'a' - 10 = 87 }
  EmitInstr('JMP _CCRT_PH_STORE');
  EmitLabel('_CCRT_PH_DIG');
  EmitInstr('ADD DL,48');
  EmitLabel('_CCRT_PH_STORE');
  EmitInstr('DEC EDI');
  EmitInstr('MOV [EDI],DL');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ _CCRT_PH_LOOP');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PRINTCHAR : AL = caractere }
  EmitComment('--- _CCRT_PRINTCHAR : afficher un caractere (AL) ---');
  EmitLabel('_CCRT_PRINTCHAR');
  EmitInstr('PUSHAD');
  EmitInstr('MOV [NUMBUF],AL');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PRINTCRLF : ecrire CR+LF }
  EmitComment('--- _CCRT_PRINTCRLF : afficher retour a la ligne ---');
  EmitLabel('_CCRT_PRINTCRLF');
  EmitInstr('PUSHAD');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESWR');
  EmitInstr('PUSH 2');
  EmitInstr('PUSH OFFSET CRLF');
  EmitInstr('PUSH [HSTDOUT]');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_READINT : lire un entier depuis stdin -> EAX }
  EmitComment('--- _CCRT_READINT : lire entier depuis stdin -> EAX ---');
  EmitLabel('_CCRT_READINT');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  { Lire une ligne dans INBUF }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESRD');
  EmitInstr('PUSH 255');
  EmitInstr('PUSH OFFSET INBUF');
  EmitInstr('PUSH [HSTDIN]');
  EmitInstr('CALL _ReadFile@20');
  { Convertir ASCII -> entier }
  EmitInstr('LEA ESI,[INBUF]');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('XOR ECX,ECX');
  EmitInstr('XOR EDX,EDX'); { signe : 0=positif }
  { Sauter les espaces }
  EmitLabel('_CCRT_RI_SKIP');
  EmitInstr('MOV CL,[ESI]');
  EmitInstr('CMP CL,32');
  EmitInstr('JE _CCRT_RI_SKIPN');
  EmitInstr('CMP CL,9');
  EmitInstr('JNE _CCRT_RI_SIGN');
  EmitLabel('_CCRT_RI_SKIPN');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_RI_SKIP');
  { Verifier le signe }
  EmitLabel('_CCRT_RI_SIGN');
  EmitInstr('CMP CL,45'); { '-' }
  EmitInstr('JNE _CCRT_RI_PLUS');
  EmitInstr('MOV EDX,1');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_RI_DLOOP');
  EmitLabel('_CCRT_RI_PLUS');
  EmitInstr('CMP CL,43'); { '+' }
  EmitInstr('JNE _CCRT_RI_DLOOP');
  EmitInstr('INC ESI');
  { Boucle de conversion }
  EmitLabel('_CCRT_RI_DLOOP');
  EmitInstr('MOVZX ECX,BYTE PTR [ESI]');
  EmitInstr('CMP ECX,48');
  EmitInstr('JB _CCRT_RI_DONE');
  EmitInstr('CMP ECX,57');
  EmitInstr('JA _CCRT_RI_DONE');
  EmitInstr('SUB ECX,48');
  EmitInstr('IMUL EAX,10');
  EmitInstr('ADD EAX,ECX');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_RI_DLOOP');
  EmitLabel('_CCRT_RI_DONE');
  EmitInstr('TEST EDX,EDX');
  EmitInstr('JZ _CCRT_RI_RET');
  EmitInstr('NEG EAX');
  EmitLabel('_CCRT_RI_RET');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_READSTR : EDI = buffer dest, lire une ligne }
  EmitComment('--- _CCRT_READSTR : lire chaine depuis stdin (EDI=buf) ---');
  EmitLabel('_CCRT_READSTR');
  EmitInstr('PUSHAD');
  { Lire dans INBUF }
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESRD');
  EmitInstr('PUSH 255');
  EmitInstr('PUSH OFFSET INBUF');
  EmitInstr('PUSH [HSTDIN]');
  EmitInstr('CALL _ReadFile@20');
  { Copier INBUF -> EDI sans CR/LF }
  EmitInstr('LEA ESI,[INBUF]');
  EmitInstr('MOV EDI,[ESP+4]'); { EDI original depuis PUSHAD }
  EmitLabel('_CCRT_RS_COPY');
  EmitInstr('LODSB');
  EmitInstr('CMP AL,13');
  EmitInstr('JE _CCRT_RS_END');
  EmitInstr('CMP AL,10');
  EmitInstr('JE _CCRT_RS_END');
  EmitInstr('CMP AL,0');
  EmitInstr('JE _CCRT_RS_END');
  EmitInstr('STOSB');
  EmitInstr('JMP _CCRT_RS_COPY');
  EmitLabel('_CCRT_RS_END');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_READCHAR : lire un caractere depuis stdin -> EAX }
  EmitComment('--- _CCRT_READCHAR : lire un caractere -> EAX ---');
  EmitLabel('_CCRT_READCHAR');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('MOV BYTE PTR [NUMBUF],0');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESRD');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH [HSTDIN]');
  EmitInstr('CALL _ReadFile@20');
  EmitInstr('MOVZX EAX,BYTE PTR [NUMBUF]');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');
  EmitBlankLine;

  EmitComment('=== Runtime supplementaire (TODO 24) ===');
  EmitBlankLine;

  { _CCRT_NUMTOSTR : EAX = entier signe, EDI = buffer dest -> ASCIIZ }
  EmitComment('--- _CCRT_NUMTOSTR : entier (EAX) -> ASCII (EDI=buf) ---');
  EmitLabel('_CCRT_NUMTOSTR');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,EDI');       { sauver debut du buffer }
  EmitInstr('MOV ECX,EAX');       { sauver la valeur }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNS _CCRT_NT_POS');
  EmitInstr('MOV BYTE PTR [EDI],45'); { '-' }
  EmitInstr('INC EDI');
  EmitInstr('NEG EAX');
  EmitLabel('_CCRT_NT_POS');
  { Ecrire les chiffres dans l ordre inverse via la pile }
  EmitInstr('XOR ECX,ECX');       { compteur de chiffres }
  EmitInstr('MOV EBX,10');
  EmitLabel('_CCRT_NT_PUSH');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');
  EmitInstr('ADD DL,48');
  EmitInstr('PUSH EDX');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ _CCRT_NT_PUSH');
  { Depiler dans l ordre correct }
  EmitLabel('_CCRT_NT_POP');
  EmitInstr('POP EAX');
  EmitInstr('MOV [EDI],AL');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ _CCRT_NT_POP');
  EmitInstr('MOV BYTE PTR [EDI],0'); { terminateur nul }
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_STRTONUM : ESI = chaine ASCIIZ -> EAX = entier (atoi) }
  EmitComment('--- _CCRT_STRTONUM : ASCII (ESI) -> entier (EAX) ---');
  EmitLabel('_CCRT_STRTONUM');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('XOR EDX,EDX');       { signe : 0=positif }
  { Sauter les espaces }
  EmitLabel('_CCRT_SN_SKIP');
  EmitInstr('MOV CL,[ESI]');
  EmitInstr('CMP CL,32');
  EmitInstr('JE _CCRT_SN_SKIPN');
  EmitInstr('CMP CL,9');
  EmitInstr('JNE _CCRT_SN_SIGN');
  EmitLabel('_CCRT_SN_SKIPN');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_SN_SKIP');
  { Verifier le signe }
  EmitLabel('_CCRT_SN_SIGN');
  EmitInstr('CMP CL,45');         { '-' }
  EmitInstr('JNE _CCRT_SN_PLUS');
  EmitInstr('MOV EDX,1');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_SN_LOOP');
  EmitLabel('_CCRT_SN_PLUS');
  EmitInstr('CMP CL,43');         { '+' }
  EmitInstr('JNE _CCRT_SN_LOOP');
  EmitInstr('INC ESI');
  { Boucle de conversion }
  EmitLabel('_CCRT_SN_LOOP');
  EmitInstr('MOVZX ECX,BYTE PTR [ESI]');
  EmitInstr('CMP ECX,48');
  EmitInstr('JB _CCRT_SN_DONE');
  EmitInstr('CMP ECX,57');
  EmitInstr('JA _CCRT_SN_DONE');
  EmitInstr('SUB ECX,48');
  EmitInstr('IMUL EAX,10');
  EmitInstr('ADD EAX,ECX');
  EmitInstr('INC ESI');
  EmitInstr('JMP _CCRT_SN_LOOP');
  EmitLabel('_CCRT_SN_DONE');
  EmitInstr('TEST EDX,EDX');
  EmitInstr('JZ _CCRT_SN_RET');
  EmitInstr('NEG EAX');
  EmitLabel('_CCRT_SN_RET');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_STRLEN : ESI = chaine ASCIIZ -> EAX = longueur }
  EmitComment('--- _CCRT_STRLEN : longueur ASCIIZ (ESI) -> EAX ---');
  EmitLabel('_CCRT_STRLEN');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV EDI,ESI');
  EmitInstr('XOR EAX,EAX');
  EmitLabel('_CCRT_SL_LOOP');
  EmitInstr('CMP BYTE PTR [EDI],0');
  EmitInstr('JE _CCRT_SL_DONE');
  EmitInstr('INC EDI');
  EmitInstr('INC EAX');
  EmitInstr('JMP _CCRT_SL_LOOP');
  EmitLabel('_CCRT_SL_DONE');
  EmitInstr('POP EDI');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_STRCMP : ESI = s1, EDI = s2 -> drapeaux (ZF si egal) }
  EmitComment('--- _CCRT_STRCMP : comparer (ESI) et (EDI) -> drapeaux ---');
  EmitLabel('_CCRT_STRCMP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel('_CCRT_SC_LOOP');
  EmitInstr('MOV AL,[ESI]');
  EmitInstr('MOV AH,[EDI]');
  EmitInstr('CMP AL,AH');
  EmitInstr('JNE _CCRT_SC_DONE');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ _CCRT_SC_DONE');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP _CCRT_SC_LOOP');
  EmitLabel('_CCRT_SC_DONE');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_STRCPY : ESI = src, EDI = dst -> copie chaine }
  EmitComment('--- _CCRT_STRCPY : copier (ESI) -> (EDI) ---');
  EmitLabel('_CCRT_STRCPY');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel('_CCRT_SCP_LOOP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ _CCRT_SCP_LOOP');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_STRCAT : ESI = s1, EDI = s2 -> EAX = ptr concat (INBUF) }
  EmitComment('--- _CCRT_STRCAT : concatener (ESI)+(EDI) -> EAX=INBUF ---');
  EmitLabel('_CCRT_STRCAT');
  EmitInstr('PUSHAD');
  { Copier s1 dans INBUF }
  EmitInstr('LEA EDI,[INBUF]');
  EmitInstr('MOV EBX,[ESP+4]');   { EDI original = s2 }
  EmitLabel('_CCRT_CAT_CP1');
  EmitInstr('LODSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ _CCRT_CAT_S2');
  EmitInstr('STOSB');
  EmitInstr('JMP _CCRT_CAT_CP1');
  { Copier s2 apres }
  EmitLabel('_CCRT_CAT_S2');
  EmitInstr('MOV ESI,EBX');
  EmitLabel('_CCRT_CAT_CP2');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ _CCRT_CAT_CP2');
  EmitInstr('POPAD');
  EmitInstr('LEA EAX,[INBUF]');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_READLN : consommer stdin jusqu au prochain CR+LF }
  EmitComment('--- _CCRT_READLN : consommer jusqu a CR+LF ---');
  EmitLabel('_CCRT_READLN');
  EmitInstr('PUSHAD');
  EmitLabel('_CCRT_RL_LOOP');
  EmitInstr('PUSH 0');
  EmitInstr('PUSH OFFSET BYTESRD');
  EmitInstr('PUSH 1');
  EmitInstr('PUSH OFFSET NUMBUF');
  EmitInstr('PUSH [HSTDIN]');
  EmitInstr('CALL _ReadFile@20');
  EmitInstr('CMP DWORD PTR [BYTESRD],0');
  EmitInstr('JE _CCRT_RL_END');
  EmitInstr('CMP BYTE PTR [NUMBUF],10');
  EmitInstr('JE _CCRT_RL_END');
  EmitInstr('JMP _CCRT_RL_LOOP');
  EmitLabel('_CCRT_RL_END');
  EmitInstr('POPAD');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_MALLOC : EAX = taille -> EAX = pointeur (HeapAlloc) }
  EmitComment('--- _CCRT_MALLOC : allouer EAX octets -> EAX=ptr ---');
  EmitLabel('_CCRT_MALLOC');
  EmitInstr('PUSH EAX');          { taille }
  EmitInstr('PUSH 8');            { HEAP_ZERO_MEMORY = 0x08 }
  EmitInstr('PUSH [HHEAP]');
  EmitInstr('CALL _HeapAlloc@12');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_FREE : EAX = pointeur -> HeapFree }
  EmitComment('--- _CCRT_FREE : liberer (EAX) ---');
  EmitLabel('_CCRT_FREE');
  EmitInstr('PUSH EAX');          { pointeur }
  EmitInstr('PUSH 0');            { flags }
  EmitInstr('PUSH [HHEAP]');
  EmitInstr('CALL _HeapFree@12');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_MEMCPY : ESI = src, EDI = dst, ECX = len }
  EmitComment('--- _CCRT_MEMCPY : copier ECX octets (ESI)->(EDI) ---');
  EmitLabel('_CCRT_MEMCPY');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH ECX');
  EmitInstr('REP MOVSB');
  EmitInstr('POP ECX');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_MEMSET : EDI = dst, EAX = val (byte), ECX = len }
  EmitComment('--- _CCRT_MEMSET : remplir ECX octets (EDI) avec AL ---');
  EmitLabel('_CCRT_MEMSET');
  EmitInstr('PUSH EDI');
  EmitInstr('PUSH ECX');
  EmitInstr('REP STOSB');
  EmitInstr('POP ECX');
  EmitInstr('POP EDI');
  EmitInstr('RET');
  EmitBlankLine;

  { _CCRT_PANIC : ESI = message -> affiche + ExitProcess(1) }
  EmitComment('--- _CCRT_PANIC : afficher ESI + ExitProcess(1) ---');
  EmitLabel('_CCRT_PANIC');
  EmitInstr('CALL _CCRT_PRINTSTR');
  EmitInstr('CALL _CCRT_PRINTCRLF');
  EmitInstr('PUSH 1');
  EmitInstr('CALL _ExitProcess@4');
  EmitBlankLine;

  EmitComment('=== Fin Runtime (TODO 24) ===');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitFunctions : emettre le code ASM pour toutes les fonctions}
{ ------------------------------------------------------------ }

Procedure EmitFunctions;
Var
  FI, LI  : Integer;
  OfsStr  : TString;
Begin
  For FI := 0 To FuncCount - 1 Do
  Begin
    If FuncTab[FI].IsForward Then Continue;

    EmitComment('--- Fonction: ' + FuncTab[FI].Name + ' ---');
    EmitLabel(FuncTab[FI].MangledName);
    EmitProlog(FuncTab[FI].LocalSize);

    { Commentaires descriptifs pour les parametres }
    For LI := 0 To FuncTab[FI].ParamCount - 1 Do
    Begin
      EmitComment('  param ' + FuncTab[FI].ParamNames[LI] +
                  ' = [EBP+' + IntToStr_(FuncTab[FI].ParamOfs[LI]) + ']');
    End;

    { Commentaires descriptifs et initialisation des variables locales }
    For LI := 0 To FuncTab[FI].LocalCount - 1 Do
    Begin
      If FuncTab[FI].Locals[LI].IsStatic Then
      Begin
        EmitComment('  static ' + FuncTab[FI].Locals[LI].Name +
                    ' = [' + FuncTab[FI].Locals[LI].StaticLbl + ']');
      End
      Else
      Begin
        OfsStr := IntToStr_(FuncTab[FI].Locals[LI].Offset);
        EmitComment('  local ' + FuncTab[FI].Locals[LI].Name +
                    ' = [EBP' + OfsStr + ']');
        { Emettre l initialisation si necessaire }
        If FuncTab[FI].Locals[LI].HasInit Then
        Begin
          EmitInstr('MOV DWORD PTR [EBP' + OfsStr + '],' +
                    IntToStr_(FuncTab[FI].Locals[LI].InitVal));
        End;
      End;
    End;

    { Emettre le corps de la fonction (TODO 10) }
    ParseBody(FI);

    EmitEpilog;
    EmitBlankLine;
  End;

  { --- Point d entree Win32 si main() existe --- }
  If HasMainFunc Then
  Begin
    EmitComment('--- Point d''entree Win32 ---');
    EmitLabel('_main');

    { Obtenir les handles standard }
    EmitInstr('PUSH -11');
    EmitInstr('CALL _GetStdHandle@4');
    EmitInstr('MOV DWORD PTR [HSTDOUT],EAX');

    EmitInstr('PUSH -10');
    EmitInstr('CALL _GetStdHandle@4');
    EmitInstr('MOV DWORD PTR [HSTDIN],EAX');

    EmitInstr('CALL _GetProcessHeap@0');
    EmitInstr('MOV DWORD PTR [HHEAP],EAX');

    { Appeler main() }
    EmitInstr('CALL ' + CC_FUNC_PFX + 'main');

    { Quitter le processus }
    EmitInstr('PUSH 0');
    EmitInstr('CALL _ExitProcess@4');
    EmitBlankLine;
  End;
End;

{ ============================================================ }
{ TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES            }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ Binary emission helpers                                      }
{ ------------------------------------------------------------ }

Procedure BinInit;
Begin
  BinCodeLen := 0; BinDataLen := 0;
  BinLblCount := 0; BinFixCount := 0;
  BinInCode := True;
  FillChar(BinCode, SizeOf(BinCode), 0);
  FillChar(BinData, SizeOf(BinData), 0);
End;

Procedure BinCodeByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin BinCode[BinCodeLen] := B; Inc(BinCodeLen); End;
End;

Procedure BinCodeDWord(D : LongInt);
Begin
  BinCodeByte(Byte(D And $FF));
  BinCodeByte(Byte((D Shr 8) And $FF));
  BinCodeByte(Byte((D Shr 16) And $FF));
  BinCodeByte(Byte((D Shr 24) And $FF));
End;

Procedure BinCodeWord(W : Word);
Begin BinCodeByte(Lo(W)); BinCodeByte(Hi(W)); End;

Procedure BinDataByte(B : Byte);
Begin
  If BinDataLen < MAX_BIN_DATA Then
  Begin BinData[BinDataLen] := B; Inc(BinDataLen); End;
End;

Procedure BinDataDWord(D : LongInt);
Begin
  BinDataByte(Byte(D And $FF));
  BinDataByte(Byte((D Shr 8) And $FF));
  BinDataByte(Byte((D Shr 16) And $FF));
  BinDataByte(Byte((D Shr 24) And $FF));
End;

{ ------------------------------------------------------------ }
{ Label and fixup management                                   }
{ ------------------------------------------------------------ }

Procedure BinAddLabel(Const Name : TString; IsCode : Boolean; Ofs : LongInt);
Begin
  If BinLblCount < MAX_BIN_LBL Then
  Begin
    BinLabels[BinLblCount].Name := StrUpperCase(Name);
    BinLabels[BinLblCount].Offset := Ofs;
    BinLabels[BinLblCount].InCode := IsCode;
    Inc(BinLblCount);
  End;
End;

Function BinFindLabel(Const Name : TString) : Integer;
Var I : Integer; U : TString;
Begin
  U := StrUpperCase(Name);
  BinFindLabel := -1;
  For I := BinLblCount - 1 DownTo 0 Do
    If BinLabels[I].Name = U Then Begin BinFindLabel := I; Exit; End;
End;

Procedure BinAddFixup(Ofs : LongInt; Kind : TBinFixKind;
                      Const Target : TString; IsCode : Boolean);
Begin
  If BinFixCount < MAX_BIN_FIX Then
  Begin
    BinFixups[BinFixCount].Offset := Ofs;
    BinFixups[BinFixCount].Kind := Kind;
    BinFixups[BinFixCount].Target := StrUpperCase(Target);
    BinFixups[BinFixCount].InCode := IsCode;
    Inc(BinFixCount);
  End;
End;

Function BinIsExtern(Const Name : TString) : Integer;
Var I : Integer; U : TString;
Begin
  U := StrUpperCase(Name);
  BinIsExtern := -1;
  For I := 0 To PE_NUM_API - 1 Do
    If StrUpperCase(BinAPIDecorated[I]) = U Then
    Begin BinIsExtern := I; Exit; End;
End;

{ ------------------------------------------------------------ }
{ Register mapping and parsing helpers                         }
{ ------------------------------------------------------------ }

Function BinReg32(Const S : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(S);
  If U = 'EAX' Then BinReg32 := 0
  Else If U = 'ECX' Then BinReg32 := 1
  Else If U = 'EDX' Then BinReg32 := 2
  Else If U = 'EBX' Then BinReg32 := 3
  Else If U = 'ESP' Then BinReg32 := 4
  Else If U = 'EBP' Then BinReg32 := 5
  Else If U = 'ESI' Then BinReg32 := 6
  Else If U = 'EDI' Then BinReg32 := 7
  Else BinReg32 := -1;
End;

Function BinReg8(Const S : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(S);
  If U = 'AL' Then BinReg8 := 0
  Else If U = 'CL' Then BinReg8 := 1
  Else If U = 'DL' Then BinReg8 := 2
  Else If U = 'BL' Then BinReg8 := 3
  Else If U = 'AH' Then BinReg8 := 4
  Else BinReg8 := -1;
End;

Function BinParseImm(Const S : TString) : LongInt;
Var V : LongInt; U : TString; Neg : Boolean; Code : Integer;
Begin
  U := S;
  While (Length(U) > 0) And (U[1] = ' ') Do Delete(U, 1, 1);
  While (Length(U) > 0) And (U[Length(U)] = ' ') Do Delete(U, Length(U), 1);
  Neg := False;
  If (Length(U) > 0) And (U[1] = '-') Then Begin Neg := True; Delete(U, 1, 1); End;
  V := 0;
  If (Length(U) >= 3) And (U[1] = Chr(39)) And (U[Length(U)] = Chr(39)) Then
    V := Ord(U[2])
  Else If (Length(U) > 1) And (UpCase(U[Length(U)]) = 'H') Then
  Begin Delete(U, Length(U), 1); System.Val('$' + U, V, Code); End
  Else If (Length(U) > 1) And (U[1] = '$') Then
    System.Val(U, V, Code)
  Else
    System.Val(U, V, Code);
  If Neg Then V := -V;
  BinParseImm := V;
End;

Function BinStripSize(Const S : TString; Var SzByte : Boolean) : TString;
Var U, R : TString;
Begin
  U := StrUpperCase(S); SzByte := False; R := S;
  If Pos('DWORD PTR', U) = 1 Then R := Copy(S, 10, Length(S) - 9)
  Else If Pos('BYTE PTR', U) = 1 Then Begin R := Copy(S, 9, Length(S) - 8); SzByte := True; End
  Else If Pos('WORD PTR', U) = 1 Then R := Copy(S, 9, Length(S) - 8);
  While (Length(R) > 0) And (R[1] = ' ') Do Delete(R, 1, 1);
  BinStripSize := R;
End;

Function BinStripBrackets(Const S : TString) : TString;
Var R : TString;
Begin
  R := S;
  While (Length(R) > 0) And (R[1] = ' ') Do Delete(R, 1, 1);
  If (Length(R) >= 2) And (R[1] = '[') And (R[Length(R)] = ']') Then
    R := Copy(R, 2, Length(R) - 2);
  BinStripBrackets := R;
End;

Function BinParseEBPOfs(Const S : TString; Var Ofs : LongInt) : Boolean;
Var Inner : TString; P, Code : Integer;
Begin
  Inner := BinStripBrackets(S);
  BinParseEBPOfs := False;
  If Pos('EBP', StrUpperCase(Inner)) <> 1 Then Exit;
  P := Pos('+', Inner);
  If P > 0 Then
  Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); BinParseEBPOfs := True; End
  Else Begin
    P := Pos('-', Inner);
    If P > 0 Then
    Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); Ofs := -Ofs; BinParseEBPOfs := True; End
    Else Begin Ofs := 0; BinParseEBPOfs := True; End;
  End;
End;

Function BinJccOpcode(Const Cond : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(Cond); BinJccOpcode := -1;
  If (U='JE') Or (U='JZ') Then BinJccOpcode := $84
  Else If (U='JNE') Or (U='JNZ') Then BinJccOpcode := $85
  Else If (U='JB') Or (U='JC') Or (U='JNAE') Then BinJccOpcode := $82
  Else If (U='JAE') Or (U='JNB') Or (U='JNC') Then BinJccOpcode := $83
  Else If (U='JBE') Or (U='JNA') Then BinJccOpcode := $86
  Else If (U='JA') Or (U='JNBE') Then BinJccOpcode := $87
  Else If (U='JS') Then BinJccOpcode := $88
  Else If (U='JNS') Then BinJccOpcode := $89
  Else If (U='JP') Or (U='JPE') Then BinJccOpcode := $8A
  Else If (U='JNP') Or (U='JPO') Then BinJccOpcode := $8B
  Else If (U='JL') Or (U='JNGE') Then BinJccOpcode := $8C
  Else If (U='JGE') Or (U='JNL') Then BinJccOpcode := $8D
  Else If (U='JLE') Or (U='JNG') Then BinJccOpcode := $8E
  Else If (U='JG') Or (U='JNLE') Then BinJccOpcode := $8F;
End;

Function BinModRM(Mo, Reg, RM : Integer) : Byte;
Begin BinModRM := Byte((Mo Shl 6) Or ((Reg And 7) Shl 3) Or (RM And 7)); End;

{ ------------------------------------------------------------ }
{ Memory operand emission helpers                              }
{ ------------------------------------------------------------ }

Procedure BinEmitMemRef(RegField : Integer; Const LabelName : TString);
Var PP : Integer; Lbl, OStr : TString; Ofs : LongInt;
Begin
  BinCodeByte(BinModRM(0, RegField, 5));
  PP := Pos('+', LabelName);
  If PP > 0 Then
  Begin
    Lbl := Copy(LabelName, 1, PP - 1);
    While (Length(Lbl) > 0) And (Lbl[Length(Lbl)] = ' ') Do Delete(Lbl, Length(Lbl), 1);
    OStr := Copy(LabelName, PP + 1, Length(LabelName) - PP);
    While (Length(OStr) > 0) And (OStr[1] = ' ') Do Delete(OStr, 1, 1);
    Ofs := BinParseImm(OStr);
    BinAddFixup(BinCodeLen, BFK_ABS32, Lbl, True);
    BinCodeDWord(Ofs);
  End
  Else
  Begin
    PP := Pos('-', LabelName);
    If (PP > 1) Then
    Begin
      Lbl := Copy(LabelName, 1, PP - 1);
      While (Length(Lbl) > 0) And (Lbl[Length(Lbl)] = ' ') Do Delete(Lbl, Length(Lbl), 1);
      OStr := Copy(LabelName, PP + 1, Length(LabelName) - PP);
      While (Length(OStr) > 0) And (OStr[1] = ' ') Do Delete(OStr, 1, 1);
      Ofs := -BinParseImm(OStr);
      BinAddFixup(BinCodeLen, BFK_ABS32, Lbl, True);
      BinCodeDWord(Ofs);
    End
    Else
    Begin
      BinAddFixup(BinCodeLen, BFK_ABS32, LabelName, True);
      BinCodeDWord(0);
    End;
  End;
End;

Procedure BinEmitEBPRef(RegField : Integer; Ofs : LongInt);
Begin
  If (Ofs >= -128) And (Ofs <= 127) Then
  Begin BinCodeByte(BinModRM(1, RegField, 5)); BinCodeByte(Byte(Ofs And $FF)); End
  Else
  Begin BinCodeByte(BinModRM(2, RegField, 5)); BinCodeDWord(Ofs); End;
End;

Procedure BinEmitESPRef(RegField : Integer; Ofs : LongInt);
Begin
  If Ofs = 0 Then
  Begin BinCodeByte(BinModRM(0, RegField, 4)); BinCodeByte($24); End
  Else If (Ofs >= -128) And (Ofs <= 127) Then
  Begin BinCodeByte(BinModRM(1, RegField, 4)); BinCodeByte($24); BinCodeByte(Byte(Ofs And $FF)); End
  Else
  Begin BinCodeByte(BinModRM(2, RegField, 4)); BinCodeByte($24); BinCodeDWord(Ofs); End;
End;

Function BinParseESPOfs(Const S : TString; Var Ofs : LongInt) : Boolean;
Var Inner : TString; P, Code : Integer;
Begin
  Inner := BinStripBrackets(S);
  BinParseESPOfs := False;
  If Pos('ESP', StrUpperCase(Inner)) <> 1 Then Exit;
  P := Pos('+', Inner);
  If P > 0 Then
  Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); BinParseESPOfs := True; End
  Else Begin
    P := Pos('-', Inner);
    If P > 0 Then
    Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); Ofs := -Ofs; BinParseESPOfs := True; End
    Else Begin Ofs := 0; BinParseESPOfs := True; End;
  End;
End;

Procedure BinEmitRegIndirect(RegField, BaseReg : Integer);
Begin
  If BaseReg = 4 Then Begin BinCodeByte(BinModRM(0, RegField, 4)); BinCodeByte($24); End
  Else If BaseReg = 5 Then Begin BinCodeByte(BinModRM(1, RegField, 5)); BinCodeByte(0); End
  Else BinCodeByte(BinModRM(0, RegField, BaseReg));
End;

Procedure BinEmitMemOp(RegField : Integer; Const Inner : TString);
Var RBase, RIdx, PP : Integer; Tmp : TString; EbpOfs, Imm : LongInt;
Begin
  If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then
  Begin BinEmitEBPRef(RegField, EbpOfs); Exit; End;
  If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then
  Begin BinEmitESPRef(RegField, EbpOfs); Exit; End;
  RBase := BinReg32(Inner);
  If RBase >= 0 Then
  Begin BinEmitRegIndirect(RegField, RBase); Exit; End;
  PP := Pos('+', Inner);
  If PP > 0 Then
  Begin
    Tmp := Copy(Inner, 1, PP - 1);
    While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
    RBase := BinReg32(Tmp);
    If RBase >= 0 Then
    Begin
      Tmp := Copy(Inner, PP + 1, Length(Inner) - PP);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      RIdx := BinReg32(Tmp);
      If RIdx >= 0 Then
      Begin
        BinCodeByte(BinModRM(0, RegField, 4));
        BinCodeByte(Byte((RIdx Shl 3) Or RBase));
        Exit;
      End;
      { reg+imm : registre de base + deplacement immediat }
      Imm := BinParseImm(Tmp);
      If RBase = 4 Then { ESP a besoin du SIB }
        BinEmitESPRef(RegField, Imm)
      Else Begin
        If (Imm >= -128) And (Imm <= 127) Then
        Begin BinCodeByte(BinModRM(1, RegField, RBase)); BinCodeByte(Byte(Imm And $FF)); End
        Else Begin BinCodeByte(BinModRM(2, RegField, RBase)); BinCodeDWord(Imm); End;
      End;
      Exit;
    End;
  End;
  BinEmitMemRef(RegField, Inner);
End;

{ ------------------------------------------------------------ }
{ BinAssembleLine : mini-assembleur ASM x86-32 -> binaire      }
{ ------------------------------------------------------------ }

Procedure BinAssembleLine(Const Line : String);
Var
  S, Mnem, Op1, Op2, Inner, Tmp : TString;
  I, P, R1, R2, R8, ApiIdx : Integer;
  Imm, EbpOfs : LongInt;
  IsByte, HasOp2 : Boolean;
  BrkDepth : Integer;
Begin
  S := Line;
  While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
  While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
  If Length(S) = 0 Then Exit;
  If S[1] = ';' Then Exit;

  { Label }
  If (Length(S) >= 2) And (S[Length(S)] = ':') And (S[1] <> '.') Then
  Begin
    Tmp := Copy(S, 1, Length(S) - 1);
    While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
    If BinInCode Then BinAddLabel(Tmp, True, BinCodeLen)
    Else BinAddLabel(Tmp, False, BinDataLen);
    Exit;
  End;

  { .DATA / .CODE switching - doit etre traite AVANT les autres directives }
  If StrUpperCase(S) = '.DATA' Then Begin BinInCode := False; Exit; End;
  If StrUpperCase(S) = '.CODE' Then Begin BinInCode := True; Exit; End;

  { Directives }
  If S[1] = '.' Then Exit;
  If Pos('EXTRN', StrUpperCase(S)) > 0 Then Exit;
  If Pos('OPTION', StrUpperCase(S)) > 0 Then Exit;
  If Pos('END ', StrUpperCase(S)) = 1 Then Exit;
  If StrUpperCase(S) = 'END' Then Exit;

  { Data segment declarations }
  If Not BinInCode Then
  Begin
    P := Pos(' DD ', StrUpperCase(S));
    If P = 0 Then P := Pos(' DB ', StrUpperCase(S));
    If P > 0 Then
    Begin
      Tmp := Copy(S, 1, P - 1);
      While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
      BinAddLabel(Tmp, False, BinDataLen);
      Tmp := Copy(S, P + 1, Length(S) - P);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    End
    Else If (Pos('DB', StrUpperCase(S)) = 1) Or (Pos('DD', StrUpperCase(S)) = 1) Then
      Tmp := S
    Else Exit;
    If Pos('DD', StrUpperCase(Tmp)) = 1 Then
    Begin
      Delete(Tmp, 1, 2);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      If Pos('OFFSET', StrUpperCase(Tmp)) = 1 Then
      Begin
        Delete(Tmp, 1, 6);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        BinAddFixup(BinDataLen, BFK_ABS32, Tmp, False);
        BinDataDWord(0);
      End
      Else If Pos('DUP', StrUpperCase(Tmp)) > 0 Then
      Begin
        P := Pos(' ', Tmp);
        If P > 0 Then Imm := BinParseImm(Copy(Tmp, 1, P - 1))
        Else Imm := BinParseImm(Tmp);
        For I := 1 To Imm Do BinDataDWord(0);
      End
      Else BinDataDWord(BinParseImm(Tmp));
    End
    Else If Pos('DB', StrUpperCase(Tmp)) = 1 Then
    Begin
      Delete(Tmp, 1, 2);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      If Pos('DUP', StrUpperCase(Tmp)) > 0 Then
      Begin
        P := Pos(' ', Tmp);
        If P > 0 Then Imm := BinParseImm(Copy(Tmp, 1, P - 1))
        Else Imm := BinParseImm(Tmp);
        For I := 1 To Imm Do BinDataByte(0);
      End
      Else If (Length(Tmp) > 0) And (Tmp[1] = Chr(39)) Then
      Begin
        Delete(Tmp, 1, 1); I := 1;
        While I <= Length(Tmp) Do
        Begin
          If Tmp[I] = Chr(39) Then
          Begin
            If (I < Length(Tmp)) And (Tmp[I + 1] = Chr(39)) Then
            Begin BinDataByte(Ord(Chr(39))); Inc(I, 2); End
            Else Begin Inc(I); Break; End;
          End
          Else Begin BinDataByte(Ord(Tmp[I])); Inc(I); End;
        End;
        Inner := Copy(Tmp, I, Length(Tmp) - I + 1);
        If Pos(',0', Inner) > 0 Then BinDataByte(0);
      End
      Else
      Begin
        While Length(Tmp) > 0 Do
        Begin
          P := Pos(',', Tmp);
          If P > 0 Then
          Begin BinDataByte(Byte(BinParseImm(Copy(Tmp, 1, P - 1)))); Delete(Tmp, 1, P); End
          Else Begin BinDataByte(Byte(BinParseImm(Tmp))); Tmp := ''; End;
        End;
      End;
    End;
    Exit;
  End;

  { Parse mnemonic and operands }
  P := 0;
  For I := 1 To Length(S) Do
    If (S[I] = ' ') Or (S[I] = #9) Then Begin P := I; Break; End;
  If P = 0 Then Begin Mnem := StrUpperCase(S); Op1 := ''; Op2 := ''; HasOp2 := False; End
  Else
  Begin
    Mnem := StrUpperCase(Copy(S, 1, P - 1));
    Tmp := Copy(S, P + 1, Length(S) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    HasOp2 := False; P := 0; BrkDepth := 0;
    For I := 1 To Length(Tmp) Do
    Begin
      If Tmp[I] = '[' Then Inc(BrkDepth)
      Else If Tmp[I] = ']' Then Dec(BrkDepth)
      Else If (Tmp[I] = ',') And (BrkDepth = 0) Then Begin P := I; Break; End;
    End;
    If P > 0 Then
    Begin
      Op1 := Copy(Tmp, 1, P - 1); Op2 := Copy(Tmp, P + 1, Length(Tmp) - P);
      While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do Delete(Op1, Length(Op1), 1);
      While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
      HasOp2 := True;
    End
    Else Begin Op1 := Tmp; Op2 := ''; End;
  End;

  { RET }
  If Mnem = 'RET' Then
  Begin
    If Length(Op1) > 0 Then Begin BinCodeByte($C2); BinCodeWord(Word(BinParseImm(Op1))); End
    Else BinCodeByte($C3);
    Exit;
  End;
  If Mnem = 'CDQ' Then Begin BinCodeByte($99); Exit; End;
  If Mnem = 'NOP' Then Begin BinCodeByte($90); Exit; End;
  If Mnem = 'PUSHAD' Then Begin BinCodeByte($60); Exit; End;
  If Mnem = 'POPAD' Then Begin BinCodeByte($61); Exit; End;
  If Mnem = 'REP' Then
  Begin
    If StrUpperCase(Op1) = 'MOVSB' Then Begin BinCodeByte($F3); BinCodeByte($A4); End
    Else If StrUpperCase(Op1) = 'STOSB' Then Begin BinCodeByte($F3); BinCodeByte($AA); End;
    Exit;
  End;
  If Mnem = 'REPNE' Then
  Begin
    If StrUpperCase(Op1) = 'SCASB' Then Begin BinCodeByte($F2); BinCodeByte($AE); End;
    Exit;
  End;

  { PUSH }
  If Mnem = 'PUSH' Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then Begin BinCodeByte($50 + R1); Exit; End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemOp(6, Inner); Exit; End;
    If Pos('OFFSET', StrUpperCase(Op1)) = 1 Then
    Begin
      Tmp := Copy(Op1, 7, Length(Op1) - 6);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      BinCodeByte($68); BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0);
      Exit;
    End;
    Imm := BinParseImm(Op1);
    If (Imm >= -128) And (Imm <= 127) Then
    Begin BinCodeByte($6A); BinCodeByte(Byte(Imm And $FF)); End
    Else Begin BinCodeByte($68); BinCodeDWord(Imm); End;
    Exit;
  End;

  { POP }
  If Mnem = 'POP' Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then Begin BinCodeByte($58 + R1); Exit; End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($8F); BinEmitMemOp(0, Inner); End;
    Exit;
  End;

  { INC / DEC }
  If (Mnem = 'INC') Or (Mnem = 'DEC') Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin If Mnem = 'INC' Then BinCodeByte($40 + R1) Else BinCodeByte($48 + R1); Exit; End;
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      BinCodeByte($FE);
      If Mnem = 'INC' Then BinCodeByte(BinModRM(3, 0, R8)) Else BinCodeByte(BinModRM(3, 1, R8));
      Exit;
    End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      If IsByte Then BinCodeByte($FE) Else BinCodeByte($FF);
      If Mnem = 'INC' Then R1 := 0 Else R1 := 1;
      BinEmitMemOp(R1, Inner);
    End;
    Exit;
  End;

  { NEG / NOT / DIV / IDIV }
  If (Mnem = 'NEG') Or (Mnem = 'NOT') Or (Mnem = 'DIV') Or (Mnem = 'IDIV') Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin
      BinCodeByte($F7);
      If Mnem = 'NEG' Then BinCodeByte(BinModRM(3, 3, R1))
      Else If Mnem = 'NOT' Then BinCodeByte(BinModRM(3, 2, R1))
      Else If Mnem = 'DIV' Then BinCodeByte(BinModRM(3, 6, R1))
      Else BinCodeByte(BinModRM(3, 7, R1));
    End;
    Exit;
  End;

  { CALL }
  If Mnem = 'CALL' Then
  Begin
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemRef(2, Inner); Exit; End;
    ApiIdx := BinIsExtern(Op1);
    If ApiIdx >= 0 Then
    Begin BinCodeByte($FF); BinCodeByte($15); BinAddFixup(BinCodeLen, BFK_IAT32, Op1, True); BinCodeDWord(0); Exit; End;
    BinCodeByte($E8); BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { JMP }
  If Mnem = 'JMP' Then
  Begin
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemRef(4, Inner); Exit; End;
    BinCodeByte($E9); BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { Jcc }
  R1 := BinJccOpcode(Mnem);
  If R1 >= 0 Then
  Begin
    BinCodeByte($0F); BinCodeByte(Byte(R1));
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { SETE / SETNE / SETL / SETG / SETLE / SETGE / SETB / SETA / SETBE / SETAE }
  If (Mnem = 'SETE') Or (Mnem = 'SETNE') Or (Mnem = 'SETL') Or
     (Mnem = 'SETG') Or (Mnem = 'SETLE') Or (Mnem = 'SETGE') Or
     (Mnem = 'SETB') Or (Mnem = 'SETA') Or (Mnem = 'SETBE') Or (Mnem = 'SETAE') Then
  Begin
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      BinCodeByte($0F);
      If Mnem = 'SETE' Then BinCodeByte($94)
      Else If Mnem = 'SETNE' Then BinCodeByte($95)
      Else If Mnem = 'SETL' Then BinCodeByte($9C)
      Else If Mnem = 'SETGE' Then BinCodeByte($9D)
      Else If Mnem = 'SETLE' Then BinCodeByte($9E)
      Else If Mnem = 'SETG' Then BinCodeByte($9F)
      Else If Mnem = 'SETB' Then BinCodeByte($92)
      Else If Mnem = 'SETAE' Then BinCodeByte($93)
      Else If Mnem = 'SETBE' Then BinCodeByte($96)
      Else If Mnem = 'SETA' Then BinCodeByte($97);
      BinCodeByte(BinModRM(3, 0, R8));
    End;
    Exit;
  End;

  { TEST }
  If Mnem = 'TEST' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin BinCodeByte($85); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      Imm := BinParseImm(Op2);
      If R8 = 0 Then Begin BinCodeByte($A8); BinCodeByte(Byte(Imm And $FF)); End
      Else Begin BinCodeByte($F6); BinCodeByte(BinModRM(3, 0, R8)); BinCodeByte(Byte(Imm And $FF)); End;
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := BinParseImm(Op2);
      If R1 = 0 Then Begin BinCodeByte($A9); BinCodeDWord(Imm); End
      Else Begin BinCodeByte($F7); BinCodeByte(BinModRM(3, 0, R1)); BinCodeDWord(Imm); End;
    End;
    Exit;
  End;

  { MOVZX }
  If Mnem = 'MOVZX' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin
      R8 := BinReg8(Op2);
      If R8 >= 0 Then
      Begin BinCodeByte($0F); BinCodeByte($B6); BinCodeByte(BinModRM(3, R1, R8)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte($0F); BinCodeByte($B6);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then BinEmitRegIndirect(R1, R2)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R1, EbpOfs)
        Else BinEmitMemRef(R1, Inner);
      End;
    End;
    Exit;
  End;

  { LEA }
  If Mnem = 'LEA' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 < 0 Then Exit;
    If BinParseEBPOfs(Op2, EbpOfs) Then
    Begin BinCodeByte($8D); BinEmitEBPRef(R1, EbpOfs); Exit; End;
    Inner := BinStripBrackets(Op2);
    R2 := BinReg32(Inner);
    If R2 >= 0 Then Begin BinCodeByte($8D); BinEmitRegIndirect(R1, R2); Exit; End;
    P := Pos('+', Inner);
    If P > 0 Then
    Begin
      Tmp := Copy(Inner, 1, P - 1);
      While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
      R2 := BinReg32(Tmp);
      If R2 >= 0 Then
      Begin
        Tmp := Copy(Inner, P + 1, Length(Inner) - P);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        R8 := BinReg32(Tmp);
        If R8 >= 0 Then
        Begin BinCodeByte($8D); BinCodeByte(BinModRM(0, R1, 4)); BinCodeByte(Byte((R8 Shl 3) Or R2)); Exit; End;
        Imm := BinParseImm(Tmp);
        BinCodeByte($8D);
        If (Imm >= -128) And (Imm <= 127) Then
        Begin BinCodeByte(BinModRM(1, R1, R2)); BinCodeByte(Byte(Imm And $FF)); End
        Else Begin BinCodeByte(BinModRM(2, R1, R2)); BinCodeDWord(Imm); End;
        Exit;
      End;
    End;
    BinCodeByte($8D); BinEmitMemRef(R1, Inner);
    Exit;
  End;

  { SHL / SHR / SAR }
  If (Mnem = 'SHL') Or (Mnem = 'SHR') Or (Mnem = 'SAR') Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 < 0 Then Exit;
    If StrUpperCase(Op2) = 'CL' Then
    Begin
      BinCodeByte($D3);
      If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
      Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
      Else BinCodeByte(BinModRM(3, 7, R1));
    End
    Else
    Begin
      Imm := BinParseImm(Op2);
      If Imm = 1 Then
      Begin
        BinCodeByte($D1);
        If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
        Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
        Else BinCodeByte(BinModRM(3, 7, R1));
      End
      Else
      Begin
        BinCodeByte($C1);
        If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
        Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
        Else BinCodeByte(BinModRM(3, 7, R1));
        BinCodeByte(Byte(Imm And $FF));
      End;
    End;
    Exit;
  End;

  { IMUL }
  If Mnem = 'IMUL' Then
  Begin
    If Not HasOp2 Then
    Begin R1 := BinReg32(Op1); If R1 >= 0 Then Begin BinCodeByte($F7); BinCodeByte(BinModRM(3, 5, R1)); End; Exit; End;
    R1 := BinReg32(Op1); If R1 < 0 Then Exit;
    R2 := BinReg32(Op2);
    If R2 >= 0 Then Begin BinCodeByte($0F); BinCodeByte($AF); BinCodeByte(BinModRM(3, R1, R2)); Exit; End;
    Imm := BinParseImm(Op2);
    BinCodeByte($69); BinCodeByte(BinModRM(3, R1, R1)); BinCodeDWord(Imm);
    Exit;
  End;

  { MOV }
  If Mnem = 'MOV' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then Begin BinCodeByte($89); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    If (R1 >= 0) Then
    Begin
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then Begin BinCodeByte($8B); BinEmitRegIndirect(R1, R2); Exit; End;
        If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8B); BinEmitEBPRef(R1, EbpOfs); Exit; End;
        If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8B); BinEmitESPRef(R1, EbpOfs); Exit; End;
        BinCodeByte($8B); BinEmitMemOp(R1, Inner); Exit;
      End;
      If Pos('OFFSET', StrUpperCase(Op2)) = 1 Then
      Begin
        Tmp := Copy(Op2, 7, Length(Op2) - 6);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        BinCodeByte($B8 + R1); BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0); Exit;
      End;
      Imm := BinParseImm(Op2);
      BinCodeByte($B8 + R1); BinCodeDWord(Imm); Exit;
    End;
    R1 := BinReg8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := BinReg8(Op2);
      If R2 >= 0 Then Begin BinCodeByte($88); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then Begin BinCodeByte($8A); BinEmitRegIndirect(R1, R2); Exit; End;
        If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8A); BinEmitEBPRef(R1, EbpOfs); Exit; End;
        If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8A); BinEmitESPRef(R1, EbpOfs); Exit; End;
        BinCodeByte($8A); BinEmitMemOp(R1, Inner); Exit;
      End;
      Imm := BinParseImm(Op2);
      BinCodeByte($B0 + R1); BinCodeByte(Byte(Imm And $FF)); Exit;
    End;
    { MOV [mem], src }
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      R2 := BinReg32(Op2); R8 := BinReg8(Op2);
      If IsByte Then
      Begin
        If R8 >= 0 Then
        Begin
          BinCodeByte($88); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R8, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R8, EbpOfs)
          Else BinEmitMemRef(R8, Inner); Exit;
        End;
        Imm := BinParseImm(Op2); BinCodeByte($C6); R1 := BinReg32(Inner);
        If R1 >= 0 Then BinEmitRegIndirect(0, R1)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
        Else BinEmitMemRef(0, Inner);
        BinCodeByte(Byte(Imm And $FF)); Exit;
      End
      Else
      Begin
        { Detecter si Op2 est un registre 8 bits meme sans BYTE PTR }
        If (R8 >= 0) And (R2 < 0) Then
        Begin
          BinCodeByte($88); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R8, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R8, EbpOfs)
          Else If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then BinEmitESPRef(R8, EbpOfs)
          Else BinEmitMemOp(R8, Inner); Exit;
        End;
        If R2 >= 0 Then
        Begin
          BinCodeByte($89); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R2, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R2, EbpOfs)
          Else If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then BinEmitESPRef(R2, EbpOfs)
          Else BinEmitMemOp(R2, Inner); Exit;
        End;
        If Pos('OFFSET', StrUpperCase(Op2)) = 1 Then
        Begin
          Tmp := Copy(Op2, 7, Length(Op2) - 6);
          While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
          BinCodeByte($C7); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(0, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
          Else BinEmitMemRef(0, Inner);
          BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0); Exit;
        End;
        Imm := BinParseImm(Op2); BinCodeByte($C7); R1 := BinReg32(Inner);
        If R1 >= 0 Then BinEmitRegIndirect(0, R1)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
        Else BinEmitMemRef(0, Inner);
        BinCodeDWord(Imm); Exit;
      End;
    End;
    Exit;
  End;

  { ADD / SUB / CMP / AND / OR / XOR }
  If (Mnem = 'ADD') Or (Mnem = 'SUB') Or (Mnem = 'CMP') Or
     (Mnem = 'AND') Or (Mnem = 'OR') Or (Mnem = 'XOR') Then
  Begin
    If Not HasOp2 Then Exit;
    If Mnem = 'ADD' Then R8 := 0
    Else If Mnem = 'OR' Then R8 := 1
    Else If Mnem = 'AND' Then R8 := 4
    Else If Mnem = 'SUB' Then R8 := 5
    Else If Mnem = 'XOR' Then R8 := 6
    Else R8 := 7;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin BinCodeByte(Byte($01 + (R8 Shl 3))); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    If R1 >= 0 Then
    Begin
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte(Byte($03 + (R8 Shl 3)));
        BinEmitMemOp(R1, Inner);
        Exit;
      End;
      Imm := BinParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin BinCodeByte($83); BinCodeByte(BinModRM(3, R8, R1)); BinCodeByte(Byte(Imm And $FF)); End
      Else
      Begin
        If R1 = 0 Then BinCodeByte(Byte($05 + (R8 Shl 3)))
        Else Begin BinCodeByte($81); BinCodeByte(BinModRM(3, R8, R1)); End;
        BinCodeDWord(Imm);
      End;
      Exit;
    End;
    R1 := BinReg8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := BinReg8(Op2);
      If R2 >= 0 Then Begin BinCodeByte(Byte($00 + (R8 Shl 3))); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte(Byte($02 + (R8 Shl 3)));
        BinEmitMemOp(R1, Inner);
        Exit;
      End;
      Imm := BinParseImm(Op2);
      If R1 = 0 Then BinCodeByte(Byte($04 + (R8 Shl 3)))
      Else Begin BinCodeByte($80); BinCodeByte(BinModRM(3, R8, R1)); End;
      BinCodeByte(Byte(Imm And $FF)); Exit;
    End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      R2 := BinReg32(Op2);
      If (Not IsByte) And (R2 >= 0) Then
      Begin
        BinCodeByte(Byte($01 + (R8 Shl 3)));
        BinEmitMemOp(R2, Inner); Exit;
      End;
      Imm := BinParseImm(Op2);
      If IsByte Then
      Begin
        BinCodeByte($80);
        BinEmitMemOp(R8, Inner);
        BinCodeByte(Byte(Imm And $FF));
      End
      Else
      Begin
        If (Imm >= -128) And (Imm <= 127) Then
        Begin
          BinCodeByte($83);
          BinEmitMemOp(R8, Inner);
          BinCodeByte(Byte(Imm And $FF));
        End
        Else
        Begin
          BinCodeByte($81);
          BinEmitMemOp(R8, Inner);
          BinCodeDWord(Imm);
        End;
      End;
    End;
    Exit;
  End;

  { XCHG }
  If Mnem = 'XCHG' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      If R1 = 0 Then BinCodeByte($90 + R2)
      Else If R2 = 0 Then BinCodeByte($90 + R1)
      Else Begin BinCodeByte($87); BinCodeByte(BinModRM(3, R1, R2)); End;
    End;
    Exit;
  End;

  { Unknown instruction -> NOP with warning }
  If Opts.Verbose Then
    WarnMsg('instruction ASM inconnue ignoree: ' + Mnem);
  BinCodeByte($90);
End;

{ ------------------------------------------------------------ }
{ BinResolveAll : resoudre tous les fixups apres assemblage    }
{ ------------------------------------------------------------ }

Procedure BinResolveAll(TextRVA, DataRVA, RdataRVA, IATOfs : LongInt);
Var
  I, LblIdx, ApiIdx : Integer;
  TargetAddr, FixAddr : LongInt;
  P : ^Byte;
  ExistOfs : LongInt;
Begin
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFixups[I].Kind = BFK_IAT32 Then
    Begin
      ApiIdx := BinIsExtern(BinFixups[I].Target);
      If ApiIdx >= 0 Then TargetAddr := PE_IMG_BASE + RdataRVA + IATOfs + ApiIdx * 4
      Else TargetAddr := 0;
      If BinFixups[I].InCode Then P := @BinCode[BinFixups[I].Offset]
      Else P := @BinData[BinFixups[I].Offset];
      P^ := Byte(TargetAddr And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 24) And $FF);
    End
    Else
    Begin
      LblIdx := BinFindLabel(BinFixups[I].Target);
      If LblIdx >= 0 Then
      Begin
        If BinLabels[LblIdx].InCode Then TargetAddr := PE_IMG_BASE + TextRVA + BinLabels[LblIdx].Offset
        Else TargetAddr := PE_IMG_BASE + DataRVA + BinLabels[LblIdx].Offset;
      End
      Else TargetAddr := 0;
      If BinFixups[I].InCode Then P := @BinCode[BinFixups[I].Offset]
      Else P := @BinData[BinFixups[I].Offset];
      If BinFixups[I].Kind = BFK_REL32 Then
      Begin
        If BinFixups[I].InCode Then FixAddr := PE_IMG_BASE + TextRVA + BinFixups[I].Offset + 4
        Else FixAddr := PE_IMG_BASE + DataRVA + BinFixups[I].Offset + 4;
        TargetAddr := TargetAddr - FixAddr;
        P^ := Byte(TargetAddr And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 24) And $FF);
      End
      Else
      Begin
        If BinFixups[I].InCode Then
          ExistOfs := LongInt(BinCode[BinFixups[I].Offset]) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 1]) Shl 8) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 2]) Shl 16) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 3]) Shl 24)
        Else
          ExistOfs := LongInt(BinData[BinFixups[I].Offset]) Or
                     (LongInt(BinData[BinFixups[I].Offset + 1]) Shl 8) Or
                     (LongInt(BinData[BinFixups[I].Offset + 2]) Shl 16) Or
                     (LongInt(BinData[BinFixups[I].Offset + 3]) Shl 24);
        TargetAddr := TargetAddr + ExistOfs;
        P^ := Byte(TargetAddr And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 24) And $FF);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ File writing helpers                                         }
{ ------------------------------------------------------------ }

Function BinAlignTo(Size, Align : LongInt) : LongInt;
Begin
  If (Size Mod Align) = 0 Then BinAlignTo := Size
  Else BinAlignTo := Size + Align - (Size Mod Align);
End;

Procedure WriteBinPad(Var F : File; Count : LongInt);
Var ZB : Array[0..511] of Byte; N : LongInt;
Begin
  FillChar(ZB, SizeOf(ZB), 0);
  While Count > 0 Do
  Begin If Count > 512 Then N := 512 Else N := Count; BlockWrite(F, ZB, N); Dec(Count, N); End;
End;

Procedure WriteBinWord(Var F : File; W : Word);
Begin BlockWrite(F, W, 2); End;

Procedure WriteBinDWord(Var F : File; D : LongInt);
Begin BlockWrite(F, D, 4); End;

{ ------------------------------------------------------------ }
{ WritePEFile : generer un fichier PE (.EXE ou .DLL) Win32     }
{ ------------------------------------------------------------ }

Procedure WritePEFile(Const FileName : TString; IsDLL : Boolean);
Var
  F : File;
  HSz, TFSz, RFSz, DFSz, TRVA, RRVA, DRVA, ImgSz, RSz : LongInt;
  IATOf, ILTOf, HNOf, DNOf, IDTOf : LongInt;
  I, ANL : Integer;
  HNBuf : Array[0..1023] of Byte;
  HNLen, Pad : LongInt;
  DName : String[16];
  SName : Array[0..7] of Byte;
  CoffChar : Word;
  EntryRVA : LongInt;
  MainIdx  : Integer;
Begin
  DName := 'KERNEL32.DLL'#0;
  { COFF Characteristics : EXECUTABLE_IMAGE | 32BIT_MACHINE [| DLL] }
  CoffChar := $0102;
  If IsDLL Then CoffChar := CoffChar Or $2000;
  IDTOf := 0; ILTOf := 40;
  IATOf := ILTOf + (PE_NUM_API + 1) * 4;
  HNOf := IATOf + (PE_NUM_API + 1) * 4;
  HNLen := 0;
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    HNBuf[HNLen] := 0; Inc(HNLen); HNBuf[HNLen] := 0; Inc(HNLen);
    ANL := Length(BinAPIName[I]);
    Move(BinAPIName[I][1], HNBuf[HNLen], ANL); Inc(HNLen, ANL);
    HNBuf[HNLen] := 0; Inc(HNLen);
    If (HNLen And 1) <> 0 Then Begin HNBuf[HNLen] := 0; Inc(HNLen); End;
  End;
  DNOf := HNOf + HNLen;
  RSz := BinAlignTo(DNOf + Length(DName), 4);
  HSz := BinAlignTo($200, PE_FILE_ALIGN);
  TRVA := PE_SEC_ALIGN;
  TFSz := BinAlignTo(BinCodeLen, PE_FILE_ALIGN);
  RRVA := TRVA + BinAlignTo(BinCodeLen, PE_SEC_ALIGN);
  RFSz := BinAlignTo(RSz, PE_FILE_ALIGN);
  DRVA := RRVA + BinAlignTo(RSz, PE_SEC_ALIGN);
  DFSz := BinAlignTo(BinDataLen, PE_FILE_ALIGN);
  ImgSz := DRVA + BinAlignTo(BinDataLen, PE_SEC_ALIGN);
  BinResolveAll(TRVA, DRVA, RRVA, IATOf);
  { Determiner le point d entree : chercher le label _MAIN }
  EntryRVA := TRVA;
  MainIdx := BinFindLabel('_MAIN');
  If MainIdx >= 0 Then
    EntryRVA := TRVA + BinLabels[MainIdx].Offset;
  Assign(F, FileName); Rewrite(F, 1);
  { DOS Header }
  WriteBinWord(F, PE_DOS_MAGIC); WriteBinPad(F, 58); WriteBinDWord(F, $80);
  WriteBinPad(F, $80 - 64);
  { PE Sig }
  WriteBinDWord(F, PE_PE_SIG);
  { COFF Hdr }
  WriteBinWord(F, PE_MACHINE_I386); WriteBinWord(F, 3);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinWord(F, PE_OPT_SIZE); WriteBinWord(F, CoffChar);
  { Opt Hdr }
  WriteBinWord(F, PE_MAGIC_32); WriteBinWord(F, $0100);
  WriteBinDWord(F, TFSz); WriteBinDWord(F, DFSz + RFSz); WriteBinDWord(F, 0);
  WriteBinDWord(F, EntryRVA); WriteBinDWord(F, TRVA); WriteBinDWord(F, DRVA);
  WriteBinDWord(F, PE_IMG_BASE); WriteBinDWord(F, PE_SEC_ALIGN); WriteBinDWord(F, PE_FILE_ALIGN);
  WriteBinWord(F, 4); WriteBinWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinWord(F, 4); WriteBinWord(F, 0);
  WriteBinDWord(F, 0); WriteBinDWord(F, ImgSz); WriteBinDWord(F, HSz); WriteBinDWord(F, 0);
  WriteBinWord(F, PE_SUBSYS_CUI); WriteBinWord(F, 0);
  WriteBinDWord(F, $100000); WriteBinDWord(F, $1000);
  WriteBinDWord(F, $100000); WriteBinDWord(F, $1000);
  WriteBinDWord(F, 0); WriteBinDWord(F, 16);
  { Data dirs }
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, RRVA + IDTOf); WriteBinDWord(F, 40);
  For I := 2 To 11 Do Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;
  WriteBinDWord(F, RRVA + IATOf); WriteBinDWord(F, (PE_NUM_API + 1) * 4);
  For I := 13 To 15 Do Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;
  { Section Hdrs }
  FillChar(SName, 8, 0); Move('.text'#0, SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, BinCodeLen); WriteBinDWord(F, TRVA);
  WriteBinDWord(F, TFSz); WriteBinDWord(F, HSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_TEXT);
  FillChar(SName, 8, 0); Move('.rdata', SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, RSz); WriteBinDWord(F, RRVA);
  WriteBinDWord(F, RFSz); WriteBinDWord(F, HSz + TFSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_RDATA);
  FillChar(SName, 8, 0); Move('.data'#0, SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, BinDataLen); WriteBinDWord(F, DRVA);
  WriteBinDWord(F, DFSz); WriteBinDWord(F, HSz + TFSz + RFSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);
  { Pad headers }
  Pad := HSz - (64 + ($80 - 64) + 4 + 20 + 224 + 120);
  If Pad > 0 Then WriteBinPad(F, Pad);
  { .text }
  BlockWrite(F, BinCode, BinCodeLen);
  Pad := TFSz - BinCodeLen; If Pad > 0 Then WriteBinPad(F, Pad);
  { .rdata }
  WriteBinDWord(F, RRVA + ILTOf); WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, RRVA + DNOf); WriteBinDWord(F, RRVA + IATOf);
  WriteBinPad(F, 20);
  Pad := HNOf;
  For I := 0 To PE_NUM_API - 1 Do
  Begin WriteBinDWord(F, RRVA + Pad); Pad := Pad + 2 + Length(BinAPIName[I]) + 1;
    If ((2 + Length(BinAPIName[I]) + 1) And 1) <> 0 Then Inc(Pad); End;
  WriteBinDWord(F, 0);
  Pad := HNOf;
  For I := 0 To PE_NUM_API - 1 Do
  Begin WriteBinDWord(F, RRVA + Pad); Pad := Pad + 2 + Length(BinAPIName[I]) + 1;
    If ((2 + Length(BinAPIName[I]) + 1) And 1) <> 0 Then Inc(Pad); End;
  WriteBinDWord(F, 0);
  BlockWrite(F, HNBuf, HNLen);
  BlockWrite(F, DName[1], Length(DName));
  Pad := RFSz - (40 + (PE_NUM_API + 1) * 4 + (PE_NUM_API + 1) * 4 + HNLen + Length(DName));
  If Pad > 0 Then WriteBinPad(F, Pad);
  { .data }
  BlockWrite(F, BinData, BinDataLen);
  Pad := DFSz - BinDataLen; If Pad > 0 Then WriteBinPad(F, Pad);
  Close(F);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFFile : generer un fichier COFF (.OBJ)               }
{ ------------------------------------------------------------ }

Procedure WriteCOFFFile(Const FileName : TString);
Var F : File; TOfs, DOfs : LongInt; SN : Array[0..7] of Byte;
Begin
  TOfs := 20 + 80; DOfs := TOfs + BinCodeLen;
  Assign(F, FileName); Rewrite(F, 1);
  WriteBinWord(F, PE_MACHINE_I386); WriteBinWord(F, 2);
  WriteBinDWord(F, 0); WriteBinDWord(F, DOfs + BinDataLen);
  WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  FillChar(SN, 8, 0); Move('.text'#0, SN, 6); BlockWrite(F, SN, 8);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, BinCodeLen); WriteBinDWord(F, TOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_TEXT);
  FillChar(SN, 8, 0); Move('.data'#0, SN, 6); BlockWrite(F, SN, 8);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, BinDataLen); WriteBinDWord(F, DOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);
  BlockWrite(F, BinCode, BinCodeLen);
  BlockWrite(F, BinData, BinDataLen);
  WriteBinDWord(F, 4);
  Close(F);
End;

{ ------------------------------------------------------------ }
{ AssembleAndWriteBinary : lire ASM et generer PE/COFF         }
{ ------------------------------------------------------------ }

Procedure AssembleAndWriteBinary(Const AsmFile, BinFile : TString;
                                IsObj, IsDLL : Boolean);
Var AsmF : Text; Line : String;
Begin
  BinInit; BinInCode := True;
  Assign(AsmF, AsmFile);
  {$I-} Reset(AsmF); {$I+}
  If IOResult <> 0 Then Begin
    WarnMsg('impossible d''ouvrir le fichier ASM intermediaire: ' + AsmFile);
    Exit;
  End;
  While Not EOF(AsmF) Do Begin ReadLn(AsmF, Line); BinAssembleLine(Line); End;
  Close(AsmF);
  If IsObj Then WriteCOFFFile(BinFile)
  Else WritePEFile(BinFile, IsDLL);
End;

{ ------------------------------------------------------------ }
{ Run : ouvre le fichier source, lexe et affiche les tokens     }
{ avec support du preprocesseur, des litteraux et symboles     }
{ ------------------------------------------------------------ }

Procedure Run;
Var
  AsmFile : TString;
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

  { Initialiser le pool de donnees, le pool de tokens, la table des symboles et des types }
  DataInit;
  TokenPoolInit;
  SymInit;
  TypeInit;

  { Initialiser le preprocesseur et le lexeur }
  PPInit;
  LexInit;

  { Scanner tous les tokens via le preprocesseur et les stocker }
  Repeat
    LexNextTokenPP;
    If CurToken.Kind <> TK_EOF Then
      TokenPoolAdd(CurToken);
  Until CurToken.Kind = TK_EOF;

  { Verifier les conditionnels non fermes }
  If CondTop >= 0 Then
    WarnMsg(IntToStr_(CondTop + 1) +
      ' directive(s) #if/#ifdef non fermee(s)');

  { Fermer le fichier source }
  LexClose;

  { Concatener les chaines adjacentes ("abc" "def" -> "abcdef") }
  TokenPoolConcatStrings;

  { Enregistrer toutes les chaines dans le pool de donnees }
  TokenPoolRegisterStrings;

  { --- Analyse des declarations globales (TODO 08) --- }
  ParseDataDecls;

  { --- Analyse des fonctions (TODO 09) --- }
  ParseFuncDecls;

  WriteLn('CCW32: Lexer+PP OK (', TotalLines, ' lignes, ',
    MacroCount, ' macros, ', TokenCount, ' tokens, ',
    DataCount, ' data, ', SymCount, ' symboles, ',
    TypeCount, ' types, ', FuncCount, ' fonctions)');

  { --- Emetteur ASM (TODO 07) --- }
  { Toujours generer le fichier .ASM (intermediaire ou final) }
  AsmFile := ReplaceExt(Opts.SrcFile, '.asm');
  EmitOpen(AsmFile);
  EmitHeader;
  EmitExternFuncs;
  EmitDataSeg;
  EmitCodeSeg;
  EmitRuntime;
  EmitFunctions;
  EmitLateData;
  EmitClose;
  If Opts.AsmOutput Then
    WriteLn('CCW32: ASM genere -> ', AsmFile);

  { --- Generation binaire (TODO 25) --- }
  If Opts.ObjOnly Then
  Begin
    { Generer un fichier COFF .OBJ }
    AssembleAndWriteBinary(AsmFile, ReplaceExt(Opts.SrcFile, '.obj'), True, False);
    WriteLn('CCW32: OBJ genere -> ', ReplaceExt(Opts.SrcFile, '.obj'));
    If Not Opts.AsmOutput Then
    Begin
      Assign(OutF, AsmFile);
      {$I-} Erase(OutF); {$I+}
      If IOResult <> 0 Then { ignorer };
    End;
  End
  Else If Opts.DLLMode Then
  Begin
    { Generer un fichier PE .DLL }
    AssembleAndWriteBinary(AsmFile, ReplaceExt(Opts.SrcFile, '.dll'), False, True);
    WriteLn('CCW32: DLL genere -> ', ReplaceExt(Opts.SrcFile, '.dll'));
    If Not Opts.AsmOutput Then
    Begin
      Assign(OutF, AsmFile);
      {$I-} Erase(OutF); {$I+}
      If IOResult <> 0 Then { ignorer };
    End;
  End
  Else
  Begin
    { Generer un fichier PE .EXE (defaut) }
    AssembleAndWriteBinary(AsmFile, ReplaceExt(Opts.SrcFile, '.exe'), False, False);
    WriteLn('CCW32: EXE genere -> ', ReplaceExt(Opts.SrcFile, '.exe'));
    If Not Opts.AsmOutput Then
    Begin
      Assign(OutF, AsmFile);
      {$I-} Erase(OutF); {$I+}
      If IOResult <> 0 Then { ignorer };
    End;
  End;
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
