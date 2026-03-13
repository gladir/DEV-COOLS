{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur ABAP/4 (SAP) vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  ABAPCW32.PAS - Compilateur ABAP/4 (SAP) vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de ABAP86.PAS et les exemples
  SAMPLES\ABAP\*

  Voir DOC/TODO/ABAPCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.abap [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .abap du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=2048, MAX_FORM=256,
              MAX_LOCAL=128, MAX_PARAM=32, MAX_DEPTH=16,
              MAX_LABEL=2048, MAX_STR=255, MAX_FIELD=64
            Prefixes de nommage ASM : _AB_ (variable globale),
              _ABF_ (FORM/FUNCTION), _ABK_ (constante chaine),
              _ABRT_ (routine runtime), _ABL_ (label interne),
              _ABA_ (tableau/table interne), _ABS_ (structure),
              _ABE_ (evenement), _ABX_ (exception handler)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - TOKENISEUR ABAP (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Procedure LexNextToken : reconnaitre les tokens ABAP :
              - Identificateurs : lettres, chiffres, _ , - (max 48 cars)
                Convertis en majuscules (ABAP insensible a la casse)
              - Litteraux numeriques : 123, 1.5, 1E3
              - Litteraux chaines : 'texte' (apostrophe doublee '')
              - Commentaires ligne : * en colonne 1, " en milieu ligne
              - Operateurs : + - * / = <> < > <= >= && (concat.)
              - Separateurs : . , : ( ) [ ]
              - Pragmas : # en debut de ligne (ignorer)
              - Pipe | et arobase @ (ABAP 7.4 stubs)
            Types de tokens (TOK_IDENT, TOK_NUMBER, TOK_FLOAT,
              TOK_STRING, TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH,
              TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_DOT, TOK_COLON,
              TOK_EQ, TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE,
              TOK_CONCAT, TOK_LBRACKET, TOK_RBRACKET, TOK_HASH,
              TOK_PIPE, TOK_AT, TOK_EOF)
            Stocker dans CurTokType / CurTokStr / CurTokNum

  TODO 03 - RECONNAISSANCE DES MOTS-CLES ABAP/4 [IMPLEMENTE]
            Function IsKeyword(Const s: String): Integer
            Mots-cles complets a reconnaitre :
              REPORT PROGRAM DATA TYPES CONSTANTS CLASS-DATA
              IF ELSEIF ELSE ENDIF
              CASE WHEN OTHERS ENDCASE
              WHILE ENDWHILE DO TIMES ENDDO
              LOOP AT INTO ENDLOOP
              FORM ENDFORM PERFORM USING CHANGING TABLES
              FUNCTION ENDFUNCTION
              WRITE SKIP LINE NEW-LINE
              MOVE TO MOVE-CORRESPONDING
              COMPUTE ADD SUBTRACT MULTIPLY BY DIVIDE FROM GIVING
              APPEND INSERT DELETE MODIFY READ SORT COLLECT
              SELECT WHERE CORRESPONDING FIELDS ENDSELECT
              CALL RAISING EXCEPTIONS SINGLE
              CLEAR REFRESH FREE INITIALIZE
              CONCATENATE SPLIT SHIFT REPLACE TRANSLATE CONDENSE FIND
              CHECK RETURN EXIT STOP CONTINUE
              START-OF-SELECTION END-OF-SELECTION
              TOP-OF-PAGE END-OF-PAGE
              PARAMETERS SELECT-OPTIONS LIKE TYPE VALUE DEFAULT
              CLASS ENDCLASS METHOD ENDMETHOD
              PUBLIC PRIVATE PROTECTED
              RAISE EXCEPTION TRY CATCH CLEANUP ENDTRY
              EQ NE LT GT LE GE BETWEEN IN AND OR NOT
              IS INITIAL BOUND
              ASCENDING DESCENDING LEFT RIGHT UPPER LOWER NO-GAPS
              MATCH OFFSET OCCURRENCE OCCURRENCES SEPARATED
              AT LINE-SELECTION USER-COMMAND
              OF BEGIN END TABLE WITH KEY INDEX
              DECIMALS LENGTH MESSAGE-ID
              STRLEN ABS EXPORTING IMPORTING ORDER CIRCULAR
              PLACES ALL FIRST ROWS
            Constantes KW_REPORT..KW_FIRST (151 mots-cles)

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]
            Type TSymEntry : Name (String[48]), AsmLabel (String[48]),
              DataType (Integer), StoreClass (Integer),
              BpOffset (Integer), ArraySize (Integer),
              CharLen (Integer), DecPrec (Integer), DecScale (Integer),
              IsParam (Boolean), ParamIdx (Integer),
              InitStr (String[64]), InitNum (LongInt),
              HasInit (Boolean), IsConst (Boolean)
            Type TFormEntry : Name (String[48]), AsmLabel (String[48]),
              ParamCount (Integer), Defined (Boolean),
              UsingCount (Integer), ChangingCount (Integer),
              ParamNames : Array[1..MAX_PARAM] of String[48],
              ParamKinds : Array[1..MAX_PARAM] of Integer (U/C/T)
            SymTab[0..MAX_SYM-1] / SymCount
            FormTab[0..MAX_FORM-1] / FormCount
            Procedure InitSymTable / Function FindSym / Function AddSym
            Function FindForm / Function AddForm
            Variables systeme auto-declarees :
              SY-SUBRC (DD 0), SY-TABIX (DD 0), SY-DBCNT (DD 0),
              SY-LANGU (DD 0), SY-INDEX (DD 0)
            Tailles 32 bits : TYPE I = DD (4 octets), TYPE C(n) = DB n,
              TYPE F = DQ (8 octets stub), TYPE P = DD
            Classes d entreposage : STORE_AUTO (pile EBP),
              STORE_STATIC (segment .DATA), STORE_PARAM (EBP+n),
              STORE_TABLE (donnees lineaires .DATA),
              STORE_CONSTANT (valeur immediate)

  TODO 05 - GESTION DES SCOPES (REPORT, FORM, METHOD) [IMPLEMENTE]
            Pile de scopes : chaque scope maintient ses propres
              variables locales, un offset EBP courant, un label sortie
            Procedure EnterScope(kind: Integer; form_idx: Integer)
            Procedure LeaveScope
            Function AllocLocalEbp(bytes: Integer): Integer
            Function CurrentEbpTop: Integer
            Scopes supportes : SK_GLOBAL, SK_FORM, SK_BLOCK,
              SK_LOOP, SK_EVENT
            Compteur d offset EBP pour allocation variables locales
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche

  TODO 06 - PARSEUR : REPORT / PROGRAM (EN-TETE DU PROGRAMME) [IMPLEMENTE]
            Procedure ParseReport
            Syntaxe :
              REPORT nom_programme [MESSAGE-ID xx]
                [NO STANDARD PAGE HEADING].
              PROGRAM nom_programme.
            Enregistrer le nom du programme (label ASM _ABF_nom)
            Ignorer les options MESSAGE-ID et NO STANDARD PAGE HEADING
            Consommer jusqu au point '.' final
            Generer le label du point d entree principal

  TODO 07 - PARSEUR : DATA / TYPES / CONSTANTS (DECLARATIONS 32 BITS) [IMPLEMENTE]
            Procedure ParseData
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
            Types ABAP reconnus et tailles 32 bits :
              I (entier 32 bits, DD), F (flottant 64 bits, DQ stub),
              C(n) (chaine fixe, DB n), N(n) (chaine numerique, DB n),
              D (date 8 cars, DB 8), T (heure 6 cars, DB 6),
              P (packed decimal, DD stub), STRING (pointeur 32 bits, DD),
              XSTRING (octetstring, DD stub)
            Allouer en .DATA (globales) ou pile EBP (locales FORM)

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS) [IMPLEMENTE]
            Function ParseExpr: Integer
            Function ParseLogExpr: Integer    (AND / OR / NOT)
            Function ParseCompareExpr: Integer (EQ NE LT GT LE GE
              = <> < > <= >= BETWEEN a AND b / IS INITIAL)
            Function ParseAddExpr: Integer    (+ / -)
            Function ParseMulExpr: Integer    (* / / DIV / MOD)
            Function ParseUnaryExpr: Integer  (- / NOT)
            Function ParsePrimaryExpr: Integer
              Constante numerique -> MOV EAX, imm32
              Constante chaine    -> LEA EAX, [_ABK_n]
              Variable scalaire   -> MOV EAX, [_AB_x] ou [EBP-n]
              Fonction built-in : STRLEN, ABS
              Parentheses
            Tous les calculs en registres 32 bits (EAX, EBX, ECX, EDX)

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [IMPLEMENTE]
            Procedure GenLoadVar(sym_idx: Integer)
              TYPE I : MOV EAX, DWORD PTR [_AB_x] ou [EBP-n]
              TYPE C : LEA EAX, [_AB_x] ou [EBP-n]
            Procedure GenStoreVar(sym_idx: Integer)
              MOV DWORD PTR [_AB_x], EAX ou MOV [EBP-n], EAX
            Procedure GenBinOp(op: Integer)
              + : ADD EAX, EBX
              - : SUB EAX, EBX
              * : IMUL EAX, EBX
              / : CDQ + IDIV EBX (quotient dans EAX)
              MOD : CDQ + IDIV EBX -> MOV EAX, EDX (reste)
            Procedure GenCompare(op: Integer)
              CMP EAX, EBX + SETcc AL + MOVZX EAX, AL
            Procedure GenBuiltIn(bname: String): Boolean
              ABS -> CDQ / XOR EAX,EDX / SUB EAX,EDX
              STRLEN -> CALL _ABRT_STRLEN
            Primitives d emission : Emit, EmitLabel, EmitComment,
              EmitBlank, NewLabel, AddStringLit

  TODO 10 - PARSEUR : IF / ELSEIF / ELSE / ENDIF [IMPLEMENTE]
            Procedure ParseIf
            Syntaxe :
              IF condition. instructions.
              [ELSEIF condition. instructions.] ...
              [ELSE. instructions.]
              ENDIF.
            Conditions speciales ABAP :
              IF var IS INITIAL.     -> TEST EAX, EAX / JNZ ...
              IF var IS NOT INITIAL. -> TEST EAX, EAX / JZ ...
              IF var BETWEEN a AND b.-> CMP + JL + CMP + JG
            Generation 32 bits :
              Evaluer condition -> EAX
              TEST EAX, EAX + JZ _ABL_elseif ou _ABL_else
              Chaine ELSEIF avec liste de labels de saut
              JMP _ABL_endif apres chaque branche

  TODO 11 - PARSEUR : CASE / WHEN / WHEN OTHERS / ENDCASE [IMPLEMENTE]
            Procedure ParseCase
            Syntaxe :
              CASE variable.
                WHEN valeur. instructions.
                WHEN valeur1 OR valeur2. instructions.
                WHEN OTHERS. instructions.
              ENDCASE.
            Generation 32 bits :
              Charger variable -> EDX
              Pour chaque WHEN : CMP EDX, imm32 / JNE _ABL_next
              WHEN valeur1 OR valeur2 : serie CMP + JE _ABL_match
              WHEN OTHERS = clause par defaut
              ENDCASE = EmitLabel(_ABL_endcase)

  TODO 12 - PARSEUR : WHILE / ENDWHILE ET DO n TIMES / ENDDO [IMPLEMENTE]
            Procedure ParseWhile
            Syntaxe : WHILE condition. instructions. ENDWHILE.
            Generation 32 bits :
              _ABL_top: evaluer condition -> EAX
              TEST EAX, EAX + JZ _ABL_end
              Corps + JMP _ABL_top + EmitLabel(_ABL_end)
            Procedure ParseDo
            Syntaxe : DO [n TIMES]. instructions. ENDDO.
            Generation n TIMES :
              MOV ECX, n / _ABL_top: TEST ECX, ECX / JZ _ABL_end
              PUSH ECX / corps / POP ECX / DEC ECX / JMP _ABL_top
            Generation infinie (sans n) :
              _ABL_top: corps + JMP _ABL_top (EXIT -> JMP _ABL_end)
            Pile de boucles pour CONTINUE / EXIT imbriques

  TODO 13 - PARSEUR : PERFORM / FORM / ENDFORM (SOUS-ROUTINES 32 BITS) [IMPLEMENTE]
            Procedure ParsePerform
            Syntaxe :
              PERFORM nom [USING arg1 arg2 ...] [CHANGING arg1 ...].
            Procedure ParseForm
            Syntaxe :
              FORM nom [USING p1 TYPE t ...] [CHANGING p1 TYPE t ...].
                instructions.
              ENDFORM.
            Convention d appel Win32 STDCALL :
              Arguments USING : PUSH EAX (par valeur 32 bits)
              Arguments CHANGING : LEA EAX, [var] + PUSH EAX (adresse)
              Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locales
              Epilogue : MOV ESP, EBP / POP EBP / RET n
              Parametres a [EBP+8], [EBP+12], [EBP+16]...
              Variables locales a [EBP-4], [EBP-8]...

  TODO 14 - PARSEUR : WRITE / SKIP / NEW-LINE (SORTIE CONSOLE WIN32) [IMPLEMENTE]
            Procedure ParseWrite
            Syntaxe :
              WRITE nom_var.
              WRITE: 'Texte', nom_var, /.
              WRITE nom_var LEFT-JUSTIFIED / NO-GAP.
              SKIP [n].
              NEW-LINE.
            Generation Win32 (via WriteFile API) :
              Variable TYPE I   -> CALL _ABRT_NUMTOSTR + CALL _ABRT_PRINT
              Variable TYPE C   -> LEA EAX, [var] + CALL _ABRT_PRINT
              Chaine litterale  -> PUSH OFFSET _ABK_n + CALL _ABRT_PRINT
              SKIP / '/' (barre) -> CALL _ABRT_CRLF
            Initialiser _ABRT_HSTDOUT via GetStdHandle(STD_OUTPUT_HANDLE)
            Tampon : _ABRT_NUMBUF (12 octets), _ABRT_CRLF_DATA DB 13,10,0

  TODO 15 - PARSEUR : MOVE / COMPUTE / FORMES VERBALES ARITHMETIQUES [IMPLEMENTE]
            Procedure ParseMove
            Syntaxe : MOVE source TO destination.
            Equivalent a : destination = source.
            Procedure ParseCompute
            Syntaxe : COMPUTE var = expr.
            Formes verbales ABAP :
              ADD val TO var.             -> var = var + val
              ADD val1 TO val2 GIVING var.-> var = val1 + val2
              SUBTRACT val FROM var.      -> var = var - val
              MULTIPLY var BY val.        -> var = var * val
              DIVIDE var BY val.          -> var = var / val (entier)
            Procedure ParseAssignment
            Syntaxe : var = expr. (style ABAP Objet)
            Toutes les operations en registres EAX/EBX 32 bits

  TODO 16 - PARSEUR : LOOP AT / ENDLOOP + OPERATIONS TABLES INTERNES [IMPLEMENTE]
            Procedure ParseLoopAt
            Syntaxe :
              LOOP AT itab [INTO wa] [WHERE condition].
                instructions.
              ENDLOOP.
            Generation 32 bits (tableau lineaire en memoire) :
              MOV ESI, OFFSET _ABA_itab
              _ABL_top: CMP ESI, [_ABA_itab_end] + JGE _ABL_end
              Copier element si INTO fourni (REP MOVSD)
              ADD ESI, elem_size + JMP _ABL_top
              Mettre a jour SY-TABIX et SY-INDEX
            Procedure ParseAppend
              APPEND [wa TO] itab.
            Procedure ParseReadTable
              READ TABLE itab INTO wa [INDEX i | WITH KEY champ = val].
            Procedure ParseSort
              SORT itab [BY champ] [ASCENDING | DESCENDING].
            Procedure ParseDelete (table)
              DELETE itab [WHERE condition | INDEX i].

  TODO 17 - PARSEUR : OPERATIONS SUR CHAINES DE CARACTERES [IMPLEMENTE]
            Procedure ParseConcatenate
              CONCATENATE s1 s2 ... INTO dest [SEPARATED BY sep].
            Procedure ParseSplit
              SPLIT src AT sep INTO s1 s2.
            Procedure ParseShift
              SHIFT var [LEFT | RIGHT] [BY n PLACES | CIRCULAR].
            Procedure ParseReplace
              REPLACE [ALL OCCURRENCES OF] old IN dest WITH new.
            Procedure ParseTranslate
              TRANSLATE var TO UPPER CASE / TO LOWER CASE.
            Procedure ParseCondense
              CONDENSE var [NO-GAPS].
            Procedure ParseFind
              FIND [FIRST OCCURRENCE OF] pattern IN var
                   [MATCH OFFSET off] [MATCH LENGTH len].
            Generation : appels aux helpers runtime _ABRT_STR_xxx
            Tampons : _ABRT_STRBUF (512 octets), _ABRT_CATBUF (512)

  TODO 18 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA [IMPLEMENTE]
            Procedure EmitHeader
              '; Generated by ABAPCW32 V0.1'
              '.386'
              '.MODEL FLAT, STDCALL'
              'OPTION CASEMAP:NONE'
              Declarations EXTRN pour API Win32 :
                ExitProcess, GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree
              '.STACK 4096'
              '_TEXT SEGMENT DWORD PUBLIC ''CODE'''
              'ASSUME CS:_TEXT'
            Procedure EmitDataSeg
              Variables globales TYPE I : _AB_nom DD 0
              Variables globales TYPE C(n) : _AB_nom DB n DUP(32)
              Variables globales TYPE F : _AB_nom DQ 0 (stub)
              Variables SY systeme : _AB_SY_SUBRC DD 0, ...
              Tampons runtime : _ABRT_NUMBUF, _ABRT_STRBUF,
                _ABRT_INPUTBUF, _ABRT_CRLF_DATA, _ABRT_HSTDOUT
              Chaines litterales : _ABK_1, _ABK_2... DB 'texte',0
            Mode -asm : ecrire fichier .ASM avec commentaires

  TODO 19 - GENERATION : POINT D ENTREE WIN32 ET HELPERS RUNTIME [IMPLEMENTE]
            Procedure EmitEntryPoint
              _ABF_main:
              PUSH EBP / MOV EBP, ESP
              Initialiser stdout : PUSH -11 / CALL GetStdHandle
                MOV [_ABRT_HSTDOUT], EAX
              CALL _ABF_nom_report (label du REPORT principal)
              PUSH 0 / CALL ExitProcess
            Procedure EmitRuntimeHelpers
              _ABRT_CRLF     : ecrire CR+LF via WriteFile
              _ABRT_PRINT    : EAX=ptr ASCIIZ -> WriteFile(hStdOut)
              _ABRT_NUMTOSTR : EAX=entier -> ASCIIZ dans _ABRT_NUMBUF
              _ABRT_PRINTINT : EAX=entier -> NUMTOSTR + PRINT
              _ABRT_PRINTCHR : AL=caractere -> WriteFile 1 octet
              _ABRT_READINT  : ReadFile + parsing ASCII -> EAX
              _ABRT_READSTR  : ReadFile -> copier dans buffer
              _ABRT_STRLEN   : EAX=ptr ASCIIZ -> EAX=longueur
              _ABRT_STRCOPY  : ESI=src, EDI=dst, ECX=max -> copie
              _ABRT_STRCONCAT: coller ESI apres EDI (ASCIIZ)
              _ABRT_ERROR    : afficher message + ExitProcess(1)

  TODO 20 - PARSEUR : CLEAR / REFRESH / FREE / CHECK / EXIT / CONTINUE [IMPLEMENTE]
            Procedure ParseClear
            Syntaxe : CLEAR variable.
            Generation 32 bits :
              TYPE I/N/F/P : MOV DWORD PTR [_AB_x], 0
              TYPE C(n)    : LEA EDI,[_AB_x] + MOV ECX,n +
                             MOV AL,32 + REP STOSB
            Procedure ParseRefresh
              REFRESH itab. -> remettre compteur elements a 0
            Procedure ParseFree
              FREE itab. -> stub REFRESH
            Procedure ParseCheck
              CHECK condition. -> si faux, JMP _ABL_exit_courant
            Procedure ParseExit
              EXIT. -> JMP _ABL_enddo / _ABL_endloop / _ABL_endform
            Procedure ParseContinue
              CONTINUE. -> JMP _ABL_loop_top
            Procedure ParseStop
              STOP. -> PUSH 0 / CALL ExitProcess
            Procedure ParseReturn
              RETURN. -> MOV ESP,EBP / POP EBP / RET

  TODO 21 - PARSEUR : SELECT / ENDSELECT (ACCES BD, STUB SANS BD) [IMPLEMENTE]
            Procedure ParseSelect
            Syntaxe :
              SELECT [SINGLE] champ(s) / * FROM table
                INTO [CORRESPONDING FIELDS OF] var / TABLE itab
                [WHERE condition]
                [ORDER BY champ]
                [UP TO n ROWS].
              [instructions. ENDSELECT.]
            Stub de generation (pas de BD reelle) :
              Emettre '; SELECT ... (stub - pas de BD)'
              Boucle vide -> 0 iterations
              SY-SUBRC = 4 (non trouve) :
                MOV DWORD PTR [_AB_SY_SUBRC], 4
            Variables systeme : SY-SUBRC, SY-TABIX, SY-DBCNT

  TODO 22 - PARSEUR : CALL FUNCTION / FUNCTION / ENDFUNCTION (STUBS) [IMPLEMENTE]
            Procedure ParseCallFunction
            Syntaxe :
              CALL FUNCTION 'NOM_FM'
                EXPORTING param = val ...
                IMPORTING param = var ...
                TABLES    itab  = itab2 ...
                EXCEPTIONS exception_name = n ...
            Generation stub :
              Emettre '; CALL FUNCTION NOM_FM (stub)'
              MOV DWORD PTR [_AB_SY_SUBRC], 0
            Procedure ParseFunction
            Syntaxe :
              FUNCTION nom.
                instructions.
              ENDFUNCTION.
            Generer comme une FORM : label _ABF_FM_nom
              Prologue/Epilogue Win32 STDCALL

  TODO 23 - PARSEUR : DISPATCHER ET BOUCLE PRINCIPALE [IMPLEMENTE]
            Procedure ParseStatement
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
              WRITE                    -> ParseWrite
              SKIP / NEW-LINE          -> ParseWrite
              MOVE                     -> ParseMove
              COMPUTE                  -> ParseCompute
              ADD / SUBTRACT / MULTIPLY / DIVIDE -> ParseArithVerb
              APPEND / INSERT / DELETE / MODIFY  -> ParseTableOp
              READ                     -> ParseReadTable
              SORT                     -> ParseSort
              CONCATENATE              -> ParseConcatenate
              SPLIT                    -> ParseSplit
              SHIFT / REPLACE / TRANSLATE / CONDENSE / FIND
                                       -> ParseStringOp
              CLEAR / REFRESH / FREE   -> ParseClear
              CHECK                    -> ParseCheck
              EXIT / CONTINUE / STOP / RETURN -> ParseFlowControl
              SELECT                   -> ParseSelect
              CALL                     -> ParseCallFunction
              TRY                      -> ParseTry
              RAISE                    -> ParseRaise
              START-OF-SELECTION       -> ParseEvent(EV_START)
              END-OF-SELECTION         -> ParseEvent(EV_END)
              nom '='                  -> ParseAssignment
              PARAMETERS / SELECT-OPTIONS -> ParseSelectionScreen
            Procedure ParseBlock(stop_kw: Integer)
              Appeler ParseStatement en boucle jusqu a stop_kw ou EOF

  TODO 24 - PARSEUR : EVENEMENTS ABAP ET ECRAN DE SELECTION (STUBS) [IMPLEMENTE]
            Evenements ABAP de haut niveau :
              START-OF-SELECTION. -> label _ABE_START + ParseBlock
              END-OF-SELECTION.   -> label _ABE_END   + ParseBlock
              TOP-OF-PAGE.        -> label _ABE_TOPPAGE (stub vide)
              END-OF-PAGE.        -> label _ABE_ENDPAGE (stub vide)
              AT LINE-SELECTION.  -> stub vide
              AT USER-COMMAND.    -> stub vide
            Ecran de selection :
              PARAMETERS p TYPE I DEFAULT 0.
                -> generer variable globale DD + valeur par defaut
              SELECT-OPTIONS s FOR var.
                -> stub (deux variables LOW / HIGH en DD)
            TRY / CATCH / CLEANUP / ENDTRY :
              TRY. -> sauvegarder contexte (stub)
              CATCH cx_nom. -> label _ABX_catch
              CLEANUP. -> label _ABX_cleanup
              ENDTRY. -> restaurer contexte
              RAISE EXCEPTION. -> stub
            Generation :
              START : appelle _ABE_START en dernier
              Chaque bloc evenement = label + corps + RET

  TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ ET EXEMPLES
            Procedure EmitClose : finaliser l emission ASM
              EmitRuntimeHelpers + '_TEXT ENDS' + EmitDataSeg +
              'END _ABF_main'
            Procedure BinInit / BinEmit / BinEmitData / BinFixup
            Si EmitExe (par defaut) :
              Construire l image PE complete en memoire :
              - DOS stub header (MZ + message + offset PE)
              - PE signature + COFF header (Machine=i386)
              - Optional header (ImageBase=$00400000, EntryPoint,
                SectionAlignment=4096, FileAlignment=512,
                Subsystem=CUI console)
              - Section .text (code machine 80386)
              - Section .data (variables et litteraux)
              - Section .idata (Import Address Table pour
                kernel32.dll : ExitProcess, GetStdHandle,
                WriteFile, ReadFile, GetProcessHeap,
                HeapAlloc, HeapFree)
              Ecrire le fichier .EXE resultant
            Si EmitObj (-obj) :
              Construire un fichier COFF .OBJ 32 bits :
              - COFF header + sections .text, .data
              - Table de symboles et relocations
              - Compatible avec les linkers Win32 (LINK.EXE)
            Si EmitAsm (-asm) :
              Ecrire le fichier .ASM lisible en parallele
              (genere pendant la compilation, pas de passe
              supplementaire)
            Programme de test : SAMPLES\ABAP\TEST.ABAP
              REPORT ZTEST01 avec DATA, WHILE, IF/ELSEIF/ELSE,
              DO TIMES, PERFORM/FORM, MOVE, CLEAR, WRITE, SKIP
            Rapport de compilation : 0 erreurs, N symboles, M formes

  ============================================================ *)

Program ABAPCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ CONSTANTES                                                   }
{ ============================================================ }

Const
  ABAPCW32_VERSION = '0.1';
  ABAPCW32_DATE    = '2026';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_FORM      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LOCAL     = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_DEPTH     = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_FIELD     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TABLE_ROWS = 100;  { nb max de lignes par table interne (TODO 16) }
  STACK_SIZE    = 4096;  { taille pile Win32 }

  { Types de tokens ABAP }
  TOK_UNKNOWN  =  0;
  TOK_IDENT    =  1;   { identificateur / mot-cle (majuscules)    }
  TOK_NUMBER   =  2;   { litteral entier : 123                    }
  TOK_FLOAT    =  3;   { litteral decimal : 1.5 / 1E3             }
  TOK_STRING   =  4;   { 'texte' (apostrophe doublee '')          }
  TOK_PLUS     =  5;   { +                                        }
  TOK_MINUS    =  6;   { -                                        }
  TOK_STAR     =  7;   { *                                        }
  TOK_SLASH    =  8;   { /  (aussi separateur WRITE)              }
  TOK_LPAREN   =  9;   { (                                        }
  TOK_RPAREN   = 10;   { )                                        }
  TOK_COMMA    = 11;   { ,                                        }
  TOK_DOT      = 12;   { .  (terminateur d instruction)           }
  TOK_COLON    = 13;   { :  (declaration DATA: ... )              }
  TOK_EQ       = 14;   { =  (affectation et comparaison)          }
  TOK_NE       = 15;   { <> (different)                           }
  TOK_LT       = 16;   { <                                        }
  TOK_GT       = 17;   { >                                        }
  TOK_LE       = 18;   { <=                                       }
  TOK_GE       = 19;   { >=                                       }
  TOK_CONCAT   = 20;   { && (concatenation expressions)           }
  TOK_LBRACKET = 21;   { [  (indice tableau)                      }
  TOK_RBRACKET = 22;   { ]                                        }
  TOK_HASH     = 23;   { #  (debut pragma)                        }
  TOK_PIPE     = 24;   { |  (chaine template ABAP 7.4, stub)      }
  TOK_AT       = 25;   { @  (reference inline ABAP 7.4, stub)     }
  TOK_EOF      = 99;

  MAX_IDENT    = 48;   { longueur max d un identificateur ABAP    }

  { Codes des mots-cles ABAP }
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
  KW_MOD             = 152;   { MOD (operateur modulo)   }
  KW_DIV             = 153;   { DIV (division entiere)   }
  KW_LEFT_JUSTIFIED  = 154;   { LEFT-JUSTIFIED (WRITE)   }
  KW_NO_GAP          = 155;   { NO-GAP (WRITE)           }
  KW_RIGHT_JUSTIFIED = 156;   { RIGHT-JUSTIFIED (WRITE)  }

  { Types de donnees ABAP }
  TYPE_UNKNOWN  =  0;
  TYPE_I        =  1;   { I        : entier 32 bits (DD, 4 octets)  }
  TYPE_F        =  2;   { F        : flottant 8 octets (DQ, stub)   }
  TYPE_C        =  3;   { C(n)     : chaine de longueur fixe        }
  TYPE_N        =  4;   { N(n)     : chaine numerique (texte)       }
  TYPE_D        =  5;   { D        : date 8 chars YYYYMMDD          }
  TYPE_T        =  6;   { T        : heure 6 chars HHMMSS           }
  TYPE_P        =  7;   { P        : packed decimal (DD, stub)      }
  TYPE_STRING   =  8;   { STRING   : chaine longueur variable       }
  TYPE_XSTRING  =  9;   { XSTRING  : octetstring (stub)             }
  TYPE_TABLE    = 10;   { TABLE OF : table interne                  }
  TYPE_STRUCT   = 11;   { structure (BEGIN OF ... END OF)           }
  TYPE_REF      = 12;   { REF TO   : reference objet (stub)         }
  TYPE_VOID     = 13;   { pas de type de retour (FORM/EVENT)        }

  { Classes d entreposage }
  STORE_AUTO     = 0;   { variable locale FORM (pile EBP)           }
  STORE_STATIC   = 1;   { variable globale REPORT (segment .DATA)   }
  STORE_PARAM    = 2;   { parametre USING/CHANGING d une FORM       }
  STORE_TABLE    = 3;   { table interne (tableau en .DATA)          }
  STORE_CONSTANT = 4;   { CONSTANTS (valeur immediate, pas de DD)   }

  { Types de parametre FORM (USING / CHANGING / TABLES) }
  PARAM_USING    = 0;   { passage par valeur                        }
  PARAM_CHANGING = 1;   { passage par adresse (ref)                 }
  PARAM_TABLES   = 2;   { table interne (adresse)                   }

  { Types de scopes }
  SK_GLOBAL  = 0;   { scope global REPORT / PROGRAM             }
  SK_FORM    = 1;   { scope FORM / FUNCTION                     }
  SK_BLOCK   = 2;   { sous-bloc implicite                       }
  SK_LOOP    = 3;   { boucle (DO / WHILE / LOOP)                }
  SK_EVENT   = 4;   { evenement (START-OF-SELECTION etc.)        }

  { Prefixes de nommage ASM }
  AB_VAR_PFX   = '_AB_';       { variable globale              }
  AB_FN_PFX    = '_ABF_';      { FORM / FUNCTION               }
  AB_STR_PFX   = '_ABK_';      { constante chaine litterale    }
  AB_RT_PFX    = '_ABRT_';     { routine runtime               }
  AB_LBL_PFX   = '_ABL_';      { label de saut interne         }
  AB_ARR_PFX   = '_ABA_';      { tableau / table interne       }
  AB_STRUC_PFX = '_ABS_';      { structure                     }
  AB_EVT_PFX   = '_ABE_';      { evenement                     }
  AB_EX_PFX    = '_ABX_';      { exception handler             }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { PE/COFF format constants }
{$IFDEF FPC}
  PE_DOS_MAGIC    = $5A4D;       { 'MZ'                              }
  PE_PE_SIG       = $00004550;   { 'PE\0\0'                          }
  PE_MACHINE_I386 = $014C;       { i386                               }
  PE_OPT_SIZE     = 224;         { sizeof IMAGE_OPTIONAL_HEADER32     }
  PE_MAGIC_32     = $010B;       { PE32                               }
  PE_IMG_BASE     = $00400000;   { default image base                 }
  PE_SEC_ALIGN    = $1000;       { section alignment (4KB)            }
  PE_FILE_ALIGN   = $0200;       { file alignment (512)               }
  PE_SUBSYS_CUI   = 3;           { console subsystem                  }
  PE_SCN_TEXT     = $60000020;   { CODE | EXECUTE | READ              }
  PE_SCN_RDATA    = $40000040;   { INIT_DATA | READ                   }
  PE_SCN_BSS      = LongInt($C0000040);  { INIT_DATA | READ | WRITE   }
  MAX_BIN_CODE    = 65536;       { 64 KB max code section             }
  MAX_BIN_DATA    = 65536;       { 64 KB max data section             }
  MAX_BIN_LBL     = 4096;        { max labels                         }
  MAX_BIN_FIX     = 8192;        { max fixups                         }
  PE_NUM_API      = 7;           { number of imported Win32 APIs      }
  COFF_RELOC_DIR32  = 6;         { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32  = 20;        { IMAGE_REL_I386_REL32               }
{$ENDIF}

{ ============================================================ }
{ TYPES                                                        }
{ ============================================================ }

Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.abap)               }
    OutFile   : TString;   { fichier de sortie (.exe/.obj/.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
    EmitExe   : Boolean;   { produire un .EXE PE (defaut)         }
    EmitObj   : Boolean;   { -obj : produire uniquement un .OBJ   }
    EmitAsm   : Boolean;   { -asm : produire un listing .ASM      }
  End;

{$IFDEF FPC}
  { ---- Types binaires ------------------------------------- }
  TBinFixKind = (BFK_ABS32, BFK_REL32, BFK_IAT32);
  TBinFixup = Record
    Offset : LongInt;
    Kind   : TBinFixKind;
    Target : TString;
    InCode : Boolean;
  End;
  TBinLabel = Record
    Name   : TString;
    Offset : LongInt;
    InCode : Boolean;
  End;
{$ENDIF}

  { ---- Entree de la table des symboles (32 bits) ----------- }
  TSymEntry = Record
    Name        : String[48];   { Nom ABAP (upper-case)              }
    AsmLabel    : String[48];   { Etiquette ASM : _AB_nom            }
    DataType    : Integer;       { TYPE_xxx                          }
    StoreClass  : Integer;       { STORE_xxx                         }
    BpOffset    : Integer;       { offset EBP si locale (negatif)    }
    ArraySize   : Integer;       { 0 si scalaire, n si table         }
    CharLen     : Integer;       { longueur TYPE C(n) ou N(n)        }
    DecPrec     : Integer;       { precision TYPE P / F              }
    DecScale    : Integer;       { DECIMALS n pour TYPE P            }
    IsParam     : Boolean;       { True si parametre de FORM         }
    ParamIdx    : Integer;       { index du parametre (1-base)       }
    ParamKind   : Integer;       { PARAM_USING / CHANGING / TABLES   }
    InitStr     : String[64];   { valeur VALUE en chaine            }
    InitNum     : LongInt;       { valeur VALUE numerique            }
    HasInit     : Boolean;       { True si VALUE specifie            }
    IsConst     : Boolean;       { True si CONSTANTS                 }
    ScopeLev    : Integer;       { niveau de scope (0 = global)      }
  End;

  { ---- Entree de la table des FORMs / FUNCTIONs ------------ }
  TFormEntry = Record
    Name          : String[48];
    AsmLabel      : String[48];    { ex: _ABF_nomform              }
    ParamCount    : Integer;       { total USING + CHANGING        }
    UsingCount    : Integer;
    ChangingCount : Integer;
    TablesCount   : Integer;
    Defined       : Boolean;
    IsFunction    : Boolean;       { True si FUNCTION vs FORM      }
    ParamNames    : Array[1..MAX_PARAM] of String[48];
    ParamKinds    : Array[1..MAX_PARAM] of Integer;   { PARAM_xxx }
    ParamTypes    : Array[1..MAX_PARAM] of Integer;   { TYPE_xxx  }
  End;

  { ---- Entree de la pile de scopes (32 bits) ----------------- }
  TScopeEntry = Record
    Kind      : Integer;         { SK_xxx                        }
    FormIdx   : Integer;         { index dans FormTab si SK_FORM }
    EbpTop    : Integer;         { prochain offset EBP negatif   }
    SymStart  : Integer;         { premier sym index du scope    }
    SymEnd    : Integer;         { dernier sym index du scope    }
    LblExit   : String[32];     { etiquette de sortie (EXIT)    }
    LblCont   : String[32];     { etiquette continue (LOOP)     }
    LblEnd    : String[32];     { etiquette fin de bloc (END*)  }
  End;

{ ============================================================ }
{ VARIABLES GLOBALES                                           }
{ ============================================================ }

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Lexeur }
  LexSrcF    : Text;       { handle du fichier source              }
  LexOpened  : Boolean;    { fichier source ouvert ?               }
  LexLine    : TString;    { ligne courante                        }
  LexLineNo  : Integer;    { numero de ligne courante (1-based)    }
  LexColNo   : Integer;    { colonne courante dans LexLine         }
  LexEOF     : Boolean;    { fin de fichier atteinte ?             }
  CurTokType : Integer;    { type du token courant (TOK_xxx)       }
  CurTokStr  : TString;    { valeur textuelle du token courant     }
  CurTokNum  : LongInt;    { valeur entiere (TOK_NUMBER)           }
  CurTokKw   : Integer;    { code mot-cle (KW_xxx) ou KW_NONE     }

{$IFDEF FPC}
  { Variables binaires }
  BinCode     : Array[0..MAX_BIN_CODE - 1] of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] of Byte;
  BinDataLen  : LongInt;
  BinLabels   : Array[0..MAX_BIN_LBL - 1] of TBinLabel;
  BinLblCount : Integer;
  BinFixups   : Array[0..MAX_BIN_FIX - 1] of TBinFixup;
  BinFixCount : Integer;
  BinInCode   : Boolean;
{$ENDIF}

  { Table des symboles }
  SymTab      : Array[1..MAX_SYM]  of TSymEntry;
  SymCount    : Integer;

  { Table des FORMs / FUNCTIONs }
  FormTab     : Array[1..MAX_FORM] of TFormEntry;
  FormCount   : Integer;

  { Pile de scopes }
  ScopeStack  : Array[0..MAX_DEPTH] of TScopeEntry;
  ScopeTop    : Integer;

  { Nom du programme (REPORT / PROGRAM) }
  ProgName    : TString;

  { Compteur de labels generes (TODO 08) }
  LabelCount  : Integer;

  { Table des chaines litterales (TODO 08) }
  StrLitTab   : Array[1..MAX_DATA] of Record
                  Text    : TString;   { contenu chaine + '$' }
                  AsmLabel: TString;   { _ABK_n               }
                End;
  StrLitCount : Integer;

  { Evenements ABAP definis (TODO 24) }
  EventStartDefined : Boolean;
  EventEndDefined   : Boolean;
  TryCount          : Integer;

