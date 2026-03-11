{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Modula-3 vers assembleur 8086
}

{  ============================================================
   MODIII86.PAS - Compilateur Modula-3 vers assembleur 8086
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : MASM .MODEL SMALL, DOS 16 bits

   FEUILLE DE ROUTE - 25 TODOS
   ============================================================

   TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
             TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
             ParseArgs : analyser argv (source.m3 [sortie.asm] [-v] [-d] [-w])
             FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
             Detecter l extension .m3 (module) ou .i3 (interface)
             Programme principal : validation des arguments et appel Run
             Version, Date, aide en ligne (option -h)

   TODO 02 - LEXEUR (TOKENS MODULA-3) [IMPLEMENTE]
             TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_CHAR,
               TK_STRING, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
             LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
             LexScanString : chaine entre guillemets doubles "abc"
               Sequences d echappement : \n \t \r \\ \" \xNN
             LexScanChar : litteral caractere entre apostrophes 'A'
               ou notation hexadecimale 0x41
             Commentaires : imbriques (nesting autorise en Modula-3)
             Mots-cles : AND ARRAY AS BEGIN BITS BRANDED BY CASE CONST
               DIV DO ELSE ELSIF END EVAL EXCEPT EXCEPTION EXIT
               EXPORTS FINALLY FOR FROM GENERIC IF IMPORT IN
               INTERFACE LOCK LOOP METHODS MOD MODULE NOT OBJECT
               OF OR OVERRIDES PROCEDURE RAISE READONLY RECORD
               REF REPEAT RETURN REVEAL ROOT SET THEN TO TRY
               TYPE TYPECASE UNSAFE UNTIL UNTRACED VALUE VAR
               WHILE WITH
             Mode debug -d : affichage de chaque token avec PrintToken

   TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
             Entiers decimaux : 0..65535 (CARDINAL) ou -32768..32767 (INTEGER)
             Entiers hexadecimaux : 16_FF, 8_77, 2_1010 (base quelconque)
             Reels : reconnus par le lexeur, traites comme entiers (trunc)
               Suffixes D0..D15 pour LONGREAL (avertissement + trunc)
             Caracteres : 'A' ou '\n' ou '\x41'
             Chaines TEXT : "abc" -> pointeur vers donnees DATA
               Concatenation de chaines : & operateur
             NIL : constante pointeur nul -> AX=0
             TRUE : constante booleenne -> AX=1
             FALSE : constante booleenne -> AX=0
             FIRST(T), LAST(T) : constantes de bornes de type ordinal
             NUMBER(T) : nombre d elements d un type ordinal ou tableau
             ORD(x), VAL(T,x) : conversion ordinale

   TODO 04 - OPERATEURS ET PRECEDENCE
             Arithmetiques  : + - * DIV MOD (entiers)
                              + - * / (reels -> entiers tronques)
             Concatenation  : & (TEXT & TEXT -> appel _M3RT_CONCAT)
             Comparaison    : = # < <= > >= (# est le "different de")
             Logiques       : AND OR NOT (court-circuit)
             Ensemblistes   : + (union) * (intersection) - (difference)
             Appartenance   : IN (element IN ensemble)
             Affectation    : := (assignation)
             Unaire         : + - (signe) NOT (negation logique)
             Precedence (du plus fort au plus faible) :
               1. NOT, unaire +/-
               2. * DIV MOD / &
               3. + - (binaire)
               4. = # < <= > >=  IN
               5. AND
               6. OR

   TODO 05 - TABLE DES SYMBOLES
             TSymKind : SK_CONST, SK_TYPE, SK_VAR, SK_PARAM, SK_PROC,
               SK_FIELD, SK_METHOD, SK_MODULE, SK_EXCEPTION
             TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
               Scope, IsExported, IsImported, IsReadonly
             SymAdd, SymFind, SymFindInScope, SymMangle
             CurScope : compteur de portee imbriquee (max MAX_SCOPE)
             SymEnterScope / SymLeaveScope : gestion des portees imbriquees
             Qualificateurs : Module.Ident -> recherche dans la portee du module
             Tables separees pour chaque module importe
             Exportation : marquer les symboles visibles depuis INTERFACE

   TODO 06 - SYSTEME DE TYPES
             TTypeKind : TYK_INTEGER (16 bits signe), TYK_CARDINAL (16 bits non signe),
               TYK_BOOLEAN (8 bits), TYK_CHAR (8 bits), TYK_REAL (stub entier),
               TYK_LONGREAL (stub entier), TYK_TEXT (ptr chaine),
               TYK_ARRAY (fixe), TYK_OPENARRAY (ouvert), TYK_RECORD,
               TYK_SET (ensemble), TYK_ENUM (enumeration),
               TYK_REF (reference), TYK_REFANY, TYK_OBJECT, TYK_PROC,
               TYK_SUBRANGE, TYK_PACKED, TYK_OPAQUE, TYK_NULL
             TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
             TypeSizeof : INTEGER=2, CARDINAL=2, BOOLEAN=1, CHAR=1, ptr=2
             Sous-typage : verifier compatibilite d affectation (assignable)
             BITS FOR n : taille en bits (packing dans RECORD)
             BRANDED "tag" REF T : type reference unique (distinction nominale)
             ROOT : type objet racine de la hierarchie

   TODO 07 - EMETTEUR DE CODE ASM
             TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
             EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
             EmitComment, EmitBlankLine
             LabelGen global (compteur unique _M3L_NNNNN)
             Prefixes : _M3V_ (variable), _M3P_ (procedure), _M3K_ (chaine const),
               _M3RT_ (runtime), _M3L_ (label), _M3T_ (type/vtable),
               _M3O_ (objet data), _M3X_ (exception handler)
             EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
             EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
             EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

   TODO 08 - SEGMENT DE DONNEES ET STATIQUES
             TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_RECORD),
               IntVal, StrVal, ElemCount
             DataTab[0..MAX_DATA-1], DataCount
             DataAdd, DataAddStr, DataAddRecord : variantes d ajout
             Variables globales (VAR au niveau MODULE) : entrees DK_WORD dans DATA
             Constantes CONST : entrees DK_WORD ou DK_STR (immuables)
             Chaines TEXT litterales : DB 'abc',0 dans DATA avec label _M3K_N
             Tables de methodes virtuelles (vtable) : DW offset proc par methode
             Descripteurs d exception : DW code + ptr nom dans DATA

   TODO 09 - VARIABLES ET AFFECTATIONS
             Variables globales : segment DATA, acces par label _M3V_nom
             Variables locales : pile BP, acces [BP-offset]
             Parametres VALUE : copie sur pile (comme variable locale)
             Parametres VAR : passage par adresse (pointeur sur pile)
             Parametres READONLY : passage par adresse, interdiction d ecriture
             Affectation := : ExprLoad + MOV destination, AX
             Affectation de RECORD : copie champ par champ ou REP MOVSW
             Affectation de ARRAY : copie element par element ou REP MOVSW

   TODO 10 - EXPRESSIONS PRIMAIRES
             ParsePrimary : literal entier, literal chaine, ident, appel de proc
             Acces qualifie : Module.Ident -> recherche symbole dans module
             Acces champ : expr.champ -> offset dans RECORD
             Acces index : expr[i] -> offset dans ARRAY
             Dereferencement : expr^ -> MOV BX,AX / MOV AX,[BX]
             NEW(T) : allocation dynamique -> CALL _M3RT_NEW -> AX=ptr
             NEW(T, method := proc) : allocation avec surcharge de methode
             ISTYPE(expr, T) : test de type dynamique -> AX=0|1
             NARROW(expr, T) : conversion de type avec verification
             TYPECODE(T) : code numerique du type -> AX=constante
             ABS(x), MAX(a,b), MIN(a,b), FLOAT(x), TRUNC(x)
             INC(x), DEC(x), INC(x,n), DEC(x,n) : procedures predefinies

   TODO 11 - EXPRESSIONS BINAIRES
             ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
             Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, DIV
             MOD : IDIV -> resultat dans DX (reste)
             Concatenation TEXT : & -> CALL _M3RT_CONCAT(SI=gauche, DI=droite) -> AX
             Comparaison : CMP + Jcc pour =, #, <, <=, >, >=
             Comparaison TEXT : CALL _M3RT_STRCMP -> drapeaux
             Logique AND : court-circuit JZ vers false-branch
             Logique OR : court-circuit JNZ vers true-branch
             Logique NOT : XOR AX,1
             Ensembles : OR (union), AND (intersection), NOT+AND (difference)
             Operateur IN : BT (bit test) ou decalage + AND

   TODO 12 - ENTREES/SORTIES (MODULES Wr / Rd / Stdio)
             Module Wr (ecriture) :
               Wr.PutChar(ch)     -> INT 21h AH=02h DL=ch
               Wr.PutText(txt)    -> INT 21h AH=40h BX=1 (STDOUT)
               Wr.PutInt(n)       -> CALL _M3RT_NUMTOSTR + ecriture
               Wr.PutReal(r)      -> avertissement + PutInt(TRUNC(r))
               Wr.Nl()            -> ecriture CR+LF
             Module Rd (lecture) :
               Rd.GetChar()       -> INT 21h AH=01h -> AL
               Rd.GetLine(buf)    -> INT 21h AH=0Ah (lecture ligne)
               Rd.GetInt()        -> lecture chaine + CALL _M3RT_STRTONUM
             Module Stdio :
               Stdio.stdout / Stdio.stderr : handles 1 et 2
             Module Fmt :
               Fmt.Int(n)         -> CALL _M3RT_NUMTOSTR -> AX=ptr TEXT
               Fmt.Char(ch)       -> caractere en TEXT
             Module Text :
               Text.Length(t)     -> CALL _M3RT_STRLEN -> AX
               Text.GetChar(t,i)  -> acces direct octet -> AL
               Text.Sub(t,s,l)   -> CALL _M3RT_TEXTSUB -> AX=ptr
               Text.Equal(a,b)   -> CALL _M3RT_STRCMP -> AX=0|1
               Text.Cat(a,b)     -> CALL _M3RT_CONCAT -> AX=ptr

   TODO 13 - IF / ELSIF / ELSE / CASE
             ParseIfStmt : IF cond THEN stmts ELSIF cond THEN stmts ELSE stmts END
               Emission TEST AX,AX / JZ pour condition fausse
               Labels : _M3L_ELSIF_N, _M3L_ELSE_N, _M3L_ENDIF_N
             ParseCaseStmt : CASE expr OF
               | val1 => stmts
               | val2, val3 => stmts
               | lo..hi => stmts (intervalle)
               ELSE stmts END
               Emission : CMP + JE pour chaque valeur, intervalle -> CMP+JB/JA
               Labels : _M3L_CASE_N, _M3L_CEND_N
             ParseTypecaseStmt : TYPECASE expr OF
               | T1(v) => stmts   (test de type dynamique + bind variable)
               | T2(v) => stmts
               ELSE stmts END
               Emission : CALL _M3RT_TYPECODE + CMP pour chaque type

   TODO 14 - BOUCLES : WHILE / REPEAT / FOR / LOOP / EXIT
             ParseWhileStmt : WHILE cond DO stmts END
               Labels : _M3L_WTEST_N, _M3L_WEND_N
             ParseRepeatStmt : REPEAT stmts UNTIL cond
               Labels : _M3L_RBEG_N, _M3L_RTEST_N
             ParseForStmt : FOR id := lo TO hi [BY step] DO stmts END
               Variable de boucle locale, increment automatique
               BY step : increment different de 1 (positif ou negatif)
               Labels : _M3L_FTEST_N, _M3L_FINCR_N, _M3L_FEND_N
             ParseLoopStmt : LOOP stmts END
               Boucle infinie, sortie par EXIT
               Labels : _M3L_LBEG_N, _M3L_LEND_N
             EXIT : saut vers fin de la boucle LOOP englobante
               -> JMP _M3L_LEND_N (erreur si hors LOOP)
             LoopPush / LoopPop : pile de labels pour EXIT

   TODO 15 - TABLEAUX (ARRAY)
             ARRAY [lo..hi] OF T : tableau a bornes fixes
               Taille = (hi - lo + 1) * sizeof(T), acces par offset calcule
               Multidimensionnel : ARRAY [a..b],[c..d] OF T
             ARRAY OF T : tableau ouvert (open array)
               Parametre : ptr + nombre d elements sur la pile
               Acces : indirection BX=ptr, calcul offset
               NUMBER(arr) : nombre d elements -> AX
             Affectation de tableau : copie REP MOVSW si taille connue
             Constructeurs de tableau : T(e0, e1, e2) -> DATA ou pile
             SUBARRAY(arr, start, len) : sous-tableau (ptr + offset)
             Verification de bornes : CMP index + JB/JAE -> exception si hors bornes

   TODO 16 - ENREGISTREMENTS (RECORD) ET WITH
             RECORD champ1: T1; champ2: T2; ... END
               Taille = somme des sizeof(Ti) alignes
               Acces champ : offset fixe depuis debut du record
             BITS FOR n : champs compactes sur n bits (emission decalages/masques)
             Constructeurs de record : T(champ1 := val1, champ2 := val2)
             Affectation de record : copie champ par champ ou REP MOVSW
             ParseWithStmt : WITH id = expr DO stmts END
               Alias temporaire : id lie a l expression evaluee
               Acces direct sans recalcul de l expression
             RECORD imbriques : acces chaine expr.champ1.champ2

   TODO 17 - PROCEDURES ET FONCTIONS
             ParseProcDecl : PROCEDURE nom(params) [: T] = bloc
             Parametres VALUE : copie de la valeur sur la pile
             Parametres VAR : passage par adresse (LEA + PUSH ptr)
             Parametres READONLY : adresse, interdiction d ecriture (erreur compile)
             Convention d appel : cdecl 16 bits, arguments empiles gauche a droite
             Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
             Epilogue : MOV SP,BP / POP BP / RET
             RETURN expr : MOV AX, valeur + JMP vers epilogue
             Procedures predefinies : INC, DEC, NEW, DISPOSE, ABS, MAX, MIN
             Procedures imbriquees : acces au cadre englobant via lien statique
               (pointeur vers BP du cadre parent passe comme parametre cache)
             Types PROCEDURE : variables de type procedural -> pointeur de code
               Appel indirect : CALL AX

   TODO 18 - INTERFACES ET MODULES (INTERFACE / MODULE)
             INTERFACE Nom; ... END Nom.
               Declarations exportees : types, constantes, variables, procedures
               Pas de corps d implementation dans INTERFACE
             MODULE Nom EXPORTS Intf; ... END Nom.
               IMPORT Mod1, Mod2 : importer les modules
               FROM Mod IMPORT sym1, sym2 : importation selective
               EXPORTS Intf : le module implemente cette interface
             Resolution des noms qualifies : Mod.Ident
             Verification de conformite : MODULE doit fournir tout ce que
               INTERFACE declare (types, procedures, signatures)
             Compilation separee (simplifiee) :
               Un seul fichier source a la fois, les interfaces importees
               sont declarees comme modules externes (EXTRN en ASM)
             Tables d importation/exportation : symboles EXTRN et PUBLIC

   TODO 19 - TYPES OBJETS ET METHODES (OBJECT)
             Declaration : TYPE T = ParentType OBJECT
               champs;
               METHODS
                 methode(params): RetType;
               OVERRIDES
                 methode := NouvelleProc;
               END
             Allocation : NEW(T) -> CALL _M3RT_OBJNEW(BX=taille+vtable) -> AX=ptr
             Vtable (table de methodes virtuelles) :
               Chaque type objet a une vtable dans DATA
               Entrees : DW offset de chaque methode
               Heritage : copie de la vtable du parent + surcharges
             Appel de methode : obj.method(args)
               MOV BX,[AX] (ptr vtable) / CALL [BX+offset_methode]
               Self (premier parametre cache) : PUSH AX avant appel
             OVERRIDES : remplacement d une entree dans la vtable
             Sous-typage objet : T <: ParentType (verification statique)
             ISTYPE(expr, T) : comparaison du typecode dynamique
             NARROW(expr, T) : verification + cast (exception si echec)
             ROOT : type objet racine, ancetre de tous les objets

   TODO 20 - TYPES OPAQUES ET REVEAL
             Type opaque dans INTERFACE :
               TYPE T <: SuperType (type partiellement revele)
               Les clients ne voient que SuperType
             REVEAL dans MODULE :
               REVEAL T = SuperType BRANDED OBJECT ... END
               Revelation complete du type opaque
             Verification de coherence : le type revele doit etre
               un sous-type du supertype declare dans INTERFACE
             Acces restreint : les clients ne peuvent acceder qu aux
               champs et methodes visibles via le supertype
             BRANDED : chaque BRANDED cree un type distinct nominalement
               BRANDED "etiquette" ou BRANDED (etiquette automatique)

   TODO 21 - EXCEPTIONS (TRY / EXCEPT / FINALLY / RAISE)
             ParseTryExceptStmt : TRY stmts EXCEPT
               | Exception1 => stmts
               | Exception2(v) => stmts  (v = argument de l exception)
               ELSE stmts END
             ParseTryFinallyStmt : TRY stmts FINALLY stmts END
               Le bloc FINALLY est toujours execute
             RAISE Exception [(arg)] : lever une exception
               AX = code exception, BX = argument optionnel
             Declaration : EXCEPTION NomExc [(T)] dans INTERFACE ou MODULE
             Mecanisme sans support OS :
               _M3X_HANDLER DW 0 dans DATA (ptr vers handler courant)
               TRY : sauvegarder ancien handler, installer nouveau
                 MOV [_M3X_HANDLER], OFFSET _M3L_EXCEPT_N
               EXCEPT : label _M3L_EXCEPT_N, CMP AX pour chaque exception
               FINALLY : label _M3L_FINALLY_N, execute dans tous les cas
               Restauration : MOV [_M3X_HANDLER], ancien_handler
             RAISE sans handler : affiche 'Unhandled exception' + Halt

   TODO 22 - TYPES REFERENCE (REF / REFANY / BRANDED / UNTRACED)
             REF T : reference vers un type T (pointeur type)
               Allocation : NEW(REF T) -> CALL _M3RT_NEW(CX=sizeof(T)) -> AX=ptr
               Dereferencement : expr^ -> MOV BX,AX / MOV AX,[BX]
               Affectation : ptr^ := val -> MOV BX,ptr / MOV [BX],AX
             REFANY : reference generique (compatible avec tout REF T)
               Necessite NARROW ou TYPECASE pour utilisation typee
             BRANDED REF T : type reference nominalement unique
               "tag" optionnel pour distinguer les types
             UNTRACED REF T : reference non tracee par le ramasse-miettes
               (en pratique sur DOS 8086, toutes les references sont non tracees)
             Allocation sur heap statique :
               _M3_HEAP DB 4096 DUP(0) + _M3_HEAPTOP DW 0
               _M3RT_NEW(CX=nb_octets) -> AX=ptr, avance _M3_HEAPTOP
             DISPOSE(ptr) : liberation (stub, pas de GC reel sur DOS)
             NIL : valeur nulle pour toute reference -> AX=0

   TODO 23 - MODULES GENERIQUES (GENERIC)
             GENERIC INTERFACE Nom(ParamFormel1, ParamFormel2);
               Declarations parametrees par des interfaces formelles
             GENERIC MODULE Nom(ParamFormel1, ParamFormel2);
               Implementation parametree
             Instanciation :
               INTERFACE MonInst = Nom(ParamActuel1, ParamActuel2) END MonInst.
               MODULE MonInst = Nom(ParamActuel1, ParamActuel2) END MonInst.
             Mecanisme de compilation :
               Substitution textuelle des parametres formels par les actuels
               Verification de conformite des interfaces fournies
               Generation de code specifique pour chaque instanciation
             Prefixe des labels : _M3G_NomInst_ pour eviter les collisions
             Limitation : un seul niveau de genericite (pas de generiques imbriques)

   TODO 24 - RUNTIME MINIMAL
             _M3RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
             _M3RT_PRINTLN : _M3RT_PRINT + CR+LF via _M3_CRLF DB 13,10,0
             _M3RT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
             _M3RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
             _M3RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
             _M3RT_CONCAT(SI=src1, DI=src2) : concatenation TEXT -> AX=ptr buf
             _M3RT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
             _M3RT_TEXTSUB(SI=str, BX=start, CX=len) : sous-chaine -> AX=ptr
             _M3RT_ABS(AX=n) : valeur absolue -> AX
             _M3RT_MAX(AX=a, BX=b) : maximum -> AX
             _M3RT_MIN(AX=a, BX=b) : minimum -> AX
             _M3RT_NEW(CX=nb_octets) : allocation heap -> AX=ptr
             _M3RT_OBJNEW(BX=taille, SI=vtable) : allocation objet -> AX=ptr
             _M3RT_TYPECODE(BX=ptr_objet) : lire typecode -> AX
             _M3RT_CHKIDX(AX=index, BX=lo, CX=hi) : verification bornes
               -> exception si hors bornes
             _M3RT_CHKNIL(AX=ptr) : verification pointeur nul
               -> exception si AX=0
             _M3RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
             RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
             Heap statique : _M3_HEAP DB 4096 DUP(0) + _M3_HEAPTOP DW 0

   TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
             EmitClose : END _M3P_Main dans _TEXT ENDS / DATA ENDS
             Run : pipeline complet LexInit -> ParseCompilationUnit ->
               EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _M3P_Main
             Fichiers SAMPLES\MODULA3\ a creer :
               hello.m3    (Wr.PutText, variables, constantes, TEXT)
               math.m3     (procedures, fonctions, recursion, RETURN)
               control.m3  (IF/ELSIF, CASE, WHILE, FOR, LOOP/EXIT)
               arrays.m3   (ARRAY fixe et ouvert, SUBARRAY, bornes)
               records.m3  (RECORD, WITH, constructeurs, champs)
               objects.m3  (OBJECT, METHODS, OVERRIDES, ISTYPE, NARROW)
               except.m3   (TRY/EXCEPT/FINALLY, RAISE, EXCEPTION)
               generic.m3  (GENERIC MODULE, instanciation)
             Smoke tests : MODIII86.EXE -v SAMPLES\MODULA3\*.m3

   ============================================================ }

