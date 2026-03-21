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
      forall), expressions select-from-where.

  4.  Implementer le systeme de types du langage QL : types primitifs
      (int, float, string, boolean, date), types de reference vers les
      noeuds de l'AST source (@locatable, @expr, @stmt, @function,
      @class), verification des types dans les predicats et les
      expressions.

  5.  Implementer le lexeur pour le langage source cible (Pascal) :
      TSourceTokenKind, reconnaissance des mots-cles Pascal (program,
      unit, uses, const, type, var, procedure, function, begin, end,
      if, then, else, while, for, repeat, case, with, record, array,
      string, integer, boolean, real), gestion des commentaires
      (accolades, parenthese-etoile, double-barre oblique).

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
