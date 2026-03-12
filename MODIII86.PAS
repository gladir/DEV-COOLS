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

   TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
             Variables globales : segment DATA, acces par label _M3V_nom
             Variables locales : pile BP, acces [BP-offset]
             Parametres VALUE : copie sur pile (comme variable locale)
             Parametres VAR : passage par adresse (pointeur sur pile)
             Parametres READONLY : passage par adresse, interdiction d ecriture
             Affectation := : ExprLoad + MOV destination, AX
             Affectation de RECORD : copie champ par champ ou REP MOVSW
             Affectation de ARRAY : copie element par element ou REP MOVSW

   TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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

   TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
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

   TODO 12 - ENTREES/SORTIES (MODULES Wr / Rd / Stdio) [IMPLEMENTE]
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

   TODO 13 - IF / ELSIF / ELSE / CASE [IMPLEMENTE]
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

   TODO 14 - BOUCLES : WHILE / REPEAT / FOR / LOOP / EXIT [IMPLEMENTE]
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

   TODO 15 - TABLEAUX (ARRAY) [IMPLEMENTE]
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

   TODO 16 - ENREGISTREMENTS (RECORD) ET WITH [IMPLEMENTE]
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

   TODO 17 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
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

   TODO 18 - INTERFACES ET MODULES (INTERFACE / MODULE) [IMPLEMENTE]
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

   TODO 19 - TYPES OBJETS ET METHODES (OBJECT) [IMPLEMENTE]
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

   TODO 20 - TYPES OPAQUES ET REVEAL [IMPLEMENTE]
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
  MAX_PROC      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LOCAL     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  STACK_SIZE    = 1024;
  MAX_TOKEN     = {$IFDEF FPC}16384{$ELSE}2048{$ENDIF};
  MAX_OBJ_TYPE  = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_METHOD    = 16;
  MAX_OPAQUE    = {$IFDEF FPC}32{$ELSE}8{$ENDIF};

  (* Prefixe statique (TODO 09) *)
  M3_STA_PFX  = '_M3S_';     (* variable statique locale             *)

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

  (* ---- Variable locale de procedure (TODO 09) ----------------- *)
  TLocalVar = Record
    Name    : TString;       (* nom de la variable                  *)
    TypeIdx : Integer;       (* index dans TypeTab                  *)
    Offset  : Integer;       (* offset BP (negatif : [BP-n])        *)
    Size    : Integer;       (* taille en octets                    *)
  End;

  (* ---- Mode de passage de parametre Modula-3 (TODO 09) -------- *)
  TParamMode = (
    PM_VALUE,                (* VALUE : copie par valeur            *)
    PM_VAR,                  (* VAR : passage par adresse           *)
    PM_READONLY              (* READONLY : adresse, lecture seule   *)
  );

  (* ---- Information sur une procedure (TODO 09) ----------------- *)
  TProcInfo = Record
    Name       : TString;    (* nom Modula-3 original               *)
    MangledName: TString;    (* label ASM (_M3P_nom)                *)
    RetTypeIdx : Integer;    (* type retour (-1 = procedure void)   *)
    IsFunction : Boolean;    (* True si retourne une valeur         *)
    ParamCount : Integer;
    ParamNames : Array[0..MAX_PARAM - 1] Of TString;
    ParamTypes : Array[0..MAX_PARAM - 1] Of Integer;
    ParamOfs   : Array[0..MAX_PARAM - 1] Of Integer;
    ParamModes : Array[0..MAX_PARAM - 1] Of TParamMode;
    LocalCount : Integer;
    Locals     : Array[0..MAX_LOCAL - 1] Of TLocalVar;
    LocalSize  : Integer;    (* taille totale cadre local (bytes)   *)
    BodyStart  : Integer;    (* index premier token du corps        *)
    BodyEnd    : Integer;    (* index dernier token du corps        *)
    SymIdx     : Integer;    (* index dans SymTab                   *)
    NestLevel  : Integer;    (* 0=module-level, 1=nested, etc TODO 17 *)
    ParentIdx  : Integer;    (* index du parent (-1=aucun) TODO 17  *)
  End;

  (* ---- Imports et Modules (TODO 18) ----------------------------- *)
  TImportEntry = Record
    ModName    : TString;     (* nom du module importe                  *)
    IsFrom     : Boolean;     (* True si FROM Mod IMPORT sym            *)
    SymNames   : Array[0..MAX_PARAM - 1] Of TString;
    SymCount   : Integer;     (* nombre de symboles (FROM ... IMPORT)   *)
  End;

  (* ---- Types objets et methodes (TODO 19) ---------------------- *)
  TMethodEntry = Record
    Name       : TString;    (* nom Modula-3 de la methode            *)
    MangledName: TString;    (* label ASM (_M3P_Type_Method)          *)
    ParamCount : Integer;    (* nombre de parametres (sans self)      *)
    RetTypeIdx : Integer;    (* type de retour (-1 = void)            *)
    VTSlot     : Integer;    (* index dans la vtable (0-based)        *)
  End;

  TObjTypeInfo = Record
    Name       : TString;    (* nom du type objet                     *)
    TypeIdx    : Integer;    (* index dans TypeTab                    *)
    ParentObjIdx: Integer;   (* index dans ObjTypeTab (-1 = ROOT)     *)
    FieldCount : Integer;    (* nombre de champs                      *)
    Fields     : Array[0..MAX_FIELD - 1] Of TFieldRec;
    FieldSize  : Integer;    (* taille totale des champs en octets    *)
    MethodCount: Integer;    (* nombre de methodes (y compris heritees)*)
    Methods    : Array[0..MAX_METHOD - 1] Of TMethodEntry;
    VtableLabel: TString;    (* label de la vtable dans DATA          *)
    TypeCode   : Integer;    (* code unique pour ISTYPE               *)
    TotalSize  : Integer;    (* taille = 2 (vtable ptr) + champs      *)
  End;

  (* ---- Types opaques et REVEAL (TODO 20) ---------------------- *)
  TOpaqueEntry = Record
    Name       : TString;     (* nom du type opaque                    *)
    SuperTIdx  : Integer;     (* index TypeTab du supertype declare     *)
    OpaqueIdx  : Integer;     (* index TypeTab de l entree opaque       *)
    RevealTIdx : Integer;     (* index TypeTab du type revele (-1=non)  *)
    IsBranded  : Boolean;     (* BRANDED utilise dans le REVEAL         *)
    BrandTag   : TString;     (* etiquette BRANDED ('' = auto)          *)
    IsRevealed : Boolean;     (* True quand REVEAL a ete traite         *)
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

  (* Imports et Modules (TODO 18) *)
  ImportTab    : Array[0..MAX_IMPORT - 1] Of TImportEntry;
  ImportCount  : Integer;
  ModuleName   : TString;   (* nom du MODULE ou INTERFACE courant *)
  ExportsName  : TString;   (* nom de l interface exportee (EXPORTS) *)

  (* Types objets (TODO 19) *)
  ObjTypeTab   : Array[0..MAX_OBJ_TYPE - 1] Of TObjTypeInfo;
  ObjTypeCount : Integer;

  (* Types opaques (TODO 20) *)
  OpaqueTab    : Array[0..MAX_OPAQUE - 1] Of TOpaqueEntry;
  OpaqueCount  : Integer;

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

  (* Table des procedures (TODO 09) *)
  ProcTab    : Array[0..MAX_PROC-1] Of TProcInfo;
  ProcCount  : Integer;

  (* Curseur d expression (TODO 10) *)
  EP          : Integer;  (* position courante dans TokenPool *)
  EPEnd       : Integer;  (* borne fin du corps courant *)
  CurProcIdx  : Integer;  (* index dans ProcTab de la proc courante *)
  RetLbl      : TString;  (* label de retour de la proc courante *)

  (* Pile de boucles LOOP/EXIT (TODO 14) *)
  LoopExitStack : Array[0..MAX_LOOP_NEST-1] Of TString;
  LoopExitTop   : Integer;  (* sommet de la pile, 0 = vide *)

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
          Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
          Begin
            S := '<:';
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
  LoopExitTop := 0;
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

  (* Type objet racine ROOT (TODO 19) *)
  If TypeCount < MAX_TYPE Then
  Begin
    TypeTab[TypeCount].Kind        := TYK_OBJECT;
    TypeTab[TypeCount].Name        := 'ROOT';
    TypeTab[TypeCount].Size        := 2;
    TypeTab[TypeCount].BaseTypeIdx := TypeCount;
    TypeTab[TypeCount].Lo          := 0;
    TypeTab[TypeCount].Hi          := 0;
    TypeTab[TypeCount].FieldCount  := 0;
    TypeTab[TypeCount].EnumCount   := 0;
    SymAdd('ROOT', SK_TYPE, TypeCount, 0);
    If ObjTypeCount < MAX_OBJ_TYPE Then
    Begin
      ObjTypeTab[ObjTypeCount].Name        := 'ROOT';
      ObjTypeTab[ObjTypeCount].TypeIdx     := TypeCount;
      ObjTypeTab[ObjTypeCount].ParentObjIdx:= -1;
      ObjTypeTab[ObjTypeCount].FieldCount  := 0;
      ObjTypeTab[ObjTypeCount].FieldSize   := 0;
      ObjTypeTab[ObjTypeCount].MethodCount := 0;
      ObjTypeTab[ObjTypeCount].VtableLabel := M3_TYPE_PFX + 'ROOT_VT';
      ObjTypeTab[ObjTypeCount].TypeCode    := 0;
      ObjTypeTab[ObjTypeCount].TotalSize   := 2;
      Inc(ObjTypeCount);
    End;
    Inc(TypeCount);
  End;

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
Var
  I, J : Integer;
Begin
  EmitComment('=========================================================');
  EmitComment('Genere par MODIII86 v' + MODIII86_VERSION +
              ' (' + MODIII86_DATE + ')');
  EmitComment('Source  : ' + Opts.SrcFile);
  If ModuleName <> '' Then
  Begin
    If Opts.IsIface Then
      EmitComment('Interface : ' + ModuleName)
    Else
      EmitComment('Module  : ' + ModuleName);
  End;
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;

  (* --- EXTRN : symboles importes depuis d autres modules (TODO 18) --- *)
  If ImportCount > 0 Then
  Begin
    EmitComment('--- Symboles externes (IMPORT) ---');
    For I := 0 To ImportCount - 1 Do
    Begin
      If ImportTab[I].IsFrom Then
      Begin
        (* FROM Mod IMPORT sym1, sym2 : declarer chaque symbole *)
        For J := 0 To ImportTab[I].SymCount - 1 Do
          EmitRaw('        EXTRN ' + M3_VAR_PFX +
                  ImportTab[I].ModName + '_' +
                  ImportTab[I].SymNames[J] + ':NEAR');
      End
      Else
      Begin
        (* IMPORT Mod : declarer le module comme externe *)
        EmitRaw('        EXTRN ' + M3_PROC_PFX +
                ImportTab[I].ModName + '_INIT:NEAR');
      End;
    End;
    EmitBlankLine;
  End;

  (* --- PUBLIC : symboles exportes par ce module (TODO 18) --- *)
  If (Not Opts.IsIface) And (ExportsName <> '') Then
  Begin
    EmitComment('--- Symboles publics (EXPORTS ' + ExportsName + ') ---');
    For I := 0 To ProcCount - 1 Do
      EmitRaw('        PUBLIC ' + ProcTab[I].MangledName);
    EmitBlankLine;
  End;

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

  (* Vtables des types objets (TODO 19) *)
  If ObjTypeCount > 0 Then
  Begin
    EmitBlankLine;
    EmitComment('--- Vtables des types objets ---');
    For I := 0 To ObjTypeCount - 1 Do
    Begin
      S := ObjTypeTab[I].VtableLabel + '  DW  ';
      S := S + IntToStr(ObjTypeTab[I].TypeCode);
      For J := 0 To ObjTypeTab[I].MethodCount - 1 Do
        S := S + ',OFFSET ' + ObjTypeTab[I].Methods[J].MangledName;
      EmitRaw(S);
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
  If Not Opts.IsIface Then
  Begin
    (* Mode MODULE : sortie DOS normale *)
    EmitBlankLine;
    EmitComment('--- Sortie programme (DOS INT 21h) ---');
    EmitInstrAB('MOV', 'AH', '4Ch');
    EmitInstrAB('MOV', 'AL', '0');
    EmitInstr('INT    21h');
  End
  Else
  Begin
    (* Mode INTERFACE : pas de code executable, seulement RET *)
    EmitBlankLine;
    EmitComment('--- INTERFACE : pas de point d''entree ---');
    EmitInstr('RET');
  End;
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
Var Idx : Integer;
Begin
  If V = 'INTEGER'  Then TypeIdxFromName := TY_IDX_INTEGER
  Else If V = 'CARDINAL' Then TypeIdxFromName := TY_IDX_CARDINAL
  Else If V = 'BOOLEAN'  Then TypeIdxFromName := TY_IDX_BOOLEAN
  Else If V = 'CHAR'     Then TypeIdxFromName := TY_IDX_CHAR
  Else If V = 'REAL'     Then TypeIdxFromName := TY_IDX_REAL
  Else If V = 'LONGREAL' Then TypeIdxFromName := TY_IDX_LONGREAL
  Else If V = 'TEXT'     Then TypeIdxFromName := TY_IDX_TEXT
  Else If V = 'REFANY'   Then TypeIdxFromName := TY_IDX_NIL
  Else
  Begin
    (* Chercher dans TypeTab les types definis par l utilisateur *)
    Idx := TypeFindByName(V);
    TypeIdxFromName := Idx;
  End;
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
    If (TIdx >= 0) And (TIdx < TypeCount) Then
      TypeSizeFromIdx := TypeTab[TIdx].Size
    Else
      TypeSizeFromIdx := 2;  (* defaut : mot 16 bits *)
  End;
End;

(* ---- ParseArrayTypeFromTokens : parser un type ARRAY -------- *)
(* Lit ARRAY [lo..hi] OF T ou ARRAY OF T a partir de la position *)
(* P dans le TokenPool et cree l entree TypeTab correspondante.  *)
(* Retourne l index du type ou TY_UNKNOWN.                       *)

Function ParseArrayTypeFromTokens(Var P : Integer) : Integer;
Var
  Lo, Hi   : LongInt;
  ElemTIdx : Integer;
  ElemSz   : Integer;
  ArrSize  : Integer;
  TIdx     : Integer;
Begin
  ParseArrayTypeFromTokens := TY_UNKNOWN;
  If (P >= TokenCount) Then Exit;
  If Not ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'ARRAY')) Then
    Exit;
  Inc(P); (* passer ARRAY *)

  (* --- Tableau fixe : ARRAY [lo..hi] OF T --- *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '[') Then
  Begin
    Inc(P); (* passer '[' *)
    Lo := 0;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      Lo := TokenPool[P].IntVal;
      Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
       (TokenPool[P].Val = '..') Then
      Inc(P);
    Hi := 0;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      Hi := TokenPool[P].IntVal;
      Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ']') Then
      Inc(P);
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'OF') Then
      Inc(P);
    ElemTIdx := TY_IDX_INTEGER;
    If (P < TokenCount) And
       ((TokenPool[P].Kind = TK_KEYWORD) Or
        (TokenPool[P].Kind = TK_IDENT)) Then
    Begin
      ElemTIdx := TypeIdxFromName(TokenPool[P].Val);
      If ElemTIdx = TY_UNKNOWN Then
        ElemTIdx := TY_IDX_INTEGER;
      Inc(P);
    End;
    ElemSz  := TypeSizeFromIdx(ElemTIdx);
    ArrSize := (Hi - Lo + 1) * ElemSz;
    TIdx := TypeAdd(TYK_ARRAY, '', ArrSize);
    If TIdx >= 0 Then
    Begin
      TypeTab[TIdx].BaseTypeIdx := ElemTIdx;
      TypeTab[TIdx].Lo          := Lo;
      TypeTab[TIdx].Hi          := Hi;
    End;
    ParseArrayTypeFromTokens := TIdx;
  End
  Else
  Begin
    (* --- Tableau ouvert : ARRAY OF T --- *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'OF') Then
      Inc(P);
    ElemTIdx := TY_IDX_INTEGER;
    If (P < TokenCount) And
       ((TokenPool[P].Kind = TK_KEYWORD) Or
        (TokenPool[P].Kind = TK_IDENT)) Then
    Begin
      ElemTIdx := TypeIdxFromName(TokenPool[P].Val);
      If ElemTIdx = TY_UNKNOWN Then
        ElemTIdx := TY_IDX_INTEGER;
      Inc(P);
    End;
    TIdx := TypeAdd(TYK_OPENARRAY, '', 4);
    If TIdx >= 0 Then
    Begin
      TypeTab[TIdx].BaseTypeIdx := ElemTIdx;
      TypeTab[TIdx].Lo          := 0;
      TypeTab[TIdx].Hi          := 0;
    End;
    ParseArrayTypeFromTokens := TIdx;
  End;
End;

