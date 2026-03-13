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

  TODO 12 - PARSEUR : WHILE / ENDWHILE ET DO n TIMES / ENDDO
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

  TODO 13 - PARSEUR : PERFORM / FORM / ENDFORM (SOUS-ROUTINES 32 BITS)
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

  TODO 14 - PARSEUR : WRITE / SKIP / NEW-LINE (SORTIE CONSOLE WIN32)
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

  TODO 15 - PARSEUR : MOVE / COMPUTE / FORMES VERBALES ARITHMETIQUES
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

  TODO 16 - PARSEUR : LOOP AT / ENDLOOP + OPERATIONS TABLES INTERNES
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

  TODO 17 - PARSEUR : OPERATIONS SUR CHAINES DE CARACTERES
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

  TODO 18 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA
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

  TODO 19 - GENERATION : POINT D ENTREE WIN32 ET HELPERS RUNTIME
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

  TODO 20 - PARSEUR : CLEAR / REFRESH / FREE / CHECK / EXIT / CONTINUE
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

  TODO 21 - PARSEUR : SELECT / ENDSELECT (ACCES BD, STUB SANS BD)
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

  TODO 22 - PARSEUR : CALL FUNCTION / FUNCTION / ENDFUNCTION (STUBS)
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

  TODO 23 - PARSEUR : DISPATCHER ET BOUCLE PRINCIPALE
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

  TODO 24 - PARSEUR : EVENEMENTS ABAP ET ECRAN DE SELECTION (STUBS)
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
  { Pour l'instant, ecriture vers WriteLn (sera redirige vers OutF
    quand TODO 09 implementera l'emetteur binaire/ASM complet.)    }
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

  { COMPUTE var = expr. }
  If TokIsKw(KW_COMPUTE) Then
  Begin
    Consume;
    ExprType := ParseExpr;
    If CurTokType = TOK_DOT Then Consume;
    Exit;
  End;

  { IF / ELSEIF / ELSE / ENDIF }
  If TokIsKw(KW_IF) Then
  Begin Consume; ParseIf; Exit; End;

  { CASE / WHEN / ENDCASE }
  If TokIsKw(KW_CASE) Then
  Begin Consume; ParseCase; Exit; End;

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
    ParseAndExpr;
    EmitI('CMP     EDX, EAX');

    { Valeurs supplementaires separees par OR }
    While TokIsKw(KW_OR) Do
    Begin
      EmitI('JE      ' + LblBody); { correspond -> sauter au corps }
      Consume; { skip OR }
      ParseAndExpr; { valeur suivante -> EAX }
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
Begin
  InitSymTable;
  InitScopes;
  DeclSysVars;
  ProgName    := 'ZPROGRAM';
  LabelCount  := 0;
  StrLitCount := 0;
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
    { Parser les declarations et instructions de haut niveau }
    While (CurTokType <> TOK_EOF) Do
    Begin
      ParseStatement;
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