Program MODIII86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

(* ============================================================
   CONSTANTES GLOBALES
   ============================================================ *)
Const
  MODIII86_VERSION = '1.0';
  MODIII86_DATE    = '2026-03-11';

  (* Limites internes *)
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_FIELD     = 64;
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_IMPORT    = 16;
  STACK_SIZE    = 1024;
  MAX_TOKEN     = {$IFDEF FPC}16384{$ELSE}2048{$ENDIF};

  (* Prefixes de nommage ASM *)
  M3_VAR_PFX  = '_M3V_';     (* variable globale                    *)
  M3_PROC_PFX = '_M3P_';     (* procedure / fonction                *)
  M3_STR_PFX  = '_M3K_';     (* constante chaine litterale          *)
  M3_RT_PFX   = '_M3RT_';    (* routine runtime                     *)
  M3_LBL_PFX  = '_M3L_';     (* label de saut interne               *)
  M3_TYPE_PFX = '_M3T_';     (* type / vtable                       *)
  M3_OBJ_PFX  = '_M3O_';     (* objet data                          *)
  M3_EXC_PFX  = '_M3X_';     (* exception handler                   *)

  (* Codes de sortie *)
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  (* Index de types primitifs (futurs, pour TypeTab TODO 06) *)
  TY_UNKNOWN     = -1;
  TY_IDX_INTEGER = 0;
  TY_IDX_CARDINAL= 1;
  TY_IDX_BOOLEAN = 2;
  TY_IDX_CHAR    = 3;
  TY_IDX_REAL    = 4;
  TY_IDX_LONGREAL= 5;
  TY_IDX_TEXT    = 6;
  TY_IDX_NIL     = 7;
  TY_IDX_VOID    = 8;

