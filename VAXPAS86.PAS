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
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC,
               DK_ARRAY_INIT);

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

(* Helpers pour crochets - le lexeur peut emettre TK_PUNCT ou TK_ATTR *)
Function IsOpenBracket : Boolean;
Begin
  IsOpenBracket := ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[')) Or
                   (CurToken.Kind = TK_ATTR_OPEN);
End;

Function IsCloseBracket : Boolean;
Begin
  IsCloseBracket := ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']')) Or
                    (CurToken.Kind = TK_ATTR_CLOSE);
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
  LEXEUR - TODO 02 : ANALYSE LEXICALE VAX PASCAL
  ============================================================ }

{ Forward declarations pour references croisees }
Procedure LexNextLine; Forward;
Procedure IncludePop; Forward;
Procedure LexHandleDollarDirective; Forward;
Function  LexHandlePercentDirective : Boolean; Forward;

{ ---- IsKeyword : teste si un identifiant est un mot-cle ----- }
Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsKeyword :=
    { Mots-cles Pascal standard }
    (L = 'program')    Or (L = 'begin')     Or (L = 'end')       Or
    (L = 'var')        Or (L = 'const')     Or (L = 'type')      Or
    (L = 'if')         Or (L = 'then')      Or (L = 'else')      Or
    (L = 'while')      Or (L = 'do')        Or (L = 'for')       Or
    (L = 'to')         Or (L = 'downto')    Or (L = 'repeat')    Or
    (L = 'until')      Or (L = 'case')      Or (L = 'of')        Or
    (L = 'function')   Or (L = 'procedure') Or (L = 'forward')   Or
    (L = 'array')      Or (L = 'record')    Or (L = 'string')    Or
    (L = 'integer')    Or (L = 'boolean')   Or (L = 'char')      Or
    (L = 'byte')       Or (L = 'word')      Or (L = 'real')      Or
    (L = 'nil')        Or (L = 'true')      Or (L = 'false')     Or
    (L = 'not')        Or (L = 'and')       Or (L = 'or')        Or
    (L = 'xor')        Or (L = 'div')       Or (L = 'mod')       Or
    (L = 'shl')        Or (L = 'shr')       Or (L = 'in')        Or
    (L = 'with')       Or (L = 'set')       Or (L = 'file')      Or
    (L = 'write')      Or (L = 'writeln')   Or (L = 'read')      Or
    (L = 'readln')     Or (L = 'break')     Or (L = 'continue')  Or
    (L = 'exit')       Or (L = 'halt')      Or (L = 'packed')    Or
    { Mots-cles VAX Pascal supplementaires }
    (L = 'module')     Or (L = 'varying')   Or (L = 'return')    Or
    (L = 'loop')       Or (L = 'others')    Or (L = 'otherwise') Or
    (L = 'andif')      Or (L = 'orif')      Or (L = 'value')     Or
    (L = 'static')     Or (L = 'external')  Or (L = 'global')    Or
    (L = 'public')     Or (L = 'condition') Or (L = 'exception') Or
    (L = 'stop')       Or (L = 'origin')    Or (L = 'prec')      Or
    (L = 'by')         Or (L = 'label')     Or (L = 'goto')      Or
    (L = 'signal')     Or (L = 'resignal')  Or (L = 'on')        Or
    (L = 'anyother')   Or (L = 'allconditions') Or
    (L = 'double')     Or (L = 'unsigned')  Or (L = 'single')    Or
    (L = 'writev')     Or (L = 'readv')  Or (L = 'next');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF        : Write('EOF');
    TK_INTEGER    : Write('INT(', T.IntVal, ')');
    TK_REAL       : Write('REAL(', T.Val, ')');
    TK_STRING     : Write('STR(''', T.Val, ''')');
    TK_CHAR       : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT      : Write('IDENT(', T.Val, ')');
    TK_KEYWORD    : Write('KW(', T.Val, ')');
    TK_OP         : Write('OP(', T.Val, ')');
    TK_PUNCT      : Write('PUNCT(', T.Val, ')');
    TK_OCTAL      : Write('OCT(', T.IntVal, ')');
    TK_ATTR_OPEN  : Write('ATTR[');
    TK_ATTR_CLOSE : Write(']ATTR');
  End;
  WriteLn;
End;

{ ---- Fonctions de test sur les caracteres ------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9')) Or
                 (Ch = '$');  { VMS : $ valide dans identifiants }
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsOctDigit(Ch : Char) : Boolean;
Begin
  IsOctDigit := (Ch >= '0') And (Ch <= '7');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    { Si on est dans un fichier inclus, depiler }
    If IncTop >= 0 Then
    Begin
      IncludePop;
      Exit;
    End;
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- IncludePush / IncludePop ------------------------------ }

Procedure IncludePush(Const FileName : TString);
Begin
  If IncTop >= MAX_INCLUDE - 1 Then
  Begin
    WarnMsg('profondeur d''inclusion maximale atteinte');
    Exit;
  End;
  Inc(IncTop);
  IncSavedFName[IncTop]  := LexSrcFName;
  IncSavedFLine[IncTop]  := LexLineNo;
  IncSavedLine[IncTop]   := LexLine;
  IncSavedLineNo[IncTop] := LexLineNo;
  IncSavedColNo[IncTop]  := LexColNo;
  IncSavedEOF[IncTop]    := LexEOF;
  Close(LexSrcF);
  {$I-}
  Assign(LexSrcF, FileName);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('impossible d''ouvrir le fichier include: ' + FileName);
    Assign(LexSrcF, IncSavedFName[IncTop]);
    Reset(LexSrcF);
    Dec(IncTop);
    Exit;
  End;
  LexSrcFName := FileName;
  LexOpened := True;
  LexLine   := '';
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexNextLine;
End;

Procedure IncludePop;
Var
  I : Integer;
  Dummy : String;
Begin
  If IncTop < 0 Then Exit;
  Close(LexSrcF);
  Assign(LexSrcF, IncSavedFName[IncTop]);
  Reset(LexSrcF);
  For I := 1 To IncSavedFLine[IncTop] Do
  Begin
    If Not EOF(LexSrcF) Then
      ReadLn(LexSrcF, Dummy);
  End;
  LexSrcFName := IncSavedFName[IncTop];
  LexLine   := IncSavedLine[IncTop];
  LexLineNo := IncSavedLineNo[IncTop];
  LexColNo  := IncSavedColNo[IncTop];
  LexEOF    := IncSavedEOF[IncTop];
  Dec(IncTop);
End;

(* ---- LexSkipBraceComment : sauter accolade-commentaire ----- *)
(* Detecte dollar-directive pour les directives de compilation.   *)
Procedure LexSkipBraceComment;
Begin
  (* Detecter dollar-directive de compilation *)
  If (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] = '$') Then
  Begin
    LexHandleDollarDirective;
    Exit;
  End;
  Inc(LexColNo); (* sauter accolade ouvrante *)
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = '}' Then
    Begin
      Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipParenStarComment : sauter paren-star ... star-paren }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '(' et '*' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- Define management -------------------------------------- }

Function DefineDefined(Const Name : TString) : Boolean;
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  DefineDefined := False;
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineDefined := True;
      Exit;
    End;
End;

Procedure DefineAdd(Const Name : TString);
Var
  N : TString;
Begin
  N := StrUpperCase(Name);
  If DefineDefined(N) Then Exit;
  If DefineCount >= MAX_DEFINE Then
  Begin
    WarnMsg('trop de symboles $DEFINE');
    Exit;
  End;
  DefineTab[DefineCount] := N;
  Inc(DefineCount);
End;

Procedure DefineRemove(Const Name : TString);
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineTab[I] := DefineTab[DefineCount - 1];
      Dec(DefineCount);
      Exit;
    End;
End;

{ ---- LexSkipCondFalse : sauter un bloc conditionnel faux ---- }
Procedure LexSkipCondFalse;
Var
  Depth : Integer;
  P     : Integer;
  Dir   : TString;
Begin
  Depth := 1;
  While (Depth > 0) And (Not LexEOF) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    If LexLine[LexColNo] = '{' Then
    Begin
      P := LexColNo + 1;
      If (P <= Length(LexLine)) And (LexLine[P] = '$') Then
      Begin
        Inc(P);
        Dir := '';
        While (P <= Length(LexLine)) And (LexLine[P] <> '}') And
              (LexLine[P] <> ' ') Do
        Begin
          Dir := Dir + UpCase(LexLine[P]);
          Inc(P);
        End;
        If (Dir = 'IFDEF') Or (Dir = 'IFNDEF') Or
           (Dir = 'IF') Or (Dir = 'IFNOT') Then
          Inc(Depth)
        Else If (Dir = 'ENDIF') Or (Dir = 'END') Then
        Begin
          Dec(Depth);
          If Depth = 0 Then
          Begin
            While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
              Inc(P);
            LexColNo := P + 1;
            Exit;
          End;
        End
        Else If (Dir = 'ELSE') And (Depth = 1) Then
        Begin
          While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
            Inc(P);
          LexColNo := P + 1;
          Exit;
        End;
      End;
      { Sauter toute l accolade }
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
        Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
        Inc(LexColNo);
    End
    Else
      Inc(LexColNo);
  End;
End;

(* ---- LexHandleDollarDirective : traiter dollar-directives --- *)
(* Gere INCLUDE/I, DEFINE, UNDEF, IFDEF/IFNDEF/IF/IFNOT,         *)
(* ELSE, ENDIF/END, TITLE, PAGE, HEADER, OPTIONS, SYSTEM,         *)
(* SOURCE, NOSOURCE, MODE. Les autres sont ignores.               *)
Procedure LexHandleDollarDirective;
Var
  Dir  : TString;
  Arg  : TString;
Begin
  Inc(LexColNo);  (* sauter accolade ouvrante *)
  Inc(LexColNo);  (* sauter dollar *)
  Dir := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') And
        (LexLine[LexColNo] <> ' ') Do
  Begin
    Dir := Dir + UpCase(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  { Sauter espaces }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] = ' ') Do
    Inc(LexColNo);
  { Lire argument }
  Arg := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') Do
  Begin
    Arg := Arg + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
    Delete(Arg, Length(Arg), 1);
  (* Consommer accolade fermante *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
    Inc(LexColNo);

  { Dispatcher }
  If (Dir = 'I') Or (Dir = 'INCLUDE') Then
  Begin
    If (Length(Arg) >= 2) And
       ((Arg[1] = '''') Or (Arg[1] = '"')) Then
    Begin
      Delete(Arg, 1, 1);
      If (Length(Arg) > 0) And
         ((Arg[Length(Arg)] = '''') Or (Arg[Length(Arg)] = '"')) Then
        Delete(Arg, Length(Arg), 1);
    End;
    If Length(Arg) > 0 Then
      IncludePush(Arg)
    Else
      WarnMsg('nom de fichier attendu pour $INCLUDE');
  End
  Else If Dir = 'SYSTEM' Then
  Begin
    { $SYSTEM fichier : inclusion systeme (ignore le path VMS) }
    If (Length(Arg) >= 2) And
       ((Arg[1] = '''') Or (Arg[1] = '"')) Then
    Begin
      Delete(Arg, 1, 1);
      If (Length(Arg) > 0) And
         ((Arg[Length(Arg)] = '''') Or (Arg[Length(Arg)] = '"')) Then
        Delete(Arg, Length(Arg), 1);
    End;
    WarnMsg('$SYSTEM ' + Arg + ' ignore (pas de support systeme VMS)');
  End
  Else If Dir = 'DEFINE' Then
    DefineAdd(Arg)
  Else If Dir = 'UNDEF' Then
    DefineRemove(Arg)
  Else If Dir = 'IFDEF' Then
  Begin
    If Not DefineDefined(Arg) Then
      LexSkipCondFalse;
  End
  Else If Dir = 'IFNDEF' Then
  Begin
    If DefineDefined(Arg) Then
      LexSkipCondFalse;
  End
  Else If (Dir = 'IF') Then
  Begin
    { $IF identifier }
    If Not DefineDefined(Arg) Then
      LexSkipCondFalse;
  End
  Else If (Dir = 'IFNOT') Then
  Begin
    If DefineDefined(Arg) Then
      LexSkipCondFalse;
  End
  Else If Dir = 'ELSE' Then
    LexSkipCondFalse
  Else If (Dir = 'ENDIF') Or (Dir = 'END') Then
  Begin
    { Fin de bloc conditionnel }
  End
  Else If Dir = 'MODE' Then
  Begin
    { Ignore pour compatibilite FPC }
  End
  Else If (Dir = 'TITLE') Or (Dir = 'HEADER') Then
  Begin
    (* $TITLE texte / $HEADER texte : listing, ignore *)
    If Opts.DebugMode Then
      WriteLn('  [preproc] ', Dir, ' = ', Arg);
  End
  Else If Dir = 'PAGE' Then
  Begin
    (* $PAGE : saut de page listing, ignore *)
  End
  Else If Dir = 'LENGTH' Then
  Begin
    (* $LENGTH=n : longueur de page listing, ignore *)
  End
  Else If Dir = 'WIDTH' Then
  Begin
    (* $WIDTH=n : largeur de page listing, ignore *)
  End
  Else If (Dir = 'SOURCE') Or (Dir = 'NOSOURCE') Then
  Begin
    (* $SOURCE / $NOSOURCE : listing source, ignore *)
  End
  Else If Dir = 'OPTIONS' Then
  Begin
    (* $OPTIONS directives : SPECIAL, NOCHECK, CHECK, etc. ignore *)
    If Opts.DebugMode Then
      WriteLn('  [preproc] $OPTIONS ', Arg, ' (ignore)');
  End
  Else
  Begin
    (* Directive inconnue : avertir et ignorer *)
    If Opts.Warnings Then
      WarnMsg('directive inconnue: $' + Dir);
  End;
End;

(* ---- LexHandlePercentDirective : directives VMS % ---------- *)
(* Gere %INCLUDE, %DICTIONARY, %DESCR, %REF, %STDESCR, %IMMED   *)
(* Retourne True si un token a ete produit (DESCR/REF/etc.),     *)
(* False si la directive a ete consommee sans produire de token.  *)
Function LexHandlePercentDirective : Boolean;
Var
  Dir : TString;
  Arg : TString;
  QuC : Char;
Begin
  LexHandlePercentDirective := False;
  Inc(LexColNo);  (* sauter le % *)
  Dir := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    Dir := Dir + UpCase(LexLine[LexColNo]);
    Inc(LexColNo);
  End;

  If (Dir = 'INCLUDE') Then
  Begin
    (* %INCLUDE 'fichier' : inclusion VMS native *)
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ' ') Do
      Inc(LexColNo);
    Arg := '';
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '''') Or (LexLine[LexColNo] = '"')) Then
    Begin
      QuC := LexLine[LexColNo];
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> QuC) Do
      Begin
        Arg := Arg + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      If LexColNo <= Length(LexLine) Then
        Inc(LexColNo);
    End;
    If Length(Arg) > 0 Then
      IncludePush(Arg)
    Else
      WarnMsg('nom de fichier attendu pour %INCLUDE');
  End
  Else If Dir = 'DICTIONARY' Then
  Begin
    (* %DICTIONARY 'CDD_PATH' : charge definitions CDD, ignore *)
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ' ') Do
      Inc(LexColNo);
    Arg := '';
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Begin
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '''') Do
      Begin
        Arg := Arg + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      If LexColNo <= Length(LexLine) Then
        Inc(LexColNo);
    End;
    WarnMsg('%DICTIONARY ' + Arg + ' ignore (CDD non supporte)');
  End
  Else If (Dir = 'DESCR') Or (Dir = 'REF') Or
          (Dir = 'STDESCR') Or (Dir = 'IMMED') Then
  Begin
    (* Mecanismes de passage de parametres VMS : retourner comme token *)
    CurToken.Kind   := TK_KEYWORD;
    CurToken.Val    := '%' + Dir;
    CurToken.IntVal := 0;
    LexHandlePercentDirective := True;
  End
  Else
  Begin
    If Opts.Warnings Then
      WarnMsg('directive inconnue: %' + Dir);
  End;
End;

(* ---- LexScanIdent : scanner un identificateur ou mot-cle --- *)
(* Le dollar est un caractere valide pour les identifiants VMS   *)
(* (ex: SMG$Create_Virtual_Display, LIB$Signal)                  *)
Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  If IsKeyword(S) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := StrLowerCase(S);
  End
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Decimaux (123), octaux (777B), reels (3.14, 1.5E3)            }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  IsOctal : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
  AllOct  : Boolean;
  SaveCol : Integer;
Begin
  N       := 0;
  IsReal  := False;
  IsOctal := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  AllOct  := True;

  { Sauvegarder position pour detection octale }
  SaveCol := LexColNo;

  { Scanner la partie entiere }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    If LexLine[LexColNo] > '7' Then AllOct := False;
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Test suffixe octal B/b : 777B signifie octal }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'B') Or (LexLine[LexColNo] = 'b')) And
     AllOct Then
  Begin
    { Recalculer la valeur en octal }
    N := 0;
    LexColNo := SaveCol;
    While (LexColNo <= Length(LexLine)) And
          IsOctDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 8 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
    Inc(LexColNo); { sauter le B/b }
    CurToken.Kind    := TK_OCTAL;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
    Exit;
  End;

  { Partie decimale .ddd (pas '..' qui est le token de plage) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] <> '.') And
     IsDigit(LexLine[LexColNo + 1]) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant E[+-]ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.Kind    := TK_REAL;
    CurToken.RealVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanHexNumber : scanner #XFF ou #xff ----------------- }
Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_INTEGER;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ---- LexScanOctalNumber : scanner #O377 ---------------------- }
Procedure LexScanOctalNumber;
Var
  N : LongInt;
Begin
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsOctDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 8 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_OCTAL;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : chaine Pascal entre quotes simples ------ }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(LexColNo);
      End
      Else
        Break;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

(* ---- LexScanCharLit : caractere #nn, #hex, #Onnn, #Xnn ----- *)
Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter '#' }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo); (* hex TP-style *)
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else If (LexColNo <= Length(LexLine)) And
            ((LexLine[LexColNo] = 'X') Or (LexLine[LexColNo] = 'x')) Then
    Begin
      Inc(LexColNo); { hex VAX-style #XFF }
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else If (LexColNo <= Length(LexLine)) And
            ((LexLine[LexColNo] = 'O') Or (LexLine[LexColNo] = 'o')) Then
    Begin
      Inc(LexColNo); { octal VAX-style #O377 }
      While (LexColNo <= Length(LexLine)) And IsOctDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 8 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      { decimal #13 }
      While (LexColNo <= Length(LexLine)) And
            IsDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End;
    If Length(S) < MAX_STR Then
      S := S + Chr(V And $FF);
  End;

  { Si suivi d une chaine 'xxx', concatener }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
    Inc(LexColNo);
    While LexColNo <= Length(LexLine) Do
    Begin
      If LexLine[LexColNo] = '''' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
        Begin
          If Length(S) < MAX_STR Then S := S + '''';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d un autre #nn }
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
    Begin
      Inc(LexColNo);
      V := 0;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
      Begin
        Inc(LexColNo);
        While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End
      Else
      Begin
        While (LexColNo <= Length(LexLine)) And
              IsDigit(LexLine[LexColNo]) Do
        Begin
          V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
          Inc(LexColNo);
        End;
      End;
      If Length(S) < MAX_STR Then
        S := S + Chr(V And $FF);
    End;
  End;

  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
  Begin
    CurToken.Kind   := TK_STRING;
    CurToken.IntVal := 0;
  End;
  CurToken.Val     := S;
  CurToken.RealVal := 0.0;
End;

{ ---- LexInit / LexClose ------------------------------------ }

Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
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

{ ---- LexNextToken : scanner principal VAX Pascal ------------ }
Procedure LexNextToken;
Var
  Ch : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
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

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    (* Commentaire accolade ou directive dollar *)
    Else If Ch = '{' Then
      LexSkipBraceComment

    { Commentaire paren-star ... star-paren }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
      LexSkipParenStarComment

    (* Caractere literal #nn, #hex, #Onnn, #Xnn *)
    Else If Ch = '#' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Chaine Pascal 'xxx' }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    (* Directive VMS avec prefixe % *)
    Else If Ch = '%' Then
    Begin
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      If LexHandlePercentDirective Then
        Scanning := False;
      (* sinon %INCLUDE/%DICTIONARY consomme, on continue *)
    End

    { Identificateur ou mot-cle (lettres, _, et $ pour VMS) }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre decimal (peut devenir octal si suffixe B) }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Operateur d affectation := }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur ** (exponentiation VAX) }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '**';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur || (concatenation VAX) }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '||';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <> }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Token de plage .. }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateurs simples : + - * / = < > @ ^ }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Or
            (Ch = '^') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Crochets [ ] : tokens d attribut VAX Pascal }
    Else If Ch = '[' Then
    Begin
      CurToken.Kind := TK_ATTR_OPEN;
      CurToken.Val  := '[';
      Inc(LexColNo);
      Scanning := False;
    End
    Else If Ch = ']' Then
    Begin
      CurToken.Kind := TK_ATTR_CLOSE;
      CurToken.Val  := ']';
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation : ; , ( ) . : }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '.') Or (Ch = ':') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ord=' + IntToStr(Ord(Ch)) + ')');
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================
  TODO 04 - LITTERAUX ET SEGMENT DE DONNEES
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := VXP_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
Procedure EmitRaw(Const S : String);
Begin
  WriteLn(OutF, S);
End;

{ ---- EmitComment : ecrire un commentaire ASM ---------------- }
Procedure EmitComment(Const S : String);
Begin
  WriteLn(OutF, '; ' + S);
End;

{ ---- EmitBlankLine : ecrire une ligne vide ------------------- }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ ---- DataAdd : ajouter une entree dans DataTab --------------- }
Function DataAdd(Const Lbl : TString; AKind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := AKind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataTab[DataCount].ElemSize  := 0;
  DataTab[DataCount].RecSize   := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label et stocker une chaine ------- }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := VXP_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DataTab ------- }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- DataAddByte : ajouter un octet dans DataTab ------------- }
Function DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, AIntVal, '');
End;

{ ---- DataAddArray : ajouter un tableau dans DataTab ---------- }
Function DataAddArray(Const Lbl : TString;
                      ECount, ESz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY, 0, '');
  DataTab[Idx].ElemCount := ECount;
  DataTab[Idx].ElemSize  := ESz;
  DataAddArray := Idx;
End;

{ ---- DataAddRec : ajouter un record dans DataTab ------------- }
Function DataAddRec(Const Lbl : TString; RSz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_REC, 0, '');
  DataTab[Idx].RecSize := RSz;
  DataAddRec := Idx;
End;

{ ---- EmitDataSeg : emettre le segment _DATA complet ---------- }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  Sz   : Integer;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');

  { --- Buffers internes du runtime --- }
  EmitComment('--- Buffers internes ---');
  EmitRaw(VXP_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(VXP_RT_PFX + 'STRBUF  DB  512 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'CHRBUF  DB  2 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'NUMBUF  DB  12 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(VXP_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  EmitRaw(VXP_RT_PFX + 'HEAP    DB  4096 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'HEAPTOP DW  OFFSET ' + VXP_RT_PFX + 'HEAP');
  EmitRaw(VXP_RT_PFX + 'SEED    DW  1');
  EmitBlankLine;

  { --- Entrees dynamiques de DataTab --- }
  If DataCount > 0 Then
    EmitComment('--- Donnees du programme ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        If DataTab[I].StrVal <> '' Then
          EmitRaw(DataTab[I].LblName + '  DW  OFFSET ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Doubler les apostrophes pour syntaxe MASM }
          S := '';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
      DK_ARRAY :
        Begin
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else If Sz = 2 Then
            EmitRaw(DataTab[I].LblName + '  DW  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount * Sz) + ' DUP(0)');
        End;
      DK_REC :
        Begin
          EmitRaw(DataTab[I].LblName + '  DB  ' +
                  IntToStr(DataTab[I].RecSize) + ' DUP(0)');
        End;
      DK_ARRAY_INIT :
        Begin
          (* Tableau initialise : StrVal contient les valeurs separees par virgule *)
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' + DataTab[I].StrVal)
          Else
            EmitRaw(DataTab[I].LblName + '  DW  ' + DataTab[I].StrVal);
        End;
    End;
  End;

  EmitRaw('_DATA   ENDS');
End;

{ ---- LitEval : evaluer un token litteral en TExprVal --------- }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Lw : TString;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case T.Kind Of
    { --- Entiers decimaux et hexadecimaux --- }
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Octaux (suffixe B) --- }
    TK_OCTAL :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Reels : tronquer en entier + avertissement --- }
    TK_REAL :
    Begin
      WarnMsg('reel ' + T.Val + ' tronque en entier');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := Trunc(T.RealVal);
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Chaines : stocker en DATA, retourner index DataTab --- }
    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := DataCount - 1;
    End;

    { --- Caracteres : valeur ordinale dans ImmVal --- }
    TK_CHAR :
    Begin
      If Length(T.Val) = 1 Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := Ord(T.Val[1]);
        Res.TypeIdx := TY_IDX_CHAR;
      End
      Else
      Begin
        { Multi-caractere (#13#10 etc.) : traiter comme chaine }
        DataAddStr(T.Val);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
      End;
    End;

    { --- Mots-cles speciaux : true, false, nil, maxint --- }
    TK_KEYWORD :
    Begin
      Lw := StrLowerCase(T.Val);
      If Lw = 'true' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 1;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'false' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'nil' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_NIL;
      End
      Else If Lw = 'maxint' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 32767;
        Res.TypeIdx := TY_IDX_INTEGER;
      End;
    End;
  Else
    Res.Kind := EK_NONE;
  End;
End;

{ ============================================================
  TODO 05 - EMETTEUR DE CODE ASM
  ============================================================ }

{ ---- NewLabel : generer un label unique ---------------------- }
Function NewLabel : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  While Length(S) < 5 Do
    S := '0' + S;
  NewLabel := VXP_LBL_PFX + S;
End;

{ ---- EmitLabel : label ASM suivi de ':' en colonne 0 --------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitInstr : instruction sans operande -------------------- }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ ---- EmitInstrA : instruction + un operande ------------------- }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ ---- EmitInstrAB : instruction + deux operandes --------------- }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ ---- EmitPush : PUSH registre -------------------------------- }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : POP registre ---------------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : MOV dst, src ---------------------------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitCall : CALL target ---------------------------------- }
Procedure EmitCall(Const Target : TString);
Begin
  EmitInstrA('CALL', Target);
End;

{ ---- EmitJmp : JMP target ------------------------------------ }
Procedure EmitJmp(Const Target : TString);
Begin
  EmitInstrA('JMP', Target);
End;

{ ---- EmitJmpCond : saut conditionnel (JE, JNE, JL, etc.) ----- }
Procedure EmitJmpCond(Const Cond, Target : TString);
Begin
  EmitInstrA(Cond, Target);
End;

{ ---- EmitProlog : prologue de procedure/fonction -------------- }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitPush('BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If FrameSize > 0 Then
  Begin
    EmitInstrAB('SUB', 'SP', IntToStr(FrameSize));
    If (FrameSize > FRAME_WARN) And Opts.Warnings Then
      WarnMsg('cadre de pile volumineux : ' + IntToStr(FrameSize) +
              ' octets');
  End;
  EmitPush('SI');
  EmitPush('DI');
End;

{ ---- EmitEpilog : epilogue de procedure/fonction -------------- }
Procedure EmitEpilog(ParamBytes : Integer);
Begin
  EmitPop('DI');
  EmitPop('SI');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitPop('BP');
  If ParamBytes > 0 Then
    EmitInstrA('RET', IntToStr(ParamBytes))
  Else
    EmitInstr('RET');
End;

{ ---- EmitHeader : en-tete du fichier ASM --------------------- }
Procedure EmitHeader;
Begin
  EmitComment('========================================');
  EmitComment('Genere par VAXPAS86 v' + VXP_VERSION +
              ' (' + VXP_DATE + ')');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitComment('========================================');
  EmitBlankLine;
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitComment('--- Segment de code ---');
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitComment('--- Point d entree principal ---');
  EmitLabel(VXP_FN_PFX + 'MAIN');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitInstrA('JMP', VXP_LBL_PFX + 'MAINBODY');
  EmitBlankLine;
End;

{ ---- EmitFooter : fin du segment de code --------------------- }
Procedure EmitFooter;
Begin
  If Not MainBodyEmitted Then
  Begin
    MainBodyEmitted := True;
    EmitLabel(VXP_LBL_PFX + 'MAINBODY');
  End;

  EmitBlankLine;
  EmitComment('--- Sortie programme (DOS INT 21h) ---');
  EmitInstrAB('MOV', 'AH', '4Ch');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('INT    21h');
  EmitBlankLine;

  { --- Routines runtime --- }
  If RuntimeEmitted Then
  Begin
    EmitRaw('_TEXT   ENDS');
    Exit;
  End;
  RuntimeEmitted := True;
  EmitComment('=== Routines runtime ===');
  EmitBlankLine;

  { _VXPRT_PRINTSTR : afficher chaine ASCIIZ pointee par SI }
  EmitComment('PRINTSTR : affiche chaine ASCIIZ (SI -> chaine)');
  EmitLabel(VXP_RT_PFX + 'PRINTSTR');
  EmitRaw(VXP_RT_PFX + 'PRINTSTR_LP:');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'PRINTSTR_DONE');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstrA('JMP', VXP_RT_PFX + 'PRINTSTR_LP');
  EmitRaw(VXP_RT_PFX + 'PRINTSTR_DONE:');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_NUMTOSTR : convertir AX (signe) en chaine NUMBUF }
  EmitComment('NUMTOSTR : convertit AX (signe) -> NUMBUF (ASCIIZ)');
  EmitLabel(VXP_RT_PFX + 'NUMTOSTR');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + VXP_RT_PFX + 'NUMBUF');
  EmitInstrAB('MOV', 'CX', '0');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JGE', VXP_RT_PFX + 'NTS_POS');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstr('INC    DI');
  EmitInstr('NEG    AX');
  EmitRaw(VXP_RT_PFX + 'NTS_POS:');
  EmitInstrAB('MOV', 'BX', '10');
  EmitRaw(VXP_RT_PFX + 'NTS_DIV:');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrA('PUSH', 'DX');
  EmitInstr('INC    CX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', VXP_RT_PFX + 'NTS_DIV');
  EmitRaw(VXP_RT_PFX + 'NTS_POP:');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    DI');
  EmitInstr('LOOP   ' + VXP_RT_PFX + 'NTS_POP');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_STRLEN : longueur chaine ASCIIZ }
  EmitComment('STRLEN : longueur chaine ASCIIZ (SI -> AX)');
  EmitLabel(VXP_RT_PFX + 'STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitRaw(VXP_RT_PFX + 'STRLEN_LP:');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'STRLEN_DONE');
  EmitInstr('INC    AX');
  EmitInstr('INC    SI');
  EmitInstrA('JMP', VXP_RT_PFX + 'STRLEN_LP');
  EmitRaw(VXP_RT_PFX + 'STRLEN_DONE:');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_CONCAT : concatener deux chaines ASCIIZ }
  EmitComment('CONCAT : SI + DI -> AX = ptr STRBUF');
  EmitLabel(VXP_RT_PFX + 'CONCAT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'BX', 'OFFSET ' + VXP_RT_PFX + 'STRBUF');
  EmitRaw(VXP_RT_PFX + 'CONCAT_S1:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'CONCAT_S2');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    BX');
  EmitInstrA('JMP', VXP_RT_PFX + 'CONCAT_S1');
  EmitRaw(VXP_RT_PFX + 'CONCAT_S2:');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'CONCAT_END');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstr('INC    DI');
  EmitInstr('INC    BX');
  EmitInstrA('JMP', VXP_RT_PFX + 'CONCAT_S2');
  EmitRaw(VXP_RT_PFX + 'CONCAT_END:');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', '0');
  EmitInstrAB('LEA', 'AX', VXP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_STRCMP : comparer deux chaines ASCIIZ }
  EmitComment('STRCMP : SI vs DI -> AX (signe)');
  EmitLabel(VXP_RT_PFX + 'STRCMP');
  EmitRaw(VXP_RT_PFX + 'STRCMP_LP:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', 'AH', '[DI]');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', VXP_RT_PFX + 'STRCMP_DIFF');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'STRCMP_EQ');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', VXP_RT_PFX + 'STRCMP_LP');
  EmitRaw(VXP_RT_PFX + 'STRCMP_EQ:');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');
  EmitRaw(VXP_RT_PFX + 'STRCMP_DIFF:');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'BL', '[DI]');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('SUB', 'AX', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_CHR : convertir code ASCII en chaine 1 caractere }
  EmitComment('CHR : AL -> AX = ptr chaine 1 car');
  EmitLabel(VXP_RT_PFX + 'CHR');
  EmitInstrAB('MOV', 'BYTE PTR [' + VXP_RT_PFX + 'CHRBUF]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [' + VXP_RT_PFX + 'CHRBUF+1]', '0');
  EmitInstrAB('LEA', 'AX', VXP_RT_PFX + 'CHRBUF');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_READCHAR : lire un caractere (INT 21h/01h) -> AL }
  EmitComment('READCHAR : lire un caractere -> AL');
  EmitLabel(VXP_RT_PFX + 'READCHAR');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstr('INT    21h');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_READNUM : lire un entier depuis stdin -> AX }
  EmitComment('READNUM : lire entier decimal -> AX');
  EmitLabel(VXP_RT_PFX + 'READNUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('XOR', 'BX', 'BX');  (* BX = resultat *)
  EmitInstrAB('XOR', 'CX', 'CX');  (* CX = flag negatif *)
  EmitRaw(VXP_RT_PFX + 'RN_LP:');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstr('INT    21h');
  EmitInstrAB('CMP', 'AL', '13');   (* CR -> fin *)
  EmitInstrA('JE', VXP_RT_PFX + 'RN_DONE');
  EmitInstrAB('CMP', 'AL', '''-''');
  EmitInstrA('JNE', VXP_RT_PFX + 'RN_DIG');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstrA('JMP', VXP_RT_PFX + 'RN_LP');
  EmitRaw(VXP_RT_PFX + 'RN_DIG:');
  EmitInstrAB('CMP', 'AL', '''0''');
  EmitInstrA('JB', VXP_RT_PFX + 'RN_DONE');
  EmitInstrAB('CMP', 'AL', '''9''');
  EmitInstrA('JA', VXP_RT_PFX + 'RN_DONE');
  EmitInstrAB('SUB', 'AL', '''0''');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('MOV', 'DX', '10');
  EmitInstrA('MUL', 'DX');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('ADD', 'BX', 'AX');
  EmitInstrA('JMP', VXP_RT_PFX + 'RN_LP');
  EmitRaw(VXP_RT_PFX + 'RN_DONE:');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'RN_END');
  EmitInstr('NEG    AX');
  EmitRaw(VXP_RT_PFX + 'RN_END:');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  EmitRaw('_TEXT   ENDS');
End;

{ ---- EmitClose : directive END finale apres _DATA ENDS -------- }
Procedure EmitClose;
Begin
  EmitRaw('        END     ' + VXP_FN_PFX + 'MAIN');
End;

{ ---- EmitCoerce : conversion de type inline ------------------- }
Procedure EmitCoerce(SrcType, DstType : Integer);
Var
  Ks, Kd : TTypeKind;
Begin
  If SrcType = DstType Then Exit;
  If (SrcType = TY_UNKNOWN) Or (DstType = TY_UNKNOWN) Then Exit;
  If (SrcType < 0) Or (SrcType >= TypeCount) Or
     (DstType < 0) Or (DstType >= TypeCount) Then Exit;

  Ks := TypeTab[SrcType].Kind;
  Kd := TypeTab[DstType].Kind;

  { Byte -> Integer/Word : extension zero }
  If (Ks = TKP_BYTE) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce byte -> word');
    EmitInstrAB('XOR', 'AH', 'AH');
    Exit;
  End;

  { Char -> Integer/Word : extension zero }
  If (Ks = TKP_CHAR) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce char -> word');
    EmitInstrAB('XOR', 'AH', 'AH');
    Exit;
  End;

  { Integer/Word -> Byte : troncature (AL deja ok) }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_BYTE) Then
  Begin
    EmitComment('coerce word -> byte');
    Exit;
  End;

  { Boolean -> Integer : deja 0|1 dans AX }
  If (Ks = TKP_BOOLEAN) And
     ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce boolean -> word');
    EmitInstrAB('XOR', 'AH', 'AH');
    Exit;
  End;

  { Integer -> Boolean : CMP AX,0 }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And
     (Kd = TKP_BOOLEAN) Then
  Begin
    EmitComment('coerce word -> boolean');
    EmitInstrAB('CMP', 'AX', '0');
    EmitInstrAB('MOV', 'AX', '0');
    EmitInstr('JE     $+4');
    EmitInstrAB('MOV', 'AX', '1');
    Exit;
  End;

  { Char -> String : via runtime CHR }
  If (Ks = TKP_CHAR) And (Kd = TKP_STRING) Then
  Begin
    EmitComment('coerce char -> string (runtime)');
    Exit;
  End;

  { nil -> Pointer/String : valeur deja 0 }
  If (Ks = TKP_NIL) And ((Kd = TKP_POINTER) Or (Kd = TKP_STRING)) Then
    Exit;

  { Real -> Integer : tronquage }
  If (Ks = TKP_REAL) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    WarnMsg('reel tronque en entier');
    Exit;
  End;

  { Integer -> Real : on garde la valeur entiere }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_REAL) Then
    Exit;

  { Enum -> Integer (Ord) }
  If (Ks = TKP_ENUM) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce enum -> word (Ord)');
    Exit;
  End;

  { Integer <-> Word : meme representation }
  If ((Ks = TKP_INTEGER) And (Kd = TKP_WORD)) Or
     ((Ks = TKP_WORD) And (Kd = TKP_INTEGER)) Then
  Begin
    If Opts.Warnings Then
      WarnMsg('conversion implicite signe <-> non-signe');
    Exit;
  End;

  { Double -> Integer : tronquage }
  If (Ks = TKP_DOUBLE) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    WarnMsg('double tronque en entier');
    Exit;
  End;

  { Varying -> String : on traite comme pointeur chaine }
  If (Ks = TKP_VARYING) And (Kd = TKP_STRING) Then
  Begin
    EmitComment('coerce varying -> string');
    Exit;
  End;

  { String -> Varying : inverse }
  If (Ks = TKP_STRING) And (Kd = TKP_VARYING) Then
  Begin
    EmitComment('coerce string -> varying');
    Exit;
  End;

  { Pas de conversion connue }
  If Opts.Warnings Then
    WarnMsg('conversion de type implicite non supportee');
End;

{ ---- EmitPrintAX : emettre code pour afficher AX selon type --- }
Procedure EmitPrintAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
Begin
  If TypeIdx = TY_IDX_STRING Then
  Begin
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitCall(VXP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    EmitInstrAB('MOV', 'DL', 'AL');
    EmitInstrAB('MOV', 'AH', '02h');
    EmitInstr('INT    21h');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstrAB('CMP', 'AX', '0');
    EmitInstrA('JE', LblFalse);
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'TRUE_S');
    EmitInstrA('JMP', LblDone);
    EmitLabel(LblFalse);
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'FALSE_S');
    EmitLabel(LblDone);
    EmitCall(VXP_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    EmitCall(VXP_RT_PFX + 'NUMTOSTR');
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'NUMBUF');
    EmitCall(VXP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ============================================================
  TODO 06 - TABLE DES SYMBOLES
  ============================================================ }

{ Forward declarations }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer; Forward;

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR        : Pfx := VXP_VAR_PFX;
    SC_CONST      : Pfx := VXP_VAR_PFX;
    SC_TYPED_CONST: Pfx := VXP_VAR_PFX;
    SC_PARAM      : Pfx := VXP_VAR_PFX;
    SC_VARPARAM   : Pfx := VXP_VAR_PFX;
    SC_FUNC       : Pfx := VXP_FN_PFX;
    SC_PROC       : Pfx := VXP_FN_PFX;
    SC_TYPE       : Pfx := '';
    SC_FIELD      : Pfx := VXP_REC_PFX;
    SC_ENUM_VAL   : Pfx := VXP_ENUM_PFX;
    SC_LABEL      : Pfx := VXP_LBL_PFX;
    SC_STATIC     : Pfx := VXP_VAR_PFX;
    SC_EXTERNAL   : Pfx := VXP_FN_PFX;
    SC_GLOBAL     : Pfx := VXP_FN_PFX;
    SC_PUBLIC     : Pfx := VXP_FN_PFX;
    SC_MODULE     : Pfx := VXP_MOD_PFX;
    SC_CONDITION  : Pfx := VXP_VAR_PFX;
  Else
    Pfx := VXP_VAR_PFX;
  End;
  SymMangle := Pfx + StrUpperCase(Name);
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
Function SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Idx : Integer;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    If SymTab[Dup].IsForward Then
    Begin
      SymTab[Dup].IsForward := False;
      SymTab[Dup].TypeIdx   := TIdx;
      SymAdd := Dup;
      Exit;
    End
    Else
    Begin
      WarnMsg('symbole deja declare dans ce scope: ' + Name);
      SymAdd := Dup;
      Exit;
    End;
  End;

  Idx := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);

  SymTab[Idx].Name        := Lw;
  SymTab[Idx].MangledName := SymMangle(Lw, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := TIdx;
  SymTab[Idx].Offset      := 0;
  SymTab[Idx].ScopeLevel  := CurScopeLevel;
  SymTab[Idx].ScopeId     := CurScopeId;
  SymTab[Idx].IsForward   := False;
  SymTab[Idx].IsLocal     := (CurScopeLevel > 0);
  SymTab[Idx].ImmVal      := 0;
  SymTab[Idx].DataIdx     := -1;
  SymTab[Idx].ParamCnt    := 0;
  SymTab[Idx].VarParamMask := 0;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Lw,
            ' cat=', Ord(Cat),
            ' scope=', CurScopeLevel,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymFind : rechercher un symbole (interne -> global) ----- }
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

{ ---- SymFindInScope : rechercher dans un scope precis -------- }
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

{ ---- SymEnterScope : entrer dans un nouveau scope ------------ }
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

{ ---- SymLeaveScope : quitter le scope courant ---------------- }
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

{ ---- SymInit : predeclarer les types et symboles builtin ----- }
Procedure SymInit;
Var
  Idx : Integer;
Begin
  { Types primitifs Pascal standard }
  Idx := SymAdd('integer', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER';
  Idx := SymAdd('word', SC_TYPE, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'WORD';
  Idx := SymAdd('byte', SC_TYPE, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BYTE';
  Idx := SymAdd('char', SC_TYPE, TY_IDX_CHAR);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'CHAR';
  Idx := SymAdd('boolean', SC_TYPE, TY_IDX_BOOLEAN);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BOOLEAN';
  Idx := SymAdd('string', SC_TYPE, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'STRING';
  Idx := SymAdd('real', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'REAL';
  Idx := SymAdd('double', SC_TYPE, TY_IDX_DOUBLE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'DOUBLE';
  Idx := SymAdd('text', SC_TYPE, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'TEXT';

  { Types VAX Pascal supplementaires }
  Idx := SymAdd('unsigned', SC_TYPE, TY_IDX_UNSIGNED);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'UNSIGNED';
  Idx := SymAdd('single', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'SINGLE';
  Idx := SymAdd('d_float', SC_TYPE, TY_IDX_DOUBLE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'D_FLOAT';
  Idx := SymAdd('d_floating', SC_TYPE, TY_IDX_DOUBLE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'D_FLOATING';
  Idx := SymAdd('g_float', SC_TYPE, TY_IDX_DOUBLE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'G_FLOAT';
  Idx := SymAdd('g_floating', SC_TYPE, TY_IDX_DOUBLE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'G_FLOATING';
  Idx := SymAdd('f_floating', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'F_FLOATING';
  Idx := SymAdd('integer16', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER16';
  Idx := SymAdd('integer32', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER32';
  Idx := SymAdd('machine_word', SC_TYPE, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'MACHINE_WORD';
  Idx := SymAdd('half_word', SC_TYPE, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'HALF_WORD';
  Idx := SymAdd('quadword', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'QUADWORD';

  { Constantes predefinies }
  Idx := SymAdd('true', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 1;
    SymTab[Idx].MangledName := 'TRUE';
  End;
  Idx := SymAdd('false', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'FALSE';
  End;
  Idx := SymAdd('nil', SC_CONST, TY_IDX_NIL);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'NIL';
  End;
  Idx := SymAdd('maxint', SC_CONST, TY_IDX_INTEGER);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 32767;
    SymTab[Idx].MangledName := 'MAXINT';
  End;

  { Variables predefinies I/O }
  Idx := SymAdd('input', SC_VAR, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_VAR_PFX + 'INPUT';
  Idx := SymAdd('output', SC_VAR, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_VAR_PFX + 'OUTPUT';
  Idx := SymAdd('tty', SC_VAR, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_VAR_PFX + 'TTY';
  Idx := SymAdd('ttyoutput', SC_VAR, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_VAR_PFX + 'TTYOUTPUT';

  { Procedures/fonctions runtime predeclarees }
  Idx := SymAdd('write', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'WRITE';
  Idx := SymAdd('writeln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'WRITELN';
  Idx := SymAdd('read', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'READ';
  Idx := SymAdd('readln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'READLN';
  Idx := SymAdd('writev', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'WRITEV';
  Idx := SymAdd('readv', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'READV';
  Idx := SymAdd('halt', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'HALT';
  Idx := SymAdd('stop', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'STOP';

  { Fonctions standard }
  Idx := SymAdd('ord', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ORD';
  Idx := SymAdd('chr', SC_FUNC, TY_IDX_CHAR);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'CHR';
  Idx := SymAdd('succ', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SUCC';
  Idx := SymAdd('pred', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'PRED';
  Idx := SymAdd('abs', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ABS';
  Idx := SymAdd('sqr', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SQR';
  Idx := SymAdd('odd', SC_FUNC, TY_IDX_BOOLEAN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ODD';
  Idx := SymAdd('length', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'LENGTH';
  Idx := SymAdd('sizeof', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SIZEOF';
  Idx := SymAdd('new', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'NEW';
  Idx := SymAdd('dispose', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'DISPOSE';

  If Opts.DebugMode Then
    WriteLn('  SymInit: ', SymCount, ' symboles predeclares');
End;

{ ============================================================
  SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

(* ---- TypeInit : initialiser les types primitifs ------------- *)
(* 13 types primitifs (TY_PRIM_COUNT) + types predefinis VAX     *)
(* supplementaires ajoutes comme alias ou types derives.         *)

Procedure TypeInit;

  Procedure AddPrim(Idx : Integer; K : TTypeKind; Sz : Integer);
  Begin
    TypeTab[Idx].Kind        := K;
    TypeTab[Idx].Size        := Sz;
    TypeTab[Idx].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 0;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].EnumCount   := 0;
    TypeTab[Idx].Packed_     := False;
    TypeTab[Idx].Precision   := 0;
  End;

  (* Ajouter un type supplementaire dans TypeTab *)
  Function AddExtra(K : TTypeKind; Sz : Integer;
                    Base : Integer) : Integer;
  Var
    Idx : Integer;
  Begin
    Idx := TypeCount;
    If Idx >= MAX_TYPE Then
    Begin
      AddExtra := TY_UNKNOWN;
      Exit;
    End;
    TypeTab[Idx].Kind        := K;
    TypeTab[Idx].Size        := Sz;
    TypeTab[Idx].BaseTypeIdx := Base;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 0;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].EnumCount   := 0;
    TypeTab[Idx].Packed_     := False;
    TypeTab[Idx].Precision   := 0;
    Inc(TypeCount);
    AddExtra := Idx;
  End;

  (* Enregistrer un alias de type dans la table des symboles *)
  (* Ne rien faire si le symbole existe deja *)
  Procedure RegAlias(Const AName : TString; TIdx : Integer);
  Var
    SI : Integer;
  Begin
    SI := SymFind(AName);
    If SI >= 0 Then
    Begin
      (* Mettre a jour le TypeIdx si deja present *)
      SymTab[SI].TypeIdx := TIdx;
      Exit;
    End;
    SI := SymAdd(AName, SC_TYPE, TIdx);
    If SI >= 0 Then
      SymTab[SI].MangledName := '';
  End;

Var
  Idx, EnIdx : Integer;
Begin
  { 1) Initialiser les 13 types primitifs }
  TypeCount := TY_PRIM_COUNT;
  AddPrim(TY_IDX_INTEGER,  TKP_INTEGER,  2);  { Integer  : 2 octets }
  AddPrim(TY_IDX_WORD,     TKP_WORD,     2);  { Word     : 2 octets }
  AddPrim(TY_IDX_BYTE,     TKP_BYTE,     1);  { Byte     : 1 octet  }
  AddPrim(TY_IDX_CHAR,     TKP_CHAR,     1);  { Char     : 1 octet  }
  AddPrim(TY_IDX_BOOLEAN,  TKP_BOOLEAN,  1);  { Boolean  : 1 octet  }
  AddPrim(TY_IDX_STRING,   TKP_STRING,   2);  { String   : 2 (ptr)  }
  AddPrim(TY_IDX_REAL,     TKP_REAL,     2);  { Real     : 2 (tronq)}
  AddPrim(TY_IDX_DOUBLE,   TKP_DOUBLE,   2);  { Double   : 2 (tronq)}
  AddPrim(TY_IDX_POINTER,  TKP_POINTER,  2);  { Pointer  : 2 octets }
  AddPrim(TY_IDX_NIL,      TKP_NIL,      2);  { nil      : 2 octets }
  AddPrim(TY_IDX_TEXT,     TKP_TEXT,     2);   { Text     : 2 (hndl) }
  AddPrim(TY_IDX_UNSIGNED, TKP_WORD,     2);   { Unsigned : 2 octets }
  AddPrim(TY_IDX_VARYING,  TKP_VARYING,  2);  { Varying  : 2 (ptr)  }

  { 2) Types predefinis VMS Pascal supplementaires (alias) }
  RegAlias('MACHINE_WORD', TY_IDX_WORD);
  RegAlias('HALF_WORD',    TY_IDX_BYTE);
  RegAlias('INTEGER16',    TY_IDX_INTEGER);
  RegAlias('SINGLE',       TY_IDX_REAL);
  RegAlias('D_FLOAT',      TY_IDX_REAL);
  RegAlias('D_FLOATING',   TY_IDX_REAL);
  RegAlias('F_FLOATING',   TY_IDX_REAL);
  RegAlias('G_FLOAT',      TY_IDX_DOUBLE);
  RegAlias('G_FLOATING',   TY_IDX_DOUBLE);
  RegAlias('FILE_NAME',    TY_IDX_STRING);
  RegAlias('LINE',         TY_IDX_STRING);

  { INTEGER32 : emule en 32 bits (4 octets, 2x16) }
  Idx := AddExtra(TKP_INTEGER, 4, TY_IDX_INTEGER);
  RegAlias('INTEGER32', Idx);

  { QUADWORD : 64 bits (8 octets, 4x16) }
  Idx := AddExtra(TKP_INTEGER, 8, TY_IDX_INTEGER);
  RegAlias('QUADWORD', Idx);

  { H_FLOATING : quadruple precision (non supporte, alias Double) }
  RegAlias('H_FLOATING', TY_IDX_DOUBLE);

  { 3) IO_STATUS : enumeration predefinie d etats d I/O }
  Idx := TypeCount;
  If Idx < MAX_TYPE Then
  Begin
    TypeTab[Idx].Kind        := TKP_ENUM;
    TypeTab[Idx].Size        := 2;
    TypeTab[Idx].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 13;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].Packed_     := False;
    TypeTab[Idx].Precision   := 0;
    TypeTab[Idx].EnumCount   := 14;
    TypeTab[Idx].Enums[0].Name  := 'IO_OK';    TypeTab[Idx].Enums[0].Value  := 0;
    TypeTab[Idx].Enums[1].Name  := 'IO_NOVF';  TypeTab[Idx].Enums[1].Value  := 1;
    TypeTab[Idx].Enums[2].Name  := 'IO_POVF';  TypeTab[Idx].Enums[2].Value  := 2;
    TypeTab[Idx].Enums[3].Name  := 'IO_DGIT';  TypeTab[Idx].Enums[3].Value  := 3;
    TypeTab[Idx].Enums[4].Name  := 'IO_GOVF';  TypeTab[Idx].Enums[4].Value  := 4;
    TypeTab[Idx].Enums[5].Name  := 'IO_INTR';  TypeTab[Idx].Enums[5].Value  := 5;
    TypeTab[Idx].Enums[6].Name  := 'IO_REWR';  TypeTab[Idx].Enums[6].Value  := 6;
    TypeTab[Idx].Enums[7].Name  := 'IO_EOF';   TypeTab[Idx].Enums[7].Value  := 7;
    TypeTab[Idx].Enums[8].Name  := 'IO_OUTF';  TypeTab[Idx].Enums[8].Value  := 8;
    TypeTab[Idx].Enums[9].Name  := 'IO_INPF';  TypeTab[Idx].Enums[9].Value  := 9;
    TypeTab[Idx].Enums[10].Name := 'IO_SEEK';  TypeTab[Idx].Enums[10].Value := 10;
    TypeTab[Idx].Enums[11].Name := 'IO_ILLC';  TypeTab[Idx].Enums[11].Value := 11;
    TypeTab[Idx].Enums[12].Name := 'IO_NEPF';  TypeTab[Idx].Enums[12].Value := 12;
    TypeTab[Idx].Enums[13].Name := 'IO_OPNF';  TypeTab[Idx].Enums[13].Value := 13;
    Inc(TypeCount);
    RegAlias('IO_STATUS', Idx);

    (* Enregistrer chaque valeur enum dans SymTab *)
    For EnIdx := 0 To 13 Do
    Begin
      Idx := SymAdd(TypeTab[TypeCount - 1].Enums[EnIdx].Name,
                     SC_ENUM_VAL, TypeCount - 1);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].ImmVal := EnIdx;
        SymTab[Idx].MangledName := VXP_ENUM_PFX +
          StrUpperCase(TypeTab[TypeCount - 1].Enums[EnIdx].Name);
      End;
    End;
  End;

  If Opts.DebugMode Then
    WriteLn('  TypeInit: ', TypeCount, ' types initialises');
End;

(* ---- TypeSizeof : retourner la taille d un type en octets ---- *)
Function TypeSizeof(TIdx : Integer) : Integer;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeSizeof := TypeTab[TIdx].Size
  Else
    TypeSizeof := 2;  (* taille par defaut = mot 16 bits *)
End;

(* ---- TypeIsOrdinal : le type est-il ordinal ? ----------------- *)
(* Integer, Word, Byte, Char, Boolean, Enum, Subrange, Unsigned    *)
Function TypeIsOrdinal(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_CHAR,
    TKP_BOOLEAN, TKP_ENUM, TKP_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

(* ---- TypeIsNumeric : le type est-il numerique ? --------------- *)
(* Integer, Word, Byte, Real, Double                               *)
Function TypeIsNumeric(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_REAL, TKP_DOUBLE :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

(* ---- TypeIsPointer : le type est-il un pointeur ? ------------- *)
Function TypeIsPointer(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_POINTER, TKP_NIL, TKP_STRING :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

(* ---- TypeCompatible : deux types sont-ils compatibles ? ------- *)
(* Retourne True si on peut affecter une valeur de type T2 a T1.   *)
(* Couvre les promotions implicites et les extensions VAX Pascal.   *)
Function TypeCompatible(T1, T2 : Integer) : Boolean;
Var
  K1, K2 : TTypeKind;
Begin
  (* Types identiques : toujours compatible *)
  If T1 = T2 Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Si l un des deux est inconnu, accepter *)
  If (T1 = TY_UNKNOWN) Or (T2 = TY_UNKNOWN) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Verifier les bornes *)
  If (T1 < 0) Or (T1 >= TypeCount) Or
     (T2 < 0) Or (T2 >= TypeCount) Then
  Begin
    TypeCompatible := False;
    Exit;
  End;

  K1 := TypeTab[T1].Kind;
  K2 := TypeTab[T2].Kind;

  (* nil -> tout type pointeur ou string *)
  If K2 = TKP_NIL Then
  Begin
    TypeCompatible := (K1 = TKP_POINTER) Or (K1 = TKP_STRING) Or
                      (K1 = TKP_NIL);
    Exit;
  End;

  (* Integer <-> Word (implicite) *)
  If ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Byte -> Integer ou Word (promotion implicite) *)
  If (K2 = TKP_BYTE) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Integer/Word -> Byte (retrecissement implicite) *)
  If (K1 = TKP_BYTE) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Char <-> Integer (Ord/Chr) *)
  If ((K1 = TKP_CHAR) And (K2 = TKP_INTEGER)) Or
     ((K1 = TKP_INTEGER) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Char <-> Byte *)
  If ((K1 = TKP_CHAR) And (K2 = TKP_BYTE)) Or
     ((K1 = TKP_BYTE) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Char <-> String (1 caractere, conversion implicite) *)
  If ((K1 = TKP_CHAR) And (K2 = TKP_STRING)) Or
     ((K1 = TKP_STRING) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Boolean -> Integer (0|1) *)
  If (K2 = TKP_BOOLEAN) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Integer -> Boolean (non-zero = true) *)
  If (K1 = TKP_BOOLEAN) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD) Or (K2 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Enum -> Integer (Ord) *)
  If (K2 = TKP_ENUM) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Subrange -> son type de base *)
  If (K2 = TKP_SUBRANGE) And
     (TypeTab[T2].BaseTypeIdx = T1) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If (K1 = TKP_SUBRANGE) And
     (TypeTab[T1].BaseTypeIdx = T2) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Real <-> Integer (tronquage implicite) *)
  If ((K1 = TKP_REAL) And ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD))) Or
     (((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And (K2 = TKP_REAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Pointer <-> tout type pointeur *)
  If (K1 = TKP_POINTER) And (K2 = TKP_POINTER) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* --- Extensions VAX Pascal --- *)

  (* Double <-> Real (promotion/retrecissement flottant) *)
  If ((K1 = TKP_DOUBLE) And (K2 = TKP_REAL)) Or
     ((K1 = TKP_REAL) And (K2 = TKP_DOUBLE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Double <-> Integer/Word *)
  If ((K1 = TKP_DOUBLE) And ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD))) Or
     (((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And (K2 = TKP_DOUBLE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Varying <-> String (interchangeables) *)
  If ((K1 = TKP_VARYING) And (K2 = TKP_STRING)) Or
     ((K1 = TKP_STRING) And (K2 = TKP_VARYING)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* Varying <-> Char *)
  If ((K1 = TKP_VARYING) And (K2 = TKP_CHAR)) Or
     ((K1 = TKP_CHAR) And (K2 = TKP_VARYING)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  TypeCompatible := False;
End;

(* ---- TypeCoerce : emettre le code de conversion src -> dst ---- *)
(* Delegue a EmitCoerce (deja implemente dans TODO 05) et retourne *)
(* le TypeIdx du resultat.                                          *)
Function TypeCoerce(SrcType, DstType : Integer) : Integer;
Begin
  If SrcType = DstType Then
  Begin
    TypeCoerce := SrcType;
    Exit;
  End;
  If (SrcType = TY_UNKNOWN) Or (DstType = TY_UNKNOWN) Then
  Begin
    If DstType <> TY_UNKNOWN Then
      TypeCoerce := DstType
    Else
      TypeCoerce := SrcType;
    Exit;
  End;
  (* Emettre le code de conversion via EmitCoerce *)
  EmitCoerce(SrcType, DstType);
  TypeCoerce := DstType;
End;

(* ---- TypeResolve : resoudre un nom de type en indice ---------- *)
(* Cherche dans SymTab (SC_TYPE), sinon retourne TY_UNKNOWN.       *)
Function TypeResolve(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name);
  If (Idx >= 0) And (SymTab[Idx].Cat = SC_TYPE) Then
    TypeResolve := SymTab[Idx].TypeIdx
  Else
    TypeResolve := TY_UNKNOWN;
End;

(* Forward declarations pour les expressions *)
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer;
                      Var R : TExprVal); Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ParseCallArgs(FuncIdx : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer;
                        Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;

(* Forward declarations pour les declarations et affectations *)
Procedure ParseVarDecl; Forward;
Procedure ParseAssignment(Const VarName : TString); Forward;
Procedure ParseValueSection; Forward;
Procedure ParseTypeDecl; Forward;
Procedure ParseWriteStmt(IsWriteLn : Boolean); Forward;
Procedure ParseReadStmt(IsReadLn : Boolean); Forward;
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseCaseStmt; Forward;
Procedure ParseForStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseRepeatStmt; Forward;
Procedure ParseLoopStmt; Forward;
Procedure ParseFuncDecl; Forward;
Procedure ParseProcDecl; Forward;
Procedure ParseWithStmt; Forward;

{ ============================================================
  OPERATEURS ET PRECEDENCES [IMPLEMENTE]
  ============================================================ }

(* ---- OpPrec : priorite d un operateur binaire --------------- *)
(* VAX Pascal utilise 8 niveaux de priorite :                     *)
(*   1 : OR, ORIF                                                 *)
(*   2 : AND, ANDIF                                               *)
(*   3 : (NOT unaire, gere dans ParseUnary)                       *)
(*   4 : =, <>, <, >, <=, >=, IN                                  *)
(*   5 : +, -, || (concatenation)                                  *)
(*   6 : *, /, DIV, MOD                                            *)
(*   7 : ** (exponentiation)                                       *)
(*   8 : (unaires, gere dans ParseUnary)                           *)

Function OpPrec(Const Op : TString) : Integer;
Begin
  If Op = '**' Then
    OpPrec := 7
  Else If (Op = '*') Or (Op = '/') Or (Op = 'div') Or
          (Op = 'mod') Then
    OpPrec := 6
  Else If (Op = '+') Or (Op = '-') Or (Op = '||') Then
    OpPrec := 5
  Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
    OpPrec := 4
  Else If (Op = 'and') Or (Op = 'andif') Then
    OpPrec := 2
  Else If (Op = 'or') Or (Op = 'orif') Or (Op = 'xor') Then
    OpPrec := 1
  Else If (Op = 'shl') Or (Op = 'shr') Then
    OpPrec := 6
  Else
    OpPrec := 0;
End;

(* ---- ExprMakeImm : creer une valeur immediate --------------- *)
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal);
Begin
  R.Kind    := EK_IMM;
  R.ImmVal  := V;
  R.TypeIdx := TIdx;
  R.Offset  := 0;
  R.SymIdx  := -1;
End;

(* ---- ExprFlushToAX : materialiser une expression dans AX ---- *)
(* Si deja AX, ne rien faire. Si immediate, MOV AX, imm.         *)
(* Si memoire, charger depuis variable locale ou globale.         *)
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  SIdx : Integer;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
        EmitInstrAB('MOV', 'AX', IntToStr(E.ImmVal));
      E.Kind := EK_AX;
    End;
    EK_AX :
      ; (* deja dans AX *)
    EK_MEM :
    Begin
      SIdx := E.SymIdx;
      If (SIdx >= 0) And (SIdx < SymCount) Then
      Begin
        If SymTab[SIdx].IsLocal Then
        Begin
          (* Variable locale : MOV AX, [BP-n] *)
          If SymTab[SIdx].Cat = SC_VARPARAM Then
          Begin
            (* Parametre var (reference) : MOV BX,[BP+n] / MOV AX,[BX] *)
            EmitInstrAB('MOV', 'BX',
              'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          End
          Else
          Begin
            If TypeSizeof(E.TypeIdx) = 1 Then
            Begin
              EmitInstrAB('XOR', 'AH', 'AH');
              EmitInstrAB('MOV', 'AL',
                'BYTE PTR ' + BPOfs(SymTab[SIdx].Offset));
            End
            Else
              EmitInstrAB('MOV', 'AX',
                'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
          End;
        End
        Else
        Begin
          (* Variable globale : MOV AX, [_VXP_xxx] *)
          If TypeSizeof(E.TypeIdx) = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL',
              'BYTE PTR [' + SymTab[SIdx].MangledName + ']');
          End
          Else
            EmitInstrAB('MOV', 'AX',
              'WORD PTR [' + SymTab[SIdx].MangledName + ']');
        End;
      End
      Else
      Begin
        (* Symbole inconnu : XOR AX,AX par defaut *)
        EmitInstrAB('XOR', 'AX', 'AX');
      End;
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
  End;
End;

(* ---- ParseCallArgs : evaluer et PUSH des arguments ---------- *)
(* FuncIdx est l indice du symbole de la fonction dans SymTab.    *)
(* CurToken doit etre sur ( au debut. Consomme jusqu a ).         *)
Procedure ParseCallArgs(FuncIdx : Integer);
Var
  ArgExpr  : TExprVal;
  ArgCnt   : Integer;
  IsBit    : LongInt;
  ParamVar : Boolean;
Begin
  ArgCnt := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    LexNextToken;  (* consommer ( *)

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    (* Determiner si c est un parametre var *)
    ParamVar := False;
    If (FuncIdx >= 0) And (ArgCnt < 16) Then
    Begin
      IsBit := SymTab[FuncIdx].VarParamMask;
      If (IsBit And (LongInt(1) Shl ArgCnt)) <> 0 Then
        ParamVar := True;
    End;

    If ParamVar Then
    Begin
      (* Parametre var : empiler l adresse *)
      If (CurToken.Kind = TK_IDENT) Then
      Begin
        ArgExpr.SymIdx := SymFind(CurToken.Val);
        If (ArgExpr.SymIdx >= 0) And
           SymTab[ArgExpr.SymIdx].IsLocal Then
          EmitInstrAB('LEA', 'AX',
            BPOfs(SymTab[ArgExpr.SymIdx].Offset))
        Else If ArgExpr.SymIdx >= 0 Then
          EmitInstrAB('MOV', 'AX',
            'OFFSET ' + SymTab[ArgExpr.SymIdx].MangledName)
        Else
          EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('PUSH', 'AX');
        LexNextToken;
      End
      Else
      Begin
        ParseExpr(ArgExpr);
        ExprFlushToAX(ArgExpr);
        EmitInstrA('PUSH', 'AX');
      End;
    End
    Else
    Begin
      ParseExpr(ArgExpr);
      ExprFlushToAX(ArgExpr);
      EmitInstrA('PUSH', 'AX');
    End;

    Inc(ArgCnt);

    (* Virgule entre arguments *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken;
  End;

  (* Consommer ) *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    LexNextToken;

  If Opts.DebugMode Then
    WriteLn('  CALL_ARGS: ', ArgCnt, ' argument(s)');
End;

(* ---- ParsePrimary : token primaire -> TExprVal --------------- *)
(* Gere : litteraux (entier, reel, chaine, char, true/false/nil),  *)
(*        identificateurs (variable, constante, appel fonction),   *)
(*        sous-expression parenthesee (expr),                      *)
(*        transtypage : Integer(expr), Char(expr), etc.            *)
(*        fonctions builtin VAX Pascal.                            *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  CastTypeIdx : Integer;
  LblUC       : TString;
  BaseTIdx    : Integer;
  Idx         : Integer;
  (* Tableaux *)
  ArrTIdx     : Integer;
  IdxExpr     : TExprVal;
  ArrLo       : LongInt;
  ElemSz      : Integer;
  (* Records *)
  RecTIdx     : Integer;
  FldIdx      : Integer;
  FI          : Integer;
  FldTIdx     : Integer;
  FldSz       : Integer;
  WIdx        : Integer;
  WI          : Integer;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case CurToken.Kind Of
    (* --- Litteraux numeriques --- *)
    TK_INTEGER, TK_REAL, TK_CHAR, TK_OCTAL :
    Begin
      LitEval(CurToken, Res);
      LexNextToken;
    End;

    (* --- Chaine litterale --- *)
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      (* Emettre LEA AX, label de la chaine *)
      If (Res.SymIdx >= 0) And (Res.SymIdx < DataCount) Then
        EmitInstrAB('LEA', 'AX', DataTab[Res.SymIdx].LblName)
      Else If DataCount > 0 Then
        EmitInstrAB('LEA', 'AX', DataTab[DataCount - 1].LblName);
      Res.Kind := EK_AX;
      LexNextToken;
    End;

    (* --- Mots-cles speciaux --- *)
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'nil') Or (CurToken.Val = 'maxint') Then
      Begin
        LitEval(CurToken, Res);
        LexNextToken;
      End
      (* Transtypage : Integer(expr), Char(expr), Byte(expr), etc. *)
      Else If (CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
              (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Or
              (CurToken.Val = 'unsigned') Then
      Begin
        CastTypeIdx := TypeResolve(CurToken.Val);
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          LexNextToken;  (* consommer ( *)
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            LexNextToken;
          Res.TypeIdx := CastTypeIdx;
          If Res.Kind <> EK_IMM Then
          Begin
            ExprFlushToAX(Res);
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              EmitInstrAB('AND', 'AX', '00FFh');
            Res.Kind := EK_AX;
          End
          Else
          Begin
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              Res.ImmVal := Res.ImmVal And $FF;
          End;
          If Opts.DebugMode Then
            WriteLn('  TYPECAST -> type ', CastTypeIdx);
        End
        Else
          WarnMsg('''('' attendu apres le type dans le transtypage');
      End
      Else
      Begin
        WarnMsg('mot-cle inattendu dans expression: ' + CurToken.Val);
        LexNextToken;
      End;
    End;

    (* --- Identificateurs --- *)
    TK_IDENT :
    Begin
      (* --- Fonctions builtin --- *)

      (* Length(x) *)
      If StrLowerCase(CurToken.Val) = 'length' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        Idx := -1;
        If CurToken.Kind = TK_IDENT Then
          Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Idx].TypeIdx;
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[ArrTIdx].Hi - TypeTab[ArrTIdx].Lo + 1));
          LexNextToken;
        End
        Else
        Begin
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRLEN');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Chr(n) *)
      Else If StrLowerCase(CurToken.Val) = 'chr' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrA('CALL', VXP_RT_PFX + 'CHR');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      (* Ord(x) *)
      Else If StrLowerCase(CurToken.Val) = 'ord' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        If Res.TypeIdx = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstr('LODSB');
          EmitInstrAB('XOR', 'AH', 'AH');
        End
        Else
          EmitInstrAB('AND', 'AX', '00FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Succ(x) *)
      Else If StrLowerCase(CurToken.Val) = 'succ' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('INC    AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Pred(x) *)
      Else If StrLowerCase(CurToken.Val) = 'pred' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('DEC    AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Low(T) *)
      Else If StrLowerCase(CurToken.Val) = 'low' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then BaseTIdx := SymTab[Idx].TypeIdx
            Else BaseTIdx := TY_IDX_INTEGER;
          End;
          LexNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Lo
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour Low');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* High(T) *)
      Else If StrLowerCase(CurToken.Val) = 'high' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then BaseTIdx := SymTab[Idx].TypeIdx
            Else BaseTIdx := TY_IDX_INTEGER;
          End;
          LexNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Hi
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour High');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* SizeOf(T) *)
      Else If StrLowerCase(CurToken.Val) = 'sizeof' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then BaseTIdx := SymTab[Idx].TypeIdx
            Else BaseTIdx := TY_IDX_INTEGER;
          End;
          LexNextToken;
          Res.ImmVal := TypeSizeof(BaseTIdx);
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour SizeOf');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Abs(n) *)
      Else If StrLowerCase(CurToken.Val) = 'abs' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('CWD');
        EmitInstrAB('XOR', 'AX', 'DX');
        EmitInstrAB('SUB', 'AX', 'DX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Sqr(n) *)
      Else If StrLowerCase(CurToken.Val) = 'sqr' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('IMUL', 'AX', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* Odd(n) *)
      Else If StrLowerCase(CurToken.Val) = 'odd' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('AND', 'AX', '1');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End

      (* Concat(s1, s2, ...) *)
      Else If StrLowerCase(CurToken.Val) = 'concat' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
        Begin
          LexNextToken;
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('PUSH', 'SI');
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstrA('POP', 'SI');
          EmitInstrA('CALL', VXP_RT_PFX + 'CONCAT');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      (* UpCase(c) *)
      Else If StrLowerCase(CurToken.Val) = 'upcase' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        LblUC := LabelGen;
        EmitInstrAB('CMP', 'AL', '''a''');
        EmitInstrA('JB', LblUC);
        EmitInstrAB('CMP', 'AL', '''z''');
        EmitInstrA('JA', LblUC);
        EmitInstrAB('AND', 'AL', '0DFh');
        EmitLabel(LblUC);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx  := -1;
      End

      (* EOF (stub retourne True=1) *)
      Else If StrLowerCase(CurToken.Val) = 'eof' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          LexNextToken;
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            LexNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            LexNextToken;
        End;
        EmitInstrAB('MOV', 'AX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End

      (* UPPERBOUND(a, n) *)
      Else If StrLowerCase(CurToken.Val) = 'upperbound' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        Idx := -1;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          Idx := SymFind(CurToken.Val);
          LexNextToken;
        End;
        (* Consommer la dimension optionnelle : , n *)
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          LexNextToken;
          If CurToken.Kind = TK_INTEGER Then LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        If (Idx >= 0) And (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[SymTab[Idx].TypeIdx].Hi))
        Else
        Begin
          WarnMsg('UPPERBOUND attend un tableau');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* LOWERBOUND(a, n) *)
      Else If StrLowerCase(CurToken.Val) = 'lowerbound' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        Idx := -1;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          Idx := SymFind(CurToken.Val);
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          LexNextToken;
          If CurToken.Kind = TK_INTEGER Then LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        If (Idx >= 0) And (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[SymTab[Idx].TypeIdx].Lo))
        Else
        Begin
          WarnMsg('LOWERBOUND attend un tableau');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* DIMENSION(a, n) : nombre d elements de la dimension n *)
      Else If StrLowerCase(CurToken.Val) = 'dimension' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          LexNextToken;
        Idx := -1;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          Idx := SymFind(CurToken.Val);
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          LexNextToken;
          If CurToken.Kind = TK_INTEGER Then LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        If (Idx >= 0) And (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[SymTab[Idx].TypeIdx].Hi -
                     TypeTab[SymTab[Idx].TypeIdx].Lo + 1))
        Else
        Begin
          WarnMsg('DIMENSION attend un tableau');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      (* EOLN (stub retourne True=1) *)
      Else If StrLowerCase(CurToken.Val) = 'eoln' Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          LexNextToken;
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            LexNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            LexNextToken;
        End;
        EmitInstrAB('MOV', 'AX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End

      Else
      Begin
      (* --- Resolution with-stack pour lecture champ --- *)
      WIdx := -1;
      If WithTop >= 0 Then
      Begin
        For WI := WithTop DownTo 0 Do
        Begin
          RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(CurToken.Val) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
          If WIdx >= 0 Then Break;
        End;
      End;
      If WIdx >= 0 Then
      Begin
        (* Champ trouve dans le with-stack *)
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'BX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz   := TypeSizeof(FldTIdx);
        If FldSz = 1 Then
        Begin
          EmitInstrAB('XOR', 'AH', 'AH');
          EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
        End
        Else
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := FldTIdx;
        Res.SymIdx  := -1;
        LexNextToken;
      End
      Else
      Begin
      (* --- Resolution standard ident --- *)
      Res.SymIdx := SymFind(CurToken.Val);
      If Res.SymIdx >= 0 Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  EXPR_IDENT: ', CurToken.Val,
                  ' -> sym[', Res.SymIdx, '] cat=',
                  Ord(SymTab[Res.SymIdx].Cat));
        Case SymTab[Res.SymIdx].Cat Of
          SC_CONST :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_TYPED_CONST :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_VAR, SC_PARAM, SC_VARPARAM, SC_STATIC :
          Begin
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
            Res.Offset  := SymTab[Res.SymIdx].Offset;
          End;
          SC_FUNC :
          Begin
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_ENUM_VAL :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
        Else
          Res.Kind    := EK_MEM;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INTEGER;
        End;
      End
      Else
      Begin
        WarnMsg('symbole non declare: ' + CurToken.Val);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End;
      LexNextToken;

      (* --- Detecter acces champ record : ident.field --- *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_RECORD) Then
        Begin
          RecTIdx := SymTab[Res.SymIdx].TypeIdx;
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'BX',
              BPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'BX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);
          FldTIdx := TY_IDX_INTEGER;
          While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Do
          Begin
            LexNextToken;  (* consommer . *)
            If CurToken.Kind = TK_IDENT Then
            Begin
              FldIdx := -1;
              For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
                If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
                   StrLowerCase(CurToken.Val) Then
                Begin
                  FldIdx := FI;
                  Break;
                End;
              If FldIdx >= 0 Then
              Begin
                If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
                  EmitInstrAB('ADD', 'BX',
                    IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
                FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
                LexNextToken;
                If (FldTIdx >= 0) And (FldTIdx < TypeCount) And
                   (TypeTab[FldTIdx].Kind = TKP_RECORD) Then
                  RecTIdx := FldTIdx;
              End
              Else
              Begin
                WarnMsg('champ inconnu: ' + CurToken.Val);
                LexNextToken;
                Break;
              End;
            End
            Else
            Begin
              WarnMsg('nom de champ attendu apres "."');
              Break;
            End;
          End;
          FldSz := TypeSizeof(FldTIdx);
          If FldSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
          End
          Else
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          Res.Kind    := EK_AX;
          Res.TypeIdx := FldTIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('acces "." sur un non-record');
          LexNextToken;
          If CurToken.Kind = TK_IDENT Then
            LexNextToken;
        End;
      End
      Else
      (* --- Detecter indexation tableau : ident[ --- *)
      If IsOpenBracket Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Res.SymIdx].TypeIdx;
          ArrLo   := TypeTab[ArrTIdx].Lo;
          ElemSz  := TypeSizeof(TypeTab[ArrTIdx].BaseTypeIdx);
          LexNextToken;  (* consommer [ *)
          ParseExpr(IdxExpr);
          ExprFlushToAX(IdxExpr);
          If ArrLo <> 0 Then
            EmitInstrAB('SUB', 'AX', IntToStr(ArrLo));
          If ElemSz = 2 Then
            EmitInstrAB('SHL', 'AX', '1')
          Else If (ElemSz <> 1) And (ElemSz > 2) Then
          Begin
            EmitInstrAB('MOV', 'CX', IntToStr(ElemSz));
            EmitInstr('MUL    CX');
          End;
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'BX',
              BPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'BX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);
          EmitInstrAB('ADD', 'BX', 'AX');
          If ElemSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
          End
          Else
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          If IsCloseBracket Then
            LexNextToken;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TypeTab[ArrTIdx].BaseTypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('indexation sur un non-tableau');
          LexNextToken;
          While (CurToken.Kind <> TK_EOF) And
                Not IsCloseBracket Do
            LexNextToken;
          If IsCloseBracket Then
            LexNextToken;
        End;
      End
      (* --- Detecter un appel de fonction : ident( --- *)
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        If (Res.SymIdx >= 0) And
           (SymTab[Res.SymIdx].Cat In [SC_FUNC, SC_PROC]) Then
        Begin
          EmitComment('call ' + SymTab[Res.SymIdx].Name);
          ParseCallArgs(Res.SymIdx);
          EmitInstrA('CALL', SymTab[Res.SymIdx].MangledName);
          Res.Kind    := EK_AX;
          Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          LexNextToken;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ')')) Do
            LexNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            LexNextToken;
          Res.Kind := EK_AX;
        End;
      End
      (* --- Dereferencement pointeur : ident^ --- *)
      Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
      Begin
        LexNextToken;  (* consommer ^ *)
        If (Res.SymIdx >= 0) Then
        Begin
          ExprFlushToAX(Res);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          Res.Kind    := EK_AX;
          If (Res.TypeIdx >= 0) And (Res.TypeIdx < TypeCount) And
             (TypeTab[Res.TypeIdx].BaseTypeIdx >= 0) Then
            Res.TypeIdx := TypeTab[Res.TypeIdx].BaseTypeIdx
          Else
            Res.TypeIdx := TY_IDX_INTEGER;
          Res.SymIdx  := -1;
        End;
      End;
      End; (* fin Else Begin Resolution standard ident *)
      End; (* fin du else (ident standard / with-stack) *)
    End;

    (* --- Sous-expression parenthesee --- *)
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        LexNextToken;
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken
        Else
          WarnMsg(''')'' attendu apres expression parenthesee');
      End
      Else
      Begin
        WarnMsg('token inattendu dans expression: ' + CurToken.Val);
        LexNextToken;
      End;
    End;

  Else
    WarnMsg('expression attendue, token: ' + CurToken.Val);
    LexNextToken;
  End;
End;

(* ---- ParseUnary : operateurs unaires prefixes --------------- *)
(* Niveau 8 : not, -, +, @, ^                                    *)
Procedure ParseUnary(Var Res : TExprVal);
Begin
  (* not (logique ou bits selon type) *)
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    LexNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.ImmVal := Not Res.ImmVal;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
        EmitInstrAB('XOR', 'AX', '1')
      Else
        EmitInstr('NOT    AX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  (* Moins unaire *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    LexNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG    AX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  (* Plus unaire (no-op) *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    LexNextToken;
    ParseUnary(Res);
    Exit;
  End;

  (* @ (adresse de) *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
  Begin
    LexNextToken;
    ParsePrimary(Res);
    If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) Then
    Begin
      If SymTab[Res.SymIdx].IsLocal Then
        EmitInstrAB('LEA', 'AX',
          BPOfs(SymTab[Res.SymIdx].Offset))
      Else
        EmitInstrAB('MOV', 'AX',
          'OFFSET ' + SymTab[Res.SymIdx].MangledName);
    End
    Else
    Begin
      WarnMsg('@ requiert une variable ou un parametre');
      EmitInstrAB('XOR', 'AX', 'AX');
    End;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_POINTER;
    Res.SymIdx  := -1;
    Exit;
  End;

  (* Pas d operateur unaire : ParsePrimary *)
  ParsePrimary(Res);
End;

(* ---- ParseExprPrec : Pratt parser pour operateurs binaires --- *)
(* Boucle de montee de precedence. AX=gauche, BX=droite.          *)
(* Gere || (concatenation), ** (exponentiation), ANDIF, ORIF.     *)
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  ResType   : Integer;
  LblSkip   : TString;
  LblPow    : TString;
  LblPowEnd : TString;
  PowAccum  : LongInt;
  PowI      : Integer;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    (* Detecter operateur binaire *)
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'div') Or (CurToken.Val = 'mod') Or
             (CurToken.Val = 'and') Or (CurToken.Val = 'or') Or
             (CurToken.Val = 'xor') Or (CurToken.Val = 'shl') Or
             (CurToken.Val = 'shr') Or (CurToken.Val = 'in') Or
             (CurToken.Val = 'andif') Or (CurToken.Val = 'orif')) Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End;

    (* Arreter si pas operateur ou precedence insuffisante *)
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    LexNextToken;  (* consommer l operateur *)

    (* ---- ANDIF : evaluation court-circuit ---- *)
    If Op = 'andif' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := NewLabel;
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JE', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* ---- ORIF : evaluation court-circuit ---- *)
    If Op = 'orif' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := NewLabel;
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JNE', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Sauvegarder operande gauche *)
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;

    (* Recurser cote droit (gauche-assoc : Prec + 1) *)
    ParseExprPrec(Prec + 1, Right);

    (* Pliage de constantes si les deux sont immediats *)
    If LeftIsImm And (Right.Kind = EK_IMM) Then
    Begin
      If Op = '+' Then
        ExprMakeImm(LeftImm + Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '-' Then
        ExprMakeImm(LeftImm - Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '*' Then
        ExprMakeImm(LeftImm * Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Div Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('division par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'mod' Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Mod Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('modulo par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'and' Then
        ExprMakeImm(LeftImm And Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'or' Then
        ExprMakeImm(LeftImm Or Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(LeftImm Xor Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'shl' Then
        ExprMakeImm(LeftImm Shl Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      Else If Op = 'shr' Then
        ExprMakeImm(LeftImm Shr Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      Else If Op = '**' Then
      Begin
        (* Exponentiation constante *)
        If Right.ImmVal = 0 Then
          ExprMakeImm(1, TY_IDX_INTEGER, Res)
        Else If Right.ImmVal = 1 Then
          ExprMakeImm(LeftImm, TY_IDX_INTEGER, Res)
        Else
        Begin
          PowAccum := 1;
          For PowI := 1 To Integer(Right.ImmVal) Do
            PowAccum := PowAccum * LeftImm;
          ExprMakeImm(PowAccum, TY_IDX_INTEGER, Res);
        End;
      End
      (* Comparaisons -> booleen *)
      Else If Op = '=' Then
        ExprMakeImm(Ord(LeftImm = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<>' Then
        ExprMakeImm(Ord(LeftImm <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<' Then
        ExprMakeImm(Ord(LeftImm < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>' Then
        ExprMakeImm(Ord(LeftImm > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<=' Then
        ExprMakeImm(Ord(LeftImm <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(LeftImm >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = 'in' Then
      Begin
        WarnMsg('in : ensembles non supportes, retourne 0');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End
    Else
    Begin
      (* ---- Emission de code binaire ---- *)
      ResType := Res.TypeIdx;
      If (Res.TypeIdx = TY_IDX_STRING) Or (Right.TypeIdx = TY_IDX_STRING) Or
         (Res.TypeIdx = TY_IDX_VARYING) Or (Right.TypeIdx = TY_IDX_VARYING) Then
        ResType := TY_IDX_STRING
      Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
              (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
        ResType := TY_IDX_BOOLEAN;

      (* Charger droite dans BX *)
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');

      (* Restaurer gauche dans AX *)
      If LeftIsImm Then
        EmitInstrAB('MOV', 'AX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'AX');

      (* AX = gauche, BX = droite *)

      (* --- Arithmetique --- *)
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'CONCAT');
        End
        Else
          EmitInstrAB('ADD', 'AX', 'BX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')

      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')

      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
      End

      Else If Op = 'mod' Then
      Begin
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');
      End

      (* --- Concatenation || --- *)
      Else If Op = '||' Then
      Begin
        EmitComment('|| concatenation');
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'DI', 'BX');
        EmitInstrA('CALL', VXP_RT_PFX + 'CONCAT');
        ResType := TY_IDX_STRING;
      End

      (* --- Exponentiation ** --- *)
      Else If Op = '**' Then
      Begin
        EmitComment('** exponentiation');
        (* AX = base, BX = exposant *)
        (* Boucle : CX=exposant, AX=resultat, DX=base *)
        EmitInstrAB('MOV', 'CX', 'BX');  (* CX = exposant *)
        EmitInstrAB('MOV', 'DX', 'AX');  (* DX = base *)
        EmitInstrAB('MOV', 'AX', '1');   (* AX = resultat = 1 *)
        LblPow := NewLabel;
        LblPowEnd := NewLabel;
        EmitInstrAB('CMP', 'CX', '0');
        EmitInstrA('JLE', LblPowEnd);
        EmitLabel(LblPow);
        EmitInstrA('IMUL', 'DX');         (* AX = AX * DX *)
        EmitInstr('DEC    CX');
        EmitInstrA('JNZ', LblPow);
        EmitLabel(LblPowEnd);
        ResType := TY_IDX_INTEGER;
      End

      (* --- Bits / Logiques --- *)
      Else If Op = 'and' Then
        EmitInstrAB('AND', 'AX', 'BX')

      Else If Op = 'or' Then
        EmitInstrAB('OR', 'AX', 'BX')

      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'AX', 'BX')

      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'AX', 'CL');
      End

      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'AX', 'CL');
      End

      (* --- Comparaisons : CMP + Jcc -> AX = 0|1 --- *)
      Else If Op = '=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = 'in' Then
      Begin
        EmitInstrAB('XOR', 'AX', 'AX');
        WarnMsg('in : ensembles non supportes, retourne 0');
      End;

      Res.Kind    := EK_AX;
      Res.TypeIdx := ResType;
      Res.SymIdx  := -1;
    End;
  Until False;
End;

(* ---- ParseExpr : point d entree pour les expressions --------- *)
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  DECLARATIONS DE VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

(* ---- ParseVarAttributes : lire les attributs VAX entre [] ---- *)
(* Retourne les drapeaux via les parametres var.                   *)
(* Attributs supportes : EXTERNAL, GLOBAL, VOLATILE, READONLY,    *)
(*   WRITEONLY, ALIGNED(n), WORD, UNSAFE, HIDDEN, UNBOUND, POS(n) *)
Procedure ParseVarAttributes(Var IsExternal, IsGlobal, IsVolatile,
                              IsReadOnly, IsWriteOnly,
                              IsWord, IsUnsafe,
                              IsHidden, IsUnbound : Boolean;
                              Var AlignVal, PosVal : Integer);
Var
  Attr : TString;
Begin
  IsExternal  := False;
  IsGlobal    := False;
  IsVolatile  := False;
  IsReadOnly  := False;
  IsWriteOnly := False;
  IsWord      := False;
  IsUnsafe    := False;
  IsHidden    := False;
  IsUnbound   := False;
  AlignVal    := 0;
  PosVal      := -1;

  If Not IsOpenBracket Then
    Exit;

  LexNextToken;  (* consommer [ *)
  While (CurToken.Kind <> TK_EOF) And
        Not IsCloseBracket Do
  Begin
    Attr := StrLowerCase(CurToken.Val);

    If Attr = 'external' Then
      IsExternal := True
    Else If Attr = 'global' Then
      IsGlobal := True
    Else If Attr = 'volatile' Then
      IsVolatile := True
    Else If Attr = 'readonly' Then
      IsReadOnly := True
    Else If Attr = 'writeonly' Then
      IsWriteOnly := True
    Else If Attr = 'word' Then
      IsWord := True
    Else If Attr = 'unsafe' Then
      IsUnsafe := True
    Else If Attr = 'hidden' Then
      IsHidden := True
    Else If Attr = 'unbound' Then
      IsUnbound := True
    Else If Attr = 'aligned' Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          AlignVal := CurToken.IntVal;
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
      Continue;
    End
    Else If Attr = 'pos' Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          PosVal := CurToken.IntVal;
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
      Continue;
    End
    Else
      WarnMsg('attribut VAX inconnu: ' + CurToken.Val);

    LexNextToken;

    (* virgule entre attributs *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken;
  End;

  (* consommer ] *)
  If IsCloseBracket Then
    LexNextToken;
End;

(* ---- ParseVarDecl : analyser un bloc VAR ---------------------- *)
(* Syntaxe VAX Pascal :                                            *)
(*   VAR a, b : Integer;                                           *)
(*   VAR s : VARYING [80] OF CHAR;                                 *)
(*   VAR p : ^Integer;                                             *)
(*   [EXTERNAL] VAR x : Integer;                                   *)
(*   [GLOBAL]   VAR x : Integer;                                   *)
(*   STATIC VAR x : Integer := 0;                                  *)
(*   EXTERNAL VAR x : Integer;                                     *)
Procedure ParseVarDecl;
Var
  Names    : Array[0..MAX_PARAM - 1] Of TString;
  NCount   : Integer;
  TName    : TString;
  TIdx     : Integer;
  TSz      : Integer;
  I, Idx   : Integer;
  DIdx     : Integer;
  (* VAX attributes *)
  AttrExternal, AttrGlobal, AttrVolatile : Boolean;
  AttrReadOnly, AttrWriteOnly : Boolean;
  AttrWord, AttrUnsafe : Boolean;
  AttrHidden, AttrUnbound : Boolean;
  AttrAlignVal, AttrPosVal : Integer;
  IsStaticVar   : Boolean;
  IsExternalVar : Boolean;
  UseCat        : TSymCat;
  (* Tableaux *)
  ArrLo, ArrHi   : LongInt;
  ArrCount        : LongInt;
  ArrSize         : LongInt;
  ElemTIdx        : Integer;
  NewArrTIdx      : Integer;
  ElemTName       : TString;
  ElemSz          : Integer;
  (* VARYING *)
  VaryLen         : Integer;
  NewVaryTIdx     : Integer;
  (* Pointeurs *)
  IsPtr           : Boolean;
  BaseTIdx        : Integer;
  NewPtrTIdx      : Integer;
  (* Initialisation *)
  InitEv          : TExprVal;
Begin
  (* Le mot-cle VAR a deja ete consomme par l appelant *)
  HasPendingAssign := False;

  (* Detecter STATIC VAR et EXTERNAL VAR *)
  IsStaticVar   := False;
  IsExternalVar := False;

  While (CurToken.Kind = TK_IDENT) Or IsOpenBracket Do
  Begin
    (* Lire les attributs VAX optionnels *)
    AttrExternal  := False;
    AttrGlobal    := False;
    AttrVolatile  := False;
    AttrReadOnly  := False;
    AttrWriteOnly := False;
    AttrWord      := False;
    AttrUnsafe    := False;
    AttrHidden    := False;
    AttrUnbound   := False;
    AttrAlignVal  := 0;
    AttrPosVal    := -1;

    If IsOpenBracket Then
    Begin
      ParseVarAttributes(AttrExternal, AttrGlobal, AttrVolatile,
        AttrReadOnly, AttrWriteOnly, AttrWord, AttrUnsafe,
        AttrHidden, AttrUnbound, AttrAlignVal, AttrPosVal);
    End;

    (* Apres attributs VAX, il peut y avoir le mot-cle VAR *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'var') Then
      LexNextToken;

    (* Apres attributs, detecter STATIC ou EXTERNAL *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'static') Then
    Begin
      IsStaticVar := True;
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
        LexNextToken;
    End;
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'external') Then
    Begin
      AttrExternal := True;
      IsExternalVar := True;
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
        LexNextToken;
    End;

    (* Premier identifiant *)
    If CurToken.Kind <> TK_IDENT Then Break;
    Names[0] := CurToken.Val;
    NCount := 1;
    LexNextToken;

    (* Si := suit, c est une affectation, pas une declaration var *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      PendingAssignName := Names[0];
      HasPendingAssign  := True;
      Exit;  (* Quitter ParseVarDecl, laisser CurToken sur := *)
    End;

    (* Collecter d eventuels noms supplementaires separes par virgule *)
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      LexNextToken;
      If CurToken.Kind = TK_IDENT Then
      Begin
        If NCount < MAX_PARAM Then
        Begin
          Names[NCount] := CurToken.Val;
          Inc(NCount);
        End
        Else
          WarnMsg('trop de variables dans une declaration');
        LexNextToken;
      End
      Else
      Begin
        WarnMsg('identificateur attendu apres virgule');
        Break;
      End;
    End;

    (* Deux-points + nom de type *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':'' attendu apres le(s) nom(s) de variable');
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* Determiner la categorie de symbole *)
    UseCat := SC_VAR;
    If IsStaticVar Or AttrExternal Then
    Begin
      If AttrExternal Then
        UseCat := SC_EXTERNAL
      Else
        UseCat := SC_STATIC;
    End
    Else If IsExternalVar Then
      UseCat := SC_EXTERNAL
    Else If AttrGlobal Then
      UseCat := SC_GLOBAL;

    (* --- Detection pointeur ^Type --- *)
    IsPtr := False;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
    Begin
      IsPtr := True;
      LexNextToken;
    End;

    (* --- Detection VARYING [n] OF CHAR --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'varying') Then
    Begin
      LexNextToken;  (* consommer VARYING *)
      VaryLen := 80;  (* defaut *)
      If IsOpenBracket Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          VaryLen := CurToken.IntVal;
          LexNextToken;
        End;
        If IsCloseBracket Then
          LexNextToken;
      End;
      (* consommer OF *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;
      (* consommer CHAR *)
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
        LexNextToken;

      (* Creer un type VARYING *)
      NewVaryTIdx := TY_IDX_VARYING;
      If TypeCount < MAX_TYPE Then
      Begin
        NewVaryTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewVaryTIdx].Kind     := TKP_VARYING;
        TypeTab[NewVaryTIdx].Size     := 2 + VaryLen;
        TypeTab[NewVaryTIdx].Hi       := VaryLen;
        TypeTab[NewVaryTIdx].Lo       := 0;
        TypeTab[NewVaryTIdx].BaseTypeIdx := TY_IDX_CHAR;
        TypeTab[NewVaryTIdx].FieldCount  := 0;
        TypeTab[NewVaryTIdx].EnumCount   := 0;
      End;

      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], UseCat, NewVaryTIdx);
        If Idx >= 0 Then
        Begin
          If (UseCat = SC_EXTERNAL) Then
          Begin
            SymTab[Idx].IsLocal := False;
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':WORD');
            If Opts.DebugMode Then
              WriteLn('  VAR_EXTERNAL: ', Names[I],
                      ' : VARYING[', VaryLen, ']');
          End
          Else If (CurScopeLevel = 0) Or (UseCat = SC_STATIC) Then
          Begin
            SymTab[Idx].IsLocal := False;
            DIdx := DataAddArray(SymTab[Idx].MangledName,
              2 + VaryLen, 1);
            SymTab[Idx].DataIdx := DIdx;
            If Opts.DebugMode Then
              WriteLn('  VAR_VARYING_GLOBAL: ', Names[I],
                      ' VARYING[', VaryLen, '] -> ',
                      SymTab[Idx].MangledName);
          End
          Else
          Begin
            Dec(CurFrameOffset, 2 + VaryLen);
            If (CurFrameOffset And 1) <> 0 Then
              Dec(CurFrameOffset);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_VARYING_LOCAL: ', Names[I],
                      ' VARYING[', VaryLen, '] -> [BP',
                      CurFrameOffset, ']');
          End;
        End;
      End;

      (* Point-virgule *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- Detection ARRAY[lo..hi] OF type --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      LexNextToken;  (* consommer ARRAY *)

      If IsOpenBracket Then
        LexNextToken
      Else
        WarnMsg('''['' attendu apres ARRAY');

      (* Borne inferieure *)
      ArrLo := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrLo := CurToken.IntVal;
        LexNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrLo := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne inferieure');
        LexNextToken;
      End;

      (* Consommer .. *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        LexNextToken
      Else
        WarnMsg('''..'' attendu dans declaration ARRAY');

      (* Borne superieure - support * pour tableaux conformants *)
      ArrHi := 0;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
      Begin
        ArrHi := 1;  (* placeholder conformant *)
        LexNextToken;
      End
      Else If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrHi := CurToken.IntVal;
        LexNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrHi := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne superieure');
        LexNextToken;
      End;

      If IsCloseBracket Then
        LexNextToken
      Else
        WarnMsg(''']'' attendu');

      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken
      Else
        WarnMsg('''OF'' attendu apres ARRAY[...]');

      ElemTName := '';
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        ElemTName := CurToken.Val;
        LexNextToken;
      End
      Else
        WarnMsg('type element attendu');

      ElemTIdx := TypeResolve(ElemTName);
      If ElemTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type element inconnu: ' + ElemTName);
        ElemTIdx := TY_IDX_INTEGER;
      End;
      ElemSz := TypeSizeof(ElemTIdx);

      ArrCount := ArrHi - ArrLo + 1;
      If ArrCount < 1 Then ArrCount := 1;
      ArrSize := ArrCount * ElemSz;

      NewArrTIdx := TY_IDX_INTEGER;
      If TypeCount < MAX_TYPE Then
      Begin
        NewArrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewArrTIdx].Kind        := TKP_ARRAY;
        TypeTab[NewArrTIdx].Size        := ArrSize;
        TypeTab[NewArrTIdx].BaseTypeIdx := ElemTIdx;
        TypeTab[NewArrTIdx].Lo          := ArrLo;
        TypeTab[NewArrTIdx].Hi          := ArrHi;
        TypeTab[NewArrTIdx].FieldCount  := 0;
        TypeTab[NewArrTIdx].EnumCount   := 0;
      End
      Else
        WarnMsg('nombre maximal de types atteint');

      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], UseCat, NewArrTIdx);
        If Idx >= 0 Then
        Begin
          If (UseCat = SC_EXTERNAL) Then
          Begin
            SymTab[Idx].IsLocal := False;
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':WORD');
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_EXTERNAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName);
          End
          Else If (CurScopeLevel = 0) Or (UseCat = SC_STATIC) Then
          Begin
            SymTab[Idx].MangledName := VXP_ARR_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddArray(
              SymTab[Idx].MangledName, ArrCount, ElemSz);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_GLOBAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> ',
                      SymTab[Idx].MangledName);
          End
          Else
          Begin
            Dec(CurFrameOffset, ArrSize);
            If (CurFrameOffset And 1) <> 0 Then
              Dec(CurFrameOffset);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_LOCAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> [BP',
                      CurFrameOffset, ']');
          End;
        End;
      End;

      (* Point-virgule *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- Lire le type standard ou identifiant --- *)
    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      LexNextToken;
    End
    Else
      WarnMsg('nom de type attendu');

    (* Resoudre le type *)
    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;
    End;
    TSz := TypeSizeof(TIdx);

    (* Si pointeur, creer un type pointeur *)
    If IsPtr Then
    Begin
      BaseTIdx := TIdx;
      NewPtrTIdx := TY_IDX_POINTER;
      If TypeCount < MAX_TYPE Then
      Begin
        NewPtrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewPtrTIdx].Kind        := TKP_POINTER;
        TypeTab[NewPtrTIdx].Size        := 2;
        TypeTab[NewPtrTIdx].BaseTypeIdx := BaseTIdx;
        TypeTab[NewPtrTIdx].FieldCount  := 0;
        TypeTab[NewPtrTIdx].EnumCount   := 0;
      End;
      TIdx := NewPtrTIdx;
      TSz  := 2;
    End;

    (* Si [WORD], forcer la taille a 2 *)
    If AttrWord Then TSz := 2;

    (* Enregistrer chaque variable *)
    For I := 0 To NCount - 1 Do
    Begin
      Idx := SymAdd(Names[I], UseCat, TIdx);
      If Idx >= 0 Then
      Begin
        (* Variable EXTERNAL : declarer EXTRN *)
        If (UseCat = SC_EXTERNAL) Then
        Begin
          SymTab[Idx].IsLocal := False;
          If TSz = 1 Then
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':BYTE')
          Else
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':WORD');
          If Opts.DebugMode Then
            WriteLn('  VAR_EXTERNAL: ', Names[I], ' : ', TName);
        End
        (* Variable GLOBAL : marquer PUBLIC *)
        Else If (UseCat = SC_GLOBAL) Then
        Begin
          SymTab[Idx].IsLocal := False;
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TKP_RECORD) Then
          Begin
            SymTab[Idx].MangledName := VXP_REC_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddRec(SymTab[Idx].MangledName, TSz);
          End
          Else If TSz = 1 Then
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0)
          Else
            DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
          SymTab[Idx].DataIdx := DIdx;
          EmitInstr('PUBLIC ' + SymTab[Idx].MangledName);
          If Opts.DebugMode Then
            WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                    ' -> ', SymTab[Idx].MangledName);
        End
        (* Variable STATIC : dans _DATA *)
        Else If (UseCat = SC_STATIC) Then
        Begin
          SymTab[Idx].IsLocal := False;
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TKP_RECORD) Then
          Begin
            SymTab[Idx].MangledName := VXP_REC_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddRec(SymTab[Idx].MangledName, TSz);
          End
          Else If TSz = 1 Then
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0)
          Else
            DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
          SymTab[Idx].DataIdx := DIdx;
          If Opts.DebugMode Then
            WriteLn('  VAR_STATIC: ', Names[I], ' : ', TName,
                    ' -> ', SymTab[Idx].MangledName);
        End
        (* Variable globale standard *)
        Else If CurScopeLevel = 0 Then
        Begin
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TKP_RECORD) Then
          Begin
            SymTab[Idx].MangledName := VXP_REC_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddRec(SymTab[Idx].MangledName, TSz);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_REC_GLOBAL: ', Names[I], ' : ',
                      TName, ' size=', TSz,
                      ' -> ', SymTab[Idx].MangledName);
          End
          Else If TSz = 1 Then
          Begin
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                      ' -> ', SymTab[Idx].MangledName);
          End
          Else
          Begin
            DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                      ' -> ', SymTab[Idx].MangledName);
          End;
        End
        Else
        Begin
          (* Variable locale : allouer sur la pile *)
          If TSz < 2 Then TSz := 2;
          Dec(CurFrameOffset, TSz);
          If (CurFrameOffset And 1) <> 0 Then
            Dec(CurFrameOffset);
          SymTab[Idx].Offset  := CurFrameOffset;
          SymTab[Idx].IsLocal := True;
          If Opts.DebugMode Then
            WriteLn('  VAR_LOCAL: ', Names[I], ' : ', TName,
                    ' -> [BP', CurFrameOffset, ']');
        End;
      End;
    End;

    (* Detecter initialisation optionnelle := valeur (STATIC VAR) *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      LexNextToken;  (* consommer := *)
      ParseExpr(InitEv);
      (* Pour les var globales/statiques, on peut optimiser *)
      (* en mettant la valeur dans DataTab directement     *)
      If (Idx >= 0) And Not SymTab[Idx].IsLocal Then
      Begin
        If (InitEv.Kind = EK_IMM) Then
        Begin
          If SymTab[Idx].DataIdx >= 0 Then
            DataTab[SymTab[Idx].DataIdx].IntVal := InitEv.ImmVal;
        End
        Else
        Begin
          (* Valeur dynamique : emettre du code *)
          ExprFlushToAX(InitEv);
          If TypeSizeof(SymTab[Idx].TypeIdx) = 1 Then
            EmitInstrAB('MOV',
              'BYTE PTR [' + SymTab[Idx].MangledName + ']', 'AL')
          Else
            EmitInstrAB('MOV',
              'WORD PTR [' + SymTab[Idx].MangledName + ']', 'AX');
        End;
      End
      Else If (Idx >= 0) And SymTab[Idx].IsLocal Then
      Begin
        ExprFlushToAX(InitEv);
        If TypeSizeof(SymTab[Idx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR ' + BPOfs(SymTab[Idx].Offset), 'AL')
        Else
          EmitInstrAB('MOV',
            'WORD PTR ' + BPOfs(SymTab[Idx].Offset), 'AX');
      End;
    End;

    (* Point-virgule *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

(* ---- ParseAssignment : analyser une affectation --------------- *)
(* Syntaxe : ident := expr ;                                       *)
(* Le nom de la variable a ete lu par l appelant.                  *)
(* CurToken est sur :=                                             *)
(* Gere aussi : r.field := expr, p^.field := expr, p^[i] := expr  *)
Procedure ParseAssignment(Const VarName : TString);
Var
  SIdx     : Integer;
  Ev       : TExprVal;
  FieldName: TString;
  FI, FIdx : Integer;
  FTIdx    : Integer;
  ArrEv    : TExprVal;
  WI       : Integer;
  WIdx     : Integer;
  RecTIdx  : Integer;
  FldIdx   : Integer;
  FldTIdx2 : Integer;
  FldSz    : Integer;
Begin
  (* Affectation a la valeur de retour : FuncName := expr *)
  If (CurFuncName <> '') And
     ((StrLowerCase(VarName) = CurFuncName) Or
      (StrLowerCase(VarName) = 'result')) Then
  Begin
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu pour l''affectation');
      Exit;
    End;

    EmitComment('assign retval ' + VarName);
    ParseExpr(Ev);
    ExprFlushToAX(Ev);
    EmitInstrAB('MOV',
      'WORD PTR ' + BPOfs(CurFuncRetOfs), 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* Rechercher la variable *)
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
  Begin
    (* --- WITH : resolution de champ non qualifie pour affectation --- *)
    If WithTop >= 0 Then
    Begin
      WIdx := -1;
      FldIdx := -1;
      For WI := WithTop DownTo 0 Do
      Begin
        RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
        For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
          If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
             StrLowerCase(VarName) Then
          Begin
            WIdx := WI;
            FldIdx := FI;
            Break;
          End;
        If WIdx >= 0 Then Break;
      End;
      If (WIdx >= 0) And (FldIdx >= 0) Then
      Begin
        (* Consommer := *)
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
          LexNextToken
        Else
        Begin
          WarnMsg(''':='' attendu');
          Exit;
        End;
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        EmitComment('with assign ' + VarName);
        ParseExpr(Ev);
        ExprFlushToAX(Ev);
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'BX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        FldTIdx2 := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz := TypeSizeof(FldTIdx2);
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
        Else
          EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Exit;
      End;
    End;
    WarnMsg('variable non declaree: ' + VarName);
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* Verifier que c est bien une variable/param *)
  If Not (SymTab[SIdx].Cat In [SC_VAR, SC_PARAM, SC_VARPARAM,
                                 SC_TYPED_CONST, SC_STATIC,
                                 SC_GLOBAL, SC_EXTERNAL]) Then
  Begin
    WarnMsg('cible d''affectation invalide: ' + VarName);
  End;

  (* --- Acces champ record : ident.field := expr --- *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
  Begin
    LexNextToken;  (* consommer . *)
    FieldName := '';
    If CurToken.Kind = TK_IDENT Then
    Begin
      FieldName := CurToken.Val;
      LexNextToken;
    End;

    (* Consommer := *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu pour l''affectation de champ');
      Exit;
    End;

    EmitComment('assign ' + VarName + '.' + FieldName);
    ParseExpr(Ev);
    ExprFlushToAX(Ev);

    (* Calculer l offset du champ dans le record *)
    FTIdx := SymTab[SIdx].TypeIdx;
    FIdx := -1;
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_RECORD) Then
    Begin
      For FI := 0 To TypeTab[FTIdx].FieldCount - 1 Do
      Begin
        If StrLowerCase(TypeTab[FTIdx].Fields[FI].Name) =
           StrLowerCase(FieldName) Then
        Begin
          FIdx := FI;
          Break;
        End;
      End;
    End;

    If FIdx < 0 Then
    Begin
      WarnMsg('champ inconnu: ' + FieldName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* Emettre le store *)
    If SymTab[SIdx].IsLocal Then
    Begin
      If SymTab[SIdx].Cat = SC_VARPARAM Then
      Begin
        EmitInstrAB('MOV', 'BX',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
        If TypeTab[FTIdx].Fields[FIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'BX',
            IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
        EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
      End
      Else
      Begin
        EmitInstrAB('MOV',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset +
            TypeTab[FTIdx].Fields[FIdx].Offset), 'AX');
      End;
    End
    Else
    Begin
      If TypeTab[FTIdx].Fields[FIdx].Offset = 0 Then
        EmitInstrAB('MOV',
          'WORD PTR [' + SymTab[SIdx].MangledName + ']', 'AX')
      Else
      Begin
        EmitInstrAB('MOV', 'BX',
          'OFFSET ' + SymTab[SIdx].MangledName);
        EmitInstrAB('ADD', 'BX',
          IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
        EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* --- Acces pointeur dereference : p^ := expr ou p^.f := expr --- *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
  Begin
    LexNextToken;  (* consommer ^ *)

    (* p^.field := expr *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      LexNextToken;
      FieldName := '';
      If CurToken.Kind = TK_IDENT Then
      Begin
        FieldName := CurToken.Val;
        LexNextToken;
      End;

      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        LexNextToken
      Else
      Begin
        WarnMsg(''':='' attendu');
        Exit;
      End;

      EmitComment('assign ' + VarName + '^.' + FieldName);
      ParseExpr(Ev);
      ExprFlushToAX(Ev);

      (* Charger le pointeur *)
      If SymTab[SIdx].IsLocal Then
        EmitInstrAB('MOV', 'BX',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset))
      Else
        EmitInstrAB('MOV', 'BX',
          'WORD PTR [' + SymTab[SIdx].MangledName + ']');

      (* Trouver l offset du champ dans le type pointe *)
      FTIdx := SymTab[SIdx].TypeIdx;
      If (FTIdx >= 0) And (FTIdx < TypeCount) And
         (TypeTab[FTIdx].Kind = TKP_POINTER) Then
        FTIdx := TypeTab[FTIdx].BaseTypeIdx;
      FIdx := -1;
      If (FTIdx >= 0) And (FTIdx < TypeCount) And
         (TypeTab[FTIdx].Kind = TKP_RECORD) Then
      Begin
        For FI := 0 To TypeTab[FTIdx].FieldCount - 1 Do
          If StrLowerCase(TypeTab[FTIdx].Fields[FI].Name) =
             StrLowerCase(FieldName) Then
          Begin
            FIdx := FI;
            Break;
          End;
      End;

      If (FIdx >= 0) And (TypeTab[FTIdx].Fields[FIdx].Offset > 0) Then
        EmitInstrAB('ADD', 'BX',
          IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
      EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* p^[i] := expr -- tableau via pointeur *)
    If IsOpenBracket Then
    Begin
      LexNextToken;  (* consommer [ *)
      EmitComment('assign ' + VarName + '^[i]');

      ParseExpr(ArrEv);
      ExprFlushToAX(ArrEv);
      EmitPush('AX');

      If IsCloseBracket Then
        LexNextToken;

      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        LexNextToken
      Else
        WarnMsg(''':='' attendu');

      ParseExpr(Ev);
      ExprFlushToAX(Ev);
      EmitPush('AX');  (* valeur *)

      (* Charger le pointeur *)
      If SymTab[SIdx].IsLocal Then
        EmitInstrAB('MOV', 'BX',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset))
      Else
        EmitInstrAB('MOV', 'BX',
          'WORD PTR [' + SymTab[SIdx].MangledName + ']');

      (* Calculer l adresse : BX + index * elemsize *)
      EmitPop('CX');   (* valeur *)
      EmitPop('AX');   (* index *)
      EmitInstrAB('SHL', 'AX', '1');  (* * 2 pour WORD *)
      EmitInstrAB('ADD', 'BX', 'AX');
      EmitInstrAB('MOV', 'AX', 'CX');
      EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* p^ := expr -- simple dereference *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu apres ^');
      Exit;
    End;

    EmitComment('assign ' + VarName + '^');
    ParseExpr(Ev);
    ExprFlushToAX(Ev);

    If SymTab[SIdx].IsLocal Then
      EmitInstrAB('MOV', 'BX',
        'WORD PTR ' + BPOfs(SymTab[SIdx].Offset))
    Else
      EmitInstrAB('MOV', 'BX',
        'WORD PTR [' + SymTab[SIdx].MangledName + ']');
    EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* --- Acces tableau : ident[index] := expr --- *)
  If IsOpenBracket Then
  Begin
    LexNextToken;  (* consommer [ *)

    EmitComment('assign ' + VarName + '[i]');
    ParseExpr(ArrEv);
    ExprFlushToAX(ArrEv);

    (* Soustraire la borne inferieure *)
    FTIdx := SymTab[SIdx].TypeIdx;
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) And
       (TypeTab[FTIdx].Lo <> 0) Then
      EmitInstrAB('SUB', 'AX', IntToStr(TypeTab[FTIdx].Lo));

    (* Multiplier par la taille element *)
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) Then
    Begin
      If TypeSizeof(TypeTab[FTIdx].BaseTypeIdx) = 2 Then
        EmitInstrAB('SHL', 'AX', '1')
      Else If TypeSizeof(TypeTab[FTIdx].BaseTypeIdx) > 2 Then
      Begin
        EmitInstrAB('MOV', 'CX',
          IntToStr(TypeSizeof(TypeTab[FTIdx].BaseTypeIdx)));
        EmitInstrAB('MUL', 'CX', '');
      End;
    End
    Else
      EmitInstrAB('SHL', 'AX', '1');

    EmitPush('AX');  (* sauver offset *)

    (* Detecter substring VAX : [pos:len] *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      LexNextToken;
      ParseExpr(ArrEv);
      (* Stub substring : ignorer len pour l instant *)
      WarnMsg('substring VAX [pos:len] : stub, seul pos est utilise');
    End;

    If IsCloseBracket Then
      LexNextToken;

    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu');
      EmitPop('BX');
      Exit;
    End;

    ParseExpr(Ev);
    ExprFlushToAX(Ev);

    EmitPop('BX');  (* recuperer offset *)

    (* Calculer adresse base + offset *)
    If SymTab[SIdx].IsLocal Then
    Begin
      EmitInstrAB('LEA', 'SI',
        BPOfs(SymTab[SIdx].Offset));
      EmitInstrAB('ADD', 'BX', 'SI');
    End
    Else
    Begin
      EmitInstrAB('ADD', 'BX',
        'OFFSET ' + SymTab[SIdx].MangledName);
    End;
    (* Ecriture selon la taille de l element *)
    FTIdx := SymTab[SIdx].TypeIdx;
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) And
       (TypeSizeof(TypeTab[FTIdx].BaseTypeIdx) = 1) Then
      EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
    Else
      EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* --- Affectation simple : ident := expr --- *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    LexNextToken
  Else
  Begin
    WarnMsg(''':='' attendu pour l''affectation');
    Exit;
  End;

  EmitComment('assign ' + VarName);

  ParseExpr(Ev);

  (* Verification de compatibilite de type *)
  If (SymTab[SIdx].TypeIdx <> TY_UNKNOWN) And
     (Ev.TypeIdx <> TY_UNKNOWN) Then
  Begin
    If Not TypeCompatible(SymTab[SIdx].TypeIdx, Ev.TypeIdx) Then
      WarnMsg('type incompatible dans l''affectation de ' + VarName);
  End;

  ExprFlushToAX(Ev);

  (* Stocker AX dans la cible *)
  If SymTab[SIdx].IsLocal Then
  Begin
    If SymTab[SIdx].Cat = SC_VARPARAM Then
    Begin
      EmitInstrAB('MOV', 'BX',
        'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
      EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
    End
    Else
    Begin
      If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
        EmitInstrAB('MOV',
          'BYTE PTR ' + BPOfs(SymTab[SIdx].Offset), 'AL')
      Else
        EmitInstrAB('MOV',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset), 'AX');
    End;
  End
  Else
  Begin
    If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
      EmitInstrAB('MOV',
        'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
    Else
      EmitInstrAB('MOV',
        'WORD PTR [' + SymTab[SIdx].MangledName + ']', 'AX');
  End;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;
End;

(* ---- ParseValueSection : analyser le bloc VALUE (VMS) --------- *)
(* Syntaxe :                                                        *)
(*   VALUE                                                          *)
(*     x := 10;                                                     *)
(*     s := 'default';                                              *)
(* Initialise des variables declarees dans VAR.                     *)
Procedure ParseValueSection;
Var
  VName : TString;
  SIdx  : Integer;
  Ev    : TExprVal;
Begin
  (* Le mot-cle VALUE a deja ete consomme *)
  While CurToken.Kind = TK_IDENT Do
  Begin
    VName := CurToken.Val;
    LexNextToken;

    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu dans la section VALUE');
      Break;
    End;

    SIdx := SymFind(VName);
    If SIdx < 0 Then
    Begin
      WarnMsg('variable non declaree dans VALUE: ' + VName);
      (* Sauter jusqu au ; *)
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    EmitComment('value init ' + VName);
    ParseExpr(Ev);

    (* Si constante immediate et var globale, mettre dans DataTab *)
    If Not SymTab[SIdx].IsLocal And (Ev.Kind = EK_IMM) Then
    Begin
      If SymTab[SIdx].DataIdx >= 0 Then
        DataTab[SymTab[SIdx].DataIdx].IntVal := Ev.ImmVal;
    End
    Else
    Begin
      ExprFlushToAX(Ev);
      If SymTab[SIdx].IsLocal Then
      Begin
        If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR ' + BPOfs(SymTab[SIdx].Offset), 'AL')
        Else
          EmitInstrAB('MOV',
            'WORD PTR ' + BPOfs(SymTab[SIdx].Offset), 'AX');
      End
      Else
      Begin
        If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
        Else
          EmitInstrAB('MOV',
            'WORD PTR [' + SymTab[SIdx].MangledName + ']', 'AX');
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

(* ---- ParseConstDecl : analyser un bloc CONST ----------------  *)
(* Syntaxe :                                                       *)
(*   const x = 42;                   (standard Pascal)             *)
(*   const x := 42;                  (VAX Pascal typed const)      *)
(*   const x : Integer = 42;         (typed const standard)        *)
Procedure ParseConstDecl;
Var
  CName   : TString;
  ConstEv : TExprVal;
  CIdx    : Integer;
  DIdx    : Integer;
  (* Const ARRAY *)
  ConstArrLo     : LongInt;
  ConstArrHi     : LongInt;
  ConstArrCount  : LongInt;
  ConstArrTIdx   : Integer;
  ConstElemTIdx  : Integer;
  ConstElemSz    : Integer;
  ConstElemTName : TString;
  ConstInitStr   : TString;
  ConstInitCount : Integer;
Begin
  (* Le mot-cle CONST a deja ete consomme *)
  While CurToken.Kind = TK_IDENT Do
  Begin
    CName := CurToken.Val;
    LexNextToken;

    (* const x = valeur (standard Pascal, untyped const) *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      LexNextToken;
      ParseExpr(ConstEv);
      If ConstEv.Kind = EK_IMM Then
      Begin
        CIdx := SymAdd(CName, SC_CONST, ConstEv.TypeIdx);
        If CIdx >= 0 Then
          SymTab[CIdx].ImmVal := ConstEv.ImmVal;
      End
      Else
        WarnMsg('constante attendue');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* const x := valeur (VAX Pascal typed const avec :=) *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      LexNextToken;
      ParseExpr(ConstEv);
      If ConstEv.Kind = EK_IMM Then
      Begin
        CIdx := SymAdd(CName, SC_TYPED_CONST, ConstEv.TypeIdx);
        If CIdx >= 0 Then
        Begin
          SymTab[CIdx].ImmVal := ConstEv.ImmVal;
          SymTab[CIdx].IsLocal := False;
          DIdx := DataAddWord(SymTab[CIdx].MangledName,
            ConstEv.ImmVal);
          SymTab[CIdx].DataIdx := DIdx;
        End;
      End
      Else
        WarnMsg('constante attendue pour const :=');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* const x : type = valeur (typed const standard) *)
    (* const tab : ARRAY[lo..hi] OF type = (v1, v2, ...); *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      LexNextToken;

      (* --- Detection ARRAY[lo..hi] OF type = (valeurs) --- *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'array') Then
      Begin
        LexNextToken;  (* consommer ARRAY *)
        If IsOpenBracket Then LexNextToken;
        ConstArrLo := 0;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          ConstArrLo := CurToken.IntVal;
          LexNextToken;
        End
        Else If (CurToken.Kind = TK_IDENT) Or
                (CurToken.Kind = TK_KEYWORD) Then
        Begin
          CIdx := SymFind(CurToken.Val);
          If (CIdx >= 0) And
             (SymTab[CIdx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
            ConstArrLo := SymTab[CIdx].ImmVal;
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
          LexNextToken;
        ConstArrHi := 0;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          ConstArrHi := CurToken.IntVal;
          LexNextToken;
        End
        Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
        Begin
          ConstArrHi := 1;
          LexNextToken;
        End
        Else If (CurToken.Kind = TK_IDENT) Or
                (CurToken.Kind = TK_KEYWORD) Then
        Begin
          CIdx := SymFind(CurToken.Val);
          If (CIdx >= 0) And
             (SymTab[CIdx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
            ConstArrHi := SymTab[CIdx].ImmVal;
          LexNextToken;
        End;
        If IsCloseBracket Then LexNextToken;
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'of') Then
          LexNextToken;
        ConstElemTName := '';
        If (CurToken.Kind = TK_KEYWORD) Or
           (CurToken.Kind = TK_IDENT) Then
        Begin
          ConstElemTName := CurToken.Val;
          LexNextToken;
        End;
        ConstElemTIdx := TypeResolve(ConstElemTName);
        If ConstElemTIdx = TY_UNKNOWN Then
          ConstElemTIdx := TY_IDX_INTEGER;
        ConstElemSz := TypeSizeof(ConstElemTIdx);
        ConstArrCount := ConstArrHi - ConstArrLo + 1;
        If ConstArrCount < 1 Then ConstArrCount := 1;

        (* Creer le type tableau *)
        ConstArrTIdx := TY_IDX_INTEGER;
        If TypeCount < MAX_TYPE Then
        Begin
          ConstArrTIdx := TypeCount;
          Inc(TypeCount);
          TypeTab[ConstArrTIdx].Kind        := TKP_ARRAY;
          TypeTab[ConstArrTIdx].Size        := ConstArrCount * ConstElemSz;
          TypeTab[ConstArrTIdx].BaseTypeIdx := ConstElemTIdx;
          TypeTab[ConstArrTIdx].Lo          := ConstArrLo;
          TypeTab[ConstArrTIdx].Hi          := ConstArrHi;
          TypeTab[ConstArrTIdx].FieldCount  := 0;
          TypeTab[ConstArrTIdx].EnumCount   := 0;
        End;

        (* Consommer = *)
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          LexNextToken;

        (* Parser les valeurs initiales (val1, val2, ...) *)
        ConstInitStr := '';
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          LexNextToken;
          ConstInitCount := 0;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          Begin
            If ConstInitCount > 0 Then
              ConstInitStr := ConstInitStr + ',';
            (* Lire une valeur : entier, negatif, char, string, ident *)
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
            Begin
              LexNextToken;
              If CurToken.Kind = TK_INTEGER Then
              Begin
                ConstInitStr := ConstInitStr + IntToStr(-CurToken.IntVal);
                LexNextToken;
              End
              Else
              Begin
                ConstInitStr := ConstInitStr + '0';
                LexNextToken;
              End;
            End
            Else If CurToken.Kind = TK_INTEGER Then
            Begin
              ConstInitStr := ConstInitStr + IntToStr(CurToken.IntVal);
              LexNextToken;
            End
            Else If CurToken.Kind = TK_STRING Then
            Begin
              (* String constante : pour les arrays de char/string *)
              If Length(CurToken.Val) = 1 Then
                ConstInitStr := ConstInitStr + IntToStr(Ord(CurToken.Val[1]))
              Else
                ConstInitStr := ConstInitStr + '0';
              LexNextToken;
            End
            Else If CurToken.Kind = TK_CHAR Then
            Begin
              ConstInitStr := ConstInitStr + IntToStr(Ord(CurToken.Val[1]));
              LexNextToken;
            End
            Else If (CurToken.Kind = TK_IDENT) Or
                    (CurToken.Kind = TK_KEYWORD) Then
            Begin
              CIdx := SymFind(CurToken.Val);
              If (CIdx >= 0) And
                 (SymTab[CIdx].Cat In [SC_CONST, SC_ENUM_VAL,
                                        SC_TYPED_CONST]) Then
                ConstInitStr := ConstInitStr + IntToStr(SymTab[CIdx].ImmVal)
              Else
                ConstInitStr := ConstInitStr + '0';
              LexNextToken;
            End
            Else
            Begin
              ConstInitStr := ConstInitStr + '0';
              LexNextToken;
            End;
            Inc(ConstInitCount);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              LexNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            LexNextToken;
        End
        Else
        Begin
          (* Pas de parentheses : remplir de zeros *)
          ConstInitStr := '';
          For ConstInitCount := 1 To ConstArrCount Do
          Begin
            If ConstInitCount > 1 Then
              ConstInitStr := ConstInitStr + ',';
            ConstInitStr := ConstInitStr + '0';
          End;
        End;

        (* Creer le symbole et la donnee *)
        CIdx := SymAdd(CName, SC_TYPED_CONST, ConstArrTIdx);
        If CIdx >= 0 Then
        Begin
          SymTab[CIdx].MangledName := VXP_ARR_PFX +
            StrUpperCase(CName);
          SymTab[CIdx].IsLocal := False;
          DIdx := DataAdd(SymTab[CIdx].MangledName,
            DK_ARRAY_INIT, 0, ConstInitStr);
          DataTab[DIdx].ElemCount := ConstArrCount;
          DataTab[DIdx].ElemSize  := ConstElemSz;
          SymTab[CIdx].DataIdx   := DIdx;
          If Opts.DebugMode Then
            WriteLn('  CONST_ARRAY: ', CName,
                    ' [', ConstArrLo, '..', ConstArrHi,
                    '] of ', ConstElemTName,
                    ' = (', ConstInitStr, ')');
        End;

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Continue;
      End;

      (* --- Typed const simple : type = valeur --- *)
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
        LexNextToken;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        LexNextToken;
      ParseExpr(ConstEv);
      If ConstEv.Kind = EK_IMM Then
      Begin
        CIdx := SymAdd(CName, SC_TYPED_CONST, ConstEv.TypeIdx);
        If CIdx >= 0 Then
        Begin
          SymTab[CIdx].ImmVal := ConstEv.ImmVal;
          SymTab[CIdx].IsLocal := False;
          DIdx := DataAddWord(SymTab[CIdx].MangledName,
            ConstEv.ImmVal);
          SymTab[CIdx].DataIdx := DIdx;
        End;
      End
      Else
        WarnMsg('constante attendue pour typed const');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* Sinon, token non reconnu dans CONST, sortir *)
    Break;
  End;
End;

{ ============================================================
  TYPES DEFINIS, ENUMERATIONS, SOUS-INTERVALLES [IMPLEMENTE]
  ============================================================ }

(* ---- ParseTypeDecl : analyser un bloc TYPE -------------------- *)
(* Syntaxe VAX Pascal :                                            *)
(*   type Color = (Red, Green, Blue);                              *)
(*   type SmallInt = -32..31;                                      *)
(*   type Matrix = ARRAY[1..10, 1..20] OF Real;                   *)
(*   type PInt = ^Integer;                                         *)
(*   type CharSet = SET OF Char;                                   *)
(*   type FlexRec = PACKED RECORD ... END;                         *)
(*   type VS80 = VARYING [80] OF CHAR;                             *)
(*   type TProc = PROCEDURE(x: Integer);                           *)
(*   type TFunc = FUNCTION(x: Integer) : Integer;                  *)
(*   type T = [WORD] 0..255;                                       *)
(*   type T = [ALIGNED(n)] BaseType;                               *)
(* Le mot-cle TYPE a deja ete consomme par l appelant.             *)
Procedure ParseTypeDecl;
Var
  TName    : TString;
  NewTIdx  : Integer;
  BaseTIdx : Integer;
  BaseStr  : TString;
  Idx      : Integer;
  OrdVal   : Integer;
  EnName   : TString;
  LoVal    : LongInt;
  HiVal    : LongInt;
  Ev       : TExprVal;
  IsPacked : Boolean;
  IsNeg    : Boolean;
  (* Attributs VAX *)
  HasWordAttr    : Boolean;
  (* Records *)
  FldTIdx  : Integer;
  FldNames : Array[0..MAX_PARAM - 1] Of TString;
  FldCount : Integer;
  FldI     : Integer;
  (* Arrays multidim *)
  ArrLo, ArrHi  : LongInt;
  ArrCount       : LongInt;
  ElemTIdx       : Integer;
  ElemSz         : Integer;
  ElemTName      : TString;
  (* VARYING *)
  VaryLen  : Integer;
Begin
  While (CurToken.Kind = TK_IDENT) Or IsOpenBracket Do
  Begin
    (* --- Attributs VAX optionnels avant le nom de type --- *)
    HasWordAttr    := False;
    IsPacked       := False;

    If IsOpenBracket Then
    Begin
      LexNextToken;  (* consommer [ *)
      While (CurToken.Kind <> TK_EOF) And Not IsCloseBracket Do
      Begin
        If StrLowerCase(CurToken.Val) = 'word' Then
          HasWordAttr := True
        Else If StrLowerCase(CurToken.Val) = 'aligned' Then
        Begin
          LexNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            LexNextToken;
            If CurToken.Kind = TK_INTEGER Then
              LexNextToken;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              LexNextToken;
          End;
          Continue;
        End;
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          LexNextToken;
      End;
      If IsCloseBracket Then LexNextToken;
    End;

    (* Detecter PACKED avant le nom *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'packed') Then
    Begin
      IsPacked := True;
      LexNextToken;
    End;

    If CurToken.Kind <> TK_IDENT Then Break;
    TName := CurToken.Val;
    LexNextToken;

    (* Signe = : si absent, pas une declaration de type -> sortir *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      LexNextToken
    Else
    Begin
      PendingAssignName := TName;
      HasPendingAssign  := True;
      Break;
    End;

    (* Detecter PACKED apres le = *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'packed') Then
    Begin
      IsPacked := True;
      LexNextToken;
    End;

    (* Detecter attribut VAX apres = *)
    If IsOpenBracket Then
    Begin
      LexNextToken;
      While (CurToken.Kind <> TK_EOF) And Not IsCloseBracket Do
      Begin
        If StrLowerCase(CurToken.Val) = 'word' Then
          HasWordAttr := True
        Else If StrLowerCase(CurToken.Val) = 'aligned' Then
        Begin
          LexNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            LexNextToken;
            If CurToken.Kind = TK_INTEGER Then
              LexNextToken;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              LexNextToken;
          End;
          Continue;
        End;
        LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          LexNextToken;
      End;
      If IsCloseBracket Then LexNextToken;
    End;

    (* --- Enumeration : (val1, val2, ...) --- *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      LexNextToken;
      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_ENUM;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := IsPacked;
      TypeTab[NewTIdx].Precision   := 0;
      If HasWordAttr Then TypeTab[NewTIdx].Size := 2;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := VXP_ENUM_PFX + StrUpperCase(TName);

      OrdVal := 0;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          EnName := CurToken.Val;
          LexNextToken;

          (* Valeur explicite = n (VAX extension) *)
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            LexNextToken;
            If CurToken.Kind = TK_INTEGER Then
            Begin
              OrdVal := CurToken.IntVal;
              LexNextToken;
            End;
          End;

          Idx := SymAdd(EnName, SC_ENUM_VAL, NewTIdx);
          If Idx >= 0 Then
          Begin
            SymTab[Idx].ImmVal      := OrdVal;
            SymTab[Idx].MangledName := VXP_ENUM_PFX +
                                         StrUpperCase(EnName);
          End;

          If TypeTab[NewTIdx].EnumCount < MAX_ENUM Then
          Begin
            TypeTab[NewTIdx].Enums[TypeTab[NewTIdx].EnumCount].Name := EnName;
            TypeTab[NewTIdx].Enums[TypeTab[NewTIdx].EnumCount].Value := OrdVal;
            Inc(TypeTab[NewTIdx].EnumCount);
          End;

          If Opts.DebugMode Then
            WriteLn('  ENUM: ', TName, '.', EnName, ' = ', OrdVal);

          Inc(OrdVal);
        End
        Else
        Begin
          WarnMsg('identificateur attendu dans enumeration');
          LexNextToken;
        End;

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          LexNextToken;
      End;

      If OrdVal > 0 Then
        TypeTab[NewTIdx].Hi := OrdVal - 1;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        LexNextToken;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;

      Continue;
    End;

    (* --- Pointeur : ^TypeBase --- *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
    Begin
      LexNextToken;
      BaseStr := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        LexNextToken;
      End;
      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_POINTER;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := BaseTIdx;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_PTR: ', TName, ' = ^', BaseStr);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- VARYING [n] OF CHAR --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'varying') Then
    Begin
      LexNextToken;
      VaryLen := 80;
      If IsOpenBracket Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          VaryLen := CurToken.IntVal;
          LexNextToken;
        End;
        If IsCloseBracket Then LexNextToken;
      End;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
        LexNextToken;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_VARYING;
      TypeTab[NewTIdx].Size        := 2 + VaryLen;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_CHAR;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := VaryLen;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_VARYING: ', TName, ' = VARYING[', VaryLen,
                '] OF CHAR');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- ARRAY[lo..hi] OF type (y compris multi-dimensions) --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      LexNextToken;

      If IsOpenBracket Then
        LexNextToken
      Else
        WarnMsg('''['' attendu apres ARRAY');

      (* Borne inferieure *)
      ArrLo := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrLo := CurToken.IntVal;
        LexNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrLo := SymTab[Idx].ImmVal;
        LexNextToken;
      End;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        LexNextToken
      Else
        WarnMsg('''..'' attendu dans declaration ARRAY');

      (* Borne superieure - support * pour conformant *)
      ArrHi := 0;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
      Begin
        ArrHi := 1;
        LexNextToken;
      End
      Else If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrHi := CurToken.IntVal;
        LexNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrHi := SymTab[Idx].ImmVal;
        LexNextToken;
      End;

      (* Multi-dimensions : sauter les dimensions supplementaires *)
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin
        LexNextToken;
        (* Borne inf *)
        If CurToken.Kind = TK_INTEGER Then LexNextToken
        Else If CurToken.Kind = TK_IDENT Then LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
          LexNextToken;
        (* Borne sup *)
        If CurToken.Kind = TK_INTEGER Then LexNextToken
        Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
          LexNextToken
        Else If CurToken.Kind = TK_IDENT Then LexNextToken;
        WarnMsg('tableaux multi-dimensions : seule la 1ere dim est geree');
      End;

      If IsCloseBracket Then
        LexNextToken
      Else
        WarnMsg(''']'' attendu');

      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken
      Else
        WarnMsg('''OF'' attendu apres ARRAY[...]');

      ElemTName := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        ElemTName := CurToken.Val;
        LexNextToken;
      End;

      ElemTIdx := TypeResolve(ElemTName);
      If ElemTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type element inconnu: ' + ElemTName);
        ElemTIdx := TY_IDX_INTEGER;
      End;
      ElemSz := TypeSizeof(ElemTIdx);

      ArrCount := ArrHi - ArrLo + 1;
      If ArrCount < 1 Then ArrCount := 1;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_ARRAY;
      TypeTab[NewTIdx].Size        := ArrCount * ElemSz;
      TypeTab[NewTIdx].BaseTypeIdx := ElemTIdx;
      TypeTab[NewTIdx].Lo          := ArrLo;
      TypeTab[NewTIdx].Hi          := ArrHi;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := IsPacked;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_ARRAY: ', TName,
                ' = ARRAY[', ArrLo, '..', ArrHi,
                '] OF ', ElemTName);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- SET OF type --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'set') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;

      BaseStr := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        LexNextToken;
      End;

      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_SET;
      TypeTab[NewTIdx].Size        := 32;  (* 256 bits = 32 octets *)
      TypeTab[NewTIdx].BaseTypeIdx := BaseTIdx;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 255;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_SET: ', TName, ' = SET OF ', BaseStr);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- RECORD ... END --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'record') Then
    Begin
      LexNextToken;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_RECORD;
      TypeTab[NewTIdx].Size        := 0;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := IsPacked;
      TypeTab[NewTIdx].Precision   := 0;

      (* Parser les champs *)
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 (StrLowerCase(CurToken.Val) = 'end')) Do
      Begin
        (* --- Attributs de champs VAX optionnels : [POS(n)], [ALIGNED(n)], [READONLY], [WRITEONLY] --- *)
        If IsOpenBracket Then
        Begin
          LexNextToken;  (* consommer [ *)
          While (CurToken.Kind <> TK_EOF) And Not IsCloseBracket Do
          Begin
            If Opts.DebugMode Then
              WriteLn('  FIELD_ATTR: ', CurToken.Val);
            (* POS(n) *)
            If StrLowerCase(CurToken.Val) = 'pos' Then
            Begin
              LexNextToken;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
              Begin
                LexNextToken;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  LexNextToken;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  LexNextToken;
              End;
            End
            (* ALIGNED(n) *)
            Else If StrLowerCase(CurToken.Val) = 'aligned' Then
            Begin
              LexNextToken;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
              Begin
                LexNextToken;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  LexNextToken;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  LexNextToken;
              End;
            End
            (* READONLY, WRITEONLY *)
            Else If (StrLowerCase(CurToken.Val) = 'readonly') Or
                    (StrLowerCase(CurToken.Val) = 'writeonly') Then
              LexNextToken
            Else
              LexNextToken;  (* attribut inconnu *)
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              LexNextToken;
          End;
          If IsCloseBracket Then
            LexNextToken;  (* consommer ] *)
        End;

        (* --- Variant records : CASE tag : Type OF val:(fields); ... END --- *)
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'case') Then
        Begin
          LexNextToken;  (* consommer CASE *)
          (* tag : Type OF *)
          (* Lire le tag identifier (optionnel en standard Pascal) *)
          If (CurToken.Kind = TK_IDENT) Or
             (CurToken.Kind = TK_KEYWORD) Then
            LexNextToken;
          (* Possible colon + type *)
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
          Begin
            LexNextToken;
            If (CurToken.Kind = TK_IDENT) Or
               (CurToken.Kind = TK_KEYWORD) Then
              LexNextToken;
          End;
          (* OF *)
          If (CurToken.Kind = TK_KEYWORD) And
             (StrLowerCase(CurToken.Val) = 'of') Then
            LexNextToken;

          (* Parser les branches variant : val : (field1:type1; ...) *)
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_KEYWORD) And
                     ((StrLowerCase(CurToken.Val) = 'end') Or
                      (StrLowerCase(CurToken.Val) = 'otherwise') Or
                      (StrLowerCase(CurToken.Val) = 'others'))) Do
          Begin
            (* Lire la/les valeurs de selection : val1, val2, ... : (fields) *)
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) And
                  Not ((CurToken.Kind = TK_KEYWORD) And
                       ((StrLowerCase(CurToken.Val) = 'end') Or
                        (StrLowerCase(CurToken.Val) = 'otherwise') Or
                        (StrLowerCase(CurToken.Val) = 'others'))) Do
              LexNextToken;

            (* Branche par defaut OTHERS/OTHERWISE *)
            If (CurToken.Kind = TK_KEYWORD) And
               ((StrLowerCase(CurToken.Val) = 'others') Or
                (StrLowerCase(CurToken.Val) = 'otherwise')) Then
            Begin
              LexNextToken;
              (* Consommer : si present *)
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
                LexNextToken;
            End;

            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              LexNextToken;  (* consommer ( *)
              (* Parser les champs variant comme des champs normaux *)
              While (CurToken.Kind <> TK_EOF) And
                    Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              Begin
                FldCount := 0;
                If (CurToken.Kind = TK_IDENT) Or
                   (CurToken.Kind = TK_KEYWORD) Then
                Begin
                  FldNames[0] := CurToken.Val;
                  FldCount := 1;
                  LexNextToken;
                  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
                  Begin
                    LexNextToken;
                    If (CurToken.Kind = TK_IDENT) Or
                       (CurToken.Kind = TK_KEYWORD) Then
                    Begin
                      If FldCount < MAX_PARAM Then
                      Begin
                        FldNames[FldCount] := CurToken.Val;
                        Inc(FldCount);
                      End;
                      LexNextToken;
                    End;
                  End;
                  (* : type *)
                  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
                    LexNextToken;
                  FldTIdx := TY_IDX_INTEGER;
                  If (CurToken.Kind = TK_KEYWORD) Or
                     (CurToken.Kind = TK_IDENT) Then
                  Begin
                    FldTIdx := TypeResolve(CurToken.Val);
                    If FldTIdx = TY_UNKNOWN Then
                      FldTIdx := TY_IDX_INTEGER;
                    LexNextToken;
                  End;
                  (* Enregistrer les champs variant avec offset courant *)
                  For FldI := 0 To FldCount - 1 Do
                  Begin
                    If TypeTab[NewTIdx].FieldCount < MAX_FIELD Then
                    Begin
                      TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Name :=
                        StrLowerCase(FldNames[FldI]);
                      TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].TypeIdx :=
                        FldTIdx;
                      TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Offset :=
                        TypeTab[NewTIdx].Size;
                      Inc(TypeTab[NewTIdx].FieldCount);
                      (* Les champs variant partagent la meme zone memoire
                         donc on ne met pas a jour Size ici - on le fait
                         apres pour le plus grand variant *)
                      If Opts.DebugMode Then
                        WriteLn('  VARIANT_FIELD: ', FldNames[FldI],
                                ' : tidx=', FldTIdx,
                                ' ofs=', TypeTab[NewTIdx].Size);
                    End;
                  End;
                  (* semicolonne optionnelle *)
                  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
                    LexNextToken;
                End
                Else
                  LexNextToken;  (* token inattendu dans variant *)
              End;  (* while not ) *)
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                LexNextToken;
              (* semicolonne apres la branche *)
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
                LexNextToken;
            End
            Else
              Break;  (* pas de ( -> fin des branches *)
          End;  (* while branches variant *)

          (* Consommer OTHERS/OTHERWISE final si present *)
          If (CurToken.Kind = TK_KEYWORD) And
             ((StrLowerCase(CurToken.Val) = 'others') Or
              (StrLowerCase(CurToken.Val) = 'otherwise')) Then
          Begin
            LexNextToken;
            (* Sauter la branche others restante *)
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
              LexNextToken;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              LexNextToken;
              While (CurToken.Kind <> TK_EOF) And
                    Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                LexNextToken;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                LexNextToken;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
              LexNextToken;
          End;
          Break;  (* variant record termine la liste des champs fixes *)
        End;

        (* Lire un ou plusieurs noms de champs *)
        FldCount := 0;
        If (CurToken.Kind = TK_IDENT) Or
           (CurToken.Kind = TK_KEYWORD) Then
        Begin
          FldNames[0] := CurToken.Val;
          FldCount := 1;
          LexNextToken;

          While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
          Begin
            LexNextToken;
            If (CurToken.Kind = TK_IDENT) Or
               (CurToken.Kind = TK_KEYWORD) Then
            Begin
              If FldCount < MAX_PARAM Then
              Begin
                FldNames[FldCount] := CurToken.Val;
                Inc(FldCount);
              End;
              LexNextToken;
            End;
          End;

          (* Deux-points *)
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
            LexNextToken
          Else
            WarnMsg(''':'' attendu apres nom de champ');

          FldTIdx := TY_IDX_INTEGER;
          If (CurToken.Kind = TK_KEYWORD) Or
             (CurToken.Kind = TK_IDENT) Then
          Begin
            FldTIdx := TypeResolve(CurToken.Val);
            If FldTIdx = TY_UNKNOWN Then
            Begin
              WarnMsg('type de champ inconnu: ' + CurToken.Val);
              FldTIdx := TY_IDX_INTEGER;
            End;
            LexNextToken;
          End;

          For FldI := 0 To FldCount - 1 Do
          Begin
            If TypeTab[NewTIdx].FieldCount < MAX_FIELD Then
            Begin
              TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Name :=
                StrLowerCase(FldNames[FldI]);
              TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].TypeIdx :=
                FldTIdx;
              TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Offset :=
                TypeTab[NewTIdx].Size;
              Inc(TypeTab[NewTIdx].FieldCount);
              TypeTab[NewTIdx].Size :=
                TypeTab[NewTIdx].Size + TypeSizeof(FldTIdx);

              If Opts.DebugMode Then
                WriteLn('  FIELD: ', FldNames[FldI], ' : tidx=', FldTIdx,
                        ' ofs=', TypeTab[NewTIdx].Size - TypeSizeof(FldTIdx));
            End
            Else
              WarnMsg('trop de champs dans le record');
          End;

          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            LexNextToken;
        End
        Else
        Begin
          WarnMsg('identificateur attendu dans record');
          LexNextToken;
        End;
      End;

      (* Consommer END *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'end') Then
        LexNextToken;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_RECORD: ', TName,
                ' size=', TypeTab[NewTIdx].Size,
                ' fields=', TypeTab[NewTIdx].FieldCount,
                ' packed=', IsPacked);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- FILE OF type --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'file') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;

      BaseStr := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        LexNextToken;
      End;
      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_FILE;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := BaseTIdx;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_FILE: ', TName, ' = FILE OF ', BaseStr);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- Types proceduraux : PROCEDURE(...) ou FUNCTION(...):Type --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'procedure') Then
    Begin
      LexNextToken;
      (* Sauter les parametres *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_PROCEDURAL;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_PROC: ', TName, ' = PROCEDURE(...)');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'function') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
      (* Consommer : ReturnType *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_KEYWORD) Or
           (CurToken.Kind = TK_IDENT) Then
          LexNextToken;
      End;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_PROCEDURAL;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;
      TypeTab[NewTIdx].Packed_     := False;
      TypeTab[NewTIdx].Precision   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_FUNC: ', TName, ' = FUNCTION(...): ...');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- STRING[n] type --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'string') Then
    Begin
      LexNextToken;
      VaryLen := 255;
      If IsOpenBracket Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          VaryLen := CurToken.IntVal;
          LexNextToken;
        End
        Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
        Begin
          VaryLen := 255;
          LexNextToken;
        End;
        If IsCloseBracket Then LexNextToken;
      End;

      Idx := SymAdd(TName, SC_TYPE, TY_IDX_STRING);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_STRING: ', TName, ' = STRING[', VaryLen, ']');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- Sous-plage avec literal negatif : -n..m --- *)
    IsNeg := False;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
    Begin
      IsNeg := True;
      LexNextToken;
    End;

    If (CurToken.Kind = TK_INTEGER) Then
    Begin
      LoVal := CurToken.IntVal;
      If IsNeg Then LoVal := -LoVal;
      LexNextToken;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        LexNextToken;
        ParseExpr(Ev);
        HiVal := Ev.ImmVal;

        (* Detecter PREC n (VAX specifique) *)
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'prec') Then
        Begin
          LexNextToken;
          If CurToken.Kind = TK_INTEGER Then
            LexNextToken;
          (* TODO: utiliser Precision *)
        End;

        If TypeCount >= MAX_TYPE Then
        Begin
          WarnMsg('nombre maximal de types atteint');
          Break;
        End;
        NewTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
        If HasWordAttr Then
          TypeTab[NewTIdx].Size := 2
        Else If (LoVal >= 0) And (HiVal <= 255) Then
          TypeTab[NewTIdx].Size := 1
        Else
          TypeTab[NewTIdx].Size := 2;
        TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
        TypeTab[NewTIdx].Lo          := LoVal;
        TypeTab[NewTIdx].Hi          := HiVal;
        TypeTab[NewTIdx].FieldCount  := 0;
        TypeTab[NewTIdx].EnumCount   := 0;
        TypeTab[NewTIdx].Packed_     := False;
        TypeTab[NewTIdx].Precision   := 0;

        Idx := SymAdd(TName, SC_TYPE, NewTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);

        If Opts.DebugMode Then
          WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                  LoVal, '..', HiVal);

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Continue;
      End
      Else
      Begin
        WarnMsg('declaration de type inattendue pour ' + TName);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Continue;
      End;
    End;

    (* --- Alias de type ou sous-intervalle avec ident --- *)
    BaseStr := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      BaseStr := CurToken.Val;
      LexNextToken;

      (* Detecter sous-intervalle : ident..hi *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        Idx := SymFind(BaseStr);
        If (Idx >= 0) And (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          LoVal := SymTab[Idx].ImmVal
        Else
          LoVal := 0;
        LexNextToken;
        ParseExpr(Ev);
        HiVal := Ev.ImmVal;

        (* Detecter PREC n *)
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'prec') Then
        Begin
          LexNextToken;
          If CurToken.Kind = TK_INTEGER Then
            LexNextToken;
        End;

        If TypeCount >= MAX_TYPE Then
        Begin
          WarnMsg('nombre maximal de types atteint');
          Break;
        End;
        NewTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
        TypeTab[NewTIdx].Size        := 2;
        TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
        TypeTab[NewTIdx].Lo          := LoVal;
        TypeTab[NewTIdx].Hi          := HiVal;
        TypeTab[NewTIdx].FieldCount  := 0;
        TypeTab[NewTIdx].EnumCount   := 0;
        TypeTab[NewTIdx].Packed_     := False;
        TypeTab[NewTIdx].Precision   := 0;

        Idx := SymAdd(TName, SC_TYPE, NewTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);

        If Opts.DebugMode Then
          WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                  LoVal, '..', HiVal);

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Continue;
      End;

      (* Simple alias de type *)
      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type inconnu dans alias: ' + BaseStr);
        BaseTIdx := TY_IDX_INTEGER;
      End;

      Idx := SymAdd(TName, SC_TYPE, BaseTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_ALIAS: ', TName, ' = ', BaseStr,
                ' (idx=', BaseTIdx, ')');
    End
    Else
    Begin
      WarnMsg('definition de type attendue pour ' + TName);
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

{ ============================================================
  WRITE / WRITELN / READ / READLN [IMPLEMENTE]
  ============================================================ }

(* ---- ParseWriteStmt : analyser Write ou WriteLn --------------- *)
(* Le mot-cle write/writeln a deja ete consomme par l appelant.    *)
(* CurToken est sur ( si arguments, ou ; si WriteLn sans args.     *)
(* Supporte :                                                      *)
(*   WriteLn                    -> juste CR+LF                     *)
(*   WriteLn('texte')           -> afficher chaine                 *)
(*   WriteLn(expr)              -> afficher entier/char/bool       *)
(*   Write(expr:width)          -> format avec largeur (stub)      *)
(*   Write(expr:w:d)            -> format reel (stub)              *)
(*   Write(output, expr)        -> fichier predefini ignore        *)
(*   WriteV(str, expr, ...)     -> stub, traite comme Write        *)
Procedure ParseWriteStmt(IsWriteLn : Boolean);
Var
  Ev      : TExprVal;
  WidthEv : TExprVal;
  L       : TString;
  SaveTI  : Integer;
Begin
  If IsWriteLn Then
    EmitComment('writeln')
  Else
    EmitComment('write');

  (* WriteLn sans arguments -> juste CR+LF *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'CRLF');
      EmitCall(VXP_RT_PFX + 'PRINTSTR');
    End;
    LexNextToken;
    Exit;
  End;

  (* Consommer ( *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    LexNextToken
  Else
  Begin
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'CRLF');
      EmitCall(VXP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  (* Sauter fichier predefini en premier argument : output, tty, ttyoutput *)
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
  Begin
    L := StrLowerCase(CurToken.Val);
    If (L = 'output') Or (L = 'tty') Or (L = 'ttyoutput') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        LexNextToken
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      Begin
        LexNextToken;
        If IsWriteLn Then
        Begin
          EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'CRLF');
          EmitCall(VXP_RT_PFX + 'PRINTSTR');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Exit;
      End;
    End;
  End;

  (* Boucle sur les arguments *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    ParseExpr(Ev);
    SaveTI := Ev.TypeIdx;

    (* Detecter formatage expr:width *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      (* Materialiser l expression principale avant de parser width *)
      ExprFlushToAX(Ev);
      EmitInstrA('PUSH', 'AX');  (* sauvegarder la valeur *)
      LexNextToken;
      ParseExpr(WidthEv);  (* ignorer width pour l instant *)
      (* Detecter :w:d *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        LexNextToken;
        ParseExpr(WidthEv);  (* ignorer d *)
      End;
      EmitInstrA('POP', 'AX');  (* restaurer la valeur *)
      EmitPrintAX(SaveTI);
    End
    Else
    Begin
      ExprFlushToAX(Ev);
      EmitPrintAX(Ev.TypeIdx);
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken;
  End;

  (* Consommer ) *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    LexNextToken;

  (* WriteLn : ajouter CR+LF *)
  If IsWriteLn Then
  Begin
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + VXP_RT_PFX + 'CRLF');
    EmitCall(VXP_RT_PFX + 'PRINTSTR');
  End;

  (* Point-virgule *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;
End;

(* ---- ParseReadStmt : analyser Read ou ReadLn ------------------ *)
(* Le mot-cle read/readln a deja ete consomme par l appelant.      *)
(* CurToken est sur ( si arguments, ou ; si ReadLn sans args.      *)
(* Supporte :                                                      *)
(*   ReadLn                     -> attendre CR                     *)
(*   ReadLn(x)                  -> lire entier ou char             *)
(*   Read(tty, x)               -> fichier predefini ignore        *)
(*   ReadV(str, var)             -> stub                           *)
Procedure ParseReadStmt(IsReadLn : Boolean);
Var
  ReadVarIdx : Integer;
  L          : TString;
Begin
  If IsReadLn Then
    EmitComment('readln')
  Else
    EmitComment('read');

  (* ReadLn sans arguments -> attendre CR *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    If IsReadLn Then
      EmitCall(VXP_RT_PFX + 'READCHAR');
    LexNextToken;
    Exit;
  End;

  (* Consommer ( *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    LexNextToken
  Else
  Begin
    If IsReadLn Then
      EmitCall(VXP_RT_PFX + 'READCHAR');
    Exit;
  End;

  (* Sauter fichier predefini : input, tty *)
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
  Begin
    L := StrLowerCase(CurToken.Val);
    If (L = 'input') Or (L = 'tty') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        LexNextToken
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      Begin
        LexNextToken;
        If IsReadLn Then
          EmitCall(VXP_RT_PFX + 'READCHAR');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        Exit;
      End;
    End;
  End;

  (* Boucle sur les variables a lire *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      ReadVarIdx := SymFind(CurToken.Val);
      LexNextToken;

      If ReadVarIdx >= 0 Then
      Begin
        If (SymTab[ReadVarIdx].TypeIdx = TY_IDX_CHAR) Or
           (SymTab[ReadVarIdx].TypeIdx = TY_IDX_STRING) Then
        Begin
          (* Lire un caractere *)
          EmitCall(VXP_RT_PFX + 'READCHAR');
          If SymTab[ReadVarIdx].TypeIdx = TY_IDX_CHAR Then
          Begin
            If SymTab[ReadVarIdx].IsLocal Then
              EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AL')
            Else
              EmitInstrAB('MOV',
                'BYTE PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AL');
          End
          Else
          Begin
            (* String : stocker dans buffer puis copier *)
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV',
              'BYTE PTR [' + VXP_RT_PFX + 'STRBUF]', 'AL');
            EmitInstrAB('MOV',
              'BYTE PTR [' + VXP_RT_PFX + 'STRBUF + 1]', '0');
            EmitInstrAB('LEA', 'SI', VXP_RT_PFX + 'STRBUF');
            If SymTab[ReadVarIdx].IsLocal Then
              EmitInstrAB('LEA', 'DI',
                BPOfs(SymTab[ReadVarIdx].Offset))
            Else
              EmitInstrAB('MOV', 'DI',
                'OFFSET ' + SymTab[ReadVarIdx].MangledName);
            EmitInstrAB('MOV', 'CX', '2');
            EmitInstr('REP    MOVSB');
          End;
        End
        Else
        Begin
          (* Lire un entier *)
          EmitCall(VXP_RT_PFX + 'READNUM');
          If SymTab[ReadVarIdx].IsLocal Then
            EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AX')
          Else
            EmitInstrAB('MOV',
              'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AX');
        End;
      End
      Else
        WarnMsg('variable attendue pour Read/ReadLn');
    End
    Else
    Begin
      WarnMsg('identificateur attendu dans Read/ReadLn');
      LexNextToken;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken;
  End;

  (* Consommer ) *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    LexNextToken;

  (* ReadLn : consommer le reste de la ligne *)
  If IsReadLn Then
  Begin
    EmitComment('readln: flush reste de ligne');
    EmitCall(VXP_RT_PFX + 'READCHAR');
  End;

  (* Point-virgule *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;
End;

{ ============================================================
  IF / THEN / ELSE + CASE / OF + LABEL / GOTO [IMPLEMENTE]
  ============================================================ }

(* ---- ParseBlock : analyser un bloc begin ... end ------------- *)
(* Consomme begin, execute les instructions separees par ;,        *)
(* jusqu a end. Consomme end.                                      *)
Procedure ParseBlock;
Begin
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'begin') Then
    LexNextToken
  Else
  Begin
    WarnMsg('''begin'' attendu');
    Exit;
  End;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             (StrLowerCase(CurToken.Val) = 'end')) Do
  Begin
    ParseStatement;
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      LexNextToken;
  End;

  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'end') Then
    LexNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le bloc begin');
End;

(* ---- ParseIfStmt : analyser if expr then stmt [else stmt] ---- *)
(* CurToken est sur 'if'. Gere les dangling else par rattachement  *)
(* au if le plus proche (standard Pascal).                         *)
Procedure ParseIfStmt;
Var
  Ev          : TExprVal;
  LblElse     : TString;
  LblEndIf    : TString;
  HasElsePart : Boolean;
Begin
  EmitComment('if');

  LexNextToken;  (* consommer if *)

  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  LblElse  := LabelGen;
  LblEndIf := LabelGen;

  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblElse);

  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'then') Then
    LexNextToken
  Else
    WarnMsg('''then'' attendu apres condition if');

  ParseStatement;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;

  HasElsePart := (CurToken.Kind = TK_KEYWORD) And
                 (StrLowerCase(CurToken.Val) = 'else');

  If HasElsePart Then
  Begin
    EmitInstrA('JMP', LblEndIf);
    EmitLabel(LblElse);
    LexNextToken;  (* consommer else *)
    ParseStatement;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    EmitLabel(LblEndIf);
  End
  Else
    EmitLabel(LblElse);
End;

(* ---- ParseCaseStmt : analyser case expr of ... end ----------- *)
(* CurToken est sur 'case'.                                        *)
(* Supporte :                                                      *)
(*   CASE expr OF                                                  *)
(*     val1 : stmt;                                                *)
(*     val2, val3 : stmt;                                          *)
(*     val4..val6 : stmt;                                          *)
(*     OTHERS : stmt;          (VAX Pascal)                        *)
(*     OTHERWISE : stmt;       (synonyme)                          *)
(*     ELSE stmt;              (TP/standard)                       *)
(*   END;                                                          *)
Procedure ParseCaseStmt;
Var
  Ev       : TExprVal;
  CaseEv   : TExprVal;
  LblEnd   : TString;
  LblNext  : TString;
  LblHit   : TString;
  RangeHi  : LongInt;
  L        : TString;
Begin
  EmitComment('case');
  LexNextToken;  (* consommer case *)

  ParseExpr(Ev);
  ExprFlushToAX(Ev);
  EmitInstrA('PUSH', 'AX');

  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'of') Then
    LexNextToken
  Else
    WarnMsg('''of'' attendu apres expression case');

  LblEnd := LabelGen;

  While (CurToken.Kind <> TK_EOF) Do
  Begin
    L := StrLowerCase(CurToken.Val);
    If (CurToken.Kind = TK_KEYWORD) And
       ((L = 'end') Or (L = 'else') Or (L = 'others') Or
        (L = 'otherwise')) Then
      Break;

    LblNext := LabelGen;
    LblHit  := LabelGen;

    (* Lire les valeurs de la branche separees par virgule *)
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':')) Do
    Begin
      ParseExpr(CaseEv);

      EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');

      (* Detecter plage val1..val2 *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        LexNextToken;
        RangeHi := 0;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          RangeHi := CurToken.IntVal;
          LexNextToken;
        End
        Else
        Begin
          ParseExpr(CaseEv);
          RangeHi := CaseEv.ImmVal;
        End;
        EmitInstrAB('CMP', 'AX', IntToStr(CaseEv.ImmVal));
        EmitInstrA('JB', LblNext);
        EmitInstrAB('CMP', 'AX', IntToStr(RangeHi));
        EmitInstrA('JBE', LblHit);
        EmitInstrA('JMP', LblNext);
      End
      Else
      Begin
        If CaseEv.Kind = EK_IMM Then
          EmitInstrAB('CMP', 'AX', IntToStr(CaseEv.ImmVal))
        Else
        Begin
          ExprFlushToAX(CaseEv);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');
          EmitInstrAB('CMP', 'AX', 'BX');
        End;
        EmitInstrA('JE', LblHit);
      End;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        LexNextToken
      Else
        Break;
    End;

    EmitInstrA('JMP', LblNext);
    EmitLabel(LblHit);

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      LexNextToken
    Else
      WarnMsg(''':'' attendu apres valeur(s) case');

    ParseStatement;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;

    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblNext);
  End;

  (* Branche OTHERS / OTHERWISE / ELSE *)
  L := StrLowerCase(CurToken.Val);
  If (CurToken.Kind = TK_KEYWORD) And
     ((L = 'else') Or (L = 'others') Or (L = 'otherwise')) Then
  Begin
    LexNextToken;
    (* OTHERS/OTHERWISE sont suivis de : *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      LexNextToken;
    EmitComment('case default');
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And
               (StrLowerCase(CurToken.Val) = 'end')) Do
    Begin
      ParseStatement;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
    End;
  End;

  EmitLabel(LblEnd);
  EmitInstrA('POP', 'AX');

  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'end') Then
    LexNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le case');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;
End;

{ ============================================================
  BOUCLES : FOR / WHILE / REPEAT / LOOP [IMPLEMENTE]
  ============================================================ }

(* ---- LoopPush : empiler un contexte de boucle ---------------- *)
Procedure LoopPush(Const LblBreak, LblCont : TString);
Begin
  Inc(LoopTop);
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WarnMsg('trop de boucles imbriquees');
    Dec(LoopTop);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := LblBreak;
  LoopContLbl[LoopTop]  := LblCont;
End;

(* ---- LoopPop : depiler un contexte de boucle ----------------- *)
Procedure LoopPop;
Begin
  If LoopTop >= 0 Then
    Dec(LoopTop);
End;

(* ---- ParseForStmt : for v := expr1 to|downto expr2 [by step] do stmt -- *)
(* CurToken est sur 'for'.                                                  *)
Procedure ParseForStmt;
Var
  VarName   : TString;
  Ev        : TExprVal;
  LimLabel  : TString;
  StepLabel : TString;
  LblTest   : TString;
  LblEnd    : TString;
  LblCont   : TString;
  IsDownTo  : Boolean;
  HasBy     : Boolean;
  SymIdx    : Integer;
  VarRef    : TString;
Begin
  EmitComment('for');

  (* Consommer for *)
  LexNextToken;

  (* Lire la variable de boucle *)
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('variable de boucle attendue apres ''for''');
    Exit;
  End;
  VarName := CurToken.Val;
  LexNextToken;

  (* Consommer := *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    LexNextToken
  Else
    WarnMsg(''':='' attendu apres variable de boucle');

  (* Evaluer l expression de depart *)
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  (* Chercher le symbole de la variable *)
  SymIdx := SymFind(VarName);
  If SymIdx < 0 Then
  Begin
    WarnMsg('variable de boucle ''' + VarName + ''' non declaree');
    Exit;
  End;
  If SymTab[SymIdx].IsLocal Then
    VarRef := 'WORD PTR ' + BPOfs(SymTab[SymIdx].Offset)
  Else
    VarRef := 'WORD PTR [' + SymTab[SymIdx].MangledName + ']';

  (* Stocker la valeur de depart *)
  EmitInstrAB('MOV', VarRef, 'AX');

  (* Consommer to ou downto *)
  IsDownTo := False;
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'to') Then
    LexNextToken
  Else If (CurToken.Kind = TK_KEYWORD) And
          (StrLowerCase(CurToken.Val) = 'downto') Then
  Begin
    IsDownTo := True;
    LexNextToken;
  End
  Else
    WarnMsg('''to'' ou ''downto'' attendu');

  (* Evaluer l expression limite et la stocker dans une variable data *)
  ParseExpr(Ev);
  ExprFlushToAX(Ev);
  LimLabel := LabelGen;
  EmitInstrAB('MOV', 'WORD PTR [' + LimLabel + ']', 'AX');

  (* BY step (extension VAX) *)
  HasBy := False;
  StepLabel := '';
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'by') Then
  Begin
    LexNextToken;
    ParseExpr(Ev);
    ExprFlushToAX(Ev);
    StepLabel := LabelGen;
    EmitInstrAB('MOV', 'WORD PTR [' + StepLabel + ']', 'AX');
    HasBy := True;
  End;

  (* Generer les labels de boucle *)
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblCont := LabelGen;

  (* Consommer do *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'do') Then
    LexNextToken
  Else
    WarnMsg('''do'' attendu apres expression limite');

  (* Label de test *)
  EmitLabel(LblTest);

  (* Test : CMP var, limite *)
  EmitInstrAB('MOV', 'AX', VarRef);
  EmitInstrAB('CMP', 'AX', 'WORD PTR [' + LimLabel + ']');
  If IsDownTo Then
    EmitInstrA('JL', LblEnd)
  Else
    EmitInstrA('JG', LblEnd);

  (* Empiler le contexte de boucle *)
  LoopPush(LblEnd, LblCont);

  (* Compiler le corps de la boucle *)
  ParseStatement;

  (* Consommer le ; optionnel *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;

  (* Label continue (increment) *)
  EmitLabel(LblCont);

  (* Increment ou decrement *)
  If HasBy Then
  Begin
    EmitInstrAB('MOV', 'AX', VarRef);
    If IsDownTo Then
      EmitInstrAB('SUB', 'AX', 'WORD PTR [' + StepLabel + ']')
    Else
      EmitInstrAB('ADD', 'AX', 'WORD PTR [' + StepLabel + ']');
    EmitInstrAB('MOV', VarRef, 'AX');
  End
  Else
  Begin
    If IsDownTo Then
      EmitInstrA('DEC', VarRef)
    Else
      EmitInstrA('INC', VarRef);
  End;

  (* Retour au test *)
  EmitInstrA('JMP', LblTest);

  (* Label fin *)
  EmitLabel(LblEnd);

  (* Depiler le contexte de boucle *)
  LoopPop;

  (* Ajouter la variable limite dans le segment de donnees *)
  DataAddWord(LimLabel, 0);
  If HasBy Then
    DataAddWord(StepLabel, 0);
End;

(* ---- ParseWhileStmt : while expr do stmt -------------------- *)
(* CurToken est sur 'while'.                                      *)
Procedure ParseWhileStmt;
Var
  Ev      : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');

  (* Consommer while *)
  LexNextToken;

  (* Generer les labels *)
  LblTest := LabelGen;
  LblEnd  := LabelGen;

  (* Label de test *)
  EmitLabel(LblTest);

  (* Evaluer la condition *)
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  (* TEST AX,AX / JZ fin *)
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);

  (* Consommer do *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'do') Then
    LexNextToken
  Else
    WarnMsg('''do'' attendu apres condition while');

  (* Empiler le contexte de boucle *)
  LoopPush(LblEnd, LblTest);

  (* Compiler le corps *)
  ParseStatement;

  (* Consommer le ; optionnel *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;

  (* Retour au test *)
  EmitInstrA('JMP', LblTest);

  (* Label fin *)
  EmitLabel(LblEnd);

  (* Depiler le contexte de boucle *)
  LoopPop;
End;

(* ---- ParseRepeatStmt : repeat stmts until expr -------------- *)
(* CurToken est sur 'repeat'.                                     *)
Procedure ParseRepeatStmt;
Var
  Ev     : TExprVal;
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('repeat');

  (* Consommer repeat *)
  LexNextToken;

  (* Generer les labels *)
  LblBeg := LabelGen;
  LblEnd := LabelGen;

  (* Label debut *)
  EmitLabel(LblBeg);

  (* Empiler le contexte de boucle *)
  LoopPush(LblEnd, LblBeg);

  (* Compiler les instructions jusqu a until *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             (StrLowerCase(CurToken.Val) = 'until')) Do
  Begin
    ParseStatement;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;

  (* Consommer until *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'until') Then
    LexNextToken
  Else
    WarnMsg('''until'' attendu pour fermer le repeat');

  (* Evaluer la condition *)
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  (* TEST AX,AX / JZ debut (si faux, on boucle) *)
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblBeg);

  (* Label fin *)
  EmitLabel(LblEnd);

  (* Depiler le contexte de boucle *)
  LoopPop;
End;

(* ---- ParseLoopStmt : loop stmts end (VAX extension) --------- *)
(* CurToken est sur 'loop'.                                        *)
(* Le corps peut contenir EXIT IF expr; a n importe quel endroit.  *)
Procedure ParseLoopStmt;
Var
  Ev     : TExprVal;
  LblBeg : TString;
  LblEnd : TString;
  L      : TString;
Begin
  EmitComment('loop');

  (* Consommer loop *)
  LexNextToken;

  (* Generer les labels *)
  LblBeg := LabelGen;
  LblEnd := LabelGen;

  (* Label debut *)
  EmitLabel(LblBeg);

  (* Empiler le contexte de boucle *)
  LoopPush(LblEnd, LblBeg);

  (* Compiler les instructions jusqu a END *)
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    L := StrLowerCase(CurToken.Val);
    (* Fin du LOOP *)
    If (CurToken.Kind = TK_KEYWORD) And (L = 'end') Then
      Break;

    (* EXIT IF expr; *)
    If (CurToken.Kind = TK_KEYWORD) And (L = 'exit') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'if') Then
      Begin
        LexNextToken;
        EmitComment('exit if');
        ParseExpr(Ev);
        ExprFlushToAX(Ev);
        EmitInstrAB('TEST', 'AX', 'AX');
        EmitInstrA('JNZ', LblEnd);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
      End
      Else
      Begin
        (* EXIT simple (sans IF) = break *)
        EmitComment('exit');
        EmitInstrA('JMP', LblEnd);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
      End;
      Continue;
    End;

    ParseStatement;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;

  (* Consommer end *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'end') Then
    LexNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le loop');

  (* Retour au debut *)
  EmitInstrA('JMP', LblBeg);

  (* Label fin *)
  EmitLabel(LblEnd);

  (* Depiler le contexte de boucle *)
  LoopPop;
End;

{ ============================================================
  FONCTIONS ET PROCEDURES [IMPLEMENTE]
  ============================================================ }

(* ---- ParseParamList : analyser la liste de parametres -------- *)
(* Syntaxe : (a: Integer; var b: Integer; c, d: Word)              *)
(* Enregistre chaque param dans SymTab comme SC_PARAM ou SC_VARPARAM *)
(* Retourne le nombre total d octets de parametres.                *)
Function ParseParamList : Integer;
Var
  Names      : Array[0..MAX_PARAM - 1] Of TString;
  IsVar      : Array[0..MAX_PARAM - 1] Of Boolean;
  NCount     : Integer;
  TName      : TString;
  TIdx       : Integer;
  ParamBytes : Integer;
  I, Idx     : Integer;
  Cat        : TSymCat;
Begin
  ParamBytes := 0;

  (* Consommer ( *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    LexNextToken
  Else
  Begin
    ParseParamList := 0;
    Exit;
  End;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    NCount := 0;

    (* Detecter var *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'var') Then
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := True;
      LexNextToken;
    End
    Else
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := False;
    End;

    (* Collecter les noms *)
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      If NCount < MAX_PARAM Then
      Begin
        Names[NCount] := CurToken.Val;
        Inc(NCount);
      End;
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        LexNextToken
      Else
        Break;
    End;

    (* Deux-points + type *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      LexNextToken
    Else
      WarnMsg(''':'' attendu dans liste de parametres');

    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      LexNextToken;
    End;

    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type de parametre inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;
    End;

    (* Enregistrer les parametres *)
    For I := 0 To NCount - 1 Do
    Begin
      If IsVar[I] Then
        Cat := SC_VARPARAM
      Else
        Cat := SC_PARAM;
      Idx := SymAdd(Names[I], Cat, TIdx);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].Offset  := ParamBytes;
        SymTab[Idx].IsLocal := True;
      End;
      Inc(ParamBytes, 2);
    End;

    (* Point-virgule entre groupes de params *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;

  (* Consommer ) *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    LexNextToken;

  (* Corriger les offsets : convention Pascal, premier param en haut *)
  (* Apres PUSH BP / MOV BP,SP : [BP+0]=old BP, [BP+2]=ret addr *)
  (* Param rang R (0-based en bytes) -> offset = +4 + (ParamBytes - 2 - R) *)
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].ScopeLevel = CurScopeLevel) And
       (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
    Begin
      SymTab[I].Offset := 4 + (ParamBytes - 2 - SymTab[I].Offset);
      If Opts.DebugMode Then
        WriteLn('  PARAM: ', SymTab[I].Name, ' [BP+',
                SymTab[I].Offset, ']');
    End;
  End;

  ParseParamList := ParamBytes;
End;

(* ---- ParseFuncOrProc : analyse commune func/proc ------------- *)
(* IsFunc = True pour function, False pour procedure.              *)
Procedure ParseFuncOrProc(IsFunc : Boolean);
Var
  FuncName     : TString;
  RetTypeName  : TString;
  RetTypeIdx   : Integer;
  FIdx         : Integer;
  ParamBytes   : Integer;
  FrameSize    : Integer;
  RetLabel     : TString;
  SaveFrame    : Integer;
  SaveFuncName : TString;
  SaveRetOfs   : Integer;
  SaveRetLabel : TString;
  SaveParamB   : Integer;
  Cat          : TSymCat;
  RetVarIdx    : Integer;
  VarMask      : LongInt;
  PCnt         : Integer;
  I            : Integer;
Begin
  (* Consommer function/procedure *)
  LexNextToken;

  (* Nom de la fonction / procedure *)
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('nom de fonction/procedure attendu');
    Exit;
  End;
  FuncName := CurToken.Val;
  LexNextToken;

  (* Categorie *)
  If IsFunc Then
    Cat := SC_FUNC
  Else
    Cat := SC_PROC;

  (* Type de retour par defaut *)
  RetTypeIdx := TY_IDX_INTEGER;

  (* Verifier si c est une redeclaration (forward resolue) *)
  FIdx := SymFindInScope(FuncName, CurScopeLevel);
  If (FIdx >= 0) And SymTab[FIdx].IsForward Then
    SymTab[FIdx].IsForward := False
  Else
    FIdx := SymAdd(FuncName, Cat, RetTypeIdx);

  (* Entrer dans le scope de la fonction *)
  SymEnterScope;
  Inc(CurNestLevel);
  If CurNestLevel > NEST_MAX Then
    WarnMsg('imbrication de fonctions trop profonde (>' +
            IntToStr(NEST_MAX) + ')');

  (* OPTIONS (VAX) : ignorer *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'options') Then
  Begin
    LexNextToken;
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':')) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Do
      LexNextToken;
  End;

  (* Parser les parametres *)
  ParamBytes := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParamBytes := ParseParamList;

  (* Construire le masque des parametres var *)
  If FIdx >= 0 Then
  Begin
    VarMask := 0;
    PCnt    := 0;
    For I := 0 To SymCount - 1 Do
    Begin
      If (SymTab[I].ScopeLevel = CurScopeLevel) And
         (SymTab[I].ScopeId = CurScopeId) And
         (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
      Begin
        If SymTab[I].Cat = SC_VARPARAM Then
          VarMask := VarMask Or (LongInt(1) Shl PCnt);
        Inc(PCnt);
      End;
    End;
    SymTab[FIdx].ParamCnt     := PCnt;
    SymTab[FIdx].VarParamMask := VarMask;
  End;

  (* Type de retour pour les fonctions *)
  If IsFunc Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      LexNextToken;
      RetTypeName := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        RetTypeName := CurToken.Val;
        LexNextToken;
      End;
      RetTypeIdx := TypeResolve(RetTypeName);
      If RetTypeIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type de retour inconnu: ' + RetTypeName);
        RetTypeIdx := TY_IDX_INTEGER;
      End;
    End;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := RetTypeIdx;
  End
  Else
  Begin
    RetTypeIdx := TY_UNKNOWN;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := TY_UNKNOWN;
  End;

  (* Point-virgule apres la signature *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;

  (* Verifier si FORWARD *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'forward') Then
  Begin
    If FIdx >= 0 Then
      SymTab[FIdx].IsForward := True;
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    SymLeaveScope;
    Dec(CurNestLevel);
    Exit;
  End;

  (* Verifier si EXTERNAL (apres signature) *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'external') Then
  Begin
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    SymLeaveScope;
    Dec(CurNestLevel);
    Exit;
  End;

  (* Sauvegarder le contexte du cadre parent *)
  SaveFrame    := CurFrameOffset;
  SaveFuncName := CurFuncName;
  SaveRetOfs   := CurFuncRetOfs;
  SaveRetLabel := CurRetLabel;
  SaveParamB   := CurParamBytes;

  CurFrameOffset := 0;
  CurParamBytes  := ParamBytes;
  RetLabel       := LabelGen;
  CurRetLabel    := RetLabel;

  (* Pour les fonctions : variable locale pour la valeur de retour [BP-2] *)
  If IsFunc Then
  Begin
    Dec(CurFrameOffset, 2);
    CurFuncName   := StrLowerCase(FuncName);
    CurFuncRetOfs := CurFrameOffset;

    RetVarIdx := SymAdd('result', SC_VAR, RetTypeIdx);
    If RetVarIdx >= 0 Then
    Begin
      SymTab[RetVarIdx].Offset  := CurFuncRetOfs;
      SymTab[RetVarIdx].IsLocal := True;
    End;
  End
  Else
    CurFuncName := '';

  (* Declarations locales const/var/type avant le begin *)
  While ((CurToken.Kind = TK_KEYWORD) And
         ((StrLowerCase(CurToken.Val) = 'const') Or
          (StrLowerCase(CurToken.Val) = 'var') Or
          (StrLowerCase(CurToken.Val) = 'type') Or
          (StrLowerCase(CurToken.Val) = 'label'))) Do
  Begin
    If StrLowerCase(CurToken.Val) = 'const' Then
    Begin
      LexNextToken;
      ParseConstDecl;
    End
    Else If StrLowerCase(CurToken.Val) = 'var' Then
    Begin
      LexNextToken;
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        HasPendingAssign := False;
        ParseAssignment(PendingAssignName);
      End;
    End
    Else If StrLowerCase(CurToken.Val) = 'type' Then
    Begin
      LexNextToken;
      ParseTypeDecl;
    End
    Else If StrLowerCase(CurToken.Val) = 'label' Then
    Begin
      LexNextToken;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      Begin
        If CurToken.Kind = TK_INTEGER Then
        Begin
          SymAdd(IntToStr(CurToken.IntVal), SC_LABEL, TY_UNKNOWN);
          LexNextToken;
        End
        Else If CurToken.Kind = TK_IDENT Then
        Begin
          SymAdd(CurToken.Val, SC_LABEL, TY_UNKNOWN);
          LexNextToken;
        End
        Else
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          LexNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
    End;
  End;

  (* Calculer la taille du cadre local *)
  FrameSize := -CurFrameOffset;

  (* Emettre le code de la procedure *)
  EmitBlankLine;
  EmitComment('--- ' + FuncName + ' ---');
  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   PROC NEAR')
  Else
    EmitRaw(VXP_FN_PFX + StrUpperCase(FuncName) + '   PROC NEAR');

  (* Prologue *)
  EmitProlog(FrameSize);

  (* Initialiser la valeur de retour a 0 *)
  If IsFunc Then
    EmitInstrAB('MOV', 'WORD PTR ' + BPOfs(CurFuncRetOfs), '0');

  (* Corps : begin ... end *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'begin') Then
    ParseBlock
  Else
    WarnMsg('''begin'' attendu dans le corps de ' + FuncName);

  (* Label de retour (pour Exit) *)
  EmitLabel(RetLabel);

  (* Charger la valeur de retour dans AX (fonctions) *)
  If IsFunc Then
    EmitInstrAB('MOV', 'AX',
      'WORD PTR ' + BPOfs(CurFuncRetOfs));

  (* Epilogue *)
  EmitEpilog(ParamBytes);

  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   ENDP')
  Else
    EmitRaw(VXP_FN_PFX + StrUpperCase(FuncName) + '   ENDP');
  EmitBlankLine;

  (* Consommer le ; final apres end *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;

  (* Restaurer le contexte *)
  SymLeaveScope;
  Dec(CurNestLevel);
  CurFrameOffset := SaveFrame;
  CurFuncName    := SaveFuncName;
  CurFuncRetOfs  := SaveRetOfs;
  CurRetLabel    := SaveRetLabel;
  CurParamBytes  := SaveParamB;
End;

(* ---- ParseFuncDecl : analyser une declaration de fonction ---- *)
Procedure ParseFuncDecl;
Begin
  ParseFuncOrProc(True);
End;

(* ---- ParseProcDecl : analyser une declaration de procedure --- *)
Procedure ParseProcDecl;
Begin
  ParseFuncOrProc(False);
End;

(* ---- ParseWithStmt : analyser WITH r DO stmt -------------------- *)
(* Syntaxe : WITH record_var [, record_var2] DO stmt ;               *)
(* Empile les variables record dans le with-stack pour que les       *)
(* champs soient resolus sans qualification.                          *)
Procedure ParseWithStmt;
Var
  WSIdx   : Integer;
  RTIdx   : Integer;
  WCount  : Integer;
Begin
  LexNextToken;  (* consommer WITH *)
  EmitComment('with');
  WCount := 0;

  (* Parser la liste de variables record *)
  Repeat
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      WSIdx := SymFind(CurToken.Val);
      If WSIdx < 0 Then
      Begin
        WarnMsg('variable non declaree dans WITH: ' + CurToken.Val);
        LexNextToken;
      End
      Else
      Begin
        RTIdx := SymTab[WSIdx].TypeIdx;
        If (RTIdx >= 0) And (RTIdx < TypeCount) And
           (TypeTab[RTIdx].Kind = TKP_RECORD) Then
        Begin
          LexNextToken;
          If WithTop < MAX_WITH - 1 Then
          Begin
            Inc(WithTop);
            WithSymIdx[WithTop] := WSIdx;
            Inc(WCount);
            If Opts.DebugMode Then
              WriteLn('  WITH_PUSH: ', SymTab[WSIdx].Name,
                      ' top=', WithTop);
          End
          Else
            WarnMsg('with imbrique trop profond');
        End
        Else
        Begin
          WarnMsg('WITH attend une variable de type record');
          LexNextToken;
        End;
      End;
    End
    Else
    Begin
      WarnMsg('identificateur attendu apres WITH');
      Break;
    End;
    (* Virgule pour WITH multiple : WITH r1, r2 DO ... *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken
    Else
      Break;
  Until False;

  (* Consommer DO *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'do') Then
    LexNextToken
  Else
    WarnMsg('''do'' attendu apres WITH');

  (* Parser l instruction *)
  ParseStatement;

  (* Depiler les with-variables *)
  While WCount > 0 Do
  Begin
    If WithTop >= 0 Then
    Begin
      If Opts.DebugMode Then
        WriteLn('  WITH_POP: top=', WithTop);
      Dec(WithTop);
    End;
    Dec(WCount);
  End;

  (* Semicolonne optionnelle *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    LexNextToken;
End;

(* ---- ParseStatement : analyser une instruction simple -------- *)
(* Dispatch : begin..end, if, case, for, while, repeat, loop,      *)
(*   function, procedure, with, write, writeln, read, readln, goto, *)
(*   break, continue, exit, affectation ident := expr ;             *)
(* Ne consomme PAS le ; terminal (sauf via sub-parsers).            *)
Procedure ParseStatement;
Var
  SavedName  : TString;
  GotoIdx    : Integer;
  L          : TString;
  StmtEv     : TExprVal;
Begin
  (* Bloc begin...end *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'begin') Then
  Begin
    ParseBlock;
    Exit;
  End;

  (* IF *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'if') Then
  Begin
    ParseIfStmt;
    Exit;
  End;

  (* CASE *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'case') Then
  Begin
    ParseCaseStmt;
    Exit;
  End;

  (* FOR *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'for') Then
  Begin
    ParseForStmt;
    Exit;
  End;

  (* WHILE *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'while') Then
  Begin
    ParseWhileStmt;
    Exit;
  End;

  (* REPEAT *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'repeat') Then
  Begin
    ParseRepeatStmt;
    Exit;
  End;

  (* LOOP (VAX) *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'loop') Then
  Begin
    ParseLoopStmt;
    Exit;
  End;

  (* FUNCTION declaration *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'function') Then
  Begin
    ParseFuncDecl;
    Exit;
  End;

  (* PROCEDURE declaration *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'procedure') Then
  Begin
    ParseProcDecl;
    Exit;
  End;

  (* WITH *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'with') Then
  Begin
    ParseWithStmt;
    Exit;
  End;

  (* EXIT : saut au label de retour *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'exit') Then
  Begin
    LexNextToken;
    If CurRetLabel <> '' Then
      EmitInstrA('JMP', CurRetLabel)
    Else
      WarnMsg('''exit'' en dehors d''une fonction/procedure');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* BREAK *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'break') Then
  Begin
    LexNextToken;
    If LoopTop < 0 Then
      WarnMsg('''break'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopBreakLbl[LoopTop]);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* CONTINUE / NEXT *)
  If (CurToken.Kind = TK_KEYWORD) And
     ((StrLowerCase(CurToken.Val) = 'continue') Or
      (StrLowerCase(CurToken.Val) = 'next')) Then
  Begin
    LexNextToken;
    If LoopTop < 0 Then
      WarnMsg('''continue'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopContLbl[LoopTop]);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* Write *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'write') Then
  Begin
    LexNextToken;
    ParseWriteStmt(False);
    Exit;
  End;

  (* WriteLn *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'writeln') Then
  Begin
    LexNextToken;
    ParseWriteStmt(True);
    Exit;
  End;

  (* WriteV *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'writev') Then
  Begin
    LexNextToken;
    WarnMsg('WriteV traite comme Write (stub)');
    ParseWriteStmt(False);
    Exit;
  End;

  (* Read *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'read') Then
  Begin
    LexNextToken;
    ParseReadStmt(False);
    Exit;
  End;

  (* ReadLn *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'readln') Then
  Begin
    LexNextToken;
    ParseReadStmt(True);
    Exit;
  End;

  (* ReadV *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'readv') Then
  Begin
    LexNextToken;
    WarnMsg('ReadV traite comme Read (stub)');
    ParseReadStmt(False);
    Exit;
  End;

  (* Numeric label definition: 100: *)
  If CurToken.Kind = TK_INTEGER Then
  Begin
    SavedName := IntToStr(CurToken.IntVal);
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      EmitLabel(VXP_LBL_PFX + 'USR_' + SavedName);
      LexNextToken;
      Exit;
    End;
    (* Entier isole dans un contexte instruction - ignorer *)
    Exit;
  End;

  (* GOTO *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'goto') Then
  Begin
    LexNextToken;
    EmitComment('goto');
    If (CurToken.Kind = TK_INTEGER) Then
    Begin
      EmitInstrA('JMP', VXP_LBL_PFX + 'USR_' + IntToStr(CurToken.IntVal));
      LexNextToken;
    End
    Else If (CurToken.Kind = TK_IDENT) Then
    Begin
      GotoIdx := SymFind(CurToken.Val);
      If (GotoIdx >= 0) And (SymTab[GotoIdx].Cat = SC_LABEL) Then
        EmitInstrA('JMP', SymTab[GotoIdx].MangledName)
      Else
        EmitInstrA('JMP', VXP_LBL_PFX + 'USR_' +
                     StrUpperCase(CurToken.Val));
      LexNextToken;
    End
    Else
      WarnMsg('label attendu apres GOTO');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* RETURN (VAX) *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'return') Then
  Begin
    LexNextToken;
    EmitComment('return');
    (* RETURN(expr) optionnel *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      LexNextToken;
      ParseExpr(StmtEv);
      ExprFlushToAX(StmtEv);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        LexNextToken;
    End;
    EmitInstr('RET');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* STOP (VAX) - equivalent de HALT *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'stop') Then
  Begin
    LexNextToken;
    EmitComment('stop');
    EmitInstrAB('MOV', 'AH', '4Ch');
    EmitInstrAB('MOV', 'AL', '0');
    EmitInstr('INT    21h');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* HALT / HALT(code) *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'halt') Then
  Begin
    LexNextToken;
    EmitComment('halt');
    EmitInstrAB('MOV', 'AH', '4Ch');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      LexNextToken;
      ParseExpr(StmtEv);
      ExprFlushToAX(StmtEv);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        LexNextToken;
    End
    Else
      EmitInstrAB('MOV', 'AL', '0');
    EmitInstr('INT    21h');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* Identifiant suivi de := -> affectation *)
  If CurToken.Kind = TK_IDENT Then
  Begin
    SavedName := CurToken.Val;
    LexNextToken;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      ParseAssignment(SavedName);
      Exit;
    End;
    (* Ident label definition: mylabel: *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      GotoIdx := SymFind(SavedName);
      If (GotoIdx >= 0) And (SymTab[GotoIdx].Cat = SC_LABEL) Then
        EmitLabel(SymTab[GotoIdx].MangledName)
      Else
        EmitLabel(VXP_LBL_PFX + StrUpperCase(SavedName));
      LexNextToken;
      Exit;
    End;
    (* Appel de procedure sans parametres *)
    GotoIdx := SymFind(SavedName);
    If (GotoIdx >= 0) And (SymTab[GotoIdx].Cat = SC_PROC) Then
    Begin
      EmitComment('call ' + SavedName);
      EmitCall(SymTab[GotoIdx].MangledName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;
    (* Sinon token consomme, continuer *)
    Exit;
  End;

  (* Instruction vide ou token inconnu *)
  If CurToken.Kind <> TK_EOF Then
  Begin
    L := StrLowerCase(CurToken.Val);
    (* Ne pas consommer end, else, until, others, otherwise *)
    If (CurToken.Kind = TK_KEYWORD) And
       ((L = 'end') Or (L = 'else') Or (L = 'until') Or
        (L = 'others') Or (L = 'otherwise')) Then
      Exit;
    LexNextToken;
  End;
End;

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

  { -- TODO 05 : En-tete ASM -- }
  EmitHeader;

  { -- TODO 06 : Initialiser la table des symboles -- }
  SymInit;

  { -- TODO 07 : Initialiser le systeme de types -- }
  TypeInit;

  { -- TODO 02 : Lexeur -- }
  LexInit;

  { Boucle de tokenisation - TODO 09 : dispatch declarations }
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
  Begin
    (* PROGRAM header *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'program') Then
    Begin
      LexNextToken;  (* consommer PROGRAM *)
      If CurToken.Kind = TK_IDENT Then
        LexNextToken;  (* nom du programme *)
      (* Parametres optionnels (input, output) *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* MODULE header *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'module') Then
    Begin
      IsModule := True;
      LexNextToken;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ModuleName := CurToken.Val;
        LexNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* VAR block *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'var') Then
    Begin
      LexNextToken;  (* consommer VAR *)
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        ParseAssignment(PendingAssignName);
        HasPendingAssign := False;
      End;
      Continue;
    End;

    (* STATIC VAR *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'static') Then
    Begin
      LexNextToken;  (* consommer STATIC *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
      Begin
        LexNextToken;  (* consommer VAR *)
        (* Flag pour ParseVarDecl via attributs -- on appelle direct *)
        (* On reutilise ParseVarDecl, le IsStaticVar est interne    *)
        (* Solution: gerer via attribut interne                     *)
        ParseVarDecl;
        If HasPendingAssign Then
        Begin
          ParseAssignment(PendingAssignName);
          HasPendingAssign := False;
        End;
      End
      Else
        LexNextToken;  (* sauter si pas VAR *)
      Continue;
    End;

    (* EXTERNAL VAR (VMS) *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'external') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
      Begin
        LexNextToken;
        ParseVarDecl;
        If HasPendingAssign Then
        Begin
          ParseAssignment(PendingAssignName);
          HasPendingAssign := False;
        End;
      End
      Else
        LexNextToken;
      Continue;
    End;

    (* VALUE section (VMS Pascal) *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'value') Then
    Begin
      LexNextToken;
      ParseValueSection;
      Continue;
    End;

    (* CONST block - support VAX := pour typed const *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'const') Then
    Begin
      LexNextToken;
      ParseConstDecl;
      Continue;
    End;

    (* TYPE block *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'type') Then
    Begin
      LexNextToken;
      ParseTypeDecl;
      Continue;
    End;

    (* Attributs VAX avant VAR : [EXTERNAL] var ... *)
    If IsOpenBracket Then
    Begin
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        ParseAssignment(PendingAssignName);
        HasPendingAssign := False;
      End;
      Continue;
    End;

    (* BEGIN..END : bloc principal du programme *)

    (* LABEL declarations *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'label') Then
    Begin
      LexNextToken;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      Begin
        If CurToken.Kind = TK_INTEGER Then
        Begin
          SymAdd(IntToStr(CurToken.IntVal), SC_LABEL, TY_UNKNOWN);
          LexNextToken;
        End
        Else If CurToken.Kind = TK_IDENT Then
        Begin
          SymAdd(CurToken.Val, SC_LABEL, TY_UNKNOWN);
          LexNextToken;
        End
        Else
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          LexNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* FUNCTION declaration au niveau global *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'function') Then
    Begin
      ParseFuncDecl;
      Continue;
    End;

    (* PROCEDURE declaration au niveau global *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'procedure') Then
    Begin
      ParseProcDecl;
      Continue;
    End;

    (* BEGIN : entrer dans le bloc principal *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'begin') Then
    Begin
      If Not MainBodyEmitted Then
      Begin
        MainBodyEmitted := True;
        EmitLabel(VXP_LBL_PFX + 'MAINBODY');
      End;
      ParseBlock;
      (* Consommer le . final *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
        LexNextToken;
      Continue;
    End;

    (* END seul (fin de module ou bloc implicite) *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'end') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And
         ((CurToken.Val = '.') Or (CurToken.Val = ';')) Then
        LexNextToken;
      Continue;
    End;

    (* Toute autre instruction executable au niveau global *)
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      If Not MainBodyEmitted Then
      Begin
        MainBodyEmitted := True;
        EmitLabel(VXP_LBL_PFX + 'MAINBODY');
      End;
      ParseStatement;
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
        LexNextToken;
      Continue;
    End;

    (* Sauter les tokens non reconnus *)
    LexNextToken;
  End;

  LexClose;

  { -- TODO 05 : Label MAINBODY et code principal -- }
  If Not MainBodyEmitted Then
  Begin
    MainBodyEmitted := True;
    EmitLabel(VXP_LBL_PFX + 'MAINBODY');
  End;

  { -- TODO 05 : Pied de page et runtime -- }
  EmitFooter;

  { -- TODO 04 : Segment de donnees -- }
  EmitDataSeg;
  EmitBlankLine;

  { -- TODO 05 : Directive END finale -- }
  EmitClose;

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
