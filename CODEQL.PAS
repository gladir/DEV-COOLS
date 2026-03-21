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
      aux tableaux, acces aux champs de records).

  7.  Implementer la representation de la base de donnees relationnelle
      CodeQL : schema des tables (programs, files, locations, exprs,
      stmts, functions, variables, types, calls, accesses, comments,
      diagnostics), definition des colonnes et des cles primaires,
      relations entre les tables.

  8.  Implementer le stockage de la base de donnees sur disque : format
      de fichier binaire pour les tables, index sur les colonnes cles,
      lecture et ecriture sequentielle et aleatoire des enregistrements,
      gestion d'un repertoire de base de donnees avec un fichier par
      table.

  9.  Implementer l'extraction (extracteur) : parcours de l'AST du code
      source Pascal et insertion des enregistrements dans les tables de
      la base de donnees (un enregistrement par noeud AST, avec les
      positions source, les types resolus, les relations parent-enfant).

  10. Implementer la hierarchie de classes QL et l'heritage : resolution
      des classes de base et des classes derivees, gestion du mot-cle
      extends, methodes heritees et surchargees (override), predicats
      caracteristiques (characteristic predicates), classes abstraites.

  11. Implementer le moteur d'evaluation des predicats QL : evaluation
      des predicats non-recursifs, liaison des variables (binding),
      jointures entre les tables de la base de donnees, filtrage par
      les formules where, retour des tuples de resultats.

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

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
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
