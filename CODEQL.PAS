{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

{ TODO - Liste des 26 points a implementer pour le clone de CodeQL :

  1.  Implementer l'infrastructure de base et les options de ligne de
      commande : sous-commandes (database create, database analyze,
      query run, database interpret-results), options -v, -d, -h,
      --search-path, --format, TOptions, ParseArgs, FatalError,
      WarnMsg, ShowBanner, ShowUsage. [IMPLEMENTE]

  2.  Implementer le lexeur pour le langage de requete QL : TTokenKind
      (TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT, TK_KEYWORD,
      TK_OP, TK_PUNCT, TK_COMMENT, TK_ANNOTATION), LexInit, LexClose,
      LexNextToken, reconnaissance des mots-cles QL (select, from,
      where, import, class, extends, predicate, result, exists, forall,
      not, and, or, implies, if, then, else, in, module, override,
      abstract, private, this, super, instanceof, any, none, count).
      [IMPLEMENTE]

  3.  Implementer l'analyseur syntaxique (parser) pour le langage QL :
      construction de l'arbre syntaxique abstrait (AST) des requetes,
      gestion des classes, des predicats, des formules logiques
      (conjonction, disjonction, negation, quantificateurs exists et
      forall), expressions select-from-where. [IMPLEMENTE]

  4.  Implementer le systeme de types du langage QL : types primitifs
      (int, float, string, boolean, date), types de reference vers les
      noeuds de l'AST source (@locatable, @expr, @stmt, @function,
      @class), verification des types dans les predicats et les
      expressions. [IMPLEMENTE]

  5.  Implementer le lexeur pour le langage source cible (Pascal) :
      TSourceTokenKind, reconnaissance des mots-cles Pascal (program,
      unit, uses, const, type, var, procedure, function, begin, end,
      if, then, else, while, for, repeat, case, with, record, array,
      string, integer, boolean, real), gestion des commentaires
      (accolades, parenthese-etoile, double-barre oblique).
      [IMPLEMENTE]

  6.  Implementer l'analyseur syntaxique du langage source (Pascal) :
      construction de l'AST complet du programme source avec les
      noeuds pour les declarations (types, constantes, variables,
      procedures, fonctions, unites), les instructions (affectation,
      appel, if, while, for, repeat, case, with, try) et les
      expressions (arithmetiques, logiques, relationnelles, acces
      aux tableaux, acces aux champs de records). [IMPLEMENTE]

  7.  Implementer la representation de la base de donnees relationnelle
      CodeQL : schema des tables (programs, files, locations, exprs,
      stmts, functions, variables, types, calls, accesses, comments,
      diagnostics), definition des colonnes et des cles primaires,
      relations entre les tables. [IMPLEMENTE]

  8.  Implementer le stockage de la base de donnees sur disque : format
      de fichier binaire pour les tables, index sur les colonnes cles,
      lecture et ecriture sequentielle et aleatoire des enregistrements,
      gestion d'un repertoire de base de donnees avec un fichier par
      table. [IMPLEMENTE]

  9.  Implementer l'extraction (extracteur) : parcours de l'AST du code
      source Pascal et insertion des enregistrements dans les tables de
      la base de donnees (un enregistrement par noeud AST, avec les
      positions source, les types resolus, les relations parent-enfant).
      [IMPLEMENTE]

  10. Implementer la hierarchie de classes QL et l'heritage : resolution
      des classes de base et des classes derivees, gestion du mot-cle
      extends, methodes heritees et surchargees (override), predicats
      caracteristiques (characteristic predicates), classes abstraites.
      [IMPLEMENTE]

  11. Implementer le moteur d'evaluation des predicats QL : evaluation
      des predicats non-recursifs, liaison des variables (binding),
      jointures entre les tables de la base de donnees, filtrage par
      les formules where, retour des tuples de resultats.
      [IMPLEMENTE]

  12. Implementer le graphe de flot de controle (CFG) : construction du
      graphe a partir de l'AST source avec les noeuds de base (blocs,
      branchements, boucles), aretes de flot normal et de flot
      exceptionnel, identification des points d'entree et de sortie.
      [IMPLEMENTE]

  13. Implementer l'analyse de flot de donnees (data flow) : calcul des
      definitions atteignantes (reaching definitions), chaines
      definition-utilisation (def-use chains), analyse de vivacite
      (liveness), propagation avant et arriere sur le CFG.
      [IMPLEMENTE]

  14. Implementer le suivi de teinte (taint tracking) : definition des
      sources de donnees non fiables (entrees utilisateur : ReadLn,
      ParamStr, fichiers), definition des puits sensibles (WriteLn
      avec format, Exec, Assign, acces SQL), propagation de la teinte
      a travers les affectations, les appels de procedures et les
      expressions. [IMPLEMENTE]

  15. Implementer les fonctions d'agregation du langage QL : count,
      sum, min, max, avg, rank, concat, strictcount, strictsum,
      strictconcat, avec gestion des clauses group by et order by
      dans les expressions select. [IMPLEMENTE]

  16. Implementer l'evaluation des requetes recursives : detection des
      predicats mutuellement recursifs, evaluation par point fixe
      (iteration jusqu'a stabilisation), gestion de la negation
      stratifiee pour eviter les cycles negatifs. [IMPLEMENTE]

  17. Implementer les requetes de securite integrees pour Pascal :
      detection d'injection de commandes (Exec avec donnees non
      validees), detection de debordement de tampon (acces a un
      tableau avec un indice non verifie), detection de fuites de
      ressources (fichiers ouverts non fermes), detection
      d'utilisation de variables non initialisees. [IMPLEMENTE]

  18. Implementer la sortie au format SARIF (Static Analysis Results
      Interchange Format) : generation d'un fichier JSON conforme
      au schema SARIF v2.1.0 avec les runs, les resultats, les
      locations (fichier, ligne, colonne), les messages, les
      niveaux de severite (error, warning, note), et les
      codeFlows pour le suivi de teinte. [IMPLEMENTE]

  19. Implementer la sortie au format CSV et texte : generation de
      tableaux de resultats formattes avec les colonnes selectionnees,
      option --format=csv pour le format separe par des virgules,
      option --format=text pour l'affichage tabule en console, avec
      tri et pagination des resultats. [IMPLEMENTE]

  20. Implementer le systeme d'import et de modules QL : resolution des
      chemins d'import (import pascal, import semmle.code.pascal),
      chargement des bibliotheques de requetes depuis --search-path,
      gestion des espaces de noms et des alias de modules. [IMPLEMENTE]

  21. Implementer la bibliotheque standard de predicats QL pour Pascal :
      classes de base (Element, Locatable, Expr, Stmt, Function,
      Variable, Type, Call, Access, Comment), predicats utilitaires
      (hasName, getType, getAChild, getLocation, getEnclosingFunction,
      getAnArgument, getTarget, flowsTo). [IMPLEMENTE]

  22. Implementer la commande "codeql database create" : orchestration
      complete de la creation de la base de donnees a partir d'un
      repertoire de sources Pascal (parcours recursif des fichiers
      .pas et .pp, extraction de chaque fichier, ecriture de la base
      de donnees dans le repertoire de sortie specifie). [IMPLEMENTE]

  23. Implementer la commande "codeql database analyze" : chargement
      de la base de donnees, chargement et compilation des suites de
      requetes (.ql et .qls), execution sequentielle de toutes les
      requetes, collecte et fusion des resultats, generation du
      rapport final au format choisi (SARIF, CSV, texte). [IMPLEMENTE]

  24. Implementer la commande "codeql query run" : chargement de la
      base de donnees, compilation et execution d'une seule requete
      QL specifiee en argument, affichage des resultats sur la
      sortie standard, mode interactif (REPL) avec l'option
      --interactive pour executer des requetes une par une.
      [IMPLEMENTE]

  25. Implementer la generation finale et les fichiers exemples :
      creation de 10 requetes exemples dans un repertoire SAMPLES
      (variables non initialisees, fichiers non fermes, debordement
      de tampon, injection de commandes, code mort, complexite
      cyclomatique, convention de nommage, parametres inutilises,
      code duplique, utilisation de Goto), documentation d'aide,
      nettoyage des ressources. [IMPLEMENTE]

  26. Implementer le support du langage C : lexeur C (32 mots-cles,
      operateurs C, commentaires /* */ et //, preprocesseur #include/#define),
      parseur C (fonctions, struct/union/enum, typedef, instructions
      if/while/for/do-while/switch/break/continue/return/goto, expressions
      avec operateur ternaire, cast, sizeof), detection des fichiers .c/.h,
      integration dans database create avec --language=c.
      [IMPLEMENTE]

  27. Implementer le support du langage C++ : lexeur C++ (mots-cles C++
      supplementaires class/namespace/template/virtual/public/private/
      protected/try/catch/throw/new/delete/bool/true/false/using/
      operator/friend/inline/explicit/mutable/typeid/typename/
      dynamic_cast/static_cast/reinterpret_cast/const_cast/nullptr),
      parseur C++ (classes, namespaces, templates, heritage, try/catch,
      new/delete, operateur ::), detection des fichiers .cpp/.cc/.cxx/
      .hpp/.hh/.hxx, integration dans database create avec --language=cpp.
      [IMPLEMENTE]
  28. Implementer le support du langage C# : lexeur C# (mots-cles C#
      using/namespace/class/struct/interface/enum/delegate/event/
      async/await/yield/var/dynamic/is/as/new/override/virtual/
      abstract/sealed/partial/readonly/ref/out/in/params/
      get/set/value/where/select/from/orderby/group/into/join/let),
      parseur C# (classes, interfaces, structs, enums, proprietes,
      attributs, namespaces, using directives, expressions LINQ,
      async/await, try/catch/finally, foreach, lock),
      detection des fichiers .cs,
      integration dans database create avec --language=csharp.
      [IMPLEMENTE]
}

Program CODEQL;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}
{$I-}

Uses Dos;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  CODEQL_VERSION = '1.0';
  CODEQL_DATE    = '2026-03-21';

  MAX_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ERRORS = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_NODES  = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_TYPES  = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_SRC_NODES = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_DB_ROWS   = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};
  MAX_DB_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_QL_CLASSES = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_QL_PREDS   = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_BINDINGS   = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_RESULT_COLS = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_RESULT_ROWS = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_CFG_NODES   = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};
  MAX_CFG_EDGES   = {$IFDEF FPC}16384{$ELSE}2048{$ENDIF};
  MAX_DF_VARS     = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_DF_DEFS     = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_DF_USES     = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_DF_BITS     = {$IFDEF FPC}256{$ELSE}32{$ENDIF};  { taille du bitset en octets = MAX_DF_DEFS/8 }
  MAX_DF_CHAINS   = {$IFDEF FPC}8192{$ELSE}1024{$ENDIF};
  MAX_TAINT_SRCS  = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TAINT_SINKS = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TAINT_STEPS = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_TAINT_ALERTS= {$IFDEF FPC}256{$ELSE}32{$ENDIF};

  { TODO 15 : Fonctions d agregation }
  MAX_AGGR_GROUPS = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_ORDER_BY    = {$IFDEF FPC}8{$ELSE}4{$ENDIF};

  { TODO 16 : Requetes recursives }
  MAX_REC_PREDS   = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_REC_DEPS    = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_REC_STRATA  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_REC_ITERS   = {$IFDEF FPC}1000{$ELSE}100{$ENDIF};

  { TODO 17 : Requetes de securite integrees }
  MAX_SEC_ALERTS  = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_SEC_LEAKS   = {$IFDEF FPC}256{$ELSE}32{$ENDIF};

  { TODO 19 : Sortie CSV / Text }
  CSV_PAGE_SIZE   = {$IFDEF FPC}50{$ELSE}20{$ENDIF};
  TEXT_COL_MIN    = 6;     { largeur minimale d une colonne texte  }
  TEXT_COL_MAX    = 40;    { largeur maximale d une colonne texte  }

  { TODO 20 : Systeme d import et de modules QL }
  MAX_QL_MODULES  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_QL_IMPORTS  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};

  { TODO 21 : Bibliotheque standard de predicats QL }
  MAX_STDLIB_PREDS = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  STDLIB_NUM_CLASSES = 10;  { Element,Locatable,Expr,Stmt,Function,Variable,Type,Call,Access,Comment }

  { TODO 22 : codeql database create }
  MAX_SRC_FILES = {$IFDEF FPC}256{$ELSE}32{$ENDIF};

  { TODO 23 : codeql database analyze }
  MAX_SUITE_QUERIES = {$IFDEF FPC}64{$ELSE}16{$ENDIF};

  { TODO 24 : codeql query run - mode REPL }
  MAX_REPL_LINE    = 255;     { longueur max d une ligne REPL        }
  REPL_PROMPT      = 'ql> ';  { invite de commande REPL              }
  REPL_TMPFILE     = '_repl_tmp.ql'; { fichier temporaire REPL       }

  { TODO 25 : repertoire des exemples }
  SAMPLES_DIR      = 'SAMPLES';
  NUM_SAMPLE_QUERIES = 10;    { nombre de requetes exemples          }

  { TODO 8 : Noms de fichiers des tables sur disque }
  DB_SIGNATURE  = $51444243;  { signature 'QBDC' en little-endian  }
  DB_VERSION    = 1;          { version du format binaire           }
  DB_FILE_PROGRAMS  = 'programs.dat';
  DB_FILE_FILES     = 'files.dat';
  DB_FILE_LOCATIONS = 'locations.dat';
  DB_FILE_EXPRS     = 'exprs.dat';
  DB_FILE_STMTS     = 'stmts.dat';
  DB_FILE_FUNCTIONS = 'functions.dat';
  DB_FILE_VARIABLES = 'variables.dat';
  DB_FILE_TYPES     = 'types.dat';
  DB_FILE_CALLS     = 'calls.dat';
  DB_FILE_ACCESSES  = 'accesses.dat';
  DB_FILE_COMMENTS  = 'comments.dat';
  DB_FILE_DIAGS     = 'diagnostics.dat';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { TODO 1 : Sous-commandes CodeQL }
  TSubCommand = (
    CMD_NONE,
    CMD_DATABASE_CREATE,
    CMD_DATABASE_ANALYZE,
    CMD_QUERY_RUN,
    CMD_DB_INTERPRET_RESULTS,
    CMD_GENERATE_SAMPLES
  );

  { TODO 1 : Formats de sortie }
  TOutputFormat = (
    FMT_SARIF,
    FMT_CSV,
    FMT_TEXT
  );

  { TODO 1 : Options de la ligne de commande }
  TOptions = Record
    SubCmd       : TSubCommand;  { sous-commande active               }
    Verbose      : Boolean;      { -v : banniere et messages verbeux  }
    DebugMode    : Boolean;      { -d : affichage de debug            }
    SearchPath   : TString;      { --search-path : chemin QL libs     }
    Format       : TOutputFormat;{ --format : sarif, csv, text        }
    DatabasePath : TString;      { chemin vers le repertoire de la BD }
    QueryFile    : TString;      { fichier .ql ou .qls                }
    SourceDir    : TString;      { repertoire source pour db create   }
    OutputFile   : TString;      { fichier de sortie des resultats    }
    Language     : TString;      { --language : langage source        }
    Interactive  : Boolean;      { --interactive : mode REPL          }
  End;

  { TODO 2 : Tokens du langage QL }
  TTokenKind = (
    TK_EOF,          { fin de fichier                         }
    TK_INTEGER,      { literal entier 42 0xFF                 }
    TK_FLOAT,        { literal flottant 3.14 1.5e3            }
    TK_STRING,       { literal chaine "abc"                   }
    TK_IDENT,        { identificateur (non-mot-cle)           }
    TK_KEYWORD,      { mot-cle QL reconnu                     }
    TK_OP,           { operateur + - * / = != < > etc.        }
    TK_PUNCT,        { ponctuation , ( ) : . | etc.           }
    TK_COMMENT,      { commentaire // ou /* */                }
    TK_ANNOTATION    { annotation @kind @description etc.     }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute              }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)         }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)         }
    Line     : Integer;     { ligne source (1-base)               }
    Col      : Integer;     { colonne source (1-base)             }
  End;

  { TODO 3 : Noeuds de l arbre syntaxique abstrait (AST) QL }
  TNodeKind = (
    NK_NONE,            { noeud vide / non utilise              }
    NK_MODULE,          { module QL (fichier racine)            }
    NK_IMPORT,          { declaration import                    }
    NK_CLASS_DECL,      { declaration de classe                 }
    NK_PRED_DECL,       { declaration de predicat               }
    NK_SELECT,          { expression select-from-where          }
    NK_FROM_DECL,       { declaration from (type var)           }
    NK_VAR_DECL,        { declaration de variable typee         }
    NK_FORMULA_AND,     { conjonction (and)                     }
    NK_FORMULA_OR,      { disjonction (or)                      }
    NK_FORMULA_NOT,     { negation (not)                        }
    NK_FORMULA_IMPLIES, { implication (implies)                 }
    NK_FORMULA_EXISTS,  { quantificateur exists                 }
    NK_FORMULA_FORALL,  { quantificateur forall                 }
    NK_FORMULA_IF,      { formule if-then-else                  }
    NK_EXPR_CALL,       { appel predicat/methode f(...)         }
    NK_EXPR_MEMBER,     { acces membre obj.field                }
    NK_EXPR_BINOP,      { operation binaire + - * / = != < >    }
    NK_EXPR_UNOP,       { operation unaire - not                }
    NK_EXPR_IDENT,      { reference a un identificateur         }
    NK_EXPR_INT,        { literal entier                        }
    NK_EXPR_FLOAT,      { literal flottant                      }
    NK_EXPR_STRING,     { literal chaine                        }
    NK_EXPR_THIS,       { reference this                        }
    NK_EXPR_SUPER,      { reference super                       }
    NK_EXPR_RESULT,     { reference result                      }
    NK_EXPR_INSTANCEOF, { test instanceof                       }
    NK_EXPR_IN,         { test d appartenance (in)              }
    NK_EXPR_RANGE,      { intervalle a..b                       }
    NK_EXPR_AGGR,       { agregation count/any/none             }
    NK_ANNOTATION       { annotation @kind etc.                 }
  );

  TASTNode = Record
    Kind     : TNodeKind;   { type du noeud                      }
    Name     : TString;     { nom (ident, operateur, valeur)     }
    IntVal   : LongInt;     { valeur entiere (NK_EXPR_INT)       }
    FloatVal : Real;        { valeur flottante (NK_EXPR_FLOAT)   }
    Line     : Integer;     { ligne source                       }
    Col      : Integer;     { colonne source                     }
    Left     : Integer;     { enfant gauche  (-1 = aucun)        }
    Right    : Integer;     { enfant droit   (-1 = aucun)        }
    Extra    : Integer;     { enfant extra   (-1 = aucun)        }
    Next     : Integer;     { frere suivant  (-1 = aucun)        }
    TypeIdx  : Integer;     { index type resolu (-1 = inconnu)   }
  End;

  { TODO 4 : Systeme de types du langage QL }
  TQLTypeKind = (
    QTK_NONE,        { type non resolu / inconnu               }
    QTK_INT,         { type primitif int                       }
    QTK_FLOAT,       { type primitif float                     }
    QTK_STRING,      { type primitif string                    }
    QTK_BOOLEAN,     { type primitif boolean                   }
    QTK_DATE,        { type primitif date                      }
    QTK_VOID,        { type void (predicat sans resultat)      }
    QTK_LOCATABLE,   { reference @locatable (noeud source)     }
    QTK_EXPR,        { reference @expr (expression source)     }
    QTK_STMT,        { reference @stmt (instruction source)    }
    QTK_FUNCTION,    { reference @function (fonction source)   }
    QTK_CLASS,       { reference @class (classe source)        }
    QTK_VARIABLE,    { reference @variable (variable source)   }
    QTK_TYPE,        { reference @type (type source)           }
    QTK_USER         { type defini par l utilisateur (classe)  }
  );

  TQLType = Record
    Kind     : TQLTypeKind;  { categorie du type                 }
    Name     : TString;      { nom du type (int, string, etc.)   }
    BaseType : Integer;      { index du type parent (-1 = aucun) }
    IsRef    : Boolean;      { True si type reference (@...)     }
  End;

  { TODO 5 : Tokens du langage source Pascal }
  TSourceTokenKind = (
    STK_EOF,         { fin de fichier                         }
    STK_INTEGER,     { literal entier 42 $FF                  }
    STK_FLOAT,       { literal flottant 3.14 1.5e3            }
    STK_STRING,      { literal chaine 'abc'                   }
    STK_IDENT,       { identificateur (non-mot-cle)           }
    STK_KEYWORD,     { mot-cle Pascal reconnu                 }
    STK_OP,          { operateur + - * / := = <> < > etc.     }
    STK_PUNCT,       { ponctuation , ( ) : ; . [ ] ^          }
    STK_COMMENT,     (* commentaire accolades, paren-etoile, // *)
    STK_DIRECTIVE    (* directive de compilation $...           *)
  );

  TSourceToken = Record
    Kind     : TSourceTokenKind;
    Val      : TString;     { valeur textuelle brute              }
    IntVal   : LongInt;     { valeur entiere (STK_INTEGER)        }
    FloatVal : Real;        { valeur flottante (STK_FLOAT)        }
    Line     : Integer;     { ligne source (1-base)               }
    Col      : Integer;     { colonne source (1-base)             }
  End;

  { TODO 6 : Noeuds de l AST source Pascal }
  TSrcNodeKind = (
    SNK_NONE,
    SNK_PROGRAM, SNK_UNIT, SNK_USES, SNK_USES_ITEM,
    SNK_CONST_DECL, SNK_TYPE_DECL, SNK_VAR_DECL, SNK_PARAM_DECL,
    SNK_PROC_DECL, SNK_FUNC_DECL, SNK_BLOCK,
    SNK_ASSIGN, SNK_CALL, SNK_IF, SNK_WHILE, SNK_FOR, SNK_REPEAT,
    SNK_CASE, SNK_CASE_ITEM, SNK_WITH, SNK_TRY, SNK_EXCEPT,
    SNK_FINALLY, SNK_RAISE, SNK_GOTO, SNK_LABEL_DECL, SNK_COMPOUND,
    SNK_EXPR_BINOP, SNK_EXPR_UNOP, SNK_EXPR_INT, SNK_EXPR_FLOAT,
    SNK_EXPR_STRING, SNK_EXPR_IDENT, SNK_EXPR_CALL, SNK_EXPR_INDEX,
    SNK_EXPR_FIELD, SNK_EXPR_DEREF, SNK_EXPR_ADDR, SNK_EXPR_NIL,
    SNK_EXPR_SET, SNK_EXPR_RANGE,
    SNK_TYPE_IDENT, SNK_TYPE_ARRAY, SNK_TYPE_RECORD, SNK_TYPE_POINTER,
    SNK_TYPE_SET, SNK_TYPE_FILE, SNK_TYPE_RANGE, SNK_TYPE_ENUM,
    SNK_TYPE_STRING, SNK_FIELD_DECL, SNK_RECORD_SECTION,
    SNK_C_TRANSLATION_UNIT, SNK_C_INCLUDE, SNK_C_DEFINE,
    SNK_C_STRUCT_DECL, SNK_C_UNION_DECL, SNK_C_ENUM_DECL,
    SNK_C_TYPEDEF, SNK_C_DO_WHILE, SNK_C_SWITCH,
    SNK_C_CASE_ITEM, SNK_C_DEFAULT_ITEM, SNK_C_BREAK,
    SNK_C_CONTINUE, SNK_C_RETURN, SNK_C_SIZEOF,
    SNK_C_CAST, SNK_C_TERNARY, SNK_C_PREPROC,
    SNK_CPP_TRANSLATION_UNIT, SNK_CPP_CLASS_DECL,
    SNK_CPP_NAMESPACE, SNK_CPP_TEMPLATE,
    SNK_CPP_ACCESS_SPEC, SNK_CPP_TRY, SNK_CPP_CATCH,
    SNK_CPP_THROW, SNK_CPP_NEW, SNK_CPP_DELETE,
    SNK_CPP_USING, SNK_CPP_SCOPE_RES,
    SNK_CSHARP_TRANSLATION_UNIT, SNK_CSHARP_CLASS_DECL,
    SNK_CSHARP_INTERFACE_DECL, SNK_CSHARP_STRUCT_DECL,
    SNK_CSHARP_ENUM_DECL, SNK_CSHARP_DELEGATE_DECL,
    SNK_CSHARP_NAMESPACE, SNK_CSHARP_USING,
    SNK_CSHARP_PROPERTY, SNK_CSHARP_ATTRIBUTE,
    SNK_CSHARP_ASYNC, SNK_CSHARP_AWAIT,
    SNK_CSHARP_FOREACH, SNK_CSHARP_LOCK
  );

  TSrcASTNode = Record
    Kind     : TSrcNodeKind;
    Name     : TString;
    IntVal   : LongInt;
    FloatVal : Real;
    Line     : Integer;
    Col      : Integer;
    Left     : Integer;     { enfant gauche  (-1 = aucun) }
    Right    : Integer;     { enfant droit   (-1 = aucun) }
    Extra    : Integer;     { enfant extra   (-1 = aucun) }
    Next     : Integer;     { frere suivant  (-1 = aucun) }
  End;

  { TODO 7 : Base de donnees relationnelle CodeQL }

  { Table des programmes }
  TDbProgram = Record
    Id       : Integer;     { cle primaire                       }
    Name     : TString;     { nom du programme ou de l unite     }
    FileName : TString;     { chemin du fichier source           }
  End;

  { Table des fichiers }
  TDbFile = Record
    Id       : Integer;     { cle primaire                       }
    Name     : TString;     { chemin du fichier                  }
    NumLines : Integer;     { nombre de lignes                   }
  End;

  { Table des positions source }
  TDbLocation = Record
    Id       : Integer;     { cle primaire                       }
    FileId   : Integer;     { cle etrangere vers files           }
    StartLine: Integer;     { ligne de debut (1-base)            }
    StartCol : Integer;     { colonne de debut (1-base)          }
    EndLine  : Integer;     { ligne de fin                       }
    EndCol   : Integer;     { colonne de fin                     }
  End;

  { Sortes d expressions pour la table exprs }
  TDbExprKind = (
    DEK_NONE,      { inconnu                    }
    DEK_INT_LIT,   { litteral entier            }
    DEK_FLOAT_LIT, { litteral flottant          }
    DEK_STR_LIT,   { litteral chaine            }
    DEK_IDENT,     { reference a un ident       }
    DEK_BINOP,     { operation binaire          }
    DEK_UNOP,      { operation unaire           }
    DEK_CALL,      { appel de fonction          }
    DEK_INDEX,     { acces tableau a[i]         }
    DEK_FIELD,     { acces champ r.f            }
    DEK_DEREF,     { dereference p^             }
    DEK_ADDR,      { adresse @x                 }
    DEK_NIL,       { nil                        }
    DEK_SET,       { constructeur d ensemble    }
    DEK_RANGE      { intervalle a..b            }
  );

  { Table des expressions }
  TDbExpr = Record
    Id       : Integer;     { cle primaire                       }
    Kind     : TDbExprKind; { sorte d expression                 }
    ParentId : Integer;     { cle etrangere vers exprs/stmts     }
    LocId    : Integer;     { cle etrangere vers locations       }
    TypeId   : Integer;     { cle etrangere vers types           }
    Value    : TString;     { valeur textuelle (litteral, op)    }
  End;

  { Sortes d instructions pour la table stmts }
  TDbStmtKind = (
    DSK_NONE,      { inconnu                    }
    DSK_ASSIGN,    { affectation :=             }
    DSK_CALL,      { appel de procedure         }
    DSK_IF,        { if-then-else               }
    DSK_WHILE,     { while-do                   }
    DSK_FOR,       { for-to/downto-do           }
    DSK_REPEAT,    { repeat-until               }
    DSK_CASE,      { case-of                    }
    DSK_WITH,      { with-do                    }
    DSK_TRY,       { try-except/finally         }
    DSK_RAISE,     { raise                      }
    DSK_GOTO,      { goto                       }
    DSK_COMPOUND,  { begin-end                  }
    DSK_BLOCK      { bloc de declarations       }
  );

  { Table des instructions }
  TDbStmt = Record
    Id       : Integer;     { cle primaire                       }
    Kind     : TDbStmtKind; { sorte d instruction                }
    ParentId : Integer;     { cle etrangere vers stmts/functions }
    LocId    : Integer;     { cle etrangere vers locations       }
  End;

  { Table des fonctions et procedures }
  TDbFunction = Record
    Id          : Integer;  { cle primaire                       }
    Name        : TString;  { nom de la fonction/procedure       }
    ParentId    : Integer;  { cle etrangere vers programs/funcs  }
    LocId       : Integer;  { cle etrangere vers locations       }
    ReturnTypeId: Integer;  { cle etrangere vers types (-1=proc) }
    NumParams   : Integer;  { nombre de parametres               }
  End;

  { Table des variables }
  TDbVariable = Record
    Id       : Integer;     { cle primaire                       }
    Name     : TString;     { nom de la variable                 }
    ParentId : Integer;     { cle etrangere vers functions/progs }
    LocId    : Integer;     { cle etrangere vers locations       }
    TypeId   : Integer;     { cle etrangere vers types           }
    IsParam  : Boolean;     { True si parametre de fonction      }
  End;

  { Sortes de types pour la table types }
  TDbTypeKind = (
    DTK_NONE,      { inconnu                    }
    DTK_INTEGER,   { type entier                }
    DTK_REAL,      { type reel                  }
    DTK_STRING,    { type chaine                }
    DTK_BOOLEAN,   { type booleen               }
    DTK_CHAR,      { type caractere             }
    DTK_ARRAY,     { type tableau               }
    DTK_RECORD,    { type enregistrement        }
    DTK_POINTER,   { type pointeur              }
    DTK_SET,       { type ensemble              }
    DTK_FILE,      { type fichier               }
    DTK_ENUM,      { type enumere               }
    DTK_RANGE,     { type intervalle            }
    DTK_ALIAS,     { alias de type              }
    DTK_VOID       { type void (procedure)      }
  );

  { Table des types }
  TDbType = Record
    Id       : Integer;     { cle primaire                       }
    Name     : TString;     { nom du type                        }
    Kind     : TDbTypeKind; { sorte de type                      }
    BaseTypeId: Integer;    { cle etrangere vers types (-1=aucun)}
  End;

  { Table des appels }
  TDbCall = Record
    Id       : Integer;     { cle primaire                       }
    CallerId : Integer;     { cle etrangere vers functions       }
    TargetId : Integer;     { cle etrangere vers functions       }
    LocId    : Integer;     { cle etrangere vers locations       }
    NumArgs  : Integer;     { nombre d arguments                 }
  End;

  { Sortes d acces pour la table accesses }
  TDbAccessKind = (
    DAK_NONE,      { inconnu                    }
    DAK_READ,      { lecture de variable         }
    DAK_WRITE,     { ecriture de variable        }
    DAK_READWRITE  { lecture et ecriture (var)    }
  );

  { Table des acces aux variables }
  TDbAccess = Record
    Id       : Integer;       { cle primaire                     }
    Kind     : TDbAccessKind; { sorte d acces                    }
    ExprId   : Integer;       { cle etrangere vers exprs         }
    TargetId : Integer;       { cle etrangere vers variables     }
    LocId    : Integer;       { cle etrangere vers locations     }
  End;

  { Table des commentaires }
  TDbComment = Record
    Id       : Integer;     { cle primaire                       }
    FileId   : Integer;     { cle etrangere vers files           }
    LocId    : Integer;     { cle etrangere vers locations       }
    Text     : TString;     { contenu du commentaire             }
  End;

  { Niveaux de severite pour la table diagnostics }
  TDbSeverity = (
    DSEV_NOTE,     { note informative            }
    DSEV_WARNING,  { avertissement               }
    DSEV_ERROR     { erreur                      }
  );

  { Table des diagnostics }
  TDbDiagnostic = Record
    Id       : Integer;       { cle primaire                     }
    Severity : TDbSeverity;   { niveau de severite               }
    Message  : TString;       { message de diagnostic            }
    FileId   : Integer;       { cle etrangere vers files         }
    LocId    : Integer;       { cle etrangere vers locations     }
  End;

  { TODO 10 : Hierarchie de classes QL }

  { Drapeaux de predicat QL }
  TQLPredFlag = (
    QPF_NONE,         { predicat normal                      }
    QPF_OVERRIDE,     { surcharge un predicat parent         }
    QPF_ABSTRACT,     { predicat abstrait (pas de corps)     }
    QPF_PRIVATE,      { predicat prive                       }
    QPF_CHARACTERISTIC { predicat caracteristique            }
  );

  { Enregistrement d un predicat de classe QL }
  TQLPredInfo = Record
    Name       : TString;      { nom du predicat               }
    ClassIdx   : Integer;      { index de la classe proprietaire}
    Flag       : TQLPredFlag;  { drapeau (override, abstract)  }
    NodeIdx    : Integer;      { index dans l AST QL           }
    RetTypeIdx : Integer;      { type de retour (-1 = void)    }
    ParamCount : Integer;      { nombre de parametres          }
  End;

  { Enregistrement d une classe QL }
  TQLClassInfo = Record
    Name       : TString;      { nom de la classe              }
    TypeIdx    : Integer;      { index dans TypeTable           }
    BaseIdx    : Integer;      { index de la classe parent (-1) }
    NodeIdx    : Integer;      { index dans l AST QL           }
    IsAbstract : Boolean;      { True si classe abstraite      }
    PredStart  : Integer;      { debut des predicats dans table }
    PredCount  : Integer;      { nombre de predicats propres   }
  End;

  { TODO 11 : Moteur d evaluation des predicats QL }
  TBindingKind = (
    BK_NONE,       { valeur non initialisee     }
    BK_INT,        { valeur entiere             }
    BK_FLOAT,      { valeur flottante           }
    BK_STRING,     { valeur chaine              }
    BK_DBREF       { reference vers un enreg DB }
  );

  TBindingValue = Record
    Kind     : TBindingKind; { type de la valeur                  }
    IntVal   : LongInt;      { si BK_INT                          }
    FloatVal : Real;         { si BK_FLOAT                        }
    StrVal   : TString;      { si BK_STRING                       }
    RefTable : TString;      { nom de la table si BK_DBREF        }
    RefId    : Integer;       { id dans la table si BK_DBREF       }
  End;

  TBinding = Record
    Name  : TString;        { nom de la variable liee            }
    Value : TBindingValue;  { valeur courante                    }
  End;

  TResultTuple = Record
    Cols : Array[0..MAX_RESULT_COLS - 1] Of TBindingValue;
    NCols: Integer;         { nombre de colonnes dans ce tuple   }
  End;

  TResultSet = Record
    ColNames : Array[0..MAX_RESULT_COLS - 1] Of TString;
    Rows     : Array[0..MAX_RESULT_ROWS - 1] Of TResultTuple;
    NCols    : Integer;     { nombre de colonnes                 }
    NRows    : Integer;     { nombre de tuples                   }
  End;

  { TODO 12 : Graphe de flot de controle (CFG) }
  TCFGNodeKind = (
    CFG_ENTRY,       { point d'entree de la fonction       }
    CFG_EXIT,        { point de sortie de la fonction      }
    CFG_BLOCK,       { bloc d'instructions sequentielles   }
    CFG_BRANCH,      { branchement conditionnel (if/case)  }
    CFG_LOOP_HEAD,   { tete de boucle (while/for/repeat)   }
    CFG_LOOP_END,    { fin de boucle                       }
    CFG_TRY,         { debut bloc try                      }
    CFG_EXCEPT,      { gestionnaire d'exception            }
    CFG_FINALLY,     { bloc finally                        }
    CFG_RAISE        { levee d'exception                   }
  );

  TCFGEdgeKind = (
    CFG_EDGE_NORMAL,   { flot sequentiel normal              }
    CFG_EDGE_TRUE,     { branche vrai d'un if/while          }
    CFG_EDGE_FALSE,    { branche faux d'un if/while          }
    CFG_EDGE_EXCEPT,   { flot exceptionnel (vers except)     }
    CFG_EDGE_FINALLY,  { flot vers finally                   }
    CFG_EDGE_BACK      { arete de retour (boucle)            }
  );

  TCFGNode = Record
    Kind     : TCFGNodeKind; { type du noeud CFG                }
    ASTIndex : Integer;      { index dans SrcNodes (-1=aucun)   }
    FuncId   : Integer;      { id de la fonction proprietaire   }
    FirstEdge: Integer;      { premiere arete sortante (-1)     }
    Label_   : TString;      { etiquette descriptive            }
  End;

  TCFGEdge = Record
    Kind     : TCFGEdgeKind; { type de l'arete                  }
    Src      : Integer;      { index du noeud source            }
    Dst      : Integer;      { index du noeud destination       }
    NextEdge : Integer;      { arete suivante meme source (-1)  }
  End;

  { TODO 13 : Analyse de flot de donnees (data flow) }
  TDFBitSet = Array[0..MAX_DF_BITS - 1] Of Byte;

  TDFVarInfo = Record
    Name     : TString;      { nom de la variable                 }
    ASTIndex : Integer;      { index du noeud de declaration      }
    FuncId   : Integer;      { -1 = globale, sinon index func     }
  End;

  TDFDefInfo = Record
    VarIdx   : Integer;      { index dans DfVars                  }
    CfgNode  : Integer;      { noeud CFG contenant la definition  }
    ASTIndex : Integer;      { index du noeud AST (assign/decl)   }
    DefId    : Integer;      { identifiant unique de definition   }
  End;

  TDFUseInfo = Record
    VarIdx   : Integer;      { index dans DfVars                  }
    CfgNode  : Integer;      { noeud CFG contenant l'utilisation  }
    ASTIndex : Integer;      { index du noeud AST (expr ident)    }
    UseId    : Integer;      { identifiant unique d'utilisation   }
  End;

  TDFNodeInfo = Record
    Gen      : TDFBitSet;    { definitions generees par ce noeud  }
    Kill     : TDFBitSet;    { definitions tuees par ce noeud     }
    RDIn     : TDFBitSet;    { reaching defs en entree            }
    RDOut    : TDFBitSet;    { reaching defs en sortie            }
    LiveIn   : TDFBitSet;    { variables vivantes en entree       }
    LiveOut  : TDFBitSet;    { variables vivantes en sortie       }
    UseSet   : TDFBitSet;    { variables utilisees dans ce noeud  }
    DefSet   : TDFBitSet;    { variables definies dans ce noeud   }
  End;

  TDefUseLink = Record
    DefIdx   : Integer;      { index dans DfDefs                  }
    UseIdx   : Integer;      { index dans DfUses                  }
  End;

  { TODO 14 : Suivi de teinte (taint tracking) }
  TTaintSourceKind = (
    TSK_NONE,        { inconnu                                }
    TSK_READLN,      { ReadLn / Read : entree standard         }
    TSK_PARAMSTR,    { ParamStr : parametre de ligne commande  }
    TSK_READ_FILE,   { lecture de fichier (Read, ReadLn file)   }
    TSK_READKEY,     { ReadKey : entree clavier                }
    TSK_GETENV,      { GetEnv : variable d'environnement       }
    TSK_INPUT_PORT,  { Port / PortW : acces port               }
    TSK_RESET_REWRITE { Reset/Rewrite : ouverture fichier ext  }
  );

  TTaintSinkKind = (
    TNK_NONE,        { inconnu                                }
    TNK_WRITELN_FMT, { WriteLn/Write avec donnees non fiables  }
    TNK_EXEC,        { Exec : execution de commande            }
    TNK_ASSIGN,      { Assign : nom de fichier non fiable      }
    TNK_SQL,         { acces SQL avec donnees non fiables       }
    TNK_RENAME,      { Rename : renommage fichier non fiable   }
    TNK_ERASE,       { Erase : suppression fichier non fiable  }
    TNK_CHDIR,       { ChDir : changement repertoire           }
    TNK_MKDIR,       { MkDir : creation repertoire             }
    TNK_VAL          { Val : conversion non validee            }
  );

  TTaintSource = Record
    Kind     : TTaintSourceKind; { type de source                }
    VarIdx   : Integer;          { index variable teintee (DfVars) }
    ASTIndex : Integer;          { noeud AST de la source         }
    CfgNode  : Integer;          { noeud CFG de la source         }
    Line     : Integer;          { ligne source                   }
    Col      : Integer;          { colonne source                 }
  End;

  TTaintSink = Record
    Kind     : TTaintSinkKind;   { type de puits                  }
    ASTIndex : Integer;          { noeud AST du puits             }
    CfgNode  : Integer;          { noeud CFG du puits             }
    ArgVarIdx: Integer;          { index variable arg (-1=expr)   }
    Line     : Integer;          { ligne source                   }
    Col      : Integer;          { colonne source                 }
  End;

  TTaintFlowStep = Record
    FromVar  : Integer;          { index variable source (DfVars) }
    ToVar    : Integer;          { index variable destination     }
    CfgNode  : Integer;          { noeud CFG du transfert         }
    ASTIndex : Integer;          { noeud AST du transfert         }
    StepKind : Integer;          { 0=assign, 1=call arg, 2=expr  }
  End;

  TTaintAlert = Record
    SrcIdx   : Integer;          { index dans TaintSources        }
    SinkIdx  : Integer;          { index dans TaintSinks          }
    PathLen  : Integer;          { nombre de pas dans le chemin   }
    FirstStep: Integer;          { premier pas (TaintSteps index) }
  End;

  { TODO 15 : Fonctions d agregation QL }
  TAggrKind = (
    AGG_COUNT,         { count(...)                            }
    AGG_SUM,           { sum(...)                              }
    AGG_MIN,           { min(...)                              }
    AGG_MAX,           { max(...)                              }
    AGG_AVG,           { avg(...)                              }
    AGG_RANK,          { rank(...)                             }
    AGG_CONCAT,        { concat(...)                           }
    AGG_STRICTCOUNT,   { strictcount(...)                      }
    AGG_STRICTSUM,     { strictsum(...)                        }
    AGG_STRICTCONCAT   { strictconcat(...)                     }
  );

  TAggrAccum = Record
    Kind      : TAggrKind;  { type de l agregation               }
    IntSum    : LongInt;     { accumulateur entier (sum/count)    }
    FloatSum  : Real;        { accumulateur flottant (avg)        }
    IntMin    : LongInt;     { minimum entier                     }
    IntMax    : LongInt;     { maximum entier                     }
    StrAccum  : TString;     { accumulateur chaine (concat)       }
    Count     : LongInt;     { nombre d elements accumules        }
    HasValue  : Boolean;     { au moins une valeur accumulee ?    }
    Separator : TString;     { separateur pour concat             }
    RankPos   : LongInt;     { position courante pour rank        }
  End;

  TGroupByKey = Record
    Cols : Array[0..MAX_RESULT_COLS - 1] Of TBindingValue;
    NCols: Integer;
  End;

  TOrderByEntry = Record
    ColIdx    : Integer;     { index de la colonne de tri         }
    Ascending : Boolean;     { True = ASC, False = DESC           }
  End;

  { TODO 16 : Requetes recursives - dependances entre predicats }
  TRecPredDep = Record
    FromPred : Integer;      { index du predicat appelant (QLPreds)}
    ToPred   : Integer;      { index du predicat appele (QLPreds) }
    IsNeg    : Boolean;       { True si appel sous negation        }
  End;

  TRecSCCInfo = Record
    SCCId     : Integer;      { identifiant du composant connexe   }
    IsRecurs  : Boolean;       { True si le SCC a plus de 1 noeud
                                  ou un arc reflexif               }
  End;

  TRecStratum = Record
    Preds    : Array[0..MAX_REC_PREDS - 1] Of Integer; { indices QLPreds }
    PredCnt  : Integer;       { nombre de predicats dans cette strate }
    Level    : Integer;       { niveau de stratification (0 = base)  }
    HasNeg   : Boolean;        { True si strate contient negation     }
  End;

  TRecFixPoint = Record
    PredIdx  : Integer;       { index du predicat dans QLPreds       }
    OldRows  : Integer;       { nombre de tuples a l iteration N-1   }
    NewRows  : Integer;       { nombre de tuples a l iteration N     }
    Stable   : Boolean;        { True si OldRows = NewRows            }
  End;

  { TODO 17 : Requetes de securite integrees pour Pascal }
  TSecQueryKind = (
    SQK_NONE,            { inconnu                                 }
    SQK_CMD_INJECTION,   { injection de commandes (Exec)            }
    SQK_BUFFER_OVERFLOW, { debordement de tampon (index tableau)    }
    SQK_RESOURCE_LEAK,   { fuite de ressources (fichier non ferme)  }
    SQK_UNINIT_VAR       { utilisation de variable non initialisee  }
  );

  TSecAlert = Record
    Kind     : TSecQueryKind; { type de la requete de securite       }
    ASTIndex : Integer;       { noeud AST concerne                   }
    VarIdx   : Integer;       { index de la variable (DfVars) ou -1  }
    Line     : Integer;       { ligne source                         }
    Col      : Integer;       { colonne source                       }
    Message  : TString;       { message descriptif                   }
    Severity : TDbSeverity;   { niveau de severite                   }
  End;

  TSecResLeak = Record
    VarIdx   : Integer;       { index de la variable fichier         }
    OpenAST  : Integer;       { noeud AST de l ouverture (Reset/Rw)  }
    CloseAST : Integer;       { noeud AST de la fermeture (-1=absent)}
    OpenLine : Integer;       { ligne de l ouverture                 }
    FuncIdx  : Integer;       { index de la fonction englobante      }
  End;

  { TODO 20 : Systeme d import et de modules QL }
  TQLImportStatus = (
    IMS_PENDING,     { import non encore resolu                }
    IMS_RESOLVED,    { import resolu avec succes               }
    IMS_NOT_FOUND,   { fichier ou module introuvable           }
    IMS_ERROR        { erreur de chargement                    }
  );

  TQLImport = Record
    Path       : TString;        { chemin d import brut (ex: semmle.code.pascal) }
    Alias      : TString;        { alias optionnel (import X as Y)               }
    ResolvedPath : TString;      { chemin resolu sur disque                       }
    ModuleIdx  : Integer;        { index du module cible (-1 = non resolu)        }
    Status     : TQLImportStatus;{ etat de la resolution                          }
    ASTNodeIdx : Integer;        { index du noeud NK_IMPORT dans l AST            }
  End;

  TQLModule = Record
    Name       : TString;        { nom complet du module (ex: semmle.code.pascal) }
    ShortName  : TString;        { nom court (dernier segment : pascal)            }
    FilePath   : TString;        { chemin du fichier .ql sur disque                }
    ParentIdx  : Integer;        { index du module parent (-1 = racine)            }
    FirstChild : Integer;        { premier sous-module (-1 = aucun)                }
    NextSibling: Integer;        { module frere suivant (-1 = aucun)               }
    ImportStart: Integer;        { premier import dans QLImports[] pour ce module  }
    ImportCount: Integer;        { nombre d imports du module                      }
    Loaded     : Boolean;        { True si le contenu a ete charge/parse           }
  End;

  { TODO 21 : Bibliotheque standard de predicats QL }
  TStdPredKind = (
    SPK_NONE,                { inconnu                             }
    SPK_HAS_NAME,            { hasName(name) : boolean             }
    SPK_GET_TYPE,            { getType() : Type                    }
    SPK_GET_A_CHILD,         { getAChild() : Element               }
    SPK_GET_LOCATION,        { getLocation() : Location            }
    SPK_GET_ENCLOSING_FUNC,  { getEnclosingFunction() : Function   }
    SPK_GET_AN_ARGUMENT,     { getAnArgument() : Expr              }
    SPK_GET_TARGET,          { getTarget() : Variable / Function   }
    SPK_FLOWS_TO             { flowsTo(target) : boolean           }
  );

  TStdPredInfo = Record
    Name       : TString;        { nom du predicat (ex: hasName)   }
    Kind       : TStdPredKind;   { type du predicat                }
    ClassIdx   : Integer;        { index de la classe proprietaire }
    QLPredIdx  : Integer;        { index dans QLPreds[]            }
  End;

Var
  Opts       : TOptions;
  ErrorCount : Integer;
  WarnCount  : Integer;

  { Lexeur QL (TODO 2) }
  LexSrcF    : Text;        { handle du fichier source QL        }
  LexOpened  : Boolean;      { fichier ouvert ?                   }
  LexLine    : TString;     { ligne courante                     }
  LexLineNo  : Integer;     { numero de ligne courante           }
  LexColNo   : Integer;     { colonne courante dans LexLine      }
  LexEOF     : Boolean;     { fin de fichier atteinte ?          }
  CurToken   : TToken;      { token courant                      }
  TokenCount : LongInt;     { nombre total de tokens produits    }
  TotalLines : LongInt;     { nombre total de lignes lues        }

  { AST QL (TODO 3) }
  Nodes      : Array[0..MAX_NODES - 1] Of TASTNode;
  NodeCount  : Integer;      { nombre de noeuds alloues           }
  RootNode   : Integer;      { index du noeud racine (module)     }

  { Systeme de types QL (TODO 4) }
  TypeTable  : Array[0..MAX_TYPES - 1] Of TQLType;
  TypeCount  : Integer;      { nombre de types enregistres        }
  TypeErrors : Integer;      { nombre d erreurs de type           }

  { Lexeur source Pascal (TODO 5) }
  SrcLexF      : Text;        { handle du fichier source Pascal    }
  SrcLexOpened : Boolean;      { fichier ouvert ?                   }
  SrcLine      : TString;     { ligne courante                     }
  SrcLineNo    : Integer;     { numero de ligne courante           }
  SrcColNo     : Integer;     { colonne courante dans SrcLine      }
  SrcEOF       : Boolean;     { fin de fichier atteinte ?          }
  SrcToken     : TSourceToken; { token courant                     }
  SrcTokenCount: LongInt;     { nombre total de tokens produits    }
  SrcTotalLines: LongInt;     { nombre total de lignes lues        }

  { Parser source Pascal (TODO 6) }
  SrcNodes     : Array[0..MAX_SRC_NODES - 1] Of TSrcASTNode;
  SrcNodeCount : Integer;
  SrcRootNode  : Integer;

  { Base de donnees relationnelle (TODO 7) }
  DbPrograms   : Array[0..MAX_DB_ROWS - 1] Of TDbProgram;
  DbProgramCnt : Integer;
  DbFiles      : Array[0..MAX_DB_ROWS - 1] Of TDbFile;
  DbFileCnt    : Integer;
  DbLocations  : Array[0..MAX_DB_ROWS - 1] Of TDbLocation;
  DbLocationCnt: Integer;
  DbExprs      : Array[0..MAX_DB_ROWS - 1] Of TDbExpr;
  DbExprCnt    : Integer;
  DbStmts      : Array[0..MAX_DB_ROWS - 1] Of TDbStmt;
  DbStmtCnt    : Integer;
  DbFunctions  : Array[0..MAX_DB_ROWS - 1] Of TDbFunction;
  DbFunctionCnt: Integer;
  DbVariables  : Array[0..MAX_DB_ROWS - 1] Of TDbVariable;
  DbVariableCnt: Integer;
  DbTypes      : Array[0..MAX_DB_ROWS - 1] Of TDbType;
  DbTypeCnt    : Integer;
  DbCalls      : Array[0..MAX_DB_ROWS - 1] Of TDbCall;
  DbCallCnt    : Integer;
  DbAccesses   : Array[0..MAX_DB_ROWS - 1] Of TDbAccess;
  DbAccessCnt  : Integer;
  DbComments   : Array[0..MAX_DB_ROWS - 1] Of TDbComment;
  DbCommentCnt : Integer;
  DbDiags      : Array[0..MAX_DB_ROWS - 1] Of TDbDiagnostic;
  DbDiagCnt    : Integer;

  { Hierarchie de classes QL (TODO 10) }
  QLClasses    : Array[0..MAX_QL_CLASSES - 1] Of TQLClassInfo;
  QLClassCount : Integer;
  QLPreds      : Array[0..MAX_QL_PREDS - 1] Of TQLPredInfo;
  QLPredCount  : Integer;

  { Moteur d evaluation QL (TODO 11) }
  EvalBindings  : Array[0..MAX_BINDINGS - 1] Of TBinding;
  EvalBindCount : Integer;
  EvalResults   : TResultSet;

  { Graphe de flot de controle (TODO 12) }
  CfgNodes     : Array[0..MAX_CFG_NODES - 1] Of TCFGNode;
  CfgNodeCount : Integer;
  CfgEdges     : Array[0..MAX_CFG_EDGES - 1] Of TCFGEdge;
  CfgEdgeCount : Integer;

  { Analyse de flot de donnees (TODO 13) }
  DfVars       : Array[0..MAX_DF_VARS - 1] Of TDFVarInfo;
  DfVarCount   : Integer;
  DfDefs       : Array[0..MAX_DF_DEFS - 1] Of TDFDefInfo;
  DfDefCount   : Integer;
  DfUses       : Array[0..MAX_DF_USES - 1] Of TDFUseInfo;
  DfUseCount   : Integer;
  DfNodeInfo   : Array[0..MAX_CFG_NODES - 1] Of TDFNodeInfo;
  DfChains     : Array[0..MAX_DF_CHAINS - 1] Of TDefUseLink;
  DfChainCount : Integer;

  { Suivi de teinte (TODO 14) }
  TaintSources  : Array[0..MAX_TAINT_SRCS - 1] Of TTaintSource;
  TaintSrcCount : Integer;
  TaintSinks    : Array[0..MAX_TAINT_SINKS - 1] Of TTaintSink;
  TaintSinkCount: Integer;
  TaintSteps    : Array[0..MAX_TAINT_STEPS - 1] Of TTaintFlowStep;
  TaintStepCount: Integer;
  TaintAlerts   : Array[0..MAX_TAINT_ALERTS - 1] Of TTaintAlert;
  TaintAlertCount: Integer;
  TaintVarState : Array[0..MAX_DF_VARS - 1] Of Boolean; { variable teintee? }

  { Fonctions d agregation (TODO 15) }
  AggrAccums   : Array[0..MAX_AGGR_GROUPS - 1] Of TAggrAccum;
  AggrGroupCnt : Integer;
  AggrGroupKeys: Array[0..MAX_AGGR_GROUPS - 1] Of TGroupByKey;
  OrderByCols  : Array[0..MAX_ORDER_BY - 1] Of TOrderByEntry;
  OrderByCount : Integer;
  GroupByExprs : Array[0..MAX_ORDER_BY - 1] Of Integer;
  GroupByCount : Integer;

  { Requetes recursives (TODO 16) }
  RecDeps      : Array[0..MAX_REC_DEPS - 1] Of TRecPredDep;
  RecDepCount  : Integer;
  RecSCCs      : Array[0..MAX_REC_PREDS - 1] Of TRecSCCInfo;
  RecSCCCount  : Integer;
  RecStrata    : Array[0..MAX_REC_STRATA - 1] Of TRecStratum;
  RecStrataCnt : Integer;
  RecFP        : Array[0..MAX_REC_PREDS - 1] Of TRecFixPoint;
  RecFPCount   : Integer;
  RecTotalIter : Integer;
  RecPredSCC   : Array[0..MAX_REC_PREDS - 1] Of Integer; { SCC id par pred }

  { Requetes de securite (TODO 17) }
  SecAlerts     : Array[0..MAX_SEC_ALERTS - 1] Of TSecAlert;
  SecAlertCount : Integer;
  SecLeaks      : Array[0..MAX_SEC_LEAKS - 1] Of TSecResLeak;
  SecLeakCount  : Integer;

  { Systeme d import et de modules QL (TODO 20) }
  QLModules    : Array[0..MAX_QL_MODULES - 1] Of TQLModule;
  QLModuleCount: Integer;
  QLImports    : Array[0..MAX_QL_IMPORTS - 1] Of TQLImport;
  QLImportCount: Integer;

  { Bibliotheque standard QL (TODO 21) }
  StdPreds      : Array[0..MAX_STDLIB_PREDS - 1] Of TStdPredInfo;
  StdPredCount  : Integer;
  StdLibBuilt   : Boolean;    { True apres BuildStdLibrary }

  { Liste de fichiers sources a extraire (TODO 22) }
  SrcFileList   : Array[0..MAX_SRC_FILES - 1] Of TString;
  SrcFileCount  : Integer;

  { Liste de requetes d une suite (TODO 23) }
  SuiteQueries  : Array[0..MAX_SUITE_QUERIES - 1] Of TString;
  SuiteQueryCount : Integer;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Conversion en minuscules ------------------------------ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

{ ---- Messages d erreur et d avertissement ------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CODEQL: FATAL: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('CODEQL: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('CODEQL v', CODEQL_VERSION, ' (', CODEQL_DATE, ')');
  WriteLn('Clone CodeQL - Analyse statique de code Pascal');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

{ ---- Aide en ligne ----------------------------------------- }

Procedure ShowUsage;
Begin
  WriteLn('Usage: CODEQL <commande> [options]');
  WriteLn;
  WriteLn('Commandes :');
  WriteLn('  database create   <db> --source-root=<dir> [--language=pascal|c|cpp|csharp]');
  WriteLn('  database analyze  <db> [suite.qls] [--format=sarif|csv|text]');
  WriteLn('  query run         --database=<db> <query.ql> [--interactive]');
  WriteLn('  database interpret-results <db> [--format=sarif|csv|text]');
  WriteLn('  generate samples  [<dir>]');
  WriteLn;
  WriteLn('Options globales :');
  WriteLn('  -v, --verbose       Mode verbeux');
  WriteLn('  -d                  Mode debug');
  WriteLn('  -h, --help          Afficher cette aide');
  WriteLn('  --search-path=<p>   Chemin vers les bibliotheques QL');
  WriteLn('  --format=<fmt>      Format de sortie : sarif, csv, text');
  WriteLn('  --output=<file>     Fichier de sortie des resultats');
  WriteLn('  --interactive       Mode REPL (query run)');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  CODEQL database create mydb --source-root=src');
  WriteLn('  CODEQL database analyze mydb security.qls --format=sarif');
  WriteLn('  CODEQL query run --database=mydb find_bugs.ql');
  WriteLn('  CODEQL query run --database=mydb --interactive');
  WriteLn('  CODEQL generate samples');
  WriteLn;
  Halt(EXIT_USAGE);
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SubCmd       := CMD_NONE;
  Opts.Verbose      := False;
  Opts.DebugMode    := False;
  Opts.SearchPath   := '';
  Opts.Format       := FMT_SARIF;
  Opts.DatabasePath := '';
  Opts.QueryFile    := '';
  Opts.SourceDir    := '';
  Opts.OutputFile   := '';
  Opts.Language     := 'pascal';
  Opts.Interactive  := False;
  ErrorCount        := 0;
  WarnCount         := 0;
End;

{ ---- Verifie si S commence par Prefix ---------------------- }

Function StartsWith(Const S, Prefix : TString) : Boolean;
Begin
  If Length(Prefix) > Length(S) Then
    StartsWith := False
  Else
    StartsWith := (Copy(S, 1, Length(Prefix)) = Prefix);
End;

{ ---- Extrait la valeur apres le signe = -------------------- }

Function ExtractValue(Const S : TString) : TString;
Var
  P : Integer;
Begin
  P := Pos('=', S);
  If P > 0 Then
    ExtractValue := Copy(S, P + 1, Length(S) - P)
  Else
    ExtractValue := '';
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I     : Integer;
  Arg   : TString;
  LArg  : TString;
  Val   : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg  := ParamStr(I);
    LArg := StrLowerCase(Arg);

    { Options globales }
    If (LArg = '-h') Or (LArg = '--help') Or (LArg = '/?') Then
      ShowUsage
    Else If (LArg = '-v') Or (LArg = '--verbose') Then
      Opts.Verbose := True
    Else If LArg = '-d' Then
      Opts.DebugMode := True
    Else If LArg = '--interactive' Then
      Opts.Interactive := True
    Else If StartsWith(LArg, '--search-path=') Then
      Opts.SearchPath := ExtractValue(Arg)
    Else If StartsWith(LArg, '--format=') Then
    Begin
      Val := StrLowerCase(ExtractValue(Arg));
      If Val = 'sarif' Then
        Opts.Format := FMT_SARIF
      Else If Val = 'csv' Then
        Opts.Format := FMT_CSV
      Else If Val = 'text' Then
        Opts.Format := FMT_TEXT
      Else
      Begin
        WriteLn('CODEQL: format inconnu: ', Val);
        ShowUsage;
      End;
    End
    Else If StartsWith(LArg, '--output=') Then
      Opts.OutputFile := ExtractValue(Arg)
    Else If StartsWith(LArg, '--source-root=') Then
      Opts.SourceDir := ExtractValue(Arg)
    Else If StartsWith(LArg, '--language=') Then
      Opts.Language := StrLowerCase(ExtractValue(Arg))
    Else If StartsWith(LArg, '--database=') Then
      Opts.DatabasePath := ExtractValue(Arg)

    { Sous-commande : database }
    Else If (LArg = 'database') And (Opts.SubCmd = CMD_NONE) Then
    Begin
      Inc(I);
      If I > ParamCount Then
      Begin
        WriteLn('CODEQL: sous-commande database incomplete');
        ShowUsage;
      End;
      Val := StrLowerCase(ParamStr(I));
      If Val = 'create' Then
        Opts.SubCmd := CMD_DATABASE_CREATE
      Else If Val = 'analyze' Then
        Opts.SubCmd := CMD_DATABASE_ANALYZE
      Else If Val = 'interpret-results' Then
        Opts.SubCmd := CMD_DB_INTERPRET_RESULTS
      Else
      Begin
        WriteLn('CODEQL: sous-commande database inconnue: ', ParamStr(I));
        ShowUsage;
      End;
    End

    { Sous-commande : query }
    Else If (LArg = 'query') And (Opts.SubCmd = CMD_NONE) Then
    Begin
      Inc(I);
      If I > ParamCount Then
      Begin
        WriteLn('CODEQL: sous-commande query incomplete');
        ShowUsage;
      End;
      Val := StrLowerCase(ParamStr(I));
      If Val = 'run' Then
        Opts.SubCmd := CMD_QUERY_RUN
      Else
      Begin
        WriteLn('CODEQL: sous-commande query inconnue: ', ParamStr(I));
        ShowUsage;
      End;
    End

    { Sous-commande : generate }
    Else If (LArg = 'generate') And (Opts.SubCmd = CMD_NONE) Then
    Begin
      Inc(I);
      If I > ParamCount Then
      Begin
        WriteLn('CODEQL: sous-commande generate incomplete');
        ShowUsage;
      End;
      Val := StrLowerCase(ParamStr(I));
      If Val = 'samples' Then
        Opts.SubCmd := CMD_GENERATE_SAMPLES
      Else
      Begin
        WriteLn('CODEQL: sous-commande generate inconnue: ', ParamStr(I));
        ShowUsage;
      End;
    End

    { Arguments positionnels }
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('CODEQL: option inconnue: ', Arg);
      ShowUsage;
    End
    Else
    Begin
      Case Opts.SubCmd Of
        CMD_DATABASE_CREATE,
        CMD_DATABASE_ANALYZE,
        CMD_DB_INTERPRET_RESULTS:
        Begin
          If Opts.DatabasePath = '' Then
            Opts.DatabasePath := Arg
          Else If Opts.QueryFile = '' Then
            Opts.QueryFile := Arg
          Else
          Begin
            WriteLn('CODEQL: argument inattendu: ', Arg);
            ShowUsage;
          End;
        End;
        CMD_QUERY_RUN:
        Begin
          If Opts.QueryFile = '' Then
            Opts.QueryFile := Arg
          Else
          Begin
            WriteLn('CODEQL: argument inattendu: ', Arg);
            ShowUsage;
          End;
        End;
        CMD_GENERATE_SAMPLES:
        Begin
          If Opts.OutputFile = '' Then
            Opts.OutputFile := Arg
          Else
          Begin
            WriteLn('CODEQL: argument inattendu: ', Arg);
            ShowUsage;
          End;
        End;
      Else
        WriteLn('CODEQL: commande attendue, recu: ', Arg);
        ShowUsage;
      End;
    End;

    Inc(I);
  End;

  { Validation }
  If Opts.SubCmd = CMD_NONE Then
  Begin
    WriteLn('CODEQL: aucune commande specifiee');
    ShowUsage;
  End;

  Case Opts.SubCmd Of
    CMD_DATABASE_CREATE:
    Begin
      If Opts.DatabasePath = '' Then
        FatalError('chemin de la base de donnees requis');
      If Opts.SourceDir = '' Then
        FatalError('--source-root requis pour database create');
    End;
    CMD_DATABASE_ANALYZE:
    Begin
      If Opts.DatabasePath = '' Then
        FatalError('chemin de la base de donnees requis');
    End;
    CMD_QUERY_RUN:
    Begin
      If Opts.DatabasePath = '' Then
        FatalError('--database requis pour query run');
      If (Opts.QueryFile = '') And (Not Opts.Interactive) Then
        FatalError('fichier .ql requis ou --interactive');
    End;
    CMD_DB_INTERPRET_RESULTS:
    Begin
      If Opts.DatabasePath = '' Then
        FatalError('chemin de la base de donnees requis');
    End;
    CMD_GENERATE_SAMPLES:
    Begin
      { Le repertoire de sortie est optionnel, SAMPLES par defaut }
    End;
  End;

  If (Opts.Language <> 'pascal') And (Opts.Language <> 'c') And
     (Opts.Language <> 'cpp') And (Opts.Language <> 'csharp') Then
    FatalError('langage non supporte: ' + Opts.Language + ' (pascal, c, cpp ou csharp)');
End;

{ ---- Stubs des sous-commandes (TODO 23-24) ----------------- }

{ ============================================================
  TODO 02 - LEXEUR QL (TOKENS) [IMPLEMENTE]
  ============================================================ }

{ ---- Classification de caracteres -------------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- Reconnaissance des mots-cles QL ----------------------- }

Function IsQLKeyword(Const S : TString) : Boolean;
Begin
  IsQLKeyword :=
    (S = 'select')     Or (S = 'from')      Or (S = 'where')    Or
    (S = 'import')     Or (S = 'class')     Or (S = 'extends')  Or
    (S = 'predicate')  Or (S = 'result')    Or (S = 'exists')   Or
    (S = 'forall')     Or (S = 'not')       Or (S = 'and')      Or
    (S = 'or')         Or (S = 'implies')   Or (S = 'if')       Or
    (S = 'then')       Or (S = 'else')      Or (S = 'in')       Or
    (S = 'module')     Or (S = 'override')  Or (S = 'abstract') Or
    (S = 'private')    Or (S = 'this')      Or (S = 'super')    Or
    (S = 'instanceof') Or (S = 'any')       Or (S = 'none')     Or
    (S = 'count')      Or (S = 'sum')       Or (S = 'min')      Or
    (S = 'max')        Or (S = 'avg')       Or (S = 'rank')     Or
    (S = 'concat')     Or (S = 'strictcount') Or (S = 'strictsum') Or
    (S = 'strictconcat') Or (S = 'order')   Or (S = 'by')       Or
    (S = 'group')      Or (S = 'asc')       Or (S = 'desc');
End;

{ ---- Lire la prochaine ligne source ------------------------- }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    {$I-}
    ReadLn(LexSrcF, LexLine);
    {$I+}
    If IOResult <> 0 Then
    Begin
      LexEOF   := True;
      LexLine  := '';
      LexColNo := 1;
      Exit;
    End;
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- Initialiser le lexeur ---------------------------------- }

Procedure LexInit;
Begin
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  TokenCount := 0;
  TotalLines := 0;
  CurToken.Kind     := TK_EOF;
  CurToken.Val      := '';
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line     := 0;
  CurToken.Col      := 0;
  LexNextLine;
End;

{ ---- Fermer le lexeur ---------------------------------------- }

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    {$I-}
    Close(LexSrcF);
    {$I+}
    If IOResult <> 0 Then { ignorer };
    LexOpened := False;
  End;
End;

{ ---- Scanner un identificateur ou mot-cle QL ----------------- }

Procedure LexScanIdent;
Var S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  If IsQLKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- Scanner un nombre (entier ou flottant) ------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  Ch      : Char;
  NumStr  : TString;
  IsFloat : Boolean;
  Code    : Integer;
Begin
  N       := 0;
  NumStr  := '';
  IsFloat := False;
  Ch      := LexLine[LexColNo];

  { Hexadecimal : 0x... }
  If (Ch = '0') And (LexColNo < Length(LexLine)) And
     ((LexLine[LexColNo + 1] = 'x') Or
      (LexLine[LexColNo + 1] = 'X')) Then
  Begin
    NumStr := '0x';
    Inc(LexColNo, 2);
    While (LexColNo <= Length(LexLine)) And
          IsHexDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 16 + HexVal(LexLine[LexColNo]);
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    CurToken.Kind     := TK_INTEGER;
    CurToken.Val      := NumStr;
    CurToken.IntVal   := N;
    CurToken.FloatVal := 0.0;
    Exit;
  End;

  { Decimal }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie fractionnaire .ddd }
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     IsDigit(LexLine[LexColNo + 1]) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + '.';
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Exposant E[+-]ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + LexLine[LexColNo];
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      NumStr := NumStr + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  If IsFloat Then
  Begin
    CurToken.Kind   := TK_FLOAT;
    CurToken.Val    := NumStr;
    CurToken.IntVal := N;
    Val(NumStr, CurToken.FloatVal, Code);
    If Code <> 0 Then
      CurToken.FloatVal := N;
  End
  Else
  Begin
    CurToken.Kind     := TK_INTEGER;
    CurToken.Val      := NumStr;
    CurToken.IntVal   := N;
    CurToken.FloatVal := 0.0;
  End;
End;

{ ---- Scanner une chaine entre guillemets --------------------- }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);  { sauter le guillemet ouvrant }
  While (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
      Begin
        Case LexLine[LexColNo] Of
          'n'  : If Length(S) < MAX_STR Then S := S + #10;
          't'  : If Length(S) < MAX_STR Then S := S + #9;
          'r'  : If Length(S) < MAX_STR Then S := S + #13;
          '\'  : If Length(S) < MAX_STR Then S := S + '\';
          '"'  : If Length(S) < MAX_STR Then S := S + '"';
        Else
          If Length(S) < MAX_STR Then
            S := S + LexLine[LexColNo];
        End;
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- Sauter un commentaire de ligne // ----------------------- }

Procedure LexSkipLineComment;
Var S : TString;
Begin
  S := Copy(LexLine, LexColNo + 2, Length(LexLine) - LexColNo - 1);
  CurToken.Kind := TK_COMMENT;
  CurToken.Val  := S;
  LexColNo := Length(LexLine) + 1;
End;

{ ---- Sauter un commentaire bloc /* ... */ -------------------- }

Procedure LexSkipBlockComment;
Var S : TString;
Begin
  S := '';
  Inc(LexColNo, 2);  { sauter /* }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + ' ';
      LexNextLine;
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo, 2);
      CurToken.Kind := TK_COMMENT;
      CurToken.Val  := S;
      Exit;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind := TK_COMMENT;
  CurToken.Val  := S;
End;

{ ---- Scanner une annotation @name --------------------------- }

Procedure LexScanAnnotation;
Var S : TString;
Begin
  S := '@';
  Inc(LexColNo);  { sauter le @ }
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Kind   := TK_ANNOTATION;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexNextToken : dispatcher principal du lexeur QL -------- }

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la ligne suivante si fin de ligne courante }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
      Continue;
    End;

    Scanning := False;

    { Commentaires }
    If (Ch = '/') And (LexColNo < Length(LexLine)) Then
    Begin
      If LexLine[LexColNo + 1] = '/' Then
      Begin
        LexSkipLineComment;
        Inc(TokenCount);
        Exit;
      End
      Else If LexLine[LexColNo + 1] = '*' Then
      Begin
        LexSkipBlockComment;
        Inc(TokenCount);
        Exit;
      End;
    End;

    { Chaines entre guillemets }
    If Ch = '"' Then
    Begin
      LexScanString;
      Inc(TokenCount);
      Exit;
    End;

    { Annotations @ }
    If (Ch = '@') And (LexColNo < Length(LexLine)) And
       IsIdentStart(LexLine[LexColNo + 1]) Then
    Begin
      LexScanAnnotation;
      Inc(TokenCount);
      Exit;
    End;

    { Identificateurs et mots-cles }
    If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Inc(TokenCount);
      Exit;
    End;

    { Nombres }
    If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Inc(TokenCount);
      Exit;
    End;

    { Operateurs multi-caracteres }
    If (Ch = '!') And (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '!=';
      Inc(LexColNo, 2);
      Inc(TokenCount);
      Exit;
    End;

    If (Ch = '<') And (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Inc(TokenCount);
      Exit;
    End;

    If (Ch = '>') And (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Inc(TokenCount);
      Exit;
    End;

    If (Ch = '.') And (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Inc(TokenCount);
      Exit;
    End;

    { Operateurs simples }
    If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
       (Ch = '%') Or (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or
       (Ch = '!') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(TokenCount);
      Exit;
    End;

    { Ponctuation }
    If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
       (Ch = '{') Or (Ch = '}') Or (Ch = ',') Or (Ch = ';') Or
       (Ch = ':') Or (Ch = '.') Or (Ch = '|') Or (Ch = '@') Or
       (Ch = '#') Or (Ch = '_') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(TokenCount);
      Exit;
    End;

    { Caractere inconnu : emettre comme ponctuation }
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := Ch;
    Inc(LexColNo);
    Inc(TokenCount);
  End;
End;

{ ---- Affichage debug d un token QL -------------------------- }

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF        : Write('EOF');
    TK_INTEGER    : Write('INT(', T.IntVal, ')');
    TK_FLOAT      : Write('FLOAT(', T.Val, ')');
    TK_STRING     : Write('STR("', T.Val, '")');
    TK_IDENT      : Write('IDENT(', T.Val, ')');
    TK_KEYWORD    : Write('KW(', T.Val, ')');
    TK_OP         : Write('OP(', T.Val, ')');
    TK_PUNCT      : Write('PUNCT(', T.Val, ')');
    TK_COMMENT    : Write('COMMENT(', T.Val, ')');
    TK_ANNOTATION : Write('ANNOT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ============================================================
  TODO 03 - ANALYSEUR SYNTAXIQUE QL (PARSER / AST) [IMPLEMENTE]
  ============================================================ }

{ ---- Allocation d un noeud AST ------------------------------ }

Function NewNode(Kind : TNodeKind) : Integer;
Begin
  If NodeCount >= MAX_NODES Then
    FatalError('AST: depassement MAX_NODES');
  Nodes[NodeCount].Kind     := Kind;
  Nodes[NodeCount].Name     := '';
  Nodes[NodeCount].IntVal   := 0;
  Nodes[NodeCount].FloatVal := 0.0;
  Nodes[NodeCount].Line     := CurToken.Line;
  Nodes[NodeCount].Col      := CurToken.Col;
  Nodes[NodeCount].Left     := -1;
  Nodes[NodeCount].Right    := -1;
  Nodes[NodeCount].Extra    := -1;
  Nodes[NodeCount].Next     := -1;
  Nodes[NodeCount].TypeIdx  := -1;
  NewNode := NodeCount;
  Inc(NodeCount);
End;

{ ---- Initialiser l AST -------------------------------------- }

Procedure ASTInit;
Begin
  NodeCount := 0;
  RootNode  := -1;
End;

{ ---- Avancer : consommer le prochain token non-commentaire --- }

Procedure Consume;
Begin
  Repeat
    LexNextToken;
  Until CurToken.Kind <> TK_COMMENT;
  PrintToken(CurToken);
End;

{ ---- Verifier le token courant ------------------------------ }

Function TokIs(Const S : TString) : Boolean;
Begin
  TokIs := (CurToken.Val = S);
End;

Function TokIsKw(Const S : TString) : Boolean;
Begin
  TokIsKw := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = S);
End;

Function TokIsOp(Const S : TString) : Boolean;
Begin
  TokIsOp := (CurToken.Kind = TK_OP) And (CurToken.Val = S);
End;

Function TokIsPunct(Const S : TString) : Boolean;
Begin
  TokIsPunct := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = S);
End;

{ ---- Attendre un token precis ------------------------------- }

Procedure Expect(Const S : TString);
Begin
  If CurToken.Val <> S Then
  Begin
    WriteLn('CODEQL: erreur ligne ', CurToken.Line, ' col ',
            CurToken.Col, ': attendu ''', S, ''' lu ''',
            CurToken.Val, '''');
    Inc(ErrorCount);
  End;
  Consume;
End;

{ ---- Forward declarations du parser ------------------------- }

Function ParseFormula   : Integer; Forward;
Function ParseExpr      : Integer; Forward;
Function ParsePrimary   : Integer; Forward;

{ ---- Chainer deux noeuds en liste (via Next) ---------------- }

Procedure AppendToList(Var Head : Integer; N : Integer);
Var Cur : Integer;
Begin
  If Head < 0 Then
    Head := N
  Else
  Begin
    Cur := Head;
    While Nodes[Cur].Next >= 0 Do
      Cur := Nodes[Cur].Next;
    Nodes[Cur].Next := N;
  End;
End;

{ ---- ParseImport : import <path> ---------------------------- }

Function ParseImport : Integer;
Var
  N    : Integer;
  Path : TString;
Begin
  N := NewNode(NK_IMPORT);
  Consume;  { sauter 'import' }
  Path := '';
  While (CurToken.Kind = TK_IDENT) Or TokIsPunct('.') Do
  Begin
    Path := Path + CurToken.Val;
    Consume;
  End;
  Nodes[N].Name := Path;
  ParseImport := N;
End;

{ ---- ParseVarDecl : Type varname ----------------------------- }

Function ParseVarDecl : Integer;
Var N : Integer;
    TypeName : TString;
Begin
  N := NewNode(NK_VAR_DECL);
  TypeName := CurToken.Val;
  Consume;  { type name or single name }
  { Si le token suivant est un ident, c est Type varname }
  If (CurToken.Kind = TK_IDENT) Then
  Begin
    Nodes[N].Name := CurToken.Val;
    Nodes[N].Left := NewNode(NK_EXPR_IDENT);
    Nodes[Nodes[N].Left].Name := TypeName;
    Consume;  { variable name }
  End
  Else
  Begin
    { Un seul token (ex: result) : c est juste un nom }
    Nodes[N].Name := TypeName;
  End;
  ParseVarDecl := N;
End;

{ ---- ParseExprList : liste d expressions separees par , ------ }

Function ParseExprList : Integer;
Var Head, E : Integer;
Begin
  Head := -1;
  E := ParseExpr;
  AppendToList(Head, E);
  While TokIsPunct(',') Do
  Begin
    Consume;  { sauter , }
    E := ParseExpr;
    AppendToList(Head, E);
  End;
  ParseExprList := Head;
End;

{ ---- ParsePrimary : litteraux, ident, this, appels, etc ------ }

Function ParsePrimary : Integer;
Var
  N, Args, Body, VDecl : Integer;
Begin
  { Entier }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    N := NewNode(NK_EXPR_INT);
    Nodes[N].Name   := CurToken.Val;
    Nodes[N].IntVal := CurToken.IntVal;
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { Flottant }
  If CurToken.Kind = TK_FLOAT Then
  Begin
    N := NewNode(NK_EXPR_FLOAT);
    Nodes[N].Name     := CurToken.Val;
    Nodes[N].FloatVal := CurToken.FloatVal;
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { Chaine }
  If CurToken.Kind = TK_STRING Then
  Begin
    N := NewNode(NK_EXPR_STRING);
    Nodes[N].Name := CurToken.Val;
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { this }
  If TokIsKw('this') Then
  Begin
    N := NewNode(NK_EXPR_THIS);
    Nodes[N].Name := 'this';
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { super }
  If TokIsKw('super') Then
  Begin
    N := NewNode(NK_EXPR_SUPER);
    Nodes[N].Name := 'super';
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { result }
  If TokIsKw('result') Then
  Begin
    N := NewNode(NK_EXPR_RESULT);
    Nodes[N].Name := 'result';
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { exists( Type var | formula ) }
  If TokIsKw('exists') Then
  Begin
    N := NewNode(NK_FORMULA_EXISTS);
    Consume;  { sauter exists }
    Expect('(');
    VDecl := ParseVarDecl;
    Nodes[N].Left := VDecl;
    If TokIsPunct('|') Then
      Consume;
    Body := ParseFormula;
    Nodes[N].Right := Body;
    Expect(')');
    ParsePrimary := N;
    Exit;
  End;

  { forall( Type var | formula | formula ) }
  If TokIsKw('forall') Then
  Begin
    N := NewNode(NK_FORMULA_FORALL);
    Consume;  { sauter forall }
    Expect('(');
    VDecl := ParseVarDecl;
    Nodes[N].Left := VDecl;
    If TokIsPunct('|') Then
      Consume;
    Body := ParseFormula;
    Nodes[N].Right := Body;
    If TokIsPunct('|') Then
    Begin
      Consume;
      Nodes[N].Extra := ParseFormula;
    End;
    Expect(')');
    ParsePrimary := N;
    Exit;
  End;

  { if formula then formula else formula }
  If TokIsKw('if') Then
  Begin
    N := NewNode(NK_FORMULA_IF);
    Consume;  { sauter if }
    Nodes[N].Left := ParseFormula;
    If TokIsKw('then') Then
      Consume;
    Nodes[N].Right := ParseFormula;
    If TokIsKw('else') Then
    Begin
      Consume;
      Nodes[N].Extra := ParseFormula;
    End;
    ParsePrimary := N;
    Exit;
  End;

  { count/any/none/sum/min/max/avg/rank/concat/strictcount/strictsum/strictconcat }
  If TokIsKw('count') Or TokIsKw('any') Or TokIsKw('none') Or
     TokIsKw('sum') Or TokIsKw('min') Or TokIsKw('max') Or
     TokIsKw('avg') Or TokIsKw('rank') Or TokIsKw('concat') Or
     TokIsKw('strictcount') Or TokIsKw('strictsum') Or
     TokIsKw('strictconcat') Then
  Begin
    N := NewNode(NK_EXPR_AGGR);
    Nodes[N].Name := CurToken.Val;
    Consume;
    Expect('(');
    If Not TokIsPunct(')') Then
    Begin
      { Heuristique : si IDENT suivi d'un IDENT -> Type var | formula }
      VDecl := ParseVarDecl;
      Nodes[N].Left := VDecl;
      If TokIsPunct('|') Then
      Begin
        Consume;
        Nodes[N].Right := ParseFormula;
      End;
    End;
    Expect(')');
    ParsePrimary := N;
    Exit;
  End;

  { Ensemble/range entre crochets : [expr] ou [lo..hi] }
  If TokIsPunct('[') Then
  Begin
    Consume;
    N := ParseExpr;
    If TokIsPunct(']') Then
      Consume;
    ParsePrimary := N;
    Exit;
  End;

  { Sous-expression parenthesee }
  If TokIsPunct('(') Then
  Begin
    Consume;  { sauter ( }
    N := ParseFormula;
    Expect(')');
    ParsePrimary := N;
    Exit;
  End;

  { Identificateur (eventuellement suivi de . ou () ) }
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
  Begin
    N := NewNode(NK_EXPR_IDENT);
    Nodes[N].Name := CurToken.Val;
    Consume;

    { Appel de fonction/predicat : ident( args ) }
    If TokIsPunct('(') Then
    Begin
      Consume;  { sauter ( }
      Args := -1;
      If Not TokIsPunct(')') Then
        Args := ParseExprList;
      Expect(')');
      Nodes[N].Kind := NK_EXPR_CALL;
      Nodes[N].Left := Args;
    End;

    ParsePrimary := N;
    Exit;
  End;

  { Annotation }
  If CurToken.Kind = TK_ANNOTATION Then
  Begin
    N := NewNode(NK_ANNOTATION);
    Nodes[N].Name := CurToken.Val;
    Consume;
    ParsePrimary := N;
    Exit;
  End;

  { Fallback : noeud vide }
  N := NewNode(NK_NONE);
  Nodes[N].Name := CurToken.Val;
  If CurToken.Kind <> TK_EOF Then
    Consume;
  ParsePrimary := N;
End;

{ ---- ParsePostfix : acces membre et appels de methode -------- }

Function ParsePostfix : Integer;
Var N, M, Args : Integer;
    MethName : TString;
Begin
  N := ParsePrimary;
  While TokIsPunct('.') Do
  Begin
    Consume;  { sauter . }
    MethName := '';
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      MethName := CurToken.Val;
      Consume;
    End;
    { Appel de methode : .name( args ) }
    If TokIsPunct('(') Then
    Begin
      Consume;
      Args := -1;
      If Not TokIsPunct(')') Then
        Args := ParseExprList;
      Expect(')');
      M := NewNode(NK_EXPR_CALL);
      Nodes[M].Name  := MethName;
      Nodes[M].Left  := Args;
      Nodes[M].Right := N;
    End
    Else
    Begin
      { Acces membre simple : obj.field }
      M := NewNode(NK_EXPR_MEMBER);
      Nodes[M].Name := MethName;
      Nodes[M].Left := N;
    End;
    N := M;
  End;
  ParsePostfix := N;
End;

{ ---- ParseUnary : -expr, not expr ---------------------------- }

Function ParseUnary : Integer;
Var N : Integer;
Begin
  If TokIsOp('-') Then
  Begin
    N := NewNode(NK_EXPR_UNOP);
    Nodes[N].Name := '-';
    Consume;
    Nodes[N].Left := ParseUnary;
    ParseUnary := N;
    Exit;
  End;
  If TokIsKw('not') Then
  Begin
    N := NewNode(NK_FORMULA_NOT);
    Consume;
    Nodes[N].Left := ParseUnary;
    ParseUnary := N;
    Exit;
  End;
  ParseUnary := ParsePostfix;
End;

{ ---- ParseMulDiv : expr * expr, expr / expr, expr % expr ----- }

Function ParseMulDiv : Integer;
Var N, R : Integer;
    Op   : TString;
Begin
  N := ParseUnary;
  While TokIsOp('*') Or TokIsOp('/') Or TokIsOp('%') Do
  Begin
    Op := CurToken.Val;
    Consume;
    R := NewNode(NK_EXPR_BINOP);
    Nodes[R].Name  := Op;
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseUnary;
    N := R;
  End;
  ParseMulDiv := N;
End;

{ ---- ParseAddSub : expr + expr, expr - expr ------------------ }

Function ParseAddSub : Integer;
Var N, R : Integer;
    Op   : TString;
Begin
  N := ParseMulDiv;
  While TokIsOp('+') Or TokIsOp('-') Do
  Begin
    Op := CurToken.Val;
    Consume;
    R := NewNode(NK_EXPR_BINOP);
    Nodes[R].Name  := Op;
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseMulDiv;
    N := R;
  End;
  ParseAddSub := N;
End;

{ ---- ParseRange : expr .. expr ------------------------------- }

Function ParseRange : Integer;
Var N, R : Integer;
Begin
  N := ParseAddSub;
  If TokIsOp('..') Then
  Begin
    Consume;
    R := NewNode(NK_EXPR_RANGE);
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseAddSub;
    N := R;
  End;
  ParseRange := N;
End;

{ ---- ParseComparison : expr = != < > <= >= expr -------------- }

Function ParseComparison : Integer;
Var N, R : Integer;
    Op   : TString;
Begin
  N := ParseRange;
  If TokIsOp('=') Or TokIsOp('!=') Or TokIsOp('<') Or
     TokIsOp('>') Or TokIsOp('<=') Or TokIsOp('>=') Then
  Begin
    Op := CurToken.Val;
    Consume;
    R := NewNode(NK_EXPR_BINOP);
    Nodes[R].Name  := Op;
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseRange;
    N := R;
  End;

  { instanceof }
  If TokIsKw('instanceof') Then
  Begin
    Consume;
    R := NewNode(NK_EXPR_INSTANCEOF);
    Nodes[R].Left := N;
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      Nodes[R].Name := CurToken.Val;
      Consume;
    End;
    N := R;
  End;

  { in }
  If TokIsKw('in') Then
  Begin
    Consume;
    R := NewNode(NK_EXPR_IN);
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseRange;
    N := R;
  End;

  ParseComparison := N;
End;

{ ---- ParseExpr : point d entree expression ------------------- }

Function ParseExpr : Integer;
Begin
  ParseExpr := ParseComparison;
End;

{ ---- ParseNegation : not formula ----------------------------- }

Function ParseNegation : Integer;
Var N : Integer;
Begin
  If TokIsKw('not') Then
  Begin
    N := NewNode(NK_FORMULA_NOT);
    Consume;
    Nodes[N].Left := ParseNegation;
    ParseNegation := N;
  End
  Else
    ParseNegation := ParseExpr;
End;

{ ---- ParseConjunction : formula and formula ------------------ }

Function ParseConjunction : Integer;
Var N, R : Integer;
Begin
  N := ParseNegation;
  While TokIsKw('and') Do
  Begin
    Consume;
    R := NewNode(NK_FORMULA_AND);
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseNegation;
    N := R;
  End;
  ParseConjunction := N;
End;

{ ---- ParseDisjunction : formula or formula ------------------- }

Function ParseDisjunction : Integer;
Var N, R : Integer;
Begin
  N := ParseConjunction;
  While TokIsKw('or') Do
  Begin
    Consume;
    R := NewNode(NK_FORMULA_OR);
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseConjunction;
    N := R;
  End;
  ParseDisjunction := N;
End;

{ ---- ParseImplication : formula implies formula -------------- }

Function ParseImplication : Integer;
Var N, R : Integer;
Begin
  N := ParseDisjunction;
  If TokIsKw('implies') Then
  Begin
    Consume;
    R := NewNode(NK_FORMULA_IMPLIES);
    Nodes[R].Left  := N;
    Nodes[R].Right := ParseDisjunction;
    N := R;
  End;
  ParseImplication := N;
End;

{ ---- ParseFormula : point d entree formule QL ---------------- }

Function ParseFormula : Integer;
Begin
  ParseFormula := ParseImplication;
End;

(* ---- ParsePredBody : corps de predicat (formulas) ----------- *)

Function ParsePredBody : Integer;
Var Head, F : Integer;
Begin
  Head := -1;
  If TokIsPunct('{') Then
  Begin
    Consume;  (* sauter accolade ouvrante *)
    While (Not TokIsPunct('}')) And (CurToken.Kind <> TK_EOF) Do
    Begin
      F := ParseFormula;
      AppendToList(Head, F);
    End;
    Expect('}');
  End;
  ParsePredBody := Head;
End;

(* ---- ParsePredDecl : predicate name(params) (body) ---------- *)

Function ParsePredDecl : Integer;
Var
  N, ParamList, Param, Body : Integer;
Begin
  N := NewNode(NK_PRED_DECL);
  Consume;  { sauter 'predicate' }
  Nodes[N].Name := CurToken.Val;
  Consume;  { nom du predicat }

  { Parametres }
  ParamList := -1;
  If TokIsPunct('(') Then
  Begin
    Consume;
    While (Not TokIsPunct(')')) And (CurToken.Kind <> TK_EOF) Do
    Begin
      Param := ParseVarDecl;
      AppendToList(ParamList, Param);
      If TokIsPunct(',') Then
        Consume;
    End;
    Expect(')');
  End;
  Nodes[N].Left := ParamList;

  { Corps }
  Body := ParsePredBody;
  Nodes[N].Right := Body;

  ParsePredDecl := N;
End;

(* ---- ParseClassDecl : class Name extends Base (members) ----- *)

Function ParseClassDecl : Integer;
Var
  N, MemberList, Member : Integer;
Begin
  N := NewNode(NK_CLASS_DECL);
  Consume;  { sauter 'class' }
  Nodes[N].Name := CurToken.Val;
  Consume;  { nom de la classe }

  { extends }
  If TokIsKw('extends') Then
  Begin
    Consume;
    Nodes[N].Extra := NewNode(NK_EXPR_IDENT);
    Nodes[Nodes[N].Extra].Name := CurToken.Val;
    Consume;
  End;

  { Corps de la classe }
  MemberList := -1;
  If TokIsPunct('{') Then
  Begin
    Consume;
    While (Not TokIsPunct('}')) And (CurToken.Kind <> TK_EOF) Do
    Begin
      { override predicate ... }
      If TokIsKw('override') Then
      Begin
        Consume;
        If TokIsKw('predicate') Then
        Begin
          Member := ParsePredDecl;
          AppendToList(MemberList, Member);
        End;
      End
      Else If TokIsKw('predicate') Then
      Begin
        Member := ParsePredDecl;
        AppendToList(MemberList, Member);
      End
      Else If TokIsKw('abstract') Then
      Begin
        Consume;
        If TokIsKw('predicate') Then
        Begin
          Member := ParsePredDecl;
          AppendToList(MemberList, Member);
        End;
      End
      Else If TokIsKw('private') Then
      Begin
        Consume;
        If TokIsKw('predicate') Then
        Begin
          Member := ParsePredDecl;
          AppendToList(MemberList, Member);
        End;
      End
      Else
      Begin
        { Autre membre : consommer pour avancer }
        Member := ParseFormula;
        AppendToList(MemberList, Member);
      End;
    End;
    Expect('}');
  End;
  Nodes[N].Left := MemberList;

  ParseClassDecl := N;
End;

{ ---- ParseSelect : from ... where ... select ... ------------- }

Function ParseSelect : Integer;
Var
  N, FromList, FDecl, WhereF, SelList : Integer;
  OBIdx : Integer;
Begin
  N := NewNode(NK_SELECT);
  FromList := -1;
  WhereF   := -1;
  SelList  := -1;

  { Reinitialiser les infos group by / order by }
  GroupByCount := 0;
  OrderByCount := 0;

  { from Type var, Type var, ... }
  If TokIsKw('from') Then
  Begin
    Consume;
    While (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Do
    Begin
      FDecl := ParseVarDecl;
      AppendToList(FromList, FDecl);
      If TokIsPunct(',') Then
        Consume
      Else
        Break;
    End;
  End;
  Nodes[N].Left := FromList;

  { where formula }
  If TokIsKw('where') Then
  Begin
    Consume;
    WhereF := ParseFormula;
  End;
  Nodes[N].Right := WhereF;

  { select exprList }
  If TokIsKw('select') Then
  Begin
    Consume;
    SelList := ParseExprList;
  End;
  Nodes[N].Extra := SelList;

  { group by expr, expr, ... }
  If TokIsKw('group') Then
  Begin
    Consume;  { sauter group }
    If TokIsKw('by') Then
      Consume;  { sauter by }
    While (GroupByCount < MAX_ORDER_BY) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      GroupByExprs[GroupByCount] := ParseExpr;
      Inc(GroupByCount);
      If TokIsPunct(',') Then
        Consume
      Else
        Break;
    End;
  End;

  { order by expr [asc|desc], expr [asc|desc], ... }
  If TokIsKw('order') Then
  Begin
    Consume;  { sauter order }
    If TokIsKw('by') Then
      Consume;  { sauter by }
    While (OrderByCount < MAX_ORDER_BY) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      OBIdx := ParseExpr;
      OrderByCols[OrderByCount].ColIdx := OBIdx;
      OrderByCols[OrderByCount].Ascending := True;
      If TokIsKw('desc') Then
      Begin
        OrderByCols[OrderByCount].Ascending := False;
        Consume;
      End
      Else If TokIsKw('asc') Then
        Consume;
      Inc(OrderByCount);
      If TokIsPunct(',') Then
        Consume
      Else
        Break;
    End;
  End;

  ParseSelect := N;
End;

{ ---- ParseModule : racine du fichier QL ---------------------- }

Function ParseModule : Integer;
Var
  N, Child : Integer;
Begin
  N := NewNode(NK_MODULE);
  Nodes[N].Name := 'module';

  { Premier token }
  Consume;

  While CurToken.Kind <> TK_EOF Do
  Begin
    { Annotations : sauter }
    If CurToken.Kind = TK_ANNOTATION Then
    Begin
      Child := NewNode(NK_ANNOTATION);
      Nodes[Child].Name := CurToken.Val;
      AppendToList(Nodes[N].Left, Child);
      Consume;
      Continue;
    End;

    { import }
    If TokIsKw('import') Then
    Begin
      Child := ParseImport;
      AppendToList(Nodes[N].Left, Child);
      Continue;
    End;

    { class }
    If TokIsKw('class') Then
    Begin
      Child := ParseClassDecl;
      AppendToList(Nodes[N].Left, Child);
      Continue;
    End;

    { predicate }
    If TokIsKw('predicate') Then
    Begin
      Child := ParsePredDecl;
      AppendToList(Nodes[N].Left, Child);
      Continue;
    End;

    { module }
    If TokIsKw('module') Then
    Begin
      Child := NewNode(NK_MODULE);
      Consume;
      If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Nodes[Child].Name := CurToken.Val;
        Consume;
      End;
      If TokIsPunct('{') Then
        Nodes[Child].Left := ParsePredBody;
      AppendToList(Nodes[N].Left, Child);
      Continue;
    End;

    { select-from-where (from ou select en top-level) }
    If TokIsKw('from') Or TokIsKw('select') Then
    Begin
      Child := ParseSelect;
      AppendToList(Nodes[N].Left, Child);
      Continue;
    End;

    { Autre : avancer pour ne pas boucler }
    Consume;
  End;

  ParseModule := N;
End;

{ ---- NodeKindName : nom textuel d un TNodeKind --------------- }

Function NodeKindName(K : TNodeKind) : TString;
Begin
  Case K Of
    NK_NONE            : NodeKindName := 'NONE';
    NK_MODULE          : NodeKindName := 'MODULE';
    NK_IMPORT          : NodeKindName := 'IMPORT';
    NK_CLASS_DECL      : NodeKindName := 'CLASS';
    NK_PRED_DECL       : NodeKindName := 'PREDICATE';
    NK_SELECT          : NodeKindName := 'SELECT';
    NK_FROM_DECL       : NodeKindName := 'FROM';
    NK_VAR_DECL        : NodeKindName := 'VAR_DECL';
    NK_FORMULA_AND     : NodeKindName := 'AND';
    NK_FORMULA_OR      : NodeKindName := 'OR';
    NK_FORMULA_NOT     : NodeKindName := 'NOT';
    NK_FORMULA_IMPLIES : NodeKindName := 'IMPLIES';
    NK_FORMULA_EXISTS  : NodeKindName := 'EXISTS';
    NK_FORMULA_FORALL  : NodeKindName := 'FORALL';
    NK_FORMULA_IF      : NodeKindName := 'IF';
    NK_EXPR_CALL       : NodeKindName := 'CALL';
    NK_EXPR_MEMBER     : NodeKindName := 'MEMBER';
    NK_EXPR_BINOP      : NodeKindName := 'BINOP';
    NK_EXPR_UNOP       : NodeKindName := 'UNOP';
    NK_EXPR_IDENT      : NodeKindName := 'IDENT';
    NK_EXPR_INT        : NodeKindName := 'INT';
    NK_EXPR_FLOAT      : NodeKindName := 'FLOAT';
    NK_EXPR_STRING     : NodeKindName := 'STRING';
    NK_EXPR_THIS       : NodeKindName := 'THIS';
    NK_EXPR_SUPER      : NodeKindName := 'SUPER';
    NK_EXPR_RESULT     : NodeKindName := 'RESULT';
    NK_EXPR_INSTANCEOF : NodeKindName := 'INSTANCEOF';
    NK_EXPR_IN         : NodeKindName := 'IN';
    NK_EXPR_RANGE      : NodeKindName := 'RANGE';
    NK_EXPR_AGGR       : NodeKindName := 'AGGR';
    NK_ANNOTATION      : NodeKindName := 'ANNOTATION';
  End;
End;

{ ---- DumpAST : affichage recursif de l AST ------------------- }

Procedure DumpAST(Idx, Depth : Integer);
Var
  I   : Integer;
  Spc : TString;
  Cur : Integer;
Begin
  If Idx < 0 Then Exit;
  Spc := '';
  For I := 1 To Depth * 2 Do
    If Length(Spc) < MAX_STR Then
      Spc := Spc + ' ';
  Write(Spc, NodeKindName(Nodes[Idx].Kind));
  If Nodes[Idx].Name <> '' Then
    Write(' "', Nodes[Idx].Name, '"');
  If Nodes[Idx].Kind = NK_EXPR_INT Then
    Write(' =', Nodes[Idx].IntVal);
  WriteLn(' [', Nodes[Idx].Line, ',', Nodes[Idx].Col, ']');
  { Enfants }
  If Nodes[Idx].Left >= 0 Then
  Begin
    Cur := Nodes[Idx].Left;
    While Cur >= 0 Do
    Begin
      DumpAST(Cur, Depth + 1);
      Cur := Nodes[Cur].Next;
    End;
  End;
  If Nodes[Idx].Right >= 0 Then
    DumpAST(Nodes[Idx].Right, Depth + 1);
  If Nodes[Idx].Extra >= 0 Then
    DumpAST(Nodes[Idx].Extra, Depth + 1);
End;

{ ============================================================
  TODO 04 - SYSTEME DE TYPES DU LANGAGE QL [IMPLEMENTE]
  ============================================================ }

{ ---- Enregistrer un type dans la table ----------------------- }

Function RegisterType(Kind : TQLTypeKind;
                      Const AName : TString;
                      ABase : Integer;
                      AIsRef : Boolean) : Integer;
Begin
  If TypeCount >= MAX_TYPES Then
    FatalError('TypeSystem: depassement MAX_TYPES');
  TypeTable[TypeCount].Kind     := Kind;
  TypeTable[TypeCount].Name     := AName;
  TypeTable[TypeCount].BaseType := ABase;
  TypeTable[TypeCount].IsRef    := AIsRef;
  RegisterType := TypeCount;
  Inc(TypeCount);
End;

{ ---- Initialiser le systeme de types built-in ---------------- }

Procedure InitTypeSystem;
Begin
  TypeCount  := 0;
  TypeErrors := 0;

  { Index 0 : type inconnu / non resolu }
  RegisterType(QTK_NONE,    '<none>',    -1, False);

  { Types primitifs (indices 1 a 6) }
  RegisterType(QTK_INT,     'int',       -1, False);
  RegisterType(QTK_FLOAT,   'float',     -1, False);
  RegisterType(QTK_STRING,  'string',    -1, False);
  RegisterType(QTK_BOOLEAN, 'boolean',   -1, False);
  RegisterType(QTK_DATE,    'date',      -1, False);
  RegisterType(QTK_VOID,    'void',      -1, False);

  { Types de reference vers les noeuds de l AST source (indices 7+) }
  RegisterType(QTK_LOCATABLE, '@locatable', -1, True);
  RegisterType(QTK_EXPR,      '@expr',      7,  True);
  RegisterType(QTK_STMT,      '@stmt',      7,  True);
  RegisterType(QTK_FUNCTION,  '@function',  7,  True);
  RegisterType(QTK_CLASS,     '@class',     7,  True);
  RegisterType(QTK_VARIABLE,  '@variable',  7,  True);
  RegisterType(QTK_TYPE,      '@type',      7,  True);
End;

{ ---- Chercher un type par nom -------------------------------- }

Function FindType(Const AName : TString) : Integer;
Var
  I   : Integer;
  Low : TString;
Begin
  Low := StrLowerCase(AName);
  For I := 0 To TypeCount - 1 Do
  Begin
    If StrLowerCase(TypeTable[I].Name) = Low Then
    Begin
      FindType := I;
      Exit;
    End;
  End;
  FindType := -1;
End;

{ ---- Enregistrer un type utilisateur (classe QL) ------------- }

Function RegisterUserType(Const AName : TString;
                          ABase : Integer) : Integer;
Begin
  RegisterUserType := RegisterType(QTK_USER, AName, ABase, False);
End;

{ ---- Verifier si TypeA est compatible avec TypeB ------------- }

Function TypeIsCompatible(TypeA, TypeB : Integer) : Boolean;
Var Cur : Integer;
Begin
  If (TypeA < 0) Or (TypeB < 0) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  If TypeA = TypeB Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  If TypeA = 0 Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  Cur := TypeA;
  While Cur >= 0 Do
  Begin
    If Cur = TypeB Then
    Begin
      TypeIsCompatible := True;
      Exit;
    End;
    Cur := TypeTable[Cur].BaseType;
  End;
  Cur := TypeB;
  While Cur >= 0 Do
  Begin
    If Cur = TypeA Then
    Begin
      TypeIsCompatible := True;
      Exit;
    End;
    Cur := TypeTable[Cur].BaseType;
  End;
  TypeIsCompatible := False;
End;

{ ---- Nom textuel d un TQLTypeKind ---------------------------- }

Function TypeKindName(K : TQLTypeKind) : TString;
Begin
  Case K Of
    QTK_NONE     : TypeKindName := 'none';
    QTK_INT      : TypeKindName := 'int';
    QTK_FLOAT    : TypeKindName := 'float';
    QTK_STRING   : TypeKindName := 'string';
    QTK_BOOLEAN  : TypeKindName := 'boolean';
    QTK_DATE     : TypeKindName := 'date';
    QTK_VOID     : TypeKindName := 'void';
    QTK_LOCATABLE: TypeKindName := '@locatable';
    QTK_EXPR     : TypeKindName := '@expr';
    QTK_STMT     : TypeKindName := '@stmt';
    QTK_FUNCTION : TypeKindName := '@function';
    QTK_CLASS    : TypeKindName := '@class';
    QTK_VARIABLE : TypeKindName := '@variable';
    QTK_TYPE     : TypeKindName := '@type';
    QTK_USER     : TypeKindName := 'user';
  End;
End;

{ ---- Nom complet du type par index --------------------------- }

Function TypeName(Idx : Integer) : TString;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeName := '<unknown>'
  Else
    TypeName := TypeTable[Idx].Name;
End;

{ ---- Emettre une erreur de type ------------------------------ }

Procedure TypeErrorMsg(ALine, ACol : Integer; Const Msg : TString);
Begin
  WriteLn('CODEQL: type error ligne ', ALine, ' col ', ACol,
          ': ', Msg);
  Inc(TypeErrors);
  Inc(ErrorCount);
End;

{ ---- ResolveNodeType : deduire le type d un noeud AST -------- }

Procedure ResolveNodeType(Idx : Integer); Forward;

Procedure ResolveNodeType;
Var
  LT, RT, TI : Integer;
  Cur        : Integer;
Begin
  If Idx < 0 Then Exit;
  If Nodes[Idx].TypeIdx >= 0 Then Exit;

  Case Nodes[Idx].Kind Of

    NK_EXPR_INT:
      Nodes[Idx].TypeIdx := FindType('int');

    NK_EXPR_FLOAT:
      Nodes[Idx].TypeIdx := FindType('float');

    NK_EXPR_STRING:
      Nodes[Idx].TypeIdx := FindType('string');

    NK_EXPR_THIS, NK_EXPR_SUPER, NK_EXPR_RESULT:
      Nodes[Idx].TypeIdx := 0;

    NK_EXPR_IDENT:
    Begin
      TI := FindType(Nodes[Idx].Name);
      If TI >= 0 Then
        Nodes[Idx].TypeIdx := TI
      Else
        Nodes[Idx].TypeIdx := 0;
    End;

    NK_EXPR_CALL:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        ResolveNodeType(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
        ResolveNodeType(Nodes[Idx].Right);
      Nodes[Idx].TypeIdx := 0;
    End;

    NK_EXPR_MEMBER:
    Begin
      If Nodes[Idx].Left >= 0 Then
        ResolveNodeType(Nodes[Idx].Left);
      Nodes[Idx].TypeIdx := 0;
    End;

    NK_EXPR_BINOP:
    Begin
      If Nodes[Idx].Left >= 0 Then
        ResolveNodeType(Nodes[Idx].Left);
      If Nodes[Idx].Right >= 0 Then
        ResolveNodeType(Nodes[Idx].Right);
      LT := -1;
      RT := -1;
      If Nodes[Idx].Left >= 0 Then
        LT := Nodes[Nodes[Idx].Left].TypeIdx;
      If Nodes[Idx].Right >= 0 Then
        RT := Nodes[Nodes[Idx].Right].TypeIdx;
      If (Nodes[Idx].Name = '=') Or (Nodes[Idx].Name = '!=') Or
         (Nodes[Idx].Name = '<') Or (Nodes[Idx].Name = '>') Or
         (Nodes[Idx].Name = '<=') Or (Nodes[Idx].Name = '>=') Then
        Nodes[Idx].TypeIdx := FindType('boolean')
      Else If (LT > 0) And (LT = RT) Then
        Nodes[Idx].TypeIdx := LT
      Else If (LT > 0) Then
        Nodes[Idx].TypeIdx := LT
      Else If (RT > 0) Then
        Nodes[Idx].TypeIdx := RT
      Else
        Nodes[Idx].TypeIdx := 0;
    End;

    NK_EXPR_UNOP:
    Begin
      If Nodes[Idx].Left >= 0 Then
      Begin
        ResolveNodeType(Nodes[Idx].Left);
        Nodes[Idx].TypeIdx := Nodes[Nodes[Idx].Left].TypeIdx;
      End
      Else
        Nodes[Idx].TypeIdx := 0;
    End;

    NK_EXPR_INSTANCEOF:
      Nodes[Idx].TypeIdx := FindType('boolean');

    NK_EXPR_IN:
    Begin
      If Nodes[Idx].Left >= 0 Then
        ResolveNodeType(Nodes[Idx].Left);
      If Nodes[Idx].Right >= 0 Then
        ResolveNodeType(Nodes[Idx].Right);
      Nodes[Idx].TypeIdx := FindType('boolean');
    End;

    NK_EXPR_RANGE:
    Begin
      If Nodes[Idx].Left >= 0 Then
      Begin
        ResolveNodeType(Nodes[Idx].Left);
        Nodes[Idx].TypeIdx := Nodes[Nodes[Idx].Left].TypeIdx;
      End
      Else
        Nodes[Idx].TypeIdx := FindType('int');
    End;

    NK_EXPR_AGGR:
    Begin
      If (Nodes[Idx].Name = 'count') Or
         (Nodes[Idx].Name = 'strictcount') Or
         (Nodes[Idx].Name = 'rank') Then
        Nodes[Idx].TypeIdx := FindType('int')
      Else If (Nodes[Idx].Name = 'sum') Or
              (Nodes[Idx].Name = 'strictsum') Or
              (Nodes[Idx].Name = 'min') Or
              (Nodes[Idx].Name = 'max') Then
      Begin
        If Nodes[Idx].Left >= 0 Then
        Begin
          ResolveNodeType(Nodes[Idx].Left);
          Nodes[Idx].TypeIdx := Nodes[Nodes[Idx].Left].TypeIdx;
        End
        Else
          Nodes[Idx].TypeIdx := FindType('int');
      End
      Else If Nodes[Idx].Name = 'avg' Then
        Nodes[Idx].TypeIdx := FindType('float')
      Else If (Nodes[Idx].Name = 'concat') Or
              (Nodes[Idx].Name = 'strictconcat') Then
        Nodes[Idx].TypeIdx := FindType('string')
      Else
        Nodes[Idx].TypeIdx := 0;
    End;

    NK_FORMULA_AND, NK_FORMULA_OR, NK_FORMULA_NOT,
    NK_FORMULA_IMPLIES, NK_FORMULA_EXISTS, NK_FORMULA_FORALL,
    NK_FORMULA_IF:
    Begin
      If Nodes[Idx].Left >= 0 Then
        ResolveNodeType(Nodes[Idx].Left);
      If Nodes[Idx].Right >= 0 Then
        ResolveNodeType(Nodes[Idx].Right);
      If Nodes[Idx].Extra >= 0 Then
        ResolveNodeType(Nodes[Idx].Extra);
      Nodes[Idx].TypeIdx := FindType('boolean');
    End;

    NK_VAR_DECL:
    Begin
      If Nodes[Idx].Left >= 0 Then
      Begin
        TI := FindType(Nodes[Nodes[Idx].Left].Name);
        If TI >= 0 Then
          Nodes[Idx].TypeIdx := TI
        Else
          Nodes[Idx].TypeIdx := 0;
      End
      Else
        Nodes[Idx].TypeIdx := 0;
    End;

    NK_PRED_DECL:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        ResolveNodeType(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
      Begin
        Cur := Nodes[Idx].Right;
        While Cur >= 0 Do
        Begin
          ResolveNodeType(Cur);
          Cur := Nodes[Cur].Next;
        End;
      End;
      Nodes[Idx].TypeIdx := FindType('void');
    End;

    NK_CLASS_DECL:
    Begin
      TI := FindType(Nodes[Idx].Name);
      If TI < 0 Then
      Begin
        LT := -1;
        If Nodes[Idx].Extra >= 0 Then
          LT := FindType(Nodes[Nodes[Idx].Extra].Name);
        TI := RegisterUserType(Nodes[Idx].Name, LT);
      End;
      Nodes[Idx].TypeIdx := TI;
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        ResolveNodeType(Cur);
        Cur := Nodes[Cur].Next;
      End;
    End;

    NK_SELECT:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        ResolveNodeType(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
        ResolveNodeType(Nodes[Idx].Right);
      If Nodes[Idx].Extra >= 0 Then
      Begin
        Cur := Nodes[Idx].Extra;
        While Cur >= 0 Do
        Begin
          ResolveNodeType(Cur);
          Cur := Nodes[Cur].Next;
        End;
      End;
      Nodes[Idx].TypeIdx := 0;
    End;

    NK_MODULE:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        ResolveNodeType(Cur);
        Cur := Nodes[Cur].Next;
      End;
      Nodes[Idx].TypeIdx := 0;
    End;

    NK_IMPORT, NK_ANNOTATION:
      Nodes[Idx].TypeIdx := 0;

  Else
    Nodes[Idx].TypeIdx := 0;
  End;
End;

{ ---- TypeCheckNode : verifier la coherence des types --------- }

Procedure TypeCheckNode(Idx : Integer);
Var
  LT, RT : Integer;
  Cur    : Integer;
Begin
  If Idx < 0 Then Exit;

  Case Nodes[Idx].Kind Of

    NK_EXPR_BINOP:
    Begin
      TypeCheckNode(Nodes[Idx].Left);
      TypeCheckNode(Nodes[Idx].Right);
      If (Nodes[Idx].Left >= 0) And (Nodes[Idx].Right >= 0) Then
      Begin
        LT := Nodes[Nodes[Idx].Left].TypeIdx;
        RT := Nodes[Nodes[Idx].Right].TypeIdx;
        If (LT > 0) And (RT > 0) Then
        Begin
          If (Nodes[Idx].Name = '+') Or (Nodes[Idx].Name = '-') Or
             (Nodes[Idx].Name = '*') Or (Nodes[Idx].Name = '/') Or
             (Nodes[Idx].Name = '%') Then
          Begin
            If Not TypeIsCompatible(LT, RT) Then
              TypeErrorMsg(Nodes[Idx].Line, Nodes[Idx].Col,
                'operandes incompatibles: ' + TypeName(LT) +
                ' ' + Nodes[Idx].Name + ' ' + TypeName(RT));
          End;
          If (Nodes[Idx].Name = '=') Or (Nodes[Idx].Name = '!=') Then
          Begin
            If Not TypeIsCompatible(LT, RT) Then
              TypeErrorMsg(Nodes[Idx].Line, Nodes[Idx].Col,
                'comparaison entre types incompatibles: ' +
                TypeName(LT) + ' et ' + TypeName(RT));
          End;
        End;
      End;
    End;

    NK_FORMULA_AND, NK_FORMULA_OR, NK_FORMULA_IMPLIES:
    Begin
      TypeCheckNode(Nodes[Idx].Left);
      TypeCheckNode(Nodes[Idx].Right);
    End;

    NK_FORMULA_NOT:
      TypeCheckNode(Nodes[Idx].Left);

    NK_FORMULA_EXISTS, NK_FORMULA_FORALL:
    Begin
      TypeCheckNode(Nodes[Idx].Left);
      TypeCheckNode(Nodes[Idx].Right);
      If Nodes[Idx].Extra >= 0 Then
        TypeCheckNode(Nodes[Idx].Extra);
    End;

    NK_FORMULA_IF:
    Begin
      TypeCheckNode(Nodes[Idx].Left);
      TypeCheckNode(Nodes[Idx].Right);
      If Nodes[Idx].Extra >= 0 Then
        TypeCheckNode(Nodes[Idx].Extra);
    End;

    NK_EXPR_CALL:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        TypeCheckNode(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
        TypeCheckNode(Nodes[Idx].Right);
    End;

    NK_PRED_DECL:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        If (Nodes[Cur].Left >= 0) Then
        Begin
          LT := FindType(Nodes[Nodes[Cur].Left].Name);
          If LT < 0 Then
            TypeErrorMsg(Nodes[Cur].Line, Nodes[Cur].Col,
              'type inconnu: ' + Nodes[Nodes[Cur].Left].Name);
        End;
        TypeCheckNode(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
      Begin
        Cur := Nodes[Idx].Right;
        While Cur >= 0 Do
        Begin
          TypeCheckNode(Cur);
          Cur := Nodes[Cur].Next;
        End;
      End;
    End;

    NK_CLASS_DECL:
    Begin
      If Nodes[Idx].Extra >= 0 Then
      Begin
        LT := FindType(Nodes[Nodes[Idx].Extra].Name);
        If LT < 0 Then
          TypeErrorMsg(Nodes[Idx].Line, Nodes[Idx].Col,
            'classe de base inconnue: ' +
            Nodes[Nodes[Idx].Extra].Name);
      End;
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        TypeCheckNode(Cur);
        Cur := Nodes[Cur].Next;
      End;
    End;

    NK_SELECT:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        If (Nodes[Cur].Left >= 0) Then
        Begin
          LT := FindType(Nodes[Nodes[Cur].Left].Name);
          If LT < 0 Then
            TypeErrorMsg(Nodes[Cur].Line, Nodes[Cur].Col,
              'type from inconnu: ' +
              Nodes[Nodes[Cur].Left].Name);
        End;
        TypeCheckNode(Cur);
        Cur := Nodes[Cur].Next;
      End;
      If Nodes[Idx].Right >= 0 Then
        TypeCheckNode(Nodes[Idx].Right);
      If Nodes[Idx].Extra >= 0 Then
      Begin
        Cur := Nodes[Idx].Extra;
        While Cur >= 0 Do
        Begin
          TypeCheckNode(Cur);
          Cur := Nodes[Cur].Next;
        End;
      End;
    End;

    NK_MODULE:
    Begin
      Cur := Nodes[Idx].Left;
      While Cur >= 0 Do
      Begin
        TypeCheckNode(Cur);
        Cur := Nodes[Cur].Next;
      End;
    End;

  End;
End;

{ ---- TypeCheckAST : parcourir l AST et verifier les types ---- }

Procedure TypeCheckAST;
Begin
  If RootNode < 0 Then Exit;
  TypeErrors := 0;
  ResolveNodeType(RootNode);
  TypeCheckNode(RootNode);
End;

{ ---- DumpTypes : affichage de la table des types ------------- }

Procedure DumpTypes;
Var I : Integer;
Begin
  WriteLn('--- Table des types (', TypeCount, ' types) ---');
  For I := 0 To TypeCount - 1 Do
  Begin
    Write('  [', I, '] ', TypeTable[I].Name,
          ' (', TypeKindName(TypeTable[I].Kind), ')');
    If TypeTable[I].BaseType >= 0 Then
      Write(' extends ', TypeTable[TypeTable[I].BaseType].Name);
    If TypeTable[I].IsRef Then
      Write(' [ref]');
    WriteLn;
  End;
  WriteLn;
End;

{ ============================================================
  TODO 05 - LEXEUR PASCAL (SOURCE) [IMPLEMENTE]
  ============================================================ }

{ ---- Reconnaissance des mots-cles Pascal -------------------- }

Function IsPascalKeyword(Const S : TString) : Boolean;
Var Low : TString;
Begin
  Low := StrLowerCase(S);
  IsPascalKeyword :=
    (Low = 'program')   Or (Low = 'unit')      Or (Low = 'uses')     Or
    (Low = 'const')     Or (Low = 'type')      Or (Low = 'var')      Or
    (Low = 'procedure') Or (Low = 'function')  Or (Low = 'begin')    Or
    (Low = 'end')       Or (Low = 'if')        Or (Low = 'then')     Or
    (Low = 'else')      Or (Low = 'while')     Or (Low = 'for')      Or
    (Low = 'repeat')    Or (Low = 'until')     Or (Low = 'do')       Or
    (Low = 'case')      Or (Low = 'with')      Or (Low = 'record')   Or
    (Low = 'array')     Or (Low = 'string')    Or (Low = 'integer')  Or
    (Low = 'boolean')   Or (Low = 'real')      Or (Low = 'of')       Or
    (Low = 'to')        Or (Low = 'downto')    Or (Low = 'div')      Or
    (Low = 'mod')       Or (Low = 'and')       Or (Low = 'or')       Or
    (Low = 'not')       Or (Low = 'xor')       Or (Low = 'shl')      Or
    (Low = 'shr')       Or (Low = 'nil')       Or (Low = 'set')      Or
    (Low = 'file')      Or (Low = 'object')    Or (Low = 'class')    Or
    (Low = 'interface') Or (Low = 'implementation') Or
    (Low = 'inherited') Or (Low = 'in')        Or (Low = 'is')       Or
    (Low = 'as')        Or (Low = 'try')       Or (Low = 'except')   Or
    (Low = 'finally')   Or (Low = 'raise')     Or (Low = 'goto')     Or
    (Low = 'label')     Or (Low = 'packed')    Or (Low = 'inline')   Or
    (Low = 'forward')   Or (Low = 'external');
End;

{ ---- Lire la prochaine ligne source Pascal ------------------- }

Procedure SrcLexNextLine;
Begin
  If SrcEOF Then Exit;
  If EOF(SrcLexF) Then
  Begin
    SrcEOF   := True;
    SrcLine  := '';
    SrcColNo := 1;
  End
  Else
  Begin
    {$I-}
    ReadLn(SrcLexF, SrcLine);
    {$I+}
    If IOResult <> 0 Then
    Begin
      SrcEOF   := True;
      SrcLine  := '';
      SrcColNo := 1;
      Exit;
    End;
    Inc(SrcLineNo);
    Inc(SrcTotalLines);
    SrcColNo := 1;
  End;
End;

{ ---- Initialiser le lexeur source Pascal --------------------- }

Procedure SrcLexInit;
Begin
  SrcLineNo    := 0;
  SrcColNo     := 1;
  SrcEOF       := False;
  SrcLine      := '';
  SrcTokenCount := 0;
  SrcTotalLines := 0;
  SrcToken.Kind     := STK_EOF;
  SrcToken.Val      := '';
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;
  SrcToken.Line     := 0;
  SrcToken.Col      := 0;
  SrcLexNextLine;
End;

{ ---- Fermer le lexeur source Pascal -------------------------- }

Procedure SrcLexClose;
Begin
  If SrcLexOpened Then
  Begin
    {$I-}
    Close(SrcLexF);
    {$I+}
    If IOResult <> 0 Then { ignorer };
    SrcLexOpened := False;
  End;
End;

{ ---- Scanner un identificateur ou mot-cle Pascal ------------- }

Procedure SrcLexScanIdent;
Var S : TString;
Begin
  S := '';
  While (SrcColNo <= Length(SrcLine)) And
        IsIdentCont(SrcLine[SrcColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  SrcToken.Val    := S;
  SrcToken.IntVal := 0;
  If IsPascalKeyword(S) Then
    SrcToken.Kind := STK_KEYWORD
  Else
    SrcToken.Kind := STK_IDENT;
End;

{ ---- Scanner un nombre Pascal (entier ou flottant) ----------- }

Procedure SrcLexScanNumber;
Var
  N       : LongInt;
  Ch      : Char;
  NumStr  : TString;
  IsFloat : Boolean;
  Code    : Integer;
Begin
  N       := 0;
  NumStr  := '';
  IsFloat := False;
  Ch      := SrcLine[SrcColNo];

  { Hexadecimal Pascal : $FF }
  If Ch = '$' Then
  Begin
    NumStr := '$';
    Inc(SrcColNo);
    While (SrcColNo <= Length(SrcLine)) And
          IsHexDigit(SrcLine[SrcColNo]) Do
    Begin
      N := N * 16 + HexVal(SrcLine[SrcColNo]);
      NumStr := NumStr + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
    SrcToken.Kind     := STK_INTEGER;
    SrcToken.Val      := NumStr;
    SrcToken.IntVal   := N;
    SrcToken.FloatVal := 0.0;
    Exit;
  End;

  { Decimal }
  While (SrcColNo <= Length(SrcLine)) And
        IsDigit(SrcLine[SrcColNo]) Do
  Begin
    N := N * 10 + (Ord(SrcLine[SrcColNo]) - Ord('0'));
    NumStr := NumStr + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;

  { Partie fractionnaire .ddd }
  If (SrcColNo <= Length(SrcLine)) And
     (SrcLine[SrcColNo] = '.') And
     (SrcColNo < Length(SrcLine)) And
     IsDigit(SrcLine[SrcColNo + 1]) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + '.';
    Inc(SrcColNo);
    While (SrcColNo <= Length(SrcLine)) And
          IsDigit(SrcLine[SrcColNo]) Do
    Begin
      NumStr := NumStr + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;

  { Exposant E[+-]ddd }
  If (SrcColNo <= Length(SrcLine)) And
     ((SrcLine[SrcColNo] = 'e') Or (SrcLine[SrcColNo] = 'E')) Then
  Begin
    IsFloat := True;
    NumStr := NumStr + SrcLine[SrcColNo];
    Inc(SrcColNo);
    If (SrcColNo <= Length(SrcLine)) And
       ((SrcLine[SrcColNo] = '+') Or (SrcLine[SrcColNo] = '-')) Then
    Begin
      NumStr := NumStr + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
    While (SrcColNo <= Length(SrcLine)) And
          IsDigit(SrcLine[SrcColNo]) Do
    Begin
      NumStr := NumStr + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;

  If IsFloat Then
  Begin
    SrcToken.Kind   := STK_FLOAT;
    SrcToken.Val    := NumStr;
    SrcToken.IntVal := N;
    Val(NumStr, SrcToken.FloatVal, Code);
    If Code <> 0 Then
      SrcToken.FloatVal := N;
  End
  Else
  Begin
    SrcToken.Kind     := STK_INTEGER;
    SrcToken.Val      := NumStr;
    SrcToken.IntVal   := N;
    SrcToken.FloatVal := 0.0;
  End;
End;

{ ---- Scanner une chaine Pascal entre apostrophes ------------- }

Procedure SrcLexScanString;
Var
  S        : TString;
  CharCode : Integer;
Begin
  S := '';
  Inc(SrcColNo);  { sauter l apostrophe ouvrante }
  While SrcColNo <= Length(SrcLine) Do
  Begin
    If SrcLine[SrcColNo] = '''' Then
    Begin
      { Apostrophe double '' = apostrophe dans la chaine }
      If (SrcColNo < Length(SrcLine)) And
         (SrcLine[SrcColNo + 1] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(SrcColNo, 2);
      End
      Else
      Begin
        Inc(SrcColNo);  { sauter l apostrophe fermante }
        Break;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  { Concatenation avec #nn (caractere code ASCII) }
  While (SrcColNo <= Length(SrcLine)) And
        (SrcLine[SrcColNo] = '#') Do
  Begin
    Inc(SrcColNo);
    { Lire le code numerique }
    If (SrcColNo <= Length(SrcLine)) And
       IsDigit(SrcLine[SrcColNo]) Then
    Begin
      CharCode := 0;
      While (SrcColNo <= Length(SrcLine)) And
            IsDigit(SrcLine[SrcColNo]) Do
      Begin
        CharCode := CharCode * 10 +
                    (Ord(SrcLine[SrcColNo]) - Ord('0'));
        Inc(SrcColNo);
      End;
      If (CharCode >= 0) And (CharCode <= 255) And
         (Length(S) < MAX_STR) Then
        S := S + Chr(CharCode);
    End;
    { Si une autre chaine suit directement }
    If (SrcColNo <= Length(SrcLine)) And
       (SrcLine[SrcColNo] = '''') Then
    Begin
      Inc(SrcColNo);
      While SrcColNo <= Length(SrcLine) Do
      Begin
        If SrcLine[SrcColNo] = '''' Then
        Begin
          If (SrcColNo < Length(SrcLine)) And
             (SrcLine[SrcColNo + 1] = '''') Then
          Begin
            If Length(S) < MAX_STR Then
              S := S + '''';
            Inc(SrcColNo, 2);
          End
          Else
          Begin
            Inc(SrcColNo);
            Break;
          End;
        End
        Else
        Begin
          If Length(S) < MAX_STR Then
            S := S + SrcLine[SrcColNo];
          Inc(SrcColNo);
        End;
      End;
    End;
  End;
  SrcToken.Kind   := STK_STRING;
  SrcToken.Val    := S;
  SrcToken.IntVal := 0;
End;

{ ---- Scanner un caractere # code (hors chaine) --------------- }

Procedure SrcLexScanCharCode;
Var
  S        : TString;
  CharCode : Integer;
Begin
  S := '';
  Inc(SrcColNo);  { sauter le # }
  CharCode := 0;
  If (SrcColNo <= Length(SrcLine)) And
     (SrcLine[SrcColNo] = '$') Then
  Begin
    { #$xx : code hexadecimal }
    Inc(SrcColNo);
    While (SrcColNo <= Length(SrcLine)) And
          IsHexDigit(SrcLine[SrcColNo]) Do
    Begin
      CharCode := CharCode * 16 + HexVal(SrcLine[SrcColNo]);
      Inc(SrcColNo);
    End;
  End
  Else
  Begin
    { #nn : code decimal }
    While (SrcColNo <= Length(SrcLine)) And
          IsDigit(SrcLine[SrcColNo]) Do
    Begin
      CharCode := CharCode * 10 +
                  (Ord(SrcLine[SrcColNo]) - Ord('0'));
      Inc(SrcColNo);
    End;
  End;
  If (CharCode >= 0) And (CharCode <= 255) Then
    S := Chr(CharCode)
  Else
    S := '?';
  SrcToken.Kind   := STK_STRING;
  SrcToken.Val    := S;
  SrcToken.IntVal := CharCode;
End;

(* ---- Sauter un commentaire accolades ----- *)

Procedure SrcLexSkipBraceComment;
Var S : TString;
Begin
  S := '';
  Inc(SrcColNo);  (* sauter l accolade ouvrante *)
  (* Verifier si c est une directive $... *)
  If (SrcColNo <= Length(SrcLine)) And
     (SrcLine[SrcColNo] = '$') Then
  Begin
    { Directive de compilation }
    While (Not SrcEOF) Do
    Begin
      If SrcColNo > Length(SrcLine) Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + ' ';
        SrcLexNextLine;
      End
      Else If SrcLine[SrcColNo] = '}' Then
      Begin
        Inc(SrcColNo);
        SrcToken.Kind := STK_DIRECTIVE;
        SrcToken.Val  := S;
        Exit;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
    End;
    SrcToken.Kind := STK_DIRECTIVE;
    SrcToken.Val  := S;
    Exit;
  End;

  { Commentaire normal }
  While Not SrcEOF Do
  Begin
    If SrcColNo > Length(SrcLine) Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + ' ';
      SrcLexNextLine;
    End
    Else If SrcLine[SrcColNo] = '}' Then
    Begin
      Inc(SrcColNo);
      SrcToken.Kind := STK_COMMENT;
      SrcToken.Val  := S;
      Exit;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  SrcToken.Kind := STK_COMMENT;
  SrcToken.Val  := S;
End;

{ ---- Sauter un commentaire parenthese-etoile (* ... *) ------- }

Procedure SrcLexSkipParenStarComment;
Var S : TString;
Begin
  S := '';
  Inc(SrcColNo, 2);  { sauter (* }
  While Not SrcEOF Do
  Begin
    If SrcColNo > Length(SrcLine) Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + ' ';
      SrcLexNextLine;
    End
    Else If (SrcLine[SrcColNo] = '*') And
            (SrcColNo < Length(SrcLine)) And
            (SrcLine[SrcColNo + 1] = ')') Then
    Begin
      Inc(SrcColNo, 2);
      SrcToken.Kind := STK_COMMENT;
      SrcToken.Val  := S;
      Exit;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  SrcToken.Kind := STK_COMMENT;
  SrcToken.Val  := S;
End;

{ ---- Sauter un commentaire de ligne // ----------------------- }

Procedure SrcLexSkipLineComment;
Var S : TString;
Begin
  S := Copy(SrcLine, SrcColNo + 2, Length(SrcLine) - SrcColNo - 1);
  SrcToken.Kind := STK_COMMENT;
  SrcToken.Val  := S;
  SrcColNo := Length(SrcLine) + 1;
End;

{ ---- SrcLexNextToken : dispatcher principal du lexeur Pascal - }

Procedure SrcLexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la ligne suivante si fin de ligne courante }
    While (Not SrcEOF) And (SrcColNo > Length(SrcLine)) Do
      SrcLexNextLine;

    { Fin de fichier }
    If SrcEOF Then
    Begin
      SrcToken.Kind := STK_EOF;
      SrcToken.Val  := '';
      SrcToken.Line := SrcLineNo;
      SrcToken.Col  := SrcColNo;
      Scanning := False;
      Break;
    End;

    SrcToken.Line := SrcLineNo;
    SrcToken.Col  := SrcColNo;
    Ch := SrcLine[SrcColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(SrcColNo);
      Continue;
    End;

    Scanning := False;

    (* Commentaire accolades ou directive *)
    If Ch = '{' Then
    Begin
      SrcLexSkipBraceComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire parenthese-etoile (* ... *) ou affectation }
    If (Ch = '(') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '*') Then
    Begin
      SrcLexSkipParenStarComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire de ligne // }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '/') Then
    Begin
      SrcLexSkipLineComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines entre apostrophes }
    If Ch = '''' Then
    Begin
      SrcLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caractere code #nn }
    If Ch = '#' Then
    Begin
      SrcLexScanCharCode;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Identificateurs et mots-cles }
    If IsIdentStart(Ch) Then
    Begin
      SrcLexScanIdent;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Nombres (decimaux ou hexadecimaux $FF) }
    If IsDigit(Ch) Or (Ch = '$') Then
    Begin
      SrcLexScanNumber;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Operateurs multi-caracteres }
    If (Ch = ':') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '=') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := ':=';
      Inc(SrcColNo, 2);
      Inc(SrcTokenCount);
      Exit;
    End;

    If (Ch = '<') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '>') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := '<>';
      Inc(SrcColNo, 2);
      Inc(SrcTokenCount);
      Exit;
    End;

    If (Ch = '<') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '=') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := '<=';
      Inc(SrcColNo, 2);
      Inc(SrcTokenCount);
      Exit;
    End;

    If (Ch = '>') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '=') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := '>=';
      Inc(SrcColNo, 2);
      Inc(SrcTokenCount);
      Exit;
    End;

    If (Ch = '.') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '.') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := '..';
      Inc(SrcColNo, 2);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Operateurs simples }
    If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
       (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Ponctuation }
    If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
       (Ch = ',') Or (Ch = ';') Or (Ch = ':') Or (Ch = '.') Or
       (Ch = '^') Then
    Begin
      SrcToken.Kind := STK_PUNCT;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caractere inconnu : emettre comme ponctuation }
    SrcToken.Kind := STK_PUNCT;
    SrcToken.Val  := Ch;
    Inc(SrcColNo);
    Inc(SrcTokenCount);
  End;
End;

{ ---- Nom textuel d un type de token source Pascal ------------ }

Function SrcTokenKindName(K : TSourceTokenKind) : TString;
Begin
  Case K Of
    STK_EOF       : SrcTokenKindName := 'EOF';
    STK_INTEGER   : SrcTokenKindName := 'INT';
    STK_FLOAT     : SrcTokenKindName := 'FLOAT';
    STK_STRING    : SrcTokenKindName := 'STR';
    STK_IDENT     : SrcTokenKindName := 'IDENT';
    STK_KEYWORD   : SrcTokenKindName := 'KW';
    STK_OP        : SrcTokenKindName := 'OP';
    STK_PUNCT     : SrcTokenKindName := 'PUNCT';
    STK_COMMENT   : SrcTokenKindName := 'COMMENT';
    STK_DIRECTIVE : SrcTokenKindName := 'DIR';
  Else
    SrcTokenKindName := '?';
  End;
End;

{ ---- Affichage debug d un token source Pascal ---------------- }

Procedure PrintSrcToken(Const T : TSourceToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    STK_EOF       : Write('EOF');
    STK_INTEGER   : Write('INT(', T.IntVal, ')');
    STK_FLOAT     : Write('FLOAT(', T.Val, ')');
    STK_STRING    : Write('STR(''', T.Val, ''')');
    STK_IDENT     : Write('IDENT(', T.Val, ')');
    STK_KEYWORD   : Write('KW(', T.Val, ')');
    STK_OP        : Write('OP(', T.Val, ')');
    STK_PUNCT     : Write('PUNCT(', T.Val, ')');
    STK_COMMENT   : Write('COMMENT(', T.Val, ')');
    STK_DIRECTIVE : Write('DIR(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- Dump complet de tous les tokens d un fichier Pascal ----- }

Procedure DumpSrcTokens(Const FileName : TString);
Begin
  Assign(SrcLexF, FileName);
  {$I-}
  Reset(SrcLexF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('CODEQL: impossible d''ouvrir le fichier source: ', FileName);
    Exit;
  End;
  SrcLexOpened := True;
  SrcLexInit;
  WriteLn('--- Tokens source Pascal : ', FileName, ' ---');
  Repeat
    SrcLexNextToken;
    PrintSrcToken(SrcToken);
  Until SrcToken.Kind = STK_EOF;
  WriteLn('--- ', SrcTokenCount, ' tokens, ',
          SrcTotalLines, ' lignes ---');
  WriteLn;
  SrcLexClose;
End;

{ ============================================================
  TODO 06 - ANALYSEUR SYNTAXIQUE PASCAL (SOURCE) [IMPLEMENTE]
  ============================================================ }

{ ---- Allocation d un noeud AST source ----------------------- }

Function SrcNewNode(K : TSrcNodeKind) : Integer;
Begin
  If SrcNodeCount >= MAX_SRC_NODES Then
  Begin
    WriteLn('CODEQL: trop de noeuds AST source');
    SrcNewNode := -1;
    Exit;
  End;
  SrcNodes[SrcNodeCount].Kind     := K;
  SrcNodes[SrcNodeCount].Name     := '';
  SrcNodes[SrcNodeCount].IntVal   := 0;
  SrcNodes[SrcNodeCount].FloatVal := 0.0;
  SrcNodes[SrcNodeCount].Line     := SrcToken.Line;
  SrcNodes[SrcNodeCount].Col      := SrcToken.Col;
  SrcNodes[SrcNodeCount].Left     := -1;
  SrcNodes[SrcNodeCount].Right    := -1;
  SrcNodes[SrcNodeCount].Extra    := -1;
  SrcNodes[SrcNodeCount].Next     := -1;
  SrcNewNode := SrcNodeCount;
  Inc(SrcNodeCount);
End;

{ ---- Initialisation du parser source ------------------------ }

Procedure SrcASTInit;
Begin
  SrcNodeCount := 0;
  SrcRootNode  := -1;
End;

{ ---- Consommer le prochain token non-commentaire ------------ }

Procedure SrcConsume;
Begin
  Repeat
    SrcLexNextToken;
  Until (SrcToken.Kind <> STK_COMMENT) And
        (SrcToken.Kind <> STK_DIRECTIVE);
End;

{ ---- Tester la valeur du token courant ---------------------- }

Function SrcTokIs(Const S : TString) : Boolean;
Begin
  SrcTokIs := (SrcToken.Val = S);
End;

{ ---- Tester si le token courant est un mot-cle -------------- }

Function SrcTokIsKw(Const S : TString) : Boolean;
Begin
  SrcTokIsKw := (SrcToken.Kind = STK_KEYWORD) And
                (StrLowerCase(SrcToken.Val) = S);
End;

{ ---- Tester si le token courant est un operateur ------------ }

Function SrcTokIsOp(Const S : TString) : Boolean;
Begin
  SrcTokIsOp := (SrcToken.Kind = STK_OP) And (SrcToken.Val = S);
End;

{ ---- Tester si le token courant est une ponctuation --------- }

Function SrcTokIsPunct(Const S : TString) : Boolean;
Begin
  SrcTokIsPunct := (SrcToken.Kind = STK_PUNCT) And (SrcToken.Val = S);
End;

{ ---- Attendre un token et le consommer ---------------------- }

Procedure SrcExpect(Const S : TString);
Begin
  If (StrLowerCase(SrcToken.Val) <> S) Then
    WriteLn('CODEQL: attendu ''', S, ''' a la ligne ', SrcToken.Line,
            ', colonne ', SrcToken.Col, ', trouve ''', SrcToken.Val, '''');
  SrcConsume;
End;

{ ---- Ajouter un noeud a la fin d une liste chainee ---------- }

Procedure SrcAppendToList(Var Head : Integer; N : Integer);
Var Cur : Integer;
Begin
  If Head = -1 Then
    Head := N
  Else
  Begin
    Cur := Head;
    While SrcNodes[Cur].Next <> -1 Do
      Cur := SrcNodes[Cur].Next;
    SrcNodes[Cur].Next := N;
  End;
End;

{ ---- Declarations Forward ----------------------------------- }

Function  SrcParseExpr      : Integer; Forward;
Function  SrcParsePrimary   : Integer; Forward;
Function  SrcParseStatement : Integer; Forward;
Function  SrcParseBlock     : Integer; Forward;
Function  SrcParseType      : Integer; Forward;

{ ---- Parsing d une expression primaire ---------------------- }

Function SrcParsePrimary : Integer;
Var N, Sub, Head, Arg : Integer;
Begin
  SrcParsePrimary := -1;
  Case SrcToken.Kind Of
    STK_INTEGER:
      Begin
        N := SrcNewNode(SNK_EXPR_INT);
        SrcNodes[N].IntVal := SrcToken.IntVal;
        SrcNodes[N].Name   := SrcToken.Val;
        SrcConsume;
        SrcParsePrimary := N;
      End;
    STK_FLOAT:
      Begin
        N := SrcNewNode(SNK_EXPR_FLOAT);
        SrcNodes[N].FloatVal := SrcToken.FloatVal;
        SrcNodes[N].Name     := SrcToken.Val;
        SrcConsume;
        SrcParsePrimary := N;
      End;
    STK_STRING:
      Begin
        N := SrcNewNode(SNK_EXPR_STRING);
        SrcNodes[N].Name := SrcToken.Val;
        SrcConsume;
        SrcParsePrimary := N;
      End;
    STK_KEYWORD:
      Begin
        If SrcTokIsKw('nil') Then
        Begin
          N := SrcNewNode(SNK_EXPR_NIL);
          SrcConsume;
          SrcParsePrimary := N;
        End
        Else
        Begin
          { mot-cle utilise comme identifiant (ex: string, integer) }
          N := SrcNewNode(SNK_EXPR_IDENT);
          SrcNodes[N].Name := SrcToken.Val;
          SrcConsume;
          SrcParsePrimary := N;
        End;
      End;
    STK_IDENT:
      Begin
        N := SrcNewNode(SNK_EXPR_IDENT);
        SrcNodes[N].Name := SrcToken.Val;
        SrcConsume;
        SrcParsePrimary := N;
      End;
    STK_PUNCT:
      Begin
        If SrcTokIsPunct('(') Then
        Begin
          SrcConsume;
          N := SrcParseExpr;
          If SrcTokIsPunct(')') Then
            SrcConsume;
          SrcParsePrimary := N;
        End
        Else If SrcTokIsPunct('[') Then
        Begin
          { constructeur d ensemble [a, b, c..d] }
          N := SrcNewNode(SNK_EXPR_SET);
          SrcConsume;
          Head := -1;
          If Not SrcTokIsPunct(']') Then
          Begin
            Sub := SrcParseExpr;
            If SrcTokIsOp('..') Then
            Begin
              Arg := SrcNewNode(SNK_EXPR_RANGE);
              SrcNodes[Arg].Left := Sub;
              SrcConsume;
              SrcNodes[Arg].Right := SrcParseExpr;
              Sub := Arg;
            End;
            SrcAppendToList(Head, Sub);
            While SrcTokIsPunct(',') Do
            Begin
              SrcConsume;
              Sub := SrcParseExpr;
              If SrcTokIsOp('..') Then
              Begin
                Arg := SrcNewNode(SNK_EXPR_RANGE);
                SrcNodes[Arg].Left := Sub;
                SrcConsume;
                SrcNodes[Arg].Right := SrcParseExpr;
                Sub := Arg;
              End;
              SrcAppendToList(Head, Sub);
            End;
          End;
          SrcNodes[N].Left := Head;
          If SrcTokIsPunct(']') Then
            SrcConsume;
          SrcParsePrimary := N;
        End;
      End;
  End;

  { postfixes : .field  ^deref  [index]  (args) }
  N := SrcParsePrimary;
  While True Do
  Begin
    If SrcTokIsPunct('.') Then
    Begin
      SrcConsume;
      Sub := SrcNewNode(SNK_EXPR_FIELD);
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        SrcNodes[Sub].Name := SrcToken.Val;
        SrcConsume;
      End;
      SrcNodes[Sub].Left := N;
      N := Sub;
    End
    Else If SrcTokIsPunct('^') Then
    Begin
      Sub := SrcNewNode(SNK_EXPR_DEREF);
      SrcNodes[Sub].Left := N;
      SrcConsume;
      N := Sub;
    End
    Else If SrcTokIsPunct('[') Then
    Begin
      Sub := SrcNewNode(SNK_EXPR_INDEX);
      SrcNodes[Sub].Left := N;
      SrcConsume;
      Head := -1;
      Arg := SrcParseExpr;
      SrcAppendToList(Head, Arg);
      While SrcTokIsPunct(',') Do
      Begin
        SrcConsume;
        Arg := SrcParseExpr;
        SrcAppendToList(Head, Arg);
      End;
      SrcNodes[Sub].Right := Head;
      If SrcTokIsPunct(']') Then
        SrcConsume;
      N := Sub;
    End
    Else If SrcTokIsPunct('(') Then
    Begin
      Sub := SrcNewNode(SNK_EXPR_CALL);
      SrcNodes[Sub].Left := N;
      SrcConsume;
      Head := -1;
      If Not SrcTokIsPunct(')') Then
      Begin
        Arg := SrcParseExpr;
        SrcAppendToList(Head, Arg);
        While SrcTokIsPunct(',') Do
        Begin
          SrcConsume;
          Arg := SrcParseExpr;
          SrcAppendToList(Head, Arg);
        End;
      End;
      SrcNodes[Sub].Right := Head;
      If SrcTokIsPunct(')') Then
        SrcConsume;
      N := Sub;
    End
    Else
      Break;
  End;
  SrcParsePrimary := N;
End;

{ ---- Parsing unaire ----------------------------------------- }

Function SrcParseUnary : Integer;
Var N : Integer;
Begin
  If SrcTokIsKw('not') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := 'not';
    SrcConsume;
    SrcNodes[N].Left := SrcParsePrimary;
    SrcParseUnary := N;
  End
  Else If SrcTokIsOp('@') Then
  Begin
    N := SrcNewNode(SNK_EXPR_ADDR);
    SrcConsume;
    SrcNodes[N].Left := SrcParsePrimary;
    SrcParseUnary := N;
  End
  Else If SrcTokIsOp('-') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := '-';
    SrcConsume;
    SrcNodes[N].Left := SrcParsePrimary;
    SrcParseUnary := N;
  End
  Else If SrcTokIsOp('+') Then
  Begin
    SrcConsume;
    SrcParseUnary := SrcParsePrimary;
  End
  Else
    SrcParseUnary := SrcParsePrimary;
End;

{ ---- Parsing facteur (meme que unaire) ---------------------- }

Function SrcParseFactor : Integer;
Begin
  SrcParseFactor := SrcParseUnary;
End;

{ ---- Parsing terme (* / div mod and shl shr) ---------------- }

Function SrcParseTerm : Integer;
Var N, Op : Integer;
    OpName : TString;
Begin
  N := SrcParseFactor;
  While SrcTokIsOp('*') Or SrcTokIsOp('/') Or
        SrcTokIsKw('div') Or SrcTokIsKw('mod') Or
        SrcTokIsKw('and') Or SrcTokIsKw('shl') Or
        SrcTokIsKw('shr') Do
  Begin
    OpName := StrLowerCase(SrcToken.Val);
    Op := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[Op].Name := OpName;
    SrcConsume;
    SrcNodes[Op].Left  := N;
    SrcNodes[Op].Right := SrcParseFactor;
    N := Op;
  End;
  SrcParseTerm := N;
End;

{ ---- Parsing expression simple (+ - or xor) ----------------- }

Function SrcParseSimpleExpr : Integer;
Var N, Op : Integer;
    OpName : TString;
Begin
  N := SrcParseTerm;
  While SrcTokIsOp('+') Or SrcTokIsOp('-') Or
        SrcTokIsKw('or') Or SrcTokIsKw('xor') Do
  Begin
    OpName := StrLowerCase(SrcToken.Val);
    Op := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[Op].Name := OpName;
    SrcConsume;
    SrcNodes[Op].Left  := N;
    SrcNodes[Op].Right := SrcParseTerm;
    N := Op;
  End;
  SrcParseSimpleExpr := N;
End;

{ ---- Parsing expression (relationnels, in, is, as) ---------- }

Function SrcParseExpr : Integer;
Var N, Op : Integer;
    OpName : TString;
Begin
  N := SrcParseSimpleExpr;
  While SrcTokIsOp('=') Or SrcTokIsOp('<>') Or
        SrcTokIsOp('<') Or SrcTokIsOp('>') Or
        SrcTokIsOp('<=') Or SrcTokIsOp('>=') Or
        SrcTokIsKw('in') Or SrcTokIsKw('is') Or
        SrcTokIsKw('as') Do
  Begin
    OpName := StrLowerCase(SrcToken.Val);
    Op := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[Op].Name := OpName;
    SrcConsume;
    SrcNodes[Op].Left  := N;
    SrcNodes[Op].Right := SrcParseSimpleExpr;
    N := Op;
  End;
  SrcParseExpr := N;
End;

{ ---- Parsing d un type Pascal ------------------------------- }

Function SrcParseType : Integer;
Var N, Sub, Head : Integer;
Begin
  SrcParseType := -1;

  If SrcTokIsKw('array') Then
  Begin
    N := SrcNewNode(SNK_TYPE_ARRAY);
    SrcConsume;
    If SrcTokIsPunct('[') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseExpr;
      If SrcTokIsOp('..') Then
      Begin
        Sub := SrcNewNode(SNK_EXPR_RANGE);
        SrcNodes[Sub].Left := SrcNodes[N].Left;
        SrcConsume;
        SrcNodes[Sub].Right := SrcParseExpr;
        SrcNodes[N].Left := Sub;
      End;
      While SrcTokIsPunct(',') Do
      Begin
        SrcConsume;
        Sub := SrcParseExpr;
        If SrcTokIsOp('..') Then
        Begin
          Head := SrcNewNode(SNK_EXPR_RANGE);
          SrcNodes[Head].Left := Sub;
          SrcConsume;
          SrcNodes[Head].Right := SrcParseExpr;
          Sub := Head;
        End;
        SrcAppendToList(SrcNodes[N].Left, Sub);
      End;
      If SrcTokIsPunct(']') Then
        SrcConsume;
    End;
    If SrcTokIsKw('of') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseType;
    SrcParseType := N;
  End
  Else If SrcTokIsKw('record') Then
  Begin
    N := SrcNewNode(SNK_TYPE_RECORD);
    SrcConsume;
    Head := -1;
    While (Not SrcTokIsKw('end')) And (SrcToken.Kind <> STK_EOF) Do
    Begin
      If SrcTokIsKw('case') Then
      Begin
        { variante record : on saute jusqu a end }
        Sub := SrcNewNode(SNK_RECORD_SECTION);
        SrcNodes[Sub].Name := 'case';
        SrcConsume;
        SrcNodes[Sub].Left := SrcParseExpr;
        If SrcTokIsKw('of') Then
          SrcConsume;
        { sauter les variantes simplement }
        While (Not SrcTokIsKw('end')) And (SrcToken.Kind <> STK_EOF) Do
          SrcConsume;
        SrcAppendToList(Head, Sub);
      End
      Else If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        Sub := SrcNewNode(SNK_FIELD_DECL);
        SrcNodes[Sub].Name := SrcToken.Val;
        SrcConsume;
        While SrcTokIsPunct(',') Do
        Begin
          SrcConsume;
          If (SrcToken.Kind = STK_IDENT) Or
             (SrcToken.Kind = STK_KEYWORD) Then
            SrcConsume;
        End;
        If SrcTokIsPunct(':') Then
        Begin
          SrcConsume;
          SrcNodes[Sub].Left := SrcParseType;
        End;
        If SrcTokIsPunct(';') Then
          SrcConsume;
        SrcAppendToList(Head, Sub);
      End
      Else
        SrcConsume;
    End;
    SrcNodes[N].Left := Head;
    If SrcTokIsKw('end') Then
      SrcConsume;
    SrcParseType := N;
  End
  Else If SrcTokIsPunct('^') Then
  Begin
    N := SrcNewNode(SNK_TYPE_POINTER);
    SrcConsume;
    SrcNodes[N].Left := SrcParseType;
    SrcParseType := N;
  End
  Else If SrcTokIsKw('set') Then
  Begin
    N := SrcNewNode(SNK_TYPE_SET);
    SrcConsume;
    If SrcTokIsKw('of') Then
      SrcConsume;
    SrcNodes[N].Left := SrcParseType;
    SrcParseType := N;
  End
  Else If SrcTokIsKw('file') Then
  Begin
    N := SrcNewNode(SNK_TYPE_FILE);
    SrcConsume;
    If SrcTokIsKw('of') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseType;
    End;
    SrcParseType := N;
  End
  Else If SrcTokIsKw('string') Then
  Begin
    N := SrcNewNode(SNK_TYPE_STRING);
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
    If SrcTokIsPunct('[') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseExpr;
      If SrcTokIsPunct(']') Then
        SrcConsume;
    End;
    SrcParseType := N;
  End
  Else If SrcTokIsPunct('(') Then
  Begin
    { type enumere (a, b, c) }
    N := SrcNewNode(SNK_TYPE_ENUM);
    SrcConsume;
    Head := -1;
    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
    Begin
      Sub := SrcNewNode(SNK_EXPR_IDENT);
      SrcNodes[Sub].Name := SrcToken.Val;
      SrcConsume;
      SrcAppendToList(Head, Sub);
      While SrcTokIsPunct(',') Do
      Begin
        SrcConsume;
        If (SrcToken.Kind = STK_IDENT) Or
           (SrcToken.Kind = STK_KEYWORD) Then
        Begin
          Sub := SrcNewNode(SNK_EXPR_IDENT);
          SrcNodes[Sub].Name := SrcToken.Val;
          SrcConsume;
          SrcAppendToList(Head, Sub);
        End;
      End;
    End;
    SrcNodes[N].Left := Head;
    If SrcTokIsPunct(')') Then
      SrcConsume;
    SrcParseType := N;
  End
  Else If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    N := SrcNewNode(SNK_TYPE_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
    { sous-type intervalle : lo..hi }
    If SrcTokIsOp('..') Then
    Begin
      Sub := SrcNewNode(SNK_TYPE_RANGE);
      SrcNodes[Sub].Left := N;
      SrcConsume;
      SrcNodes[Sub].Right := SrcParseExpr;
      SrcParseType := Sub;
    End
    Else
      SrcParseType := N;
  End
  Else If SrcToken.Kind = STK_INTEGER Then
  Begin
    { intervalle numerique : 0..255 }
    N := SrcNewNode(SNK_EXPR_INT);
    SrcNodes[N].IntVal := SrcToken.IntVal;
    SrcNodes[N].Name   := SrcToken.Val;
    SrcConsume;
    If SrcTokIsOp('..') Then
    Begin
      Sub := SrcNewNode(SNK_TYPE_RANGE);
      SrcNodes[Sub].Left := N;
      SrcConsume;
      SrcNodes[Sub].Right := SrcParseExpr;
      SrcParseType := Sub;
    End
    Else
      SrcParseType := N;
  End;
End;

{ ---- Section const ------------------------------------------ }

Procedure SrcParseConstSection(Var Head : Integer);
Var N : Integer;
Begin
  SrcConsume; { consomme 'const' }
  While (SrcToken.Kind = STK_IDENT) And
        (Not SrcTokIsKw('type')) And (Not SrcTokIsKw('var')) And
        (Not SrcTokIsKw('procedure')) And (Not SrcTokIsKw('function')) And
        (Not SrcTokIsKw('begin')) And (Not SrcTokIsKw('end')) And
        (SrcToken.Kind <> STK_EOF) Do
  Begin
    N := SrcNewNode(SNK_CONST_DECL);
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
    If SrcTokIsPunct(':') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseType;
    End;
    If SrcTokIsOp('=') Then
    Begin
      SrcConsume;
      SrcNodes[N].Right := SrcParseExpr;
    End;
    If SrcTokIsPunct(';') Then
      SrcConsume;
    SrcAppendToList(Head, N);
  End;
End;

{ ---- Section type ------------------------------------------- }

Procedure SrcParseTypeSection(Var Head : Integer);
Var N : Integer;
Begin
  SrcConsume; { consomme 'type' }
  While (SrcToken.Kind = STK_IDENT) And
        (Not SrcTokIsKw('const')) And (Not SrcTokIsKw('var')) And
        (Not SrcTokIsKw('procedure')) And (Not SrcTokIsKw('function')) And
        (Not SrcTokIsKw('begin')) And (Not SrcTokIsKw('end')) And
        (SrcToken.Kind <> STK_EOF) Do
  Begin
    N := SrcNewNode(SNK_TYPE_DECL);
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
    If SrcTokIsOp('=') Then
      SrcConsume;
    SrcNodes[N].Left := SrcParseType;
    If SrcTokIsPunct(';') Then
      SrcConsume;
    SrcAppendToList(Head, N);
  End;
End;

{ ---- Section var -------------------------------------------- }

Procedure SrcParseVarSection(Var Head : Integer);
Var N : Integer;
Begin
  SrcConsume; { consomme 'var' }
  While ((SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD)) And
        (Not SrcTokIsKw('const')) And (Not SrcTokIsKw('type')) And
        (Not SrcTokIsKw('procedure')) And (Not SrcTokIsKw('function')) And
        (Not SrcTokIsKw('begin')) And (Not SrcTokIsKw('end')) And
        (SrcToken.Kind <> STK_EOF) Do
  Begin
    N := SrcNewNode(SNK_VAR_DECL);
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
    While SrcTokIsPunct(',') Do
    Begin
      SrcConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
        SrcConsume;
    End;
    If SrcTokIsPunct(':') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseType;
    End;
    If SrcTokIsOp('=') Then
    Begin
      SrcConsume;
      SrcNodes[N].Right := SrcParseExpr;
    End;
    If SrcTokIsPunct(';') Then
      SrcConsume;
    SrcAppendToList(Head, N);
  End;
End;

{ ---- Liste de parametres (a, b : T; var c : U) -------------- }

Function SrcParseParamList : Integer;
Var Head, N : Integer;
    IsVar   : Boolean;
Begin
  Head := -1;
  If Not SrcTokIsPunct('(') Then
  Begin
    SrcParseParamList := -1;
    Exit;
  End;
  SrcConsume; { consomme '(' }
  While (Not SrcTokIsPunct(')')) And (SrcToken.Kind <> STK_EOF) Do
  Begin
    IsVar := False;
    If SrcTokIsKw('var') Or SrcTokIsKw('const') Then
    Begin
      IsVar := True;
      SrcConsume;
    End;
    N := SrcNewNode(SNK_PARAM_DECL);
    If IsVar Then
      SrcNodes[N].IntVal := 1;
    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      SrcConsume;
    End;
    While SrcTokIsPunct(',') Do
    Begin
      SrcConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
        SrcConsume;
    End;
    If SrcTokIsPunct(':') Then
    Begin
      SrcConsume;
      SrcNodes[N].Left := SrcParseType;
    End;
    SrcAppendToList(Head, N);
    If SrcTokIsPunct(';') Then
      SrcConsume;
  End;
  If SrcTokIsPunct(')') Then
    SrcConsume;
  SrcParseParamList := Head;
End;

{ ---- Declaration de procedure ------------------------------- }

Function SrcParseProcDecl : Integer;
Var N : Integer;
Begin
  N := SrcNewNode(SNK_PROC_DECL);
  SrcConsume; { consomme 'procedure' }
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
  End;
  If SrcTokIsPunct('(') Then
    SrcNodes[N].Left := SrcParseParamList;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  { forward ou external => pas de corps }
  If SrcTokIsKw('forward') Or SrcTokIsKw('external') Then
  Begin
    SrcConsume;
    If SrcTokIsPunct(';') Then
      SrcConsume;
  End
  Else
    SrcNodes[N].Right := SrcParseBlock;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  SrcParseProcDecl := N;
End;

{ ---- Declaration de fonction -------------------------------- }

Function SrcParseFuncDecl : Integer;
Var N : Integer;
Begin
  N := SrcNewNode(SNK_FUNC_DECL);
  SrcConsume; { consomme 'function' }
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
  End;
  If SrcTokIsPunct('(') Then
    SrcNodes[N].Left := SrcParseParamList;
  If SrcTokIsPunct(':') Then
  Begin
    SrcConsume;
    SrcNodes[N].Extra := SrcParseType;
  End;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  { forward ou external => pas de corps }
  If SrcTokIsKw('forward') Or SrcTokIsKw('external') Then
  Begin
    SrcConsume;
    If SrcTokIsPunct(';') Then
      SrcConsume;
  End
  Else
    SrcNodes[N].Right := SrcParseBlock;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  SrcParseFuncDecl := N;
End;

{ ---- Liste d instructions separees par ; -------------------- }

Function SrcParseStatementList : Integer;
Var Head, S : Integer;
Begin
  Head := -1;
  S := SrcParseStatement;
  If S <> -1 Then
    SrcAppendToList(Head, S);
  While SrcTokIsPunct(';') Do
  Begin
    SrcConsume;
    If SrcTokIsKw('end') Or SrcTokIsKw('until') Or
       SrcTokIsKw('else') Or SrcTokIsKw('except') Or
       SrcTokIsKw('finally') Or (SrcToken.Kind = STK_EOF) Then
      Break;
    S := SrcParseStatement;
    If S <> -1 Then
      SrcAppendToList(Head, S);
  End;
  SrcParseStatementList := Head;
End;

{ ---- Instruction composee begin...end ----------------------- }

Function SrcParseCompound : Integer;
Var N : Integer;
Begin
  N := SrcNewNode(SNK_COMPOUND);
  SrcConsume; { consomme 'begin' }
  SrcNodes[N].Left := SrcParseStatementList;
  If SrcTokIsKw('end') Then
    SrcConsume;
  SrcParseCompound := N;
End;

{ ---- Parsing d une instruction ------------------------------ }

Function SrcParseStatement : Integer;
Var N, E, SaveIdx : Integer;
Begin
  SrcParseStatement := -1;

  If SrcToken.Kind = STK_EOF Then
    Exit;

  If SrcTokIsKw('begin') Then
  Begin
    SrcParseStatement := SrcParseCompound;
    Exit;
  End;

  If SrcTokIsKw('if') Then
  Begin
    N := SrcNewNode(SNK_IF);
    SrcConsume;
    SrcNodes[N].Left := SrcParseExpr;
    If SrcTokIsKw('then') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseStatement;
    If SrcTokIsKw('else') Then
    Begin
      SrcConsume;
      SrcNodes[N].Extra := SrcParseStatement;
    End;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('while') Then
  Begin
    N := SrcNewNode(SNK_WHILE);
    SrcConsume;
    SrcNodes[N].Left := SrcParseExpr;
    If SrcTokIsKw('do') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseStatement;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('for') Then
  Begin
    N := SrcNewNode(SNK_FOR);
    SrcConsume;
    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      SrcConsume;
    End;
    If SrcTokIsOp(':=') Then
      SrcConsume;
    SrcNodes[N].Left := SrcParseExpr;
    If SrcTokIsKw('to') Or SrcTokIsKw('downto') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseExpr;
    If SrcTokIsKw('do') Then
      SrcConsume;
    SrcNodes[N].Extra := SrcParseStatement;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('repeat') Then
  Begin
    N := SrcNewNode(SNK_REPEAT);
    SrcConsume;
    SrcNodes[N].Left := SrcParseStatementList;
    If SrcTokIsKw('until') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseExpr;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('case') Then
  Begin
    N := SrcNewNode(SNK_CASE);
    SrcConsume;
    SrcNodes[N].Left := SrcParseExpr;
    If SrcTokIsKw('of') Then
      SrcConsume;
    E := -1;
    While (Not SrcTokIsKw('end')) And (Not SrcTokIsKw('else')) And
          (SrcToken.Kind <> STK_EOF) Do
    Begin
      SaveIdx := SrcNewNode(SNK_CASE_ITEM);
      SrcNodes[SaveIdx].Left := SrcParseExpr;
      While SrcTokIsPunct(',') Do
      Begin
        SrcConsume;
        SrcParseExpr; { extra labels, simplified }
      End;
      If SrcTokIsPunct(':') Then
        SrcConsume;
      SrcNodes[SaveIdx].Right := SrcParseStatement;
      If SrcTokIsPunct(';') Then
        SrcConsume;
      SrcAppendToList(E, SaveIdx);
    End;
    SrcNodes[N].Right := E;
    If SrcTokIsKw('else') Then
    Begin
      SrcConsume;
      SrcNodes[N].Extra := SrcParseStatementList;
    End;
    If SrcTokIsKw('end') Then
      SrcConsume;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('with') Then
  Begin
    N := SrcNewNode(SNK_WITH);
    SrcConsume;
    SrcNodes[N].Left := SrcParseExpr;
    While SrcTokIsPunct(',') Do
    Begin
      SrcConsume;
      SrcParseExpr;
    End;
    If SrcTokIsKw('do') Then
      SrcConsume;
    SrcNodes[N].Right := SrcParseStatement;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('try') Then
  Begin
    N := SrcNewNode(SNK_TRY);
    SrcConsume;
    SrcNodes[N].Left := SrcParseStatementList;
    If SrcTokIsKw('except') Then
    Begin
      E := SrcNewNode(SNK_EXCEPT);
      SrcConsume;
      SrcNodes[E].Left := SrcParseStatementList;
      SrcNodes[N].Right := E;
    End
    Else If SrcTokIsKw('finally') Then
    Begin
      E := SrcNewNode(SNK_FINALLY);
      SrcConsume;
      SrcNodes[E].Left := SrcParseStatementList;
      SrcNodes[N].Right := E;
    End;
    If SrcTokIsKw('end') Then
      SrcConsume;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('raise') Then
  Begin
    N := SrcNewNode(SNK_RAISE);
    SrcConsume;
    If (SrcToken.Kind <> STK_EOF) And (Not SrcTokIsPunct(';')) Then
      SrcNodes[N].Left := SrcParseExpr;
    SrcParseStatement := N;
    Exit;
  End;

  If SrcTokIsKw('goto') Then
  Begin
    N := SrcNewNode(SNK_GOTO);
    SrcConsume;
    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_INTEGER) Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      SrcConsume;
    End;
    SrcParseStatement := N;
    Exit;
  End;

  { instruction vide ou mot-cle de fermeture }
  If SrcTokIsKw('end') Or SrcTokIsKw('until') Or
     SrcTokIsKw('else') Or SrcTokIsKw('except') Or
     SrcTokIsKw('finally') Then
    Exit;

  { identifiant : affectation ou appel }
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    E := SrcParseExpr;
    If SrcTokIsOp(':=') Then
    Begin
      N := SrcNewNode(SNK_ASSIGN);
      SrcNodes[N].Left := E;
      SrcConsume;
      SrcNodes[N].Right := SrcParseExpr;
      SrcParseStatement := N;
    End
    Else
    Begin
      { appel de procedure (l expression elle-meme) }
      If (E >= 0) And ((SrcNodes[E].Kind = SNK_EXPR_CALL) Or
         (SrcNodes[E].Kind = SNK_EXPR_IDENT) Or
         (SrcNodes[E].Kind = SNK_EXPR_FIELD)) Then
      Begin
        N := SrcNewNode(SNK_CALL);
        SrcNodes[N].Left := E;
        SrcParseStatement := N;
      End
      Else
        SrcParseStatement := E;
    End;
    Exit;
  End;
End;

{ ---- Parsing d un bloc -------------------------------------- }

Function SrcParseBlock : Integer;
Var N : Integer;
    DeclHead : Integer;
Begin
  N := SrcNewNode(SNK_BLOCK);
  DeclHead := -1;

  While True Do
  Begin
    If SrcTokIsKw('const') Then
      SrcParseConstSection(DeclHead)
    Else If SrcTokIsKw('type') Then
      SrcParseTypeSection(DeclHead)
    Else If SrcTokIsKw('var') Then
      SrcParseVarSection(DeclHead)
    Else If SrcTokIsKw('label') Then
    Begin
      SrcConsume;
      While (SrcToken.Kind = STK_IDENT) Or
            (SrcToken.Kind = STK_INTEGER) Do
      Begin
        SrcConsume;
        If SrcTokIsPunct(',') Then
          SrcConsume;
      End;
      If SrcTokIsPunct(';') Then
        SrcConsume;
    End
    Else If SrcTokIsKw('procedure') Then
    Begin
      SrcAppendToList(DeclHead, SrcParseProcDecl);
    End
    Else If SrcTokIsKw('function') Then
    Begin
      SrcAppendToList(DeclHead, SrcParseFuncDecl);
    End
    Else
      Break;
  End;

  SrcNodes[N].Left := DeclHead;

  If SrcTokIsKw('begin') Then
    SrcNodes[N].Right := SrcParseCompound;

  SrcParseBlock := N;
End;

{ ---- Clause uses -------------------------------------------- }

Function SrcParseUsesClause : Integer;
Var N, Item, Head : Integer;
Begin
  N := SrcNewNode(SNK_USES);
  SrcConsume; { consomme 'uses' }
  Head := -1;
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    Item := SrcNewNode(SNK_USES_ITEM);
    SrcNodes[Item].Name := SrcToken.Val;
    SrcConsume;
    SrcAppendToList(Head, Item);
    While SrcTokIsPunct(',') Do
    Begin
      SrcConsume;
      If (SrcToken.Kind = STK_IDENT) Or
         (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        Item := SrcNewNode(SNK_USES_ITEM);
        SrcNodes[Item].Name := SrcToken.Val;
        SrcConsume;
        SrcAppendToList(Head, Item);
      End;
    End;
  End;
  SrcNodes[N].Left := Head;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  SrcParseUsesClause := N;
End;

{ ---- Programme principal ------------------------------------ }

Function SrcParseProgram : Integer;
Var N : Integer;
Begin
  N := SrcNewNode(SNK_PROGRAM);
  SrcConsume; { consomme 'program' }
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
  End;
  { parametres optionnels de programme (input, output) }
  If SrcTokIsPunct('(') Then
  Begin
    While (Not SrcTokIsPunct(')')) And (SrcToken.Kind <> STK_EOF) Do
      SrcConsume;
    If SrcTokIsPunct(')') Then
      SrcConsume;
  End;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  If SrcTokIsKw('uses') Then
    SrcNodes[N].Left := SrcParseUsesClause;
  SrcNodes[N].Right := SrcParseBlock;
  If SrcTokIsPunct('.') Then
    SrcConsume;
  SrcParseProgram := N;
End;

{ ---- Unite (unit) ------------------------------------------- }

Function SrcParseUnit : Integer;
Var N, DeclHead : Integer;
Begin
  N := SrcNewNode(SNK_UNIT);
  SrcConsume; { consomme 'unit' }
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    SrcConsume;
  End;
  If SrcTokIsPunct(';') Then
    SrcConsume;
  DeclHead := -1;
  { interface / implementation : on parse les sections }
  While (Not SrcTokIsKw('end')) And (SrcToken.Kind <> STK_EOF) And
        (Not SrcTokIsPunct('.')) Do
  Begin
    If SrcTokIsKw('interface') Or SrcTokIsKw('implementation') Then
      SrcConsume
    Else If SrcTokIsKw('uses') Then
      SrcAppendToList(DeclHead, SrcParseUsesClause)
    Else If SrcTokIsKw('const') Then
      SrcParseConstSection(DeclHead)
    Else If SrcTokIsKw('type') Then
      SrcParseTypeSection(DeclHead)
    Else If SrcTokIsKw('var') Then
      SrcParseVarSection(DeclHead)
    Else If SrcTokIsKw('procedure') Then
      SrcAppendToList(DeclHead, SrcParseProcDecl)
    Else If SrcTokIsKw('function') Then
      SrcAppendToList(DeclHead, SrcParseFuncDecl)
    Else If SrcTokIsKw('begin') Then
    Begin
      SrcAppendToList(DeclHead, SrcParseCompound);
      Break;
    End
    Else
      SrcConsume;
  End;
  SrcNodes[N].Left := DeclHead;
  If SrcTokIsKw('end') Then
    SrcConsume;
  If SrcTokIsPunct('.') Then
    SrcConsume;
  SrcParseUnit := N;
End;

{ ---- Point d entree du module ------------------------------- }

Function SrcParseModule : Integer;
Begin
  SrcConsume; { lire le premier token }
  If SrcTokIsKw('program') Then
    SrcParseModule := SrcParseProgram
  Else If SrcTokIsKw('unit') Then
    SrcParseModule := SrcParseUnit
  Else
  Begin
    { pas de mot-cle program/unit => on traite comme un programme }
    SrcParseModule := SrcParseBlock;
  End;
End;

{ ---- Nom d un type de noeud --------------------------------- }

Function SrcNodeKindName(K : TSrcNodeKind) : TString;
Begin
  Case K Of
    SNK_NONE         : SrcNodeKindName := 'NONE';
    SNK_PROGRAM      : SrcNodeKindName := 'PROGRAM';
    SNK_UNIT         : SrcNodeKindName := 'UNIT';
    SNK_USES         : SrcNodeKindName := 'USES';
    SNK_USES_ITEM    : SrcNodeKindName := 'USES_ITEM';
    SNK_CONST_DECL   : SrcNodeKindName := 'CONST_DECL';
    SNK_TYPE_DECL    : SrcNodeKindName := 'TYPE_DECL';
    SNK_VAR_DECL     : SrcNodeKindName := 'VAR_DECL';
    SNK_PARAM_DECL   : SrcNodeKindName := 'PARAM_DECL';
    SNK_PROC_DECL    : SrcNodeKindName := 'PROC_DECL';
    SNK_FUNC_DECL    : SrcNodeKindName := 'FUNC_DECL';
    SNK_BLOCK        : SrcNodeKindName := 'BLOCK';
    SNK_ASSIGN       : SrcNodeKindName := 'ASSIGN';
    SNK_CALL         : SrcNodeKindName := 'CALL';
    SNK_IF           : SrcNodeKindName := 'IF';
    SNK_WHILE        : SrcNodeKindName := 'WHILE';
    SNK_FOR          : SrcNodeKindName := 'FOR';
    SNK_REPEAT       : SrcNodeKindName := 'REPEAT';
    SNK_CASE         : SrcNodeKindName := 'CASE';
    SNK_CASE_ITEM    : SrcNodeKindName := 'CASE_ITEM';
    SNK_WITH         : SrcNodeKindName := 'WITH';
    SNK_TRY          : SrcNodeKindName := 'TRY';
    SNK_EXCEPT       : SrcNodeKindName := 'EXCEPT';
    SNK_FINALLY      : SrcNodeKindName := 'FINALLY';
    SNK_RAISE        : SrcNodeKindName := 'RAISE';
    SNK_GOTO         : SrcNodeKindName := 'GOTO';
    SNK_LABEL_DECL   : SrcNodeKindName := 'LABEL_DECL';
    SNK_COMPOUND     : SrcNodeKindName := 'COMPOUND';
    SNK_EXPR_BINOP   : SrcNodeKindName := 'EXPR_BINOP';
    SNK_EXPR_UNOP    : SrcNodeKindName := 'EXPR_UNOP';
    SNK_EXPR_INT     : SrcNodeKindName := 'EXPR_INT';
    SNK_EXPR_FLOAT   : SrcNodeKindName := 'EXPR_FLOAT';
    SNK_EXPR_STRING  : SrcNodeKindName := 'EXPR_STRING';
    SNK_EXPR_IDENT   : SrcNodeKindName := 'EXPR_IDENT';
    SNK_EXPR_CALL    : SrcNodeKindName := 'EXPR_CALL';
    SNK_EXPR_INDEX   : SrcNodeKindName := 'EXPR_INDEX';
    SNK_EXPR_FIELD   : SrcNodeKindName := 'EXPR_FIELD';
    SNK_EXPR_DEREF   : SrcNodeKindName := 'EXPR_DEREF';
    SNK_EXPR_ADDR    : SrcNodeKindName := 'EXPR_ADDR';
    SNK_EXPR_NIL     : SrcNodeKindName := 'EXPR_NIL';
    SNK_EXPR_SET     : SrcNodeKindName := 'EXPR_SET';
    SNK_EXPR_RANGE   : SrcNodeKindName := 'EXPR_RANGE';
    SNK_TYPE_IDENT   : SrcNodeKindName := 'TYPE_IDENT';
    SNK_TYPE_ARRAY   : SrcNodeKindName := 'TYPE_ARRAY';
    SNK_TYPE_RECORD  : SrcNodeKindName := 'TYPE_RECORD';
    SNK_TYPE_POINTER : SrcNodeKindName := 'TYPE_POINTER';
    SNK_TYPE_SET     : SrcNodeKindName := 'TYPE_SET';
    SNK_TYPE_FILE    : SrcNodeKindName := 'TYPE_FILE';
    SNK_TYPE_RANGE   : SrcNodeKindName := 'TYPE_RANGE';
    SNK_TYPE_ENUM    : SrcNodeKindName := 'TYPE_ENUM';
    SNK_TYPE_STRING  : SrcNodeKindName := 'TYPE_STRING';
    SNK_FIELD_DECL   : SrcNodeKindName := 'FIELD_DECL';
    SNK_RECORD_SECTION : SrcNodeKindName := 'RECORD_SECTION';
    SNK_C_TRANSLATION_UNIT : SrcNodeKindName := 'C_TRANSLATION_UNIT';
    SNK_C_INCLUDE      : SrcNodeKindName := 'C_INCLUDE';
    SNK_C_DEFINE       : SrcNodeKindName := 'C_DEFINE';
    SNK_C_STRUCT_DECL  : SrcNodeKindName := 'C_STRUCT_DECL';
    SNK_C_UNION_DECL   : SrcNodeKindName := 'C_UNION_DECL';
    SNK_C_ENUM_DECL    : SrcNodeKindName := 'C_ENUM_DECL';
    SNK_C_TYPEDEF      : SrcNodeKindName := 'C_TYPEDEF';
    SNK_C_DO_WHILE     : SrcNodeKindName := 'C_DO_WHILE';
    SNK_C_SWITCH       : SrcNodeKindName := 'C_SWITCH';
    SNK_C_CASE_ITEM    : SrcNodeKindName := 'C_CASE_ITEM';
    SNK_C_DEFAULT_ITEM : SrcNodeKindName := 'C_DEFAULT_ITEM';
    SNK_C_BREAK        : SrcNodeKindName := 'C_BREAK';
    SNK_C_CONTINUE     : SrcNodeKindName := 'C_CONTINUE';
    SNK_C_RETURN       : SrcNodeKindName := 'C_RETURN';
    SNK_C_SIZEOF       : SrcNodeKindName := 'C_SIZEOF';
    SNK_C_CAST         : SrcNodeKindName := 'C_CAST';
    SNK_C_TERNARY      : SrcNodeKindName := 'C_TERNARY';
    SNK_C_PREPROC      : SrcNodeKindName := 'C_PREPROC';
    SNK_CPP_TRANSLATION_UNIT : SrcNodeKindName := 'CPP_TRANSLATION_UNIT';
    SNK_CPP_CLASS_DECL   : SrcNodeKindName := 'CPP_CLASS_DECL';
    SNK_CPP_NAMESPACE    : SrcNodeKindName := 'CPP_NAMESPACE';
    SNK_CPP_TEMPLATE     : SrcNodeKindName := 'CPP_TEMPLATE';
    SNK_CPP_ACCESS_SPEC  : SrcNodeKindName := 'CPP_ACCESS_SPEC';
    SNK_CPP_TRY          : SrcNodeKindName := 'CPP_TRY';
    SNK_CPP_CATCH        : SrcNodeKindName := 'CPP_CATCH';
    SNK_CPP_THROW        : SrcNodeKindName := 'CPP_THROW';
    SNK_CPP_NEW          : SrcNodeKindName := 'CPP_NEW';
    SNK_CPP_DELETE       : SrcNodeKindName := 'CPP_DELETE';
    SNK_CPP_USING        : SrcNodeKindName := 'CPP_USING';
    SNK_CPP_SCOPE_RES    : SrcNodeKindName := 'CPP_SCOPE_RES';
    SNK_CSHARP_TRANSLATION_UNIT : SrcNodeKindName := 'CSHARP_TRANSLATION_UNIT';
    SNK_CSHARP_CLASS_DECL     : SrcNodeKindName := 'CSHARP_CLASS_DECL';
    SNK_CSHARP_INTERFACE_DECL : SrcNodeKindName := 'CSHARP_INTERFACE_DECL';
    SNK_CSHARP_STRUCT_DECL    : SrcNodeKindName := 'CSHARP_STRUCT_DECL';
    SNK_CSHARP_ENUM_DECL      : SrcNodeKindName := 'CSHARP_ENUM_DECL';
    SNK_CSHARP_DELEGATE_DECL  : SrcNodeKindName := 'CSHARP_DELEGATE_DECL';
    SNK_CSHARP_NAMESPACE      : SrcNodeKindName := 'CSHARP_NAMESPACE';
    SNK_CSHARP_USING          : SrcNodeKindName := 'CSHARP_USING';
    SNK_CSHARP_PROPERTY       : SrcNodeKindName := 'CSHARP_PROPERTY';
    SNK_CSHARP_ATTRIBUTE      : SrcNodeKindName := 'CSHARP_ATTRIBUTE';
    SNK_CSHARP_ASYNC          : SrcNodeKindName := 'CSHARP_ASYNC';
    SNK_CSHARP_AWAIT          : SrcNodeKindName := 'CSHARP_AWAIT';
    SNK_CSHARP_FOREACH        : SrcNodeKindName := 'CSHARP_FOREACH';
    SNK_CSHARP_LOCK           : SrcNodeKindName := 'CSHARP_LOCK';
  Else
    SrcNodeKindName := '???';
  End;
End;

{ ---- Dump recursif de l AST source -------------------------- }

Procedure DumpSrcAST(Idx : Integer; Depth : Integer);
Var I : Integer;
Begin
  If Idx < 0 Then Exit;
  For I := 1 To Depth Do
    Write('  ');
  Write(SrcNodeKindName(SrcNodes[Idx].Kind));
  If SrcNodes[Idx].Name <> '' Then
    Write(' "', SrcNodes[Idx].Name, '"');
  If SrcNodes[Idx].Kind = SNK_EXPR_INT Then
    Write(' =', SrcNodes[Idx].IntVal);
  WriteLn(' [', SrcNodes[Idx].Line, ':', SrcNodes[Idx].Col, ']');
  DumpSrcAST(SrcNodes[Idx].Left,  Depth + 1);
  DumpSrcAST(SrcNodes[Idx].Right, Depth + 1);
  DumpSrcAST(SrcNodes[Idx].Extra, Depth + 1);
  DumpSrcAST(SrcNodes[Idx].Next,  Depth);
End;

{ ---- Parser complet d un fichier Pascal ---------------------- }

Procedure ParseSrcFile(Const FileName : TString);
Begin
  Assign(SrcLexF, FileName);
  {$I-}
  Reset(SrcLexF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('CODEQL: impossible d''ouvrir le fichier source: ', FileName);
    Exit;
  End;
  SrcLexOpened := True;
  SrcLexInit;
  SrcASTInit;
  SrcRootNode := SrcParseModule;
  WriteLn('--- AST source Pascal : ', FileName, ' ---');
  WriteLn('  Noeuds: ', SrcNodeCount);
  WriteLn('  Tokens: ', SrcTokenCount);
  WriteLn('  Lignes: ', SrcTotalLines);
  If Opts.Verbose Then
    DumpSrcAST(SrcRootNode, 0);
  WriteLn;
  SrcLexClose;
End;

{ ============================================================
  TODO 07 - BASE DE DONNEES RELATIONNELLE CODEQL [IMPLEMENTE]
  ============================================================ }

{ ---- Noms textuels des sortes -------------------------------- }

Function DbExprKindName(K : TDbExprKind) : TString;
Begin
  Case K Of
    DEK_NONE      : DbExprKindName := 'none';
    DEK_INT_LIT   : DbExprKindName := 'int_literal';
    DEK_FLOAT_LIT : DbExprKindName := 'float_literal';
    DEK_STR_LIT   : DbExprKindName := 'string_literal';
    DEK_IDENT     : DbExprKindName := 'identifier';
    DEK_BINOP     : DbExprKindName := 'binary_op';
    DEK_UNOP      : DbExprKindName := 'unary_op';
    DEK_CALL      : DbExprKindName := 'call';
    DEK_INDEX     : DbExprKindName := 'index';
    DEK_FIELD     : DbExprKindName := 'field_access';
    DEK_DEREF     : DbExprKindName := 'dereference';
    DEK_ADDR      : DbExprKindName := 'address_of';
    DEK_NIL       : DbExprKindName := 'nil';
    DEK_SET       : DbExprKindName := 'set_constructor';
    DEK_RANGE     : DbExprKindName := 'range';
  Else
    DbExprKindName := '?';
  End;
End;

Function DbStmtKindName(K : TDbStmtKind) : TString;
Begin
  Case K Of
    DSK_NONE     : DbStmtKindName := 'none';
    DSK_ASSIGN   : DbStmtKindName := 'assignment';
    DSK_CALL     : DbStmtKindName := 'call';
    DSK_IF       : DbStmtKindName := 'if';
    DSK_WHILE    : DbStmtKindName := 'while';
    DSK_FOR      : DbStmtKindName := 'for';
    DSK_REPEAT   : DbStmtKindName := 'repeat';
    DSK_CASE     : DbStmtKindName := 'case';
    DSK_WITH     : DbStmtKindName := 'with';
    DSK_TRY      : DbStmtKindName := 'try';
    DSK_RAISE    : DbStmtKindName := 'raise';
    DSK_GOTO     : DbStmtKindName := 'goto';
    DSK_COMPOUND : DbStmtKindName := 'compound';
    DSK_BLOCK    : DbStmtKindName := 'block';
  Else
    DbStmtKindName := '?';
  End;
End;

Function DbTypeKindName(K : TDbTypeKind) : TString;
Begin
  Case K Of
    DTK_NONE    : DbTypeKindName := 'none';
    DTK_INTEGER : DbTypeKindName := 'integer';
    DTK_REAL    : DbTypeKindName := 'real';
    DTK_STRING  : DbTypeKindName := 'string';
    DTK_BOOLEAN : DbTypeKindName := 'boolean';
    DTK_CHAR    : DbTypeKindName := 'char';
    DTK_ARRAY   : DbTypeKindName := 'array';
    DTK_RECORD  : DbTypeKindName := 'record';
    DTK_POINTER : DbTypeKindName := 'pointer';
    DTK_SET     : DbTypeKindName := 'set';
    DTK_FILE    : DbTypeKindName := 'file';
    DTK_ENUM    : DbTypeKindName := 'enum';
    DTK_RANGE   : DbTypeKindName := 'range';
    DTK_ALIAS   : DbTypeKindName := 'alias';
    DTK_VOID    : DbTypeKindName := 'void';
  Else
    DbTypeKindName := '?';
  End;
End;

Function DbAccessKindName(K : TDbAccessKind) : TString;
Begin
  Case K Of
    DAK_NONE      : DbAccessKindName := 'none';
    DAK_READ      : DbAccessKindName := 'read';
    DAK_WRITE     : DbAccessKindName := 'write';
    DAK_READWRITE : DbAccessKindName := 'readwrite';
  Else
    DbAccessKindName := '?';
  End;
End;

Function DbSeverityName(S : TDbSeverity) : TString;
Begin
  Case S Of
    DSEV_NOTE    : DbSeverityName := 'note';
    DSEV_WARNING : DbSeverityName := 'warning';
    DSEV_ERROR   : DbSeverityName := 'error';
  Else
    DbSeverityName := '?';
  End;
End;

{ ---- Initialiser la base de donnees (vider toutes les tables) }

Procedure InitDatabase;
Begin
  DbProgramCnt  := 0;
  DbFileCnt     := 0;
  DbLocationCnt := 0;
  DbExprCnt     := 0;
  DbStmtCnt     := 0;
  DbFunctionCnt := 0;
  DbVariableCnt := 0;
  DbTypeCnt     := 0;
  DbCallCnt     := 0;
  DbAccessCnt   := 0;
  DbCommentCnt  := 0;
  DbDiagCnt     := 0;
End;

{ ---- Ajouter un programme ------------------------------------ }

Function DbAddProgram(Const AName, AFileName : TString) : Integer;
Begin
  If DbProgramCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB programs table overflow');
    DbAddProgram := -1;
    Exit;
  End;
  DbPrograms[DbProgramCnt].Id       := DbProgramCnt;
  DbPrograms[DbProgramCnt].Name     := AName;
  DbPrograms[DbProgramCnt].FileName := AFileName;
  DbAddProgram := DbProgramCnt;
  Inc(DbProgramCnt);
End;

{ ---- Ajouter un fichier -------------------------------------- }

Function DbAddFile(Const AName : TString; ANumLines : Integer) : Integer;
Begin
  If DbFileCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB files table overflow');
    DbAddFile := -1;
    Exit;
  End;
  DbFiles[DbFileCnt].Id       := DbFileCnt;
  DbFiles[DbFileCnt].Name     := AName;
  DbFiles[DbFileCnt].NumLines := ANumLines;
  DbAddFile := DbFileCnt;
  Inc(DbFileCnt);
End;

{ ---- Ajouter une position source ----------------------------- }

Function DbAddLocation(AFileId, ASLine, ASCol,
                        AELine, AECol : Integer) : Integer;
Begin
  If DbLocationCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB locations table overflow');
    DbAddLocation := -1;
    Exit;
  End;
  DbLocations[DbLocationCnt].Id        := DbLocationCnt;
  DbLocations[DbLocationCnt].FileId    := AFileId;
  DbLocations[DbLocationCnt].StartLine := ASLine;
  DbLocations[DbLocationCnt].StartCol  := ASCol;
  DbLocations[DbLocationCnt].EndLine   := AELine;
  DbLocations[DbLocationCnt].EndCol    := AECol;
  DbAddLocation := DbLocationCnt;
  Inc(DbLocationCnt);
End;

{ ---- Ajouter une expression ---------------------------------- }

Function DbAddExpr(AKind : TDbExprKind; AParentId, ALocId,
                    ATypeId : Integer;
                    Const AValue : TString) : Integer;
Begin
  If DbExprCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB exprs table overflow');
    DbAddExpr := -1;
    Exit;
  End;
  DbExprs[DbExprCnt].Id       := DbExprCnt;
  DbExprs[DbExprCnt].Kind     := AKind;
  DbExprs[DbExprCnt].ParentId := AParentId;
  DbExprs[DbExprCnt].LocId    := ALocId;
  DbExprs[DbExprCnt].TypeId   := ATypeId;
  DbExprs[DbExprCnt].Value    := AValue;
  DbAddExpr := DbExprCnt;
  Inc(DbExprCnt);
End;

{ ---- Ajouter une instruction --------------------------------- }

Function DbAddStmt(AKind : TDbStmtKind;
                    AParentId, ALocId : Integer) : Integer;
Begin
  If DbStmtCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB stmts table overflow');
    DbAddStmt := -1;
    Exit;
  End;
  DbStmts[DbStmtCnt].Id       := DbStmtCnt;
  DbStmts[DbStmtCnt].Kind     := AKind;
  DbStmts[DbStmtCnt].ParentId := AParentId;
  DbStmts[DbStmtCnt].LocId    := ALocId;
  DbAddStmt := DbStmtCnt;
  Inc(DbStmtCnt);
End;

{ ---- Ajouter une fonction ou procedure ----------------------- }

Function DbAddFunction(Const AName : TString;
                        AParentId, ALocId,
                        ARetTypeId, ANumParams : Integer) : Integer;
Begin
  If DbFunctionCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB functions table overflow');
    DbAddFunction := -1;
    Exit;
  End;
  DbFunctions[DbFunctionCnt].Id           := DbFunctionCnt;
  DbFunctions[DbFunctionCnt].Name         := AName;
  DbFunctions[DbFunctionCnt].ParentId     := AParentId;
  DbFunctions[DbFunctionCnt].LocId        := ALocId;
  DbFunctions[DbFunctionCnt].ReturnTypeId := ARetTypeId;
  DbFunctions[DbFunctionCnt].NumParams    := ANumParams;
  DbAddFunction := DbFunctionCnt;
  Inc(DbFunctionCnt);
End;

{ ---- Ajouter une variable ------------------------------------ }

Function DbAddVariable(Const AName : TString;
                        AParentId, ALocId, ATypeId : Integer;
                        AIsParam : Boolean) : Integer;
Begin
  If DbVariableCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB variables table overflow');
    DbAddVariable := -1;
    Exit;
  End;
  DbVariables[DbVariableCnt].Id       := DbVariableCnt;
  DbVariables[DbVariableCnt].Name     := AName;
  DbVariables[DbVariableCnt].ParentId := AParentId;
  DbVariables[DbVariableCnt].LocId    := ALocId;
  DbVariables[DbVariableCnt].TypeId   := ATypeId;
  DbVariables[DbVariableCnt].IsParam  := AIsParam;
  DbAddVariable := DbVariableCnt;
  Inc(DbVariableCnt);
End;

{ ---- Ajouter un type ----------------------------------------- }

Function DbAddType(Const AName : TString;
                    AKind : TDbTypeKind;
                    ABaseTypeId : Integer) : Integer;
Begin
  If DbTypeCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB types table overflow');
    DbAddType := -1;
    Exit;
  End;
  DbTypes[DbTypeCnt].Id         := DbTypeCnt;
  DbTypes[DbTypeCnt].Name       := AName;
  DbTypes[DbTypeCnt].Kind       := AKind;
  DbTypes[DbTypeCnt].BaseTypeId := ABaseTypeId;
  DbAddType := DbTypeCnt;
  Inc(DbTypeCnt);
End;

{ ---- Ajouter un appel ---------------------------------------- }

Function DbAddCall(ACallerId, ATargetId, ALocId,
                    ANumArgs : Integer) : Integer;
Begin
  If DbCallCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB calls table overflow');
    DbAddCall := -1;
    Exit;
  End;
  DbCalls[DbCallCnt].Id       := DbCallCnt;
  DbCalls[DbCallCnt].CallerId := ACallerId;
  DbCalls[DbCallCnt].TargetId := ATargetId;
  DbCalls[DbCallCnt].LocId    := ALocId;
  DbCalls[DbCallCnt].NumArgs  := ANumArgs;
  DbAddCall := DbCallCnt;
  Inc(DbCallCnt);
End;

{ ---- Ajouter un acces a une variable ------------------------- }

Function DbAddAccess(AKind : TDbAccessKind;
                      AExprId, ATargetId, ALocId : Integer) : Integer;
Begin
  If DbAccessCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB accesses table overflow');
    DbAddAccess := -1;
    Exit;
  End;
  DbAccesses[DbAccessCnt].Id       := DbAccessCnt;
  DbAccesses[DbAccessCnt].Kind     := AKind;
  DbAccesses[DbAccessCnt].ExprId   := AExprId;
  DbAccesses[DbAccessCnt].TargetId := ATargetId;
  DbAccesses[DbAccessCnt].LocId    := ALocId;
  DbAddAccess := DbAccessCnt;
  Inc(DbAccessCnt);
End;

{ ---- Ajouter un commentaire ---------------------------------- }

Function DbAddComment(AFileId, ALocId : Integer;
                       Const AText : TString) : Integer;
Begin
  If DbCommentCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB comments table overflow');
    DbAddComment := -1;
    Exit;
  End;
  DbComments[DbCommentCnt].Id     := DbCommentCnt;
  DbComments[DbCommentCnt].FileId := AFileId;
  DbComments[DbCommentCnt].LocId  := ALocId;
  DbComments[DbCommentCnt].Text   := AText;
  DbAddComment := DbCommentCnt;
  Inc(DbCommentCnt);
End;

{ ---- Ajouter un diagnostic ----------------------------------- }

Function DbAddDiagnostic(ASeverity : TDbSeverity;
                          Const AMessage : TString;
                          AFileId, ALocId : Integer) : Integer;
Begin
  If DbDiagCnt >= MAX_DB_ROWS Then
  Begin
    WriteLn('CODEQL: DB diagnostics table overflow');
    DbAddDiagnostic := -1;
    Exit;
  End;
  DbDiags[DbDiagCnt].Id       := DbDiagCnt;
  DbDiags[DbDiagCnt].Severity := ASeverity;
  DbDiags[DbDiagCnt].Message  := AMessage;
  DbDiags[DbDiagCnt].FileId   := AFileId;
  DbDiags[DbDiagCnt].LocId    := ALocId;
  DbAddDiagnostic := DbDiagCnt;
  Inc(DbDiagCnt);
End;

{ ---- Recherche par nom dans la table functions --------------- }

Function DbFindFunction(Const AName : TString) : Integer;
Var I : Integer;
    Low : TString;
Begin
  Low := StrLowerCase(AName);
  DbFindFunction := -1;
  For I := 0 To DbFunctionCnt - 1 Do
    If StrLowerCase(DbFunctions[I].Name) = Low Then
    Begin
      DbFindFunction := I;
      Exit;
    End;
End;

{ ---- Recherche par nom dans la table variables --------------- }

Function DbFindVariable(Const AName : TString) : Integer;
Var I : Integer;
    Low : TString;
Begin
  Low := StrLowerCase(AName);
  DbFindVariable := -1;
  For I := 0 To DbVariableCnt - 1 Do
    If StrLowerCase(DbVariables[I].Name) = Low Then
    Begin
      DbFindVariable := I;
      Exit;
    End;
End;

{ ---- Recherche par nom dans la table types ------------------- }

Function DbFindType(Const AName : TString) : Integer;
Var I : Integer;
    Low : TString;
Begin
  Low := StrLowerCase(AName);
  DbFindType := -1;
  For I := 0 To DbTypeCnt - 1 Do
    If StrLowerCase(DbTypes[I].Name) = Low Then
    Begin
      DbFindType := I;
      Exit;
    End;
End;

{ ---- Recherche par nom dans la table files ------------------- }

Function DbFindFile(Const AName : TString) : Integer;
Var I : Integer;
Begin
  DbFindFile := -1;
  For I := 0 To DbFileCnt - 1 Do
    If DbFiles[I].Name = AName Then
    Begin
      DbFindFile := I;
      Exit;
    End;
End;

{ ---- Affichage du schema de la base de donnees --------------- }

Procedure DumpDbSchema;
Begin
  WriteLn('=== Schema de la base de donnees CodeQL ===');
  WriteLn;
  WriteLn('TABLE programs (');
  WriteLn('  id       INTEGER PRIMARY KEY,');
  WriteLn('  name     VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  filename VARCHAR(', MAX_DB_STR, ')');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE files (');
  WriteLn('  id       INTEGER PRIMARY KEY,');
  WriteLn('  name     VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  numlines INTEGER');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE locations (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  file_id   INTEGER REFERENCES files(id),');
  WriteLn('  startline INTEGER,');
  WriteLn('  startcol  INTEGER,');
  WriteLn('  endline   INTEGER,');
  WriteLn('  endcol    INTEGER');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE exprs (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  kind      INTEGER,');
  WriteLn('  parent_id INTEGER,');
  WriteLn('  loc_id    INTEGER REFERENCES locations(id),');
  WriteLn('  type_id   INTEGER REFERENCES types(id),');
  WriteLn('  value     VARCHAR(', MAX_DB_STR, ')');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE stmts (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  kind      INTEGER,');
  WriteLn('  parent_id INTEGER,');
  WriteLn('  loc_id    INTEGER REFERENCES locations(id)');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE functions (');
  WriteLn('  id             INTEGER PRIMARY KEY,');
  WriteLn('  name           VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  parent_id      INTEGER,');
  WriteLn('  loc_id         INTEGER REFERENCES locations(id),');
  WriteLn('  return_type_id INTEGER REFERENCES types(id),');
  WriteLn('  numparams      INTEGER');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE variables (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  name      VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  parent_id INTEGER,');
  WriteLn('  loc_id    INTEGER REFERENCES locations(id),');
  WriteLn('  type_id   INTEGER REFERENCES types(id),');
  WriteLn('  is_param  BOOLEAN');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE types (');
  WriteLn('  id           INTEGER PRIMARY KEY,');
  WriteLn('  name         VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  kind         INTEGER,');
  WriteLn('  base_type_id INTEGER REFERENCES types(id)');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE calls (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  caller_id INTEGER REFERENCES functions(id),');
  WriteLn('  target_id INTEGER REFERENCES functions(id),');
  WriteLn('  loc_id    INTEGER REFERENCES locations(id),');
  WriteLn('  numargs   INTEGER');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE accesses (');
  WriteLn('  id        INTEGER PRIMARY KEY,');
  WriteLn('  kind      INTEGER,');
  WriteLn('  expr_id   INTEGER REFERENCES exprs(id),');
  WriteLn('  target_id INTEGER REFERENCES variables(id),');
  WriteLn('  loc_id    INTEGER REFERENCES locations(id)');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE comments (');
  WriteLn('  id      INTEGER PRIMARY KEY,');
  WriteLn('  file_id INTEGER REFERENCES files(id),');
  WriteLn('  loc_id  INTEGER REFERENCES locations(id),');
  WriteLn('  text    VARCHAR(', MAX_DB_STR, ')');
  WriteLn(');');
  WriteLn;
  WriteLn('TABLE diagnostics (');
  WriteLn('  id       INTEGER PRIMARY KEY,');
  WriteLn('  severity INTEGER,');
  WriteLn('  message  VARCHAR(', MAX_DB_STR, '),');
  WriteLn('  file_id  INTEGER REFERENCES files(id),');
  WriteLn('  loc_id   INTEGER REFERENCES locations(id)');
  WriteLn(');');
  WriteLn;
End;

{ ---- Affichage du contenu de la base de donnees -------------- }

Procedure DumpDatabase;
Var I : Integer;
Begin
  WriteLn('=== Contenu de la base de donnees CodeQL ===');
  WriteLn;

  If DbProgramCnt > 0 Then
  Begin
    WriteLn('--- programs (', DbProgramCnt, ' lignes) ---');
    For I := 0 To DbProgramCnt - 1 Do
      WriteLn('  [', DbPrograms[I].Id, '] ',
              DbPrograms[I].Name, ' file="',
              DbPrograms[I].FileName, '"');
    WriteLn;
  End;

  If DbFileCnt > 0 Then
  Begin
    WriteLn('--- files (', DbFileCnt, ' lignes) ---');
    For I := 0 To DbFileCnt - 1 Do
      WriteLn('  [', DbFiles[I].Id, '] ',
              DbFiles[I].Name, ' lines=',
              DbFiles[I].NumLines);
    WriteLn;
  End;

  If DbLocationCnt > 0 Then
  Begin
    WriteLn('--- locations (', DbLocationCnt, ' lignes) ---');
    For I := 0 To DbLocationCnt - 1 Do
      WriteLn('  [', DbLocations[I].Id, '] file=',
              DbLocations[I].FileId, ' ',
              DbLocations[I].StartLine, ':',
              DbLocations[I].StartCol, '-',
              DbLocations[I].EndLine, ':',
              DbLocations[I].EndCol);
    WriteLn;
  End;

  If DbTypeCnt > 0 Then
  Begin
    WriteLn('--- types (', DbTypeCnt, ' lignes) ---');
    For I := 0 To DbTypeCnt - 1 Do
    Begin
      Write('  [', DbTypes[I].Id, '] ',
            DbTypes[I].Name, ' kind=',
            DbTypeKindName(DbTypes[I].Kind));
      If DbTypes[I].BaseTypeId >= 0 Then
        Write(' base=', DbTypes[I].BaseTypeId);
      WriteLn;
    End;
    WriteLn;
  End;

  If DbFunctionCnt > 0 Then
  Begin
    WriteLn('--- functions (', DbFunctionCnt, ' lignes) ---');
    For I := 0 To DbFunctionCnt - 1 Do
    Begin
      Write('  [', DbFunctions[I].Id, '] ',
            DbFunctions[I].Name,
            ' parent=', DbFunctions[I].ParentId,
            ' loc=', DbFunctions[I].LocId,
            ' params=', DbFunctions[I].NumParams);
      If DbFunctions[I].ReturnTypeId >= 0 Then
        Write(' ret=', DbFunctions[I].ReturnTypeId);
      WriteLn;
    End;
    WriteLn;
  End;

  If DbVariableCnt > 0 Then
  Begin
    WriteLn('--- variables (', DbVariableCnt, ' lignes) ---');
    For I := 0 To DbVariableCnt - 1 Do
    Begin
      Write('  [', DbVariables[I].Id, '] ',
            DbVariables[I].Name,
            ' parent=', DbVariables[I].ParentId,
            ' loc=', DbVariables[I].LocId,
            ' type=', DbVariables[I].TypeId);
      If DbVariables[I].IsParam Then
        Write(' [param]');
      WriteLn;
    End;
    WriteLn;
  End;

  If DbExprCnt > 0 Then
  Begin
    WriteLn('--- exprs (', DbExprCnt, ' lignes) ---');
    For I := 0 To DbExprCnt - 1 Do
      WriteLn('  [', DbExprs[I].Id, '] ',
              DbExprKindName(DbExprs[I].Kind),
              ' parent=', DbExprs[I].ParentId,
              ' loc=', DbExprs[I].LocId,
              ' type=', DbExprs[I].TypeId,
              ' val="', DbExprs[I].Value, '"');
    WriteLn;
  End;

  If DbStmtCnt > 0 Then
  Begin
    WriteLn('--- stmts (', DbStmtCnt, ' lignes) ---');
    For I := 0 To DbStmtCnt - 1 Do
      WriteLn('  [', DbStmts[I].Id, '] ',
              DbStmtKindName(DbStmts[I].Kind),
              ' parent=', DbStmts[I].ParentId,
              ' loc=', DbStmts[I].LocId);
    WriteLn;
  End;

  If DbCallCnt > 0 Then
  Begin
    WriteLn('--- calls (', DbCallCnt, ' lignes) ---');
    For I := 0 To DbCallCnt - 1 Do
      WriteLn('  [', DbCalls[I].Id, '] caller=',
              DbCalls[I].CallerId,
              ' target=', DbCalls[I].TargetId,
              ' loc=', DbCalls[I].LocId,
              ' args=', DbCalls[I].NumArgs);
    WriteLn;
  End;

  If DbAccessCnt > 0 Then
  Begin
    WriteLn('--- accesses (', DbAccessCnt, ' lignes) ---');
    For I := 0 To DbAccessCnt - 1 Do
      WriteLn('  [', DbAccesses[I].Id, '] ',
              DbAccessKindName(DbAccesses[I].Kind),
              ' expr=', DbAccesses[I].ExprId,
              ' target=', DbAccesses[I].TargetId,
              ' loc=', DbAccesses[I].LocId);
    WriteLn;
  End;

  If DbCommentCnt > 0 Then
  Begin
    WriteLn('--- comments (', DbCommentCnt, ' lignes) ---');
    For I := 0 To DbCommentCnt - 1 Do
      WriteLn('  [', DbComments[I].Id, '] file=',
              DbComments[I].FileId,
              ' loc=', DbComments[I].LocId,
              ' "', DbComments[I].Text, '"');
    WriteLn;
  End;

  If DbDiagCnt > 0 Then
  Begin
    WriteLn('--- diagnostics (', DbDiagCnt, ' lignes) ---');
    For I := 0 To DbDiagCnt - 1 Do
      WriteLn('  [', DbDiags[I].Id, '] ',
              DbSeverityName(DbDiags[I].Severity),
              ' file=', DbDiags[I].FileId,
              ' loc=', DbDiags[I].LocId,
              ' "', DbDiags[I].Message, '"');
    WriteLn;
  End;

  WriteLn('--- Resume ---');
  WriteLn('  programs   : ', DbProgramCnt);
  WriteLn('  files      : ', DbFileCnt);
  WriteLn('  locations  : ', DbLocationCnt);
  WriteLn('  types      : ', DbTypeCnt);
  WriteLn('  functions  : ', DbFunctionCnt);
  WriteLn('  variables  : ', DbVariableCnt);
  WriteLn('  exprs      : ', DbExprCnt);
  WriteLn('  stmts      : ', DbStmtCnt);
  WriteLn('  calls      : ', DbCallCnt);
  WriteLn('  accesses   : ', DbAccessCnt);
  WriteLn('  comments   : ', DbCommentCnt);
  WriteLn('  diagnostics: ', DbDiagCnt);
  WriteLn;
End;

{ ============================================================
  TODO 08 - STOCKAGE DE LA BASE DE DONNEES SUR DISQUE [IMPLEMENTE]
  ============================================================ }

{ ---- Creation du repertoire de la base de donnees ------------ }

Procedure DbCreateDir(Const DirPath : TString);
Begin
  {$I-}
  MkDir(DirPath);
  {$I+}
  If (IOResult <> 0) Then
  Begin
    { Le repertoire existe peut-etre deja, on ignore l erreur }
  End;
End;

{ ---- Ecriture de l en-tete binaire d un fichier table -------- }

Procedure DbWriteHeader(Var F : File; RowCount : Integer);
Var
  Sig : LongInt;
  Ver : Integer;
Begin
  Sig := DB_SIGNATURE;
  Ver := DB_VERSION;
  BlockWrite(F, Sig, SizeOf(Sig));
  BlockWrite(F, Ver, SizeOf(Ver));
  BlockWrite(F, RowCount, SizeOf(RowCount));
End;

{ ---- Lecture de l en-tete binaire d un fichier table ---------- }

Function DbReadHeader(Var F : File; Var RowCount : Integer) : Boolean;
Var
  Sig : LongInt;
  Ver : Integer;
Begin
  DbReadHeader := False;
  BlockRead(F, Sig, SizeOf(Sig));
  If Sig <> DB_SIGNATURE Then
  Begin
    WriteLn('CODEQL: signature invalide dans le fichier table');
    Exit;
  End;
  BlockRead(F, Ver, SizeOf(Ver));
  If Ver <> DB_VERSION Then
  Begin
    WriteLn('CODEQL: version incompatible (', Ver, ' vs ', DB_VERSION, ')');
    Exit;
  End;
  BlockRead(F, RowCount, SizeOf(RowCount));
  DbReadHeader := True;
End;

{ ---- Sauvegarde de la table programs ------------------------- }

Procedure DbSavePrograms(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_PROGRAMS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbProgramCnt);
  For I := 0 To DbProgramCnt - 1 Do
    BlockWrite(F, DbPrograms[I], SizeOf(TDbProgram));
  Close(F);
End;

{ ---- Chargement de la table programs ------------------------- }

Procedure DbLoadPrograms(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_PROGRAMS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbProgramCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbProgramCnt - 1 Do
    BlockRead(F, DbPrograms[I], SizeOf(TDbProgram));
  Close(F);
End;

{ ---- Sauvegarde de la table files ---------------------------- }

Procedure DbSaveFiles(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_FILES);
  Rewrite(F, 1);
  DbWriteHeader(F, DbFileCnt);
  For I := 0 To DbFileCnt - 1 Do
    BlockWrite(F, DbFiles[I], SizeOf(TDbFile));
  Close(F);
End;

{ ---- Chargement de la table files ---------------------------- }

Procedure DbLoadFiles(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_FILES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbFileCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbFileCnt - 1 Do
    BlockRead(F, DbFiles[I], SizeOf(TDbFile));
  Close(F);
End;

{ ---- Sauvegarde de la table locations ------------------------ }

Procedure DbSaveLocations(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_LOCATIONS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbLocationCnt);
  For I := 0 To DbLocationCnt - 1 Do
    BlockWrite(F, DbLocations[I], SizeOf(TDbLocation));
  Close(F);
End;

{ ---- Chargement de la table locations ------------------------ }

Procedure DbLoadLocations(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_LOCATIONS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbLocationCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbLocationCnt - 1 Do
    BlockRead(F, DbLocations[I], SizeOf(TDbLocation));
  Close(F);
End;

{ ---- Sauvegarde de la table exprs ---------------------------- }

Procedure DbSaveExprs(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_EXPRS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbExprCnt);
  For I := 0 To DbExprCnt - 1 Do
    BlockWrite(F, DbExprs[I], SizeOf(TDbExpr));
  Close(F);
End;

{ ---- Chargement de la table exprs ---------------------------- }

Procedure DbLoadExprs(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_EXPRS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbExprCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbExprCnt - 1 Do
    BlockRead(F, DbExprs[I], SizeOf(TDbExpr));
  Close(F);
End;

{ ---- Sauvegarde de la table stmts ---------------------------- }

Procedure DbSaveStmts(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_STMTS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbStmtCnt);
  For I := 0 To DbStmtCnt - 1 Do
    BlockWrite(F, DbStmts[I], SizeOf(TDbStmt));
  Close(F);
End;

{ ---- Chargement de la table stmts ---------------------------- }

Procedure DbLoadStmts(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_STMTS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbStmtCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbStmtCnt - 1 Do
    BlockRead(F, DbStmts[I], SizeOf(TDbStmt));
  Close(F);
End;

{ ---- Sauvegarde de la table functions ------------------------ }

Procedure DbSaveFunctions(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_FUNCTIONS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbFunctionCnt);
  For I := 0 To DbFunctionCnt - 1 Do
    BlockWrite(F, DbFunctions[I], SizeOf(TDbFunction));
  Close(F);
End;

{ ---- Chargement de la table functions ------------------------ }

Procedure DbLoadFunctions(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_FUNCTIONS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbFunctionCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbFunctionCnt - 1 Do
    BlockRead(F, DbFunctions[I], SizeOf(TDbFunction));
  Close(F);
End;

{ ---- Sauvegarde de la table variables ------------------------ }

Procedure DbSaveVariables(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_VARIABLES);
  Rewrite(F, 1);
  DbWriteHeader(F, DbVariableCnt);
  For I := 0 To DbVariableCnt - 1 Do
    BlockWrite(F, DbVariables[I], SizeOf(TDbVariable));
  Close(F);
End;

{ ---- Chargement de la table variables ------------------------ }

Procedure DbLoadVariables(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_VARIABLES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbVariableCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbVariableCnt - 1 Do
    BlockRead(F, DbVariables[I], SizeOf(TDbVariable));
  Close(F);
End;

{ ---- Sauvegarde de la table types ---------------------------- }

Procedure DbSaveTypes(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_TYPES);
  Rewrite(F, 1);
  DbWriteHeader(F, DbTypeCnt);
  For I := 0 To DbTypeCnt - 1 Do
    BlockWrite(F, DbTypes[I], SizeOf(TDbType));
  Close(F);
End;

{ ---- Chargement de la table types ---------------------------- }

Procedure DbLoadTypes(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_TYPES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbTypeCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbTypeCnt - 1 Do
    BlockRead(F, DbTypes[I], SizeOf(TDbType));
  Close(F);
End;

{ ---- Sauvegarde de la table calls ---------------------------- }

Procedure DbSaveCalls(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_CALLS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbCallCnt);
  For I := 0 To DbCallCnt - 1 Do
    BlockWrite(F, DbCalls[I], SizeOf(TDbCall));
  Close(F);
End;

{ ---- Chargement de la table calls ---------------------------- }

Procedure DbLoadCalls(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_CALLS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbCallCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbCallCnt - 1 Do
    BlockRead(F, DbCalls[I], SizeOf(TDbCall));
  Close(F);
End;

{ ---- Sauvegarde de la table accesses ------------------------- }

Procedure DbSaveAccesses(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_ACCESSES);
  Rewrite(F, 1);
  DbWriteHeader(F, DbAccessCnt);
  For I := 0 To DbAccessCnt - 1 Do
    BlockWrite(F, DbAccesses[I], SizeOf(TDbAccess));
  Close(F);
End;

{ ---- Chargement de la table accesses ------------------------- }

Procedure DbLoadAccesses(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_ACCESSES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbAccessCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbAccessCnt - 1 Do
    BlockRead(F, DbAccesses[I], SizeOf(TDbAccess));
  Close(F);
End;

{ ---- Sauvegarde de la table comments ------------------------- }

Procedure DbSaveComments(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_COMMENTS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbCommentCnt);
  For I := 0 To DbCommentCnt - 1 Do
    BlockWrite(F, DbComments[I], SizeOf(TDbComment));
  Close(F);
End;

{ ---- Chargement de la table comments ------------------------- }

Procedure DbLoadComments(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_COMMENTS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbCommentCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbCommentCnt - 1 Do
    BlockRead(F, DbComments[I], SizeOf(TDbComment));
  Close(F);
End;

{ ---- Sauvegarde de la table diagnostics ---------------------- }

Procedure DbSaveDiagnostics(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_DIAGS);
  Rewrite(F, 1);
  DbWriteHeader(F, DbDiagCnt);
  For I := 0 To DbDiagCnt - 1 Do
    BlockWrite(F, DbDiags[I], SizeOf(TDbDiagnostic));
  Close(F);
End;

{ ---- Chargement de la table diagnostics ---------------------- }

Procedure DbLoadDiagnostics(Const DirPath : TString);
Var F : File; I : Integer;
Begin
  Assign(F, DirPath + '/' + DB_FILE_DIAGS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, DbDiagCnt) Then Begin Close(F); Exit; End;
  For I := 0 To DbDiagCnt - 1 Do
    BlockRead(F, DbDiags[I], SizeOf(TDbDiagnostic));
  Close(F);
End;

{ ---- Sauvegarde complete de la base de donnees --------------- }

Procedure DbSaveDatabase(Const DirPath : TString);
Begin
  DbCreateDir(DirPath);
  DbSavePrograms(DirPath);
  DbSaveFiles(DirPath);
  DbSaveLocations(DirPath);
  DbSaveExprs(DirPath);
  DbSaveStmts(DirPath);
  DbSaveFunctions(DirPath);
  DbSaveVariables(DirPath);
  DbSaveTypes(DirPath);
  DbSaveCalls(DirPath);
  DbSaveAccesses(DirPath);
  DbSaveComments(DirPath);
  DbSaveDiagnostics(DirPath);
  WriteLn('Base de donnees sauvegardee dans: ', DirPath);
  WriteLn('  12 tables, ',
          DbProgramCnt + DbFileCnt + DbLocationCnt +
          DbExprCnt + DbStmtCnt + DbFunctionCnt +
          DbVariableCnt + DbTypeCnt + DbCallCnt +
          DbAccessCnt + DbCommentCnt + DbDiagCnt,
          ' enregistrements au total');
End;

{ ---- Chargement complet de la base de donnees ---------------- }

Procedure DbLoadDatabase(Const DirPath : TString);
Begin
  InitDatabase;
  DbLoadPrograms(DirPath);
  DbLoadFiles(DirPath);
  DbLoadLocations(DirPath);
  DbLoadExprs(DirPath);
  DbLoadStmts(DirPath);
  DbLoadFunctions(DirPath);
  DbLoadVariables(DirPath);
  DbLoadTypes(DirPath);
  DbLoadCalls(DirPath);
  DbLoadAccesses(DirPath);
  DbLoadComments(DirPath);
  DbLoadDiagnostics(DirPath);
  WriteLn('Base de donnees chargee depuis: ', DirPath);
  WriteLn('  12 tables, ',
          DbProgramCnt + DbFileCnt + DbLocationCnt +
          DbExprCnt + DbStmtCnt + DbFunctionCnt +
          DbVariableCnt + DbTypeCnt + DbCallCnt +
          DbAccessCnt + DbCommentCnt + DbDiagCnt,
          ' enregistrements au total');
End;

{ ---- Lecture aleatoire d un enregistrement par index --------- }

Function DbReadProgramAt(Const DirPath : TString;
                          Idx : Integer;
                          Var Rec : TDbProgram) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbReadProgramAt := False;
  Assign(F, DirPath + '/' + DB_FILE_PROGRAMS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbProgram);
  Seek(F, Ofs);
  BlockRead(F, Rec, SizeOf(TDbProgram));
  Close(F);
  DbReadProgramAt := True;
End;

Function DbReadFunctionAt(Const DirPath : TString;
                            Idx : Integer;
                            Var Rec : TDbFunction) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbReadFunctionAt := False;
  Assign(F, DirPath + '/' + DB_FILE_FUNCTIONS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbFunction);
  Seek(F, Ofs);
  BlockRead(F, Rec, SizeOf(TDbFunction));
  Close(F);
  DbReadFunctionAt := True;
End;

Function DbReadVariableAt(Const DirPath : TString;
                            Idx : Integer;
                            Var Rec : TDbVariable) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbReadVariableAt := False;
  Assign(F, DirPath + '/' + DB_FILE_VARIABLES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbVariable);
  Seek(F, Ofs);
  BlockRead(F, Rec, SizeOf(TDbVariable));
  Close(F);
  DbReadVariableAt := True;
End;

Function DbReadTypeAt(Const DirPath : TString;
                       Idx : Integer;
                       Var Rec : TDbType) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbReadTypeAt := False;
  Assign(F, DirPath + '/' + DB_FILE_TYPES);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbType);
  Seek(F, Ofs);
  BlockRead(F, Rec, SizeOf(TDbType));
  Close(F);
  DbReadTypeAt := True;
End;

{ ---- Ecriture aleatoire d un enregistrement par index -------- }

Function DbWriteProgramAt(Const DirPath : TString;
                            Idx : Integer;
                            Const Rec : TDbProgram) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbWriteProgramAt := False;
  Assign(F, DirPath + '/' + DB_FILE_PROGRAMS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbProgram);
  Seek(F, Ofs);
  BlockWrite(F, Rec, SizeOf(TDbProgram));
  Close(F);
  DbWriteProgramAt := True;
End;

Function DbWriteFunctionAt(Const DirPath : TString;
                             Idx : Integer;
                             Const Rec : TDbFunction) : Boolean;
Var F : File; Cnt : Integer; Ofs : LongInt;
Begin
  DbWriteFunctionAt := False;
  Assign(F, DirPath + '/' + DB_FILE_FUNCTIONS);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If Not DbReadHeader(F, Cnt) Then Begin Close(F); Exit; End;
  If (Idx < 0) Or (Idx >= Cnt) Then Begin Close(F); Exit; End;
  Ofs := SizeOf(LongInt) + SizeOf(Integer) + SizeOf(Integer)
       + LongInt(Idx) * SizeOf(TDbFunction);
  Seek(F, Ofs);
  BlockWrite(F, Rec, SizeOf(TDbFunction));
  Close(F);
  DbWriteFunctionAt := True;
End;

{ ============================================================
  TODO 09 - EXTRACTEUR : AST SOURCE -> BASE DE DONNEES [IMPLEMENTE]
  ============================================================ }

{ Variables globales de l extracteur }
Var
  ExtFileId   : Integer;   { identifiant du fichier courant      }
  ExtProgramId: Integer;   { identifiant du programme courant     }

{ ---- Creation d un enregistrement de position source ---------- }

Function ExtractLocation(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then
    ExtractLocation := -1
  Else
    ExtractLocation := DbAddLocation(ExtFileId,
      SrcNodes[Idx].Line, SrcNodes[Idx].Col,
      SrcNodes[Idx].Line, SrcNodes[Idx].Col);
End;

{ ---- Conversion TSrcNodeKind expression -> TDbExprKind -------- }

Function SrcExprKindToDb(K : TSrcNodeKind) : TDbExprKind;
Begin
  Case K Of
    SNK_EXPR_INT    : SrcExprKindToDb := DEK_INT_LIT;
    SNK_EXPR_FLOAT  : SrcExprKindToDb := DEK_FLOAT_LIT;
    SNK_EXPR_STRING : SrcExprKindToDb := DEK_STR_LIT;
    SNK_EXPR_IDENT  : SrcExprKindToDb := DEK_IDENT;
    SNK_EXPR_BINOP  : SrcExprKindToDb := DEK_BINOP;
    SNK_EXPR_UNOP   : SrcExprKindToDb := DEK_UNOP;
    SNK_EXPR_CALL   : SrcExprKindToDb := DEK_CALL;
    SNK_EXPR_INDEX  : SrcExprKindToDb := DEK_INDEX;
    SNK_EXPR_FIELD  : SrcExprKindToDb := DEK_FIELD;
    SNK_EXPR_DEREF  : SrcExprKindToDb := DEK_DEREF;
    SNK_EXPR_ADDR   : SrcExprKindToDb := DEK_ADDR;
    SNK_EXPR_NIL    : SrcExprKindToDb := DEK_NIL;
    SNK_EXPR_SET    : SrcExprKindToDb := DEK_SET;
    SNK_EXPR_RANGE  : SrcExprKindToDb := DEK_RANGE;
    SNK_C_SIZEOF    : SrcExprKindToDb := DEK_CALL;
    SNK_C_CAST      : SrcExprKindToDb := DEK_UNOP;
    SNK_C_TERNARY   : SrcExprKindToDb := DEK_BINOP;
  Else
    SrcExprKindToDb := DEK_NONE;
  End;
End;

{ ---- Conversion TSrcNodeKind instruction -> TDbStmtKind ------- }

Function SrcStmtKindToDb(K : TSrcNodeKind) : TDbStmtKind;
Begin
  Case K Of
    SNK_ASSIGN   : SrcStmtKindToDb := DSK_ASSIGN;
    SNK_CALL     : SrcStmtKindToDb := DSK_CALL;
    SNK_IF       : SrcStmtKindToDb := DSK_IF;
    SNK_WHILE    : SrcStmtKindToDb := DSK_WHILE;
    SNK_FOR      : SrcStmtKindToDb := DSK_FOR;
    SNK_REPEAT   : SrcStmtKindToDb := DSK_REPEAT;
    SNK_CASE     : SrcStmtKindToDb := DSK_CASE;
    SNK_WITH     : SrcStmtKindToDb := DSK_WITH;
    SNK_TRY      : SrcStmtKindToDb := DSK_TRY;
    SNK_RAISE    : SrcStmtKindToDb := DSK_RAISE;
    SNK_GOTO     : SrcStmtKindToDb := DSK_GOTO;
    SNK_COMPOUND : SrcStmtKindToDb := DSK_COMPOUND;
    SNK_BLOCK    : SrcStmtKindToDb := DSK_BLOCK;
    SNK_C_DO_WHILE   : SrcStmtKindToDb := DSK_REPEAT;
    SNK_C_SWITCH     : SrcStmtKindToDb := DSK_CASE;
    SNK_C_CASE_ITEM  : SrcStmtKindToDb := DSK_BLOCK;
    SNK_C_DEFAULT_ITEM : SrcStmtKindToDb := DSK_BLOCK;
    SNK_C_BREAK      : SrcStmtKindToDb := DSK_GOTO;
    SNK_C_CONTINUE   : SrcStmtKindToDb := DSK_GOTO;
    SNK_C_RETURN     : SrcStmtKindToDb := DSK_GOTO;
  Else
    SrcStmtKindToDb := DSK_NONE;
  End;
End;

{ ---- Conversion TSrcNodeKind type -> TDbTypeKind -------------- }

Function SrcTypeKindToDb(K : TSrcNodeKind) : TDbTypeKind;
Begin
  Case K Of
    SNK_TYPE_IDENT   : SrcTypeKindToDb := DTK_ALIAS;
    SNK_TYPE_ARRAY   : SrcTypeKindToDb := DTK_ARRAY;
    SNK_TYPE_RECORD  : SrcTypeKindToDb := DTK_RECORD;
    SNK_TYPE_POINTER : SrcTypeKindToDb := DTK_POINTER;
    SNK_TYPE_SET     : SrcTypeKindToDb := DTK_SET;
    SNK_TYPE_FILE    : SrcTypeKindToDb := DTK_FILE;
    SNK_TYPE_RANGE   : SrcTypeKindToDb := DTK_RANGE;
    SNK_TYPE_ENUM    : SrcTypeKindToDb := DTK_ENUM;
    SNK_TYPE_STRING  : SrcTypeKindToDb := DTK_STRING;
    SNK_C_STRUCT_DECL : SrcTypeKindToDb := DTK_RECORD;
    SNK_C_UNION_DECL  : SrcTypeKindToDb := DTK_RECORD;
    SNK_C_ENUM_DECL   : SrcTypeKindToDb := DTK_ENUM;
    SNK_C_TYPEDEF     : SrcTypeKindToDb := DTK_ALIAS;
  Else
    SrcTypeKindToDb := DTK_NONE;
  End;
End;

{ ---- Teste si un noeud est une expression --------------------- }

Function IsExprNode(K : TSrcNodeKind) : Boolean;
Begin
  IsExprNode := ((K >= SNK_EXPR_BINOP) And (K <= SNK_EXPR_RANGE)) Or
                (K = SNK_C_SIZEOF) Or (K = SNK_C_CAST) Or
                (K = SNK_C_TERNARY);
End;

{ ---- Teste si un noeud est une instruction -------------------- }

Function IsStmtNode(K : TSrcNodeKind) : Boolean;
Begin
  IsStmtNode := ((K >= SNK_ASSIGN) And (K <= SNK_COMPOUND)) Or
                (K = SNK_C_DO_WHILE) Or (K = SNK_C_SWITCH) Or
                (K = SNK_C_CASE_ITEM) Or (K = SNK_C_DEFAULT_ITEM) Or
                (K = SNK_C_BREAK) Or (K = SNK_C_CONTINUE) Or
                (K = SNK_C_RETURN);
End;

{ ---- Teste si un noeud est un type ---------------------------- }

Function IsTypeNode(K : TSrcNodeKind) : Boolean;
Begin
  IsTypeNode := ((K >= SNK_TYPE_IDENT) And (K <= SNK_TYPE_STRING)) Or
                (K = SNK_C_STRUCT_DECL) Or (K = SNK_C_UNION_DECL) Or
                (K = SNK_C_ENUM_DECL) Or (K = SNK_C_TYPEDEF);
End;

{ ---- Forward declaration pour l extraction recursive ---------- }

Function ExtractNode(Idx, ParentId : Integer) : Integer; Forward;

{ ---- Extraction d une expression ------------------------------ }

Function ExtractExpr(Idx, ParentId : Integer) : Integer;
Var LocId, ExprId : Integer;
    Val : TString;
Begin
  ExtractExpr := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  LocId := ExtractLocation(Idx);
  Val := SrcNodes[Idx].Name;
  ExprId := DbAddExpr(SrcExprKindToDb(SrcNodes[Idx].Kind),
                       ParentId, LocId, -1, Val);
  { Extraire les sous-expressions enfants }
  If SrcNodes[Idx].Left >= 0 Then
    ExtractNode(SrcNodes[Idx].Left, ExprId);
  If SrcNodes[Idx].Right >= 0 Then
    ExtractNode(SrcNodes[Idx].Right, ExprId);
  If SrcNodes[Idx].Extra >= 0 Then
    ExtractNode(SrcNodes[Idx].Extra, ExprId);
  ExtractExpr := ExprId;
End;

{ ---- Extraction d une instruction ----------------------------- }

Function ExtractStmt(Idx, ParentId : Integer) : Integer;
Var LocId, StmtId : Integer;
Begin
  ExtractStmt := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  LocId := ExtractLocation(Idx);
  StmtId := DbAddStmt(SrcStmtKindToDb(SrcNodes[Idx].Kind),
                        ParentId, LocId);
  { Extraire les enfants }
  If SrcNodes[Idx].Left >= 0 Then
    ExtractNode(SrcNodes[Idx].Left, StmtId);
  If SrcNodes[Idx].Right >= 0 Then
    ExtractNode(SrcNodes[Idx].Right, StmtId);
  If SrcNodes[Idx].Extra >= 0 Then
    ExtractNode(SrcNodes[Idx].Extra, StmtId);
  ExtractStmt := StmtId;
End;

{ ---- Extraction d une declaration de type --------------------- }

Function ExtractTypeDecl(Idx, ParentId : Integer) : Integer;
Var TypeId : Integer;
    K      : TDbTypeKind;
Begin
  ExtractTypeDecl := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  If SrcNodes[Idx].Kind = SNK_TYPE_DECL Then
  Begin
    K := DTK_ALIAS;
    { Si l enfant gauche est un noeud de type, utiliser sa sorte }
    If (SrcNodes[Idx].Left >= 0) And
       IsTypeNode(SrcNodes[SrcNodes[Idx].Left].Kind) Then
      K := SrcTypeKindToDb(SrcNodes[SrcNodes[Idx].Left].Kind);
    TypeId := DbAddType(SrcNodes[Idx].Name, K, -1);
    If SrcNodes[Idx].Left >= 0 Then
      ExtractNode(SrcNodes[Idx].Left, TypeId);
  End
  Else If IsTypeNode(SrcNodes[Idx].Kind) Then
  Begin
    K := SrcTypeKindToDb(SrcNodes[Idx].Kind);
    TypeId := DbAddType(SrcNodes[Idx].Name, K, -1);
    If SrcNodes[Idx].Left >= 0 Then
      ExtractNode(SrcNodes[Idx].Left, TypeId);
    If SrcNodes[Idx].Right >= 0 Then
      ExtractNode(SrcNodes[Idx].Right, TypeId);
  End
  Else
    TypeId := -1;
  ExtractTypeDecl := TypeId;
End;

{ ---- Extraction d une declaration de variable ----------------- }

Function ExtractVarDecl(Idx, ParentId : Integer) : Integer;
Var LocId, VarId : Integer;
    IsPar        : Boolean;
Begin
  ExtractVarDecl := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  LocId := ExtractLocation(Idx);
  IsPar := (SrcNodes[Idx].Kind = SNK_PARAM_DECL);
  VarId := DbAddVariable(SrcNodes[Idx].Name,
                           ParentId, LocId, -1, IsPar);
  { Extraire le type de la variable si present }
  If SrcNodes[Idx].Left >= 0 Then
    ExtractNode(SrcNodes[Idx].Left, VarId);
  ExtractVarDecl := VarId;
End;

{ ---- Extraction d une declaration de procedure/fonction ------- }

Function ExtractFuncDecl(Idx, ParentId : Integer) : Integer;
Var LocId, FuncId, NParams, ParamIdx : Integer;
    RetType : Integer;
Begin
  ExtractFuncDecl := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  LocId := ExtractLocation(Idx);
  { Compter les parametres dans la liste Left (chainage par Next) }
  NParams := 0;
  ParamIdx := SrcNodes[Idx].Left;
  While (ParamIdx >= 0) And (ParamIdx < SrcNodeCount) Do
  Begin
    If SrcNodes[ParamIdx].Kind = SNK_PARAM_DECL Then
      Inc(NParams);
    ParamIdx := SrcNodes[ParamIdx].Next;
  End;
  RetType := -1;
  If SrcNodes[Idx].Kind = SNK_FUNC_DECL Then
    RetType := 0;
  FuncId := DbAddFunction(SrcNodes[Idx].Name,
                            ParentId, LocId, RetType, NParams);
  { Extraire les parametres }
  If SrcNodes[Idx].Left >= 0 Then
    ExtractNode(SrcNodes[Idx].Left, FuncId);
  { Extraire le corps (Right = bloc) }
  If SrcNodes[Idx].Right >= 0 Then
    ExtractNode(SrcNodes[Idx].Right, FuncId);
  { Extraire le type de retour (Extra) }
  If SrcNodes[Idx].Extra >= 0 Then
    ExtractNode(SrcNodes[Idx].Extra, FuncId);
  ExtractFuncDecl := FuncId;
End;

{ ---- Extraction d une constante ------------------------------- }

Function ExtractConstDecl(Idx, ParentId : Integer) : Integer;
Var LocId, VarId : Integer;
Begin
  ExtractConstDecl := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  LocId := ExtractLocation(Idx);
  VarId := DbAddVariable(SrcNodes[Idx].Name,
                           ParentId, LocId, -1, False);
  If SrcNodes[Idx].Left >= 0 Then
    ExtractNode(SrcNodes[Idx].Left, VarId);
  ExtractConstDecl := VarId;
End;

{ ---- Extraction recursive d un noeud AST quelconque ----------- }

Function ExtractNode(Idx, ParentId : Integer) : Integer;
Var Id, SibIdx : Integer;
    K          : TSrcNodeKind;
Begin
  ExtractNode := -1;
  If (Idx < 0) Or (Idx >= SrcNodeCount) Then Exit;
  K := SrcNodes[Idx].Kind;

  { Dispatcher selon le type de noeud }
  If IsExprNode(K) Then
    Id := ExtractExpr(Idx, ParentId)
  Else If IsStmtNode(K) Or (K = SNK_BLOCK) Then
    Id := ExtractStmt(Idx, ParentId)
  Else If (K = SNK_PROC_DECL) Or (K = SNK_FUNC_DECL) Then
    Id := ExtractFuncDecl(Idx, ParentId)
  Else If (K = SNK_VAR_DECL) Or (K = SNK_PARAM_DECL) Then
    Id := ExtractVarDecl(Idx, ParentId)
  Else If (K = SNK_TYPE_DECL) Or IsTypeNode(K) Then
    Id := ExtractTypeDecl(Idx, ParentId)
  Else If K = SNK_CONST_DECL Then
    Id := ExtractConstDecl(Idx, ParentId)
  Else
  Begin
    { Noeuds generiques : program, unit, uses, case_item, etc. }
    Id := ParentId;
    If SrcNodes[Idx].Left >= 0 Then
      ExtractNode(SrcNodes[Idx].Left, Id);
    If SrcNodes[Idx].Right >= 0 Then
      ExtractNode(SrcNodes[Idx].Right, Id);
    If SrcNodes[Idx].Extra >= 0 Then
      ExtractNode(SrcNodes[Idx].Extra, Id);
  End;

  { Traiter le frere suivant (chainage par Next) }
  SibIdx := SrcNodes[Idx].Next;
  If (SibIdx >= 0) And (SibIdx < SrcNodeCount) Then
    ExtractNode(SibIdx, ParentId);

  ExtractNode := Id;
End;

{ ---- Point d entree : extraction complete de l AST ------------ }

Procedure ExtractSourceAST(Const FileName : TString);
Var LocId : Integer;
Begin
  InitDatabase;
  ExtProgramId := DbAddProgram(SrcNodes[SrcRootNode].Name, FileName);
  ExtFileId := DbAddFile(FileName, SrcTotalLines);
  LocId := DbAddLocation(ExtFileId, 1, 1,
                           SrcTotalLines, 1);
  ExtractNode(SrcRootNode, ExtProgramId);
  WriteLn('Extraction terminee :');
  WriteLn('  programmes  : ', DbProgramCnt);
  WriteLn('  fichiers    : ', DbFileCnt);
  WriteLn('  positions   : ', DbLocationCnt);
  WriteLn('  expressions : ', DbExprCnt);
  WriteLn('  instructions: ', DbStmtCnt);
  WriteLn('  fonctions   : ', DbFunctionCnt);
  WriteLn('  variables   : ', DbVariableCnt);
  WriteLn('  types       : ', DbTypeCnt);
  WriteLn('  appels      : ', DbCallCnt);
  WriteLn('  acces       : ', DbAccessCnt);
  WriteLn('  commentaires: ', DbCommentCnt);
  WriteLn('  diagnostics : ', DbDiagCnt);
  WriteLn;
End;

{ ============================================================
  TODO 10 - HIERARCHIE DE CLASSES QL ET HERITAGE [IMPLEMENTE]
  ============================================================ }

{ ---- Initialisation de la table des classes QL ---------------- }

Procedure InitClassHierarchy;
Begin
  QLClassCount := 0;
  QLPredCount  := 0;
End;

{ ---- Nom textuel d un drapeau de predicat --------------------- }

Function PredFlagName(F : TQLPredFlag) : TString;
Begin
  Case F Of
    QPF_NONE           : PredFlagName := '';
    QPF_OVERRIDE       : PredFlagName := 'override';
    QPF_ABSTRACT       : PredFlagName := 'abstract';
    QPF_PRIVATE        : PredFlagName := 'private';
    QPF_CHARACTERISTIC : PredFlagName := 'characteristic';
  End;
End;

{ ---- Enregistrer une classe QL -------------------------------- }

Function RegisterQLClass(Const AName : TString;
                         ATypeIdx, ANodeIdx : Integer;
                         AIsAbstract : Boolean) : Integer;
Begin
  If QLClassCount >= MAX_QL_CLASSES Then
  Begin
    WarnMsg('ClassHierarchy: depassement MAX_QL_CLASSES');
    RegisterQLClass := -1;
    Exit;
  End;
  QLClasses[QLClassCount].Name       := AName;
  QLClasses[QLClassCount].TypeIdx    := ATypeIdx;
  QLClasses[QLClassCount].BaseIdx    := -1;
  QLClasses[QLClassCount].NodeIdx    := ANodeIdx;
  QLClasses[QLClassCount].IsAbstract := AIsAbstract;
  QLClasses[QLClassCount].PredStart  := QLPredCount;
  QLClasses[QLClassCount].PredCount  := 0;
  RegisterQLClass := QLClassCount;
  Inc(QLClassCount);
End;

{ ---- Enregistrer un predicat de classe QL --------------------- }

Function RegisterQLPred(Const AName : TString;
                        AClassIdx, ANodeIdx : Integer;
                        AFlag : TQLPredFlag) : Integer;
Begin
  If QLPredCount >= MAX_QL_PREDS Then
  Begin
    WarnMsg('ClassHierarchy: depassement MAX_QL_PREDS');
    RegisterQLPred := -1;
    Exit;
  End;
  QLPreds[QLPredCount].Name       := AName;
  QLPreds[QLPredCount].ClassIdx   := AClassIdx;
  QLPreds[QLPredCount].Flag       := AFlag;
  QLPreds[QLPredCount].NodeIdx    := ANodeIdx;
  QLPreds[QLPredCount].RetTypeIdx := -1;
  QLPreds[QLPredCount].ParamCount := 0;
  RegisterQLPred := QLPredCount;
  Inc(QLPredCount);
  If (AClassIdx >= 0) And (AClassIdx < QLClassCount) Then
    Inc(QLClasses[AClassIdx].PredCount);
End;

{ ---- Rechercher une classe QL par nom ------------------------- }

Function FindQLClass(Const AName : TString) : Integer;
Var
  I   : Integer;
  Low : TString;
Begin
  Low := StrLowerCase(AName);
  For I := 0 To QLClassCount - 1 Do
  Begin
    If StrLowerCase(QLClasses[I].Name) = Low Then
    Begin
      FindQLClass := I;
      Exit;
    End;
  End;
  FindQLClass := -1;
End;

{ ---- Rechercher un predicat dans une classe ------------------- }

Function FindQLPredInClass(AClassIdx : Integer;
                           Const AName : TString) : Integer;
Var
  I, Start, Limit : Integer;
  Low : TString;
Begin
  FindQLPredInClass := -1;
  If (AClassIdx < 0) Or (AClassIdx >= QLClassCount) Then Exit;
  Low   := StrLowerCase(AName);
  Start := QLClasses[AClassIdx].PredStart;
  Limit := Start + QLClasses[AClassIdx].PredCount;
  For I := Start To Limit - 1 Do
  Begin
    If StrLowerCase(QLPreds[I].Name) = Low Then
    Begin
      FindQLPredInClass := I;
      Exit;
    End;
  End;
End;

{ ---- Resoudre la classe de base (extends) --------------------- }

Procedure ResolveBaseClass(CIdx : Integer);
Var BaseCI : Integer;
Begin
  If (CIdx < 0) Or (CIdx >= QLClassCount) Then Exit;
  If QLClasses[CIdx].NodeIdx < 0 Then Exit;
  { La classe de base est stockee dans Extra du noeud NK_CLASS_DECL }
  If Nodes[QLClasses[CIdx].NodeIdx].Extra >= 0 Then
  Begin
    BaseCI := FindQLClass(
      Nodes[Nodes[QLClasses[CIdx].NodeIdx].Extra].Name);
    If BaseCI >= 0 Then
      QLClasses[CIdx].BaseIdx := BaseCI
    Else
    Begin
      { Verifier si c est un type de reference intrinseque }
      If FindType(
        Nodes[Nodes[QLClasses[CIdx].NodeIdx].Extra].Name) >= 0 Then
        QLClasses[CIdx].BaseIdx := -1
      Else
        WarnMsg('classe "' + QLClasses[CIdx].Name +
                '": classe de base introuvable "' +
                Nodes[Nodes[QLClasses[CIdx].NodeIdx].Extra].Name +
                '"');
    End;
  End;
End;

{ ---- Detecter les cycles d heritage --------------------------- }

Function HasInheritanceCycle(CIdx : Integer) : Boolean;
Var
  Slow, Fast : Integer;
Begin
  HasInheritanceCycle := False;
  If (CIdx < 0) Or (CIdx >= QLClassCount) Then Exit;
  { Algorithme de Floyd (tortue et lievre) }
  Slow := CIdx;
  Fast := CIdx;
  While True Do
  Begin
    { La tortue avance d un pas }
    If QLClasses[Slow].BaseIdx >= 0 Then
      Slow := QLClasses[Slow].BaseIdx
    Else
      Exit;
    { Le lievre avance de deux pas }
    If QLClasses[Fast].BaseIdx >= 0 Then
      Fast := QLClasses[Fast].BaseIdx
    Else
      Exit;
    If QLClasses[Fast].BaseIdx >= 0 Then
      Fast := QLClasses[Fast].BaseIdx
    Else
      Exit;
    If Slow = Fast Then
    Begin
      HasInheritanceCycle := True;
      Exit;
    End;
  End;
End;

{ ---- Valider l heritage (cycles et coherence) ----------------- }

Procedure ValidateInheritance;
Var I : Integer;
Begin
  For I := 0 To QLClassCount - 1 Do
  Begin
    If HasInheritanceCycle(I) Then
      WarnMsg('classe "' + QLClasses[I].Name +
              '": cycle d''heritage detecte');
  End;
End;

{ ---- Verifier les predicats override -------------------------- }

Procedure CheckOverrides;
Var
  I, CIdx, ParentIdx, ParentPred : Integer;
Begin
  For I := 0 To QLPredCount - 1 Do
  Begin
    If QLPreds[I].Flag = QPF_OVERRIDE Then
    Begin
      CIdx := QLPreds[I].ClassIdx;
      If (CIdx < 0) Or (CIdx >= QLClassCount) Then Continue;
      ParentIdx := QLClasses[CIdx].BaseIdx;
      If ParentIdx < 0 Then
      Begin
        WarnMsg('override "' + QLPreds[I].Name +
                '" dans "' + QLClasses[CIdx].Name +
                '": pas de classe parent');
        Continue;
      End;
      { Chercher le predicat dans la chaine d heritage }
      ParentPred := -1;
      While (ParentIdx >= 0) And (ParentPred < 0) Do
      Begin
        ParentPred := FindQLPredInClass(ParentIdx,
                                         QLPreds[I].Name);
        If ParentPred < 0 Then
          ParentIdx := QLClasses[ParentIdx].BaseIdx;
      End;
      If ParentPred < 0 Then
        WarnMsg('override "' + QLPreds[I].Name +
                '" dans "' + QLClasses[CIdx].Name +
                '": predicat parent introuvable');
    End;
  End;
End;

{ ---- Verifier les predicats abstraits ------------------------- }

Procedure CheckAbstractPredicates;
Var
  I, J, Start, Limit : Integer;
Begin
  For I := 0 To QLClassCount - 1 Do
  Begin
    If QLClasses[I].IsAbstract Then Continue;
    { Pour les classes non abstraites, verifier que tous les
      predicats abstraits herites sont implementes }
    If QLClasses[I].BaseIdx < 0 Then Continue;
    Start := QLClasses[QLClasses[I].BaseIdx].PredStart;
    Limit := Start + QLClasses[QLClasses[I].BaseIdx].PredCount;
    For J := Start To Limit - 1 Do
    Begin
      If QLPreds[J].Flag = QPF_ABSTRACT Then
      Begin
        If FindQLPredInClass(I, QLPreds[J].Name) < 0 Then
          WarnMsg('classe "' + QLClasses[I].Name +
                  '": predicat abstrait "' + QLPreds[J].Name +
                  '" non implemente');
      End;
    End;
  End;
End;

{ ---- Identifier les predicats caracteristiques ---------------- }

Procedure ProcessCharPredicates;
Var
  I, Start, Limit, J : Integer;
Begin
  For I := 0 To QLClassCount - 1 Do
  Begin
    Start := QLClasses[I].PredStart;
    Limit := Start + QLClasses[I].PredCount;
    For J := Start To Limit - 1 Do
    Begin
      { Un predicat portant le meme nom que la classe est
        un predicat caracteristique }
      If StrLowerCase(QLPreds[J].Name) =
         StrLowerCase(QLClasses[I].Name) Then
        QLPreds[J].Flag := QPF_CHARACTERISTIC;
    End;
  End;
End;

{ ---- Compter les predicats herites d une classe --------------- }

Function CountInheritedPreds(CIdx : Integer) : Integer;
Var
  Cnt, ParIdx, Start, Limit, J : Integer;
Begin
  Cnt := 0;
  If (CIdx < 0) Or (CIdx >= QLClassCount) Then
  Begin
    CountInheritedPreds := 0;
    Exit;
  End;
  ParIdx := QLClasses[CIdx].BaseIdx;
  While ParIdx >= 0 Do
  Begin
    Start := QLClasses[ParIdx].PredStart;
    Limit := Start + QLClasses[ParIdx].PredCount;
    For J := Start To Limit - 1 Do
    Begin
      { Compter seulement s il n est pas surcharge localement }
      If FindQLPredInClass(CIdx, QLPreds[J].Name) < 0 Then
        Inc(Cnt);
    End;
    ParIdx := QLClasses[ParIdx].BaseIdx;
  End;
  CountInheritedPreds := Cnt;
End;

{ ---- Construire la hierarchie a partir de l AST QL ------------ }

Procedure BuildClassHierarchy;
Var
  Cur, MemberCur, CIdx : Integer;
  IsAbstract : Boolean;
  PFlag      : TQLPredFlag;
Begin
  InitClassHierarchy;
  If RootNode < 0 Then Exit;

  { Premiere passe : enregistrer toutes les classes }
  Cur := Nodes[RootNode].Left;
  While Cur >= 0 Do
  Begin
    If Nodes[Cur].Kind = NK_CLASS_DECL Then
    Begin
      { Detecter abstract class : si le premier membre est
        annote abstract, on considere la classe abstraite }
      IsAbstract := False;
      MemberCur := Nodes[Cur].Left;
      While MemberCur >= 0 Do
      Begin
        If (Nodes[MemberCur].Kind = NK_PRED_DECL) And
           (Nodes[MemberCur].Name = 'abstract') Then
          IsAbstract := True;
        MemberCur := Nodes[MemberCur].Next;
      End;
      CIdx := RegisterQLClass(Nodes[Cur].Name,
                                Nodes[Cur].TypeIdx,
                                Cur, IsAbstract);
      { Enregistrer les predicats membres }
      If CIdx >= 0 Then
      Begin
        MemberCur := Nodes[Cur].Left;
        While MemberCur >= 0 Do
        Begin
          If Nodes[MemberCur].Kind = NK_PRED_DECL Then
          Begin
            PFlag := QPF_NONE;
            RegisterQLPred(Nodes[MemberCur].Name,
                            CIdx, MemberCur, PFlag);
          End;
          MemberCur := Nodes[MemberCur].Next;
        End;
      End;
    End;
    Cur := Nodes[Cur].Next;
  End;

  { Deuxieme passe : resoudre les classes de base }
  For CIdx := 0 To QLClassCount - 1 Do
    ResolveBaseClass(CIdx);

  { Troisieme passe : identifier les predicats caracteristiques }
  ProcessCharPredicates;

  { Quatrieme passe : valider l heritage }
  ValidateInheritance;
  CheckOverrides;
  CheckAbstractPredicates;
End;

{ ---- Afficher la hierarchie de classes pour debug -------------- }

Procedure DumpClassHierarchy;
Var
  I, J, Start, Limit, InhCnt : Integer;
Begin
  WriteLn('=== Hierarchie de classes QL ===');
  WriteLn('Classes : ', QLClassCount);
  WriteLn('Predicats: ', QLPredCount);
  WriteLn;
  For I := 0 To QLClassCount - 1 Do
  Begin
    Write('  class ', QLClasses[I].Name);
    If QLClasses[I].IsAbstract Then
      Write(' [abstract]');
    If QLClasses[I].BaseIdx >= 0 Then
      Write(' extends ', QLClasses[QLClasses[I].BaseIdx].Name);
    WriteLn;
    Write('    type=', QLClasses[I].TypeIdx);
    InhCnt := CountInheritedPreds(I);
    WriteLn(' preds=', QLClasses[I].PredCount,
            ' inherited=', InhCnt);
    Start := QLClasses[I].PredStart;
    Limit := Start + QLClasses[I].PredCount;
    For J := Start To Limit - 1 Do
    Begin
      Write('      predicate ', QLPreds[J].Name);
      If QLPreds[J].Flag <> QPF_NONE Then
        Write(' [', PredFlagName(QLPreds[J].Flag), ']');
      WriteLn;
    End;
  End;
  WriteLn;
End;

{ ============================================================
  TODO 11 - MOTEUR D'EVALUATION DES PREDICATS QL [IMPLEMENTE]
  ============================================================ }

{ ---- Initialisation de l'environnement de liaisons --------- }

Procedure InitBindings;
Begin
  EvalBindCount := 0;
End;

{ ---- Lier une variable a une valeur ------------------------ }

Function BindVar(Const AName : TString; AValue : TBindingValue) : Boolean;
Begin
  If EvalBindCount >= MAX_BINDINGS Then
  Begin
    BindVar := False;
    Exit;
  End;
  EvalBindings[EvalBindCount].Name  := AName;
  EvalBindings[EvalBindCount].Value := AValue;
  Inc(EvalBindCount);
  BindVar := True;
End;

{ ---- Rechercher une variable dans l'environnement ---------- }

Function LookupVar(Const AName : TString; Var AValue : TBindingValue) : Boolean;
Var
  I : Integer;
  N : TString;
Begin
  N := StrLowerCase(AName);
  For I := EvalBindCount - 1 DownTo 0 Do
    If StrLowerCase(EvalBindings[I].Name) = N Then
    Begin
      AValue := EvalBindings[I].Value;
      LookupVar := True;
      Exit;
    End;
  LookupVar := False;
End;

{ ---- Creer une valeur de liaison --------------------------- }

Function MakeIntBinding(V : LongInt) : TBindingValue;
Var
  R : TBindingValue;
Begin
  R.Kind     := BK_INT;
  R.IntVal   := V;
  R.FloatVal := 0.0;
  R.StrVal   := '';
  R.RefTable := '';
  R.RefId    := -1;
  MakeIntBinding := R;
End;

Function MakeFloatBinding(V : Real) : TBindingValue;
Var
  R : TBindingValue;
Begin
  R.Kind     := BK_FLOAT;
  R.IntVal   := 0;
  R.FloatVal := V;
  R.StrVal   := '';
  R.RefTable := '';
  R.RefId    := -1;
  MakeFloatBinding := R;
End;

Function MakeStrBinding(Const V : TString) : TBindingValue;
Var
  R : TBindingValue;
Begin
  R.Kind     := BK_STRING;
  R.IntVal   := 0;
  R.FloatVal := 0.0;
  R.StrVal   := V;
  R.RefTable := '';
  R.RefId    := -1;
  MakeStrBinding := R;
End;

Function MakeDbRefBinding(Const ATable : TString; AId : Integer) : TBindingValue;
Var
  R : TBindingValue;
Begin
  R.Kind     := BK_DBREF;
  R.IntVal   := AId;
  R.FloatVal := 0.0;
  R.StrVal   := '';
  R.RefTable := ATable;
  R.RefId    := AId;
  MakeDbRefBinding := R;
End;

Function MakeNoneBinding : TBindingValue;
Var
  R : TBindingValue;
Begin
  R.Kind     := BK_NONE;
  R.IntVal   := 0;
  R.FloatVal := 0.0;
  R.StrVal   := '';
  R.RefTable := '';
  R.RefId    := -1;
  MakeNoneBinding := R;
End;

{ ---- Convertir une valeur en chaine pour affichage --------- }

Function BindingToStr(Const V : TBindingValue) : TString;
Var
  S : String[20];
Begin
  Case V.Kind Of
    BK_INT:
    Begin
      Str(V.IntVal, S);
      BindingToStr := S;
    End;
    BK_FLOAT:
    Begin
      Str(V.FloatVal:0:4, S);
      BindingToStr := S;
    End;
    BK_STRING:
      BindingToStr := '"' + V.StrVal + '"';
    BK_DBREF:
    Begin
      Str(V.RefId, S);
      BindingToStr := V.RefTable + '#' + S;
    End;
  Else
    BindingToStr := '(none)';
  End;
End;

{ ---- Comparer deux valeurs de liaison ---------------------- }

Function BindingEqual(Const A, B : TBindingValue) : Boolean;
Begin
  If A.Kind <> B.Kind Then
  Begin
    BindingEqual := False;
    Exit;
  End;
  Case A.Kind Of
    BK_INT:    BindingEqual := (A.IntVal = B.IntVal);
    BK_FLOAT:  BindingEqual := (Abs(A.FloatVal - B.FloatVal) < 1E-9);
    BK_STRING: BindingEqual := (A.StrVal = B.StrVal);
    BK_DBREF:  BindingEqual := (A.RefTable = B.RefTable) And
                               (A.RefId = B.RefId);
  Else
    BindingEqual := True;
  End;
End;

{ ---- Initialisation du jeu de resultats -------------------- }

Procedure InitResultSet;
Var
  I : Integer;
Begin
  EvalResults.NCols := 0;
  EvalResults.NRows := 0;
  For I := 0 To MAX_RESULT_COLS - 1 Do
    EvalResults.ColNames[I] := '';
End;

{ ---- Ajouter un nom de colonne au jeu de resultats --------- }

Procedure AddResultCol(Const AName : TString);
Begin
  If EvalResults.NCols < MAX_RESULT_COLS Then
  Begin
    EvalResults.ColNames[EvalResults.NCols] := AName;
    Inc(EvalResults.NCols);
  End;
End;

{ ---- Ajouter un tuple au jeu de resultats ------------------ }

Function AddResultTuple(Const T : TResultTuple) : Boolean;
Begin
  If EvalResults.NRows >= MAX_RESULT_ROWS Then
  Begin
    AddResultTuple := False;
    Exit;
  End;
  EvalResults.Rows[EvalResults.NRows] := T;
  Inc(EvalResults.NRows);
  AddResultTuple := True;
End;

{ ---- Afficher le jeu de resultats -------------------------- }

Procedure DumpResultSet;
Var
  I, J : Integer;
Begin
  WriteLn('--- Resultats : ', EvalResults.NRows, ' tuples, ',
          EvalResults.NCols, ' colonnes ---');
  { en-tete }
  For J := 0 To EvalResults.NCols - 1 Do
  Begin
    If J > 0 Then Write(' | ');
    Write(EvalResults.ColNames[J]);
  End;
  WriteLn;
  For J := 0 To EvalResults.NCols - 1 Do
  Begin
    If J > 0 Then Write('-+-');
    Write('----------');
  End;
  WriteLn;
  { lignes }
  For I := 0 To EvalResults.NRows - 1 Do
  Begin
    For J := 0 To EvalResults.Rows[I].NCols - 1 Do
    Begin
      If J > 0 Then Write(' | ');
      Write(BindingToStr(EvalResults.Rows[I].Cols[J]));
    End;
    WriteLn;
  End;
  WriteLn;
End;

{ ---- Nombre de lignes dans une table DB par nom ------------ }

Function TableRowCount(Const TName : TString) : Integer;
Var
  N : TString;
Begin
  N := StrLowerCase(TName);
  If N = 'functions'   Then TableRowCount := DbFunctionCnt
  Else If N = 'variables' Then TableRowCount := DbVariableCnt
  Else If N = 'types'     Then TableRowCount := DbTypeCnt
  Else If N = 'exprs'     Then TableRowCount := DbExprCnt
  Else If N = 'stmts'     Then TableRowCount := DbStmtCnt
  Else If N = 'programs'  Then TableRowCount := DbProgramCnt
  Else If N = 'files'     Then TableRowCount := DbFileCnt
  Else If N = 'locations' Then TableRowCount := DbLocationCnt
  Else If N = 'calls'     Then TableRowCount := DbCallCnt
  Else If N = 'accesses'  Then TableRowCount := DbAccessCnt
  Else If N = 'comments'  Then TableRowCount := DbCommentCnt
  Else If N = 'diagnostics' Then TableRowCount := DbDiagCnt
  Else TableRowCount := 0;
End;

{ ---- Recuperer un champ d un enregistrement DB ------------- }

Function GetDbField(Const TName : TString; RowIdx : Integer;
                    Const FName : TString) : TBindingValue;
Var
  NT, NF : TString;
Begin
  NT := StrLowerCase(TName);
  NF := StrLowerCase(FName);
  GetDbField := MakeNoneBinding;

  If NT = 'functions' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbFunctionCnt) Then Exit;
    If NF = 'id'           Then GetDbField := MakeIntBinding(DbFunctions[RowIdx].Id)
    Else If NF = 'name'    Then GetDbField := MakeStrBinding(DbFunctions[RowIdx].Name)
    Else If NF = 'parentid' Then GetDbField := MakeIntBinding(DbFunctions[RowIdx].ParentId)
    Else If NF = 'locid'   Then GetDbField := MakeIntBinding(DbFunctions[RowIdx].LocId)
    Else If NF = 'returntypeid' Then GetDbField := MakeIntBinding(DbFunctions[RowIdx].ReturnTypeId)
    Else If NF = 'numparams' Then GetDbField := MakeIntBinding(DbFunctions[RowIdx].NumParams);
  End
  Else If NT = 'variables' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbVariableCnt) Then Exit;
    If NF = 'id'           Then GetDbField := MakeIntBinding(DbVariables[RowIdx].Id)
    Else If NF = 'name'    Then GetDbField := MakeStrBinding(DbVariables[RowIdx].Name)
    Else If NF = 'parentid' Then GetDbField := MakeIntBinding(DbVariables[RowIdx].ParentId)
    Else If NF = 'locid'   Then GetDbField := MakeIntBinding(DbVariables[RowIdx].LocId)
    Else If NF = 'typeid'  Then GetDbField := MakeIntBinding(DbVariables[RowIdx].TypeId);
  End
  Else If NT = 'types' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbTypeCnt) Then Exit;
    If NF = 'id'            Then GetDbField := MakeIntBinding(DbTypes[RowIdx].Id)
    Else If NF = 'name'     Then GetDbField := MakeStrBinding(DbTypes[RowIdx].Name)
    Else If NF = 'kind'     Then GetDbField := MakeIntBinding(Ord(DbTypes[RowIdx].Kind))
    Else If NF = 'basetypeid' Then GetDbField := MakeIntBinding(DbTypes[RowIdx].BaseTypeId);
  End
  Else If NT = 'exprs' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbExprCnt) Then Exit;
    If NF = 'id'           Then GetDbField := MakeIntBinding(DbExprs[RowIdx].Id)
    Else If NF = 'kind'    Then GetDbField := MakeIntBinding(Ord(DbExprs[RowIdx].Kind))
    Else If NF = 'parentid' Then GetDbField := MakeIntBinding(DbExprs[RowIdx].ParentId)
    Else If NF = 'locid'   Then GetDbField := MakeIntBinding(DbExprs[RowIdx].LocId)
    Else If NF = 'typeid'  Then GetDbField := MakeIntBinding(DbExprs[RowIdx].TypeId)
    Else If NF = 'value'   Then GetDbField := MakeStrBinding(DbExprs[RowIdx].Value);
  End
  Else If NT = 'stmts' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbStmtCnt) Then Exit;
    If NF = 'id'            Then GetDbField := MakeIntBinding(DbStmts[RowIdx].Id)
    Else If NF = 'kind'     Then GetDbField := MakeIntBinding(Ord(DbStmts[RowIdx].Kind))
    Else If NF = 'parentid' Then GetDbField := MakeIntBinding(DbStmts[RowIdx].ParentId)
    Else If NF = 'locid'    Then GetDbField := MakeIntBinding(DbStmts[RowIdx].LocId);
  End
  Else If NT = 'programs' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbProgramCnt) Then Exit;
    If NF = 'id'            Then GetDbField := MakeIntBinding(DbPrograms[RowIdx].Id)
    Else If NF = 'name'     Then GetDbField := MakeStrBinding(DbPrograms[RowIdx].Name)
    Else If NF = 'filename' Then GetDbField := MakeStrBinding(DbPrograms[RowIdx].FileName);
  End
  Else If NT = 'files' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbFileCnt) Then Exit;
    If NF = 'id'            Then GetDbField := MakeIntBinding(DbFiles[RowIdx].Id)
    Else If NF = 'name'     Then GetDbField := MakeStrBinding(DbFiles[RowIdx].Name)
    Else If NF = 'numlines' Then GetDbField := MakeIntBinding(DbFiles[RowIdx].NumLines);
  End
  Else If NT = 'calls' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbCallCnt) Then Exit;
    If NF = 'id'            Then GetDbField := MakeIntBinding(DbCalls[RowIdx].Id)
    Else If NF = 'callerid' Then GetDbField := MakeIntBinding(DbCalls[RowIdx].CallerId)
    Else If NF = 'targetid' Then GetDbField := MakeIntBinding(DbCalls[RowIdx].TargetId)
    Else If NF = 'locid'    Then GetDbField := MakeIntBinding(DbCalls[RowIdx].LocId)
    Else If NF = 'numargs'  Then GetDbField := MakeIntBinding(DbCalls[RowIdx].NumArgs);
  End;
End;

{ ---- Mapper un nom de type QL vers un nom de table DB ------ }

Function QLTypeToTable(Const TName : TString) : TString;
Var
  N : TString;
Begin
  N := StrLowerCase(TName);
  If (N = 'function') Or (N = '@function') Then QLTypeToTable := 'functions'
  Else If (N = 'variable') Or (N = '@variable') Then QLTypeToTable := 'variables'
  Else If (N = 'type') Or (N = '@type') Then QLTypeToTable := 'types'
  Else If (N = 'expr') Or (N = '@expr') Then QLTypeToTable := 'exprs'
  Else If (N = 'stmt') Or (N = '@stmt') Then QLTypeToTable := 'stmts'
  Else If (N = 'call') Then QLTypeToTable := 'calls'
  Else If (N = 'file') Then QLTypeToTable := 'files'
  Else If (N = 'program') Then QLTypeToTable := 'programs'
  Else If (N = 'comment') Then QLTypeToTable := 'comments'
  Else If (N = 'diagnostic') Then QLTypeToTable := 'diagnostics'
  Else QLTypeToTable := N;
End;

{ ---- Forward declarations pour les fonctions d agregation -- }

Function EvalExprValue(NIdx : Integer) : TBindingValue; Forward;
Function MatchesFilter(NIdx : Integer) : Boolean; Forward;

{ ============================================================
  TODO 15 - FONCTIONS D AGREGATION QL [IMPLEMENTE]
  ============================================================ }

{ ---- Nom textuel d un type d agregation -------------------- }

Function AggrKindName(K : TAggrKind) : TString;
Begin
  Case K Of
    AGG_COUNT       : AggrKindName := 'count';
    AGG_SUM         : AggrKindName := 'sum';
    AGG_MIN         : AggrKindName := 'min';
    AGG_MAX         : AggrKindName := 'max';
    AGG_AVG         : AggrKindName := 'avg';
    AGG_RANK        : AggrKindName := 'rank';
    AGG_CONCAT      : AggrKindName := 'concat';
    AGG_STRICTCOUNT : AggrKindName := 'strictcount';
    AGG_STRICTSUM   : AggrKindName := 'strictsum';
    AGG_STRICTCONCAT: AggrKindName := 'strictconcat';
  Else
    AggrKindName := '?aggr?';
  End;
End;

{ ---- Convertir un nom en TAggrKind ------------------------- }

Function ParseAggrKindStr(Const S : TString) : TAggrKind;
Var
  N : TString;
Begin
  N := StrLowerCase(S);
  If N = 'count'       Then ParseAggrKindStr := AGG_COUNT
  Else If N = 'sum'         Then ParseAggrKindStr := AGG_SUM
  Else If N = 'min'         Then ParseAggrKindStr := AGG_MIN
  Else If N = 'max'         Then ParseAggrKindStr := AGG_MAX
  Else If N = 'avg'         Then ParseAggrKindStr := AGG_AVG
  Else If N = 'rank'        Then ParseAggrKindStr := AGG_RANK
  Else If N = 'concat'      Then ParseAggrKindStr := AGG_CONCAT
  Else If N = 'strictcount' Then ParseAggrKindStr := AGG_STRICTCOUNT
  Else If N = 'strictsum'   Then ParseAggrKindStr := AGG_STRICTSUM
  Else If N = 'strictconcat'Then ParseAggrKindStr := AGG_STRICTCONCAT
  Else ParseAggrKindStr := AGG_COUNT;
End;

{ ---- Initialiser un accumulateur d agregation -------------- }

Procedure AggrAccumInit(Var Acc : TAggrAccum; K : TAggrKind);
Begin
  Acc.Kind     := K;
  Acc.IntSum   := 0;
  Acc.FloatSum := 0.0;
  Acc.IntMin   := MaxLongInt;
  Acc.IntMax   := -MaxLongInt;
  Acc.StrAccum := '';
  Acc.Count    := 0;
  Acc.HasValue := False;
  Acc.Separator:= ', ';
  Acc.RankPos  := 0;
End;

{ ---- Alimenter un accumulateur avec une valeur ------------- }

Procedure AggrAccumFeed(Var Acc : TAggrAccum;
                        Const V : TBindingValue);
Begin
  If V.Kind = BK_NONE Then
  Begin
    { strict* : BK_NONE invalide l accumulateur }
    If (Acc.Kind = AGG_STRICTCOUNT) Or
       (Acc.Kind = AGG_STRICTSUM) Or
       (Acc.Kind = AGG_STRICTCONCAT) Then
    Begin
      Acc.HasValue := False;
      Acc.Count    := -1;
    End;
    Exit;
  End;

  If Acc.Count < 0 Then Exit;  { deja invalide par strict }

  Inc(Acc.Count);
  Acc.HasValue := True;

  Case Acc.Kind Of
    AGG_COUNT, AGG_STRICTCOUNT:
      Inc(Acc.IntSum);

    AGG_SUM, AGG_STRICTSUM:
    Begin
      If V.Kind = BK_INT Then
        Acc.IntSum := Acc.IntSum + V.IntVal
      Else If V.Kind = BK_FLOAT Then
        Acc.FloatSum := Acc.FloatSum + V.FloatVal;
    End;

    AGG_MIN:
    Begin
      If V.Kind = BK_INT Then
      Begin
        If V.IntVal < Acc.IntMin Then
          Acc.IntMin := V.IntVal;
      End
      Else If V.Kind = BK_FLOAT Then
      Begin
        If V.FloatVal < Acc.FloatSum Then
          Acc.FloatSum := V.FloatVal
        Else If Not Acc.HasValue Then
          Acc.FloatSum := V.FloatVal;
      End;
    End;

    AGG_MAX:
    Begin
      If V.Kind = BK_INT Then
      Begin
        If V.IntVal > Acc.IntMax Then
          Acc.IntMax := V.IntVal;
      End
      Else If V.Kind = BK_FLOAT Then
      Begin
        If V.FloatVal > Acc.FloatSum Then
          Acc.FloatSum := V.FloatVal
        Else If Not Acc.HasValue Then
          Acc.FloatSum := V.FloatVal;
      End;
    End;

    AGG_AVG:
    Begin
      If V.Kind = BK_INT Then
        Acc.FloatSum := Acc.FloatSum + V.IntVal
      Else If V.Kind = BK_FLOAT Then
        Acc.FloatSum := Acc.FloatSum + V.FloatVal;
    End;

    AGG_RANK:
      Inc(Acc.RankPos);

    AGG_CONCAT, AGG_STRICTCONCAT:
    Begin
      If V.Kind = BK_STRING Then
      Begin
        If Acc.StrAccum <> '' Then
          Acc.StrAccum := Acc.StrAccum + Acc.Separator;
        Acc.StrAccum := Acc.StrAccum + V.StrVal;
      End
      Else
      Begin
        If Acc.StrAccum <> '' Then
          Acc.StrAccum := Acc.StrAccum + Acc.Separator;
        Acc.StrAccum := Acc.StrAccum + BindingToStr(V);
      End;
    End;
  End;
End;

{ ---- Finaliser un accumulateur et retourner le resultat ---- }

Function AggrAccumFinalize(Const Acc : TAggrAccum) : TBindingValue;
Begin
  If (Not Acc.HasValue) Or (Acc.Count < 0) Then
  Begin
    AggrAccumFinalize := MakeNoneBinding;
    Exit;
  End;

  Case Acc.Kind Of
    AGG_COUNT, AGG_STRICTCOUNT:
      AggrAccumFinalize := MakeIntBinding(Acc.IntSum);

    AGG_SUM, AGG_STRICTSUM:
    Begin
      If Acc.FloatSum <> 0.0 Then
        AggrAccumFinalize := MakeFloatBinding(
                               Acc.FloatSum + Acc.IntSum)
      Else
        AggrAccumFinalize := MakeIntBinding(Acc.IntSum);
    End;

    AGG_MIN:
    Begin
      If Acc.IntMin < MaxLongInt Then
        AggrAccumFinalize := MakeIntBinding(Acc.IntMin)
      Else
        AggrAccumFinalize := MakeFloatBinding(Acc.FloatSum);
    End;

    AGG_MAX:
    Begin
      If Acc.IntMax > -MaxLongInt Then
        AggrAccumFinalize := MakeIntBinding(Acc.IntMax)
      Else
        AggrAccumFinalize := MakeFloatBinding(Acc.FloatSum);
    End;

    AGG_AVG:
    Begin
      If Acc.Count > 0 Then
        AggrAccumFinalize := MakeFloatBinding(
                               Acc.FloatSum / Acc.Count)
      Else
        AggrAccumFinalize := MakeNoneBinding;
    End;

    AGG_RANK:
      AggrAccumFinalize := MakeIntBinding(Acc.RankPos);

    AGG_CONCAT, AGG_STRICTCONCAT:
      AggrAccumFinalize := MakeStrBinding(Acc.StrAccum);
  Else
    AggrAccumFinalize := MakeNoneBinding;
  End;
End;

{ ---- Evaluer une expression d agregation (NK_EXPR_AGGR) ---- }

Function EvalAggrExpr(NIdx : Integer) : TBindingValue;
Var
  Acc  : TAggrAccum;
  Kind : TAggrKind;
  LVal : TBindingValue;
  TblRows : LongInt;
  TblName : TString;
Begin
  EvalAggrExpr := MakeNoneBinding;
  If (NIdx < 0) Or (NIdx >= NodeCount) Then Exit;

  Kind := ParseAggrKindStr(Nodes[NIdx].Name);
  AggrAccumInit(Acc, Kind);

  { Si l agregation porte sur un sous-arbre (Left = variable decl) }
  If Nodes[NIdx].Left >= 0 Then
  Begin
    { Evaluer l expression enfant }
    LVal := EvalExprValue(Nodes[NIdx].Left);

    { count/strictcount sur un type -> nombre de lignes }
    If (Kind = AGG_COUNT) Or (Kind = AGG_STRICTCOUNT) Then
    Begin
      If LVal.Kind = BK_STRING Then
      Begin
        TblName := QLTypeToTable(LVal.StrVal);
        TblRows := TableRowCount(TblName);
        EvalAggrExpr := MakeIntBinding(TblRows);
        Exit;
      End;
    End;

    { Pour les autres : accumuler la valeur unique }
    AggrAccumFeed(Acc, LVal);

    { Si un filtre (Right) est present et satisfait, accumuler }
    If Nodes[NIdx].Right >= 0 Then
    Begin
      If MatchesFilter(Nodes[NIdx].Right) Then
        AggrAccumFeed(Acc, LVal);
    End;

    EvalAggrExpr := AggrAccumFinalize(Acc);
  End
  Else
  Begin
    { count() sans argument -> 0 }
    If (Kind = AGG_COUNT) Or (Kind = AGG_STRICTCOUNT) Then
      EvalAggrExpr := MakeIntBinding(0)
    Else
      EvalAggrExpr := MakeNoneBinding;
  End;
End;

{ ---- Initialiser les structures d agregation --------------- }

Procedure InitAggregation;
Var
  I : Integer;
Begin
  AggrGroupCnt := 0;
  OrderByCount := 0;
  GroupByCount := 0;
  For I := 0 To MAX_AGGR_GROUPS - 1 Do
    AggrAccumInit(AggrAccums[I], AGG_COUNT);
  For I := 0 To MAX_ORDER_BY - 1 Do
  Begin
    OrderByCols[I].ColIdx    := -1;
    OrderByCols[I].Ascending := True;
    GroupByExprs[I]          := -1;
  End;
End;

{ ---- Tester si deux cles group by sont identiques ---------- }

Function GroupByMatch(Const A, B : TGroupByKey) : Boolean;
Var
  I : Integer;
Begin
  GroupByMatch := False;
  If A.NCols <> B.NCols Then Exit;
  For I := 0 To A.NCols - 1 Do
    If Not BindingEqual(A.Cols[I], B.Cols[I]) Then Exit;
  GroupByMatch := True;
End;

{ ---- Trier le jeu de resultats selon order by -------------- }

Procedure SortResultSet;
Var
  I, J, K   : Integer;
  Swapped   : Boolean;
  TmpRow    : TResultTuple;
  OIdx, CIdx: Integer;
  VA, VB    : TBindingValue;
  Cmp       : Integer;
Begin
  If OrderByCount = 0 Then Exit;
  If EvalResults.NRows <= 1 Then Exit;

  { Tri a bulles stable }
  For I := 0 To EvalResults.NRows - 2 Do
  Begin
    Swapped := False;
    For J := 0 To EvalResults.NRows - 2 - I Do
    Begin
      Cmp := 0;
      For K := 0 To OrderByCount - 1 Do
      Begin
        OIdx := OrderByCols[K].ColIdx;
        { OIdx est un index AST; on l utilise comme index de colonne }
        If (OIdx >= 0) And (OIdx < NodeCount) Then
          CIdx := K
        Else
          CIdx := K;
        If CIdx >= EvalResults.NCols Then CIdx := 0;

        VA := EvalResults.Rows[J].Cols[CIdx];
        VB := EvalResults.Rows[J + 1].Cols[CIdx];

        If (VA.Kind = BK_INT) And (VB.Kind = BK_INT) Then
        Begin
          If VA.IntVal < VB.IntVal Then Cmp := -1
          Else If VA.IntVal > VB.IntVal Then Cmp := 1
          Else Cmp := 0;
        End
        Else If (VA.Kind = BK_FLOAT) And (VB.Kind = BK_FLOAT) Then
        Begin
          If VA.FloatVal < VB.FloatVal Then Cmp := -1
          Else If VA.FloatVal > VB.FloatVal Then Cmp := 1
          Else Cmp := 0;
        End
        Else If (VA.Kind = BK_STRING) And (VB.Kind = BK_STRING) Then
        Begin
          If VA.StrVal < VB.StrVal Then Cmp := -1
          Else If VA.StrVal > VB.StrVal Then Cmp := 1
          Else Cmp := 0;
        End;

        If Not OrderByCols[K].Ascending Then
          Cmp := -Cmp;

        If Cmp <> 0 Then Break;
      End;

      If Cmp > 0 Then
      Begin
        TmpRow := EvalResults.Rows[J];
        EvalResults.Rows[J] := EvalResults.Rows[J + 1];
        EvalResults.Rows[J + 1] := TmpRow;
        Swapped := True;
      End;
    End;
    If Not Swapped Then Break;
  End;
End;

{ ---- Appliquer le group by avec agregation ----------------- }

Procedure ApplyGroupBy;
Var
  I, J, GIdx : Integer;
  Key        : TGroupByKey;
  Found      : Boolean;
  SrcRow     : TResultTuple;
  GrpRows    : Array[0..MAX_AGGR_GROUPS - 1] Of TResultTuple;
  GrpCount   : Integer;
Begin
  If GroupByCount = 0 Then Exit;
  If EvalResults.NRows = 0 Then Exit;

  GrpCount := 0;

  For I := 0 To EvalResults.NRows - 1 Do
  Begin
    SrcRow := EvalResults.Rows[I];

    { Construire la cle group by }
    Key.NCols := GroupByCount;
    For J := 0 To GroupByCount - 1 Do
    Begin
      If J < SrcRow.NCols Then
        Key.Cols[J] := SrcRow.Cols[J]
      Else
        Key.Cols[J] := MakeNoneBinding;
    End;

    { Chercher un groupe existant }
    Found := False;
    For GIdx := 0 To GrpCount - 1 Do
    Begin
      If GroupByMatch(Key, AggrGroupKeys[GIdx]) Then
      Begin
        Found := True;
        { Incrementer le compteur du groupe }
        AggrAccumFeed(AggrAccums[GIdx], MakeIntBinding(1));
        Break;
      End;
    End;

    { Nouveau groupe }
    If (Not Found) And (GrpCount < MAX_AGGR_GROUPS) Then
    Begin
      AggrGroupKeys[GrpCount] := Key;
      AggrAccumInit(AggrAccums[GrpCount], AGG_COUNT);
      AggrAccumFeed(AggrAccums[GrpCount], MakeIntBinding(1));
      GrpRows[GrpCount] := SrcRow;
      Inc(GrpCount);
    End;
  End;

  { Remplacer le result set par les groupes }
  EvalResults.NRows := GrpCount;
  For I := 0 To GrpCount - 1 Do
    EvalResults.Rows[I] := GrpRows[I];
End;

{ ---- Appliquer order by au jeu de resultats ---------------- }

Procedure ApplyOrderBy;
Begin
  If OrderByCount > 0 Then
    SortResultSet;
End;

{ ---- Afficher les parametres d agregation (debug) ---------- }

Procedure DumpAggregations;
Var
  I : Integer;
Begin
  WriteLn('--- Agregations ---');
  WriteLn('  GroupByCount : ', GroupByCount);
  WriteLn('  OrderByCount : ', OrderByCount);
  WriteLn('  AggrGroupCnt : ', AggrGroupCnt);
  For I := 0 To AggrGroupCnt - 1 Do
    WriteLn('  G', I, ' ', AggrKindName(AggrAccums[I].Kind),
            ' cnt=', AggrAccums[I].Count,
            ' sum=', AggrAccums[I].IntSum,
            ' has=', AggrAccums[I].HasValue);
  WriteLn;
End;

{ ---- Evaluer une expression QL en TBindingValue ------------ }

Function EvalExprValue(NIdx : Integer) : TBindingValue;
Var
  LVal, RVal : TBindingValue;
  BV         : TBindingValue;
Begin
  EvalExprValue := MakeNoneBinding;
  If (NIdx < 0) Or (NIdx >= NodeCount) Then Exit;
  Case Nodes[NIdx].Kind Of
    NK_EXPR_INT:
      EvalExprValue := MakeIntBinding(Nodes[NIdx].IntVal);
    NK_EXPR_FLOAT:
      EvalExprValue := MakeFloatBinding(Nodes[NIdx].FloatVal);
    NK_EXPR_STRING:
      EvalExprValue := MakeStrBinding(Nodes[NIdx].Name);
    NK_EXPR_IDENT:
    Begin
      If LookupVar(Nodes[NIdx].Name, BV) Then
        EvalExprValue := BV
      Else
        EvalExprValue := MakeStrBinding(Nodes[NIdx].Name);
    End;
    NK_EXPR_MEMBER:
    Begin
      { obj.field : evaluer obj, puis recuperer le champ }
      LVal := EvalExprValue(Nodes[NIdx].Left);
      If LVal.Kind = BK_DBREF Then
        EvalExprValue := GetDbField(LVal.RefTable, LVal.RefId,
                                    Nodes[NIdx].Name)
      Else
        EvalExprValue := MakeNoneBinding;
    End;
    NK_EXPR_BINOP:
    Begin
      LVal := EvalExprValue(Nodes[NIdx].Left);
      RVal := EvalExprValue(Nodes[NIdx].Right);
      If (LVal.Kind = BK_INT) And (RVal.Kind = BK_INT) Then
      Begin
        If Nodes[NIdx].Name = '+' Then
          EvalExprValue := MakeIntBinding(LVal.IntVal + RVal.IntVal)
        Else If Nodes[NIdx].Name = '-' Then
          EvalExprValue := MakeIntBinding(LVal.IntVal - RVal.IntVal)
        Else If Nodes[NIdx].Name = '*' Then
          EvalExprValue := MakeIntBinding(LVal.IntVal * RVal.IntVal)
        Else If Nodes[NIdx].Name = '=' Then
        Begin
          If LVal.IntVal = RVal.IntVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End
        Else If Nodes[NIdx].Name = '!=' Then
        Begin
          If LVal.IntVal <> RVal.IntVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End
        Else If Nodes[NIdx].Name = '<' Then
        Begin
          If LVal.IntVal < RVal.IntVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End
        Else If Nodes[NIdx].Name = '>' Then
        Begin
          If LVal.IntVal > RVal.IntVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End;
      End
      Else If (LVal.Kind = BK_STRING) And (RVal.Kind = BK_STRING) Then
      Begin
        If Nodes[NIdx].Name = '=' Then
        Begin
          If LVal.StrVal = RVal.StrVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End
        Else If Nodes[NIdx].Name = '!=' Then
        Begin
          If LVal.StrVal <> RVal.StrVal Then
            EvalExprValue := MakeIntBinding(1)
          Else
            EvalExprValue := MakeIntBinding(0);
        End
        Else If Nodes[NIdx].Name = '+' Then
          EvalExprValue := MakeStrBinding(LVal.StrVal + RVal.StrVal);
      End;
    End;
    NK_EXPR_CALL:
    Begin
      { count(...) retourne le nombre de lignes dans la table }
      If StrLowerCase(Nodes[NIdx].Name) = 'count' Then
      Begin
        LVal := EvalExprValue(Nodes[NIdx].Left);
        If LVal.Kind = BK_STRING Then
          EvalExprValue := MakeIntBinding(TableRowCount(
                              QLTypeToTable(LVal.StrVal)))
        Else
          EvalExprValue := MakeIntBinding(0);
      End;
    End;
    NK_EXPR_AGGR:
    Begin
      EvalExprValue := EvalAggrExpr(NIdx);
    End;
    NK_EXPR_THIS:
    Begin
      If LookupVar('this', BV) Then
        EvalExprValue := BV;
    End;
    NK_EXPR_RESULT:
    Begin
      If LookupVar('result', BV) Then
        EvalExprValue := BV;
    End;
  End;
End;

{ ---- Tester si une formule where est satisfaite ------------ }

Function MatchesFilter(NIdx : Integer) : Boolean;
Var
  LVal       : TBindingValue;
  BV         : TBindingValue;
  SavedCount : Integer;
  I, Cnt     : Integer;
  TblName    : TString;
Begin
  MatchesFilter := True;
  If (NIdx < 0) Or (NIdx >= NodeCount) Then Exit;

  Case Nodes[NIdx].Kind Of
    NK_FORMULA_AND:
    Begin
      MatchesFilter := MatchesFilter(Nodes[NIdx].Left) And
                        MatchesFilter(Nodes[NIdx].Right);
    End;
    NK_FORMULA_OR:
    Begin
      MatchesFilter := MatchesFilter(Nodes[NIdx].Left) Or
                        MatchesFilter(Nodes[NIdx].Right);
    End;
    NK_FORMULA_NOT:
    Begin
      MatchesFilter := Not MatchesFilter(Nodes[NIdx].Left);
    End;
    NK_FORMULA_EXISTS:
    Begin
      { exists(Type v | formula) : verifier s il existe au moins un v }
      MatchesFilter := False;
      If Nodes[NIdx].Left >= 0 Then
      Begin
        TblName := QLTypeToTable(Nodes[Nodes[NIdx].Left].Name);
        Cnt := TableRowCount(TblName);
        SavedCount := EvalBindCount;
        For I := 0 To Cnt - 1 Do
        Begin
          EvalBindCount := SavedCount;
          BV := MakeDbRefBinding(TblName, I);
          If Nodes[Nodes[NIdx].Left].Kind = NK_VAR_DECL Then
            BindVar(Nodes[Nodes[NIdx].Left].Name, BV);
          If MatchesFilter(Nodes[NIdx].Right) Then
          Begin
            MatchesFilter := True;
            EvalBindCount := SavedCount;
            Exit;
          End;
        End;
        EvalBindCount := SavedCount;
      End;
    End;
    NK_FORMULA_FORALL:
    Begin
      { forall(Type v | guard | formula) : verifier pour tous }
      MatchesFilter := True;
      If Nodes[NIdx].Left >= 0 Then
      Begin
        TblName := QLTypeToTable(Nodes[Nodes[NIdx].Left].Name);
        Cnt := TableRowCount(TblName);
        SavedCount := EvalBindCount;
        For I := 0 To Cnt - 1 Do
        Begin
          EvalBindCount := SavedCount;
          BV := MakeDbRefBinding(TblName, I);
          If Nodes[Nodes[NIdx].Left].Kind = NK_VAR_DECL Then
            BindVar(Nodes[Nodes[NIdx].Left].Name, BV);
          If MatchesFilter(Nodes[NIdx].Extra) Then
          Begin
            If Not MatchesFilter(Nodes[NIdx].Right) Then
            Begin
              MatchesFilter := False;
              EvalBindCount := SavedCount;
              Exit;
            End;
          End;
        End;
        EvalBindCount := SavedCount;
      End;
    End;
    NK_EXPR_BINOP,
    NK_EXPR_CALL:
    Begin
      LVal := EvalExprValue(NIdx);
      MatchesFilter := (LVal.Kind = BK_INT) And (LVal.IntVal <> 0);
    End;
  Else
    { expression quelconque : evaluer comme booleen }
    LVal := EvalExprValue(NIdx);
    If LVal.Kind = BK_INT Then
      MatchesFilter := (LVal.IntVal <> 0)
    Else
      MatchesFilter := (LVal.Kind <> BK_NONE);
  End;
End;

{ ---- Evaluer les jointures from d un select ---------------- }

Procedure EvalFromJoin(SelectIdx : Integer;
                       FromList  : Integer;
                       WhereIdx  : Integer;
                       SelectExprs : Integer);

  Procedure CollectSelectExprs(NIdx : Integer; Var T : TResultTuple);
  Var
    V : TBindingValue;
    Cur : Integer;
  Begin
    T.NCols := 0;
    Cur := NIdx;
    While (Cur >= 0) And (Cur < NodeCount) Do
    Begin
      V := EvalExprValue(Cur);
      If T.NCols < MAX_RESULT_COLS Then
      Begin
        T.Cols[T.NCols] := V;
        Inc(T.NCols);
      End;
      Cur := Nodes[Cur].Next;
    End;
  End;

  Procedure JoinRecursive(FromIdx : Integer);
  Var
    TblName : TString;
    VarName : TString;
    I, Cnt  : Integer;
    SavedBind : Integer;
    BV : TBindingValue;
    T  : TResultTuple;
  Begin
    If (FromIdx < 0) Or (FromIdx >= NodeCount) Then
    Begin
      { toutes les variables from sont liees : tester le where }
      If MatchesFilter(WhereIdx) Then
      Begin
        { collecter les expressions select }
        CollectSelectExprs(SelectExprs, T);
        AddResultTuple(T);
      End;
      Exit;
    End;

    { FromIdx pointe vers un NK_FROM_DECL ou NK_VAR_DECL }
    TblName := QLTypeToTable(Nodes[FromIdx].Name);
    Cnt := TableRowCount(TblName);

    { Le nom de la variable est dans le fils gauche (NK_VAR_DECL) }
    If Nodes[FromIdx].Left >= 0 Then
      VarName := Nodes[Nodes[FromIdx].Left].Name
    Else
      VarName := Nodes[FromIdx].Name;

    SavedBind := EvalBindCount;
    For I := 0 To Cnt - 1 Do
    Begin
      EvalBindCount := SavedBind;
      BV := MakeDbRefBinding(TblName, I);
      BindVar(VarName, BV);
      JoinRecursive(Nodes[FromIdx].Next);
    End;
    EvalBindCount := SavedBind;
  End;

Begin
  JoinRecursive(FromList);
End;

{ ---- Evaluer un noeud select-from-where -------------------- }

Procedure EvalSelect(NIdx : Integer);
Var
  FromList, WhereIdx, SelectExprs : Integer;
  Cur, ColIdx : Integer;
Begin
  If (NIdx < 0) Or (NIdx >= NodeCount) Then Exit;
  If Nodes[NIdx].Kind <> NK_SELECT Then Exit;

  InitResultSet;
  InitBindings;
  InitAggregation;

  { Structure du NK_SELECT :
    Left  = premier NK_FROM_DECL (chaine via Next)
    Right = formule where (-1 si absente)
    Extra = premier expression select (chaine via Next) }
  FromList    := Nodes[NIdx].Left;
  WhereIdx    := Nodes[NIdx].Right;
  SelectExprs := Nodes[NIdx].Extra;

  { collecter les noms de colonnes a partir des expressions select }
  ColIdx := 0;
  Cur := SelectExprs;
  While (Cur >= 0) And (Cur < NodeCount) Do
  Begin
    If ColIdx < MAX_RESULT_COLS Then
    Begin
      If Nodes[Cur].Name <> '' Then
        AddResultCol(Nodes[Cur].Name)
      Else
        AddResultCol('col' + Chr(Ord('0') + ColIdx));
      Inc(ColIdx);
    End;
    Cur := Nodes[Cur].Next;
  End;

  { evaluer les jointures et collecter les resultats }
  EvalFromJoin(NIdx, FromList, WhereIdx, SelectExprs);

  { appliquer group by puis order by (TODO 15) }
  ApplyGroupBy;
  ApplyOrderBy;
End;

{ ---- Evaluer un predicat non-recursif ---------------------- }

Function EvalPredicate(PredIdx : Integer) : Boolean;
Var
  Body : Integer;
Begin
  EvalPredicate := False;
  If (PredIdx < 0) Or (PredIdx >= NodeCount) Then Exit;
  If Nodes[PredIdx].Kind <> NK_PRED_DECL Then Exit;

  { Le corps du predicat est dans Extra (formule ou select) }
  Body := Nodes[PredIdx].Extra;
  If Body < 0 Then Exit;

  If Nodes[Body].Kind = NK_SELECT Then
    EvalSelect(Body)
  Else
  Begin
    { predicat booleen : evaluer la formule }
    InitResultSet;
    InitBindings;
    EvalPredicate := MatchesFilter(Body);
  End;
  EvalPredicate := True;
End;

{ ---- Point d'entree : evaluer une requete QL --------------- }

Procedure EvalQuery(RootIdx : Integer);
Var
  Cur : Integer;
Begin
  If (RootIdx < 0) Or (RootIdx >= NodeCount) Then Exit;

  { Parcourir les enfants du module pour trouver les select }
  Cur := Nodes[RootIdx].Left;
  While (Cur >= 0) And (Cur < NodeCount) Do
  Begin
    Case Nodes[Cur].Kind Of
      NK_SELECT:
      Begin
        EvalSelect(Cur);
        DumpResultSet;
      End;
      NK_PRED_DECL:
      Begin
        { Evaluer uniquement si le predicat est marque comme requete }
        { (dans un vrai CodeQL, seul le select principal est evalue) }
      End;
    End;
    Cur := Nodes[Cur].Next;
  End;
End;

{ ---- Afficher les liaisons courantes pour debug ------------ }

Procedure DumpBindings;
Var
  I : Integer;
Begin
  WriteLn('--- Liaisons : ', EvalBindCount, ' variables ---');
  For I := 0 To EvalBindCount - 1 Do
    WriteLn('  ', EvalBindings[I].Name, ' = ',
            BindingToStr(EvalBindings[I].Value));
  WriteLn;
End;

{ ============================================================
  TODO 16 - REQUETES RECURSIVES [IMPLEMENTE]
  ============================================================ }

{ ---- Initialiser les structures de recursion ---------------- }

Procedure InitRecursion;
Var
  I : Integer;
Begin
  RecDepCount  := 0;
  RecSCCCount  := 0;
  RecStrataCnt := 0;
  RecFPCount   := 0;
  RecTotalIter := 0;
  For I := 0 To MAX_REC_PREDS - 1 Do
  Begin
    RecSCCs[I].SCCId    := -1;
    RecSCCs[I].IsRecurs := False;
    RecPredSCC[I]       := -1;
  End;
  For I := 0 To MAX_REC_DEPS - 1 Do
  Begin
    RecDeps[I].FromPred := -1;
    RecDeps[I].ToPred   := -1;
    RecDeps[I].IsNeg    := False;
  End;
  For I := 0 To MAX_REC_STRATA - 1 Do
  Begin
    RecStrata[I].PredCnt := 0;
    RecStrata[I].Level   := 0;
    RecStrata[I].HasNeg  := False;
  End;
End;

{ ---- Ajouter une dependance entre deux predicats ------------ }

Procedure AddRecDep(FromP, ToP : Integer; Neg : Boolean);
Begin
  If RecDepCount >= MAX_REC_DEPS Then Exit;
  RecDeps[RecDepCount].FromPred := FromP;
  RecDeps[RecDepCount].ToPred   := ToP;
  RecDeps[RecDepCount].IsNeg    := Neg;
  Inc(RecDepCount);
End;

{ ---- Trouver un predicat par nom dans QLPreds --------------- }

Function RecFindPredByName(Const AName : TString) : Integer;
Var
  I : Integer;
  N : TString;
Begin
  RecFindPredByName := -1;
  N := StrLowerCase(AName);
  For I := 0 To QLPredCount - 1 Do
    If StrLowerCase(QLPreds[I].Name) = N Then
    Begin
      RecFindPredByName := I;
      Exit;
    End;
End;

{ ---- Scanner un noeud AST pour trouver les appels ----------- }
{ Parcourt l AST QL et detecte les NK_EXPR_CALL qui referent   }
{ a des predicats enregistres. UnderNeg indique si on est sous }
{ une negation (NOT).                                           }

Procedure ScanCallsInNode(PredOwner, NIdx : Integer; UnderNeg : Boolean);
Var
  CalledPred : Integer;
  Child      : Integer;
Begin
  If (NIdx < 0) Or (NIdx >= NodeCount) Then Exit;

  Case Nodes[NIdx].Kind Of
    NK_EXPR_CALL:
    Begin
      { Verifier si le nom de la fonction appelee est un predicat connu }
      CalledPred := RecFindPredByName(Nodes[NIdx].Name);
      If CalledPred >= 0 Then
        AddRecDep(PredOwner, CalledPred, UnderNeg);
      { scanner aussi les arguments }
      Child := Nodes[NIdx].Left;
      While (Child >= 0) And (Child < NodeCount) Do
      Begin
        ScanCallsInNode(PredOwner, Child, UnderNeg);
        Child := Nodes[Child].Next;
      End;
    End;

    NK_FORMULA_NOT:
    Begin
      { Sous negation : inverser le drapeau }
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, True);
    End;

    NK_FORMULA_AND, NK_FORMULA_OR, NK_FORMULA_IMPLIES:
    Begin
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, UnderNeg);
      ScanCallsInNode(PredOwner, Nodes[NIdx].Right, UnderNeg);
    End;

    NK_FORMULA_EXISTS, NK_FORMULA_FORALL, NK_FORMULA_IF:
    Begin
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, UnderNeg);
      ScanCallsInNode(PredOwner, Nodes[NIdx].Right, UnderNeg);
      If Nodes[NIdx].Extra >= 0 Then
        ScanCallsInNode(PredOwner, Nodes[NIdx].Extra, UnderNeg);
    End;

    NK_SELECT:
    Begin
      { Scanner from, where et select }
      Child := Nodes[NIdx].Left;
      While (Child >= 0) And (Child < NodeCount) Do
      Begin
        ScanCallsInNode(PredOwner, Child, UnderNeg);
        Child := Nodes[Child].Next;
      End;
      ScanCallsInNode(PredOwner, Nodes[NIdx].Right, UnderNeg);
      Child := Nodes[NIdx].Extra;
      While (Child >= 0) And (Child < NodeCount) Do
      Begin
        ScanCallsInNode(PredOwner, Child, UnderNeg);
        Child := Nodes[Child].Next;
      End;
    End;

    NK_EXPR_BINOP, NK_EXPR_MEMBER:
    Begin
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, UnderNeg);
      ScanCallsInNode(PredOwner, Nodes[NIdx].Right, UnderNeg);
    End;

    NK_EXPR_UNOP:
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, UnderNeg);

    NK_EXPR_AGGR:
    Begin
      ScanCallsInNode(PredOwner, Nodes[NIdx].Left, UnderNeg);
      ScanCallsInNode(PredOwner, Nodes[NIdx].Right, UnderNeg);
      If Nodes[NIdx].Extra >= 0 Then
        ScanCallsInNode(PredOwner, Nodes[NIdx].Extra, UnderNeg);
    End;
  End; { case }
End;

{ ---- Construire le graphe de dependances entre predicats ---- }

Procedure BuildPredDepGraph;
Var
  I    : Integer;
  Body : Integer;
Begin
  RecDepCount := 0;
  For I := 0 To QLPredCount - 1 Do
  Begin
    { Retrouver le corps du predicat via le noeud AST }
    If QLPreds[I].NodeIdx < 0 Then Continue;
    If QLPreds[I].NodeIdx >= NodeCount Then Continue;
    Body := Nodes[QLPreds[I].NodeIdx].Right;
    If Body < 0 Then
      Body := Nodes[QLPreds[I].NodeIdx].Extra;
    If Body >= 0 Then
      ScanCallsInNode(I, Body, False);
  End;
End;

{ ---- Algorithme de Tarjan pour trouver les SCC -------------- }
{ (Strongly Connected Components : composantes fortement        }
{  connexes dans le graphe de dependances)                      }

Var
  TarjStack    : Array[0..MAX_REC_PREDS - 1] Of Integer;
  TarjStackTop : Integer;
  TarjIndex    : Array[0..MAX_REC_PREDS - 1] Of Integer;
  TarjLowLink  : Array[0..MAX_REC_PREDS - 1] Of Integer;
  TarjOnStack  : Array[0..MAX_REC_PREDS - 1] Of Boolean;
  TarjCounter  : Integer;
  TarjSCCId    : Integer;

Procedure TarjPush(V : Integer);
Begin
  If TarjStackTop < MAX_REC_PREDS Then
  Begin
    TarjStack[TarjStackTop] := V;
    Inc(TarjStackTop);
    TarjOnStack[V] := True;
  End;
End;

Function TarjPop : Integer;
Begin
  If TarjStackTop > 0 Then
  Begin
    Dec(TarjStackTop);
    TarjPop := TarjStack[TarjStackTop];
    TarjOnStack[TarjStack[TarjStackTop]] := False;
  End
  Else
    TarjPop := -1;
End;

Procedure TarjStrongConnect(V : Integer); Forward;

Procedure TarjStrongConnect(V : Integer);
Var
  I, W : Integer;
  MemberCount : Integer;
Begin
  TarjIndex[V]   := TarjCounter;
  TarjLowLink[V] := TarjCounter;
  Inc(TarjCounter);
  TarjPush(V);

  { Parcourir les successeurs de V dans le graphe de dependances }
  For I := 0 To RecDepCount - 1 Do
  Begin
    If RecDeps[I].FromPred <> V Then Continue;
    W := RecDeps[I].ToPred;
    If (W < 0) Or (W >= QLPredCount) Then Continue;

    If TarjIndex[W] < 0 Then
    Begin
      { W n a pas encore ete visite }
      TarjStrongConnect(W);
      If TarjLowLink[W] < TarjLowLink[V] Then
        TarjLowLink[V] := TarjLowLink[W];
    End
    Else If TarjOnStack[W] Then
    Begin
      { W est sur la pile => dans le SCC courant }
      If TarjIndex[W] < TarjLowLink[V] Then
        TarjLowLink[V] := TarjIndex[W];
    End;
  End;

  { Si V est la racine d un SCC }
  If TarjLowLink[V] = TarjIndex[V] Then
  Begin
    MemberCount := 0;
    Repeat
      W := TarjPop;
      If W < 0 Then Break;
      RecPredSCC[W] := TarjSCCId;
      Inc(MemberCount);
    Until W = V;

    { Enregistrer le SCC }
    If TarjSCCId < MAX_REC_PREDS Then
    Begin
      RecSCCs[TarjSCCId].SCCId    := TarjSCCId;
      RecSCCs[TarjSCCId].IsRecurs := (MemberCount > 1);
      Inc(RecSCCCount);
    End;

    { Un SCC de taille 1 peut etre recursif s il y a un arc reflexif }
    If MemberCount = 1 Then
    Begin
      For I := 0 To RecDepCount - 1 Do
        If (RecDeps[I].FromPred = V) And (RecDeps[I].ToPred = V) Then
        Begin
          RecSCCs[TarjSCCId].IsRecurs := True;
          Break;
        End;
    End;

    Inc(TarjSCCId);
  End;
End;

Procedure FindSCCs;
Var
  I : Integer;
Begin
  TarjStackTop := 0;
  TarjCounter  := 0;
  TarjSCCId    := 0;
  RecSCCCount  := 0;
  For I := 0 To QLPredCount - 1 Do
  Begin
    TarjIndex[I]   := -1;
    TarjLowLink[I] := -1;
    TarjOnStack[I] := False;
    RecPredSCC[I]  := -1;
  End;

  For I := 0 To QLPredCount - 1 Do
    If TarjIndex[I] < 0 Then
      TarjStrongConnect(I);
End;

{ ---- Stratification par negation ---------------------------- }
{ Les predicats sont organises en strates : une strate ne peut  }
{ utiliser la negation que sur des predicats de strates          }
{ inferieures. Cela evite les cycles negatifs.                  }

Procedure ComputeStrata;
Var
  I, J, K      : Integer;
  StratLevel   : Array[0..MAX_REC_PREDS - 1] Of Integer;
  Changed      : Boolean;
  MaxLevel     : Integer;
  DepLevel     : Integer;
Begin
  RecStrataCnt := 0;

  { Initialiser tous les predicats au niveau 0 }
  For I := 0 To QLPredCount - 1 Do
    StratLevel[I] := 0;

  { Propagation : si P depend negativement de Q, alors        }
  { level(P) >= level(Q) + 1                                   }
  { Si P depend positivement de Q (meme SCC), level(P) = level(Q) }
  Repeat
    Changed := False;
    For I := 0 To RecDepCount - 1 Do
    Begin
      If (RecDeps[I].FromPred < 0) Or (RecDeps[I].ToPred < 0) Then
        Continue;
      If RecDeps[I].IsNeg Then
      Begin
        { Dependance negative : la strate de FromPred doit etre
          strictement superieure a celle de ToPred }
        DepLevel := StratLevel[RecDeps[I].ToPred] + 1;
        If DepLevel > StratLevel[RecDeps[I].FromPred] Then
        Begin
          StratLevel[RecDeps[I].FromPred] := DepLevel;
          Changed := True;
        End;
      End
      Else
      Begin
        { Dependance positive dans le meme SCC : meme niveau }
        If RecPredSCC[RecDeps[I].FromPred] =
           RecPredSCC[RecDeps[I].ToPred] Then
        Begin
          If StratLevel[RecDeps[I].ToPred] >
             StratLevel[RecDeps[I].FromPred] Then
          Begin
            StratLevel[RecDeps[I].FromPred] :=
              StratLevel[RecDeps[I].ToPred];
            Changed := True;
          End;
        End
        Else
        Begin
          { Dependance positive hors SCC : au moins le meme niveau }
          If StratLevel[RecDeps[I].ToPred] >
             StratLevel[RecDeps[I].FromPred] Then
          Begin
            StratLevel[RecDeps[I].FromPred] :=
              StratLevel[RecDeps[I].ToPred];
            Changed := True;
          End;
        End;
      End;
    End;
  Until Not Changed;

  { Verifier qu il n y a pas de cycle negatif (niveau > MAX_REC_STRATA) }
  For I := 0 To QLPredCount - 1 Do
    If StratLevel[I] >= MAX_REC_STRATA Then
    Begin
      WarnMsg('Recursion: cycle negatif detecte pour predicat ' +
              QLPreds[I].Name);
      StratLevel[I] := MAX_REC_STRATA - 1;
    End;

  { Trouver le niveau maximum }
  MaxLevel := 0;
  For I := 0 To QLPredCount - 1 Do
    If StratLevel[I] > MaxLevel Then
      MaxLevel := StratLevel[I];

  { Construire les strates }
  For K := 0 To MaxLevel Do
  Begin
    If RecStrataCnt >= MAX_REC_STRATA Then Break;
    RecStrata[RecStrataCnt].PredCnt := 0;
    RecStrata[RecStrataCnt].Level   := K;
    RecStrata[RecStrataCnt].HasNeg  := False;
    For I := 0 To QLPredCount - 1 Do
    Begin
      If StratLevel[I] = K Then
      Begin
        J := RecStrata[RecStrataCnt].PredCnt;
        If J < MAX_REC_PREDS Then
        Begin
          RecStrata[RecStrataCnt].Preds[J] := I;
          Inc(RecStrata[RecStrataCnt].PredCnt);
        End;
        { Verifier si ce predicat utilise la negation }
        For J := 0 To RecDepCount - 1 Do
          If (RecDeps[J].FromPred = I) And RecDeps[J].IsNeg Then
          Begin
            RecStrata[RecStrataCnt].HasNeg := True;
            Break;
          End;
      End;
    End;
    If RecStrata[RecStrataCnt].PredCnt > 0 Then
      Inc(RecStrataCnt);
  End;
End;

{ ---- Evaluation par point fixe d une strate ----------------- }
{ Evalue les predicats recursifs d une strate en iterant        }
{ jusqu a ce que le nombre de tuples se stabilise.              }

Procedure EvalStrataFixPoint(StrataIdx : Integer);
Var
  I, PIdx, Iter : Integer;
  AllStable     : Boolean;
  Body          : Integer;
Begin
  If (StrataIdx < 0) Or (StrataIdx >= RecStrataCnt) Then Exit;

  { Initialiser le suivi de point fixe pour chaque predicat }
  RecFPCount := RecStrata[StrataIdx].PredCnt;
  For I := 0 To RecFPCount - 1 Do
  Begin
    RecFP[I].PredIdx := RecStrata[StrataIdx].Preds[I];
    RecFP[I].OldRows := -1;
    RecFP[I].NewRows := 0;
    RecFP[I].Stable  := False;
  End;

  { Iteration jusqu a stabilisation }
  Iter := 0;
  Repeat
    AllStable := True;
    For I := 0 To RecFPCount - 1 Do
    Begin
      PIdx := RecFP[I].PredIdx;
      If (PIdx < 0) Or (PIdx >= QLPredCount) Then Continue;

      { Sauvegarder le nombre de resultats precedent }
      RecFP[I].OldRows := RecFP[I].NewRows;

      { Evaluer le predicat }
      If QLPreds[PIdx].NodeIdx >= 0 Then
      Begin
        Body := Nodes[QLPreds[PIdx].NodeIdx].Right;
        If Body < 0 Then
          Body := Nodes[QLPreds[PIdx].NodeIdx].Extra;
        If Body >= 0 Then
        Begin
          If Nodes[Body].Kind = NK_SELECT Then
            EvalSelect(Body)
          Else
          Begin
            InitResultSet;
            InitBindings;
            MatchesFilter(Body);
          End;
        End;
      End;

      { Comparer le nombre de resultats }
      RecFP[I].NewRows := EvalResults.NRows;
      RecFP[I].Stable  := (RecFP[I].NewRows = RecFP[I].OldRows);
      If Not RecFP[I].Stable Then
        AllStable := False;
    End;

    Inc(Iter);
    Inc(RecTotalIter);
  Until AllStable Or (Iter >= MAX_REC_ITERS);

  { Avertir si on a atteint la limite d iterations }
  If Not AllStable Then
    WarnMsg('Recursion: point fixe non atteint apres ' +
            Chr(Ord('0') + (Iter Div 100) Mod 10) +
            Chr(Ord('0') + (Iter Div 10) Mod 10) +
            Chr(Ord('0') + Iter Mod 10) + ' iterations (strate ' +
            Chr(Ord('0') + StrataIdx) + ')');
End;

{ ---- Detecter les predicats mutuellement recursifs ---------- }

Function CountRecursivePredicates : Integer;
Var
  I, Cnt : Integer;
Begin
  Cnt := 0;
  For I := 0 To RecSCCCount - 1 Do
    If RecSCCs[I].IsRecurs Then
      Inc(Cnt);
  CountRecursivePredicates := Cnt;
End;

{ ---- Point d entree : evaluation des requetes recursives ---- }

Procedure RunRecursiveEval;
Var
  I, J    : Integer;
  HasRecur: Boolean;
Begin
  InitRecursion;

  { Etape 1 : construire le graphe de dependances }
  BuildPredDepGraph;

  { Etape 2 : trouver les composantes fortement connexes (SCC) }
  FindSCCs;

  { Etape 3 : verifier s il y a des predicats recursifs }
  HasRecur := False;
  For I := 0 To RecSCCCount - 1 Do
    If RecSCCs[I].IsRecurs Then
    Begin
      HasRecur := True;
      Break;
    End;

  { Etape 4 : stratification par negation }
  ComputeStrata;

  { Etape 5 : evaluation par point fixe, strate par strate }
  If HasRecur Then
  Begin
    For I := 0 To RecStrataCnt - 1 Do
    Begin
      { Verifier si cette strate contient des predicats recursifs }
      For J := 0 To RecStrata[I].PredCnt - 1 Do
      Begin
        If RecPredSCC[RecStrata[I].Preds[J]] >= 0 Then
        Begin
          If RecSCCs[RecPredSCC[RecStrata[I].Preds[J]]].IsRecurs Then
          Begin
            EvalStrataFixPoint(I);
            Break;
          End;
        End;
      End;
    End;
  End;
End;

{ ---- Afficher les informations de recursion (debug) --------- }

Procedure DumpRecursiveInfo;
Var
  I, J : Integer;
Begin
  WriteLn('--- Recursion : dependances entre predicats ---');
  WriteLn('  Nombre de dependances  : ', RecDepCount);
  WriteLn('  Nombre de SCC          : ', RecSCCCount);
  WriteLn('  Nombre de strates      : ', RecStrataCnt);
  WriteLn('  Iterations point fixe  : ', RecTotalIter);
  WriteLn;

  If RecDepCount > 0 Then
  Begin
    WriteLn('  Dependances :');
    For I := 0 To RecDepCount - 1 Do
    Begin
      If (RecDeps[I].FromPred >= 0) And
         (RecDeps[I].FromPred < QLPredCount) And
         (RecDeps[I].ToPred >= 0) And
         (RecDeps[I].ToPred < QLPredCount) Then
      Begin
        Write('    ', QLPreds[RecDeps[I].FromPred].Name, ' -> ',
              QLPreds[RecDeps[I].ToPred].Name);
        If RecDeps[I].IsNeg Then
          Write(' [NEG]');
        WriteLn;
      End;
    End;
    WriteLn;
  End;

  If RecSCCCount > 0 Then
  Begin
    WriteLn('  Composantes fortement connexes :');
    For I := 0 To RecSCCCount - 1 Do
    Begin
      Write('    SCC ', RecSCCs[I].SCCId);
      If RecSCCs[I].IsRecurs Then
        Write(' [RECURSIF]')
      Else
        Write(' [non-recursif]');
      Write(' : ');
      For J := 0 To QLPredCount - 1 Do
        If RecPredSCC[J] = I Then
          Write(QLPreds[J].Name, ' ');
      WriteLn;
    End;
    WriteLn;
  End;

  If RecStrataCnt > 0 Then
  Begin
    WriteLn('  Strates (negation stratifiee) :');
    For I := 0 To RecStrataCnt - 1 Do
    Begin
      Write('    Strate ', RecStrata[I].Level);
      If RecStrata[I].HasNeg Then
        Write(' [negation]');
      Write(' : ');
      For J := 0 To RecStrata[I].PredCnt - 1 Do
      Begin
        If (RecStrata[I].Preds[J] >= 0) And
           (RecStrata[I].Preds[J] < QLPredCount) Then
          Write(QLPreds[RecStrata[I].Preds[J]].Name, ' ');
      End;
      WriteLn;
    End;
    WriteLn;
  End;

  If RecFPCount > 0 Then
  Begin
    WriteLn('  Point fixe :');
    For I := 0 To RecFPCount - 1 Do
    Begin
      If (RecFP[I].PredIdx >= 0) And
         (RecFP[I].PredIdx < QLPredCount) Then
      Begin
        Write('    ', QLPreds[RecFP[I].PredIdx].Name);
        Write(' rows=', RecFP[I].NewRows);
        If RecFP[I].Stable Then
          Write(' [stable]')
        Else
          Write(' [instable]');
        WriteLn;
      End;
    End;
    WriteLn;
  End;
End;

{ ============================================================
  TODO 12 - GRAPHE DE FLOT DE CONTROLE (CFG) [IMPLEMENTE]
  ============================================================ }

{ ---- Initialiser le graphe CFG ----------------------------- }

Procedure InitCFG;
Var
  I : Integer;
Begin
  CfgNodeCount := 0;
  CfgEdgeCount := 0;
  For I := 0 To MAX_CFG_NODES - 1 Do
  Begin
    CfgNodes[I].Kind      := CFG_BLOCK;
    CfgNodes[I].ASTIndex  := -1;
    CfgNodes[I].FuncId    := -1;
    CfgNodes[I].FirstEdge := -1;
    CfgNodes[I].Label_    := '';
  End;
End;

{ ---- Creer un nouveau noeud CFG ---------------------------- }

Function CfgNewNode(K : TCFGNodeKind; AST : Integer;
                    Func : Integer; Lbl : TString) : Integer;
Begin
  If CfgNodeCount >= MAX_CFG_NODES Then
  Begin
    CfgNewNode := -1;
    Exit;
  End;
  CfgNodes[CfgNodeCount].Kind      := K;
  CfgNodes[CfgNodeCount].ASTIndex  := AST;
  CfgNodes[CfgNodeCount].FuncId    := Func;
  CfgNodes[CfgNodeCount].FirstEdge := -1;
  CfgNodes[CfgNodeCount].Label_    := Lbl;
  CfgNewNode := CfgNodeCount;
  Inc(CfgNodeCount);
End;

{ ---- Creer une nouvelle arete CFG -------------------------- }

Function CfgNewEdge(K : TCFGEdgeKind;
                    S, D : Integer) : Integer;
Begin
  If CfgEdgeCount >= MAX_CFG_EDGES Then
  Begin
    CfgNewEdge := -1;
    Exit;
  End;
  CfgEdges[CfgEdgeCount].Kind     := K;
  CfgEdges[CfgEdgeCount].Src      := S;
  CfgEdges[CfgEdgeCount].Dst      := D;
  CfgEdges[CfgEdgeCount].NextEdge := -1;
  CfgNewEdge := CfgEdgeCount;
  Inc(CfgEdgeCount);
End;

{ ---- Ajouter une arete au noeud source --------------------- }

Procedure CfgAddEdge(K : TCFGEdgeKind; Src, Dst : Integer);
Var
  EIdx, Cur : Integer;
Begin
  If (Src < 0) Or (Src >= CfgNodeCount) Then Exit;
  If (Dst < 0) Or (Dst >= CfgNodeCount) Then Exit;
  EIdx := CfgNewEdge(K, Src, Dst);
  If EIdx < 0 Then Exit;
  If CfgNodes[Src].FirstEdge < 0 Then
    CfgNodes[Src].FirstEdge := EIdx
  Else
  Begin
    Cur := CfgNodes[Src].FirstEdge;
    While CfgEdges[Cur].NextEdge >= 0 Do
      Cur := CfgEdges[Cur].NextEdge;
    CfgEdges[Cur].NextEdge := EIdx;
  End;
End;

{ ---- Nom d'un type de noeud CFG ---------------------------- }

Function CfgNodeKindName(K : TCFGNodeKind) : TString;
Begin
  Case K Of
    CFG_ENTRY    : CfgNodeKindName := 'ENTRY';
    CFG_EXIT     : CfgNodeKindName := 'EXIT';
    CFG_BLOCK    : CfgNodeKindName := 'BLOCK';
    CFG_BRANCH   : CfgNodeKindName := 'BRANCH';
    CFG_LOOP_HEAD: CfgNodeKindName := 'LOOP_HEAD';
    CFG_LOOP_END : CfgNodeKindName := 'LOOP_END';
    CFG_TRY      : CfgNodeKindName := 'TRY';
    CFG_EXCEPT   : CfgNodeKindName := 'EXCEPT';
    CFG_FINALLY  : CfgNodeKindName := 'FINALLY';
    CFG_RAISE    : CfgNodeKindName := 'RAISE';
    Else           CfgNodeKindName := '???';
  End;
End;

{ ---- Nom d'un type d'arete CFG ----------------------------- }

Function CfgEdgeKindName(K : TCFGEdgeKind) : TString;
Begin
  Case K Of
    CFG_EDGE_NORMAL  : CfgEdgeKindName := 'NORMAL';
    CFG_EDGE_TRUE    : CfgEdgeKindName := 'TRUE';
    CFG_EDGE_FALSE   : CfgEdgeKindName := 'FALSE';
    CFG_EDGE_EXCEPT  : CfgEdgeKindName := 'EXCEPT';
    CFG_EDGE_FINALLY : CfgEdgeKindName := 'FINALLY';
    CFG_EDGE_BACK    : CfgEdgeKindName := 'BACK';
    Else               CfgEdgeKindName := '???';
  End;
End;

{ ---- Declarations forward pour BuildCfgForStmt ------------- }

Function BuildCfgForStmt(StmtIdx : Integer;
                         FuncId  : Integer;
                         ExitNode: Integer) : Integer; Forward;

{ ---- Construire le CFG pour un bloc compound --------------- }
{  Retourne l'index du premier noeud du bloc.                  }
{  PrevNode est le noeud precedent a connecter (-1 = aucun).   }

Function BuildCfgForBlock(BlockIdx : Integer;
                          FuncId   : Integer;
                          ExitNode : Integer) : Integer;
Var
  Cur, First, Prev, Nd : Integer;
Begin
  BuildCfgForBlock := -1;
  If (BlockIdx < 0) Or (BlockIdx >= SrcNodeCount) Then Exit;

  First := -1;
  Prev  := -1;
  Cur   := SrcNodes[BlockIdx].Left; { premier enfant }

  While (Cur >= 0) And (Cur < SrcNodeCount) Do
  Begin
    Nd := BuildCfgForStmt(Cur, FuncId, ExitNode);
    If Nd >= 0 Then
    Begin
      If First < 0 Then
        First := Nd;
      If Prev >= 0 Then
        CfgAddEdge(CFG_EDGE_NORMAL, Prev, Nd);
      Prev := Nd;
    End;
    Cur := SrcNodes[Cur].Next;
  End;

  BuildCfgForBlock := First;
End;

{ ---- Construire le CFG pour une instruction ----------------- }
{  Retourne l'index du noeud CFG cree pour cette instruction.   }

Function BuildCfgForStmt(StmtIdx : Integer;
                         FuncId  : Integer;
                         ExitNode: Integer) : Integer;
Var
  Nd, Cond, TrueNd, FalseNd : Integer;
  LoopHead, LoopEnd, BodyFirst : Integer;
  TryNd, ExceptNd, FinallyNd, BodyBlock : Integer;
  CaseItem, CaseNd : Integer;
Begin
  BuildCfgForStmt := -1;
  If (StmtIdx < 0) Or (StmtIdx >= SrcNodeCount) Then Exit;

  Case SrcNodes[StmtIdx].Kind Of

    { --- IF : branchement conditionnel ---------------------- }
    SNK_IF:
    Begin
      Cond := CfgNewNode(CFG_BRANCH, StmtIdx, FuncId, 'if');
      TrueNd := -1;
      FalseNd := -1;

      { branche then }
      If SrcNodes[StmtIdx].Left >= 0 Then
        TrueNd := BuildCfgForStmt(SrcNodes[StmtIdx].Left,
                                   FuncId, ExitNode);

      { branche else }
      If SrcNodes[StmtIdx].Right >= 0 Then
        FalseNd := BuildCfgForStmt(SrcNodes[StmtIdx].Right,
                                    FuncId, ExitNode);

      If TrueNd >= 0 Then
        CfgAddEdge(CFG_EDGE_TRUE, Cond, TrueNd)
      Else
        CfgAddEdge(CFG_EDGE_TRUE, Cond, ExitNode);

      If FalseNd >= 0 Then
        CfgAddEdge(CFG_EDGE_FALSE, Cond, FalseNd)
      Else
        CfgAddEdge(CFG_EDGE_FALSE, Cond, ExitNode);

      BuildCfgForStmt := Cond;
    End;

    { --- WHILE : boucle avec condition en tete -------------- }
    SNK_WHILE:
    Begin
      LoopHead := CfgNewNode(CFG_LOOP_HEAD, StmtIdx, FuncId,
                              'while');
      LoopEnd  := CfgNewNode(CFG_LOOP_END, StmtIdx, FuncId,
                              'end_while');

      { corps de la boucle }
      BodyFirst := -1;
      If SrcNodes[StmtIdx].Left >= 0 Then
        BodyFirst := BuildCfgForStmt(SrcNodes[StmtIdx].Left,
                                      FuncId, ExitNode);

      { condition vraie -> corps }
      If BodyFirst >= 0 Then
      Begin
        CfgAddEdge(CFG_EDGE_TRUE, LoopHead, BodyFirst);
        CfgAddEdge(CFG_EDGE_BACK, BodyFirst, LoopHead);
      End
      Else
        CfgAddEdge(CFG_EDGE_TRUE, LoopHead, LoopHead);

      { condition fausse -> fin de boucle }
      CfgAddEdge(CFG_EDGE_FALSE, LoopHead, LoopEnd);

      BuildCfgForStmt := LoopHead;
    End;

    { --- FOR : boucle for ----------------------------------- }
    SNK_FOR:
    Begin
      LoopHead := CfgNewNode(CFG_LOOP_HEAD, StmtIdx, FuncId,
                              'for');
      LoopEnd  := CfgNewNode(CFG_LOOP_END, StmtIdx, FuncId,
                              'end_for');

      BodyFirst := -1;
      If SrcNodes[StmtIdx].Left >= 0 Then
        BodyFirst := BuildCfgForStmt(SrcNodes[StmtIdx].Left,
                                      FuncId, ExitNode);

      If BodyFirst >= 0 Then
      Begin
        CfgAddEdge(CFG_EDGE_TRUE, LoopHead, BodyFirst);
        CfgAddEdge(CFG_EDGE_BACK, BodyFirst, LoopHead);
      End
      Else
        CfgAddEdge(CFG_EDGE_TRUE, LoopHead, LoopHead);

      CfgAddEdge(CFG_EDGE_FALSE, LoopHead, LoopEnd);

      BuildCfgForStmt := LoopHead;
    End;

    { --- REPEAT : boucle avec condition en fin --------------- }
    SNK_REPEAT:
    Begin
      LoopHead := CfgNewNode(CFG_LOOP_HEAD, StmtIdx, FuncId,
                              'repeat');
      LoopEnd  := CfgNewNode(CFG_LOOP_END, StmtIdx, FuncId,
                              'end_repeat');

      BodyFirst := -1;
      If SrcNodes[StmtIdx].Left >= 0 Then
        BodyFirst := BuildCfgForStmt(SrcNodes[StmtIdx].Left,
                                      FuncId, ExitNode);

      { entree -> corps (ou tete directe) }
      If BodyFirst >= 0 Then
        CfgAddEdge(CFG_EDGE_NORMAL, LoopHead, BodyFirst)
      Else
        CfgAddEdge(CFG_EDGE_NORMAL, LoopHead, LoopEnd);

      { fin corps -> condition : faux -> retour, vrai -> fin }
      CfgAddEdge(CFG_EDGE_FALSE, LoopEnd, LoopHead);
      { si condition vraie -> sortie apres la boucle }
      BuildCfgForStmt := LoopHead;
    End;

    { --- CASE : branchement multiple ------------------------ }
    SNK_CASE:
    Begin
      Nd := CfgNewNode(CFG_BRANCH, StmtIdx, FuncId, 'case');
      CaseItem := SrcNodes[StmtIdx].Left;
      While (CaseItem >= 0) And (CaseItem < SrcNodeCount) Do
      Begin
        CaseNd := BuildCfgForStmt(CaseItem, FuncId, ExitNode);
        If CaseNd >= 0 Then
          CfgAddEdge(CFG_EDGE_NORMAL, Nd, CaseNd);
        CaseItem := SrcNodes[CaseItem].Next;
      End;
      BuildCfgForStmt := Nd;
    End;

    { --- TRY : gestion d'exceptions ------------------------- }
    SNK_TRY:
    Begin
      TryNd := CfgNewNode(CFG_TRY, StmtIdx, FuncId, 'try');

      { bloc try corps }
      BodyBlock := -1;
      If SrcNodes[StmtIdx].Left >= 0 Then
        BodyBlock := BuildCfgForStmt(SrcNodes[StmtIdx].Left,
                                      FuncId, ExitNode);
      If BodyBlock >= 0 Then
        CfgAddEdge(CFG_EDGE_NORMAL, TryNd, BodyBlock);

      { bloc except }
      ExceptNd := -1;
      If SrcNodes[StmtIdx].Right >= 0 Then
      Begin
        ExceptNd := CfgNewNode(CFG_EXCEPT, SrcNodes[StmtIdx].Right,
                                FuncId, 'except');
        CfgAddEdge(CFG_EDGE_EXCEPT, TryNd, ExceptNd);
        If BodyBlock >= 0 Then
          CfgAddEdge(CFG_EDGE_EXCEPT, BodyBlock, ExceptNd);
      End;

      { bloc finally }
      FinallyNd := -1;
      If SrcNodes[StmtIdx].Extra >= 0 Then
      Begin
        FinallyNd := CfgNewNode(CFG_FINALLY, SrcNodes[StmtIdx].Extra,
                                 FuncId, 'finally');
        CfgAddEdge(CFG_EDGE_FINALLY, TryNd, FinallyNd);
        If BodyBlock >= 0 Then
          CfgAddEdge(CFG_EDGE_FINALLY, BodyBlock, FinallyNd);
        If ExceptNd >= 0 Then
          CfgAddEdge(CFG_EDGE_FINALLY, ExceptNd, FinallyNd);
      End;

      BuildCfgForStmt := TryNd;
    End;

    { --- RAISE : levee d'exception -------------------------- }
    SNK_RAISE:
    Begin
      Nd := CfgNewNode(CFG_RAISE, StmtIdx, FuncId, 'raise');
      CfgAddEdge(CFG_EDGE_EXCEPT, Nd, ExitNode);
      BuildCfgForStmt := Nd;
    End;

    { --- COMPOUND : bloc begin..end ------------------------- }
    SNK_COMPOUND:
    Begin
      Nd := BuildCfgForBlock(StmtIdx, FuncId, ExitNode);
      BuildCfgForStmt := Nd;
    End;

    { --- Instructions simples (assign, call, goto, etc) ----- }
    Else
    Begin
      Nd := CfgNewNode(CFG_BLOCK, StmtIdx, FuncId,
                        SrcNodes[StmtIdx].Name);
      BuildCfgForStmt := Nd;
    End;

  End; { case }
End;

{ ---- Construire le CFG pour une fonction/procedure --------- }

Procedure BuildCfgForFunction(FuncIdx : Integer);
Var
  EntryNd, ExitNd, BodyNd : Integer;
  BodyAST : Integer;
Begin
  If (FuncIdx < 0) Or (FuncIdx >= SrcNodeCount) Then Exit;
  If (SrcNodes[FuncIdx].Kind <> SNK_PROC_DECL) And
     (SrcNodes[FuncIdx].Kind <> SNK_FUNC_DECL) Then Exit;

  EntryNd := CfgNewNode(CFG_ENTRY, FuncIdx, FuncIdx,
                          'entry:' + SrcNodes[FuncIdx].Name);
  ExitNd  := CfgNewNode(CFG_EXIT, FuncIdx, FuncIdx,
                          'exit:' + SrcNodes[FuncIdx].Name);

  { Le corps est dans Extra (bloc compound) }
  BodyAST := SrcNodes[FuncIdx].Extra;
  If BodyAST >= 0 Then
  Begin
    BodyNd := BuildCfgForStmt(BodyAST, FuncIdx, ExitNd);
    If BodyNd >= 0 Then
    Begin
      CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, BodyNd);
      CfgAddEdge(CFG_EDGE_NORMAL, BodyNd, ExitNd);
    End
    Else
      CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, ExitNd);
  End
  Else
    CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, ExitNd);
End;

{ ---- Construire le CFG pour le programme principal --------- }

Procedure BuildCfgForProgram(RootIdx : Integer);
Var
  EntryNd, ExitNd, BodyNd : Integer;
  BodyAST : Integer;
Begin
  If (RootIdx < 0) Or (RootIdx >= SrcNodeCount) Then Exit;

  EntryNd := CfgNewNode(CFG_ENTRY, RootIdx, -1,
                          'entry:main');
  ExitNd  := CfgNewNode(CFG_EXIT, RootIdx, -1,
                          'exit:main');

  { Le corps principal est dans Extra }
  BodyAST := SrcNodes[RootIdx].Extra;
  If BodyAST >= 0 Then
  Begin
    BodyNd := BuildCfgForStmt(BodyAST, -1, ExitNd);
    If BodyNd >= 0 Then
    Begin
      CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, BodyNd);
      CfgAddEdge(CFG_EDGE_NORMAL, BodyNd, ExitNd);
    End
    Else
      CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, ExitNd);
  End
  Else
    CfgAddEdge(CFG_EDGE_NORMAL, EntryNd, ExitNd);
End;

{ ---- Parcourir l'AST pour construire tous les CFGs --------- }

Procedure BuildCFG;
Var
  I : Integer;
Begin
  InitCFG;

  { Construire le CFG pour chaque fonction/procedure trouvee }
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    If (SrcNodes[I].Kind = SNK_PROC_DECL) Or
       (SrcNodes[I].Kind = SNK_FUNC_DECL) Then
      BuildCfgForFunction(I);
  End;

  { Construire le CFG pour le programme principal }
  If SrcNodeCount > 0 Then
  Begin
    If (SrcNodes[SrcRootNode].Kind = SNK_PROGRAM) Or
       (SrcNodes[SrcRootNode].Kind = SNK_UNIT) Then
      BuildCfgForProgram(SrcRootNode);
  End;
End;

{ ---- Afficher le graphe CFG pour debug --------------------- }

Procedure DumpCFG;
Var
  I, E : Integer;
Begin
  WriteLn('=== Graphe de Flot de Controle (CFG) ===');
  WriteLn('Noeuds : ', CfgNodeCount);
  WriteLn('Aretes : ', CfgEdgeCount);
  WriteLn;

  For I := 0 To CfgNodeCount - 1 Do
  Begin
    Write('  N', I, ' [', CfgNodeKindName(CfgNodes[I].Kind), ']');
    If CfgNodes[I].Label_ <> '' Then
      Write(' "', CfgNodes[I].Label_, '"');
    If CfgNodes[I].ASTIndex >= 0 Then
      Write(' ast=', CfgNodes[I].ASTIndex);
    If CfgNodes[I].FuncId >= 0 Then
      Write(' func=', CfgNodes[I].FuncId);
    WriteLn;

    { Afficher les aretes sortantes }
    E := CfgNodes[I].FirstEdge;
    While E >= 0 Do
    Begin
      WriteLn('    -> N', CfgEdges[E].Dst, ' [',
              CfgEdgeKindName(CfgEdges[E].Kind), ']');
      E := CfgEdges[E].NextEdge;
    End;
  End;
  WriteLn;
End;

{ ============================================================
  TODO 13 - ANALYSE DE FLOT DE DONNEES (DATA FLOW) [IMPLEMENTE]
  ============================================================ }

{ ---- Initialisation de l'analyse de flot de donnees -------- }

Procedure InitDataFlow;
Var
  I, J : Integer;
Begin
  DfVarCount   := 0;
  DfDefCount   := 0;
  DfUseCount   := 0;
  DfChainCount := 0;
  For I := 0 To CfgNodeCount - 1 Do
  Begin
    For J := 0 To MAX_DF_BITS - 1 Do
    Begin
      DfNodeInfo[I].Gen[J]     := 0;
      DfNodeInfo[I].Kill[J]    := 0;
      DfNodeInfo[I].RDIn[J]    := 0;
      DfNodeInfo[I].RDOut[J]   := 0;
      DfNodeInfo[I].LiveIn[J]  := 0;
      DfNodeInfo[I].LiveOut[J] := 0;
      DfNodeInfo[I].UseSet[J]  := 0;
      DfNodeInfo[I].DefSet[J]  := 0;
    End;
  End;
End;

{ ---- Operations sur les ensembles de bits (bitset) --------- }

Procedure DfBitSetInit(Var S : TDFBitSet);
Var
  I : Integer;
Begin
  For I := 0 To MAX_DF_BITS - 1 Do
    S[I] := 0;
End;

Procedure DfBitSetSet(Var S : TDFBitSet; Bit : Integer);
Begin
  If (Bit >= 0) And (Bit < MAX_DF_BITS * 8) Then
    S[Bit Div 8] := S[Bit Div 8] Or (1 Shl (Bit Mod 8));
End;

Procedure DfBitSetClear(Var S : TDFBitSet; Bit : Integer);
Begin
  If (Bit >= 0) And (Bit < MAX_DF_BITS * 8) Then
    S[Bit Div 8] := S[Bit Div 8] And Not (1 Shl (Bit Mod 8));
End;

Function DfBitSetTest(Const S : TDFBitSet; Bit : Integer) : Boolean;
Begin
  If (Bit >= 0) And (Bit < MAX_DF_BITS * 8) Then
    DfBitSetTest := (S[Bit Div 8] And (1 Shl (Bit Mod 8))) <> 0
  Else
    DfBitSetTest := False;
End;

Procedure DfBitSetUnion(Var Dst : TDFBitSet; Const Src : TDFBitSet);
Var
  I : Integer;
Begin
  For I := 0 To MAX_DF_BITS - 1 Do
    Dst[I] := Dst[I] Or Src[I];
End;

Procedure DfBitSetIntersect(Var Dst : TDFBitSet;
                             Const Src : TDFBitSet);
Var
  I : Integer;
Begin
  For I := 0 To MAX_DF_BITS - 1 Do
    Dst[I] := Dst[I] And Src[I];
End;

Procedure DfBitSetDiff(Var Dst : TDFBitSet;
                        Const Src : TDFBitSet);
Var
  I : Integer;
Begin
  For I := 0 To MAX_DF_BITS - 1 Do
    Dst[I] := Dst[I] And Not Src[I];
End;

Function DfBitSetEqual(Const A, B : TDFBitSet) : Boolean;
Var
  I : Integer;
Begin
  DfBitSetEqual := True;
  For I := 0 To MAX_DF_BITS - 1 Do
    If A[I] <> B[I] Then
    Begin
      DfBitSetEqual := False;
      Exit;
    End;
End;

Procedure DfBitSetCopy(Var Dst : TDFBitSet; Const Src : TDFBitSet);
Var
  I : Integer;
Begin
  For I := 0 To MAX_DF_BITS - 1 Do
    Dst[I] := Src[I];
End;

{ ---- Gestion des variables DF ------------------------------ }

Function DfFindVar(Const VarName : TString) : Integer;
Var
  I : Integer;
  LowName : TString;
Begin
  LowName := StrLowerCase(VarName);
  DfFindVar := -1;
  For I := 0 To DfVarCount - 1 Do
    If StrLowerCase(DfVars[I].Name) = LowName Then
    Begin
      DfFindVar := I;
      Exit;
    End;
End;

Function DfAddVar(Const VarName : TString; ASTIdx, FuncId : Integer)
                  : Integer;
Var
  Idx : Integer;
Begin
  Idx := DfFindVar(VarName);
  If Idx >= 0 Then
  Begin
    DfAddVar := Idx;
    Exit;
  End;
  If DfVarCount >= MAX_DF_VARS Then
  Begin
    DfAddVar := -1;
    Exit;
  End;
  Idx := DfVarCount;
  DfVars[Idx].Name     := VarName;
  DfVars[Idx].ASTIndex := ASTIdx;
  DfVars[Idx].FuncId   := FuncId;
  Inc(DfVarCount);
  DfAddVar := Idx;
End;

Function DfAddDef(VarIdx, CfgNd, ASTIdx : Integer) : Integer;
Begin
  If DfDefCount >= MAX_DF_DEFS Then
  Begin
    DfAddDef := -1;
    Exit;
  End;
  DfDefs[DfDefCount].VarIdx   := VarIdx;
  DfDefs[DfDefCount].CfgNode  := CfgNd;
  DfDefs[DfDefCount].ASTIndex := ASTIdx;
  DfDefs[DfDefCount].DefId    := DfDefCount;
  DfAddDef := DfDefCount;
  Inc(DfDefCount);
End;

Function DfAddUse(VarIdx, CfgNd, ASTIdx : Integer) : Integer;
Begin
  If DfUseCount >= MAX_DF_USES Then
  Begin
    DfAddUse := -1;
    Exit;
  End;
  DfUses[DfUseCount].VarIdx   := VarIdx;
  DfUses[DfUseCount].CfgNode  := CfgNd;
  DfUses[DfUseCount].ASTIndex := ASTIdx;
  DfUses[DfUseCount].UseId    := DfUseCount;
  DfAddUse := DfUseCount;
  Inc(DfUseCount);
End;

{ ---- Trouver le noeud CFG pour un noeud AST ---------------- }

Function FindCfgNodeForAST(ASTIdx : Integer) : Integer;
Var
  I : Integer;
Begin
  FindCfgNodeForAST := -1;
  For I := 0 To CfgNodeCount - 1 Do
    If CfgNodes[I].ASTIndex = ASTIdx Then
    Begin
      FindCfgNodeForAST := I;
      Exit;
    End;
  { Si non trouve, chercher le noeud CFG parent le plus proche }
  If (ASTIdx >= 0) And (ASTIdx < SrcNodeCount) Then
  Begin
    For I := 0 To CfgNodeCount - 1 Do
      If CfgNodes[I].ASTIndex >= 0 Then
        If CfgNodes[I].Kind = CFG_BLOCK Then
        Begin
          FindCfgNodeForAST := I;
          Exit;
        End;
  End;
End;

{ ---- Collecter les definitions et utilisations ------------- }

Procedure CollectDefsUses;
Var
  I, VarIdx, CfgNd : Integer;
Begin
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    Case SrcNodes[I].Kind Of

      { Declarations de variables : c'est une definition initiale }
      SNK_VAR_DECL:
      Begin
        If SrcNodes[I].Name <> '' Then
        Begin
          VarIdx := DfAddVar(SrcNodes[I].Name, I, -1);
          If VarIdx >= 0 Then
          Begin
            CfgNd := FindCfgNodeForAST(I);
            If CfgNd < 0 Then CfgNd := 0;
            DfAddDef(VarIdx, CfgNd, I);
          End;
        End;
      End;

      { Declarations de parametres : definition a l'entree }
      SNK_PARAM_DECL:
      Begin
        If SrcNodes[I].Name <> '' Then
        Begin
          VarIdx := DfAddVar(SrcNodes[I].Name, I, -1);
          If VarIdx >= 0 Then
          Begin
            CfgNd := FindCfgNodeForAST(I);
            If CfgNd < 0 Then CfgNd := 0;
            DfAddDef(VarIdx, CfgNd, I);
          End;
        End;
      End;

      { Affectations : la partie gauche est une definition }
      SNK_ASSIGN:
      Begin
        If SrcNodes[I].Left >= 0 Then
        Begin
          If SrcNodes[SrcNodes[I].Left].Kind = SNK_EXPR_IDENT Then
          Begin
            VarIdx := DfAddVar(
              SrcNodes[SrcNodes[I].Left].Name,
              SrcNodes[I].Left, -1);
            If VarIdx >= 0 Then
            Begin
              CfgNd := FindCfgNodeForAST(I);
              If CfgNd < 0 Then CfgNd := 0;
              DfAddDef(VarIdx, CfgNd, I);
            End;
          End;
        End;
        { La partie droite contient des utilisations }
        If SrcNodes[I].Right >= 0 Then
        Begin
          If SrcNodes[SrcNodes[I].Right].Kind = SNK_EXPR_IDENT Then
          Begin
            VarIdx := DfFindVar(
              SrcNodes[SrcNodes[I].Right].Name);
            If VarIdx >= 0 Then
            Begin
              CfgNd := FindCfgNodeForAST(I);
              If CfgNd < 0 Then CfgNd := 0;
              DfAddUse(VarIdx, CfgNd, SrcNodes[I].Right);
            End;
          End;
        End;
      End;

      { Identifiants dans les expressions : utilisation }
      SNK_EXPR_IDENT:
      Begin
        If SrcNodes[I].Name <> '' Then
        Begin
          VarIdx := DfFindVar(SrcNodes[I].Name);
          If VarIdx >= 0 Then
          Begin
            CfgNd := FindCfgNodeForAST(I);
            If CfgNd < 0 Then CfgNd := 0;
            DfAddUse(VarIdx, CfgNd, I);
          End;
        End;
      End;

      { Boucle for : la variable de boucle est definie }
      SNK_FOR:
      Begin
        If SrcNodes[I].Name <> '' Then
        Begin
          VarIdx := DfAddVar(SrcNodes[I].Name, I, -1);
          If VarIdx >= 0 Then
          Begin
            CfgNd := FindCfgNodeForAST(I);
            If CfgNd < 0 Then CfgNd := 0;
            DfAddDef(VarIdx, CfgNd, I);
          End;
        End;
      End;

    End; { case }
  End;
End;

{ ---- Calculer les ensembles Gen et Kill -------------------- }

Procedure ComputeGenKill;
Var
  D, K, CfgNd, VarIdx : Integer;
Begin
  { Gen[n] = ensemble des definitions generees dans le noeud n }
  { Kill[n] = ensemble des definitions tuees par le noeud n    }
  For D := 0 To DfDefCount - 1 Do
  Begin
    CfgNd := DfDefs[D].CfgNode;
    If (CfgNd >= 0) And (CfgNd < CfgNodeCount) Then
    Begin
      { Cette definition est generee dans ce noeud }
      DfBitSetSet(DfNodeInfo[CfgNd].Gen, D);

      { Marquer la variable comme definie dans ce noeud }
      VarIdx := DfDefs[D].VarIdx;
      If (VarIdx >= 0) And (VarIdx < DfVarCount) Then
        DfBitSetSet(DfNodeInfo[CfgNd].DefSet, VarIdx);

      { Kill : toutes les autres definitions de la meme variable }
      For K := 0 To DfDefCount - 1 Do
      Begin
        If (K <> D) And (DfDefs[K].VarIdx = VarIdx) Then
          DfBitSetSet(DfNodeInfo[CfgNd].Kill, K);
      End;
    End;
  End;

  { UseSet : ensemble des variables utilisees dans chaque noeud }
  For D := 0 To DfUseCount - 1 Do
  Begin
    CfgNd := DfUses[D].CfgNode;
    If (CfgNd >= 0) And (CfgNd < CfgNodeCount) Then
    Begin
      VarIdx := DfUses[D].VarIdx;
      If (VarIdx >= 0) And (VarIdx < DfVarCount) Then
        DfBitSetSet(DfNodeInfo[CfgNd].UseSet, VarIdx);
    End;
  End;
End;

{ ---- Trouver les predecesseurs d'un noeud CFG -------------- }

Procedure GetCfgPredecessors(NodeIdx : Integer;
                              Var Preds : Array Of Integer;
                              Var PredCount : Integer);
Var
  I, E : Integer;
Begin
  PredCount := 0;
  For I := 0 To CfgNodeCount - 1 Do
  Begin
    E := CfgNodes[I].FirstEdge;
    While E >= 0 Do
    Begin
      If CfgEdges[E].Dst = NodeIdx Then
      Begin
        If PredCount < MAX_CFG_NODES Then
        Begin
          Preds[PredCount] := I;
          Inc(PredCount);
        End;
      End;
      E := CfgEdges[E].NextEdge;
    End;
  End;
End;

{ ---- Trouver les successeurs d'un noeud CFG ---------------- }

Procedure GetCfgSuccessors(NodeIdx : Integer;
                            Var Succs : Array Of Integer;
                            Var SuccCount : Integer);
Var
  E : Integer;
Begin
  SuccCount := 0;
  E := CfgNodes[NodeIdx].FirstEdge;
  While E >= 0 Do
  Begin
    If SuccCount < MAX_CFG_NODES Then
    Begin
      Succs[SuccCount] := CfgEdges[E].Dst;
      Inc(SuccCount);
    End;
    E := CfgEdges[E].NextEdge;
  End;
End;

{ ---- Definitions atteignantes (propagation avant) ---------- }

Procedure ComputeReachingDefs;
Var
  Changed : Boolean;
  I, J, PredCount : Integer;
  OldOut, Temp : TDFBitSet;
  Preds : Array[0..255] Of Integer;
Begin
  { Initialiser OUT[n] = Gen[n] pour chaque noeud }
  For I := 0 To CfgNodeCount - 1 Do
    DfBitSetCopy(DfNodeInfo[I].RDOut, DfNodeInfo[I].Gen);

  { Iteration point fixe }
  Repeat
    Changed := False;
    For I := 0 To CfgNodeCount - 1 Do
    Begin
      { IN[n] = union des OUT des predecesseurs }
      DfBitSetInit(DfNodeInfo[I].RDIn);
      GetCfgPredecessors(I, Preds, PredCount);
      For J := 0 To PredCount - 1 Do
        DfBitSetUnion(DfNodeInfo[I].RDIn,
                       DfNodeInfo[Preds[J]].RDOut);

      { OUT[n] = Gen[n] union (IN[n] - Kill[n]) }
      DfBitSetCopy(OldOut, DfNodeInfo[I].RDOut);
      DfBitSetCopy(Temp, DfNodeInfo[I].RDIn);
      DfBitSetDiff(Temp, DfNodeInfo[I].Kill);
      DfBitSetCopy(DfNodeInfo[I].RDOut, DfNodeInfo[I].Gen);
      DfBitSetUnion(DfNodeInfo[I].RDOut, Temp);

      If Not DfBitSetEqual(OldOut, DfNodeInfo[I].RDOut) Then
        Changed := True;
    End;
  Until Not Changed;
End;

{ ---- Analyse de vivacite (propagation arriere) ------------- }

Procedure ComputeLiveness;
Var
  Changed : Boolean;
  I, J, SuccCount : Integer;
  OldIn, Temp : TDFBitSet;
  Succs : Array[0..255] Of Integer;
Begin
  { Initialiser LiveIn[n] = UseSet[n] }
  For I := 0 To CfgNodeCount - 1 Do
    DfBitSetCopy(DfNodeInfo[I].LiveIn, DfNodeInfo[I].UseSet);

  { Iteration point fixe (parcours arriere) }
  Repeat
    Changed := False;
    For I := CfgNodeCount - 1 DownTo 0 Do
    Begin
      { OUT[n] = union des IN des successeurs }
      DfBitSetInit(DfNodeInfo[I].LiveOut);
      GetCfgSuccessors(I, Succs, SuccCount);
      For J := 0 To SuccCount - 1 Do
        DfBitSetUnion(DfNodeInfo[I].LiveOut,
                       DfNodeInfo[Succs[J]].LiveIn);

      { IN[n] = Use[n] union (OUT[n] - Def[n]) }
      DfBitSetCopy(OldIn, DfNodeInfo[I].LiveIn);
      DfBitSetCopy(Temp, DfNodeInfo[I].LiveOut);
      DfBitSetDiff(Temp, DfNodeInfo[I].DefSet);
      DfBitSetCopy(DfNodeInfo[I].LiveIn, DfNodeInfo[I].UseSet);
      DfBitSetUnion(DfNodeInfo[I].LiveIn, Temp);

      If Not DfBitSetEqual(OldIn, DfNodeInfo[I].LiveIn) Then
        Changed := True;
    End;
  Until Not Changed;
End;

{ ---- Construire les chaines definition-utilisation ---------- }

Procedure BuildDefUseChains;
Var
  D, U, CfgNd : Integer;
Begin
  DfChainCount := 0;
  For U := 0 To DfUseCount - 1 Do
  Begin
    CfgNd := DfUses[U].CfgNode;
    If (CfgNd < 0) Or (CfgNd >= CfgNodeCount) Then Continue;

    { Une definition atteint cette utilisation si elle est dans
      RDIn du noeud CFG de l'utilisation et concerne la meme
      variable }
    For D := 0 To DfDefCount - 1 Do
    Begin
      If DfDefs[D].VarIdx <> DfUses[U].VarIdx Then Continue;
      If DfBitSetTest(DfNodeInfo[CfgNd].RDIn, D) Or
         DfBitSetTest(DfNodeInfo[CfgNd].Gen, D) Then
      Begin
        If DfChainCount < MAX_DF_CHAINS Then
        Begin
          DfChains[DfChainCount].DefIdx := D;
          DfChains[DfChainCount].UseIdx := U;
          Inc(DfChainCount);
        End;
      End;
    End;
  End;
End;

{ ---- Point d'entree de l'analyse de flot de donnees -------- }

Procedure RunDataFlowAnalysis;
Begin
  InitDataFlow;
  CollectDefsUses;
  ComputeGenKill;
  ComputeReachingDefs;
  ComputeLiveness;
  BuildDefUseChains;
End;

{ ---- Affichage debug de l'analyse de flot de donnees ------- }

Procedure DumpDataFlow;
Var
  I, J : Integer;
Begin
  WriteLn('=== Analyse de Flot de Donnees ===');
  WriteLn('Variables : ', DfVarCount);
  WriteLn('Definitions : ', DfDefCount);
  WriteLn('Utilisations : ', DfUseCount);
  WriteLn('Chaines def-use : ', DfChainCount);
  WriteLn;

  { Afficher les variables }
  WriteLn('--- Variables ---');
  For I := 0 To DfVarCount - 1 Do
  Begin
    Write('  V', I, ' "', DfVars[I].Name, '"');
    If DfVars[I].ASTIndex >= 0 Then
      Write(' ast=', DfVars[I].ASTIndex);
    WriteLn;
  End;
  WriteLn;

  { Afficher les definitions }
  WriteLn('--- Definitions ---');
  For I := 0 To DfDefCount - 1 Do
  Begin
    Write('  D', I, ' var=V', DfDefs[I].VarIdx);
    If DfDefs[I].VarIdx >= 0 Then
      Write(' "', DfVars[DfDefs[I].VarIdx].Name, '"');
    Write(' cfg=N', DfDefs[I].CfgNode);
    Write(' ast=', DfDefs[I].ASTIndex);
    WriteLn;
  End;
  WriteLn;

  { Afficher les utilisations }
  WriteLn('--- Utilisations ---');
  For I := 0 To DfUseCount - 1 Do
  Begin
    Write('  U', I, ' var=V', DfUses[I].VarIdx);
    If DfUses[I].VarIdx >= 0 Then
      Write(' "', DfVars[DfUses[I].VarIdx].Name, '"');
    Write(' cfg=N', DfUses[I].CfgNode);
    Write(' ast=', DfUses[I].ASTIndex);
    WriteLn;
  End;
  WriteLn;

  { Afficher les definitions atteignantes par noeud CFG }
  WriteLn('--- Definitions atteignantes ---');
  For I := 0 To CfgNodeCount - 1 Do
  Begin
    Write('  N', I, ' RDIn={');
    For J := 0 To DfDefCount - 1 Do
      If DfBitSetTest(DfNodeInfo[I].RDIn, J) Then
        Write('D', J, ' ');
    Write('} RDOut={');
    For J := 0 To DfDefCount - 1 Do
      If DfBitSetTest(DfNodeInfo[I].RDOut, J) Then
        Write('D', J, ' ');
    WriteLn('}');
  End;
  WriteLn;

  { Afficher l'analyse de vivacite par noeud CFG }
  WriteLn('--- Vivacite (liveness) ---');
  For I := 0 To CfgNodeCount - 1 Do
  Begin
    Write('  N', I, ' LiveIn={');
    For J := 0 To DfVarCount - 1 Do
      If DfBitSetTest(DfNodeInfo[I].LiveIn, J) Then
        Write('V', J, ' ');
    Write('} LiveOut={');
    For J := 0 To DfVarCount - 1 Do
      If DfBitSetTest(DfNodeInfo[I].LiveOut, J) Then
        Write('V', J, ' ');
    WriteLn('}');
  End;
  WriteLn;

  { Afficher les chaines definition-utilisation }
  WriteLn('--- Chaines def-use ---');
  For I := 0 To DfChainCount - 1 Do
  Begin
    Write('  D', DfChains[I].DefIdx);
    Write(' "', DfVars[DfDefs[DfChains[I].DefIdx].VarIdx].Name, '"');
    Write(' -> U', DfChains[I].UseIdx);
    WriteLn;
  End;
  WriteLn;
End;

{ ============================================================
  TODO 14 - SUIVI DE TEINTE (TAINT TRACKING) [IMPLEMENTE]
  ============================================================ }

{ ---- Initialisation du suivi de teinte --------------------- }

Procedure InitTaint;
Var
  I : Integer;
Begin
  TaintSrcCount   := 0;
  TaintSinkCount  := 0;
  TaintStepCount  := 0;
  TaintAlertCount := 0;
  For I := 0 To MAX_DF_VARS - 1 Do
    TaintVarState[I] := False;
End;

{ ---- Noms des types de sources et de puits ----------------- }

Function TaintSourceKindName(K : TTaintSourceKind) : TString;
Begin
  Case K Of
    TSK_NONE:          TaintSourceKindName := 'none';
    TSK_READLN:        TaintSourceKindName := 'ReadLn';
    TSK_PARAMSTR:      TaintSourceKindName := 'ParamStr';
    TSK_READ_FILE:     TaintSourceKindName := 'Read(file)';
    TSK_READKEY:       TaintSourceKindName := 'ReadKey';
    TSK_GETENV:        TaintSourceKindName := 'GetEnv';
    TSK_INPUT_PORT:    TaintSourceKindName := 'Port';
    TSK_RESET_REWRITE: TaintSourceKindName := 'Reset/Rewrite';
  Else
    TaintSourceKindName := '?';
  End;
End;

Function TaintSinkKindName(K : TTaintSinkKind) : TString;
Begin
  Case K Of
    TNK_NONE:        TaintSinkKindName := 'none';
    TNK_WRITELN_FMT: TaintSinkKindName := 'WriteLn';
    TNK_EXEC:        TaintSinkKindName := 'Exec';
    TNK_ASSIGN:      TaintSinkKindName := 'Assign';
    TNK_SQL:         TaintSinkKindName := 'SQL';
    TNK_RENAME:      TaintSinkKindName := 'Rename';
    TNK_ERASE:       TaintSinkKindName := 'Erase';
    TNK_CHDIR:       TaintSinkKindName := 'ChDir';
    TNK_MKDIR:       TaintSinkKindName := 'MkDir';
    TNK_VAL:         TaintSinkKindName := 'Val';
  Else
    TaintSinkKindName := '?';
  End;
End;

{ ---- Identification des sources de teinte ------------------ }

Function ClassifyTaintSource(Const FuncName : TString)
                             : TTaintSourceKind;
Var
  Low : TString;
Begin
  Low := StrLowerCase(FuncName);
  If (Low = 'readln') Or (Low = 'read') Then
    ClassifyTaintSource := TSK_READLN
  Else If Low = 'paramstr' Then
    ClassifyTaintSource := TSK_PARAMSTR
  Else If Low = 'readkey' Then
    ClassifyTaintSource := TSK_READKEY
  Else If Low = 'getenv' Then
    ClassifyTaintSource := TSK_GETENV
  Else If (Low = 'port') Or (Low = 'portw') Then
    ClassifyTaintSource := TSK_INPUT_PORT
  Else If (Low = 'reset') Or (Low = 'rewrite') Then
    ClassifyTaintSource := TSK_RESET_REWRITE
  Else
    ClassifyTaintSource := TSK_NONE;
End;

{ ---- Identification des puits sensibles -------------------- }

Function ClassifyTaintSink(Const FuncName : TString)
                           : TTaintSinkKind;
Var
  Low : TString;
Begin
  Low := StrLowerCase(FuncName);
  If (Low = 'writeln') Or (Low = 'write') Then
    ClassifyTaintSink := TNK_WRITELN_FMT
  Else If Low = 'exec' Then
    ClassifyTaintSink := TNK_EXEC
  Else If Low = 'assign' Then
    ClassifyTaintSink := TNK_ASSIGN
  Else If Low = 'rename' Then
    ClassifyTaintSink := TNK_RENAME
  Else If Low = 'erase' Then
    ClassifyTaintSink := TNK_ERASE
  Else If Low = 'chdir' Then
    ClassifyTaintSink := TNK_CHDIR
  Else If Low = 'mkdir' Then
    ClassifyTaintSink := TNK_MKDIR
  Else If Low = 'val' Then
    ClassifyTaintSink := TNK_VAL
  Else
    ClassifyTaintSink := TNK_NONE;
End;

{ ---- Ajout d'une source de teinte -------------------------- }

Function AddTaintSource(Kind : TTaintSourceKind;
                        VarIdx, ASTIdx, CfgNd,
                        Ln, Co : Integer) : Integer;
Begin
  If TaintSrcCount >= MAX_TAINT_SRCS Then
  Begin
    AddTaintSource := -1;
    Exit;
  End;
  TaintSources[TaintSrcCount].Kind     := Kind;
  TaintSources[TaintSrcCount].VarIdx   := VarIdx;
  TaintSources[TaintSrcCount].ASTIndex := ASTIdx;
  TaintSources[TaintSrcCount].CfgNode  := CfgNd;
  TaintSources[TaintSrcCount].Line     := Ln;
  TaintSources[TaintSrcCount].Col      := Co;
  AddTaintSource := TaintSrcCount;
  Inc(TaintSrcCount);
End;

{ ---- Ajout d'un puits sensible ----------------------------- }

Function AddTaintSink(Kind : TTaintSinkKind;
                      ASTIdx, CfgNd, ArgVar,
                      Ln, Co : Integer) : Integer;
Begin
  If TaintSinkCount >= MAX_TAINT_SINKS Then
  Begin
    AddTaintSink := -1;
    Exit;
  End;
  TaintSinks[TaintSinkCount].Kind      := Kind;
  TaintSinks[TaintSinkCount].ASTIndex  := ASTIdx;
  TaintSinks[TaintSinkCount].CfgNode   := CfgNd;
  TaintSinks[TaintSinkCount].ArgVarIdx := ArgVar;
  TaintSinks[TaintSinkCount].Line      := Ln;
  TaintSinks[TaintSinkCount].Col       := Co;
  AddTaintSink := TaintSinkCount;
  Inc(TaintSinkCount);
End;

{ ---- Ajout d'un pas de propagation de teinte --------------- }

Function AddTaintStep(FromV, ToV, CfgNd, ASTIdx,
                      SK : Integer) : Integer;
Begin
  If TaintStepCount >= MAX_TAINT_STEPS Then
  Begin
    AddTaintStep := -1;
    Exit;
  End;
  TaintSteps[TaintStepCount].FromVar  := FromV;
  TaintSteps[TaintStepCount].ToVar    := ToV;
  TaintSteps[TaintStepCount].CfgNode  := CfgNd;
  TaintSteps[TaintStepCount].ASTIndex := ASTIdx;
  TaintSteps[TaintStepCount].StepKind := SK;
  AddTaintStep := TaintStepCount;
  Inc(TaintStepCount);
End;

{ ---- Ajout d'une alerte de teinte -------------------------- }

Function AddTaintAlert(SrcI, SinkI, PathL,
                       FirstS : Integer) : Integer;
Begin
  If TaintAlertCount >= MAX_TAINT_ALERTS Then
  Begin
    AddTaintAlert := -1;
    Exit;
  End;
  TaintAlerts[TaintAlertCount].SrcIdx    := SrcI;
  TaintAlerts[TaintAlertCount].SinkIdx   := SinkI;
  TaintAlerts[TaintAlertCount].PathLen   := PathL;
  TaintAlerts[TaintAlertCount].FirstStep := FirstS;
  AddTaintAlert := TaintAlertCount;
  Inc(TaintAlertCount);
End;

{ ---- Recherche du noeud CFG pour un noeud AST -------------- }

Function TaintFindCfgForAST(ASTIdx : Integer) : Integer;
Var
  I : Integer;
Begin
  TaintFindCfgForAST := -1;
  For I := 0 To CfgNodeCount - 1 Do
    If CfgNodes[I].ASTIndex = ASTIdx Then
    Begin
      TaintFindCfgForAST := I;
      Exit;
    End;
End;

{ ---- Collecte des sources et puits dans l'AST source ------- }

Procedure CollectTaintSourcesAndSinks;
Var
  I, CfgNd, VarIdx, ParentIdx : Integer;
  CallName : TString;
  SrcKind  : TTaintSourceKind;
  SinkKind : TTaintSinkKind;
Begin
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    { Detecter les appels (SNK_CALL et SNK_EXPR_CALL) }
    If (SrcNodes[I].Kind = SNK_CALL) Or
       (SrcNodes[I].Kind = SNK_EXPR_CALL) Then
    Begin
      CallName := SrcNodes[I].Name;
      If Length(CallName) = 0 Then
      Begin
        { Le nom peut etre dans l'enfant gauche (ident) }
        If SrcNodes[I].Left >= 0 Then
          CallName := SrcNodes[SrcNodes[I].Left].Name;
      End;
      If Length(CallName) = 0 Then Continue;

      { Verifier si c'est une source de teinte }
      SrcKind := ClassifyTaintSource(CallName);
      If SrcKind <> TSK_NONE Then
      Begin
        CfgNd := TaintFindCfgForAST(I);
        { La variable teintee est le LHS de l'affectation parente
          ou la variable de ReadLn }
        VarIdx := -1;
        { Pour ReadLn(x), l'argument est l'enfant de l'appel }
        If (SrcKind = TSK_READLN) And (SrcNodes[I].Right >= 0) Then
        Begin
          VarIdx := DfFindVar(SrcNodes[SrcNodes[I].Right].Name);
        End;
        { Pour x := ParamStr(...), le parent est l'affectation }
        If (SrcKind = TSK_PARAMSTR) Or (SrcKind = TSK_READKEY) Or
           (SrcKind = TSK_GETENV) Then
        Begin
          { Chercher l'affectation parente }
          ParentIdx := -1;
          { Parcourir pour trouver le SNK_ASSIGN parent }
          If I > 0 Then
          Begin
            { Heuristique : les noeuds proches en indice }
            If (I >= 2) And
               (SrcNodes[I - 1].Kind = SNK_ASSIGN) Then
              ParentIdx := I - 1
            Else If (I >= 2) And
                    (SrcNodes[I - 2].Kind = SNK_ASSIGN) Then
              ParentIdx := I - 2;
          End;
          If (ParentIdx >= 0) And
             (SrcNodes[ParentIdx].Left >= 0) Then
            VarIdx := DfFindVar(
              SrcNodes[SrcNodes[ParentIdx].Left].Name);
        End;
        AddTaintSource(SrcKind, VarIdx, I, CfgNd,
                       SrcNodes[I].Line, SrcNodes[I].Col);
        If VarIdx >= 0 Then
          TaintVarState[VarIdx] := True;
      End;

      { Verifier si c'est un puits sensible }
      SinkKind := ClassifyTaintSink(CallName);
      If SinkKind <> TNK_NONE Then
      Begin
        CfgNd := TaintFindCfgForAST(I);
        { L'argument est l'enfant droit de l'appel }
        VarIdx := -1;
        If SrcNodes[I].Right >= 0 Then
          VarIdx := DfFindVar(SrcNodes[SrcNodes[I].Right].Name);
        AddTaintSink(SinkKind, I, CfgNd, VarIdx,
                     SrcNodes[I].Line, SrcNodes[I].Col);
      End;
    End;
  End;
End;

{ ---- Propagation de la teinte via les chaines def-use ------ }

Procedure PropagateTaint;
Var
  Changed : Boolean;
  I, DefVarIdx, UseVarIdx, K : Integer;
  DefASTIdx, UseASTIdx, CfgNd : Integer;
Begin
  { Propager la teinte par point fixe sur les chaines def-use }
  Repeat
    Changed := False;
    For I := 0 To DfChainCount - 1 Do
    Begin
      DefVarIdx := DfDefs[DfChains[I].DefIdx].VarIdx;
      UseVarIdx := DfUses[DfChains[I].UseIdx].VarIdx;

      { Si la variable de la definition est teintee }
      If (DefVarIdx >= 0) And (DefVarIdx < MAX_DF_VARS) And
         TaintVarState[DefVarIdx] Then
      Begin
        { Chercher les affectations qui utilisent cette variable
          et definissent une autre variable }
        { L'utilisation propage la teinte a la meme variable }
        If (UseVarIdx >= 0) And (UseVarIdx < MAX_DF_VARS) Then
        Begin
          If Not TaintVarState[UseVarIdx] Then
          Begin
            { Chercher si cette utilisation est dans une
              affectation qui definit une autre variable }
            For K := 0 To DfDefCount - 1 Do
            Begin
              CfgNd := DfDefs[K].CfgNode;
              If CfgNd = DfUses[DfChains[I].UseIdx].CfgNode Then
              Begin
                If DfDefs[K].VarIdx <> DefVarIdx Then
                Begin
                  If Not TaintVarState[DfDefs[K].VarIdx] Then
                  Begin
                    TaintVarState[DfDefs[K].VarIdx] := True;
                    Changed := True;
                    DefASTIdx := DfDefs[K].ASTIndex;
                    UseASTIdx := DfUses[DfChains[I].UseIdx].ASTIndex;
                    AddTaintStep(DefVarIdx, DfDefs[K].VarIdx,
                                 CfgNd, DefASTIdx, 0);
                  End;
                End;
              End;
            End;
          End;
        End;
      End;
    End;

    { Aussi propager la teinte a travers les affectations directes
      dans l'AST source : si LHS := expr contenant var teintee }
    For I := 0 To SrcNodeCount - 1 Do
    Begin
      If SrcNodes[I].Kind <> SNK_ASSIGN Then Continue;
      If SrcNodes[I].Left < 0 Then Continue;
      If SrcNodes[I].Right < 0 Then Continue;

      { Variable cible de l'affectation }
      DefVarIdx := DfFindVar(SrcNodes[SrcNodes[I].Left].Name);
      If DefVarIdx < 0 Then Continue;
      If TaintVarState[DefVarIdx] Then Continue;

      { Variable source dans l'expression droite }
      UseVarIdx := DfFindVar(SrcNodes[SrcNodes[I].Right].Name);
      If UseVarIdx < 0 Then Continue;
      If Not TaintVarState[UseVarIdx] Then Continue;

      TaintVarState[DefVarIdx] := True;
      CfgNd := TaintFindCfgForAST(I);
      AddTaintStep(UseVarIdx, DefVarIdx, CfgNd, I, 0);
      Changed := True;
    End;
  Until Not Changed;
End;

{ ---- Verification des alertes de teinte -------------------- }

Procedure CheckTaintAlerts;
Var
  I, VarIdx : Integer;
Begin
  TaintAlertCount := 0;
  For I := 0 To TaintSinkCount - 1 Do
  Begin
    VarIdx := TaintSinks[I].ArgVarIdx;
    If (VarIdx >= 0) And (VarIdx < MAX_DF_VARS) And
       TaintVarState[VarIdx] Then
    Begin
      { Trouver la source qui teinte cette variable }
      { Pour simplifier, lier a la premiere source trouvee }
      AddTaintAlert(0, I, 0, -1);
    End
    Else
    Begin
      { Verifier si un argument quelconque dans l'appel est teinte }
      If TaintSinks[I].ASTIndex >= 0 Then
      Begin
        If SrcNodes[TaintSinks[I].ASTIndex].Right >= 0 Then
        Begin
          VarIdx := DfFindVar(
            SrcNodes[SrcNodes[TaintSinks[I].ASTIndex].Right].Name);
          If (VarIdx >= 0) And (VarIdx < MAX_DF_VARS) And
             TaintVarState[VarIdx] Then
            AddTaintAlert(0, I, 0, -1);
        End;
      End;
    End;
  End;
End;

{ ---- Point d'entree du suivi de teinte --------------------- }

Procedure RunTaintTracking;
Begin
  InitTaint;
  CollectTaintSourcesAndSinks;
  PropagateTaint;
  CheckTaintAlerts;
End;

{ ---- Affichage debug du suivi de teinte -------------------- }

Procedure DumpTaintTracking;
Var
  I : Integer;
Begin
  WriteLn('=== Suivi de Teinte (Taint Tracking) ===');
  WriteLn('Sources : ', TaintSrcCount);
  WriteLn('Puits   : ', TaintSinkCount);
  WriteLn('Pas     : ', TaintStepCount);
  WriteLn('Alertes : ', TaintAlertCount);
  WriteLn;

  { Afficher les sources de teinte }
  WriteLn('--- Sources de teinte ---');
  For I := 0 To TaintSrcCount - 1 Do
  Begin
    Write('  S', I, ' [', TaintSourceKindName(
      TaintSources[I].Kind), ']');
    If TaintSources[I].VarIdx >= 0 Then
      Write(' var="', DfVars[TaintSources[I].VarIdx].Name, '"');
    Write(' ast=', TaintSources[I].ASTIndex);
    Write(' L', TaintSources[I].Line, ':',
              TaintSources[I].Col);
    WriteLn;
  End;
  WriteLn;

  { Afficher les puits sensibles }
  WriteLn('--- Puits sensibles ---');
  For I := 0 To TaintSinkCount - 1 Do
  Begin
    Write('  K', I, ' [', TaintSinkKindName(
      TaintSinks[I].Kind), ']');
    If TaintSinks[I].ArgVarIdx >= 0 Then
      Write(' arg="', DfVars[TaintSinks[I].ArgVarIdx].Name, '"');
    Write(' ast=', TaintSinks[I].ASTIndex);
    Write(' L', TaintSinks[I].Line, ':',
              TaintSinks[I].Col);
    WriteLn;
  End;
  WriteLn;

  { Afficher les variables teintees }
  WriteLn('--- Variables teintees ---');
  For I := 0 To DfVarCount - 1 Do
    If TaintVarState[I] Then
      WriteLn('  V', I, ' "', DfVars[I].Name, '" TAINTED');
  WriteLn;

  { Afficher les pas de propagation }
  WriteLn('--- Pas de propagation ---');
  For I := 0 To TaintStepCount - 1 Do
  Begin
    Write('  T', I);
    If TaintSteps[I].FromVar >= 0 Then
      Write(' from="', DfVars[TaintSteps[I].FromVar].Name, '"');
    If TaintSteps[I].ToVar >= 0 Then
      Write(' to="', DfVars[TaintSteps[I].ToVar].Name, '"');
    Write(' cfg=N', TaintSteps[I].CfgNode);
    Case TaintSteps[I].StepKind Of
      0 : Write(' [assign]');
      1 : Write(' [call]');
      2 : Write(' [expr]');
    End;
    WriteLn;
  End;
  WriteLn;

  { Afficher les alertes }
  WriteLn('--- Alertes de teinte ---');
  If TaintAlertCount = 0 Then
    WriteLn('  (aucune alerte)')
  Else
    For I := 0 To TaintAlertCount - 1 Do
    Begin
      Write('  ALERT #', I);
      Write(' source=[', TaintSourceKindName(
        TaintSources[TaintAlerts[I].SrcIdx].Kind), ']');
      Write(' -> sink=[', TaintSinkKindName(
        TaintSinks[TaintAlerts[I].SinkIdx].Kind), ']');
      Write(' L', TaintSinks[TaintAlerts[I].SinkIdx].Line, ':',
                TaintSinks[TaintAlerts[I].SinkIdx].Col);
      WriteLn;
    End;
  WriteLn;
End;

{ ============================================================
  TODO 17 - REQUETES DE SECURITE INTEGREES POUR PASCAL [IMPLEMENTE]
  ============================================================ }

{ ---- Initialiser les requetes de securite ------------------- }

Procedure InitSecQueries;
Var
  I : Integer;
Begin
  SecAlertCount := 0;
  SecLeakCount  := 0;
  For I := 0 To MAX_SEC_ALERTS - 1 Do
  Begin
    SecAlerts[I].Kind     := SQK_NONE;
    SecAlerts[I].ASTIndex := -1;
    SecAlerts[I].VarIdx   := -1;
    SecAlerts[I].Line     := 0;
    SecAlerts[I].Col      := 0;
    SecAlerts[I].Message  := '';
    SecAlerts[I].Severity := DSEV_NOTE;
  End;
  For I := 0 To MAX_SEC_LEAKS - 1 Do
  Begin
    SecLeaks[I].VarIdx   := -1;
    SecLeaks[I].OpenAST  := -1;
    SecLeaks[I].CloseAST := -1;
    SecLeaks[I].OpenLine := 0;
    SecLeaks[I].FuncIdx  := -1;
  End;
End;

{ ---- Nom du type de requete de securite --------------------- }

Function SecQueryKindName(K : TSecQueryKind) : TString;
Begin
  Case K Of
    SQK_NONE:            SecQueryKindName := 'none';
    SQK_CMD_INJECTION:   SecQueryKindName := 'command-injection';
    SQK_BUFFER_OVERFLOW: SecQueryKindName := 'buffer-overflow';
    SQK_RESOURCE_LEAK:   SecQueryKindName := 'resource-leak';
    SQK_UNINIT_VAR:      SecQueryKindName := 'uninitialized-variable';
  Else
    SecQueryKindName := '?';
  End;
End;

{ ---- Ajouter une alerte de securite ------------------------- }

Function AddSecAlert(AKind : TSecQueryKind; AAST, AVar,
                     ALine, ACol : Integer;
                     Const AMsg : TString;
                     ASev : TDbSeverity) : Integer;
Begin
  If SecAlertCount >= MAX_SEC_ALERTS Then
  Begin
    AddSecAlert := -1;
    Exit;
  End;
  SecAlerts[SecAlertCount].Kind     := AKind;
  SecAlerts[SecAlertCount].ASTIndex := AAST;
  SecAlerts[SecAlertCount].VarIdx   := AVar;
  SecAlerts[SecAlertCount].Line     := ALine;
  SecAlerts[SecAlertCount].Col      := ACol;
  SecAlerts[SecAlertCount].Message  := AMsg;
  SecAlerts[SecAlertCount].Severity := ASev;
  AddSecAlert := SecAlertCount;
  Inc(SecAlertCount);
End;

{ ---- Ajouter un suivi de fuite de ressource ----------------- }

Function AddSecLeak(AVar, AOpenAST, AOpenLine,
                    AFunc : Integer) : Integer;
Begin
  If SecLeakCount >= MAX_SEC_LEAKS Then
  Begin
    AddSecLeak := -1;
    Exit;
  End;
  SecLeaks[SecLeakCount].VarIdx   := AVar;
  SecLeaks[SecLeakCount].OpenAST  := AOpenAST;
  SecLeaks[SecLeakCount].CloseAST := -1;
  SecLeaks[SecLeakCount].OpenLine := AOpenLine;
  SecLeaks[SecLeakCount].FuncIdx  := AFunc;
  AddSecLeak := SecLeakCount;
  Inc(SecLeakCount);
End;

{ ---- Detection d injection de commandes (Exec) -------------- }
{ Parcours l AST source a la recherche d appels a Exec dont     }
{ l argument provient d une source de donnees non fiable (taint).}

Procedure CheckCmdInjection;
Var
  I, ArgVar : Integer;
  NName     : TString;
  IsExec    : Boolean;
Begin
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    If (SrcNodes[I].Kind = SNK_CALL) Or
       (SrcNodes[I].Kind = SNK_EXPR_CALL) Then
    Begin
      NName := SrcNodes[I].Name;
      { Comparer en minuscules }
      IsExec := False;
      If Length(NName) = 4 Then
        If (NName[1] In ['E','e']) And
           (NName[2] In ['X','x']) And
           (NName[3] In ['E','e']) And
           (NName[4] In ['C','c']) Then
          IsExec := True;
      If Not IsExec Then
        Continue;

      { Verifier si un argument provient d une variable teintee }
      If SrcNodes[I].Left >= 0 Then
      Begin
        If SrcNodes[SrcNodes[I].Left].Kind = SNK_EXPR_IDENT Then
        Begin
          { Chercher la variable dans DfVars par nom }
          If DfVarCount > 0 Then
          Begin
            For ArgVar := 0 To DfVarCount - 1 Do
              If DfVars[ArgVar].Name = SrcNodes[SrcNodes[I].Left].Name Then
              Begin
                If TaintVarState[ArgVar] Then
                Begin
                  AddSecAlert(SQK_CMD_INJECTION, I, ArgVar,
                    SrcNodes[I].Line, SrcNodes[I].Col,
                    'Exec with tainted argument: ' +
                    SrcNodes[SrcNodes[I].Left].Name,
                    DSEV_ERROR);
                End;
                Break;
              End;
          End;
        End;
      End;
    End;
  End;
End;

{ ---- Detection de debordement de tampon (index tableau) ------ }
{ Parcours l AST a la recherche d acces a un tableau (EXPR_INDEX)}
{ dont l indice provient d une source non fiable.                }

Procedure CheckBufferOverflow;
Var
  I, IdxVar : Integer;
  IdxNode   : Integer;
Begin
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    If SrcNodes[I].Kind = SNK_EXPR_INDEX Then
    Begin
      { Le sous-noeud Right est l expression d indice }
      IdxNode := SrcNodes[I].Right;
      If IdxNode < 0 Then
        Continue;
      If SrcNodes[IdxNode].Kind = SNK_EXPR_IDENT Then
      Begin
        { Chercher la variable dans DfVars }
        For IdxVar := 0 To DfVarCount - 1 Do
        Begin
          If DfVars[IdxVar].Name = SrcNodes[IdxNode].Name Then
          Begin
            If TaintVarState[IdxVar] Then
            Begin
              AddSecAlert(SQK_BUFFER_OVERFLOW, I, IdxVar,
                SrcNodes[I].Line, SrcNodes[I].Col,
                'Array access with tainted index: ' +
                SrcNodes[IdxNode].Name,
                DSEV_WARNING);
            End;
            Break;
          End;
        End;
      End;
    End;
  End;
End;

{ ---- Detection de fuites de ressources (fichiers) ----------- }
{ Parcours l AST a la recherche d appels Reset/Rewrite sans     }
{ Close correspondant dans la meme fonction.                    }

Procedure CheckResourceLeak;
Var
  I, J, K, LeakIdx : Integer;
  NName        : TString;
  IsOpen       : Boolean;
  IsClose      : Boolean;
  VarName      : TString;
  FuncId       : Integer;
Begin
  { Premiere passe : collecter les ouvertures (Reset/Rewrite) }
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    If (SrcNodes[I].Kind = SNK_CALL) Or
       (SrcNodes[I].Kind = SNK_EXPR_CALL) Then
    Begin
      NName := SrcNodes[I].Name;
      IsOpen := False;
      If Length(NName) >= 5 Then
      Begin
        If (NName[1] In ['R','r']) And
           (NName[2] In ['E','e']) And
           (NName[3] In ['S','s']) And
           (NName[4] In ['E','e']) And
           (NName[5] In ['T','t']) Then
          IsOpen := True;
      End;
      If (Not IsOpen) And (Length(NName) >= 7) Then
      Begin
        If (NName[1] In ['R','r']) And
           (NName[2] In ['E','e']) And
           (NName[3] In ['W','w']) And
           (NName[4] In ['R','r']) And
           (NName[5] In ['I','i']) And
           (NName[6] In ['T','t']) And
           (NName[7] In ['E','e']) Then
          IsOpen := True;
      End;
      If Not IsOpen Then
        Continue;

      { Recuperer le nom de la variable fichier (premier argument) }
      VarName := '';
      If SrcNodes[I].Left >= 0 Then
        If SrcNodes[SrcNodes[I].Left].Kind = SNK_EXPR_IDENT Then
          VarName := SrcNodes[SrcNodes[I].Left].Name;
      If VarName = '' Then
        Continue;

      { Trouver la fonction englobante }
      FuncId := -1;
      For J := 0 To DbFunctionCnt - 1 Do
      Begin
        If (DbFunctions[J].LocId >= 0) And
           (DbFunctions[J].LocId < DbLocationCnt) Then
        Begin
          If (SrcNodes[I].Line >= DbLocations[DbFunctions[J].LocId].StartLine) And
             (SrcNodes[I].Line <= DbLocations[DbFunctions[J].LocId].EndLine) Then
          Begin
            FuncId := J;
            Break;
          End;
        End;
      End;

      { Enregistrer l ouverture }
      LeakIdx := AddSecLeak(-1, I, SrcNodes[I].Line, FuncId);
      If LeakIdx >= 0 Then
      Begin
        { Chercher l index de la variable dans DfVars }
        For K := 0 To DfVarCount - 1 Do
          If DfVars[K].Name = VarName Then
          Begin
            SecLeaks[LeakIdx].VarIdx := K;
            Break;
          End;
      End;
    End;
  End;

  { Deuxieme passe : chercher les fermetures (Close/CloseFile) }
  For I := 0 To SrcNodeCount - 1 Do
  Begin
    If (SrcNodes[I].Kind = SNK_CALL) Or
       (SrcNodes[I].Kind = SNK_EXPR_CALL) Then
    Begin
      NName := SrcNodes[I].Name;
      IsClose := False;
      If Length(NName) = 5 Then
      Begin
        If (NName[1] In ['C','c']) And
           (NName[2] In ['L','l']) And
           (NName[3] In ['O','o']) And
           (NName[4] In ['S','s']) And
           (NName[5] In ['E','e']) Then
          IsClose := True;
      End;
      If (Not IsClose) And (Length(NName) = 9) Then
      Begin
        If (NName[1] In ['C','c']) And
           (NName[2] In ['L','l']) And
           (NName[3] In ['O','o']) And
           (NName[4] In ['S','s']) And
           (NName[5] In ['E','e']) And
           (NName[6] In ['F','f']) And
           (NName[7] In ['I','i']) And
           (NName[8] In ['L','l']) And
           (NName[9] In ['E','e']) Then
          IsClose := True;
      End;
      If Not IsClose Then
        Continue;

      { Recuperer le nom de la variable fichier (premier argument) }
      VarName := '';
      If SrcNodes[I].Left >= 0 Then
        If SrcNodes[SrcNodes[I].Left].Kind = SNK_EXPR_IDENT Then
          VarName := SrcNodes[SrcNodes[I].Left].Name;
      If VarName = '' Then
        Continue;

      { Marquer la fermeture dans les fuites correspondantes }
      For J := 0 To SecLeakCount - 1 Do
      Begin
        If SecLeaks[J].CloseAST < 0 Then { pas encore ferme }
        Begin
          If SecLeaks[J].VarIdx >= 0 Then
          Begin
            If DfVars[SecLeaks[J].VarIdx].Name = VarName Then
              SecLeaks[J].CloseAST := I;
          End;
        End;
      End;
    End;
  End;

  { Troisieme passe : signaler les fichiers ouverts non fermes }
  For J := 0 To SecLeakCount - 1 Do
  Begin
    If SecLeaks[J].CloseAST < 0 Then
    Begin
      VarName := '';
      If SecLeaks[J].VarIdx >= 0 Then
        VarName := DfVars[SecLeaks[J].VarIdx].Name;
      If VarName = '' Then
        VarName := '(unknown)';
      AddSecAlert(SQK_RESOURCE_LEAK,
        SecLeaks[J].OpenAST, SecLeaks[J].VarIdx,
        SecLeaks[J].OpenLine, 1,
        'File opened but not closed: ' + VarName,
        DSEV_WARNING);
    End;
  End;
End;

{ ---- Detection de variables non initialisees ----------------- }
{ Utilise les chaines def-use de l analyse de flot de donnees    }
{ pour trouver des utilisations sans definition prealable.       }

Procedure CheckUninitVar;
Var
  I, J     : Integer;
  HasDef   : Boolean;
  VarName  : TString;
Begin
  { Pour chaque utilisation dans DfUses, verifier s il y a au   }
  { moins une definition atteignante.                            }
  For I := 0 To DfUseCount - 1 Do
  Begin
    HasDef := False;
    { Parcourir les chaines def-use pour voir si une definition
      atteint cette utilisation }
    For J := 0 To DfChainCount - 1 Do
    Begin
      If DfChains[J].UseIdx = I Then
      Begin
        HasDef := True;
        Break;
      End;
    End;

    If Not HasDef Then
    Begin
      VarName := '';
      If (DfUses[I].VarIdx >= 0) And
         (DfUses[I].VarIdx < DfVarCount) Then
        VarName := DfVars[DfUses[I].VarIdx].Name;
      If VarName = '' Then
        Continue;
      If (DfUses[I].ASTIndex >= 0) And
         (DfUses[I].ASTIndex < SrcNodeCount) Then
        AddSecAlert(SQK_UNINIT_VAR,
          DfUses[I].ASTIndex,
          DfUses[I].VarIdx,
          SrcNodes[DfUses[I].ASTIndex].Line,
          SrcNodes[DfUses[I].ASTIndex].Col,
          'Possibly uninitialized variable: ' + VarName,
          DSEV_WARNING);
    End;
  End;
End;

{ ---- Point d entree des requetes de securite ---------------- }

Procedure RunSecurityQueries;
Begin
  InitSecQueries;
  CheckCmdInjection;
  CheckBufferOverflow;
  CheckResourceLeak;
  CheckUninitVar;
End;

{ ---- Affichage debug des alertes de securite ---------------- }

Procedure DumpSecurityAlerts;
Var
  I : Integer;
Begin
  WriteLn('=== Requetes de Securite (Security Queries) ===');
  WriteLn('Alertes : ', SecAlertCount);
  WriteLn('Fuites  : ', SecLeakCount);
  WriteLn;

  { Afficher les fuites de ressources detectees }
  If SecLeakCount > 0 Then
  Begin
    WriteLn('--- Suivi des ressources fichier ---');
    For I := 0 To SecLeakCount - 1 Do
    Begin
      Write('  R', I);
      If SecLeaks[I].VarIdx >= 0 Then
        Write(' var="', DfVars[SecLeaks[I].VarIdx].Name, '"')
      Else
        Write(' var=?');
      Write(' open=L', SecLeaks[I].OpenLine);
      If SecLeaks[I].CloseAST >= 0 Then
        Write(' [closed]')
      Else
        Write(' [LEAKED]');
      WriteLn;
    End;
    WriteLn;
  End;

  { Afficher toutes les alertes de securite }
  If SecAlertCount = 0 Then
    WriteLn('  (aucune alerte de securite)')
  Else
  Begin
    WriteLn('--- Alertes de securite ---');
    For I := 0 To SecAlertCount - 1 Do
    Begin
      Write('  SEC #', I);
      Write(' [', SecQueryKindName(SecAlerts[I].Kind), ']');
      Write(' ', DbSeverityName(SecAlerts[I].Severity));
      Write(' L', SecAlerts[I].Line, ':', SecAlerts[I].Col);
      If SecAlerts[I].VarIdx >= 0 Then
        Write(' var="', DfVars[SecAlerts[I].VarIdx].Name, '"');
      WriteLn;
      WriteLn('    ', SecAlerts[I].Message);
    End;
  End;
  WriteLn;
End;

{ ============================================================
  TODO 18 - SORTIE AU FORMAT SARIF v2.1.0 [IMPLEMENTE]
  ============================================================ }

{ Echapper une chaine pour JSON : guillemets, antislash, retour
  chariot. Conforme a RFC 8259.                                  }
Function SarifEscStr(Const S : TString) : TString;
Var
  R : TString;
  I : Integer;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    Case S[I] Of
      '"' : R := R + '\"';
      '\' : R := R + '\\';
      #8  : R := R + '\b';
      #9  : R := R + '\t';
      #10 : R := R + '\n';
      #12 : R := R + '\f';
      #13 : R := R + '\r';
    Else
      If Ord(S[I]) < 32 Then
        { caracteres de controle non imprimables : ignorer }
      Else
        R := R + S[I];
    End;
  End;
  SarifEscStr := R;
End;

{ Convertir un TDbSeverity en niveau SARIF (error/warning/note) }
Function SarifSeverity(S : TDbSeverity) : TString;
Begin
  Case S Of
    DSEV_ERROR   : SarifSeverity := 'error';
    DSEV_WARNING : SarifSeverity := 'warning';
    DSEV_NOTE    : SarifSeverity := 'note';
  Else
    SarifSeverity := 'note';
  End;
End;

{ Convertir un TSecQueryKind en identifiant de regle SARIF }
Function SarifRuleId(K : TSecQueryKind) : TString;
Begin
  Case K Of
    SQK_CMD_INJECTION   : SarifRuleId := 'pascal/command-injection';
    SQK_BUFFER_OVERFLOW : SarifRuleId := 'pascal/buffer-overflow';
    SQK_RESOURCE_LEAK   : SarifRuleId := 'pascal/resource-leak';
    SQK_UNINIT_VAR      : SarifRuleId := 'pascal/uninitialized-variable';
  Else
    SarifRuleId := 'pascal/unknown';
  End;
End;

{ Description courte d une regle de securite }
Function SarifRuleDesc(K : TSecQueryKind) : TString;
Begin
  Case K Of
    SQK_CMD_INJECTION   : SarifRuleDesc := 'Command injection vulnerability';
    SQK_BUFFER_OVERFLOW : SarifRuleDesc := 'Potential buffer overflow';
    SQK_RESOURCE_LEAK   : SarifRuleDesc := 'Resource leak detected';
    SQK_UNINIT_VAR      : SarifRuleDesc := 'Use of uninitialized variable';
  Else
    SarifRuleDesc := 'Unknown security issue';
  End;
End;

{ Ecrire le rapport SARIF v2.1.0 complet dans un fichier ou la console.
  Genere un JSON conforme au schema SARIF :
    - $schema + version
    - runs[] avec tool.driver (name, version, rules[])
    - results[] avec ruleId, level, message, locations[], codeFlows[]
}
Procedure WriteSarifReport(Const FileName : TString);
Var
  F           : Text;
  ToFile      : Boolean;
  I, J        : Integer;
  A           : TSecAlert;
  LocFile     : TString;
  RulesWritten: Array[0..4] Of Boolean;
  NeedComma   : Boolean;
  TA          : TTaintAlert;
  Src         : TTaintSource;
  Snk         : TTaintSink;
Begin
  ToFile := (FileName <> '');
  If ToFile Then
  Begin
    Assign(F, FileName);
    {$I-}
    Rewrite(F);
    {$I+}
    If IOResult <> 0 Then
    Begin
      WriteLn('SARIF: impossible d''ouvrir: ', FileName);
      Exit;
    End;
  End;

  { --- Helper: ecrire vers fichier ou stdout --- }
  { On utilise F si ToFile, sinon Output          }

  { ---- En-tete SARIF ---- }
  If ToFile Then
  Begin
    WriteLn(F, '{');
    WriteLn(F, '  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",');
    WriteLn(F, '  "version": "2.1.0",');
    WriteLn(F, '  "runs": [');
    WriteLn(F, '    {');
    WriteLn(F, '      "tool": {');
    WriteLn(F, '        "driver": {');
    WriteLn(F, '          "name": "codeql-pascal",');
    WriteLn(F, '          "version": "1.0.0",');
    WriteLn(F, '          "informationUri": "https://www.gladir.com/dev-cools",');
  End
  Else
  Begin
    WriteLn('{');
    WriteLn('  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",');
    WriteLn('  "version": "2.1.0",');
    WriteLn('  "runs": [');
    WriteLn('    {');
    WriteLn('      "tool": {');
    WriteLn('        "driver": {');
    WriteLn('          "name": "codeql-pascal",');
    WriteLn('          "version": "1.0.0",');
    WriteLn('          "informationUri": "https://www.gladir.com/dev-cools",');
  End;

  { ---- rules[] ---- }
  For I := 0 To 4 Do
    RulesWritten[I] := False;
  { Determiner quelles regles sont utilisees }
  For I := 0 To SecAlertCount - 1 Do
    RulesWritten[Ord(SecAlerts[I].Kind)] := True;

  If ToFile Then
    Write(F, '          "rules": [')
  Else
    Write('          "rules": [');

  NeedComma := False;
  For I := 1 To 4 Do { SQK_CMD_INJECTION..SQK_UNINIT_VAR }
  Begin
    If RulesWritten[I] Then
    Begin
      If NeedComma Then
      Begin
        If ToFile Then WriteLn(F, ',') Else WriteLn(',');
      End
      Else
      Begin
        If ToFile Then WriteLn(F) Else WriteLn;
      End;
      If ToFile Then
      Begin
        WriteLn(F, '            {');
        WriteLn(F, '              "id": "', SarifRuleId(TSecQueryKind(I)), '",');
        WriteLn(F, '              "shortDescription": {');
        WriteLn(F, '                "text": "', SarifEscStr(SarifRuleDesc(TSecQueryKind(I))), '"');
        WriteLn(F, '              },');
        WriteLn(F, '              "defaultConfiguration": {');
        WriteLn(F, '                "level": "warning"');
        WriteLn(F, '              }');
        Write(F,   '            }');
      End
      Else
      Begin
        WriteLn('            {');
        WriteLn('              "id": "', SarifRuleId(TSecQueryKind(I)), '",');
        WriteLn('              "shortDescription": {');
        WriteLn('                "text": "', SarifEscStr(SarifRuleDesc(TSecQueryKind(I))), '"');
        WriteLn('              },');
        WriteLn('              "defaultConfiguration": {');
        WriteLn('                "level": "warning"');
        WriteLn('              }');
        Write(  '            }');
      End;
      NeedComma := True;
    End;
  End;
  If ToFile Then
  Begin
    WriteLn(F);
    WriteLn(F, '          ]');
    WriteLn(F, '        }');
    WriteLn(F, '      },');
  End
  Else
  Begin
    WriteLn;
    WriteLn('          ]');
    WriteLn('        }');
    WriteLn('      },');
  End;

  { ---- results[] ---- }
  If ToFile Then
    Write(F, '      "results": [')
  Else
    Write('      "results": [');

  For I := 0 To SecAlertCount - 1 Do
  Begin
    A := SecAlerts[I];
    If I > 0 Then
    Begin
      If ToFile Then WriteLn(F, ',') Else WriteLn(',');
    End
    Else
    Begin
      If ToFile Then WriteLn(F) Else WriteLn;
    End;

    { Determiner le nom du fichier source }
    If DbFileCnt > 0 Then
      LocFile := SarifEscStr(DbFiles[0].Name)
    Else
      LocFile := 'unknown.pas';

    If ToFile Then
    Begin
      WriteLn(F, '        {');
      WriteLn(F, '          "ruleId": "', SarifRuleId(A.Kind), '",');
      WriteLn(F, '          "level": "', SarifSeverity(A.Severity), '",');
      WriteLn(F, '          "message": {');
      WriteLn(F, '            "text": "', SarifEscStr(A.Message), '"');
      WriteLn(F, '          },');
      WriteLn(F, '          "locations": [');
      WriteLn(F, '            {');
      WriteLn(F, '              "physicalLocation": {');
      WriteLn(F, '                "artifactLocation": {');
      WriteLn(F, '                  "uri": "', LocFile, '"');
      WriteLn(F, '                },');
      WriteLn(F, '                "region": {');
      WriteLn(F, '                  "startLine": ', A.Line, ',');
      WriteLn(F, '                  "startColumn": ', A.Col);
      WriteLn(F, '                }');
      WriteLn(F, '              }');
      WriteLn(F, '            }');
      WriteLn(F, '          ]');
    End
    Else
    Begin
      WriteLn('        {');
      WriteLn('          "ruleId": "', SarifRuleId(A.Kind), '",');
      WriteLn('          "level": "', SarifSeverity(A.Severity), '",');
      WriteLn('          "message": {');
      WriteLn('            "text": "', SarifEscStr(A.Message), '"');
      WriteLn('          },');
      WriteLn('          "locations": [');
      WriteLn('            {');
      WriteLn('              "physicalLocation": {');
      WriteLn('                "artifactLocation": {');
      WriteLn('                  "uri": "', LocFile, '"');
      WriteLn('                },');
      WriteLn('                "region": {');
      WriteLn('                  "startLine": ', A.Line, ',');
      WriteLn('                  "startColumn": ', A.Col);
      WriteLn('                }');
      WriteLn('              }');
      WriteLn('            }');
      WriteLn('          ]');
    End;

    { ---- codeFlows[] pour les alertes de type injection de commandes
           (SQK_CMD_INJECTION) : on cherche un TTaintAlert correspondant. }
    If A.Kind = SQK_CMD_INJECTION Then
    Begin
      For J := 0 To TaintAlertCount - 1 Do
      Begin
        TA := TaintAlerts[J];
        Src := TaintSources[TA.SrcIdx];
        Snk := TaintSinks[TA.SinkIdx];
        { Verifier que le puits correspond a la meme ligne }
        If (Snk.Line = A.Line) And (Snk.Kind = TNK_EXEC) Then
        Begin
          If ToFile Then
          Begin
            WriteLn(F, ',');
            WriteLn(F, '          "codeFlows": [');
            WriteLn(F, '            {');
            WriteLn(F, '              "threadFlows": [');
            WriteLn(F, '                {');
            WriteLn(F, '                  "locations": [');
            { Source }
            WriteLn(F, '                    {');
            WriteLn(F, '                      "location": {');
            WriteLn(F, '                        "physicalLocation": {');
            WriteLn(F, '                          "artifactLocation": {');
            WriteLn(F, '                            "uri": "', LocFile, '"');
            WriteLn(F, '                          },');
            WriteLn(F, '                          "region": {');
            WriteLn(F, '                            "startLine": ', Src.Line, ',');
            WriteLn(F, '                            "startColumn": ', Src.Col);
            WriteLn(F, '                          }');
            WriteLn(F, '                        },');
            WriteLn(F, '                        "message": {');
            WriteLn(F, '                          "text": "Taint source"');
            WriteLn(F, '                        }');
            WriteLn(F, '                      }');
            WriteLn(F, '                    },');
            { Sink }
            WriteLn(F, '                    {');
            WriteLn(F, '                      "location": {');
            WriteLn(F, '                        "physicalLocation": {');
            WriteLn(F, '                          "artifactLocation": {');
            WriteLn(F, '                            "uri": "', LocFile, '"');
            WriteLn(F, '                          },');
            WriteLn(F, '                          "region": {');
            WriteLn(F, '                            "startLine": ', Snk.Line, ',');
            WriteLn(F, '                            "startColumn": ', Snk.Col);
            WriteLn(F, '                          }');
            WriteLn(F, '                        },');
            WriteLn(F, '                        "message": {');
            WriteLn(F, '                          "text": "Taint sink"');
            WriteLn(F, '                        }');
            WriteLn(F, '                      }');
            WriteLn(F, '                    }');
            WriteLn(F, '                  ]');
            WriteLn(F, '                }');
            WriteLn(F, '              ]');
            WriteLn(F, '            }');
            WriteLn(F, '          ]');
          End
          Else
          Begin
            WriteLn(',');
            WriteLn('          "codeFlows": [');
            WriteLn('            {');
            WriteLn('              "threadFlows": [');
            WriteLn('                {');
            WriteLn('                  "locations": [');
            WriteLn('                    {');
            WriteLn('                      "location": {');
            WriteLn('                        "physicalLocation": {');
            WriteLn('                          "artifactLocation": {');
            WriteLn('                            "uri": "', LocFile, '"');
            WriteLn('                          },');
            WriteLn('                          "region": {');
            WriteLn('                            "startLine": ', Src.Line, ',');
            WriteLn('                            "startColumn": ', Src.Col);
            WriteLn('                          }');
            WriteLn('                        },');
            WriteLn('                        "message": {');
            WriteLn('                          "text": "Taint source"');
            WriteLn('                        }');
            WriteLn('                      }');
            WriteLn('                    },');
            WriteLn('                    {');
            WriteLn('                      "location": {');
            WriteLn('                        "physicalLocation": {');
            WriteLn('                          "artifactLocation": {');
            WriteLn('                            "uri": "', LocFile, '"');
            WriteLn('                          },');
            WriteLn('                          "region": {');
            WriteLn('                            "startLine": ', Snk.Line, ',');
            WriteLn('                            "startColumn": ', Snk.Col);
            WriteLn('                          }');
            WriteLn('                        },');
            WriteLn('                        "message": {');
            WriteLn('                          "text": "Taint sink"');
            WriteLn('                        }');
            WriteLn('                      }');
            WriteLn('                    }');
            WriteLn('                  ]');
            WriteLn('                }');
            WriteLn('              ]');
            WriteLn('            }');
            WriteLn('          ]');
          End;
          Break; { un seul codeFlow par resultat }
        End;
      End; { for J }
    End; { if CMD_INJECTION }

    { Fermer le result }
    If ToFile Then
      Write(F, '        }')
    Else
      Write('        }');
  End; { for I }

  { ---- Pied de page SARIF ---- }
  If ToFile Then
  Begin
    WriteLn(F);
    WriteLn(F, '      ]');
    WriteLn(F, '    }');
    WriteLn(F, '  ]');
    WriteLn(F, '}');
  End
  Else
  Begin
    WriteLn;
    WriteLn('      ]');
    WriteLn('    }');
    WriteLn('  ]');
    WriteLn('}');
  End;

  If ToFile Then
  Begin
    Close(F);
    WriteLn('SARIF: rapport ecrit dans ', FileName);
  End;
End;

{ Procedure d entree pour la generation SARIF.
  Utilise le fichier de sortie configure dans les options
  ou ecrit sur la sortie standard.                         }
Procedure DumpSarif;
Begin
  WriteSarifReport(Opts.OutputFile);
End;

{ ============================================================
  TODO 19 - SORTIE AU FORMAT CSV ET TEXTE [IMPLEMENTE]
  ============================================================ }

{ Echapper un champ CSV conformement a la RFC 4180 :
  - encadrer par des guillemets si le champ contient une virgule,
    un guillemet ou un saut de ligne
  - doubler chaque guillemet interne                              }
Function CsvEscField(Const S : TString) : TString;
Var
  NeedQuote : Boolean;
  R : TString;
  I : Integer;
Begin
  NeedQuote := False;
  For I := 1 To Length(S) Do
    If (S[I] = ',') Or (S[I] = '"') Or (S[I] = #10) Or (S[I] = #13) Then
      NeedQuote := True;

  If Not NeedQuote Then
  Begin
    CsvEscField := S;
    Exit;
  End;

  R := '"';
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '"' Then
      R := R + '""'
    Else
      R := R + S[I];
  End;
  R := R + '"';
  CsvEscField := R;
End;

{ Convertir une valeur de liaison en chaine brute (sans guillemets
  autour des chaines) pour la sortie CSV.                          }
Function BindingToRawStr(Const V : TBindingValue) : TString;
Var
  S : String[20];
Begin
  Case V.Kind Of
    BK_INT:
    Begin
      Str(V.IntVal, S);
      BindingToRawStr := S;
    End;
    BK_FLOAT:
    Begin
      Str(V.FloatVal:0:4, S);
      BindingToRawStr := S;
    End;
    BK_STRING:
      BindingToRawStr := V.StrVal;
    BK_DBREF:
    Begin
      Str(V.RefId, S);
      BindingToRawStr := V.RefTable + '#' + S;
    End;
  Else
    BindingToRawStr := '';
  End;
End;

{ ---- Ecrire les resultats de requete au format CSV ----------- }

Procedure WriteResultCSV(Const FileName : TString);
Var
  F       : Text;
  ToFile  : Boolean;
  I, J    : Integer;
  SrcFile : TString;
Begin
  If DbFileCnt > 0 Then
    SrcFile := DbFiles[0].Name
  Else
    SrcFile := 'unknown.pas';
  ToFile := (FileName <> '');
  If ToFile Then
  Begin
    Assign(F, FileName);
    {$I-}
    Rewrite(F);
    {$I+}
    If IOResult <> 0 Then
    Begin
      WriteLn('CSV: impossible de creer: ', FileName);
      ToFile := False;
    End;
  End;

  { En-tete CSV }
  If ToFile Then
  Begin
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write(F, ',');
      Write(F, CsvEscField(EvalResults.ColNames[J]));
    End;
    WriteLn(F);
  End
  Else
  Begin
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write(',');
      Write(CsvEscField(EvalResults.ColNames[J]));
    End;
    WriteLn;
  End;

  { Lignes de donnees }
  For I := 0 To EvalResults.NRows - 1 Do
  Begin
    If ToFile Then
    Begin
      For J := 0 To EvalResults.Rows[I].NCols - 1 Do
      Begin
        If J > 0 Then Write(F, ',');
        Write(F, CsvEscField(
          BindingToRawStr(EvalResults.Rows[I].Cols[J])));
      End;
      WriteLn(F);
    End
    Else
    Begin
      For J := 0 To EvalResults.Rows[I].NCols - 1 Do
      Begin
        If J > 0 Then Write(',');
        Write(CsvEscField(
          BindingToRawStr(EvalResults.Rows[I].Cols[J])));
      End;
      WriteLn;
    End;
  End;

  { Alertes de securite en CSV }
  If SecAlertCount > 0 Then
  Begin
    If ToFile Then
    Begin
      WriteLn(F);
      WriteLn(F, 'rule,severity,file,line,col,message');
      For I := 0 To SecAlertCount - 1 Do
      Begin
        Write(F, CsvEscField(SecQueryKindName(SecAlerts[I].Kind)));
        Write(F, ',');
        Write(F, CsvEscField(DbSeverityName(SecAlerts[I].Severity)));
        Write(F, ',');
        Write(F, CsvEscField(SrcFile));
        Write(F, ',', SecAlerts[I].Line);
        Write(F, ',', SecAlerts[I].Col);
        Write(F, ',');
        Write(F, CsvEscField(SecAlerts[I].Message));
        WriteLn(F);
      End;
    End
    Else
    Begin
      WriteLn;
      WriteLn('rule,severity,file,line,col,message');
      For I := 0 To SecAlertCount - 1 Do
      Begin
        Write(CsvEscField(SecQueryKindName(SecAlerts[I].Kind)));
        Write(',');
        Write(CsvEscField(DbSeverityName(SecAlerts[I].Severity)));
        Write(',');
        Write(CsvEscField(SrcFile));
        Write(',', SecAlerts[I].Line);
        Write(',', SecAlerts[I].Col);
        Write(',');
        Write(CsvEscField(SecAlerts[I].Message));
        WriteLn;
      End;
    End;
  End;

  If ToFile Then
  Begin
    Close(F);
    WriteLn('CSV: rapport ecrit dans ', FileName);
  End;
End;

{ ---- Fonctions utilitaires pour le format texte tabule ------- }

{ Repeter un caractere N fois }
Function RepeatCh(C : Char; N : Integer) : TString;
Var
  R : TString;
  I : Integer;
Begin
  R := '';
  If N > MAX_STR Then N := MAX_STR;
  For I := 1 To N Do
    R := R + C;
  RepeatCh := R;
End;

{ Completer une chaine a droite avec des espaces pour atteindre
  une largeur W.  Tronquer si elle depasse.                      }
Function PadRight(Const S : TString; W : Integer) : TString;
Var
  R : TString;
  I : Integer;
Begin
  If Length(S) >= W Then
  Begin
    R := Copy(S, 1, W);
    PadRight := R;
    Exit;
  End;
  R := S;
  For I := Length(S) + 1 To W Do
    R := R + ' ';
  PadRight := R;
End;

{ ---- Ecrire les resultats de requete au format texte tabule -- }

Procedure WriteResultText(Const FileName : TString);
Var
  F        : Text;
  ToFile   : Boolean;
  I, J, W  : Integer;
  ColW     : Array[0..MAX_RESULT_COLS - 1] Of Integer;
  CellStr  : TString;
  SrcFile  : TString;
  PageNo   : Integer;
  RowInPage: Integer;
Begin
  If DbFileCnt > 0 Then
    SrcFile := DbFiles[0].Name
  Else
    SrcFile := 'unknown.pas';
  ToFile := (FileName <> '');
  If ToFile Then
  Begin
    Assign(F, FileName);
    {$I-}
    Rewrite(F);
    {$I+}
    If IOResult <> 0 Then
    Begin
      WriteLn('TEXT: impossible de creer: ', FileName);
      ToFile := False;
    End;
  End;

  { Calculer les largeurs de colonnes }
  For J := 0 To EvalResults.NCols - 1 Do
  Begin
    ColW[J] := Length(EvalResults.ColNames[J]);
    If ColW[J] < TEXT_COL_MIN Then ColW[J] := TEXT_COL_MIN;
  End;

  For I := 0 To EvalResults.NRows - 1 Do
  Begin
    For J := 0 To EvalResults.Rows[I].NCols - 1 Do
    Begin
      CellStr := BindingToRawStr(EvalResults.Rows[I].Cols[J]);
      W := Length(CellStr);
      If (J < EvalResults.NCols) And (W > ColW[J]) Then
        ColW[J] := W;
    End;
  End;

  { Limiter a TEXT_COL_MAX }
  For J := 0 To EvalResults.NCols - 1 Do
    If ColW[J] > TEXT_COL_MAX Then ColW[J] := TEXT_COL_MAX;

  { Afficher avec pagination }
  PageNo    := 1;
  RowInPage := 0;

  { ---- En-tete ---- }
  If ToFile Then
  Begin
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write(F, ' | ');
      Write(F, PadRight(EvalResults.ColNames[J], ColW[J]));
    End;
    WriteLn(F);
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write(F, '-+-');
      Write(F, RepeatCh('-', ColW[J]));
    End;
    WriteLn(F);
  End
  Else
  Begin
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write(' | ');
      Write(PadRight(EvalResults.ColNames[J], ColW[J]));
    End;
    WriteLn;
    For J := 0 To EvalResults.NCols - 1 Do
    Begin
      If J > 0 Then Write('-+-');
      Write(RepeatCh('-', ColW[J]));
    End;
    WriteLn;
  End;

  { ---- Lignes de donnees ---- }
  For I := 0 To EvalResults.NRows - 1 Do
  Begin
    If ToFile Then
    Begin
      For J := 0 To EvalResults.Rows[I].NCols - 1 Do
      Begin
        If J > 0 Then Write(F, ' | ');
        CellStr := BindingToRawStr(EvalResults.Rows[I].Cols[J]);
        If J < EvalResults.NCols Then
          Write(F, PadRight(CellStr, ColW[J]))
        Else
          Write(F, CellStr);
      End;
      WriteLn(F);
    End
    Else
    Begin
      For J := 0 To EvalResults.Rows[I].NCols - 1 Do
      Begin
        If J > 0 Then Write(' | ');
        CellStr := BindingToRawStr(EvalResults.Rows[I].Cols[J]);
        If J < EvalResults.NCols Then
          Write(PadRight(CellStr, ColW[J]))
        Else
          Write(CellStr);
      End;
      WriteLn;
    End;

    Inc(RowInPage);
    If (RowInPage >= CSV_PAGE_SIZE) And
       (I < EvalResults.NRows - 1) Then
    Begin
      { Separateur de page }
      If ToFile Then
        WriteLn(F, '--- Page ', PageNo, ' ---')
      Else
        WriteLn('--- Page ', PageNo, ' ---');
      Inc(PageNo);
      RowInPage := 0;
    End;
  End;

  { ---- Pied ---- }
  If ToFile Then
  Begin
    WriteLn(F);
    WriteLn(F, '(', EvalResults.NRows, ' lignes)');
  End
  Else
  Begin
    WriteLn;
    WriteLn('(', EvalResults.NRows, ' lignes)');
  End;

  { ---- Alertes de securite en texte tabule ---- }
  If SecAlertCount > 0 Then
  Begin
    If ToFile Then
    Begin
      WriteLn(F);
      WriteLn(F, PadRight('Rule', 20), ' | ',
                 PadRight('Sev', 8), ' | ',
                 PadRight('File', 20), ' | ',
                 PadRight('Line', 6), ' | ',
                 'Message');
      WriteLn(F, RepeatCh('-', 20), '-+-',
                 RepeatCh('-', 8), '-+-',
                 RepeatCh('-', 20), '-+-',
                 RepeatCh('-', 6), '-+-',
                 RepeatCh('-', 30));
      For I := 0 To SecAlertCount - 1 Do
      Begin
        CellStr := '';
        Str(SecAlerts[I].Line, CellStr);
        WriteLn(F, PadRight(SecQueryKindName(SecAlerts[I].Kind), 20), ' | ',
                   PadRight(DbSeverityName(SecAlerts[I].Severity), 8), ' | ',
                   PadRight(SrcFile, 20), ' | ',
                   PadRight(CellStr, 6), ' | ',
                   SecAlerts[I].Message);
      End;
    End
    Else
    Begin
      WriteLn;
      WriteLn(PadRight('Rule', 20), ' | ',
              PadRight('Sev', 8), ' | ',
              PadRight('File', 20), ' | ',
              PadRight('Line', 6), ' | ',
              'Message');
      WriteLn(RepeatCh('-', 20), '-+-',
              RepeatCh('-', 8), '-+-',
              RepeatCh('-', 20), '-+-',
              RepeatCh('-', 6), '-+-',
              RepeatCh('-', 30));
      For I := 0 To SecAlertCount - 1 Do
      Begin
        CellStr := '';
        Str(SecAlerts[I].Line, CellStr);
        WriteLn(PadRight(SecQueryKindName(SecAlerts[I].Kind), 20), ' | ',
                PadRight(DbSeverityName(SecAlerts[I].Severity), 8), ' | ',
                PadRight(SrcFile, 20), ' | ',
                PadRight(CellStr, 6), ' | ',
                SecAlerts[I].Message);
      End;
    End;
  End;

  If ToFile Then
  Begin
    Close(F);
    WriteLn('TEXT: rapport ecrit dans ', FileName);
  End;
End;

{ Procedure d entree pour la generation CSV.
  Utilise le fichier de sortie configure dans les options
  ou ecrit sur la sortie standard.                         }
Procedure DumpCSV;
Begin
  WriteResultCSV(Opts.OutputFile);
End;

{ Procedure d entree pour la generation texte tabule.
  Utilise le fichier de sortie configure dans les options
  ou ecrit sur la sortie standard.                         }
Procedure DumpText;
Begin
  WriteResultText(Opts.OutputFile);
End;

{ ============================================================
  TODO 20 - SYSTEME D IMPORT ET DE MODULES QL [IMPLEMENTE]
  ============================================================ }

{ ---- InitModules : initialiser le registre de modules ------ }

Procedure InitModules;
Var I : Integer;
Begin
  QLModuleCount := 0;
  QLImportCount := 0;
  For I := 0 To MAX_QL_MODULES - 1 Do
  Begin
    QLModules[I].Name       := '';
    QLModules[I].ShortName  := '';
    QLModules[I].FilePath   := '';
    QLModules[I].ParentIdx  := -1;
    QLModules[I].FirstChild := -1;
    QLModules[I].NextSibling:= -1;
    QLModules[I].ImportStart:= 0;
    QLModules[I].ImportCount:= 0;
    QLModules[I].Loaded     := False;
  End;
  For I := 0 To MAX_QL_IMPORTS - 1 Do
  Begin
    QLImports[I].Path        := '';
    QLImports[I].Alias       := '';
    QLImports[I].ResolvedPath:= '';
    QLImports[I].ModuleIdx   := -1;
    QLImports[I].Status      := IMS_PENDING;
    QLImports[I].ASTNodeIdx  := -1;
  End;
End;

{ ---- ExtractShortName : dernier segment d un chemin -------- }
{   Ex: semmle.code.pascal -> pascal                           }

Function ExtractShortName(Const FullPath : TString) : TString;
Var
  I    : Integer;
  Last : Integer;
Begin
  Last := 1;
  For I := 1 To Length(FullPath) Do
    If FullPath[I] = '.' Then
      Last := I + 1;
  ExtractShortName := Copy(FullPath, Last, Length(FullPath) - Last + 1);
End;

{ ---- DotPathToFilePath : convertir un chemin avec des points }
{   en chemin avec separateurs de repertoire.                  }
{   Ex: semmle.code.pascal -> semmle/code/pascal               }

Function DotPathToFilePath(Const DotPath : TString) : TString;
Var
  R : TString;
  I : Integer;
Begin
  R := '';
  For I := 1 To Length(DotPath) Do
  Begin
    If DotPath[I] = '.' Then
      R := R + '/'
    Else
      R := R + DotPath[I];
  End;
  DotPathToFilePath := R;
End;

{ ---- FindModuleByName : chercher un module par son nom ----- }

Function FindModuleByName(Const MName : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To QLModuleCount - 1 Do
    If QLModules[I].Name = MName Then
    Begin
      FindModuleByName := I;
      Exit;
    End;
  FindModuleByName := -1;
End;

{ ---- FindModuleByShort : chercher un module par nom court -- }

Function FindModuleByShort(Const SName : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To QLModuleCount - 1 Do
    If QLModules[I].ShortName = SName Then
    Begin
      FindModuleByShort := I;
      Exit;
    End;
  FindModuleByShort := -1;
End;

{ ---- RegisterModule : enregistrer un nouveau module -------- }

Function RegisterModule(Const MName, FPath : TString;
                        ParIdx : Integer) : Integer;
Var
  Idx : Integer;
  Sib : Integer;
Begin
  Idx := FindModuleByName(MName);
  If Idx >= 0 Then
  Begin
    RegisterModule := Idx;
    Exit;
  End;
  If QLModuleCount >= MAX_QL_MODULES Then
  Begin
    WarnMsg('Module limit reached');
    RegisterModule := -1;
    Exit;
  End;
  Idx := QLModuleCount;
  Inc(QLModuleCount);
  QLModules[Idx].Name       := MName;
  QLModules[Idx].ShortName  := ExtractShortName(MName);
  QLModules[Idx].FilePath   := FPath;
  QLModules[Idx].ParentIdx  := ParIdx;
  QLModules[Idx].FirstChild := -1;
  QLModules[Idx].NextSibling:= -1;
  QLModules[Idx].ImportStart:= 0;
  QLModules[Idx].ImportCount:= 0;
  QLModules[Idx].Loaded     := False;
  { Relier au parent }
  If ParIdx >= 0 Then
  Begin
    If QLModules[ParIdx].FirstChild < 0 Then
      QLModules[ParIdx].FirstChild := Idx
    Else
    Begin
      Sib := QLModules[ParIdx].FirstChild;
      While QLModules[Sib].NextSibling >= 0 Do
        Sib := QLModules[Sib].NextSibling;
      QLModules[Sib].NextSibling := Idx;
    End;
  End;
  RegisterModule := Idx;
End;

{ ---- AddQLImport : ajouter un import au registre ----------- }

Function AddQLImport(Const IPath, IAlias : TString;
                     ASTIdx : Integer) : Integer;
Var Idx : Integer;
Begin
  If QLImportCount >= MAX_QL_IMPORTS Then
  Begin
    WarnMsg('Import limit reached');
    AddQLImport := -1;
    Exit;
  End;
  Idx := QLImportCount;
  Inc(QLImportCount);
  QLImports[Idx].Path        := IPath;
  QLImports[Idx].Alias       := IAlias;
  QLImports[Idx].ResolvedPath:= '';
  QLImports[Idx].ModuleIdx   := -1;
  QLImports[Idx].Status      := IMS_PENDING;
  QLImports[Idx].ASTNodeIdx  := ASTIdx;
  AddQLImport := Idx;
End;

{ ---- CollectImportsFromAST : parcourir l AST pour extraire - }
{   les declarations import et les enregistrer.                }

Procedure CollectImportsFromAST(N : Integer);
Var
  Child : Integer;
Begin
  If N < 0 Then Exit;
  If N >= NodeCount Then Exit;

  If Nodes[N].Kind = NK_IMPORT Then
    AddQLImport(Nodes[N].Name, '', N);

  { Parcourir les enfants }
  Child := Nodes[N].Left;
  While (Child >= 0) And (Child < NodeCount) Do
  Begin
    CollectImportsFromAST(Child);
    Child := Nodes[Child].Next;
  End;

  If Nodes[N].Right >= 0 Then
    CollectImportsFromAST(Nodes[N].Right);
  If Nodes[N].Extra >= 0 Then
    CollectImportsFromAST(Nodes[N].Extra);
End;

{ ---- FileExists2 : tester si un fichier existe ------------- }

Function FileExists2(Const FName : TString) : Boolean;
Var F : Text;
Begin
  Assign(F, FName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists2 := True;
  End
  Else
    FileExists2 := False;
End;

{ ---- ResolveImportPath : resoudre un chemin d import ------- }
{   Cherche le fichier .ql correspondant dans les chemins      }
{   de recherche (SearchPath) et le repertoire courant.        }

Function ResolveImportPath(Const DotPath : TString) : TString;
Var
  RelPath  : TString;
  Candidate: TString;
Begin
  RelPath := DotPathToFilePath(DotPath);

  { 1. Essayer dans le repertoire courant }
  Candidate := RelPath + '.ql';
  If FileExists2(Candidate) Then
  Begin
    ResolveImportPath := Candidate;
    Exit;
  End;

  { 2. Essayer dans le repertoire courant comme dossier }
  Candidate := RelPath + '/index.ql';
  If FileExists2(Candidate) Then
  Begin
    ResolveImportPath := Candidate;
    Exit;
  End;

  { 3. Essayer dans le SearchPath }
  If Opts.SearchPath <> '' Then
  Begin
    Candidate := Opts.SearchPath + '/' + RelPath + '.ql';
    If FileExists2(Candidate) Then
    Begin
      ResolveImportPath := Candidate;
      Exit;
    End;

    Candidate := Opts.SearchPath + '/' + RelPath + '/index.ql';
    If FileExists2(Candidate) Then
    Begin
      ResolveImportPath := Candidate;
      Exit;
    End;
  End;

  { 4. Non trouve }
  ResolveImportPath := '';
End;

{ ---- ResolveImports : resoudre tous les imports pending ---- }

Procedure ResolveImports;
Var
  I      : Integer;
  Resolved: TString;
  ModIdx : Integer;
Begin
  For I := 0 To QLImportCount - 1 Do
  Begin
    If QLImports[I].Status <> IMS_PENDING Then
      Continue;

    { Verifier si le chemin correspond a un module deja charge }
    ModIdx := FindModuleByName(QLImports[I].Path);
    If ModIdx >= 0 Then
    Begin
      QLImports[I].ModuleIdx    := ModIdx;
      QLImports[I].ResolvedPath := QLModules[ModIdx].FilePath;
      QLImports[I].Status       := IMS_RESOLVED;
      Continue;
    End;

    { Verifier par le nom court }
    ModIdx := FindModuleByShort(QLImports[I].Path);
    If ModIdx >= 0 Then
    Begin
      QLImports[I].ModuleIdx    := ModIdx;
      QLImports[I].ResolvedPath := QLModules[ModIdx].FilePath;
      QLImports[I].Status       := IMS_RESOLVED;
      Continue;
    End;

    { Resoudre sur le disque }
    Resolved := ResolveImportPath(QLImports[I].Path);
    If Resolved <> '' Then
    Begin
      QLImports[I].ResolvedPath := Resolved;
      { Enregistrer comme module }
      ModIdx := RegisterModule(QLImports[I].Path, Resolved, -1);
      QLImports[I].ModuleIdx := ModIdx;
      QLImports[I].Status    := IMS_RESOLVED;
    End
    Else
    Begin
      { Les imports de la bibliotheque standard (pascal, semmle.*) sont
        consideres comme resolus meme sans fichier physique car ils
        designent des modules integres.                                }
      If (QLImports[I].Path = 'pascal') Or
         (Copy(QLImports[I].Path, 1, 6) = 'semmle') Then
      Begin
        ModIdx := RegisterModule(QLImports[I].Path, '', -1);
        If ModIdx >= 0 Then
          QLModules[ModIdx].Loaded := True;
        QLImports[I].ModuleIdx := ModIdx;
        QLImports[I].Status    := IMS_RESOLVED;
      End
      Else
      Begin
        QLImports[I].Status := IMS_NOT_FOUND;
        WarnMsg('Import not found: ' + QLImports[I].Path);
      End;
    End;
  End;
End;

{ ---- LoadQLLibrary : charger un fichier .ql de bibliotheque  }
{   Cette version simple lit le fichier et le marque comme     }
{   charge sans parser son contenu (la resolution des symboles }
{   exportes est une extension future).                        }

Procedure LoadQLLibrary(ModIdx : Integer);
Var
  F     : Text;
  L     : TString;
  Lines : Integer;
Begin
  If ModIdx < 0 Then Exit;
  If ModIdx >= QLModuleCount Then Exit;
  If QLModules[ModIdx].Loaded Then Exit;
  If QLModules[ModIdx].FilePath = '' Then
  Begin
    QLModules[ModIdx].Loaded := True;
    Exit;
  End;

  Assign(F, QLModules[ModIdx].FilePath);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Cannot open library: ' + QLModules[ModIdx].FilePath);
    Exit;
  End;

  Lines := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, L);
    Inc(Lines);
  End;
  Close(F);

  QLModules[ModIdx].Loaded := True;
  If Opts.Verbose Then
    WriteLn('  Loaded module ', QLModules[ModIdx].Name,
            ' (', Lines, ' lines) from ', QLModules[ModIdx].FilePath);
End;

{ ---- LoadAllLibraries : charger toutes les bibliotheques --- }

Procedure LoadAllLibraries;
Var I : Integer;
Begin
  For I := 0 To QLModuleCount - 1 Do
    LoadQLLibrary(I);
End;

{ ---- ImportStatusName : nom textuel d un TQLImportStatus --- }

Function ImportStatusName(S : TQLImportStatus) : TString;
Begin
  Case S Of
    IMS_PENDING   : ImportStatusName := 'PENDING';
    IMS_RESOLVED  : ImportStatusName := 'RESOLVED';
    IMS_NOT_FOUND : ImportStatusName := 'NOT_FOUND';
    IMS_ERROR     : ImportStatusName := 'ERROR';
  Else
    ImportStatusName := '?';
  End;
End;

{ ---- CountResolvedImports : compter les imports resolus ---- }

Function CountResolvedImports : Integer;
Var I, C : Integer;
Begin
  C := 0;
  For I := 0 To QLImportCount - 1 Do
    If QLImports[I].Status = IMS_RESOLVED Then
      Inc(C);
  CountResolvedImports := C;
End;

{ ---- BuildModuleTree : construire les sous-modules a partir }
{   des chemins d import avec des points.                     }

Procedure BuildModuleTree;
Var
  I        : Integer;
  Path     : TString;
  Seg      : TString;
  Prefix   : TString;
  ParIdx   : Integer;
  DotPos   : Integer;
  J        : Integer;
Begin
  For I := 0 To QLModuleCount - 1 Do
  Begin
    Path   := QLModules[I].Name;
    ParIdx := -1;
    Prefix := '';

    { Decomposer le chemin en segments et creer les modules intermediaires }
    While Length(Path) > 0 Do
    Begin
      DotPos := 0;
      For J := 1 To Length(Path) Do
        If Path[J] = '.' Then
        Begin
          DotPos := J;
          Break;
        End;

      If DotPos > 0 Then
      Begin
        Seg := Copy(Path, 1, DotPos - 1);
        Path := Copy(Path, DotPos + 1, Length(Path) - DotPos);
      End
      Else
      Begin
        Seg := Path;
        Path := '';
      End;

      If Prefix = '' Then
        Prefix := Seg
      Else
        Prefix := Prefix + '.' + Seg;

      { Ne pas re-creer le module complet si c est le dernier segment }
      If Length(Path) > 0 Then
      Begin
        { Creer le module intermediaire s il n existe pas }
        If FindModuleByName(Prefix) < 0 Then
          RegisterModule(Prefix, '', ParIdx);
        ParIdx := FindModuleByName(Prefix);
      End
      Else
      Begin
        { Mettre a jour le parent du module existant }
        If (ParIdx >= 0) And (QLModules[I].ParentIdx < 0) Then
          QLModules[I].ParentIdx := ParIdx;
      End;
    End;
  End;
End;

{ ---- RunImportResolution : pipeline complet de resolution -- }
{   1. Initialiser le registre                                 }
{   2. Collecter les imports de l AST                          }
{   3. Construire l arbre de modules                           }
{   4. Resoudre les chemins d import                           }
{   5. Charger les bibliotheques trouvees                      }

Procedure RunImportResolution;
Begin
  InitModules;
  CollectImportsFromAST(RootNode);
  ResolveImports;
  BuildModuleTree;
  LoadAllLibraries;
End;

{ ---- DumpModules : afficher le registre de modules --------- }

Procedure DumpModules;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('=== MODULES QL (', QLModuleCount, ') ===');
  For I := 0 To QLModuleCount - 1 Do
  Begin
    WriteLn('  [', I, '] ', QLModules[I].Name);
    WriteLn('       short=', QLModules[I].ShortName,
            '  parent=', QLModules[I].ParentIdx,
            '  loaded=', QLModules[I].Loaded);
    If QLModules[I].FilePath <> '' Then
      WriteLn('       file=', QLModules[I].FilePath);
  End;

  WriteLn;
  WriteLn('=== IMPORTS QL (', QLImportCount, ') ===');
  For I := 0 To QLImportCount - 1 Do
  Begin
    Write('  [', I, '] import ', QLImports[I].Path);
    If QLImports[I].Alias <> '' Then
      Write(' as ', QLImports[I].Alias);
    WriteLn('  => ', ImportStatusName(QLImports[I].Status),
            '  module=', QLImports[I].ModuleIdx);
    If QLImports[I].ResolvedPath <> '' Then
      WriteLn('       resolved=', QLImports[I].ResolvedPath);
  End;

  WriteLn;
  WriteLn('Resolved: ', CountResolvedImports, '/', QLImportCount);
End;

{ ============================================================
  TODO 21 - BIBLIOTHEQUE STANDARD DE PREDICATS QL [IMPLEMENTE]
  ============================================================ }

{ ---- InitStdLib : initialiser la bibliotheque standard ------ }

Procedure InitStdLib;
Var I : Integer;
Begin
  StdPredCount := 0;
  StdLibBuilt  := False;
  For I := 0 To MAX_STDLIB_PREDS - 1 Do
  Begin
    StdPreds[I].Name     := '';
    StdPreds[I].Kind     := SPK_NONE;
    StdPreds[I].ClassIdx := -1;
    StdPreds[I].QLPredIdx:= -1;
  End;
End;

{ ---- Nom textuel d un type de predicat stdlib --------------- }

Function StdPredKindName(K : TStdPredKind) : TString;
Begin
  Case K Of
    SPK_NONE              : StdPredKindName := 'none';
    SPK_HAS_NAME          : StdPredKindName := 'hasName';
    SPK_GET_TYPE           : StdPredKindName := 'getType';
    SPK_GET_A_CHILD        : StdPredKindName := 'getAChild';
    SPK_GET_LOCATION       : StdPredKindName := 'getLocation';
    SPK_GET_ENCLOSING_FUNC : StdPredKindName := 'getEnclosingFunction';
    SPK_GET_AN_ARGUMENT    : StdPredKindName := 'getAnArgument';
    SPK_GET_TARGET         : StdPredKindName := 'getTarget';
    SPK_FLOWS_TO           : StdPredKindName := 'flowsTo';
  End;
End;

{ ---- Enregistrer un predicat standard ----------------------- }

Function AddStdPred(Const AName : TString; AKind : TStdPredKind;
                    ACIdx, AQLPIdx : Integer) : Integer;
Begin
  If StdPredCount >= MAX_STDLIB_PREDS Then
  Begin
    WarnMsg('StdLib: depassement MAX_STDLIB_PREDS');
    AddStdPred := -1;
    Exit;
  End;
  StdPreds[StdPredCount].Name      := AName;
  StdPreds[StdPredCount].Kind      := AKind;
  StdPreds[StdPredCount].ClassIdx  := ACIdx;
  StdPreds[StdPredCount].QLPredIdx := AQLPIdx;
  AddStdPred := StdPredCount;
  Inc(StdPredCount);
End;

{ ---- FindStdPred : trouver un predicat standard par nom et classe }

Function FindStdPred(AClassIdx : Integer;
                     Const AName : TString) : Integer;
Var
  I   : Integer;
  LN  : TString;
Begin
  LN := StrLowerCase(AName);
  FindStdPred := -1;
  For I := 0 To StdPredCount - 1 Do
  Begin
    If (StdPreds[I].ClassIdx = AClassIdx) And
       (StrLowerCase(StdPreds[I].Name) = LN) Then
    Begin
      FindStdPred := I;
      Exit;
    End;
  End;
End;

{ ---- FindStdPredByQLIdx : trouver par index QLPred ---------- }

Function FindStdPredByQLIdx(AQLPIdx : Integer) : Integer;
Var I : Integer;
Begin
  FindStdPredByQLIdx := -1;
  For I := 0 To StdPredCount - 1 Do
    If StdPreds[I].QLPredIdx = AQLPIdx Then
    Begin
      FindStdPredByQLIdx := I;
      Exit;
    End;
End;

{ ---- EvalStdPredHasName : predicat hasName(name) ------------ }
{ Retourne True si l element de la base de donnees a le nom donne }

Function EvalStdPredHasName(Const TableName : TString;
                            RowIdx : Integer;
                            Const ArgName : TString) : Boolean;
Var
  BV : TBindingValue;
Begin
  EvalStdPredHasName := False;
  BV := GetDbField(TableName, RowIdx, 'name');
  If BV.Kind = BK_STRING Then
    EvalStdPredHasName := (StrLowerCase(BV.StrVal) =
                           StrLowerCase(ArgName));
End;

{ ---- EvalStdPredGetType : predicat getType() ---------------- }
{ Retourne une reference vers le type de l element }

Function EvalStdPredGetType(Const TableName : TString;
                            RowIdx : Integer) : TBindingValue;
Var
  BV : TBindingValue;
  TId : LongInt;
Begin
  EvalStdPredGetType := MakeNoneBinding;
  BV := GetDbField(TableName, RowIdx, 'typeid');
  If BV.Kind = BK_INT Then
  Begin
    TId := BV.IntVal;
    If (TId >= 0) And (TId < DbTypeCnt) Then
      EvalStdPredGetType := MakeDbRefBinding('types', TId);
  End;
  { Pour les fonctions, on utilise returntypeid }
  If (BV.Kind = BK_NONE) And
     (StrLowerCase(TableName) = 'functions') Then
  Begin
    BV := GetDbField(TableName, RowIdx, 'returntypeid');
    If BV.Kind = BK_INT Then
    Begin
      TId := BV.IntVal;
      If (TId >= 0) And (TId < DbTypeCnt) Then
        EvalStdPredGetType := MakeDbRefBinding('types', TId);
    End;
  End;
End;

{ ---- EvalStdPredGetAChild : predicat getAChild() ------------ }
{ Retourne le premier enfant (premier element avec parentid = id) }

Function EvalStdPredGetAChild(Const TableName : TString;
                              RowIdx : Integer) : TBindingValue;
Var
  NT   : TString;
  MyId : LongInt;
  BV   : TBindingValue;
  I    : Integer;
Begin
  EvalStdPredGetAChild := MakeNoneBinding;
  NT := StrLowerCase(TableName);
  BV := GetDbField(TableName, RowIdx, 'id');
  If BV.Kind <> BK_INT Then Exit;
  MyId := BV.IntVal;

  { Chercher un enfant dans exprs }
  For I := 0 To DbExprCnt - 1 Do
    If DbExprs[I].ParentId = MyId Then
    Begin
      EvalStdPredGetAChild := MakeDbRefBinding('exprs', I);
      Exit;
    End;
  { Chercher un enfant dans stmts }
  For I := 0 To DbStmtCnt - 1 Do
    If DbStmts[I].ParentId = MyId Then
    Begin
      EvalStdPredGetAChild := MakeDbRefBinding('stmts', I);
      Exit;
    End;
  { Chercher un enfant dans variables }
  For I := 0 To DbVariableCnt - 1 Do
    If DbVariables[I].ParentId = MyId Then
    Begin
      EvalStdPredGetAChild := MakeDbRefBinding('variables', I);
      Exit;
    End;
  { Chercher un enfant dans functions }
  For I := 0 To DbFunctionCnt - 1 Do
    If DbFunctions[I].ParentId = MyId Then
    Begin
      EvalStdPredGetAChild := MakeDbRefBinding('functions', I);
      Exit;
    End;
End;

{ ---- EvalStdPredGetLocation : predicat getLocation() -------- }
{ Retourne la location associee a l element }

Function EvalStdPredGetLocation(Const TableName : TString;
                                RowIdx : Integer) : TBindingValue;
Var
  BV   : TBindingValue;
  LId  : LongInt;
Begin
  EvalStdPredGetLocation := MakeNoneBinding;
  BV := GetDbField(TableName, RowIdx, 'locid');
  If BV.Kind = BK_INT Then
  Begin
    LId := BV.IntVal;
    If (LId >= 0) And (LId < DbLocationCnt) Then
      EvalStdPredGetLocation := MakeDbRefBinding('locations', LId);
  End;
End;

{ ---- EvalStdPredGetEnclosingFunction : predicat getEnclosingFunction() }
{ Retourne la fonction englobante via parentid }

Function EvalStdPredGetEnclosingFunc(Const TableName : TString;
                                     RowIdx : Integer) : TBindingValue;
Var
  BV   : TBindingValue;
  PId  : LongInt;
  NT   : TString;
  I    : Integer;
Begin
  EvalStdPredGetEnclosingFunc := MakeNoneBinding;
  NT := StrLowerCase(TableName);

  { Si c est deja une fonction, retourner elle-meme }
  If NT = 'functions' Then
  Begin
    EvalStdPredGetEnclosingFunc := MakeDbRefBinding('functions', RowIdx);
    Exit;
  End;

  { Sinon, chercher via parentid }
  BV := GetDbField(TableName, RowIdx, 'parentid');
  If BV.Kind <> BK_INT Then Exit;
  PId := BV.IntVal;

  { Chercher dans les fonctions celle avec cet Id }
  For I := 0 To DbFunctionCnt - 1 Do
    If DbFunctions[I].Id = PId Then
    Begin
      EvalStdPredGetEnclosingFunc := MakeDbRefBinding('functions', I);
      Exit;
    End;

  { Si le parentid pointe vers un stmt, remonter encore }
  For I := 0 To DbStmtCnt - 1 Do
    If DbStmts[I].Id = PId Then
    Begin
      EvalStdPredGetEnclosingFunc :=
        EvalStdPredGetEnclosingFunc('stmts', I);
      Exit;
    End;
End;

{ ---- EvalStdPredGetAnArgument : predicat getAnArgument() ---- }
{ Pour un appel (Call), retourne le premier argument (expr enfant) }

Function EvalStdPredGetAnArgument(Const TableName : TString;
                                  RowIdx : Integer) : TBindingValue;
Var
  NT   : TString;
  BV   : TBindingValue;
  MyId : LongInt;
  I    : Integer;
Begin
  EvalStdPredGetAnArgument := MakeNoneBinding;
  NT := StrLowerCase(TableName);
  If (NT <> 'calls') And (NT <> 'exprs') Then Exit;

  BV := GetDbField(TableName, RowIdx, 'id');
  If BV.Kind <> BK_INT Then Exit;
  MyId := BV.IntVal;

  { Pour un Call, chercher les expressions enfants }
  For I := 0 To DbExprCnt - 1 Do
    If DbExprs[I].ParentId = MyId Then
    Begin
      EvalStdPredGetAnArgument := MakeDbRefBinding('exprs', I);
      Exit;
    End;
End;

{ ---- EvalStdPredGetTarget : predicat getTarget() ------------ }
{ Pour un acces, retourne la variable cible;
  pour un appel, retourne la fonction cible }

Function EvalStdPredGetTarget(Const TableName : TString;
                              RowIdx : Integer) : TBindingValue;
Var
  NT   : TString;
  BV   : TBindingValue;
  TId  : LongInt;
  I    : Integer;
Begin
  EvalStdPredGetTarget := MakeNoneBinding;
  NT := StrLowerCase(TableName);

  If NT = 'accesses' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbAccessCnt) Then Exit;
    TId := DbAccesses[RowIdx].TargetId;
    For I := 0 To DbVariableCnt - 1 Do
      If DbVariables[I].Id = TId Then
      Begin
        EvalStdPredGetTarget := MakeDbRefBinding('variables', I);
        Exit;
      End;
  End
  Else If NT = 'calls' Then
  Begin
    If (RowIdx < 0) Or (RowIdx >= DbCallCnt) Then Exit;
    TId := DbCalls[RowIdx].TargetId;
    For I := 0 To DbFunctionCnt - 1 Do
      If DbFunctions[I].Id = TId Then
      Begin
        EvalStdPredGetTarget := MakeDbRefBinding('functions', I);
        Exit;
      End;
  End;
End;

{ ---- EvalStdPredFlowsTo : predicat flowsTo(target) ---------- }
{ Verifie si un element tainted atteint la cible via le taint tracking }

Function EvalStdPredFlowsTo(Const SrcTable : TString;
                            SrcRow : Integer;
                            Const DstTable : TString;
                            DstRow : Integer) : Boolean;
Var
  SrcBV, DstBV : TBindingValue;
  SrcId, DstId : LongInt;
  I            : Integer;
Begin
  EvalStdPredFlowsTo := False;
  SrcBV := GetDbField(SrcTable, SrcRow, 'id');
  DstBV := GetDbField(DstTable, DstRow, 'id');
  If (SrcBV.Kind <> BK_INT) Or (DstBV.Kind <> BK_INT) Then Exit;
  SrcId := SrcBV.IntVal;
  DstId := DstBV.IntVal;

  { Verifier dans les alertes de teinte si une source atteint un puits }
  For I := 0 To TaintAlertCount - 1 Do
  Begin
    If (TaintAlerts[I].SrcIdx >= 0) And
       (TaintAlerts[I].SrcIdx < TaintSrcCount) And
       (TaintAlerts[I].SinkIdx >= 0) And
       (TaintAlerts[I].SinkIdx < TaintSinkCount) Then
    Begin
      If (TaintSources[TaintAlerts[I].SrcIdx].ASTIndex = SrcId) And
         (TaintSinks[TaintAlerts[I].SinkIdx].ASTIndex = DstId) Then
      Begin
        EvalStdPredFlowsTo := True;
        Exit;
      End;
    End;
  End;

  { Cas simple : meme identifiant = trivially flows to itself }
  If (StrLowerCase(SrcTable) = StrLowerCase(DstTable)) And
     (SrcId = DstId) Then
    EvalStdPredFlowsTo := True;
End;

{ ---- EvalStdPred : evaluer un predicat standard --------------- }
{ Retourne le resultat d un predicat standard en fonction de son type }

Function EvalStdPred(StdIdx : Integer;
                     Const TableName : TString;
                     RowIdx : Integer) : TBindingValue;
Begin
  EvalStdPred := MakeNoneBinding;
  If (StdIdx < 0) Or (StdIdx >= StdPredCount) Then Exit;

  Case StdPreds[StdIdx].Kind Of
    SPK_GET_TYPE:
      EvalStdPred := EvalStdPredGetType(TableName, RowIdx);
    SPK_GET_A_CHILD:
      EvalStdPred := EvalStdPredGetAChild(TableName, RowIdx);
    SPK_GET_LOCATION:
      EvalStdPred := EvalStdPredGetLocation(TableName, RowIdx);
    SPK_GET_ENCLOSING_FUNC:
      EvalStdPred := EvalStdPredGetEnclosingFunc(TableName, RowIdx);
    SPK_GET_AN_ARGUMENT:
      EvalStdPred := EvalStdPredGetAnArgument(TableName, RowIdx);
    SPK_GET_TARGET:
      EvalStdPred := EvalStdPredGetTarget(TableName, RowIdx);
  Else
    EvalStdPred := MakeNoneBinding;
  End;
End;

{ ---- RegisterStdClassPreds : enregistrer les predicats d une classe stdlib }

Procedure RegisterStdClassPreds(CIdx : Integer;
                                Const CName : TString);
Var
  PIdx : Integer;
  NT   : TString;
Begin
  NT := StrLowerCase(CName);

  { hasName : disponible pour toutes les classes sauf Element }
  If (NT <> 'element') Then
  Begin
    PIdx := RegisterQLPred('hasName', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('hasName', SPK_HAS_NAME, CIdx, PIdx);
  End;

  { getLocation : disponible pour Locatable et toutes ses sous-classes }
  If (NT = 'locatable') Or (NT = 'expr') Or (NT = 'stmt') Or
     (NT = 'function') Or (NT = 'variable') Or (NT = 'type') Or
     (NT = 'call') Or (NT = 'access') Or (NT = 'comment') Then
  Begin
    PIdx := RegisterQLPred('getLocation', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getLocation', SPK_GET_LOCATION, CIdx, PIdx);
  End;

  { getType : pour Expr, Variable, Function }
  If (NT = 'expr') Or (NT = 'variable') Or (NT = 'function') Or
     (NT = 'call') Or (NT = 'access') Then
  Begin
    PIdx := RegisterQLPred('getType', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getType', SPK_GET_TYPE, CIdx, PIdx);
  End;

  { getAChild : pour Element et toutes les classes }
  Begin
    PIdx := RegisterQLPred('getAChild', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getAChild', SPK_GET_A_CHILD, CIdx, PIdx);
  End;

  { getEnclosingFunction : pour Expr, Stmt, Variable }
  If (NT = 'expr') Or (NT = 'stmt') Or (NT = 'variable') Or
     (NT = 'call') Or (NT = 'access') Then
  Begin
    PIdx := RegisterQLPred('getEnclosingFunction', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getEnclosingFunction', SPK_GET_ENCLOSING_FUNC, CIdx, PIdx);
  End;

  { getAnArgument : pour Call }
  If (NT = 'call') Then
  Begin
    PIdx := RegisterQLPred('getAnArgument', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getAnArgument', SPK_GET_AN_ARGUMENT, CIdx, PIdx);
  End;

  { getTarget : pour Call et Access }
  If (NT = 'call') Or (NT = 'access') Then
  Begin
    PIdx := RegisterQLPred('getTarget', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('getTarget', SPK_GET_TARGET, CIdx, PIdx);
  End;

  { flowsTo : pour Expr }
  If (NT = 'expr') Or (NT = 'variable') Then
  Begin
    PIdx := RegisterQLPred('flowsTo', CIdx, -1, QPF_NONE);
    If PIdx >= 0 Then
      AddStdPred('flowsTo', SPK_FLOWS_TO, CIdx, PIdx);
  End;
End;

{ ---- BuildStdLibrary : construire la bibliotheque standard --- }

Procedure BuildStdLibrary;
Var
  CIdx : Integer;
  BaseLocatable : Integer;
  BaseElement   : Integer;
Begin
  InitStdLib;

  { 1. Enregistrer la classe racine : Element }
  BaseElement := RegisterQLClass('Element', -1, -1, True);
  If BaseElement >= 0 Then
    RegisterStdClassPreds(BaseElement, 'Element');

  { 2. Enregistrer Locatable extends Element }
  BaseLocatable := RegisterQLClass('Locatable', -1, -1, True);
  If BaseLocatable >= 0 Then
  Begin
    QLClasses[BaseLocatable].BaseIdx := BaseElement;
    RegisterStdClassPreds(BaseLocatable, 'Locatable');
  End;

  { 3. Enregistrer Expr extends Locatable }
  CIdx := RegisterQLClass('Expr', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Expr');
  End;

  { 4. Enregistrer Stmt extends Locatable }
  CIdx := RegisterQLClass('Stmt', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Stmt');
  End;

  { 5. Enregistrer Function extends Locatable }
  CIdx := RegisterQLClass('Function', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Function');
  End;

  { 6. Enregistrer Variable extends Locatable }
  CIdx := RegisterQLClass('Variable', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Variable');
  End;

  { 7. Enregistrer Type extends Locatable }
  CIdx := RegisterQLClass('Type', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Type');
  End;

  { 8. Enregistrer Call extends Expr }
  CIdx := RegisterQLClass('Call', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    CIdx := FindQLClass('Call');
    If CIdx >= 0 Then
      QLClasses[CIdx].BaseIdx := FindQLClass('Expr');
    RegisterStdClassPreds(CIdx, 'Call');
  End;

  { 9. Enregistrer Access extends Expr }
  CIdx := RegisterQLClass('Access', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    CIdx := FindQLClass('Access');
    If CIdx >= 0 Then
      QLClasses[CIdx].BaseIdx := FindQLClass('Expr');
    RegisterStdClassPreds(CIdx, 'Access');
  End;

  { 10. Enregistrer Comment extends Locatable }
  CIdx := RegisterQLClass('Comment', -1, -1, False);
  If CIdx >= 0 Then
  Begin
    QLClasses[CIdx].BaseIdx := BaseLocatable;
    RegisterStdClassPreds(CIdx, 'Comment');
  End;

  StdLibBuilt := True;
End;

{ ---- CountStdLibPreds : nombre de predicats standard --------- }

Function CountStdLibPreds : Integer;
Begin
  CountStdLibPreds := StdPredCount;
End;

{ ---- CountStdLibClasses : nombre de classes standard ---------- }

Function CountStdLibClasses : Integer;
Var
  I, Cnt : Integer;
Begin
  Cnt := 0;
  For I := 0 To QLClassCount - 1 Do
    If QLClasses[I].NodeIdx = -1 Then
      Inc(Cnt);
  CountStdLibClasses := Cnt;
End;

{ ---- DumpStdLibrary : afficher la bibliotheque standard ------- }

Procedure DumpStdLibrary;
Var
  I : Integer;
Begin
  WriteLn;
  WriteLn('=== BIBLIOTHEQUE STANDARD QL ===');
  WriteLn('Classes stdlib : ', CountStdLibClasses);
  WriteLn('Predicats stdlib: ', StdPredCount);
  WriteLn;

  For I := 0 To StdPredCount - 1 Do
  Begin
    Write('  [', I, '] ');
    If StdPreds[I].ClassIdx >= 0 Then
      Write(QLClasses[StdPreds[I].ClassIdx].Name, '.');
    WriteLn(StdPreds[I].Name,
            '  (', StdPredKindName(StdPreds[I].Kind), ')',
            '  qlpred=', StdPreds[I].QLPredIdx);
  End;
  WriteLn;
End;

{ ---- Stubs des sous-commandes (TODO 23-24) ----------------- }

{ ============================================================
  TODO 22 - COMMANDE "codeql database create" [IMPLEMENTE]
  ============================================================ }

{ ============================================================
  TODO 26 - LEXEUR ET PARSEUR C [IMPLEMENTE]
  ============================================================ }

{ ---- IsCKeyword : reconnaissance des 32 mots-cles C -------- }

Function IsCKeyword(Const W : TString) : Boolean;
Begin
  IsCKeyword :=
    (W = 'auto')     Or (W = 'break')    Or (W = 'case')     Or
    (W = 'char')     Or (W = 'const')    Or (W = 'continue') Or
    (W = 'default')  Or (W = 'do')       Or (W = 'double')   Or
    (W = 'else')     Or (W = 'enum')     Or (W = 'extern')   Or
    (W = 'float')    Or (W = 'for')      Or (W = 'goto')     Or
    (W = 'if')       Or (W = 'int')      Or (W = 'long')     Or
    (W = 'register') Or (W = 'return')   Or (W = 'short')    Or
    (W = 'signed')   Or (W = 'sizeof')   Or (W = 'static')   Or
    (W = 'struct')   Or (W = 'switch')   Or (W = 'typedef')  Or
    (W = 'union')    Or (W = 'unsigned') Or (W = 'void')     Or
    (W = 'volatile') Or (W = 'while');
End;

{ ---- CLexScanIdent : scanner un identificateur ou mot-cle C -- }

Procedure CLexScanIdent;
Var S : TString;
Begin
  S := '';
  While (SrcColNo <= Length(SrcLine)) And
        IsIdentCont(SrcLine[SrcColNo]) Do
  Begin
    If Length(S) < 255 Then
      S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  If IsCKeyword(S) Then
    SrcToken.Kind := STK_KEYWORD
  Else
    SrcToken.Kind := STK_IDENT;
  SrcToken.Val := S;
End;

{ ---- CLexScanNumber : scanner un nombre C -------------------- }

Procedure CLexScanNumber;
Var S : TString;
    HasDot, HasExp : Boolean;
    V : Integer;
    Code : Integer;
Begin
  S := '';
  HasDot := False;
  HasExp := False;
  { Hexadecimal 0x... }
  If (SrcLine[SrcColNo] = '0') And (SrcColNo < Length(SrcLine)) And
     ((SrcLine[SrcColNo + 1] = 'x') Or (SrcLine[SrcColNo + 1] = 'X')) Then
  Begin
    S := '0x';
    Inc(SrcColNo, 2);
    While (SrcColNo <= Length(SrcLine)) And
          (((SrcLine[SrcColNo] >= '0') And (SrcLine[SrcColNo] <= '9')) Or
           ((SrcLine[SrcColNo] >= 'a') And (SrcLine[SrcColNo] <= 'f')) Or
           ((SrcLine[SrcColNo] >= 'A') And (SrcLine[SrcColNo] <= 'F'))) Do
    Begin
      S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
    SrcToken.Kind := STK_INTEGER;
    SrcToken.Val  := S;
    Val(S, SrcToken.IntVal, Code);
    Exit;
  End;
  { Decimal ou flottant }
  While (SrcColNo <= Length(SrcLine)) And
        IsDigit(SrcLine[SrcColNo]) Do
  Begin
    S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  If (SrcColNo <= Length(SrcLine)) And (SrcLine[SrcColNo] = '.') And
     (SrcColNo < Length(SrcLine)) And (SrcLine[SrcColNo + 1] <> '.') Then
  Begin
    HasDot := True;
    S := S + '.';
    Inc(SrcColNo);
    While (SrcColNo <= Length(SrcLine)) And
          IsDigit(SrcLine[SrcColNo]) Do
    Begin
      S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  If (SrcColNo <= Length(SrcLine)) And
     ((SrcLine[SrcColNo] = 'e') Or (SrcLine[SrcColNo] = 'E')) Then
  Begin
    HasExp := True;
    S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
    If (SrcColNo <= Length(SrcLine)) And
       ((SrcLine[SrcColNo] = '+') Or (SrcLine[SrcColNo] = '-')) Then
    Begin
      S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
    While (SrcColNo <= Length(SrcLine)) And
          IsDigit(SrcLine[SrcColNo]) Do
    Begin
      S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  { Suffixes : u, l, f, etc. }
  While (SrcColNo <= Length(SrcLine)) And
        ((SrcLine[SrcColNo] = 'u') Or (SrcLine[SrcColNo] = 'U') Or
         (SrcLine[SrcColNo] = 'l') Or (SrcLine[SrcColNo] = 'L') Or
         (SrcLine[SrcColNo] = 'f') Or (SrcLine[SrcColNo] = 'F')) Do
    Inc(SrcColNo);
  SrcToken.Val := S;
  If HasDot Or HasExp Then
  Begin
    SrcToken.Kind := STK_FLOAT;
    Val(S, SrcToken.FloatVal, V);
  End
  Else
  Begin
    SrcToken.Kind := STK_INTEGER;
    Val(S, SrcToken.IntVal, V);
  End;
End;

{ ---- CLexScanString : scanner une chaine C "..." ------------- }

Procedure CLexScanString;
Var S : TString;
Begin
  S := '';
  Inc(SrcColNo); { sauter le guillemet ouvrant }
  While (SrcColNo <= Length(SrcLine)) And
        (SrcLine[SrcColNo] <> '"') Do
  Begin
    If SrcLine[SrcColNo] = '\' Then
    Begin
      Inc(SrcColNo);
      If SrcColNo <= Length(SrcLine) Then
      Begin
        If Length(S) < 255 Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
    End
    Else
    Begin
      If Length(S) < 255 Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  If (SrcColNo <= Length(SrcLine)) And (SrcLine[SrcColNo] = '"') Then
    Inc(SrcColNo);
  SrcToken.Kind := STK_STRING;
  SrcToken.Val  := S;
End;

{ ---- CLexScanChar : scanner un caractere C '.' --------------- }

Procedure CLexScanChar;
Var S : TString;
Begin
  S := '';
  Inc(SrcColNo); { sauter l apostrophe ouvrante }
  While (SrcColNo <= Length(SrcLine)) And
        (SrcLine[SrcColNo] <> '''') Do
  Begin
    If SrcLine[SrcColNo] = '\' Then
    Begin
      Inc(SrcColNo);
      If SrcColNo <= Length(SrcLine) Then
      Begin
        If Length(S) < 255 Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
    End
    Else
    Begin
      If Length(S) < 255 Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
  End;
  If (SrcColNo <= Length(SrcLine)) And (SrcLine[SrcColNo] = '''') Then
    Inc(SrcColNo);
  SrcToken.Kind := STK_STRING;
  SrcToken.Val  := S;
  If Length(S) = 1 Then
    SrcToken.IntVal := Ord(S[1]);
End;

{ ---- CLexSkipLineComment : sauter un commentaire // ---------- }

Procedure CLexSkipLineComment;
Var S : TString;
Begin
  S := '';
  Inc(SrcColNo, 2); { sauter // }
  While SrcColNo <= Length(SrcLine) Do
  Begin
    If Length(S) < 255 Then
      S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  SrcToken.Kind := STK_COMMENT;
  SrcToken.Val  := S;
End;

{ ---- CLexSkipBlockComment : sauter un commentaire /* ... */ -- }

Procedure CLexSkipBlockComment;
Var S : TString;
    Done : Boolean;
Begin
  S := '';
  Inc(SrcColNo, 2); { sauter /* }
  Done := False;
  While Not Done Do
  Begin
    If SrcEOF Then
    Begin
      Done := True;
      Break;
    End;
    While SrcColNo <= Length(SrcLine) Do
    Begin
      If (SrcLine[SrcColNo] = '*') And (SrcColNo < Length(SrcLine)) And
         (SrcLine[SrcColNo + 1] = '/') Then
      Begin
        Inc(SrcColNo, 2);
        Done := True;
        Break;
      End;
      If Length(S) < 255 Then
        S := S + SrcLine[SrcColNo];
      Inc(SrcColNo);
    End;
    If Not Done Then
    Begin
      If Length(S) < 255 Then
        S := S + ' ';
      SrcLexNextLine;
    End;
  End;
  SrcToken.Kind := STK_COMMENT;
  SrcToken.Val  := S;
End;

{ ---- CLexInit : initialiser le lexeur C ---------------------- }

Procedure CLexInit;
Begin
  SrcLineNo    := 0;
  SrcColNo     := 1;
  SrcEOF       := False;
  SrcLine      := '';
  SrcTokenCount := 0;
  SrcTotalLines := 0;
  SrcToken.Kind     := STK_EOF;
  SrcToken.Val      := '';
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;
  SrcToken.Line     := 0;
  SrcToken.Col      := 0;
  SrcLexNextLine;
End;

{ ---- CLexNextToken : prochain token C ------------------------ }

Procedure CLexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
  S        : TString;
Begin
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    While (Not SrcEOF) And (SrcColNo > Length(SrcLine)) Do
      SrcLexNextLine;

    If SrcEOF Then
    Begin
      SrcToken.Kind := STK_EOF;
      SrcToken.Val  := '';
      SrcToken.Line := SrcLineNo;
      SrcToken.Col  := SrcColNo;
      Scanning := False;
      Break;
    End;

    SrcToken.Line := SrcLineNo;
    SrcToken.Col  := SrcColNo;
    Ch := SrcLine[SrcColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(SrcColNo);
      Continue;
    End;

    Scanning := False;

    { Preprocesseur : lignes commencant par # }
    If Ch = '#' Then
    Begin
      S := '';
      While SrcColNo <= Length(SrcLine) Do
      Begin
        If Length(S) < 255 Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
      SrcToken.Kind := STK_DIRECTIVE;
      SrcToken.Val  := S;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire de ligne // }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '/') Then
    Begin
      CLexSkipLineComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire bloc /* ... */ }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '*') Then
    Begin
      CLexSkipBlockComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines entre guillemets }
    If Ch = '"' Then
    Begin
      CLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caracteres entre apostrophes }
    If Ch = '''' Then
    Begin
      CLexScanChar;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Identificateurs et mots-cles }
    If IsIdentStart(Ch) Then
    Begin
      CLexScanIdent;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Nombres }
    If IsDigit(Ch) Then
    Begin
      CLexScanNumber;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Operateurs multi-caracteres (3 car) }
    If (SrcColNo + 1 < Length(SrcLine)) Then
    Begin
      If (Ch = '<') And (SrcLine[SrcColNo + 1] = '<') And
         (SrcLine[SrcColNo + 2] = '=') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := '<<=';
        Inc(SrcColNo, 3); Inc(SrcTokenCount); Exit;
      End;
      If (Ch = '>') And (SrcLine[SrcColNo + 1] = '>') And
         (SrcLine[SrcColNo + 2] = '=') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := '>>=';
        Inc(SrcColNo, 3); Inc(SrcTokenCount); Exit;
      End;
    End;

    { Operateurs multi-caracteres (2 car) }
    If (SrcColNo < Length(SrcLine)) Then
    Begin
      S := Ch + SrcLine[SrcColNo + 1];
      If (S = '->') Or (S = '++') Or (S = '--') Or
         (S = '&&') Or (S = '||') Or (S = '<<') Or (S = '>>') Or
         (S = '==') Or (S = '!=') Or (S = '<=') Or (S = '>=') Or
         (S = '+=') Or (S = '-=') Or (S = '*=') Or (S = '/=') Or
         (S = '%=') Or (S = '&=') Or (S = '|=') Or (S = '^=') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := S;
        Inc(SrcColNo, 2); Inc(SrcTokenCount); Exit;
      End;
    End;

    { Operateurs simples }
    If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
       (Ch = '%') Or (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or
       (Ch = '!') Or (Ch = '&') Or (Ch = '|') Or (Ch = '^') Or
       (Ch = '~') Or (Ch = '?') Or (Ch = ':') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Ponctuation }
    If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
       (Ch = '{') Or (Ch = '}') Or (Ch = ',') Or (Ch = ';') Or
       (Ch = '.') Then
    Begin
      SrcToken.Kind := STK_PUNCT;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caractere inconnu }
    SrcToken.Kind := STK_PUNCT;
    SrcToken.Val  := Ch;
    Inc(SrcColNo);
    Inc(SrcTokenCount);
  End;
End;

{ ---- Parseur C : consommation de tokens ---------------------- }

Procedure CConsume; Forward;
Function CParseExpr : Integer; Forward;
Function CParsePrimary : Integer; Forward;
Function CParseUnary : Integer; Forward;
Function CParseBinary(MinPrec : Integer) : Integer; Forward;
Function CParseAssign : Integer; Forward;
Function CParseStatement : Integer; Forward;
Function CParseCompound : Integer; Forward;
Function CParseDeclaration : Integer; Forward;
Function CParseTopLevel : Integer; Forward;
Function CParseTranslationUnit : Integer; Forward;

Procedure CConsume;
Begin
  Repeat
    CLexNextToken;
  Until (SrcToken.Kind <> STK_COMMENT);
End;

Function CTokIs(Const S : TString) : Boolean;
Begin
  CTokIs := (SrcToken.Val = S);
End;

Function CTokIsKw(Const S : TString) : Boolean;
Begin
  CTokIsKw := (SrcToken.Kind = STK_KEYWORD) And (SrcToken.Val = S);
End;

Procedure CExpect(Const S : TString);
Begin
  If SrcToken.Val <> S Then
    WriteLn('CODEQL(C): attendu ''', S, ''' a la ligne ', SrcToken.Line,
            ', colonne ', SrcToken.Col, ', trouve ''', SrcToken.Val, '''');
  CConsume;
End;

{ ---- CParseTypeSpec : lire un specificateur de type C -------- }

Function CParseTypeSpec : TString;
Var S : TString;
Begin
  S := '';
  { Qualificateurs et specificateurs }
  While (CTokIsKw('const')) Or (CTokIsKw('volatile')) Or
        (CTokIsKw('static')) Or (CTokIsKw('extern')) Or
        (CTokIsKw('auto')) Or (CTokIsKw('register')) Or
        (CTokIsKw('signed')) Or (CTokIsKw('unsigned')) Or
        (CTokIsKw('short')) Or (CTokIsKw('long')) Or
        (CTokIsKw('typedef')) Do
  Begin
    If S <> '' Then S := S + ' ';
    S := S + SrcToken.Val;
    CConsume;
  End;
  { Type de base }
  If (CTokIsKw('void')) Or (CTokIsKw('char')) Or (CTokIsKw('int')) Or
     (CTokIsKw('float')) Or (CTokIsKw('double')) Or
     (CTokIsKw('struct')) Or (CTokIsKw('union')) Or
     (CTokIsKw('enum')) Or (SrcToken.Kind = STK_IDENT) Then
  Begin
    If S <> '' Then S := S + ' ';
    S := S + SrcToken.Val;
    CConsume;
    { struct/union/enum tag }
    If (SrcToken.Kind = STK_IDENT) And
       ((S = 'struct') Or (S = 'union') Or (S = 'enum') Or
        (Copy(S, Length(S) - 5, 6) = 'struct') Or
        (Copy(S, Length(S) - 4, 5) = 'union') Or
        (Copy(S, Length(S) - 3, 4) = 'enum')) Then
    Begin
      S := S + ' ' + SrcToken.Val;
      CConsume;
    End;
  End;
  { Pointeurs * }
  While CTokIs('*') Do
  Begin
    S := S + '*';
    CConsume;
  End;
  If S = '' Then S := 'int';
  CParseTypeSpec := S;
End;

{ ---- CIsCTypeStart : teste si le token courant demarre un type }

Function CIsCTypeStart : Boolean;
Begin
  CIsCTypeStart :=
    (CTokIsKw('void')) Or (CTokIsKw('char')) Or (CTokIsKw('int')) Or
    (CTokIsKw('short')) Or (CTokIsKw('long')) Or (CTokIsKw('float')) Or
    (CTokIsKw('double')) Or (CTokIsKw('signed')) Or (CTokIsKw('unsigned')) Or
    (CTokIsKw('const')) Or (CTokIsKw('volatile')) Or
    (CTokIsKw('static')) Or (CTokIsKw('extern')) Or
    (CTokIsKw('auto')) Or (CTokIsKw('register')) Or
    (CTokIsKw('struct')) Or (CTokIsKw('union')) Or
    (CTokIsKw('enum')) Or (CTokIsKw('typedef'));
End;

{ ---- CParsePrimary : expression primaire C ------------------- }

Function CParsePrimary : Integer;
Var N, ArgNode, Last : Integer;
Begin
  N := -1;
  Case SrcToken.Kind Of
    STK_INTEGER:
    Begin
      N := SrcNewNode(SNK_EXPR_INT);
      SrcNodes[N].IntVal := SrcToken.IntVal;
      SrcNodes[N].Name   := SrcToken.Val;
      CConsume;
    End;
    STK_FLOAT:
    Begin
      N := SrcNewNode(SNK_EXPR_FLOAT);
      SrcNodes[N].FloatVal := SrcToken.FloatVal;
      SrcNodes[N].Name     := SrcToken.Val;
      CConsume;
    End;
    STK_STRING:
    Begin
      N := SrcNewNode(SNK_EXPR_STRING);
      SrcNodes[N].Name := SrcToken.Val;
      CConsume;
    End;
    STK_KEYWORD:
    Begin
      If CTokIsKw('sizeof') Then
      Begin
        N := SrcNewNode(SNK_C_SIZEOF);
        SrcNodes[N].Name := 'sizeof';
        CConsume;
        If CTokIs('(') Then
        Begin
          CConsume;
          SrcNodes[N].Left := CParseExpr;
          If CTokIs(')') Then CConsume;
        End
        Else
          SrcNodes[N].Left := CParseUnary;
      End
      Else
      Begin
        N := SrcNewNode(SNK_EXPR_IDENT);
        SrcNodes[N].Name := SrcToken.Val;
        CConsume;
      End;
    End;
    STK_IDENT:
    Begin
      N := SrcNewNode(SNK_EXPR_IDENT);
      SrcNodes[N].Name := SrcToken.Val;
      CConsume;
    End;
  Else
    Begin
      If CTokIs('(') Then
      Begin
        CConsume;
        N := CParseExpr;
        If CTokIs(')') Then CConsume;
      End
      Else
      Begin
        N := SrcNewNode(SNK_EXPR_IDENT);
        SrcNodes[N].Name := SrcToken.Val;
        CConsume;
      End;
    End;
  End;
  { Postfix : appel de fonction, indexation, champ, ->, ++, -- }
  While (CTokIs('(')) Or (CTokIs('[')) Or (CTokIs('.')) Or
        (CTokIs('->')) Or (CTokIs('++')) Or (CTokIs('--')) Do
  Begin
    If CTokIs('(') Then
    Begin
      CConsume;
      ArgNode := SrcNewNode(SNK_EXPR_CALL);
      SrcNodes[ArgNode].Left := N;
      If N >= 0 Then
        SrcNodes[ArgNode].Name := SrcNodes[N].Name;
      Last := -1;
      If Not CTokIs(')') Then
      Begin
        SrcNodes[ArgNode].Right := CParseAssign;
        Last := SrcNodes[ArgNode].Right;
        While CTokIs(',') Do
        Begin
          CConsume;
          SrcNodes[Last].Next := CParseAssign;
          Last := SrcNodes[Last].Next;
        End;
      End;
      If CTokIs(')') Then CConsume;
      N := ArgNode;
    End
    Else If CTokIs('[') Then
    Begin
      CConsume;
      ArgNode := SrcNewNode(SNK_EXPR_INDEX);
      SrcNodes[ArgNode].Left  := N;
      SrcNodes[ArgNode].Right := CParseExpr;
      If CTokIs(']') Then CConsume;
      N := ArgNode;
    End
    Else If CTokIs('.') Then
    Begin
      CConsume;
      ArgNode := SrcNewNode(SNK_EXPR_FIELD);
      SrcNodes[ArgNode].Left := N;
      SrcNodes[ArgNode].Name := SrcToken.Val;
      CConsume;
      N := ArgNode;
    End
    Else If CTokIs('->') Then
    Begin
      CConsume;
      ArgNode := SrcNewNode(SNK_EXPR_FIELD);
      SrcNodes[ArgNode].Left := N;
      SrcNodes[ArgNode].Name := SrcToken.Val;
      CConsume;
      N := ArgNode;
    End
    Else If CTokIs('++') Or CTokIs('--') Then
    Begin
      ArgNode := SrcNewNode(SNK_EXPR_UNOP);
      SrcNodes[ArgNode].Name := SrcToken.Val + '_post';
      SrcNodes[ArgNode].Left := N;
      CConsume;
      N := ArgNode;
    End;
  End;
  CParsePrimary := N;
End;

{ ---- CParseUnary : expression unaire C ----------------------- }

Function CParseUnary : Integer;
Var N : Integer;
Begin
  If CTokIs('+') Or CTokIs('-') Or CTokIs('!') Or CTokIs('~') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := SrcToken.Val;
    CConsume;
    SrcNodes[N].Left := CParseUnary;
    CParseUnary := N;
  End
  Else If CTokIs('++') Or CTokIs('--') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := SrcToken.Val;
    CConsume;
    SrcNodes[N].Left := CParseUnary;
    CParseUnary := N;
  End
  Else If CTokIs('*') Then
  Begin
    N := SrcNewNode(SNK_EXPR_DEREF);
    CConsume;
    SrcNodes[N].Left := CParseUnary;
    CParseUnary := N;
  End
  Else If CTokIs('&') Then
  Begin
    N := SrcNewNode(SNK_EXPR_ADDR);
    CConsume;
    SrcNodes[N].Left := CParseUnary;
    CParseUnary := N;
  End
  Else
    CParseUnary := CParsePrimary;
End;

{ ---- COpPrec : precedence des operateurs binaires C ---------- }

Function COpPrec(Const Op : TString) : Integer;
Begin
  If (Op = '*') Or (Op = '/') Or (Op = '%') Then
    COpPrec := 12
  Else If (Op = '+') Or (Op = '-') Then
    COpPrec := 11
  Else If (Op = '<<') Or (Op = '>>') Then
    COpPrec := 10
  Else If (Op = '<') Or (Op = '>') Or (Op = '<=') Or (Op = '>=') Then
    COpPrec := 9
  Else If (Op = '==') Or (Op = '!=') Then
    COpPrec := 8
  Else If Op = '&' Then
    COpPrec := 7
  Else If Op = '^' Then
    COpPrec := 6
  Else If Op = '|' Then
    COpPrec := 5
  Else If Op = '&&' Then
    COpPrec := 4
  Else If Op = '||' Then
    COpPrec := 3
  Else
    COpPrec := 0;
End;

{ ---- CParseBinary : expression binaire C (Pratt) ------------- }

Function CParseBinary(MinPrec : Integer) : Integer;
Var Left, Right, BinNode, Prec : Integer;
    Op : TString;
Begin
  Left := CParseUnary;
  While (SrcToken.Kind = STK_OP) And (COpPrec(SrcToken.Val) >= MinPrec) Do
  Begin
    Op   := SrcToken.Val;
    Prec := COpPrec(Op);
    CConsume;
    Right := CParseBinary(Prec + 1);
    BinNode := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[BinNode].Name  := Op;
    SrcNodes[BinNode].Left  := Left;
    SrcNodes[BinNode].Right := Right;
    Left := BinNode;
  End;
  { Operateur ternaire ? : }
  If CTokIs('?') Then
  Begin
    CConsume;
    BinNode := SrcNewNode(SNK_C_TERNARY);
    SrcNodes[BinNode].Left  := Left;
    SrcNodes[BinNode].Right := CParseExpr;
    If CTokIs(':') Then CConsume;
    SrcNodes[BinNode].Extra := CParseAssign;
    Left := BinNode;
  End;
  CParseBinary := Left;
End;

{ ---- CParseAssign : expression d affectation C --------------- }

Function CParseAssign : Integer;
Var Left, N : Integer;
Begin
  Left := CParseBinary(1);
  If CTokIs('=') Or CTokIs('+=') Or CTokIs('-=') Or
     CTokIs('*=') Or CTokIs('/=') Or CTokIs('%=') Or
     CTokIs('&=') Or CTokIs('|=') Or CTokIs('^=') Or
     CTokIs('<<=') Or CTokIs('>>=') Then
  Begin
    N := SrcNewNode(SNK_ASSIGN);
    SrcNodes[N].Name  := SrcToken.Val;
    SrcNodes[N].Left  := Left;
    CConsume;
    SrcNodes[N].Right := CParseAssign;
    CParseAssign := N;
  End
  Else
    CParseAssign := Left;
End;

{ ---- CParseExpr : expression complete avec virgule ----------- }

Function CParseExpr : Integer;
Var N : Integer;
Begin
  N := CParseAssign;
  While CTokIs(',') Do
  Begin
    CConsume;
    SrcNodes[N].Next := CParseAssign;
    N := SrcNodes[N].Next;
  End;
  CParseExpr := N;
End;

(* ---- CParseCompound : bloc { ... } C ---------------------- *)

Function CParseCompound : Integer;
Var N, S, Last : Integer;
Begin
  N := SrcNewNode(SNK_COMPOUND);
  CExpect('{');
  Last := -1;
  While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
  Begin
    S := CParseStatement;
    If S >= 0 Then
    Begin
      If SrcNodes[N].Left = -1 Then
        SrcNodes[N].Left := S
      Else If Last >= 0 Then
        SrcNodes[Last].Next := S;
      Last := S;
    End;
  End;
  If CTokIs('}') Then CConsume;
  CParseCompound := N;
End;

{ ---- CParseStatement : instruction C ------------------------- }

Function CParseStatement : Integer;
Var N, Body, Last, Item : Integer;
Begin
  N := -1;

  { Directive du preprocesseur }
  If SrcToken.Kind = STK_DIRECTIVE Then
  Begin
    N := SrcNewNode(SNK_C_PREPROC);
    SrcNodes[N].Name := SrcToken.Val;
    CConsume;
    CParseStatement := N;
    Exit;
  End;

  (* Bloc compose { ... } *)
  If CTokIs('{') Then
  Begin
    CParseStatement := CParseCompound;
    Exit;
  End;

  { if (expr) stmt [else stmt] }
  If CTokIsKw('if') Then
  Begin
    N := SrcNewNode(SNK_IF);
    CConsume;
    If CTokIs('(') Then CConsume;
    SrcNodes[N].Left := CParseExpr;
    If CTokIs(')') Then CConsume;
    SrcNodes[N].Right := CParseStatement;
    If CTokIsKw('else') Then
    Begin
      CConsume;
      SrcNodes[N].Extra := CParseStatement;
    End;
    CParseStatement := N;
    Exit;
  End;

  { while (expr) stmt }
  If CTokIsKw('while') Then
  Begin
    N := SrcNewNode(SNK_WHILE);
    CConsume;
    If CTokIs('(') Then CConsume;
    SrcNodes[N].Left := CParseExpr;
    If CTokIs(')') Then CConsume;
    SrcNodes[N].Right := CParseStatement;
    CParseStatement := N;
    Exit;
  End;

  { for (init; cond; incr) stmt }
  If CTokIsKw('for') Then
  Begin
    N := SrcNewNode(SNK_FOR);
    CConsume;
    If CTokIs('(') Then CConsume;
    { init }
    If Not CTokIs(';') Then
      SrcNodes[N].Left := CParseExpr;
    If CTokIs(';') Then CConsume;
    { condition }
    If Not CTokIs(';') Then
      SrcNodes[N].Right := CParseExpr;
    If CTokIs(';') Then CConsume;
    { increment }
    If Not CTokIs(')') Then
      SrcNodes[N].Extra := CParseExpr;
    If CTokIs(')') Then CConsume;
    { body - stocker dans le Next du noeud Extra si possible }
    Body := CParseStatement;
    If SrcNodes[N].Extra >= 0 Then
      SrcNodes[SrcNodes[N].Extra].Next := Body
    Else If SrcNodes[N].Right >= 0 Then
      SrcNodes[SrcNodes[N].Right].Next := Body
    Else
      SrcNodes[N].Extra := Body;
    CParseStatement := N;
    Exit;
  End;

  { do stmt while (expr) ; }
  If CTokIsKw('do') Then
  Begin
    N := SrcNewNode(SNK_C_DO_WHILE);
    CConsume;
    SrcNodes[N].Left := CParseStatement;
    If CTokIsKw('while') Then CConsume;
    If CTokIs('(') Then CConsume;
    SrcNodes[N].Right := CParseExpr;
    If CTokIs(')') Then CConsume;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  (* switch (expr) { case ...: ... } *)
  If CTokIsKw('switch') Then
  Begin
    N := SrcNewNode(SNK_C_SWITCH);
    CConsume;
    If CTokIs('(') Then CConsume;
    SrcNodes[N].Left := CParseExpr;
    If CTokIs(')') Then CConsume;
    If CTokIs('{') Then CConsume;
    Last := -1;
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
    Begin
      If CTokIsKw('case') Then
      Begin
        Item := SrcNewNode(SNK_C_CASE_ITEM);
        CConsume;
        SrcNodes[Item].Left := CParseExpr;
        If CTokIs(':') Then CConsume;
        If SrcNodes[N].Right = -1 Then
          SrcNodes[N].Right := Item
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Item;
        Last := Item;
      End
      Else If CTokIsKw('default') Then
      Begin
        Item := SrcNewNode(SNK_C_DEFAULT_ITEM);
        CConsume;
        If CTokIs(':') Then CConsume;
        If SrcNodes[N].Right = -1 Then
          SrcNodes[N].Right := Item
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Item;
        Last := Item;
      End
      Else
      Begin
        Body := CParseStatement;
        If (Last >= 0) And (Body >= 0) Then
        Begin
          If SrcNodes[Last].Right = -1 Then
            SrcNodes[Last].Right := Body
          Else
          Begin
            Item := SrcNodes[Last].Right;
            While SrcNodes[Item].Next >= 0 Do
              Item := SrcNodes[Item].Next;
            SrcNodes[Item].Next := Body;
          End;
        End;
      End;
    End;
    If CTokIs('}') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { break ; }
  If CTokIsKw('break') Then
  Begin
    N := SrcNewNode(SNK_C_BREAK);
    CConsume;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { continue ; }
  If CTokIsKw('continue') Then
  Begin
    N := SrcNewNode(SNK_C_CONTINUE);
    CConsume;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { return [expr] ; }
  If CTokIsKw('return') Then
  Begin
    N := SrcNewNode(SNK_C_RETURN);
    CConsume;
    If Not CTokIs(';') Then
      SrcNodes[N].Left := CParseExpr;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { goto label ; }
  If CTokIsKw('goto') Then
  Begin
    N := SrcNewNode(SNK_GOTO);
    CConsume;
    SrcNodes[N].Name := SrcToken.Val;
    CConsume;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { Declarations locales (type ident ...) }
  If CIsCTypeStart Then
  Begin
    CParseStatement := CParseDeclaration;
    Exit;
  End;

  { Instruction vide ; }
  If CTokIs(';') Then
  Begin
    CConsume;
    CParseStatement := -1;
    Exit;
  End;

  { Label  ident : }
  If (SrcToken.Kind = STK_IDENT) Then
  Begin
    { Sauvegarder l etat pour verifier si c est un label }
    N := SrcNewNode(SNK_EXPR_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    CConsume;
    If CTokIs(':') Then
    Begin
      { C'est un label }
      SrcNodes[N].Kind := SNK_LABEL_DECL;
      CConsume;
      CParseStatement := N;
      Exit;
    End;
    { C est le debut d une expression-instruction }
    { N est deja un EXPR_IDENT, continuer le parsing postfix }
    While (CTokIs('(')) Or (CTokIs('[')) Or (CTokIs('.')) Or
          (CTokIs('->')) Or (CTokIs('++')) Or (CTokIs('--')) Do
    Begin
      If CTokIs('(') Then
      Begin
        CConsume;
        Item := SrcNewNode(SNK_EXPR_CALL);
        SrcNodes[Item].Left := N;
        SrcNodes[Item].Name := SrcNodes[N].Name;
        Last := -1;
        If Not CTokIs(')') Then
        Begin
          SrcNodes[Item].Right := CParseAssign;
          Last := SrcNodes[Item].Right;
          While CTokIs(',') Do
          Begin
            CConsume;
            SrcNodes[Last].Next := CParseAssign;
            Last := SrcNodes[Last].Next;
          End;
        End;
        If CTokIs(')') Then CConsume;
        N := Item;
      End
      Else If CTokIs('[') Then
      Begin
        CConsume;
        Item := SrcNewNode(SNK_EXPR_INDEX);
        SrcNodes[Item].Left  := N;
        SrcNodes[Item].Right := CParseExpr;
        If CTokIs(']') Then CConsume;
        N := Item;
      End
      Else If CTokIs('.') Or CTokIs('->') Then
      Begin
        CConsume;
        Item := SrcNewNode(SNK_EXPR_FIELD);
        SrcNodes[Item].Left := N;
        SrcNodes[Item].Name := SrcToken.Val;
        CConsume;
        N := Item;
      End
      Else If CTokIs('++') Or CTokIs('--') Then
      Begin
        Item := SrcNewNode(SNK_EXPR_UNOP);
        SrcNodes[Item].Name := SrcToken.Val + '_post';
        SrcNodes[Item].Left := N;
        CConsume;
        N := Item;
      End;
    End;
    { Verifier affectation }
    If CTokIs('=') Or CTokIs('+=') Or CTokIs('-=') Or
       CTokIs('*=') Or CTokIs('/=') Or CTokIs('%=') Or
       CTokIs('&=') Or CTokIs('|=') Or CTokIs('^=') Or
       CTokIs('<<=') Or CTokIs('>>=') Then
    Begin
      Item := SrcNewNode(SNK_ASSIGN);
      SrcNodes[Item].Name  := SrcToken.Val;
      SrcNodes[Item].Left  := N;
      CConsume;
      SrcNodes[Item].Right := CParseExpr;
      N := Item;
    End;
    If CTokIs(';') Then CConsume;
    CParseStatement := N;
    Exit;
  End;

  { Expression-instruction }
  N := CParseExpr;
  If CTokIs(';') Then CConsume;
  CParseStatement := N;
End;

{ ---- CParseDeclaration : declaration C ----------------------- }

Function CParseDeclaration : Integer;
Var TypeStr : TString;
    N, Last, VN : Integer;
    IsTypedef : Boolean;
    TagKind : TSrcNodeKind;
Begin
  IsTypedef := CTokIsKw('typedef');
  TagKind := SNK_NONE;

  { Detecter struct/union/enum }
  If CTokIsKw('struct') Or CTokIsKw('union') Or CTokIsKw('enum') Then
  Begin
    If CTokIsKw('struct') Then TagKind := SNK_C_STRUCT_DECL
    Else If CTokIsKw('union') Then TagKind := SNK_C_UNION_DECL
    Else TagKind := SNK_C_ENUM_DECL;
  End;

  TypeStr := CParseTypeSpec;

  (* struct/union/enum avec corps { ... } *)
  If (TagKind <> SNK_NONE) And CTokIs('{') Then
  Begin
    N := SrcNewNode(TagKind);
    SrcNodes[N].Name := TypeStr;
    CConsume; (* sauter lacco ouvrante *)
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
    Begin
      { Sauter le contenu du corps }
      CConsume;
    End;
    If CTokIs('}') Then CConsume;
    { Eventuellement un nom de variable apres la fermeture }
    If (SrcToken.Kind = STK_IDENT) Then
    Begin
      SrcNodes[N].Name := SrcNodes[N].Name + ' ' + SrcToken.Val;
      CConsume;
    End;
    If CTokIs(';') Then CConsume;
    CParseDeclaration := N;
    Exit;
  End;

  If IsTypedef Then
  Begin
    N := SrcNewNode(SNK_C_TYPEDEF);
    SrcNodes[N].Name := TypeStr;
    { Le dernier ident avant ; est le nom du typedef }
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs(';')) Do
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CConsume;
    End;
    If CTokIs(';') Then CConsume;
    CParseDeclaration := N;
    Exit;
  End;

  { Variable ou liste de variables }
  N := -1;
  Last := -1;
  While True Do
  Begin
    { Sauter les pointeurs restants }
    While CTokIs('*') Do CConsume;

    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
    Begin
      VN := SrcNewNode(SNK_VAR_DECL);
      SrcNodes[VN].Name := SrcToken.Val;
      CConsume;
      { Tableau [...] }
      While CTokIs('[') Do
      Begin
        CConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CTokIs(']')) Do
          CConsume;
        If CTokIs(']') Then CConsume;
      End;
      { Initialisation = expr }
      If CTokIs('=') Then
      Begin
        CConsume;
        If CTokIs('{') Then
        Begin
          { Initialisation agregat - sauter }
          CConsume;
          While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
            CConsume;
          If CTokIs('}') Then CConsume;
        End
        Else
          SrcNodes[VN].Left := CParseAssign;
      End;
      If N = -1 Then
        N := VN
      Else If Last >= 0 Then
        SrcNodes[Last].Next := VN;
      Last := VN;
    End
    Else
      Break;

    If CTokIs(',') Then
      CConsume
    Else
      Break;
  End;
  If CTokIs(';') Then CConsume;
  CParseDeclaration := N;
End;

{ ---- CParseTopLevel : declaration ou fonction top-level C ---- }

Function CParseTopLevel : Integer;
Var N : Integer;
    TypeStr, FuncName : TString;
    TagKind : TSrcNodeKind;
Begin
  N := -1;
  TagKind := SNK_NONE;

  { Directive preprocesseur }
  If SrcToken.Kind = STK_DIRECTIVE Then
  Begin
    N := SrcNewNode(SNK_C_PREPROC);
    SrcNodes[N].Name := SrcToken.Val;
    If (Length(SrcToken.Val) >= 8) And
       (Copy(SrcToken.Val, 1, 8) = '#include') Then
      SrcNodes[N].Kind := SNK_C_INCLUDE
    Else If (Length(SrcToken.Val) >= 7) And
            (Copy(SrcToken.Val, 1, 7) = '#define') Then
      SrcNodes[N].Kind := SNK_C_DEFINE;
    CConsume;
    CParseTopLevel := N;
    Exit;
  End;

  { Detecter struct/union/enum avant CParseTypeSpec }
  If CTokIsKw('struct') Then TagKind := SNK_C_STRUCT_DECL
  Else If CTokIsKw('union') Then TagKind := SNK_C_UNION_DECL
  Else If CTokIsKw('enum') Then TagKind := SNK_C_ENUM_DECL;

  { Lire le type de retour / type de declaration }
  TypeStr := CParseTypeSpec;

  { struct/union/enum avec corps }
  If (TagKind <> SNK_NONE) And CTokIs('{') Then
  Begin
    N := SrcNewNode(TagKind);
    SrcNodes[N].Name := TypeStr;
    CConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
      CConsume;
    If CTokIs('}') Then CConsume;
    If (SrcToken.Kind = STK_IDENT) Then
    Begin
      SrcNodes[N].Name := SrcNodes[N].Name + ' ' + SrcToken.Val;
      CConsume;
    End;
    If CTokIs(';') Then CConsume;
    CParseTopLevel := N;
    Exit;
  End;

  { typedef }
  If (Length(TypeStr) >= 7) And (Copy(TypeStr, 1, 7) = 'typedef') Then
  Begin
    N := SrcNewNode(SNK_C_TYPEDEF);
    SrcNodes[N].Name := TypeStr;
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs(';')) Do
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CConsume;
    End;
    If CTokIs(';') Then CConsume;
    CParseTopLevel := N;
    Exit;
  End;

  { Nom de la fonction ou variable }
  FuncName := '';
  While CTokIs('*') Do CConsume;
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    FuncName := SrcToken.Val;
    CConsume;
  End;

  (* Fonction : nom ( ... ) lacco ... racco *)
  If CTokIs('(') Then
  Begin
    N := SrcNewNode(SNK_FUNC_DECL);
    SrcNodes[N].Name := FuncName;
    CConsume; { sauter ( }
    { Parametres }
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs(')')) Do
      CConsume;
    If CTokIs(')') Then CConsume;
    { Corps de la fonction ou prototype }
    If CTokIs('{') Then
      SrcNodes[N].Left := CParseCompound
    Else If CTokIs(';') Then
      CConsume;
    CParseTopLevel := N;
    Exit;
  End;

  { Declaration de variable globale }
  N := SrcNewNode(SNK_VAR_DECL);
  SrcNodes[N].Name := FuncName;
  { Tableau [...] }
  While CTokIs('[') Do
  Begin
    CConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CTokIs(']')) Do
      CConsume;
    If CTokIs(']') Then CConsume;
  End;
  { Initialisation }
  If CTokIs('=') Then
  Begin
    CConsume;
    If CTokIs('{') Then
    Begin
      CConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
        CConsume;
      If CTokIs('}') Then CConsume;
    End
    Else
      SrcNodes[N].Left := CParseAssign;
  End;
  { Plusieurs variables separees par , }
  While CTokIs(',') Do
  Begin
    CConsume;
    While CTokIs('*') Do CConsume;
    If (SrcToken.Kind = STK_IDENT) Then CConsume;
    If CTokIs('=') Then
    Begin
      CConsume;
      If CTokIs('{') Then
      Begin
        CConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CTokIs('}')) Do
          CConsume;
        If CTokIs('}') Then CConsume;
      End;
    End;
  End;
  If CTokIs(';') Then CConsume;
  CParseTopLevel := N;
End;

{ ---- CParseTranslationUnit : unite de traduction C ----------- }

Function CParseTranslationUnit : Integer;
Var Root, N, Last : Integer;
Begin
  CConsume; { lire le premier token }
  Root := SrcNewNode(SNK_C_TRANSLATION_UNIT);
  SrcNodes[Root].Name := 'C_TU';
  Last := -1;
  While SrcToken.Kind <> STK_EOF Do
  Begin
    N := CParseTopLevel;
    If N >= 0 Then
    Begin
      If SrcNodes[Root].Left = -1 Then
        SrcNodes[Root].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End;
  End;
  CParseTranslationUnit := Root;
End;

{ ---- Fin TODO 26 --------------------------------------------- }

{ ============================================================
  TODO 27 - LEXEUR ET PARSEUR C++ [IMPLEMENTE]
  ============================================================ }

{ ---- IsCppKeyword : reconnaissance des mots-cles C++ -------- }

Function IsCppKeyword(Const W : TString) : Boolean;
Begin
  IsCppKeyword :=
    IsCKeyword(W) Or
    (W = 'class')     Or (W = 'namespace')  Or (W = 'template')  Or
    (W = 'virtual')   Or (W = 'public')     Or (W = 'private')   Or
    (W = 'protected') Or (W = 'try')        Or (W = 'catch')     Or
    (W = 'throw')     Or (W = 'new')        Or (W = 'delete')    Or
    (W = 'bool')      Or (W = 'true')       Or (W = 'false')     Or
    (W = 'using')     Or (W = 'operator')   Or (W = 'friend')    Or
    (W = 'inline')    Or (W = 'explicit')   Or (W = 'mutable')   Or
    (W = 'typeid')    Or (W = 'typename')   Or (W = 'nullptr')   Or
    (W = 'dynamic_cast')     Or (W = 'static_cast') Or
    (W = 'reinterpret_cast') Or (W = 'const_cast')  Or
    (W = 'override')  Or (W = 'final')      Or (W = 'noexcept')  Or
    (W = 'constexpr') Or (W = 'decltype')   Or (W = 'auto');
End;

{ ---- CppLexScanIdent : scanner un identificateur ou mot-cle C++ }

Procedure CppLexScanIdent;
Var S : TString;
Begin
  S := '';
  While (SrcColNo <= Length(SrcLine)) And
        IsIdentCont(SrcLine[SrcColNo]) Do
  Begin
    If Length(S) < 255 Then
      S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  If IsCppKeyword(S) Then
    SrcToken.Kind := STK_KEYWORD
  Else
    SrcToken.Kind := STK_IDENT;
  SrcToken.Val := S;
End;

{ ---- CppLexInit : initialiser le lexeur C++ ------------------ }

Procedure CppLexInit;
Begin
  SrcLineNo    := 0;
  SrcColNo     := 1;
  SrcEOF       := False;
  SrcLine      := '';
  SrcTokenCount := 0;
  SrcTotalLines := 0;
  SrcToken.Kind     := STK_EOF;
  SrcToken.Val      := '';
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;
  SrcToken.Line     := 0;
  SrcToken.Col      := 0;
  SrcLexNextLine;
End;

{ ---- CppLexNextToken : prochain token C++ -------------------- }

Procedure CppLexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
  S        : TString;
Begin
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    While (Not SrcEOF) And (SrcColNo > Length(SrcLine)) Do
      SrcLexNextLine;

    If SrcEOF Then
    Begin
      SrcToken.Kind := STK_EOF;
      SrcToken.Val  := '';
      SrcToken.Line := SrcLineNo;
      SrcToken.Col  := SrcColNo;
      Scanning := False;
      Break;
    End;

    SrcToken.Line := SrcLineNo;
    SrcToken.Col  := SrcColNo;
    Ch := SrcLine[SrcColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(SrcColNo);
      Continue;
    End;

    Scanning := False;

    { Preprocesseur : lignes commencant par # }
    If Ch = '#' Then
    Begin
      S := '';
      While SrcColNo <= Length(SrcLine) Do
      Begin
        If Length(S) < 255 Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
      SrcToken.Kind := STK_DIRECTIVE;
      SrcToken.Val  := S;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire de ligne // }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '/') Then
    Begin
      CLexSkipLineComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Commentaire bloc /* ... */ }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '*') Then
    Begin
      CLexSkipBlockComment;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines entre guillemets }
    If Ch = '"' Then
    Begin
      CLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caracteres entre apostrophes }
    If Ch = '''' Then
    Begin
      CLexScanChar;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Identificateurs et mots-cles }
    If IsIdentStart(Ch) Then
    Begin
      CppLexScanIdent;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Nombres }
    If IsDigit(Ch) Then
    Begin
      CLexScanNumber;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Operateurs multi-caracteres (3 car) }
    If (SrcColNo + 1 < Length(SrcLine)) Then
    Begin
      If (Ch = '<') And (SrcLine[SrcColNo + 1] = '<') And
         (SrcLine[SrcColNo + 2] = '=') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := '<<=';
        Inc(SrcColNo, 3); Inc(SrcTokenCount); Exit;
      End;
      If (Ch = '>') And (SrcLine[SrcColNo + 1] = '>') And
         (SrcLine[SrcColNo + 2] = '=') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := '>>=';
        Inc(SrcColNo, 3); Inc(SrcTokenCount); Exit;
      End;
    End;

    { Operateurs multi-caracteres (2 car) }
    If (SrcColNo < Length(SrcLine)) Then
    Begin
      S := Ch + SrcLine[SrcColNo + 1];
      If (S = '->') Or (S = '++') Or (S = '--') Or
         (S = '&&') Or (S = '||') Or (S = '<<') Or (S = '>>') Or
         (S = '==') Or (S = '!=') Or (S = '<=') Or (S = '>=') Or
         (S = '+=') Or (S = '-=') Or (S = '*=') Or (S = '/=') Or
         (S = '%=') Or (S = '&=') Or (S = '|=') Or (S = '^=') Or
         (S = '::') Then
      Begin
        SrcToken.Kind := STK_OP; SrcToken.Val := S;
        Inc(SrcColNo, 2); Inc(SrcTokenCount); Exit;
      End;
    End;

    { Operateurs simples }
    If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
       (Ch = '%') Or (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or
       (Ch = '!') Or (Ch = '&') Or (Ch = '|') Or (Ch = '^') Or
       (Ch = '~') Or (Ch = '?') Or (Ch = ':') Then
    Begin
      SrcToken.Kind := STK_OP;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Ponctuation }
    If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
       (Ch = '{') Or (Ch = '}') Or (Ch = ',') Or (Ch = ';') Or
       (Ch = '.') Then
    Begin
      SrcToken.Kind := STK_PUNCT;
      SrcToken.Val  := Ch;
      Inc(SrcColNo);
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caractere inconnu }
    SrcToken.Kind := STK_PUNCT;
    SrcToken.Val  := Ch;
    Inc(SrcColNo);
    Inc(SrcTokenCount);
  End;
End;

{ ---- Parseur C++ : consommation de tokens -------------------- }

Procedure CppConsume; Forward;
Function CppParseExpr : Integer; Forward;
Function CppParsePrimary : Integer; Forward;
Function CppParseUnary : Integer; Forward;
Function CppParseBinary(MinPrec : Integer) : Integer; Forward;
Function CppParseAssign : Integer; Forward;
Function CppParseStatement : Integer; Forward;
Function CppParseCompound : Integer; Forward;
Function CppParseDeclaration : Integer; Forward;
Function CppParseTopLevel : Integer; Forward;
Function CppParseTranslationUnit : Integer; Forward;

Procedure CppConsume;
Begin
  Repeat
    CppLexNextToken;
  Until (SrcToken.Kind <> STK_COMMENT);
End;

Function CppTokIs(Const S : TString) : Boolean;
Begin
  CppTokIs := (SrcToken.Val = S);
End;

Function CppTokIsKw(Const S : TString) : Boolean;
Begin
  CppTokIsKw := (SrcToken.Kind = STK_KEYWORD) And (SrcToken.Val = S);
End;

Procedure CppExpect(Const S : TString);
Begin
  If SrcToken.Val <> S Then
    WriteLn('CODEQL(C++): attendu ''', S, ''' a la ligne ', SrcToken.Line,
            ', colonne ', SrcToken.Col, ', trouve ''', SrcToken.Val, '''');
  CppConsume;
End;

{ ---- CppParseTypeSpec : lire un specificateur de type C++ ---- }

Function CppParseTypeSpec : TString;
Var S : TString;
Begin
  S := '';
  { Qualificateurs et specificateurs }
  While (CppTokIsKw('const')) Or (CppTokIsKw('volatile')) Or
        (CppTokIsKw('static')) Or (CppTokIsKw('extern')) Or
        (CppTokIsKw('auto')) Or (CppTokIsKw('register')) Or
        (CppTokIsKw('signed')) Or (CppTokIsKw('unsigned')) Or
        (CppTokIsKw('short')) Or (CppTokIsKw('long')) Or
        (CppTokIsKw('typedef')) Or (CppTokIsKw('inline')) Or
        (CppTokIsKw('virtual')) Or (CppTokIsKw('explicit')) Or
        (CppTokIsKw('mutable')) Or (CppTokIsKw('constexpr')) Do
  Begin
    If S <> '' Then S := S + ' ';
    S := S + SrcToken.Val;
    CppConsume;
  End;
  { Type de base }
  If (CppTokIsKw('void')) Or (CppTokIsKw('char')) Or (CppTokIsKw('int')) Or
     (CppTokIsKw('float')) Or (CppTokIsKw('double')) Or
     (CppTokIsKw('bool')) Or
     (CppTokIsKw('struct')) Or (CppTokIsKw('union')) Or
     (CppTokIsKw('enum')) Or (CppTokIsKw('class')) Or
     (CppTokIsKw('typename')) Or
     (SrcToken.Kind = STK_IDENT) Then
  Begin
    If S <> '' Then S := S + ' ';
    S := S + SrcToken.Val;
    CppConsume;
    { Scope resolution :: }
    While CppTokIs('::') Do
    Begin
      S := S + '::';
      CppConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        S := S + SrcToken.Val;
        CppConsume;
      End;
    End;
    { struct/union/enum/class tag }
    If (SrcToken.Kind = STK_IDENT) And
       ((S = 'struct') Or (S = 'union') Or (S = 'enum') Or
        (S = 'class') Or
        (Copy(S, Length(S) - 5, 6) = 'struct') Or
        (Copy(S, Length(S) - 4, 5) = 'union') Or
        (Copy(S, Length(S) - 3, 4) = 'enum') Or
        (Copy(S, Length(S) - 4, 5) = 'class')) Then
    Begin
      S := S + ' ' + SrcToken.Val;
      CppConsume;
    End;
    { Template arguments < ... > }
    If CppTokIs('<') Then
    Begin
      S := S + '<';
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('>')) Do
      Begin
        S := S + SrcToken.Val;
        CppConsume;
      End;
      If CppTokIs('>') Then
      Begin
        S := S + '>';
        CppConsume;
      End;
    End;
  End;
  { Reference & et && }
  While CppTokIs('&') Do
  Begin
    S := S + '&';
    CppConsume;
  End;
  { Pointeurs * }
  While CppTokIs('*') Do
  Begin
    S := S + '*';
    CppConsume;
  End;
  If S = '' Then S := 'int';
  CppParseTypeSpec := S;
End;

{ ---- CppIsCTypeStart : teste si le token demarre un type C++ - }

Function CppIsCTypeStart : Boolean;
Begin
  CppIsCTypeStart :=
    (CppTokIsKw('void')) Or (CppTokIsKw('char')) Or (CppTokIsKw('int')) Or
    (CppTokIsKw('short')) Or (CppTokIsKw('long')) Or (CppTokIsKw('float')) Or
    (CppTokIsKw('double')) Or (CppTokIsKw('signed')) Or
    (CppTokIsKw('unsigned')) Or (CppTokIsKw('bool')) Or
    (CppTokIsKw('const')) Or (CppTokIsKw('volatile')) Or
    (CppTokIsKw('static')) Or (CppTokIsKw('extern')) Or
    (CppTokIsKw('auto')) Or (CppTokIsKw('register')) Or
    (CppTokIsKw('struct')) Or (CppTokIsKw('union')) Or
    (CppTokIsKw('enum')) Or (CppTokIsKw('typedef')) Or
    (CppTokIsKw('class')) Or (CppTokIsKw('typename')) Or
    (CppTokIsKw('inline')) Or (CppTokIsKw('virtual')) Or
    (CppTokIsKw('explicit')) Or (CppTokIsKw('constexpr'));
End;

{ ---- CppParsePrimary : expression primaire C++ --------------- }

Function CppParsePrimary : Integer;
Var N, ArgNode, Last : Integer;
Begin
  N := -1;
  Case SrcToken.Kind Of
    STK_INTEGER:
    Begin
      N := SrcNewNode(SNK_EXPR_INT);
      SrcNodes[N].IntVal := SrcToken.IntVal;
      SrcNodes[N].Name   := SrcToken.Val;
      CppConsume;
    End;
    STK_FLOAT:
    Begin
      N := SrcNewNode(SNK_EXPR_FLOAT);
      SrcNodes[N].FloatVal := SrcToken.FloatVal;
      SrcNodes[N].Name     := SrcToken.Val;
      CppConsume;
    End;
    STK_STRING:
    Begin
      N := SrcNewNode(SNK_EXPR_STRING);
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
    End;
    STK_KEYWORD:
    Begin
      If CppTokIsKw('sizeof') Then
      Begin
        N := SrcNewNode(SNK_C_SIZEOF);
        SrcNodes[N].Name := 'sizeof';
        CppConsume;
        If CppTokIs('(') Then
        Begin
          CppConsume;
          SrcNodes[N].Left := CppParseExpr;
          If CppTokIs(')') Then CppConsume;
        End
        Else
          SrcNodes[N].Left := CppParseUnary;
      End
      Else If CppTokIsKw('new') Then
      Begin
        N := SrcNewNode(SNK_CPP_NEW);
        SrcNodes[N].Name := 'new';
        CppConsume;
        { new Type ou new Type(...) ou new Type[...] }
        If SrcToken.Kind <> STK_EOF Then
        Begin
          SrcNodes[N].Name := 'new ' + SrcToken.Val;
          CppConsume;
        End;
        If CppTokIs('(') Then
        Begin
          CppConsume;
          If Not CppTokIs(')') Then
            SrcNodes[N].Left := CppParseExpr;
          If CppTokIs(')') Then CppConsume;
        End
        Else If CppTokIs('[') Then
        Begin
          CppConsume;
          SrcNodes[N].Left := CppParseExpr;
          If CppTokIs(']') Then CppConsume;
        End;
      End
      Else If CppTokIsKw('delete') Then
      Begin
        N := SrcNewNode(SNK_CPP_DELETE);
        SrcNodes[N].Name := 'delete';
        CppConsume;
        If CppTokIs('[') Then
        Begin
          CppConsume;
          If CppTokIs(']') Then CppConsume;
          SrcNodes[N].Name := 'delete[]';
        End;
        SrcNodes[N].Left := CppParseUnary;
      End
      Else If CppTokIsKw('true') Or CppTokIsKw('false') Then
      Begin
        N := SrcNewNode(SNK_EXPR_INT);
        If CppTokIsKw('true') Then
          SrcNodes[N].IntVal := 1
        Else
          SrcNodes[N].IntVal := 0;
        SrcNodes[N].Name := SrcToken.Val;
        CppConsume;
      End
      Else If CppTokIsKw('nullptr') Then
      Begin
        N := SrcNewNode(SNK_EXPR_NIL);
        SrcNodes[N].Name := 'nullptr';
        CppConsume;
      End
      Else If CppTokIsKw('static_cast') Or CppTokIsKw('dynamic_cast') Or
              CppTokIsKw('reinterpret_cast') Or CppTokIsKw('const_cast') Then
      Begin
        N := SrcNewNode(SNK_C_CAST);
        SrcNodes[N].Name := SrcToken.Val;
        CppConsume;
        { <Type> }
        If CppTokIs('<') Then
        Begin
          CppConsume;
          While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('>')) Do
            CppConsume;
          If CppTokIs('>') Then CppConsume;
        End;
        { (expr) }
        If CppTokIs('(') Then
        Begin
          CppConsume;
          SrcNodes[N].Left := CppParseExpr;
          If CppTokIs(')') Then CppConsume;
        End;
      End
      Else If CppTokIsKw('typeid') Then
      Begin
        N := SrcNewNode(SNK_EXPR_CALL);
        SrcNodes[N].Name := 'typeid';
        CppConsume;
        If CppTokIs('(') Then
        Begin
          CppConsume;
          SrcNodes[N].Left := CppParseExpr;
          If CppTokIs(')') Then CppConsume;
        End;
      End
      Else If CppTokIsKw('throw') Then
      Begin
        N := SrcNewNode(SNK_CPP_THROW);
        SrcNodes[N].Name := 'throw';
        CppConsume;
        If (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(';')) Then
          SrcNodes[N].Left := CppParseAssign;
      End
      Else
      Begin
        N := SrcNewNode(SNK_EXPR_IDENT);
        SrcNodes[N].Name := SrcToken.Val;
        CppConsume;
      End;
    End;
    STK_IDENT:
    Begin
      N := SrcNewNode(SNK_EXPR_IDENT);
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
      { Scope resolution :: }
      While CppTokIs('::') Do
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + '::';
        CppConsume;
        If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
        Begin
          SrcNodes[N].Name := SrcNodes[N].Name + SrcToken.Val;
          CppConsume;
        End;
      End;
    End;
  Else
    Begin
      If CppTokIs('(') Then
      Begin
        CppConsume;
        N := CppParseExpr;
        If CppTokIs(')') Then CppConsume;
      End
      Else If CppTokIs('::') Then
      Begin
        N := SrcNewNode(SNK_CPP_SCOPE_RES);
        SrcNodes[N].Name := '::';
        CppConsume;
        If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
        Begin
          SrcNodes[N].Name := '::' + SrcToken.Val;
          CppConsume;
        End;
      End
      Else
      Begin
        N := SrcNewNode(SNK_EXPR_IDENT);
        SrcNodes[N].Name := SrcToken.Val;
        CppConsume;
      End;
    End;
  End;
  { Postfix : appel, indexation, champ, ->, ++, --, :: }
  While (CppTokIs('(')) Or (CppTokIs('[')) Or (CppTokIs('.')) Or
        (CppTokIs('->')) Or (CppTokIs('++')) Or (CppTokIs('--')) Do
  Begin
    If CppTokIs('(') Then
    Begin
      CppConsume;
      ArgNode := SrcNewNode(SNK_EXPR_CALL);
      SrcNodes[ArgNode].Left := N;
      If N >= 0 Then
        SrcNodes[ArgNode].Name := SrcNodes[N].Name;
      Last := -1;
      If Not CppTokIs(')') Then
      Begin
        SrcNodes[ArgNode].Right := CppParseAssign;
        Last := SrcNodes[ArgNode].Right;
        While CppTokIs(',') Do
        Begin
          CppConsume;
          SrcNodes[Last].Next := CppParseAssign;
          Last := SrcNodes[Last].Next;
        End;
      End;
      If CppTokIs(')') Then CppConsume;
      N := ArgNode;
    End
    Else If CppTokIs('[') Then
    Begin
      CppConsume;
      ArgNode := SrcNewNode(SNK_EXPR_INDEX);
      SrcNodes[ArgNode].Left  := N;
      SrcNodes[ArgNode].Right := CppParseExpr;
      If CppTokIs(']') Then CppConsume;
      N := ArgNode;
    End
    Else If CppTokIs('.') Then
    Begin
      CppConsume;
      ArgNode := SrcNewNode(SNK_EXPR_FIELD);
      SrcNodes[ArgNode].Left := N;
      SrcNodes[ArgNode].Name := SrcToken.Val;
      CppConsume;
      N := ArgNode;
    End
    Else If CppTokIs('->') Then
    Begin
      CppConsume;
      ArgNode := SrcNewNode(SNK_EXPR_FIELD);
      SrcNodes[ArgNode].Left := N;
      SrcNodes[ArgNode].Name := SrcToken.Val;
      CppConsume;
      N := ArgNode;
    End
    Else If CppTokIs('++') Or CppTokIs('--') Then
    Begin
      ArgNode := SrcNewNode(SNK_EXPR_UNOP);
      SrcNodes[ArgNode].Name := SrcToken.Val + '_post';
      SrcNodes[ArgNode].Left := N;
      CppConsume;
      N := ArgNode;
    End;
  End;
  CppParsePrimary := N;
End;

{ ---- CppParseUnary : expression unaire C++ ------------------- }

Function CppParseUnary : Integer;
Var N : Integer;
Begin
  If CppTokIs('+') Or CppTokIs('-') Or CppTokIs('!') Or CppTokIs('~') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := SrcToken.Val;
    CppConsume;
    SrcNodes[N].Left := CppParseUnary;
    CppParseUnary := N;
  End
  Else If CppTokIs('++') Or CppTokIs('--') Then
  Begin
    N := SrcNewNode(SNK_EXPR_UNOP);
    SrcNodes[N].Name := SrcToken.Val;
    CppConsume;
    SrcNodes[N].Left := CppParseUnary;
    CppParseUnary := N;
  End
  Else If CppTokIs('*') Then
  Begin
    N := SrcNewNode(SNK_EXPR_DEREF);
    CppConsume;
    SrcNodes[N].Left := CppParseUnary;
    CppParseUnary := N;
  End
  Else If CppTokIs('&') Then
  Begin
    N := SrcNewNode(SNK_EXPR_ADDR);
    CppConsume;
    SrcNodes[N].Left := CppParseUnary;
    CppParseUnary := N;
  End
  Else
    CppParseUnary := CppParsePrimary;
End;

{ ---- CppParseBinary : expression binaire C++ (Pratt) --------- }

Function CppParseBinary(MinPrec : Integer) : Integer;
Var Left, Right, BinNode, Prec : Integer;
    Op : TString;
Begin
  Left := CppParseUnary;
  While (SrcToken.Kind = STK_OP) And (COpPrec(SrcToken.Val) >= MinPrec) Do
  Begin
    Op   := SrcToken.Val;
    Prec := COpPrec(Op);
    CppConsume;
    Right := CppParseBinary(Prec + 1);
    BinNode := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[BinNode].Name  := Op;
    SrcNodes[BinNode].Left  := Left;
    SrcNodes[BinNode].Right := Right;
    Left := BinNode;
  End;
  { Operateur ternaire ? : }
  If CppTokIs('?') Then
  Begin
    CppConsume;
    BinNode := SrcNewNode(SNK_C_TERNARY);
    SrcNodes[BinNode].Left  := Left;
    SrcNodes[BinNode].Right := CppParseExpr;
    If CppTokIs(':') Then CppConsume;
    SrcNodes[BinNode].Extra := CppParseAssign;
    Left := BinNode;
  End;
  CppParseBinary := Left;
End;

{ ---- CppParseAssign : expression d affectation C++ ----------- }

Function CppParseAssign : Integer;
Var Left, N : Integer;
Begin
  Left := CppParseBinary(1);
  If CppTokIs('=') Or CppTokIs('+=') Or CppTokIs('-=') Or
     CppTokIs('*=') Or CppTokIs('/=') Or CppTokIs('%=') Or
     CppTokIs('&=') Or CppTokIs('|=') Or CppTokIs('^=') Or
     CppTokIs('<<=') Or CppTokIs('>>=') Then
  Begin
    N := SrcNewNode(SNK_ASSIGN);
    SrcNodes[N].Name  := SrcToken.Val;
    SrcNodes[N].Left  := Left;
    CppConsume;
    SrcNodes[N].Right := CppParseAssign;
    CppParseAssign := N;
  End
  Else
    CppParseAssign := Left;
End;

{ ---- CppParseExpr : expression complete avec virgule --------- }

Function CppParseExpr : Integer;
Var N : Integer;
Begin
  N := CppParseAssign;
  While CppTokIs(',') Do
  Begin
    CppConsume;
    SrcNodes[N].Next := CppParseAssign;
    N := SrcNodes[N].Next;
  End;
  CppParseExpr := N;
End;

(* ---- CppParseCompound : bloc lacco ... racco C++ ----------- *)

Function CppParseCompound : Integer;
Var N, S, Last : Integer;
Begin
  N := SrcNewNode(SNK_COMPOUND);
  CppExpect('{');
  Last := -1;
  While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
  Begin
    S := CppParseStatement;
    If S >= 0 Then
    Begin
      If SrcNodes[N].Left = -1 Then
        SrcNodes[N].Left := S
      Else If Last >= 0 Then
        SrcNodes[Last].Next := S;
      Last := S;
    End;
  End;
  If CppTokIs('}') Then CppConsume;
  CppParseCompound := N;
End;

{ ---- CppParseStatement : instruction C++ --------------------- }

Function CppParseStatement : Integer;
Var N, Body, Last, Item : Integer;
Begin
  N := -1;

  { Directive du preprocesseur }
  If SrcToken.Kind = STK_DIRECTIVE Then
  Begin
    N := SrcNewNode(SNK_C_PREPROC);
    SrcNodes[N].Name := SrcToken.Val;
    CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  (* Bloc compose lacco ... racco *)
  If CppTokIs('{') Then
  Begin
    CppParseStatement := CppParseCompound;
    Exit;
  End;

  { if (expr) stmt [else stmt] }
  If CppTokIsKw('if') Then
  Begin
    N := SrcNewNode(SNK_IF);
    CppConsume;
    If CppTokIs('(') Then CppConsume;
    SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(')') Then CppConsume;
    SrcNodes[N].Right := CppParseStatement;
    If CppTokIsKw('else') Then
    Begin
      CppConsume;
      SrcNodes[N].Extra := CppParseStatement;
    End;
    CppParseStatement := N;
    Exit;
  End;

  { while (expr) stmt }
  If CppTokIsKw('while') Then
  Begin
    N := SrcNewNode(SNK_WHILE);
    CppConsume;
    If CppTokIs('(') Then CppConsume;
    SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(')') Then CppConsume;
    SrcNodes[N].Right := CppParseStatement;
    CppParseStatement := N;
    Exit;
  End;

  { for (init; cond; incr) stmt }
  If CppTokIsKw('for') Then
  Begin
    N := SrcNewNode(SNK_FOR);
    CppConsume;
    If CppTokIs('(') Then CppConsume;
    If Not CppTokIs(';') Then
      SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(';') Then CppConsume;
    If Not CppTokIs(';') Then
      SrcNodes[N].Right := CppParseExpr;
    If CppTokIs(';') Then CppConsume;
    If Not CppTokIs(')') Then
      SrcNodes[N].Extra := CppParseExpr;
    If CppTokIs(')') Then CppConsume;
    Body := CppParseStatement;
    If SrcNodes[N].Extra >= 0 Then
      SrcNodes[SrcNodes[N].Extra].Next := Body
    Else If SrcNodes[N].Right >= 0 Then
      SrcNodes[SrcNodes[N].Right].Next := Body
    Else
      SrcNodes[N].Extra := Body;
    CppParseStatement := N;
    Exit;
  End;

  { do stmt while (expr) ; }
  If CppTokIsKw('do') Then
  Begin
    N := SrcNewNode(SNK_C_DO_WHILE);
    CppConsume;
    SrcNodes[N].Left := CppParseStatement;
    If CppTokIsKw('while') Then CppConsume;
    If CppTokIs('(') Then CppConsume;
    SrcNodes[N].Right := CppParseExpr;
    If CppTokIs(')') Then CppConsume;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  (* switch (expr) lacco case ...: ... racco *)
  If CppTokIsKw('switch') Then
  Begin
    N := SrcNewNode(SNK_C_SWITCH);
    CppConsume;
    If CppTokIs('(') Then CppConsume;
    SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(')') Then CppConsume;
    If CppTokIs('{') Then CppConsume;
    Last := -1;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
    Begin
      If CppTokIsKw('case') Then
      Begin
        Item := SrcNewNode(SNK_C_CASE_ITEM);
        CppConsume;
        SrcNodes[Item].Left := CppParseExpr;
        If CppTokIs(':') Then CppConsume;
        If SrcNodes[N].Right = -1 Then
          SrcNodes[N].Right := Item
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Item;
        Last := Item;
      End
      Else If CppTokIsKw('default') Then
      Begin
        Item := SrcNewNode(SNK_C_DEFAULT_ITEM);
        CppConsume;
        If CppTokIs(':') Then CppConsume;
        If SrcNodes[N].Right = -1 Then
          SrcNodes[N].Right := Item
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Item;
        Last := Item;
      End
      Else
      Begin
        Body := CppParseStatement;
        If (Last >= 0) And (Body >= 0) Then
        Begin
          If SrcNodes[Last].Right = -1 Then
            SrcNodes[Last].Right := Body
          Else
          Begin
            Item := SrcNodes[Last].Right;
            While SrcNodes[Item].Next >= 0 Do
              Item := SrcNodes[Item].Next;
            SrcNodes[Item].Next := Body;
          End;
        End;
      End;
    End;
    If CppTokIs('}') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  (* try lacco ... racco catch (...) lacco ... racco *)
  If CppTokIsKw('try') Then
  Begin
    N := SrcNewNode(SNK_CPP_TRY);
    SrcNodes[N].Name := 'try';
    CppConsume;
    SrcNodes[N].Left := CppParseCompound;
    Last := -1;
    While CppTokIsKw('catch') Do
    Begin
      Item := SrcNewNode(SNK_CPP_CATCH);
      CppConsume;
      If CppTokIs('(') Then
      Begin
        CppConsume;
        SrcNodes[Item].Name := '';
        While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(')')) Do
        Begin
          If SrcNodes[Item].Name <> '' Then
            SrcNodes[Item].Name := SrcNodes[Item].Name + ' ';
          SrcNodes[Item].Name := SrcNodes[Item].Name + SrcToken.Val;
          CppConsume;
        End;
        If CppTokIs(')') Then CppConsume;
      End;
      SrcNodes[Item].Left := CppParseCompound;
      If SrcNodes[N].Right = -1 Then
        SrcNodes[N].Right := Item
      Else If Last >= 0 Then
        SrcNodes[Last].Next := Item;
      Last := Item;
    End;
    CppParseStatement := N;
    Exit;
  End;

  { throw [expr] ; }
  If CppTokIsKw('throw') Then
  Begin
    N := SrcNewNode(SNK_CPP_THROW);
    SrcNodes[N].Name := 'throw';
    CppConsume;
    If Not CppTokIs(';') Then
      SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { break ; }
  If CppTokIsKw('break') Then
  Begin
    N := SrcNewNode(SNK_C_BREAK);
    CppConsume;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { continue ; }
  If CppTokIsKw('continue') Then
  Begin
    N := SrcNewNode(SNK_C_CONTINUE);
    CppConsume;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { return [expr] ; }
  If CppTokIsKw('return') Then
  Begin
    N := SrcNewNode(SNK_C_RETURN);
    CppConsume;
    If Not CppTokIs(';') Then
      SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { goto label ; }
  If CppTokIsKw('goto') Then
  Begin
    N := SrcNewNode(SNK_GOTO);
    CppConsume;
    SrcNodes[N].Name := SrcToken.Val;
    CppConsume;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { delete [[] ] expr ; }
  If CppTokIsKw('delete') Then
  Begin
    N := SrcNewNode(SNK_CPP_DELETE);
    SrcNodes[N].Name := 'delete';
    CppConsume;
    If CppTokIs('[') Then
    Begin
      CppConsume;
      If CppTokIs(']') Then CppConsume;
      SrcNodes[N].Name := 'delete[]';
    End;
    SrcNodes[N].Left := CppParseExpr;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { Declarations locales }
  If CppIsCTypeStart Then
  Begin
    CppParseStatement := CppParseDeclaration;
    Exit;
  End;

  { Instruction vide ; }
  If CppTokIs(';') Then
  Begin
    CppConsume;
    CppParseStatement := -1;
    Exit;
  End;

  { Label  ident : }
  If (SrcToken.Kind = STK_IDENT) Then
  Begin
    N := SrcNewNode(SNK_EXPR_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    CppConsume;
    { Scope resolution :: }
    While CppTokIs('::') Do
    Begin
      SrcNodes[N].Name := SrcNodes[N].Name + '::';
      CppConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + SrcToken.Val;
        CppConsume;
      End;
    End;
    If CppTokIs(':') Then
    Begin
      SrcNodes[N].Kind := SNK_LABEL_DECL;
      CppConsume;
      CppParseStatement := N;
      Exit;
    End;
    { Postfix }
    While (CppTokIs('(')) Or (CppTokIs('[')) Or (CppTokIs('.')) Or
          (CppTokIs('->')) Or (CppTokIs('++')) Or (CppTokIs('--')) Do
    Begin
      If CppTokIs('(') Then
      Begin
        CppConsume;
        Item := SrcNewNode(SNK_EXPR_CALL);
        SrcNodes[Item].Left := N;
        SrcNodes[Item].Name := SrcNodes[N].Name;
        Last := -1;
        If Not CppTokIs(')') Then
        Begin
          SrcNodes[Item].Right := CppParseAssign;
          Last := SrcNodes[Item].Right;
          While CppTokIs(',') Do
          Begin
            CppConsume;
            SrcNodes[Last].Next := CppParseAssign;
            Last := SrcNodes[Last].Next;
          End;
        End;
        If CppTokIs(')') Then CppConsume;
        N := Item;
      End
      Else If CppTokIs('[') Then
      Begin
        CppConsume;
        Item := SrcNewNode(SNK_EXPR_INDEX);
        SrcNodes[Item].Left  := N;
        SrcNodes[Item].Right := CppParseExpr;
        If CppTokIs(']') Then CppConsume;
        N := Item;
      End
      Else If CppTokIs('.') Or CppTokIs('->') Then
      Begin
        CppConsume;
        Item := SrcNewNode(SNK_EXPR_FIELD);
        SrcNodes[Item].Left := N;
        SrcNodes[Item].Name := SrcToken.Val;
        CppConsume;
        N := Item;
      End
      Else If CppTokIs('++') Or CppTokIs('--') Then
      Begin
        Item := SrcNewNode(SNK_EXPR_UNOP);
        SrcNodes[Item].Name := SrcToken.Val + '_post';
        SrcNodes[Item].Left := N;
        CppConsume;
        N := Item;
      End;
    End;
    { Affectation }
    If CppTokIs('=') Or CppTokIs('+=') Or CppTokIs('-=') Or
       CppTokIs('*=') Or CppTokIs('/=') Or CppTokIs('%=') Or
       CppTokIs('&=') Or CppTokIs('|=') Or CppTokIs('^=') Or
       CppTokIs('<<=') Or CppTokIs('>>=') Then
    Begin
      Item := SrcNewNode(SNK_ASSIGN);
      SrcNodes[Item].Name  := SrcToken.Val;
      SrcNodes[Item].Left  := N;
      CppConsume;
      SrcNodes[Item].Right := CppParseExpr;
      N := Item;
    End;
    If CppTokIs(';') Then CppConsume;
    CppParseStatement := N;
    Exit;
  End;

  { Expression-instruction }
  N := CppParseExpr;
  If CppTokIs(';') Then CppConsume;
  CppParseStatement := N;
End;

{ ---- CppParseDeclaration : declaration C++ ------------------- }

Function CppParseDeclaration : Integer;
Var TypeStr : TString;
    N, Last, VN : Integer;
    IsTypedef : Boolean;
    TagKind : TSrcNodeKind;
Begin
  IsTypedef := CppTokIsKw('typedef');
  TagKind := SNK_NONE;

  If CppTokIsKw('struct') Or CppTokIsKw('union') Or CppTokIsKw('enum') Or
     CppTokIsKw('class') Then
  Begin
    If CppTokIsKw('struct') Then TagKind := SNK_C_STRUCT_DECL
    Else If CppTokIsKw('union') Then TagKind := SNK_C_UNION_DECL
    Else If CppTokIsKw('enum') Then TagKind := SNK_C_ENUM_DECL
    Else TagKind := SNK_CPP_CLASS_DECL;
  End;

  TypeStr := CppParseTypeSpec;

  (* struct/union/enum/class avec corps lacco ... racco *)
  If (TagKind <> SNK_NONE) And CppTokIs('{') Then
  Begin
    N := SrcNewNode(TagKind);
    SrcNodes[N].Name := TypeStr;
    CppConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
      CppConsume;
    If CppTokIs('}') Then CppConsume;
    If (SrcToken.Kind = STK_IDENT) Then
    Begin
      SrcNodes[N].Name := SrcNodes[N].Name + ' ' + SrcToken.Val;
      CppConsume;
    End;
    If CppTokIs(';') Then CppConsume;
    CppParseDeclaration := N;
    Exit;
  End;

  If IsTypedef Then
  Begin
    N := SrcNewNode(SNK_C_TYPEDEF);
    SrcNodes[N].Name := TypeStr;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(';')) Do
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
    End;
    If CppTokIs(';') Then CppConsume;
    CppParseDeclaration := N;
    Exit;
  End;

  { Variable ou liste de variables }
  N := -1;
  Last := -1;
  While True Do
  Begin
    While CppTokIs('*') Or CppTokIs('&') Do CppConsume;
    If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
    Begin
      VN := SrcNewNode(SNK_VAR_DECL);
      SrcNodes[VN].Name := SrcToken.Val;
      CppConsume;
      While CppTokIs('[') Do
      Begin
        CppConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(']')) Do
          CppConsume;
        If CppTokIs(']') Then CppConsume;
      End;
      If CppTokIs('=') Then
      Begin
        CppConsume;
        If CppTokIs('{') Then
        Begin
          CppConsume;
          While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
            CppConsume;
          If CppTokIs('}') Then CppConsume;
        End
        Else
          SrcNodes[VN].Left := CppParseAssign;
      End;
      If N = -1 Then
        N := VN
      Else If Last >= 0 Then
        SrcNodes[Last].Next := VN;
      Last := VN;
    End
    Else
      Break;
    If CppTokIs(',') Then
      CppConsume
    Else
      Break;
  End;
  If CppTokIs(';') Then CppConsume;
  CppParseDeclaration := N;
End;

{ ---- CppParseClassBody : corps d une classe C++ -------------- }

Procedure CppParseClassBody(ClassNode : Integer);
Var N, Last : Integer;
Begin
  CppExpect('{');
  Last := -1;
  While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
  Begin
    { Specificateurs d acces public:/private:/protected: }
    If CppTokIsKw('public') Or CppTokIsKw('private') Or
       CppTokIsKw('protected') Then
    Begin
      N := SrcNewNode(SNK_CPP_ACCESS_SPEC);
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
      If CppTokIs(':') Then CppConsume;
      If SrcNodes[ClassNode].Left = -1 Then
        SrcNodes[ClassNode].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End
    Else
    Begin
      N := CppParseTopLevel;
      If N >= 0 Then
      Begin
        If SrcNodes[ClassNode].Left = -1 Then
          SrcNodes[ClassNode].Left := N
        Else If Last >= 0 Then
          SrcNodes[Last].Next := N;
        Last := N;
      End;
    End;
  End;
  If CppTokIs('}') Then CppConsume;
End;

{ ---- CppParseTopLevel : declaration top-level C++ ------------ }

Function CppParseTopLevel : Integer;
Var N : Integer;
    TypeStr, FuncName : TString;
    TagKind : TSrcNodeKind;
Begin
  N := -1;
  TagKind := SNK_NONE;

  { Directive preprocesseur }
  If SrcToken.Kind = STK_DIRECTIVE Then
  Begin
    N := SrcNewNode(SNK_C_PREPROC);
    SrcNodes[N].Name := SrcToken.Val;
    If (Length(SrcToken.Val) >= 8) And
       (Copy(SrcToken.Val, 1, 8) = '#include') Then
      SrcNodes[N].Kind := SNK_C_INCLUDE
    Else If (Length(SrcToken.Val) >= 7) And
            (Copy(SrcToken.Val, 1, 7) = '#define') Then
      SrcNodes[N].Kind := SNK_C_DEFINE;
    CppConsume;
    CppParseTopLevel := N;
    Exit;
  End;

  { using namespace ... ; ou using ... ; }
  If CppTokIsKw('using') Then
  Begin
    N := SrcNewNode(SNK_CPP_USING);
    SrcNodes[N].Name := '';
    CppConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(';')) Do
    Begin
      If SrcNodes[N].Name <> '' Then
        SrcNodes[N].Name := SrcNodes[N].Name + ' ';
      SrcNodes[N].Name := SrcNodes[N].Name + SrcToken.Val;
      CppConsume;
    End;
    If CppTokIs(';') Then CppConsume;
    CppParseTopLevel := N;
    Exit;
  End;

  (* namespace ident lacco ... racco *)
  If CppTokIsKw('namespace') Then
  Begin
    N := SrcNewNode(SNK_CPP_NAMESPACE);
    CppConsume;
    If SrcToken.Kind = STK_IDENT Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
    End
    Else
      SrcNodes[N].Name := '<anonymous>';
    If CppTokIs('{') Then
    Begin
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
      Begin
        SrcNodes[N].Left := CppParseTopLevel;
      End;
      If CppTokIs('}') Then CppConsume;
    End;
    CppParseTopLevel := N;
    Exit;
  End;

  { template < ... > }
  If CppTokIsKw('template') Then
  Begin
    N := SrcNewNode(SNK_CPP_TEMPLATE);
    SrcNodes[N].Name := 'template';
    CppConsume;
    If CppTokIs('<') Then
    Begin
      SrcNodes[N].Name := 'template<';
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('>')) Do
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + SrcToken.Val;
        CppConsume;
      End;
      If CppTokIs('>') Then
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + '>';
        CppConsume;
      End;
    End;
    SrcNodes[N].Left := CppParseTopLevel;
    CppParseTopLevel := N;
    Exit;
  End;

  (* extern "C" lacco ... racco *)
  If CppTokIsKw('extern') And (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    CppConsume;
    If (SrcToken.Kind = STK_STRING) And (SrcToken.Val = 'C') Then
    Begin
      CppConsume;
      If CppTokIs('{') Then
      Begin
        N := SrcNewNode(SNK_CPP_NAMESPACE);
        SrcNodes[N].Name := 'extern "C"';
        CppConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
          SrcNodes[N].Left := CppParseTopLevel;
        If CppTokIs('}') Then CppConsume;
        CppParseTopLevel := N;
        Exit;
      End
      Else
      Begin
        { extern "C" single declaration }
        CppParseTopLevel := CppParseTopLevel;
        Exit;
      End;
    End;
    { extern was a storage class - rewind mentally: treat as type start }
  End;

  { Detecter struct/union/enum/class }
  If CppTokIsKw('struct') Then TagKind := SNK_C_STRUCT_DECL
  Else If CppTokIsKw('union') Then TagKind := SNK_C_UNION_DECL
  Else If CppTokIsKw('enum') Then TagKind := SNK_C_ENUM_DECL
  Else If CppTokIsKw('class') Then TagKind := SNK_CPP_CLASS_DECL;

  TypeStr := CppParseTypeSpec;

  { class/struct avec corps et heritage }
  If (TagKind = SNK_CPP_CLASS_DECL) Or (TagKind = SNK_C_STRUCT_DECL) Then
  Begin
    { Heritage : public/private/protected Base }
    If CppTokIs(':') Then
    Begin
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('{')) Do
        CppConsume;
    End;
    If CppTokIs('{') Then
    Begin
      N := SrcNewNode(TagKind);
      SrcNodes[N].Name := TypeStr;
      CppParseClassBody(N);
      If (SrcToken.Kind = STK_IDENT) Then
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + ' ' + SrcToken.Val;
        CppConsume;
      End;
      If CppTokIs(';') Then CppConsume;
      CppParseTopLevel := N;
      Exit;
    End;
  End;

  { union/enum avec corps }
  If (TagKind = SNK_C_UNION_DECL) Or (TagKind = SNK_C_ENUM_DECL) Then
  Begin
    If CppTokIs('{') Then
    Begin
      N := SrcNewNode(TagKind);
      SrcNodes[N].Name := TypeStr;
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
        CppConsume;
      If CppTokIs('}') Then CppConsume;
      If (SrcToken.Kind = STK_IDENT) Then
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + ' ' + SrcToken.Val;
        CppConsume;
      End;
      If CppTokIs(';') Then CppConsume;
      CppParseTopLevel := N;
      Exit;
    End;
  End;

  { typedef }
  If (Length(TypeStr) >= 7) And (Copy(TypeStr, 1, 7) = 'typedef') Then
  Begin
    N := SrcNewNode(SNK_C_TYPEDEF);
    SrcNodes[N].Name := TypeStr;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(';')) Do
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CppConsume;
    End;
    If CppTokIs(';') Then CppConsume;
    CppParseTopLevel := N;
    Exit;
  End;

  { Nom de la fonction ou variable }
  FuncName := '';
  While CppTokIs('*') Or CppTokIs('&') Do CppConsume;
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    FuncName := SrcToken.Val;
    CppConsume;
    { Scope resolution Class::method }
    While CppTokIs('::') Do
    Begin
      FuncName := FuncName + '::';
      CppConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        FuncName := FuncName + SrcToken.Val;
        CppConsume;
      End;
      { Operateur surcharge }
      If CppTokIsKw('operator') Then
      Begin
        FuncName := FuncName + 'operator';
        CppConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('(')) Do
        Begin
          FuncName := FuncName + SrcToken.Val;
          CppConsume;
        End;
      End;
    End;
  End;

  (* Fonction : nom ( ... ) [const] [noexcept] [override] lacco ... racco *)
  If CppTokIs('(') Then
  Begin
    N := SrcNewNode(SNK_FUNC_DECL);
    SrcNodes[N].Name := FuncName;
    CppConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(')')) Do
      CppConsume;
    If CppTokIs(')') Then CppConsume;
    { Qualificateurs de methode }
    While CppTokIsKw('const') Or CppTokIsKw('noexcept') Or
          CppTokIsKw('override') Or CppTokIsKw('final') Do
      CppConsume;
    { Initializer list : init1(val), init2(val) }
    If CppTokIs(':') Then
    Begin
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('{')) And
            (Not CppTokIs(';')) Do
        CppConsume;
    End;
    { Corps ou prototype }
    If CppTokIs('{') Then
      SrcNodes[N].Left := CppParseCompound
    Else If CppTokIs(';') Then
      CppConsume;
    { Pure virtual = 0 }
    If CppTokIs('=') Then
    Begin
      CppConsume;
      If CppTokIs('0') Or (SrcToken.Val = '0') Then CppConsume;
      If CppTokIs(';') Then CppConsume;
    End;
    CppParseTopLevel := N;
    Exit;
  End;

  { Declaration de variable globale }
  N := SrcNewNode(SNK_VAR_DECL);
  SrcNodes[N].Name := FuncName;
  While CppTokIs('[') Do
  Begin
    CppConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs(']')) Do
      CppConsume;
    If CppTokIs(']') Then CppConsume;
  End;
  If CppTokIs('=') Then
  Begin
    CppConsume;
    If CppTokIs('{') Then
    Begin
      CppConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
        CppConsume;
      If CppTokIs('}') Then CppConsume;
    End
    Else
      SrcNodes[N].Left := CppParseAssign;
  End;
  While CppTokIs(',') Do
  Begin
    CppConsume;
    While CppTokIs('*') Or CppTokIs('&') Do CppConsume;
    If (SrcToken.Kind = STK_IDENT) Then CppConsume;
    If CppTokIs('=') Then
    Begin
      CppConsume;
      If CppTokIs('{') Then
      Begin
        CppConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CppTokIs('}')) Do
          CppConsume;
        If CppTokIs('}') Then CppConsume;
      End;
    End;
  End;
  If CppTokIs(';') Then CppConsume;
  CppParseTopLevel := N;
End;

{ ---- CppParseTranslationUnit : unite de traduction C++ ------- }

Function CppParseTranslationUnit : Integer;
Var Root, N, Last : Integer;
Begin
  CppConsume; { lire le premier token }
  Root := SrcNewNode(SNK_CPP_TRANSLATION_UNIT);
  SrcNodes[Root].Name := 'CPP_TU';
  Last := -1;
  While SrcToken.Kind <> STK_EOF Do
  Begin
    N := CppParseTopLevel;
    If N >= 0 Then
    Begin
      If SrcNodes[Root].Left = -1 Then
        SrcNodes[Root].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End;
  End;
  CppParseTranslationUnit := Root;
End;

{ ---- Fin TODO 27 --------------------------------------------- }

{ ============================================================
  TODO 28 - LEXEUR ET PARSEUR C# [IMPLEMENTE]
  ============================================================ }

{ ---- IsCSharpKeyword : reconnaissance des mots-cles C# ------ }

Function IsCSharpKeyword(Const W : TString) : Boolean;
Begin
  IsCSharpKeyword :=
    (W = 'abstract')  Or (W = 'as')         Or (W = 'base')      Or
    (W = 'bool')      Or (W = 'break')      Or (W = 'byte')      Or
    (W = 'case')      Or (W = 'catch')      Or (W = 'char')      Or
    (W = 'checked')   Or (W = 'class')      Or (W = 'const')     Or
    (W = 'continue')  Or (W = 'decimal')    Or (W = 'default')   Or
    (W = 'delegate')  Or (W = 'do')         Or (W = 'double')    Or
    (W = 'else')      Or (W = 'enum')       Or (W = 'event')     Or
    (W = 'explicit')  Or (W = 'extern')     Or (W = 'false')     Or
    (W = 'finally')   Or (W = 'fixed')      Or (W = 'float')     Or
    (W = 'for')       Or (W = 'foreach')    Or (W = 'goto')      Or
    (W = 'if')        Or (W = 'implicit')   Or (W = 'in')        Or
    (W = 'int')       Or (W = 'interface')  Or (W = 'internal')  Or
    (W = 'is')        Or (W = 'lock')       Or (W = 'long')      Or
    (W = 'namespace') Or (W = 'new')        Or (W = 'null')      Or
    (W = 'object')    Or (W = 'operator')   Or (W = 'out')       Or
    (W = 'override')  Or (W = 'params')     Or (W = 'private')   Or
    (W = 'protected') Or (W = 'public')     Or (W = 'readonly')  Or
    (W = 'ref')       Or (W = 'return')     Or (W = 'sbyte')     Or
    (W = 'sealed')    Or (W = 'short')      Or (W = 'sizeof')    Or
    (W = 'stackalloc') Or (W = 'static')   Or (W = 'string')    Or
    (W = 'struct')    Or (W = 'switch')     Or (W = 'this')      Or
    (W = 'throw')     Or (W = 'true')       Or (W = 'try')       Or
    (W = 'typeof')    Or (W = 'uint')       Or (W = 'ulong')     Or
    (W = 'unchecked') Or (W = 'unsafe')     Or (W = 'ushort')    Or
    (W = 'using')     Or (W = 'virtual')    Or (W = 'void')      Or
    (W = 'volatile')  Or (W = 'while')      Or
    { mots-cles contextuels }
    (W = 'add')       Or (W = 'alias')      Or (W = 'ascending') Or
    (W = 'async')     Or (W = 'await')      Or (W = 'by')        Or
    (W = 'descending') Or (W = 'dynamic')   Or (W = 'equals')    Or
    (W = 'from')      Or (W = 'get')        Or (W = 'global')    Or
    (W = 'group')     Or (W = 'into')       Or (W = 'join')      Or
    (W = 'let')       Or (W = 'nameof')     Or (W = 'on')        Or
    (W = 'orderby')   Or (W = 'partial')    Or (W = 'remove')    Or
    (W = 'select')    Or (W = 'set')        Or (W = 'value')     Or
    (W = 'var')       Or (W = 'when')       Or (W = 'where')     Or
    (W = 'yield');
End;

{ ---- CSharpLexScanIdent : scanner un identificateur ou mot-cle C# }

Procedure CSharpLexScanIdent;
Var S : TString;
Begin
  S := '';
  While (SrcColNo <= Length(SrcLine)) And
        IsIdentCont(SrcLine[SrcColNo]) Do
  Begin
    If Length(S) < 255 Then
      S := S + SrcLine[SrcColNo];
    Inc(SrcColNo);
  End;
  If IsCSharpKeyword(S) Then
    SrcToken.Kind := STK_KEYWORD
  Else
    SrcToken.Kind := STK_IDENT;
  SrcToken.Val := S;
End;

{ ---- CSharpLexInit : initialiser le lexeur C# ---------------- }

Procedure CSharpLexInit;
Begin
  SrcLineNo    := 0;
  SrcColNo     := 1;
  SrcEOF       := False;
  SrcLine      := '';
  SrcTokenCount := 0;
  SrcTotalLines := 0;
  SrcToken.Kind     := STK_EOF;
  SrcToken.Val      := '';
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;
  SrcToken.Line     := 0;
  SrcToken.Col      := 0;
  SrcLexNextLine;
End;

{ ---- CSharpLexNextToken : obtenir le prochain token C# ------- }

Procedure CSharpLexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
  S        : TString;
  Found    : Boolean;
Begin
  SrcToken.IntVal   := 0;
  SrcToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    While (Not SrcEOF) And (SrcColNo > Length(SrcLine)) Do
      SrcLexNextLine;

    If SrcEOF Then
    Begin
      SrcToken.Kind := STK_EOF;
      SrcToken.Val  := '';
      SrcToken.Line := SrcLineNo;
      SrcToken.Col  := SrcColNo;
      Scanning := False;
      Break;
    End;

    SrcToken.Line := SrcLineNo;
    SrcToken.Col  := SrcColNo;
    Ch := SrcLine[SrcColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(SrcColNo);
      Continue;
    End;

    Scanning := False;

    { Commentaires // }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '/') Then
    Begin
      SrcColNo := Length(SrcLine) + 1;
      Scanning := True;
      Continue;
    End;

    { Commentaires /* ... */ }
    If (Ch = '/') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '*') Then
    Begin
      Inc(SrcColNo, 2);
      Found := False;
      While (Not SrcEOF) And (Not Found) Do
      Begin
        While (SrcColNo <= Length(SrcLine)) And (Not Found) Do
        Begin
          If (SrcLine[SrcColNo] = '*') And
             (SrcColNo < Length(SrcLine)) And
             (SrcLine[SrcColNo + 1] = '/') Then
          Begin
            Inc(SrcColNo, 2);
            Found := True;
          End
          Else
            Inc(SrcColNo);
        End;
        If Not Found Then
          SrcLexNextLine;
      End;
      Scanning := True;
      Continue;
    End;

    { Directives preprocesseur # }
    If Ch = '#' Then
    Begin
      SrcToken.Kind := STK_DIRECTIVE;
      S := '';
      While SrcColNo <= Length(SrcLine) Do
      Begin
        If Length(S) < 255 Then
          S := S + SrcLine[SrcColNo];
        Inc(SrcColNo);
      End;
      SrcToken.Val := S;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Identificateurs et mots-cles }
    If IsIdentStart(Ch) Or (Ch = '@') Then
    Begin
      If Ch = '@' Then Inc(SrcColNo); { verbatim identifier }
      CSharpLexScanIdent;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Nombres }
    If IsDigit(Ch) Then
    Begin
      CLexScanNumber;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines de caracteres "..." }
    If (Ch = '"') Then
    Begin
      CLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines verbatim @"..." }
    If (Ch = '@') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '"') Then
    Begin
      Inc(SrcColNo);
      CLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Chaines interpolees $"..." }
    If (Ch = '$') And (SrcColNo < Length(SrcLine)) And
       (SrcLine[SrcColNo + 1] = '"') Then
    Begin
      Inc(SrcColNo);
      CLexScanString;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Caracteres '...' }
    If (Ch = '''') Then
    Begin
      CLexScanChar;
      Inc(SrcTokenCount);
      Exit;
    End;

    { Operateurs multi-caracteres }
    If SrcColNo < Length(SrcLine) Then
    Begin
      S := Ch + SrcLine[SrcColNo + 1];
      If (S = '==') Or (S = '!=') Or (S = '<=') Or (S = '>=') Or
         (S = '&&') Or (S = '||') Or (S = '++') Or (S = '--') Or
         (S = '+=') Or (S = '-=') Or (S = '*=') Or (S = '/=') Or
         (S = '%=') Or (S = '&=') Or (S = '|=') Or (S = '^=') Or
         (S = '<<') Or (S = '>>') Or (S = '??') Or (S = '=>') Then
      Begin
        SrcToken.Kind := STK_OP;
        SrcToken.Val  := S;
        Inc(SrcColNo, 2);
        Inc(SrcTokenCount);
        Exit;
      End;
      { Operateur ?.  (null-conditional) }
      If S = '?.' Then
      Begin
        SrcToken.Kind := STK_OP;
        SrcToken.Val  := S;
        Inc(SrcColNo, 2);
        Inc(SrcTokenCount);
        Exit;
      End;
    End;

    { Operateurs simples }
    SrcToken.Kind := STK_OP;
    SrcToken.Val  := Ch;
    Inc(SrcColNo);
    Inc(SrcTokenCount);
  End;
End;

{ ---- Helpers de parsing C# ---------------------------------- }

Var
  CSharpTok : TSourceToken; { copy locale pour look-ahead C# }

Procedure CSharpConsume;
Begin
  CSharpLexNextToken;
End;

Function CSharpTokIs(Const V : TString) : Boolean;
Begin
  CSharpTokIs := (SrcToken.Val = V);
End;

Function CSharpTokKind : TSourceTokenKind;
Begin
  CSharpTokKind := SrcToken.Kind;
End;

Function CSharpKwIs(Const V : TString) : Boolean;
Begin
  CSharpKwIs := (SrcToken.Kind = STK_KEYWORD) And (SrcToken.Val = V);
End;

Procedure CSharpExpect(Const V : TString);
Begin
  If SrcToken.Val <> V Then
    WriteLn('CODEQL: C# attendu ''', V, ''' a la ligne ', SrcToken.Line,
            ':', SrcToken.Col, ' (lu: ''', SrcToken.Val, ''')');
  CSharpConsume;
End;

{ ---- Forward declarations C# parser ------------------------- }

Function CSharpParseExpr : Integer; Forward;
Function CSharpParseStatement : Integer; Forward;
Function CSharpParseBlock : Integer; Forward;
Function CSharpParseTypeDecl : Integer; Forward;
Function CSharpParseTopLevel : Integer; Forward;

{ ---- CSharpParsePrimary : expression primaire C# ------------- }

Function CSharpParsePrimary : Integer;
Var N : Integer;
Begin
  N := -1;
  If (SrcToken.Kind = STK_INTEGER) Or (SrcToken.Kind = STK_FLOAT) Or
     (SrcToken.Kind = STK_STRING) Then
  Begin
    If SrcToken.Kind = STK_INTEGER Then
      N := SrcNewNode(SNK_EXPR_INT)
    Else If SrcToken.Kind = STK_FLOAT Then
      N := SrcNewNode(SNK_EXPR_FLOAT)
    Else
      N := SrcNewNode(SNK_EXPR_STRING);
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
  End
  Else If CSharpKwIs('true') Or CSharpKwIs('false') Or CSharpKwIs('null') Then
  Begin
    N := SrcNewNode(SNK_EXPR_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
  End
  Else If CSharpKwIs('new') Then
  Begin
    N := SrcNewNode(SNK_CALL);
    SrcNodes[N].Name := 'new';
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    { Type name }
    If SrcToken.Kind = STK_IDENT Then
    Begin
      SrcNodes[N].Name := 'new ' + SrcToken.Val;
      CSharpConsume;
    End;
    { Generic args or parens or braces }
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    If CSharpTokIs('{') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
        CSharpConsume;
      If CSharpTokIs('}') Then CSharpConsume;
    End;
  End
  Else If CSharpKwIs('typeof') Or CSharpKwIs('sizeof') Or
          CSharpKwIs('nameof') Then
  Begin
    N := SrcNewNode(SNK_CALL);
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
  End
  Else If CSharpTokIs('(') Then
  Begin
    CSharpConsume;
    N := CSharpParseExpr;
    If CSharpTokIs(')') Then CSharpConsume;
  End
  Else If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    N := SrcNewNode(SNK_EXPR_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    { Acces membre . et appels }
    While CSharpTokIs('.') Or CSharpTokIs('(') Or CSharpTokIs('[') Or
          CSharpTokIs('?.') Do
    Begin
      If CSharpTokIs('.') Or CSharpTokIs('?.') Then
      Begin
        CSharpConsume;
        If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
        Begin
          SrcNodes[N].Name := SrcNodes[N].Name + '.' + SrcToken.Val;
          CSharpConsume;
        End;
      End
      Else If CSharpTokIs('(') Then
      Begin
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        Begin
          CSharpParseExpr;
          If CSharpTokIs(',') Then CSharpConsume;
        End;
        If CSharpTokIs(')') Then CSharpConsume;
      End
      Else If CSharpTokIs('[') Then
      Begin
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(']')) Do
          CSharpConsume;
        If CSharpTokIs(']') Then CSharpConsume;
      End;
    End;
  End
  Else
  Begin
    { Token inconnu, avancer }
    N := SrcNewNode(SNK_EXPR_IDENT);
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
  End;
  CSharpParsePrimary := N;
End;

{ ---- CSharpParseUnary : expression unaire C# ----------------- }

Function CSharpParseUnary : Integer;
Var N : Integer;
Begin
  If CSharpTokIs('!') Or CSharpTokIs('-') Or CSharpTokIs('~') Or
     CSharpTokIs('++') Or CSharpTokIs('--') Or
     CSharpKwIs('await') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_AWAIT);
    If CSharpKwIs('await') Then
      SrcNodes[N].Kind := SNK_CSHARP_AWAIT
    Else
      SrcNodes[N].Kind := SNK_EXPR_UNOP;
    SrcNodes[N].Name := SrcToken.Val;
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    SrcNodes[N].Left := CSharpParseUnary;
    CSharpParseUnary := N;
  End
  Else
    CSharpParseUnary := CSharpParsePrimary;
End;

{ ---- CSharpParseBinary : expression binaire C# (precedence) - }

Function CSharpParseBinary(MinPrec : Integer) : Integer;
Var N, Op, Right : Integer;
    Prec         : Integer;
Begin
  N := CSharpParseUnary;
  While True Do
  Begin
    Prec := 0;
    If CSharpTokIs('*') Or CSharpTokIs('/') Or CSharpTokIs('%') Then
      Prec := 12
    Else If CSharpTokIs('+') Or CSharpTokIs('-') Then
      Prec := 11
    Else If CSharpTokIs('<<') Or CSharpTokIs('>>') Then
      Prec := 10
    Else If CSharpTokIs('<') Or CSharpTokIs('>') Or
            CSharpTokIs('<=') Or CSharpTokIs('>=') Or
            CSharpKwIs('is') Or CSharpKwIs('as') Then
      Prec := 9
    Else If CSharpTokIs('==') Or CSharpTokIs('!=') Then
      Prec := 8
    Else If CSharpTokIs('&') And (Not CSharpTokIs('&&')) Then
      Prec := 7
    Else If CSharpTokIs('^') Then
      Prec := 6
    Else If CSharpTokIs('|') And (Not CSharpTokIs('||')) Then
      Prec := 5
    Else If CSharpTokIs('&&') Then
      Prec := 4
    Else If CSharpTokIs('||') Then
      Prec := 3
    Else If CSharpTokIs('??') Then
      Prec := 2;

    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    Op := SrcNewNode(SNK_EXPR_BINOP);
    SrcNodes[Op].Name := SrcToken.Val;
    SrcNodes[Op].Line := SrcToken.Line;
    SrcNodes[Op].Col  := SrcToken.Col;
    CSharpConsume;
    Right := CSharpParseBinary(Prec + 1);
    SrcNodes[Op].Left  := N;
    SrcNodes[Op].Right := Right;
    N := Op;
  End;
  CSharpParseBinary := N;
End;

{ ---- CSharpParseAssign : expression d'assignation C# -------- }

Function CSharpParseAssign : Integer;
Var N, Op : Integer;
Begin
  N := CSharpParseBinary(1);
  If CSharpTokIs('=') Or CSharpTokIs('+=') Or CSharpTokIs('-=') Or
     CSharpTokIs('*=') Or CSharpTokIs('/=') Or CSharpTokIs('%=') Or
     CSharpTokIs('&=') Or CSharpTokIs('|=') Or CSharpTokIs('^=') Then
  Begin
    Op := SrcNewNode(SNK_ASSIGN);
    SrcNodes[Op].Name := SrcToken.Val;
    SrcNodes[Op].Line := SrcToken.Line;
    SrcNodes[Op].Col  := SrcToken.Col;
    CSharpConsume;
    SrcNodes[Op].Left  := N;
    SrcNodes[Op].Right := CSharpParseAssign;
    N := Op;
  End;
  CSharpParseAssign := N;
End;

{ ---- CSharpParseExpr : expression C# complete ---------------- }

Function CSharpParseExpr : Integer;
Begin
  CSharpParseExpr := CSharpParseAssign;
End;

{ ---- CSharpParseBlock : bloc d instructions C# --------------- }

Function CSharpParseBlock : Integer;
Var Root, N, Last : Integer;
Begin
  Root := SrcNewNode(SNK_BLOCK);
  SrcNodes[Root].Line := SrcToken.Line;
  SrcNodes[Root].Col  := SrcToken.Col;
  If CSharpTokIs('{') Then CSharpConsume;
  Last := -1;
  While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
  Begin
    N := CSharpParseStatement;
    If N >= 0 Then
    Begin
      If SrcNodes[Root].Left = -1 Then
        SrcNodes[Root].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End;
  End;
  If CSharpTokIs('}') Then CSharpConsume;
  CSharpParseBlock := Root;
End;

{ ---- CSharpParseStatement : instruction C# ------------------- }

Function CSharpParseStatement : Integer;
Var N : Integer;
Begin
  N := -1;

  { Bloc }
  If CSharpTokIs('{') Then
  Begin
    N := CSharpParseBlock;
  End
  { if }
  Else If CSharpKwIs('if') Then
  Begin
    N := SrcNewNode(SNK_IF);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Left := CSharpParseExpr;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    SrcNodes[N].Right := CSharpParseStatement;
    If CSharpKwIs('else') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Extra := CSharpParseStatement;
    End;
  End
  { while }
  Else If CSharpKwIs('while') Then
  Begin
    N := SrcNewNode(SNK_WHILE);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Left := CSharpParseExpr;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    SrcNodes[N].Right := CSharpParseStatement;
  End
  { for }
  Else If CSharpKwIs('for') Then
  Begin
    N := SrcNewNode(SNK_FOR);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    SrcNodes[N].Right := CSharpParseStatement;
  End
  { foreach }
  Else If CSharpKwIs('foreach') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_FOREACH);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    SrcNodes[N].Right := CSharpParseStatement;
  End
  { do...while }
  Else If CSharpKwIs('do') Then
  Begin
    N := SrcNewNode(SNK_C_DO_WHILE);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    SrcNodes[N].Right := CSharpParseStatement;
    If CSharpKwIs('while') Then
    Begin
      CSharpConsume;
      If CSharpTokIs('(') Then
      Begin
        CSharpConsume;
        SrcNodes[N].Left := CSharpParseExpr;
        If CSharpTokIs(')') Then CSharpConsume;
      End;
    End;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  { switch }
  Else If CSharpKwIs('switch') Then
  Begin
    N := SrcNewNode(SNK_C_SWITCH);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Left := CSharpParseExpr;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    If CSharpTokIs('{') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
        CSharpConsume;
      If CSharpTokIs('}') Then CSharpConsume;
    End;
  End
  { return }
  Else If CSharpKwIs('return') Then
  Begin
    N := SrcNewNode(SNK_C_RETURN);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If Not CSharpTokIs(';') Then
      SrcNodes[N].Left := CSharpParseExpr;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  { break / continue }
  Else If CSharpKwIs('break') Or CSharpKwIs('continue') Then
  Begin
    If CSharpKwIs('break') Then
      N := SrcNewNode(SNK_C_BREAK)
    Else
      N := SrcNewNode(SNK_C_CONTINUE);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  { throw }
  Else If CSharpKwIs('throw') Then
  Begin
    N := SrcNewNode(SNK_CPP_THROW);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If Not CSharpTokIs(';') Then
      SrcNodes[N].Left := CSharpParseExpr;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  { try ... catch ... finally }
  Else If CSharpKwIs('try') Then
  Begin
    N := SrcNewNode(SNK_CPP_TRY);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    SrcNodes[N].Left := CSharpParseBlock;
    If CSharpKwIs('catch') Then
    Begin
      CSharpConsume;
      If CSharpTokIs('(') Then
      Begin
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
          CSharpConsume;
        If CSharpTokIs(')') Then CSharpConsume;
      End;
      SrcNodes[N].Right := CSharpParseBlock;
    End;
    If CSharpKwIs('finally') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Extra := CSharpParseBlock;
    End;
  End
  { lock }
  Else If CSharpKwIs('lock') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_LOCK);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      SrcNodes[N].Left := CSharpParseExpr;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    SrcNodes[N].Right := CSharpParseStatement;
  End
  { using (statement) }
  Else If CSharpKwIs('using') And
    (SrcColNo <= Length(SrcLine)) And
    (SrcLine[SrcColNo] <> ' ') Then
  Begin
    { Could be using statement or using directive - check for ( }
    N := SrcNewNode(SNK_CSHARP_USING);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
      SrcNodes[N].Right := CSharpParseStatement;
    End
    Else
    Begin
      { using directive at statement level }
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) Do
        CSharpConsume;
      If CSharpTokIs(';') Then CSharpConsume;
    End;
  End
  { yield return / yield break }
  Else If CSharpKwIs('yield') Then
  Begin
    N := SrcNewNode(SNK_C_RETURN);
    SrcNodes[N].Name := 'yield';
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    If CSharpKwIs('return') Then
    Begin
      CSharpConsume;
      If Not CSharpTokIs(';') Then
        SrcNodes[N].Left := CSharpParseExpr;
    End
    Else If CSharpKwIs('break') Then
      CSharpConsume;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  { Expression statement }
  Else
  Begin
    N := CSharpParseExpr;
    If CSharpTokIs(';') Then CSharpConsume;
  End;
  CSharpParseStatement := N;
End;

{ ---- CSharpSkipAttributes : sauter les attributs [xxx] ------- }

Procedure CSharpSkipAttributes;
Begin
  While CSharpTokIs('[') Do
  Begin
    CSharpConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(']')) Do
      CSharpConsume;
    If CSharpTokIs(']') Then CSharpConsume;
  End;
End;

{ ---- CSharpSkipModifiers : sauter les modificateurs ---------- }

Procedure CSharpSkipModifiers;
Begin
  While CSharpKwIs('public') Or CSharpKwIs('private') Or
        CSharpKwIs('protected') Or CSharpKwIs('internal') Or
        CSharpKwIs('static') Or CSharpKwIs('virtual') Or
        CSharpKwIs('override') Or CSharpKwIs('abstract') Or
        CSharpKwIs('sealed') Or CSharpKwIs('new') Or
        CSharpKwIs('readonly') Or CSharpKwIs('volatile') Or
        CSharpKwIs('extern') Or CSharpKwIs('unsafe') Or
        CSharpKwIs('async') Or CSharpKwIs('partial') Do
    CSharpConsume;
End;

{ ---- CSharpSkipGenericArgs : sauter <T, U, ...> -------------- }

Procedure CSharpSkipGenericArgs;
Var Depth : Integer;
Begin
  If CSharpTokIs('<') Then
  Begin
    Depth := 1;
    CSharpConsume;
    While (SrcToken.Kind <> STK_EOF) And (Depth > 0) Do
    Begin
      If CSharpTokIs('<') Then Inc(Depth)
      Else If CSharpTokIs('>') Then Dec(Depth);
      If Depth > 0 Then CSharpConsume;
    End;
    If CSharpTokIs('>') Then CSharpConsume;
  End;
End;

{ ---- CSharpParseTypeName : parser un nom de type ------------- }

Function CSharpParseTypeName : TString;
Var S : TString;
Begin
  S := '';
  If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
  Begin
    S := SrcToken.Val;
    CSharpConsume;
    While CSharpTokIs('.') Do
    Begin
      CSharpConsume;
      If (SrcToken.Kind = STK_IDENT) Or (SrcToken.Kind = STK_KEYWORD) Then
      Begin
        S := S + '.' + SrcToken.Val;
        CSharpConsume;
      End;
    End;
    CSharpSkipGenericArgs;
    { Arrays }
    While CSharpTokIs('[') Do
    Begin
      S := S + '[]';
      CSharpConsume;
      If CSharpTokIs(']') Then CSharpConsume;
    End;
    { Nullable }
    If CSharpTokIs('?') Then
    Begin
      S := S + '?';
      CSharpConsume;
    End;
  End;
  CSharpParseTypeName := S;
End;

{ ---- CSharpParseMethodBody : parser un corps de methode ------ }

Procedure CSharpParseMethodBody(N : Integer);
Begin
  If CSharpTokIs('{') Then
    SrcNodes[N].Right := CSharpParseBlock
  Else If CSharpTokIs('=>') Then
  Begin
    CSharpConsume;
    SrcNodes[N].Right := CSharpParseExpr;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else If CSharpTokIs(';') Then
    CSharpConsume;
End;

{ ---- CSharpParseMemberDecl : parser un membre de type -------- }

Function CSharpParseMemberDecl : Integer;
Var N : Integer;
    TypeName, MemberName : TString;
Begin
  N := -1;
  CSharpSkipAttributes;
  CSharpSkipModifiers;

  { Constructeur ou methode ou propriete ou champ }
  If CSharpKwIs('event') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_DELEGATE_DECL);
    SrcNodes[N].Name := 'event';
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) And
          (Not CSharpTokIs('{')) Do
      CSharpConsume;
    If CSharpTokIs(';') Then CSharpConsume
    Else If CSharpTokIs('{') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
        CSharpConsume;
      If CSharpTokIs('}') Then CSharpConsume;
    End;
  End
  Else If CSharpKwIs('class') Or CSharpKwIs('struct') Or
          CSharpKwIs('interface') Or CSharpKwIs('enum') Then
  Begin
    { Nested type declaration }
    N := CSharpParseTypeDecl;
  End
  Else If CSharpKwIs('delegate') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_DELEGATE_DECL);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    { Return type + name }
    TypeName := CSharpParseTypeName;
    If (SrcToken.Kind = STK_IDENT) Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CSharpConsume;
    End
    Else
      SrcNodes[N].Name := TypeName;
    CSharpSkipGenericArgs;
    If CSharpTokIs('(') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
    End;
    While CSharpKwIs('where') Do
    Begin
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) And
            (Not CSharpKwIs('where')) Do
        CSharpConsume;
    End;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else If CSharpKwIs('const') Then
  Begin
    N := SrcNewNode(SNK_CONST_DECL);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    TypeName := CSharpParseTypeName;
    If SrcToken.Kind = STK_IDENT Then
    Begin
      SrcNodes[N].Name := SrcToken.Val;
      CSharpConsume;
    End;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) Do
      CSharpConsume;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else
  Begin
    { Method, property, field, or constructor }
    TypeName := CSharpParseTypeName;
    If TypeName = '' Then
    Begin
      { Skip unknown token }
      CSharpConsume;
      CSharpParseMemberDecl := -1;
      Exit;
    End;

    { Check if this is a constructor (typeName matches class, followed by '(') }
    If CSharpTokIs('(') Then
    Begin
      { Constructor }
      N := SrcNewNode(SNK_FUNC_DECL);
      SrcNodes[N].Name := TypeName;
      SrcNodes[N].Line := SrcToken.Line;
      SrcNodes[N].Col  := SrcToken.Col;
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
        CSharpConsume;
      If CSharpTokIs(')') Then CSharpConsume;
      { Base/this call }
      If CSharpTokIs(':') Then
      Begin
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('{')) And
              (Not CSharpTokIs(';')) Do
          CSharpConsume;
      End;
      CSharpParseMethodBody(N);
    End
    Else If (SrcToken.Kind = STK_IDENT) Then
    Begin
      MemberName := SrcToken.Val;
      CSharpConsume;
      CSharpSkipGenericArgs;
      If CSharpTokIs('(') Then
      Begin
        { Method }
        N := SrcNewNode(SNK_FUNC_DECL);
        SrcNodes[N].Name := MemberName;
        SrcNodes[N].Line := SrcToken.Line;
        SrcNodes[N].Col  := SrcToken.Col;
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(')')) Do
          CSharpConsume;
        If CSharpTokIs(')') Then CSharpConsume;
        { where clauses }
        While CSharpKwIs('where') Do
        Begin
          While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('{')) And
                (Not CSharpTokIs(';')) And (Not CSharpTokIs('=>')) And
                (Not CSharpKwIs('where')) Do
            CSharpConsume;
        End;
        CSharpParseMethodBody(N);
      End
      Else If CSharpTokIs('{') Then
      Begin
        { Property }
        N := SrcNewNode(SNK_CSHARP_PROPERTY);
        SrcNodes[N].Name := MemberName;
        SrcNodes[N].Line := SrcToken.Line;
        SrcNodes[N].Col  := SrcToken.Col;
        CSharpConsume;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
          CSharpConsume;
        If CSharpTokIs('}') Then CSharpConsume;
        { Auto property initializer }
        If CSharpTokIs('=') Then
        Begin
          CSharpConsume;
          CSharpParseExpr;
          If CSharpTokIs(';') Then CSharpConsume;
        End;
      End
      Else
      Begin
        { Field }
        N := SrcNewNode(SNK_VAR_DECL);
        SrcNodes[N].Name := MemberName;
        SrcNodes[N].Line := SrcToken.Line;
        SrcNodes[N].Col  := SrcToken.Col;
        While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) Do
          CSharpConsume;
        If CSharpTokIs(';') Then CSharpConsume;
      End;
    End
    Else If CSharpTokIs(';') Then
    Begin
      { Simple declaration like "int;" (unlikely but safe) }
      CSharpConsume;
    End
    Else
    Begin
      (* Unknown, skip to next ; or } *)
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) And
            (Not CSharpTokIs('}')) Do
        CSharpConsume;
      If CSharpTokIs(';') Then CSharpConsume;
    End;
  End;
  CSharpParseMemberDecl := N;
End;

{ ---- CSharpParseTypeBody : parser le corps d un type --------- }

Procedure CSharpParseTypeBody(Root : Integer);
Var N, Last : Integer;
Begin
  If CSharpTokIs('{') Then CSharpConsume;
  Last := -1;
  While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
  Begin
    N := CSharpParseMemberDecl;
    If N >= 0 Then
    Begin
      If SrcNodes[Root].Left = -1 Then
        SrcNodes[Root].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End;
  End;
  If CSharpTokIs('}') Then CSharpConsume;
End;

{ ---- CSharpParseTypeDecl : parser une declaration de type ---- }

Function CSharpParseTypeDecl : Integer;
Var N    : Integer;
    Kind : TSrcNodeKind;
Begin
  N := -1;
  If CSharpKwIs('class') Then
    Kind := SNK_CSHARP_CLASS_DECL
  Else If CSharpKwIs('struct') Then
    Kind := SNK_CSHARP_STRUCT_DECL
  Else If CSharpKwIs('interface') Then
    Kind := SNK_CSHARP_INTERFACE_DECL
  Else
    Kind := SNK_CSHARP_ENUM_DECL;

  N := SrcNewNode(Kind);
  SrcNodes[N].Line := SrcToken.Line;
  SrcNodes[N].Col  := SrcToken.Col;
  CSharpConsume; { class/struct/interface/enum }

  If (SrcToken.Kind = STK_IDENT) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    CSharpConsume;
  End;
  CSharpSkipGenericArgs;

  { Heritage : base classes }
  If CSharpTokIs(':') Then
  Begin
    CSharpConsume;
    CSharpParseTypeName;
    While CSharpTokIs(',') Do
    Begin
      CSharpConsume;
      CSharpParseTypeName;
    End;
  End;

  { where clauses }
  While CSharpKwIs('where') Do
  Begin
    CSharpConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('{')) And
          (Not CSharpKwIs('where')) Do
      CSharpConsume;
  End;

  If Kind = SNK_CSHARP_ENUM_DECL Then
  Begin
    { Enum body }
    If CSharpTokIs('{') Then
    Begin
      CSharpConsume;
      While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
        CSharpConsume;
      If CSharpTokIs('}') Then CSharpConsume;
    End;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else
    CSharpParseTypeBody(N);

  CSharpParseTypeDecl := N;
End;

{ ---- CSharpParseNamespace : parser un namespace C# ----------- }

Function CSharpParseNamespace : Integer;
Var N, Child, Last : Integer;
Begin
  N := SrcNewNode(SNK_CSHARP_NAMESPACE);
  SrcNodes[N].Line := SrcToken.Line;
  SrcNodes[N].Col  := SrcToken.Col;
  CSharpConsume; { namespace }

  { Namespace name (could be dotted) }
  If (SrcToken.Kind = STK_IDENT) Then
  Begin
    SrcNodes[N].Name := SrcToken.Val;
    CSharpConsume;
    While CSharpTokIs('.') Do
    Begin
      CSharpConsume;
      If SrcToken.Kind = STK_IDENT Then
      Begin
        SrcNodes[N].Name := SrcNodes[N].Name + '.' + SrcToken.Val;
        CSharpConsume;
      End;
    End;
  End;

  { File-scoped namespace (C# 10) }
  If CSharpTokIs(';') Then
  Begin
    CSharpConsume;
    { File-scoped: rest of file is in this namespace }
    Last := -1;
    While SrcToken.Kind <> STK_EOF Do
    Begin
      Child := CSharpParseTopLevel;
      If Child >= 0 Then
      Begin
        If SrcNodes[N].Left = -1 Then
          SrcNodes[N].Left := Child
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Child;
        Last := Child;
      End;
    End;
  End
  Else If CSharpTokIs('{') Then
  Begin
    CSharpConsume;
    Last := -1;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs('}')) Do
    Begin
      Child := CSharpParseTopLevel;
      If Child >= 0 Then
      Begin
        If SrcNodes[N].Left = -1 Then
          SrcNodes[N].Left := Child
        Else If Last >= 0 Then
          SrcNodes[Last].Next := Child;
        Last := Child;
      End;
    End;
    If CSharpTokIs('}') Then CSharpConsume;
  End;
  CSharpParseNamespace := N;
End;

{ ---- CSharpParseTopLevel : parser un element de premier niveau }

Function CSharpParseTopLevel : Integer;
Var N : Integer;
Begin
  N := -1;
  CSharpSkipAttributes;
  CSharpSkipModifiers;

  If CSharpKwIs('using') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_USING);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    { using static, using alias = type }
    If CSharpKwIs('static') Then CSharpConsume;
    SrcNodes[N].Name := '';
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) Do
    Begin
      If SrcNodes[N].Name <> '' Then
        SrcNodes[N].Name := SrcNodes[N].Name + SrcToken.Val
      Else
        SrcNodes[N].Name := SrcToken.Val;
      CSharpConsume;
    End;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else If CSharpKwIs('namespace') Then
  Begin
    N := CSharpParseNamespace;
  End
  Else If CSharpKwIs('class') Or CSharpKwIs('struct') Or
          CSharpKwIs('interface') Or CSharpKwIs('enum') Then
  Begin
    N := CSharpParseTypeDecl;
  End
  Else If CSharpKwIs('delegate') Then
  Begin
    N := SrcNewNode(SNK_CSHARP_DELEGATE_DECL);
    SrcNodes[N].Line := SrcToken.Line;
    SrcNodes[N].Col  := SrcToken.Col;
    CSharpConsume;
    While (SrcToken.Kind <> STK_EOF) And (Not CSharpTokIs(';')) Do
      CSharpConsume;
    If CSharpTokIs(';') Then CSharpConsume;
  End
  Else If SrcToken.Kind = STK_EOF Then
  Begin
    { Fin de fichier }
  End
  Else
  Begin
    { Declaration globale inconnue, avancer }
    CSharpConsume;
  End;
  CSharpParseTopLevel := N;
End;

{ ---- CSharpParseTranslationUnit : unite de traduction C# ----- }

Function CSharpParseTranslationUnit : Integer;
Var Root, N, Last : Integer;
Begin
  CSharpConsume; { lire le premier token }
  Root := SrcNewNode(SNK_CSHARP_TRANSLATION_UNIT);
  SrcNodes[Root].Name := 'CSHARP_TU';
  Last := -1;
  While SrcToken.Kind <> STK_EOF Do
  Begin
    N := CSharpParseTopLevel;
    If N >= 0 Then
    Begin
      If SrcNodes[Root].Left = -1 Then
        SrcNodes[Root].Left := N
      Else If Last >= 0 Then
        SrcNodes[Last].Next := N;
      Last := N;
    End;
  End;
  CSharpParseTranslationUnit := Root;
End;

{ ---- Fin TODO 28 --------------------------------------------- }

{ ---- StrEndsWith : tester si S se termine par Suf ---------- }

Function StrEndsWith(Const S, Suf : TString) : Boolean;
Var LS, LSuf, I : Integer;
    SLow, SufLow : TString;
Begin
  LS   := Length(S);
  LSuf := Length(Suf);
  StrEndsWith := False;
  If LSuf > LS Then Exit;
  SLow := StrLowerCase(S);
  SufLow := StrLowerCase(Suf);
  For I := 1 To LSuf Do
    If SLow[LS - LSuf + I] <> SufLow[I] Then Exit;
  StrEndsWith := True;
End;

{ ---- IsPascalSource : verifier si le fichier est .pas ou .pp }

Function IsPascalSource(Const FName : TString) : Boolean;
Begin
  IsPascalSource := StrEndsWith(FName, '.pas') Or
                    StrEndsWith(FName, '.pp');
End;

{ ---- IsCSource : verifier si le fichier est .c ou .h -------- }

Function IsCSource(Const FName : TString) : Boolean;
Begin
  IsCSource := StrEndsWith(FName, '.c') Or
               StrEndsWith(FName, '.h');
End;

{ ---- IsCppSource : verifier si le fichier est .cpp/.cc/.cxx/.hpp/.hh/.hxx }

Function IsCppSource(Const FName : TString) : Boolean;
Begin
  IsCppSource := StrEndsWith(FName, '.cpp') Or
                 StrEndsWith(FName, '.cc')  Or
                 StrEndsWith(FName, '.cxx') Or
                 StrEndsWith(FName, '.hpp') Or
                 StrEndsWith(FName, '.hh')  Or
                 StrEndsWith(FName, '.hxx') Or
                 StrEndsWith(FName, '.h');
End;

{ ---- IsCSharpSource : verifier si le fichier est .cs --------- }

Function IsCSharpSource(Const FName : TString) : Boolean;
Begin
  IsCSharpSource := StrEndsWith(FName, '.cs');
End;

{ ---- AddSrcFile : ajouter un fichier a la liste ------------ }

Procedure AddSrcFile(Const FName : TString);
Begin
  If SrcFileCount >= MAX_SRC_FILES Then
  Begin
    WriteLn('CODEQL: trop de fichiers sources (max=', MAX_SRC_FILES, ')');
    Exit;
  End;
  SrcFileList[SrcFileCount] := FName;
  Inc(SrcFileCount);
End;

{ ---- EnsureTrailingSep : ajouter / ou \ si absent ---------- }

Function EnsureTrailingSep(Const Dir : TString) : TString;
Var Last : Char;
Begin
  If Length(Dir) = 0 Then
  Begin
    EnsureTrailingSep := '';
    Exit;
  End;
  Last := Dir[Length(Dir)];
  {$IFDEF LINUX}
  If Last <> '/' Then
    EnsureTrailingSep := Dir + '/'
  Else
    EnsureTrailingSep := Dir;
  {$ELSE}
  If (Last <> '\') And (Last <> '/') Then
    EnsureTrailingSep := Dir + '\'
  Else
    EnsureTrailingSep := Dir;
  {$ENDIF}
End;

{ ---- CollectSourceFiles : parcours recursif d un repertoire  }

Procedure CollectSourceFiles(Const Dir : TString);
Var
  SR     : SearchRec;
  Prefix : TString;
Begin
  Prefix := EnsureTrailingSep(Dir);
  { Collecter les fichiers Pascal dans ce repertoire }
  FindFirst(Prefix + '*.*', AnyFile, SR);
  While DosError = 0 Do
  Begin
    If (SR.Attr And Directory) = 0 Then
    Begin
      If ((Opts.Language = 'pascal') And IsPascalSource(SR.Name)) Or
         ((Opts.Language = 'c') And IsCSource(SR.Name)) Or
         ((Opts.Language = 'cpp') And IsCppSource(SR.Name)) Or
         ((Opts.Language = 'csharp') And IsCSharpSource(SR.Name)) Then
        AddSrcFile(Prefix + SR.Name);
    End;
    FindNext(SR);
  End;
  { Parcours recursif des sous-repertoires }
  FindFirst(Prefix + '*.*', Directory, SR);
  While DosError = 0 Do
  Begin
    If (SR.Attr And Directory) <> 0 Then
    Begin
      If (SR.Name <> '.') And (SR.Name <> '..') Then
        CollectSourceFiles(Prefix + SR.Name);
    End;
    FindNext(SR);
  End;
End;

{ ---- RunDatabaseCreate : orchestration complete ------------- }

Procedure RunDatabaseCreate;
Var
  I           : Integer;
  TotalNodes  : LongInt;
  TotalFiles  : Integer;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('=== codeql database create ===');
  WriteLn('  base de donnees : ', Opts.DatabasePath);
  WriteLn('  source-root     : ', Opts.SourceDir);
  WriteLn('  language        : ', Opts.Language);
  WriteLn;

  { Etape 1 : Collecter les fichiers sources }
  SrcFileCount := 0;
  CollectSourceFiles(Opts.SourceDir);
  WriteLn('Fichiers sources trouves : ', SrcFileCount);
  If SrcFileCount = 0 Then
  Begin
    If Opts.Language = 'c' Then
      WriteLn('CODEQL: aucun fichier .c ou .h trouve dans: ', Opts.SourceDir)
    Else If Opts.Language = 'cpp' Then
      WriteLn('CODEQL: aucun fichier .cpp/.cc/.cxx/.hpp/.hh/.hxx trouve dans: ', Opts.SourceDir)
    Else
      WriteLn('CODEQL: aucun fichier .pas ou .pp trouve dans: ', Opts.SourceDir);
    Exit;
  End;
  If Opts.Verbose Then
    For I := 0 To SrcFileCount - 1 Do
      WriteLn('  [', I + 1, '] ', SrcFileList[I]);
  WriteLn;

  { Etape 2 : Initialiser la base de donnees }
  InitDatabase;

  { Etape 3 : Parser et extraire chaque fichier source }
  TotalNodes := 0;
  TotalFiles := 0;
  For I := 0 To SrcFileCount - 1 Do
  Begin
    WriteLn('--- Extraction [', I + 1, '/', SrcFileCount, '] : ',
            SrcFileList[I], ' ---');
    { Parser le fichier source Pascal }
    Assign(SrcLexF, SrcFileList[I]);
    {$I-}
    Reset(SrcLexF);
    {$I+}
    If IOResult <> 0 Then
    Begin
      WriteLn('  ERREUR: impossible d''ouvrir: ', SrcFileList[I]);
      Continue;
    End;
    SrcLexOpened := True;
    If Opts.Language = 'c' Then
    Begin
      CLexInit;
      SrcASTInit;
      SrcRootNode := CParseTranslationUnit;
    End
    Else If Opts.Language = 'cpp' Then
    Begin
      CppLexInit;
      SrcASTInit;
      SrcRootNode := CppParseTranslationUnit;
    End
    Else If Opts.Language = 'csharp' Then
    Begin
      CSharpLexInit;
      SrcASTInit;
      SrcRootNode := CSharpParseTranslationUnit;
    End
    Else
    Begin
      SrcLexInit;
      SrcASTInit;
      SrcRootNode := SrcParseModule;
    End;
    WriteLn('  noeuds AST : ', SrcNodeCount);
    WriteLn('  lignes     : ', SrcTotalLines);
    TotalNodes := TotalNodes + SrcNodeCount;
    Inc(TotalFiles);

    { Extraire dans la base de donnees relationnelle }
    ExtProgramId := DbAddProgram(SrcNodes[SrcRootNode].Name,
                                 SrcFileList[I]);
    ExtFileId := DbAddFile(SrcFileList[I], SrcTotalLines);
    DbAddLocation(ExtFileId, 1, 1, SrcTotalLines, 1);
    ExtractNode(SrcRootNode, ExtProgramId);
    WriteLn('  expressions : ', DbExprCnt,
            '  instructions: ', DbStmtCnt,
            '  fonctions   : ', DbFunctionCnt);

    SrcLexClose;
  End;
  WriteLn;
  WriteLn('Extraction terminee :');
  WriteLn('  fichiers traites : ', TotalFiles, ' / ', SrcFileCount);
  WriteLn('  noeuds AST total : ', TotalNodes);
  WriteLn('  programmes  : ', DbProgramCnt);
  WriteLn('  fichiers    : ', DbFileCnt);
  WriteLn('  positions   : ', DbLocationCnt);
  WriteLn('  expressions : ', DbExprCnt);
  WriteLn('  instructions: ', DbStmtCnt);
  WriteLn('  fonctions   : ', DbFunctionCnt);
  WriteLn('  variables   : ', DbVariableCnt);
  WriteLn('  types       : ', DbTypeCnt);
  WriteLn('  appels      : ', DbCallCnt);
  WriteLn('  acces       : ', DbAccessCnt);
  WriteLn('  commentaires: ', DbCommentCnt);
  WriteLn('  diagnostics : ', DbDiagCnt);
  WriteLn;

  { Etape 4 : Construire le graphe de flot de controle }
  WriteLn('Construction du CFG...');
  InitCFG;
  BuildCFG;
  WriteLn('  noeuds CFG : ', CfgNodeCount);
  WriteLn('  aretes CFG : ', CfgEdgeCount);
  WriteLn;

  { Etape 5 : Analyse de flot de donnees }
  WriteLn('Analyse de flot de donnees...');
  RunDataFlowAnalysis;
  WriteLn('  variables : ', DfVarCount);
  WriteLn('  definitions: ', DfDefCount);
  WriteLn('  utilisations: ', DfUseCount);
  WriteLn('  chaines def-use: ', DfChainCount);
  WriteLn;

  { Etape 6 : Suivi de teinte }
  WriteLn('Suivi de teinte (taint tracking)...');
  RunTaintTracking;
  WriteLn('  sources  : ', TaintSrcCount);
  WriteLn('  puits    : ', TaintSinkCount);
  WriteLn('  alertes  : ', TaintAlertCount);
  WriteLn;

  { Etape 7 : Requetes de securite integrees }
  WriteLn('Requetes de securite...');
  RunSecurityQueries;
  WriteLn('  alertes securite : ', SecAlertCount);
  WriteLn;

  { Etape 8 : Sauvegarder la base de donnees sur disque }
  WriteLn('Sauvegarde de la base de donnees...');
  DbSaveDatabase(Opts.DatabasePath);
  WriteLn;
  WriteLn('=== database create terminee ===');
End;

{ ============================================================
  TODO 23 - COMMANDE "codeql database analyze" [IMPLEMENTE]
  ============================================================ }

{ ---- TrimStr : supprimer les espaces en debut et fin ------- }

Function TrimStr(Const S : TString) : TString;
Var I, J : Integer;
    R : TString;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  J := Length(S);
  While (J >= I) And (S[J] = ' ') Do Dec(J);
  R := '';
  While I <= J Do
  Begin
    R := R + S[I];
    Inc(I);
  End;
  TrimStr := R;
End;

{ ---- LoadQuerySuite : charger une suite .qls --------------- }
{   Un fichier .qls contient un nom de fichier .ql par ligne.
    Les lignes vides et les lignes commencant par # sont ignorees. }

Procedure LoadQuerySuite(Const SuiteFile : TString);
Var
  F : Text;
  Line, Trimmed : TString;
Begin
  SuiteQueryCount := 0;
  Assign(F, SuiteFile);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('CODEQL: impossible d''ouvrir la suite: ', SuiteFile);
    Exit;
  End;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Trimmed := TrimStr(Line);
    If (Length(Trimmed) = 0) Or (Trimmed[1] = '#') Then
      Continue;
    If SuiteQueryCount >= MAX_SUITE_QUERIES Then
    Begin
      WriteLn('CODEQL: trop de requetes dans la suite (max=',
              MAX_SUITE_QUERIES, ')');
      Break;
    End;
    SuiteQueries[SuiteQueryCount] := Trimmed;
    Inc(SuiteQueryCount);
  End;
  Close(F);
End;

{ ---- CompileAndRunQuery : compiler et executer une requete -- }

Procedure CompileAndRunQuery(Const QLFile : TString);
Begin
  WriteLn('  --- Compilation : ', QLFile, ' ---');
  Assign(LexSrcF, QLFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('  ERREUR: impossible d''ouvrir: ', QLFile);
    Exit;
  End;
  LexOpened := True;
  LexInit;
  ASTInit;
  InitTypeSystem;
  RootNode := ParseModule;
  WriteLn('    noeuds AST : ', NodeCount);

  { Verification des types }
  TypeCheckAST;
  WriteLn('    types      : ', TypeCount);

  { Resolution des imports }
  RunImportResolution;

  { Bibliotheque standard }
  BuildStdLibrary;

  { Evaluation de la requete }
  InitBindings;
  InitResultSet;
  EvalQuery(RootNode);
  WriteLn('    resultats  : ', EvalResults.NRows, ' lignes');

  If Opts.DebugMode Then
  Begin
    DumpAST(RootNode, 0);
    DumpBindings;
  End;
  LexClose;
  WriteLn;
End;

{ ---- FormatName : nom textuel du format de sortie ---------- }

Function FormatName(F : TOutputFormat) : TString;
Begin
  Case F Of
    FMT_SARIF : FormatName := 'SARIF';
    FMT_CSV   : FormatName := 'CSV';
    FMT_TEXT  : FormatName := 'Text';
  Else
    FormatName := 'unknown';
  End;
End;

{ ---- RunDatabaseAnalyze : orchestration complete ------------ }

Procedure RunDatabaseAnalyze;
Var
  I : Integer;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('=== codeql database analyze ===');
  WriteLn('  base de donnees : ', Opts.DatabasePath);
  If Opts.QueryFile <> '' Then
    WriteLn('  suite/requete   : ', Opts.QueryFile);
  WriteLn('  format de sortie: ', FormatName(Opts.Format));
  WriteLn;

  { Etape 1 : Charger la base de donnees depuis le disque }
  WriteLn('Chargement de la base de donnees...');
  DbLoadDatabase(Opts.DatabasePath);
  WriteLn('  programmes  : ', DbProgramCnt);
  WriteLn('  fichiers    : ', DbFileCnt);
  WriteLn('  expressions : ', DbExprCnt);
  WriteLn('  instructions: ', DbStmtCnt);
  WriteLn('  fonctions   : ', DbFunctionCnt);
  WriteLn('  variables   : ', DbVariableCnt);
  WriteLn('  types       : ', DbTypeCnt);
  WriteLn;

  { Etape 2 : Construire le CFG a partir des donnees chargees }
  WriteLn('Construction du CFG...');
  InitCFG;
  BuildCFG;
  WriteLn('  noeuds CFG : ', CfgNodeCount);
  WriteLn('  aretes CFG : ', CfgEdgeCount);
  WriteLn;

  { Etape 3 : Analyse de flot de donnees }
  WriteLn('Analyse de flot de donnees...');
  RunDataFlowAnalysis;
  WriteLn('  chaines def-use: ', DfChainCount);
  WriteLn;

  { Etape 4 : Suivi de teinte }
  WriteLn('Suivi de teinte...');
  RunTaintTracking;
  WriteLn('  alertes teinte : ', TaintAlertCount);
  WriteLn;

  { Etape 5 : Requetes de securite integrees }
  WriteLn('Requetes de securite integrees...');
  RunSecurityQueries;
  WriteLn('  alertes securite : ', SecAlertCount);
  WriteLn;

  { Etape 6 : Charger et executer les requetes QL utilisateur }
  If Opts.QueryFile <> '' Then
  Begin
    If StrEndsWith(Opts.QueryFile, '.qls') Then
    Begin
      WriteLn('Chargement de la suite de requetes...');
      LoadQuerySuite(Opts.QueryFile);
      WriteLn('  requetes dans la suite : ', SuiteQueryCount);
      WriteLn;
      For I := 0 To SuiteQueryCount - 1 Do
        CompileAndRunQuery(SuiteQueries[I]);
    End
    Else
    Begin
      WriteLn('Execution de la requete...');
      CompileAndRunQuery(Opts.QueryFile);
    End;
  End
  Else
    WriteLn('Aucune requete utilisateur specifiee, utilisation des requetes integrees.');
  WriteLn;

  { Etape 7 : Generation du rapport final }
  WriteLn('Generation du rapport...');
  Case Opts.Format Of
    FMT_SARIF :
    Begin
      DumpSarif;
      WriteLn('  format: SARIF v2.1.0');
    End;
    FMT_CSV :
    Begin
      DumpCSV;
      WriteLn('  format: CSV');
    End;
    FMT_TEXT :
    Begin
      DumpText;
      WriteLn('  format: texte tabule');
    End;
  End;
  WriteLn;
  WriteLn('=== database analyze terminee ===');
End;

Procedure RunQueryRun;
Var
  ReplLine : TString;
  TmpF     : Text;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('=== codeql query run ===');
  WriteLn('  base de donnees : ', Opts.DatabasePath);
  If Opts.Interactive Then
    WriteLn('  mode            : REPL interactif')
  Else
    WriteLn('  requete         : ', Opts.QueryFile);
  WriteLn;

  { Etape 1 : Charger la base de donnees }
  WriteLn('Chargement de la base de donnees...');
  DbLoadDatabase(Opts.DatabasePath);
  WriteLn('  programmes  : ', DbProgramCnt);
  WriteLn('  fichiers    : ', DbFileCnt);
  WriteLn('  expressions : ', DbExprCnt);
  WriteLn('  instructions: ', DbStmtCnt);
  WriteLn('  fonctions   : ', DbFunctionCnt);
  WriteLn('  variables   : ', DbVariableCnt);
  WriteLn('  types       : ', DbTypeCnt);
  WriteLn;

  { Etape 2 : Construire le CFG }
  WriteLn('Construction du CFG...');
  InitCFG;
  BuildCFG;
  WriteLn('  noeuds CFG : ', CfgNodeCount);
  WriteLn('  aretes CFG : ', CfgEdgeCount);
  WriteLn;

  { Etape 3 : Analyse de flot de donnees }
  WriteLn('Analyse de flot de donnees...');
  RunDataFlowAnalysis;
  WriteLn('  chaines def-use: ', DfChainCount);
  WriteLn;

  { Etape 4 : Suivi de teinte }
  WriteLn('Suivi de teinte...');
  RunTaintTracking;
  WriteLn('  alertes teinte : ', TaintAlertCount);
  WriteLn;

  { Etape 5 : Requetes de securite integrees }
  WriteLn('Requetes de securite...');
  RunSecurityQueries;
  WriteLn('  alertes securite : ', SecAlertCount);
  WriteLn;

  If Not Opts.Interactive Then
  Begin
    { Mode fichier : compiler et executer la requete specifiee }
    WriteLn('Compilation et execution de la requete...');
    CompileAndRunQuery(Opts.QueryFile);
    WriteLn;
    WriteLn('=== query run terminee ===');
  End
  Else
  Begin
    { Mode REPL interactif }
    WriteLn('Mode REPL interactif. Tapez une requete QL et validez');
    WriteLn('avec une ligne vide. Commandes speciales :');
    WriteLn('  :quit, :q, :exit  Quitter le REPL');
    WriteLn('  :help             Afficher l''aide REPL');
    WriteLn('  :db               Afficher les statistiques de la BD');
    WriteLn('  :debug            Basculer le mode debug');
    WriteLn;
    Repeat
      Write(REPL_PROMPT);
      ReadLn(ReplLine);
      ReplLine := TrimStr(ReplLine);

      { Commandes speciales }
      If (ReplLine = ':quit') Or (ReplLine = ':q') Or
         (ReplLine = ':exit') Then
        Break
      Else If ReplLine = ':help' Then
      Begin
        WriteLn('Aide REPL :');
        WriteLn('  Entrez une requete QL complete (ex: select v from');
        WriteLn('  Variable v where v.hasName("x")).');
        WriteLn('  Validez avec une ligne vide pour executer.');
        WriteLn('  Commandes : :quit :help :db :debug');
        WriteLn;
      End
      Else If ReplLine = ':db' Then
      Begin
        WriteLn('Statistiques de la base de donnees :');
        WriteLn('  programmes  : ', DbProgramCnt);
        WriteLn('  fichiers    : ', DbFileCnt);
        WriteLn('  expressions : ', DbExprCnt);
        WriteLn('  instructions: ', DbStmtCnt);
        WriteLn('  fonctions   : ', DbFunctionCnt);
        WriteLn('  variables   : ', DbVariableCnt);
        WriteLn('  types       : ', DbTypeCnt);
        WriteLn('  noeuds CFG  : ', CfgNodeCount);
        WriteLn('  alertes     : ', SecAlertCount);
        WriteLn;
      End
      Else If ReplLine = ':debug' Then
      Begin
        Opts.DebugMode := Not Opts.DebugMode;
        If Opts.DebugMode Then
          WriteLn('Mode debug active.')
        Else
          WriteLn('Mode debug desactive.');
        WriteLn;
      End
      Else If Length(ReplLine) > 0 Then
      Begin
        { Ecrire la requete dans un fichier temporaire }
        Assign(TmpF, REPL_TMPFILE);
        {$I-}
        Rewrite(TmpF);
        {$I+}
        If IOResult <> 0 Then
        Begin
          WriteLn('ERREUR: impossible de creer le fichier temporaire');
          Continue;
        End;
        WriteLn(TmpF, ReplLine);
        { Lire les lignes suivantes jusqu a une ligne vide }
        Repeat
          Write('...  ');
          ReadLn(ReplLine);
          If Length(TrimStr(ReplLine)) = 0 Then Break;
          WriteLn(TmpF, ReplLine);
        Until False;
        Close(TmpF);
        { Compiler et executer la requete temporaire }
        CompileAndRunQuery(REPL_TMPFILE);
        { Supprimer le fichier temporaire }
        Assign(TmpF, REPL_TMPFILE);
        {$I-}
        Erase(TmpF);
        {$I+}
        If IOResult <> 0 Then { ignorer };
        WriteLn;
      End;
    Until False;
    WriteLn;
    WriteLn('=== REPL termine ===');
  End;
End;

Procedure RunInterpretResults;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('database interpret-results: ', Opts.DatabasePath);
  WriteLn('(non implemente)');
End;

{ ============================================================
  TODO 24 - COMMANDE "codeql query run" [IMPLEMENTE]
  ============================================================ }

{ (Integre dans RunQueryRun ci-dessus : chargement BD, analyses,
   execution d une requete QL unique, mode REPL interactif.) }

{ ============================================================
  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES [IMPLEMENTE]
  ============================================================ }

{ ---- WriteSampleFile : ecrire un fichier texte --------------- }

Procedure WriteSampleFile(Const FilePath : TString;
                          Const Lines : Array Of TString);
Var
  F : Text;
  I : Integer;
Begin
  Assign(F, FilePath);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('ERREUR: impossible de creer: ', FilePath);
    Exit;
  End;
  For I := 0 To High(Lines) Do
    WriteLn(F, Lines[I]);
  Close(F);
  WriteLn('  cree: ', FilePath);
End;

{ ---- GenerateSample01 : Variables non initialisees ---------- }

Procedure GenerateSample01(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/01_uninit_var.ql', [
    '/**',
    ' * @name Detection de variables non initialisees',
    ' * @description Trouve les variables locales utilisees avant',
    ' *              d''etre initialisees.',
    ' * @kind problem',
    ' * @problem.severity warning',
    ' * @id pascal/uninit-variable',
    ' */',
    '',
    'import pascal',
    '',
    'from Variable v, Access a',
    'where v.getAnAccess() = a',
    '  and not exists(Assignment assign |',
    '    assign.getTarget() = v and',
    '    assign.getLocation().getLine() < a.getLocation().getLine())',
    'select v, "La variable " + v.getName() + " est utilisee sans etre initialisee"'
  ]);
End;

{ ---- GenerateSample02 : Fichiers non fermes ----------------- }

Procedure GenerateSample02(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/02_unclosed_file.ql', [
    '/**',
    ' * @name Detection de fichiers non fermes',
    ' * @description Trouve les fichiers ouverts avec Reset/Rewrite',
    ' *              qui ne sont jamais fermes avec Close.',
    ' * @kind problem',
    ' * @problem.severity warning',
    ' * @id pascal/unclosed-file',
    ' */',
    '',
    'import pascal',
    '',
    'from Variable f, Call openCall',
    'where (openCall.getTarget().hasName("Reset") or',
    '       openCall.getTarget().hasName("Rewrite"))',
    '  and openCall.getAnArgument() = f.getAnAccess()',
    '  and not exists(Call closeCall |',
    '    closeCall.getTarget().hasName("Close") and',
    '    closeCall.getAnArgument() = f.getAnAccess())',
    'select f, "Le fichier " + f.getName() + " est ouvert mais jamais ferme"'
  ]);
End;

{ ---- GenerateSample03 : Debordement de tampon --------------- }

Procedure GenerateSample03(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/03_buffer_overflow.ql', [
    '/**',
    ' * @name Detection de debordement de tampon',
    ' * @description Trouve les acces a un tableau avec un indice',
    ' *              qui pourrait depasser les bornes.',
    ' * @kind problem',
    ' * @problem.severity error',
    ' * @id pascal/buffer-overflow',
    ' */',
    '',
    'import pascal',
    '',
    'from Access a, Variable arr, Expr idx',
    'where a.getTarget() = arr',
    '  and arr.getType().getName() = "array"',
    '  and idx = a.getAChild()',
    '  and not exists(Stmt guard |',
    '    guard.getLocation().getLine() < a.getLocation().getLine() and',
    '    guard instanceof Stmt)',
    'select a, "Acces potentiel hors bornes au tableau " + arr.getName()'
  ]);
End;

{ ---- GenerateSample04 : Injection de commandes -------------- }

Procedure GenerateSample04(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/04_cmd_injection.ql', [
    '/**',
    ' * @name Detection d''injection de commandes',
    ' * @description Trouve les appels a Exec avec des donnees',
    ' *              provenant de l''utilisateur sans validation.',
    ' * @kind path-problem',
    ' * @problem.severity error',
    ' * @id pascal/command-injection',
    ' */',
    '',
    'import pascal',
    '',
    'from Call execCall, Expr arg, Call readCall',
    'where execCall.getTarget().hasName("Exec")',
    '  and arg = execCall.getAnArgument()',
    '  and readCall.getTarget().hasName("ReadLn")',
    '  and arg.flowsTo(readCall)',
    'select execCall, "Injection de commande : donnees de ReadLn vers Exec"'
  ]);
End;

{ ---- GenerateSample05 : Code mort --------------------------- }

Procedure GenerateSample05(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/05_dead_code.ql', [
    '/**',
    ' * @name Detection de code mort',
    ' * @description Trouve les fonctions et procedures declarees',
    ' *              mais jamais appelees dans le programme.',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/dead-code',
    ' */',
    '',
    'import pascal',
    '',
    'from Function f',
    'where not f.hasName("main")',
    '  and not exists(Call c | c.getTarget() = f)',
    'select f, "La fonction " + f.getName() + " n''est jamais appelee"'
  ]);
End;

{ ---- GenerateSample06 : Complexite cyclomatique ------------- }

Procedure GenerateSample06(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/06_cyclomatic.ql', [
    '/**',
    ' * @name Complexite cyclomatique elevee',
    ' * @description Trouve les fonctions dont la complexite',
    ' *              cyclomatique depasse un seuil (>10 branches).',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/high-cyclomatic-complexity',
    ' */',
    '',
    'import pascal',
    '',
    'from Function f, int branches',
    'where branches = count(Stmt s |',
    '  s.getEnclosingFunction() = f and',
    '  (s instanceof Stmt))',
    '  and branches > 10',
    'select f, "La fonction " + f.getName() +',
    '  " a une complexite cyclomatique elevee (" +',
    '  branches.toString() + " branches)"'
  ]);
End;

{ ---- GenerateSample07 : Convention de nommage --------------- }

Procedure GenerateSample07(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/07_naming_convention.ql', [
    '/**',
    ' * @name Violation de convention de nommage',
    ' * @description Trouve les variables dont le nom ne commence',
    ' *              pas par une lettre minuscule, et les types qui',
    ' *              ne commencent pas par T.',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/naming-convention',
    ' */',
    '',
    'import pascal',
    '',
    'from Variable v',
    'where v.getName().charAt(0) >= "A"',
    '  and v.getName().charAt(0) <= "Z"',
    '  and not v.getName().charAt(0) = "T"',
    'select v, "La variable " + v.getName() +',
    '  " devrait commencer par une minuscule"'
  ]);
End;

{ ---- GenerateSample08 : Parametres inutilises --------------- }

Procedure GenerateSample08(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/08_unused_param.ql', [
    '/**',
    ' * @name Parametres inutilises',
    ' * @description Trouve les parametres de fonctions ou procedures',
    ' *              qui ne sont jamais utilises dans le corps.',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/unused-parameter',
    ' */',
    '',
    'import pascal',
    '',
    'from Function f, Variable param',
    'where param = f.getAnArgument()',
    '  and not exists(Access a |',
    '    a.getTarget() = param and',
    '    a.getEnclosingFunction() = f)',
    'select param, "Le parametre " + param.getName() +',
    '  " de " + f.getName() + " n''est jamais utilise"'
  ]);
End;

{ ---- GenerateSample09 : Code duplique ----------------------- }

Procedure GenerateSample09(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/09_duplicated_code.ql', [
    '/**',
    ' * @name Detection de code duplique',
    ' * @description Trouve les blocs d''instructions identiques',
    ' *              apparaissant dans plusieurs fonctions.',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/duplicated-code',
    ' */',
    '',
    'import pascal',
    '',
    'from Stmt s1, Stmt s2, Function f1, Function f2',
    'where s1.getEnclosingFunction() = f1',
    '  and s2.getEnclosingFunction() = f2',
    '  and not f1 = f2',
    '  and s1.toString() = s2.toString()',
    '  and s1.getLocation().getLine() < s2.getLocation().getLine()',
    'select s1, "Bloc duplique entre " + f1.getName() +',
    '  " et " + f2.getName()'
  ]);
End;

{ ---- GenerateSample10 : Utilisation de Goto ----------------- }

Procedure GenerateSample10(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/10_goto_usage.ql', [
    '/**',
    ' * @name Utilisation de Goto',
    ' * @description Trouve les instructions Goto qui rendent',
    ' *              le code difficile a lire et a maintenir.',
    ' * @kind problem',
    ' * @problem.severity recommendation',
    ' * @id pascal/goto-usage',
    ' */',
    '',
    'import pascal',
    '',
    'from Stmt s',
    'where s.getType() = "goto"',
    'select s, "Utilisation de Goto a la ligne " +',
    '  s.getLocation().getLine().toString() +',
    '  " : envisager une restructuration du code"'
  ]);
End;

{ ---- GenerateReadme : documentation d aide ------------------ }

Procedure GenerateReadme(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/README.txt', [
    '================================================================',
    ' CODEQL pour Pascal - Requetes exemples',
    '================================================================',
    '',
    'Ce repertoire contient 10 requetes QL exemples pour l''analyse',
    'statique de code Pascal.',
    '',
    'Requetes disponibles :',
    '  01_uninit_var.ql       Variables non initialisees',
    '  02_unclosed_file.ql    Fichiers non fermes',
    '  03_buffer_overflow.ql  Debordement de tampon',
    '  04_cmd_injection.ql    Injection de commandes',
    '  05_dead_code.ql        Code mort (fonctions inutilisees)',
    '  06_cyclomatic.ql       Complexite cyclomatique elevee',
    '  07_naming_convention.ql Convention de nommage',
    '  08_unused_param.ql     Parametres inutilises',
    '  09_duplicated_code.ql  Code duplique',
    '  10_goto_usage.ql       Utilisation de Goto',
    '',
    'Utilisation :',
    '  1. Creer une base de donnees :',
    '     CODEQL database create mydb --source-root=src',
    '',
    '  2. Analyser avec une requete :',
    '     CODEQL query run --database=mydb SAMPLES/01_uninit_var.ql',
    '',
    '  3. Analyser avec toutes les requetes :',
    '     CODEQL database analyze mydb SAMPLES/all.qls --format=sarif',
    '',
    '  4. Mode interactif :',
    '     CODEQL query run --database=mydb --interactive',
    '',
    'Suite de requetes :',
    '  Le fichier all.qls contient la liste de toutes les requetes',
    '  et peut etre utilise avec "database analyze".',
    '',
    '================================================================'
  ]);
End;

{ ---- GenerateQuerySuite : fichier .qls avec toutes les queries }

Procedure GenerateQuerySuite(Const Dir : TString);
Begin
  WriteSampleFile(Dir + '/all.qls', [
    '# Suite de requetes CodeQL pour Pascal',
    '# Chaque ligne contient le chemin vers un fichier .ql',
    '',
    Dir + '/01_uninit_var.ql',
    Dir + '/02_unclosed_file.ql',
    Dir + '/03_buffer_overflow.ql',
    Dir + '/04_cmd_injection.ql',
    Dir + '/05_dead_code.ql',
    Dir + '/06_cyclomatic.ql',
    Dir + '/07_naming_convention.ql',
    Dir + '/08_unused_param.ql',
    Dir + '/09_duplicated_code.ql',
    Dir + '/10_goto_usage.ql'
  ]);
End;

{ ---- RunGenerateSamples : orchestration complete ------------- }

Procedure RunGenerateSamples;
Var
  Dir : TString;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('=== codeql generate samples ===');
  WriteLn;

  { Determiner le repertoire de sortie }
  If Opts.OutputFile <> '' Then
    Dir := Opts.OutputFile
  Else
    Dir := SAMPLES_DIR;

  WriteLn('Repertoire de sortie : ', Dir);
  WriteLn;

  { Creer le repertoire (ignore si deja existant) }
  {$I-}
  MkDir(Dir);
  {$I+}
  If IOResult <> 0 Then
  Begin
    { Le repertoire existe peut-etre deja, on continue }
  End;

  { Generer les 10 requetes exemples }
  WriteLn('Generation de ', NUM_SAMPLE_QUERIES, ' requetes exemples...');
  GenerateSample01(Dir);
  GenerateSample02(Dir);
  GenerateSample03(Dir);
  GenerateSample04(Dir);
  GenerateSample05(Dir);
  GenerateSample06(Dir);
  GenerateSample07(Dir);
  GenerateSample08(Dir);
  GenerateSample09(Dir);
  GenerateSample10(Dir);
  WriteLn;

  { Generer la documentation }
  WriteLn('Generation de la documentation...');
  GenerateReadme(Dir);
  WriteLn;

  { Generer la suite de requetes }
  WriteLn('Generation de la suite de requetes...');
  GenerateQuerySuite(Dir);
  WriteLn;

  WriteLn(NUM_SAMPLE_QUERIES, ' requetes exemples generees dans ', Dir, '/');
  WriteLn('=== generation terminee ===');
End;

{ ---- DumpExtendedHelp : documentation etendue --------------- }

Procedure DumpExtendedHelp;
Begin
  WriteLn('================================================================');
  WriteLn(' CODEQL pour Pascal v', CODEQL_VERSION, ' - Documentation');
  WriteLn('================================================================');
  WriteLn;
  WriteLn('Description :');
  WriteLn('  Clone de CodeQL pour l''analyse statique de code Pascal.');
  WriteLn('  Supporte la creation de bases de donnees relationnelles,');
  WriteLn('  l''analyse de flot de donnees, le suivi de teinte, et');
  WriteLn('  l''execution de requetes QL.');
  WriteLn;
  WriteLn('Architecture :');
  WriteLn('  - Lexeur et parseur QL pour les requetes');
  WriteLn('  - Lexeur et parseur Pascal pour le code source');
  WriteLn('  - Base de donnees relationnelle (12 tables)');
  WriteLn('  - Graphe de flot de controle (CFG)');
  WriteLn('  - Analyse de flot de donnees (reaching defs, liveness)');
  WriteLn('  - Suivi de teinte (taint tracking)');
  WriteLn('  - Requetes de securite integrees');
  WriteLn('  - Sortie SARIF, CSV et texte');
  WriteLn('  - Systeme d''import et de modules QL');
  WriteLn('  - Bibliotheque standard de predicats');
  WriteLn('  - Mode REPL interactif');
  WriteLn;
  WriteLn('Workflow typique :');
  WriteLn('  1. CODEQL database create mydb --source-root=src');
  WriteLn('  2. CODEQL database analyze mydb security.qls --format=sarif');
  WriteLn('  3. CODEQL generate samples');
  WriteLn;
  WriteLn('Pour plus d''aide : CODEQL -h');
  WriteLn('================================================================');
End;

{ ---- CleanupResources : nettoyage des ressources ------------ }

Procedure CleanupResources;
Var
  TmpF : Text;
Begin
  { Fermer le lexeur QL s il est ouvert }
  If LexOpened Then
    LexClose;
  { Fermer le lexeur source s il est ouvert }
  If SrcLexOpened Then
  Begin
    {$I-}
    Close(SrcLexF);
    {$I+}
    If IOResult <> 0 Then { ignorer };
    SrcLexOpened := False;
  End;
  { Supprimer le fichier temporaire REPL s il existe }
  Assign(TmpF, REPL_TMPFILE);
  {$I-}
  Erase(TmpF);
  {$I+}
  If IOResult <> 0 Then { ignorer };
End;

{ ---- Dispatch de la sous-commande -------------------------- }

Procedure Run;
Begin
  Case Opts.SubCmd Of
    CMD_DATABASE_CREATE         : RunDatabaseCreate;
    CMD_DATABASE_ANALYZE        : RunDatabaseAnalyze;
    CMD_QUERY_RUN               : RunQueryRun;
    CMD_DB_INTERPRET_RESULTS    : RunInterpretResults;
    CMD_GENERATE_SAMPLES        : RunGenerateSamples;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
  ParseArgs;
  Run;
  CleanupResources;
End.
