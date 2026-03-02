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
    {ELSIF cond THEN stmts}
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
{ FIN DU FICHIER SQUELETTE - Implementer les TODOs dans l'ordre               }
{ ============================================================================ }

Program ADA86_Stub;
Begin
  WriteLn('ADA86 - Compilateur Ada -> 8086 (non encore implemente)');
  WriteLn('Implementez les 25 TODOs dans ADA86.PAS');
End.
