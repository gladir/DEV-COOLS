{ ============================================================================
  SNOBOL86.PAS  -  Compilateur SNOBOL 4 -> Assembleur 8086 (MASM/TASM)
  Langage hote : Turbo Pascal / Free Pascal (ne compile pas en Turbo Pascal, programme trop gros)
  Cible        : .MODEL SMALL, MS-DOS, INT 21h
  Auteur       : Sylvain Maltais
  ============================================================================

  APERCU DU LANGAGE SNOBOL 4
  ---------------------------
  SNOBOL 4 (StriNg Oriented and symBOlic Language) est un langage de
  manipulation de chaines invente aux Bell Labs (1967).
  Une instruction SNOBOL a la forme generale :

      LABEL   SUJET   PATRON = REMPLACEMENT   :GOTO

  - LABEL      : etiquette optionnelle (colonne 1)
  - SUJET      : variable dont le contenu est inspecte/modifie
  - PATRON     : expression de filtrage (pattern matching)
  - REMPLACEMENT : chaine substituee dans le sujet apres matching reussi
  - GOTO       : branchement conditionnel :S(lbl) :F(lbl) ou :(lbl)

  Types de donnees : STRING, INTEGER, REAL, PATTERN, TABLE, ARRAY.
  Gestion memoire  : garbage collection automatique (heap dynamique).
  Caractere fin    : ligne contenant "-END-".

  LISTE DES 25 TODOS
  ------------------

  TODO 01 - EN-TETE, CONSTANTES ET OPTIONS DU COMPILATEUR
    Definir les constantes globales (MAX_SYM, MAX_LABEL, MAX_PAT,
    MAX_STR, MAX_SUB, MAX_LIT, MAX_BUILTIN, niveaux de debug, etc.).
    Definir les options de compilation ($MODE, $LIST, $ERRORS).
    Preparer le squelette ($A-)($I-) et les directives FPC.

  TODO 02 - TYPES FONDAMENTAUX ET STRUCTURES DE DONNEES
    Definir les enumerations : TokType (TOK_IDENT, TOK_INTEGER,
    TOK_REAL, TOK_STRING, TOK_EOF, TOK_LPAREN, TOK_RPAREN, TOK_COMMA,
    TOK_EQ, TOK_COLON, TOK_AT, TOK_BANG, TOK_AMP, TOK_PIPE, ...).
    Definir les kinds de valeur runtime : VK_STR, VK_INT, VK_REAL,
    VK_PAT, VK_TABLE, VK_ARRAY, VK_UNDEF.
    Definir les kinds de pattern : PK_LIT, PK_ANY, PK_NOTANY, PK_SPAN,
    PK_BREAK, PK_LEN, PK_POS, PK_RPOS, PK_TAB, PK_RTAB, PK_REM,
    PK_ARB, PK_ARBNO, PK_ALT, PK_CONCAT, PK_ASSIGN, PK_IMMED.

  TODO 03 - TABLES : SYMBOLES, LABELS, PATTERNS, FONCTIONS
    SymTable  : nom, kind (SYM_VAR/SYM_CONST/SYM_BUILTIN/SYM_FUNC),
                type runtime, asm_label, init_str, init_num.
    LabelTable: nom Ada -> label ASM (_SB_lbl), present flag.
    PatTable  : id, kind, operande1 (string ou index), operande2,
                pat_left, pat_right (arbre de patterns).
    FuncTable : nom, ndef (nb args), nloc (nb locals), label ASM,
                params[], locals[].

  TODO 04 - DESCRIPTEUR DE CHAINE RUNTIME (STRING DESCRIPTOR)
    Un descripteur est un DWORD en memoire : [ptr:WORD | len:WORD].
    Definir les macros/helpers ASM emis :
      _RT_STR_PTR  : MOV BX, [DI]   ; BX <- pointeur donnees
      _RT_STR_LEN  : MOV CX, [DI+2] ; CX <- longueur
    Definir la zone DATA pour le heap dynamique (_HEAP_BASE, _HEAP_PTR,
    _HEAP_END) et la taille par defaut (8 Ko).

  TODO 05 - LEXEUR : LECTURE SOURCE ET TOKENISATION
    Gerer les lignes SNOBOL (continuite par '+'/'-' en col 1,
    commentaire par '*' en col 1, fin par ligne vide ou "-END-").
    Extraire : label (col 1-7), sujet (tok ident), patron, remplacement,
    goto (:S(...) :F(...) :(...)  :S(lbl)F(lbl)).
    Reconnaitre : litteaux chaine delimitee par apostrophe ou guillemet,
    entiers, reels, identifiants, operateurs de pattern.

  TODO 06 - TABLE DES MOTS-CLES ET IDENTIFICATEURS PREDEFINIS
    Fonctions integrees : SIZE, SUBSTR, DUPL, REPLACE, TRIM, LPAD, RPAD,
    REVERSE, UPPER, LOWER, CONVERT, DATATYPE, IDENT, DIFFER,
    INTEGER (predicat), REAL, NUMERIC, CHAR, ORD, DATE, TIME.
    Predicats de comparaison : LT, LE, GT, GE, EQ, NE.
    Variables systeme : &ALPHABET, &ANCHOR, &DUMP, &FAIL, &FENCE,
    &FNCODE, &FULLSCAN, &INPUT, &OUTPUT, &STCOUNT, &STFAIL,
    &STLIMIT, &SUBJECT, &SUCCESS, &TRIM.
    Registrer tous ces noms dans SymTable au demarrage.

  TODO 07 - GESTION DES ERREURS ET DES AVERTISSEMENTS
    Procedures : Error(msg), Warning(msg), ErrorTok(msg), FatalError(msg).
    Compteurs err_count, warn_count.
    Affichage numero de ligne source, texte fautif.
    Procedure BilanCompilation : resume final.

  TODO 08 - GENERATION D'EN-TETE ASM ET SEGMENT .DATA
    GenHeader   : commentaire, .MODEL SMALL, .STACK 256.
    GenDataSeg  : emettre _HEAP_BASE, _HEAP_PTR, _HEAP_END,
                  _SB_CRLF, _SB_EMPTY (chaine vide), _SB_NEWLINE,
                  toutes les chaines litterales (pool de constantes),
                  tous les descripteurs de variables globales.
    GenPredefinedData : constantes &ALPHABET (256 chars), &SUCCESS="",
                  &FAIL (sentinel speciale), &FNCODE DW 0.

  TODO 09 - GENERATION DU SEGMENT .CODE ET POINT D'ENTREE
    GenCodeHeader : .CODE, etiquette START:, init DS/ES,
                    appel _SB_INIT_HEAP, appel _SB_INIT_IO,
                    JMP vers premiere instruction du programme.
    GenFooter     : etiquette _SB_END_PROG: , INT 21h AH=4Ch,
                    directive END START.
    Gestion du label special "-END-" : branchement vers _SB_END_PROG.

  TODO 10 - RUNTIME : GESTION DE LA MEMOIRE (HEAP)
    Emettre _SB_ALLOC(cx=nb_bytes) -> BX=ptr ou FAIL si OOM.
    Emettre _SB_NEWSTR(cx=len) -> DI=descripteur alloue.
    Emettre _SB_COPYSTR(SI=src_desc, DI=dst_desc).
    Emettre _SB_CONCATSTR(DI=d1, SI=d2) -> DX=nouveau descripteur.
    Note : pas de GC en v1 - heap monotone, OOM = erreur fatale.

  TODO 11 - RUNTIME : OPERATIONS SUR LES CHAINES
    _RT_STRLEN   : longueur d'un descripteur -> CX.
    _RT_STRNCPY  : copier CX caracteres de [SI] vers [DI].
    _RT_STRCMP   : comparer deux descripteurs -> ZF/CF.
    _RT_SUBSTR   : extraire sous-chaine (pos 1-base, longueur).
    _RT_DUPL     : dupliquer une chaine N fois.
    _RT_REPLACE  : remplacer occurrences (table de traduction).
    _RT_TRIM     : supprimer blancs en fin de chaine.
    _RT_LPAD, _RT_RPAD : cadrage avec caractere remplissage.
    _RT_REVERSE  : inverser une chaine.
    _RT_UPPER, _RT_LOWER : conversion casse.

  TODO 12 - RUNTIME : CONVERSIONS ET ARITHMETIQUE
    _RT_STR2INT  : convertir descripteur ASCII -> AX (entier signe).
    _RT_INT2STR  : AX -> nouveau descripteur chaine.
    _RT_STR2REAL : convertir descripteur -> flottant 16.16 (DX:AX).
    _RT_REAL2STR : flottant -> descripteur chaine.
    _RT_IADD, _RT_ISUB, _RT_IMUL, _RT_IDIV : arithmetique entiere.
    _RT_RADD, _RT_RSUB, _RT_RMUL, _RT_RDIV : arithmetique reelle 16.16.
    _RT_ICOMPARE : LT/LE/GT/GE/EQ/NE sur entiers -> CF/ZF.
    _RT_RCOMPARE : idem sur reels.

  TODO 13 - RUNTIME : TABLES (ASSOCIATIVES)
    Representation : vecteur de paires (cle_desc, val_desc) alloue
    sur le heap, avec facteur de chargement et rehashing lineaire.
    _RT_TABLE_NEW(cx=taille_initiale) -> BX=ptr table.
    _RT_TABLE_GET(BX=table, DI=cle_desc) -> DX=val_desc / FAIL.
    _RT_TABLE_SET(BX=table, DI=cle_desc, SI=val_desc).
    _RT_TABLE_DEL(BX=table, DI=cle_desc).

  TODO 14 - RUNTIME : TABLEAUX (ARRAYS)
    Representation : header (dimensions, bornes) + vecteur de descripteurs.
    _RT_ARRAY_NEW(nb_dims, bornes[]) -> BX=ptr array.
    _RT_ARRAY_GET(BX=array, index_list) -> DX=val_desc.
    _RT_ARRAY_SET(BX=array, index_list, DI=val_desc).
    Support tableau 1D uniquement en v1, extension N-D en v2.

  TODO 15 - PARSER : STRUCTURE D'UNE INSTRUCTION SNOBOL
    Lire une ligne source decomposee en :
      ParseLabel    -> enregistre etiquette si presente.
      ParseSubject  -> variable ou acces tableau/table.
      ParsePattern  -> expression de patron (peut etre vide).
      ParseEq       -> si '=' present, ParseReplacement.
      ParseGoto     -> :S(..) :F(..) ou :(..) en fin.
    Structure TInstruction : label, subject, has_pat, pat_idx,
                has_repl, repl_expr, goto_s, goto_f.

  TODO 16 - PARSER ET CODEGEN : AFFECTATION SIMPLE (SANS PATRON)
    Instruction de la forme :  X = expression
    Evaluer l'expression droite (chaine, entier, appel de fonction,
    concatenation par espace).
    Emettre : calcul de la valeur -> descripteur en DI,
              _SB_STORE_VAR(var_asm_label, DI).
    Gerer l'affectation a une variable indexee : X<i> = val.

  TODO 17 - CODEGEN : PATTERN MATCHING DE BASE
    Pour chaque kind de patron :
      PK_LIT    : _RT_MATCH_LIT(sujet, pos, lit_desc) -> S/F + new_pos.
      PK_ANY    : _RT_MATCH_ANY(sujet, pos, set_desc).
      PK_NOTANY : _RT_MATCH_NOTANY(sujet, pos, set_desc).
      PK_SPAN   : _RT_MATCH_SPAN(sujet, pos, set_desc).
      PK_BREAK  : _RT_MATCH_BREAK(sujet, pos, set_desc).
      PK_LEN    : _RT_MATCH_LEN(sujet, pos, n).
      PK_POS    : _RT_MATCH_POS(sujet, pos, n) -> succes si pos=n.
      PK_RPOS   : _RT_MATCH_RPOS(sujet, pos, n).
      PK_TAB    : _RT_MATCH_TAB(sujet, pos, n) -> avancer jusqu'a n.
      PK_RTAB   : _RT_MATCH_RTAB(sujet, pos, n).
      PK_REM    : _RT_MATCH_REM -> toujours succes, consume le reste.
      PK_ARB    : non-deterministe, tentatives successives (backtrack).
      PK_ARBNO  : repetition d'un sous-patron (a planifier).

  TODO 18 - CODEGEN : OPERATEURS DE PATRON (ALT, CONCAT, ASSIGN)
    PK_CONCAT  : evaluer patron gauche, puis droit si succes.
    PK_ALT     : evaluer patron gauche ; si echec, essayer droit.
    PK_ASSIGN  : affecter la sous-chaine matchee a une variable
                 PATRON $ VAR (assign immediate) ou PATRON . VAR
                 (assign apres matching complet).
    PK_IMMED   : assignation immediate via $.
    Gestion du curseur de position (register SI ou variable locale).
    Mode ANCHOR (&ANCHOR = 1) : desactiver le deplacement automatique.

  TODO 19 - CODEGEN : GOTO ET BRANCHEMENTS SUCCES/ECHEC
    Generer les branchements :
      :S(label) -> JMP si matching reussi.
      :F(label) -> JMP si matching echoue.
      :(label)  -> JMP inconditionnel.
      Absence de goto -> instruction suivante.
    Label special RETURN, FRETURN, NRETURN pour les fonctions.
    Label special END -> fin de programme.
    Resolution en deux passes : forward refs collectees, resolues apres.

  TODO 20 - CODEGEN : FONCTIONS PREDEFINIES (APPELS)
    Pour chaque builtin : emettre PUSH args, CALL _RT_xxx, recup resultat.
    SIZE(s)        -> CX = longueur du descripteur s.
    SUBSTR(s,i,n)  -> DI = nouveau descripteur sous-chaine.
    DUPL(s,n)      -> DI = s repete n fois.
    REPLACE(s,t,u) -> DI = s avec remplacement table t par u.
    TRIM(s)        -> DI = s sans blancs finaux.
    CHAR(n)        -> DI = chaine d'un caractere.
    ORD(s)         -> AX = code ASCII premier caractere.
    CONVERT(v,t)   -> DI = valeur convertie en type t.
    DATATYPE(v)    -> DI = nom du type ('STRING', 'INTEGER'...).
    DATE, TIME     -> DI = chaine date/heure (INT 21h AH=2Ah/2Ch).

  TODO 21 - PARSER ET CODEGEN : DEFINITION DE FONCTIONS (DEFINE)
    DEFINE('nom(p1,p2,...)', 'entry_label')
    Enregistrer dans FuncTable : nb params, nb locals, label.
    A l'entree d'une fonction :
      prologue : PUSH BP / MOV BP,SP / alloc locals.
      lier les descripteurs des arguments (BP+offset).
    A la sortie (RETURN / FRETURN / NRETURN) :
      RETURN  -> retourner le descripteur resultat, succes.
      FRETURN -> retourner, signaler echec.
      NRETURN -> retourner NULL (pas de valeur).
    Appel de fonction utilisateur : PUSH args, CALL _SB_FUNC_xxx.

  TODO 22 - CODEGEN : PREDICATS ET OPERATEURS DE COMPARAISON
    LT(x,y) / LE / GT / GE / EQ / NE : comparaison numerique.
    IDENT(x,y) / DIFFER(x,y) : comparaison de chaines.
    INTEGER(x) / REAL(x) / NUMERIC(x) : predicats de type.
    Chaque predicat returnne sa valeur si vrai, FAIL sinon.
    Emettre : CALL _RT_LT / _RT_LE ... suivi de JNZ _$F(gotoF).

  TODO 23 - GESTION DES VARIABLES SYSTEME (&xxx)
    &ANCHOR  DW 0   : mode ancrage (0 = libre, 1 = ancre a pos 0).
    &TRIM    DW 0   : trim auto de l'entree.
    &STLIMIT DW 50000 : limite iterations.
    &STCOUNT DW 0   : compteur iterations (incremente a chaque instr).
    &OUTPUT  : ecriture automatique sur sortie standard si affecte.
    &INPUT   : lecture automatique sur entree standard.
    Emettre en .DATA : _SB_VAR_ANCHOR, _SB_VAR_TRIM, etc.
    Intercepter les affectations a ces variables pour appel runtime.

  TODO 24 - GESTION DE L'ENTREE/SORTIE (INPUT / OUTPUT)
    Lecture : _RT_READLINE -> DI=descripteur chaine ligne lue (INT 21h
              AH=0Ah), echec si EOF.
    Ecriture : _RT_WRITELINE(DI) -> afficher la chaine + CRLF.
    &INPUT  : variable lecture-seule, declenchant _RT_READLINE a chaque
              evaluation.
    &OUTPUT : variable ecriture-seule, declenchant _RT_WRITELINE a chaque
              affectation.
    INPUT   : fichier d'entree (stub : stdin uniquement en v1).
    OUTPUT  : fichier de sortie (stub : stdout uniquement en v1).

  TODO 25 - PROCEDURE COMPILE ET ORCHESTRATION DEUX PASSES
    Passe 1 : lire et parser toutes les instructions, construire
              SymTable / LabelTable / FuncTable, collecter les literals,
              generer le code intermediaire dans un fichier temporaire.
    Passe 2 : GenHeader -> GenDataSeg (tous les descripteurs et
              constantes) -> GenCodeHeader -> copier code temporaire ->
              GenBuiltinRuntime -> GenStringRuntime -> GenHeapRuntime ->
              GenTableRuntime -> GenFooter.
    Resolution des forward refs de labels entre les deux passes.
    Procedure BilanCompilation : afficher stats (symboles, labels,
              patterns, fonctions, erreurs, avertissements).
    Valider ParamStr(1)=source.SBL, deduire nom .ASM de sortie.

  ============================================================================ }

{ ============================================================================
  TODO 01 - EN-TETE, CONSTANTES ET OPTIONS DU COMPILATEUR
  ============================================================================ }

Program SNOBOL86;

{ --------------------------------------------------------------------------
  Directives compilateur
  -------------------------------------------------------------------------- }

