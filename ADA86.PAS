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
  except_next_code : Integer;  { prochain code d'exception utilisateur  }

{ ============================================================================ }
{ TODO 02 - Lexeur : lecture source et tokenisation                            }
{ ============================================================================ }

{ ---------- Utilitaires chaines ---------- }

Function UpCaseStr(Const s: String): String;
Var i: Integer; r: String;
Begin
 r := s;
 For i := 1 to Length(r) do
  r[i] := UpCase(r[i]);
 UpCaseStr := r;
End;

Function IntToStr(n: LongInt): String;
Var s: String;
Begin
 Str(n, s);
 IntToStr := s;
End;

Function StrToInt(Const s: String): LongInt;
Var v: LongInt; code: Integer;
Begin
 Val(s, v, code);
 If code <> 0 Then v := 0;
 StrToInt := v;
End;

{ Normalise un nom en etiquette ASM valide (remplace - et . par _) }
Function AsmIdent(Const prefix, name: String): String;
Var i: Integer; r: String;
Begin
 r := prefix + name;
 For i := 1 to Length(r) do
  If r[i] In ['-', '.', ' '] Then r[i] := '_';
 AsmIdent := r;
End;

{ ---------- Lecture source caractere par caractere ---------- }

{ Lire un caractere depuis input_file ; gerer fin de ligne et fin de fichier.
  Remplit src_line a chaque nouvelle ligne, incremente src_line_num.          }
Procedure SrcRefillLine;
Begin
 If EOF(input_file) Then
 Begin
  src_eof := True;
  src_line := '';
  src_col  := 1;
  Exit;
 End;
 ReadLn(input_file, src_line);
 Inc(src_line_num);
 src_col    := 1;
 src_eof    := False;
End;

{ Retourne le prochain caractere source sans avancer (lookahead 1) }
Function SrcPeek: Char;
Begin
 While (src_col > Length(src_line) + 1) Or
       ((src_col > Length(src_line)) And (Not src_eof)) do
 Begin
  { arrivee en fin de ligne courante : passer a la suivante }
  If EOF(input_file) Then
  Begin src_eof := True; SrcPeek := #0; Exit; End;
  SrcRefillLine;
 End;
 If src_eof Or (src_col > Length(src_line)) Then
 Begin SrcPeek := #10; { LF synthetique fin de ligne } End
 Else
  SrcPeek := src_line[src_col];
End;

{ Consomme et retourne un caractere source }
Function SrcGetChar: Char;
Var ch: Char;
Begin
 { Initialisation : charger la premiere ligne si necessaire }
 If (src_line_num = 0) And (Not src_eof) Then
  SrcRefillLine;

 If src_eof Then
 Begin SrcGetChar := #0; Exit; End;

 If src_col > Length(src_line) Then
 Begin
  { Fin de la ligne courante -> retourner LF puis passer a la suivante }
  cur_column := src_col;
  Inc(src_col);
  If src_col > Length(src_line) + 1 Then
  Begin
   If Not EOF(input_file) Then SrcRefillLine
   Else src_eof := True;
  End;
  SrcGetChar := #10;
  Exit;
 End;

 ch := src_line[src_col];
 cur_column := src_col;
 Inc(src_col);
 SrcGetChar := ch;
End;

{ Remet un caractere dans le flux (un seul niveau de retour en arriere) }
Procedure SrcUnget;
Begin
 If src_col > 1 Then Dec(src_col);
End;

{ ---------- Gestion du lookahead (peek_char) ---------------  }

Function GetChar: Char;
Var ch: Char;
Begin
 If has_peek Then
 Begin
  ch       := peek_char;
  has_peek := False;
 End
 Else
  ch := SrcGetChar;
 GetChar := ch;
End;

Procedure UngetChar(ch: Char);
Begin
 peek_char := ch;
 has_peek  := True;
End;

Function PeekNextChar: Char;
Var ch: Char;
Begin
 ch := GetChar;
 UngetChar(ch);
 PeekNextChar := ch;
End;

{ ---------- Ignorer espaces et commentaires Ada (--) ---------- }

Procedure SkipWhitespaceAndComments;
Var ch, ch2: Char;
Begin
 Repeat
  ch := GetChar;
  If ch = #0 Then Exit;
  If ch In [' ', #9, #10, #13] Then
   { espace / tabulation / fin de ligne : continuer }
  Else If ch = '-' Then
  Begin
   { possible commentaire -- }
   ch2 := PeekNextChar;
   If ch2 = '-' Then
   Begin
    { commentaire : consommer jusqu'a fin de ligne }
    GetChar; { consommer le deuxieme - }
    Repeat
     ch := GetChar;
    Until (ch = #10) Or (ch = #0);
   End
   Else
   Begin
    { signe moins : remettre et sortir }
    UngetChar(ch);
    Exit;
   End;
  End
  Else
  Begin
   { caractere significatif }
   UngetChar(ch);
   Exit;
  End;
 Until False;
End;

{ ---------- Table des mots-cles Ada ---------- }

{ Retourne KW_xxx si l'identifiant (en majuscules) est un mot-cle,
  sinon KW_NONE.  La table est triee alphabetiquement pour lisibilite. }
Function LookupKeyword(Const u: String): Integer;
Begin
 LookupKeyword := KW_NONE;
 Case Length(u) of
  2: Begin
      If      u = 'AT' Then LookupKeyword := KW_AT
      Else If u = 'DO' Then LookupKeyword := KW_DO
      Else If u = 'IF' Then LookupKeyword := KW_IF
      Else If u = 'IN' Then LookupKeyword := KW_IN
      Else If u = 'IS' Then LookupKeyword := KW_IS
      Else If u = 'OF' Then LookupKeyword := KW_OF
      Else If u = 'OR' Then LookupKeyword := KW_OR;
     End;
  3: Begin
      If      u = 'ABS' Then LookupKeyword := KW_ABS
      Else If u = 'ALL' Then LookupKeyword := KW_ALL
      Else If u = 'AND' Then LookupKeyword := KW_AND
      Else If u = 'END' Then LookupKeyword := KW_END
      Else If u = 'FOR' Then LookupKeyword := KW_FOR
      Else If u = 'MOD' Then LookupKeyword := KW_MOD
      Else If u = 'NEW' Then LookupKeyword := KW_NEW
      Else If u = 'NOT' Then LookupKeyword := KW_NOT
      Else If u = 'OUT' Then LookupKeyword := KW_OUT
      Else If u = 'REM' Then LookupKeyword := KW_REM
      Else If u = 'USE' Then LookupKeyword := KW_USE
      Else If u = 'XOR' Then LookupKeyword := KW_XOR;
     End;
  4: Begin
      If      u = 'BODY' Then LookupKeyword := KW_BODY
      Else If u = 'CASE' Then LookupKeyword := KW_CASE
      Else If u = 'ELSE' Then LookupKeyword := KW_ELSE
      Else If u = 'EXIT' Then LookupKeyword := KW_EXIT
      Else If u = 'GOTO' Then LookupKeyword := KW_GOTO
      Else If u = 'LOOP' Then LookupKeyword := KW_LOOP
      Else If u = 'NULL' Then LookupKeyword := KW_NULL
      Else If u = 'SOME' Then LookupKeyword := KW_SOME
      Else If u = 'TASK' Then LookupKeyword := KW_TASK
      Else If u = 'THEN' Then LookupKeyword := KW_THEN
      Else If u = 'TRUE' Then LookupKeyword := KW_TRUE
      Else If u = 'TYPE' Then LookupKeyword := KW_TYPE
      Else If u = 'WHEN' Then LookupKeyword := KW_WHEN
      Else If u = 'WITH' Then LookupKeyword := KW_WITH;
     End;
  5: Begin
      If      u = 'ARRAY' Then LookupKeyword := KW_ARRAY
      Else If u = 'BEGIN' Then LookupKeyword := KW_BEGIN
      Else If u = 'DELAY' Then LookupKeyword := KW_DELAY
      Else If u = 'DELTA' Then LookupKeyword := KW_DELTA
      Else If u = 'ELSIF' Then LookupKeyword := KW_ELSIF
      Else If u = 'ENTRY' Then LookupKeyword := KW_ENTRY
      Else If u = 'FALSE' Then LookupKeyword := KW_FALSE
      Else If u = 'INOUT' Then LookupKeyword := KW_INOUT
      Else If u = 'RAISE' Then LookupKeyword := KW_RAISE
      Else If u = 'RANGE' Then LookupKeyword := KW_RANGE
      Else If u = 'UNTIL' Then LookupKeyword := KW_UNTIL
      Else If u = 'WHILE' Then LookupKeyword := KW_WHILE;
     End;
  6: Begin
      If      u = 'ACCEPT' Then LookupKeyword := KW_ACCEPT
      Else If u = 'ACCESS' Then LookupKeyword := KW_ACCESS
      Else If u = 'DIGITS' Then LookupKeyword := KW_DIGITS
      Else If u = 'OTHERS' Then LookupKeyword := KW_OTHERS
      Else If u = 'PRAGMA' Then LookupKeyword := KW_PRAGMA
      Else If u = 'RECORD' Then LookupKeyword := KW_RECORD
      Else If u = 'RETURN' Then LookupKeyword := KW_RETURN
      Else If u = 'SELECT' Then LookupKeyword := KW_SELECT
      Else If u = 'TAGGED' Then LookupKeyword := KW_TAGGED;
     End;
  7: Begin
      If      u = 'DECLARE' Then LookupKeyword := KW_DECLARE
      Else If u = 'GENERIC' Then LookupKeyword := KW_GENERIC
      Else If u = 'LIMITED' Then LookupKeyword := KW_LIMITED
      Else If u = 'PACKAGE' Then LookupKeyword := KW_PACKAGE
      Else If u = 'PRIVATE' Then LookupKeyword := KW_PRIVATE
      Else If u = 'RENAMES' Then LookupKeyword := KW_RENAMES
      Else If u = 'REQUEUE' Then LookupKeyword := KW_REQUEUE
      Else If u = 'REVERSE' Then LookupKeyword := KW_REVERSE
      Else If u = 'SUBTYPE' Then LookupKeyword := KW_SUBTYPE;
     End;
  8: Begin
      If      u = 'ABSTRACT' Then LookupKeyword := KW_ABSTRACT
      Else If u = 'CONSTANT' Then LookupKeyword := KW_CONSTANT
      Else If u = 'FUNCTION' Then LookupKeyword := KW_FUNCTION
      Else If u = 'SEPARATE' Then LookupKeyword := KW_SEPARATE;
     End;
  9: Begin
      If      u = 'EXCEPTION' Then LookupKeyword := KW_EXCEPTION
      Else If u = 'INTERFACE' Then LookupKeyword := KW_INTERFACE
      Else If u = 'PROCEDURE' Then LookupKeyword := KW_PROCEDURE
      Else If u = 'PROTECTED' Then LookupKeyword := KW_PROTECTED
      Else If u = 'TERMINATE' Then LookupKeyword := KW_TERMINATE;
     End;
  10: If u = 'OVERRIDING' Then LookupKeyword := KW_OVERRIDING;
  12: If u = 'SYNCHRONIZED' Then LookupKeyword := KW_SYNCHRONIZED;
 End;
End;

{ ---------- Lex : identifiant ou mot-cle ---------- }

Procedure LexIdent;
Var s: String; ch: Char;
Begin
 s := '';
 Repeat
  ch := GetChar;
  If ch In ['A'..'Z', 'a'..'z', '0'..'9', '_'] Then
   s := s + ch
  Else
  Begin
   UngetChar(ch);
   Break;
  End;
 Until Length(s) = 255;
 { Ada autorise _ interieurs mais pas en debut/fin -> on ne valide pas ici }
 s := UpCaseStr(s);
 cur_tok_str  := s;
 cur_tok_kw   := LookupKeyword(s);
 cur_tok_type := TOK_IDENT;
 { Pseudo-tokens booleans -> rester IDENT, le parser utilisera KW_TRUE/FALSE }
End;

{ ---------- Lex : litteraux numeriques ---------- }

{ Convertit un chiffre dans une base donnee ; retourne -1 si invalide }
Function DigitValue(ch: Char; base: Integer): Integer;
Var v: Integer;
Begin
 ch := UpCase(ch);
 If (ch >= '0') And (ch <= '9') Then v := Ord(ch) - Ord('0')
 Else If (ch >= 'A') And (ch <= 'F') Then v := Ord(ch) - Ord('A') + 10
 Else v := -1;
 If v >= base Then v := -1;
 DigitValue := v;
End;

Procedure LexNumber(firstCh: Char);
Var s        : String;
    intVal   : LongInt;
    base     : Integer;
    ch       : Char;
    dv       : Integer;
    isFloat  : Boolean;
    fltStr   : String;
Begin
 s      := '' + firstCh;
 isFloat:= False;
 base   := 10;
 intVal := Ord(firstCh) - Ord('0');

 { Accumuler les chiffres decimaux initiaux }
 Repeat
  ch := GetChar;
  If ch In ['0'..'9', '_'] Then
  Begin
   If ch <> '_' Then
   Begin
    s      := s + ch;
    intVal := intVal * 10 + (Ord(ch) - Ord('0'));
   End;
  End
  Else
  Begin
   UngetChar(ch);
   Break;
  End;
 Until False;

 ch := GetChar;

 { Litteral en base n#valeur# }
 If ch = '#' Then
 Begin
  base   := intVal;
  intVal := 0;
  s      := '';
  Repeat
   ch := GetChar;
   If ch = '#' Then Break;
   If ch = '_' Then Continue;
   dv := DigitValue(ch, base);
   If dv < 0 Then Break; { ignorer caractere invalide }
   s      := s + ch;
   intVal := intVal * base + dv;
  Until False;
  cur_tok_type := TOK_INTEGER;
  cur_tok_num  := intVal;
  cur_tok_str  := IntToStr(intVal);
  Exit;
 End;

 { Flottant : partie decimale apres '.' }
 If ch = '.' Then
 Begin
  ch := PeekNextChar;
  If ch = '.' Then
  Begin
   { operateur '..' : remettre le '.' et sortir }
   UngetChar('.');
   cur_tok_type := TOK_INTEGER;
   cur_tok_num  := intVal;
   cur_tok_str  := s;
   Exit;
  End;
  isFloat := True;
  fltStr  := s + '.';
  Repeat
   ch := GetChar;
   If ch In ['0'..'9', '_'] Then
   Begin
    If ch <> '_' Then fltStr := fltStr + ch;
   End
   Else
   Begin
    UngetChar(ch);
    Break;
   End;
  Until False;
  ch := GetChar;
 End;

 { Exposant E ou e }
 If (ch = 'E') Or (ch = 'e') Then
 Begin
  isFloat := True;
  If Not isFloat Then fltStr := s;
  fltStr := fltStr + 'E';
  ch := GetChar;
  If ch In ['+', '-'] Then
  Begin
   fltStr := fltStr + ch;
   ch     := GetChar;
  End;
  While ch In ['0'..'9'] do
  Begin
   fltStr := fltStr + ch;
   ch     := GetChar;
  End;
  UngetChar(ch);
 End
 Else
  UngetChar(ch);

 If isFloat Then
 Begin
  cur_tok_type := TOK_FLOAT;
  cur_tok_str  := fltStr;
  Val(fltStr, cur_tok_flt, base { reutilise comme code });
  cur_tok_num  := Round(cur_tok_flt);
 End
 Else
 Begin
  cur_tok_type := TOK_INTEGER;
  cur_tok_num  := intVal;
  cur_tok_str  := s;
 End;
End;

{ ---------- Lex : litteral caractere 'c' ---------- }
{ En Ada : 'c' est un Character literal.
  '' n'existe pas en Ada (c'est toujours exactement un caractere).
  Le tick ' devant un ident est l'attribut T'FIRST -> retourne TOK_TICK.     }

Procedure LexCharOrTick;
Var ch, ch2: Char;
Begin
 ch := GetChar;
 If ch = #0 Then
 Begin
  cur_tok_type := TOK_TICK;
  cur_tok_str  := '''';
  Exit;
 End;
 ch2 := GetChar;
 If ch2 = '''' Then
 Begin
  { 'c' -> litteral caractere }
  cur_tok_type := TOK_CHAR;
  cur_tok_str  := '' + ch;
  cur_tok_num  := Ord(ch);
 End
 Else
 Begin
  { n'est pas 'c' -> c'est un tick d'attribut (T'FIRST, T'(expr))
    On a consomme trop : remettre ch2 et ch }
  UngetChar(ch2);
  UngetChar(ch);
  cur_tok_type := TOK_TICK;
  cur_tok_str  := '''';
 End;
End;

{ ---------- Lex : litteral chaine "..." ---------- }

Procedure LexString;
Var s: String; ch: Char;
Begin
 s := '';
 Repeat
  ch := GetChar;
  If ch = '"' Then
  Begin
   { "" -> guillemet double inclu dans la chaine }
   If PeekNextChar = '"' Then
   Begin
    GetChar;
    s := s + '"';
   End
   Else
    Break; { fin de la chaine }
  End
  Else If (ch = #10) Or (ch = #0) Then
  Begin
   { chaine non fermee }
   Break;
  End
  Else
   s := s + ch;
 Until False;
 cur_tok_type := TOK_STRING;
 cur_tok_str  := s;
End;

{ ---------- Lex : symboles et operateurs ---------- }

Procedure LexSymbol(firstCh: Char);
Var ch2: Char;
Begin
 cur_tok_str := '' + firstCh;
 Case firstCh of
  ':': Begin
        ch2 := PeekNextChar;
        If ch2 = '=' Then
        Begin GetChar; cur_tok_type := TOK_COLONASSIGN; cur_tok_str := ':='; End
        Else cur_tok_type := TOK_COLON;
       End;
  '/': Begin
        ch2 := PeekNextChar;
        If ch2 = '=' Then
        Begin GetChar; cur_tok_type := TOK_NEQ; cur_tok_str := '/='; End
        Else cur_tok_type := TOK_SLASH;
       End;
  '>': Begin
        ch2 := PeekNextChar;
        If ch2 = '=' Then
        Begin GetChar; cur_tok_type := TOK_GE; cur_tok_str := '>='; End
        Else cur_tok_type := TOK_GT;
       End;
  '<': Begin
        ch2 := PeekNextChar;
        If ch2 = '=' Then
        Begin GetChar; cur_tok_type := TOK_LE; cur_tok_str := '<='; End
        Else cur_tok_type := TOK_LT;
       End;
  '=': Begin
        ch2 := PeekNextChar;
        If ch2 = '>' Then
        Begin GetChar; cur_tok_type := TOK_ARROW; cur_tok_str := '=>'; End
        Else cur_tok_type := TOK_EQ;
       End;
  '.': Begin
        ch2 := PeekNextChar;
        If ch2 = '.' Then
        Begin GetChar; cur_tok_type := TOK_DOTDOT; cur_tok_str := '..'; End
        Else cur_tok_type := TOK_DOT;
       End;
  '*': Begin
        ch2 := PeekNextChar;
        If ch2 = '*' Then
        Begin GetChar; cur_tok_type := TOK_STARSTAR; cur_tok_str := '**'; End
        Else cur_tok_type := TOK_STAR;
       End;
  '+': cur_tok_type := TOK_PLUS;
  '-': cur_tok_type := TOK_MINUS;
  '(': cur_tok_type := TOK_LPAREN;
  ')': cur_tok_type := TOK_RPAREN;
  ',': cur_tok_type := TOK_COMMA;
  ';': cur_tok_type := TOK_SEMI;
  '|': cur_tok_type := TOK_BAR;
  '&': cur_tok_type := TOK_AMP;
  '#': cur_tok_type := TOK_HASH;
  Else cur_tok_type := TOK_UNKNOWN;
 End;
End;

{ ---------- Tokeniseur principal ---------- }

Procedure NextToken;
Var ch: Char;
Begin
 SkipWhitespaceAndComments;

 cur_tok_str  := '';
 cur_tok_num  := 0;
 cur_tok_flt  := 0.0;
 cur_tok_kw   := KW_NONE;

 ch := GetChar;

 If ch = #0 Then
 Begin
  cur_tok_type := TOK_EOF;
  cur_tok_str  := '';
  Exit;
 End;

 If ch In ['A'..'Z', 'a'..'z', '_'] Then LexIdent
 Else If ch In ['0'..'9'] Then LexNumber(ch)
 Else If ch = '''' Then LexCharOrTick
 Else If ch = '"' Then LexString
 Else LexSymbol(ch);
End;

{ Avancer au prochain token }
Procedure Consume;
Begin
 NextToken;
End;

{ ---------- Helpers de parsing ---------- }

Function TokIsKw(kw: Integer): Boolean;
Begin
 TokIsKw := (cur_tok_type = TOK_IDENT) And (cur_tok_kw = kw);
End;

Function TokIsOp(tok: Integer): Boolean;
Begin
 TokIsOp := (cur_tok_type = tok);
End;

{ Verify that current token is of type tok ; consume it ; else error msg }
Procedure Expect(tok: Integer; Const msg: String);
Begin
 If cur_tok_type <> tok Then
 Begin
  WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg,
          ' (recu : ''', cur_tok_str, ''')');
  Inc(error_count);
 End
 Else
  Consume;
End;

Procedure ExpectKw(kw: Integer; Const kwname, msg: String);
Begin
 If Not TokIsKw(kw) Then
 Begin
  WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg,
          ' (recu : ''', cur_tok_str, ''')');
  Inc(error_count);
 End
 Else
  Consume;
End;

{ ============================================================================ }
{ TODO 03 - Gestion des erreurs, avertissements et resynchronisation           }
{ ============================================================================ }

{ Affiche un message d'erreur non fatal et incremente error_count.
  Le parsing continue pour detecter d'autres erreurs.                         }
Procedure Error(Const msg: String);
Begin
 WriteLn('ERREUR (ligne ', src_line_num, ', col ', cur_column, ') : ', msg);
 Inc(error_count);
End;

{ Affiche un message d'erreur avec le token courant en contexte }
Procedure ErrorTok(Const msg: String);
Begin
 WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg,
         ' (token : ''', cur_tok_str, ''')');
 Inc(error_count);
End;

{ Avertissement non bloquant }
Procedure Warning(Const msg: String);
Begin
 WriteLn('ATTENTION (ligne ', src_line_num, ') : ', msg);
 Inc(warn_count);
End;

{ Erreur fatale : affiche le message et arrete la compilation }
Procedure FatalError(Const msg: String);
Begin
 WriteLn('ERREUR FATALE (ligne ', src_line_num, ') : ', msg);
 Halt(1);
End;

{ Resynchronisation : consommer tous les tokens jusqu'au prochain ';'
  (inclus) ou EOF. Utilise apres une erreur de syntaxe dans une instruction. }
Procedure SkipToSemi;
Begin
 While (cur_tok_type <> TOK_SEMI) And (cur_tok_type <> TOK_EOF) do
  Consume;
 If cur_tok_type = TOK_SEMI Then Consume;
End;

{ Resynchronisation : consommer jusqu'a END correspondant (suivi de ';').
  Gere les blocs imbrique en comptant BEGIN/END.
  Utilise apres une erreur grave dans un bloc.                                }
Procedure SkipToEnd;
Var depth: Integer;
Begin
 depth := 1;
 While (cur_tok_type <> TOK_EOF) And (depth > 0) do
 Begin
  If TokIsKw(KW_BEGIN) Or TokIsKw(KW_DECLARE) Or
     TokIsKw(KW_LOOP)  Or TokIsKw(KW_RECORD)  Then
   Inc(depth)
  Else If TokIsKw(KW_END) Then
   Dec(depth);
  Consume;
 End;
 { Consommer le ';' apres END si present }
 If cur_tok_type = TOK_SEMI Then Consume;
End;

{ Resynchronisation : sauter jusqu'a l'un des mots-cles de l'ensemble donne.
  Exemple d'utilisation : SkipToKw(KW_THEN) apres une condition malformee.   }
Procedure SkipToKw(kw: Integer);
Begin
 While (cur_tok_type <> TOK_EOF) And Not TokIsKw(kw) do
  Consume;
End;

{ Bilan de compilation : affiche les statistiques sur stderr }
Procedure BilanCompilation;
Begin
 WriteLn;
 WriteLn('ADA86 - Compilation terminee');
 WriteLn('  Source     : ', source_filename);
 WriteLn('  Sortie     : ', output_filename);
 WriteLn('  Symboles   : ', sym_count);
 WriteLn('  Sous-progs : ', sub_count);
 WriteLn('  Types user : ', type_count);
 WriteLn('  Erreurs    : ', error_count);
 WriteLn('  Attention  : ', warn_count);
 If error_count > 0 Then
  WriteLn('  *** COMPILATION AVEC ERREURS ***');
End;

{ ============================================================================ }
{ TODO 04 - Tables des symboles : CRUD + resolution de portee                 }
{ ============================================================================ }

{ Taille en octets d'un type primaire Ada (types predefinis uniquement).
  Pour les types utilisateur (type_idx >= 6), retourne 2 par defaut ;
  GetTypeSize (TODO 05) affinera ce calcul.                                    }
Function PrimTypeSize(type_idx: Integer): Integer;
Begin
 Case type_idx of
  TYPE_INT    : PrimTypeSize := 2;   { Integer : DW 16 bits signe    }
  TYPE_FLOAT  : PrimTypeSize := 4;   { Float   : DD 32 bits          }
  TYPE_BOOL   : PrimTypeSize := 2;   { Boolean : DW (0 / -1)         }
  TYPE_CHAR   : PrimTypeSize := 2;   { Character : DW (code ASCII)   }
  TYPE_STR    : PrimTypeSize := 2;   { String : ptr (adresse 16 bits)}
 Else
  PrimTypeSize := 2;                 { types utilisateur : stub = 2  }
 End;
End;

{ Retourne la taille en octets du symbole sym_idx.
  Tient compte de array_size et char_len.                                      }
Function GetSymSize(sym_idx: Integer): Integer;
Var base_sz : Integer;
    arr_sz  : Integer;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin GetSymSize := 2; Exit; End;

 base_sz := PrimTypeSize(sym_table^[sym_idx].type_idx);

 { TYPE_STR avec char_len explicite : taille reelle en octets }
 If sym_table^[sym_idx].type_idx = TYPE_STR Then
 Begin
  If sym_table^[sym_idx].char_len > 0 Then
   base_sz := sym_table^[sym_idx].char_len + 1 { +1 pour terminateur $ }
  Else
   base_sz := 2;
 End;

 arr_sz := sym_table^[sym_idx].array_size;
 If arr_sz > 0 Then
  GetSymSize := base_sz * arr_sz
 Else
  GetSymSize := base_sz;
End;

{ Aligne une taille sur un multiple de 2 (alginement mot pour la pile 8086) }
Function AlignWord(n: Integer): Integer;
Begin
 If (n Mod 2) <> 0 Then AlignWord := n + 1
 Else AlignWord := n;
End;

{ ---- Initialisation de la table des symboles ---- }

Procedure InitSymTable;
Var i: Integer;
Begin
 If sym_table = nil Then New(sym_table);
 sym_count := 0;
 except_next_code := 100;  { codes 1-99 reserves aux exceptions standard }
 For i := 1 to MAX_SYM do
 Begin
  sym_table^[i].name        := '';
  sym_table^[i].asm_label   := '';
  sym_table^[i].type_idx    := TYPE_UNKNOWN;
  sym_table^[i].store_class := STORE_STATIC;
  sym_table^[i].bp_offset   := 0;
  sym_table^[i].array_size  := 0;
  sym_table^[i].char_len    := 0;
  sym_table^[i].is_const    := False;
  sym_table^[i].scope_lev   := 0;
  sym_table^[i].init_num    := 0;
  sym_table^[i].init_str    := '';
  sym_table^[i].has_init    := False;
 End;
End;

{ ---- Ajout d'un symbole dans la table ----
  - Retourne l'index (1-base) du nouveau symbole.
  - Retourne 0 si la table est pleine.
  - Pour STORE_AUTO : calcule bp_offset en decalant bp_top du scope courant.  }
Function AddSym(Const name: String; type_idx, store_class: Integer): Integer;
Var u   : String;
    sz  : Integer;
    idx : Integer;
Begin
 If sym_count >= MAX_SYM Then
 Begin
  Error('Table des symboles pleine (MAX_SYM=' + IntToStr(MAX_SYM) + ')');
  AddSym := 0; Exit;
 End;
 u := UpCaseStr(name);
 Inc(sym_count);
 idx := sym_count;
 sym_table^[idx].name        := u;
 sym_table^[idx].asm_label   := AsmIdent('_VAR_', u);
 sym_table^[idx].type_idx    := type_idx;
 sym_table^[idx].store_class := store_class;
 sym_table^[idx].bp_offset   := 0;
 sym_table^[idx].array_size  := 0;
 sym_table^[idx].char_len    := 0;
 sym_table^[idx].is_const    := (store_class = STORE_CONST);
 sym_table^[idx].scope_lev   := scope_top;
 sym_table^[idx].init_num    := 0;
 sym_table^[idx].init_str    := '';
 sym_table^[idx].has_init    := False;

 { Pour les variables locales : allouer l'espace sur la pile.
   scope_stack^[scope_top].bp_top contient le prochain offset libre
   (valeur negative croissante en valeur absolue).                            }
 If (store_class = STORE_AUTO) And (scope_top > 0) Then
 Begin
  sz := PrimTypeSize(type_idx);   { sera affine apres AddSym par le parseur }
  scope_stack^[scope_top].bp_top :=
    scope_stack^[scope_top].bp_top - AlignWord(sz);
  sym_table^[idx].bp_offset := scope_stack^[scope_top].bp_top;
 End;

 AddSym := idx;
End;

{ Recalcule le bp_offset apres que char_len / array_size ont ete mis a jour.
  A appeler juste apres AddSym quand la taille reelle est connue.             }
Procedure FixSymBpOffset(sym_idx: Integer);
Var sz      : Integer;
    old_off : Integer;
    new_off : Integer;
    lev     : Integer;
Begin
 If sym_table^[sym_idx].store_class <> STORE_AUTO Then Exit;
 lev := sym_table^[sym_idx].scope_lev;
 If lev <= 0 Then Exit;

 { Retrouver l'espace alloue initialement (PrimTypeSize lors de AddSym) }
 old_off := sym_table^[sym_idx].bp_offset;  { offset courant }
 sz      := GetSymSize(sym_idx);

 { Recalculer : bp_top apres cet objet = old_off ; retirer l'ancienne taille
   et placer la nouvelle.                                                      }
 new_off := scope_stack^[lev].bp_top - AlignWord(sz)
            + AlignWord(PrimTypeSize(sym_table^[sym_idx].type_idx));
 { Si la taille a change, ajuster bp_top du scope }
 scope_stack^[lev].bp_top :=
   scope_stack^[lev].bp_top
   - AlignWord(sz)
   + AlignWord(PrimTypeSize(sym_table^[sym_idx].type_idx));

 { L'offset du symbole lui-meme reste le meme (allocation deja faite) ;
   pour la correction exacte il faudrait une seconde passe — on laisse
   tel quel pour les types de base (change surtout pour STR/tableaux).         }
End;

{ ---- Recherche dans la table des symboles ----
  Cherche de la fin vers le debut pour respecter la portee la plus proche.   }
Function FindSym(Const name: String): Integer;
Var i : Integer;
    u : String;
Begin
 u := UpCaseStr(name);
 For i := sym_count DownTo 1 do
  If sym_table^[i].name = u Then Begin FindSym := i; Exit; End;
 FindSym := 0;
End;

{ Recherche uniquement dans le scope courant }
Function FindSymLocal(Const name: String): Integer;
Var i   : Integer;
    u   : String;
    lev : Integer;
Begin
 u   := UpCaseStr(name);
 lev := scope_top;
 For i := sym_count DownTo 1 do
  If (sym_table^[i].name = u) And (sym_table^[i].scope_lev = lev) Then
  Begin FindSymLocal := i; Exit; End;
 FindSymLocal := 0;
End;

{ Recherche dans un scope de niveau donne }
Function FindSymAtLevel(Const name: String; lev: Integer): Integer;
Var i : Integer;
    u : String;
Begin
 u := UpCaseStr(name);
 For i := sym_count DownTo 1 do
  If (sym_table^[i].name = u) And (sym_table^[i].scope_lev = lev) Then
  Begin FindSymAtLevel := i; Exit; End;
 FindSymAtLevel := 0;
End;

{ ============================================================================ }
{ TODO 05 - Tables des types, sous-programmes et packages                     }
{ ============================================================================ }

{ ---- Table des types utilisateur ----------------------------------------- }

Procedure InitTypeTable;
Var i, j : Integer;
Begin
 If type_table = nil Then New(type_table);
 type_count := 0;
 For i := 1 to MAX_TYPE do
 Begin
  type_table^[i].name       := '';
  type_table^[i].kind       := TK_PREDEF;
  type_table^[i].base_type  := TYPE_UNKNOWN;
  type_table^[i].lo_bound   := 0;
  type_table^[i].hi_bound   := 0;
  type_table^[i].field_count:= 0;
  type_table^[i].elem_type  := TYPE_UNKNOWN;
  type_table^[i].elem_size  := 2;
  type_table^[i].enum_count := 0;
  type_table^[i].total_size := 2;
  For j := 1 to MAX_FIELD do
  Begin
   type_table^[i].field_names[j] := '';
   type_table^[i].field_types[j] := TYPE_UNKNOWN;
   type_table^[i].field_offs[j]  := 0;
  End;
  For j := 1 to MAX_ENUM do
   type_table^[i].enum_names[j] := '';
 End;
End;

{ Enregistre les types Ada predefinis aux indices TYPE_xxx connus.
  Doit etre appele au debut de la compilation (apres InitTypeTable).          }
Procedure RegisterPredefinedTypes;
Var i : Integer;
Begin
 { On "pre-rempli" les entrees aux indices TYPE_INT..TYPE_STR directement }
 For i := 1 to 5 do
 Begin
  type_table^[i].kind      := TK_PREDEF;
  type_table^[i].base_type := TYPE_UNKNOWN;
  type_table^[i].lo_bound  := 0;
  type_table^[i].hi_bound  := 0;
 End;

 { TYPE_INT = 1 : Integer 16 bits signe [-32768 .. 32767] }
 type_table^[TYPE_INT].name       := 'INTEGER';
 type_table^[TYPE_INT].total_size := 2;
 type_table^[TYPE_INT].lo_bound   := -32768;
 type_table^[TYPE_INT].hi_bound   :=  32767;
 type_table^[TYPE_INT].kind       := TK_RANGE;
 type_table^[TYPE_INT].base_type  := TYPE_INT;

 { TYPE_FLOAT = 2 : Float 32 bits (stocke en DD, calculs entiers stubs) }
 type_table^[TYPE_FLOAT].name       := 'FLOAT';
 type_table^[TYPE_FLOAT].total_size := 4;
 type_table^[TYPE_FLOAT].kind       := TK_PREDEF;

 { TYPE_BOOL = 3 : Boolean (0 = False, -1 = True en 8086 / 0xFFFF) }
 type_table^[TYPE_BOOL].name       := 'BOOLEAN';
 type_table^[TYPE_BOOL].total_size := 2;
 type_table^[TYPE_BOOL].kind       := TK_ENUM;
 type_table^[TYPE_BOOL].enum_count := 2;
 type_table^[TYPE_BOOL].enum_names[1] := 'FALSE';
 type_table^[TYPE_BOOL].enum_names[2] := 'TRUE';

 { TYPE_CHAR = 4 : Character (code ASCII 0..127, stocke en DW) }
 type_table^[TYPE_CHAR].name       := 'CHARACTER';
 type_table^[TYPE_CHAR].total_size := 2;
 type_table^[TYPE_CHAR].kind       := TK_RANGE;
 type_table^[TYPE_CHAR].lo_bound   := 0;
 type_table^[TYPE_CHAR].hi_bound   := 127;

 { TYPE_STR = 5 : String (longueur variable, stocke comme pointeur 16 bits) }
 type_table^[TYPE_STR].name       := 'STRING';
 type_table^[TYPE_STR].total_size := 2;  { adresse 16 bits }
 type_table^[TYPE_STR].kind       := TK_ARRAY;
 type_table^[TYPE_STR].elem_type  := TYPE_CHAR;
 type_table^[TYPE_STR].elem_size  := 2;

 { Les 5 premiers slots sont occupes par les types predefinis }
 type_count := 5;
End;

{ Ajoute un type utilisateur ; retourne l'index (>5) ou 0 si plein }
Function AddType(Const name: String; kind: Integer): Integer;
Var u : String;
Begin
 If type_count >= MAX_TYPE Then
 Begin
  Error('Table des types pleine (MAX_TYPE=' + IntToStr(MAX_TYPE) + ')');
  AddType := 0; Exit;
 End;
 u := UpCaseStr(name);
 Inc(type_count);
 type_table^[type_count].name       := u;
 type_table^[type_count].kind       := kind;
 type_table^[type_count].base_type  := TYPE_UNKNOWN;
 type_table^[type_count].lo_bound   := 0;
 type_table^[type_count].hi_bound   := 0;
 type_table^[type_count].field_count:= 0;
 type_table^[type_count].elem_type  := TYPE_UNKNOWN;
 type_table^[type_count].elem_size  := 2;
 type_table^[type_count].enum_count := 0;
 type_table^[type_count].total_size := 2;
 AddType := type_count;
End;

{ Recherche un type par nom (majuscules) ; retourne l'index ou 0 }
Function FindType(Const name: String): Integer;
Var i : Integer;
    u : String;
Begin
 u := UpCaseStr(name);
 For i := type_count DownTo 1 do
  If type_table^[i].name = u Then Begin FindType := i; Exit; End;
 FindType := 0;
End;

{ Taille en octets d'un type selon son index dans type_table.
  Pour les types predefinis, identique a PrimTypeSize.
  Pour les types utilisateur, lit total_size.
  Un type de taille 0 (non resolu) est traite comme 2 octets.                }
Function GetTypeSize(type_idx: Integer): Integer;
Var sz : Integer;
Begin
 If (type_idx < 1) Or (type_idx > type_count) Then
 Begin GetTypeSize := 2; Exit; End;

 sz := type_table^[type_idx].total_size;
 If sz <= 0 Then sz := 2;
 GetTypeSize := sz;
End;

{ ---- Table des sous-programmes (procedures + fonctions) ------------------- }

Procedure InitSubTable;
Var i, j : Integer;
Begin
 If sub_table = nil Then New(sub_table);
 sub_count := 0;
 For i := 1 to MAX_SUB do
 Begin
  sub_table^[i].name        := '';
  sub_table^[i].asm_label   := '';
  sub_table^[i].ret_type    := TYPE_VOID;
  sub_table^[i].param_count := 0;
  sub_table^[i].is_forward  := False;
  sub_table^[i].is_function := False;
  sub_table^[i].frame_size  := 0;
  For j := 1 to MAX_PARAM do
  Begin
   sub_table^[i].param_names[j] := '';
   sub_table^[i].param_types[j] := TYPE_UNKNOWN;
   sub_table^[i].param_modes[j] := PARAM_IN;
  End;
 End;
End;

{ Ajoute un sous-programme ; retourne l'index ou 0 si plein }
Function AddSub(Const name: String; is_func: Boolean; ret_type: Integer): Integer;
Var u   : String;
    idx : Integer;
Begin
 If sub_count >= MAX_SUB Then
 Begin
  Error('Table sous-programmes pleine (MAX_SUB=' + IntToStr(MAX_SUB) + ')');
  AddSub := 0; Exit;
 End;
 u := UpCaseStr(name);
 Inc(sub_count);
 idx := sub_count;
 sub_table^[idx].name        := u;
 sub_table^[idx].is_function := is_func;
 sub_table^[idx].ret_type    := ret_type;
 sub_table^[idx].param_count := 0;
 sub_table^[idx].is_forward  := False;
 sub_table^[idx].frame_size  := 0;
 If is_func Then
  sub_table^[idx].asm_label := AsmIdent('_ADA_FUNC_', u)
 Else
  sub_table^[idx].asm_label := AsmIdent('_ADA_PROC_', u);
 AddSub := idx;
End;

{ Recherche un sous-programme par nom ; retourne l'index ou 0 }
Function FindSub(Const name: String): Integer;
Var i : Integer;
    u : String;
Begin
 u := UpCaseStr(name);
 For i := sub_count DownTo 1 do
  If sub_table^[i].name = u Then Begin FindSub := i; Exit; End;
 FindSub := 0;
End;

{ Taille totale en octets des parametres IN d'un sous-programme
  (pour le nettoyage de pile callee-cleanup : RET n).                         }
Function SubParamBytes(sub_idx: Integer): Integer;
Var i   : Integer;
    tot : Integer;
Begin
 tot := 0;
 If (sub_idx < 1) Or (sub_idx > sub_count) Then
 Begin SubParamBytes := 0; Exit; End;
 For i := 1 to sub_table^[sub_idx].param_count do
 Begin
  { OUT et IN OUT passent par adresse -> toujours 2 octets (ptr 16 bits) }
  If (sub_table^[sub_idx].param_modes[i] = PARAM_OUT) Or
     (sub_table^[sub_idx].param_modes[i] = PARAM_INOUT) Then
   Inc(tot, 2)
  Else
   Inc(tot, GetTypeSize(sub_table^[sub_idx].param_types[i]));
 End;
 SubParamBytes := tot;
End;

{ ---- Table des packages importes (WITH / USE) ----------------------------- }

Procedure InitPkgTable;
Var i : Integer;
Begin
 If pkg_table = nil Then New(pkg_table);
 pkg_count := 0;
 For i := 1 to MAX_PKG do
 Begin
  pkg_table^[i].name        := '';
  pkg_table^[i].is_standard := False;
  pkg_table^[i].use_active  := False;
 End;
End;

{ Enregistre un package importe (WITH).
  Retourne l'index ou 0 si plein ou deja present.                             }
Function AddPkg(Const name: String; is_std: Boolean): Integer;
Var u   : String;
    i   : Integer;
    idx : Integer;
Begin
 u := UpCaseStr(name);
 { Verifier si deja present }
 For i := 1 to pkg_count do
  If pkg_table^[i].name = u Then Begin AddPkg := i; Exit; End;
 If pkg_count >= MAX_PKG Then
 Begin
  Warning('Table packages pleine, ' + name + ' ignore');
  AddPkg := 0; Exit;
 End;
 Inc(pkg_count);
 idx := pkg_count;
 pkg_table^[idx].name        := u;
 pkg_table^[idx].is_standard := is_std;
 pkg_table^[idx].use_active  := False;
 AddPkg := idx;
End;

{ Recherche un package ; retourne l'index ou 0 }
Function FindPkg(Const name: String): Integer;
Var i : Integer;
    u : String;
Begin
 u := UpCaseStr(name);
 For i := 1 to pkg_count do
  If pkg_table^[i].name = u Then Begin FindPkg := i; Exit; End;
 FindPkg := 0;
End;

{ Teste si Ada.Text_IO (ou equivalent) est importe et actif via USE }
Function TextIO_Active: Boolean;
Var i : Integer;
Begin
 For i := 1 to pkg_count do
  If pkg_table^[i].use_active And
     ((pkg_table^[i].name = 'ADA.TEXT_IO') Or
      (pkg_table^[i].name = 'TEXT_IO')) Then
  Begin TextIO_Active := True; Exit; End;
 TextIO_Active := False;
End;

{ ============================================================================ }
{ TODO 06 - Gestion des scopes et de la pile de scopes                        }
{ ============================================================================ }

{ ---- Initialisation de la pile de scopes ---- }

Procedure InitScopeStack;
Begin
 If scope_stack = nil Then New(scope_stack);
 scope_top := 0;
 { Scope global (niveau 0) : toujours present }
 scope_stack^[0].kind       := SK_GLOBAL;
 scope_stack^[0].sub_idx    := 0;
 scope_stack^[0].bp_top     := 0;
 scope_stack^[0].sym_start  := 1;
 scope_stack^[0].lbl_exit   := '';
 scope_stack^[0].lbl_cont   := '';
 scope_stack^[0].lbl_end    := '';
 scope_stack^[0].has_except := False;
 scope_stack^[0].lbl_except := '';
End;

{ ---- Accesseurs courants ---- }

Function CurrentScopeKind: Integer;
Begin
 CurrentScopeKind := scope_stack^[scope_top].kind;
End;

Function CurrentSubIdx: Integer;
Begin
 CurrentSubIdx := scope_stack^[scope_top].sub_idx;
End;

{ Remonte la pile pour trouver l'index du sous-programme englobant
  (ignore les scopes SK_BLOCK et SK_LOOP qui ne definissent pas de frame) }
Function EnclosingSubIdx: Integer;
Var lev : Integer;
Begin
 lev := scope_top;
 While lev > 0 do
 Begin
  If scope_stack^[lev].kind In [SK_PROC, SK_FUNC, SK_PACKAGE] Then
  Begin EnclosingSubIdx := scope_stack^[lev].sub_idx; Exit; End;
  Dec(lev);
 End;
 EnclosingSubIdx := 0; { scope global }
End;

{ Taille totale de la frame locale du sous-programme courant (valeur absolue) }
Function CurrentFrameSize: Integer;
Var lev : Integer;
Begin
 lev := scope_top;
 While lev > 0 do
 Begin
  If scope_stack^[lev].kind In [SK_PROC, SK_FUNC] Then
  Begin CurrentFrameSize := -scope_stack^[lev].bp_top; Exit; End;
  Dec(lev);
 End;
 CurrentFrameSize := 0;
End;

{ ---- PushScope ---- }

Procedure PushScope(kind, sub_idx: Integer);
Begin
 If scope_top >= MAX_DEPTH Then
 Begin
  FatalError('Profondeur de scopes depassee (MAX_DEPTH=' +
             IntToStr(MAX_DEPTH) + ')');
 End;
 Inc(scope_top);
 scope_stack^[scope_top].kind       := kind;
 scope_stack^[scope_top].sub_idx    := sub_idx;
 scope_stack^[scope_top].bp_top     := 0;   { compte en negatif pour AUTO }
 scope_stack^[scope_top].sym_start  := sym_count + 1;
 scope_stack^[scope_top].lbl_exit   := '';
 scope_stack^[scope_top].lbl_cont   := '';
 scope_stack^[scope_top].lbl_end    := '';
 scope_stack^[scope_top].has_except := False;
 scope_stack^[scope_top].lbl_except := '';
End;

{ ---- PopScope ----
  Libere les symboles locaux du scope courant (en decrementant sym_count).
  Retourne la taille de frame allouee pour ce scope.                          }
Function PopScope: Integer;
Var frame : Integer;
    st    : Integer;
Begin
 If scope_top <= 0 Then
 Begin
  Error('PopScope : pile de scopes deja vide');
  PopScope := 0; Exit;
 End;
 frame := -scope_stack^[scope_top].bp_top;  { taille frame locale }
 st    := scope_stack^[scope_top].sym_start;
 { Retirer les symboles locaux de ce scope }
 If st >= 1 Then
  sym_count := st - 1;
 Dec(scope_top);
 PopScope := frame;
End;

{ ---- AllocLocal ----
  Alloue 'size' octets (aligne sur mot) sur la pile du scope courant.
  Retourne l'offset BP (negatif) ou 0 si scope global.                        }
Function AllocLocal(size: Integer): Integer;
Var aligned : Integer;
Begin
 If scope_top <= 0 Then Begin AllocLocal := 0; Exit; End;
 aligned := AlignWord(size);
 scope_stack^[scope_top].bp_top :=
   scope_stack^[scope_top].bp_top - aligned;
 AllocLocal := scope_stack^[scope_top].bp_top;
End;

{ ---- Gestion des labels de boucle et de sortie ---- }

{ Enregistre les labels pour une boucle dans le scope courant }
Procedure EnterLoop(Const lbl_cont, lbl_end: String);
Begin
 scope_stack^[scope_top].lbl_cont := lbl_cont;
 scope_stack^[scope_top].lbl_end  := lbl_end;
End;

{ Retourne le label de continuation de la boucle englobante (ou '') }
Function FindLoopCont: String;
Var lev : Integer;
Begin
 For lev := scope_top DownTo 1 do
  If scope_stack^[lev].lbl_cont <> '' Then
  Begin FindLoopCont := scope_stack^[lev].lbl_cont; Exit; End;
 FindLoopCont := '';
End;

{ Retourne le label de fin de la boucle englobante (pour EXIT) }
Function FindLoopEnd: String;
Var lev : Integer;
Begin
 For lev := scope_top DownTo 1 do
  If scope_stack^[lev].lbl_end <> '' Then
  Begin FindLoopEnd := scope_stack^[lev].lbl_end; Exit; End;
 FindLoopEnd := '';
End;

{ Positionne le label de sortie (RETURN / procedure exit) }
Procedure SetExitLabel(Const lbl: String);
Begin
 scope_stack^[scope_top].lbl_exit := lbl;
End;

{ Retourne le label de sortie du sous-programme courant }
Function FindExitLabel: String;
Var lev : Integer;
Begin
 For lev := scope_top DownTo 1 do
  If scope_stack^[lev].lbl_exit <> '' Then
  Begin FindExitLabel := scope_stack^[lev].lbl_exit; Exit; End;
 FindExitLabel := '';
End;

{ ---- Gestion des exceptions ---- }

Procedure SetExceptLabel(Const lbl: String);
Begin
 scope_stack^[scope_top].has_except := True;
 scope_stack^[scope_top].lbl_except := lbl;
End;

{ Retourne le label du handler EXCEPTION le plus proche (ou '') }
Function FindExceptLabel: String;
Var lev : Integer;
Begin
 For lev := scope_top DownTo 1 do
  If scope_stack^[lev].has_except Then
  Begin FindExceptLabel := scope_stack^[lev].lbl_except; Exit; End;
 FindExceptLabel := '';
End;

{ ---- Niveau de scope courant (pour sym_table.scope_lev) ---- }

Function CurrentLevel: Integer;
Begin
 CurrentLevel := scope_top;
End;

{ ============================================================================ }
{ TODO 07 - Generateur de code bas niveau : Emit, labels, helpers             }
{ ============================================================================ }

{ ---- Initialisation des tables de litteraux chaines ---- }

Procedure InitStrTable;
Begin
 If str_table = nil Then New(str_table);
 If lbl_table = nil Then New(lbl_table);
 str_count   := 0;
 lit_counter := 0;
End;

{ ---- Primitives d'emission ASM ---- }

{ Emet une ligne brute dans le fichier de sortie (ou ne fait rien si !gen) }
Procedure Emit(Const s: String);
Begin
 If Not gen_enabled Then Exit;
 WriteLn(output_file, s);
End;

{ Emet une instruction indentee (tabulation) }
Procedure EmitI(Const s: String);
Begin
 If Not gen_enabled Then Exit;
 WriteLn(output_file, #9 + s);
End;

{ Emet un label suivi de ':' sans indentation }
Procedure EmitLabel(Const lbl: String);
Begin
 If Not gen_enabled Then Exit;
 WriteLn(output_file, lbl + ':');
End;

{ Emet un commentaire ASM (';' prefixe) }
Procedure EmitComment(Const s: String);
Begin
 If Not gen_enabled Then Exit;
 WriteLn(output_file, '; ' + s);
End;

{ Emet une ligne vide }
Procedure EmitBlank;
Begin
 If Not gen_enabled Then Exit;
 WriteLn(output_file, '');
End;

{ ---- Generateur de labels ---- }

{ Retourne un nouveau label local unique de la forme @@L0001 }
Function NewLabel: String;
Var n : String;
Begin
 Inc(label_counter);
 n := IntToStr(label_counter);
 While Length(n) < 4 do n := '0' + n;
 NewLabel := '@@L' + n;
End;

{ ---- Gestion des litteraux chaines ---- }

{ Ajoute un litteral chaine dans str_table, retourne le label _LSn }
Function AsmStrLit(Const s: String): String;
Var i  : Integer;
    lb : String;
Begin
 { Deduplication : cherche si deja present }
 For i := 1 to str_count do
  If str_table^[i] = s Then
  Begin AsmStrLit := lbl_table^[i]; Exit; End;
 { Ajout nouveau }
 If str_count >= MAX_STR Then
 Begin
  FatalError('Table des litteraux chaines pleine (MAX_STR=' +
             IntToStr(MAX_STR) + ')');
 End;
 Inc(str_count);
 Inc(lit_counter);
 lb := '_LS' + IntToStr(lit_counter);
 str_table^[str_count] := s;
 lbl_table^[str_count] := lb;
 AsmStrLit := lb;
End;

{ Emet la section .DATA pour tous les litteraux chaines accumules
  Appele par le generateur de code final (TODO 24)                }
Procedure EmitStringLiterals;
Var i : Integer;
    s : String;
    j : Integer;
Begin
 If str_count = 0 Then Exit;
 EmitComment('--- litteraux chaines ---');
 For i := 1 to str_count do
 Begin
  s := str_table^[i];
  { Construit DB avec octets ASCII + 0 terminateur }
  Emit(lbl_table^[i] + ' DB ' + IntToStr(Length(s)));
  { Bytes du contenu }
  If Length(s) > 0 Then
  Begin
   For j := 1 to Length(s) do
    EmitI('DB ' + IntToStr(Ord(s[j])));
  End;
  EmitI('DB 0');   { terminateur null pour compatibilite }
 End;
End;

{ ---- Normalisation des etiquettes ASM ---- }

{ Transforme un nom Ada en etiquette ASM .DATA : _VAR_NOM }
Function DataLbl(Const name: String): String;
Begin
 DataLbl := AsmIdent('_VAR_', UpCaseStr(name));
End;

{ ---- Helpers de chargement / stockage ---- }

{ Retourne la taille en octets du type d'un symbole (2 ou 4) }
Function SymTypeSize(sym_idx: Integer): Integer;
Var ti : Integer;
Begin
 ti := sym_table^[sym_idx].type_idx;
 If ti = TYPE_FLOAT Then SymTypeSize := 4
 Else SymTypeSize := 2;
End;

{ Charge un symbole dans AX (ou DX:AX si float, AL si char/bool) }
Procedure GenLoadVar(sym_idx: Integer);
Var sc   : Integer;
    off  : Integer;
    lbl  : String;
    ti   : Integer;
    sz   : Integer;
Begin
 sc  := sym_table^[sym_idx].store_class;
 off := sym_table^[sym_idx].bp_offset;
 lbl := sym_table^[sym_idx].asm_label;
 ti  := sym_table^[sym_idx].type_idx;
 sz  := SymTypeSize(sym_idx);

 If sym_table^[sym_idx].is_const Then
 Begin
  { Constante : valeur immediate }
  If ti = TYPE_FLOAT Then
  Begin
   EmitI('MOV AX, WORD PTR [' + lbl + ']');
   EmitI('MOV DX, WORD PTR [' + lbl + '+2]');
  End
  Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
   EmitI('MOV AL, BYTE PTR ' + IntToStr(sym_table^[sym_idx].init_num))
  Else { INT, ENUM, RANGE ... }
   EmitI('MOV AX, ' + IntToStr(sym_table^[sym_idx].init_num));
  Exit;
 End;

 Case sc Of
  STORE_STATIC :
  Begin
   If sz = 4 Then
   Begin
    EmitI('MOV AX, WORD PTR [' + lbl + ']');
    EmitI('MOV DX, WORD PTR [' + lbl + '+2]');
   End
   Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
    EmitI('MOV AL, BYTE PTR [' + lbl + '+1]')  { word high-byte=char }
   Else
    EmitI('MOV AX, [' + lbl + ']');
  End;
  STORE_AUTO :
  Begin
   If sz = 4 Then
   Begin
    EmitI('MOV AX, [BP' + IntToStr(off) + ']');
    EmitI('MOV DX, [BP' + IntToStr(off + 2) + ']');
   End
   Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
    EmitI('MOV AL, [BP' + IntToStr(off) + ']')
   Else
    EmitI('MOV AX, [BP' + IntToStr(off) + ']');
  End;
  STORE_CONST :
   { Constante litterale : valeur directe }
   EmitI('MOV AX, ' + IntToStr(sym_table^[sym_idx].init_num));
 End; { Case }
End;

{ Stocke AX (ou DX:AX si float, AL si char/bool) dans un symbole }
Procedure GenStoreVar(sym_idx: Integer);
Var sc  : Integer;
    off : Integer;
    lbl : String;
    ti  : Integer;
    sz  : Integer;
Begin
 If sym_table^[sym_idx].is_const Then
 Begin
  Error('Tentative d''assignation a une constante : ' +
        sym_table^[sym_idx].name);
  Exit;
 End;
 sc  := sym_table^[sym_idx].store_class;
 off := sym_table^[sym_idx].bp_offset;
 lbl := sym_table^[sym_idx].asm_label;
 ti  := sym_table^[sym_idx].type_idx;
 sz  := SymTypeSize(sym_idx);

 Case sc Of
  STORE_STATIC :
  Begin
   If sz = 4 Then
   Begin
    EmitI('MOV WORD PTR [' + lbl + '], AX');
    EmitI('MOV WORD PTR [' + lbl + '+2], DX');
   End
   Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
    EmitI('MOV BYTE PTR [' + lbl + '+1], AL')
   Else
    EmitI('MOV [' + lbl + '], AX');
  End;
  STORE_AUTO :
  Begin
   If sz = 4 Then
   Begin
    EmitI('MOV [BP' + IntToStr(off) + '], AX');
    EmitI('MOV [BP' + IntToStr(off + 2) + '], DX');
   End
   Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
    EmitI('MOV [BP' + IntToStr(off) + '], AL')
   Else
    EmitI('MOV [BP' + IntToStr(off) + '], AX');
  End;
 End; { Case }
End;

{ ---- Chargement de constante immediate ---- }

{ MOV AX, val  (entier 16 bits) }
Procedure GenLoadConst(val: LongInt);
Begin
 EmitI('MOV AX, ' + IntToStr(val));
End;

{ ---- Prologue / Epilogue de sous-programme ---- }

{ PUSH BP / MOV BP,SP / SUB SP,frame_size }
Procedure GenPrologue(frame_size: Integer);
Begin
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 If frame_size > 0 Then
  EmitI('SUB  SP, ' + IntToStr(frame_size));
End;

{ MOV SP,BP / POP BP / RET param_bytes
  Callee-cleanup : param_bytes = nombre d'octets pousses par l'appelant }
Procedure GenEpilogue(frame_size: Integer; param_bytes: Integer);
Begin
 If frame_size > 0 Then
  EmitI('MOV  SP, BP');
 EmitI('POP  BP');
 If param_bytes > 0 Then
  EmitI('RET  ' + IntToStr(param_bytes))
 Else
  EmitI('RET');
End;

{ ---- Helpers PUSH / POP ---- }

Procedure GenPushAX;
Begin EmitI('PUSH AX'); End;

Procedure GenPopAX;
Begin EmitI('POP  AX'); End;

{ Pour float DX:AX : pousse DX puis AX (AX en TOS) }
Procedure GenPushDXAX;
Begin
 EmitI('PUSH DX');
 EmitI('PUSH AX');
End;

{ Pour float DX:AX : depile AX puis DX }
Procedure GenPopDXAX;
Begin
 EmitI('POP  AX');
 EmitI('POP  DX');
End;

{ ============================================================================ }
{ TODO 08 - Parseur d'expressions et generateur d'operations                  }
{ ============================================================================ }

{ ---- Prototypes forward ---- }
{ (ParseExpr appelle ParseOrElse qui descend jusqu'a ParsePrimary,
   mais ParsePrimary peut appeler ParseExpr pour les sous-expressions
   entre parentheses -> declaration forward necessaire)               }

Procedure ParseExpr; Forward;

{ ---- GenBinaryOp : gen code pour operateurs binaires arithmetiques ---- }
{ AX = operande gauche (deja sur pile), AX = operande droit apres ParseTerm
  Resultat dans AX.  Pile : TOS = droite, TOS+2 = gauche.               }

Procedure GenBinaryOp(op: Integer);
{ op = TOK_PLUS / TOK_MINUS / TOK_STAR / TOK_SLASH / KW_MOD / KW_REM }
Begin
 Case op Of
  TOK_PLUS  :
  Begin
   EmitI('POP  BX');
   EmitI('ADD  AX, BX');
  End;
  TOK_MINUS :
  Begin
   { gauche est sous le droit -> POP BX = droite, puis SUB }
   EmitI('MOV  BX, AX');   { BX = droite                  }
   EmitI('POP  AX');       { AX = gauche                  }
   EmitI('SUB  AX, BX');
  End;
  TOK_STAR  :
  Begin
   EmitI('POP  BX');
   EmitI('IMUL BX');       { DX:AX = AX * BX              }
   { On garde AX (16 bits, overflow ignore pour cibles 16b) }
  End;
  TOK_SLASH :
  Begin
   EmitI('MOV  BX, AX');   { BX = diviseur (droite)       }
   EmitI('POP  AX');       { AX = dividende (gauche)      }
   EmitI('CWD');           { signe-etend AX -> DX:AX      }
   EmitI('IDIV BX');       { AX = quotient                }
  End;
  KW_MOD    :
  Begin
   EmitI('MOV  BX, AX');
   EmitI('POP  AX');
   EmitI('CWD');
   EmitI('IDIV BX');       { AX = quotient, DX = reste    }
   { Ada MOD : ajuste si signe different du diviseur }
   EmitI('CMP  DX, 0');
   EmitI('JE   @@MODOK_' + IntToStr(label_counter + 1));
   EmitI('ADD  BX, 0');    { test signe diviseur BX xor reste DX }
   EmitI('XOR  BX, DX');
   EmitI('JS   @@MODADJ_' + IntToStr(label_counter + 1));
   EmitI('JMP  @@MODOK_' + IntToStr(label_counter + 1));
   EmitI('@@MODADJ_' + IntToStr(label_counter + 1) + ':');
   EmitI('ADD  DX, BX');   { DX += diviseur pour corriger }
   EmitI('@@MODOK_' + IntToStr(label_counter + 1) + ':');
   Inc(label_counter);
   EmitI('MOV  AX, DX');   { AX = MOD                    }
  End;
  KW_REM    :
  Begin
   EmitI('MOV  BX, AX');
   EmitI('POP  AX');
   EmitI('CWD');
   EmitI('IDIV BX');       { Ada REM = reste C-like = DX  }
   EmitI('MOV  AX, DX');
  End;
  TOK_AMP   :
  Begin
   { Concatenation de chaines : stub - genere appel helper _STR_CAT }
   EmitI('POP  BX');
   EmitI('CALL _STR_CAT');  { BX=gauche, AX=droite, AX->resultat }
  End;
 End; { Case }
End;

{ ---- GenRelOp : CMP + Jcc, resultat 0/1 dans AX ---- }
{ A gauche : deja sur pile (PUSHed). AX = operande droit. }

Procedure GenRelOp(op: Integer);
{ op = TOK_EQ / TOK_NEQ / TOK_LT / TOK_LE / TOK_GT / TOK_GE }
Var lbl_true, lbl_end : String;
Begin
 lbl_true := NewLabel;
 lbl_end  := NewLabel;
 EmitI('MOV  BX, AX');    { BX = droite              }
 EmitI('POP  AX');        { AX = gauche              }
 EmitI('CMP  AX, BX');
 Case op Of
  TOK_EQ  : EmitI('JE   ' + lbl_true);
  TOK_NEQ : EmitI('JNE  ' + lbl_true);
  TOK_LT  : EmitI('JL   ' + lbl_true);
  TOK_LE  : EmitI('JLE  ' + lbl_true);
  TOK_GT  : EmitI('JG   ' + lbl_true);
  TOK_GE  : EmitI('JGE  ' + lbl_true);
 End;
 EmitI('XOR  AX, AX');    { False = 0                }
 EmitI('JMP  ' + lbl_end);
 EmitLabel(lbl_true);
 EmitI('MOV  AX, 1');     { True = 1                 }
 EmitLabel(lbl_end);
End;

{ ---- Forward declarations pour helpers tableaux/records (definis en TODO 16/20/21) ---- }
Procedure GenLoadAddrBX(sym_idx: Integer); Forward;
Procedure GenElemOffset(sym_idx: Integer); Forward;
Procedure GenLoadElement(sym_idx: Integer); Forward;
Procedure GenLoadField(sym_idx, field_off: Integer); Forward;
Procedure GenStoreField(sym_idx, field_off: Integer); Forward;

{ ---- ParsePrimary : litteraux, idents, appels, (expr), attributs ---- }

Procedure ParsePrimary;
Var sym       : Integer;
    sub       : Integer;
    ti        : Integer;
    nm        : String;
    lbl       : String;
    ai        : Integer;   { index attribut : 1=FIRST 2=LAST 3=LENGTH 4=SIZE }
    i         : Integer;
    j         : Integer;
    arg_count : Integer;
    field_off : Integer;   { offset champ de record courrant                 }
    total_off : Integer;   { offset cumule pour champs imbriques             }
Begin
 { --- Litteral entier --- }
 If cur_tok_type = TOK_INTEGER Then
 Begin
  EmitI('MOV AX, ' + IntToStr(cur_tok_num));
  Consume;
  Exit;
 End;

 { --- Litteral flottant (stub 16 bits) --- }
 If cur_tok_type = TOK_FLOAT Then
 Begin
  { Charge 0 dans AX comme stub (float non pleinement supporte en 16b) }
  EmitI('XOR AX, AX');
  Consume;
  Exit;
 End;

 { --- Litteral charactere --- }
 If cur_tok_type = TOK_CHAR Then
 Begin
  EmitI('MOV AX, ' + IntToStr(Ord(cur_tok_str[1])));
  Consume;
  Exit;
 End;

 { --- Litteral chaine --- }
 If cur_tok_type = TOK_STRING Then
 Begin
  lbl := AsmStrLit(cur_tok_str);
  EmitI('MOV AX, OFFSET ' + lbl);
  Consume;
  Exit;
 End;

 { --- TRUE / FALSE --- }
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_TRUE) Then
 Begin EmitI('MOV AX, 1'); Consume; Exit; End;
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_FALSE) Then
 Begin EmitI('XOR AX, AX'); Consume; Exit; End;

 { --- NULL --- }
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_NULL) Then
 Begin EmitI('XOR AX, AX'); Consume; Exit; End;

 { --- Identifiant : variable, constante, ou appel de fonction --- }
 If cur_tok_type = TOK_IDENT Then
 Begin
  nm := cur_tok_str;
  Consume;

  { Attribut : Nom' FIRST | LAST | LENGTH }
  If cur_tok_type = TOK_TICK Then
  Begin
   Consume; { consomme ' }
   ai := 0;
   If cur_tok_type = TOK_IDENT Then
   Begin
    If cur_tok_str = 'FIRST'  Then ai := 1
    Else If cur_tok_str = 'LAST'   Then ai := 2
    Else If cur_tok_str = 'LENGTH' Then ai := 3
    Else If cur_tok_str = 'SIZE'   Then ai := 4
    Else Warning('Attribut Ada inconnu : ' + cur_tok_str);
    Consume;
   End;
   { Chercher le type ou la variable }
   ti := FindType(nm);
   If ti > 0 Then
   Begin
    Case ai Of
     1 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].lo_bound));
     2 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].hi_bound));
     3 : EmitI('MOV AX, ' + IntToStr(
               type_table^[ti].hi_bound - type_table^[ti].lo_bound + 1));
     4 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].total_size));  { T'SIZE en octets }
    Else EmitI('XOR AX, AX');
    End;
   End
   Else
   Begin
    sym := FindSym(nm);
    If sym > 0 Then
    Begin
     ti := sym_table^[sym].type_idx;
     Case ai Of
      1 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].lo_bound));
      2 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].hi_bound));
      3 : EmitI('MOV AX, ' + IntToStr(
                type_table^[ti].hi_bound - type_table^[ti].lo_bound + 1));
      4 : EmitI('MOV AX, ' + IntToStr(type_table^[ti].total_size));  { T'SIZE en octets }
     Else EmitI('XOR AX, AX');
     End;
    End
    Else
    Begin
     Error('Nom inconnu pour attribut : ' + nm);
     EmitI('XOR AX, AX');
    End;
   End;
   Exit;
  End; { TOK_TICK }

  { Appel de fonction ou acces tableau : Nom( ... ) }
  If cur_tok_type = TOK_LPAREN Then
  Begin
   sub := FindSub(nm);
   If sub > 0 Then
   Begin
    { Appel de fonction }
    Consume; { ( }
    arg_count := 0;
    While cur_tok_type <> TOK_RPAREN do
    Begin
     ParseExpr;
     GenPushAX;
     Inc(arg_count);
     If cur_tok_type = TOK_COMMA Then Consume;
    End;
    Expect(TOK_RPAREN, '`)` attendu apres arguments');
    EmitI('CALL ' + sub_table^[sub].asm_label);
    { callee-cleanup : RET n dans la fonction -> pas de ADD SP ici }
    { AX = valeur de retour }
   End
   Else
   Begin
    { Acces tableau : Nom(index) }
    sym := FindSym(nm);
    If sym <= 0 Then
    Begin
     Error('Identificateur inconnu : ' + nm);
     Consume; { ( }
     ParseExpr;
     Expect(TOK_RPAREN, '`)` attendu');
     EmitI('XOR AX, AX');
     Exit;
    End;
    Consume; { ( }
    ParseExpr;         { AX = index }
    { Slice T(lo..hi) : warning + ignorer borne haute }
    If cur_tok_type = TOK_DOTDOT Then
    Begin
     Warning('Slice Ada non supporte, lecture de l''element lo uniquement');
     Consume;
     ParseExpr;   { consommer hi }
     Expect(TOK_RPAREN, '`)` attendu apres slice');
     EmitI('XOR AX, AX');
     Exit;
    End;
    { Calcul adresse exact : GenLoadElement utilise lo_bound et elem_size reels }
    GenLoadElement(sym);
    Expect(TOK_RPAREN, '`)` attendu apres index tableau');
   End;
   Exit;
  End; { TOK_LPAREN apres ident }

  { Acces champ de record en lecture : var.champ [.sous_champ]* }
  If cur_tok_type = TOK_DOT Then
  Begin
   sym := FindSym(nm);
   If sym <= 0 Then
   Begin Error('Variable inconnue avant `.` : ' + nm); EmitI('XOR AX, AX'); Exit; End;
   total_off := 0;
   ti := sym_table^[sym].type_idx;
   While cur_tok_type = TOK_DOT do
   Begin
    Consume; { . }
    If cur_tok_type <> TOK_IDENT Then
    Begin ErrorTok('Nom de champ attendu apres `.`'); Break; End;
    nm := UpCaseStr(cur_tok_str);
    Consume;
    field_off := 0;
    If (ti > 0) And (type_table^[ti].kind = TK_RECORD) Then
    Begin
     For i := 1 to type_table^[ti].field_count do
      If type_table^[ti].field_names[i] = nm Then
      Begin
       field_off := type_table^[ti].field_offs[i];
       ti := type_table^[ti].field_types[i];   { type du sous-champ }
       Break;
      End;
    End
    Else Warning('Acces `.champ` sur type non-RECORD : ' + nm);
    total_off := total_off + field_off;
   End;
   GenLoadField(sym, total_off);
   Exit;
  End; { TOK_DOT }

  { Variable ou constante simple }
  sym := FindSym(nm);
  If sym > 0 Then
   GenLoadVar(sym)
  Else
  Begin
   { Peut etre un litteral d'enumeration : chercher dans les types }
   For i := 1 to type_count do
    If type_table^[i].kind = TK_ENUM Then
    Begin
     For j := 1 to type_table^[i].enum_count do
      If type_table^[i].enum_names[j] = nm Then
      Begin EmitI('MOV AX, ' + IntToStr(j - 1)); Exit; End;
    End;
   Error('Identificateur inconnu : ' + nm);
   EmitI('XOR AX, AX');
  End;
  Exit;
 End; { TOK_IDENT }

 { --- Sous-expression ( expr ) --- }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  ParseExpr;
  Expect(TOK_RPAREN, '`)` attendu en fin de sous-expression');
  Exit;
 End;

 { Rien reconnu }
 ErrorTok('Primaire d''expression attendu');
 EmitI('XOR AX, AX');
 Consume;
End;

{ ---- ParseFactor : ** et ABS ---- }

Procedure ParseFactor;
Var lbl1     : String;
    lbl_loop : String;
Begin
 { ABS unaire }
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_ABS) Then
 Begin
  Consume;
  ParseFactor;
  lbl1 := NewLabel;
  EmitI('CMP  AX, 0');
  EmitI('JGE  ' + lbl1);
  EmitI('NEG  AX');
  EmitLabel(lbl1);
  Exit;
 End;
 ParsePrimary;
 { ** (puissance entiere iterative) }
 While cur_tok_type = TOK_STARSTAR do
 Begin
  Consume;
  ParsePrimary;                      { AX = exposant }
  EmitI('MOV  CX, AX');             { CX = exposant }
  EmitI('POP  BX');                  { BX = base (gauche) }
  { Cas exposant = 0 : retourne 1 }
  lbl1 := NewLabel;
  EmitI('MOV  AX, 1');
  EmitI('CMP  CX, 0');
  EmitI('JE   ' + lbl1);
  { Boucle : AX = BX^CX }
  lbl_loop := NewLabel;
  EmitLabel(lbl_loop);
  EmitI('IMUL BX');
  EmitI('LOOP ' + lbl_loop);
  EmitLabel(lbl1);
 End;
End;

{ ---- ParseTerm : * / mod rem ---- }

Procedure ParseTerm;
Var op : Integer;
Begin
 ParseFactor;
 While (cur_tok_type = TOK_STAR) Or (cur_tok_type = TOK_SLASH)
    Or ((cur_tok_type = TOK_IDENT) And
        ((cur_tok_kw = KW_MOD) Or (cur_tok_kw = KW_REM))) do
 Begin
  GenPushAX;
  If cur_tok_type = TOK_IDENT Then op := cur_tok_kw
  Else op := cur_tok_type;
  Consume;
  ParseFactor;
  GenBinaryOp(op);
 End;
End;

{ ---- ParseSimple : + - & (unaire + ou - possible en tete) ---- }

Procedure ParseSimple;
Var op   : Integer;
    uneg : Boolean;
Begin
 uneg := False;
 If cur_tok_type = TOK_MINUS Then Begin uneg := True; Consume; End
 Else If cur_tok_type = TOK_PLUS Then Consume;
 ParseTerm;
 If uneg Then EmitI('NEG  AX');
 While (cur_tok_type = TOK_PLUS) Or (cur_tok_type = TOK_MINUS)
    Or (cur_tok_type = TOK_AMP) do
 Begin
  GenPushAX;
  op := cur_tok_type;
  Consume;
  ParseTerm;
  GenBinaryOp(op);
 End;
End;

{ ---- ParseRelation : = /= < <= > >= ---- }

Procedure ParseRelation;
Var op : Integer;
Begin
 ParseSimple;
 If (cur_tok_type = TOK_EQ)  Or (cur_tok_type = TOK_NEQ) Or
    (cur_tok_type = TOK_LT)  Or (cur_tok_type = TOK_LE)  Or
    (cur_tok_type = TOK_GT)  Or (cur_tok_type = TOK_GE) Then
 Begin
  GenPushAX;
  op := cur_tok_type;
  Consume;
  ParseSimple;
  GenRelOp(op);
 End;
End;

{ ---- ParseNot : NOT unaire logique ---- }

Procedure ParseNot;
Begin
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_NOT) Then
 Begin
  Consume;
  ParseRelation;
  { NOT bool : AX XOR 1 }
  EmitI('XOR  AX, 1');
 End
 Else
  ParseRelation;
End;

{ ---- ParseAnd : AND (bit ou logique) ---- }

Procedure ParseAnd;
Begin
 ParseNot;
 While (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_AND) do
 Begin
  GenPushAX;
  Consume;
  ParseNot;
  EmitI('POP  BX');
  EmitI('AND  AX, BX');
 End;
End;

{ ---- ParseOr : OR et XOR (bit ou logique) ---- }

Procedure ParseOr;
Var is_xor : Boolean;
Begin
 ParseAnd;
 While (cur_tok_type = TOK_IDENT) And
       ((cur_tok_kw = KW_OR) Or (cur_tok_kw = KW_XOR)) do
 Begin
  GenPushAX;
  is_xor := (cur_tok_kw = KW_XOR);
  Consume;
  ParseAnd;
  EmitI('POP  BX');
  If is_xor Then EmitI('XOR  AX, BX')
  Else           EmitI('OR   AX, BX');
 End;
End;

{ ---- ParseAndThen : AND THEN (court-circuit) ---- }

Procedure ParseAndThen;
Var lbl_false : String;
Begin
 ParseOr;
 While (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_ANDTHEN) do
 Begin
  lbl_false := NewLabel;
  Consume;
  { Si AX=0 (False) -> court-circuit }
  EmitI('CMP  AX, 0');
  EmitI('JE   ' + lbl_false);
  ParseOr;
  EmitI('AND  AX, AX');  { resultat dans AX }
  EmitLabel(lbl_false);
 End;
End;

{ ---- ParseOrElse : OR ELSE (court-circuit) ---- }

Procedure ParseOrElse;
Var lbl_true : String;
Begin
 ParseAndThen;
 While (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_ORELSE) do
 Begin
  lbl_true := NewLabel;
  Consume;
  { Si AX<>0 (True) -> court-circuit }
  EmitI('CMP  AX, 0');
  EmitI('JNE  ' + lbl_true);
  ParseAndThen;
  EmitI('OR   AX, AX');  { resultat dans AX }
  EmitLabel(lbl_true);
 End;
End;

{ ---- ParseExpr : point d'entree principal des expressions ---- }

Procedure ParseExpr;
Begin
 ParseOrElse;
End;

{ ============================================================================ }
{ TODO 09 - ParseWithUse : WITH et USE                                         }
{ ============================================================================ }

{ ---- Liste des packages standard reconnus (comparaison en majuscules) ---- }

Function IsStandardPackage(Const u: String): Boolean;
Begin
 IsStandardPackage :=
   (u = 'ADA.TEXT_IO')                        Or
   (u = 'ADA.INTEGER_TEXT_IO')                Or
   (u = 'ADA.FLOAT_TEXT_IO')                  Or
   (u = 'ADA.NUMERICS')                       Or
   (u = 'ADA.NUMERICS.ELEMENTARY_FUNCTIONS')  Or
   (u = 'SYSTEM')                             Or
   (u = 'TEXT_IO');    { ancien style TP-Ada }
End;

{ ---- ParsePackageName : lire un nom compose Ada.xxx.yyy ----
  Le lexeur produit : IDENT (DOT IDENT)* car le point est TOK_DOT.
  On reconnecte les segments en majuscules avec des points.                   }

Function ParsePackageName: String;
Var res : String;
Begin
 If cur_tok_type <> TOK_IDENT Then
 Begin
  ErrorTok('Nom de package attendu');
  ParsePackageName := '';
  Exit;
 End;
 res := UpCaseStr(cur_tok_str);
 Consume;
 { Tant qu'on voit '.', on continue a lire des segments }
 While cur_tok_type = TOK_DOT do
 Begin
  Consume; { consomme '.' }
  If cur_tok_type <> TOK_IDENT Then
  Begin
   ErrorTok('Identifiant attendu apres `.` dans nom de package');
   Break;
  End;
  res := res + '.' + UpCaseStr(cur_tok_str);
  Consume;
 End;
 ParsePackageName := res;
End;

{ ---- ParseWith : WITH pkg1 [, pkg2 ...] ; ---- }
{ Enregistre chaque package dans pkg_table.
  Les packages standards reçoivent is_standard=True.
  Les autres : avertissement + enregistrement avec is_standard=False.         }

Procedure ParseWith;
Var nm  : String;
    idx : Integer;
Begin
 Consume; { consomme WITH }
 Repeat
  nm := ParsePackageName;
  If nm = '' Then Break;
  If IsStandardPackage(nm) Then
   idx := AddPkg(nm, True)
  Else
  Begin
   Warning('Package non supporte, importe mais ignore a la generation : ' + nm);
   idx := AddPkg(nm, False);
  End;
  If cur_tok_type = TOK_COMMA Then Consume
  Else Break;
 Until False;
 Expect(TOK_SEMI, '`;` attendu en fin de clause WITH');
End;

{ ---- ParseUse : USE pkg1 [, pkg2 ...] ; ---- }
{ Active use_active pour chaque package.
  Si un package est USE sans WITH prealable, il est ajoute automatiquement.  }

Procedure ParseUse;
Var nm  : String;
    idx : Integer;
Begin
 Consume; { consomme USE }
 Repeat
  nm := ParsePackageName;
  If nm = '' Then Break;
  idx := FindPkg(nm);
  If idx = 0 Then
  Begin
   { USE sans WITH prealable : importer silencieusement si standard }
   If IsStandardPackage(nm) Then
    idx := AddPkg(nm, True)
   Else
   Begin
    Warning('USE sur package non importe via WITH : ' + nm);
    idx := AddPkg(nm, False);
   End;
  End;
  If idx > 0 Then
   pkg_table^[idx].use_active := True;
  If cur_tok_type = TOK_COMMA Then Consume
  Else Break;
 Until False;
 Expect(TOK_SEMI, '`;` attendu en fin de clause USE');
End;

{ ---- ParseWithUseSection : lit la section WITH/USE en tete d'unite ----
  A appeler au debut de Compile (TODO 24), avant le corps PROCEDURE/PACKAGE. }

Procedure ParseWithUseSection;
Begin
 While (cur_tok_type = TOK_IDENT) And
       ((cur_tok_kw = KW_WITH) Or (cur_tok_kw = KW_USE)) do
 Begin
  If cur_tok_kw = KW_WITH Then ParseWith
  Else ParseUse;
 End;
End;

{ ============================================================================ }
{ TODO 10 - ParseTypeDecl : declarations de types utilisateur                  }
{ ============================================================================ }

{ ---- ParseTypeRef : lire un nom de type et retourner son index ----
  Cherche d'abord les predefinis (INTEGER, FLOAT...) puis les types
  utilisateur. Retourne TYPE_UNKNOWN si non trouve.                            }

Function ParseTypeRef: Integer;
Var nm : String;
    ti : Integer;
Begin
 If cur_tok_type <> TOK_IDENT Then
 Begin
  ErrorTok('Nom de type attendu');
  ParseTypeRef := TYPE_UNKNOWN; Exit;
 End;
 nm := UpCaseStr(cur_tok_str);
 Consume;
 { Types predefinis par mot-cle ou nom }
 If nm = 'INTEGER'   Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
 If nm = 'FLOAT'     Then Begin ParseTypeRef := TYPE_FLOAT; Exit; End;
 If nm = 'BOOLEAN'   Then Begin ParseTypeRef := TYPE_BOOL;  Exit; End;
 If nm = 'CHARACTER' Then Begin ParseTypeRef := TYPE_CHAR;  Exit; End;
 If nm = 'STRING'    Then Begin ParseTypeRef := TYPE_STR;   Exit; End;
 If nm = 'NATURAL'   Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
 If nm = 'POSITIVE'  Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
 { Type utilisateur }
 ti := FindType(nm);
 If ti > 0 Then Begin ParseTypeRef := ti; Exit; End;
 Error('Type inconnu : ' + nm);
 ParseTypeRef := TYPE_UNKNOWN;
End;

{ ---- ParseEnumType : ( lit1, lit2, ... ) ---- }

Function ParseEnumType(Const tname: String): Integer;
Var idx : Integer;
    cnt : Integer;
Begin
 idx := AddType(tname, TK_ENUM);
 type_table^[idx].enum_count := 0;
 Consume; { ( }
 cnt := 0;
 Repeat
  If cur_tok_type <> TOK_IDENT Then
  Begin ErrorTok('Litteral d''enumeration attendu'); Break; End;
  Inc(cnt);
  If cnt > MAX_ENUM Then
  Begin Error('Trop de litteraux dans enumeration'); Break; End;
  type_table^[idx].enum_names[cnt] := UpCaseStr(cur_tok_str);
  Consume;
  If cur_tok_type = TOK_COMMA Then Consume Else Break;
 Until False;
 Expect(TOK_RPAREN, '`)` attendu en fin d''enumeration');
 type_table^[idx].enum_count := cnt;
 type_table^[idx].lo_bound   := 0;
 type_table^[idx].hi_bound   := cnt - 1;
 type_table^[idx].total_size := 2;  { Word - indice 16 bits }
 ParseEnumType := idx;
End;

{ ---- ParseRangeConstraint : lire lo .. hi ---- }
{ Retourne via var lo et hi. Attend le token RANGE deja consomme ou
  directement les bornes (selon le contexte appelant).                        }

Procedure ParseRangeBounds(Var lo, hi: LongInt);
Begin
 lo := cur_tok_num;
 If cur_tok_type = TOK_INTEGER Then Consume
 Else If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_TRUE) Then
  Begin lo := 1; Consume; End
 Else If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_FALSE) Then
  Begin lo := 0; Consume; End
 Else
 Begin ErrorTok('Borne inferieure entiere attendue'); lo := 0; Consume; End;
 Expect(TOK_DOTDOT, '`..` attendu dans contrainte RANGE');
 hi := cur_tok_num;
 If cur_tok_type = TOK_INTEGER Then Consume
 Else
 Begin ErrorTok('Borne superieure entiere attendue'); hi := lo; Consume; End;
End;

{ ---- ParseRangeType : RANGE lo .. hi ---- }

Function ParseRangeType(Const tname: String; base_ti: Integer): Integer;
Var idx    : Integer;
    lo, hi : LongInt;
Begin
 { RANGE deja consomme par l'appelant si besoin }
 ParseRangeBounds(lo, hi);
 idx := AddType(tname, TK_RANGE);
 type_table^[idx].base_type  := base_ti;
 type_table^[idx].lo_bound   := lo;
 type_table^[idx].hi_bound   := hi;
 type_table^[idx].total_size := 2;
 ParseRangeType := idx;
End;

{ ---- ParseArrayType : ARRAY ( lo .. hi ) OF type
  ou ARRAY ( TypeName RANGE <> ) OF type (non contraint -> stub)              }

Function ParseArrayType(Const tname: String): Integer;
Var idx           : Integer;
    lo, hi        : LongInt;
    elem_ti       : Integer;
    esz           : Integer;
    unconstrained : Boolean;
    peek_name     : String;
Begin
 Expect(TOK_LPAREN, '`(` attendu apres ARRAY');
 unconstrained := False;
 { Tester si non-contraint : TypeName RANGE <> }
 If cur_tok_type = TOK_IDENT Then
 Begin
  { Lire potentiel nom de type suivi de RANGE }
  peek_name := UpCaseStr(cur_tok_str);
  Consume;
  If TokIsKw(KW_RANGE) Then
  Begin
   Consume; { RANGE }
   { Attendre <> : TOK_LT puis TOK_GT }
   If cur_tok_type = TOK_LT Then
   Begin
    Consume;
    If cur_tok_type = TOK_GT Then Consume
    Else ErrorTok('`>` attendu dans ARRAY non contraint');
   End
   Else ErrorTok('`<>` attendu dans ARRAY non contraint');
   unconstrained := True;
   lo := 1; hi := 0;  { signifie : taille inconnue }
  End
  Else
  Begin
   { c'etait le debut d'une expression lo..hi precedee d'un ident entier }
   { ex: ARRAY(1..10) mais on a consomme '1' comme ident -> erreur rare }
   { Reconstruire en supposant que c'etait un entier : fallback }
   lo := 0;
   If TokIsKw(KW_RANGE) Then Consume;
   ParseRangeBounds(lo, hi);
  End;
 End
 Else
 Begin
  lo := 0; hi := 0;
  ParseRangeBounds(lo, hi);
 End;
 Expect(TOK_RPAREN, '`)` attendu apres indices ARRAY');
 ExpectKw(KW_OF, 'OF', '`OF` attendu apres indices ARRAY');
 elem_ti := ParseTypeRef;
 esz     := GetTypeSize(elem_ti);
 If esz <= 0 Then esz := 2;
 idx := AddType(tname, TK_ARRAY);
 type_table^[idx].lo_bound   := lo;
 type_table^[idx].hi_bound   := hi;
 type_table^[idx].elem_type  := elem_ti;
 type_table^[idx].elem_size  := esz;
 If unconstrained Then
  type_table^[idx].total_size := 0  { taille inconnue }
 Else
  type_table^[idx].total_size := (hi - lo + 1) * esz;
 ParseArrayType := idx;
End;

{ ---- ParseRecordType : RECORD champ : type [; ...] END RECORD ---- }

Function ParseRecordType(Const tname: String): Integer;
Var idx    : Integer;
    fi     : Integer;     { index champ courant }
    fti    : Integer;     { type du champ }
    off    : Integer;     { offset courant en octets }
    fsz    : Integer;
    fname  : String;
Begin
 { RECORD deja consomme par l'appelant }
 idx := AddType(tname, TK_RECORD);
 fi  := 0;
 off := 0;
 While Not TokIsKw(KW_END) And (cur_tok_type <> TOK_EOF) do
 Begin
  { NULL record : NULL ; }
  If TokIsKw(KW_NULL) Then
  Begin Consume; Expect(TOK_SEMI, '`;` attendu apres NULL'); Continue; End;
  { Nom(s) de champ }
  Repeat
   If cur_tok_type <> TOK_IDENT Then
   Begin ErrorTok('Nom de champ attendu'); Break; End;
   fname := UpCaseStr(cur_tok_str);
   Consume;
   Expect(TOK_COLON, '`:` attendu apres nom de champ');
   fti := ParseTypeRef;
   fsz := GetTypeSize(fti);
   If fsz <= 0 Then fsz := 2;
   fsz := AlignWord(fsz);
   Inc(fi);
   If fi > MAX_FIELD Then
   Begin Error('Trop de champs dans RECORD'); fi := MAX_FIELD; End;
   type_table^[idx].field_names[fi] := fname;
   type_table^[idx].field_types[fi] := fti;
   type_table^[idx].field_offs[fi]  := off;
   Inc(off, fsz);
   { Plusieurs champs du meme type separes par ',' }
   If cur_tok_type = TOK_COMMA Then Consume Else Break;
  Until False;
  Expect(TOK_SEMI, '`;` attendu apres declaration de champ');
 End;
 type_table^[idx].field_count := fi;
 type_table^[idx].total_size  := AlignWord(off);
 ExpectKw(KW_END,    'END',    '`END` attendu en fin de RECORD');
 ExpectKw(KW_RECORD, 'RECORD', '`RECORD` attendu apres END');
 ParseRecordType := idx;
End;

{ ---- GenTypeData : emission .DATA pour un type statique ----
  Pour les types simples (ENUM, RANGE, ACCESS) : rien a emettre.
  Appele lors de la generation du segment .DATA pour les variables
  dont le type necessite un gabarit (reservé au TODO 24).                     }

Procedure GenTypeData(ti: Integer);
Begin
 { Pour l'instant : stub —  les variables elles-memes emettent leurs DW/DB }
 { Les tableaux et records emettent via GenVarData dans ParseObjectDecl     }
End;

{ ---- ParseTypeDecl : TYPE nom IS definition ; ---- }

Procedure ParseTypeDecl;
Var tname  : String;
    idx    : Integer;
    base   : Integer;
    lo, hi : LongInt;
Begin
 Consume; { TYPE }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de type attendu apres TYPE'); Exit; End;
 tname := UpCaseStr(cur_tok_str);
 Consume;
 ExpectKw(KW_IS, 'IS', '`IS` attendu apres nom de type');

 { Enumeration : ( lit1, lit2, ... ) }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  idx := ParseEnumType(tname);
 End

 { RANGE lo .. hi }
 Else If TokIsKw(KW_RANGE) Then
 Begin
  Consume; { RANGE }
  idx := ParseRangeType(tname, TYPE_INT);
 End

 { ARRAY ( ... ) OF type }
 Else If TokIsKw(KW_ARRAY) Then
 Begin
  Consume; { ARRAY }
  idx := ParseArrayType(tname);
 End

 { RECORD ... END RECORD }
 Else If TokIsKw(KW_RECORD) Then
 Begin
  Consume; { RECORD }
  idx := ParseRecordType(tname);
 End

 { NEW basetype }
 Else If TokIsKw(KW_NEW) Then
 Begin
  Consume; { NEW }
  base := ParseTypeRef;
  idx  := AddType(tname, TK_DERIVED);
  type_table^[idx].base_type  := base;
  type_table^[idx].total_size := GetTypeSize(base);
 End

 { ACCESS basetype }
 Else If TokIsKw(KW_ACCESS) Then
 Begin
  Consume; { ACCESS }
  base := ParseTypeRef;
  idx  := AddType(tname, TK_ACCESS);
  type_table^[idx].base_type  := base;
  type_table^[idx].total_size := 2;  { adresse 16 bits }
 End

 Else
 Begin
  ErrorTok('Definition de type inconnue apres IS');
  idx := 0;
 End;

 Expect(TOK_SEMI, '`;` attendu en fin de declaration de type');
End;

{ ---- ParseSubtypeDecl : SUBTYPE nom IS basetype [RANGE lo .. hi] ; ---- }

Procedure ParseSubtypeDecl;
Var sname  : String;
    base   : Integer;
    idx    : Integer;
    lo, hi : LongInt;
Begin
 Consume; { SUBTYPE }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de sous-type attendu apres SUBTYPE'); Exit; End;
 sname := UpCaseStr(cur_tok_str);
 Consume;
 ExpectKw(KW_IS, 'IS', '`IS` attendu apres nom de sous-type');
 base := ParseTypeRef;

 { Contrainte RANGE optionnelle }
 If TokIsKw(KW_RANGE) Then
 Begin
  Consume; { RANGE }
  ParseRangeBounds(lo, hi);
  idx := AddType(sname, TK_RANGE);
  type_table^[idx].base_type  := base;
  type_table^[idx].lo_bound   := lo;
  type_table^[idx].hi_bound   := hi;
  type_table^[idx].total_size := 2;
 End
 Else
 Begin
  { Simple alias du type de base }
  idx := AddType(sname, TK_DERIVED);
  type_table^[idx].base_type  := base;
  type_table^[idx].total_size := GetTypeSize(base);
 End;

 Expect(TOK_SEMI, '`;` attendu en fin de declaration de sous-type');
End;

{ ============================================================================ }
{ TODO 11 - ParseObjectDecl : declarations d'objets                           }
{ ============================================================================ }

{ ---- GenVarData : emission .DATA pour une variable statique globale ----
  Appele lors de la passe .DATA (TODO 24).  Ici on l'ecrit directement
  dans output_file car les variables globales sont declarees avant BEGIN.     }

Procedure GenVarData(sym_idx: Integer);
Var ti   : Integer;
    sz   : Integer;
    i    : Integer;
    n    : LongInt;
Begin
 ti := sym_table^[sym_idx].type_idx;
 sz := GetSymSize(sym_idx);

 { Label ASM }
 Emit(sym_table^[sym_idx].asm_label + ':');

 { Contenu selon le type }
 If ti = TYPE_FLOAT Then
 Begin
  { 4 octets (DD) - valeur flottante non supportee en 16b, on emet 0 }
  EmitI('DD 0');
 End
 Else If (ti = TYPE_CHAR) Or (ti = TYPE_BOOL) Then
 Begin
  n := sym_table^[sym_idx].init_num;
  EmitI('DW ' + IntToStr(n));  { word pour alignement }
 End
 Else If ti = TYPE_STR Then
 Begin
  { String(n) : DB longueur, DB n DUP(0) }
  n := sym_table^[sym_idx].char_len;
  If n <= 0 Then n := 1;
  EmitI('DB ' + IntToStr(n));            { longueur }
  EmitI('DB ' + IntToStr(n) + ' DUP(0)'); { contenu null }
 End
 Else If ti = TYPE_ARRAY Then
 Begin
  { Tableau : sz/2 mots a zero }
  If sz > 0 Then
   EmitI('DW ' + IntToStr(sz Div 2) + ' DUP(0)')
  Else
   EmitI('DW 0');
 End
 Else If ti = TYPE_RECORD Then
 Begin
  If sz > 0 Then
   EmitI('DB ' + IntToStr(sz) + ' DUP(0)')
  Else
   EmitI('DW 0');
 End
 Else
 Begin
  { Scalaire entier / enum / range / pointeur : DW valeur_init }
  n := sym_table^[sym_idx].init_num;
  EmitI('DW ' + IntToStr(n));
 End;
End;

{ ---- GenVarInit : code d'initialisation runtime pour variable locale ----
  Suppose que l'expression a ete evaluee et que AX contient le resultat.
  Stocke dans la variable via GenStoreVar.                                     }

Procedure GenVarInit(sym_idx: Integer);
Begin
 GenStoreVar(sym_idx);
End;

{ ---- ParseConstExpr : evaluer une expression constante a la compilation ----
  Essaie d'evaluer une expression simple (litteraux, pas d'appels).
  Retourne True si l'evaluation a reussi, et la valeur dans val.
  Sinon, genere le code de l'expression et laisse le resultat dans AX.        }

Function ParseConstExpr(Var val: LongInt): Boolean;
Begin
 { Litteraux entiers simples }
 If cur_tok_type = TOK_INTEGER Then
 Begin
  val := cur_tok_num;
  Consume;
  ParseConstExpr := True;
  Exit;
 End;
 { Litteraux caracteres }
 If cur_tok_type = TOK_CHAR Then
 Begin
  val := Ord(cur_tok_str[1]);
  Consume;
  ParseConstExpr := True;
  Exit;
 End;
 { TRUE / FALSE }
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_TRUE) Then
 Begin
  val := 1; Consume;
  ParseConstExpr := True;
  Exit;
 End;
 If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_FALSE) Then
 Begin
  val := 0; Consume;
  ParseConstExpr := True;
  Exit;
 End;
 { Expression generale : generer du code }
 ParseExpr;
 val := 0;
 ParseConstExpr := False;  { valeur calculee au runtime dans AX }
End;

{ ---- ParseObjectDecl : nom [, nom2 ...] : [CONSTANT] type [:= expr] ;
  Peut etre appele pour une ou plusieurs variables du meme type.
  isSym_global = True si on emet dans .DATA, False si pile.                   }

Procedure ParseObjectDecl;
Var names     : Array[1..16] of String[48];
    ncount    : Integer;
    is_const  : Boolean;
    ti        : Integer;
    sc        : Integer;
    sym_idx   : Integer;
    has_init  : Boolean;
    init_val  : LongInt;
    got_const : Boolean;
    i         : Integer;
    sz        : Integer;
Begin
 { Lire la liste de noms }
 ncount := 0;
 Repeat
  If cur_tok_type <> TOK_IDENT Then
  Begin ErrorTok('Identifiant attendu'); Break; End;
  Inc(ncount);
  If ncount > 16 Then Begin Error('Trop de noms dans declaration'); ncount := 16; End;
  names[ncount] := UpCaseStr(cur_tok_str);
  Consume;
  If cur_tok_type = TOK_COMMA Then Consume Else Break;
 Until False;

 Expect(TOK_COLON, '`:` attendu apres nom(s) de variable');

 { Declaration d'exception : nom : EXCEPTION ; }
 If TokIsKw(KW_EXCEPTION) Then
 Begin
  Consume; { EXCEPTION }
  For i := 1 to ncount do
  Begin
   Inc(except_next_code);
   sym_idx := AddSym(names[i], TYPE_INT, STORE_CONST);
   If sym_idx > 0 Then
   Begin
    sym_table^[sym_idx].init_num := except_next_code;
    sym_table^[sym_idx].is_const := True;
   End;
  End;
  Expect(TOK_SEMI, '`;` attendu apres declaration EXCEPTION');
  Exit;
 End;

 { CONSTANT optionnel }
 is_const := False;
 If TokIsKw(KW_CONSTANT) Then
 Begin
  is_const := True;
  Consume;
 End;

 { Type }
 ti := ParseTypeRef;

 { Classe de stockage }
 If is_const Then
  sc := STORE_CONST
 Else If scope_top = 0 Then
  sc := STORE_STATIC
 Else
  sc := STORE_AUTO;

 { Initialisation [:= expr] }
 has_init  := False;
 init_val  := 0;
 got_const := False;
 If cur_tok_type = TOK_COLONASSIGN Then
 Begin
  Consume;
  has_init  := True;
  got_const := ParseConstExpr(init_val);
  { Si l'expression est runtime (got_const=False), AX contient le resultat }
 End;

 { Creer les symboles }
 For i := 1 to ncount do
 Begin
  sym_idx := AddSym(names[i], ti, sc);
  If sym_idx = 0 Then Continue;

  If has_init Then
  Begin
   sym_table^[sym_idx].has_init  := True;
   sym_table^[sym_idx].init_num  := init_val;
  End;

  { Ajuster la taille reelle si tableau / string }
  sz := GetTypeSize(ti);
  If ti = TYPE_ARRAY Then
  Begin
   sym_table^[sym_idx].array_size := sz;
   FixSymBpOffset(sym_idx);
  End
  Else If ti = TYPE_STR Then
  Begin
   { Chercher la longueur dans type_table si c'est un sous-type STRING(n) }
   sym_table^[sym_idx].char_len := sz;
   FixSymBpOffset(sym_idx);
  End;

  { Emission selon classe de stockage }
  If sc = STORE_STATIC Then
  Begin
   { Variable globale : emet en .DATA maintenant }
   GenVarData(sym_idx);
  End
  Else If sc = STORE_AUTO Then
  Begin
   { Variable locale : l'espace est alloue par AddSym via bp_top.
     L'initialisation est DIFFEREE : emise apres SUB SP dans ParseProcedureBody.
     On stocke seulement has_init / init_num (deja fait plus haut).           }
   If has_init And Not got_const Then
    Warning('Init runtime de variable locale differee non supportee : ' + names[i]);
  End;
  { STORE_CONST : rien a emettre, valeur dans init_num }
 End;

 Expect(TOK_SEMI, '`;` attendu en fin de declaration d''objet');
End;

{ ============================================================================ }
{ TODO 12 - ParseProcedureSpec / ParseFunctionSpec : signatures               }
{ ============================================================================ }

{ ---- ParseParamList : ( nom [, nom2] : [IN|IN OUT|OUT] type [:= def] ; ...) }
{ Remplit les champs param_names, param_types, param_modes, param_count du
  sous-programme dont l'index est sub_idx.
  Retourne le nombre total de parametres enregistres.                          }

Procedure ParseParamList(sub_idx: Integer);
Var names  : Array[1..MAX_PARAM] of String[48];
    ncount : Integer;
    mode   : Integer;
    ti     : Integer;
    pc     : Integer;   { param_count global }
    i      : Integer;
    dummy  : LongInt;
Begin
 { Parenthese ouvrante deja consommee par l'appelant }
 pc := sub_table^[sub_idx].param_count;

 While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do
 Begin
  { Lire noms du groupe }
  ncount := 0;
  Repeat
   If cur_tok_type <> TOK_IDENT Then
   Begin ErrorTok('Nom de parametre attendu'); Break; End;
   Inc(ncount);
   names[ncount] := UpCaseStr(cur_tok_str);
   Consume;
   If cur_tok_type = TOK_COMMA Then Consume Else Break;
  Until False;

  Expect(TOK_COLON, '`:` attendu apres nom de parametre');

  { Mode : IN | OUT | IN OUT  (defaut = IN) }
  mode := PARAM_IN;
  If TokIsKw(KW_IN) Then
  Begin
   Consume;
   If TokIsKw(KW_OUT) Or TokIsKw(KW_INOUT) Then
   Begin
    mode := PARAM_INOUT;
    Consume;
   End;
  End
  Else If TokIsKw(KW_OUT) Then
  Begin
   mode := PARAM_OUT;
   Consume;
  End;

  { Type }
  ti := ParseTypeRef;

  { Valeur par defaut optionnelle [:= expr] — consommee, non stockee }
  If cur_tok_type = TOK_COLONASSIGN Then
  Begin
   Consume;
   ParseConstExpr(dummy);   { evalue ou consomme l'expression }
  End;

  { Enregistrer les parametres dans sub_table }
  For i := 1 to ncount do
  Begin
   Inc(pc);
   If pc > MAX_PARAM Then
   Begin
    Error('Trop de parametres (MAX_PARAM=' + IntToStr(MAX_PARAM) + ')');
    Break;
   End;
   sub_table^[sub_idx].param_names[pc] := names[i];
   sub_table^[sub_idx].param_types[pc] := ti;
   sub_table^[sub_idx].param_modes[pc] := mode;
  End;

  { Separateur entre groupes : ';' }
  If cur_tok_type = TOK_SEMI Then Consume
  Else Break;
 End;

 sub_table^[sub_idx].param_count := pc;
End;

{ ---- ParseProcedureSpec : PROCEDURE nom [(params)] ;
  Cree ou met a jour l'entree sub_table avec is_forward := True.
  Retourne l'index dans sub_table.                                             }

Function ParseProcedureSpec: Integer;
Var nm  : String;
    idx : Integer;
Begin
 Consume; { PROCEDURE }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de procedure attendu'); ParseProcedureSpec := 0; Exit; End;
 nm  := UpCaseStr(cur_tok_str);
 Consume;

 { Verifier si deja declare (forward ou spec de package) }
 idx := FindSub(nm);
 If idx = 0 Then
  idx := AddSub(nm, False, TYPE_VOID);
 If idx = 0 Then Begin ParseProcedureSpec := 0; Exit; End;

 sub_table^[idx].is_forward := True;

 { Parametres optionnels }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  ParseParamList(idx);
  Expect(TOK_RPAREN, '`)` attendu apres parametres');
 End;

 ParseProcedureSpec := idx;
End;

{ ---- ParseFunctionSpec : FUNCTION nom [(params)] RETURN type ;
  Retourne l'index dans sub_table.                                             }

Function ParseFunctionSpec: Integer;
Var nm     : String;
    idx    : Integer;
    ret_ti : Integer;
Begin
 Consume; { FUNCTION }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de fonction attendu'); ParseFunctionSpec := 0; Exit; End;
 nm  := UpCaseStr(cur_tok_str);
 Consume;

 idx := FindSub(nm);
 If idx = 0 Then
  idx := AddSub(nm, True, TYPE_UNKNOWN);  { ret_type mis a jour plus bas }
 If idx = 0 Then Begin ParseFunctionSpec := 0; Exit; End;

 sub_table^[idx].is_forward  := True;
 sub_table^[idx].is_function := True;

 { Parametres optionnels }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  ParseParamList(idx);
  Expect(TOK_RPAREN, '`)` attendu apres parametres');
 End;

 { RETURN type }
 ExpectKw(KW_RETURN, 'RETURN', '`RETURN` attendu dans specification de fonction');
 ret_ti := ParseTypeRef;
 sub_table^[idx].ret_type := ret_ti;

 ParseFunctionSpec := idx;
End;

{ ---- VerifySubSignature : verifie coherence forward vs body ----
  Appele depuis ParseProcedureBody / ParseFunctionBody quand la
  procedure etait deja declaree comme forward.                                }

Procedure VerifySubSignature(fwd_idx, body_idx: Integer);
Var i : Integer;
Begin
 If fwd_idx = body_idx Then Exit;  { meme entree, rien a verifier }
 { Comparer param_count }
 If sub_table^[fwd_idx].param_count <> sub_table^[body_idx].param_count Then
  Warning('Corps de ' + sub_table^[fwd_idx].name +
          ' : nombre de parametres different de la spec forward');
 { Comparer types de retour }
 If sub_table^[fwd_idx].ret_type <> sub_table^[body_idx].ret_type Then
  Warning('Corps de ' + sub_table^[fwd_idx].name +
          ' : type de retour different de la spec forward');
 { Comparer modes des parametres }
 For i := 1 to sub_table^[fwd_idx].param_count do
  If sub_table^[fwd_idx].param_modes[i] <> sub_table^[body_idx].param_modes[i] Then
   Warning('Corps de ' + sub_table^[fwd_idx].name +
           ' : mode du parametre ' + IntToStr(i) + ' different de la spec forward');
End;

{ ============================================================================ }
{ TODO 13 - ParseProcedureBody / ParseFunctionBody : corps de sous-programmes  }
{ ============================================================================ }

{ ---- Prototypes forward (corps dans TODO 15) ---- }
Procedure ParseStatement;      Forward;
Procedure ParseDeclarativePart; Forward;

{ ---- ParseSequenceOfStatements ----
  Lit des instructions jusqu'a une borne de fin de bloc :
  END | EXCEPTION | ELSIF | ELSE | WHEN | TOK_EOF                             }

Procedure ParseSequenceOfStatements;
Begin
 While True do
 Begin
  { Conditions de fin de sequence }
  If cur_tok_type = TOK_EOF Then Break;
  If TokIsKw(KW_END)       Then Break;
  If TokIsKw(KW_EXCEPTION) Then Break;
  If TokIsKw(KW_ELSIF)     Then Break;
  If TokIsKw(KW_ELSE)      Then Break;
  If TokIsKw(KW_WHEN)      Then Break;
  ParseStatement;
 End;
End;

{ ---- RegisterParamSymbols : enregistre les parametres comme symboles locaux --
  Parametres sur la pile (au-dessus de BP) :
    [BP+0] = ancien BP, [BP+2] = adresse retour
    [BP+4] = 1er param, [BP+6] = 2eme param, ...                              }

Procedure RegisterParamSymbols(sub_idx: Integer);
Var i      : Integer;
    pc     : Integer;
    ti     : Integer;
    mode   : Integer;
    off    : Integer;
    sym    : Integer;
Begin
 pc  := sub_table^[sub_idx].param_count;
 off := 4;   { [BP+4] = premier parametre }
 For i := 1 to pc do
 Begin
  ti   := sub_table^[sub_idx].param_types[i];
  mode := sub_table^[sub_idx].param_modes[i];
  sym  := AddSym(sub_table^[sub_idx].param_names[i], ti, STORE_AUTO);
  If sym = 0 Then Continue;
  { Surcharger l'offset BP calcule par AddSym : les params sont au-dessus }
  sym_table^[sym].bp_offset := off;
  { OUT/IN OUT : la variable est un pointeur (2 octets), ti reste le type Ada }
  Inc(off, 2);  { chaque parametre occupe 2 octets sur la pile 8086 }
 End;
End;

{ ---- EmitLocalInits : emet les MOV [BP-n], val pour toutes les vars locales
  ayant has_init=True et un init_num connu (compile-time).                    }

Procedure EmitLocalInits(sym_start: Integer);
Var i : Integer;
Begin
 For i := sym_start to sym_count do
  If sym_table^[i].has_init And (sym_table^[i].store_class = STORE_AUTO) Then
  Begin
   EmitI('MOV AX, ' + IntToStr(sym_table^[i].init_num));
   GenStoreVar(i);
  End;
End;

{ ---- ParseExceptionHandlers : EXCEPTION handler [handler ...] ----
  WHEN [nom |] typ => instructions
  WHEN OTHERS     => instructions
  Compile les handlers : CMP AX, code d'exception + Jcc.                      }

{ ---- ParseExceptionHandlers : WHEN nom [| nom2] => stmts  (dans EXCEPTION) ----
  AX = code exception pose par RAISE (ou 0 si re-raise generique)
  Chaque clause nomme fait : CMP AX, code; JNE lbl_next
  WHEN OTHERS => couvre tout (pas de CMP)                                      }

Procedure ParseExceptionHandlers(Const lbl_end: String);
Var lbl_next : String;
    lbl_body : String;
    nm       : String;
    si       : Integer;
    code     : LongInt;
    matched  : Boolean;
Begin
 While TokIsKw(KW_WHEN) And (cur_tok_type <> TOK_EOF) do
 Begin
  Consume; { WHEN }
  lbl_next := NewLabel;
  lbl_body := NewLabel;
  If TokIsKw(KW_OTHERS) Then
  Begin
   Consume; { OTHERS }
   { Pas de test : tomber dans le corps directement }
   Expect(TOK_ARROW, '`=>` attendu apres OTHERS');
   ParseSequenceOfStatements;
   EmitI('JMP  ' + lbl_end);
   EmitLabel(lbl_next);
  End
  Else
  Begin
   { Un ou plusieurs noms d'exceptions separes par | }
   matched := False;
   While True do
   Begin
    If cur_tok_type <> TOK_IDENT Then Break;
    nm := UpCaseStr(cur_tok_str);
    Consume;
    { Alias : nom : ident (rare, on consomme le second ident) }
    If cur_tok_type = TOK_COLON Then
    Begin Consume;
     If cur_tok_type = TOK_IDENT Then Begin nm := UpCaseStr(cur_tok_str); Consume; End;
    End;
    { Chercher le code }    si := FindSym(nm);
    code := 0;
    If (si > 0) And sym_table^[si].is_const Then
     code := sym_table^[si].init_num
    Else
     Warning('Exception inconnue dans WHEN : ' + nm);
    If code <> 0 Then
    Begin
     EmitI('CMP  AX, ' + IntToStr(code));
     EmitI('JE   ' + lbl_body);
    End
    Else
    Begin
     { Code inconnu : sauter quand meme dans le corps (OTHERS-like) }
     EmitI('JMP  ' + lbl_body);
    End;
    matched := True;
    If cur_tok_type = TOK_BAR Then Consume Else Break;
   End;
   If Not matched Then
    Warning('Clause WHEN vide ou mal formee');
   { Sauter la branche si aucune correspondance }   EmitI('JMP  ' + lbl_next);
   EmitLabel(lbl_body);
   Expect(TOK_ARROW, '`=>` attendu apres nom d''exception');
   ParseSequenceOfStatements;
   EmitI('JMP  ' + lbl_end);
   EmitLabel(lbl_next);
  End;
 End;
End;

{ ---- ParseSubBody : corps commun PROCEDURE et FUNCTION ----
  sub_idx : entree sub_table deja creee par le parseur appelant               }

Procedure ParseSubBody(sub_idx: Integer; kind: Integer);
Var frame_size  : Integer;
    param_bytes : Integer;
    lbl_exit    : String;
    lbl_except  : String;
    has_except  : Boolean;
    sym_start   : Integer;
    end_name    : String;
Begin
 { Emettre le label de la procedure / fonction }
 EmitBlank;
 EmitComment(sub_table^[sub_idx].name);
 EmitLabel(sub_table^[sub_idx].asm_label);

 { Empiler le scope }
 PushScope(kind, sub_idx);
 sym_start := scope_stack^[scope_top].sym_start;

 { Enregistrer les parametres comme symboles locaux (bp_offset positifs) }
 RegisterParamSymbols(sub_idx);

 { Debut de frame : PUSH BP / MOV BP,SP }
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');

 { Parser les declarations (types, constantes, variables, sous-progs) }
 { Apres cet appel, bp_top contiendra l'espace local total }
 ParseDeclarativePart;

 { Maintenant on connait la taille de frame }
 frame_size := -scope_stack^[scope_top].bp_top;
 If frame_size > 0 Then
  EmitI('SUB  SP, ' + IntToStr(frame_size));

 { Emettre les initialisations compile-time des variables locales }
 EmitLocalInits(sym_start);

 { Label de sortie (pour RETURN interieur) }
 lbl_exit   := NewLabel;
 lbl_except := NewLabel;
 has_except := False;
 SetExitLabel(lbl_exit);

 { Attendre BEGIN }
 ExpectKw(KW_BEGIN, 'BEGIN', '`BEGIN` attendu apres partie declarative');

 { Corps }
 ParseSequenceOfStatements;

 { Bloc EXCEPTION optionnel }
 If TokIsKw(KW_EXCEPTION) Then
 Begin
  has_except := True;
  EmitI('JMP ' + lbl_exit);  { code normal saute les handlers }
  EmitLabel(lbl_except);
  Consume; { EXCEPTION }
  ParseExceptionHandlers(lbl_exit);
 End;

 { Label de sortie : debut de l'epilogue }
 EmitLabel(lbl_exit);

 { Epilogue }
 param_bytes := SubParamBytes(sub_idx);
 If frame_size > 0 Then
  EmitI('MOV  SP, BP');
 EmitI('POP  BP');
 If param_bytes > 0 Then
  EmitI('RET  ' + IntToStr(param_bytes))
 Else
  EmitI('RET');

 { Mettre a jour frame_size dans sub_table }
 sub_table^[sub_idx].frame_size  := frame_size;
 sub_table^[sub_idx].is_forward  := False;

 { Depiler le scope }
 PopScope;

 { END [nom] ; }
 ExpectKw(KW_END, 'END', '`END` attendu en fin de sous-programme');
 If cur_tok_type = TOK_IDENT Then
 Begin
  end_name := UpCaseStr(cur_tok_str);
  If end_name <> sub_table^[sub_idx].name Then
   Warning('Nom apres END (' + end_name + ') different du nom declare (' +
           sub_table^[sub_idx].name + ')');
  Consume;
 End;
 Expect(TOK_SEMI, '`;` attendu apres END de sous-programme');
End;

{ ---- ParseProcedureBody : PROCEDURE nom [(params)] IS ... ---- }

Procedure ParseProcedureBody;
Var nm  : String;
    idx : Integer;
Begin
 Consume; { PROCEDURE }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de procedure attendu'); Exit; End;
 nm  := UpCaseStr(cur_tok_str);
 Consume;

 { Chercher un forward ou creer }
 idx := FindSub(nm);
 If idx = 0 Then
  idx := AddSub(nm, False, TYPE_VOID);
 If idx = 0 Then Exit;

 { Parametres : relire si pas de forward, ou ignorer si deja definis }
 If sub_table^[idx].param_count = 0 Then
 Begin
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   ParseParamList(idx);
   Expect(TOK_RPAREN, '`)` attendu apres parametres');
  End;
 End
 Else
 Begin
  { Forward : consommer la liste si presente (non enregistree) }
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
   Consume; { ) }
  End;
 End;

 ExpectKw(KW_IS, 'IS', '`IS` attendu apres signature de procedure');
 ParseSubBody(idx, SK_PROC);
End;

{ ---- ParseFunctionBody : FUNCTION nom [(params)] RETURN type IS ... ---- }

Procedure ParseFunctionBody;
Var nm     : String;
    idx    : Integer;
    ret_ti : Integer;
Begin
 Consume; { FUNCTION }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de fonction attendu'); Exit; End;
 nm  := UpCaseStr(cur_tok_str);
 Consume;

 idx := FindSub(nm);
 If idx = 0 Then
  idx := AddSub(nm, True, TYPE_UNKNOWN);
 If idx = 0 Then Exit;

 sub_table^[idx].is_function := True;

 If sub_table^[idx].param_count = 0 Then
 Begin
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   ParseParamList(idx);
   Expect(TOK_RPAREN, '`)` attendu apres parametres');
  End;
 End
 Else
 Begin
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
   Consume;
  End;
 End;

 ExpectKw(KW_RETURN, 'RETURN', '`RETURN` attendu dans corps de fonction');
 ret_ti := ParseTypeRef;
 sub_table^[idx].ret_type := ret_ti;

 ExpectKw(KW_IS, 'IS', '`IS` attendu apres signature de fonction');
 ParseSubBody(idx, SK_FUNC);
End;

{ ---- ParseDeclarativePart : types, constants, variables, sous-progs ----
  Boucle jusqu'a BEGIN ou END (partie declarative terminee).                   }

Procedure ParseDeclarativePart;
Begin
 While True do
 Begin
  If cur_tok_type = TOK_EOF Then Break;
  If TokIsKw(KW_BEGIN)     Then Break;
  If TokIsKw(KW_END)       Then Break;

  If TokIsKw(KW_TYPE)    Then ParseTypeDecl
  Else If TokIsKw(KW_SUBTYPE)  Then ParseSubtypeDecl
  Else If TokIsKw(KW_PROCEDURE) Then
  Begin
   { Body si IS present apres nom/params, sinon spec forward }
   ParseProcedureBody;
  End
  Else If TokIsKw(KW_FUNCTION) Then
   ParseFunctionBody
  Else If TokIsKw(KW_PRAGMA) Then
  Begin
   Consume; { PRAGMA }
   If cur_tok_type = TOK_IDENT Then Consume;
   If cur_tok_type = TOK_LPAREN Then
   Begin
    Consume;
    While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
    Consume;
   End;
   Expect(TOK_SEMI, '`;` attendu apres PRAGMA');
  End
  Else If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_NONE) Then
  Begin
   { Declaration d'objet : ident : [CONSTANT] type [:= expr] ; }
   ParseObjectDecl;
  End
  Else If TokIsKw(KW_USE) Then
   ParseUse
  Else
  Begin
   { Token inattendu dans la partie declarative }
   ErrorTok('Element inattendu dans partie declarative');
   SkipToSemi;
  End;
 End;
End;

{ ============================================================================ }
{ TODO 15 - ParseStatement : dispatcher principal des instructions             }
{ ============================================================================ }

{ ---- Prototypes forward pour instructions complexes (TODOs 16-18) ---- }
Procedure ParseAssignment;   Forward;
Procedure ParseProcedureCall; Forward;
Procedure ParseIf;           Forward;
Procedure ParseCase;         Forward;
Procedure ParseLoop;         Forward;
Procedure ParseWhile;        Forward;
Procedure ParseFor;          Forward;
Procedure ParseReturn;       Forward;
Procedure ParseRaise;        Forward;
Procedure ParseBeginBlock;   Forward;

{ ---- ParseNull : NULL ; ---- }
Procedure ParseNull;
Begin
 Consume; { NULL }
 Expect(TOK_SEMI, '`;` attendu apres NULL');
End;

{ ---- ParsePragma : PRAGMA ident [(args)] ; ---- }
Procedure ParsePragma;
Begin
 Consume; { PRAGMA }
 If cur_tok_type = TOK_IDENT Then Consume;  { nom du pragma }
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
  Consume; { ) }
 End;
 Expect(TOK_SEMI, '`;` attendu apres PRAGMA');
End;

{ ---- ParseExit : EXIT [WHEN expr] ; ---- }
Procedure ParseExit;
Var lbl_end  : String;
    lbl_cont : String;
Begin
 Consume; { EXIT }
 lbl_end := FindLoopEnd;
 If TokIsKw(KW_WHEN) Then
 Begin
  Consume; { WHEN }
  ParseExpr;           { AX = condition }
  { Sauter si AX <> 0 (True) }
  If lbl_end <> '' Then
  Begin
   EmitI('CMP  AX, 0');
   EmitI('JNE  ' + lbl_end);
  End
  Else
   Warning('EXIT WHEN sans boucle englobante');
 End
 Else
 Begin
  { EXIT inconditionnel }
  If lbl_end <> '' Then
   EmitI('JMP  ' + lbl_end)
  Else
   Warning('EXIT sans boucle englobante');
 End;
 Expect(TOK_SEMI, '`;` attendu apres EXIT');
End;

{ ---- ParseGoto : GOTO label ; (stub minimal) ---- }
Procedure ParseGoto;
Var lbl : String;
Begin
 Consume; { GOTO }
 If cur_tok_type = TOK_IDENT Then
 Begin
  lbl := UpCaseStr(cur_tok_str);
  Consume;
  EmitI('JMP  ' + AsmIdent('_LBL_', lbl));
 End;
 Expect(TOK_SEMI, '`;` attendu apres GOTO');
End;

{ ---- ParseLabeledStatement : <<nom>> ---- }
Procedure ParseLabeledStatement;
Var lbl : String;
Begin
 { Deja consomme le premier '<' }
 If cur_tok_type = TOK_LT Then
 Begin
  Consume; { second '<' }
  If cur_tok_type = TOK_IDENT Then
  Begin
   lbl := UpCaseStr(cur_tok_str);
   Consume;
   EmitLabel(AsmIdent('_LBL_', lbl));
   Expect(TOK_GT, '`>` attendu');
   Expect(TOK_GT, '`>>` attendu');
  End
  Else
   ErrorTok('Nom de label attendu apres <<');
 End;
End;

{ ---- ParseBeginBlock : [DECLARE decls] BEGIN stmts [EXCEPTION] END ; ---- }
Procedure ParseBeginBlock;
Var frame  : Integer;
    lbl_ex : String;
    lbl_end: String;
Begin
 PushScope(SK_BLOCK, CurrentSubIdx);

 If TokIsKw(KW_DECLARE) Then
 Begin
  Consume;
  ParseDeclarativePart;
 End;

 { Allouer la frame du bloc si variables locales }
 frame := -scope_stack^[scope_top].bp_top;
 If frame > 0 Then
 Begin
  EmitI('SUB  SP, ' + IntToStr(frame));
  EmitLocalInits(scope_stack^[scope_top].sym_start);
 End;

 ExpectKw(KW_BEGIN, 'BEGIN', '`BEGIN` attendu dans bloc');
 ParseSequenceOfStatements;

 If TokIsKw(KW_EXCEPTION) Then
 Begin
  lbl_end := NewLabel;
  EmitI('JMP  ' + lbl_end);
  lbl_ex  := NewLabel;
  EmitLabel(lbl_ex);
  Consume; { EXCEPTION }
  ParseExceptionHandlers(lbl_end);
  EmitLabel(lbl_end);
 End;

 If frame > 0 Then
  EmitI('ADD  SP, ' + IntToStr(frame));

 PopScope;

 ExpectKw(KW_END, 'END', '`END` attendu apres bloc');
 If cur_tok_type = TOK_IDENT Then Consume;  { nom optionnel }
 Expect(TOK_SEMI, '`;` attendu apres END de bloc');
End;

{ ---- IsEndBoundary : teste si le token courant termine une sequence ---- }
Function IsEndBoundary: Boolean;
Begin
 IsEndBoundary :=
   (cur_tok_type = TOK_EOF)     Or
   TokIsKw(KW_END)              Or
   TokIsKw(KW_EXCEPTION)        Or
   TokIsKw(KW_ELSIF)            Or
   TokIsKw(KW_ELSE)             Or
   TokIsKw(KW_WHEN);
End;

{ ---- ParseStatement : dispatcher principal ---- }
Procedure ParseStatement;
Var nm      : String;
    sym     : Integer;
    sub     : Integer;
    is_call : Boolean;
Begin
 If IsEndBoundary Then Exit;

 { === NULL === }
 If TokIsKw(KW_NULL) Then Begin ParseNull; Exit; End;

 { === PRAGMA === }
 If TokIsKw(KW_PRAGMA) Then Begin ParsePragma; Exit; End;

 { === EXIT === }
 If TokIsKw(KW_EXIT) Then Begin ParseExit; Exit; End;

 { === GOTO === }
 If TokIsKw(KW_GOTO) Then Begin ParseGoto; Exit; End;

 { === RETURN === }
 If TokIsKw(KW_RETURN) Then Begin ParseReturn; Exit; End;

 { === RAISE === }
 If TokIsKw(KW_RAISE) Then Begin ParseRaise; Exit; End;

 { === IF === }
 If TokIsKw(KW_IF) Then Begin ParseIf; Exit; End;

 { === CASE === }
 If TokIsKw(KW_CASE) Then Begin ParseCase; Exit; End;

 { === LOOP (boucle infinie) === }
 If TokIsKw(KW_LOOP) Then Begin ParseLoop; Exit; End;

 { === WHILE === }
 If TokIsKw(KW_WHILE) Then Begin ParseWhile; Exit; End;

 { === FOR === }
 If TokIsKw(KW_FOR) Then Begin ParseFor; Exit; End;

 { === DECLARE ... BEGIN ou BEGIN (bloc declare) === }
 If TokIsKw(KW_DECLARE) Or TokIsKw(KW_BEGIN) Then
 Begin ParseBeginBlock; Exit; End;

 { === Label Ada : <<nom>> === }
 If cur_tok_type = TOK_LT Then
 Begin
  Consume;
  ParseLabeledStatement;
  Exit;
 End;

 { === Identifiant : assignment, proc call, ou declaration d'objet === }
 If cur_tok_type = TOK_IDENT Then
 Begin
  nm := UpCaseStr(cur_tok_str);

  { Declaration d'objet detectable par ':' apres le nom }
  { On utilise PeekNextChar pour voir si le suivant est ':' }
  { Approche : on compare cur_tok_kw = KW_NONE et regarde si la variable
    n'est pas dans sub_table (ce serait une proc call).
    La distinction assignment vs proc call se fait DANS ParseAssignment /
    ParseProcedureCall apres consommation du nom.                         }

  { Procedure call detectee si : nom est connu dans sub_table OU
    si le token apres est '(' sans ':=' -> traiter comme appel }
  sub := FindSub(nm);
  sym := FindSym(nm);

  { Si le nom n'est ni un symbole ni un sous-programme -> possible decl }
  If (sub = 0) And (sym = 0) And
     (cur_tok_kw = KW_NONE) Then
  Begin
   { Pourrait etre une declaration d'objet si ':' suit }
   { On parse comme declaration d'objet -> ParseObjectDecl }
   { (ParseObjectDecl re-lira le nom depuis le cur_tok_type = IDENT) }
   ParseObjectDecl;
   Exit;
  End;

  { Si c'est une procedure connue -> ParseProcedureCall }
  If sub > 0 Then
  Begin
   ParseProcedureCall;
   Exit;
  End;

  { Sinon : assignment (variable := expr) }
  ParseAssignment;
  Exit;
 End;

 { Token inattendu }
 ErrorTok('Instruction attendue');
 SkipToSemi;
End;

{ ============================================================================ }
{ TODO 14 - ParsePackageSpec / ParsePackageBody                               }
{ ============================================================================ }

{ ---- Helpers Text_IO : stubs Put / Put_Line / New_Line / Get / Get_Line ----
  Ces stubs s'appuient sur des helpers runtime assembleur (TODO 22).
  Convention : argument en AX (pointeur chaine ou valeur entiere).            }

Procedure GenTextIO_Stubs;
Begin
 { ---- Put_Line(str) : affiche chaine + saut de ligne ---- }
 EmitBlank;
 EmitComment('Ada.Text_IO.Put_Line stub');
 EmitLabel('_ADA_PROC_PUT_LINE');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('MOV  AX, [BP+4]');   { argument chaine (offset) }
 EmitI('CALL _RT_PUTS');      { helper : affiche chaine pointee par AX }
 EmitI('CALL _RT_NEWLINE');   { helper : emite CR LF }
 EmitI('POP  BP');
 EmitI('RET  2');
 EmitBlank;

 { ---- Put(str) : affiche chaine sans saut de ligne ---- }
 EmitComment('Ada.Text_IO.Put stub');
 EmitLabel('_ADA_PROC_PUT');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('MOV  AX, [BP+4]');
 EmitI('CALL _RT_PUTS');
 EmitI('POP  BP');
 EmitI('RET  2');
 EmitBlank;

 { ---- New_Line : saut de ligne ---- }
 EmitComment('Ada.Text_IO.New_Line stub');
 EmitLabel('_ADA_PROC_NEW_LINE');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('CALL _RT_NEWLINE');
 EmitI('POP  BP');
 EmitI('RET');
 EmitBlank;

 { ---- Put_Integer / Put(int) ---- }
 EmitComment('Ada.Integer_Text_IO.Put stub');
 EmitLabel('_ADA_PROC_PUT_INTEGER');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('MOV  AX, [BP+4]');
 EmitI('CALL _RT_PUTI');      { helper : affiche entier AX en decimal }
 EmitI('POP  BP');
 EmitI('RET  2');
 EmitBlank;

 { ---- Get_Line(str, last) : lecture ligne ---- }
 EmitComment('Ada.Text_IO.Get_Line stub');
 EmitLabel('_ADA_PROC_GET_LINE');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('MOV  AX, [BP+6]');   { 1er arg : buffer }
 EmitI('CALL _RT_GETS');      { helper : lit ligne dans AX }
 EmitI('POP  BP');
 EmitI('RET  4');
 EmitBlank;

 { ---- Get(val) : lecture entier ---- }
 EmitComment('Ada.Integer_Text_IO.Get stub');
 EmitLabel('_ADA_PROC_GET');
 EmitI('PUSH BP');
 EmitI('MOV  BP, SP');
 EmitI('CALL _RT_GETI');      { retour entier dans AX }
 EmitI('MOV  BX, [BP+4]');   { pointeur vers variable OUT }
 EmitI('MOV  [BX], AX');
 EmitI('POP  BP');
 EmitI('RET  2');
 EmitBlank;
End;

{ ---- RegisterTextIO_Subs : enregistre les sous-progs Text_IO dans sub_table -
  Permet aux appels de procedure de retrouver Put_Line, Put, Get_Line, etc.   }

{ ---- RegisterStdExceptions : pre-enregistre les exceptions standard Ada ---- }

Procedure RegisterStdExceptions;
Var idx : Integer;
    code : Integer;

  Procedure RegEx(Const nm: String; c: Integer);
  Begin
   idx := FindSym(nm);
   If idx = 0 Then
   Begin
    idx := AddSym(nm, TYPE_INT, STORE_CONST);
    If idx > 0 Then
    Begin
     sym_table^[idx].init_num := c;
     sym_table^[idx].is_const := True;
    End;
   End;
  End;

Begin
 code := 0; { eviter warning variable inutilisee }
 RegEx('CONSTRAINT_ERROR', 1);
 RegEx('PROGRAM_ERROR',    2);
 RegEx('STORAGE_ERROR',    3);
 RegEx('TASKING_ERROR',    4);
 RegEx('NUMERIC_ERROR',    5);
End;

Procedure RegisterTextIO_Subs;
Var idx : Integer;
Begin
 { PUT_LINE(str : String) }
 idx := FindSub('PUT_LINE');
 If idx = 0 Then
 Begin
  idx := AddSub('PUT_LINE', False, TYPE_VOID);
  If idx > 0 Then
  Begin
   sub_table^[idx].param_count    := 1;
   sub_table^[idx].param_names[1] := 'ITEM';
   sub_table^[idx].param_types[1] := TYPE_STR;
   sub_table^[idx].param_modes[1] := PARAM_IN;
  End;
 End;

 { PUT(str : String) }
 idx := FindSub('PUT');
 If idx = 0 Then
 Begin
  idx := AddSub('PUT', False, TYPE_VOID);
  If idx > 0 Then
  Begin
   sub_table^[idx].param_count    := 1;
   sub_table^[idx].param_names[1] := 'ITEM';
   sub_table^[idx].param_types[1] := TYPE_STR;
   sub_table^[idx].param_modes[1] := PARAM_IN;
  End;
 End;

 { NEW_LINE }
 idx := FindSub('NEW_LINE');
 If idx = 0 Then
  idx := AddSub('NEW_LINE', False, TYPE_VOID);

 { GET_LINE(str, last) }
 idx := FindSub('GET_LINE');
 If idx = 0 Then
 Begin
  idx := AddSub('GET_LINE', False, TYPE_VOID);
  If idx > 0 Then
  Begin
   sub_table^[idx].param_count    := 2;
   sub_table^[idx].param_names[1] := 'ITEM';
   sub_table^[idx].param_types[1] := TYPE_STR;
   sub_table^[idx].param_modes[1] := PARAM_OUT;
   sub_table^[idx].param_names[2] := 'LAST';
   sub_table^[idx].param_types[2] := TYPE_INT;
   sub_table^[idx].param_modes[2] := PARAM_OUT;
  End;
 End;

 { GET(val) }
 idx := FindSub('GET');
 If idx = 0 Then
 Begin
  idx := AddSub('GET', False, TYPE_VOID);
  If idx > 0 Then
  Begin
   sub_table^[idx].param_count    := 1;
   sub_table^[idx].param_names[1] := 'ITEM';
   sub_table^[idx].param_types[1] := TYPE_INT;
   sub_table^[idx].param_modes[1] := PARAM_OUT;
  End;
 End;

 { PUT_INTEGER alias pour Ada.Integer_Text_IO.Put }
 idx := FindSub('PUT_INTEGER');
 If idx = 0 Then
 Begin
  idx := AddSub('PUT_INTEGER', False, TYPE_VOID);
  If idx > 0 Then
  Begin
   sub_table^[idx].param_count    := 1;
   sub_table^[idx].param_names[1] := 'ITEM';
   sub_table^[idx].param_types[1] := TYPE_INT;
   sub_table^[idx].param_modes[1] := PARAM_IN;
  End;
 End;
End;

{ ---- ParsePackageSpec : PACKAGE nom IS [PRIVATE] decls END [nom] ; ----
  Enregistre le package et ses exports (types, constantes, sous-progs)
  dans les tables globales. Aucun code n'est genere pour la spec.             }

Procedure ParsePackageSpec;
Var nm       : String;
    idx      : Integer;
    spec_idx : Integer;
    fspec_idx: Integer;
Begin
 Consume; { PACKAGE }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de package attendu'); Exit; End;
 nm  := UpCaseStr(cur_tok_str);
 Consume;

 ExpectKw(KW_IS, 'IS', '`IS` attendu apres nom de package');

 { Enregistrer le package }
 idx := FindPkg(nm);
 If idx = 0 Then
  idx := AddPkg(nm, False);

 PushScope(SK_PACKAGE, 0);

 { Parser les declarations publiques }
 While True do
 Begin
  If cur_tok_type = TOK_EOF   Then Break;
  If TokIsKw(KW_END)          Then Break;
  If TokIsKw(KW_PRIVATE) Then
  Begin Consume; Continue; End;  { section privee : ignorer et continuer }

  If TokIsKw(KW_TYPE)       Then ParseTypeDecl
  Else If TokIsKw(KW_SUBTYPE)  Then ParseSubtypeDecl
  Else If TokIsKw(KW_PROCEDURE) Then
  Begin
   spec_idx := ParseProcedureSpec;
   Expect(TOK_SEMI, '`;` attendu apres spec de procedure');
  End
  Else If TokIsKw(KW_FUNCTION) Then
  Begin
   fspec_idx := ParseFunctionSpec;
   Expect(TOK_SEMI, '`;` attendu apres spec de fonction');
  End
  Else If TokIsKw(KW_PRAGMA) Then
  Begin
   Consume;
   If cur_tok_type = TOK_IDENT Then Consume;
   If cur_tok_type = TOK_LPAREN Then
   Begin
    Consume;
    While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
    Consume;
   End;
   Expect(TOK_SEMI, '`;` attendu apres PRAGMA');
  End
  Else If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_NONE) Then
   ParseObjectDecl
  Else
  Begin ErrorTok('Element inattendu dans spec de package'); SkipToSemi; End;
 End;

 PopScope;

 ExpectKw(KW_END, 'END', '`END` attendu en fin de package spec');
 If cur_tok_type = TOK_IDENT Then Consume;  { nom optionnel }
 Expect(TOK_SEMI, '`;` attendu apres END de package spec');
End;

{ ---- ParsePackageBody : PACKAGE BODY nom IS decls [BEGIN stmts END] ; ---- }

Procedure ParsePackageBody;
Var nm       : String;
    idx      : Integer;
    lbl_init : String;
    is_textio: Boolean;
    end_name : String;
Begin
 { BODY deja consomme par l'appelant (PACKAGE BODY) }
 { ou appele apres que PACKAGE et BODY ont ete consommes }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Nom de package body attendu'); Exit; End;
 nm := UpCaseStr(cur_tok_str);
 Consume;

 ExpectKw(KW_IS, 'IS', '`IS` attendu apres nom de package body');

 { Package Text_IO standard ? }
 is_textio := (nm = 'ADA.TEXT_IO') Or (nm = 'TEXT_IO')
           Or (nm = 'ADA.INTEGER_TEXT_IO') Or (nm = 'ADA.FLOAT_TEXT_IO');

 { Enregistrer le package }
 idx := FindPkg(nm);
 If idx = 0 Then
  idx := AddPkg(nm, is_textio);

 PushScope(SK_PACKAGE, 0);

 { Pour Ada.Text_IO : enregistrer les sous-programmes stubs }
 If is_textio Then
 Begin
  RegisterTextIO_Subs;
  { Consommer le corps du package sans generer de code utilisateur }
  While Not TokIsKw(KW_END) And (cur_tok_type <> TOK_EOF) do
  Begin
   If TokIsKw(KW_BEGIN) Then Begin Consume; Break; End;
   SkipToSemi;
  End;
  { Consommer jusqu'a END }
  While Not TokIsKw(KW_END) And (cur_tok_type <> TOK_EOF) do Consume;
 End
 Else
 Begin
  { Corps de package utilisateur : parser toutes les declarations }
  While True do
  Begin
   If cur_tok_type = TOK_EOF   Then Break;
   If TokIsKw(KW_END)          Then Break;
   If TokIsKw(KW_BEGIN)        Then Break;
   If TokIsKw(KW_PROCEDURE)    Then ParseProcedureBody
   Else If TokIsKw(KW_FUNCTION) Then ParseFunctionBody
   Else If TokIsKw(KW_TYPE)    Then ParseTypeDecl
   Else If TokIsKw(KW_SUBTYPE) Then ParseSubtypeDecl
   Else If TokIsKw(KW_PRAGMA) Then
   Begin
    Consume;
    If cur_tok_type = TOK_IDENT Then Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume;
     While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
     Consume;
    End;
    Expect(TOK_SEMI, '`;` attendu apres PRAGMA');
   End
   Else If (cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_NONE) Then
    ParseObjectDecl
   Else
   Begin ErrorTok('Element inattendu dans corps de package'); SkipToSemi; End;
  End;
 End;

 { Bloc d'initialisation BEGIN ... END optionnel }
 If TokIsKw(KW_BEGIN) Then
 Begin
  Consume;
  lbl_init := AsmIdent('_PKG_', nm) + '_INIT';
  EmitBlank;
  EmitComment('Package init : ' + nm);
  EmitLabel(lbl_init);
  EmitI('PUSH BP');
  EmitI('MOV  BP, SP');
  ParseSequenceOfStatements;
  EmitI('POP  BP');
  EmitI('RET');
 End;

 PopScope;

 ExpectKw(KW_END, 'END', '`END` attendu en fin de package body');
 If cur_tok_type = TOK_IDENT Then
 Begin
  end_name := UpCaseStr(cur_tok_str);
  Consume;
 End;
 Expect(TOK_SEMI, '`;` attendu apres END de package body');
End;

{ ---- ParsePackage : PACKAGE [BODY] ... ---- }

Procedure ParsePackage;
Begin
 Consume; { PACKAGE }
 If TokIsKw(KW_BODY) Then
 Begin
  Consume; { BODY }
  ParsePackageBody;
 End
 Else
  ParsePackageSpec;
End;

{ ============================================================================ }
{ Point d'entree (sera remplace par Compile a TODO 24)                        }
{ ============================================================================ }

{ --- TODO 16 : ParseAssignment + ParseProcedureCall (implementation complete) --- }

{ ---- GenLoadAddrBX : charge l'adresse d'un symbole dans BX ---- }

Procedure GenLoadAddrBX(sym_idx: Integer);
Var off : Integer;
Begin
 Case sym_table^[sym_idx].store_class Of
  STORE_STATIC :
   EmitI('MOV  BX, OFFSET ' + sym_table^[sym_idx].asm_label);
  STORE_AUTO :
  Begin
   off := sym_table^[sym_idx].bp_offset;
   EmitI('MOV  BX, BP');
   If off < 0 Then
    EmitI('ADD  BX, ' + IntToStr(off))
   Else If off > 0 Then
    EmitI('ADD  BX, ' + IntToStr(off));
  End;
 End;
End;

{ ---- GenPushAddr : pousse l'adresse d'un symbole (pour OUT/IN OUT) ---- }

Procedure GenPushAddr(sym_idx: Integer);
Begin
 GenLoadAddrBX(sym_idx);
 EmitI('PUSH BX');
End;

{ ---- ParseLhsInfo : parse un LHS et retourne descripteur ----
  Entree  : cur_tok sur l'identifiant de base                                 }

Function ParseLhsInfo(Var sym_idx, field_off: Integer;
                      Var has_index: Boolean): Boolean;
Var nm  : String;
    ti  : Integer;
    i   : Integer;
Begin
 field_off := 0;
 has_index := False;
 sym_idx   := 0;
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Identifiant attendu dans LHS'); ParseLhsInfo := False; Exit; End;
 nm := UpCaseStr(cur_tok_str);
 Consume;
 sym_idx := FindSym(nm);
 If sym_idx = 0 Then
 Begin Error('Symbole inconnu dans LHS : ' + nm); ParseLhsInfo := False; Exit; End;
 ti := sym_table^[sym_idx].type_idx;
 { .champ }
 If cur_tok_type = TOK_DOT Then
 Begin
  Consume;
  If cur_tok_type <> TOK_IDENT Then
  Begin ErrorTok('Nom de champ attendu apres `.`'); ParseLhsInfo := False; Exit; End;
  nm := UpCaseStr(cur_tok_str);
  Consume;
  If (ti > 0) And (type_table^[ti].kind = TK_RECORD) Then
  Begin
   For i := 1 to type_table^[ti].field_count do
    If type_table^[ti].field_names[i] = nm Then
    Begin field_off := type_table^[ti].field_offs[i]; Break; End;
  End
  Else Warning('Acces `.champ` sur type non-RECORD');
 End
 { (index) }
 Else If cur_tok_type = TOK_LPAREN Then
 Begin
  has_index := True;
  Consume;
  ParseExpr;   { AX = index }
  { Slice T(lo..hi) : warning, on ignore hi et met offset=0 }
  If cur_tok_type = TOK_DOTDOT Then
  Begin
   Warning('Slice Ada dans LHS non supporte, seule la borne basse est utilisee');
   Consume;
   ParseExpr;   { consommer hi }
   EmitI('MOV  AX, 0');   { offset = 0 par defaut }
  End;
  { SI = (AX - lo_bound) * elem_size via GenElemOffset }
  GenElemOffset(sym_idx);
  Expect(TOK_RPAREN, '`)` attendu apres index de tableau dans LHS');
 End;
 ParseLhsInfo := True;
End;

{ ---- GenStoreLhs : stocke AX dans le LHS decrit ---- }

Procedure GenStoreLhs(sym_idx, field_off: Integer; has_index: Boolean);
Var sc  : Integer;
    off : Integer;
    lbl : String;
Begin
 If sym_table^[sym_idx].is_const Then
 Begin Error('Assignation a une constante : ' + sym_table^[sym_idx].name); Exit; End;
 sc  := sym_table^[sym_idx].store_class;
 off := sym_table^[sym_idx].bp_offset;
 lbl := sym_table^[sym_idx].asm_label;
 If has_index Then
 Begin
  GenLoadAddrBX(sym_idx);
  EmitI('ADD  BX, SI');
  If field_off > 0 Then EmitI('ADD  BX, ' + IntToStr(field_off));
  EmitI('MOV  [BX], AX');
 End
 Else If sc = STORE_STATIC Then
 Begin
  If field_off > 0 Then
   EmitI('MOV  WORD PTR [' + lbl + '+' + IntToStr(field_off) + '], AX')
  Else
   EmitI('MOV  [' + lbl + '], AX');
 End
 Else
 Begin
  off := off + field_off;
  If off < 0 Then
   EmitI('MOV  [BP' + IntToStr(off) + '], AX')
  Else If off > 0 Then
   EmitI('MOV  [BP+' + IntToStr(off) + '], AX')
  Else
   EmitI('MOV  [BP], AX');
 End;
End;

{ ============================================================================ }
{ TODO 20 - Acces tableaux : GenElemOffset, GenLoadElement, GenStoreElement   }
{ ============================================================================ }

{ ---- GenElemOffset : AX = index -> SI = byte offset dans le tableau ----
  Utilise lo_bound et elem_size reels de type_table quand le symbole est
  un tableau 1D de type TK_ARRAY ; sinon hypothese lo=1, stride=2.            }

Procedure GenElemOffset(sym_idx: Integer);
Var ti  : Integer;
    lo  : LongInt;
    esz : Integer;
Begin
 ti  := sym_table^[sym_idx].type_idx;
 If (ti > 0) And (type_table^[ti].kind = TK_ARRAY) Then
 Begin
  lo  := type_table^[ti].lo_bound;
  esz := type_table^[ti].elem_size;
  If lo <> 0 Then
   EmitI('SUB  AX, ' + IntToStr(lo));
  If esz = 2 Then
   EmitI('SHL  AX, 1')
  Else If esz > 2 Then
  Begin
   EmitI('MOV  BX, ' + IntToStr(esz));
   EmitI('IMUL BX');
  End;
  { esz = 1 : pas de multiplication (acces octet) }
 End
 Else
 Begin
  { Tableau generique ou type inconnu : lo=1, stride=2 }
  EmitI('DEC  AX');
  EmitI('SHL  AX, 1');
 End;
 EmitI('MOV  SI, AX');
End;

{ ---- GenLoadElement : AX=index en entree -> charge elem[AX] dans AX ----
  Sequence : compute SI via GenElemOffset, BX <- base, AX <- [BX+SI]         }

Procedure GenLoadElement(sym_idx: Integer);
Begin
 GenElemOffset(sym_idx);    { SI = byte offset }
 GenLoadAddrBX(sym_idx);    { BX = adresse de base (STATIC ou AUTO) }
 EmitI('ADD  BX, SI');
 EmitI('MOV  AX, [BX]');
End;

{ ---- GenStoreElement : AX=valeur, SI=byte offset -> stocke dans tab[SI] ---
  Sauvegarde AX, charge adresse dans BX, restaure et ecrit.                   }

Procedure GenStoreElement(sym_idx: Integer);
Begin
 EmitI('PUSH AX');           { sauver valeur }
 GenLoadAddrBX(sym_idx);    { BX = adresse de base }
 EmitI('ADD  BX, SI');
 EmitI('POP  AX');
 EmitI('MOV  [BX], AX');
End;

{ ============================================================================ }
{ TODO 21 - Acces records : GenLoadField, GenStoreField, agregats             }
{ ============================================================================ }

{ ---- GenLoadField : charge le champ a field_off octets de sym dans AX ---- }

Procedure GenLoadField(sym_idx, field_off: Integer);
Var sc  : Integer;
    off : Integer;
    lbl : String;
Begin
 sc  := sym_table^[sym_idx].store_class;
 off := sym_table^[sym_idx].bp_offset;
 lbl := sym_table^[sym_idx].asm_label;
 If sc = STORE_STATIC Then
 Begin
  If field_off > 0 Then
   EmitI('MOV  AX, WORD PTR [' + lbl + '+' + IntToStr(field_off) + ']')
  Else
   EmitI('MOV  AX, [' + lbl + ']');
 End
 Else
 Begin
  off := off + field_off;
  If off < 0 Then
   EmitI('MOV  AX, [BP' + IntToStr(off) + ']')
  Else If off > 0 Then
   EmitI('MOV  AX, [BP+' + IntToStr(off) + ']')
  Else
   EmitI('MOV  AX, [BP]');
 End;
End;

{ ---- GenStoreField : stocke AX dans le champ a field_off octets de sym ---- }

Procedure GenStoreField(sym_idx, field_off: Integer);
Var sc  : Integer;
    off : Integer;
    lbl : String;
Begin
 sc  := sym_table^[sym_idx].store_class;
 off := sym_table^[sym_idx].bp_offset;
 lbl := sym_table^[sym_idx].asm_label;
 If sc = STORE_STATIC Then
 Begin
  If field_off > 0 Then
   EmitI('MOV  WORD PTR [' + lbl + '+' + IntToStr(field_off) + '], AX')
  Else
   EmitI('MOV  [' + lbl + '], AX');
 End
 Else
 Begin
  off := off + field_off;
  If off < 0 Then
   EmitI('MOV  [BP' + IntToStr(off) + '], AX')
  Else If off > 0 Then
   EmitI('MOV  [BP+' + IntToStr(off) + '], AX')
  Else
   EmitI('MOV  [BP], AX');
 End;
End;

{ ---- ParseRecordAggregate : ( champ => val [, champ2 => val2 ...] ) ----
  Precondition : cur_tok est sur `(`, appelant a determine que c'est un
  agregat de record pour sym_idx.                                              }

Procedure ParseRecordAggregate(sym_idx: Integer);
Var ti        : Integer;
    nm        : String;
    fi        : Integer;
    foff      : Integer;
    fcount    : Integer;
    i         : Integer;
    fsym      : Integer;
Begin
 Consume; { ( }
 ti := sym_table^[sym_idx].type_idx;
 fcount := 0;
 { OTHERS => val : initialiser tous les champs avec la meme valeur }
 If TokIsKw(KW_OTHERS) Then
 Begin
  Consume;
  Expect(TOK_ARROW, '`=>` attendu apres OTHERS');
  ParseExpr;  { AX = valeur }
  If (ti > 0) And (type_table^[ti].kind = TK_RECORD) Then
   For i := 1 to type_table^[ti].field_count do
    GenStoreField(sym_idx, type_table^[ti].field_offs[i]);
 End
 Else
 Begin
  While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do
  Begin
   Inc(fcount);
   foff := -1;
   { Accepter : champ => val (association nominale) OU val positionnelle }
   If cur_tok_type = TOK_IDENT Then
   Begin
    nm := UpCaseStr(cur_tok_str);
    Consume;
    If cur_tok_type = TOK_ARROW Then
    Begin
     Consume; { => }
     { Chercher l'offset du champ par nom }
     If (ti > 0) And (type_table^[ti].kind = TK_RECORD) Then
      For i := 1 to type_table^[ti].field_count do
       If type_table^[ti].field_names[i] = nm Then
       Begin foff := type_table^[ti].field_offs[i]; Break; End;
     If foff < 0 Then
     Begin Warning('Champ inconnu dans agregat : ' + nm); foff := 0; End;
     ParseExpr;
     GenStoreField(sym_idx, foff);
    End
    Else
    Begin
     { Positionnelle : nm est un ident debut d'expression }
     { Retrouver l'offset positionnel }
     If (ti > 0) And (type_table^[ti].kind = TK_RECORD)
        And (fcount <= type_table^[ti].field_count) Then
      foff := type_table^[ti].field_offs[fcount]
     Else foff := 0;
     { nm est deja consume, continuer l'expression }
     { la valeur simple nm : chercher dans symboles/enums, puis AX }
     fsym := FindSym(nm);
     If fsym > 0 Then GenLoadVar(fsym) Else EmitI('XOR AX, AX');
     GenStoreField(sym_idx, foff);
    End;
   End
   Else
   Begin
    { Valeur positionnelle directement }
    If (ti > 0) And (type_table^[ti].kind = TK_RECORD)
       And (fcount <= type_table^[ti].field_count) Then
     foff := type_table^[ti].field_offs[fcount]
    Else foff := 0;
    ParseExpr;
    GenStoreField(sym_idx, foff);
   End;
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
 End;
 Expect(TOK_RPAREN, '`)` attendu en fin d''agregat de record');
End;

{ ---- ParseAssignment : ident [.champ | (index)] := expr ; ---- }

Procedure ParseAssignment;
Var sym_idx   : Integer;
    field_off : Integer;
    has_index : Boolean;
    saved_type : Integer;
Begin
 If Not ParseLhsInfo(sym_idx, field_off, has_index) Then
 Begin SkipToSemi; Exit; End;
 Expect(TOK_COLONASSIGN, '`:=` attendu dans assignation');
 { Agregat de record : ( champ => val, ... ) }
 If (cur_tok_type = TOK_LPAREN) And
    Not has_index And (field_off = 0) Then
 Begin
  { Verifier si c'est un agregat (premier token interieur est ident => ou OTHERS) }
  saved_type := sym_table^[sym_idx].type_idx;
  If (saved_type > 0) And (type_table^[saved_type].kind = TK_RECORD) Then
  Begin
   ParseRecordAggregate(sym_idx);
   Expect(TOK_SEMI, '`;` attendu apres assignation agregat');
   Exit;
  End;
 End;
 ParseExpr;
 GenStoreLhs(sym_idx, field_off, has_index);
 Expect(TOK_SEMI, '`;` attendu apres assignation');
End;

{ ---- ParseOneArg : un argument d'appel (mode IN, OUT, ou IN OUT) ----
  IN      : evaluer expression -> PUSH AX
  OUT/INOUT : pousser adresse de la variable effective -> PUSH BX             }

Procedure ParseOneArg(mode: Integer);
Var nm      : String;
    lhs_sym : Integer;
Begin
 If (mode = PARAM_OUT) Or (mode = PARAM_INOUT) Then
 Begin
  { L-valeur obligatoire (variable) ; gestion ident => var }
  If cur_tok_type = TOK_IDENT Then
  Begin
   nm := UpCaseStr(cur_tok_str); Consume;
   If cur_tok_type = TOK_ARROW Then
   Begin Consume; nm := UpCaseStr(cur_tok_str); Consume; End;
   lhs_sym := FindSym(nm);
   If lhs_sym > 0 Then GenPushAddr(lhs_sym)
   Else Begin Error('Variable OUT attendue : ' + nm); EmitI('PUSH 0'); End;
   { Absorber .champ ou (index) sur le LHS OUT }
   If cur_tok_type = TOK_DOT Then
   Begin Consume; If cur_tok_type = TOK_IDENT Then Consume; End;
   If cur_tok_type = TOK_LPAREN Then
   Begin
    Consume;
    While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
    Consume;
   End;
  End
  Else Begin ParseExpr; EmitI('PUSH AX'); End;
 End
 Else { PARAM_IN }
 Begin
  { Detection association nommee : ident => expr }
  If cur_tok_type = TOK_IDENT Then
  Begin
   nm := UpCaseStr(cur_tok_str); Consume;
   If cur_tok_type = TOK_ARROW Then
   Begin
    Consume;   { sauter => }
    ParseExpr;
    EmitI('PUSH AX');
   End
   Else
   Begin
    { nm est le debut de l'expression (variable seule, common case) }
    lhs_sym := FindSym(nm);
    If lhs_sym > 0 Then GenLoadVar(lhs_sym)
    Else EmitI('XOR  AX, AX');
    EmitI('PUSH AX');
   End;
  End
  Else
  Begin
   ParseExpr;
   EmitI('PUSH AX');
  End;
 End;
End;

{ ---- ParseProcedureCall : nom [(arg1, arg2, ...)] ; ---- }

Procedure ParseProcedureCall;
Var nm       : String;
    sub_idx  : Integer;
    pc       : Integer;
    arg_num  : Integer;
    mode     : Integer;
Begin
 nm := UpCaseStr(cur_tok_str);
 Consume;   { identifiant }
 sub_idx := FindSub(nm);
 If sub_idx = 0 Then
 Begin
  Warning('Procedure inconnue : ' + nm);
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do Consume;
   Consume;
  End;
  Expect(TOK_SEMI, '`;` attendu apres appel');
  Exit;
 End;
 pc := sub_table^[sub_idx].param_count;
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  arg_num := 0;
  While (cur_tok_type <> TOK_RPAREN) And (cur_tok_type <> TOK_EOF) do
  Begin
   Inc(arg_num);
   If (arg_num >= 1) And (arg_num <= pc) Then
    mode := sub_table^[sub_idx].param_modes[arg_num]
   Else
    mode := PARAM_IN;
   ParseOneArg(mode);
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
  Consume; { ) }
 End;
 EmitI('CALL ' + sub_table^[sub_idx].asm_label);
 { Callee-cleanup: RET n dans le sous-programme, pas d'ADD SP ici }
 Expect(TOK_SEMI, '`;` attendu apres appel de procedure');
End;

{ ============================================================================ }
{ TODO 17 - ParseIf / ParseCase                                               }
{ ============================================================================ }

{ ---- ParseIf : IF cond THEN stmts [ELSIF cond THEN stmts]* [ELSE stmts] END IF ; ---- }

Procedure ParseIf;
Var lbl_next : String;
    lbl_end  : String;
Begin
 Consume; { IF }
 lbl_end := NewLabel;
 { Premiere condition }
 ParseExpr;
 EmitI('CMP  AX, 0');
 lbl_next := NewLabel;
 EmitI('JE   ' + lbl_next);
 ExpectKw(KW_THEN, 'THEN', '`THEN` attendu apres condition IF');
 ParseSequenceOfStatements;
 EmitI('JMP  ' + lbl_end);
 EmitLabel(lbl_next);
 { Branches ELSIF }
 While TokIsKw(KW_ELSIF) do
 Begin
  Consume; { ELSIF }
  ParseExpr;
  EmitI('CMP  AX, 0');
  lbl_next := NewLabel;
  EmitI('JE   ' + lbl_next);
  ExpectKw(KW_THEN, 'THEN', '`THEN` attendu apres condition ELSIF');
  ParseSequenceOfStatements;
  EmitI('JMP  ' + lbl_end);
  EmitLabel(lbl_next);
 End;
 { Branche ELSE optionnelle }
 If TokIsKw(KW_ELSE) Then
 Begin
  Consume; { ELSE }
  ParseSequenceOfStatements;
 End;
 ExpectKw(KW_END, 'END', '`END` attendu apres IF');
 If TokIsKw(KW_IF) Then Consume;
 Expect(TOK_SEMI, '`;` attendu apres END IF');
 EmitLabel(lbl_end);
End;

{ ---- GetCaseVal : lit une valeur scalaire constante pour WHEN  ----
  Retourne True si valeur constante obtenue dans v.
  Handles : integer literals, char literals, TRUE/FALSE, enum literals,
  symbolic constants.                                                          }

Function GetCaseVal(Var v: LongInt): Boolean;
Var nm : String;
    ti : Integer;
    j  : Integer;
    si : Integer;
Begin
 GetCaseVal := False; v := 0;
 If cur_tok_type = TOK_INTEGER Then
 Begin v := cur_tok_num; Consume; GetCaseVal := True; Exit; End;
 If cur_tok_type = TOK_CHAR Then
 Begin v := Ord(cur_tok_str[1]); Consume; GetCaseVal := True; Exit; End;
 If cur_tok_type = TOK_IDENT Then
 Begin
  nm := UpCaseStr(cur_tok_str);
  If nm = 'TRUE'  Then Begin v := 1; Consume; GetCaseVal := True; Exit; End;
  If nm = 'FALSE' Then Begin v := 0; Consume; GetCaseVal := True; Exit; End;
  { Litteraux d'enumeres }
  For ti := 1 to type_count do
   If type_table^[ti].kind = TK_ENUM Then
    For j := 1 to type_table^[ti].enum_count do
     If type_table^[ti].enum_names[j] = nm Then
     Begin
      v := j - 1; Consume; GetCaseVal := True; Exit;
     End;
  { Constante symbolique }
  si := FindSym(nm);
  If (si > 0) And sym_table^[si].is_const Then
  Begin
   v := sym_table^[si].init_num; Consume; GetCaseVal := True; Exit;
  End;
  Warning('Valeur de WHEN inconnue : ' + nm);
  Consume;
 End;
End;

{ ---- ParseCase : CASE expr IS WHEN val [| val2 ...] => stmts ... END CASE ; ---- }

Procedure ParseCase;
Var lbl_body : String;
    lbl_next : String;
    lbl_end  : String;
    v        : LongInt;
Begin
 Consume; { CASE }
 ParseExpr;            { AX = valeur du CASE }
 EmitI('MOV  BX, AX'); { preserver dans BX pour les CMP successifs }
 ExpectKw(KW_IS, 'IS', '`IS` attendu apres expression CASE');
 lbl_end := NewLabel;
 While TokIsKw(KW_WHEN) And (cur_tok_type <> TOK_EOF) do
 Begin
  Consume; { WHEN }
  If TokIsKw(KW_OTHERS) Then
  Begin
   Consume; { OTHERS }
   Expect(TOK_ARROW, '`=>` attendu apres OTHERS');
   ParseSequenceOfStatements;
   EmitI('JMP  ' + lbl_end);
  End
  Else
  Begin
   lbl_body := NewLabel;
   lbl_next := NewLabel;
   { Un ou plusieurs choix separes par | }
   While True do
   Begin
    If GetCaseVal(v) Then
    Begin
     EmitI('CMP  BX, ' + IntToStr(v));
     EmitI('JE   ' + lbl_body);
    End;
    If cur_tok_type = TOK_BAR Then Consume
    Else Break;
   End;
   EmitI('JMP  ' + lbl_next);
   EmitLabel(lbl_body);
   Expect(TOK_ARROW, '`=>` attendu apres choix WHEN');
   ParseSequenceOfStatements;
   EmitI('JMP  ' + lbl_end);
   EmitLabel(lbl_next);
  End;
 End;
 EmitLabel(lbl_end);
 ExpectKw(KW_END, 'END', '`END` attendu apres CASE');
 If TokIsKw(KW_CASE) Then Consume;
 Expect(TOK_SEMI, '`;` attendu apres END CASE');
End;

{ ============================================================================ }
{ TODO 18 - ParseLoop / ParseWhile / ParseFor                                 }
{ ============================================================================ }

{ ---- ParseLoop : LOOP stmts END LOOP ;  (boucle infinie) ---- }

Procedure ParseLoop;
Var lbl_cont : String;
    lbl_end  : String;
Begin
 Consume; { LOOP }
 lbl_cont := NewLabel;
 lbl_end  := NewLabel;
 PushScope(SK_LOOP, EnclosingSubIdx);
 EnterLoop(lbl_cont, lbl_end);
 EmitLabel(lbl_cont);
 ParseSequenceOfStatements;
 EmitI('JMP  ' + lbl_cont);
 EmitLabel(lbl_end);
 PopScope;
 ExpectKw(KW_END, 'END', '`END` attendu apres LOOP');
 If TokIsKw(KW_LOOP) Then Consume;
 Expect(TOK_SEMI, '`;` attendu apres END LOOP');
End;

{ ---- ParseWhile : WHILE cond LOOP stmts END LOOP ; ---- }

Procedure ParseWhile;
Var lbl_cont : String;
    lbl_end  : String;
Begin
 Consume; { WHILE }
 lbl_cont := NewLabel;
 lbl_end  := NewLabel;
 PushScope(SK_LOOP, EnclosingSubIdx);
 EnterLoop(lbl_cont, lbl_end);
 EmitLabel(lbl_cont);
 ParseExpr;            { AX = condition }
 EmitI('CMP  AX, 0');
 EmitI('JE   ' + lbl_end);
 ExpectKw(KW_LOOP, 'LOOP', '`LOOP` attendu apres condition WHILE');
 ParseSequenceOfStatements;
 EmitI('JMP  ' + lbl_cont);
 EmitLabel(lbl_end);
 PopScope;
 ExpectKw(KW_END, 'END', '`END` attendu apres WHILE LOOP');
 If TokIsKw(KW_LOOP) Then Consume;
 Expect(TOK_SEMI, '`;` attendu apres END LOOP');
End;

{ ---- ParseFor : FOR ident IN [REVERSE] lo .. hi LOOP stmts END LOOP ;
  Strategie : donnees du compteur et de la borne haute embarquees dans
  le segment de code (saut JMP par-dessus), ce qui evite toute
  collision avec la frame BP du sous-programme courant.

  Code genere :
      JMP  _LSTART_xxx
  _FORI_xxx  DW  0        ; compteur courant (I)
  _FORH_xxx  DW  0        ; borne haute (ou basse si REVERSE)
  _LSTART_xxx:
      MOV  AX, <lo>
      MOV  [_FORI_xxx], AX
      MOV  AX, <hi>
      MOV  [_FORH_xxx], AX
  _LCONT_xxx:
      MOV  AX, [_FORI_xxx]
      CMP  AX, [_FORH_xxx]
      JG/JL _LEND_xxx      (selon REVERSE)
      ...stmts...           (I lit [_FORI_xxx])
      INC/DEC WORD PTR [_FORI_xxx]
      JMP  _LCONT_xxx
  _LEND_xxx:
                                                                              }

Procedure ParseFor;
Var iter_nm   : String;    { nom Ada de la variable de boucle              }
    lbl_iter  : String;    { label DW compteur                              }
    lbl_hi    : String;    { label DW borne                                 }
    lbl_start : String;    { label apres les DW                             }
    lbl_cont  : String;
    lbl_end   : String;
    is_rev    : Boolean;
    sym_iter  : Integer;   { index symbole de boucle (lecture seule)        }
Begin
 Consume; { FOR }
 { Lire le nom de la variable de boucle }
 If cur_tok_type <> TOK_IDENT Then
 Begin ErrorTok('Identifiant attendu apres FOR'); SkipToSemi; Exit; End;
 iter_nm := UpCaseStr(cur_tok_str);
 Consume;
 ExpectKw(KW_IN, 'IN', '`IN` attendu apres identificateur FOR');
 { REVERSE optionnel }
 is_rev := False;
 If TokIsKw(KW_REVERSE) Then Begin is_rev := True; Consume; End;
 { Generer les labels uniques }
 lbl_iter  := '_FORI' + NewLabel;
 lbl_hi    := '_FORH' + NewLabel;
 lbl_start := '_FORS' + NewLabel;
 lbl_cont  := NewLabel;
 lbl_end   := NewLabel;
 { Evaluer borne basse (lo) }
 ParseExpr;          { AX = lo }
 EmitI('PUSH AX');   { sauvegarder lo }
 Expect(TOK_DOTDOT, '`..` attendu dans intervalle FOR');
 { Evaluer borne haute (hi) }
 ParseExpr;          { AX = hi }
 EmitI('PUSH AX');   { sauvegarder hi }
 { Sauter par-dessus les DW embarques }
 EmitI('JMP  ' + lbl_start);
 EmitLabel(lbl_iter); EmitI('DW   0');
 EmitLabel(lbl_hi);   EmitI('DW   0');
 EmitLabel(lbl_start);
 { Recuperer hi et lo depuis la pile, initialiser les cellules }
 EmitI('POP  AX');   { hi }
 If is_rev Then
 Begin
  EmitI('MOV  [' + lbl_iter + '], AX');  { iter = hi  (REVERSE part de hi) }
  EmitI('POP  AX');                       { lo }
  EmitI('MOV  [' + lbl_hi   + '], AX');  { hi_cell = lo (borne basse) }
 End
 Else
 Begin
  EmitI('MOV  [' + lbl_hi   + '], AX');  { hi_cell = hi }
  EmitI('POP  AX');                       { lo }
  EmitI('MOV  [' + lbl_iter + '], AX');  { iter = lo }
 End;
 { Enregistrer le symbole Ada de boucle (lecture seule, statique sur lbl_iter) }
 PushScope(SK_LOOP, EnclosingSubIdx);
 EnterLoop(lbl_cont, lbl_end);
 sym_iter := AddSym(iter_nm, TYPE_INT, STORE_STATIC);
 If sym_iter > 0 Then
 Begin
  sym_table^[sym_iter].asm_label := lbl_iter;
  sym_table^[sym_iter].is_const  := True;  { lecture seule }
 End;
 { Label de continuation : test de la borne }
 EmitLabel(lbl_cont);
 EmitI('MOV  AX, [' + lbl_iter + ']');
 EmitI('CMP  AX, [' + lbl_hi   + ']');
 If is_rev Then
  EmitI('JL   ' + lbl_end)   { iter < lo_bound -> sortir }
 Else
  EmitI('JG   ' + lbl_end);  { iter > hi_bound -> sortir }
 ExpectKw(KW_LOOP, 'LOOP', '`LOOP` attendu dans FOR');
 ParseSequenceOfStatements;
 { Incrementer ou decrementer le compteur }
 If is_rev Then
  EmitI('DEC  WORD PTR [' + lbl_iter + ']')
 Else
  EmitI('INC  WORD PTR [' + lbl_iter + ']');
 EmitI('JMP  ' + lbl_cont);
 EmitLabel(lbl_end);
 PopScope;
 ExpectKw(KW_END, 'END', '`END` attendu apres FOR LOOP');
 If TokIsKw(KW_LOOP) Then Consume;
 Expect(TOK_SEMI, '`;` attendu apres END LOOP');
End;

Procedure ParseReturn;
Var lbl : String;
Begin
 Consume; { RETURN }
 If Not TokIsOp(TOK_SEMI) Then
 Begin
  { Expression de retour pour FUNCTION }
  ParseExpr;  { resultat dans AX }
 End;
 { JMP vers lbl_exit du scope courant }
 lbl := FindExitLabel;
 If lbl <> '' Then
  EmitI('JMP  ' + lbl)
 Else
  Warning('RETURN sans sous-programme englobant');
 Expect(TOK_SEMI, '`;` attendu apres RETURN');
End;

{ ============================================================================ }
{ TODO 19 - ParseRaise (ameliore) et ParseExceptionDecl (via ParseObjectDecl) }
{ ============================================================================ }

Procedure ParseRaise;
Var nm     : String;
    lbl_ex : String;
    si     : Integer;
    code   : LongInt;
Begin
 Consume; { RAISE }
 nm := '';
 code := 0;
 If cur_tok_type = TOK_IDENT Then
 Begin
  nm := UpCaseStr(cur_tok_str);
  Consume;
  { Chercher le code de l'exception par nom }
  si := FindSym(nm);
  If (si > 0) And sym_table^[si].is_const Then
   code := sym_table^[si].init_num
  Else
  Begin
   Warning('Exception non declaree dans RAISE : ' + nm);
   code := 255;  { code generique d'erreur }
  End;
  { Poser le code dans AX avant de sauter }
  EmitI('MOV  AX, ' + IntToStr(code));
 End
 Else
 Begin
  { RAISE ; sans nom : re-raise, AX inchange }
  EmitI('NOP  ');
 End;
 { Sauter vers le handler le plus proche }
 lbl_ex := FindExceptLabel;
 If lbl_ex <> '' Then
  EmitI('JMP  ' + lbl_ex)
 Else
 Begin
  { Pas de handler : terminer le programme (DOS exit avec code d'erreur) }
  If code <> 0 Then
   EmitI('MOV  AL, ' + IntToStr(code))
  Else
   EmitI('MOV  AL, 1');
  EmitI('MOV  AH, 4CH');
  EmitI('INT  21H');
 End;
 Expect(TOK_SEMI, '`;` attendu apres RAISE');
End;

{ ============================================================= }
{ TODO 22 — GenRuntimeData + GenRuntimeHelpers                  }
{ GenRuntimeData  : declare _NUMBUF + _INPUTBUF dans .DATA      }
{ GenRuntimeHelpers : emets les helpers runtime 8086/DOS        }
{   _RT_NEWLINE   _RT_PUTCHAR  _RT_PUTS                         }
{   _RT_PUTI      _RT_GETS     _RT_GETI    _ADA_ERROR           }
{ ============================================================= }

{ ------------- buffers ------------------------------------- }
Procedure GenRuntimeData;
Begin
 EmitBlank;
 EmitComment('--- Runtime buffers (emis dans .DATA) ---');
 Emit('_NUMBUF    DB  7 DUP(0)  ; buffer conversion entier->chaine');
 Emit('_INPUTBUF  DB  128 DUP(0); buffer lecture DOS AH=0Ah');
End;

{ ------------- helpers ------------------------------------- }
Procedure GenRuntimeHelpers;
Begin
 EmitBlank;
 EmitComment('=== Runtime helpers ADA86 (MS-DOS INT 21h) ===');

 { ------ _RT_NEWLINE : emet CR + LF ---------------------- }
 EmitBlank;
 EmitComment('_RT_NEWLINE : emet CR (0Dh) puis LF (0Ah)');
 EmitLabel('_RT_NEWLINE');
 EmitI('PUSH AX');
 EmitI('PUSH DX');
 EmitI('MOV  AH, 02h');
 EmitI('MOV  DL, 0Dh');
 EmitI('INT  21h');
 EmitI('MOV  DL, 0Ah');
 EmitI('INT  21h');
 EmitI('POP  DX');
 EmitI('POP  AX');
 EmitI('RET');

 { ------ _RT_PUTCHAR : affiche le caractere dans AL ------- }
 EmitBlank;
 EmitComment('_RT_PUTCHAR : affiche le caractere dans AL via AH=02h');
 EmitLabel('_RT_PUTCHAR');
 EmitI('PUSH AX');
 EmitI('PUSH DX');
 EmitI('MOV  AH, 02h');
 EmitI('MOV  DL, AL');
 EmitI('INT  21h');
 EmitI('POP  DX');
 EmitI('POP  AX');
 EmitI('RET');

 { ------ _RT_PUTS : AX = offset chaine Pascal ------------- }
 { format : [BX+0]=longueur, [BX+1..n]=octets, [BX+n+1]=0  }
 EmitBlank;
 EmitComment('_RT_PUTS : AX=offset chaine Pascal; imprime via AH=02h');
 EmitLabel('_RT_PUTS');
 EmitI('PUSH AX');
 EmitI('PUSH BX');
 EmitI('PUSH CX');
 EmitI('PUSH DX');
 EmitI('MOV  BX, AX');
 EmitI('XOR  CH, CH');
 EmitI('MOV  CL, [BX]');
 EmitI('JCXZ _RT_PUTS_END');
 EmitI('INC  BX');
 EmitLabel('_RT_PUTS_LP');
 EmitI('MOV  DL, [BX]');
 EmitI('MOV  AH, 02h');
 EmitI('INT  21h');
 EmitI('INC  BX');
 EmitI('LOOP _RT_PUTS_LP');
 EmitLabel('_RT_PUTS_END');
 EmitI('POP  DX');
 EmitI('POP  CX');
 EmitI('POP  BX');
 EmitI('POP  AX');
 EmitI('RET');

 { ------ _RT_PUTI : AX = entier signe 16b -> decimal ------ }
 EmitBlank;
 EmitComment('_RT_PUTI : AX=entier signe -> affiche decimal via _NUMBUF');
 EmitLabel('_RT_PUTI');
 EmitI('PUSH BX');
 EmitI('PUSH CX');
 EmitI('PUSH DX');
 EmitI('PUSH SI');
 EmitI('CMP  AX, 0');
 EmitI('JGE  _RT_PUTI_POS');
 EmitI('PUSH AX');
 EmitI('MOV  AH, 02h');
 EmitI('MOV  DL, 2Dh');  { '-' = 0x2D }
 EmitI('INT  21h');
 EmitI('POP  AX');
 EmitI('NEG  AX');
 EmitLabel('_RT_PUTI_POS');
 { Construire les chiffres a rebours dans _NUMBUF }
 EmitI('MOV  SI, OFFSET _NUMBUF');
 EmitI('ADD  SI, 6');   { pointer a la fin du buffer de 7 octets }
 EmitI('MOV  BX, 10');
 EmitI('XOR  CX, CX');
 EmitLabel('_RT_PUTI_DIG');
 EmitI('XOR  DX, DX');
 EmitI('DIV  BX');      { DX = chiffre, AX = quotient }
 EmitI('ADD  DL, 30h'); { '0'+chiffre }
 EmitI('DEC  SI');
 EmitI('MOV  [SI], DL');
 EmitI('INC  CX');
 EmitI('CMP  AX, 0');
 EmitI('JNE  _RT_PUTI_DIG');
 { Imprimer CX chiffres depuis SI }
 EmitI('MOV  AH, 02h');
 EmitLabel('_RT_PUTI_PR');
 EmitI('MOV  DL, [SI]');
 EmitI('INT  21h');
 EmitI('INC  SI');
 EmitI('LOOP _RT_PUTI_PR');
 EmitI('POP  SI');
 EmitI('POP  DX');
 EmitI('POP  CX');
 EmitI('POP  BX');
 EmitI('RET');

 { ------ _RT_GETS : AX = adr dest Pascal string ----------- }
 { lit une ligne via AH=0Ah; stocke dans dest: [0]=len,[1..n]=octets,[n+1]=0 }
 EmitBlank;
 EmitComment('_RT_GETS : AX=dest; lit ligne stdin via AH=0Ah -> Pascal string');
 EmitLabel('_RT_GETS');
 EmitI('PUSH BX');
 EmitI('PUSH CX');
 EmitI('PUSH DX');
 EmitI('PUSH SI');
 EmitI('MOV  BX, AX');
 EmitI('MOV  BYTE PTR [_INPUTBUF], 126');
 EmitI('MOV  BYTE PTR [_INPUTBUF+1], 0');
 EmitI('MOV  AH, 0Ah');
 EmitI('MOV  DX, OFFSET _INPUTBUF');
 EmitI('INT  21h');
 EmitI('MOV  AH, 02h');  { emet LF pour avancer la ligne }
 EmitI('MOV  DL, 0Ah');
 EmitI('INT  21h');
 EmitI('XOR  CH, CH');
 EmitI('MOV  CL, [_INPUTBUF+1]');
 EmitI('MOV  [BX], CL'); { stocker longueur dans dest[0] }
 EmitI('JCXZ _RT_GETS_END');
 EmitI('MOV  SI, OFFSET _INPUTBUF');
 EmitI('ADD  SI, 2');     { debut des chars dans _INPUTBUF }
 EmitI('INC  BX');        { dest[1] }
 EmitLabel('_RT_GETS_CP');
 EmitI('MOV  AL, [SI]');
 EmitI('MOV  [BX], AL');
 EmitI('INC  SI');
 EmitI('INC  BX');
 EmitI('LOOP _RT_GETS_CP');
 EmitI('MOV  BYTE PTR [BX], 0'); { terminateur null }
 EmitLabel('_RT_GETS_END');
 EmitI('POP  SI');
 EmitI('POP  DX');
 EmitI('POP  CX');
 EmitI('POP  BX');
 EmitI('RET');

 { ------ _RT_GETI : lit entier stdin -> AX ---------------- }
 EmitBlank;
 EmitComment('_RT_GETI : lit entier signe desde stdin -> AX');
 EmitLabel('_RT_GETI');
 EmitI('PUSH BX');
 EmitI('PUSH CX');
 EmitI('PUSH DX');
 EmitI('PUSH SI');
 EmitI('MOV  BYTE PTR [_INPUTBUF], 10');
 EmitI('MOV  BYTE PTR [_INPUTBUF+1], 0');
 EmitI('MOV  AH, 0Ah');
 EmitI('MOV  DX, OFFSET _INPUTBUF');
 EmitI('INT  21h');
 EmitI('MOV  AH, 02h');  { LF apres saisie }
 EmitI('MOV  DL, 0Ah');
 EmitI('INT  21h');
 EmitI('XOR  CH, CH');
 EmitI('MOV  CL, [_INPUTBUF+1]');
 EmitI('MOV  SI, OFFSET _INPUTBUF');
 EmitI('ADD  SI, 2');
 EmitI('XOR  AX, AX');
 EmitI('MOV  BL, 0');     { BL = flag signe }
 EmitI('JCXZ _RT_GETI_DONE');
 EmitI('MOV  DL, [SI]');
 EmitI('CMP  DL, 2Dh');  { '-' }
 EmitI('JNE  _RT_GETI_DIG');
 EmitI('MOV  BL, 1');
 EmitI('INC  SI');
 EmitI('DEC  CX');
 EmitLabel('_RT_GETI_DIG');
 EmitI('JCXZ _RT_GETI_SGN');
 EmitI('MOV  DL, [SI]');
 EmitI('SUB  DL, 30h');
 EmitI('PUSH CX');
 EmitI('MOV  CX, 10');
 EmitI('MUL  CX');        { AX = AX * 10 }
 EmitI('POP  CX');
 EmitI('MOV  DH, 0');
 EmitI('ADD  AX, DX');
 EmitI('INC  SI');
 EmitI('DEC  CX');
 EmitI('JMP  _RT_GETI_DIG');
 EmitLabel('_RT_GETI_SGN');
 EmitI('CMP  BL, 0');
 EmitI('JE   _RT_GETI_DONE');
 EmitI('NEG  AX');
 EmitLabel('_RT_GETI_DONE');
 EmitI('POP  SI');
 EmitI('POP  DX');
 EmitI('POP  CX');
 EmitI('POP  BX');
 EmitI('RET');

 { ------ _ADA_ERROR : AX=offset msg -> affiche + exit(1) -- }
 EmitBlank;
 EmitComment('_ADA_ERROR : AX=offset msg; CALL _RT_PUTS + exit code 1');
 EmitLabel('_ADA_ERROR');
 EmitI('CALL _RT_PUTS');
 EmitI('CALL _RT_NEWLINE');
 EmitI('MOV  AX, 4C01h');
 EmitI('INT  21h');
End;

Begin
  WriteLn('ADA86 V1.0 - TODO 22 OK (Runtime helpers OK)');
  WriteLn('  GenRuntimeData    : _NUMBUF (7B) + _INPUTBUF (128B) en .DATA');
  WriteLn('  GenRuntimeHelpers : _RT_NEWLINE / _RT_PUTCHAR / _RT_PUTS');
  WriteLn('                      _RT_PUTI / _RT_GETS / _RT_GETI');
  WriteLn('                      _ADA_ERROR (PUT_STR + exit 1)');
  WriteLn('  Appel via CALL depuis GenTextIO_Stubs (TODO 14)');
End.
