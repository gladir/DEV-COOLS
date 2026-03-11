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

   TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

   TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
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

   TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

   TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
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

   TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
             TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_RECORD),
               IntVal, StrVal, ElemCount
             DataTab[0..MAX_DATA-1], DataCount
             DataAdd, DataAddStr, DataAddRecord : variantes d ajout
             Variables globales (VAR au niveau MODULE) : entrees DK_WORD dans DATA
             Constantes CONST : entrees DK_WORD ou DK_STR (immuables)
             Chaines TEXT litterales : DB 'abc',0 dans DATA avec label _M3K_N
             IsM3TypeKeyword : detecter les mots-cles de type Modula-3
             DataAddGlobalVar : creer entree DATA + symbole pour variable globale
             DataAddGlobalConst : creer entree DATA + symbole pour constante
             ParseDataDecls : scanner TokenPool pour blocs VAR/CONST au niveau MODULE
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

  (* Index de types primitifs (TypeTab TODO 06) *)
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
  TY_PRIM_COUNT  = 9;

  (* Bornes des types primitifs Modula-3 (8086 16 bits) *)
  MIN_INTEGER    = -32768;
  MAX_INTEGER    =  32767;
  MIN_CARDINAL   =  0;
  MAX_CARDINAL   =  65535;
  MIN_CHAR       =  0;
  MAX_CHAR       =  255;
  MIN_BOOLEAN    =  0;
  MAX_BOOLEAN    =  1;
  NUM_INTEGER    =  65536;
  NUM_CARDINAL   =  65536;
  NUM_CHAR       =  256;
  NUM_BOOLEAN    =  2;

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

  (* ---- Table des symboles (TODO 05) ------------------------- *)
  TSymKind = (
    SK_CONST,      (* constante (CONST)                           *)
    SK_TYPE,       (* type utilisateur (TYPE)                     *)
    SK_VAR,        (* variable (VAR)                              *)
    SK_PARAM,      (* parametre de procedure (VALUE/VAR/READONLY) *)
    SK_PROC,       (* procedure / fonction (PROCEDURE)            *)
    SK_FIELD,      (* champ de RECORD                             *)
    SK_METHOD,     (* methode d un OBJECT                         *)
    SK_MODULE,     (* module (MODULE / INTERFACE)                 *)
    SK_EXCEPTION   (* exception (EXCEPTION)                       *)
  );

  TSymRec = Record
    Name        : TString;   (* identifiant Modula-3 original         *)
    MangledName : TString;   (* nom ASM (_M3V_nom, _M3P_nom, ...)    *)
    Kind        : TSymKind;  (* categorie du symbole                  *)
    TypeIdx     : Integer;   (* index dans TypeTab (-1 si inconnu)    *)
    Offset      : Integer;   (* offset pile [BP-n] ou DATA            *)
    ScopeLevel  : Integer;   (* profondeur de portee (0 = global)     *)
    IsExported  : Boolean;   (* visible depuis INTERFACE              *)
    IsImported  : Boolean;   (* importe depuis un autre module        *)
    IsReadonly  : Boolean;   (* parametre READONLY                    *)
    ImmVal      : LongInt;   (* valeur immediate (SK_CONST)           *)
    DeclLine    : Integer;   (* ligne de declaration source           *)
  End;

  (* ---- Systeme de types (TODO 06) ----------------------------- *)
  TTypeKind = (
    TYK_INTEGER,   (* entier 16 bits signe                        *)
    TYK_CARDINAL,  (* entier 16 bits non signe                    *)
    TYK_BOOLEAN,   (* booleen 8 bits (0 ou 1), etendu a AX       *)
    TYK_CHAR,      (* caractere 8 bits (0..255), etendu a AX     *)
    TYK_REAL,      (* reel (stub: tronque en entier 16 bits)      *)
    TYK_LONGREAL,  (* long reel (stub: tronque en entier 16 bits) *)
    TYK_TEXT,      (* pointeur vers chaine ASCIIZ (2 octets)      *)
    TYK_ARRAY,     (* tableau fixe (BaseTypeIdx = type element)   *)
    TYK_OPENARRAY, (* tableau ouvert (taille inconnue statiquement)*)
    TYK_RECORD,    (* enregistrement (FieldCount champs)          *)
    TYK_SET,       (* ensemble d un type ordinal                  *)
    TYK_ENUM,      (* enumeration (EnumCount valeurs)             *)
    TYK_REF,       (* reference (pointeur trace)                  *)
    TYK_REFANY,    (* REFANY : pointeur generique trace           *)
    TYK_OBJECT,    (* objet (methodes + champs)                   *)
    TYK_PROC,      (* type procedure / fonction                   *)
    TYK_SUBRANGE,  (* sous-intervalle [Lo..Hi]                    *)
    TYK_PACKED,    (* BITS FOR n : type compacte                  *)
    TYK_OPAQUE,    (* type opaque (defini ailleurs)               *)
    TYK_NULL       (* NIL : type du pointeur nul                  *)
  );

  TFieldRec = Record
    Name    : TString;
    TypeIdx : Integer;     (* index dans TypeTab                    *)
    Offset  : Integer;     (* decalage en octets dans le record     *)
  End;

  TTypeRec = Record
    Kind        : TTypeKind;  (* categorie du type                  *)
    Name        : TString;    (* nom du type ('' si anonyme)        *)
    Size        : Integer;    (* taille en octets                   *)
    BaseTypeIdx : Integer;    (* type de base (array elem, ref, sub)*)
    Lo          : LongInt;    (* borne inf (subrange, array index)  *)
    Hi          : LongInt;    (* borne sup (subrange, array index)  *)
    FieldCount  : Integer;    (* nombre de champs (record)          *)
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    EnumCount   : Integer;    (* nombre de valeurs (enum)           *)
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

  (* Table des symboles (TODO 05) *)
  SymTab     : Array[0..MAX_SYM-1] Of TSymRec;
  SymCount   : Integer;
  ScopeTop   : Integer;         (* sommet de la pile de scopes         *)
  CurScope   : Integer;         (* niveau de portee courant            *)
  ScopeStack : Array[0..MAX_SCOPE-1] Of Integer; (* SymCount a l entree *)

  (* Systeme de types (TODO 06) *)
  TypeTab    : Array[0..MAX_TYPE-1] Of TTypeRec;
  TypeCount  : Integer;

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

(* ---- TypeFirst : FIRST(T) pour un nom de type --------------- *)

Function TypeFirst(Const TName : TString) : LongInt;
Var U : TString;
Begin
  U := StrUpCase(TName);
  If U = 'INTEGER'       Then TypeFirst := MIN_INTEGER
  Else If U = 'CARDINAL' Then TypeFirst := MIN_CARDINAL
  Else If U = 'CHAR'     Then TypeFirst := MIN_CHAR
  Else If U = 'BOOLEAN'  Then TypeFirst := MIN_BOOLEAN
  Else TypeFirst := 0;