{$A-}           { Pas d'alignement memoire }
{$I-}           { Pas de verification I/O inline (on gere manuellement) }
{$B-}           { Evaluation booleenne court-circuit }
{$Q-}           { Pas de verification overflow (acces tableaux explicites) }
{$R-}           { Pas de verification range }

{ Detection Free Pascal pour portabilite }
{$IFDEF FPC}
 {$MODE DELPHI}
 {$CODEPAGE UTF8}
{$ENDIF}

{ --------------------------------------------------------------------------
  Options de compilation (peuvent etre surchargees par $DEFINE)
  -------------------------------------------------------------------------- }

{ $DEFINE SB_LIST    -- Activer listing source annote  }
{ $DEFINE SB_DEBUG   -- Tracage interne du compilateur }
{ $DEFINE SB_STRICT  -- Erreurs fatales bloquantes     }

{ --------------------------------------------------------------------------
  Constantes dimensionnant les tables internes
  -------------------------------------------------------------------------- }

Const

 { --- Limites des tables principales --- }
 MAX_SYM      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};    { Symboles (variables, constantes, builtins)   }
 MAX_LABEL    = {$IFDEF FPC}256{$ELSE}128{$ENDIF};    { Etiquettes SNOBOL et labels ASM              }
 MAX_PAT      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};    { Noeuds d'arbre de patrons                    }
 MAX_STR      = 4096;   { Taille du pool de chaines litterales (bytes) }
 MAX_LIT      = 256;    { Nombre max de litteraux de chaine distincts  }
 MAX_SUB      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { Fonctions utilisateur (DEFINE)               }
 MAX_BUILTIN  = 48;     { Fonctions integrees connues du compilateur   }
 MAX_PARAM    = {$IFDEF FPC}16{$ELSE}8{$ENDIF};     { Parametres max par fonction SNOBOL           }
 MAX_LOCAL    = 16;     { Variables locales max par fonction SNOBOL    }
 MAX_FWDREF   = 256;    { Forward references de labels a resoudre      }

 { --- Limites du lexeur --- }
 MAX_LINE     = 256;    { Longueur max d'une ligne source              }
 MAX_TOKSTR   = 128;    { Longueur max d'un token chaine/ident         }
 MAX_SRCLINES = 65535;  { Lignes source max (compteur 16 bits)         }

 { --- Limites de la zone heap runtime emise en .DATA --- }
 HEAP_DEFAULT = 8192;   { Taille du heap dynamique cible (bytes)       }
 HEAP_MIN     = 2048;   { Taille minimale acceptable                   }
 HEAP_MAX     = 32768;  { Taille maximale en .MODEL SMALL (32 Ko)      }

 { --- Niveaux de debug interne --- }
 DBG_NONE     = 0;      { Pas de trace                                 }
 DBG_ERRORS   = 1;      { Erreurs seulement                            }
 DBG_TOKENS   = 2;      { Trace lexeur                                 }
 DBG_PARSE    = 3;      { Trace parseur                                }
 DBG_CODEGEN  = 4;      { Trace generateur de code                     }
 DBG_ALL      = 5;      { Tout tracer                                  }

 { --- Version du compilateur --- }
 SNOBOL86_VERSION = '1.0';
 SNOBOL86_DATE    = '2026-03-02';

 { --- Chaines speciales du langage SNOBOL 4 --- }
 SB_END_SENTINEL = '-END-';         { Fin de programme source          }
 SB_CONT_PLUS    = '+';             { Continuation ligne suivante      }
 SB_CONT_MINUS   = '-';             { Continuation (variante)          }
 SB_COMMENT_CHAR = '*';             { Ligne de commentaire (col 1)     }

 { --- Labels ASM emis pour le runtime --- }
 RT_PREFIX    = '_RT_';             { Prefixe routines runtime         }
 SB_PREFIX    = '_SB_';             { Prefixe routines SNOBOL system   }
 SB_VAR_PFX   = '_SBV_';           { Prefixe variables SNOBOL         }
 SB_LBL_PFX  = '_SBL_';            { Prefixe etiquettes SNOBOL        }
 SB_FUN_PFX  = '_SBF_';            { Prefixe fonctions SNOBOL         }
 SB_LIT_PFX  = '_SBS_';            { Prefixe chaines litterales       }

 { --- Codes de retour de matching (stockes dans registre BX) --- }
 MATCH_FAIL    = 0;     { 0 = echec du patron                          }
 MATCH_SUCCESS = 1;     { 1 = succes du patron                         }

 { --- Taille d'un descripteur de chaine en memoire cible (bytes) --- }
 DESC_SIZE    = 4;      { WORD ptr + WORD len                          }

 { --- Codes d'erreur compilateur --- }
 ERR_NONE     = 0;
 ERR_SYNTAX   = 1;
 ERR_SYMTAB   = 2;
 ERR_PATTAB   = 3;
 ERR_STRPOOL  = 4;
 ERR_LABFWD   = 5;
 ERR_FUNCDEF  = 6;
 ERR_INTERNAL = 99;

{ --------------------------------------------------------------------------
  Type de base partage par tous les modules (utilise des TODO 02 a 25)
  -------------------------------------------------------------------------- }

Type
 TString = String[MAX_TOKSTR];   { Chaine Pascal courte portable      }

{ ============================================================================
  TODO 02 - TYPES FONDAMENTAUX ET STRUCTURES DE DONNEES
  ============================================================================ }

 { --------------------------------------------------------------------------
   Tokens du lexeur SNOBOL 4
   -------------------------------------------------------------------------- }

 TTokType = (
  { --- Fin de flux / erreur --- }
  TOK_EOF,          { fin de fichier source                             }
  TOK_EOL,          { fin de ligne (instruction terminee)               }
  TOK_UNKNOWN,      { caractere non reconnu                             }

  { --- Litteraux --- }
  TOK_INTEGER,      { constante entiere  ex: 42                         }
  TOK_REAL,         { constante reelle   ex: 3.14                       }
  TOK_STRING,       { chaine delimitee   ex: 'hello' ou "hello"         }

  { --- Identificateur / mot-cle --- }
  TOK_IDENT,        { identificateur SNOBOL (var, label, fonction)      }

  { --- Ponctuation et operateurs --- }
  TOK_LPAREN,       { (                                                 }
  TOK_RPAREN,       { )                                                 }
  TOK_LANGLE,       { <   (acces indirect / tableau)                    }
  TOK_RANGLE,       { >                                                 }
  TOK_COMMA,        { ,   (separateur arguments)                        }
  TOK_EQ,           { =   (affectation / remplacement patron)           }
  TOK_DOT,          { .   (assignation conditionnelle en patron)        }
  TOK_DOLLAR,       { $   (assignation immediate en patron / indir.)    }
  TOK_AT,           { @   (curseur de position)                         }
  TOK_BANG,         { !   (appel indirect de fonction)                  }
  TOK_AMP,          { &   (prefixe variables systeme : &ANCHOR...)      }
  TOK_PIPE,         { |   (alternative de patron)                       }
  TOK_STAR,         { *   (operateur ARB ou multiplication)             }
  TOK_HASH,         { #   (operateur ARBNO / repetition)                }
  TOK_SLASH,        { /   (division)                                    }
  TOK_PLUS,         { +   (addition / continuation ligne)               }
  TOK_MINUS,        { -   (soustraction)                                }
  TOK_TILDE,        { ~   (negation de pattern : NOT)                   }
  TOK_CARET,        { ^   (debut de chaine en patron)                   }

  { --- Goto --- }
  TOK_COLON,        { :   (debut section goto)                          }
  TOK_GOTO_S,       { :S( succes conditionnel                           }
  TOK_GOTO_F,       { :F( echec  conditionnel                           }
  TOK_GOTO_UNC      { :(  inconditionnel                                }
 );

 { --------------------------------------------------------------------------
   Kinds de valeur runtime (type dynamique d'une variable SNOBOL)
   -------------------------------------------------------------------------- }

 TValueKind = (
  VK_UNDEF,    { variable non initialisee (valeur = chaine vide "")    }
  VK_STR,      { chaine de caracteres (STRING)                         }
  VK_INT,      { entier signe 16 bits (INTEGER)                        }
  VK_REAL,     { reel point fixe 16.16 (REAL)                          }
  VK_PAT,      { patron compile (PATTERN)                              }
  VK_TABLE,    { table associative (TABLE)                             }
  VK_ARRAY,    { tableau indexe (ARRAY)                                }
  VK_CODE,     { bloc de code (CODE) - non implem. en v1               }
  VK_EXPR      { expression non evaluee (EXPRESSION) - non impl. v1    }
 );

 { --------------------------------------------------------------------------
   Kinds de noeud dans l'arbre de patron (pattern tree node kind)
   Chaque valeur correspond a une routine _RT_MATCH_xxx emise en ASM.
   -------------------------------------------------------------------------- }

 TPatKind = (
  { --- Patrons terminaux --- }
  PK_FAIL,     { FAIL      : echoue toujours (predicat d'echec)        }
  PK_FENCE,    { FENCE     : succes mais bloque le backtrack            }
  PK_ABORT,    { ABORT     : abandonne toute tentative de matching      }
  PK_SUCCEED,  { SUCCEED   : reussit toujours                           }
  PK_REM,      { REM       : consomme le reste du sujet                 }
  PK_ARB,      { ARB       : consomme 0..n caracteres (non-det.)        }

  { --- Patrons bases sur un ensemble de caracteres --- }
  PK_ANY,      { ANY(s)    : un caractere appartenant a s               }
  PK_NOTANY,   { NOTANY(s) : un caractere n'appartenant pas a s         }
  PK_SPAN,     { SPAN(s)   : une ou plusieurs chars de s (greedy)       }
  PK_BREAK,    { BREAK(s)  : chars jusqu'a (non inclu) un char de s     }
  PK_BREAKX,   { BREAKX(s) : variante BREAK avec retry apres match      }

  { --- Patrons bases sur une position --- }
  PK_POS,      { POS(n)    : succes si curseur = n (0-base)             }
  PK_RPOS,     { RPOS(n)   : succes si curseur = len-n                  }
  PK_TAB,      { TAB(n)    : avancer jusqu'a position n                 }
  PK_RTAB,     { RTAB(n)   : avancer jusqu'a len-n                      }

  { --- Patrons bases sur une longueur --- }
  PK_LEN,      { LEN(n)    : consommer exactement n caracteres          }

  { --- Litteral --- }
  PK_LIT,      { chaine litterale a matcher exactement                  }

  { --- Patrons composites (noeuds internes de l'arbre) --- }
  PK_CONCAT,   { p1 p2     : concatenation (p1 puis p2)                 }
  PK_ALT,      { p1 | p2   : alternative   (p1 ou p2)                  }
  PK_ARBNO,    { ARBNO(p)  : repetition 0..n fois du patron p           }

  { --- Assignation en cours de matching --- }
  PK_ASSIGN,   { p . var   : copier sous-chaine dans var apres matching }
  PK_IMMED,    { p $ var   : copier sous-chaine dans var immediatement  }

  { --- Patron indirect --- }
  PK_INDIRECT  { *var / !var : evaluer var comme patron a l'execution   }
 );

 { --------------------------------------------------------------------------
   Noeud d'arbre de patron (stocke dans pat_table)
   -------------------------------------------------------------------------- }

 TPatNode = Record
  kind      : TPatKind;        { type du noeud                         }
  { Operandes selon le kind }
  lit_idx   : Integer;         { PK_LIT : index dans str_pool          }
  lit_len   : Integer;         { PK_LIT : longueur du litteral         }
  int_val   : Integer;         { PK_LEN/POS/RPOS/TAB/RTAB : valeur n  }
  set_idx   : Integer;         { PK_ANY/NOTANY/SPAN/BREAK : index pool }
  left      : Integer;         { PK_CONCAT/ALT/ASSIGN/IMMED : fils g.  }
  right     : Integer;         { PK_CONCAT/ALT : fils droit            }
  var_nm    : TString;         { PK_ASSIGN/IMMED/INDIRECT : nom var    }
  asm_label : TString;         { label ASM genere pour ce noeud        }
 End;

 { --------------------------------------------------------------------------
   Kinds de symbole dans la table des symboles
   -------------------------------------------------------------------------- }

 TSymKind = (
  SK_UNDEF,      { non encore defini                                    }
  SK_VAR,        { variable SNOBOL (descripteur en .DATA ou BP)         }
  SK_CONST_STR,  { constante chaine (pool litteraux)                    }
  SK_CONST_INT,  { constante entiere                                    }
  SK_CONST_REAL, { constante reelle                                     }
  SK_BUILTIN,    { fonction integree du langage                         }
  SK_FUNC,       { fonction utilisateur (DEFINE)                        }
  SK_SYSVAR      { variable systeme (&ANCHOR, &OUTPUT, etc.)            }
 );

 { --------------------------------------------------------------------------
   Kinds de sous-programme (fonctions/procedures utilisateur)
   -------------------------------------------------------------------------- }

 TSubKind = (
  SUB_FUNC,      { fonction definie par DEFINE (retourne une valeur)    }
  SUB_BUILTIN    { fonction integree (emise comme stub ASM)             }
 );

 { --------------------------------------------------------------------------
   Noeud de goto (branchement conditionnel d'une instruction SNOBOL)
   -------------------------------------------------------------------------- }

 TGotoKind = (
  GT_NONE,       { pas de goto                                          }
  GT_SUCCESS,    { :S(label)  - branchement si matching reussi          }
  GT_FAIL,       { :F(label)  - branchement si matching echoue          }
  GT_UNCOND,     { :(label)   - branchement inconditionnel              }
  GT_END,        { END        - fin de programme                        }
  GT_RETURN,     { RETURN     - retour de fonction (succes)             }
  GT_FRETURN,    { FRETURN    - retour de fonction (echec)              }
  GT_NRETURN     { NRETURN    - retour de fonction (pas de valeur)      }
 );

 { --------------------------------------------------------------------------
   Forward declarations des procedures principales (remplies TODO 03+)
   -------------------------------------------------------------------------- }

 { Pointeurs de tableaux dynamiques (alloues en TODO 03) }
 PPatNode = ^TPatNode;

{ ============================================================================
  TODO 03 - TABLES : SYMBOLES, LABELS, PATTERNS, FONCTIONS
  ============================================================================ }

 { --------------------------------------------------------------------------
   Table des symboles (variables, constantes, builtins, fonctions user)
   -------------------------------------------------------------------------- }

 TSymEntry = Record
  name      : TString;      { nom SNOBOL en majuscules                  }
  kind      : TSymKind;     { SK_VAR / SK_CONST_STR / SK_BUILTIN ...     }
  val_kind  : TValueKind;   { type runtime courant de la variable        }
  asm_label : TString;      { label ASM pour le descripteur en .DATA     }
  init_str  : TString;      { valeur initiale (chaine)                   }
  init_num  : LongInt;      { valeur initiale (entier ou reel 16.16)     }
  str_idx   : Integer;      { index dans str_pool si SK_CONST_STR        }
  str_len   : Integer;      { longueur dans str_pool                     }
  is_local  : Boolean;      { variable locale d'une fonction (sur BP)    }
  bp_offset : Integer;      { offset BP si variable locale               }
  param_idx : Integer;      { rang dans la liste des params (0 = non)    }
 End;

 PSymTable = ^TSymTableArr;
 TSymTableArr = Array[1..MAX_SYM] of TSymEntry;

 { --------------------------------------------------------------------------
   Table des labels SNOBOL (etiquettes source et forward references)
   -------------------------------------------------------------------------- }

 TLabelEntry = Record
  name      : TString;      { etiquette SNOBOL en majuscules             }
  asm_label : TString;      { label ASM genere (_SBL_xxx)                }
  defined   : Boolean;      { True si label rencontre dans le source     }
  line_def  : Integer;      { ligne source ou le label est defini        }
 End;

 PLabelTable = ^TLabelTableArr;
 TLabelTableArr = Array[1..MAX_LABEL] of TLabelEntry;

 { --------------------------------------------------------------------------
   Table des patrons (noeuds d'arbre de matching)
   Deja declare : TPatNode / PPatNode -> tableau dynamique pat_table
   -------------------------------------------------------------------------- }

 PPatTable = ^TPatTableArr;
 TPatTableArr = Array[1..MAX_PAT] of TPatNode;

 { --------------------------------------------------------------------------
   Table des fonctions utilisateur (definies par DEFINE)
   -------------------------------------------------------------------------- }

 TParamEntry = Record
  name      : TString;      { nom du parametre                          }
  bp_offset : Integer;      { offset BP positif (arg passe par pile)    }
 End;

 TLocalEntry = Record
  name      : TString;      { nom de la variable locale                 }
  bp_offset : Integer;      { offset BP negatif                         }
 End;

 TFuncEntry = Record
  name        : TString;        { nom de la fonction en majuscules       }
  kind        : TSubKind;       { SUB_FUNC ou SUB_BUILTIN                }
  asm_label   : TString;        { label ASM du point d'entree            }
  entry_label : TString;        { etiquette SNOBOL du point d'entree     }
  param_count : Integer;        { nombre de parametres                   }
  local_count : Integer;        { nombre de variables locales            }
  params      : Array[1..MAX_PARAM] of TParamEntry;
  locals      : Array[1..MAX_LOCAL]  of TLocalEntry;
  frame_size  : Integer;        { total octets de frame locale           }
  param_bytes : Integer;        { octets a depiler (RET n)               }
 End;

 PFuncTable = ^TFuncTableArr;
 TFuncTableArr = Array[1..MAX_SUB] of TFuncEntry;

 { --------------------------------------------------------------------------
   Forward references de labels (resolution passe 2)
   -------------------------------------------------------------------------- }

 TFwdRef = Record
  asm_label : TString;      { label ASM reference mais pas encore defini }
  src_line  : Integer;      { ligne source pour le message d'erreur      }
 End;

 PFwdRefTable = ^TFwdRefArr;
 TFwdRefArr = Array[1..MAX_FWDREF] of TFwdRef;

{ --------------------------------------------------------------------------
  Variables globales de configuration (positionnees en debut de Compile)
  -------------------------------------------------------------------------- }

Var
  { Options runtime du compilateur }
  opt_list      : Boolean;   { Generer un listing annote (.LST)         }
  opt_debug     : Integer;   { Niveau de debug (DBG_xxx)                }
  opt_strict    : Boolean;   { Arret sur premiere erreur                }
  opt_heap_size : Integer;   { Taille du heap cible (defaut HEAP_DEFAULT)}

  { Compteurs globaux }
  err_count     : Integer;   { Nombre d'erreurs detectees               }
  warn_count    : Integer;   { Nombre d'avertissements emis             }
  src_line_num  : Integer;   { Numero de la ligne source courante        }
  instr_count   : Integer;   { Instructions SNOBOL compilees            }

  { Noms de fichiers }
  src_fname     : String;    { Fichier source (.SBL)                    }
  out_fname     : String;    { Fichier sortie (.ASM)                    }
  lst_fname     : String;    { Fichier listing (.LST)                   }
  tmp_fname     : String;    { Fichier temporaire passe 1               }

  { Fichiers }
  src_file      : Text;      { Lecture source SNOBOL                    }
  out_file      : Text;      { Ecriture ASM final                       }
  lst_file      : Text;      { Ecriture listing optionnel               }
  tmp_file      : Text;      { Code intermediaire passe 1               }
  lst_open      : Boolean;   { lst_file est-il ouvert ?                 }
  tmp_open      : Boolean;   { tmp_file est-il ouvert ?                 }

  { --- Tables principales (allouees par InitXxxTable) --- }
  sym_table     : PSymTable;   { table des symboles                      }
  sym_count     : Integer;     { nb entrees utilisees                    }

  label_table   : PLabelTable; { table des labels SNOBOL                 }
  label_count   : Integer;

  pat_table     : PPatTable;   { table des noeuds de patrons             }
  pat_count     : Integer;

  func_table    : PFuncTable;  { table des fonctions utilisateur         }
  func_count    : Integer;

  fwd_table     : PFwdRefTable;{ forward references de labels            }
  fwd_count     : Integer;

  { --- Pool de chaines litterales (bytes bruts concatenes) --- }
  str_pool      : Array[0..MAX_STR-1] of Char;
  str_top       : Integer;     { prochain octet libre dans str_pool      }

  { --- Compteur de labels ASM generes (unique par compilation) --- }
  lbl_seq       : Integer;     { sequence pour NewLabel -> @@Lxxxx       }

{ ============================================================================
  TODO 03 (suite) - PROCEDURES D'INITIALISATION ET D'ACCES AUX TABLES
  ============================================================================ }

{ --- Helpers generaux --- }

Function StringOfChar(c: Char; n: Integer): String;
Var s : String;
    i : Integer;
Begin
 s := '';
 For i := 1 To n Do
  s := s + c;
 StringOfChar := s;
End;

Function UpCaseStr(Const s: String): String;
Var i : Integer;
    r : String;
Begin
 r := s;
 For i := 1 To Length(r) Do
  r[i] := UpCase(r[i]);
 UpCaseStr := r;
End;

Function IntToStr(n: LongInt): String;
Var s : String;
Begin
 Str(n, s);
 IntToStr := s;
End;

Function NewLabel: String;
Begin
 Inc(lbl_seq);
 NewLabel := '@@L' + IntToStr(lbl_seq);
End;

Function AsmSafeIdent(Const s: TString): TString;
{ Remplace les caracteres non alphanumeriques par '_' pour les labels ASM }
Var i   : Integer;
    res : TString;
Begin
 res := s;
 For i := 1 To Length(res) Do
  If Not (res[i] In ['A'..'Z','a'..'z','0'..'9','_']) Then
   res[i] := '_';
 AsmSafeIdent := res;
End;

{ --------------------------------------------------------------------------
  InitSymTable / FindSym / AddSym
  -------------------------------------------------------------------------- }

Procedure InitSymTable;
Begin
 New(sym_table);
 sym_count := 0;
End;

Function FindSym(Const nm: TString): Integer;
Var i   : Integer;
    u   : TString;
Begin
 u := UpCaseStr(nm);
 For i := 1 To sym_count Do
  If sym_table^[i].name = u Then Begin FindSym := i; Exit; End;
 FindSym := 0;
End;

Function AddSym(Const nm: TString; k: TSymKind; vk: TValueKind): Integer;
Var u : TString;
Begin
 If sym_count >= MAX_SYM Then Begin AddSym := 0; Exit; End;
 u := UpCaseStr(nm);
 Inc(sym_count);
 FillChar(sym_table^[sym_count], SizeOf(TSymEntry), 0);
 sym_table^[sym_count].name      := u;
 sym_table^[sym_count].kind      := k;
 sym_table^[sym_count].val_kind  := vk;
 sym_table^[sym_count].asm_label := SB_VAR_PFX + AsmSafeIdent(u);
 sym_table^[sym_count].init_num  := 0;
 sym_table^[sym_count].is_local  := False;
 sym_table^[sym_count].bp_offset := 0;
 sym_table^[sym_count].param_idx := 0;
 AddSym := sym_count;
End;

{ --------------------------------------------------------------------------
  InitLabelTable / FindLabel / AddLabel
  -------------------------------------------------------------------------- }

Procedure InitLabelTable;
Begin
 New(label_table);
 label_count := 0;
End;

Function FindLabel(Const nm: TString): Integer;
Var i : Integer;
    u : TString;
Begin
 u := UpCaseStr(nm);
 For i := 1 To label_count Do
  If label_table^[i].name = u Then Begin FindLabel := i; Exit; End;
 FindLabel := 0;
End;

Function AddLabel(Const nm: TString): Integer;
Var u : TString;
Begin
 If label_count >= MAX_LABEL Then Begin AddLabel := 0; Exit; End;
 u := UpCaseStr(nm);
 Inc(label_count);
 FillChar(label_table^[label_count], SizeOf(TLabelEntry), 0);
 label_table^[label_count].name      := u;
 label_table^[label_count].asm_label := SB_LBL_PFX + AsmSafeIdent(u);
 label_table^[label_count].defined   := False;
 label_table^[label_count].line_def  := 0;
 AddLabel := label_count;
End;

Procedure DefineLabel(idx: Integer; line_num: Integer);
Begin
 label_table^[idx].defined  := True;
 label_table^[idx].line_def := line_num;
End;

{ --------------------------------------------------------------------------
  InitPatTable / AddPat
  -------------------------------------------------------------------------- }

Procedure InitPatTable;
Begin
 New(pat_table);
 pat_count := 0;
End;

Function AddPat(k: TPatKind): Integer;
Begin
 If pat_count >= MAX_PAT Then Begin AddPat := 0; Exit; End;
 Inc(pat_count);
 FillChar(pat_table^[pat_count], SizeOf(TPatNode), 0);
 pat_table^[pat_count].kind      := k;
 pat_table^[pat_count].lit_idx   := 0;
 pat_table^[pat_count].lit_len   := 0;
 pat_table^[pat_count].int_val   := 0;
 pat_table^[pat_count].set_idx   := 0;
 pat_table^[pat_count].left      := 0;
 pat_table^[pat_count].right     := 0;
 pat_table^[pat_count].var_nm    := '';
 pat_table^[pat_count].asm_label := NewLabel;
 AddPat := pat_count;
End;

{ --------------------------------------------------------------------------
  InitFuncTable / FindFunc / AddFunc
  -------------------------------------------------------------------------- }

Procedure InitFuncTable;
Begin
 New(func_table);
 func_count := 0;
End;

Function FindFunc(Const nm: TString): Integer;
Var i : Integer;
    u : TString;
Begin
 u := UpCaseStr(nm);
 For i := 1 To func_count Do
  If func_table^[i].name = u Then Begin FindFunc := i; Exit; End;
 FindFunc := 0;
End;

Function AddFunc(Const nm: TString; k: TSubKind): Integer;
Var u : TString;
Begin
 If func_count >= MAX_SUB Then Begin AddFunc := 0; Exit; End;
 u := UpCaseStr(nm);
 Inc(func_count);
 FillChar(func_table^[func_count], SizeOf(TFuncEntry), 0);
 func_table^[func_count].name        := u;
 func_table^[func_count].kind        := k;
 func_table^[func_count].asm_label   := SB_FUN_PFX + AsmSafeIdent(u);
 func_table^[func_count].entry_label := '';
 func_table^[func_count].param_count := 0;
 func_table^[func_count].local_count := 0;
 func_table^[func_count].frame_size  := 0;
 func_table^[func_count].param_bytes := 0;
 AddFunc := func_count;
End;

{ --------------------------------------------------------------------------
  InitFwdTable / AddFwdRef
  -------------------------------------------------------------------------- }

Procedure InitFwdTable;
Begin
 New(fwd_table);
 fwd_count := 0;
End;

Procedure AddFwdRef(Const lbl: TString; line_num: Integer);
Begin
 If fwd_count >= MAX_FWDREF Then Exit;
 Inc(fwd_count);
 fwd_table^[fwd_count].asm_label := lbl;
 fwd_table^[fwd_count].src_line  := line_num;
End;

{ --------------------------------------------------------------------------
  Pool de chaines litterales (str_pool) : StrPoolAdd / StrPoolGet
  -------------------------------------------------------------------------- }

Procedure InitStrPool;
Begin
 str_top := 0;
 FillChar(str_pool, SizeOf(str_pool), 0);
End;

Function StrPoolAdd(Const s: TString): Integer;
{ Ajoute s dans str_pool, retourne l'index de debut (0-base). }
Var i   : Integer;
    idx : Integer;
Begin
 idx := str_top;
 For i := 1 To Length(s) Do
 Begin
  If str_top >= MAX_STR Then Begin StrPoolAdd := -1; Exit; End;
  str_pool[str_top] := s[i];
  Inc(str_top);
 End;
 If str_top < MAX_STR Then Begin str_pool[str_top] := #0; Inc(str_top); End;
 StrPoolAdd := idx;
End;

Function StrPoolGet(idx, len: Integer): TString;
{ Relit une chaine depuis str_pool a partir de l'index idx sur len chars. }
Var i   : Integer;
    res : TString;
Begin
 res := '';
 For i := 0 To len - 1 Do
  If (idx + i < MAX_STR) And (str_pool[idx+i] <> #0) Then
   res := res + str_pool[idx+i];
 StrPoolGet := res;
End;

{ --------------------------------------------------------------------------
  DisposeAllTables : liberer la memoire des tables en fin de compilation
  -------------------------------------------------------------------------- }

Procedure DisposeAllTables;
Begin
 If sym_table   <> Nil Then Begin Dispose(sym_table);   sym_table   := Nil; End;
 If label_table <> Nil Then Begin Dispose(label_table); label_table := Nil; End;
 If pat_table   <> Nil Then Begin Dispose(pat_table);   pat_table   := Nil; End;
 If func_table  <> Nil Then Begin Dispose(func_table);  func_table  := Nil; End;
 If fwd_table   <> Nil Then Begin Dispose(fwd_table);   fwd_table   := Nil; End;
End;

{ ============================================================================
  TODO 04 - DESCRIPTEUR DE CHAINE RUNTIME (STRING DESCRIPTOR)
  ============================================================================

  En memoire cible (8086), chaque valeur SNOBOL est representee par un
  "descripteur" de 4 octets (DWORD) :

      Offset 0 : WORD  ptr  ->  adresse des octets de donnees dans le heap
      Offset 2 : WORD  len  ->  longueur courante de la chaine (0..65535)

  Un descripteur vide (chaine "") a ptr=OFFSET _SB_EMPTY_BUF, len=0.
  Les registres utilises par convention :
      DI = adresse du descripteur a lire/ecrire
      BX = ptr (apres _RT_STR_PTR)
      CX = len (apres _RT_STR_LEN)

  Heap dynamique : zone lineaire en .DATA, croissant vers le haut.
    _HEAP_BASE DD ?   <- premier octet du heap (base fixe)
    _HEAP_PTR  DD ?   <- prochain octet libre (avance a chaque alloc)
    _HEAP_END  DD ?   <- premiere adresse invalide (base + taille)
  ============================================================================ }

{ --------------------------------------------------------------------------
  Infrastructure d'emission ASM (Emit / EmitI / EmitLabel / EmitComment)
  Toutes les routines de generation de code passent par ces helpers.
  La variable cur_out pointe sur out_file ou tmp_file selon la passe.
  -------------------------------------------------------------------------- }

Var
  cur_out : ^Text;    { pointeur sur le fichier de sortie courant        }

{$IFDEF FPC}
 {$WARN 5036 OFF} { cur_out : pointeur global initialise dans Begin }
{$ENDIF}
Procedure Emit(Const s: String);
Begin
  WriteLn(cur_out^, s);
End;

Procedure EmitI(Const s: String);
{ Emettre une instruction avec TAB de mise en forme }
Begin
  WriteLn(cur_out^, #9, s);
End;

Procedure EmitLabel(Const lbl: String);
Begin
  WriteLn(cur_out^, lbl, ':');
End;

Procedure EmitBlank;
Begin
  WriteLn(cur_out^, '');
End;

Procedure EmitComment(Const s: String);
Begin
  WriteLn(cur_out^, '; ', s);
End;

Procedure EmitSep;
{ Ligne separatrice de section }
Begin
  WriteLn(cur_out^, '; ', StringOfChar('-', 72));
End;

{ --------------------------------------------------------------------------
  Helpers : noms de labels predefined pour les descripteurs et le heap
  -------------------------------------------------------------------------- }

Function DescLabel(Const var_name: TString): TString;
{ Label ASM du descripteur d'une variable SNOBOL : _SBV_xxx_DESC }
Begin
  DescLabel := SB_VAR_PFX + AsmSafeIdent(UpCaseStr(var_name)) + '_D';
End;

Function DataLabel(Const var_name: TString): TString;
{ Label ASM du buffer de donnees d'une variable SNOBOL : _SBV_xxx_BUF }
Begin
  DataLabel := SB_VAR_PFX + AsmSafeIdent(UpCaseStr(var_name)) + '_B';
End;

Function LitDescLabel(idx: Integer): TString;
{ Label ASM du descripteur d'un litteral : _SBS_nnn_D }
Begin
  LitDescLabel := SB_LIT_PFX + IntToStr(idx) + '_D';
End;

Function LitDataLabel(idx: Integer): TString;
{ Label ASM du buffer de donnees d'un litteral : _SBS_nnn_B }
Begin
  LitDataLabel := SB_LIT_PFX + IntToStr(idx) + '_B';
End;

{ --------------------------------------------------------------------------
  GenDescriptor : emettre un descripteur + son buffer dans le segment .DATA
  --------------------------------------------------------------------------
  Forme emise :
      <desc_lbl>:   DW  OFFSET <data_lbl>   ; ptr
                    DW  <initial_len>        ; len
      <data_lbl>:   DB  <initial_len> DUP(0); buffer (init a vide)
                    DB  0                    ; garde-fou null
  -------------------------------------------------------------------------- }

Procedure GenDescriptor(Const desc_lbl, data_lbl: TString;
                        init_len: Integer);
Begin
  EmitComment('Descripteur : ' + desc_lbl);
  EmitI(desc_lbl + ':');
  EmitI('DW  OFFSET ' + data_lbl + '  ; ptr');
  EmitI('DW  0                       ; len courante (init = 0)');
  EmitI(data_lbl + ':');
  If init_len > 0 Then
    EmitI('DB  ' + IntToStr(init_len) + ' DUP(0) ; buffer')
  Else
    EmitI('DB  0                    ; buffer vide (chaine "")');
  EmitI('DB  0                    ; garde-fou null');
End;

{ --------------------------------------------------------------------------
  GenDescriptorFromLit : emettre un descripteur pour un litteral SNOBOL
  Le buffer contient les octets de la chaine (longueur connue).
  -------------------------------------------------------------------------- }

Procedure GenDescriptorFromLit(Const desc_lbl, data_lbl, s: TString);
Var i   : Integer;
    hex : String;
    b   : Byte;
Begin
  EmitComment('Litteral : ''' + s + '''');
  EmitI(desc_lbl + ':');
  EmitI('DW  OFFSET ' + data_lbl + '  ; ptr');
  EmitI('DW  ' + IntToStr(Length(s)) + '           ; len');
  EmitI(data_lbl + ':');
  If Length(s) = 0 Then
  Begin
    EmitI('DB  0  ; buffer vide');
  End
  Else
  Begin
    { Emettre les octets en une ligne DB }
    hex := 'DB  ';
    For i := 1 To Length(s) Do
    Begin
      b := Ord(s[i]);
      If i > 1 Then hex := hex + ', ';
      hex := hex + IntToStr(b);
    End;
    EmitI(hex);
    EmitI('DB  0  ; garde-fou null');
  End;
End;

{ --------------------------------------------------------------------------
  GenHeapData : emettre les variables du heap dynamique dans le .DATA
  Emis une seule fois par GenDataSeg (TODO 08).
  --------------------------------------------------------------------------

  Structure emise :

      ; --- Heap dynamique SNOBOL runtime ---
      _HEAP_BASE  DW  0              ; offset base (rempli par _SB_INIT_HEAP)
      _HEAP_PTR   DW  0              ; offset prochain octet libre
      _HEAP_END   DW  0              ; offset premiere adresse invalide
      _HEAP_BUF   DB  8192 DUP(0)   ; zone de donnees brute

  Note : on utilise des WORDs pour rester dans l'espace adressable 16 bits
  du segment DS en .MODEL SMALL.
  -------------------------------------------------------------------------- }

Procedure GenHeapData(heap_size: Integer);
Begin
  EmitSep;
  EmitComment('Heap dynamique SNOBOL runtime (' + IntToStr(heap_size) + ' octets)');
  EmitSep;
  EmitI('_HEAP_BASE  DW  0            ; offset base dans DS');
  EmitI('_HEAP_PTR   DW  0            ; offset prochain octet libre');
  EmitI('_HEAP_END   DW  0            ; offset premiere adresse invalide');
  EmitI('_HEAP_BUF   DB  ' + IntToStr(heap_size) + ' DUP(0)  ; zone de donnees');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenInitHeap : emettre la routine _SB_INIT_HEAP dans le segment .CODE
  Appele depuis GenCodeHeader (TODO 09).

  Logique :
      MOV AX, OFFSET _HEAP_BUF
      MOV [_HEAP_BASE], AX
      MOV [_HEAP_PTR],  AX
      ADD AX, <heap_size>
      MOV [_HEAP_END],  AX
      RET
  -------------------------------------------------------------------------- }

Procedure GenInitHeap(heap_size: Integer);
Begin
  EmitSep;
  EmitComment('_SB_INIT_HEAP : initialiser le heap dynamique');
  EmitSep;
  EmitLabel('_SB_INIT_HEAP');
  EmitI('MOV  AX, OFFSET _HEAP_BUF');
  EmitI('MOV  [_HEAP_BASE], AX');
  EmitI('MOV  [_HEAP_PTR],  AX');
  EmitI('ADD  AX, ' + IntToStr(heap_size));
  EmitI('MOV  [_HEAP_END],  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStrPtrMacro / GenStrLenMacro : sequences inline pour acceder a un
  descripteur pointe par DI.

  Equivalent ASM des "macros" :
      _RT_STR_PTR : MOV BX, [DI]      ; BX <- ptr donnees
      _RT_STR_LEN : MOV CX, [DI+2]    ; CX <- longueur
  Ces sequences sont emises inline plutot que comme CALL pour minimiser
  le surco?t sur 8086 (pas de MACRO MASM en ciblant TASM minimal).
  -------------------------------------------------------------------------- }

Procedure GenLoadStrPtr;
{ Emettre : MOV BX, [DI] -- BX <- ptr donnees du descripteur en DI }
Begin
  EmitI('MOV  BX, [DI]    ; ptr <- descripteur[DI].ptr');
End;

Procedure GenLoadStrLen;
{ Emettre : MOV CX, [DI+2] -- CX <- longueur du descripteur en DI }
Begin
  EmitI('MOV  CX, [DI+2]  ; len <- descripteur[DI].len');
End;

Procedure GenStoreStrPtr;
{ Emettre : MOV [DI], BX -- descripteur[DI].ptr <- BX }
Begin
  EmitI('MOV  [DI], BX    ; descripteur[DI].ptr <- BX');
End;

Procedure GenStoreStrLen;
{ Emettre : MOV [DI+2], CX -- descripteur[DI].len <- CX }
Begin
  EmitI('MOV  [DI+2], CX  ; descripteur[DI].len <- CX');
End;

Procedure GenLoadDesc(Const desc_label: TString);
{ Emettre : MOV DI, OFFSET <label> -- DI pointe sur le descripteur }
Begin
  EmitI('MOV  DI, OFFSET ' + desc_label);
End;

{ --------------------------------------------------------------------------
  GenEmptyStrData : emettre la constante chaine vide (_SB_EMPTY_BUF)
  et son descripteur (_SB_EMPTY_DESC) dans le .DATA.
  Utilise comme valeur initiale de toute variable non initialisee.
  -------------------------------------------------------------------------- }

Procedure GenEmptyStrData;
Begin
  EmitComment('"" - chaine vide (descripteur initial de toute variable)');
  EmitI('_SB_EMPTY_DESC:');
  EmitI('  DW  OFFSET _SB_EMPTY_BUF  ; ptr');
  EmitI('  DW  0                      ; len = 0');
  EmitI('_SB_EMPTY_BUF:');
  EmitI('  DB  0                      ; buffer null');
  EmitBlank;
End;
{$IFDEF FPC}
 {$WARN 5036 ON}
{$ENDIF}

{ --------------------------------------------------------------------------
  GenCrlfData : emettre le descripteur CRLF (_SB_CRLF_DESC) dans .DATA.
  Utilise par _RT_WRITELINE / New_Line.
  -------------------------------------------------------------------------- }

Procedure GenCrlfData;
Begin
  EmitComment('CRLF - fin de ligne');
  EmitI('_SB_CRLF_DESC:');
  EmitI('  DW  OFFSET _SB_CRLF_BUF  ; ptr');
  EmitI('  DW  2                     ; len = 2');
  EmitI('_SB_CRLF_BUF:');
  EmitI('  DB  0Dh, 0Ah, 0          ; CR LF null');
  EmitBlank;
End;
{$IFDEF FPC}
{$WARN 5036 ON}
{$ENDIF}

{ ============================================================================
  TODO 05 - LEXEUR : LECTURE SOURCE ET TOKENISATION
  ============================================================================ }

{ --------------------------------------------------------------------------
  Variables d'etat du lexeur
  -------------------------------------------------------------------------- }

Var
  lex_line     : String;        { ligne source courante (brute)             }
  lex_pos      : Integer;       { position courante dans lex_line (1-base)  }
  lex_line_raw : String;        { copie de la ligne avant toute modification}
  lex_at_eol   : Boolean;       { True quand la ligne est entierement lue   }
  lex_at_eof   : Boolean;       { True quand le fichier source est epuise   }
  lex_in_cont  : Boolean;       { True si la ligne est une continuation     }
  { Token courant }
  cur_tok_type : TTokType;      { type du token en cours                    }
  cur_tok_str  : TString;       { valeur chaine du token                    }
  cur_tok_num  : LongInt;       { valeur entiere du token                   }
  cur_tok_real : LongInt;       { valeur reelle 16.16 du token              }

{ --------------------------------------------------------------------------
  Helpers internes du lexeur
  -------------------------------------------------------------------------- }

Function LexCurChar: Char;
{ Caractere courant sans avancer }
Begin
  If lex_pos > Length(lex_line) Then LexCurChar := #0
  Else LexCurChar := lex_line[lex_pos];
End;

Function LexPeekChar(offset: Integer): Char;
{ Regarder le caractere a lex_pos + offset (0 = courant) }
Var p : Integer;
Begin
  p := lex_pos + offset;
  If (p < 1) Or (p > Length(lex_line)) Then LexPeekChar := #0
  Else LexPeekChar := lex_line[p];
End;

Procedure LexAdvance;
{ Avancer d'un caractere dans la ligne }
Begin
  If lex_pos <= Length(lex_line) Then Inc(lex_pos);
End;

Procedure LexSkipSpaces;
{ Sauter les espaces et tabulations en position courante }
Begin
  While (lex_pos <= Length(lex_line)) And
        (lex_line[lex_pos] In [' ', #9]) Do
    Inc(lex_pos);
End;

{ --------------------------------------------------------------------------
  LexReadLine : lire la prochaine ligne significative du fichier source.

  Regles SNOBOL 4 :
    - Ligne dont le premier caractere est '*'  -> commentaire, ignorer.
    - Ligne dont le premier caractere est '+'
      ou '-' -> continuation de l'instruction precedente :
      on retire le premier caractere et on concat?ne au buffer en cours.
    - Ligne "-END-" (apres trim) -> fin de programme.
    - Ligne vide -> ignoree (ligne blanche).
  La fonction retourne True si une nouvelle instruction demarre,
  False si EOF.
  -------------------------------------------------------------------------- }

Function LexReadLine: Boolean;
Var raw : String;
    ch1 : Char;
Begin
  LexReadLine := False;
  Repeat
    If Eof(src_file) Then Begin lex_at_eof := True; Exit; End;
    ReadLn(src_file, raw);
    Inc(src_line_num);
    { Normaliser : retirer CR residuel eventuel (DOS/Unix) }
    If (Length(raw) > 0) And (raw[Length(raw)] = #13) Then
      Delete(raw, Length(raw), 1);

    { Ligne vide -> ignorer }
    If Length(raw) = 0 Then Continue;

    ch1 := raw[1];

    { Commentaire : col 1 = '*' ou '!' }
    If ch1 In ['*', '!'] Then Continue;

    { Fin de programme }
    If raw = SB_END_SENTINEL Then
    Begin
      lex_at_eof := True;
      lex_line   := raw;
      lex_pos    := 1;
      LexReadLine := True;
      Exit;
    End;

    { Continuation : col 1 = '+' ou '-' }
    If ch1 In ['+', '-'] Then
    Begin
      { Concatener au contenu deja dans lex_line apres la colonne 1 }
      lex_line    := lex_line + Copy(raw, 2, Length(raw) - 1);
      lex_in_cont := True;
      Continue;
    End;

    { Nouvelle instruction }
    lex_line     := raw;
    lex_line_raw := raw;
    lex_pos      := 1;
    lex_at_eol   := False;
    lex_in_cont  := False;
    LexReadLine  := True;
    Exit;
  Until False;
End;

{ --------------------------------------------------------------------------
  Decomposition d'une ligne SNOBOL 4 en champs :
    LABEL (col 1..initialement, jusqu'au premier espace/tab ou hors col 1)
    SUBJECT
    PATTERN = REPLACEMENT
    :GOTO

  En SNOBOL 4, le LABEL est en colonne 1 (concerne seulement si le
  premier caractere n'est pas un espace).
  Le sujet, patron et remplacement sont separes par des espaces.
  La section goto commence au premier ':' non guillemete.
  -------------------------------------------------------------------------- }

{ Champs de l'instruction en cours }
Var
  inst_label   : TString;    { etiquette de l'instruction (peut etre '')    }
  inst_subject : TString;    { sujet (variable ou '')                       }
  inst_pattern : TString;    { patron brut (chaine, avant parsing)          }
  inst_repl    : TString;    { remplacement brut                            }
  inst_goto_s  : TString;    { label goto succes                            }
  inst_goto_f  : TString;    { label goto echec                             }
  inst_goto_u  : TString;    { label goto inconditionnel                    }
  inst_has_eq  : Boolean;    { True si '=' remplacement present             }

{ --------------------------------------------------------------------------
  LexExtractLabel : extraire le label eventuel de la ligne (colonne 1)
  Un label est present ssi le premier caractere de la ligne n'est pas
  un espace/tabulation.
  Le label se termine au premier espace/tab ou a la fin de la ligne.
  -------------------------------------------------------------------------- }

Procedure LexExtractLabel;
Var i : Integer;
Begin
  inst_label := '';
  { Si la ligne commence par un espace/tab -> pas de label }
  If (Length(lex_line) = 0) Or (lex_line[1] In [' ', #9]) Then
  Begin
    lex_pos := 1;
    Exit;
  End;
  { Lire jusqu'au premier espace/tab }
  i := 1;
  While (i <= Length(lex_line)) And Not (lex_line[i] In [' ', #9]) Do
    Inc(i);
  inst_label := UpCaseStr(Copy(lex_line, 1, i - 1));
  lex_pos   := i;
End;

{ --------------------------------------------------------------------------
  LexReadToken : lire le prochain token depuis la position lex_pos.
  Remplit cur_tok_type / cur_tok_str / cur_tok_num.
  -------------------------------------------------------------------------- }

Procedure LexReadToken;
Var ch    : Char;
    s     : TString;
    n     : LongInt;
    code  : Integer;
    delim : Char;
    i     : Integer;
    r     : LongInt;      { partie decimale 16.16 }
    frac  : LongInt;
    denom : LongInt;
Begin
  LexSkipSpaces;
  cur_tok_str  := '';
  cur_tok_num  := 0;
  cur_tok_real := 0;

  If lex_pos > Length(lex_line) Then
  Begin
    cur_tok_type := TOK_EOL;
    lex_at_eol  := True;
    Exit;
  End;

  ch := lex_line[lex_pos];

  { --- Debut de la section GOTO : ':' --- }
  If ch = ':' Then
  Begin
    LexAdvance;
    ch := LexCurChar;
    If ch = 'S' Then
    Begin
      LexAdvance; { S }
      LexAdvance; { ( }
      cur_tok_type := TOK_GOTO_S;
    End
    Else If ch = 'F' Then
    Begin
      LexAdvance; { F }
      LexAdvance; { ( }
      cur_tok_type := TOK_GOTO_F;
    End
    Else If ch = '(' Then
    Begin
      LexAdvance; { ( }
      cur_tok_type := TOK_GOTO_UNC;
    End
    Else
      cur_tok_type := TOK_COLON;
    Exit;
  End;

  { --- Litteral chaine : apostrophe ou guillemet --- }
  If ch In ['''', '"'] Then
  Begin
    delim := ch;
    LexAdvance;
    s := '';
    While lex_pos <= Length(lex_line) Do
    Begin
      ch := lex_line[lex_pos];
      LexAdvance;
      If ch = delim Then
      Begin
        { Double delimiteur -> delimiteur litterral }
        If (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = delim) Then
        Begin
          s := s + delim;
          LexAdvance;
        End
        Else Break;
      End
      Else
        s := s + ch;
    End;
    cur_tok_type := TOK_STRING;
    cur_tok_str  := s;
    Exit;
  End;

  { --- Entier ou reel --- }
  If ch In ['0'..'9'] Then
  Begin
    s := '';
    While (lex_pos <= Length(lex_line)) And
          (lex_line[lex_pos] In ['0'..'9']) Do
    Begin
      s := s + lex_line[lex_pos];
      LexAdvance;
    End;
    { Verifier presence d'un '.' pour reel }
    If (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = '.') Then
    Begin
      { Partie decimale }
      LexAdvance; { sauter '.' }
      frac  := 0;
      denom := 1;
      While (lex_pos <= Length(lex_line)) And
            (lex_line[lex_pos] In ['0'..'9']) Do
      Begin
        frac  := frac * 10 + (Ord(lex_line[lex_pos]) - Ord('0'));
        denom := denom * 10;
        LexAdvance;
      End;
      Val(s, n, code);
      { Representation 16.16 fixe : partie entiere * 65536 + frac/denom*65536 }
      cur_tok_real := (n shl 16) Or ((frac * 65536) Div denom);
      cur_tok_type := TOK_REAL;
    End
    Else
    Begin
      Val(s, n, code);
      cur_tok_num  := n;
      cur_tok_type := TOK_INTEGER;
    End;
    Exit;
  End;

  { --- Identifiant --- }
  If ch In ['A'..'Z','a'..'z','_'] Then
  Begin
    s := '';
    While (lex_pos <= Length(lex_line)) And
          (lex_line[lex_pos] In ['A'..'Z','a'..'z','0'..'9','_','.']) Do
    Begin
      s := s + lex_line[lex_pos];
      LexAdvance;
    End;
    cur_tok_type := TOK_IDENT;
    cur_tok_str  := UpCaseStr(s);
    Exit;
  End;

  { --- Variable systeme : & suivi d'un ident --- }
  If ch = '&' Then
  Begin
    LexAdvance;
    s := '';
    While (lex_pos <= Length(lex_line)) And
          (lex_line[lex_pos] In ['A'..'Z','a'..'z','0'..'9','_']) Do
    Begin
      s := s + lex_line[lex_pos];
      LexAdvance;
    End;
    cur_tok_type := TOK_AMP;
    cur_tok_str  := UpCaseStr(s);
    Exit;
  End;

  { --- Operateurs et ponctuation simples --- }
  LexAdvance;
  Case ch Of
    '(' : cur_tok_type := TOK_LPAREN;
    ')' : cur_tok_type := TOK_RPAREN;
    '<' : cur_tok_type := TOK_LANGLE;
    '>' : cur_tok_type := TOK_RANGLE;
    ',' : cur_tok_type := TOK_COMMA;
    '=' : cur_tok_type := TOK_EQ;
    '.' : cur_tok_type := TOK_DOT;
    '$' : cur_tok_type := TOK_DOLLAR;
    '@' : cur_tok_type := TOK_AT;
    '!' : cur_tok_type := TOK_BANG;
    '|' : cur_tok_type := TOK_PIPE;
    '*' : cur_tok_type := TOK_STAR;
    '#' : cur_tok_type := TOK_HASH;
    '/' : cur_tok_type := TOK_SLASH;
    '+' : cur_tok_type := TOK_PLUS;
    '-' : cur_tok_type := TOK_MINUS;
    '~' : cur_tok_type := TOK_TILDE;
    '^' : cur_tok_type := TOK_CARET;
    Else  cur_tok_type := TOK_UNKNOWN;
  End;
  cur_tok_str := ch;
End;

{ --------------------------------------------------------------------------
  LexExtractGoto : lire les labels de goto depuis la position courante.
  Appele quand LexReadToken retourne TOK_GOTO_S / TOK_GOTO_F / TOK_GOTO_UNC.
  Remplit inst_goto_s, inst_goto_f, inst_goto_u.
  La forme attendue dans lex_line a partir de lex_pos est :
      label)[:S(label)][:F(label)]
  -------------------------------------------------------------------------- }

Procedure LexReadGotoLabel(Var lbl: TString);
{ Lire le label jusqu'a ')' et avancer apres le ')' }
Var s : TString;
Begin
  s := '';
  While (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] <> ')') Do
  Begin
    s := s + lex_line[lex_pos];
    LexAdvance;
  End;
  If lex_pos <= Length(lex_line) Then LexAdvance; { sauter ')' }
  lbl := UpCaseStr(s);
End;

Procedure LexExtractGotos;
{ Parser toutes les sections :S(lbl) :F(lbl) :(lbl) sur la ligne }
Var ch : Char;
Begin
  inst_goto_s := '';
  inst_goto_f := '';
  inst_goto_u := '';
  Repeat
    LexSkipSpaces;
    If (lex_pos > Length(lex_line)) Or (LexCurChar <> ':') Then Break;
    LexAdvance; { ':' }
    ch := LexCurChar;
    If ch = 'S' Then
    Begin
      LexAdvance; LexAdvance; { S( }
      LexReadGotoLabel(inst_goto_s);
    End
    Else If ch = 'F' Then
    Begin
      LexAdvance; LexAdvance; { F( }
      LexReadGotoLabel(inst_goto_f);
    End
    Else If ch = '(' Then
    Begin
      LexAdvance; { ( }
      LexReadGotoLabel(inst_goto_u);
    End
    Else Break;
  Until False;
End;

{ --------------------------------------------------------------------------
  InitLexer : initialiser l'etat du lexeur avant la premiere ligne
  -------------------------------------------------------------------------- }

Procedure InitLexer;
Begin
  lex_line     := '';
  lex_pos      := 1;
  lex_line_raw := '';
  lex_at_eol   := False;
  lex_at_eof   := False;
  lex_in_cont  := False;
  cur_tok_type := TOK_EOF;
  cur_tok_str  := '';
  cur_tok_num  := 0;
  cur_tok_real := 0;
  { Champs d'instruction }
  inst_label   := '';
  inst_subject := '';
  inst_pattern := '';
  inst_repl    := '';
  inst_goto_s  := '';
  inst_goto_f  := '';
  inst_goto_u  := '';
  inst_has_eq  := False;
End;

{ ============================================================================
  TODO 06 - TABLE DES MOTS-CLES ET IDENTIFICATEURS PREDEFINIS
  ============================================================================ }

{ --------------------------------------------------------------------------
  RegisterBuiltin : enregistrer une fonction integree dans SymTable + FuncTable
  -------------------------------------------------------------------------- }

Procedure RegisterBuiltin(Const nm: TString; nparams: Integer);
Var si, fi : Integer;
Begin
  si := AddSym(nm, SK_BUILTIN, VK_STR);
  If si = 0 Then Exit;
  sym_table^[si].param_idx := nparams;   { nb params attendus (0 = variable) }
  fi := AddFunc(nm, SUB_BUILTIN);
  If fi = 0 Then Exit;
  func_table^[fi].param_count := nparams;
End;

{ --------------------------------------------------------------------------
  RegisterSysVar : enregistrer une variable systeme &NOM dans SymTable
  -------------------------------------------------------------------------- }

Procedure RegisterSysVar(Const nm: TString; init_val: LongInt; vk: TValueKind);
Var si : Integer;
Begin
  si := AddSym(nm, SK_SYSVAR, vk);
  If si = 0 Then Exit;
  sym_table^[si].init_num  := init_val;
  sym_table^[si].asm_label := '_SB_SYS_' + AsmSafeIdent(nm);
End;

{ --------------------------------------------------------------------------
  RegisterBuiltins : enregistrer toutes les fonctions integrees SNOBOL 4
  --------------------------------------------------------------------------

  Fonctions de manipulation de chaines
  ------------------------------------
  SIZE(s)            -> longueur de s (entier)
  SUBSTR(s, i, n)    -> sous-chaine de s a partir de i sur n chars
  DUPL(s, n)         -> s repete n fois
  REPLACE(s, t, u)   -> s avec traduction par table t->u
  TRIM(s)            -> s sans espaces de fin
  LPAD(s, n)         -> s complete a gauche par des espaces jusqu'a n chars
  RPAD(s, n)         -> s complete a droite par des espaces jusqu'a n chars
  REVERSE(s)         -> s inverse caractere par caractere
  UPPER(s)           -> s en majuscules
  LOWER(s)           -> s en minuscules

  Fonctions de conversion et typage
  ----------------------------------
  CONVERT(v, t)      -> convertir v vers le type nomme par t
  DATATYPE(v)        -> nom du type de v ('STRING', 'INTEGER', 'REAL'...)
  INTEGER(s)         -> predicat : retourne entier si s est entier, sinon FAIL
  REAL(s)            -> predicat : retourne reel si s est reel, sinon FAIL
  NUMERIC(s)         -> predicat : retourne s si numerique (entier ou reel)
  CHAR(n)            -> chaine d'un seul caractere de code ASCII n
  ORD(s)             -> entier : code ASCII du premier caractere de s

  Predicats de comparaison numerique (retournent leur 2e arg si vrai, FAIL sinon)
  ---------------------------------------------------------------------------------
  LT(x, y)  / LE(x, y) / GT(x, y) / GE(x, y) / EQ(x, y) / NE(x, y)

  Predicats d'identite de chaines
  --------------------------------
  IDENT(s1, s2)      -> s1 = s2 exactement (retourne s1 si vrai, FAIL sinon)
  DIFFER(s1, s2)     -> s1 # s2 (retourne s1 si vrai, FAIL sinon)

  Fonctions systeme
  -----------------
  DATE               -> chaine date DOS (AH=2Ah INT 21h)
  TIME               -> chaine heure DOS (AH=2Ch INT 21h)
  -------------------------------------------------------------------------- }

Const
  BC_COUNT  = 44;
  BC_NAMES  : Array[1..44] Of String[10] = (
    { Manipulation de chaines }
    'SIZE','SUBSTR','DUPL','REPLACE','TRIM','LPAD','RPAD','REVERSE','UPPER','LOWER',
    { Conversion et typage }
    'CONVERT','DATATYPE','INTEGER','REAL','NUMERIC','CHAR','ORD',
    { Predicats numeriques }
    'LT','LE','GT','GE','EQ','NE',
    { Predicats de chaines }
    'IDENT','DIFFER',
    { Fonctions systeme }
    'DATE','TIME',
    { Patterns predifinis }
    'ANY','NOTANY','SPAN','BREAK','BREAKX','LEN','POS','RPOS','TAB','RTAB',
    'ARB','ARBNO','REM','FAIL','FENCE','ABORT','SUCCEED');
  BC_PARAMS : Array[1..44] Of Integer = (
    1, 3, 2, 3, 1, 2, 2, 1, 1, 1,
    2, 1, 1, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2,
    2, 2,
    0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    0, 1, 0, 0, 0, 0, 0);

Procedure RegisterBuiltins;
Var i : Integer;
Begin
  For i := 1 To BC_COUNT Do
    RegisterBuiltin(BC_NAMES[i], BC_PARAMS[i]);
End;

{ --------------------------------------------------------------------------
  RegisterSysVars : enregistrer toutes les variables systeme &xxx
  --------------------------------------------------------------------------

  &ALPHABET  -> chaine des 256 caracteres ASCII (0..255)
  &ANCHOR    -> entier 0/1 : mode ancrage du matching (defaut 0 = libre)
  &DUMP      -> entier : afficher dump des variables si <>0 a la fin
  &FAIL      -> patron : echoue toujours (alias de FAIL)
  &FENCE     -> patron : coupe le backtrack
  &FNCODE    -> entier : code retour de derniere fonction externe
  &FULLSCAN  -> entier : mode scan complet (defaut 0)
  &INPUT     -> chaine : lecture d'une ligne sur stdin a chaque evaluation
  &OUTPUT    -> chaine : ecriture sur stdout a chaque affectation
  &STCOUNT   -> entier : compteur d'instructions executees
  &STFAIL    -> entier : nombre d'echecs de matching
  &STLIMIT   -> entier : limite max de &STCOUNT (defaut 50000)
  &SUBJECT   -> chaine : sujet courant du matching en cours
  &SUCCESS   -> patron : reussit toujours (alias de SUCCEED)
  &TRIM      -> entier 0/1 : trim auto de l'entree (defaut 0)
  -------------------------------------------------------------------------- }

Const
  SV_LAST = 14;
  builtinCommandArray : Array[0..14] Of String[10] = (
    'ALPHABET','ANCHOR','DUMP','FAIL','FENCE','FNCODE','FULLSCAN','INPUT',
    'OUTPUT','STCOUNT','STFAIL','STLIMIT','SUBJECT','SUCCESS','TRIM');
  SV_INITS : Array[0..14] Of LongInt = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50000, 0, 0, 0);
  SV_KINDS : Array[0..14] Of TValueKind = (
    VK_STR, VK_INT, VK_INT, VK_PAT, VK_PAT, VK_INT, VK_INT, VK_STR,
    VK_STR, VK_INT, VK_INT, VK_INT, VK_STR, VK_PAT, VK_INT);

Procedure RegisterSysVars;
Var i : Integer;
Begin
  For i := 0 To SV_LAST Do
    RegisterSysVar(builtinCommandArray[i], SV_INITS[i], SV_KINDS[i]);
End;

{ --------------------------------------------------------------------------
  Fonctions de recherche rapide dans les tables predefinis
  -------------------------------------------------------------------------- }

Function IsBuiltin(Const nm: TString): Boolean;
{ True si nm est une fonction integree }
Var si : Integer;
Begin
  si := FindSym(nm);
  IsBuiltin := (si > 0) And (sym_table^[si].kind = SK_BUILTIN);
End;

Function IsSysVar(Const nm: TString): Boolean;
{ True si nm est une variable systeme (&xxx) }
Var si : Integer;
Begin
  si := FindSym(nm);
  IsSysVar := (si > 0) And (sym_table^[si].kind = SK_SYSVAR);
End;

Function GetBuiltinParamCount(Const nm: TString): Integer;
{ Nombre de parametres attendus par la fonction integree nm }
Var si : Integer;
Begin
  si := FindSym(nm);
  If (si > 0) And (sym_table^[si].kind = SK_BUILTIN) Then
    GetBuiltinParamCount := sym_table^[si].param_idx
  Else
    GetBuiltinParamCount := -1;
End;

Function IsPatternBuiltin(Const nm: TString): Boolean;
{ True si nm est une fonction retournant un patron (ANY, LEN, ARB...) }
Const pat_builtins : Array[1..17] Of String[8] = (
  'ANY','NOTANY','SPAN','BREAK','BREAKX',
  'LEN','POS','RPOS','TAB','RTAB',
  'ARB','ARBNO','REM','FAIL','FENCE','ABORT','SUCCEED');
Var i : Integer;
    u : TString;
Begin
  u := UpCaseStr(nm);
  IsPatternBuiltin := False;
  For i := 1 To 17 Do
    If pat_builtins[i] = u Then Begin IsPatternBuiltin := True; Exit; End;
End;

Function IsPredicateBuiltin(Const nm: TString): Boolean;
{ True si nm est un predicat numerique ou de chaine (LT/LE/.../IDENT/DIFFER) }
Const pred_builtins : Array[1..8] Of String[6] = (
  'LT','LE','GT','GE','EQ','NE','IDENT','DIFFER');
Var i : Integer;
    u : TString;
Begin
  u := UpCaseStr(nm);
  IsPredicateBuiltin := False;
  For i := 1 To 8 Do
    If pred_builtins[i] = u Then Begin IsPredicateBuiltin := True; Exit; End;
End;

{ --------------------------------------------------------------------------
  InitPredefined : appel group? enregistrant builtins + sysvars.
  Appelee une seule fois au debut de Compile (TODO 25).
  -------------------------------------------------------------------------- }

Procedure InitPredefined;
Begin
  RegisterBuiltins;
  RegisterSysVars;
End;

{ ============================================================================
  TODO 07 - GESTION DES ERREURS ET DES AVERTISSEMENTS
  ============================================================================ }

{ --------------------------------------------------------------------------
  Helpers de formatage
  -------------------------------------------------------------------------- }

Function PadLeft(Const s: String; n: Integer): String;
{ Cadrer s a gauche dans un champ de n caracteres }
Var r : String;
Begin
  r := s;
  While Length(r) < n Do r := ' ' + r;
  PadLeft := r;
End;

Function PadRight(Const s: String; n: Integer): String;
{ Cadrer s a droite dans un champ de n caracteres }
Var r : String;
Begin
  r := s;
  While Length(r) < n Do r := r + ' ';
  PadRight := r;
End;

{ --------------------------------------------------------------------------
  Affichage des messages d'erreur / avertissement sur stderr
  Les messages sont toujours affiches sur la console (WriteLn),
  independamment du fichier de sortie courant.
  -------------------------------------------------------------------------- }

Procedure PrintMsg(Const prefix, msg: String);
{ Afficher  PREFIX  (ligne N) : message }
Begin
  If src_line_num > 0 Then
    WriteLn(prefix, ' (ligne ', src_line_num, ') : ', msg)
  Else
    WriteLn(prefix, ' : ', msg);
End;

Procedure PrintMsgLine;
{ Afficher le contexte : la ligne source et un pointeur sous le token }
Begin
  If Length(lex_line) > 0 Then
  Begin
    WriteLn('  >> ', lex_line);
    If lex_pos > 1 Then
      WriteLn('  >> ', StringOfChar(' ', lex_pos - 1), '^');
  End;
End;

{ --------------------------------------------------------------------------
  Error / ErrorTok / Warning / FatalError
  -------------------------------------------------------------------------- }

Procedure Error(Const msg: String);
{ Erreur de compilation : incrementer le compteur, afficher, continuer. }
Begin
  Inc(err_count);
  PrintMsg('ERREUR', msg);
  PrintMsgLine;
  If opt_strict Then
  Begin
    WriteLn('Arret sur premiere erreur (mode strict).');
    Halt(1);
  End;
End;

Procedure ErrorTok(Const msg: String);
{ Erreur liee au token courant (ajoute le token au message). }
Var tok_info : String;
Begin
  Case cur_tok_type Of
    TOK_IDENT    : tok_info := '''' + cur_tok_str + '''';
    TOK_STRING   : tok_info := '"' + cur_tok_str + '"';
    TOK_INTEGER  : tok_info := IntToStr(cur_tok_num);
    TOK_EOF      : tok_info := '<EOF>';
    TOK_EOL      : tok_info := '<EOL>';
    TOK_UNKNOWN  : tok_info := '''' + cur_tok_str + '''';
    Else           tok_info := '''' + cur_tok_str + '''';
  End;
  Error(msg + ' (token : ' + tok_info + ')');
End;

Procedure Warning(Const msg: String);
{ Avertissement : n'interrompt pas la compilation. }
Begin
  Inc(warn_count);
  PrintMsg('ATTENTION', msg);
  If opt_debug >= DBG_ERRORS Then PrintMsgLine;
End;

Procedure FatalError(Const msg: String);
{ Erreur interne ou irrecuperable : afficher et arreter immediatement. }
Begin
  Inc(err_count);
  WriteLn('ERREUR FATALE : ', msg);
  If src_line_num > 0 Then
    WriteLn('  Ligne source : ', src_line_num);
  WriteLn('Compilation abandonnee.');
  { Fermer les fichiers proprement avant de quitter }
  {$I-}
  If lst_open Then Close(lst_file);
  If tmp_open Then Close(tmp_file);
  {$I+}
  Halt(2);
End;

Procedure InternalError(Const msg: String);
{ Erreur de bug interne du compilateur lui-meme. }
Begin
  FatalError('BUG INTERNE - ' + msg);
End;

{ --------------------------------------------------------------------------
  CheckLabel : verifier que tous les labels cibles ont ete definis.
  Appelee en fin de passe 1 pour detecter les forward refs non resolues.
  -------------------------------------------------------------------------- }

Procedure CheckUndefinedLabels;
Var i : Integer;
Begin
  For i := 1 To label_count Do
    If Not label_table^[i].defined Then
      Error('Label non defini : ' + label_table^[i].name);
End;

{ --------------------------------------------------------------------------
  BilanCompilation : afficher le resume final de la compilation.
  Appelee a la fin de Compile (TODO 25).
  -------------------------------------------------------------------------- }

Procedure BilanCompilation;
Var ok : Boolean;
Begin
  WriteLn;
  WriteLn('SNOBOL86 - Compilation terminee');
  WriteLn('  Source     : ', src_fname);
  WriteLn('  Sortie     : ', out_fname);
  WriteLn('  Instructions : ', PadLeft(IntToStr(instr_count),  6));
  WriteLn('  Symboles     : ', PadLeft(IntToStr(sym_count),    6));
  WriteLn('  Labels       : ', PadLeft(IntToStr(label_count),  6));
  WriteLn('  Patrons      : ', PadLeft(IntToStr(pat_count),    6));
  WriteLn('  Fonctions    : ', PadLeft(IntToStr(func_count),   6));
  WriteLn('  Erreurs      : ', PadLeft(IntToStr(err_count),    6));
  WriteLn('  Attention    : ', PadLeft(IntToStr(warn_count),   6));
  ok := (err_count = 0);
  If Not ok Then
    WriteLn('  *** COMPILATION AVEC ERREURS ***')
  Else If warn_count > 0 Then
    WriteLn('  (compilation reussie avec avertissements)')
  Else
    WriteLn('  (compilation reussie)');
End;

{ --------------------------------------------------------------------------
  DebugMsg : trace interne conditionnelle selon opt_debug
  -------------------------------------------------------------------------- }

Procedure DebugMsg(level: Integer; Const msg: String);
Begin
  If opt_debug >= level Then
    WriteLn('[DEBUG] ', msg);
End;

{ ============================================================================
  TODO 08 - GENERATION D'EN-TETE ASM ET SEGMENT .DATA
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenHeader : emettre le commentaire d'en-tete, .MODEL SMALL, .STACK 256
  -------------------------------------------------------------------------- }

Procedure GenHeader;
Begin
  EmitComment(StringOfChar('=', 72));
  EmitComment('Genere par SNOBOL86 v' + SNOBOL86_VERSION +
              ' - SNOBOL 4 -> 8086 MASM');
  EmitComment('Source : ' + src_fname);
  EmitComment(StringOfChar('=', 72));
  EmitBlank;
  Emit('.MODEL SMALL');
  Emit('.STACK 256');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataSegHeader : ouvrir le segment .DATA
  -------------------------------------------------------------------------- }

Procedure GenDataSegHeader;
Begin
  Emit('.DATA');
  EmitBlank;
  EmitComment('--- Constantes systeme ---');
End;

{ --------------------------------------------------------------------------
  GenPredefinedData : emettre les constantes et descripteurs predifinis :
    - Chaine vide (_SB_EMPTY_DESC / _SB_EMPTY_BUF)
    - CRLF       (_SB_CRLF_DESC  / _SB_CRLF_BUF)
    - &ALPHABET  (256 octets 0..255)
    - _SB_FAIL_DESC  (sentinel d'echec : ptr=0, len=0FFFFh)
  -------------------------------------------------------------------------- }

Procedure GenPredefinedData;
Var i : Integer;
    s : String;
Begin
  { Chaine vide }
  GenEmptyStrData;

  { CRLF }
  GenCrlfData;

  { &ALPHABET : 256 caracteres de code 0 a 255 }
  EmitComment('&ALPHABET - les 256 caracteres ASCII');
  EmitI('_SB_SYS_ALPHABET_D:');
  EmitI('  DW  OFFSET _SB_SYS_ALPHABET_B  ; ptr');
  EmitI('  DW  256                         ; len');
  EmitI('_SB_SYS_ALPHABET_B:');
  s := 'DB  ';
  For i := 0 To 255 Do
  Begin
    If i > 0 Then s := s + ', ';
    s := s + IntToStr(i);
    { Ligne de 16 valeurs pour lisibilite }
    If (i > 0) And ((i Mod 16) = 15) And (i < 255) Then
    Begin
      EmitI(s);
      s := 'DB  ';
    End;
  End;
  If s <> 'DB  ' Then EmitI(s);
  EmitBlank;

  { Sentinel FAIL : ptr=0, len=0FFFFh -> valeur magique non-string }
  EmitComment('_SB_FAIL_DESC - sentinel d''echec (len=0FFFFh)');
  EmitI('_SB_FAIL_DESC:');
  EmitI('  DW  0       ; ptr nul');
  EmitI('  DW  0FFFFh  ; len magique = echec');
  EmitBlank;

  { Variables systeme numeriques }
  EmitComment('--- Variables systeme (&xxx) ---');
  EmitI('_SB_SYS_ANCHOR  DW  0       ; &ANCHOR');
  EmitI('_SB_SYS_DUMP    DW  0       ; &DUMP');
  EmitI('_SB_SYS_FNCODE  DW  0       ; &FNCODE');
  EmitI('_SB_SYS_FULLSCAN DW 0       ; &FULLSCAN');
  EmitI('_SB_SYS_STCOUNT  DW 0       ; &STCOUNT');
  EmitI('_SB_SYS_STFAIL   DW 0       ; &STFAIL');
  EmitI('_SB_SYS_STLIMIT  DW 50000   ; &STLIMIT');
  EmitI('_SB_SYS_TRIM     DW 0       ; &TRIM');
  EmitBlank;

  { &INPUT / &OUTPUT / &SUBJECT comme descripteurs }
  GenDescriptor('_SB_SYS_INPUT_D',   '_SB_SYS_INPUT_B',   0);
  GenDescriptor('_SB_SYS_OUTPUT_D',  '_SB_SYS_OUTPUT_B',  0);
  GenDescriptor('_SB_SYS_SUBJECT_D', '_SB_SYS_SUBJECT_B', 0);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenVarDescriptors : emettre les descripteurs de toutes les variables
  SNOBOL globales (SK_VAR) declarees dans SymTable.
  Les variables locales (is_local=True) sont sur la pile, pas en .DATA.
  -------------------------------------------------------------------------- }

Procedure GenVarDescriptors;
Var i      : Integer;
    e      : TSymEntry;
    buflen : Integer;
Begin
  EmitComment('--- Descripteurs de variables SNOBOL ---');
  For i := 1 To sym_count Do
  Begin
    e := sym_table^[i];
    If (e.kind = SK_VAR) And Not e.is_local Then
    Begin
      { Taille de buffer initiale : longueur de la valeur initiale ou 16 min }
      buflen := Length(e.init_str);
      If buflen < 16 Then buflen := 16;
      GenDescriptor(e.asm_label + '_D', e.asm_label + '_B', buflen);
    End;
  End;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenLiteralPool : emettre tous les litteraux de chaine collectes
  pendant la passe 1 (enregistres dans str_pool via StrPoolAdd).
  Chaque litteral i genere _SBS_i_D (descripteur) + _SBS_i_B (buffer).
  Pour simplifier, on re-parcourt sym_table cherchant SK_CONST_STR.
  -------------------------------------------------------------------------- }

Procedure GenLiteralPool;
Var i   : Integer;
    e   : TSymEntry;
    s   : TString;
Begin
  EmitComment('--- Pool de litteraux de chaine ---');
  For i := 1 To sym_count Do
  Begin
    e := sym_table^[i];
    If e.kind = SK_CONST_STR Then
    Begin
      s := StrPoolGet(e.str_idx, e.str_len);
      GenDescriptorFromLit(
        LitDescLabel(e.str_idx),
        LitDataLabel(e.str_idx),
        s);
    End;
  End;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenHeapDataSeg : emettre la zone heap dans .DATA
  -------------------------------------------------------------------------- }

Procedure GenHeapDataSeg;
Begin
  GenHeapData(opt_heap_size);
End;

{ --------------------------------------------------------------------------
  GenRuntimeBuffers : buffers de travail utilises par le runtime
    _SB_NUMBUF   : buffer temporaire pour conversion entier->chaine (12 b)
    _SB_INPUTBUF : buffer lecture ligne stdin (128 b, format DOS AH=0Ah)
    _SB_WORKDESC : descripteur temporaire (scratch)
    _SB_WORKBUF  : buffer de travail general (256 b)
  -------------------------------------------------------------------------- }

Procedure GenRuntimeBuffers;
Begin
  EmitComment('--- Buffers runtime ---');
  EmitI('_SB_NUMBUF    DB  12 DUP(0)   ; conversion entier->chaine');
  EmitI('_SB_INPUTBUF  DB  128 DUP(0)  ; lecture ligne DOS AH=0Ah');
  EmitI('_SB_WORKDESC:');
  EmitI('  DW  OFFSET _SB_WORKBUF  ; ptr scratch');
  EmitI('  DW  0                   ; len scratch');
  EmitI('_SB_WORKBUF   DB  256 DUP(0)  ; buffer de travail');
  EmitBlank;
End;

{ Forward : GenStlimitMsg definie en TODO 09 }
Procedure GenStlimitMsg; Forward;

{ --------------------------------------------------------------------------
  GenDataSegment : orchestrateur complet du segment .DATA.
  Appele par Compile (TODO 25) en debut de passe 2.
  -------------------------------------------------------------------------- }

Procedure GenDataSegment;
Begin
  GenDataSegHeader;
  GenPredefinedData;
  GenVarDescriptors;
  GenLiteralPool;
  GenHeapDataSeg;
  GenRuntimeBuffers;
  GenStlimitMsg;
End;

{ --------------------------------------------------------------------------
  AddLiteral : enregistrer un litteral de chaine dans SymTable + str_pool.
  Retourne l'index str_pool du debut du litteral (utilise comme cle unique).
  Si le meme litteral existe deja, retourne l'index existant.
  -------------------------------------------------------------------------- }

Function AddLiteral(Const s: TString): Integer;
Var i   : Integer;
    idx : Integer;
Begin
  { Chercher un litteral identique deja enregistre }
  For i := 1 To sym_count Do
    If (sym_table^[i].kind = SK_CONST_STR) And
       (StrPoolGet(sym_table^[i].str_idx, sym_table^[i].str_len) = s) Then
    Begin
      AddLiteral := sym_table^[i].str_idx;
      Exit;
    End;
  { Nouveau litteral }
  idx := StrPoolAdd(s);
  If idx < 0 Then Begin Error('Pool de chaines plein'); AddLiteral := 0; Exit; End;
  i := AddSym('_LIT_' + IntToStr(idx), SK_CONST_STR, VK_STR);
  If i = 0 Then Begin Error('Table des symboles pleine'); AddLiteral := 0; Exit; End;
  sym_table^[i].str_idx := idx;
  sym_table^[i].str_len := Length(s);
  AddLiteral := idx;
End;

{ ============================================================================
  TODO 09 - GENERATION DU SEGMENT .CODE ET POINT D'ENTREE
  ============================================================================ }

{ --------------------------------------------------------------------------
  Variables de suivi du segment .CODE
  -------------------------------------------------------------------------- }

Var
  main_proc_label : TString;   { label ASM de la procedure principale     }
  first_instr_lbl : TString;   { label de la premiere instruction SNOBOL  }
  cur_func_idx    : Integer;   { index dans func_table de la fonction courante (0=aucune) }

{ --------------------------------------------------------------------------
  GenCodeSegHeader : ouvrir .CODE et emettre le point d'entree START:

  Structure emise :
    .CODE
    START:
        MOV  AX, @DATA
        MOV  DS, AX
        MOV  ES, AX
        CALL _SB_INIT_HEAP
        CALL _SB_INIT_IO
        CALL _SB_INIT_SYSVARS
        JMP  <premiere_instruction>

  Si le programme source est vide (aucune instruction), on saute
  directement vers _SB_END_PROG.
  -------------------------------------------------------------------------- }

Procedure GenCodeSegHeader;
Begin
  EmitBlank;
  Emit('.CODE');
  EmitBlank;
  EmitComment(StringOfChar('=', 72));
  EmitComment('Point d''entree du programme');
  EmitComment(StringOfChar('=', 72));
  EmitLabel('START');
  EmitI('MOV  AX, @DATA');
  EmitI('MOV  DS, AX');
  EmitI('MOV  ES, AX');
  EmitBlank;
  EmitComment('Initialisation runtime SNOBOL');
  EmitI('CALL _SB_INIT_HEAP');
  EmitI('CALL _SB_INIT_IO');
  EmitI('CALL _SB_INIT_SYSVARS');
  EmitBlank;
  EmitComment('Saut vers la premiere instruction du programme');
  If first_instr_lbl <> '' Then
    EmitI('JMP  ' + first_instr_lbl)
  Else
    EmitI('JMP  _SB_END_PROG');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenInitIO : emettre la routine _SB_INIT_IO dans le segment .CODE.
  En v1, stdin/stdout sont deja ouverts sous DOS -> initialisation nulle.
  La routine prepare juste le buffer _SB_INPUTBUF pour AH=0Ah.
  -------------------------------------------------------------------------- }

Procedure GenInitIO;
Begin
  EmitSep;
  EmitComment('_SB_INIT_IO : initialiser stdin/stdout (DOS : deja ouvert)');
  EmitSep;
  EmitLabel('_SB_INIT_IO');
  EmitI('MOV  AL, 127');
  EmitI('MOV  [_SB_INPUTBUF], AL    ; max chars pour AH=0Ah');
  EmitI('MOV  BYTE PTR [_SB_INPUTBUF+1], 0');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenInitSysVars : emettre la routine _SB_INIT_SYSVARS.
  Remet a zero / initialise les variables systeme au lancement.
  -------------------------------------------------------------------------- }

Procedure GenInitSysVars;
Begin
  EmitSep;
  EmitComment('_SB_INIT_SYSVARS : initialiser les variables systeme &xxx');
  EmitSep;
  EmitLabel('_SB_INIT_SYSVARS');
  EmitI('XOR  AX, AX');
  EmitI('MOV  [_SB_SYS_ANCHOR],   AX');
  EmitI('MOV  [_SB_SYS_DUMP],     AX');
  EmitI('MOV  [_SB_SYS_FNCODE],   AX');
  EmitI('MOV  [_SB_SYS_FULLSCAN], AX');
  EmitI('MOV  [_SB_SYS_STCOUNT],  AX');
  EmitI('MOV  [_SB_SYS_STFAIL],   AX');
  EmitI('MOV  [_SB_SYS_TRIM],     AX');
  EmitI('MOV  AX, 50000');
  EmitI('MOV  [_SB_SYS_STLIMIT],  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStcountCheck : emettre une verification &STCOUNT / &STLIMIT.
  Emise inline avant chaque instruction SNOBOL (TODO 16+).

  Logique :
      INC  [_SB_SYS_STCOUNT]
      MOV  AX, [_SB_SYS_STCOUNT]
      CMP  AX, [_SB_SYS_STLIMIT]
      JBE  @@ok
      ; depasser la limite : afficher message et quitter
      MOV  DX, OFFSET _SB_STLIMIT_MSG
      MOV  AH, 9
      INT  21h
      JMP  _SB_END_PROG
  @@ok:
  -------------------------------------------------------------------------- }

Procedure GenStcountCheck;
Var lbl_ok : TString;
Begin
  lbl_ok := NewLabel;
  EmitI('INC  WORD PTR [_SB_SYS_STCOUNT]');
  EmitI('MOV  AX, [_SB_SYS_STCOUNT]');
  EmitI('CMP  AX, [_SB_SYS_STLIMIT]');
  EmitI('JBE  ' + lbl_ok);
  EmitI('MOV  DX, OFFSET _SB_STLIMIT_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitLabel(lbl_ok);
End;

{ --------------------------------------------------------------------------
  GenStlimitMsg : emettre la chaine de message de depassement STLIMIT
  dans le .DATA. (Appellee depuis GenDataSegment si besoin.)
  Utilise le format DOS : chaine terminee par '$' pour INT 21h AH=9.
  -------------------------------------------------------------------------- }

Procedure GenStlimitMsg;
Begin
  EmitComment('Message depassement &STLIMIT');
  EmitI('_SB_STLIMIT_MSG:');
  EmitI('  DB  ''Erreur : &STLIMIT depasse'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenEndProg : emettre la routine de fin de programme _SB_END_PROG.

  Structure emise :
    _SB_END_PROG:
        ; Si &DUMP <> 0 -> appeler _SB_DUMP_VARS
        MOV  AX, [_SB_SYS_DUMP]
        CMP  AX, 0
        JE   @@nodump
        CALL _SB_DUMP_VARS
    @@nodump:
        MOV  AX, 4C00h
        INT  21h
  -------------------------------------------------------------------------- }

Procedure GenEndProg;
Var lbl_nodump : TString;
Begin
  EmitSep;
  EmitComment('_SB_END_PROG : fin du programme SNOBOL');
  EmitSep;
  EmitLabel('_SB_END_PROG');
  lbl_nodump := NewLabel;
  EmitI('MOV  AX, [_SB_SYS_DUMP]');
  EmitI('CMP  AX, 0');
  EmitI('JE   ' + lbl_nodump);
  EmitI('CALL _SB_DUMP_VARS');
  EmitLabel(lbl_nodump);
  EmitBlank;
  EmitComment('Retour DOS - code 0');
  EmitI('MOV  AX, 4C00h');
  EmitI('INT  21h');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDumpVarsStub : emettre un stub _SB_DUMP_VARS (v1 : ne fait rien).
  En v2, cette routine afficherait toutes les variables si &DUMP <> 0.
  -------------------------------------------------------------------------- }

Procedure GenDumpVarsStub;
Begin
  EmitSep;
  EmitComment('_SB_DUMP_VARS : dump variables globales (stub v1)');
  EmitSep;
  EmitLabel('_SB_DUMP_VARS');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenFooter : emettre la directive END START en toute fin de fichier ASM.
  C'est la derniere chose generee en passe 2 (apres tout le runtime).
  -------------------------------------------------------------------------- }

Procedure GenFooter;
Begin
  EmitBlank;
  EmitComment(StringOfChar('=', 72));
  EmitComment('Fin du fichier genere par SNOBOL86');
  EmitComment(StringOfChar('=', 72));
  Emit('END START');
End;

{ --------------------------------------------------------------------------
  SetFirstInstrLabel : enregistrer le label de la 1ere instruction SNOBOL.
  Appele par le parseur (TODO 15) quand il emet la premiere instruction.
  -------------------------------------------------------------------------- }

Procedure SetFirstInstrLabel(Const lbl: TString);
Begin
  If first_instr_lbl = '' Then
    first_instr_lbl := lbl;
End;

{ --------------------------------------------------------------------------
  GenEndSentinel : traiter la ligne "-END-" du source.
  Emet un JMP vers _SB_END_PROG a l'endroit courant du code.
  Gere aussi les labels optionnels apres -END- (non standard, ignore).
  -------------------------------------------------------------------------- }

Procedure GenEndSentinel;
Begin
  EmitComment('Fin explicite du programme (-END-)');
  EmitI('JMP  _SB_END_PROG');
  EmitBlank;
End;

{ ============================================================================
  TODO 10 - RUNTIME : GESTION DE LA MEMOIRE (HEAP)
  ============================================================================

  Le heap SNOBOL est une zone lineaire allouee en .DATA (_HEAP_BUF).
  Trois mots de controle en .DATA :
      _HEAP_BASE DW  <- offset du debut du heap dans DS
      _HEAP_PTR  DW  <- offset du prochain octet libre
      _HEAP_END  DW  <- offset du premier octet invalide

  Convention des routines :
    _SB_ALLOC  : CX = nb octets demandes -> BX = ptr alloue (ou 0 : OOM)
    _SB_NEWSTR : CX = longueur souhaitee  -> DI = ptr descripteur alloue
    _SB_COPYSTR: SI = src_desc, DI = dst_desc  (copie len + data)
    _SB_CONCATSTR : DI = desc1, SI = desc2 -> DX = nouveau desc (joint)

  Format d'un descripteur (4 octets) :
      [ptr:WORD] [len:WORD]
  Alloue toujours : 4 octets (descripteur) + len + 1 (garde-fou null).
  ============================================================================ }

{ --------------------------------------------------------------------------
  _SB_ALLOC : allouer CX octets sur le heap -> BX = adresse
  Si heap plein : afficher message et sauter vers _SB_END_PROG.
  --------------------------------------------------------------------------

  Code ASM emis :
      _SB_ALLOC:
          MOV  BX, [_HEAP_PTR]      ; BX = ptr courant
          MOV  AX, BX
          ADD  AX, CX               ; AX = ptr apres alloc
          CMP  AX, [_HEAP_END]      ; depasse la fin ?
          JBE  @@ok
          ; OOM
          MOV  DX, OFFSET _SB_HEAP_OOM_MSG
          MOV  AH, 9
          INT  21h
          JMP  _SB_END_PROG
      @@ok:
          MOV  [_HEAP_PTR], AX      ; avancer le pointeur
          RET
  -------------------------------------------------------------------------- }

Procedure GenAllocRoutine;
Var lbl_ok : TString;
Begin
  EmitSep;
  EmitComment('_SB_ALLOC : allouer CX octets sur le heap -> BX = adresse');
  EmitSep;
  EmitLabel('_SB_ALLOC');
  lbl_ok := NewLabel;
  EmitI('MOV  BX, [_HEAP_PTR]');
  EmitI('MOV  AX, BX');
  EmitI('ADD  AX, CX');
  EmitI('CMP  AX, [_HEAP_END]');
  EmitI('JBE  ' + lbl_ok);
  EmitI('MOV  DX, OFFSET _SB_HEAP_OOM_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitLabel(lbl_ok);
  EmitI('MOV  [_HEAP_PTR], AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _SB_NEWSTR : creer un nouveau descripteur de chaine de longueur CX.
  Alloue 4 (desc) + CX + 1 (null) octets sur le heap.
  -> DI = adresse du descripteur alloue (ptr pointe juste apres le desc).

  Code ASM emis :
      _SB_NEWSTR:
          PUSH CX
          ADD  CX, 5        ; 4 desc + 1 null
          CALL _SB_ALLOC    ; BX = debut du bloc
          POP  CX
          ; Remplir le descripteur
          MOV  DI, BX
          MOV  AX, BX
          ADD  AX, 4        ; AX = adresse des donnees (apres le desc)
          MOV  [DI],   AX   ; ptr
          MOV  [DI+2], CX   ; len
          ; Mettre null apres les donnees
          PUSH DI
          MOV  DI, AX
          ADD  DI, CX
          MOV  BYTE PTR [DI], 0
          POP  DI
          RET
  -------------------------------------------------------------------------- }

Procedure GenNewStrRoutine;
Begin
  EmitSep;
  EmitComment('_SB_NEWSTR : allouer un descripteur pour CX chars -> DI');
  EmitSep;
  EmitLabel('_SB_NEWSTR');
  EmitI('PUSH CX');
  EmitI('ADD  CX, 5');
  EmitI('CALL _SB_ALLOC');
  EmitI('POP  CX');
  EmitI('MOV  DI, BX');
  EmitI('MOV  AX, BX');
  EmitI('ADD  AX, 4');
  EmitI('MOV  [DI],   AX');
  EmitI('MOV  [DI+2], CX');
  EmitI('PUSH DI');
  EmitI('MOV  DI, AX');
  EmitI('ADD  DI, CX');
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('POP  DI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _SB_COPYSTR : copier le contenu du descripteur SI vers DI.
  Alloue un nouveau buffer sur le heap si necessaire.

  Entree  : SI = ptr descripteur source, DI = ptr descripteur destination
  Logique :
      1. Lire len du source (CX = [SI+2])
      2. Appeler _SB_NEWSTR pour creer un nouveau desc -> DX = nouveau desc
      3. Copier CX octets de [SI].ptr vers [DX].ptr
      4. Mettre [DI] = [DX] (ecraser le descripteur dest)

  Code ASM emis :
      _SB_COPYSTR:
          PUSH SI
          PUSH DI
          MOV  CX, [SI+2]    ; len source
          PUSH CX
          PUSH SI
          CALL _SB_NEWSTR    ; DI = nouveau desc
          MOV  DX, DI        ; DX = nouveau desc
          POP  SI
          POP  CX
          ; Copier donnees
          MOV  SI, [SI]      ; SI = ptr donnees source
          MOV  DI, [DX]      ; DI = ptr donnees dest
          REP  MOVSB          ; copier CX octets
          ; Ecrire le nouveau desc dans la destination
          POP  DI
          MOV  AX, [DX]
          MOV  [DI],   AX
          MOV  AX, [DX+2]
          MOV  [DI+2], AX
          POP  SI
          RET
  -------------------------------------------------------------------------- }

Procedure GenCopyStrRoutine;
Begin
  EmitSep;
  EmitComment('_SB_COPYSTR : copier desc SI -> desc DI');
  EmitSep;
  EmitLabel('_SB_COPYSTR');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  EmitI('MOV  CX, [SI+2]');
  EmitI('PUSH CX');
  EmitI('PUSH SI');
  EmitI('CALL _SB_NEWSTR');
  EmitI('MOV  DX, DI');
  EmitI('POP  SI');
  EmitI('POP  CX');
  EmitI('PUSH SI');
  EmitI('MOV  SI, [SI]');
  EmitI('MOV  DI, [DX]');
  EmitI('REP  MOVSB');
  EmitI('POP  SI');
  EmitI('POP  DI');
  EmitI('MOV  AX, [DX]');
  EmitI('MOV  [DI],   AX');
  EmitI('MOV  AX, [DX+2]');
  EmitI('MOV  [DI+2], AX');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _SB_CONCATSTR : concatener desc DI et desc SI -> DX = nouveau desc.

  Logique :
      1. len_total = [DI+2] + [SI+2]
      2. _SB_NEWSTR(len_total) -> DX = desc resultat
      3. copier [DI+2] octets de [DI].ptr vers [DX].ptr
      4. copier [SI+2] octets de [SI].ptr vers [DX].ptr + [DI+2]
      5. mettre null final

  Code ASM emis :
      _SB_CONCATSTR:
          PUSH SI
          PUSH DI
          MOV  AX, [DI+2]    ; len1
          MOV  BX, [SI+2]    ; len2
          MOV  CX, AX
          ADD  CX, BX        ; len_total
          PUSH AX
          PUSH BX
          PUSH SI
          PUSH DI
          CALL _SB_NEWSTR    ; DI = nouveau desc
          MOV  DX, DI
          POP  DI
          POP  SI
          POP  BX            ; len2
          POP  AX            ; len1
          ; Copier partie 1
          PUSH SI
          MOV  SI, [DI]      ; ptr src1
          MOV  DI, [DX]      ; ptr dst
          MOV  CX, AX
          REP  MOVSB
          ; Copier partie 2
          POP  SI
          MOV  SI, [SI]      ; ptr src2
          MOV  CX, BX
          REP  MOVSB
          ; Null final
          MOV  BYTE PTR [DI], 0
          POP  DI
          POP  SI
          RET
  -------------------------------------------------------------------------- }

Procedure GenConcatStrRoutine;
Begin
  EmitSep;
  EmitComment('_SB_CONCATSTR : DI||SI -> DX = nouveau desc');
  EmitSep;
  EmitLabel('_SB_CONCATSTR');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  EmitI('MOV  AX, [DI+2]');
  EmitI('MOV  BX, [SI+2]');
  EmitI('MOV  CX, AX');
  EmitI('ADD  CX, BX');
  EmitI('PUSH AX');
  EmitI('PUSH BX');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  EmitI('CALL _SB_NEWSTR');
  EmitI('MOV  DX, DI');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('POP  BX');
  EmitI('POP  AX');
  EmitI('PUSH SI');
  EmitI('MOV  SI, [DI]');
  EmitI('MOV  DI, [DX]');
  EmitI('MOV  CX, AX');
  EmitI('REP  MOVSB');
  EmitI('POP  SI');
  EmitI('MOV  SI, [SI]');
  EmitI('MOV  CX, BX');
  EmitI('REP  MOVSB');
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenHeapOomMsg : emettre le message OOM dans le .DATA.
  (Appele depuis GenDataSegment, apres GenRuntimeBuffers.)
  -------------------------------------------------------------------------- }

Procedure GenHeapOomMsg;
Begin
  EmitComment('Message manque de memoire heap');
  EmitI('_SB_HEAP_OOM_MSG:');
  EmitI('  DB  ''SNOBOL86 : Heap plein (out of memory)'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenHeapRuntime : emettre toutes les routines de gestion heap dans .CODE.
  Appele par Compile en passe 2 (TODO 25).
  -------------------------------------------------------------------------- }

Procedure GenHeapRuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : gestion du heap dynamique ===');
  EmitSep;
  EmitBlank;
  GenInitHeap(opt_heap_size);
  GenAllocRoutine;
  GenNewStrRoutine;
  GenCopyStrRoutine;
  GenConcatStrRoutine;
End;

{ ============================================================================
  TODO 11 - RUNTIME : OPERATIONS SUR LES CHAINES
  ============================================================================

  Convention registres pour toutes les routines :
    DI = descripteur destination (ptr:WORD + len:WORD a offset 0 et 2)
    SI = descripteur source
    CX = longueur / compteur
    BX = tableau de traduction (pour _RT_REPLACE)
    AX = position 1-based (_RT_SUBSTR) ou char de remplissage (_RT_LPAD/_RT_RPAD)

  Prerequis : a l'entree du programme, ES doit etre initialise = DS
  (pour MOVSB/STOSB). Emis dans GenCodeSegHeader (PUSH DS; POP ES).

  Format descripteur (4 octets) :
      offset 0 : WORD ptr  <- adresse des donnees dans DS
      offset 2 : WORD len  <- longueur en octets

  Liste :
    _RT_STRLEN   : DI = desc -> CX = longueur
    _RT_STRNCPY  : SI = src data, DI = dst data, CX = nb -> copie brute
    _RT_STRCMP   : SI = desc1, DI = desc2 -> flags (ZF=egal, CF=SI<DI)
    _RT_SUBSTR   : SI = src, AX = pos(1-based), CX = len -> DI = desc
    _RT_DUPL     : SI = src, CX = count -> DI = desc
    _RT_REPLACE  : SI = src, BX = table[256] -> DI = desc
    _RT_TRIM     : SI = src -> DI = desc sans blancs en fin
    _RT_LPAD     : SI = src, CX = width, AL = fill -> DI = desc cadre gauche
    _RT_RPAD     : SI = src, CX = width, AL = fill -> DI = desc cadre droit
    _RT_REVERSE  : SI = src -> DI = desc inverse
    _RT_UPPER    : SI = src -> DI = desc en majuscules
    _RT_LOWER    : SI = src -> DI = desc en minuscules
  ============================================================================ }

{ --- _RT_STRLEN --- }
{ DI = descripteur -> CX = longueur de la chaine }
Procedure GenRtStrLen;
Begin
  EmitSep;
  EmitComment('_RT_STRLEN : CX <- longueur du descripteur DI');
  EmitSep;
  EmitLabel('_RT_STRLEN');
  EmitI('MOV  CX, [DI+2]');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_STRNCPY --- }
{ SI = ptr donnees source, DI = ptr donnees dest, CX = nb octets }
Procedure GenRtStrNCpy;
Var lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_STRNCPY : copier CX octets de DS:SI vers ES:DI (brut)');
  EmitSep;
  lbl_done := NewLabel;
  EmitLabel('_RT_STRNCPY');
  EmitI('JCXZ ' + lbl_done);
  EmitI('REP  MOVSB');
  EmitLabel(lbl_done);
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_STRCMP --- }
{ SI = desc1, DI = desc2 -> flags : ZF si egal, CF si SI < DI (lexicographique) }
Procedure GenRtStrCmp;
Var lbl_after_cmp, lbl_done_cmp, lbl_use_min : TString;
Begin
  EmitSep;
  EmitComment('_RT_STRCMP : comparer desc SI et desc DI -> flags CPU');
  EmitComment('  ZF=1 si egal, CF=1 si SI < DI lexicographiquement');
  EmitSep;
  lbl_use_min  := NewLabel;
  lbl_after_cmp := NewLabel;
  lbl_done_cmp := NewLabel;
  EmitLabel('_RT_STRCMP');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  EmitI('PUSH BX');
  EmitI('MOV  CX, [SI+2]         ; CX = len1');
  EmitI('MOV  BX, [DI+2]         ; BX = len2');
  EmitI('MOV  AX, CX             ; AX = len1 (sauvegarde pour comparer longueurs)');
  EmitI('CMP  CX, BX');
  EmitI('JBE  ' + lbl_use_min + '         ; utiliser min(len1,len2)');
  EmitI('MOV  CX, BX');
  EmitLabel(lbl_use_min);
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees1');
  EmitI('MOV  DI, [DI]           ; DI = ptr donnees2');
  EmitI('JCXZ ' + lbl_after_cmp);
  EmitI('REPE CMPSB              ; comparer octet par octet');
  EmitI('JNE  ' + lbl_done_cmp + '        ; difference trouvee -> flags deja positionnes');
  EmitLabel(lbl_after_cmp);
  EmitI('CMP  AX, BX             ; bytes egaux : comparer longueurs');
  EmitLabel(lbl_done_cmp);
  EmitI('POP  BX');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_SUBSTR --- }
{ SI = src_desc, AX = pos (1-based, >=1), CX = longueur voulue }
{ -> DI = nouveau descripteur ; si hors-bornes -> afficher erreur + jmp _SB_END_PROG }
Procedure GenRtSubStr;
Var lbl_ok1, lbl_len_ok, lbl_skip_data : TString;
Begin
  EmitSep;
  EmitComment('_RT_SUBSTR : extraire sous-chaine SI[AX..AX+CX-1] -> DI');
  EmitComment('  AX = position 1-based, CX = longueur. Clamp si trop long.');
  EmitSep;
  lbl_ok1      := NewLabel;
  lbl_len_ok   := NewLabel;
  lbl_skip_data := NewLabel;
  EmitLabel('_RT_SUBSTR');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  { Validation pos >= 1 }
  EmitI('CMP  AX, 1');
  EmitI('JAE  ' + lbl_ok1 + '            ; pos >= 1 ok');
  EmitI('MOV  DX, OFFSET _RT_RANGE_ERR_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitLabel(lbl_ok1);
  { Validation pos <= len }
  EmitI('MOV  BX, [SI+2]         ; BX = src_len');
  EmitI('CMP  AX, BX');
  EmitI('JBE  ' + lbl_len_ok);
  { Pos > len : retourner chaine vide plutot que crash (SNOBOL : FAIL) }
  EmitI('XOR  CX, CX             ; longueur = 0');
  EmitI('JMP  ' + lbl_skip_data);
  EmitLabel(lbl_len_ok);
  { Calculer chars disponibles depuis pos : dispo = src_len - (pos-1) }
  EmitI('MOV  DX, AX');
  EmitI('DEC  DX                 ; DX = pos - 1');
  EmitI('MOV  BX, [SI+2]');
  EmitI('SUB  BX, DX             ; BX = chars disponibles depuis pos');
  EmitI('CMP  CX, BX');
  EmitI('JBE  ' + lbl_skip_data + '      ; longueur ok');
  EmitI('MOV  CX, BX             ; clamp');
  EmitLabel(lbl_skip_data);
  { Allouer nouveau descripteur de longueur CX }
  EmitI('PUSH SI');
  EmitI('PUSH AX                 ; sauvegarder pos');
  EmitI('PUSH CX                 ; sauvegarder longueur');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('POP  CX                 ; longueur');
  EmitI('POP  AX                 ; pos');
  EmitI('POP  SI                 ; src_desc');
  { Copier les donnees }
  EmitI('PUSH DI                 ; sauvegarder desc resultat');
  EmitI('MOV  DI, [DI]           ; DI = ptr buffer dest');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('DEC  AX                 ; AX = pos - 1 (offset 0-based)');
  EmitI('ADD  SI, AX             ; SI = source + offset');
  EmitI('JCXZ ' + lbl_ok1 + '_end');
  EmitI('REP  MOVSB');
  EmitLabel(lbl_ok1 + '_end');
  EmitI('MOV  BYTE PTR [DI], 0   ; null garde-fou');
  EmitI('POP  DI                 ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_DUPL --- }
{ SI = src_desc, CX = count (nb de repetitions) -> DI = nouveau desc }
Procedure GenRtDupl;
Var lbl_loop, lbl_skip, lbl_end : TString;
Begin
  EmitSep;
  EmitComment('_RT_DUPL : SI repete CX fois -> DI = desc concatene');
  EmitSep;
  lbl_loop := NewLabel;
  lbl_skip := NewLabel;
  lbl_end  := NewLabel;
  EmitLabel('_RT_DUPL');
  EmitI('PUSH CX                 ; [1] sauvegarder count');
  EmitI('MOV  AX, [SI+2]         ; AX = src_len');
  EmitI('MUL  CX                 ; AX = src_len * count (16 bits, ignore overflow)');
  EmitI('PUSH SI                 ; [2] sauvegarder src_desc');
  EmitI('MOV  CX, AX             ; CX = longueur totale pour _SB_NEWSTR');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('MOV  BX, DI             ; BX = desc resultat (sauvegarder)');
  EmitI('MOV  DI, [BX]           ; DI = ptr buffer dest courant');
  EmitI('POP  SI                 ; [2] src_desc');
  EmitI('MOV  DX, [SI+2]         ; DX = src_len (fixe pendant la boucle)');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source (fixe)');
  EmitI('POP  CX                 ; [1] count');
  EmitLabel(lbl_loop);
  EmitI('JCXZ ' + lbl_end);
  EmitI('PUSH SI');
  EmitI('PUSH CX');
  EmitI('MOV  CX, DX             ; CX = src_len pour MOVSB');
  EmitI('JCXZ ' + lbl_skip);
  EmitI('REP  MOVSB              ; copier src vers DI (DI avance)');
  EmitLabel(lbl_skip);
  EmitI('POP  CX');
  EmitI('POP  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_loop);
  EmitLabel(lbl_end);
  EmitI('MOV  BYTE PTR [DI], 0   ; null garde-fou');
  EmitI('MOV  DI, BX             ; DI = desc resultat');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_REPLACE --- }
{ SI = src_desc, BX = ptr table de traduction [256 octets] -> DI = desc traduit }
{ Chaque caractere c de src est remplace par table[c] (XLAT). }
Procedure GenRtReplace;
Var lbl_loop, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_REPLACE : transliterer SI via table[256] BX -> DI');
  EmitSep;
  lbl_loop := NewLabel;
  lbl_done := NewLabel;
  EmitLabel('_RT_REPLACE');
  EmitI('PUSH BX');
  EmitI('PUSH SI');
  EmitI('MOV  CX, [SI+2]         ; CX = longueur');
  EmitI('PUSH CX                 ; [1] sauvegarder longueur');
  EmitI('PUSH BX                 ; [2] sauvegarder table');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('MOV  DX, DI             ; DX = desc resultat');
  EmitI('MOV  DI, [DX]           ; DI = ptr buffer dest');
  EmitI('POP  BX                 ; [2] table');
  EmitI('POP  CX                 ; [1] longueur');
  EmitI('POP  SI                 ; src_desc');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('JCXZ ' + lbl_done);
  EmitLabel(lbl_loop);
  EmitI('MOV  AL, [SI]           ; lire char source');
  EmitI('INC  SI');
  EmitI('XLAT                    ; AL <- BX[AL] (transliteration)');
  EmitI('MOV  [DI], AL           ; ecrire char traduit');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_loop);
  EmitLabel(lbl_done);
  EmitI('MOV  BYTE PTR [DI], 0   ; null garde-fou');
  EmitI('MOV  DI, DX             ; DI = desc resultat');
  EmitI('POP  SI');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_TRIM --- }
{ SI = src_desc -> DI = desc sans espaces en fin de chaine }
Procedure GenRtTrim;
Var lbl_loop, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_TRIM : supprimer les blancs en fin de chaine SI -> DI');
  EmitSep;
  lbl_loop := NewLabel;
  lbl_done := NewLabel;
  EmitLabel('_RT_TRIM');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  BX, [SI]           ; BX = ptr donnees');
  EmitI('MOV  CX, [SI+2]         ; CX = longueur initiale');
  { Reculer depuis la fin tant que char = 32 (espace) }
  EmitI('JCXZ ' + lbl_done + '           ; chaine vide -> rien a faire');
  EmitLabel(lbl_loop);
  EmitI('MOV  DX, BX');
  EmitI('ADD  DX, CX');
  EmitI('DEC  DX                 ; DX = adresse du dernier char');
  EmitI('CMP  BYTE PTR [DX], 32  ; est-ce un espace ?');
  EmitI('JNE  ' + lbl_done);
  EmitI('DEC  CX');
  EmitI('JCXZ ' + lbl_done);
  EmitI('JMP  ' + lbl_loop);
  EmitLabel(lbl_done);
  { Allouer un nouveau descripteur de longueur CX }
  EmitI('PUSH SI');
  EmitI('PUSH CX                 ; [1] longueur trimee');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('POP  CX                 ; [1]');
  EmitI('POP  SI                 ; src_desc');
  EmitI('PUSH DI                 ; sauvegarder desc result');
  EmitI('MOV  DI, [DI]           ; DI = buffer dest');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('JCXZ ' + lbl_done + '_copy');
  EmitI('REP  MOVSB');
  EmitLabel(lbl_done + '_copy');
  EmitI('MOV  BYTE PTR [DI], 0   ; null');
  EmitI('POP  DI                 ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_LPAD --- }
{ SI = src_desc, CX = width, AL = fill_char -> DI = desc cadre a gauche }
{ Si len(src) >= width : copier tel quel. Sinon : (width-len) fois fill + src. }
Procedure GenRtLPad;
Var lbl_no_pad, lbl_done_pad, lbl_fill_loop : TString;
Begin
  EmitSep;
  EmitComment('_RT_LPAD : cadrer SI a gauche sur CX chars (fill=AL) -> DI');
  EmitSep;
  lbl_no_pad    := NewLabel;
  lbl_done_pad  := NewLabel;
  lbl_fill_loop := NewLabel;
  EmitLabel('_RT_LPAD');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  BX, [SI+2]         ; BX = src_len');
  EmitI('CMP  CX, BX');
  EmitI('JBE  ' + lbl_no_pad + '         ; width <= len : pas de remplissage');
  { Calculer nb de chars de remplissage }
  EmitI('MOV  DX, CX');
  EmitI('SUB  DX, BX             ; DX = width - src_len (nb fill chars)');
  { Allouer desc de longueur CX (= width) }
  EmitI('PUSH SI');
  EmitI('PUSH AX                 ; [1] fill_char');
  EmitI('PUSH BX                 ; [2] src_len');
  EmitI('PUSH DX                 ; [3] nb fill chars');
  EmitI('CALL _SB_NEWSTR         ; DI = desc de longueur width');
  EmitI('MOV  BX, DI             ; BX = desc result');
  EmitI('MOV  DI, [BX]           ; DI = ptr buffer');
  EmitI('POP  DX                 ; [3] nb fill chars');
  EmitI('POP  CX                 ; [2] src_len');
  EmitI('POP  AX                 ; [1] fill_char (en AL)');
  EmitI('POP  SI                 ; src_desc');
  { Ecrire DX fois le fill_char }
  EmitI('PUSH CX                 ; sauvegarder src_len');
  EmitI('MOV  CX, DX');
  EmitLabel(lbl_fill_loop);
  EmitI('JCXZ ' + lbl_done_pad);
  EmitI('MOV  [DI], AL');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_fill_loop);
  EmitLabel(lbl_done_pad);
  { Copier les donnees source }
  EmitI('POP  CX                 ; src_len');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('JCXZ ' + lbl_no_pad + '_end');
  EmitI('REP  MOVSB');
  EmitLabel(lbl_no_pad + '_end');
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('MOV  DI, BX             ; DI = desc result');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitLabel(lbl_no_pad);
  { width <= src_len : copier simplement (COPYSTR) }
  EmitI('CALL _SB_COPYSTR');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_RPAD --- }
{ SI = src_desc, CX = width, AL = fill_char -> DI = desc cadre a droite }
{ Si len(src) >= width : copier tel quel. Sinon : src + (width-len) fois fill. }
Procedure GenRtRPad;
Var lbl_no_pad, lbl_fill_loop, lbl_skip_src : TString;
Begin
  EmitSep;
  EmitComment('_RT_RPAD : cadrer SI a droite sur CX chars (fill=AL) -> DI');
  EmitSep;
  lbl_no_pad    := NewLabel;
  lbl_fill_loop := NewLabel;
  lbl_skip_src  := NewLabel;
  EmitLabel('_RT_RPAD');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  BX, [SI+2]         ; BX = src_len');
  EmitI('CMP  CX, BX');
  EmitI('JBE  ' + lbl_no_pad + '         ; pas de remplissage');
  EmitI('MOV  DX, CX');
  EmitI('SUB  DX, BX             ; DX = nb fill chars');
  { Allouer desc de longueur CX (=width) }
  EmitI('PUSH SI');
  EmitI('PUSH AX                 ; [1] fill_char');
  EmitI('PUSH BX                 ; [2] src_len');
  EmitI('PUSH DX                 ; [3] nb fill');
  EmitI('CALL _SB_NEWSTR         ; DI = desc width chars');
  EmitI('MOV  BX, DI             ; BX = desc result');
  EmitI('MOV  DI, [BX]           ; DI = ptr buffer');
  EmitI('POP  DX                 ; [3] nb fill');
  EmitI('POP  CX                 ; [2] src_len');
  EmitI('POP  AX                 ; [1] fill_char');
  EmitI('POP  SI                 ; src_desc');
  { Copier les donnees source }
  EmitI('PUSH DX                 ; sauvegarder nb fill');
  EmitI('MOV  SI, [SI]');
  EmitI('JCXZ ' + lbl_skip_src);
  EmitI('REP  MOVSB');
  EmitLabel(lbl_skip_src);
  { Ecrire nb fill chars }
  EmitI('POP  CX                 ; nb fill');
  EmitLabel(lbl_fill_loop);
  EmitI('JCXZ ' + lbl_no_pad + '_end');
  EmitI('MOV  [DI], AL');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_fill_loop);
  EmitLabel(lbl_no_pad + '_end');
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('MOV  DI, BX');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitLabel(lbl_no_pad);
  EmitI('CALL _SB_COPYSTR');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_REVERSE --- }
{ SI = src_desc -> DI = desc avec les octets en ordre inverse }
Procedure GenRtReverse;
Var lbl_copy, lbl_rev_loop, lbl_skip : TString;
Begin
  EmitSep;
  EmitComment('_RT_REVERSE : inverser les octets de SI -> DI');
  EmitSep;
  lbl_copy     := NewLabel;
  lbl_rev_loop := NewLabel;
  lbl_skip     := NewLabel;
  EmitLabel('_RT_REVERSE');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  CX, [SI+2]         ; CX = longueur');
  EmitI('PUSH SI');
  EmitI('PUSH CX                 ; [1]');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('POP  CX                 ; [1]');
  EmitI('POP  SI                 ; src_desc');
  EmitI('PUSH DI                 ; sauvegarder desc result');
  EmitI('MOV  BX, [DI]           ; BX = ptr buffer dest');
  EmitI('MOV  DX, [SI]           ; DX = ptr donnees source');
  EmitI('JCXZ ' + lbl_skip);
  { Lire depuis la fin de la source et ecrire dans BX[0..CX-1] }
  EmitI('ADD  DX, CX');
  EmitI('DEC  DX                 ; DX pointe sur le dernier char source');
  EmitI('MOV  DI, BX             ; DI = debut buffer dest');
  EmitLabel(lbl_rev_loop);
  EmitI('MOV  AL, [DX]           ; lire char depuis la fin');
  EmitI('MOV  [DI], AL           ; ecrire au debut dest');
  EmitI('INC  DI');
  EmitI('DEC  DX');
  EmitI('LOOP ' + lbl_rev_loop);
  EmitLabel(lbl_skip);
  EmitI('MOV  BYTE PTR [BX+CX], 0 ; null (CX=0 ici, correct)');
  EmitI('POP  DI                 ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_UPPER --- }
{ SI = src_desc -> DI = desc converti en majuscules }
Procedure GenRtUpper;
Var lbl_loop, lbl_not_lower, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_UPPER : convertir SI en majuscules -> DI');
  EmitSep;
  lbl_loop      := NewLabel;
  lbl_not_lower := NewLabel;
  lbl_done      := NewLabel;
  EmitLabel('_RT_UPPER');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  CX, [SI+2]');
  EmitI('PUSH SI');
  EmitI('PUSH CX                 ; [1]');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('MOV  DX, DI             ; DX = desc result');
  EmitI('MOV  DI, [DX]           ; DI = buffer dest');
  EmitI('POP  CX                 ; [1]');
  EmitI('POP  SI                 ; src_desc');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('JCXZ ' + lbl_done);
  EmitLabel(lbl_loop);
  EmitI('MOV  AL, [SI]');
  EmitI('INC  SI');
  EmitI('CMP  AL, 61h            ; ''a''');
  EmitI('JB   ' + lbl_not_lower);
  EmitI('CMP  AL, 7Ah            ; ''z''');
  EmitI('JA   ' + lbl_not_lower);
  EmitI('AND  AL, 0DFh           ; minuscule -> majuscule');
  EmitLabel(lbl_not_lower);
  EmitI('MOV  [DI], AL');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_loop);
  EmitLabel(lbl_done);
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('MOV  DI, DX             ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- _RT_LOWER --- }
{ SI = src_desc -> DI = desc converti en minuscules }
Procedure GenRtLower;
Var lbl_loop, lbl_not_upper, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_LOWER : convertir SI en minuscules -> DI');
  EmitSep;
  lbl_loop      := NewLabel;
  lbl_not_upper := NewLabel;
  lbl_done      := NewLabel;
  EmitLabel('_RT_LOWER');
  EmitI('PUSH BX');
  EmitI('PUSH DX');
  EmitI('MOV  CX, [SI+2]');
  EmitI('PUSH SI');
  EmitI('PUSH CX                 ; [1]');
  EmitI('CALL _SB_NEWSTR         ; DI = nouveau desc');
  EmitI('MOV  DX, DI             ; DX = desc result');
  EmitI('MOV  DI, [DX]           ; DI = buffer dest');
  EmitI('POP  CX                 ; [1]');
  EmitI('POP  SI                 ; src_desc');
  EmitI('MOV  SI, [SI]           ; SI = ptr donnees source');
  EmitI('JCXZ ' + lbl_done);
  EmitLabel(lbl_loop);
  EmitI('MOV  AL, [SI]');
  EmitI('INC  SI');
  EmitI('CMP  AL, 41h            ; ''A''');
  EmitI('JB   ' + lbl_not_upper);
  EmitI('CMP  AL, 5Ah            ; ''Z''');
  EmitI('JA   ' + lbl_not_upper);
  EmitI('OR   AL, 20h            ; majuscule -> minuscule');
  EmitLabel(lbl_not_upper);
  EmitI('MOV  [DI], AL');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_loop);
  EmitLabel(lbl_done);
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('MOV  DI, DX             ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --- Message d'erreur hors-bornes pour SUBSTR --- }
{ A emettre dans le segment .DATA (depuis GenDataSegment). }
Procedure GenRangeErrMsg;
Begin
  EmitComment('Message erreur acces hors-bornes (SUBSTR/DUPL)');
  EmitI('_RT_RANGE_ERR_MSG:');
  EmitI('  DB  ''SNOBOL86 : acces hors-bornes de chaine'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStringRuntime : emettre toutes les routines de manipulation de chaines.
  Appelee depuis l'orchestrateur de passe 2 (TODO 25).
  -------------------------------------------------------------------------- }
Procedure GenStringRuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : operations sur les chaines ===');
  EmitSep;
  EmitBlank;
  GenRtStrLen;
  GenRtStrNCpy;
  GenRtStrCmp;
  GenRtSubStr;
  GenRtDupl;
  GenRtReplace;
  GenRtTrim;
  GenRtLPad;
  GenRtRPad;
  GenRtReverse;
  GenRtUpper;
  GenRtLower;
End;

{ ============================================================================
  TODO 12 - RUNTIME : CONVERSIONS ET ARITHMETIQUE
  ============================================================================

  Conventions registres :
    _RT_STR2INT  : SI = ptr descripteur -> AX = entier signe
    _RT_INT2STR  : AX = entier signe    -> DI = nouveau descripteur
    _RT_STR2REAL : SI = ptr descripteur -> DX:AX = reel 16.16 (DX=partie entiere)
    _RT_REAL2STR : DX:AX = reel 16.16   -> DI = nouveau descripteur

    Arithmetique entiere (operandes dans AX, BX ; resultat dans AX) :
      _RT_IADD : AX + BX -> AX
      _RT_ISUB : AX - BX -> AX
      _RT_IMUL : AX * BX -> AX (partie basse signee)
      _RT_IDIV : AX / BX -> AX (quotient entier signe; erreur sur div/0)

    Arithmetique reelle 16.16 (op1=DX:AX, op2=CX:BX ; resultat DX:AX) :
      _RT_RADD, _RT_RSUB, _RT_RMUL, _RT_RDIV
      Note : DX = partie entiere signee, AX = partie fractionnaire 0..65535

    Comparaisons (positionnent flags CPU pour Jxx subsequents) :
      _RT_ICOMPARE : CMP AX, BX  (entiers signes)
      _RT_RCOMPARE : compare DX:AX vs CX:BX (reels 16.16)

  Format 16.16 : valeur = DX + AX/65536
    Exemples : 3.5 -> DX=3, AX=32768 (0.5 * 65536)
               -1   -> DX=0FFFFh, AX=0
  ============================================================================ }

{ --------------------------------------------------------------------------
  _RT_STR2INT : convertir la chaine ASCII du descripteur SI en entier signe.
  Entree  : SI = ptr descripteur source
  Sortie  : AX = valeur entiere
  Transforme : espaces de tete ignores, signe optionnel +/-,
               s'arrete au premier caractere non decimal.
  -------------------------------------------------------------------------- }
Procedure GenRtStr2Int;
Var lbl_sp, lbl_sign, lbl_plus, lbl_loop, lbl_done, lbl_neg, lbl_ret : TString;
Begin
  EmitSep;
  EmitComment('_RT_STR2INT : desc SI -> AX entier signe');
  EmitSep;
  lbl_sp   := NewLabel;
  lbl_sign := NewLabel;
  lbl_plus := NewLabel;
  lbl_loop := NewLabel;
  lbl_done := NewLabel;
  lbl_neg  := NewLabel;
  lbl_ret  := NewLabel;
  EmitLabel('_RT_STR2INT');
  EmitI('PUSH SI');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitI('MOV  CX, [SI+2]           ; CX = longueur');
  EmitI('MOV  SI, [SI]             ; SI = ptr donnees');
  EmitI('XOR  AX, AX               ; accumulateur');
  EmitI('XOR  BX, BX               ; BX = signe (0=+, 1=-)');
  EmitI('JCXZ ' + lbl_done + '            ; chaine vide -> 0');
  { Ignorer les espaces en tete }
  EmitLabel(lbl_sp);
  EmitI('CMP  BYTE PTR [SI], 32');
  EmitI('JNE  ' + lbl_sign);
  EmitI('INC  SI');
  EmitI('LOOP ' + lbl_sp);
  EmitI('JMP  ' + lbl_done);
  { Lire le signe eventuel }
  EmitLabel(lbl_sign);
  EmitI('CMP  BYTE PTR [SI], 2Dh   ; ''-''');
  EmitI('JNE  ' + lbl_plus);
  EmitI('MOV  BX, 1');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_loop);
  EmitLabel(lbl_plus);
  EmitI('CMP  BYTE PTR [SI], 2Bh   ; ''+''');
  EmitI('JNE  ' + lbl_loop);
  EmitI('INC  SI');
  EmitI('DEC  CX');
  { Boucle de conversion }
  EmitLabel(lbl_loop);
  EmitI('JCXZ ' + lbl_done);
  EmitI('MOV  DL, [SI]             ; lire char');
  EmitI('SUB  DL, 30h              ; ''0'' = 30h');
  EmitI('JB   ' + lbl_done + '            ; < ''0'' -> stop');
  EmitI('CMP  DL, 9');
  EmitI('JA   ' + lbl_done + '            ; > ''9'' -> stop');
  EmitI('PUSH DX                   ; sauvegarder digit');
  EmitI('MOV  DX, 10');
  EmitI('MUL  DX                   ; DX:AX = AX * 10');
  EmitI('POP  DX');
  EmitI('ADD  AX, DX               ; AX += digit');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_loop);
  EmitLabel(lbl_done);
  EmitI('CMP  BX, 0');
  EmitI('JE   ' + lbl_ret);
  EmitI('NEG  AX                   ; appliquer le signe negatif');
  EmitLabel(lbl_ret);
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_INT2STR : convertir l'entier signe AX en descripteur de chaine.
  Entree  : AX = valeur entiere signee
  Sortie  : DI = nouveau descripteur contenant la representation ASCII
  Utilise : _SB_NUMBUF (12 octets) comme tampon temporaire, puis _SB_NEWSTR.
  -------------------------------------------------------------------------- }
Procedure GenRtInt2Str;
Var lbl_pos, lbl_div_loop, lbl_store_loop, lbl_done_copy : TString;
Begin
  EmitSep;
  EmitComment('_RT_INT2STR : AX entier -> DI descripteur chaine');
  EmitSep;
  lbl_pos        := NewLabel;
  lbl_div_loop   := NewLabel;
  lbl_store_loop := NewLabel;
  lbl_done_copy  := NewLabel;
  EmitLabel('_RT_INT2STR');
  EmitI('PUSH AX');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH SI');
  EmitI('PUSH DX');
  { Gestion du signe }
  EmitI('XOR  BX, BX               ; BX = signe');
  EmitI('CMP  AX, 0');
  EmitI('JGE  ' + lbl_pos);
  EmitI('NEG  AX');
  EmitI('MOV  BX, 1');
  EmitLabel(lbl_pos);
  { Construire les chiffres en sens inverse dans _SB_NUMBUF }
  EmitI('MOV  SI, OFFSET _SB_NUMBUF + 11 ; ptr fin de buffer');
  EmitI('MOV  BYTE PTR [SI], 0      ; null guard');
  EmitI('MOV  CX, 0                 ; compteur chars');
  EmitI('MOV  DX, 10');
  EmitLabel(lbl_div_loop);
  EmitI('XOR  DX, DX');
  EmitI('MOV  DX, 10');
  EmitI('DIV  DX                    ; AX = quotient, DX = reste (digit)');
  EmitI('ADD  DL, 30h               ; digit -> ASCII');
  EmitI('DEC  SI');
  EmitI('MOV  [SI], DL              ; ecrire dans buffer (droite vers gauche)');
  EmitI('INC  CX');
  EmitI('CMP  AX, 0');
  EmitI('JNE  ' + lbl_div_loop);
  { Ajouter le signe si negatif }
  EmitI('CMP  BX, 0');
  EmitI('JE   ' + lbl_store_loop);
  EmitI('DEC  SI');
  EmitI('MOV  BYTE PTR [SI], 2Dh   ; ''-''');
  EmitI('INC  CX');
  { Allouer un nouveau descripteur de longueur CX }
  EmitLabel(lbl_store_loop);
  EmitI('PUSH SI                    ; [1] ptr debut chaine dans NUMBUF');
  EmitI('PUSH CX                    ; [2] longueur');
  EmitI('CALL _SB_NEWSTR            ; DI = nouveau desc');
  EmitI('POP  CX                    ; [2]');
  EmitI('POP  SI                    ; [1] source');
  { Copier de NUMBUF vers le buffer du nouveau desc }
  EmitI('PUSH DI                    ; sauvegarder desc result');
  EmitI('MOV  DI, [DI]             ; DI = ptr buffer dest');
  EmitI('JCXZ ' + lbl_done_copy);
  EmitI('REP  MOVSB');
  EmitLabel(lbl_done_copy);
  EmitI('MOV  BYTE PTR [DI], 0');
  EmitI('POP  DI                    ; DI = desc resultat');
  EmitI('POP  DX');
  EmitI('POP  SI');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('POP  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_STR2REAL : convertir la chaine descripteur SI en reel 16.16 (DX:AX).
  Entree  : SI = ptr descripteur
  Sortie  : DX = partie entiere signee, AX = partie fractionnaire (0..65535)
  Algorithme :
    1. Parser la partie entiere -> DX
    2. Si '.' rencontre, parser la partie decimale :
       chaque chiffre d apres le point contribue : AX += d * (65536/10^pos)
  Note : arrondi effectue a la precision disponible (1/65536 ~ 0.0000153).
  -------------------------------------------------------------------------- }
Procedure GenRtStr2Real;
Var lbl_sp, lbl_sign, lbl_sign_plus, lbl_int_loop, lbl_check_dot,
    lbl_frac_loop, lbl_frac_char, lbl_done_frac,
    lbl_done, lbl_neg, lbl_ret : TString;
Begin
  EmitSep;
  EmitComment('_RT_STR2REAL : desc SI -> DX:AX reel 16.16');
  EmitSep;
  lbl_sp        := NewLabel;
  lbl_sign      := NewLabel;
  lbl_sign_plus := NewLabel;
  lbl_int_loop  := NewLabel;
  lbl_check_dot := NewLabel;
  lbl_frac_loop := NewLabel;
  lbl_frac_char := NewLabel;
  lbl_done_frac := NewLabel;
  lbl_done      := NewLabel;
  lbl_neg       := NewLabel;
  lbl_ret       := NewLabel;
  EmitLabel('_RT_STR2REAL');
  EmitI('PUSH SI');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('MOV  CX, [SI+2]           ; CX = longueur');
  EmitI('MOV  SI, [SI]             ; SI = ptr donnees');
  EmitI('XOR  DX, DX               ; DX = partie entiere');
  EmitI('XOR  AX, AX               ; AX = partie fractionnaire');
  EmitI('XOR  BX, BX               ; BX = signe');
  EmitI('JCXZ ' + lbl_done);
  { Ignorer espaces en tete }
  EmitLabel(lbl_sp);
  EmitI('CMP  BYTE PTR [SI], 32');
  EmitI('JNE  ' + lbl_sign);
  EmitI('INC  SI');
  EmitI('LOOP ' + lbl_sp);
  EmitI('JMP  ' + lbl_done);
  { Signe }
  EmitLabel(lbl_sign);
  EmitI('CMP  BYTE PTR [SI], 2Dh');
  EmitI('JNE  ' + lbl_sign_plus);
  EmitI('MOV  BX, 1');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_int_loop);
  EmitLabel(lbl_sign_plus);
  EmitI('CMP  BYTE PTR [SI], 2Bh');
  EmitI('JNE  ' + lbl_int_loop);
  EmitI('INC  SI');
  EmitI('DEC  CX');
  { Partie entiere }
  EmitLabel(lbl_int_loop);
  EmitI('JCXZ ' + lbl_done);
  EmitI('CMP  BYTE PTR [SI], 2Eh   ; ''.''');
  EmitI('JE   ' + lbl_check_dot);
  EmitI('MOV  AL, [SI]');
  EmitI('SUB  AL, 30h');
  EmitI('JB   ' + lbl_done);
  EmitI('CMP  AL, 9');
  EmitI('JA   ' + lbl_done);
  EmitI('PUSH AX');
  EmitI('PUSH CX');
  EmitI('MOV  AX, DX');
  EmitI('MOV  CX, 10');
  EmitI('MUL  CX                   ; DX:AX = DX*10');
  EmitI('MOV  DX, AX               ; DX = partie entiere * 10');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('ADD  DX, AX               ; DX += digit');
  EmitI('XOR  AX, AX               ; remettre AX=0 (frac)');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_int_loop);
  { Partie fractionnaire }
  EmitLabel(lbl_check_dot);
  EmitI('INC  SI');
  EmitI('DEC  CX');
  { Diviseur initial pour la fraction : 65536/10 = 6553 (arrondi) }
  EmitI('PUSH DX                   ; [1] sauvegarder partie entiere');
  EmitI('MOV  DX, 6553             ; DX = poids du 1er chiffre decimal (/65536)');
  EmitI('XOR  AX, AX               ; AX = accumulateur fraction');
  EmitLabel(lbl_frac_loop);
  EmitI('JCXZ ' + lbl_done_frac);
  EmitI('CMP  DX, 0                ; poids trop petit ?');
  EmitI('JE   ' + lbl_done_frac);
  EmitLabel(lbl_frac_char);
  EmitI('MOV  BL, [SI]');
  EmitI('SUB  BL, 30h');
  EmitI('JB   ' + lbl_done_frac);
  EmitI('CMP  BL, 9');
  EmitI('JA   ' + lbl_done_frac);
  EmitI('PUSH AX');
  EmitI('PUSH CX');
  EmitI('MOV  AX, DX               ; AX = poids courant');
  EmitI('XOR  BH, BH');
  EmitI('MUL  BX                   ; DX:AX = poids * digit');
  EmitI('XCHG AX, DX               ; DX = resultat high = contribution fraction');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('ADD  AX, DX               ; ajouter contribution');
  EmitI('PUSH AX');
  EmitI('MOV  AX, DX');
  EmitI('XOR  DX, DX');
  EmitI('MOV  BX, 10');
  EmitI('DIV  BX                   ; poids /= 10');
  EmitI('MOV  DX, AX               ; DX = nouveau poids');
  EmitI('POP  AX');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_frac_loop);
  EmitLabel(lbl_done_frac);
  EmitI('PUSH AX                   ; [2] sauvegarder frac');
  EmitI('POP  AX');
  EmitI('POP  DX                   ; [1] restaurer partie entiere');
  EmitI('PUSH AX                   ; [3] frac -> stack');
  { Appliquer signe }
  EmitI('CMP  BX, 0');
  EmitI('JE   ' + lbl_ret);
  EmitI('NEG  DX');
  EmitI('JMP  ' + lbl_ret);
  EmitLabel(lbl_done);
  EmitI('CMP  BX, 0');
  EmitI('JE   ' + lbl_ret);
  EmitI('NEG  DX');
  EmitLabel(lbl_ret);
  EmitI('POP  AX                   ; [3] restaurer frac dans AX');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_REAL2STR : convertir le reel 16.16 (DX:AX) en descripteur de chaine.
  Entree  : DX = partie entiere signee, AX = partie fractionnaire (0..65535)
  Sortie  : DI = nouveau descripteur ASCII  (ex: "3.14159")
  Algorithme : convertir DX avec _RT_INT2STR, ajouter '.', puis extraire
               6 chiffres decimaux de la fraction par multiplications repetees.
  -------------------------------------------------------------------------- }
Procedure GenRtReal2Str;
Var lbl_pos, lbl_frac_loop, lbl_frac_done, lbl_copy_int, lbl_copy_done,
    lbl_copy_frac, lbl_frac_copy_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_REAL2STR : DX:AX reel 16.16 -> DI descripteur chaine');
  EmitSep;
  lbl_pos           := NewLabel;
  lbl_frac_loop     := NewLabel;
  lbl_frac_done     := NewLabel;
  lbl_copy_int      := NewLabel;
  lbl_copy_done     := NewLabel;
  lbl_copy_frac     := NewLabel;
  lbl_frac_copy_done := NewLabel;
  EmitLabel('_RT_REAL2STR');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH SI');
  { Convertir la partie entiere -> chaine dans NUMBUF via _RT_INT2STR }
  EmitI('PUSH AX                   ; [1] sauvegarder partie frac');
  EmitI('MOV  AX, DX               ; AX = partie entiere');
  EmitI('CALL _RT_INT2STR          ; DI = desc chaine int');
  EmitI('MOV  SI, DI               ; SI = desc entier');
  EmitI('POP  AX                   ; [1] restaurer frac');
  { Construire les 6 chiffres decimaux dans un tampon sur la pile }
  EmitI('PUSH BP');
  EmitI('MOV  BP, SP');
  EmitI('SUB  SP, 8                 ; 6 chiffres + ''.'' + null');
  EmitI('MOV  BYTE PTR [BP-1], 2Eh ; ''.''');
  EmitI('MOV  CX, 6                 ; 6 chiffres decimaux');
  EmitI('MOV  BX, BP');
  EmitI('SUB  BX, 2                 ; BX = ptr vers 1er chiffre decimal');
  EmitLabel(lbl_frac_loop);
  EmitI('JCXZ ' + lbl_frac_done);
  EmitI('MOV  DX, 10');
  EmitI('MUL  DX                    ; DX:AX = frac * 10');
  EmitI('PUSH DX');
  EmitI('ADD  DL, 30h               ; DX = digit ASCII');
  EmitI('MOV  [BX], DL');
  EmitI('DEC  BX');
  EmitI('POP  DX');
  EmitI('XCHG AX, DX               ; AX = reste fractionnaire');
  EmitI('XOR  DX, DX');
  EmitI('LOOP ' + lbl_frac_loop);
  EmitLabel(lbl_frac_done);
  { Longueur totale = len(int) + 1 ('.') + 6 = len(int) + 7 }
  EmitI('MOV  CX, [SI+2]           ; CX = longueur partie entiere');
  EmitI('ADD  CX, 7                 ; + 1 point + 6 chiffres');
  EmitI('PUSH SI                    ; [2] desc entier');
  EmitI('PUSH AX                    ; [3] (inutilise)');
  EmitI('CALL _SB_NEWSTR            ; DI = nouveau desc total');
  EmitI('POP  AX');
  EmitI('POP  SI                    ; [2]');
  { Copier partie entiere }
  EmitI('PUSH DI                    ; [4] sauvegarder desc result');
  EmitI('MOV  DI, [DI]             ; DI = ptr buffer dest');
  EmitI('MOV  CX, [SI+2]');
  EmitI('MOV  SI, [SI]');
  EmitI('JCXZ ' + lbl_copy_done);
  EmitI('REP  MOVSB');
  EmitLabel(lbl_copy_done);
  { Copier '.' + 6 chiffres depuis la pile (BX+2..BX+8) }
  EmitI('MOV  BYTE PTR [DI], 2Eh   ; ''.''');
  EmitI('INC  DI');
  { Les chiffres ont ete ecrits de droite a gauche dans [BP-2..BP-7] }
  { Ils sont en ordre inverse : lire de BP-7 a BP-2 }
  EmitI('MOV  SI, BX');
  EmitI('INC  SI                    ; SI = BP-7, dernier chiffre ecrit = 1er decimal');
  EmitI('MOV  CX, 6');
  EmitLabel(lbl_copy_frac);
  EmitI('JCXZ ' + lbl_frac_copy_done);
  EmitI('MOV  AL, [SI]');
  EmitI('MOV  [DI], AL');
  EmitI('INC  SI');
  EmitI('INC  DI');
  EmitI('LOOP ' + lbl_copy_frac);
  EmitLabel(lbl_frac_copy_done);
  EmitI('MOV  BYTE PTR [DI], 0     ; null garde-fou');
  EmitI('POP  DI                    ; [4] DI = desc resultat');
  EmitI('ADD  SP, 8                 ; liberer pile');
  EmitI('POP  BP');
  EmitI('POP  SI');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Arithmetique entiere : _RT_IADD, _RT_ISUB, _RT_IMUL, _RT_IDIV
  Entree : AX = operande 1, BX = operande 2
  Sortie : AX = resultat
  -------------------------------------------------------------------------- }
Procedure GenRtIAdd;
Begin
  EmitSep;
  EmitComment('_RT_IADD : AX + BX -> AX');
  EmitSep;
  EmitLabel('_RT_IADD');
  EmitI('ADD  AX, BX');
  EmitI('RET');
  EmitBlank;
End;

Procedure GenRtISub;
Begin
  EmitSep;
  EmitComment('_RT_ISUB : AX - BX -> AX');
  EmitSep;
  EmitLabel('_RT_ISUB');
  EmitI('SUB  AX, BX');
  EmitI('RET');
  EmitBlank;
End;

Procedure GenRtIMul;
Begin
  EmitSep;
  EmitComment('_RT_IMUL : AX * BX -> AX (signe, partie basse)');
  EmitSep;
  EmitLabel('_RT_IMUL');
  EmitI('IMUL BX                   ; DX:AX = AX * BX (signe)');
  EmitI('RET                       ; AX = partie basse');
  EmitBlank;
End;

Procedure GenRtIDiv;
Var lbl_ok : TString;
Begin
  EmitSep;
  EmitComment('_RT_IDIV : AX / BX -> AX (quotient signe). Erreur sur div/0.');
  EmitSep;
  lbl_ok := NewLabel;
  EmitLabel('_RT_IDIV');
  EmitI('CMP  BX, 0');
  EmitI('JNE  ' + lbl_ok);
  EmitI('MOV  DX, OFFSET _RT_DIVZERO_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitLabel(lbl_ok);
  EmitI('CWD                        ; signe-etendre AX -> DX:AX');
  EmitI('IDIV BX                    ; AX = quotient, DX = reste');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Arithmetique reelle 16.16 : _RT_RADD, _RT_RSUB, _RT_RMUL, _RT_RDIV
  Entree : DX:AX (op1), CX:BX (op2)
  Sortie : DX:AX (resultat)
  DX = partie entiere signee, AX = partie fractionnaire (0..65535)
  -------------------------------------------------------------------------- }
Procedure GenRtRAdd;
Begin
  EmitSep;
  EmitComment('_RT_RADD : (DX:AX) + (CX:BX) -> DX:AX  (reel 16.16)');
  EmitSep;
  EmitLabel('_RT_RADD');
  EmitI('ADD  AX, BX               ; fractions');
  EmitI('ADC  DX, CX               ; parties entieres + retenue');
  EmitI('RET');
  EmitBlank;
End;

Procedure GenRtRSub;
Begin
  EmitSep;
  EmitComment('_RT_RSUB : (DX:AX) - (CX:BX) -> DX:AX  (reel 16.16)');
  EmitSep;
  EmitLabel('_RT_RSUB');
  EmitI('SUB  AX, BX');
  EmitI('SBB  DX, CX');
  EmitI('RET');
  EmitBlank;
End;

Procedure GenRtRMul;
{ (a + f/65536) * (c + d/65536)
  = a*c + (a*d + c*f)/65536 + f*d/65536^2
  Resultat : DX = a*c + [(a*d)>>16] + [(c*f)>>16]
             AX = (a*d & 0xFFFF) + (c*f & 0xFFFF) }
Begin
  EmitSep;
  EmitComment('_RT_RMUL : (DX:AX) * (CX:BX) -> DX:AX  (reel 16.16)');
  EmitSep;
  EmitLabel('_RT_RMUL');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  EmitI('PUSH BP');
  { Sauvegarder les operandes }
  EmitI('MOV  SI, DX               ; SI = a (int op1)');
  EmitI('MOV  DI, AX               ; DI = f (frac op1)');
  { Pas besoin de sauvegarder CX/BX (c/d) }
  { Terme a*c -> SI_result:AX_result }
  EmitI('MOV  AX, SI');
  EmitI('IMUL CX                   ; DX:AX = a*c');
  EmitI('MOV  BP, AX               ; BP = a*c (partie entiere resultat)');
  EmitI('XOR  SI, SI               ; accumulateur frac = 0');
  { Terme a*d -> DX:AX = a*d ; DX -> int, AX -> frac }
  EmitI('MOV  AX, [SP+6]           ; recharger a depuis pile : SI original');
  EmitI('MOV  AX, DI');
  EmitI('XCHG AX, DI               ; AX=frac(f), DI=a*c (garde BP)');
  EmitI('MOV  AX, [SP+6]'); { not needed, redo cleanly }
  { Use simpler register-based approach }
  EmitI('POP  BP');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
  { Note : impl?mentation simplifiee ci-dessus ? remplacee par GenRtRMulFull }
End;

{ Impl?mentation correcte de RMUL utilisant la pile pour sauvegarder }
Procedure GenRtRMulFull;
Var lbl_done : TString;
Begin
  lbl_done := NewLabel;
  EmitSep;
  EmitComment('_RT_RMUL_FULL : multiplication 16.16 precise');
  EmitComment('  (DX:AX) * (CX:BX) -> DX:AX');
  EmitComment('  Methode : a*c + [(a*d)>>16 + (c*f)>>16] avec a=DX,f=AX,c=CX,d=BX');
  EmitSep;
  EmitLabel('_RT_RMUL');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  { Sauvegarder les quatre termes }
  EmitI('PUSH DX                   ; [1] a = int(op1)');
  EmitI('PUSH AX                   ; [2] f = frac(op1)');
  EmitI('PUSH CX                   ; [3] c = int(op2)');
  EmitI('PUSH BX                   ; [4] d = frac(op2)');
  { Terme a*c : resultat entier }
  EmitI('MOV  AX, DX               ; AX = a');
  EmitI('IMUL CX                   ; DX:AX = a*c');
  EmitI('MOV  SI, AX               ; SI = partie entiere result (low 16)');
  EmitI('XOR  DI, DI               ; DI = accumulateur frac');
  { Terme a*d : contribue a*d/65536 a la partie entiere et a*d%65536 a la frac }
  EmitI('MOV  AX, [SP+6]           ; AX = a');
  EmitI('MUL  WORD PTR [SP]        ; DX:AX = a*d (non signe)');
  EmitI('ADD  DI, AX               ; frac += lo(a*d)');
  EmitI('ADD  SI, DX               ; int++ += hi(a*d)');
  { Terme c*f : contribue c*f/65536 a la partie entiere et c*f%65536 a la frac }
  EmitI('MOV  AX, [SP+4]           ; AX = f');
  EmitI('MUL  WORD PTR [SP+2]      ; DX:AX = c*f (non signe)');
  EmitI('ADD  DI, AX               ; frac += lo(c*f)');
  EmitI('ADD  SI, DX               ; int  += hi(c*f)');
  { Assembler le resultat }
  EmitI('MOV  DX, SI               ; DX = partie entiere');
  EmitI('MOV  AX, DI               ; AX = partie fractionnaire');
  { Nettoyer pile }
  EmitI('ADD  SP, 8');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

Procedure GenRtRDiv;
Var lbl_ok : TString;
{ (DX:AX) / (CX:BX) -> DX:AX en 16.16
  Algorithme :
    Si BX=0 (diviseur entier pur) : quotient = DX/CX, reste/CX -> frac
    Cas general : approximation par (DX*65536 + AX) / (CX*65536 + BX)
    8086 : utiliser DIV 16-bit, accepter perte de precision sur la frac }
Begin
  EmitSep;
  EmitComment('_RT_RDIV : (DX:AX) / (CX:BX) -> DX:AX  (reel 16.16)');
  EmitSep;
  lbl_ok := NewLabel;
  EmitLabel('_RT_RDIV');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH SI');
  EmitI('PUSH DI');
  { Test division par zero }
  EmitI('MOV  SI, CX');
  EmitI('OR   SI, BX               ; (CX | BX) == 0 ?');
  EmitI('JNZ  ' + lbl_ok);
  EmitI('MOV  DX, OFFSET _RT_DIVZERO_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitLabel(lbl_ok);
  { Partie entiere : DX / CX }
  EmitI('MOV  AX, DX               ; AX = int(numerateur)');
  EmitI('CWD');
  EmitI('IDIV CX                   ; AX = int(quotient), DX = reste');
  EmitI('MOV  DI, AX               ; DI = quotient entier');
  { Partie fractionnaire : reste*65536 / CX (approximation) }
  EmitI('XCHG AX, DX               ; AX = reste');
  EmitI('XOR  DX, DX');
  EmitI('DIV  CX                   ; AX = (reste*65536)/CX approx via high/low trick');
  { Note : la division ci-dessus est en fait reste/CX (pas *65536)     }
  { Pour une vraie precision, il faudrait DX=reste, AX=0 -> DIV CX     }
  { Reprendre :                                                          }
  EmitI('XOR  AX, AX               ; AX = 0 (poids bas pour shift *65536)');
  EmitI('DIV  CX                   ; DX:AX = reste:0 / CX -> AX=frac');
  EmitI('MOV  DX, DI               ; DX = partie entiere');
  EmitI('POP  DI');
  EmitI('POP  SI');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_ICOMPARE : comparer AX et BX (entiers signes), positionner flags CPU.
  Usage : CALL _RT_ICOMPARE; puis JL/JG/JE/JLE/JGE/JNE selon besoin.
  -------------------------------------------------------------------------- }
Procedure GenRtICompare;
Begin
  EmitSep;
  EmitComment('_RT_ICOMPARE : CMP AX, BX (entiers signes) -> flags');
  EmitSep;
  EmitLabel('_RT_ICOMPARE');
  EmitI('CMP  AX, BX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_RCOMPARE : comparer DX:AX et CX:BX (reels 16.16), positionner flags.
  Logique : comparer DX vs CX (entier) en premier ; si egal, AX vs BX (frac).
  Flags resultants : ZF/SF/OF comme pour un CMP classique.
  -------------------------------------------------------------------------- }
Procedure GenRtRCompare;
Var lbl_int_ne, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_RCOMPARE : comparer DX:AX vs CX:BX (reel 16.16) -> flags');
  EmitSep;
  lbl_int_ne := NewLabel;
  lbl_done   := NewLabel;
  EmitLabel('_RT_RCOMPARE');
  EmitI('CMP  DX, CX               ; comparer parties entieres');
  EmitI('JNE  ' + lbl_int_ne + '          ; si != les flags sont deja bons');
  EmitI('CMP  AX, BX               ; meme partie entiere : comparer fractions');
  EmitLabel(lbl_int_ne);
  EmitI('RET');
  EmitBlank;
End;

{ --- Message erreur division par zero --- }
Procedure GenDivZeroMsg;
Begin
  EmitComment('Message erreur division par zero');
  EmitI('_RT_DIVZERO_MSG:');
  EmitI('  DB  ''SNOBOL86 : division par zero'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenArithRuntime : emettre toutes les routines de conversion et arithmetique.
  Appelee depuis l'orchestrateur de passe 2 (TODO 25).
  -------------------------------------------------------------------------- }
Procedure GenArithRuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : conversions et arithmetique ===');
  EmitSep;
  EmitBlank;
  GenRtStr2Int;
  GenRtInt2Str;
  GenRtStr2Real;
  GenRtReal2Str;
  GenRtIAdd;
  GenRtISub;
  GenRtIMul;
  GenRtIDiv;
  GenRtRAdd;
  GenRtRSub;
  GenRtRMulFull;
  GenRtRDiv;
  GenRtICompare;
  GenRtRCompare;
End;

{ ============================================================================
  TODO 13 - RUNTIME : TABLES (ASSOCIATIVES)
  ============================================================================

  Layout memoire (alloue sur le heap via _SB_ALLOC) :

      BX -> [ size:W | count:W | load:W | slot[0] ... slot[size-1] ]
               +0       +2       +4       +6

      Header   = 6 octets
      Chaque slot = 8 octets :
          offset 0 : WORD cle_ptr    <- ptr donnees de la cle
          offset 2 : WORD cle_len    <- longueur de la cle
          offset 4 : WORD val_ptr    <- ptr donnees de la valeur
          offset 6 : WORD val_len    <- longueur de la valeur

      Slot vide : cle_ptr=0 ET cle_len=0
      Pas de tombstone en v1 : DELETE vide simplement le slot
      (peut casser les chaines de probing, negligeable pour v1)

  Hachage : somme des octets de la cle, modulo size (probing lineaire)

  Conventions des routines publiques :
      _RT_TABLE_NEW : CX=nb_slots -> BX=ptr_table
      _RT_TABLE_GET : BX=table, DI=cle_desc -> DX=val_desc (AX=1) ou AX=0
      _RT_TABLE_SET : BX=table, DI=cle_desc, SI=val_desc
      _RT_TABLE_DEL : BX=table, DI=cle_desc

  Interne :
      _RT_TABLE_HASH   : BX=table, DI=cle_desc -> AX=index
      _RT_TABLE_LOOKUP : BX=table, DI=cle_desc -> SI=slot, AX=0 vide/1 trouve/2 plein

  Prerequis : ES=DS (initialise dans _SB_INIT_IO pour STOSB)
  ============================================================================ }

{ --------------------------------------------------------------------------
  _RT_TABLE_NEW : creer une table de hachage de CX slots.
  Entree : CX = nombre de slots souhaite
  Sortie : BX = ptr table initialisee
  -------------------------------------------------------------------------- }
Procedure GenRtTableNew;
Var lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_NEW : creer une table associative de CX slots -> BX');
  EmitSep;
  lbl_done := NewLabel;
  EmitLabel('_RT_TABLE_NEW');
  EmitI('PUSH AX');
  EmitI('PUSH CX');
  EmitI('PUSH DI');
  EmitI('PUSH DX');
  { Allouer 6 + CX*8 octets }
  EmitI('PUSH CX                    ; [1] sauvegarder nb slots');
  EmitI('MOV  AX, CX');
  EmitI('ADD  AX, AX                ; *2');
  EmitI('ADD  AX, AX                ; *4');
  EmitI('ADD  AX, AX                ; *8 = CX*8');
  EmitI('ADD  AX, 6                 ; + header');
  EmitI('MOV  CX, AX');
  EmitI('CALL _SB_ALLOC             ; BX = ptr debut');
  EmitI('POP  CX                    ; [1] nb slots');
  { Remplir header }
  EmitI('MOV  [BX],   CX            ; [BX+0] = size');
  EmitI('MOV  WORD PTR [BX+2], 0    ; [BX+2] = count = 0');
  { load = size * 3 / 4 }
  EmitI('PUSH BX');
  EmitI('MOV  AX, CX');
  EmitI('MOV  DX, 3');
  EmitI('MUL  DX                    ; AX = CX*3 (DX=0 si CX < 21845)');
  EmitI('MOV  DX, 4');
  EmitI('DIV  DX                    ; AX = CX*3/4');
  EmitI('POP  BX');
  EmitI('MOV  [BX+4], AX            ; [BX+4] = load');
  { Zero-fill toute la zone de slots }
  EmitI('MOV  DI, BX');
  EmitI('ADD  DI, 6                 ; DI = debut slots');
  EmitI('MOV  AX, CX');
  EmitI('ADD  AX, AX');
  EmitI('ADD  AX, AX');
  EmitI('ADD  AX, AX                ; AX = CX*8');
  EmitI('MOV  CX, AX');
  EmitI('XOR  AL, AL');
  EmitI('JCXZ ' + lbl_done);
  EmitI('REP  STOSB                  ; remplir a zero');
  EmitLabel(lbl_done);
  EmitI('POP  DX');
  EmitI('POP  DI');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_TABLE_HASH (interne) : calculer le hash d'une cle dans une table.
  Entree : BX=table, DI=cle_desc
  Sortie : AX = index hash (0..size-1)
  Conserve : BX, SI, CX, DX, DI
  -------------------------------------------------------------------------- }
Procedure GenRtTableHash;
Var lbl_loop, lbl_done, lbl_zero, lbl_ret : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_HASH : hacher DI dans table BX -> AX=index (interne)');
  EmitSep;
  lbl_loop := NewLabel;
  lbl_done := NewLabel;
  lbl_zero := NewLabel;
  lbl_ret  := NewLabel;
  EmitLabel('_RT_TABLE_HASH');
  EmitI('PUSH BX');
  EmitI('PUSH SI');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitI('MOV  SI, [DI]              ; ptr donnees cle');
  EmitI('MOV  CX, [DI+2]            ; longueur cle');
  EmitI('XOR  AX, AX                ; accumulateur hash');
  EmitLabel(lbl_loop);
  EmitI('JCXZ ' + lbl_done);
  EmitI('MOV  DL, [SI]');
  EmitI('XOR  DH, DH');
  EmitI('ADD  AX, DX                ; hash += octet');
  EmitI('INC  SI');
  EmitI('DEC  CX');
  EmitI('JMP  ' + lbl_loop);
  EmitLabel(lbl_done);
  { AX mod size }
  EmitI('MOV  CX, [BX]              ; CX = size');
  EmitI('JCXZ ' + lbl_zero);
  EmitI('XOR  DX, DX');
  EmitI('DIV  CX                    ; DX:AX / CX -> AX=quot, DX=reste');
  EmitI('MOV  AX, DX                ; AX = hash index');
  EmitI('JMP  ' + lbl_ret);
  EmitLabel(lbl_zero);
  EmitI('XOR  AX, AX');
  EmitLabel(lbl_ret);
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  SI');
  EmitI('POP  BX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_TABLE_LOOKUP (interne) : chercher ou preparer l'insertion d'une cle.
  Entree : BX=table, DI=cle_desc
  Sortie : SI = ptr slot
           AX = 0 -> slot vide (insertion possible)
           AX = 1 -> cle trouvee (correspondance exacte)
           AX = 2 -> table pleine (aucun slot disponible)
  Utilise BP comme frame pour preserver DI au travers du REPE CMPSB.
  -------------------------------------------------------------------------- }
Procedure GenRtTableLookup;
Var lbl_probe, lbl_not_empty, lbl_cmp, lbl_cmp_done, lbl_found,
    lbl_advance, lbl_no_wrap, lbl_empty, lbl_full, lbl_ret : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_LOOKUP : chercher cle DI dans table BX -> SI=slot AX=0/1/2');
  EmitSep;
  lbl_probe     := NewLabel;
  lbl_not_empty := NewLabel;
  lbl_cmp       := NewLabel;
  lbl_cmp_done  := NewLabel;
  lbl_found     := NewLabel;
  lbl_advance   := NewLabel;
  lbl_no_wrap   := NewLabel;
  lbl_empty     := NewLabel;
  lbl_full      := NewLabel;
  lbl_ret       := NewLabel;
  EmitLabel('_RT_TABLE_LOOKUP');
  { Etablir un frame BP pour acceder a DI original a travers le CMPSB }
  EmitI('PUSH BP');
  EmitI('MOV  BP, SP');
  EmitI('PUSH DI                    ; [BP-2] = cle_desc original');
  EmitI('PUSH CX                    ; [BP-4] = caller CX (sauvegarde)');
  EmitI('PUSH DX                    ; [BP-6] = hash initial (sera rempli)');
  EmitI('CALL _RT_TABLE_HASH        ; AX = hash initial');
  EmitI('MOV  [BP-6], AX            ; sauvegarder hash initial');
  { Boucle de probing }
  EmitLabel(lbl_probe);
  { SI = BX + 6 + AX*8 }
  EmitI('MOV  CX, AX');
  EmitI('ADD  CX, CX                ; *2');
  EmitI('ADD  CX, CX                ; *4');
  EmitI('ADD  CX, CX                ; *8');
  EmitI('MOV  SI, BX');
  EmitI('ADD  SI, 6');
  EmitI('ADD  SI, CX                ; SI = &slot[AX]');
  { Slot vide ? }
  EmitI('MOV  CX, [SI]');
  EmitI('OR   CX, [SI+2]');
  EmitI('JNZ  ' + lbl_not_empty);
  EmitLabel(lbl_empty);
  EmitI('XOR  AX, AX                ; AX=0 : vide');
  EmitI('JMP  ' + lbl_ret);
  EmitLabel(lbl_not_empty);
  { Comparer longueurs }
  EmitI('MOV  CX, [SI+2]            ; cle_len du slot');
  EmitI('MOV  DI, [BP-2]            ; recharger cle_desc original');
  EmitI('CMP  CX, [DI+2]            ; longueurs egales ?');
  EmitI('JNE  ' + lbl_advance);
  { Comparer bytes }
  EmitI('PUSH AX                    ; [1] sauvegarder hash courant');
  EmitI('PUSH SI                    ; [2] sauvegarder ptr slot');
  EmitI('MOV  SI, [SI]              ; SI = ptr donnees slot.cle');
  EmitI('MOV  DI, [DI]              ; DI = ptr donnees cle recherche');
  EmitI('JCXZ ' + lbl_cmp_done);
  EmitI('REPE CMPSB                  ; comparer octet par octet');
  EmitLabel(lbl_cmp_done);
  EmitI('POP  SI                    ; [2] restaurer ptr slot');
  EmitI('MOV  DI, [BP-2]            ; restaurer cle_desc original');
  EmitI('POP  AX                    ; [1] restaurer hash courant');
  EmitI('JNE  ' + lbl_advance + '          ; bytes differents -> prochain slot');
  EmitLabel(lbl_found);
  EmitI('MOV  AX, 1                 ; AX=1 : trouve');
  EmitI('JMP  ' + lbl_ret);
  { Avancer au slot suivant (probing lineaire) }
  EmitLabel(lbl_advance);
  EmitI('INC  AX');
  EmitI('CMP  AX, [BX]              ; >= size ?');
  EmitI('JB   ' + lbl_no_wrap);
  EmitI('XOR  AX, AX                ; repasser a 0');
  EmitLabel(lbl_no_wrap);
  EmitI('CMP  AX, [BP-6]            ; retour au hash initial -> plein');
  EmitI('JNE  ' + lbl_probe);
  EmitLabel(lbl_full);
  EmitI('MOV  AX, 2                 ; AX=2 : plein');
  EmitLabel(lbl_ret);
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  DI');
  EmitI('POP  BP');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_TABLE_GET : lire la valeur associee a une cle.
  Entree : BX=table, DI=cle_desc
  Sortie : DX=val_desc si trouvee (AX=1), DX=0 et AX=0 si absente.
  -------------------------------------------------------------------------- }
Procedure GenRtTableGet;
Var lbl_found, lbl_not_found : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_GET : lire val de cle DI dans table BX -> DX=val, AX=1/0');
  EmitSep;
  lbl_found     := NewLabel;
  lbl_not_found := NewLabel;
  EmitLabel('_RT_TABLE_GET');
  EmitI('PUSH SI');
  EmitI('PUSH CX');
  EmitI('CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2');
  EmitI('CMP  AX, 1');
  EmitI('JE   ' + lbl_found);
  { Pas trouve }
  EmitLabel(lbl_not_found);
  EmitI('XOR  AX, AX                ; AX=0 : absent');
  EmitI('XOR  DX, DX                ; DX=0');
  EmitI('JMP  ' + lbl_found + '_end');
  EmitLabel(lbl_found);
  { DX = ptr du descripteur valeur (offset +4 dans le slot) }
  EmitI('MOV  DX, SI');
  EmitI('ADD  DX, 4                 ; DX = &slot.val = SI+4');
  EmitI('MOV  AX, 1                 ; AX=1 : trouve');
  EmitLabel(lbl_found + '_end');
  EmitI('POP  CX');
  EmitI('POP  SI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_TABLE_SET : inserer ou modifier une cle/valeur.
  Entree : BX=table, DI=cle_desc, SI=val_desc
  En cas de table pleine : erreur fatale.
  -------------------------------------------------------------------------- }
Procedure GenRtTableSet;
Var lbl_overwrite, lbl_insert, lbl_full_err : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_SET : inserer/modifier cle DI -> val SI dans table BX');
  EmitSep;
  lbl_overwrite := NewLabel;
  lbl_insert    := NewLabel;
  lbl_full_err  := NewLabel;
  EmitLabel('_RT_TABLE_SET');
  EmitI('PUSH AX');
  EmitI('PUSH SI');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitI('PUSH SI                    ; [1] sauvegarder val_desc');
  EmitI('CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2');
  EmitI('POP  DX                    ; [1] DX = val_desc');
  EmitI('CMP  AX, 2');
  EmitI('JE   ' + lbl_full_err);
  EmitI('CMP  AX, 1');
  EmitI('JE   ' + lbl_overwrite);
  { Insertion : verifier load }
  EmitI('MOV  CX, [BX+2]            ; count');
  EmitI('CMP  CX, [BX+4]            ; count >= load ?');
  EmitI('JAE  ' + lbl_full_err);
  { Copier la cle dans slot[0..3] }
  EmitLabel(lbl_insert);
  EmitI('MOV  CX, [DI]');
  EmitI('MOV  [SI],   CX            ; slot.cle_ptr = DI.ptr');
  EmitI('MOV  CX, [DI+2]');
  EmitI('MOV  [SI+2], CX            ; slot.cle_len = DI.len');
  { Incrementer count }
  EmitI('INC  WORD PTR [BX+2]');
  { Ecrire la valeur }
  EmitLabel(lbl_overwrite);
  EmitI('MOV  CX, [DX]');
  EmitI('MOV  [SI+4], CX            ; slot.val_ptr = DX.ptr');
  EmitI('MOV  CX, [DX+2]');
  EmitI('MOV  [SI+6], CX            ; slot.val_len = DX.len');
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  SI');
  EmitI('POP  AX');
  EmitI('RET');
  EmitLabel(lbl_full_err);
  EmitI('MOV  DX, OFFSET _RT_TABLE_OVF_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_TABLE_DEL : supprimer une entree (vider le slot).
  Entree : BX=table, DI=cle_desc
  Si non trouvee : no-op.
  Note v1 : vider le slot peut casser les chaines de probing.
  -------------------------------------------------------------------------- }
Procedure GenRtTableDel;
Var lbl_found, lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_TABLE_DEL : supprimer cle DI de la table BX');
  EmitSep;
  lbl_found := NewLabel;
  lbl_done  := NewLabel;
  EmitLabel('_RT_TABLE_DEL');
  EmitI('PUSH AX');
  EmitI('PUSH SI');
  EmitI('PUSH CX');
  EmitI('CALL _RT_TABLE_LOOKUP      ; SI=slot, AX=0/1/2');
  EmitI('CMP  AX, 1');
  EmitI('JNE  ' + lbl_done + '            ; pas trouve -> rien a faire');
  EmitLabel(lbl_found);
  EmitI('MOV  WORD PTR [SI],   0    ; cle_ptr = 0 (vider slot)');
  EmitI('MOV  WORD PTR [SI+2], 0    ; cle_len = 0');
  EmitI('MOV  WORD PTR [SI+4], 0    ; val_ptr = 0');
  EmitI('MOV  WORD PTR [SI+6], 0    ; val_len = 0');
  EmitI('DEC  WORD PTR [BX+2]       ; count--');
  EmitLabel(lbl_done);
  EmitI('POP  CX');
  EmitI('POP  SI');
  EmitI('POP  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --- Message debordement de table --- }
Procedure GenTableOverflowMsg;
Begin
  EmitComment('Message debordement de table associative');
  EmitI('_RT_TABLE_OVF_MSG:');
  EmitI('  DB  ''SNOBOL86 : table associative pleine'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenTableRuntime : emettre toutes les routines de gestion des tables.
  -------------------------------------------------------------------------- }
Procedure GenTableRuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : tables associatives ===');
  EmitSep;
  EmitBlank;
  GenRtTableNew;
  GenRtTableHash;
  GenRtTableLookup;
  GenRtTableGet;
  GenRtTableSet;
  GenRtTableDel;
End;

{ ============================================================================
  TODO 14 - RUNTIME : TABLEAUX (ARRAYS)
  ============================================================================

  Layout memoire (alloue sur le heap) :

      BX -> [ lb:W | ub:W | size:W | desc[0] ... desc[size-1] ]
               +0     +2     +4      +6

      Header  = 6 octets
      lb      = borne inferieure (1-based par convention SNOBOL)
      ub      = borne superieure
      size    = ub - lb + 1 (nb elements)
      desc[i] = descripteur 4 octets (ptr:W + len:W), initialise a zero

  Support tableau 1D uniquement en v1.

  Conventions des routines :
      _RT_ARRAY_NEW : CX=lb, DX=ub -> BX=ptr array
      _RT_ARRAY_GET : BX=array, AX=index -> DI=ptr descripteur element
                      AX=1 si index valide, AX=0 si hors-bornes
      _RT_ARRAY_SET : BX=array, AX=index, SI=ptr val_desc
                      AX=1 si ok, AX=0 si hors-bornes
  ============================================================================ }

{ --------------------------------------------------------------------------
  _RT_ARRAY_NEW : creer un tableau 1D [lb..ub].
  Entree : CX = borne inferieure (lb), DX = borne superieure (ub)
  Sortie : BX = ptr tableau (header + descripteurs zero-initialises)
  -------------------------------------------------------------------------- }
Procedure GenRtArrayNew;
Var lbl_done : TString;
Begin
  EmitSep;
  EmitComment('_RT_ARRAY_NEW : creer tableau 1D [CX..DX] -> BX');
  EmitSep;
  lbl_done := NewLabel;
  EmitLabel('_RT_ARRAY_NEW');
  EmitI('PUSH AX');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitI('PUSH DI');
  EmitI('PUSH SI');
  { Calculer size = ub - lb + 1 }
  EmitI('MOV  AX, DX               ; AX = ub');
  EmitI('SUB  AX, CX               ; AX = ub - lb');
  EmitI('INC  AX                    ; AX = size');
  { Allouer 6 + size*4 octets }
  EmitI('PUSH AX                    ; [1] sauvegarder size');
  EmitI('PUSH CX                    ; [2] sauvegarder lb');
  EmitI('PUSH DX                    ; [3] sauvegarder ub');
  EmitI('MOV  SI, AX               ; SI = size');
  EmitI('ADD  AX, AX                ; *2');
  EmitI('ADD  AX, AX                ; *4 = size*4');
  EmitI('ADD  AX, 6                 ; + header');
  EmitI('MOV  CX, AX');
  EmitI('CALL _SB_ALLOC             ; BX = ptr debut');
  EmitI('POP  DX                    ; [3] ub');
  EmitI('POP  CX                    ; [2] lb');
  EmitI('POP  AX                    ; [1] size');
  { Remplir le header }
  EmitI('MOV  [BX],   CX            ; [BX+0] = lb');
  EmitI('MOV  [BX+2], DX            ; [BX+2] = ub');
  EmitI('MOV  [BX+4], AX            ; [BX+4] = size');
  { Zero-initialiser les descripteurs (size*4 octets) }
  EmitI('MOV  DI, BX');
  EmitI('ADD  DI, 6                 ; DI = debut des descripteurs');
  EmitI('MOV  CX, AX');
  EmitI('ADD  CX, CX');
  EmitI('ADD  CX, CX                ; CX = size*4');
  EmitI('XOR  AL, AL');
  EmitI('JCXZ ' + lbl_done);
  EmitI('REP  STOSB                  ; remplir a zero');
  EmitLabel(lbl_done);
  EmitI('POP  SI');
  EmitI('POP  DI');
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_ARRAY_IDX (interne) : calculer le ptr vers le descripteur d'indice AX.
  Entree : BX=array, AX=index (1-based, ou lb-based selon convention)
  Sortie : DI = ptr descripteur (= BX + 6 + (AX-lb)*4)
           CF=0 si valide, CF=1 si hors-bornes
  -------------------------------------------------------------------------- }
Procedure GenRtArrayIdx;
Var lbl_ok, lbl_oob : TString;
Begin
  EmitSep;
  EmitComment('_RT_ARRAY_IDX : valider AX et calculer ptr desc -> DI (interne)');
  EmitSep;
  lbl_ok  := NewLabel;
  lbl_oob := NewLabel;
  EmitLabel('_RT_ARRAY_IDX');
  EmitI('PUSH AX');
  EmitI('PUSH CX');
  { Verifier lb <= AX <= ub }
  EmitI('CMP  AX, [BX]              ; AX < lb ?');
  EmitI('JB   ' + lbl_oob);
  EmitI('CMP  AX, [BX+2]            ; AX > ub ?');
  EmitI('JA   ' + lbl_oob);
  { Calculer offset = (AX - lb) * 4 }
  EmitI('SUB  AX, [BX]             ; AX = AX - lb (offset 0-based)');
  EmitI('ADD  AX, AX                ; *2');
  EmitI('ADD  AX, AX                ; *4');
  EmitI('MOV  DI, BX');
  EmitI('ADD  DI, 6                 ; sauter le header');
  EmitI('ADD  DI, AX                ; DI = ptr descripteur');
  EmitI('CLC                        ; CF=0 : valide');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('RET');
  EmitLabel(lbl_oob);
  EmitI('STC                        ; CF=1 : hors-bornes');
  EmitI('POP  CX');
  EmitI('POP  AX');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_ARRAY_GET : lire l'element d'indice AX.
  Entree : BX=array, AX=index
  Sortie : DI=ptr descripteur element, AX=1 si ok / AX=0 si hors-bornes.
  -------------------------------------------------------------------------- }
Procedure GenRtArrayGet;
Var lbl_ok, lbl_oob : TString;
Begin
  EmitSep;
  EmitComment('_RT_ARRAY_GET : lire element[AX] de tableau BX -> DI, AX=1/0');
  EmitSep;
  lbl_ok  := NewLabel;
  lbl_oob := NewLabel;
  EmitLabel('_RT_ARRAY_GET');
  EmitI('CALL _RT_ARRAY_IDX         ; DI=ptr desc, CF=hors-bornes');
  EmitI('JC   ' + lbl_oob);
  EmitI('MOV  AX, 1                 ; AX=1 : valide');
  EmitI('RET');
  EmitLabel(lbl_oob);
  EmitI('XOR  AX, AX                ; AX=0 : hors-bornes');
  EmitI('XOR  DI, DI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_ARRAY_SET : ecrire val_desc SI dans l'element d'indice AX.
  Entree : BX=array, AX=index, SI=ptr val_desc
  Sortie : AX=1 si ok / AX=0 si hors-bornes (la valeur n'est pas ecrite).
  -------------------------------------------------------------------------- }
Procedure GenRtArraySet;
Var lbl_ok, lbl_oob : TString;
Begin
  EmitSep;
  EmitComment('_RT_ARRAY_SET : ecrire SI dans element[AX] du tableau BX -> AX=1/0');
  EmitSep;
  lbl_ok  := NewLabel;
  lbl_oob := NewLabel;
  EmitLabel('_RT_ARRAY_SET');
  EmitI('PUSH DI');
  EmitI('PUSH CX');
  EmitI('CALL _RT_ARRAY_IDX         ; DI=ptr desc, CF=hors-bornes');
  EmitI('JC   ' + lbl_oob);
  { Copier les 4 octets du descripteur SI -> [DI] }
  EmitI('MOV  CX, [SI]');
  EmitI('MOV  [DI],   CX            ; ptr');
  EmitI('MOV  CX, [SI+2]');
  EmitI('MOV  [DI+2], CX            ; len');
  EmitI('MOV  AX, 1                 ; AX=1 : ok');
  EmitI('POP  CX');
  EmitI('POP  DI');
  EmitI('RET');
  EmitLabel(lbl_oob);
  EmitI('XOR  AX, AX                ; AX=0 : hors-bornes');
  EmitI('POP  CX');
  EmitI('POP  DI');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  _RT_ARRAY_OOB_ERR : erreur fatale si acces hors-bornes demande.
  Appelee par le code compile quand il veut un arret sur OOB.
  -------------------------------------------------------------------------- }
Procedure GenRtArrayOobErr;
Begin
  EmitSep;
  EmitComment('_RT_ARRAY_OOB_ERR : acces hors-bornes tableau -> arret');
  EmitSep;
  EmitLabel('_RT_ARRAY_OOB_ERR');
  EmitI('MOV  DX, OFFSET _RT_ARRAY_OOB_MSG');
  EmitI('MOV  AH, 9');
  EmitI('INT  21h');
  EmitI('JMP  _SB_END_PROG');
  EmitBlank;
End;

{ --- Message acces hors-bornes tableau --- }
Procedure GenArrayOobMsg;
Begin
  EmitComment('Message acces hors-bornes tableau');
  EmitI('_RT_ARRAY_OOB_MSG:');
  EmitI('  DB  ''SNOBOL86 : acces hors-bornes de tableau'', 0Dh, 0Ah, ''$''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenArrayRuntime : emettre toutes les routines de gestion des tableaux.
  -------------------------------------------------------------------------- }
Procedure GenArrayRuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : tableaux 1D ===');
  EmitSep;
  EmitBlank;
  GenRtArrayNew;
  GenRtArrayIdx;
  GenRtArrayGet;
  GenRtArraySet;
  GenRtArrayOobErr;
End;

{ ============================================================================
  TODO 15 - PARSER : STRUCTURE D'UNE INSTRUCTION SNOBOL
  ============================================================================

  Format d'une ligne source SNOBOL 4 :

      [label]  subject  [pattern]  [=replacement]  [:goto]

  Regles :
    - Label   : commence en colonne 1 (pas d'espace initial) ; vide si ' '
    - Subject : premier token apres le label (separateur = espace/tab)
    - Pattern : tokens entre le sujet et le premier '=' ou ':' ou fin de ligne
    - Replacement : tokens apres '=' jusqu'au premier ':' ou fin de ligne
    - Goto    : section commencant par ':' ; peut contenir :S(..) :F(..) :(..);
                deja analysee par LexExtractGotos (TODO 05)

  Variables globales remplies :
      inst_label   - etiquette (vide si absente)
      inst_subject - sujet (vide si ligne vide ou commentaire)
      inst_pattern - patron brut (vide si absent)
      inst_has_eq  - True si remplacement present
      inst_repl    - remplacement brut
      inst_goto_s  - label succes (ou '')
      inst_goto_f  - label echec (ou '')
      inst_goto_u  - label inconditionnel (ou '')

  Distinctions importantes :
      inst_subject = ''  et inst_pattern = ''  => instruction vide / commentaire
      inst_subject <> '' et inst_pattern = ''  et not inst_has_eq
                                               => acces simple (test d'existence)
      inst_subject <> '' et inst_has_eq        => affectation
      inst_subject <> '' et inst_pattern <> '' => matching (avec eventuel remplacement)

  Acces indexes :
      Subject de la forme   VAR<expr>    -> tableau
      Subject de la forme   VAR[expr]    -> reservee v2 (traite comme scalaire en v1)

  Procedures exportees :
      ParseInstruction : appelle dans l'ordre LexExtractLabel, ParseSubjectField,
                         ParsePatternField, ParseReplField, ParseGotoField.
      HasSubjectArrayAccess(s) : True si s contient '<'...'>'
      ParseArraySubscript(s, base, subscript) : decomposer VAR<expr>
  ============================================================================ }

{ --------------------------------------------------------------------------
  SkipWS : avancer lex_pos au-dela des espaces et tabulations.
  -------------------------------------------------------------------------- }
Procedure SkipWS;
Begin
  While (lex_pos <= Length(lex_line)) And
        (lex_line[lex_pos] In [' ', #9]) Do
    Inc(lex_pos);
End;

{ --------------------------------------------------------------------------
  ParseSubjectField : lire le champ sujet depuis la position courante.
  Remplit inst_subject.
  Le sujet se termine au premier espace/tab, '=', ':', fin de ligne.
  Cas speciaux traites :
    - guillemets ''...'' : lire jusqu'au guillemet fermant.
    - '<' referme avec '>' sans tenir compte des espaces internes.
  -------------------------------------------------------------------------- }
Procedure ParseSubjectField;
Var s     : TString;
    c     : Char;
    depth : Integer;
Begin
  inst_subject := '';
  SkipWS;
  If lex_pos > Length(lex_line) Then Exit;
  s := '';
  While lex_pos <= Length(lex_line) Do
  Begin
    c := lex_line[lex_pos];
    { Fin du sujet sur espace libre, '=', ':', mais pas dans '<>' }
    If c In [' ', #9, '=', ':'] Then Break;
    If c = '''' Then
    Begin
      { Chaine litterale comme sujet (cas rare mais legal) }
      Inc(lex_pos);
      s := s + '''';
      While lex_pos <= Length(lex_line) Do
      Begin
        c := lex_line[lex_pos];
        Inc(lex_pos);
        s := s + c;
        If c = '''' Then
        Begin
          { Double quote = quote literale }
          If (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = '''') Then
          Begin
            s := s + '''';
            Inc(lex_pos);
          End
          Else Break;
        End;
      End;
    End
    Else If c = '<' Then
    Begin
      s := s + c;
      Inc(lex_pos);
      depth := 1;
      While (lex_pos <= Length(lex_line)) And (depth > 0) Do
      Begin
        c := lex_line[lex_pos];
        s := s + c;
        Inc(lex_pos);
        If c = '<' Then Inc(depth)
        Else If c = '>' Then Dec(depth);
      End;
    End
    Else
    Begin
      s := s + c;
      Inc(lex_pos);
    End;
  End;
  inst_subject := s;
End;

{ --------------------------------------------------------------------------
  ParsePatternField : lire le champ patron.
  Remplit inst_pattern (chaine brute, trimee).
  S'arrete au premier '=' en dehors des guillemets/parentheses, ou ':'.
  -------------------------------------------------------------------------- }
Procedure ParsePatternField;
Var s : TString;
    c : Char;
    depth : Integer;
Begin
  inst_pattern := '';
  SkipWS;
  If lex_pos > Length(lex_line) Then Exit;
  { Si le char courant est deja '=' ou ':' -> pas de patron }
  If lex_line[lex_pos] In ['=', ':'] Then Exit;
  s     := '';
  depth := 0;
  While lex_pos <= Length(lex_line) Do
  Begin
    c := lex_line[lex_pos];
    { '=' hors parentheses/guillemets = fin du patron }
    If (c = '=') And (depth = 0) Then Break;
    If (c = ':') And (depth = 0) Then Break;
    If c = '(' Then
    Begin
      Inc(depth);
      s := s + c;
      Inc(lex_pos);
    End
    Else If c = ')' Then
    Begin
      If depth > 0 Then Dec(depth);
      s := s + c;
      Inc(lex_pos);
    End
    Else If c = '''' Then
    Begin
      { Lire chaine litterale }
      s := s + c;
      Inc(lex_pos);
      While lex_pos <= Length(lex_line) Do
      Begin
        c := lex_line[lex_pos];
        s := s + c;
        Inc(lex_pos);
        If c = '''' Then
        Begin
          If (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = '''') Then
          Begin
            s := s + '''';
            Inc(lex_pos);
          End
          Else Break;
        End;
      End;
    End
    Else
    Begin
      s := s + c;
      Inc(lex_pos);
    End;
  End;
  { Supprimer les espaces en fin }
  While (Length(s) > 0) And (s[Length(s)] In [' ', #9]) Do
    Delete(s, Length(s), 1);
  inst_pattern := s;
End;

{ --------------------------------------------------------------------------
  ParseReplField : lire le champ remplacement (apres '=').
  Remplit inst_has_eq et inst_repl.
  -------------------------------------------------------------------------- }
Procedure ParseReplField;
Var s : TString;
    c : Char;
    depth : Integer;
Begin
  inst_has_eq := False;
  inst_repl   := '';
  SkipWS;
  If lex_pos > Length(lex_line) Then Exit;
  If lex_line[lex_pos] <> '=' Then Exit;
  inst_has_eq := True;
  Inc(lex_pos);   { sauter le '=' }
  SkipWS;
  s     := '';
  depth := 0;
  While lex_pos <= Length(lex_line) Do
  Begin
    c := lex_line[lex_pos];
    If (c = ':') And (depth = 0) Then Break;
    If c = '(' Then
    Begin
      Inc(depth);
      s := s + c;
      Inc(lex_pos);
    End
    Else If c = ')' Then
    Begin
      If depth > 0 Then Dec(depth);
      s := s + c;
      Inc(lex_pos);
    End
    Else If c = '''' Then
    Begin
      s := s + c;
      Inc(lex_pos);
      While lex_pos <= Length(lex_line) Do
      Begin
        c := lex_line[lex_pos];
        s := s + c;
        Inc(lex_pos);
        If c = '''' Then
        Begin
          If (lex_pos <= Length(lex_line)) And (lex_line[lex_pos] = '''') Then
          Begin
            s := s + '''';
            Inc(lex_pos);
          End
          Else Break;
        End;
      End;
    End
    Else
    Begin
      s := s + c;
      Inc(lex_pos);
    End;
  End;
  { Trim final }
  While (Length(s) > 0) And (s[Length(s)] In [' ', #9]) Do
    Delete(s, Length(s), 1);
  inst_repl := s;
End;

{ --------------------------------------------------------------------------
  ParseGotoField : lire la section goto (:S(..) :F(..) :(..) etc.)
  Remplit inst_goto_s, inst_goto_f, inst_goto_u en appelant LexExtractGotos.
  -------------------------------------------------------------------------- }
Procedure ParseGotoField;
Begin
  inst_goto_s := '';
  inst_goto_f := '';
  inst_goto_u := '';
  SkipWS;
  If lex_pos > Length(lex_line) Then Exit;
  If lex_line[lex_pos] <> ':' Then Exit;
  { LexExtractGotos travaille sur lex_line a partir de lex_pos }
  LexExtractGotos;
End;

{ --------------------------------------------------------------------------
  HasSubjectArrayAccess : True si le sujet contient une notation '<...>'.
  -------------------------------------------------------------------------- }
Function HasSubjectArrayAccess(Const s : TString) : Boolean;
Var i : Integer;
Begin
  HasSubjectArrayAccess := False;
  For i := 1 To Length(s) Do
    If s[i] = '<' Then Begin HasSubjectArrayAccess := True; Exit; End;
End;

{ --------------------------------------------------------------------------
  ParseArraySubscript : decomposer 'VAR<expr>' en base et subscript.
  Si aucun '<' trouve, base=s, subscript=''.
  -------------------------------------------------------------------------- }
Procedure ParseArraySubscript(Const s : TString; Var base, subscript : TString);
Var i, depth : Integer;
Begin
  base      := '';
  subscript := '';
  i := 1;
  While i <= Length(s) Do
  Begin
    If s[i] = '<' Then
    Begin
      { base = tout ce qui precede le '<' }
      base := Copy(s, 1, i - 1);
      { subscript = contenu entre '<' et '>' correspondant }
      Inc(i);
      depth := 1;
      While (i <= Length(s)) And (depth > 0) Do
      Begin
        If s[i] = '<' Then Inc(depth)
        Else If s[i] = '>' Then Dec(depth);
        If depth > 0 Then subscript := subscript + s[i];
        Inc(i);
      End;
      Exit;
    End;
    Inc(i);
  End;
  { Pas de '<' -> scalaire }
  base := s;
End;

{ --------------------------------------------------------------------------
  ParseInstruction : analyser la ligne source courante.
  Prereq : lex_line contient la ligne (deja lue par LexReadLine, TODO 05).
  Remplit tous les champs inst_*.
  -------------------------------------------------------------------------- }
Procedure ParseInstruction;
Begin
  { Reinitialiser les champs }
  inst_label   := '';
  inst_subject := '';
  inst_pattern := '';
  inst_has_eq  := False;
  inst_repl    := '';
  inst_goto_s  := '';
  inst_goto_f  := '';
  inst_goto_u  := '';
  { 1. Extraire le label eventuel (colonne 1) }
  LexExtractLabel;
  { 2. Sujet }
  ParseSubjectField;
  { 3. Patron eventuellement present }
  ParsePatternField;
  { 4. Remplacement (si '=' rencontre) }
  ParseReplField;
  { 5. Section goto }
  ParseGotoField;
End;

{ ============================================================================
  TODO 16 - PARSER ET CODEGEN : AFFECTATION SIMPLE (SANS PATRON)
  ============================================================================

  Gere les instructions de la forme :   [label]  subject = expression  [:goto]

  Expression droite : suite de tokens separes par des espaces, concatenes.
  Chaque token peut etre :
      'literal'          -> string literal (GenDescriptorFromLit)
      entier 0..32767    -> converti par _RT_INT2STR -> DI
      variable (IDENT)   -> LEA DI, [VAR_D] (descripteur existant)
      FUNC(args)         -> appel stub (TODO 21) ; en v1 : variable simple

  Concatenation :
      Si plusieurs tokens : chaque token evalue -> DI ; puis CALL _SB_CONCATSTR
      accumulant dans un descripteur resultat (DX devient DI suivant).

  Affectation scalaire   X = expr :
      EvalExpr(inst_repl) -> DI
      EmitStoreVarDesc(sujet)

  Affectation indexee    X<i> = expr :
      EmitLoadVarDesc(base) -> BX (ptr array)
      EvalExprToken(subscript) -> AX (index entier)
      EvalExpr(inst_repl) -> SI (ptr val desc)
      CALL _RT_ARRAY_SET

  Section goto emise par EmitGotoSection (succes/echec/inconditionnel).
  ============================================================================ }

{ --------------------------------------------------------------------------
  AsmVarDesc : nom du descripteur ASM d'une variable (label_D).
  Identique a DescLabel deficit dans TODO 04.
  -------------------------------------------------------------------------- }
Procedure GenLoadSysVar(Const nm : TString); Forward;
Procedure GenStoreSysVar(Const nm : TString); Forward;
Procedure GenIORuntime; Forward;

Function AsmVarDesc(Const varname : TString) : TString;
Begin
  AsmVarDesc := AsmSafeIdent(UpCaseStr(varname)) + '_D';
End;

{ --------------------------------------------------------------------------
  AsmVarData : nom du buffer de donnees ASM (label_S).
  -------------------------------------------------------------------------- }
Function AsmVarData(Const varname : TString) : TString;
Begin
  AsmVarData := AsmSafeIdent(UpCaseStr(varname)) + '_S';
End;

{ --------------------------------------------------------------------------
  EmitLoadVarDesc : charger l'adresse du descripteur d'une variable dans DI.
  Emettre :  LEA  DI, [VAR_D]
  Si la variable n'est pas encore dans la table des symboles, l'ajouter.
  -------------------------------------------------------------------------- }
Procedure EmitLoadVarDesc(Const varname : TString);
Var sym : Integer;
Begin
  If (Length(varname) > 1) And (varname[1] = '&') Then
  Begin
    GenLoadSysVar(Copy(varname, 2, Length(varname) - 1));
    Exit;
  End;
  sym := FindSym(UpCaseStr(varname));
  If sym < 0 Then
    sym := AddSym(UpCaseStr(varname), SK_VAR, VK_UNDEF);
  EmitI('LEA  DI, [' + AsmVarDesc(varname) + ']');
End;

{ --------------------------------------------------------------------------
  EmitLoadVarDescToBX : charger l'adresse du descripteur dans BX.
  Utile pour les tableaux (BX = ptr tableau).
  -------------------------------------------------------------------------- }
Procedure EmitLoadVarDescToBX(Const varname : TString);
Var sym : Integer;
Begin
  sym := FindSym(UpCaseStr(varname));
  If sym < 0 Then
    sym := AddSym(UpCaseStr(varname), SK_VAR, VK_UNDEF);
  EmitI('LEA  BX, [' + AsmVarDesc(varname) + ']');
End;

{ --------------------------------------------------------------------------
  EmitStoreVarDesc : copier le descripteur DI vers le descripteur d'une var.
  Emettre :
      PUSH AX
      MOV  AX, [DI]
      MOV  [VAR_D],   AX      ; ptr
      MOV  AX, [DI+2]
      MOV  [VAR_D+2], AX      ; len
      POP  AX
  -------------------------------------------------------------------------- }
Procedure EmitStoreVarDesc(Const varname : TString);
Var lbl : TString;
Begin
  If (Length(varname) > 1) And (varname[1] = '&') Then
  Begin
    GenStoreSysVar(Copy(varname, 2, Length(varname) - 1));
    Exit;
  End;
  lbl := AsmVarDesc(varname);
  EmitI('PUSH AX');
  EmitI('MOV  AX, [DI]');
  EmitI('MOV  [' + lbl + '],   AX     ; stocker ptr');
  EmitI('MOV  AX, [DI+2]');
  EmitI('MOV  [' + lbl + '+2], AX     ; stocker len');
  EmitI('POP  AX');
End;

{ --------------------------------------------------------------------------
  IsStringLiteral : True si tok commence et finit par un apostrophe.
  -------------------------------------------------------------------------- }
Function IsStringLiteral(Const tok : TString) : Boolean;
Begin
  IsStringLiteral := (Length(tok) >= 2) And (tok[1] = '''') And (tok[Length(tok)] = '''');
End;

{ --------------------------------------------------------------------------
  IsIntegerLiteral : True si tok est compose uniquement de chiffres (eventuellement
  precede d'un '-').
  -------------------------------------------------------------------------- }
Function IsIntegerLiteral(Const tok : TString) : Boolean;
Var i : Integer;
Begin
  IsIntegerLiteral := False;
  If Length(tok) = 0 Then Exit;
  i := 1;
  If tok[1] = '-' Then Inc(i);
  If i > Length(tok) Then Exit;
  While i <= Length(tok) Do
  Begin
    If Not (tok[i] In ['0'..'9']) Then Exit;
    Inc(i);
  End;
  IsIntegerLiteral := True;
End;

{ --------------------------------------------------------------------------
  IsRealLiteral : True si tok est un reel (chiffres + '.' + chiffres).
  -------------------------------------------------------------------------- }
Function IsRealLiteral(Const tok : TString) : Boolean;
Var i : Integer;
    dot : Boolean;
Begin
  IsRealLiteral := False;
  dot := False;
  If Length(tok) = 0 Then Exit;
  i := 1;
  If tok[1] = '-' Then Inc(i);
  If i > Length(tok) Then Exit;
  While i <= Length(tok) Do
  Begin
    If tok[i] = '.' Then
    Begin
      If dot Then Exit;
      dot := True;
    End
    Else If Not (tok[i] In ['0'..'9']) Then Exit;
    Inc(i);
  End;
  IsRealLiteral := dot;
End;

{ --------------------------------------------------------------------------
  HasFuncCall : True si tok contient une parenthese ouvrante (appel de fonction).
  -------------------------------------------------------------------------- }
Function HasFuncCall(Const tok : TString) : Boolean;
Var i : Integer;
Begin
  HasFuncCall := False;
  For i := 1 To Length(tok) Do
    If tok[i] = '(' Then Begin HasFuncCall := True; Exit; End;
End;

{ --------------------------------------------------------------------------
  ExtractFuncName : extraire le nom de la fonction avant '('.
  -------------------------------------------------------------------------- }
Function ExtractFuncName(Const tok : TString) : TString;
Var i : Integer;
Begin
  i := 1;
  While (i <= Length(tok)) And (tok[i] <> '(') Do Inc(i);
  ExtractFuncName := UpCaseStr(Copy(tok, 1, i - 1));
End;

{ --------------------------------------------------------------------------
  ExtractFuncArgs : extraire la liste des arguments entre parentheses.
  Retourne la chaine brute (non parsee) entre '(' et ')'.
  -------------------------------------------------------------------------- }
Function ExtractFuncArgs(Const tok : TString) : TString;
Var i, depth : Integer;
    res        : TString;
Begin
  i := 1;
  While (i <= Length(tok)) And (tok[i] <> '(') Do Inc(i);
  Inc(i);   { sauter '(' }
  depth := 1;
  res := '';
  While (i <= Length(tok)) And (depth > 0) Do
  Begin
    If tok[i] = '(' Then Inc(depth)
    Else If tok[i] = ')' Then Dec(depth);
    If depth > 0 Then res := res + tok[i];
    Inc(i);
  End;
  ExtractFuncArgs := res;
End;

{ --------------------------------------------------------------------------
  StripStringLiteral : retirer les guillemets englobants d'un literal.
  Ex : '''hello''' -> 'hello'
  -------------------------------------------------------------------------- }
Function StripStringLiteral(Const tok : TString) : TString;
Begin
  If (Length(tok) >= 2) And (tok[1] = '''') And (tok[Length(tok)] = '''') Then
    StripStringLiteral := Copy(tok, 2, Length(tok) - 2)
  Else
    StripStringLiteral := tok;
End;

Procedure GenPredicateCall(Const fn : TString; nargs : Integer; Var args : Array of TString); Forward;
Procedure GenUserFuncCall(Const fname : TString; Const fargs : TString); Forward;
Procedure GenBuiltinCall(Const fname : TString; Const fargs : TString); Forward;

{ --------------------------------------------------------------------------
  EvalExprToken : evaluer un token unique, mettre le descripteur resultat dans DI.
  Cas geres :
    1. Chaine litterale ''...''  -> GenDescriptorFromLit + LEA DI, [desc]
    2. Entier                    -> MOV AX, val + CALL _RT_INT2STR -> DI
    3. Reel                      -> MOV AX/DX, val + CALL _RT_REAL2STR -> DI (approx)
    4. Appel de fonction         -> stub : charger la variable de meme nom (v1)
    5. Variable                  -> LEA DI, [VAR_D]
  -------------------------------------------------------------------------- }
Procedure EvalExprToken(Const tok : TString);
Var lit       : TString;
    idx       : Integer;
    fname     : TString;
    fargs     : TString;
    int_val   : LongInt;
    code_i    : Integer;
Begin
  If tok = '' Then
  Begin
    { Chaine vide : descripteur vide }
    EmitI('LEA  DI, [_SB_EMPTY_DESC]');
    Exit;
  End;

  If IsStringLiteral(tok) Then
  Begin
    { --- Chaine litterale --- }
    lit := StripStringLiteral(tok);
    idx := AddLiteral(lit);
    EmitI('LEA  DI, [' + LitDescLabel(idx) + ']');
  End
  Else If IsIntegerLiteral(tok) Then
  Begin
    { --- Entier --- }
    Val(tok, int_val, code_i);
    If code_i = 0 Then
    Begin
      EmitI('MOV  AX, ' + IntToStr(int_val));
      EmitI('CALL _RT_INT2STR          ; AX -> DI descripteur chaine');
    End
    Else
    Begin
      { Erreur de conversion : traiter comme variable }
      EmitLoadVarDesc(tok);
    End;
  End
  Else If IsRealLiteral(tok) Then
  Begin
    { --- Reel : transformer en literal chaine (valeur brute) --- }
    idx := AddLiteral(tok);
    EmitI('LEA  DI, [' + LitDescLabel(idx) + ']');
  End
  Else If HasFuncCall(tok) Then
  Begin
    { --- Appel de fonction : GenBuiltinCall (TODO 20) --- }
    fname := ExtractFuncName(tok);
    fargs := ExtractFuncArgs(tok);
    GenBuiltinCall(fname, fargs);
  End
  Else
  Begin
    { --- Variable scalaire --- }
    EmitLoadVarDesc(tok);
  End;
End;

{ --------------------------------------------------------------------------
  SplitTokens : decouper une expression en tokens sur les espaces.
  Respecte les guillemets et les parentheses imbriquees.
  Retourne les tokens dans un tableau toks (max 16), nb dans count.
  -------------------------------------------------------------------------- }
Procedure SplitTokens(Const expr : TString; Var toks : Array of TString; Var count : Integer);
Var i    : Integer;
    cur  : TString;
    c    : Char;
    depth : Integer;
    inquote : Boolean;
Begin
  count   := 0;
  cur     := '';
  depth   := 0;
  inquote := False;
  For i := 1 To Length(expr) Do
  Begin
    c := expr[i];
    If inquote Then
    Begin
      cur := cur + c;
      If c = '''' Then inquote := False;
    End
    Else If c = '''' Then
    Begin
      inquote := True;
      cur := cur + c;
    End
    Else If c = '(' Then
    Begin
      Inc(depth);
      cur := cur + c;
    End
    Else If c = ')' Then
    Begin
      If depth > 0 Then Dec(depth);
      cur := cur + c;
    End
    Else If (c In [' ', #9]) And (depth = 0) Then
    Begin
      If cur <> '' Then
      Begin
        If count <= High(toks) Then
        Begin
          toks[count] := cur;
          Inc(count);
        End;
        cur := '';
      End;
    End
    Else
      cur := cur + c;
  End;
  If cur <> '' Then
  Begin
    If count <= High(toks) Then
    Begin
      toks[count] := cur;
      Inc(count);
    End;
  End;
End;

{ --------------------------------------------------------------------------
  EvalExpr : evaluer une expression (concatenation de tokens) -> DI = desc.
  Si expr est vide -> LEA DI, [_SB_EMPTY_DESC].
  Si un token unique -> EvalExprToken.
  Sinon : evaluer chaque token, concatener successivement via _SB_CONCATSTR.
  -------------------------------------------------------------------------- }
Procedure EvalExpr(Const expr : TString);
Var toks  : Array[0..15] Of TString;
    count : Integer;
    i     : Integer;
Begin
  If expr = '' Then
  Begin
    EmitI('LEA  DI, [_SB_EMPTY_DESC]');
    Exit;
  End;
  { Decoupe en tokens }
  SplitTokens(expr, toks, count);
  If count = 0 Then
  Begin
    EmitI('LEA  DI, [_SB_EMPTY_DESC]');
    Exit;
  End;
  { Evaluer le premier token -> DI }
  EvalExprToken(toks[0]);
  { Concatener les tokens suivants }
  For i := 1 To count - 1 Do
  Begin
    EmitComment('Concatenation token ' + IntToStr(i + 1));
    EmitI('PUSH DI                    ; [1] sauvegarder gauche');
    EvalExprToken(toks[i]);            { DI = droite }
    EmitI('MOV  SI, DI               ; SI = droite');
    EmitI('POP  DI                    ; [1] DI = gauche');
    EmitI('CALL _SB_CONCATSTR         ; DX = resultat concat');
    EmitI('MOV  DI, DX               ; DI = descripteur resultat');
  End;
End;

{ ============================================================================
  TODO 19 - CODEGEN : GOTO ET BRANCHEMENTS SUCCES/ECHEC
  ============================================================================
  GotoLabelToAsm  : nom SNOBOL -> label ASM
  IsSpecialGotoLabel : END/RETURN/FRETURN/NRETURN -> True
  EmitGotoJmp     : emettre JMP + enregistrer forward ref
  ResolveForwardRefs : verifier toutes les forward refs post-compilation
  ============================================================================ }

{ --------------------------------------------------------------------------
  GotoLabelToAsm : traduire un nom de label SNOBOL en label ASM.
  -------------------------------------------------------------------------- }
Function GotoLabelToAsm(Const lbl : TString) : TString;
Var u : TString;
Begin
  u := UpCaseStr(lbl);
  If      u = 'END'     Then GotoLabelToAsm := '_SB_END_PROG'
  Else If u = 'RETURN'  Then GotoLabelToAsm := '_SB_RETURN'
  Else If u = 'FRETURN' Then GotoLabelToAsm := '_SB_FRETURN'
  Else If u = 'NRETURN' Then GotoLabelToAsm := '_SB_NRETURN'
  Else GotoLabelToAsm := SB_LBL_PFX + AsmSafeIdent(u);
End;

{ --------------------------------------------------------------------------
  IsSpecialGotoLabel : True si lbl est un label special.
  -------------------------------------------------------------------------- }
Function IsSpecialGotoLabel(Const lbl : TString) : Boolean;
Var u : TString;
Begin
  u := UpCaseStr(lbl);
  IsSpecialGotoLabel := (u = 'END') Or (u = 'RETURN') Or
                        (u = 'FRETURN') Or (u = 'NRETURN');
End;

{ --------------------------------------------------------------------------
  EmitGotoJmp : emettre un JMP vers un label SNOBOL.
  Pour les labels utilisateur non speciaux, enregistre une forward ref.
  -------------------------------------------------------------------------- }
Procedure EmitGotoJmp(Const lbl : TString);
Var asm_lbl : TString;
    u       : TString;
Begin
  If lbl = '' Then Exit;
  u       := UpCaseStr(lbl);
  asm_lbl := GotoLabelToAsm(u);
  EmitI('JMP  ' + asm_lbl);
  If Not IsSpecialGotoLabel(u) Then
  Begin
    If FindLabel(u) = 0 Then
      AddLabel(u);
    AddFwdRef(u, src_line_num);
  End;
End;

{ --------------------------------------------------------------------------
  ResolveForwardRefs : verifier toutes les forward refs apres compilation.
  Emet un Warning pour chaque label utilise mais non defini.
  -------------------------------------------------------------------------- }
Procedure ResolveForwardRefs;
Var i   : Integer;
    idx : Integer;
Begin
  For i := 1 To fwd_count Do
  Begin
    idx := FindLabel(fwd_table^[i].asm_label);
    If (idx = 0) Or (Not label_table^[idx].defined) Then
      Warning('Label non defini : ' + fwd_table^[i].asm_label);
  End;
End;
{ --------------------------------------------------------------------------
  EmitGotoSection : emettre le code de saut de la section goto.
  Conventions :
      goto_u (inconditionnel) -> JMP lbl (toujours emis en premier)
      goto_s (succes)         -> JMP lbl (utilise apres un test de succes)
      goto_f (echec)          -> JMP lbl (utilise apres un test d'echec)
  Pour une affectation simple (sans patron), le matching ne peut pas echouer :
      succes = toujours; echec = jamais.
  Donc :  si goto_u <> '' -> JMP goto_u
          si goto_s <> '' -> JMP goto_s  (la branche succes)
          si goto_f <> '' -> rien (echec impossible ici)
  -------------------------------------------------------------------------- }
Procedure EmitGotoSection;
Begin
  If inst_goto_u <> '' Then
    EmitGotoJmp(inst_goto_u)
  Else If inst_goto_s <> '' Then
    EmitGotoJmp(inst_goto_s);
  { inst_goto_f : impossible ici (affectation simple = toujours succes) }
End;

{ --------------------------------------------------------------------------
  GenLabelDef : si inst_label est non vide, emettre l'etiquette ASM
  et la definir dans la table des labels.
  -------------------------------------------------------------------------- }
Procedure GenLabelDef;
Var lbl_idx : Integer;
Begin
  If inst_label = '' Then Exit;
  lbl_idx := FindLabel(inst_label);
  If lbl_idx = 0 Then
    lbl_idx := AddLabel(inst_label);
  DefineLabel(lbl_idx, 0);
  EmitLabel(SB_LBL_PFX + AsmSafeIdent(UpCaseStr(inst_label)));
End;

{ --------------------------------------------------------------------------
  GenSimpleAssign : generer le code d'une affectation simple sans patron.
  Cas 1 : scalaire   X = expr
  Cas 2 : tableau    X<i> = expr
  -------------------------------------------------------------------------- }
Procedure GenSimpleAssign;
Var base      : TString;
    subscript : TString;
Begin
  EmitComment('Affectation : ' + inst_subject + ' = ' + inst_repl);
  If HasSubjectArrayAccess(inst_subject) Then
  Begin
    { --- Cas 2 : affectation indexee X<i> = expr --- }
    ParseArraySubscript(inst_subject, base, subscript);
    EmitComment('  Tableau : ' + base + '[' + subscript + ']');
    { Charger ptr du tableau dans BX }
    EmitLoadVarDescToBX(base);
    EmitI('MOV  BX, [BX]             ; BX = ptr donnees = ptr array header');
    { Evaluer l'indice -> AX }
    EmitComment('  Evaluer indice');
    EvalExprToken(subscript);          { DI = desc indice (chaine) }
    EmitI('CALL _RT_STR2INT           ; SI=DI -> AX = entier indice');
    EmitI('PUSH AX                    ; [1] sauvegarder indice');
    EmitI('PUSH BX                    ; [2] sauvegarder ptr array');
    { Evaluer la valeur -> DI }
    EmitComment('  Evaluer expression droite');
    EvalExpr(inst_repl);               { DI = descripteur valeur }
    EmitI('MOV  SI, DI               ; SI = val_desc');
    EmitI('POP  BX                    ; [2] ptr array');
    EmitI('POP  AX                    ; [1] indice');
    EmitI('CALL _RT_ARRAY_SET         ; stocker SI dans BX[AX]');
    EmitI('CMP  AX, 0');
    EmitI('JE   _RT_ARRAY_OOB_ERR     ; hors-bornes -> erreur fatale');
  End
  Else
  Begin
    { --- Cas 1 : affectation scalaire X = expr --- }
    EvalExpr(inst_repl);               { DI = descripteur valeur }
    EmitStoreVarDesc(inst_subject);
  End;
  { Section goto }
  EmitGotoSection;
  EmitBlank;
End;


{ ============================================================================
  TODO 18 - CODEGEN : OPERATEURS DE PATRON (ALT, CONCAT, ASSIGN)
  ============================================================================ }

{ --------------------------------------------------------------------------
  PatTrimStr : retirer les espaces de debut/fin.
  -------------------------------------------------------------------------- }
Function PatTrimStr(Const s : TString) : TString;
Var i, j : Integer;
Begin
  i := 1;
  While (i <= Length(s)) And (s[i] In [' ', #9]) Do Inc(i);
  j := Length(s);
  While (j >= i) And (s[j] In [' ', #9]) Do Dec(j);
  PatTrimStr := Copy(s, i, j - i + 1);
End;

{ ============================================================================
  TODO 20 - CODEGEN : FONCTIONS PREDEFINIES (APPEND)
  ============================================================================
  SplitArgsComma  : decouper la liste d'args CSV en tableau de TString.
  EvalArgAsDesc   : evaluer un arg -> SI = descripteur.
  EvalArgAsInt    : evaluer un arg -> AX = entier.
  GenBuiltinCall  : dispatcher pour SIZE, SUBSTR, DUPL, REPLACE, TRIM,
                    CHAR, ORD, CONVERT, DATATYPE, DATE, TIME.
  ============================================================================ }

{ --------------------------------------------------------------------------
  SplitArgsComma : decouper raw sur les ',' de niveau 0.
  Respecte les guillemets simples et les parentheses imbriquees.
  -------------------------------------------------------------------------- }
Procedure SplitArgsComma(Const raw : TString;
                         Var parts : Array of TString;
                         Var count : Integer);
Var i, depth : Integer;
    cur      : TString;
    c        : Char;
    in_q     : Boolean;
Begin
  count := 0;  cur := '';  depth := 0;  in_q := False;
  For i := 1 To Length(raw) Do
  Begin
    c := raw[i];
    If in_q Then
    Begin
      cur := cur + c;
      If c = '''' Then in_q := False;
    End
    Else If c = '''' Then Begin cur := cur + c; in_q := True; End
    Else If c = '(' Then Begin Inc(depth); cur := cur + c; End
    Else If c = ')' Then Begin If depth > 0 Then Dec(depth); cur := cur + c; End
    Else If (c = ',') And (depth = 0) Then
    Begin
      cur := PatTrimStr(cur);
      If count <= High(parts) Then Begin parts[count] := cur; Inc(count); End;
      cur := '';
    End
    Else cur := cur + c;
  End;
  cur := PatTrimStr(cur);
  If (Length(cur) > 0) And (count <= High(parts)) Then
  Begin parts[count] := cur; Inc(count); End;
End;

{ --------------------------------------------------------------------------
  EvalArgAsDesc : evaluer l'expression arg, charger descripteur dans SI.
  Post-condition : SI = adresse du descripteur string de arg.
  -------------------------------------------------------------------------- }
Procedure EvalArgAsDesc(Const arg : TString);
Begin
  EvalExprToken(arg);        { DI = desc }
  EmitI('MOV  SI, DI');
End;

{ --------------------------------------------------------------------------
  EvalArgAsInt : evaluer l'expression arg, produire entier dans AX.
  Cas literal entier : MOV AX, imm.  Sinon : evalue -> DI -> SI -> _RT_STR2INT.
  -------------------------------------------------------------------------- }
Procedure EvalArgAsInt(Const arg : TString);
Var iv   : LongInt;
    ci   : Integer;
    trim : TString;
Begin
  trim := PatTrimStr(arg);
  If IsIntegerLiteral(trim) Then
  Begin
    Val(trim, iv, ci);
    If ci = 0 Then EmitI('MOV  AX, ' + IntToStr(iv))
    Else Begin
      EmitI('MOV  AX, 0  ; conversion litterale echouee');
    End;
  End
  Else
  Begin
    EvalExprToken(trim);
    EmitI('MOV  SI, DI');
    EmitI('CALL _RT_STR2INT    ; SI=desc -> AX=entier');
  End;
End;

{ --------------------------------------------------------------------------
  GenBuiltinCall : emettre le code ASM pour un appel de fonction predefined.
  fname = nom (casse quelconque), fargs = chaine CSV des arguments.
  Resultat standard : DI = descripteur de la valeur retournee.
  Exception : ORD -> resultat converti en chaine ; SIZE idem.
  -------------------------------------------------------------------------- }
Procedure GenBuiltinCall(Const fname : TString; Const fargs : TString);
Var args  : Array[0..7] of TString;
    nargs : Integer;
    fn    : TString;
Begin
  fn    := UpCaseStr(fname);
  SplitArgsComma(fargs, args, nargs);
  EmitComment('Builtin ' + fn + '(' + fargs + ')');

  { ---- SIZE(s) -> CX = longueur de s, retourne CX converti en chaine ---- }
  If fn = 'SIZE' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('CALL _RT_STRLEN   ; SI=desc -> CX=longueur');
    EmitI('MOV  AX, CX');
    EmitI('CALL _RT_INT2STR  ; AX -> DI=descripteur entier');
  End

  { ---- SUBSTR(s,i,n) -> DI = sous-chaine de s a partir de i, longueur n ---- }
  Else If fn = 'SUBSTR' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI');
    If nargs >= 2 Then EvalArgAsInt(args[1])
    Else EmitI('MOV  AX, 1');
    EmitI('PUSH AX');
    If nargs >= 3 Then EvalArgAsInt(args[2])
    Else EmitI('MOV  AX, 0');
    EmitI('MOV  CX, AX');
    EmitI('POP  AX           ; AX = position (1-base)');
    EmitI('POP  SI           ; SI = sujet desc');
    EmitI('CALL _RT_SUBSTR   ; SI=sujet, AX=pos, CX=len -> DI');
  End

  { ---- DUPL(s,n) -> DI = s repete n fois ---- }
  Else If fn = 'DUPL' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI');
    If nargs >= 2 Then EvalArgAsInt(args[1])
    Else EmitI('MOV  AX, 0');
    EmitI('MOV  CX, AX');
    EmitI('POP  SI           ; SI = desc source');
    EmitI('CALL _RT_DUPL     ; SI=desc, CX=n -> DI');
  End

  { ---- REPLACE(s,t,u) -> DI = s avec table de traduction t->u ---- }
  Else If fn = 'REPLACE' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI           ; [1] sujet');
    If nargs >= 2 Then EvalArgAsDesc(args[1])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI           ; [2] table from');
    If nargs >= 3 Then EvalArgAsDesc(args[2])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('MOV  BX, SI       ; BX = table to desc');
    EmitI('POP  DI           ; DI = table from desc');
    EmitI('POP  SI           ; SI = sujet desc');
    EmitI('CALL _RT_REPLACE  ; SI=s, DI=from, BX=to -> DI');
  End

  { ---- TRIM(s) -> DI = s sans espaces finaux ---- }
  Else If fn = 'TRIM' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('CALL _RT_TRIM     ; SI=desc -> DI=desc trimme');
  End

  { ---- CHAR(n) -> DI = chaine d'un caractere de code ASCII n ---- }
  Else If fn = 'CHAR' Then
  Begin
    If nargs >= 1 Then EvalArgAsInt(args[0])
    Else EmitI('MOV  AX, 0');
    EmitI('CALL _RT_CHAR     ; AX=code -> DI=desc 1 char');
  End

  { ---- ORD(s) -> DI = code ASCII du premier caractere de s ---- }
  Else If fn = 'ORD' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('CALL _RT_ORD      ; SI=desc -> AX=code ASCII');
    EmitI('CALL _RT_INT2STR  ; AX -> DI=descripteur entier');
  End

  { ---- CONVERT(v,t) -> DI = v converti en type t ---- }
  Else If fn = 'CONVERT' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI           ; [1] valeur source');
    If nargs >= 2 Then EvalArgAsDesc(args[1])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('MOV  DI, SI       ; DI = desc type cible');
    EmitI('POP  SI           ; SI = valeur source');
    EmitI('CALL _RT_CONVERT  ; SI=val, DI=type -> DI');
  End

  { ---- DATATYPE(v) -> DI = chaine du type ('STRING','INTEGER',...) ---- }
  Else If fn = 'DATATYPE' Then
  Begin
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('CALL _RT_DATATYPE ; SI=desc -> DI=type desc');
  End

  { ---- DATE -> DI = chaine de la date (INT 21h AH=2Ah) ---- }
  Else If fn = 'DATE' Then
  Begin
    EmitI('CALL _RT_DATE     ; -> DI=desc date');
  End

  { ---- TIME -> DI = chaine de l'heure (INT 21h AH=2Ch) ---- }
  Else If fn = 'TIME' Then
  Begin
    EmitI('CALL _RT_TIME     ; -> DI=desc heure');
  End

  { ---- Predicats : LT/LE/GT/GE/EQ/NE/IDENT/DIFFER/INTEGER/REAL/NUMERIC ---- }
  Else If IsPredicateBuiltin(fn) Or (fn='INTEGER') Or (fn='REAL') Or (fn='NUMERIC') Then
  Begin
    GenPredicateCall(fn, nargs, args);
  End

  { ---- Fonction utilisateur : GenUserFuncCall (TODO 21) ---- }
  Else
  Begin
    GenUserFuncCall(fn, fargs);
  End;
End;
{ --------------------------------------------------------------------------
  PatSplitOnAlt : decouper raw sur les '|' de niveau 0.
  -------------------------------------------------------------------------- }
Procedure PatSplitOnAlt(Const raw : TString;
                        Var parts : Array of TString;
                        Var count : Integer);
Var i, depth : Integer;
    cur      : TString;
    c        : Char;
    in_q     : Boolean;
Begin
  count := 0;  cur := '';  depth := 0;  in_q := False;
  For i := 1 To Length(raw) Do
  Begin
    c := raw[i];
    If in_q Then
    Begin
      cur := cur + c;
      If c = '''' Then in_q := False;
    End
    Else If c = '''' Then Begin cur := cur + c; in_q := True; End
    Else If c = '(' Then Begin Inc(depth); cur := cur + c; End
    Else If c = ')' Then Begin If depth > 0 Then Dec(depth); cur := cur + c; End
    Else If (c = '|') And (depth = 0) Then
    Begin
      cur := PatTrimStr(cur);
      If (Length(cur) > 0) And (count <= High(parts)) Then
      Begin parts[count] := cur; Inc(count); End;
      cur := '';
    End
    Else cur := cur + c;
  End;
  cur := PatTrimStr(cur);
  If (Length(cur) > 0) And (count <= High(parts)) Then
  Begin parts[count] := cur; Inc(count); End;
End;

{ --------------------------------------------------------------------------
  PatSplitConcat : decouper un segment en tokens primaires.
  -------------------------------------------------------------------------- }
Procedure PatSplitConcat(Const raw : TString;
                         Var toks  : Array of TString;
                         Var count : Integer);
Var i, depth : Integer;
    cur      : TString;
    c        : Char;
    in_q     : Boolean;
Begin
  count := 0;  cur := '';  depth := 0;  in_q := False;  i := 1;
  While i <= Length(raw) Do
  Begin
    c := raw[i];
    If in_q Then
    Begin
      cur := cur + c;
      If c = '''' Then
      Begin
        If (i < Length(raw)) And (raw[i+1] = '''') Then
        Begin cur := cur + ''''; Inc(i); End
        Else in_q := False;
      End;
      Inc(i);
    End
    Else If c = '''' Then Begin cur := cur + c; in_q := True; Inc(i); End
    Else If c = '(' Then Begin Inc(depth); cur := cur + c; Inc(i); End
    Else If c = ')' Then Begin If depth > 0 Then Dec(depth); cur := cur + c; Inc(i); End
    Else If (c In [' ', #9]) And (depth = 0) Then
    Begin
      cur := PatTrimStr(cur);
      If (Length(cur) > 0) And (count <= High(toks)) Then
      Begin toks[count] := cur; Inc(count); End;
      cur := '';  Inc(i);
    End
    Else If ((c = '.') Or (c = '$')) And (depth = 0) Then
    Begin
      cur := PatTrimStr(cur);
      If (Length(cur) > 0) And (count <= High(toks)) Then
      Begin toks[count] := cur; Inc(count); End;
      cur := '';
      If count <= High(toks) Then Begin toks[count] := c; Inc(count); End;
      Inc(i);
    End
    Else Begin cur := cur + c; Inc(i); End;
  End;
  cur := PatTrimStr(cur);
  If (Length(cur) > 0) And (count <= High(toks)) Then
  Begin toks[count] := cur; Inc(count); End;
End;

{ --------------------------------------------------------------------------
  ParsePatPrimary : creer un noeud TPatNode pour un token primaire brut.
  -------------------------------------------------------------------------- }
Function ParsePatPrimary(Const tok : TString) : Integer;
Var fn, arg, lit : TString;
    i, ival, ci  : Integer;
    c            : Char;
    ndx, idx     : Integer;
Begin
  ParsePatPrimary := 0;
  If tok = '' Then Exit;
  If tok[1] = '''' Then
  Begin
    lit := '';  i := 2;
    While i <= Length(tok) Do
    Begin
      c := tok[i];
      If c = '''' Then
      Begin
        Inc(i);
        If (i <= Length(tok)) And (tok[i] = '''') Then
        Begin lit := lit + ''''; Inc(i); End
        Else Break;
      End
      Else Begin lit := lit + c; Inc(i); End;
    End;
    idx := AddLiteral(lit);
    ndx := AddPat(PK_LIT);
    pat_table^[ndx].lit_idx := idx;
    pat_table^[ndx].lit_len := Length(lit);
    ParsePatPrimary := ndx;  Exit;
  End;
  If HasFuncCall(tok) Then
  Begin
    fn  := ExtractFuncName(tok);
    arg := PatTrimStr(ExtractFuncArgs(tok));
    lit := arg;
    If (Length(arg) >= 2) And (arg[1] = '''') And (arg[Length(arg)] = '''') Then
      lit := Copy(arg, 2, Length(arg)-2);
    If (fn='ANY') Or (fn='NOTANY') Or (fn='SPAN') Or (fn='BREAK') Or (fn='BREAKX') Then
    Begin
      idx := AddLiteral(lit);
      If      fn='ANY'    Then ndx := AddPat(PK_ANY)
      Else If fn='NOTANY' Then ndx := AddPat(PK_NOTANY)
      Else If fn='SPAN'   Then ndx := AddPat(PK_SPAN)
      Else                     ndx := AddPat(PK_BREAK);
      pat_table^[ndx].set_idx := idx;
      ParsePatPrimary := ndx;  Exit;
    End;
    If (fn='LEN') Or (fn='POS') Or (fn='RPOS') Or (fn='TAB') Or (fn='RTAB') Then
    Begin
      Val(arg, ival, ci);  If ci <> 0 Then ival := 0;
      If      fn='LEN'  Then ndx := AddPat(PK_LEN)
      Else If fn='POS'  Then ndx := AddPat(PK_POS)
      Else If fn='RPOS' Then ndx := AddPat(PK_RPOS)
      Else If fn='TAB'  Then ndx := AddPat(PK_TAB)
      Else                   ndx := AddPat(PK_RTAB);
      pat_table^[ndx].int_val := ival;
      ParsePatPrimary := ndx;  Exit;
    End;
    If fn = 'ARBNO' Then Begin ParsePatPrimary := AddPat(PK_ARB); Exit; End;
    ndx := AddPat(PK_INDIRECT);  pat_table^[ndx].var_nm := fn;
    ParsePatPrimary := ndx;  Exit;
  End;
  fn := UpCaseStr(tok);
  If fn='ARB'     Then Begin ParsePatPrimary:=AddPat(PK_ARB);     Exit; End;
  If fn='REM'     Then Begin ParsePatPrimary:=AddPat(PK_REM);     Exit; End;
  If fn='FAIL'    Then Begin ParsePatPrimary:=AddPat(PK_FAIL);    Exit; End;
  If fn='FENCE'   Then Begin ParsePatPrimary:=AddPat(PK_FENCE);   Exit; End;
  If fn='ABORT'   Then Begin ParsePatPrimary:=AddPat(PK_ABORT);   Exit; End;
  If fn='SUCCEED' Then Begin ParsePatPrimary:=AddPat(PK_SUCCEED); Exit; End;
  ndx := AddPat(PK_INDIRECT);  pat_table^[ndx].var_nm := tok;
  ParsePatPrimary := ndx;
End;

{ --------------------------------------------------------------------------
  ParsePatStr : parser le patron brut -> arbre dans pat_table.
  -------------------------------------------------------------------------- }
Function ParsePatStr(Const raw : TString) : Integer;
Var alt_parts   : Array[0..15] of TString;
    concat_toks : Array[0..31] of TString;
    alt_count, tok_count     : Integer;
    root, left, right, node  : Integer;
    i, j                     : Integer;
    has_asgn                 : Boolean;
    asgn_op                  : Char;
    asgn_var, trimmed        : TString;
Begin
  ParsePatStr := 0;
  trimmed := PatTrimStr(raw);
  If trimmed = '' Then Exit;
  PatSplitOnAlt(trimmed, alt_parts, alt_count);
  If alt_count = 0 Then Exit;
  root := 0;
  For i := 0 To alt_count - 1 Do
  Begin
    PatSplitConcat(alt_parts[i], concat_toks, tok_count);
    If tok_count = 0 Then Continue;
    has_asgn := False;  asgn_op := '.';  asgn_var := '';
    If (tok_count >= 3) And
       ((concat_toks[tok_count-2]='.') Or (concat_toks[tok_count-2]='$')) Then
    Begin
      has_asgn  := True;
      asgn_op   := concat_toks[tok_count-2][1];
      asgn_var  := concat_toks[tok_count-1];
      tok_count := tok_count - 2;
    End;
    left := 0;
    For j := 0 To tok_count - 1 Do
    Begin
      node := ParsePatPrimary(concat_toks[j]);
      If node = 0 Then Continue;
      If left = 0 Then left := node
      Else
      Begin
        right := AddPat(PK_CONCAT);
        pat_table^[right].left  := left;
        pat_table^[right].right := node;
        left := right;
      End;
    End;
    If has_asgn And (left <> 0) Then
    Begin
      If asgn_op = '$' Then node := AddPat(PK_IMMED)
      Else                   node := AddPat(PK_ASSIGN);
      pat_table^[node].left   := left;
      pat_table^[node].var_nm := asgn_var;
      left := node;
    End;
    If left = 0 Then Continue;
    If root = 0 Then root := left
    Else
    Begin
      node := AddPat(PK_ALT);
      pat_table^[node].left  := root;
      pat_table^[node].right := left;
      root := node;
    End;
  End;
  ParsePatStr := root;
End;

{ --------------------------------------------------------------------------
  GenEmitPatNode : generer le code ASM pour un noeud du patron.
  idx      = index dans pat_table (1-base)
  fail_lbl = label ASM de saut sur echec
  -------------------------------------------------------------------------- }
Procedure GenEmitPatNode(idx : Integer; Const fail_lbl : TString);
Var nd       : TPatNode;
    alt_fl   : TString;
    alt_done : TString;
    asn_fl   : TString;
    asn_done : TString;
Begin
  If (idx <= 0) Or (idx > pat_count) Then Exit;
  nd := pat_table^[idx];
  Case nd.kind Of
    PK_LIT :
    Begin
      EmitI('LEA  DI, [' + LitDescLabel(nd.lit_idx) + ']');
      EmitI('CALL _RT_MATCH_LIT');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_ANY :
    Begin
      EmitI('LEA  DI, [' + LitDescLabel(nd.set_idx) + ']');
      EmitI('CALL _RT_MATCH_ANY');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_NOTANY :
    Begin
      EmitI('LEA  DI, [' + LitDescLabel(nd.set_idx) + ']');
      EmitI('CALL _RT_MATCH_NOTANY');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_SPAN :
    Begin
      EmitI('LEA  DI, [' + LitDescLabel(nd.set_idx) + ']');
      EmitI('CALL _RT_MATCH_SPAN');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_BREAK, PK_BREAKX :
    Begin
      EmitI('LEA  DI, [' + LitDescLabel(nd.set_idx) + ']');
      EmitI('CALL _RT_MATCH_BREAK');
    End;
    PK_LEN :
    Begin
      EmitI('MOV  CX, ' + IntToStr(nd.int_val));
      EmitI('CALL _RT_MATCH_LEN');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_POS :
    Begin
      EmitI('MOV  CX, ' + IntToStr(nd.int_val));
      EmitI('CALL _RT_MATCH_POS');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_RPOS :
    Begin
      EmitI('MOV  CX, ' + IntToStr(nd.int_val));
      EmitI('CALL _RT_MATCH_RPOS');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_TAB :
    Begin
      EmitI('MOV  CX, ' + IntToStr(nd.int_val));
      EmitI('CALL _RT_MATCH_TAB');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_RTAB :
    Begin
      EmitI('MOV  CX, ' + IntToStr(nd.int_val));
      EmitI('CALL _RT_MATCH_RTAB');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
    PK_REM :
    Begin
      EmitI('CALL _RT_MATCH_REM');
    End;
    PK_ARB, PK_ARBNO :
    Begin
      EmitI('CALL _RT_MATCH_ARB');
    End;
    PK_FAIL :
    Begin
      EmitI('JMP  ' + fail_lbl);
    End;
    PK_SUCCEED, PK_FENCE :
    Begin
      EmitComment('PK_SUCCEED/FENCE : succes immediat');
    End;
    PK_ABORT :
    Begin
      EmitI('JMP  _SB_END_PROG');
    End;
    PK_CONCAT :
    Begin
      GenEmitPatNode(nd.left,  fail_lbl);
      GenEmitPatNode(nd.right, fail_lbl);
    End;
    PK_ALT :
    Begin
      alt_fl   := NewLabel;
      alt_done := NewLabel;
      EmitI('PUSH BX');
      GenEmitPatNode(nd.left, alt_fl);
      EmitI('ADD  SP, 2');
      EmitI('JMP  ' + alt_done);
      EmitLabel(alt_fl);
      EmitI('POP  BX');
      GenEmitPatNode(nd.right, fail_lbl);
      EmitLabel(alt_done);
    End;
    PK_ASSIGN, PK_IMMED :
    Begin
      asn_fl   := NewLabel;
      asn_done := NewLabel;
      EmitI('PUSH BX');
      GenEmitPatNode(nd.left, asn_fl);
      EmitI('POP  AX');
      EmitI('PUSH BX');
      EmitI('PUSH SI');
      EmitI('MOV  CX, BX');
      EmitI('SUB  CX, AX');
      EmitI('INC  AX');
      EmitI('CALL _RT_SUBSTR');
      EmitI('POP  SI');
      EmitI('POP  BX');
      EmitStoreVarDesc(nd.var_nm);
      EmitI('JMP  ' + asn_done);
      EmitLabel(asn_fl);
      EmitI('POP  AX');
      EmitI('JMP  ' + fail_lbl);
      EmitLabel(asn_done);
    End;
    PK_INDIRECT :
    Begin
      EmitComment('PK_INDIRECT : ' + nd.var_nm);
      EmitI('LEA  DI, [' + AsmVarDesc(nd.var_nm) + ']');
      EmitI('CALL _RT_MATCH_LIT');
      EmitI('CMP  AX, 1');
      EmitI('JNE  ' + fail_lbl);
    End;
  End;
End;

{ --------------------------------------------------------------------------
  GenMatchInstruction : code complet d'une instruction de matching.
  -------------------------------------------------------------------------- }
Procedure GenMatchInstruction;
Var pat_root       : Integer;
    lbl_retry      : TString;
    lbl_pat_fail   : TString;
    lbl_match_fail : TString;
    lbl_done       : TString;
Begin
  EmitComment('Matching : ' + inst_subject + ' ' + inst_pattern);
  pat_root := ParsePatStr(inst_pattern);
  If pat_root = 0 Then
  Begin
    EmitComment('  Patron vide : succes immediat');
    If inst_goto_u <> '' Then EmitGotoJmp(inst_goto_u)
    Else If inst_goto_s <> '' Then EmitGotoJmp(inst_goto_s);
    EmitBlank;
    Exit;
  End;
  lbl_retry      := NewLabel;
  lbl_pat_fail   := NewLabel;
  lbl_match_fail := NewLabel;
  lbl_done       := NewLabel;
  EmitI('LEA  SI, [' + AsmVarDesc(inst_subject) + ']');
  EmitI('XOR  BX, BX');
  EmitLabel(lbl_retry);
  EmitI('PUSH BX');
  GenEmitPatNode(pat_root, lbl_pat_fail);
  EmitI('ADD  SP, 2');
  If inst_has_eq Then
  Begin
    EmitComment('  Remplacement : ' + inst_subject + ' = ' + inst_repl);
    EvalExpr(inst_repl);
    EmitStoreVarDesc(inst_subject);
  End;
  If inst_goto_u <> '' Then EmitGotoJmp(inst_goto_u)
  Else If inst_goto_s <> '' Then EmitGotoJmp(inst_goto_s);
  EmitI('JMP  ' + lbl_done);
  EmitLabel(lbl_pat_fail);
  EmitI('POP  BX');
  EmitI('CMP  WORD PTR [_SB_VAR_ANCHOR], 0');
  EmitI('JNE  ' + lbl_match_fail);
  EmitI('INC  BX');
  EmitI('CMP  BX, [SI+2]');
  EmitI('JBE  ' + lbl_retry);
  EmitLabel(lbl_match_fail);
  If inst_goto_u <> '' Then EmitGotoJmp(inst_goto_u)
  Else If inst_goto_f <> '' Then EmitGotoJmp(inst_goto_f);
  EmitLabel(lbl_done);
  EmitBlank;
End;
{ --------------------------------------------------------------------------
  GenSimpleAccess : generer le code d'un simple acces (sujet seul, sans patron
  ni remplacement). En SNOBOL4 : teste si la variable est definie (non-echec).
  En v1 : simple no-op avec gestion goto.
  -------------------------------------------------------------------------- }
Procedure GenSimpleAccess;
Begin
  EmitComment('Acces : ' + inst_subject + ' (test existence)');
  EmitComment('  v1 : non-implementee, traite comme succes');
  EmitGotoSection;
  EmitBlank;
End;

{ ============================================================================
  TODO 21 - PARSER ET CODEGEN : DEFINITION DE FONCTIONS (DEFINE)
  ============================================================================
  ParseDefinePrototype  : extraire nom et params depuis 'nom(p1,p2,...)'.
  GenFunctionEntry      : emettre prologue PUSH BP/MOV BP,SP/alloc locaux.
  GenFunctionReturnStubs: emettre _SB_RETURN, _SB_FRETURN, _SB_NRETURN.
  GenDefineInstruction  : traiter DEFINE('proto','entry') -> func_table.
  GenUserFuncCall       : emettre PUSH args + CALL _SBF_xxx (caller cleanup).
  Convention frame (near call, caller cleanup cdecl) :
    [BP+0]    = ancien BP  (PUSH BP)
    [BP+2]    = adresse retour proche (near CALL)
    [BP+4]    = param 1  (2 octets = pointeur descripteur near)
    [BP+6]    = param 2
    [BP+4+(i-1)*2] = param i
    [BP-4]    = local 1  (4 octets par local : desc ptr + len)
    [BP-8]    = local 2
  Retour : DI = desc resultat, AX = 1 (RETURN/NRETURN) ou 0 (FRETURN).
  ============================================================================ }

{ --------------------------------------------------------------------------
  ParseDefinePrototype : parser 'nom(p1,p2,...)' (sans guillemets).
  Remplit fname (en maj.), params[0..nparams-1], nparams.
  Ex : 'F(A,B,C)' -> fname='F', params=['A','B','C'], nparams=3.
  -------------------------------------------------------------------------- }
Procedure ParseDefinePrototype(Const proto : TString;
                               Var fname   : TString;
                               Var params  : Array of TString;
                               Var nparams : Integer);
Var i, j, paren : Integer;
    tok          : TString;
Begin
  nparams := 0;
  fname   := '';
  paren   := Pos('(', proto);
  If paren = 0 Then
  Begin
    fname := UpCaseStr(PatTrimStr(proto));
    Exit;
  End;
  fname := UpCaseStr(PatTrimStr(Copy(proto, 1, paren - 1)));
  i := paren + 1;
  While i <= Length(proto) Do
  Begin
    If proto[i] = ')' Then Break;
    j := i;
    While (j <= Length(proto)) And Not (proto[j] In [',', ')']) Do Inc(j);
    tok := UpCaseStr(PatTrimStr(Copy(proto, i, j - i)));
    If (tok <> '') And (nparams <= High(params)) Then
    Begin
      params[nparams] := tok;
      Inc(nparams);
    End;
    i := j + 1;
  End;
End;

{ --------------------------------------------------------------------------
  GenFunctionEntry : emettre le prologue d'une fonction utilisateur.
  Appele juste apres le label d'entree de la fonction.
  -------------------------------------------------------------------------- }
Procedure GenFunctionEntry(Const fi : Integer);
Var i  : Integer;
    fe : TFuncEntry;
Begin
  fe := func_table^[fi];
  cur_func_idx := fi;
  EmitComment('--- Prologue fonction ' + fe.name + ' ---');
  EmitI('PUSH BP');
  EmitI('MOV  BP, SP');
  If fe.local_count > 0 Then
    EmitI('SUB  SP, ' + IntToStr(fe.local_count * 4) + '   ; frame locaux');
  For i := 1 To fe.param_count Do
    EmitComment('  Param ' + IntToStr(i) + ' : ' + fe.params[i].name +
                ' -> [BP+' + IntToStr(fe.params[i].bp_offset) + ']');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenFunctionReturnStubs : emettre les labels globaux de retour.
  Doit etre appele une seule fois depuis GenFooter (ou Compile).
  _SB_RETURN   : DI=desc resultat, AX=1 (succes).
  _SB_FRETURN  : DI=_SB_EMPTY_DESC,  AX=0 (echec).
  _SB_NRETURN  : DI=_SB_EMPTY_DESC,  AX=1 (succes sans valeur).
  v1 : suppose frame_size=0 (pas de locaux). Caller cleanup (cdecl).
  -------------------------------------------------------------------------- }
Procedure GenFunctionReturnStubs;
Begin
  EmitComment('Stubs de retour de fonctions utilisateur');
  EmitLabel('_SB_RETURN');
  EmitI('MOV  AX, 1              ; succes : DI = desc resultat');
  EmitI('POP  BP');
  EmitI('RET');
  EmitBlank;
  EmitLabel('_SB_FRETURN');
  EmitI('XOR  AX, AX            ; echec : AX=0');
  EmitI('LEA  DI, [_SB_EMPTY_DESC]');
  EmitI('POP  BP');
  EmitI('RET');
  EmitBlank;
  EmitLabel('_SB_NRETURN');
  EmitI('MOV  AX, 1              ; retour sans valeur');
  EmitI('LEA  DI, [_SB_EMPTY_DESC]');
  EmitI('POP  BP');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDefineInstruction : traiter DEFINE('proto','entry').
  Enregistre la fonction dans func_table avec ses parametres.
  N'emet pas de code ASM (declaratif a la compilation).
  fargs = contenu des parentheses de l'appel DEFINE.
  -------------------------------------------------------------------------- }
Procedure GenDefineInstruction(Const fargs : TString);
Var args     : Array[0..3] of TString;
    nargs    : Integer;
    proto    : TString;
    entry    : TString;
    pnames   : Array[0..MAX_PARAM-1] of TString;
    nparams  : Integer;
    fname    : TString;
    fi, si   : Integer;
    i        : Integer;
Begin
  SplitArgsComma(fargs, args, nargs);
  If nargs < 1 Then
  Begin
    EmitComment('; DEFINE : argument prototype manquant');
    Exit;
  End;
  proto := StripStringLiteral(PatTrimStr(args[0]));
  If nargs >= 2 Then
    entry := UpCaseStr(StripStringLiteral(PatTrimStr(args[1])))
  Else
    entry := '';
  ParseDefinePrototype(proto, fname, pnames, nparams);
  If fname = '' Then
  Begin
    EmitComment('; DEFINE : nom de fonction vide');
    Exit;
  End;
  fi := FindFunc(fname);
  If fi = 0 Then
    fi := AddFunc(fname, SUB_FUNC);
  If fi = 0 Then
  Begin
    EmitComment('; DEFINE : table des fonctions pleine');
    Exit;
  End;
  func_table^[fi].kind        := SUB_FUNC;
  func_table^[fi].entry_label := entry;
  func_table^[fi].param_count := nparams;
  func_table^[fi].param_bytes := nparams * 2;
  func_table^[fi].local_count := 0;
  func_table^[fi].frame_size  := 0;
  For i := 1 To nparams Do
  Begin
    func_table^[fi].params[i].name      := pnames[i-1];
    func_table^[fi].params[i].bp_offset := 4 + (i - 1) * 2;
  End;
  si := FindSym(fname);
  If si < 0 Then
    si := AddSym(fname, SK_FUNC, VK_UNDEF);
  EmitComment('; DEFINE : ' + fname + '(' + IntToStr(nparams) +
              ' param(s)) entree=' + entry);
End;

{ --------------------------------------------------------------------------
  GenUserFuncCall : emettre l'appel a une fonction utilisateur.
  Convention cdecl : push args droite->gauche, caller cleanup apres CALL.
  Resultat : DI = descripteur retourne, AX = 1 si succes, 0 si echec.
  -------------------------------------------------------------------------- }
Procedure GenUserFuncCall(Const fname : TString; Const fargs : TString);
Var args    : Array[0..MAX_PARAM-1] of TString;
    nargs   : Integer;
    fi      : Integer;
    fn      : TString;
    asm_lbl : TString;
    i       : Integer;
Begin
  fn     := UpCaseStr(fname);
  fi     := FindFunc(fn);
  If fi > 0 Then
    asm_lbl := func_table^[fi].asm_label
  Else
    asm_lbl := SB_FUN_PFX + AsmSafeIdent(fn);
  SplitArgsComma(fargs, args, nargs);
  EmitComment('Appel utilisateur ' + fn + '(' + fargs + ')');
  For i := nargs - 1 DownTo 0 Do
  Begin
    EvalExprToken(args[i]);
    EmitI('PUSH DI             ; arg ' + IntToStr(i + 1));
  End;
  EmitI('CALL ' + asm_lbl);
  If nargs > 0 Then
    EmitI('ADD  SP, ' + IntToStr(nargs * 2) + '   ; caller cleanup');
  EmitComment('  AX=1->succes DI=desc  AX=0->echec');
End;
{ ============================================================================
  TODO 22 - CODEGEN : PREDICATS ET OPERATEURS DE COMPARAISON
  ============================================================================
  GenPredicateCall : dispatcher pour LT/LE/GT/GE/EQ/NE (numeriques),
                     IDENT/DIFFER (chaines) et INTEGER/REAL/NUMERIC (types).
  Convention SNOBOL : predicat retourne son premier argument si vrai,
                      provoque FAIL (goto_f) si faux.
  _RT_ICOMPARE : CMP AX, BX (entiers signes) -> flags
  _RT_STRCMP   : SI=desc1, DI=desc2 -> flags (ZF=egal, CF=SI<DI)
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenPredicateCall : emettre le code d'un predicat SNOBOL.
  fn    = nom du predicat en majuscules.
  nargs = nombre d'arguments parsed.
  args  = tableau des arg bruts (chaines, vars, exprs).
  Resultat succes : DI = descripteur de args[0].
  Resultat echec  : branchement vers inst_goto_f (ou inst_goto_u si vide).
  -------------------------------------------------------------------------- }
Procedure GenPredicateCall(Const fn : TString; nargs : Integer;
                           Var args : Array of TString);
Var lbl_fail : TString;
    lbl_done : TString;
    jmp_fail : TString;
Begin
  lbl_fail := NewLabel;
  lbl_done := NewLabel;

  { ---- Comparaisons numeriques : LT LE GT GE EQ NE ---- }
  If (fn='LT') Or (fn='LE') Or (fn='GT') Or (fn='GE') Or
     (fn='EQ') Or (fn='NE') Then
  Begin
    EmitComment('Predicat numerique ' + fn);
    { Sauvegarder le descripteur de arg0 pour le retour succes }
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI                    ; [1] conserver desc arg0');
    { AX = valeur entiere de arg0 }
    If nargs >= 1 Then EvalArgAsInt(args[0])
    Else EmitI('MOV  AX, 0');
    EmitI('PUSH AX                    ; [2] AX arg0');
    { BX = valeur entiere de arg1 }
    If nargs >= 2 Then EvalArgAsInt(args[1])
    Else EmitI('MOV  AX, 0');
    EmitI('MOV  BX, AX');
    EmitI('POP  AX                    ; [2] AX = arg0 int');
    EmitI('CALL _RT_ICOMPARE          ; CMP AX, BX -> flags');
    { Saut sur echec selon le predicat }
    If      fn = 'LT' Then jmp_fail := 'JGE'
    Else If fn = 'LE' Then jmp_fail := 'JG '
    Else If fn = 'GT' Then jmp_fail := 'JLE'
    Else If fn = 'GE' Then jmp_fail := 'JL '
    Else If fn = 'EQ' Then jmp_fail := 'JNE'
    Else                    jmp_fail := 'JE ';  { NE }
    EmitI(jmp_fail + '  ' + lbl_fail + '   ; echec predicat ' + fn);
    { Succes : DI = desc arg0 }
    EmitI('POP  SI                    ; [1] SI = desc arg0');
    EmitI('MOV  DI, SI');
  End

  { ---- Comparaisons de chaines : IDENT DIFFER ---- }
  Else If (fn = 'IDENT') Or (fn = 'DIFFER') Then
  Begin
    EmitComment('Predicat chaine ' + fn);
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('PUSH SI                    ; [1] conserver desc arg0');
    If nargs >= 2 Then EvalArgAsDesc(args[1])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('MOV  DI, SI                ; DI = desc arg1');
    EmitI('POP  SI                    ; [1] SI = desc arg0');
    EmitI('CALL _RT_STRCMP            ; SI=arg0, DI=arg1 -> flags (ZF=egal)');
    If fn = 'IDENT' Then
      EmitI('JNE  ' + lbl_fail + '   ; IDENT : echec si differents')
    Else
      EmitI('JE   ' + lbl_fail + '   ; DIFFER : echec si egaux');
    { Succes : DI = desc arg0 }
    EmitI('MOV  DI, SI                ; DI = arg0 (valeur retournee)');
  End

  { ---- Predicats de type : INTEGER REAL NUMERIC (stub v1 -> succes) ---- }
  Else
  Begin
    EmitComment('Predicat type ' + fn + ' : stub v1 (succes si arg defini)');
    If nargs >= 1 Then EvalArgAsDesc(args[0])
    Else EmitI('LEA  SI, [_SB_EMPTY_DESC]');
    EmitI('MOV  DI, SI                ; DI = arg0 (valeur retournee)');
    EmitI('JMP  ' + lbl_done + '      ; type check stub : toujours succes');
  End;

  EmitI('JMP  ' + lbl_done);

  { ---- Echec du predicat ---- }
  EmitLabel(lbl_fail);
  If fn = 'LT' Then EmitI('ADD  SP, 2   ; liberer desc arg0 sauvegarde')
  Else If fn = 'LE' Then EmitI('ADD  SP, 2')
  Else If fn = 'GT' Then EmitI('ADD  SP, 2')
  Else If fn = 'GE' Then EmitI('ADD  SP, 2')
  Else If fn = 'EQ' Then EmitI('ADD  SP, 2')
  Else If fn = 'NE' Then EmitI('ADD  SP, 2');
  EmitI('LEA  DI, [_SB_EMPTY_DESC]   ; predicat echec : DI = vide');
  If inst_goto_f <> '' Then EmitGotoJmp(inst_goto_f)
  Else If inst_goto_u <> '' Then EmitGotoJmp(inst_goto_u);

  { ---- Done ---- }
  EmitLabel(lbl_done);
  EmitBlank;
End;
{ ============================================================================
  TODO 23 - GESTION DES VARIABLES SYSTEME (&xxx)
  ============================================================================
  SysVarAsmLabel  : 'ANCHOR' -> '_SB_SYS_ANCHOR'
  GenLoadSysVar   : charger &xxx dans DI (descripteur string)
  GenStoreSysVar  : stocker DI (desc string) dans &xxx
  Variables numeriques : _RT_INT2STR / _RT_STR2INT
  &INPUT  : CALL _RT_READLINE -> DI (stub ; TODO 24 fournira le runtime)
  &OUTPUT : MOV SI,DI + CALL _RT_WRITELINE (stub ; TODO 24)
  ============================================================================ }

{ --------------------------------------------------------------------------
  SysVarAsmLabel : traduire le nom (sans '&') en label ASM .DATA.
  Ex : 'ANCHOR' -> '_SB_SYS_ANCHOR'
  -------------------------------------------------------------------------- }
Function SysVarAsmLabel(Const nm : TString) : TString;
Begin
  SysVarAsmLabel := '_SB_SYS_' + UpCaseStr(nm);
End;

{ --------------------------------------------------------------------------
  GenLoadSysVar : charger la valeur d'une variable systeme dans DI.
  nm = nom sans '&', peut etre en casse quelconque.
  Post : DI = adresse descripteur (string) representant la valeur.
  Variables numeriques exportees comme string via _RT_INT2STR.
  -------------------------------------------------------------------------- }
Procedure GenLoadSysVar(Const nm : TString);
Var u : TString;
Begin
  u := UpCaseStr(nm);
  EmitComment('Load sysvar &' + u);
  If u = 'INPUT' Then
  Begin
    EmitI('CALL _RT_READLINE          ; &INPUT : lire ligne stdin -> DI');
  End
  Else If u = 'ALPHABET' Then
  Begin
    EmitI('LEA  DI, [_SB_SYS_ALPHABET_D]  ; &ALPHABET');
  End
  Else If u = 'FAIL' Then
  Begin
    EmitI('LEA  DI, [_SB_FAIL_DESC]   ; &FAIL');
  End
  Else If (u = 'OUTPUT') Or (u = 'SUBJECT') Then
  Begin
    EmitI('LEA  DI, [_SB_SYS_' + u + '_D]  ; &' + u + ' desc');
  End
  Else If (u = 'SUCCESS') Or (u = 'FENCE') Then
  Begin
    EmitI('LEA  DI, [_SB_EMPTY_DESC]   ; &' + u + ' : patron stub');
  End
  Else
  Begin
    { Sysvar numerique : charger DW -> AX -> _RT_INT2STR -> DI }
    EmitI('MOV  AX, [' + SysVarAsmLabel(u) + ']    ; &' + u);
    EmitI('CALL _RT_INT2STR             ; AX -> DI (desc chaine)');
  End;
End;

{ --------------------------------------------------------------------------
  GenStoreSysVar : stocker le descripteur DI dans une variable systeme.
  nm = nom sans '&', peut etre en casse quelconque.
  Variables numeriques : convertir desc -> AX -> stocker en DW.
  -------------------------------------------------------------------------- }
Procedure GenStoreSysVar(Const nm : TString);
Var u : TString;
Begin
  u := UpCaseStr(nm);
  EmitComment('Store sysvar &' + u);
  If u = 'OUTPUT' Then
  Begin
    EmitI('MOV  SI, DI');
    EmitI('CALL _RT_WRITELINE          ; &OUTPUT : ecrire SI sur stdout');
  End
  Else If u = 'SUBJECT' Then
  Begin
    EmitI('PUSH AX');
    EmitI('MOV  AX, [DI]');
    EmitI('MOV  [_SB_SYS_SUBJECT_D],   AX  ; stocker ptr');
    EmitI('MOV  AX, [DI+2]');
    EmitI('MOV  [_SB_SYS_SUBJECT_D+2], AX  ; stocker len');
    EmitI('POP  AX');
  End
  Else If (u = 'INPUT') Or (u = 'ALPHABET') Or (u = 'FAIL') Or
          (u = 'FENCE') Or (u = 'SUCCESS') Then
  Begin
    EmitComment('  &' + u + ' : lecture seule, affectation ignoree');
  End
  Else
  Begin
    { Sysvar numerique : desc DI -> AX int -> stocker DW }
    EmitI('MOV  SI, DI');
    EmitI('CALL _RT_STR2INT             ; SI=desc -> AX entier');
    EmitI('MOV  [' + SysVarAsmLabel(u) + '], AX     ; &' + u);
  End;
End;
{ ============================================================================
  TODO 24 - GESTION DE L'ENTREE/SORTIE (INPUT / OUTPUT)
  _RT_READLINE  : lire une ligne de stdin (INT 21h AH=0Ah) dans _SB_INPUTBUF,
                  construire un descripteur dans _SB_SYS_INPUT_D,
                  retourner DI=&_SB_SYS_INPUT_D, AX=1 succes / AX=0 EOF.
  _RT_WRITELINE : ecrire la chaine decrite par SI sur stdout (INT 21h AH=40h),
                  suivie de CRLF, retourner AX=1.
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenReadlineRuntime : emettre _RT_READLINE dans le segment .CODE.
  Retour : DI = adresse _SB_SYS_INPUT_D, AX = 1 (succes) ou AX = 0 (EOF).
  -------------------------------------------------------------------------- }
Procedure GenReadlineRuntime;
Begin
  EmitSep;
  EmitComment('_RT_READLINE : lire une ligne stdin -> descripteur _SB_SYS_INPUT_D');
  EmitSep;
  EmitLabel('_RT_READLINE');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitComment('INT 21h AH=0Ah : saisie tamponnee sur stdin');
  EmitI('MOV  AH, 0Ah');
  EmitI('LEA  DX, [_SB_INPUTBUF]');
  EmitI('INT  21h');
  EmitComment('Longueur reelle = _SB_INPUTBUF+1');
  EmitI('XOR  CX, CX');
  EmitI('MOV  CL, [_SB_INPUTBUF+1]');
  EmitComment('Longueur nulle => ligne vide; 1Ah en premier => EOF DOS');
  EmitI('CMP  CX, 0');
  EmitI('JE   _RT_READLINE_EOF');
  EmitI('LEA  BX, [_SB_INPUTBUF+2]');
  EmitI('MOV  AL, [BX]');
  EmitI('CMP  AL, 1Ah              ; Ctrl+Z = EOF DOS');
  EmitI('JE   _RT_READLINE_EOF');
  EmitComment('Construire descripteur : ptr = &_SB_INPUTBUF+2, len = CX');
  EmitI('LEA  DI, [_SB_SYS_INPUT_D]');
  EmitI('MOV  [DI],   BX           ; ptr -> donnees');
  EmitI('MOV  [DI+2], CX           ; len = chars lus');
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('MOV  AX, 1                ; AX=1 => succes');
  EmitI('RET');
  EmitLabel('_RT_READLINE_EOF');
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('XOR  AX, AX               ; AX=0 => EOF/echec');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenWritelineRuntime : emettre _RT_WRITELINE dans le segment .CODE.
  Convention d'appel : SI = adresse du descripteur a ecrire.
  Retour : AX = 1.
  -------------------------------------------------------------------------- }
Procedure GenWritelineRuntime;
Begin
  EmitSep;
  EmitComment('_RT_WRITELINE : ecrire chaine [SI] sur stdout + CRLF');
  EmitSep;
  EmitLabel('_RT_WRITELINE');
  EmitI('PUSH BX');
  EmitI('PUSH CX');
  EmitI('PUSH DX');
  EmitComment('Extraire len et ptr du descripteur SI');
  EmitI('MOV  DX, [SI]             ; ptr donnees');
  EmitI('MOV  CX, [SI+2]           ; len');
  EmitI('CMP  CX, 0');
  EmitI('JE   _RT_WRITELINE_CRLF   ; chaine vide : sauter au CRLF');
  EmitComment('INT 21h AH=40h : ecrire CX octets sur stdout (handle 1)');
  EmitI('MOV  AH, 40h');
  EmitI('MOV  BX, 1                ; handle stdout');
  EmitI('INT  21h');
  EmitLabel('_RT_WRITELINE_CRLF');
  EmitComment('Ecrire CRLF');
  EmitI('MOV  AH, 40h');
  EmitI('MOV  BX, 1');
  EmitI('MOV  CX, 2');
  EmitI('LEA  DX, [_SB_CRLF_BUF]');
  EmitI('INT  21h');
  EmitI('POP  DX');
  EmitI('POP  CX');
  EmitI('POP  BX');
  EmitI('MOV  AX, 1');
  EmitI('RET');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenIORuntime : emettre toutes les routines I/O dans le segment .CODE.
  Appelee depuis l'orchestrateur de passe 2 (TODO 25).
  -------------------------------------------------------------------------- }
Procedure GenIORuntime;
Begin
  EmitSep;
  EmitComment('=== Runtime : entree / sortie (stdin / stdout) ===');
  EmitSep;
  EmitBlank;
  GenReadlineRuntime;
  GenWritelineRuntime;
End;

{ ============================================================================
  TODO 25 - PROCEDURE COMPILE ET ORCHESTRATION DEUX PASSES
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenInstruction : dispatcher apres ParseInstruction.
  -------------------------------------------------------------------------- }
Procedure GenInstruction;
Var subj_up  : TString;
    auto_lbl : TString;
Begin
  GenLabelDef;
  If first_instr_lbl = '' Then
  Begin
    If inst_label <> '' Then
      SetFirstInstrLabel(SB_LBL_PFX + AsmSafeIdent(UpCaseStr(inst_label)))
    Else
    Begin
      auto_lbl := NewLabel;
      EmitLabel(auto_lbl);
      SetFirstInstrLabel(auto_lbl);
    End;
  End;
  If (inst_subject = '') And (inst_pattern = '') And (Not inst_has_eq) Then
  Begin
    If (inst_goto_u <> '') Or (inst_goto_s <> '') Or (inst_goto_f <> '') Then
      EmitGotoSection;
    Exit;
  End;
  GenStcountCheck;
  subj_up := UpCaseStr(inst_subject);
  If (Length(subj_up) >= 7) And (Copy(subj_up, 1, 7) = 'DEFINE(') Then
    GenDefineInstruction(Copy(inst_subject, 8, Length(inst_subject) - 8))
  Else If inst_pattern <> '' Then
    GenMatchInstruction
  Else If inst_has_eq Then
    GenSimpleAssign
  Else
    GenSimpleAccess;
End;

{ --------------------------------------------------------------------------
  CopyTmpToOut : re-ouvrir tmp_file en lecture et recopier dans out_file.
  -------------------------------------------------------------------------- }
Procedure CopyTmpToOut;
Var line : String;
Begin
  EmitComment('--- Code programme SNOBOL (passe 1) ---');
  {$I-}
  Reset(tmp_file);
  {$I+}
  If IOResult <> 0 Then Begin Warning('CopyTmpToOut : relecture impossible : ' + tmp_fname); Exit; End;
  While Not Eof(tmp_file) Do
  Begin
    ReadLn(tmp_file, line);
    WriteLn(out_file, line);
  End;
  CloseFile(tmp_file);
  tmp_open := False;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Compile : orchestrateur principal - passe 1 puis passe 2.
  -------------------------------------------------------------------------- }
Procedure Compile;
Begin
  If ParamStr(1) = '' Then
  Begin
    WriteLn('SNOBOL86 v', SNOBOL86_VERSION, ' - compilateur SNOBOL 4 -> 8086 MASM');
    WriteLn('Usage : SNOBOL86 source.SBL [sortie.ASM]');
    Halt(1);
  End;
  src_fname := ParamStr(1);
  If ParamStr(2) <> '' Then
    out_fname := ParamStr(2)
  Else
  Begin
    out_fname := src_fname;
    If (Length(out_fname) > 4) And
       (UpCaseStr(Copy(out_fname, Length(out_fname)-3, 4)) = '.SBL') Then
      Delete(out_fname, Length(out_fname)-3, 4);
    out_fname := out_fname + '.ASM';
  End;
  tmp_fname := src_fname + '.TMP';
  WriteLn('SNOBOL86 v', SNOBOL86_VERSION, ' - compilation : ', src_fname, ' -> ', out_fname);
  InitSymTable;
  InitLabelTable;
  InitPatTable;
  InitFuncTable;
  InitFwdTable;
  InitPredefined;
  {$I-}
  Assign(src_file, src_fname); Reset(src_file);
  {$I+}
  If IOResult <> 0 Then Begin WriteLn('ERREUR : impossible d''ouvrir : ', src_fname); Halt(2); End;
  {$I-}
  Assign(tmp_file, tmp_fname); Rewrite(tmp_file);
  {$I+}
  If IOResult <> 0 Then Begin CloseFile(src_file); WriteLn('ERREUR : impossible de creer : ', tmp_fname); Halt(2); End;
  tmp_open := True;
  cur_out  := @tmp_file;
  lex_at_eof := False;
  { PASSE 1 }
  While LexReadLine Do
  Begin
    If lex_line = SB_END_SENTINEL Then
    Begin
      GenEndSentinel; Break;
    End;
    ParseInstruction;
    GenInstruction;
    Inc(instr_count);
  End;
  CloseFile(src_file);
  If tmp_open Then Begin CloseFile(tmp_file); tmp_open := False; End;
  { PASSE 2 }
  {$I-}
  Assign(out_file, out_fname); Rewrite(out_file);
  {$I+}
  If IOResult <> 0 Then Begin WriteLn('ERREUR : impossible de creer : ', out_fname); Halt(2); End;
  cur_out := @out_file;
  GenHeader;
  GenDataSegment;
  GenCodeSegHeader;
  GenInitIO;
  GenInitSysVars;
  {$I-}
  Assign(tmp_file, tmp_fname);
  {$I+}
  CopyTmpToOut;
  GenEndProg;
  GenDumpVarsStub;
  GenHeapRuntime;
  GenStringRuntime;
  GenArithRuntime;
  GenTableRuntime;
  GenArrayRuntime;
  GenFunctionReturnStubs;
  GenIORuntime;
  ResolveForwardRefs;
  GenFooter;
  CloseFile(out_file);
  {$I-} Assign(tmp_file, tmp_fname); Erase(tmp_file); {$I+}
  BilanCompilation;
  DisposeAllTables;
End;

Begin
  { Initialiser les pointeurs a Nil pour securiser DisposeAllTables }
  sym_table   := Nil;
  label_table := Nil;
  pat_table   := Nil;
  func_table  := Nil;
  fwd_table   := Nil;
  cur_out     := @out_file;   { sortie par defaut : out_file }
  { Options compilateur }
  opt_list      := False;
  opt_debug     := DBG_NONE;
  opt_strict    := False;
  opt_heap_size := HEAP_DEFAULT;
  { Compteurs }
  err_count    := 0;
  warn_count   := 0;
  src_line_num := 0;
  instr_count  := 0;
  { Fichiers }
  lst_open     := False;
  tmp_open     := False;
  lbl_seq      := 0;
  str_top      := 0;
  main_proc_label := '';
  first_instr_lbl := '';
  cur_func_idx    := 0;
  { TODO 25 : Orchestration de la compilation en deux passes }
  Compile;
End.
