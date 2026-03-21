{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

{ TODO - Liste des 25 points a implementer pour le clone de CodeQL :

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

  13. Implementer l'analyse de flot de donnees (data flow) : calcul des
      definitions atteignantes (reaching definitions), chaines
      definition-utilisation (def-use chains), analyse de vivacite
      (liveness), propagation avant et arriere sur le CFG.

  14. Implementer le suivi de teinte (taint tracking) : definition des
      sources de donnees non fiables (entrees utilisateur : ReadLn,
      ParamStr, fichiers), definition des puits sensibles (WriteLn
      avec format, Exec, Assign, acces SQL), propagation de la teinte
      a travers les affectations, les appels de procedures et les
      expressions.

  15. Implementer les fonctions d'agregation du langage QL : count,
      sum, min, max, avg, rank, concat, strictcount, strictsum,
      strictconcat, avec gestion des clauses group by et order by
      dans les expressions select.

  16. Implementer l'evaluation des requetes recursives : detection des
      predicats mutuellement recursifs, evaluation par point fixe
      (iteration jusqu'a stabilisation), gestion de la negation
      stratifiee pour eviter les cycles negatifs.

  17. Implementer les requetes de securite integrees pour Pascal :
      detection d'injection de commandes (Exec avec donnees non
      validees), detection de debordement de tampon (acces a un
      tableau avec un indice non verifie), detection de fuites de
      ressources (fichiers ouverts non fermes), detection
      d'utilisation de variables non initialisees.

  18. Implementer la sortie au format SARIF (Static Analysis Results
      Interchange Format) : generation d'un fichier JSON conforme
      au schema SARIF v2.1.0 avec les runs, les resultats, les
      locations (fichier, ligne, colonne), les messages, les
      niveaux de severite (error, warning, note), et les
      codeFlows pour le suivi de teinte.

  19. Implementer la sortie au format CSV et texte : generation de
      tableaux de resultats formattes avec les colonnes selectionnees,
      option --format=csv pour le format separe par des virgules,
      option --format=text pour l'affichage tabule en console, avec
      tri et pagination des resultats.

  20. Implementer le systeme d'import et de modules QL : resolution des
      chemins d'import (import pascal, import semmle.code.pascal),
      chargement des bibliotheques de requetes depuis --search-path,
      gestion des espaces de noms et des alias de modules.

  21. Implementer la bibliotheque standard de predicats QL pour Pascal :
      classes de base (Element, Locatable, Expr, Stmt, Function,
      Variable, Type, Call, Access, Comment), predicats utilitaires
      (hasName, getType, getAChild, getLocation, getEnclosingFunction,
      getAnArgument, getTarget, flowsTo).

  22. Implementer la commande "codeql database create" : orchestration
      complete de la creation de la base de donnees a partir d'un
      repertoire de sources Pascal (parcours recursif des fichiers
      .pas et .pp, extraction de chaque fichier, ecriture de la base
      de donnees dans le repertoire de sortie specifie).

  23. Implementer la commande "codeql database analyze" : chargement
      de la base de donnees, chargement et compilation des suites de
      requetes (.ql et .qls), execution sequentielle de toutes les
      requetes, collecte et fusion des resultats, generation du
      rapport final au format choisi (SARIF, CSV, texte).

  24. Implementer la commande "codeql query run" : chargement de la
      base de donnees, compilation et execution d'une seule requete
      QL specifiee en argument, affichage des resultats sur la
      sortie standard, mode interactif (REPL) avec l'option
      --interactive pour executer des requetes une par une.

  25. Implementer la generation finale et les fichiers exemples :
      creation de 10 requetes exemples dans un repertoire SAMPLES
      (variables non initialisees, fichiers non fermes, debordement
      de tampon, injection de commandes, code mort, complexite
      cyclomatique, convention de nommage, parametres inutilises,
      code duplique, utilisation de Goto), documentation d'aide,
      nettoyage des ressources.
}

Program CODEQL;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}
{$I-}

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
    CMD_DB_INTERPRET_RESULTS
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
    SNK_TYPE_STRING, SNK_FIELD_DECL, SNK_RECORD_SECTION
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
  WriteLn('  database create   <db> --source-root=<dir> [--language=pascal]');
  WriteLn('  database analyze  <db> [suite.qls] [--format=sarif|csv|text]');
  WriteLn('  query run         --database=<db> <query.ql>');
  WriteLn('  database interpret-results <db> [--format=sarif|csv|text]');
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
  End;