End;

(* ---- TypeLast : LAST(T) pour un nom de type ----------------- *)

Function TypeLast(Const TName : TString) : LongInt;
Var U : TString;
Begin
  U := StrUpCase(TName);
  If U = 'INTEGER'       Then TypeLast := MAX_INTEGER
  Else If U = 'CARDINAL' Then TypeLast := MAX_CARDINAL
  Else If U = 'CHAR'     Then TypeLast := MAX_CHAR
  Else If U = 'BOOLEAN'  Then TypeLast := MAX_BOOLEAN
  Else TypeLast := 0;
End;

(* ---- TypeNumber : NUMBER(T) pour un nom de type ------------- *)

Function TypeNumber(Const TName : TString) : LongInt;
Var U : TString;
Begin
  U := StrUpCase(TName);
  If U = 'INTEGER'       Then TypeNumber := NUM_INTEGER
  Else If U = 'CARDINAL' Then TypeNumber := NUM_CARDINAL
  Else If U = 'CHAR'     Then TypeNumber := NUM_CHAR
  Else If U = 'BOOLEAN'  Then TypeNumber := NUM_BOOLEAN
  Else TypeNumber := 0;
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

    (* FIRST(INTEGER), FIRST(CARDINAL), etc. *)
    Else If S = 'FIRST' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        V := TypeFirst(TokenPool[P].Val);
        Inc(P);
      End;
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    End

    (* LAST(INTEGER), LAST(CARDINAL), etc. *)
    Else If S = 'LAST' Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = '(') Then Inc(P);
      If (P < TokenCount) Then
      Begin
        V := TypeLast(TokenPool[P].Val);
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
        V := TypeNumber(TokenPool[P].Val);
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
        V := TypeFirst(TokenPool[P].Val);
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
        V := TypeLast(TokenPool[P].Val);
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
        V := TypeNumber(TokenPool[P].Val);
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

(* ============================================================
   TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
   ============================================================ *)

(* ---- IsM3BinOp : vrai si le token est un operateur binaire -- *)
(* Operateurs binaires Modula-3 : + - * / & = # < <= > >=       *)
(* Mots-cles operateurs : DIV MOD AND OR IN                      *)

Function IsM3BinOp(Const T : TPoolToken) : Boolean;
Begin
  IsM3BinOp := False;
  If T.Kind = TK_OP Then
  Begin
    If (T.Val = '+') Or (T.Val = '-') Or (T.Val = '*') Or
       (T.Val = '/') Or (T.Val = '&') Or (T.Val = '=') Or
       (T.Val = '#') Or (T.Val = '<') Or (T.Val = '>') Or
       (T.Val = '<=') Or (T.Val = '>=') Then
      IsM3BinOp := True;
  End
  Else If T.Kind = TK_KEYWORD Then
  Begin
    If (T.Val = 'DIV') Or (T.Val = 'MOD') Or
       (T.Val = 'AND') Or (T.Val = 'OR') Or
       (T.Val = 'IN') Then
      IsM3BinOp := True;
  End;
End;

(* ---- BinOpPrec : table de precedences Modula-3 (Pratt) ------ *)
(* Retourne 0 si l operateur n est pas binaire.                  *)
(* Niveaux (croissant = plus serre) :                            *)
(*   OR                         -> 1  (OU logique)               *)
(*   AND                        -> 2  (ET logique)               *)
(*   = # < <= > >= IN           -> 3  (comparaison/appartenance) *)
(*   + - (binaire)              -> 4  (additif)                  *)
(*   * DIV MOD / &              -> 5  (multiplicatif/concat)     *)
(*   NOT unaire +/-             -> traites par ParseUnary/Const  *)

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = 'OR' Then
    BinOpPrec := 1
  Else If Op = 'AND' Then
    BinOpPrec := 2
  Else If (Op = '=') Or (Op = '#') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Or (Op = 'IN') Then
    BinOpPrec := 3
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 4
  Else If (Op = '*') Or (Op = 'DIV') Or (Op = 'MOD') Or
          (Op = '/') Or (Op = '&') Then
    BinOpPrec := 5
  Else
    BinOpPrec := 0;
End;

(* ---- BinOpIsRight : vrai si operateur droit-associatif ------ *)
(* En Modula-3 aucun operateur binaire standard n est droite,    *)
(* sauf := qui est traite separement.                            *)

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := False;
End;

(* ---- ExprFlushToAX : charger TExprVal dans AX --------------- *)
(* Genere le code 8086 pour mettre la valeur de E dans AX.       *)

Procedure ExprFlushToAX(Var E : TExprVal);
Var S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      WriteLn(OutF, '        MOV     AX, ', S);
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      If (E.Offset >= 0) And (E.Offset < DataCount) Then
      Begin
        (* Charger l adresse d une chaine DATA dans AX *)
        If DataTab[E.Offset].Kind = DK_STR Then
          WriteLn(OutF, '        LEA     AX, ', DataTab[E.Offset].LblName)
        Else
          WriteLn(OutF, '        MOV     AX, WORD PTR ', DataTab[E.Offset].LblName);
      End
      Else
      Begin
        Str(E.Offset, S);
        WriteLn(OutF, '        MOV     AX, WORD PTR [BP+', S, ']');
      End;
      E.Kind := EK_AX;
    End;
    EK_AX :
      ; (* deja dans AX *)
    EK_NONE :
      WriteLn(OutF, '        XOR     AX, AX');
  End;
End;

(* ---- EmitBinOp : generer le code 8086 pour AX op BX --------- *)
(* AX contient l operande gauche, BX l operande droite.          *)
(* Resultat dans AX.                                              *)

Procedure EmitBinOp(Const Op : TString);
Var
  LblTrue, LblEnd : TString;
Begin
  (* Arithmetique entiere *)
  If Op = '+' Then
    WriteLn(OutF, '        ADD     AX, BX')
  Else If Op = '-' Then
    WriteLn(OutF, '        SUB     AX, BX')
  Else If Op = '*' Then
    WriteLn(OutF, '        IMUL    BX')
  Else If (Op = 'DIV') Or (Op = '/') Then
  Begin
    WriteLn(OutF, '        CWD');
    WriteLn(OutF, '        IDIV    BX');
    (* quotient dans AX *)
  End
  Else If Op = 'MOD' Then
  Begin
    WriteLn(OutF, '        CWD');
    WriteLn(OutF, '        IDIV    BX');
    WriteLn(OutF, '        MOV     AX, DX');
    (* reste dans DX -> AX *)
  End

  (* Concatenation TEXT : & -> CALL _M3RT_CONCAT *)
  Else If Op = '&' Then
  Begin
    WriteLn(OutF, '        MOV     SI, AX');
    WriteLn(OutF, '        MOV     DI, BX');
    WriteLn(OutF, '        CALL    ', M3_RT_PFX, 'CONCAT');
    (* resultat dans AX *)
  End

  (* Comparaisons : = # < <= > >= *)
  Else If (Op = '=') Or (Op = '#') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Then
  Begin
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblTrue);
    LblTrue := M3_LBL_PFX + LblTrue;
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblEnd);
    LblEnd := M3_LBL_PFX + LblEnd;

    WriteLn(OutF, '        CMP     AX, BX');
    If Op = '=' Then
      WriteLn(OutF, '        JE      ', LblTrue)
    Else If Op = '#' Then
      WriteLn(OutF, '        JNE     ', LblTrue)
    Else If Op = '<' Then
      WriteLn(OutF, '        JL      ', LblTrue)
    Else If Op = '>' Then
      WriteLn(OutF, '        JG      ', LblTrue)
    Else If Op = '<=' Then
      WriteLn(OutF, '        JLE     ', LblTrue)
    Else If Op = '>=' Then
      WriteLn(OutF, '        JGE     ', LblTrue);
    WriteLn(OutF, '        XOR     AX, AX');
    WriteLn(OutF, '        JMP     SHORT ', LblEnd);
    WriteLn(OutF, LblTrue, ':');
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, LblEnd, ':');
  End

  (* IN : element IN ensemble (stub - traite comme comparaison) *)
  Else If Op = 'IN' Then
  Begin
    (* Stub : teste si bit AX est dans le masque BX *)
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblTrue);
    LblTrue := M3_LBL_PFX + LblTrue;
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblEnd);
    LblEnd := M3_LBL_PFX + LblEnd;

    WriteLn(OutF, '        MOV     CX, AX');
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, '        SHL     AX, CL');
    WriteLn(OutF, '        TEST    AX, BX');
    WriteLn(OutF, '        JNZ     ', LblTrue);
    WriteLn(OutF, '        XOR     AX, AX');
    WriteLn(OutF, '        JMP     SHORT ', LblEnd);
    WriteLn(OutF, LblTrue, ':');
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, LblEnd, ':');
  End

  (* AND logique (court-circuit) *)
  Else If Op = 'AND' Then
  Begin
    (* AX = (AX <> 0) AND (BX <> 0) *)
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblEnd);
    LblEnd := M3_LBL_PFX + LblEnd;

    WriteLn(OutF, '        TEST    AX, AX');
    WriteLn(OutF, '        JZ      ', LblEnd);
    WriteLn(OutF, '        TEST    BX, BX');
    WriteLn(OutF, '        JZ      ', LblEnd);
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, LblEnd, ':');
  End

  (* OR logique (court-circuit) *)
  Else If Op = 'OR' Then
  Begin
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblTrue);
    LblTrue := M3_LBL_PFX + LblTrue;
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblEnd);
    LblEnd := M3_LBL_PFX + LblEnd;

    WriteLn(OutF, '        TEST    AX, AX');
    WriteLn(OutF, '        JNZ     ', LblTrue);
    WriteLn(OutF, '        TEST    BX, BX');
    WriteLn(OutF, '        JNZ     ', LblTrue);
    WriteLn(OutF, '        XOR     AX, AX');
    WriteLn(OutF, '        JMP     SHORT ', LblEnd);
    WriteLn(OutF, LblTrue, ':');
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, LblEnd, ':');
  End;