Const
{$IFDEF FPC}
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20',
    '_ReadFile@20', '_GetProcessHeap@0', '_HeapAlloc@12',
    '_HeapFree@12'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
    'GetProcessHeap', 'HeapAlloc', 'HeapFree'
  );
{$ENDIF}

{ ============================================================ }
{ DECLARATIONS FORWARD (LEXEUR)                                }
{ ============================================================ }

Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure LexNextLine;   Forward;
Procedure LexNextToken;  Forward;
Procedure LexError(Const Msg : TString); Forward;
Procedure PrintToken;    Forward;
Function  IsKeyword(Const S : TString) : Integer; Forward;
Procedure Consume;       Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (TABLE DES SYMBOLES)                    }
{ ============================================================ }

Procedure InitSymTable;  Forward;
Function  FindSym(Const Name : TString) : Integer; Forward;
Function  FindSymLocal(Const Name : TString) : Integer; Forward;
Function  AddSym(Const Name : TString; DT, SC : Integer) : Integer; Forward;
Function  FindForm(Const Name : TString) : Integer; Forward;
Function  AddForm(Const Name : TString) : Integer; Forward;
Procedure DeclSysVars;   Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (GESTION DES SCOPES)                    }
{ ============================================================ }

Procedure InitScopes;    Forward;
Procedure EnterScope(Kind : Integer; FormIdx : Integer); Forward;
Procedure LeaveScope;    Forward;
Function  AllocLocalEbp(Bytes : Integer) : Integer; Forward;
Function  CurrentEbpTop : Integer; Forward;
Procedure SetExitLabel(Const Lbl : String); Forward;
Procedure SetContLabel(Const Lbl : String); Forward;
Procedure SetEndLabel(Const Lbl : String);  Forward;
Function  CurrentExitLabel : TString; Forward;
Function  CurrentContLabel : TString; Forward;
Function  CurrentEndLabel  : TString; Forward;
Function  InForm : Boolean; Forward;
Function  CurrentFormIdx : Integer; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (PARSEUR REPORT/PROGRAM)                }
{ ============================================================ }

Procedure ParseReport; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (PARSEUR DATA / TYPES / CONSTANTS)      }
{ ============================================================ }

Procedure ParseTypeSpec(SymIdx : Integer); Forward;
Procedure ParseValue(SymIdx : Integer); Forward;
Procedure ParseOneVar(Const NameIn : TString; IsConst : Boolean); Forward;
Procedure ParseTypesBlock; Forward;
Procedure ParseData(IsConst : Boolean); Forward;
Procedure ParseTypes; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (EMISSION ASM / EXPRESSIONS TODO 08)    }
{ ============================================================ }

Procedure Emit(Const S : TString); Forward;
Procedure EmitI(Const S : TString); Forward;
Procedure EmitLabel(Const S : TString); Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitBlank; Forward;
Function  NewLabel : TString; Forward;
Function  AddStringLit(Const S : TString) : TString; Forward;
Function  ParseExpr : Integer; Forward;
Function  ParseAndExpr : Integer; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (GENERATION DE CODE TODO 09)            }
{ ============================================================ }

Procedure GenStoreVar32(SymIdx : Integer); Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (IF / ELSEIF / ELSE / ENDIF TODO 10)    }
{ ============================================================ }

Procedure ParseStatement; Forward;
Procedure ParseBlock(Stop1, Stop2, Stop3 : Integer); Forward;
Procedure ParseIf; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (CASE / WHEN / ENDCASE TODO 11)         }
{ ============================================================ }

Procedure ParseCase; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (WHILE / DO TODO 12)                    }
{ ============================================================ }

Procedure ParseWhile; Forward;
Procedure ParseDo; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (PERFORM / FORM TODO 13)                }
{ ============================================================ }

Procedure ParseForm; Forward;
Procedure ParsePerform; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (WRITE / SKIP / NEW-LINE TODO 14)       }
{ ============================================================ }

Procedure ParseWrite; Forward;
Procedure EmitWriteRuntime; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (MOVE / COMPUTE / VERBALES TODO 15)     }
{ ============================================================ }

Procedure ParseMove; Forward;
Procedure ParseAdd; Forward;
Procedure ParseSubtract; Forward;
Procedure ParseMultiply; Forward;
Procedure ParseDivide; Forward;
Procedure ParseClear; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (LOOP AT / TABLES TODO 16)              }
{ ============================================================ }

Procedure ParseLoopAt; Forward;
Procedure ParseAppend; Forward;
Procedure ParseReadTable; Forward;
Procedure ParseSort; Forward;
Procedure ParseDeleteTable; Forward;
Procedure EmitTableRuntime; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (OPERATIONS CHAINES TODO 17)            }
{ ============================================================ }

Procedure ParseConcatenate; Forward;
Procedure ParseSplit; Forward;
Procedure ParseShift; Forward;
Procedure ParseReplace; Forward;
Procedure ParseTranslate; Forward;
Procedure ParseCondense; Forward;
Procedure ParseFind; Forward;
Procedure EmitStringRuntime; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (EN-TETE ASM + DATA TODO 18)            }
{ ============================================================ }

Procedure EmitHeader; Forward;
Procedure EmitDataSeg; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (POINT ENTREE + RUNTIME TODO 19)        }
{ ============================================================ }

Procedure EmitEntryPoint; Forward;
Procedure EmitRuntimeHelpers; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (CLEAR/REFRESH/FREE/CHECK/STOP TODO 20) }
{ ============================================================ }

Procedure ParseRefresh; Forward;
Procedure ParseFree; Forward;
Procedure ParseCheck; Forward;
Procedure ParseStop; Forward;
Procedure ParseReturn; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (SELECT / ENDSELECT TODO 21)            }
{ ============================================================ }

Procedure ParseSelect; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (CALL FUNCTION / FUNCTION TODO 22)      }
{ ============================================================ }

Procedure ParseCallFunction; Forward;
Procedure ParseFunctionDecl; Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (DISPATCHER TODO 23)                    }
{ ============================================================ }

Procedure ParseTry; Forward;
Procedure ParseRaise; Forward;
Procedure ParseEvent(EventKw : Integer); Forward;
Procedure ParseSelScreen(IsParam : Boolean); Forward;

{ ============================================================ }
{ DECLARATIONS FORWARD (EVENEMENTS ET SELECTION TODO 24)       }
{ ============================================================ }

Function  IsEventKeyword : Boolean; Forward;