End;

{ ---- Stubs des sous-commandes (TODO 22-24) ----------------- }

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
    (S = 'count');
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

  { count/any/none(Type var | formula) or count(expr) }
  If TokIsKw('count') Or TokIsKw('any') Or TokIsKw('none') Then
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
Begin
  N := NewNode(NK_SELECT);
  FromList := -1;
  WhereF   := -1;
  SelList  := -1;

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
      If Nodes[Idx].Name = 'count' Then
        Nodes[Idx].TypeIdx := FindType('int')
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
  Else
    SrcTypeKindToDb := DTK_NONE;
  End;
End;

{ ---- Teste si un noeud est une expression --------------------- }

Function IsExprNode(K : TSrcNodeKind) : Boolean;
Begin
  IsExprNode := (K >= SNK_EXPR_BINOP) And (K <= SNK_EXPR_RANGE);
End;

{ ---- Teste si un noeud est une instruction -------------------- }

Function IsStmtNode(K : TSrcNodeKind) : Boolean;
Begin
  IsStmtNode := (K >= SNK_ASSIGN) And (K <= SNK_COMPOUND);
End;

{ ---- Teste si un noeud est un type ---------------------------- }

Function IsTypeNode(K : TSrcNodeKind) : Boolean;
Begin
  IsTypeNode := (K >= SNK_TYPE_IDENT) And (K <= SNK_TYPE_STRING);
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

{ ---- Stubs des sous-commandes (TODO 22-24) ----------------- }

Procedure RunDatabaseCreate;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('database create: ', Opts.DatabasePath);
  WriteLn('  source-root: ', Opts.SourceDir);
  WriteLn('  language: ', Opts.Language);
  WriteLn('(non implemente)');
End;

Procedure RunDatabaseAnalyze;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('database analyze: ', Opts.DatabasePath);
  If Opts.QueryFile <> '' Then
    WriteLn('  suite: ', Opts.QueryFile);
  WriteLn('  format: ', Ord(Opts.Format));
  WriteLn('(non implemente)');
End;

Procedure RunQueryRun;
Begin
  If Opts.Verbose Then
    ShowBanner;
  If Opts.Interactive Then
    WriteLn('query run: mode interactif (REPL)')
  Else
    WriteLn('query run: ', Opts.QueryFile);
  WriteLn('  database: ', Opts.DatabasePath);

  { TODO 3 : parser le fichier QL si specifie }
  If Opts.QueryFile <> '' Then
  Begin
    Assign(LexSrcF, Opts.QueryFile);
    {$I-}
    Reset(LexSrcF);
    {$I+}
    If IOResult <> 0 Then
    Begin
      WriteLn('CODEQL: impossible d''ouvrir: ', Opts.QueryFile);
      Exit;
    End;
    LexOpened := True;
    LexInit;
    ASTInit;
    InitTypeSystem;
    RootNode := ParseModule;
    WriteLn('Parsing termine : ', NodeCount, ' noeuds AST');
    WriteLn('Lignes lues     : ', TotalLines);
    WriteLn;

    { TODO 4 : verification des types }
    TypeCheckAST;
    WriteLn('Types resolus   : ', TypeCount, ' types enregistres');
    WriteLn('Erreurs de type : ', TypeErrors);
    WriteLn;

    If Opts.DebugMode Then
    Begin
      DumpTypes;
      DumpAST(RootNode, 0);
    End;
    LexClose;
  End
  Else
    WriteLn('(non implemente)');
End;

Procedure RunInterpretResults;
Begin
  If Opts.Verbose Then
    ShowBanner;
  WriteLn('database interpret-results: ', Opts.DatabasePath);
  WriteLn('(non implemente)');
End;

{ ---- Dispatch de la sous-commande -------------------------- }

Procedure Run;
Begin
  Case Opts.SubCmd Of
    CMD_DATABASE_CREATE         : RunDatabaseCreate;
    CMD_DATABASE_ANALYZE        : RunDatabaseAnalyze;
    CMD_QUERY_RUN               : RunQueryRun;
    CMD_DB_INTERPRET_RESULTS    : RunInterpretResults;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
  ParseArgs;
  Run;
End.
