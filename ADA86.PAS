{$A-} {$I-}
{ ============================================================================ }
{  ADA86.PAS  -  Compilateur Ada 83/95 (sous-ensemble) -> Assembleur 8086     }
{  Cible : MASM/TASM, .MODEL SMALL, MS-DOS                                    }
{  Ecrit en Turbo Pascal 7 / Free Pascal 3.2                                   }
{  (c) 2026                                                                    }
{ ============================================================================ }

{ ---------------------------------------------------------------------------- }
{  DESCRIPTION                                                                 }
{ ---------------------------------------------------------------------------- }
{  Compilateur en une seule passe (avec table de symboles) pour un             }
{  sous-ensemble pratique d'Ada 83/95 :                                        }
{    - WITH / USE (packages standard uniquement : Ada.Text_IO,                 }
{      Ada.Integer_Text_IO, Ada.Float_Text_IO)                                 }
{    - PROCEDURE / FUNCTION (imbriquees, recursives)                           }
{    - PACKAGE spec + body (pas de generiques)                                 }
{    - Types : Integer, Float, Boolean, Character, String(n),                  }
{              enumerations, tableaux (Array), enregistrements (Record)        }
{    - Sous-types (SUBTYPE) et constantes (CONSTANT)                           }
{    - Expressions : +,-,*,/,mod,rem,**, comparaisons, and/or/not/xor,        }
{      and then / or else                                                      }
{    - Instructions : affectation (:=), IF/ELSIF/ELSE/END IF,                  }
{      CASE/WHEN/OTHERS/END CASE, LOOP/EXIT/EXIT WHEN/END LOOP,               }
{      WHILE ... LOOP, FOR ... IN ... LOOP, RETURN, NULL                       }
{    - Appels de procedure et de fonction                                      }
{    - Gestion d'exceptions : RAISE, bloc BEGIN/EXCEPTION/END                  }
{    - Pragmas ignores (PRAGMA => skip ligne)                                  }
{  Conventions d'appel : callee-cleanup, push gauche-a-droite, RET n*2        }
{  Code genere : .MODEL SMALL, .STACK 256, MASM/TASM syntaxe Intel            }
{ ---------------------------------------------------------------------------- }

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Lexeur    : SrcGetChar, NextToken -> cur_tok_type / cur_tok_str          }
{  2. Parser    : ParseXxx procedures recursives descendantes                  }
{  3. CodeGen   : Emit / EmitI / EmitLabel / GenXxx procedures                 }
{  4. Symboles  : sym_table (variables/ctes), sub_table (proc/func),          }
{                 type_table (types utilisateur), pkg_table (packages)         }
{  5. Compile   : deux fichiers -> code_tmp puis assemblage final              }
{ ---------------------------------------------------------------------------- }

{ ---------------------------------------------------------------------------- }
{  PLAN DE DEVELOPPEMENT - 25 TODOs                                            }
{ ---------------------------------------------------------------------------- }

{ TODO 01 - Architecture de base, constantes et types internes
  ---------------------------------------------------------------
  - Constantes de tokens (TOK_IDENT, TOK_INTEGER, TOK_FLOAT, TOK_CHAR,
    TOK_STRING, TOK_OP, TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_SEMI,
    TOK_COLON, TOK_COLONASSIGN, TOK_DOT, TOK_DOTDOT, TOK_BAR, TOK_LT,
    TOK_GT, TOK_LE, TOK_GE, TOK_EQ, TOK_NEQ, TOK_ARROW, TOK_EOF,
    TOK_UNKNOWN)
  - Constantes de mots-cles Ada (KW_xxx) : PROCEDURE, FUNCTION, PACKAGE,
    BEGIN, END, IS, WITH, USE, TYPE, SUBTYPE, CONSTANT, ARRAY, RECORD,
    OF, RANGE, IF, THEN, ELSIF, ELSE, CASE, WHEN, OTHERS, LOOP, EXIT,
    WHILE, FOR, IN, REVERSE, RETURN, NULL, RAISE, EXCEPTION, PRAGMA,
    RENAMES, SEPARATE, ABSTRACT, PRIVATE, BODY, AND, OR, NOT, XOR,
    MOD, REM, NEW, ALL, ACCESS, OUT, INOUT
  - Constantes de types Ada internes (TYPE_INT, TYPE_FLOAT, TYPE_BOOL,
    TYPE_CHAR, TYPE_STR, TYPE_ENUM, TYPE_ARRAY, TYPE_RECORD, TYPE_ACCESS,
    TYPE_VOID, TYPE_UNKNOWN)
  - Constantes de classes de stockage (STORE_STATIC, STORE_AUTO, STORE_CONST)
  - Constantes de mode de parametre (PARAM_IN, PARAM_OUT, PARAM_INOUT)
  - Constantes de categorie de sous-programme (SUB_PROC, SUB_FUNC)
  - Constantes de limites (MAX_SYM, MAX_SUB, MAX_TYPE, MAX_PKG, MAX_PARAM,
    MAX_FIELD, MAX_DEPTH, MAX_STR, MAX_LABEL)
  - Types internes enregistrements :
    TSymEntry  (nom, asm_label, type_idx, store_class, bp_offset,
                array_size, char_len, is_const, scope_lev, init_num,
                init_str, has_init)
    TSubEntry  (nom, asm_label, ret_type, param_count, param_names[],
                param_types[], param_modes[], is_forward, is_function)
    TTypeEntry (nom, kind, base_type, lo_bound, hi_bound, field_count,
                field_names[], field_types[], enum_count, enum_names[])
    TPkgEntry  (nom, is_standard)
    TScopeEntry (kind, sub_idx, bp_top, sym_start, lbl_exit, lbl_cont,
                 lbl_end, has_exception, lbl_except)
  - Alias tableaux + pointeurs de tas (PSymTable, PSubTable, etc.)
  - Variables globales (fichiers, options, etat lexeur, prog_name,
    tables + pointeurs, scope_stack + scope_top, compteurs)          }

{ TODO 02 - Lexeur : lecture source et tokenisation
  ---------------------------------------------------
  - SrcGetChar : lecture caractere par caractere, gestion colonnes,
    detection commentaires Ada (-- jusqu'en fin de ligne)
  - SkipWhitespace : espaces, tabulations, fin de ligne
  - LexIdent : identifiant ou mot-cle (insensible a la casse -> upper)
  - LexNumber : entier decimal, base#valeur# (2#1010#, 16#FF#),
    flottant (1.5, 1.5E3, 1.5E-3)
  - LexChar : 'c' -> TOK_CHAR   ('' => apostrophe)
  - LexString : "..." -> TOK_STRING  ("" => guillemet)
  - LexSymbol : :=  /=  >=  <=  =>  ..  et symboles simples
  - NextToken : dispatcher principal -> cur_tok_type / cur_tok_str /
    cur_tok_num / cur_tok_kw
  - Consume : avancer au token suivant
  - TokIsKw, TokIsOp, Expect, ExpectKw : helpers de parsing
  - UpCaseStr, AsmIdent, IntToStr, StrToInt : utilitaires chaines    }

{ TODO 03 - Gestion des erreurs, des avertissements et du bilan
  --------------------------------------------------------------
  - Error(msg) : incrementer error_count, afficher ligne + message,
    continuer (pas de Halt)
  - Warning(msg) : avertissement non bloquant
  - SkipToSemi : consommer jusqu'a ';' pour resynchroniser
  - SkipToEnd  : consommer jusqu'a END correspondant (compteur depth)
  - FatalError(msg) : afficher + Halt(1)
  - BilancCompilation : afficher Stats (symboles, sous-programmes,
    types, erreurs)                                                    }

{ TODO 04 - Tables des symboles : CRUD + resolution de portee
  ------------------------------------------------------------
  - InitSymTable : allocation New() sur le tas + initialisation
  - AddSym(name, type_idx, store_class) : retourne index 1-base
  - FindSym(name) : recherche du scope courant vers global
  - FindSymLocal(name) : dans le scope courant uniquement
  - AddSym: calcul automatique bp_offset pour STORE_AUTO
    (chaque type a une taille : Integer=2, Float=4, Boolean=1,
     Char=1, String=char_len, Array=size*elem_size, Record=sum)
  - GetSymSize(sym_idx) : retourne la taille en octets du symbole   }

{ TODO 05 - Tables des types utilisateur et des sous-programmes
  -------------------------------------------------------------
  - InitTypeTable, AddType, FindType : gestion type_table
  - Types predefinis enregistres au demarrage : INTEGER, FLOAT,
    BOOLEAN, CHARACTER, STRING (index connus par constantes)
  - InitSubTable, AddSub, FindSub : gestion sub_table (proc/func)
  - InitPkgTable, AddPkg, FindPkg : packages importes (WITH)
  - Gestion forward declarations (IS SEPARATE / is_forward)
  - GetTypeSize(type_idx) : taille en octets selon le type          }

{ TODO 06 - Gestion des scopes et de la pile de scopes
  -----------------------------------------------------
  - SK_GLOBAL, SK_PROC, SK_FUNC, SK_BLOCK, SK_LOOP, SK_EXCEPT :
    constantes de categorie de scope
  - PushScope(kind, sub_idx) : empiler + initialiser champs
  - PopScope : depiler, liberer les symboles locaux
  - CurrentScope, CurrentSub : accesseurs
  - AllocLocal(size) : incrementer bp_top, retourner bp_offset
  - EnterLoop(lbl_cont, lbl_end) : enregistrer labels de boucle
  - SetExitLabel, SetContinueLabel : pour EXIT [WHEN] et boucles    }

{ TODO 07 - Generateur de code bas niveau : Emit, labels, helpers
  ---------------------------------------------------------------
  - output_file : Text global (redirigeable vers fichier temp)
  - Emit(s), EmitI(s), EmitLabel(lbl), EmitComment(s), EmitBlank
  - NewLabel : generer @@Lxxxx (compteur label_counter)
  - AsmStrLit(s) : ajouter litteral chaine dans str_table +
    retourner label  _LS1, _LS2 ...
  - DataLbl(name) : normaliser en etiquette ASM (_VAR_xxx)
  - GenLoadVar(sym_idx) : charger variable dans AX (ou DX:AX pour
    float, AL pour char/bool)  selon store_class (STATIC vs AUTO)
  - GenStoreVar(sym_idx) : stocker AX dans variable
  - GenLoadConst(val) : MOV AX, val
  - GenPrologue(frame_size) : PUSH BP / MOV BP,SP / SUB SP,n
  - GenEpilogue(frame_size, param_bytes) : MOV SP,BP / POP BP /
    RET n   (callee-cleanup)
  - GenPushAX, GenPopAX, GenPushDXAX, GenPopDXAX                   }

{ TODO 08 - Parseur d'expressions : ParseExpr, precedences Ada
  -------------------------------------------------------------
  Expression Ada (priorites croissantes) :
    Niveau 1 : and then | or else | xor  (short-circuit)
    Niveau 2 : and | or | xor            (logique bit)
    Niveau 3 : not                       (unaire logique)
    Niveau 4 : = /= < <= > >=           (relationnels)
    Niveau 5 : .. (plage)
    Niveau 6 : + - & (additive + concatenation)
    Niveau 7 : unaire + -
    Niveau 8 : * / mod rem               (multiplicative)
    Niveau 9 : ** abs                    (puissance/valeur absolue)
    Niveau 10 : primaire (lit, ident, appel, (expr), qualif)
  - ParseExpr -> ParseOrElse -> ParseAndThen -> ParseOr -> ParseAnd
    -> ParseNot -> ParseRelation -> ParseSimple -> ParseTerm
    -> ParseFactor -> ParsePrimary
  - ParsePrimary : litteraux entiers/flottants/char/string,
    identifiants (variable ou appel de fonction), (expr),
    TRUE/FALSE, type'(expr) (qualifie), type'FIRST/LAST/LENGTH
  - GenBinaryOp(op) : ADD/SUB/IMUL/IDIV/MOD selon operateur
  - GenRelOp(op) : CMP + Jcc, resultat 0/1 dans AX (Bool)          }

{ TODO 09 - ParseWithUse : WITH et USE
  -------------------------------------
  - WITH pkg1, pkg2, ... ;    -> enregistrer dans pkg_table
  - USE pkg1, pkg2, ... ;     -> activer acces direct aux exports
  - Packages standard reconnus : Ada.Text_IO, Ada.Integer_Text_IO,
    Ada.Float_Text_IO, Ada.Numerics, System
  - Pour tout autre package : avertissement "package non implemente"
  - Marquer les packages importes is_standard := True             }

{ TODO 10 - ParseTypeDecl : declarations de types utilisateur
  ------------------------------------------------------------
  TYPE nom IS definition ;
  SUBTYPE nom IS base [RANGE lo .. hi] ;
  Definitions supportees :
    - (enum1, enum2, ...)        -> type enumere
    - RANGE lo .. hi             -> sous-type entier
    - ARRAY (lo .. hi) OF type  -> tableau 1D borne fixe
    - ARRAY (type RANGE <>) OF type -> non-contraint (stub)
    - RECORD champ : type ; ... END RECORD -> enregistrement
    - NEW type                   -> derivation simple (alias)
    - ACCESS type                -> pointeur (stub ; adresse 16 bits)
  - GenTypeData : pour tableaux/records -> espace .DATA ou pile     }

{ TODO 11 - ParseObjectDecl : declarations d'objets
  --------------------------------------------------
  nom [, nom2 ...] : [CONSTANT] type [:= expr] ;
  - Detecter CONSTANT -> is_const := True, STORE_CONST
  - Variables globales (scope_lev = 0) -> STORE_STATIC, segment .DATA
  - Variables locales (scope_lev > 0)  -> STORE_AUTO, pile BP
  - Evaluer l'expression d'initialisation si presente (constante
    a la compilation ou code d'init au runtime)
  - Pour tableaux : emettre DUP(?) ou bloc d'initialisation
  - Pour records  : emettre un champ par champ               }

{ TODO 12 - ParseProcedureSpec / ParseFunctionSpec : signatures
  -------------------------------------------------------------
  PROCEDURE nom [(params)] ;          -> forward / spec de package
  FUNCTION  nom [(params)] RETURN type ;
  Forme des parametres :
    nom [, nom2] : [IN | IN OUT | OUT] type [:= default]
  - AddSub(nom, ...) avec is_forward := True
  - Enregistrer param_names, param_types, param_modes
  - Pour les OUT/IN OUT : passage par adresse (16 bits)            }

{ TODO 13 - ParseProcedureBody / ParseFunctionBody : corps
  ---------------------------------------------------------
  PROCEDURE nom [(params)] IS
    declarative_part
  BEGIN
    statements
  [EXCEPTION
    exception_handlers]
  END [nom] ;
  - PushScope(SK_PROC / SK_FUNC)
  - ParseDeclarativePart : types, constantes, variables, sous-progs
  - GenPrologue(frame_size)
  - ParseSequenceOfStatements
  - GenEpilogue
  - PopScope
  - Si is_forward : verifier coherence signature               }

{ TODO 14 - ParsePackageSpec / ParsePackageBody
  ----------------------------------------------
  PACKAGE nom IS
    [PRIVATE]
    declarations publiques
  END [nom] ;

  PACKAGE BODY nom IS
    declarations privees
    [BEGIN init_statements END [nom] ;]
  END [nom] ;
  - PackageSpec : enregistrer exports dans sub_table / type_table
  - PackageBody : generer les corps des sous-programmes
  - Init body : generer une procedure _PKG_nompackage_INIT appelee
    au demarrage si BEGIN present
  - Packages Ada.Text_IO : generer stubs Put/Put_Line/Get/Get_Line
    en appelant les helpers runtime                              }

{ TODO 15 - ParseStatement : dispatcher principal des instructions
  ---------------------------------------------------------------
  - Reconnaissance et dispatch vers :
    ParseAssignment, ParseProcedureCall, ParseIf, ParseCase,
    ParseLoop, ParseWhile, ParseFor, ParseReturn, ParseRaise,
    ParseNull, ParseExit, ParseBeginBlock, ParsePragma,
    ParseObjectDecl (debut de declaration detecte par ':')
  - Resynchronisation sur erreur : SkipToSemi
  - Gestion du point-virgule terminateur apres chaque instruction
  - ParseSequenceOfStatements : boucle Until IsEndBoundary          }

{ TODO 16 - ParseAssignment et ParseProcedureCall
  ------------------------------------------------
  ParseAssignment :
    ident [.field | (index)] := expr ;
    - GenLoadAddr(lhs) pour obtenir adresse destination
    - ParseExpr pour RHS
    - GenStoreAddr(lhs)
  ParseProcedureCall :
    nom [(arg1, arg2, ...)] ;
    - FindSub -> verifier argoments vs params
    - Pousser arguments (IN par valeur, OUT/IN OUT par adresse)
    - CALL _ABAP_SUB_nom
    - ADD SP, param_bytes (callee-cleanup, mais emettre pour IN)
  ParseNomQualified : ident.ident (pkg.proc, rec.field, etc.)      }

{ TODO 17 - ParseIf / ParseCase
  ------------------------------
  ParseIf :
    IF cond THEN stmts
    [ELSIF cond THEN stmts]
    [ELSE stmts]
    END IF ;
  - GenLabel pour chaque branche, JZ vers suivant, JMP vers END IF

  ParseCase :
    CASE expr IS
      WHEN valeur [| valeur2 ...] => stmts
      [WHEN OTHERS => stmts]
    END CASE ;
  - CMP + JE pour chaque WHEN
  - ExprType doit etre entier ou enumere
  - Optimisation : table de sauts si valeurs contiguës (optionnel)  }

{ TODO 18 - ParseLoop / ParseWhile / ParseFor / ParseExit
  --------------------------------------------------------
  ParseLoop           : LOOP stmts END LOOP ;   (boucle infinie)
  ParseWhile          : WHILE cond LOOP stmts END LOOP ;
  ParseFor            :
    FOR ident IN [REVERSE] lo .. hi LOOP stmts END LOOP ;
    - Variable de boucle implicite (STORE_AUTO, lecture seule)
    - REVERSE : decrementer de hi vers lo
    - Utiliser CX ou variable locale comme compteur

  ParseExit           :
    EXIT [WHEN cond] ;
    - JMP lbl_end (ou conditionnel)
    - Respecter les boucles imbriquees (scope_stack)

  ParseReturn         :
    RETURN [expr] ;
    - Pour FUNCTION : stocker resultat dans AX (ou DX:AX)
    - JMP lbl_exit                                                  }

{ TODO 19 - ParseExceptionDecl / ParseRaise / ParseExceptionHandler
  -----------------------------------------------------------------
  Declarations : nom : EXCEPTION ;
  RAISE [nom] ;  ->  JMP lbl_except (ou sortie programme)

  Bloc BEGIN ... EXCEPTION ... END :
    - Generer lbl_try, lbl_except
    - WHEN nom | WHEN OTHERS => stmts
    - Mecanisme simple par table de sauts (pas de stack unwinding)
    - Exceptions standard : CONSTRAINT_ERROR, PROGRAM_ERROR,
      STORAGE_ERROR, TASKING_ERROR (stubs sans comportement)        }

{ TODO 20 - ParseArrayOps : acces et affectation de tableaux
  -----------------------------------------------------------
  - Acces indexe : ident(index)  (Ada utilise () pas [])
  - Calcul d'adresse : base + (index - lo_bound) * elem_size
  - Pour tableaux 1D bornes fixes : LEA + IMUL + acces [BX+SI]
  - Affectation d'un element : GenStoreElement
  - Lecture d'un element : GenLoadElement
  - Attributs : T'FIRST, T'LAST -> constantes compilateur
                T'LENGTH -> hi - lo + 1
  - Slices : T(a..b) -> stub (avertissement)                       }

{ TODO 21 - ParseRecordOps : acces aux champs de records
  -------------------------------------------------------
  - Acces champ : var.champ -> adresse base + offset_champ
  - Calcul de l'offset par sommation des tailles des champs anterieurs
  - GenLoadField(sym_idx, field_idx) -> charger dans AX
  - GenStoreField(sym_idx, field_idx) -> stocker depuis AX
  - Affectation agregat : (champ => val, ...) -> sequence d'init
  - Records imbrique : var.champ.sous_champ (recursif)
  - Attributs record : T'SIZE -> somme des tailles (compile-time)  }

{ TODO 22 - Stubs Ada.Text_IO : Put, Put_Line, Get, Get_Line, New_Line
  --------------------------------------------------------------------
  Generer des stubs helpers DOS pour les appels Text_IO :
  - Put(item)       : afficher entier, flottant, char ou chaine
  - Put_Line(item)  : Put + New_Line
  - Get(var)        : lire entier, flottant ou char depuis stdin
  - Get_Line(str, last) : lire chaine + retourner longueur
  - New_Line [(n)]  : emettre n CR+LF (defaut 1)
  - Set_Col(n)      : stub (avertissement "non implemente")
  Appel via CALL _ADA_PUT_INT / _ADA_PUT_STR / _ADA_PUT_CHAR
             CALL _ADA_GET_INT / _ADA_GET_STR / _ADA_GET_CHAR     }

{ TODO 23 - GenDataSegment / GenCodeSegmentHeader / GenRuntimeHelpers
  -------------------------------------------------------------------
  GenHeader :
    ; Generated by ADA86 ...
    .MODEL SMALL / .STACK 256 / .DATA
  GenDataSegment :
    _VAR_xxx definitions (DW/DB/DUP)
    _LS1 ... _LSn chaines litterales
    Buffers internes : _ADA_CRLF_STR, _NUMBUF, _INPUTBUF
    .CODE
  GenCodeSegmentHeader :
    START: / MOV AX,@DATA / MOV DS,AX / MOV ES,AX
    Eventuels CALL _PKG_xxx_INIT pour les packages avec BEGIN
    CALL _ADA_MAIN  (procedure principale Ada, nom identifie
                     comme procedure de fond avec WITH/USE)
    MOV AX,4C00h / INT 21h
  GenRuntimeHelpers :
    _ADA_CRLF, _ADA_PUT_STR, _ADA_PUT_CHAR, _ADA_PUT_INT,
    _ADA_PUT_FLOAT (stub), _ADA_GET_INT, _ADA_GET_STR,
    _ADA_STR_LEN, _ADA_STR_COPY, _ADA_STR_CONCAT,
    _ADA_CHECK_RANGE (Constraint_Error si hors borne),
    _ADA_ERROR (affiche msg + exit 1)
  GenFooter : END START                                             }

{ TODO 24 - Procedure Compile : programme principal deux fichiers
  ---------------------------------------------------------------
  Architecture deux passes (identical a ABAP86) :
    1. Valider ParamStr(1) = source .ADB ou .ADS
    2. Ouvrir source, creer output_file sur tmp_filename (.$$T)
    3. InitAll (New() pour toutes les tables sur le tas)
    4. Enregistrer types predefinis (TODO 05)
    5. NextToken ; parseur principal :
         ParseWithUse* -> ParseDeclarativePart -> ParseProcedureBody
         (programme Ada = procedure de "library unit" avec Begin..End)
    6. Close(output_file) [ferme tmp]
    7. Ouvrir output_filename (final .ASM)
    8. GenHeader ; GenDataSegment ; GenCodeSegmentHeader
    9. AppendFileToOutput(tmp) [corps des proc/func]
   10. GenRuntimeHelpers ; GenFooter
   11. Close, Erase(tmp)
   12. Dispose() toutes les tables, Bilan
   Main : Begin Compile; End.                                       }

{ TODO 25 - Programme de test ADA86 + corrections de bugs
  --------------------------------------------------------
  Creer TEST.ADB : programme Ada de test couvrant :
    - WITH Ada.Text_IO ; USE Ada.Text_IO ;
    - TYPE enumere (Couleur : (Rouge, Vert, Bleu))
    - SUBTYPE plage (Petit : Integer RANGE 1..100)
    - RECORD (Point : RECORD X, Y : Integer; END RECORD)
    - ARRAY  (Vecteur : ARRAY (1..10) OF Integer)
    - CONSTANT (Pi : CONSTANT Float := 3.14159)
    - Variables, affectations :=
    - IF / ELSIF / ELSE / END IF
    - CASE / WHEN / OTHERS / END CASE
    - LOOP / EXIT WHEN / END LOOP
    - WHILE ... LOOP / END LOOP
    - FOR i IN 1..10 LOOP / END LOOP
    - PROCEDURE locale et appel
    - FUNCTION locale avec RETURN
    - RAISE Constraint_Error ; EXCEPTION handler
    - Put_Line, Put(entier/chaine), New_Line

  Compiler, corriger les bugs trouves, valider TEST.ASM :
    - Structure .MODEL SMALL, .DATA, .CODE correcte
    - Toutes les variables declarees
    - Toutes les structures de controle generees
    - Helpers runtime presents
    - END START en derniere ligne                                    }

{ ============================================================================ }
{ FIN DES TODOs - CODE SOURCE                                                  }
{ ============================================================================ }

Program ADA86;

{ ============================================================================ }
{ TODO 01 - Architecture de base : constantes, types internes, variables       }
{ ============================================================================ }

Const

  { ------------------------------------------------------------------ }
  { Types de tokens                                                     }
  { ------------------------------------------------------------------ }
  TOK_UNKNOWN    = 0;
  TOK_IDENT      = 1;   { identifiant ou mot-cle Ada                   }
  TOK_INTEGER    = 2;   { litteral entier  42  16#FF#  2#1010#         }
  TOK_FLOAT      = 3;   { litteral flottant 3.14  1.5E-3               }
  TOK_CHAR       = 4;   { litteral caractere 'c'                       }
  TOK_STRING     = 5;   { litteral chaine "texte"                      }
  TOK_PLUS       = 6;   { +                                            }
  TOK_MINUS      = 7;   { -                                            }
  TOK_STAR       = 8;   { *                                            }
  TOK_SLASH      = 9;   { /                                            }
  TOK_COLONASSIGN= 10;  { :=                                           }
  TOK_COLON      = 11;  { :                                            }
  TOK_SEMI       = 12;  { ;                                            }
  TOK_COMMA      = 13;  { ,                                            }
  TOK_DOT        = 14;  { .                                            }
  TOK_DOTDOT     = 15;  { ..                                           }
  TOK_LPAREN     = 16;  { (                                            }
  TOK_RPAREN     = 17;  { )                                            }
  TOK_EQ         = 18;  { =                                            }
  TOK_NEQ        = 19;  { /=                                           }
  TOK_LT         = 20;  { <                                            }
  TOK_GT         = 21;  { >                                            }
  TOK_LE         = 22;  { <=                                           }
  TOK_GE         = 23;  { >=                                           }
  TOK_ARROW      = 24;  { =>  (association de parametre, WHEN)         }
  TOK_BAR        = 25;  { |   (alternatives WHEN)                      }
  TOK_TICK       = 26;  { '   (attribut T'FIRST, qualificatif T'(x))  }
  TOK_STARSTAR   = 27;  { **  (puissance)                              }
  TOK_AMP        = 28;  { &   (concatenation de chaines)              }
  TOK_HASH       = 29;  { #   (litteraux en base n#val#)               }
  TOK_EOF        = 99;  { fin de fichier                               }

  { ------------------------------------------------------------------ }
  { Mots-cles Ada (insensibles a la casse -> stockes en majuscules)    }
  { ------------------------------------------------------------------ }
  KW_NONE        =  0;
  KW_PROCEDURE   =  1;
  KW_FUNCTION    =  2;
  KW_PACKAGE     =  3;
  KW_BEGIN       =  4;
  KW_END         =  5;
  KW_IS          =  6;
  KW_WITH        =  7;
  KW_USE         =  8;
  KW_TYPE        =  9;
  KW_SUBTYPE     = 10;
  KW_CONSTANT    = 11;
  KW_ARRAY       = 12;
  KW_RECORD      = 13;
  KW_OF          = 14;
  KW_RANGE       = 15;
  KW_IF          = 16;
  KW_THEN        = 17;
  KW_ELSIF       = 18;
  KW_ELSE        = 19;
  KW_CASE        = 20;
  KW_WHEN        = 21;
  KW_OTHERS      = 22;
  KW_LOOP        = 23;
  KW_EXIT        = 24;
  KW_WHILE       = 25;
  KW_FOR         = 26;
  KW_IN          = 27;
  KW_REVERSE     = 28;
  KW_RETURN      = 29;
  KW_NULL        = 30;
  KW_RAISE       = 31;
  KW_EXCEPTION   = 32;
  KW_PRAGMA      = 33;
  KW_RENAMES     = 34;
  KW_SEPARATE    = 35;
  KW_ABSTRACT    = 36;
  KW_PRIVATE     = 37;
  KW_BODY        = 38;
  KW_AND         = 39;
  KW_OR          = 40;
  KW_NOT         = 41;
  KW_XOR         = 42;
  KW_MOD         = 43;
  KW_REM         = 44;
  KW_NEW         = 45;
  KW_ALL         = 46;
  KW_ACCESS      = 47;
  KW_OUT         = 48;
  KW_DECLARE     = 49;
  KW_DO          = 50;
  KW_GOTO        = 51;
  KW_ABS         = 52;
  KW_DELTA       = 53;
  KW_DIGITS      = 54;
  KW_AT          = 55;
  KW_ACCEPT      = 56;
  KW_TASK        = 57;
  KW_PROTECTED   = 58;
  KW_GENERIC     = 59;
  KW_LIMITED     = 60;
  KW_TAGGED      = 61;
  KW_SELECT      = 62;
  KW_TERMINATE   = 63;
  KW_DELAY       = 64;
  KW_UNTIL       = 65;
  KW_REQUEUE     = 66;
  KW_ENTRY       = 67;
  KW_INTERFACE   = 68;
  KW_OVERRIDING  = 69;
  KW_SYNCHRONIZED= 70;
  KW_SOME        = 71;
  KW_TRUE        = 72;  { predefined Boolean constant                  }
  KW_FALSE       = 73;  { predefined Boolean constant                  }
  KW_ANDTHEN     = 74;  { pseudo-KW : AND THEN (court-circuit)         }
  KW_ORELSE      = 75;  { pseudo-KW : OR ELSE  (court-circuit)         }
  KW_INOUT       = 76;  { pseudo-KW : IN OUT (mode parametre)          }

  { ------------------------------------------------------------------ }
  { Types Ada internes (indices predefinis dans type_table)            }
  { ------------------------------------------------------------------ }
  TYPE_UNKNOWN   =  0;
  TYPE_INT       =  1;  { Integer  (16 bits signe, DW)                 }
  TYPE_FLOAT     =  2;  { Float    (32 bits, DD, stub)                 }
  TYPE_BOOL      =  3;  { Boolean  (8 bits, DB, 0/1)                   }
  TYPE_CHAR      =  4;  { Character(8 bits, DB)                        }
  TYPE_STR       =  5;  { String(n)(DB n DUP, $ termine)               }
  TYPE_ENUM      =  6;  { type enumere utilisateur                     }
  TYPE_RANGE     =  7;  { sous-type entier avec borne lo..hi           }
  TYPE_ARRAY     =  8;  { tableau 1D borne fixe                        }
  TYPE_RECORD    =  9;  { enregistrement                               }
  TYPE_ACCESS    = 10;  { pointeur (adresse 16 bits)                   }
  TYPE_DERIVED   = 11;  { type derive (NEW basetype)                   }
  TYPE_VOID      = 12;  { aucun type de retour (procedure)             }

  { ------------------------------------------------------------------ }
  { Categories de type (TTypeEntry.kind = TK_xxx)                      }
  { ------------------------------------------------------------------ }
  TK_PREDEF      = 0;   { type predefini (Integer, Float, etc.)        }
  TK_ENUM        = 1;   { type enumere (a, b, c)                       }
  TK_RANGE       = 2;   { sous-type entier Range lo..hi                }
  TK_ARRAY       = 3;   { tableau 1D : elem_type, lo_bound, hi_bound   }
  TK_RECORD      = 4;   { enregistrement : field_names/types/offs      }
  TK_ACCESS      = 5;   { type pointeur vers base_type                 }
  TK_DERIVED     = 6;   { derivation simple (alias base_type)          }

  { ------------------------------------------------------------------ }
  { Classes de stockage                                                 }
  { ------------------------------------------------------------------ }
  STORE_STATIC   = 1;   { variable globale -> segment .DATA            }
  STORE_AUTO     = 0;   { variable locale  -> pile [BP-n]              }
  STORE_CONST    = 2;   { constante        -> valeur immediate          }

  { ------------------------------------------------------------------ }
  { Modes de parametre Ada                                              }
  { ------------------------------------------------------------------ }
  PARAM_IN       = 0;   { IN      : passage par valeur (PUSH)          }
  PARAM_OUT      = 1;   { OUT     : passage par adresse (PUSH offset)  }
  PARAM_INOUT    = 2;   { IN OUT  : passage par adresse (PUSH offset)  }

  { ------------------------------------------------------------------ }
  { Categories de sous-programme                                        }
  { ------------------------------------------------------------------ }
  SUB_PROC       = 0;   { PROCEDURE (pas de valeur de retour)          }
  SUB_FUNC       = 1;   { FUNCTION  (valeur de retour dans AX/DX:AX)  }

  { ------------------------------------------------------------------ }
  { Categories de scope (TScopeEntry.kind = SK_xxx)                    }
  { ------------------------------------------------------------------ }
  SK_GLOBAL      = 0;   { scope global (declarations de bibliotheque)  }
  SK_PROC        = 1;   { corps de PROCEDURE                           }
  SK_FUNC        = 2;   { corps de FUNCTION                            }
  SK_BLOCK       = 3;   { bloc DECLARE ... BEGIN ... END               }
  SK_LOOP        = 4;   { corps de boucle (LOOP/WHILE/FOR)             }
  SK_EXCEPT      = 5;   { bloc BEGIN ... EXCEPTION ... END             }
  SK_PACKAGE     = 6;   { corps de PACKAGE BODY                        }

  { ------------------------------------------------------------------ }
  { Limites des tables (dimensionnement)                                }
  { ------------------------------------------------------------------ }
  MAX_SYM    = 512;     { Variables + constantes max                   }
  MAX_SUB    = 128;     { Procedures + fonctions max                   }
  MAX_TYPE   = 128;     { Types utilisateur max                        }
  MAX_PKG    = 32;      { Packages importes max                        }
  MAX_PARAM  = 20;      { Parametres max par sous-programme            }
  MAX_FIELD  = 32;      { Champs max par record                        }
  MAX_ENUM   = 64;      { Litteraux max par type enumere               }
  MAX_DEPTH  = 24;      { Profondeur de scope max                      }
  MAX_STR    = 512;     { Litteraux chaines max                        }
  MAX_LABEL  = 9999;    { Limite compteur labels ASM                   }

{ ============================================================================ }
{ Types internes                                                               }
{ ============================================================================ }

Type

  { --- Entree de table des symboles (variables + constantes) --- }
  TSymEntry = Record
    name        : String[48];  { Nom Ada (majuscules)                   }
    asm_label   : String[48];  { Etiquette ASM : _VAR_nom               }
    type_idx    : Integer;     { Index dans type_table (TYPE_xxx)       }
    store_class : Integer;     { STORE_xxx                              }
    bp_offset   : Integer;     { offset [BP-n] si STORE_AUTO            }
    array_size  : Integer;     { 0 si scalaire, n si tableau            }
    char_len    : Integer;     { longueur pour TYPE_STR / TYPE_CHAR     }
    is_const    : Boolean;     { True si CONSTANT                       }
    scope_lev   : Integer;     { niveau de scope (0 = global)           }
    init_num    : LongInt;     { valeur initiale numerique              }
    init_str    : String[64];  { valeur initiale chaine                 }
    has_init    : Boolean;     { True si initialisation specifiee       }
  End;

  { --- Entree de table des sous-programmes (proc + func) --- }
  TSubEntry = Record
    name          : String[48];
    asm_label     : String[48];  { ex: _ADA_PROC_nom / _ADA_FUNC_nom    }
    ret_type      : Integer;     { TYPE_xxx de retour (TYPE_VOID si proc)}
    param_count   : Integer;     { nombre total de parametres            }
    param_names   : Array[1..MAX_PARAM] of String[48];
    param_types   : Array[1..MAX_PARAM] of Integer;
    param_modes   : Array[1..MAX_PARAM] of Integer;   { PARAM_xxx        }
    is_forward    : Boolean;     { True si forward declaration           }
    is_function   : Boolean;     { True si FUNCTION, False si PROCEDURE  }
    frame_size    : Integer;     { taille frame locale en octets         }
  End;

  { --- Entree de table des types utilisateur --- }
  TTypeEntry = Record
    name        : String[48];
    kind        : Integer;       { TK_xxx                               }
    base_type   : Integer;       { index type_table pour derives/ranges }
    lo_bound    : LongInt;       { borne inferieure (RANGE / ARRAY)     }
    hi_bound    : LongInt;       { borne superieure                     }
    field_count : Integer;       { nombre de champs (RECORD)            }
    field_names : Array[1..MAX_FIELD] of String[48];
    field_types : Array[1..MAX_FIELD] of Integer;
    field_offs  : Array[1..MAX_FIELD] of Integer;   { offsets en octets }
    elem_type   : Integer;       { type des elements (ARRAY)            }
    elem_size   : Integer;       { taille d'un element en octets        }
    enum_count  : Integer;       { nombre de litteraux (ENUM)           }
    enum_names  : Array[1..MAX_ENUM] of String[48];
    total_size  : Integer;       { taille totale du type en octets      }
  End;

  { --- Entree de table des packages importes --- }
  TPkgEntry = Record
    name        : String[64];   { nom complet ex: ADA.TEXT_IO           }
    is_standard : Boolean;      { True si package standard reconnu      }
    use_active  : Boolean;      { True si USE activé (acces direct)     }
  End;

  { --- Entree de pile de scopes --- }
  TScopeEntry = Record
    kind        : Integer;       { SK_xxx                               }
    sub_idx     : Integer;       { index dans sub_table (0 si global)   }
    bp_top      : Integer;       { prochain offset BP libre (negatif)   }
    sym_start   : Integer;       { premier index sym dans ce scope      }
    lbl_exit    : String[32];   { label de sortie (RETURN / EXIT)      }
    lbl_cont    : String[32];   { label de continuation (boucle)       }
    lbl_end     : String[32];   { label de fin de bloc                  }
    has_except  : Boolean;       { True si bloc EXCEPTION present        }
    lbl_except  : String[32];   { label du bloc EXCEPTION               }
  End;

  { --- Alias tableaux + pointeurs pour allocation sur le tas --- }
  TSymTableArr  = Array[1..MAX_SYM]  of TSymEntry;
  TSubTableArr  = Array[1..MAX_SUB]  of TSubEntry;
  TTypeTableArr = Array[1..MAX_TYPE] of TTypeEntry;
  TPkgTableArr  = Array[1..MAX_PKG]  of TPkgEntry;
  TScopeArr     = Array[0..MAX_DEPTH] of TScopeEntry;
  TStrTableArr  = Array[1..MAX_STR]  of String;      { texte litteral   }
  TLblTableArr  = Array[1..MAX_STR]  of String[32];  { label _LSn       }

  PSymTable   = ^TSymTableArr;
  PSubTable   = ^TSubTableArr;
  PTypeTable  = ^TTypeTableArr;
  PPkgTable   = ^TPkgTableArr;
  PScopeArr   = ^TScopeArr;
  PStrTable   = ^TStrTableArr;
  PLblTable   = ^TLblTableArr;

{ ============================================================================ }
{ Variables globales                                                           }
{ ============================================================================ }

Var

  { --- Fichiers --- }
  source_filename : String;
  output_filename : String;
  input_file      : Text;
  output_file     : Text;

  { --- Options --- }
  opt_verbose     : Boolean;
  opt_dump_tok    : Boolean;

  { --- Etat du tokeniseur --- }
  src_line        : String;
  src_line_num    : Integer;
  src_col         : Integer;
  src_eof         : Boolean;
  cur_tok_type    : Integer;   { TOK_xxx                                }
  cur_tok_str     : String;    { texte brut du token (idents, strings)  }
  cur_tok_num     : LongInt;   { valeur si TOK_INTEGER                  }
  cur_tok_flt     : Double;    { valeur si TOK_FLOAT                    }
  cur_tok_kw      : Integer;   { KW_xxx si TOK_IDENT est un mot-cle    }
  peek_char       : Char;      { caractere en attente (lookahead)       }
  has_peek        : Boolean;
  cur_column      : Integer;   { colonne courante (1-base)              }

  { --- Nom de la procedure principale (library unit) --- }
  prog_name       : String;

  { --- Tables sur le tas --- }
  sym_table   : PSymTable;     { variables + constantes                 }
  sym_count   : Integer;
  sub_table   : PSubTable;     { procedures + fonctions                 }
  sub_count   : Integer;
  type_table  : PTypeTable;    { types utilisateur + predefinis         }
  type_count  : Integer;
  pkg_table   : PPkgTable;     { packages importes (WITH/USE)           }
  pkg_count   : Integer;
  str_table   : PStrTable;     { textes des litteraux chaines           }
  lbl_table   : PLblTable;     { labels ASM des litteraux (_LS1..._LSn) }
  str_count   : Integer;

  { --- Pile de scopes --- }
  scope_stack : PScopeArr;
  scope_top   : Integer;

  { --- Compteurs --- }
  label_counter : Integer;     { pour NewLabel -> @@L0001, @@L0002 ...  }
  lit_counter   : Integer;     { pour AddStringLit -> _LS1, _LS2 ...    }
  error_count   : Integer;
  warn_count    : Integer;
  gen_enabled   : Boolean;     { False -> Emit() ne fait rien (erreur)  }

{ ============================================================================ }
{ Point d'entree provisiore (sera remplace par Compile a TODO 24)             }
{ ============================================================================ }

Begin
  WriteLn('ADA86 V1.0 - TODO 01 OK (architecture de base compilee)');
  WriteLn('  TOK_xxx   : ', TOK_EOF,       ' tokens definis');
  WriteLn('  KW_xxx    : ', KW_INOUT,      ' mots-cles definis');
  WriteLn('  TYPE_xxx  : ', TYPE_VOID,     ' types predefinis');
  WriteLn('  MAX_SYM   : ', MAX_SYM,       ' / MAX_SUB : ', MAX_SUB);
  WriteLn('  MAX_TYPE  : ', MAX_TYPE,      ' / MAX_STR : ', MAX_STR);
  WriteLn('  Tailles pointeurs : PSymTable PSubTable PTypeTable OK');
End.