(* ============================================================
   TODO 16 - ENREGISTREMENTS (RECORD) ET WITH [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseRecordTypeFromTokens : parser un type RECORD ------ *)
(* Lit RECORD champ1: T1; champ2: T2; ... END a partir de la     *)
(* position P dans le TokenPool et cree l entree TypeTab.         *)
(* Retourne l index du type ou TY_UNKNOWN.                        *)

Function ParseRecordTypeFromTokens(Var P : Integer;
                                   Const TName : TString) : Integer;
Var
  TIdx, FTIdx : Integer;
  FCount      : Integer;
  FOffset     : Integer;
  FName       : TString;
  FSz         : Integer;
Begin
  ParseRecordTypeFromTokens := TY_UNKNOWN;
  If (P >= TokenCount) Or Not
     ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'RECORD'))
  Then Exit;
  Inc(P); (* passer RECORD *)

  TIdx := TypeAdd(TYK_RECORD, TName, 0);
  If TIdx < 0 Then Exit;

  FCount  := 0;
  FOffset := 0;

  (* Parser les champs : ident : Type ; *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'END'))
  Do
  Begin
    If TokenPool[P].Kind = TK_IDENT Then
    Begin
      FName := TokenPool[P].Val;
      Inc(P);
      (* Attendre ':' *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ':') Then
      Begin
        Inc(P); (* passer ':' *)
        FTIdx := TY_IDX_INTEGER;
        If P < TokenCount Then
        Begin
          If (TokenPool[P].Kind = TK_KEYWORD) Or
             (TokenPool[P].Kind = TK_IDENT) Then
          Begin
            FTIdx := TypeIdxFromName(TokenPool[P].Val);
            If FTIdx = TY_UNKNOWN Then
              FTIdx := TY_IDX_INTEGER;
            Inc(P);
          End;
        End;
        FSz := TypeSizeFromIdx(FTIdx);
        (* Aligner sur mot si necessaire *)
        If (FSz > 1) And ((FOffset Mod 2) = 1) Then
          Inc(FOffset);
        If FCount < MAX_FIELD Then
        Begin
          TypeTab[TIdx].Fields[FCount].Name    := FName;
          TypeTab[TIdx].Fields[FCount].TypeIdx := FTIdx;
          TypeTab[TIdx].Fields[FCount].Offset  := FOffset;
          Inc(FCount);
        End;
        Inc(FOffset, FSz);
      End;
      (* Passer ';' entre champs *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End
    Else
      Inc(P); (* token inattendu, avancer *)
  End;

  (* Passer END *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'END') Then
    Inc(P);

  (* Aligner la taille totale sur mot *)
  If (FOffset Mod 2) = 1 Then Inc(FOffset);
  TypeTab[TIdx].FieldCount := FCount;
  TypeTab[TIdx].Size       := FOffset;

  If Opts.DebugMode Then
    WriteLn('  RECORD TYPE[', TIdx, ']: ', TName,
            ' fields=', FCount, ' size=', FOffset);

  ParseRecordTypeFromTokens := TIdx;
End;

(* ---- RecordFieldFind : trouver un champ dans un type RECORD - *)
(* Retourne l index du champ (0..FieldCount-1) ou -1.            *)

Function RecordFieldFind(TIdx : Integer;
                         Const FName : TString) : Integer;
Var I : Integer;
Begin
  RecordFieldFind := -1;
  If (TIdx < 0) Or (TIdx >= TypeCount) Then Exit;
  If TypeTab[TIdx].Kind <> TYK_RECORD Then Exit;
  For I := 0 To TypeTab[TIdx].FieldCount - 1 Do
    If TypeTab[TIdx].Fields[I].Name = FName Then
    Begin
      RecordFieldFind := I;
      Exit;
    End;
End;

(* ============================================================
   TODO 19 - TYPES OBJETS ET METHODES (OBJECT) [IMPLEMENTE]
   ============================================================ *)

(* ---- ObjTypeFind : trouver un type objet par nom -------------- *)
(* Retourne l index dans ObjTypeTab ou -1 si non trouve.            *)

Function ObjTypeFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To ObjTypeCount - 1 Do
    If ObjTypeTab[I].Name = Name Then
    Begin
      ObjTypeFind := I;
      Exit;
    End;
  ObjTypeFind := -1;
End;

(* ---- ObjTypeFindByTypeIdx : trouver objet par TypeTab index --- *)

Function ObjTypeFindByTypeIdx(TIdx : Integer) : Integer;
Var I : Integer;
Begin
  For I := 0 To ObjTypeCount - 1 Do
    If ObjTypeTab[I].TypeIdx = TIdx Then
    Begin
      ObjTypeFindByTypeIdx := I;
      Exit;
    End;
  ObjTypeFindByTypeIdx := -1;
End;

(* ---- ObjTypeFieldFind : trouver un champ dans un type objet --- *)
(* Retourne l index du champ (0..FieldCount-1) ou -1.              *)

Function ObjTypeFieldFind(ObjIdx : Integer;
                          Const FldName : TString) : Integer;
Var I : Integer;
Begin
  ObjTypeFieldFind := -1;
  If (ObjIdx < 0) Or (ObjIdx >= ObjTypeCount) Then Exit;
  For I := 0 To ObjTypeTab[ObjIdx].FieldCount - 1 Do
    If ObjTypeTab[ObjIdx].Fields[I].Name = FldName Then
    Begin
      ObjTypeFieldFind := I;
      Exit;
    End;
End;

(* ---- ObjTypeMethodFind : trouver une methode dans un type objet *)
(* Retourne l index de la methode (0..MethodCount-1) ou -1.        *)

Function ObjTypeMethodFind(ObjIdx : Integer;
                           Const MethName : TString) : Integer;
Var I : Integer;
Begin
  ObjTypeMethodFind := -1;
  If (ObjIdx < 0) Or (ObjIdx >= ObjTypeCount) Then Exit;
  For I := 0 To ObjTypeTab[ObjIdx].MethodCount - 1 Do
    If ObjTypeTab[ObjIdx].Methods[I].Name = MethName Then
    Begin
      ObjTypeMethodFind := I;
      Exit;
    End;
End;

(* ---- ParseObjectTypeFromTokens : parser OBJECT...END ---------- *)
(* Lit [ParentType] OBJECT champs; METHODS ...; OVERRIDES ...; END *)
(* a partir de la position P dans le TokenPool. Cree l entree       *)
(* dans ObjTypeTab et TypeTab. Retourne l index TypeTab.            *)

Function ParseObjectTypeFromTokens(Var P : Integer;
                                   Const TName : TString) : Integer;
Var
  TIdx, FTIdx   : Integer;
  OIdx, POIdx   : Integer;
  FCount        : Integer;
  FOffset       : Integer;
  MCount        : Integer;
  FName, MName  : TString;
  FSz           : Integer;
  ParentName    : TString;
  InMethods     : Boolean;
  InOverrides   : Boolean;
  MI            : Integer;
Begin
  ParseObjectTypeFromTokens := TY_UNKNOWN;
  ParentName := '';

  (* Verifier si un parent est nomme avant OBJECT *)
  If (P < TokenCount) And
     ((TokenPool[P].Kind = TK_IDENT) Or
      ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'ROOT')))
  Then
  Begin
    ParentName := TokenPool[P].Val;
    Inc(P);
  End;

  (* Sauter BRANDED ["tag"] si present (TODO 20) *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'BRANDED') Then
  Begin
    Inc(P);
    If (P < TokenCount) And (TokenPool[P].Kind = TK_STRING) Then
      Inc(P);
  End;

  (* On doit maintenant etre sur OBJECT *)
  If (P >= TokenCount) Or Not
     ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'OBJECT'))
  Then Exit;
  Inc(P); (* passer OBJECT *)

  If ObjTypeCount >= MAX_OBJ_TYPE Then
  Begin
    ParseObjectTypeFromTokens := TY_UNKNOWN;
    Exit;
  End;

  (* Creer l entree TypeTab *)
  TIdx := TypeAdd(TYK_OBJECT, TName, 2);
  If TIdx < 0 Then Exit;

  OIdx := ObjTypeCount;
  Inc(ObjTypeCount);
  ObjTypeTab[OIdx].Name       := TName;
  ObjTypeTab[OIdx].TypeIdx    := TIdx;
  ObjTypeTab[OIdx].TypeCode   := OIdx + 1;
  ObjTypeTab[OIdx].VtableLabel:= M3_TYPE_PFX + TName + '_VT';
  ObjTypeTab[OIdx].FieldCount := 0;
  ObjTypeTab[OIdx].FieldSize  := 0;
  ObjTypeTab[OIdx].MethodCount:= 0;

  (* Heritage du parent *)
  POIdx := -1;
  If ParentName <> '' Then
  Begin
    POIdx := ObjTypeFind(ParentName);
    If POIdx >= 0 Then
    Begin
      (* Copier champs du parent *)
      For FCount := 0 To ObjTypeTab[POIdx].FieldCount - 1 Do
        ObjTypeTab[OIdx].Fields[FCount] := ObjTypeTab[POIdx].Fields[FCount];
      ObjTypeTab[OIdx].FieldCount := ObjTypeTab[POIdx].FieldCount;
      ObjTypeTab[OIdx].FieldSize  := ObjTypeTab[POIdx].FieldSize;
      (* Copier methodes du parent (vtable heritee) *)
      For MCount := 0 To ObjTypeTab[POIdx].MethodCount - 1 Do
        ObjTypeTab[OIdx].Methods[MCount] := ObjTypeTab[POIdx].Methods[MCount];
      ObjTypeTab[OIdx].MethodCount := ObjTypeTab[POIdx].MethodCount;
    End;
  End;
  ObjTypeTab[OIdx].ParentObjIdx := POIdx;

  FCount  := ObjTypeTab[OIdx].FieldCount;
  FOffset := ObjTypeTab[OIdx].FieldSize;
  MCount  := ObjTypeTab[OIdx].MethodCount;
  InMethods   := False;
  InOverrides := False;

  (* Parser champs, METHODS, OVERRIDES jusqu a END *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'END'))
  Do
  Begin
    (* Detecter section METHODS *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'METHODS') Then
    Begin
      InMethods   := True;
      InOverrides := False;
      Inc(P);
      Continue;
    End;
    (* Detecter section OVERRIDES *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'OVERRIDES') Then
    Begin
      InMethods   := False;
      InOverrides := True;
      Inc(P);
      Continue;
    End;

    If TokenPool[P].Kind = TK_IDENT Then
    Begin
      If InOverrides Then
      Begin
        (* OVERRIDES : methode := NouvelleProc ; *)
        MName := TokenPool[P].Val;
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
           (TokenPool[P].Val = ':=') Then
        Begin
          Inc(P); (* passer ':=' *)
          If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
          Begin
            MI := ObjTypeMethodFind(OIdx, MName);
            If MI >= 0 Then
              ObjTypeTab[OIdx].Methods[MI].MangledName :=
                M3_PROC_PFX + TokenPool[P].Val;
            Inc(P);
          End;
        End;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else If InMethods Then
      Begin
        (* METHODS : methode(params): RetType ; *)
        MName := TokenPool[P].Val;
        Inc(P);
        (* Sauter la liste de parametres *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = '(') Then
        Begin
          Inc(P);
          While (P < TokenCount) And Not
                ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ')')) Do
            Inc(P);
          If P < TokenCount Then Inc(P); (* passer ')' *)
        End;
        (* Sauter le type de retour optionnel *)
        FTIdx := -1;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P);
          If (P < TokenCount) Then
          Begin
            FTIdx := TypeIdxFromName(TokenPool[P].Val);
            Inc(P);
          End;
        End;
        If MCount < MAX_METHOD Then
        Begin
          ObjTypeTab[OIdx].Methods[MCount].Name       := MName;
          ObjTypeTab[OIdx].Methods[MCount].MangledName :=
            M3_PROC_PFX + TName + '_' + MName;
          ObjTypeTab[OIdx].Methods[MCount].ParamCount  := 0;
          ObjTypeTab[OIdx].Methods[MCount].RetTypeIdx  := FTIdx;
          ObjTypeTab[OIdx].Methods[MCount].VTSlot      := MCount;
          Inc(MCount);
        End;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else
      Begin
        (* Champ : ident : Type ; *)
        FName := TokenPool[P].Val;
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P);
          FTIdx := TY_IDX_INTEGER;
          If P < TokenCount Then
          Begin
            If (TokenPool[P].Kind = TK_KEYWORD) Or
               (TokenPool[P].Kind = TK_IDENT) Then
            Begin
              FTIdx := TypeIdxFromName(TokenPool[P].Val);
              If FTIdx = TY_UNKNOWN Then
                FTIdx := TY_IDX_INTEGER;
              Inc(P);
            End;
          End;
          FSz := TypeSizeFromIdx(FTIdx);
          If (FSz > 1) And ((FOffset Mod 2) = 1) Then
            Inc(FOffset);
          If FCount < MAX_FIELD Then
          Begin
            ObjTypeTab[OIdx].Fields[FCount].Name    := FName;
            ObjTypeTab[OIdx].Fields[FCount].TypeIdx := FTIdx;
            ObjTypeTab[OIdx].Fields[FCount].Offset  := FOffset;
            Inc(FCount);
          End;
          Inc(FOffset, FSz);
        End;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End;
    End
    Else
      Inc(P); (* token inattendu, avancer *)
  End;

  (* Passer END *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'END') Then
    Inc(P);

  If (FOffset Mod 2) = 1 Then Inc(FOffset);
  ObjTypeTab[OIdx].FieldCount  := FCount;
  ObjTypeTab[OIdx].FieldSize   := FOffset;
  ObjTypeTab[OIdx].MethodCount := MCount;
  (* TotalSize = 2 (vtable ptr) + taille des champs *)
  ObjTypeTab[OIdx].TotalSize   := 2 + FOffset;
  TypeTab[TIdx].Size           := 2; (* variable = pointeur vers objet *)
  TypeTab[TIdx].BaseTypeIdx    := TIdx;

  (* Enregistrer le symbole TYPE *)
  SymAdd(TName, SK_TYPE, TIdx, 0);

  If Opts.DebugMode Then
    WriteLn('  OBJECT TYPE[', OIdx, ']: ', TName,
            ' fields=', FCount, ' methods=', MCount,
            ' totalSize=', ObjTypeTab[OIdx].TotalSize);

  ParseObjectTypeFromTokens := TIdx;
End;

(* ---- DataAddGlobalRecordVar : creer une variable record DATA  *)
(* Cree une entree DK_REC dans DataTab et enregistre le symbole   *)
(* dans SymTab.                                                    *)

Procedure DataAddGlobalRecordVar(Const Name : TString; TIdx : Integer);
Var
  Lbl : TString;
  SI  : Integer;
Begin
  Lbl := M3_VAR_PFX + Name;
  DataAddRec(Lbl, TypeTab[TIdx].Size);
  SI := SymAdd(Name, SK_VAR, TIdx, DataCount - 1);
  If SI >= 0 Then
    SymTab[SI].MangledName := Lbl;
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

(* ---- DataAddGlobalArrayVar : creer une variable tableau DATA -- *)
(* Cree une entree DK_ARRAY dans DataTab et enregistre le symbole  *)
(* dans SymTab.                                                    *)

Procedure DataAddGlobalArrayVar(Const Name : TString; TIdx : Integer);
Var
  Lbl       : TString;
  SI        : Integer;
  ElemCount : Integer;
  ElemSz    : Integer;
Begin
  Lbl := M3_VAR_PFX + Name;
  ElemCount := TypeTab[TIdx].Hi - TypeTab[TIdx].Lo + 1;
  ElemSz    := TypeSizeFromIdx(TypeTab[TIdx].BaseTypeIdx);
  DataAddArray(Lbl, ElemCount, ElemSz);
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
  InType  : Boolean;   (* dans un bloc TYPE - TODO 16 *)
  Name    : TString;
  TIdx    : Integer;
  IVal    : LongInt;
  SVal    : TString;
  (* TODO 20 - REVEAL / types opaques *)
  SaveP       : Integer;
  ScanP       : Integer;
  HasObject   : Boolean;
  IsBranded   : Boolean;
  BrandTag    : TString;
  RevTypeName : TString;
  RevTIdx     : Integer;
  OIdx        : Integer;
  SuperName   : TString;
  I           : Integer;
Begin
  P       := 0;
  InVar   := False;
  InConst := False;
  InType  := False;
  ImportCount := 0;
  ModuleName  := '';
  ExportsName := '';

  (* Chercher le mot-cle MODULE ou INTERFACE pour commencer - TODO 18 *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_KEYWORD) And
         ((TokenPool[P].Val = 'MODULE') Or
          (TokenPool[P].Val = 'INTERFACE')))
  Do
    Inc(P);
  If P >= TokenCount Then Exit;

  (* Detecter INTERFACE vs MODULE - TODO 18 *)
  If TokenPool[P].Val = 'INTERFACE' Then
    Opts.IsIface := True;
  Inc(P); (* passer MODULE/INTERFACE *)

  (* Lire le nom du module/interface *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
  Begin
    ModuleName := TokenPool[P].Val;
    Inc(P);
  End;

  (* Detecter EXPORTS InterfaceName - TODO 18 *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'EXPORTS') Then
  Begin
    Inc(P); (* passer EXPORTS *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      ExportsName := TokenPool[P].Val;
      Inc(P);
    End;
  End;

  (* Avancer au-dela du ';' *)
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';'))
  Do
    Inc(P);
  If P < TokenCount Then Inc(P); (* passer le ';' *)

  If Opts.DebugMode Then
  Begin
    If Opts.IsIface Then
      WriteLn('  INTERFACE ', ModuleName)
    Else
      WriteLn('  MODULE ', ModuleName);
    If ExportsName <> '' Then
      WriteLn('  EXPORTS ', ExportsName);
  End;

  (* Enregistrer le module/interface dans SymTab *)
  If (ModuleName <> '') And (SymFind(ModuleName) < 0) Then
  Begin
    SymAdd(ModuleName, SK_MODULE, TY_UNKNOWN, 0);
    If Opts.IsIface Then
      SymTab[SymCount - 1].IsExported := True;
  End;

  (* Scanner les declarations entre MODULE/INTERFACE ...; et BEGIN/END *)
  While P < TokenCount Do
  Begin
    (* Si on atteint BEGIN, on arrete *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'BEGIN') Then
      Break;

    (* Si on atteint END (pour INTERFACE sans BEGIN) - TODO 18 *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'END') Then
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
      InType  := False;
      Inc(P);
      Continue;
    End;

    (* Detecter le mot-cle CONST *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'CONST') Then
    Begin
      InConst := True;
      InVar   := False;
      InType  := False;
      Inc(P);
      Continue;
    End;

    (* Detecter le mot-cle TYPE - TODO 16 *)
    If (TokenPool[P].Kind = TK_KEYWORD) And (TokenPool[P].Val = 'TYPE') Then
    Begin
      InType  := True;
      InVar   := False;
      InConst := False;
      Inc(P);
      Continue;
    End;

    (* Detecter un autre mot-cle de section (EXCEPTION, etc) *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'EXCEPTION') Then
    Begin
      InVar   := False;
      InConst := False;
      InType  := False;
      Inc(P);
      Continue;
    End;

    (* Detecter IMPORT Mod1, Mod2; -- TODO 18 *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'IMPORT') Then
    Begin
      InVar   := False;
      InConst := False;
      InType  := False;
      Inc(P); (* passer IMPORT *)
      While (P < TokenCount) And Not
            ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';'))
      Do
      Begin
        If (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          Name := TokenPool[P].Val;
          (* Enregistrer le module dans la table d imports *)
          If ImportCount < MAX_IMPORT Then
          Begin
            ImportTab[ImportCount].ModName  := Name;
            ImportTab[ImportCount].IsFrom   := False;
            ImportTab[ImportCount].SymCount := 0;
            Inc(ImportCount);
          End;
          (* Enregistrer comme symbole SK_MODULE si pas deja connu *)
          If SymFind(Name) < 0 Then
          Begin
            SymAdd(Name, SK_MODULE, TY_UNKNOWN, 0);
            SymTab[SymCount - 1].IsImported := True;
          End;
        End;
        Inc(P);
      End;
      If (P < TokenCount) Then Inc(P); (* passer ';' *)
      Continue;
    End;

    (* Detecter FROM Mod IMPORT sym1, sym2; -- TODO 18 *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'FROM') Then
    Begin
      InVar   := False;
      InConst := False;
      InType  := False;
      Inc(P); (* passer FROM *)
      Name := '';
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[P].Val;
        Inc(P);
      End;
      (* Passer le mot-cle IMPORT *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
         (TokenPool[P].Val = 'IMPORT') Then
        Inc(P);
      (* Enregistrer l entree d import *)
      If (Name <> '') And (ImportCount < MAX_IMPORT) Then
      Begin
        ImportTab[ImportCount].ModName  := Name;
        ImportTab[ImportCount].IsFrom   := True;
        ImportTab[ImportCount].SymCount := 0;
        (* Lire les symboles importes *)
        While (P < TokenCount) And Not
              ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';'))
        Do
        Begin
          If (TokenPool[P].Kind = TK_IDENT) And
             (ImportTab[ImportCount].SymCount < MAX_PARAM) Then
          Begin
            ImportTab[ImportCount].SymNames[
              ImportTab[ImportCount].SymCount] := TokenPool[P].Val;
            Inc(ImportTab[ImportCount].SymCount);
            (* Enregistrer le symbole comme importe *)
            If SymFind(TokenPool[P].Val) < 0 Then
            Begin
              SymAdd(TokenPool[P].Val, SK_VAR, TY_UNKNOWN, 0);
              SymTab[SymCount - 1].IsImported := True;
              SymTab[SymCount - 1].MangledName :=
                M3_VAR_PFX + Name + '_' + TokenPool[P].Val;
            End;
          End;
          Inc(P);
        End;
        Inc(ImportCount);
      End;
      (* Enregistrer le module si pas deja connu *)
      If (Name <> '') And (SymFind(Name) < 0) Then
      Begin
        SymAdd(Name, SK_MODULE, TY_UNKNOWN, 0);
        SymTab[SymCount - 1].IsImported := True;
      End;
      If (P < TokenCount) Then Inc(P); (* passer ';' *)
      Continue;
    End;

    (* Detecter REVEAL T = ... -- TODO 20 *)
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'REVEAL') Then
    Begin
      InVar   := False;
      InConst := False;
      InType  := False;
      Inc(P); (* passer REVEAL *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[P].Val;
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
           (TokenPool[P].Val = '=') Then
        Begin
          Inc(P); (* passer '=' *)
          SaveP := P;
          (* Scanner pour detecter OBJECT et BRANDED *)
          HasObject := False;
          IsBranded := False;
          BrandTag  := '';
          ScanP := P;
          While (ScanP < TokenCount) And Not
                ((TokenPool[ScanP].Kind = TK_PUNCT) And
                 (TokenPool[ScanP].Val = ';')) Do
          Begin
            If (TokenPool[ScanP].Kind = TK_KEYWORD) And
               (TokenPool[ScanP].Val = 'OBJECT') Then
            Begin
              HasObject := True;
              Break;
            End;
            If (TokenPool[ScanP].Kind = TK_KEYWORD) And
               (TokenPool[ScanP].Val = 'BRANDED') Then
            Begin
              IsBranded := True;
              Inc(ScanP);
              If (ScanP < TokenCount) And
                 (TokenPool[ScanP].Kind = TK_STRING) Then
              Begin
                BrandTag := TokenPool[ScanP].Val;
                Inc(ScanP);
              End;
              Continue;
            End;
            Inc(ScanP);
          End;
          (* Trouver l entree opaque correspondante *)
          OIdx := -1;
          For I := 0 To OpaqueCount - 1 Do
            If OpaqueTab[I].Name = Name Then OIdx := I;
          If HasObject Then
          Begin
            (* REVEAL T = [SuperType] [BRANDED ["tag"]] OBJECT ... END *)
            P := SaveP;
            TIdx := ParseObjectTypeFromTokens(P, Name);
            If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ';') Then
              Inc(P);
            If OIdx >= 0 Then
            Begin
              OpaqueTab[OIdx].RevealTIdx := TIdx;
              OpaqueTab[OIdx].IsBranded  := IsBranded;
              OpaqueTab[OIdx].BrandTag   := BrandTag;
              OpaqueTab[OIdx].IsRevealed := True;
              If (OpaqueTab[OIdx].SuperTIdx >= 0) And (TIdx >= 0) Then
              Begin
                If Not TypeCompatible(OpaqueTab[OIdx].SuperTIdx,
                                      TIdx) Then
                  WarnMsg('REVEAL ' + Name +
                    ': type revele peut etre incompatible avec le supertype');
              End;
            End
            Else If TIdx >= 0 Then
            Begin
              If OpaqueCount < MAX_OPAQUE Then
              Begin
                OpaqueTab[OpaqueCount].Name       := Name;
                OpaqueTab[OpaqueCount].SuperTIdx  := TY_UNKNOWN;
                OpaqueTab[OpaqueCount].OpaqueIdx  := TY_UNKNOWN;
                OpaqueTab[OpaqueCount].RevealTIdx := TIdx;
                OpaqueTab[OpaqueCount].IsBranded  := IsBranded;
                OpaqueTab[OpaqueCount].BrandTag   := BrandTag;
                OpaqueTab[OpaqueCount].IsRevealed := True;
                Inc(OpaqueCount);
              End;
            End;
          End
          Else
          Begin
            (* REVEAL T = ExistingType; (alias simple) *)
            P := SaveP;
            RevTypeName := '';
            If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
            Begin
              RevTypeName := TokenPool[P].Val;
              Inc(P);
            End;
            RevTIdx := TypeFindByName(RevTypeName);
            If RevTIdx < 0 Then
              RevTIdx := TypeIdxFromName(RevTypeName);
            If OIdx >= 0 Then
            Begin
              If RevTIdx >= 0 Then
                OpaqueTab[OIdx].RevealTIdx := RevTIdx;
              OpaqueTab[OIdx].IsRevealed := True;
            End
            Else
            Begin
              If OpaqueCount < MAX_OPAQUE Then
              Begin
                OpaqueTab[OpaqueCount].Name       := Name;
                OpaqueTab[OpaqueCount].SuperTIdx  := TY_UNKNOWN;
                OpaqueTab[OpaqueCount].OpaqueIdx  := TY_UNKNOWN;
                OpaqueTab[OpaqueCount].RevealTIdx := RevTIdx;
                OpaqueTab[OpaqueCount].IsBranded  := False;
                OpaqueTab[OpaqueCount].BrandTag   := '';
                OpaqueTab[OpaqueCount].IsRevealed := True;
                Inc(OpaqueCount);
              End;
            End;
            While (P < TokenCount) And Not
                  ((TokenPool[P].Kind = TK_PUNCT) And
                   (TokenPool[P].Val = ';')) Do
              Inc(P);
            If (P < TokenCount) Then Inc(P);
          End;
          If Opts.DebugMode Then
          Begin
            Write('  REVEAL ', Name);
            If IsBranded Then
            Begin
              Write(' BRANDED');
              If BrandTag <> '' Then Write(' "', BrandTag, '"');
            End;
            WriteLn;
          End;
        End;
      End;
      Continue;
    End;

    (* ---- Traiter une declaration TYPE : ident = RECORD ... END *)
    (* TODO 16 - parser les types RECORD definis par l utilisateur *)
    If InType And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      Name := TokenPool[P].Val;
      Inc(P);
      (* Chercher '=' *)
      If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
         (TokenPool[P].Val = '=') Then
      Begin
        Inc(P); (* passer '=' *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
           (TokenPool[P].Val = 'RECORD') Then
        Begin
          TIdx := ParseRecordTypeFromTokens(P, Name);
          (* Passer le ';' apres END *)
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
                (TokenPool[P].Val = 'PROCEDURE') Then
        Begin
          (* TODO 17 - TYPE ProcType = PROCEDURE(params): RetType *)
          If TypeCount < MAX_TYPE Then
          Begin
            TIdx := TypeCount;
            Inc(TypeCount);
            TypeTab[TIdx].Kind := TYK_PROC;
            TypeTab[TIdx].Name := Name;
            TypeTab[TIdx].Size := 2; (* pointeur de code 16 bits *)
            TypeTab[TIdx].BaseTypeIdx := TY_IDX_VOID;
            TypeTab[TIdx].FieldCount  := 0;
            TypeTab[TIdx].EnumCount   := 0;
            TypeTab[TIdx].Lo := 0;
            TypeTab[TIdx].Hi := 0;
            SymAdd(Name, SK_TYPE, TIdx, 0);
          End;
          (* Sauter la declaration jusqu au ';' *)
          While (P < TokenCount) And Not
                ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ';')) Do
            Inc(P);
          If P < TokenCount Then Inc(P);
        End
        Else If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
                (TokenPool[P].Val = 'OBJECT') Then
        Begin
          (* TODO 19 - TYPE T = OBJECT ... END *)
          TIdx := ParseObjectTypeFromTokens(P, Name);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else If (P < TokenCount) And
                ((TokenPool[P].Kind = TK_IDENT) Or
                 ((TokenPool[P].Kind = TK_KEYWORD) And
                  (TokenPool[P].Val = 'ROOT'))) And
                (P + 1 < TokenCount) And
                (TokenPool[P + 1].Kind = TK_KEYWORD) And
                (TokenPool[P + 1].Val = 'OBJECT') Then
        Begin
          (* TODO 19 - TYPE T = ParentType OBJECT ... END *)
          TIdx := ParseObjectTypeFromTokens(P, Name);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else If (P < TokenCount) And
                ((TokenPool[P].Kind = TK_IDENT) Or
                 ((TokenPool[P].Kind = TK_KEYWORD) And
                  (TokenPool[P].Val = 'ROOT'))) And
                (P + 1 < TokenCount) And
                (TokenPool[P + 1].Kind = TK_KEYWORD) And
                (TokenPool[P + 1].Val = 'BRANDED') Then
        Begin
          (* TODO 20 - TYPE T = ParentType BRANDED [tag] OBJECT ... END *)
          TIdx := ParseObjectTypeFromTokens(P, Name);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
                (TokenPool[P].Val = 'BRANDED') Then
        Begin
          (* TODO 20 - TYPE T = BRANDED [tag] OBJECT ... END *)
          TIdx := ParseObjectTypeFromTokens(P, Name);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else
        Begin
          While (P < TokenCount) And Not
                ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ';')) Do
            Inc(P);
          If P < TokenCount Then Inc(P);
        End;
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
              (TokenPool[P].Val = '<:') Then
      Begin
        Inc(P); (* passer '<:' *)
        (* TYPE T <: SuperType - declaration opaque (TODO 20) *)
        SuperName := '';
        If (P < TokenCount) And
           ((TokenPool[P].Kind = TK_IDENT) Or
            (TokenPool[P].Kind = TK_KEYWORD)) Then
        Begin
          SuperName := TokenPool[P].Val;
          Inc(P);
        End;
        If TypeCount < MAX_TYPE Then
        Begin
          TIdx := TypeCount;
          Inc(TypeCount);
          TypeTab[TIdx].Kind        := TYK_OPAQUE;
          TypeTab[TIdx].Name        := Name;
          TypeTab[TIdx].Size        := 2;
          TypeTab[TIdx].BaseTypeIdx := TypeIdxFromName(SuperName);
          TypeTab[TIdx].Lo          := 0;
          TypeTab[TIdx].Hi          := 0;
          TypeTab[TIdx].FieldCount  := 0;
          TypeTab[TIdx].EnumCount   := 0;
          SymAdd(Name, SK_TYPE, TIdx, 0);
          If OpaqueCount < MAX_OPAQUE Then
          Begin
            OpaqueTab[OpaqueCount].Name       := Name;
            OpaqueTab[OpaqueCount].SuperTIdx  := TypeTab[TIdx].BaseTypeIdx;
            OpaqueTab[OpaqueCount].OpaqueIdx  := TIdx;
            OpaqueTab[OpaqueCount].RevealTIdx := TY_UNKNOWN;
            OpaqueTab[OpaqueCount].IsBranded  := False;
            OpaqueTab[OpaqueCount].BrandTag   := '';
            OpaqueTab[OpaqueCount].IsRevealed := False;
            Inc(OpaqueCount);
          End;
          If Opts.DebugMode Then
            WriteLn('  OPAQUE TYPE: ', Name, ' <: ', SuperName);
        End;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else
      Begin
        (* Pas de '=' ou '<:' -> avancer *)
        While (P < TokenCount) And Not
              ((TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ';')) Do
          Inc(P);
        If P < TokenCount Then Inc(P);
      End;
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
              If (TokenPool[P].Kind = TK_KEYWORD) And
                 (TokenPool[P].Val = 'ARRAY') Then
              Begin
                TIdx := ParseArrayTypeFromTokens(P);
                If TIdx = TY_UNKNOWN Then
                  TIdx := TY_IDX_INTEGER;
              End
              Else If (TokenPool[P].Kind = TK_KEYWORD) Or
                 (TokenPool[P].Kind = TK_IDENT) Then
              Begin
                TIdx := TypeIdxFromName(TokenPool[P].Val);
                If TIdx = TY_UNKNOWN Then
                  TIdx := TY_IDX_INTEGER;
                Inc(P);
              End;
            End;
            (* Creer la variable globale *)
            If (TIdx >= 0) And (TIdx < TypeCount) And
               (TypeTab[TIdx].Kind = TYK_ARRAY) Then
              DataAddGlobalArrayVar(Name, TIdx)
            Else If (TIdx >= 0) And (TIdx < TypeCount) And
               (TypeTab[TIdx].Kind = TYK_RECORD) Then
              DataAddGlobalRecordVar(Name, TIdx)
            Else
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

