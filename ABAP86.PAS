(* @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur ABAP/4 (SAP) pour 8086/8088 - Sortie MASM/TASM

  ===== TODOS 25 POINTS =====

  TODO 01 - Architecture generale, constantes et types de base
            Types de tokens ABAP (TOK_IDENT, TOK_NUMBER, TOK_FLOAT,
            TOK_STRING, TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH,
            TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_DOT, TOK_COLON,
            TOK_EQ, TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE,
            TOK_CONCAT (&&), TOK_EOF, TOK_UNKNOWN...).
            Types de donnees ABAP (TYPE_I, TYPE_F, TYPE_C, TYPE_N,
            TYPE_D, TYPE_T, TYPE_P, TYPE_STRING, TYPE_XSTRING,
            TYPE_TABLE, TYPE_STRUCT, TYPE_REF, TYPE_VOID...).
            Classes de stockage (STORE_AUTO, STORE_STATIC, STORE_PARAM,
            STORE_TABLE, STORE_CONSTANT...).
            Constantes d'erreur et limites (MAX_SYM, MAX_FORM, MAX_LOCAL,
            MAX_PARAM, MAX_DEPTH, MAX_LABEL, MAX_STR, MAX_FIELD...).
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent, PadLabel,
            Error, Warning.
            => TODO 01

  TODO 02 - Tokeniseur ABAP (Lexer)
            Procedure InitTokenizer : ouvrir source, initialiser etat.
            Procedure NextChar / PeekChar.
            Procedure NextToken : reconnaitre les tokens ABAP :
              - Identificateurs : lettres, chiffres, _ (max 40 cars)
              - Litteraux numeriques : 123, 1.5, 1E3
              - Litteraux chaines : 'texte' (apostrophe doublable : '')
              - Commentaires ligne : * en colonne 1, ou " en milieu ligne
              - Pas de commentaires bloc en ABAP standard
              - Operateurs : + - * / = <> < > <= >= && (concat.)
              - Separateurs : . , : ( )
              - Pragmas : "#" en debut (a ignorer)
              - Chaine type STR : |Texte {var}| (ABAP 7.4, stub)
            Stocker dans cur_tok_type / cur_tok_str / cur_tok_num.
            => TODO 02

  TODO 03 - Reconnaissance des mots-cles ABAP/4
            Function IsKeyword(Const s: String): Integer.
            Mots-cles complets a reconnaitre :
              REPORT PROGRAM DATA TYPES CONSTANTS CLASS-DATA
              IF ELSEIF ELSE ENDIF
              CASE WHEN ENDCASE
              WHILE ENDWHILE DO TIMES ENDDO
              LOOP AT INTO ENDLOOP
              FORM ENDFORM PERFORM USING CHANGING TABLES
              FUNCTION ENDFUNCTION
              WRITE SKIP LINE NEW-LINE
              MOVE TO MOVE-CORRESPONDING
              COMPUTE ADD SUBTRACT MULTIPLY BY DIVIDE FROM GIVING
              APPEND INSERT DELETE MODIFY READ SORT COLLECT
              SELECT FROM WHERE INTO CORRESPONDING FIELDS ENDSELECT
              CALL RAISING EXCEPTIONS SINGLE
              CLEAR REFRESH FREE INITIALIZE
              CONCATENATE SPLIT SHIFT REPLACE TRANSLATE CONDENSE FIND
              CHECK RETURN EXIT STOP CONTINUE
              START-OF-SELECTION END-OF-SELECTION TOP-OF-PAGE END-OF-PAGE
              PARAMETERS SELECT-OPTIONS LIKE TYPE VALUE DEFAULT
              CLASS ENDCLASS METHOD ENDMETHOD PUBLIC PRIVATE PROTECTED
              RAISE EXCEPTION TRY CATCH CLEANUP ENDTRY
              EQ NE LT GT LE GE BETWEEN IN AND OR NOT IS INITIAL BOUND
              ASCENDING DESCENDING LEFT RIGHT UPPER LOWER NO-GAPS
              MATCH OFFSET OCCURRENCE OCCURRENCES SEPARATED
              AT LINE-SELECTION USER-COMMAND
            => TODO 03

  TODO 04 - Table des symboles (variables, formes, constantes)
            Type TSymEntry : name (String[48]), asm_label (String[48]),
              data_type (Integer), store_class (Integer),
              bp_offset (Integer), array_size (Integer),
              char_len (Integer), dec_prec (Integer), dec_scale (Integer),
              is_param (Boolean), param_idx (Integer),
              init_str (String[64]), init_num (LongInt),
              has_init (Boolean), is_const (Boolean).
            Type TFormEntry : name (String[48]), asm_label (String[48]),
              param_count (Integer), defined (Boolean),
              using_count (Integer), changing_count (Integer),
              param_names : Array[1..MAX_PARAM] of String[48],
              param_kinds : Array[1..MAX_PARAM] of Integer. (U/C/T)
            Procedure InitSymTable.
            Function FindSym(Const name: String): Integer.
            Function AddSym(Const name: String; dt, sc: Integer): Integer.
            Function FindForm(Const name: String): Integer.
            Function AddForm(Const name: String): Integer.
            Variables systeme auto-declarees : SY_SUBRC, SY_TABIX,
            SY_DBCNT, SY_LANGU, SY_INDEX.
            => TODO 04

  TODO 05 - Gestion des scopes (REPORT, FORM, METHOD)
            Pile de scopes : chaque scope maintient ses propres
            variables locales, un offset BP courant, et un label de sortie.
            Procedure EnterScope(kind: Integer; form_idx: Integer).
            Procedure LeaveScope.
            Function AllocLocalBp(bytes: Integer): Integer.
            Function CurrentBpTop: Integer.
            Compteur d'offset BP pour l'allocation des variables locales.
            Scopes supportes : SK_GLOBAL, SK_FORM, SK_BLOCK.
            => TODO 05

  TODO 06 - Parseur : REPORT / PROGRAM (en-tete du programme)
            Procedure ParseReport.
            Syntaxe :
              REPORT nom_programme [MESSAGE-ID xx] [NO STANDARD PAGE HEADING].
              PROGRAM nom_programme.
            Enregistrer le nom du programme (sera utilise pour le label ASM).
            Ignorer les options MESSAGE-ID et NO STANDARD PAGE HEADING.
            Consommer jusqu'au point '.' final.
            => TODO 06

  TODO 07 - Parseur : DATA / TYPES / CONSTANTS (declarations)
            Procedure ParseData.
            Syntaxe simple :
              DATA nom TYPE I [VALUE 0].
              DATA nom(n) TYPE C [VALUE ' '].
              DATA nom TYPE F [VALUE '0.0'].
              DATA nom TYPE P [DECIMALS n] [VALUE '0'].
              DATA: nom TYPE I, nom2 TYPE C(20).
              CONSTANTS nom TYPE I VALUE 42.
            Syntaxe TABLE :
              DATA: ITAB TYPE TABLE OF struc.
              DATA: ITAB LIKE TABLE OF var.
            Syntaxe STRUCTURE :
              TYPES: BEGIN OF struc, champ TYPE I, END OF struc.
            Types ABAP reconnus :
              I (entier 16 bits ici), F (flottant, stub), C(n) (chaine),
              N(n) (num.-texte), D (date 8 cars), T (heure 6 cars),
              P (packed, stub), STRING, XSTRING.
            Allouer espace en .DATA (global) ou sur la pile (local FORM).
            => TODO 07

  TODO 08 - Parseur : Expressions arithmetiques et logiques
            Function ParseExpr: Integer.
            Function ParseLogExpr: Integer.    (AND / OR / NOT)
            Function ParseCompareExpr: Integer. (EQ NE LT GT LE GE
              = <> < > <= >= BETWEEN a AND b  / IS INITIAL)
            Function ParseAddExpr: Integer.    (+ / -)
            Function ParseMulExpr: Integer.    ( * / / DIV / MOD)
            Function ParseUnaryExpr: Integer.  (- / NOT)
            Function ParsePrimaryExpr: Integer.
              Constante numerique -> MOV AX, n
              Constante chaine    -> LEA AX, _LSn
              Variable scalaire   -> MOV AX, [_VAR_x] / [BP-n]
              Fonction built-in : STRLEN, ABS, etc.
              Parentheses
            => TODO 08

  TODO 09 - Generation de code : operations arithmetiques
            Procedure GenLoadVar(sym_idx: Integer).
              Type I/N : MOV AX, [_VAR_x] ou [BP-n]
              Type C   : LEA AX, [_VAR_x]
            Procedure GenStoreVar(sym_idx: Integer).
              MOV [_VAR_x], AX  ou  MOV [BP-n], AX
            Procedure GenBinOp(op: Integer).
              +   : ADD AX, BX
              -   : SUB AX, BX
              *   : IMUL BX
              /   : CWD + IDIV BX (quotient)
              MOD : CWD + IDIV BX -> MOV AX, DX (reste)
            Procedure GenCompare(op: Integer).
              CMP AX, BX + sauts conditionnels -> AX = 0 ou 0FFFFh
            Procedure GenBuiltIn(Const bname: String): Boolean.
              ABS, MOD, DIV, etc.
            Primitives d'emission ASM : Emit, EmitLabel, EmitComment,
            EmitBlank, NewLabel, AddStringLit.
            => TODO 09

  TODO 10 - Parseur : IF / ELSEIF / ELSE / ENDIF
            Procedure ParseIf.
            Syntaxe :
              IF condition. instructions.
              [ELSEIF condition. instructions.] ...
              [ELSE. instructions.]
              ENDIF.
            Conditions speciales ABAP :
              IF var IS INITIAL.       -> TEST AX, AX + JNZ ...
              IF var IS NOT INITIAL.   -> TEST AX, AX + JZ ...
              IF var BETWEEN a AND b.  -> CMP + JL + CMP + JG
            Generation :
              Evaluer condition -> AX.
              TEST AX, AX + JZ lbl_elseif ou lbl_else.
              Chaine ELSEIF avec liste de labels de saut.
              JMP lbl_endif apres chaque branche.
            => TODO 10

  TODO 11 - Parseur : CASE / WHEN / WHEN OTHERS / ENDCASE
            Procedure ParseCase.
            Syntaxe :
              CASE variable.
                WHEN valeur. instructions.
                WHEN valeur1 OR valeur2. instructions.
                WHEN OTHERS. instructions.
              ENDCASE.
            Generation :
              Charger variable -> DX.
              Pour chaque WHEN : MOV AX, val + CMP DX, AX + JNE lbl_next.
              WHEN OTHERS = clause par defaut.
              ENDCASE = EmitLabel(lbl_endcase).
            => TODO 11

  TODO 12 - Parseur : WHILE / ENDWHILE et DO n TIMES / ENDDO
            Procedure ParseWhile.
            Syntaxe : WHILE condition. instructions. ENDWHILE.
            Generation :
              lbl_top: evaluer condition -> AX.
              TEST AX, AX + JZ lbl_end.
              Corps. JMP lbl_top. EmitLabel(lbl_end).
            Procedure ParseDo.
            Syntaxe : DO [n TIMES]. instructions. ENDDO.
            Generation n TIMES :
              MOV CX, n. lbl_top: JCXZ lbl_end. corps. LOOP lbl_top.
            Generation infinie (sans n) :
              lbl_top: corps + JMP lbl_top (EXIT -> JMP lbl_end).
            => TODO 12

  TODO 13 - Parseur : PERFORM / FORM / ENDFORM (sous-routines)
            Procedure ParsePerform.
            Syntaxe :
              PERFORM nom [USING arg1 arg2 ...] [CHANGING arg1 ...].
            Procedure ParseForm.
            Syntaxe :
              FORM nom [USING param1 TYPE t ...] [CHANGING param1 TYPE t ...].
                instructions.
              ENDFORM.
            Convention d'appel 8086 :
              Arguments USING : PUSH AX (par valeur).
              Arguments CHANGING : LEA AX, var + PUSH AX (par adresse).
              PUSH BP / MOV BP, SP en prologue.
              MOV SP, BP / POP BP / RET (n*2) en epilogue.
            => TODO 13

  TODO 14 - Parseur : WRITE / SKIP / NEW-LINE (sortie console)
            Procedure ParseWrite.
            Syntaxe :
              WRITE nom_var.
              WRITE: 'Texte', nom_var, /.
              WRITE nom_var LEFT-JUSTIFIED / NO-GAP.
              SKIP [n].
              NEW-LINE.
            Generation :
              Variable TYPE I   -> PUSH AX + CALL _ABAP_PRINT_INT
              Variable TYPE C   -> LEA DX, var + CALL _ABAP_PRINT_STR
              Chaine litterale  -> LEA DX, _LSn + CALL _ABAP_PRINT_STR
              SKIP / '/' (barre) -> CALL _ABAP_CRLF
            => TODO 14

  TODO 15 - Parseur : MOVE / COMPUTE / formes verbales arithmetiques
            Procedure ParseMove.
            Syntaxe : MOVE source TO destination.
            Equivalent a : destination = source.
            Procedure ParseCompute.
            Syntaxe : COMPUTE var = expr.
            Formes verbales ABAP :
              ADD val TO var.           -> var = var + val
              ADD val1 TO val2 GIVING var. -> var = val1 + val2
              SUBTRACT val FROM var.    -> var = var - val
              MULTIPLY var BY val.      -> var = var * val
              DIVIDE var BY val.        -> var = var / val (entier)
            Procedure ParseAssignment.
            Syntaxe : var = expr.  (style ABAP Objet)
            => TODO 15

  TODO 16 - Parseur : LOOP AT / ENDLOOP + operations sur tables internes
            Procedure ParseLoopAt.
            Syntaxe :
              LOOP AT itab [INTO wa] [WHERE condition].
                instructions.
              ENDLOOP.
            Generation (stub tableau lineaire en memoire) :
              Initialiser SI = adresse_debut_itab.
              lbl_top: CMP SI, limite + JGE lbl_end.
              Copier element si INTO fourni.
              INC / ADD SI puis JMP lbl_top.
            Procedure ParseAppend.
              APPEND [wa TO] itab.
            Procedure ParseReadTable.
              READ TABLE itab INTO wa [INDEX i | WITH KEY champ = val].
            Procedure ParseSort.
              SORT itab [BY champ] [ASCENDING | DESCENDING].
            Procedure ParseDelete (table).
              DELETE itab [WHERE condition | INDEX i].
            => TODO 16

  TODO 17 - Parseur : operations sur chaines de caracteres
            Procedure ParseConcatenate.
            Syntaxe :
              CONCATENATE s1 s2 ... INTO dest [SEPARATED BY sep].
            Procedure ParseSplit.
              SPLIT src AT sep INTO s1 s2.
            Procedure ParseShift.
              SHIFT var [LEFT | RIGHT] [BY n PLACES | CIRCULAR].
            Procedure ParseReplace.
              REPLACE [ALL OCCURRENCES OF] old IN dest WITH new.
            Procedure ParseTranslate.
              TRANSLATE var TO UPPER CASE / TO LOWER CASE.
            Procedure ParseCondense.
              CONDENSE var [NO-GAPS].
            Procedure ParseFind.
              FIND [FIRST OCCURRENCE OF] pattern IN var
                   [MATCH OFFSET off] [MATCH LENGTH len].
            Generation : appels aux helpers runtime _ABAP_STR_xxx.
            => TODO 17

  TODO 18 - Generation : en-tete + segment .DATA
            Procedure GenHeader.
              '; Generated by ABAP86 V1.0'
              '.MODEL SMALL' / '.STACK 256'
            Procedure GenDataSegment.
              - Variables globales TYPE I : _VAR_nom DW 0
              - Variables globales TYPE C(n): _VAR_nom DB n DUP(32)
              - Variables globales TYPE F : _VAR_nom DW 0, 0 (4 octets)
              - Variables SY systeme : _SY_SUBRC DW 0, _SY_TABIX DW 0...
              - Buffers internes : _CRLF, _NUMBUF, _INPUTBUF, _ERR_STR
              - Chaines litterales : _LS1, _LS2 ... DB 'texte', '$'
            => TODO 18

  TODO 19 - Generation : point d'entree + helpers runtime
            Procedure GenCodeSegmentHeader.
              '.CODE' + 'START:'
              MOV AX, @DATA / MOV DS, AX / MOV ES, AX
              CALL _ABAP_RPT_nom (label du REPORT principal)
              MOV AX, 4C00h / INT 21h
            Procedure GenRuntimeHelpers.
              _ABAP_CRLF      : afficher CR+LF via INT 21h AH=09h
              _ABAP_PRINT_INT : AX -> chaine decimal + INT 21h AH=09h
              _ABAP_PRINT_STR : DX = ptr '$'-termine -> INT 21h AH=09h
              _ABAP_PRINT_CHAR: DL = car -> INT 21h AH=02h
              _ABAP_READ_INT  : AH=0Ah + parsing ASCII -> AX
              _ABAP_READ_STR  : AH=0Ah -> copier dans buffer CHAR
              _ABAP_STR_LEN   : SI = ptr '$'-termine -> CX = longueur
              _ABAP_STR_COPY  : copier SI -> DI (n octets max)
              _ABAP_STR_CONCAT: coller SI apres DI jusqu'a '$'
              _ABAP_ERROR     : afficher message + INT 21h exit code 1
            Procedure GenFooter. 'END START'
            => TODO 19

  TODO 20 - Parseur : CLEAR / REFRESH / FREE / CHECK / EXIT / CONTINUE
            Procedure ParseClear.
            Syntaxe : CLEAR variable.
            Generation :
              TYPE I/N/F : MOV WORD PTR [_VAR_x], 0
              TYPE C(n)  : boucle ou REP STOSB pour remplir d'espaces
            Procedure ParseRefresh.
              REFRESH itab. -> remettre le compteur d'elements a 0.
            Procedure ParseFree.
              FREE itab.    -> stub REFRESH.
            Procedure ParseCheck.
              CHECK condition. -> si faux, JMP lbl_exit_courant.
            Procedure ParseExit.
              EXIT. -> JMP lbl_enddo / lbl_endloop / lbl_endform.
            Procedure ParseContinue.
              CONTINUE. -> JMP lbl_loop_top.
            => TODO 20

  TODO 21 - Parseur : SELECT / ENDSELECT (acces BD, stub sans BD)
            Procedure ParseSelect.
            Syntaxe :
              SELECT [SINGLE] champ(s) / * FROM table
                INTO [CORRESPONDING FIELDS OF] var / TABLE itab
                [WHERE condition]
                [ORDER BY champ]
                [UP TO n ROWS].
              [instructions. ENDSELECT.]
            Stub de generation (pas de BD reelle) :
              Emettre '; SELECT ... (stub)'.
              Boucle vide -> 0 iterations.
              SY-SUBRC = 4 (non trouve) :
                MOV WORD PTR [_SY_SUBRC], 4.
            Variables systeme necessaires : SY-SUBRC, SY-TABIX,
            SY-DBCNT.
            => TODO 21

  TODO 22 - Parseur : CALL FUNCTION / FUNCTION / ENDFUNCTION (stubs)
            Procedure ParseCallFunction.
            Syntaxe :
              CALL FUNCTION 'NOM_FM'
                EXPORTING param = val ...
                IMPORTING param = var ...
                TABLES    itab  = itab2 ...
                EXCEPTIONS exception_name = n ...
            Generation stub :
              Emettre '; CALL FUNCTION NOM_FM (stub)'.
              MOV WORD PTR [_SY_SUBRC], 0.
            Procedure ParseFunction.
            Syntaxe :
              FUNCTION nom.
                instructions.
              ENDFUNCTION.
            Generer comme une FORM avec label _ABAP_FM_nom.
            => TODO 22

  TODO 23 - Parseur : instruction de niveau superieur + boucle principale
            Procedure ParseStatement.
            Dispatcher selon le token courant :
              REPORT / PROGRAM         -> ParseReport
              DATA / TYPES / CONSTANTS -> ParseData
              IF                       -> ParseIf
              CASE                     -> ParseCase
              WHILE                    -> ParseWhile
              DO                       -> ParseDo
              LOOP                     -> ParseLoopAt
              PERFORM                  -> ParsePerform
              FORM                     -> ParseForm
              WRITE / WRITELN          -> ParseWrite
              SKIP / NEW-LINE          -> ParseWrite
              MOVE                     -> ParseMove
              COMPUTE                  -> ParseCompute
              ADD / SUBTRACT / MULTIPLY / DIVIDE -> ParseArithVerb
              APPEND / INSERT / DELETE / MODIFY  -> ParseTableOp
              READ                     -> ParseReadTable
              SORT                     -> ParseSort
              CONCATENATE              -> ParseConcatenate
              SPLIT                    -> ParseSplit
              SHIFT / REPLACE / TRANSLATE / CONDENSE / FIND -> ParseStringOp
              CLEAR / REFRESH / FREE   -> ParseClear
              CHECK                    -> ParseCheck
              EXIT / CONTINUE          -> ParseExit
              SELECT                   -> ParseSelect
              CALL                     -> ParseCallFunction
              START-OF-SELECTION       -> ParseEvent(EV_START)
              END-OF-SELECTION         -> ParseEvent(EV_END)
              nom '='                  -> ParseAssignment
              nom '.'                  -> instruction vide ou label
              PARAMETERS / SELECT-OPTIONS -> ParseSelectionScreen
            Procedure ParseBlock(stop_kw: Integer).
              Appeler ParseStatement en boucle jusqu'a stop_kw ou EOF.
            => TODO 23

  TODO 24 - Parseur : evenements ABAP et ecran de selection (stubs)
            Evenements ABAP de haut niveau :
              START-OF-SELECTION. -> label _ABAP_EV_START + ParseBlock
              END-OF-SELECTION.   -> label _ABAP_EV_END   + ParseBlock
              TOP-OF-PAGE.        -> label _ABAP_EV_TOPPAGE (stub vide)
              END-OF-PAGE.        -> label _ABAP_EV_ENDPAGE (stub vide)
              AT LINE-SELECTION.  -> stub vide
              AT USER-COMMAND.    -> stub vide
            Ecran de selection :
              PARAMETERS p TYPE I DEFAULT 0.
                -> generer variable globale + valeur par defaut
              SELECT-OPTIONS s FOR var.
                -> stub (deux variables LOW / HIGH)
            Generation :
              START: appelle _ABAP_EV_START en dernier.
              Chaque bloc evenement = CheckBP + CALL + label + corps.
            => TODO 24

  TODO 25 - Programme de test ABAP complet
            Creer TEST.ABAP :
              REPORT ZTEST01.
              DATA: GV_N   TYPE I VALUE 10,
                    GV_I   TYPE I VALUE 1,
                    GV_SUM TYPE I VALUE 0,
                    GV_MSG TYPE C.
              START-OF-SELECTION.
                GV_SUM = 0.
                GV_I   = 1.
                WHILE GV_I <= GV_N.
                  ADD GV_I TO GV_SUM.
                  ADD 1 TO GV_I.
                ENDWHILE.
                WRITE: 'Somme =', GV_SUM.
                SKIP.
            Compiler : ABAP86.EXE TEST.ABAP TEST.ASM
            Verifier le .ASM : structure .MODEL SMALL, segment .DATA
            avec _VAR_GV_N, _VAR_GV_I, _VAR_GV_SUM, boucle WHILE,
            appels WRITE et _ABAP_PRINT_INT, helpers runtime.
            Rapport de compilation : 0 erreurs, N symboles, M formes.
            => TODO 25
*)

Program ABAP86;

{$A-}
{$I-}

Uses DOS;

Procedure Test;begin
  
End;

BEGIN
END.