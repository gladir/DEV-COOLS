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
  STUBS (LexNextToken et Run - a implementer dans les TODOs suivants)
  ============================================================ }

Procedure LexNextToken;
Begin
  { Stub - sera implemente dans TODO 02 }
  CurToken.Kind := TK_EOF;
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
  LexOpened  := True;
  LexSrcFName := Opts.SrcFile;

  { TODO 02+ : LexInit, Parse, EmitHeader, ... }

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

  Cleanup;

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