(* ============================================================
   TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
   ============================================================ *)

(* ---- GenVarRef : generer operande MASM pour valeur variable -- *)
(* Retourne 'WORD PTR [BP-n]' pour locale, 'WORD PTR label' pour *)
(* globale, 'WORD PTR [BX]' pour param VAR (deref pointeur).     *)

Function GenVarRef(SIdx : Integer) : TString;
Var
  Pfx  : TString;
  Sz   : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    GenVarRef := 'WORD PTR [0]';
    Exit;
  End;

  Sz := TypeSizeFromIdx(SymTab[SIdx].TypeIdx);
  If Sz <= 1 Then
    Pfx := 'BYTE PTR '
  Else
    Pfx := 'WORD PTR ';

  Case SymTab[SIdx].Kind Of
    SK_VAR :
    Begin
      If SymTab[SIdx].ScopeLevel = 0 Then
        (* Variable globale : acces par label DATA *)
        GenVarRef := Pfx + SymTab[SIdx].MangledName
      Else
        (* Variable locale : acces par BP *)
        GenVarRef := Pfx + '[BP' + IntToStr(SymTab[SIdx].Offset) + ']';
    End;
    SK_PARAM :
    Begin
      If SymTab[SIdx].IsReadonly Then
        (* READONLY : passage par adresse, deref via BX *)
        GenVarRef := Pfx + '[BP+' + IntToStr(SymTab[SIdx].Offset) + ']'
      Else
        (* VALUE param : acces direct sur pile *)
        GenVarRef := Pfx + '[BP+' + IntToStr(SymTab[SIdx].Offset) + ']';
    End;
    SK_CONST :
    Begin
      If SymTab[SIdx].ScopeLevel = 0 Then
        GenVarRef := Pfx + SymTab[SIdx].MangledName
      Else
        GenVarRef := Pfx + '[BP' + IntToStr(SymTab[SIdx].Offset) + ']';
    End;
  Else
    GenVarRef := Pfx + SymTab[SIdx].MangledName;
  End;
End;

(* ---- GenVarAddr : generer operande MASM pour adresse variable *)
(* Retourne 'OFFSET label' pour globale, expression LEA pour      *)
(* locale.                                                         *)

Function GenVarAddr(SIdx : Integer) : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    GenVarAddr := 'OFFSET 0';
    Exit;
  End;

  Case SymTab[SIdx].Kind Of
    SK_VAR :
    Begin
      If SymTab[SIdx].ScopeLevel = 0 Then
        GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName
      Else
        GenVarAddr := 'BP' + IntToStr(SymTab[SIdx].Offset);
    End;
    SK_PARAM :
      GenVarAddr := 'BP+' + IntToStr(SymTab[SIdx].Offset);
    SK_CONST :
      GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName;
  Else
    GenVarAddr := 'OFFSET ' + SymTab[SIdx].MangledName;
  End;
End;

(* ---- GenStoreVar : emettre le code pour stocker AX dans var -- *)
(* Emet MOV destination, AX (ou MOV destination, AL pour BYTE).   *)

Procedure GenStoreVar(SIdx : Integer);
Var
  Ref : TString;
  Sz  : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Ref := GenVarRef(SIdx);
  Sz  := TypeSizeFromIdx(SymTab[SIdx].TypeIdx);
  If Sz <= 1 Then
    EmitInstrAB('MOV', Ref, 'AL')
  Else
    EmitInstrAB('MOV', Ref, 'AX');
End;

(* ---- GenLoadVar : emettre le code pour charger var dans AX --- *)
(* Emet MOV AX, source (ou MOV AL,source + CBW pour BYTE).        *)

Procedure GenLoadVar(SIdx : Integer);
Var
  Ref : TString;
  Sz  : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Ref := GenVarRef(SIdx);
  Sz  := TypeSizeFromIdx(SymTab[SIdx].TypeIdx);
  If Sz <= 1 Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrAB('MOV', 'AL', Ref);
  End
  Else
    EmitInstrAB('MOV', 'AX', Ref);
End;

(* ---- EmitAssign : emettre code d affectation := ---------------- *)
(* Emet : valeur dans AX -> MOV destination, AX                     *)
(* Pour RECORD/ARRAY : REP MOVSW (copie bloc).                      *)

Procedure EmitAssign(DestIdx : Integer; Sz : Integer);
Begin
  If Sz <= 2 Then
    (* Affectation simple : valeur dans AX *)
    GenStoreVar(DestIdx)
  Else
  Begin
    (* Affectation bloc : REP MOVSW *)
    EmitComment('assign bloc ' + IntToStr(Sz) + ' octets');
    EmitInstrAB('MOV', 'CX', IntToStr(Sz Div 2));
    EmitInstr('CLD');
    EmitInstr('REP MOVSW');
    If (Sz Mod 2) = 1 Then
      EmitInstr('MOVSB');
  End;
End;

(* ---- SkipToMatchingSemicolon : avancer jusqu au ';' ----------- *)
(* Avance P au-dela du prochain ';', en tenant compte de la       *)
(* profondeur des parentheses.                                     *)

Procedure SkipToMatchingSemicolon(Var P : Integer);
Begin
  While (P < TokenCount) And Not
        ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';'))
  Do
    Inc(P);
  If P < TokenCount Then
    Inc(P); (* passer le ';' *)
End;

(* ---- SkipToMatchingEnd : trouver le END correspondant --------- *)
(* Avance P au-dela du END correspondant au BEGIN/PROCEDURE        *)
(* courant, en tenant compte de l imbrication.                     *)

Procedure SkipToMatchingEnd(Var P : Integer);
Var
  Depth : Integer;
Begin
  Depth := 1;
  While (P < TokenCount) And (Depth > 0) Do
  Begin
    If (TokenPool[P].Kind = TK_KEYWORD) Then
    Begin
      If (TokenPool[P].Val = 'BEGIN') Or
         (TokenPool[P].Val = 'IF') Or
         (TokenPool[P].Val = 'WHILE') Or
         (TokenPool[P].Val = 'FOR') Or
         (TokenPool[P].Val = 'LOOP') Or
         (TokenPool[P].Val = 'CASE') Or
         (TokenPool[P].Val = 'TRY') Or
         (TokenPool[P].Val = 'WITH') Or
         (TokenPool[P].Val = 'TYPECASE') Or
         (TokenPool[P].Val = 'LOCK') Then
        Inc(Depth)
      Else If TokenPool[P].Val = 'END' Then
        Dec(Depth);
    End;
    Inc(P);
  End;
End;

(* ============================================================
   TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
   ============================================================ *)

(* ---- EPAtEnd : fin du corps courant ? ------------------------ *)

Function EPAtEnd : Boolean;
Begin
  EPAtEnd := (EP >= EPEnd) Or (EP >= TokenCount);
End;

(* ---- EPMatch : verifier si le token courant correspond ------- *)

Function EPMatch(Kind : TTokenKind; Const Val : TString) : Boolean;
Begin
  EPMatch := False;
  If EP >= TokenCount Then Exit;
  If TokenPool[EP].Kind <> Kind Then Exit;
  If (Val <> '') And (TokenPool[EP].Val <> Val) Then Exit;
  EPMatch := True;
End;

(* ---- FindProcLocal : chercher une variable locale dans proc -- *)

Function FindProcLocal(PI : Integer; Const Name : TString) : Integer;
Var I : Integer;
Begin
  FindProcLocal := -1;
  For I := 0 To ProcTab[PI].LocalCount - 1 Do
    If ProcTab[PI].Locals[I].Name = Name Then
    Begin
      FindProcLocal := I;
      Exit;
    End;
End;

(* ---- FindProcParam : chercher un parametre dans proc --------- *)

Function FindProcParam(PI : Integer; Const Name : TString) : Integer;
Var I : Integer;
Begin
  FindProcParam := -1;
  For I := 0 To ProcTab[PI].ParamCount - 1 Do
    If ProcTab[PI].ParamNames[I] = Name Then
    Begin
      FindProcParam := I;
      Exit;
    End;
End;

(* ---- FindProcByName : chercher une procedure par nom ---------- *)

Function FindProcByName(Const Name : TString) : Integer;
Var I : Integer;
Begin
  FindProcByName := -1;
  For I := 0 To ProcCount - 1 Do
    If ProcTab[I].Name = Name Then
    Begin
      FindProcByName := I;
      Exit;
    End;
End;

(* ---- GenLoadLocal : charger une variable locale dans AX ------- *)

Procedure GenLoadLocal(PI, LI : Integer);
Var OfsStr : TString;
Begin
  OfsStr := IntToStr(ProcTab[PI].Locals[LI].Offset);
  If ProcTab[PI].Locals[LI].Size <= 1 Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [BP' + OfsStr + ']');
  End
  Else
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BP' + OfsStr + ']');
End;

(* ---- GenStoreLocal : stocker AX dans une variable locale ------ *)

Procedure GenStoreLocal(PI, LI : Integer);
Var OfsStr : TString;
Begin
  OfsStr := IntToStr(ProcTab[PI].Locals[LI].Offset);
  If ProcTab[PI].Locals[LI].Size <= 1 Then
    EmitInstrAB('MOV', 'BYTE PTR [BP' + OfsStr + ']', 'AL')
  Else
    EmitInstrAB('MOV', 'WORD PTR [BP' + OfsStr + ']', 'AX');
End;

(* ---- GenLoadParam : charger un parametre dans AX --------------- *)

Procedure GenLoadParam(PI, ParI : Integer);
Var OfsStr : TString;
Begin
  OfsStr := IntToStr(ProcTab[PI].ParamOfs[ParI]);
  If ProcTab[PI].ParamModes[ParI] = PM_VAR Then
  Begin
    (* VAR param : adresse sur pile -> deref *)
    EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' + OfsStr + ']');
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
  End
  Else If ProcTab[PI].ParamModes[ParI] = PM_READONLY Then
  Begin
    (* READONLY : meme traitement que VALUE pour 16 bits *)
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+' + OfsStr + ']');
  End
  Else
    (* VALUE param : acces direct *)
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+' + OfsStr + ']');
End;

(* ---- GenStoreParam : stocker AX dans un parametre -------------- *)

Procedure GenStoreParam(PI, ParI : Integer);
Var OfsStr : TString;
Begin
  OfsStr := IntToStr(ProcTab[PI].ParamOfs[ParI]);
  If ProcTab[PI].ParamModes[ParI] = PM_VAR Then
  Begin
    (* VAR param : adresse sur pile -> store via deref *)
    EmitInstrA('PUSH', 'AX');
    EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' + OfsStr + ']');
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
  End
  Else
    EmitInstrAB('MOV', 'WORD PTR [BP+' + OfsStr + ']', 'AX');
End;

(* ---- Forward declarations for ParseExpr / ParseBody ----------- *)

Procedure ParseExpr; Forward;
Procedure ParseStmt; Forward;

(* ---- ParseCallArgs : parser et empiler les arguments ----------- *)
(* Empile les arguments de gauche a droite (convention Pascal 8086) *)

Procedure ParseCallArgs(Var ArgCount : Integer);
Begin
  ArgCount := 0;
  If EPMatch(TK_PUNCT, '(') Then
  Begin
    Inc(EP); (* passer '(' *)
    While Not EPAtEnd And Not EPMatch(TK_PUNCT, ')') Do
    Begin
      ParseExpr;
      EmitInstrA('PUSH', 'AX');
      Inc(ArgCount);
      If EPMatch(TK_PUNCT, ',') Then
        Inc(EP); (* passer ',' *)
    End;
    If EPMatch(TK_PUNCT, ')') Then
      Inc(EP); (* passer ')' *)
  End;
End;

(* ---- ParseBuiltinCall : parser les appels de fonctions built-in *)

Procedure ParseBuiltinCall(Const Name : TString);
Var
  ArgCount  : Integer;
  LI, SI    : Integer;
  ArrTIdx   : Integer;
  ArrElemSz : Integer;
  ObjI      : Integer;
  Lbl       : TString;
