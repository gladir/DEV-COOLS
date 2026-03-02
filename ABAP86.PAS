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

{ ============================================================================ }
{ TODO 01 - Architecture, constantes, types de base, utilitaires [COMPLET]    }
{ ============================================================================ }

Const
 VERSION = 'ABAP86 V1.0';

 { ---- Types de tokens ABAP ---- }
 TOK_UNKNOWN  =  0;
 TOK_IDENT    =  1;   { identificateur / mot-cle                  }
 TOK_NUMBER   =  2;   { litterale entiere  : 123                  }
 TOK_FLOAT    =  3;   { litterale decimale : 1.5 / 1E3            }
 TOK_STRING   =  4;   { 'texte' (apostrophe doublee '')           }
 TOK_PLUS     =  5;   { +                                         }
 TOK_MINUS    =  6;   { -                                         }
 TOK_STAR     =  7;   { *                                         }
 TOK_SLASH    =  8;   { /  (aussi separateur WRITE)               }
 TOK_LPAREN   =  9;   { (                                         }
 TOK_RPAREN   = 10;   { )                                         }
 TOK_COMMA    = 11;   { ,                                         }
 TOK_DOT      = 12;   { .  (terminateur d'instruction)            }
 TOK_COLON    = 13;   { :  (declaration DATA: ... )               }
 TOK_EQ       = 14;   { =  (affectation et comparaison)           }
 TOK_NE       = 15;   { <> (different)                            }
 TOK_LT       = 16;   { <                                         }
 TOK_GT       = 17;   { >                                         }
 TOK_LE       = 18;   { <=                                        }
 TOK_GE       = 19;   { >=                                        }
 TOK_CONCAT   = 20;   { && (concatenation expressions)            }
 TOK_LBRACKET = 21;   { [  (indice tableau)                       }
 TOK_RBRACKET = 22;   { ]                                         }
 TOK_HASH     = 23;   { #  (debut pragma)                         }
 TOK_PIPE     = 24;   { |  (chaine template ABAP 7.4, stub)       }
 TOK_AT       = 25;   { @  (reference inline ABAP 7.4, stub)      }
 TOK_EOF      = 99;

 { ---- Types de donnees ABAP ---- }
 TYPE_UNKNOWN  =  0;
 TYPE_I        =  1;   { I        : entier 16 bits (ici 2 octets) }
 TYPE_F        =  2;   { F        : flottant 8 octets (stub)      }
 TYPE_C        =  3;   { C(n)     : chaine de longueur fixe       }
 TYPE_N        =  4;   { N(n)     : chaine numerique (texte)      }
 TYPE_D        =  5;   { D        : date 8 chars YYYYMMDD         }
 TYPE_T        =  6;   { T        : heure 6 chars HHMMSS          }
 TYPE_P        =  7;   { P        : packed decimal (stub)         }
 TYPE_STRING   =  8;   { STRING   : chaine longueur variable       }
 TYPE_XSTRING  =  9;   { XSTRING  : octetstring (stub)            }
 TYPE_TABLE    = 10;   { TABLE OF : table interne                 }
 TYPE_STRUCT   = 11;   { structure (BEGIN OF ... END OF)          }
 TYPE_REF      = 12;   { REF TO   : reference objet (stub)        }
 TYPE_VOID     = 13;   { pas de type de retour (FORM/EVENT)       }

 { ---- Classes de stockage ---- }
 STORE_AUTO     = 0;   { variable locale FORM (pile, offset BP)   }
 STORE_STATIC   = 1;   { variable globale REPORT (segment .DATA)  }
 STORE_PARAM    = 2;   { parametre USING/CHANGING d'une FORM      }
 STORE_TABLE    = 3;   { table interne (tableau en .DATA)         }
 STORE_CONSTANT = 4;   { CONSTANTS (valeur immediate, pas de DW) }

 { ---- Codes des mots-cles ABAP ---- }
 KW_NONE            =   0;
 KW_REPORT          =   1;
 KW_PROGRAM         =   2;
 KW_DATA            =   3;
 KW_TYPES           =   4;
 KW_CONSTANTS       =   5;
 KW_CLASS_DATA      =   6;
 KW_IF              =   7;
 KW_ELSEIF          =   8;
 KW_ELSE            =   9;
 KW_ENDIF           =  10;
 KW_CASE            =  11;
 KW_WHEN            =  12;
 KW_OTHERS          =  13;
 KW_ENDCASE         =  14;
 KW_WHILE           =  15;
 KW_ENDWHILE        =  16;
 KW_DO              =  17;
 KW_TIMES           =  18;
 KW_ENDDO           =  19;
 KW_LOOP            =  20;
 KW_AT              =  21;
 KW_INTO            =  22;
 KW_ENDLOOP         =  23;
 KW_FORM            =  24;
 KW_ENDFORM         =  25;
 KW_PERFORM         =  26;
 KW_USING           =  27;
 KW_CHANGING        =  28;
 KW_TABLES          =  29;
 KW_FUNCTION        =  30;
 KW_ENDFUNCTION     =  31;
 KW_WRITE           =  32;
 KW_SKIP            =  33;
 KW_LINE            =  34;
 KW_NEW_LINE        =  35;
 KW_MOVE            =  36;
 KW_TO              =  37;
 KW_MOVE_CORR       =  38;
 KW_COMPUTE         =  39;
 KW_ADD             =  40;
 KW_SUBTRACT        =  41;
 KW_MULTIPLY        =  42;
 KW_BY              =  43;
 KW_DIVIDE          =  44;
 KW_FROM            =  45;
 KW_GIVING          =  46;
 KW_APPEND          =  47;
 KW_INSERT          =  48;
 KW_DELETE          =  49;
 KW_MODIFY          =  50;
 KW_READ            =  51;
 KW_SORT            =  52;
 KW_COLLECT         =  53;
 KW_SELECT          =  54;
 KW_WHERE           =  55;
 KW_CORRESPONDING   =  56;
 KW_FIELDS          =  57;
 KW_ENDSELECT       =  58;
 KW_CALL            =  59;
 KW_RAISING         =  60;
 KW_EXCEPTIONS      =  61;
 KW_SINGLE          =  62;
 KW_CLEAR           =  63;
 KW_REFRESH         =  64;
 KW_FREE            =  65;
 KW_INITIALIZE      =  66;
 KW_CONCATENATE     =  67;
 KW_SPLIT           =  68;
 KW_SHIFT           =  69;
 KW_REPLACE         =  70;
 KW_TRANSLATE       =  71;
 KW_CONDENSE        =  72;
 KW_FIND            =  73;
 KW_CHECK           =  74;
 KW_RETURN          =  75;
 KW_EXIT            =  76;
 KW_STOP            =  77;
 KW_CONTINUE        =  78;
 KW_START_OF_SEL    =  79;   { START-OF-SELECTION }
 KW_END_OF_SEL      =  80;   { END-OF-SELECTION   }
 KW_TOP_OF_PAGE     =  81;
 KW_END_OF_PAGE     =  82;
 KW_PARAMETERS      =  83;
 KW_SELECT_OPTIONS  =  84;
 KW_LIKE            =  85;
 KW_TYPE            =  86;
 KW_VALUE           =  87;
 KW_DEFAULT         =  88;
 KW_CLASS           =  89;
 KW_ENDCLASS        =  90;
 KW_METHOD          =  91;
 KW_ENDMETHOD       =  92;
 KW_PUBLIC          =  93;
 KW_PRIVATE         =  94;
 KW_PROTECTED       =  95;
 KW_RAISE           =  96;
 KW_EXCEPTION       =  97;
 KW_TRY             =  98;
 KW_CATCH           =  99;
 KW_CLEANUP         = 100;
 KW_ENDTRY          = 101;
 KW_EQ              = 102;   { EQ (comparaison verbale) }
 KW_NE              = 103;   { NE                       }
 KW_LT              = 104;   { LT                       }
 KW_GT              = 105;   { GT                       }
 KW_LE              = 106;   { LE                       }
 KW_GE              = 107;   { GE                       }
 KW_BETWEEN         = 108;
 KW_IN              = 109;
 KW_AND             = 110;
 KW_OR              = 111;
 KW_NOT             = 112;
 KW_IS              = 113;
 KW_INITIAL         = 114;
 KW_BOUND           = 115;
 KW_ASCENDING       = 116;
 KW_DESCENDING      = 117;
 KW_LEFT            = 118;
 KW_RIGHT           = 119;
 KW_UPPER           = 120;   { UPPER CASE }
 KW_LOWER           = 121;   { LOWER CASE }
 KW_NO_GAPS         = 122;   { NO-GAPS    }
 KW_MATCH           = 123;
 KW_OFFSET          = 124;
 KW_OCCURRENCE      = 125;
 KW_OCCURRENCES     = 126;
 KW_SEPARATED       = 127;
 KW_LINE_SEL        = 128;   { LINE-SELECTION  }
 KW_USER_CMD        = 129;   { USER-COMMAND    }
 KW_OF              = 130;
 KW_BEGIN           = 131;
 KW_END             = 132;
 KW_TABLE           = 133;
 KW_WITH            = 134;
 KW_KEY             = 135;
 KW_INDEX           = 136;
 KW_DECIMALS        = 137;
 KW_LENGTH          = 138;
 KW_MESSAGE_ID      = 139;
 KW_STRLEN          = 140;
 KW_ABS             = 141;
 KW_CASE_UPPER      = 142;   { UPPER CASE (suite de TRANSLATE) }
 KW_CASE_LOWER      = 143;   { LOWER CASE                      }
 KW_ROWS            = 144;   { UP TO n ROWS (SELECT)           }
 KW_EXPORTING       = 145;
 KW_IMPORTING       = 146;
 KW_ORDER           = 147;
 KW_CIRCULAR        = 148;
 KW_PLACES          = 149;
 KW_ALL             = 150;
 KW_FIRST           = 151;

 { ---- Types de parametre FORM (USING / CHANGING / TABLES) ---- }
 PARAM_USING    = 0;   { passage par valeur             }
 PARAM_CHANGING = 1;   { passage par adresse (ref)      }
 PARAM_TABLES   = 2;   { table interne (adresse)        }

 { ---- Types d'evenements ABAP ---- }
 EV_START_OF_SEL = 0;
 EV_END_OF_SEL   = 1;
 EV_TOP_OF_PAGE  = 2;
 EV_END_OF_PAGE  = 3;
 EV_LINE_SEL     = 4;
 EV_USER_CMD     = 5;

 { ---- Scopes ---- }
 SK_GLOBAL  = 0;
 SK_FORM    = 1;
 SK_BLOCK   = 2;
 SK_LOOP    = 3;
 SK_EVENT   = 4;

 { ---- Limites ---- }
 MAX_SYM    = 512;    { Variables + labels max               }
 MAX_FORM   = 128;    { FORMs + FUNCTIONs max                }
 MAX_LOCAL  = 64;     { Variables locales par scope          }
 MAX_PARAM  = 20;     { Parametres max par FORM              }
 MAX_DEPTH  = 24;     { Profondeur de scope max              }
 MAX_LABEL  = 9999;   { Limite compteur labels ASM           }
 MAX_STR    = 256;    { Litteraux chaines max                }
 MAX_FIELD  = 32;     { Champs max par structure             }
 MAX_EVTS   = 8;      { Evenements ABAP max                  }

{ ============================================================================ }
{ TYPES                                                                        }
{ ============================================================================ }

Type
 { ----- Entree de la table des symboles ----- }
 TSymEntry = Record
  name        : String[48];   { Nom ABAP (upper-case)             }
  asm_label   : String[48];   { Etiquette ASM : _VAR_nom          }
  data_type   : Integer;       { TYPE_xxx                         }
  store_class : Integer;       { STORE_xxx                        }
  bp_offset   : Integer;       { offset BP si SK_FORM (negatif)   }
  array_size  : Integer;       { 0 si scalaire, n si table        }
  char_len    : Integer;       { longueur TYPE C(n) ou N(n)       }
  dec_prec    : Integer;       { precision TYPE P / F             }
  dec_scale   : Integer;       { DECIMALS n pour TYPE P           }
  is_param    : Boolean;       { True si parametre de FORM        }
  param_idx   : Integer;       { index du parametre (1-base)      }
  param_kind  : Integer;       { PARAM_USING / CHANGING / TABLES  }
  init_str    : String[64];   { valeur VALUE en chaine           }
  init_num    : LongInt;       { valeur VALUE numerique           }
  has_init    : Boolean;       { True si VALUE specifie           }
  is_const    : Boolean;       { True si CONSTANTS                }
  scope_lev   : Integer;       { niveau de scope (0 = global)     }
 End;

 { ----- Entree de la table des FORMs / FUNCTIONs ----- }
 TFormEntry = Record
  name          : String[48];
  asm_label     : String[48];   { ex: _ABAP_FORM_nomform       }
  param_count   : Integer;       { total USING + CHANGING       }
  using_count   : Integer;
  changing_count: Integer;
  tables_count  : Integer;
  defined       : Boolean;
  is_function   : Boolean;       { True si FUNCTION vs FORM     }
  param_names   : Array[1..MAX_PARAM] of String[48];
  param_kinds   : Array[1..MAX_PARAM] of Integer;   { PARAM_xxx }
  param_types   : Array[1..MAX_PARAM] of Integer;   { TYPE_xxx  }
 End;

 { ----- Scope (frame de compilation) ----- }
 TScopeEntry = Record
  kind        : Integer;         { SK_xxx                        }
  form_idx    : Integer;         { index dans form_table si FORM }
  bp_top      : Integer;         { prochain offset BP negatif    }
  sym_start   : Integer;         { premier sym index du scope    }
  sym_end     : Integer;         { dernier sym index du scope    }
  lbl_exit    : String[32];     { label de sortie (EXIT/RETURN) }
  lbl_cont    : String[32];     { label continue (LOOP/WHILE)   }
  lbl_end     : String[32];     { label fin de bloc (ENDLOOP..) }
 End;

 { ----- Litterale chaine ----- }
 TStrEntry = Record
  text        : String;
  asm_label   : String[32];
 End;

 { ----- Evenement ABAP (START-OF-SELECTION etc.) ----- }
 TEventEntry = Record
  ev_kind     : Integer;         { EV_xxx                        }
  asm_label   : String[48];
  defined     : Boolean;
 End;

{ ============================================================================ }
{ VARIABLES GLOBALES                                                           }
{ ============================================================================ }

Var
 { --- Fichiers --- }
 source_filename  : String;
 output_filename  : String;
 input_file       : Text;
 output_file      : Text;

 { --- Options --- }
 opt_verbose  : Boolean;
 opt_dump_tok : Boolean;

 { --- Etat du tokeniseur --- }
 src_line     : String;
 src_line_num : Integer;
 src_col      : Integer;
 src_eof      : Boolean;
 cur_tok_type : Integer;
 cur_tok_str  : String;
 cur_tok_num  : LongInt;
 cur_tok_kw   : Integer;   { KW_xxx si cur_tok_type = TOK_IDENT }
 peek_char    : Char;
 has_peek     : Boolean;
 cur_column   : Integer;   { colonne courante (1-base, pour * col1) }

 { --- Nom du programme (REPORT / PROGRAM) --- }
 prog_name    : String;

 { --- Tables --- }
 sym_table    : Array[1..MAX_SYM]  of TSymEntry;
 sym_count    : Integer;
 form_table   : Array[1..MAX_FORM] of TFormEntry;
 form_count   : Integer;
 str_table    : Array[1..MAX_STR]  of TStrEntry;
 str_count    : Integer;
 evt_table    : Array[0..MAX_EVTS] of TEventEntry;
 evt_count    : Integer;

 { --- Scope --- }
 scope_stack  : Array[0..MAX_DEPTH] of TScopeEntry;
 scope_top    : Integer;

 { --- Generateur de code --- }
 label_counter : Integer;
 lit_counter   : Integer;
 gen_enabled   : Boolean;
 error_count   : Integer;

{ ============================================================================ }
{ TODO 01 - Utilitaires de base                          [COMPLET]            }
{ ============================================================================ }

{ Conversion entier -> chaine (LongInt) }
Function ItoS(n: LongInt): String;
Var s: String;
Begin Str(n, s); ItoS := s; End;

{ Conversion entier -> chaine (Integer) }
Function ItoSI(n: Integer): String;
Var s: String;
Begin Str(n, s); ItoSI := s; End;

{ Conversion en majuscules }
Function UpCaseStr(Const s: String): String;
Var i: Integer; r: String;
Begin
 r := s;
 For i := 1 to Length(r) do
  If (r[i] >= 'a') And (r[i] <= 'z') Then
   r[i] := Chr(Ord(r[i]) - 32);
 UpCaseStr := r;
End;

{ Traduit un nom ABAP en etiquette ASM valide (prefixe + name) }
{ Les - et _ sont remplaces par _ ; les autres par X           }
Function AsmIdent(Const prefix, name: String): String;
Var i: Integer; r: String; c: Char;
Begin
 r := prefix;
 For i := 1 to Length(name) do
 Begin
  c := name[i];
  Case c Of
   'A'..'Z','0'..'9': r := r + c;
   'a'..'z': r := r + Chr(Ord(c) - 32);
   '_','-': r := r + '_';
  Else  r := r + 'X';
  End;
 End;
 AsmIdent := r;
End;

{ Pad un numero de label avec des zeros a gauche (ex: 0042) }
Function PadLabel(n: Integer): String;
Var s: String;
Begin
 Str(n, s);
 While Length(s) < 4 do s := '0' + s;
 PadLabel := s;
End;

{ Genere un nouveau label unique (ex: @@L0042) }
Function NewLabel: String;
Begin
 Inc(label_counter);
 NewLabel := '@@L' + PadLabel(label_counter);
End;

{ Signale une erreur fatale et incremente le compteur }
Procedure Error(Const msg: String);
Begin
 WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg);
 Inc(error_count);
End;

{ Emet un avertissement (non fatal) }
Procedure Warning(Const msg: String);
Begin
 WriteLn('ATTENTION (ligne ', src_line_num, ') : ', msg);
End;

{ Emetteur ASM : ecrire une ligne dans le fichier de sortie }
Procedure Emit(Const s: String);
Begin
 WriteLn(output_file, s);
End;

{ Emet une etiquette ASM seule (col 1) }
Procedure EmitLabel(Const lbl: String);
Begin
 WriteLn(output_file, lbl + ':');
End;

{ Emet une instruction avec tabulation }
Procedure EmitI(Const s: String);
Begin
 WriteLn(output_file, '        ' + s);
End;

{ Emet un commentaire ASM }
Procedure EmitComment(Const s: String);
Begin
 WriteLn(output_file, '; ' + s);
End;

{ Emet une ligne vide }
Procedure EmitBlank;
Begin
 WriteLn(output_file, '');
End;

{ Ajoute une litterale chaine dans str_table, retourne son label }
Function AddStringLit(Const s: String): String;
Var lbl: String;
Begin
 Inc(str_count);
 Inc(lit_counter);
 lbl := '_LS' + ItoSI(lit_counter);
 str_table[str_count].text      := s;
 str_table[str_count].asm_label := lbl;
 AddStringLit := lbl;
End;

{ Initialisation de toutes les variables globales }
Procedure InitAll;
Var i: Integer;
Begin
 sym_count    := 0;
 form_count   := 0;
 str_count    := 0;
 evt_count    := 0;
 label_counter:= 0;
 lit_counter  := 0;
 error_count  := 0;
 scope_top    := 0;
 gen_enabled  := True;
 opt_verbose  := False;
 opt_dump_tok := False;
 prog_name    := 'ZPROGRAM';
 src_line     := '';
 src_line_num := 0;
 src_col      := 1;
 cur_column   := 1;
 src_eof      := False;
 has_peek     := False;
 peek_char    := #0;
 cur_tok_type := TOK_UNKNOWN;
 cur_tok_str  := '';
 cur_tok_num  := 0;
 cur_tok_kw   := KW_NONE;
 { Init scope global }
 scope_stack[0].kind      := SK_GLOBAL;
 scope_stack[0].form_idx  := 0;
 scope_stack[0].bp_top    := 0;
 scope_stack[0].sym_start := 1;
 scope_stack[0].sym_end   := 0;
 scope_stack[0].lbl_exit  := '';
 scope_stack[0].lbl_cont  := '';
 scope_stack[0].lbl_end   := '';
 { Init index evenements }
 For i := 0 to MAX_EVTS do
 Begin
  evt_table[i].ev_kind   := i;
  evt_table[i].defined   := False;
  evt_table[i].asm_label := '';
 End;
End;

{ ============================================================================ }
{ TODO 02 - TOKENISEUR ABAP                              [COMPLET]            }
{ ============================================================================ }

{ Lit le prochain caractere brut depuis la source.
  Gere le chargement ligne par ligne et le peek buffer.
  Met a jour src_col (position dans la ligne courante).
  Retourne #0 a la fin du fichier.                                            }
Function SrcGetChar: Char;
Begin
 { Priorite au peek buffer }
 If has_peek Then
 Begin
  SrcGetChar := peek_char;
  has_peek   := False;
  Inc(src_col);
  Exit;
 End;
 If src_eof Then Begin SrcGetChar := #0; Exit; End;
 { Tant qu'on a depasse la fin de la ligne courante, charger la suivante }
 While src_col > Length(src_line) Do
 Begin
  If EOF(input_file) Then
  Begin src_eof := True; SrcGetChar := #0; Exit; End;
  ReadLn(input_file, src_line);
  Inc(src_line_num);
  src_col    := 1;
  cur_column := 1;
  { Commentaire ABAP : ligne commencant par '*' en colonne 1 -> sauter }
  If (Length(src_line) > 0) And (src_line[1] = '*') Then
  Begin
   { On saute toute la ligne : on simule un retour de fin de ligne }
   src_col := Length(src_line) + 1;
   Continue;
  End;
  { Retourner un espace synthetique entre les lignes }
  SrcGetChar := ' ';
  Exit;
 End;
 SrcGetChar := src_line[src_col];
 cur_column := src_col;
 Inc(src_col);
End;

{ Lit le prochain caractere sans le consommer (un seul niveau de peek) }
Function SrcPeekChar: Char;
Var ch: Char;
Begin
 If has_peek Then Begin SrcPeekChar := peek_char; Exit; End;
 ch := SrcGetChar;
 If ch = #0 Then Begin SrcPeekChar := #0; Exit; End;
 { On remet le car dans le buffer ; on repositionne src_col }
 has_peek   := True;
 peek_char  := ch;
 Dec(src_col);
 SrcPeekChar := ch;
End;

{ Prototype anticipe pour IsKeyword (defini au TODO 03) }
Function IsKeyword(Const s: String): Integer; Forward;

{ Prototype anticipe pour NextToken (utilise dans InitTokenizer) }
Procedure NextToken; Forward;

{ Initialise le tokeniseur et lit le premier token }
Procedure InitTokenizer;
Begin
 src_line_num := 0;
 src_col      := 1;
 cur_column   := 1;
 src_eof      := False;
 has_peek     := False;
 peek_char    := #0;
 cur_tok_type := TOK_UNKNOWN;
 cur_tok_str  := '';
 cur_tok_num  := 0;
 cur_tok_kw   := KW_NONE;
 src_line     := '';
 If EOF(input_file) Then src_eof := True
 Else
 Begin
  ReadLn(input_file, src_line);
  src_line_num := 1;
  src_col      := 1;
  cur_column   := 1;
  { Sauter d'emblee une ligne de commentaire * en col 1 }
  While (Length(src_line) > 0) And (src_line[1] = '*') Do
  Begin
   If EOF(input_file) Then Begin src_eof := True; Break; End;
   ReadLn(input_file, src_line);
   Inc(src_line_num);
  End;
 End;
 NextToken;
End;

{ Jette le token courant et lit le suivant }
Procedure Consume;
Begin NextToken; End;

{ Verifie que le token courant est de type tt, sinon erreur, puis consomme }
Procedure Expect(tt: Integer; Const what: String);
Begin
 If cur_tok_type <> tt Then
  Error('Attendu ' + what + ', trouve : ''' + cur_tok_str + '''');
 Consume;
End;

{ True si le token courant est le mot-cle ABAP kw }
Function TokIsKw(kw: Integer): Boolean;
Begin
 TokIsKw := (cur_tok_type = TOK_IDENT) And (cur_tok_kw = kw);
End;

{ Consomme si le token courant est le mot-cle kw (retourne True si consomme) }
Function EatKw(kw: Integer): Boolean;
Begin
 If TokIsKw(kw) Then Begin Consume; EatKw := True; End
 Else EatKw := False;
End;

{ Verifie et consomme le mot-cle ABAP kw, sinon signale une erreur  }
Procedure ExpectKw(kw: Integer; Const what: String);
Begin
 If Not TokIsKw(kw) Then
  Error('Attendu ' + what + ', trouve : ''' + cur_tok_str + '''');
 Consume;
End;

{ Sauter jusqu'au prochain '.' (fin d'instruction) inclus }
Procedure SkipToDot;
Begin
 While (cur_tok_type <> TOK_DOT) And (cur_tok_type <> TOK_EOF) Do
  Consume;
 If cur_tok_type = TOK_DOT Then Consume;
End;

{ Analyseur lexical principal : produit le prochain token ABAP.
  Specificites ABAP :
  - Commentaire '*' en colonne 1 (detecte dans SrcGetChar)
  - Commentaire '"' en milieu de ligne -> sauter jusqu'a fin de ligne
  - Terminateur d'instruction : '.'
  - Operateur NE : '<>'
  - Operateur CONCAT : '&&'
  - Chaines : '...' avec apostrophe doublee ''
  - Identificateurs : lettres/chiffres/_/-, kw reunis par '-'
    ex: SY-SUBRC, START-OF-SELECTION (lus comme un seul ident)
  - Litteraux flottants : 1.5, 1E3 (le '.' suivi d'un chiffre)    }
Procedure NextToken;
Var c, c2: Char; s: String; n: LongInt; flt: Boolean;
Begin
 cur_tok_str := '';
 cur_tok_num := 0;
 cur_tok_kw  := KW_NONE;
 flt         := False;
 { ---- Sauter espaces, TAB, CR, LF et commentaires ---- }
 Repeat
  c := SrcPeekChar;
  If c = #0 Then Break;
  { Espaces et separateurs }
  If (c = ' ') Or (c = #9) Or (c = #13) Or (c = #10) Then
  Begin SrcGetChar; Continue; End;
  { Commentaire inline ABAP : " jusqu'a fin de ligne }
  If c = '"' Then
  Begin
   { Sauter jusqu'a la fin de la ligne source courante }
   While (src_col <= Length(src_line)) Do SrcGetChar;
   Continue;
  End;
  Break;
 Until False;
 { ---- EOF ---- }
 If SrcPeekChar = #0 Then
 Begin
  cur_tok_type := TOK_EOF;
  cur_tok_str  := 'EOF';
  Exit;
 End;
 c := SrcGetChar;
 { ---- Separateurs simples ---- }
 Case c Of
  '(': Begin cur_tok_type := TOK_LPAREN;   cur_tok_str := '('; Exit; End;
  ')': Begin cur_tok_type := TOK_RPAREN;   cur_tok_str := ')'; Exit; End;
  '[': Begin cur_tok_type := TOK_LBRACKET; cur_tok_str := '['; Exit; End;
  ']': Begin cur_tok_type := TOK_RBRACKET; cur_tok_str := ']'; Exit; End;
  ',': Begin cur_tok_type := TOK_COMMA;    cur_tok_str := ','; Exit; End;
  '.': Begin cur_tok_type := TOK_DOT;      cur_tok_str := '.'; Exit; End;
  ':': Begin cur_tok_type := TOK_COLON;    cur_tok_str := ':'; Exit; End;
  '+': Begin cur_tok_type := TOK_PLUS;     cur_tok_str := '+'; Exit; End;
  '/': Begin cur_tok_type := TOK_SLASH;    cur_tok_str := '/'; Exit; End;
  '@': Begin cur_tok_type := TOK_AT;       cur_tok_str := '@'; Exit; End;
  '#': Begin cur_tok_type := TOK_HASH;     cur_tok_str := '#'; Exit; End;
  { '-' : operateur soustraction OU separateur dans un ident -->
    on decide apres avoir vu ce qu'il y a apres                    }
  '-': Begin cur_tok_type := TOK_MINUS; cur_tok_str := '-'; Exit; End;
  { '*' : multiplication (la detection col-1 est faite dans SrcGetChar) }
  '*': Begin cur_tok_type := TOK_STAR;  cur_tok_str := '*'; Exit; End;
  { '=' : affectation / egalite (contexte decide par le parseur) }
  '=': Begin cur_tok_type := TOK_EQ;   cur_tok_str := '='; Exit; End;
  { '<' et '<>' }
  '<': Begin
        c2 := SrcPeekChar;
        If c2 = '>' Then
        Begin SrcGetChar; cur_tok_type := TOK_NE; cur_tok_str := '<>'; End
        Else If c2 = '=' Then
        Begin SrcGetChar; cur_tok_type := TOK_LE; cur_tok_str := '<='; End
        Else Begin cur_tok_type := TOK_LT; cur_tok_str := '<'; End;
        Exit;
       End;
  { '>' et '>=' }
  '>': Begin
        c2 := SrcPeekChar;
        If c2 = '=' Then
        Begin SrcGetChar; cur_tok_type := TOK_GE; cur_tok_str := '>='; End
        Else Begin cur_tok_type := TOK_GT; cur_tok_str := '>'; End;
        Exit;
       End;
  { '&&' concatenation ABAP expression ou '&' seul (pragma) }
  '&': Begin
        If SrcPeekChar = '&' Then
        Begin SrcGetChar; cur_tok_type := TOK_CONCAT; cur_tok_str := '&&'; End
        Else Begin cur_tok_type := TOK_UNKNOWN; cur_tok_str := '&'; End;
        Exit;
       End;
  { '|' : debut de template string ABAP 7.4 - stub : on lit jusqu'a '|' }
  '|': Begin
        s := '';
        Repeat
         c2 := SrcGetChar;
         If (c2 = '|') Or (c2 = #0) Then Break;
         s := s + c2;
        Until False;
        cur_tok_type := TOK_STRING;
        cur_tok_str  := s;
        Exit;
       End;
  { Chaine ABAP : '...' avec '' pour apostrophe interieure }
  '''': Begin
         s := '';
         Repeat
          c2 := SrcGetChar;
          If c2 = #0 Then Begin Error('Chaine non terminee'); Break; End;
          If c2 = '''' Then
          Begin
           If SrcPeekChar = '''' Then
           Begin SrcGetChar; s := s + ''''; End  { apostrophe doublee }
           Else Break;                             { fin de la chaine  }
          End Else s := s + c2;
         Until False;
         cur_tok_type := TOK_STRING;
         cur_tok_str  := s;
         Exit;
        End;
 End; { Case }

 { ---- Litteraux numeriques ---- }
 If (c >= '0') And (c <= '9') Then
 Begin
  n := Ord(c) - 48;
  { Partie entiere }
  While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do
   n := n * 10 + (Ord(SrcGetChar) - 48);
  { Partie decimale : '.' suivi d'un chiffre = flottant }
  If (SrcPeekChar = '.') Then
  Begin
   { On regarde un caractere de plus pour voir si c'est un chiffre }
   SrcGetChar; { consomme le '.' }
   If (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Then
   Begin
    flt := True;
    While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do SrcGetChar;
   End Else
   Begin
    { Ce '.' etait le terminateur d'instruction -> le remettre }
    has_peek   := True;
    peek_char  := '.';
    Dec(src_col);
   End;
  End;
  { Exposant E/e (stub : ignorer la valeur, float seulement) }
  If (SrcPeekChar = 'E') Or (SrcPeekChar = 'e') Then
  Begin SrcGetChar; flt := True;
   If (SrcPeekChar = '+') Or (SrcPeekChar = '-') Then SrcGetChar;
   While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do SrcGetChar;
  End;
  If flt Then cur_tok_type := TOK_FLOAT
  Else         cur_tok_type := TOK_NUMBER;
  cur_tok_num := n;
  cur_tok_str := ItoS(n);
  Exit;
 End;

 { ---- Identificateurs et mots-cles ABAP ---- }
 If ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or (c = '_') Then
 Begin
  s := UpCase(c);
  Repeat
   c2 := SrcPeekChar;
   { Caractere standard d'identificateur }
   If ((c2 >= 'A') And (c2 <= 'Z')) Or ((c2 >= 'a') And (c2 <= 'z')) Or
      (c2 = '_') Or ((c2 >= '0') And (c2 <= '9')) Then
   Begin
    s := s + UpCase(SrcGetChar);
    Continue;
   End;
   { '-' : fait partie de l'ident si la lettre suivante est alpha :
     ex: SY-SUBRC, START-OF-SELECTION, NEW-LINE, NO-GAPS...
     on consomme le '-' et la suite seulement si next est alpha/_ }
   If c2 = '-' Then
   Begin
    { peek un caractere de plus }
    SrcGetChar; { consomme '-' }
    c2 := SrcPeekChar;
    If ((c2 >= 'A') And (c2 <= 'Z')) Or ((c2 >= 'a') And (c2 <= 'z')) Or (c2 = '_') Then
    Begin
     s := s + '-'; { le '-' fait partie du nom compose }
     Continue;
    End Else
    Begin
     { Le '-' etait l'operateur soustraction : le remettre dans le flux }
     has_peek  := True;
     peek_char := '-';
     Dec(src_col);
     Break;
    End;
   End;
   Break;
  Until False;
  cur_tok_type := TOK_IDENT;
  cur_tok_str  := s;
  cur_tok_kw   := IsKeyword(s);
  Exit;
 End;

 { ---- Caractere inconnu ---- }
 cur_tok_type := TOK_UNKNOWN;
 cur_tok_str  := c;
End;

{ ============================================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES ABAP/4          [COMPLET]            }
{ ============================================================================ }

{ Retourne le code KW_xxx correspondant au nom ABAP (deja en majuscules),
  ou KW_NONE si ce n'est pas un mot-cle.
  Les identificateurs composes (ex: START-OF-SELECTION, NO-GAPS) sont lus
  par le lexer comme un seul token grace a la regle du '-' inter-alpha.      }
Function IsKeyword(Const s: String): Integer;
Begin
 { ---- Structure du programme ---- }
 If s = 'REPORT'              Then Begin IsKeyword := KW_REPORT;        Exit; End;
 If s = 'PROGRAM'             Then Begin IsKeyword := KW_PROGRAM;       Exit; End;
 { ---- Declarations ---- }
 If s = 'DATA'                Then Begin IsKeyword := KW_DATA;          Exit; End;
 If s = 'TYPES'               Then Begin IsKeyword := KW_TYPES;         Exit; End;
 If s = 'CONSTANTS'           Then Begin IsKeyword := KW_CONSTANTS;     Exit; End;
 If s = 'CLASS-DATA'          Then Begin IsKeyword := KW_CLASS_DATA;    Exit; End;
 { ---- IF / CASE ---- }
 If s = 'IF'                  Then Begin IsKeyword := KW_IF;            Exit; End;
 If s = 'ELSEIF'              Then Begin IsKeyword := KW_ELSEIF;        Exit; End;
 If s = 'ELSE'                Then Begin IsKeyword := KW_ELSE;          Exit; End;
 If s = 'ENDIF'               Then Begin IsKeyword := KW_ENDIF;         Exit; End;
 If s = 'CASE'                Then Begin IsKeyword := KW_CASE;          Exit; End;
 If s = 'WHEN'                Then Begin IsKeyword := KW_WHEN;          Exit; End;
 If s = 'OTHERS'              Then Begin IsKeyword := KW_OTHERS;        Exit; End;
 If s = 'ENDCASE'             Then Begin IsKeyword := KW_ENDCASE;       Exit; End;
 { ---- Boucles ---- }
 If s = 'WHILE'               Then Begin IsKeyword := KW_WHILE;         Exit; End;
 If s = 'ENDWHILE'            Then Begin IsKeyword := KW_ENDWHILE;      Exit; End;
 If s = 'DO'                  Then Begin IsKeyword := KW_DO;            Exit; End;
 If s = 'TIMES'               Then Begin IsKeyword := KW_TIMES;         Exit; End;
 If s = 'ENDDO'               Then Begin IsKeyword := KW_ENDDO;         Exit; End;
 If s = 'LOOP'                Then Begin IsKeyword := KW_LOOP;          Exit; End;
 If s = 'AT'                  Then Begin IsKeyword := KW_AT;            Exit; End;
 If s = 'INTO'                Then Begin IsKeyword := KW_INTO;          Exit; End;
 If s = 'ENDLOOP'             Then Begin IsKeyword := KW_ENDLOOP;       Exit; End;
 { ---- Sous-routines FORM ---- }
 If s = 'FORM'                Then Begin IsKeyword := KW_FORM;          Exit; End;
 If s = 'ENDFORM'             Then Begin IsKeyword := KW_ENDFORM;       Exit; End;
 If s = 'PERFORM'             Then Begin IsKeyword := KW_PERFORM;       Exit; End;
 If s = 'USING'               Then Begin IsKeyword := KW_USING;         Exit; End;
 If s = 'CHANGING'            Then Begin IsKeyword := KW_CHANGING;      Exit; End;
 If s = 'TABLES'              Then Begin IsKeyword := KW_TABLES;        Exit; End;
 { ---- Modules de fonction ---- }
 If s = 'FUNCTION'            Then Begin IsKeyword := KW_FUNCTION;      Exit; End;
 If s = 'ENDFUNCTION'         Then Begin IsKeyword := KW_ENDFUNCTION;   Exit; End;
 { ---- Sortie / Affichage ---- }
 If s = 'WRITE'               Then Begin IsKeyword := KW_WRITE;         Exit; End;
 If s = 'SKIP'                Then Begin IsKeyword := KW_SKIP;          Exit; End;
 If s = 'LINE'                Then Begin IsKeyword := KW_LINE;          Exit; End;
 If s = 'NEW-LINE'            Then Begin IsKeyword := KW_NEW_LINE;      Exit; End;
 { ---- Affectation / Calcul ---- }
 If s = 'MOVE'                Then Begin IsKeyword := KW_MOVE;          Exit; End;
 If s = 'TO'                  Then Begin IsKeyword := KW_TO;            Exit; End;
 If s = 'MOVE-CORRESPONDING'  Then Begin IsKeyword := KW_MOVE_CORR;     Exit; End;
 If s = 'COMPUTE'             Then Begin IsKeyword := KW_COMPUTE;       Exit; End;
 If s = 'ADD'                 Then Begin IsKeyword := KW_ADD;           Exit; End;
 If s = 'SUBTRACT'            Then Begin IsKeyword := KW_SUBTRACT;      Exit; End;
 If s = 'MULTIPLY'            Then Begin IsKeyword := KW_MULTIPLY;      Exit; End;
 If s = 'BY'                  Then Begin IsKeyword := KW_BY;            Exit; End;
 If s = 'DIVIDE'              Then Begin IsKeyword := KW_DIVIDE;        Exit; End;
 If s = 'FROM'                Then Begin IsKeyword := KW_FROM;          Exit; End;
 If s = 'GIVING'              Then Begin IsKeyword := KW_GIVING;        Exit; End;
 { ---- Operations sur tables internes ---- }
 If s = 'APPEND'              Then Begin IsKeyword := KW_APPEND;        Exit; End;
 If s = 'INSERT'              Then Begin IsKeyword := KW_INSERT;        Exit; End;
 If s = 'DELETE'              Then Begin IsKeyword := KW_DELETE;        Exit; End;
 If s = 'MODIFY'              Then Begin IsKeyword := KW_MODIFY;        Exit; End;
 If s = 'READ'                Then Begin IsKeyword := KW_READ;          Exit; End;
 If s = 'SORT'                Then Begin IsKeyword := KW_SORT;          Exit; End;
 If s = 'COLLECT'             Then Begin IsKeyword := KW_COLLECT;       Exit; End;
 { ---- SELECT (acces BD, stub) ---- }
 If s = 'SELECT'              Then Begin IsKeyword := KW_SELECT;        Exit; End;
 If s = 'WHERE'               Then Begin IsKeyword := KW_WHERE;         Exit; End;
 If s = 'CORRESPONDING'       Then Begin IsKeyword := KW_CORRESPONDING; Exit; End;
 If s = 'FIELDS'              Then Begin IsKeyword := KW_FIELDS;        Exit; End;
 If s = 'ENDSELECT'           Then Begin IsKeyword := KW_ENDSELECT;     Exit; End;
 { ---- CALL ---- }
 If s = 'CALL'                Then Begin IsKeyword := KW_CALL;          Exit; End;
 If s = 'RAISING'             Then Begin IsKeyword := KW_RAISING;       Exit; End;
 If s = 'EXCEPTIONS'          Then Begin IsKeyword := KW_EXCEPTIONS;    Exit; End;
 If s = 'SINGLE'              Then Begin IsKeyword := KW_SINGLE;        Exit; End;
 { ---- Gestion memoire / controle ---- }
 If s = 'CLEAR'               Then Begin IsKeyword := KW_CLEAR;         Exit; End;
 If s = 'REFRESH'             Then Begin IsKeyword := KW_REFRESH;       Exit; End;
 If s = 'FREE'                Then Begin IsKeyword := KW_FREE;          Exit; End;
 If s = 'INITIALIZE'          Then Begin IsKeyword := KW_INITIALIZE;    Exit; End;
 { ---- Operations chaines ---- }
 If s = 'CONCATENATE'         Then Begin IsKeyword := KW_CONCATENATE;   Exit; End;
 If s = 'SPLIT'               Then Begin IsKeyword := KW_SPLIT;         Exit; End;
 If s = 'SHIFT'               Then Begin IsKeyword := KW_SHIFT;         Exit; End;
 If s = 'REPLACE'             Then Begin IsKeyword := KW_REPLACE;       Exit; End;
 If s = 'TRANSLATE'           Then Begin IsKeyword := KW_TRANSLATE;     Exit; End;
 If s = 'CONDENSE'            Then Begin IsKeyword := KW_CONDENSE;      Exit; End;
 If s = 'FIND'                Then Begin IsKeyword := KW_FIND;          Exit; End;
 { ---- Controle de flux ---- }
 If s = 'CHECK'               Then Begin IsKeyword := KW_CHECK;         Exit; End;
 If s = 'RETURN'              Then Begin IsKeyword := KW_RETURN;        Exit; End;
 If s = 'EXIT'                Then Begin IsKeyword := KW_EXIT;          Exit; End;
 If s = 'STOP'                Then Begin IsKeyword := KW_STOP;          Exit; End;
 If s = 'CONTINUE'            Then Begin IsKeyword := KW_CONTINUE;      Exit; End;
 { ---- Evenements ABAP (composes avec - lus comme un seul token) ---- }
 If s = 'START-OF-SELECTION'  Then Begin IsKeyword := KW_START_OF_SEL;  Exit; End;
 If s = 'END-OF-SELECTION'    Then Begin IsKeyword := KW_END_OF_SEL;    Exit; End;
 If s = 'TOP-OF-PAGE'         Then Begin IsKeyword := KW_TOP_OF_PAGE;   Exit; End;
 If s = 'END-OF-PAGE'         Then Begin IsKeyword := KW_END_OF_PAGE;   Exit; End;
 { ---- Ecran de selection ---- }
 If s = 'PARAMETERS'          Then Begin IsKeyword := KW_PARAMETERS;    Exit; End;
 If s = 'SELECT-OPTIONS'      Then Begin IsKeyword := KW_SELECT_OPTIONS; Exit; End;
 { ---- Specificateurs de type / valeur ---- }
 If s = 'LIKE'                Then Begin IsKeyword := KW_LIKE;          Exit; End;
 If s = 'TYPE'                Then Begin IsKeyword := KW_TYPE;          Exit; End;
 If s = 'VALUE'               Then Begin IsKeyword := KW_VALUE;         Exit; End;
 If s = 'DEFAULT'             Then Begin IsKeyword := KW_DEFAULT;       Exit; End;
 If s = 'DECIMALS'            Then Begin IsKeyword := KW_DECIMALS;      Exit; End;
 If s = 'LENGTH'              Then Begin IsKeyword := KW_LENGTH;        Exit; End;
 { ---- Classes (ABAP OO, stubs) ---- }
 If s = 'CLASS'               Then Begin IsKeyword := KW_CLASS;         Exit; End;
 If s = 'ENDCLASS'            Then Begin IsKeyword := KW_ENDCLASS;      Exit; End;
 If s = 'METHOD'              Then Begin IsKeyword := KW_METHOD;        Exit; End;
 If s = 'ENDMETHOD'           Then Begin IsKeyword := KW_ENDMETHOD;     Exit; End;
 If s = 'PUBLIC'              Then Begin IsKeyword := KW_PUBLIC;        Exit; End;
 If s = 'PRIVATE'             Then Begin IsKeyword := KW_PRIVATE;       Exit; End;
 If s = 'PROTECTED'           Then Begin IsKeyword := KW_PROTECTED;     Exit; End;
 { ---- Exceptions (stubs) ---- }
 If s = 'RAISE'               Then Begin IsKeyword := KW_RAISE;         Exit; End;
 If s = 'EXCEPTION'           Then Begin IsKeyword := KW_EXCEPTION;     Exit; End;
 If s = 'TRY'                 Then Begin IsKeyword := KW_TRY;           Exit; End;
 If s = 'CATCH'               Then Begin IsKeyword := KW_CATCH;         Exit; End;
 If s = 'CLEANUP'             Then Begin IsKeyword := KW_CLEANUP;       Exit; End;
 If s = 'ENDTRY'              Then Begin IsKeyword := KW_ENDTRY;        Exit; End;
 { ---- Operateurs de comparaison verbaux ---- }
 If s = 'EQ'                  Then Begin IsKeyword := KW_EQ;            Exit; End;
 If s = 'NE'                  Then Begin IsKeyword := KW_NE;            Exit; End;
 If s = 'LT'                  Then Begin IsKeyword := KW_LT;            Exit; End;
 If s = 'GT'                  Then Begin IsKeyword := KW_GT;            Exit; End;
 If s = 'LE'                  Then Begin IsKeyword := KW_LE;            Exit; End;
 If s = 'GE'                  Then Begin IsKeyword := KW_GE;            Exit; End;
 If s = 'BETWEEN'             Then Begin IsKeyword := KW_BETWEEN;       Exit; End;
 If s = 'IN'                  Then Begin IsKeyword := KW_IN;            Exit; End;
 { ---- Operateurs logiques ---- }
 If s = 'AND'                 Then Begin IsKeyword := KW_AND;           Exit; End;
 If s = 'OR'                  Then Begin IsKeyword := KW_OR;            Exit; End;
 If s = 'NOT'                 Then Begin IsKeyword := KW_NOT;           Exit; End;
 { ---- Predicats IS ---- }
 If s = 'IS'                  Then Begin IsKeyword := KW_IS;            Exit; End;
 If s = 'INITIAL'             Then Begin IsKeyword := KW_INITIAL;       Exit; End;
 If s = 'BOUND'               Then Begin IsKeyword := KW_BOUND;         Exit; End;
 { ---- Tri ---- }
 If s = 'ASCENDING'           Then Begin IsKeyword := KW_ASCENDING;     Exit; End;
 If s = 'DESCENDING'          Then Begin IsKeyword := KW_DESCENDING;    Exit; End;
 { ---- Directions / casse ---- }
 If s = 'LEFT'                Then Begin IsKeyword := KW_LEFT;          Exit; End;
 If s = 'RIGHT'               Then Begin IsKeyword := KW_RIGHT;         Exit; End;
 If s = 'UPPER'               Then Begin IsKeyword := KW_UPPER;         Exit; End;
 If s = 'LOWER'               Then Begin IsKeyword := KW_LOWER;         Exit; End;
 If s = 'NO-GAPS'             Then Begin IsKeyword := KW_NO_GAPS;       Exit; End;
 { ---- Recherche dans chaines ---- }
 If s = 'MATCH'               Then Begin IsKeyword := KW_MATCH;         Exit; End;
 If s = 'OFFSET'              Then Begin IsKeyword := KW_OFFSET;        Exit; End;
 If s = 'OCCURRENCE'          Then Begin IsKeyword := KW_OCCURRENCE;    Exit; End;
 If s = 'OCCURRENCES'         Then Begin IsKeyword := KW_OCCURRENCES;   Exit; End;
 If s = 'SEPARATED'           Then Begin IsKeyword := KW_SEPARATED;     Exit; End;
 { ---- Evenements interactifs ---- }
 If s = 'LINE-SELECTION'      Then Begin IsKeyword := KW_LINE_SEL;      Exit; End;
 If s = 'USER-COMMAND'        Then Begin IsKeyword := KW_USER_CMD;      Exit; End;
 { ---- Divers ---- }
 If s = 'OF'                  Then Begin IsKeyword := KW_OF;            Exit; End;
 If s = 'BEGIN'               Then Begin IsKeyword := KW_BEGIN;         Exit; End;
 If s = 'END'                 Then Begin IsKeyword := KW_END;           Exit; End;
 If s = 'TABLE'               Then Begin IsKeyword := KW_TABLE;         Exit; End;
 If s = 'WITH'                Then Begin IsKeyword := KW_WITH;          Exit; End;
 If s = 'KEY'                 Then Begin IsKeyword := KW_KEY;           Exit; End;
 If s = 'INDEX'               Then Begin IsKeyword := KW_INDEX;         Exit; End;
 If s = 'MESSAGE-ID'          Then Begin IsKeyword := KW_MESSAGE_ID;    Exit; End;
 { ---- Fonctions built-in ---- }
 If s = 'STRLEN'              Then Begin IsKeyword := KW_STRLEN;        Exit; End;
 If s = 'ABS'                 Then Begin IsKeyword := KW_ABS;           Exit; End;
 { ---- SELECT avance ---- }
 If s = 'ROWS'                Then Begin IsKeyword := KW_ROWS;          Exit; End;
 If s = 'ORDER'               Then Begin IsKeyword := KW_ORDER;         Exit; End;
 If s = 'EXPORTING'           Then Begin IsKeyword := KW_EXPORTING;     Exit; End;
 If s = 'IMPORTING'           Then Begin IsKeyword := KW_IMPORTING;     Exit; End;
 { ---- Shift / Replace ---- }
 If s = 'CIRCULAR'            Then Begin IsKeyword := KW_CIRCULAR;      Exit; End;
 If s = 'PLACES'              Then Begin IsKeyword := KW_PLACES;        Exit; End;
 If s = 'ALL'                 Then Begin IsKeyword := KW_ALL;           Exit; End;
 If s = 'FIRST'               Then Begin IsKeyword := KW_FIRST;         Exit; End;
 IsKeyword := KW_NONE;
End;

{ ============================================================================ }
{ TODO 04 - TABLE DES SYMBOLES ET DES FORMS              [COMPLET]            }
{ ============================================================================ }

{ Initialise toutes les tables (symboles, formes, chaines) }
Procedure InitSymTable;
Var i, j: Integer;
Begin
 sym_count  := 0;
 form_count := 0;
 str_count  := 0;
 For i := 1 to MAX_SYM do
 Begin
  sym_table[i].name        := '';
  sym_table[i].asm_label   := '';
  sym_table[i].data_type   := TYPE_UNKNOWN;
  sym_table[i].store_class := STORE_STATIC;
  sym_table[i].bp_offset   := 0;
  sym_table[i].array_size  := 0;
  sym_table[i].char_len    := 1;
  sym_table[i].dec_prec    := 0;
  sym_table[i].dec_scale   := 0;
  sym_table[i].is_param    := False;
  sym_table[i].param_idx   := 0;
  sym_table[i].param_kind  := PARAM_USING;
  sym_table[i].init_str    := '';
  sym_table[i].init_num    := 0;
  sym_table[i].has_init    := False;
  sym_table[i].is_const    := False;
  sym_table[i].scope_lev   := 0;
 End;
 For i := 1 to MAX_FORM do
 Begin
  form_table[i].name           := '';
  form_table[i].asm_label      := '';
  form_table[i].param_count    := 0;
  form_table[i].using_count    := 0;
  form_table[i].changing_count := 0;
  form_table[i].tables_count   := 0;
  form_table[i].defined        := False;
  form_table[i].is_function    := False;
  For j := 1 to MAX_PARAM do
  Begin
   form_table[i].param_names[j] := '';
   form_table[i].param_kinds[j] := PARAM_USING;
   form_table[i].param_types[j] := TYPE_UNKNOWN;
  End;
 End;
 For i := 1 to MAX_STR do
 Begin
  str_table[i].text      := '';
  str_table[i].asm_label := '';
 End;
End;

{ ---- Recherche dans la table des symboles ----
  Cherche de la fin vers le debut pour respecter la portee la plus proche. }
Function FindSym(Const name: String): Integer;
Var i: Integer; u: String;
Begin
 u := UpCaseStr(name);
 For i := sym_count DownTo 1 do
  If sym_table[i].name = u Then Begin FindSym := i; Exit; End;
 FindSym := 0;
End;

{ ---- Recherche uniquement dans le scope courant ---- }
Function FindSymLocal(Const name: String): Integer;
Var i: Integer; u: String; lev: Integer;
Begin
 u   := UpCaseStr(name);
 lev := scope_top;
 For i := sym_count DownTo 1 do
  If (sym_table[i].name = u) And (sym_table[i].scope_lev = lev) Then
  Begin FindSymLocal := i; Exit; End;
 FindSymLocal := 0;
End;

{ ---- Ajout d'un symbole dans la table ----
  Retourne l'index (1-base) du nouveau symbole, ou 0 si la table est pleine. }
Function AddSym(Const name: String; dt, sc: Integer): Integer;
Var u: String;
Begin
 u := UpCaseStr(name);
 If sym_count >= MAX_SYM Then
 Begin Error('Table des symboles pleine'); AddSym := 0; Exit; End;
 Inc(sym_count);
 sym_table[sym_count].name        := u;
 sym_table[sym_count].asm_label   := AsmIdent('_VAR_', u);
 sym_table[sym_count].data_type   := dt;
 sym_table[sym_count].store_class := sc;
 sym_table[sym_count].bp_offset   := 0;
 sym_table[sym_count].array_size  := 0;
 sym_table[sym_count].char_len    := 1;
 sym_table[sym_count].dec_prec    := 0;
 sym_table[sym_count].dec_scale   := 0;
 sym_table[sym_count].is_param    := False;
 sym_table[sym_count].param_idx   := 0;
 sym_table[sym_count].param_kind  := PARAM_USING;
 sym_table[sym_count].init_str    := '';
 sym_table[sym_count].init_num    := 0;
 sym_table[sym_count].has_init    := False;
 sym_table[sym_count].is_const    := False;
 sym_table[sym_count].scope_lev   := scope_top;
 AddSym := sym_count;
End;

{ ---- Recherche dans la table des FORMs / FUNCTIONs ---- }
Function FindForm(Const name: String): Integer;
Var i: Integer; u: String;
Begin
 u := UpCaseStr(name);
 For i := 1 to form_count do
  If form_table[i].name = u Then Begin FindForm := i; Exit; End;
 FindForm := 0;
End;

{ ---- Ajout d'une entree FORM / FUNCTION ----
  Si la FORM existe deja (forward reference), retourne l'index existant. }
Function AddForm(Const name: String): Integer;
Var u: String; existing: Integer;
Begin
 u        := UpCaseStr(name);
 existing := FindForm(u);
 If existing > 0 Then Begin AddForm := existing; Exit; End;
 If form_count >= MAX_FORM Then
 Begin Error('Table des FORMs pleine'); AddForm := 0; Exit; End;
 Inc(form_count);
 form_table[form_count].name           := u;
 form_table[form_count].asm_label      := AsmIdent('_ABAP_FORM_', u);
 form_table[form_count].param_count    := 0;
 form_table[form_count].using_count    := 0;
 form_table[form_count].changing_count := 0;
 form_table[form_count].tables_count   := 0;
 form_table[form_count].defined        := False;
 form_table[form_count].is_function    := False;
 AddForm := form_count;
End;

{ ---- Declarer les variables systeme ABAP (SY-xxx) ----
  Appellee au debut de la compilation, avant tout parsage.
  Ces variables sont globales TYPE I (word) en .DATA.               }
Procedure DeclSysVars;
Var idx: Integer;

 Procedure DeclSY(Const nm: String; dt: Integer);
 Begin
  idx := AddSym(nm, dt, STORE_STATIC);
  If idx > 0 Then
  Begin
   sym_table[idx].asm_label := AsmIdent('_SY_', Copy(nm, 4, 255));
   sym_table[idx].has_init  := True;
   sym_table[idx].init_num  := 0;
  End;
 End;

Begin
 DeclSY('SY-SUBRC',  TYPE_I);   { code retour dernier SELECT/CALL }
 DeclSY('SY-TABIX',  TYPE_I);   { index courant dans LOOP AT      }
 DeclSY('SY-DBCNT',  TYPE_I);   { nb lignes SQL affectees         }
 DeclSY('SY-INDEX',  TYPE_I);   { compteur DO TIMES               }
 DeclSY('SY-LANGU',  TYPE_C);   { langue (stub = 'F')             }
 DeclSY('SY-MANDT',  TYPE_C);   { mandant (stub = '000')          }
 DeclSY('SY-DATUM',  TYPE_D);   { date systeme (stub)             }
 DeclSY('SY-UZEIT',  TYPE_T);   { heure systeme (stub)            }
 DeclSY('SY-UNAME',  TYPE_C);   { nom utilisateur (stub)          }
End;

{ ============================================================================ }
{ TODO 05 - GESTION DES SCOPES                           [COMPLET]            }
{ ============================================================================ }

{ Initialise la pile de scopes : scope 0 = global REPORT }
Procedure InitScopes;
Begin
 scope_top := 0;
 scope_stack[0].kind      := SK_GLOBAL;
 scope_stack[0].form_idx  := 0;
 scope_stack[0].bp_top    := 0;
 scope_stack[0].sym_start := 1;
 scope_stack[0].sym_end   := 0;
 scope_stack[0].lbl_exit  := '';
 scope_stack[0].lbl_cont  := '';
 scope_stack[0].lbl_end   := '';
End;

{ Empile un nouveau scope.
  kind     : SK_GLOBAL / SK_FORM / SK_BLOCK / SK_LOOP / SK_EVENT
  form_idx : index dans form_table si SK_FORM, sinon 0               }
Procedure EnterScope(kind: Integer; form_idx: Integer);
Begin
 If scope_top >= MAX_DEPTH Then
 Begin Error('Trop d''imbrications de scopes'); Exit; End;
 Inc(scope_top);
 scope_stack[scope_top].kind      := kind;
 scope_stack[scope_top].form_idx  := form_idx;
 scope_stack[scope_top].bp_top    := 0;           { repart a 0 en local }
 scope_stack[scope_top].sym_start := sym_count + 1;
 scope_stack[scope_top].sym_end   := sym_count;
 scope_stack[scope_top].lbl_exit  := '';
 scope_stack[scope_top].lbl_cont  := '';
 scope_stack[scope_top].lbl_end   := '';
End;

{ Depile le scope courant.
  Attention : ne depile jamais le scope global (niveau 0).            }
Procedure LeaveScope;
Begin
 If scope_top = 0 Then Begin Error('LeaveScope hors scope'); Exit; End;
 scope_stack[scope_top].sym_end := sym_count;
 Dec(scope_top);
End;

{ Retourne la profondeur BP courante (valeur negative pour variables locales) }
Function CurrentBpTop: Integer;
Begin
 CurrentBpTop := scope_stack[scope_top].bp_top;
End;

{ Reserve n octets sur la pile locale (decremente bp_top).
  Retourne l'offset BP du nouvel emplacement (negatif).              }
Function AllocLocalBp(bytes: Integer): Integer;
Begin
 Dec(scope_stack[scope_top].bp_top, bytes);
 AllocLocalBp := scope_stack[scope_top].bp_top;
End;

{ ---- Setters / Getters de labels de scope ---- }

{ Definit le label de sortie du scope courant (EXIT -> JMP lbl_exit) }
Procedure SetExitLabel(Const lbl: String);
Begin scope_stack[scope_top].lbl_exit := lbl; End;

{ Definit le label de continuation (CONTINUE -> JMP lbl_cont) }
Procedure SetContLabel(Const lbl: String);
Begin scope_stack[scope_top].lbl_cont := lbl; End;

{ Definit le label de fin de bloc (ENDLOOP/ENDDO/ENDWHILE) }
Procedure SetEndLabel(Const lbl: String);
Begin scope_stack[scope_top].lbl_end := lbl; End;

{ Retourne le label EXIT du scope le plus proche qui en a un.
  Remonte la pile jusqu'a trouver un lbl_exit non vide.               }
Function CurrentExitLabel: String;
Var i: Integer;
Begin
 For i := scope_top DownTo 0 do
  If scope_stack[i].lbl_exit <> '' Then
  Begin CurrentExitLabel := scope_stack[i].lbl_exit; Exit; End;
 CurrentExitLabel := '';
End;

{ Retourne le label CONTINUE du scope de boucle le plus proche }
Function CurrentContLabel: String;
Var i: Integer;
Begin
 For i := scope_top DownTo 0 do
  If scope_stack[i].lbl_cont <> '' Then
  Begin CurrentContLabel := scope_stack[i].lbl_cont; Exit; End;
 CurrentContLabel := '';
End;

{ Retourne le label END du scope de boucle le plus proche }
Function CurrentEndLabel: String;
Var i: Integer;
Begin
 For i := scope_top DownTo 0 do
  If scope_stack[i].lbl_end <> '' Then
  Begin CurrentEndLabel := scope_stack[i].lbl_end; Exit; End;
 CurrentEndLabel := '';
End;

{ Vrai si on se trouve a l'interieur d'une FORM (SK_FORM quelque part) }
Function InForm: Boolean;
Var i: Integer;
Begin
 For i := scope_top DownTo 1 do
  If scope_stack[i].kind = SK_FORM Then Begin InForm := True; Exit; End;
 InForm := False;
End;

{ Retourne l'index de la FORM englobante, ou 0 si pas dans une FORM }
Function CurrentFormIdx: Integer;
Var i: Integer;
Begin
 For i := scope_top DownTo 1 do
  If scope_stack[i].kind = SK_FORM Then
  Begin CurrentFormIdx := scope_stack[i].form_idx; Exit; End;
 CurrentFormIdx := 0;
End;

{ ============================================================================ }
{ TODO 06 - PARSEUR : REPORT / PROGRAM (en-tete)         [COMPLET]            }
{ ============================================================================ }

{ ParseReport / ParseProgram
  Syntaxes :
    REPORT nom_programme [MESSAGE-ID xx] [NO STANDARD PAGE HEADING].
    PROGRAM nom_programme.
  Le mot-cle REPORT ou PROGRAM a deja ete consomme par l'appelant.
  On memorise le nom dans prog_name et on ignore les options.             }
Procedure ParseReport;
Var name: String;
Begin
 { Le nom du programme est obligatoire }
 If cur_tok_type <> TOK_IDENT Then
 Begin
  Error('Nom de programme attendu apres REPORT/PROGRAM');
  SkipToDot;
  Exit;
 End;
 name      := cur_tok_str;
 prog_name := name;
 Consume;
 EmitComment('Programme ABAP : ' + name);
 { Sauter toutes les options jusqu'au '.' }
 { Options reconnues (ignorees) :
     MESSAGE-ID xx
     NO STANDARD PAGE HEADING
     LINE-SIZE nn
     LINE-COUNT nn (nn)
 }
 While (cur_tok_type <> TOK_DOT) And (cur_tok_type <> TOK_EOF) Do
 Begin
  { On peut donner un avertissement pour les options inconnues si besoin }
  Consume;
 End;
 { Consommer le '.' final }
 If cur_tok_type = TOK_DOT Then Consume;
End;

{ ============================================================================ }
{ TODO 07 - PARSEUR : DATA / TYPES / CONSTANTS           [COMPLET]            }
{ ============================================================================ }

{ --- Analyse du type ABAP apres TYPE ou LIKE ---
  Remplit data_type, char_len, dec_scale dans le symbole sym_idx.
  TYPE I / F / C / C(n) / N(n) / D / T / P / STRING / XSTRING
  TYPE TABLE OF xxx  (table interne)
  LIKE xxx           (meme type qu'une autre variable)                        }
Procedure ParseTypeSpec(sym_idx: Integer);
Var refname: String; ref_idx: Integer;
Begin
 If TokIsKw(KW_LIKE) Then
 Begin
  Consume;
  { LIKE TABLE OF var }
  If TokIsKw(KW_TABLE) Then
  Begin
   Consume; EatKw(KW_OF);
   sym_table[sym_idx].data_type  := TYPE_TABLE;
   sym_table[sym_idx].char_len   := 0;
   If cur_tok_type = TOK_IDENT Then Consume;
   Exit;
  End;
  { LIKE varname : copie le type de la variable reference }
  refname := cur_tok_str; Consume;
  ref_idx := FindSym(refname);
  If ref_idx > 0 Then
  Begin
   sym_table[sym_idx].data_type  := sym_table[ref_idx].data_type;
   sym_table[sym_idx].char_len   := sym_table[ref_idx].char_len;
   sym_table[sym_idx].dec_scale  := sym_table[ref_idx].dec_scale;
  End Else
  Begin
   Warning('LIKE: variable inconnue ' + refname + ', TYPE I suppose');
   sym_table[sym_idx].data_type := TYPE_I;
  End;
  Exit;
 End;
 { TYPE ... }
 If Not TokIsKw(KW_TYPE) Then Exit;
 Consume;
 { TABLE OF xxx }
 If TokIsKw(KW_TABLE) Then
 Begin
  Consume; EatKw(KW_OF);
  sym_table[sym_idx].data_type := TYPE_TABLE;
  sym_table[sym_idx].char_len  := 0;
  If cur_tok_type = TOK_IDENT Then Consume;
  Exit;
 End;
 { REF TO xxx (stub) }
 If cur_tok_str = 'REF' Then
 Begin
  Consume; EatKw(KW_TO);
  sym_table[sym_idx].data_type := TYPE_REF;
  If cur_tok_type = TOK_IDENT Then Consume;
  Exit;
 End;
 { Types scalaires }
 If cur_tok_type <> TOK_IDENT Then
 Begin Warning('Type ABAP attendu'); Exit; End;
 If cur_tok_str = 'I' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_I;
  sym_table[sym_idx].char_len  := 2;
  Consume;
 End Else If cur_tok_str = 'F' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_F;
  sym_table[sym_idx].char_len  := 8;
  Consume;
 End Else If cur_tok_str = 'C' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_C;
  sym_table[sym_idx].char_len  := 1;
  Consume;
  { TYPE C(n) }
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   sym_table[sym_idx].char_len := cur_tok_num;
   If cur_tok_type = TOK_NUMBER Then Consume;
   If cur_tok_type = TOK_RPAREN Then Consume;
  End;
 End Else If cur_tok_str = 'N' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_N;
  sym_table[sym_idx].char_len  := 1;
  Consume;
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   sym_table[sym_idx].char_len := cur_tok_num;
   If cur_tok_type = TOK_NUMBER Then Consume;
   If cur_tok_type = TOK_RPAREN Then Consume;
  End;
 End Else If cur_tok_str = 'D' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_D;
  sym_table[sym_idx].char_len  := 8;
  Consume;
 End Else If cur_tok_str = 'T' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_T;
  sym_table[sym_idx].char_len  := 6;
  Consume;
 End Else If cur_tok_str = 'P' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_P;
  sym_table[sym_idx].char_len  := 2;
  Consume;
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   sym_table[sym_idx].char_len := cur_tok_num;
   If cur_tok_type = TOK_NUMBER Then Consume;
   If cur_tok_type = TOK_RPAREN Then Consume;
  End;
  { DECIMALS n }
  If TokIsKw(KW_DECIMALS) Then
  Begin
   Consume;
   sym_table[sym_idx].dec_scale := cur_tok_num;
   If cur_tok_type = TOK_NUMBER Then Consume;
  End;
 End Else If cur_tok_str = 'STRING' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_STRING;
  sym_table[sym_idx].char_len  := 255;
  Consume;
 End Else If cur_tok_str = 'XSTRING' Then
 Begin
  sym_table[sym_idx].data_type := TYPE_XSTRING;
  sym_table[sym_idx].char_len  := 255;
  Consume;
 End Else
 Begin
  { Type utilisateur (structure ou table definie par TYPES) : stub TYPE_STRUCT }
  sym_table[sym_idx].data_type := TYPE_STRUCT;
  sym_table[sym_idx].char_len  := 2;
  Consume;
 End;
End;

{ --- Taille en octets d'une variable selon son type et char_len --- }
Function SymByteSize(sym_idx: Integer): Integer;
Var dt, cl: Integer;
Begin
 dt := sym_table[sym_idx].data_type;
 cl := sym_table[sym_idx].char_len;
 Case dt Of
  TYPE_I, TYPE_N : SymByteSize := 2;
  TYPE_F         : SymByteSize := 8;
  TYPE_C         : If cl < 1 Then SymByteSize := 1 Else SymByteSize := cl + 1;
  TYPE_D         : SymByteSize := 9;   { 8 chars + '$' }
  TYPE_T         : SymByteSize := 7;   { 6 chars + '$' }
  TYPE_P         : SymByteSize := cl * 2;
  TYPE_STRING,
  TYPE_XSTRING   : SymByteSize := 256; { buffer fixe 255+1 }
  TYPE_TABLE     : SymByteSize := 0;   { taille calculee a l'allocation }
  TYPE_STRUCT    : SymByteSize := cl * 2;
 Else              SymByteSize := 2;
 End;
End;

{ --- Lit la clause VALUE xxx ---
  Remplit init_str / init_num / has_init.
  VALUE 0 / VALUE 42 / VALUE 'texte' / VALUE IS INITIAL (= 0/' ')           }
Procedure ParseValue(sym_idx: Integer);
Begin
 If Not TokIsKw(KW_VALUE) Then Exit;
 Consume;
 sym_table[sym_idx].has_init := True;
 { VALUE IS INITIAL -> valeur zero }
 If TokIsKw(KW_IS) Then
 Begin
  Consume; EatKw(KW_INITIAL);
  sym_table[sym_idx].init_num := 0;
  sym_table[sym_idx].init_str := '';
  Exit;
 End;
 If cur_tok_type = TOK_NUMBER Then
 Begin
  sym_table[sym_idx].init_num := cur_tok_num;
  Str(cur_tok_num, sym_table[sym_idx].init_str);
  Consume;
 End Else If cur_tok_type = TOK_STRING Then
 Begin
  sym_table[sym_idx].init_str := cur_tok_str;
  sym_table[sym_idx].init_num := 0;
  Consume;
 End Else If cur_tok_type = TOK_MINUS Then
 Begin
  Consume;
  sym_table[sym_idx].init_num := -cur_tok_num;
  sym_table[sym_idx].init_str := '-' + ItoS(cur_tok_num);
  If cur_tok_type = TOK_NUMBER Then Consume;
 End Else
  Warning('Valeur VALUE non reconnue dans declaration');
End;

{ --- Declaration d'une seule variable ABAP ---
  Syntaxe : nom[(n)] [TYPE t | LIKE var] [VALUE x]
  name_in : si non vide, le nom a deja ete lu (appel depuis ParseData).     }
Procedure ParseOneVar(Const name_in: String; is_const: Boolean);
Var vname: String; sym_idx: Integer; sc: Integer;
    bytes, bpoff: Integer; lblfx: String;
Begin
 { Nom de la variable }
 If name_in <> '' Then vname := name_in
 Else
 Begin
  If cur_tok_type <> TOK_IDENT Then
  Begin Error('Nom de variable attendu'); Exit; End;
  vname := cur_tok_str; Consume;
 End;
 { Longueur inline : DATA nom(n) TYPE C }
 If scope_top = 0 Then sc := STORE_STATIC Else sc := STORE_AUTO;
 If is_const Then sc := STORE_CONSTANT;
 sym_idx := AddSym(vname, TYPE_I, sc);
 If sym_idx = 0 Then Exit;
 { Longueur inline : DATA nom(n) TYPE C }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  sym_table[sym_idx].char_len  := cur_tok_num;
  sym_table[sym_idx].data_type := TYPE_C;  { defaut si pas TYPE apres }
  If cur_tok_type = TOK_NUMBER Then Consume;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End;
 { TYPE ... ou LIKE ... }
 ParseTypeSpec(sym_idx);
 { VALUE ... }
 ParseValue(sym_idx);
 { ---- Allocation memoire / generation ASM ---- }
 If sc = STORE_CONSTANT Then
 Begin
  { CONSTANTS : pas de DW, valeur immediate utilisee a la compilation }
  sym_table[sym_idx].is_const := True;
  EmitComment('CONSTANTS ' + vname + ' = ' + sym_table[sym_idx].init_str);
  Exit;
 End;
 bytes := SymByteSize(sym_idx);
 If sc = STORE_AUTO Then
 Begin
  { Variable locale dans une FORM }
  If bytes < 2 Then bytes := 2;
  bpoff  := AllocLocalBp(bytes);
  sym_table[sym_idx].bp_offset := bpoff;
  EmitI('SUB     SP, ' + ItoSI(bytes) + '   ; LOCAL ' + vname);
  { Initialisation si VALUE }
  If sym_table[sym_idx].has_init Then
  Begin
   Case sym_table[sym_idx].data_type Of
    TYPE_I, TYPE_N, TYPE_P:
     EmitI('MOV     WORD PTR [BP' + ItoSI(bpoff) + '], ' +
           ItoS(sym_table[sym_idx].init_num));
    TYPE_C, TYPE_STRING, TYPE_D, TYPE_T:
    Begin
     If sym_table[sym_idx].init_str = '' Then
      EmitI('MOV     BYTE PTR [BP' + ItoSI(bpoff) + '], 32  ; espace')
     Else
     Begin
      lblfx := AddStringLit(sym_table[sym_idx].init_str);
      EmitI('LEA     SI, ' + lblfx);
      EmitI('LEA     DI, [BP' + ItoSI(bpoff) + ']');
      EmitI('CALL    _ABAP_STR_COPY');
     End;
    End;
   End;
  End;
 End Else
 Begin
  { Variable globale → sera emise dans le DataSegment (GenDataSegment) }
  { Ici on emet juste un commentaire ; la definition DW/DB est differee }
  EmitComment('DATA ' + vname + ' : ' + sym_table[sym_idx].asm_label + ' (global)');
 End;
End;

{ --- TYPES: BEGIN OF struc ... END OF struc (stub structure) ---
  On enregistre juste le nom de la structure dans la table des types.
  Les champs sont ignores (stub) pour l'instant.                          }
Procedure ParseTypesBlock;
Begin
 EatKw(KW_BEGIN); EatKw(KW_OF);
 { Nom de la structure }
 If cur_tok_type = TOK_IDENT Then Consume;
 If cur_tok_type = TOK_COMMA Then Consume;
 { Sauter les champs jusqu'a END OF }
 While Not (cur_tok_type = TOK_EOF) Do
 Begin
  If TokIsKw(KW_END) Then
  Begin
   Consume; EatKw(KW_OF);
   If cur_tok_type = TOK_IDENT Then Consume;
   If cur_tok_type = TOK_DOT Then Consume;
   Break;
  End;
  Consume;
 End;
End;

{ --- ParseData : DATA [: ] liste de declarations ---
  Syntaxe :
    DATA nom TYPE I [VALUE 0].
    DATA: nom TYPE I, nom2 TYPE C(20), ...
    DATA: BEGIN OF struc, champ TYPE I, END OF struc.
    DATA itab TYPE TABLE OF struc.                                          }
Procedure ParseData(is_const: Boolean);
Var multi: Boolean; vname: String;
Begin
 { DATA ou CONSTANTS : mot-cle deja consomme par l'appelant }
 multi := (cur_tok_type = TOK_COLON);
 If multi Then Consume;
 Repeat
  { TYPES: BEGIN OF ... -> traitement special }
  If TokIsKw(KW_BEGIN) Then
  Begin
   ParseTypesBlock;
   If Not multi Then Break;
   If cur_tok_type = TOK_COMMA Then Consume Else Break;
   Continue;
  End;
  If cur_tok_type <> TOK_IDENT Then Break;
  vname := cur_tok_str; Consume;
  ParseOneVar(vname, is_const);
  If (Not multi) Or (cur_tok_type <> TOK_COMMA) Then Break;
  Consume; { sauter la virgule }
 Until (cur_tok_type = TOK_DOT) Or (cur_tok_type = TOK_EOF);
 If cur_tok_type = TOK_DOT Then Consume;
End;

{ --- ParseTypes : TYPES [: ] liste de definitions ---
  Similaire a DATA mais definit des types (structures), pas des variables.
  Syntaxe simple : TYPES: BEGIN OF struc, ... END OF struc.              }
Procedure ParseTypes;
Var multi: Boolean;
Begin
 multi := (cur_tok_type = TOK_COLON);
 If multi Then Consume;
 Repeat
  If TokIsKw(KW_BEGIN) Then
  Begin ParseTypesBlock; If Not multi Then Break; End
  Else
  Begin
   { TYPES nom TYPE I : alias de type (stub, ignore) }
   While (cur_tok_type <> TOK_DOT) And (cur_tok_type <> TOK_COMMA)
         And (cur_tok_type <> TOK_EOF) Do Consume;
  End;
  If (Not multi) Or (cur_tok_type <> TOK_COMMA) Then Break;
  Consume;
 Until (cur_tok_type = TOK_DOT) Or (cur_tok_type = TOK_EOF);
 If cur_tok_type = TOK_DOT Then Consume;
End;

{ ============================================================================ }
{ TODO 08 - PARSEUR : EXPRESSIONS ABAP                   [COMPLET]            }
{ ============================================================================ }

{ --- Primitives de generation incluses ici car pre-requises par ParseExpr.
  La section TODO 09 ci-dessous documente et complete l'infrastructure.  --- }

{ Charge une variable dans AX selon son type et sa classe de stockage }
Procedure GenLoadVar(sym_idx: Integer);
Var sc, dt, bp: Integer; lbl: String;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenLoadVar: idx invalide'); Exit; End;
 sc  := sym_table[sym_idx].store_class;
 dt  := sym_table[sym_idx].data_type;
 bp  := sym_table[sym_idx].bp_offset;
 lbl := sym_table[sym_idx].asm_label;
 { CONSTANT : valeur immediate }
 If sc = STORE_CONSTANT Then
 Begin
  EmitI('MOV     AX, ' + ItoS(sym_table[sym_idx].init_num));
  Exit;
 End;
 Case dt Of
  TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
  Begin
   { Chaine : charger l'adresse (LEA) }
   If sc = STORE_AUTO Then
   Begin
    If bp >= 0 Then EmitI('LEA     AX, [BP+' + ItoSI(bp) + ']')
    Else             EmitI('LEA     AX, [BP' + ItoSI(bp) + ']');
   End Else          EmitI('LEA     AX, ' + lbl);
  End;
 Else
  { Numerique : charger la valeur (MOV) }
  If sc = STORE_AUTO Then
  Begin
   If bp >= 0 Then EmitI('MOV     AX, [BP+' + ItoSI(bp) + ']')
   Else            EmitI('MOV     AX, [BP' + ItoSI(bp) + ']');
  End Else         EmitI('MOV     AX, [' + lbl + ']');
 End;
End;

{ Stocke AX dans une variable selon son type et sa classe de stockage }
Procedure GenStoreVar(sym_idx: Integer);
Var sc, dt, bp: Integer; lbl: String;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenStoreVar: idx invalide'); Exit; End;
 sc  := sym_table[sym_idx].store_class;
 dt  := sym_table[sym_idx].data_type;
 bp  := sym_table[sym_idx].bp_offset;
 lbl := sym_table[sym_idx].asm_label;
 If sc = STORE_CONSTANT Then
 Begin Warning('Affectation a une CONSTANT ignoree'); Exit; End;
 Case dt Of
  TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
  Begin
   { Chaine : AX = adresse source -> copier vers dest }
   EmitI('MOV     SI, AX');
   If sc = STORE_AUTO Then
   Begin
    If bp >= 0 Then EmitI('LEA     DI, [BP+' + ItoSI(bp) + ']')
    Else            EmitI('LEA     DI, [BP' + ItoSI(bp) + ']');
   End Else         EmitI('LEA     DI, ' + lbl);
   EmitI('CALL    _ABAP_STR_COPY');
  End;
 Else
  { Numerique : MOV }
  If sc = STORE_AUTO Then
  Begin
   If bp >= 0 Then EmitI('MOV     [BP+' + ItoSI(bp) + '], AX')
   Else            EmitI('MOV     [BP' + ItoSI(bp) + '], AX');
  End Else         EmitI('MOV     [' + lbl + '], AX');
 End;
End;

{ Genere l'operation binaire : AX op BX -> AX }
Procedure GenBinOp(op: Integer);
Begin
 Case op Of
  TOK_PLUS:  EmitI('ADD     AX, BX');
  TOK_MINUS: EmitI('SUB     AX, BX');
  TOK_STAR:  EmitI('IMUL    BX');
  TOK_SLASH:
  Begin
   EmitI('CWD');
   EmitI('IDIV    BX');
  End;
  TOK_CONCAT: EmitComment('&& concatenation (stub)');
 Else EmitComment('GenBinOp: op inconnu');
 End;
End;

{ Genere une comparaison : AX CMP BX -> AX = 0FFFFh (vrai) ou 0 (faux) }
Procedure GenCompare(op: Integer);
Var lbl_f, lbl_e: String;
Begin
 lbl_f := NewLabel;
 lbl_e := NewLabel;
 EmitI('CMP     AX, BX');
 Case op Of
  TOK_EQ,  KW_EQ: EmitI('JNE     ' + lbl_f);
  TOK_NE,  KW_NE: EmitI('JE      ' + lbl_f);
  TOK_LT,  KW_LT: EmitI('JGE     ' + lbl_f);
  TOK_LE,  KW_LE: EmitI('JG      ' + lbl_f);
  TOK_GT,  KW_GT: EmitI('JLE     ' + lbl_f);
  TOK_GE,  KW_GE: EmitI('JL      ' + lbl_f);
  Else             EmitI('JNE     ' + lbl_f);
 End;
 EmitI('MOV     AX, 0FFFFh');
 EmitI('JMP     ' + lbl_e);
 EmitLabel(lbl_f);
 EmitI('XOR     AX, AX');
 EmitLabel(lbl_e);
End;

{ --- Prototypes anticipes --- }
Function ParseExpr: Integer; Forward;

{ --- Built-ins ABAP reconnus dans les expressions --- }
Function GenBuiltIn(Const bname: String): Boolean;
Var lbl1, lbl2: String;
Begin
 GenBuiltIn := True;
 lbl1 := NewLabel;
 lbl2 := NewLabel;
 If bname = 'STRLEN' Then
 Begin
  { STRLEN( var ) -> longueur d'une chaine terminee par '$' }
  ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitI('MOV     SI, AX');
  EmitI('XOR     CX, CX');
  EmitLabel(lbl1);
  EmitI('MOV     AL, [SI]');
  EmitI('CMP     AL, 24h');
  EmitI('JE      ' + lbl2);
  EmitI('INC     SI');
  EmitI('INC     CX');
  EmitI('JMP     ' + lbl1);
  EmitLabel(lbl2);
  EmitI('MOV     AX, CX');
 End Else If bname = 'ABS' Then
 Begin
  { ABS( expr ) -> valeur absolue }
  ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitI('CWD');
  EmitI('XOR     AX, DX');
  EmitI('SUB     AX, DX');
 End Else If bname = 'SIGN' Then
 Begin
  ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitI('TEST    AX, AX');
  EmitI('JZ      ' + lbl2);
  EmitI('JNS     ' + lbl1);
  EmitI('MOV     AX, 0FFFFh');
  EmitI('JMP     ' + lbl2);
  EmitLabel(lbl1);
  EmitI('MOV     AX, 1');
  EmitLabel(lbl2);
 End Else If bname = 'LINES' Then
 Begin
  { LINES( itab ) -> stub -> 0 }
  ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitI('XOR     AX, AX');
  EmitComment('LINES( itab ) stub = 0');
 End Else
  GenBuiltIn := False;
End;

{ --- Niveau 1 : expression primaire ---
  Constante numerique, chaine, variable, built-in, parentheses, unaire -     }
Function ParsePrimaryExpr: Integer;
Var sym_idx, nargs: Integer; s: String; lbl_t, lbl_e: String;
Begin
 ParsePrimaryExpr := TYPE_I;
 Case cur_tok_type Of
  { Constante entiere }
  TOK_NUMBER:
  Begin
   EmitI('MOV     AX, ' + ItoS(cur_tok_num));
   Consume;
  End;
  { Constante flottante (stub : partie entiere seulement) }
  TOK_FLOAT:
  Begin
   EmitI('MOV     AX, ' + ItoS(cur_tok_num) + '  ; FLOAT stub');
   Consume;
  End;
  { Chaine litterale }
  TOK_STRING:
  Begin
   s := AddStringLit(cur_tok_str + '$');
   EmitI('LEA     AX, ' + s);
   Consume;
   ParsePrimaryExpr := TYPE_C;
  End;
  { Expression parenthesee }
  TOK_LPAREN:
  Begin
   Consume;
   ParsePrimaryExpr := ParseExpr;
   If cur_tok_type = TOK_RPAREN Then Consume
   Else Error('Attendu ) dans expression');
  End;
  { Unaire : - expr }
  TOK_MINUS:
  Begin
   Consume;
   ParsePrimaryExpr := ParsePrimaryExpr;
   EmitI('NEG     AX');
  End;
  { Identificateur : variable, constante, built-in }
  TOK_IDENT:
  Begin
   { NOT en tant qu'operateur unaire }
   If cur_tok_kw = KW_NOT Then
   Begin
    lbl_t := NewLabel; lbl_e := NewLabel;
    Consume;
    ParsePrimaryExpr := ParsePrimaryExpr;
    EmitI('TEST    AX, AX');
    EmitI('JNZ     ' + lbl_t);
    EmitI('MOV     AX, 0FFFFh');
    EmitI('JMP     ' + lbl_e);
    EmitLabel(lbl_t);
    EmitI('XOR     AX, AX');
    EmitLabel(lbl_e);
   End Else
   Begin
    s := cur_tok_str; Consume;
    { Appel built-in ou PERFORM comme expression }
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume;
     If Not GenBuiltIn(s) Then
     Begin
      { Appel de FORM comme expression (stub) }
      nargs := 0;
      While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) Do
      Begin
       ParseExpr;
       EmitI('PUSH    AX');
       Inc(nargs);
       If cur_tok_type = TOK_COMMA Then Consume;
      End;
      If cur_tok_type = TOK_RPAREN Then Consume;
      EmitI('CALL    ' + AsmIdent('_ABAP_FORM_', s));
      If nargs > 0 Then EmitI('ADD     SP, ' + ItoSI(nargs * 2));
     End;
    End Else
    Begin
     { Chargement d'une variable / constante }
     sym_idx := FindSym(s);
     If sym_idx > 0 Then
     Begin
      GenLoadVar(sym_idx);
      ParsePrimaryExpr := sym_table[sym_idx].data_type;
     End Else
     Begin
      EmitComment('Variable inconnue: ' + s + ' (suppose 0)');
      EmitI('XOR     AX, AX');
     End;
    End;
   End;
  End;
 Else
  EmitComment('ParsePrimaryExpr: token inattendu: ' + cur_tok_str);
  Consume;
 End;
End;

{ --- Niveau 2 : multiplication / division ---
  * / (DIV et MOD via formes verbales traitees par ParseArithVerb)           }
Function ParseMulExpr: Integer;
Var op: Integer;
Begin
 ParseMulExpr := ParsePrimaryExpr;
 While (cur_tok_type = TOK_STAR) Or (cur_tok_type = TOK_SLASH) Do
 Begin
  op := cur_tok_type; Consume;
  EmitI('PUSH    AX');
  ParseMulExpr := ParsePrimaryExpr;
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');
  GenBinOp(op);
 End;
End;

{ --- Niveau 3 : addition / soustraction --- }
Function ParseAddExpr: Integer;
Var op: Integer;
Begin
 ParseAddExpr := ParseMulExpr;
 While (cur_tok_type = TOK_PLUS) Or (cur_tok_type = TOK_MINUS) Do
 Begin
  op := cur_tok_type; Consume;
  EmitI('PUSH    AX');
  ParseAddExpr := ParseMulExpr;
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');
  GenBinOp(op);
 End;
End;

{ --- Niveau 4 : comparaison ---
  Operateurs : = <> < > <= >= EQ NE LT GT LE GE
  Formes speciales ABAP:
    var IS [NOT] INITIAL  -> TEST AX, AX
    var IS [NOT] BOUND    -> stub (0 / 1)
    var BETWEEN lo AND hi -> double comparaison                              }
Function ParseCompareExpr: Integer;
Var op, kw: Integer; lbl_f, lbl_e: String; is_not: Boolean;
Begin
 ParseCompareExpr := ParseAddExpr;
 { Operateurs de comparaison symboliques }
 op := cur_tok_type;
 kw := cur_tok_kw;
 If (op = TOK_EQ) Or (op = TOK_NE) Or
    (op = TOK_LT) Or (op = TOK_LE) Or
    (op = TOK_GT) Or (op = TOK_GE) Then
 Begin
  Consume;
  EmitI('PUSH    AX');
  ParseCompareExpr := ParseAddExpr;
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');
  GenCompare(op);
 End Else If (cur_tok_type = TOK_IDENT) And
             ((kw = KW_EQ) Or (kw = KW_NE) Or
              (kw = KW_LT) Or (kw = KW_LE) Or
              (kw = KW_GT) Or (kw = KW_GE)) Then
 Begin
  { Formes verbales EQ / NE / LT / GT / LE / GE }
  Consume;
  EmitI('PUSH    AX');
  ParseCompareExpr := ParseAddExpr;
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');
  GenCompare(kw);
 End Else If TokIsKw(KW_IS) Then
 Begin
  { var IS [NOT] INITIAL | BOUND }
  Consume;
  is_not := False;
  If TokIsKw(KW_NOT) Then Begin Consume; is_not := True; End;
  lbl_f := NewLabel; lbl_e := NewLabel;
  If TokIsKw(KW_INITIAL) Then
  Begin
   Consume;
   EmitI('TEST    AX, AX');
   If is_not Then EmitI('JNZ     ' + lbl_f)
   Else           EmitI('JZ      ' + lbl_f);
   EmitI('MOV     AX, 0FFFFh');
   EmitI('JMP     ' + lbl_e);
   EmitLabel(lbl_f);
   EmitI('XOR     AX, AX');
   EmitLabel(lbl_e);
  End Else If TokIsKw(KW_BOUND) Then
  Begin
   Consume;
   { IS BOUND : stub = toujours vrai (0FFFFh) }
   EmitComment('IS BOUND stub = vrai');
   If is_not Then EmitI('XOR     AX, AX')
   Else           EmitI('MOV     AX, 0FFFFh');
  End Else
   Warning('IS : predicat inconnu -> ignore');
 End Else If TokIsKw(KW_BETWEEN) Then
 Begin
  { var BETWEEN lo AND hi : vrai si lo <= var <= hi }
  { AX = var deja calcule }
  Consume;
  lbl_f    := NewLabel;
  lbl_e    := NewLabel;
  EmitI('PUSH    AX');        { sauver var }
  ParseAddExpr;               { AX = lo }
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');
  EmitI('PUSH    AX');        { re-sauver var }
  EmitI('CMP     AX, BX');   { var < lo ? }
  EmitI('JL      ' + lbl_f);
  EatKw(KW_AND);
  ParseAddExpr;               { AX = hi }
  EmitI('MOV     BX, AX');
  EmitI('POP     AX');        { restaurer var }
  EmitI('CMP     AX, BX');   { var > hi ? }
  EmitI('JG      ' + lbl_f);
  EmitI('MOV     AX, 0FFFFh');
  EmitI('JMP     ' + lbl_e);
  EmitLabel(lbl_f);
  EmitI('XOR     AX, AX');
  EmitLabel(lbl_e);
 End Else If TokIsKw(KW_IN) Then
 Begin
  { var IN sy-set (stub) : toujours faux }
  Consume;
  If cur_tok_type = TOK_IDENT Then Consume;
  EmitComment('IN set stub = faux');
  EmitI('XOR     AX, AX');
 End;
End;

{ --- Niveau 5 : NOT logique --- }
Function ParseNotExpr: Integer;
Var lbl_t, lbl_e: String;
Begin
 If TokIsKw(KW_NOT) Then
 Begin
  Consume;
  lbl_t := NewLabel; lbl_e := NewLabel;
  ParseNotExpr := ParseCompareExpr;
  EmitI('TEST    AX, AX');
  EmitI('JNZ     ' + lbl_t);
  EmitI('MOV     AX, 0FFFFh');
  EmitI('JMP     ' + lbl_e);
  EmitLabel(lbl_t);
  EmitI('XOR     AX, AX');
  EmitLabel(lbl_e);
 End Else
  ParseNotExpr := ParseCompareExpr;
End;

{ --- Niveau 6 : AND logique --- }
Function ParseAndExpr: Integer;
Begin
 ParseAndExpr := ParseNotExpr;
 While TokIsKw(KW_AND) Do
 Begin
  Consume;
  EmitI('PUSH    AX');
  ParseAndExpr := ParseNotExpr;
  EmitI('POP     BX');
  EmitI('AND     AX, BX');
 End;
End;

{ --- Niveau 7 (racine) : OR logique --- }
Function ParseExpr: Integer;
Begin
 ParseExpr := ParseAndExpr;
 While TokIsKw(KW_OR) Do
 Begin
  Consume;
  EmitI('PUSH    AX');
  ParseExpr := ParseAndExpr;
  EmitI('POP     BX');
  EmitI('OR      AX, BX');
 End;
End;

{ ============================================================================ }
{ TODO 09 - GENERATION DE CODE : INFRASTRUCTURE COMPLETE [COMPLET]            }
{ ============================================================================ }
{ Note : GenLoadVar, GenStoreVar, GenBinOp, GenCompare, GenBuiltIn sont        }
{ places dans la section TODO 08 car pre-requis par ParseExpr.                }
{ Ce TODO ajoute : GenLoadAddr, GenPrologue, GenEpilogue,                     }
{                  GenModDiv, GenClearVar, GenWordToStr.                       }

{ --- Charge l'ADRESSE d'une variable dans AX (pour CHANGING / LEA) ---
  Equivalent a LEA AX, var ; utile pour passer par reference dans PERFORM.   }
Procedure GenLoadAddr(sym_idx: Integer);
Var sc, bp: Integer; lbl: String;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenLoadAddr: idx invalide'); Exit; End;
 sc  := sym_table[sym_idx].store_class;
 bp  := sym_table[sym_idx].bp_offset;
 lbl := sym_table[sym_idx].asm_label;
 If sc = STORE_AUTO Then
 Begin
  If bp >= 0 Then EmitI('LEA     AX, [BP+' + ItoSI(bp) + ']')
  Else            EmitI('LEA     AX, [BP' + ItoSI(bp) + ']');
 End Else
  EmitI('LEA     AX, ' + lbl);
End;

{ --- Accede a une variable CHANGING via son adresse (DI pointe dessus) ---
  Utilise apres CALL FORM pour lire/ecrire un parametre CHANGING.            }
Procedure GenIndirectLoad;
Begin
 EmitI('MOV     AX, [DI]');
End;

Procedure GenIndirectStore;
Begin
 EmitI('MOV     [DI], AX');
End;

{ --- Prologue standard d'une FORM (sauvegarde frame) ---
  local_size : taille totale des variables locales en octets (positif).     }
Procedure GenPrologue(local_size: Integer);
Begin
 EmitI('PUSH    BP');
 EmitI('MOV     BP, SP');
 If local_size > 0 Then
  EmitI('SUB     SP, ' + ItoSI(local_size) + '  ; variables locales');
End;

{ --- Epilogue standard d'une FORM (restauration frame + retour) ---
  param_bytes : taille totale des parametres empiles (nparams * 2 octets).  }
Procedure GenEpilogue(param_bytes: Integer);
Begin
 EmitI('MOV     SP, BP');
 EmitI('POP     BP');
 If param_bytes > 0 Then
  EmitI('RET     ' + ItoSI(param_bytes))
 Else
  EmitI('RET');
End;

{ --- Division entiere et modulo : AX / BX ---
  is_div = True  -> resultat = quotient  (AX apres IDIV)
  is_div = False -> resultat = reste     (DX apres IDIV)                     }
Procedure GenModDiv(is_div: Boolean);
Begin
 EmitI('CWD');
 EmitI('IDIV    BX');
 If Not is_div Then
  EmitI('MOV     AX, DX  ; reste (MOD)');
End;

{ --- Efface une variable (CLEAR) ---
  TYPE I / N / P / F : MOV WORD PTR, 0
  TYPE C / STRING    : remplissage d'espaces (20h) jusqu'a char_len          }
Procedure GenClearVar(sym_idx: Integer);
Var sc, dt, bp, cl: Integer; lbl: String;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenClearVar: idx invalide'); Exit; End;
 sc  := sym_table[sym_idx].store_class;
 dt  := sym_table[sym_idx].data_type;
 bp  := sym_table[sym_idx].bp_offset;
 cl  := sym_table[sym_idx].char_len;
 lbl := sym_table[sym_idx].asm_label;
 EmitComment('CLEAR ' + sym_table[sym_idx].name);
 Case dt Of
  TYPE_I, TYPE_P, TYPE_F:
  Begin
   If sc = STORE_AUTO Then
   Begin
    If bp >= 0 Then EmitI('MOV     WORD PTR [BP+' + ItoSI(bp) + '], 0')
    Else            EmitI('MOV     WORD PTR [BP' + ItoSI(bp) + '], 0');
   End Else         EmitI('MOV     WORD PTR [' + lbl + '], 0');
  End;
  TYPE_C, TYPE_N, TYPE_D, TYPE_T, TYPE_STRING, TYPE_XSTRING:
  Begin
   { Remplir le buffer avec des espaces (20h) via REP STOSB }
   If cl < 1 Then cl := 1;
   EmitI('MOV     AL, 20h  ; espace');
   EmitI('MOV     CX, ' + ItoSI(cl));
   If sc = STORE_AUTO Then
   Begin
    If bp >= 0 Then EmitI('LEA     DI, [BP+' + ItoSI(bp) + ']')
    Else            EmitI('LEA     DI, [BP' + ItoSI(bp) + ']');
   End Else         EmitI('LEA     DI, ' + lbl);
   EmitI('REP     STOSB');
   { Terminer par '$' pour les routines PRINT_STR }
   EmitI('MOV     BYTE PTR [DI], 24h  ; terminateur $');
  End;
 Else
  { Types inconnus : juste un zero-word }
  If sc = STORE_AUTO Then
  Begin
   If bp >= 0 Then EmitI('MOV     WORD PTR [BP+' + ItoSI(bp) + '], 0')
   Else            EmitI('MOV     WORD PTR [BP' + ItoSI(bp) + '], 0');
  End Else         EmitI('MOV     WORD PTR [' + lbl + '], 0');
 End;
End;

{ --- Conversion AX (entier signe) vers chaine dans NUMBUF ---
  Utilise par _ABAP_PRINT_INT ; genere l'appel au helper runtime.            }
Procedure GenPrintInt;
Begin
 EmitI('PUSH    AX');
 EmitI('CALL    _ABAP_PRINT_INT');
 EmitI('ADD     SP, 2');
End;

{ --- Impression d'une chaine AX (pointeur vers chaine terminee '$') ---
  Genere l'appel au helper runtime _ABAP_PRINT_STR.                          }
Procedure GenPrintStr;
Begin
 EmitI('MOV     DX, AX');
 EmitI('CALL    _ABAP_PRINT_STR');
End;

{ --- Saut conditionnel depuis AX (resultat d'une expression boolenne) ---
  Saute vers lbl si la condition est FAUSSE (AX = 0).                        }
Procedure GenJmpIfFalse(Const lbl: String);
Begin
 EmitI('TEST    AX, AX');
 EmitI('JZ      ' + lbl);
End;

{ --- Saut conditionnel : saute si la condition est VRAIE (AX <> 0) --- }
Procedure GenJmpIfTrue(Const lbl: String);
Begin
 EmitI('TEST    AX, AX');
 EmitI('JNZ     ' + lbl);
End;

{ --- Saut inconditionnel --- }
Procedure GenJmp(Const lbl: String);
Begin
 EmitI('JMP     ' + lbl);
End;

{ ============================================================================ }
{ TODO 10 - PARSEUR : IF / ELSEIF / ELSE / ENDIF         [COMPLET]            }
{ ============================================================================ }

{ Forward pour ParseStatement (defini au TODO 23) }
Procedure ParseStatement; Forward;

{ Parse un bloc d'instructions jusqu'a l'un des trois mots-cles d'arret.
  Passe KW_NONE (=0) pour un emplacement inutilise.
  Note : KW_NONE = 0, donc on verifie kw <> KW_NONE avant TokIsKw pour eviter
  de confondre les identifiants non-mot-cle avec un marqueur d'arret.         }
Procedure ParseBlock(stop1, stop2, stop3: Integer);
Begin
 While (cur_tok_type <> TOK_EOF) Do
 Begin
  If ((stop1 <> KW_NONE) And TokIsKw(stop1)) Or
     ((stop2 <> KW_NONE) And TokIsKw(stop2)) Or
     ((stop3 <> KW_NONE) And TokIsKw(stop3)) Then Break;
  ParseStatement;
 End;
End;

{ Parse IF / ELSEIF / ELSE / ENDIF avec generation de code 8086.

  Syntaxe ABAP :
    IF condition.                  <- point apres la condition
      instructions.
    ELSEIF condition.             <- point apres la condition
      instructions.
    ELSE.                         <- point apres ELSE
      instructions.
    ENDIF.                        <- point apres ENDIF

  Generation :
    ParseExpr         -> AX = resultat booleen
    TEST AX, AX
    JZ  lbl_next      <- saute si faux
    ... corps ...
    JMP lbl_end
  lbl_next:
    (repeter pour chaque ELSEIF)
    (ELSE : corps direct sans test)
  lbl_end:
}
Procedure ParseIf;
Var lbl_next, lbl_end : String;
    first_branch      : Boolean;
Begin
 Consume; { skip IF }
 lbl_end      := NewLabel + 'EN';
 first_branch := True;

 { --- Boucle IF / ELSEIF --- }
 Repeat
  If first_branch Then EmitComment('---- IF ----')
  Else             EmitComment('---- ELSEIF ----');
  first_branch := False;

  lbl_next := NewLabel + 'NX';

  { Evaluer la condition -> AX }
  ParseExpr;

  { Consommer le point terminateur apres la condition }
  If cur_tok_type = TOK_DOT Then Consume
  Else Warning('Point attendu apres condition IF/ELSEIF');

  { Saut conditionnel si faux }
  GenJmpIfFalse(lbl_next);

  { Corps de la branche }
  EnterScope(SK_BLOCK, 0);
  ParseBlock(KW_ELSEIF, KW_ELSE, KW_ENDIF);
  LeaveScope;

  { Saut vers la fin apres le corps }
  GenJmp(lbl_end);

  { Etiquette du prochain ELSEIF ou de la fin de branche }
  EmitLabel(lbl_next);

  { Continuer la boucle si ELSEIF }
  If TokIsKw(KW_ELSEIF) Then
  Begin
   Consume; { skip ELSEIF }
   Continue;
  End;

  Break; { pas de ELSEIF : sortir }
 Until False;

 { --- Branche ELSE optionnelle --- }
 If TokIsKw(KW_ELSE) Then
 Begin
  Consume; { skip ELSE }
  If cur_tok_type = TOK_DOT Then Consume
  Else Warning('Point attendu apres ELSE');
  EmitComment('---- ELSE ----');
  EnterScope(SK_BLOCK, 0);
  ParseBlock(KW_ENDIF, KW_NONE, KW_NONE);
  LeaveScope;
 End;

 { --- ENDIF. --- }
 If TokIsKw(KW_ENDIF) Then
 Begin
  Consume; { skip ENDIF }
  If cur_tok_type = TOK_DOT Then Consume
  Else Warning('Point attendu apres ENDIF');
 End
 Else Error('ENDIF attendu');

 { Etiquette de fin commune a toutes les branches }
 EmitLabel(lbl_end);
End;

{ ============================================================================ }
{ TODO 11 - PARSEUR : CASE / WHEN / WHEN OTHERS / ENDCASE [COMPLET]           }
{ ============================================================================ }

{ Parse CASE variable. WHEN val [OR val2]. ... [WHEN OTHERS. ...] ENDCASE.

  Syntaxe ABAP :
    CASE var.
      WHEN val1.              instructions.
      WHEN val2 OR val3.      instructions.
      WHEN OTHERS.            instructions.
    ENDCASE.

  Generation 8086 :
    ParseExpr(var) -> AX ; MOV DX, AX     ; DX = valeur de selection
    Pour chaque WHEN :
      ParseExpr(val) -> AX ; CMP DX, AX
      S'il y a OR : JE lbl_body, puis ParseExpr(val_suivante) -> AX ; CMP DX, AX
      Apres la derniere valeur : JNE lbl_next
    lbl_body:
      corps
      JMP lbl_endcase
    lbl_next:   <- prochain WHEN ou fall-through vers ENDCASE
    WHEN OTHERS -> corps direct (pas de test), JMP lbl_endcase
    EmitLabel(lbl_endcase)
}
Procedure ParseCase;
Var lbl_endcase, lbl_next, lbl_body : String;
Begin
 Consume; { skip CASE }
 EmitComment('---- CASE ----');

 { Evaluer la variable de selection -> AX, puis sauvegarde dans DX }
 ParseExpr;
 EmitI('MOV     DX, AX');

 { Consommer le point apres la variable }
 If cur_tok_type = TOK_DOT Then Consume
 Else Warning('Point attendu apres variable CASE');

 lbl_endcase := NewLabel + 'EC';

 { ----------------------------------------------------------------
   Boucle sur les clauses WHEN
   ---------------------------------------------------------------- }
 While TokIsKw(KW_WHEN) Do
 Begin
  Consume; { skip WHEN }

  { WHEN OTHERS : clause par defaut }
  If TokIsKw(KW_OTHERS) Then
  Begin
   Consume; { skip OTHERS }
   If cur_tok_type = TOK_DOT Then Consume
   Else Warning('Point attendu apres WHEN OTHERS');
   EmitComment('---- WHEN OTHERS ----');
   EnterScope(SK_BLOCK, 0);
   ParseBlock(KW_ENDCASE, KW_NONE, KW_NONE);
   LeaveScope;
   GenJmp(lbl_endcase);
   Break; { WHEN OTHERS termine la liste des clauses }
  End;

  { WHEN valeur [OR valeur2 ...] }
  lbl_next := NewLabel + 'WN';
  lbl_body := NewLabel + 'WB';
  EmitComment('---- WHEN ----');

  { Evaluer la premiere valeur -> AX, comparer avec DX }
  ParseExpr;
  EmitI('CMP     DX, AX');

  { Valeurs supplementaires separees par OR }
  While TokIsKw(KW_OR) Do
  Begin
   EmitI('JE      ' + lbl_body); { correspond a cette valeur -> corps }
   Consume; { skip OR }
   ParseExpr; { valeur suivante -> AX }
   EmitI('CMP     DX, AX');
  End;

  { Apres la derniere valeur : sauter si pas egal }
  EmitI('JNE     ' + lbl_next);

  { --- Corps de la clause --- }
  EmitLabel(lbl_body);
  If cur_tok_type = TOK_DOT Then Consume
  Else Warning('Point attendu apres valeur(s) WHEN');

  EnterScope(SK_BLOCK, 0);
  ParseBlock(KW_WHEN, KW_ENDCASE, KW_NONE);
  LeaveScope;
  GenJmp(lbl_endcase);

  { Etiquette pour la clause suivante }
  EmitLabel(lbl_next);
 End; { While WHEN }

 { ENDCASE. }
 If TokIsKw(KW_ENDCASE) Then
 Begin
  Consume;
  If cur_tok_type = TOK_DOT Then Consume
  Else Warning('Point attendu apres ENDCASE');
 End
 Else Error('ENDCASE attendu');

 EmitLabel(lbl_endcase);
End;

{ ============================================================================ }
{ TODO 23 (stub) - ParseStatement : sera complete au TODO 23                   }
{ ============================================================================ }

Procedure ParseStatement;
Begin
 { Stub requis pour resoudre le Forward de ParseBlock/ParseIf. }
 { TODO 23 : dispatcher complet sur cur_tok_type / cur_kw. }
 Error('ParseStatement : non encore implemente (stub TODO 23)');
 Consume;
End;

Begin
End.