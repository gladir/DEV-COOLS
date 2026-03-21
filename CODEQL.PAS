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
      WarnMsg, ShowBanner, ShowUsage.

  2.  Implementer le lexeur pour le langage de requete QL : TTokenKind
      (TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT, TK_KEYWORD,
      TK_OP, TK_PUNCT, TK_COMMENT, TK_ANNOTATION), LexInit, LexClose,
      LexNextToken, reconnaissance des mots-cles QL (select, from,
      where, import, class, extends, predicate, result, exists, forall,
      not, and, or, implies, if, then, else, in, module, override,
      abstract, private, this, super, instanceof, any, none, count).

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

Begin
End.
