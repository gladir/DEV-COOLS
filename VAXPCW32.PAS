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

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
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

  TODO 02 - LEXEUR (TOKENS VAX PASCAL) [IMPLEMENTE]
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

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
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

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
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

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
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
  VXP_DATE    = '2026-03-09';

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
  STACK_SIZE    = 4096;  { taille pile Win32 }
  FRAME_WARN    = 512;   { seuil avertissement taille cadre (octets) }
  NEST_MAX      = 4;     { profondeur max imbrication proc/func }

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
  TY_IDX_SET       = 13;
  TY_PRIM_COUNT    = 14;
  TY_UNKNOWN       = -1;

  { Taille du File Descriptor Block (FDB) pour TEXT et FILE OF }
  FILE_DESC_SIZE   = 132;  { 4 handle + 4 mode + 128 filename (32 bits) }
  FDB_OFS_HANDLE   = 0;    { Offset du handle Win32 dans le FDB }
  FDB_OFS_MODE     = 4;    { Offset du mode (0=ferme,1=lect,2=ecrit) }
  FDB_OFS_NAME     = 8;    { Offset du buffer filename ASCIIZ }

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile      : TString;   { fichier source (.pas)                }
    OutFile      : TString;   { fichier de sortie (.exe/.obj/.asm)   }
    Verbose      : Boolean;   { -v : banniere et statistiques        }
    DebugMode    : Boolean;   { -d : affichage de chaque token       }
    Warnings     : Boolean;   { -w : activer les avertissements      }
    CheckEnabled : Boolean;   { $OPTIONS CHECK : runtime checks      }
    EmitExe      : Boolean;   { produire un .EXE PE (defaut)         }
    EmitObj      : Boolean;   { -obj : produire uniquement un .OBJ   }
    EmitAsm      : Boolean;   { -asm : produire un listing .ASM      }
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
  TDataKind = (DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC,
               DK_ARRAY_INIT, DK_SET);

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
    EK_EAX,
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
  ModuleIdent     : TString;
  EnvironmentName : TString;

  { Attributs pre-parses pour la prochaine declaration }
  PendAttrGlobal   : Boolean;
  PendAttrExternal : Boolean;

  { Table des EXTRN VMS auto-generes (eviter doublons) }
  VMSExternTab    : Array[0..255] Of TString;
  VMSExternCount  : Integer;
  SymInitCount    : Integer;

  { Gestion des exceptions }
  ExcNestLevel    : Integer;   { niveau d imbrication exception courant }
  ExcHandlerLabel : TString;   { label du handler EXCEPTION courant }
  ExcEndLabel     : TString;   { label de fin du bloc BEGIN..EXCEPTION..END }

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Declarations Forward --------------------------------- }
Procedure LexNextToken; Forward;
Procedure Run; Forward;
Procedure LexNextLine; Forward;
Procedure IncludePop; Forward;
Procedure LexHandleDollarDirective; Forward;
Function  LexHandlePercentDirective : Boolean; Forward;
{ Forward declarations TODO 03 }
Procedure EmitDataSeg; Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitHeader; Forward;
Procedure EmitProlog(FrameSize : Integer); Forward;
Procedure EmitEpilog(ParamBytes : Integer); Forward;
{ Forward declarations TODO 04 }
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer;
                      Var R : TExprVal); Forward;
Procedure ExprFlushToEAX(Var E : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer;
                        Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Forward declarations TODO 05 }
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
                TIdx : Integer) : Integer; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Forward declarations TODO 07 }
Procedure EmitOpen; Forward;
Procedure EmitFooter; Forward;
Procedure EmitClose; Forward;
{ Forward declarations TODO 06 }
Procedure TypeInit; Forward;
Function  TypeSizeof(TIdx : Integer) : Integer; Forward;
Function  TypeCompatible(T1, T2 : Integer) : Boolean; Forward;
Function  TypeCoerce(SrcType, DstType : Integer) : Integer; Forward;
Function  TypeResolve(Const Name : TString) : Integer; Forward;
Function  TypeIsOrdinal(TIdx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(TIdx : Integer) : Boolean; Forward;
Function  TypeIsPointer(TIdx : Integer) : Boolean; Forward;
Function  IsSetTypeIdx(TIdx : Integer) : Boolean; Forward;
Procedure EmitCoerce(SrcType, DstType : Integer); Forward;
{ Forward declarations TODO 08 }
Procedure ParseVarDecl; Forward;
Procedure ParseConstDecl; Forward;
Procedure ParseVarAttributes(
  Var AExternal, AGlobal, AVolatile,
      AReadOnly, AWriteOnly, AWord, AUnsafe,
      AHidden, AUnbound : Boolean;
  Var AAlignVal, APosVal : Integer); Forward;
Procedure ParseDeclAttributes; Forward;
{ Forward declarations TODO 09 }
Procedure ParseAssignment(Const VarName : TString); Forward;
Procedure ParseValueSection; Forward;
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;

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

{ Retourne '[EBP+n]' ou '[EBP-n]' selon le signe }
Function EBPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    EBPOfs := '[EBP+' + IntToStr(Ofs) + ']'
  Else
    EBPOfs := '[EBP' + IntToStr(Ofs) + ']';
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

{ Extrait le nom de base d un chemin (sans extension) }
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

{ Retourne l extension d un chemin (avec le point) }
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
  WriteLn('VAXPCW32: FATAL: ', Msg);
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
  WriteLn('VAXPCW32: warning: ', Msg);
  Inc(WarnCount);
End;

Procedure ErrorMsg(Const Msg : TString);
Begin
  WriteLn('VAXPCW32: erreur ligne ', LexLineNo, ' : ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs (' + IntToStr(MAX_ERRORS) + '), arret');
End;

{ ---- Expect : verifier et consommer un token attendu ---------- }
Procedure Expect(Const ExpKind : TTokenKind; Const ExpVal : TString);
Begin
  If (CurToken.Kind = ExpKind) And
     (StrLowerCase(CurToken.Val) = StrLowerCase(ExpVal)) Then
    LexNextToken
  Else
    ErrorMsg('''' + ExpVal + ''' attendu, trouve ''' + CurToken.Val + '''');
End;

{ ---- SkipTo : synchroniser apres une erreur de syntaxe -------- }
Procedure SkipTo(Const StopVal : TString);
Var
  SL : TString;
Begin
  SL := StrLowerCase(StopVal);
  While (CurToken.Kind <> TK_EOF) And
        (StrLowerCase(CurToken.Val) <> SL) Do
    LexNextToken;
  If StrLowerCase(CurToken.Val) = SL Then
    LexNextToken;
End;

{ ============================================================
  BANNIERE ET USAGE
  ============================================================ }

Procedure ShowBanner;
Begin
  WriteLn('VAXPCW32 v', VXP_VERSION, ' (', VXP_DATE, ')');
  WriteLn('Compilateur VAX Pascal -> assembleur 80386 / Win32');
  WriteLn('Free Pascal (-Mtp)  Cible: MASM .386 .MODEL FLAT');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('VAXPCW32 - Cette commande permet de lancer le compilateur de ',
          'VAX Pascal pour l''assembleur du microprocesseur 80386 ',
          '(en executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : VAXPCW32 <source.pas> [-o sortie] [-v] [-d] [-w] [-obj] [-asm]');
  WriteLn;
  WriteLn('  source.pas : fichier VAX Pascal source');
  WriteLn('  -o nom     : specifier le nom du fichier de sortie');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -obj       : produire uniquement un .OBJ (format COFF 32 bits)');
  WriteLn('  -asm       : produire egalement un listing assembleur .ASM');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  WriteLn('Par defaut, VAXPCW32 produit un fichier .EXE (PE Windows 32 bits).');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  ShowUsage;
End;

{ ============================================================
  OPTIONS ET ARGUMENTS
  ============================================================ }

Procedure InitOptions;
Begin
  Opts.SrcFile      := '';
  Opts.OutFile      := '';
  Opts.Verbose      := False;
  Opts.DebugMode    := False;
  Opts.Warnings     := False;
  Opts.CheckEnabled := False;
  Opts.EmitExe      := True;    { par defaut : produire un .EXE }
  Opts.EmitObj      := False;
  Opts.EmitAsm      := False;
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
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-o' Then
    Begin
      If I < ParamCount Then
      Begin
        Inc(I);
        Opts.OutFile := ParamStr(I);
      End
      Else
      Begin
        WriteLn('VAXPCW32: -o requiert un nom de fichier');
        ShowUsage;
      End;
    End
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('VAXPCW32: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('VAXPCW32: argument inattendu: ', Arg);
      ShowUsage;
    End;

    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('VAXPCW32: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .pas }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.pas') Then
    WarnMsg('extension attendue .pas, trouvee: ' + Ext);

  { Fichier de sortie par defaut selon le mode }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
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
  ModuleIdent   := '';
  EnvironmentName := '';
  PendAttrGlobal   := False;
  PendAttrExternal := False;
  VMSExternCount   := 0;
  SymInitCount     := 0;
  ExcNestLevel     := 0;
  ExcHandlerLabel  := '';
  ExcEndLabel      := '';
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS VAX PASCAL) [IMPLEMENTE]
  ============================================================ }

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
    (L = 'signal_stop') Or
    (L = 'anyother')   Or (L = 'allconditions') Or
    (L = 'double')     Or (L = 'unsigned')  Or (L = 'single')    Or
    (L = 'writev')     Or (L = 'readv')  Or (L = 'putstring') Or
    (L = 'getstring')  Or (L = 'next')  Or (L = 'initialize') Or
    (L = 'finalize')   Or (L = 'inherit');
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
Var
  FN  : TString;
  FI  : Integer;
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
  {$IFDEF UNIX}
  FN := FileName;
  For FI := 1 To Length(FN) Do
    If FN[FI] = '\' Then FN[FI] := '/';
  {$I-}
  Assign(LexSrcF, FN);
  {$ELSE}
  {$I-}
  Assign(LexSrcF, FileName);
  {$ENDIF}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('impossible d''ouvrir le fichier include: ' + FileName);
    {$I-}
    Assign(LexSrcF, IncSavedFName[IncTop]);
    Reset(LexSrcF);
    {$I+}
    If IOResult <> 0 Then
    Begin
      Dec(IncTop);
      LexEOF := True;
      Exit;
    End;
    { Skip to the saved line position to avoid re-reading from start }
    {$I-}
    For FI := 1 To IncSavedFLine[IncTop] Do
    Begin
      If EOF(LexSrcF) Then Break;
      ReadLn(LexSrcF, FN);
    End;
    {$I+}
    LexSrcFName := IncSavedFName[IncTop];
    LexLine     := IncSavedLine[IncTop];
    LexLineNo   := IncSavedLineNo[IncTop];
    LexColNo    := IncSavedColNo[IncTop];
    LexEOF      := IncSavedEOF[IncTop];
    Dec(IncTop);
    Exit;
  End;
  {$IFDEF UNIX}
  LexSrcFName := FN;
  {$ELSE}
  LexSrcFName := FileName;
  {$ENDIF}
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
    If FltVal > 2147483647.0 Then N := 2147483647
    Else If FltVal < -2147483648.0 Then N := -2147483648
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
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := VXP_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- NewLabel : generer un label unique (alias) -------------- }
Function NewLabel : TString;
Begin
  NewLabel := LabelGen;
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

{ ---- EmitLabel : label ASM suivi de ':' en colonne 0 --------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

{ ---- EmitInstr : instruction sans operande ------------------- }
Procedure EmitInstr(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

{ ---- EmitInstrA : instruction avec un operande --------------- }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1);
End;

{ ---- EmitInstrAB : instruction avec deux operandes ----------- }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1 + ', ' + A2);
End;

{ ---- EmitPush : instruction PUSH ----------------------------- }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : instruction POP ------------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : instruction MOV ------------------------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitCall : instruction CALL ----------------------------- }
Procedure EmitCall(Const Target : TString);
Begin
  EmitInstrA('CALL', Target);
End;

{ ---- EmitJmp : instruction JMP ------------------------------- }
Procedure EmitJmp(Const Target : TString);
Begin
  EmitInstrA('JMP', Target);
End;

{ ---- EmitJmpCond : saut conditionnel (JE, JNE, JL, ...) ----- }
Procedure EmitJmpCond(Const Cond, Target : TString);
Begin
  EmitInstrA(Cond, Target);
End;

{ ---- EmitProlog : prologue de procedure/fonction 32 bits ----- }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitPush('EBP');
  EmitInstrAB('MOV', 'EBP', 'ESP');
  If FrameSize > 0 Then
  Begin
    EmitInstrAB('SUB', 'ESP', IntToStr(FrameSize));
    If (FrameSize > FRAME_WARN) And Opts.Warnings Then
      WarnMsg('cadre de pile volumineux : ' + IntToStr(FrameSize) +
              ' octets');
  End;
  EmitPush('ESI');
  EmitPush('EDI');
End;

{ ---- EmitEpilog : epilogue de procedure/fonction 32 bits ----- }
Procedure EmitEpilog(ParamBytes : Integer);
Begin
  EmitPop('EDI');
  EmitPop('ESI');
  EmitInstrAB('MOV', 'ESP', 'EBP');
  EmitPop('EBP');
  If ParamBytes > 0 Then
    EmitInstrA('RET', IntToStr(ParamBytes))
  Else
    EmitInstr('RET');
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

{ ---- DataAddDWord : ajouter un double-mot 32 bits dans DataTab }
Function DataAddDWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, AIntVal, '');
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

{ ---- EmitDataSeg : emettre le segment _DATA complet (32 bits) }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  Sz   : Integer;
  IsFirst : Boolean;