(* ============================================================
   TYPES
   ============================================================ *)
Type
  TString = String[MAX_STR];

  (* ---- Options de compilation ----------------------------- *)
  TOptions = Record
    SrcFile   : TString;   (* fichier source (.m3 ou .i3)         *)
    OutFile   : TString;   (* fichier assembleur de sortie (.asm)  *)
    Verbose   : Boolean;   (* -v : banniere et statistiques        *)
    DebugMode : Boolean;   (* -d : affichage de chaque token       *)
    Warnings  : Boolean;   (* -w : activer les avertissements      *)
    IsIface   : Boolean;   (* True si extension .i3 (interface)    *)
  End;

  (* ---- Tokens Modula-3 ------------------------------------ *)
  TTokenKind = (
    TK_EOF,        (* fin de fichier                              *)
    TK_INTEGER,    (* litteral entier decimal ou base_digits       *)
    TK_REAL,       (* litteral reel (reconnu, traite comme entier) *)
    TK_CHAR,       (* litteral caractere entre apostrophes         *)
    TK_STRING,     (* litteral chaine entre guillemets doubles     *)
    TK_IDENT,      (* identificateur                               *)
    TK_KEYWORD,    (* mot-cle reserve Modula-3                     *)
    TK_OP,         (* operateur (:= <= >= <> .. # & + - * / etc.) *)
    TK_PUNCT       (* ponctuation ( ) [ ] ; , . : ^ | *)
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;       (* representation textuelle brute      *)
    IntVal : LongInt;       (* valeur entiere (TK_INTEGER/TK_CHAR) *)
    Line   : Integer;       (* ligne source (1-base)               *)
    Col    : Integer;       (* colonne source (1-base)             *)
  End;

  (* ---- Segment de donnees (TODO 03) ------------------------- *)
  TDataKind = (
    DK_WORD,       (* mot 16 bits (DW)                            *)
    DK_BYTE,       (* octet (DB)                                  *)
    DK_STR,        (* chaine ASCIIZ (DB 'abc',0)                  *)
    DK_ARRAY,      (* tableau (DB n DUP(0))                       *)
    DK_REC         (* record (DB size DUP(0))                     *)
  );

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   (* nombre d elements (DK_ARRAY)        *)
    ElemSize  : Integer;   (* taille d un element (DK_ARRAY)      *)
    RecSize   : Integer;   (* taille totale en octets (DK_REC)    *)
  End;

  (* ---- Valeurs d expression (TODO 03) ----------------------- *)
  TExprKind = (
    EK_NONE,       (* void / pas de valeur                        *)
    EK_IMM,        (* valeur immediate dans ImmVal                 *)
    EK_AX,         (* valeur dans registre AX                      *)
    EK_MEM         (* adresse memoire [BP+Offset] ou label DATA   *)
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;     (* valeur immediate ou offset           *)
    TypeIdx : Integer;     (* index dans TypeTab (futur)           *)
    Offset  : Integer;     (* offset dans DataTab ou pile          *)
    SymIdx  : Integer;     (* index dans SymTab (-1 si aucun)     *)
  End;

  (* ---- Token pool (TODO 03) --------------------------------- *)
  TPoolToken = Record
    Kind   : TTokenKind;
    Val    : TString;
    IntVal : LongInt;
    Line   : Integer;
    Col    : Integer;
  End;

(* ============================================================
   VARIABLES GLOBALES
   ============================================================ *)
Var
  (* Options *)
  Opts : TOptions;

  (* Compteurs generaux *)
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  (* Emetteur ASM *)
  OutF     : Text;
  OutFOpen : Boolean;

  (* Lexeur *)
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  (* Segment de donnees (TODO 03) *)
  DataTab    : Array[0..MAX_DATA-1] Of TDataRec;
  DataCount  : Integer;
  LabelGenSeq: LongInt;

  (* Token Pool (TODO 03) *)
  TokenPool  : Array[0..MAX_TOKEN-1] Of TPoolToken;
  TokenCount : Integer;

(* ============================================================
   TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
   ============================================================ *)

(* ---- Messages d erreur et d avertissement ----------------- *)

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('MODIII86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    {$I+}
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
    {$I-}
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('MODIII86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('MODIII86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

(* ---- Banniere et aide ------------------------------------- *)

Procedure ShowBanner;
Begin
  WriteLn('MODIII86 v', MODIII86_VERSION, ' (', MODIII86_DATE, ')');
  WriteLn('Compilateur Modula-3 -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('MODIII86 - Cette commande permet de lancer le compilateur Modula-3 ',
          'pour de l''assembleur de microprocesseur 8086 ou 8088.');
  WriteLn;
  WriteLn('Syntaxe: MODIII86 <source.m3|source.i3> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.m3  : fichier module Modula-3 source');
  WriteLn('  source.i3  : fichier interface Modula-3 source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

(* ---- Utilitaires chaines ---------------------------------- *)

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

(* ---- Initialisation des options --------------------------- *)

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.IsIface   := False;
End;

(* ---- Analyse des arguments en ligne de commande ----------- *)

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

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('MODIII86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('MODIII86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('MODIII86: fichier source manquant');
    ShowUsage;
  End;

  (* Verifier l extension .m3 ou .i3 *)
  Ext := ExtractExt(Opts.SrcFile);
  If Ext = '.i3' Then
    Opts.IsIface := True
  Else If Ext = '.m3' Then
    Opts.IsIface := False
  Else
    WarnMsg('extension attendue .m3 ou .i3, trouvee: ' + Ext);

  (* Fichier de sortie par defaut : meme nom avec .asm *)
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

(* ---- Nettoyage -------------------------------------------- *)

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

(* ============================================================
   TODO 02 - LEXEUR (TOKENS MODULA-3) [IMPLEMENTE]
   ============================================================ *)

(* ---- Fonctions auxiliaires de classification de caracteres -- *)

Function IsAlpha(Ch : Char) : Boolean;
Begin
  IsAlpha := ((Ch >= 'A') And (Ch <= 'Z')) Or
             ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
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

Function IsAlNum(Ch : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(Ch) Or IsDigit(Ch);
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

Function UpChar(Ch : Char) : Char;
Begin
  If (Ch >= 'a') And (Ch <= 'z') Then
    UpChar := Chr(Ord(Ch) - 32)
  Else
    UpChar := Ch;
End;

Function StrUpCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    R[I] := UpChar(R[I]);
  StrUpCase := R;
End;

(* ---- LexNextLine : lire la prochaine ligne source ---------- *)

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
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

(* ---- LexInit : ouvrir le fichier source et initialiser ----- *)

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  LexEOF    := False;
  CurToken.Kind   := TK_EOF;
  CurToken.Val    := '';
  CurToken.IntVal := 0;
  CurToken.Line   := 0;
  CurToken.Col    := 0;
  LexNextLine;
End;

(* ---- LexClose : fermer le fichier source ------------------- *)

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

(* ---- IsKeyword : verifier si un mot est un mot-cle Modula-3  *)
(*      Les mots-cles Modula-3 sont en majuscules.               *)

Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'AND')       Or (S = 'ARRAY')     Or (S = 'AS')        Or
    (S = 'BEGIN')     Or (S = 'BITS')      Or (S = 'BRANDED')   Or
    (S = 'BY')        Or (S = 'CASE')      Or (S = 'CONST')     Or
    (S = 'DIV')       Or (S = 'DO')        Or (S = 'ELSE')      Or
    (S = 'ELSIF')     Or (S = 'END')       Or (S = 'EVAL')      Or
    (S = 'EXCEPT')    Or (S = 'EXCEPTION') Or (S = 'EXIT')      Or
    (S = 'EXPORTS')   Or (S = 'FINALLY')   Or (S = 'FOR')       Or
    (S = 'FROM')      Or (S = 'GENERIC')   Or (S = 'IF')        Or
    (S = 'IMPORT')    Or (S = 'IN')        Or (S = 'INTERFACE')  Or
    (S = 'LOCK')      Or (S = 'LOOP')      Or (S = 'METHODS')   Or
    (S = 'MOD')       Or (S = 'MODULE')    Or (S = 'NOT')       Or
    (S = 'OBJECT')    Or (S = 'OF')        Or (S = 'OR')        Or
    (S = 'OVERRIDES') Or (S = 'PROCEDURE') Or (S = 'RAISE')     Or
    (S = 'READONLY')  Or (S = 'RECORD')    Or (S = 'REF')       Or
    (S = 'REPEAT')    Or (S = 'RETURN')    Or (S = 'REVEAL')    Or
    (S = 'ROOT')      Or (S = 'SET')       Or (S = 'THEN')      Or
    (S = 'TO')        Or (S = 'TRY')       Or (S = 'TYPE')      Or
    (S = 'TYPECASE')  Or (S = 'UNSAFE')    Or (S = 'UNTIL')     Or
    (S = 'UNTRACED')  Or (S = 'VALUE')     Or (S = 'VAR')       Or
    (S = 'WHILE')     Or (S = 'WITH');
End;

(* ---- LexScanIdent : scanner un identificateur ou mot-cle --- *)
(*      Modula-3 est sensible a la casse ; les mots-cles sont   *)
(*      en majuscules. On compare la version majuscule.          *)

Procedure LexScanIdent;
Var
  S, SU : TString;
Begin
  S  := '';
  SU := '';
  While (LexColNo <= Length(LexLine)) And IsAlNum(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
    Begin
      S  := S + LexLine[LexColNo];
      SU := SU + UpChar(LexLine[LexColNo]);
    End;
    Inc(LexColNo);
  End;
  If IsKeyword(SU) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := SU;   (* mots-cles toujours en majuscules *)
  End
  Else
  Begin
    CurToken.Kind := TK_IDENT;
    CurToken.Val  := S;    (* identifiants : casse conservee   *)
  End;
  CurToken.IntVal := 0;
End;

(* ---- LexScanNumber : scanner un litteral numerique ---------- *)
(*      Formes reconnues :                                       *)
(*        ddddd          entier decimal                          *)
(*        base_ddddd     entier en base quelconque (16_FF, 8_77) *)
(*        ddddd.ddddd    reel (traite comme entier tronque)      *)
(*        dddddDn        LONGREAL suffix (avertissement+trunc)   *)

Procedure LexScanNumber;
Var
  S     : TString;
  N     : LongInt;
  Base  : Integer;
  I     : Integer;
  Ch    : Char;
  IsReal : Boolean;
Begin
  S      := '';
  N      := 0;
  Base   := 10;
  IsReal := False;

  (* Accumuler les chiffres decimaux *)
  While (LexColNo <= Length(LexLine)) And IsDigit(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  (* Verifier base_digits : format N_xxxx (ex: 16_FF, 8_77, 2_1010) *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '_') And
     (LexColNo < Length(LexLine)) Then
  Begin
    (* S contient la base sous forme de chiffres decimaux *)
    Base := 0;
    For I := 1 To Length(S) Do
      Base := Base * 10 + (Ord(S[I]) - Ord('0'));
    If (Base < 2) Or (Base > 16) Then
    Begin
      CompileError('base invalide: ' + S);
      Base := 10;
    End;
    Inc(LexColNo); (* sauter le _ *)
    S := '';
    (* Accumuler les digits dans la base specifiee *)
    While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
    Begin
      If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    (* Convertir selon la base *)
    N := 0;
    For I := 1 To Length(S) Do
    Begin
      Ch := S[I];
      If IsHexDigit(Ch) Then
        N := N * Base + HexVal(Ch);
    End;
    CurToken.Kind   := TK_INTEGER;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  (* Verifier si c est un reel : point decimal (mais pas ..) *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
  Begin
    (* Verifier que ce n est pas '..' *)
    If (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] = '.') Then
    Begin
      (* C est '..' -> ne pas consommer, rester entier *)
    End
    Else
    Begin
      IsReal := True;
      If Length(S) < MAX_STR Then S := S + '.';
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And IsDigit(LexLine[LexColNo]) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      (* Exposant E ou e *)
      If (LexColNo <= Length(LexLine)) And
         ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + 'E';
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And
           ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
        Begin
          If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
          Inc(LexColNo);
        End;
        While (LexColNo <= Length(LexLine)) And IsDigit(LexLine[LexColNo]) Do
        Begin
          If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
          Inc(LexColNo);
        End;
      End;
    End;
  End;

  (* Suffixe D0..D15 pour LONGREAL *)
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'D') Or (LexLine[LexColNo] = 'd')) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And IsDigit(LexLine[LexColNo]) Do
      Inc(LexColNo);
    WarnMsg('suffixe LONGREAL ignore, tronque a entier');
  End;

  If IsReal Then
  Begin
    (* Traiter le reel comme entier tronque *)
    N := 0;
    For I := 1 To Length(S) Do
    Begin
      If S[I] = '.' Then Break;
      If IsDigit(S[I]) Then
        N := N * 10 + (Ord(S[I]) - Ord('0'));
    End;
    CurToken.Kind   := TK_REAL;
    CurToken.IntVal := N;
    CurToken.Val    := S;
  End
  Else
  Begin
    (* Entier decimal simple *)
    N := 0;
    For I := 1 To Length(S) Do
      N := N * 10 + (Ord(S[I]) - Ord('0'));
    CurToken.Kind   := TK_INTEGER;
    CurToken.IntVal := N;
    CurToken.Val    := S;
  End;
End;

(* ---- LexScanString : chaine entre guillemets doubles -------- *)
(*      Sequences d echappement : \n \t \r \\ \" \xNN            *)

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
  V  : Integer;
Begin
  S := '';
  Inc(LexColNo); (* sauter guillemet ouvrant *)
  While (Not LexEOF) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      CompileError('chaine non terminee en fin de ligne');
      Break;
    End;
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      If LexColNo > Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + '\';
      End
      Else
      Begin
        Ch := LexLine[LexColNo];
        Inc(LexColNo);
        Case Ch Of
          'n' : If Length(S) < MAX_STR Then S := S + #10;
          't' : If Length(S) < MAX_STR Then S := S + #9;
          'r' : If Length(S) < MAX_STR Then S := S + #13;
          '\' : If Length(S) < MAX_STR Then S := S + '\';
          '"' : If Length(S) < MAX_STR Then S := S + '"';
          '0' : If Length(S) < MAX_STR Then S := S + #0;
          'x', 'X' :
          Begin
            V := 0;
            If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
            Begin
              V := HexVal(LexLine[LexColNo]);
              Inc(LexColNo);
            End;
            If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
            Begin
              V := V * 16 + HexVal(LexLine[LexColNo]);
              Inc(LexColNo);
            End;
            If Length(S) < MAX_STR Then S := S + Chr(V);
          End;
        Else
          If Length(S) < MAX_STR Then S := S + Ch;
        End;
      End;
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

(* ---- LexScanChar : litteral caractere entre apostrophes ----- *)
(*      'A' ou '\n' ou '\x41'                                    *)

Procedure LexScanChar;
Var
  Ch : Char;
  V  : Integer;
Begin
  Inc(LexColNo); (* sauter apostrophe ouvrante *)
  CurToken.Kind   := TK_CHAR;
  CurToken.IntVal := 0;
  CurToken.Val    := '';

  If LexColNo > Length(LexLine) Then
  Begin
    CompileError('caractere non termine');
    Exit;
  End;

  Ch := LexLine[LexColNo];

  (* Sequence d echappement *)
  If Ch = '\' Then
  Begin
    Inc(LexColNo);
    If LexColNo > Length(LexLine) Then
    Begin
      CompileError('caractere non termine');
      Exit;
    End;
    Ch := LexLine[LexColNo];
    Inc(LexColNo);
    Case Ch Of
      'n' : Begin CurToken.IntVal := 10;  CurToken.Val := '\n'; End;
      't' : Begin CurToken.IntVal := 9;   CurToken.Val := '\t'; End;
      'r' : Begin CurToken.IntVal := 13;  CurToken.Val := '\r'; End;
      '\' : Begin CurToken.IntVal := Ord('\'); CurToken.Val := '\\'; End;
      '''' : Begin CurToken.IntVal := Ord(''''); CurToken.Val := '\'''; End;
      '0' : Begin CurToken.IntVal := 0;   CurToken.Val := '\0'; End;
      'x', 'X' :
      Begin
        V := 0;
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
        CurToken.IntVal := V;
        CurToken.Val    := '\x';
      End;
    Else
      CurToken.IntVal := Ord(Ch);
      CurToken.Val    := Ch;
    End;
  End
  Else
  Begin
    (* Caractere simple *)
    CurToken.IntVal := Ord(Ch);
    CurToken.Val    := Ch;
    Inc(LexColNo);
  End;

  (* Consommer l apostrophe fermante *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Inc(LexColNo)
  Else
    CompileError('apostrophe fermante attendue');
End;

{ ---- LexSkipComment : sauter un commentaire imbrique --------- }
{      Les commentaires Modula-3 sont de la forme (* ... *)      }
{      et peuvent etre imbriques (nesting autorise).             }

Procedure LexSkipComment;
Var
  Depth : Integer;
Begin
  Depth := 1;
  Inc(LexColNo); (* sauter '(' *)
  Inc(LexColNo); (* sauter '*' *)
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    (* Fin de ligne -> passer a la suivante *)
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      If LexEOF Then
      Begin
        CompileError('commentaire non termine');
        Exit;
      End;
    End
    Else If (LexLine[LexColNo] = '(') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(Depth);
      Inc(LexColNo);
      Inc(LexColNo);
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Dec(Depth);
      Inc(LexColNo);
      Inc(LexColNo);
    End
    Else
      Inc(LexColNo);
  End;
End;

(* ---- LexScanOp : scanner un operateur Modula-3 ------------- *)
(*      Operateurs : := <= >= <> .. # & + - * / =  < >           *)
(*      Ponctuation : ( ) [ ] ; , . : ^ |                        *)

Procedure LexScanOp;
Var
  Ch : Char;
  S  : TString;
Begin
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  S := Ch;

  Case Ch Of
    ':' : If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
          Begin
            S := ':=';
            Inc(LexColNo);
          End;
    '<' : If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
          Begin
            S := '<=';
            Inc(LexColNo);
          End
          Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
          Begin
            S := '<>';
            Inc(LexColNo);
          End;
    '>' : If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
          Begin
            S := '>=';
            Inc(LexColNo);
          End;
    '.' : If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
          Begin
            S := '..';
            Inc(LexColNo);
          End;
    '=' : If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
          Begin
            S := '=>';
            Inc(LexColNo);
          End;
  End;

  (* Classifier en ponctuation ou operateur *)
  If (S = '(') Or (S = ')') Or (S = '[') Or (S = ']') Or
     (S = ';') Or (S = ',') Or (S = '.') Or (S = ':') Or
     (S = '^') Or (S = '|') Or
     (S = Chr(123)) Or (S = Chr(125)) Then
    CurToken.Kind := TK_PUNCT
  Else
    CurToken.Kind := TK_OP;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- PrintToken : affichage debug d un token ---------------- *)

Procedure PrintToken(Const T : TToken);
Var NS : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Begin Str(T.IntVal, NS); Write('INT(', NS, ')'); End;
    TK_REAL    : Write('REAL(', T.Val, ')');
    TK_CHAR    : Begin Str(T.IntVal, NS); Write('CHAR(''', T.Val, '''=', NS, ')'); End;
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

(* ---- LexNextToken : produire le prochain token -------------- *)

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal := 0;
  Scanning := True;

  While Scanning Do
  Begin
    (* Avancer tant qu on est en fin de ligne *)
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    (* Fin de fichier *)
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

    (* Espaces et tabulations *)
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire imbrique }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipComment;
    End

    (* Identificateur ou mot-cle *)
    Else If IsAlpha(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    (* Litteral numerique *)
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    (* Chaine entre guillemets doubles *)
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    (* Litteral caractere entre apostrophes *)
    Else If Ch = '''' Then
    Begin
      LexScanChar;
      Scanning := False;
    End

    (* Operateurs et ponctuation *)
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '#') Or (Ch = '<') Or (Ch = '>') Or
            (Ch = '&') Or (Ch = ':') Or (Ch = '.') Or (Ch = ',') Or
            (Ch = ';') Or (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or
            (Ch = ']') Or (Ch = '^') Or (Ch = '|') Or
            (Ch = Chr(123)) Or (Ch = Chr(125)) Then
    Begin
      LexScanOp;
      Scanning := False;
    End

    (* Caractere inconnu *)
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;
  End;
End;

(* ============================================================
   TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
   ============================================================ *)

(* ---- IntToStr : convertir un entier en chaine --------------- *)

Function IntToStr(N : LongInt) : TString;
Var S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

(* ---- LabelGen : generateur de labels uniques ---------------- *)

Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := M3_LBL_PFX + IntToStr(LabelGenSeq);
End;

(* ---- DataAdd : ajouter une entree dans DataTab -------------- *)

Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataTab[DataCount].ElemSize  := 0;
  DataTab[DataCount].RecSize   := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

(* ---- DataAddStr : creer un label et stocker une chaine ------ *)
(* Retourne le label genere (_M3K_N).                            *)

Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := M3_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

(* ---- DataAddWord : ajouter un mot 16 bits dans DataTab ------ *)

Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- DataAddByte : ajouter un octet dans DataTab ------------ *)

Function DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, AIntVal, '');
End;

(* ---- DataAddArray : ajouter un tableau dans DataTab --------- *)

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

(* ---- DataAddRec : ajouter un record dans DataTab ------------ *)

Function DataAddRec(Const Lbl : TString; RSz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_REC, 0, '');
  DataTab[Idx].RecSize := RSz;
  DataAddRec := Idx;
End;

(* ---- DataFindStr : chercher une chaine deja stockee --------- *)
(* Retourne l index dans DataTab ou -1 si non trouvee.           *)

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

(* ---- DataGetOrAddStr : chercher ou ajouter une chaine ------- *)
(* Deduplication : si la chaine existe deja, retourne son label. *)

Function DataGetOrAddStr(Const S : TString) : TString;
Var Idx : Integer;
Begin
  Idx := DataFindStr(S);
  If Idx >= 0 Then
    DataGetOrAddStr := DataTab[Idx].LblName
  Else
    DataGetOrAddStr := DataAddStr(S);
End;

(* ---- DataInit : initialiser le segment de donnees ----------- *)

Procedure DataInit;
Begin
  DataCount   := 0;
  LabelGenSeq := 0;
End;

(* ---- ExprMakeImm : creer une valeur immediate --------------- *)

Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeNone : creer une valeur void ------------------- *)

Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_VOID;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeBool : creer une valeur booleenne -------------- *)

Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- LitEval : evaluer un token litteral en TExprVal -------- *)
(* Gere : TK_INTEGER, TK_REAL (tronque), TK_STRING,             *)
(*        TK_CHAR, TK_KEYWORD (TRUE/FALSE/NIL).                 *)

Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Idx : Integer;
Begin
  ExprMakeNone(Res);

  Case T.Kind Of
    (* --- Entiers --- *)
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    (* --- Reels (tronques a entier) --- *)
    TK_REAL :
    Begin
      WarnMsg('litteral reel tronque a entier');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;  (* deja tronque par LexScanNumber *)
      Res.TypeIdx := TY_IDX_REAL;
    End;

    (* --- Caracteres --- *)
    TK_CHAR :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_CHAR;
    End;

    (* --- Chaines TEXT --- *)
    TK_STRING :
    Begin
      DataGetOrAddStr(T.Val);
      Idx := DataFindStr(T.Val);
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_TEXT;
      Res.Offset  := Idx;
      Res.SymIdx  := -1;
    End;

    (* --- Mots-cles speciaux : TRUE, FALSE, NIL --- *)
    TK_KEYWORD :
    Begin
      If T.Val = 'TRUE' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'FALSE' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'NIL' Then
        ExprMakeImm(0, TY_IDX_NIL, Res);
    End;

    (* --- Identifiants predeclares : TRUE, FALSE, NIL --- *)
    TK_IDENT :
    Begin
      If StrUpCase(T.Val) = 'TRUE' Then
        ExprMakeBool(1, Res)
      Else If StrUpCase(T.Val) = 'FALSE' Then
        ExprMakeBool(0, Res)
      Else If StrUpCase(T.Val) = 'NIL' Then
        ExprMakeImm(0, TY_IDX_NIL, Res);
    End;
  End;
End;

(* ---- ConstEvalAtom : evaluer un atome de constante ---------- *)
(* Gere : litteral entier/reel/char, TRUE/FALSE/NIL,            *)
(*        FIRST(T), LAST(T), NUMBER(T), ORD(x), VAL(T,x),      *)
(*        parentheses, unaire +/- et NOT.                        *)

Function ConstEvalAtom(Var P : Integer) : LongInt;
Var
  V : LongInt;
  S : TString;
Begin
  V := 0;
  If P >= TokenCount Then
  Begin
    ConstEvalAtom := 0;
    Exit;
  End;

  (* Litteral entier *)
  If TokenPool[P].Kind = TK_INTEGER Then
  Begin
    V := TokenPool[P].IntVal;
    Inc(P);
  End

  (* Litteral reel -> tronquer *)
  Else If TokenPool[P].Kind = TK_REAL Then
  Begin
    V := TokenPool[P].IntVal;
    Inc(P);
  End

  (* Litteral caractere *)
  Else If TokenPool[P].Kind = TK_CHAR Then
  Begin
    V := TokenPool[P].IntVal;
    Inc(P);
  End

  (* Mots-cles speciaux *)
  Else If TokenPool[P].Kind = TK_KEYWORD Then
  Begin
    S := TokenPool[P].Val;
    If S = 'TRUE' Then V := 1
    Else If S = 'FALSE' Then V := 0
    Else If S = 'NIL' Then V := 0

    (* FIRST(INTEGER) = -32768, FIRST(CARDINAL) = 0, FIRST(CHAR) = 0, FIRST(BOOLEAN) = 0 *)
    Else If S = 'FIRST' Then
    Begin
      Inc(P);
      (* Consommer ( *)
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := -32768
        Else If S = 'CARDINAL' Then V := 0
        Else If S = 'CHAR'     Then V := 0
        Else If S = 'BOOLEAN'  Then V := 0
        Else V := 0;
        Inc(P);
      End;
      (* Consommer ) *)
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    (* LAST(INTEGER) = 32767, LAST(CARDINAL) = 65535, LAST(CHAR) = 255, LAST(BOOLEAN) = 1 *)
    Else If S = 'LAST' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := 32767
        Else If S = 'CARDINAL' Then V := 65535
        Else If S = 'CHAR'     Then V := 255
        Else If S = 'BOOLEAN'  Then V := 1
        Else V := 0;
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    (* NUMBER(T) : nombre d elements d un type ordinal *)
    Else If S = 'NUMBER' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := 65536
        Else If S = 'CARDINAL' Then V := 65536
        Else If S = 'CHAR'     Then V := 256
        Else If S = 'BOOLEAN'  Then V := 2
        Else V := 0;
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    (* ORD(x) : conversion ordinale *)
    Else If S = 'ORD' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      V := ConstEvalAtom(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    (* VAL(T,x) : conversion vers type T *)
    Else If S = 'VAL' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      (* Sauter le nom de type *)
      If (P < TokenCount) Then Inc(P);
      (* Consommer virgule *)
      If (P < TokenCount) And (TokenPool[P].Val = ',') Then Inc(P);
      V := ConstEvalAtom(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else
    Begin
      V := 0;
      Inc(P);
    End;
  End

  (* Identificateur : TRUE/FALSE/NIL ou FIRST/LAST/NUMBER/ORD/VAL *)
  Else If TokenPool[P].Kind = TK_IDENT Then
  Begin
    S := StrUpCase(TokenPool[P].Val);
    If S = 'TRUE' Then Begin V := 1; Inc(P); End
    Else If S = 'FALSE' Then Begin V := 0; Inc(P); End
    Else If S = 'NIL' Then Begin V := 0; Inc(P); End

    Else If S = 'FIRST' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := -32768
        Else If S = 'CARDINAL' Then V := 0
        Else If S = 'CHAR'     Then V := 0
        Else If S = 'BOOLEAN'  Then V := 0
        Else V := 0;
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else If S = 'LAST' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := 32767
        Else If S = 'CARDINAL' Then V := 65535
        Else If S = 'CHAR'     Then V := 255
        Else If S = 'BOOLEAN'  Then V := 1
        Else V := 0;
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else If S = 'NUMBER' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        S := StrUpCase(TokenPool[P].Val);
        If S = 'INTEGER'  Then V := 65536
        Else If S = 'CARDINAL' Then V := 65536
        Else If S = 'CHAR'     Then V := 256
        Else If S = 'BOOLEAN'  Then V := 2
        Else V := 0;
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else If S = 'ORD' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      V := ConstEvalAtom(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else If S = 'VAL' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then Inc(P); (* sauter le nom de type *)
      If (P < TokenCount) And (TokenPool[P].Val = ',') Then Inc(P);
      V := ConstEvalAtom(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    Else
    Begin
      V := 0;
      Inc(P);
    End;
  End

  (* Parentheses *)
  Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '(') Then
  Begin
    Inc(P);
    V := ConstEvalAtom(P);
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
  End

  (* Unaire + *)
  Else If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '+') Then
  Begin
    Inc(P);
    V := ConstEvalAtom(P);
  End

  (* Unaire - *)
  Else If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '-') Then
  Begin
    Inc(P);
    V := -ConstEvalAtom(P);
  End

  (* NOT *)
  Else If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'NOT') Then
  Begin
    Inc(P);
    If ConstEvalAtom(P) = 0 Then V := 1 Else V := 0;
  End

  Else
    Inc(P);

  ConstEvalAtom := V;
End;

(* ---- ConstEvalExpr : evaluer une expression constante ------- *)
(* Gere : + - * DIV MOD AND OR = # < > <= >=                    *)

Function ConstEvalExpr(Var P : Integer) : LongInt;
Var
  L, R : LongInt;
  Op   : TString;
Begin
  L := ConstEvalAtom(P);

  While (P < TokenCount) And
        ((TokenPool[P].Kind = TK_OP) Or
         ((TokenPool[P].Kind = TK_KEYWORD) And
          ((TokenPool[P].Val = 'DIV') Or (TokenPool[P].Val = 'MOD') Or
           (TokenPool[P].Val = 'AND') Or (TokenPool[P].Val = 'OR')))) Do
  Begin
    Op := TokenPool[P].Val;
    Inc(P);
    R := ConstEvalAtom(P);

    If Op = '+' Then L := L + R
    Else If Op = '-' Then L := L - R
    Else If Op = '*' Then L := L * R
    Else If Op = 'DIV' Then
    Begin
      If R = 0 Then CompileError('division par zero')
      Else L := L Div R;
    End
    Else If Op = 'MOD' Then
    Begin
      If R = 0 Then CompileError('division par zero')
      Else L := L Mod R;
    End
    Else If Op = 'AND' Then
    Begin
      If (L <> 0) And (R <> 0) Then L := 1 Else L := 0;
    End
    Else If Op = 'OR' Then
    Begin
      If (L <> 0) Or (R <> 0) Then L := 1 Else L := 0;
    End
    Else If Op = '=' Then
    Begin If L = R Then L := 1 Else L := 0; End
    Else If Op = '#' Then
    Begin If L <> R Then L := 1 Else L := 0; End
    Else If Op = '<' Then
    Begin If L < R Then L := 1 Else L := 0; End
    Else If Op = '>' Then
    Begin If L > R Then L := 1 Else L := 0; End
    Else If Op = '<=' Then
    Begin If L <= R Then L := 1 Else L := 0; End
    Else If Op = '>=' Then
    Begin If L >= R Then L := 1 Else L := 0; End
    Else
      Break;
  End;

  ConstEvalExpr := L;
End;

(* ---- ConstEval : point d entree pour evaluer une constante -- *)
(* Evaluer les tokens de la position Start a End dans TokenPool. *)

Function ConstEval(StartP, EndP : Integer) : LongInt;
Var P : Integer;
Begin
  P := StartP;
  ConstEval := ConstEvalExpr(P);
End;

(* ---- TokenPoolInit : initialiser le pool de tokens ---------- *)

Procedure TokenPoolInit;
Begin
  TokenCount := 0;
End;

(* ---- TokenPoolAdd : ajouter un token au pool ---------------- *)

Procedure TokenPoolAdd(Const T : TToken);
Begin
  If TokenCount >= MAX_TOKEN Then
    FatalError('TokenPool plein (MAX_TOKEN atteint)');
  TokenPool[TokenCount].Kind   := T.Kind;
  TokenPool[TokenCount].Val    := T.Val;
  TokenPool[TokenCount].IntVal := T.IntVal;
  TokenPool[TokenCount].Line   := T.Line;
  TokenPool[TokenCount].Col    := T.Col;
  Inc(TokenCount);
End;

(* ---- TokenPoolConcatStrings : concatener les chaines adj. --- *)
(* En Modula-3, "abc" & "def" au niveau des constantes.         *)
(* Cette passe ne traite que les chaines litterales adjacentes.  *)

Procedure TokenPoolConcatStrings;
Var
  I, J : Integer;
Begin
  I := 0;
  While I < TokenCount - 2 Do
  Begin
    If (TokenPool[I].Kind = TK_STRING) And
       (TokenPool[I+1].Kind = TK_OP) And (TokenPool[I+1].Val = '&') And
       (TokenPool[I+2].Kind = TK_STRING) Then
    Begin
      (* Concatener les deux chaines *)
      TokenPool[I].Val := Copy(TokenPool[I].Val, 1,
                               Length(TokenPool[I].Val)) +
                          TokenPool[I+2].Val;
      (* Supprimer les deux tokens suivants *)
      For J := I + 1 To TokenCount - 3 Do
        TokenPool[J] := TokenPool[J + 2];
      Dec(TokenCount, 2);
    End
    Else
      Inc(I);
  End;
End;

(* ---- TokenPoolRegisterStrings : enregistrer les chaines ----- *)
(* Parcourir le TokenPool et ajouter chaque chaine dans DataTab. *)

Procedure TokenPoolRegisterStrings;
Var I : Integer;
Begin
  For I := 0 To TokenCount - 1 Do
  Begin
    If TokenPool[I].Kind = TK_STRING Then
      DataGetOrAddStr(TokenPool[I].Val);
  End;
End;

(* ---- Statistiques ----------------------------------------- *)

Procedure ShowStats;
Begin
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

(* ---- Boucle principale ------------------------------------ *)

Procedure Run;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;
  LexOpened  := False;

  If Opts.Verbose Then ShowBanner;

  DataInit;
  TokenPoolInit;

  LexInit;
  LexNextToken;

  (* Phase 1 : lire tous les tokens et les stocker dans TokenPool *)
  While CurToken.Kind <> TK_EOF Do
  Begin
    PrintToken(CurToken);
    TokenPoolAdd(CurToken);
    LexNextToken;
  End;
  PrintToken(CurToken); (* afficher le token EOF *)
  TokenPoolAdd(CurToken);

  LexClose;

  (* Phase 2 : concatener les chaines adjacentes et enregistrer *)
  TokenPoolConcatStrings;
  TokenPoolRegisterStrings;

  If Opts.Verbose Then
  Begin
    WriteLn('  Tokens         : ', TokenCount);
    WriteLn('  Donnees (DATA) : ', DataCount);
  End;

  (* TODO 04+ : ParseCompilationUnit, EmitRuntime, etc. *)

  If Opts.Verbose Then ShowStats;
  Cleanup;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

(* ============================================================
   PROGRAMME PRINCIPAL
   ============================================================ *)
Begin
  ParseArgs;
  Run;
End.
