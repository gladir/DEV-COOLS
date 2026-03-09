{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur VAX Pascal vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  VAXPCW32.PAS - Compilateur VAX Pascal vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de VAXPAS86.PAS et les exemples
  SAMPLES\VAXPASCAL\*

  VAX Pascal est une extension du Pascal standard ISO 7185
  developpee par Digital Equipment Corporation (DEC) pour les
  systemes VAX/VMS. Ce compilateur prend en entree des fichiers
  .PAS en dialecte VAX Pascal et produit de l assembleur 80386
  compatible MASM pour Windows 32 bits (PE).

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              AsmOutput, ObjOnly)
            ParseArgs : analyser argv (source.pas [sortie.exe] [-v] [-d]
              [-w] [-obj] [-asm])
            -obj : produire uniquement un fichier .OBJ (COFF)
            -asm : produire egalement un fichier .ASM lisible
            Par defaut : produire un .EXE (PE Windows 32 bits)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .pas du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h ou /?)

  TODO 02 - LEXEUR (TOKENS VAX PASCAL)
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_OCTAL, TK_ATTR_OPEN, TK_ATTR_CLOSE
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre apostrophes 'abc'
              Apostrophe doublee : 'it''s' -> it's
            LexScanCharLit : caractere entre apostrophes 'A'
            LexScanHexNumber : entiers hexadecimaux %X'FF' ou $FF
            LexScanOctalNumber : entiers octaux %O'77' ou 777B
            Commentaires : accolades et parentheses-etoile imbriques
            Mots-cles : AND ARRAY BEGIN BOOLEAN CASE CHAR CONST
              DIV DO DOWNTO ELSE END FILE FOR FUNCTION GOTO IF
              IN INTEGER LABEL MOD MODULE NIL NOT OF OR OTHERWISE
              PACKED PROCEDURE PROGRAM RECORD REPEAT SET THEN TO
              TYPE UNTIL VAR VARYING WHILE WITH
            Mots-cles VAX etendus : DOUBLE EXTERNAL GLOBAL INHERIT
              ENVIRONMENT STATIC VALUE ANDIF ORIF LOOP EXIT
              CONDITION EXCEPTION ON READONLY VOLATILE WORD HIDDEN
            Attributs entre crochets : [ et ] pour TK_ATTR_OPEN / CLOSE
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..4294967295 (32 bits) ou signes
            Entiers hexadecimaux : %X'FF' ou $FF -> valeur 32 bits
            Entiers octaux : %O'77' ou 777B -> valeur 32 bits
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
              DOUBLE : reconnu, tronque en entier avec avertissement
            Caracteres : 'A' -> valeur ordinale 32 bits
            Chaines : 'abc' -> pointeur vers donnees .DATA avec label
            NIL : constante pointeur nul -> EAX=0
            TRUE : constante booleenne -> EAX=1
            FALSE : constante booleenne -> EAX=0
            MAXINT : constante predeclaree -> 2147483647 (32 bits)
            Constantes typees : CONST x : Integer = 42; -> .DATA
            Constantes nommees : CONST x = 42; -> substitution immediate

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques  : + - * DIV MOD (entiers 32 bits)
            Concatenation  : || (VAX Pascal, appel _VXPRT_CONCAT)
            Exponentiation : ** (appel _VXPRT_POWER)
            Comparaison    : = <> < <= > >=
            Logiques       : AND OR NOT
            Court-circuit  : ANDIF ORIF (evaluation court-circuit)
            Ensemblistes   : + (union) * (intersection) - (difference)
            Appartenance   : IN (element IN ensemble)
            Affectation    : := (assignation)
            Unaire         : + - (signe) NOT (negation logique)
            Adresse        : @ (adresse de variable)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-, @
              2. ** (exponentiation)
              3. * DIV MOD / AND
              4. + - OR || (concatenation)
              5. = <> < <= > >= IN
              6. ANDIF (AND court-circuit)
              7. ORIF (OR court-circuit)

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR, SC_CONST, SC_TYPED_CONST, SC_PARAM,
              SC_VARPARAM, SC_FUNC, SC_PROC, SC_TYPE, SC_FIELD,
              SC_ENUM_VAL, SC_LABEL, SC_STATIC, SC_EXTERNAL, SC_GLOBAL,
              SC_PUBLIC, SC_MODULE, SC_CONDITION
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              Scope, ScopeId, IsGlobal, IsExternal, IsStatic
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Qualificateurs de module : Module.Ident recherche dans portee
            Prefixes de mangling : _VXV_ (var), _VXF_ (func/proc),
              _VXK_ (chaine const), _VXRT_ (runtime), _VXL_ (label),
              _VXA_ (tableau), _VXR_ (record), _VXE_ (enum),
              _VXM_ (module)

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TKP_INTEGER (32 bits signe), TKP_WORD (32 bits
              non signe), TKP_BYTE (8 bits), TKP_CHAR (8 bits),
              TKP_BOOLEAN (8 bits), TKP_STRING (ptr chaine),
              TKP_REAL (stub entier), TKP_DOUBLE (stub entier),
              TKP_ARRAY, TKP_RECORD, TKP_ENUM, TKP_SUBRANGE,
              TKP_POINTER, TKP_NIL, TKP_TEXT (fichier texte),
              TKP_VARYING (chaine longueur variable),
              TKP_SET (ensemble), TKP_FILE (fichier binaire),
              TKP_SCHEMA (type schema), TKP_PROCEDURAL (var procedurale),
              TKP_VOID
            TypeTab, TypeInit : enregistrer types primitifs et utilisateur
            TypeSizeof : Integer=4, Word=4, Byte=1, Char=1, Bool=1,
              String=4 (ptr), Pointer=4, Varying=4+n (len+data)
            TypeCompatible : verification de compatibilite d affectation
            TypeCoerce : coercition automatique (Byte->Integer, etc.)
            TypeResolve : resolution de types nommes
            Types primitifs predefinis : INTEGER, UNSIGNED, WORD,
              BYTE, CHAR, BOOLEAN, REAL, DOUBLE, STRING, POINTER

  TODO 07 - EMETTEUR DE CODE ASM 80386
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _VXL_NNNNN)
            Prefixes 32 bits : _VXV_ (variable), _VXF_ (fonction),
              _VXK_ (chaine const), _VXRT_ (runtime), _VXL_ (label)
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
              DK_ARRAY/DK_REC/DK_ARRAY_INIT/DK_SET), IntVal, StrVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddDWord, DataAddByte,
              DataAddArray, DataAddRec : variantes d ajout
            Variables globales (VAR au niveau programme) :
              DD dans .DATA avec label _VXV_nom
            Variables STATIC : DD dans .DATA, persistantes entre appels
            Constantes typees : DD/DB dans .DATA (immuables)
            Chaines litterales : DB 'abc',0 dans .DATA avec label _VXK_N
            Tampons VARYING : DB taille DUP(0) avec prefixe longueur

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables globales : segment .DATA, acces par [_VXV_nom]
            Variables locales : pile EBP, acces [EBP-offset]
            Parametres : [EBP+8+...] (convention stdcall/cdecl 32 bits)
            Declaration VAR : allocation espace pile (SUB ESP,n) ou DATA
            Declaration STATIC VAR : allocation en .DATA, persistante
            Affectation := : ExprFlushToEAX + MOV destination, EAX
            Affectation de chaines : CALL _VXPRT_STRCOPY
            Affectation de records : copie champ par champ ou REP MOVSD
            Affectation de tableaux : copie par REP MOVSD
            Affectation VARYING := : CALL _VXPRT_VARY_ASSIGN
            Coercition automatique lors de l affectation

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, ident, appel
            Acces variable globale : MOV EAX,[_VXV_nom]
            Acces variable locale : MOV EAX,[EBP-offset]
            Acces parametre : MOV EAX,[EBP+offset]
            Appel de fonction : CALL _VXF_nom -> resultat dans EAX
            Fonctions intrinseques VAX Pascal :
              ORD(x), CHR(x), ABS(x), SQR(x), ODD(x)
              SUCC(x), PRED(x), TRUNC(x), ROUND(x)
              SIZE(x), ADDRESS(x), IADDRESS(x)
              UPPERBOUND(a,d), LOWERBOUND(a,d), DIMENSION(a,d)
              LENGTH(s), INDEX(s,t), SUBSTR(s,pos,len)
            Parentheses : (expr) pour forcer la precedence
            Conversion de type : TypeName(expr) (coercition)
            Substring : S[pos:len] -> CALL _VXPRT_SUBSTR

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique 32 bits : ADD/SUB/IMUL/IDIV pour +, -, *, DIV
            Modulo : IDIV -> resultat dans EDX (reste) pour MOD
            Comparaison : CMP + Jcc pour =, <>, <, <=, >, >=
            Comparaison String : CALL _VXPRT_STRCMP -> drapeaux
            Comparaison VARYING : CALL _VXPRT_VARY_CMP -> drapeaux
            Logique AND : AND EAX, valeur (bit a bit si entier)
            Logique OR  : OR EAX, valeur
            Logique NOT : XOR EAX,1 (booleen)
            Court-circuit ANDIF : TEST EAX,EAX / JZ vers false
            Court-circuit ORIF : TEST EAX,EAX / JNZ vers true
            Concatenation || : CALL _VXPRT_CONCAT
            Exponentiation ** : CALL _VXPRT_POWER
            Ensembles IN : BT [set_addr], valeur / SETC AL

  TODO 12 - ENTREES/SORTIES (WRITE / WRITELN / READ / READLN)
            WRITE(items...) / WRITELN(items...) :
              WRITE('Hello')     -> CALL _VXPRT_PRINTSTR
              WRITE(42)          -> CALL _VXPRT_PRINTINT
              WRITE(x:10)        -> CALL _VXPRT_PRINTINT_W (largeur)
              WRITE(r:10:2)      -> CALL _VXPRT_PRINTREAL_WD (stub)
              WRITE(b)           -> CALL _VXPRT_PRINTBOOL
              WRITE(c)           -> CALL _VXPRT_PRINTCHAR
              WRITELN            -> CALL _VXPRT_PRINTCRLF
            READ(vars...) / READLN(vars...) :
              READ(i)            -> CALL _VXPRT_READINT
              READ(s)            -> CALL _VXPRT_READSTR
              READ(c)            -> CALL _VXPRT_READCHAR
              READLN             -> CALL _VXPRT_READLN
            WRITE(f, ...) / READ(f, ...) : I/O sur fichier (variable f)
            OPEN, CLOSE : ouverture / fermeture de fichier
            Emission bas niveau Win32 :
              WriteFile(hStdOut, buf, len, written, nil)
              ReadFile(hStdIn, buf, len, read, nil)

  TODO 13 - IF / CASE / OTHERS
            ParseIfStmt : IF cond THEN stmt [ELSE stmt]
              Emission TEST EAX,EAX / JZ pour condition fausse
              Labels : _VXL_ELSE_N, _VXL_ENDIF_N
              IF imbriques : ELSE IF cond THEN ...
            ParseCaseStmt : CASE expr OF val1: stmt; val2: stmt;
              [OTHERWISE stmt;] END
              OTHERWISE (ou OTHERS) : branche par defaut VAX Pascal
              Emission : CMP EAX, valeur + JE pour chaque branche
              Intervalles : val1..val2 : stmt (comparaison de bornes)
              Listes de valeurs : val1, val2, val3 : stmt
              Labels : _VXL_CASE_N, _VXL_CDEF_N, _VXL_CEND_N

  TODO 14 - BOUCLES (FOR / WHILE / REPEAT / LOOP..EXIT IF..END)
            ParseForStmt : FOR i := lo TO|DOWNTO hi DO stmt
              Variable de boucle locale ou globale 32 bits
              Labels : _VXL_FTEST_N, _VXL_FINCR_N, _VXL_FEND_N
              TO : INC + CMP + JLE / DOWNTO : DEC + CMP + JGE
            ParseWhileStmt : WHILE cond DO stmt
              Labels : _VXL_WTEST_N, _VXL_WEND_N
            ParseRepeatStmt : REPEAT stmts UNTIL cond
              Labels : _VXL_RBEG_N, _VXL_REND_N
            ParseLoopStmt : LOOP stmts [EXIT IF cond;] END (VAX)
              Boucle infinie avec sortie conditionnelle
              EXIT IF cond : TEST EAX,EAX / JNZ -> fin de boucle
              Labels : _VXL_LBEG_N, _VXL_LEND_N
            LoopPush / LoopPop : pile de labels pour break/continue
            LEAVE : sortie immediate de la boucle englobante

  TODO 15 - TABLEAUX ET TABLEAUX CONFORMANTS
            ARRAY[lo..hi] OF T : tableau a bornes fixes
              Taille = (hi-lo+1) * sizeof(T)
              Acces : base + (index-lo) * sizeof(T) -> adresse element
            ARRAY[lo..hi, lo2..hi2] OF T : tableaux multi-dimensionnels
              Linearisation : (i-lo1)*dim2 + (j-lo2)
            PACKED ARRAY : compactage (1 octet par CHAR, etc.)
            Tableaux conformants : ARRAY[1..*] OF T (VAX Pascal)
              Borne superieure passee comme parametre cache
              Acces via descripteur (ptr + bornes)
            ARRAY OF CHAR : traitement special comme chaine
            Constantes de tableau : CONST a = (1, 2, 3);
              -> donnees dans .DATA
            Verification de bornes optionnelle (CheckEnabled)

  TODO 16 - ENREGISTREMENTS (RECORD) ET WITH
            RECORD champ1: T1; champ2: T2; END
              Taille = somme des sizeof(Ti) avec alignement 32 bits
              Acces champ : offset fixe depuis debut du record
            RECORD CASE tag OF ... END : variantes (unions)
              Partie fixe + partie variante (taille = max des variantes)
            PACKED RECORD : compactage sans alignement
            WITH rec DO stmt : acces direct aux champs
              WithSymIdx : pile de records en cours (max MAX_WITH)
              Recherche de champs dans les records englobants
            Affectation de records : copie complete (REP MOVSD)
            Constantes de record : CONST r = (x: 1; y: 2);
            Records imbriques : RECORD contenant RECORD

  TODO 17 - ENUMERATIONS ET SOUS-INTERVALLES
            TYPE T = (Val1, Val2, Val3) : enumeration
              Chaque valeur = constante entiere (0, 1, 2, ...)
              Taille : 4 octets (DWORD 32 bits)
              ORD(val) : valeur ordinale
              SUCC(val), PRED(val) : successeur, predecesseur
            TYPE T = lo..hi : sous-intervalle
              Bornes entieres ou valeurs d enumeration
              Taille : 4 octets (DWORD)
              Verification de bornes optionnelle
            FIRST(T), LAST(T) : bornes du type ordinal
              FIRST -> valeur minimale, LAST -> valeur maximale
            Fonctions intrinseques sur types ordinaux :
              ORD, CHR, SUCC, PRED, ODD

  TODO 18 - PROCEDURES ET FONCTIONS
            ParseParamList : parametres formels 32 bits
              Parametres valeur : copie sur la pile (PUSH)
              Parametres VAR : passage par adresse (LEA + PUSH)
              Offsets : [EBP+8], [EBP+12], [EBP+16], ...
            ParseFuncOrProc : declaration complete
              Attributs : [GLOBAL], [EXTERNAL], [HIDDEN]
              FORWARD : declaration avancee
              Variables locales : [EBP-4], [EBP-8], ...
              Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,n
              Epilogue : MOV ESP,EBP / POP EBP / RET n
              Valeur de retour (fonction) : resultat dans EAX
              Nom de fonction := valeur (assignation du resultat)
            Variables procedurales : TYPE ProcType = PROCEDURE(...)
              Stockage : DWORD contenant adresse de la procedure
              Appel indirect : CALL DWORD PTR [var]
            Procedures et fonctions imbriquees
            Parametres nommes : Proc(Param1 := val1, Param2 := val2)
              (VAX Pascal extension)

  TODO 19 - POINTEURS ET ALLOCATION DYNAMIQUE
            TYPE PtrType = ^BaseType : declaration de pointeur
              Taille : 4 octets (DWORD, adresse 32 bits)
            NEW(p) : allocation dynamique
              CALL _VXPRT_NEW -> HeapAlloc Win32
            DISPOSE(p) : liberation memoire
              CALL _VXPRT_DISPOSE -> HeapFree Win32
            Dereferencement : p^ -> MOV EAX,[EAX]
            Acces champ via pointeur : p^.champ -> offset
            Affectation de pointeurs : copie d adresse (MOV)
            NIL : pointeur nul (EAX=0)
            Test de pointeur : IF p <> NIL THEN ...
            ADDRESS(x) : adresse d une variable -> LEA EAX,[var]
            IADDRESS(x) : adresse entiere (meme chose en 32 bits)

  TODO 20 - CHAINES ET VARYING OF CHAR
            STRING : chaine terminee par 0 (ASCIIZ)
              Taille en .DATA : DB 'abc',0
              Acces par pointeur (EAX = adresse)
            VARYING [n] OF CHAR : chaine de longueur variable (VAX)
              Structure : WORD longueur + n octets de donnees
              .LENGTH : lire le mot de longueur
              .BODY : pointeur vers les donnees
            Routines runtime VARYING :
              _VXPRT_VARY_ASSIGN(ESI=src, EDI=dst) : copie
              _VXPRT_VARY_CONCAT(ESI=s1, EDI=s2) : concatenation
              _VXPRT_VARY_LENGTH(ESI=s) -> EAX : longueur
              _VXPRT_VARY_BODY(ESI=s) -> EAX : ptr donnees
              _VXPRT_VARY_SUBSTR(ESI=s, EBX=pos, ECX=len) : extraction
              _VXPRT_VARY_CMP(ESI=s1, EDI=s2) : comparaison
            Concatenation || : chaine || chaine -> resultat VARYING
            INDEX(s, t) : position de t dans s -> EAX (0 si absent)
            LENGTH(s) : longueur de chaine -> EAX
            SUBSTR(s, pos, len) : extraction de sous-chaine

  TODO 21 - ENSEMBLES (SET)
            SET OF T : ensemble de type ordinal (0..255 max)
              Representation : 32 octets (256 bits) en .DATA ou pile
            Constructeur : [val1, val2, lo..hi]
              BTS [set_addr], valeur pour chaque element
            Operations ensemblistes :
              + (union)        : OR octet par octet
              * (intersection) : AND octet par octet
              - (difference)   : AND NOT octet par octet
            IN : test d appartenance -> BT [set_addr], valeur / SETC
            Comparaison : = <> <= >= entre ensembles
              = : comparaison octet par octet (REPE CMPSB)
              <= : sous-ensemble (A-B = vide)
            Ensemble vide : [] -> 32 octets a zero
            Affectation : copie des 32 octets (REP MOVSD)

  TODO 22 - MODULES (MODULE / INHERIT / ENVIRONMENT)
            MODULE nom; ... END. : unite de compilation separee
              Pas de programme principal, seulement declarations
              Toutes les declarations sont exportables
            [ENVIRONMENT('nom')] : generer fichier .INC d export
              Ecriture des EXTRN pour chaque symbole exporte
              Symboles exportes : SC_FUNC, SC_PROC, SC_GLOBAL,
                SC_PUBLIC, SC_VAR, SC_STATIC, SC_TYPED_CONST
            [INHERIT('nom')] : charger definitions d un module
              Lire le fichier .INC genere par ENVIRONMENT
              Ajouter les symboles externes a la table
            [GLOBAL] : procedure/fonction visible depuis d autres modules
              Generer PUBLIC dans l assembleur
            [EXTERNAL] : procedure/fonction definie dans un autre module
              Generer EXTRN dans l assembleur
            [HIDDEN] : symbole non exportable
            Mangling de noms de module : _VXM_module_VXF_proc

  TODO 23 - EXCEPTIONS (CONDITION / ON..DO) ET PREPROCESSEUR
            Exceptions VAX Pascal :
              Conditions predefinies : ss$_accvio, ss$_intovf,
                ss$_intdiv, ss$_fltovf, ss$_fltdiv, ss$_roprand
              CONDITION : declaration de condition utilisateur
              BEGIN ... EXCEPTION
                ON cond DO stmt;
                [ANYOTHER stmt;]
                [ALLCONDITIONS stmt;]
              END
              Mecanisme : sauvegarde ESP/EBP + handler address
              SIGNAL(cond) : lever une exception -> JMP handler
              RESIGNAL : propager au handler englobant
            Directives de pretraitement :
              $INCLUDE 'fichier' ou %INCLUDE 'fichier'
              $TITLE 'titre', $PAGE, $OPTIONS
              $IF expr / $ELSE / $END (compilation conditionnelle)
              %DICTIONARY : consultation CDD (stub avec avertissement)

  TODO 24 - RUNTIME MINIMAL WIN32
            _VXPRT_PRINTSTR(ESI=msg) : WriteFile sur hStdOut
            _VXPRT_PRINTINT(EAX=n) : conversion + WriteFile
            _VXPRT_PRINTCRLF : ecriture CR+LF
            _VXPRT_PRINTBOOL(EAX=b) : afficher TRUE/FALSE
            _VXPRT_PRINTCHAR(EAX=c) : afficher un caractere
            _VXPRT_PRINTINT_W(EAX=n, ECX=w) : entier avec largeur
            _VXPRT_NUMTOSTR(EAX=n, EDI=buf) : entier -> ASCII (itoa)
            _VXPRT_STRTONUM(ESI=str) : ASCII -> entier -> EAX (atoi)
            _VXPRT_STRLEN(ESI=str) : longueur ASCIIZ -> EAX
            _VXPRT_STRCMP(ESI=s1, EDI=s2) : comparaison -> drapeaux
            _VXPRT_STRCOPY(ESI=src, EDI=dst) : copie de chaine
            _VXPRT_CONCAT(ESI=s1, EDI=s2) : concatenation -> EAX=ptr
            _VXPRT_SUBSTR(ESI=s, EBX=pos, ECX=len) : sous-chaine
            _VXPRT_READINT -> EAX : lire entier depuis stdin
            _VXPRT_READSTR(EDI=buf) : lire ligne depuis stdin
            _VXPRT_READCHAR -> EAX : lire un caractere
            _VXPRT_READLN : consommer jusqu au prochain CR+LF
            _VXPRT_POWER(EAX=base, ECX=exp) : exponentiation -> EAX
            _VXPRT_NEW(ECX=taille) : HeapAlloc -> EAX=ptr
            _VXPRT_DISPOSE(EAX=ptr) : HeapFree
            _VXPRT_VARY_ASSIGN, _VXPRT_VARY_CONCAT,
              _VXPRT_VARY_LENGTH, _VXPRT_VARY_BODY,
              _VXPRT_VARY_SUBSTR, _VXPRT_VARY_CMP : runtime VARYING
            _VXPRT_PANIC(ESI=msg) : affiche message + ExitProcess(1)
            _VXPRT_CHKIDX(EAX=idx, EBX=lo, ECX=hi) : verif bornes
            Heap Win32 : GetProcessHeap + HeapAlloc / HeapFree
            Handles : hStdOut, hStdIn via GetStdHandle

  TODO 25 - GENERATION PE/COFF ET FICHIERS EXEMPLES
            Generation PE (.EXE Windows 32 bits) :
              DOS stub + signature PE + en-tete COFF + en-tete optionnel
              Sections : .text (code), .rdata (imports), .data (donnees)
              Table d imports : kernel32.dll (ExitProcess, GetStdHandle,
                WriteFile, ReadFile, GetProcessHeap, HeapAlloc,
                HeapFree, GetTickCount)
              Point d entree : _VXF_main ou _VXPL_MAINBODY
            Generation COFF (.OBJ) : option -obj
              En-tete COFF + sections .text/.data + table symboles
              Relocations pour les references externes
            Generation ASM (.ASM) : option -asm
              Fichier assembleur MASM lisible en plus du binaire
            EmitClose : finalisation du fichier de sortie
            Run : pipeline complet LexInit -> Parse -> Emit -> Binary
            Fichiers SAMPLES\VAXPASCAL\*.PAS existants :
              test_array.pas, test_arrays.pas, test_assert.pas,
              test_coerce.pas, test_const.pas, test_converge.pas,
              test_datetime.pas, test_except.pas, test_expr.pas,
              test_fileorg.pas, test_func.pas, test_funcproc.pas,
              test_if.pas, test_ifcase.pas, test_include.pas,
              test_io.pas, test_label.pas, test_lex.pas,
              test_loop.pas, test_loops.pas, test_module.pas,
              test_named.pas, test_percent.pas, test_pointer.pas,
              test_preproc.pas, test_procvar.pas, test_record.pas,
              test_records.pas, test_set.pas, test_smg.pas,
              test_static.pas, test_string.pas, test_typedecl.pas,
              test_types.pas, test_value.pas, test_var.pas,
              test_vardecl.pas, test_varying.pas, test_writeread.pas
            Smoke tests : VAXPCW32.EXE -v SAMPLES\VAXPASCAL\*.pas

  ============================================================ *)

Program VAXPCW32;

Begin
End.
