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
  MAX_SYM    = 512;    { Symboles (variables locales + globales + params)  }
  MAX_FUNC   = 128;    { Methodes statiques                                }
  MAX_LIT    = 256;    { Litteraux de chaine distincts                     }
  MAX_PARAM  = 16;     { Parametres max par methode                        }
  MAX_LOCAL  = 32;     { Variables locales max par methode                 }
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
  TODO 02 ... 25 : a implementer
  ============================================================================ }

BEGIN
  InitTables;
  WriteLn('CSC86 v' + CSC86_VERSION + ' - compilateur C# Lite -> MASM 8086');
  WriteLn('(TODO 02-25 non implementes)');
  FreeTables;
END.