Begin
  EmitRaw('_DATA   SEGMENT DWORD PUBLIC ''DATA''');

  { --- Buffers internes du runtime 32 bits --- }
  EmitComment('--- Buffers internes ---');
  EmitRaw(VXP_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(VXP_RT_PFX + 'STRBUF  DB  512 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'CHRBUF  DB  2 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'NUMBUF  DB  16 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(VXP_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  EmitRaw(VXP_RT_PFX + 'HEAP    DB  4096 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'HEAPTOP DD  OFFSET ' + VXP_RT_PFX + 'HEAP');
  EmitRaw(VXP_RT_PFX + 'SEED    DD  1');
  EmitRaw(VXP_RT_PFX + 'SETBUF  DB  32 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'DATEBUF DB  16 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'TIMEBUF DB  12 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'ASSERTMSG DB ''Assertion failed'',0');
  { Handle stdout Win32 et buffer d ecriture }
  EmitRaw(VXP_RT_PFX + 'HSTDOUT DD  0');
  EmitRaw(VXP_RT_PFX + 'HSTDIN  DD  0');
  EmitRaw(VXP_RT_PFX + 'WRITTEN DD  0');
  EmitBlankLine;

  { --- FDB fichiers predefinis (32 bits : DD handle, DD mode) --- }
  EmitComment('--- File Descriptor Blocks predefinis ---');
  { Input : handle obtenu via GetStdHandle, mode=1 (lecture) }
  EmitRaw(VXP_VAR_PFX + 'INPUT   DD  0');
  EmitRaw('        DD  1');
  EmitRaw('        DB  ''CON'',0');
  EmitRaw('        DB  120 DUP(0)');
  { Output : handle obtenu via GetStdHandle, mode=2 (ecriture) }
  EmitRaw(VXP_VAR_PFX + 'OUTPUT  DD  0');
  EmitRaw('        DD  2');
  EmitRaw('        DB  ''CON'',0');
  EmitRaw('        DB  120 DUP(0)');
  { TTY : handle=0 (stdin), mode=1 (lecture) }
  EmitRaw(VXP_VAR_PFX + 'TTY     DD  0');
  EmitRaw('        DD  1');
  EmitRaw('        DB  ''CON'',0');
  EmitRaw('        DB  120 DUP(0)');
  { TTYOUTPUT : handle=0 (stdout), mode=2 (ecriture) }
  EmitRaw(VXP_VAR_PFX + 'TTYOUTPUT DD  0');
  EmitRaw('        DD  2');
  EmitRaw('        DB  ''CON'',0');
  EmitRaw('        DB  120 DUP(0)');
  { Error : handle=0 (stderr), mode=2 (ecriture) }
  EmitRaw(VXP_VAR_PFX + 'ERROR   DD  0');
  EmitRaw('        DD  2');
  EmitRaw('        DB  ''CON'',0');
  EmitRaw('        DB  120 DUP(0)');
  { Buffer handle courant pour Write/Read avec fichier }
  EmitRaw(VXP_RT_PFX + 'CURHDL  DD  0');
  EmitRaw(VXP_RT_PFX + 'IOSTATUS DD  0');
  EmitRaw(VXP_RT_PFX + 'FNAMEBUF DB  128 DUP(0)');
  EmitRaw(VXP_RT_PFX + 'FRDCBUF DB  2 DUP(0)');
  EmitBlankLine;

  { --- Exception frame et messages d erreur --- }
  EmitComment('--- Exception handler frame ---');
  EmitRaw(VXP_RT_PFX + 'EXCHDL  DD  0');      { adresse du handler courant }
  EmitRaw(VXP_RT_PFX + 'EXCSP   DD  0');      { ESP sauvegarde }
  EmitRaw(VXP_RT_PFX + 'EXCBP   DD  0');      { EBP sauvegarde }
  EmitRaw(VXP_RT_PFX + 'EXCCODE DD  0');      { code de la condition }
  EmitRaw(VXP_RT_PFX + 'EXCVAL  DD  0');      { valeur de la condition }
  EmitRaw(VXP_RT_PFX + 'EXCPHDL DD  0');      { handler parent (chaine) }
  EmitRaw(VXP_RT_PFX + 'EXCPSP  DD  0');      { ESP parent }
  EmitRaw(VXP_RT_PFX + 'EXCPBP  DD  0');      { EBP parent }
  EmitComment('--- Messages d erreur runtime ---');
  EmitRaw(VXP_RT_PFX + 'DIV0MSG DB  ''Runtime error: Division by zero'',0');
  EmitRaw(VXP_RT_PFX + 'OVFMSG  DB  ''Runtime error: Integer overflow'',0');
  EmitRaw(VXP_RT_PFX + 'RNGMSG  DB  ''Runtime error: Range check error'',0');
  EmitRaw(VXP_RT_PFX + 'NILMSG  DB  ''Runtime error: Nil pointer dereference'',0');
  EmitRaw(VXP_RT_PFX + 'SIGMSG  DB  ''Runtime error: Unhandled condition'',0');
  EmitBlankLine;

  { --- Entrees dynamiques de DataTab --- }
  If DataCount > 0 Then
    EmitComment('--- Donnees du programme ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_DWORD :
        If DataTab[I].StrVal <> '' Then
          EmitRaw(DataTab[I].LblName + '  DD  OFFSET ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + '  DD  ' +
                  IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Emettre la chaine, en decoupant aux retours a la ligne }
          S := '';
          IsFirst := True;
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If (DataTab[I].StrVal[J] = #13) Or
               (DataTab[I].StrVal[J] = #10) Then
            Begin
              If Length(S) > 0 Then
              Begin
                If IsFirst Then
                Begin EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''''); IsFirst := False; End
                Else EmitRaw('  DB  ''' + S + '''');
                S := '';
              End;
              If IsFirst Then
              Begin EmitRaw(DataTab[I].LblName + '  DB  ' + IntToStr(Ord(DataTab[I].StrVal[J]))); IsFirst := False; End
              Else EmitRaw('  DB  ' + IntToStr(Ord(DataTab[I].StrVal[J])));
            End
            Else If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          { Vider le restant + null terminator }
          If Length(S) > 0 Then
          Begin
            If IsFirst Then
              EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0')
            Else
              EmitRaw('  DB  ''' + S + ''',0');
          End
          Else
          Begin
            If IsFirst Then
              EmitRaw(DataTab[I].LblName + '  DB  0')
            Else
              EmitRaw('  DB  0');
          End;
        End;
      DK_ARRAY :
        Begin
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else If Sz = 4 Then
            EmitRaw(DataTab[I].LblName + '  DD  ' +
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
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' + DataTab[I].StrVal)
          Else
            EmitRaw(DataTab[I].LblName + '  DD  ' + DataTab[I].StrVal);
        End;
      DK_SET :
        EmitRaw(DataTab[I].LblName + '  DB  32 DUP(0)');
    End;
  End;

  EmitRaw('_DATA   ENDS');
End;

{ ---- LitEval : evaluer un token litteral en TExprVal --------- }
{ Gere : TK_INTEGER, TK_OCTAL, TK_REAL (tronque+warn),          }
{        TK_STRING, TK_CHAR, TK_KEYWORD (true/false/nil/maxint). }
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
      Res.Kind    := EK_EAX;
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
        Res.Kind    := EK_EAX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := DataCount - 1;
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
        Res.ImmVal  := 2147483647;
        Res.TypeIdx := TY_IDX_INTEGER;
      End;
    End;
  Else
    Res.Kind := EK_NONE;
  End;
End;

{ ---- EmitHeader : en-tete ASM Win32 FLAT --------------------- }
Procedure EmitHeader;
Begin
  EmitComment('========================================');
  EmitComment('Genere par VAXPCW32 v' + VXP_VERSION +
              ' (' + VXP_DATE + ')');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitComment('Cible  : Win32 / 80386 / PE');
  EmitComment('========================================');
  EmitBlankLine;
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitRaw('OPTION CASEMAP:NONE');
  EmitBlankLine;
  EmitComment('--- Declarations externes Win32 ---');
  EmitRaw('EXTRN   _ExitProcess@4       : PROC');
  EmitRaw('EXTRN   _GetStdHandle@4      : PROC');
  EmitRaw('EXTRN   _WriteFile@20        : PROC');
  EmitRaw('EXTRN   _ReadFile@20         : PROC');
  EmitRaw('EXTRN   _GetProcessHeap@0    : PROC');
  EmitRaw('EXTRN   _HeapAlloc@12        : PROC');
  EmitRaw('EXTRN   _HeapFree@12         : PROC');
  EmitRaw('EXTRN   _GetTickCount@0      : PROC');
  EmitBlankLine;
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitComment('--- Segment de code ---');
  EmitRaw('_TEXT   SEGMENT DWORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT');
  EmitBlankLine;
  EmitComment('--- Point d entree principal ---');
  EmitLabel(VXP_FN_PFX + 'MAIN');
  EmitComment('Obtenir le handle stdout');
  EmitInstrA('PUSH', '-11');
  EmitInstrA('CALL', '_GetStdHandle@4');
  EmitInstrAB('MOV', 'DWORD PTR [' + VXP_RT_PFX + 'HSTDOUT]', 'EAX');
  EmitComment('Obtenir le handle stdin');
  EmitInstrA('PUSH', '-10');
  EmitInstrA('CALL', '_GetStdHandle@4');
  EmitInstrAB('MOV', 'DWORD PTR [' + VXP_RT_PFX + 'HSTDIN]', 'EAX');
  EmitBlankLine;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

(* ---- OpPrec : priorite d un operateur binaire --------------- *)
(* VAX Pascal utilise 7 niveaux de priorite :                     *)
(*   1 : OR, ORIF, XOR                                           *)
(*   2 : AND, ANDIF                                               *)
(*   3 : (NOT unaire, gere dans ParseUnary)                       *)
(*   4 : =, <>, <, >, <=, >=, IN                                  *)
(*   5 : +, -, || (concatenation)                                  *)
(*   6 : *, /, DIV, MOD, SHL, SHR                                 *)
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

(* ---- ExprFlushToEAX : materialiser une expression dans EAX --- *)
(* Si deja EAX, ne rien faire. Si immediate, MOV EAX, imm.        *)
(* Si memoire, charger depuis variable locale ou globale (32 bits).*)
Procedure ExprFlushToEAX(Var E : TExprVal);
Var
  SIdx : Integer;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'EAX', 'EAX')
      Else
        EmitInstrAB('MOV', 'EAX', IntToStr(E.ImmVal));
      E.Kind := EK_EAX;
    End;
    EK_EAX :
      ; (* deja dans EAX *)
    EK_MEM :
    Begin
      SIdx := E.SymIdx;
      If (SIdx >= 0) And (SIdx < SymCount) Then
      Begin
        If SymTab[SIdx].IsLocal Then
        Begin
          (* Variable locale : MOV EAX, [EBP-n] *)
          If SymTab[SIdx].Cat = SC_VARPARAM Then
          Begin
            (* Parametre var (reference) : MOV EBX,[EBP+n] / MOV EAX,[EBX] *)
            EmitInstrAB('MOV', 'EBX',
              'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
            EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
          End
          Else
          Begin
            EmitInstrAB('MOV', 'EAX',
              'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
          End;
        End
        Else
        Begin
          (* Variable globale : MOV EAX, [_VXP_xxx] *)
          EmitInstrAB('MOV', 'EAX',
            'DWORD PTR [' + SymTab[SIdx].MangledName + ']');
        End;
      End
      Else
      Begin
        (* Symbole inconnu : XOR EAX,EAX par defaut *)
        EmitInstrAB('XOR', 'EAX', 'EAX');
      End;
      E.Kind := EK_EAX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'EAX', 'EAX');
      E.Kind := EK_EAX;
    End;
  End;
End;

(* ---- ParsePrimary : token primaire -> TExprVal --------------- *)
(* Gere : litteraux (entier, reel, chaine, char, octal,            *)
(*        true/false/nil/maxint),                                   *)
(*        sous-expression parenthesee (expr),                      *)
(*        identificateurs (stub pour futurs TODOs).                 *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  IdName    : TString;
  SIdx2     : Integer;
  FTIdx2    : Integer;
  FI2       : Integer;
  FIdx2     : Integer;
  WI2       : Integer;
  WIdx2     : Integer;
  RecTI2    : Integer;
  FldI2     : Integer;
  ESize2    : Integer;
  ArgCount2 : Integer;
  SubEv     : TExprVal;
  Lw2       : TString;
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
      (* Emettre LEA EAX, label de la chaine *)
      If (Res.SymIdx >= 0) And (Res.SymIdx < DataCount) Then
        EmitInstrAB('LEA', 'EAX', DataTab[Res.SymIdx].LblName)
      Else If DataCount > 0 Then
        EmitInstrAB('LEA', 'EAX', DataTab[DataCount - 1].LblName);
      Res.Kind := EK_EAX;
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
      Else
      Begin
        WarnMsg('mot-cle inattendu dans expression: ' + CurToken.Val);
        LexNextToken;
      End;
    End;

    (* --- Identificateurs : acces variables, constantes, fonctions --- *)
    TK_IDENT :
    Begin
      IdName := CurToken.Val;
      Lw2 := StrLowerCase(IdName);
      LexNextToken;

        (* --- Built-in functions --- *)
        If (Lw2 = 'ord') Or (Lw2 = 'chr') Or (Lw2 = 'abs') Or
           (Lw2 = 'odd') Or (Lw2 = 'succ') Or (Lw2 = 'pred') Or
           (Lw2 = 'length') Or (Lw2 = 'sizeof') Or (Lw2 = 'size') Or
           (Lw2 = 'address') Or (Lw2 = 'iaddress') Or
           (Lw2 = 'trunc') Or (Lw2 = 'round') Or (Lw2 = 'sqr') Then
        Begin
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            LexNextToken;
            ParseExpr(SubEv);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              LexNextToken;
          End
          Else
            ParsePrimary(SubEv);

          If Lw2 = 'ord' Then
          Begin
            ExprFlushToEAX(SubEv);
            EmitInstrAB('MOVZX', 'EAX', 'AL');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_INTEGER;
          End
          Else If Lw2 = 'chr' Then
          Begin
            ExprFlushToEAX(SubEv);
            EmitInstrAB('AND', 'EAX', '255');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_CHAR;
          End
          Else If Lw2 = 'abs' Then
          Begin
            If SubEv.Kind = EK_IMM Then
            Begin
              If SubEv.ImmVal < 0 Then
                SubEv.ImmVal := -SubEv.ImmVal;
              Res := SubEv;
            End
            Else
            Begin
              ExprFlushToEAX(SubEv);
              EmitInstrAB('TEST', 'EAX', 'EAX');
              EmitInstr('JNS    $+4');
              EmitInstr('NEG    EAX');
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SubEv.TypeIdx;
            End;
          End
          Else If Lw2 = 'odd' Then
          Begin
            ExprFlushToEAX(SubEv);
            EmitInstrAB('AND', 'EAX', '1');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_BOOLEAN;
          End
          Else If Lw2 = 'succ' Then
          Begin
            If SubEv.Kind = EK_IMM Then
            Begin
              Inc(SubEv.ImmVal);
              Res := SubEv;
            End
            Else
            Begin
              ExprFlushToEAX(SubEv);
              EmitInstr('INC    EAX');
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SubEv.TypeIdx;
            End;
          End
          Else If Lw2 = 'pred' Then
          Begin
            If SubEv.Kind = EK_IMM Then
            Begin
              Dec(SubEv.ImmVal);
              Res := SubEv;
            End
            Else
            Begin
              ExprFlushToEAX(SubEv);
              EmitInstr('DEC    EAX');
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SubEv.TypeIdx;
            End;
          End
          Else If Lw2 = 'sqr' Then
          Begin
            ExprFlushToEAX(SubEv);
            EmitInstrAB('IMUL', 'EAX', 'EAX');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := SubEv.TypeIdx;
          End
          Else If Lw2 = 'length' Then
          Begin
            ExprFlushToEAX(SubEv);
            EmitInstrA('CALL', VXP_RT_PFX + 'STRLEN');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_INTEGER;
          End
          Else If (Lw2 = 'sizeof') Or (Lw2 = 'size') Then
          Begin
            If (SubEv.SymIdx >= 0) And (SubEv.SymIdx < SymCount) Then
              ExprMakeImm(TypeSizeof(SymTab[SubEv.SymIdx].TypeIdx),
                TY_IDX_INTEGER, Res)
            Else
              ExprMakeImm(4, TY_IDX_INTEGER, Res);
          End
          Else If (Lw2 = 'address') Or (Lw2 = 'iaddress') Then
          Begin
            If (SubEv.SymIdx >= 0) And (SubEv.SymIdx < SymCount) Then
            Begin
              If SymTab[SubEv.SymIdx].IsLocal Then
                EmitInstrAB('LEA', 'EAX',
                  EBPOfs(SymTab[SubEv.SymIdx].Offset))
              Else
                EmitInstrAB('LEA', 'EAX',
                  '[' + SymTab[SubEv.SymIdx].MangledName + ']');
            End
            Else
              EmitInstrAB('XOR', 'EAX', 'EAX');
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_POINTER;
          End
          Else
          Begin
            (* trunc, round : identity for integer *)
            ExprFlushToEAX(SubEv);
            Res.Kind    := EK_EAX;
            Res.TypeIdx := TY_IDX_INTEGER;
          End;
        End  (* built-in functions *)

        Else
        Begin
          (* --- Symbol lookup --- *)
          SIdx2 := SymFind(IdName);

          (* --- WITH context : unqualified field resolution --- *)
          If (SIdx2 < 0) And (WithTop >= 0) Then
          Begin
            WIdx2 := -1;
            FldI2 := -1;
            For WI2 := WithTop DownTo 0 Do
            Begin
              RecTI2 := SymTab[WithSymIdx[WI2]].TypeIdx;
              If (RecTI2 >= 0) And (RecTI2 < TypeCount) And
                 (TypeTab[RecTI2].Kind = TKP_RECORD) Then
              Begin
                For FI2 := 0 To TypeTab[RecTI2].FieldCount - 1 Do
                  If StrLowerCase(TypeTab[RecTI2].Fields[FI2].Name) =
                     Lw2 Then
                  Begin
                    WIdx2 := WI2;
                    FldI2 := FI2;
                    Break;
                  End;
              End;
              If WIdx2 >= 0 Then Break;
            End;
            If (WIdx2 >= 0) And (FldI2 >= 0) Then
            Begin
              RecTI2 := SymTab[WithSymIdx[WIdx2]].TypeIdx;
              EmitComment('with field ' + IdName);
              If SymTab[WithSymIdx[WIdx2]].IsLocal Then
                EmitInstrAB('LEA', 'EBX',
                  EBPOfs(SymTab[WithSymIdx[WIdx2]].Offset))
              Else
                EmitInstrAB('MOV', 'EBX',
                  'OFFSET ' + SymTab[WithSymIdx[WIdx2]].MangledName);
              If TypeTab[RecTI2].Fields[FldI2].Offset > 0 Then
                EmitInstrAB('ADD', 'EBX',
                  IntToStr(TypeTab[RecTI2].Fields[FldI2].Offset));
              FTIdx2 := TypeTab[RecTI2].Fields[FldI2].TypeIdx;
              If TypeSizeof(FTIdx2) = 1 Then
              Begin
                EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]');
              End
              Else
                EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
              Res.Kind    := EK_EAX;
              Res.TypeIdx := FTIdx2;
              Res.SymIdx  := -1;
            End
            Else
            Begin
              WarnMsg('identificateur non declare: ' + IdName);
              Res.Kind := EK_NONE;
            End;
          End  (* WITH resolution *)

          (* --- Type cast : TypeName(expr) --- *)
          Else If (SIdx2 >= 0) And (SymTab[SIdx2].Cat = SC_TYPE) Then
          Begin
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              LexNextToken;
              ParseExpr(SubEv);
              ExprFlushToEAX(SubEv);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                LexNextToken;
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SymTab[SIdx2].TypeIdx;
              Res.SymIdx  := -1;
            End
            Else
            Begin
              (* bare type name -> its size *)
              ExprMakeImm(TypeSizeof(SymTab[SIdx2].TypeIdx),
                TY_IDX_INTEGER, Res);
            End;
          End

          Else If SIdx2 < 0 Then
          Begin
            WarnMsg('identificateur non declare: ' + IdName);
            Res.Kind := EK_NONE;
          End

          (* --- SC_CONST: immediate value --- *)
          Else If SymTab[SIdx2].Cat = SC_CONST Then
          Begin
            ExprMakeImm(SymTab[SIdx2].ImmVal,
              SymTab[SIdx2].TypeIdx, Res);
            Res.SymIdx := SIdx2;
          End

          (* --- SC_ENUM_VAL: enumeration value --- *)
          Else If SymTab[SIdx2].Cat = SC_ENUM_VAL Then
          Begin
            ExprMakeImm(SymTab[SIdx2].ImmVal,
              SymTab[SIdx2].TypeIdx, Res);
            Res.SymIdx := SIdx2;
          End

          (* --- SC_FUNC: function call or function result variable --- *)
          Else If SymTab[SIdx2].Cat = SC_FUNC Then
          Begin
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              EmitComment('call func ' + IdName);
              LexNextToken;
              (* Push arguments *)
              ArgCount2 := 0;
              If Not ((CurToken.Kind = TK_PUNCT) And
                      (CurToken.Val = ')')) Then
              Begin
                Repeat
                  ParseExpr(SubEv);
                  ExprFlushToEAX(SubEv);
                  EmitPush('EAX');
                  Inc(ArgCount2);
                  If (CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ',') Then
                    LexNextToken
                  Else
                    Break;
                Until False;
              End;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                LexNextToken;
              EmitInstrA('CALL', SymTab[SIdx2].MangledName);
              If ArgCount2 > 0 Then
                EmitInstrAB('ADD', 'ESP', IntToStr(ArgCount2 * 4));
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SymTab[SIdx2].TypeIdx;
              Res.SymIdx  := SIdx2;
            End
            Else
            Begin
              (* bare function name = result variable *)
              EmitInstrAB('MOV', 'EAX',
                'DWORD PTR ' + EBPOfs(CurFuncRetOfs));
              Res.Kind    := EK_EAX;
              Res.TypeIdx := SymTab[SIdx2].TypeIdx;
              Res.SymIdx  := SIdx2;
            End;
          End

          (* --- SC_PROC: procedure call (result ignored or in EAX) --- *)
          Else If SymTab[SIdx2].Cat = SC_PROC Then
          Begin
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              EmitComment('call proc ' + IdName);
              LexNextToken;
              ArgCount2 := 0;
              If Not ((CurToken.Kind = TK_PUNCT) And
                      (CurToken.Val = ')')) Then
              Begin
                Repeat
                  ParseExpr(SubEv);
                  ExprFlushToEAX(SubEv);
                  EmitPush('EAX');
                  Inc(ArgCount2);
                  If (CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ',') Then
                    LexNextToken
                  Else
                    Break;
                Until False;
              End;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                LexNextToken;
              EmitInstrA('CALL', SymTab[SIdx2].MangledName);
              If ArgCount2 > 0 Then
                EmitInstrAB('ADD', 'ESP', IntToStr(ArgCount2 * 4));
              Res.Kind    := EK_EAX;
              Res.TypeIdx := TY_IDX_INTEGER;
              Res.SymIdx  := SIdx2;
            End
            Else
            Begin
              (* bare procedure name as value = address *)
              EmitInstrAB('MOV', 'EAX',
                'OFFSET ' + SymTab[SIdx2].MangledName);
              Res.Kind    := EK_EAX;
              Res.TypeIdx := TY_IDX_POINTER;
              Res.SymIdx  := SIdx2;
            End;
          End

          (* --- SC_CONDITION: condition value --- *)
          Else If SymTab[SIdx2].Cat = SC_CONDITION Then
          Begin
            ExprMakeImm(SymTab[SIdx2].Offset, TY_IDX_INTEGER, Res);
            Res.SymIdx := SIdx2;
          End

          (* --- Variable access (SC_VAR, SC_TYPED_CONST, etc.) --- *)
          Else
          Begin
            Res.SymIdx  := SIdx2;
            Res.TypeIdx := SymTab[SIdx2].TypeIdx;

            (* Handle pointer dereference: ident^ *)
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
            Begin
              LexNextToken;
              EmitComment('deref ' + IdName + '^');
              If SymTab[SIdx2].IsLocal Then
              Begin
                If SymTab[SIdx2].Cat = SC_VARPARAM Then
                Begin
                  EmitInstrAB('MOV', 'EBX',
                    'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
                  EmitInstrAB('MOV', 'EBX', 'DWORD PTR [EBX]');
                End
                Else
                  EmitInstrAB('MOV', 'EBX',
                    'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
              End
              Else
                EmitInstrAB('MOV', 'EBX',
                  'DWORD PTR [' + SymTab[SIdx2].MangledName + ']');
              If Opts.CheckEnabled Then
              Begin
                EmitInstrAB('TEST', 'EBX', 'EBX');
                EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_NIL');
              End;

              (* p^.field *)
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
              Begin
                LexNextToken;
                FTIdx2 := SymTab[SIdx2].TypeIdx;
                If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                   (TypeTab[FTIdx2].Kind = TKP_POINTER) Then
                  FTIdx2 := TypeTab[FTIdx2].BaseTypeIdx;
                FIdx2 := -1;
                If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                   (TypeTab[FTIdx2].Kind = TKP_RECORD) And
                   (CurToken.Kind = TK_IDENT) Then
                Begin
                  For FI2 := 0 To TypeTab[FTIdx2].FieldCount - 1 Do
                    If StrLowerCase(TypeTab[FTIdx2].Fields[FI2].Name) =
                       StrLowerCase(CurToken.Val) Then
                    Begin
                      FIdx2 := FI2;
                      Break;
                    End;
                  LexNextToken;
                End;
                If FIdx2 >= 0 Then
                Begin
                  If TypeTab[FTIdx2].Fields[FIdx2].Offset > 0 Then
                    EmitInstrAB('ADD', 'EBX',
                      IntToStr(TypeTab[FTIdx2].Fields[FIdx2].Offset));
                  Res.TypeIdx := TypeTab[FTIdx2].Fields[FIdx2].TypeIdx;
                  If TypeSizeof(Res.TypeIdx) = 1 Then
                    EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]')
                  Else
                    EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                End
                Else
                Begin
                  EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                  FTIdx2 := SymTab[SIdx2].TypeIdx;
                  If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                     (TypeTab[FTIdx2].Kind = TKP_POINTER) Then
                    Res.TypeIdx := TypeTab[FTIdx2].BaseTypeIdx;
                End;
              End
              (* p^[i] *)
              Else If IsOpenBracket Then
              Begin
                LexNextToken;
                ParseExpr(SubEv);
                ExprFlushToEAX(SubEv);
                EmitInstrAB('SHL', 'EAX', '2');
                EmitInstrAB('ADD', 'EBX', 'EAX');
                If IsCloseBracket Then LexNextToken;
                EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                FTIdx2 := SymTab[SIdx2].TypeIdx;
                If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                   (TypeTab[FTIdx2].Kind = TKP_POINTER) Then
                  Res.TypeIdx := TypeTab[FTIdx2].BaseTypeIdx;
              End
              Else
              Begin
                (* simple p^ *)
                EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                FTIdx2 := SymTab[SIdx2].TypeIdx;
                If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                   (TypeTab[FTIdx2].Kind = TKP_POINTER) Then
                  Res.TypeIdx := TypeTab[FTIdx2].BaseTypeIdx;
              End;
              Res.Kind   := EK_EAX;
              Res.SymIdx := -1;
            End  (* pointer dereference *)

            (* Handle record field access: ident.field *)
            Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
            Begin
              LexNextToken;
              FTIdx2 := SymTab[SIdx2].TypeIdx;
              FIdx2 := -1;
              If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                 (TypeTab[FTIdx2].Kind = TKP_RECORD) And
                 (CurToken.Kind = TK_IDENT) Then
              Begin
                For FI2 := 0 To TypeTab[FTIdx2].FieldCount - 1 Do
                  If StrLowerCase(TypeTab[FTIdx2].Fields[FI2].Name) =
                     StrLowerCase(CurToken.Val) Then
                  Begin
                    FIdx2 := FI2;
                    Break;
                  End;
                LexNextToken;
              End
              Else If CurToken.Kind = TK_IDENT Then
                LexNextToken;
              EmitComment('field ' + IdName + '.*');
              If FIdx2 >= 0 Then
              Begin
                Res.TypeIdx := TypeTab[FTIdx2].Fields[FIdx2].TypeIdx;
                If SymTab[SIdx2].IsLocal Then
                Begin
                  If SymTab[SIdx2].Cat = SC_VARPARAM Then
                  Begin
                    EmitInstrAB('MOV', 'EBX',
                      'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
                    If TypeTab[FTIdx2].Fields[FIdx2].Offset > 0 Then
                      EmitInstrAB('ADD', 'EBX',
                        IntToStr(TypeTab[FTIdx2].Fields[FIdx2].Offset));
                    If TypeSizeof(Res.TypeIdx) = 1 Then
                      EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]')
                    Else
                      EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                  End
                  Else
                  Begin
                    If TypeSizeof(Res.TypeIdx) = 1 Then
                      EmitInstrAB('MOVZX', 'EAX',
                        'BYTE PTR ' + EBPOfs(SymTab[SIdx2].Offset +
                          TypeTab[FTIdx2].Fields[FIdx2].Offset))
                    Else
                      EmitInstrAB('MOV', 'EAX',
                        'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset +
                          TypeTab[FTIdx2].Fields[FIdx2].Offset));
                  End;
                End
                Else
                Begin
                  If TypeTab[FTIdx2].Fields[FIdx2].Offset = 0 Then
                  Begin
                    If TypeSizeof(Res.TypeIdx) = 1 Then
                      EmitInstrAB('MOVZX', 'EAX',
                        'BYTE PTR [' + SymTab[SIdx2].MangledName + ']')
                    Else
                      EmitInstrAB('MOV', 'EAX',
                        'DWORD PTR [' + SymTab[SIdx2].MangledName + ']');
                  End
                  Else
                  Begin
                    EmitInstrAB('MOV', 'EBX',
                      'OFFSET ' + SymTab[SIdx2].MangledName);
                    EmitInstrAB('ADD', 'EBX',
                      IntToStr(TypeTab[FTIdx2].Fields[FIdx2].Offset));
                    If TypeSizeof(Res.TypeIdx) = 1 Then
                      EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]')
                    Else
                      EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
                  End;
                End;
              End
              Else
              Begin
                (* Unknown field - load base *)
                If SymTab[SIdx2].IsLocal Then
                  EmitInstrAB('MOV', 'EAX',
                    'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset))
                Else
                  EmitInstrAB('MOV', 'EAX',
                    'DWORD PTR [' + SymTab[SIdx2].MangledName + ']');
              End;
              Res.Kind   := EK_EAX;
              Res.SymIdx := SIdx2;
            End  (* record field *)

            (* Handle array/string subscript: ident[index] *)
            Else If IsOpenBracket Then
            Begin
              LexNextToken;
              FTIdx2 := SymTab[SIdx2].TypeIdx;
              EmitComment('index ' + IdName + '[i]');

              ParseExpr(SubEv);
              ExprFlushToEAX(SubEv);

              (* Subtract lower bound for arrays *)
              If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                 (TypeTab[FTIdx2].Kind = TKP_ARRAY) And
                 (TypeTab[FTIdx2].Lo <> 0) Then
                EmitInstrAB('SUB', 'EAX', IntToStr(TypeTab[FTIdx2].Lo));

              (* Multiply by element size *)
              ESize2 := 4;
              If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                 (TypeTab[FTIdx2].Kind = TKP_ARRAY) Then
              Begin
                ESize2 := TypeSizeof(TypeTab[FTIdx2].BaseTypeIdx);
                If ESize2 = 4 Then
                  EmitInstrAB('SHL', 'EAX', '2')
                Else If ESize2 = 2 Then
                  EmitInstrAB('SHL', 'EAX', '1')
                Else If ESize2 > 4 Then
                Begin
                  EmitInstrAB('MOV', 'ECX', IntToStr(ESize2));
                  EmitInstrAB('IMUL', 'EAX', 'ECX');
                End;
                (* ESize2 = 1 : no multiply needed *)
              End
              Else If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                      ((TypeTab[FTIdx2].Kind = TKP_STRING) Or
                       (TypeTab[FTIdx2].Kind = TKP_VARYING)) Then
              Begin
                ESize2 := 1;
                (* char access: no multiply needed *)
              End
              Else
                EmitInstrAB('SHL', 'EAX', '2');

              EmitInstrAB('MOV', 'EBX', 'EAX');

              (* Calculate base address *)
              If SymTab[SIdx2].IsLocal Then
              Begin
                If SymTab[SIdx2].Cat = SC_VARPARAM Then
                Begin
                  EmitInstrAB('MOV', 'ECX',
                    'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
                  EmitInstrAB('ADD', 'EBX', 'ECX');
                End
                Else
                Begin
                  EmitInstrAB('LEA', 'ECX',
                    EBPOfs(SymTab[SIdx2].Offset));
                  EmitInstrAB('ADD', 'EBX', 'ECX');
                End;
              End
              Else
                EmitInstrAB('ADD', 'EBX',
                  'OFFSET ' + SymTab[SIdx2].MangledName);

              If IsCloseBracket Then LexNextToken;

              (* Load the element *)
              If ESize2 = 1 Then
                EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]')
              Else
                EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');

              If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                 (TypeTab[FTIdx2].Kind = TKP_ARRAY) Then
                Res.TypeIdx := TypeTab[FTIdx2].BaseTypeIdx
              Else If (FTIdx2 >= 0) And (FTIdx2 < TypeCount) And
                      ((TypeTab[FTIdx2].Kind = TKP_STRING) Or
                       (TypeTab[FTIdx2].Kind = TKP_VARYING)) Then
                Res.TypeIdx := TY_IDX_CHAR
              Else
                Res.TypeIdx := TY_IDX_INTEGER;
              Res.Kind   := EK_EAX;
              Res.SymIdx := SIdx2;
            End  (* array/string subscript *)

            (* Simple variable access *)
            Else
            Begin
              If SymTab[SIdx2].Cat = SC_VARPARAM Then
              Begin
                EmitInstrAB('MOV', 'EBX',
                  'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
                If TypeSizeof(SymTab[SIdx2].TypeIdx) = 1 Then
                  EmitInstrAB('MOVZX', 'EAX', 'BYTE PTR [EBX]')
                Else
                  EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
              End
              Else If SymTab[SIdx2].IsLocal Then
              Begin
                If TypeSizeof(SymTab[SIdx2].TypeIdx) = 1 Then
                  EmitInstrAB('MOVZX', 'EAX',
                    'BYTE PTR ' + EBPOfs(SymTab[SIdx2].Offset))
                Else
                  EmitInstrAB('MOV', 'EAX',
                    'DWORD PTR ' + EBPOfs(SymTab[SIdx2].Offset));
              End
              Else
              Begin
                If TypeSizeof(SymTab[SIdx2].TypeIdx) = 1 Then
                  EmitInstrAB('MOVZX', 'EAX',
                    'BYTE PTR [' + SymTab[SIdx2].MangledName + ']')
                Else
                  EmitInstrAB('MOV', 'EAX',
                    'DWORD PTR [' + SymTab[SIdx2].MangledName + ']');
              End;
              Res.Kind    := EK_EAX;
              Res.SymIdx  := SIdx2;
            End;  (* simple variable access *)
          End;  (* variable symbol cases *)
        End;  (* else not builtin *)
    End;

    (* --- Ponctuation ( ) --- *)
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        LexNextToken;  (* consommer ( *)
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken  (* consommer ) *)
        Else
          WarnMsg(''')'' attendu dans sous-expression');
      End
      Else
      Begin
        WarnMsg('expression primaire attendue, trouve: ' + CurToken.Val);
        LexNextToken;
      End;
    End;

  Else
    WarnMsg('expression primaire attendue');
    LexNextToken;
  End;
End;

(* ---- ParseUnary : operateurs unaires -------------------------*)
(* Gere NOT, moins unaire -, plus unaire +, @ (adresse de).      *)
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
      ExprFlushToEAX(Res);
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
        EmitInstrAB('XOR', 'EAX', '1')
      Else
        EmitInstr('NOT    EAX');
      Res.Kind   := EK_EAX;
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
      ExprFlushToEAX(Res);
      EmitInstr('NEG    EAX');
      Res.Kind   := EK_EAX;
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
        EmitInstrAB('LEA', 'EAX',
          EBPOfs(SymTab[Res.SymIdx].Offset))
      Else
        EmitInstrAB('MOV', 'EAX',
          'OFFSET ' + SymTab[Res.SymIdx].MangledName);
    End
    Else
    Begin
      WarnMsg('@ requiert une variable ou un parametre');
      EmitInstrAB('XOR', 'EAX', 'EAX');
    End;
    Res.Kind    := EK_EAX;
    Res.TypeIdx := TY_IDX_POINTER;
    Res.SymIdx  := -1;
    Exit;
  End;

  (* Pas d operateur unaire : ParsePrimary *)
  ParsePrimary(Res);
End;

(* ---- ParseExprPrec : Pratt parser pour operateurs binaires --- *)
(* Boucle de montee de precedence. EAX=gauche, EBX=droite.        *)
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
      ExprFlushToEAX(Res);
      LblSkip := NewLabel;
      EmitInstrAB('CMP', 'EAX', '0');
      EmitInstrA('JE', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToEAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_EAX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* ---- ORIF : evaluation court-circuit ---- *)
    If Op = 'orif' Then
    Begin
      ExprFlushToEAX(Res);
      LblSkip := NewLabel;
      EmitInstrAB('CMP', 'EAX', '0');
      EmitInstrA('JNE', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToEAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_EAX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Sauvegarder operande gauche *)
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToEAX(Res);
      EmitInstrA('PUSH', 'EAX');
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
        ExprMakeImm(LeftImm Shl Integer(Right.ImmVal And 31),
                    TY_IDX_INTEGER, Res)
      Else If Op = 'shr' Then
        ExprMakeImm(LeftImm Shr Integer(Right.ImmVal And 31),
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
        WarnMsg('in : ensembles non supportes (constantes), retourne 0');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End
    Else
    Begin
      (* ---- Emission de code binaire 32 bits ---- *)
      ResType := Res.TypeIdx;
      If (Res.TypeIdx = TY_IDX_STRING) Or (Right.TypeIdx = TY_IDX_STRING) Then
        ResType := TY_IDX_STRING
      Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
              (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
        ResType := TY_IDX_BOOLEAN;

      (* Charger droite dans EBX *)
      ExprFlushToEAX(Right);
      EmitInstrAB('MOV', 'EBX', 'EAX');

      (* Restaurer gauche dans EAX *)
      If LeftIsImm Then
        EmitInstrAB('MOV', 'EAX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'EAX');

      (* EAX = gauche, EBX = droite *)

      (* --- Arithmetique 32 bits --- *)
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'CONCAT');
        End
        Else
          EmitInstrAB('ADD', 'EAX', 'EBX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'EAX', 'EBX')

      Else If Op = '*' Then
        EmitInstrA('IMUL', 'EBX')

      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        EmitInstrAB('TEST', 'EBX', 'EBX');
        EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CDQ');
        EmitInstrA('IDIV', 'EBX');
      End

      Else If Op = 'mod' Then
      Begin
        EmitInstrAB('TEST', 'EBX', 'EBX');
        EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CDQ');
        EmitInstrA('IDIV', 'EBX');
        EmitInstrAB('MOV', 'EAX', 'EDX');
      End

      (* --- Concatenation || --- *)
      Else If Op = '||' Then
      Begin
        EmitComment('|| concatenation');
        EmitInstrAB('MOV', 'ESI', 'EAX');
        EmitInstrAB('MOV', 'EDI', 'EBX');
        EmitInstrA('CALL', VXP_RT_PFX + 'CONCAT');
        ResType := TY_IDX_STRING;
      End

      (* --- Exponentiation ** --- *)
      Else If Op = '**' Then
      Begin
        EmitComment('** exponentiation');
        (* EAX = base, EBX = exposant *)
        (* Boucle : ECX=exposant, EAX=resultat, EDX=base *)
        EmitInstrAB('MOV', 'ECX', 'EBX');  (* ECX = exposant *)
        EmitInstrAB('MOV', 'EDX', 'EAX');  (* EDX = base *)
        EmitInstrAB('MOV', 'EAX', '1');    (* EAX = resultat = 1 *)
        LblPow := NewLabel;
        LblPowEnd := NewLabel;
        EmitInstrAB('CMP', 'ECX', '0');
        EmitInstrA('JLE', LblPowEnd);
        EmitLabel(LblPow);
        EmitInstrA('IMUL', 'EDX');          (* EAX = EAX * EDX *)
        EmitInstr('DEC    ECX');
        EmitInstrA('JNZ', LblPow);
        EmitLabel(LblPowEnd);
        ResType := TY_IDX_INTEGER;
      End

      (* --- Bits / Logiques --- *)
      Else If Op = 'and' Then
        EmitInstrAB('AND', 'EAX', 'EBX')

      Else If Op = 'or' Then
        EmitInstrAB('OR', 'EAX', 'EBX')

      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'EAX', 'EBX')

      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'EAX', 'CL');
      End

      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'EAX', 'CL');
      End

      (* --- Comparaisons : CMP + Jcc -> EAX = 0|1 --- *)
      Else If Op = '=' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<>' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<=' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>=' Then
      Begin
        LblSkip := NewLabel;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', VXP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstr('INC    EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = 'in' Then
      Begin
        EmitComment('element IN set');
        (* EAX = element, EBX = set pointer *)
        EmitInstrAB('MOV', 'ESI', 'EBX');
        EmitInstrAB('MOV', 'EBX', 'EAX');
        EmitInstrA('CALL', VXP_RT_PFX + 'SET_IN');
        ResType := TY_IDX_BOOLEAN;
      End;

      Res.Kind    := EK_EAX;
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
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
{ Produit l etiquette assembleur a partir du nom du symbole et de }
{ sa categorie. Utilise les prefixes VXP_* definis dans les       }
{ constantes pour la cible Win32/MASM .386.                       }
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
{ Retourne l indice du nouveau symbole dans SymTab[], ou -1 si   }
{ la table est pleine. Verifie les doublons dans le scope courant }
{ et gere les declarations forward.                                }
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
{ Parcourt la table du plus recent au plus ancien, retourne le    }
{ premier symbole dont le ScopeLevel est inferieur ou egal au     }
{ scope courant. Retourne -1 si non trouve.                       }
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
{ Retourne l indice du symbole portant ce nom dans ce niveau de  }
{ scope exact, ou -1 si non trouve.                               }
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
{ Enregistre les types primitifs Pascal standard, les types VAX   }
{ Pascal supplementaires, les constantes predefinies (true, false, }
{ nil, maxint=2147483647 pour 32 bits), les variables I/O, les    }
{ procedures et fonctions du runtime, et les conditions VMS.      }
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

  { Constantes predefinies (MAXINT = 2147483647 pour 32 bits) }
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
    SymTab[Idx].ImmVal := 2147483647;
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
  Idx := SymAdd('error', SC_VAR, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_VAR_PFX + 'ERROR';

  { Procedures runtime predeclarees }
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

  { Procedures fichier }
  Idx := SymAdd('assign', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ASSIGN';
  Idx := SymAdd('reset', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'RESET';
  Idx := SymAdd('rewrite', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'REWRITE';
  Idx := SymAdd('close', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'CLOSE';
  Idx := SymAdd('open', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'OPEN';
  Idx := SymAdd('get', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'GET';
  Idx := SymAdd('put', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'PUT';
  Idx := SymAdd('find', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'FIND';
  Idx := SymAdd('locate', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'LOCATE';
  Idx := SymAdd('truncate', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'TRUNCATE';
  Idx := SymAdd('readrn', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'READRN';
  Idx := SymAdd('writern', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'WRITERN';
  Idx := SymAdd('update', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'UPDATE';

  { Fonctions fichier }
  Idx := SymAdd('status', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'STATUS';
  Idx := SymAdd('cursor', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'CURSOR';
  Idx := SymAdd('filename', SC_FUNC, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'FILENAME';
  Idx := SymAdd('ufb', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'UFB';

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

  { Fonctions mathematiques et utilitaires }
  Idx := SymAdd('sqrt', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SQRT';
  Idx := SymAdd('sin', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SIN';
  Idx := SymAdd('cos', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'COS';
  Idx := SymAdd('arctan', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ARCTAN';
  Idx := SymAdd('ln', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'LN';
  Idx := SymAdd('exp', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'EXP';
  Idx := SymAdd('trunc', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'TRUNC';
  Idx := SymAdd('round', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ROUND';
  Idx := SymAdd('max', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'MAX';
  Idx := SymAdd('min', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'MIN';
  Idx := SymAdd('random', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'RANDOM';
  Idx := SymAdd('lo', SC_FUNC, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'LO';
  Idx := SymAdd('hi', SC_FUNC, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'HI';
  Idx := SymAdd('swap', SC_FUNC, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SWAP';
  Idx := SymAdd('copy', SC_FUNC, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'COPY';
  Idx := SymAdd('pos', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'POS';
  Idx := SymAdd('trim', SC_FUNC, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'TRIM';
  Idx := SymAdd('clock', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'CLOCK';
  Idx := SymAdd('wallclock', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'WALLCLOCK';

  { Procedures standard }
  Idx := SymAdd('assert', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ASSERT';
  Idx := SymAdd('message', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'MESSAGE';
  Idx := SymAdd('delete', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'DELETE';
  Idx := SymAdd('insert', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'INSERT';
  Idx := SymAdd('seed', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'SETSEED';
  Idx := SymAdd('zero', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'ZERO';
  Idx := SymAdd('fill', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'FILL';
  Idx := SymAdd('str', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'STR';
  Idx := SymAdd('val', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'VAL';
  Idx := SymAdd('date', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'DATE';
  Idx := SymAdd('time', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'TIME';
  Idx := SymAdd('page', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'PAGE';
  Idx := SymAdd('linelimit', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'LINELIMIT';

  { Conditions predefinies VMS }
  Idx := SymAdd('ss$_accvio', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '1'; SymTab[Idx].Offset := 1; End;
  Idx := SymAdd('ss$_intovf', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '2'; SymTab[Idx].Offset := 2; End;
  Idx := SymAdd('ss$_intdiv', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '3'; SymTab[Idx].Offset := 3; End;
  Idx := SymAdd('ss$_fltovf', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '4'; SymTab[Idx].Offset := 4; End;
  Idx := SymAdd('ss$_fltdiv', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '5'; SymTab[Idx].Offset := 5; End;
  Idx := SymAdd('ss$_roprand', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '6'; SymTab[Idx].Offset := 6; End;
  Idx := SymAdd('ss$_hparith', SC_CONDITION, TY_IDX_INTEGER);
  If Idx >= 0 Then Begin SymTab[Idx].MangledName := '7'; SymTab[Idx].Offset := 7; End;

  { Fonctions/variables d exception }
  Idx := SymAdd('exception_message', SC_FUNC, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'EXCMSG';
  Idx := SymAdd('exception_value', SC_FUNC, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := VXP_RT_PFX + 'EXCVAL';

  If Opts.DebugMode Then
    WriteLn('  SymInit: ', SymCount, ' symboles predeclares');

  { Sauvegarder le nombre de symboles predeclares (pour ENVIRONMENT) }
  SymInitCount := SymCount;
End;


{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

(* ---- TypeInit : initialiser les types primitifs 32 bits ----- *)
(* 14 types primitifs (TY_PRIM_COUNT) + types predefinis VAX      *)
(* supplementaires ajoutes comme alias ou types derives.          *)
(* Mapping Win32 32 bits :                                        *)
(*   Integer = 4 octets (32 bits signe, EAX)                     *)
(*   Word    = 4 octets (32 bits non signe)                      *)
(*   Byte    = 1 octet                                           *)
(*   Char    = 1 octet                                           *)
(*   Boolean = 1 octet (etendu dans EAX)                         *)
(*   String  = 4 octets (pointeur near 32 bits)                  *)
(*   Real    = 4 octets (tronque en entier 32 bits)              *)
(*   Double  = 4 octets (tronque en entier 32 bits)              *)
(*   Pointer = 4 octets (32 bits)                                *)
(*   nil     = 4 octets                                          *)
(*   Text    = FDB (File Descriptor Block, FILE_DESC_SIZE octets)*)
(*   Unsigned= 4 octets (alias Word)                             *)
(*   Varying = 4 octets (pointeur)                               *)
(*   Set     = 32 octets (256 bits)                              *)

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
  Procedure RegAlias(Const AName : TString; TIdx : Integer);
  Var
    SI : Integer;
  Begin
    SI := SymFind(AName);
    If SI >= 0 Then
    Begin
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
  { 1) Initialiser les 14 types primitifs (32 bits) }
  TypeCount := TY_PRIM_COUNT;
  AddPrim(TY_IDX_INTEGER,  TKP_INTEGER,  4);  { Integer  : 4 octets (32 bits signe)    }
  AddPrim(TY_IDX_WORD,     TKP_WORD,     4);  { Word     : 4 octets (32 bits non signe) }
  AddPrim(TY_IDX_BYTE,     TKP_BYTE,     1);  { Byte     : 1 octet                      }
  AddPrim(TY_IDX_CHAR,     TKP_CHAR,     1);  { Char     : 1 octet                      }
  AddPrim(TY_IDX_BOOLEAN,  TKP_BOOLEAN,  1);  { Boolean  : 1 octet (etendu EAX)         }
  AddPrim(TY_IDX_STRING,   TKP_STRING,   4);  { String   : 4 octets (ptr ASCIIZ 32 bits)}
  AddPrim(TY_IDX_REAL,     TKP_REAL,     4);  { Real     : 4 (tronque en entier 32 bits)}
  AddPrim(TY_IDX_DOUBLE,   TKP_DOUBLE,   4);  { Double   : 4 (tronque en entier 32 bits)}
  AddPrim(TY_IDX_POINTER,  TKP_POINTER,  4);  { Pointer  : 4 octets (32 bits)           }
  AddPrim(TY_IDX_NIL,      TKP_NIL,      4);  { nil      : 4 octets                     }
  AddPrim(TY_IDX_TEXT,     TKP_TEXT,     FILE_DESC_SIZE); { Text : FDB (132 oct) }
  AddPrim(TY_IDX_UNSIGNED, TKP_WORD,     4);  { Unsigned : 4 octets (alias Word 32 bits)}
  AddPrim(TY_IDX_VARYING,  TKP_VARYING,  4);  { Varying  : 4 octets (ptr)               }
  AddPrim(TY_IDX_SET,      TKP_SET,     32);  { Set      : 32 octets (256 bits)          }

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

  { INTEGER32 : natif 32 bits (4 octets) }
  Idx := AddExtra(TKP_INTEGER, 4, TY_IDX_INTEGER);
  RegAlias('INTEGER32', Idx);

  { QUADWORD : 64 bits (8 octets, emule en 2x32) }
  Idx := AddExtra(TKP_INTEGER, 8, TY_IDX_INTEGER);
  RegAlias('QUADWORD', Idx);

  { H_FLOATING : quadruple precision (non supporte, alias Double) }
  RegAlias('H_FLOATING', TY_IDX_DOUBLE);

  { 3) IO_STATUS : enumeration predefinie d etats d I/O }
  Idx := TypeCount;
  If Idx < MAX_TYPE Then
  Begin
    TypeTab[Idx].Kind        := TKP_ENUM;
    TypeTab[Idx].Size        := 4;  { 4 octets en 32 bits }
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
    TypeSizeof := 4;  (* taille par defaut = DWORD 32 bits *)
End;

(* ---- IsSetTypeIdx : le type est-il un ensemble ? -------------- *)
Function IsSetTypeIdx(TIdx : Integer) : Boolean;
Begin
  IsSetTypeIdx := (TIdx >= 0) And (TIdx < TypeCount) And
                  (TypeTab[TIdx].Kind = TKP_SET);
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

  (* Set <-> Set (meme genre) *)
  If (K1 = TKP_SET) And (K2 = TKP_SET) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  TypeCompatible := False;
End;

(* ---- EmitCoerce : conversion de type inline 32 bits ----------- *)
(* Emet le code x86-32 necessaire pour convertir la valeur dans    *)
(* EAX du type SrcType vers DstType.                               *)
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

  { Byte -> Integer/Word : extension zero MOVZX EAX, AL }
  If (Ks = TKP_BYTE) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce byte -> dword');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    Exit;
  End;

  { Char -> Integer/Word : extension zero MOVZX EAX, AL }
  If (Ks = TKP_CHAR) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce char -> dword (Ord)');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    Exit;
  End;

  { Integer/Word -> Byte : troncature (prendre AL) }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_BYTE) Then
  Begin
    EmitComment('coerce dword -> byte (troncature)');
    Exit;
  End;

  { Boolean -> Integer : extension zero MOVZX EAX, AL }
  If (Ks = TKP_BOOLEAN) And
     ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce boolean -> dword');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    Exit;
  End;

  { Integer -> Boolean : CMP EAX,0 / SETNE AL / MOVZX EAX, AL }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And
     (Kd = TKP_BOOLEAN) Then
  Begin
    EmitComment('coerce dword -> boolean');
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('SETNE', 'AL');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    Exit;
  End;

  { Char -> String : sera gere par le runtime (Chr) }
  If (Ks = TKP_CHAR) And (Kd = TKP_STRING) Then
  Begin
    EmitComment('coerce char -> string (runtime)');
    Exit;
  End;

  { nil -> Pointer/String : valeur deja 0 }
  If (Ks = TKP_NIL) And ((Kd = TKP_POINTER) Or (Kd = TKP_STRING)) Then
    Exit;

  { Real -> Integer : tronquage (deja fait par le front-end) }
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
    EmitComment('coerce enum -> dword (Ord)');
    Exit;
  End;

  { Integer <-> Word : meme representation 32 bits, pas de code }
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

  { Pas de conversion connue : avertissement }
  If Opts.Warnings Then
    WarnMsg('conversion de type implicite non supportee');
End;

(* ---- TypeCoerce : emettre le code de conversion src -> dst ---- *)
(* Delegue a EmitCoerce et retourne le TypeIdx du resultat.        *)
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


{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
  ============================================================ }

{ ---- EmitOpen : ouvrir le fichier de sortie ASM -------------- }
{ Cree le fichier ASM de sortie (ou un fichier intermediaire     }
{ en mode binaire -exe/-obj). Initialise OutF et OutFOpen.       }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-} Rewrite(OutF); {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;
End;

{ ---- EmitFooter : pied de page ASM + runtime Win32 32 bits --- }
{ Emet le code de terminaison (ExitProcess) puis les routines    }
{ runtime 32 bits : PRINTSTR, NUMTOSTR, STRLEN, CONCAT, STRCMP,  }
{ NEWLINE, PRINTINT, PRINTBOOL, READLN, POWER, SET_IN, STRTONUM. }
{ Toutes les routines utilisent EAX/EBX/ECX/EDX/ESI/EDI et les  }
{ appels systeme Win32 via WriteFile / ReadFile / ExitProcess.   }
Procedure EmitFooter;
Begin
  EmitBlankLine;
  { Emettre le label MAINBODY si pas deja fait }
  If Not MainBodyEmitted Then
  Begin
    EmitLabel(VXP_LBL_PFX + 'MAINBODY');
    MainBodyEmitted := True;
  End;
  EmitBlankLine;
  EmitComment('--- Sortie programme (Win32 ExitProcess) ---');
  EmitInstrA('PUSH', '0');
  EmitInstrA('CALL', '_ExitProcess@4');
  EmitBlankLine;

  { --- Routines runtime 32 bits --- }
  If RuntimeEmitted Then
  Begin
    EmitRaw('_TEXT   ENDS');
    Exit;
  End;
  RuntimeEmitted := True;
  EmitComment('========================================');
  EmitComment('  ROUTINES RUNTIME 32 BITS (Win32)');
  EmitComment('========================================');
  EmitBlankLine;

  { _VXPRT_PRINTSTR : afficher chaine ASCIIZ pointee par ESI }
  EmitComment('PRINTSTR : affiche chaine ASCIIZ (ESI -> chaine)');
  EmitLabel(VXP_RT_PFX + 'PRINTSTR');
  EmitInstrA('PUSH', 'ESI');
  EmitInstrAB('MOV', 'EDI', 'ESI');
  EmitComment('calculer la longueur');
  EmitInstrAB('XOR', 'ECX', 'ECX');
  EmitLabel(VXP_RT_PFX + 'PRINTSTR_L');
  EmitInstrAB('CMP', 'BYTE PTR [EDI]', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'PRINTSTR_W');
  EmitInstrA('INC', 'EDI');
  EmitInstrA('INC', 'ECX');
  EmitInstrA('JMP', VXP_RT_PFX + 'PRINTSTR_L');
  EmitLabel(VXP_RT_PFX + 'PRINTSTR_W');
  EmitComment('WriteFile(hStdout, pStr, len, pWritten, 0)');
  EmitInstrA('PUSH', '0');
  EmitInstrA('PUSH', 'OFFSET ' + VXP_RT_PFX + 'WRITTEN');
  EmitInstrA('PUSH', 'ECX');
  EmitInstrA('PUSH', 'ESI');
  EmitInstrA('PUSH', 'DWORD PTR [' + VXP_RT_PFX + 'HSTDOUT]');
  EmitInstrA('CALL', '_WriteFile@20');
  EmitInstrA('POP', 'ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_NUMTOSTR : convertir EAX (signe) -> ASCIIZ dans NUMBUF }
  EmitComment('NUMTOSTR : convertit EAX (signe) -> NUMBUF (ASCIIZ)');
  EmitLabel(VXP_RT_PFX + 'NUMTOSTR');
  EmitInstrA('PUSH', 'EBX');
  EmitInstrA('PUSH', 'ECX');
  EmitInstrA('PUSH', 'EDX');
  EmitInstrA('PUSH', 'EDI');
  EmitInstrA('PUSH', 'EAX');
  EmitInstrAB('LEA', 'EDI', VXP_RT_PFX + 'NUMBUF + 15');
  EmitInstrAB('MOV', 'BYTE PTR [EDI]', '0');
  EmitInstrAB('MOV', 'ECX', '0');
  EmitInstrAB('MOV', 'EBX', '10');
  EmitInstrAB('CMP', 'EAX', '0');
  EmitInstrA('JGE', VXP_RT_PFX + 'NTS_POS');
  EmitInstr('NEG    EAX');
  EmitRaw(VXP_RT_PFX + 'NTS_POS:');
  EmitRaw(VXP_RT_PFX + 'NTS_DIV:');
  EmitInstrAB('XOR', 'EDX', 'EDX');
  EmitInstrA('DIV', 'EBX');
  EmitRaw('        ADD    DL, ' + Chr(39) + '0' + Chr(39));
  EmitInstr('DEC    EDI');
  EmitInstrAB('MOV', '[EDI]', 'DL');
  EmitInstrA('INC', 'ECX');
  EmitInstrAB('CMP', 'EAX', '0');
  EmitInstrA('JNE', VXP_RT_PFX + 'NTS_DIV');
  EmitComment('verifier le signe (valeur originale empilee)');
  EmitInstrAB('MOV', 'EAX', 'DWORD PTR [ESP]');
  EmitInstrAB('CMP', 'EAX', '0');
  EmitInstrA('JGE', VXP_RT_PFX + 'NTS_DONE');
  EmitInstr('DEC    EDI');
  EmitRaw('        MOV    BYTE PTR [EDI], ' + Chr(39) + '-' + Chr(39));
  EmitRaw(VXP_RT_PFX + 'NTS_DONE:');
  EmitInstrAB('MOV', 'EAX', 'EDI');
  EmitInstrAB('ADD', 'ESP', '4');
  EmitInstrA('POP', 'EDI');
  EmitInstrA('POP', 'EDX');
  EmitInstrA('POP', 'ECX');
  EmitInstrA('POP', 'EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_STRLEN : longueur chaine ASCIIZ (ESI -> EAX) }
  EmitComment('STRLEN : longueur chaine ASCIIZ (ESI -> EAX)');
  EmitLabel(VXP_RT_PFX + 'STRLEN');
  EmitInstrA('PUSH', 'ESI');
  EmitInstrAB('XOR', 'EAX', 'EAX');
  EmitRaw(VXP_RT_PFX + 'STRLEN_LP:');
  EmitInstrAB('CMP', 'BYTE PTR [ESI]', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'STRLEN_DONE');
  EmitInstr('INC    EAX');
  EmitInstr('INC    ESI');
  EmitInstrA('JMP', VXP_RT_PFX + 'STRLEN_LP');
  EmitRaw(VXP_RT_PFX + 'STRLEN_DONE:');
  EmitInstrA('POP', 'ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_CONCAT : concatener deux chaines ASCIIZ }
  EmitComment('CONCAT : ESI + EDI -> EAX = ptr STRBUF');
  EmitLabel(VXP_RT_PFX + 'CONCAT');
  EmitInstrA('PUSH', 'EBX');
  EmitInstrAB('LEA', 'EBX', VXP_RT_PFX + 'STRBUF');
  EmitRaw(VXP_RT_PFX + 'CONCAT_S1:');
  EmitInstrAB('MOV', 'AL', '[ESI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'CONCAT_S2');
  EmitInstrAB('MOV', '[EBX]', 'AL');
  EmitInstr('INC    ESI');
  EmitInstr('INC    EBX');
  EmitInstrA('JMP', VXP_RT_PFX + 'CONCAT_S1');
  EmitRaw(VXP_RT_PFX + 'CONCAT_S2:');
  EmitInstrAB('MOV', 'AL', '[EDI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'CONCAT_END');
  EmitInstrAB('MOV', '[EBX]', 'AL');
  EmitInstr('INC    EDI');
  EmitInstr('INC    EBX');
  EmitInstrA('JMP', VXP_RT_PFX + 'CONCAT_S2');
  EmitRaw(VXP_RT_PFX + 'CONCAT_END:');
  EmitInstrAB('MOV', 'BYTE PTR [EBX]', '0');
  EmitInstrAB('LEA', 'EAX', VXP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_STRCMP : comparer deux chaines ASCIIZ }
  EmitComment('STRCMP : ESI vs EDI -> EAX (0=egal, <0 inf, >0 sup)');
  EmitLabel(VXP_RT_PFX + 'STRCMP');
  EmitInstrA('PUSH', 'ESI');
  EmitInstrA('PUSH', 'EDI');
  EmitRaw(VXP_RT_PFX + 'STRCMP_LP:');
  EmitInstrAB('MOV', 'AL', '[ESI]');
  EmitInstrAB('MOV', 'AH', '[EDI]');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', VXP_RT_PFX + 'STRCMP_DIFF');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'STRCMP_EQ');
  EmitInstr('INC    ESI');
  EmitInstr('INC    EDI');
  EmitInstrA('JMP', VXP_RT_PFX + 'STRCMP_LP');
  EmitRaw(VXP_RT_PFX + 'STRCMP_EQ:');
  EmitInstrAB('XOR', 'EAX', 'EAX');
  EmitInstrA('JMP', VXP_RT_PFX + 'STRCMP_RET');
  EmitRaw(VXP_RT_PFX + 'STRCMP_DIFF:');
  EmitInstrAB('MOVZX', 'EAX', 'AL');
  EmitInstrAB('MOVZX', 'EDX', 'AH');
  EmitInstrAB('SUB', 'EAX', 'EDX');
  EmitRaw(VXP_RT_PFX + 'STRCMP_RET:');
  EmitInstrA('POP', 'EDI');
  EmitInstrA('POP', 'ESI');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_NEWLINE : ecrire CRLF }
  EmitComment('NEWLINE : ecrire CR+LF sur stdout');
  EmitLabel(VXP_RT_PFX + 'NEWLINE');
  EmitInstrAB('MOV', 'ESI', 'OFFSET ' + VXP_RT_PFX + 'CRLF');
  EmitInstrA('CALL', VXP_RT_PFX + 'PRINTSTR');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_PRINTINT : afficher EAX comme entier signe }
  EmitComment('PRINTINT : affiche EAX en decimal signe');
  EmitLabel(VXP_RT_PFX + 'PRINTINT');
  EmitInstrA('CALL', VXP_RT_PFX + 'NUMTOSTR');
  EmitInstrAB('MOV', 'ESI', 'EAX');
  EmitInstrA('CALL', VXP_RT_PFX + 'PRINTSTR');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_PRINTBOOL : afficher EAX comme TRUE/FALSE }
  EmitComment('PRINTBOOL : affiche TRUE ou FALSE (EAX)');
  EmitLabel(VXP_RT_PFX + 'PRINTBOOL');
  EmitInstrAB('CMP', 'EAX', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'PB_FALSE');
  EmitInstrAB('MOV', 'ESI', 'OFFSET ' + VXP_RT_PFX + 'TRUE_S');
  EmitInstrA('JMP', VXP_RT_PFX + 'PB_PRINT');
  EmitRaw(VXP_RT_PFX + 'PB_FALSE:');
  EmitInstrAB('MOV', 'ESI', 'OFFSET ' + VXP_RT_PFX + 'FALSE_S');
  EmitRaw(VXP_RT_PFX + 'PB_PRINT:');
  EmitInstrA('CALL', VXP_RT_PFX + 'PRINTSTR');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_READLN : lire une ligne depuis stdin -> STRBUF, EAX=ptr }
  EmitComment('READLN : lit une ligne stdin -> STRBUF (EAX=ptr)');
  EmitLabel(VXP_RT_PFX + 'READLN');
  EmitInstrA('PUSH', 'EBX');
  EmitInstrA('PUSH', 'ECX');
  EmitComment('ReadFile(hStdin, STRBUF, 255, WRITTEN, 0)');
  EmitInstrA('PUSH', '0');
  EmitInstrA('PUSH', 'OFFSET ' + VXP_RT_PFX + 'WRITTEN');
  EmitInstrA('PUSH', '255');
  EmitInstrA('PUSH', 'OFFSET ' + VXP_RT_PFX + 'STRBUF');
  EmitInstrA('PUSH', 'DWORD PTR [' + VXP_RT_PFX + 'HSTDIN]');
  EmitInstrA('CALL', '_ReadFile@20');
  EmitComment('Supprimer CR/LF en fin de ligne');
  EmitInstrAB('MOV', 'ECX', 'DWORD PTR [' + VXP_RT_PFX + 'WRITTEN]');
  EmitInstrAB('LEA', 'EBX', VXP_RT_PFX + 'STRBUF');
  EmitRaw(VXP_RT_PFX + 'RL_TRIM:');
  EmitInstrAB('CMP', 'ECX', '0');
  EmitInstrA('JE', VXP_RT_PFX + 'RL_DONE');
  EmitInstr('DEC    ECX');
  EmitInstrAB('CMP', 'BYTE PTR [EBX+ECX]', '10');
  EmitInstrA('JE', VXP_RT_PFX + 'RL_ZERO');
  EmitInstrAB('CMP', 'BYTE PTR [EBX+ECX]', '13');
  EmitInstrA('JE', VXP_RT_PFX + 'RL_ZERO');
  EmitInstr('INC    ECX');
  EmitInstrA('JMP', VXP_RT_PFX + 'RL_DONE');
  EmitRaw(VXP_RT_PFX + 'RL_ZERO:');
  EmitInstrAB('MOV', 'BYTE PTR [EBX+ECX]', '0');
  EmitInstrA('JMP', VXP_RT_PFX + 'RL_TRIM');
  EmitRaw(VXP_RT_PFX + 'RL_DONE:');
  EmitInstrAB('MOV', 'BYTE PTR [EBX+ECX]', '0');
  EmitInstrAB('LEA', 'EAX', VXP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'ECX');
  EmitInstrA('POP', 'EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_POWER : exponentiation EAX^EBX -> EAX }
  EmitComment('POWER : EAX ^ EBX -> EAX (entier)');
  EmitLabel(VXP_RT_PFX + 'POWER');
  EmitInstrA('PUSH', 'ECX');
  EmitInstrA('PUSH', 'EDX');
  EmitInstrAB('MOV', 'ECX', 'EBX');
  EmitInstrAB('MOV', 'EDX', 'EAX');
  EmitInstrAB('MOV', 'EAX', '1');
  EmitInstrAB('CMP', 'ECX', '0');
  EmitInstrA('JLE', VXP_RT_PFX + 'POW_DONE');
  EmitRaw(VXP_RT_PFX + 'POW_LP:');
  EmitInstrA('IMUL', 'EDX');
  EmitInstr('DEC    ECX');
  EmitInstrA('JNZ', VXP_RT_PFX + 'POW_LP');
  EmitRaw(VXP_RT_PFX + 'POW_DONE:');
  EmitInstrA('POP', 'EDX');
  EmitInstrA('POP', 'ECX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_SET_IN : test EAX IN ensemble pointe par ESI }
  EmitComment('SET_IN : test EAX IN set[ESI] -> EAX (0 ou 1)');
  EmitLabel(VXP_RT_PFX + 'SET_IN');
  EmitInstrA('PUSH', 'EBX');
  EmitInstrA('PUSH', 'ECX');
  EmitInstrAB('MOV', 'ECX', 'EAX');
  EmitInstrAB('SHR', 'ECX', '3');
  EmitInstrAB('MOVZX', 'EBX', 'BYTE PTR [ESI+ECX]');
  EmitInstrAB('MOV', 'ECX', 'EAX');
  EmitInstrAB('AND', 'ECX', '7');
  EmitInstrAB('SHR', 'EBX', 'CL');
  EmitInstrAB('AND', 'EBX', '1');
  EmitInstrAB('MOV', 'EAX', 'EBX');
  EmitInstrA('POP', 'ECX');
  EmitInstrA('POP', 'EBX');
  EmitInstr('RET');
  EmitBlankLine;

  { _VXPRT_STRTONUM : convertir chaine ASCIIZ (ESI) -> EAX entier }
  EmitComment('STRTONUM : convertit chaine ESI -> EAX (entier signe)');
  EmitLabel(VXP_RT_PFX + 'STRTONUM');
  EmitInstrA('PUSH', 'EBX');
  EmitInstrA('PUSH', 'ECX');
  EmitInstrA('PUSH', 'EDX');
  EmitInstrAB('XOR', 'EAX', 'EAX');
  EmitInstrAB('XOR', 'ECX', 'ECX');
  EmitInstrAB('MOV', 'EBX', '10');
  EmitRaw('        CMP    BYTE PTR [ESI], ' + Chr(39) + '-' + Chr(39));
  EmitInstrA('JNE', VXP_RT_PFX + 'STN_LP');
  EmitInstr('INC    ESI');
  EmitInstrAB('MOV', 'ECX', '1');
  EmitRaw(VXP_RT_PFX + 'STN_LP:');
  EmitInstrAB('MOVZX', 'EDX', 'BYTE PTR [ESI]');
  EmitRaw('        CMP    EDX, ' + Chr(39) + '0' + Chr(39));
  EmitInstrA('JB', VXP_RT_PFX + 'STN_END');
  EmitRaw('        CMP    EDX, ' + Chr(39) + '9' + Chr(39));
  EmitInstrA('JA', VXP_RT_PFX + 'STN_END');
  EmitRaw('        SUB    EDX, ' + Chr(39) + '0' + Chr(39));
  EmitInstrA('IMUL', 'EBX');
  EmitInstrAB('ADD', 'EAX', 'EDX');
  EmitInstr('INC    ESI');
  EmitInstrA('JMP', VXP_RT_PFX + 'STN_LP');
  EmitRaw(VXP_RT_PFX + 'STN_END:');
  EmitInstrAB('CMP', 'ECX', '1');
  EmitInstrA('JNE', VXP_RT_PFX + 'STN_RET');
  EmitInstr('NEG    EAX');
  EmitRaw(VXP_RT_PFX + 'STN_RET:');
  EmitInstrA('POP', 'EDX');
  EmitInstrA('POP', 'ECX');
  EmitInstrA('POP', 'EBX');
  EmitInstr('RET');
  EmitBlankLine;

  EmitRaw('_TEXT   ENDS');
End;

{ ---- EmitClose : finaliser le fichier de sortie ASM ---------- }
{ Emet le pied de page (EmitFooter), ecrit le segment de        }
{ donnees (EmitDataSeg), ajoute la directive END, puis ferme     }
{ le fichier.                                                    }
Procedure EmitClose;
Begin
  { Emettre le pied de page ASM + runtime }
  EmitFooter;
  { Emettre le segment de donnees }
  EmitDataSeg;
  { Directive END }
  If OutFOpen Then
    EmitRaw('        END     ' + VXP_FN_PFX + 'MAIN');
  { Fermer les fichiers ouverts }
  Cleanup;
End;


{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ParseDeclAttributes, ParseVarAttributes, ParseVarDecl,
  ParseConstDecl
  ============================================================ }

(* ---- ParseDeclAttributes : lire les attributs de haut niveau --- *)
(* Consomme [GLOBAL], [EXTERNAL], [INHERIT('file')],               *)
(* [ENVIRONMENT('name')], [IDENT('name')], etc.                    *)
(* Positionne PendAttrGlobal / PendAttrExternal.                   *)
Procedure ParseDeclAttributes;
Var
  Attr : TString;
  Arg  : TString;
Begin
  PendAttrGlobal   := False;
  PendAttrExternal := False;

  If Not IsOpenBracket Then
    Exit;

  LexNextToken;  (* consommer [ *)
  While (CurToken.Kind <> TK_EOF) And
        Not IsCloseBracket Do
  Begin
    Attr := StrLowerCase(CurToken.Val);

    If Attr = 'global' Then
    Begin
      PendAttrGlobal := True;
      LexNextToken;
    End
    Else If Attr = 'external' Then
    Begin
      PendAttrExternal := True;
      LexNextToken;
    End
    Else If Attr = 'inherit' Then
    Begin
      LexNextToken;  (* consommer INHERIT *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
        Begin
          If CurToken.Kind = TK_STRING Then
          Begin
            Arg := CurToken.Val;
            EmitComment('INHERIT: ' + Arg);
            If (Pos('$', Arg) = 0) And (Pos(':', Arg) = 0) Then
            Begin
              If (Pos('.', Arg) = 0) Then
                Arg := Arg + '.INC';
              {$I-}
              IncludePush(Arg);
              {$I+}
            End;
            LexNextToken;
          End
          Else
            LexNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
    End
    Else If Attr = 'environment' Then
    Begin
      LexNextToken;  (* consommer ENVIRONMENT *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_STRING Then
        Begin
          EnvironmentName := CurToken.Val;
          EmitComment('ENVIRONMENT: ' + EnvironmentName);
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
    End
    Else If Attr = 'ident' Then
    Begin
      LexNextToken;  (* consommer IDENT *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_STRING Then
        Begin
          ModuleIdent := CurToken.Val;
          EmitComment('IDENT: ' + ModuleIdent);
          LexNextToken;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
    End
    Else
    Begin
      LexNextToken;
    End;

    (* virgule entre attributs *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      LexNextToken;
  End;

  (* consommer ] *)
  If IsCloseBracket Then
    LexNextToken;
End;

(* ---- ParseVarAttributes : lire les attributs VAX entre [] ---- *)
(* Retourne les drapeaux via les parametres var.                   *)
(* Attributs supportes : EXTERNAL, GLOBAL, VOLATILE, READONLY,    *)
(*   WRITEONLY, ALIGNED(n), WORD, UNSAFE, HIDDEN, UNBOUND, POS(n) *)
Procedure ParseVarAttributes(
  Var AExternal, AGlobal, AVolatile,
      AReadOnly, AWriteOnly, AWord, AUnsafe,
      AHidden, AUnbound : Boolean;
  Var AAlignVal, APosVal : Integer);
Var
  Attr : TString;
Begin
  AExternal  := False;
  AGlobal    := False;
  AVolatile  := False;
  AReadOnly  := False;
  AWriteOnly := False;
  AWord      := False;
  AUnsafe    := False;
  AHidden    := False;
  AUnbound   := False;
  AAlignVal  := 0;
  APosVal    := -1;

  If Not IsOpenBracket Then
    Exit;

  LexNextToken;  (* consommer [ *)
  While (CurToken.Kind <> TK_EOF) And
        Not IsCloseBracket Do
  Begin
    Attr := StrLowerCase(CurToken.Val);

    If Attr = 'external' Then
      AExternal := True
    Else If Attr = 'global' Then
      AGlobal := True
    Else If Attr = 'volatile' Then
      AVolatile := True
    Else If Attr = 'readonly' Then
      AReadOnly := True
    Else If Attr = 'writeonly' Then
      AWriteOnly := True
    Else If Attr = 'word' Then
      AWord := True
    Else If Attr = 'unsafe' Then
      AUnsafe := True
    Else If Attr = 'hidden' Then
      AHidden := True
    Else If Attr = 'unbound' Then
      AUnbound := True
    Else If Attr = 'aligned' Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          AAlignVal := CurToken.IntVal;
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
          APosVal := CurToken.IntVal;
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
  HasPendingAssign := False;

  IsStaticVar   := False;
  IsExternalVar := False;

  While (CurToken.Kind = TK_IDENT) Or IsOpenBracket Do
  Begin
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

    (* After VAX attributes, there may be the keyword VAR *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'var') Then
      LexNextToken;

    (* Detect STATIC or EXTERNAL after attributes *)
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

    (* Propagate pending attributes from ParseDeclAttributes *)
    If PendAttrGlobal Then
      AttrGlobal := True;
    If PendAttrExternal Then
      AttrExternal := True;

    (* First identifier *)
    If CurToken.Kind <> TK_IDENT Then Break;
    Names[0] := CurToken.Val;
    NCount := 1;
    LexNextToken;

    (* If := follows, this is an assignment, not a var declaration *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      PendingAssignName := Names[0];
      HasPendingAssign  := True;
      Exit;
    End;

    (* Collect additional names separated by commas *)
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

    (* Colon + type name *)
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

    (* Determine the symbol category *)
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

    (* --- Pointer ^Type detection --- *)
    IsPtr := False;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
    Begin
      IsPtr := True;
      LexNextToken;
    End;

    (* --- Procedure/Function pointer variable --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       ((StrLowerCase(CurToken.Val) = 'procedure') Or
        (StrLowerCase(CurToken.Val) = 'function')) Then
    Begin
      LexNextToken;  (* consume PROCEDURE/FUNCTION *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = ')')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        LexNextToken;
        If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
          LexNextToken;
      End;
      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], UseCat, TY_IDX_POINTER);
        If Idx >= 0 Then
        Begin
          If (CurScopeLevel = 0) Or (UseCat = SC_STATIC) Or
             (UseCat = SC_GLOBAL) Or (UseCat = SC_EXTERNAL) Then
          Begin
            SymTab[Idx].IsLocal := False;
            If UseCat = SC_EXTERNAL Then
              EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':DWORD')
            Else
            Begin
              DIdx := DataAdd(SymTab[Idx].MangledName, DK_DWORD, 0, '');
              SymTab[Idx].DataIdx := DIdx;
            End;
          End
          Else
          Begin
            Dec(CurFrameOffset, 4);
            If (CurFrameOffset And 3) <> 0 Then
              CurFrameOffset := CurFrameOffset And (Not 3);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
          End;
          If Opts.DebugMode Then
            WriteLn('  VAR_PROCPTR: ', Names[I], ' -> pointer');
        End;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- VARYING [n] OF CHAR detection --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'varying') Then
    Begin
      LexNextToken;  (* consume VARYING *)
      VaryLen := 80;  (* default *)
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
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
        LexNextToken;

      NewVaryTIdx := TY_IDX_VARYING;
      If TypeCount < MAX_TYPE Then
      Begin
        NewVaryTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewVaryTIdx].Kind        := TKP_VARYING;
        TypeTab[NewVaryTIdx].Size        := 4 + VaryLen;
        TypeTab[NewVaryTIdx].Hi          := VaryLen;
        TypeTab[NewVaryTIdx].Lo          := 0;
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
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':DWORD');
            If Opts.DebugMode Then
              WriteLn('  VAR_EXTERNAL: ', Names[I],
                      ' : VARYING[', VaryLen, ']');
          End
          Else If (CurScopeLevel = 0) Or (UseCat = SC_STATIC) Then
          Begin
            SymTab[Idx].IsLocal := False;
            DIdx := DataAddArray(SymTab[Idx].MangledName,
              4 + VaryLen, 1);
            SymTab[Idx].DataIdx := DIdx;
            If Opts.DebugMode Then
              WriteLn('  VAR_VARYING_GLOBAL: ', Names[I],
                      ' VARYING[', VaryLen, '] -> ',
                      SymTab[Idx].MangledName);
          End
          Else
          Begin
            Dec(CurFrameOffset, 4 + VaryLen);
            If (CurFrameOffset And 3) <> 0 Then
              CurFrameOffset := CurFrameOffset And (Not 3);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_VARYING_LOCAL: ', Names[I],
                      ' VARYING[', VaryLen, '] -> [EBP',
                      CurFrameOffset, ']');
          End;
        End;
      End;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- SET OF type (inline) detection --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'set') Then
    Begin
      LexNextToken;  (* consume SET *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        LexNextToken;
      TName := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        TName := CurToken.Val;
        LexNextToken;
      End;
      BaseTIdx := TypeResolve(TName);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;
      NewPtrTIdx := TY_IDX_SET;
      If TypeCount < MAX_TYPE Then
      Begin
        NewPtrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewPtrTIdx].Kind        := TKP_SET;
        TypeTab[NewPtrTIdx].Size        := 32;
        TypeTab[NewPtrTIdx].BaseTypeIdx := BaseTIdx;
        TypeTab[NewPtrTIdx].Lo          := 0;
        TypeTab[NewPtrTIdx].Hi          := 255;
        TypeTab[NewPtrTIdx].FieldCount  := 0;
        TypeTab[NewPtrTIdx].EnumCount   := 0;
        TypeTab[NewPtrTIdx].Packed_     := False;
        TypeTab[NewPtrTIdx].Precision   := 0;
      End;
      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], UseCat, NewPtrTIdx);
        If Idx >= 0 Then
        Begin
          If (CurScopeLevel = 0) Or (UseCat = SC_STATIC) Or
             (UseCat = SC_GLOBAL) Then
          Begin
            SymTab[Idx].IsLocal := False;
            DIdx := DataAdd(SymTab[Idx].MangledName, DK_SET, 0, '');
            SymTab[Idx].DataIdx := DIdx;
            If UseCat = SC_GLOBAL Then
              EmitInstr('PUBLIC ' + SymTab[Idx].MangledName);
            If Opts.DebugMode Then
              WriteLn('  VAR_SET_GLOBAL: ', Names[I],
                      ' -> ', SymTab[Idx].MangledName);
          End
          Else If UseCat = SC_EXTERNAL Then
          Begin
            SymTab[Idx].IsLocal := False;
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':BYTE');
            If Opts.DebugMode Then
              WriteLn('  VAR_SET_EXTERNAL: ', Names[I]);
          End
          Else
          Begin
            Dec(CurFrameOffset, 32);
            If (CurFrameOffset And 3) <> 0 Then
              CurFrameOffset := CurFrameOffset And (Not 3);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_SET_LOCAL: ', Names[I],
                      ' -> [EBP', CurFrameOffset, ']');
          End;
        End;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- ARRAY[lo..hi] OF type detection --- *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      LexNextToken;  (* consume ARRAY *)

      If IsOpenBracket Then
        LexNextToken
      Else
        WarnMsg('''['' attendu apres ARRAY');

      (* Lower bound *)
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

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        LexNextToken
      Else
        WarnMsg('''..'' attendu dans declaration ARRAY');

      (* Upper bound - support * for conformant arrays *)
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
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':DWORD');
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
            If (CurFrameOffset And 3) <> 0 Then
              CurFrameOffset := CurFrameOffset And (Not 3);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_LOCAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> [EBP',
                      CurFrameOffset, ']');
          End;
        End;
      End;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* --- Read standard type or identifier --- *)
    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      LexNextToken;
    End
    Else
      WarnMsg('nom de type attendu');

    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;
    End;
    TSz := TypeSizeof(TIdx);

    (* If pointer, create a pointer type *)
    If IsPtr Then
    Begin
      BaseTIdx := TIdx;
      NewPtrTIdx := TY_IDX_POINTER;
      If TypeCount < MAX_TYPE Then
      Begin
        NewPtrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewPtrTIdx].Kind        := TKP_POINTER;
        TypeTab[NewPtrTIdx].Size        := 4;
        TypeTab[NewPtrTIdx].BaseTypeIdx := BaseTIdx;
        TypeTab[NewPtrTIdx].FieldCount  := 0;
        TypeTab[NewPtrTIdx].EnumCount   := 0;
      End;
      TIdx := NewPtrTIdx;
      TSz  := 4;
    End;

    If AttrWord Then TSz := 4;

    (* Register each variable *)
    For I := 0 To NCount - 1 Do
    Begin
      Idx := SymAdd(Names[I], UseCat, TIdx);
      If Idx >= 0 Then
      Begin
        (* EXTERNAL variable : declare EXTRN *)
        If (UseCat = SC_EXTERNAL) Then
        Begin
          SymTab[Idx].IsLocal := False;
          If TSz = 1 Then
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':BYTE')
          Else
            EmitInstr('EXTRN  ' + SymTab[Idx].MangledName + ':DWORD');
          If Opts.DebugMode Then
            WriteLn('  VAR_EXTERNAL: ', Names[I], ' : ', TName);
        End
        (* GLOBAL variable : mark PUBLIC *)
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
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  (TypeTab[TIdx].Kind = TKP_SET) Then
            DIdx := DataAdd(SymTab[Idx].MangledName, DK_SET, 0, '')
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  ((TypeTab[TIdx].Kind = TKP_TEXT) Or
                   (TypeTab[TIdx].Kind = TKP_FILE)) Then
            DIdx := DataAddRec(SymTab[Idx].MangledName, FILE_DESC_SIZE)
          Else If TSz = 1 Then
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0)
          Else
            DIdx := DataAddDWord(SymTab[Idx].MangledName, 0);
          SymTab[Idx].DataIdx := DIdx;
          EmitInstr('PUBLIC ' + SymTab[Idx].MangledName);
          If Opts.DebugMode Then
            WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                    ' -> ', SymTab[Idx].MangledName);
        End
        (* STATIC variable : in .DATA *)
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
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  (TypeTab[TIdx].Kind = TKP_SET) Then
            DIdx := DataAdd(SymTab[Idx].MangledName, DK_SET, 0, '')
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  ((TypeTab[TIdx].Kind = TKP_TEXT) Or
                   (TypeTab[TIdx].Kind = TKP_FILE)) Then
            DIdx := DataAddRec(SymTab[Idx].MangledName, FILE_DESC_SIZE)
          Else If TSz = 1 Then
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0)
          Else
            DIdx := DataAddDWord(SymTab[Idx].MangledName, 0);
          SymTab[Idx].DataIdx := DIdx;
          If Opts.DebugMode Then
            WriteLn('  VAR_STATIC: ', Names[I], ' : ', TName,
                    ' -> ', SymTab[Idx].MangledName);
        End
        (* Standard global variable *)
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
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  (TypeTab[TIdx].Kind = TKP_SET) Then
          Begin
            DIdx := DataAdd(SymTab[Idx].MangledName, DK_SET, 0, '');
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_SET_GLOBAL: ', Names[I], ' : ',
                      TName, ' -> ', SymTab[Idx].MangledName);
          End
          Else If (TIdx >= 0) And (TIdx < TypeCount) And
                  ((TypeTab[TIdx].Kind = TKP_TEXT) Or
                   (TypeTab[TIdx].Kind = TKP_FILE)) Then
          Begin
            DIdx := DataAddRec(SymTab[Idx].MangledName, FILE_DESC_SIZE);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_FILE_GLOBAL: ', Names[I], ' : ',
                      TName, ' -> ', SymTab[Idx].MangledName);
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
            DIdx := DataAddDWord(SymTab[Idx].MangledName, 0);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                      ' -> ', SymTab[Idx].MangledName);
          End;
        End
        Else
        Begin
          (* Local variable : allocate on stack *)
          If TSz < 4 Then TSz := 4;
          Dec(CurFrameOffset, TSz);
          If (CurFrameOffset And 3) <> 0 Then
            CurFrameOffset := CurFrameOffset And (Not 3);
          SymTab[Idx].Offset  := CurFrameOffset;
          SymTab[Idx].IsLocal := True;
          If Opts.DebugMode Then
            WriteLn('  VAR_LOCAL: ', Names[I], ' : ', TName,
                    ' -> [EBP', CurFrameOffset, ']');
        End;
      End;
    End;

    (* Optional initialization := value *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      LexNextToken;  (* consume := *)
      ParseExpr(InitEv);
      If (Idx >= 0) And Not SymTab[Idx].IsLocal Then
      Begin
        If (InitEv.Kind = EK_IMM) Then
        Begin
          If SymTab[Idx].DataIdx >= 0 Then
            DataTab[SymTab[Idx].DataIdx].IntVal := InitEv.ImmVal;
        End
        Else
        Begin
          ExprFlushToEAX(InitEv);
          If TypeSizeof(SymTab[Idx].TypeIdx) = 1 Then
            EmitInstrAB('MOV',
              'BYTE PTR [' + SymTab[Idx].MangledName + ']', 'AL')
          Else
            EmitInstrAB('MOV',
              'DWORD PTR [' + SymTab[Idx].MangledName + ']', 'EAX');
        End;
      End
      Else If (Idx >= 0) And SymTab[Idx].IsLocal Then
      Begin
        ExprFlushToEAX(InitEv);
        If TypeSizeof(SymTab[Idx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR ' + EBPOfs(SymTab[Idx].Offset), 'AL')
        Else
          EmitInstrAB('MOV',
            'DWORD PTR ' + EBPOfs(SymTab[Idx].Offset), 'EAX');
      End;
    End;

    (* Semicolon *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

(* ---- ParseConstDecl : analyser un bloc CONST ------------------- *)
(* Supporte :                                                        *)
(*   const x = 42;             (untyped constant)                    *)
(*   const x := 42;            (VAX typed const with :=)             *)
(*   const x : Type = value;   (typed constant)                      *)
(*   const tab : ARRAY[lo..hi] OF type = (v1, v2, ...);             *)
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
  While CurToken.Kind = TK_IDENT Do
  Begin
    CName := CurToken.Val;
    LexNextToken;

    (* const x = value (standard Pascal, untyped const) *)
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
        WarnMsg('constante attendue pour ' + CName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* const x := value (VAX Pascal typed const with :=) *)
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
          DIdx := DataAddDWord(SymTab[CIdx].MangledName,
            ConstEv.ImmVal);
          SymTab[CIdx].DataIdx := DIdx;
        End;
      End
      Else
        WarnMsg('constante attendue pour const := ' + CName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* const x : type = value (typed const standard) *)
    (* const tab : ARRAY[lo..hi] OF type = (v1, v2, ...); *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      LexNextToken;

      (* --- ARRAY[lo..hi] OF type = (values) detection --- *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'array') Then
      Begin
        LexNextToken;  (* consume ARRAY *)
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

        (* Create the array type *)
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

        (* Consume = *)
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          LexNextToken;

        (* Parse initial values (val1, val2, ...) *)
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
          ConstInitStr := '';
          For ConstInitCount := 1 To ConstArrCount Do
          Begin
            If ConstInitCount > 1 Then
              ConstInitStr := ConstInitStr + ',';
            ConstInitStr := ConstInitStr + '0';
          End;
        End;

        (* Create symbol and data entry *)
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

      (* --- Typed const simple : type = value --- *)
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
          DIdx := DataAddDWord(SymTab[CIdx].MangledName,
            ConstEv.ImmVal);
          SymTab[CIdx].DataIdx := DIdx;
        End;
      End
      Else
        WarnMsg('constante attendue pour typed const ' + CName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* Unrecognized token in CONST block, exit *)
    Break;
  End;
End;


{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

(* ---- ParseAssignment : analyser une affectation --------------- *)
(* Syntaxe : ident := expr ;                                       *)
(* Le nom de la variable a ete lu par l appelant.                  *)
(* CurToken est sur := ou . ou ^ ou [                              *)
Procedure ParseAssignment(Const VarName : TString);
Var
  SIdx       : Integer;
  Ev         : TExprVal;
  FieldName  : TString;
  FI, FIdx   : Integer;
  FTIdx      : Integer;
  ArrEv      : TExprVal;
  WI         : Integer;
  WIdx       : Integer;
  RecTIdx    : Integer;
  FldIdx     : Integer;
  FldTIdx2   : Integer;
  FldSz      : Integer;
  HasSliceLen: Boolean;
  ESize      : Integer;
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
    ExprFlushToEAX(Ev);
    EmitInstrAB('MOV',
      'DWORD PTR ' + EBPOfs(CurFuncRetOfs), 'EAX');
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
        If (RecTIdx >= 0) And (RecTIdx < TypeCount) And
           (TypeTab[RecTIdx].Kind = TKP_RECORD) Then
        Begin
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(VarName) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
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
        ExprFlushToEAX(Ev);
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'EBX',
            EBPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'EBX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'EBX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        FldTIdx2 := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz := TypeSizeof(FldTIdx2);
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
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
      WarnMsg(''':='' attendu pour l''affectation de champ');
      Exit;
    End;

    EmitComment('assign ' + VarName + '.' + FieldName);
    ParseExpr(Ev);
    ExprFlushToEAX(Ev);

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
        EmitInstrAB('MOV', 'EBX',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
        If TypeTab[FTIdx].Fields[FIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'EBX',
            IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
        FldSz := TypeSizeof(TypeTab[FTIdx].Fields[FIdx].TypeIdx);
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
      End
      Else
      Begin
        FldSz := TypeSizeof(TypeTab[FTIdx].Fields[FIdx].TypeIdx);
        If FldSz = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR ' + EBPOfs(SymTab[SIdx].Offset +
              TypeTab[FTIdx].Fields[FIdx].Offset), 'AL')
        Else
          EmitInstrAB('MOV',
            'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset +
              TypeTab[FTIdx].Fields[FIdx].Offset), 'EAX');
      End;
    End
    Else
    Begin
      If TypeTab[FTIdx].Fields[FIdx].Offset = 0 Then
      Begin
        FldSz := TypeSizeof(TypeTab[FTIdx].Fields[FIdx].TypeIdx);
        If FldSz = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
        Else
          EmitInstrAB('MOV',
            'DWORD PTR [' + SymTab[SIdx].MangledName + ']', 'EAX');
      End
      Else
      Begin
        EmitInstrAB('MOV', 'EBX',
          'OFFSET ' + SymTab[SIdx].MangledName);
        EmitInstrAB('ADD', 'EBX',
          IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
        FldSz := TypeSizeof(TypeTab[FTIdx].Fields[FIdx].TypeIdx);
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* --- Acces pointeur dereference : p^ := expr ou p^.f := expr --- *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
  Begin
    LexNextToken;

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
      ExprFlushToEAX(Ev);

      (* Charger le pointeur *)
      If SymTab[SIdx].IsLocal Then
        EmitInstrAB('MOV', 'EBX',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset))
      Else
        EmitInstrAB('MOV', 'EBX',
          'DWORD PTR [' + SymTab[SIdx].MangledName + ']');
      If Opts.CheckEnabled Then
      Begin
        EmitInstrAB('TEST', 'EBX', 'EBX');
        EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_NIL');
      End;

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
        EmitInstrAB('ADD', 'EBX',
          IntToStr(TypeTab[FTIdx].Fields[FIdx].Offset));
      EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* p^[i] := expr -- tableau via pointeur *)
    If IsOpenBracket Then
    Begin
      LexNextToken;
      EmitComment('assign ' + VarName + '^[i]');

      ParseExpr(ArrEv);
      ExprFlushToEAX(ArrEv);
      EmitPush('EAX');

      If IsCloseBracket Then
        LexNextToken;

      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        LexNextToken
      Else
        WarnMsg(''':='' attendu');

      ParseExpr(Ev);
      ExprFlushToEAX(Ev);
      EmitPush('EAX');

      (* Charger le pointeur *)
      If SymTab[SIdx].IsLocal Then
        EmitInstrAB('MOV', 'EBX',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset))
      Else
        EmitInstrAB('MOV', 'EBX',
          'DWORD PTR [' + SymTab[SIdx].MangledName + ']');
      If Opts.CheckEnabled Then
      Begin
        EmitInstrAB('TEST', 'EBX', 'EBX');
        EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_NIL');
      End;

      (* Calculer l adresse : EBX + index * 4 *)
      EmitPop('ECX');
      EmitPop('EAX');
      EmitInstrAB('SHL', 'EAX', '2');
      EmitInstrAB('ADD', 'EBX', 'EAX');
      EmitInstrAB('MOV', 'EAX', 'ECX');
      EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');

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
    ExprFlushToEAX(Ev);

    If SymTab[SIdx].IsLocal Then
      EmitInstrAB('MOV', 'EBX',
        'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset))
    Else
      EmitInstrAB('MOV', 'EBX',
        'DWORD PTR [' + SymTab[SIdx].MangledName + ']');
    If Opts.CheckEnabled Then
    Begin
      EmitInstrAB('TEST', 'EBX', 'EBX');
      EmitInstrA('JZ', VXP_RT_PFX + 'PANIC_NIL');
    End;
    EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* --- Acces tableau / sous-chaine : ident[index] := expr --- *)
  If IsOpenBracket Then
  Begin
    LexNextToken;

    FTIdx := SymTab[SIdx].TypeIdx;
    (* --- Affectation sous-chaine VAX : s[pos:len] := expr ou s[pos] := ch --- *)
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       ((TypeTab[FTIdx].Kind = TKP_STRING) Or
        (TypeTab[FTIdx].Kind = TKP_VARYING)) Then
    Begin
      EmitComment('assign ' + VarName + '[substring]');
      ParseExpr(ArrEv);
      ExprFlushToEAX(ArrEv);
      EmitPush('EAX');

      HasSliceLen := False;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        LexNextToken;
        ParseExpr(ArrEv);
        ExprFlushToEAX(ArrEv);
        EmitPush('EAX');
        HasSliceLen := True;
      End;

      If IsCloseBracket Then
        LexNextToken
      Else
        WarnMsg(''']'' attendu apres substring');

      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        LexNextToken
      Else
      Begin
        WarnMsg(''':='' attendu');
        If HasSliceLen Then EmitPop('ECX');
        EmitPop('EBX');
        Exit;
      End;

      ParseExpr(Ev);
      ExprFlushToEAX(Ev);

      If HasSliceLen Then
      Begin
        EmitInstrAB('MOV', 'ESI', 'EAX');
        EmitPop('ECX');
        EmitPop('EBX');
        If SymTab[SIdx].IsLocal Then
          EmitInstrAB('LEA', 'EDI',
            EBPOfs(SymTab[SIdx].Offset))
        Else
          EmitInstrAB('MOV', 'EDI',
            'OFFSET ' + SymTab[SIdx].MangledName);
        EmitInstrA('CALL', VXP_RT_PFX + 'SSLICE');
      End
      Else
      Begin
        EmitPop('EBX');
        EmitInstr('DEC    EBX');
        If SymTab[SIdx].IsLocal Then
          EmitInstrAB('LEA', 'EDI',
            EBPOfs(SymTab[SIdx].Offset))
        Else
          EmitInstrAB('MOV', 'EDI',
            'OFFSET ' + SymTab[SIdx].MangledName);
        EmitInstrAB('ADD', 'EDI', 'EBX');
        EmitInstrAB('MOV', 'BYTE PTR [EDI]', 'AL');
      End;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* --- Acces tableau classique : arr[index] := expr --- *)
    EmitComment('assign ' + VarName + '[i]');
    ParseExpr(ArrEv);
    ExprFlushToEAX(ArrEv);

    (* Soustraire la borne inferieure *)
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) And
       (TypeTab[FTIdx].Lo <> 0) Then
      EmitInstrAB('SUB', 'EAX', IntToStr(TypeTab[FTIdx].Lo));

    (* Multiplier par la taille element *)
    ESize := 4;
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) Then
    Begin
      ESize := TypeSizeof(TypeTab[FTIdx].BaseTypeIdx);
      If ESize = 4 Then
        EmitInstrAB('SHL', 'EAX', '2')
      Else If ESize = 2 Then
        EmitInstrAB('SHL', 'EAX', '1')
      Else If ESize > 4 Then
      Begin
        EmitInstrAB('MOV', 'ECX', IntToStr(ESize));
        EmitInstrAB('IMUL', 'EAX', 'ECX');
      End;
      (* ESize = 1 : no multiply needed *)
    End
    Else
      EmitInstrAB('SHL', 'EAX', '2');

    EmitPush('EAX');

    If IsCloseBracket Then
      LexNextToken;

    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      LexNextToken
    Else
    Begin
      WarnMsg(''':='' attendu');
      EmitPop('EBX');
      Exit;
    End;

    ParseExpr(Ev);
    ExprFlushToEAX(Ev);

    EmitPop('EBX');

    (* Calculer adresse base + offset *)
    If SymTab[SIdx].IsLocal Then
    Begin
      If SymTab[SIdx].Cat = SC_VARPARAM Then
      Begin
        EmitInstrAB('MOV', 'ECX',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
        EmitInstrAB('ADD', 'EBX', 'ECX');
      End
      Else
      Begin
        EmitInstrAB('LEA', 'ESI',
          EBPOfs(SymTab[SIdx].Offset));
        EmitInstrAB('ADD', 'EBX', 'ESI');
      End;
    End
    Else
    Begin
      EmitInstrAB('ADD', 'EBX',
        'OFFSET ' + SymTab[SIdx].MangledName);
    End;
    (* Ecriture selon la taille de l element *)
    If (FTIdx >= 0) And (FTIdx < TypeCount) And
       (TypeTab[FTIdx].Kind = TKP_ARRAY) And
       (TypeSizeof(TypeTab[FTIdx].BaseTypeIdx) = 1) Then
      EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
    Else
      EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');

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

  ExprFlushToEAX(Ev);

  (* Stocker EAX dans la cible *)
  If IsSetTypeIdx(SymTab[SIdx].TypeIdx) Then
  Begin
    (* Affectation ensemble : copier 32 octets via SET_COPY *)
    EmitInstrAB('MOV', 'ESI', 'EAX');
    If SymTab[SIdx].IsLocal Then
      EmitInstrAB('LEA', 'EDI',
        EBPOfs(SymTab[SIdx].Offset))
    Else
      EmitInstrAB('MOV', 'EDI',
        'OFFSET ' + SymTab[SIdx].MangledName);
    EmitInstrA('CALL', VXP_RT_PFX + 'SET_COPY');
  End
  Else If SymTab[SIdx].IsLocal Then
  Begin
    If SymTab[SIdx].Cat = SC_VARPARAM Then
    Begin
      EmitInstrAB('MOV', 'EBX',
        'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
      EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
    End
    Else
    Begin
      If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
        EmitInstrAB('MOV',
          'BYTE PTR ' + EBPOfs(SymTab[SIdx].Offset), 'AL')
      Else
        EmitInstrAB('MOV',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset), 'EAX');
    End;
  End
  Else
  Begin
    If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
      EmitInstrAB('MOV',
        'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
    Else
      EmitInstrAB('MOV',
        'DWORD PTR [' + SymTab[SIdx].MangledName + ']', 'EAX');
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
      ExprFlushToEAX(Ev);
      If SymTab[SIdx].IsLocal Then
      Begin
        If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR ' + EBPOfs(SymTab[SIdx].Offset), 'AL')
        Else
          EmitInstrAB('MOV',
            'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset), 'EAX');
      End
      Else
      Begin
        If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
          EmitInstrAB('MOV',
            'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
        Else
          EmitInstrAB('MOV',
            'DWORD PTR [' + SymTab[SIdx].MangledName + ']', 'EAX');
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

(* ---- ParseStatement : analyser une instruction ---------------  *)
Procedure ParseStatement;
Var
  StId     : TString;
  StLw     : TString;
  StIdx    : Integer;
  StEv     : TExprVal;
  StArgCnt : Integer;
Begin
  (* Empty statement *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    LexNextToken;
    Exit;
  End;

  (* BEGIN..END block *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'begin') Then
  Begin
    ParseBlock;
    Exit;
  End;

  (* Numeric label : 100: stmt *)
  If CurToken.Kind = TK_INTEGER Then
  Begin
    StId := IntToStr(CurToken.IntVal);
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      LexNextToken;
      EmitLabel(VXP_LBL_PFX + 'USR_' + StId);
    End;
    Exit;
  End;

  (* Keyword statements *)
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    StLw := StrLowerCase(CurToken.Val);

    (* EXIT *)
    If StLw = 'exit' Then
    Begin
      LexNextToken;
      If CurRetLabel <> '' Then
        EmitInstrA('JMP', CurRetLabel)
      Else
        EmitInstrA('JMP', VXP_LBL_PFX + 'EXIT');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* BREAK *)
    If StLw = 'break' Then
    Begin
      LexNextToken;
      If (LoopTop > 0) And (LoopBreakLbl[LoopTop - 1] <> '') Then
        EmitInstrA('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        WarnMsg('BREAK en dehors d''une boucle');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* CONTINUE *)
    If StLw = 'continue' Then
    Begin
      LexNextToken;
      If (LoopTop > 0) And (LoopContLbl[LoopTop - 1] <> '') Then
        EmitInstrA('JMP', LoopContLbl[LoopTop - 1])
      Else
        WarnMsg('CONTINUE en dehors d''une boucle');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* GOTO *)
    If StLw = 'goto' Then
    Begin
      LexNextToken;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        EmitInstrA('JMP', VXP_LBL_PFX + 'USR_' + IntToStr(CurToken.IntVal));
        LexNextToken;
      End
      Else If CurToken.Kind = TK_IDENT Then
      Begin
        EmitInstrA('JMP', VXP_LBL_PFX + 'USR_' + CurToken.Val);
        LexNextToken;
      End
      Else
        WarnMsg('etiquette attendue apres GOTO');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* RETURN *)
    If StLw = 'return' Then
    Begin
      LexNextToken;
      (* Optional return value *)
      If Not ((CurToken.Kind = TK_PUNCT) And
              ((CurToken.Val = ';') Or (CurToken.Val = '}'))) And
         Not ((CurToken.Kind = TK_KEYWORD) And
              (StrLowerCase(CurToken.Val) = 'end')) Then
      Begin
        ParseExpr(StEv);
        ExprFlushToEAX(StEv);
      End;
      If CurRetLabel <> '' Then
        EmitInstrA('JMP', CurRetLabel)
      Else
        EmitInstrA('JMP', VXP_LBL_PFX + 'EXIT');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* HALT / STOP *)
    If (StLw = 'halt') Or (StLw = 'stop') Then
    Begin
      LexNextToken;
      (* Optional exit code *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        ParseExpr(StEv);
        ExprFlushToEAX(StEv);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        EmitPush('EAX');
      End
      Else
      Begin
        EmitPush('0');
      End;
      EmitInstrA('CALL', '_ExitProcess@4');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* WRITE / WRITELN - stub for TODO 12 *)
    If (StLw = 'write') Or (StLw = 'writeln') Then
    Begin
      WarnMsg(StLw + ' ignore (TODO 12)');
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
      Exit;
    End;

    (* READ / READLN - stub for TODO 12 *)
    If (StLw = 'read') Or (StLw = 'readln') Then
    Begin
      WarnMsg(StLw + ' ignore (TODO 12)');
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
      Exit;
    End;

    (* OPEN / CLOSE / RESET / REWRITE - stub for TODO 12 *)
    If (StLw = 'open') Or (StLw = 'close') Or
       (StLw = 'reset') Or (StLw = 'rewrite') Then
    Begin
      WarnMsg(StLw + ' ignore (TODO 12)');
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
      Exit;
    End;

    (* NEW / DISPOSE - heap stubs *)
    If (StLw = 'new') Or (StLw = 'dispose') Then
    Begin
      WarnMsg(StLw + ' ignore (TODO ulterieur)');
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
      Exit;
    End;

    (* Future TODO stubs: IF, CASE, FOR, WHILE, REPEAT, LOOP, WITH *)
    If (StLw = 'if') Or (StLw = 'case') Or (StLw = 'for') Or
       (StLw = 'while') Or (StLw = 'repeat') Or (StLw = 'loop') Or
       (StLw = 'with') Then
    Begin
      WarnMsg(StLw + ' ignore (TODO ulterieur)');
      LexNextToken;
      (* Skip until ; or END *)
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 (StrLowerCase(CurToken.Val) = 'end')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* Other keywords : skip *)
    If (StLw = 'function') Or (StLw = 'procedure') Or
       (StLw = 'var') Or (StLw = 'const') Or (StLw = 'type') Or
       (StLw = 'label') Then
    Begin
      WarnMsg('declaration ' + StLw + ' dans un bloc (ignore)');
      LexNextToken;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* END - do not consume, let ParseBlock handle it *)
    If StLw = 'end' Then
      Exit;

    (* Unknown keyword - skip *)
    WarnMsg('instruction non geree: ' + CurToken.Val);
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
    Exit;
  End;

  (* Identifier : could be label, procedure call, or assignment *)
  If CurToken.Kind = TK_IDENT Then
  Begin
    StId := CurToken.Val;
    LexNextToken;

    (* Identifier label : ident: stmt *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      StIdx := SymFind(StId);
      If (StIdx >= 0) And (SymTab[StIdx].Cat = SC_LABEL) Then
      Begin
        EmitLabel(VXP_LBL_PFX + 'USR_' + StId);
        LexNextToken;
        Exit;
      End;
      (* Could also be : after ident in other context,
         fall through to assignment *)
    End;

    (* Assignment or procedure call *)
    StIdx := SymFind(StId);

    (* Procedure call without parens *)
    If (StIdx >= 0) And (SymTab[StIdx].Cat = SC_PROC) And
       Not ((CurToken.Kind = TK_OP) And (CurToken.Val = ':=')) And
       Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.')) And
       Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '^')) And
       Not IsOpenBracket Then
    Begin
      EmitComment('call ' + StId);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        LexNextToken;
        StArgCnt := 0;
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
        Begin
          Repeat
            ParseExpr(StEv);
            ExprFlushToEAX(StEv);
            EmitPush('EAX');
            Inc(StArgCnt);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              LexNextToken
            Else
              Break;
          Until False;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          LexNextToken;
        EmitInstrA('CALL', SymTab[StIdx].MangledName);
        If StArgCnt > 0 Then
          EmitInstrAB('ADD', 'ESP', IntToStr(StArgCnt * 4));
      End
      Else
        EmitInstrA('CALL', SymTab[StIdx].MangledName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* Function call without parens *)
    If (StIdx >= 0) And (SymTab[StIdx].Cat = SC_FUNC) And
       (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      EmitComment('call func ' + StId);
      LexNextToken;
      StArgCnt := 0;
      If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
      Begin
        Repeat
          ParseExpr(StEv);
          ExprFlushToEAX(StEv);
          EmitPush('EAX');
          Inc(StArgCnt);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            LexNextToken
          Else
            Break;
        Until False;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        LexNextToken;
      EmitInstrA('CALL', SymTab[StIdx].MangledName);
      If StArgCnt > 0 Then
        EmitInstrAB('ADD', 'ESP', IntToStr(StArgCnt * 4));
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Exit;
    End;

    (* Otherwise : assignment *)
    ParseAssignment(StId);
    Exit;
  End;

  (* Skip unknown token *)
  If CurToken.Kind <> TK_EOF Then
  Begin
    LexNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      LexNextToken;
  End;
End;

(* ---- ParseBlock : analyser un bloc BEGIN..END ---------------  *)
Procedure ParseBlock;
Begin
  LexNextToken;  (* consommer BEGIN *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             (StrLowerCase(CurToken.Val) = 'end')) Do
  Begin
    ParseStatement;
    (* Skip extra semicolons *)
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      LexNextToken;
  End;
  If (CurToken.Kind = TK_KEYWORD) And
     (StrLowerCase(CurToken.Val) = 'end') Then
    LexNextToken;
End;


{ ============================================================
  PROCEDURE PRINCIPALE (Run)
  ============================================================ }

Procedure Run;
Var
  EnvIncF     : Text;
  EnvIncFName : TString;
  EnvI        : Integer;
  Idx         : Integer;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  { Verifier que le fichier source existe }
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened  := True;
  LexSrcFName := Opts.SrcFile;

  { Ouvrir le fichier de sortie ASM }
  EmitOpen;

  { Emettre l en-tete ASM (.386 / .MODEL FLAT / EXTRN) }
  EmitHeader;

  { Initialiser la table des symboles }
  SymInit;

  { Initialiser le systeme de types }
  TypeInit;

  { Initialiser le lexeur }
  LexInit;

  { Mode debug -d : afficher tous les tokens et quitter }
  If Opts.DebugMode Then
  Begin
    LexNextToken;
    While CurToken.Kind <> TK_EOF Do
      LexNextToken;
    LexClose;
    EmitClose;
    If ErrorCount > 0 Then
      Halt(EXIT_ERROR)
    Else
      Halt(EXIT_OK);
    Exit;
  End;

  { Boucle principale de compilation }
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
  Begin
    (* PROGRAM header *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'program') Then
    Begin
      LexNextToken;  (* consume PROGRAM *)
      If CurToken.Kind = TK_IDENT Then
        LexNextToken;  (* program name *)
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
      LexNextToken;  (* consume VAR *)
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
      LexNextToken;  (* consume STATIC *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
      Begin
        LexNextToken;  (* consume VAR *)
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

    (* EXTERNAL VAR/PROCEDURE/FUNCTION *)
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
      Else If (CurToken.Kind = TK_KEYWORD) And
              (StrLowerCase(CurToken.Val) = 'function') Then
      Begin
        PendAttrExternal := True;
        WarnMsg('EXTERNAL FUNCTION ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrExternal := False;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And
              (StrLowerCase(CurToken.Val) = 'procedure') Then
      Begin
        PendAttrExternal := True;
        WarnMsg('EXTERNAL PROCEDURE ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrExternal := False;
      End
      Else
        LexNextToken;
      Continue;
    End;

    (* GLOBAL VAR/PROCEDURE/FUNCTION *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'global') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'function') Then
      Begin
        PendAttrGlobal := True;
        WarnMsg('GLOBAL FUNCTION ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal := False;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And
              (StrLowerCase(CurToken.Val) = 'procedure') Then
      Begin
        PendAttrGlobal := True;
        WarnMsg('GLOBAL PROCEDURE ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal := False;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And
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

    (* PUBLIC PROCEDURE/FUNCTION *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'public') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'function') Then
      Begin
        PendAttrGlobal := True;
        WarnMsg('PUBLIC FUNCTION ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal := False;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And
              (StrLowerCase(CurToken.Val) = 'procedure') Then
      Begin
        PendAttrGlobal := True;
        WarnMsg('PUBLIC PROCEDURE ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal := False;
      End
      Else
        LexNextToken;
      Continue;
    End;

    (* VALUE section *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'value') Then
    Begin
      LexNextToken;
      ParseValueSection;
      Continue;
    End;

    (* CONST block *)
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
      WarnMsg('section TYPE ignoree (TODO ulterieur)');
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 ((StrLowerCase(CurToken.Val) = 'begin') Or
                  (StrLowerCase(CurToken.Val) = 'var') Or
                  (StrLowerCase(CurToken.Val) = 'const') Or
                  (StrLowerCase(CurToken.Val) = 'function') Or
                  (StrLowerCase(CurToken.Val) = 'procedure') Or
                  (StrLowerCase(CurToken.Val) = 'end') Or
                  (StrLowerCase(CurToken.Val) = 'static') Or
                  (StrLowerCase(CurToken.Val) = 'external') Or
                  (StrLowerCase(CurToken.Val) = 'global') Or
                  (StrLowerCase(CurToken.Val) = 'label'))) And
            Not IsOpenBracket Do
        LexNextToken;
      Continue;
    End;

    (* VAX attributes [...] before declarations *)
    If IsOpenBracket Then
    Begin
      ParseDeclAttributes;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'function') Then
      Begin
        WarnMsg('[attr] FUNCTION ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal   := False;
        PendAttrExternal := False;
        Continue;
      End;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'procedure') Then
      Begin
        WarnMsg('[attr] PROCEDURE ignoree (TODO ulterieur)');
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
          LexNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          LexNextToken;
        PendAttrGlobal   := False;
        PendAttrExternal := False;
        Continue;
      End;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'module') Then
        Continue;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'program') Then
        Continue;
      (* [INITIALIZE] : module init block *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'initialize') Then
      Begin
        LexNextToken;
        If Not MainBodyEmitted Then
        Begin
          MainBodyEmitted := True;
          EmitLabel(VXP_LBL_PFX + 'MAINBODY');
        End;
        EmitComment('INITIALIZE');
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'begin') Then
          ParseBlock;
        If (CurToken.Kind = TK_PUNCT) And
           ((CurToken.Val = ';') Or (CurToken.Val = '.')) Then
          LexNextToken;
        PendAttrGlobal   := False;
        PendAttrExternal := False;
        Continue;
      End;
      (* [FINALIZE] : module cleanup block *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'finalize') Then
      Begin
        LexNextToken;
        EmitComment('FINALIZE');
        If (CurToken.Kind = TK_KEYWORD) And
           (StrLowerCase(CurToken.Val) = 'begin') Then
          ParseBlock;
        If (CurToken.Kind = TK_PUNCT) And
           ((CurToken.Val = ';') Or (CurToken.Val = '.')) Then
          LexNextToken;
        PendAttrGlobal   := False;
        PendAttrExternal := False;
        Continue;
      End;
      (* Otherwise [EXTERNAL]/[GLOBAL] VAR *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'var') Then
        LexNextToken;
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        ParseAssignment(PendingAssignName);
        HasPendingAssign := False;
      End;
      PendAttrGlobal   := False;
      PendAttrExternal := False;
      Continue;
    End;

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

    (* CONDITION declaration *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'condition') Then
    Begin
      LexNextToken;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      Begin
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          Idx := SymAdd(CurToken.Val, SC_CONDITION, TY_IDX_INTEGER);
          If Idx >= 0 Then
          Begin
            SymTab[Idx].Offset := 100 + Idx;
            SymTab[Idx].MangledName := IntToStr(SymTab[Idx].Offset);
          End;
          LexNextToken;
          If (CurToken.Kind = TK_KEYWORD) And
             (StrLowerCase(CurToken.Val) = 'value') Then
          Begin
            LexNextToken;
            If (Idx >= 0) And (CurToken.Kind = TK_INTEGER) Then
            Begin
              SymTab[Idx].Offset := CurToken.IntVal;
              SymTab[Idx].MangledName := IntToStr(CurToken.IntVal);
            End;
            If CurToken.Kind = TK_INTEGER Then LexNextToken;
          End;
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

    (* FUNCTION declaration at global level *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'function') Then
    Begin
      WarnMsg('FUNCTION ignoree (TODO ulterieur)');
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* PROCEDURE declaration at global level *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'procedure') Then
    Begin
      WarnMsg('PROCEDURE ignoree (TODO ulterieur)');
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        LexNextToken;
      Continue;
    End;

    (* BEGIN : enter main program block *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'begin') Then
    Begin
      If Not MainBodyEmitted Then
      Begin
        MainBodyEmitted := True;
        EmitLabel(VXP_LBL_PFX + 'MAINBODY');
      End;
      ParseBlock;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
        LexNextToken;
      Continue;
    End;

    (* END alone (end of module or implicit block) *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'end') Then
    Begin
      LexNextToken;
      If (CurToken.Kind = TK_PUNCT) And
         ((CurToken.Val = '.') Or (CurToken.Val = ';')) Then
        LexNextToken;
      Continue;
    End;

    (* Skip any other token *)
    LexNextToken;
  End;

  { Fermer le lexeur }
  LexClose;

  { Emettre MAINBODY si pas encore fait }
  If Not MainBodyEmitted Then
  Begin
    MainBodyEmitted := True;
    EmitLabel(VXP_LBL_PFX + 'MAINBODY');
  End;

  { Finaliser le fichier de sortie (EmitFooter + EmitDataSeg + END) }
  EmitClose;

  { Generation du fichier .INC pour [ENVIRONMENT] }
  If EnvironmentName <> '' Then
  Begin
    EnvIncFName := EnvironmentName;
    If Pos('.', EnvIncFName) = 0 Then
      EnvIncFName := EnvIncFName + '.INC';
    {$I-}
    Assign(EnvIncF, EnvIncFName);
    Rewrite(EnvIncF);
    {$I+}
    If IOResult = 0 Then
    Begin
      WriteLn(EnvIncF, '; [ENVIRONMENT] export pour module : ',
              ModuleName);
      WriteLn(EnvIncF, '; Genere par VAXPCW32 v' + VXP_VERSION);
      WriteLn(EnvIncF, '');
      For EnvI := SymInitCount To SymCount - 1 Do
      Begin
        If (SymTab[EnvI].ScopeLevel = 0) And
           (SymTab[EnvI].Cat In [SC_FUNC, SC_PROC, SC_GLOBAL,
             SC_PUBLIC]) Then
          WriteLn(EnvIncF, 'EXTRN  ' + SymTab[EnvI].MangledName + ':NEAR')
        Else If (SymTab[EnvI].ScopeLevel = 0) And
                (SymTab[EnvI].Cat In [SC_VAR, SC_STATIC, SC_TYPED_CONST]) And
                (Not SymTab[EnvI].IsLocal) Then
        Begin
          If (SymTab[EnvI].TypeIdx >= 0) And
             (SymTab[EnvI].TypeIdx < TypeCount) And
             (TypeTab[SymTab[EnvI].TypeIdx].Size > 4) Then
            WriteLn(EnvIncF, 'EXTRN  ' + SymTab[EnvI].MangledName + ':BYTE')
          Else
            WriteLn(EnvIncF, 'EXTRN  ' + SymTab[EnvI].MangledName + ':DWORD');
        End;
      End;
      Close(EnvIncF);
      If Opts.Verbose Then
        WriteLn('Fichier ENVIRONMENT genere : ', EnvIncFName);
    End
    Else
      WarnMsg('impossible de creer le fichier environment: ' + EnvIncFName);
  End;

  { Statistiques de compilation }
  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
    If Opts.EmitExe Then
      WriteLn('  Mode           : EXE (PE Win32)')
    Else If Opts.EmitObj Then
      WriteLn('  Mode           : OBJ (COFF 32 bits)');
    If Opts.EmitAsm Then
      WriteLn('  Listing ASM    : oui');
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
    ShowHelp;
    Halt(0);
  End;
  ParseArgs;
  Run;
END.