End;

(* ---- EmitUnaryOp : generer le code 8086 pour op unaire ------- *)
(* NOT : negation logique (AX=0 -> 1, AX<>0 -> 0)               *)
(* unaire - : NEG AX                                              *)
(* unaire + : noop                                                *)

Procedure EmitUnaryOp(Const Op : TString);
Var LblZero, LblEnd : TString;
Begin
  If Op = 'NOT' Then
  Begin
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblZero);
    LblZero := M3_LBL_PFX + LblZero;
    Inc(LabelGenSeq);
    Str(LabelGenSeq, LblEnd);
    LblEnd := M3_LBL_PFX + LblEnd;

    WriteLn(OutF, '        TEST    AX, AX');
    WriteLn(OutF, '        JZ      ', LblZero);
    WriteLn(OutF, '        XOR     AX, AX');
    WriteLn(OutF, '        JMP     SHORT ', LblEnd);
    WriteLn(OutF, LblZero, ':');
    WriteLn(OutF, '        MOV     AX, 1');
    WriteLn(OutF, LblEnd, ':');
  End
  Else If Op = '-' Then
    WriteLn(OutF, '        NEG     AX')
  Else If Op = '+' Then
    (* noop *)
  ;
End;

(* ============================================================
   TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
   ============================================================ *)

(* ---- SymKindStr : nom textuel d un TSymKind ----------------- *)
Function SymKindStr(K : TSymKind) : TString;
Begin
  Case K Of
    SK_CONST     : SymKindStr := 'CONST';
    SK_TYPE      : SymKindStr := 'TYPE';
    SK_VAR       : SymKindStr := 'VAR';
    SK_PARAM     : SymKindStr := 'PARAM';
    SK_PROC      : SymKindStr := 'PROC';
    SK_FIELD     : SymKindStr := 'FIELD';
    SK_METHOD    : SymKindStr := 'METHOD';
    SK_MODULE    : SymKindStr := 'MODULE';
    SK_EXCEPTION : SymKindStr := 'EXCEPTION';
  Else
    SymKindStr := '?';
  End;
End;

(* ---- SymNameClean : nettoyer un identifiant pour ASM --------- *)
(* Remplace les caracteres non alphanumeriques par '_'.            *)

Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
  C : Char;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or (C = '_') Then
      R := R + C
    Else
      R := R + '_';
  End;
  SymNameClean := R;
End;

(* ---- SymMangle : generer un nom ASM mangled pour un symbole -- *)
(* Utilise les prefixes M3_VAR_PFX, M3_PROC_PFX, etc.            *)

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_CONST     : SymMangle := M3_VAR_PFX  + Clean;
    SK_TYPE      : SymMangle := M3_TYPE_PFX + Clean;
    SK_VAR       : SymMangle := M3_VAR_PFX  + Clean;
    SK_PARAM     : SymMangle := M3_VAR_PFX  + Clean;
    SK_PROC      : SymMangle := M3_PROC_PFX + Clean;
    SK_FIELD     : SymMangle := M3_OBJ_PFX  + Clean;
    SK_METHOD    : SymMangle := M3_PROC_PFX + Clean;
    SK_MODULE    : SymMangle := M3_VAR_PFX  + Clean;
    SK_EXCEPTION : SymMangle := M3_EXC_PFX  + Clean;
  Else
    SymMangle := M3_VAR_PFX + Clean;
  End;
End;

(* ---- SymInit : initialiser la table des symboles ------------- *)

