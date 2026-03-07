{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur VAX Pascal vers assembleur 8086
  @license: MIT
}

(* ============================================================
  VAXPAS86.PAS - Compilateur VAX Pascal vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  VAX Pascal est une extension du Pascal standard ISO 7185
  developpee par Digital Equipment Corporation (DEC) pour les
  systemes VAX/VMS. Ce compilateur prend en entree des fichiers
  .PAS en dialecte VAX Pascal et produit de l assembleur 8086
  compatible MASM (.ASM) pour DOS 16 bits.

  Les extensions VAX Pascal supportees incluent :
    - MODULE (unite de compilation separee)
    - Attributs entre crochets : [EXTERNAL], [GLOBAL], [INHERIT],
      [ENVIRONMENT], [WORD], [VOLATILE], [READONLY], [HIDDEN]
    - VARYING [n] OF CHAR (chaines de longueur variable)
    - Litteraux octaux (777B, #O377)
    - Operateurs : || (concatenation), ** (exponentiation),
      ANDIF/ORIF (evaluation court-circuit)
    - Substring : S[pos:len]
    - Fonctions intrinseques : UPPERBOUND, LOWERBOUND, DIMENSION,
      SIZE, ADDRESS, IADDRESS, SUBSTR, INDEX, LENGTH, etc.
    - Boucle LOOP..EXIT IF..END
    - CASE..OTHERS (branche par defaut)
    - $INCLUDE, $TITLE, $PAGE, $OPTIONS, $IF/$END (preprocesseur)
    - STATIC VAR, PUBLIC, EXTERNAL
    - Schema types et tableaux conformants : array[1..*]
    - I/O etendu : TTY, TTYOUTPUT, OPEN, CLOSE, CURSOR, FILENAME
    - Gestion d exceptions : CONDITION, EXCEPTION, ON..DO

  Fichiers exemples : SAMPLES\VAXPASCAL\*.PAS

  ============================================================

  PLAN D IMPLEMENTATION - 25 TODOS
  ================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS DE LIGNE DE COMMANDE
            Squelette du programme principal :
              ParseArgs : analyser -v -d -w -o fichier.asm source.pas
              ShowBanner : affiche le nom + version
              ShowUsage  : affiche la syntaxe
              GlobalInit : initialiser toutes les variables globales
              Cleanup    : fermer les fichiers ouverts
              Run        : pipeline principal (boucle de compilation)
            Record TOptions :
              SrcFile, OutFile, Verbose, DebugMode, Warnings
            Fonctions utilitaires de chaines :
              StrLowerCase, StrUpperCase, IntToStr, StrToIntDef
              ExtractExt, ReplaceExt, BPOfs
            Gestion des erreurs :
              ErrorCount, WarnCount, FatalError, ErrorMsg, WarnMsg
              Expect (token attendu), SkipTo (synchronisation)
            Constantes internes :
              MAX_SYM, MAX_DATA, MAX_TYPE, MAX_LABEL, MAX_SCOPE,
              MAX_PARAM, MAX_ERRORS, MAX_STR, MAX_INCLUDE, MAX_DEFINE,
              MAX_FIELD, MAX_ENUM, STACK_SIZE
            Prefixes de nommage ASM :
              VXP_VAR_PFX  = '_VXP_'   (variable globale)
              VXP_FN_PFX   = '_VXPF_'  (fonction/procedure)
              VXP_STR_PFX  = '_VXPK_'  (constante chaine)
              VXP_RT_PFX   = '_VXPRT_' (routine runtime)
              VXP_LBL_PFX  = '_VXPL_'  (label de saut interne)
              VXP_ARR_PFX  = '_VXPA_'  (tableau)
              VXP_REC_PFX  = '_VXPR_'  (record)
              VXP_ENUM_PFX = '_VXPE_'  (enumeration)
              VXP_MOD_PFX  = '_VXPM_'  (module)
            Codes de sortie : EXIT_OK=0, EXIT_ERROR=1, EXIT_USAGE=2

  TODO 02 - LEXEUR (TOKENS VAX PASCAL)
            Analyse lexicale caractere par caractere :
              LexInit, LexClose, LexNextLine, LexNextToken
              LexScanIdent, LexScanNumber, LexScanString, LexScanCharLit
            Token record : Kind, Val, IntVal, RealVal, Line, Col
            Types de tokens :
              TK_EOF, TK_INTEGER, TK_REAL, TK_STRING, TK_CHAR,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_OCTAL,
              TK_ATTR_OPEN, TK_ATTR_CLOSE (crochets [ ] pour attributs)
            Mots-cles VAX Pascal (en plus du standard) :
              MODULE, VARYING, RETURN, LOOP, OTHERS, OTHERWISE,
              ANDIF, ORIF, VALUE, STATIC, EXTERNAL, GLOBAL, PUBLIC,
              CONDITION, EXCEPTION, STOP, ORIGIN, PACKED, PREC, BY,
              LABEL, GOTO, SIGNAL, RESIGNAL
            Mots-cles d attributs entre crochets :
              INHERIT, ENVIRONMENT, EXTERNAL, GLOBAL, HIDDEN,
              WORD, VOLATILE, READONLY, WRITEONLY, ALIGNED, UNSAFE,
              UNBOUND, ASYNCHRONOUS, IMMEDIATE, LIST, NOLIST,
              OPTIMIZE, NOOPTIMIZE, CHECK, NOCHECK, POS, IDENT,
              TRUNCATE, FORTRAN, C, PASCAL
            Operateurs supplementaires :
              || (concatenation), ** (exponentiation)
            Identifiants avec $ (VMS) :
              SMG$Create_Virtual_Display, LIB$Signal, SYS$...
              Le $ est un caractere valide dans les identifiants
            Commentaires : { ... }, paren-etoile, (pas de // en VAX Pascal)
            Litteraux octaux :
              Suffixe B ou b : 777B, 377b
              Prefixe #O : #O377
            Litteraux hexadecimaux :
              Prefixe #X ou #x : #XFF
            Caracteres speciaux :
              Apostrophe simple pour chaines : 'texte'
              # pour caractere : #13, #O15
            PrintToken : affichage debug d un token

  TODO 03 - PREPROCESSEUR ($DIRECTIVES ET %DIRECTIVES)
            Directives de compilation VAX Pascal (prefixe $) :
              $INCLUDE 'fichier'    : inclusion de fichier source
              $SYSTEM fichier       : inclusion systeme (TOPS-10/20)
              $TITLE texte          : titre de listing (ignore)
              $HEADER texte         : en-tete de listing (ignore)
              $PAGE                 : saut de page listing (ignore)
              $LENGTH=n             : longueur de page (ignore)
              $WIDTH=n              : largeur de page (ignore)
              $SOURCE               : activer le listing source (ignore)
              $NOSOURCE             : desactiver le listing (ignore)
              $OPTIONS directives   : options de compilation
                SPECIAL, SPECIAL(COERCIONS), SPECIAL(WORD), SPECIAL(PTR),
                NOCHECK, CHECK, CHECK(ASSERTIONS), ASSEMBLY,
                DUMPST, DUMPIF, FORTRAN
            Compilation conditionnelle :
              $IF identifier        : si symbole defini
              $IFNOT identifier     : si symbole non defini
              $ELSE                 : branche alternative
              $END                  : fin de bloc conditionnel
              $ENDIF                : synonyme de $END
              $DEFINE identifier    : definir un symbole
            Directives VMS avec prefixe % :
              %INCLUDE 'fichier'    : inclusion (syntaxe VMS native)
              %DICTIONARY 'CDD_PATH' : charge definitions CDD (ignore)
              %DESCR(param)         : passage par descripteur (appels VMS)
              %REF(param)           : passage par reference (appels VMS)
              %STDESCR(param)       : descripteur standard (appels VMS)
              %IMMED(param)         : passage immediat (appels VMS)
            Mecanisme d inclusion :
              IncludePush(FileName) : empiler fichier courant, ouvrir include
              IncludePop           : depiler et restaurer fichier precedent
              IncSavedFName, IncSavedLine, IncSavedLineNo, etc.
              Profondeur maximale : MAX_INCLUDE (8)

  TODO 04 - LITTERAUX ET SEGMENT DE DONNEES
            Table de donnees (DataTab, DataCount) :
              DK_STR  : chaine ASCIIZ (DB 'texte',0)
              DK_WORD : mot 16 bits (DW valeur)
              DK_BYTE : octet (DB valeur)
              DK_ARR  : tableau (DB count DUP(0))
              DK_REC  : record (DB size DUP(0))
            DataAdd, DataAddStr, DataAddWord, DataAddByte,
            DataAddArray, DataAddRec
            Evaluation de litteraux :
              Decimaux : 123, -45
              Octaux : 777B, #O377
              Hexadecimaux : #XFF
              Chaines : 'texte', 'l''apostrophe'
              Caracteres : #65, #O101, #XFF
              Reels : 3.14, 1.5E+3
            Constantes nommees :
              CONST name = valeur;
              CONST name := valeur;  (syntaxe VAX := pour constantes)
            LabelGen, LabelGenSeq : generateur de labels uniques
            EmitRaw : ecriture directe dans le fichier de sortie
            EmitDataSeg : emission du segment _DATA complet

  TODO 05 - EMETTEUR DE CODE ASM
            Instructions de base :
              EmitComment, EmitLabel, EmitBlankLine
              EmitInstr, EmitInstrA, EmitInstrAB
              EmitPush, EmitPop, EmitMov, EmitCall
              EmitJmp, EmitJmpCond
            En-tete et pied de page :
              EmitHeader : .MODEL SMALL, .STACK, _TEXT SEGMENT,
                _VXPF_main PROC, MOV AX,_DATA / MOV DS,AX
              EmitFooter : MOV AX,4C00h / INT 21h + runtime + _TEXT ENDS
              EmitClose  : END _VXPF_main (apres _DATA ENDS)
            Cadre de pile :
              EmitProlog(FrameSize) : PUSH BP / MOV BP,SP / SUB SP,n
              EmitEpilog(ParamBytes) : MOV SP,BP / POP BP / RET n
            Coercitions de type :
              EmitCoerce(SrcType, DstType) : CBW, etc.
            NewLabel : generateur de labels internes

  TODO 06 - TABLE DES SYMBOLES
            Enregistrement TSymRec :
              Name, MangledName, Cat (SC_VAR/SC_CONST/SC_FUNC/...),
              TypeIdx, Offset, ScopeLevel, ScopeId,
              IsForward, IsLocal, ImmVal, DataIdx,
              ParamCnt, VarParamMask
            Categories supplementaires VAX :
              SC_STATIC    : variable static (persistente)
              SC_EXTERNAL  : variable/procedure externe
              SC_GLOBAL    : procedure globale (exportee)
              SC_PUBLIC    : procedure publique
              SC_MODULE    : nom de module
            Table SymTab[0..MAX_SYM-1], SymCount
            Operations :
              SymAdd, SymFind, SymFindInScope, SymMangle
            Portees (scopes) :
              SymEnterScope, SymLeaveScope
              CurScopeLevel, CurScopeId, ScopeIdSeq
            SymInit : precharger les symboles builtin
              (Integer, Boolean, Char, Real, String, Text,
               True, False, Nil, MaxInt, Unsigned,
               Input, Output, TTY, TTYOutput)

  TODO 07 - SYSTEME DE TYPES
            Enregistrement TTypeRec :
              Name, Kind (TK_PRIM/TK_ENUM/TK_ARRAY/TK_RECORD/
                TK_POINTER/TK_SUBRANGE/TK_SET/TK_FILE/TK_VARYING/
                TK_SCHEMA/TK_PROCEDURAL),
              Size, BaseType, Lo, Hi, FieldCount, Fields,
              EnumCount, Enums, Packed, Precision
            Types primitifs VAX Pascal :
              TY_IDX_INTEGER  = 0   (entier 32 bits signe sur VAX,
                                     tronque a 16 bits pour 8086)
              TY_IDX_WORD     = 1   (entier 16 bits non signe)
              TY_IDX_BYTE     = 2   (8 bits non signe)
              TY_IDX_CHAR     = 3   (8 bits caractere)
              TY_IDX_BOOLEAN  = 4   (0 ou 1)
              TY_IDX_STRING   = 5   (pointeur ASCIIZ)
              TY_IDX_REAL     = 6   (flottant simple precision)
              TY_IDX_DOUBLE   = 7   (flottant double precision)
              TY_IDX_POINTER  = 8   (pointeur generique)
              TY_IDX_NIL      = 9   (pointeur nul)
              TY_IDX_TEXT     = 10   (fichier texte)
              TY_IDX_UNSIGNED = 11   (entier 16 bits non signe VAX)
              TY_IDX_VARYING  = 12   (VARYING [n] OF CHAR)
            Types predefinis VMS Pascal supplementaires :
              MACHINE_WORD    : mot machine (16 bits sur 8086)
              HALF_WORD       : demi-mot (8 bits sur 8086)
              INTEGER16       : entier 16 bits explicite
              INTEGER32       : entier 32 bits (emule en 16+16)
              SINGLE, D_FLOAT, D_FLOATING : simple precision IEEE
              DOUBLE, G_FLOAT, G_FLOATING : double precision IEEE
              F_FLOATING      : simple precision VAX (= SINGLE)
              H_FLOATING      : quadruple precision (non supporte)
              QUADWORD        : 64 bits (emule en 4x16)
              UNSIGNED        : 16 bits non signe
              FILE_NAME       : STRING predefini pour noms de fichier
              LINE            : STRING predefini (longueur standard)
              IO_STATUS       : enumeration predefinie d etats d I/O
                (IO_OK, IO_NOVF, IO_POVF, IO_DGIT, IO_GOVF,
                 IO_INTR, IO_REWR, IO_EOF, IO_OUTF, IO_INPF,
                 IO_SEEK, IO_ILLC, IO_NEPF, IO_OPNF)
            Types proceduraux :
              TYPE TProc = PROCEDURE(a: Integer);
              TYPE TFunc = FUNCTION(a: Integer): Integer;
              VAR callback : TProc;
            TypeInit, TypeSizeof, TypeCompatible, TypeCoerce,
            TypeResolve, TypeIsOrdinal, TypeIsNumeric, TypeIsPointer
            Attribut [WORD] : forcer la taille a 16 bits
            Attribut PACKED : compresser les champs
            PREC n : precision flottante (=> REAL ou DOUBLE)

  TODO 08 - OPERATEURS ET PRECEDENCES
            Priorites (du plus faible au plus fort) :
              1 : OR, ORIF
              2 : AND, ANDIF
              3 : NOT (unaire)
              4 : =, <>, <, >, <=, >=, IN
              5 : +, -, || (concatenation)
              6 : *, /, DIV, MOD
              7 : ** (exponentiation)
              8 : unaires +, -, @, ^, NOT
            Evaluation court-circuit :
              ANDIF : si gauche = False, ne pas evaluer droite
              ORIF  : si gauche = True, ne pas evaluer droite
            Concatenation || :
              Genere un appel runtime _VXPRT_CONCAT
              Resultat dans un buffer temporaire
            Exponentiation ** :
              Entier ** Entier  : boucle de multiplication
              Reel ** Entier    : appel _VXPRT_POWRI
            Operateurs de bits : AND, OR, XOR, NOT, SHL, SHR
            Expression record TExprVal :
              Kind (EK_IMM/EK_REG/EK_MEM/EK_STR), TypeIdx, IntVal
            ParseExpr, ParseExprPrec, ParseUnary, ParsePrimary

  TODO 09 - DECLARATIONS DE VARIABLES ET AFFECTATIONS
            ParseVarDecl : parser le bloc VAR
              var x : Integer;
              var a, b : Integer;
              var s : VARYING [80] OF CHAR;
              var p : ^Integer;
            Attributs de variables VAX (entre crochets) :
              [EXTERNAL] var x : Integer;  (importee d un autre module)
              [GLOBAL]   var x : Integer;  (exportee vers autres modules)
              [VOLATILE] var x : Integer;  (pas de cache registre)
              [READONLY] var x : Integer;  (interdire affectation)
              [WRITEONLY] var x : Integer;  (interdire lecture)
              [ALIGNED(n)] var x : type;   (alignement memoire)
              [WORD] var x : subrange;     (forcer 16 bits)
              [UNSAFE] var x : type;       (pas de verification de type)
              [HIDDEN] var x : type;       (non visible aux autres modules)
              [UNBOUND] var x : type;      (pas lie a un module)
              [POS(n)] dans record : position en bits du champ
            STATIC VAR :
              Persistance entre appels de procedure
              Emis dans le segment _DATA au lieu de la pile
              Initialisation possible : STATIC VAR x : Integer := 0;
            EXTERNAL VAR :
              Variable definie dans un autre module
              Emis comme EXTRN _VXP_name:WORD dans l ASM
            Section VALUE (VMS Pascal) :
              VALUE
                x := 10;
                s := 'default';
              Initialise des variables declarees dans VAR
              Emis comme donnees initiales dans le segment _DATA
            Affectation :
              x := expr;
              Record fields : r.field := expr;
              Pointeur-champ : p^.field := expr;
              Substring : s[pos:len] := expr; (VAX)
              Tableau via pointeur : p^[i] := expr;
            Initialisation dans const :
              const x := valeur;  (syntaxe VAX avec :=)

  TODO 10 - TYPES DEFINIS, ENUMERATIONS, SOUS-INTERVALLES
            ParseTypeDecl : parser le bloc TYPE
              type Color = (Red, Green, Blue);
              type SmallInt = -32..31;
              type Range = 0..777777B;  (litteral octal)
              type Matrix = ARRAY[1..10, 1..20] OF Real;
              type PInt = ^Integer;
              type CharSet = SET OF Char;
              type FlexRec = PACKED RECORD ... END;
            Types VAX specifiques :
              VARYING [n] OF CHAR :
                Record interne avec champ .LENGTH (Word) + .BODY
                Taille en memoire = 2 + n
              Sous-intervalles avec precision :
                -10E4..10E4 PREC 5   (simple precision)
                -10E4..10E4 PREC 12  (double precision)
            Attributs de types :
              PACKED : compresser les champs du record
              [WORD] : forcer la taille a 16 bits
              [ALIGNED(n)] : alignement en memoire
              [UNSAFE] : pas de verification de type dans les coercitions
            Schema types et tableaux conformants :
              ARRAY[1..*] OF type  (taille indeterminee)
              STRING[*] : chaine de longueur indeterminee
              Parametre conformant : VAR a: ARRAY[lo..*] OF type
              PACKED ARRAY[*] OF type
              DIMENSION(a, n), UPPERBOUND(a, n), LOWERBOUND(a, n)
            Types proceduraux :
              TYPE TProc = PROCEDURE(params);
              TYPE TFunc = FUNCTION(params) : RetType;
              Passage comme parametre, stockage dans variable
            Alias de types avec attributs :
              TYPE T = [WORD] lo..hi;
              TYPE T = [ALIGNED(n)] BaseType;

  TODO 11 - WRITE / WRITELN / READ / READLN
            ParseWriteStmt(IsWriteLn) :
              WriteLn(expr)         => appel _VXPRT_PRINTINT/_VXPRT_PRINTSTR
              WriteLn(expr:width)   => format avec largeur
              WriteLn(expr:w:d)     => format reel avec decimales
              Write(tty, ...)       => ecriture sur TTY
              WriteLn(ttyoutput,...)=> ecriture sur TTYOUTPUT
            ParseReadStmt(IsReadLn) :
              Read(x), ReadLn(x)
              ReadLn(tty)           => lecture depuis TTY
            Format d ecriture VAX :
              expr:width:decimal    (standard)
              expr:o                (octal, VAX extension)
              expr:h                (hexadecimal, VAX extension)
            WriteV / ReadV (VAX) :
              WriteV(str, expr, ...) : ecrire dans une variable string
              ReadV(str, var, ...)   : lire depuis une variable string
            Fichiers predefinis :
              Input, Output : stdin/stdout
              TTY           : terminal (lecture interactive)
              TTYOUTPUT     : terminal (ecriture)

  TODO 12 - IF / THEN / ELSE + CASE / OF + LABEL / GOTO
            ParseIfStmt :
              IF expr THEN stmt
              IF expr THEN stmt ELSE stmt
              IF expr THEN BEGIN ... END ELSE BEGIN ... END
            ParseCaseStmt :
              CASE expr OF
                val1 : stmt;
                val2, val3 : stmt;
                val4..val6 : stmt;
                OTHERS : stmt;       (VAX Pascal, au lieu de ELSE)
                OTHERWISE : stmt;    (synonyme de OTHERS)
              END;
            Emission :
              CMP AX, val / JE label pour chaque cas
              Branche OTHERS/OTHERWISE en dernier (fallthrough)
            LABEL et GOTO (VAX et standard) :
              LABEL 1, 100, sortie;  (declarations numeriques ou identifiant)
              GOTO 1;                (saut a un label)
              Goto non-local :       (saut dans une portee englobante)
                Le goto non-local restaure le cadre de pile (BP)
                via une sauvegarde/restauration dans _DATA
            Variantes CASE dans records :
              CASE tag : Type OF
                val : (champs);
                OTHERS : (champs);  (branche par defaut VMS)

  TODO 13 - BOUCLES : FOR / WHILE / REPEAT / LOOP
            ParseForStmt :
              FOR i := lo TO hi DO stmt
              FOR i := hi DOWNTO lo DO stmt
              FOR c := lowerbound(a,1) TO upperbound(a,1) DO stmt
              BY step (VAX extension) :
                FOR i := 0 TO 100 BY 2 DO stmt
            ParseWhileStmt :
              WHILE expr DO stmt
              WHILE expr DO BEGIN ... END
            ParseRepeatStmt :
              REPEAT stmt; ... UNTIL expr
            ParseLoopStmt (VAX extension) :
              LOOP
                stmt;
                EXIT IF expr;
                stmt;
              END;
              Note : EXIT IF peut apparaitre n importe ou dans le LOOP
              Plusieurs EXIT IF possibles dans un meme LOOP
            Break et Continue (bouclage) :
              BREAK  (quitter la boucle)
              CONTINUE (passer a l iteration suivante)
            NEXT (VMS Pascal) :
              Synonyme de CONTINUE dans certaines versions
            Pile de boucles : LoopBreakLbl, LoopContLbl, LoopTop

  TODO 14 - FONCTIONS ET PROCEDURES
            ParseFuncDecl :
              FUNCTION name(params) : ReturnType;
              FUNCTION name : ReturnType; FORWARD;
              name := expr;  (affectation du resultat)
            ParseProcDecl :
              PROCEDURE name(params);
              PROCEDURE name; FORWARD;
            Parametres :
              par valeur    : param : Type
              par reference : VAR param : Type
              Valeurs par defaut (VAX) : param : Type := default
              Parametres conformants : VAR a : ARRAY[lo..*] OF Type
              Parametres proceduraux : PROCEDURE p(PROCEDURE callback)
              Parametres fonction   : FUNCTION f(FUNCTION g: Integer)
            Parametres nommes dans les appels (VMS) :
              LibCall(param1 := val1, param2 := val2)
              SMG$Put_Line(Display, Msg, wrap_flag:=SMG$M_WRAP_WORD)
            OPTIONS sur routines (VAX) :
              PROCEDURE name OPTIONS SPECIAL(COERCIONS);
              PROCEDURE name OPTIONS SPECIAL(WORD);
              PROCEDURE name OPTIONS SPECIAL(PTR);
              FUNCTION name OPTIONS ASSEMBLY;
              FUNCTION name OPTIONS CHECK;
              FUNCTION name OPTIONS NOCHECK;
            Attributs de routines (VAX) :
              [EXTERNAL] PROCEDURE name(...); EXTERNAL;
              [GLOBAL] PROCEDURE name(...);
              [ASYNCHRONOUS] PROCEDURE name(...);
              [UNBOUND] PROCEDURE name(...);
              PUBLIC PROCEDURE name(...);
            Conventions d appel (VMS) :
              Par defaut : convention Pascal (droite a gauche)
              [FORTRAN] : convention Fortran (gauche a droite)
              [C]       : convention C (droite a gauche, appelant nettoie)
              [PASCAL]  : explicitement Pascal
            RETURN (VAX) :
              RETURN        : quitter procedure (equiv. EXIT en TP)
              RETURN(expr)  : quitter fonction avec valeur
            STOP (VAX) :
              Arret immediat du programme (equiv. HALT)
            Cadre local : PUSH BP / MOV BP,SP / SUB SP,framesize
            Result dans AX (entier) ou buffer (string)

  TODO 15 - ENREGISTREMENTS (RECORDS)
            ParseRecordType :
              TYPE rec = RECORD
                field1 : Type1;
                field2 : Type2;
              END;
            PACKED RECORD :
              Champs compresses sans padding
            Variant records :
              CASE tag : Type OF
                val1 : (fields);
                val2 : (fields);
                OTHERS : (fields);  (VMS : branche par defaut)
              END;
            Attributs de champs (VMS) :
              [POS(n)]      : position en bits du champ dans le record
              [ALIGNED(n)]  : alignement du champ
              [READONLY]    : champ en lecture seule
              [WRITEONLY]   : champ en ecriture seule
            Acces aux champs :
              r.field
              p^.field (via pointeur)
            WITH :
              WITH r DO BEGIN ... END;
              WITH r1, r2 DO stmt;  (with imbrique)
            Constructeurs de records (VAX) :
              TypeName(field1 := val1, field2 := val2)
              Utilise dans les expressions et les affectations
            SIZE avec variantes de tag (VMS) :
              SIZE(RecType)         : taille du type
              SIZE(RecType, tag)    : taille avec variant specifique
              NEW(p, tag1, tag2)    : allocation avec tags de variant
              DISPOSE(p, tag1)      : liberation avec tags

  TODO 16 - TABLEAUX
            ParseArrayType :
              TYPE t = ARRAY[lo..hi] OF ElemType;
              TYPE t = ARRAY[1..m, 1..n] OF ElemType;
              TYPE t = PACKED ARRAY[range] OF type;
            Acces aux elements :
              a[i], a[i,j], a[expr]
            Tableaux de constantes :
              CONST tab : ARRAY[range] OF type = (v1, v2, ...);
              CONST tab : ARRAY[io_status] OF STRING = (...);
            Tableaux conformants (VAX) :
              ARRAY[1..*] OF type (taille dynamique)
              Allocation via NEW(p, size)
            Fonctions sur tableaux :
              DIMENSION(a, n) : nombre d elements de la dimension n
              UPPERBOUND(a, n) : borne superieure de la dimension n
              LOWERBOUND(a, n) : borne inferieure de la dimension n
            Emission :
              Acces par offset = (index - lo) * taille_element
              LEA, base + index * taille

  TODO 17 - CHAINES (STRING ET VARYING)
            Chaines STRING standard :
              VAR s : STRING;          (longueur max par defaut)
              VAR s : STRING[80];      (longueur max explicite)
              s := 'texte';
              s := s1 + s2;            (concatenation avec +)
              Length(s), Copy(s,i,n), Pos(sub,s)
              Delete(s,i,n), Insert(sub,s,i)
            Chaines VARYING [n] OF CHAR (VAX) :
              Structure interne : .LENGTH (Word) + .BODY (n octets)
              VAR s : VARYING [80] OF CHAR;
              s := 'texte';
              s.LENGTH                (propriete longueur, Word)
              s.BODY                  (acces brut au corps, PACKED ARRAY)
              s := s1 || s2;          (concatenation VAX avec double-pipe)
              s := s1 + s2;           (concatenation aussi avec +)
              Comparaisons : =, <>, <, >, <=, >= (lexicographiques)
            PACKED ARRAY[1..n] OF CHAR (VMS) :
              Litteral chaine implicitement PACKED ARRAY
              Pad automatique avec espaces si longueur < n
              Comparaison avec padding integre
            STRING(n) (VMS) :
              Synonyme de PACKED ARRAY[1..n] OF CHAR
              STRING(n) := 'texte';
            Sous-chaines (VAX) :
              s[pos:len]              (extraction)
              s[pos:len] := 'texte';  (affectation partielle)
            Fonctions chaines VAX :
              LENGTH(s)               : longueur
              SUBSTR(s, pos, len)     : extraction
              INDEX(s, sub)           : position de sous-chaine
              VERIFY(s, charset)      : verification caracteres
              SEARCH(s, sub)          : recherche
              UPPERCASE(ch)           : majuscule (caractere)
              LOWERCASE(ch)           : minuscule (caractere)
              TRIM(s)                 : supprimer espaces de fin
              PAD(s, ch, n)           : completer a n car avec ch
              EQ(s1,s2)              : egalite case-insensitive
              NE, LT, GT, LE, GE     : comparaisons case-insensitive
            WriteV / ReadV :
              WriteV(str, expr, ...)  : ecriture formatee dans string
              ReadV(str, var, ...)    : lecture formatee depuis string
              PutString(str, expr, ...): synonyme de WriteV
              GetString(str, var, ...): synonyme de ReadV
            Descripteurs de chaines (VMS) :
              %DESCR(s) : passer par descripteur DSC$DESCRIPTOR_S
              %REF(s)   : passer par reference brute
              %STDESCR(s): passer par descripteur standard
              %IMMED(n)  : passer par valeur immediate

  TODO 18 - ENSEMBLES (SET OF)
            ParseSetType :
              TYPE cs = SET OF Char;
              TYPE colors = SET OF Color;
              TYPE digits = SET OF 0..9;
              TYPE bits = SET OF 0..255;
            Constructeurs :
              s := [1, 3, 5..8];
              s := ['A'..'Z', '_', '0'..'9'];
              s := [];  (ensemble vide)
            Operations :
              + (union), - (difference), * (intersection)
              IN (appartenance) : IF ch IN s THEN ...
              =, <> (egalite)
              <= (sous-ensemble), >= (sur-ensemble)
            Fonctions sur ensembles (VMS) :
              CARD(s)    : cardinalite (nombre d elements)
              EMPTY(s)   : vrai si ensemble vide (equiv. s = [])
            Implementation :
              Bitmap sur 32 octets max (256 bits pour SET OF Char)
              Operations par octets avec AND, OR, XOR, NOT
              CARD : compter les bits a 1 avec lookup table

  TODO 19 - POINTEURS ET ALLOCATION DYNAMIQUE
            Declarations :
              VAR p : ^Integer;
              VAR p : ^record ... end;
              VAR p : ^array[1..10] of Integer;
              TYPE PInt = ^Integer;  (alias de type pointeur)
              [UNSAFE] VAR p : ^anytype; (pointeur non type)
            Operations :
              New(p)       : allouer un element
              New(p, n)    : allouer avec taille (VAX, conformant)
              New(p, tag1, tag2) : allouer record variant (tags)
              Dispose(p)   : liberer la memoire
              Dispose(p, tag1) : liberer avec tags de variant
              p^ := expr   : dereferencement et affectation
              p^.field     : acces champ via pointeur
              p^[i]        : acces tableau via pointeur
              p := NIL     : pointeur nul
              p := @x      : adresse de variable (standard)
              p := ADDRESS(x) : adresse de variable (VAX)
            Fonctions VAX :
              ADDRESS(x)   : adresse (retourne pointeur type)
              IADDRESS(x)  : adresse (retourne entier)
              PTR(n)       : convertir entier en pointeur
              ORD(ADDRESS(x)) : adresse en entier
              BITNEXT(p)   : pointeur vers le bit suivant (packed)
              UNDEFINED(x) : verifier si variable initialisee
            Coercition de pointeurs (VMS) :
              Type coercion : TypeName(ptr^)
              [UNSAFE] permet conversions implicites
              OPTIONS SPECIAL(COERCIONS) : idem par routine
            Allocation : heap statique avec _VXP_HEAP et _VXP_HEAPTOP
            Pointeurs de procedures et fonctions (VMS) :
              VAR pf : PROCEDURE(params);
              VAR pf : FUNCTION(params) : RetType;
              pf := SomeProc;  (affectation)
              pf(args);        (appel indirect)

  TODO 20 - MODULES ET COMPILATION SEPAREE
            MODULE (VAX Pascal) :
              [Inherit('lib1','lib2')] MODULE name;
                TYPE, VAR, PROCEDURE, FUNCTION declarations
              END.
            Vs PROGRAM :
              PROGRAM name;
                declarations
              BEGIN
                corps principal
              END.
            Vs PROGRAM avec parametre (VMS) :
              PROGRAM name(Input, Output);
              PROGRAM name(Input, Output, DataFile);
              (parametres de programme = fichiers pre-ouverts)
            Attribut [INHERIT] :
              Charge les declarations exportees par d autres modules
              [Inherit('SYS$LIBRARY:STARLET','LibRtl','Types')]
              [Inherit('SYS$LIBRARY:PASCAL$SMG_ROUTINES')]
              [Inherit('SYS$LIBRARY:PASCAL$LIB_ROUTINES')]
              Pour 8086 : ignore ou charge un fichier .INC
            Attribut [ENVIRONMENT] :
              Exporte les declarations du module courant
              [Environment('name')] MODULE name;
              Pour 8086 : genere un fichier .INC avec EXTRN
            Attribut [IDENT] :
              [IDENT('V1.0')] MODULE name;
              Identifiant de version du module (informatif)
            Interface externe VMS (appels systeme) :
              SMG$ : Screen Management (SMG$CREATE_VIRTUAL_DISPLAY,
                SMG$CREATE_PASTEBOARD, SMG$PUT_LINE, SMG$PUT_CHARS,
                SMG$READ_STRING, SMG$SET_CURSOR_ABS, etc.)
              LIB$ : Library (LIB$GET_INPUT, LIB$PUT_OUTPUT,
                LIB$GET_FOREIGN, LIB$SIGNAL, LIB$STOP, etc.)
              SYS$ : System Services (SYS$ASSIGN, SYS$QIOW,
                SYS$GETTIM, SYS$ASCTIM, SYS$BINTIM, etc.)
              OTS$ : Object Time System (OTS$CVT_TU_L, etc.)
              STR$ : String (STR$MATCH_WILD, STR$TRIM, etc.)
              CLI$ : Command Line (CLI$GET_VALUE, CLI$PRESENT, etc.)
              PPL$ : Parallel Processing (PPL$CREATE_SPIN_LOCK, etc.)
              Pour 8086 : stubs EXTRN ou reimplementation minimale
            EXTERNAL :
              EXTERNAL VAR x : Integer;
              [EXTERNAL] PROCEDURE name(...); EXTERNAL;
              Genere EXTRN _VXPF_name:NEAR dans l ASM
            GLOBAL :
              [GLOBAL] PROCEDURE name(...);
              Genere PUBLIC _VXPF_name dans l ASM
            PUBLIC :
              PUBLIC PROCEDURE name(...);
              Synonyme de [GLOBAL]
            Sections d initialisation et terminaison :
              MODULE name;
                (decls)
              [INITIALIZE]
                BEGIN (code) END;
              [FINALIZE]
                BEGIN (code) END;
              END.

  TODO 21 - FONCTIONS ET PROCEDURES STANDARD (INTRINSEQUES)
            Arithmetique :
              Abs(x), Sqr(x), Sqrt(x), Odd(x)
              Sin(x), Cos(x), ArcTan(x), ArcTan(x,y) (VAX : 2 args)
              Ln(x), Exp(x), Log(x) (VAX), Log10(x) (VAX)
              Trunc(x), Round(x), Round(x, n) (VAX : precision)
              Max(a, b), Max(a, b, c) (VAX : N-aire)
              Min(a, b), Min(a, b, c) (VAX : N-aire)
              Maximum(a, b) (VAX : synonyme de Max)
              Minimum(a, b) (VAX : synonyme de Min)
              Random, Random(x) (VAX : avec graine), Seed(n)
              Succ(x), Pred(x), Succ(x, n), Pred(x, n) (VAX : pas)
              Lo(w), Hi(w), Swap(w)
              Dble(x) (VAX : convertir en Double)
              Sngl(x) (VAX : convertir en Single)
              Int(x) (VAX : partie entiere comme reel)
            Ordinaux :
              Ord(x), Chr(n)
              First(type) (VAX : premier element ordinal)
              Last(type) (VAX : dernier element ordinal)
              Next(x) (VAX : synonyme de Succ)
              Prev(x) (VAX : synonyme de Pred)
            Conversion et coercition :
              Trunc(r), Round(r)
              ORD(x) : ordinal d un type enumere ou Boolean
              CHR(n) : caractere depuis ordinal
              Coercition de type : TypeName(expr)
              UINT(x) (VAX : convertir en UNSIGNED)
              UAND, UOR, UNOT, UXOR (VAX : operations non signees)
            Chaines :
              Length(s), Concat(s1, s2, ...)
              Copy(s, i, n), Pos(sub, s)
              Delete(s, i, n), Insert(sub, s, i)
              Uppercase(ch), Lowercase(ch) (VAX)
              Substr(s, pos, len) (VAX)
              Index(s, sub) (VAX)
              Verify(s, charset) (VAX)
              Search(s, sub) (VAX)
              Trim(s) (VAX)
              Pad(s, ch, n) (VAX)
              EQ, NE, LT, GT, LE, GE(s1, s2) (VAX : comp case-blind)
            Memoire :
              New(p), New(p, n) (VAX)
              Dispose(p), Dispose(p, tags) (VAX)
              SizeOf(type) / Size(type) (VAX : SIZE avec variantes)
              Size(type, tag1, tag2) (VAX : taille specifique variant)
              Address(x) (VAX), IAddress(x) (VAX)
              Ptr(n) (VAX)
              Zero(x) (VAX : mettre variable a zero)
              Fill(x, n, val) (VAX : remplir memoire)
            Tableaux (VAX) :
              Dimension(a, n), UpperBound(a, n), LowerBound(a, n)
            Bit et logique (VMS) :
              BIT_OFFSET(ident) : decalage en bits dans record
              BITAND(a,b), BITOR(a,b), BITXOR(a,b), BITNOT(a)
            Diagnostic et controle :
              Assert(cond) (VAX : assertion)
              Assert(cond, 'message') (VAX : avec message)
              Halt, Halt(n)
              Stop (VAX : arret immediat, pas de cleanup)
              Return (VAX : quitter routine)
              Return(expr) (VAX : quitter fonction avec valeur)
            Date et heure (VMS) :
              Date(s) (VAX : date courante en string DD-MMM-YYYY)
              Time(s) (VAX : heure courante en string HH:MM:SS.CC)
              Clock (VAX : centisecondes depuis minuit, Integer)
              WallClock (VAX : secondes depuis minuit, Integer)
              SysClock (VAX : horloge systeme haute resolution)
            Fichiers :
              Str(n, s), Val(s, n, code)
              WriteLn, ReadLn, Write, Read
              GetMem, FreeMem
              Break(f) (VAX : flush fichier)
              Scratch(f) (VAX : supprimer fichier)
              LineLimit(f, n) (VAX : limiter lignes par page)
              Page(f) (VAX : saut de page dans fichier texte)
              Message(s) (VAX : ecrire sur SYS$ERROR / stderr)

  TODO 22 - ENTREES/SORTIES (I/O)
            Fichiers predefinis :
              Input, Output       : stdin/stdout
              TTY                 : terminal lecture (VAX)
              TTYOUTPUT           : terminal ecriture (VAX)
              Error               : stderr (VAX)
            Types de fichiers :
              TEXT                : fichier texte
              FILE OF Type        : fichier type (records binaires)
              FILE                : fichier non type (bloc I/O)
            Organisations de fichiers (VMS) :
              SEQUENTIAL          : acces sequentiel (defaut)
              RELATIVE            : acces relatif par numero
              INDEXED             : acces par cle (index)
            Operations fichier :
              Assign(f, nom)  (non-VAX, utilise pour DOS)
              Reset(f)        : ouvrir en lecture
              Reset(f, nom)   : ouvrir en lecture avec nom (VAX)
              Rewrite(f)      : ouvrir en ecriture
              Rewrite(f, nom) : ouvrir en ecriture avec nom (VAX)
              Close(f)        : fermer
              Open(f)         : ouvrir (VAX, mode par defaut)
              Open(f, nom)    : ouvrir avec nom (VAX)
              Open(f, nom, history) : ouvrir avec histo (NEW/OLD/ANY)
              EOF(f), EOLN(f) : fin de fichier / fin de ligne
              UFB(f)          : Ufo File Buffer (VAX, acces bas niveau)
            Options d ouverture VMS :
              OPEN(f, FILE_NAME:=nom)        : nom de fichier
              OPEN(f, HISTORY:=OLD)           : fichier existant
              OPEN(f, HISTORY:=NEW)           : nouveau fichier
              OPEN(f, HISTORY:=READONLY)      : lecture seule
              OPEN(f, ACCESS_METHOD:=DIRECT)  : acces direct
              OPEN(f, ACCESS_METHOD:=KEYED)   : acces par cle
              OPEN(f, RECORD_LENGTH:=n)       : taille record
              OPEN(f, RECORD_TYPE:=FIXED)     : records fixes
              OPEN(f, RECORD_TYPE:=VARIABLE)  : records variables
              OPEN(f, ERROR:=CONTINUE)        : ne pas planter sur erreur
              OPEN(f, SHARING:=READWRITE)     : partage du fichier
              OPEN(f, USER_ACTION:=proc)      : callback utilisateur
            Fonctions fichier VAX :
              Cursor(f)       : position courante dans un fichier texte
              Filename(f)     : nom du fichier associe (retourne string)
              IO_STATUS       : type enumere d etat d I/O (VAX)
              Status(f)       : statut du dernier I/O
              LineLimit(f, n) : limiter nombre de lignes par page
              Page(f)         : inserer saut de page (#12)
            Write/Read formatte :
              Write(f, expr:width)            : largeur minimale
              Write(f, expr:width:decimals)   : decimales
              WriteLn(f, expr, ...)            : avec saut de ligne
              Read(f, var, ...)                : lecture
              ReadLn(f, var, ...)              : lecture avec saut ligne
              WriteV(str, expr, ...)           : ecrire dans string
              ReadV(str, var, ...)             : lire depuis string
            Acces direct (VAX) :
              ReadRN(f, rec, n)  : lecture aleatoire au record n
              WriteRN(f, rec, n) : ecriture aleatoire au record n
              Find(f, n)         : positionner au record n
              Locate(f, n)       : positionner pour ecriture
              Delete(f)          : supprimer record courant (indexed)
              Update(f)          : mettre a jour record courant
              Truncate(f)        : tronquer fichier a position courante
            Buffer variable :
              f^     : valeur du buffer du fichier
              Get(f) : avancer le buffer
              Put(f) : ecrire le buffer
            Gestion erreurs I/O (VMS) :
              Status(f) retourne IO_STATUS
              ERROR:=CONTINUE dans OPEN pour continuer sur erreur
              $IO_STATUS constantes : IO_OK, IO_FILTER, IO_OVFL, etc.

  TODO 23 - GESTION DES ERREURS ET EXCEPTIONS
            Gestion des erreurs de compilation :
              ErrorMsg(msg) : erreur non fatale
              WarnMsg(msg)  : avertissement
              Expect(token) : token attendu absent
              SkipTo        : synchronisation apres erreur
            Erreurs a l execution :
              Division par zero : CALL _VXPRT_PANIC_DIV0
              Depassement de pile : verification frame > STACK_SIZE
              Pointeur nul : verification optionnelle ($OPTIONS CHECK)
              Overflow entier : verification si $OPTIONS CHECK actif
              Range check : verification bornes de sous-intervalles
            Exceptions VAX Pascal :
              CONDITION name;    : declarer une condition nommee
              CONDITION name VALUE n; : condition avec valeur numerique
              EXCEPTION          : bloc de traitement (debut)
              ON condname DO stmt; : traiter une condition specifique
              ANYOTHER           : traiter toute condition non captee
              ALLCONDITIONS      : traiter TOUTES les conditions
                (ALLCONDITIONS inclut meme les erreurs systeme,
                 ANYOTHER n inclut que les erreurs non-fatales)
              EXCEPTION_MESSAGE  : obtenir le message d erreur (string)
              EXCEPTION_VALUE    : obtenir la valeur de la condition
            Signalisation :
              SIGNAL(condname)   : lever une condition
              SIGNAL(condname, arg1, arg2) : lever avec arguments
              SIGNAL_STOP(condname) : lever et arreter (non-continuable)
              RESIGNAL           : re-propager la condition au handler parent
                Usage : dans ON .. DO RESIGNAL; ou dans ANYOTHER
            Structure du bloc TRY/EXCEPTION (VMS) :
              BEGIN
                (code protege)
              EXCEPTION
                ON cond1 DO stmt1;
                ON cond2 DO stmt2;
                ANYOTHER stmt3;
              END;
              Note : le bloc EXCEPTION est attache au BEGIN..END englobant
            Conditions predefinies VMS :
              SS$_ACCVIO       : access violation
              SS$_INTOVF       : integer overflow
              SS$_FLTOVF       : floating overflow
              SS$_FLTDIV       : floating divide by zero
              SS$_INTDIV       : integer divide by zero
              SS$_ROPRAND      : reserved operand
              SS$_HPARITH      : high performance arithmetic trap
              (Pour 8086 : mapper sur des codes d erreur internes)
            Implementation 8086 :
              Handler save/restore via segment _DATA
              Sauvegarder SP, BP, adresse retour dans _VXP_EXCFRAME
              CALL/RET pour les blocs exception
              RESIGNAL = JMP au handler parent dans la chaine
              Runtime _VXPRT_PANIC pour les erreurs fatales
              Runtime _VXPRT_SIGNAL pour lever une condition
              Runtime _VXPRT_EXCMSG pour obtenir le message

  TODO 24 - RUNTIME MINIMAL
            Routines d affichage :
              _VXPRT_PRINTSTR  : afficher chaine ASCIIZ (INT 21h/09h)
              _VXPRT_PRINTINT  : afficher entier signe (AX)
              _VXPRT_PRINTUINT : afficher entier non signe
              _VXPRT_PRINTLN   : afficher CRLF
              _VXPRT_PRINTCHAR : afficher un caractere (AL)
              _VXPRT_PRINTBOOL : afficher True/False
              _VXPRT_PRINTREAL : afficher reel (format d:w)
            Routines de lecture :
              _VXPRT_READCHAR  : lire un caractere (INT 21h/01h)
              _VXPRT_READINT   : lire un entier depuis stdin
              _VXPRT_READLINE  : lire une ligne complete
              _VXPRT_READSTR   : lire une chaine
            Routines de chaines :
              _VXPRT_CONCAT    : concatener deux chaines (+, double-pipe)
              _VXPRT_STRCPY    : copier chaine
              _VXPRT_STRCMP    : comparer deux chaines
              _VXPRT_STRLEN    : longueur d une chaine
              _VXPRT_SUBSTR    : extraire sous-chaine (VAX)
              _VXPRT_INDEX     : trouver position sous-chaine (VAX)
              _VXPRT_VERIFY    : verifier caracteres (VAX)
              _VXPRT_SEARCH    : rechercher dans chaine (VAX)
              _VXPRT_UPPERCASE : convertir en majuscule
              _VXPRT_LOWERCASE : convertir en minuscule
              _VXPRT_DELETE    : supprimer partie de chaine
              _VXPRT_INSERT    : inserer dans chaine
              _VXPRT_TRIM      : supprimer espaces de fin
              _VXPRT_PAD       : completer chaine avec caractere
            Routines VARYING :
              _VXPRT_VARY_ASSIGN : affecter string a VARYING
              _VXPRT_VARY_CONCAT : concatener VARYING
              _VXPRT_VARY_LENGTH : obtenir .LENGTH
              _VXPRT_VARY_BODY   : obtenir .BODY
              _VXPRT_VARY_SUBSTR : sous-chaine de VARYING
              _VXPRT_VARY_CMP    : comparer deux VARYING
            Routines arithmetiques :
              _VXPRT_POWI      : exponentiation entiere
              _VXPRT_RANDOM    : nombre pseudo-aleatoire
              _VXPRT_SEED      : initialiser la graine
              _VXPRT_ABS       : valeur absolue
              _VXPRT_SQR       : carre
              _VXPRT_MAX       : maximum de deux entiers
              _VXPRT_MIN       : minimum de deux entiers
            Routines d allocation :
              _VXPRT_NEW       : allouer memoire sur le heap
              _VXPRT_DISPOSE   : liberer memoire
              _VXPRT_ZERO      : mettre a zero un bloc memoire
              _VXPRT_FILL      : remplir un bloc memoire
            Routines d erreur et exceptions :
              _VXPRT_PANIC     : erreur fatale + arret
              _VXPRT_PANIC_DIV0: division par zero
              _VXPRT_PANIC_RNG : range check error
              _VXPRT_PANIC_OVF : overflow error
              _VXPRT_PANIC_NIL : nil pointer dereference
              _VXPRT_SIGNAL    : lever une condition
              _VXPRT_RESIGNAL  : propager condition au parent
              _VXPRT_EXCMSG    : obtenir message d exception
              _VXPRT_ASSERT    : verifier assertion
            Routines de fichiers :
              _VXPRT_FOPEN     : ouvrir fichier (INT 21h/3Dh)
              _VXPRT_FCLOSE    : fermer fichier (INT 21h/3Eh)
              _VXPRT_FREAD     : lire depuis fichier
              _VXPRT_FWRITE    : ecrire dans fichier
              _VXPRT_FCREATE   : creer fichier (INT 21h/3Ch)
              _VXPRT_FDELETE   : supprimer fichier (INT 21h/41h)
            Routines de date/heure :
              _VXPRT_DATE      : date courante (INT 21h/2Ah)
              _VXPRT_TIME      : heure courante (INT 21h/2Ch)
              _VXPRT_CLOCK     : centisecondes depuis minuit
            Routines d ensembles :
              _VXPRT_SET_UNION : union de deux ensembles (OR)
              _VXPRT_SET_INTER : intersection (AND)
              _VXPRT_SET_DIFF  : difference (AND NOT)
              _VXPRT_SET_IN    : test d appartenance (BT)
              _VXPRT_SET_CARD  : cardinalite (count bits)
              _VXPRT_SET_EQ    : egalite de deux ensembles
              _VXPRT_SET_SUB   : sous-ensemble
            Stubs appels VMS (SMG$/LIB$/SYS$) :
              _VXPRT_VMS_STUB  : stub generique (affiche nom + retourne 1)
              Chaque appel SMG$/LIB$/SYS$ genere EXTRN _VMS_name
              ou un stub local qui simule le comportement
            Donnees internes :
              _VXP_HEAP, _VXP_HEAPTOP : tas statique
              _VXP_SEED : graine pour RANDOM
              _VXP_EXCFRAME : cadre d exception courant (SP,BP,IP)
              _VXP_EXCCHAIN : chaine de handlers d exception
              _VXPRT_CRLF, _VXPRT_STRBUF, _VXPRT_NUMBUF, etc.
            RuntimeEmitted : flag pour n emettre qu une seule fois

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _VXPF_main apres _TEXT ENDS / _DATA ENDS
            Run : pipeline complet :
              1. ParseArgs et ouverture des fichiers
              2. EmitHeader (_TEXT SEGMENT, _VXPF_main:, MOV AX,_DATA)
              3. Boucle de parsing : PROGRAM/MODULE, declarations, corps
              4. Emission MOV AX,4C00h / INT 21h (fin du programme)
              5. EmitRuntime (routines _VXPRT_)
              6. _TEXT ENDS
              7. EmitDataSeg (_DATA SEGMENT, constantes, variables, _DATA ENDS)
              8. END _VXPF_main
            Fichiers exemples dans SAMPLES\VAXPASCAL\ :
              hello.pas         (programme minimal WriteLn)
              test_var.pas      (declarations de variables, types)
              test_const.pas    (constantes, litteral octal)
              test_expr.pas     (expressions, operateurs, exponentiation)
              test_types.pas    (types, enumerations, subranges, PREC)
              test_string.pas   (STRING, VARYING, double-pipe, SUBSTR)
              test_func.pas     (functions, procedures, RETURN)
              test_if.pas       (IF/THEN/ELSE, CASE/OTHERS)
              test_loop.pas     (FOR, WHILE, REPEAT, LOOP..END, BY)
              test_array.pas    (tableaux, DIMENSION, UPPERBOUND, conformants)
              test_record.pas   (records, WITH, variant, POS, ALIGNED)
              test_io.pas       (I/O, TTY, TTYOUTPUT, OPEN/CLOSE, status)
              test_pointer.pas  (pointeurs, NEW, ADDRESS, PTR)
              test_set.pas      (ensembles, IN, operations, CARD)
              test_module.pas   (MODULE, [EXTERNAL], [GLOBAL], [INHERIT])
              test_include.pas  ($INCLUDE, $TITLE, $PAGE, $SYSTEM)
              test_except.pas   (EXCEPTION, ON, CONDITION, RESIGNAL)
              test_static.pas   (STATIC VAR, persistance, VOLATILE)
              test_varying.pas  (VARYING, .LENGTH, .BODY, concat)
              test_preproc.pas  ($IF, $IFNOT, $DEFINE, $END, $ELSE)
              test_label.pas    (LABEL, GOTO, GOTO non-local)
              test_value.pas    (VALUE section, initialisations)
              test_named.pas    (parametres nommes, SMG$ stubs)
              test_fileorg.pas  (FILE OF, SEQUENTIAL, RELATIVE, acces direct)
              test_coerce.pas   (coercitions, UNSAFE, SPECIAL(COERCIONS))
              test_datetime.pas (DATE, TIME, CLOCK, WALLCLOCK)
              test_assert.pas   (ASSERT, $OPTIONS CHECK, verifications)
              test_procvar.pas  (types proceduraux, pointeurs de fonctions)
              test_smg.pas      (appels SMG$, stubs VMS)
              test_converge.pas (programme complet : toutes fonctionnalites)
            Smoke tests : VAXPAS86.EXE -v SAMPLES\VAXPASCAL\test_*.pas

  ============================================================ *)

Program VAXPAS86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  VXP_VERSION = '1.0';
  VXP_DATE    = '2026-03-07';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}8{$ELSE}4{$ENDIF};
  MAX_DEFINE    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_FIELD     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_ENUM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_WITH      = 8;
  STACK_SIZE    = 1024;
  FRAME_WARN    = 256;
  NEST_MAX      = 4;

  { Prefixes de nommage ASM }
  VXP_VAR_PFX   = '_VXP_';
  VXP_FN_PFX    = '_VXPF_';
  VXP_STR_PFX   = '_VXPK_';
  VXP_RT_PFX    = '_VXPRT_';
  VXP_LBL_PFX   = '_VXPL_';
  VXP_ARR_PFX   = '_VXPA_';
  VXP_REC_PFX   = '_VXPR_';
  VXP_ENUM_PFX  = '_VXPE_';
  VXP_MOD_PFX   = '_VXPM_';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs }
  TY_IDX_INTEGER  = 0;
  TY_IDX_WORD     = 1;
  TY_IDX_BYTE     = 2;
  TY_IDX_CHAR     = 3;
  TY_IDX_BOOLEAN  = 4;
  TY_IDX_STRING   = 5;
  TY_IDX_REAL     = 6;
  TY_IDX_DOUBLE   = 7;
  TY_IDX_POINTER  = 8;
  TY_IDX_NIL      = 9;
  TY_IDX_TEXT      = 10;
  TY_IDX_UNSIGNED  = 11;
  TY_IDX_VARYING   = 12;
  TY_PRIM_COUNT    = 13;
  TY_UNKNOWN       = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;
    OutFile   : TString;
    Verbose   : Boolean;
    DebugMode : Boolean;
    Warnings  : Boolean;
  End;

  { ---- Tokens VAX Pascal ---------------------------------- }
  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_REAL,
    TK_STRING,
    TK_CHAR,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT,
    TK_OCTAL,
    TK_ATTR_OPEN,
    TK_ATTR_CLOSE
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;
    IntVal   : LongInt;
    RealVal  : Real;
    Line     : Integer;
    Col      : Integer;
  End;

  { ---- Segment de donnees --------------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
    ElemSize  : Integer;
    RecSize   : Integer;
  End;

  { ---- Valeurs d expression ------------------------------- }
  TExprKind = (
    EK_NONE,
    EK_IMM,
    EK_AX,
    EK_MEM
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;
  End;

  { ---- Genre de type -------------------------------------- }
  TTypeKind = (
    TKP_INTEGER,
    TKP_WORD,
    TKP_BYTE,
    TKP_CHAR,
    TKP_BOOLEAN,
    TKP_STRING,
    TKP_REAL,
    TKP_DOUBLE,
    TKP_ARRAY,
    TKP_RECORD,
    TKP_ENUM,
    TKP_SUBRANGE,
    TKP_POINTER,
    TKP_NIL,
    TKP_TEXT,
    TKP_VARYING,
    TKP_SET,
    TKP_FILE,
    TKP_SCHEMA,
    TKP_PROCEDURAL,
    TKP_VOID
  );

  { ---- Champ de record ----------------------------------- }
  TFieldRec = Record
    Name    : TString;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  { ---- Valeur d enumeration ------------------------------ }
  TEnumValRec = Record
    Name  : TString;
    Value : Integer;
  End;

  { ---- Enregistrement de type ---------------------------- }
  TTypeRec = Record
    Kind        : TTypeKind;
    Size        : Integer;
    BaseTypeIdx : Integer;
    Lo          : LongInt;
    Hi          : LongInt;
    FieldCount  : Integer;
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    EnumCount   : Integer;
    Enums       : Array[0..MAX_ENUM - 1] Of TEnumValRec;
    Packed_     : Boolean;
    Precision   : Integer;
  End;

  { ---- Categorie de symbole ------------------------------ }
  TSymCat = (
    SC_VAR,
    SC_CONST,
    SC_TYPED_CONST,
    SC_PARAM,
    SC_VARPARAM,
    SC_FUNC,
    SC_PROC,
    SC_TYPE,
    SC_FIELD,
    SC_ENUM_VAL,
    SC_LABEL,
    SC_STATIC,
    SC_EXTERNAL,
    SC_GLOBAL,
    SC_PUBLIC,
    SC_MODULE,
    SC_CONDITION
  );

  { ---- Enregistrement symbole ---------------------------- }
  TSymRec = Record
    Name        : TString;
    MangledName : TString;
    Cat         : TSymCat;
    TypeIdx     : Integer;
    Offset      : Integer;
    ScopeLevel  : Integer;
    ScopeId     : Integer;
    IsForward   : Boolean;
    IsLocal     : Boolean;
    ImmVal      : LongInt;
    DataIdx     : Integer;
    ParamCnt    : Integer;
    VarParamMask: LongInt;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Emetteur ASM }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;
  LexSrcFName : TString;

  { Segment de donnees }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Variables et affectations }
  CurFrameOffset    : Integer;
  PendingAssignName : TString;
  HasPendingAssign  : Boolean;

  { Pile de boucles pour break/continue }
  LoopBreakLbl    : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl     : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop         : Integer;

  { Fonctions et procedures }
  CurFuncName     : TString;
  CurFuncRetOfs   : Integer;
  CurRetLabel     : TString;
  CurNestLevel    : Integer;
  CurParamBytes   : Integer;
  MainBodyEmitted : Boolean;
  RuntimeEmitted  : Boolean;

  { Pile with pour records }
  WithSymIdx      : Array[0..MAX_WITH - 1] Of Integer;
  WithTop         : Integer;

  { Directives et inclusions }
  IncSavedFName   : Array[0..MAX_INCLUDE - 1] Of TString;
  IncSavedFLine   : Array[0..MAX_INCLUDE - 1] Of Integer;
  IncSavedLine    : Array[0..MAX_INCLUDE - 1] Of String;
  IncSavedLineNo  : Array[0..MAX_INCLUDE - 1] Of Integer;
  IncSavedColNo   : Array[0..MAX_INCLUDE - 1] Of Integer;
  IncSavedEOF     : Array[0..MAX_INCLUDE - 1] Of Boolean;
  IncTop          : Integer;
  DefineTab       : Array[0..MAX_DEFINE - 1] Of TString;
  DefineCount     : Integer;

  { Module ou Programme }
  IsModule        : Boolean;
  ModuleName      : TString;

{ ============================================================
  UTILITAIRES DE CHAINES
  ============================================================ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function BPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    BPOfs := '[BP+' + IntToStr(Ofs) + ']'
  Else
    BPOfs := '[BP' + IntToStr(Ofs) + ']';
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
End;

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
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ ============================================================
  GESTION DES ERREURS ET MESSAGES
  ============================================================ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('VAXPAS86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('VAXPAS86: warning: ', Msg);
  Inc(WarnCount);
End;

Procedure ErrorMsg(Const Msg : TString);
Begin
  WriteLn('VAXPAS86: erreur ligne ', LexLineNo, ' : ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs (' + IntToStr(MAX_ERRORS) + '), arret');
End;

{ ============================================================
  BANNIERE ET USAGE
  ============================================================ }

Procedure ShowBanner;
Begin
  WriteLn('VAXPAS86 v', VXP_VERSION, ' (', VXP_DATE, ')');
  WriteLn('Compilateur VAX Pascal -> assembleur 8086');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)  Cible: MASM .MODEL SMALL');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('VAXPAS86 - Cette commande permet de lancer le compilateur de ',
          'VAX Pascal pour l''assembleur du microprocesseur 8086.');
  WriteLn;
  WriteLn('Syntaxe : VAXPAS86 <source.pas> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.pas : fichier VAX Pascal source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

{ ============================================================
  OPTIONS ET ARGUMENTS
  ============================================================ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('VAXPAS86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('VAXPAS86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('VAXPAS86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .pas }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.pas') Then
    WarnMsg('extension attendue .pas, trouvee: ' + Ext);

  { Fichier de sortie par defaut : meme nom avec .asm }
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ============================================================
  NETTOYAGE
  ============================================================ }

Procedure Cleanup;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  INITIALISATION GENERALE
  ============================================================ }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  LexSrcFName := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  DataCount   := 0;
  LabelGenSeq := 0;
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  TypeCount := 0;
  CurFrameOffset    := 0;
  HasPendingAssign  := False;
  PendingAssignName := '';
  LoopTop := -1;
  CurFuncName   := '';
  CurFuncRetOfs := 0;
  CurRetLabel   := '';
  CurNestLevel  := 0;
  CurParamBytes := 0;
  MainBodyEmitted := False;
  RuntimeEmitted  := False;
  WithTop := -1;
  IncTop        := -1;
  DefineCount   := 0;
  IsModule      := False;
  ModuleName    := '';
End;

{ ============================================================
  PIPELINE DE COMPILATION (STUB POUR TODO 02+)
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  { Verifier que le fichier source existe }
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Creer le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;

  { -- TODO 02+ : Lexeur, Parseur, Emetteur -- }
  WriteLn('VAXPAS86: compilation de ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('VAXPAS86: (pas encore implemente - stubs TODO 02 a 25)');

  { Ecrire un fichier ASM minimal }
  WriteLn(OutF, '; Genere par VAXPAS86 v' + VXP_VERSION);
  WriteLn(OutF, '; Source : ' + Opts.SrcFile);
  WriteLn(OutF, '        .MODEL  SMALL');
  WriteLn(OutF, '        .STACK  ' + IntToStr(STACK_SIZE));
  WriteLn(OutF, '');
  WriteLn(OutF, '_DATA   SEGMENT WORD PUBLIC ''DATA''');
  WriteLn(OutF, '_DATA   ENDS');
  WriteLn(OutF, '');
  WriteLn(OutF, '_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  WriteLn(OutF, '        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  WriteLn(OutF, VXP_FN_PFX + 'main PROC NEAR');
  WriteLn(OutF, '        MOV     AX, _DATA');
  WriteLn(OutF, '        MOV     DS, AX');
  WriteLn(OutF, '        MOV     AX, 4C00h');
  WriteLn(OutF, '        INT     21h');
  WriteLn(OutF, VXP_FN_PFX + 'main ENDP');
  WriteLn(OutF, '_TEXT   ENDS');
  WriteLn(OutF, '        END     ' + VXP_FN_PFX + 'main');

  Cleanup;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
  If (ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
     (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
     (ParamStr(1) = '/H') Then
  Begin
    ShowUsage;
    Halt(0);
  End;
  ParseArgs;
  Run;
END.
