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

  TODO 04 - PARSER DES BALISES DOXYGEN [IMPLEMENTE]
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

  TODO 05 - LECTURE ET PARSING DU FICHIER DE CONFIGURATION (DOXYFILE) [IMPLEMENTE]
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

  TODO 06 - TOUTES LES OPTIONS DE LIGNE DE COMMANDE [IMPLEMENTE]
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

  TODO 07 - DETECTION AUTOMATIQUE DU LANGAGE SOURCE [IMPLEMENTE]
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

  TODO 08 - EXTRACTION DES ENTITES DOCUMENTEES [IMPLEMENTE]
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

  TODO 09 - ANALYSE DES HIERARCHIES DE CLASSES [IMPLEMENTE]
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
            Procedure InitInheritances
              initialise le tableau des heritages
            Procedure AddInheritance(ChildId: Integer; ParentName: String;
              Rel: TClassRelation; Vis: TEntityVisibility; IsVirt: Boolean)
              ajoute une relation d heritage au tableau
            Function ClassRelationToStr(Rel: TClassRelation): String
              convertit un type de relation en chaine
            Function FindEntityByName(Name: String): Integer
              recherche une entite par son nom
            Function IsClassEntity(Kind: TEntityKind): Boolean
              verifie si le type d entite est une classe/struct/interface
            Procedure ParseCppInheritance(Line: String; EntityId: Integer)
              parse les heritages C++ (class Derived : public Base)
            Procedure ParseJavaInheritance(Line: String; EntityId: Integer)
              parse les heritages Java (extends/implements)
            Procedure ParsePascalInheritance(Line: String; EntityId: Integer)
              parse les heritages Pascal (= class(TBase))
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
            Procedure ShowClassHierarchy
              affiche la hierarchie des classes extraite

  TODO 10 - ANALYSE DES DEPENDANCES (INCLUDE, USES, IMPORT) [IMPLEMENTE]
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

  TODO 11 - GENERATION DE LA TABLE DES MATIERES ET INDEX [IMPLEMENTE]
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

  TODO 12 - GENERATION DE LA DOCUMENTATION HTML [IMPLEMENTE]
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

  TODO 13 - GENERATION DE LA DOCUMENTATION LATEX [IMPLEMENTE]
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

  TODO 14 - GENERATION DE LA DOCUMENTATION RTF [IMPLEMENTE]
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

  TODO 15 - GENERATION DE LA DOCUMENTATION XML [IMPLEMENTE]
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

  TODO 16 - GENERATION DE LA DOCUMENTATION MAN PAGES [IMPLEMENTE]
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

  TODO 17 - GENERATION DES GRAPHES D'APPELS (CALL GRAPHS) [IMPLEMENTE]
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
            Procedure InitCallGraph
              initialiser le generateur de graphes d appels
            Procedure BuildCallGraph
              analyser le code source pour detecter les appels
              de fonctions et construire le graphe d appels
            Function FindCallNode(EntityId: Integer): Integer
              trouver un noeud par son EntityId
            Function FindCallNodeByName(Const Name: String): Integer
              trouver un noeud par son nom
            Function AddCallGraphNode(...): Integer
              ajouter un noeud au graphe d appels
            Function AddCallGraphEdge(...): Integer
              ajouter une arete au graphe d appels
            Function GetCallees(EntityId: Integer): String
              retourner la liste des fonctions appelees par EntityId
            Function GetCallers(EntityId: Integer): String
              retourner la liste des fonctions qui appellent EntityId
            Function CountCallees(EntityId: Integer): Integer
              compter le nombre de fonctions appelees
            Function CountCallers(EntityId: Integer): Integer
              compter le nombre de fonctions appelantes
            Procedure GenerateCallGraphDot(Const Entity: TEntity;
              Var OutFile: Text)
              generer le graphe d appels au format DOT (Graphviz)
            Procedure GenerateFullCallGraphDot(Var OutFile: Text)
              generer le graphe d appels complet
            Procedure RenderCallGraphImage(Const DotFile, ImageFile: String)
              invoquer dot pour generer l image (PNG, SVG, etc.)
            Procedure GenerateCallGraphDocumentation
              orchestrateur : generer tous les graphes d appels
            Fonctions accesseurs Get/SetCallGraphOutputDir,
              GetCallNodeCount, GetCallEdgeCount, GetCallGraphNode,
              GetCallGraphEdge, IsCallGraphInitialized, IsCallGraphEmpty,
              HasCallGraphEdge, GetNodeCallees, GetNodeCallers

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

  { Constantes pour la generation HTML (TODO 12) }
  HTML_DOCTYPE       = '<!DOCTYPE html>';
  HTML_CHARSET       = 'UTF-8';
  HTML_CSS_FILE      = 'doxygen.css';
  HTML_JS_FILE       = 'doxygen.js';
  HTML_SEARCH_FILE   = 'search.js';
  HTML_INDEX_FILE    = 'index.html';
  HTML_CLASSES_FILE  = 'classes.html';
  HTML_FILES_FILE    = 'files.html';
  HTML_NAMESPACES_FILE = 'namespaces.html';
  HTML_HIERARCHY_FILE = 'hierarchy.html';
  HTML_SEARCH_DIR    = 'search';

  { Constantes pour la generation LaTeX (TODO 13) }
  LATEX_MAIN_FILE      = 'refman.tex';
  LATEX_CLASSES_FILE   = 'classes.tex';
  LATEX_FILES_FILE     = 'files.tex';
  LATEX_INDEX_FILE     = 'index.tex';
  LATEX_HIERARCHY_FILE = 'hierarchy.tex';
  LATEX_MAKEFILE       = 'Makefile';
  LATEX_DEFAULT_CMD    = 'pdflatex';
  LATEX_DEFAULT_PAPER  = 'a4';

  { Constantes pour la generation RTF (TODO 14) }
  RTF_MAIN_FILE       = 'refman.rtf';
  RTF_CHARSET_ANSI    = 'ansi';
  RTF_FONT_ARIAL      = 'Arial';
  RTF_FONT_COURIER    = 'Courier New';
  RTF_FONT_TIMES      = 'Times New Roman';
  RTF_DEFAULT_FONTSIZE = 20;  { En demi-points (10pt = 20) }
  RTF_TITLE_FONTSIZE  = 48;   { 24pt }
  RTF_HEADING_FONTSIZE = 28;  { 14pt }

  { Constantes pour la generation XML (TODO 15) }
  XML_INDEX_FILE       = 'index.xml';
  XML_COMPOUND_PREFIX  = 'compound_';
  XML_MEMBER_PREFIX    = 'member_';
  XML_SCHEMA_LOC       = 'compound.xsd';
  XML_VERSION          = '1.0';
  XML_ENCODING         = 'UTF-8';
  XML_DOXYFILE_VERSION = '1.9.8';

  { Constantes pour la generation MAN pages (TODO 16) }
  MAN_DEFAULT_EXTENSION = '.3';
  MAN_DEFAULT_SUBDIR    = 'man3';
  MAN_OUTPUT_DIR        = 'man';
  MAN_DATE_FORMAT       = '%B %Y';
  MAN_SOURCE_DEFAULT    = 'Documentation';
  MAN_MANUAL_DEFAULT    = 'Programmer''s Manual';

  { Constantes pour les graphes d'appels (TODO 17) }
  MAX_CALL_NODES        = 8192;
  MAX_CALL_EDGES        = 32768;
  CALLGRAPH_DOT_FILE    = 'callgraph.dot';
  CALLGRAPH_PNG_FILE    = 'callgraph.png';
  CALLGRAPH_SVG_FILE    = 'callgraph.svg';
  CALLGRAPH_OUTPUT_DIR  = 'callgraph';
  CALLGRAPH_NODE_SHAPE  = 'box';
  CALLGRAPH_EDGE_STYLE  = 'solid';
  CALLGRAPH_FONT_NAME   = 'Helvetica';
  CALLGRAPH_FONT_SIZE   = 10;

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

  { Types pour les balises Doxygen (TODO 04) }
  TDoxyTagKind = (
    { Balises inconnues ou texte libre }
    TAG_UNKNOWN, TAG_TEXT,
    { Description }
    TAG_BRIEF, TAG_DETAILS, TAG_SHORT,
    { Parametres et retour }
    TAG_PARAM, TAG_RETURN, TAG_RETURNS, TAG_RETVAL, TAG_TPARAM,
    { Exceptions }
    TAG_EXCEPTION, TAG_THROW, TAG_THROWS,
    { Notes et avertissements }
    TAG_NOTE, TAG_WARNING, TAG_ATTENTION, TAG_REMARK, TAG_REMARKS,
    TAG_TODO, TAG_BUG, TAG_DEPRECATED,
    { Informations sur l'entite }
    TAG_AUTHOR, TAG_AUTHORS, TAG_VERSION, TAG_DATE, TAG_SINCE,
    TAG_COPYRIGHT, TAG_LICENSE,
    { References croisees }
    TAG_SEE, TAG_SA, TAG_REF, TAG_LINK, TAG_ENDLINK,
    { Documentation de code }
    TAG_CODE, TAG_ENDCODE, TAG_VERBATIM, TAG_ENDVERBATIM,
    TAG_EXAMPLE, TAG_SNIPPET, TAG_INCLUDE, TAG_INCLUDELINENO, TAG_INCLUDEDOC,
    { Entites documentees }
    TAG_FILE, TAG_CLASS, TAG_STRUCT, TAG_UNION, TAG_ENUM,
    TAG_VAR, TAG_DEF, TAG_TYPEDEF, TAG_FN, TAG_NAMESPACE,
    TAG_PACKAGE, TAG_INTERFACE, TAG_PROPERTY, TAG_EVENT,
    TAG_RELATES, TAG_RELATED, TAG_RELATESALSO, TAG_MEMBEROF,
    { Groupes }
    TAG_INGROUP, TAG_DEFGROUP, TAG_ADDTOGROUP, TAG_WEAKGROUP, TAG_NAME,
    { Pages et sections }
    TAG_MAINPAGE, TAG_PAGE, TAG_SUBPAGE, TAG_SECTION, TAG_SUBSECTION,
    TAG_PARAGRAPH, TAG_ANCHOR,
    { Multimedia }
    TAG_IMAGE, TAG_DOT, TAG_ENDDOT, TAG_MSC, TAG_ENDMSC,
    TAG_STARTUML, TAG_ENDUML,
    { Formatage conditionnel }
    TAG_HTMLONLY, TAG_ENDHTMLONLY, TAG_LATEXONLY, TAG_ENDLATEXONLY,
    TAG_XMLONLY, TAG_ENDXMLONLY, TAG_RTFONLY, TAG_ENDRTFONLY,
    TAG_MANONLY, TAG_ENDMANONLY, TAG_DOCBOOKONLY, TAG_ENDDOCBOOKONLY,
    { Conditions }
    TAG_IF, TAG_IFNOT, TAG_ELSE, TAG_ELSEIF, TAG_ENDIF,
    TAG_COND, TAG_ENDCOND,
    { Copie de documentation }
    TAG_COPYDOC, TAG_COPYBRIEF, TAG_COPYDETAILS,
    { Sections internes }
    TAG_INTERNAL, TAG_ENDINTERNAL, TAG_PAR, TAG_PARBLOCK, TAG_ENDPARBLOCK,
    { Visibilite }
    TAG_PURE, TAG_STATIC, TAG_PRIVATE, TAG_PROTECTED, TAG_PUBLIC,
    { Affichage }
    TAG_NOSUBGROUPING, TAG_SHOWINITIALIZER, TAG_HIDEINITIALIZER,
    TAG_CALLGRAPH, TAG_HIDECALLGRAPH, TAG_CALLERGRAPH, TAG_HIDECALLERGRAPH,
    { Divers }
    TAG_DIR, TAG_DONTINCLUDE, TAG_LINE, TAG_SKIP, TAG_SKIPLINE, TAG_UNTIL,
    TAG_TEST, TAG_XREFITEM, TAG_INVARIANT, TAG_PRE, TAG_POST
  );

  TDoxyTag = Record
    Kind      : TDoxyTagKind;
    Name      : String;
    ParamName : String;
    Content   : String;
    Line      : Integer;
  End;

  { Types pour la configuration Doxyfile (TODO 05) }
  TConfigOption = Record
    Name   : String;    { Nom de l'option, ex: PROJECT_NAME }
    Value  : String;    { Valeur de l'option }
    IsSet  : Boolean;   { True si explicitement definie }
    Line   : Integer;   { Ligne dans le fichier }
  End;

  { Types pour l'extraction des entites (TODO 08) }
  TEntityKind = (ENT_UNKNOWN, ENT_FILE, ENT_NAMESPACE, ENT_CLASS,
    ENT_STRUCT, ENT_UNION, ENT_INTERFACE, ENT_ENUM, ENT_TYPEDEF,
    ENT_FUNCTION, ENT_VARIABLE, ENT_DEFINE, ENT_PROPERTY,
    ENT_SIGNAL, ENT_SLOT, ENT_FRIEND, ENT_MODULE, ENT_GROUP,
    ENT_PAGE, ENT_EXAMPLE, ENT_DIR, ENT_CONCEPT, ENT_SEQUENCE,
    ENT_DICTIONARY, ENT_SERVICE, ENT_SINGLETON, ENT_EXCEPTION);

  TEntityVisibility = (VIS_PUBLIC, VIS_PROTECTED, VIS_PRIVATE,
    VIS_PACKAGE);

  TEntity = Record
    Kind         : TEntityKind;    { Type d entite }
    Name         : String;         { Nom de l entite }
    FullName     : String;         { Nom qualifie complet }
    FileName     : String;         { Fichier source }
    Line         : Integer;        { Ligne de debut }
    EndLine      : Integer;        { Ligne de fin }
    Visibility   : TEntityVisibility; { Visibilite }
    IsStatic     : Boolean;        { Membre statique }
    IsConst      : Boolean;        { Constante }
    IsVirtual    : Boolean;        { Virtuelle }
    IsAbstract   : Boolean;        { Abstraite }
    IsFinal      : Boolean;        { Finale }
    IsOverride   : Boolean;        { Override }
    IsInline     : Boolean;        { Inline }
    IsExplicit   : Boolean;        { Explicit }
    IsTemplate   : Boolean;        { Template/generic }
    ReturnType   : String;         { Type de retour }
    Parameters   : String;         { Liste des parametres }
    Signature    : String;         { Signature complete }
    ParentId     : Integer;        { ID de l entite parente }
    DocComment   : String;         { Commentaire de documentation }
    BriefDesc    : String;         { Description breve }
    DetailedDesc : String;         { Description detaillee }
  End;

  { Types pour l'analyse des hierarchies de classes (TODO 09) }
  TClassRelation = (REL_INHERITS, REL_IMPLEMENTS, REL_USES,
    REL_CONTAINS, REL_AGGREGATES, REL_ASSOCIATES, REL_DEPENDS,
    REL_FRIEND);

  TInheritance = Record
    ChildId    : Integer;           { ID de la classe enfant }
    ParentId   : Integer;           { ID de la classe parente }
    ParentName : String;            { Nom de la classe parente }
    Relation   : TClassRelation;    { Type de relation }
    Visibility : TEntityVisibility; { Visibilite de l heritage }
    IsVirtual  : Boolean;           { Heritage virtuel }
  End;

  { Types pour l'analyse des dependances (TODO 10) }
  TDependencyKind = (DEP_INCLUDE, DEP_INCLUDE_LOCAL, DEP_IMPORT,
    DEP_USES, DEP_REQUIRE, DEP_MODULE, DEP_PACKAGE, DEP_FROM);

  TDependency = Record
    SourceFile : String;            { Fichier qui depend }
    TargetFile : String;            { Fichier dont on depend }
    Kind       : TDependencyKind;   { Type de dependance }
    Line       : Integer;           { Ligne de la directive }
    IsSystem   : Boolean;           { Include systeme <> ou local "" }
  End;

  { Types pour la generation de l'index et table des matieres (TODO 11) }
  TIndexEntry = Record
    Name       : String;            { Nom pour l'index }
    EntityId   : Integer;           { ID de l'entite }
    FileName   : String;            { Fichier de documentation }
    Anchor     : String;            { Ancre HTML }
    Kind       : TEntityKind;       { Type d'entite }
    SortKey    : String;            { Cle de tri }
  End;

  { Types pour les graphes d'appels (TODO 17) }
  TCallGraphNode = Record
    EntityId   : Integer;           { ID de la fonction }
    Name       : String;            { Nom de la fonction }
    FileName   : String;            { Fichier source }
    Line       : Integer;           { Ligne de definition }
    NodeId     : Integer;           { ID unique du noeud }
  End;

  TCallGraphEdge = Record
    CallerId   : Integer;           { ID de l'appelant }
    CalleeId   : Integer;           { ID de l'appele }
    Line       : Integer;           { Ligne de l'appel }
    IsDirect   : Boolean;           { Appel direct vs pointeur }
    EdgeId     : Integer;           { ID unique de l'arete }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;

  { Variables pour les commentaires de documentation (TODO 03) }
  DocTokens     : Array[1..MAX_DOC_TOKENS] Of TDocToken;
  DocTokenCount : Integer;

  { Variables pour les balises Doxygen (TODO 04) }
  DocTags       : Array[1..MAX_TAGS] Of TDoxyTag;
  DocTagCount   : Integer;

  { Variables pour la configuration Doxyfile (TODO 05) }
  Config        : Array[1..MAX_CONFIG_OPTIONS] Of TConfigOption;
  ConfigCount   : Integer;

  { Variables pour l'extraction des entites (TODO 08) }
  Entities      : Array[1..MAX_SYMBOLS] Of TEntity;
  EntityCount   : Integer;

  { Variables pour l'analyse des hierarchies de classes (TODO 09) }
  Inheritances     : Array[1..MAX_INHERITANCES] Of TInheritance;
  InheritanceCount : Integer;

  { Variables pour l'analyse des dependances (TODO 10) }
  Dependencies     : Array[1..MAX_DEPENDENCIES] Of TDependency;
  DependencyCount  : Integer;

  { Variables pour la generation de l'index (TODO 11) }
  IndexEntries     : Array[1..MAX_INDEX_ENTRIES] Of TIndexEntry;
  IndexCount       : Integer;

  { Variables pour la generation HTML (TODO 12) }
  HtmlOutputDir    : String;
  HtmlHeader       : String;
  HtmlFooter       : String;
  HtmlStylesheet   : String;
  HtmlProjectName  : String;
  HtmlProjectBrief : String;
  HtmlTimestamp    : String;
  HtmlInitialized  : Boolean;

  { Variables pour la generation LaTeX (TODO 13) }
  LatexOutputDir   : String;
  LatexHeader      : String;
  LatexFooter      : String;
  LatexCmdName     : String;
  LatexCompactMode : Boolean;
  LatexPaperType   : String;
  LatexProjectName : String;
  LatexProjectBrief: String;
  LatexInitialized : Boolean;

  { Variables pour la generation RTF (TODO 14) }
  RtfOutputDir    : String;
  RtfStylesheet   : String;
  RtfExtensions   : String;
  RtfProjectName  : String;
  RtfProjectBrief : String;
  RtfInitialized  : Boolean;

  { Variables pour la generation XML (TODO 15) }
  XmlOutputDir    : String;
  XmlSchemaLoc    : String;
  XmlProjectName  : String;
  XmlProjectBrief : String;
  XmlInitialized  : Boolean;

  { Variables pour la generation MAN pages (TODO 16) }
  ManOutputDir    : String;
  ManExtension    : String;
  ManSubdir       : String;
  ManProjectName  : String;
  ManProjectBrief : String;
  ManInitialized  : Boolean;

  { Variables pour les graphes d'appels (TODO 17) }
  CallGraphNodes    : Array[1..MAX_CALL_NODES] Of TCallGraphNode;
  CallGraphEdges    : Array[1..MAX_CALL_EDGES] Of TCallGraphEdge;
  CallNodeCount     : Integer;
  CallEdgeCount     : Integer;
  CallGraphOutputDir: String;
  CallGraphInitialized : Boolean;

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
  TODO 07 - DETECTION AUTOMATIQUE DU LANGAGE SOURCE
  ============================================================ }

Function LanguageSupportsDocComments(Lang: TSourceLanguage): Boolean;
{ Retourne True si le langage supporte les commentaires de documentation Doxygen }
Begin
  Case Lang Of
    LANG_C,
    LANG_CPP,
    LANG_JAVA,
    LANG_CSHARP,
    LANG_D,
    LANG_OBJC,
    LANG_RUST,
    LANG_GO,
    LANG_SWIFT,
    LANG_KOTLIN,
    LANG_JAVASCRIPT:
      LanguageSupportsDocComments := True;
    LANG_PYTHON,
    LANG_PASCAL,
    LANG_ADA,
    LANG_PHP,
    LANG_PERL,
    LANG_RUBY,
    LANG_FORTRAN,
    LANG_VHDL,
    LANG_TCL,
    LANG_SQL,
    LANG_IDL,
    LANG_SLICE,
    LANG_LEX,
    LANG_BASIC,
    LANG_COBOL:
      LanguageSupportsDocComments := True;
  Else
    LanguageSupportsDocComments := False;
  End;
End;

Function GetCommentStyles(Lang: TSourceLanguage): String;
{ Retourne les styles de commentaires supportes par le langage }
Begin
  Case Lang Of
    LANG_C:
      GetCommentStyles := '/* */, //, /** */, /*! */';
    LANG_CPP:
      GetCommentStyles := '/* */, //, /** */, /*! */, ///';
    LANG_JAVA:
      GetCommentStyles := '/* */, //, /** */';
    LANG_CSHARP:
      GetCommentStyles := '/* */, //, /** */, ///, ///';
    LANG_PYTHON:
      GetCommentStyles := '#, """ """, '' '' ''';
    LANG_PASCAL:
      GetCommentStyles := '{ }, (* *), //, {** }, (*! *)';
    LANG_ADA:
      GetCommentStyles := '--';
    LANG_PHP:
      GetCommentStyles := '/* */, //, #, /** */';
    LANG_JAVASCRIPT:
      GetCommentStyles := '/* */, //, /** */';
    LANG_PERL:
      GetCommentStyles := '#, =pod ... =cut';
    LANG_RUBY:
      GetCommentStyles := '#, =begin ... =end';
    LANG_FORTRAN:
      GetCommentStyles := 'C, !, !>';
    LANG_VHDL:
      GetCommentStyles := '--';
    LANG_TCL:
      GetCommentStyles := '#';
    LANG_SQL:
      GetCommentStyles := '--, /* */';
    LANG_D:
      GetCommentStyles := '/* */, //, /** */, /*! */, ///';
    LANG_IDL:
      GetCommentStyles := '/* */, //';
    LANG_OBJC:
      GetCommentStyles := '/* */, //, /** */, /*! */';
    LANG_SLICE:
      GetCommentStyles := '/* */, //';
    LANG_LEX:
      GetCommentStyles := '/* */, //';
    LANG_RUST:
      GetCommentStyles := '/* */, //, /// , //!';
    LANG_GO:
      GetCommentStyles := '/* */, //';
    LANG_SWIFT:
      GetCommentStyles := '/* */, //, /** */, ///';
    LANG_KOTLIN:
      GetCommentStyles := '/* */, //, /** */';
    LANG_BASIC:
      GetCommentStyles := ''''' , REM';
    LANG_COBOL:
      GetCommentStyles := '* (column 7)';
  Else
    GetCommentStyles := 'Unknown';
  End;
End;

Function DetectLanguageFromShebang(Const Line: String): TSourceLanguage;
{ Detecte le langage a partir du shebang (premiere ligne #!...) }
Var
  UpperLine: String;
Begin
  DetectLanguageFromShebang := LANG_UNKNOWN;
  
  If (Length(Line) < 2) Or (Line[1] <> '#') Or (Line[2] <> '!') Then
    Exit;
  
  UpperLine := UpStr(Line);
  
  { Python }
  If (Pos('PYTHON', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_PYTHON
  { Perl }
  Else If (Pos('PERL', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_PERL
  { Ruby }
  Else If (Pos('RUBY', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_RUBY
  { PHP }
  Else If (Pos('PHP', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_PHP
  { Tcl }
  Else If (Pos('TCLSH', UpperLine) > 0) Or (Pos('WISH', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_TCL
  { Bash/Shell (non supporte, mais detecte) }
  Else If (Pos('/SH', UpperLine) > 0) Or (Pos('BASH', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_UNKNOWN
  { Node.js }
  Else If (Pos('NODE', UpperLine) > 0) Then
    DetectLanguageFromShebang := LANG_JAVASCRIPT;
End;

Function DetectLanguageFromContent(Const FileName: String): TSourceLanguage;
{ Analyse les premieres lignes du fichier pour detecter le langage }
Var
  F: Text;
  Line, UpperLine: String;
  LineCount: Integer;
  ShebangLang: TSourceLanguage;
Begin
  DetectLanguageFromContent := LANG_UNKNOWN;
  
  {$I-}
  Assign(F, FileName);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineCount := 0;
  While (Not Eof(F)) And (LineCount < 50) Do
  Begin
    ReadLn(F, Line);
    Inc(LineCount);
    
    { Verifier le shebang sur la premiere ligne }
    If LineCount = 1 Then
    Begin
      ShebangLang := DetectLanguageFromShebang(Line);
      If ShebangLang <> LANG_UNKNOWN Then
      Begin
        DetectLanguageFromContent := ShebangLang;
        Close(F);
        Exit;
      End;
    End;
    
    UpperLine := UpStr(Line);
    
    { Detecter Pascal par mots-cles }
    If (Pos('PROGRAM ', UpperLine) = 1) Or (Pos('UNIT ', UpperLine) = 1) Or
       (Pos('LIBRARY ', UpperLine) = 1) Or (Pos('USES ', UpperLine) > 0) Then
    Begin
      DetectLanguageFromContent := LANG_PASCAL;
      Close(F);
      Exit;
    End;
    
    { Detecter Fortran par mots-cles }
    If (Pos('PROGRAM ', UpperLine) = 1) Or (Pos('SUBROUTINE ', UpperLine) > 0) Or
       (Pos('FUNCTION ', UpperLine) > 0) Or (Pos('MODULE ', UpperLine) = 1) Then
    Begin
      { Verifier si c'est vraiment Fortran et pas un autre langage }
      If (Pos('IMPLICIT ', UpperLine) > 0) Or (Pos('INTEGER ', UpperLine) > 0) Or
         (Pos('REAL ', UpperLine) > 0) Or (Pos('DIMENSION ', UpperLine) > 0) Then
      Begin
        DetectLanguageFromContent := LANG_FORTRAN;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter C/C++ par #include }
    If (Pos('#INCLUDE', UpperLine) > 0) Then
    Begin
      { C++ si headers sans .h ou iostream/vector/etc. }
      If (Pos('<IOSTREAM>', UpperLine) > 0) Or (Pos('<VECTOR>', UpperLine) > 0) Or
         (Pos('<STRING>', UpperLine) > 0) Or (Pos('<MAP>', UpperLine) > 0) Then
        DetectLanguageFromContent := LANG_CPP
      Else
        DetectLanguageFromContent := LANG_C;
      Close(F);
      Exit;
    End;
    
    { Detecter Java par package/import }
    If (Pos('PACKAGE ', UpperLine) = 1) Or (Pos('IMPORT JAVA.', UpperLine) > 0) Then
    Begin
      DetectLanguageFromContent := LANG_JAVA;
      Close(F);
      Exit;
    End;
    
    { Detecter Python par def/class/import }
    If (Pos('DEF ', UpperLine) = 1) Or (Pos('CLASS ', UpperLine) = 1) Or
       (Pos('IMPORT ', UpperLine) = 1) Or (Pos('FROM ', UpperLine) = 1) Then
    Begin
      { Eviter confusion avec d'autres langages }
      If (Pos(':', Line) > 0) Then
      Begin
        DetectLanguageFromContent := LANG_PYTHON;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter C# par using System }
    If (Pos('USING SYSTEM', UpperLine) > 0) Or (Pos('NAMESPACE ', UpperLine) > 0) Then
    Begin
      { Verifier que ce n'est pas C++ }
      If (Pos('#INCLUDE', UpperLine) = 0) Then
      Begin
        DetectLanguageFromContent := LANG_CSHARP;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter Rust par fn main() ou use std:: }
    If (Pos('FN MAIN', UpperLine) > 0) Or (Pos('USE STD::', UpperLine) > 0) Or
       (Pos('MOD ', UpperLine) = 1) Then
    Begin
      DetectLanguageFromContent := LANG_RUST;
      Close(F);
      Exit;
    End;
    
    { Detecter Go par package main/func }
    If (Pos('PACKAGE MAIN', UpperLine) > 0) Or (Pos('FUNC ', UpperLine) > 0) Then
    Begin
      { Verifier la syntaxe Go }
      If (Pos('IMPORT (', UpperLine) > 0) Or (Pos('IMPORT "', UpperLine) > 0) Then
      Begin
        DetectLanguageFromContent := LANG_GO;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter Swift par import Foundation/UIKit }
    If (Pos('IMPORT FOUNDATION', UpperLine) > 0) Or (Pos('IMPORT UIKIT', UpperLine) > 0) Or
       (Pos('IMPORT SWIFTUI', UpperLine) > 0) Then
    Begin
      DetectLanguageFromContent := LANG_SWIFT;
      Close(F);
      Exit;
    End;
    
    { Detecter Kotlin par fun main ou package }
    If (Pos('FUN MAIN', UpperLine) > 0) Or (Pos('PACKAGE ', UpperLine) = 1) Then
    Begin
      { Verifier syntaxe Kotlin vs Java }
      If (Pos('VAL ', UpperLine) > 0) Or (Pos('VAR ', UpperLine) > 0) Or
         (Pos('FUN ', UpperLine) > 0) Then
      Begin
        DetectLanguageFromContent := LANG_KOTLIN;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter VHDL par library/entity/architecture }
    If (Pos('LIBRARY ', UpperLine) = 1) Or (Pos('ENTITY ', UpperLine) = 1) Or
       (Pos('ARCHITECTURE ', UpperLine) = 1) Then
    Begin
      DetectLanguageFromContent := LANG_VHDL;
      Close(F);
      Exit;
    End;
    
    { Detecter Ada par with/procedure }
    If (Pos('WITH ', UpperLine) = 1) Or (Pos('PROCEDURE ', UpperLine) = 1) Then
    Begin
      { Verifier syntaxe Ada }
      If (Pos(';', Line) > 0) And (Pos('IS', UpperLine) > 0) Then
      Begin
        DetectLanguageFromContent := LANG_ADA;
        Close(F);
        Exit;
      End;
    End;
    
    { Detecter COBOL par IDENTIFICATION DIVISION }
    If (Pos('IDENTIFICATION DIVISION', UpperLine) > 0) Or
       (Pos('PROCEDURE DIVISION', UpperLine) > 0) Then
    Begin
      DetectLanguageFromContent := LANG_COBOL;
      Close(F);
      Exit;
    End;
  End;
  
  Close(F);
End;

Function DetectLanguage(Const FileName: String): TSourceLanguage;
{ Detection complete du langage : extension puis analyse du contenu }
Var
  Lang: TSourceLanguage;
Begin
  { D'abord essayer par l'extension }
  Lang := DetectLanguageFromExt(FileName);
  
  { Si inconnu ou ambigu, analyser le contenu }
  If Lang = LANG_UNKNOWN Then
    Lang := DetectLanguageFromContent(FileName);
  
  { Pour certaines extensions ambigues, analyser le contenu }
  { .h peut etre C ou C++ }
  If (Lang = LANG_C) And (Pos('.H', UpStr(ExtractExt(FileName))) > 0) Then
  Begin
    { Analyser le contenu pour determiner si c'est du C++ }
    { Si DetectLanguageFromContent trouve C++, utiliser ca }
    If DetectLanguageFromContent(FileName) = LANG_CPP Then
      Lang := LANG_CPP;
  End;
  
  DetectLanguage := Lang;
End;

{ ============================================================
  TODO 08 - EXTRACTION DES ENTITES DOCUMENTEES
  ============================================================ }

Procedure InitEntities;
{ Initialise le tableau des entites }
Begin
  EntityCount := 0;
End;

Function EntityKindToStr(Kind: TEntityKind): String;
{ Convertit un type d entite en chaine }
Begin
  Case Kind Of
    ENT_UNKNOWN:    EntityKindToStr := 'unknown';
    ENT_FILE:       EntityKindToStr := 'file';
    ENT_NAMESPACE:  EntityKindToStr := 'namespace';
    ENT_CLASS:      EntityKindToStr := 'class';
    ENT_STRUCT:     EntityKindToStr := 'struct';
    ENT_UNION:      EntityKindToStr := 'union';
    ENT_INTERFACE:  EntityKindToStr := 'interface';
    ENT_ENUM:       EntityKindToStr := 'enum';
    ENT_TYPEDEF:    EntityKindToStr := 'typedef';
    ENT_FUNCTION:   EntityKindToStr := 'function';
    ENT_VARIABLE:   EntityKindToStr := 'variable';
    ENT_DEFINE:     EntityKindToStr := 'define';
    ENT_PROPERTY:   EntityKindToStr := 'property';
    ENT_SIGNAL:     EntityKindToStr := 'signal';
    ENT_SLOT:       EntityKindToStr := 'slot';
    ENT_FRIEND:     EntityKindToStr := 'friend';
    ENT_MODULE:     EntityKindToStr := 'module';
    ENT_GROUP:      EntityKindToStr := 'group';
    ENT_PAGE:       EntityKindToStr := 'page';
    ENT_EXAMPLE:    EntityKindToStr := 'example';
    ENT_DIR:        EntityKindToStr := 'dir';
    ENT_CONCEPT:    EntityKindToStr := 'concept';
    ENT_SEQUENCE:   EntityKindToStr := 'sequence';
    ENT_DICTIONARY: EntityKindToStr := 'dictionary';
    ENT_SERVICE:    EntityKindToStr := 'service';
    ENT_SINGLETON:  EntityKindToStr := 'singleton';
    ENT_EXCEPTION:  EntityKindToStr := 'exception';
  Else
    EntityKindToStr := 'unknown';
  End;
End;

Function VisibilityToStr(Vis: TEntityVisibility): String;
{ Convertit une visibilite en chaine }
Begin
  Case Vis Of
    VIS_PUBLIC:    VisibilityToStr := 'public';
    VIS_PROTECTED: VisibilityToStr := 'protected';
    VIS_PRIVATE:   VisibilityToStr := 'private';
    VIS_PACKAGE:   VisibilityToStr := 'package';
  Else
    VisibilityToStr := 'public';
  End;
End;

Procedure AddEntity(Kind: TEntityKind; Const Name, FullName, FileName: String;
  Line: Integer; Vis: TEntityVisibility);
{ Ajoute une entite au tableau }
Begin
  If EntityCount >= MAX_SYMBOLS Then Exit;
  Inc(EntityCount);
  With Entities[EntityCount] Do
  Begin
    Entities[EntityCount].Kind := Kind;
    Entities[EntityCount].Name := Name;
    Entities[EntityCount].FullName := FullName;
    Entities[EntityCount].FileName := FileName;
    Entities[EntityCount].Line := Line;
    Entities[EntityCount].EndLine := Line;
    Entities[EntityCount].Visibility := Vis;
    Entities[EntityCount].IsStatic := False;
    Entities[EntityCount].IsConst := False;
    Entities[EntityCount].IsVirtual := False;
    Entities[EntityCount].IsAbstract := False;
    Entities[EntityCount].IsFinal := False;
    Entities[EntityCount].IsOverride := False;
    Entities[EntityCount].IsInline := False;
    Entities[EntityCount].IsExplicit := False;
    Entities[EntityCount].IsTemplate := False;
    Entities[EntityCount].ReturnType := '';
    Entities[EntityCount].Parameters := '';
    Entities[EntityCount].Signature := '';
    Entities[EntityCount].ParentId := 0;
    Entities[EntityCount].DocComment := '';
    Entities[EntityCount].BriefDesc := '';
    Entities[EntityCount].DetailedDesc := '';
  End;
End;

Function IsIdentChar(Ch: Char): Boolean;
{ Retourne True si Ch est un caractere valide dans un identificateur }
Begin
  IsIdentChar := ((Ch >= 'A') And (Ch <= 'Z')) Or
                 ((Ch >= 'a') And (Ch <= 'z')) Or
                 ((Ch >= '0') And (Ch <= '9')) Or
                 (Ch = '_');
End;

Function IsIdentStart(Ch: Char): Boolean;
{ Retourne True si Ch peut demarrer un identificateur }
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function ExtractIdent(Const Line: String; StartPos: Integer): String;
{ Extrait un identificateur a partir de la position donnee }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  I := StartPos;
  { Sauter les espaces }
  While (I <= Length(Line)) And (Line[I] = ' ') Do
    Inc(I);
  { Extraire l identificateur }
  If (I <= Length(Line)) And IsIdentStart(Line[I]) Then
  Begin
    While (I <= Length(Line)) And IsIdentChar(Line[I]) Do
    Begin
      R := R + Line[I];
      Inc(I);
    End;
  End;
  ExtractIdent := R;
End;

Function TrimLine(Const S: String): String;
{ Supprime les espaces en debut et fin de chaine }
Var
  L, R: Integer;
Begin
  L := 1;
  R := Length(S);
  While (L <= R) And (S[L] = ' ') Do Inc(L);
  While (R >= L) And (S[R] = ' ') Do Dec(R);
  TrimLine := Copy(S, L, R - L + 1);
End;

Procedure ExtractEntitiesC(Const FileName: String);
{ Extraction des entites pour C/C++ }
Var
  F: Text;
  Line, TrimmedLine, UpperLine: String;
  LineNum: Integer;
  P: Integer;
  Name: String;
  InComment: Boolean;
  InClass: Boolean;
  CurrentClass: String;
  BraceDepth: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  InComment := False;
  InClass := False;
  CurrentClass := '';
  BraceDepth := 0;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    TrimmedLine := TrimLine(Line);
    UpperLine := UpStr(TrimmedLine);
    
    { Gerer les commentaires multiligne }
    If InComment Then
    Begin
      P := Pos('*/', TrimmedLine);
      If P > 0 Then
        InComment := False;
      Continue;
    End;
    
    { Detecter debut de commentaire multiligne }
    P := Pos('/*', TrimmedLine);
    If (P > 0) And (Pos('*/', TrimmedLine) = 0) Then
    Begin
      InComment := True;
      Continue;
    End;
    
    { Ignorer les lignes de commentaire simple }
    If (Length(TrimmedLine) >= 2) And (Copy(TrimmedLine, 1, 2) = '//') Then
      Continue;
    
    { Compter les accolades }
    For P := 1 To Length(TrimmedLine) Do
    Begin
      If TrimmedLine[P] = '{' Then Inc(BraceDepth)
      Else If TrimmedLine[P] = '}' Then
      Begin
        Dec(BraceDepth);
        If InClass And (BraceDepth = 0) Then
        Begin
          InClass := False;
          CurrentClass := '';
        End;
      End;
    End;
    
    { Detecter #define }
    If Copy(TrimmedLine, 1, 7) = '#define' Then
    Begin
      Name := ExtractIdent(TrimmedLine, 8);
      If Name <> '' Then
        AddEntity(ENT_DEFINE, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les classes }
    P := Pos('CLASS ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 6);
      If Name <> '' Then
      Begin
        AddEntity(ENT_CLASS, Name, Name, FileName, LineNum, VIS_PUBLIC);
        InClass := True;
        CurrentClass := Name;
      End;
      Continue;
    End;
    
    { Detecter les structures }
    P := Pos('STRUCT ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 7);
      If Name <> '' Then
        AddEntity(ENT_STRUCT, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les unions }
    P := Pos('UNION ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 6);
      If Name <> '' Then
        AddEntity(ENT_UNION, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les enumerations }
    P := Pos('ENUM ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 5);
      If Name <> '' Then
        AddEntity(ENT_ENUM, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter typedef }
    If Copy(UpperLine, 1, 8) = 'TYPEDEF ' Then
    Begin
      { Le nom du typedef est generalement a la fin avant ; }
      P := Pos(';', TrimmedLine);
      If P > 1 Then
      Begin
        { Trouver le dernier mot avant ; }
        P := P - 1;
        While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
        If P > 0 Then
        Begin
          Name := '';
          While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
          Begin
            Name := TrimmedLine[P] + Name;
            Dec(P);
          End;
          If Name <> '' Then
            AddEntity(ENT_TYPEDEF, Name, Name, FileName, LineNum, VIS_PUBLIC);
        End;
      End;
      Continue;
    End;
    
    { Detecter les fonctions (pattern simplifie: type nom(...) ) }
    P := Pos('(', TrimmedLine);
    If P > 1 Then
    Begin
      { Verifier que ce n est pas un if, while, for, switch }
      If (Pos('IF ', UpperLine) = 0) And
         (Pos('WHILE ', UpperLine) = 0) And
         (Pos('FOR ', UpperLine) = 0) And
         (Pos('SWITCH ', UpperLine) = 0) And
         (Pos('RETURN ', UpperLine) = 0) And
         (Pos('#', TrimmedLine) = 0) Then
      Begin
        { Extraire le nom de la fonction (dernier mot avant la parenthese) }
        P := P - 1;
        While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
        If P > 0 Then
        Begin
          Name := '';
          While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
          Begin
            Name := TrimmedLine[P] + Name;
            Dec(P);
          End;
          { Verifier que ce n est pas un mot-cle }
          If (Name <> '') And (UpStr(Name) <> 'IF') And 
             (UpStr(Name) <> 'WHILE') And (UpStr(Name) <> 'FOR') And
             (UpStr(Name) <> 'SWITCH') And (UpStr(Name) <> 'RETURN') And
             (UpStr(Name) <> 'SIZEOF') And (UpStr(Name) <> 'TYPEOF') Then
          Begin
            If InClass Then
              AddEntity(ENT_FUNCTION, Name, CurrentClass + '::' + Name, 
                FileName, LineNum, VIS_PUBLIC)
            Else
              AddEntity(ENT_FUNCTION, Name, Name, FileName, LineNum, VIS_PUBLIC);
          End;
        End;
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractEntitiesPascal(Const FileName: String);
{ Extraction des entites pour Pascal/Delphi }
Var
  F: Text;
  Line, TrimmedLine, UpperLine: String;
  LineNum: Integer;
  P: Integer;
  Name: String;
  InComment, InBraceComment: Boolean;
  InClass, InInterface: Boolean;
  CurrentClass: String;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  InComment := False;
  InBraceComment := False;
  InClass := False;
  InInterface := False;
  CurrentClass := '';
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    TrimmedLine := TrimLine(Line);
    UpperLine := UpStr(TrimmedLine);
    
    { Gerer les commentaires }
    If InComment Then
    Begin
      P := Pos('*)', TrimmedLine);
      If P > 0 Then InComment := False;
      Continue;
    End;
    If InBraceComment Then
    Begin
      P := Pos('}', TrimmedLine);
      If P > 0 Then InBraceComment := False;
      Continue;
    End;
    
    { Detecter debut de commentaire }
    P := Pos('(*', TrimmedLine);
    If (P > 0) And (Pos('*)', TrimmedLine) = 0) Then
    Begin
      InComment := True;
      Continue;
    End;
    P := Pos('{', TrimmedLine);
    If (P > 0) And (Pos('}', TrimmedLine) = 0) And 
       (Copy(TrimmedLine, P, 2) <> '{$') Then
    Begin
      InBraceComment := True;
      Continue;
    End;
    
    { Detecter unit }
    If Copy(UpperLine, 1, 5) = 'UNIT ' Then
    Begin
      Name := ExtractIdent(TrimmedLine, 6);
      If Name <> '' Then
        AddEntity(ENT_MODULE, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter program }
    If Copy(UpperLine, 1, 8) = 'PROGRAM ' Then
    Begin
      Name := ExtractIdent(TrimmedLine, 9);
      If Name <> '' Then
        AddEntity(ENT_MODULE, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les classes (Delphi) }
    P := Pos('= CLASS', UpperLine);
    If P > 0 Then
    Begin
      { Le nom est avant le = }
      Name := '';
      P := P - 1;
      While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
      While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
      Begin
        Name := TrimmedLine[P] + Name;
        Dec(P);
      End;
      If Name <> '' Then
      Begin
        AddEntity(ENT_CLASS, Name, Name, FileName, LineNum, VIS_PUBLIC);
        InClass := True;
        CurrentClass := Name;
      End;
      Continue;
    End;
    
    { Detecter les records }
    P := Pos('= RECORD', UpperLine);
    If P > 0 Then
    Begin
      Name := '';
      P := P - 1;
      While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
      While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
      Begin
        Name := TrimmedLine[P] + Name;
        Dec(P);
      End;
      If Name <> '' Then
        AddEntity(ENT_STRUCT, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les interfaces }
    P := Pos('= INTERFACE', UpperLine);
    If P > 0 Then
    Begin
      Name := '';
      P := P - 1;
      While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
      While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
      Begin
        Name := TrimmedLine[P] + Name;
        Dec(P);
      End;
      If Name <> '' Then
      Begin
        AddEntity(ENT_INTERFACE, Name, Name, FileName, LineNum, VIS_PUBLIC);
        InInterface := True;
      End;
      Continue;
    End;
    
    { Detecter fin de classe/interface }
    If (UpperLine = 'END;') Or (Copy(UpperLine, 1, 4) = 'END;') Then
    Begin
      If InClass Then
      Begin
        InClass := False;
        CurrentClass := '';
      End;
      If InInterface Then InInterface := False;
    End;
    
    { Detecter les procedures }
    If Copy(UpperLine, 1, 10) = 'PROCEDURE ' Then
    Begin
      Name := ExtractIdent(TrimmedLine, 11);
      If Name <> '' Then
      Begin
        If InClass Then
          AddEntity(ENT_FUNCTION, Name, CurrentClass + '.' + Name,
            FileName, LineNum, VIS_PUBLIC)
        Else
          AddEntity(ENT_FUNCTION, Name, Name, FileName, LineNum, VIS_PUBLIC);
      End;
      Continue;
    End;
    
    { Detecter les fonctions }
    If Copy(UpperLine, 1, 9) = 'FUNCTION ' Then
    Begin
      Name := ExtractIdent(TrimmedLine, 10);
      If Name <> '' Then
      Begin
        If InClass Then
          AddEntity(ENT_FUNCTION, Name, CurrentClass + '.' + Name,
            FileName, LineNum, VIS_PUBLIC)
        Else
          AddEntity(ENT_FUNCTION, Name, Name, FileName, LineNum, VIS_PUBLIC);
      End;
      Continue;
    End;
    
    { Detecter les types enumeres }
    P := Pos('= (', UpperLine);
    If (P > 0) And (Pos('TYPE', UpperLine) > 0) Then
    Begin
      Name := '';
      P := P - 1;
      While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
      While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
      Begin
        Name := TrimmedLine[P] + Name;
        Dec(P);
      End;
      If Name <> '' Then
        AddEntity(ENT_ENUM, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les constantes }
    If Copy(UpperLine, 1, 6) = 'CONST ' Then
    Begin
      { La ligne suivante devrait avoir le nom de la constante }
      Continue;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractEntitiesJava(Const FileName: String);
{ Extraction des entites pour Java }
Var
  F: Text;
  Line, TrimmedLine, UpperLine: String;
  LineNum: Integer;
  P: Integer;
  Name: String;
  InComment: Boolean;
  PackageName: String;
  CurrentClass: String;
  BraceDepth: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  InComment := False;
  PackageName := '';
  CurrentClass := '';
  BraceDepth := 0;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    TrimmedLine := TrimLine(Line);
    UpperLine := UpStr(TrimmedLine);
    
    { Gerer les commentaires multiligne }
    If InComment Then
    Begin
      P := Pos('*/', TrimmedLine);
      If P > 0 Then InComment := False;
      Continue;
    End;
    
    P := Pos('/*', TrimmedLine);
    If (P > 0) And (Pos('*/', TrimmedLine) = 0) Then
    Begin
      InComment := True;
      Continue;
    End;
    
    If (Length(TrimmedLine) >= 2) And (Copy(TrimmedLine, 1, 2) = '//') Then
      Continue;
    
    { Compter les accolades }
    For P := 1 To Length(TrimmedLine) Do
    Begin
      If TrimmedLine[P] = '{' Then Inc(BraceDepth)
      Else If TrimmedLine[P] = '}' Then
      Begin
        Dec(BraceDepth);
        If BraceDepth = 0 Then CurrentClass := '';
      End;
    End;
    
    { Detecter package }
    If Copy(UpperLine, 1, 8) = 'PACKAGE ' Then
    Begin
      P := Pos(';', TrimmedLine);
      If P > 9 Then
        PackageName := TrimLine(Copy(TrimmedLine, 9, P - 9));
      Continue;
    End;
    
    { Detecter class }
    P := Pos(' CLASS ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 7);
      If Name <> '' Then
      Begin
        If PackageName <> '' Then
          AddEntity(ENT_CLASS, Name, PackageName + '.' + Name,
            FileName, LineNum, VIS_PUBLIC)
        Else
          AddEntity(ENT_CLASS, Name, Name, FileName, LineNum, VIS_PUBLIC);
        CurrentClass := Name;
      End;
      Continue;
    End;
    
    { Detecter interface }
    P := Pos(' INTERFACE ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 11);
      If Name <> '' Then
      Begin
        If PackageName <> '' Then
          AddEntity(ENT_INTERFACE, Name, PackageName + '.' + Name,
            FileName, LineNum, VIS_PUBLIC)
        Else
          AddEntity(ENT_INTERFACE, Name, Name, FileName, LineNum, VIS_PUBLIC);
      End;
      Continue;
    End;
    
    { Detecter enum }
    P := Pos(' ENUM ', UpperLine);
    If P > 0 Then
    Begin
      Name := ExtractIdent(TrimmedLine, P + 6);
      If Name <> '' Then
        AddEntity(ENT_ENUM, Name, Name, FileName, LineNum, VIS_PUBLIC);
      Continue;
    End;
    
    { Detecter les methodes }
    P := Pos('(', TrimmedLine);
    If (P > 1) And (CurrentClass <> '') And
       (Pos('IF ', UpperLine) = 0) And
       (Pos('WHILE ', UpperLine) = 0) And
       (Pos('FOR ', UpperLine) = 0) And
       (Pos('SWITCH ', UpperLine) = 0) Then
    Begin
      P := P - 1;
      While (P > 0) And (TrimmedLine[P] = ' ') Do Dec(P);
      If P > 0 Then
      Begin
        Name := '';
        While (P > 0) And IsIdentChar(TrimmedLine[P]) Do
        Begin
          Name := TrimmedLine[P] + Name;
          Dec(P);
        End;
        If (Name <> '') And (Name <> CurrentClass) And
           (UpStr(Name) <> 'IF') And (UpStr(Name) <> 'WHILE') And
           (UpStr(Name) <> 'FOR') And (UpStr(Name) <> 'NEW') Then
          AddEntity(ENT_FUNCTION, Name, CurrentClass + '.' + Name,
            FileName, LineNum, VIS_PUBLIC);
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractEntitiesPython(Const FileName: String);
{ Extraction des entites pour Python }
Var
  F: Text;
  Line, TrimmedLine: String;
  LineNum: Integer;
  P: Integer;
  Name: String;
  InDocString: Boolean;
  CurrentClass: String;
  IndentLevel: Integer;
  ClassIndent: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  InDocString := False;
  CurrentClass := '';
  ClassIndent := 0;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    TrimmedLine := TrimLine(Line);
    
    { Calculer l indentation }
    IndentLevel := 0;
    P := 1;
    While (P <= Length(Line)) And ((Line[P] = ' ') Or (Line[P] = #9)) Do
    Begin
      If Line[P] = #9 Then
        Inc(IndentLevel, 4)
      Else
        Inc(IndentLevel);
      Inc(P);
    End;
    
    { Gerer les docstrings triple quotes }
    If InDocString Then
    Begin
      If (Pos('"""', TrimmedLine) > 0) Or (Pos('''''''', TrimmedLine) > 0) Then
        InDocString := False;
      Continue;
    End;
    
    If (Pos('"""', TrimmedLine) > 0) Or (Pos('''''''', TrimmedLine) > 0) Then
    Begin
      { Verifier si la docstring se termine sur la meme ligne }
      P := Pos('"""', TrimmedLine);
      If P > 0 Then
      Begin
        If Pos('"""', Copy(TrimmedLine, P + 3, Length(TrimmedLine))) = 0 Then
          InDocString := True;
      End;
      Continue;
    End;
    
    { Ignorer les commentaires }
    If (Length(TrimmedLine) > 0) And (TrimmedLine[1] = '#') Then
      Continue;
    
    { Sortir de la classe si l indentation diminue }
    If (CurrentClass <> '') And (IndentLevel <= ClassIndent) And
       (TrimmedLine <> '') Then
    Begin
      CurrentClass := '';
    End;
    
    { Detecter class }
    If Copy(TrimmedLine, 1, 6) = 'class ' Then
    Begin
      P := Pos('(', TrimmedLine);
      If P = 0 Then P := Pos(':', TrimmedLine);
      If P > 7 Then
      Begin
        Name := TrimLine(Copy(TrimmedLine, 7, P - 7));
        If Name <> '' Then
        Begin
          AddEntity(ENT_CLASS, Name, Name, FileName, LineNum, VIS_PUBLIC);
          CurrentClass := Name;
          ClassIndent := IndentLevel;
        End;
      End;
      Continue;
    End;
    
    { Detecter def (fonctions/methodes) }
    If Copy(TrimmedLine, 1, 4) = 'def ' Then
    Begin
      P := Pos('(', TrimmedLine);
      If P > 5 Then
      Begin
        Name := TrimLine(Copy(TrimmedLine, 5, P - 5));
        If Name <> '' Then
        Begin
          If CurrentClass <> '' Then
            AddEntity(ENT_FUNCTION, Name, CurrentClass + '.' + Name,
              FileName, LineNum, VIS_PUBLIC)
          Else
            AddEntity(ENT_FUNCTION, Name, Name, FileName, LineNum, VIS_PUBLIC);
        End;
      End;
      Continue;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractEntities(Const FileName: String; Lang: TSourceLanguage);
{ Dispatcher vers l extracteur specifique au langage }
Begin
  InitEntities;
  
  Case Lang Of
    LANG_C, LANG_CPP, LANG_CSHARP, LANG_D, LANG_OBJC:
      ExtractEntitiesC(FileName);
    LANG_PASCAL:
      ExtractEntitiesPascal(FileName);
    LANG_JAVA, LANG_KOTLIN:
      ExtractEntitiesJava(FileName);
    LANG_PYTHON:
      ExtractEntitiesPython(FileName);
  Else
    { Pour les autres langages, utiliser l extracteur C comme base }
    ExtractEntitiesC(FileName);
  End;
End;

Procedure ShowExtractedEntities;
{ Affiche les entites extraites }
Var
  I: Integer;
Begin
  If EntityCount = 0 Then
  Begin
    WriteLn('Aucune entite extraite.');
    Exit;
  End;
  
  WriteLn('Entites documentees extraites: ', EntityCount);
  WriteLn;
  
  For I := 1 To EntityCount Do
  Begin
    Write('  [', I, '] ');
    Write(EntityKindToStr(Entities[I].Kind), ' ');
    Write(Entities[I].Name);
    If Entities[I].FullName <> Entities[I].Name Then
      Write(' (', Entities[I].FullName, ')');
    WriteLn(' - ligne ', Entities[I].Line);
  End;
  
  WriteLn;
End;

{ ============================================================
  TODO 09 - ANALYSE DES HIERARCHIES DE CLASSES
  ============================================================ }

Procedure InitInheritances;
{ Initialise le tableau des heritages }
Begin
  InheritanceCount := 0;
End;

Function ClassRelationToStr(Rel: TClassRelation): String;
{ Convertit un type de relation en chaine }
Begin
  Case Rel Of
    REL_INHERITS:   ClassRelationToStr := 'inherits';
    REL_IMPLEMENTS: ClassRelationToStr := 'implements';
    REL_USES:       ClassRelationToStr := 'uses';
    REL_CONTAINS:   ClassRelationToStr := 'contains';
    REL_AGGREGATES: ClassRelationToStr := 'aggregates';
    REL_ASSOCIATES: ClassRelationToStr := 'associates';
    REL_DEPENDS:    ClassRelationToStr := 'depends';
    REL_FRIEND:     ClassRelationToStr := 'friend';
  Else
    ClassRelationToStr := 'unknown';
  End;
End;

Procedure AddInheritance(ChildId: Integer; Const ParentName: String;
  Rel: TClassRelation; Vis: TEntityVisibility; IsVirt: Boolean);
{ Ajoute une relation d heritage au tableau }
Var
  I, ParentId: Integer;
Begin
  If InheritanceCount >= MAX_INHERITANCES Then
  Begin
    WarnMsg('Trop de relations d''heritage (max=' + IntToStr(MAX_INHERITANCES) + ')');
    Exit;
  End;
  
  { Rechercher l ID de la classe parente }
  ParentId := -1;
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].Name = ParentName) Or (Entities[I].FullName = ParentName) Then
    Begin
      If (Entities[I].Kind = ENT_CLASS) Or (Entities[I].Kind = ENT_STRUCT) Or
         (Entities[I].Kind = ENT_INTERFACE) Then
      Begin
        ParentId := I;
        Break;
      End;
    End;
  End;
  
  Inc(InheritanceCount);
  Inheritances[InheritanceCount].ChildId := ChildId;
  Inheritances[InheritanceCount].ParentId := ParentId;
  Inheritances[InheritanceCount].ParentName := ParentName;
  Inheritances[InheritanceCount].Relation := Rel;
  Inheritances[InheritanceCount].Visibility := Vis;
  Inheritances[InheritanceCount].IsVirtual := IsVirt;
End;

Function FindEntityByName(Const Name: String): Integer;
{ Recherche une entite par son nom, retourne l index ou -1 si non trouve }
Var
  I: Integer;
Begin
  FindEntityByName := -1;
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].Name = Name) Or (Entities[I].FullName = Name) Then
    Begin
      FindEntityByName := I;
      Exit;
    End;
  End;
End;

Function IsClassEntity(Kind: TEntityKind): Boolean;
{ Verifie si le type d entite est une classe, struct ou interface }
Begin
  IsClassEntity := (Kind = ENT_CLASS) Or (Kind = ENT_STRUCT) Or
                   (Kind = ENT_INTERFACE) Or (Kind = ENT_EXCEPTION);
End;

Procedure ParseCppInheritance(Const Line: String; EntityId: Integer);
{ Parse une ligne de declaration C++ pour extraire les heritages.
  Ex: class Derived : public Base, private Base2, virtual public Base3 }
Var
  Pos, ColonPos, I, StartPos: Integer;
  ParentName: String;
  Vis: TEntityVisibility;
  IsVirtual: Boolean;
Begin
  { Chercher le : qui indique l heritage }
  ColonPos := 0;
  For I := 1 To Length(Line) Do
  Begin
    If Line[I] = ':' Then
    Begin
      { Verifier que ce n est pas :: }
      If (I > 1) And (Line[I-1] = ':') Then Continue;
      If (I < Length(Line)) And (Line[I+1] = ':') Then Continue;
      ColonPos := I;
      Break;
    End;
  End;
  
  If ColonPos = 0 Then Exit;
  
  { Parser les classes parentes apres le : }
  Pos := ColonPos + 1;
  While Pos <= Length(Line) Do
  Begin
    { Sauter les espaces }
    While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
    If Pos > Length(Line) Then Break;
    
    { Detecter les modificateurs }
    Vis := VIS_PRIVATE;  { Par defaut pour class }
    IsVirtual := False;
    
    { Boucle pour parser virtual et visibilite }
    While Pos <= Length(Line) Do
    Begin
      { virtual }
      If (Pos + 6 <= Length(Line)) And 
         (Copy(Line, Pos, 7) = 'virtual') And
         ((Pos + 7 > Length(Line)) Or (Line[Pos+7] = ' ')) Then
      Begin
        IsVirtual := True;
        Inc(Pos, 7);
        While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
        Continue;
      End;
      
      { public }
      If (Pos + 5 <= Length(Line)) And 
         (Copy(Line, Pos, 6) = 'public') And
         ((Pos + 6 > Length(Line)) Or (Line[Pos+6] = ' ')) Then
      Begin
        Vis := VIS_PUBLIC;
        Inc(Pos, 6);
        While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
        Continue;
      End;
      
      { protected }
      If (Pos + 8 <= Length(Line)) And 
         (Copy(Line, Pos, 9) = 'protected') And
         ((Pos + 9 > Length(Line)) Or (Line[Pos+9] = ' ')) Then
      Begin
        Vis := VIS_PROTECTED;
        Inc(Pos, 9);
        While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
        Continue;
      End;
      
      { private }
      If (Pos + 6 <= Length(Line)) And 
         (Copy(Line, Pos, 7) = 'private') And
         ((Pos + 7 > Length(Line)) Or (Line[Pos+7] = ' ')) Then
      Begin
        Vis := VIS_PRIVATE;
        Inc(Pos, 7);
        While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
        Continue;
      End;
      
      Break;
    End;
    
    { Extraire le nom de la classe parente }
    StartPos := Pos;
    While (Pos <= Length(Line)) And 
          (Line[Pos] <> ',') And (Line[Pos] <> '{') And 
          (Line[Pos] <> ' ') And (Line[Pos] <> '<') Do
    Begin
      { Gerer les noms qualifies avec :: }
      If (Pos < Length(Line)) And (Line[Pos] = ':') And (Line[Pos+1] = ':') Then
        Inc(Pos, 2)
      Else
        Inc(Pos);
    End;
    
    ParentName := Copy(Line, StartPos, Pos - StartPos);
    
    { Sauter les templates <...> }
    If (Pos <= Length(Line)) And (Line[Pos] = '<') Then
    Begin
      I := 1;  { Compteur de < }
      Inc(Pos);
      While (Pos <= Length(Line)) And (I > 0) Do
      Begin
        If Line[Pos] = '<' Then Inc(I)
        Else If Line[Pos] = '>' Then Dec(I);
        Inc(Pos);
      End;
    End;
    
    { Ajouter l heritage si le nom est valide }
    If Length(ParentName) > 0 Then
      AddInheritance(EntityId, ParentName, REL_INHERITS, Vis, IsVirtual);
    
    { Chercher la prochaine classe parente (apres la virgule) }
    While (Pos <= Length(Line)) And (Line[Pos] <> ',') And (Line[Pos] <> '{') Do
      Inc(Pos);
    
    If (Pos <= Length(Line)) And (Line[Pos] = ',') Then
      Inc(Pos)
    Else
      Break;
  End;
End;

Procedure ParseJavaInheritance(Const Line: String; EntityId: Integer);
{ Parse une declaration Java pour extraire extends et implements.
  Ex: class Derived extends Base implements Interface1, Interface2 }
Var
  Pos, StartPos: Integer;
  ParentName: String;
  InExtends, InImplements: Boolean;
Begin
  InExtends := False;
  InImplements := False;
  Pos := 1;
  
  While Pos <= Length(Line) Do
  Begin
    { Chercher extends }
    If (Pos + 6 <= Length(Line)) And (Copy(Line, Pos, 7) = 'extends') Then
    Begin
      InExtends := True;
      InImplements := False;
      Inc(Pos, 7);
      While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
      Continue;
    End;
    
    { Chercher implements }
    If (Pos + 9 <= Length(Line)) And (Copy(Line, Pos, 10) = 'implements') Then
    Begin
      InExtends := False;
      InImplements := True;
      Inc(Pos, 10);
      While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
      Continue;
    End;
    
    { Si on est dans extends ou implements, extraire le nom }
    If InExtends Or InImplements Then
    Begin
      StartPos := Pos;
      While (Pos <= Length(Line)) And 
            (Line[Pos] <> ',') And (Line[Pos] <> '{') And 
            (Line[Pos] <> ' ') And (Line[Pos] <> '<') Do
        Inc(Pos);
      
      ParentName := Copy(Line, StartPos, Pos - StartPos);
      
      { Sauter les generics <...> }
      If (Pos <= Length(Line)) And (Line[Pos] = '<') Then
      Begin
        StartPos := 1;
        Inc(Pos);
        While (Pos <= Length(Line)) And (StartPos > 0) Do
        Begin
          If Line[Pos] = '<' Then Inc(StartPos)
          Else If Line[Pos] = '>' Then Dec(StartPos);
          Inc(Pos);
        End;
      End;
      
      If Length(ParentName) > 0 Then
      Begin
        If InExtends Then
          AddInheritance(EntityId, ParentName, REL_INHERITS, VIS_PUBLIC, False)
        Else
          AddInheritance(EntityId, ParentName, REL_IMPLEMENTS, VIS_PUBLIC, False);
      End;
      
      { Passer a la prochaine classe/interface }
      While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
      If (Pos <= Length(Line)) And (Line[Pos] = ',') Then
      Begin
        Inc(Pos);
        While (Pos <= Length(Line)) And (Line[Pos] = ' ') Do Inc(Pos);
        Continue;
      End;
      
      { Fin de extends/implements }
      If (Pos <= Length(Line)) And (Line[Pos] = '{') Then Break;
      InExtends := False;
      InImplements := False;
    End
    Else
      Inc(Pos);
  End;
End;

Procedure ParsePascalInheritance(Const Line: String; EntityId: Integer);
{ Parse une declaration Pascal pour extraire l heritage.
  Ex: TDerived = class(TBase, IInterface1) }
Var
  ParenPos, Pos, StartPos, EndPos: Integer;
  ParentName: String;
  IsFirst: Boolean;
Begin
  { Chercher la parenthese ouvrante apres class/object }
  ParenPos := 0;
  For Pos := 1 To Length(Line) Do
  Begin
    If Line[Pos] = '(' Then
    Begin
      ParenPos := Pos;
      Break;
    End;
  End;
  
  If ParenPos = 0 Then Exit;
  
  { Chercher la parenthese fermante }
  EndPos := 0;
  For Pos := ParenPos + 1 To Length(Line) Do
  Begin
    If Line[Pos] = ')' Then
    Begin
      EndPos := Pos;
      Break;
    End;
  End;
  
  If EndPos = 0 Then EndPos := Length(Line) + 1;
  
  { Parser les classes parentes entre parentheses }
  Pos := ParenPos + 1;
  IsFirst := True;
  
  While Pos < EndPos Do
  Begin
    { Sauter les espaces }
    While (Pos < EndPos) And (Line[Pos] = ' ') Do Inc(Pos);
    If Pos >= EndPos Then Break;
    
    { Extraire le nom }
    StartPos := Pos;
    While (Pos < EndPos) And (Line[Pos] <> ',') And (Line[Pos] <> ' ') Do
      Inc(Pos);
    
    ParentName := Copy(Line, StartPos, Pos - StartPos);
    
    If Length(ParentName) > 0 Then
    Begin
      { En Pascal, la premiere classe est la classe de base,
        les suivantes sont des interfaces }
      If IsFirst Then
        AddInheritance(EntityId, ParentName, REL_INHERITS, VIS_PUBLIC, False)
      Else
        AddInheritance(EntityId, ParentName, REL_IMPLEMENTS, VIS_PUBLIC, False);
      IsFirst := False;
    End;
    
    { Passer a la prochaine classe/interface }
    While (Pos < EndPos) And ((Line[Pos] = ' ') Or (Line[Pos] = ',')) Do Inc(Pos);
  End;
End;

Procedure BuildClassHierarchy;
{ Parcourt toutes les entites de type classe/interface
  et extrait les relations d heritage et d implementation }
Var
  I: Integer;
Begin
  InitInheritances;
  
  For I := 1 To EntityCount Do
  Begin
    If IsClassEntity(Entities[I].Kind) Then
    Begin
      { Analyser la signature pour extraire les heritages }
      If Length(Entities[I].Signature) > 0 Then
      Begin
        { Detecter le langage a partir du contenu }
        If (Pos('class ', Entities[I].Signature) > 0) Or
           (Pos('struct ', Entities[I].Signature) > 0) Then
        Begin
          { C++ ou Java }
          If (Pos(' extends ', Entities[I].Signature) > 0) Or
             (Pos(' implements ', Entities[I].Signature) > 0) Then
            ParseJavaInheritance(Entities[I].Signature, I)
          Else If Pos(':', Entities[I].Signature) > 0 Then
            ParseCppInheritance(Entities[I].Signature, I);
        End
        Else If (Pos('= class', Entities[I].Signature) > 0) Or
                (Pos('= object', Entities[I].Signature) > 0) Or
                (Pos('= interface', Entities[I].Signature) > 0) Then
        Begin
          { Pascal }
          ParsePascalInheritance(Entities[I].Signature, I);
        End;
      End;
    End;
  End;
End;

Function GetBaseClasses(EntityId: Integer): String;
{ Retourne la liste des classes de base (separees par des virgules) }
Var
  I: Integer;
  Result: String;
Begin
  Result := '';
  For I := 1 To InheritanceCount Do
  Begin
    If (Inheritances[I].ChildId = EntityId) And 
       (Inheritances[I].Relation = REL_INHERITS) Then
    Begin
      If Length(Result) > 0 Then Result := Result + ', ';
      Result := Result + Inheritances[I].ParentName;
    End;
  End;
  GetBaseClasses := Result;
End;

Function GetDerivedClasses(EntityId: Integer): String;
{ Retourne la liste des classes derivees (separees par des virgules) }
Var
  I: Integer;
  Result: String;
Begin
  Result := '';
  For I := 1 To InheritanceCount Do
  Begin
    If (Inheritances[I].ParentId = EntityId) And 
       (Inheritances[I].Relation = REL_INHERITS) Then
    Begin
      If Length(Result) > 0 Then Result := Result + ', ';
      If Inheritances[I].ChildId > 0 Then
        Result := Result + Entities[Inheritances[I].ChildId].Name;
    End;
  End;
  GetDerivedClasses := Result;
End;

Function GetImplementedInterfaces(EntityId: Integer): String;
{ Retourne la liste des interfaces implementees (separees par des virgules) }
Var
  I: Integer;
  Result: String;
Begin
  Result := '';
  For I := 1 To InheritanceCount Do
  Begin
    If (Inheritances[I].ChildId = EntityId) And 
       (Inheritances[I].Relation = REL_IMPLEMENTS) Then
    Begin
      If Length(Result) > 0 Then Result := Result + ', ';
      Result := Result + Inheritances[I].ParentName;
    End;
  End;
  GetImplementedInterfaces := Result;
End;

Procedure DetectDiamondInheritance;
{ Detecte et signale les heritages en diamant.
  Un heritage en diamant se produit quand une classe herite de deux classes
  qui ont elles-memes un ancetre commun. }
Var
  I, J, K: Integer;
  Class1, Class2: Integer;
  Ancestors1, Ancestors2: Array[1..100] Of Integer;
  Count1, Count2: Integer;
  Found: Boolean;
  
  Procedure CollectAncestors(EntityId: Integer; Var Ancestors: Array Of Integer;
    Var Count: Integer; Depth: Integer);
  { Collecte recursivement tous les ancetres d une classe }
  Var
    M: Integer;
  Begin
    If Depth > 50 Then Exit;  { Protection contre les boucles infinies }
    
    For M := 1 To InheritanceCount Do
    Begin
      If (Inheritances[M].ChildId = EntityId) And 
         (Inheritances[M].Relation = REL_INHERITS) And
         (Inheritances[M].ParentId > 0) Then
      Begin
        If Count < 100 Then
        Begin
          Inc(Count);
          Ancestors[Count] := Inheritances[M].ParentId;
          CollectAncestors(Inheritances[M].ParentId, Ancestors, Count, Depth + 1);
        End;
      End;
    End;
  End;
  
Begin
  { Parcourir toutes les classes }
  For I := 1 To EntityCount Do
  Begin
    If Not IsClassEntity(Entities[I].Kind) Then Continue;
    
    { Trouver toutes les classes parentes directes }
    Class1 := 0;
    Class2 := 0;
    For J := 1 To InheritanceCount Do
    Begin
      If (Inheritances[J].ChildId = I) And 
         (Inheritances[J].Relation = REL_INHERITS) And
         (Inheritances[J].ParentId > 0) Then
      Begin
        If Class1 = 0 Then
          Class1 := Inheritances[J].ParentId
        Else If Class2 = 0 Then
          Class2 := Inheritances[J].ParentId
        Else
          Break;  { Plus de 2 parents - verifier chaque paire }
      End;
    End;
    
    { Si la classe a au moins 2 parents, verifier le diamant }
    If (Class1 > 0) And (Class2 > 0) Then
    Begin
      { Collecter les ancetres de chaque parent }
      Count1 := 0;
      Count2 := 0;
      CollectAncestors(Class1, Ancestors1, Count1, 0);
      CollectAncestors(Class2, Ancestors2, Count2, 0);
      
      { Chercher un ancetre commun }
      Found := False;
      For J := 1 To Count1 Do
      Begin
        For K := 1 To Count2 Do
        Begin
          If Ancestors1[J] = Ancestors2[K] Then
          Begin
            Found := True;
            WarnMsg('Heritage en diamant detecte: ' + Entities[I].Name +
                    ' herite de ' + Entities[Class1].Name + ' et ' +
                    Entities[Class2].Name + ', qui ont un ancetre commun: ' +
                    Entities[Ancestors1[J]].Name);
            Break;
          End;
        End;
        If Found Then Break;
      End;
    End;
  End;
End;

Procedure ShowClassHierarchy;
{ Affiche la hierarchie des classes }
Var
  I: Integer;
  BaseClasses, DerivedClasses, Interfaces: String;
Begin
  If InheritanceCount = 0 Then
  Begin
    WriteLn('Aucune relation d''heritage trouvee.');
    Exit;
  End;
  
  WriteLn('Hierarchie des classes:');
  WriteLn;
  
  For I := 1 To EntityCount Do
  Begin
    If Not IsClassEntity(Entities[I].Kind) Then Continue;
    
    BaseClasses := GetBaseClasses(I);
    DerivedClasses := GetDerivedClasses(I);
    Interfaces := GetImplementedInterfaces(I);
    
    If (Length(BaseClasses) > 0) Or (Length(DerivedClasses) > 0) Or 
       (Length(Interfaces) > 0) Then
    Begin
      WriteLn('  ', EntityKindToStr(Entities[I].Kind), ' ', Entities[I].Name);
      If Length(BaseClasses) > 0 Then
        WriteLn('    Herite de: ', BaseClasses);
      If Length(Interfaces) > 0 Then
        WriteLn('    Implemente: ', Interfaces);
      If Length(DerivedClasses) > 0 Then
        WriteLn('    Classes derivees: ', DerivedClasses);
      WriteLn;
    End;
  End;
End;

{ ============================================================
  TODO 10 - ANALYSE DES DEPENDANCES (INCLUDE, USES, IMPORT)
  ============================================================ }

Procedure InitDependencies;
{ Initialise le compteur de dependances }
Begin
  DependencyCount := 0;
End;

Function DependencyKindToStr(Kind: TDependencyKind): String;
{ Convertit un type de dependance en chaine }
Begin
  Case Kind Of
    DEP_INCLUDE:       DependencyKindToStr := '#include';
    DEP_INCLUDE_LOCAL: DependencyKindToStr := '#include (local)';
    DEP_IMPORT:        DependencyKindToStr := 'import';
    DEP_USES:          DependencyKindToStr := 'uses';
    DEP_REQUIRE:       DependencyKindToStr := 'require';
    DEP_MODULE:        DependencyKindToStr := 'module';
    DEP_PACKAGE:       DependencyKindToStr := 'package';
    DEP_FROM:          DependencyKindToStr := 'from...import';
  Else
    DependencyKindToStr := 'unknown';
  End;
End;

Procedure AddDependency(Const Source, Target: String; Kind: TDependencyKind;
  LineNum: Integer; IsSys: Boolean);
{ Ajoute une dependance au tableau global }
Begin
  If DependencyCount >= MAX_DEPENDENCIES Then Exit;
  Inc(DependencyCount);
  Dependencies[DependencyCount].SourceFile := Source;
  Dependencies[DependencyCount].TargetFile := Target;
  Dependencies[DependencyCount].Kind := Kind;
  Dependencies[DependencyCount].Line := LineNum;
  Dependencies[DependencyCount].IsSystem := IsSys;
End;

Procedure ExtractCppDependencies(Const FileName: String);
{ Extrait les directives #include des fichiers C/C++ }
Var
  F: Text;
  Line, TrimLine, Target: String;
  LineNum, I, StartPos, EndPos: Integer;
  IsSystem: Boolean;
  Kind: TDependencyKind;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Enlever les espaces au debut }
    TrimLine := Line;
    While (Length(TrimLine) > 0) And (TrimLine[1] = ' ') Do
      Delete(TrimLine, 1, 1);
    
    { Chercher #include }
    If (Length(TrimLine) >= 8) And (Copy(TrimLine, 1, 8) = '#include') Then
    Begin
      { Trouver le delimiteur < ou " }
      I := 9;
      While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      
      If I <= Length(TrimLine) Then
      Begin
        If TrimLine[I] = '<' Then
        Begin
          { Include systeme <fichier> }
          IsSystem := True;
          Kind := DEP_INCLUDE;
          StartPos := I + 1;
          EndPos := StartPos;
          While (EndPos <= Length(TrimLine)) And (TrimLine[EndPos] <> '>') Do
            Inc(EndPos);
          Target := Copy(TrimLine, StartPos, EndPos - StartPos);
        End
        Else If TrimLine[I] = '"' Then
        Begin
          { Include local "fichier" }
          IsSystem := False;
          Kind := DEP_INCLUDE_LOCAL;
          StartPos := I + 1;
          EndPos := StartPos;
          While (EndPos <= Length(TrimLine)) And (TrimLine[EndPos] <> '"') Do
            Inc(EndPos);
          Target := Copy(TrimLine, StartPos, EndPos - StartPos);
        End
        Else
          Continue;
        
        If Length(Target) > 0 Then
          AddDependency(FileName, Target, Kind, LineNum, IsSystem);
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractPascalDependencies(Const FileName: String);
{ Extrait les clauses uses des fichiers Pascal }
Var
  F: Text;
  Line, TrimLine, UpLine, UnitName: String;
  LineNum, I, StartPos: Integer;
  InUsesClause: Boolean;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  InUsesClause := False;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Enlever les espaces au debut }
    TrimLine := Line;
    While (Length(TrimLine) > 0) And (TrimLine[1] = ' ') Do
      Delete(TrimLine, 1, 1);
    
    UpLine := UpStr(TrimLine);
    
    { Chercher le mot-cle uses }
    If (Length(UpLine) >= 4) And (Copy(UpLine, 1, 4) = 'USES') And
       ((Length(UpLine) = 4) Or (UpLine[5] = ' ') Or (UpLine[5] = #9)) Then
    Begin
      InUsesClause := True;
      { Commencer apres 'uses' }
      Delete(TrimLine, 1, 4);
    End;
    
    If InUsesClause Then
    Begin
      { Parser les noms d'unites }
      I := 1;
      While I <= Length(TrimLine) Do
      Begin
        { Passer les espaces et virgules }
        While (I <= Length(TrimLine)) And 
              ((TrimLine[I] = ' ') Or (TrimLine[I] = ',') Or
               (TrimLine[I] = #9)) Do
          Inc(I);
        
        { Verifier si fin de clause }
        If (I <= Length(TrimLine)) And (TrimLine[I] = ';') Then
        Begin
          InUsesClause := False;
          Break;
        End;
        
        { Extraire le nom d'unite }
        StartPos := I;
        While (I <= Length(TrimLine)) And 
              (TrimLine[I] <> ' ') And (TrimLine[I] <> ',') And
              (TrimLine[I] <> ';') And (TrimLine[I] <> #9) And
              (TrimLine[I] <> '{') Do
          Inc(I);
        
        If I > StartPos Then
        Begin
          UnitName := Copy(TrimLine, StartPos, I - StartPos);
          { Ignorer le mot-cle 'in' pour les chemins specifiques }
          If UpStr(UnitName) <> 'IN' Then
            AddDependency(FileName, UnitName, DEP_USES, LineNum, False);
        End;
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractJavaDependencies(Const FileName: String);
{ Extrait les declarations import des fichiers Java }
Var
  F: Text;
  Line, TrimLine, Target: String;
  LineNum, I, StartPos: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Enlever les espaces au debut }
    TrimLine := Line;
    While (Length(TrimLine) > 0) And (TrimLine[1] = ' ') Do
      Delete(TrimLine, 1, 1);
    
    { Chercher import }
    If (Length(TrimLine) >= 6) And (Copy(TrimLine, 1, 6) = 'import') And
       ((Length(TrimLine) = 6) Or (TrimLine[7] = ' ')) Then
    Begin
      I := 7;
      While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      
      { Passer 'static' si present }
      If (I + 5 <= Length(TrimLine)) And
         (Copy(TrimLine, I, 6) = 'static') Then
      Begin
        I := I + 6;
        While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      End;
      
      StartPos := I;
      While (I <= Length(TrimLine)) And (TrimLine[I] <> ';') And
            (TrimLine[I] <> ' ') Do Inc(I);
      
      Target := Copy(TrimLine, StartPos, I - StartPos);
      If Length(Target) > 0 Then
        AddDependency(FileName, Target, DEP_IMPORT, LineNum, False);
    End;
    
    { Chercher package (pour reference) }
    If (Length(TrimLine) >= 7) And (Copy(TrimLine, 1, 7) = 'package') And
       ((Length(TrimLine) = 7) Or (TrimLine[8] = ' ')) Then
    Begin
      I := 8;
      While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      
      StartPos := I;
      While (I <= Length(TrimLine)) And (TrimLine[I] <> ';') And
            (TrimLine[I] <> ' ') Do Inc(I);
      
      Target := Copy(TrimLine, StartPos, I - StartPos);
      If Length(Target) > 0 Then
        AddDependency(FileName, Target, DEP_PACKAGE, LineNum, False);
    End;
  End;
  
  Close(F);
End;

Procedure ExtractPythonDependencies(Const FileName: String);
{ Extrait les declarations import et from...import des fichiers Python }
Var
  F: Text;
  Line, TrimLine, Target, Module: String;
  LineNum, I, StartPos: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Enlever les espaces au debut }
    TrimLine := Line;
    While (Length(TrimLine) > 0) And (TrimLine[1] = ' ') Do
      Delete(TrimLine, 1, 1);
    While (Length(TrimLine) > 0) And (TrimLine[1] = #9) Do
      Delete(TrimLine, 1, 1);
    
    { Chercher from ... import }
    If (Length(TrimLine) >= 4) And (Copy(TrimLine, 1, 4) = 'from') And
       ((Length(TrimLine) = 4) Or (TrimLine[5] = ' ')) Then
    Begin
      I := 5;
      While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      
      StartPos := I;
      While (I <= Length(TrimLine)) And (TrimLine[I] <> ' ') Do Inc(I);
      
      Module := Copy(TrimLine, StartPos, I - StartPos);
      If Length(Module) > 0 Then
        AddDependency(FileName, Module, DEP_FROM, LineNum, False);
    End
    { Chercher import simple }
    Else If (Length(TrimLine) >= 6) And (Copy(TrimLine, 1, 6) = 'import') And
       ((Length(TrimLine) = 6) Or (TrimLine[7] = ' ')) Then
    Begin
      I := 7;
      While (I <= Length(TrimLine)) And (TrimLine[I] = ' ') Do Inc(I);
      
      { Parser les modules separes par des virgules }
      While I <= Length(TrimLine) Do
      Begin
        StartPos := I;
        While (I <= Length(TrimLine)) And (TrimLine[I] <> ',') And
              (TrimLine[I] <> ' ') And (TrimLine[I] <> #9) Do Inc(I);
        
        Target := Copy(TrimLine, StartPos, I - StartPos);
        
        { Ignorer 'as' et le reste }
        If UpStr(Target) = 'AS' Then Break;
        
        If Length(Target) > 0 Then
          AddDependency(FileName, Target, DEP_IMPORT, LineNum, False);
        
        { Passer la virgule et les espaces }
        While (I <= Length(TrimLine)) And 
              ((TrimLine[I] = ',') Or (TrimLine[I] = ' ') Or
               (TrimLine[I] = #9)) Do Inc(I);
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractAdaDependencies(Const FileName: String);
{ Extrait les clauses with des fichiers Ada }
Var
  F: Text;
  Line, TrimLine, UpLine, UnitName: String;
  LineNum, I, StartPos: Integer;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Enlever les espaces au debut }
    TrimLine := Line;
    While (Length(TrimLine) > 0) And (TrimLine[1] = ' ') Do
      Delete(TrimLine, 1, 1);
    
    UpLine := UpStr(TrimLine);
    
    { Chercher with }
    If (Length(UpLine) >= 4) And (Copy(UpLine, 1, 4) = 'WITH') And
       ((Length(UpLine) = 4) Or (UpLine[5] = ' ')) Then
    Begin
      I := 5;
      { Parser les noms d'unites }
      While I <= Length(TrimLine) Do
      Begin
        { Passer les espaces et virgules }
        While (I <= Length(TrimLine)) And 
              ((TrimLine[I] = ' ') Or (TrimLine[I] = ',')) Do
          Inc(I);
        
        { Verifier si fin de clause }
        If (I <= Length(TrimLine)) And (TrimLine[I] = ';') Then Break;
        
        { Extraire le nom d'unite }
        StartPos := I;
        While (I <= Length(TrimLine)) And 
              (TrimLine[I] <> ' ') And (TrimLine[I] <> ',') And
              (TrimLine[I] <> ';') Do
          Inc(I);
        
        If I > StartPos Then
        Begin
          UnitName := Copy(TrimLine, StartPos, I - StartPos);
          AddDependency(FileName, UnitName, DEP_USES, LineNum, False);
        End;
      End;
    End;
  End;
  
  Close(F);
End;

Procedure ExtractDependencies(Const FileName: String; Lang: TSourceLanguage);
{ Extrait les dependances d un fichier source selon son langage }
Begin
  Case Lang Of
    LANG_C, LANG_CPP, LANG_OBJC:
      ExtractCppDependencies(FileName);
    LANG_PASCAL:
      ExtractPascalDependencies(FileName);
    LANG_JAVA, LANG_KOTLIN:
      ExtractJavaDependencies(FileName);
    LANG_PYTHON:
      ExtractPythonDependencies(FileName);
    LANG_ADA:
      ExtractAdaDependencies(FileName);
  End;
End;

Function ExtractFileName(Const Path: String): String;
{ Extrait le nom de fichier d un chemin }
Var
  I: Integer;
Begin
  ExtractFileName := Path;
  For I := Length(Path) DownTo 1 Do
  Begin
    If (Path[I] = '/') Or (Path[I] = '\') Then
    Begin
      ExtractFileName := Copy(Path, I + 1, Length(Path) - I);
      Exit;
    End;
  End;
End;

Function ExtractFilePath(Const Path: String): String;
{ Extrait le chemin d un fichier }
Var
  I: Integer;
Begin
  ExtractFilePath := '';
  For I := Length(Path) DownTo 1 Do
  Begin
    If (Path[I] = '/') Or (Path[I] = '\') Then
    Begin
      ExtractFilePath := Copy(Path, 1, I);
      Exit;
    End;
  End;
End;

Function ResolveDependencyPath(Const BaseFile, FileName: String;
  Const IncludePaths: String): String;
{ Resout le chemin complet d un fichier inclus en parcourant les repertoires.
  IncludePaths est une liste de chemins separes par ';' }
Var
  BasePath, TestPath, PathItem: String;
  I, Start: Integer;
Begin
  ResolveDependencyPath := FileName;
  
  { D abord essayer dans le meme repertoire que le fichier source }
  BasePath := ExtractFilePath(BaseFile);
  If Length(BasePath) > 0 Then
  Begin
    TestPath := BasePath + FileName;
    If FileExists(TestPath) Then
    Begin
      ResolveDependencyPath := TestPath;
      Exit;
    End;
  End;
  
  { Essayer le fichier tel quel }
  If FileExists(FileName) Then
  Begin
    ResolveDependencyPath := FileName;
    Exit;
  End;
  
  { Parcourir les chemins d include }
  If Length(IncludePaths) > 0 Then
  Begin
    Start := 1;
    For I := 1 To Length(IncludePaths) + 1 Do
    Begin
      If (I > Length(IncludePaths)) Or (IncludePaths[I] = ';') Then
      Begin
        PathItem := Copy(IncludePaths, Start, I - Start);
        If Length(PathItem) > 0 Then
        Begin
          { Ajouter separateur si necessaire }
          If (PathItem[Length(PathItem)] <> '/') And
             (PathItem[Length(PathItem)] <> '\') Then
            PathItem := PathItem + '/';
          TestPath := PathItem + FileName;
          If FileExists(TestPath) Then
          Begin
            ResolveDependencyPath := TestPath;
            Exit;
          End;
        End;
        Start := I + 1;
      End;
    End;
  End;
End;

Procedure BuildDependencyGraph;
{ Construit le graphe de dependances et detecte les cycles.
  Affiche un avertissement pour chaque dependance circulaire trouvee. }
Var
  I, J: Integer;
  Visited: Array[1..MAX_DEPENDENCIES] Of Boolean;
  InStack: Array[1..MAX_DEPENDENCIES] Of Boolean;
  
  Function FindDepsForFile(Const FileName: String): Integer;
  { Retourne l index de la premiere dependance pour un fichier, ou 0 }
  Var
    K: Integer;
  Begin
    FindDepsForFile := 0;
    For K := 1 To DependencyCount Do
    Begin
      If Dependencies[K].SourceFile = FileName Then
      Begin
        FindDepsForFile := K;
        Exit;
      End;
    End;
  End;
  
  Procedure DetectCycleDFS(Const CurrentFile: String; Depth: Integer);
  { Parcours en profondeur pour detecter les cycles }
  Var
    M: Integer;
  Begin
    If Depth > 100 Then Exit;  { Protection contre les recursions trop profondes }
    
    For M := 1 To DependencyCount Do
    Begin
      If Dependencies[M].SourceFile = CurrentFile Then
      Begin
        { Verifier si on revient sur un fichier deja dans la pile }
        If InStack[M] Then
        Begin
          WriteLn('Avertissement: Dependance circulaire detectee impliquant: ',
            Dependencies[M].TargetFile);
        End
        Else If Not Visited[M] Then
        Begin
          Visited[M] := True;
          InStack[M] := True;
          DetectCycleDFS(Dependencies[M].TargetFile, Depth + 1);
          InStack[M] := False;
        End;
      End;
    End;
  End;
  
Begin
  If DependencyCount = 0 Then Exit;
  
  { Initialiser les tableaux }
  For I := 1 To DependencyCount Do
  Begin
    Visited[I] := False;
    InStack[I] := False;
  End;
  
  { Lancer la detection de cycles depuis chaque fichier source }
  For I := 1 To DependencyCount Do
  Begin
    If Not Visited[I] Then
    Begin
      Visited[I] := True;
      InStack[I] := True;
      DetectCycleDFS(Dependencies[I].TargetFile, 1);
      InStack[I] := False;
    End;
  End;
End;

Function GetFileDependencies(Const FileName: String): String;
{ Retourne la liste des fichiers dont depend FileName }
Var
  I: Integer;
  Result: String;
  BaseName: String;
Begin
  Result := '';
  BaseName := ExtractFileName(FileName);
  
  For I := 1 To DependencyCount Do
  Begin
    If (Dependencies[I].SourceFile = FileName) Or
       (ExtractFileName(Dependencies[I].SourceFile) = BaseName) Then
    Begin
      If Length(Result) > 0 Then Result := Result + ', ';
      Result := Result + Dependencies[I].TargetFile;
    End;
  End;
  
  GetFileDependencies := Result;
End;

Function GetFileDependents(Const FileName: String): String;
{ Retourne la liste des fichiers qui dependent de FileName }
Var
  I: Integer;
  Result: String;
  BaseName: String;
Begin
  Result := '';
  BaseName := ExtractFileName(FileName);
  
  For I := 1 To DependencyCount Do
  Begin
    If (Dependencies[I].TargetFile = FileName) Or
       (Dependencies[I].TargetFile = BaseName) Or
       (ExtractFileName(Dependencies[I].TargetFile) = BaseName) Then
    Begin
      If Length(Result) > 0 Then Result := Result + ', ';
      Result := Result + Dependencies[I].SourceFile;
    End;
  End;
  
  GetFileDependents := Result;
End;

Function CountDependencies(Const FileName: String): Integer;
{ Compte le nombre de dependances d un fichier }
Var
  I, Count: Integer;
  BaseName: String;
Begin
  Count := 0;
  BaseName := ExtractFileName(FileName);
  
  For I := 1 To DependencyCount Do
  Begin
    If (Dependencies[I].SourceFile = FileName) Or
       (ExtractFileName(Dependencies[I].SourceFile) = BaseName) Then
      Inc(Count);
  End;
  
  CountDependencies := Count;
End;

Function CountDependents(Const FileName: String): Integer;
{ Compte le nombre de fichiers qui dependent de FileName }
Var
  I, Count: Integer;
  BaseName: String;
Begin
  Count := 0;
  BaseName := ExtractFileName(FileName);
  
  For I := 1 To DependencyCount Do
  Begin
    If (Dependencies[I].TargetFile = FileName) Or
       (Dependencies[I].TargetFile = BaseName) Or
       (ExtractFileName(Dependencies[I].TargetFile) = BaseName) Then
      Inc(Count);
  End;
  
  CountDependents := Count;
End;

Procedure ShowDependencies;
{ Affiche le graphe des dependances extrait }
Var
  I: Integer;
  LastSource: String;
Begin
  If DependencyCount = 0 Then
  Begin
    WriteLn('Aucune dependance trouvee.');
    Exit;
  End;
  
  WriteLn('Dependances extraites (', DependencyCount, ' total):');
  WriteLn;
  
  LastSource := '';
  For I := 1 To DependencyCount Do
  Begin
    If Dependencies[I].SourceFile <> LastSource Then
    Begin
      If LastSource <> '' Then WriteLn;
      WriteLn('Fichier: ', Dependencies[I].SourceFile);
      LastSource := Dependencies[I].SourceFile;
    End;
    
    Write('  L', Dependencies[I].Line, ': ');
    Write(DependencyKindToStr(Dependencies[I].Kind), ' ');
    Write(Dependencies[I].TargetFile);
    If Dependencies[I].IsSystem Then
      Write(' (systeme)');
    WriteLn;
  End;
  WriteLn;
  
  { Afficher le resume }
  WriteLn('Resume:');
  WriteLn('  Total dependances: ', DependencyCount);
  
  { Detecter les cycles }
  BuildDependencyGraph;
End;

{ ============================================================
  TODO 11 - GENERATION DE LA TABLE DES MATIERES ET INDEX
  ============================================================ }

Procedure InitIndex;
{ Initialise l'index }
Begin
  IndexCount := 0;
End;

Function MakeAnchor(Const Name: String; Kind: TEntityKind): String;
{ Genere un identifiant d'ancre HTML a partir du nom et du type }
Var
  R: String;
  I: Integer;
  C: Char;
Begin
  R := EntityKindToStr(Kind) + '_';
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If ((C >= 'a') And (C <= 'z')) Or
       ((C >= 'A') And (C <= 'Z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Then
      R := R + C
    Else If (C = ':') Or (C = ' ') Or (C = '.') Then
      R := R + '_'
    Else
      R := R + '_';
  End;
  MakeAnchor := R;
End;

Function MakeSortKey(Const Name: String): String;
{ Genere une cle de tri (nom en minuscules sans prefixes) }
Var
  R: String;
  I: Integer;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    If (Name[I] >= 'A') And (Name[I] <= 'Z') Then
      R := R + Chr(Ord(Name[I]) + 32)
    Else If (Name[I] >= 'a') And (Name[I] <= 'z') Then
      R := R + Name[I]
    Else If (Name[I] >= '0') And (Name[I] <= '9') Then
      R := R + Name[I]
    Else If Name[I] = '_' Then
      R := R + Name[I];
  End;
  MakeSortKey := R;
End;

Procedure AddIndexEntry(Const Name, FileName: String; EntityId: Integer;
  Kind: TEntityKind);
{ Ajoute une entree dans l'index }
Begin
  If IndexCount >= MAX_INDEX_ENTRIES Then Exit;
  Inc(IndexCount);
  IndexEntries[IndexCount].Name := Name;
  IndexEntries[IndexCount].EntityId := EntityId;
  IndexEntries[IndexCount].FileName := FileName;
  IndexEntries[IndexCount].Anchor := MakeAnchor(Name, Kind);
  IndexEntries[IndexCount].Kind := Kind;
  IndexEntries[IndexCount].SortKey := MakeSortKey(Name);
End;

Procedure SortIndex;
{ Trie l'index par ordre alphabetique (tri a bulles) }
Var
  I, J: Integer;
  Temp: TIndexEntry;
  Swapped: Boolean;
Begin
  If IndexCount < 2 Then Exit;
  
  For I := 1 To IndexCount - 1 Do
  Begin
    Swapped := False;
    For J := 1 To IndexCount - I Do
    Begin
      If IndexEntries[J].SortKey > IndexEntries[J + 1].SortKey Then
      Begin
        Temp := IndexEntries[J];
        IndexEntries[J] := IndexEntries[J + 1];
        IndexEntries[J + 1] := Temp;
        Swapped := True;
      End;
    End;
    If Not Swapped Then Exit;
  End;
End;

Procedure BuildClassIndex;
{ Construit l'index des classes/structures/interfaces }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].Kind = ENT_CLASS) Or
       (Entities[I].Kind = ENT_STRUCT) Or
       (Entities[I].Kind = ENT_INTERFACE) Then
    Begin
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, Entities[I].Kind);
    End;
  End;
End;

Procedure BuildFileIndex;
{ Construit l'index des fichiers documentes }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FILE Then
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, ENT_FILE);
  End;
End;

Procedure BuildNamespaceIndex;
{ Construit l'index des namespaces/packages/modules }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].Kind = ENT_NAMESPACE) Or
       (Entities[I].Kind = ENT_MODULE) Then
    Begin
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, Entities[I].Kind);
    End;
  End;
End;

Procedure BuildFunctionIndex;
{ Construit l'index des fonctions/methodes/procedures }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FUNCTION Then
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, ENT_FUNCTION);
  End;
End;

Procedure BuildVariableIndex;
{ Construit l'index des variables/constantes/defines }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].Kind = ENT_VARIABLE) Or
       (Entities[I].Kind = ENT_DEFINE) Then
    Begin
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, Entities[I].Kind);
    End;
  End;
End;

Procedure BuildPageIndex;
{ Construit l'index des pages personnalisees (@page) }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_PAGE Then
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, ENT_PAGE);
  End;
End;

Procedure BuildGroupIndex;
{ Construit l'index des groupes (@defgroup) }
Var
  I: Integer;
Begin
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_GROUP Then
      AddIndexEntry(Entities[I].Name, Entities[I].FileName, I, ENT_GROUP);
  End;
End;

Procedure BuildIndex;
{ Construit l'index global de toutes les entites }
Begin
  InitIndex;
  BuildClassIndex;
  BuildFileIndex;
  BuildNamespaceIndex;
  BuildFunctionIndex;
  BuildVariableIndex;
  BuildPageIndex;
  BuildGroupIndex;
  SortIndex;
End;

Procedure GenerateTOC(Var OutFile: Text);
{ Genere la table des matieres hierarchique }
Var
  I, Level, LastLevel: Integer;
  LastKind: TEntityKind;
Begin
  WriteLn(OutFile, '<!-- Table des matieres generee par DOXYGEN.PAS -->');
  WriteLn(OutFile, '<div class="toc">');
  WriteLn(OutFile, '<h2>Table des matieres</h2>');
  WriteLn(OutFile, '<ul>');
  
  LastLevel := 0;
  LastKind := ENT_UNKNOWN;
  
  { Grouper par type d'entite }
  For I := 1 To IndexCount Do
  Begin
    { Nouveau type d'entite = nouveau groupe }
    If IndexEntries[I].Kind <> LastKind Then
    Begin
      If LastKind <> ENT_UNKNOWN Then
        WriteLn(OutFile, '</ul></li>');
      
      WriteLn(OutFile, '<li><strong>', 
        UpStr(EntityKindToStr(IndexEntries[I].Kind)), 'S</strong>');
      WriteLn(OutFile, '<ul>');
      LastKind := IndexEntries[I].Kind;
    End;
    
    WriteLn(OutFile, '<li><a href="', IndexEntries[I].FileName, 
      '#', IndexEntries[I].Anchor, '">', IndexEntries[I].Name, '</a></li>');
  End;
  
  If IndexCount > 0 Then
    WriteLn(OutFile, '</ul></li>');
  
  WriteLn(OutFile, '</ul>');
  WriteLn(OutFile, '</div>');
End;

Function CountIndexEntries: Integer;
{ Retourne le nombre d'entrees dans l'index }
Begin
  CountIndexEntries := IndexCount;
End;

Function CountIndexEntriesByKind(Kind: TEntityKind): Integer;
{ Compte les entrees d'index d'un type donne }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To IndexCount Do
  Begin
    If IndexEntries[I].Kind = Kind Then
      Inc(Count);
  End;
  CountIndexEntriesByKind := Count;
End;

Function GetIndexEntry(Index: Integer): TIndexEntry;
{ Retourne une entree d'index }
Var
  Empty: TIndexEntry;
Begin
  If (Index >= 1) And (Index <= IndexCount) Then
    GetIndexEntry := IndexEntries[Index]
  Else
  Begin
    Empty.Name := '';
    Empty.EntityId := 0;
    Empty.FileName := '';
    Empty.Anchor := '';
    Empty.Kind := ENT_UNKNOWN;
    Empty.SortKey := '';
    GetIndexEntry := Empty;
  End;
End;

Function FindIndexEntry(Const Name: String): Integer;
{ Recherche une entree par nom, retourne l'index ou 0 si non trouve }
Var
  I: Integer;
  NameUp: String;
Begin
  FindIndexEntry := 0;
  NameUp := UpStr(Name);
  For I := 1 To IndexCount Do
  Begin
    If UpStr(IndexEntries[I].Name) = NameUp Then
    Begin
      FindIndexEntry := I;
      Exit;
    End;
  End;
End;

Function IsIndexEmpty: Boolean;
{ Verifie si l'index est vide }
Begin
  IsIndexEmpty := (IndexCount = 0);
End;

Procedure ShowIndex;
{ Affiche l'index (pour debug) }
Var
  I: Integer;
Begin
  If IndexCount = 0 Then
  Begin
    WriteLn('Index vide.');
    Exit;
  End;
  
  WriteLn('Index (', IndexCount, ' entrees):');
  WriteLn;
  For I := 1 To IndexCount Do
  Begin
    WriteLn(I:4, '. [', EntityKindToStr(IndexEntries[I].Kind):10, '] ',
      IndexEntries[I].Name);
    WriteLn('     Fichier: ', IndexEntries[I].FileName);
    WriteLn('     Ancre: ', IndexEntries[I].Anchor);
  End;
  WriteLn;
  WriteLn('Resume par type:');
  WriteLn('  Classes/Structures: ', CountIndexEntriesByKind(ENT_CLASS) + 
    CountIndexEntriesByKind(ENT_STRUCT) + CountIndexEntriesByKind(ENT_INTERFACE));
  WriteLn('  Fichiers: ', CountIndexEntriesByKind(ENT_FILE));
  WriteLn('  Namespaces/Modules: ', CountIndexEntriesByKind(ENT_NAMESPACE) +
    CountIndexEntriesByKind(ENT_MODULE));
  WriteLn('  Fonctions: ', CountIndexEntriesByKind(ENT_FUNCTION));
  WriteLn('  Variables/Defines: ', CountIndexEntriesByKind(ENT_VARIABLE) +
    CountIndexEntriesByKind(ENT_DEFINE));
  WriteLn('  Pages: ', CountIndexEntriesByKind(ENT_PAGE));
  WriteLn('  Groupes: ', CountIndexEntriesByKind(ENT_GROUP));
End;

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

{ ============================================================
  TODO 04 - PARSER DES BALISES DOXYGEN
  ============================================================ }

Procedure InitDocTags;
{ Initialise le tableau des balises }
Begin
  DocTagCount := 0;
End;

Procedure AddDocTag(Kind: TDoxyTagKind; Const Name, ParamName, Content: String;
  Line: Integer);
{ Ajoute une balise au tableau }
Begin
  If DocTagCount < MAX_TAGS Then
  Begin
    Inc(DocTagCount);
    DocTags[DocTagCount].Kind := Kind;
    DocTags[DocTagCount].Name := Name;
    DocTags[DocTagCount].ParamName := ParamName;
    DocTags[DocTagCount].Content := Content;
    DocTags[DocTagCount].Line := Line;
  End
  Else
    WarnMsg('Trop de balises Doxygen (max=' + IntToStr(MAX_TAGS) + ')');
End;

Function LowerStr(Const S: String): String;
{ Convertit une chaine en minuscules }
Var
  I: Integer;
  R: String;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  LowerStr := R;
End;

Function ParseTagKind(Const TagName: String): TDoxyTagKind;
{ Convertit un nom de balise en enumeration TDoxyTagKind.
  Supporte les variantes avec @ et \ (ex: @param et \param) }
Var
  Name: String;
Begin
  { Normaliser le nom (enlever @ ou \ et mettre en minuscules) }
  Name := LowerStr(TagName);
  If (Length(Name) >= 1) And ((Name[1] = '@') Or (Name[1] = '\')) Then
    Name := Copy(Name, 2, Length(Name) - 1);

  { Mapper vers l'enumeration }
  If (Name = 'brief') Or (Name = 'short') Then
    ParseTagKind := TAG_BRIEF
  Else If Name = 'details' Then
    ParseTagKind := TAG_DETAILS
  Else If Name = 'param' Then
    ParseTagKind := TAG_PARAM
  Else If Name = 'return' Then
    ParseTagKind := TAG_RETURN
  Else If Name = 'returns' Then
    ParseTagKind := TAG_RETURNS
  Else If Name = 'retval' Then
    ParseTagKind := TAG_RETVAL
  Else If Name = 'tparam' Then
    ParseTagKind := TAG_TPARAM
  Else If (Name = 'exception') Or (Name = 'throw') Or (Name = 'throws') Then
    ParseTagKind := TAG_EXCEPTION
  Else If Name = 'note' Then
    ParseTagKind := TAG_NOTE
  Else If Name = 'warning' Then
    ParseTagKind := TAG_WARNING
  Else If Name = 'attention' Then
    ParseTagKind := TAG_ATTENTION
  Else If (Name = 'remark') Or (Name = 'remarks') Then
    ParseTagKind := TAG_REMARK
  Else If Name = 'todo' Then
    ParseTagKind := TAG_TODO
  Else If Name = 'bug' Then
    ParseTagKind := TAG_BUG
  Else If Name = 'deprecated' Then
    ParseTagKind := TAG_DEPRECATED
  Else If (Name = 'author') Or (Name = 'authors') Then
    ParseTagKind := TAG_AUTHOR
  Else If Name = 'version' Then
    ParseTagKind := TAG_VERSION
  Else If Name = 'date' Then
    ParseTagKind := TAG_DATE
  Else If Name = 'since' Then
    ParseTagKind := TAG_SINCE
  Else If Name = 'copyright' Then
    ParseTagKind := TAG_COPYRIGHT
  Else If Name = 'license' Then
    ParseTagKind := TAG_LICENSE
  Else If (Name = 'see') Or (Name = 'sa') Then
    ParseTagKind := TAG_SEE
  Else If Name = 'ref' Then
    ParseTagKind := TAG_REF
  Else If Name = 'link' Then
    ParseTagKind := TAG_LINK
  Else If Name = 'endlink' Then
    ParseTagKind := TAG_ENDLINK
  Else If Name = 'code' Then
    ParseTagKind := TAG_CODE
  Else If Name = 'endcode' Then
    ParseTagKind := TAG_ENDCODE
  Else If Name = 'verbatim' Then
    ParseTagKind := TAG_VERBATIM
  Else If Name = 'endverbatim' Then
    ParseTagKind := TAG_ENDVERBATIM
  Else If Name = 'example' Then
    ParseTagKind := TAG_EXAMPLE
  Else If Name = 'snippet' Then
    ParseTagKind := TAG_SNIPPET
  Else If Name = 'include' Then
    ParseTagKind := TAG_INCLUDE
  Else If Name = 'includelineno' Then
    ParseTagKind := TAG_INCLUDELINENO
  Else If Name = 'includedoc' Then
    ParseTagKind := TAG_INCLUDEDOC
  Else If Name = 'file' Then
    ParseTagKind := TAG_FILE
  Else If Name = 'class' Then
    ParseTagKind := TAG_CLASS
  Else If Name = 'struct' Then
    ParseTagKind := TAG_STRUCT
  Else If Name = 'union' Then
    ParseTagKind := TAG_UNION
  Else If Name = 'enum' Then
    ParseTagKind := TAG_ENUM
  Else If Name = 'var' Then
    ParseTagKind := TAG_VAR
  Else If (Name = 'def') Or (Name = 'define') Then
    ParseTagKind := TAG_DEF
  Else If Name = 'typedef' Then
    ParseTagKind := TAG_TYPEDEF
  Else If (Name = 'fn') Or (Name = 'function') Then
    ParseTagKind := TAG_FN
  Else If Name = 'namespace' Then
    ParseTagKind := TAG_NAMESPACE
  Else If Name = 'package' Then
    ParseTagKind := TAG_PACKAGE
  Else If Name = 'interface' Then
    ParseTagKind := TAG_INTERFACE
  Else If Name = 'property' Then
    ParseTagKind := TAG_PROPERTY
  Else If Name = 'event' Then
    ParseTagKind := TAG_EVENT
  Else If (Name = 'relates') Or (Name = 'related') Or (Name = 'relatesalso') Then
    ParseTagKind := TAG_RELATES
  Else If Name = 'memberof' Then
    ParseTagKind := TAG_MEMBEROF
  Else If Name = 'ingroup' Then
    ParseTagKind := TAG_INGROUP
  Else If Name = 'defgroup' Then
    ParseTagKind := TAG_DEFGROUP
  Else If Name = 'addtogroup' Then
    ParseTagKind := TAG_ADDTOGROUP
  Else If Name = 'weakgroup' Then
    ParseTagKind := TAG_WEAKGROUP
  Else If Name = 'name' Then
    ParseTagKind := TAG_NAME
  Else If Name = 'mainpage' Then
    ParseTagKind := TAG_MAINPAGE
  Else If Name = 'page' Then
    ParseTagKind := TAG_PAGE
  Else If Name = 'subpage' Then
    ParseTagKind := TAG_SUBPAGE
  Else If Name = 'section' Then
    ParseTagKind := TAG_SECTION
  Else If Name = 'subsection' Then
    ParseTagKind := TAG_SUBSECTION
  Else If Name = 'paragraph' Then
    ParseTagKind := TAG_PARAGRAPH
  Else If Name = 'anchor' Then
    ParseTagKind := TAG_ANCHOR
  Else If Name = 'image' Then
    ParseTagKind := TAG_IMAGE
  Else If Name = 'dot' Then
    ParseTagKind := TAG_DOT
  Else If Name = 'enddot' Then
    ParseTagKind := TAG_ENDDOT
  Else If Name = 'msc' Then
    ParseTagKind := TAG_MSC
  Else If Name = 'endmsc' Then
    ParseTagKind := TAG_ENDMSC
  Else If Name = 'startuml' Then
    ParseTagKind := TAG_STARTUML
  Else If Name = 'enduml' Then
    ParseTagKind := TAG_ENDUML
  Else If Name = 'htmlonly' Then
    ParseTagKind := TAG_HTMLONLY
  Else If Name = 'endhtmlonly' Then
    ParseTagKind := TAG_ENDHTMLONLY
  Else If Name = 'latexonly' Then
    ParseTagKind := TAG_LATEXONLY
  Else If Name = 'endlatexonly' Then
    ParseTagKind := TAG_ENDLATEXONLY
  Else If Name = 'xmlonly' Then
    ParseTagKind := TAG_XMLONLY
  Else If Name = 'endxmlonly' Then
    ParseTagKind := TAG_ENDXMLONLY
  Else If Name = 'rtfonly' Then
    ParseTagKind := TAG_RTFONLY
  Else If Name = 'endrtfonly' Then
    ParseTagKind := TAG_ENDRTFONLY
  Else If Name = 'manonly' Then
    ParseTagKind := TAG_MANONLY
  Else If Name = 'endmanonly' Then
    ParseTagKind := TAG_ENDMANONLY
  Else If Name = 'docbookonly' Then
    ParseTagKind := TAG_DOCBOOKONLY
  Else If Name = 'enddocbookonly' Then
    ParseTagKind := TAG_ENDDOCBOOKONLY
  Else If Name = 'if' Then
    ParseTagKind := TAG_IF
  Else If Name = 'ifnot' Then
    ParseTagKind := TAG_IFNOT
  Else If Name = 'else' Then
    ParseTagKind := TAG_ELSE
  Else If Name = 'elseif' Then
    ParseTagKind := TAG_ELSEIF
  Else If Name = 'endif' Then
    ParseTagKind := TAG_ENDIF
  Else If Name = 'cond' Then
    ParseTagKind := TAG_COND
  Else If Name = 'endcond' Then
    ParseTagKind := TAG_ENDCOND
  Else If Name = 'copydoc' Then
    ParseTagKind := TAG_COPYDOC
  Else If Name = 'copybrief' Then
    ParseTagKind := TAG_COPYBRIEF
  Else If Name = 'copydetails' Then
    ParseTagKind := TAG_COPYDETAILS
  Else If Name = 'internal' Then
    ParseTagKind := TAG_INTERNAL
  Else If Name = 'endinternal' Then
    ParseTagKind := TAG_ENDINTERNAL
  Else If Name = 'par' Then
    ParseTagKind := TAG_PAR
  Else If Name = 'parblock' Then
    ParseTagKind := TAG_PARBLOCK
  Else If Name = 'endparblock' Then
    ParseTagKind := TAG_ENDPARBLOCK
  Else If Name = 'pure' Then
    ParseTagKind := TAG_PURE
  Else If Name = 'static' Then
    ParseTagKind := TAG_STATIC
  Else If Name = 'private' Then
    ParseTagKind := TAG_PRIVATE
  Else If Name = 'protected' Then
    ParseTagKind := TAG_PROTECTED
  Else If Name = 'public' Then
    ParseTagKind := TAG_PUBLIC
  Else If Name = 'nosubgrouping' Then
    ParseTagKind := TAG_NOSUBGROUPING
  Else If Name = 'showinitializer' Then
    ParseTagKind := TAG_SHOWINITIALIZER
  Else If Name = 'hideinitializer' Then
    ParseTagKind := TAG_HIDEINITIALIZER
  Else If Name = 'callgraph' Then
    ParseTagKind := TAG_CALLGRAPH
  Else If Name = 'hidecallgraph' Then
    ParseTagKind := TAG_HIDECALLGRAPH
  Else If Name = 'callergraph' Then
    ParseTagKind := TAG_CALLERGRAPH
  Else If Name = 'hidecallergraph' Then
    ParseTagKind := TAG_HIDECALLERGRAPH
  Else If Name = 'dir' Then
    ParseTagKind := TAG_DIR
  Else If Name = 'dontinclude' Then
    ParseTagKind := TAG_DONTINCLUDE
  Else If Name = 'line' Then
    ParseTagKind := TAG_LINE
  Else If Name = 'skip' Then
    ParseTagKind := TAG_SKIP
  Else If Name = 'skipline' Then
    ParseTagKind := TAG_SKIPLINE
  Else If Name = 'until' Then
    ParseTagKind := TAG_UNTIL
  Else If Name = 'test' Then
    ParseTagKind := TAG_TEST
  Else If Name = 'xrefitem' Then
    ParseTagKind := TAG_XREFITEM
  Else If Name = 'invariant' Then
    ParseTagKind := TAG_INVARIANT
  Else If Name = 'pre' Then
    ParseTagKind := TAG_PRE
  Else If Name = 'post' Then
    ParseTagKind := TAG_POST
  Else
    ParseTagKind := TAG_UNKNOWN;
End;

Function TagKindToStr(Kind: TDoxyTagKind): String;
{ Convertit un TDoxyTagKind en chaine pour affichage }
Begin
  Case Kind Of
    TAG_BRIEF:       TagKindToStr := '@brief';
    TAG_DETAILS:     TagKindToStr := '@details';
    TAG_PARAM:       TagKindToStr := '@param';
    TAG_RETURN:      TagKindToStr := '@return';
    TAG_RETURNS:     TagKindToStr := '@returns';
    TAG_RETVAL:      TagKindToStr := '@retval';
    TAG_TPARAM:      TagKindToStr := '@tparam';
    TAG_EXCEPTION:   TagKindToStr := '@exception';
    TAG_NOTE:        TagKindToStr := '@note';
    TAG_WARNING:     TagKindToStr := '@warning';
    TAG_ATTENTION:   TagKindToStr := '@attention';
    TAG_REMARK:      TagKindToStr := '@remark';
    TAG_TODO:        TagKindToStr := '@todo';
    TAG_BUG:         TagKindToStr := '@bug';
    TAG_DEPRECATED:  TagKindToStr := '@deprecated';
    TAG_AUTHOR:      TagKindToStr := '@author';
    TAG_VERSION:     TagKindToStr := '@version';
    TAG_DATE:        TagKindToStr := '@date';
    TAG_SINCE:       TagKindToStr := '@since';
    TAG_COPYRIGHT:   TagKindToStr := '@copyright';
    TAG_LICENSE:     TagKindToStr := '@license';
    TAG_SEE:         TagKindToStr := '@see';
    TAG_REF:         TagKindToStr := '@ref';
    TAG_LINK:        TagKindToStr := '@link';
    TAG_CODE:        TagKindToStr := '@code';
    TAG_ENDCODE:     TagKindToStr := '@endcode';
    TAG_VERBATIM:    TagKindToStr := '@verbatim';
    TAG_ENDVERBATIM: TagKindToStr := '@endverbatim';
    TAG_EXAMPLE:     TagKindToStr := '@example';
    TAG_FILE:        TagKindToStr := '@file';
    TAG_CLASS:       TagKindToStr := '@class';
    TAG_STRUCT:      TagKindToStr := '@struct';
    TAG_ENUM:        TagKindToStr := '@enum';
    TAG_VAR:         TagKindToStr := '@var';
    TAG_FN:          TagKindToStr := '@fn';
    TAG_NAMESPACE:   TagKindToStr := '@namespace';
    TAG_PACKAGE:     TagKindToStr := '@package';
    TAG_INTERFACE:   TagKindToStr := '@interface';
    TAG_MAINPAGE:    TagKindToStr := '@mainpage';
    TAG_PAGE:        TagKindToStr := '@page';
    TAG_SECTION:     TagKindToStr := '@section';
    TAG_SUBSECTION:  TagKindToStr := '@subsection';
    TAG_INVARIANT:   TagKindToStr := '@invariant';
    TAG_PRE:         TagKindToStr := '@pre';
    TAG_POST:        TagKindToStr := '@post';
    TAG_TEXT:        TagKindToStr := '(text)';
  Else
    TagKindToStr := '@unknown';
  End;
End;

Function IsTagStart(Ch: Char): Boolean;
{ Verifie si un caractere est un debut de balise (@ ou \) }
Begin
  IsTagStart := (Ch = '@') Or (Ch = '\');
End;

{ Note: IsIdentChar est definie dans TODO 08 - EXTRACTION DES ENTITES DOCUMENTEES }

Function TagNeedsParamName(Kind: TDoxyTagKind): Boolean;
{ Verifie si une balise prend un nom de parametre comme premier argument }
Begin
  TagNeedsParamName := (Kind = TAG_PARAM) Or (Kind = TAG_TPARAM) Or
                       (Kind = TAG_RETVAL) Or (Kind = TAG_EXCEPTION) Or
                       (Kind = TAG_THROW) Or (Kind = TAG_THROWS);
End;

Procedure ParseDocComment(Const Comment: String; CommentLine: Integer);
{ Parse un commentaire de documentation et extrait les balises Doxygen.
  Les balises sont stockees dans le tableau global DocTags. }
Var
  I, J: Integer;
  TagName, ParamName: String;
  Kind: TDoxyTagKind;
  InTag: Boolean;
  CurrentContent: String;
  CurrentTagKind: TDoxyTagKind;
  CurrentParamName: String;
  CurrentTagName: String;
  CurrentTagLine: Integer;
Begin
  InitDocTags;

  If Length(Comment) = 0 Then Exit;

  I := 1;
  InTag := False;
  CurrentContent := '';
  CurrentTagKind := TAG_TEXT;
  CurrentParamName := '';
  CurrentTagName := '';
  CurrentTagLine := CommentLine;

  While I <= Length(Comment) Do
  Begin
    { Detecter le debut d'une balise @ ou \ }
    If IsTagStart(Comment[I]) And (I < Length(Comment)) And
       IsIdentChar(Comment[I + 1]) Then
    Begin
      { Sauvegarder la balise/contenu precedent }
      If InTag Or (TrimStr(CurrentContent) <> '') Then
      Begin
        AddDocTag(CurrentTagKind, CurrentTagName, CurrentParamName,
                  TrimStr(CurrentContent), CurrentTagLine);
      End;

      { Extraire le nom de la nouvelle balise }
      Inc(I); { Sauter @ ou \ }
      J := I;
      While (J <= Length(Comment)) And IsIdentChar(Comment[J]) Do Inc(J);
      TagName := Copy(Comment, I, J - I);
      I := J;

      { Identifier le type de balise }
      Kind := ParseTagKind(TagName);

      { Sauter les espaces apres le nom de balise }
      While (I <= Length(Comment)) And (Comment[I] = ' ') Do Inc(I);

      { Pour certaines balises, extraire le nom du parametre }
      ParamName := '';
      If TagNeedsParamName(Kind) And (I <= Length(Comment)) Then
      Begin
        J := I;
        While (J <= Length(Comment)) And (Comment[J] <> ' ') And
              (Comment[J] <> #9) And (Not IsTagStart(Comment[J])) Do Inc(J);
        ParamName := Copy(Comment, I, J - I);
        I := J;
        { Sauter les espaces apres le nom du parametre }
        While (I <= Length(Comment)) And (Comment[I] = ' ') Do Inc(I);
      End;

      { Initialiser la nouvelle balise }
      CurrentTagKind := Kind;
      CurrentTagName := TagName;
      CurrentParamName := ParamName;
      CurrentContent := '';
      CurrentTagLine := CommentLine;
      InTag := True;
    End
    Else
    Begin
      { Ajouter le caractere au contenu courant }
      CurrentContent := CurrentContent + Comment[I];
      Inc(I);
    End;
  End;

  { Sauvegarder la derniere balise/contenu }
  If InTag Or (TrimStr(CurrentContent) <> '') Then
  Begin
    AddDocTag(CurrentTagKind, CurrentTagName, CurrentParamName,
              TrimStr(CurrentContent), CurrentTagLine);
  End;
End;

Procedure ParseAllDocComments;
{ Parse tous les commentaires de documentation extraits et
  collecte toutes les balises dans DocTags }
Var
  I: Integer;
  TotalTags: Integer;
  Tags: Array[1..MAX_TAGS] Of TDoxyTag;
  J: Integer;
Begin
  InitDocTags;
  TotalTags := 0;

  For I := 1 To DocTokenCount Do
  Begin
    ParseDocComment(DocTokens[I].Text, DocTokens[I].Line);
    { Accumuler les tags de ce commentaire }
    For J := 1 To DocTagCount Do
    Begin
      If TotalTags < MAX_TAGS Then
      Begin
        Inc(TotalTags);
        Tags[TotalTags] := DocTags[J];
      End;
    End;
  End;

  { Copier tous les tags accumules dans DocTags }
  InitDocTags;
  For I := 1 To TotalTags Do
  Begin
    Inc(DocTagCount);
    DocTags[DocTagCount] := Tags[I];
  End;
End;

Function GetBriefDescription: String;
{ Extrait la description breve (@brief ou premiere phrase si pas de @brief) }
Var
  I, J: Integer;
  Result: String;
  DotPos: Integer;
Begin
  Result := '';

  { Chercher d'abord un tag @brief explicite }
  For I := 1 To DocTagCount Do
  Begin
    If DocTags[I].Kind = TAG_BRIEF Then
    Begin
      Result := DocTags[I].Content;
      GetBriefDescription := Result;
      Exit;
    End;
  End;

  { Sinon, prendre la premiere phrase du premier texte ou du @details }
  For I := 1 To DocTagCount Do
  Begin
    If (DocTags[I].Kind = TAG_TEXT) Or (DocTags[I].Kind = TAG_DETAILS) Then
    Begin
      Result := DocTags[I].Content;
      { Trouver le premier point suivi d'un espace ou fin de chaine }
      DotPos := 0;
      For J := 1 To Length(Result) Do
      Begin
        If (Result[J] = '.') Then
        Begin
          If (J = Length(Result)) Or (Result[J + 1] = ' ') Then
          Begin
            DotPos := J;
            Break;
          End;
        End;
      End;
      If DotPos > 0 Then
        Result := Copy(Result, 1, DotPos);
      GetBriefDescription := Result;
      Exit;
    End;
  End;

  GetBriefDescription := '';
End;

Function GetDetailedDescription: String;
{ Extrait la description detaillee (@details ou texte apres @brief) }
Var
  I: Integer;
  Result: String;
  HasBrief: Boolean;
  BriefContent: String;
Begin
  Result := '';
  HasBrief := False;
  BriefContent := '';

  { Verifier s'il y a un @brief }
  For I := 1 To DocTagCount Do
  Begin
    If DocTags[I].Kind = TAG_BRIEF Then
    Begin
      HasBrief := True;
      BriefContent := DocTags[I].Content;
      Break;
    End;
  End;

  { Chercher un tag @details explicite }
  For I := 1 To DocTagCount Do
  Begin
    If DocTags[I].Kind = TAG_DETAILS Then
    Begin
      If Result <> '' Then Result := Result + ' ';
      Result := Result + DocTags[I].Content;
    End;
  End;

  { Si pas de @details, prendre le texte libre (sauf si c'est le @brief) }
  If Result = '' Then
  Begin
    For I := 1 To DocTagCount Do
    Begin
      If DocTags[I].Kind = TAG_TEXT Then
      Begin
        If HasBrief And (DocTags[I].Content = BriefContent) Then
          Continue;
        If Result <> '' Then Result := Result + ' ';
        Result := Result + DocTags[I].Content;
      End;
    End;
  End;

  GetDetailedDescription := Result;
End;

{ ============================================================
  TODO 05 - LECTURE ET PARSING DU FICHIER DE CONFIGURATION
  ============================================================ }

Procedure InitConfig;
{ Initialise le tableau de configuration }
Begin
  ConfigCount := 0;
End;

Function FindConfigOption(Const Name: String): Integer;
{ Trouve l'index d'une option par son nom, retourne 0 si non trouvee }
Var
  I: Integer;
  UpName: String;
Begin
  UpName := UpStr(Name);
  For I := 1 To ConfigCount Do
  Begin
    If UpStr(Config[I].Name) = UpName Then
    Begin
      FindConfigOption := I;
      Exit;
    End;
  End;
  FindConfigOption := 0;
End;

Procedure SetConfigOption(Const Name, Value: String; LineNum: Integer; Append: Boolean);
{ Definit ou ajoute une valeur a une option de configuration }
Var
  Idx: Integer;
Begin
  Idx := FindConfigOption(Name);
  If Idx > 0 Then
  Begin
    { Option existante }
    If Append Then
      Config[Idx].Value := Config[Idx].Value + ' ' + Value
    Else
      Config[Idx].Value := Value;
    Config[Idx].IsSet := True;
  End
  Else If ConfigCount < MAX_CONFIG_OPTIONS Then
  Begin
    { Nouvelle option }
    Inc(ConfigCount);
    Config[ConfigCount].Name := Name;
    Config[ConfigCount].Value := Value;
    Config[ConfigCount].IsSet := True;
    Config[ConfigCount].Line := LineNum;
  End;
End;

Function GetConfigValue(Const Name: String): String;
{ Retourne la valeur d'une option de configuration }
Var
  Idx: Integer;
Begin
  Idx := FindConfigOption(Name);
  If Idx > 0 Then
    GetConfigValue := Config[Idx].Value
  Else
    GetConfigValue := '';
End;

Function GetConfigBool(Const Name: String): Boolean;
{ Retourne True si la valeur est YES/TRUE/1/ON }
Var
  Val: String;
Begin
  Val := UpStr(GetConfigValue(Name));
  GetConfigBool := (Val = 'YES') Or (Val = 'TRUE') Or 
                   (Val = '1') Or (Val = 'ON');
End;

Function GetConfigInt(Const Name: String): Integer;
{ Retourne la valeur numerique d'une option }
Var
  ValStr: String;
  N, Code: Integer;
Begin
  ValStr := GetConfigValue(Name);
  If ValStr = '' Then
    GetConfigInt := 0
  Else
  Begin
    System.Val(ValStr, N, Code);
    If Code = 0 Then
      GetConfigInt := N
    Else
      GetConfigInt := 0;
  End;
End;

Function StripQuotes(Const S: String): String;
{ Supprime les guillemets autour d'une chaine }
Var
  Temp: String;
Begin
  Temp := TrimStr(S);
  If Length(Temp) >= 2 Then
  Begin
    If ((Temp[1] = '"') And (Temp[Length(Temp)] = '"')) Or
       ((Temp[1] = '''') And (Temp[Length(Temp)] = '''')) Then
      StripQuotes := Copy(Temp, 2, Length(Temp) - 2)
    Else
      StripQuotes := Temp;
  End
  Else
    StripQuotes := Temp;
End;

Procedure ReadConfigFile(Const FileName: String);
{ Lit et parse un fichier de configuration Doxyfile }
Var
  F: Text;
  Line, TempLine: String;
  LineNum: Integer;
  EqPos, PlusEqPos: Integer;
  Name, Value: String;
  Append: Boolean;
  I: Integer;
  InContinuation: Boolean;
  ContinuedValue: String;
Begin
  InitConfig;
  
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible d''ouvrir le fichier: ' + FileName);
    Exit;
  End;

  LineNum := 0;
  InContinuation := False;
  ContinuedValue := '';
  Name := '';
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    
    { Supprimer les espaces en debut et fin }
    Line := TrimStr(Line);
    
    { Ignorer les lignes vides }
    If Length(Line) = 0 Then Continue;
    
    { Ignorer les commentaires (lignes commencant par #) }
    If Line[1] = '#' Then Continue;
    
    { Gerer les continuations de ligne }
    If InContinuation Then
    Begin
      { Verifier si la ligne continue encore }
      If (Length(Line) > 0) And (Line[Length(Line)] = '\') Then
      Begin
        ContinuedValue := ContinuedValue + ' ' + Copy(Line, 1, Length(Line) - 1);
      End
      Else
      Begin
        ContinuedValue := ContinuedValue + ' ' + Line;
        SetConfigOption(Name, TrimStr(ContinuedValue), LineNum, False);
        InContinuation := False;
      End;
      Continue;
    End;
    
    { Chercher l'operateur = ou += }
    EqPos := 0;
    PlusEqPos := 0;
    Append := False;
    
    For I := 1 To Length(Line) Do
    Begin
      If (I < Length(Line)) And (Line[I] = '+') And (Line[I + 1] = '=') Then
      Begin
        PlusEqPos := I;
        Break;
      End;
      If Line[I] = '=' Then
      Begin
        EqPos := I;
        Break;
      End;
    End;
    
    If PlusEqPos > 0 Then
    Begin
      Name := TrimStr(Copy(Line, 1, PlusEqPos - 1));
      Value := TrimStr(Copy(Line, PlusEqPos + 2, Length(Line)));
      Append := True;
    End
    Else If EqPos > 0 Then
    Begin
      Name := TrimStr(Copy(Line, 1, EqPos - 1));
      Value := TrimStr(Copy(Line, EqPos + 1, Length(Line)));
      Append := False;
    End
    Else
      Continue; { Ligne invalide }
    
    { Supprimer les guillemets }
    Value := StripQuotes(Value);
    
    { Verifier si la ligne continue }
    If (Length(Value) > 0) And (Value[Length(Value)] = '\') Then
    Begin
      InContinuation := True;
      ContinuedValue := Copy(Value, 1, Length(Value) - 1);
    End
    Else
    Begin
      SetConfigOption(Name, Value, LineNum, Append);
    End;
  End;
  
  Close(F);
  
  InfoMsg('Configuration chargee: ' + IntToStr(ConfigCount) + ' options');
End;

Procedure SetDefaultConfigOptions;
{ Definit les valeurs par defaut des options principales }
Begin
  { Projet }
  SetConfigOption('PROJECT_NAME', 'My Project', 0, False);
  SetConfigOption('PROJECT_NUMBER', '', 0, False);
  SetConfigOption('PROJECT_BRIEF', '', 0, False);
  SetConfigOption('PROJECT_LOGO', '', 0, False);
  SetConfigOption('OUTPUT_DIRECTORY', '', 0, False);
  SetConfigOption('OUTPUT_LANGUAGE', 'English', 0, False);
  
  { Build }
  SetConfigOption('EXTRACT_ALL', 'NO', 0, False);
  SetConfigOption('EXTRACT_PRIVATE', 'NO', 0, False);
  SetConfigOption('EXTRACT_STATIC', 'NO', 0, False);
  SetConfigOption('HIDE_UNDOC_MEMBERS', 'NO', 0, False);
  SetConfigOption('HIDE_UNDOC_CLASSES', 'NO', 0, False);
  SetConfigOption('BRIEF_MEMBER_DESC', 'YES', 0, False);
  SetConfigOption('REPEAT_BRIEF', 'YES', 0, False);
  SetConfigOption('ALWAYS_DETAILED_SEC', 'NO', 0, False);
  SetConfigOption('INLINE_INHERITED_MEMB', 'NO', 0, False);
  SetConfigOption('FULL_PATH_NAMES', 'YES', 0, False);
  SetConfigOption('SHORT_NAMES', 'NO', 0, False);
  SetConfigOption('JAVADOC_AUTOBRIEF', 'NO', 0, False);
  SetConfigOption('QT_AUTOBRIEF', 'NO', 0, False);
  SetConfigOption('MULTILINE_CPP_IS_BRIEF', 'NO', 0, False);
  SetConfigOption('INHERIT_DOCS', 'YES', 0, False);
  SetConfigOption('SEPARATE_MEMBER_PAGES', 'NO', 0, False);
  SetConfigOption('TAB_SIZE', '4', 0, False);
  SetConfigOption('OPTIMIZE_OUTPUT_FOR_C', 'NO', 0, False);
  SetConfigOption('OPTIMIZE_OUTPUT_JAVA', 'NO', 0, False);
  SetConfigOption('OPTIMIZE_FOR_FORTRAN', 'NO', 0, False);
  SetConfigOption('OPTIMIZE_OUTPUT_VHDL', 'NO', 0, False);
  
  { Messages }
  SetConfigOption('QUIET', 'NO', 0, False);
  SetConfigOption('WARNINGS', 'YES', 0, False);
  SetConfigOption('WARN_IF_UNDOCUMENTED', 'YES', 0, False);
  SetConfigOption('WARN_IF_DOC_ERROR', 'YES', 0, False);
  SetConfigOption('WARN_NO_PARAMDOC', 'NO', 0, False);
  SetConfigOption('WARN_FORMAT', '$file:$line: $text', 0, False);
  
  { Input }
  SetConfigOption('INPUT', '', 0, False);
  SetConfigOption('INPUT_ENCODING', 'UTF-8', 0, False);
  SetConfigOption('FILE_PATTERNS', '*.c *.cc *.cxx *.cpp *.c++ *.java *.ii *.ixx *.ipp *.i++ *.inl *.idl *.ddl *.odl *.h *.hh *.hxx *.hpp *.h++ *.l *.cs *.d *.php *.php4 *.php5 *.phtml *.inc *.m *.markdown *.md *.mm *.dox *.py *.pyw *.f90 *.f95 *.f03 *.f08 *.f18 *.f *.for *.vhd *.vhdl *.ucf *.qsf *.ice *.pas *.pp *.p', 0, False);
  SetConfigOption('RECURSIVE', 'NO', 0, False);
  SetConfigOption('EXCLUDE', '', 0, False);
  SetConfigOption('EXCLUDE_SYMLINKS', 'NO', 0, False);
  SetConfigOption('EXCLUDE_PATTERNS', '', 0, False);
  SetConfigOption('EXAMPLE_PATH', '', 0, False);
  SetConfigOption('EXAMPLE_PATTERNS', '*', 0, False);
  SetConfigOption('EXAMPLE_RECURSIVE', 'NO', 0, False);
  SetConfigOption('IMAGE_PATH', '', 0, False);
  
  { Source browsing }
  SetConfigOption('SOURCE_BROWSER', 'NO', 0, False);
  SetConfigOption('INLINE_SOURCES', 'NO', 0, False);
  SetConfigOption('STRIP_CODE_COMMENTS', 'YES', 0, False);
  SetConfigOption('REFERENCED_BY_RELATION', 'NO', 0, False);
  SetConfigOption('REFERENCES_RELATION', 'NO', 0, False);
  SetConfigOption('VERBATIM_HEADERS', 'YES', 0, False);
  
  { Alphabetical index }
  SetConfigOption('ALPHABETICAL_INDEX', 'YES', 0, False);
  
  { HTML }
  SetConfigOption('GENERATE_HTML', 'YES', 0, False);
  SetConfigOption('HTML_OUTPUT', 'html', 0, False);
  SetConfigOption('HTML_FILE_EXTENSION', '.html', 0, False);
  SetConfigOption('HTML_HEADER', '', 0, False);
  SetConfigOption('HTML_FOOTER', '', 0, False);
  SetConfigOption('HTML_STYLESHEET', '', 0, False);
  SetConfigOption('HTML_EXTRA_STYLESHEET', '', 0, False);
  SetConfigOption('HTML_EXTRA_FILES', '', 0, False);
  SetConfigOption('HTML_COLORSTYLE_HUE', '220', 0, False);
  SetConfigOption('HTML_COLORSTYLE_SAT', '100', 0, False);
  SetConfigOption('HTML_COLORSTYLE_GAMMA', '80', 0, False);
  SetConfigOption('GENERATE_TREEVIEW', 'NO', 0, False);
  SetConfigOption('TREEVIEW_WIDTH', '250', 0, False);
  
  { LaTeX }
  SetConfigOption('GENERATE_LATEX', 'YES', 0, False);
  SetConfigOption('LATEX_OUTPUT', 'latex', 0, False);
  SetConfigOption('LATEX_CMD_NAME', 'latex', 0, False);
  SetConfigOption('COMPACT_LATEX', 'NO', 0, False);
  SetConfigOption('PAPER_TYPE', 'a4', 0, False);
  SetConfigOption('PDF_HYPERLINKS', 'YES', 0, False);
  SetConfigOption('USE_PDFLATEX', 'YES', 0, False);
  SetConfigOption('LATEX_BATCHMODE', 'NO', 0, False);
  
  { RTF }
  SetConfigOption('GENERATE_RTF', 'NO', 0, False);
  SetConfigOption('RTF_OUTPUT', 'rtf', 0, False);
  SetConfigOption('COMPACT_RTF', 'NO', 0, False);
  
  { MAN }
  SetConfigOption('GENERATE_MAN', 'NO', 0, False);
  SetConfigOption('MAN_OUTPUT', 'man', 0, False);
  SetConfigOption('MAN_EXTENSION', '.3', 0, False);
  
  { XML }
  SetConfigOption('GENERATE_XML', 'NO', 0, False);
  SetConfigOption('XML_OUTPUT', 'xml', 0, False);
  SetConfigOption('XML_PROGRAMLISTING', 'YES', 0, False);
  
  { DOT }
  SetConfigOption('HAVE_DOT', 'NO', 0, False);
  SetConfigOption('DOT_NUM_THREADS', '0', 0, False);
  SetConfigOption('DOT_FONTNAME', 'Helvetica', 0, False);
  SetConfigOption('DOT_FONTSIZE', '10', 0, False);
  SetConfigOption('CLASS_GRAPH', 'YES', 0, False);
  SetConfigOption('COLLABORATION_GRAPH', 'YES', 0, False);
  SetConfigOption('GROUP_GRAPHS', 'YES', 0, False);
  SetConfigOption('UML_LOOK', 'NO', 0, False);
  SetConfigOption('TEMPLATE_RELATIONS', 'NO', 0, False);
  SetConfigOption('INCLUDE_GRAPH', 'YES', 0, False);
  SetConfigOption('INCLUDED_BY_GRAPH', 'YES', 0, False);
  SetConfigOption('CALL_GRAPH', 'NO', 0, False);
  SetConfigOption('CALLER_GRAPH', 'NO', 0, False);
  SetConfigOption('GRAPHICAL_HIERARCHY', 'YES', 0, False);
  SetConfigOption('DIRECTORY_GRAPH', 'YES', 0, False);
  SetConfigOption('DOT_IMAGE_FORMAT', 'png', 0, False);
  SetConfigOption('MAX_DOT_GRAPH_DEPTH', '0', 0, False);
  SetConfigOption('DOT_TRANSPARENT', 'NO', 0, False);
  SetConfigOption('DOT_MULTI_TARGETS', 'NO', 0, False);
  SetConfigOption('GENERATE_LEGEND', 'YES', 0, False);
  SetConfigOption('DOT_CLEANUP', 'YES', 0, False);
End;

Procedure GenerateDefaultConfig(Const FileName: String);
{ Genere un fichier Doxyfile avec toutes les options par defaut }
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '# Doxyfile 1.0');
  WriteLn(F, '# Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS)');
  WriteLn(F, '#');
  WriteLn(F, '# Ce fichier decrit les parametres utilises par doxygen.');
  WriteLn(F, '# Toutes les valeurs par defaut peuvent etre modifiees.');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration du projet');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Le nom du projet.');
  WriteLn(F, 'PROJECT_NAME           = "My Project"');
  WriteLn(F, '');
  WriteLn(F, '# Numero de version ou de revision du projet.');
  WriteLn(F, 'PROJECT_NUMBER         = ');
  WriteLn(F, '');
  WriteLn(F, '# Description courte du projet (une ligne).');
  WriteLn(F, 'PROJECT_BRIEF          = ');
  WriteLn(F, '');
  WriteLn(F, '# Chemin vers le logo du projet.');
  WriteLn(F, 'PROJECT_LOGO           = ');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie pour la documentation generee.');
  WriteLn(F, 'OUTPUT_DIRECTORY       = ');
  WriteLn(F, '');
  WriteLn(F, '# Langue de la documentation generee.');
  WriteLn(F, 'OUTPUT_LANGUAGE        = English');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de l''extraction');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Extraire tous les membres, meme non documentes.');
  WriteLn(F, 'EXTRACT_ALL            = NO');
  WriteLn(F, '');
  WriteLn(F, '# Inclure les membres prives.');
  WriteLn(F, 'EXTRACT_PRIVATE        = NO');
  WriteLn(F, '');
  WriteLn(F, '# Inclure les membres statiques.');
  WriteLn(F, 'EXTRACT_STATIC         = NO');
  WriteLn(F, '');
  WriteLn(F, '# Utiliser le style Javadoc pour la description breve.');
  WriteLn(F, 'JAVADOC_AUTOBRIEF      = NO');
  WriteLn(F, '');
  WriteLn(F, '# Utiliser le style Qt pour la description breve.');
  WriteLn(F, 'QT_AUTOBRIEF           = NO');
  WriteLn(F, '');
  WriteLn(F, '# Taille des tabulations.');
  WriteLn(F, 'TAB_SIZE               = 4');
  WriteLn(F, '');
  WriteLn(F, '# Optimiser pour le langage C.');
  WriteLn(F, 'OPTIMIZE_OUTPUT_FOR_C  = NO');
  WriteLn(F, '');
  WriteLn(F, '# Optimiser pour Java.');
  WriteLn(F, 'OPTIMIZE_OUTPUT_JAVA   = NO');
  WriteLn(F, '');
  WriteLn(F, '# Optimiser pour Fortran.');
  WriteLn(F, 'OPTIMIZE_FOR_FORTRAN   = NO');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration des messages');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Mode silencieux.');
  WriteLn(F, 'QUIET                  = NO');
  WriteLn(F, '');
  WriteLn(F, '# Afficher les avertissements.');
  WriteLn(F, 'WARNINGS               = YES');
  WriteLn(F, '');
  WriteLn(F, '# Avertir si une entite n''est pas documentee.');
  WriteLn(F, 'WARN_IF_UNDOCUMENTED   = YES');
  WriteLn(F, '');
  WriteLn(F, '# Avertir en cas d''erreur de documentation.');
  WriteLn(F, 'WARN_IF_DOC_ERROR      = YES');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration des fichiers d''entree');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Fichiers ou repertoires source a analyser.');
  WriteLn(F, '# Utiliser les espaces ou les retours a la ligne pour separer les elements.');
  WriteLn(F, 'INPUT                  = ');
  WriteLn(F, '');
  WriteLn(F, '# Encodage des fichiers source.');
  WriteLn(F, 'INPUT_ENCODING         = UTF-8');
  WriteLn(F, '');
  WriteLn(F, '# Patterns des fichiers a analyser.');
  WriteLn(F, 'FILE_PATTERNS          = *.c *.cc *.cxx *.cpp *.h *.hh *.hxx *.hpp \');
  WriteLn(F, '                         *.java *.cs *.py *.pas *.pp *.php *.js \');
  WriteLn(F, '                         *.f90 *.f95 *.f *.for *.vhd *.vhdl \');
  WriteLn(F, '                         *.ada *.adb *.ads *.d *.go *.rs *.swift *.kt');
  WriteLn(F, '');
  WriteLn(F, '# Parcourir les sous-repertoires.');
  WriteLn(F, 'RECURSIVE              = NO');
  WriteLn(F, '');
  WriteLn(F, '# Fichiers ou repertoires a exclure.');
  WriteLn(F, 'EXCLUDE                = ');
  WriteLn(F, '');
  WriteLn(F, '# Patterns d''exclusion.');
  WriteLn(F, 'EXCLUDE_PATTERNS       = ');
  WriteLn(F, '');
  WriteLn(F, '# Chemin vers les exemples.');
  WriteLn(F, 'EXAMPLE_PATH           = ');
  WriteLn(F, '');
  WriteLn(F, '# Chemin vers les images.');
  WriteLn(F, 'IMAGE_PATH             = ');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration du navigateur de source');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Inclure le code source dans la documentation.');
  WriteLn(F, 'SOURCE_BROWSER         = NO');
  WriteLn(F, '');
  WriteLn(F, '# Inclure le code inline.');
  WriteLn(F, 'INLINE_SOURCES         = NO');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de la sortie HTML');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Generer la documentation HTML.');
  WriteLn(F, 'GENERATE_HTML          = YES');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie HTML.');
  WriteLn(F, 'HTML_OUTPUT            = html');
  WriteLn(F, '');
  WriteLn(F, '# Extension des fichiers HTML.');
  WriteLn(F, 'HTML_FILE_EXTENSION    = .html');
  WriteLn(F, '');
  WriteLn(F, '# Header HTML personnalise.');
  WriteLn(F, 'HTML_HEADER            = ');
  WriteLn(F, '');
  WriteLn(F, '# Footer HTML personnalise.');
  WriteLn(F, 'HTML_FOOTER            = ');
  WriteLn(F, '');
  WriteLn(F, '# Feuille de style CSS personnalisee.');
  WriteLn(F, 'HTML_STYLESHEET        = ');
  WriteLn(F, '');
  WriteLn(F, '# Generer un treeview pour la navigation.');
  WriteLn(F, 'GENERATE_TREEVIEW      = NO');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de la sortie LaTeX');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Generer la documentation LaTeX.');
  WriteLn(F, 'GENERATE_LATEX         = YES');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie LaTeX.');
  WriteLn(F, 'LATEX_OUTPUT           = latex');
  WriteLn(F, '');
  WriteLn(F, '# Utiliser pdflatex.');
  WriteLn(F, 'USE_PDFLATEX           = YES');
  WriteLn(F, '');
  WriteLn(F, '# Type de papier (a4, letter, legal, executive).');
  WriteLn(F, 'PAPER_TYPE             = a4');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de la sortie RTF');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Generer la documentation RTF.');
  WriteLn(F, 'GENERATE_RTF           = NO');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie RTF.');
  WriteLn(F, 'RTF_OUTPUT             = rtf');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de la sortie MAN');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Generer les pages MAN.');
  WriteLn(F, 'GENERATE_MAN           = NO');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie MAN.');
  WriteLn(F, 'MAN_OUTPUT             = man');
  WriteLn(F, '');
  WriteLn(F, '# Extension des fichiers MAN.');
  WriteLn(F, 'MAN_EXTENSION          = .3');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de la sortie XML');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Generer la documentation XML.');
  WriteLn(F, 'GENERATE_XML           = NO');
  WriteLn(F, '');
  WriteLn(F, '# Repertoire de sortie XML.');
  WriteLn(F, 'XML_OUTPUT             = xml');
  WriteLn(F, '');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '# Configuration de DOT (Graphviz)');
  WriteLn(F, '#---------------------------------------------------------------------------');
  WriteLn(F, '');
  WriteLn(F, '# Utiliser DOT pour generer des graphes.');
  WriteLn(F, 'HAVE_DOT               = NO');
  WriteLn(F, '');
  WriteLn(F, '# Generer les graphes de classes.');
  WriteLn(F, 'CLASS_GRAPH            = YES');
  WriteLn(F, '');
  WriteLn(F, '# Generer les graphes de collaboration.');
  WriteLn(F, 'COLLABORATION_GRAPH    = YES');
  WriteLn(F, '');
  WriteLn(F, '# Generer les graphes d''inclusion.');
  WriteLn(F, 'INCLUDE_GRAPH          = YES');
  WriteLn(F, '');
  WriteLn(F, '# Generer les graphes d''appel.');
  WriteLn(F, 'CALL_GRAPH             = NO');
  WriteLn(F, '');
  WriteLn(F, '# Generer les graphes d''appelants.');
  WriteLn(F, 'CALLER_GRAPH           = NO');
  WriteLn(F, '');
  WriteLn(F, '# Format des images DOT (png, svg, etc.).');
  WriteLn(F, 'DOT_IMAGE_FORMAT       = png');
  WriteLn(F, '');

  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Fichier de configuration genere: ', FileName);
End;

{ ============================================================
  TODO 06 - TOUTES LES OPTIONS DE LIGNE DE COMMANDE
  ============================================================ }

{ GenerateLayoutXml : generer un fichier DoxygenLayout.xml par defaut }
Procedure GenerateLayoutXml(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  { En-tete XML }
  WriteLn(F, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(F, '<!-- DoxygenLayout.xml - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS) -->');
  WriteLn(F, '<!-- Ce fichier definit la structure de la documentation generee -->');
  WriteLn(F, '');
  WriteLn(F, '<doxygenlayout version="1.0">');
  WriteLn(F, '  <!-- Navigation principale -->');
  WriteLn(F, '  <navindex>');
  WriteLn(F, '    <tab type="mainpage" visible="yes" title=""/>');
  WriteLn(F, '    <tab type="pages" visible="yes" title="" intro=""/>');
  WriteLn(F, '    <tab type="modules" visible="yes" title="" intro=""/>');
  WriteLn(F, '    <tab type="namespaces" visible="yes" title="">');
  WriteLn(F, '      <tab type="namespacelist" visible="yes" title="" intro=""/>');
  WriteLn(F, '      <tab type="namespacemembers" visible="yes" title="" intro=""/>');
  WriteLn(F, '    </tab>');
  WriteLn(F, '    <tab type="classes" visible="yes" title="">');
  WriteLn(F, '      <tab type="classlist" visible="yes" title="" intro=""/>');
  WriteLn(F, '      <tab type="classindex" visible="yes" title=""/>');
  WriteLn(F, '      <tab type="hierarchy" visible="yes" title="" intro=""/>');
  WriteLn(F, '      <tab type="classmembers" visible="yes" title="" intro=""/>');
  WriteLn(F, '    </tab>');
  WriteLn(F, '    <tab type="files" visible="yes" title="">');
  WriteLn(F, '      <tab type="filelist" visible="yes" title="" intro=""/>');
  WriteLn(F, '      <tab type="globals" visible="yes" title="" intro=""/>');
  WriteLn(F, '    </tab>');
  WriteLn(F, '    <tab type="examples" visible="yes" title="" intro=""/>');
  WriteLn(F, '  </navindex>');
  WriteLn(F, '');
  WriteLn(F, '  <!-- Structure de la page de classe -->');
  WriteLn(F, '  <class>');
  WriteLn(F, '    <briefdescription visible="yes"/>');
  WriteLn(F, '    <includes visible="$SHOW_INCLUDE_FILES"/>');
  WriteLn(F, '    <inheritancegraph visible="$CLASS_GRAPH"/>');
  WriteLn(F, '    <collaborationgraph visible="$COLLABORATION_GRAPH"/>');
  WriteLn(F, '    <memberdecl>');
  WriteLn(F, '      <nestedclasses visible="yes" title=""/>');
  WriteLn(F, '      <publictypes title=""/>');
  WriteLn(F, '      <publicslots title=""/>');
  WriteLn(F, '      <signals title=""/>');
  WriteLn(F, '      <publicmethods title=""/>');
  WriteLn(F, '      <publicstaticmethods title=""/>');
  WriteLn(F, '      <publicattributes title=""/>');
  WriteLn(F, '      <publicstaticattributes title=""/>');
  WriteLn(F, '      <protectedtypes title=""/>');
  WriteLn(F, '      <protectedslots title=""/>');
  WriteLn(F, '      <protectedmethods title=""/>');
  WriteLn(F, '      <protectedstaticmethods title=""/>');
  WriteLn(F, '      <protectedattributes title=""/>');
  WriteLn(F, '      <protectedstaticattributes title=""/>');
  WriteLn(F, '      <privatetypes title=""/>');
  WriteLn(F, '      <privateslots title=""/>');
  WriteLn(F, '      <privatemethods title=""/>');
  WriteLn(F, '      <privatestaticmethods title=""/>');
  WriteLn(F, '      <privateattributes title=""/>');
  WriteLn(F, '      <privatestaticattributes title=""/>');
  WriteLn(F, '      <friends title=""/>');
  WriteLn(F, '      <related title="" subtitle=""/>');
  WriteLn(F, '      <membergroups visible="yes"/>');
  WriteLn(F, '    </memberdecl>');
  WriteLn(F, '    <detaileddescription title=""/>');
  WriteLn(F, '    <memberdef>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <constructors title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <related title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '      <properties title=""/>');
  WriteLn(F, '      <events title=""/>');
  WriteLn(F, '    </memberdef>');
  WriteLn(F, '    <allmemberslink visible="yes"/>');
  WriteLn(F, '    <usedfiles visible="$SHOW_USED_FILES"/>');
  WriteLn(F, '    <authorsection visible="yes"/>');
  WriteLn(F, '  </class>');
  WriteLn(F, '');
  WriteLn(F, '  <!-- Structure de la page de namespace -->');
  WriteLn(F, '  <namespace>');
  WriteLn(F, '    <briefdescription visible="yes"/>');
  WriteLn(F, '    <memberdecl>');
  WriteLn(F, '      <nestednamespaces visible="yes" title=""/>');
  WriteLn(F, '      <classes visible="yes" title=""/>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '      <membergroups visible="yes"/>');
  WriteLn(F, '    </memberdecl>');
  WriteLn(F, '    <detaileddescription title=""/>');
  WriteLn(F, '    <memberdef>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '    </memberdef>');
  WriteLn(F, '    <authorsection visible="yes"/>');
  WriteLn(F, '  </namespace>');
  WriteLn(F, '');
  WriteLn(F, '  <!-- Structure de la page de fichier -->');
  WriteLn(F, '  <file>');
  WriteLn(F, '    <briefdescription visible="yes"/>');
  WriteLn(F, '    <includes visible="$SHOW_INCLUDE_FILES"/>');
  WriteLn(F, '    <includegraph visible="$INCLUDE_GRAPH"/>');
  WriteLn(F, '    <includedbygraph visible="$INCLUDED_BY_GRAPH"/>');
  WriteLn(F, '    <sourcelink visible="yes"/>');
  WriteLn(F, '    <memberdecl>');
  WriteLn(F, '      <classes visible="yes" title=""/>');
  WriteLn(F, '      <namespaces visible="yes" title=""/>');
  WriteLn(F, '      <defines title=""/>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '      <membergroups visible="yes"/>');
  WriteLn(F, '    </memberdecl>');
  WriteLn(F, '    <detaileddescription title=""/>');
  WriteLn(F, '    <memberdef>');
  WriteLn(F, '      <defines title=""/>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '    </memberdef>');
  WriteLn(F, '    <authorsection visible="yes"/>');
  WriteLn(F, '  </file>');
  WriteLn(F, '');
  WriteLn(F, '  <!-- Structure de la page de groupe -->');
  WriteLn(F, '  <group>');
  WriteLn(F, '    <briefdescription visible="yes"/>');
  WriteLn(F, '    <groupgraph visible="$GROUP_GRAPHS"/>');
  WriteLn(F, '    <memberdecl>');
  WriteLn(F, '      <nestedgroups visible="yes" title=""/>');
  WriteLn(F, '      <dirs visible="yes" title=""/>');
  WriteLn(F, '      <files visible="yes" title=""/>');
  WriteLn(F, '      <namespaces visible="yes" title=""/>');
  WriteLn(F, '      <classes visible="yes" title=""/>');
  WriteLn(F, '      <defines title=""/>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <enumvalues title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '      <signals title=""/>');
  WriteLn(F, '      <publicslots title=""/>');
  WriteLn(F, '      <protectedslots title=""/>');
  WriteLn(F, '      <privateslots title=""/>');
  WriteLn(F, '      <events title=""/>');
  WriteLn(F, '      <properties title=""/>');
  WriteLn(F, '      <friends title=""/>');
  WriteLn(F, '      <membergroups visible="yes"/>');
  WriteLn(F, '    </memberdecl>');
  WriteLn(F, '    <detaileddescription title=""/>');
  WriteLn(F, '    <memberdef>');
  WriteLn(F, '      <defines title=""/>');
  WriteLn(F, '      <typedefs title=""/>');
  WriteLn(F, '      <enums title=""/>');
  WriteLn(F, '      <enumvalues title=""/>');
  WriteLn(F, '      <functions title=""/>');
  WriteLn(F, '      <variables title=""/>');
  WriteLn(F, '      <signals title=""/>');
  WriteLn(F, '      <publicslots title=""/>');
  WriteLn(F, '      <protectedslots title=""/>');
  WriteLn(F, '      <privateslots title=""/>');
  WriteLn(F, '      <events title=""/>');
  WriteLn(F, '      <properties title=""/>');
  WriteLn(F, '      <friends title=""/>');
  WriteLn(F, '    </memberdef>');
  WriteLn(F, '    <authorsection visible="yes"/>');
  WriteLn(F, '  </group>');
  WriteLn(F, '');
  WriteLn(F, '  <!-- Structure de la page de repertoire -->');
  WriteLn(F, '  <directory>');
  WriteLn(F, '    <briefdescription visible="yes"/>');
  WriteLn(F, '    <directorygraph visible="yes"/>');
  WriteLn(F, '    <memberdecl>');
  WriteLn(F, '      <dirs visible="yes"/>');
  WriteLn(F, '      <files visible="yes"/>');
  WriteLn(F, '    </memberdecl>');
  WriteLn(F, '    <detaileddescription title=""/>');
  WriteLn(F, '  </directory>');
  WriteLn(F, '</doxygenlayout>');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Fichier layout genere: ', FileName);
End;

{ GenerateHtmlStylesheet : generer une feuille de style CSS par defaut }
Procedure GenerateHtmlStylesheet(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '/* Doxygen Stylesheet - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS) */');
  WriteLn(F, '');
  WriteLn(F, '/* Styles generaux */');
  WriteLn(F, 'body, table, div, p, dl {');
  WriteLn(F, '  font-family: Lucida Grande, Verdana, Geneva, Arial, sans-serif;');
  WriteLn(F, '  font-size: 13px;');
  WriteLn(F, '  line-height: 1.3;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, 'body {');
  WriteLn(F, '  background-color: white;');
  WriteLn(F, '  margin: 0;');
  WriteLn(F, '  padding: 0;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '/* Titres */');
  WriteLn(F, 'h1, h2, h3, h4, h5, h6 {');
  WriteLn(F, '  color: #253555;');
  WriteLn(F, '  font-family: inherit;');
  WriteLn(F, '  margin-top: 1em;');
  WriteLn(F, '  margin-bottom: 0.5em;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, 'h1 { font-size: 150%; }');
  WriteLn(F, 'h2 { font-size: 120%; }');
  WriteLn(F, 'h3 { font-size: 100%; }');
  WriteLn(F, '');
  WriteLn(F, '/* Liens */');
  WriteLn(F, 'a { color: #3D578C; text-decoration: none; }');
  WriteLn(F, 'a:hover { text-decoration: underline; }');
  WriteLn(F, 'a.code, a.code:visited { color: #4665A2; }');
  WriteLn(F, '');
  WriteLn(F, '/* Navigation */');
  WriteLn(F, '#titlearea {');
  WriteLn(F, '  padding: 10px;');
  WriteLn(F, '  border-bottom: 1px solid #C4CFE5;');
  WriteLn(F, '  background-color: #F9FAFC;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.tabs, .tabs2, .tabs3 {');
  WriteLn(F, '  background-color: #E8EEF2;');
  WriteLn(F, '  border-bottom: 1px solid #84B0C7;');
  WriteLn(F, '  padding: 5px 0;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.tablist {');
  WriteLn(F, '  list-style: none;');
  WriteLn(F, '  margin: 0;');
  WriteLn(F, '  padding: 0;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.tablist li { display: inline; }');
  WriteLn(F, '.tablist a { padding: 5px 10px; }');
  WriteLn(F, '');
  WriteLn(F, '/* Contenu principal */');
  WriteLn(F, '.contents {');
  WriteLn(F, '  padding: 10px 20px;');
  WriteLn(F, '  margin-top: 10px;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '/* Tables */');
  WriteLn(F, 'table.memberdecls {');
  WriteLn(F, '  border-spacing: 0px;');
  WriteLn(F, '  width: 100%;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.memItemLeft, .memItemRight, .memTemplParams {');
  WriteLn(F, '  border-bottom: 1px solid #DEE4F0;');
  WriteLn(F, '  padding: 4px;');
  WriteLn(F, '  vertical-align: top;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.memItemLeft { white-space: nowrap; }');
  WriteLn(F, '');
  WriteLn(F, '/* Blocs de code */');
  WriteLn(F, 'pre.fragment, div.fragment {');
  WriteLn(F, '  background-color: #FBFCFD;');
  WriteLn(F, '  border: 1px solid #C4CFE5;');
  WriteLn(F, '  font-family: monospace, fixed;');
  WriteLn(F, '  font-size: 105%;');
  WriteLn(F, '  padding: 8px;');
  WriteLn(F, '  margin: 4px 8px;');
  WriteLn(F, '  overflow: auto;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '/* Coloration syntaxique */');
  WriteLn(F, '.keyword { color: #008000; font-weight: bold; }');
  WriteLn(F, '.keywordtype { color: #604020; }');
  WriteLn(F, '.keywordflow { color: #E08000; }');
  WriteLn(F, '.comment { color: #800000; }');
  WriteLn(F, '.preprocessor { color: #806020; }');
  WriteLn(F, '.stringliteral { color: #002080; }');
  WriteLn(F, '.charliteral { color: #008080; }');
  WriteLn(F, '');
  WriteLn(F, '/* Documentation des membres */');
  WriteLn(F, '.memtitle {');
  WriteLn(F, '  padding: 3px 5px;');
  WriteLn(F, '  background-color: #D8DFE5;');
  WriteLn(F, '  border: 1px solid #A8B8D9;');
  WriteLn(F, '  font-weight: bold;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '.memdoc {');
  WriteLn(F, '  padding: 5px 10px;');
  WriteLn(F, '  border-left: 1px solid #A8B8D9;');
  WriteLn(F, '  border-right: 1px solid #A8B8D9;');
  WriteLn(F, '  border-bottom: 1px solid #A8B8D9;');
  WriteLn(F, '  background-color: #FBFCFD;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '/* Footer */');
  WriteLn(F, '#footer {');
  WriteLn(F, '  text-align: center;');
  WriteLn(F, '  font-size: 80%;');
  WriteLn(F, '  padding: 10px;');
  WriteLn(F, '  color: #666;');
  WriteLn(F, '  border-top: 1px solid #C4CFE5;');
  WriteLn(F, '}');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Feuille de style CSS generee: ', FileName);
End;

{ GenerateHtmlHeader : generer un fichier header HTML par defaut }
Procedure GenerateHtmlHeader(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '<!-- Header HTML - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS) -->');
  WriteLn(F, '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">');
  WriteLn(F, '<html xmlns="http://www.w3.org/1999/xhtml">');
  WriteLn(F, '<head>');
  WriteLn(F, '<meta http-equiv="Content-Type" content="text/xhtml;charset=UTF-8"/>');
  WriteLn(F, '<meta http-equiv="X-UA-Compatible" content="IE=9"/>');
  WriteLn(F, '<meta name="generator" content="Doxygen $doxygenversion"/>');
  WriteLn(F, '<meta name="viewport" content="width=device-width, initial-scale=1"/>');
  WriteLn(F, '<!--BEGIN PROJECT_NAME--><title>$projectname: $title</title><!--END PROJECT_NAME-->');
  WriteLn(F, '<!--BEGIN !PROJECT_NAME--><title>$title</title><!--END !PROJECT_NAME-->');
  WriteLn(F, '<link href="$relpath^$stylesheet" rel="stylesheet" type="text/css" />');
  WriteLn(F, '$extrastylesheet');
  WriteLn(F, '</head>');
  WriteLn(F, '<body>');
  WriteLn(F, '<div id="top">');
  WriteLn(F, '<!-- Header personnalisable -->');
  WriteLn(F, '<!--BEGIN PROJECT_NAME-->');
  WriteLn(F, '<div id="titlearea">');
  WriteLn(F, '<table cellspacing="0" cellpadding="0">');
  WriteLn(F, ' <tbody>');
  WriteLn(F, ' <tr style="height: 56px;">');
  WriteLn(F, '  <!--BEGIN PROJECT_LOGO-->');
  WriteLn(F, '  <td id="projectlogo"><img alt="Logo" src="$relpath^$projectlogo"/></td>');
  WriteLn(F, '  <!--END PROJECT_LOGO-->');
  WriteLn(F, '  <td id="projectalign" style="padding-left: 0.5em;">');
  WriteLn(F, '   <div id="projectname">$projectname');
  WriteLn(F, '   <!--BEGIN PROJECT_NUMBER-->&#160;<span id="projectnumber">$projectnumber</span><!--END PROJECT_NUMBER-->');
  WriteLn(F, '   </div>');
  WriteLn(F, '   <!--BEGIN PROJECT_BRIEF--><div id="projectbrief">$projectbrief</div><!--END PROJECT_BRIEF-->');
  WriteLn(F, '  </td>');
  WriteLn(F, ' </tr>');
  WriteLn(F, ' </tbody>');
  WriteLn(F, '</table>');
  WriteLn(F, '</div>');
  WriteLn(F, '<!--END PROJECT_NAME-->');
  WriteLn(F, '');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Header HTML genere: ', FileName);
End;

{ GenerateHtmlFooter : generer un fichier footer HTML par defaut }
Procedure GenerateHtmlFooter(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '<!-- Footer HTML - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS) -->');
  WriteLn(F, '</div><!-- top -->');
  WriteLn(F, '');
  WriteLn(F, '<!-- Begin footer -->');
  WriteLn(F, '<div id="footer">');
  WriteLn(F, '<hr class="footer"/>');
  WriteLn(F, '<address class="footer">');
  WriteLn(F, '<small>');
  WriteLn(F, 'Genere par &#160;<a href="http://www.doxygen.org/index.html">');
  WriteLn(F, '<img class="footer" src="$relpath^doxygen.png" alt="doxygen"/></a> $doxygenversion');
  WriteLn(F, '</small>');
  WriteLn(F, '</address>');
  WriteLn(F, '</div>');
  WriteLn(F, '');
  WriteLn(F, '</body>');
  WriteLn(F, '</html>');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Footer HTML genere: ', FileName);
End;

{ GenerateLatexHeader : generer un fichier header LaTeX par defaut }
Procedure GenerateLatexHeader(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '% Header LaTeX - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS)');
  WriteLn(F, '%');
  WriteLn(F, '% Ce fichier est inclus au debut du document LaTeX genere.');
  WriteLn(F, '% Vous pouvez y ajouter des packages supplementaires ou des commandes.');
  WriteLn(F, '%');
  WriteLn(F, '\documentclass[a4paper]{article}');
  WriteLn(F, '');
  WriteLn(F, '% Packages de base');
  WriteLn(F, '\usepackage[utf8]{inputenc}');
  WriteLn(F, '\usepackage[T1]{fontenc}');
  WriteLn(F, '\usepackage{lmodern}');
  WriteLn(F, '\usepackage{graphicx}');
  WriteLn(F, '\usepackage{hyperref}');
  WriteLn(F, '\usepackage{color}');
  WriteLn(F, '\usepackage{fancyhdr}');
  WriteLn(F, '\usepackage{longtable}');
  WriteLn(F, '\usepackage{array}');
  WriteLn(F, '\usepackage{multicol}');
  WriteLn(F, '\usepackage{makeidx}');
  WriteLn(F, '');
  WriteLn(F, '% Configuration de la page');
  WriteLn(F, '\usepackage[top=2.5cm, bottom=2.5cm, left=2.5cm, right=2.5cm]{geometry}');
  WriteLn(F, '');
  WriteLn(F, '% Configuration de la coloration syntaxique');
  WriteLn(F, '\usepackage{listings}');
  WriteLn(F, '\lstset{');
  WriteLn(F, '  basicstyle=\ttfamily\small,');
  WriteLn(F, '  keywordstyle=\color{blue}\bfseries,');
  WriteLn(F, '  commentstyle=\color{green!60!black},');
  WriteLn(F, '  stringstyle=\color{red},');
  WriteLn(F, '  numbers=left,');
  WriteLn(F, '  numberstyle=\tiny\color{gray},');
  WriteLn(F, '  stepnumber=1,');
  WriteLn(F, '  numbersep=5pt,');
  WriteLn(F, '  showspaces=false,');
  WriteLn(F, '  showstringspaces=false,');
  WriteLn(F, '  frame=single,');
  WriteLn(F, '  breaklines=true');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '% Index');
  WriteLn(F, '\makeindex');
  WriteLn(F, '');
  WriteLn(F, '% Configuration de l''en-tete et du pied de page');
  WriteLn(F, '\pagestyle{fancy}');
  WriteLn(F, '\fancyhf{}');
  WriteLn(F, '\renewcommand{\headrulewidth}{0.4pt}');
  WriteLn(F, '\renewcommand{\footrulewidth}{0.4pt}');
  WriteLn(F, '\fancyhead[L]{$projectname}');
  WriteLn(F, '\fancyhead[R]{\thepage}');
  WriteLn(F, '\fancyfoot[C]{Genere par Doxygen}');
  WriteLn(F, '');
  WriteLn(F, '% Debut du document');
  WriteLn(F, '\begin{document}');
  WriteLn(F, '');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Header LaTeX genere: ', FileName);
End;

{ GenerateRtfStylesheet : generer un fichier de style RTF par defaut }
Procedure GenerateRtfStylesheet(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FileName);
    Exit;
  End;

  WriteLn(F, '# RTF Stylesheet - Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS)');
  WriteLn(F, '#');
  WriteLn(F, '# Ce fichier definit les styles pour la sortie RTF.');
  WriteLn(F, '# Format: StyleName,FontName,FontSize,ColorIndex,Bold,Italic,Underline');
  WriteLn(F, '#');
  WriteLn(F, '# Styles de base');
  WriteLn(F, 'Title,Arial,24,0,1,0,0');
  WriteLn(F, 'Heading1,Arial,18,0,1,0,0');
  WriteLn(F, 'Heading2,Arial,14,0,1,0,0');
  WriteLn(F, 'Heading3,Arial,12,0,1,0,0');
  WriteLn(F, 'Heading4,Arial,11,0,1,0,0');
  WriteLn(F, 'Normal,Times New Roman,10,0,0,0,0');
  WriteLn(F, 'Code,Courier New,9,0,0,0,0');
  WriteLn(F, 'CodeBold,Courier New,9,0,1,0,0');
  WriteLn(F, 'Emphasis,Times New Roman,10,0,0,1,0');
  WriteLn(F, 'Strong,Times New Roman,10,0,1,0,0');
  WriteLn(F, 'ListBullet,Times New Roman,10,0,0,0,0');
  WriteLn(F, 'ListNumber,Times New Roman,10,0,0,0,0');
  WriteLn(F, '');
  WriteLn(F, '# Styles pour la documentation');
  WriteLn(F, 'DescBrief,Times New Roman,10,0,0,1,0');
  WriteLn(F, 'DescDetailed,Times New Roman,10,0,0,0,0');
  WriteLn(F, 'ParamName,Courier New,9,1,1,0,0');
  WriteLn(F, 'ParamType,Courier New,9,2,0,0,0');
  WriteLn(F, 'ReturnValue,Courier New,9,3,0,0,0');
  WriteLn(F, '');
  WriteLn(F, '# Table des couleurs (index -> R,G,B)');
  WriteLn(F, '# 0 = noir, 1 = bleu, 2 = vert, 3 = rouge');
  WriteLn(F, '');
  
  Close(F);
  
  If Not Opts.Quiet Then
    WriteLn('Feuille de style RTF generee: ', FileName);
End;

{ UpdateConfigFile : mettre a jour un fichier de configuration existant }
Procedure UpdateConfigFile(Const FileName: String);
Var
  F, FOut: Text;
  Line, TmpName: String;
  LineNum: Integer;
Begin
  If Not FileExists(FileName) Then
  Begin
    { Si le fichier n'existe pas, en creer un nouveau }
    WriteLn('Fichier non trouve, creation d''un nouveau Doxyfile...');
    GenerateDefaultConfig(FileName);
    Exit;
  End;

  { Lire le fichier existant }
  ReadConfigFile(FileName);

  { Creer un fichier temporaire }
  TmpName := FileName + '.tmp';
  Assign(FOut, TmpName);
  {$I-}
  Rewrite(FOut);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier temporaire: ' + TmpName);
    Exit;
  End;

  { Copier le contenu avec mise a jour }
  Assign(F, FileName);
  Reset(F);
  LineNum := 0;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    WriteLn(FOut, Line);
  End;
  
  Close(F);
  
  { Ajouter une note de mise a jour }
  WriteLn(FOut, '');
  WriteLn(FOut, '# Mis a jour par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS)');
  
  Close(FOut);

  { Remplacer l'ancien fichier par le nouveau }
  Assign(F, FileName);
  Erase(F);
  Assign(FOut, TmpName);
  Rename(FOut, FileName);
  
  If Not Opts.Quiet Then
    WriteLn('Fichier de configuration mis a jour: ', FileName);
End;

{ ExpandConfig : afficher la configuration complete avec les valeurs resolues }
Procedure ExpandConfig;
Var
  I: Integer;
Begin
  WriteLn('# Configuration expandee');
  WriteLn('# Genere par DOXYGEN ', DOXYGEN_VERSION, ' (DEV-COOLS)');
  WriteLn('#');
  WriteLn('# Nombre d''options: ', ConfigCount);
  WriteLn('#');
  WriteLn;
  
  For I := 1 To ConfigCount Do
  Begin
    If Config[I].IsSet Then
      Write(Config[I].Name, ' = ')
    Else
      Write('# ', Config[I].Name, ' = ');
    WriteLn(Config[I].Value);
  End;
End;

{ IsValidDebugOption : verifier si une option de debogage est valide }
Function IsValidDebugOption(Const Opt: String): Boolean;
Var
  UpperOpt: String;
Begin
  UpperOpt := UpStr(Opt);
  IsValidDebugOption := (UpperOpt = 'TIME') Or
                        (UpperOpt = 'EXTCMD') Or
                        (UpperOpt = 'MARKDOWN') Or
                        (UpperOpt = 'FILTEROUTPUT') Or
                        (UpperOpt = 'VALIDATE') Or
                        (UpperOpt = 'PLANTUML') Or
                        (UpperOpt = 'RTF') Or
                        (UpperOpt = 'QHP') Or
                        (UpperOpt = 'TAG') Or
                        (UpperOpt = 'LEX') Or
                        (UpperOpt = 'FORTRAN') Or
                        (UpperOpt = 'LAYOUT') Or
                        (UpperOpt = 'CITE') Or
                        (UpperOpt = 'SRCLEX') Or
                        (UpperOpt = 'COMMENTCNV') Or
                        (UpperOpt = 'PREPROCESSOR');
End;

{ ProcessOption_g : traiter l'option -g (generer Doxyfile) }
Procedure ProcessOption_g(Const FileName: String);
Begin
  If FileName = '' Then
    GenerateDefaultConfig('Doxyfile')
  Else
    GenerateDefaultConfig(FileName);
End;

{ ProcessOption_s : traiter l'option -s (mode silencieux) }
Procedure ProcessOption_s;
Begin
  Opts.Quiet := True;
End;

{ ProcessOption_u : traiter l'option -u (mise a jour du Doxyfile) }
Procedure ProcessOption_u(Const FileName: String);
Begin
  If FileName = '' Then
    UpdateConfigFile('Doxyfile')
  Else
    UpdateConfigFile(FileName);
End;

{ ProcessOption_w : traiter l'option -w (generer fichier de style) }
Procedure ProcessOption_w(Const Format, StyleType, FileName: String);
Var
  UpperFormat, UpperType: String;
  ActualFileName: String;
Begin
  UpperFormat := UpStr(Format);
  UpperType := UpStr(StyleType);
  
  If FileName = '' Then
  Begin
    { Determiner le nom par defaut }
    If UpperFormat = 'HTML' Then
    Begin
      If UpperType = 'HEADER' Then
        ActualFileName := 'header.html'
      Else If UpperType = 'FOOTER' Then
        ActualFileName := 'footer.html'
      Else
        ActualFileName := 'doxygen.css';
    End
    Else If UpperFormat = 'LATEX' Then
      ActualFileName := 'header.tex'
    Else If UpperFormat = 'RTF' Then
      ActualFileName := 'rtfstyle.txt'
    Else
    Begin
      WarnMsg('Format non supporte: ' + Format);
      Exit;
    End;
  End
  Else
    ActualFileName := FileName;
  
  If UpperFormat = 'HTML' Then
  Begin
    If UpperType = 'HEADER' Then
      GenerateHtmlHeader(ActualFileName)
    Else If UpperType = 'FOOTER' Then
      GenerateHtmlFooter(ActualFileName)
    Else
      GenerateHtmlStylesheet(ActualFileName);
  End
  Else If UpperFormat = 'LATEX' Then
    GenerateLatexHeader(ActualFileName)
  Else If UpperFormat = 'RTF' Then
    GenerateRtfStylesheet(ActualFileName)
  Else
    WarnMsg('Format non supporte: ' + Format);
End;

{ ProcessOption_l : traiter l'option -l (generer layout.xml) }
Procedure ProcessOption_l(Const FileName: String);
Begin
  If FileName = '' Then
    GenerateLayoutXml('DoxygenLayout.xml')
  Else
    GenerateLayoutXml(FileName);
End;

{ ProcessOption_d : traiter l'option -d (options de debogage) }
Procedure ProcessOption_d(Const DebugOpt: String);
Begin
  If Not IsValidDebugOption(DebugOpt) Then
  Begin
    WarnMsg('Option de debogage non reconnue: ' + DebugOpt);
    WriteLn('Options valides: time, extcmd, markdown, filteroutput, validate,');
    WriteLn('                 plantuml, rtf, qhp, tag, lex, fortran, layout,');
    WriteLn('                 cite, srclex, commentcnv, preprocessor');
    Exit;
  End;
  
  Opts.DebugMode := True;
  If Opts.DebugOpts = '' Then
    Opts.DebugOpts := DebugOpt
  Else
    Opts.DebugOpts := Opts.DebugOpts + ',' + DebugOpt;
  
  If Not Opts.Quiet Then
    WriteLn('Mode debogage active: ', DebugOpt);
End;

{ ProcessOption_x : traiter l'option -x (afficher config expandee) }
Procedure ProcessOption_x;
Begin
  Opts.ExpandOnly := True;
End;

{ ProcessOption_e : traiter l'option -e (generer header pour format) }
Procedure ProcessOption_e(Const Format, FileName: String);
Var
  UpperFormat: String;
  ActualFileName: String;
Begin
  UpperFormat := UpStr(Format);
  
  If FileName = '' Then
  Begin
    If UpperFormat = 'HTML' Then
      ActualFileName := 'header.html'
    Else If UpperFormat = 'LATEX' Then
      ActualFileName := 'header.tex'
    Else
    Begin
      WarnMsg('Format non supporte pour -e: ' + Format);
      Exit;
    End;
  End
  Else
    ActualFileName := FileName;
  
  If UpperFormat = 'HTML' Then
    GenerateHtmlHeader(ActualFileName)
  Else If UpperFormat = 'LATEX' Then
    GenerateLatexHeader(ActualFileName)
  Else
    WarnMsg('Format non supporte pour -e: ' + Format);
End;

{ ProcessOption_b : traiter l'option -b (mode batch) }
Procedure ProcessOption_b;
Begin
  Opts.BatchMode := True;
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
  Brief, Details: String;
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

    { Parser les balises Doxygen (TODO 04) }
    ParseAllDocComments;

    If DocTagCount > 0 Then
    Begin
      WriteLn('Balises Doxygen extraites: ', DocTagCount);
      WriteLn;
      For I := 1 To DocTagCount Do
      Begin
        Write('  [', I, '] ', TagKindToStr(DocTags[I].Kind));
        If DocTags[I].ParamName <> '' Then
          Write(' ', DocTags[I].ParamName);
        Write(': ');
        If Length(DocTags[I].Content) > 50 Then
          WriteLn(Copy(DocTags[I].Content, 1, 47), '...')
        Else
          WriteLn(DocTags[I].Content);
      End;
      WriteLn;

      { Afficher le resume }
      Brief := GetBriefDescription;
      Details := GetDetailedDescription;
      If Brief <> '' Then
      Begin
        WriteLn('Description breve: ', Brief);
      End;
      If Details <> '' Then
      Begin
        WriteLn('Description detaillee: ');
        If Length(Details) > 70 Then
          WriteLn('  ', Copy(Details, 1, 67), '...')
        Else
          WriteLn('  ', Details);
      End;
      WriteLn;
    End;
  End
  Else
    WriteLn('Aucun commentaire de documentation trouve.');

  WriteLn;
  WriteLn('Note: La generation de documentation HTML est en cours d''implementation.');
  WriteLn('      Voir les TODOs 05 a 25 pour la feuille de route complete.');
End;

{ ============================================================
  TODO 12 - GENERATION DE LA DOCUMENTATION HTML
  ============================================================ }

Function EscapeHtml(Const S: String): String;
{ Echappe les caracteres speciaux HTML }
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '<': R := R + '&lt;';
      '>': R := R + '&gt;';
      '&': R := R + '&amp;';
      '"': R := R + '&quot;';
      '''': R := R + '&#39;';
    Else
      R := R + C;
    End;
  End;
  EscapeHtml := R;
End;

Procedure InitHtmlGenerator;
{ Initialise le generateur HTML }
Begin
  HtmlOutputDir := GetConfigValue('OUTPUT_DIRECTORY');
  If HtmlOutputDir = '' Then
    HtmlOutputDir := 'html';
  If HtmlOutputDir[Length(HtmlOutputDir)] <> '/' Then
    HtmlOutputDir := HtmlOutputDir + '/';
  HtmlOutputDir := HtmlOutputDir + 'html/';
  
  HtmlProjectName := GetConfigValue('PROJECT_NAME');
  If HtmlProjectName = '' Then
    HtmlProjectName := 'Documentation';
  
  HtmlProjectBrief := GetConfigValue('PROJECT_BRIEF');
  
  HtmlTimestamp := GetConfigValue('HTML_TIMESTAMP');
  If HtmlTimestamp = '' Then
    HtmlTimestamp := 'YES';
  
  { CSS par defaut }
  HtmlStylesheet := 'body{font-family:Arial,sans-serif;margin:0;padding:0}';
  HtmlStylesheet := HtmlStylesheet + '.header{background:#3f51b5;color:white;padding:20px}';
  HtmlStylesheet := HtmlStylesheet + '.header h1{margin:0}.nav{background:#f5f5f5;padding:10px}';
  HtmlStylesheet := HtmlStylesheet + '.nav a{margin-right:15px;color:#3f51b5}';
  HtmlStylesheet := HtmlStylesheet + '.content{padding:20px;max-width:1200px;margin:0 auto}';
  HtmlStylesheet := HtmlStylesheet + '.entity{margin-bottom:30px;padding:15px;background:#fafafa}';
  HtmlStylesheet := HtmlStylesheet + '.signature{background:#263238;color:#aed581;padding:10px}';
  HtmlStylesheet := HtmlStylesheet + '.footer{background:#f5f5f5;padding:15px;text-align:center}';
  HtmlStylesheet := HtmlStylesheet + 'table{border-collapse:collapse;width:100%}';
  HtmlStylesheet := HtmlStylesheet + 'th,td{border:1px solid #ddd;padding:10px}';
  
  { Header HTML par defaut }
  HtmlHeader := '<!DOCTYPE html><html><head>';
  HtmlHeader := HtmlHeader + '<meta charset="UTF-8">';
  HtmlHeader := HtmlHeader + '<title>%TITLE% - %PROJECT%</title>';
  HtmlHeader := HtmlHeader + '<link rel="stylesheet" href="doxygen.css">';
  HtmlHeader := HtmlHeader + '</head><body>';
  HtmlHeader := HtmlHeader + '<div class="header"><h1>%PROJECT%</h1>';
  HtmlHeader := HtmlHeader + '<p>%BRIEF%</p></div>';
  HtmlHeader := HtmlHeader + '<div class="nav">';
  HtmlHeader := HtmlHeader + '<a href="index.html">Index</a>';
  HtmlHeader := HtmlHeader + '<a href="classes.html">Classes</a>';
  HtmlHeader := HtmlHeader + '<a href="files.html">Fichiers</a>';
  HtmlHeader := HtmlHeader + '</div><div class="content">';
  
  { Footer HTML par defaut }
  HtmlFooter := '</div><div class="footer">';
  HtmlFooter := HtmlFooter + '<p>Documentation generee par DOXYGEN Clone</p>';
  HtmlFooter := HtmlFooter + '</div></body></html>';
  
  HtmlInitialized := True;
  InfoMsg('Generateur HTML initialise');
  InfoMsg('Repertoire de sortie: ' + HtmlOutputDir);
End;

Function GetHtmlHeader(Const Title: String): String;
{ Retourne le header HTML avec titre personnalise }
Var
  H: String;
  P: Integer;
Begin
  H := HtmlHeader;
  { Remplacer %TITLE% }
  P := Pos('%TITLE%', H);
  While P > 0 Do
  Begin
    H := Copy(H, 1, P - 1) + EscapeHtml(Title) + Copy(H, P + 7, Length(H));
    P := Pos('%TITLE%', H);
  End;
  { Remplacer %PROJECT% }
  P := Pos('%PROJECT%', H);
  While P > 0 Do
  Begin
    H := Copy(H, 1, P - 1) + EscapeHtml(HtmlProjectName) + Copy(H, P + 9, Length(H));
    P := Pos('%PROJECT%', H);
  End;
  { Remplacer %BRIEF% }
  P := Pos('%BRIEF%', H);
  While P > 0 Do
  Begin
    H := Copy(H, 1, P - 1) + EscapeHtml(HtmlProjectBrief) + Copy(H, P + 7, Length(H));
    P := Pos('%BRIEF%', H);
  End;
  GetHtmlHeader := H;
End;

Procedure WriteHtmlHeader(Var F: Text; Const Title: String);
{ Ecrit le header HTML dans un fichier }
Begin
  Write(F, GetHtmlHeader(Title));
End;

Procedure WriteHtmlFooter(Var F: Text);
{ Ecrit le footer HTML dans un fichier }
Begin
  Write(F, HtmlFooter);
End;

Procedure GenerateHtmlFile(Const Entity: TEntity; Var OutFile: Text);
{ Genere la page HTML pour une entite }
Begin
  WriteHtmlHeader(OutFile, Entity.Name);
  
  WriteLn(OutFile, '<div class="entity">');
  WriteLn(OutFile, '<h2>', EscapeHtml(EntityKindToStr(Entity.Kind)), ': ',
    EscapeHtml(Entity.Name), '</h2>');
  
  { Signature }
  If Entity.Signature <> '' Then
  Begin
    WriteLn(OutFile, '<div class="signature">');
    WriteLn(OutFile, EscapeHtml(Entity.Signature));
    WriteLn(OutFile, '</div>');
  End;
  
  { Brief description }
  If Entity.BriefDesc <> '' Then
    WriteLn(OutFile, '<p><strong>', EscapeHtml(Entity.BriefDesc), '</strong></p>');
  
  { Detailed description }
  If Entity.DetailedDesc <> '' Then
    WriteLn(OutFile, '<p>', EscapeHtml(Entity.DetailedDesc), '</p>');
  
  { Return type }
  If Entity.ReturnType <> '' Then
    WriteLn(OutFile, '<p>Type de retour: <code>', EscapeHtml(Entity.ReturnType), '</code></p>');
  
  { Parameters }
  If Entity.Parameters <> '' Then
    WriteLn(OutFile, '<p>Parametres: <code>', EscapeHtml(Entity.Parameters), '</code></p>');
  
  { File location }
  WriteLn(OutFile, '<p class="location">');
  WriteLn(OutFile, 'Defini dans <code>', EscapeHtml(Entity.FileName), '</code>');
  If Entity.Line > 0 Then
    Write(OutFile, ' a la ligne ', Entity.Line);
  WriteLn(OutFile, '</p>');
  
  WriteLn(OutFile, '</div>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure GenerateHtmlIndex(Var OutFile: Text);
{ Genere la page d'index principale (index.html) }
Var
  I, ClassCount, FuncCount, FileCount: Integer;
Begin
  WriteHtmlHeader(OutFile, 'Index');
  
  WriteLn(OutFile, '<h1>Documentation</h1>');
  
  If HtmlProjectBrief <> '' Then
    WriteLn(OutFile, '<p>', EscapeHtml(HtmlProjectBrief), '</p>');
  
  { Statistiques }
  ClassCount := 0;
  FuncCount := 0;
  FileCount := 0;
  For I := 1 To EntityCount Do
  Begin
    Case Entities[I].Kind Of
      ENT_CLASS, ENT_STRUCT, ENT_INTERFACE: Inc(ClassCount);
      ENT_FUNCTION: Inc(FuncCount);
      ENT_FILE: Inc(FileCount);
    End;
  End;
  
  WriteLn(OutFile, '<h2>Resume</h2>');
  WriteLn(OutFile, '<table>');
  WriteLn(OutFile, '<tr><th>Type</th><th>Nombre</th></tr>');
  WriteLn(OutFile, '<tr><td>Classes/Structures</td><td>', ClassCount, '</td></tr>');
  WriteLn(OutFile, '<tr><td>Fonctions</td><td>', FuncCount, '</td></tr>');
  WriteLn(OutFile, '<tr><td>Fichiers</td><td>', FileCount, '</td></tr>');
  WriteLn(OutFile, '<tr><td><strong>Total</strong></td><td><strong>', 
    EntityCount, '</strong></td></tr>');
  WriteLn(OutFile, '</table>');
  
  { Liens de navigation }
  WriteLn(OutFile, '<h2>Navigation</h2>');
  WriteLn(OutFile, '<ul>');
  WriteLn(OutFile, '<li><a href="classes.html">Liste des classes</a></li>');
  WriteLn(OutFile, '<li><a href="files.html">Liste des fichiers</a></li>');
  WriteLn(OutFile, '<li><a href="namespaces.html">Liste des namespaces</a></li>');
  WriteLn(OutFile, '<li><a href="hierarchy.html">Hierarchie des classes</a></li>');
  WriteLn(OutFile, '</ul>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure GenerateHtmlClasses(Var OutFile: Text);
{ Genere la page de liste des classes (classes.html) }
Var
  I: Integer;
  HasClasses: Boolean;
Begin
  WriteHtmlHeader(OutFile, 'Classes');
  
  WriteLn(OutFile, '<h1>Liste des classes</h1>');
  
  HasClasses := False;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE] Then
    Begin
      If Not HasClasses Then
      Begin
        WriteLn(OutFile, '<ul>');
        HasClasses := True;
      End;
      WriteLn(OutFile, '<li>');
      WriteLn(OutFile, '<a href="', EscapeHtml(Entities[I].Name), '.html">',
        EscapeHtml(Entities[I].Name), '</a>');
      WriteLn(OutFile, ' [', EntityKindToStr(Entities[I].Kind), ']');
      If Entities[I].BriefDesc <> '' Then
        WriteLn(OutFile, ' - ', EscapeHtml(Entities[I].BriefDesc));
      WriteLn(OutFile, '</li>');
    End;
  End;
  
  If HasClasses Then
    WriteLn(OutFile, '</ul>')
  Else
    WriteLn(OutFile, '<p>Aucune classe documentee.</p>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure GenerateHtmlFiles(Var OutFile: Text);
{ Genere la page de liste des fichiers (files.html) }
Var
  I: Integer;
  HasFiles: Boolean;
Begin
  WriteHtmlHeader(OutFile, 'Fichiers');
  
  WriteLn(OutFile, '<h1>Liste des fichiers</h1>');
  
  HasFiles := False;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FILE Then
    Begin
      If Not HasFiles Then
      Begin
        WriteLn(OutFile, '<ul>');
        HasFiles := True;
      End;
      WriteLn(OutFile, '<li>');
      WriteLn(OutFile, '<a href="', EscapeHtml(Entities[I].Name), '.html">',
        EscapeHtml(Entities[I].Name), '</a>');
      If Entities[I].BriefDesc <> '' Then
        WriteLn(OutFile, ' - ', EscapeHtml(Entities[I].BriefDesc));
      WriteLn(OutFile, '</li>');
    End;
  End;
  
  If HasFiles Then
    WriteLn(OutFile, '</ul>')
  Else
    WriteLn(OutFile, '<p>Aucun fichier documente.</p>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure GenerateHtmlNamespaces(Var OutFile: Text);
{ Genere la page de liste des namespaces (namespaces.html) }
Var
  I: Integer;
  HasNS: Boolean;
Begin
  WriteHtmlHeader(OutFile, 'Namespaces');
  
  WriteLn(OutFile, '<h1>Liste des namespaces</h1>');
  
  HasNS := False;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_NAMESPACE, ENT_MODULE] Then
    Begin
      If Not HasNS Then
      Begin
        WriteLn(OutFile, '<ul>');
        HasNS := True;
      End;
      WriteLn(OutFile, '<li>');
      WriteLn(OutFile, '<a href="', EscapeHtml(Entities[I].Name), '.html">',
        EscapeHtml(Entities[I].Name), '</a>');
      WriteLn(OutFile, ' [', EntityKindToStr(Entities[I].Kind), ']');
      If Entities[I].BriefDesc <> '' Then
        WriteLn(OutFile, ' - ', EscapeHtml(Entities[I].BriefDesc));
      WriteLn(OutFile, '</li>');
    End;
  End;
  
  If HasNS Then
    WriteLn(OutFile, '</ul>')
  Else
    WriteLn(OutFile, '<p>Aucun namespace documente.</p>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure WriteHierarchyNode(Var OutFile: Text; ParentId: Integer; Depth: Integer);
{ Ecrit recursivement les noeuds de la hierarchie }
Var
  I: Integer;
  HasChildren: Boolean;
Begin
  If Depth > 20 Then Exit; { Protection contre recursion infinie }
  
  HasChildren := False;
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ParentId = ParentId Then
    Begin
      If Not HasChildren Then
      Begin
        WriteLn(OutFile, '<ul>');
        HasChildren := True;
      End;
      WriteLn(OutFile, '<li>');
      WriteLn(OutFile, '<a href="', EscapeHtml(Entities[Inheritances[I].ChildId].Name),
        '.html">', EscapeHtml(Entities[Inheritances[I].ChildId].Name), '</a>');
      WriteHierarchyNode(OutFile, Inheritances[I].ChildId, Depth + 1);
      WriteLn(OutFile, '</li>');
    End;
  End;
  
  If HasChildren Then
    WriteLn(OutFile, '</ul>');
End;

Procedure GenerateHtmlHierarchy(Var OutFile: Text);
{ Genere la page de hierarchie de classes (hierarchy.html) }
Var
  I, J: Integer;
  IsRoot, HasRoots: Boolean;
Begin
  WriteHtmlHeader(OutFile, 'Hierarchie');
  
  WriteLn(OutFile, '<h1>Hierarchie des classes</h1>');
  
  If InheritanceCount = 0 Then
  Begin
    WriteLn(OutFile, '<p>Aucune hierarchie de classes documentee.</p>');
    WriteHtmlFooter(OutFile);
    Exit;
  End;
  
  WriteLn(OutFile, '<div class="hierarchy">');
  
  { Trouver les classes racines (sans parent) }
  HasRoots := False;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE] Then
    Begin
      IsRoot := True;
      For J := 1 To InheritanceCount Do
      Begin
        If Inheritances[J].ChildId = I Then
        Begin
          IsRoot := False;
          Break;
        End;
      End;
      
      If IsRoot Then
      Begin
        If Not HasRoots Then
        Begin
          WriteLn(OutFile, '<ul>');
          HasRoots := True;
        End;
        WriteLn(OutFile, '<li>');
        WriteLn(OutFile, '<a href="', EscapeHtml(Entities[I].Name), '.html">',
          EscapeHtml(Entities[I].Name), '</a>');
        WriteHierarchyNode(OutFile, I, 1);
        WriteLn(OutFile, '</li>');
      End;
    End;
  End;
  
  If HasRoots Then
    WriteLn(OutFile, '</ul>');
  
  WriteLn(OutFile, '</div>');
  
  WriteHtmlFooter(OutFile);
End;

Procedure GenerateHtmlSearch;
{ Genere les fichiers de recherche JavaScript }
Var
  F: Text;
  I: Integer;
Begin
  Assign(F, HtmlOutputDir + 'search.js');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer le fichier de recherche');
    Exit;
  End;
  
  WriteLn(F, '// Donnees de recherche generees par DOXYGEN Clone');
  WriteLn(F, 'var searchData = [');
  
  For I := 1 To EntityCount Do
  Begin
    Write(F, '  { name: "', EscapeHtml(Entities[I].Name), '", ');
    Write(F, 'kind: "', EntityKindToStr(Entities[I].Kind), '", ');
    Write(F, 'file: "', EscapeHtml(Entities[I].Name), '.html" }');
    If I < EntityCount Then WriteLn(F, ',')
    Else WriteLn(F);
  End;
  
  WriteLn(F, '];');
  
  Close(F);
  InfoMsg('Fichier de recherche genere: search.js');
End;

Procedure CopyHtmlResources;
{ Copie les fichiers CSS et ressources necessaires }
Var
  F: Text;
Begin
  Assign(F, HtmlOutputDir + 'doxygen.css');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer le fichier CSS');
    Exit;
  End;
  
  WriteLn(F, '/* Feuille de style generee par DOXYGEN Clone */');
  WriteLn(F, HtmlStylesheet);
  
  Close(F);
  InfoMsg('Fichier CSS genere: doxygen.css');
End;

Procedure CreateHtmlDirectory;
{ Cree le repertoire de sortie HTML }
Begin
  {$I-}
  MkDir(HtmlOutputDir);
  {$I+}
  If IOResult <> 0 Then
    InfoMsg('Repertoire HTML existe deja ou creation impossible');
End;

Procedure GenerateHtmlDocumentation;
{ Orchestrateur : genere toute la documentation HTML }
Var
  F: Text;
  I: Integer;
Begin
  InfoMsg('Debut de la generation HTML...');
  
  If Not HtmlInitialized Then
    InitHtmlGenerator;
  
  CreateHtmlDirectory;
  CopyHtmlResources;
  
  { Generer la page d'index }
  Assign(F, HtmlOutputDir + 'index.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlIndex(F);
    Close(F);
    InfoMsg('Page index generee: index.html');
  End
  Else
    WarnMsg('Impossible de creer index.html');
  
  { Generer la page des classes }
  Assign(F, HtmlOutputDir + 'classes.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlClasses(F);
    Close(F);
    InfoMsg('Page classes generee: classes.html');
  End
  Else
    WarnMsg('Impossible de creer classes.html');
  
  { Generer la page des fichiers }
  Assign(F, HtmlOutputDir + 'files.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlFiles(F);
    Close(F);
    InfoMsg('Page fichiers generee: files.html');
  End
  Else
    WarnMsg('Impossible de creer files.html');
  
  { Generer la page des namespaces }
  Assign(F, HtmlOutputDir + 'namespaces.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlNamespaces(F);
    Close(F);
    InfoMsg('Page namespaces generee: namespaces.html');
  End
  Else
    WarnMsg('Impossible de creer namespaces.html');
  
  { Generer la page de hierarchie }
  Assign(F, HtmlOutputDir + 'hierarchy.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlHierarchy(F);
    Close(F);
    InfoMsg('Page hierarchie generee: hierarchy.html');
  End
  Else
    WarnMsg('Impossible de creer hierarchy.html');
  
  { Generer une page pour chaque entite }
  For I := 1 To EntityCount Do
  Begin
    Assign(F, HtmlOutputDir + Entities[I].Name + '.html');
    {$I-}
    Rewrite(F);
    {$I+}
    If IOResult = 0 Then
    Begin
      GenerateHtmlFile(Entities[I], F);
      Close(F);
    End;
  End;
  
  GenerateHtmlSearch;
  
  WriteLn;
  WriteLn('Generation HTML terminee.');
  WriteLn('  Repertoire: ', HtmlOutputDir);
  WriteLn('  Fichiers generes: ', EntityCount + 5);
End;

{ Fonctions accesseurs pour le generateur HTML }

Function GetHtmlOutputDir: String;
Begin
  GetHtmlOutputDir := HtmlOutputDir;
End;

Procedure SetHtmlOutputDir(Const Dir: String);
Begin
  HtmlOutputDir := Dir;
  If (Length(HtmlOutputDir) > 0) And 
     (HtmlOutputDir[Length(HtmlOutputDir)] <> '/') Then
    HtmlOutputDir := HtmlOutputDir + '/';
End;

Function GetHtmlProjectName: String;
Begin
  GetHtmlProjectName := HtmlProjectName;
End;

Procedure SetHtmlProjectName(Const Name: String);
Begin
  HtmlProjectName := Name;
End;

Function GetHtmlProjectBrief: String;
Begin
  GetHtmlProjectBrief := HtmlProjectBrief;
End;

Procedure SetHtmlProjectBrief(Const Brief: String);
Begin
  HtmlProjectBrief := Brief;
End;

Function IsHtmlInitialized: Boolean;
Begin
  IsHtmlInitialized := HtmlInitialized;
End;

Function GetHtmlStylesheet: String;
Begin
  GetHtmlStylesheet := HtmlStylesheet;
End;

Procedure SetHtmlStylesheet(Const Css: String);
Begin
  HtmlStylesheet := Css;
End;

Function GetHtmlHeaderTemplate: String;
Begin
  GetHtmlHeaderTemplate := HtmlHeader;
End;

Procedure SetHtmlHeaderTemplate(Const Header: String);
Begin
  HtmlHeader := Header;
End;

Function GetHtmlFooterTemplate: String;
Begin
  GetHtmlFooterTemplate := HtmlFooter;
End;

Procedure SetHtmlFooterTemplate(Const Footer: String);
Begin
  HtmlFooter := Footer;
End;

{ ============================================================
  TODO 13 - GENERATION DE LA DOCUMENTATION LATEX
  ============================================================ }

Function EscapeLatex(Const S: String): String;
{ Echappe les caracteres speciaux LaTeX }
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '\': R := R + '\textbackslash{}';
      '{': R := R + '\{';
      '}': R := R + '\}';
      '$': R := R + '\$';
      '&': R := R + '\&';
      '%': R := R + '\%';
      '#': R := R + '\#';
      '_': R := R + '\_';
      '^': R := R + '\textasciicircum{}';
      '~': R := R + '\textasciitilde{}';
      '<': R := R + '\textless{}';
      '>': R := R + '\textgreater{}';
      '|': R := R + '\textbar{}';
    Else
      R := R + C;
    End;
  End;
  EscapeLatex := R;
End;

Procedure InitLatexGenerator;
{ Initialise le generateur LaTeX }
Begin
  LatexOutputDir := GetConfigValue('OUTPUT_DIRECTORY');
  If LatexOutputDir = '' Then
    LatexOutputDir := 'latex';
  If LatexOutputDir[Length(LatexOutputDir)] <> '/' Then
    LatexOutputDir := LatexOutputDir + '/';
  LatexOutputDir := LatexOutputDir + 'latex/';
  
  LatexProjectName := GetConfigValue('PROJECT_NAME');
  If LatexProjectName = '' Then
    LatexProjectName := 'Documentation';
  
  LatexProjectBrief := GetConfigValue('PROJECT_BRIEF');
  
  LatexCmdName := GetConfigValue('LATEX_CMD_NAME');
  If LatexCmdName = '' Then
    LatexCmdName := LATEX_DEFAULT_CMD;
  
  LatexPaperType := GetConfigValue('PAPER_TYPE');
  If LatexPaperType = '' Then
    LatexPaperType := LATEX_DEFAULT_PAPER;
  
  LatexCompactMode := (UpStr(GetConfigValue('COMPACT_LATEX')) = 'YES');
  
  { Preambule LaTeX par defaut }
  LatexHeader := '\documentclass[' + LatexPaperType + 'paper]{article}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage[utf8]{inputenc}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage[T1]{fontenc}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage{graphicx}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage{hyperref}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage{listings}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage{color}' + Chr(10);
  LatexHeader := LatexHeader + '\usepackage{fancyhdr}' + Chr(10);
  LatexHeader := LatexHeader + '\pagestyle{fancy}' + Chr(10);
  LatexHeader := LatexHeader + '\lstset{basicstyle=\ttfamily\small,breaklines=true}' + Chr(10);
  
  { Fin du document }
  LatexFooter := '\end{document}' + Chr(10);
  
  LatexInitialized := True;
  InfoMsg('Generateur LaTeX initialise');
End;

Procedure GenerateLatexFile(Const Entity: TEntity; Var OutFile: Text);
{ Genere la section LaTeX pour une entite }
Var
  I: Integer;
Begin
  WriteLn(OutFile, '\section{', EscapeLatex(Entity.Name), '}');
  WriteLn(OutFile, '\label{', Entity.Name, '}');
  WriteLn(OutFile);
  
  { Informations sur l entite }
  WriteLn(OutFile, '\subsection{Description}');
  If Entity.BriefDesc <> '' Then
    WriteLn(OutFile, EscapeLatex(Entity.BriefDesc))
  Else
    WriteLn(OutFile, 'Aucune description.');
  WriteLn(OutFile);
  
  { Type d entite }
  WriteLn(OutFile, '\begin{itemize}');
  WriteLn(OutFile, '\item \textbf{Type:} ', EntityKindToStr(Entity.Kind));
  If Entity.FileName <> '' Then
    WriteLn(OutFile, '\item \textbf{Fichier:} \texttt{', EscapeLatex(Entity.FileName), '}');
  If Entity.Line > 0 Then
    WriteLn(OutFile, '\item \textbf{Ligne:} ', Entity.Line);
  WriteLn(OutFile, '\end{itemize}');
  WriteLn(OutFile);
  
  { Description detaillee }
  If Entity.DetailedDesc <> '' Then
  Begin
    WriteLn(OutFile, '\subsection{Details}');
    WriteLn(OutFile, EscapeLatex(Entity.DetailedDesc));
    WriteLn(OutFile);
  End;
  
  { Signature si disponible }
  If Entity.Signature <> '' Then
  Begin
    WriteLn(OutFile, '\subsection{Prototype}');
    WriteLn(OutFile, '\begin{lstlisting}');
    WriteLn(OutFile, Entity.Signature);
    WriteLn(OutFile, '\end{lstlisting}');
    WriteLn(OutFile);
  End;
  
  { Parametres }
  If Entity.Parameters <> '' Then
  Begin
    WriteLn(OutFile, '\subsection{Parametres}');
    WriteLn(OutFile, EscapeLatex(Entity.Parameters));
    WriteLn(OutFile);
  End;
  
  { Type de retour }
  If Entity.ReturnType <> '' Then
  Begin
    WriteLn(OutFile, '\subsection{Type de retour}');
    WriteLn(OutFile, '\texttt{', EscapeLatex(Entity.ReturnType), '}');
    WriteLn(OutFile);
  End;
End;

Procedure GenerateLatexMain(Var OutFile: Text);
{ Genere le fichier principal refman.tex }
Var
  I: Integer;
Begin
  { Header LaTeX }
  Write(OutFile, LatexHeader);
  
  { Page de titre }
  WriteLn(OutFile);
  WriteLn(OutFile, '\title{', EscapeLatex(LatexProjectName), '}');
  If LatexProjectBrief <> '' Then
    WriteLn(OutFile, '\author{', EscapeLatex(LatexProjectBrief), '}')
  Else
    WriteLn(OutFile, '\author{Documentation generee par DOXYGEN}');
  WriteLn(OutFile, '\date{\today}');
  WriteLn(OutFile);
  WriteLn(OutFile, '\begin{document}');
  WriteLn(OutFile);
  WriteLn(OutFile, '\maketitle');
  WriteLn(OutFile, '\tableofcontents');
  WriteLn(OutFile, '\newpage');
  WriteLn(OutFile);
  
  { Introduction }
  WriteLn(OutFile, '\chapter{Introduction}');
  WriteLn(OutFile, 'Cette documentation a ete generee automatiquement a partir');
  WriteLn(OutFile, 'des sources du projet ', EscapeLatex(LatexProjectName), '.');
  WriteLn(OutFile);
  
  { Inclure les fichiers generes }
  WriteLn(OutFile, '\input{', LATEX_CLASSES_FILE, '}');
  WriteLn(OutFile, '\input{', LATEX_FILES_FILE, '}');
  WriteLn(OutFile);
  
  { Index }
  WriteLn(OutFile, '\printindex');
  WriteLn(OutFile);
  
  { Footer }
  Write(OutFile, LatexFooter);
End;

Procedure GenerateLatexClasses(Var OutFile: Text);
{ Genere le chapitre des classes }
Var
  I: Integer;
  Count: Integer;
Begin
  WriteLn(OutFile, '\chapter{Classes et structures}');
  WriteLn(OutFile);
  
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_INTERFACE] Then
    Begin
      GenerateLatexFile(Entities[I], OutFile);
      Inc(Count);
    End;
  End;
  
  If Count = 0 Then
    WriteLn(OutFile, 'Aucune classe ou structure documentee.');
  WriteLn(OutFile);
End;

Procedure GenerateLatexFiles(Var OutFile: Text);
{ Genere le chapitre des fichiers }
Var
  I: Integer;
  Count: Integer;
Begin
  WriteLn(OutFile, '\chapter{Fichiers}');
  WriteLn(OutFile);
  
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FILE Then
    Begin
      GenerateLatexFile(Entities[I], OutFile);
      Inc(Count);
    End;
  End;
  
  If Count = 0 Then
    WriteLn(OutFile, 'Aucun fichier documente.');
  WriteLn(OutFile);
  
  { Ajouter les fonctions }
  WriteLn(OutFile, '\chapter{Fonctions}');
  WriteLn(OutFile);
  
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FUNCTION Then
    Begin
      GenerateLatexFile(Entities[I], OutFile);
      Inc(Count);
    End;
  End;
  
  If Count = 0 Then
    WriteLn(OutFile, 'Aucune fonction documentee.');
  WriteLn(OutFile);
End;

Procedure GenerateLatexMakefile;
{ Genere le Makefile pour compiler le LaTeX }
Var
  F: Text;
Begin
  Assign(F, LatexOutputDir + LATEX_MAKEFILE);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer le Makefile LaTeX');
    Exit;
  End;
  
  WriteLn(F, '# Makefile genere par DOXYGEN');
  WriteLn(F, '# Compilation de la documentation LaTeX');
  WriteLn(F);
  WriteLn(F, 'LATEX_CMD = ', LatexCmdName);
  WriteLn(F, 'MAIN_DOC = ', LATEX_MAIN_FILE);
  WriteLn(F, 'PDF_FILE = refman.pdf');
  WriteLn(F);
  WriteLn(F, 'all: pdf');
  WriteLn(F);
  WriteLn(F, 'pdf: $(MAIN_DOC)');
  WriteLn(F, #9, '$(LATEX_CMD) $(MAIN_DOC)');
  WriteLn(F, #9, '$(LATEX_CMD) $(MAIN_DOC)');
  WriteLn(F, #9, '@echo "PDF genere: $(PDF_FILE)"');
  WriteLn(F);
  WriteLn(F, 'clean:');
  WriteLn(F, #9, 'rm -f *.aux *.log *.toc *.out *.idx *.ind *.ilg');
  WriteLn(F);
  WriteLn(F, 'distclean: clean');
  WriteLn(F, #9, 'rm -f *.pdf *.dvi');
  WriteLn(F);
  WriteLn(F, '.PHONY: all pdf clean distclean');
  
  Close(F);
  InfoMsg('Makefile LaTeX genere');
End;

Procedure GenerateLatexDocumentation;
{ Orchestrateur: genere toute la documentation LaTeX }
Var
  F: Text;
Begin
  WriteLn;
  WriteLn('Generation de la documentation LaTeX...');
  WriteLn;
  
  If Not LatexInitialized Then
    InitLatexGenerator;
  
  { Creer le repertoire de sortie (simule avec mkdir) }
  InfoMsg('Repertoire de sortie: ' + LatexOutputDir);
  
  { Generer le fichier principal }
  Assign(F, LatexOutputDir + LATEX_MAIN_FILE);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateLatexMain(F);
    Close(F);
    InfoMsg('Document principal genere: ' + LATEX_MAIN_FILE);
  End
  Else
    WarnMsg('Impossible de creer ' + LATEX_MAIN_FILE);
  
  { Generer le chapitre des classes }
  Assign(F, LatexOutputDir + LATEX_CLASSES_FILE);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateLatexClasses(F);
    Close(F);
    InfoMsg('Chapitre classes genere: ' + LATEX_CLASSES_FILE);
  End
  Else
    WarnMsg('Impossible de creer ' + LATEX_CLASSES_FILE);
  
  { Generer le chapitre des fichiers }
  Assign(F, LatexOutputDir + LATEX_FILES_FILE);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateLatexFiles(F);
    Close(F);
    InfoMsg('Chapitre fichiers genere: ' + LATEX_FILES_FILE);
  End
  Else
    WarnMsg('Impossible de creer ' + LATEX_FILES_FILE);
  
  { Generer le Makefile }
  GenerateLatexMakefile;
  
  WriteLn;
  WriteLn('Generation LaTeX terminee.');
  WriteLn('  Repertoire: ', LatexOutputDir);
  WriteLn('  Pour compiler: cd ', LatexOutputDir, ' && make');
End;

{ Fonctions accesseurs pour le generateur LaTeX }

Function GetLatexOutputDir: String;
Begin
  GetLatexOutputDir := LatexOutputDir;
End;

Procedure SetLatexOutputDir(Const Dir: String);
Begin
  LatexOutputDir := Dir;
  If (Length(LatexOutputDir) > 0) And 
     (LatexOutputDir[Length(LatexOutputDir)] <> '/') Then
    LatexOutputDir := LatexOutputDir + '/';
End;

Function GetLatexProjectName: String;
Begin
  GetLatexProjectName := LatexProjectName;
End;

Procedure SetLatexProjectName(Const Name: String);
Begin
  LatexProjectName := Name;
End;

Function GetLatexProjectBrief: String;
Begin
  GetLatexProjectBrief := LatexProjectBrief;
End;

Procedure SetLatexProjectBrief(Const Brief: String);
Begin
  LatexProjectBrief := Brief;
End;

Function IsLatexInitialized: Boolean;
Begin
  IsLatexInitialized := LatexInitialized;
End;

Function GetLatexCmdName: String;
Begin
  GetLatexCmdName := LatexCmdName;
End;

Procedure SetLatexCmdName(Const Cmd: String);
Begin
  LatexCmdName := Cmd;
End;

Function GetLatexPaperType: String;
Begin
  GetLatexPaperType := LatexPaperType;
End;

Procedure SetLatexPaperType(Const Paper: String);
Begin
  LatexPaperType := Paper;
End;

Function IsLatexCompactMode: Boolean;
Begin
  IsLatexCompactMode := LatexCompactMode;
End;

Procedure SetLatexCompactMode(Compact: Boolean);
Begin
  LatexCompactMode := Compact;
End;

Function GetLatexHeader: String;
Begin
  GetLatexHeader := LatexHeader;
End;

Procedure SetLatexHeader(Const Header: String);
Begin
  LatexHeader := Header;
End;

Function GetLatexFooter: String;
Begin
  GetLatexFooter := LatexFooter;
End;

Procedure SetLatexFooter(Const Footer: String);
Begin
  LatexFooter := Footer;
End;

Function CountLatexFiles: Integer;
{ Compte le nombre de fichiers LaTeX a generer }
Var
  Count: Integer;
Begin
  Count := 3; { refman.tex, classes.tex, files.tex }
  Count := Count + 1; { Makefile }
  CountLatexFiles := Count;
End;

Function IsLatexEmpty: Boolean;
{ Verifie si le generateur LaTeX est vide }
Begin
  IsLatexEmpty := (EntityCount = 0);
End;

{ ============================================================
  TODO 14 - GENERATION DE LA DOCUMENTATION RTF
  ============================================================ }

Procedure InitRtfGenerator;
{ Initialise le generateur RTF }
Begin
  If GetConfigValue('RTF_OUTPUT') <> '' Then
    RtfOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + GetConfigValue('RTF_OUTPUT') + '/'
  Else
    RtfOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + 'rtf/';
  
  RtfStylesheet := GetConfigValue('RTF_STYLESHEET_FILE');
  RtfExtensions := GetConfigValue('RTF_EXTENSIONS');
  RtfProjectName := GetConfigValue('PROJECT_NAME');
  If RtfProjectName = '' Then
    RtfProjectName := 'Documentation';
  RtfProjectBrief := GetConfigValue('PROJECT_BRIEF');
  
  { Creer le repertoire de sortie }
  {$I-}
  MkDir(RtfOutputDir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  RtfInitialized := True;
End;

Function EscapeRtf(Const S: String): String;
{ Echappe les caracteres speciaux RTF }
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '\': R := R + '\\';
      '{': R := R + '\{';
      '}': R := R + '\}';
      #10: R := R + '\line ';
      #13: ; { Ignorer CR }
    Else
      If Ord(C) > 127 Then
        R := R + '\''' + IntToStr(Ord(C))
      Else
        R := R + C;
    End;
  End;
  EscapeRtf := R;
End;

Procedure WriteRtfHeader(Var OutFile: Text);
{ Ecrit l entete RTF avec les polices et styles }
Begin
  WriteLn(OutFile, '{\rtf1\ansi\ansicpg1252\deff0\deflang1033');
  WriteLn(OutFile, '{\fonttbl');
  WriteLn(OutFile, '{\f0\fswiss\fcharset0 ', RTF_FONT_ARIAL, ';}');
  WriteLn(OutFile, '{\f1\fmodern\fcharset0 ', RTF_FONT_COURIER, ';}');
  WriteLn(OutFile, '{\f2\froman\fcharset0 ', RTF_FONT_TIMES, ';}');
  WriteLn(OutFile, '}');
  WriteLn(OutFile, '{\colortbl;');
  WriteLn(OutFile, '\red0\green0\blue0;');       { Noir }
  WriteLn(OutFile, '\red0\green0\blue128;');     { Bleu fonce }
  WriteLn(OutFile, '\red0\green128\blue0;');     { Vert }
  WriteLn(OutFile, '\red128\green0\blue0;');     { Rouge fonce }
  WriteLn(OutFile, '\red128\green128\blue128;'); { Gris }
  WriteLn(OutFile, '}');
  WriteLn(OutFile, '{\stylesheet');
  WriteLn(OutFile, '{\s0 \fs', RTF_DEFAULT_FONTSIZE, ' Normal;}');
  WriteLn(OutFile, '{\s1 \fs', RTF_TITLE_FONTSIZE, '\b Title;}');
  WriteLn(OutFile, '{\s2 \fs', RTF_HEADING_FONTSIZE, '\b Heading 1;}');
  WriteLn(OutFile, '{\s3 \fs24\b Heading 2;}');
  WriteLn(OutFile, '{\s4 \f1\fs18 Code;}');
  WriteLn(OutFile, '}');
  WriteLn(OutFile);
End;

Procedure WriteRtfFooter(Var OutFile: Text);
{ Ecrit la fin du document RTF }
Begin
  WriteLn(OutFile);
  WriteLn(OutFile, '\par');
  WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
  WriteLn(OutFile, '\par\par');
  WriteLn(OutFile, '{\i Documentation generee par DOXYGEN (DEV-COOLS)}');
  WriteLn(OutFile, '}');
End;

Procedure GenerateRtfEntity(Const Entity: TEntity; Var OutFile: Text);
{ Genere le contenu RTF pour une entite }
Begin
  { Titre de l entite }
  WriteLn(OutFile, '\pard\s2\fs', RTF_HEADING_FONTSIZE, '\b ', 
          EscapeRtf(Entity.Name), '\b0\par');
  WriteLn(OutFile);
  
  { Description breve }
  If Entity.BriefDesc <> '' Then
  Begin
    WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(OutFile, EscapeRtf(Entity.BriefDesc));
    WriteLn(OutFile, '\par\par');
  End;
  
  { Type d entite }
  WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
  WriteLn(OutFile, '\b Type:\b0  ', EntityKindToStr(Entity.Kind), '\par');
  If Entity.FileName <> '' Then
    WriteLn(OutFile, '\b Fichier:\b0  {\f1 ', EscapeRtf(Entity.FileName), '}\par');
  If Entity.Line > 0 Then
    WriteLn(OutFile, '\b Ligne:\b0  ', Entity.Line, '\par');
  WriteLn(OutFile, '\par');
  
  { Description detaillee }
  If Entity.DetailedDesc <> '' Then
  Begin
    WriteLn(OutFile, '\pard\s3\fs24\b Details\b0\par');
    WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(OutFile, EscapeRtf(Entity.DetailedDesc));
    WriteLn(OutFile, '\par\par');
  End;
  
  { Signature }
  If Entity.Signature <> '' Then
  Begin
    WriteLn(OutFile, '\pard\s3\fs24\b Prototype\b0\par');
    WriteLn(OutFile, '\pard\s4\f1\fs18');
    WriteLn(OutFile, EscapeRtf(Entity.Signature));
    WriteLn(OutFile, '\f0\par\par');
  End;
  
  { Parametres }
  If Entity.Parameters <> '' Then
  Begin
    WriteLn(OutFile, '\pard\s3\fs24\b Parametres\b0\par');
    WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(OutFile, EscapeRtf(Entity.Parameters));
    WriteLn(OutFile, '\par\par');
  End;
  
  { Type de retour }
  If Entity.ReturnType <> '' Then
  Begin
    WriteLn(OutFile, '\pard\s3\fs24\b Type de retour\b0\par');
    WriteLn(OutFile, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(OutFile, '{\f1 ', EscapeRtf(Entity.ReturnType), '}\par\par');
  End;
  
  { Separateur }
  WriteLn(OutFile, '\pard\brdrb\brdrs\brdrw10\brsp20\par');
  WriteLn(OutFile);
End;

Procedure GenerateRtfDocumentation;
{ Orchestrateur : genere la documentation RTF complete }
Var
  F: Text;
  I: Integer;
  ClassCount, FileCount, FuncCount: Integer;
Begin
  If Not RtfInitialized Then
    InitRtfGenerator;
  
  { Ouvrir le fichier principal }
  Assign(F, RtfOutputDir + RTF_MAIN_FILE);
  Rewrite(F);
  
  { Entete }
  WriteRtfHeader(F);
  
  { Page de titre }
  WriteLn(F, '\pard\qc\s1\fs', RTF_TITLE_FONTSIZE, '\b');
  WriteLn(F, EscapeRtf(RtfProjectName));
  WriteLn(F, '\b0\par\par');
  If RtfProjectBrief <> '' Then
  Begin
    WriteLn(F, '\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(F, EscapeRtf(RtfProjectBrief));
    WriteLn(F, '\par');
  End;
  WriteLn(F, '\pard\ql\par');
  WriteLn(F, '\page');
  
  { Table des matieres }
  WriteLn(F, '\pard\s2\fs', RTF_HEADING_FONTSIZE, '\b Table des matieres\b0\par\par');
  WriteLn(F, '\pard\fs', RTF_DEFAULT_FONTSIZE);
  WriteLn(F, '1. Classes et structures\par');
  WriteLn(F, '2. Fichiers\par');
  WriteLn(F, '3. Fonctions\par');
  WriteLn(F, '\page');
  
  { Section Classes et structures }
  WriteLn(F, '\pard\s2\fs', RTF_HEADING_FONTSIZE, '\b 1. Classes et structures\b0\par\par');
  ClassCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_INTERFACE] Then
    Begin
      GenerateRtfEntity(Entities[I], F);
      Inc(ClassCount);
    End;
  End;
  If ClassCount = 0 Then
  Begin
    WriteLn(F, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(F, 'Aucune classe ou structure documentee.\par');
  End;
  WriteLn(F, '\page');
  
  { Section Fichiers }
  WriteLn(F, '\pard\s2\fs', RTF_HEADING_FONTSIZE, '\b 2. Fichiers\b0\par\par');
  FileCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FILE Then
    Begin
      GenerateRtfEntity(Entities[I], F);
      Inc(FileCount);
    End;
  End;
  If FileCount = 0 Then
  Begin
    WriteLn(F, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(F, 'Aucun fichier documente.\par');
  End;
  WriteLn(F, '\page');
  
  { Section Fonctions }
  WriteLn(F, '\pard\s2\fs', RTF_HEADING_FONTSIZE, '\b 3. Fonctions\b0\par\par');
  FuncCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FUNCTION Then
    Begin
      GenerateRtfEntity(Entities[I], F);
      Inc(FuncCount);
    End;
  End;
  If FuncCount = 0 Then
  Begin
    WriteLn(F, '\pard\fs', RTF_DEFAULT_FONTSIZE);
    WriteLn(F, 'Aucune fonction documentee.\par');
  End;
  
  { Pied de page }
  WriteRtfFooter(F);
  
  Close(F);
  
  WriteLn('Documentation RTF generee dans: ', RtfOutputDir + RTF_MAIN_FILE);
End;

{ Fonctions accesseurs pour RTF }

Function GetRtfOutputDir: String;
Begin
  GetRtfOutputDir := RtfOutputDir;
End;

Procedure SetRtfOutputDir(Const Dir: String);
Begin
  RtfOutputDir := Dir;
End;

Function GetRtfProjectName: String;
Begin
  GetRtfProjectName := RtfProjectName;
End;

Procedure SetRtfProjectName(Const Name: String);
Begin
  RtfProjectName := Name;
End;

Function GetRtfProjectBrief: String;
Begin
  GetRtfProjectBrief := RtfProjectBrief;
End;

Procedure SetRtfProjectBrief(Const Brief: String);
Begin
  RtfProjectBrief := Brief;
End;

Function IsRtfInitialized: Boolean;
Begin
  IsRtfInitialized := RtfInitialized;
End;

Function GetRtfStylesheet: String;
Begin
  GetRtfStylesheet := RtfStylesheet;
End;

Procedure SetRtfStylesheet(Const Stylesheet: String);
Begin
  RtfStylesheet := Stylesheet;
End;

Function GetRtfExtensions: String;
Begin
  GetRtfExtensions := RtfExtensions;
End;

Procedure SetRtfExtensions(Const Extensions: String);
Begin
  RtfExtensions := Extensions;
End;

Function CountRtfFiles: Integer;
{ Compte le nombre de fichiers RTF a generer }
Begin
  CountRtfFiles := 1; { Un seul fichier: refman.rtf }
End;

Function IsRtfEmpty: Boolean;
{ Verifie si le generateur RTF est vide }
Begin
  IsRtfEmpty := (EntityCount = 0);
End;

{ ============================================================
  TODO 15 - GENERATION DE LA DOCUMENTATION XML
  ============================================================ }

Procedure InitXmlGenerator;
{ Initialise le generateur XML }
Begin
  If GetConfigValue('XML_OUTPUT') <> '' Then
    XmlOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + GetConfigValue('XML_OUTPUT') + '/'
  Else
    XmlOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + 'xml/';
  
  XmlSchemaLoc := XML_SCHEMA_LOC;
  XmlProjectName := GetConfigValue('PROJECT_NAME');
  If XmlProjectName = '' Then
    XmlProjectName := 'Documentation';
  XmlProjectBrief := GetConfigValue('PROJECT_BRIEF');
  
  { Creer le repertoire de sortie }
  {$I-}
  MkDir(XmlOutputDir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  XmlInitialized := True;
End;

Function EscapeXml(Const S: String): String;
{ Echappe les caracteres speciaux XML }
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '<': R := R + '&lt;';
      '>': R := R + '&gt;';
      '&': R := R + '&amp;';
      '"': R := R + '&quot;';
      '''': R := R + '&apos;';
    Else
      R := R + C;
    End;
  End;
  EscapeXml := R;
End;

Procedure WriteXmlHeader(Var OutFile: Text);
{ Ecrit l entete XML avec la declaration }
Begin
  WriteLn(OutFile, '<?xml version="', XML_VERSION, '" encoding="', XML_ENCODING, '"?>');
End;

Procedure GenerateXmlMember(Const Entity: TEntity; EntityIdx: Integer; Var OutFile: Text);
{ Genere la section XML pour un membre }
Begin
  WriteLn(OutFile, '      <memberdef kind="', EntityKindToStr(Entity.Kind), 
          '" id="member_', EntityIdx, '">');
  WriteLn(OutFile, '        <name>', EscapeXml(Entity.Name), '</name>');
  
  If Entity.BriefDesc <> '' Then
  Begin
    WriteLn(OutFile, '        <briefdescription>');
    WriteLn(OutFile, '          <para>', EscapeXml(Entity.BriefDesc), '</para>');
    WriteLn(OutFile, '        </briefdescription>');
  End
  Else
    WriteLn(OutFile, '        <briefdescription/>');
  
  If Entity.DetailedDesc <> '' Then
  Begin
    WriteLn(OutFile, '        <detaileddescription>');
    WriteLn(OutFile, '          <para>', EscapeXml(Entity.DetailedDesc), '</para>');
    WriteLn(OutFile, '        </detaileddescription>');
  End
  Else
    WriteLn(OutFile, '        <detaileddescription/>');
  
  If Entity.Signature <> '' Then
    WriteLn(OutFile, '        <definition>', EscapeXml(Entity.Signature), '</definition>');
  
  If Entity.ReturnType <> '' Then
    WriteLn(OutFile, '        <type>', EscapeXml(Entity.ReturnType), '</type>');
  
  If Entity.Parameters <> '' Then
    WriteLn(OutFile, '        <argsstring>', EscapeXml(Entity.Parameters), '</argsstring>');
  
  WriteLn(OutFile, '        <location file="', EscapeXml(Entity.FileName), 
          '" line="', Entity.Line, '"/>');
  WriteLn(OutFile, '      </memberdef>');
End;

Procedure GenerateXmlCompound(Const Entity: TEntity; EntityIdx: Integer; Var OutFile: Text);
{ Genere le fichier XML pour un compound (classe, fichier, etc.) }
Var
  CompoundKind: String;
Begin
  Case Entity.Kind Of
    ENT_CLASS: CompoundKind := 'class';
    ENT_STRUCT: CompoundKind := 'struct';
    ENT_UNION: CompoundKind := 'union';
    ENT_FILE: CompoundKind := 'file';
    ENT_NAMESPACE: CompoundKind := 'namespace';
    ENT_INTERFACE: CompoundKind := 'interface';
    ENT_ENUM: CompoundKind := 'enum';
  Else
    CompoundKind := 'unknown';
  End;
  
  WriteXmlHeader(OutFile);
  WriteLn(OutFile, '<doxygen xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
  WriteLn(OutFile, '         xsi:noNamespaceSchemaLocation="', XmlSchemaLoc, '"');
  WriteLn(OutFile, '         version="', XML_DOXYFILE_VERSION, '">');
  WriteLn(OutFile, '  <compounddef id="compound_', EntityIdx, '" kind="', CompoundKind, '">');
  WriteLn(OutFile, '    <compoundname>', EscapeXml(Entity.Name), '</compoundname>');
  
  If Entity.BriefDesc <> '' Then
  Begin
    WriteLn(OutFile, '    <briefdescription>');
    WriteLn(OutFile, '      <para>', EscapeXml(Entity.BriefDesc), '</para>');
    WriteLn(OutFile, '    </briefdescription>');
  End
  Else
    WriteLn(OutFile, '    <briefdescription/>');
  
  If Entity.DetailedDesc <> '' Then
  Begin
    WriteLn(OutFile, '    <detaileddescription>');
    WriteLn(OutFile, '      <para>', EscapeXml(Entity.DetailedDesc), '</para>');
    WriteLn(OutFile, '    </detaileddescription>');
  End
  Else
    WriteLn(OutFile, '    <detaileddescription/>');
  
  WriteLn(OutFile, '    <location file="', EscapeXml(Entity.FileName), 
          '" line="', Entity.Line, '"/>');
  WriteLn(OutFile, '  </compounddef>');
  WriteLn(OutFile, '</doxygen>');
End;

Procedure GenerateXmlIndex(Var OutFile: Text);
{ Genere le fichier index.xml avec la liste des fichiers XML generes }
Var
  I: Integer;
  RefKind: String;
Begin
  WriteXmlHeader(OutFile);
  WriteLn(OutFile, '<doxygenindex xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
  WriteLn(OutFile, '              xsi:noNamespaceSchemaLocation="index.xsd"');
  WriteLn(OutFile, '              version="', XML_DOXYFILE_VERSION, '">');
  
  For I := 1 To EntityCount Do
  Begin
    Case Entities[I].Kind Of
      ENT_CLASS: RefKind := 'class';
      ENT_STRUCT: RefKind := 'struct';
      ENT_UNION: RefKind := 'union';
      ENT_FILE: RefKind := 'file';
      ENT_NAMESPACE: RefKind := 'namespace';
      ENT_INTERFACE: RefKind := 'interface';
      ENT_ENUM: RefKind := 'enum';
      ENT_FUNCTION: RefKind := 'function';
      ENT_VARIABLE: RefKind := 'variable';
      ENT_TYPEDEF: RefKind := 'typedef';
      ENT_DEFINE: RefKind := 'define';
    Else
      RefKind := 'unknown';
    End;
    
    WriteLn(OutFile, '  <compound refid="compound_', I, '" kind="', RefKind, '">');
    WriteLn(OutFile, '    <name>', EscapeXml(Entities[I].Name), '</name>');
    WriteLn(OutFile, '  </compound>');
  End;
  
  WriteLn(OutFile, '</doxygenindex>');
End;

Procedure GenerateXmlDocumentation;
{ Orchestrateur : genere toute la documentation XML }
Var
  F: Text;
  I: Integer;
  FileName: String;
Begin
  If Not XmlInitialized Then
    InitXmlGenerator;
  
  { Generer les fichiers compound pour chaque entite majeure }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_FILE, 
                            ENT_NAMESPACE, ENT_INTERFACE, ENT_ENUM] Then
    Begin
      FileName := XmlOutputDir + XML_COMPOUND_PREFIX + IntToStr(I) + '.xml';
      Assign(F, FileName);
      Rewrite(F);
      GenerateXmlCompound(Entities[I], I, F);
      Close(F);
    End;
  End;
  
  { Generer le fichier index.xml }
  Assign(F, XmlOutputDir + XML_INDEX_FILE);
  Rewrite(F);
  GenerateXmlIndex(F);
  Close(F);
  
  WriteLn('Documentation XML generee dans: ', XmlOutputDir);
End;

{ Fonctions accesseurs pour XML }

Function GetXmlOutputDir: String;
Begin
  GetXmlOutputDir := XmlOutputDir;
End;

Procedure SetXmlOutputDir(Const Dir: String);
Begin
  XmlOutputDir := Dir;
End;

Function GetXmlProjectName: String;
Begin
  GetXmlProjectName := XmlProjectName;
End;

Procedure SetXmlProjectName(Const Name: String);
Begin
  XmlProjectName := Name;
End;

Function GetXmlProjectBrief: String;
Begin
  GetXmlProjectBrief := XmlProjectBrief;
End;

Procedure SetXmlProjectBrief(Const Brief: String);
Begin
  XmlProjectBrief := Brief;
End;

Function IsXmlInitialized: Boolean;
Begin
  IsXmlInitialized := XmlInitialized;
End;

Function GetXmlSchemaLoc: String;
Begin
  GetXmlSchemaLoc := XmlSchemaLoc;
End;

Procedure SetXmlSchemaLoc(Const SchemaLoc: String);
Begin
  XmlSchemaLoc := SchemaLoc;
End;

Function CountXmlFiles: Integer;
{ Compte le nombre de fichiers XML a generer }
Var
  I, Count: Integer;
Begin
  Count := 1; { Pour index.xml }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_FILE, 
                            ENT_NAMESPACE, ENT_INTERFACE, ENT_ENUM] Then
      Inc(Count);
  End;
  CountXmlFiles := Count;
End;

Function IsXmlEmpty: Boolean;
{ Verifie si le generateur XML est vide }
Begin
  IsXmlEmpty := (EntityCount = 0);
End;

{ ============================================================
  TODO 16 - GENERATION DE LA DOCUMENTATION MAN PAGES
  ============================================================ }

Procedure InitManGenerator;
{ Initialise le generateur de pages MAN }
Begin
  If GetConfigValue('MAN_OUTPUT') <> '' Then
    ManOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + GetConfigValue('MAN_OUTPUT') + '/'
  Else
    ManOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + MAN_OUTPUT_DIR + '/';
  
  If GetConfigValue('MAN_EXTENSION') <> '' Then
    ManExtension := GetConfigValue('MAN_EXTENSION')
  Else
    ManExtension := MAN_DEFAULT_EXTENSION;
  
  If GetConfigValue('MAN_SUBDIR') <> '' Then
    ManSubdir := GetConfigValue('MAN_SUBDIR')
  Else
    ManSubdir := MAN_DEFAULT_SUBDIR;
  
  ManProjectName := GetConfigValue('PROJECT_NAME');
  If ManProjectName = '' Then
    ManProjectName := MAN_SOURCE_DEFAULT;
  ManProjectBrief := GetConfigValue('PROJECT_BRIEF');
  
  { Creer le repertoire de sortie }
  {$I-}
  MkDir(ManOutputDir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  { Creer le sous-repertoire man3 ou autre }
  {$I-}
  MkDir(ManOutputDir + ManSubdir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  ManInitialized := True;
End;

Function EscapeMan(Const S: String): String;
{ Echappe les caracteres speciaux pour les pages MAN }
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '-': R := R + '\-';
      '\': R := R + '\\';
      '.': 
        Begin
          { Echapper le point seulement en debut de ligne }
          If (I = 1) Or (S[I-1] = #10) Then
            R := R + '\&.'
          Else
            R := R + '.';
        End;
      '''': R := R + '\''';
    Else
      R := R + C;
    End;
  End;
  EscapeMan := R;
End;

Procedure GenerateManHeader(Var OutFile: Text;
  Const Name, Section, TheDate, Source, Manual: String);
{ Ecrit l entete .TH de la page MAN }
Begin
  WriteLn(OutFile, '.TH "', EscapeMan(Name), '" ', Section, ' "', 
          TheDate, '" "', EscapeMan(Source), '" "', EscapeMan(Manual), '"');
End;

Procedure GenerateManSection(Var OutFile: Text; Const Title: String);
{ Ecrit une section .SH }
Begin
  WriteLn(OutFile, '.SH "', Title, '"');
End;

Procedure GenerateManParagraph(Var OutFile: Text);
{ Ecrit un indicateur de paragraphe .PP }
Begin
  WriteLn(OutFile, '.PP');
End;

Procedure GenerateManBold(Var OutFile: Text; Const Text: String);
{ Ecrit du texte en gras }
Begin
  Write(OutFile, '\fB', EscapeMan(Text), '\fP');
End;

Procedure GenerateManItalic(Var OutFile: Text; Const Text: String);
{ Ecrit du texte en italique }
Begin
  Write(OutFile, '\fI', EscapeMan(Text), '\fP');
End;

Procedure GenerateManPage(Const Entity: TEntity; EntityIdx: Integer; Var OutFile: Text);
{ Genere la page MAN pour une entite (fonction, structure) }
Var
  I: Integer;
  MemberEntity: TEntity;
  CurrentDate: String;
Begin
  { Date courante }
  CurrentDate := 'April 2026';
  
  { Entete de la page MAN }
  GenerateManHeader(OutFile, Entity.Name, '3', CurrentDate, 
                    ManProjectName, MAN_MANUAL_DEFAULT);
  
  { Section NAME }
  GenerateManSection(OutFile, 'NAME');
  Write(OutFile, Entity.Name);
  If Entity.Brief <> '' Then
    WriteLn(OutFile, ' \- ', EscapeMan(Entity.Brief))
  Else
    WriteLn(OutFile, ' \- ', EscapeMan(EntityKindToStr(Entity.Kind)));
  
  { Section SYNOPSIS }
  GenerateManSection(OutFile, 'SYNOPSIS');
  GenerateManParagraph(OutFile);
  Case Entity.Kind Of
    ENT_FUNCTION, ENT_METHOD:
      Begin
        If Entity.ReturnType <> '' Then
        Begin
          GenerateManBold(OutFile, Entity.ReturnType);
          Write(OutFile, ' ');
        End;
        GenerateManBold(OutFile, Entity.Name);
        WriteLn(OutFile, '(', EscapeMan(Entity.Params), ')');
      End;
    ENT_CLASS, ENT_STRUCT, ENT_UNION:
      Begin
        GenerateManBold(OutFile, EntityKindToStr(Entity.Kind));
        Write(OutFile, ' ');
        GenerateManBold(OutFile, Entity.Name);
        WriteLn(OutFile);
      End;
    ENT_TYPEDEF:
      Begin
        Write(OutFile, 'typedef ');
        GenerateManBold(OutFile, Entity.Name);
        WriteLn(OutFile);
      End;
    ENT_ENUM:
      Begin
        Write(OutFile, 'enum ');
        GenerateManBold(OutFile, Entity.Name);
        WriteLn(OutFile);
      End;
    ENT_VARIABLE:
      Begin
        If Entity.ReturnType <> '' Then
        Begin
          Write(OutFile, Entity.ReturnType, ' ');
        End;
        GenerateManBold(OutFile, Entity.Name);
        WriteLn(OutFile);
      End;
  Else
    Begin
      GenerateManBold(OutFile, Entity.Name);
      WriteLn(OutFile);
    End;
  End;
  
  { Section DESCRIPTION }
  GenerateManSection(OutFile, 'DESCRIPTION');
  GenerateManParagraph(OutFile);
  If Entity.Description <> '' Then
    WriteLn(OutFile, EscapeMan(Entity.Description))
  Else If Entity.Brief <> '' Then
    WriteLn(OutFile, EscapeMan(Entity.Brief))
  Else
    WriteLn(OutFile, 'No description available.');
  
  { Section MEMBERS pour les classes/structures }
  If Entity.Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_ENUM] Then
  Begin
    If Entity.MemberCount > 0 Then
    Begin
      GenerateManSection(OutFile, 'MEMBERS');
      For I := 1 To Entity.MemberCount Do
      Begin
        If (Entity.Members[I] >= 1) And (Entity.Members[I] <= EntityCount) Then
        Begin
          MemberEntity := Entities[Entity.Members[I]];
          GenerateManParagraph(OutFile);
          GenerateManBold(OutFile, MemberEntity.Name);
          WriteLn(OutFile);
          If MemberEntity.Brief <> '' Then
            WriteLn(OutFile, EscapeMan(MemberEntity.Brief));
        End;
      End;
    End;
  End;
  
  { Section RETURN VALUE pour les fonctions }
  If Entity.Kind In [ENT_FUNCTION, ENT_METHOD] Then
  Begin
    If Entity.ReturnType <> '' Then
    Begin
      GenerateManSection(OutFile, 'RETURN VALUE');
      GenerateManParagraph(OutFile);
      WriteLn(OutFile, 'Returns a value of type ', 
              EscapeMan(Entity.ReturnType), '.');
    End;
  End;
  
  { Section SEE ALSO }
  GenerateManSection(OutFile, 'SEE ALSO');
  GenerateManParagraph(OutFile);
  If Entity.SeeAlso <> '' Then
    WriteLn(OutFile, EscapeMan(Entity.SeeAlso))
  Else
    WriteLn(OutFile, 'Documentation generated by DOXYGEN.');
  
  { Section AUTHORS }
  If Entity.Author <> '' Then
  Begin
    GenerateManSection(OutFile, 'AUTHORS');
    GenerateManParagraph(OutFile);
    WriteLn(OutFile, EscapeMan(Entity.Author));
  End;
End;

Procedure GenerateManDocumentation;
{ Orchestrateur : genere toutes les pages MAN }
Var
  I: Integer;
  F: Text;
  FileName: String;
Begin
  If Not ManInitialized Then
    InitManGenerator;
  
  WriteLn('Generation des pages MAN...');
  
  { Generer une page pour chaque entite documentable }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_FUNCTION, ENT_CLASS, ENT_STRUCT, 
                            ENT_UNION, ENT_TYPEDEF, ENT_ENUM,
                            ENT_METHOD, ENT_INTERFACE] Then
    Begin
      FileName := ManOutputDir + ManSubdir + '/' + 
                  Entities[I].Name + ManExtension;
      Assign(F, FileName);
      {$I-}
      Rewrite(F);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateManPage(Entities[I], I, F);
        Close(F);
      End
      Else
        WarnMsg('Impossible de creer: ' + FileName);
    End;
  End;
  
  WriteLn('Documentation MAN generee dans: ', ManOutputDir + ManSubdir);
End;

{ Fonctions accesseurs pour MAN }

Function GetManOutputDir: String;
Begin
  GetManOutputDir := ManOutputDir;
End;

Procedure SetManOutputDir(Const Dir: String);
Begin
  ManOutputDir := Dir;
End;

Function GetManExtension: String;
Begin
  GetManExtension := ManExtension;
End;

Procedure SetManExtension(Const Ext: String);
Begin
  ManExtension := Ext;
End;

Function GetManSubdir: String;
Begin
  GetManSubdir := ManSubdir;
End;

Procedure SetManSubdir(Const Subdir: String);
Begin
  ManSubdir := Subdir;
End;

Function GetManProjectName: String;
Begin
  GetManProjectName := ManProjectName;
End;

Procedure SetManProjectName(Const Name: String);
Begin
  ManProjectName := Name;
End;

Function GetManProjectBrief: String;
Begin
  GetManProjectBrief := ManProjectBrief;
End;

Procedure SetManProjectBrief(Const Brief: String);
Begin
  ManProjectBrief := Brief;
End;

Function IsManInitialized: Boolean;
Begin
  IsManInitialized := ManInitialized;
End;

Function CountManPages: Integer;
{ Compte le nombre de pages MAN a generer }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_FUNCTION, ENT_CLASS, ENT_STRUCT, 
                            ENT_UNION, ENT_TYPEDEF, ENT_ENUM,
                            ENT_METHOD, ENT_INTERFACE] Then
      Inc(Count);
  End;
  CountManPages := Count;
End;

Function IsManEmpty: Boolean;
{ Verifie si le generateur MAN est vide }
Begin
  IsManEmpty := (EntityCount = 0);
End;

{ ============================================================
  TODO 17 - GENERATION DES GRAPHES D'APPELS (CALL GRAPHS)
  ============================================================ }

Procedure InitCallGraph;
{ Initialise le generateur de graphes d'appels }
Begin
  CallNodeCount := 0;
  CallEdgeCount := 0;
  
  If GetConfigValue('CALL_GRAPH_OUTPUT') <> '' Then
    CallGraphOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + GetConfigValue('CALL_GRAPH_OUTPUT') + '/'
  Else
    CallGraphOutputDir := GetConfigValue('OUTPUT_DIRECTORY') + CALLGRAPH_OUTPUT_DIR + '/';
  
  { Creer le repertoire de sortie }
  {$I-}
  MkDir(CallGraphOutputDir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  CallGraphInitialized := True;
End;

Function FindCallNode(EntityId: Integer): Integer;
{ Trouve un noeud de graphe d'appel par son EntityId }
Var
  I: Integer;
Begin
  FindCallNode := 0;
  For I := 1 To CallNodeCount Do
  Begin
    If CallGraphNodes[I].EntityId = EntityId Then
    Begin
      FindCallNode := I;
      Exit;
    End;
  End;
End;

Function FindCallNodeByName(Const Name: String): Integer;
{ Trouve un noeud de graphe d'appel par son nom }
Var
  I: Integer;
Begin
  FindCallNodeByName := 0;
  For I := 1 To CallNodeCount Do
  Begin
    If CallGraphNodes[I].Name = Name Then
    Begin
      FindCallNodeByName := I;
      Exit;
    End;
  End;
End;

Function AddCallGraphNode(EntityId: Integer; Const Name, FileName: String;
  Line: Integer): Integer;
{ Ajoute un noeud au graphe d'appels }
Var
  Idx: Integer;
Begin
  { Verifier si le noeud existe deja }
  Idx := FindCallNode(EntityId);
  If Idx > 0 Then
  Begin
    AddCallGraphNode := Idx;
    Exit;
  End;
  
  { Verifier la capacite }
  If CallNodeCount >= MAX_CALL_NODES Then
  Begin
    WarnMsg('Nombre maximum de noeuds de graphe d''appel atteint');
    AddCallGraphNode := 0;
    Exit;
  End;
  
  Inc(CallNodeCount);
  With CallGraphNodes[CallNodeCount] Do
  Begin
    EntityId := EntityId;
    Name := Name;
    FileName := FileName;
    Line := Line;
    NodeId := CallNodeCount;
  End;
  
  AddCallGraphNode := CallNodeCount;
End;

Function AddCallGraphEdge(CallerId, CalleeId, Line: Integer;
  IsDirect: Boolean): Integer;
{ Ajoute une arete au graphe d'appels }
Var
  I: Integer;
Begin
  { Verifier que l'arete n'existe pas deja }
  For I := 1 To CallEdgeCount Do
  Begin
    If (CallGraphEdges[I].CallerId = CallerId) And
       (CallGraphEdges[I].CalleeId = CalleeId) Then
    Begin
      AddCallGraphEdge := I;
      Exit;
    End;
  End;
  
  { Verifier la capacite }
  If CallEdgeCount >= MAX_CALL_EDGES Then
  Begin
    WarnMsg('Nombre maximum d''aretes de graphe d''appel atteint');
    AddCallGraphEdge := 0;
    Exit;
  End;
  
  Inc(CallEdgeCount);
  With CallGraphEdges[CallEdgeCount] Do
  Begin
    CallerId := CallerId;
    CalleeId := CalleeId;
    Line := Line;
    IsDirect := IsDirect;
    EdgeId := CallEdgeCount;
  End;
  
  AddCallGraphEdge := CallEdgeCount;
End;

Function GetCallees(EntityId: Integer): String;
{ Retourne la liste des fonctions appelees par EntityId }
Var
  I: Integer;
  NodeIdx: Integer;
  Result: String;
Begin
  Result := '';
  NodeIdx := FindCallNode(EntityId);
  
  If NodeIdx > 0 Then
  Begin
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CallerId = NodeIdx Then
      Begin
        If Result <> '' Then
          Result := Result + ', ';
        If (CallGraphEdges[I].CalleeId >= 1) And 
           (CallGraphEdges[I].CalleeId <= CallNodeCount) Then
          Result := Result + CallGraphNodes[CallGraphEdges[I].CalleeId].Name;
      End;
    End;
  End;
  
  GetCallees := Result;
End;

Function GetCallers(EntityId: Integer): String;
{ Retourne la liste des fonctions qui appellent EntityId }
Var
  I: Integer;
  NodeIdx: Integer;
  Result: String;
Begin
  Result := '';
  NodeIdx := FindCallNode(EntityId);
  
  If NodeIdx > 0 Then
  Begin
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CalleeId = NodeIdx Then
      Begin
        If Result <> '' Then
          Result := Result + ', ';
        If (CallGraphEdges[I].CallerId >= 1) And 
           (CallGraphEdges[I].CallerId <= CallNodeCount) Then
          Result := Result + CallGraphNodes[CallGraphEdges[I].CallerId].Name;
      End;
    End;
  End;
  
  GetCallers := Result;
End;

Function CountCallees(EntityId: Integer): Integer;
{ Compte le nombre de fonctions appelees par EntityId }
Var
  I: Integer;
  NodeIdx: Integer;
  Count: Integer;
Begin
  Count := 0;
  NodeIdx := FindCallNode(EntityId);
  
  If NodeIdx > 0 Then
  Begin
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CallerId = NodeIdx Then
        Inc(Count);
    End;
  End;
  
  CountCallees := Count;
End;

Function CountCallers(EntityId: Integer): Integer;
{ Compte le nombre de fonctions qui appellent EntityId }
Var
  I: Integer;
  NodeIdx: Integer;
  Count: Integer;
Begin
  Count := 0;
  NodeIdx := FindCallNode(EntityId);
  
  If NodeIdx > 0 Then
  Begin
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CalleeId = NodeIdx Then
        Inc(Count);
    End;
  End;
  
  CountCallers := Count;
End;

Function ExtractFunctionCalls(Const Code: String): String;
{ Extrait les appels de fonctions d'une ligne de code }
Var
  I, J: Integer;
  InString: Boolean;
  InComment: Boolean;
  ParenDepth: Integer;
  FuncName: String;
  Result: String;
  C: Char;
Begin
  Result := '';
  InString := False;
  InComment := False;
  ParenDepth := 0;
  FuncName := '';
  I := 1;
  
  While I <= Length(Code) Do
  Begin
    C := Code[I];
    
    { Gestion des chaines de caracteres }
    If (C = '"') And Not InComment Then
    Begin
      InString := Not InString;
      Inc(I);
      Continue;
    End;
    
    { Gestion des commentaires }
    If (C = '/') And (I < Length(Code)) And Not InString Then
    Begin
      If Code[I+1] = '/' Then
      Begin
        { Commentaire ligne, arreter }
        Break;
      End;
      If Code[I+1] = '*' Then
      Begin
        InComment := True;
        Inc(I, 2);
        Continue;
      End;
    End;
    
    If InComment And (C = '*') And (I < Length(Code)) And (Code[I+1] = '/') Then
    Begin
      InComment := False;
      Inc(I, 2);
      Continue;
    End;
    
    If InString Or InComment Then
    Begin
      Inc(I);
      Continue;
    End;
    
    { Detection des identificateurs }
    If (C >= 'A') And (C <= 'Z') Or 
       (C >= 'a') And (C <= 'z') Or (C = '_') Then
    Begin
      FuncName := '';
      While (I <= Length(Code)) And 
            ((Code[I] >= 'A') And (Code[I] <= 'Z') Or
             (Code[I] >= 'a') And (Code[I] <= 'z') Or
             (Code[I] >= '0') And (Code[I] <= '9') Or
             (Code[I] = '_')) Do
      Begin
        FuncName := FuncName + Code[I];
        Inc(I);
      End;
      
      { Sauter les espaces }
      While (I <= Length(Code)) And (Code[I] = ' ') Do
        Inc(I);
      
      { Verifier si c'est un appel de fonction }
      If (I <= Length(Code)) And (Code[I] = '(') Then
      Begin
        { Ignorer les mots-cles }
        If (FuncName <> 'if') And (FuncName <> 'while') And
           (FuncName <> 'for') And (FuncName <> 'switch') And
           (FuncName <> 'return') And (FuncName <> 'sizeof') And
           (FuncName <> 'typeof') And (FuncName <> 'case') Then
        Begin
          If Result <> '' Then
            Result := Result + ',';
          Result := Result + FuncName;
        End;
      End;
      
      Continue;
    End;
    
    Inc(I);
  End;
  
  ExtractFunctionCalls := Result;
End;

Procedure BuildCallGraph;
{ Analyse le code source pour construire le graphe d'appels }
Var
  I, J: Integer;
  NodeIdx, CalleeIdx: Integer;
  Calls: String;
  FuncName: String;
  Pos: Integer;
Begin
  If Not CallGraphInitialized Then
    InitCallGraph;
  
  WriteLn('Construction du graphe d''appels...');
  
  { Ajouter toutes les fonctions comme noeuds }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_FUNCTION, ENT_METHOD, ENT_PROCEDURE] Then
    Begin
      AddCallGraphNode(I, Entities[I].Name, Entities[I].FileName, 
                       Entities[I].Line);
    End;
  End;
  
  { Note: L'analyse complete des appels necessite le parsing du corps
    des fonctions, ce qui n'est pas implemente dans cette version
    simplifiee. Les aretes peuvent etre ajoutees manuellement ou
    lors d'une analyse plus approfondie du code source. }
  
  WriteLn('Graphe d''appels construit: ', CallNodeCount, ' noeuds, ',
          CallEdgeCount, ' aretes');
End;

Procedure GenerateCallGraphDot(Const Entity: TEntity; Var OutFile: Text);
{ Genere le graphe d'appels au format DOT (Graphviz) }
Var
  I: Integer;
  NodeIdx: Integer;
Begin
  WriteLn(OutFile, 'digraph "', Entity.Name, '" {');
  WriteLn(OutFile, '  // Configuration du graphe');
  WriteLn(OutFile, '  rankdir=LR;');
  WriteLn(OutFile, '  node [shape=', CALLGRAPH_NODE_SHAPE, ', fontname="', 
          CALLGRAPH_FONT_NAME, '", fontsize=', CALLGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', CALLGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Trouver le noeud de l'entite }
  NodeIdx := 0;
  For I := 1 To CallNodeCount Do
  Begin
    If CallGraphNodes[I].Name = Entity.Name Then
    Begin
      NodeIdx := I;
      Break;
    End;
  End;
  
  If NodeIdx > 0 Then
  Begin
    WriteLn(OutFile, '  // Noeud central');
    WriteLn(OutFile, '  "', Entity.Name, '" [style=filled, fillcolor=lightblue];');
    WriteLn(OutFile);
    
    { Generer les aretes sortantes (fonctions appelees) }
    WriteLn(OutFile, '  // Fonctions appelees');
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CallerId = NodeIdx Then
      Begin
        If (CallGraphEdges[I].CalleeId >= 1) And 
           (CallGraphEdges[I].CalleeId <= CallNodeCount) Then
        Begin
          WriteLn(OutFile, '  "', CallGraphNodes[CallGraphEdges[I].CallerId].Name,
                  '" -> "', CallGraphNodes[CallGraphEdges[I].CalleeId].Name, '";');
        End;
      End;
    End;
    
    { Generer les aretes entrantes (fonctions appelantes) }
    WriteLn(OutFile);
    WriteLn(OutFile, '  // Fonctions appelantes');
    For I := 1 To CallEdgeCount Do
    Begin
      If CallGraphEdges[I].CalleeId = NodeIdx Then
      Begin
        If (CallGraphEdges[I].CallerId >= 1) And 
           (CallGraphEdges[I].CallerId <= CallNodeCount) Then
        Begin
          WriteLn(OutFile, '  "', CallGraphNodes[CallGraphEdges[I].CallerId].Name,
                  '" -> "', CallGraphNodes[CallGraphEdges[I].CalleeId].Name, '";');
        End;
      End;
    End;
  End
  Else
  Begin
    { Noeud non trouve, generer un noeud isole }
    WriteLn(OutFile, '  "', Entity.Name, '" [style=filled, fillcolor=lightblue];');
  End;
  
  WriteLn(OutFile, '}');
End;

Procedure GenerateFullCallGraphDot(Var OutFile: Text);
{ Genere le graphe d'appels complet au format DOT }
Var
  I: Integer;
Begin
  WriteLn(OutFile, 'digraph "CallGraph" {');
  WriteLn(OutFile, '  // Configuration du graphe');
  WriteLn(OutFile, '  rankdir=TB;');
  WriteLn(OutFile, '  node [shape=', CALLGRAPH_NODE_SHAPE, ', fontname="', 
          CALLGRAPH_FONT_NAME, '", fontsize=', CALLGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', CALLGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Generer tous les noeuds }
  WriteLn(OutFile, '  // Noeuds');
  For I := 1 To CallNodeCount Do
  Begin
    WriteLn(OutFile, '  "', CallGraphNodes[I].Name, '";');
  End;
  
  WriteLn(OutFile);
  
  { Generer toutes les aretes }
  WriteLn(OutFile, '  // Aretes');
  For I := 1 To CallEdgeCount Do
  Begin
    If (CallGraphEdges[I].CallerId >= 1) And 
       (CallGraphEdges[I].CallerId <= CallNodeCount) And
       (CallGraphEdges[I].CalleeId >= 1) And 
       (CallGraphEdges[I].CalleeId <= CallNodeCount) Then
    Begin
      Write(OutFile, '  "', CallGraphNodes[CallGraphEdges[I].CallerId].Name,
            '" -> "', CallGraphNodes[CallGraphEdges[I].CalleeId].Name, '"');
      If Not CallGraphEdges[I].IsDirect Then
        Write(OutFile, ' [style=dashed]');
      WriteLn(OutFile, ';');
    End;
  End;
  
  WriteLn(OutFile, '}');
End;

Procedure RenderCallGraphImage(Const DotFile, ImageFile: String);
{ Invoque dot pour generer l'image (PNG, SVG, etc.) }
Var
  Cmd: String;
  Format: String;
  I: Integer;
Begin
  { Determiner le format a partir de l'extension }
  Format := 'png'; { Par defaut }
  For I := Length(ImageFile) DownTo 1 Do
  Begin
    If ImageFile[I] = '.' Then
    Begin
      Format := Copy(ImageFile, I + 1, Length(ImageFile) - I);
      Break;
    End;
  End;
  
  { Note: L'execution de commandes externes necessite SwapVectors
    et Exec sous DOS, ou d'autres mecanismes selon la plateforme.
    Cette procedure est un placeholder. }
  
  WriteLn('Pour generer l''image, executez:');
  WriteLn('  dot -T', Format, ' ', DotFile, ' -o ', ImageFile);
End;

Procedure GenerateCallGraphDocumentation;
{ Orchestrateur : genere tous les graphes d'appels }
Var
  I: Integer;
  F: Text;
  FileName: String;
Begin
  If Not CallGraphInitialized Then
    InitCallGraph;
  
  WriteLn('Generation des graphes d''appels...');
  
  { Construire le graphe d'appels }
  BuildCallGraph;
  
  { Generer le graphe complet }
  FileName := CallGraphOutputDir + CALLGRAPH_DOT_FILE;
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateFullCallGraphDot(F);
    Close(F);
    WriteLn('Graphe d''appels complet genere: ', FileName);
    RenderCallGraphImage(FileName, CallGraphOutputDir + CALLGRAPH_PNG_FILE);
  End
  Else
    WarnMsg('Impossible de creer: ' + FileName);
  
  { Generer un graphe pour chaque fonction }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_FUNCTION, ENT_METHOD, ENT_PROCEDURE] Then
    Begin
      FileName := CallGraphOutputDir + Entities[I].Name + '.dot';
      Assign(F, FileName);
      {$I-}
      Rewrite(F);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateCallGraphDot(Entities[I], F);
        Close(F);
      End;
    End;
  End;
  
  WriteLn('Documentation des graphes d''appels generee dans: ', CallGraphOutputDir);
End;

{ Fonctions accesseurs pour les graphes d'appels }

Function GetCallGraphOutputDir: String;
Begin
  GetCallGraphOutputDir := CallGraphOutputDir;
End;

Procedure SetCallGraphOutputDir(Const Dir: String);
Begin
  CallGraphOutputDir := Dir;
End;

Function GetCallNodeCount: Integer;
Begin
  GetCallNodeCount := CallNodeCount;
End;

Function GetCallEdgeCount: Integer;
Begin
  GetCallEdgeCount := CallEdgeCount;
End;

Function GetCallGraphNode(Index: Integer): TCallGraphNode;
Begin
  If (Index >= 1) And (Index <= CallNodeCount) Then
    GetCallGraphNode := CallGraphNodes[Index]
  Else
  Begin
    GetCallGraphNode.EntityId := 0;
    GetCallGraphNode.Name := '';
    GetCallGraphNode.FileName := '';
    GetCallGraphNode.Line := 0;
    GetCallGraphNode.NodeId := 0;
  End;
End;

Function GetCallGraphEdge(Index: Integer): TCallGraphEdge;
Begin
  If (Index >= 1) And (Index <= CallEdgeCount) Then
    GetCallGraphEdge := CallGraphEdges[Index]
  Else
  Begin
    GetCallGraphEdge.CallerId := 0;
    GetCallGraphEdge.CalleeId := 0;
    GetCallGraphEdge.Line := 0;
    GetCallGraphEdge.IsDirect := False;
    GetCallGraphEdge.EdgeId := 0;
  End;
End;

Function IsCallGraphInitialized: Boolean;
Begin
  IsCallGraphInitialized := CallGraphInitialized;
End;

Function IsCallGraphEmpty: Boolean;
Begin
  IsCallGraphEmpty := (CallNodeCount = 0);
End;

Function HasCallGraphEdge(CallerId, CalleeId: Integer): Boolean;
{ Verifie si une arete existe entre deux noeuds }
Var
  I: Integer;
Begin
  HasCallGraphEdge := False;
  For I := 1 To CallEdgeCount Do
  Begin
    If (CallGraphEdges[I].CallerId = CallerId) And
       (CallGraphEdges[I].CalleeId = CalleeId) Then
    Begin
      HasCallGraphEdge := True;
      Exit;
    End;
  End;
End;

Function GetNodeCallees(NodeIdx: Integer): String;
{ Retourne les noms des fonctions appelees par un noeud }
Var
  I: Integer;
  Result: String;
Begin
  Result := '';
  For I := 1 To CallEdgeCount Do
  Begin
    If CallGraphEdges[I].CallerId = NodeIdx Then
    Begin
      If Result <> '' Then
        Result := Result + ', ';
      If (CallGraphEdges[I].CalleeId >= 1) And 
         (CallGraphEdges[I].CalleeId <= CallNodeCount) Then
        Result := Result + CallGraphNodes[CallGraphEdges[I].CalleeId].Name;
    End;
  End;
  GetNodeCallees := Result;
End;

Function GetNodeCallers(NodeIdx: Integer): String;
{ Retourne les noms des fonctions qui appellent un noeud }
Var
  I: Integer;
  Result: String;
Begin
  Result := '';
  For I := 1 To CallEdgeCount Do
  Begin
    If CallGraphEdges[I].CalleeId = NodeIdx Then
    Begin
      If Result <> '' Then
        Result := Result + ', ';
      If (CallGraphEdges[I].CallerId >= 1) And 
         (CallGraphEdges[I].CallerId <= CallNodeCount) Then
        Result := Result + CallGraphNodes[CallGraphEdges[I].CallerId].Name;
    End;
  End;
  GetNodeCallers := Result;
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
    If Opts.ConfigFile = '' Then
      Opts.ConfigFile := 'Doxyfile';
    GenerateDefaultConfig(Opts.ConfigFile);
    Halt(EXIT_OK);
  End;

  { Mise a jour d'un fichier de configuration (TODO 06) }
  If Opts.UpdateConfig Then
  Begin
    If Opts.ConfigFile = '' Then
      Opts.ConfigFile := 'Doxyfile';
    UpdateConfigFile(Opts.ConfigFile);
    Halt(EXIT_OK);
  End;

  { Generation de fichier de style (TODO 06) }
  If Opts.GenStyle Then
  Begin
    ProcessOption_w(Opts.StyleFormat, 'stylesheet', '');
    Halt(EXIT_OK);
  End;

  { Generation de layout (TODO 06) }
  If Opts.GenLayout Then
  Begin
    ProcessOption_l('');
    Halt(EXIT_OK);
  End;

  { Generation de header (TODO 06) }
  If Opts.GenHeader Then
  Begin
    ProcessOption_e(Opts.HeaderFormat, '');
    Halt(EXIT_OK);
  End;

  { Valider les options de debogage si specifiees (TODO 06) }
  If Opts.DebugMode And (Opts.DebugOpts <> '') Then
  Begin
    If Not IsValidDebugOption(Opts.DebugOpts) Then
    Begin
      WarnMsg('Option de debogage non reconnue: ' + Opts.DebugOpts);
      WriteLn('Options valides: time, extcmd, markdown, filteroutput, validate,');
      WriteLn('                 plantuml, rtf, qhp, tag, lex, fortran, layout,');
      WriteLn('                 cite, srclex, commentcnv, preprocessor');
    End
    Else If Not Opts.Quiet Then
      WriteLn('Mode debogage active: ', Opts.DebugOpts);
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

  { Lecture du fichier de configuration (TODO 05) }
  ReadConfigFile(Opts.ConfigFile);
  
  { Mode expansion de configuration (TODO 06) }
  If Opts.ExpandOnly Then
  Begin
    ExpandConfig;
    Halt(EXIT_OK);
  End;
  
  { Afficher les informations du projet }
  WriteLn('Lecture de ', Opts.ConfigFile, '... OK');
  WriteLn;
  WriteLn('Configuration chargee:');
  WriteLn('  Nombre d''options: ', ConfigCount);
  If GetConfigValue('PROJECT_NAME') <> '' Then
    WriteLn('  Projet: ', GetConfigValue('PROJECT_NAME'));
  If GetConfigValue('PROJECT_BRIEF') <> '' Then
    WriteLn('  Description: ', GetConfigValue('PROJECT_BRIEF'));
  If GetConfigValue('OUTPUT_DIRECTORY') <> '' Then
    WriteLn('  Sortie: ', GetConfigValue('OUTPUT_DIRECTORY'));
  WriteLn('  HTML: ', GetConfigValue('GENERATE_HTML'));
  WriteLn('  LaTeX: ', GetConfigValue('GENERATE_LATEX'));
  WriteLn('  XML: ', GetConfigValue('GENERATE_XML'));
  WriteLn('  MAN: ', GetConfigValue('GENERATE_MAN'));
  WriteLn;
  
  { Verifier les fichiers d'entree }
  If GetConfigValue('INPUT') = '' Then
  Begin
    WriteLn('Avertissement: Aucun fichier d''entree specifie (INPUT).');
    WriteLn('Utilisez doxygen -INPUT fichier.c pour analyser un fichier directement.');
  End
  Else
  Begin
    WriteLn('Fichiers d''entree: ', GetConfigValue('INPUT'));
  End;
  
  WriteLn;
  WriteLn('Note: La generation de documentation est en cours d''implementation.');
  WriteLn('      Voir les TODOs 08 a 25 pour la feuille de route.');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  Run;
End.
