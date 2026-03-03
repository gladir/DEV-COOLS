(* OBERON86.PAS - Compilateur Oberon vers assembleur 8086
  Turbo Pascal / Free Pascal
  ================================================================

  LISTE DES TRAVAUX A REALISER (25 TODOS)
  ========================================

  TODO 01 - INFRASTRUCTURE DE BASE
    Definir les constantes globales (VERSION, MAX_SYM, MAX_SCOPE,
    MAX_LABELS, MAX_ERRORS, MAX_STR, etc.) et les types fondamentaux
    (TString, TToken, TTokenKind, etc.). Mettre en place le cadre
    principal du programme (lecture des arguments, ouverture des
    fichiers source .OBN et sortie .ASM, boucle principale).

  TODO 02 - ANALYSEUR LEXICAL (LEXER)
    Implementer le lecteur de caracteres (LexChar, LexPeek),
    la gestion des lignes/colonnes pour les messages d'erreur,
    et la reconnaissance de tous les tokens Oberon : mots-cles
    (MODULE, IMPORT, CONST, TYPE, VAR, PROCEDURE, BEGIN, END,
    IF, THEN, ELSIF, ELSE, WHILE, DO, REPEAT, UNTIL, FOR, TO,
    BY, LOOP, EXIT, CASE, OF, WITH, RETURN, DIV, MOD, IN, IS,
    OR, AND, NOT, NIL, TRUE, FALSE), identificateurs, entiers,
    reels, caracteres ('x'), chaines ("abc"), operateurs et
    delimiteurs. LexNext avance au token suivant.

  TODO 03 - TABLE DES SYMBOLES ET GESTION DE LA PORTEE
    Implementer la table des symboles (SymEnter, SymFind,
    SymFindLocal). Gerer les portees imbriquees (ScopeEnter /
    ScopeLeave) pour le module, les procedures et les blocs.
    Definir les categories de symboles : SK_CONST, SK_TYPE,
    SK_VAR, SK_PARAM, SK_PROC, SK_MODULE, SK_FIELD.

  TODO 04 - SYSTEME DE TYPES
    Implementer la representation interne des types Oberon :
    types de base INTEGER, BOOLEAN, CHAR, BYTE, SET, REAL ;
    types structures ARRAY, RECORD, POINTER, PROCEDURE ;
    chaines (ARRAY OF CHAR). Fonctions de compatibilite de
    types (TypeCompat, TypeAssignCompat) et de taille
    (TypeBitSize, TypeByteSize).

  TODO 05 - GENERATEUR DE CODE 8086 - PRIMITIVES
    Implementer le moteur d'emission assembleur 8086 :
    EmitLabel, EmitI0, EmitI1, EmitI2, EmitComment,
    EmitDB, EmitDW, EmitDD. Gerer le compteur d'instructions,
    le segment de code (.CODE), le segment de donnees (.DATA)
    et le segment de pile. Produire un fichier .ASM compatible
    MASM/TASM.

  TODO 06 - DECLARATIONS DE CONSTANTES (CONST)
    Parser la section CONST d'un module ou d'une procedure.
    Evaluer les expressions constantes au moment de la
    compilation (entiers, booleens, caracteres, chaines,
    expressions arithmetiques et booleennes sur constantes).
    Stocker dans la table des symboles avec SK_CONST.

  TODO 07 - DECLARATIONS DE TYPES (TYPE)
    Parser la section TYPE. Gerer les alias de types,
    les types tableaux (ARRAY n OF T), les types enregistrement
    (RECORD ... END) avec leurs champs, les types pointeur
    (POINTER TO T) et les types procedure (PROCEDURE (params) : T).
    Construire les descripteurs de types internes.

  TODO 08 - DECLARATIONS DE VARIABLES (VAR)
    Parser la section VAR au niveau module (variables globales,
    emises en .DATA) et au niveau procedure (variables locales,
    allouees sur la pile via BP). Calculer les offsets,
    generer les reserves memoire (DW ?, DB ?, etc.).

  TODO 09 - EXPRESSIONS - NIVEAU PRIMAIRE
    Parser les facteurs Oberon : litteraux entiers, booleens,
    caracteres, chaines, NIL, identificateurs (variables,
    constantes, appels de fonctions), acces indexes (a[i]),
    selection de champ (r.f), dereferencement (p^),
    sous-expressions entre parentheses. Generer le code 8086
    correspondant (resultat dans AX ou AX:DX pour 32 bits).

  TODO 10 - EXPRESSIONS - OPERATEURS ET PRIORITES
    Implémenter la hierarchie complete des operateurs Oberon :
    unaires (-, +, NOT) ; termes (*, /, DIV, MOD, AND) ;
    expressions simples (+, -, OR) ; relations (=, #, <, <=,
    >, >=, IN, IS). Verifier la compatibilite de types a chaque
    niveau et produire le code 8086 (MUL, IMUL, IDIV, AND, OR,
    XOR, NEG, CMP, Jcc, SETcc).

  TODO 11 - INSTRUCTION D'AFFECTATION (:=)
    Parser et generer le code pour l'affectation Oberon.
    Gerer les cas : variable simple, element de tableau,
    champ d'enregistrement, dereferencement de pointeur.
    Verifier la compatibilite de type assignation.
    Cas particulier : affectation de chaines.

  TODO 12 - INSTRUCTION IF / ELSIF / ELSE
    Parser IF expr THEN seq {ELSIF expr THEN seq} [ELSE seq] END.
    Generer les sauts conditionnels 8086 avec gestion correcte
    des etiquettes (label_else_i, label_end). Verifier que
    l'expression est de type BOOLEAN.

  TODO 13 - INSTRUCTION WHILE / REPEAT / LOOP / EXIT
    Parser WHILE expr DO seq END, REPEAT seq UNTIL expr,
    LOOP seq END avec EXIT. Generer les boucles 8086 :
    etiquettes de debut/fin, sauts conditionnels, traitement
    de EXIT (JMP vers label_end de la boucle englobante).

  TODO 14 - INSTRUCTION FOR
    Parser FOR v := debut TO fin [BY pas] DO seq END.
    Evaluer et stocker debut, fin, pas (constante obligatoire
    en Oberon). Generer l'initialisation, le test de borne
    et l'incrementation en 8086 (MOV, CMP, Jcc, ADD/SUB).

  TODO 15 - INSTRUCTION CASE
    Parser CASE expr OF {val {| val} : seq} [ELSE seq] END.
    Gerer les etiquettes entieres et caracteres. Generer
    la table de sauts ou la cascade de comparaisons 8086
    selon la densite des valeurs (table si dense, chaine
    CMP/JE si sparse).

  TODO 16 - INSTRUCTION WITH (GARDE DE TYPE)
    Parser WITH v : T DO seq END. Implementer la verification
    de type dynamique (IS) et le transtypage local de v vers T
    pour la duree du bloc. Generer le code de test de type
    a l'execution si necessaire.

  TODO 17 - DECLARATIONS DE PROCEDURES
    Parser PROCEDURE [*] nom [(params)] [: typeRetour] ;
    [corps] END nom. Gerer le prologue 8086 (PUSH BP /
    MOV BP, SP / SUB SP, taille_locales), l'epilogue
    (MOV SP, BP / POP BP / RET n), les parametres passes
    par valeur et par reference (VAR), le type retour
    (resultat dans AX).

  TODO 18 - APPELS DE PROCEDURES ET DE FONCTIONS
    Parser et generer les appels de procedures/fonctions :
    empilement des arguments dans l'ordre correct, gestion
    du type VAR (passage d'adresse via LEA), recuperation
    du resultat (AX). Gerer la recursion. Verifier l'arite
    et les types des arguments.

  TODO 19 - PROCEDURES ET FONCTIONS INTEGREES (STANDARD)
    Implementer les procedures/fonctions standard Oberon :
    INC(v[,n]), DEC(v[,n]), INCL(s,e), EXCL(s,e),
    NEW(p), DISPOSE(p), HALT(n), ASSERT(b[,n]),
    ABS(x), ODD(x), CAP(c), ORD(x), CHR(x),
    LEN(a[,d]), SHORT(x), LONG(x), ENTIER(x), SIZE(T).
    Generer le code 8086 inline ou appel runtime.

  TODO 20 - MODULE D'ENTREE/SORTIE (Out / In)
    Implementer le support des modules standard Oberon :
    Out.Int(n, w), Out.Real(r, w), Out.Char(c),
    Out.String(s), Out.Ln ; In.Int(n), In.Char(c),
    In.String(s). Generer les appels au runtime 8086
    (_JRT_WRITEINT, _JRT_WRITESTR, etc. adaptes Oberon).

  TODO 21 - GESTION DES TABLEAUX ET ENREGISTREMENTS
    Generer le code 8086 pour : acces indexe (calcul d'offset
    = base + i * taille_element, verification de borne
    optionnelle), acces champ (base + offset_champ),
    copie de structure (MOV par blocs), passage de tableau
    ouvert (ARRAY OF T) avec longueur implicite.

  TODO 22 - GESTION DES POINTEURS ET ALLOCATIONS
    Implementer NEW(p) : appel a un allocateur heap en 8086
    (runtime malloc simplifie). DISPOSE(p). Generer le
    dereferencement (p^ → [BX]). Gerer NIL (valeur 0000h).
    Optionnel : verifier le pointeur NIL a l'execution.

  TODO 23 - IMPORTATION DE MODULES (IMPORT)
    Parser la clause IMPORT et gerer la qualification
    M.x dans les expressions et instructions. Implementer
    une table des modules importes. Pour la phase 1 :
    supporter au moins In, Out, Math, SYSTEM comme modules
    connus avec leur interface predeclaree.

  TODO 24 - GESTION DES ERREURS ET MODE VERBEUX
    Implementer les messages d'erreur situes (fichier, ligne,
    colonne), le comptage des erreurs et avertissements,
    l'arret apres un seuil d'erreurs (MAX_ERRORS). Ajouter
    un mode verbeux (-v) affichant les symboles, les types
    et les statistiques de compilation (lignes, tokens,
    instructions generees).

  TODO 25 - INTEGRATION FINALE ET TESTS
    Assembler toutes les phases dans la boucle principale.
    Generer le prologue .ASM complet (modele memoire SMALL,
    directives DOSSEG, .MODEL, .STACK, .DATA, .CODE, END START).
    Creer une suite de programmes de test Oberon couvrant :
    HelloWorld, arithmetique, boucles, tableaux, enregistrements,
    pointeurs, procedures recursives. Valider la compilation
    de bout en bout avec TASM/MASM et execution sous DOSBox.

  ================================================================ *)

Program OBERON86;