Procedure SymInit;
Var I : Integer;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].IsExported  := False;
    SymTab[I].IsImported  := False;
    SymTab[I].IsReadonly  := False;
    SymTab[I].ImmVal      := 0;
    SymTab[I].DeclLine    := 0;
  End;
  For I := 0 To MAX_SCOPE - 1 Do
    ScopeStack[I] := 0;
End;

(* ---- SymFind : rechercher un symbole par nom (du plus recent) *)
(* Parcourt de la fin vers le debut pour respecter le shadowing.  *)

Function SymFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

(* ---- SymFindInScope : rechercher dans un scope precis -------- *)
(* Ne retourne que les symboles dont ScopeLevel = Level.           *)

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

(* ---- SymAdd : ajouter un symbole dans la table --------------- *)
(* Retourne l index du symbole (0-base) ou -1 si la table est     *)
(* pleine.                                                         *)

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].IsExported  := False;
  SymTab[SymCount].IsImported  := False;
  SymTab[SymCount].IsReadonly  := False;
  SymTab[SymCount].ImmVal      := 0;
  SymTab[SymCount].DeclLine    := 0;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', SymCount, ']: ', Name,
            ' kind=', SymKindStr(Kind),
            ' scope=', CurScope,
            ' -> ', SymTab[SymCount].MangledName);

  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

(* ---- SymEnterScope : entrer dans une nouvelle portee --------- *)
(* Chaque BEGIN, PROCEDURE, MODULE cree un nouvel environnement.  *)

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' +
                 IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

(* ---- SymLeaveScope : quitter la portee courante -------------- *)
(* Les symboles locaux de cette portee sont retires de la table.   *)

Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('SymLeaveScope: pile de scopes vide');
    Exit;
  End;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

(* ---- SymRegisterBuiltins : enregistrer les predeclares M3 --- *)
(* Types primitifs, constantes predefinies, et procedures          *)
(* predeclares de Modula-3.                                        *)

