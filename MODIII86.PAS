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

   TODO 02 - LEXEUR (TOKENS MODULA-3)
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

   TODO 03 - LITTERAUX ET CONSTANTES
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
  WriteLn(' error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('MODIII86:');
  WriteLn(' warning: ', Msg);
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
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
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

(* ---- Boucle principale (stub) ----------------------------- *)

Procedure Run;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;

  If Opts.Verbose Then ShowBanner;

  (* TODO 02+ : LexInit, ParseCompilationUnit, EmitRuntime, etc. *)

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