Begin
  If Name = 'ABS' Then
  Begin
    (* ABS(x) -> CALL _M3RT_ABS *)
    Inc(EP); (* passer '(' *)
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitInstr('CALL    ' + M3_RT_PFX + 'ABS');
  End
  Else If Name = 'MAX' Then
  Begin
    Inc(EP); (* passer '(' *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX');
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ParseExpr;
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'AX');
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitInstr('CALL    ' + M3_RT_PFX + 'MAX');
  End
  Else If Name = 'MIN' Then
  Begin
    Inc(EP); (* passer '(' *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX');
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ParseExpr;
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'AX');
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitInstr('CALL    ' + M3_RT_PFX + 'MIN');
  End
  Else If Name = 'ORD' Then
  Begin
    (* ORD(x) : identite pour CHAR/BOOLEAN -> AX *)
    Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    (* valeur deja dans AX *)
  End
  Else If Name = 'VAL' Then
  Begin
    (* VAL(T, x) : type conversion (stub: just eval x) *)
    Inc(EP);
    (* skip type name *)
    If (EP < TokenCount) And
       ((TokenPool[EP].Kind = TK_KEYWORD) Or
        (TokenPool[EP].Kind = TK_IDENT)) Then
      Inc(EP);
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'FLOAT' Then
  Begin
    (* FLOAT(x) : stub -> AX = x (integer approx) *)
    Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'TRUNC' Then
  Begin
    (* TRUNC(x) : stub -> AX = x (already integer) *)
    Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'ROUND' Then
  Begin
    Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If (Name = 'FIRST') Or (Name = 'LAST') Or (Name = 'NUMBER') Then
  Begin
    (* FIRST(T)/LAST(T)/NUMBER(T) : compile-time for primitives *)
    Inc(EP);
    If (EP < TokenCount) And
       ((TokenPool[EP].Kind = TK_KEYWORD) Or
        (TokenPool[EP].Kind = TK_IDENT)) Then
    Begin
      If Name = 'FIRST' Then
        EmitInstrAB('MOV', 'AX', IntToStr(TypeFirst(TokenPool[EP].Val)))
      Else If Name = 'LAST' Then
        EmitInstrAB('MOV', 'AX', IntToStr(TypeLast(TokenPool[EP].Val)))
      Else
      Begin
        (* NUMBER: check if it is an array variable *)
        LI := FindProcLocal(CurProcIdx, TokenPool[EP].Val);
        If (LI >= 0) And
           (ProcTab[CurProcIdx].Locals[LI].TypeIdx >= 0) And
           (ProcTab[CurProcIdx].Locals[LI].TypeIdx < TypeCount) And
           (TypeTab[ProcTab[CurProcIdx].Locals[LI].TypeIdx].Kind = TYK_ARRAY)
        Then
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[ProcTab[CurProcIdx].Locals[LI].TypeIdx].Hi -
                     TypeTab[ProcTab[CurProcIdx].Locals[LI].TypeIdx].Lo + 1))
        Else
        Begin
          SI := SymFind(TokenPool[EP].Val);
          If (SI >= 0) And (SymTab[SI].TypeIdx >= 0) And
             (SymTab[SI].TypeIdx < TypeCount) And
             (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_ARRAY) Then
            EmitInstrAB('MOV', 'AX',
              IntToStr(TypeTab[SymTab[SI].TypeIdx].Hi -
                       TypeTab[SymTab[SI].TypeIdx].Lo + 1))
          Else
            EmitInstrAB('MOV', 'AX',
              IntToStr(TypeNumber(TokenPool[EP].Val)));
        End;
      End;
      Inc(EP);
    End
    Else
    Begin
      ParseExpr;
      EmitComment('FIRST/LAST/NUMBER on expr (stub)');
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'ISTYPE' Then
  Begin
    (* ISTYPE(expr, T) -> compare typecode dynamique *)
    Inc(EP); (* passer '(' *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX'); (* sauver le pointeur objet *)
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ObjI := -1;
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      ObjI := ObjTypeFind(TokenPool[EP].Val);
      Inc(EP);
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitInstrA('POP', 'BX'); (* BX = ptr objet *)
    If ObjI >= 0 Then
    Begin
      Lbl := LabelGen;
      EmitInstrAB('MOV', 'BX', 'WORD PTR [BX]');
      EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
      EmitInstrAB('CMP', 'AX', IntToStr(ObjTypeTab[ObjI].TypeCode));
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('JNE', Lbl);
      EmitInstrAB('MOV', 'AX', '1');
      EmitLabel(Lbl);
    End
    Else
    Begin
      EmitInstrAB('MOV', 'AX', '1');
      EmitComment('ISTYPE: type inconnu, true par defaut');
    End;
  End
  Else If Name = 'NARROW' Then
  Begin
    (* NARROW(expr, T) -> verifier typecode, sinon erreur *)
    Inc(EP); (* passer '(' *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX'); (* sauver le pointeur objet *)
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ObjI := -1;
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      ObjI := ObjTypeFind(TokenPool[EP].Val);
      Inc(EP);
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitInstrA('POP', 'AX'); (* AX = ptr objet resultat *)
    If ObjI >= 0 Then
    Begin
      Lbl := LabelGen;
      EmitInstrA('PUSH', 'AX');
      EmitInstrAB('MOV', 'BX', 'WORD PTR [AX]');
      EmitInstrAB('CMP', 'WORD PTR [BX]',
                   IntToStr(ObjTypeTab[ObjI].TypeCode));
      EmitInstrA('JE', Lbl);
      EmitComment('NARROW echec: halt');
      EmitInstrAB('MOV', 'AH', '4Ch');
      EmitInstrAB('MOV', 'AL', '1');
      EmitInstr('INT    21h');
      EmitLabel(Lbl);
      EmitInstrA('POP', 'AX');
    End
    Else
      EmitComment('NARROW: type inconnu, no-op');
  End
  Else If Name = 'TYPECODE' Then
  Begin
    (* TYPECODE(T) -> AX = typecode statique *)
    Inc(EP); (* passer '(' *)
    ObjI := -1;
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      ObjI := ObjTypeFind(TokenPool[EP].Val);
      Inc(EP);
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    If ObjI >= 0 Then
      EmitInstrAB('MOV', 'AX', IntToStr(ObjTypeTab[ObjI].TypeCode))
    Else
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitComment('TYPECODE: type inconnu');
    End;
  End
  Else If Name = 'NEW' Then
  Begin
    (* NEW(T) -> allouer un objet ou un ref *)
    Inc(EP); (* passer '(' *)
    ObjI := -1;
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      ObjI := ObjTypeFind(TokenPool[EP].Val);
      Inc(EP);
    End;
    (* Skip optional method overrides *)
    While Not EPAtEnd And Not EPMatch(TK_PUNCT, ')') Do
      Inc(EP);
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    If ObjI >= 0 Then
    Begin
      EmitInstrAB('MOV', 'CX', IntToStr(ObjTypeTab[ObjI].TotalSize));
      EmitInstrAB('LEA', 'SI', ObjTypeTab[ObjI].VtableLabel);
      EmitInstr('CALL    ' + M3_RT_PFX + 'OBJNEW');
    End
    Else
      EmitInstr('CALL    ' + M3_RT_PFX + 'NEW');
  End
  Else If (Name = 'BITSIZE') Or (Name = 'BYTESIZE') Or
          (Name = 'ADRSIZE') Then
  Begin
    Inc(EP);
    If (EP < TokenCount) Then Inc(EP);
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    If Name = 'BITSIZE' Then
      EmitInstrAB('MOV', 'AX', '16')
    Else
      EmitInstrAB('MOV', 'AX', '2');
    EmitComment(Name + ' stub');
  End
  Else If Name = 'ADR' Then
  Begin
    (* ADR(x) : address of variable *)
    Inc(EP);
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      (* Try local first *)
      ArgCount := FindProcLocal(CurProcIdx, TokenPool[EP].Val);
      If ArgCount >= 0 Then
        EmitInstrAB('LEA', 'AX', '[BP' +
          IntToStr(ProcTab[CurProcIdx].Locals[ArgCount].Offset) + ']')
      Else
      Begin
        ArgCount := FindProcParam(CurProcIdx, TokenPool[EP].Val);
        If ArgCount >= 0 Then
          EmitInstrAB('LEA', 'AX', '[BP+' +
            IntToStr(ProcTab[CurProcIdx].ParamOfs[ArgCount]) + ']')
        Else
        Begin
          ArgCount := SymFind(TokenPool[EP].Val);
          If ArgCount >= 0 Then
            EmitInstrAB('LEA', 'AX', SymTab[ArgCount].MangledName)
          Else
            EmitComment('ADR: unknown var ' + TokenPool[EP].Val);
        End;
      End;
      Inc(EP);
    End
    Else
    Begin
      ParseExpr;
      EmitComment('ADR on expr (stub)');
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'SUBARRAY' Then
  Begin
    (* SUBARRAY(arr, start, len) -> pointer to arr + start * elemSize *)
    Inc(EP); (* pass '(' *)
    ArrTIdx := TY_UNKNOWN;
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      LI := FindProcLocal(CurProcIdx, TokenPool[EP].Val);
      If LI >= 0 Then
      Begin
        ArrTIdx := ProcTab[CurProcIdx].Locals[LI].TypeIdx;
        EmitInstrAB('LEA', 'AX', '[BP' +
          IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']');
      End
      Else
      Begin
        SI := SymFind(TokenPool[EP].Val);
        If SI >= 0 Then
        Begin
          ArrTIdx := SymTab[SI].TypeIdx;
          EmitInstrAB('LEA', 'AX', SymTab[SI].MangledName);
        End;
      End;
      Inc(EP);
    End;
    EmitInstrA('PUSH', 'AX');
    If EPMatch(TK_PUNCT, ',') Then Inc(EP);
    ParseExpr; (* start index -> AX *)
    ArrElemSz := 2;
    If (ArrTIdx >= 0) And (ArrTIdx < TypeCount) And
       (TypeTab[ArrTIdx].Kind = TYK_ARRAY) Then
      ArrElemSz := TypeSizeFromIdx(TypeTab[ArrTIdx].BaseTypeIdx);
    If ArrElemSz = 2 Then
      EmitInstrAB('SHL', 'AX', '1')
    Else If ArrElemSz <> 1 Then
    Begin
      EmitInstrAB('MOV', 'CX', IntToStr(ArrElemSz));
      EmitInstrA('MUL', 'CX');
    End;
    EmitInstrA('POP', 'BX');
    EmitInstrAB('ADD', 'AX', 'BX');
    If EPMatch(TK_PUNCT, ',') Then
    Begin
      Inc(EP);
      EmitInstrA('PUSH', 'AX');
      ParseExpr; (* len - ignored for address calculation *)
      EmitInstrA('POP', 'AX');
    End;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitComment('SUBARRAY: AX = base + start*elemSize');
  End
  Else
  Begin
    (* Unknown builtin - skip args *)
    While Not EPAtEnd And Not EPMatch(TK_PUNCT, ')') Do
      Inc(EP);
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitComment(Name + ' builtin stub');
  End;
End;

(* ---- ParseProcCallStmt : parser un appel INC/DEC comme stmt --- *)

Procedure ParseProcCallStmt(Const Name : TString);
Var
  LI, ParI, SI : Integer;
  VarName      : TString;
Begin
  If (Name = 'INC') Or (Name = 'DEC') Then
  Begin
    (* INC(x) / INC(x, n) / DEC(x) / DEC(x, n) *)
    If EPMatch(TK_PUNCT, '(') Then Inc(EP);
    VarName := '';
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      VarName := TokenPool[EP].Val;
      Inc(EP);
    End;

    (* Load current value *)
    LI := FindProcLocal(CurProcIdx, VarName);
    ParI := -1;
    SI := -1;
    If LI < 0 Then ParI := FindProcParam(CurProcIdx, VarName);
    If (LI < 0) And (ParI < 0) Then SI := SymFind(VarName);

    If LI >= 0 Then
      GenLoadLocal(CurProcIdx, LI)
    Else If ParI >= 0 Then
      GenLoadParam(CurProcIdx, ParI)
    Else If SI >= 0 Then
      GenLoadVar(SI);

    If EPMatch(TK_PUNCT, ',') Then
    Begin
      (* INC(x, n) / DEC(x, n) *)
      Inc(EP);
      EmitInstrA('PUSH', 'AX');
      ParseExpr;
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      If Name = 'INC' Then
        EmitInstrAB('ADD', 'AX', 'BX')
      Else
        EmitInstrAB('SUB', 'AX', 'BX');
    End
    Else
    Begin
      (* INC(x) / DEC(x) *)
      If Name = 'INC' Then
        EmitInstr('INC     AX')
      Else
        EmitInstr('DEC     AX');
    End;

    (* Store back *)
    If LI >= 0 Then
      GenStoreLocal(CurProcIdx, LI)
    Else If ParI >= 0 Then
      GenStoreParam(CurProcIdx, ParI)
    Else If SI >= 0 Then
      GenStoreVar(SI);

    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
  End
  Else If Name = 'DISPOSE' Then
  Begin
    If EPMatch(TK_PUNCT, '(') Then Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitComment('DISPOSE (stub - no heap free in DOS)');
  End
  Else If Name = 'EVAL' Then
  Begin
    If EPMatch(TK_PUNCT, '(') Then Inc(EP);
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then Inc(EP);
    EmitComment('EVAL: result discarded');
  End;
End;

(* ---- ParseQualifiedIdent : parser un identifiant qualifie ----- *)
(* Gere Module.Ident et les appels de module (Wr.PutText etc.)    *)

Procedure ParseQualifiedIdent(Const ModName : TString);
Var
  MethName  : TString;
  ArgCount  : Integer;
Begin
  Inc(EP); (* passer '.' *)
  MethName := '';
  If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
  Begin
    MethName := TokenPool[EP].Val;
    Inc(EP);
  End;

  (* Module Wr : ecriture *)
  If ModName = 'Wr' Then
  Begin
    If MethName = 'PutChar' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'DX');
      EmitInstrAB('MOV', 'AH', '02h');
      EmitInstr('INT    21h');
    End
    Else If MethName = 'PutText' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
    End
    Else If MethName = 'PutInt' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstrAB('LEA', 'DI', M3_RT_PFX + 'NUMBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'NUMTOSTR');
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
    End
    Else If MethName = 'Nl' Then
    Begin
      (* Wr.Nl() : write CRLF *)
      If EPMatch(TK_PUNCT, '(') Then
      Begin
        Inc(EP);
        If EPMatch(TK_PUNCT, ')') Then Inc(EP);
      End;
      EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'CRLF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
    End
    Else If MethName = 'PutReal' Then
    Begin
      (* Wr.PutReal(r) : avertissement + affiche comme entier *)
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitComment('Wr.PutReal: approx entiere (REAL non supporte 8086)');
      EmitInstrAB('LEA', 'DI', M3_RT_PFX + 'NUMBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'NUMTOSTR');
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
    End
    Else If MethName = 'PutBool' Then
    Begin
      (* Wr.PutBool(b) : affiche TRUE ou FALSE *)
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRBOOL');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Wr.' + MethName + ' (stub)');
    End;
  End

  (* Module Rd : lecture *)
  Else If ModName = 'Rd' Then
  Begin
    If MethName = 'GetChar' Then
    Begin
      If EPMatch(TK_PUNCT, '(') Then
      Begin
        Inc(EP);
        If EPMatch(TK_PUNCT, ')') Then Inc(EP);
      End;
      EmitInstrAB('MOV', 'AH', '01h');
      EmitInstr('INT    21h');
      EmitInstrAB('XOR', 'AH', 'AH');
    End
    Else If MethName = 'GetInt' Then
    Begin
      If EPMatch(TK_PUNCT, '(') Then
      Begin
        Inc(EP);
        If EPMatch(TK_PUNCT, ')') Then Inc(EP);
      End;
      EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'STRBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'READLINE');
      EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'STRBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'STRTONUM');
    End
    Else If MethName = 'GetLine' Then
    Begin
      (* Rd.GetLine() : lire une ligne complete -> AX=ptr STRBUF *)
      If EPMatch(TK_PUNCT, '(') Then
      Begin
        Inc(EP);
        If EPMatch(TK_PUNCT, ')') Then Inc(EP);
      End;
      EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'STRBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'READLINE');
      EmitInstrAB('LEA', 'AX', M3_RT_PFX + 'STRBUF');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Rd.' + MethName + ' (stub)');
    End;
  End

  (* Module Fmt *)
  Else If ModName = 'Fmt' Then
  Begin
    If MethName = 'Int' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstrAB('LEA', 'DI', M3_RT_PFX + 'NUMBUF');
      EmitInstr('CALL    ' + M3_RT_PFX + 'NUMTOSTR');
    End
    Else If MethName = 'Char' Then
    Begin
      (* Fmt.Char(ch) : convertir un caractere en TEXT d un octet *)
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstrAB('LEA', 'DI', M3_RT_PFX + 'STRBUF');
      EmitInstrAB('MOV', '[DI]', 'AL');
      EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '0');
      EmitInstrAB('MOV', 'AX', 'DI');
    End
    Else If MethName = 'Bool' Then
    Begin
      (* Fmt.Bool(b) : retourne "TRUE" ou "FALSE" en TEXT *)
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + M3_RT_PFX + 'FMTBOOL');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Fmt.' + MethName + ' (stub)');
    End;
  End

  (* Module Text *)
  Else If ModName = 'Text' Then
  Begin
    If MethName = 'Length' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'STRLEN');
    End
    Else If MethName = 'Equal' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'DI');
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'STRCMP');
    End
    Else If MethName = 'GetChar' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'BX');
      EmitInstrA('POP', 'SI');
      EmitInstrAB('XOR', 'AX', 'AX');
      EmitInstrAB('MOV', 'AL', '[SI+BX]');
    End
    Else If MethName = 'Sub' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'CX');
      EmitInstrA('POP', 'BX');
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'TEXTSUB');
    End
    Else If MethName = 'Cat' Then
    Begin
      (* Text.Cat(a, b) : concatener deux TEXT -> AX=ptr *)
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'DI');
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'CONCAT');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Text.' + MethName + ' (stub)');
    End;
  End

  (* Module IO *)
  Else If ModName = 'IO' Then
  Begin
    If MethName = 'Put' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'SI');
      EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('IO.' + MethName + ' (stub)');
    End;
  End

  (* Module Stdio : handles stdout et stderr *)
  Else If ModName = 'Stdio' Then
  Begin
    If MethName = 'stdout' Then
    Begin
      (* Stdio.stdout -> AX = 1 (handle stdout DOS) *)
      EmitInstrAB('MOV', 'AX', '1');
    End
    Else If MethName = 'stderr' Then
    Begin
      (* Stdio.stderr -> AX = 2 (handle stderr DOS) *)
      EmitInstrAB('MOV', 'AX', '2');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Stdio.' + MethName + ' (stub)');
    End;
  End

  (* Module Process *)
  Else If ModName = 'Process' Then
  Begin
    If MethName = 'Exit' Then
    Begin
      ParseCallArgs(ArgCount);
      EmitInstrA('POP', 'AX');
      EmitInstrAB('MOV', 'AH', '4Ch');
      EmitInstr('INT    21h');
    End
    Else
    Begin
      ParseCallArgs(ArgCount);
      EmitComment('Process.' + MethName + ' (stub)');
    End;
  End

  (* Autre module *)
  Else
  Begin
    ParseCallArgs(ArgCount);
    EmitComment(ModName + '.' + MethName + ' (stub)');
  End;
End;

(* ---- ParsePrimary : parser une expression primaire ------------ *)
(* Gere : entier, chaine, caractere, ident (variable/const/proc), *)
(*        appels de fonctions, parentheses, NOT, unaire +/-.      *)
(* Resultat dans AX.                                               *)

Procedure ParsePrimary;
Var
  LI, ParI, SI, PI2 : Integer;
  Name               : TString;
  ArgCount           : Integer;
  Lbl                : TString;
  ArrTIdx            : Integer;
  ArrElemSz          : Integer;
  ArrLo              : LongInt;
  RecTIdx            : Integer;    (* TODO 16 - record type index     *)
  FldI               : Integer;    (* TODO 16 - field index           *)
  FldOfs             : Integer;    (* TODO 16 - field offset          *)
  FldSz              : Integer;    (* TODO 16 - field size            *)
  FldName            : TString;    (* TODO 16 - field name            *)
  ObjI, MI           : Integer;    (* TODO 19 - object type/method    *)