Procedure SymRegisterBuiltins;
Begin
  (* Types primitifs Modula-3 *)
  SymAdd('INTEGER',     SK_TYPE, TY_IDX_INTEGER,  0);
  SymAdd('CARDINAL',    SK_TYPE, TY_IDX_CARDINAL, 0);
  SymAdd('BOOLEAN',     SK_TYPE, TY_IDX_BOOLEAN,  0);
  SymAdd('CHAR',        SK_TYPE, TY_IDX_CHAR,     0);
  SymAdd('REAL',        SK_TYPE, TY_IDX_REAL,      0);
  SymAdd('LONGREAL',    SK_TYPE, TY_IDX_LONGREAL,  0);
  SymAdd('TEXT',        SK_TYPE, TY_IDX_TEXT,      0);

  (* Constantes predefinies *)
  SymAdd('TRUE',        SK_CONST, TY_IDX_BOOLEAN, 0);
  SymTab[SymCount - 1].ImmVal := 1;
  SymAdd('FALSE',       SK_CONST, TY_IDX_BOOLEAN, 0);
  SymTab[SymCount - 1].ImmVal := 0;
  SymAdd('NIL',         SK_CONST, TY_IDX_NIL,     0);
  SymTab[SymCount - 1].ImmVal := 0;

  (* Procedures predefinies Modula-3 *)
  SymAdd('ABS',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('MAX',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('MIN',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('ORD',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('VAL',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('FIRST',       SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('LAST',        SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('NUMBER',      SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('FLOAT',       SK_PROC, TY_IDX_REAL,     0);
  SymAdd('TRUNC',       SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('ROUND',       SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('CEILING',     SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('FLOOR',       SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('INC',         SK_PROC, TY_IDX_VOID,     0);
  SymAdd('DEC',         SK_PROC, TY_IDX_VOID,     0);
  SymAdd('NEW',         SK_PROC, TY_IDX_NIL,      0);
  SymAdd('DISPOSE',     SK_PROC, TY_IDX_VOID,     0);
  SymAdd('ISTYPE',      SK_PROC, TY_IDX_BOOLEAN,  0);
  SymAdd('NARROW',      SK_PROC, TY_IDX_NIL,      0);
  SymAdd('TYPECODE',    SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('BITSIZE',     SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('BYTESIZE',    SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('ADRSIZE',     SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('LOOPHOLE',    SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('ADR',         SK_PROC, TY_IDX_INTEGER,  0);
  SymAdd('SUBARRAY',    SK_PROC, TY_IDX_INTEGER,  0);

  (* Modules standard couramment importes *)
  SymAdd('Wr',          SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Rd',          SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Fmt',         SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Text',        SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Stdio',       SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Math',        SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Word',        SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Process',     SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('IO',          SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;
  SymAdd('Params',      SK_MODULE, TY_UNKNOWN, 0);
  SymTab[SymCount - 1].IsImported := True;

  (* Exceptions predefinies *)
  SymAdd('RuntimeError', SK_EXCEPTION, TY_UNKNOWN, 0);

  If Opts.DebugMode Then
    WriteLn('  Builtins registres : ', SymCount, ' symboles');
End;

(* ============================================================
   TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
   ============================================================ *)

(* ---- TypeKindStr : nom textuel d un TTypeKind --------------- *)

Function TypeKindStr(K : TTypeKind) : TString;
Begin
  Case K Of
    TYK_INTEGER   : TypeKindStr := 'INTEGER';
    TYK_CARDINAL  : TypeKindStr := 'CARDINAL';
    TYK_BOOLEAN   : TypeKindStr := 'BOOLEAN';
    TYK_CHAR      : TypeKindStr := 'CHAR';
    TYK_REAL      : TypeKindStr := 'REAL';
    TYK_LONGREAL  : TypeKindStr := 'LONGREAL';
    TYK_TEXT      : TypeKindStr := 'TEXT';
    TYK_ARRAY     : TypeKindStr := 'ARRAY';
    TYK_OPENARRAY : TypeKindStr := 'OPENARRAY';
    TYK_RECORD    : TypeKindStr := 'RECORD';
    TYK_SET       : TypeKindStr := 'SET';
    TYK_ENUM      : TypeKindStr := 'ENUM';
    TYK_REF       : TypeKindStr := 'REF';
    TYK_REFANY    : TypeKindStr := 'REFANY';
    TYK_OBJECT    : TypeKindStr := 'OBJECT';
    TYK_PROC      : TypeKindStr := 'PROCEDURE';
    TYK_SUBRANGE  : TypeKindStr := 'SUBRANGE';
    TYK_PACKED    : TypeKindStr := 'PACKED';
    TYK_OPAQUE    : TypeKindStr := 'OPAQUE';
    TYK_NULL      : TypeKindStr := 'NULL';
  Else
    TypeKindStr := '?';
  End;
End;

(* ---- TypeInit : initialiser TypeTab avec les types primitifs -- *)
(* Enregistre les 9 types primitifs Modula-3 aux indices reserves  *)
(* TY_IDX_xxx. Tailles en octets pour cible 8086 16 bits.         *)

Procedure TypeInit;

  Procedure AddPrim(Idx : Integer; K : TTypeKind;
                    Const AName : TString; Sz : Integer);
  Begin
    TypeTab[Idx].Kind        := K;
    TypeTab[Idx].Name        := AName;
    TypeTab[Idx].Size        := Sz;
    TypeTab[Idx].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 0;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].EnumCount   := 0;
  End;

Var I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind        := TYK_NULL;
    TypeTab[I].Name        := '';
    TypeTab[I].Size        := 0;
    TypeTab[I].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[I].Lo          := 0;
    TypeTab[I].Hi          := 0;
    TypeTab[I].FieldCount  := 0;
    TypeTab[I].EnumCount   := 0;
  End;

  AddPrim(TY_IDX_INTEGER,  TYK_INTEGER,  'INTEGER',  2);
  AddPrim(TY_IDX_CARDINAL, TYK_CARDINAL, 'CARDINAL', 2);
  AddPrim(TY_IDX_BOOLEAN,  TYK_BOOLEAN,  'BOOLEAN',  1);
  AddPrim(TY_IDX_CHAR,     TYK_CHAR,     'CHAR',     1);
  AddPrim(TY_IDX_REAL,     TYK_REAL,     'REAL',     2);
  AddPrim(TY_IDX_LONGREAL, TYK_LONGREAL, 'LONGREAL', 2);
  AddPrim(TY_IDX_TEXT,     TYK_TEXT,     'TEXT',     2);
  AddPrim(TY_IDX_NIL,      TYK_NULL,    'NIL',      2);
  AddPrim(TY_IDX_VOID,     TYK_NULL,    'VOID',     0);

  TypeCount := TY_PRIM_COUNT;

  If Opts.DebugMode Then
    WriteLn('  TypeInit : ', TypeCount, ' types primitifs');
End;

(* ---- TypeAdd : ajouter un type dans TypeTab ------------------- *)
(* Retourne l index du nouveau type (0-base) ou -1 si plein.       *)

Function TypeAdd(Kind : TTypeKind; Const AName : TString;
                 Size : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    CompileError('table des types pleine (max=' +
                 IntToStr(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;
  TypeTab[TypeCount].Kind        := Kind;
  TypeTab[TypeCount].Name        := AName;
  TypeTab[TypeCount].Size        := Size;
  TypeTab[TypeCount].BaseTypeIdx := TY_UNKNOWN;
  TypeTab[TypeCount].Lo          := 0;
  TypeTab[TypeCount].Hi          := 0;
  TypeTab[TypeCount].FieldCount  := 0;
  TypeTab[TypeCount].EnumCount   := 0;

  If Opts.DebugMode Then
    WriteLn('  TYPE_ADD[', TypeCount, ']: ', AName,
            ' kind=', TypeKindStr(Kind),
            ' size=', Size);

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

(* ---- TypeSizeof : taille en octets d un type par son index ---- *)
(* Retourne 2 (mot 16 bits) par defaut si l index est invalide.    *)

Function TypeSizeof(TIdx : Integer) : Integer;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeSizeof := TypeTab[TIdx].Size
  Else
    TypeSizeof := 2;
End;

(* ---- TypeKindOf : retourner le TTypeKind pour un indice ------- *)

Function TypeKindOf(TIdx : Integer) : TTypeKind;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeKindOf := TypeTab[TIdx].Kind
  Else
    TypeKindOf := TYK_NULL;
End;

(* ---- TypeFindByName : rechercher un type par nom -------------- *)
(* Retourne l index dans TypeTab ou TY_UNKNOWN si non trouve.       *)

Function TypeFindByName(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
  TypeFindByName := TY_UNKNOWN;
End;

(* ---- TypeIsOrdinal : le type est-il ordinal ? ----------------- *)
(* Types ordinaux en Modula-3 : INTEGER, CARDINAL, CHAR, BOOLEAN,  *)
(* ENUM, SUBRANGE.                                                  *)

Function TypeIsOrdinal(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TYK_INTEGER, TYK_CARDINAL, TYK_CHAR,
    TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

(* ---- TypeIsNumeric : le type est-il numerique ? --------------- *)
(* Types numeriques : INTEGER, CARDINAL, REAL, LONGREAL.           *)

Function TypeIsNumeric(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TYK_INTEGER, TYK_CARDINAL, TYK_REAL, TYK_LONGREAL :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

(* ---- TypeIsPointer : le type est-il un pointeur ? ------------- *)
(* Types pointeur : REF, REFANY, OBJECT, TEXT, NULL (NIL).         *)

Function TypeIsPointer(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TYK_REF, TYK_REFANY, TYK_OBJECT, TYK_TEXT, TYK_NULL :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

(* ---- TypeCompatible : deux types sont-ils compatibles ? ------- *)
(* Retourne True si une valeur de type T2 peut etre affectee a T1. *)
(* Applique les regles d assignabilite de Modula-3 :                *)
(*   - meme type : toujours compatible                              *)
(*   - INTEGER <-> CARDINAL (promotion implicite 8086)              *)
(*   - CHAR <-> INTEGER/CARDINAL (ORD/VAL)                          *)
(*   - BOOLEAN -> INTEGER/CARDINAL (0|1)                            *)
(*   - REAL <-> INTEGER/CARDINAL (troncature)                       *)
(*   - NIL -> tout type reference (REF, REFANY, OBJECT, TEXT)       *)
(*   - SUBRANGE -> son type de base                                 *)
(*   - ENUM -> INTEGER (ORD)                                        *)

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

  (* NIL -> tout type reference ou TEXT *)
  If K2 = TYK_NULL Then
  Begin
    TypeCompatible := (K1 = TYK_REF) Or (K1 = TYK_REFANY) Or
                      (K1 = TYK_OBJECT) Or (K1 = TYK_TEXT) Or
                      (K1 = TYK_NULL) Or (K1 = TYK_PROC);
    Exit;
  End;

  (* INTEGER <-> CARDINAL (meme representation 16 bits sur 8086) *)
  If ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) And
     ((K2 = TYK_INTEGER) Or (K2 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* CHAR -> INTEGER/CARDINAL (ORD implicite) *)
  If (K2 = TYK_CHAR) And
     ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* INTEGER/CARDINAL -> CHAR (VAL implicite, avec bornes) *)
  If (K1 = TYK_CHAR) And
     ((K2 = TYK_INTEGER) Or (K2 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* BOOLEAN -> INTEGER/CARDINAL (0|1) *)
  If (K2 = TYK_BOOLEAN) And
     ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* INTEGER/CARDINAL -> BOOLEAN (non-zero = TRUE) *)
  If (K1 = TYK_BOOLEAN) And
     ((K2 = TYK_INTEGER) Or (K2 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* REAL <-> INTEGER/CARDINAL (troncature) *)
  If ((K1 = TYK_REAL) Or (K1 = TYK_LONGREAL)) And
     ((K2 = TYK_INTEGER) Or (K2 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) And
     ((K2 = TYK_REAL) Or (K2 = TYK_LONGREAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* REAL <-> LONGREAL *)
  If ((K1 = TYK_REAL) And (K2 = TYK_LONGREAL)) Or
     ((K1 = TYK_LONGREAL) And (K2 = TYK_REAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* ENUM -> INTEGER/CARDINAL (ORD implicite) *)
  If (K2 = TYK_ENUM) And
     ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* SUBRANGE -> son type de base *)
  If (K2 = TYK_SUBRANGE) And
     (TypeTab[T2].BaseTypeIdx = T1) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If (K1 = TYK_SUBRANGE) And
     (TypeTab[T1].BaseTypeIdx = T2) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* SUBRANGE <-> INTEGER/CARDINAL (le sous-type ordinal courant) *)
  If (K2 = TYK_SUBRANGE) And
     ((K1 = TYK_INTEGER) Or (K1 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If (K1 = TYK_SUBRANGE) And
     ((K2 = TYK_INTEGER) Or (K2 = TYK_CARDINAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* REF <-> REFANY *)
  If ((K1 = TYK_REF) And (K2 = TYK_REFANY)) Or
     ((K1 = TYK_REFANY) And (K2 = TYK_REF)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  (* OBJECT <-> REFANY *)
  If ((K1 = TYK_OBJECT) And (K2 = TYK_REFANY)) Or
     ((K1 = TYK_REFANY) And (K2 = TYK_OBJECT)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  TypeCompatible := False;
End;

(* ---- TypeResolve : resoudre un nom de type via SymTab ---------- *)
(* Recherche un symbole de categorie SK_TYPE et retourne TypeIdx.    *)

Function TypeResolve(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name);
  If (Idx >= 0) And (SymTab[Idx].Kind = SK_TYPE) Then
    TypeResolve := SymTab[Idx].TypeIdx
  Else
    TypeResolve := TY_UNKNOWN;
End;

(* ============================================================
   TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
   ============================================================ *)

(* ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- *)

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

(* ---- EmitBlankLine : ligne vide dans la sortie ASM ---------- *)

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

(* ---- EmitComment : ecrire un commentaire ASM ('; texte') ----- *)

Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

(* ---- EmitLabel : ecrire un label ASM ('LBL:') --------------- *)

Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

(* ---- EmitInstr : emettre une instruction sans operande ------- *)

Procedure EmitInstr(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

(* ---- EmitInstrA : emettre une instruction avec 1 operande ---- *)

Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1);
End;

(* ---- EmitInstrAB : emettre une instruction avec 2 operandes -- *)

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1 + ', ' + A2);
End;

(* ---- EmitOpen : ouvrir le fichier de sortie ASM ------------- *)

Procedure EmitOpen;
Begin
  {$I-}
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + Opts.OutFile);
  OutFOpen := True;
End;

(* ---- EmitHeader : en-tete du fichier ASM -------------------- *)
(* Genere .MODEL SMALL, .STACK, _TEXT SEGMENT, point d entree    *)
(* principal avec initialisation de DS.                          *)

Procedure EmitHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Genere par MODIII86 v' + MODIII86_VERSION +
              ' (' + MODIII86_DATE + ')');
  EmitComment('Source  : ' + Opts.SrcFile);
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitComment('--- Segment de code ---');
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitComment('--- Point d''entree principal ---');
  EmitLabel(M3_PROC_PFX + 'Main');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

(* ---- EmitProlog : prologue de procedure/fonction ------------ *)
(* Cree le cadre de pile : PUSH BP / MOV BP,SP / SUB SP,n        *)
(* Sauvegarde SI et DI.                                          *)

Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If FrameSize > 0 Then
    EmitInstrAB('SUB', 'SP', IntToStr(FrameSize));
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
End;

(* ---- EmitEpilog : epilogue de procedure/fonction ------------ *)
(* Restaure DI/SI, detruit le cadre de pile, retour.             *)

Procedure EmitEpilog(ParamBytes : Integer);
Begin
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  If ParamBytes > 0 Then
    EmitInstrA('RET', IntToStr(ParamBytes))
  Else
    EmitInstr('RET');
End;

(* ---- EmitDataSeg : emettre le segment de donnees ------------ *)
(* Genere _DATA SEGMENT avec les buffers internes, les donnees   *)
(* du programme (chaines, variables globales, records, arrays)    *)
(* et ferme avec _DATA ENDS.                                     *)

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S, Tmp : TString;
  Ch   : Char;
  InQ  : Boolean;
  Need : Boolean;
  Sz   : Integer;
Begin
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitBlankLine;
  EmitComment('--- Buffers internes Modula-3 ---');
  EmitRaw(M3_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(M3_RT_PFX + 'STRBUF  DB  512 DUP(0)');
  EmitRaw(M3_RT_PFX + 'NUMBUF  DB  12 DUP(0)');
  EmitRaw(M3_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(M3_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  EmitRaw(M3_RT_PFX + 'HEAP    DB  4096 DUP(0)');
  EmitRaw(M3_RT_PFX + 'HEAPTOP DW  OFFSET ' + M3_RT_PFX + 'HEAP');
  EmitBlankLine;

  (* Donnees du programme depuis DataTab *)
  If DataCount > 0 Then
    EmitComment('--- Donnees du programme ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
      Begin
        (* Emettre la chaine avec gestion des caracteres speciaux *)
        S := DataTab[I].LblName + '  DB  ';
        InQ  := False;
        Need := False;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          Ch := DataTab[I].StrVal[J];
          If (Ord(Ch) >= 32) And (Ord(Ch) <= 126) And (Ch <> '''') Then
          Begin
            If Not InQ Then
            Begin
              If Need Then S := S + ',';
              S := S + '''';
              InQ := True;
              Need := False;
            End;
            S := S + Ch;
          End
          Else
          Begin
            If InQ Then
            Begin
              S := S + '''';
              InQ := False;
            End;
            If Need Then S := S + ',';
            Str(Ord(Ch), Tmp);
            S := S + Tmp;
            Need := True;
          End;
        End;
        If InQ Then S := S + '''';
        If Need Or InQ Then S := S + ',';
        S := S + '0';
        EmitRaw(S);
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
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].RecSize) + ' DUP(0)');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

(* ---- EmitClose : terminer et fermer le fichier ASM ---------- *)
(* Emet la sortie DOS (INT 21h/4Ch), ferme _TEXT SEGMENT,        *)
(* genere le segment de donnees, et ecrit END _M3P_Main.         *)

Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- Sortie programme (DOS INT 21h) ---');
  EmitInstrAB('MOV', 'AH', '4Ch');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('INT    21h');
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  (* Segment de donnees *)
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END ' + M3_PROC_PFX + 'Main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

(* ============================================================
   TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
   ============================================================ *)

(* ---- IsM3TypeKeyword : detecter un mot-cle de type Modula-3 - *)
(* Retourne True si Val est un type primitif reconnu.             *)

Function IsM3TypeKeyword(Const V : TString) : Boolean;
Begin
  IsM3TypeKeyword :=
    (V = 'INTEGER')  Or (V = 'CARDINAL') Or (V = 'BOOLEAN') Or
    (V = 'CHAR')     Or (V = 'REAL')     Or (V = 'LONGREAL') Or
    (V = 'TEXT')     Or (V = 'REFANY')   Or (V = 'ROOT');
End;

(* ---- TypeIdxFromName : retourne l index de type pour un nom -- *)
(* Reconnait les types primitifs et retourne leur TY_IDX.         *)

Function TypeIdxFromName(Const V : TString) : Integer;
Begin
  If V = 'INTEGER'  Then TypeIdxFromName := TY_IDX_INTEGER
  Else If V = 'CARDINAL' Then TypeIdxFromName := TY_IDX_CARDINAL
  Else If V = 'BOOLEAN'  Then TypeIdxFromName := TY_IDX_BOOLEAN
  Else If V = 'CHAR'     Then TypeIdxFromName := TY_IDX_CHAR
  Else If V = 'REAL'     Then TypeIdxFromName := TY_IDX_REAL
  Else If V = 'LONGREAL' Then TypeIdxFromName := TY_IDX_LONGREAL
  Else If V = 'TEXT'     Then TypeIdxFromName := TY_IDX_TEXT
  Else If V = 'REFANY'   Then TypeIdxFromName := TY_IDX_NIL
  Else TypeIdxFromName := TY_UNKNOWN;
End;

(* ---- TypeSizeFromIdx : retourne la taille en octets d un type *)

Function TypeSizeFromIdx(TIdx : Integer) : Integer;
Begin
  Case TIdx Of
    TY_IDX_INTEGER  : TypeSizeFromIdx := 2;
    TY_IDX_CARDINAL : TypeSizeFromIdx := 2;
    TY_IDX_BOOLEAN  : TypeSizeFromIdx := 1;
    TY_IDX_CHAR     : TypeSizeFromIdx := 1;
    TY_IDX_REAL     : TypeSizeFromIdx := 2;
    TY_IDX_LONGREAL : TypeSizeFromIdx := 2;
    TY_IDX_TEXT     : TypeSizeFromIdx := 2;
    TY_IDX_NIL      : TypeSizeFromIdx := 2;
  Else
    TypeSizeFromIdx := 2;  (* defaut : mot 16 bits *)
  End;
End;

(* ---- DataAddGlobalVar : creer une variable globale DATA ----- *)
(* Cree une entree DK_WORD ou DK_BYTE dans DataTab et enregistre *)
(* le symbole correspondant dans SymTab avec mangling _M3V_name. *)

Procedure DataAddGlobalVar(Const Name : TString; TIdx : Integer;
                           InitVal : LongInt);
Var
  Lbl : TString;
  Sz  : Integer;
  SI  : Integer;
Begin
  Lbl := M3_VAR_PFX + Name;
  Sz  := TypeSizeFromIdx(TIdx);
  If Sz <= 1 Then
    DataAddByte(Lbl, InitVal)
  Else
    DataAddWord(Lbl, InitVal);
  SI := SymAdd(Name, SK_VAR, TIdx, DataCount - 1);
  If SI >= 0 Then
    SymTab[SI].MangledName := Lbl;
End;

(* ---- DataAddGlobalConst : creer une constante globale DATA -- *)
(* Cree une entree DK_WORD (entier) ou DK_STR (chaine) et       *)
(* enregistre le symbole dans SymTab avec SK_CONST.              *)

Procedure DataAddGlobalConst(Const Name : TString; TIdx : Integer;
                             IVal : LongInt; Const SVal : TString);
Var
  Lbl : TString;
  SI  : Integer;
Begin
  Lbl := M3_VAR_PFX + Name;
  If TIdx = TY_IDX_TEXT Then
  Begin
    (* Constante chaine : stocker dans DATA *)
    DataAdd(Lbl, DK_STR, 0, SVal);
    SI := SymAdd(Name, SK_CONST, TIdx, DataCount - 1);
    If SI >= 0 Then
    Begin
      SymTab[SI].MangledName := Lbl;
      SymTab[SI].IsReadonly  := True;
    End;
  End
  Else
  Begin
    (* Constante entiere : stocker comme DW *)
    DataAddWord(Lbl, IVal);
    SI := SymAdd(Name, SK_CONST, TIdx, DataCount - 1);
    If SI >= 0 Then
    Begin
      SymTab[SI].MangledName := Lbl;
      SymTab[SI].IsReadonly  := True;
      SymTab[SI].ImmVal      := IVal;
    End;
  End;
End;

(* ---- ParseDataDecls : scanner VAR/CONST au niveau MODULE ---- *)
(* Parcourt le TokenPool entre MODULE ... BEGIN pour identifier   *)
(* les blocs VAR (variables globales) et CONST (constantes).     *)
(* Pour chaque variable, cree une entree dans DataTab et SymTab.  *)
(* Pour chaque constante, evalue l expression et cree l entree.  *)

Procedure ParseDataDecls;
Var
  P       : Integer;
  InVar   : Boolean;   (* dans un bloc VAR *)
  InConst : Boolean;   (* dans un bloc CONST *)
  Name    : TString;
  TIdx    : Integer;
  IVal    : LongInt;
  SVal    : TString;
Begin
  P       := 0;
  InVar   := False;
  InConst := False;

  (* Chercher le mot-cle MODULE pour commencer *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'MODULE'))
  Do
    Inc(P);
  If P >= TokenCount Then Exit;
  Inc(P); (* passer MODULE *)

  (* Avancer au-dela du nom de module et du ';' *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';'))
  Do
    Inc(P);
  If P < TokenCount Then Inc(P); (* passer le ';' *)

  (* Scanner les declarations entre MODULE ...; et BEGIN *)
  While P < TokenCount Do
  Begin
    (* Si on atteint BEGIN, on arrete *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'BEGIN') Then
      Break;

    (* Si on atteint PROCEDURE, on arrete (declarations de proc) *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'PROCEDURE') Then
      Break;

    (* Detecter le mot-cle VAR *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'VAR') Then
    Begin
      InVar   := True;
      InConst := False;
      Inc(P);
      Continue;
    End;

    (* Detecter le mot-cle CONST *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'CONST') Then
    Begin
      InConst := True;
      InVar   := False;
      Inc(P);
      Continue;
    End;

    (* Detecter un autre mot-cle de section (TYPE, EXCEPTION, etc) *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       ((TokenPool[P].Val = 'TYPE') Or
        (TokenPool[P].Val = 'EXCEPTION') Or
        (TokenPool[P].Val = 'IMPORT') Or
        (TokenPool[P].Val = 'FROM') Or
        (TokenPool[P].Val = 'REVEAL')) Then
    Begin
      InVar   := False;
      InConst := False;
      (* Sauter jusqu a la fin de la section *)
      Inc(P);
      Continue;
    End;

    (* ---- Traiter une declaration VAR : ident [, ident]* : Type ; *)
    If InVar And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      (* Collecter le(s) nom(s) de variable(s) *)
      Repeat
        If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          Name := TokenPool[P].Val;
          Inc(P);
          (* Chercher le ':' pour le type *)
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ':') Then
          Begin
            Inc(P); (* passer ':' *)
            (* Lire le nom du type *)
            TIdx := TY_IDX_INTEGER; (* type par defaut *)
            If P < TokenCount Then
            Begin
              If (TokenPool[P].Kind = TK_KEYWORD) Or
                 (TokenPool[P].Kind = TK_IDENT) Then
              Begin
                TIdx := TypeIdxFromName(TokenPool[P].Val);
                If TIdx = TY_UNKNOWN Then
                  TIdx := TY_IDX_INTEGER; (* type utilisateur -> mot *)
                Inc(P);
              End;
            End;
            (* Creer la variable globale *)
            DataAddGlobalVar(Name, TIdx, 0);
            (* Passer le ';' *)
            If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ';') Then
              Inc(P);
          End
          Else If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
                  (TokenPool[P].Val = ',') Then
          Begin
            (* Plusieurs variables avant le ':' -> lire la suite *)
            (* On gere name, name, name : Type; *)
            (* Stocker ce premier nom et continuer la boucle *)
            Inc(P); (* passer ',' *)

            (* On va traiter les noms suivants dans la boucle *)
            (* mais il faut d abord trouver le ':' pour le type *)
            (* Strategie : collecter tous les noms d abord *)
            (* Reculer et traiter comme un groupe *)

            (* Approche simplifiee : creer avec type par defaut, *)
            (* le type sera resolu quand on atteint ':' *)
            DataAddGlobalVar(Name, TY_IDX_INTEGER, 0);
            Continue;
          End
          Else
            Inc(P);
        End
        Else
          Inc(P);
      Until (P >= TokenCount) Or
            ((TokenPool[P].Kind = TK_KEYWORD) And
             ((TokenPool[P].Val = 'VAR') Or
              (TokenPool[P].Val = 'CONST') Or
              (TokenPool[P].Val = 'TYPE') Or
              (TokenPool[P].Val = 'BEGIN') Or
              (TokenPool[P].Val = 'PROCEDURE'))) Or
            ((TokenPool[P].Kind = TK_IDENT) And
             (P + 1 < TokenCount) And
             ((TokenPool[P+1].Kind = TK_PUNCT) And
              ((TokenPool[P+1].Val = ':') Or (TokenPool[P+1].Val = ','))));
      Continue;
    End;

    (* ---- Traiter une declaration CONST : ident = expr ; *)
    If InConst And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[P].Val;
      Inc(P);

      (* Chercher le '=' *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
         (TokenPool[P].Val = '=') Then
      Begin
        Inc(P); (* passer '=' *)

        (* Evaluer l expression constante *)
        IVal := 0;
        SVal := '';
        TIdx := TY_IDX_INTEGER;

        If P < TokenCount Then
        Begin
          (* Constante chaine *)
          If TokenPool[P].Kind = TK_STRING Then
          Begin
            SVal := TokenPool[P].Val;
            TIdx := TY_IDX_TEXT;
            Inc(P);
          End
          (* Constante entiere *)
          Else If TokenPool[P].Kind = TK_INTEGER Then
          Begin
            IVal := TokenPool[P].IntVal;
            TIdx := TY_IDX_INTEGER;
            Inc(P);
          End
          (* Constante caractere *)
          Else If TokenPool[P].Kind = TK_CHAR Then
          Begin
            IVal := TokenPool[P].IntVal;
            TIdx := TY_IDX_CHAR;
            Inc(P);
          End
          (* Constante booleenne TRUE/FALSE *)
          Else If (TokenPool[P].Kind = TK_KEYWORD) And
                  (TokenPool[P].Val = 'TRUE') Then
          Begin
            IVal := 1;
            TIdx := TY_IDX_BOOLEAN;
            Inc(P);
          End
          Else If (TokenPool[P].Kind = TK_KEYWORD) And
                  (TokenPool[P].Val = 'FALSE') Then
          Begin
            IVal := 0;
            TIdx := TY_IDX_BOOLEAN;
            Inc(P);
          End
          (* Identifiant TRUE/FALSE (peuvent etre tokenises TK_IDENT) *)
          Else If (TokenPool[P].Kind = TK_IDENT) And
                  (TokenPool[P].Val = 'TRUE') Then
          Begin
            IVal := 1;
            TIdx := TY_IDX_BOOLEAN;
            Inc(P);
          End
          Else If (TokenPool[P].Kind = TK_IDENT) And
                  (TokenPool[P].Val = 'FALSE') Then
          Begin
            IVal := 0;
            TIdx := TY_IDX_BOOLEAN;
            Inc(P);
          End
          (* Constante entiere negative *)
          Else If (TokenPool[P].Kind = TK_OP) And
                  (TokenPool[P].Val = '-') And
                  (P + 1 < TokenCount) And
                  (TokenPool[P+1].Kind = TK_INTEGER) Then
          Begin
            IVal := -TokenPool[P+1].IntVal;
            TIdx := TY_IDX_INTEGER;
            Inc(P, 2);
          End
          Else
          Begin
            (* Expression constante non reconnue : avancer *)
            While (P < TokenCount) And Not
                  ((TokenPool[P].Kind = TK_PUNCT) And
                   (TokenPool[P].Val = ';'))
            Do
              Inc(P);
          End;
        End;

        (* Creer la constante *)
        DataAddGlobalConst(Name, TIdx, IVal, SVal);

        (* Passer le ';' *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else
        Inc(P); (* pas de '=' -> sauter *)

      Continue;
    End;

    (* Token non reconnu dans ce contexte : avancer *)
    Inc(P);
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
  TypeInit;
  SymInit;
  SymRegisterBuiltins;

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

  (* Phase 2b : scanner les declarations VAR/CONST au niveau MODULE *)
  ParseDataDecls;

  If Opts.Verbose Then
  Begin
    WriteLn('  Tokens         : ', TokenCount);
    WriteLn('  Donnees (DATA) : ', DataCount);
    WriteLn('  Types          : ', TypeCount);
    WriteLn('  Symboles       : ', SymCount);
  End;

  (* TODO 08+ : ParseCompilationUnit, EmitRuntime, etc. *)

  (* Phase 3 : emettre le fichier assembleur *)
  EmitOpen;
  EmitHeader;
  EmitClose;

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
