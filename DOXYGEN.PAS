{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
  @description: Clone de la commande doxygen - generateur de documentation
                a partir de code source annote.
                Supporte C, C++, Pascal, Ada, Fortran, Java, Python, ...
  @license: MIT
}

(* ============================================================
  DOXYGEN.PAS - Clone de la commande Doxygen
  Turbo Pascal / Free Pascal (-Mtp)

  Generateur de documentation a partir de code source annote.
  Extrait les commentaires de documentation des fichiers sources
  et genere une documentation structuree en HTML, LaTeX, RTF, XML, MAN.

  Usage :
    doxygen [options] [config-file]
    doxygen -g [config-file]
    doxygen -INPUT fichier.c
    doxygen -INPUT fichier.pas

  Options principales :
    -h, --help           : afficher l aide
    -v, --version        : afficher la version
    -g [fichier]         : generer un fichier de configuration (Doxyfile)
    -s                   : mode silencieux (moins de sortie)
    -u                   : mettre a jour un fichier de configuration existant
    -w [format]          : generer un fichier de style (html, latex, rtf)
    -l                   : generer un fichier layout.xml par defaut
    -d [option]          : activer les options de debogage
    -x                   : afficher la configuration expandee
    -e [format]          : generer un fichier d entete pour le format
    -b                   : activer le mode batch (pas d interaction)

  Options personnalisees (DEV-COOLS) :
    -INPUT fichier       : specifier directement un fichier source a analyser
                           (Pascal, C, C++, Ada, Java, Python, Fortran, ...)
                           sans avoir besoin d un fichier de configuration

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
            DOXYGEN_VERSION ('1.0') et DOXYGEN_DATE ('2026-03-29')
            {$IFDEF FPC} {$MODE TP} {$ENDIF} pour compatibilite
            TOptions : record
              ConfigFile   : String   (fichier Doxyfile)
              InputFile    : String   (fichier source direct via -INPUT)
              OutputDir    : String   (repertoire de sortie)
              GenConfig    : Boolean  (generer un Doxyfile avec -g)
              UpdateConfig : Boolean  (mettre a jour un Doxyfile avec -u)
              GenStyle     : Boolean  (generer fichier de style avec -w)
              StyleFormat  : String   (format du style: html/latex/rtf)
              GenLayout    : Boolean  (generer layout.xml avec -l)
              GenHeader    : Boolean  (generer header avec -e)
              HeaderFormat : String   (format du header)
              Verbose      : Boolean  (mode verbeux)
              Quiet        : Boolean  (mode silencieux avec -s)
              DebugMode    : Boolean  (options de debogage avec -d)
              DebugOpts    : String   (options de debogage actives)
              ExpandOnly   : Boolean  (afficher config expandee avec -x)
              BatchMode    : Boolean  (mode batch avec -b)
              ShowVersion  : Boolean  (afficher version avec -v)
              ShowHelp     : Boolean  (afficher aide avec -h)
            End
            Constantes de codes de retour : EXIT_OK = 0, EXIT_ERROR = 1,
              EXIT_USAGE = 2
            Constantes de tailles : MAX_FILES = 4096, MAX_SYMBOLS = 16384,
              MAX_CONFIG_LINES = 2048, MAX_INCLUDE_DEPTH = 64
            Procedure FatalError(Msg: String) : afficher l erreur et
              appeler Halt(EXIT_ERROR)
            Procedure WarnMsg(Msg: String) : afficher un avertissement
            Procedure InfoMsg(Msg: String) : afficher un message si Verbose
            Procedure ParseCommandLine(Var Opts: TOptions) :
              analyser ParamStr(1..ParamCount), detecter les options
              -g / -u / -w / -l / -d / -x / -e / -b / -s / -v / -h / -INPUT
              et le fichier de configuration (dernier argument sans tiret)
            Procedure ShowHelp : afficher la syntaxe complete et les options
            Procedure ShowVersion : afficher la version et la date
            Procedure ShowBanner : afficher la banniere de demarrage
            Programme principal : validation des arguments et appel Run

  TODO 02 - OPTION PERSONNALISEE -INPUT (FICHIER SOURCE DIRECT) [IMPLEMENTE]
            Extension DEV-COOLS : permettre l analyse directe d un fichier
            source sans fichier de configuration Doxyfile.
            Syntaxe : doxygen -INPUT fichier.ext
            Function DetectLanguageFromExt(Const FileName: String): String
              detecter le langage a partir de l extension :
              .pas .pp .p    -> 'Pascal'
              .c .h          -> 'C'
              .cpp .cxx .cc .hpp .hxx -> 'C++'
              .ada .adb .ads -> 'Ada'
              .f .f90 .f95 .for -> 'Fortran'
              .java          -> 'Java'
              .py            -> 'Python'
              .cs            -> 'C#'
              .php           -> 'PHP'
              .js            -> 'JavaScript'
              .rb            -> 'Ruby'
              .pl .pm        -> 'Perl'
              .vb .bas       -> 'Basic'
              .tcl           -> 'Tcl'
              .sql           -> 'SQL'
              .d             -> 'D'
              .rs            -> 'Rust'
              .go            -> 'Go'
              .swift         -> 'Swift'
              .kt .kts       -> 'Kotlin'
              .m .mm         -> 'Objective-C'
              .idl .odl      -> 'IDL'
              autres         -> 'Unknown'
            Procedure ProcessInputFile(Const FileName: String)
              valider que le fichier existe
              detecter le langage avec DetectLanguageFromExt
              creer une configuration minimale en memoire
              lancer l analyse du fichier unique
              generer la documentation dans le repertoire courant
            Procedure ValidateInputFile(Const FileName: String)
              verifier que le fichier existe ({$I-}/{$I+})
              verifier que l extension est reconnue
              afficher un avertissement si langage non supporte

  TODO 03 - LEXEUR DE COMMENTAIRES DE DOCUMENTATION [IMPLEMENTE]
            TDocCommentKind : (DCK_NONE, DCK_JAVADOC, DCK_QT,
              DCK_TRIPLE_SLASH, DCK_EXCLAMATION, DCK_DOXYGEN)
            TDocToken : record
              Kind  : TDocCommentKind (type de commentaire)
              Text  : String          (texte du commentaire)
              Line  : Integer         (numero de ligne)
              Col   : Integer         (colonne de debut)
            End
            Variables globales :
              DocTokens     : Array[1..MAX_DOC_TOKENS] Of TDocToken
              DocTokenCount : Integer
            Function IsDocCommentStart(Const Line: String; Pos: Integer): TDocCommentKind
              detecter le debut d un commentaire de documentation :
              '/**'  -> DCK_JAVADOC    (style Javadoc classique)
              '/*!'  -> DCK_DOXYGEN    (style Doxygen)
              '///'  -> DCK_TRIPLE_SLASH (triple slash C++)
              '//!'  -> DCK_EXCLAMATION  (style Qt)
              '{**'  -> DCK_JAVADOC    (style Pascal/Delphi)
              '(*!'  -> DCK_DOXYGEN    (style Pascal alternatif)
            Procedure ScanDocComment(Var Line: String; Var Pos: Integer;
              Kind: TDocCommentKind; Var Token: TDocToken)
              extraire le contenu du commentaire de documentation
              supprimer les prefixes de ligne (* ou //)
              normaliser les espaces et retours a la ligne
            Procedure ExtractDocComments(Const SourceFile: String)
              ouvrir le fichier source en lecture
              scanner chaque ligne a la recherche de commentaires doc
              accumuler les tokens dans DocTokens[]
              associer chaque commentaire a l entite qui suit

  TODO 04 - PARSER DES BALISES DOXYGEN [A FAIRE]
            TDoxyTagKind : (TAG_UNKNOWN, TAG_PARAM, TAG_RETURN, TAG_RETURNS,
              TAG_BRIEF, TAG_DETAILS, TAG_NOTE, TAG_WARNING, TAG_TODO,
              TAG_BUG, TAG_DEPRECATED, TAG_AUTHOR, TAG_VERSION, TAG_DATE,
              TAG_SINCE, TAG_SEE, TAG_SA, TAG_REF, TAG_LINK, TAG_CODE,
              TAG_ENDCODE, TAG_VERBATIM, TAG_ENDVERBATIM, TAG_EXAMPLE,
              TAG_FILE, TAG_CLASS, TAG_STRUCT, TAG_UNION, TAG_ENUM,
              TAG_VAR, TAG_DEF, TAG_TYPEDEF, TAG_FN, TAG_NAMESPACE,
              TAG_PACKAGE, TAG_INTERFACE, TAG_PROPERTY, TAG_EVENT,
              TAG_RELATES, TAG_RELATED, TAG_MEMBEROF, TAG_INGROUP,
              TAG_DEFGROUP, TAG_ADDTOGROUP, TAG_WEAKGROUP, TAG_NAME,
              TAG_MAINPAGE, TAG_PAGE, TAG_SUBPAGE, TAG_SECTION,
              TAG_SUBSECTION, TAG_PARAGRAPH, TAG_ANCHOR, TAG_IMAGE,
              TAG_DOT, TAG_ENDDOT, TAG_MSC, TAG_ENDMSC, TAG_STARTUML,
              TAG_ENDUML, TAG_HTMLONLY, TAG_ENDHTMLONLY, TAG_LATEXONLY,
              TAG_ENDLATEXONLY, TAG_XMLONLY, TAG_ENDXMLONLY,
              TAG_RTFONLY, TAG_ENDRTFONLY, TAG_MANONLY, TAG_ENDMANONLY,
              TAG_DOCBOOKONLY, TAG_ENDDOCBOOKONLY, TAG_IF, TAG_IFNOT,
              TAG_ELSE, TAG_ELSEIF, TAG_ENDIF, TAG_COND, TAG_ENDCOND,
              TAG_COPYDOC, TAG_COPYBRIEF, TAG_COPYDETAILS, TAG_INCLUDE,
              TAG_INCLUDELINENO, TAG_INCLUDEDOC, TAG_SNIPPET,
              TAG_INTERNAL, TAG_ENDINTERNAL, TAG_PAR, TAG_PARBLOCK,
              TAG_ENDPARBLOCK, TAG_EXCEPTION, TAG_THROW, TAG_THROWS,
              TAG_RETVAL, TAG_TPARAM, TAG_PURE, TAG_STATIC, TAG_PRIVATE,
              TAG_PROTECTED, TAG_PUBLIC, TAG_NOSUBGROUPING,
              TAG_SHOWINITIALIZER, TAG_HIDEINITIALIZER, TAG_CALLGRAPH,
              TAG_HIDECALLGRAPH, TAG_CALLERGRAPH, TAG_HIDECALLERGRAPH,
              TAG_DIR, TAG_DONTINCLUDE, TAG_LINE, TAG_SKIP, TAG_SKIPLINE,
              TAG_UNTIL, TAG_TEST, TAG_XREFITEM, TAG_INVARIANT, TAG_PRE,
              TAG_POST, TAG_ATTENTION, TAG_REMARK, TAG_REMARKS)
            TDoxyTag : record
              Kind      : TDoxyTagKind (type de balise)
              Name      : String       (nom de la balise sans @)
              ParamName : String       (nom du parametre pour @param)
              Content   : String       (contenu textuel de la balise)
              Line      : Integer      (ligne dans le fichier)
            End
            Function ParseTagKind(Const TagName: String): TDoxyTagKind
              convertir le nom de balise en enumeration
              supporter les variantes avec @ et \ (ex: @param et \param)
            Procedure ParseDocComment(Const Comment: String;
              Var Tags: Array Of TDoxyTag; Var TagCount: Integer)
              parser le commentaire de documentation
              extraire chaque balise et son contenu
              gerer les balises multi-lignes
              gerer les balises imbriquees (@code/@endcode, etc.)
            Function GetBriefDescription(Const Tags: Array Of TDoxyTag;
              TagCount: Integer): String
              extraire la description breve (@brief ou premiere phrase)
            Function GetDetailedDescription(Const Tags: Array Of TDoxyTag;
              TagCount: Integer): String
              extraire la description detaillee (@details ou texte apres @brief)

  TODO 05 - LECTURE ET PARSING DU FICHIER DE CONFIGURATION (DOXYFILE) [A FAIRE]
            TConfigOption : record
              Name     : String   (nom de l option, ex: PROJECT_NAME)
              Value    : String   (valeur de l option)
              IsSet    : Boolean  (True si explicitement definie)
              Line     : Integer  (ligne dans le fichier)
            End
            Variables globales :
              Config        : Array[1..MAX_CONFIG_OPTIONS] Of TConfigOption
              ConfigCount   : Integer
              ConfigFile    : String  (chemin du Doxyfile)
            Constantes des options Doxygen (plus de 300 options) :
              OPT_PROJECT_NAME, OPT_PROJECT_NUMBER, OPT_PROJECT_BRIEF,
              OPT_PROJECT_LOGO, OPT_OUTPUT_DIRECTORY, OPT_CREATE_SUBDIRS,
              OPT_ALLOW_UNICODE_NAMES, OPT_OUTPUT_LANGUAGE, OPT_BRIEF_MEMBER_DESC,
              OPT_REPEAT_BRIEF, OPT_ABBREVIATE_BRIEF, OPT_ALWAYS_DETAILED_SEC,
              OPT_INLINE_INHERITED_MEMB, OPT_FULL_PATH_NAMES, OPT_STRIP_FROM_PATH,
              OPT_STRIP_FROM_INC_PATH, OPT_SHORT_NAMES, OPT_JAVADOC_AUTOBRIEF,
              OPT_JAVADOC_BANNER, OPT_QT_AUTOBRIEF, OPT_MULTILINE_CPP_IS_BRIEF,
              OPT_PYTHON_DOCSTRING, OPT_INHERIT_DOCS, OPT_SEPARATE_MEMBER_PAGES,
              OPT_TAB_SIZE, OPT_ALIASES, OPT_OPTIMIZE_OUTPUT_FOR_C,
              OPT_OPTIMIZE_OUTPUT_JAVA, OPT_OPTIMIZE_FOR_FORTRAN,
              OPT_OPTIMIZE_OUTPUT_VHDL, OPT_OPTIMIZE_OUTPUT_SLICE,
              OPT_INPUT, OPT_INPUT_ENCODING, OPT_INPUT_FILE_ENCODING,
              OPT_FILE_PATTERNS, OPT_RECURSIVE, OPT_EXCLUDE, OPT_EXCLUDE_SYMLINKS,
              OPT_EXCLUDE_PATTERNS, OPT_EXCLUDE_SYMBOLS, OPT_EXAMPLE_PATH,
              OPT_EXAMPLE_PATTERNS, OPT_EXAMPLE_RECURSIVE, OPT_IMAGE_PATH,
              OPT_GENERATE_HTML, OPT_HTML_OUTPUT, OPT_HTML_FILE_EXTENSION,
              OPT_HTML_HEADER, OPT_HTML_FOOTER, OPT_HTML_STYLESHEET,
              OPT_HTML_EXTRA_STYLESHEET, OPT_HTML_EXTRA_FILES, OPT_HTML_COLORSTYLE,
              OPT_GENERATE_LATEX, OPT_LATEX_OUTPUT, OPT_LATEX_CMD_NAME,
              OPT_GENERATE_RTF, OPT_RTF_OUTPUT, OPT_GENERATE_XML, OPT_XML_OUTPUT,
              OPT_GENERATE_MAN, OPT_MAN_OUTPUT, OPT_MAN_EXTENSION,
              OPT_HAVE_DOT, OPT_DOT_NUM_THREADS, OPT_DOT_FONTNAME,
              OPT_CLASS_GRAPH, OPT_COLLABORATION_GRAPH, OPT_GROUP_GRAPHS,
              OPT_UML_LOOK, OPT_CALL_GRAPH, OPT_CALLER_GRAPH,
              OPT_DIRECTORY_GRAPH, OPT_INCLUDE_GRAPH, OPT_INCLUDED_BY_GRAPH
            Procedure ReadConfigFile(Const FileName: String)
              ouvrir le fichier de configuration en lecture
              parser chaque ligne (format NOM = VALEUR ou NOM += VALEUR)
              gerer les continuations de ligne (\)
              gerer les listes entre parentheses
              gerer les commentaires (#)
              gerer les directives @INCLUDE
              stocker les options dans Config[]
            Function GetConfigValue(Const Name: String): String
              rechercher une option par son nom et retourner sa valeur
            Function GetConfigBool(Const Name: String): Boolean
              retourner True si la valeur est YES/TRUE/1/ON
            Function GetConfigInt(Const Name: String): Integer
              retourner la valeur numerique de l option
            Procedure GenerateDefaultConfig(Const FileName: String)
              generer un fichier Doxyfile avec toutes les options
              par defaut, commente avec des explications

  TODO 06 - TOUTES LES OPTIONS DE LIGNE DE COMMANDE [A FAIRE]
            Implementation complete des options doxygen :
            -g [fichier]    : generer un fichier Doxyfile par defaut
                              si fichier non specifie, utiliser 'Doxyfile'
            -s              : mode silencieux, supprimer les messages d info
            -u [fichier]    : mettre a jour un Doxyfile existant avec les
                              nouvelles options (preserve les valeurs existantes)
            -w html|latex|rtf header|footer|stylesheet [fichier] :
                              generer les fichiers de style par defaut
                              pour le format specifie
            -l [fichier]    : generer DoxygenLayout.xml par defaut
            -d option       : activer les options de debogage :
                              time, extcmd, markdown, filteroutput,
                              validate, plantuml, rtf, qhp, tag, lex, ...
            -x              : afficher la configuration expandee (toutes les
                              valeurs avec les variables et includes resolus)
            -e html|latex [fichier] :
                              generer un fichier d entete pour le format
            -b              : mode batch, pas d interaction utilisateur
            --help, -h, -?  : afficher l aide complete
            --version, -v   : afficher la version
            Procedure ProcessOption_g(Var Opts: TOptions; Const Arg: String)
            Procedure ProcessOption_s(Var Opts: TOptions)
            Procedure ProcessOption_u(Var Opts: TOptions; Const Arg: String)
            Procedure ProcessOption_w(Var Opts: TOptions; Const Args: Array Of String)
            Procedure ProcessOption_l(Var Opts: TOptions; Const Arg: String)
            Procedure ProcessOption_d(Var Opts: TOptions; Const Arg: String)
            Procedure ProcessOption_x(Var Opts: TOptions)
            Procedure ProcessOption_e(Var Opts: TOptions; Const Args: Array Of String)
            Procedure ProcessOption_b(Var Opts: TOptions)

  TODO 07 - DETECTION AUTOMATIQUE DU LANGAGE SOURCE [A FAIRE]
            TSourceLanguage : (LANG_UNKNOWN, LANG_C, LANG_CPP, LANG_JAVA,
              LANG_CSHARP, LANG_PYTHON, LANG_FORTRAN, LANG_VHDL,
              LANG_PASCAL, LANG_ADA, LANG_PHP, LANG_JAVASCRIPT,
              LANG_PERL, LANG_RUBY, LANG_TCL, LANG_SQL, LANG_D,
              LANG_IDL, LANG_OBJC, LANG_SLICE, LANG_LEX, LANG_RUST,
              LANG_GO, LANG_SWIFT, LANG_KOTLIN, LANG_BASIC, LANG_COBOL)
            Function DetectLanguage(Const FileName: String): TSourceLanguage
              analyser l extension du fichier
              analyser les premieres lignes pour des indices
              (shebang, mots-cles specifiques, etc.)
            Function LanguageToStr(Lang: TSourceLanguage): String
              convertir l enumeration en chaine lisible
            Function LanguageSupportsDocComments(Lang: TSourceLanguage): Boolean
              retourner True si le langage supporte les commentaires
              de documentation Doxygen
            Function GetCommentStyles(Lang: TSourceLanguage): String
              retourner les styles de commentaires supportes par le langage
              ex: C -> '//, /*, /**'
              ex: Pascal -> '{, (*, {**, (*!'

  TODO 08 - EXTRACTION DES ENTITES DOCUMENTEES [A FAIRE]
            TEntityKind : (ENT_UNKNOWN, ENT_FILE, ENT_NAMESPACE, ENT_CLASS,
              ENT_STRUCT, ENT_UNION, ENT_INTERFACE, ENT_ENUM, ENT_TYPEDEF,
              ENT_FUNCTION, ENT_VARIABLE, ENT_DEFINE, ENT_PROPERTY,
              ENT_SIGNAL, ENT_SLOT, ENT_FRIEND, ENT_MODULE, ENT_GROUP,
              ENT_PAGE, ENT_EXAMPLE, ENT_DIR, ENT_CONCEPT, ENT_SEQUENCE,
              ENT_DICTIONARY, ENT_SERVICE, ENT_SINGLETON, ENT_EXCEPTION)
            TEntityVisibility : (VIS_PUBLIC, VIS_PROTECTED, VIS_PRIVATE,
              VIS_PACKAGE)
            TEntity : record
              Kind        : TEntityKind    (type d entite)
              Name        : String         (nom de l entite)
              FullName    : String         (nom qualifie complet)
              FileName    : String         (fichier source)
              Line        : Integer        (ligne de debut)
              EndLine     : Integer        (ligne de fin)
              Visibility  : TEntityVisibility (visibilite)
              IsStatic    : Boolean        (membre statique)
              IsConst     : Boolean        (constante)
              IsVirtual   : Boolean        (virtuelle)
              IsAbstract  : Boolean        (abstraite)
              IsFinal     : Boolean        (finale)
              IsOverride  : Boolean        (override)
              IsInline    : Boolean        (inline)
              IsExplicit  : Boolean        (explicit)
              IsTemplate  : Boolean        (template/generic)
              ReturnType  : String         (type de retour)
              Parameters  : String         (liste des parametres)
              Signature   : String         (signature complete)
              ParentId    : Integer        (ID de l entite parente)
              DocComment  : String         (commentaire de documentation)
              BriefDesc   : String         (description breve)
              DetailedDesc: String         (description detaillee)
            End
            Variables globales :
              Entities    : Array[1..MAX_SYMBOLS] Of TEntity
              EntityCount : Integer
            Procedure ExtractEntities(Const FileName: String;
              Lang: TSourceLanguage)
              scanner le fichier source et extraire toutes les entites
              associer les commentaires de documentation aux entites
            Procedure ExtractEntitiesC(Const FileName: String)
              extraction specifique pour C/C++
            Procedure ExtractEntitiesPascal(Const FileName: String)
              extraction specifique pour Pascal
            Procedure ExtractEntitiesJava(Const FileName: String)
              extraction specifique pour Java
            Procedure ExtractEntitiesPython(Const FileName: String)
              extraction specifique pour Python

  TODO 09 - ANALYSE DES HIERARCHIES DE CLASSES [A FAIRE]
            TClassRelation : (REL_INHERITS, REL_IMPLEMENTS, REL_USES,
              REL_CONTAINS, REL_AGGREGATES, REL_ASSOCIATES, REL_DEPENDS,
              REL_FRIEND)
            TInheritance : record
              ChildId    : Integer       (ID de la classe enfant)
              ParentId   : Integer       (ID de la classe parente)
              ParentName : String        (nom de la classe parente)
              Relation   : TClassRelation(type de relation)
              Visibility : TEntityVisibility (visibilite de l heritage)
              IsVirtual  : Boolean       (heritage virtuel)
            End
            Variables globales :
              Inheritances     : Array[1..MAX_INHERITANCES] Of TInheritance
              InheritanceCount : Integer
            Procedure BuildClassHierarchy
              parcourir toutes les entites de type classe/interface
              extraire les relations d heritage et d implementation
              construire l arbre de hierarchie
            Function GetBaseClasses(EntityId: Integer): String
              retourner la liste des classes de base
            Function GetDerivedClasses(EntityId: Integer): String
              retourner la liste des classes derivees
            Function GetImplementedInterfaces(EntityId: Integer): String
              retourner la liste des interfaces implementees
            Procedure DetectDiamondInheritance
              detecter et signaler les heritages en diamant

  TODO 10 - ANALYSE DES DEPENDANCES (INCLUDE, USES, IMPORT) [A FAIRE]
            TDependencyKind : (DEP_INCLUDE, DEP_INCLUDE_LOCAL, DEP_IMPORT,
              DEP_USES, DEP_REQUIRE, DEP_MODULE, DEP_PACKAGE, DEP_FROM)
            TDependency : record
              SourceFile : String        (fichier qui depend)
              TargetFile : String        (fichier dont on depend)
              Kind       : TDependencyKind (type de dependance)
              Line       : Integer       (ligne de la directive)
              IsSystem   : Boolean       (include systeme <> ou local "")
            End
            Variables globales :
              Dependencies    : Array[1..MAX_DEPENDENCIES] Of TDependency
              DependencyCount : Integer
            Procedure ExtractDependencies(Const FileName: String;
              Lang: TSourceLanguage)
              scanner le fichier et extraire les directives de dependance
              #include, import, uses, require, from...import
            Function ResolveDependencyPath(Const FileName: String;
              Const IncludePath: String): String
              resoudre le chemin complet d un fichier inclus
              en parcourant les repertoires d include
            Procedure BuildDependencyGraph
              construire le graphe de dependances complet
              detecter les dependances circulaires
            Function GetFileDependencies(Const FileName: String): String
              retourner la liste des dependances d un fichier
            Function GetFileDependents(Const FileName: String): String
              retourner la liste des fichiers qui dependent de ce fichier

  TODO 11 - GENERATION DE LA TABLE DES MATIERES ET INDEX [A FAIRE]
            TIndexEntry : record
              Name       : String   (nom pour l index)
              EntityId   : Integer  (ID de l entite)
              FileName   : String   (fichier de documentation)
              Anchor     : String   (ancre HTML)
              Kind       : TEntityKind (type d entite)
              SortKey    : String   (cle de tri)
            End
            Variables globales :
              IndexEntries : Array[1..MAX_INDEX_ENTRIES] Of TIndexEntry
              IndexCount   : Integer
            Procedure BuildIndex
              parcourir toutes les entites documentees
              creer une entree d index pour chaque
              trier par nom alphabetique
            Procedure BuildClassIndex
              construire l index des classes/structures/interfaces
            Procedure BuildFileIndex
              construire l index des fichiers documentes
            Procedure BuildNamespaceIndex
              construire l index des namespaces/packages/modules
            Procedure BuildFunctionIndex
              construire l index des fonctions/methodes/procedures
            Procedure BuildVariableIndex
              construire l index des variables/constantes/defines
            Procedure BuildPageIndex
              construire l index des pages personnalisees (@page)
            Procedure BuildGroupIndex
              construire l index des groupes (@defgroup)
            Procedure GenerateTOC(Var OutFile: Text)
              generer la table des matieres hierarchique

  TODO 12 - GENERATION DE LA DOCUMENTATION HTML [A FAIRE]
            Variables globales :
              HtmlOutputDir : String  (repertoire de sortie HTML)
              HtmlHeader    : String  (contenu du header HTML)
              HtmlFooter    : String  (contenu du footer HTML)
              HtmlStylesheet: String  (feuille de style CSS)
            Procedure InitHtmlGenerator
              initialiser les templates HTML (header, footer, CSS)
              creer le repertoire de sortie si necessaire
            Procedure GenerateHtmlFile(Const Entity: TEntity;
              Var OutFile: Text)
              generer la page HTML pour une entite
              inclure le header, la documentation, le footer
            Procedure GenerateHtmlIndex(Var OutFile: Text)
              generer la page d index principale (index.html)
            Procedure GenerateHtmlClasses(Var OutFile: Text)
              generer la page de liste des classes (classes.html)
            Procedure GenerateHtmlFiles(Var OutFile: Text)
              generer la page de liste des fichiers (files.html)
            Procedure GenerateHtmlNamespaces(Var OutFile: Text)
              generer la page de liste des namespaces (namespaces.html)
            Procedure GenerateHtmlHierarchy(Var OutFile: Text)
              generer la page de hierarchie de classes (hierarchy.html)
            Procedure GenerateHtmlSearch
              generer les fichiers de recherche JavaScript
            Procedure CopyHtmlResources
              copier les fichiers CSS, JS, images necessaires
            Procedure GenerateHtmlDocumentation
              orchestrateur : generer toute la documentation HTML

  TODO 13 - GENERATION DE LA DOCUMENTATION LATEX [A FAIRE]
            Variables globales :
              LatexOutputDir  : String  (repertoire de sortie LaTeX)
              LatexHeader     : String  (preambule LaTeX)
              LatexFooter     : String  (fin du document LaTeX)
              LatexCmdName    : String  (commande LaTeX a utiliser)
              LatexCompactMode: Boolean (mode compact)
              LatexPaperType  : String  (a4, letter, etc.)
            Procedure InitLatexGenerator
              initialiser les templates LaTeX
              creer le repertoire de sortie
            Function EscapeLatex(Const S: String): String
              echapper les caracteres speciaux LaTeX
              (\ -> \textbackslash, & -> \&, % -> \%, etc.)
            Procedure GenerateLatexFile(Const Entity: TEntity;
              Var OutFile: Text)
              generer la section LaTeX pour une entite
            Procedure GenerateLatexMain(Var OutFile: Text)
              generer le fichier principal refman.tex
              avec les \input pour chaque fichier
            Procedure GenerateLatexClasses(Var OutFile: Text)
              generer le chapitre des classes
            Procedure GenerateLatexFiles(Var OutFile: Text)
              generer le chapitre des fichiers
            Procedure GenerateLatexMakefile
              generer le Makefile pour compiler le LaTeX
            Procedure GenerateLatexDocumentation
              orchestrateur : generer toute la documentation LaTeX

  TODO 14 - GENERATION DE LA DOCUMENTATION RTF [A FAIRE]
            Variables globales :
              RtfOutputDir   : String  (repertoire de sortie RTF)
              RtfStylesheet  : String  (fichier de styles RTF)
              RtfExtensions  : String  (extensions RTF a utiliser)
            Procedure InitRtfGenerator
              initialiser les parametres RTF
              creer le repertoire de sortie
            Function EscapeRtf(Const S: String): String
              echapper les caracteres speciaux RTF
              (\ -> \\, { -> \{, } -> \}, etc.)
            Procedure WriteRtfHeader(Var OutFile: Text)
              ecrire l entete RTF avec les polices et styles
            Procedure WriteRtfFooter(Var OutFile: Text)
              ecrire la fin du document RTF
            Procedure GenerateRtfFile(Const Entity: TEntity;
              Var OutFile: Text)
              generer le contenu RTF pour une entite
            Procedure GenerateRtfDocumentation
              orchestrateur : generer la documentation RTF complete
              (fichier unique refman.rtf)

  TODO 15 - GENERATION DE LA DOCUMENTATION XML [A FAIRE]
            Variables globales :
              XmlOutputDir : String  (repertoire de sortie XML)
              XmlSchemaLoc : String  (emplacement du schema XSD)
            Procedure InitXmlGenerator
              initialiser les parametres XML
              creer le repertoire de sortie
            Function EscapeXml(Const S: String): String
              echapper les caracteres speciaux XML
              (< -> &lt;, > -> &gt;, & -> &amp;, " -> &quot;)
            Procedure GenerateXmlIndex(Var OutFile: Text)
              generer le fichier index.xml avec la liste des
              fichiers XML generes
            Procedure GenerateXmlCompound(Const Entity: TEntity;
              Var OutFile: Text)
              generer le fichier XML pour un compound (classe, fichier, etc.)
            Procedure GenerateXmlMember(Const Entity: TEntity;
              Var OutFile: Text)
              generer la section XML pour un membre
            Procedure GenerateXmlDocumentation
              orchestrateur : generer toute la documentation XML
              compatible avec le format Doxygen XML natif

  TODO 16 - GENERATION DE LA DOCUMENTATION MAN PAGES [A FAIRE]
            Variables globales :
              ManOutputDir : String  (repertoire de sortie man)
              ManExtension : String  (extension des pages man, ex: .3)
              ManSubdir    : String  (sous-repertoire man3, man7, etc.)
            Procedure InitManGenerator
              initialiser les parametres man pages
              creer le repertoire de sortie
            Function EscapeMan(Const S: String): String
              echapper les caracteres speciaux man
              (- -> \-, etc.)
            Procedure GenerateManPage(Const Entity: TEntity;
              Var OutFile: Text)
              generer la page man pour une entite (fonction, structure)
              format groff/nroff standard
            Procedure GenerateManHeader(Var OutFile: Text;
              Const Name, Section, Date, Source, Manual: String)
              ecrire l entete .TH de la page man
            Procedure GenerateManSection(Var OutFile: Text;
              Const Title: String)
              ecrire une section .SH
            Procedure GenerateManDocumentation
              orchestrateur : generer toutes les pages man

  TODO 17 - GENERATION DES GRAPHES D'APPELS (CALL GRAPHS) [A FAIRE]
            TCallGraphNode : record
              EntityId   : Integer   (ID de la fonction)
              Name       : String    (nom de la fonction)
              FileName   : String    (fichier source)
              Line       : Integer   (ligne de definition)
            End
            TCallGraphEdge : record
              CallerId   : Integer   (ID de l appelant)
              CalleeId   : Integer   (ID de l appele)
              Line       : Integer   (ligne de l appel)
              IsDirect   : Boolean   (appel direct vs pointeur)
            End
            Variables globales :
              CallGraphNodes : Array[1..MAX_CALL_NODES] Of TCallGraphNode
              CallGraphEdges : Array[1..MAX_CALL_EDGES] Of TCallGraphEdge
              CallNodeCount  : Integer
              CallEdgeCount  : Integer
            Procedure BuildCallGraph
              analyser le code source pour detecter les appels
              de fonctions et construire le graphe d appels
            Function GetCallees(EntityId: Integer): String
              retourner la liste des fonctions appelees par EntityId
            Function GetCallers(EntityId: Integer): String
              retourner la liste des fonctions qui appellent EntityId
            Procedure GenerateCallGraphDot(Const Entity: TEntity;
              Var OutFile: Text)
              generer le graphe d appels au format DOT (Graphviz)
            Procedure RenderCallGraphImage(Const DotFile, ImageFile: String)
              invoquer dot pour generer l image (PNG, SVG, etc.)

  TODO 18 - GENERATION DES GRAPHES DE DEPENDANCES (DEPENDENCY GRAPHS) [A FAIRE]
            Procedure GenerateIncludeGraphDot(Const FileName: String;
              Var OutFile: Text)
              generer le graphe d inclusion au format DOT
              (fichiers inclus par ce fichier)
            Procedure GenerateIncludedByGraphDot(Const FileName: String;
              Var OutFile: Text)
              generer le graphe d inclusion inverse au format DOT
              (fichiers qui incluent ce fichier)
            Procedure GenerateDirectoryGraphDot(Const DirPath: String;
              Var OutFile: Text)
              generer le graphe de dependances entre repertoires
            Procedure GenerateModuleGraphDot(Var OutFile: Text)
              generer le graphe de dependances entre modules
            Procedure RenderDependencyGraphImage(Const DotFile, ImageFile: String)
              invoquer dot pour generer l image

  TODO 19 - GENERATION DES DIAGRAMMES DE CLASSES (CLASS DIAGRAMS) [A FAIRE]
            Procedure GenerateClassDiagramDot(Const Entity: TEntity;
              Var OutFile: Text)
              generer le diagramme de classe au format DOT
              montrer les membres, methodes, heritage
            Procedure GenerateCollaborationDiagramDot(Const Entity: TEntity;
              Var OutFile: Text)
              generer le diagramme de collaboration au format DOT
              montrer les relations avec d autres classes
            Procedure GenerateInheritanceDiagramDot(Const Entity: TEntity;
              Var OutFile: Text)
              generer le diagramme d heritage au format DOT
              (classes de base et classes derivees)
            Procedure GenerateUmlDiagramDot(Const Entity: TEntity;
              Var OutFile: Text; UmlLook: Boolean)
              generer le diagramme UML complet au format DOT
            Procedure RenderClassDiagramImage(Const DotFile, ImageFile: String)
              invoquer dot pour generer l image
            Procedure GeneratePlantUml(Const Entity: TEntity;
              Var OutFile: Text)
              generer le code PlantUML pour le diagramme

  TODO 20 - SUPPORT DES MACROS ET PREPROCESSEUR [A FAIRE]
            TMacro : record
              Name       : String   (nom de la macro)
              Parameters : String   (parametres si fonction-like)
              Value      : String   (valeur de substitution)
              FileName   : String   (fichier de definition)
              Line       : Integer  (ligne de definition)
              IsFuncLike : Boolean  (True si macro avec parametres)
              IsVariadic : Boolean  (True si parametres variadiques)
            End
            Variables globales :
              Macros     : Array[1..MAX_MACROS] Of TMacro
              MacroCount : Integer
              PredefinedMacros : Array[1..MAX_PREDEFINED] Of TMacro
              PredefinedCount  : Integer
            Procedure ExtractMacros(Const FileName: String)
              scanner le fichier pour les directives #define
              extraire le nom, les parametres et la valeur
            Function ExpandMacro(Const Name: String;
              Const Args: Array Of String): String
              expander une macro avec les arguments fournis
            Procedure PreprocessFile(Const InFile, OutFile: String)
              preprocesser un fichier C/C++
              gerer #include, #define, #undef, #if, #ifdef, #ifndef,
              #else, #elif, #endif, #pragma, #error, #warning, #line
            Procedure AddPredefinedMacro(Const Name, Value: String)
              ajouter une macro predefinee (option -D de la config)

  TODO 21 - SUPPORT DES ESPACES DE NOMS ET MODULES [A FAIRE]
            TNamespace : record
              Name       : String   (nom du namespace)
              FullName   : String   (nom qualifie complet)
              ParentId   : Integer  (ID du namespace parent)
              FileName   : String   (fichier de definition)
              Line       : Integer  (ligne de debut)
              IsAnonymous: Boolean  (namespace anonyme)
              IsInline   : Boolean  (inline namespace C++11)
            End
            TModule : record
              Name       : String   (nom du module)
              FileName   : String   (fichier source)
              Exports    : String   (liste des exports)
              Imports    : String   (liste des imports)
              IsPartition: Boolean  (partition de module)
            End
            Variables globales :
              Namespaces     : Array[1..MAX_NAMESPACES] Of TNamespace
              NamespaceCount : Integer
              Modules        : Array[1..MAX_MODULES] Of TModule
              ModuleCount    : Integer
            Procedure ExtractNamespaces(Const FileName: String;
              Lang: TSourceLanguage)
              extraire les declarations de namespace/package/module
            Procedure BuildNamespaceHierarchy
              construire la hierarchie des namespaces
            Function GetNamespaceEntities(NamespaceId: Integer): String
              retourner les entites declarees dans un namespace

  TODO 22 - RECHERCHE ET INDEXATION FULL-TEXT [A FAIRE]
            TSearchIndex : record
              Word       : String   (mot indexe)
              EntityId   : Integer  (ID de l entite)
              FileName   : String   (fichier de documentation)
              Anchor     : String   (ancre dans le fichier)
              Score      : Integer  (score de pertinence)
            End
            Variables globales :
              SearchIndex : Array[1..MAX_SEARCH_ENTRIES] Of TSearchIndex
              SearchCount : Integer
            Procedure BuildSearchIndex
              parcourir toutes les entites et leurs descriptions
              extraire les mots significatifs (pas stop words)
              creer les entrees d index de recherche
            Procedure GenerateSearchData
              generer les fichiers de donnees de recherche
              (JavaScript pour recherche cote client)
            Function SearchEntities(Const Query: String): String
              rechercher dans l index et retourner les resultats
              tries par pertinence
            Procedure GenerateSearchHtml
              generer la page HTML de recherche avec le formulaire
            Procedure WriteSearchIndexJs(Var OutFile: Text)
              ecrire l index de recherche au format JavaScript

  TODO 23 - SUPPORT MULTI-FICHIERS ET RECURSIVITE [A FAIRE]
            Variables globales :
              SourceFiles    : Array[1..MAX_FILES] Of String
              SourceCount    : Integer
              ProcessedFiles : Array[1..MAX_FILES] Of String
              ProcessedCount : Integer
            Procedure CollectSourceFiles(Const Path: String;
              Recursive: Boolean)
              parcourir le chemin et collecter tous les fichiers sources
              qui correspondent aux patterns definis (FILE_PATTERNS)
            Function MatchesPattern(Const FileName, Pattern: String): Boolean
              verifier si un nom de fichier correspond a un pattern glob
            Function IsExcluded(Const FileName: String): Boolean
              verifier si un fichier est dans la liste d exclusion
            Procedure ProcessAllFiles
              traiter tous les fichiers sources collectes
              extraire les entites et la documentation de chacun
            Procedure ProcessDirectory(Const DirPath: String)
              traiter un repertoire et ses sous-repertoires
            Function GetRelativePath(Const FullPath, BasePath: String): String
              calculer le chemin relatif d un fichier

  TODO 24 - VALIDATION ET AVERTISSEMENTS [A FAIRE]
            TWarningKind : (WARN_UNDOC_FUNC, WARN_UNDOC_PARAM, WARN_UNDOC_RETURN,
              WARN_UNDOC_CLASS, WARN_UNDOC_MEMBER, WARN_UNDOC_FILE,
              WARN_INVALID_TAG, WARN_MISSING_PARAM, WARN_EXTRA_PARAM,
              WARN_TYPE_MISMATCH, WARN_BROKEN_LINK, WARN_DUPLICATE_DOC,
              WARN_CIRCULAR_DEP, WARN_MISSING_INCLUDE, WARN_SYNTAX_ERROR)
            TWarning : record
              Kind     : TWarningKind (type d avertissement)
              FileName : String       (fichier concerne)
              Line     : Integer      (ligne concernee)
              Message  : String       (message d avertissement)
              EntityId : Integer      (entite concernee, ou 0)
            End
            Variables globales :
              Warnings     : Array[1..MAX_WARNINGS] Of TWarning
              WarningCount : Integer
              ErrorCount   : Integer
            Procedure ValidateDocumentation
              verifier que toutes les entites publiques sont documentees
              verifier que tous les parametres sont documentes
              verifier que les types de retour sont documentes
              verifier la coherence des balises @param avec les parametres
            Procedure ValidateLinks
              verifier que tous les @see et @ref pointent vers des
              entites existantes
            Procedure ReportWarning(Kind: TWarningKind;
              Const FileName: String; Line: Integer; Const Msg: String)
              enregistrer un avertissement
            Procedure ReportError(Const FileName: String; Line: Integer;
              Const Msg: String)
              enregistrer une erreur
            Procedure DisplayWarnings
              afficher tous les avertissements collectes
            Function GetUndocumentedEntities: Integer
              retourner le nombre d entites non documentees

  TODO 25 - RAPPORT FINAL ET STATISTIQUES DE COUVERTURE [A FAIRE]
            TStatistics : record
              TotalFiles       : Integer (nombre de fichiers traites)
              TotalLines       : Integer (nombre de lignes de code)
              TotalEntities    : Integer (nombre d entites)
              DocumentedCount  : Integer (entites documentees)
              UndocumentedCount: Integer (entites non documentees)
              WarningCount     : Integer (nombre d avertissements)
              ErrorCount       : Integer (nombre d erreurs)
              ClassCount       : Integer (nombre de classes)
              FunctionCount    : Integer (nombre de fonctions)
              VariableCount    : Integer (nombre de variables)
              NamespaceCount   : Integer (nombre de namespaces)
              PageCount        : Integer (nombre de pages custom)
              GroupCount       : Integer (nombre de groupes)
              CoveragePercent  : Real    (pourcentage de couverture)
              ProcessingTime   : Real    (temps de traitement en secondes)
              OutputSize       : LongInt (taille de la doc generee en octets)
            End
            Variables globales :
              Stats : TStatistics
              StartTime : LongInt
            Procedure CollectStatistics
              parcourir les entites et calculer toutes les statistiques
            Procedure DisplayFinalReport
              afficher le rapport complet :
              '=== DOXYGEN - Rapport de generation ==='
              'Fichiers traites     : ' + IntToStr(Stats.TotalFiles)
              'Lignes de code       : ' + IntToStr(Stats.TotalLines)
              'Entites documentees  : ' + IntToStr(Stats.DocumentedCount)
              'Entites non-doc      : ' + IntToStr(Stats.UndocumentedCount)
              'Couverture           : ' + FloatToStr(Stats.CoveragePercent) + '%'
              '  Classes            : ' + IntToStr(Stats.ClassCount)
              '  Fonctions          : ' + IntToStr(Stats.FunctionCount)
              '  Variables          : ' + IntToStr(Stats.VariableCount)
              '  Namespaces         : ' + IntToStr(Stats.NamespaceCount)
              'Avertissements       : ' + IntToStr(Stats.WarningCount)
              'Erreurs              : ' + IntToStr(Stats.ErrorCount)
              'Temps de traitement  : ' + FloatToStr(Stats.ProcessingTime) + ' s'
              'Taille documentation : ' + FormatSize(Stats.OutputSize)
              Si Verbose : afficher le detail par fichier
            Procedure WriteStatisticsXml(Var OutFile: Text)
              ecrire les statistiques au format XML pour integration CI
            Procedure Run
              orchestrateur principal :
              1. Parser les arguments de la ligne de commande
              2. Si -INPUT : traiter le fichier direct (extension DEV-COOLS)
              3. Sinon : lire le fichier de configuration Doxyfile
              4. Collecter les fichiers sources
              5. Extraire les entites et la documentation
              6. Construire les hierarchies et graphes
              7. Generer la documentation selon les formats actives
              8. Valider et afficher les avertissements
              9. Afficher le rapport final

============================================================ *)

Program DOXYGEN;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  DOXYGEN_VERSION = '1.0';
  DOXYGEN_DATE    = '2026-03-29';

  { Codes de retour }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Tailles maximales }
  MAX_FILES          = 4096;
  MAX_SYMBOLS        = 16384;
  MAX_CONFIG_OPTIONS = 512;
  MAX_CONFIG_LINES   = 2048;
  MAX_INCLUDE_DEPTH  = 64;
  MAX_DOC_TOKENS     = 8192;
  MAX_TAGS           = 256;
  MAX_INHERITANCES   = 4096;
  MAX_DEPENDENCIES   = 8192;
  MAX_INDEX_ENTRIES  = 16384;
  MAX_CALL_NODES     = 8192;
  MAX_CALL_EDGES     = 32768;
  MAX_MACROS         = 4096;
  MAX_PREDEFINED     = 256;
  MAX_NAMESPACES     = 1024;
  MAX_MODULES        = 512;
  MAX_SEARCH_ENTRIES = 65536;
  MAX_WARNINGS       = 4096;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TOptions = Record
    ConfigFile   : String;
    InputFile    : String;
    OutputDir    : String;
    GenConfig    : Boolean;
    UpdateConfig : Boolean;
    GenStyle     : Boolean;
    StyleFormat  : String;
    GenLayout    : Boolean;
    GenHeader    : Boolean;
    HeaderFormat : String;
    Verbose      : Boolean;
    Quiet        : Boolean;
    DebugMode    : Boolean;
    DebugOpts    : String;
    ExpandOnly   : Boolean;
    BatchMode    : Boolean;
    ShowVersion  : Boolean;
    ShowHelp     : Boolean;
  End;

  TSourceLanguage = (LANG_UNKNOWN, LANG_C, LANG_CPP, LANG_JAVA,
    LANG_CSHARP, LANG_PYTHON, LANG_FORTRAN, LANG_VHDL,
    LANG_PASCAL, LANG_ADA, LANG_PHP, LANG_JAVASCRIPT,
    LANG_PERL, LANG_RUBY, LANG_TCL, LANG_SQL, LANG_D,
    LANG_IDL, LANG_OBJC, LANG_SLICE, LANG_LEX, LANG_RUST,
    LANG_GO, LANG_SWIFT, LANG_KOTLIN, LANG_BASIC, LANG_COBOL);

  { Types pour les commentaires de documentation (TODO 03) }
  TDocCommentKind = (DCK_NONE, DCK_JAVADOC, DCK_QT,
    DCK_TRIPLE_SLASH, DCK_EXCLAMATION, DCK_DOXYGEN);

  TDocToken = Record
    Kind : TDocCommentKind;
    Text : String;
    Line : Integer;
    Col  : Integer;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;

  { Variables pour les commentaires de documentation (TODO 03) }
  DocTokens     : Array[1..MAX_DOC_TOKENS] Of TDocToken;
  DocTokenCount : Integer;

{ ============================================================
  PROCEDURES ET FONCTIONS UTILITAIRES
  ============================================================ }

Function UpStr(Const S: String): String;
Var
  I: Integer;
  R: String;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  UpStr := R;
End;

Function IntToStr(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function FileExists(Const FName: String): Boolean;
Var
  F: File;
Begin
  Assign(F, FName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

Function ExtractExt(Const FName: String): String;
Var
  I: Integer;
Begin
  ExtractExt := '';
  For I := Length(FName) DownTo 1 Do
  Begin
    If FName[I] = '.' Then
    Begin
      ExtractExt := UpStr(Copy(FName, I, Length(FName) - I + 1));
      Exit;
    End;
    If (FName[I] = '/') Or (FName[I] = '\') Then Exit;
  End;
End;

Procedure FatalError(Const Msg: String);
Begin
  WriteLn('Erreur: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg: String);
Begin
  If Not Opts.Quiet Then
    WriteLn('Avertissement: ', Msg);
End;

Procedure InfoMsg(Const Msg: String);
Begin
  If Opts.Verbose And (Not Opts.Quiet) Then
    WriteLn(Msg);
End;

{ ============================================================
  DETECTION DU LANGAGE
  ============================================================ }

Function DetectLanguageFromExt(Const FileName: String): TSourceLanguage;
Var
  Ext: String;
Begin
  Ext := ExtractExt(FileName);
  If (Ext = '.PAS') Or (Ext = '.PP') Or (Ext = '.P') Or (Ext = '.DPR') Or (Ext = '.LPR') Then
    DetectLanguageFromExt := LANG_PASCAL
  Else If (Ext = '.C') Or (Ext = '.H') Then
    DetectLanguageFromExt := LANG_C
  Else If (Ext = '.CPP') Or (Ext = '.CXX') Or (Ext = '.CC') Or
          (Ext = '.HPP') Or (Ext = '.HXX') Or (Ext = '.HH') Then
    DetectLanguageFromExt := LANG_CPP
  Else If (Ext = '.JAVA') Then
    DetectLanguageFromExt := LANG_JAVA
  Else If (Ext = '.CS') Then
    DetectLanguageFromExt := LANG_CSHARP
  Else If (Ext = '.PY') Or (Ext = '.PYW') Then
    DetectLanguageFromExt := LANG_PYTHON
  Else If (Ext = '.F') Or (Ext = '.F90') Or (Ext = '.F95') Or
          (Ext = '.F03') Or (Ext = '.FOR') Then
    DetectLanguageFromExt := LANG_FORTRAN
  Else If (Ext = '.VHD') Or (Ext = '.VHDL') Then
    DetectLanguageFromExt := LANG_VHDL
  Else If (Ext = '.ADA') Or (Ext = '.ADB') Or (Ext = '.ADS') Then
    DetectLanguageFromExt := LANG_ADA
  Else If (Ext = '.PHP') Or (Ext = '.PHP3') Or (Ext = '.PHP4') Or (Ext = '.PHP5') Then
    DetectLanguageFromExt := LANG_PHP
  Else If (Ext = '.JS') Or (Ext = '.JSX') Or (Ext = '.MJS') Then
    DetectLanguageFromExt := LANG_JAVASCRIPT
  Else If (Ext = '.PL') Or (Ext = '.PM') Then
    DetectLanguageFromExt := LANG_PERL
  Else If (Ext = '.RB') Or (Ext = '.RBW') Then
    DetectLanguageFromExt := LANG_RUBY
  Else If (Ext = '.TCL') Then
    DetectLanguageFromExt := LANG_TCL
  Else If (Ext = '.SQL') Then
    DetectLanguageFromExt := LANG_SQL
  Else If (Ext = '.D') Then
    DetectLanguageFromExt := LANG_D
  Else If (Ext = '.IDL') Or (Ext = '.ODL') Then
    DetectLanguageFromExt := LANG_IDL
  Else If (Ext = '.M') Or (Ext = '.MM') Then
    DetectLanguageFromExt := LANG_OBJC
  Else If (Ext = '.ICE') Then
    DetectLanguageFromExt := LANG_SLICE
  Else If (Ext = '.L') Or (Ext = '.LL') Then
    DetectLanguageFromExt := LANG_LEX
  Else If (Ext = '.RS') Then
    DetectLanguageFromExt := LANG_RUST
  Else If (Ext = '.GO') Then
    DetectLanguageFromExt := LANG_GO
  Else If (Ext = '.SWIFT') Then
    DetectLanguageFromExt := LANG_SWIFT
  Else If (Ext = '.KT') Or (Ext = '.KTS') Then
    DetectLanguageFromExt := LANG_KOTLIN
  Else If (Ext = '.BAS') Or (Ext = '.VB') Then
    DetectLanguageFromExt := LANG_BASIC
  Else If (Ext = '.COB') Or (Ext = '.CBL') Then
    DetectLanguageFromExt := LANG_COBOL
  Else
    DetectLanguageFromExt := LANG_UNKNOWN;
End;

Function LanguageToStr(Lang: TSourceLanguage): String;
Begin
  Case Lang Of
    LANG_C:          LanguageToStr := 'C';
    LANG_CPP:        LanguageToStr := 'C++';
    LANG_JAVA:       LanguageToStr := 'Java';
    LANG_CSHARP:     LanguageToStr := 'C#';
    LANG_PYTHON:     LanguageToStr := 'Python';
    LANG_FORTRAN:    LanguageToStr := 'Fortran';
    LANG_VHDL:       LanguageToStr := 'VHDL';
    LANG_PASCAL:     LanguageToStr := 'Pascal';
    LANG_ADA:        LanguageToStr := 'Ada';
    LANG_PHP:        LanguageToStr := 'PHP';
    LANG_JAVASCRIPT: LanguageToStr := 'JavaScript';
    LANG_PERL:       LanguageToStr := 'Perl';
    LANG_RUBY:       LanguageToStr := 'Ruby';
    LANG_TCL:        LanguageToStr := 'Tcl';
    LANG_SQL:        LanguageToStr := 'SQL';
    LANG_D:          LanguageToStr := 'D';
    LANG_IDL:        LanguageToStr := 'IDL';
    LANG_OBJC:       LanguageToStr := 'Objective-C';
    LANG_SLICE:      LanguageToStr := 'Slice';
    LANG_LEX:        LanguageToStr := 'Lex';
    LANG_RUST:       LanguageToStr := 'Rust';
    LANG_GO:         LanguageToStr := 'Go';
    LANG_SWIFT:      LanguageToStr := 'Swift';
    LANG_KOTLIN:     LanguageToStr := 'Kotlin';
    LANG_BASIC:      LanguageToStr := 'Basic';
    LANG_COBOL:      LanguageToStr := 'COBOL';
  Else
    LanguageToStr := 'Unknown';
  End;
End;

{ ============================================================
  TODO 03 - LEXEUR DE COMMENTAIRES DE DOCUMENTATION
  ============================================================ }

Function IsDocCommentStart(Const Line: String; Pos: Integer): TDocCommentKind;
{ Detecte le debut d'un commentaire de documentation a la position Pos }
Var
  Remaining: Integer;
Begin
  IsDocCommentStart := DCK_NONE;
  Remaining := Length(Line) - Pos + 1;

  If Remaining < 2 Then Exit;

  { Styles C/C++/Java }
  If Remaining >= 3 Then
  Begin
    { /** - Style Javadoc }
    If (Line[Pos] = '/') And (Line[Pos+1] = '*') And (Line[Pos+2] = '*') Then
    Begin
      { Verifier que ce n'est pas /*** (juste des etoiles decoratives) }
      If (Remaining < 4) Or (Line[Pos+3] <> '*') Then
      Begin
        IsDocCommentStart := DCK_JAVADOC;
        Exit;
      End;
    End;

    { /*! - Style Doxygen }
    If (Line[Pos] = '/') And (Line[Pos+1] = '*') And (Line[Pos+2] = '!') Then
    Begin
      IsDocCommentStart := DCK_DOXYGEN;
      Exit;
    End;

    { /// - Triple slash C++ }
    If (Line[Pos] = '/') And (Line[Pos+1] = '/') And (Line[Pos+2] = '/') Then
    Begin
      { Verifier que ce n'est pas //// (juste des slashes decoratifs) }
      If (Remaining < 4) Or (Line[Pos+3] <> '/') Then
      Begin
        IsDocCommentStart := DCK_TRIPLE_SLASH;
        Exit;
      End;
    End;

    { //! - Style Qt/Exclamation }
    If (Line[Pos] = '/') And (Line[Pos+1] = '/') And (Line[Pos+2] = '!') Then
    Begin
      IsDocCommentStart := DCK_EXCLAMATION;
      Exit;
    End;

    { {** - Style Pascal/Delphi Javadoc }
    If (Line[Pos] = '{') And (Line[Pos+1] = '*') And (Line[Pos+2] = '*') Then
    Begin
      IsDocCommentStart := DCK_JAVADOC;
      Exit;
    End;

    { (*! - Style Pascal Doxygen }
    If (Line[Pos] = '(') And (Line[Pos+1] = '*') And (Line[Pos+2] = '!') Then
    Begin
      IsDocCommentStart := DCK_DOXYGEN;
      Exit;
    End;

    { (** - Style Pascal/OCaml Javadoc }
    If (Line[Pos] = '(') And (Line[Pos+1] = '*') And (Line[Pos+2] = '*') Then
    Begin
      { Verifier que ce n'est pas (*** }
      If (Remaining < 4) Or (Line[Pos+3] <> '*') Then
      Begin
        IsDocCommentStart := DCK_JAVADOC;
        Exit;
      End;
    End;
  End;
End;

Procedure InitDocTokens;
{ Initialise le tableau des tokens de documentation }
Begin
  DocTokenCount := 0;
End;

Procedure AddDocToken(Kind: TDocCommentKind; Const Text: String;
  Line, Col: Integer);
{ Ajoute un token de documentation au tableau }
Begin
  If DocTokenCount < MAX_DOC_TOKENS Then
  Begin
    Inc(DocTokenCount);
    DocTokens[DocTokenCount].Kind := Kind;
    DocTokens[DocTokenCount].Text := Text;
    DocTokens[DocTokenCount].Line := Line;
    DocTokens[DocTokenCount].Col  := Col;
  End
  Else
    WarnMsg('Trop de commentaires de documentation (max=' +
      IntToStr(MAX_DOC_TOKENS) + ')');
End;

Function TrimLeft(Const S: String): String;
{ Supprime les espaces au debut de la chaine }
Var
  I: Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  TrimLeft := Copy(S, I, Length(S) - I + 1);
End;

Function TrimRight(Const S: String): String;
{ Supprime les espaces a la fin de la chaine }
Var
  I: Integer;
Begin
  I := Length(S);
  While (I >= 1) And (S[I] = ' ') Do Dec(I);
  TrimRight := Copy(S, 1, I);
End;

Function TrimStr(Const S: String): String;
{ Supprime les espaces au debut et a la fin }
Begin
  TrimStr := TrimLeft(TrimRight(S));
End;

Function StripLinePrefix(Const Line: String): String;
{ Supprime les prefixes de ligne dans les commentaires multi-lignes
  comme "  * " ou "  // " }
Var
  S: String;
Begin
  S := TrimLeft(Line);

  { Prefixe * pour commentaires C style /** ... */ }
  If (Length(S) >= 1) And (S[1] = '*') Then
  Begin
    S := Copy(S, 2, Length(S) - 1);
    If (Length(S) >= 1) And (S[1] = ' ') Then
      S := Copy(S, 2, Length(S) - 1);
    StripLinePrefix := S;
    Exit;
  End;

  { Prefixe // pour commentaires C++ style /// ou //! }
  If (Length(S) >= 2) And (S[1] = '/') And (S[2] = '/') Then
  Begin
    S := Copy(S, 3, Length(S) - 2);
    { Sauter le / ou ! supplementaire }
    If (Length(S) >= 1) And ((S[1] = '/') Or (S[1] = '!')) Then
      S := Copy(S, 2, Length(S) - 1);
    If (Length(S) >= 1) And (S[1] = ' ') Then
      S := Copy(S, 2, Length(S) - 1);
    StripLinePrefix := S;
    Exit;
  End;

  StripLinePrefix := S;
End;

Procedure ScanDocComment(Var F: Text; Var CurrentLine: String;
  Var LineNum: Integer; Kind: TDocCommentKind; StartCol: Integer;
  Var Token: TDocToken);
{ Extrait le contenu complet d'un commentaire de documentation.
  Gere les commentaires multi-lignes et single-line. }
Var
  Content: String;
  TempLine: String;
  I, EndPos: Integer;
  InMultiLine: Boolean;
  EndMarker: String;
Begin
  Token.Kind := Kind;
  Token.Line := LineNum;
  Token.Col  := StartCol;
  Content := '';

  { Determiner le marqueur de fin selon le type }
  Case Kind Of
    DCK_JAVADOC, DCK_DOXYGEN:
    Begin
      { Commentaires C: /** */ ou /*! */  Pascal: (** *) }
      If CurrentLine[StartCol] = '{' Then
        EndMarker := '}'
      Else If CurrentLine[StartCol] = '(' Then
        EndMarker := '*)'
      Else
        EndMarker := '*/';
      InMultiLine := True;
    End;
    DCK_TRIPLE_SLASH, DCK_EXCLAMATION:
    Begin
      { Commentaires /// ou //! - une seule ligne }
      EndMarker := '';
      InMultiLine := False;
    End;
  Else
    EndMarker := '';
    InMultiLine := False;
  End;

  { Extraire le contenu de la premiere ligne }
  If InMultiLine Then
  Begin
    { Sauter le marqueur de debut (/** ou /*! ou {** ou (**) }
    I := StartCol + 3;
    If I <= Length(CurrentLine) Then
    Begin
      TempLine := Copy(CurrentLine, I, Length(CurrentLine) - I + 1);

      { Verifier si le commentaire se termine sur la meme ligne }
      If EndMarker = '}' Then
        EndPos := System.Pos('}', TempLine)
      Else If EndMarker = '*)' Then
        EndPos := System.Pos('*)', TempLine)
      Else
        EndPos := System.Pos('*/', TempLine);

      If EndPos > 0 Then
      Begin
        { Commentaire sur une seule ligne }
        Content := TrimStr(Copy(TempLine, 1, EndPos - 1));
        Token.Text := Content;
        Exit;
      End
      Else
        Content := StripLinePrefix(TempLine);
    End;

    { Lire les lignes suivantes jusqu'au marqueur de fin }
    While Not Eof(F) Do
    Begin
      ReadLn(F, CurrentLine);
      Inc(LineNum);

      { Chercher le marqueur de fin }
      If EndMarker = '}' Then
        EndPos := System.Pos('}', CurrentLine)
      Else If EndMarker = '*)' Then
        EndPos := System.Pos('*)', CurrentLine)
      Else
        EndPos := System.Pos('*/', CurrentLine);

      If EndPos > 0 Then
      Begin
        { Derniere ligne du commentaire }
        TempLine := Copy(CurrentLine, 1, EndPos - 1);
        TempLine := StripLinePrefix(TempLine);
        If Content <> '' Then Content := Content + ' ';
        Content := Content + TrimStr(TempLine);
        Break;
      End
      Else
      Begin
        { Ligne intermediaire }
        TempLine := StripLinePrefix(CurrentLine);
        If Content <> '' Then Content := Content + ' ';
        Content := Content + TrimStr(TempLine);
      End;
    End;
  End
  Else
  Begin
    { Commentaire single-line (/// ou //!) }
    I := StartCol + 3;
    If I <= Length(CurrentLine) Then
    Begin
      TempLine := Copy(CurrentLine, I, Length(CurrentLine) - I + 1);
      If (Length(TempLine) >= 1) And (TempLine[1] = ' ') Then
        TempLine := Copy(TempLine, 2, Length(TempLine) - 1);
      Content := TrimStr(TempLine);
    End;
  End;

  Token.Text := Content;
End;

Procedure ExtractDocComments(Const SourceFile: String);
{ Ouvre le fichier source et extrait tous les commentaires de documentation }
Var
  F: Text;
  Line: String;
  LineNum, I: Integer;
  Kind: TDocCommentKind;
  Token: TDocToken;
Begin
  InitDocTokens;

  Assign(F, SourceFile);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible d''ouvrir le fichier: ' + SourceFile);
    Exit;
  End;

  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);

    { Scanner la ligne a la recherche de commentaires doc }
    I := 1;
    While I <= Length(Line) Do
    Begin
      { Sauter les espaces }
      While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
      If I > Length(Line) Then Break;

      { Verifier si c'est un debut de commentaire doc }
      Kind := IsDocCommentStart(Line, I);
      If Kind <> DCK_NONE Then
      Begin
        ScanDocComment(F, Line, LineNum, Kind, I, Token);
        If Token.Text <> '' Then
          AddDocToken(Token.Kind, Token.Text, Token.Line, Token.Col);
        Break; { Passer a la ligne suivante }
      End;

      Inc(I);
    End;
  End;

  Close(F);

  InfoMsg('Commentaires de documentation extraits: ' + IntToStr(DocTokenCount));
End;

Procedure ShowVersion;
Begin
  WriteLn('DOXYGEN version ', DOXYGEN_VERSION, ' (', DOXYGEN_DATE, ')');
  WriteLn('Clone de la commande doxygen - Generateur de documentation');
  WriteLn('Partie du projet DEV-COOLS (https://www.gladir.com/dev-cools)');
  WriteLn;
End;

Procedure ShowHelp;
Begin
  ShowVersion;
  WriteLn('Usage: doxygen [options] [config-file]');
  WriteLn;
  WriteLn('Options standard doxygen:');
  WriteLn('  -h, --help        Afficher cette aide et quitter');
  WriteLn('  -v, --version     Afficher la version et quitter');
  WriteLn('  -g [fichier]      Generer un fichier de configuration (Doxyfile)');
  WriteLn('  -s                Mode silencieux (moins de sortie)');
  WriteLn('  -u [fichier]      Mettre a jour un Doxyfile existant');
  WriteLn('  -w format args    Generer un fichier de style (html, latex, rtf)');
  WriteLn('  -l [fichier]      Generer un fichier layout.xml par defaut');
  WriteLn('  -d option         Activer les options de debogage');
  WriteLn('  -x                Afficher la configuration expandee');
  WriteLn('  -e format [fich]  Generer un fichier d''entete pour le format');
  WriteLn('  -b                Mode batch (pas d''interaction)');
  WriteLn;
  WriteLn('Options DEV-COOLS (extension):');
  WriteLn('  -INPUT fichier    Analyser directement un fichier source');
  WriteLn('                    sans fichier de configuration');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  doxygen                     Utiliser le Doxyfile du repertoire courant');
  WriteLn('  doxygen myconfig            Utiliser myconfig comme fichier de config');
  WriteLn('  doxygen -g                  Generer un Doxyfile par defaut');
  WriteLn('  doxygen -g myDoxyfile       Generer myDoxyfile');
  WriteLn('  doxygen -INPUT hello.c      Analyser hello.c directement');
  WriteLn('  doxygen -INPUT program.pas  Analyser program.pas directement');
  WriteLn;
  WriteLn('Langages supportes pour -INPUT:');
  WriteLn('  C (.c, .h), C++ (.cpp, .hpp), Pascal (.pas, .pp)');
  WriteLn('  Ada (.ada, .adb, .ads), Java (.java), Python (.py)');
  WriteLn('  C# (.cs), PHP (.php), JavaScript (.js), Fortran (.f90)');
  WriteLn('  Rust (.rs), Go (.go), Swift (.swift), Kotlin (.kt)');
  WriteLn('  Et bien d''autres...');
  WriteLn;
End;

Procedure ShowBanner;
Begin
  If Not Opts.Quiet Then
  Begin
    WriteLn('DOXYGEN ', DOXYGEN_VERSION, ' - Generateur de documentation');
    WriteLn('(c) 2026 Gladir.com - Licence MIT');
    WriteLn;
  End;
End;

{ ============================================================
  PARSING DE LA LIGNE DE COMMANDE
  ============================================================ }

Procedure InitOptions(Var O: TOptions);
Begin
  O.ConfigFile   := '';
  O.InputFile    := '';
  O.OutputDir    := '';
  O.GenConfig    := False;
  O.UpdateConfig := False;
  O.GenStyle     := False;
  O.StyleFormat  := '';
  O.GenLayout    := False;
  O.GenHeader    := False;
  O.HeaderFormat := '';
  O.Verbose      := False;
  O.Quiet        := False;
  O.DebugMode    := False;
  O.DebugOpts    := '';
  O.ExpandOnly   := False;
  O.BatchMode    := False;
  O.ShowVersion  := False;
  O.ShowHelp     := False;
End;

Procedure ParseCommandLine(Var O: TOptions);
Var
  I: Integer;
  Arg, UpperArg: String;
Begin
  InitOptions(O);
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    UpperArg := UpStr(Arg);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '-?') Then
      O.ShowHelp := True
    Else If (Arg = '-v') Or (Arg = '--version') Then
      O.ShowVersion := True
    Else If Arg = '-s' Then
      O.Quiet := True
    Else If Arg = '-b' Then
      O.BatchMode := True
    Else If Arg = '-x' Then
      O.ExpandOnly := True
    Else If Arg = '-g' Then
    Begin
      O.GenConfig := True;
      If (I < ParamCount) And (ParamStr(I + 1)[1] <> '-') Then
      Begin
        Inc(I);
        O.ConfigFile := ParamStr(I);
      End
      Else
        O.ConfigFile := 'Doxyfile';
    End
    Else If Arg = '-u' Then
    Begin
      O.UpdateConfig := True;
      If (I < ParamCount) And (ParamStr(I + 1)[1] <> '-') Then
      Begin
        Inc(I);
        O.ConfigFile := ParamStr(I);
      End;
    End
    Else If Arg = '-l' Then
    Begin
      O.GenLayout := True;
      If (I < ParamCount) And (ParamStr(I + 1)[1] <> '-') Then
      Begin
        Inc(I);
        { Layout file name - ignored for now }
      End;
    End
    Else If Arg = '-w' Then
    Begin
      O.GenStyle := True;
      If I < ParamCount Then
      Begin
        Inc(I);
        O.StyleFormat := ParamStr(I);
      End;
    End
    Else If Arg = '-e' Then
    Begin
      O.GenHeader := True;
      If I < ParamCount Then
      Begin
        Inc(I);
        O.HeaderFormat := ParamStr(I);
      End;
    End
    Else If Arg = '-d' Then
    Begin
      O.DebugMode := True;
      If I < ParamCount Then
      Begin
        Inc(I);
        O.DebugOpts := ParamStr(I);
      End;
    End
    Else If (UpperArg = '-INPUT') Then
    Begin
      { Extension DEV-COOLS : fichier source direct }
      If I < ParamCount Then
      Begin
        Inc(I);
        O.InputFile := ParamStr(I);
      End
      Else
        FatalError('Option -INPUT requiert un nom de fichier');
    End
    Else If Arg = '-V' Then
      O.Verbose := True
    Else If Arg[1] = '-' Then
    Begin
      WarnMsg('Option inconnue: ' + Arg);
    End
    Else
    Begin
      { C'est le fichier de configuration }
      O.ConfigFile := Arg;
    End;

    Inc(I);
  End;
End;

{ ============================================================
  TRAITEMENT DU FICHIER SOURCE DIRECT (-INPUT)
  ============================================================ }

Procedure ValidateInputFile(Const FileName: String);
Var
  Lang: TSourceLanguage;
Begin
  { Verifier que le fichier existe }
  If Not FileExists(FileName) Then
    FatalError('Fichier non trouve: ' + FileName);

  { Verifier que l extension est reconnue }
  Lang := DetectLanguageFromExt(FileName);
  If Lang = LANG_UNKNOWN Then
    WarnMsg('Extension non reconnue pour: ' + FileName + ' - analyse generique');
End;

Procedure ProcessInputFile(Const FileName: String);
Var
  Lang: TSourceLanguage;
  I: Integer;
Begin
  { Valider le fichier d entree }
  ValidateInputFile(FileName);

  { Detecter le langage }
  Lang := DetectLanguageFromExt(FileName);

  InfoMsg('Analyse du fichier: ' + FileName);
  InfoMsg('Langage detecte: ' + LanguageToStr(Lang));

  WriteLn('Traitement de ', FileName, ' (', LanguageToStr(Lang), ')');
  WriteLn;

  { Extraire les commentaires de documentation (TODO 03) }
  ExtractDocComments(FileName);

  If DocTokenCount > 0 Then
  Begin
    WriteLn('Commentaires de documentation trouves: ', DocTokenCount);
    WriteLn;
    For I := 1 To DocTokenCount Do
    Begin
      Write('  [', I, '] Ligne ', DocTokens[I].Line, ': ');
      Case DocTokens[I].Kind Of
        DCK_JAVADOC:      Write('(Javadoc) ');
        DCK_DOXYGEN:      Write('(Doxygen) ');
        DCK_TRIPLE_SLASH: Write('(///) ');
        DCK_EXCLAMATION:  Write('(//!) ');
      End;
      If Length(DocTokens[I].Text) > 60 Then
        WriteLn(Copy(DocTokens[I].Text, 1, 57), '...')
      Else
        WriteLn(DocTokens[I].Text);
    End;
    WriteLn;
  End
  Else
    WriteLn('Aucun commentaire de documentation trouve.');

  WriteLn;
  WriteLn('Note: L''analyse des balises est en cours d''implementation.');
  WriteLn('      Voir les TODOs 04 a 25 pour la feuille de route complete.');
End;

{ ============================================================
  PROCEDURE PRINCIPALE
  ============================================================ }

Procedure Run;
Begin
  ParseCommandLine(Opts);

  If Opts.ShowHelp Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  If Opts.ShowVersion Then
  Begin
    ShowVersion;
    Halt(EXIT_OK);
  End;

  ShowBanner;

  { Extension DEV-COOLS : traitement direct d'un fichier source }
  If Opts.InputFile <> '' Then
  Begin
    ProcessInputFile(Opts.InputFile);
    Halt(EXIT_OK);
  End;

  { Generation d'un fichier de configuration }
  If Opts.GenConfig Then
  Begin
    WriteLn('Generation du fichier de configuration: ', Opts.ConfigFile);
    WriteLn('Note: Cette fonctionnalite est en cours d''implementation.');
    WriteLn('      Voir TODO 05 pour les details.');
    Halt(EXIT_OK);
  End;

  { Mise a jour d'un fichier de configuration }
  If Opts.UpdateConfig Then
  Begin
    WriteLn('Mise a jour du fichier de configuration...');
    WriteLn('Note: Cette fonctionnalite est en cours d''implementation.');
    Halt(EXIT_OK);
  End;

  { Generation de fichier de style }
  If Opts.GenStyle Then
  Begin
    WriteLn('Generation du fichier de style ', Opts.StyleFormat, '...');
    WriteLn('Note: Cette fonctionnalite est en cours d''implementation.');
    Halt(EXIT_OK);
  End;

  { Generation de layout }
  If Opts.GenLayout Then
  Begin
    WriteLn('Generation du fichier layout.xml...');
    WriteLn('Note: Cette fonctionnalite est en cours d''implementation.');
    Halt(EXIT_OK);
  End;

  { Mode normal : lecture du fichier de configuration et generation }
  If Opts.ConfigFile = '' Then
    Opts.ConfigFile := 'Doxyfile';

  If Not FileExists(Opts.ConfigFile) Then
  Begin
    WriteLn('Fichier de configuration non trouve: ', Opts.ConfigFile);
    WriteLn;
    WriteLn('Pour creer un fichier de configuration par defaut, utilisez:');
    WriteLn('  doxygen -g');
    WriteLn;
    WriteLn('Pour analyser directement un fichier source (extension DEV-COOLS):');
    WriteLn('  doxygen -INPUT fichier.c');
    WriteLn('  doxygen -INPUT fichier.pas');
    Halt(EXIT_ERROR);
  End;

  InfoMsg('Lecture du fichier de configuration: ' + Opts.ConfigFile);

  { TODO: Implementer la lecture du Doxyfile et la generation }
  WriteLn('Lecture de ', Opts.ConfigFile, '...');
  WriteLn;
  WriteLn('Note: L''implementation complete est en cours.');
  WriteLn('      Voir les TODOs 05 a 25 pour la feuille de route.');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  Run;
End.