Begin
  If EPAtEnd Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    Exit;
  End;

  (* --- NOT (negation logique) --- *)
  If EPMatch(TK_KEYWORD, 'NOT') Then
  Begin
    Inc(EP);
    ParsePrimary;
    EmitUnaryOp('NOT');
    Exit;
  End;

  (* --- Unaire - (negation arithmetique) --- *)
  If EPMatch(TK_OP, '-') Then
  Begin
    Inc(EP);
    ParsePrimary;
    EmitUnaryOp('-');
    Exit;
  End;

  (* --- Unaire + (noop) --- *)
  If EPMatch(TK_OP, '+') Then
  Begin
    Inc(EP);
    ParsePrimary;
    Exit;
  End;

  (* --- Parentheses --- *)
  If EPMatch(TK_PUNCT, '(') Then
  Begin
    Inc(EP); (* passer '(' *)
    ParseExpr;
    If EPMatch(TK_PUNCT, ')') Then
      Inc(EP); (* passer ')' *)
    Exit;
  End;

  (* --- Litteral entier --- *)
  If TokenPool[EP].Kind = TK_INTEGER Then
  Begin
    EmitInstrAB('MOV', 'AX', IntToStr(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  (* --- Litteral caractere --- *)
  If TokenPool[EP].Kind = TK_CHAR Then
  Begin
    EmitInstrAB('MOV', 'AX', IntToStr(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  (* --- Litteral reel (tronque) --- *)
  If TokenPool[EP].Kind = TK_REAL Then
  Begin
    EmitInstrAB('MOV', 'AX', IntToStr(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  (* --- Litteral chaine TEXT --- *)
  If TokenPool[EP].Kind = TK_STRING Then
  Begin
    Lbl := DataGetOrAddStr(TokenPool[EP].Val);
    EmitInstrAB('LEA', 'AX', Lbl);
    Inc(EP);
    Exit;
  End;

  (* --- Mot-cle TRUE / FALSE / NIL --- *)
  If TokenPool[EP].Kind = TK_KEYWORD Then
  Begin
    If TokenPool[EP].Val = 'TRUE' Then
    Begin
      EmitInstrAB('MOV', 'AX', '1');
      Inc(EP);
      Exit;
    End
    Else If TokenPool[EP].Val = 'FALSE' Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      Inc(EP);
      Exit;
    End
    Else If TokenPool[EP].Val = 'NIL' Then
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      Inc(EP);
      Exit;
    End;
  End;

  (* --- Identifiant --- *)
  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    Name := TokenPool[EP].Val;
    Inc(EP);

    (* Acces qualifie Module.Ident ou Record.Field - TODO 16 *)
    If EPMatch(TK_PUNCT, '.') Then
    Begin
      (* Verifier si c est un module connu *)
      SI := SymFind(Name);
      If (SI >= 0) And (SymTab[SI].Kind = SK_MODULE) Then
      Begin
        ParseQualifiedIdent(Name);
        Exit;
      End;
      (* Sinon : acces champ d un record ou objet *)
      (* Determiner le type de la variable pour trouver le champ *)
      RecTIdx := TY_UNKNOWN;
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
      Begin
        RecTIdx := ProcTab[CurProcIdx].Locals[LI].TypeIdx;
        (* Objets sont des pointeurs : charger le pointeur dans BX *)
        If (RecTIdx >= 0) And (RecTIdx < TypeCount) And
           (TypeTab[RecTIdx].Kind = TYK_OBJECT) Then
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BP' +
            IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']')
        Else
          EmitInstrAB('LEA', 'BX', '[BP' +
            IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']');
      End
      Else
      Begin
        ParI := FindProcParam(CurProcIdx, Name);
        If ParI >= 0 Then
        Begin
          RecTIdx := ProcTab[CurProcIdx].ParamTypes[ParI];
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
            IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']');
        End
        Else
        Begin
          SI := SymFind(Name);
          If SI >= 0 Then
          Begin
            RecTIdx := SymTab[SI].TypeIdx;
            If (RecTIdx >= 0) And (RecTIdx < TypeCount) And
               (TypeTab[RecTIdx].Kind = TYK_OBJECT) Then
              EmitInstrAB('MOV', 'BX', SymTab[SI].MangledName)
            Else
              EmitInstrAB('LEA', 'BX', SymTab[SI].MangledName);
          End
          Else
            EmitComment('unknown var: ' + Name);
        End;
      End;
      (* .champ ou .methode -> calculer l offset et charger *)
      Inc(EP); (* passer '.' *)
      If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        FldName := TokenPool[EP].Val;
        Inc(EP);
        (* Verifier si c est un type objet - TODO 19 *)
        ObjI := -1;
        If (RecTIdx >= 0) And (RecTIdx < TypeCount) And
           (TypeTab[RecTIdx].Kind = TYK_OBJECT) Then
          ObjI := ObjTypeFindByTypeIdx(RecTIdx);
        If ObjI >= 0 Then
        Begin
          (* Chercher d abord une methode *)
          MI := ObjTypeMethodFind(ObjI, FldName);
          If MI >= 0 Then
          Begin
            (* Appel de methode virtuelle via vtable *)
            (* BX = ptr objet, [BX] = ptr vtable *)
            EmitInstrA('PUSH', 'BX'); (* self = premier parametre *)
            (* Parser les arguments *)
            ArgCount := 0;
            If EPMatch(TK_PUNCT, '(') Then
            Begin
              Inc(EP);
              While Not EPAtEnd And Not EPMatch(TK_PUNCT, ')') Do
              Begin
                ParseExpr;
                EmitInstrA('PUSH', 'AX');
                Inc(ArgCount);
                If EPMatch(TK_PUNCT, ',') Then Inc(EP);
              End;
              If EPMatch(TK_PUNCT, ')') Then Inc(EP);
            End;
            (* Charger vtable et appeler la methode *)
            (* Self est deja empile, recuperer ptr objet *)
            EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
              IntToStr(4 + ArgCount * 2) + ']');
            EmitInstrAB('MOV', 'BX', 'WORD PTR [BX]');
            (* Slot 0 = typecode, methodes a partir de slot 1 *)
            EmitInstr('CALL    WORD PTR [BX+' +
              IntToStr(2 + ObjTypeTab[ObjI].Methods[MI].VTSlot * 2) + ']');
            (* Nettoyer les arguments + self de la pile *)
            If ArgCount + 1 > 0 Then
              EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
            Exit;
          End;
          (* Chercher un champ *)
          FldI := ObjTypeFieldFind(ObjI, FldName);
          If FldI >= 0 Then
          Begin
            (* BX = ptr objet, champs apres le vtable ptr (offset +2) *)
            FldOfs := ObjTypeTab[ObjI].Fields[FldI].Offset + 2;
            FldSz  := TypeSizeFromIdx(
                        ObjTypeTab[ObjI].Fields[FldI].TypeIdx);
            If FldOfs > 0 Then
              EmitInstrAB('ADD', 'BX', IntToStr(FldOfs));
            If FldSz <= 1 Then
            Begin
              EmitInstrAB('XOR', 'AX', 'AX');
              EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
            End
            Else
              EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
            Exit;
          End;
          EmitComment('unknown obj member: ' + FldName);
        End
        Else
        Begin
          (* Acces champ record normal *)
          FldI := RecordFieldFind(RecTIdx, FldName);
          If FldI >= 0 Then
          Begin
            FldOfs := TypeTab[RecTIdx].Fields[FldI].Offset;
            FldSz  := TypeSizeFromIdx(
                        TypeTab[RecTIdx].Fields[FldI].TypeIdx);
            If FldOfs > 0 Then
              EmitInstrAB('ADD', 'BX', IntToStr(FldOfs));
            If FldSz <= 1 Then
            Begin
              EmitInstrAB('XOR', 'AX', 'AX');
              EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
            End
            Else
              EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          End
          Else
            EmitComment('unknown field: ' + FldName);
        End;
      End;
      Exit;
    End;

    (* Dereferencement ^ *)
    If EPMatch(TK_PUNCT, '^') Then
    Begin
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
        GenLoadLocal(CurProcIdx, LI)
      Else
      Begin
        ParI := FindProcParam(CurProcIdx, Name);
        If ParI >= 0 Then
          GenLoadParam(CurProcIdx, ParI)
        Else
        Begin
          SI := SymFind(Name);
          If SI >= 0 Then GenLoadVar(SI);
        End;
      End;
      Inc(EP); (* passer '^' *)
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
      Exit;
    End;

    (* Acces index [i] - TODO 15 *)
    If EPMatch(TK_PUNCT, '[') Then
    Begin
      (* Determiner le type du tableau pour taille element et borne *)
      ArrTIdx := TY_UNKNOWN;
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
      Begin
        ArrTIdx := ProcTab[CurProcIdx].Locals[LI].TypeIdx;
        EmitInstrAB('LEA', 'BX', '[BP' +
          IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']');
      End
      Else
      Begin
        ParI := FindProcParam(CurProcIdx, Name);
        If ParI >= 0 Then
        Begin
          ArrTIdx := ProcTab[CurProcIdx].ParamTypes[ParI];
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
            IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']');
        End
        Else
        Begin
          SI := SymFind(Name);
          If SI >= 0 Then
          Begin
            ArrTIdx := SymTab[SI].TypeIdx;
            EmitInstrAB('LEA', 'BX', SymTab[SI].MangledName);
          End;
        End;
      End;
      ArrElemSz := 2;
      ArrLo := 0;
      If (ArrTIdx >= 0) And (ArrTIdx < TypeCount) And
         (TypeTab[ArrTIdx].Kind = TYK_ARRAY) Then
      Begin
        ArrElemSz := TypeSizeFromIdx(TypeTab[ArrTIdx].BaseTypeIdx);
        ArrLo     := TypeTab[ArrTIdx].Lo;
      End;
      EmitInstrA('PUSH', 'BX');
      Inc(EP); (* passer '[' *)
      ParseExpr;
      (* AX = index, ajuster pour borne inferieure *)
      If ArrLo <> 0 Then
        EmitInstrAB('SUB', 'AX', IntToStr(ArrLo));
      (* Calculer offset en octets *)
      If ArrElemSz = 2 Then
        EmitInstrAB('SHL', 'AX', '1')
      Else If ArrElemSz = 4 Then
        EmitInstrAB('SHL', 'AX', '2')
      Else If ArrElemSz <> 1 Then
      Begin
        EmitInstrAB('MOV', 'CX', IntToStr(ArrElemSz));
        EmitInstrA('MUL', 'CX');
      End;
      EmitInstrA('POP', 'BX');
      EmitInstrAB('ADD', 'BX', 'AX');
      If ArrElemSz = 1 Then
      Begin
        EmitInstrAB('XOR', 'AH', 'AH');
        EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
      End
      Else
        EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
      If EPMatch(TK_PUNCT, ']') Then Inc(EP);
      Exit;
    End;

    (* Appel de builtin avec '(' *)
    If EPMatch(TK_PUNCT, '(') Then
    Begin
      (* Built-in functions *)
      If (Name = 'ABS') Or (Name = 'MAX') Or (Name = 'MIN') Or
         (Name = 'ORD') Or (Name = 'VAL') Or (Name = 'FLOAT') Or
         (Name = 'TRUNC') Or (Name = 'ROUND') Or
         (Name = 'FIRST') Or (Name = 'LAST') Or (Name = 'NUMBER') Or
         (Name = 'ISTYPE') Or (Name = 'NARROW') Or (Name = 'TYPECODE') Or
         (Name = 'NEW') Or (Name = 'BITSIZE') Or (Name = 'BYTESIZE') Or
         (Name = 'ADRSIZE') Or (Name = 'ADR') Or
         (Name = 'SUBARRAY') Then
      Begin
        ParseBuiltinCall(Name);
        Exit;
      End;

      (* Appel de procedure/fonction utilisateur *)
      PI2 := FindProcByName(Name);
      If PI2 >= 0 Then
      Begin
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    ' + ProcTab[PI2].MangledName);
        Exit;
      End;

      (* TODO 17 - Appel indirect via variable de type PROCEDURE *)
      LI := FindProcLocal(CurProcIdx, Name);
      If (LI >= 0) And
         (TypeTab[ProcTab[CurProcIdx].Locals[LI].TypeIdx].Kind = TYK_PROC) Then
      Begin
        GenLoadLocal(CurProcIdx, LI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        Exit;
      End;
      ParI := FindProcParam(CurProcIdx, Name);
      If (ParI >= 0) And
         (TypeTab[ProcTab[CurProcIdx].ParamTypes[ParI]].Kind = TYK_PROC) Then
      Begin
        GenLoadParam(CurProcIdx, ParI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        Exit;
      End;
      SI := SymFind(Name);
      If (SI >= 0) And (SymTab[SI].Kind = SK_VAR) And
         (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_PROC) Then
      Begin
        GenLoadVar(SI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        Exit;
      End;

      (* Appel de procedure inconnue (module externe?) *)
      ParseCallArgs(ArgCount);
      EmitComment('call ' + Name + ' (unresolved)');
      Exit;
    End;

    (* Variable locale *)
    LI := FindProcLocal(CurProcIdx, Name);
    If LI >= 0 Then
    Begin
      GenLoadLocal(CurProcIdx, LI);
      Exit;
    End;

    (* Parametre *)
    ParI := FindProcParam(CurProcIdx, Name);
    If ParI >= 0 Then
    Begin
      GenLoadParam(CurProcIdx, ParI);
      Exit;
    End;

    (* Symbole global (variable, constante) *)
    SI := SymFind(Name);
    If SI >= 0 Then
    Begin
      Case SymTab[SI].Kind Of
        SK_CONST :
        Begin
          If SymTab[SI].TypeIdx = TY_IDX_BOOLEAN Then
            EmitInstrAB('MOV', 'AX', IntToStr(SymTab[SI].ImmVal))
          Else If SymTab[SI].TypeIdx = TY_IDX_NIL Then
            EmitInstrAB('XOR', 'AX', 'AX')
          Else
            GenLoadVar(SI);
        End;
        SK_VAR :
          GenLoadVar(SI);
        SK_PROC :
        Begin
          (* Procedure sans parentheses -> adresse *)
          EmitInstrAB('MOV', 'AX', 'OFFSET ' + SymTab[SI].MangledName);
        End;
      Else
        GenLoadVar(SI);
      End;
      Exit;
    End;

    (* Identifiant inconnu *)
    EmitComment('unknown ident: ' + Name);
    EmitInstrAB('XOR', 'AX', 'AX');
    Exit;
  End;

  (* Token inattendu -> avancer *)
  EmitComment('unexpected token: ' + TokenPool[EP].Val);
  Inc(EP);
End;

(* ============================================================
   TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
   ============================================================ *)

(* ---- EmitBinOpText : comparaison de chaines TEXT ------------- *)
(* SI=gauche, DI=droite. Appelle _M3RT_STRCMP qui positionne les *)
(* drapeaux (ZF/CF). Puis utilise la condition Jcc appropriee.    *)

Procedure EmitBinOpText(Const Op : TString);
Var
  LblTrue, LblEnd : TString;
Begin
  LblTrue := LabelGen;
  LblEnd  := LabelGen;

  (* Preparer les arguments : SI=gauche(AX), DI=droite(BX) *)
  WriteLn(OutF, '        MOV     SI, AX');
  WriteLn(OutF, '        MOV     DI, BX');
  WriteLn(OutF, '        CALL    ', M3_RT_PFX, 'STRCMP');

  (* _M3RT_STRCMP : positionne ZF si egal, CF si gauche < droite *)
  If Op = '=' Then
    WriteLn(OutF, '        JE      ', LblTrue)
  Else If Op = '#' Then
    WriteLn(OutF, '        JNE     ', LblTrue)
  Else If Op = '<' Then
    WriteLn(OutF, '        JB      ', LblTrue)
  Else If Op = '>' Then
    WriteLn(OutF, '        JA      ', LblTrue)
  Else If Op = '<=' Then
    WriteLn(OutF, '        JBE     ', LblTrue)
  Else If Op = '>=' Then
    WriteLn(OutF, '        JAE     ', LblTrue);

  WriteLn(OutF, '        XOR     AX, AX');
  WriteLn(OutF, '        JMP     SHORT ', LblEnd);
  WriteLn(OutF, LblTrue, ':');
  WriteLn(OutF, '        MOV     AX, 1');
  WriteLn(OutF, LblEnd, ':');
End;

(* ---- EmitSetOp : operations ensemblistes -------------------- *)
(* AX = ensemble gauche (masque de bits 16 bits)                  *)
(* BX = ensemble droite                                           *)
(* Resultat dans AX.                                              *)
(* Union : +            -> OR  AX, BX                             *)
(* Intersection : star  -> AND AX, BX                             *)
(* Difference : -       -> NOT BX / AND AX, BX                   *)
(* Diff. symetrique : / -> XOR AX, BX                            *)

Procedure EmitSetOp(Const Op : TString);
Begin
  If Op = '+' Then
    WriteLn(OutF, '        OR      AX, BX')
  Else If Op = '*' Then
    WriteLn(OutF, '        AND     AX, BX')
  Else If Op = '-' Then
  Begin
    WriteLn(OutF, '        NOT     BX');
    WriteLn(OutF, '        AND     AX, BX');
  End
  Else If Op = '/' Then
    WriteLn(OutF, '        XOR     AX, BX');
End;

(* ---- ParseExprPrec : parseur Pratt pour expressions binaires -- *)
(* MinPrec = niveau de precedence minimum a accepter.              *)
(* Resultat dans AX.                                               *)
(* Court-circuit : AND evalue droite seulement si gauche <> 0.     *)
(*                 OR evalue droite seulement si gauche = 0.       *)

Procedure ParseExprPrec(MinPrec : Integer);
Var
  Op       : TString;
  Prec     : Integer;
  LblSkip  : TString;
  LblEnd   : TString;
Begin
  ParsePrimary;

  While Not EPAtEnd Do
  Begin
    (* Verifier si le token courant est un operateur binaire *)
    If Not IsM3BinOp(TokenPool[EP]) Then
      Break;

    Op := TokenPool[EP].Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then
      Break;

    Inc(EP); (* passer l operateur *)

    (* Court-circuit pour AND *)
    If Op = 'AND' Then
    Begin
      LblSkip := LabelGen;
      LblEnd  := LabelGen;
      WriteLn(OutF, '        TEST    AX, AX');
      WriteLn(OutF, '        JZ      ', LblSkip);
      ParseExprPrec(Prec + 1);
      WriteLn(OutF, '        TEST    AX, AX');
      WriteLn(OutF, '        JZ      ', LblSkip);
      WriteLn(OutF, '        MOV     AX, 1');
      WriteLn(OutF, '        JMP     SHORT ', LblEnd);
      WriteLn(OutF, LblSkip, ':');
      WriteLn(OutF, '        XOR     AX, AX');
      WriteLn(OutF, LblEnd, ':');
    End

    (* Court-circuit pour OR *)
    Else If Op = 'OR' Then
    Begin
      LblSkip := LabelGen;
      LblEnd  := LabelGen;
      WriteLn(OutF, '        TEST    AX, AX');
      WriteLn(OutF, '        JNZ     ', LblSkip);
      ParseExprPrec(Prec + 1);
      WriteLn(OutF, '        TEST    AX, AX');
      WriteLn(OutF, '        JNZ     ', LblSkip);
      WriteLn(OutF, '        XOR     AX, AX');
      WriteLn(OutF, '        JMP     SHORT ', LblEnd);
      WriteLn(OutF, LblSkip, ':');
      WriteLn(OutF, '        MOV     AX, 1');
      WriteLn(OutF, LblEnd, ':');
    End

    (* Operateurs standards *)
    Else
    Begin
      (* Sauver le cote gauche *)
      EmitInstrA('PUSH', 'AX');

      (* Parser le cote droit avec precedence superieure *)
      ParseExprPrec(Prec + 1);

      (* Restaurer le cote gauche *)
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');

      (* Emettre l operation *)
      EmitBinOp(Op);
    End;
  End;
End;

(* ---- ParseExpr : parser une expression complete ---------------- *)

Procedure ParseExpr;
Begin
  ParseExprPrec(1);
End;

(* ============================================================
   TODO 14 - BOUCLES : WHILE / REPEAT / FOR / LOOP / EXIT [IMPLEMENTE]
   ============================================================ *)

(* ---- LoopPush : empiler le label de sortie EXIT d une boucle LOOP - *)

Procedure LoopPush(Const ExLbl : TString);
Begin
  If LoopExitTop >= MAX_LOOP_NEST Then
    FatalError('Boucles LOOP imbriquees trop profondes');
  LoopExitStack[LoopExitTop] := ExLbl;
  Inc(LoopExitTop);
End;

(* ---- LoopPop : depiler le label de sortie EXIT -------------------- *)

Procedure LoopPop;
Begin
  If LoopExitTop > 0 Then
    Dec(LoopExitTop);
End;

(* ---- ParseStmt : parser une instruction unique du corps -------- *)
(* Gere : affectation :=, appels de procedure (y compris qualifies *)
(* Module.Ident), RETURN, IF/ELSIF/ELSE/END, CASE/OF/END,         *)
(* TYPECASE/OF/END, WHILE/DO/END, FOR/TO/BY/DO/END,               *)
(* LOOP/EXIT/END, REPEAT/UNTIL.                                    *)

Procedure ParseStmt;
Var
  Name, LblTest, LblEnd, LblElse : TString;
  LI, ParI, SI, PI2   : Integer;
  ArgCount             : Integer;
  LoopLbl, ExitLbl     : TString;
  ForVar               : TString;
  ForLI, ForParI, ForSI: Integer;
  ByVal                : LongInt;
  LblNext, LblBody     : TString;   (* TODO 13 - CASE labels          *)
  CaseVal, HiVal       : TString;   (* TODO 13 - CASE value/range     *)
  HasRange             : Boolean;    (* TODO 13 - range .. detected    *)
  NegSign              : Boolean;    (* TODO 13 - negative value       *)
  ArrTIdx              : Integer;    (* TODO 15 - array type index     *)
  ArrElemSz            : Integer;    (* TODO 15 - array element size   *)
  ArrLo                : LongInt;    (* TODO 15 - array lower bound    *)
  RecTIdx              : Integer;    (* TODO 16 - record type index    *)
  FldI                 : Integer;    (* TODO 16 - field index          *)
  FldOfs               : Integer;    (* TODO 16 - field offset         *)
  FldSz                : Integer;    (* TODO 16 - field size           *)
  FldName              : TString;    (* TODO 16 - field name           *)
  WithVar              : TString;    (* TODO 16 - WITH alias name      *)
  ObjI, MI             : Integer;    (* TODO 19 - object type/method   *)
Begin
  If EPAtEnd Then Exit;

  (* --- Instruction vide ';' --- *)
  If EPMatch(TK_PUNCT, ';') Then
  Begin
    Inc(EP);
    Exit;
  End;

  (* --- RETURN [expr] --- *)
  If EPMatch(TK_KEYWORD, 'RETURN') Then
  Begin
    Inc(EP);
    (* Si un expression suit (pas ';' ou END), l evaluer *)
    If Not EPAtEnd And
       Not EPMatch(TK_PUNCT, ';') And
       Not EPMatch(TK_KEYWORD, 'END') Then
      ParseExpr;
    EmitInstrA('JMP', RetLbl);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- EXIT (sortie de boucle LOOP, via LoopExitStack) --- *)
  (* TODO 14 - EXIT autonome, utilisable dans IF/CASE imbrique      *)
  If EPMatch(TK_KEYWORD, 'EXIT') Then
  Begin
    Inc(EP);
    If LoopExitTop > 0 Then
      EmitInstrA('JMP', LoopExitStack[LoopExitTop - 1])
    Else
      FatalError('EXIT en dehors d''une boucle LOOP');
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- IF / ELSIF / ELSE / END --- *)
  If EPMatch(TK_KEYWORD, 'IF') Then
  Begin
    Inc(EP);
    LblEnd := LabelGen;
    LblElse := LabelGen;

    (* Condition *)
    ParseExpr;
    EmitInstrAB('TEST', 'AX', 'AX');
    EmitInstrA('JZ', LblElse);

    (* Passer THEN *)
    If EPMatch(TK_KEYWORD, 'THEN') Then Inc(EP);

    (* Corps du IF *)
    While Not EPAtEnd And
          Not EPMatch(TK_KEYWORD, 'ELSIF') And
          Not EPMatch(TK_KEYWORD, 'ELSE') And
          Not EPMatch(TK_KEYWORD, 'END') Do
      ParseStmt;

    (* ELSIF chains *)
    While EPMatch(TK_KEYWORD, 'ELSIF') Do
    Begin
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblElse);
      LblElse := LabelGen;
      Inc(EP);
      ParseExpr;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblElse);
      If EPMatch(TK_KEYWORD, 'THEN') Then Inc(EP);
      While Not EPAtEnd And
            Not EPMatch(TK_KEYWORD, 'ELSIF') And
            Not EPMatch(TK_KEYWORD, 'ELSE') And
            Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;
    End;

    (* ELSE *)
    If EPMatch(TK_KEYWORD, 'ELSE') Then
    Begin
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblElse);
      LblElse := '';
      Inc(EP);
      While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;
    End;

    If LblElse <> '' Then
      EmitLabel(LblElse);
    EmitLabel(LblEnd);
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- WHILE expr DO ... END --- *)
  (* TODO 14 - Boucle WHILE avec test de condition                  *)
  If EPMatch(TK_KEYWORD, 'WHILE') Then
  Begin
    Inc(EP);
    LblTest := LabelGen;
    LblEnd  := LabelGen;
    EmitLabel(LblTest);
    ParseExpr;
    EmitInstrAB('TEST', 'AX', 'AX');
    EmitInstrA('JZ', LblEnd);
    If EPMatch(TK_KEYWORD, 'DO') Then Inc(EP);
    While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
      ParseStmt;
    EmitInstrA('JMP', LblTest);
    EmitLabel(LblEnd);
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- FOR ident := expr TO expr [BY expr] DO ... END --- *)
  (* TODO 14 - Boucle FOR avec increment optionnel BY               *)
  If EPMatch(TK_KEYWORD, 'FOR') Then
  Begin
    Inc(EP);
    ForVar := '';
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      ForVar := TokenPool[EP].Val;
      Inc(EP);
    End;
    If EPMatch(TK_OP, ':=') Then Inc(EP);

    (* Evaluer start *)
    ParseExpr;

    (* Stocker dans la variable *)
    ForLI  := FindProcLocal(CurProcIdx, ForVar);
    ForParI := -1;
    ForSI  := -1;
    If ForLI < 0 Then ForParI := FindProcParam(CurProcIdx, ForVar);
    If (ForLI < 0) And (ForParI < 0) Then ForSI := SymFind(ForVar);

    If ForLI >= 0 Then
      GenStoreLocal(CurProcIdx, ForLI)
    Else If ForParI >= 0 Then
      GenStoreParam(CurProcIdx, ForParI)
    Else If ForSI >= 0 Then
      GenStoreVar(ForSI);

    (* TO expr *)
    If EPMatch(TK_KEYWORD, 'TO') Then Inc(EP);
    EmitInstrA('PUSH', 'AX');
    ParseExpr;
    EmitInstrA('PUSH', 'AX'); (* sauver limite sur pile *)

    (* BY expr (optionnel) *)
    ByVal := 1;
    If EPMatch(TK_KEYWORD, 'BY') Then
    Begin
      Inc(EP);
      If (EP < TokenCount) And (TokenPool[EP].Kind = TK_INTEGER) Then
      Begin
        ByVal := TokenPool[EP].IntVal;
        Inc(EP);
      End
      Else
      Begin
        ParseExpr;
        EmitComment('BY expr (using AX as step)');
      End;
    End;

    If EPMatch(TK_KEYWORD, 'DO') Then Inc(EP);

    LblTest := LabelGen;
    LblEnd  := LabelGen;
    EmitLabel(LblTest);

    (* Charger la variable et comparer avec la limite *)
    If ForLI >= 0 Then
      GenLoadLocal(CurProcIdx, ForLI)
    Else If ForParI >= 0 Then
      GenLoadParam(CurProcIdx, ForParI)
    Else If ForSI >= 0 Then
      GenLoadVar(ForSI);

    (* Comparer avec la limite (2eme element sur pile) *)
    EmitInstrAB('CMP', 'AX', 'WORD PTR [SP]');
    If ByVal >= 0 Then
      EmitInstrA('JG', LblEnd)
    Else
      EmitInstrA('JL', LblEnd);

    (* Corps du FOR *)
    While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
      ParseStmt;

    (* Incrementer *)
    If ForLI >= 0 Then
      GenLoadLocal(CurProcIdx, ForLI)
    Else If ForParI >= 0 Then
      GenLoadParam(CurProcIdx, ForParI)
    Else If ForSI >= 0 Then
      GenLoadVar(ForSI);

    If ByVal = 1 Then
      EmitInstr('INC     AX')
    Else If ByVal = -1 Then
      EmitInstr('DEC     AX')
    Else
      EmitInstrAB('ADD', 'AX', IntToStr(ByVal));

    If ForLI >= 0 Then
      GenStoreLocal(CurProcIdx, ForLI)
    Else If ForParI >= 0 Then
      GenStoreParam(CurProcIdx, ForParI)
    Else If ForSI >= 0 Then
      GenStoreVar(ForSI);

    EmitInstrA('JMP', LblTest);
    EmitLabel(LblEnd);
    EmitInstrAB('ADD', 'SP', '4'); (* depiler start+limit *)

    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- LOOP ... END (infinite loop, EXIT to break) --- *)
  (* TODO 14 - Boucle infinie avec pile pour EXIT imbrique          *)
  If EPMatch(TK_KEYWORD, 'LOOP') Then
  Begin
    Inc(EP);
    LoopLbl := LabelGen;
    ExitLbl := LabelGen;
    LoopPush(ExitLbl);
    EmitLabel(LoopLbl);
    While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
    Begin
      If EPMatch(TK_KEYWORD, 'EXIT') Then
      Begin
        Inc(EP);
        If LoopExitTop > 0 Then
          EmitInstrA('JMP', LoopExitStack[LoopExitTop - 1])
        Else
          FatalError('EXIT en dehors d''une boucle LOOP');
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      End
      Else
        ParseStmt;
    End;
    EmitInstrA('JMP', LoopLbl);
    EmitLabel(ExitLbl);
    LoopPop;
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- REPEAT ... UNTIL expr --- *)
  (* TODO 14 - Boucle REPEAT/UNTIL avec test de fin                 *)
  If EPMatch(TK_KEYWORD, 'REPEAT') Then
  Begin
    Inc(EP);
    LoopLbl := LabelGen;
    EmitLabel(LoopLbl);
    While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'UNTIL') Do
      ParseStmt;
    If EPMatch(TK_KEYWORD, 'UNTIL') Then Inc(EP);
    ParseExpr;
    EmitInstrAB('TEST', 'AX', 'AX');
    EmitInstrA('JZ', LoopLbl);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- CASE expr OF | val => stmts ... ELSE stmts END --- *)
  (* TODO 13 - Instructions de branchement CASE                    *)
  If EPMatch(TK_KEYWORD, 'CASE') Then
  Begin
    Inc(EP);
    LblEnd := LabelGen;
    EmitComment('CASE');

    (* Evaluer l expression selecteur -> AX *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX');  (* sauver la valeur sur la pile *)

    (* Passer OF *)
    If EPMatch(TK_KEYWORD, 'OF') Then Inc(EP);

    (* Passer | initial optionnel *)
    If EPMatch(TK_PUNCT, '|') Then Inc(EP);

    (* --- Boucle sur les branches | val, val, lo..hi => stmts --- *)
    While Not EPAtEnd And
          Not EPMatch(TK_KEYWORD, 'ELSE') And
          Not EPMatch(TK_KEYWORD, 'END') Do
    Begin
      LblBody := LabelGen;     (* label du corps de cette branche *)
      LblNext := LabelGen;     (* label du test suivant           *)

      (* --- Parser les etiquettes de la branche --- *)
      (* Chaque etiquette : entier, char, ident ou intervalle lo..hi *)
      While Not EPAtEnd And Not EPMatch(TK_OP, '=>') Do
      Begin
        (* Charger la valeur du selecteur depuis la pile *)
        EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');

        (* Detecter un signe negatif *)
        NegSign := False;
        If EPMatch(TK_OP, '-') Then
        Begin
          NegSign := True;
          Inc(EP);
        End;

        CaseVal := '';
        HasRange := False;

        (* Valeur entiere *)
        If (EP < TokenCount) And (TokenPool[EP].Kind = TK_INTEGER) Then
        Begin
          If NegSign Then
            CaseVal := IntToStr(-TokenPool[EP].IntVal)
          Else
            CaseVal := IntToStr(TokenPool[EP].IntVal);
          Inc(EP);
        End
        (* Valeur caractere *)
        Else If (EP < TokenCount) And (TokenPool[EP].Kind = TK_CHAR) Then
        Begin
          CaseVal := IntToStr(TokenPool[EP].IntVal);
          Inc(EP);
        End
        (* Identifiant (constante nommee) *)
        Else If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
        Begin
          SI := SymFind(TokenPool[EP].Val);
          If (SI >= 0) And (SymTab[SI].Kind = SK_CONST) Then
            CaseVal := IntToStr(SymTab[SI].ImmVal)
          Else
            CaseVal := '0';
          Inc(EP);
        End
        Else
        Begin
          (* Token inconnu dans les etiquettes CASE, avancer *)
          Inc(EP);
          If EPMatch(TK_PUNCT, ',') Then Inc(EP);
          Continue;
        End;

        (* Verifier s il y a un intervalle .. *)
        If EPMatch(TK_OP, '..') Then
        Begin
          HasRange := True;
          Inc(EP);
          HiVal := '';
          NegSign := False;
          If EPMatch(TK_OP, '-') Then
          Begin
            NegSign := True;
            Inc(EP);
          End;
          If (EP < TokenCount) And (TokenPool[EP].Kind = TK_INTEGER) Then
          Begin
            If NegSign Then
              HiVal := IntToStr(-TokenPool[EP].IntVal)
            Else
              HiVal := IntToStr(TokenPool[EP].IntVal);
            Inc(EP);
          End
          Else If (EP < TokenCount) And (TokenPool[EP].Kind = TK_CHAR) Then
          Begin
            HiVal := IntToStr(TokenPool[EP].IntVal);
            Inc(EP);
          End
          Else If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
          Begin
            SI := SymFind(TokenPool[EP].Val);
            If (SI >= 0) And (SymTab[SI].Kind = SK_CONST) Then
              HiVal := IntToStr(SymTab[SI].ImmVal)
            Else
              HiVal := '0';
            Inc(EP);
          End
          Else
            HiVal := CaseVal;
        End;

        (* Emettre le code de comparaison *)
        If HasRange Then
        Begin
          (* Intervalle lo..hi : CMP AX, lo / JL next / CMP AX, hi / JG next *)
          EmitInstrAB('CMP', 'AX', CaseVal);
          EmitInstrA('JL', LblNext);
          EmitInstrAB('CMP', 'AX', HiVal);
          EmitInstrA('JLE', LblBody);
        End
        Else
        Begin
          (* Valeur simple : CMP AX, val / JE body *)
          EmitInstrAB('CMP', 'AX', CaseVal);
          EmitInstrA('JE', LblBody);
        End;

        (* Separateur virgule entre etiquettes *)
        If EPMatch(TK_PUNCT, ',') Then Inc(EP);
      End;

      (* Aucune etiquette n a correspondu -> sauter au test suivant *)
      EmitInstrA('JMP', LblNext);

      (* --- Corps de la branche --- *)
      EmitLabel(LblBody);
      If EPMatch(TK_OP, '=>') Then Inc(EP);

      While Not EPAtEnd And
            Not EPMatch(TK_PUNCT, '|') And
            Not EPMatch(TK_KEYWORD, 'ELSE') And
            Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;

      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);

      (* Passer | avant la branche suivante *)
      If EPMatch(TK_PUNCT, '|') Then Inc(EP);
    End;

    (* --- ELSE (branche par defaut) --- *)
    If EPMatch(TK_KEYWORD, 'ELSE') Then
    Begin
      Inc(EP);
      While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;
    End;

    EmitLabel(LblEnd);
    EmitInstrAB('ADD', 'SP', '2');  (* depiler la valeur du selecteur *)
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- TRY ... EXCEPT / FINALLY ... END (stub: skip) --- *)
  If EPMatch(TK_KEYWORD, 'TRY') Then
  Begin
    EmitComment('TRY (stub: skipping)');
    Inc(EP);
    SkipToMatchingEnd(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- WITH id = expr DO stmts END - TODO 16 --- *)
  If EPMatch(TK_KEYWORD, 'WITH') Then
  Begin
    Inc(EP);
    EmitComment('WITH');
    WithVar := '';
    (* Parser : ident = expr *)
    If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
    Begin
      WithVar := TokenPool[EP].Val;
      Inc(EP);
    End;
    (* Passer '=' *)
    If EPMatch(TK_OP, '=') Then Inc(EP);
    (* Evaluer l expression -> AX contient la valeur/adresse *)
    ParseExpr;
    (* Stocker le resultat dans une variable temporaire sur la pile *)
    EmitInstrA('PUSH', 'AX');
    EmitComment('WITH ' + WithVar + ' saved on stack');
    (* Passer DO *)
    If EPMatch(TK_KEYWORD, 'DO') Then Inc(EP);
    (* Parser les instructions du bloc WITH *)
    While Not EPAtEnd And
          Not EPMatch(TK_KEYWORD, 'END') Do
    Begin
      ParseStmt;
    End;
    (* Restaurer la pile *)
    EmitInstrAB('ADD', 'SP', '2');
    EmitComment('END WITH');
    (* Passer END *)
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- TYPECASE expr OF | Type(v) => stmts ... ELSE stmts END --- *)
  (* TODO 13 - TYPECASE : dispatch sur le type dynamique             *)
  (* Note: necessite le systeme OOP (TODO 21). Implementation        *)
  (* basique : evalue l expression, puis pour chaque branche de type *)
  (* emet un test TYPECODE. Seul ELSE est garanti d etre execute     *)
  (* tant que le systeme OOP n est pas complet.                      *)
  If EPMatch(TK_KEYWORD, 'TYPECASE') Then
  Begin
    Inc(EP);
    LblEnd := LabelGen;
    EmitComment('TYPECASE');

    (* Evaluer l expression de type -> AX *)
    ParseExpr;
    EmitInstrA('PUSH', 'AX');  (* sauver la reference sur la pile *)

    (* Passer OF *)
    If EPMatch(TK_KEYWORD, 'OF') Then Inc(EP);

    (* Passer | initial optionnel *)
    If EPMatch(TK_PUNCT, '|') Then Inc(EP);

    (* --- Branches | Type(var) => stmts --- *)
    While Not EPAtEnd And
          Not EPMatch(TK_KEYWORD, 'ELSE') And
          Not EPMatch(TK_KEYWORD, 'END') Do
    Begin
      LblBody := LabelGen;
      LblNext := LabelGen;

      (* Parser le nom de type et la variable optionnelle *)
      Name := '';
      If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        Name := TokenPool[EP].Val;
        Inc(EP);
      End;

      (* Type(var) - variable liee optionnelle *)
      If EPMatch(TK_PUNCT, '(') Then
      Begin
        Inc(EP);
        If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
          Inc(EP);  (* passer le nom de variable *)
        If EPMatch(TK_PUNCT, ')') Then Inc(EP);
      End;

      (* Emettre test de type via TYPECODE *)
      EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');
      SI := SymFind(Name);
      If SI >= 0 Then
      Begin
        EmitComment('TYPECASE test: ' + Name);
        EmitInstrAB('CMP', 'AX', IntToStr(SymTab[SI].TypeIdx));
        EmitInstrA('JE', LblBody);
      End
      Else
      Begin
        EmitComment('TYPECASE test: ' + Name + ' (type inconnu)');
      End;

      EmitInstrA('JMP', LblNext);

      (* Corps de la branche *)
      EmitLabel(LblBody);
      If EPMatch(TK_OP, '=>') Then Inc(EP);

      While Not EPAtEnd And
            Not EPMatch(TK_PUNCT, '|') And
            Not EPMatch(TK_KEYWORD, 'ELSE') And
            Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;

      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);

      If EPMatch(TK_PUNCT, '|') Then Inc(EP);
    End;

    (* ELSE *)
    If EPMatch(TK_KEYWORD, 'ELSE') Then
    Begin
      Inc(EP);
      While Not EPAtEnd And Not EPMatch(TK_KEYWORD, 'END') Do
        ParseStmt;
    End;

    EmitLabel(LblEnd);
    EmitInstrAB('ADD', 'SP', '2');
    If EPMatch(TK_KEYWORD, 'END') Then Inc(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- LOCK (stub: skip) --- *)
  If EPMatch(TK_KEYWORD, 'LOCK') Then
  Begin
    EmitComment('LOCK (stub: skipping)');
    Inc(EP);
    SkipToMatchingEnd(EP);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* --- Identifiant : affectation ou appel de procedure --- *)
  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    Name := TokenPool[EP].Val;
    Inc(EP);

    (* Acces qualifie Module.Method(...) ou Record.Field := expr *)
    If EPMatch(TK_PUNCT, '.') Then
    Begin
      SI := SymFind(Name);
      If (SI >= 0) And (SymTab[SI].Kind = SK_MODULE) Then
      Begin
        ParseQualifiedIdent(Name);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;
      (* record.field := expr OR obj.field := expr OR obj.method() *)
      RecTIdx := TY_UNKNOWN;
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
      Begin
        RecTIdx := ProcTab[CurProcIdx].Locals[LI].TypeIdx;
      End
      Else
      Begin
        ParI := FindProcParam(CurProcIdx, Name);
        If ParI >= 0 Then
          RecTIdx := ProcTab[CurProcIdx].ParamTypes[ParI]
        Else
        Begin
          SI := SymFind(Name);
          If SI >= 0 Then
            RecTIdx := SymTab[SI].TypeIdx;
        End;
      End;
      Inc(EP); (* passer '.' *)
      FldName := '';
      If (EP < TokenCount) And (TokenPool[EP].Kind = TK_IDENT) Then
      Begin
        FldName := TokenPool[EP].Val;
        Inc(EP);
      End;
      (* Verifier si c est un type objet - TODO 19 *)
      ObjI := -1;
      If (RecTIdx >= 0) And (RecTIdx < TypeCount) And
         (TypeTab[RecTIdx].Kind = TYK_OBJECT) Then
        ObjI := ObjTypeFindByTypeIdx(RecTIdx);
      If (ObjI >= 0) Then
      Begin
        (* Chercher d abord une methode *)
        MI := ObjTypeMethodFind(ObjI, FldName);
        If MI >= 0 Then
        Begin
          (* Appel de methode : obj.method(args) *)
          (* Charger ptr objet dans BX et empiler self *)
          LI := FindProcLocal(CurProcIdx, Name);
          If LI >= 0 Then
            EmitInstrAB('MOV', 'BX', 'WORD PTR [BP' +
              IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']')
          Else
          Begin
            ParI := FindProcParam(CurProcIdx, Name);
            If ParI >= 0 Then
              EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
                IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']')
            Else
            Begin
              SI := SymFind(Name);
              If SI >= 0 Then
                EmitInstrAB('MOV', 'BX', SymTab[SI].MangledName);
            End;
          End;
          EmitInstrA('PUSH', 'BX'); (* self *)
          ArgCount := 0;
          If EPMatch(TK_PUNCT, '(') Then
          Begin
            Inc(EP);
            While Not EPAtEnd And Not EPMatch(TK_PUNCT, ')') Do
            Begin
              ParseExpr;
              EmitInstrA('PUSH', 'AX');
              Inc(ArgCount);
              If EPMatch(TK_PUNCT, ',') Then Inc(EP);
            End;
            If EPMatch(TK_PUNCT, ')') Then Inc(EP);
          End;
          (* Recuperer self pour vtable dispatch *)
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
            IntToStr(4 + ArgCount * 2) + ']');
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BX]');
          EmitInstr('CALL    WORD PTR [BX+' +
            IntToStr(2 + ObjTypeTab[ObjI].Methods[MI].VTSlot * 2) + ']');
          If ArgCount + 1 > 0 Then
            EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
          If EPMatch(TK_PUNCT, ';') Then Inc(EP);
          Exit;
        End;
        (* Sinon affectation champ objet *)
        FldI := ObjTypeFieldFind(ObjI, FldName);
        If EPMatch(TK_OP, ':=') Then
        Begin
          Inc(EP);
          ParseExpr;
          EmitInstrA('PUSH', 'AX');
          (* Charger le pointeur objet dans BX *)
          LI := FindProcLocal(CurProcIdx, Name);
          If LI >= 0 Then
            EmitInstrAB('MOV', 'BX', 'WORD PTR [BP' +
              IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']')
          Else
          Begin
            ParI := FindProcParam(CurProcIdx, Name);
            If ParI >= 0 Then
              EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
                IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']')
            Else
            Begin
              SI := SymFind(Name);
              If SI >= 0 Then
                EmitInstrAB('MOV', 'BX', SymTab[SI].MangledName);
            End;
          End;
          If FldI >= 0 Then
          Begin
            FldOfs := ObjTypeTab[ObjI].Fields[FldI].Offset + 2;
            FldSz  := TypeSizeFromIdx(
                        ObjTypeTab[ObjI].Fields[FldI].TypeIdx);
            If FldOfs > 0 Then
              EmitInstrAB('ADD', 'BX', IntToStr(FldOfs));
            EmitInstrA('POP', 'AX');
            If FldSz <= 1 Then
              EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
            Else
              EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
          End
          Else
          Begin
            EmitInstrA('POP', 'AX');
            EmitComment('unknown obj field: ' + FldName);
          End;
        End;
      End
      Else If EPMatch(TK_OP, ':=') Then
      Begin
        Inc(EP);
        ParseExpr;
        (* AX contient la valeur a stocker *)
        EmitInstrA('PUSH', 'AX'); (* sauver la valeur *)
        (* Charger l adresse de base du record dans BX *)
        LI := FindProcLocal(CurProcIdx, Name);
        If LI >= 0 Then
          EmitInstrAB('LEA', 'BX', '[BP' +
            IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']')
        Else
        Begin
          ParI := FindProcParam(CurProcIdx, Name);
          If ParI >= 0 Then
            EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
              IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']')
          Else
          Begin
            SI := SymFind(Name);
            If SI >= 0 Then
              EmitInstrAB('LEA', 'BX', SymTab[SI].MangledName);
          End;
        End;
        (* Calculer l offset du champ *)
        FldI := RecordFieldFind(RecTIdx, FldName);
        If FldI >= 0 Then
        Begin
          FldOfs := TypeTab[RecTIdx].Fields[FldI].Offset;
          FldSz  := TypeSizeFromIdx(
                      TypeTab[RecTIdx].Fields[FldI].TypeIdx);
          If FldOfs > 0 Then
            EmitInstrAB('ADD', 'BX', IntToStr(FldOfs));
          EmitInstrA('POP', 'AX');
          If FldSz <= 1 Then
            EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
          Else
            EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
        End
        Else
        Begin
          EmitInstrA('POP', 'AX');
          EmitComment('unknown field: ' + FldName);
        End;
      End;
      If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      Exit;
    End;

    (* Affectation :=  ident := expr *)
    If EPMatch(TK_OP, ':=') Then
    Begin
      Inc(EP);
      ParseExpr;

      (* Stocker le resultat *)
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
      Begin
        GenStoreLocal(CurProcIdx, LI);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      ParI := FindProcParam(CurProcIdx, Name);
      If ParI >= 0 Then
      Begin
        GenStoreParam(CurProcIdx, ParI);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      SI := SymFind(Name);
      If SI >= 0 Then
      Begin
        GenStoreVar(SI);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      EmitComment('assign to unknown: ' + Name);
      If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      Exit;
    End;

    (* Deref assign: ident^ := expr *)
    If EPMatch(TK_PUNCT, '^') Then
    Begin
      Inc(EP);
      If EPMatch(TK_OP, ':=') Then
      Begin
        Inc(EP);
        (* Load pointer *)
        LI := FindProcLocal(CurProcIdx, Name);
        If LI >= 0 Then
          GenLoadLocal(CurProcIdx, LI)
        Else
        Begin
          ParI := FindProcParam(CurProcIdx, Name);
          If ParI >= 0 Then
            GenLoadParam(CurProcIdx, ParI)
          Else
          Begin
            SI := SymFind(Name);
            If SI >= 0 Then GenLoadVar(SI);
          End;
        End;
        EmitInstrA('PUSH', 'AX'); (* save pointer *)
        ParseExpr;
        EmitInstrA('POP', 'BX');
        EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
      End;
      If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      Exit;
    End;

    (* Index assign: ident[i] := expr - TODO 15 *)
    If EPMatch(TK_PUNCT, '[') Then
    Begin
      ArrTIdx := TY_UNKNOWN;
      LI := FindProcLocal(CurProcIdx, Name);
      If LI >= 0 Then
      Begin
        ArrTIdx := ProcTab[CurProcIdx].Locals[LI].TypeIdx;
        EmitInstrAB('LEA', 'BX', '[BP' +
          IntToStr(ProcTab[CurProcIdx].Locals[LI].Offset) + ']');
      End
      Else
      Begin
        ParI := FindProcParam(CurProcIdx, Name);
        If ParI >= 0 Then
        Begin
          ArrTIdx := ProcTab[CurProcIdx].ParamTypes[ParI];
          EmitInstrAB('MOV', 'BX', 'WORD PTR [BP+' +
            IntToStr(ProcTab[CurProcIdx].ParamOfs[ParI]) + ']');
        End
        Else
        Begin
          SI := SymFind(Name);
          If SI >= 0 Then
          Begin
            ArrTIdx := SymTab[SI].TypeIdx;
            EmitInstrAB('LEA', 'BX', SymTab[SI].MangledName);
          End;
        End;
      End;
      ArrElemSz := 2;
      ArrLo := 0;
      If (ArrTIdx >= 0) And (ArrTIdx < TypeCount) And
         (TypeTab[ArrTIdx].Kind = TYK_ARRAY) Then
      Begin
        ArrElemSz := TypeSizeFromIdx(TypeTab[ArrTIdx].BaseTypeIdx);
        ArrLo     := TypeTab[ArrTIdx].Lo;
      End;
      EmitInstrA('PUSH', 'BX');
      Inc(EP); (* passer '[' *)
      ParseExpr;
      If ArrLo <> 0 Then
        EmitInstrAB('SUB', 'AX', IntToStr(ArrLo));
      If ArrElemSz = 2 Then
        EmitInstrAB('SHL', 'AX', '1')
      Else If ArrElemSz = 4 Then
        EmitInstrAB('SHL', 'AX', '2')
      Else If ArrElemSz <> 1 Then
      Begin
        EmitInstrAB('MOV', 'CX', IntToStr(ArrElemSz));
        EmitInstrA('MUL', 'CX');
      End;
      EmitInstrA('POP', 'BX');
      EmitInstrAB('ADD', 'BX', 'AX');
      EmitInstrA('PUSH', 'BX');
      If EPMatch(TK_PUNCT, ']') Then Inc(EP);
      If EPMatch(TK_OP, ':=') Then
      Begin
        Inc(EP);
        ParseExpr;
        EmitInstrA('POP', 'BX');
        If ArrElemSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
        Else
          EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
      End;
      If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      Exit;
    End;

    (* Appel de procedure/builtin avec '(' *)
    If EPMatch(TK_PUNCT, '(') Then
    Begin
      (* Appels builtin statement-level *)
      If (Name = 'INC') Or (Name = 'DEC') Or
         (Name = 'DISPOSE') Or (Name = 'EVAL') Then
      Begin
        ParseProcCallStmt(Name);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      (* Builtin functions called as statements *)
      If (Name = 'NEW') Then
      Begin
        ParseBuiltinCall(Name);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      (* Appel de procedure utilisateur *)
      PI2 := FindProcByName(Name);
      If PI2 >= 0 Then
      Begin
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    ' + ProcTab[PI2].MangledName);
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      (* TODO 17 - Appel indirect via variable de type PROCEDURE *)
      LI := FindProcLocal(CurProcIdx, Name);
      If (LI >= 0) And
         (TypeTab[ProcTab[CurProcIdx].Locals[LI].TypeIdx].Kind = TYK_PROC) Then
      Begin
        GenLoadLocal(CurProcIdx, LI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;
      ParI := FindProcParam(CurProcIdx, Name);
      If (ParI >= 0) And
         (TypeTab[ProcTab[CurProcIdx].ParamTypes[ParI]].Kind = TYK_PROC) Then
      Begin
        GenLoadParam(CurProcIdx, ParI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;
      SI := SymFind(Name);
      If (SI >= 0) And (SymTab[SI].Kind = SK_VAR) And
         (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_PROC) Then
      Begin
        GenLoadVar(SI);
        EmitInstrAB('MOV', 'BX', 'AX');
        ParseCallArgs(ArgCount);
        EmitInstr('CALL    BX');
        If EPMatch(TK_PUNCT, ';') Then Inc(EP);
        Exit;
      End;

      (* Appel inconnu *)
      ParseCallArgs(ArgCount);
      EmitComment('call ' + Name + ' (unresolved)');
      If EPMatch(TK_PUNCT, ';') Then Inc(EP);
      Exit;
    End;

    (* Identifiant seul -> expression evaluee et resultat ignore *)
    EmitComment('expr stmt: ' + Name);
    If EPMatch(TK_PUNCT, ';') Then Inc(EP);
    Exit;
  End;

  (* Token inattendu -> avancer *)
  Inc(EP);
End;

(* ---- ParseBody : parser le corps d une procedure --------------- *)
(* Configure le curseur EP, cree le label de retour, et itere      *)
(* ParseStmt pour chaque instruction du corps.                      *)

Procedure ParseBody(PI : Integer);
Begin
  If ProcTab[PI].BodyStart < 0 Then Exit;
  If ProcTab[PI].BodyEnd < 0 Then Exit;

  CurProcIdx := PI;
  EP    := ProcTab[PI].BodyStart;
  EPEnd := ProcTab[PI].BodyEnd;
  RetLbl := LabelGen;

  While Not EPAtEnd Do
    ParseStmt;

  EmitLabel(RetLbl);
End;

(* ============================================================
   TODO 17 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseNestedProc : parser une procedure imbriquee --------- *)
(* Cree une procedure aplatie dans ProcTab avec un nom mange       *)
(* (parent_inner) et un lien statique vers le cadre parent.        *)

Procedure ParseNestedProc(Var P : Integer;
                          ParentPI : Integer;
                          Const ParentName : TString);
Var
  NPI       : Integer;
  NPName    : TString;
  Mode      : TParamMode;
  NPC       : Integer;
  NParamOfs : Integer;
  NPTIdx    : Integer;
  NLCount   : Integer;
  NLSize    : Integer;
  NLTIdx    : Integer;
  NLName    : TString;
  NBodyOpen : Integer;
  NRetTIdx  : Integer;
  NIsFn     : Boolean;
  NSI       : Integer;
Begin
  If (P >= TokenCount) Or
     Not ((TokenPool[P].Kind = TK_KEYWORD) And
          (TokenPool[P].Val = 'PROCEDURE')) Then
    Exit;

  Inc(P); (* passer PROCEDURE *)

  If (P >= TokenCount) Or (TokenPool[P].Kind <> TK_IDENT) Then
  Begin
    Inc(P);
    Exit;
  End;

  NPName := TokenPool[P].Val;
  Inc(P);

  If ProcCount >= MAX_PROC Then
  Begin
    Inc(P);
    Exit;
  End;

  NPI := ProcCount;
  Inc(ProcCount);

  ProcTab[NPI].Name       := NPName;
  ProcTab[NPI].MangledName:= M3_PROC_PFX + SymNameClean(ParentName) +
                             '_' + SymNameClean(NPName);
  ProcTab[NPI].RetTypeIdx := TY_IDX_VOID;
  ProcTab[NPI].IsFunction := False;
  ProcTab[NPI].ParamCount := 0;
  ProcTab[NPI].LocalCount := 0;
  ProcTab[NPI].LocalSize  := 0;
  ProcTab[NPI].BodyStart  := -1;
  ProcTab[NPI].BodyEnd    := -1;
  ProcTab[NPI].SymIdx     := -1;
  ProcTab[NPI].NestLevel  := ProcTab[ParentPI].NestLevel + 1;
  ProcTab[NPI].ParentIdx  := ParentPI;

  NSI := SymAdd(NPName, SK_PROC, TY_IDX_VOID, NPI);
  If NSI >= 0 Then
  Begin
    SymTab[NSI].MangledName := ProcTab[NPI].MangledName;
    ProcTab[NPI].SymIdx     := NSI;
  End;

  (* ---- Parser les parametres ---- *)
  NPC       := 0;
  NParamOfs := 6;

  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '(') Then
  Begin
    Inc(P);
    While (P < TokenCount) And Not
          ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ')')) Do
    Begin
      Mode := PM_VALUE;
      If (TokenPool[P].Kind = TK_KEYWORD) And
         (TokenPool[P].Val = 'VAR') Then
      Begin Mode := PM_VAR; Inc(P); End
      Else If (TokenPool[P].Kind = TK_KEYWORD) And
              (TokenPool[P].Val = 'READONLY') Then
      Begin Mode := PM_READONLY; Inc(P); End
      Else If (TokenPool[P].Kind = TK_KEYWORD) And
              (TokenPool[P].Val = 'VALUE') Then
      Begin Mode := PM_VALUE; Inc(P); End;

      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        If NPC < MAX_PARAM Then
        Begin
          ProcTab[NPI].ParamNames[NPC] := TokenPool[P].Val;
          ProcTab[NPI].ParamModes[NPC] := Mode;
        End;
        Inc(P);

        NPTIdx := TY_IDX_INTEGER;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P);
          If (P < TokenCount) And
             ((TokenPool[P].Kind = TK_KEYWORD) Or
              (TokenPool[P].Kind = TK_IDENT)) Then
          Begin
            NPTIdx := TypeIdxFromName(TokenPool[P].Val);
            If NPTIdx = TY_UNKNOWN Then NPTIdx := TY_IDX_INTEGER;
            Inc(P);
          End;
        End;

        If NPC < MAX_PARAM Then
        Begin
          ProcTab[NPI].ParamTypes[NPC] := NPTIdx;
          ProcTab[NPI].ParamOfs[NPC]   := NParamOfs;
          Inc(NParamOfs, 2);
        End;
        Inc(NPC);
      End;

      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         ((TokenPool[P].Val = ';') Or (TokenPool[P].Val = ',')) Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ')') Then
      Inc(P);
  End;
  ProcTab[NPI].ParamCount := NPC;

  (* ---- Type retour ---- *)
  NRetTIdx := TY_IDX_VOID;
  NIsFn    := False;
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ':') Then
  Begin
    Inc(P);
    If (P < TokenCount) And
       ((TokenPool[P].Kind = TK_KEYWORD) Or
        (TokenPool[P].Kind = TK_IDENT)) Then
    Begin
      NRetTIdx := TypeIdxFromName(TokenPool[P].Val);
      If NRetTIdx = TY_UNKNOWN Then NRetTIdx := TY_IDX_INTEGER;
      NIsFn := True;
      Inc(P);
    End;
  End;
  ProcTab[NPI].RetTypeIdx := NRetTIdx;
  ProcTab[NPI].IsFunction := NIsFn;

  (* Passer '=' *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
     (TokenPool[P].Val = '=') Then
    Inc(P);
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  (* ---- Variables locales ---- *)
  NLCount := 0;
  NLSize  := 0;
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'VAR') Then
  Begin
    Inc(P);
    While (P < TokenCount) And Not
          ((TokenPool[P].Kind = TK_KEYWORD) And
           ((TokenPool[P].Val = 'BEGIN') Or
            (TokenPool[P].Val = 'PROCEDURE'))) Do
    Begin
      If TokenPool[P].Kind = TK_IDENT Then
      Begin
        NLName := TokenPool[P].Val;
        Inc(P);
        NLTIdx := TY_IDX_INTEGER;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P);
          If (P < TokenCount) And
             ((TokenPool[P].Kind = TK_KEYWORD) Or
              (TokenPool[P].Kind = TK_IDENT)) Then
          Begin
            NLTIdx := TypeIdxFromName(TokenPool[P].Val);
            If NLTIdx = TY_UNKNOWN Then NLTIdx := TY_IDX_INTEGER;
            Inc(P);
          End;
        End;
        If NLCount < MAX_LOCAL Then
        Begin
          Inc(NLSize, TypeSizeFromIdx(NLTIdx));
          ProcTab[NPI].Locals[NLCount].Name    := NLName;
          ProcTab[NPI].Locals[NLCount].TypeIdx := NLTIdx;
          ProcTab[NPI].Locals[NLCount].Size    := TypeSizeFromIdx(NLTIdx);
          ProcTab[NPI].Locals[NLCount].Offset  := -NLSize;
          Inc(NLCount);
        End;
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else
        Inc(P);
    End;
  End;
  ProcTab[NPI].LocalCount := NLCount;
  If (NLSize Mod 2) = 1 Then Inc(NLSize);
  ProcTab[NPI].LocalSize  := NLSize;

  (* ---- Corps BEGIN ... END ---- *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (TokenPool[P].Val = 'BEGIN') Then
  Begin
    Inc(P);
    NBodyOpen := P;
    SkipToMatchingEnd(P);
    ProcTab[NPI].BodyStart := NBodyOpen;
    ProcTab[NPI].BodyEnd   := P - 1;
  End;

  (* Passer le nom apres END *)
  If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Inc(P);
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  If Opts.DebugMode Then
    WriteLn('  NESTED_PROC[', NPI, ']: ', ParentName, '.', NPName,
            ' params=', NPC, ' locals=', NLCount,
            ' body=', ProcTab[NPI].BodyStart, '..',
            ProcTab[NPI].BodyEnd);
End;

(* ============================================================
   TODO 09 (suite) - ParseProcDecls
   ============================================================ *)

(* ---- ParseProcDecls : scanner PROCEDURE au niveau MODULE ------ *)
(* Parcourt le TokenPool pour trouver les declarations PROCEDURE.  *)
(* Pour chaque procedure, collecte les parametres (VALUE/VAR/      *)
(* READONLY), les variables locales (VAR dans le corps), et        *)
(* memorise les bornes du corps (entre BEGIN et END).               *)

Procedure ParseProcDecls;
Var
  P          : Integer;
  PI         : Integer;   (* index dans ProcTab *)
  PName      : TString;
  Mode       : TParamMode;
  PCount     : Integer;
  ParamOfs   : Integer;
  PTIdx      : Integer;
  LCount     : Integer;
  LSize      : Integer;
  LTIdx      : Integer;
  LName      : TString;
  BodyOpen   : Integer;
  RetTIdx    : Integer;
  IsFn       : Boolean;
  SI         : Integer;
Begin
  ProcCount := 0;

  P := 0;
  While P < TokenCount Do
  Begin
    (* Chercher le mot-cle PROCEDURE au niveau global *)
    If Not ((TokenPool[P].Kind = TK_KEYWORD) And
            (TokenPool[P].Val = 'PROCEDURE')) Then
    Begin
      Inc(P);
      Continue;
    End;

    (* On ne traite que les PROCEDURE au niveau module *)
    (* (pas celles imbriquees dans un corps BEGIN..END) *)
    Inc(P); (* passer PROCEDURE *)

    (* Nom de la procedure *)
    If (P >= TokenCount) Or (TokenPool[P].Kind <> TK_IDENT) Then
    Begin
      Inc(P);
      Continue;
    End;
    PName := TokenPool[P].Val;
    Inc(P);

    If ProcCount >= MAX_PROC Then
    Begin
      CompileError('trop de procedures (max=' + IntToStr(MAX_PROC) + ')');
      Break;
    End;
    PI := ProcCount;
    Inc(ProcCount);

    ProcTab[PI].Name       := PName;
    ProcTab[PI].MangledName:= M3_PROC_PFX + SymNameClean(PName);
    ProcTab[PI].RetTypeIdx := TY_IDX_VOID;
    ProcTab[PI].IsFunction := False;
    ProcTab[PI].ParamCount := 0;
    ProcTab[PI].LocalCount := 0;
    ProcTab[PI].LocalSize  := 0;
    ProcTab[PI].BodyStart  := -1;
    ProcTab[PI].BodyEnd    := -1;
    ProcTab[PI].SymIdx     := -1;
    ProcTab[PI].NestLevel  := 0;
    ProcTab[PI].ParentIdx  := -1;

    (* Enregistrer le symbole de la procedure *)
    SI := SymAdd(PName, SK_PROC, TY_IDX_VOID, PI);
    If SI >= 0 Then
    Begin
      SymTab[SI].MangledName := ProcTab[PI].MangledName;
      ProcTab[PI].SymIdx     := SI;
      (* Marquer comme exportee si INTERFACE ou MODULE EXPORTS - TODO 18 *)
      If Opts.IsIface Or (ExportsName <> '') Then
        SymTab[SI].IsExported := True;
    End;

    (* ---- Parser la liste de parametres '(' ... ')' ---- *)
    PCount   := 0;
    ParamOfs := 4; (* [BP+4] = adresse retour, [BP+6] = 1er param *)
    (* En convention Pascal 8086 : params empiles gauche->droite *)
    (* mais on fixe [BP+4]=retaddr, [BP+6..] = params            *)
    ParamOfs := 6;

    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P); (* passer '(' *)
      SymEnterScope; (* portee des parametres *)

      While (P < TokenCount) And Not
            ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ')')) Do
      Begin
        (* Detecter le mode de passage *)
        Mode := PM_VALUE; (* defaut : VALUE *)
        If (TokenPool[P].Kind = TK_KEYWORD) And
           (TokenPool[P].Val = 'VAR') Then
        Begin
          Mode := PM_VAR;
          Inc(P);
        End
        Else If (TokenPool[P].Kind = TK_KEYWORD) And
                (TokenPool[P].Val = 'READONLY') Then
        Begin
          Mode := PM_READONLY;
          Inc(P);
        End
        Else If (TokenPool[P].Kind = TK_KEYWORD) And
                (TokenPool[P].Val = 'VALUE') Then
        Begin
          Mode := PM_VALUE;
          Inc(P);
        End;

        (* Nom du parametre *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          If PCount < MAX_PARAM Then
          Begin
            ProcTab[PI].ParamNames[PCount] := TokenPool[P].Val;
            ProcTab[PI].ParamModes[PCount] := Mode;
          End;
          Inc(P);

          (* ':' Type *)
          PTIdx := TY_IDX_INTEGER;
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ':') Then
          Begin
            Inc(P); (* passer ':' *)
            If (P < TokenCount) And
               ((TokenPool[P].Kind = TK_KEYWORD) Or
                (TokenPool[P].Kind = TK_IDENT)) Then
            Begin
              PTIdx := TypeIdxFromName(TokenPool[P].Val);
              If PTIdx = TY_UNKNOWN Then
                PTIdx := TY_IDX_INTEGER;
              Inc(P);
            End;
          End;

          If PCount < MAX_PARAM Then
          Begin
            ProcTab[PI].ParamTypes[PCount] := PTIdx;
            ProcTab[PI].ParamOfs[PCount]   := ParamOfs;
            (* En 8086, chaque param occupe 2 octets sur la pile *)
            Inc(ParamOfs, 2);

            (* Enregistrer le parametre dans SymTab *)
            SI := SymAdd(ProcTab[PI].ParamNames[PCount],
                         SK_PARAM, PTIdx, ProcTab[PI].ParamOfs[PCount]);
            If SI >= 0 Then
            Begin
              If Mode = PM_READONLY Then
                SymTab[SI].IsReadonly := True;
            End;
          End;
          Inc(PCount);
        End;

        (* Separateur ';' ou ',' entre parametres *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           ((TokenPool[P].Val = ';') Or (TokenPool[P].Val = ',')) Then
          Inc(P);
      End; (* while not ')' *)

      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ')') Then
        Inc(P); (* passer ')' *)

      SymLeaveScope; (* quitter la portee des parametres *)
    End;
    ProcTab[PI].ParamCount := PCount;

    (* ---- Type retour ': Type' apres ')' => c est une fonction --- *)
    RetTIdx := TY_IDX_VOID;
    IsFn    := False;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); (* passer ':' *)
      If (P < TokenCount) And
         ((TokenPool[P].Kind = TK_KEYWORD) Or
          (TokenPool[P].Kind = TK_IDENT)) Then
      Begin
        RetTIdx := TypeIdxFromName(TokenPool[P].Val);
        If RetTIdx = TY_UNKNOWN Then
          RetTIdx := TY_IDX_INTEGER;
        IsFn := True;
        Inc(P);
      End;
    End;
    ProcTab[PI].RetTypeIdx := RetTIdx;
    ProcTab[PI].IsFunction := IsFn;
    If (ProcTab[PI].SymIdx >= 0) Then
      SymTab[ProcTab[PI].SymIdx].TypeIdx := RetTIdx;

    (* Passer '=' si present (pour corps inline) *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
       (TokenPool[P].Val = '=') Then
      Inc(P);

    (* Passer ';' apres la signature *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);

    (* ---- Variables locales (VAR avant BEGIN) ---- *)
    LCount := 0;
    LSize  := 0;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'VAR') Then
    Begin
      Inc(P); (* passer VAR *)
      (* Lire les declarations locales : ident : Type; *)
      While (P < TokenCount) And Not
            ((TokenPool[P].Kind = TK_KEYWORD) And
             ((TokenPool[P].Val = 'BEGIN') Or
              (TokenPool[P].Val = 'CONST') Or
              (TokenPool[P].Val = 'VAR') Or
              (TokenPool[P].Val = 'PROCEDURE'))) Do
      Begin
        If TokenPool[P].Kind = TK_IDENT Then
        Begin
          LName := TokenPool[P].Val;
          Inc(P);
          LTIdx := TY_IDX_INTEGER;
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ':') Then
          Begin
            Inc(P); (* passer ':' *)
            If (P < TokenCount) And
               (TokenPool[P].Kind = TK_KEYWORD) And
               (TokenPool[P].Val = 'ARRAY') Then
            Begin
              LTIdx := ParseArrayTypeFromTokens(P);
              If LTIdx = TY_UNKNOWN Then
                LTIdx := TY_IDX_INTEGER;
            End
            Else If (P < TokenCount) And
               ((TokenPool[P].Kind = TK_KEYWORD) Or
                (TokenPool[P].Kind = TK_IDENT)) Then
            Begin
              LTIdx := TypeIdxFromName(TokenPool[P].Val);
              If LTIdx = TY_UNKNOWN Then
                LTIdx := TY_IDX_INTEGER;
              Inc(P);
            End;
          End;

          (* Creer la variable locale *)
          If LCount < MAX_LOCAL Then
          Begin
            Inc(LSize, TypeSizeFromIdx(LTIdx));
            ProcTab[PI].Locals[LCount].Name    := LName;
            ProcTab[PI].Locals[LCount].TypeIdx := LTIdx;
            ProcTab[PI].Locals[LCount].Size    := TypeSizeFromIdx(LTIdx);
            ProcTab[PI].Locals[LCount].Offset  := -LSize;
            Inc(LCount);
          End;

          (* Passer le ';' *)
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Inc(P);
        End
        Else
          Inc(P); (* token inattendu, avancer *)
      End;
    End;
    ProcTab[PI].LocalCount := LCount;
    (* Aligner la taille locale sur mot (2 octets) *)
    If (LSize Mod 2) = 1 Then Inc(LSize);
    ProcTab[PI].LocalSize  := LSize;

    (* ---- Procedures imbriquees (TODO 17) ---- *)
    (* Detecter PROCEDURE avant BEGIN dans le corps d'une procedure *)
    (* Les procedures imbriquees sont aplaties avec un nom mange    *)
    While (P < TokenCount) And
          (TokenPool[P].Kind = TK_KEYWORD) And
          (TokenPool[P].Val = 'PROCEDURE') Do
    Begin
      ParseNestedProc(P, PI, PName);
    End;

    (* ---- Corps : BEGIN ... END ---- *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (TokenPool[P].Val = 'BEGIN') Then
    Begin
      Inc(P); (* passer BEGIN *)
      BodyOpen := P;
      SkipToMatchingEnd(P);
      ProcTab[PI].BodyStart := BodyOpen;
      ProcTab[PI].BodyEnd   := P - 1;
    End;

    (* Passer le nom du module apres END (ex: END NomProc) *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Inc(P);

    (* Passer le ';' apres END *)
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);

    If Opts.DebugMode Then
      WriteLn('  PROC[', PI, ']: ', PName,
              ' params=', PCount,
              ' locals=', LCount,
              ' localSize=', ProcTab[PI].LocalSize,
              ' body=', ProcTab[PI].BodyStart, '..',
              ProcTab[PI].BodyEnd);
  End; (* while P < TokenCount *)
End;

(* ---- EmitProcedures : emettre le code ASM des procedures ------ *)
(* Pour chaque procedure dans ProcTab, genere :                     *)
(*   - label + prologue (PUSH BP / MOV BP,SP / SUB SP,n)           *)
(*   - commentaires decrivant les parametres et les locales         *)
(*   - corps via ParseBody (TODO 10)                               *)
(*   - epilogue (POP BP / RET n)                                   *)

Procedure EmitProcedures;
Var
  PI, LI : Integer;
  OfsStr : TString;
Begin
  For PI := 0 To ProcCount - 1 Do
  Begin
    EmitBlankLine;
    If ProcTab[PI].IsFunction Then
      EmitComment('--- Fonction: ' + ProcTab[PI].Name + ' ---')
    Else
      EmitComment('--- Procedure: ' + ProcTab[PI].Name + ' ---');

    EmitLabel(ProcTab[PI].MangledName);
    EmitProlog(ProcTab[PI].LocalSize);

    (* Commentaires descriptifs pour les parametres *)
    For LI := 0 To ProcTab[PI].ParamCount - 1 Do
    Begin
      Case ProcTab[PI].ParamModes[LI] Of
        PM_VALUE :
          OfsStr := 'VALUE ';
        PM_VAR :
          OfsStr := 'VAR ';
        PM_READONLY :
          OfsStr := 'READONLY ';
      End;
      EmitComment('  param ' + OfsStr + ProcTab[PI].ParamNames[LI] +
                  ' = [BP+' + IntToStr(ProcTab[PI].ParamOfs[LI]) + ']');
    End;

    (* Commentaires descriptifs pour les variables locales *)
    For LI := 0 To ProcTab[PI].LocalCount - 1 Do
    Begin
      OfsStr := IntToStr(ProcTab[PI].Locals[LI].Offset);
      EmitComment('  local ' + ProcTab[PI].Locals[LI].Name +
                  ' = [BP' + OfsStr + ']');
    End;

    (* Initialiser les variables locales a zero *)
    For LI := 0 To ProcTab[PI].LocalCount - 1 Do
    Begin
      If ProcTab[PI].Locals[LI].Size <= 1 Then
        EmitInstrAB('MOV', 'BYTE PTR [BP' +
                    IntToStr(ProcTab[PI].Locals[LI].Offset) + ']', '0')
      Else If ProcTab[PI].Locals[LI].Size > 2 Then
      Begin
        (* RECORD/ARRAY : initialiser avec REP STOSW *)
        EmitInstrAB('LEA', 'DI', '[BP' +
                    IntToStr(ProcTab[PI].Locals[LI].Offset) + ']');
        EmitInstrAB('MOV', 'CX',
                    IntToStr(ProcTab[PI].Locals[LI].Size Div 2));
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstr('REP    STOSW');
      End
      Else
        EmitInstrAB('MOV', 'WORD PTR [BP' +
                    IntToStr(ProcTab[PI].Locals[LI].Offset) + ']', '0');
    End;

    EmitBlankLine;
    ParseBody(PI);

    (* Epilogue *)
    EmitBlankLine;
    EmitEpilog(ProcTab[PI].ParamCount * 2);
  End;
End;

(* ============================================================
   TODO 12 - ENTREES/SORTIES (MODULES Wr / Rd / Stdio) [IMPLEMENTE]
   ============================================================ *)

(* ---- EmitRuntime : emettre les routines runtime dans _TEXT ---- *)
(* Genere les sous-programmes ASM 8086 appeles par le code genere. *)
(* Chaque routine est autonome et suit la convention NEAR CALL.    *)
(* Toutes les routines preservent BP et les registres de segment.  *)

Procedure EmitRuntime;
Begin
  EmitBlankLine;
  EmitComment('=========================================================');
  EmitComment('RUNTIME MODULA-3 (_M3RT_xxx)');
  EmitComment('=========================================================');

  (* --------------------------------------------------------------- *)
  (* _M3RT_PRINT : afficher une chaine ASCIIZ via DOS               *)
  (* Entree : SI = pointeur vers chaine ASCIIZ                      *)
  (* Sortie : rien                                                   *)
  (* Modifie : AX, BX, CX, DX                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'PRINT');
  EmitInstrA('PUSH', 'SI');
  EmitComment('calculer la longueur de la chaine');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(M3_RT_PFX + 'PRINT_L');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', M3_RT_PFX + 'PRINT_D');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', M3_RT_PFX + 'PRINT_L');
  EmitLabel(M3_RT_PFX + 'PRINT_D');
  EmitComment('ecrire CX octets a partir de SI');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrAB('MOV', 'DX', 'SI');
  EmitInstr('INT    21h');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_NUMTOSTR : convertir un entier signe 16 bits en ASCIIZ   *)
  (* Entree : AX = valeur, DI = buffer destination                  *)
  (* Sortie : AX = pointeur vers debut du nombre dans buffer        *)
  (* Modifie : AX, BX, CX, DX, DI                                   *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'NUMTOSTR');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JGE', M3_RT_PFX + 'NTS_POS');
  EmitComment('nombre negatif : stocker - et nier');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstrA('INC', 'DI');
  EmitInstr('NEG     AX');
  EmitLabel(M3_RT_PFX + 'NTS_POS');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', M3_RT_PFX + 'NTS_DIVL');
  EmitComment('cas zero');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''0''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '0');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel(M3_RT_PFX + 'NTS_DIVL');
  EmitComment('extraire chiffres de droite a gauche');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', M3_RT_PFX + 'NTS_DIVL');
  EmitComment('ecrire chiffres dans l''ordre');
  EmitLabel(M3_RT_PFX + 'NTS_WR');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', M3_RT_PFX + 'NTS_WR');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_STRTONUM : convertir une chaine ASCIIZ en entier signe   *)
  (* Entree : SI = pointeur vers chaine ASCIIZ                      *)
  (* Sortie : AX = valeur entiere                                   *)
  (* Modifie : AX, BX, CX, DX                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'STRTONUM');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitComment('verifier signe negatif');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''-''');
  EmitInstrA('JNE', M3_RT_PFX + 'STN_LP');
  EmitInstrA('INC', 'SI');
  EmitInstrAB('MOV', 'CX', '1');
  EmitLabel(M3_RT_PFX + 'STN_LP');
  EmitInstrAB('MOV', 'DL', '[SI]');
  EmitInstrAB('CMP', 'DL', '''0''');
  EmitInstrA('JB', M3_RT_PFX + 'STN_DN');
  EmitInstrAB('CMP', 'DL', '''9''');
  EmitInstrA('JA', M3_RT_PFX + 'STN_DN');
  EmitInstrAB('SUB', 'DL', '''0''');
  EmitInstrAB('XOR', 'DH', 'DH');
  EmitInstrA('MUL', 'BX');
  EmitInstrAB('ADD', 'AX', 'DX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', M3_RT_PFX + 'STN_LP');
  EmitLabel(M3_RT_PFX + 'STN_DN');
  EmitInstrAB('CMP', 'CX', '1');
  EmitInstrA('JNE', M3_RT_PFX + 'STN_OK');
  EmitInstr('NEG     AX');
  EmitLabel(M3_RT_PFX + 'STN_OK');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_STRLEN : longueur d une chaine ASCIIZ                    *)
  (* Entree : SI = pointeur vers chaine ASCIIZ                      *)
  (* Sortie : AX = longueur (sans le zero terminal)                 *)
  (* Modifie : AX, SI                                                *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel(M3_RT_PFX + 'SL_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', M3_RT_PFX + 'SL_DN');
  EmitInstrA('INC', 'AX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', M3_RT_PFX + 'SL_LP');
  EmitLabel(M3_RT_PFX + 'SL_DN');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_STRCMP : comparer deux chaines ASCIIZ                     *)
  (* Entree : SI = chaine gauche, DI = chaine droite                *)
  (* Sortie : drapeaux ZF et CF selon comparaison                   *)
  (*   ZF=1 -> egal ; CF=1 -> gauche < droite                      *)
  (*   AX = 1 si egal, AX = 0 sinon                                *)
  (* Modifie : AX, SI, DI                                            *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'STRCMP');
  EmitInstrA('PUSH', 'BX');
  EmitLabel(M3_RT_PFX + 'SC_LP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', 'BL', '[DI]');
  EmitInstrAB('CMP', 'AL', 'BL');
  EmitInstrA('JNE', M3_RT_PFX + 'SC_NE');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', M3_RT_PFX + 'SC_EQ');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', M3_RT_PFX + 'SC_LP');
  EmitLabel(M3_RT_PFX + 'SC_EQ');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel(M3_RT_PFX + 'SC_NE');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_CONCAT : concatener deux ASCIIZ -> STRBUF                *)
  (* Entree : SI = chaine gauche, DI = chaine droite                *)
  (* Sortie : AX = pointeur vers STRBUF avec resultat               *)
  (* Modifie : AX, CX, SI, DI                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'CONCAT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('LEA', 'BX', M3_RT_PFX + 'STRBUF');
  EmitInstrA('PUSH', 'BX');
  EmitComment('copier chaine gauche');
  EmitLabel(M3_RT_PFX + 'CC_L1');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', M3_RT_PFX + 'CC_L2');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', M3_RT_PFX + 'CC_L1');
  EmitComment('copier chaine droite');
  EmitLabel(M3_RT_PFX + 'CC_L2');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', M3_RT_PFX + 'CC_DN');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', M3_RT_PFX + 'CC_L2');
  EmitLabel(M3_RT_PFX + 'CC_DN');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', '0');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_TEXTSUB : extraction sous-chaine -> STRBUF               *)
  (* Entree : SI = source, BX = start (0-based), CX = longueur     *)
  (* Sortie : AX = pointeur vers STRBUF avec sous-chaine            *)
  (* Modifie : AX, CX, SI, DI                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'TEXTSUB');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('ADD', 'SI', 'BX');
  EmitInstrAB('LEA', 'DI', M3_RT_PFX + 'STRBUF');
  EmitInstrA('PUSH', 'DI');
  EmitLabel(M3_RT_PFX + 'TS_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', M3_RT_PFX + 'TS_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', M3_RT_PFX + 'TS_DN');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', M3_RT_PFX + 'TS_LP');
  EmitLabel(M3_RT_PFX + 'TS_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_READLINE : lire une ligne depuis stdin (INT 21h AH=0Ah)  *)
  (* Entree : SI = buffer destination (doit faire >= 256 octets)    *)
  (* Sortie : SI contient la chaine ASCIIZ lue                      *)
  (* Modifie : AX, BX, CX, DX                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'READLINE');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitComment('preparer le buffer DOS AH=0Ah : [maxlen] [actlen] [data...]');
  EmitInstrAB('MOV', 'BYTE PTR [SI]', '253');
  EmitInstrAB('MOV', 'BYTE PTR [SI+1]', '0');
  EmitInstrAB('MOV', 'AH', '0Ah');
  EmitInstrAB('MOV', 'DX', 'SI');
  EmitInstr('INT    21h');
  EmitComment('convertir en ASCIIZ : deplacer les caracteres et terminer par 0');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'CL', '[SI+1]');
  EmitInstrAB('LEA', 'BX', '[SI+2]');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitLabel(M3_RT_PFX + 'RL_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', M3_RT_PFX + 'RL_DN');
  EmitInstrAB('MOV', 'AL', '[BX]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'BX');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', M3_RT_PFX + 'RL_LP');
  EmitLabel(M3_RT_PFX + 'RL_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_PRBOOL : afficher TRUE ou FALSE                          *)
  (* Entree : AX = valeur booleenne (0=FALSE, non-zero=TRUE)        *)
  (* Sortie : rien                                                   *)
  (* Modifie : AX, SI                                                *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'PRBOOL');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', M3_RT_PFX + 'PB_F');
  EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'TRUE_S');
  EmitInstrA('JMP', M3_RT_PFX + 'PB_PR');
  EmitLabel(M3_RT_PFX + 'PB_F');
  EmitInstrAB('LEA', 'SI', M3_RT_PFX + 'FALSE_S');
  EmitLabel(M3_RT_PFX + 'PB_PR');
  EmitInstr('CALL    ' + M3_RT_PFX + 'PRINT');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_FMTBOOL : retourner pointeur vers "TRUE" ou "FALSE"     *)
  (* Entree : AX = valeur booleenne (0=FALSE, non-zero=TRUE)        *)
  (* Sortie : AX = pointeur vers chaine ASCIIZ "TRUE" ou "FALSE"   *)
  (* Modifie : AX                                                    *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'FMTBOOL');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', M3_RT_PFX + 'FB_F');
  EmitInstrAB('LEA', 'AX', M3_RT_PFX + 'TRUE_S');
  EmitInstr('RET');
  EmitLabel(M3_RT_PFX + 'FB_F');
  EmitInstrAB('LEA', 'AX', M3_RT_PFX + 'FALSE_S');
  EmitInstr('RET');

  (* --------------------------------------------------------------- *)
  (* _M3RT_OBJNEW : allouer un objet sur le heap (TODO 19)          *)
  (* Entree : CX = taille totale, SI = adresse vtable               *)
  (* Sortie : AX = pointeur vers le nouvel objet                    *)
  (* [AX] contient le pointeur vtable, le reste est a zero          *)
  (* Modifie : AX, BX, CX, DI                                       *)
  (* --------------------------------------------------------------- *)
  EmitBlankLine;
  EmitLabel(M3_RT_PFX + 'OBJNEW');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'BX', M3_RT_PFX + 'HEAPTOP');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('ADD', 'BX', 'CX');
  EmitInstrAB('MOV', M3_RT_PFX + 'HEAPTOP', 'BX');
  EmitComment('zero-fill the object');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('SHR', 'CX', '1');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('REP    STOSW');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'AX');
  EmitComment('store vtable pointer at [AX]');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'WORD PTR [AX]', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
End;

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
  ProcCount  := 0;
  ObjTypeCount := 0;
  OpaqueCount  := 0;
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

  (* Phase 2c : scanner les declarations PROCEDURE au niveau MODULE *)
  ParseProcDecls;

  If Opts.Verbose Then
  Begin
    If ModuleName <> '' Then
    Begin
      If Opts.IsIface Then
        WriteLn('  Interface      : ', ModuleName)
      Else
        WriteLn('  Module         : ', ModuleName);
      If ExportsName <> '' Then
        WriteLn('  Exports        : ', ExportsName);
    End;
    WriteLn('  Tokens         : ', TokenCount);
    WriteLn('  Donnees (DATA) : ', DataCount);
    WriteLn('  Types          : ', TypeCount);
    WriteLn('  Symboles       : ', SymCount);
    WriteLn('  Procedures     : ', ProcCount);
    WriteLn('  Imports        : ', ImportCount);
    WriteLn('  Types objets   : ', ObjTypeCount);
  End;

  (* Phase 3 : emettre le fichier assembleur *)
  EmitOpen;
  EmitHeader;
  EmitProcedures;
  EmitRuntime;
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