{$I-}   { desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  TODO 01 - INFRASTRUCTURE DE BASE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  OBERON86_VERSION = '1.0';
  OBERON86_DATE    = '2026-03-03';

  MAX_SYM    = 1024;   { entrees dans la table des symboles       }
  MAX_PROC   = 128;    { procedures / fonctions                   }
  MAX_PARAM  = 16;     { parametres par procedure                 }
  MAX_FIELD  = 64;     { champs par RECORD                        }
  MAX_CONST  = 256;    { constantes nommees (CONST)               }
  MAX_TYPE   = 256;    { descripteurs de type                     }
  MAX_LABEL  = 1024;   { labels internes (IF/WHILE/FOR...)        }
  MAX_SCOPE  = 32;     { profondeur maximale de portee            }
  MAX_ERRORS = 30;     { arret apres N erreurs                    }
  MAX_STR    = 128;    { longueur maximale d'une TString          }
  MAX_IMPORT = 16;     { modules importes par compilation         }
  STACK_SIZE = 512;    { taille segment pile en octets            }

  { Prefixes des labels assembleur 8086 }
  OV_PFX  = '_OV_';   { variables globales (.DATA)               }
  OP_PFX  = '_OP_';   { procedures et modules                    }
  OL_PFX  = '_OL_';   { etiquettes de controle (IF/WHILE/FOR)   }
  ORT_PFX = '_ORT_';  { routines runtime                         }
  OK_PFX  = '_OK_';   { constantes de chaines litterales         }

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Tokens ---- }
  TTokenKind = (
    TK_IDENT,     { identificateur                                }
    TK_INTEGER,   { litteral entier                               }
    TK_REAL,      { litteral reel                                 }
    TK_CHAR,      { litteral caractere  0X ou 'X'                 }
    TK_STRING,    { litteral chaine  "abc"                        }
    TK_KEYWORD,   { mot-cle Oberon reserve                        }
    TK_OP,        { operateur symbolique                          }
    TK_PUNCT,     { ponctuation  : ; . , ( ) [ ] ^ &             }
    TK_EOF        { fin de fichier source                         }
  );

  TToken = Record
    kind     : TTokenKind;
    val      : TString;       { representation brute              }
    int_val  : LongInt;       { si TK_INTEGER ou TK_CHAR          }
    real_val : Real;          { si TK_REAL                        }
    line     : Integer;       { ligne dans le source              }
    col      : Integer;       { colonne dans le source            }
  End;

  { ---- Kinds de type Oberon ---- }
  TTypeKind = (
    TYK_NONE,     { non encore resolu                             }
    TYK_INTEGER,  { INTEGER (16 bits signe sur 8086)              }
    TYK_BOOLEAN,  { BOOLEAN (8 bits, 0=FALSE 1=TRUE)              }
    TYK_CHAR,     { CHAR    (8 bits)                              }
    TYK_BYTE,     { BYTE    (8 bits non signe)                    }
    TYK_SET,      { SET OF [0..15]  (16 bits, un bit par element) }
    TYK_REAL,     { REAL   (32 bits IEEE 754, emulation software) }
    TYK_ARRAY,    { ARRAY n OF T                                  }
    TYK_OPENARRAY,{ ARRAY OF T  (longueur implicite)              }
    TYK_RECORD,   { RECORD ... END                                }
    TYK_POINTER,  { POINTER TO T                                  }
    TYK_PROC,     { type procedure  PROCEDURE(params):T           }
    TYK_NIL       { type de NIL (compatible POINTER uniquement)   }
  );

  { ---- Descripteur de type ---- }
  TTypeRec = Record
    kind     : TTypeKind;
    bit_size : Integer;       { taille en bits                    }
    base_idx : Integer;       { type de base (ARRAY/POINTER/OPEN) }
    arr_len  : Integer;       { nombre d'elements si TYK_ARRAY    }
    rec_sym  : Integer;       { premier champ dans sym_table      }
    rec_nfld : Integer;       { nombre de champs du RECORD        }
  End;

  { ---- Categories de symboles ---- }
  TSymKind = (
    SK_NONE,      { entree non utilisee                           }
    SK_CONST,     { constante CONST                               }
    SK_TYPE,      { declaration TYPE                              }
    SK_VAR,       { variable (globale ou locale)                  }
    SK_PARAM,     { parametre formel (VAR ou valeur)              }
    SK_PROC,      { procedure ou fonction                         }
    SK_FIELD,     { champ de RECORD                               }
    SK_MODULE     { module importe                                }
  );

  { ---- Portee d'un symbole ---- }
  TScope = (
    SC_GLOBAL,    { niveau module (segment DATA / registre)       }
    SC_LOCAL,     { niveau procedure (pile BP)                    }
    SC_PARAM,     { parametre (pile BP, offset positif)           }
    SC_CONST      { constante evaluee au compile-time             }
  );

  { ---- Entree de la table des symboles ---- }
  TSymbol = Record
    name       : TString;     { nom tel que declare (casse conservee)  }
    kind       : TSymKind;
    scope      : TScope;
    type_idx   : Integer;     { index dans type_table                  }
    asm_label  : TString;     { label ASM : _OV_<nom>  ou  _OP_<nom>  }
    bp_offset  : Integer;     { offset BP pour variables locales/param }
    is_var_par : Boolean;     { parametre passe par reference (VAR)    }
    const_ival : LongInt;     { valeur si SK_CONST entier/char/bool    }
    const_sval : TString;     { valeur si SK_CONST chaine              }
    proc_idx   : Integer;     { si SK_PROC : index dans proc_table     }
    fld_offset : Integer;     { si SK_FIELD : offset dans le RECORD    }
    scope_level: Integer;     { niveau de portee lors de la declaration}
  End;

  TSymbolTable = Array[1..MAX_SYM]  of TSymbol;
  TTypeTable   = Array[1..MAX_TYPE] of TTypeRec;

  { ---- Parametre formel de procedure ---- }
  TParamRec = Record
    name       : TString;
    type_idx   : Integer;
    is_var_par : Boolean;     { VAR param -> passe par adresse         }
    bp_offset  : Integer;
  End;

  { ---- Entree de procedure / fonction ---- }
  TProcRec = Record
    name         : TString;
    asm_label    : TString;   { ex : _OP_<module>_<nom>               }
    ret_type_idx : Integer;   { 0 si procedure sans retour             }
    param_count  : Integer;
    params       : Array[1..MAX_PARAM] of TParamRec;
    local_size   : Integer;   { octets du cadre local sur la pile      }
    is_export    : Boolean;   { PROCEDURE* (export pour liaison)       }
  End;

  TProcTable = Array[1..MAX_PROC] of TProcRec;

  { ---- Constante nommee (section CONST) ---- }
  TConstRec = Record
    name     : TString;
    type_idx : Integer;
    ival     : LongInt;       { valeur entiere / booleen / char        }
    sval     : TString;       { valeur chaine                          }
    is_real  : Boolean;
    rval     : Real;
  End;

  TConstTable = Array[1..MAX_CONST] of TConstRec;

  { ---- Module importe ---- }
  TImportRec = Record
    mod_name : TString;       { nom d'origine (ex : Out)               }
    alias    : TString;       { alias local si IMPORT Out := Output    }
  End;

{ --- Variables globales du compilateur --- }
Var
  { Tables allouees dynamiquement }
  sym_table   : ^TSymbolTable;
  type_table  : ^TTypeTable;
  proc_table  : ^TProcTable;
  const_table : ^TConstTable;

  { Fichiers }
  src_file     : Text;
  out_file     : Text;
  tmp_file     : Text;
  cur_out      : ^Text;        { pointe sur out_file ou tmp_file       }
  src_fname    : TString;
  out_fname    : TString;
  tmp_fname    : TString;

  { Compteurs }
  sym_count    : Integer;
  type_count   : Integer;
  proc_count   : Integer;
  const_count  : Integer;
  label_count  : Integer;
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;
  str_lit_count: Integer;

  { Etat lexer }
  lex_lineno   : Integer;
  lex_colno    : Integer;
  lex_line     : String[255];
  lex_pos      : Integer;
  cur_tok      : TToken;
  peek_tok     : TToken;
  has_peek     : Boolean;
  lex_eof      : Boolean;       { vrai quand le source est epuise         }

  { Contexte de compilation }
  module_name  : TString;
  cur_proc_idx : Integer;      { 0 = niveau module                     }
  scope_sp     : Integer;      { pointeur de pile de portee            }
  scope_base   : Array[0..MAX_SCOPE] of Integer;  { base sym par portee }

  { Options }
  opt_verbose  : Boolean;
  opt_debug    : Boolean;
  opt_no_rt    : Boolean;

  { Modules importes }
  import_count : Integer;
  import_table : Array[1..MAX_IMPORT] of TImportRec;

  { Pile de labels boucle (WHILE/REPEAT/LOOP) }
  loop_depth       : Integer;
  loop_break_stk   : Array[1..MAX_SCOPE] of TString;
  loop_cont_stk    : Array[1..MAX_SCOPE] of TString;

  { Types primitifs predefinis (indexes dans type_table) }
  TYP_INTEGER  : Integer;
  TYP_BOOLEAN  : Integer;
  TYP_CHAR     : Integer;
  TYP_BYTE     : Integer;
  TYP_SET      : Integer;
  TYP_REAL     : Integer;
  TYP_NIL      : Integer;
  TYP_UNDEF    : Integer;

{ ============================================================
  Utilitaires generaux (stubs - implementation dans TODO 02+)
  ============================================================ }

Function IntToStr(n : LongInt) : TString;
Var s : TString;
Begin
  Str(n, s);
  IntToStr := s;
End;

Function StrToInt(Const s : TString) : LongInt;
Var n : LongInt; code : Integer;
Begin
  Val(s, n, code);
  StrToInt := n;
End;

Function StrUpper(Const s : TString) : TString;
Var i : Integer; r : TString;
Begin
  r := s;
  For i := 1 To Length(r) Do
    If (r[i] >= 'a') And (r[i] <= 'z') Then
      r[i] := Chr(Ord(r[i]) - 32);
  StrUpper := r;
End;

Function ChangeExtension(Const fn, ext : TString) : TString;
Var i : Integer; base : TString;
Begin
  base := fn;
  i    := Length(base);
  While (i > 0) And (base[i] <> '.') And (base[i] <> '\') And (base[i] <> '/') Do
    Dec(i);
  If (i > 0) And (base[i] = '.') Then
    base := Copy(base, 1, i - 1);
  ChangeExtension := base + ext;
End;

{ ============================================================
  TODO 02 - ANALYSEUR LEXICAL (LEXER)
  ============================================================ }

{ --- Predicats de caracteres --- }

Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or (c = '_');
End;

Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := ((c >= '0') And (c <= '9'))
    Or ((c >= 'A') And (c <= 'F'))
    Or ((c >= 'a') And (c <= 'f'));
End;

Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c);
End;

Function LexIsWS(c : Char) : Boolean;
Begin
  LexIsWS := (c = ' ') Or (c = #9) Or (c = #13);
End;

Function UpChr(c : Char) : Char;
Begin
  If (c >= 'a') And (c <= 'z') Then
    UpChr := Chr(Ord(c) - 32)
  Else
    UpChr := c;
End;

Function HexVal(c : Char) : Integer;
Begin
  If (c >= '0') And (c <= '9') Then HexVal := Ord(c) - Ord('0')
  Else If (c >= 'A') And (c <= 'F') Then HexVal := Ord(c) - Ord('A') + 10
  Else HexVal := Ord(c) - Ord('a') + 10;
End;

{ --------------------------------------------------------------------------
  LexRefill : lire la prochaine ligne du fichier source dans lex_line.
  Met lex_eof a True quand le fichier est epuise.
  -------------------------------------------------------------------------- }
Procedure LexRefill;
Begin
  If Eof(src_file) Then
  Begin
    lex_eof  := True;
    lex_line := '';
    lex_pos  := 1;
  End
  Else
  Begin
    ReadLn(src_file, lex_line);
    Inc(lex_lineno);
    lex_pos   := 1;
    lex_colno := 1;
  End;
End;

{ --------------------------------------------------------------------------
  LexCurChar : retourner le caractere courant ou #0 si fin de ligne/fichier.
  -------------------------------------------------------------------------- }
Function LexCurChar : Char;
Begin
  If lex_eof Then
    LexCurChar := #0
  Else If lex_pos > Length(lex_line) Then
    LexCurChar := #0
  Else
    LexCurChar := lex_line[lex_pos];
End;

{ --------------------------------------------------------------------------
  LexPeekChar : regarder en avance de n positions sans consommer.
  -------------------------------------------------------------------------- }
Function LexPeekChar(n : Integer) : Char;
Var p : Integer;
Begin
  p := lex_pos + n;
  If lex_eof Or (p < 1) Or (p > Length(lex_line)) Then
    LexPeekChar := #0
  Else
    LexPeekChar := lex_line[p];
End;

{ --------------------------------------------------------------------------
  LexAdvance : avancer d'un caractere ; passer a la ligne suivante si besoin.
  -------------------------------------------------------------------------- }
Procedure LexAdvance;
Begin
  If Not lex_eof Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
    If lex_pos > Length(lex_line) + 1 Then
      LexRefill;
  End;
End;

{ --------------------------------------------------------------------------
  LexSkipOberonComment : sauter un commentaire  (* ... *)  avec imbrication.
  On est positionne sur le '(' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure LexSkipOberonComment;
Var depth : Integer;
Begin
  depth := 1;
  LexAdvance;  { sauter '(' }
  LexAdvance;  { sauter '*' }
  While (Not lex_eof) And (depth > 0) Do
  Begin
    If LexCurChar = #0 Then
    Begin
      LexRefill;
    End
    Else If (LexCurChar = '(') And (LexPeekChar(1) = '*') Then
    Begin
      Inc(depth);
      LexAdvance;
      LexAdvance;
    End
    Else If (LexCurChar = '*') And (LexPeekChar(1) = ')') Then
    Begin
      Dec(depth);
      LexAdvance;
      LexAdvance;
    End
    Else
      LexAdvance;
  End;
End;

{ --------------------------------------------------------------------------
  LexSkipWS : sauter les blancs et les commentaires (* ... *).
  -------------------------------------------------------------------------- }
Procedure LexSkipWS;
Begin
  Repeat
    { Sauter espaces et tabulations }
    While (Not lex_eof) And (LexCurChar <> #0) And LexIsWS(LexCurChar) Do
      LexAdvance;

    { Fin de ligne -> ligne suivante }
    If (Not lex_eof) And (LexCurChar = #0) Then
    Begin
      LexRefill;
      Continue;
    End;

    { Commentaire Oberon  (* ... *)  eventuellement imbrique }
    If (LexCurChar = '(') And (LexPeekChar(1) = '*') Then
    Begin
      LexSkipOberonComment;
      Continue;
    End;

    Break;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexIsKeyword : verifier si s est un mot-cle Oberon (en majuscules).
  En Oberon les mots-cles sont en majuscules ; les identificateurs sont
  sensibles a la casse. On compare donc la version majuscule du lexeme.
  -------------------------------------------------------------------------- }
Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'MODULE')    Or (s = 'IMPORT')    Or (s = 'CONST')     Or
    (s = 'TYPE')      Or (s = 'VAR')       Or (s = 'PROCEDURE') Or
    (s = 'BEGIN')     Or (s = 'END')       Or
    (s = 'IF')        Or (s = 'THEN')      Or (s = 'ELSIF')     Or
    (s = 'ELSE')      Or
    (s = 'WHILE')     Or (s = 'DO')        Or
    (s = 'REPEAT')    Or (s = 'UNTIL')     Or
    (s = 'FOR')       Or (s = 'TO')        Or (s = 'BY')        Or
    (s = 'LOOP')      Or (s = 'EXIT')      Or
    (s = 'CASE')      Or (s = 'OF')        Or
    (s = 'WITH')      Or
    (s = 'RETURN')    Or
    (s = 'ARRAY')     Or (s = 'RECORD')    Or (s = 'POINTER')   Or
    (s = 'DIV')       Or (s = 'MOD')       Or
    (s = 'IN')        Or (s = 'IS')        Or
    (s = 'OR')        Or (s = 'AND')       Or (s = 'NOT')       Or
    (s = 'NIL')       Or (s = 'TRUE')      Or (s = 'FALSE');
End;

{ --------------------------------------------------------------------------
  LexMakeTok : construire un TToken passe par reference.
  -------------------------------------------------------------------------- }
Procedure LexMakeTok(Var t : TToken; k : TTokenKind; Const v : TString);
Begin
  t.kind     := k;
  t.val      := v;
  t.int_val  := 0;
  t.real_val := 0.0;
  t.line     := lex_lineno;
  t.col      := lex_colno;
End;

{ --------------------------------------------------------------------------
  LexReadIdent : lire un identifiant ou un mot-cle Oberon.
  Oberon est sensible a la casse pour les identifiants ; les mots-cles sont
  en majuscules dans le source standard.  On compare la version majuscule
  pour la detection du mot-cle mais on conserve la casse originale dans val.
  -------------------------------------------------------------------------- }
Procedure LexReadIdent(Var t : TToken);
Var s  : TString;
    su : TString;
Begin
  s  := '';
  su := '';
  While (Not lex_eof) And LexIsAlNum(LexCurChar) Do
  Begin
    If Length(s) < MAX_STR Then
    Begin
      s  := s  + LexCurChar;
      su := su + UpChr(LexCurChar);
    End;
    LexAdvance;
  End;
  If LexIsKeyword(su) Then
    LexMakeTok(t, TK_KEYWORD, su)   { mots-cles toujours en majuscules }
  Else
    LexMakeTok(t, TK_IDENT, s);     { identifiants : casse conservee   }
End;

{ --------------------------------------------------------------------------
  LexReadNumber : lire un entier decimal, un reel, un entier hexadecimal
  (suffixe H) ou un caractere Oberon (suffixe X).
  Formes reconnues :
    ddddd          entier decimal
    dddddH         entier hexadecimal (digits 0-9 A-F)
    dddddX         code de caractere (Oberon char literal)
    ddddd.ddddd    reel
    ddddd.dddddE[+-]nn  reel avec exposant
  -------------------------------------------------------------------------- }
Procedure LexReadNumber(Var t : TToken);
Var s      : TString;
    n      : LongInt;
    r      : Real;
    err    : Integer;
    is_hex : Boolean;
    i      : Integer;
Begin
  s      := '';
  n      := 0;
  is_hex := False;

  { Accumuler les chiffres (hex ou decimal) }
  While (Not lex_eof) And LexIsHexDigit(LexCurChar) Do
  Begin
    If Length(s) < MAX_STR Then s := s + LexCurChar;
    If (LexCurChar >= 'A') And (LexCurChar <= 'F') Then is_hex := True;
    If (LexCurChar >= 'a') And (LexCurChar <= 'f') Then is_hex := True;
    LexAdvance;
  End;

  { Suffixe H -> hexadecimal }
  If (LexCurChar = 'H') Or (LexCurChar = 'h') Then
  Begin
    n := 0;
    For i := 1 To Length(s) Do
      n := n * 16 + HexVal(s[i]);
    LexAdvance;
    LexMakeTok(t, TK_INTEGER, s + 'H');
    t.int_val := n;
    Exit;
  End;

  { Suffixe X -> caractere Oberon  nnnX }
  If (LexCurChar = 'X') Or (LexCurChar = 'x') Then
  Begin
    n := 0;
    For i := 1 To Length(s) Do
      n := n * 16 + HexVal(s[i]);
    LexAdvance;
    LexMakeTok(t, TK_CHAR, s + 'X');
    t.int_val := n;
    Exit;
  End;

  { Point decimal -> reel (le '..' ne doit pas etre consomme) }
  If (LexCurChar = '.') And (LexPeekChar(1) <> '.') Then
  Begin
    { Reconvertir s en decimal pour la partie entiere du reel }
    If Length(s) < MAX_STR Then s := s + '.';
    LexAdvance;
    While (Not lex_eof) And LexIsDigit(LexCurChar) Do
    Begin
      If Length(s) < MAX_STR Then s := s + LexCurChar;
      LexAdvance;
    End;
    { Exposant E }
    If (LexCurChar = 'E') Or (LexCurChar = 'e') Then
    Begin
      If Length(s) < MAX_STR Then s := s + 'E';
      LexAdvance;
      If (LexCurChar = '+') Or (LexCurChar = '-') Then
      Begin
        If Length(s) < MAX_STR Then s := s + LexCurChar;
        LexAdvance;
      End;
      While (Not lex_eof) And LexIsDigit(LexCurChar) Do
      Begin
        If Length(s) < MAX_STR Then s := s + LexCurChar;
        LexAdvance;
      End;
    End;
    LexMakeTok(t, TK_REAL, s);
    Val(s, r, err);
    If err = 0 Then t.real_val := r;
    Exit;
  End;

  { Entier pur }
  n := 0;
  For i := 1 To Length(s) Do
  Begin
    If is_hex Then
      n := n * 16 + HexVal(s[i])
    Else
      n := n * 10 + (Ord(s[i]) - Ord('0'));
  End;
  LexMakeTok(t, TK_INTEGER, s);
  t.int_val := n;
End;

{ --------------------------------------------------------------------------
  LexReadString : lire une chaine entre guillemets doubles  "texte".
  Il n'y a pas d'echappement en Oberon : un guillemet double ne peut pas
  apparaitre dans la chaine.
  -------------------------------------------------------------------------- }
Procedure LexReadString(Var t : TToken);
Var s : TString;
Begin
  s := '';
  LexAdvance;  { sauter '"' ouvrant }
  While (Not lex_eof) And (LexCurChar <> '"') And (LexCurChar <> #0) Do
  Begin
    If Length(s) < MAX_STR Then s := s + LexCurChar;
    LexAdvance;
  End;
  If LexCurChar = '"' Then
    LexAdvance;  { sauter '"' fermant }
  LexMakeTok(t, TK_STRING, s);
  { Chaine d'un seul caractere -> aussi interpretable comme TK_CHAR }
  If Length(s) = 1 Then
    t.int_val := Ord(s[1]);
End;

{ --------------------------------------------------------------------------
  LexReadOp : lire un operateur ou signe de ponctuation Oberon.
  Operateurs :  := = # < <= > >= .. + - * / & ~ |
  Ponctuation : ( ) [ ] ^ ; , . :
  -------------------------------------------------------------------------- }
Procedure LexReadOp(Var t : TToken);
Var s : TString;
    c : Char;
Begin
  c := LexCurChar;
  LexAdvance;
  s := c;

  Case c Of
    ':' : If LexCurChar = '=' Then
          Begin
            s := ':=';
            LexAdvance;
          End;
    '<' : If LexCurChar = '=' Then
          Begin
            s := '<=';
            LexAdvance;
          End;
    '>' : If LexCurChar = '=' Then
          Begin
            s := '>=';
            LexAdvance;
          End;
    '.' : If LexCurChar = '.' Then
          Begin
            s := '..';
            LexAdvance;
          End;
  End;

  { Classement en ponctuation ou en operateur }
  If (s = '(') Or (s = ')') Or (s = '[') Or (s = ']') Or
     (s = '^') Or (s = ';') Or (s = ',') Or (s = '.') Or
     (s = ':') Then
    LexMakeTok(t, TK_PUNCT, s)
  Else
    LexMakeTok(t, TK_OP, s);
End;

{ --------------------------------------------------------------------------
  LexNext : produire le token suivant dans cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Begin
  { Consommer le token anticipe si disponible }
  If has_peek Then
  Begin
    cur_tok  := peek_tok;
    has_peek := False;
    Exit;
  End;

  LexSkipWS;
  lex_colno := lex_pos;

  If lex_eof Or (LexCurChar = #0) Then
  Begin
    LexMakeTok(cur_tok, TK_EOF, '');
    Exit;
  End;

  { Identifiant ou mot-cle }
  If LexIsAlpha(LexCurChar) Then
  Begin
    LexReadIdent(cur_tok);
    Exit;
  End;

  { Litteraux numeriques : entier decimal/hex, reel, char (nX) }
  If LexIsDigit(LexCurChar) Then
  Begin
    LexReadNumber(cur_tok);
    Exit;
  End;

  { Litteraux chaine  "..." }
  If LexCurChar = '"' Then
  Begin
    LexReadString(cur_tok);
    Exit;
  End;

  { Operateurs et ponctuation }
  LexReadOp(cur_tok);
End;

{ --------------------------------------------------------------------------
  LexPeek : anticiper le token suivant sans consommer cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexPeek;
Var saved : TToken;
Begin
  If Not has_peek Then
  Begin
    saved    := cur_tok;
    LexNext;
    peek_tok := cur_tok;
    cur_tok  := saved;
    has_peek := True;
  End;
End;

{ --------------------------------------------------------------------------
  LexExpect : consommer cur_tok en verifiant que sa valeur est 'val'.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const val : TString);
Begin
  If cur_tok.val <> val Then
  Begin
    Inc(err_count);
    WriteLn('Erreur ligne ', lex_lineno, ' col ', lex_colno,
            ' : attendu ''', val, ''' mais lu ''', cur_tok.val, '''');
  End;
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : consommer cur_tok en verifiant son TTokenKind.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Begin
  If cur_tok.kind <> k Then
  Begin
    Inc(err_count);
    WriteLn('Erreur ligne ', lex_lineno, ' col ', lex_colno,
            ' : type de token inattendu (lu : ''', cur_tok.val, ''')');
  End;
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexInit : ouvrir le fichier source et charger le premier token.
  -------------------------------------------------------------------------- }
Procedure LexInit(Const fname : TString);
Begin
  Assign(src_file, fname);
  Reset(src_file);
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible d''ouvrir ', fname);
    Halt(1);
  End;
  lex_line    := '';
  lex_pos     := 1;
  lex_lineno  := 0;
  lex_colno   := 1;
  lex_eof     := False;
  has_peek    := False;
  LexRefill;
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexClose : fermer le fichier source.
  -------------------------------------------------------------------------- }
Procedure LexClose;
Begin
  If Not lex_eof Then
    Close(src_file);
End;

{ ============================================================
  TODO 03 - TABLE DES SYMBOLES ET GESTION DE LA PORTEE
  ============================================================ }

{ --------------------------------------------------------------------------
  ErrorMsg : afficher un message d'erreur situe et incrementer err_count.
  -------------------------------------------------------------------------- }
Procedure ErrorMsg(Const msg : TString);
Begin
  Inc(err_count);
  WriteLn('Erreur (', lex_lineno, ',', lex_colno, ') : ', msg);
  If err_count >= MAX_ERRORS Then
  Begin
    WriteLn('Trop d''erreurs (', MAX_ERRORS, ') - compilation abandonnee.');
    Halt(1);
  End;
End;

Procedure WarnMsg(Const msg : TString);
Begin
  Inc(warn_count);
  WriteLn('Avertissement (', lex_lineno, ',', lex_colno, ') : ', msg);
End;

{ --------------------------------------------------------------------------
  AsmIdent : convertir un identifiant Oberon en label ASM valide.
  Les caracteres non autorises en MASM sont remplaces par '_'.
  -------------------------------------------------------------------------- }
Function AsmIdent(Const s : TString) : TString;
Var i   : Integer;
    r   : TString;
    c   : Char;
Begin
  r := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If LexIsAlNum(c) Or (c = '_') Then
      r := r + c
    Else
      r := r + '_';
  End;
  AsmIdent := r;
End;

{ --------------------------------------------------------------------------
  NewLabel : generer un label de controle unique  _OL_nnn.
  -------------------------------------------------------------------------- }
Function NewLabel : TString;
Var s : TString;
Begin
  Inc(label_count);
  Str(label_count, s);
  NewLabel := OL_PFX + s;
End;

{ --------------------------------------------------------------------------
  Pile de labels de boucle (WHILE / REPEAT / LOOP).
  -------------------------------------------------------------------------- }
Procedure PushLoopLabels(Const lbl_break, lbl_cont : TString);
Begin
  If loop_depth >= MAX_SCOPE Then
  Begin
    ErrorMsg('Imbrication de boucles trop profonde');
    Exit;
  End;
  Inc(loop_depth);
  loop_break_stk[loop_depth] := lbl_break;
  loop_cont_stk[loop_depth]  := lbl_cont;
End;

Procedure PopLoopLabels;
Begin
  If loop_depth > 0 Then
    Dec(loop_depth);
End;

Function TopBreakLabel : TString;
Begin
  If loop_depth > 0 Then
    TopBreakLabel := loop_break_stk[loop_depth]
  Else
    TopBreakLabel := '';
End;

Function TopContLabel : TString;
Begin
  If loop_depth > 0 Then
    TopContLabel := loop_cont_stk[loop_depth]
  Else
    TopContLabel := '';
End;

{ --------------------------------------------------------------------------
  ScopeEnter : ouvrir un nouveau niveau de portee.
  On memorise l'indice de sym_count courant dans scope_base.
  -------------------------------------------------------------------------- }
Procedure ScopeEnter;
Begin
  If scope_sp >= MAX_SCOPE Then
  Begin
    ErrorMsg('Portee trop imbriquee');
    Exit;
  End;
  Inc(scope_sp);
  scope_base[scope_sp] := sym_count;
End;

{ --------------------------------------------------------------------------
  ScopeLeave : fermer le niveau de portee courant.
  Les symboles declares dans cette portee restent en table (acces lecture)
  mais scope_sp recule ; les futures recherches ne remonteront plus ici.
  Pour liberer les entrees locales : ClearLocalSymbols.
  -------------------------------------------------------------------------- }
Procedure ScopeLeave;
Begin
  If scope_sp > 1 Then
  Begin
    { Marquer les symboles locaux comme hors portee }
    sym_count := scope_base[scope_sp];
    Dec(scope_sp);
  End
  Else If scope_sp = 1 Then
    Dec(scope_sp);
End;

{ --------------------------------------------------------------------------
  SymEnter : ajouter un symbole dans la table.
  Retourne l'index 1-base ou 0 si la table est pleine.
  -------------------------------------------------------------------------- }
Function SymEnter(Const name : TString; kind : TSymKind;
                  scope : TScope; type_idx : Integer) : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    ErrorMsg('Table des symboles saturee');
    SymEnter := 0;
    Exit;
  End;
  Inc(sym_count);
  sym_table^[sym_count].name        := name;
  sym_table^[sym_count].kind        := kind;
  sym_table^[sym_count].scope       := scope;
  sym_table^[sym_count].type_idx    := type_idx;
  sym_table^[sym_count].asm_label   := OV_PFX + AsmIdent(name);
  sym_table^[sym_count].bp_offset   := 0;
  sym_table^[sym_count].is_var_par  := False;
  sym_table^[sym_count].const_ival  := 0;
  sym_table^[sym_count].const_sval  := '';
  sym_table^[sym_count].proc_idx    := 0;
  sym_table^[sym_count].fld_offset  := 0;
  sym_table^[sym_count].scope_level := scope_sp;
  SymEnter := sym_count;
End;

{ --------------------------------------------------------------------------
  SymFind : chercher un symbole par son nom (casse significative en Oberon).
  Parcourt la table de sym_count vers 1 (dernier declare en premier).
  Retourne l'index ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If sym_table^[i].name = name Then
    Begin
      SymFind := i;
      Exit;
    End;
  SymFind := 0;
End;

{ --------------------------------------------------------------------------
  SymFindLocal : chercher uniquement dans la portee courante.
  La portee courante commence a scope_base[scope_sp]+1.
  -------------------------------------------------------------------------- }
Function SymFindLocal(Const name : TString) : Integer;
Var i    : Integer;
    base : Integer;
Begin
  If scope_sp > 0 Then
    base := scope_base[scope_sp]
  Else
    base := 0;
  For i := sym_count DownTo base + 1 Do
    If sym_table^[i].name = name Then
    Begin
      SymFindLocal := i;
      Exit;
    End;
  SymFindLocal := 0;
End;

{ --------------------------------------------------------------------------
  SymFindInScope : chercher dans une portee donnee (par son niveau 0-based).
  -------------------------------------------------------------------------- }
Function SymFindInScope(Const name : TString; level : Integer) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If (sym_table^[i].name = name) And (sym_table^[i].scope_level = level) Then
    Begin
      SymFindInScope := i;
      Exit;
    End;
  SymFindInScope := 0;
End;

{ --------------------------------------------------------------------------
  ProcEnter : enregistrer une procedure / fonction dans proc_table.
  Retourne l'index 1-base ou 0 si la table est pleine.
  -------------------------------------------------------------------------- }
Function ProcEnter(Const name : TString; ret_type_idx : Integer;
                   is_export : Boolean) : Integer;
Var pi  : Integer;
    si  : Integer;
Begin
  If proc_count >= MAX_PROC Then
  Begin
    ErrorMsg('Trop de procedures');
    ProcEnter := 0;
    Exit;
  End;
  Inc(proc_count);
  pi := proc_count;
  proc_table^[pi].name         := name;
  proc_table^[pi].ret_type_idx := ret_type_idx;
  proc_table^[pi].param_count  := 0;
  proc_table^[pi].local_size   := 0;
  proc_table^[pi].is_export    := is_export;
  { Construire le label ASM : _OP_<module>_<name> }
  proc_table^[pi].asm_label := OP_PFX + AsmIdent(module_name) + '_' + AsmIdent(name);

  { Enregistrer aussi dans sym_table comme SK_PROC }
  si := SymEnter(name, SK_PROC, SC_GLOBAL, ret_type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].proc_idx  := pi;
    sym_table^[si].asm_label := proc_table^[pi].asm_label;
  End;
  ProcEnter := pi;
End;

{ --------------------------------------------------------------------------
  ProcFind : chercher une procedure par son nom.
  Retourne l'index dans proc_table ou 0.
  -------------------------------------------------------------------------- }
Function ProcFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := proc_count DownTo 1 Do
    If proc_table^[i].name = name Then
    Begin
      ProcFind := i;
      Exit;
    End;
  ProcFind := 0;
End;

{ --------------------------------------------------------------------------
  ProcAddParam : ajouter un parametre formel a la procedure courante.
  L'offset BP est calcule automatiquement (convention near cdecl) :
    BP+4 = premier parametre, BP+6 = deuxieme, etc.
  -------------------------------------------------------------------------- }
Procedure ProcAddParam(pi : Integer; Const pname : TString;
                       type_idx : Integer; is_var : Boolean);
Var pp  : Integer;
    si  : Integer;
    ofs : Integer;
Begin
  If proc_table^[pi].param_count >= MAX_PARAM Then
  Begin
    ErrorMsg('Trop de parametres pour ' + proc_table^[pi].name);
    Exit;
  End;
  Inc(proc_table^[pi].param_count);
  pp := proc_table^[pi].param_count;
  proc_table^[pi].params[pp].name       := pname;
  proc_table^[pi].params[pp].type_idx   := type_idx;
  proc_table^[pi].params[pp].is_var_par := is_var;
  { Offset BP : BP+4 pour le premier, +2 par parametre supplementaire }
  ofs := 4 + (pp - 1) * 2;
  proc_table^[pi].params[pp].bp_offset  := ofs;

  { Ajouter aussi dans sym_table pour la portee locale }
  si := SymEnter(pname, SK_PARAM, SC_PARAM, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].bp_offset  := ofs;
    sym_table^[si].is_var_par := is_var;
    sym_table^[si].asm_label  := '';
  End;
End;

{ --------------------------------------------------------------------------
  ProcAddLocal : allouer une variable locale dans le cadre de pile courant.
  L'offset BP negatif est calcule et mis a jour dans proc_table^[pi].local_size.
  -------------------------------------------------------------------------- }
Function ProcAddLocal(pi : Integer; Const vname : TString;
                      type_idx : Integer; byte_size : Integer) : Integer;
Var si  : Integer;
    ofs : Integer;
Begin
  { Aligner sur 2 octets }
  If byte_size Mod 2 <> 0 Then Inc(byte_size);
  proc_table^[pi].local_size := proc_table^[pi].local_size + byte_size;
  ofs := -proc_table^[pi].local_size;

  si := SymEnter(vname, SK_VAR, SC_LOCAL, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].bp_offset  := ofs;
    sym_table^[si].asm_label  := '';
  End;
  ProcAddLocal := si;
End;

{ --------------------------------------------------------------------------
  ConstEnter : ajouter une constante nommee dans const_table.
  Retourne l'index ou 0 si plein.
  -------------------------------------------------------------------------- }
Function ConstEnter(Const name : TString; type_idx : Integer;
                    ival : LongInt; Const sval : TString;
                    is_real : Boolean; rval : Real) : Integer;
Var ci : Integer;
    si : Integer;
Begin
  If const_count >= MAX_CONST Then
  Begin
    ErrorMsg('Table des constantes saturee');
    ConstEnter := 0;
    Exit;
  End;
  Inc(const_count);
  ci := const_count;
  const_table^[ci].name     := name;
  const_table^[ci].type_idx := type_idx;
  const_table^[ci].ival     := ival;
  const_table^[ci].sval     := sval;
  const_table^[ci].is_real  := is_real;
  const_table^[ci].rval     := rval;

  { Enregistrer aussi dans sym_table }
  si := SymEnter(name, SK_CONST, SC_CONST, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].const_ival := ival;
    sym_table^[si].const_sval := sval;
  End;
  ConstEnter := ci;
End;

{ --------------------------------------------------------------------------
  ConstFind : chercher une constante par son nom.
  Retourne l'index dans const_table ou 0.
  -------------------------------------------------------------------------- }
Function ConstFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := const_count DownTo 1 Do
    If const_table^[i].name = name Then
    Begin
      ConstFind := i;
      Exit;
    End;
  ConstFind := 0;
End;

{ --------------------------------------------------------------------------
  SymDumpVerbose : afficher la table des symboles (mode -v -d).
  -------------------------------------------------------------------------- }
Procedure SymDumpVerbose;
Const
  KNames : Array[TSymKind] of String[8] =
    ('NONE', 'CONST', 'TYPE', 'VAR', 'PARAM', 'PROC', 'FIELD', 'MODULE');
Var i : Integer;
Begin
  WriteLn('--- Table des symboles (', sym_count, ' entrees) ---');
  For i := 1 To sym_count Do
  Begin
    Write('  [', i:3, '] ', sym_table^[i].name:-20, ' ',
          KNames[sym_table^[i].kind], '  lv=', sym_table^[i].scope_level);
    If sym_table^[i].asm_label <> '' Then
      Write('  asm=', sym_table^[i].asm_label);
    If sym_table^[i].bp_offset <> 0 Then
      Write('  bp+', sym_table^[i].bp_offset);
    WriteLn;
  End;
End;

{ ============================================================
  TODO 04 - SYSTEME DE TYPES
  ============================================================ }

{ --------------------------------------------------------------------------
  Constructeurs de types : allouer un descripteur dans type_table.
  -------------------------------------------------------------------------- }

Function TypeNew(k : TTypeKind; bits : Integer) : Integer;
Begin
  If type_count >= MAX_TYPE Then
  Begin
    WriteLn('FATAL : table des types saturee');
    Halt(1);
  End;
  Inc(type_count);
  type_table^[type_count].kind     := k;
  type_table^[type_count].bit_size := bits;
  type_table^[type_count].base_idx := 0;
  type_table^[type_count].arr_len  := 0;
  type_table^[type_count].rec_sym  := 0;
  type_table^[type_count].rec_nfld := 0;
  TypeNew := type_count;
End;

{ Array fixe : ARRAY len OF base_idx }
Function TypeNewArray(base_idx, len : Integer) : Integer;
Var ti : Integer;
Begin
  ti := TypeNew(TYK_ARRAY, 0);  { bit_size calcule au besoin }
  type_table^[ti].base_idx := base_idx;
  type_table^[ti].arr_len  := len;
  { bit_size = len * bit_size(base) - calcule a la demande via TypeBitSize }
  TypeNewArray := ti;
End;

{ Open array : ARRAY OF base_idx (longueur inconnue a la compilation) }
Function TypeNewOpenArray(base_idx : Integer) : Integer;
Var ti : Integer;
Begin
  ti := TypeNew(TYK_OPENARRAY, 0);
  type_table^[ti].base_idx := base_idx;
  type_table^[ti].arr_len  := 0;
  TypeNewOpenArray := ti;
End;

{ Record : les champs seront ajoutes dans sym_table a partir de first_field }
Function TypeNewRecord(first_field, nfld : Integer) : Integer;
Var ti : Integer;
Begin
  ti := TypeNew(TYK_RECORD, 0);
  type_table^[ti].rec_sym  := first_field;
  type_table^[ti].rec_nfld := nfld;
  TypeNewRecord := ti;
End;

{ Pointer TO base_idx }
Function TypeNewPointer(base_idx : Integer) : Integer;
Var ti : Integer;
Begin
  ti := TypeNew(TYK_POINTER, 16);  { toujours 16 bits en modele SMALL }
  type_table^[ti].base_idx := base_idx;
  TypeNewPointer := ti;
End;

{ Type procedure / fonction (ret_idx = 0 si pas de retour) }
Function TypeNewProc(ret_idx : Integer) : Integer;
Var ti : Integer;
Begin
  ti := TypeNew(TYK_PROC, 16);
  type_table^[ti].base_idx := ret_idx;
  TypeNewProc := ti;
End;

{ --------------------------------------------------------------------------
  TypeBitSize : retourner la taille en bits du type designe par type_idx.
  Pour les tableaux, la taille est len * taille_element.
  Pour les records, elle est la somme des champs (calcul simplifie ici).
  -------------------------------------------------------------------------- }
Function TypeBitSize(ti : Integer) : Integer;
Var base_bits : Integer;
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeBitSize := 16;
    Exit;
  End;
  Case type_table^[ti].kind Of
    TYK_ARRAY :
      Begin
        base_bits := TypeBitSize(type_table^[ti].base_idx);
        TypeBitSize := type_table^[ti].arr_len * base_bits;
      End;
    TYK_OPENARRAY :
      TypeBitSize := 16;  { on ne connait pas la taille a la compilation }
    TYK_RECORD :
      { La taille exacte est stockee dans bit_size apres analyse }
      TypeBitSize := type_table^[ti].bit_size;
    TYK_POINTER :
      TypeBitSize := 16;
    TYK_PROC :
      TypeBitSize := 16;
    TYK_NIL :
      TypeBitSize := 16;
    TYK_NONE :
      TypeBitSize := 0;
  Else
    TypeBitSize := type_table^[ti].bit_size;
  End;
End;

{ --------------------------------------------------------------------------
  TypeByteSize : arrondi a l'octet superieur (minimum 1).
  -------------------------------------------------------------------------- }
Function TypeByteSize(ti : Integer) : Integer;
Var b : Integer;
Begin
  b := TypeBitSize(ti);
  If b <= 0 Then
    TypeByteSize := 1
  Else
    TypeByteSize := (b + 7) Div 8;
End;

{ --------------------------------------------------------------------------
  Predicats de categorie.
  -------------------------------------------------------------------------- }

Function TypeIsInteger(ti : Integer) : Boolean;
Begin
  TypeIsInteger := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_INTEGER);
End;

Function TypeIsBoolean(ti : Integer) : Boolean;
Begin
  TypeIsBoolean := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_BOOLEAN);
End;

Function TypeIsChar(ti : Integer) : Boolean;
Begin
  TypeIsChar := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_CHAR);
End;

Function TypeIsReal(ti : Integer) : Boolean;
Begin
  TypeIsReal := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_REAL);
End;

Function TypeIsSet(ti : Integer) : Boolean;
Begin
  TypeIsSet := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_SET);
End;

Function TypeIsPointer(ti : Integer) : Boolean;
Begin
  TypeIsPointer := (ti >= 1) And (ti <= type_count)
    And ((type_table^[ti].kind = TYK_POINTER)
      Or (type_table^[ti].kind = TYK_NIL));
End;

Function TypeIsRecord(ti : Integer) : Boolean;
Begin
  TypeIsRecord := (ti >= 1) And (ti <= type_count)
    And (type_table^[ti].kind = TYK_RECORD);
End;

Function TypeIsArray(ti : Integer) : Boolean;
Begin
  TypeIsArray := (ti >= 1) And (ti <= type_count)
    And ((type_table^[ti].kind = TYK_ARRAY)
      Or (type_table^[ti].kind = TYK_OPENARRAY));
End;

{ Ordinal = INTEGER, BOOLEAN, CHAR, BYTE, SET }
Function TypeIsOrdinal(ti : Integer) : Boolean;
Var k : TTypeKind;
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  k := type_table^[ti].kind;
  TypeIsOrdinal := (k = TYK_INTEGER) Or (k = TYK_BOOLEAN)
               Or (k = TYK_CHAR)    Or (k = TYK_BYTE)
               Or (k = TYK_SET);
End;

{ Numerique = INTEGER, BYTE, REAL }
Function TypeIsNumeric(ti : Integer) : Boolean;
Var k : TTypeKind;
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  k := type_table^[ti].kind;
  TypeIsNumeric := (k = TYK_INTEGER) Or (k = TYK_BYTE) Or (k = TYK_REAL);
End;

{ Chaine = ARRAY OF CHAR ou ARRAY n OF CHAR }
Function TypeIsString(ti : Integer) : Boolean;
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeIsString := False;
    Exit;
  End;
  If Not TypeIsArray(ti) Then
  Begin
    TypeIsString := False;
    Exit;
  End;
  TypeIsString := TypeIsChar(type_table^[ti].base_idx);
End;

{ --------------------------------------------------------------------------
  TypeCompat : compatibilite d'expression (Oberon Report §9.1).
  Regles :
    1. Meme type (meme index).
    2. t2 = NIL et t1 est POINTER.
    3. t1 et t2 sont des types numeriques (INTEGER/BYTE/REAL).
    4. t1 = CHAR et t2 = STRING d'un seul caractere (gere par le parser).
    5. t1 et t2 sont des ARRAY OF CHAR (chaines de longueurs differentes).
  -------------------------------------------------------------------------- }
Function TypeCompat(t1, t2 : Integer) : Boolean;
Begin
  { Identique }
  If t1 = t2 Then
  Begin
    TypeCompat := True;
    Exit;
  End;
  { NIL compatible avec tout pointeur }
  If (type_table^[t2].kind = TYK_NIL) And TypeIsPointer(t1) Then
  Begin
    TypeCompat := True;
    Exit;
  End;
  If (type_table^[t1].kind = TYK_NIL) And TypeIsPointer(t2) Then
  Begin
    TypeCompat := True;
    Exit;
  End;
  { Numeriques entre eux }
  If TypeIsNumeric(t1) And TypeIsNumeric(t2) Then
  Begin
    TypeCompat := True;
    Exit;
  End;
  { Chaines (ARRAY OF CHAR) }
  If TypeIsString(t1) And TypeIsString(t2) Then
  Begin
    TypeCompat := True;
    Exit;
  End;
  TypeCompat := False;
End;

{ --------------------------------------------------------------------------
  TypeAssignCompat : compatibilite d'affectation (Oberon Report §9.2).
  En plus des regles de TypeCompat :
    - t2 peut etre une chaine litterale (type_idx = TYP_CHAR, len=1) vers
      ARRAY OF CHAR (gere par le parser avant d'appeler ici).
    - Les entiers de differentes tailles sont assignables entre eux.
  -------------------------------------------------------------------------- }
Function TypeAssignCompat(t1, t2 : Integer) : Boolean;
Begin
  { Si TypeCompat passe, l'affectation est aussi compatible }
  If TypeCompat(t1, t2) Then
  Begin
    TypeAssignCompat := True;
    Exit;
  End;
  { CHAR -> ARRAY OF CHAR d'au moins 1 element }
  If TypeIsChar(t2) And TypeIsString(t1) Then
  Begin
    TypeAssignCompat := True;
    Exit;
  End;
  TypeAssignCompat := False;
End;

{ --------------------------------------------------------------------------
  TypeName : retourner une representation lisible du type (debug/erreurs).
  -------------------------------------------------------------------------- }
Function TypeName(ti : Integer) : TString;
Const
  KStr : Array[TTypeKind] of String[10] =
    ('NONE', 'INTEGER', 'BOOLEAN', 'CHAR', 'BYTE', 'SET', 'REAL',
     'ARRAY', 'OPENARRAY', 'RECORD', 'POINTER', 'PROC', 'NIL');
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeName := '?';
    Exit;
  End;
  Case type_table^[ti].kind Of
    TYK_ARRAY :
      TypeName := 'ARRAY[' + IntToStr(type_table^[ti].arr_len) + '] OF '
                + TypeName(type_table^[ti].base_idx);
    TYK_OPENARRAY :
      TypeName := 'ARRAY OF ' + TypeName(type_table^[ti].base_idx);
    TYK_POINTER :
      TypeName := 'POINTER TO ' + TypeName(type_table^[ti].base_idx);
    TYK_PROC :
      If type_table^[ti].base_idx = 0 Then
        TypeName := 'PROCEDURE'
      Else
        TypeName := 'PROCEDURE:' + TypeName(type_table^[ti].base_idx);
  Else
    TypeName := KStr[type_table^[ti].kind];
  End;
End;

{ --------------------------------------------------------------------------
  TypeCheckCompat : verifier la compatibilite et signaler une erreur si non.
  -------------------------------------------------------------------------- }
Procedure TypeCheckCompat(t1, t2 : Integer; Const ctx : TString);
Begin
  If Not TypeCompat(t1, t2) Then
    ErrorMsg('Types incompatibles dans ' + ctx
             + ' (' + TypeName(t1) + ' vs ' + TypeName(t2) + ')');
End;

Procedure TypeCheckAssign(t1, t2 : Integer);
Begin
  If Not TypeAssignCompat(t1, t2) Then
    ErrorMsg('Affectation incompatible : ' + TypeName(t2)
             + ' vers ' + TypeName(t1));
End;

{ --------------------------------------------------------------------------
  TypeDump : afficher tous les descripteurs de type (mode -v -d).
  -------------------------------------------------------------------------- }
Procedure TypeDump;
Var i : Integer;
Begin
  WriteLn('--- Table des types (', type_count, ' entrees) ---');
  For i := 1 To type_count Do
  Begin
    WriteLn('  [', i:3, '] ', TypeName(i):30,
            '  bits=', TypeBitSize(i));
  End;
End;

{ ============================================================
  Initialisation et liberation des tables
  ============================================================ }

Procedure InitTables;
Begin
  New(sym_table);
  New(type_table);
  New(proc_table);
  New(const_table);
  sym_count    := 0;
  type_count   := 0;
  proc_count   := 0;
  const_count  := 0;
  label_count  := 0;
  err_count    := 0;
  warn_count   := 0;
  instr_count  := 0;
  str_lit_count := 0;
  scope_sp     := 0;
  cur_proc_idx := 0;
  import_count := 0;
  loop_depth   := 0;
  has_peek     := False;
  lex_eof      := False;
  module_name  := 'MODULE';  { sera ecrase a la lecture du nom reel }
End;

Procedure FreeTables;
Begin
  Dispose(sym_table);
  Dispose(type_table);
  Dispose(proc_table);
  Dispose(const_table);
End;

{ Types primitifs predefinis - utilise TypeNew (TODO 04) }
Procedure InitBuiltinTypes;
Begin
  TYP_UNDEF   := TypeNew(TYK_NONE,    0);
  TYP_INTEGER := TypeNew(TYK_INTEGER, 16);
  TYP_BOOLEAN := TypeNew(TYK_BOOLEAN,  8);
  TYP_CHAR    := TypeNew(TYK_CHAR,     8);
  TYP_BYTE    := TypeNew(TYK_BYTE,     8);
  TYP_SET     := TypeNew(TYK_SET,     16);
  TYP_REAL    := TypeNew(TYK_REAL,    32);
  TYP_NIL     := TypeNew(TYK_NIL,     16);
End;

{ ============================================================
  Impression de l'usage
  ============================================================ }

Procedure PrintUsage;
Begin
  WriteLn('OBERON86 v', OBERON86_VERSION, ' - Compilateur Oberon -> MASM 8086');
  WriteLn('Usage : OBERON86 source.obn [sortie.asm] [options]');
  WriteLn('Options :');
  WriteLn('  -v   mode verbeux (statistiques et symboles)');
  WriteLn('  -d   mode debug   (trace de parsing)');
  WriteLn('  -nr  pas de liaison avec le runtime');
  Halt(1);
End;

{ ============================================================
  Lecture des arguments de la ligne de commande
  ============================================================ }

Procedure ParseArgs;
Var
  i   : Integer;
  arg : TString;
Begin
  src_fname    := '';
  out_fname    := '';
  opt_verbose  := False;
  opt_debug    := False;
  opt_no_rt    := False;

  For i := 1 To ParamCount Do
  Begin
    arg := ParamStr(i);
    If arg = '-v'  Then opt_verbose := True
    Else If arg = '-d'  Then opt_debug   := True
    Else If arg = '-nr' Then opt_no_rt   := True
    Else If arg[1] = '-' Then
    Begin
      WriteLn('Option inconnue : ', arg);
      PrintUsage;
    End
    Else If src_fname = '' Then src_fname := arg
    Else If out_fname = '' Then out_fname := arg
    Else
    Begin
      WriteLn('Argument inattendu : ', arg);
      PrintUsage;
    End;
  End;

  If src_fname = '' Then PrintUsage;

  If out_fname = '' Then
    out_fname := ChangeExtension(src_fname, '.asm');

  tmp_fname := ChangeExtension(src_fname, '.tmp');
End;

{ ============================================================
  TODO 05 - GENERATEUR DE CODE 8086 - PRIMITIVES
  ============================================================ }

Const
  ASM_INDENT = '        ';    { 8 espaces avant les mnemoniques }
  SEP_LINE   = '; ' + '------------------------------------------------------------';

{ --------------------------------------------------------------------------
  Routines de base d'emission vers cur_out.
  -------------------------------------------------------------------------- }

Procedure Emit(Const s : TString);
Begin
  WriteLn(cur_out^, s);
End;

Procedure EmitBlank;
Begin
  WriteLn(cur_out^);
End;

Procedure EmitComment(Const s : TString);
Begin
  WriteLn(cur_out^, '; ', s);
End;

Procedure EmitSep;
Begin
  WriteLn(cur_out^, SEP_LINE);
End;

Procedure EmitLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl, ':');
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Instructions ASM (8 espaces d'indentation).
  -------------------------------------------------------------------------- }

Procedure EmitI0(Const op : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op);
  Inc(instr_count);
End;

Procedure EmitI1(Const op, a : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a);
  Inc(instr_count);
End;

Procedure EmitI2(Const op, a, b : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b);
  Inc(instr_count);
End;

{ Instruction avec commentaire fin de ligne }
Procedure EmitIC(Const op, a, b, cmt : TString);
Begin
  If cmt = '' Then
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b)
  Else
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b, '  ; ', cmt);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Helpers de formatage de labels DATA.
  -------------------------------------------------------------------------- }

Function PadLabel(Const lbl : TString) : TString;
Var s : TString;
    i : Integer;
Begin
  s := lbl;
  For i := Length(s) To 23 Do
    s := s + ' ';
  PadLabel := s;
End;

{ --------------------------------------------------------------------------
  Emission de donnees dans le segment DATA.
  -------------------------------------------------------------------------- }

Procedure EmitDB(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DB      ', v);
End;

Procedure EmitDW(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DW      ', v);
End;

Procedure EmitDD(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DD      ', v);
End;

{ EmitDup : lbl  DB/DW/DD  n DUP(init)    sz=1->DB  sz=2->DW  sz=4->DD }
Procedure EmitDup(Const lbl : TString; n : Integer;
                  Const init : TString; sz : Integer);
Var dir : TString;
Begin
  Case sz Of
    1 : dir := 'DB';
    4 : dir := 'DD';
  Else
    dir := 'DW';
  End;
  WriteLn(cur_out^, PadLabel(lbl), dir, '      ',
          IntToStr(n), ' DUP(', init, ')');
End;

Procedure EmitEqu(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'EQU     ', v);
End;

{ --------------------------------------------------------------------------
  Gestion des fichiers de sortie (code principal <-> temporaire procedures).
  -------------------------------------------------------------------------- }

Procedure SwitchToTmp;
Begin
  cur_out := @tmp_file;
End;

Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

{ Copier tmp_file ligne par ligne dans out_file, puis effacer tmp_file. }
Procedure MergeTmpToMain;
Var line : String[255];
Begin
  SwitchToMain;
  Close(tmp_file);
  Assign(tmp_file, tmp_fname);
  Reset(tmp_file);
  While Not Eof(tmp_file) Do
  Begin
    ReadLn(tmp_file, line);
    WriteLn(out_file, line);
  End;
  Close(tmp_file);
  Erase(tmp_file);
End;

{ --------------------------------------------------------------------------
  En-tete du fichier ASM genere (commentaire, modele, pile).
  -------------------------------------------------------------------------- }

Procedure GenFileHeader;
Begin
  EmitSep;
  EmitComment(' Fichier genere par OBERON86 v' + OBERON86_VERSION);
  EmitComment(' Date   : ' + OBERON86_DATE);
  EmitComment(' Source : ' + src_fname);
  EmitComment(' Module : ' + module_name);
  EmitComment(' Cible  : MASM 8086, modele SMALL, near cdecl');
  EmitSep;
  EmitBlank;
End;

Procedure GenModelDirectives;
Begin
  Emit('        .MODEL  SMALL');
  Emit('        .8086');
  EmitBlank;
End;

Procedure GenStackSegment;
Begin
  EmitComment(' ----- Segment STACK -----');
  Emit('_STACK          SEGMENT PARA STACK ''STACK''');
  Emit('                DB      ' + IntToStr(STACK_SIZE) + ' DUP (?)');
  Emit('_STACK          ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Segments DATA : ouverture, variables systeme Oberon, fermeture.
  -------------------------------------------------------------------------- }

Procedure GenDataHeader;
Begin
  EmitComment(' ----- Segment DATA -----');
  Emit('_DATA           SEGMENT WORD PUBLIC ''DATA''');
  EmitBlank;
End;

Procedure GenDataFooter;
Begin
  EmitBlank;
  Emit('_DATA           ENDS');
  EmitBlank;
End;

{ Variables systeme emises avant les variables utilisateur. }
Procedure GenSystemVarsData;
Begin
  EmitComment(' ----- Variables systeme OBERON86 -----');
  EmitDup('_OV_OUTBUF',  256, '0', 1);  { buffer sortie Out.String }
  EmitDup('_OV_INBUF',   128, '0', 1);  { buffer entree In.String  }
  EmitDup('_OV_INTBUF',   12, '0', 1);  { buffer conversion entier }
  EmitDB ('_OV_CRLF',  '0Dh, 0Ah, ''$''');
  EmitDB ('_OV_NULLSTR', '0');
  EmitDB ('_OV_TRUE',  '''TRUE'', 0');
  EmitDB ('_OV_FALSE', '''FALSE'', 0');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Segment CODE : ouverture, point d'entree START, fermeture.
  -------------------------------------------------------------------------- }

Procedure GenCodeHeader;
Begin
  EmitComment(' ----- Segment CODE -----');
  Emit('_CODE           SEGMENT WORD PUBLIC ''CODE''');
  EmitBlank;
  Emit('                ASSUME CS:_CODE, DS:_DATA, SS:_STACK');
  EmitBlank;
End;

Procedure GenCodeFooter;
Begin
  EmitBlank;
  Emit('_CODE           ENDS');
  EmitBlank;
End;

{ Prologue du point d'entree START (appele avant ParseModule). }
Procedure GenStartEntry;
Begin
  EmitLabel('START');
  EmitI2('MOV', 'AX', '_DATA');
  EmitI2('MOV', 'DS', 'AX');
  EmitBlank;
End;

{ Epilogue du point d'entree START (appele apres la derniere instruction). }
Procedure GenStartExit;
Begin
  EmitBlank;
  EmitComment(' Fin normale du programme');
  EmitI2('MOV', 'AX', '4C00h');
  EmitI0('INT  21h');
  EmitBlank;
End;

{ Directive END avec point d'entree. }
Procedure GenEndDirective;
Begin
  Emit('                END     START');
End;

{ --------------------------------------------------------------------------
  Prologue / epilogue de procedure (near, convention cdecl).
  -------------------------------------------------------------------------- }

{ Prologue : PUSH BP / MOV BP,SP / SUB SP,local_size / PUSH SI DI BX }
Procedure GenProcPrologue(pi : Integer);
Begin
  EmitLabel(proc_table^[pi].asm_label);
  EmitI1('PUSH', 'BP');
  EmitI2('MOV',  'BP', 'SP');
  If proc_table^[pi].local_size > 0 Then
    EmitI2('SUB', 'SP', IntToStr(proc_table^[pi].local_size));
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitI1('PUSH', 'BX');
  EmitBlank;
End;

{ Epilogue : POP BX DI SI / MOV SP,BP / POP BP / RET }
Procedure GenProcEpilogue(pi : Integer);
Begin
  EmitBlank;
  EmitI1('POP', 'BX');
  EmitI1('POP', 'DI');
  EmitI1('POP', 'SI');
  EmitI2('MOV', 'SP', 'BP');
  EmitI1('POP', 'BP');
  EmitI0('RET');
  EmitBlank;
  { Marque de fin de procedure }
  EmitComment(' END ' + proc_table^[pi].name);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Chargement / stockage de variables dans AX selon leur portee.
  Ces helpers seront appeles par les parseurs d'expression (TODO 09+).
  -------------------------------------------------------------------------- }

{ Charger une variable globale (sym_table[si]) dans AX (ou DX:AX si 32 bits). }
Procedure GenLoadVar(si : Integer);
Var lbl  : TString;
    bits : Integer;
Begin
  lbl  := sym_table^[si].asm_label;
  bits := TypeBitSize(sym_table^[si].type_idx);
  Case bits Of
     8 : Begin EmitI2('MOV', 'AL', '[' + lbl + ']'); EmitI0('CBW'); End;
    32 : Begin
           EmitI2('MOV', 'AX', '[' + lbl + ']');
           EmitI2('MOV', 'DX', '[' + lbl + '+2]');
         End;
  Else
    EmitI2('MOV', 'AX', '[' + lbl + ']');
  End;
End;

{ Charger une variable locale / parametre (offset BP) dans AX. }
Procedure GenLoadLocal(si : Integer);
Var ofs  : Integer;
    bits : Integer;
    ref  : TString;
Begin
  ofs  := sym_table^[si].bp_offset;
  bits := TypeBitSize(sym_table^[si].type_idx);
  If ofs >= 0 Then
    ref := '[BP+' + IntToStr(ofs) + ']'
  Else
    ref := '[BP-' + IntToStr(-ofs) + ']';

  If sym_table^[si].is_var_par Then
  Begin
    { Parametre VAR : charger l'adresse puis deref }
    EmitI2('MOV', 'BX', ref);
    Case bits Of
       8 : Begin EmitI2('MOV', 'AL', '[BX]'); EmitI0('CBW'); End;
      32 : Begin EmitI2('MOV', 'AX', '[BX]'); EmitI2('MOV', 'DX', '[BX+2]'); End;
    Else
      EmitI2('MOV', 'AX', '[BX]');
    End;
  End
  Else
  Begin
    Case bits Of
       8 : Begin EmitI2('MOV', 'AL', ref); EmitI0('CBW'); End;
      32 : Begin
             EmitI2('MOV', 'AX', ref);
             If ofs >= 0 Then
               EmitI2('MOV', 'DX', '[BP+' + IntToStr(ofs + 2) + ']')
             Else
               EmitI2('MOV', 'DX', '[BP-' + IntToStr(-(ofs + 2)) + ']');
           End;
    Else
      EmitI2('MOV', 'AX', ref);
    End;
  End;
End;

{ Stocker AX dans une variable globale. }
Procedure GenStoreVar(si : Integer);
Var lbl  : TString;
    bits : Integer;
Begin
  lbl  := sym_table^[si].asm_label;
  bits := TypeBitSize(sym_table^[si].type_idx);
  Case bits Of
     8 : EmitI2('MOV', '[' + lbl + ']', 'AL');
    32 : Begin
           EmitI2('MOV', '[' + lbl + ']',     'AX');
           EmitI2('MOV', '[' + lbl + '+2]',   'DX');
         End;
  Else
    EmitI2('MOV', '[' + lbl + ']', 'AX');
  End;
End;

{ Stocker AX dans une variable locale / parametre. }
Procedure GenStoreLocal(si : Integer);
Var ofs  : Integer;
    bits : Integer;
    ref  : TString;
Begin
  ofs  := sym_table^[si].bp_offset;
  bits := TypeBitSize(sym_table^[si].type_idx);
  If ofs >= 0 Then
    ref := '[BP+' + IntToStr(ofs) + ']'
  Else
    ref := '[BP-' + IntToStr(-ofs) + ']';

  If sym_table^[si].is_var_par Then
  Begin
    EmitI2('MOV', 'BX', ref);
    Case bits Of
       8 : EmitI2('MOV', '[BX]', 'AL');
      32 : Begin EmitI2('MOV', '[BX]', 'AX'); EmitI2('MOV', '[BX+2]', 'DX'); End;
    Else
      EmitI2('MOV', '[BX]', 'AX');
    End;
  End
  Else
  Begin
    Case bits Of
       8 : EmitI2('MOV', ref, 'AL');
      32 : Begin
             EmitI2('MOV', ref, 'AX');
             If ofs >= 0 Then
               EmitI2('MOV', '[BP+' + IntToStr(ofs + 2) + ']', 'DX')
             Else
               EmitI2('MOV', '[BP-' + IntToStr(-(ofs + 2)) + ']', 'DX');
           End;
    Else
      EmitI2('MOV', ref, 'AX');
    End;
  End;
End;

{ Dispatcher : charger / stocker selon la portee du symbole. }
Procedure GenLoad(si : Integer);
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    GenLoadVar(si)
  Else
    GenLoadLocal(si);
End;

Procedure GenStore(si : Integer);
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    GenStoreVar(si)
  Else
    GenStoreLocal(si);
End;

{ ============================================================
  TODO 06 - DECLARATIONS DE CONSTANTES (CONST)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseConstExprInt : evaluer une expression constante entiere/booleenne
  au compile-time.
  Grammaire simplifiee :
    expr  = signe? terme ( op_add terme )*
    terme = fac ( op_mul fac )*
    fac   = entier | ident_const | TRUE | FALSE | '(' expr ')'
  Retourne la valeur entiere. Pour les booleens : 0=FALSE, 1=TRUE.
  -------------------------------------------------------------------------- }
Function ParseConstExprInt : LongInt; Forward;

Function ParseConstExprPrimary : LongInt;
Var ci : Integer;
    v  : LongInt;
    si : Integer;
Begin
  { Signe unaire }
  If cur_tok.val = '-' Then
  Begin
    LexNext;
    ParseConstExprPrimary := -ParseConstExprPrimary;
    Exit;
  End;
  If cur_tok.val = '+' Then
  Begin
    LexNext;
    ParseConstExprPrimary := ParseConstExprPrimary;
    Exit;
  End;
  If cur_tok.val = 'NOT' Then
  Begin
    LexNext;
    v := ParseConstExprPrimary;
    If v = 0 Then ParseConstExprPrimary := 1
    Else           ParseConstExprPrimary := 0;
    Exit;
  End;

  { Parentheses }
  If cur_tok.val = '(' Then
  Begin
    LexNext;
    v := ParseConstExprInt;
    LexExpect(')');
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteral entier }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    v := cur_tok.int_val;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteral caractere  nnnX }
  If cur_tok.kind = TK_CHAR Then
  Begin
    v := cur_tok.int_val;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteraux booleens }
  If cur_tok.val = 'TRUE' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 1;
    Exit;
  End;
  If cur_tok.val = 'FALSE' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 0;
    Exit;
  End;

  { NIL -> 0 }
  If cur_tok.val = 'NIL' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 0;
    Exit;
  End;

  { Identificateur = constante nommee }
  If cur_tok.kind = TK_IDENT Then
  Begin
    ci := ConstFind(cur_tok.val);
    If ci > 0 Then
      v := const_table^[ci].ival
    Else
    Begin
      { Chercher dans sym_table }
      si := SymFind(cur_tok.val);
      If (si > 0) And (sym_table^[si].kind = SK_CONST) Then
        v := sym_table^[si].const_ival
      Else
      Begin
        ErrorMsg('Constante inconnue : ' + cur_tok.val);
        v := 0;
      End;
    End;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  ErrorMsg('Expression constante attendue, lu : ' + cur_tok.val);
  LexNext;
  ParseConstExprPrimary := 0;
End;

Function ParseConstExprFactor : LongInt;
Var v, r : LongInt;
Begin
  v := ParseConstExprPrimary;
  While (cur_tok.val = '*') Or (cur_tok.val = 'DIV')
     Or (cur_tok.val = 'MOD') Or (cur_tok.val = 'AND') Do
  Begin
    If cur_tok.val = '*' Then
    Begin
      LexNext; r := ParseConstExprPrimary; v := v * r;
    End
    Else If cur_tok.val = 'DIV' Then
    Begin
      LexNext; r := ParseConstExprPrimary;
      If r <> 0 Then v := v Div r Else Begin ErrorMsg('Division par zero'); v := 0; End;
    End
    Else If cur_tok.val = 'MOD' Then
    Begin
      LexNext; r := ParseConstExprPrimary;
      If r <> 0 Then v := v Mod r Else Begin ErrorMsg('Modulo par zero'); v := 0; End;
    End
    Else { AND }
    Begin
      LexNext; r := ParseConstExprPrimary;
      v := v And r;
    End;
  End;
  ParseConstExprFactor := v;
End;

Function ParseConstExprInt : LongInt;
Var v, r : LongInt;
Begin
  v := ParseConstExprFactor;
  While (cur_tok.val = '+') Or (cur_tok.val = '-') Or (cur_tok.val = 'OR') Do
  Begin
    If cur_tok.val = '+' Then
    Begin
      LexNext; r := ParseConstExprFactor; v := v + r;
    End
    Else If cur_tok.val = '-' Then
    Begin
      LexNext; r := ParseConstExprFactor; v := v - r;
    End
    Else { OR }
    Begin
      LexNext; r := ParseConstExprFactor; v := v Or r;
    End;
  End;
  ParseConstExprInt := v;
End;

{ --------------------------------------------------------------------------
  ParseConstExprReal : evaluer une expression constante reelle.
  Retourne un Real. Si l'expression est entiere, la convertit.
  -------------------------------------------------------------------------- }
Function ParseConstExprReal : Real;
Var r  : Real;
    ci : Integer;
    err: Integer;
Begin
  { Signe unaire }
  If cur_tok.val = '-' Then
  Begin
    LexNext;
    ParseConstExprReal := -ParseConstExprReal;
    Exit;
  End;
  If cur_tok.val = '+' Then
  Begin
    LexNext;
    ParseConstExprReal := ParseConstExprReal;
    Exit;
  End;

  If cur_tok.kind = TK_REAL Then
  Begin
    Val(cur_tok.val, r, err);
    If err <> 0 Then r := 0.0;
    LexNext;
    ParseConstExprReal := r;
    Exit;
  End;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    r := cur_tok.int_val;
    LexNext;
    ParseConstExprReal := r;
    Exit;
  End;

  { Constante nommee reelle }
  If cur_tok.kind = TK_IDENT Then
  Begin
    ci := ConstFind(cur_tok.val);
    If (ci > 0) And const_table^[ci].is_real Then
    Begin
      r := const_table^[ci].rval;
      LexNext;
      ParseConstExprReal := r;
      Exit;
    End;
    { Retomber sur l'entier }
    ParseConstExprReal := ParseConstExprInt;
    Exit;
  End;

  ParseConstExprReal := ParseConstExprInt;
End;

{ --------------------------------------------------------------------------
  GenStringLitData : emettre un litteral de chaine en DATA.
  Retourne le label ASM genere (_OK_nnn).
  -------------------------------------------------------------------------- }
Function GenStringLitData(Const s : TString) : TString;
Var lbl : TString;
    i   : Integer;
    out_s : TString;
    c     : Char;
Begin
  Inc(str_lit_count);
  Str(str_lit_count, lbl);
  lbl := OK_PFX + lbl;

  { Construire la valeur DB : caracteres entre apostrophes + 0 terminateur }
  out_s := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (Ord(c) >= 32) And (c <> '''') Then
    Begin
      If out_s = '' Then out_s := ''''
      Else If out_s[Length(out_s)] <> '''' Then
        out_s := out_s + ', ''';
      out_s := out_s + c;
    End
    Else
    Begin
      If (out_s <> '') And (out_s[Length(out_s)] = '''') Then
        out_s := out_s + '''';
      If out_s <> '' Then out_s := out_s + ', ';
      Str(Ord(c), lbl);
      out_s := out_s + lbl + 'd';
      lbl := OK_PFX;
      Str(str_lit_count, lbl);
      lbl := OK_PFX + lbl;
    End;
  End;
  { Fermer l'apostrophe si necessaire et ajouter terminateur 0 }
  If (out_s <> '') And (out_s[Length(out_s)] <> 'd') Then
    out_s := out_s + '''';
  If out_s = '' Then
    out_s := '0'
  Else
    out_s := out_s + ', 0';

  { Emettre dans le DATA courant (avant GenDataFooter) }
  { Note : on emet dans out_file directement via SwitchToMain si besoin }
  EmitDB(lbl, out_s);
  GenStringLitData := lbl;
End;

{ --------------------------------------------------------------------------
  ParseConstDecl : parser une declaration  ident '=' constExpr  ';'.
  Supporte : entiers, booleens, caracteres, reels, chaines, expressions.
  -------------------------------------------------------------------------- }
Procedure ParseConstDecl;
Var
  cname  : TString;
  ival   : LongInt;
  rval   : Real;
  sval   : TString;
  ti     : Integer;
  is_real: Boolean;
  err    : Integer;
  slbl   : TString;
  op     : TString;
  rv2    : Real;
Begin
  cname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect('=');

  is_real := False;
  ival    := 0;
  rval    := 0.0;
  sval    := '';
  ti      := TYP_INTEGER;

  { Detecter le type par le token de valeur }
  If cur_tok.kind = TK_STRING Then
  Begin
    { Constante chaine }
    sval := cur_tok.val;
    ti   := TYP_CHAR;   { ARRAY OF CHAR sera cree si besoin en TODO 07 }
    ival := 0;
    LexNext;
  End
  Else If cur_tok.val = 'TRUE' Then
  Begin
    ival := 1; ti := TYP_BOOLEAN; LexNext;
  End
  Else If cur_tok.val = 'FALSE' Then
  Begin
    ival := 0; ti := TYP_BOOLEAN; LexNext;
  End
  Else If cur_tok.val = 'NIL' Then
  Begin
    ival := 0; ti := TYP_NIL; LexNext;
  End
  Else If cur_tok.kind = TK_CHAR Then
  Begin
    ival := cur_tok.int_val; ti := TYP_CHAR; LexNext;
  End
  Else If cur_tok.kind = TK_REAL Then
  Begin
    Val(cur_tok.val, rval, err);
    If err <> 0 Then rval := 0.0;
    is_real := True;
    ti      := TYP_REAL;
    LexNext;
    { Operateurs sur reels }
    While (cur_tok.val = '+') Or (cur_tok.val = '-') Or (cur_tok.val = '*') Do
    Begin
      op := cur_tok.val; LexNext;
      rv2 := ParseConstExprReal;
      If op = '+' Then rval := rval + rv2
      Else If op = '-' Then rval := rval - rv2
      Else rval := rval * rv2;
    End;
    ival := Round(rval);
  End
  Else
  Begin
    { Expression constante entiere (peut referencer d'autres constantes) }
    ival := ParseConstExprInt;
    ti   := TYP_INTEGER;
  End;

  { Verifier que le nom n'est pas deja declare dans cette portee }
  If SymFindLocal(cname) > 0 Then
    ErrorMsg('Constante deja declaree : ' + cname);

  { Enregistrer dans const_table et sym_table }
  ConstEnter(cname, ti, ival, sval, is_real, rval);

  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseConstSection : parser la section CONST ident = expr ;
  -------------------------------------------------------------------------- }
Procedure ParseConstSection;
Begin
  LexExpect('CONST');
  While (cur_tok.kind = TK_IDENT) Do
    ParseConstDecl;
End;

{ ============================================================
  TODO 07 - DECLARATIONS DE TYPES (TYPE)
  ============================================================ }

{ Forward : ParseArrayType / ParseRecordType / ParsePointerType / ParseProcType
  appellent tous ParseTypeRef, qui est defini plus loin. }
Function ParseTypeRef : Integer; Forward;

{ --------------------------------------------------------------------------
  ParseArrayType : ARRAY constExpr OF typeRef
  -------------------------------------------------------------------------- }
Function ParseArrayType : Integer;
Var len : LongInt;
    base: Integer;
Begin
  LexExpect('ARRAY');
  len  := ParseConstExprInt;
  LexExpect('OF');
  base := ParseTypeRef;
  ParseArrayType := TypeNewArray(base, len);
End;

{ --------------------------------------------------------------------------
  ParseRecordType : RECORD ident-list : typeRef ; ... END
  Chaque champ est inscrit dans sym_table comme SK_FIELD avec son offset.
  -------------------------------------------------------------------------- }
Function ParseRecordType : Integer;
Var first_fld : Integer;
    nfld      : Integer;
    off       : Integer;
    fti       : Integer;
    si        : Integer;
    names     : Array[1..MAX_FIELD] of TString;
    nnames    : Integer;
    k         : Integer;
Begin
  LexExpect('RECORD');
  first_fld := sym_count + 1;
  nfld      := 0;
  off       := 0;
  While (cur_tok.kind = TK_IDENT) Do
  Begin
    { Collecter les noms de champs : ident, ident, ... }
    nnames      := 1;
    names[1]    := cur_tok.val;
    LexNext;
    While cur_tok.val = ',' Do
    Begin
      LexNext;
      If nnames < MAX_FIELD Then
      Begin
        Inc(nnames);
        names[nnames] := cur_tok.val;
      End;
      LexExpectKind(TK_IDENT);
    End;
    LexExpect(':');
    fti := ParseTypeRef;
    { Inscrire chaque champ dans sym_table }
    For k := 1 To nnames Do
    Begin
      si := SymEnter(names[k], SK_FIELD, SC_GLOBAL, fti);
      If si > 0 Then
      Begin
        sym_table^[si].fld_offset := off;
        Inc(off, TypeByteSize(fti));
        Inc(nfld);
      End;
    End;
    { Separateur ; optionnel entre groupes de champs }
    If cur_tok.val = ';' Then
      LexNext
    Else If cur_tok.val <> 'END' Then
      ErrorMsg('Point-virgule ou END attendu dans RECORD');
  End;
  LexExpect('END');
  ParseRecordType := TypeNewRecord(first_fld, nfld);
End;

{ --------------------------------------------------------------------------
  ParsePointerType : POINTER TO typeRef
  -------------------------------------------------------------------------- }
Function ParsePointerType : Integer;
Var base : Integer;
Begin
  LexExpect('POINTER');
  LexExpect('TO');
  base := ParseTypeRef;
  ParsePointerType := TypeNewPointer(base);
End;

{ --------------------------------------------------------------------------
  ParseProcType : PROCEDURE [ ( params ) ] [ : typeRef ]
  Simplifie : on capture le type de retour ; le detail des parametres
  formels sera gere en TODO 17 (on saute les parentheses ici).
  -------------------------------------------------------------------------- }
Function ParseProcType : Integer;
Var ret_ti : Integer;
    depth  : Integer;
Begin
  LexExpect('PROCEDURE');
  ret_ti := 0;
  { Sauter les parametres entre parentheses - sera traite en TODO 17 }
  If cur_tok.val = '(' Then
  Begin
    depth := 1;
    LexNext;   { consomme '(' }
    While (depth > 0) And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.val = '(' Then Inc(depth)
      Else If cur_tok.val = ')' Then Dec(depth);
      LexNext;
    End;
    { apres la boucle, '(' final vient d'etre consomme par le dernier LexNext }
  End;
  { Type de retour facultatif }
  If cur_tok.val = ':' Then
  Begin
    LexNext;
    ret_ti := ParseTypeRef;
  End;
  ParseProcType := TypeNewProc(ret_ti);
End;

{ --------------------------------------------------------------------------
  ParseTypeRef : parser une designation de type Oberon.
  Retourne l'index dans type_table.
    ident              -> alias de type (SK_TYPE dans sym_table)
    ARRAY  n OF T      -> ParseArrayType
    RECORD ... END     -> ParseRecordType
    POINTER TO T       -> ParsePointerType
    PROCEDURE [(.)] :T -> ParseProcType
  -------------------------------------------------------------------------- }
Function ParseTypeRef;
Var tok : TString;
    si  : Integer;
Begin
  tok := cur_tok.val;
  If tok = 'ARRAY' Then
    ParseTypeRef := ParseArrayType
  Else If tok = 'RECORD' Then
    ParseTypeRef := ParseRecordType
  Else If tok = 'POINTER' Then
    ParseTypeRef := ParsePointerType
  Else If tok = 'PROCEDURE' Then
    ParseTypeRef := ParseProcType
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    LexNext;   { consommer le nom }
    si := SymFind(tok);
    If (si > 0) And (sym_table^[si].kind = SK_TYPE) Then
      ParseTypeRef := sym_table^[si].type_idx
    Else
    Begin
      ErrorMsg('Type inconnu : ' + tok);
      ParseTypeRef := TYP_UNDEF;
    End;
  End
  Else
  Begin
    ErrorMsg('Designation de type attendue, obtenu : ' + cur_tok.val);
    LexNext;
    ParseTypeRef := TYP_UNDEF;
  End;
End;

{ --------------------------------------------------------------------------
  ParseTypeDecl : ident = typeRef ;
  Cree un alias de type et l'inscrit comme SK_TYPE dans sym_table.
  -------------------------------------------------------------------------- }
Procedure ParseTypeDecl;
Var tname : TString;
    ti    : Integer;
    si    : Integer;
Begin
  tname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect('=');
  ti := ParseTypeRef;
  If SymFindLocal(tname) > 0 Then
    WarnMsg('Type deja declare dans cette portee : ' + tname);
  si := SymEnter(tname, SK_TYPE, SC_GLOBAL, ti);
  If si > 0 Then
    sym_table^[si].asm_label := '';   { les types n'ont pas de label ASM }
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseTypeSection : TYPE ident = typeRef ; ...
  -------------------------------------------------------------------------- }
Procedure ParseTypeSection;
Begin
  LexExpect('TYPE');
  While (cur_tok.kind = TK_IDENT) Do
    ParseTypeDecl;
End;

{ ============================================================
  TODO 08 - DECLARATIONS DE VARIABLES (VAR)
  ============================================================ }

{ --------------------------------------------------------------------------
  GenGlobalVarData : emettre la reserve DATA pour une variable globale.
  Le cur_out doit pointer vers out_file (segment DATA).
  -------------------------------------------------------------------------- }
Procedure GenGlobalVarData(si : Integer);
Var lbl : TString;
    ti  : Integer;
    nb  : Integer;
Begin
  lbl := sym_table^[si].asm_label;
  ti  := sym_table^[si].type_idx;
  If (ti < 1) Or (ti > type_count) Then
  Begin
    EmitDW(lbl, '0');
    Exit;
  End;
  nb := TypeByteSize(ti);
  If nb < 1 Then nb := 2;
  Case type_table^[ti].kind Of
    TYK_BOOLEAN,
    TYK_CHAR,
    TYK_BYTE    : EmitDB(lbl, '0');
    TYK_SET,
    TYK_INTEGER,
    TYK_POINTER : EmitDW(lbl, '0');
    TYK_REAL    : EmitDD(lbl, '0');
    TYK_PROC    : EmitDW(lbl, '0');
    TYK_ARRAY,
    TYK_RECORD  : EmitDup(lbl, nb, '0', 1);   { nb DB 0 }
  Else
    EmitDW(lbl, '0');
  End;
End;

{ --------------------------------------------------------------------------
  ParseVarDecl : parser un groupe de declarations de variables.
    IdentList : TypeRef ;
  is_local    = False -> variables globales (symbol SC_GLOBAL + DATA)
  is_local    = True  -> variables locales (symbol SC_LOCAL, BP negatif)
  local_off   = offset courant (negatif) sur la pile, mis a jour en sortie.
  -------------------------------------------------------------------------- }
Procedure ParseVarDecl(is_local : Boolean; Var local_off : Integer);
Var names  : Array[1..MAX_FIELD] of TString;
    nnames : Integer;
    ti     : Integer;
    k      : Integer;
    nb     : Integer;
    si     : Integer;
Begin
  { Collecter la liste des identificateurs }
  nnames   := 1;
  names[1] := cur_tok.val;
  LexExpectKind(TK_IDENT);
  While cur_tok.val = ',' Do
  Begin
    LexNext;
    If nnames < MAX_FIELD Then
    Begin
      Inc(nnames);
      names[nnames] := cur_tok.val;
    End;
    LexExpectKind(TK_IDENT);
  End;
  LexExpect(':');
  ti := ParseTypeRef;
  nb := TypeByteSize(ti);
  If nb < 1 Then nb := 2;
  { Inscrire chaque variable dans sym_table et generer sa reserve }
  For k := 1 To nnames Do
  Begin
    If SymFindLocal(names[k]) > 0 Then
      ErrorMsg('Variable deja declaree : ' + names[k]);
    If is_local Then
    Begin
      { Variable locale : reserve sur la pile }
      Dec(local_off, nb);                          { BP - nb }
      si := SymEnter(names[k], SK_VAR, SC_LOCAL, ti);
      If si > 0 Then
      Begin
        sym_table^[si].bp_offset := local_off;
        sym_table^[si].asm_label := '';             { pas de label DATA }
        { Mettre a jour local_size de la procedure courante }
        If cur_proc_idx > 0 Then
        Begin
          If (-local_off) > proc_table^[cur_proc_idx].local_size Then
            proc_table^[cur_proc_idx].local_size := -local_off;
        End;
      End;
    End
    Else
    Begin
      { Variable globale : reserve dans le segment DATA }
      si := SymEnter(names[k], SK_VAR, SC_GLOBAL, ti);
      If si > 0 Then
      Begin
        sym_table^[si].asm_label := OV_PFX + AsmIdent(names[k]);
        GenGlobalVarData(si);
      End;
    End;
  End;
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseVarSection : VAR IdentList : TypeRef ; ...
  is_local  : True si on est dans une procedure (variables locales).
  local_off : offset BP courant (negatif), mis a jour par ParseVarDecl.
  -------------------------------------------------------------------------- }
Procedure ParseVarSection(is_local : Boolean; Var local_off : Integer);
Begin
  LexExpect('VAR');
  While (cur_tok.kind = TK_IDENT) Do
    ParseVarDecl(is_local, local_off);
End;

{ ============================================================
  TODO 09 - EXPRESSIONS - NIVEAU PRIMAIRE
  ============================================================ }

{ Forward : ParseExpr est defini en TODO 10 ; ParseFactor l'appelle
  pour les sous-expressions entre parentheses et les index de tableau. }
Function ParseExpr : Integer; Forward;

{ --------------------------------------------------------------------------
  GenLoadConst : charger une valeur immediate dans AX (ou DX:AX si 32 bits).
  -------------------------------------------------------------------------- }
Procedure GenLoadConst(v : LongInt; ti : Integer);
Begin
  If (ti >= 1) And (ti <= type_count) And (TypeBitSize(ti) = 32) Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(v And $FFFF));
    EmitI2('MOV', 'DX', IntToStr((v Shr 16) And $FFFF));
    Exit;
  End;
  EmitI2('MOV', 'AX', IntToStr(v And $FFFF));
End;

{ --------------------------------------------------------------------------
  GenLoadAddr : charger l'adresse (near ptr) d'un symbole dans BX.
  -------------------------------------------------------------------------- }
Procedure GenLoadAddr(si : Integer);
Var ofs : Integer;
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    EmitI2('LEA', 'BX', '[' + sym_table^[si].asm_label + ']')
  Else
  Begin
    ofs := sym_table^[si].bp_offset;
    If ofs >= 0 Then
      EmitI2('LEA', 'BX', '[BP+' + IntToStr(ofs) + ']')
    Else
      EmitI2('LEA', 'BX', '[BP-' + IntToStr(-ofs) + ']');
  End;
End;

{ --------------------------------------------------------------------------
  ParseDesignator : ident postfix*
    postfix = '.' ident          (champ de RECORD)
            | '[' expr ']'       (element de tableau)
            | '^'                (dereferencement de pointeur)
  Charge la valeur finale dans AX (ou BX pour les aggregats).
  Retourne le type_idx resultant.
  -------------------------------------------------------------------------- }
Function ParseDesignator : Integer;
Var name    : TString;
    si      : Integer;
    ti      : Integer;
    el_ti   : Integer;
    el_size : Integer;
    fld_idx : Integer;
    k       : Integer;
Begin
  name := cur_tok.val;
  LexExpectKind(TK_IDENT);
  si := SymFind(name);
  If si = 0 Then
  Begin
    ErrorMsg('Identifiant inconnu : ' + name);
    ParseDesignator := TYP_UNDEF;
    Exit;
  End;

  ti := sym_table^[si].type_idx;

  { Charger la valeur ou l'adresse de base selon la nature du symbole }
  Case sym_table^[si].kind Of
    SK_CONST :
      GenLoadConst(sym_table^[si].const_ival, ti);
    SK_TYPE :
      ErrorMsg('Nom de type non valide dans une expression : ' + name);
    SK_PROC :
      Begin
        { Appel sans arguments a completer en TODO 18 - on met AX=0 }
        EmitI2('MOV', 'AX', '0');
      End;
  Else
    { SK_VAR, SK_PARAM, SK_FIELD }
    GenLoad(si);
  End;

  { Post-fixes }
  While (cur_tok.val = '.') Or (cur_tok.val = '[') Or (cur_tok.val = '^') Do
  Begin
    If cur_tok.val = '.' Then
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_RECORD) Then
        ErrorMsg('Selection de champ sur un type non RECORD');
      name := cur_tok.val;
      LexExpectKind(TK_IDENT);
      fld_idx := 0;
      For k := type_table^[ti].rec_sym To
               type_table^[ti].rec_sym + type_table^[ti].rec_nfld - 1 Do
        If (k >= 1) And (k <= sym_count) And (sym_table^[k].name = name) Then
        Begin
          fld_idx := k;
          Break;
        End;
      If fld_idx = 0 Then
        ErrorMsg('Champ inconnu : ' + name)
      Else
      Begin
        { On suppose BX = adresse de base du record }
        EmitI2('ADD', 'BX', IntToStr(sym_table^[fld_idx].fld_offset));
        EmitI2('MOV', 'AX', '[BX]');
        ti := sym_table^[fld_idx].type_idx;
      End;
    End
    Else If cur_tok.val = '[' Then
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_ARRAY) Then
        ErrorMsg('Acces indexe sur un type non ARRAY');
      el_ti   := type_table^[ti].base_idx;
      el_size := TypeByteSize(el_ti);
      If el_size < 1 Then el_size := 1;
      { Sauvegarder l'adresse de base (AX) dans BX }
      EmitI2('MOV', 'BX', 'AX');
      { Evaluer l'index -> AX }
      ParseExpr;
      { Calculer l'offset : AX * el_size }
      If el_size = 2 Then
        EmitI0('SHL  AX, 1')
      Else If el_size > 2 Then
      Begin
        EmitI2('MOV', 'CX', IntToStr(el_size));
        EmitI0('MUL  CX');
      End;
      EmitI2('ADD', 'BX', 'AX');
      EmitI2('MOV', 'AX', '[BX]');
      ti := el_ti;
      LexExpect(']');
    End
    Else
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_POINTER) Then
        ErrorMsg('Dereferencement sur un type non POINTER');
      EmitI2('MOV', 'BX', 'AX');
      EmitI2('MOV', 'AX', '[BX]');
      ti := type_table^[ti].base_idx;
    End;
  End;

  ParseDesignator := ti;
End;

{ --------------------------------------------------------------------------
  ParseFactor : facteur primaire Oberon.
  Grammaire :
    factor = integer | char | real | string
           | TRUE | FALSE | NIL
           | '~' factor
           | '(' expr ')'
           | designator [ '(' ExprList ')' ]
  Resultat dans AX ; type retourne.
  Les appels de fonction sont des stubs (TODO 18).
  -------------------------------------------------------------------------- }
Function ParseFactor : Integer;
Var ti    : Integer;
    lbl   : TString;
    n_str : TString;
Begin
  ti := TYP_UNDEF;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    ti := TYP_INTEGER;
    LexNext;
  End
  Else If cur_tok.kind = TK_CHAR Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    ti := TYP_CHAR;
    LexNext;
  End
  Else If cur_tok.kind = TK_REAL Then
  Begin
    { Constante reelle : emettre une reserve DD dans DATA et charger l'adresse }
    Inc(str_lit_count);
    Str(str_lit_count, n_str);
    lbl := OK_PFX + 'R' + n_str;
    EmitDD(lbl, cur_tok.val);
    EmitI2('LEA', 'AX', '[' + lbl + ']');
    ti := TYP_REAL;
    LexNext;
  End
  Else If cur_tok.kind = TK_STRING Then
  Begin
    lbl := GenStringLitData(cur_tok.val);
    EmitI2('LEA', 'AX', '[' + lbl + ']');
    ti := TypeNewArray(TYP_CHAR, Length(cur_tok.val) + 1);
    LexNext;
  End
  Else If cur_tok.val = 'TRUE' Then
  Begin
    EmitI2('MOV', 'AX', '1');
    ti := TYP_BOOLEAN;
    LexNext;
  End
  Else If cur_tok.val = 'FALSE' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_BOOLEAN;
    LexNext;
  End
  Else If cur_tok.val = 'NIL' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_NIL;
    LexNext;
  End
  Else If cur_tok.val = '~' Then
  Begin
    LexNext;
    ti := ParseFactor;
    If Not TypeIsBoolean(ti) Then
      ErrorMsg('NOT applicable uniquement sur BOOLEAN');
    EmitI2('XOR', 'AX', '1');
  End
  Else If cur_tok.val = '(' Then
  Begin
    LexNext;
    ti := ParseExpr;
    LexExpect(')');
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    ti := ParseDesignator;
    { Appel de procedure/fonction : '(' suit le designateur -- stub TODO 18 }
    If cur_tok.val = '(' Then
    Begin
      LexNext;
      If cur_tok.val <> ')' Then
      Begin
        ParseExpr;
        While cur_tok.val = ',' Do
        Begin
          LexNext;
          ParseExpr;
        End;
      End;
      LexExpect(')');
      EmitI2('MOV', 'AX', '0');
    End;
  End
  Else
  Begin
    ErrorMsg('Facteur attendu, obtenu : ' + cur_tok.val);
    LexNext;
  End;

  ParseFactor := ti;
End;

{ --------------------------------------------------------------------------
  ParseExpr : stub minimal - sera remplace en TODO 10 (hierarchie complete).
  Pour l'instant, delègue a ParseFactor pour permettre la compilation.
  -------------------------------------------------------------------------- }
Function ParseExpr;
Begin
  ParseExpr := ParseFactor;
End;

{ ============================================================
  Programme principal
  ============================================================ }

Begin
  { --- Arguments --- }
  ParseArgs;

  { --- Initialisation --- }
  InitTables;
  InitBuiltinTypes;

  { --- Ouverture du source et lancement du lexer --- }
  LexInit(src_fname);  { ouvre src_file, charge le premier token }

  { --- Portee module (niveau 1) --- }
  ScopeEnter;

  { --- Ouverture de la sortie --- }
  Assign(out_file, out_fname);
  Rewrite(out_file);
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible de creer ', out_fname);
    Close(src_file);
    Halt(1);
  End;
  cur_out := @out_file;

  { --- Ouverture du fichier temporaire (code des procedures) --- }
  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);

  { --- Compilation principale (TODO 04 -> 24) --- }
  { En-tete complet du fichier ASM }
  GenFileHeader;
  GenModelDirectives;
  GenStackSegment;
  GenDataHeader;
  GenSystemVarsData;
  { Les variables globales seront ajoutees ici (TODO 08) }
  GenDataFooter;
  GenCodeHeader;
  GenStartEntry;

  { ParseModule; }

  GenStartExit;
  GenCodeFooter;
  { MergeTmpToMain; }    { fusionner les procedures (TODO 17) }
  GenEndDirective;

  { --- Fermeture --- }
  ScopeLeave;  { fermer la portee module }
  LexClose;
  Close(tmp_file);
  Close(out_file);

  { --- Rapport final --- }
  If opt_verbose Then
  Begin
    WriteLn('Symboles   : ', sym_count);
    WriteLn('Procedures : ', proc_count);
    WriteLn('Types      : ', type_count);
    WriteLn('Erreurs    : ', err_count);
    WriteLn('Avertissements : ', warn_count);
    WriteLn('Instructions   : ', instr_count);
    If opt_debug Then
    Begin
      TypeDump;
      SymDumpVerbose;
    End;
  End;

  FreeTables;

  If err_count > 0 Then
  Begin
    WriteLn(err_count, ' erreur(s) - compilation echouee.');
    Halt(1);
  End
  Else
  Begin
    If opt_verbose Then
      WriteLn('Compilation reussie -> ', out_fname);
  End;
End.
