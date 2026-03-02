{ ============================================================================
  CSC86.PAS - Compilateur C# (sous-ensemble) -> Assembleur MASM 8086
  Version 1.0  -  Free Pascal / Turbo Pascal compatible
  ============================================================================

  DESCRIPTION
  -----------
  CSC86 traduit un sous-ensemble de C# en assembleur MASM 8086 (16 bits).
  Le sous-ensemble cible (C# Lite) couvre :
    - Types primitifs : int, bool, char, string (pointeur + longueur)
    - Variables locales et globales statiques (static)
    - Expressions arithmetiques : + - * / % (entiers signes 16 bits)
    - Expressions booleennes  : && || ! == != < <= > >=
    - Instructions : if/else, while, for, do-while, break, continue, return
    - Methodes statiques (sans surcharge), class statique
    - E/S : Console.Write / Console.WriteLine / Console.ReadLine
    - Tableaux unidimensionnels de int et char (allocation statique)
    - Chaines litterales (stockees dans .DATA)
    - Commentaires // et /* ... */

  ARCHITECTURE (deux passes, analogue a SNOBOL86)
  -----------------------------------------------
    Passe 1 : lecture + analyse lexicale + analyse syntaxique
              construction des tables (symboles, litteraux, fonctions).
    Passe 2 : generation du code ASM (DATA, CODE, STACK).

  CONVENTION D'APPEL (near cdecl, 16 bits)
  -----------------------------------------
    - Arguments : push droite -> gauche, caller cleanup
    - [BP+0] = ancien BP, [BP+2] = adresse retour, [BP+4] = arg1, ...
    - Valeur de retour : AX (int/bool/char) ou DX:AX (pointeur string)
    - Registres preserves : BP, SI, DI, DS, SS

  MODELE MEMOIRE : SMALL (DS=SS, CS separe)
  Entree du programme : label START dans le segment _CODE

  ============================================================================

  PLAN DE DEVELOPPEMENT - 25 TODOS
  =================================

  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES DU COMPILATEUR
  --------------------------------------------------------------------------
  Definir les types Pascal fondamentaux :
    TString     = String[255]
    TSymKind    = (SK_VAR, SK_PARAM, SK_FUNC, SK_CLASS, SK_CONST, SK_TYPE)
    TValueKind  = (VK_INT, VK_BOOL, VK_CHAR, VK_STRING, VK_VOID, VK_ARRAY)
    TScope      = (SC_GLOBAL, SC_LOCAL, SC_PARAM)
    TTokenKind  = (TK_IDENT, TK_INT, TK_STRING, TK_CHAR, TK_KEYWORD,
                   TK_OP, TK_PUNCT, TK_EOF, TK_UNKNOWN)
    TToken      = record kind, val, line, col
    TSymEntry   = record name, kind, vtype, scope, bp_offset, asm_label,
                         array_size, is_static
    TFuncEntry  = record name, return_type, param_count, params[],
                         local_frame_size, asm_label
    TLitEntry   = record val, asm_label (pour chaines)
  Constantes : MAX_SYM, MAX_FUNC, MAX_LIT, MAX_LOCAL, SB_DATA_PFX, etc.
  Variables globales : sym_table, func_table, lit_table, sym_count,
                       func_count, lit_count, lbl_seq, cur_func_idx.
  Infrastructure fichiers (in_file, out_file, tmp_file).

  TODO 02 - LEXEUR (ANALYSE LEXICALE C#)
  ----------------------------------------
  Implementer l'analyseur lexical C# :
    LexInit       : ouvrir le fichier source, initialiser l'etat.
    LexReadChar   : lecture d'un caractere, gestion LF/CR, compteur lignes.
    LexSkipWS     : espaces, tabulations, commentaires // et /* ... */.
    LexReadIdent  : identifiant ou mot-cle [a-zA-Z_][a-zA-Z0-9_]*.
    LexReadNumber : entier decimal (et hex 0x...), suffixes u/l/ul.
    LexReadString : chaine "" avec sequences d'echappement \n \t \\ \".
    LexReadChar2  : char litteral '' avec sequences d'echappement.
    LexReadOp     : operateurs mono/bicaracteres (++, --, +=, ==, !=, <=, ...).
    LexNext       : produire le prochain token (TToken).
    LexPeek       : consulter le prochain token sans le consommer.
    LexExpect     : consommer un token attendu, erreur sinon.
  Mots-cles reconnus : int bool char string void static class new if else
                       while for do break continue return true false null
                       Console using namespace public private.

  TODO 03 - TABLES DE SYMBOLES ET DE FONCTIONS
  -----------------------------------------------
  Gestion des tables de compilation :
    FindSym    : rechercher une variable par nom dans la portee courante
                 puis globale.
    AddSym     : ajouter un symbole (variable/parametre/constante).
    FindFunc   : rechercher une fonction par nom.
    AddFunc    : enregistrer une entree de fonction.
    AddLiteral : enregistrer une chaine litterale, retourner son index.
    LitAsmLabel: generer l'etiquette DATA d'un litteral.
    NewLabel   : generateur de labels auto @@Lxx.
    AsmSafeIdent: nettoyer un identifiant C# pour ASM (points -> underscores).
    ScopeEnter / ScopeLeave : empiler/depiler le niveau de portee.
    ResetLocals : reinitialiser les locaux d'une nouvelle fonction.

  TODO 04 - INFRASTRUCTURE D'EMISSION ASM
  -----------------------------------------
  Procedures d'ecriture dans le fichier de sortie :
    Emit        : ecrire une ligne brute.
    EmitI       : ecrire une instruction ASM indentee.
    EmitLabel   : ecrire un label suivi de ':'.
    EmitComment : ecrire un commentaire '; ...'.
    EmitSep     : ecrire une ligne de separation '; ---...'.
    EmitBlank   : ecrire une ligne vide.
    EmitDB      : ecrire une directive DB (donnees octets).
    EmitDW      : ecrire une directive DW (donnees mots).
    EmitEQU     : ecrire une directive EQU.
    SetFirstInstrLabel / first_instr_lbl : gestion du label d'entree.

  TODO 05 - GENERATION DE L'EN-TETE ET DU SEGMENT .STACK
  ---------------------------------------------------------
  GenHeader : emettre l'en-tete MASM 8086 :
    .8086 / DOSSEG / MODEL SMALL / STACK 512
    Inclure les macro-definitions necessaires.
    Emettre le segment _STACK avec DW 256 DUP(?).
  GenStackSegment : reserve 512 octets de pile (256 DW ?).

  TODO 06 - GENERATION DU SEGMENT .DATA (VARIABLES GLOBALES)
  ------------------------------------------------------------
  GenDataSegment (passe 2) :
    - Pour chaque symbole SK_VAR SC_GLOBAL : emettre label_D DW 0 / DB / ARRAY.
    - Pour chaque litteral string : emettre _SL_xx DB 'texte', 0 + _SLD_xx DW.
    - Variables systeme : _CS86_CRLF_BUF, _CS86_INPUTBUF (128 octets),
      _CS86_ITOA_BUF (8 octets), _CS86_TRUE_STR, _CS86_FALSE_STR.
    - Descripteurs de chaines (ptr + len, 2 DW chacun).
    - Tableaux statiques.

  TODO 07 - PARSER : DECLARATIONS DE TYPES ET VARIABLES
  -------------------------------------------------------
  ParseTypeSpec    : reconnaitre int / bool / char / string / void
                     et les tableaux type[] (allocation taille fixe en C# Lite).
  ParseVarDecl     : 'type ident [= expr] ;'
                     Gerer : int x; int x = 5; int[] arr = new int[10];
                     Appeler AddSym, calculer bp_offset pour les locaux.
  ParseConstDecl   : 'const type ident = expr ;'
                     Evaluer l'expression en temps de compilation (entier).
  ParseParamList   : lire '(type id, type id, ...)' et remplir func params.
  IsTypeKeyword    : True si le token courant est int/bool/char/string/void.

  TODO 08 - PARSER : EXPRESSIONS (PRECEDENCE COMPLETE)
  -----------------------------------------------------
  Implementer un parseur descendant recursif pour les expressions C# :
    ParseExpr        : niveau OR '||'
    ParseExprAnd     : niveau AND '&&'
    ParseExprEq      : == !=
    ParseExprRel     : < <= > >=
    ParseExprAdd     : + -
    ParseExprMul     : * / %
    ParseExprUnary   : ! - (cast) ++ -- (prefix)
    ParseExprPostfix : appel de fonction, indexation [], ++/-- postfix
    ParseExprPrimary : litteral int/bool/char/string, identifiant,
                       '(' expr ')', new type[n]
  Chaque noeud produit un code intermediaire vers DI/AX.

  TODO 09 - PARSER : INSTRUCTIONS SIMPLES
  -----------------------------------------
  ParseStatement : dispatcher principal :
    ParseBlock       : '(* stmt* *)'  -- bloc C#
    ParseIf          : 'if (expr) stmt [else stmt]'
    ParseWhile       : 'while (expr) stmt'
    ParseFor         : 'for (init; cond; incr) stmt'
    ParseDoWhile     : 'do stmt while (expr) ;'
    ParseBreak       : 'break ;' -> JMP label_break
    ParseContinue    : 'continue ;' -> JMP label_continue
    ParseReturn      : 'return [expr] ;'
    ParseExprStmt    : expression seule (affectation, appel) + ';'
  Gestion de boucles imbriquees : pile de labels break/continue.

  TODO 10 - PARSER : METHODES ET CLASSES STATIQUES
  --------------------------------------------------
  ParseClassDecl    : 'class Ident ( member* )'  -- membres statiques
                      Reconnaître uniquement les classes avec membres statiques.
  ParseMethodDecl   : '[static] type Ident (params) block'
                      Enregistrer dans func_table, calculer la taille du frame.
  ParseProgram      : point d'entree du parseur :
                      ParseUsings -> ParseNamespace -> ParseClassDecl.
  ParseUsings       : consommer 'using ...' sans generer de code.
  ParseNamespace    : consommer 'namespace ...' sans generer de code.
  DetectEntryPoint  : identifier la methode 'static void Main(...)'.

  TODO 11 - CODEGEN : EXPRESSIONS ENTIERS ET BOOLEENS
  -----------------------------------------------------
  EvalExprToAX   : generer le code ASM pour une expression entiere -> AX.
  EvalExprToDI   : idem mais resultat dans DI (pour les chaines).
  EvalBoolExpr   : generer code pour bool -> AX (0 ou 1).
  GenCompare     : emettre CMP + Jxx -> AX = 0 ou 1 selon operateur.
  GenArith       : +/-: ADD/SUB AX,BX ; *: CALL _RT_IMUL ; /:%: CALL _RT_IDIV.
  GenLogical     : && -> code court-circuit (JZ), || -> code court-circuit (JNZ).
  GenNot         : XOR AX, 1 (bool) ou NEG AX (entier).
  GenIntLiteral  : MOV AX, val.
  GenBoolLiteral : MOV AX, 1 / XOR AX, AX.

  TODO 12 - CODEGEN : ACCES AUX VARIABLES
  -----------------------------------------
  GenLoadVar    : charger la valeur d'une variable dans AX (int/bool/char)
                  ou DI (string).
                  Globale  -> MOV AX, [_G_NOM]
                  Locale   -> MOV AX, [BP - offset]
                  Parametre-> MOV AX, [BP + offset]
  GenStoreVar   : stocker AX / DI dans une variable.
  GenLoadArray  : LEA SI, [base] ; ajouter index*2 ; MOV AX, [SI].
  GenStoreArray : calculer adresse ; MOV [SI], AX.
  GenAddrOf     : calculer l'adresse effective (pour tableaux).

  TODO 13 - CODEGEN : AFFECTATION ET AFFECTATION COMPOSEE
  ---------------------------------------------------------
  GenAssign      : x = expr -> EvalExprToAX + GenStoreVar.
  GenAssignOp   : x += expr, x -= expr, x *= expr, x /= expr, x %= expr.
  GenIncDec     : x++ / x-- / ++x / --x  -> INC/DEC [var].
  Gestion des affectations de chaines : copie de descripteur (ptr + len).
  Affectation d'element de tableau : arr[i] = expr.

  TODO 14 - CODEGEN : INSTRUCTIONS DE CONTROLE
  ----------------------------------------------
  GenIf         : evaluer condition -> JZ/JNZ + labels then/else/endif.
  GenWhile      : label_top -> cond -> JZ label_end -> body -> JMP label_top.
  GenFor        : init -> label_top -> cond -> JZ end -> body -> incr -> JMP top.
  GenDoWhile    : label_top -> body -> cond -> JNZ label_top.
  GenBreak      : JMP label_break courant.
  GenContinue   : JMP label_continue courant.
  GenReturn     : [charger valeur dans AX/DX:AX] + epilogue + RET.
  Pile de contexte de boucle : break_stack, continue_stack.

  TODO 15 - CODEGEN : ENTREES / SORTIES (Console.*)
  ---------------------------------------------------
  Generer les appels a Console.Write et Console.WriteLine :
    Console.Write(int)     -> _RT_INT2STR + _RT_WRITESTR (pas de CRLF)
    Console.Write(bool)    -> AX -> 'True'/'False' -> _RT_WRITESTR
    Console.Write(char)    -> INT 21h AH=02h
    Console.Write(string)  -> _RT_WRITESTR (ptr + len dans DS)
    Console.WriteLine(...)  -> idem + CRLF (_RT_WRITECRLF)
    Console.ReadLine()     -> _RT_READLINE -> DX:AX (ptr + len)
    Console.ReadLine (int) -> _RT_READLINE + _RT_STR2INT -> AX
  Patterns de detection pendant le parsing : 'Console' '.' 'Write[Line]' '('.

  TODO 16 - CODEGEN : GESTION DES CHAINES
  -----------------------------------------
  Modele de chaine : descripteur 2 DW [ ptr, len ].
  _RT_STRLEN    : SI = ptr, CX = len -> CX.
  _RT_STRCAT    : DI + SI -> ds:dx descripteur chaine concatenee.
  _RT_STRCMP    : SI + DI -> flags (ZF = egal).
  _RT_STR2INT   : SI, CX -> AX (entier signe).
  _RT_INT2STR   : AX -> DX:AX (ptr + len dans buf temporaire).
  _RT_WRITESTR  : DX = ptr, CX = len -> INT 21h AH=40h handle 1.
  _RT_WRITECRLF : ecrire $0D $0A.
  _RT_READLINE  : INT 21h AH=0Ah -> DX:AX (ptr + len dans _CS86_INPUTBUF).
  Concatenation '+' entre chaines : CALL _RT_STRCAT.
  Comparaison == entre chaines : CALL _RT_STRCMP + flags.

  TODO 17 - CODEGEN : TABLEAUX
  ------------------------------
  Allocation statique des tableaux en .DATA :
    int[] arr = new int[N] -> _G_ARR DW N DUP(0).
  Acces en lecture  : arr[i] -> LEA BX,[base] + AX=[BX+SI*2].
  Acces en ecriture : arr[i] = v -> [BX+SI*2] = AX.
  Verification de bornes (optionnel v1 : desactivee par defaut).
  Chaines de tableaux de char (char[]).
  Propriete .Length -> stocker la taille dans un DW supplementaire.

  TODO 18 - CODEGEN : FONCTIONS ET APPELS
  -----------------------------------------
  GenFunctionPrologue : PUSH BP / MOV BP,SP / SUB SP, frame_size.
  GenFunctionEpilogue : MOV SP,BP / POP BP / RET (caller cleanup).
  GenFunctionCall     : PUSH args (droite -> gauche) + CALL label
                        + ADD SP, n*2 (caller cleanup).
  GenReturn           : charger AX [+ DX pour ptr] + epilogue + RET.
  Convention de retour par valeur :
    int/bool/char -> AX
    string        -> DX = ptr, AX = len
    void          -> rien
  Recursivite : supporter les appels recursifs (frame independant).
  Predeclaration obligatoire (pas de forward implicite en C# Lite).

  TODO 19 - RUNTIME : ARITHMETIQUE ET CONVERSIONS
  -------------------------------------------------
  Emettre dans le segment .CODE les routines runtime :
    _RT_IMUL  : AX * BX -> AX (IMUL BX, clamp 16 bits).
    _RT_IDIV  : AX / BX -> AX, AX mod BX -> DX (IDIV BX).
    _RT_IMOD  : AX % BX -> AX (via IDIV, copier DX -> AX).
    _RT_ABS   : AX -> |AX|.
    _RT_INT2STR : AX -> DX:AX (chaine decimale signee, buf interne).
    _RT_STR2INT : DX:AX (ptr,len) -> AX (entier signe).
    _RT_BOOL2STR: AX (0/1) -> DX:AX 'False'/'True'.
    _RT_ITOA_BUF: buffer de 8 octets pour la conversion.

  TODO 20 - RUNTIME : ENTREES/SORTIES ET GESTION PROGRAMME
  ----------------------------------------------------------
  Emettre les routines I/O dans le segment .CODE :
    _RT_WRITESTR  : DX=ptr, CX=len -> INT 21h AH=40h handle 1.
    _RT_WRITECRLF : ecrire 0Dh 0Ah sur stdout.
    _RT_WRITECHR  : AL -> INT 21h AH=02h.
    _RT_READLINE  : saisie tamponnee INT 21h AH=0Ah -> DX:AX.
    _RT_ERREXIT   : afficher message d'erreur + INT 21h AH=4Ch AL=1.
    _RT_EXIT0     : INT 21h AH=4Ch AL=0 (fin normale).
  GenFooter : emettre le label de fin + appel _RT_EXIT0.
  GenHeader _CODE : emettre START: + initialisation DS/SS.

  TODO 21 - CODEGEN : INITIALISATION ET PIED DE PAGE
  ----------------------------------------------------
  GenCodeHeader  : emettre le prologue du segment .CODE :
                   ASSUME CS:_CODE, DS:_DATA, SS:_STACK
                   START: MOV AX, _DATA / MOV DS, AX / MOV SS, AX
                          MOV SP, OFFSET _STACK_TOP
                          CALL _G_MAIN  (point d'entree C#)
                          CALL _RT_EXIT0
  GenCodeFooter  : emettre le pied de page du segment .CODE :
                   END START
  GenDataHeader  : emettre '_DATA SEGMENT WORD PUBLIC ''DATA'''
  GenDataFooter  : emettre '_DATA ENDS'
  GenStackHeader : emettre '_STACK SEGMENT STACK ''STACK'''
                   DW 256 DUP(?) / _STACK_TOP LABEL WORD
  GenStackFooter : emettre '_STACK ENDS'

  TODO 22 - GESTION DES ERREURS ET DIAGNOSTIC
  ---------------------------------------------
  ErrorMsg   : afficher un message d'erreur avec fichier + ligne + colonne.
  WarnMsg    : afficher un avertissement (continue la compilation).
  ErrorCount / WarnCount : compteurs pour le bilan final.
  FatalError : afficher l'erreur + arreter la compilation proprement.
  Types d'erreurs geres :
    - Erreur lexicale (caractere inattendu, chaine non fermee).
    - Erreur syntaxique (token inattendu).
    - Erreur semantique (variable non declaree, type incompatible).
    - Erreur de debordement de tables (> MAX_SYM, > MAX_FUNC, etc.).
  Mode verbose : option -v pour afficher les instructions parsees.

  TODO 23 - GESTION DES OPTIONS ET INTERFACE LIGNE DE COMMANDE
  -------------------------------------------------------------
  ParseCommandLine : lire ParamStr(1..ParamCount).
  Options reconnues :
    fichier.cs      -> source C# a compiler (obligatoire)
    fichier.asm     -> fichier ASM de sortie (defaut : meme nom + .asm)
    -v              -> mode verbose (afficher statistiques)
    -d              -> mode debug (commentaires supplementaires dans ASM)
    -ns             -> ne pas emettre le runtime (fichier externe)
    -h / --help     -> afficher l'aide
  Afficher la banniere 'CSC86 v1.0 - compilateur C# Lite -> MASM 8086'.
  Afficher le bilan final : instructions, symboles, fonctions, erreurs.

  TODO 24 - PROCEDURE COMPILE (ORCHESTRATEUR DEUX PASSES)
  --------------------------------------------------------
  Procedure Compile : orchestrer la compilation complete.
    Passe 1 :
      LexInit(source_file)
      ParseProgram -> remplir sym_table, func_table, lit_table
      Verifier que Main() existe
    Passe 2 :
      Ouvrir tmp_file (code) et out_file (sortie finale)
      GenStackSegment
      GenDataSegment (DATA + litteraux + variables globales)
      GenCodeHeader  (START: + init DS/SS)
      Pour chaque methode dans l'ordre de declaration :
        GenFunctionPrologue
        Re-parser le corps de la methode (passe 2) -> GenInstruction
        GenFunctionEpilogue
      GenRuntime (arithmetique + I/O)
      GenCodeFooter
      CopyTmpToOut
    Rapport final.

  TODO 25 - INTEGRATION, TESTS ET VALIDATION
  --------------------------------------------
  Creer les programmes de test progressifs :
    test01_hello.cs     : Console.WriteLine("Hello, World!");
    test02_vars.cs      : int/bool/char, affectations, cout.
    test03_arith.cs     : +,-,*,/,%, operateurs composes, ++/--.
    test04_cond.cs      : if/else, operateurs de comparaison et logiques.
    test05_while.cs     : boucle while + break/continue.
    test06_for.cs       : boucle for + boucle for imbriquee.
    test07_fonct.cs     : methodes statiques, passage de parametres, return.
    test08_string.cs    : chaines, concatenation, Console.ReadLine.
    test09_array.cs     : tableaux int[], acces et boucle.
    test10_recurs.cs    : factorielle recursive.
  Valider chaque test : 0 erreur de compilation + sortie ASM correcte.
  Verifier les labels coherents, les conventions d'appel, les gotos corrects.
  Mesurer : instructions parsees, symboles, litteraux, fonctions, erreurs.

  ============================================================================ }

Program CSC86;

{ ============================================================================
  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES DU COMPILATEUR
  ============================================================================ }

{ --------------------------------------------------------------------------
  Directives compilateur (Turbo Pascal / Free Pascal)
  -------------------------------------------------------------------------- }
{$A-}   { Pas d'alignement memoire                                          }
{$I-}   { Pas de verification I/O automatique (gestion manuelle)            }
{$B-}   { Evaluation booleenne court-circuit                                }
{$Q-}   { Pas de verification overflow                                      }
{$R-}   { Pas de verification de range                                      }

{$IFDEF FPC}
 {$MODE DELPHI}
 {$CODEPAGE UTF8}
{$ENDIF}

{ --------------------------------------------------------------------------
  Constantes dimensionnant les tables et buffers internes
  -------------------------------------------------------------------------- }
Const
  { --- Version --- }
  CSC86_VERSION = '1.0';
  CSC86_DATE    = '2026-03-02';

  { --- Limites des tables principales --- }
  MAX_SYM    = {$IFDEF FPC}512{$ELSE}128{$ENDIF};    { Symboles (variables locales + globales + params)  }
  MAX_FUNC   = {$IFDEF FPC}128{$ELSE}16{$ENDIF};    { Methodes statiques                                }
  MAX_LIT    = {$IFDEF FPC}256{$ELSE}128{$ENDIF};    { Litteraux de chaine distincts                     }
  MAX_PARAM  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};     { Parametres max par methode                        }
  MAX_LOCAL  = {$IFDEF FPC}32{$ELSE}8{$ENDIF};     { Variables locales max par methode                 }
  MAX_FWDREF = 256;    { Forward references de labels a resoudre           }

  { --- Limites du lexeur --- }
  MAX_LINE   = 256;    { Longueur max d'une ligne source                   }
  MAX_TOKSTR = 128;    { Longueur max d'un token (ident, chaine, ...)      }

  { --- Prefixes des labels ASM emis --- }
  CS_LBL_PFX  = '_CL_';    { Labels utilisateur (if/while/for)            }
  CS_FUN_PFX  = '_CF_';    { Fonctions (methodes statiques C#)            }
  CS_GLB_PFX  = '_G_';     { Variables globales                           }
  CS_LIT_PFX  = '_SL_';    { Donnees brutes des litteraux de chaine       }
  CS_LITD_PFX = '_SLD_';   { Descripteurs de litteraux (ptr + len)        }
  RT_PFX      = '_RT_';    { Routines runtime                             }

  { --- Codes d'erreur compilateur --- }
  ERR_NONE     = 0;
  ERR_SYNTAX   = 1;
  ERR_SEMANTIC = 2;
  ERR_SYMTAB   = 3;
  ERR_INTERNAL = 99;

{ --------------------------------------------------------------------------
  Types de base
  -------------------------------------------------------------------------- }
Type
  TString = String[MAX_TOKSTR];

  { ---------- Enumeration : type de valeur C# Lite ---------- }
  TValueKind = (
    VK_UNDEF,    { non defini                                              }
    VK_INT,      { int  (entier signe 16 bits)                             }
    VK_BOOL,     { bool (0 = false, 1 = true, stocke en DW)               }
    VK_CHAR,     { char (code ASCII, stocke en DW)                         }
    VK_STRING,   { string (descripteur : ptr DW + len DW)                  }
    VK_VOID,     { type de retour void                                     }
    VK_ARRAY     { tableau (ptr base + taille statique)                    }
  );

  { ---------- Enumeration : portee d'un symbole ---------- }
  TScope = (
    SC_GLOBAL,   { variable statique dans .DATA                            }
    SC_LOCAL,    { variable locale sur la pile  [BP - offset]              }
    SC_PARAM     { parametre de methode         [BP + offset]              }
  );

  { ---------- Enumeration : nature d'un symbole ---------- }
  TSymKind = (
    SK_UNDEF,    { non encore defini                                       }
    SK_VAR,      { variable (locale, globale ou parametre)                 }
    SK_CONST,    { constante (evaluee a la compilation)                    }
    SK_FUNC,     { methode statique                                        }
    SK_CLASS,    { classe (namespace dans C# Lite)                         }
    SK_TYPE      { alias de type                                           }
  );

  { ---------- Enumeration : type de token lexical ---------- }
  TTokenKind = (
    TK_EOF,      { fin de fichier                                           }
    TK_UNKNOWN,  { caractere non reconnu                                    }
    TK_IDENT,    { identificateur ou mot-cle (distingues par val)           }
    TK_INT,      { constante entiere  ex : 42  0xFF                         }
    TK_STRING,   { constante chaine   ex : "hello\n"                        }
    TK_CHAR,     { constante char     ex : 'A'  '\n'                        }
    TK_KEYWORD,  { mot-cle reserve (int, if, while, class, ...)             }
    TK_OP,       { operateur          ex : +  -  *  /  ==  !=  <=  &&  ||   }
    TK_PUNCT     { ponctuation        ex : ()  []  ;  ,  .                  }
  );

  { ---------- Token produit par le lexeur ---------- }
  TToken = Record
    kind    : TTokenKind;   { nature du token                               }
    val     : TString;      { representation textuelle brute                }
    int_val : LongInt;      { valeur numerique si TK_INT                    }
    line    : Integer;      { ligne source (1-base)                         }
    col     : Integer;      { colonne source (1-base)                       }
  End;

  { ---------- Entree de parametre (dans TFuncEntry) ---------- }
  TParamEntry = Record
    name      : TString;    { nom du parametre                              }
    vtype     : TValueKind; { type declare                                  }
    bp_offset : Integer;    { offset positif depuis BP [BP + bp_offset]     }
  End;

  { ---------- Entree de variable locale (dans TFuncEntry) ---------- }
  TLocalEntry = Record
    name      : TString;    { nom de la variable locale                     }
    vtype     : TValueKind; { type declare                                  }
    bp_offset : Integer;    { offset negatif depuis BP [BP - bp_offset]     }
    arr_size  : Integer;    { taille si VK_ARRAY (sinon 0)                  }
  End;

  { ---------- Entree de la table des symboles ---------- }
  TSymEntry = Record
    name       : TString;    { nom en casse d'origine                       }
    kind       : TSymKind;   { nature du symbole                            }
    vtype      : TValueKind; { type de valeur                               }
    scope      : TScope;     { portee : global / local / param              }
    asm_label  : TString;    { label ASM (_G_xxx pour globales)             }
    bp_offset  : Integer;    { offset BP (locaux et params)                 }
    arr_size   : Integer;    { taille du tableau si VK_ARRAY                }
    is_static  : Boolean;    { True = variable / methode statique           }
    const_val  : LongInt;    { valeur si SK_CONST                           }
    func_idx   : Integer;    { index dans func_table si SK_FUNC (0 = non)  }
  End;

  PSymTableArr = ^TSymTableArr;
  TSymTableArr = Array[1..MAX_SYM] of TSymEntry;

  { ---------- Entree de la table des methodes ---------- }
  TFuncEntry = Record
    name             : TString;    { nom de la methode                      }
    return_type      : TValueKind; { type de retour                         }
    asm_label        : TString;    { label ASM du point d'entree            }
    param_count      : Integer;    { nombre de parametres                   }
    local_count      : Integer;    { nombre de variables locales            }
    local_frame_size : Integer;    { octets de frame locale (SUB SP, n)     }
    param_bytes      : Integer;    { octets d'args a depiler (caller cdecl) }
    params           : Array[1..MAX_PARAM] of TParamEntry;
    locals           : Array[1..MAX_LOCAL]  of TLocalEntry;
    is_main          : Boolean;    { True si c'est Main()                   }
  End;

  PFuncTableArr = ^TFuncTableArr;
  TFuncTableArr = Array[1..MAX_FUNC] of TFuncEntry;

  { ---------- Entree de la table des litteraux de chaine ---------- }
  TLitEntry = Record
    val       : TString;    { valeur brute (apres decodage \n \t etc.)     }
    len       : Integer;    { longueur en octets                           }
    asm_data  : TString;    { label du buffer de donnees  (_SL_xx)         }
    asm_desc  : TString;    { label du descripteur        (_SLD_xx)        }
  End;

  PLitTableArr = ^TLitTableArr;
  TLitTableArr = Array[1..MAX_LIT] of TLitEntry;

  { ---------- Forward reference de label (resolution passe 2) ---------- }
  TFwdRef = Record
    asm_label : TString;    { label ASM reference avant definition         }
    src_line  : Integer;    { ligne source pour diagnostic                 }
  End;

  PFwdRefArr = ^TFwdRefArr;
  TFwdRefArr = Array[1..MAX_FWDREF] of TFwdRef;

{ --------------------------------------------------------------------------
  Variables globales du compilateur
  -------------------------------------------------------------------------- }
Var
  { --- Options invocation --- }
  opt_verbose   : Boolean;     { -v : afficher statistiques               }
  opt_debug     : Boolean;     { -d : commentaires supplementaires ASM    }
  opt_no_rt     : Boolean;     { -ns : ne pas emettre le runtime inline   }

  { --- Compteurs de compilation --- }
  err_count     : Integer;     { erreurs detectees                        }
  warn_count    : Integer;     { avertissements emis                      }
  src_line_num  : Integer;     { ligne source courante                    }
  instr_count   : Integer;     { instructions C# parsees                  }
  lbl_seq       : Integer;     { sequence labels ASM auto (@@Lxxxx)       }

  { --- Noms de fichiers --- }
  src_fname     : String;      { source .cs                               }
  out_fname     : String;      { sortie .asm                              }
  tmp_fname     : String;      { temporaire passe 1                       }

  { --- Fichiers --- }
  src_file      : Text;        { lecture source C#                        }
  out_file      : Text;        { ecriture ASM final                       }
  tmp_file      : Text;        { code intermediaire passe 1               }
  cur_out       : ^Text;       { pointeur vers le fichier d'emission actif}
  tmp_open      : Boolean;     { tmp_file ouvert ?                        }

  { --- Tables principales (allouees au demarrage) --- }
  sym_table     : PSymTableArr;
  sym_count     : Integer;

  func_table    : PFuncTableArr;
  func_count    : Integer;
  cur_func_idx  : Integer;     { methode en cours de compilation (0=global)}

  lit_table     : PLitTableArr;
  lit_count     : Integer;

  fwd_table     : PFwdRefArr;
  fwd_count     : Integer;

  { --- Contexte lexeur (rempli par TODO 02) --- }
  lex_line      : String;      { ligne source courante                    }
  lex_pos       : Integer;     { position dans lex_line                   }
  lex_lineno    : Integer;     { numero de ligne                          }
  lex_colno     : Integer;     { numero de colonne                        }
  lex_cur_tok   : TToken;      { dernier token lu                         }
  lex_peek_tok  : TToken;      { token en attente (peek)                  }
  lex_has_peek  : Boolean;     { peek_tok est-il valide ?                 }

  { --- Contexte de boucle (break/continue, pile max 8 niveaux) --- }
  break_stack    : Array[1..8] of TString;
  continue_stack : Array[1..8] of TString;
  loop_depth     : Integer;

  { --- Label de la premiere instruction (passe 2) --- }
  first_instr_lbl : TString;

{ --------------------------------------------------------------------------
  Procedure d'initialisation : allouer les tables et mettre a zero.
  -------------------------------------------------------------------------- }
Procedure InitTables;
Begin
  New(sym_table);    sym_count    := 0;
  New(func_table);   func_count   := 0;  cur_func_idx := 0;
  New(lit_table);    lit_count    := 0;
  New(fwd_table);    fwd_count    := 0;
  lbl_seq      := 0;
  err_count    := 0;  warn_count  := 0;
  src_line_num := 0;  instr_count := 0;
  loop_depth   := 0;
  tmp_open     := False;
  lex_has_peek := False;
  first_instr_lbl := '';
  opt_verbose  := False;  opt_debug := False;  opt_no_rt := False;
End;

{ --------------------------------------------------------------------------
  Procedure de liberation des tables.
  -------------------------------------------------------------------------- }
Procedure FreeTables;
Begin
  If sym_table  <> Nil Then Dispose(sym_table);
  If func_table <> Nil Then Dispose(func_table);
  If lit_table  <> Nil Then Dispose(lit_table);
  If fwd_table  <> Nil Then Dispose(fwd_table);
End;

{ ============================================================================
  TODO 02 - LEXEUR (ANALYSE LEXICALE C#)
  ============================================================================ }

{ --------------------------------------------------------------------------
  Constantes internes au lexeur
  -------------------------------------------------------------------------- }
Const
  LEX_EOF_CHAR = #0;    { sentinelle fin de ligne / fin de fichier }

{ --------------------------------------------------------------------------
  LexIsAlpha : True si c est une lettre ou underscore (debut d'ident)
  -------------------------------------------------------------------------- }
Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := (c In ['a'..'z', 'A'..'Z', '_']);
End;

{ --------------------------------------------------------------------------
  LexIsAlNum : True si c est une lettre, chiffre ou underscore
  -------------------------------------------------------------------------- }
Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := (c In ['a'..'z', 'A'..'Z', '0'..'9', '_']);
End;

{ --------------------------------------------------------------------------
  LexIsDigit : True si c est un chiffre decimal
  -------------------------------------------------------------------------- }
Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c In ['0'..'9']);
End;

{ --------------------------------------------------------------------------
  LexIsHexDigit : True si c est un chiffre hexadecimal
  -------------------------------------------------------------------------- }
Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := (c In ['0'..'9', 'a'..'f', 'A'..'F']);
End;

{ --------------------------------------------------------------------------
  LexHexVal : valeur d'un chiffre hexadecimal
  -------------------------------------------------------------------------- }
Function LexHexVal(c : Char) : Integer;
Begin
  If c In ['0'..'9'] Then LexHexVal := Ord(c) - Ord('0')
  Else If c In ['a'..'f'] Then LexHexVal := Ord(c) - Ord('a') + 10
  Else LexHexVal := Ord(c) - Ord('A') + 10;
End;

{ --------------------------------------------------------------------------
  LexIsKeyword : True si s est un mot-cle C# Lite reconnu
  -------------------------------------------------------------------------- }
Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'int')       Or (s = 'bool')      Or (s = 'char')    Or
    (s = 'string')    Or (s = 'void')      Or (s = 'static')  Or
    (s = 'class')     Or (s = 'new')       Or (s = 'if')      Or
    (s = 'else')      Or (s = 'while')     Or (s = 'for')     Or
    (s = 'do')        Or (s = 'break')     Or (s = 'continue')Or
    (s = 'return')    Or (s = 'true')      Or (s = 'false')   Or
    (s = 'null')      Or (s = 'Console')   Or (s = 'using')   Or
    (s = 'namespace') Or (s = 'public')    Or (s = 'private') Or
    (s = 'readonly')  Or (s = 'const')     Or (s = 'out')     Or
    (s = 'ref');
End;

{ --------------------------------------------------------------------------
  LexInit : ouvrir le fichier source et initialiser l'etat du lexeur.
  -------------------------------------------------------------------------- }
Procedure LexInit(Const fname : String);
Begin
  Assign(src_file, fname);
  Reset(src_file);
  lex_line    := '';
  lex_pos     := 1;
  lex_lineno  := 0;
  lex_colno   := 1;
  lex_has_peek := False;
  FillChar(lex_cur_tok, SizeOf(lex_cur_tok), 0);
  FillChar(lex_peek_tok, SizeOf(lex_peek_tok), 0);
End;

{ --------------------------------------------------------------------------
  LexCurChar : retourner le caractere courant dans lex_line (ou #0).
  -------------------------------------------------------------------------- }
Function LexCurChar : Char;
Begin
  If lex_pos <= Length(lex_line) Then
    LexCurChar := lex_line[lex_pos]
  Else
    LexCurChar := LEX_EOF_CHAR;
End;

{ --------------------------------------------------------------------------
  LexPeekChar : retourner le caractere a lex_pos + offset (sans avancer).
  -------------------------------------------------------------------------- }
Function LexPeekChar(offset : Integer) : Char;
Var p : Integer;
Begin
  p := lex_pos + offset;
  If (p >= 1) And (p <= Length(lex_line)) Then
    LexPeekChar := lex_line[p]
  Else
    LexPeekChar := LEX_EOF_CHAR;
End;

{ --------------------------------------------------------------------------
  LexAdvance : avancer d'un caractere dans la ligne courante.
  -------------------------------------------------------------------------- }
Procedure LexAdvance;
Begin
  If lex_pos <= Length(lex_line) Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
  End;
End;

{ --------------------------------------------------------------------------
  LexReadLine : lire la prochaine ligne du source dans lex_line.
  Retourne False si EOF.
  -------------------------------------------------------------------------- }
Function LexReadLine : Boolean;
Begin
  If EOF(src_file) Then
  Begin
    LexReadLine := False;
    lex_line := '';
    Exit;
  End;
  ReadLn(src_file, lex_line);
  Inc(lex_lineno);
  lex_pos    := 1;
  lex_colno  := 1;
  src_line_num := lex_lineno;
  LexReadLine := True;
End;

{ --------------------------------------------------------------------------
  LexRefill : avancer dans le flux jusqu'a trouver un caractere non-EOF.
  Gere les fins de ligne et lit les nouvelles lignes si necessaire.
  Retourne False si le source est completement epuise.
  -------------------------------------------------------------------------- }
Function LexRefill : Boolean;
Begin
  While LexCurChar = LEX_EOF_CHAR Do
  Begin
    If Not LexReadLine Then
    Begin
      LexRefill := False;
      Exit;
    End;
  End;
  LexRefill := True;
End;

{ --------------------------------------------------------------------------
  LexSkipWS : sauter les espaces, tabulations, et commentaires C#.
    // commentaire de ligne              -> sauter jusqu'a fin de ligne
    /* commentaire multi-ligne */        -> sauter jusqu'a */
  -------------------------------------------------------------------------- }
Procedure LexSkipWS;
Var in_block : Boolean;
Begin
  in_block := False;
  Repeat
    { Remplir la ligne si necessaire }
    While LexCurChar = LEX_EOF_CHAR Do
    Begin
      If in_block Then
      Begin
        { Continuer a chercher */ sur la ligne suivante }
        If Not LexReadLine Then Exit;
      End
      Else
        Exit;
    End;

    If in_block Then
    Begin
      { Chercher la fin du commentaire bloc '*/' }
      If (LexCurChar = '*') And (LexPeekChar(1) = '/') Then
      Begin
        LexAdvance; LexAdvance;   { sauter '*' et '/' }
        in_block := False;
      End
      Else
        LexAdvance;
    End
    Else If (LexCurChar = '/') And (LexPeekChar(1) = '/') Then
    Begin
      { Commentaire de ligne : sauter jusqu'a la fin }
      lex_pos := Length(lex_line) + 1;
    End
    Else If (LexCurChar = '/') And (LexPeekChar(1) = '*') Then
    Begin
      { Debut de commentaire bloc }
      LexAdvance; LexAdvance;
      in_block := True;
    End
    Else If LexCurChar In [' ', #9, #13, #10] Then
      LexAdvance
    Else
      Exit;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexDecodeEscape : decoder une sequence d'echappement C# apres '\'.
  Retourne le caractere decode ; avance lex_pos au-dela de la sequence.
  -------------------------------------------------------------------------- }
Function LexDecodeEscape : Char;
Var c : Char;
    h : Integer;
Begin
  c := LexCurChar;
  LexAdvance;
  Case c Of
    'n'  : LexDecodeEscape := #10;
    'r'  : LexDecodeEscape := #13;
    't'  : LexDecodeEscape := #9;
    '0'  : LexDecodeEscape := #0;
    '\' : LexDecodeEscape := '\';
    '"'  : LexDecodeEscape := '"';
    ''''  : LexDecodeEscape := '''';
    'x'  :
    Begin
      { \xHH : un ou deux chiffres hexa }
      h := 0;
      If LexIsHexDigit(LexCurChar) Then
      Begin
        h := LexHexVal(LexCurChar); LexAdvance;
        If LexIsHexDigit(LexCurChar) Then
        Begin
          h := h * 16 + LexHexVal(LexCurChar); LexAdvance;
        End;
      End;
      LexDecodeEscape := Chr(h);
    End;
  Else
    LexDecodeEscape := c;   { sequence inconnue : garder le caractere }
  End;
End;

{ --------------------------------------------------------------------------
  LexMakeTok : construire un TToken a partir des elements courants.
  -------------------------------------------------------------------------- }
Function LexMakeTok(k : TTokenKind; Const v : TString) : TToken;
Var t : TToken;
Begin
  t.kind    := k;
  t.val     := v;
  t.int_val := 0;
  t.line    := lex_lineno;
  t.col     := lex_colno;
  LexMakeTok := t;
End;

{ --------------------------------------------------------------------------
  LexReadIdent : lire un identifiant ou mot-cle a partir de lex_pos.
  -------------------------------------------------------------------------- }
Function LexReadIdent : TToken;
Var s : TString;
    k : TTokenKind;
Begin
  s := '';
  While LexIsAlNum(LexCurChar) Do
  Begin
    s := s + LexCurChar;
    LexAdvance;
  End;
  If LexIsKeyword(s) Then k := TK_KEYWORD
  Else                     k := TK_IDENT;
  LexReadIdent := LexMakeTok(k, s);
End;

{ --------------------------------------------------------------------------
  LexReadNumber : lire une constante entiere (decimale ou 0x...).
  -------------------------------------------------------------------------- }
Function LexReadNumber : TToken;
Var s   : TString;
    v   : LongInt;
    t   : TToken;
    hex : Boolean;
Begin
  s   := '';
  v   := 0;
  hex := False;
  If (LexCurChar = '0') And (LexPeekChar(1) In ['x', 'X']) Then
  Begin
    { Hexadecimal 0x... }
    LexAdvance; LexAdvance;   { sauter '0' et 'x' }
    hex := True;
    While LexIsHexDigit(LexCurChar) Do
    Begin
      v := v * 16 + LexHexVal(LexCurChar);
      s := s + LexCurChar;
      LexAdvance;
    End;
    s := '0x' + s;
  End
  Else
  Begin
    { Decimal }
    While LexIsDigit(LexCurChar) Do
    Begin
      v := v * 10 + (Ord(LexCurChar) - Ord('0'));
      s := s + LexCurChar;
      LexAdvance;
    End;
  End;
  { Sauter suffixes optionnels u / l / ul / lu }
  While LexCurChar In ['u', 'U', 'l', 'L'] Do LexAdvance;
  t         := LexMakeTok(TK_INT, s);
  t.int_val := v;
  LexReadNumber := t;
End;

{ --------------------------------------------------------------------------
  LexReadString : lire une chaine litterale delimitee par ".
  Les sequences \n \t \\ \" \xHH sont decodees.
  -------------------------------------------------------------------------- }
Function LexReadString : TToken;
Var s : TString;
    c : Char;
Begin
  s := '';
  LexAdvance;   { sauter le '"' ouvrant }
  While (LexCurChar <> LEX_EOF_CHAR) And (LexCurChar <> '"') Do
  Begin
    If LexCurChar = '\' Then
    Begin
      LexAdvance;   { sauter '\' }
      c := LexDecodeEscape;
    End
    Else
    Begin
      c := LexCurChar;
      LexAdvance;
    End;
    If Length(s) < MAX_TOKSTR Then s := s + c;
  End;
  If LexCurChar = '"' Then LexAdvance;   { sauter '"' fermant }
  LexReadString := LexMakeTok(TK_STRING, s);
End;

{ --------------------------------------------------------------------------
  LexReadChar2 : lire un char litteral delimite par des apostrophes ' '.
  -------------------------------------------------------------------------- }
Function LexReadChar2 : TToken;
Var s : TString;
    c : Char;
    t : TToken;
Begin
  LexAdvance;   { sauter "'" ouvrant }
  If LexCurChar = '\' Then
  Begin
    LexAdvance;
    c := LexDecodeEscape;
  End
  Else
  Begin
    c := LexCurChar;
    LexAdvance;
  End;
  If LexCurChar = '''' Then LexAdvance;   { sauter "'" fermant }
  s := c;
  t         := LexMakeTok(TK_CHAR, s);
  t.int_val := Ord(c);
  LexReadChar2 := t;
End;

{ --------------------------------------------------------------------------
  LexReadOp : lire un operateur ou signe de ponctuation.
  Gere les operateurs a 2 caracteres : == != <= >= && || ++ -- += -= *= /= %=
  -------------------------------------------------------------------------- }
Function LexReadOp : TToken;
Var c1, c2 : Char;
    s       : TString;
    k       : TTokenKind;
Begin
  c1 := LexCurChar;
  c2 := LexPeekChar(1);
  s  := c1;
  k  := TK_OP;

  { Operateurs deux caracteres }
  If ((c1 = '=') And (c2 = '=')) Or
     ((c1 = '!') And (c2 = '=')) Or
     ((c1 = '<') And (c2 = '=')) Or
     ((c1 = '>') And (c2 = '=')) Or
     ((c1 = '&') And (c2 = '&')) Or
     ((c1 = '|') And (c2 = '|')) Or
     ((c1 = '+') And (c2 = '+')) Or
     ((c1 = '-') And (c2 = '-')) Or
     ((c1 = '+') And (c2 = '=')) Or
     ((c1 = '-') And (c2 = '=')) Or
     ((c1 = '*') And (c2 = '=')) Or
     ((c1 = '/') And (c2 = '=')) Or
     ((c1 = '%') And (c2 = '=')) Then
  Begin
    s := c1 + c2;
    LexAdvance; LexAdvance;
  End
  Else
  Begin
    { Ponctuation a un caractere }
    If c1 In ['{', '}', '(', ')', '[', ']', ';', ',', '.'] Then
      k := TK_PUNCT;
    LexAdvance;
  End;
  LexReadOp := LexMakeTok(k, s);
End;

{ --------------------------------------------------------------------------
  LexNext : produire le prochain token depuis le flux source.
  Met a jour lex_cur_tok et retourne le token.
  -------------------------------------------------------------------------- }
Function LexNext : TToken;
Var t : TToken;
Begin
  { Si un token est en attente (peek), le consommer }
  If lex_has_peek Then
  Begin
    lex_cur_tok  := lex_peek_tok;
    lex_has_peek := False;
    LexNext      := lex_cur_tok;
    Exit;
  End;

  { Assurer qu'il y a des donnees a lire }
  If Not LexRefill Then
  Begin
    t := LexMakeTok(TK_EOF, '');
    lex_cur_tok := t;
    LexNext     := t;
    Exit;
  End;

  LexSkipWS;

  If LexCurChar = LEX_EOF_CHAR Then
  Begin
    If Not LexRefill Then
    Begin
      t := LexMakeTok(TK_EOF, '');
      lex_cur_tok := t;
      LexNext := t;
      Exit;
    End;
    LexSkipWS;
  End;

  If LexCurChar = LEX_EOF_CHAR Then
  Begin
    t := LexMakeTok(TK_EOF, '');
    lex_cur_tok := t;
    LexNext := t;
    Exit;
  End;

  { Dispatcher selon le premier caractere }
  If LexIsAlpha(LexCurChar) Then
    t := LexReadIdent
  Else If LexIsDigit(LexCurChar) Then
    t := LexReadNumber
  Else If LexCurChar = '"' Then
    t := LexReadString
  Else If LexCurChar = '''' Then
    t := LexReadChar2
  Else
    t := LexReadOp;

  lex_cur_tok := t;
  LexNext := t;
End;

{ --------------------------------------------------------------------------
  LexPeek : retourner le prochain token SANS le consommer.
  -------------------------------------------------------------------------- }
Function LexPeek : TToken;
Begin
  If Not lex_has_peek Then
  Begin
    lex_peek_tok := LexNext;
    lex_has_peek := True;
    { Remettre cur_tok a l'etat precedent n'est pas necessaire car
      LexNext sera appele par LexPeek, on remet simplement le flag }
  End;
  LexPeek := lex_peek_tok;
End;

{ --------------------------------------------------------------------------
  LexExpect : consommer le prochain token en verifiant sa valeur.
  Si le token ne correspond pas a val, emettre une erreur.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const expected_val : TString);
Var t : TToken;
Begin
  t := LexNext;
  If t.val <> expected_val Then
  Begin
    Inc(err_count);
    WriteLn('Erreur syntaxique ligne ', t.line, ' col ', t.col,
            ' : attendu ''', expected_val, ''' mais lu ''', t.val, '''');
  End;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : consommer le prochain token en verifiant son kind.
  Retourne le token consomme.
  -------------------------------------------------------------------------- }
Function LexExpectKind(k : TTokenKind) : TToken;
Var t     : TToken;
    kname : TString;
Begin
  t := LexNext;
  If t.kind <> k Then
  Begin
    Inc(err_count);
    Case k Of
      TK_IDENT   : kname := 'identificateur';
      TK_INT     : kname := 'entier';
      TK_STRING  : kname := 'chaine';
      TK_KEYWORD : kname := 'mot-cle';
    Else             kname := 'token';
    End;
    WriteLn('Erreur syntaxique ligne ', t.line, ' col ', t.col,
            ' : attendu ', kname, ' mais lu ''', t.val, '''');
  End;
  LexExpectKind := t;
End;

{ --------------------------------------------------------------------------
  LexClose : fermer le fichier source.
  -------------------------------------------------------------------------- }
Procedure LexClose;
Begin
  {$I-}
  Close(src_file);
  {$I+}
End;

{ ============================================================================
  TODO 03 - TABLES DE SYMBOLES ET DE FONCTIONS
  ============================================================================ }

{ --------------------------------------------------------------------------
  IntToStr : convertir un entier en chaine (Turbo Pascal / FPC)
  -------------------------------------------------------------------------- }
Function IntToStr(n : LongInt) : TString;
Var s : TString;
Begin
  Str(n, s);
  IntToStr := s;
End;

{ --------------------------------------------------------------------------
  AsmSafeIdent : nettoyer un identifiant C# pour l'utiliser comme label ASM.
  Remplace '.' et tout caractere non alphanum par '_'.
  Ex : 'Console.WriteLine' -> 'Console_WriteLine'
  -------------------------------------------------------------------------- }
Function AsmSafeIdent(Const s : TString) : TString;
Var i   : Integer;
    res : TString;
    c   : Char;
Begin
  res := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If c In ['a'..'z', 'A'..'Z', '0'..'9', '_'] Then
      res := res + c
    Else
      res := res + '_';
  End;
  If res = '' Then res := '_';
  AsmSafeIdent := res;
End;

{ --------------------------------------------------------------------------
  NewLabel : generer un label ASM unique de la forme @@Lxxxx.
  -------------------------------------------------------------------------- }
Function NewLabel : TString;
Begin
  Inc(lbl_seq);
  NewLabel := '@@L' + IntToStr(lbl_seq);
End;

{ --------------------------------------------------------------------------
  GlbAsmLabel : label ASM d'une variable globale C#.
  Ex : 'count' -> '_G_count'
  -------------------------------------------------------------------------- }
Function GlbAsmLabel(Const name : TString) : TString;
Begin
  GlbAsmLabel := CS_GLB_PFX + AsmSafeIdent(name);
End;

{ --------------------------------------------------------------------------
  FuncAsmLabel : label ASM d'une methode statique.
  Ex : 'Fact' -> '_CF_Fact'
  -------------------------------------------------------------------------- }
Function FuncAsmLabel(Const name : TString) : TString;
Begin
  FuncAsmLabel := CS_FUN_PFX + AsmSafeIdent(name);
End;

{ --------------------------------------------------------------------------
  LitDataLabel : label ASM du buffer de donnees d'un litteral de chaine.
  -------------------------------------------------------------------------- }
Function LitDataLabel(idx : Integer) : TString;
Begin
  LitDataLabel := CS_LIT_PFX + IntToStr(idx);
End;

{ --------------------------------------------------------------------------
  LitDescLabel : label ASM du descripteur (ptr+len) d'un litteral.
  -------------------------------------------------------------------------- }
Function LitDescLabel(idx : Integer) : TString;
Begin
  LitDescLabel := CS_LITD_PFX + IntToStr(idx);
End;

{ --------------------------------------------------------------------------
  StrEq : comparaison de chaines insensible a la casse.
  (Utile pour la recherche de noms en C# qui est case-sensitive ;
   mais les noms ASM sont normalises en minuscules d'origine.)
  En C# la casse EST significative, on compare donc directement.
  -------------------------------------------------------------------------- }
Function StrEq(Const a, b : TString) : Boolean;
Begin
  StrEq := (a = b);
End;

{ ==========================================================================
  Gestion de la portee (scope)
  ========================================================================== }

Var
  scope_level : Integer;   { 0 = global, 1 = methode, 2+ = blocs imbriques }

Procedure ScopeEnter;
Begin
  Inc(scope_level);
End;

Procedure ScopeLeave;
Begin
  If scope_level > 0 Then Dec(scope_level);
End;

{ --------------------------------------------------------------------------
  ResetLocals : reinitialiser le compteur de locaux pour une nouvelle methode.
  L'entree func_table[cur_func_idx] est supposee deja creee.
  -------------------------------------------------------------------------- }
Procedure ResetLocals;
Begin
  If cur_func_idx > 0 Then
  Begin
    func_table^[cur_func_idx].local_count      := 0;
    func_table^[cur_func_idx].local_frame_size := 0;
    func_table^[cur_func_idx].param_count      := 0;
    func_table^[cur_func_idx].param_bytes      := 0;
  End;
End;

{ ==========================================================================
  Table des symboles
  ========================================================================== }

{ --------------------------------------------------------------------------
  FindSymInScope : chercher un symbole par nom dans la portee courante.
  Retourne l'index (1-base) ou 0 si non trouve.
  scope_filter = SC_LOCAL  -> locaux + params de la methode courante.
  scope_filter = SC_GLOBAL -> variables globales uniquement.
  -------------------------------------------------------------------------- }
Function FindSymInScope(Const name : TString; scope_filter : TScope) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If StrEq(sym_table^[i].name, name) And
       (sym_table^[i].scope = scope_filter) Then
    Begin
      FindSymInScope := i;
      Exit;
    End;
  FindSymInScope := 0;
End;

{ --------------------------------------------------------------------------
  FindSym : chercher un symbole par nom : d'abord local/param, puis global.
  Retourne l'index (1-base) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function FindSym(Const name : TString) : Integer;
Var i : Integer;
Begin
  { Recherche des plus recents vers les plus anciens (portee interne gagne) }
  For i := sym_count DownTo 1 Do
    If StrEq(sym_table^[i].name, name) Then
    Begin
      FindSym := i;
      Exit;
    End;
  FindSym := 0;
End;

{ --------------------------------------------------------------------------
  AddSym : ajouter un nouveau symbole dans la table.
  Retourne l'index (1-base) ou 0 si table pleine.
  -------------------------------------------------------------------------- }
Function AddSym(Const name : TString; k : TSymKind;
                vt : TValueKind; sc : TScope) : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    Inc(err_count);
    WriteLn('Erreur interne : table des symboles pleine (MAX_SYM=', MAX_SYM, ')');
    AddSym := 0;
    Exit;
  End;
  Inc(sym_count);
  FillChar(sym_table^[sym_count], SizeOf(TSymEntry), 0);
  sym_table^[sym_count].name      := name;
  sym_table^[sym_count].kind      := k;
  sym_table^[sym_count].vtype     := vt;
  sym_table^[sym_count].scope     := sc;
  sym_table^[sym_count].is_static := (sc = SC_GLOBAL);
  If sc = SC_GLOBAL Then
    sym_table^[sym_count].asm_label := GlbAsmLabel(name)
  Else
    sym_table^[sym_count].asm_label := '';
  AddSym := sym_count;
End;

{ --------------------------------------------------------------------------
  AddGlobalVar : raccourci pour ajouter une variable globale statique.
  -------------------------------------------------------------------------- }
Function AddGlobalVar(Const name : TString; vt : TValueKind) : Integer;
Begin
  AddGlobalVar := AddSym(name, SK_VAR, vt, SC_GLOBAL);
End;

{ --------------------------------------------------------------------------
  AddLocalVar : ajouter une variable locale a la methode courante.
  Calcule l'offset BP negatif en tenant compte du type (VK_ARRAY = n*2 octets).
  -------------------------------------------------------------------------- }
Function AddLocalVar(Const name : TString; vt : TValueKind;
                     arr_size : Integer) : Integer;
Var idx     : Integer;
    fi      : Integer;
    sz      : Integer;
    offset  : Integer;
Begin
  fi := cur_func_idx;
  If fi = 0 Then
  Begin
    AddLocalVar := AddGlobalVar(name, vt);
    Exit;
  End;

  { Calcul de la taille en octets }
  If vt = VK_ARRAY Then
    sz := arr_size * 2        { tableau de int/bool/char : 1 DW par element }
  Else If vt = VK_STRING Then
    sz := 4                   { descripteur : 2 DW (ptr + len) }
  Else
    sz := 2;                  { int / bool / char : 1 DW }

  func_table^[fi].local_frame_size :=
    func_table^[fi].local_frame_size + sz;
  offset := func_table^[fi].local_frame_size;  { offset positif, acces [BP-offset] }

  { Ajouter dans la table des locaux de la fonction }
  If func_table^[fi].local_count < MAX_LOCAL Then
  Begin
    Inc(func_table^[fi].local_count);
    func_table^[fi].locals[func_table^[fi].local_count].name      := name;
    func_table^[fi].locals[func_table^[fi].local_count].vtype     := vt;
    func_table^[fi].locals[func_table^[fi].local_count].bp_offset := offset;
    func_table^[fi].locals[func_table^[fi].local_count].arr_size  := arr_size;
  End;

  idx := AddSym(name, SK_VAR, vt, SC_LOCAL);
  If idx > 0 Then
  Begin
    sym_table^[idx].bp_offset := offset;
    sym_table^[idx].arr_size  := arr_size;
  End;
  AddLocalVar := idx;
End;

{ --------------------------------------------------------------------------
  AddParam : ajouter un parametre de methode.
  Les parametres sont accedes via [BP + offset] (positif, convention cdecl).
  Convention near cdecl : [BP+0]=old BP, [BP+2]=ret addr, [BP+4]=param1, ...
  -------------------------------------------------------------------------- }
Function AddParam(Const name : TString; vt : TValueKind) : Integer;
Var idx    : Integer;
    fi     : Integer;
    offset : Integer;
Begin
  fi := cur_func_idx;
  If fi = 0 Then
  Begin
    AddParam := 0;
    Exit;
  End;
  { offset BP pour ce parametre }
  offset := 4 + func_table^[fi].param_count * 2;

  If func_table^[fi].param_count < MAX_PARAM Then
  Begin
    Inc(func_table^[fi].param_count);
    func_table^[fi].param_bytes :=
      func_table^[fi].param_bytes + 2;
    func_table^[fi].params[func_table^[fi].param_count].name      := name;
    func_table^[fi].params[func_table^[fi].param_count].vtype     := vt;
    func_table^[fi].params[func_table^[fi].param_count].bp_offset := offset;
  End;

  idx := AddSym(name, SK_VAR, vt, SC_PARAM);
  If idx > 0 Then
    sym_table^[idx].bp_offset := offset;
  AddParam := idx;
End;

{ ==========================================================================
  Table des methodes (fonctions)
  ========================================================================== }

{ --------------------------------------------------------------------------
  FindFunc : chercher une methode par nom.
  Retourne l'index (1-base) ou 0 si non trouvee.
  -------------------------------------------------------------------------- }
Function FindFunc(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To func_count Do
    If StrEq(func_table^[i].name, name) Then
    Begin
      FindFunc := i;
      Exit;
    End;
  FindFunc := 0;
End;

{ --------------------------------------------------------------------------
  AddFunc : enregistrer une nouvelle methode dans la table.
  Retourne l'index (1-base) ou 0 si table pleine.
  -------------------------------------------------------------------------- }
Function AddFunc(Const name : TString; rt : TValueKind) : Integer;
Begin
  If func_count >= MAX_FUNC Then
  Begin
    Inc(err_count);
    WriteLn('Erreur interne : table des methodes pleine (MAX_FUNC=', MAX_FUNC, ')');
    AddFunc := 0;
    Exit;
  End;
  Inc(func_count);
  FillChar(func_table^[func_count], SizeOf(TFuncEntry), 0);
  func_table^[func_count].name             := name;
  func_table^[func_count].return_type      := rt;
  func_table^[func_count].asm_label        := FuncAsmLabel(name);
  func_table^[func_count].is_main          :=
    (name = 'Main') Or (name = 'main');
  AddFunc := func_count;
End;

{ ==========================================================================
  Table des litteraux de chaine
  ========================================================================== }

{ --------------------------------------------------------------------------
  FindLiteral : chercher un litteral de chaine par valeur.
  Retourne l'index (1-base) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function FindLiteral(Const val : TString) : Integer;
Var i : Integer;
Begin
  For i := 1 To lit_count Do
    If lit_table^[i].val = val Then
    Begin
      FindLiteral := i;
      Exit;
    End;
  FindLiteral := 0;
End;

{ --------------------------------------------------------------------------
  AddLiteral : enregistrer un litteral de chaine, ou retourner l'index
  existant si la meme chaine a deja ete enregistree (deduplication).
  Retourne l'index (1-base) ou 0 si table pleine.
  -------------------------------------------------------------------------- }
Function AddLiteral(Const val : TString) : Integer;
Var idx : Integer;
Begin
  { deduplication }
  idx := FindLiteral(val);
  If idx > 0 Then
  Begin
    AddLiteral := idx;
    Exit;
  End;
  If lit_count >= MAX_LIT Then
  Begin
    Inc(err_count);
    WriteLn('Erreur interne : table des litteraux pleine (MAX_LIT=', MAX_LIT, ')');
    AddLiteral := 0;
    Exit;
  End;
  Inc(lit_count);
  lit_table^[lit_count].val      := val;
  lit_table^[lit_count].len      := Length(val);
  lit_table^[lit_count].asm_data := LitDataLabel(lit_count);
  lit_table^[lit_count].asm_desc := LitDescLabel(lit_count);
  AddLiteral := lit_count;
End;

{ ==========================================================================
  Rapport de compilation (bilan final)
  ========================================================================== }

{ --------------------------------------------------------------------------
  PrintReport : afficher les statistiques de compilation sur stdout.
  -------------------------------------------------------------------------- }
Procedure PrintReport;
Begin
  WriteLn;
  WriteLn('CSC86 - Compilation terminee');
  WriteLn('  Source     : ', src_fname);
  WriteLn('  Sortie     : ', out_fname);
  WriteLn('  Instructions :  ', instr_count);
  WriteLn('  Symboles     :  ', sym_count);
  WriteLn('  Methodes     :  ', func_count);
  WriteLn('  Litteraux    :  ', lit_count);
  WriteLn('  Erreurs      :  ', err_count);
  WriteLn('  Attention    :  ', warn_count);
  If err_count = 0 Then
    WriteLn('  (compilation reussie)')
  Else
    WriteLn('  (compilation echouee)');
End;

{ ============================================================================
  TODO 04 - INFRASTRUCTURE D'EMISSION ASM
  ============================================================================ }

{ --------------------------------------------------------------------------
  InitOutput : ouvrir les fichiers de sortie.
  out_file   = fichier ASM final (out_fname).
  tmp_file   = fichier intermediaire (tmp_fname) pour la passe 1 (CODE).
  cur_out    = pointeur vers la destination courante.
  -------------------------------------------------------------------------- }
Procedure InitOutput;
Begin
  Assign(out_file, out_fname);
  Rewrite(out_file);
  cur_out  := @out_file;
  tmp_open := False;
End;

{ --------------------------------------------------------------------------
  OpenTmpFile : creer / (re)ouvrir le fichier temporaire pour la passe CODE.
  Apres cet appel, cur_out pointe sur tmp_file.
  -------------------------------------------------------------------------- }
Procedure OpenTmpFile;
Begin
  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);
  tmp_open := True;
  cur_out  := @tmp_file;
End;

{ --------------------------------------------------------------------------
  CloseOutput : fermer le fichier principal de sortie.
  -------------------------------------------------------------------------- }
Procedure CloseOutput;
Begin
  Close(out_file);
End;

{ --------------------------------------------------------------------------
  CloseTmpFile : fermer le fichier temporaire.
  -------------------------------------------------------------------------- }
Procedure CloseTmpFile;
Begin
  If tmp_open Then
  Begin
    Close(tmp_file);
    tmp_open := False;
  End;
End;

{ --------------------------------------------------------------------------
  SwitchToMain : rediriger cur_out vers out_file (passe DATA / epilogue).
  -------------------------------------------------------------------------- }
Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

{ --------------------------------------------------------------------------
  MergeTmpToMain : copier le contenu de tmp_file vers out_file.
  Utilise apres la generation du segment CODE (passe 2).
  -------------------------------------------------------------------------- }
Procedure MergeTmpToMain;
Var
  tf  : Text;
  line : String;
Begin
  If Not tmp_open Then Exit;
  CloseTmpFile;
  Assign(tf, tmp_fname);
  Reset(tf);
  While Not Eof(tf) Do
  Begin
    ReadLn(tf, line);
    WriteLn(out_file, line);
  End;
  Close(tf);
  { Supprimer le fichier temporaire }
  Erase(tf);
End;

{ ==========================================================================
  Primitives d'emission
  ========================================================================== }

{ --------------------------------------------------------------------------
  Emit : ecrire une ligne brute dans le fichier courant.
  -------------------------------------------------------------------------- }
Procedure Emit(Const s : TString);
Begin
  WriteLn(cur_out^, s);
End;

{ --------------------------------------------------------------------------
  EmitBlank : ecrire une ligne vide.
  -------------------------------------------------------------------------- }
Procedure EmitBlank;
Begin
  WriteLn(cur_out^, '');
End;

{ --------------------------------------------------------------------------
  EmitSep : ligne de separation '; ---(72 tirets)'.
  -------------------------------------------------------------------------- }
Procedure EmitSep;
Begin
  WriteLn(cur_out^,
    '; -----------------------------------------------------------------------');
End;

{ --------------------------------------------------------------------------
  EmitComment : ecrire un commentaire '; texte'.
  -------------------------------------------------------------------------- }
Procedure EmitComment(Const s : TString);
Begin
  WriteLn(cur_out^, '; ' + s);
End;

{ --------------------------------------------------------------------------
  EmitLabel : ecrire un label suivi de ':'
  (sur sa propre ligne, pas d'indentation).
  -------------------------------------------------------------------------- }
Procedure EmitLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl + ':');
End;

{ --------------------------------------------------------------------------
  EmitI : ecrire une instruction ASM indentee (8 espaces).
  Format : '        MNEM  OPERANDES   ; commentaire'
  Le commentaire est omis si c est vide.
  -------------------------------------------------------------------------- }
Procedure EmitI(Const mnem, ops, cmt : TString);
Var line : String;
Begin
  line := '        ' + mnem;
  If ops <> '' Then
  Begin
    While Length(line) < 16 Do line := line + ' ';
    line := line + ops;
  End;
  If cmt <> '' Then
  Begin
    While Length(line) < 40 Do line := line + ' ';
    line := line + '; ' + cmt;
  End;
  WriteLn(cur_out^, line);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  EmitI1 : EmitI sans commentaire (raccourci frequent).
  -------------------------------------------------------------------------- }
Procedure EmitI1(Const mnem, ops : TString);
Begin
  EmitI(mnem, ops, '');
End;

{ --------------------------------------------------------------------------
  EmitI0 : EmitI sans operande ni commentaire (ex : PUSHF, RET, NOP).
  -------------------------------------------------------------------------- }
Procedure EmitI0(Const mnem : TString);
Begin
  EmitI(mnem, '', '');
End;

{ --------------------------------------------------------------------------
  EmitDB : ecrire une directive 'label  DB  data'.
  -------------------------------------------------------------------------- }
Procedure EmitDB(Const lbl, data : TString);
Var line : String;
Begin
  line := lbl;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'DB      ' + data;
  WriteLn(cur_out^, line);
End;

{ --------------------------------------------------------------------------
  EmitDW : ecrire une directive 'label  DW  data'.
  -------------------------------------------------------------------------- }
Procedure EmitDW(Const lbl, data : TString);
Var line : String;
Begin
  line := lbl;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'DW      ' + data;
  WriteLn(cur_out^, line);
End;

{ --------------------------------------------------------------------------
  EmitDWNoLbl : DW sans label (suite d'une directive).
  -------------------------------------------------------------------------- }
Procedure EmitDWNoLbl(Const data : TString);
Begin
  WriteLn(cur_out^, '                        DW      ' + data);
End;

{ --------------------------------------------------------------------------
  EmitDBStr : emettre la definition d'une chaine litterale en DB.
  Genere :   labelData   DB   'texte', 0
  Puis   :   labelDesc   DW   OFFSET labelData, len
  -------------------------------------------------------------------------- }
Procedure EmitDBStr(Const lbl_data, lbl_desc, val : TString);
Var safe : String;
    i    : Integer;
    c    : Char;
    inq  : Boolean;    { a l'interieur d'une paire de guillemets }
    data : String;
    nlen : Integer;
Begin
  { Construit la chaine DB en gerant les caracteres de controle }
  data  := '';
  inq   := False;
  nlen  := 0;
  For i := 1 To Length(val) Do
  Begin
    c := val[i];
    If c < ' ' Then
    Begin
      If inq Then begin data := data + '''' + ','; inq := False; end;
      data := data + IntToStr(Ord(c)) + ',';
    End
    Else
    Begin
      If Not inq Then begin data := data + ''''; inq := True; end;
      data := data + c;
    End;
    Inc(nlen);
  End;
  If inq Then data := data + '''' + ',';
  data := data + '0';   { terminateur nul }

  EmitDB(lbl_data, data);
  EmitDW(lbl_desc, 'OFFSET ' + lbl_data + ', ' + IntToStr(nlen));
End;

{ --------------------------------------------------------------------------
  EmitEQU : ecrire 'name  EQU  valeur'.
  -------------------------------------------------------------------------- }
Procedure EmitEQU(Const name, valstr : TString);
Var line : String;
Begin
  line := name;
  While Length(line) < 24 Do line := line + ' ';
  line := line + 'EQU     ' + valstr;
  WriteLn(cur_out^, line);
End;

{ --------------------------------------------------------------------------
  SetFirstInstrLabel : memoriser le label du premier point d'entree.
  Utilise par GenHeader pour le 'jmp START'.
  -------------------------------------------------------------------------- }
Procedure SetFirstInstrLabel(Const lbl : TString);
Begin
  first_instr_lbl := lbl;
End;

{ --------------------------------------------------------------------------
  EmitExtern : ecrire 'EXTRN name : NEAR'.
  -------------------------------------------------------------------------- }
Procedure EmitExtern(Const name : TString);
Begin
  WriteLn(cur_out^, '        EXTRN   ' + name + ':NEAR');
End;

{ --------------------------------------------------------------------------
  EmitPublic : ecrire 'PUBLIC name'.
  -------------------------------------------------------------------------- }
Procedure EmitPublic(Const name : TString);
Begin
  WriteLn(cur_out^, '        PUBLIC  ' + name);
End;

{ ============================================================================
  TODO 05 - GENERATION DE L'EN-TETE ET DU SEGMENT .STACK
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenFileHeader : emettre l'en-tete de fichier ASM (commentaires + version).
  -------------------------------------------------------------------------- }
Procedure GenFileHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Fichier genere par CSC86 v' + CSC86_VERSION);
  EmitComment('Source : ' + src_fname);
  EmitComment('=========================================================');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenModelDirectives : directives MASM modele memoire SMALL 16 bits.
  -------------------------------------------------------------------------- }
Procedure GenModelDirectives;
Begin
  Emit('        .8086');
  Emit('        DOSSEG');
  Emit('        .MODEL  SMALL');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStackSegment : segment STACK de 512 octets (256 DW ?).
  -------------------------------------------------------------------------- }
Procedure GenStackSegment;
Begin
  EmitComment('----- Segment STACK -----');
  Emit('        .STACK  512');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenMacroDefs : emettre les macros MASM utiles (optionnel).
  On definit PRINTLN et PRINT comme alias sur les routines runtime.
  -------------------------------------------------------------------------- }
Procedure GenMacroDefs;
Begin
  EmitComment('----- Macros -----');
  { Macro EXIT_DOS : terminer le programme via INT 21h AH=4Ch }
  Emit('EXIT_DOS        MACRO');
  Emit('                MOV     AH, 4Ch');
  Emit('                INT     21h');
  Emit('                ENDM');
  EmitBlank;
  { Macro INIT_DS : initialiser DS au debut de Main }
  Emit('INIT_DS         MACRO');
  Emit('                MOV     AX, @DATA');
  Emit('                MOV     DS, AX');
  Emit('                ENDM');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenHeader : point d'entree de la phase 2 — emettre tout ce qui precede
  les segments DATA et CODE.
  Ordre MASM standard :
    1. En-tete commentaires
    2. .8086 / DOSSEG / .MODEL SMALL
    3. Macros
    4. .STACK
  -------------------------------------------------------------------------- }
Procedure GenHeader;
Begin
  GenFileHeader;
  GenModelDirectives;
  GenMacroDefs;
  GenStackSegment;
End;

{ ============================================================================
  TODO 06 - GENERATION DU SEGMENT .DATA
  ============================================================================ }

{ --------------------------------------------------------------------------
  TypeSizeWords : nombre de DW alloues pour un type donne.
  -------------------------------------------------------------------------- }
Function TypeSizeWords(vt : TValueKind; arr_size : Integer) : Integer;
Begin
  Case vt Of
    VK_ARRAY  : TypeSizeWords := arr_size;   { N DW pour arr[N] }
    VK_STRING : TypeSizeWords := 2;          { ptr + len }
  Else
    TypeSizeWords := 1;                      { int / bool / char }
  End;
End;

{ --------------------------------------------------------------------------
  GenOneGlobalVar : emettre la reservation de donnees pour un symbole global.
  -------------------------------------------------------------------------- }
Procedure GenOneGlobalVar(i : Integer);
Var lbl  : TString;
    vt   : TValueKind;
    n    : Integer;
Begin
  lbl := sym_table^[i].asm_label;
  vt  := sym_table^[i].vtype;
  n   := sym_table^[i].arr_size;
  Case vt Of
    VK_INT, VK_BOOL, VK_CHAR :
      Begin
        EmitDW(lbl, '0');
      End;
    VK_ARRAY :
      Begin
        If n <= 0 Then n := 1;
        EmitDW(lbl, IntToStr(n) + ' DUP(0)');
      End;
    VK_STRING :
      Begin
        { descripteur vide : ptr=0, len=0 }
        EmitDW(lbl, '0, 0');
      End;
  Else
    EmitComment('(variable de type inconnu : ' + lbl + ')');
  End;
End;

{ --------------------------------------------------------------------------
  GenGlobalVarsData : emettre toutes les variables globales SC_GLOBAL.
  -------------------------------------------------------------------------- }
Procedure GenGlobalVarsData;
Var i : Integer;
Begin
  If sym_count = 0 Then Exit;
  EmitComment('----- Variables globales -----');
  For i := 1 To sym_count Do
    If (sym_table^[i].scope = SC_GLOBAL) And
       (sym_table^[i].kind  = SK_VAR) Then
      GenOneGlobalVar(i);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenLiteralsData : emettre les chaines litterales et leurs descripteurs.
  Format :
    _SL_n    DB   'texte', 0
    _SLD_n   DW   OFFSET _SL_n, longueur
  -------------------------------------------------------------------------- }
Procedure GenLiteralsData;
Var i : Integer;
Begin
  If lit_count = 0 Then Exit;
  EmitComment('----- Litteraux de chaines -----');
  For i := 1 To lit_count Do
    EmitDBStr(lit_table^[i].asm_data, lit_table^[i].asm_desc,
              lit_table^[i].val);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenSystemVarsData : variables systeme utilisees par le runtime CSC86.

  _CS86_CRLF    DB  0Dh, 0Ah        ; retour chariot + saut de ligne
  _CS86_CRLFLEN DW  2                ; longueur du CRLF
  _CS86_INBUF   DB  128 DUP(0)      ; buffer d'entree console (ReadLine)
  _CS86_INLEN   DW  0               ; longueur effective apres ReadLine
  _CS86_ITOA    DB  8 DUP(0)        ; buffer de conversion int -> string
  _CS86_TRUES   DB  'True', 0       ; chaine statique 'True'
  _CS86_TRUED   DW  OFFSET _CS86_TRUES, 4
  _CS86_FALSES  DB  'False', 0      ; chaine statique 'False'
  _CS86_FALSED  DW  OFFSET _CS86_FALSES, 5
  _CS86_NULLS   DB  0               ; chaine vide (null)
  _CS86_NULLD   DW  OFFSET _CS86_NULLS, 0
  -------------------------------------------------------------------------- }
Procedure GenSystemVarsData;
Begin
  EmitComment('----- Variables systeme CSC86 -----');

  { CRLF }
  EmitDB('_CS86_CRLF',    '0Dh, 0Ah');
  EmitDW('_CS86_CRLFLEN', '2');
  EmitBlank;

  { Buffer de saisie console }
  EmitDB('_CS86_INBUF',   '128 DUP(0)');
  EmitDW('_CS86_INLEN',   '0');
  EmitBlank;

  { Buffer de conversion entier -> chaine }
  EmitDB('_CS86_ITOA',    '8 DUP(0)');
  EmitBlank;

  { Chaine 'True' }
  EmitDB('_CS86_TRUES',   '''True'', 0');
  EmitDW('_CS86_TRUED',   'OFFSET _CS86_TRUES, 4');
  EmitBlank;

  { Chaine 'False' }
  EmitDB('_CS86_FALSES',  '''False'', 0');
  EmitDW('_CS86_FALSED',  'OFFSET _CS86_FALSES, 5');
  EmitBlank;

  { Chaine nulle (null / "") }
  EmitDB('_CS86_NULLS',   '0');
  EmitDW('_CS86_NULLD',   'OFFSET _CS86_NULLS, 0');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataSegment : emettre le segment .DATA complet (passe 2).
  Ordre :
    1. Directive .DATA
    2. Variables globales utilisateur
    3. Litteraux de chaines
    4. Variables systeme
  -------------------------------------------------------------------------- }
Procedure GenDataSegment;
Begin
  EmitSep;
  EmitComment('Segment de donnees');
  EmitSep;
  Emit('        .DATA');
  EmitBlank;
  GenGlobalVarsData;
  GenLiteralsData;
  GenSystemVarsData;
  EmitBlank;
End;

{ ============================================================================
  TODO 07 - PARSER : DECLARATIONS DE TYPES ET VARIABLES
  ============================================================================ }

{ --------------------------------------------------------------------------
  Utilitaires d'erreur / avertissement
  -------------------------------------------------------------------------- }
Procedure ParseError(Const msg : TString);
Begin
  Inc(err_count);
  WriteLn('Erreur (ligne ', lex_lineno, ') : ', msg);
End;

Procedure ParseWarn(Const msg : TString);
Begin
  Inc(warn_count);
  WriteLn('Attention (ligne ', lex_lineno, ') : ', msg);
End;

{ --------------------------------------------------------------------------
  IsTypeKeyword : vrai si le token est un mot-cle de type de base.
  Reconnu : int  bool  char  string  void
  -------------------------------------------------------------------------- }
Function IsTypeKeyword(Const t : TToken) : Boolean;
Begin
  IsTypeKeyword := (t.kind = TK_KEYWORD) And
    ( (t.val = 'int')    Or (t.val = 'bool') Or
      (t.val = 'char')   Or (t.val = 'string') Or
      (t.val = 'void') );
End;

{ --------------------------------------------------------------------------
  KeywordToValueKind : convertir un mot-cle de type en TValueKind.
  -------------------------------------------------------------------------- }
Function KeywordToValueKind(Const kw : TString) : TValueKind;
Begin
  If      kw = 'int'    Then KeywordToValueKind := VK_INT
  Else If kw = 'bool'   Then KeywordToValueKind := VK_BOOL
  Else If kw = 'char'   Then KeywordToValueKind := VK_CHAR
  Else If kw = 'string' Then KeywordToValueKind := VK_STRING
  Else If kw = 'void'   Then KeywordToValueKind := VK_VOID
  Else                       KeywordToValueKind := VK_UNDEF;
End;

{ --------------------------------------------------------------------------
  ParseTypeSpec : lire un specif. de type et retourner vt + is_array.
  Syntaxe : type_kw [ '[]' ]
  Ex :  int          -> vt=VK_INT,  is_array=False
        int[]        -> vt=VK_INT,  is_array=True
        string[]     -> vt=VK_STRING, is_array=True
  Retourne True si un type a ete reconnu, False sinon.
  Consomme le token type (et '[]' si present).
  -------------------------------------------------------------------------- }
Function ParseTypeSpec(Var vt : TValueKind; Var is_array : Boolean) : Boolean;
Var t  : TToken;
    t2, t3 : TToken;
Begin
  t := LexPeek;
  If Not IsTypeKeyword(t) Then
  Begin
    ParseTypeSpec := False;
    vt       := VK_UNDEF;
    is_array := False;
    Exit;
  End;
  LexNext;                        { consommer le mot-cle }
  vt       := KeywordToValueKind(t.val);
  is_array := False;

  { Detect '[]' : le lexeur emet '[' puis ']' comme deux tokens TK_PUNCT }
  t2 := LexPeek;
  If (t2.kind = TK_PUNCT) And (t2.val = '[') Then
  Begin
    t3 := LexPeek;  { on ne peut regarder qu'un token en avance avec LexPeek }
    { On avance avec LexNext pour obtenir le token suivant le '[' }
    LexNext;        { consommer '[' }
    t3 := LexPeek;
    If (t3.kind = TK_PUNCT) And (t3.val = ']') Then
    Begin
      LexNext;      { consommer ']' }
      is_array := True;
      If vt = VK_STRING Then vt := VK_ARRAY  { string[] non supporte pour l'instant }
      Else                    vt := VK_ARRAY;
    End
    Else
      ParseError('] attendu apres [ dans le type tableau');
  End;
  ParseTypeSpec := True;
End;

{ --------------------------------------------------------------------------
  SkipToSemicolon : en cas d'erreur, avancer jusqu'au prochain ';' ou EOF.
  -------------------------------------------------------------------------- }
Procedure SkipToSemicolon;
Var t : TToken;
Begin
  Repeat
    t := LexNext;
  Until (t.kind = TK_EOF) Or
        ((t.kind = TK_PUNCT) And (t.val = ';'));
End;

{ --------------------------------------------------------------------------
  ParseConstIntExpr : evaluer une expression constante entiere simple
  au moment de la compilation. Formes supportees :
    integer_literal | char_literal | ( expr ) | -expr | +expr
    et operations binaires + - * / entre ceux-ci.
  Retourne la valeur calculee ou 0 en cas d'erreur.
  -------------------------------------------------------------------------- }
Function ParseConstIntExpr : LongInt;
Var t   : TToken;
    v   : LongInt;
    lhs : LongInt;
    op  : TString;
Begin
  t := LexPeek;

  { Parenthese }
  If (t.kind = TK_PUNCT) And (t.val = '(') Then
  Begin
    LexNext;
    v := ParseConstIntExpr;
    LexExpect(')');
    ParseConstIntExpr := v;
    Exit;
  End;

  { Unaire - }
  If (t.kind = TK_OP) And (t.val = '-') Then
  Begin
    LexNext;
    ParseConstIntExpr := -ParseConstIntExpr;
    Exit;
  End;

  { Unaire + }
  If (t.kind = TK_OP) And (t.val = '+') Then
  Begin
    LexNext;
    ParseConstIntExpr := ParseConstIntExpr;
    Exit;
  End;

  { Literal entier }
  If t.kind = TK_INT Then
  Begin
    LexNext;
    lhs := t.int_val;
    { Operateurs binaires }
    t := LexPeek;
    While (t.kind = TK_OP) And
          ((t.val = '+') Or (t.val = '-') Or
           (t.val = '*') Or (t.val = '/') Or (t.val = '%')) Do
    Begin
      op := t.val;
      LexNext;
      v := ParseConstIntExpr;
      If op = '+' Then lhs := lhs + v
      Else If op = '-' Then lhs := lhs - v
      Else If op = '*' Then lhs := lhs * v
      Else If op = '/' Then
      Begin
        If v <> 0 Then lhs := lhs Div v
        Else begin ParseError('Division par zero dans expression constante'); lhs := 0; end;
      End
      Else If op = '%' Then
      Begin
        If v <> 0 Then lhs := lhs Mod v
        Else begin ParseError('Modulo par zero dans expression constante'); lhs := 0; end;
      End;
      t := LexPeek;
    End;
    ParseConstIntExpr := lhs;
    Exit;
  End;

  { Literal char -> valeur ordinale }
  If t.kind = TK_CHAR Then
  Begin
    LexNext;
    If Length(t.val) > 0 Then
      ParseConstIntExpr := Ord(t.val[1])
    Else
      ParseConstIntExpr := 0;
    Exit;
  End;

  { true / false }
  If (t.kind = TK_KEYWORD) And (t.val = 'true')  Then begin LexNext; ParseConstIntExpr := 1; Exit; end;
  If (t.kind = TK_KEYWORD) And (t.val = 'false') Then begin LexNext; ParseConstIntExpr := 0; Exit; end;

  ParseError('Expression constante attendue, trouve : ' + t.val);
  ParseConstIntExpr := 0;
End;

{ --------------------------------------------------------------------------
  ParseConstDecl : 'const type ident = expr ;'
  Ajoute le symbole SK_CONST dans la table avec sa valeur evaluee.
  -------------------------------------------------------------------------- }
Procedure ParseConstDecl(is_global : Boolean);
Var vt       : TValueKind;
    is_arr   : Boolean;
    name     : TString;
    cval     : LongInt;
    sc       : TScope;
    idx      : Integer;
    t        : TToken;
Begin
  LexExpect('const');           { consommer 'const' }
  If Not ParseTypeSpec(vt, is_arr) Then
  Begin
    ParseError('Type attendu apres ''const''');
    SkipToSemicolon;
    Exit;
  End;
  If is_arr Then
  Begin
    ParseError('Les tableaux constants ne sont pas supportes');
    SkipToSemicolon;
    Exit;
  End;
  t := LexExpectKind(TK_IDENT);
  name := t.val;
  LexExpect('=');
  cval := ParseConstIntExpr;
  LexExpect(';');

  If is_global Then sc := SC_GLOBAL Else sc := SC_LOCAL;
  idx := AddSym(name, SK_CONST, vt, sc);
  If idx > 0 Then
    sym_table^[idx].const_val := cval;
End;

{ --------------------------------------------------------------------------
  ParseVarDecl : 'type ident [= expr] ;'  ou  'type[] ident = new type[N] ;'

  Formes supportees :
    int x;
    int x = 5;         (* initialisation par litterale, const ou -litterale *)
    bool b = true;
    string s = "...";
    int[] arr = new int[10];
    char[] buf = new char[32];

  Consomme jusqu'au ';'.
  -------------------------------------------------------------------------- }
Procedure ParseVarDecl(is_global : Boolean);
Var vt       : TValueKind;
    vt2      : TValueKind;
    is_arr   : Boolean;
    isar2    : Boolean;
    name     : TString;
    sc       : TScope;
    idx      : Integer;
    arr_size : Integer;
    t        : TToken;
    init_val : LongInt;
    has_init : Boolean;
Begin
  If Not ParseTypeSpec(vt, is_arr) Then
  Begin
    ParseError('Type attendu dans declaration de variable');
    SkipToSemicolon;
    Exit;
  End;
  t := LexExpectKind(TK_IDENT);
  name := t.val;

  arr_size := 0;
  has_init := False;
  init_val := 0;

  { Verifier si un symbole de meme nom existe deja dans la portee }
  If FindSym(name) > 0 Then
    ParseWarn('Redeclaration de : ' + name);

  t := LexPeek;
  If (t.kind = TK_OP) And (t.val = '=') Then
  Begin
    LexNext;   { consommer '=' }
    t := LexPeek;

    If is_arr Then
    Begin
      { 'new type[N]' }
      If (t.kind = TK_KEYWORD) And (t.val = 'new') Then
      Begin
        LexNext;   { 'new' }
        { type de base du tableau }
        If Not ParseTypeSpec(vt2, isar2) Then
          ParseError('Type attendu apres ''new''');
        LexExpect('[');
        arr_size := ParseConstIntExpr;
        LexExpect(']');
        If arr_size <= 0 Then
        Begin
          ParseError('Taille de tableau invalide : ' + IntToStr(arr_size));
          arr_size := 1;
        End;
      End
      Else
        ParseError('''new'' attendu dans l''initialisation de tableau');
    End
    Else
    Begin
      { Initialisation scalaire : expression constante simple }
      has_init := True;
      init_val := ParseConstIntExpr;
    End;
  End
  Else If is_arr Then
  Begin
    ParseError('Les tableaux doivent etre initialises : ' + name);
    SkipToSemicolon;
    Exit;
  End;

  LexExpect(';');

  { Enregistrer le symbole }
  If is_global Then sc := SC_GLOBAL Else sc := SC_LOCAL;

  If is_arr Then
    idx := AddLocalVar(name, VK_ARRAY, arr_size)
  Else If is_global Then
    idx := AddGlobalVar(name, vt)
  Else
    idx := AddLocalVar(name, vt, 0);

  If (idx > 0) And has_init And (Not is_arr) Then
    sym_table^[idx].const_val := init_val;
End;

{ --------------------------------------------------------------------------
  ParseParamList : '( [ type id (* , type id *) ] )'
  Enregistre les parametres dans func_table^[func_idx].
  -------------------------------------------------------------------------- }
Procedure ParseParamList(func_idx : Integer);
Var vt     : TValueKind;
    is_arr : Boolean;
    name   : TString;
    t      : TToken;
    old    : Integer;
Begin
  old := cur_func_idx;
  cur_func_idx := func_idx;

  LexExpect('(');
  t := LexPeek;
  If (t.kind = TK_PUNCT) And (t.val = ')') Then
  Begin
    LexNext;   { liste vide }
    cur_func_idx := old;
    Exit;
  End;

  Repeat
    If Not ParseTypeSpec(vt, is_arr) Then
    Begin
      ParseError('Type attendu dans la liste de parametres');
      Break;
    End;
    t := LexExpectKind(TK_IDENT);
    name := t.val;
    AddParam(name, vt);
    t := LexPeek;
    If (t.kind = TK_PUNCT) And (t.val = ',') Then
      LexNext
    Else
      Break;
  Until False;

  LexExpect(')');
  cur_func_idx := old;
End;

{ ============================================================================
  TODO 08 ... 25 : a implementer
  ============================================================================ }

BEGIN
  InitTables;
  scope_level := 0;
  WriteLn('CSC86 v' + CSC86_VERSION + ' - compilateur C# Lite -> MASM 8086');
  WriteLn('(TODO 08-25 non implementes)');
  FreeTables;
END.
