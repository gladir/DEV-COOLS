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

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              AsmOutput, ObjOnly)
            ParseArgs : analyser argv (source.c [sortie.exe] [-v] [-d]
              [-w] [-obj] [-asm])
            -obj : produire uniquement un fichier .OBJ (COFF)
            -asm : produire egalement un fichier .ASM lisible
            Par defaut : produire un .EXE (PE Windows 32 bits)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .c du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h ou /?)

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

Begin
End.