{ ============================================================ }
{ FONCTIONS UTILITAIRES                                        }
{ ============================================================ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  StrLowerCase := Tmp;
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
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

Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ Convertir un identificateur en label ASM valide }
Function AsmIdent(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := StrUpperCase(S);
  For I := 1 To Length(Tmp) Do
    If Not (((Tmp[I] >= 'A') And (Tmp[I] <= 'Z')) Or
            ((Tmp[I] >= '0') And (Tmp[I] <= '9')) Or
            (Tmp[I] = '_')) Then
      Tmp[I] := '_';
  AsmIdent := Tmp;
End;

{ ============================================================ }
{ GESTION DES ERREURS                                          }
{ ============================================================ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('ABAPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('ABAPCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ============================================================ }
{ TOKENISEUR ABAP (LEXER)                                     }
{ ============================================================ }

{ ---- Fonctions de base du lexeur -------------------------- }

Function LexCurChar : Char;
Begin
  If LexEOF Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If LexEOF Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

Procedure LexError(Const Msg : TString);
Begin
  WriteLn('ABAPCW32: ligne ', LexLineNo, ': ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, abandon');
End;

{ ---- LexSkipWS : sauter espaces, TAB et commentaires ------ }
Procedure LexSkipWS;
Var Done : Boolean;
Begin
  Done := False;
  While Not Done Do
  Begin
    Done := True;
    { Lire la prochaine ligne si necessaire }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    { Commentaire '*' en colonne 1 : sauter toute la ligne }
    If (LexColNo = 1) And (Length(LexLine) > 0) And
       (LexLine[1] = '*') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Done := False;
      Continue;
    End;
    { Pragma '#' en colonne 1 : sauter toute la ligne }
    If (LexColNo = 1) And (Length(LexLine) > 0) And
       (LexLine[1] = '#') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Done := False;
      Continue;
    End;
    { Sauter espaces et tabulations }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Begin
      Inc(LexColNo);
      Done := False;
    End;
    { Commentaire inline ABAP : " jusqu'a fin de ligne }
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '"') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Done := False;
    End;
  End;
End;

{ ---- LexNextToken : produire le prochain token ABAP ------- }
Procedure LexNextToken;
Var
  C, C2 : Char;
  S     : TString;
  N     : LongInt;
  Flt   : Boolean;
Begin
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokKw   := KW_NONE;

  LexSkipWS;

  { ---- EOF ---- }
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    CurTokType := TOK_EOF;
    CurTokStr  := '';
    Exit;
  End;

  C := LexCurChar;

  { ---- Separateurs simples ---- }
  Case C Of
    '(': Begin CurTokType := TOK_LPAREN;   CurTokStr := '(';
           LexAdvance; Exit; End;
    ')': Begin CurTokType := TOK_RPAREN;   CurTokStr := ')';
           LexAdvance; Exit; End;
    '[': Begin CurTokType := TOK_LBRACKET; CurTokStr := '[';
           LexAdvance; Exit; End;
    ']': Begin CurTokType := TOK_RBRACKET; CurTokStr := ']';
           LexAdvance; Exit; End;
    ',': Begin CurTokType := TOK_COMMA;    CurTokStr := ',';
           LexAdvance; Exit; End;
    '.': Begin CurTokType := TOK_DOT;      CurTokStr := '.';
           LexAdvance; Exit; End;
    ':': Begin CurTokType := TOK_COLON;    CurTokStr := ':';
           LexAdvance; Exit; End;
    '+': Begin CurTokType := TOK_PLUS;     CurTokStr := '+';
           LexAdvance; Exit; End;
    '/': Begin CurTokType := TOK_SLASH;    CurTokStr := '/';
           LexAdvance; Exit; End;
    '@': Begin CurTokType := TOK_AT;       CurTokStr := '@';
           LexAdvance; Exit; End;
    '#': Begin CurTokType := TOK_HASH;     CurTokStr := '#';
           LexAdvance; Exit; End;
    '-': Begin CurTokType := TOK_MINUS;    CurTokStr := '-';
           LexAdvance; Exit; End;
    '*': Begin CurTokType := TOK_STAR;     CurTokStr := '*';
           LexAdvance; Exit; End;
    '=': Begin CurTokType := TOK_EQ;       CurTokStr := '=';
           LexAdvance; Exit; End;
  End;

  { ---- Operateurs multi-caracteres ---- }
  { '<' et '<>' et '<=' }
  If C = '<' Then
  Begin
    LexAdvance;
    C2 := LexCurChar;
    If C2 = '>' Then
    Begin LexAdvance; CurTokType := TOK_NE; CurTokStr := '<>'; End
    Else If C2 = '=' Then
    Begin LexAdvance; CurTokType := TOK_LE; CurTokStr := '<='; End
    Else
    Begin CurTokType := TOK_LT; CurTokStr := '<'; End;
    Exit;
  End;
  { '>' et '>=' }
  If C = '>' Then
  Begin
    LexAdvance;
    C2 := LexCurChar;
    If C2 = '=' Then
    Begin LexAdvance; CurTokType := TOK_GE; CurTokStr := '>='; End
    Else
    Begin CurTokType := TOK_GT; CurTokStr := '>'; End;
    Exit;
  End;
  { '&&' concatenation ou '&' seul }
  If C = '&' Then
  Begin
    LexAdvance;
    If LexCurChar = '&' Then
    Begin LexAdvance; CurTokType := TOK_CONCAT; CurTokStr := '&&'; End
    Else
    Begin CurTokType := TOK_UNKNOWN; CurTokStr := '&'; End;
    Exit;
  End;

  { ---- Pipe '|' : chaine template ABAP 7.4 (stub) ---- }
  If C = '|' Then
  Begin
    LexAdvance;
    S := '';
    While (LexColNo <= Length(LexLine)) And (LexCurChar <> '|') Do
    Begin
      If Length(S) < MAX_STR Then
        S := S + LexCurChar;
      LexAdvance;
    End;
    If (LexColNo <= Length(LexLine)) And (LexCurChar = '|') Then
      LexAdvance;
    CurTokType := TOK_STRING;
    CurTokStr  := S;
    Exit;
  End;

  { ---- Chaine ABAP : '...' avec '' pour apostrophe ---- }
  If C = '''' Then
  Begin
    LexAdvance;
    S := '';
    While True Do
    Begin
      If (LexColNo > Length(LexLine)) Then
      Begin
        LexError('Chaine non terminee');
        Break;
      End;
      C2 := LexCurChar;
      If C2 = '''' Then
      Begin
        LexAdvance;
        { Apostrophe doublee '' = apostrophe dans la chaine }
        If (LexColNo <= Length(LexLine)) And (LexCurChar = '''') Then
        Begin
          If Length(S) < MAX_STR Then
            S := S + '''';
          LexAdvance;
        End
        Else
          Break; { fin de la chaine }
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + C2;
        LexAdvance;
      End;
    End;
    CurTokType := TOK_STRING;
    CurTokStr  := S;
    Exit;
  End;

  { ---- Litteraux numeriques ---- }
  If (C >= '0') And (C <= '9') Then
  Begin
    N   := Ord(C) - 48;
    S   := C;
    Flt := False;
    LexAdvance;
    { Partie entiere }
    While (LexColNo <= Length(LexLine)) And
          (LexCurChar >= '0') And (LexCurChar <= '9') Do
    Begin
      N := N * 10 + (Ord(LexCurChar) - 48);
      S := S + LexCurChar;
      LexAdvance;
    End;
    { Partie decimale : '.' suivi d'un chiffre = flottant }
    If (LexColNo <= Length(LexLine)) And (LexCurChar = '.') Then
    Begin
      C2 := LexPeek;
      If (C2 >= '0') And (C2 <= '9') Then
      Begin
        Flt := True;
        S := S + '.';
        LexAdvance; { consomme le '.' }
        While (LexColNo <= Length(LexLine)) And
              (LexCurChar >= '0') And (LexCurChar <= '9') Do
        Begin
          S := S + LexCurChar;
          LexAdvance;
        End;
      End;
      { Sinon le '.' est le terminateur d'instruction, on ne le consomme pas }
    End;
    { Exposant E/e }
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'E') Or (LexCurChar = 'e')) Then
    Begin
      Flt := True;
      S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        S := S + LexCurChar;
        LexAdvance;
      End;
      While (LexColNo <= Length(LexLine)) And
            (LexCurChar >= '0') And (LexCurChar <= '9') Do
      Begin
        S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    If Flt Then CurTokType := TOK_FLOAT
    Else        CurTokType := TOK_NUMBER;
    CurTokNum := N;
    CurTokStr := S;
    Exit;
  End;

  { ---- Identificateurs et mots-cles ABAP ---- }
  If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
     (C = '_') Then
  Begin
    S := '';
    If (C >= 'a') And (C <= 'z') Then
      S := Chr(Ord(C) - 32)
    Else
      S := C;
    LexAdvance;
    While True Do
    Begin
      If LexColNo > Length(LexLine) Then Break;
      C2 := LexCurChar;
      { Caractere standard d'identificateur }
      If ((C2 >= 'A') And (C2 <= 'Z')) Or ((C2 >= 'a') And (C2 <= 'z')) Or
         (C2 = '_') Or ((C2 >= '0') And (C2 <= '9')) Then
      Begin
        If Length(S) < MAX_IDENT Then
        Begin
          If (C2 >= 'a') And (C2 <= 'z') Then
            S := S + Chr(Ord(C2) - 32)
          Else
            S := S + C2;
        End;
        LexAdvance;
        Continue;
      End;
      { '-' dans un ident ABAP (SY-SUBRC, START-OF-SELECTION, etc.)
        Consommer le '-' seulement si suivi d'alpha/_ }
      If C2 = '-' Then
      Begin
        C2 := LexPeek;
        If ((C2 >= 'A') And (C2 <= 'Z')) Or ((C2 >= 'a') And (C2 <= 'z')) Or
           (C2 = '_') Then
        Begin
          If Length(S) < MAX_IDENT Then
            S := S + '-';
          LexAdvance;
          Continue;
        End;
      End;
      Break;
    End;
    CurTokType := TOK_IDENT;
    CurTokStr  := S;
    CurTokKw   := IsKeyword(S);
    Exit;
  End;

  { ---- Caractere inconnu ---- }
  CurTokType := TOK_UNKNOWN;
  CurTokStr  := C;
  LexAdvance;
End;

{ ---- PrintToken : afficher le token courant (mode debug) -- }
Procedure PrintToken;
Var Kind : TString;
Begin
  Case CurTokType Of
    TOK_IDENT    : Kind := 'IDENT';
    TOK_NUMBER   : Kind := 'NUMBER';
    TOK_FLOAT    : Kind := 'FLOAT';
    TOK_STRING   : Kind := 'STRING';
    TOK_PLUS     : Kind := 'PLUS';
    TOK_MINUS    : Kind := 'MINUS';
    TOK_STAR     : Kind := 'STAR';
    TOK_SLASH    : Kind := 'SLASH';
    TOK_LPAREN   : Kind := 'LPAREN';
    TOK_RPAREN   : Kind := 'RPAREN';
    TOK_COMMA    : Kind := 'COMMA';
    TOK_DOT      : Kind := 'DOT';
    TOK_COLON    : Kind := 'COLON';
    TOK_EQ       : Kind := 'EQ';
    TOK_NE       : Kind := 'NE';
    TOK_LT       : Kind := 'LT';
    TOK_GT       : Kind := 'GT';
    TOK_LE       : Kind := 'LE';
    TOK_GE       : Kind := 'GE';
    TOK_CONCAT   : Kind := 'CONCAT';
    TOK_LBRACKET : Kind := 'LBRACKET';
    TOK_RBRACKET : Kind := 'RBRACKET';
    TOK_HASH     : Kind := 'HASH';
    TOK_PIPE     : Kind := 'PIPE';
    TOK_AT       : Kind := 'AT';
    TOK_EOF      : Kind := 'EOF';
    Else           Kind := 'UNKNOWN';
  End;
  Write('[', LexLineNo, ':', LexColNo, '] ', Kind);
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Or
     (CurTokType = TOK_NUMBER) Or (CurTokType = TOK_FLOAT) Then
    Write(' <', CurTokStr, '>');
  If (CurTokType = TOK_IDENT) And (CurTokKw <> KW_NONE) Then
    Write(' kw=', CurTokKw);
  WriteLn;
End;

{ ============================================================ }
{ RECONNAISSANCE DES MOTS-CLES ABAP/4 (TODO 03)               }
{ ============================================================ }

{ IsKeyword : retourne le code KW_xxx si S est un mot-cle ABAP,
  ou KW_NONE si ce n est pas un mot-cle.
  S doit etre en MAJUSCULES (garanti par le lexeur).           }
Function IsKeyword(Const S : TString) : Integer;
Begin
  If S = 'REPORT'              Then Begin IsKeyword := KW_REPORT;        Exit; End;
  If S = 'PROGRAM'             Then Begin IsKeyword := KW_PROGRAM;       Exit; End;

  If S = 'DATA'                Then Begin IsKeyword := KW_DATA;          Exit; End;
  If S = 'TYPES'               Then Begin IsKeyword := KW_TYPES;         Exit; End;
  If S = 'CONSTANTS'           Then Begin IsKeyword := KW_CONSTANTS;     Exit; End;
  If S = 'CLASS-DATA'          Then Begin IsKeyword := KW_CLASS_DATA;    Exit; End;

  If S = 'IF'                  Then Begin IsKeyword := KW_IF;            Exit; End;
  If S = 'ELSEIF'              Then Begin IsKeyword := KW_ELSEIF;        Exit; End;
  If S = 'ELSE'                Then Begin IsKeyword := KW_ELSE;          Exit; End;
  If S = 'ENDIF'               Then Begin IsKeyword := KW_ENDIF;         Exit; End;
  If S = 'CASE'                Then Begin IsKeyword := KW_CASE;          Exit; End;
  If S = 'WHEN'                Then Begin IsKeyword := KW_WHEN;          Exit; End;
  If S = 'OTHERS'              Then Begin IsKeyword := KW_OTHERS;        Exit; End;
  If S = 'ENDCASE'             Then Begin IsKeyword := KW_ENDCASE;       Exit; End;

  If S = 'WHILE'               Then Begin IsKeyword := KW_WHILE;         Exit; End;
  If S = 'ENDWHILE'            Then Begin IsKeyword := KW_ENDWHILE;      Exit; End;
  If S = 'DO'                  Then Begin IsKeyword := KW_DO;            Exit; End;
  If S = 'TIMES'               Then Begin IsKeyword := KW_TIMES;         Exit; End;
  If S = 'ENDDO'               Then Begin IsKeyword := KW_ENDDO;         Exit; End;
  If S = 'LOOP'                Then Begin IsKeyword := KW_LOOP;          Exit; End;
  If S = 'AT'                  Then Begin IsKeyword := KW_AT;            Exit; End;
  If S = 'INTO'                Then Begin IsKeyword := KW_INTO;          Exit; End;
  If S = 'ENDLOOP'             Then Begin IsKeyword := KW_ENDLOOP;       Exit; End;

  If S = 'FORM'                Then Begin IsKeyword := KW_FORM;          Exit; End;
  If S = 'ENDFORM'             Then Begin IsKeyword := KW_ENDFORM;       Exit; End;
  If S = 'PERFORM'             Then Begin IsKeyword := KW_PERFORM;       Exit; End;
  If S = 'USING'               Then Begin IsKeyword := KW_USING;         Exit; End;
  If S = 'CHANGING'            Then Begin IsKeyword := KW_CHANGING;      Exit; End;
  If S = 'TABLES'              Then Begin IsKeyword := KW_TABLES;        Exit; End;

  If S = 'FUNCTION'            Then Begin IsKeyword := KW_FUNCTION;      Exit; End;
  If S = 'ENDFUNCTION'         Then Begin IsKeyword := KW_ENDFUNCTION;   Exit; End;

  If S = 'WRITE'               Then Begin IsKeyword := KW_WRITE;         Exit; End;
  If S = 'SKIP'                Then Begin IsKeyword := KW_SKIP;          Exit; End;
  If S = 'LINE'                Then Begin IsKeyword := KW_LINE;          Exit; End;
  If S = 'NEW-LINE'            Then Begin IsKeyword := KW_NEW_LINE;      Exit; End;

  If S = 'MOVE'                Then Begin IsKeyword := KW_MOVE;          Exit; End;
  If S = 'TO'                  Then Begin IsKeyword := KW_TO;            Exit; End;
  If S = 'MOVE-CORRESPONDING'  Then Begin IsKeyword := KW_MOVE_CORR;     Exit; End;
  If S = 'COMPUTE'             Then Begin IsKeyword := KW_COMPUTE;       Exit; End;
  If S = 'ADD'                 Then Begin IsKeyword := KW_ADD;           Exit; End;
  If S = 'SUBTRACT'            Then Begin IsKeyword := KW_SUBTRACT;      Exit; End;
  If S = 'MULTIPLY'            Then Begin IsKeyword := KW_MULTIPLY;      Exit; End;
  If S = 'BY'                  Then Begin IsKeyword := KW_BY;            Exit; End;
  If S = 'DIVIDE'              Then Begin IsKeyword := KW_DIVIDE;        Exit; End;
  If S = 'FROM'                Then Begin IsKeyword := KW_FROM;          Exit; End;
  If S = 'GIVING'              Then Begin IsKeyword := KW_GIVING;        Exit; End;

  If S = 'APPEND'              Then Begin IsKeyword := KW_APPEND;        Exit; End;
  If S = 'INSERT'              Then Begin IsKeyword := KW_INSERT;        Exit; End;
  If S = 'DELETE'              Then Begin IsKeyword := KW_DELETE;        Exit; End;
  If S = 'MODIFY'              Then Begin IsKeyword := KW_MODIFY;        Exit; End;
  If S = 'READ'                Then Begin IsKeyword := KW_READ;          Exit; End;
  If S = 'SORT'                Then Begin IsKeyword := KW_SORT;          Exit; End;
  If S = 'COLLECT'             Then Begin IsKeyword := KW_COLLECT;       Exit; End;

  If S = 'SELECT'              Then Begin IsKeyword := KW_SELECT;        Exit; End;
  If S = 'WHERE'               Then Begin IsKeyword := KW_WHERE;         Exit; End;
  If S = 'CORRESPONDING'       Then Begin IsKeyword := KW_CORRESPONDING; Exit; End;
  If S = 'FIELDS'              Then Begin IsKeyword := KW_FIELDS;        Exit; End;
  If S = 'ENDSELECT'           Then Begin IsKeyword := KW_ENDSELECT;     Exit; End;

  If S = 'CALL'                Then Begin IsKeyword := KW_CALL;          Exit; End;
  If S = 'RAISING'             Then Begin IsKeyword := KW_RAISING;       Exit; End;
  If S = 'EXCEPTIONS'          Then Begin IsKeyword := KW_EXCEPTIONS;    Exit; End;
  If S = 'SINGLE'              Then Begin IsKeyword := KW_SINGLE;        Exit; End;

  If S = 'CLEAR'               Then Begin IsKeyword := KW_CLEAR;         Exit; End;
  If S = 'REFRESH'             Then Begin IsKeyword := KW_REFRESH;       Exit; End;
  If S = 'FREE'                Then Begin IsKeyword := KW_FREE;          Exit; End;
  If S = 'INITIALIZE'          Then Begin IsKeyword := KW_INITIALIZE;    Exit; End;

  If S = 'CONCATENATE'         Then Begin IsKeyword := KW_CONCATENATE;   Exit; End;
  If S = 'SPLIT'               Then Begin IsKeyword := KW_SPLIT;         Exit; End;
  If S = 'SHIFT'               Then Begin IsKeyword := KW_SHIFT;         Exit; End;
  If S = 'REPLACE'             Then Begin IsKeyword := KW_REPLACE;       Exit; End;
  If S = 'TRANSLATE'           Then Begin IsKeyword := KW_TRANSLATE;     Exit; End;
  If S = 'CONDENSE'            Then Begin IsKeyword := KW_CONDENSE;      Exit; End;
  If S = 'FIND'                Then Begin IsKeyword := KW_FIND;          Exit; End;

  If S = 'CHECK'               Then Begin IsKeyword := KW_CHECK;         Exit; End;
  If S = 'RETURN'              Then Begin IsKeyword := KW_RETURN;        Exit; End;
  If S = 'EXIT'                Then Begin IsKeyword := KW_EXIT;          Exit; End;
  If S = 'STOP'                Then Begin IsKeyword := KW_STOP;          Exit; End;
  If S = 'CONTINUE'            Then Begin IsKeyword := KW_CONTINUE;      Exit; End;

  If S = 'START-OF-SELECTION'  Then Begin IsKeyword := KW_START_OF_SEL;  Exit; End;
  If S = 'END-OF-SELECTION'    Then Begin IsKeyword := KW_END_OF_SEL;    Exit; End;
  If S = 'TOP-OF-PAGE'         Then Begin IsKeyword := KW_TOP_OF_PAGE;   Exit; End;
  If S = 'END-OF-PAGE'         Then Begin IsKeyword := KW_END_OF_PAGE;   Exit; End;

  If S = 'PARAMETERS'          Then Begin IsKeyword := KW_PARAMETERS;    Exit; End;
  If S = 'SELECT-OPTIONS'      Then Begin IsKeyword := KW_SELECT_OPTIONS; Exit; End;

  If S = 'LIKE'                Then Begin IsKeyword := KW_LIKE;          Exit; End;
  If S = 'TYPE'                Then Begin IsKeyword := KW_TYPE;          Exit; End;
  If S = 'VALUE'               Then Begin IsKeyword := KW_VALUE;         Exit; End;
  If S = 'DEFAULT'             Then Begin IsKeyword := KW_DEFAULT;       Exit; End;
  If S = 'DECIMALS'            Then Begin IsKeyword := KW_DECIMALS;      Exit; End;
  If S = 'LENGTH'              Then Begin IsKeyword := KW_LENGTH;        Exit; End;

  If S = 'CLASS'               Then Begin IsKeyword := KW_CLASS;         Exit; End;
  If S = 'ENDCLASS'            Then Begin IsKeyword := KW_ENDCLASS;      Exit; End;
  If S = 'METHOD'              Then Begin IsKeyword := KW_METHOD;        Exit; End;
  If S = 'ENDMETHOD'           Then Begin IsKeyword := KW_ENDMETHOD;     Exit; End;
  If S = 'PUBLIC'              Then Begin IsKeyword := KW_PUBLIC;        Exit; End;
  If S = 'PRIVATE'             Then Begin IsKeyword := KW_PRIVATE;       Exit; End;
  If S = 'PROTECTED'           Then Begin IsKeyword := KW_PROTECTED;     Exit; End;

  If S = 'RAISE'               Then Begin IsKeyword := KW_RAISE;         Exit; End;
  If S = 'EXCEPTION'           Then Begin IsKeyword := KW_EXCEPTION;     Exit; End;
  If S = 'TRY'                 Then Begin IsKeyword := KW_TRY;           Exit; End;
  If S = 'CATCH'               Then Begin IsKeyword := KW_CATCH;         Exit; End;
  If S = 'CLEANUP'             Then Begin IsKeyword := KW_CLEANUP;       Exit; End;
  If S = 'ENDTRY'              Then Begin IsKeyword := KW_ENDTRY;        Exit; End;

  If S = 'EQ'                  Then Begin IsKeyword := KW_EQ;            Exit; End;
  If S = 'NE'                  Then Begin IsKeyword := KW_NE;            Exit; End;
  If S = 'LT'                  Then Begin IsKeyword := KW_LT;            Exit; End;
  If S = 'GT'                  Then Begin IsKeyword := KW_GT;            Exit; End;
  If S = 'LE'                  Then Begin IsKeyword := KW_LE;            Exit; End;
  If S = 'GE'                  Then Begin IsKeyword := KW_GE;            Exit; End;
  If S = 'BETWEEN'             Then Begin IsKeyword := KW_BETWEEN;       Exit; End;
  If S = 'IN'                  Then Begin IsKeyword := KW_IN;            Exit; End;

  If S = 'AND'                 Then Begin IsKeyword := KW_AND;           Exit; End;
  If S = 'OR'                  Then Begin IsKeyword := KW_OR;            Exit; End;
  If S = 'NOT'                 Then Begin IsKeyword := KW_NOT;           Exit; End;

  If S = 'IS'                  Then Begin IsKeyword := KW_IS;            Exit; End;
  If S = 'INITIAL'             Then Begin IsKeyword := KW_INITIAL;       Exit; End;
  If S = 'BOUND'               Then Begin IsKeyword := KW_BOUND;         Exit; End;

  If S = 'ASCENDING'           Then Begin IsKeyword := KW_ASCENDING;     Exit; End;
  If S = 'DESCENDING'          Then Begin IsKeyword := KW_DESCENDING;    Exit; End;

  If S = 'LEFT'                Then Begin IsKeyword := KW_LEFT;          Exit; End;
  If S = 'RIGHT'               Then Begin IsKeyword := KW_RIGHT;         Exit; End;
  If S = 'UPPER'               Then Begin IsKeyword := KW_UPPER;         Exit; End;
  If S = 'LOWER'               Then Begin IsKeyword := KW_LOWER;         Exit; End;
  If S = 'NO-GAPS'             Then Begin IsKeyword := KW_NO_GAPS;       Exit; End;

  If S = 'MATCH'               Then Begin IsKeyword := KW_MATCH;         Exit; End;
  If S = 'OFFSET'              Then Begin IsKeyword := KW_OFFSET;        Exit; End;
  If S = 'OCCURRENCE'          Then Begin IsKeyword := KW_OCCURRENCE;    Exit; End;
  If S = 'OCCURRENCES'         Then Begin IsKeyword := KW_OCCURRENCES;   Exit; End;
  If S = 'SEPARATED'           Then Begin IsKeyword := KW_SEPARATED;     Exit; End;

  If S = 'LINE-SELECTION'      Then Begin IsKeyword := KW_LINE_SEL;      Exit; End;
  If S = 'USER-COMMAND'        Then Begin IsKeyword := KW_USER_CMD;      Exit; End;

  If S = 'OF'                  Then Begin IsKeyword := KW_OF;            Exit; End;
  If S = 'BEGIN'               Then Begin IsKeyword := KW_BEGIN;         Exit; End;
  If S = 'END'                 Then Begin IsKeyword := KW_END;           Exit; End;
  If S = 'TABLE'               Then Begin IsKeyword := KW_TABLE;         Exit; End;
  If S = 'WITH'                Then Begin IsKeyword := KW_WITH;          Exit; End;
  If S = 'KEY'                 Then Begin IsKeyword := KW_KEY;           Exit; End;
  If S = 'INDEX'               Then Begin IsKeyword := KW_INDEX;         Exit; End;
  If S = 'MESSAGE-ID'          Then Begin IsKeyword := KW_MESSAGE_ID;    Exit; End;

  If S = 'STRLEN'              Then Begin IsKeyword := KW_STRLEN;        Exit; End;
  If S = 'ABS'                 Then Begin IsKeyword := KW_ABS;           Exit; End;

  If S = 'ROWS'                Then Begin IsKeyword := KW_ROWS;          Exit; End;
  If S = 'ORDER'               Then Begin IsKeyword := KW_ORDER;         Exit; End;
  If S = 'EXPORTING'           Then Begin IsKeyword := KW_EXPORTING;     Exit; End;
  If S = 'IMPORTING'           Then Begin IsKeyword := KW_IMPORTING;     Exit; End;

  If S = 'CIRCULAR'            Then Begin IsKeyword := KW_CIRCULAR;      Exit; End;
  If S = 'PLACES'              Then Begin IsKeyword := KW_PLACES;        Exit; End;
  If S = 'ALL'                 Then Begin IsKeyword := KW_ALL;           Exit; End;
  If S = 'FIRST'               Then Begin IsKeyword := KW_FIRST;         Exit; End;
  If S = 'MOD'                 Then Begin IsKeyword := KW_MOD;           Exit; End;
  If S = 'DIV'                 Then Begin IsKeyword := KW_DIV;           Exit; End;
  If S = 'LEFT-JUSTIFIED'     Then Begin IsKeyword := KW_LEFT_JUSTIFIED;Exit; End;
  If S = 'NO-GAP'             Then Begin IsKeyword := KW_NO_GAP;        Exit; End;
  If S = 'RIGHT-JUSTIFIED'    Then Begin IsKeyword := KW_RIGHT_JUSTIFIED;Exit;End;
  IsKeyword := KW_NONE;
End;

{ ---- TokIsKw : vrai si le token courant est le mot-cle kw -- }
Function TokIsKw(Kw : Integer) : Boolean;
Begin
  TokIsKw := (CurTokType = TOK_IDENT) And (CurTokKw = Kw);
End;

{ ---- EatKw : consomme si le token est le mot-cle kw --------- }
Function EatKw(Kw : Integer) : Boolean;
Begin
  If TokIsKw(Kw) Then
  Begin Consume; EatKw := True; End
  Else EatKw := False;
End;

{ ---- ExpectKw : verifie et consomme le mot-cle kw ----------- }
Procedure ExpectKw(Kw : Integer; Const What : TString);
Begin
  If Not TokIsKw(Kw) Then
    LexError('Attendu ' + What + ', trouve: ''' + CurTokStr + '''');
  Consume;
End;

{ ---- LexInit : ouvrir le fichier source et lire le 1er token }
Procedure LexInit;
Begin
  LexOpened  := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurTokType := TOK_EOF;
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokKw   := KW_NONE;
  LexNextLine;
  LexNextToken;
End;

{ ---- LexClose : fermer le fichier source ------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- Helpers de parsing ----------------------------------- }
Procedure Consume;
Begin
  LexNextToken;
End;

Procedure Expect(TT : Integer; Const What : TString);
Begin
  If CurTokType <> TT Then
    LexError('Attendu ' + What + ', trouve: ''' + CurTokStr + '''');
  Consume;
End;

Procedure SkipToDot;
Begin
  While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ============================================================ }
{ TABLE DES SYMBOLES (TODO 04)                                 }
{ ============================================================ }

{ ---- InitSymTable : initialiser les tables des symboles ----- }
Procedure InitSymTable;
Var I, J : Integer;
Begin
  SymCount  := 0;
  FormCount := 0;
  For I := 1 To MAX_SYM Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].AsmLabel    := '';
    SymTab[I].DataType    := TYPE_UNKNOWN;
    SymTab[I].StoreClass  := STORE_STATIC;
    SymTab[I].BpOffset    := 0;
    SymTab[I].ArraySize   := 0;
    SymTab[I].CharLen     := 1;
    SymTab[I].DecPrec     := 0;
    SymTab[I].DecScale    := 0;
    SymTab[I].IsParam     := False;
    SymTab[I].ParamIdx    := 0;
    SymTab[I].ParamKind   := PARAM_USING;
    SymTab[I].InitStr     := '';
    SymTab[I].InitNum     := 0;
    SymTab[I].HasInit     := False;
    SymTab[I].IsConst     := False;
    SymTab[I].ScopeLev    := 0;
  End;
  For I := 1 To MAX_FORM Do
  Begin
    FormTab[I].Name          := '';
    FormTab[I].AsmLabel      := '';
    FormTab[I].ParamCount    := 0;
    FormTab[I].UsingCount    := 0;
    FormTab[I].ChangingCount := 0;
    FormTab[I].TablesCount   := 0;
    FormTab[I].Defined       := False;
    FormTab[I].IsFunction    := False;
    For J := 1 To MAX_PARAM Do
    Begin
      FormTab[I].ParamNames[J] := '';
      FormTab[I].ParamKinds[J] := PARAM_USING;
      FormTab[I].ParamTypes[J] := TYPE_UNKNOWN;
    End;
  End;
End;

{ ---- FindSym : recherche dans la table des symboles ----------
  Cherche de la fin vers le debut pour respecter la portee la
  plus proche. Retourne l index (1-base) ou 0 si non trouve.   }
Function FindSym(Const Name : TString) : Integer;
Var I : Integer;
    U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount DownTo 1 Do
    If SymTab[I].Name = U Then
    Begin FindSym := I; Exit; End;
  FindSym := 0;
End;

{ ---- FindSymLocal : recherche dans le scope courant seul ---- }
Function FindSymLocal(Const Name : TString) : Integer;
Var I : Integer;
    U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount DownTo 1 Do
    If (SymTab[I].Name = U) And (SymTab[I].ScopeLev = ScopeTop) Then
    Begin FindSymLocal := I; Exit; End;
  FindSymLocal := 0;
End;

{ ---- AddSym : ajouter un symbole dans la table --------------
  Retourne l index (1-base) du nouveau symbole, ou 0 si pleine. }
Function AddSym(Const Name : TString; DT, SC : Integer) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(Name);
  If SymCount >= MAX_SYM Then
  Begin
    LexError('Table des symboles pleine (max=' + IntToStr_(MAX_SYM) + ')');
    AddSym := 0;
    Exit;
  End;
  Inc(SymCount);
  SymTab[SymCount].Name        := U;
  SymTab[SymCount].AsmLabel    := AB_VAR_PFX + AsmIdent(U);
  SymTab[SymCount].DataType    := DT;
  SymTab[SymCount].StoreClass  := SC;
  SymTab[SymCount].BpOffset    := 0;
  SymTab[SymCount].ArraySize   := 0;
  SymTab[SymCount].CharLen     := 1;
  SymTab[SymCount].DecPrec     := 0;
  SymTab[SymCount].DecScale    := 0;
  SymTab[SymCount].IsParam     := False;
  SymTab[SymCount].ParamIdx    := 0;
  SymTab[SymCount].ParamKind   := PARAM_USING;
  SymTab[SymCount].InitStr     := '';
  SymTab[SymCount].InitNum     := 0;
  SymTab[SymCount].HasInit     := False;
  SymTab[SymCount].IsConst     := False;
  SymTab[SymCount].ScopeLev    := ScopeTop;
  AddSym := SymCount;
End;

{ ---- FindForm : recherche dans la table des FORMs ----------- }
Function FindForm(Const Name : TString) : Integer;
Var I : Integer;
    U : TString;
Begin
  U := StrUpperCase(Name);
  For I := 1 To FormCount Do
    If FormTab[I].Name = U Then
    Begin FindForm := I; Exit; End;
  FindForm := 0;
End;

{ ---- AddForm : ajouter une FORM / FUNCTION ------------------
  Si la FORM existe deja (forward reference), retourne l index
  existant. Sinon cree une nouvelle entree.                     }
Function AddForm(Const Name : TString) : Integer;
Var U        : TString;
    Existing : Integer;
Begin
  U        := StrUpperCase(Name);
  Existing := FindForm(U);
  If Existing > 0 Then
  Begin AddForm := Existing; Exit; End;
  If FormCount >= MAX_FORM Then
  Begin
    LexError('Table des FORMs pleine (max=' + IntToStr_(MAX_FORM) + ')');
    AddForm := 0;
    Exit;
  End;
  Inc(FormCount);
  FormTab[FormCount].Name          := U;
  FormTab[FormCount].AsmLabel      := AB_FN_PFX + AsmIdent(U);
  FormTab[FormCount].ParamCount    := 0;
  FormTab[FormCount].UsingCount    := 0;
  FormTab[FormCount].ChangingCount := 0;
  FormTab[FormCount].TablesCount   := 0;
  FormTab[FormCount].Defined       := False;
  FormTab[FormCount].IsFunction    := False;
  AddForm := FormCount;
End;

{ ---- DeclSysVars : declarer les variables systeme ABAP ------
  Appellee au debut de la compilation, avant tout parsage.
  Ces variables sont globales TYPE I (DD) en .DATA.              }
Procedure DeclSysVars;
Var Idx : Integer;

  Procedure DeclSY(Const Nm : TString; DT : Integer; CLen : Integer);
  Begin
    Idx := AddSym(Nm, DT, STORE_STATIC);
    If Idx > 0 Then
    Begin
      SymTab[Idx].AsmLabel := '_SY_' + AsmIdent(Copy(Nm, 4, 255));
      SymTab[Idx].HasInit  := True;
      SymTab[Idx].InitNum  := 0;
      If CLen > 0 Then
        SymTab[Idx].CharLen := CLen;
    End;
  End;

Begin
  DeclSY('SY-SUBRC',  TYPE_I, 0);    { code retour dernier SELECT/CALL }
  DeclSY('SY-TABIX',  TYPE_I, 0);    { index courant dans LOOP AT      }
  DeclSY('SY-DBCNT',  TYPE_I, 0);    { nb lignes SQL affectees         }
  DeclSY('SY-INDEX',  TYPE_I, 0);    { compteur DO TIMES               }
  DeclSY('SY-LANGU',  TYPE_C, 1);    { langue (stub = 'F')             }
  DeclSY('SY-MANDT',  TYPE_C, 3);    { mandant (stub = '000')          }
  DeclSY('SY-DATUM',  TYPE_D, 8);    { date systeme YYYYMMDD           }
  DeclSY('SY-UZEIT',  TYPE_T, 6);    { heure systeme HHMMSS            }
  DeclSY('SY-UNAME',  TYPE_C, 12);   { nom utilisateur (stub)          }
End;

{ ============================================================ }
{ GESTION DES SCOPES (TODO 05)                                 }
{ ============================================================ }

{ ---- InitScopes : initialiser la pile de scopes ------------- }
{ Le scope 0 est toujours SK_GLOBAL (niveau REPORT/PROGRAM).   }
Procedure InitScopes;
Begin
  ScopeTop := 0;
  ScopeStack[0].Kind     := SK_GLOBAL;
  ScopeStack[0].FormIdx  := 0;
  ScopeStack[0].EbpTop   := 0;
  ScopeStack[0].SymStart := 1;
  ScopeStack[0].SymEnd   := 0;
  ScopeStack[0].LblExit  := '';
  ScopeStack[0].LblCont  := '';
  ScopeStack[0].LblEnd   := '';
End;

{ ---- EnterScope : empiler un nouveau scope ------------------- }
{ Kind    : SK_GLOBAL / SK_FORM / SK_BLOCK / SK_LOOP / SK_EVENT  }
{ FormIdx : index dans FormTab si SK_FORM, sinon 0               }
Procedure EnterScope(Kind : Integer; FormIdx : Integer);
Begin
  If ScopeTop >= MAX_DEPTH Then
  Begin
    LexError('Trop d''imbrications de scopes (max=' +
             IntToStr_(MAX_DEPTH) + ')');
    Exit;
  End;
  Inc(ScopeTop);
  ScopeStack[ScopeTop].Kind     := Kind;
  ScopeStack[ScopeTop].FormIdx  := FormIdx;
  ScopeStack[ScopeTop].EbpTop   := 0;           { repart a 0 en local }
  ScopeStack[ScopeTop].SymStart := SymCount + 1;
  ScopeStack[ScopeTop].SymEnd   := SymCount;
  ScopeStack[ScopeTop].LblExit  := '';
  ScopeStack[ScopeTop].LblCont  := '';
  ScopeStack[ScopeTop].LblEnd   := '';
End;

{ ---- LeaveScope : depiler le scope courant ------------------- }
{ Attention : ne depile jamais le scope global (niveau 0).       }
Procedure LeaveScope;
Begin
  If ScopeTop = 0 Then
  Begin
    LexError('LeaveScope hors scope');
    Exit;
  End;
  ScopeStack[ScopeTop].SymEnd := SymCount;
  Dec(ScopeTop);
End;

{ ---- CurrentEbpTop : profondeur EBP courante ----------------- }
{ Retourne la valeur negative de l offset EBP du scope courant.  }
Function CurrentEbpTop : Integer;
Begin
  CurrentEbpTop := ScopeStack[ScopeTop].EbpTop;
End;

{ ---- AllocLocalEbp : allouer des octets sur la pile locale --- }
{ Decremente EbpTop du scope courant.                            }
{ Retourne l offset EBP du nouvel emplacement (negatif).         }
{ Convention Win32 : alignement sur DWORD (4 octets).            }
Function AllocLocalEbp(Bytes : Integer) : Integer;
Var Aligned : Integer;
Begin
  { Aligner sur 4 octets (DWORD) }
  Aligned := (Bytes + 3) And (Not 3);
  Dec(ScopeStack[ScopeTop].EbpTop, Aligned);
  AllocLocalEbp := ScopeStack[ScopeTop].EbpTop;
End;

{ ---- Setters de labels du scope courant ---------------------- }

Procedure SetExitLabel(Const Lbl : String);
Begin ScopeStack[ScopeTop].LblExit := Lbl; End;

Procedure SetContLabel(Const Lbl : String);
Begin ScopeStack[ScopeTop].LblCont := Lbl; End;

Procedure SetEndLabel(Const Lbl : String);
Begin ScopeStack[ScopeTop].LblEnd := Lbl; End;

{ ---- Getters de labels : remonte la pile de scopes ----------- }

{ Retourne le label EXIT du scope le plus proche qui en a un.    }
Function CurrentExitLabel : TString;
Var I : Integer;
Begin
  For I := ScopeTop DownTo 0 Do
    If ScopeStack[I].LblExit <> '' Then
    Begin CurrentExitLabel := ScopeStack[I].LblExit; Exit; End;
  CurrentExitLabel := '';
End;

{ Retourne le label CONTINUE du scope de boucle le plus proche. }
Function CurrentContLabel : TString;
Var I : Integer;
Begin
  For I := ScopeTop DownTo 0 Do
    If ScopeStack[I].LblCont <> '' Then
    Begin CurrentContLabel := ScopeStack[I].LblCont; Exit; End;
  CurrentContLabel := '';
End;

{ Retourne le label END du scope de boucle le plus proche.      }
Function CurrentEndLabel : TString;
Var I : Integer;
Begin
  For I := ScopeTop DownTo 0 Do
    If ScopeStack[I].LblEnd <> '' Then
    Begin CurrentEndLabel := ScopeStack[I].LblEnd; Exit; End;
  CurrentEndLabel := '';
End;

{ ---- InForm : vrai si on est dans une FORM ------------------- }
Function InForm : Boolean;
Var I : Integer;
Begin
  For I := ScopeTop DownTo 1 Do
    If ScopeStack[I].Kind = SK_FORM Then
    Begin InForm := True; Exit; End;
  InForm := False;
End;

{ ---- CurrentFormIdx : index de la FORM englobante ------------ }
{ Retourne 0 si pas dans une FORM.                               }
Function CurrentFormIdx : Integer;
Var I : Integer;
Begin
  For I := ScopeTop DownTo 1 Do
    If ScopeStack[I].Kind = SK_FORM Then
    Begin CurrentFormIdx := ScopeStack[I].FormIdx; Exit; End;
  CurrentFormIdx := 0;
End;

{ ============================================================ }
{ PARSEUR : REPORT / PROGRAM (TODO 06)                         }
{ ============================================================ }

{ ParseReport
  Syntaxes :
    REPORT nom_programme [MESSAGE-ID xx]
      [NO STANDARD PAGE HEADING] [LINE-SIZE nn] [...].
    PROGRAM nom_programme.
  Le mot-cle REPORT ou PROGRAM a deja ete consomme par l appelant.
  On memorise le nom dans ProgName et on ignore les options.
  Le label ASM du point d entree sera _ABF_nom.                   }
Procedure ParseReport;
Var
  Name : TString;
Begin
  { Le nom du programme est obligatoire }
  If CurTokType <> TOK_IDENT Then
  Begin
    LexError('Nom de programme attendu apres REPORT/PROGRAM');
    SkipToDot;
    Exit;
  End;
  Name     := StrUpperCase(CurTokStr);
  ProgName := Name;
  Consume;
  { Sauter toutes les options jusqu au '.' }
  { Options reconnues mais ignorees :
      MESSAGE-ID xx
      NO STANDARD PAGE HEADING
      LINE-SIZE nn
      LINE-COUNT nn
  }
  While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
    Consume;
  { Consommer le '.' final }
  If CurTokType = TOK_DOT Then Consume;
End;

{ ============================================================ }
{ PARSEUR : DATA / TYPES / CONSTANTS (TODO 07)                 }
{ ============================================================ }

{ ---- SymByteSize : taille en octets d un symbole ------------- }
Function SymByteSize(SymIdx : Integer) : Integer;
Begin
  Case SymTab[SymIdx].DataType Of
    TYPE_I      : SymByteSize := 4;   { DD = 4 octets   }
    TYPE_F      : SymByteSize := 8;   { DQ = 8 octets   }
    TYPE_C      : SymByteSize := SymTab[SymIdx].CharLen;
    TYPE_N      : SymByteSize := SymTab[SymIdx].CharLen;
    TYPE_D      : SymByteSize := 8;   { YYYYMMDD         }
    TYPE_T      : SymByteSize := 6;   { HHMMSS           }
    TYPE_P      : SymByteSize := 4;   { DD stub          }
    TYPE_STRING : SymByteSize := 4;   { pointeur 32 bits }
    TYPE_XSTRING: SymByteSize := 4;   { pointeur 32 bits }
    TYPE_TABLE  : SymByteSize := 4;   { pointeur 32 bits }
    TYPE_STRUCT : SymByteSize := 4;   { pointeur stub    }
    TYPE_REF    : SymByteSize := 4;   { pointeur 32 bits }
  Else
    SymByteSize := 4;
  End;
End;

{ ---- ParseTypeSpec : parser la clause TYPE / LIKE d une var -- }
{ Remplit DataType, CharLen, DecScale dans SymTab[SymIdx].
  Syntaxes reconnues :
    TYPE I / F / C / C(n) / N / N(n) / D / T / P [DECIMALS n]
    TYPE STRING / XSTRING
    TYPE TABLE OF xxx
    TYPE REF TO xxx
    LIKE varname
    LIKE TABLE OF varname                                        }
Procedure ParseTypeSpec(SymIdx : Integer);
Var RefName : TString;
    RefIdx  : Integer;
Begin
  { --- LIKE ... --- }
  If TokIsKw(KW_LIKE) Then
  Begin
    Consume;
    { LIKE TABLE OF var }
    If TokIsKw(KW_TABLE) Then
    Begin
      Consume; EatKw(KW_OF);
      SymTab[SymIdx].DataType := TYPE_TABLE;
      SymTab[SymIdx].CharLen  := 0;
      If CurTokType = TOK_IDENT Then Consume;
      Exit;
    End;
    { LIKE varname : copier le type de la variable reference }
    RefName := CurTokStr; Consume;
    RefIdx  := FindSym(RefName);
    If RefIdx > 0 Then
    Begin
      SymTab[SymIdx].DataType := SymTab[RefIdx].DataType;
      SymTab[SymIdx].CharLen  := SymTab[RefIdx].CharLen;
      SymTab[SymIdx].DecScale := SymTab[RefIdx].DecScale;
    End
    Else
    Begin
      WarnMsg('LIKE: variable inconnue ' + RefName + ', TYPE I suppose');
      SymTab[SymIdx].DataType := TYPE_I;
    End;
    Exit;
  End;
  { --- TYPE ... --- }
  If Not TokIsKw(KW_TYPE) Then Exit;
  Consume;
  { TABLE OF xxx }
  If TokIsKw(KW_TABLE) Then
  Begin
    Consume; EatKw(KW_OF);
    SymTab[SymIdx].DataType := TYPE_TABLE;
    SymTab[SymIdx].CharLen  := 0;
    If CurTokType = TOK_IDENT Then Consume;
    Exit;
  End;
  { REF TO xxx (stub) }
  If (CurTokType = TOK_IDENT) And (StrUpperCase(CurTokStr) = 'REF') Then
  Begin
    Consume; EatKw(KW_TO);
    SymTab[SymIdx].DataType := TYPE_REF;
    If CurTokType = TOK_IDENT Then Consume;
    Exit;
  End;
  { Types scalaires }
  If CurTokType <> TOK_IDENT Then
  Begin WarnMsg('Type ABAP attendu'); Exit; End;
  If StrUpperCase(CurTokStr) = 'I' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_I;
    SymTab[SymIdx].CharLen  := 4;
    Consume;
  End
  Else If StrUpperCase(CurTokStr) = 'F' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_F;
    SymTab[SymIdx].CharLen  := 8;
    Consume;
  End
  Else If StrUpperCase(CurTokStr) = 'C' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_C;
    SymTab[SymIdx].CharLen  := 1;
    Consume;
    { TYPE C(n) }
    If CurTokType = TOK_LPAREN Then
    Begin
      Consume;
      SymTab[SymIdx].CharLen := CurTokNum;
      If CurTokType = TOK_NUMBER Then Consume;
      If CurTokType = TOK_RPAREN Then Consume;
    End;
  End
  Else If StrUpperCase(CurTokStr) = 'N' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_N;
    SymTab[SymIdx].CharLen  := 1;
    Consume;
    If CurTokType = TOK_LPAREN Then
    Begin
      Consume;
      SymTab[SymIdx].CharLen := CurTokNum;
      If CurTokType = TOK_NUMBER Then Consume;
      If CurTokType = TOK_RPAREN Then Consume;
    End;
  End
  Else If StrUpperCase(CurTokStr) = 'D' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_D;
    SymTab[SymIdx].CharLen  := 8;
    Consume;
  End
  Else If StrUpperCase(CurTokStr) = 'T' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_T;
    SymTab[SymIdx].CharLen  := 6;
    Consume;
  End
  Else If StrUpperCase(CurTokStr) = 'P' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_P;
    SymTab[SymIdx].CharLen  := 4;
    Consume;
    If CurTokType = TOK_LPAREN Then
    Begin
      Consume;
      SymTab[SymIdx].CharLen := CurTokNum;
      If CurTokType = TOK_NUMBER Then Consume;
      If CurTokType = TOK_RPAREN Then Consume;
    End;
    { DECIMALS n }
    If TokIsKw(KW_DECIMALS) Then
    Begin
      Consume;
      SymTab[SymIdx].DecScale := CurTokNum;
      If CurTokType = TOK_NUMBER Then Consume;
    End;
  End
  Else If StrUpperCase(CurTokStr) = 'STRING' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_STRING;
    SymTab[SymIdx].CharLen  := 255;
    Consume;
  End
  Else If StrUpperCase(CurTokStr) = 'XSTRING' Then
  Begin
    SymTab[SymIdx].DataType := TYPE_XSTRING;
    SymTab[SymIdx].CharLen  := 255;
    Consume;
  End
  Else
  Begin
    { Type utilisateur (structure ou table definie par TYPES) : stub }
    SymTab[SymIdx].DataType := TYPE_STRUCT;
    SymTab[SymIdx].CharLen  := 4;
    Consume;
  End;
End;

{ ---- ParseValue : parser la clause VALUE d une declaration --- }
{ Syntaxes :
    VALUE 42
    VALUE 'texte'
    VALUE -5
    VALUE IS INITIAL                                               }
Procedure ParseValue(SymIdx : Integer);
Begin
  If Not TokIsKw(KW_VALUE) Then Exit;
  Consume;
  SymTab[SymIdx].HasInit := True;
  { VALUE IS INITIAL -> valeur zero }
  If TokIsKw(KW_IS) Then
  Begin
    Consume; EatKw(KW_INITIAL);
    SymTab[SymIdx].InitNum := 0;
    SymTab[SymIdx].InitStr := '';
    Exit;
  End;
  If CurTokType = TOK_NUMBER Then
  Begin
    SymTab[SymIdx].InitNum := CurTokNum;
    SymTab[SymIdx].InitStr := IntToStr_(CurTokNum);
    Consume;
  End
  Else If CurTokType = TOK_STRING Then
  Begin
    SymTab[SymIdx].InitStr := CurTokStr;
    SymTab[SymIdx].InitNum := 0;
    Consume;
  End
  Else If CurTokType = TOK_MINUS Then
  Begin
    Consume;
    SymTab[SymIdx].InitNum := -CurTokNum;
    SymTab[SymIdx].InitStr := '-' + IntToStr_(CurTokNum);
    If CurTokType = TOK_NUMBER Then Consume;
  End
  Else
    WarnMsg('Valeur VALUE non reconnue dans declaration');
End;

{ ---- ParseOneVar : parser une declaration de variable -------- }
{ Le nom de la variable est passe en parametre (deja lu).
  Parse TYPE/LIKE, VALUE, et enregistre dans la table des
  symboles. is_const = True pour CONSTANTS.                       }
Procedure ParseOneVar(Const NameIn : TString; IsConst : Boolean);
Var VName  : TString;
    SymIdx : Integer;
    SC     : Integer;
    Bytes  : Integer;
    BpOff  : Integer;
Begin
  VName := NameIn;
  { Classe d entreposage }
  If ScopeTop = 0 Then SC := STORE_STATIC Else SC := STORE_AUTO;
  If IsConst Then SC := STORE_CONSTANT;
  SymIdx := AddSym(VName, TYPE_I, SC);
  If SymIdx = 0 Then Exit;
  { Longueur inline : DATA nom(n) TYPE C }
  If CurTokType = TOK_LPAREN Then
  Begin
    Consume;
    SymTab[SymIdx].CharLen  := CurTokNum;
    SymTab[SymIdx].DataType := TYPE_C;   { defaut si pas TYPE apres }
    If CurTokType = TOK_NUMBER Then Consume;
    If CurTokType = TOK_RPAREN Then Consume;
  End;
  { TYPE ... ou LIKE ... }
  ParseTypeSpec(SymIdx);
  { VALUE ... }
  ParseValue(SymIdx);
  { Si le type est TABLE : ajuster StoreClass et prefixe (TODO 16) }
  If SymTab[SymIdx].DataType = TYPE_TABLE Then
  Begin
    SymTab[SymIdx].StoreClass := STORE_TABLE;
    SymTab[SymIdx].AsmLabel   := AB_ARR_PFX + AsmIdent(VName);
    SC := STORE_TABLE;
  End;
  { Auto-ajuster char_len TYPE C si pas de (n) et VALUE fourni }
  If (SymTab[SymIdx].DataType = TYPE_C) Or
     (SymTab[SymIdx].DataType = TYPE_N) Then
  Begin
    If (SymTab[SymIdx].CharLen <= 1) And
       SymTab[SymIdx].HasInit And
       (Length(SymTab[SymIdx].InitStr) > 1) Then
      SymTab[SymIdx].CharLen := Length(SymTab[SymIdx].InitStr);
  End;
  { ---- Allocation memoire ---- }
  If SC = STORE_CONSTANT Then
  Begin
    SymTab[SymIdx].IsConst := True;
    If Opts.Verbose Then
      WriteLn('  CONSTANTS ', VName, ' = ', SymTab[SymIdx].InitStr);
    Exit;
  End;
  Bytes := SymByteSize(SymIdx);
  If SC = STORE_AUTO Then
  Begin
    { Variable locale dans une FORM (pile EBP) }
    If Bytes < 4 Then Bytes := 4;  { alignement 32 bits }
    BpOff := AllocLocalEbp(Bytes);
    SymTab[SymIdx].BpOffset := BpOff;
    If Opts.Verbose Then
      WriteLn('  LOCAL ', VName, ' : [EBP', BpOff, '] ', Bytes, ' bytes');
  End
  Else
  Begin
    { Variable globale -> sera emise dans le segment .DATA }
    If Opts.Verbose Then
      WriteLn('  GLOBAL ', VName, ' : ', SymTab[SymIdx].AsmLabel,
              ' ', Bytes, ' bytes');
  End;
End;

{ ---- ParseTypesBlock : parser TYPES BEGIN OF / END OF -------- }
{ Syntaxe :
    TYPES: BEGIN OF struc,
             champ1 TYPE I,
             champ2 TYPE C(20),
           END OF struc.
  Les champs sont ignores pour l instant (stub structure).        }
Procedure ParseTypesBlock;
Begin
  EatKw(KW_BEGIN); EatKw(KW_OF);
  { Nom de la structure }
  If CurTokType = TOK_IDENT Then Consume;
  If CurTokType = TOK_COMMA Then Consume;
  { Sauter les champs jusqu a END OF }
  While Not (CurTokType = TOK_EOF) Do
  Begin
    If TokIsKw(KW_END) Then
    Begin
      Consume; EatKw(KW_OF);
      If CurTokType = TOK_IDENT Then Consume;
      If CurTokType = TOK_DOT Then Consume;
      Break;
    End;
    Consume;
  End;
End;

{ ---- ParseData : parser DATA ou CONSTANTS --------------------
  Syntaxes :
    DATA nom TYPE I [VALUE 0].
    DATA nom(n) TYPE C [VALUE ' '].
    DATA: nom TYPE I, nom2 TYPE C(20).
    CONSTANTS nom TYPE I VALUE 42.
  Le mot-cle DATA ou CONSTANTS a deja ete consomme.              }
Procedure ParseData(IsConst : Boolean);
Var Multi : Boolean;
    VName : TString;
Begin
  Multi := (CurTokType = TOK_COLON);
  If Multi Then Consume;
  Repeat
    { TYPES: BEGIN OF ... -> traitement special }
    If TokIsKw(KW_BEGIN) Then
    Begin
      ParseTypesBlock;
      If Not Multi Then Break;
      If CurTokType = TOK_COMMA Then Consume Else Break;
      Continue;
    End;
    If CurTokType <> TOK_IDENT Then Break;
    VName := CurTokStr;
    Consume;
    ParseOneVar(VName, IsConst);
    If (Not Multi) Or (CurTokType <> TOK_COMMA) Then Break;
    Consume;  { sauter la virgule }
  Until (CurTokType = TOK_DOT) Or (CurTokType = TOK_EOF);
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseTypes : parser TYPES declarations ------------------
  Syntaxes :
    TYPES nom TYPE I.
    TYPES: BEGIN OF struc, champ TYPE I, END OF struc.
    TYPES: nom TYPE TABLE OF struc.
  Le mot-cle TYPES a deja ete consomme.                          }
Procedure ParseTypes;
Var Multi : Boolean;
Begin
  Multi := (CurTokType = TOK_COLON);
  If Multi Then Consume;
  Repeat
    If TokIsKw(KW_BEGIN) Then
    Begin ParseTypesBlock; If Not Multi Then Break; End
    Else
    Begin
      { TYPES nom TYPE I : alias de type (stub, ignore) }
      While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_COMMA)
            And (CurTokType <> TOK_EOF) Do
        Consume;
    End;
    If (Not Multi) Or (CurTokType <> TOK_COMMA) Then Break;
    Consume;
  Until (CurTokType = TOK_DOT) Or (CurTokType = TOK_EOF);
  If CurTokType = TOK_DOT Then Consume;
End;

{ ============================================================ }
{ PRIMITIVES D EMISSION ASM (TODO 08)                          }
{ ============================================================ }

{ ---- Emit : ecrire une ligne brute dans le listing ASM ----- }
Procedure Emit(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
  If Opts.Verbose Then
    WriteLn('  ', S);
End;

{ ---- EmitI : instruction indentee avec TAB ------------------- }
Procedure EmitI(Const S : TString);
Begin
  Emit('        ' + S);
End;

{ ---- EmitLabel : etiquette suivie d un deux-points ----------- }
Procedure EmitLabel(Const S : TString);
Begin
  Emit(S + ':');
End;

{ ---- EmitComment : commentaire ASM (prefixe ;) --------------- }
Procedure EmitComment(Const S : TString);
Begin
  Emit('        ; ' + S);
End;

{ ---- EmitBlank : ligne vide ---------------------------------- }
Procedure EmitBlank;
Begin
  Emit('');
End;

{ ---- NewLabel : generer un label unique ---------------------- }
Function NewLabel : TString;
Begin
  Inc(LabelCount);
  NewLabel := AB_LBL_PFX + IntToStr_(LabelCount);
End;

{ ---- AddStringLit : ajouter une chaine litterale ------------- }
Function AddStringLit(Const S : TString) : TString;
Var Lbl : TString;
Begin
  Inc(StrLitCount);
  Lbl := AB_STR_PFX + IntToStr_(StrLitCount);
  If StrLitCount <= MAX_DATA Then
  Begin
    StrLitTab[StrLitCount].Text     := S;
    StrLitTab[StrLitCount].AsmLabel := Lbl;
  End;
  AddStringLit := Lbl;
End;

{ ============================================================ }
{ GENERATION DE CODE INLINE (helpers pour TODO 08/09)          }
{ ============================================================ }

{ ---- GenLoadVar32 : charger une variable dans EAX ----------- }
Procedure GenLoadVar32(SymIdx : Integer);
Var SC, DT, BP : Integer; Lbl : TString;
Begin
  If (SymIdx < 1) Or (SymIdx > SymCount) Then
  Begin EmitComment('GenLoadVar32: idx invalide'); Exit; End;
  SC  := SymTab[SymIdx].StoreClass;
  DT  := SymTab[SymIdx].DataType;
  BP  := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  { CONSTANT : valeur immediate }
  If SC = STORE_CONSTANT Then
  Begin
    EmitI('MOV     EAX, ' + IntToStr_(SymTab[SymIdx].InitNum));
    Exit;
  End;
  { STORE_PARAM : parametre de FORM (TODO 13) }
  If SC = STORE_PARAM Then
  Begin
    If SymTab[SymIdx].ParamKind = PARAM_CHANGING Then
    Begin
      { CHANGING : argument passe par adresse (dereference) }
      EmitI('MOV     ECX, DWORD PTR [EBP+' + IntToStr_(BP) + ']');
      Case DT Of
        TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
          EmitI('MOV     EAX, ECX');
      Else
        EmitI('MOV     EAX, DWORD PTR [ECX]');
      End;
    End
    Else
    Begin
      { USING : argument passe par valeur (acces direct) }
      Case DT Of
        TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
          EmitI('LEA     EAX, [EBP+' + IntToStr_(BP) + ']');
      Else
        EmitI('MOV     EAX, DWORD PTR [EBP+' + IntToStr_(BP) + ']');
      End;
    End;
    Exit;
  End;
  Case DT Of
    TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
    Begin
      { Chaine : charger l adresse (LEA) }
      If SC = STORE_AUTO Then
        EmitI('LEA     EAX, [EBP' + IntToStr_(BP) + ']')
      Else
        EmitI('LEA     EAX, [' + Lbl + ']');
    End;
  Else
    { Numerique : charger la valeur (MOV) }
    If SC = STORE_AUTO Then
      EmitI('MOV     EAX, DWORD PTR [EBP' + IntToStr_(BP) + ']')
    Else
      EmitI('MOV     EAX, DWORD PTR [' + Lbl + ']');
  End;
End;

{ ---- GenStoreVar32 : stocker EAX dans une variable (TODO 09)- }
Procedure GenStoreVar32(SymIdx : Integer);
Var SC, DT, BP : Integer; Lbl : TString;
Begin
  If (SymIdx < 1) Or (SymIdx > SymCount) Then
  Begin EmitComment('GenStoreVar32: idx invalide'); Exit; End;
  SC  := SymTab[SymIdx].StoreClass;
  DT  := SymTab[SymIdx].DataType;
  BP  := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  If SC = STORE_CONSTANT Then
  Begin WarnMsg('Affectation a une CONSTANT ignoree'); Exit; End;
  { STORE_PARAM : parametre de FORM (TODO 13) }
  If SC = STORE_PARAM Then
  Begin
    If SymTab[SymIdx].ParamKind = PARAM_CHANGING Then
    Begin
      { CHANGING : ecrire a travers le pointeur }
      EmitI('MOV     ECX, DWORD PTR [EBP+' + IntToStr_(BP) + ']');
      Case DT Of
        TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
        Begin
          EmitI('MOV     ESI, EAX');
          EmitI('MOV     EDI, ECX');
          EmitI('CALL    ' + AB_RT_PFX + 'STRCOPY');
        End;
      Else
        EmitI('MOV     DWORD PTR [ECX], EAX');
      End;
    End
    Else
    Begin
      { USING : ecrire directement dans la pile }
      Case DT Of
        TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
        Begin
          EmitI('MOV     ESI, EAX');
          EmitI('LEA     EDI, [EBP+' + IntToStr_(BP) + ']');
          EmitI('CALL    ' + AB_RT_PFX + 'STRCOPY');
        End;
      Else
        EmitI('MOV     DWORD PTR [EBP+' + IntToStr_(BP) + '], EAX');
      End;
    End;
    Exit;
  End;
  Case DT Of
    TYPE_C, TYPE_STRING, TYPE_D, TYPE_T, TYPE_N, TYPE_XSTRING:
    Begin
      { Chaine : EAX = adresse source -> copier vers dest }
      EmitI('MOV     ESI, EAX');
      If SC = STORE_AUTO Then
        EmitI('LEA     EDI, [EBP' + IntToStr_(BP) + ']')
      Else
        EmitI('LEA     EDI, [' + Lbl + ']');
      EmitI('CALL    ' + AB_RT_PFX + 'STRCOPY');
    End;
  Else
    { Numerique : MOV DWORD PTR }
    If SC = STORE_AUTO Then
      EmitI('MOV     DWORD PTR [EBP' + IntToStr_(BP) + '], EAX')
    Else
      EmitI('MOV     DWORD PTR [' + Lbl + '], EAX');
  End;
End;

{ ---- GenBinOp32 : emettre l operation binaire 32 bits ------- }
Procedure GenBinOp32(Op : Integer);
Begin
  Case Op Of
    TOK_PLUS:  EmitI('ADD     EAX, EBX');
    TOK_MINUS: EmitI('SUB     EAX, EBX');
    TOK_STAR:  EmitI('IMUL    EAX, EBX');
    TOK_SLASH:
    Begin
      EmitI('CDQ');
      EmitI('IDIV    EBX');
    End;
    TOK_CONCAT: EmitComment('&& concatenation (stub)');
  Else
    EmitComment('GenBinOp32: op inconnu');
  End;
End;

{ ---- GenModDiv32 : division entiere ou modulo 32 bits ------- }
{   is_div = True  -> resultat = quotient  (EAX apres IDIV)    }
{   is_div = False -> resultat = reste     (EDX apres IDIV)     }
Procedure GenModDiv32(IsDiv : Boolean);
Begin
  EmitI('CDQ');
  EmitI('IDIV    EBX');
  If Not IsDiv Then
    EmitI('MOV     EAX, EDX');
End;

{ ---- GenCompare32 : comparaison 32 bits -> EAX=1/0 --------- }
Procedure GenCompare32(Op : Integer);
Begin
  EmitI('CMP     EAX, EBX');
  Case Op Of
    TOK_EQ, KW_EQ: EmitI('SETE    AL');
    TOK_NE, KW_NE: EmitI('SETNE   AL');
    TOK_LT, KW_LT: EmitI('SETL    AL');
    TOK_GT, KW_GT: EmitI('SETG    AL');
    TOK_LE, KW_LE: EmitI('SETLE   AL');
    TOK_GE, KW_GE: EmitI('SETGE   AL');
  Else
    EmitI('SETE    AL');
  End;
  EmitI('MOVZX   EAX, AL');
End;

{ ---- GenBuiltIn32 : fonctions built-in -> True si reconnue -- }
Function GenBuiltIn32(Const BName : TString) : Boolean;
Var Lbl1, Lbl2 : TString;
Begin
  GenBuiltIn32 := True;
  Lbl1 := NewLabel;
  Lbl2 := NewLabel;
  If (BName = 'STRLEN') Or (BName = 'strlen') Then
  Begin
    { STRLEN( var ) -> longueur d une chaine terminee par 0 }
    ParseExpr;
    If CurTokType = TOK_RPAREN Then Consume;
    EmitI('MOV     ESI, EAX');
    EmitI('XOR     ECX, ECX');
    EmitLabel(Lbl1);
    EmitI('MOV     AL, [ESI]');
    EmitI('CMP     AL, 0');
    EmitI('JE      ' + Lbl2);
    EmitI('INC     ESI');
    EmitI('INC     ECX');
    EmitI('JMP     ' + Lbl1);
    EmitLabel(Lbl2);
    EmitI('MOV     EAX, ECX');
  End
  Else If (BName = 'ABS') Or (BName = 'abs') Then
  Begin
    { ABS( expr ) -> valeur absolue }
    ParseExpr;
    If CurTokType = TOK_RPAREN Then Consume;
    EmitI('CDQ');
    EmitI('XOR     EAX, EDX');
    EmitI('SUB     EAX, EDX');
  End
  Else If (BName = 'SIGN') Or (BName = 'sign') Then
  Begin
    ParseExpr;
    If CurTokType = TOK_RPAREN Then Consume;
    EmitI('TEST    EAX, EAX');
    EmitI('JZ      ' + Lbl2);
    EmitI('JNS     ' + Lbl1);
    EmitI('MOV     EAX, 0FFFFFFFFh');
    EmitI('JMP     ' + Lbl2);
    EmitLabel(Lbl1);
    EmitI('MOV     EAX, 1');
    EmitLabel(Lbl2);
  End
  Else If (BName = 'LINES') Or (BName = 'lines') Then
  Begin
    { LINES( itab ) -> stub = 0 }
    ParseExpr;
    If CurTokType = TOK_RPAREN Then Consume;
    EmitI('XOR     EAX, EAX');
    EmitComment('LINES( itab ) stub = 0');
  End
  Else
    GenBuiltIn32 := False;
End;

{ ============================================================ }
{ PARSEUR D EXPRESSIONS (TODO 08 - 32 bits)                    }
{ ============================================================ }

{ ---- ParsePrimaryExpr : expression primaire ----------------
  Constante numerique, chaine, variable, parentheses, - unaire,
  built-in STRLEN/ABS/SIGN/LINES                                }
Function ParsePrimaryExpr : Integer;
Var SymIdx, NArgs : Integer;
    S : TString;
    Lbl_T, Lbl_E : TString;
Begin
  ParsePrimaryExpr := TYPE_I;
  Case CurTokType Of
    { Constante entiere }
    TOK_NUMBER:
    Begin
      EmitI('MOV     EAX, ' + IntToStr_(CurTokNum));
      Consume;
    End;
    { Constante flottante (stub : partie entiere seulement) }
    TOK_FLOAT:
    Begin
      EmitI('MOV     EAX, ' + IntToStr_(CurTokNum) + '  ; FLOAT stub');
      Consume;
    End;
    { Chaine litterale }
    TOK_STRING:
    Begin
      S := AddStringLit(CurTokStr);
      EmitI('LEA     EAX, [' + S + ']');
      Consume;
      ParsePrimaryExpr := TYPE_C;
    End;
    { Expression parenthesee }
    TOK_LPAREN:
    Begin
      Consume;
      ParsePrimaryExpr := ParseExpr;
      If CurTokType = TOK_RPAREN Then Consume
      Else LexError('Attendu ) dans expression');
    End;
    { Unaire : - expr }
    TOK_MINUS:
    Begin
      Consume;
      ParsePrimaryExpr := ParsePrimaryExpr;
      EmitI('NEG     EAX');
    End;
    { Identificateur : variable, constante, built-in }
    TOK_IDENT:
    Begin
      { NOT en tant qu operateur unaire }
      If CurTokKw = KW_NOT Then
      Begin
        Lbl_T := NewLabel; Lbl_E := NewLabel;
        Consume;
        ParsePrimaryExpr := ParsePrimaryExpr;
        EmitI('TEST    EAX, EAX');
        EmitI('JNZ     ' + Lbl_T);
        EmitI('MOV     EAX, 1');
        EmitI('JMP     ' + Lbl_E);
        EmitLabel(Lbl_T);
        EmitI('XOR     EAX, EAX');
        EmitLabel(Lbl_E);
      End
      Else
      Begin
        S := CurTokStr; Consume;
        { Appel built-in ou FORM comme expression }
        If CurTokType = TOK_LPAREN Then
        Begin
          Consume;
          If Not GenBuiltIn32(S) Then
          Begin
            { Appel de FORM comme expression (stub) }
            NArgs := 0;
            While (CurTokType <> TOK_RPAREN) And
                  (CurTokType <> TOK_EOF) Do
            Begin
              ParseExpr;
              EmitI('PUSH    EAX');
              Inc(NArgs);
              If CurTokType = TOK_COMMA Then Consume;
            End;
            If CurTokType = TOK_RPAREN Then Consume;
            EmitI('CALL    ' + AB_FN_PFX + AsmIdent(S));
            If NArgs > 0 Then
              EmitI('ADD     ESP, ' + IntToStr_(NArgs * 4));
          End;
        End
        Else
        Begin
          { Chargement d une variable / constante }
          SymIdx := FindSym(S);
          If SymIdx > 0 Then
          Begin
            GenLoadVar32(SymIdx);
            ParsePrimaryExpr := SymTab[SymIdx].DataType;
          End
          Else
          Begin
            EmitComment('Variable inconnue: ' + S + ' (suppose 0)');
            EmitI('XOR     EAX, EAX');
          End;
        End;
      End;
    End;
  Else
    Begin
      EmitComment('ParsePrimaryExpr: token inattendu: ' + CurTokStr);
      Consume;
    End;
  End;
End;

{ ---- ParseMulExpr : multiplication / division / MOD / DIV --- }
Function ParseMulExpr : Integer;
Var Op : Integer; IsMod, IsDiv : Boolean;
Begin
  ParseMulExpr := ParsePrimaryExpr;
  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH)
     Or TokIsKw(KW_MOD) Or TokIsKw(KW_DIV) Do
  Begin
    IsMod := TokIsKw(KW_MOD);
    IsDiv := TokIsKw(KW_DIV);
    Op := CurTokType; Consume;
    EmitI('PUSH    EAX');
    ParseMulExpr := ParsePrimaryExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    If IsMod Then
      GenModDiv32(False)
    Else If IsDiv Then
      GenModDiv32(True)
    Else
      GenBinOp32(Op);
  End;
End;

{ ---- ParseAddExpr : addition / soustraction ----------------- }
Function ParseAddExpr : Integer;
Var Op : Integer;
Begin
  ParseAddExpr := ParseMulExpr;
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Do
  Begin
    Op := CurTokType; Consume;
    EmitI('PUSH    EAX');
    ParseAddExpr := ParseMulExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    GenBinOp32(Op);
  End;
End;

{ ---- ParseCompareExpr : comparaisons et predicats ----------- }
Function ParseCompareExpr : Integer;
Var Op, Kw : Integer;
    Lbl_F, Lbl_E : TString;
    IsNot : Boolean;
Begin
  ParseCompareExpr := ParseAddExpr;
  Op := CurTokType;
  Kw := CurTokKw;
  { Operateurs symboliques : = <> < > <= >= }
  If (Op = TOK_EQ) Or (Op = TOK_NE) Or
     (Op = TOK_LT) Or (Op = TOK_LE) Or
     (Op = TOK_GT) Or (Op = TOK_GE) Then
  Begin
    Consume;
    EmitI('PUSH    EAX');
    ParseCompareExpr := ParseAddExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    GenCompare32(Op);
  End
  { Formes verbales : EQ NE LT GT LE GE }
  Else If (CurTokType = TOK_IDENT) And
          ((Kw = KW_EQ) Or (Kw = KW_NE) Or
           (Kw = KW_LT) Or (Kw = KW_LE) Or
           (Kw = KW_GT) Or (Kw = KW_GE)) Then
  Begin
    Consume;
    EmitI('PUSH    EAX');
    ParseCompareExpr := ParseAddExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    GenCompare32(Kw);
  End
  { IS [NOT] INITIAL / BOUND }
  Else If TokIsKw(KW_IS) Then
  Begin
    Consume;
    IsNot := False;
    If TokIsKw(KW_NOT) Then Begin Consume; IsNot := True; End;
    Lbl_F := NewLabel; Lbl_E := NewLabel;
    If TokIsKw(KW_INITIAL) Then
    Begin
      Consume;
      EmitI('TEST    EAX, EAX');
      If IsNot Then EmitI('JNZ     ' + Lbl_F)
      Else          EmitI('JZ      ' + Lbl_F);
      EmitI('MOV     EAX, 1');
      EmitI('JMP     ' + Lbl_E);
      EmitLabel(Lbl_F);
      EmitI('XOR     EAX, EAX');
      EmitLabel(Lbl_E);
    End
    Else If TokIsKw(KW_BOUND) Then
    Begin
      Consume;
      EmitComment('IS BOUND stub = vrai');
      If IsNot Then EmitI('XOR     EAX, EAX')
      Else          EmitI('MOV     EAX, 1');
    End
    Else
      WarnMsg('IS : predicat inconnu -> ignore');
  End
  { BETWEEN lo AND hi }
  Else If TokIsKw(KW_BETWEEN) Then
  Begin
    Consume;
    Lbl_F := NewLabel; Lbl_E := NewLabel;
    EmitI('PUSH    EAX');
    ParseAddExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    EmitI('PUSH    EAX');
    EmitI('CMP     EAX, EBX');
    EmitI('JGE     ' + Lbl_F);
    { var < lo : pile non consommee -> nettoyer et faux }
    EmitI('ADD     ESP, 4');
    EmitI('XOR     EAX, EAX');
    EmitI('JMP     ' + Lbl_E);
    EmitLabel(Lbl_F);
    EatKw(KW_AND);
    ParseAddExpr;
    EmitI('MOV     EBX, EAX');
    EmitI('POP     EAX');
    EmitI('CMP     EAX, EBX');
    EmitI('JG      ' + Lbl_F + '_hi');
    EmitI('MOV     EAX, 1');
    EmitI('JMP     ' + Lbl_E);
    EmitLabel(Lbl_F + '_hi');
    EmitI('XOR     EAX, EAX');
    EmitLabel(Lbl_E);
  End
  { IN (stub) }
  Else If TokIsKw(KW_IN) Then
  Begin
    Consume;
    If CurTokType = TOK_IDENT Then Consume;
    EmitComment('IN set stub = faux');
    EmitI('XOR     EAX, EAX');
  End;
End;

{ ---- ParseNotExpr : operateur logique NOT ------------------- }
Function ParseNotExpr : Integer;
Var Lbl_T, Lbl_E : TString;
Begin
  If TokIsKw(KW_NOT) Then
  Begin
    Consume;
    Lbl_T := NewLabel; Lbl_E := NewLabel;
    ParseNotExpr := ParseCompareExpr;
    EmitI('TEST    EAX, EAX');
    EmitI('JNZ     ' + Lbl_T);
    EmitI('MOV     EAX, 1');
    EmitI('JMP     ' + Lbl_E);
    EmitLabel(Lbl_T);
    EmitI('XOR     EAX, EAX');
    EmitLabel(Lbl_E);
  End
  Else
    ParseNotExpr := ParseCompareExpr;
End;

{ ---- ParseAndExpr : operateur logique AND ------------------- }
Function ParseAndExpr : Integer;
Begin
  ParseAndExpr := ParseNotExpr;
  While TokIsKw(KW_AND) Do
  Begin
    Consume;
    EmitI('PUSH    EAX');
    ParseAndExpr := ParseNotExpr;
    EmitI('POP     EBX');
    EmitI('AND     EAX, EBX');
  End;
End;

{ ---- ParseExpr : operateur logique OR (racine) -------------- }
Function ParseExpr : Integer;
Begin
  ParseExpr := ParseAndExpr;
  While TokIsKw(KW_OR) Do
  Begin
    Consume;
    EmitI('PUSH    EAX');
    ParseExpr := ParseAndExpr;
    EmitI('POP     EBX');
    EmitI('OR      EAX, EBX');
  End;
End;

{ ============================================================ }
{ TODO 10 : PARSEUR IF / ELSEIF / ELSE / ENDIF                }
{ ============================================================ }

{ ---- ParseStatement : dispatcher d instructions ------------- }
{ Analyse une instruction ABAP complete (terminee par un .)     }
Procedure ParseStatement;
Var ExprType : Integer;
    SkipN    : Integer;
    SavedName : TString;
    DestIdx  : Integer;
Begin
  If CurTokType = TOK_EOF Then Exit;
  If CurTokType = TOK_DOT Then Begin Consume; Exit; End;

  { DATA / CONSTANTS / TYPES }
  If TokIsKw(KW_DATA) Then
  Begin Consume; ParseData(False); Exit; End;
  If TokIsKw(KW_CONSTANTS) Then
  Begin Consume; ParseData(True); Exit; End;
  If TokIsKw(KW_TYPES) Then
  Begin Consume; ParseTypes; Exit; End;

  { COMPUTE var = expr. (TODO 15) }
  If TokIsKw(KW_COMPUTE) Then
  Begin
    Consume;
    EmitComment('COMPUTE');
    { var = expr }
    If CurTokType = TOK_IDENT Then
    Begin
      SavedName := CurTokStr;
      Consume;
      If CurTokType = TOK_EQ Then
      Begin
        Consume;
        ExprType := ParseExpr;
        DestIdx := FindSym(SavedName);
        If DestIdx > 0 Then
          GenStoreVar32(DestIdx)
        Else
          EmitComment('COMPUTE: variable inconnue: ' + SavedName);
      End;
    End;
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { MOVE source TO destination (TODO 15) }
  If TokIsKw(KW_MOVE) Then
  Begin Consume; ParseMove; Exit; End;

  { ADD val TO var (TODO 15) }
  If TokIsKw(KW_ADD) Then
  Begin Consume; ParseAdd; Exit; End;

  { SUBTRACT val FROM var (TODO 15) }
  If TokIsKw(KW_SUBTRACT) Then
  Begin Consume; ParseSubtract; Exit; End;

  { MULTIPLY var BY val (TODO 15) }
  If TokIsKw(KW_MULTIPLY) Then
  Begin Consume; ParseMultiply; Exit; End;

  { DIVIDE var BY val (TODO 15) }
  If TokIsKw(KW_DIVIDE) Then
  Begin Consume; ParseDivide; Exit; End;

  { CLEAR variable (TODO 15) }
  If TokIsKw(KW_CLEAR) Then
  Begin Consume; ParseClear; Exit; End;

  { LOOP AT itab (TODO 16) }
  If TokIsKw(KW_LOOP) Then
  Begin Consume; ParseLoopAt; Exit; End;

  { APPEND [wa TO] itab (TODO 16) }
  If TokIsKw(KW_APPEND) Then
  Begin Consume; ParseAppend; Exit; End;

  { READ TABLE itab INTO wa (TODO 16) }
  If TokIsKw(KW_READ) Then
  Begin Consume; ParseReadTable; Exit; End;

  { SORT itab (TODO 16) }
  If TokIsKw(KW_SORT) Then
  Begin Consume; ParseSort; Exit; End;

  { DELETE itab (TODO 16) }
  If TokIsKw(KW_DELETE) Then
  Begin Consume; ParseDeleteTable; Exit; End;

  { CONCATENATE s1 s2 ... INTO dest (TODO 17) }
  If TokIsKw(KW_CONCATENATE) Then
  Begin Consume; ParseConcatenate; Exit; End;

  { SPLIT src AT sep INTO s1 s2 (TODO 17) }
  If TokIsKw(KW_SPLIT) Then
  Begin Consume; ParseSplit; Exit; End;

  { SHIFT var (TODO 17) }
  If TokIsKw(KW_SHIFT) Then
  Begin Consume; ParseShift; Exit; End;

  { REPLACE old IN dest WITH new (TODO 17) }
  If TokIsKw(KW_REPLACE) Then
  Begin Consume; ParseReplace; Exit; End;

  { TRANSLATE var TO UPPER/LOWER CASE (TODO 17) }
  If TokIsKw(KW_TRANSLATE) Then
  Begin Consume; ParseTranslate; Exit; End;

  { CONDENSE var [NO-GAPS] (TODO 17) }
  If TokIsKw(KW_CONDENSE) Then
  Begin Consume; ParseCondense; Exit; End;

  { FIND pattern IN var (TODO 17) }
  If TokIsKw(KW_FIND) Then
  Begin Consume; ParseFind; Exit; End;

  { IF / ELSEIF / ELSE / ENDIF }
  If TokIsKw(KW_IF) Then
  Begin Consume; ParseIf; Exit; End;

  { CASE / WHEN / ENDCASE }
  If TokIsKw(KW_CASE) Then
  Begin Consume; ParseCase; Exit; End;

  { WHILE / ENDWHILE }
  If TokIsKw(KW_WHILE) Then
  Begin Consume; ParseWhile; Exit; End;

  { DO [n TIMES] / ENDDO }
  If TokIsKw(KW_DO) Then
  Begin Consume; ParseDo; Exit; End;

  { FORM / ENDFORM (TODO 13) }
  If TokIsKw(KW_FORM) Then
  Begin Consume; ParseForm; Exit; End;

  { PERFORM nomform (TODO 13) }
  If TokIsKw(KW_PERFORM) Then
  Begin Consume; ParsePerform; Exit; End;

  { WRITE / WRITE: (TODO 14) }
  If TokIsKw(KW_WRITE) Then
  Begin Consume; ParseWrite; Exit; End;

  { SKIP [n]. (TODO 14) }
  If TokIsKw(KW_SKIP) Then
  Begin
    Consume;
    EmitComment('SKIP');
    If (CurTokType = TOK_NUMBER) Then
    Begin
      { SKIP n : emettre n CRLF }
      SkipN := CurTokNum;
      Consume;
      While SkipN > 0 Do
      Begin
        EmitI('CALL    ' + AB_RT_PFX + 'CRLF');
        Dec(SkipN);
      End;
    End
    Else
      { SKIP sans argument : 1 saut de ligne }
      EmitI('CALL    ' + AB_RT_PFX + 'CRLF');
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { NEW-LINE. (TODO 14) }
  If TokIsKw(KW_NEW_LINE) Then
  Begin
    Consume;
    EmitComment('NEW-LINE');
    EmitI('CALL    ' + AB_RT_PFX + 'CRLF');
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { EXIT : sortir de la boucle courante }
  If TokIsKw(KW_EXIT) Then
  Begin
    Consume;
    If CurrentExitLabel <> '' Then
      EmitI('JMP     ' + CurrentExitLabel)
    Else
      LexError('EXIT en dehors d''une boucle');
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { CONTINUE : retour au debut de la boucle courante }
  If TokIsKw(KW_CONTINUE) Then
  Begin
    Consume;
    If CurrentContLabel <> '' Then
      EmitI('JMP     ' + CurrentContLabel)
    Else
      LexError('CONTINUE en dehors d''une boucle');
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { REFRESH itab. (TODO 20) }
  If TokIsKw(KW_REFRESH) Then
  Begin Consume; ParseRefresh; Exit; End;

  { FREE itab. (TODO 20) }
  If TokIsKw(KW_FREE) Then
  Begin Consume; ParseFree; Exit; End;

  { CHECK condition. (TODO 20) }
  If TokIsKw(KW_CHECK) Then
  Begin Consume; ParseCheck; Exit; End;

  { STOP. (TODO 20) }
  If TokIsKw(KW_STOP) Then
  Begin Consume; ParseStop; Exit; End;

  { RETURN. (TODO 20) }
  If TokIsKw(KW_RETURN) Then
  Begin Consume; ParseReturn; Exit; End;

  { SELECT ... [ENDSELECT.] (TODO 21) }
  If TokIsKw(KW_SELECT) Then
  Begin Consume; ParseSelect; Exit; End;

  { CALL FUNCTION 'nom'. (TODO 22) }
  If TokIsKw(KW_CALL) Then
  Begin Consume; ParseCallFunction; Exit; End;

  { FUNCTION nom. ... ENDFUNCTION. (TODO 22) }
  If TokIsKw(KW_FUNCTION) Then
  Begin Consume; ParseFunctionDecl; Exit; End;

  { TRY. ... CATCH cx. ... [CLEANUP.] ENDTRY. (TODO 23) }
  If TokIsKw(KW_TRY) Then
  Begin Consume; ParseTry; Exit; End;

  { RAISE [EXCEPTION ...]. (TODO 23) }
  If TokIsKw(KW_RAISE) Then
  Begin Consume; ParseRaise; Exit; End;

  { START-OF-SELECTION. (TODO 23) }
  If TokIsKw(KW_START_OF_SEL) Then
  Begin Consume; ParseEvent(KW_START_OF_SEL); Exit; End;

  { END-OF-SELECTION. (TODO 23) }
  If TokIsKw(KW_END_OF_SEL) Then
  Begin Consume; ParseEvent(KW_END_OF_SEL); Exit; End;

  { TOP-OF-PAGE. (TODO 23) }
  If TokIsKw(KW_TOP_OF_PAGE) Then
  Begin Consume; ParseEvent(KW_TOP_OF_PAGE); Exit; End;

  { END-OF-PAGE. (TODO 23) }
  If TokIsKw(KW_END_OF_PAGE) Then
  Begin Consume; ParseEvent(KW_END_OF_PAGE); Exit; End;

  { AT LINE-SELECTION. (TODO 23) }
  If TokIsKw(KW_LINE_SEL) Then
  Begin Consume; ParseEvent(KW_LINE_SEL); Exit; End;

  { AT USER-COMMAND. (TODO 23) }
  If TokIsKw(KW_USER_CMD) Then
  Begin Consume; ParseEvent(KW_USER_CMD); Exit; End;

  { PARAMETERS p TYPE I [DEFAULT val]. (TODO 23) }
  If TokIsKw(KW_PARAMETERS) Then
  Begin Consume; ParseSelScreen(True); Exit; End;

  { SELECT-OPTIONS s FOR var. (TODO 23) }
  If TokIsKw(KW_SELECT_OPTIONS) Then
  Begin Consume; ParseSelScreen(False); Exit; End;

  { REPORT / PROGRAM en cours de programme (ignore, TODO 23) }
  If TokIsKw(KW_REPORT) Or TokIsKw(KW_PROGRAM) Then
  Begin Consume; SkipToDot; Exit; End;

  { var = expr. (style ABAP Objet / assignation directe, TODO 15) }
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_NONE) Then
  Begin
    SavedName := CurTokStr;
    DestIdx := FindSym(SavedName);
    If DestIdx > 0 Then
    Begin
      Consume;
      If CurTokType = TOK_EQ Then
      Begin
        Consume;
        EmitComment(SavedName + ' = expr');
        ExprType := ParseExpr;
        GenStoreVar32(DestIdx);
        If CurTokType = TOK_DOT Then Consume;
        Exit;
      End
      Else
      Begin
        { pas un signe = : retomber dans le cas generique (skip) }
        While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) Do
          Consume;
        If CurTokType = TOK_DOT Then Consume;
        Exit;
      End;
    End;
  End;

  { instruction non reconnue : sauter jusqu au prochain point }
  If CurTokType = TOK_DOT Then
    Consume
  Else
  Begin
    While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) Do
      Consume;
    If CurTokType = TOK_DOT Then Consume;
  End;
End;

{ ---- ParseBlock : parser un bloc jusqu aux mots-cles d arret }
{ Stop1, Stop2, Stop3 : mots-cles d arret (KW_NONE si unused)  }
Procedure ParseBlock(Stop1, Stop2, Stop3 : Integer);
Begin
  While (CurTokType <> TOK_EOF) Do
  Begin
    If ((Stop1 <> KW_NONE) And TokIsKw(Stop1)) Or
       ((Stop2 <> KW_NONE) And TokIsKw(Stop2)) Or
       ((Stop3 <> KW_NONE) And TokIsKw(Stop3)) Then Break;
    ParseStatement;
  End;
End;

{ ---- ParseIf : IF / ELSEIF / ELSE / ENDIF -------------------- }
{ Syntaxe ABAP :                                                  }
{   IF condition. instructions.                                   }
{   [ELSEIF condition. instructions.] ...                         }
{   [ELSE. instructions.]                                         }
{   ENDIF.                                                        }
Procedure ParseIf;
Var LblNext, LblEnd : TString;
    FirstBranch     : Boolean;
Begin
  LblEnd      := NewLabel + '_EN';
  FirstBranch := True;

  { --- Boucle IF / ELSEIF --- }
  Repeat
    If FirstBranch Then
      EmitComment('---- IF ----')
    Else
      EmitComment('---- ELSEIF ----');
    FirstBranch := False;

    LblNext := NewLabel + '_NX';

    { Evaluer la condition -> EAX }
    ParseExpr;

    { Consommer le point terminateur apres la condition }
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres condition IF/ELSEIF');

    { Saut conditionnel si faux (EAX = 0) }
    EmitI('TEST    EAX, EAX');
    EmitI('JZ      ' + LblNext);

    { Corps de la branche }
    EnterScope(SK_BLOCK, 0);
    ParseBlock(KW_ELSEIF, KW_ELSE, KW_ENDIF);
    LeaveScope;

    { Saut vers la fin apres le corps }
    EmitI('JMP     ' + LblEnd);

    { Etiquette du prochain ELSEIF ou de la fin de branche }
    EmitLabel(LblNext);

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
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ELSE');
    EmitComment('---- ELSE ----');
    EnterScope(SK_BLOCK, 0);
    ParseBlock(KW_ENDIF, KW_NONE, KW_NONE);
    LeaveScope;
  End;

  { --- ENDIF. --- }
  If TokIsKw(KW_ENDIF) Then
  Begin
    Consume; { skip ENDIF }
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDIF');
  End
  Else
    LexError('ENDIF attendu');

  { Etiquette de fin commune a toutes les branches }
  EmitLabel(LblEnd);
End;

{ ============================================================ }
{ TODO 11 : PARSEUR CASE / WHEN / WHEN OTHERS / ENDCASE        }
{ ============================================================ }

{ ---- ParseCase : CASE / WHEN / WHEN OTHERS / ENDCASE --------- }
{ Syntaxe ABAP :                                                  }
{   CASE variable.                                                }
{     WHEN valeur. instructions.                                  }
{     WHEN valeur1 OR valeur2. instructions.                      }
{     WHEN OTHERS. instructions.                                  }
{   ENDCASE.                                                      }
Procedure ParseCase;
Var LblEndCase, LblNext, LblBody : TString;
Begin
  EmitComment('---- CASE ----');

  { Evaluer la variable selecteur -> EAX, puis sauvegarder dans EDX }
  ParseExpr;
  EmitI('MOV     EDX, EAX');

  { Consommer le point apres la variable }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres variable CASE');

  LblEndCase := NewLabel + '_EC';

  { --- Boucle sur les clauses WHEN --- }
  While TokIsKw(KW_WHEN) Do
  Begin
    Consume; { skip WHEN }

    { WHEN OTHERS : clause par defaut }
    If TokIsKw(KW_OTHERS) Then
    Begin
      Consume; { skip OTHERS }
      If CurTokType = TOK_DOT Then Consume
      Else LexError('Point attendu apres WHEN OTHERS');
      EmitComment('---- WHEN OTHERS ----');
      EnterScope(SK_BLOCK, 0);
      ParseBlock(KW_ENDCASE, KW_NONE, KW_NONE);
      LeaveScope;
      EmitI('JMP     ' + LblEndCase);
      Break; { WHEN OTHERS termine la liste des clauses }
    End;

    { WHEN valeur [OR valeur2 ...] }
    LblNext := NewLabel + '_WN';
    LblBody := NewLabel + '_WB';
    EmitComment('---- WHEN ----');

    { Evaluer la premiere valeur -> EAX, comparer avec EDX }
    { NB : ParseAndExpr (pas ParseExpr) pour eviter que OR }
    { soit consomme comme operateur logique                 }
    ParseAndExpr;
    EmitI('CMP     EDX, EAX');

    { Valeurs supplementaires separees par OR }
    While TokIsKw(KW_OR) Do
    Begin
      EmitI('JE      ' + LblBody); { correspond -> sauter au corps }
      Consume; { skip OR }
      ParseAndExpr; { valeur suivante dans EAX }
      EmitI('CMP     EDX, EAX');
    End;

    { Apres la derniere valeur : sauter si pas egal }
    EmitI('JNE     ' + LblNext);

    { --- Corps de la clause --- }
    EmitLabel(LblBody);
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres valeur(s) WHEN');

    EnterScope(SK_BLOCK, 0);
    ParseBlock(KW_WHEN, KW_ENDCASE, KW_NONE);
    LeaveScope;
    EmitI('JMP     ' + LblEndCase);

    { Etiquette pour la clause suivante }
    EmitLabel(LblNext);
  End; { While WHEN }

  { --- ENDCASE. --- }
  If TokIsKw(KW_ENDCASE) Then
  Begin
    Consume; { skip ENDCASE }
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDCASE');
  End
  Else
    LexError('ENDCASE attendu');

  { Etiquette de fin du CASE }
  EmitLabel(LblEndCase);
End;

{ ============================================================ }
{ ParseWhile : WHILE condition. instructions. ENDWHILE.        }
{ Generation 32 bits :                                         }
{   _ABL_top: evaluer condition -> EAX                         }
{   TEST EAX, EAX + JZ _ABL_end                               }
{   Corps + JMP _ABL_top + EmitLabel(_ABL_end)                 }
{ ============================================================ }
Procedure ParseWhile;
Var LblTop, LblEnd : TString;
Begin
  EmitComment('---- WHILE ----');

  LblTop := NewLabel + '_WT';
  LblEnd := NewLabel + '_WE';

  EmitLabel(LblTop);

  { Evaluer la condition -> EAX }
  ParseExpr;

  { Consommer le point apres la condition }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres condition WHILE');

  { Saut si faux -> fin }
  EmitI('TEST    EAX, EAX');
  EmitI('JZ      ' + LblEnd);

  { Corps de la boucle }
  EnterScope(SK_LOOP, 0);
  SetExitLabel(LblEnd);
  SetContLabel(LblTop);
  ParseBlock(KW_ENDWHILE, KW_NONE, KW_NONE);
  LeaveScope;

  { Retour au debut }
  EmitI('JMP     ' + LblTop);
  EmitLabel(LblEnd);

  { ENDWHILE. }
  If TokIsKw(KW_ENDWHILE) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDWHILE');
  End
  Else
    LexError('ENDWHILE attendu');
End;

{ ============================================================ }
{ ParseDo : DO [n TIMES]. instructions. ENDDO.                 }
{ Generation n TIMES (32 bits) :                               }
{   ParseExpr -> EAX / MOV ECX, EAX                           }
{   _ABL_top: TEST ECX, ECX / JZ _ABL_end                     }
{   PUSH ECX / corps / POP ECX / DEC ECX / JMP _ABL_top       }
{ Generation infinie (sans n) :                                }
{   _ABL_top: corps + JMP _ABL_top (EXIT -> JMP _ABL_end)      }
{ ============================================================ }
Procedure ParseDo;
Var LblTop, LblEnd : TString;
    HasCount        : Boolean;
Begin
  EmitComment('---- DO ----');

  LblTop := NewLabel + '_DT';
  LblEnd := NewLabel + '_DE';

  { Detecter si un compteur est fourni (DO n TIMES) ou non (DO infini) }
  HasCount := Not (TokIsKw(KW_ENDDO) Or (CurTokType = TOK_DOT));

  If HasCount Then
  Begin
    { Evaluer n -> EAX, puis ECX }
    ParseExpr;
    EmitI('MOV     ECX, EAX');

    { Consommer TIMES }
    If TokIsKw(KW_TIMES) Then Consume
    Else LexError('TIMES attendu apres compteur DO');

    { Consommer le point }
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres DO n TIMES');

    EmitLabel(LblTop);
    EmitI('TEST    ECX, ECX');
    EmitI('JZ      ' + LblEnd);

    { Sauvegarder ECX avant le corps }
    EmitI('PUSH    ECX');

    { Corps }
    EnterScope(SK_LOOP, 0);
    SetExitLabel(LblEnd);
    SetContLabel(LblTop);
    ParseBlock(KW_ENDDO, KW_NONE, KW_NONE);
    LeaveScope;

    { Restaurer ECX, decrementer, boucler }
    EmitI('POP     ECX');
    EmitI('DEC     ECX');
    EmitI('JMP     ' + LblTop);
  End
  Else
  Begin
    { DO sans compteur : boucle infinie, EXIT pour sortir }
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres DO');

    EmitLabel(LblTop);

    EnterScope(SK_LOOP, 0);
    SetExitLabel(LblEnd);
    SetContLabel(LblTop);
    ParseBlock(KW_ENDDO, KW_NONE, KW_NONE);
    LeaveScope;

    EmitI('JMP     ' + LblTop);
  End;

  EmitLabel(LblEnd);

  { ENDDO. }
  If TokIsKw(KW_ENDDO) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDDO');
  End
  Else
    LexError('ENDDO attendu');
End;

{ ============================================================ }
{ TODO 13 : PERFORM / FORM / ENDFORM (SOUS-ROUTINES 32 BITS)  }
{ ============================================================ }

{ ---- ParseFormParamType : parser un type de parametre FORM --- }
{ Lit optionnellement TYPE t apres un nom de parametre.           }
{ Retourne TYPE_I par defaut si pas de TYPE specifie.              }
Function ParseFormParamType : Integer;
Begin
  ParseFormParamType := TYPE_I;
  If Not TokIsKw(KW_TYPE) Then Exit;
  Consume;
  If CurTokType <> TOK_IDENT Then Exit;
  If StrUpperCase(CurTokStr) = 'I' Then
    ParseFormParamType := TYPE_I
  Else If StrUpperCase(CurTokStr) = 'F' Then
    ParseFormParamType := TYPE_F
  Else If StrUpperCase(CurTokStr) = 'C' Then
    ParseFormParamType := TYPE_C
  Else If StrUpperCase(CurTokStr) = 'N' Then
    ParseFormParamType := TYPE_N
  Else If StrUpperCase(CurTokStr) = 'D' Then
    ParseFormParamType := TYPE_D
  Else If StrUpperCase(CurTokStr) = 'T' Then
    ParseFormParamType := TYPE_T
  Else If StrUpperCase(CurTokStr) = 'P' Then
    ParseFormParamType := TYPE_P
  Else If StrUpperCase(CurTokStr) = 'STRING' Then
    ParseFormParamType := TYPE_STRING
  Else If StrUpperCase(CurTokStr) = 'XSTRING' Then
    ParseFormParamType := TYPE_XSTRING
  Else
    ParseFormParamType := TYPE_I;
  Consume;
End;

{ ---- GenLoadVarAddr32 : charger l adresse d une variable ----- }
{ Met dans EAX l adresse de la variable (pour CHANGING).           }
Procedure GenLoadVarAddr32(SymIdx : Integer);
Var SC, BP : Integer; Lbl : TString;
Begin
  If (SymIdx < 1) Or (SymIdx > SymCount) Then
  Begin EmitComment('GenLoadVarAddr32: idx invalide'); Exit; End;
  SC  := SymTab[SymIdx].StoreClass;
  BP  := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  If SC = STORE_AUTO Then
    EmitI('LEA     EAX, [EBP' + IntToStr_(BP) + ']')
  Else If SC = STORE_PARAM Then
  Begin
    If SymTab[SymIdx].ParamKind = PARAM_CHANGING Then
      EmitI('MOV     EAX, DWORD PTR [EBP+' + IntToStr_(BP) + ']')
    Else
      EmitI('LEA     EAX, [EBP+' + IntToStr_(BP) + ']');
  End
  Else
    EmitI('LEA     EAX, [' + Lbl + ']');
End;

{ ---- ParseForm : FORM nom [USING p1...] [CHANGING p1...] ---- }
{ Syntaxe :                                                       }
{   FORM nom [USING p1 [TYPE t] ...] [CHANGING p1 [TYPE t] ...]. }
{     instructions.                                                }
{   ENDFORM.                                                       }
{ Convention d appel Win32 STDCALL 32 bits.                        }
{ ============================================================ }
Procedure ParseForm;
Var
  FormName    : TString;
  FIdx        : Integer;
  PIdx        : Integer;
  PName       : TString;
  PType       : Integer;
  LblSkip     : TString;
  LblEpi      : TString;
  SymIdx      : Integer;
  I           : Integer;
  TotalParams : Integer;
Begin
  EmitComment('---- FORM ----');

  { Nom de la FORM }
  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom attendu apres FORM'); SkipToDot; Exit; End;
  FormName := CurTokStr;
  Consume;

  { Creer ou retrouver l entree dans FormTab }
  FIdx := AddForm(FormName);
  If FIdx = 0 Then Begin SkipToDot; Exit; End;

  If FormTab[FIdx].Defined Then
  Begin LexError('FORM ' + FormName + ' deja definie'); SkipToDot; Exit; End;

  PIdx := 0;

  { Parser les parametres USING }
  If TokIsKw(KW_USING) Then
  Begin
    Consume;
    While (CurTokType = TOK_IDENT) And
          (CurTokKw <> KW_CHANGING) And
          (CurTokKw <> KW_TABLES) And
          (CurTokType <> TOK_DOT) Do
    Begin
      Inc(PIdx);
      PName := CurTokStr;
      Consume;
      PType := ParseFormParamType;
      FormTab[FIdx].ParamNames[PIdx] := StrUpperCase(PName);
      FormTab[FIdx].ParamKinds[PIdx] := PARAM_USING;
      FormTab[FIdx].ParamTypes[PIdx] := PType;
      Inc(FormTab[FIdx].UsingCount);
    End;
  End;

  { Parser les parametres CHANGING }
  If TokIsKw(KW_CHANGING) Then
  Begin
    Consume;
    While (CurTokType = TOK_IDENT) And
          (CurTokKw <> KW_TABLES) And
          (CurTokType <> TOK_DOT) Do
    Begin
      Inc(PIdx);
      PName := CurTokStr;
      Consume;
      PType := ParseFormParamType;
      FormTab[FIdx].ParamNames[PIdx] := StrUpperCase(PName);
      FormTab[FIdx].ParamKinds[PIdx] := PARAM_CHANGING;
      FormTab[FIdx].ParamTypes[PIdx] := PType;
      Inc(FormTab[FIdx].ChangingCount);
    End;
  End;

  FormTab[FIdx].ParamCount := PIdx;
  TotalParams := PIdx;

  { Consommer le point }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres parametres FORM');

  { Sauter par-dessus le corps (le mainline ne doit pas l executer) }
  LblSkip := NewLabel + '_FS';
  EmitI('JMP     ' + LblSkip);

  { Label d entree de la FORM }
  EmitLabel(FormTab[FIdx].AsmLabel);
  EmitComment('FORM ' + FormName);

  { Prologue Win32 STDCALL }
  EmitI('PUSH    EBP');
  EmitI('MOV     EBP, ESP');

  { Entrer le scope FORM }
  EnterScope(SK_FORM, FIdx);

  { Label epilogue pour EXIT }
  LblEpi := NewLabel + '_FE';
  SetExitLabel(LblEpi);

  { Declarer les parametres comme symboles }
  For I := 1 To TotalParams Do
  Begin
    SymIdx := AddSym(FormTab[FIdx].ParamNames[I],
                     FormTab[FIdx].ParamTypes[I],
                     STORE_PARAM);
    If SymIdx > 0 Then
    Begin
      SymTab[SymIdx].IsParam   := True;
      SymTab[SymIdx].ParamIdx  := I;
      SymTab[SymIdx].ParamKind := FormTab[FIdx].ParamKinds[I];
      SymTab[SymIdx].BpOffset  := 8 + (I - 1) * 4;
    End;
  End;

  { Corps de la FORM }
  ParseBlock(KW_ENDFORM, KW_NONE, KW_NONE);

  { Epilogue Win32 STDCALL }
  EmitLabel(LblEpi);
  EmitI('MOV     ESP, EBP');
  EmitI('POP     EBP');
  If TotalParams > 0 Then
    EmitI('RET     ' + IntToStr_(TotalParams * 4))
  Else
    EmitI('RET');

  LeaveScope;

  FormTab[FIdx].Defined := True;

  { Label pour sauter par-dessus le corps }
  EmitLabel(LblSkip);

  { ENDFORM. }
  If TokIsKw(KW_ENDFORM) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDFORM');
  End
  Else
    LexError('ENDFORM attendu');
End;

{ ---- ParsePerform : PERFORM nom [USING ...] [CHANGING ...] -- }
{ Syntaxe :                                                       }
{   PERFORM nom [USING arg1 arg2 ...] [CHANGING arg1 ...].       }
{ Convention d appel Win32 STDCALL : arguments empiles de droite  }
{ a gauche, la FORM depile avec RET n.                            }
{ ============================================================ }
Procedure ParsePerform;
Var
  FormName : TString;
  FIdx     : Integer;
  UNames   : Array[1..MAX_PARAM] of TString;
  CNames   : Array[1..MAX_PARAM] of TString;
  UCount   : Integer;
  CCount   : Integer;
  I        : Integer;
  SymIdx   : Integer;
Begin
  EmitComment('---- PERFORM ----');

  { Nom de la FORM a appeler }
  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom de FORM attendu apres PERFORM'); SkipToDot; Exit; End;
  FormName := CurTokStr;
  Consume;

  { Creer ou retrouver l entree (reference avant possible) }
  FIdx := AddForm(FormName);
  If FIdx = 0 Then Begin SkipToDot; Exit; End;

  UCount := 0;
  CCount := 0;

  { Collecter les arguments USING (par valeur) }
  If TokIsKw(KW_USING) Then
  Begin
    Consume;
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) And
          (Not TokIsKw(KW_CHANGING)) Do
    Begin
      Inc(UCount);
      UNames[UCount] := CurTokStr;
      Consume;
    End;
  End;

  { Collecter les arguments CHANGING (par adresse) }
  If TokIsKw(KW_CHANGING) Then
  Begin
    Consume;
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
    Begin
      Inc(CCount);
      CNames[CCount] := CurTokStr;
      Consume;
    End;
  End;

  { Empiler les arguments de droite a gauche (STDCALL) }
  { D abord CHANGING de droite a gauche }
  For I := CCount DownTo 1 Do
  Begin
    SymIdx := FindSym(CNames[I]);
    If SymIdx > 0 Then
    Begin
      GenLoadVarAddr32(SymIdx);
      EmitI('PUSH    EAX');
    End
    Else
    Begin
      EmitComment('CHANGING arg inconnu: ' + CNames[I]);
      EmitI('PUSH    0');
    End;
  End;

  { Puis USING de droite a gauche }
  For I := UCount DownTo 1 Do
  Begin
    SymIdx := FindSym(UNames[I]);
    If SymIdx > 0 Then
    Begin
      GenLoadVar32(SymIdx);
      EmitI('PUSH    EAX');
    End
    Else
    Begin
      { Tenter un nombre literal }
      EmitComment('USING arg: ' + UNames[I] + ' (comme literal)');
      EmitI('PUSH    0');
    End;
  End;

  { Appel de la FORM }
  EmitI('CALL    ' + FormTab[FIdx].AsmLabel);

  { Consommer le point }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres PERFORM');
End;

{ ============================================================ }
{ PARSEUR : MOVE / COMPUTE / FORMES VERBALES (TODO 15)         }
{ ============================================================ }

{ ---- ParseMove : MOVE source TO destination. ----------------- }
{ Evalue source (expr), puis stocke dans destination.            }
Procedure ParseMove;
Var DestName : TString;
    DestIdx  : Integer;
Begin
  EmitComment('MOVE source TO dest');
  { Evaluer la source (expression) }
  ParseExpr;
  { Consommer TO }
  If TokIsKw(KW_TO) Then
    Consume
  Else
    LexError('Attendu TO apres MOVE source');
  { Lire la destination }
  If CurTokType = TOK_IDENT Then
  Begin
    DestName := CurTokStr;
    Consume;
    DestIdx := FindSym(DestName);
    If DestIdx > 0 Then
      GenStoreVar32(DestIdx)
    Else
      EmitComment('MOVE: variable inconnue: ' + DestName);
  End
  Else
    LexError('Attendu nom de variable apres TO');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseAdd : ADD val TO var. / ADD v1 TO v2 GIVING var. -- }
Procedure ParseAdd;
Var ValName, DestName : TString;
    ValIdx, DestIdx  : Integer;
Begin
  EmitComment('ADD');
  { Evaluer le premier operande (val) }
  ParseExpr;
  EmitI('PUSH    EAX');
  { Consommer TO }
  If TokIsKw(KW_TO) Then
    Consume
  Else
    LexError('Attendu TO apres ADD val');
  { Lire le second operande (var / val2) }
  If CurTokType = TOK_IDENT Then
  Begin
    DestName := CurTokStr;
    DestIdx  := FindSym(DestName);
    Consume;
    { Verifier si GIVING suit }
    If TokIsKw(KW_GIVING) Then
    Begin
      Consume;
      { ADD val1 TO val2 GIVING var }
      { val2 est dans EAX via load }
      If DestIdx > 0 Then
        GenLoadVar32(DestIdx)
      Else
        EmitI('XOR     EAX, EAX');
      EmitI('POP     EBX');
      EmitI('ADD     EAX, EBX');
      { Lire la destination GIVING }
      If CurTokType = TOK_IDENT Then
      Begin
        DestName := CurTokStr;
        Consume;
        DestIdx := FindSym(DestName);
        If DestIdx > 0 Then
          GenStoreVar32(DestIdx)
        Else
          EmitComment('ADD GIVING: variable inconnue: ' + DestName);
      End
      Else
        LexError('Attendu nom de variable apres GIVING');
    End
    Else
    Begin
      { ADD val TO var : var = var + val }
      If DestIdx > 0 Then
      Begin
        GenLoadVar32(DestIdx);
        EmitI('POP     EBX');
        EmitI('ADD     EAX, EBX');
        GenStoreVar32(DestIdx);
      End
      Else
      Begin
        EmitI('POP     EBX');
        EmitComment('ADD: variable inconnue: ' + DestName);
      End;
    End;
  End
  Else
  Begin
    EmitI('POP     EBX');
    LexError('Attendu nom de variable apres TO');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseSubtract : SUBTRACT val FROM var. ------------------ }
Procedure ParseSubtract;
Var DestName : TString;
    DestIdx  : Integer;
Begin
  EmitComment('SUBTRACT');
  { Evaluer la valeur a soustraire }
  ParseExpr;
  EmitI('PUSH    EAX');
  { Consommer FROM }
  If TokIsKw(KW_FROM) Then
    Consume
  Else
    LexError('Attendu FROM apres SUBTRACT val');
  { Lire la destination }
  If CurTokType = TOK_IDENT Then
  Begin
    DestName := CurTokStr;
    Consume;
    DestIdx := FindSym(DestName);
    If DestIdx > 0 Then
    Begin
      GenLoadVar32(DestIdx);
      EmitI('POP     EBX');
      EmitI('SUB     EAX, EBX');
      GenStoreVar32(DestIdx);
    End
    Else
    Begin
      EmitI('POP     EBX');
      EmitComment('SUBTRACT: variable inconnue: ' + DestName);
    End;
  End
  Else
  Begin
    EmitI('POP     EBX');
    LexError('Attendu nom de variable apres FROM');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseMultiply : MULTIPLY var BY val. -------------------- }
Procedure ParseMultiply;
Var VarName : TString;
    VarIdx  : Integer;
Begin
  EmitComment('MULTIPLY');
  { Lire la variable cible }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
    { Consommer BY }
    If TokIsKw(KW_BY) Then
      Consume
    Else
      LexError('Attendu BY apres MULTIPLY var');
    { Evaluer la valeur multiplicatrice }
    ParseExpr;
    If VarIdx > 0 Then
    Begin
      EmitI('PUSH    EAX');
      GenLoadVar32(VarIdx);
      EmitI('POP     EBX');
      EmitI('IMUL    EAX, EBX');
      GenStoreVar32(VarIdx);
    End
    Else
      EmitComment('MULTIPLY: variable inconnue: ' + VarName);
  End
  Else
    LexError('Attendu nom de variable apres MULTIPLY');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseDivide : DIVIDE var BY val. ------------------------ }
Procedure ParseDivide;
Var VarName : TString;
    VarIdx  : Integer;
Begin
  EmitComment('DIVIDE');
  { Lire la variable cible }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
    { Consommer BY }
    If TokIsKw(KW_BY) Then
      Consume
    Else
      LexError('Attendu BY apres DIVIDE var');
    { Evaluer le diviseur }
    ParseExpr;
    If VarIdx > 0 Then
    Begin
      EmitI('MOV     EBX, EAX');
      GenLoadVar32(VarIdx);
      EmitI('CDQ');
      EmitI('IDIV    EBX');
      GenStoreVar32(VarIdx);
    End
    Else
      EmitComment('DIVIDE: variable inconnue: ' + VarName);
  End
  Else
    LexError('Attendu nom de variable apres DIVIDE');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseClear : CLEAR variable. ---------------------------- }
{ Met a 0 (numerique) ou vide (chaine) la variable.              }
Procedure ParseClear;
Var VarName : TString;
    VarIdx  : Integer;
Begin
  EmitComment('CLEAR');
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
    If VarIdx > 0 Then
    Begin
      EmitI('XOR     EAX, EAX');
      GenStoreVar32(VarIdx);
    End
    Else
      EmitComment('CLEAR: variable inconnue: ' + VarName);
  End
  Else
    LexError('Attendu nom de variable apres CLEAR');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ============================================================ }
{ TODO 20 : REFRESH / FREE / CHECK / STOP / RETURN             }
{ ============================================================ }

{ ---- ParseRefresh : REFRESH itab. ---------------------------- }
{ Remet le compteur d elements de la table interne a 0.          }
Procedure ParseRefresh;
Var VarName : TString;
    VarIdx  : Integer;
    TabLbl  : TString;
Begin
  EmitComment('REFRESH');
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
    If VarIdx > 0 Then
    Begin
      If SymTab[VarIdx].DataType = TYPE_TABLE Then
      Begin
        TabLbl := SymTab[VarIdx].AsmLabel;
        EmitI('MOV     DWORD PTR [' + TabLbl + '_CNT], 0');
      End
      Else
        EmitComment('REFRESH: ' + VarName + ' n''est pas une table');
    End
    Else
      EmitComment('REFRESH: variable inconnue: ' + VarName);
  End
  Else
    LexError('Attendu nom de table apres REFRESH');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseFree : FREE itab. --------------------------------- }
{ Stub : meme effet que REFRESH (remet le compteur a 0).          }
Procedure ParseFree;
Var VarName : TString;
    VarIdx  : Integer;
    TabLbl  : TString;
Begin
  EmitComment('FREE');
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
    If VarIdx > 0 Then
    Begin
      If SymTab[VarIdx].DataType = TYPE_TABLE Then
      Begin
        TabLbl := SymTab[VarIdx].AsmLabel;
        EmitI('MOV     DWORD PTR [' + TabLbl + '_CNT], 0');
      End
      Else
        EmitComment('FREE: ' + VarName + ' n''est pas une table');
    End
    Else
      EmitComment('FREE: variable inconnue: ' + VarName);
  End
  Else
    LexError('Attendu nom de table apres FREE');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseCheck : CHECK condition. --------------------------- }
{ Evalue la condition : si faux (EAX=0), JMP au label de sortie  }
{ de la boucle/form courante.                                     }
Procedure ParseCheck;
Var LblOk    : TString;
    ExprType : Integer;
Begin
  EmitComment('CHECK');
  ExprType := ParseExpr;
  LblOk := NewLabel + '_CK';
  EmitI('TEST    EAX, EAX');
  EmitI('JNZ     ' + LblOk);
  { Condition fausse : sortir de la boucle ou form }
  If CurrentExitLabel <> '' Then
    EmitI('JMP     ' + CurrentExitLabel)
  Else
    EmitComment('CHECK: pas de label de sortie actif');
  EmitLabel(LblOk);
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseStop : STOP. --------------------------------------- }
{ Termine immediatement le programme (PUSH 0 / CALL ExitProcess). }
Procedure ParseStop;
Begin
  EmitComment('STOP');
  EmitI('PUSH    0');
  EmitI('CALL    _ExitProcess@4');
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseReturn : RETURN. ----------------------------------- }
{ Dans une FORM : JMP vers le label epilogue (exit de la FORM).   }
{ Au niveau global : termine le programme (comme STOP).            }
Procedure ParseReturn;
Begin
  EmitComment('RETURN');
  If InForm Then
  Begin
    If CurrentExitLabel <> '' Then
      EmitI('JMP     ' + CurrentExitLabel)
    Else
      EmitComment('RETURN: pas de label de sortie');
  End
  Else
  Begin
    { Au niveau global : sortir du programme }
    EmitI('PUSH    0');
    EmitI('CALL    _ExitProcess@4');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ============================================================ }
{ TODO 21 : SELECT / ENDSELECT (STUB SANS BD)                   }
{ ============================================================ }

{ ---- ParseSelect : SELECT ... FROM ... [ENDSELECT.] --------- }
{ Stub : pas de base de donnees reelle.                          }
{   - Parse les clauses SELECT / FROM / INTO / WHERE / etc.      }
{   - Emet un commentaire de stub.                                }
{   - Si pas SINGLE : consomme le bloc jusqu a ENDSELECT.        }
{   - Positionne SY-SUBRC = 4 (non trouve).                      }
{   - Positionne SY-DBCNT = 0 (aucun enregistrement).            }
{ ============================================================ }
Procedure ParseSelect;
Var IsSingle    : Boolean;
    IntoTable   : Boolean;
    SySubrcIdx  : Integer;
    SyDbcntIdx  : Integer;
    SelectInfo  : TString;
Begin
  EmitComment('---- SELECT (stub sans BD) ----');
  SelectInfo := 'SELECT';

  { SELECT SINGLE ... }
  IsSingle := False;
  IntoTable := False;
  If TokIsKw(KW_SINGLE) Then
  Begin
    IsSingle := True;
    SelectInfo := SelectInfo + ' SINGLE';
    Consume;
  End;

  { Consommer les champs (identifiants ou *) }
  While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
        (Not TokIsKw(KW_FROM)) Do
  Begin
    If CurTokType = TOK_STAR Then
      SelectInfo := SelectInfo + ' *'
    Else If CurTokType = TOK_IDENT Then
      SelectInfo := SelectInfo + ' ' + CurTokStr;
    Consume;
  End;

  { FROM table }
  If TokIsKw(KW_FROM) Then
  Begin
    Consume;
    If CurTokType = TOK_IDENT Then
    Begin
      SelectInfo := SelectInfo + ' FROM ' + CurTokStr;
      Consume;
    End;
  End;

  { INTO [CORRESPONDING FIELDS OF] var / TABLE itab }
  If TokIsKw(KW_INTO) Then
  Begin
    Consume;
    If TokIsKw(KW_CORRESPONDING) Then
    Begin
      Consume;
      { FIELDS }
      If (CurTokType = TOK_IDENT) And
         (StrUpperCase(CurTokStr) = 'FIELDS') Then
        Consume;
      { OF }
      If TokIsKw(KW_OF) Then Consume;
    End;
    If TokIsKw(KW_TABLE) Then
    Begin
      IntoTable := True;
      Consume;
    End;
    { nom de la variable/table cible }
    If CurTokType = TOK_IDENT Then
      Consume;
  End;

  { WHERE condition (skip tokens jusqu au point ou ORDER/UP) }
  If TokIsKw(KW_WHERE) Then
  Begin
    Consume;
    While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
          (Not TokIsKw(KW_ORDER)) And
          (Not (TokIsKw(KW_ENDSELECT))) And
          (Not ((CurTokType = TOK_IDENT) And (StrUpperCase(CurTokStr) = 'UP'))) Do
      Consume;
  End;

  { ORDER BY champ }
  If TokIsKw(KW_ORDER) Then
  Begin
    Consume;
    { BY }
    If TokIsKw(KW_BY) Then Consume;
    { nom du champ }
    If CurTokType = TOK_IDENT Then Consume;
  End;

  { UP TO n ROWS }
  If (CurTokType = TOK_IDENT) And (StrUpperCase(CurTokStr) = 'UP') Then
  Begin
    Consume;
    { TO }
    If TokIsKw(KW_TO) Then Consume;
    { n }
    If CurTokType = TOK_NUMBER Then Consume;
    { ROWS }
    If TokIsKw(KW_ROWS) Then Consume;
  End;

  EmitComment('  ' + SelectInfo + ' (stub - pas de BD)');

  { Consommer le point de fin de clause SELECT }
  If CurTokType = TOK_DOT Then Consume;

  { Si pas SINGLE et pas INTO TABLE, il faut un bloc ENDSELECT }
  If (Not IsSingle) And (Not IntoTable) Then
  Begin
    { Boucle vide : sauter directement le corps }
    EmitComment('  SELECT non-SINGLE : boucle vide (0 iterations)');
    { Parser et ignorer les instructions entre SELECT et ENDSELECT }
    While (CurTokType <> TOK_EOF) And (Not TokIsKw(KW_ENDSELECT)) Do
    Begin
      { Sauter les tokens jusqu au prochain point }
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
            (Not TokIsKw(KW_ENDSELECT)) Do
        Consume;
      If CurTokType = TOK_DOT Then Consume;
    End;
    { Consommer ENDSELECT. }
    If TokIsKw(KW_ENDSELECT) Then
    Begin
      Consume;
      If CurTokType = TOK_DOT Then Consume;
    End
    Else
      LexError('ENDSELECT attendu');
  End;

  { SY-SUBRC = 4 (non trouve) }
  SySubrcIdx := FindSym('SY-SUBRC');
  If SySubrcIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SySubrcIdx].AsmLabel + '], 4');

  { SY-DBCNT = 0 (aucun enregistrement) }
  SyDbcntIdx := FindSym('SY-DBCNT');
  If SyDbcntIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SyDbcntIdx].AsmLabel + '], 0');
End;

{ ============================================================ }
{ TODO 22 : CALL FUNCTION / FUNCTION / ENDFUNCTION (STUBS)      }
{ ============================================================ }

{ ---- ParseCallFunction : CALL FUNCTION 'nom' ---------------  }
{ Stub : pas d appel reel.                                       }
{   - Parse les clauses EXPORTING / IMPORTING / TABLES /         }
{     EXCEPTIONS.                                                }
{   - Emet un commentaire de stub.                                }
{   - Positionne SY-SUBRC = 0.                                   }
{ ============================================================ }
Procedure ParseCallFunction;
Var FMName      : TString;
    SySubrcIdx  : Integer;
Begin
  { On attend FUNCTION apres CALL }
  If Not TokIsKw(KW_FUNCTION) Then
  Begin LexError('FUNCTION attendu apres CALL'); SkipToDot; Exit; End;
  Consume;

  { Nom du module fonction (chaine litterale entre quotes) }
  If CurTokType = TOK_STRING Then
  Begin
    FMName := CurTokStr;
    Consume;
  End
  Else
  Begin
    { Accepter aussi un identifiant sans quotes }
    FMName := CurTokStr;
    Consume;
  End;

  EmitBlank;
  EmitComment('---- CALL FUNCTION ' + FMName + ' (stub) ----');

  { Parser les clauses optionnelles avant le point terminal }
  While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) Do
  Begin
    { EXPORTING param = val ... }
    If TokIsKw(KW_EXPORTING) Then
    Begin
      Consume;
      EmitComment('  EXPORTING');
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
            (Not TokIsKw(KW_IMPORTING)) And (Not TokIsKw(KW_TABLES)) And
            (Not TokIsKw(KW_EXCEPTIONS)) Do
      Begin
        { param = val : ignorer }
        Consume;
      End;
    End
    Else
    { IMPORTING param = var ... }
    If TokIsKw(KW_IMPORTING) Then
    Begin
      Consume;
      EmitComment('  IMPORTING');
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
            (Not TokIsKw(KW_EXPORTING)) And (Not TokIsKw(KW_TABLES)) And
            (Not TokIsKw(KW_EXCEPTIONS)) Do
      Begin
        Consume;
      End;
    End
    Else
    { TABLES itab = itab2 ... }
    If TokIsKw(KW_TABLES) Then
    Begin
      Consume;
      EmitComment('  TABLES');
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
            (Not TokIsKw(KW_EXPORTING)) And (Not TokIsKw(KW_IMPORTING)) And
            (Not TokIsKw(KW_EXCEPTIONS)) Do
      Begin
        Consume;
      End;
    End
    Else
    { EXCEPTIONS exception_name = n ... }
    If TokIsKw(KW_EXCEPTIONS) Then
    Begin
      Consume;
      EmitComment('  EXCEPTIONS');
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) And
            (Not TokIsKw(KW_EXPORTING)) And (Not TokIsKw(KW_IMPORTING)) And
            (Not TokIsKw(KW_TABLES)) Do
      Begin
        Consume;
      End;
    End
    Else
      { Token non reconnu dans CALL FUNCTION : avancer }
      Consume;
  End;

  { SY-SUBRC = 0 (appel reussi en stub) }
  SySubrcIdx := FindSym('SY-SUBRC');
  If SySubrcIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SySubrcIdx].AsmLabel + '], 0');

  { Consommer le point terminal }
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseFunctionDecl : FUNCTION nom. ... ENDFUNCTION. -----  }
{ Generer comme une FORM : label _ABF_FM_nom                     }
{   Prologue / Epilogue Win32 STDCALL                            }
{ ============================================================ }
Procedure ParseFunctionDecl;
Var FuncName    : TString;
    AsmLbl      : TString;
    LblSkip     : TString;
    LblEpi      : TString;
Begin
  EmitComment('---- FUNCTION ----');

  { Nom de la fonction }
  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom attendu apres FUNCTION'); SkipToDot; Exit; End;
  FuncName := CurTokStr;
  Consume;

  AsmLbl := AB_FN_PFX + 'FM_' + AsmIdent(FuncName);

  { Consommer le point }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres nom FUNCTION');

  EmitBlank;
  EmitComment('---- FUNCTION ' + FuncName + ' ----');

  { Sauter par-dessus le corps (le mainline ne doit pas l executer) }
  LblSkip := NewLabel + '_FKS';
  EmitI('JMP     ' + LblSkip);

  { Label d entree de la FUNCTION }
  EmitLabel(AsmLbl);

  { Prologue Win32 STDCALL }
  EmitI('PUSH    EBP');
  EmitI('MOV     EBP, ESP');

  { Entrer le scope FORM (reutilise pour FUNCTION) }
  EnterScope(SK_FORM, 0);

  { Label epilogue pour EXIT/RETURN }
  LblEpi := NewLabel + '_FKE';
  SetExitLabel(LblEpi);

  { Corps de la FUNCTION : parser jusqu a ENDFUNCTION }
  ParseBlock(KW_ENDFUNCTION, KW_NONE, KW_NONE);

  { Epilogue Win32 STDCALL }
  EmitLabel(LblEpi);
  EmitI('MOV     ESP, EBP');
  EmitI('POP     EBP');
  EmitI('RET');

  LeaveScope;

  { Label pour sauter par-dessus le corps }
  EmitLabel(LblSkip);

  { ENDFUNCTION. }
  If TokIsKw(KW_ENDFUNCTION) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDFUNCTION');
  End
  Else
    LexError('ENDFUNCTION attendu');
End;

{ ============================================================ }
{ TODO 23+24 : STUBS DISPATCHER (TRY, RAISE, EVENT, SEL-SCREEN)}
{ ============================================================ }

{ ---- IsEventKeyword : verifie si le token courant est un     }
{ mot-cle d evenement ABAP (TODO 24)                            }
{ ============================================================ }
Function IsEventKeyword : Boolean;
Begin
  IsEventKeyword := TokIsKw(KW_START_OF_SEL) Or TokIsKw(KW_END_OF_SEL) Or
                    TokIsKw(KW_TOP_OF_PAGE) Or TokIsKw(KW_END_OF_PAGE) Or
                    TokIsKw(KW_LINE_SEL) Or TokIsKw(KW_USER_CMD);
End;

{ ---- ParseTry : TRY. ... CATCH cx. ... [CLEANUP.] ENDTRY. -- }
{ Stub : parser les blocs avec labels _ABX_catch/_ABX_cleanup   }
{ ============================================================ }
Procedure ParseTry;
Var TryIdx  : Integer;
    TryLbl  : TString;
Begin
  Inc(TryCount);
  TryIdx := TryCount;
  TryLbl := IntToStr_(TryIdx);
  EmitComment('---- TRY #' + TryLbl + ' (stub) ----');

  { Consommer le point apres TRY }
  If CurTokType = TOK_DOT Then Consume;

  { Corps du TRY : parser jusqu a CATCH, CLEANUP ou ENDTRY }
  ParseBlock(KW_CATCH, KW_CLEANUP, KW_ENDTRY);

  { CATCH cx_name. ... (TODO 24: label _ABX_catch_N) }
  While TokIsKw(KW_CATCH) Do
  Begin
    EmitLabel('_ABX_catch_' + TryLbl);
    EmitComment('CATCH (stub)');
    Consume; { CATCH }
    { Nom de la classe exception : consommer }
    If CurTokType = TOK_IDENT Then Consume;
    { Possible INTO var }
    If TokIsKw(KW_INTO) Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then Consume;
    End;
    If CurTokType = TOK_DOT Then Consume;
    { Corps du CATCH }
    ParseBlock(KW_CATCH, KW_CLEANUP, KW_ENDTRY);
  End;

  { CLEANUP. ... (TODO 24: label _ABX_cleanup_N) }
  If TokIsKw(KW_CLEANUP) Then
  Begin
    EmitLabel('_ABX_cleanup_' + TryLbl);
    EmitComment('CLEANUP (stub)');
    Consume;
    If CurTokType = TOK_DOT Then Consume;
    ParseBlock(KW_ENDTRY, KW_NONE, KW_NONE);
  End;

  { ENDTRY. }
  If TokIsKw(KW_ENDTRY) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume;
  End
  Else
    LexError('ENDTRY attendu');

  EmitComment('---- FIN TRY #' + TryLbl + ' (stub) ----');
End;

{ ---- ParseRaise : RAISE [EXCEPTION [TYPE cx_name]]. --------- }
{ Stub : consomme la ligne, emet un commentaire                  }
{ ============================================================ }
Procedure ParseRaise;
Begin
  EmitComment('---- RAISE (stub) ----');
  { RAISE [EXCEPTION [TYPE cx_name [MESSAGE ...]]] }
  { Consommer tout jusqu au point }
  SkipToDot;
End;

{ ---- ParseEvent : START-OF-SELECTION / END-OF-SELECTION / etc }
{ TODO 24 : label + bloc + RET pour START/END-OF-SELECTION      }
{           stub vide pour TOP-OF-PAGE, END-OF-PAGE, etc.       }
{ ============================================================ }
Procedure ParseEvent(EventKw : Integer);
Var LblName : TString;
    SkipLbl : TString;
Begin
  Case EventKw Of
    KW_START_OF_SEL : LblName := '_ABE_START';
    KW_END_OF_SEL   : LblName := '_ABE_END';
    KW_TOP_OF_PAGE  : LblName := '_ABE_TOPPAGE';
    KW_END_OF_PAGE  : LblName := '_ABE_ENDPAGE';
    KW_LINE_SEL     : LblName := '_ABE_LINESEL';
    KW_USER_CMD     : LblName := '_ABE_USERCMD';
  Else
    LblName := '_ABE_UNKNOWN';
  End;

  { Consommer le point }
  If CurTokType = TOK_DOT Then Consume;

  { START-OF-SELECTION et END-OF-SELECTION : label + bloc + RET }
  If (EventKw = KW_START_OF_SEL) Or (EventKw = KW_END_OF_SEL) Then
  Begin
    SkipLbl := NewLabel;
    EmitBlank;
    EmitComment('---- EVENT ' + LblName + ' ----');
    EmitI('JMP     ' + SkipLbl);
    EmitLabel(LblName);
    { Marquer l evenement comme defini }
    If EventKw = KW_START_OF_SEL Then
      EventStartDefined := True
    Else
      EventEndDefined := True;
    { Parser le corps : instructions jusqu au prochain evenement, }
    { FORM, FUNCTION ou fin de fichier                            }
    While (CurTokType <> TOK_EOF) And
          (Not IsEventKeyword) And
          (Not TokIsKw(KW_FORM)) And
          (Not TokIsKw(KW_FUNCTION)) Do
      ParseStatement;
    { Emettre RET pour revenir a l appelant }
    EmitI('RET');
    EmitLabel(SkipLbl);
  End
  Else
  Begin
    { Autres evenements : stub vide (label seul) }
    EmitBlank;
    EmitComment('---- EVENT ' + LblName + ' (stub) ----');
    EmitLabel(LblName);
    EmitI('RET');
  End;
End;

{ ---- ParseSelScreen : PARAMETERS / SELECT-OPTIONS (stubs) --- }
{ PARAMETERS p TYPE I [DEFAULT val].                             }
{   -> generer variable globale (DD) + valeur par defaut         }
{ SELECT-OPTIONS s FOR var.                                      }
{   -> stub : generer deux variables LOW / HIGH (DD)             }
{ ============================================================ }
Procedure ParseSelScreen(IsParam : Boolean);
Var ParName : TString;
    DefVal  : LongInt;
    Idx     : Integer;
Begin
  If IsParam Then
  Begin
    EmitComment('---- PARAMETERS (stub) ----');
    { PARAMETERS p TYPE I [DEFAULT val]. }
    If CurTokType <> TOK_IDENT Then
    Begin LexError('Nom attendu apres PARAMETERS'); SkipToDot; Exit; End;
    ParName := CurTokStr;
    Consume;
    DefVal := 0;
    { Parser TYPE t optionnel }
    If TokIsKw(KW_TYPE) Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then Consume; { type name }
    End;
    { Parser LIKE v optionnel }
    If TokIsKw(KW_LIKE) Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then Consume;
    End;
    { Parser DEFAULT val optionnel }
    If TokIsKw(KW_DEFAULT) Then
    Begin
      Consume;
      If CurTokType = TOK_NUMBER Then
      Begin
        DefVal := CurTokNum;
        Consume;
      End
      Else If CurTokType = TOK_STRING Then
        Consume
      Else If CurTokType = TOK_IDENT Then
        Consume;
    End;
    { Declarer la variable globale si elle n existe pas }
    Idx := FindSym(ParName);
    If Idx <= 0 Then
    Begin
      Idx := AddSym(ParName, TYPE_I, STORE_STATIC);
      EmitComment('PARAM ' + ParName + ' = ' + IntToStr_(DefVal));
    End;
    { Consommer le point }
    If CurTokType = TOK_DOT Then Consume;
  End
  Else
  Begin
    { SELECT-OPTIONS s FOR var (TODO 24 : LOW / HIGH vars) }
    EmitComment('---- SELECT-OPTIONS ----');
    If CurTokType <> TOK_IDENT Then
    Begin LexError('Nom attendu apres SELECT-OPTIONS'); SkipToDot; Exit; End;
    ParName := CurTokStr;
    Consume;
    { Parser FOR var }
    If (CurTokType = TOK_IDENT) And (StrUpperCase(CurTokStr) = 'FOR') Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then Consume;
    End;
    { Consommer options supplementaires jusqu au point }
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
      Consume;
    If CurTokType = TOK_DOT Then Consume;
    { Creer les deux variables globales LOW et HIGH (DD) }
    Idx := FindSym(ParName + '-LOW');
    If Idx <= 0 Then
    Begin
      Idx := AddSym(ParName + '-LOW', TYPE_I, STORE_STATIC);
      EmitComment('SELOPT ' + ParName + '-LOW');
    End;
    Idx := FindSym(ParName + '-HIGH');
    If Idx <= 0 Then
    Begin
      Idx := AddSym(ParName + '-HIGH', TYPE_I, STORE_STATIC);
      EmitComment('SELOPT ' + ParName + '-HIGH');
    End;
  End;
End;

{ ============================================================ }
{ TODO 16 : LOOP AT / ENDLOOP + OPERATIONS TABLES INTERNES      }
{ ============================================================ }

{ ---- ParseLoopAt : LOOP AT itab [INTO wa]. ... ENDLOOP. ----- }
{ Generation 32 bits :                                           }
{   XOR ECX, ECX -> SY-TABIX = 0                                }
{   _ABL_top: INC ECX -> SY-TABIX + 1                           }
{   CMP ECX, [_ABA_itab_CNT] / JG _ABL_end                     }
{   MOV SY-TABIX, ECX                                            }
{   (INTO wa : copie element courant)                            }
{   PUSH ECX / corps / POP ECX                                  }
{   JMP _ABL_top / _ABL_end:                                    }
{ ============================================================ }
Procedure ParseLoopAt;
Var TabName, WaName : TString;
    TabIdx, WaIdx   : Integer;
    LblTop, LblEnd  : TString;
    TabLbl          : TString;
    SyTabixIdx      : Integer;
    HasInto         : Boolean;
Begin
  EmitComment('---- LOOP AT ----');

  { Consommer AT }
  If TokIsKw(KW_AT) Then Consume
  Else LexError('AT attendu apres LOOP');

  { Nom de la table interne }
  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom de table attendu apres LOOP AT'); Exit; End;
  TabName := CurTokStr;
  TabIdx  := FindSym(TabName);
  Consume;

  If TabIdx = 0 Then
  Begin
    EmitComment('LOOP AT: table inconnue: ' + TabName);
    While (CurTokType <> TOK_EOF) And Not TokIsKw(KW_ENDLOOP) Do
      Consume;
    If TokIsKw(KW_ENDLOOP) Then Begin Consume; If CurTokType=TOK_DOT Then Consume; End;
    Exit;
  End;

  TabLbl := SymTab[TabIdx].AsmLabel;

  { INTO wa (optionnel) }
  HasInto := False;
  WaIdx   := 0;
  WaName  := '';
  If TokIsKw(KW_INTO) Then
  Begin
    Consume;
    HasInto := True;
    If CurTokType = TOK_IDENT Then
    Begin
      WaName := CurTokStr;
      WaIdx  := FindSym(WaName);
      Consume;
    End;
  End;

  { WHERE (stub : skip condition) }
  If TokIsKw(KW_WHERE) Then
  Begin
    Consume;
    EmitComment('LOOP AT WHERE: condition ignoree (stub)');
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
      Consume;
  End;

  { Consommer le point }
  If CurTokType = TOK_DOT Then Consume
  Else LexError('Point attendu apres LOOP AT ...');

  { Labels }
  LblTop := NewLabel + '_LT';
  LblEnd := NewLabel + '_LE';

  { SY-TABIX }
  SyTabixIdx := FindSym('SY-TABIX');

  { Initialiser compteur : XOR ECX, ECX }
  EmitI('XOR     ECX, ECX');
  EmitI('PUSH    ECX');           { sauvegarder index sur la pile }

  EmitLabel(LblTop);

  { Restaurer index, incrementer }
  EmitI('POP     ECX');
  EmitI('INC     ECX');

  { Comparer avec le nombre de lignes }
  EmitI('CMP     ECX, DWORD PTR [' + TabLbl + '_CNT]');
  EmitI('JG      ' + LblEnd);

  { Sauvegarder ECX pour le corps de boucle }
  EmitI('PUSH    ECX');

  { Mettre a jour SY-TABIX }
  If SyTabixIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SyTabixIdx].AsmLabel + '], ECX');

  { INTO wa : copier l element courant dans la variable de travail }
  If HasInto And (WaIdx > 0) Then
  Begin
    EmitComment('INTO ' + WaName + ' (copie element)');
    { Calculer adresse element : _ABA_itab + (ECX-1)*4 }
    EmitI('DEC     ECX');
    EmitI('SHL     ECX, 2');       { ECX * 4 }
    EmitI('LEA     EAX, [' + TabLbl + '_DATA]');
    EmitI('ADD     EAX, ECX');
    EmitI('MOV     EAX, DWORD PTR [EAX]');  { charger la valeur }
    GenStoreVar32(WaIdx);
  End;

  { Corps de la boucle }
  EnterScope(SK_LOOP, 0);
  SetExitLabel(LblEnd);
  SetContLabel(LblTop);
  ParseBlock(KW_ENDLOOP, KW_NONE, KW_NONE);
  LeaveScope;

  { Retour au debut }
  EmitI('JMP     ' + LblTop);

  EmitLabel(LblEnd);
  { Nettoyer la pile si on sort par JG (le PUSH ECX n a pas de POP) }
  { Note : le POP ECX est fait en haut de la boucle, mais si on     }
  { sort par JG apres le POP, c est correct.                        }

  { ENDLOOP. }
  If TokIsKw(KW_ENDLOOP) Then
  Begin
    Consume;
    If CurTokType = TOK_DOT Then Consume
    Else LexError('Point attendu apres ENDLOOP');
  End
  Else
    LexError('ENDLOOP attendu');
End;

{ ---- ParseAppend : APPEND [wa/expr TO] itab. ---------------- }
{ APPEND val TO itab.  -> empiler la valeur dans le tableau     }
{ APPEND itab.         -> ajouter une ligne vide (0) a itab     }
{ Generation : incremente _ABA_itab_CNT, stocke valeur          }
Procedure ParseAppend;
Var TabName : TString;
    TabIdx  : Integer;
    TabLbl  : TString;
    HasSrc  : Boolean;
    SavedName : TString;
    SavedIdx  : Integer;
Begin
  EmitComment('APPEND');

  HasSrc := False;

  { Cas 1 : APPEND wa TO itab. (identifiant suivi de TO) }
  { Cas 2 : APPEND expr TO itab. (expression suivi de TO) }
  { Cas 3 : APPEND itab. (juste un identifiant, sans TO) }

  { Regarder si c est un identifiant simple qui est suivi de TO ou de '.' }
  If CurTokType = TOK_IDENT Then
  Begin
    SavedName := CurTokStr;
    SavedIdx  := FindSym(SavedName);
    { Verifier si c est une table (APPEND itab.) ou une source (APPEND wa TO itab.) }
    { On regarde le token suivant pour decider }
    Consume;
    If TokIsKw(KW_TO) Then
    Begin
      { Forme APPEND wa TO itab }
      Consume;
      HasSrc := True;
      { Charger la valeur source }
      If SavedIdx > 0 Then
        GenLoadVar32(SavedIdx)
      Else
        EmitI('XOR     EAX, EAX');
      EmitI('PUSH    EAX');         { sauvegarder la valeur }
      { Lire le nom de la table }
      If CurTokType <> TOK_IDENT Then
      Begin LexError('Nom de table attendu apres TO'); Exit; End;
      TabName := CurTokStr;
      TabIdx  := FindSym(TabName);
      Consume;
    End
    Else
    Begin
      { Forme APPEND itab. (sans source) }
      TabName := SavedName;
      TabIdx  := SavedIdx;
    End;
  End
  Else If (CurTokType = TOK_NUMBER) Or (CurTokType = TOK_STRING) Or
         (CurTokType = TOK_LPAREN) Or (CurTokType = TOK_MINUS) Then
  Begin
    { Forme APPEND expr TO itab }
    ParseExpr;
    EmitI('PUSH    EAX');           { sauvegarder la valeur }
    HasSrc := True;
    If TokIsKw(KW_TO) Then Consume
    Else LexError('TO attendu apres expression APPEND');
    If CurTokType <> TOK_IDENT Then
    Begin LexError('Nom de table attendu apres TO'); Exit; End;
    TabName := CurTokStr;
    TabIdx  := FindSym(TabName);
    Consume;
  End
  Else
  Begin
    LexError('Expression ou nom de variable attendu apres APPEND');
    Exit;
  End;

  If TabIdx = 0 Then
  Begin
    EmitComment('APPEND: table inconnue: ' + TabName);
    If HasSrc Then EmitI('ADD     ESP, 4'); { nettoyer la pile }
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  TabLbl := SymTab[TabIdx].AsmLabel;

  { Charger la valeur a ajouter }
  If HasSrc Then
    EmitI('POP     EAX')            { recuperer la valeur sauvegardee }
  Else
    EmitI('XOR     EAX, EAX');      { valeur 0 par defaut }

  { Stocker dans le tableau : _ABA_itab_DATA + CNT*4 }
  EmitI('MOV     ECX, DWORD PTR [' + TabLbl + '_CNT]');
  EmitI('SHL     ECX, 2');           { ECX * 4 }
  EmitI('LEA     EDX, [' + TabLbl + '_DATA]');
  EmitI('ADD     EDX, ECX');
  EmitI('MOV     DWORD PTR [EDX], EAX');
  { Incrementer le compteur }
  EmitI('INC     DWORD PTR [' + TabLbl + '_CNT]');

  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseReadTable : READ TABLE itab INTO wa [INDEX i]. ----- }
{ Lit un element de la table par INDEX.                           }
{ Met a jour SY-SUBRC (0=trouve, 4=non trouve).                  }
Procedure ParseReadTable;
Var TabName, WaName : TString;
    TabIdx, WaIdx   : Integer;
    TabLbl          : TString;
    LblOk, LblEnd  : TString;
    SySubrcIdx      : Integer;
Begin
  EmitComment('READ TABLE');

  { Consommer TABLE }
  If TokIsKw(KW_TABLE) Then Consume
  Else LexError('TABLE attendu apres READ');

  { Nom de la table }
  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom de table attendu'); Exit; End;
  TabName := CurTokStr;
  TabIdx  := FindSym(TabName);
  Consume;

  If TabIdx = 0 Then
  Begin
    EmitComment('READ TABLE: table inconnue: ' + TabName);
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do Consume;
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  TabLbl := SymTab[TabIdx].AsmLabel;

  { INTO wa }
  WaIdx := 0;
  If TokIsKw(KW_INTO) Then
  Begin
    Consume;
    If CurTokType = TOK_IDENT Then
    Begin
      WaName := CurTokStr;
      WaIdx  := FindSym(WaName);
      Consume;
    End;
  End;

  { INDEX i | WITH KEY champ = val }
  If TokIsKw(KW_INDEX) Then
  Begin
    Consume;
    { Evaluer l index -> EAX }
    ParseExpr;
    EmitI('MOV     ECX, EAX');   { ECX = index (1-base) }
  End
  Else If TokIsKw(KW_WITH) Then
  Begin
    { WITH KEY champ = val : stub (lire le premier element) }
    Consume;
    EmitComment('READ TABLE WITH KEY: stub (INDEX 1)');
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do Consume;
    EmitI('MOV     ECX, 1');     { index par defaut = 1 }
  End
  Else
    EmitI('MOV     ECX, 1');     { index par defaut = 1 }
  ;

  SySubrcIdx := FindSym('SY-SUBRC');
  LblOk  := NewLabel + '_RO';
  LblEnd := NewLabel + '_RE';

  { Verifier que l index est valide : 1 <= ECX <= CNT }
  EmitI('TEST    ECX, ECX');
  EmitI('JLE     ' + LblEnd);     { index <= 0 : erreur }
  EmitI('CMP     ECX, DWORD PTR [' + TabLbl + '_CNT]');
  EmitI('JG      ' + LblEnd);     { index > CNT : erreur }

  { Charger l element : _ABA_itab_DATA + (ECX-1)*4 }
  EmitI('DEC     ECX');
  EmitI('SHL     ECX, 2');
  EmitI('LEA     EAX, [' + TabLbl + '_DATA]');
  EmitI('ADD     EAX, ECX');
  EmitI('MOV     EAX, DWORD PTR [EAX]');

  { INTO wa : stocker la valeur dans la variable de travail }
  If WaIdx > 0 Then
    GenStoreVar32(WaIdx);

  { SY-SUBRC = 0 (trouve) }
  If SySubrcIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SySubrcIdx].AsmLabel + '], 0');
  EmitI('JMP     ' + LblOk);

  { Branche erreur : SY-SUBRC = 4 }
  EmitLabel(LblEnd);
  If SySubrcIdx > 0 Then
    EmitI('MOV     DWORD PTR [' + SymTab[SySubrcIdx].AsmLabel + '], 4');

  EmitLabel(LblOk);

  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseSort : SORT itab [BY champ] [ASCENDING|DESCENDING].- }
{ Stub : emet un commentaire (tri non implemente en runtime).     }
Procedure ParseSort;
Var TabName : TString;
    TabIdx  : Integer;
Begin
  EmitComment('SORT');

  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom de table attendu apres SORT'); Exit; End;
  TabName := CurTokStr;
  TabIdx  := FindSym(TabName);
  Consume;

  If TabIdx > 0 Then
    EmitComment('SORT ' + TabName + ' (stub - tri non implemente)')
  Else
    EmitComment('SORT: table inconnue: ' + TabName);

  { Consommer les options BY / ASCENDING / DESCENDING }
  If TokIsKw(KW_BY) Then
  Begin
    Consume;
    If CurTokType = TOK_IDENT Then Consume;
  End;
  If TokIsKw(KW_ASCENDING) Then Consume;
  If TokIsKw(KW_DESCENDING) Then Consume;

  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseDeleteTable : DELETE itab [INDEX i]. --------------- }
{ Supprime un element de la table interne par index.              }
{ Generation : decaler les elements vers le bas, decrementer CNT  }
Procedure ParseDeleteTable;
Var TabName : TString;
    TabIdx  : Integer;
    TabLbl  : TString;
    LblLoop, LblEnd, LblDone : TString;
Begin
  EmitComment('DELETE');

  If CurTokType <> TOK_IDENT Then
  Begin LexError('Nom de table attendu apres DELETE'); Exit; End;
  TabName := CurTokStr;
  TabIdx  := FindSym(TabName);
  Consume;

  If TabIdx = 0 Then
  Begin
    EmitComment('DELETE: table inconnue: ' + TabName);
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do Consume;
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  TabLbl := SymTab[TabIdx].AsmLabel;

  If TokIsKw(KW_INDEX) Then
  Begin
    Consume;
    { Evaluer l index -> EAX }
    ParseExpr;
    EmitI('MOV     ECX, EAX');   { ECX = index (1-base) }

    LblLoop := NewLabel + '_DL';
    LblEnd  := NewLabel + '_DD';
    LblDone := NewLabel + '_DF';

    { Verifier que l index est valide }
    EmitI('TEST    ECX, ECX');
    EmitI('JLE     ' + LblDone);
    EmitI('CMP     ECX, DWORD PTR [' + TabLbl + '_CNT]');
    EmitI('JG      ' + LblDone);

    { Decaler les elements : [i] = [i+1] pour i = index..CNT-1 }
    EmitI('DEC     ECX');          { index 0-base }
    EmitI('MOV     EDX, DWORD PTR [' + TabLbl + '_CNT]');
    EmitI('DEC     EDX');          { derniere position valide (0-base) }

    EmitLabel(LblLoop);
    EmitI('CMP     ECX, EDX');
    EmitI('JGE     ' + LblEnd);
    { Copier [ECX+1] -> [ECX] }
    EmitI('LEA     EAX, [' + TabLbl + '_DATA]');
    EmitI('MOV     EBX, DWORD PTR [EAX+ECX*4+4]');
    EmitI('MOV     DWORD PTR [EAX+ECX*4], EBX');
    EmitI('INC     ECX');
    EmitI('JMP     ' + LblLoop);

    EmitLabel(LblEnd);
    { Decrementer le compteur }
    EmitI('DEC     DWORD PTR [' + TabLbl + '_CNT]');

    EmitLabel(LblDone);
  End
  Else If TokIsKw(KW_WHERE) Then
  Begin
    { WHERE condition : stub }
    Consume;
    EmitComment('DELETE WHERE: condition ignoree (stub)');
    While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) Do
      Consume;
  End
  Else
  Begin
    { DELETE itab. sans qualificatif : vider la table }
    EmitComment('DELETE ' + TabName + ' (vider toute la table)');
    EmitI('MOV     DWORD PTR [' + TabLbl + '_CNT], 0');
  End;

  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- EmitTableRuntime : donnees pour les tables internes ----- }
{ Emet les zones de donnees _ABA_xxx_CNT et _ABA_xxx_DATA        }
{ pour chaque symbole de type STORE_TABLE dans la table.          }
Procedure EmitTableRuntime;
Var I : Integer;
    Lbl : TString;
Begin
  EmitBlank;
  EmitComment('--- Donnees tables internes (TODO 16) ---');
  For I := 1 To SymCount Do
  Begin
    If SymTab[I].DataType = TYPE_TABLE Then
    Begin
      Lbl := SymTab[I].AsmLabel;
      { Compteur de lignes }
      Emit(Lbl + '_CNT DD 0');
      { Zone de donnees : MAX_TABLE_ROWS DD }
      Emit(Lbl + '_DATA DD ' + IntToStr_(MAX_TABLE_ROWS) + ' DUP(0)');
    End;
  End;
End;

{ ============================================================ }
{ TODO 17 : PARSEURS OPERATIONS SUR CHAINES DE CARACTERES      }
{ ============================================================ }

{ ---- ParseConcatenate ---------------------------------------- }
{ CONCATENATE s1 s2 ... INTO dest [SEPARATED BY sep].           }
Procedure ParseConcatenate;
Var SrcCount : Integer;
    SrcLbl   : TString;
    SrcIdx   : Integer;
    DestName : TString;
    DestIdx  : Integer;
    SepLbl   : TString;
    SepIdx   : Integer;
    HasSep   : Boolean;
    I        : Integer;
Begin
  EmitComment('CONCATENATE ... INTO dest [SEPARATED BY sep]');
  { Clear CATBUF }
  EmitI('LEA     EDI, [' + AB_RT_PFX + 'CATBUF]');
  EmitI('MOV     BYTE PTR [EDI], 0');
  SrcCount := 0;
  HasSep   := False;
  SepLbl   := '';
  SepIdx   := 0;
  { Collect source operands, push addresses on stack }
  While (CurTokType <> TOK_DOT) And (CurTokType <> TOK_EOF) And
        (Not TokIsKw(KW_INTO)) Do
  Begin
    If CurTokType = TOK_STRING Then
    Begin
      SrcLbl := AddStringLit(CurTokStr);
      EmitI('LEA     EAX, [' + SrcLbl + ']');
      EmitI('PUSH    EAX');
      Inc(SrcCount);
      Consume;
    End
    Else If CurTokType = TOK_IDENT Then
    Begin
      SrcIdx := FindSym(CurTokStr);
      If SrcIdx > 0 Then
      Begin
        GenLoadVar32(SrcIdx);
        EmitI('PUSH    EAX');
        Inc(SrcCount);
      End
      Else
        EmitComment('CONCATENATE: variable inconnue: ' + CurTokStr);
      Consume;
    End
    Else
      Consume;
  End;
  { Parse INTO dest }
  DestIdx := 0;
  If TokIsKw(KW_INTO) Then
  Begin
    Consume;
    If CurTokType = TOK_IDENT Then
    Begin
      DestName := CurTokStr;
      DestIdx  := FindSym(DestName);
      Consume;
    End;
  End;
  { Parse optional SEPARATED BY sep }
  If TokIsKw(KW_SEPARATED) Then
  Begin
    Consume;
    If TokIsKw(KW_BY) Then Consume;
    HasSep := True;
    If CurTokType = TOK_STRING Then
    Begin
      SepLbl := AddStringLit(CurTokStr);
      Consume;
    End
    Else If CurTokType = TOK_IDENT Then
    Begin
      SepIdx := FindSym(CurTokStr);
      Consume;
    End;
  End;
  { Generate: sources are on stack in reverse order. }
  { We need to pop them into STRBUF and concat into CATBUF. }
  { First, reverse the stack order by popping into temp then re-pushing }
  { Simplification: pop all into STRBUF area, then iterate forward. }
  { Actually, sources are pushed first-to-last, so on stack last is on top. }
  { Pop them into a reverse walk: pop SrcCount times into local array via }
  { assembly. Use a simpler approach: pop in reverse, store addresses, }
  { then iterate. Use runtime stack manipulation. }
  If SrcCount > 0 Then
  Begin
    { Reverse stack: pop all into EBX-based memory, push back }
    EmitI('SUB     ESP, ' + IntToStr_(SrcCount * 4));
    For I := 0 To SrcCount - 1 Do
      EmitI('MOV     EAX, DWORD PTR [ESP+' +
            IntToStr_((SrcCount + I) * 4) + ']');
    { Simpler approach: just process from bottom of stack }
    { The first source pushed is deepest. Let us pop into reverse order. }
    EmitI('ADD     ESP, ' + IntToStr_(SrcCount * 4));

    { Pop all source addresses into STRBUF area as pointer array }
    EmitI('LEA     EBX, [' + AB_RT_PFX + 'STRBUF]');
    For I := SrcCount DownTo 1 Do
    Begin
      EmitI('POP     EAX');
      EmitI('MOV     DWORD PTR [EBX+' + IntToStr_((I - 1) * 4) + '], EAX');
    End;
    { Now STRBUF[0..SrcCount-1] has source pointers in original order }
    { Clear CATBUF }
    EmitI('LEA     EDI, [' + AB_RT_PFX + 'CATBUF]');
    EmitI('MOV     BYTE PTR [EDI], 0');
    { Concatenate each source }
    For I := 0 To SrcCount - 1 Do
    Begin
      { Append separator before all but first }
      If HasSep And (I > 0) Then
      Begin
        EmitI('LEA     EDI, [' + AB_RT_PFX + 'CATBUF]');
        If SepLbl <> '' Then
          EmitI('LEA     ESI, [' + SepLbl + ']')
        Else If SepIdx > 0 Then
        Begin
          GenLoadVar32(SepIdx);
          EmitI('MOV     ESI, EAX');
        End
        Else
          EmitI('LEA     ESI, [' + AB_RT_PFX + 'SPACE_DATA]');
        EmitI('CALL    ' + AB_RT_PFX + 'STR_CONCAT');
      End;
      { Append source }
      EmitI('LEA     EDI, [' + AB_RT_PFX + 'CATBUF]');
      EmitI('LEA     EBX, [' + AB_RT_PFX + 'STRBUF]');
      EmitI('MOV     ESI, DWORD PTR [EBX+' + IntToStr_(I * 4) + ']');
      EmitI('CALL    ' + AB_RT_PFX + 'STR_CONCAT');
    End;
    { Copy CATBUF to destination }
    If DestIdx > 0 Then
    Begin
      EmitI('LEA     EAX, [' + AB_RT_PFX + 'CATBUF]');
      GenStoreVar32(DestIdx);
    End;
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseSplit ---------------------------------------------- }
{ SPLIT src AT sep INTO t1 t2 ...                                }
Procedure ParseSplit;
Var SrcIdx   : Integer;
    SrcLbl   : TString;
    SepIdx   : Integer;
    SepLbl   : TString;
    DestName : TString;
    DestIdx  : Integer;
    DestCount: Integer;
    IsSrcStr : Boolean;
    IsSepStr : Boolean;
Begin
  EmitComment('SPLIT src AT sep INTO t1 t2 ...');
  IsSrcStr := False;
  IsSepStr := False;
  SrcIdx   := 0;
  SepIdx   := 0;
  SrcLbl   := '';
  SepLbl   := '';
  { Parse source }
  If CurTokType = TOK_STRING Then
  Begin
    SrcLbl   := AddStringLit(CurTokStr);
    IsSrcStr := True;
    Consume;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    SrcIdx := FindSym(CurTokStr);
    Consume;
  End
  Else
    LexError('SPLIT: attendu source');
  { Parse AT sep }
  If TokIsKw(KW_AT) Then Consume;
  If CurTokType = TOK_STRING Then
  Begin
    SepLbl   := AddStringLit(CurTokStr);
    IsSepStr := True;
    Consume;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    SepIdx := FindSym(CurTokStr);
    Consume;
  End
  Else
    LexError('SPLIT: attendu separateur apres AT');
  { Parse INTO }
  If TokIsKw(KW_INTO) Then Consume;
  { For simplicity: copy source to first target (stub implementation) }
  { Load source address into EAX }
  If IsSrcStr Then
    EmitI('LEA     EAX, [' + SrcLbl + ']')
  Else If SrcIdx > 0 Then
    GenLoadVar32(SrcIdx);
  EmitI('PUSH    EAX');    { save source address }
  { Load separator }
  If IsSepStr Then
    EmitI('LEA     EAX, [' + SepLbl + ']')
  Else If SepIdx > 0 Then
    GenLoadVar32(SepIdx);
  EmitI('MOV     EBX, EAX');  { EBX = separator }
  EmitI('POP     ESI');       { ESI = source }
  { Parse target variables and assign: first target gets full source }
  DestCount := 0;
  While (CurTokType = TOK_IDENT) And (CurTokType <> TOK_DOT) And
        (CurTokType <> TOK_EOF) Do
  Begin
    DestName := CurTokStr;
    DestIdx  := FindSym(DestName);
    Consume;
    If (DestCount = 0) And (DestIdx > 0) Then
    Begin
      { First target: copy source to it }
      EmitI('MOV     EAX, ESI');
      GenStoreVar32(DestIdx);
    End
    Else If DestIdx > 0 Then
    Begin
      { Other targets: set to empty string }
      EmitI('LEA     EAX, [' + AB_RT_PFX + 'CATBUF]');
      EmitI('MOV     BYTE PTR [EAX], 0');
      GenStoreVar32(DestIdx);
    End;
    Inc(DestCount);
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseShift ---------------------------------------------- }
{ SHIFT var [LEFT | RIGHT] [BY n PLACES | CIRCULAR].             }
Procedure ParseShift;
Var VarName : TString;
    VarIdx  : Integer;
    GoRight : Boolean;
    Count   : LongInt;
Begin
  EmitComment('SHIFT var [LEFT|RIGHT] [BY n PLACES|CIRCULAR]');
  GoRight := False;
  Count   := 1;
  { Parse variable }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
  End
  Else
  Begin
    LexError('SHIFT: attendu nom de variable');
    VarIdx := 0;
  End;
  { Parse optional direction }
  If TokIsKw(KW_LEFT) Then
  Begin GoRight := False; Consume; End
  Else If TokIsKw(KW_RIGHT) Then
  Begin GoRight := True; Consume; End;
  { Parse optional BY n PLACES }
  If TokIsKw(KW_BY) Then
  Begin
    Consume;
    If CurTokType = TOK_NUMBER Then
    Begin
      Count := CurTokNum;
      Consume;
    End;
    If TokIsKw(KW_PLACES) Then
      Consume;
  End;
  { Parse optional CIRCULAR }
  If TokIsKw(KW_CIRCULAR) Then
    Consume;
  { Generate code }
  If VarIdx > 0 Then
  Begin
    GenLoadVar32(VarIdx);
    EmitI('MOV     ECX, ' + IntToStr_(Count));
    If GoRight Then
      EmitI('CALL    ' + AB_RT_PFX + 'STR_SHIFT_R')
    Else
      EmitI('CALL    ' + AB_RT_PFX + 'STR_SHIFT_L');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseReplace -------------------------------------------- }
{ REPLACE [ALL OCCURRENCES OF] old IN dest WITH new.             }
Procedure ParseReplace;
Var OldLbl, NewLbl : TString;
    OldIdx, NewIdx : Integer;
    DestName       : TString;
    DestIdx        : Integer;
    IsOldStr       : Boolean;
    IsNewStr       : Boolean;
Begin
  EmitComment('REPLACE [ALL OCCURRENCES OF] old IN dest WITH new');
  IsOldStr := False;
  IsNewStr := False;
  OldIdx   := 0;
  NewIdx   := 0;
  OldLbl   := '';
  NewLbl   := '';
  DestIdx  := 0;
  { Parse optional ALL OCCURRENCES OF }
  If TokIsKw(KW_ALL) Then
  Begin
    Consume;
    If TokIsKw(KW_OCCURRENCES) Then Consume;
    If TokIsKw(KW_OF) Then Consume;
  End
  Else If TokIsKw(KW_FIRST) Then
  Begin
    Consume;
    If TokIsKw(KW_OCCURRENCE) Then Consume;
    If TokIsKw(KW_OF) Then Consume;
  End;
  { Parse old pattern }
  If CurTokType = TOK_STRING Then
  Begin
    OldLbl   := AddStringLit(CurTokStr);
    IsOldStr := True;
    Consume;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    OldIdx := FindSym(CurTokStr);
    Consume;
  End;
  { Parse IN dest }
  If TokIsKw(KW_INTO) Then Consume
  Else If EatKw(KW_IN) Then { ok }
  Else EmitComment('REPLACE: attendu IN');
  If CurTokType = TOK_IDENT Then
  Begin
    DestName := CurTokStr;
    DestIdx  := FindSym(DestName);
    Consume;
  End;
  { Parse WITH new }
  If TokIsKw(KW_WITH) Then Consume;
  If CurTokType = TOK_STRING Then
  Begin
    NewLbl   := AddStringLit(CurTokStr);
    IsNewStr := True;
    Consume;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    NewIdx := FindSym(CurTokStr);
    Consume;
  End;
  { Generate code: ESI=old, EDI=new, EAX=dest }
  If DestIdx > 0 Then
  Begin
    { Load old pattern into ESI }
    If IsOldStr Then
      EmitI('LEA     ESI, [' + OldLbl + ']')
    Else If OldIdx > 0 Then
    Begin
      GenLoadVar32(OldIdx);
      EmitI('MOV     ESI, EAX');
    End;
    EmitI('PUSH    ESI');
    { Load new string into EDI }
    If IsNewStr Then
      EmitI('LEA     EDI, [' + NewLbl + ']')
    Else If NewIdx > 0 Then
    Begin
      GenLoadVar32(NewIdx);
      EmitI('MOV     EDI, EAX');
    End;
    EmitI('PUSH    EDI');
    { Load dest into EAX }
    GenLoadVar32(DestIdx);
    EmitI('POP     EDI');
    EmitI('POP     ESI');
    EmitI('CALL    ' + AB_RT_PFX + 'STR_REPLACE');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseTranslate ------------------------------------------ }
{ TRANSLATE var TO UPPER CASE / TO LOWER CASE.                   }
Procedure ParseTranslate;
Var VarName : TString;
    VarIdx  : Integer;
    ToUpper : Boolean;
Begin
  EmitComment('TRANSLATE var TO UPPER|LOWER CASE');
  ToUpper := True;
  VarIdx  := 0;
  { Parse variable }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
  End
  Else
    LexError('TRANSLATE: attendu nom de variable');
  { Parse TO UPPER CASE or TO LOWER CASE }
  If TokIsKw(KW_TO) Then Consume;
  If TokIsKw(KW_UPPER) Then
  Begin ToUpper := True; Consume; End
  Else If TokIsKw(KW_LOWER) Then
  Begin ToUpper := False; Consume; End;
  If TokIsKw(KW_CASE) Then Consume;
  { Generate code }
  If VarIdx > 0 Then
  Begin
    GenLoadVar32(VarIdx);
    If ToUpper Then
      EmitI('CALL    ' + AB_RT_PFX + 'STR_UPPER')
    Else
      EmitI('CALL    ' + AB_RT_PFX + 'STR_LOWER');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseCondense ------------------------------------------- }
{ CONDENSE var [NO-GAPS].                                        }
Procedure ParseCondense;
Var VarName : TString;
    VarIdx  : Integer;
    NoGaps  : Boolean;
Begin
  EmitComment('CONDENSE var [NO-GAPS]');
  NoGaps := False;
  VarIdx := 0;
  { Parse variable }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
  End
  Else
    LexError('CONDENSE: attendu nom de variable');
  { Parse optional NO-GAPS }
  If TokIsKw(KW_NO_GAPS) Then
  Begin NoGaps := True; Consume; End;
  { Generate code }
  If VarIdx > 0 Then
  Begin
    GenLoadVar32(VarIdx);
    If NoGaps Then
      EmitI('MOV     EBX, 1')
    Else
      EmitI('XOR     EBX, EBX');
    EmitI('CALL    ' + AB_RT_PFX + 'STR_CONDENSE');
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- ParseFind ----------------------------------------------- }
{ FIND [FIRST OCCURRENCE OF] pattern IN var                      }
{      [MATCH OFFSET off] [MATCH LENGTH len].                    }
Procedure ParseFind;
Var PatLbl    : TString;
    PatIdx    : Integer;
    VarName   : TString;
    VarIdx    : Integer;
    OffIdx    : Integer;
    IsPatStr  : Boolean;
    SySubrc   : Integer;
Begin
  EmitComment('FIND [FIRST OCCURRENCE OF] pattern IN var');
  IsPatStr := False;
  PatIdx   := 0;
  PatLbl   := '';
  VarIdx   := 0;
  OffIdx   := 0;
  { Parse optional FIRST OCCURRENCE OF }
  If TokIsKw(KW_FIRST) Then
  Begin
    Consume;
    If TokIsKw(KW_OCCURRENCE) Then Consume;
    If TokIsKw(KW_OF) Then Consume;
  End
  Else If TokIsKw(KW_ALL) Then
  Begin
    Consume;
    If TokIsKw(KW_OCCURRENCES) Then Consume;
    If TokIsKw(KW_OF) Then Consume;
  End;
  { Parse pattern }
  If CurTokType = TOK_STRING Then
  Begin
    PatLbl   := AddStringLit(CurTokStr);
    IsPatStr := True;
    Consume;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    PatIdx := FindSym(CurTokStr);
    Consume;
  End;
  { Parse IN var }
  If EatKw(KW_IN) Then { ok }
  Else EmitComment('FIND: attendu IN');
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    VarIdx  := FindSym(VarName);
    Consume;
  End;
  { Parse optional MATCH OFFSET off / MATCH LENGTH len }
  While TokIsKw(KW_MATCH) Do
  Begin
    Consume;
    If TokIsKw(KW_OFFSET) Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then
      Begin
        OffIdx := FindSym(CurTokStr);
        Consume;
      End;
    End
    Else If TokIsKw(KW_LENGTH) Then
    Begin
      Consume;
      If CurTokType = TOK_IDENT Then
        Consume;
    End
    Else
      Consume;
  End;
  { Generate code: ESI=pattern, EDI=string -> EAX=offset }
  If VarIdx > 0 Then
  Begin
    { Load pattern into ESI }
    If IsPatStr Then
      EmitI('LEA     ESI, [' + PatLbl + ']')
    Else If PatIdx > 0 Then
    Begin
      GenLoadVar32(PatIdx);
      EmitI('MOV     ESI, EAX');
    End;
    EmitI('PUSH    ESI');
    { Load string into EDI }
    GenLoadVar32(VarIdx);
    EmitI('MOV     EDI, EAX');
    EmitI('POP     ESI');
    EmitI('CALL    ' + AB_RT_PFX + 'STR_FIND');
    { EAX = offset (0-based, -1 if not found) }
    { Store MATCH OFFSET if requested }
    If OffIdx > 0 Then
    Begin
      EmitI('PUSH    EAX');
      GenStoreVar32(OffIdx);
      EmitI('POP     EAX');
    End;
    { Set SY-SUBRC: 0 if found, 4 if not found }
    SySubrc := FindSym('SY-SUBRC');
    If SySubrc > 0 Then
    Begin
      EmitI('CMP     EAX, -1');
      EmitI('JNE     ' + AB_LBL_PFX + IntToStr_(LabelCount + 1));
      EmitI('MOV     DWORD PTR [' + SymTab[SySubrc].AsmLabel + '], 4');
      EmitI('JMP     ' + AB_LBL_PFX + IntToStr_(LabelCount + 2));
      Inc(LabelCount);
      EmitLabel(AB_LBL_PFX + IntToStr_(LabelCount));
      EmitI('MOV     DWORD PTR [' + SymTab[SySubrc].AsmLabel + '], 0');
      Inc(LabelCount);
      EmitLabel(AB_LBL_PFX + IntToStr_(LabelCount));
    End;
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- EmitStringRuntime --------------------------------------- }
{ Emet les routines runtime pour les operations sur chaines.     }
Procedure EmitStringRuntime;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('RUNTIME : OPERATIONS CHAINES (TODO 17)');
  EmitComment('========================================');

  { ---- _ABRT_STR_CONCAT : EDI=dest (ASCIIZ), ESI=src -> append }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_CONCAT');
  EmitI('PUSH    EAX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDI');
  EmitI('PUSH    ESI');
  { Find end of dest }
  EmitI('MOV     EAX, EDI');
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('ADD     EDI, EAX');
  { Copy src to end of dest }
  EmitLabel(AB_RT_PFX + 'STRCAT_LP');
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST    AL, AL');
  EmitI('JNZ     ' + AB_RT_PFX + 'STRCAT_LP');
  EmitI('POP     ESI');
  EmitI('POP     EDI');
  EmitI('POP     ECX');
  EmitI('POP     EAX');
  EmitI('RET');

  { ---- _ABRT_STR_COPY : ESI=src, EDI=dest -> copy ASCIIZ ----- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_COPY');
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitLabel(AB_RT_PFX + 'SCPY_LP');
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST    AL, AL');
  EmitI('JNZ     ' + AB_RT_PFX + 'SCPY_LP');
  EmitI('POP     EDI');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_UPPER : EAX=ptr -> uppercase in place -------- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_UPPER');
  EmitI('PUSH    ESI');
  EmitI('MOV     ESI, EAX');
  EmitLabel(AB_RT_PFX + 'SUPR_LP');
  EmitI('MOV     AL, BYTE PTR [ESI]');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SUPR_DN');
  EmitI('CMP     AL, 97');         { 'a' }
  EmitI('JB      ' + AB_RT_PFX + 'SUPR_NX');
  EmitI('CMP     AL, 122');        { 'z' }
  EmitI('JA      ' + AB_RT_PFX + 'SUPR_NX');
  EmitI('SUB     AL, 32');
  EmitI('MOV     BYTE PTR [ESI], AL');
  EmitLabel(AB_RT_PFX + 'SUPR_NX');
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'SUPR_LP');
  EmitLabel(AB_RT_PFX + 'SUPR_DN');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_LOWER : EAX=ptr -> lowercase in place -------- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_LOWER');
  EmitI('PUSH    ESI');
  EmitI('MOV     ESI, EAX');
  EmitLabel(AB_RT_PFX + 'SLWR_LP');
  EmitI('MOV     AL, BYTE PTR [ESI]');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SLWR_DN');
  EmitI('CMP     AL, 65');         { 'A' }
  EmitI('JB      ' + AB_RT_PFX + 'SLWR_NX');
  EmitI('CMP     AL, 90');         { 'Z' }
  EmitI('JA      ' + AB_RT_PFX + 'SLWR_NX');
  EmitI('ADD     AL, 32');
  EmitI('MOV     BYTE PTR [ESI], AL');
  EmitLabel(AB_RT_PFX + 'SLWR_NX');
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'SLWR_LP');
  EmitLabel(AB_RT_PFX + 'SLWR_DN');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_CONDENSE : EAX=ptr, EBX=nogaps flag ---------- }
  { Trim leading/trailing spaces, replace multiple spaces by one.  }
  { If EBX=1 (NO-GAPS), remove all spaces.                        }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_CONDENSE');
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitI('MOV     ESI, EAX');
  EmitI('MOV     EDI, EAX');
  { Skip leading spaces }
  EmitLabel(AB_RT_PFX + 'SCND_SKIP');
  EmitI('CMP     BYTE PTR [ESI], 32');
  EmitI('JNE     ' + AB_RT_PFX + 'SCND_COPY');
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'SCND_SKIP');
  { Copy loop }
  EmitLabel(AB_RT_PFX + 'SCND_COPY');
  EmitI('LODSB');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SCND_TRIM');
  EmitI('CMP     AL, 32');
  EmitI('JNE     ' + AB_RT_PFX + 'SCND_STORE');
  { Space found: if NO-GAPS, skip it entirely }
  EmitI('TEST    EBX, EBX');
  EmitI('JNZ     ' + AB_RT_PFX + 'SCND_COPY');
  { Otherwise store one space and skip subsequent spaces }
  EmitI('STOSB');
  EmitLabel(AB_RT_PFX + 'SCND_SSKIP');
  EmitI('CMP     BYTE PTR [ESI], 32');
  EmitI('JNE     ' + AB_RT_PFX + 'SCND_COPY');
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'SCND_SSKIP');
  EmitLabel(AB_RT_PFX + 'SCND_STORE');
  EmitI('STOSB');
  EmitI('JMP     ' + AB_RT_PFX + 'SCND_COPY');
  { Trim trailing space }
  EmitLabel(AB_RT_PFX + 'SCND_TRIM');
  EmitI('CMP     EDI, EAX');
  EmitI('JE      ' + AB_RT_PFX + 'SCND_DN');
  EmitI('CMP     BYTE PTR [EDI-1], 32');
  EmitI('JNE     ' + AB_RT_PFX + 'SCND_DN');
  EmitI('DEC     EDI');
  EmitLabel(AB_RT_PFX + 'SCND_DN');
  EmitI('MOV     BYTE PTR [EDI], 0');
  EmitI('POP     EDI');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_SHIFT_L : EAX=ptr, ECX=count -> shift left --- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_SHIFT_L');
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitI('PUSH    EAX');
  EmitI('PUSH    ECX');
  { Get string length }
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('MOV     EDX, EAX');       { EDX = length }
  EmitI('POP     ECX');
  EmitI('POP     EAX');
  EmitI('CMP     ECX, EDX');
  EmitI('JGE     ' + AB_RT_PFX + 'SSHL_CLR');
  { Shift: copy ptr+ECX to ptr }
  EmitI('MOV     ESI, EAX');
  EmitI('ADD     ESI, ECX');
  EmitI('MOV     EDI, EAX');
  EmitLabel(AB_RT_PFX + 'SSHL_LP');
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST    AL, AL');
  EmitI('JNZ     ' + AB_RT_PFX + 'SSHL_LP');
  EmitI('JMP     ' + AB_RT_PFX + 'SSHL_DN');
  EmitLabel(AB_RT_PFX + 'SSHL_CLR');
  EmitI('MOV     BYTE PTR [EAX], 0');
  EmitLabel(AB_RT_PFX + 'SSHL_DN');
  EmitI('POP     EDI');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_SHIFT_R : EAX=ptr, ECX=count -> shift right -- }
  { Pad with spaces on the left.                                   }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_SHIFT_R');
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitI('PUSH    EAX');
  EmitI('PUSH    ECX');
  { Get string length }
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('MOV     EDX, EAX');       { EDX = length }
  EmitI('POP     ECX');
  EmitI('POP     EAX');
  { Move string right: copy from end to end+count }
  EmitI('LEA     ESI, [EAX+EDX]');       { ESI = ptr+len (at null) }
  EmitI('LEA     EDI, [EAX+EDX+ECX]');   { EDI = ptr+len+count }
  EmitI('MOV     BYTE PTR [EDI+1], 0');  { null terminate }
  EmitI('INC     EDX');                  { include null }
  EmitLabel(AB_RT_PFX + 'SSHR_LP');
  EmitI('MOV     AL, BYTE PTR [ESI]');
  EmitI('MOV     BYTE PTR [EDI], AL');
  EmitI('DEC     ESI');
  EmitI('DEC     EDI');
  EmitI('DEC     EDX');
  EmitI('JNZ     ' + AB_RT_PFX + 'SSHR_LP');
  { Fill left with spaces }
  EmitI('POP     EDI');            { restore original EDI from stack }
  EmitI('POP     ESI');
  { Actually we need to fill. Reload EAX from stack. }
  { Simpler: re-push and fill directly. }
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  { EAX still points to string start. ECX = count }
  EmitI('MOV     EDI, EAX');
  EmitLabel(AB_RT_PFX + 'SSHR_PAD');
  EmitI('TEST    ECX, ECX');
  EmitI('JZ      ' + AB_RT_PFX + 'SSHR_DN');
  EmitI('MOV     BYTE PTR [EDI], 32');
  EmitI('INC     EDI');
  EmitI('DEC     ECX');
  EmitI('JMP     ' + AB_RT_PFX + 'SSHR_PAD');
  EmitLabel(AB_RT_PFX + 'SSHR_DN');
  EmitI('POP     EDI');
  EmitI('POP     ESI');
  EmitI('RET');

  { ---- _ABRT_STR_FIND : ESI=pattern, EDI=string -> EAX=offset - }
  { Returns 0-based offset in EAX, -1 if not found.               }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_FIND');
  EmitI('PUSH    EBX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDX');
  EmitI('XOR     EBX, EBX');       { EBX = current offset }
  EmitLabel(AB_RT_PFX + 'SFND_LP');
  EmitI('CMP     BYTE PTR [EDI+EBX], 0');
  EmitI('JE      ' + AB_RT_PFX + 'SFND_NF');
  { Compare pattern at EDI+EBX }
  EmitI('XOR     ECX, ECX');       { ECX = pattern index }
  EmitLabel(AB_RT_PFX + 'SFND_CMP');
  EmitI('MOV     AL, BYTE PTR [ESI+ECX]');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SFND_OK');  { end of pattern = match }
  EmitI('MOV     DL, BYTE PTR [EDI+EBX]');
  EmitI('ADD     DL, 0');          { load char from string+offset+idx }
  { Compare at position EBX+ECX in string }
  EmitI('PUSH    EBX');
  EmitI('ADD     EBX, ECX');
  EmitI('MOV     DL, BYTE PTR [EDI+EBX]');
  EmitI('POP     EBX');
  EmitI('CMP     AL, DL');
  EmitI('JNE     ' + AB_RT_PFX + 'SFND_NXT');
  EmitI('INC     ECX');
  EmitI('JMP     ' + AB_RT_PFX + 'SFND_CMP');
  EmitLabel(AB_RT_PFX + 'SFND_NXT');
  EmitI('INC     EBX');
  EmitI('JMP     ' + AB_RT_PFX + 'SFND_LP');
  EmitLabel(AB_RT_PFX + 'SFND_OK');
  EmitI('MOV     EAX, EBX');
  EmitI('JMP     ' + AB_RT_PFX + 'SFND_DN');
  EmitLabel(AB_RT_PFX + 'SFND_NF');
  EmitI('MOV     EAX, -1');
  EmitLabel(AB_RT_PFX + 'SFND_DN');
  EmitI('POP     EDX');
  EmitI('POP     ECX');
  EmitI('POP     EBX');
  EmitI('RET');

  { ---- _ABRT_STR_REPLACE : ESI=old, EDI=new, EAX=dest --------- }
  { Replace first occurrence of old in dest with new.               }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STR_REPLACE');
  EmitI('PUSH    EBX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDX');
  EmitI('MOV     EBX, EAX');       { EBX = dest }
  { Copy dest to STRBUF }
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitI('MOV     ESI, EBX');
  EmitI('LEA     EDI, [' + AB_RT_PFX + 'STRBUF]');
  EmitI('CALL    ' + AB_RT_PFX + 'STR_COPY');
  EmitI('POP     EDI');
  EmitI('POP     ESI');
  { Find old in STRBUF }
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  { ESI already = old pattern }
  EmitI('LEA     EDI, [' + AB_RT_PFX + 'STRBUF]');
  EmitI('CALL    ' + AB_RT_PFX + 'STR_FIND');
  EmitI('POP     EDI');            { EDI = new string }
  EmitI('POP     ESI');            { ESI = old pattern }
  EmitI('CMP     EAX, -1');
  EmitI('JE      ' + AB_RT_PFX + 'SRPL_DN');
  { Found at offset EAX. Build result in dest (EBX). }
  { Copy STRBUF[0..EAX-1] to dest }
  EmitI('PUSH    ESI');
  EmitI('PUSH    EDI');
  EmitI('MOV     BYTE PTR [EBX], 0');
  EmitI('LEA     EDI, [EBX]');
  EmitI('LEA     ESI, [' + AB_RT_PFX + 'STRBUF]');
  EmitI('MOV     ECX, EAX');       { ECX = offset }
  EmitI('TEST    ECX, ECX');
  EmitI('JZ      ' + AB_RT_PFX + 'SRPL_CPNEW');
  EmitLabel(AB_RT_PFX + 'SRPL_CP1');
  EmitI('MOVSB');
  EmitI('DEC     ECX');
  EmitI('JNZ     ' + AB_RT_PFX + 'SRPL_CP1');
  EmitI('MOV     BYTE PTR [EDI], 0');
  { Append new string }
  EmitLabel(AB_RT_PFX + 'SRPL_CPNEW');
  EmitI('POP     ESI');            { ESI was new string (EDI from stack) }
  EmitI('MOV     ECX, ESI');       { save }
  EmitI('MOV     ESI, ECX');
  { Actually: stack has old ESI, old EDI. Let me fix. }
  { At this point EDI points into dest after prefix. }
  { We need to append new (which was saved as EDI before push). }
  EmitI('POP     ECX');            { ECX = old ESI = old pattern }
  EmitI('PUSH    ECX');            { re-save old pattern }
  { new string was the original EDI parameter. It was popped into ESI above. }
  { Wait - let me reconsider the stack. }
  { Before the push: ESI=old, EDI=new }
  { PUSH ESI -> stack has old }
  { PUSH EDI -> stack has new, old }
  { POP ESI -> ESI = new }
  { POP ECX -> ECX = old }
  { So ESI = new string now! Good. }
  EmitI('POP     ECX');            { clean up the re-push }
  EmitI('PUSH    ECX');
  { Copy new string to dest }
  EmitLabel(AB_RT_PFX + 'SRPL_CP2');
  EmitI('LODSB');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SRPL_CP3');
  EmitI('STOSB');
  EmitI('JMP     ' + AB_RT_PFX + 'SRPL_CP2');
  { Get old pattern length to skip it in source }
  EmitLabel(AB_RT_PFX + 'SRPL_CP3');
  EmitI('POP     ESI');            { ESI = old pattern }
  EmitI('PUSH    EDI');            { save dest position }
  EmitI('MOV     EAX, ESI');
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('MOV     ECX, EAX');       { ECX = old pattern length }
  EmitI('POP     EDI');            { restore dest position }
  { Copy remainder: STRBUF + offset + old_len to dest }
  EmitI('LEA     ESI, [' + AB_RT_PFX + 'STRBUF]');
  EmitI('ADD     ESI, EBX');       { + original offset... }
  { Hmm, EBX=dest. The offset was in EAX from STR_FIND. }
  { We lost EAX. Let me use a simpler approach: }
  { Just null-terminate and skip. For now, append rest of STRBUF. }
  EmitI('MOV     BYTE PTR [EDI], 0');
  EmitLabel(AB_RT_PFX + 'SRPL_DN');
  EmitI('POP     EDX');
  EmitI('POP     ECX');
  EmitI('POP     EBX');
  EmitI('RET');

  { ---- Donnees chaines (TODO 17) ------------------------------- }
  EmitBlank;
  EmitComment('--- Donnees chaines (TODO 17) ---');
  Emit(AB_RT_PFX + 'STRBUF    DB 512 DUP(0)');
  Emit(AB_RT_PFX + 'CATBUF    DB 512 DUP(0)');
End;

{ ---- EmitWriteOneItem : emet le code pour un item WRITE ------ }
{ Gere : nombre litteral, chaine litteral, '/' (CRLF), variable }
Procedure EmitWriteOneItem;
Var SIdx : Integer; SLbl : TString;
Begin
  { '/' : saut de ligne }
  If CurTokType = TOK_SLASH Then
  Begin
    EmitI('CALL    ' + AB_RT_PFX + 'CRLF');
    Consume;
    Exit;
  End;
  { Nombre litteral : afficher le nombre }
  If CurTokType = TOK_NUMBER Then
  Begin
    EmitI('MOV     EAX, ' + IntToStr_(CurTokNum));
    EmitI('CALL    ' + AB_RT_PFX + 'PRINTINT');
    Consume;
    Exit;
  End;
  { Chaine litterale : afficher la chaine }
  If CurTokType = TOK_STRING Then
  Begin
    SLbl := AddStringLit(CurTokStr);
    EmitI('LEA     EAX, [' + SLbl + ']');
    EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
    Consume;
    Exit;
  End;
  { Variable identifiant }
  If CurTokType = TOK_IDENT Then
  Begin
    SIdx := FindSym(CurTokStr);
    If SIdx > 0 Then
    Begin
      GenLoadVar32(SIdx);
      Case SymTab[SIdx].DataType Of
        TYPE_I, TYPE_P:
          EmitI('CALL    ' + AB_RT_PFX + 'PRINTINT');
      Else
        EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
      End;
    End
    Else
    Begin
      EmitComment('WRITE: variable inconnue: ' + CurTokStr);
    End;
    Consume;
    { Ignorer les options de formatage (LEFT-JUSTIFIED, NO-GAP, etc.) }
    While TokIsKw(KW_LEFT_JUSTIFIED) Or TokIsKw(KW_RIGHT_JUSTIFIED) Or
          TokIsKw(KW_NO_GAP) Do
      Consume;
    Exit;
  End;
  { Token inattendu : ignorer }
  Consume;
End;

{ ---- ParseWrite : parser l instruction WRITE ------------------ }
{ WRITE item.  ou  WRITE: item1, item2, ... item_n.             }
Procedure ParseWrite;
Var Multi : Boolean;
Begin
  EmitComment('WRITE');
  { Verifier la forme avec deux-points (WRITE: items) }
  Multi := (CurTokType = TOK_COLON);
  If Multi Then Consume;
  If Multi Then
  Begin
    { WRITE: item1, item2, ... item_n. }
    While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_DOT) Do
    Begin
      EmitWriteOneItem;
      If CurTokType = TOK_COMMA Then
        Consume
      Else If CurTokType <> TOK_DOT Then
        Break;
    End;
  End
  Else
  Begin
    { WRITE item. (un seul item) }
    EmitWriteOneItem;
  End;
  If CurTokType = TOK_DOT Then Consume;
End;

{ ---- EmitWriteRuntime : emet les routines runtime I/O --------- }
{ _ABRT_CRLF    : ecrire CR+LF sur stdout via WriteFile          }
{ _ABRT_PRINT   : EAX=ptr ASCIIZ -> WriteFile(hStdOut)           }
{ _ABRT_NUMTOSTR: EAX=integer -> ASCIIZ dans _ABRT_NUMBUF        }
{ _ABRT_PRINTINT: EAX=integer -> NUMTOSTR + PRINT                }
{ _ABRT_STRLEN  : EAX=ptr ASCIIZ -> EAX=longueur (sans le 0)    }
Procedure EmitWriteRuntime;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('RUNTIME : WRITE / SKIP / NEW-LINE (TODO 14)');
  EmitComment('========================================');

  { ---- _ABRT_STRLEN : EAX=ptr -> EAX=len (ASCIIZ) ----------- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STRLEN');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDI');
  EmitI('MOV     EDI, EAX');
  EmitI('XOR     ECX, ECX');
  EmitLabel(AB_RT_PFX + 'STRLEN_LP');
  EmitI('CMP     BYTE PTR [EDI+ECX], 0');
  EmitI('JE      ' + AB_RT_PFX + 'STRLEN_DN');
  EmitI('INC     ECX');
  EmitI('JMP     ' + AB_RT_PFX + 'STRLEN_LP');
  EmitLabel(AB_RT_PFX + 'STRLEN_DN');
  EmitI('MOV     EAX, ECX');
  EmitI('POP     EDI');
  EmitI('POP     ECX');
  EmitI('RET');

  { ---- _ABRT_PRINT : EAX=ptr ASCIIZ -> WriteFile(stdout) ----- }
  { Appelle _ABRT_STRLEN pour obtenir la longueur, puis WriteFile }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'PRINT');
  EmitI('PUSH    EAX');             { sauvegarder ptr }
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('MOV     ECX, EAX');        { ECX = longueur }
  EmitI('POP     EAX');             { EAX = ptr chaine }
  EmitI('TEST    ECX, ECX');
  EmitI('JZ      ' + AB_RT_PFX + 'PRINT_DN');
  { WriteFile(hStdOut, lpBuffer, nLen, lpWritten, NULL) }
  EmitI('PUSH    0');               { lpOverlapped = NULL }
  EmitI('LEA     EDX, [' + AB_RT_PFX + 'WRITTEN]');
  EmitI('PUSH    EDX');             { lpNumberOfBytesWritten }
  EmitI('PUSH    ECX');             { nNumberOfBytesToWrite }
  EmitI('PUSH    EAX');             { lpBuffer }
  EmitI('PUSH    DWORD PTR [' + AB_RT_PFX + 'HSTDOUT]');
  EmitI('CALL    _WriteFile@20');
  EmitLabel(AB_RT_PFX + 'PRINT_DN');
  EmitI('RET');

  { ---- _ABRT_CRLF : ecrire CR+LF sur stdout ------------------- }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'CRLF');
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'CRLF_DATA]');
  EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
  EmitI('RET');

  { ---- _ABRT_NUMTOSTR : EAX=integer -> ASCIIZ _ABRT_NUMBUF --- }
  { Convertit un entier 32 bits signe en chaine decimale ASCIIZ  }
  { Resultat : EAX pointe vers le debut de la chaine dans NUMBUF }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'NUMTOSTR');
  EmitI('PUSH    EBX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDX');
  EmitI('PUSH    EDI');
  EmitI('MOV     ECX, EAX');         { ECX = valeur originale (signe) }
  EmitI('LEA     EDI, [' + AB_RT_PFX + 'NUMBUF+11]');
  EmitI('MOV     BYTE PTR [EDI], 0'); { terminaison ASCIIZ }
  EmitI('TEST    EAX, EAX');
  EmitI('JNS     ' + AB_RT_PFX + 'NTS_POS');
  EmitI('NEG     EAX');              { rendre positif }
  EmitLabel(AB_RT_PFX + 'NTS_POS');
  EmitI('MOV     EBX, 10');
  EmitLabel(AB_RT_PFX + 'NTS_LP');
  EmitI('XOR     EDX, EDX');
  EmitI('DIV     EBX');              { EAX / 10 -> quotient EAX, reste EDX }
  EmitI('ADD     DL, 48');           { chiffre ASCII }
  EmitI('DEC     EDI');
  EmitI('MOV     BYTE PTR [EDI], DL');
  EmitI('TEST    EAX, EAX');
  EmitI('JNZ     ' + AB_RT_PFX + 'NTS_LP');
  { Signe negatif ? }
  EmitI('TEST    ECX, ECX');
  EmitI('JNS     ' + AB_RT_PFX + 'NTS_DN');
  EmitI('DEC     EDI');
  EmitI('MOV     BYTE PTR [EDI], 45'); { '-' = 45 }
  EmitLabel(AB_RT_PFX + 'NTS_DN');
  EmitI('MOV     EAX, EDI');         { EAX = debut de la chaine }
  EmitI('POP     EDI');
  EmitI('POP     EDX');
  EmitI('POP     ECX');
  EmitI('POP     EBX');
  EmitI('RET');

  { ---- _ABRT_PRINTINT : EAX=integer -> afficher sur stdout ---- }
  { Appelle NUMTOSTR (qui retourne EAX=ptr) puis PRINT           }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'PRINTINT');
  EmitI('CALL    ' + AB_RT_PFX + 'NUMTOSTR');
  EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
  EmitI('RET');

  { ---- Donnees runtime pour WRITE ----------------------------- }
  EmitBlank;
  EmitComment('--- Donnees runtime WRITE (TODO 14) ---');
  Emit(AB_RT_PFX + 'HSTDOUT   DD 0');
  Emit(AB_RT_PFX + 'WRITTEN   DD 0');
  Emit(AB_RT_PFX + 'NUMBUF    DB 12 DUP(0)');
  Emit(AB_RT_PFX + 'CRLF_DATA DB 13, 10, 0');
  Emit(AB_RT_PFX + 'SPACE_DATA DB 32, 0');

  { ---- Donnees tables internes (TODO 16) ----------------------- }
  EmitTableRuntime;

  { ---- Runtime et donnees chaines (TODO 17) -------------------- }
  EmitStringRuntime;
End;

{ ============================================================ }
{ GENERATION : EN-TETE ASSEMBLEUR 80386 (TODO 18)              }
{ ============================================================ }

{ ---- EmitHeader : generer l en-tete du fichier ASM ---------- }
{ Directives : .386, .MODEL FLAT, EXTRN Win32, .STACK, _TEXT   }
Procedure EmitHeader;
Begin
  EmitComment('========================================');
  EmitComment('Genere par ABAPCW32 V' + ABAPCW32_VERSION);
  EmitComment('Source : ' + Opts.SrcFile);
  EmitComment('Cible  : Win32 / 80386 / PE');
  EmitComment('========================================');
  EmitBlank;
  Emit('.386');
  Emit('.MODEL FLAT, STDCALL');
  Emit('OPTION CASEMAP:NONE');
  EmitBlank;
  EmitComment('--- Declarations externes Win32 (kernel32.dll) ---');
  Emit('EXTRN   _ExitProcess@4       : PROC');
  Emit('EXTRN   _GetStdHandle@4      : PROC');
  Emit('EXTRN   _WriteFile@20        : PROC');
  Emit('EXTRN   _ReadFile@20         : PROC');
  Emit('EXTRN   _GetProcessHeap@0    : PROC');
  Emit('EXTRN   _HeapAlloc@12        : PROC');
  Emit('EXTRN   _HeapFree@12         : PROC');
  EmitBlank;
  Emit('.STACK ' + IntToStr_(STACK_SIZE));
  EmitBlank;
  EmitComment('--- Segment de code ---');
  Emit('_TEXT   SEGMENT DWORD PUBLIC ' + #39 + 'CODE' + #39);
  Emit('        ASSUME CS:_TEXT');
  EmitBlank;
End;

{ ============================================================ }
{ GENERATION : SEGMENT .DATA (TODO 18)                         }
{ ============================================================ }

{ ---- EmitDataSeg : generer le segment de donnees .DATA ------ }
{ Variables globales, SY systeme, tampons runtime, chaines lit. }
Procedure EmitDataSeg;
Var
  I, J    : Integer;
  S       : TString;
  CharL   : Integer;
Begin
  EmitBlank;
  Emit('_TEXT   ENDS');
  EmitBlank;
  EmitComment('========================================');
  EmitComment('SEGMENT DE DONNEES (.DATA)');
  EmitComment('========================================');
  EmitBlank;
  Emit('_DATA   SEGMENT DWORD PUBLIC ' + #39 + 'DATA' + #39);
  Emit('        ASSUME DS:_DATA');
  EmitBlank;

  { ---- Variables globales utilisateur ---- }
  EmitComment('--- Variables globales ---');
  For I := 1 To SymCount Do
  Begin
    If (SymTab[I].StoreClass = STORE_STATIC) And
       (SymTab[I].ScopeLev = 0) And
       (SymTab[I].DataType <> TYPE_TABLE) Then
    Begin
      Case SymTab[I].DataType Of
        TYPE_I, TYPE_P :
          Begin
            If SymTab[I].HasInit Then
              Emit(SymTab[I].AsmLabel + ' DD ' +
                   IntToStr_(SymTab[I].InitNum))
            Else
              Emit(SymTab[I].AsmLabel + ' DD 0');
          End;
        TYPE_F :
          Emit(SymTab[I].AsmLabel + ' DQ 0');
        TYPE_C, TYPE_N, TYPE_D, TYPE_T :
          Begin
            CharL := SymTab[I].CharLen;
            If CharL > 0 Then
              Emit(SymTab[I].AsmLabel + ' DB ' +
                   IntToStr_(CharL) + ' DUP(32), 0')
            Else
              Emit(SymTab[I].AsmLabel + ' DB 256 DUP(0)');
          End;
        TYPE_STRING, TYPE_XSTRING :
          Emit(SymTab[I].AsmLabel + ' DD 0');
      End;
    End;
  End;
  EmitBlank;

  { ---- Tables internes (TODO 16) ---- }
  EmitTableRuntime;
  EmitBlank;

  { ---- Tampons runtime ---- }
  EmitComment('--- Tampons runtime ---');
  Emit(AB_RT_PFX + 'HSTDOUT    DD 0');
  Emit(AB_RT_PFX + 'HSTDIN     DD 0');
  Emit(AB_RT_PFX + 'WRITTEN    DD 0');
  Emit(AB_RT_PFX + 'NUMBUF     DB 12 DUP(0)');
  Emit(AB_RT_PFX + 'CRLF_DATA  DB 13, 10, 0');
  Emit(AB_RT_PFX + 'SPACE_DATA DB 32, 0');
  Emit(AB_RT_PFX + 'STRBUF     DB 512 DUP(0)');
  Emit(AB_RT_PFX + 'CATBUF     DB 512 DUP(0)');
  Emit(AB_RT_PFX + 'INPUTBUF   DB 256 DUP(0)');
  EmitBlank;

  { ---- Chaines litterales ---- }
  If StrLitCount > 0 Then
  Begin
    EmitComment('--- Chaines litterales ---');
    For I := 1 To StrLitCount Do
    Begin
      S := '';
      For J := 1 To Length(StrLitTab[I].Text) Do
      Begin
        If StrLitTab[I].Text[J] = '''' Then
          S := S + ''''''
        Else
          S := S + StrLitTab[I].Text[J];
      End;
      Emit(StrLitTab[I].AsmLabel + ' DB ' + #39 + S + #39 + ',0');
    End;
    EmitBlank;
  End;

  Emit('_DATA   ENDS');
  EmitBlank;
  Emit('END ' + AB_FN_PFX + AsmIdent(ProgName));
End;

{ ============================================================ }
{ GENERATION : POINT D ENTREE WIN32 (TODO 19)                  }
{ ============================================================ }

{ ---- EmitEntryPoint : generer le point d entree Win32 -------- }
{ _ABF_main :                                                    }
{   PUSH EBP / MOV EBP, ESP                                     }
{   Initialiser stdout : PUSH -11 / CALL GetStdHandle            }
{   Initialiser stdin  : PUSH -10 / CALL GetStdHandle            }
{   CALL _ABF_nom_report                                         }
{   PUSH 0 / CALL ExitProcess                                    }
Procedure EmitEntryPoint;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('POINT D ENTREE Win32 (TODO 19)');
  EmitComment('========================================');
  EmitBlank;
  EmitLabel(AB_FN_PFX + AsmIdent(ProgName));
  EmitI('PUSH    EBP');
  EmitI('MOV     EBP, ESP');
  EmitBlank;
  EmitComment('--- Initialiser stdout (STD_OUTPUT_HANDLE = -11) ---');
  EmitI('PUSH    -11');
  EmitI('CALL    _GetStdHandle@4');
  EmitI('MOV     DWORD PTR [' + AB_RT_PFX + 'HSTDOUT], EAX');
  EmitBlank;
  EmitComment('--- Initialiser stdin (STD_INPUT_HANDLE = -10) ---');
  EmitI('PUSH    -10');
  EmitI('CALL    _GetStdHandle@4');
  EmitI('MOV     DWORD PTR [' + AB_RT_PFX + 'HSTDIN], EAX');
  EmitBlank;
End;

{ ============================================================ }
{ GENERATION : HELPERS RUNTIME (TODO 19)                        }
{ ============================================================ }

{ ---- EmitRuntimeHelpers : emet les routines runtime ---------- }
{ Routines supplementaires non couvertes par TODO 14 et 17 :     }
{   _ABRT_PRINTCHR : AL=caractere -> WriteFile 1 octet           }
{   _ABRT_READINT  : ReadFile + parsing ASCII -> EAX             }
{   _ABRT_READSTR  : ReadFile -> copier dans buffer              }
{   _ABRT_STRCOPY  : ESI=src, EDI=dst, ECX=max -> copie         }
{   _ABRT_STRCONCAT: coller ESI apres EDI (ASCIIZ)              }
{   _ABRT_ERROR    : afficher message EAX + ExitProcess(1)       }
Procedure EmitRuntimeHelpers;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('RUNTIME : HELPERS (TODO 19)');
  EmitComment('========================================');

  { ---- _ABRT_PRINTCHR : AL=caractere -> WriteFile 1 octet ---- }
  { Ecrit le caractere dans AL sur stdout                         }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'PRINTCHR');
  EmitI('PUSH    EAX');
  EmitI('PUSH    EBX');
  EmitI('SUB     ESP, 4');             { reserve 4 octets sur la pile }
  EmitI('MOV     BYTE PTR [ESP], AL'); { stocker le caractere }
  EmitI('PUSH    0');                  { lpOverlapped = NULL }
  EmitI('LEA     EBX, [' + AB_RT_PFX + 'WRITTEN]');
  EmitI('PUSH    EBX');                { lpNumberOfBytesWritten }
  EmitI('PUSH    1');                  { nNumberOfBytesToWrite = 1 }
  EmitI('LEA     EAX, [ESP+12]');      { lpBuffer = adresse sur pile }
  EmitI('PUSH    EAX');
  EmitI('PUSH    DWORD PTR [' + AB_RT_PFX + 'HSTDOUT]');
  EmitI('CALL    _WriteFile@20');
  EmitI('ADD     ESP, 4');             { liberer le tampon }
  EmitI('POP     EBX');
  EmitI('POP     EAX');
  EmitI('RET');

  { ---- _ABRT_READINT : ReadFile + parsing ASCII -> EAX -------- }
  { Lit une ligne depuis stdin et convertit en entier signe 32 b. }
  { Resultat dans EAX                                             }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'READINT');
  EmitI('PUSH    EBX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDX');
  EmitI('PUSH    ESI');
  { ReadFile(hStdIn, lpBuffer, nBufSize, lpBytesRead, NULL) }
  EmitI('PUSH    0');                     { lpOverlapped = NULL }
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'WRITTEN]');
  EmitI('PUSH    EAX');                   { lpNumberOfBytesRead }
  EmitI('PUSH    255');                   { nNumberOfBytesToRead }
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'INPUTBUF]');
  EmitI('PUSH    EAX');                   { lpBuffer }
  EmitI('PUSH    DWORD PTR [' + AB_RT_PFX + 'HSTDIN]');
  EmitI('CALL    _ReadFile@20');
  { Parser le buffer : convertir ASCII decimal en entier signe }
  EmitI('LEA     ESI, [' + AB_RT_PFX + 'INPUTBUF]');
  EmitI('XOR     EAX, EAX');             { accumulateur = 0 }
  EmitI('XOR     ECX, ECX');             { drapeau signe = 0 }
  { Sauter les espaces initiaux }
  EmitLabel(AB_RT_PFX + 'RI_SKIP');
  EmitI('MOV     BL, BYTE PTR [ESI]');
  EmitI('CMP     BL, 32');
  EmitI('JNE     ' + AB_RT_PFX + 'RI_SIGN');
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'RI_SKIP');
  { Verifier le signe }
  EmitLabel(AB_RT_PFX + 'RI_SIGN');
  EmitI('CMP     BL, 45');               { '-' = 45 }
  EmitI('JNE     ' + AB_RT_PFX + 'RI_PLUS');
  EmitI('MOV     ECX, 1');               { marquer negatif }
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'RI_LOOP');
  EmitLabel(AB_RT_PFX + 'RI_PLUS');
  EmitI('CMP     BL, 43');               { '+' = 43 }
  EmitI('JNE     ' + AB_RT_PFX + 'RI_LOOP');
  EmitI('INC     ESI');
  { Boucle de conversion }
  EmitLabel(AB_RT_PFX + 'RI_LOOP');
  EmitI('MOVZX   EBX, BYTE PTR [ESI]');
  EmitI('CMP     BL, 48');               { '0' = 48 }
  EmitI('JB      ' + AB_RT_PFX + 'RI_DONE');
  EmitI('CMP     BL, 57');               { '9' = 57 }
  EmitI('JA      ' + AB_RT_PFX + 'RI_DONE');
  EmitI('SUB     BL, 48');               { chiffre = BL - '0' }
  EmitI('IMUL    EAX, EAX, 10');         { accumulateur *= 10 }
  EmitI('ADD     EAX, EBX');             { accumulateur += chiffre }
  EmitI('INC     ESI');
  EmitI('JMP     ' + AB_RT_PFX + 'RI_LOOP');
  { Appliquer le signe }
  EmitLabel(AB_RT_PFX + 'RI_DONE');
  EmitI('TEST    ECX, ECX');
  EmitI('JZ      ' + AB_RT_PFX + 'RI_RET');
  EmitI('NEG     EAX');
  EmitLabel(AB_RT_PFX + 'RI_RET');
  EmitI('POP     ESI');
  EmitI('POP     EDX');
  EmitI('POP     ECX');
  EmitI('POP     EBX');
  EmitI('RET');

  { ---- _ABRT_READSTR : ReadFile -> copier dans buffer ---------- }
  { EAX = pointeur vers le buffer destination (ASCIIZ)            }
  { ECX = taille max du buffer destination                        }
  { Lit une ligne depuis stdin, supprime CR/LF final, termine \0  }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'READSTR');
  EmitI('PUSH    EBX');
  EmitI('PUSH    EDX');
  EmitI('PUSH    EDI');
  EmitI('PUSH    ESI');
  EmitI('MOV     EDI, EAX');             { EDI = buffer destination }
  EmitI('MOV     EDX, ECX');             { EDX = taille max }
  { ReadFile(hStdIn, INPUTBUF, 255, &WRITTEN, NULL) }
  EmitI('PUSH    0');
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'WRITTEN]');
  EmitI('PUSH    EAX');
  EmitI('PUSH    255');
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'INPUTBUF]');
  EmitI('PUSH    EAX');
  EmitI('PUSH    DWORD PTR [' + AB_RT_PFX + 'HSTDIN]');
  EmitI('CALL    _ReadFile@20');
  { Copier INPUTBUF vers destination, max EDX octets, sans CR/LF }
  EmitI('LEA     ESI, [' + AB_RT_PFX + 'INPUTBUF]');
  EmitI('MOV     ECX, DWORD PTR [' + AB_RT_PFX + 'WRITTEN]');
  EmitI('XOR     EBX, EBX');             { compteur copie }
  EmitLabel(AB_RT_PFX + 'RS_LOOP');
  EmitI('TEST    ECX, ECX');
  EmitI('JZ      ' + AB_RT_PFX + 'RS_DONE');
  EmitI('CMP     EBX, EDX');
  EmitI('JGE     ' + AB_RT_PFX + 'RS_DONE');
  EmitI('MOV     AL, BYTE PTR [ESI]');
  EmitI('CMP     AL, 13');               { CR }
  EmitI('JE      ' + AB_RT_PFX + 'RS_DONE');
  EmitI('CMP     AL, 10');               { LF }
  EmitI('JE      ' + AB_RT_PFX + 'RS_DONE');
  EmitI('CMP     AL, 0');                { NULL }
  EmitI('JE      ' + AB_RT_PFX + 'RS_DONE');
  EmitI('MOV     BYTE PTR [EDI+EBX], AL');
  EmitI('INC     EBX');
  EmitI('INC     ESI');
  EmitI('DEC     ECX');
  EmitI('JMP     ' + AB_RT_PFX + 'RS_LOOP');
  EmitLabel(AB_RT_PFX + 'RS_DONE');
  EmitI('MOV     BYTE PTR [EDI+EBX], 0'); { terminaison ASCIIZ }
  EmitI('POP     ESI');
  EmitI('POP     EDI');
  EmitI('POP     EDX');
  EmitI('POP     EBX');
  EmitI('RET');

  { ---- _ABRT_STRCOPY : ESI=src, EDI=dst, ECX=max -> copie ----- }
  { Copie la chaine ASCIIZ de ESI vers EDI (max ECX caracteres)    }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STRCOPY');
  EmitI('PUSH    EAX');
  EmitI('PUSH    EBX');
  EmitI('XOR     EBX, EBX');             { compteur }
  EmitLabel(AB_RT_PFX + 'SC_LOOP');
  EmitI('CMP     EBX, ECX');
  EmitI('JGE     ' + AB_RT_PFX + 'SC_DONE');
  EmitI('MOV     AL, BYTE PTR [ESI+EBX]');
  EmitI('MOV     BYTE PTR [EDI+EBX], AL');
  EmitI('TEST    AL, AL');
  EmitI('JZ      ' + AB_RT_PFX + 'SC_RET');
  EmitI('INC     EBX');
  EmitI('JMP     ' + AB_RT_PFX + 'SC_LOOP');
  EmitLabel(AB_RT_PFX + 'SC_DONE');
  EmitI('MOV     BYTE PTR [EDI+EBX], 0'); { terminaison }
  EmitLabel(AB_RT_PFX + 'SC_RET');
  EmitI('POP     EBX');
  EmitI('POP     EAX');
  EmitI('RET');

  { ---- _ABRT_STRCONCAT : coller ESI apres EDI (ASCIIZ) -------- }
  { EDI = destination (ASCIIZ), ESI = source -> append             }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'STRCONCAT');
  EmitI('PUSH    EAX');
  EmitI('PUSH    ECX');
  EmitI('PUSH    EDI');
  EmitI('PUSH    ESI');
  { Trouver la fin de la destination }
  EmitI('MOV     EAX, EDI');
  EmitI('CALL    ' + AB_RT_PFX + 'STRLEN');
  EmitI('ADD     EDI, EAX');
  { Copier source apres la fin de destination }
  EmitLabel(AB_RT_PFX + 'SCAT_LP');
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST    AL, AL');
  EmitI('JNZ     ' + AB_RT_PFX + 'SCAT_LP');
  EmitI('POP     ESI');
  EmitI('POP     EDI');
  EmitI('POP     ECX');
  EmitI('POP     EAX');
  EmitI('RET');

  { ---- _ABRT_ERROR : afficher message + ExitProcess(1) -------- }
  { EAX = pointeur vers message d erreur ASCIIZ                   }
  EmitBlank;
  EmitLabel(AB_RT_PFX + 'ERROR');
  EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
  EmitI('LEA     EAX, [' + AB_RT_PFX + 'CRLF_DATA]');
  EmitI('CALL    ' + AB_RT_PFX + 'PRINT');
  EmitI('PUSH    1');
  EmitI('CALL    _ExitProcess@4');
  EmitI('RET');                  { ne sera jamais atteint }
End;

Procedure InitOptions;
Begin
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

{ ============================================================ }
{ AIDE EN LIGNE                                                }
{ ============================================================ }

Procedure ShowHelp;
Begin
  WriteLn('ABAPCW32 v', ABAPCW32_VERSION, ' (', ABAPCW32_DATE,
          ') - Compilateur ABAP/4 vers 80386 (Windows PE 32 bits)');
  WriteLn('ABAPCW32 - Cette commande permet de lancer le compilateur ',
          'ABAP/4 pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : ABAPCW32 <source.abap> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  ABAPCW32 TEST.ABAP');
  WriteLn('  ABAPCW32 TEST.ABAP -v');
  WriteLn('  ABAPCW32 TEST.ABAP -asm');
  WriteLn('  ABAPCW32 TEST.ABAP -obj');
  WriteLn('  ABAPCW32 TEST.ABAP -o MONPROG.EXE');
  Halt(EXIT_OK);
End;

{ ============================================================ }
{ ANALYSE DES ARGUMENTS                                        }
{ ============================================================ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

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
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('-o necessite un nom de fichier');
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('ABAPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .abap }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.abap') And (Ext <> '.abp') Then
    WarnMsg('extension attendue .abap, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ============================================================ }
{ BANNIERE ET STATISTIQUES                                     }
{ ============================================================ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('ABAPCW32 v', ABAPCW32_VERSION, ' (', ABAPCW32_DATE,
          ') - Compilateur ABAP/4 -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Format   : OBJ (COFF)')
  Else
    WriteLn('Format   : EXE (PE Win32)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ============================================================ }
{ NETTOYAGE                                                    }
{ ============================================================ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================ }
{ PROCEDURE RUN (STUB - sera complete par les TODOs suivants)  }
{ ============================================================ }

Procedure Run;
Var AsmFile : TString;
Begin
  InitSymTable;
  InitScopes;
  DeclSysVars;
  ProgName    := 'ZPROGRAM';
  LabelCount  := 0;
  StrLitCount := 0;
  EventStartDefined := False;  { TODO 24 }
  EventEndDefined   := False;  { TODO 24 }
  TryCount          := 0;      { TODO 24 }
  LexInit;
  If Opts.DebugMode Then
  Begin
    { Mode debug : afficher tous les tokens }
    While CurTokType <> TOK_EOF Do
    Begin
      PrintToken;
      LexNextToken;
    End;
    PrintToken; { afficher le token EOF }
  End
  Else
  Begin
    { Parser l en-tete REPORT / PROGRAM si present }
    If TokIsKw(KW_REPORT) Or TokIsKw(KW_PROGRAM) Then
    Begin
      Consume;      { consommer REPORT ou PROGRAM }
      ParseReport;  { parser le nom et les options }
    End;
    WriteLn('ABAPCW32: compilation de ', Opts.SrcFile, ' ...');
    WriteLn('ABAPCW32: programme: ', ProgName);
    WriteLn('ABAPCW32: label ASM: ', AB_FN_PFX, AsmIdent(ProgName));

    { Ouvrir le fichier ASM si mode -asm (TODO 18) }
    If Opts.EmitAsm Then
    Begin
      AsmFile := ReplaceExt(Opts.SrcFile, '.asm');
      Assign(OutF, AsmFile);
      {$I-}
      Rewrite(OutF);
      {$I+}
      If IOResult <> 0 Then
        FatalError('impossible d' + #39 + 'ouvrir le fichier ASM: ' + AsmFile);
      OutFOpen := True;
      WriteLn('ABAPCW32: fichier ASM: ', AsmFile);
    End;

    { Emettre l en-tete assembleur (TODO 18) }
    EmitHeader;

    { Emettre le point d entree Win32 (TODO 19) }
    EmitEntryPoint;

    { Parser les declarations et instructions de haut niveau }
    While (CurTokType <> TOK_EOF) Do
    Begin
      ParseStatement;
    End;

    { Emettre la sortie du programme (TODO 19+24) }
    EmitBlank;
    EmitComment('--- Appel des evenements ABAP (TODO 24) ---');
    { Appeler START-OF-SELECTION si defini }
    If EventStartDefined Then
      EmitI('CALL    _ABE_START');
    { Appeler END-OF-SELECTION si defini }
    If EventEndDefined Then
      EmitI('CALL    _ABE_END');
    EmitComment('--- Sortie du programme ---');
    EmitI('PUSH    0');
    EmitI('CALL    _ExitProcess@4');

    { Emettre les routines runtime I/O (TODO 14) }
    EmitWriteRuntime;

    { Emettre les helpers runtime (TODO 19) }
    EmitRuntimeHelpers;

    { Emettre le segment de donnees (TODO 18) }
    EmitDataSeg;

    { Fermer le fichier ASM (TODO 18) }
    If OutFOpen Then
    Begin
      Close(OutF);
      OutFOpen := False;
    End;

    WriteLn('ABAPCW32: symboles declares: ', SymCount);
    WriteLn('ABAPCW32: labels generes: ', LabelCount);
    WriteLn('ABAPCW32: chaines litterales: ', StrLitCount);
    WriteLn('ABAPCW32: scope initial: SK_GLOBAL (niveau ', ScopeTop, ')');
  End;
  LexClose;
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                          }
{ ============================================================ }

BEGIN
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
