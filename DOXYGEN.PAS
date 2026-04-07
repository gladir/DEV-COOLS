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

  TODO 18 - GENERATION DES GRAPHES DE DEPENDANCES (DEPENDENCY GRAPHS) [IMPLEMENTE]
            Constantes : DEPGRAPH_OUTPUT_DIR, DEPGRAPH_DOT_FILE, DEPGRAPH_PNG_FILE,
              DEPGRAPH_SVG_FILE, DEPGRAPH_INC_PREFIX, DEPGRAPH_INCBY_PREFIX,
              DEPGRAPH_DIR_PREFIX, DEPGRAPH_MOD_PREFIX, DEPGRAPH_NODE_SHAPE,
              DEPGRAPH_DIR_SHAPE, DEPGRAPH_EDGE_STYLE, DEPGRAPH_FONT_NAME,
              DEPGRAPH_FONT_SIZE, DEPGRAPH_INCLUDE_COLOR, DEPGRAPH_LOCAL_COLOR,
              DEPGRAPH_SYSTEM_COLOR, MAX_DEP_DIRS
            Variables : DepGraphOutputDir, DepGraphFormat, DepGraphInitialized
            Procedure InitDepGraph
              initialiser le generateur de graphes de dependances
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
            Procedure GenerateDepGraphDocumentation
              orchestrateur: generer tous les graphes de dependances
            Fonctions accesseurs Get/SetDepGraphOutputDir, Get/SetDepGraphFormat,
              IsDepGraphInitialized, IsDepGraphEmpty, CountIncludeDependencies,
              CountIncludedByDependencies, GetDepGraphDotFileName,
              GetDepGraphImageFileName, ExtractBaseFileName, ExtractDirPath,
              DependencyKindColor, SanitizeNodeId

  TODO 19 - GENERATION DES DIAGRAMMES DE CLASSES (CLASS DIAGRAMS) [IMPLEMENTE]
            Constantes : CLASSDIAG_OUTPUT_DIR, CLASSDIAG_DOT_FILE,
              CLASSDIAG_PNG_FILE, CLASSDIAG_SVG_FILE, CLASSDIAG_CLASS_PREFIX,
              CLASSDIAG_COLLAB_PREFIX, CLASSDIAG_INHERIT_PREFIX,
              CLASSDIAG_UML_PREFIX, CLASSDIAG_NODE_SHAPE, CLASSDIAG_UML_SHAPE,
              CLASSDIAG_EDGE_INHERIT, CLASSDIAG_EDGE_COMPOSE, CLASSDIAG_EDGE_AGGREG,
              CLASSDIAG_EDGE_ASSOC, CLASSDIAG_FONT_NAME, CLASSDIAG_FONT_SIZE,
              CLASSDIAG_PUBLIC_COLOR, CLASSDIAG_PROTECTED_COLOR,
              CLASSDIAG_PRIVATE_COLOR, CLASSDIAG_CLASS_COLOR,
              CLASSDIAG_ABSTRACT_COLOR, CLASSDIAG_INTERFACE_COLOR,
              CLASSDIAG_MAX_MEMBERS, CLASSDIAG_PLANTUML_START, CLASSDIAG_PLANTUML_END
            Variables : ClassDiagOutputDir, ClassDiagFormat, ClassDiagUmlLook,
              ClassDiagInitialized
            Procedure InitClassDiagram
              initialiser le generateur de diagrammes de classes
            Procedure GenerateClassDiagramDot(Const EntityId: Integer;
              Var OutFile: Text)
              generer le diagramme de classe au format DOT
              montrer les membres, methodes, heritage
            Procedure GenerateCollaborationDiagramDot(Const EntityId: Integer;
              Var OutFile: Text)
              generer le diagramme de collaboration au format DOT
              montrer les relations avec d autres classes
            Procedure GenerateInheritanceDiagramDot(Const EntityId: Integer;
              Var OutFile: Text)
              generer le diagramme d heritage au format DOT
              (classes de base et classes derivees)
            Procedure GenerateUmlDiagramDot(Const EntityId: Integer;
              Var OutFile: Text; UmlLook: Boolean)
              generer le diagramme UML complet au format DOT
            Procedure RenderClassDiagramImage(Const DotFile, ImageFile: String)
              invoquer dot pour generer l image
            Procedure GeneratePlantUml(Const EntityId: Integer;
              Var OutFile: Text)
              generer le code PlantUML pour le diagramme
            Procedure GenerateClassDiagramDocumentation
              orchestrateur: generer tous les diagrammes de classes
            Fonctions accesseurs Get/SetClassDiagOutputDir, Get/SetClassDiagFormat,
              Get/SetClassDiagUmlLook, IsClassDiagInitialized, IsClassDiagEmpty,
              CountClassDiagrams, GetClassDiagDotFileName, GetClassDiagImageFileName,
              GetClassDiagPlantUmlFileName, VisibilitySymbol, VisibilityColor,
              EscapeDotLabel, SanitizeClassNodeId, EntityVisibilityToStr

  TODO 20 - SUPPORT DES MACROS ET PREPROCESSEUR [IMPLEMENTE]
            TMacro : record
              Name       : String   (nom de la macro)
              Parameters : String   (parametres si fonction-like)
              Value      : String   (valeur de substitution)
              FileName   : String   (fichier de definition)
              Line       : Integer  (ligne de definition)
              IsFuncLike : Boolean  (True si macro avec parametres)
              IsVariadic : Boolean  (True si parametres variadiques)
            End
            TPreprocessorState : enumeration (PP_ACTIVE, PP_SKIPPING, PP_DONE)
            TIfDefStack : record (State, WasActive, Line)
            Variables globales :
              Macros     : Array[1..MAX_MACROS] Of TMacro
              MacroCount : Integer
              PredefinedMacros : Array[1..MAX_PREDEFINED] Of TMacro
              PredefinedCount  : Integer
              IfDefStack, IfDefStackDepth, MacrosInitialized
            Constantes : MAX_MACROS, MAX_PREDEFINED, MAX_MACRO_PARAMS,
              MAX_MACRO_VALUE, MAX_INCLUDE_STACK, MACRO_PREFIX_*
            Procedure InitMacros : initialiser le systeme de macros
            Function FindMacro : chercher une macro par nom
            Function AddMacro : ajouter une macro
            Procedure RemoveMacro : supprimer une macro (#undef)
            Procedure ExtractMacros(Const FileName: String)
              scanner le fichier pour les directives #define
              extraire le nom, les parametres et la valeur
            Function ExpandMacroSimple : expander une macro simple
            Procedure AddPredefinedMacro : ajouter une macro predefinee
            Procedure Push/PopIfDefState, HandleIfDef, HandleElse, HandleEndIf
            Fonctions accesseurs : GetMacroCount, GetPredefinedCount,
              IsMacrosInitialized, IsMacrosEmpty, IsMacroDefined, GetMacro,
              GetPredefinedMacro, GetMacroValue, GetMacroParams,
              IsMacroFuncLike, IsMacroVariadic, GetCurrentPPState,
              IsPreprocessorActive, CountTotalMacros, GetMacroFileName,
              GetMacroLine, ShowMacros

  TODO 21 - SUPPORT DES ESPACES DE NOMS ET MODULES [IMPLEMENTE]
            TNamespace : record
              Name       : String   (nom du namespace)
              FullName   : String   (nom qualifie complet)
              ParentId   : Integer  (ID du namespace parent)
              FileName   : String   (fichier de definition)
              Line       : Integer  (ligne de debut)
              EndLine    : Integer  (ligne de fin)
              IsAnonymous: Boolean  (namespace anonyme)
              IsInline   : Boolean  (inline namespace C++11)
              Language   : String   (langage source)
            End
            TModule : record
              Name       : String   (nom du module)
              FileName   : String   (fichier source)
              Exports    : String   (liste des exports)
              Imports    : String   (liste des imports)
              IsPartition: Boolean  (partition de module)
              IsInterface: Boolean  (module interface)
              Line       : Integer  (ligne de declaration)
            End
            Variables globales :
              Namespaces     : Array[1..MAX_NAMESPACES] Of TNamespace
              NamespaceCount : Integer
              Modules        : Array[1..MAX_MODULES] Of TModule
              ModuleCount    : Integer
              NamespaceStack, NamespaceStackDepth, NamespacesInitialized
            Constantes : MAX_NAMESPACES, MAX_MODULES, MAX_NS_DEPTH,
              NS_KEYWORD_CPP, NS_KEYWORD_CSHARP, NS_KEYWORD_JAVA,
              NS_KEYWORD_ADA, NS_KEYWORD_PASCAL, MOD_KEYWORD_CPP20,
              MOD_KEYWORD_EXPORT, MOD_KEYWORD_IMPORT
            Procedure InitNamespaces : initialiser le systeme
            Function FindNamespace : chercher un namespace par nom complet
            Function FindNamespaceByName : chercher par nom simple
            Function AddNamespace : ajouter un namespace
            Function FindModule : chercher un module par nom
            Function AddModule : ajouter un module
            Procedure AddModuleExport/AddModuleImport : gerer exports/imports
            Procedure Push/PopNamespace, GetCurrentNamespace : pile de contexte
            Function BuildFullNamespaceName : construire le nom complet
            Function ExtractCppNamespaceName : extraire namespace C++
            Function ExtractJavaPackageName : extraire package Java
            Function ExtractCSharpNamespaceName : extraire namespace C#
            Function ExtractAdaPackageName : extraire package Ada
            Function ExtractCpp20ModuleName : extraire module C++20
            Function ExtractCpp20Import : extraire import C++20
            Procedure ExtractNamespaces(Const FileName: String;
              Lang: TSourceLanguage) : extraire les declarations
            Procedure BuildNamespaceHierarchy : construire la hierarchie
            Function GetNamespaceEntities(NamespaceId: Integer): String
              retourner les entites declarees dans un namespace
            Fonctions accesseurs : GetNamespaceCount, GetModuleCount,
              IsNamespacesInitialized, IsNamespacesEmpty, IsModulesEmpty,
              GetNamespaceByIndex, GetModuleByIndex, IsValidNamespaceIndex,
              IsValidModuleIndex, GetNamespaceName, GetNamespaceFullName,
              GetNamespaceFileName, GetNamespaceLine, GetNamespaceParent,
              IsNamespaceAnonymous, IsNamespaceInline, GetModuleName,
              GetModuleFileName, GetModuleExports, GetModuleImports,
              IsModulePartition, IsModuleInterface, CountChildNamespaces,
              CountRootNamespaces, CountNamespacesByLanguage
            Procedure ShowNamespaces, ShowModules : affichage debug

  TODO 22 - RECHERCHE ET INDEXATION FULL-TEXT [IMPLEMENTE]
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

  TODO 23 - SUPPORT MULTI-FICHIERS ET RECURSIVITE [IMPLEMENTE]
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

  TODO 24 - VALIDATION ET AVERTISSEMENTS [IMPLEMENTE]
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
              ValidationInitialized : Boolean
            Procedure InitValidation
              initialiser le systeme de validation
            Procedure WarningKindName(Kind: TWarningKind): String
              retourner le nom d un type d avertissement
            Procedure WarningKindDescription(Kind: TWarningKind): String
              retourner la description d un type d avertissement
            Procedure ReportWarning(Kind: TWarningKind;
              Const FileName: String; Line: Integer; Const Msg: String)
              enregistrer un avertissement
            Procedure ReportWarningForEntity(Kind: TWarningKind;
              Const FileName: String; Line: Integer;
              Const Msg: String; EntId: Integer)
              enregistrer un avertissement avec ID d entite
            Procedure ReportError(Const FileName: String; Line: Integer;
              Const Msg: String)
              enregistrer une erreur
            Function FindEntityByName(Const Name: String): Integer
              trouver une entite par son nom
            Function IsEntityDocumented(EntId: Integer): Boolean
              verifier si une entite est documentee
            Function IsEntityPublic(EntId: Integer): Boolean
              verifier si une entite est publique
            Procedure ValidateDocumentation
              verifier que toutes les entites publiques sont documentees
            Procedure ValidateLinks
              verifier que tous les @see et @ref pointent vers des
              entites existantes
            Procedure ValidateParams
              verifier la coherence des @param avec les parametres
            Procedure DisplayWarnings
              afficher tous les avertissements collectes
            Procedure DisplayWarningSummary
              afficher un resume des avertissements par type
            Function GetUndocumentedEntities: Integer
              retourner le nombre d entites non documentees
            Function GetDocumentedEntities: Integer
              retourner le nombre d entites documentees
            Function GetDocumentationCoverage: Real
              retourner le pourcentage de couverture
            Fonctions accesseur (10+):
              GetWarningCount, GetErrorCount, GetWarning,
              IsValidationInitialized, IsValidationClean,
              CountWarningsOfKind, CountWarningsForFile,
              CountWarningsForEntity, ClearWarnings,
              RunAllValidations, ShowValidationStatus

  TODO 25 - RAPPORT FINAL ET STATISTIQUES DE COUVERTURE [IMPLEMENTE]
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
  MAX_SEARCH_ENTRIES = 32767;
  MAX_WARNINGS       = 4096;

  { Constantes pour la generation HTML (TODO 12) }
  HTML_DOCTYPE       = '<!DOCTYPE html>';
  HTML_CHARSET       = 'UTF-8';
  HTML_CSS_FILE      = 'doxygen.css';
  HTML_JS_FILE       = 'doxygen.js';
  HTML_SEARCH_FILE   = 'search.js';
  HTML_INDEX_FILE    = 'index.html';
  HTML_CLASSES_FILE  = 'classes.html';
  HTML_FUNCTIONS_FILE = 'functions.html';
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
  CALLGRAPH_DOT_FILE    = 'callgraph.dot';
  CALLGRAPH_PNG_FILE    = 'callgraph.png';
  CALLGRAPH_SVG_FILE    = 'callgraph.svg';
  CALLGRAPH_OUTPUT_DIR  = 'callgraph';
  CALLGRAPH_NODE_SHAPE  = 'box';
  CALLGRAPH_EDGE_STYLE  = 'solid';
  CALLGRAPH_FONT_NAME   = 'Helvetica';
  CALLGRAPH_FONT_SIZE   = 10;

  { Constantes pour les graphes de dependances (TODO 18) }
  DEPGRAPH_OUTPUT_DIR   = 'depgraph';
  DEPGRAPH_DOT_FILE     = 'dependencies.dot';
  DEPGRAPH_PNG_FILE     = 'dependencies.png';
  DEPGRAPH_SVG_FILE     = 'dependencies.svg';
  DEPGRAPH_INC_PREFIX   = 'include_';
  DEPGRAPH_INCBY_PREFIX = 'included_by_';
  DEPGRAPH_DIR_PREFIX   = 'directory_';
  DEPGRAPH_MOD_PREFIX   = 'module_';
  DEPGRAPH_NODE_SHAPE   = 'box';
  DEPGRAPH_DIR_SHAPE    = 'folder';
  DEPGRAPH_EDGE_STYLE   = 'solid';
  DEPGRAPH_FONT_NAME    = 'Helvetica';
  DEPGRAPH_FONT_SIZE    = 10;
  DEPGRAPH_INCLUDE_COLOR = '#4CAF50';
  DEPGRAPH_LOCAL_COLOR   = '#2196F3';
  DEPGRAPH_SYSTEM_COLOR  = '#9E9E9E';
  MAX_DEP_DIRS          = 256;

  { Constantes pour les diagrammes de classes (TODO 19) }
  CLASSDIAG_OUTPUT_DIR   = 'classdiag';
  CLASSDIAG_DOT_FILE     = 'class.dot';
  CLASSDIAG_PNG_FILE     = 'class.png';
  CLASSDIAG_SVG_FILE     = 'class.svg';
  CLASSDIAG_CLASS_PREFIX = 'class_';
  CLASSDIAG_COLLAB_PREFIX = 'collab_';
  CLASSDIAG_INHERIT_PREFIX = 'inherit_';
  CLASSDIAG_UML_PREFIX   = 'uml_';
  CLASSDIAG_NODE_SHAPE   = 'record';
  CLASSDIAG_UML_SHAPE    = 'rectangle';
  CLASSDIAG_EDGE_INHERIT = 'onormal';
  CLASSDIAG_EDGE_COMPOSE = 'diamond';
  CLASSDIAG_EDGE_AGGREG  = 'odiamond';
  CLASSDIAG_EDGE_ASSOC   = 'vee';
  CLASSDIAG_FONT_NAME    = 'Helvetica';
  CLASSDIAG_FONT_SIZE    = 10;
  CLASSDIAG_PUBLIC_COLOR = '#27AE60';
  CLASSDIAG_PROTECTED_COLOR = '#F39C12';
  CLASSDIAG_PRIVATE_COLOR = '#E74C3C';
  CLASSDIAG_CLASS_COLOR  = '#3498DB';
  CLASSDIAG_ABSTRACT_COLOR = '#9B59B6';
  CLASSDIAG_INTERFACE_COLOR = '#1ABC9C';
  CLASSDIAG_MAX_MEMBERS  = 50;
  CLASSDIAG_PLANTUML_START = '@startuml';
  CLASSDIAG_PLANTUML_END = '@enduml';

  { Constantes pour les macros et preprocesseur (TODO 20) }
  MAX_MACRO_PARAMS      = 32;
  MAX_MACRO_VALUE       = 4096;
  MAX_INCLUDE_STACK     = 64;
  MACRO_PREFIX_DEFINE   = '#define';
  MACRO_PREFIX_UNDEF    = '#undef';
  MACRO_PREFIX_IF       = '#if';
  MACRO_PREFIX_IFDEF    = '#ifdef';
  MACRO_PREFIX_IFNDEF   = '#ifndef';
  MACRO_PREFIX_ELSE     = '#else';
  MACRO_PREFIX_ELIF     = '#elif';
  MACRO_PREFIX_ENDIF    = '#endif';
  MACRO_PREFIX_INCLUDE  = '#include';
  MACRO_PREFIX_PRAGMA   = '#pragma';
  MACRO_PREFIX_ERROR    = '#error';
  MACRO_PREFIX_WARNING  = '#warning';
  MACRO_PREFIX_LINE     = '#line';

  { Constantes pour les espaces de noms et modules (TODO 21) }
  MAX_NS_DEPTH          = 32;
  NS_KEYWORD_CPP        = 'namespace';
  NS_KEYWORD_CSHARP     = 'namespace';
  NS_KEYWORD_JAVA       = 'package';
  NS_KEYWORD_ADA        = 'package';
  NS_KEYWORD_PASCAL     = 'unit';
  MOD_KEYWORD_CPP20     = 'module';
  MOD_KEYWORD_EXPORT    = 'export';
  MOD_KEYWORD_IMPORT    = 'import';

  { Constantes pour la recherche et indexation (TODO 22) }
  SEARCH_MIN_WORD_LEN   = 2;    { Longueur minimale d'un mot a indexer }
  SEARCH_MAX_WORD_LEN   = 50;   { Longueur maximale d'un mot a indexer }
  SEARCH_MAX_RESULTS    = 100;  { Nombre max de resultats de recherche }
  SEARCH_INDEX_FILE     = 'search.js';
  SEARCH_DATA_FILE      = 'searchdata.js';
  SEARCH_HTML_FILE      = 'search.html';
  SEARCH_SCORE_TITLE    = 100;  { Score pour match dans le titre }
  SEARCH_SCORE_NAME     = 80;   { Score pour match dans le nom }
  SEARCH_SCORE_BRIEF    = 60;   { Score pour match dans le brief }
  SEARCH_SCORE_DETAIL   = 40;   { Score pour match dans les details }
  SEARCH_SCORE_PARAM    = 20;   { Score pour match dans les parametres }

  { Constantes pour le generateur PNG integre (sans outil externe) }
  PNG_SIGNATURE_1       = $89;       { Signature PNG byte 1 }
  PNG_SIGNATURE_2       = $50;       { Signature PNG byte 2 (P) }
  PNG_SIGNATURE_3       = $4E;       { Signature PNG byte 3 (N) }
  PNG_SIGNATURE_4       = $47;       { Signature PNG byte 4 (G) }
  PNG_SIGNATURE_5       = $0D;       { Signature PNG byte 5 (CR) }
  PNG_SIGNATURE_6       = $0A;       { Signature PNG byte 6 (LF) }
  PNG_SIGNATURE_7       = $1A;       { Signature PNG byte 7 (SUB) }
  PNG_SIGNATURE_8       = $0A;       { Signature PNG byte 8 (LF) }
  PNG_COLOR_RGB         = 2;         { Mode couleur RGB }
  PNG_COLOR_RGBA        = 6;         { Mode couleur RGBA }
  PNG_COLOR_INDEXED     = 3;         { Mode couleur indexe }
  PNG_FILTER_NONE       = 0;         { Filtre: aucun }
  PNG_FILTER_SUB        = 1;         { Filtre: sub }
  PNG_FILTER_UP         = 2;         { Filtre: up }
  PNG_COMPRESSION       = 0;         { Compression zlib }
  PNG_INTERLACE_NONE    = 0;         { Pas d'entrelacement }
  PNG_MAX_WIDTH         = 1024;      { Largeur maximale }
  PNG_MAX_HEIGHT        = 1024;      { Hauteur maximale }
  PNG_DEFAULT_WIDTH     = 400;       { Largeur par defaut }
  PNG_DEFAULT_HEIGHT    = 300;       { Hauteur par defaut }
  PNG_NODE_WIDTH        = 120;       { Largeur d'un noeud }
  PNG_NODE_HEIGHT       = 40;        { Hauteur d'un noeud }
  PNG_NODE_MARGIN       = 30;        { Marge entre les noeuds }
  PNG_FONT_WIDTH        = 7;         { Largeur approximative d'un caractere }
  PNG_FONT_HEIGHT       = 12;        { Hauteur approximative d'un caractere }
  MAX_PNG_NODES         = 256;       { Nombre max de noeuds dans un graphe }
  MAX_PNG_EDGES         = 512;       { Nombre max d'aretes dans un graphe }

  { Constantes pour le generateur SVG integre (sans outil externe) }
  SVG_DEFAULT_WIDTH     = 800;       { Largeur par defaut }
  SVG_DEFAULT_HEIGHT    = 600;       { Hauteur par defaut }
  SVG_NODE_WIDTH        = 120;       { Largeur d'un noeud }
  SVG_NODE_HEIGHT       = 40;        { Hauteur d'un noeud }
  SVG_NODE_MARGIN       = 30;        { Marge entre les noeuds }
  SVG_FONT_SIZE         = 12;        { Taille de police }
  SVG_FONT_FAMILY       = 'Arial, sans-serif';  { Police }
  SVG_ARROW_SIZE        = 8;         { Taille de la pointe de fleche }
  MAX_SVG_NODES         = 256;       { Nombre max de noeuds dans un graphe }
  MAX_SVG_EDGES         = 512;       { Nombre max d'aretes dans un graphe }

  { Constantes pour le generateur Visio VDX integre (sans outil externe) }
  VDX_DEFAULT_WIDTH     = 8.5;       { Largeur page en pouces (Letter) }
  VDX_DEFAULT_HEIGHT    = 11.0;      { Hauteur page en pouces (Letter) }
  VDX_NODE_WIDTH        = 1.5;       { Largeur d'un noeud en pouces }
  VDX_NODE_HEIGHT       = 0.5;       { Hauteur d'un noeud en pouces }
  VDX_NODE_MARGIN       = 0.4;       { Marge entre les noeuds en pouces }
  VDX_FONT_SIZE         = 10;        { Taille de police en points }
  VDX_ARROW_SIZE        = 0.1;       { Taille de la pointe de fleche en pouces }
  MAX_VDX_NODES         = 256;       { Nombre max de noeuds dans un graphe }
  MAX_VDX_EDGES         = 512;       { Nombre max d'aretes dans un graphe }
  VDX_MASTER_RECT       = 1;         { ID Master pour rectangle }
  VDX_MASTER_CONNECTOR  = 2;         { ID Master pour connecteur }
  VDX_VERSION           = '11.0';    { Version Visio (2003+) }
  VDX_XMLNS             = 'http://schemas.microsoft.com/visio/2003/core';

  { ============================================================
    CONSTANTES JPEG - GENERATEUR INTEGRE (SANS OUTIL EXTERNE)
    Partie 1: Marqueurs JPEG
    ============================================================ }
  
  { Marqueurs JPEG standard (tous commencent par $FF) }
  JPEG_MARKER_PREFIX    = $FF;       { Prefixe de tous les marqueurs JPEG }
  
  { Marqueurs de debut et fin d'image }
  JPEG_SOI              = $D8;       { Start Of Image - debut de l'image }
  JPEG_EOI              = $D9;       { End Of Image - fin de l'image }
  
  { Marqueurs de segment d'application (APP0-APP15: $E0-$EF) }
  JPEG_APP0             = $E0;       { Application segment 0 (JFIF) }
  JPEG_APP1             = $E1;       { Application segment 1 (EXIF) }
  JPEG_APP2             = $E2;       { Application segment 2 (ICC Profile) }
  JPEG_APP13            = $ED;       { Application segment 13 (Photoshop) }
  JPEG_APP14            = $EE;       { Application segment 14 (Adobe) }
  
  { Marqueurs de definition des tables }
  JPEG_DQT              = $DB;       { Define Quantization Table(s) }
  JPEG_DHT              = $C4;       { Define Huffman Table(s) }
  JPEG_DAC              = $CC;       { Define Arithmetic Coding }
  
  { Marqueurs de cadre (Start Of Frame) }
  JPEG_SOF0             = $C0;       { Baseline DCT }
  JPEG_SOF1             = $C1;       { Extended sequential DCT }
  JPEG_SOF2             = $C2;       { Progressive DCT }
  JPEG_SOF3             = $C3;       { Lossless (sequential) }
  JPEG_SOF5             = $C5;       { Differential sequential DCT }
  JPEG_SOF6             = $C6;       { Differential progressive DCT }
  JPEG_SOF7             = $C7;       { Differential lossless (sequential) }
  JPEG_SOF9             = $C9;       { Extended sequential DCT, arithmetic }
  JPEG_SOF10            = $CA;       { Progressive DCT, arithmetic }
  JPEG_SOF11            = $CB;       { Lossless (sequential), arithmetic }
  JPEG_SOF13            = $CD;       { Differential sequential DCT, arithmetic }
  JPEG_SOF14            = $CE;       { Differential progressive DCT, arithmetic }
  JPEG_SOF15            = $CF;       { Differential lossless, arithmetic }
  
  { Marqueurs de scan et restart }
  JPEG_SOS              = $DA;       { Start Of Scan - debut des donnees image }
  JPEG_RST0             = $D0;       { Restart marker 0 }
  JPEG_RST1             = $D1;       { Restart marker 1 }
  JPEG_RST2             = $D2;       { Restart marker 2 }
  JPEG_RST3             = $D3;       { Restart marker 3 }
  JPEG_RST4             = $D4;       { Restart marker 4 }
  JPEG_RST5             = $D5;       { Restart marker 5 }
  JPEG_RST6             = $D6;       { Restart marker 6 }
  JPEG_RST7             = $D7;       { Restart marker 7 }
  JPEG_DRI              = $DD;       { Define Restart Interval }
  
  { Marqueurs divers }
  JPEG_DNL              = $DC;       { Define Number of Lines }
  JPEG_DHP              = $DE;       { Define Hierarchical Progression }
  JPEG_EXP              = $DF;       { Expand Reference Component(s) }
  JPEG_COM              = $FE;       { Comment - commentaire }
  JPEG_TEM              = $01;       { For temporary private use }
  
  { Constantes JFIF (APP0) }
  JFIF_IDENTIFIER       = 'JFIF';    { Identificateur JFIF }
  JFIF_VERSION_MAJOR    = 1;         { Version majeure JFIF }
  JFIF_VERSION_MINOR    = 1;         { Version mineure JFIF (1.01 ou 1.02) }
  JFIF_UNITS_NONE       = 0;         { Pas d'unite (rapport d'aspect) }
  JFIF_UNITS_DPI        = 1;         { Dots per inch }
  JFIF_UNITS_DPCM       = 2;         { Dots per centimeter }
  JFIF_DEFAULT_XDENSITY = 72;        { Densite X par defaut (72 DPI) }
  JFIF_DEFAULT_YDENSITY = 72;        { Densite Y par defaut (72 DPI) }
  
  { Limites et constantes de dimensions JPEG }
  JPEG_MAX_WIDTH        = 65535;     { Largeur maximale (16 bits) }
  JPEG_MAX_HEIGHT       = 65535;     { Hauteur maximale (16 bits) }
  JPEG_BLOCK_SIZE       = 8;         { Taille d'un bloc DCT (8x8) }
  JPEG_BLOCK_SIZE_SQ    = 64;        { 8 * 8 = 64 coefficients par bloc }
  JPEG_MAX_COMPONENTS   = 4;         { Nombre max de composantes (Y,Cb,Cr,K) }
  JPEG_MAX_QUANT_TABLES = 4;         { Nombre max de tables de quantification }
  JPEG_MAX_HUFF_TABLES  = 4;         { Nombre max de tables Huffman (2 DC + 2 AC) }
  
  { Types de tables Huffman }
  JPEG_HUFF_DC          = 0;         { Table Huffman DC }
  JPEG_HUFF_AC          = 1;         { Table Huffman AC }
  
  { Identificateurs de composantes couleur }
  JPEG_COMP_Y           = 1;         { Composante luminance Y }
  JPEG_COMP_CB          = 2;         { Composante chrominance Cb (bleu) }
  JPEG_COMP_CR          = 3;         { Composante chrominance Cr (rouge) }
  JPEG_COMP_K           = 4;         { Composante noire K (CMYK) }
  
  { Facteurs d'echantillonnage courants }
  JPEG_SAMPLE_444       = 1;         { Pas de sous-echantillonnage (4:4:4) }
  JPEG_SAMPLE_422_H     = 2;         { Sous-echantillonnage horizontal 4:2:2 }
  JPEG_SAMPLE_420       = 2;         { Sous-echantillonnage 4:2:0 (H et V) }
  
  { Qualites JPEG predefinies }
  JPEG_QUALITY_LOW      = 25;        { Qualite basse (forte compression) }
  JPEG_QUALITY_MEDIUM   = 50;        { Qualite moyenne }
  JPEG_QUALITY_HIGH     = 75;        { Qualite haute }
  JPEG_QUALITY_BEST     = 95;        { Meilleure qualite (faible compression) }
  JPEG_QUALITY_DEFAULT  = 75;        { Qualite par defaut }
  JPEG_QUALITY_MIN      = 1;         { Qualite minimale }
  JPEG_QUALITY_MAX      = 100;       { Qualite maximale }
  
  { Constantes pour la generation de graphes en JPEG }
  JPEG_DEFAULT_WIDTH    = 800;       { Largeur par defaut pour les graphes }
  JPEG_DEFAULT_HEIGHT   = 600;       { Hauteur par defaut pour les graphes }
  JPEG_NODE_WIDTH       = 120;       { Largeur d'un noeud }
  JPEG_NODE_HEIGHT      = 40;        { Hauteur d'un noeud }
  JPEG_NODE_MARGIN      = 30;        { Marge entre les noeuds }
  JPEG_FONT_WIDTH       = 7;         { Largeur approximative d'un caractere }
  JPEG_FONT_HEIGHT      = 12;        { Hauteur approximative d'un caractere }
  MAX_JPEG_NODES        = 256;       { Nombre max de noeuds dans un graphe }
  MAX_JPEG_EDGES        = 512;       { Nombre max d'aretes dans un graphe }

  { ============================================================
    CONSTANTES JPEG - GENERATEUR INTEGRE (SANS OUTIL EXTERNE)
    Partie 2: Tables de quantification 8x8
    ============================================================ }
  
  { Table de quantification standard pour la LUMINANCE (Y)
    Issue de la norme JPEG (ITU-T T.81 / ISO/IEC 10918-1)
    Organisee en ordre ligne par ligne (row-major order)
    Ces valeurs correspondent a une qualite de 50% }
    
  { Luminance - Ligne 0 }
  JPEG_QL_00 = 16;   JPEG_QL_01 = 11;   JPEG_QL_02 = 10;   JPEG_QL_03 = 16;
  JPEG_QL_04 = 24;   JPEG_QL_05 = 40;   JPEG_QL_06 = 51;   JPEG_QL_07 = 61;
  { Luminance - Ligne 1 }
  JPEG_QL_08 = 12;   JPEG_QL_09 = 12;   JPEG_QL_10 = 14;   JPEG_QL_11 = 19;
  JPEG_QL_12 = 26;   JPEG_QL_13 = 58;   JPEG_QL_14 = 60;   JPEG_QL_15 = 55;
  { Luminance - Ligne 2 }
  JPEG_QL_16 = 14;   JPEG_QL_17 = 13;   JPEG_QL_18 = 16;   JPEG_QL_19 = 24;
  JPEG_QL_20 = 40;   JPEG_QL_21 = 57;   JPEG_QL_22 = 69;   JPEG_QL_23 = 56;
  { Luminance - Ligne 3 }
  JPEG_QL_24 = 14;   JPEG_QL_25 = 17;   JPEG_QL_26 = 22;   JPEG_QL_27 = 29;
  JPEG_QL_28 = 51;   JPEG_QL_29 = 87;   JPEG_QL_30 = 80;   JPEG_QL_31 = 62;
  { Luminance - Ligne 4 }
  JPEG_QL_32 = 18;   JPEG_QL_33 = 22;   JPEG_QL_34 = 37;   JPEG_QL_35 = 56;
  JPEG_QL_36 = 68;   JPEG_QL_37 = 109;  JPEG_QL_38 = 103;  JPEG_QL_39 = 77;
  { Luminance - Ligne 5 }
  JPEG_QL_40 = 24;   JPEG_QL_41 = 35;   JPEG_QL_42 = 55;   JPEG_QL_43 = 64;
  JPEG_QL_44 = 81;   JPEG_QL_45 = 104;  JPEG_QL_46 = 113;  JPEG_QL_47 = 92;
  { Luminance - Ligne 6 }
  JPEG_QL_48 = 49;   JPEG_QL_49 = 64;   JPEG_QL_50 = 78;   JPEG_QL_51 = 87;
  JPEG_QL_52 = 103;  JPEG_QL_53 = 121;  JPEG_QL_54 = 120;  JPEG_QL_55 = 101;
  { Luminance - Ligne 7 }
  JPEG_QL_56 = 72;   JPEG_QL_57 = 92;   JPEG_QL_58 = 95;   JPEG_QL_59 = 98;
  JPEG_QL_60 = 112;  JPEG_QL_61 = 100;  JPEG_QL_62 = 103;  JPEG_QL_63 = 99;
  
  { Table de quantification standard pour la CHROMINANCE (Cb, Cr)
    Issue de la norme JPEG (ITU-T T.81 / ISO/IEC 10918-1)
    La chrominance peut etre plus compressée car l'oeil est
    moins sensible aux variations de couleur
    Ces valeurs correspondent a une qualite de 50% }
  
  { Chrominance - Ligne 0 }
  JPEG_QC_00 = 17;   JPEG_QC_01 = 18;   JPEG_QC_02 = 24;   JPEG_QC_03 = 47;
  JPEG_QC_04 = 99;   JPEG_QC_05 = 99;   JPEG_QC_06 = 99;   JPEG_QC_07 = 99;
  { Chrominance - Ligne 1 }
  JPEG_QC_08 = 18;   JPEG_QC_09 = 21;   JPEG_QC_10 = 26;   JPEG_QC_11 = 66;
  JPEG_QC_12 = 99;   JPEG_QC_13 = 99;   JPEG_QC_14 = 99;   JPEG_QC_15 = 99;
  { Chrominance - Ligne 2 }
  JPEG_QC_16 = 24;   JPEG_QC_17 = 26;   JPEG_QC_18 = 56;   JPEG_QC_19 = 99;
  JPEG_QC_20 = 99;   JPEG_QC_21 = 99;   JPEG_QC_22 = 99;   JPEG_QC_23 = 99;
  { Chrominance - Ligne 3 }
  JPEG_QC_24 = 47;   JPEG_QC_25 = 66;   JPEG_QC_26 = 99;   JPEG_QC_27 = 99;
  JPEG_QC_28 = 99;   JPEG_QC_29 = 99;   JPEG_QC_30 = 99;   JPEG_QC_31 = 99;
  { Chrominance - Ligne 4 }
  JPEG_QC_32 = 99;   JPEG_QC_33 = 99;   JPEG_QC_34 = 99;   JPEG_QC_35 = 99;
  JPEG_QC_36 = 99;   JPEG_QC_37 = 99;   JPEG_QC_38 = 99;   JPEG_QC_39 = 99;
  { Chrominance - Ligne 5 }
  JPEG_QC_40 = 99;   JPEG_QC_41 = 99;   JPEG_QC_42 = 99;   JPEG_QC_43 = 99;
  JPEG_QC_44 = 99;   JPEG_QC_45 = 99;   JPEG_QC_46 = 99;   JPEG_QC_47 = 99;
  { Chrominance - Ligne 6 }
  JPEG_QC_48 = 99;   JPEG_QC_49 = 99;   JPEG_QC_50 = 99;   JPEG_QC_51 = 99;
  JPEG_QC_52 = 99;   JPEG_QC_53 = 99;   JPEG_QC_54 = 99;   JPEG_QC_55 = 99;
  { Chrominance - Ligne 7 }
  JPEG_QC_56 = 99;   JPEG_QC_57 = 99;   JPEG_QC_58 = 99;   JPEG_QC_59 = 99;
  JPEG_QC_60 = 99;   JPEG_QC_61 = 99;   JPEG_QC_62 = 99;   JPEG_QC_63 = 99;
  
  { Ordre de parcours zigzag pour les coefficients DCT 8x8
    Utilise pour convertir de l'ordre matriciel vers l'ordre
    lineaire lors de l'encodage/decodage JPEG }
  
  { Zigzag - Indices 0-7 }
  JPEG_ZZ_00 = 0;   JPEG_ZZ_01 = 1;   JPEG_ZZ_02 = 8;   JPEG_ZZ_03 = 16;
  JPEG_ZZ_04 = 9;   JPEG_ZZ_05 = 2;   JPEG_ZZ_06 = 3;   JPEG_ZZ_07 = 10;
  { Zigzag - Indices 8-15 }
  JPEG_ZZ_08 = 17;  JPEG_ZZ_09 = 24;  JPEG_ZZ_10 = 32;  JPEG_ZZ_11 = 25;
  JPEG_ZZ_12 = 18;  JPEG_ZZ_13 = 11;  JPEG_ZZ_14 = 4;   JPEG_ZZ_15 = 5;
  { Zigzag - Indices 16-23 }
  JPEG_ZZ_16 = 12;  JPEG_ZZ_17 = 19;  JPEG_ZZ_18 = 26;  JPEG_ZZ_19 = 33;
  JPEG_ZZ_20 = 40;  JPEG_ZZ_21 = 48;  JPEG_ZZ_22 = 41;  JPEG_ZZ_23 = 34;
  { Zigzag - Indices 24-31 }
  JPEG_ZZ_24 = 27;  JPEG_ZZ_25 = 20;  JPEG_ZZ_26 = 13;  JPEG_ZZ_27 = 6;
  JPEG_ZZ_28 = 7;   JPEG_ZZ_29 = 14;  JPEG_ZZ_30 = 21;  JPEG_ZZ_31 = 28;
  { Zigzag - Indices 32-39 }
  JPEG_ZZ_32 = 35;  JPEG_ZZ_33 = 42;  JPEG_ZZ_34 = 49;  JPEG_ZZ_35 = 56;
  JPEG_ZZ_36 = 57;  JPEG_ZZ_37 = 50;  JPEG_ZZ_38 = 43;  JPEG_ZZ_39 = 36;
  { Zigzag - Indices 40-47 }
  JPEG_ZZ_40 = 29;  JPEG_ZZ_41 = 22;  JPEG_ZZ_42 = 15;  JPEG_ZZ_43 = 23;
  JPEG_ZZ_44 = 30;  JPEG_ZZ_45 = 37;  JPEG_ZZ_46 = 44;  JPEG_ZZ_47 = 51;
  { Zigzag - Indices 48-55 }
  JPEG_ZZ_48 = 58;  JPEG_ZZ_49 = 59;  JPEG_ZZ_50 = 52;  JPEG_ZZ_51 = 45;
  JPEG_ZZ_52 = 38;  JPEG_ZZ_53 = 31;  JPEG_ZZ_54 = 39;  JPEG_ZZ_55 = 46;
  { Zigzag - Indices 56-63 }
  JPEG_ZZ_56 = 53;  JPEG_ZZ_57 = 60;  JPEG_ZZ_58 = 61;  JPEG_ZZ_59 = 54;
  JPEG_ZZ_60 = 47;  JPEG_ZZ_61 = 55;  JPEG_ZZ_62 = 62;  JPEG_ZZ_63 = 63;
  
  { Facteurs d'echelle pour ajuster la qualite JPEG
    La qualite Q (1-100) est convertie en facteur d'echelle S:
    - Si Q < 50: S = 5000 / Q
    - Si Q >= 50: S = 200 - 2 * Q
    Puis chaque valeur de quantification est: (BaseValue * S + 50) / 100 }
  
  JPEG_QUALITY_SCALE_LOW  = 50;      { Seuil pour calcul du facteur d'echelle }
  JPEG_QUALITY_FACTOR_50  = 100;     { Facteur d'echelle a qualite 50% }
  JPEG_QUANT_MIN_VALUE    = 1;       { Valeur minimale de quantification }
  JPEG_QUANT_MAX_VALUE    = 255;     { Valeur maximale de quantification (8 bits) }
  
  { Indices des tables de quantification dans le fichier JPEG }
  JPEG_QUANT_TABLE_Y      = 0;       { Table 0 pour luminance }
  JPEG_QUANT_TABLE_C      = 1;       { Table 1 pour chrominance }

{ ============================================================
  CONSTANTES JPEG - GENERATEUR INTEGRE (SANS OUTIL EXTERNE)
  Partie 3: Tables de Huffman DC et AC pour Y et CbCr
  ============================================================ }

{ Les tables de Huffman sont utilisees pour l'encodage entropique
  dans JPEG. Il y a 4 tables au total:
  - 2 tables DC (coefficients continus): 1 pour Y, 1 pour CbCr
  - 2 tables AC (coefficients alternatifs): 1 pour Y, 1 pour CbCr
  
  Chaque table est definie par:
  - BITS[16]: nombre de codes de chaque longueur (1-16 bits)
  - HUFFVAL[n]: valeurs associees aux codes Huffman
  
  Ces tables sont issues de la norme JPEG (ITU-T T.81 / Annex K) }

{ ============================================================
  TABLE HUFFMAN DC LUMINANCE (Y) - Table 0
  BITS: nombre de codes Huffman de longueur 1 a 16 bits
  ============================================================ }

{ DC Luminance BITS - 16 valeurs indiquant le nombre de codes par longueur }
  JPEG_DC_LUM_BITS_00 = 0;      { Indice 0 non utilise (compatibilite) }
  JPEG_DC_LUM_BITS_01 = 0;      { Codes de 1 bit: 0 }
  JPEG_DC_LUM_BITS_02 = 1;      { Codes de 2 bits: 1 }
  JPEG_DC_LUM_BITS_03 = 5;      { Codes de 3 bits: 5 }
  JPEG_DC_LUM_BITS_04 = 1;      { Codes de 4 bits: 1 }
  JPEG_DC_LUM_BITS_05 = 1;      { Codes de 5 bits: 1 }
  JPEG_DC_LUM_BITS_06 = 1;      { Codes de 6 bits: 1 }
  JPEG_DC_LUM_BITS_07 = 1;      { Codes de 7 bits: 1 }
  JPEG_DC_LUM_BITS_08 = 1;      { Codes de 8 bits: 1 }
  JPEG_DC_LUM_BITS_09 = 1;      { Codes de 9 bits: 1 }
  JPEG_DC_LUM_BITS_10 = 0;      { Codes de 10 bits: 0 }
  JPEG_DC_LUM_BITS_11 = 0;      { Codes de 11 bits: 0 }
  JPEG_DC_LUM_BITS_12 = 0;      { Codes de 12 bits: 0 }
  JPEG_DC_LUM_BITS_13 = 0;      { Codes de 13 bits: 0 }
  JPEG_DC_LUM_BITS_14 = 0;      { Codes de 14 bits: 0 }
  JPEG_DC_LUM_BITS_15 = 0;      { Codes de 15 bits: 0 }
  JPEG_DC_LUM_BITS_16 = 0;      { Codes de 16 bits: 0 }
  
{ DC Luminance HUFFVAL - Valeurs pour les 12 categories (0-11) }
{ Total: 0+1+5+1+1+1+1+1+1 = 12 valeurs }
  JPEG_DC_LUM_VAL_00 = 0;       { Categorie 0: difference DC = 0 }
  JPEG_DC_LUM_VAL_01 = 1;       { Categorie 1: diff DC -1,1 }
  JPEG_DC_LUM_VAL_02 = 2;       { Categorie 2: diff DC -3..-2,2..3 }
  JPEG_DC_LUM_VAL_03 = 3;       { Categorie 3: diff DC -7..-4,4..7 }
  JPEG_DC_LUM_VAL_04 = 4;       { Categorie 4: diff DC -15..-8,8..15 }
  JPEG_DC_LUM_VAL_05 = 5;       { Categorie 5: diff DC -31..-16,16..31 }
  JPEG_DC_LUM_VAL_06 = 6;       { Categorie 6: diff DC -63..-32,32..63 }
  JPEG_DC_LUM_VAL_07 = 7;       { Categorie 7: diff DC -127..-64,64..127 }
  JPEG_DC_LUM_VAL_08 = 8;       { Categorie 8: diff DC -255..-128,128..255 }
  JPEG_DC_LUM_VAL_09 = 9;       { Categorie 9: diff DC -511..-256,256..511 }
  JPEG_DC_LUM_VAL_10 = 10;      { Categorie 10: diff DC -1023..-512,512..1023 }
  JPEG_DC_LUM_VAL_11 = 11;      { Categorie 11: diff DC -2047..-1024,1024..2047 }
  
  JPEG_DC_LUM_VAL_COUNT = 12;   { Nombre total de valeurs DC luminance }

{ ============================================================
  TABLE HUFFMAN DC CHROMINANCE (CbCr) - Table 1
  BITS: nombre de codes Huffman de longueur 1 a 16 bits
  ============================================================ }

{ DC Chrominance BITS - 16 valeurs indiquant le nombre de codes par longueur }
  JPEG_DC_CHR_BITS_00 = 0;      { Indice 0 non utilise (compatibilite) }
  JPEG_DC_CHR_BITS_01 = 0;      { Codes de 1 bit: 0 }
  JPEG_DC_CHR_BITS_02 = 3;      { Codes de 2 bits: 3 }
  JPEG_DC_CHR_BITS_03 = 1;      { Codes de 3 bits: 1 }
  JPEG_DC_CHR_BITS_04 = 1;      { Codes de 4 bits: 1 }
  JPEG_DC_CHR_BITS_05 = 1;      { Codes de 5 bits: 1 }
  JPEG_DC_CHR_BITS_06 = 1;      { Codes de 6 bits: 1 }
  JPEG_DC_CHR_BITS_07 = 1;      { Codes de 7 bits: 1 }
  JPEG_DC_CHR_BITS_08 = 1;      { Codes de 8 bits: 1 }
  JPEG_DC_CHR_BITS_09 = 1;      { Codes de 9 bits: 1 }
  JPEG_DC_CHR_BITS_10 = 1;      { Codes de 10 bits: 1 }
  JPEG_DC_CHR_BITS_11 = 0;      { Codes de 11 bits: 0 }
  JPEG_DC_CHR_BITS_12 = 0;      { Codes de 12 bits: 0 }
  JPEG_DC_CHR_BITS_13 = 0;      { Codes de 13 bits: 0 }
  JPEG_DC_CHR_BITS_14 = 0;      { Codes de 14 bits: 0 }
  JPEG_DC_CHR_BITS_15 = 0;      { Codes de 15 bits: 0 }
  JPEG_DC_CHR_BITS_16 = 0;      { Codes de 16 bits: 0 }
  
{ DC Chrominance HUFFVAL - Valeurs pour les 12 categories (0-11) }
{ Total: 0+3+1+1+1+1+1+1+1+1 = 12 valeurs }
  JPEG_DC_CHR_VAL_00 = 0;       { Categorie 0 }
  JPEG_DC_CHR_VAL_01 = 1;       { Categorie 1 }
  JPEG_DC_CHR_VAL_02 = 2;       { Categorie 2 }
  JPEG_DC_CHR_VAL_03 = 3;       { Categorie 3 }
  JPEG_DC_CHR_VAL_04 = 4;       { Categorie 4 }
  JPEG_DC_CHR_VAL_05 = 5;       { Categorie 5 }
  JPEG_DC_CHR_VAL_06 = 6;       { Categorie 6 }
  JPEG_DC_CHR_VAL_07 = 7;       { Categorie 7 }
  JPEG_DC_CHR_VAL_08 = 8;       { Categorie 8 }
  JPEG_DC_CHR_VAL_09 = 9;       { Categorie 9 }
  JPEG_DC_CHR_VAL_10 = 10;      { Categorie 10 }
  JPEG_DC_CHR_VAL_11 = 11;      { Categorie 11 }
  
  JPEG_DC_CHR_VAL_COUNT = 12;   { Nombre total de valeurs DC chrominance }

{ ============================================================
  TABLE HUFFMAN AC LUMINANCE (Y) - Table 0
  BITS: nombre de codes Huffman de longueur 1 a 16 bits
  ============================================================ }

{ AC Luminance BITS - 16 valeurs indiquant le nombre de codes par longueur }
  JPEG_AC_LUM_BITS_01 = 0;      { Codes de 1 bit: 0 }
  JPEG_AC_LUM_BITS_02 = 2;      { Codes de 2 bits: 2 }
  JPEG_AC_LUM_BITS_03 = 1;      { Codes de 3 bits: 1 }
  JPEG_AC_LUM_BITS_04 = 3;      { Codes de 4 bits: 3 }
  JPEG_AC_LUM_BITS_05 = 3;      { Codes de 5 bits: 3 }
  JPEG_AC_LUM_BITS_06 = 2;      { Codes de 6 bits: 2 }
  JPEG_AC_LUM_BITS_07 = 4;      { Codes de 7 bits: 4 }
  JPEG_AC_LUM_BITS_08 = 3;      { Codes de 8 bits: 3 }
  JPEG_AC_LUM_BITS_09 = 5;      { Codes de 9 bits: 5 }
  JPEG_AC_LUM_BITS_10 = 5;      { Codes de 10 bits: 5 }
  JPEG_AC_LUM_BITS_11 = 4;      { Codes de 11 bits: 4 }
  JPEG_AC_LUM_BITS_12 = 4;      { Codes de 12 bits: 4 }
  JPEG_AC_LUM_BITS_13 = 0;      { Codes de 13 bits: 0 }
  JPEG_AC_LUM_BITS_14 = 0;      { Codes de 14 bits: 0 }
  JPEG_AC_LUM_BITS_15 = 1;      { Codes de 15 bits: 1 }
  JPEG_AC_LUM_BITS_16 = 125;    { Codes de 16 bits: 125 }
  
{ AC Luminance HUFFVAL - 162 valeurs au total
  Format: RRRRSSSS ou RRRR=run de zeros (0-15), SSSS=taille (0-10)
  Valeurs speciales: $00=EOB (fin de bloc), $F0=ZRL (16 zeros) }

{ AC Luminance valeurs - Groupe 1 (indices 0-15) }
  JPEG_AC_LUM_VAL_000 = $01;    { Run=0, Size=1 }
  JPEG_AC_LUM_VAL_001 = $02;    { Run=0, Size=2 }
  JPEG_AC_LUM_VAL_002 = $03;    { Run=0, Size=3 }
  JPEG_AC_LUM_VAL_003 = $00;    { EOB - End Of Block }
  JPEG_AC_LUM_VAL_004 = $04;    { Run=0, Size=4 }
  JPEG_AC_LUM_VAL_005 = $11;    { Run=1, Size=1 }
  JPEG_AC_LUM_VAL_006 = $05;    { Run=0, Size=5 }
  JPEG_AC_LUM_VAL_007 = $12;    { Run=1, Size=2 }
  JPEG_AC_LUM_VAL_008 = $21;    { Run=2, Size=1 }
  JPEG_AC_LUM_VAL_009 = $31;    { Run=3, Size=1 }
  JPEG_AC_LUM_VAL_010 = $41;    { Run=4, Size=1 }
  JPEG_AC_LUM_VAL_011 = $06;    { Run=0, Size=6 }
  JPEG_AC_LUM_VAL_012 = $13;    { Run=1, Size=3 }
  JPEG_AC_LUM_VAL_013 = $51;    { Run=5, Size=1 }
  JPEG_AC_LUM_VAL_014 = $61;    { Run=6, Size=1 }
  JPEG_AC_LUM_VAL_015 = $07;    { Run=0, Size=7 }
  
{ AC Luminance valeurs - Groupe 2 (indices 16-31) }
  JPEG_AC_LUM_VAL_016 = $22;    { Run=2, Size=2 }
  JPEG_AC_LUM_VAL_017 = $71;    { Run=7, Size=1 }
  JPEG_AC_LUM_VAL_018 = $14;    { Run=1, Size=4 }
  JPEG_AC_LUM_VAL_019 = $32;    { Run=3, Size=2 }
  JPEG_AC_LUM_VAL_020 = $81;    { Run=8, Size=1 }
  JPEG_AC_LUM_VAL_021 = $91;    { Run=9, Size=1 }
  JPEG_AC_LUM_VAL_022 = $A1;    { Run=10, Size=1 }
  JPEG_AC_LUM_VAL_023 = $08;    { Run=0, Size=8 }
  JPEG_AC_LUM_VAL_024 = $23;    { Run=2, Size=3 }
  JPEG_AC_LUM_VAL_025 = $42;    { Run=4, Size=2 }
  JPEG_AC_LUM_VAL_026 = $B1;    { Run=11, Size=1 }
  JPEG_AC_LUM_VAL_027 = $C1;    { Run=12, Size=1 }
  JPEG_AC_LUM_VAL_028 = $15;    { Run=1, Size=5 }
  JPEG_AC_LUM_VAL_029 = $52;    { Run=5, Size=2 }
  JPEG_AC_LUM_VAL_030 = $D1;    { Run=13, Size=1 }
  JPEG_AC_LUM_VAL_031 = $F0;    { ZRL - Zero Run Length (16 zeros) }
  
{ AC Luminance valeurs - Groupe 3 (indices 32-47) }
  JPEG_AC_LUM_VAL_032 = $24;    { Run=2, Size=4 }
  JPEG_AC_LUM_VAL_033 = $33;    { Run=3, Size=3 }
  JPEG_AC_LUM_VAL_034 = $62;    { Run=6, Size=2 }
  JPEG_AC_LUM_VAL_035 = $72;    { Run=7, Size=2 }
  JPEG_AC_LUM_VAL_036 = $82;    { Run=8, Size=2 }
  JPEG_AC_LUM_VAL_037 = $09;    { Run=0, Size=9 }
  JPEG_AC_LUM_VAL_038 = $0A;    { Run=0, Size=10 }
  JPEG_AC_LUM_VAL_039 = $16;    { Run=1, Size=6 }
  JPEG_AC_LUM_VAL_040 = $17;    { Run=1, Size=7 }
  JPEG_AC_LUM_VAL_041 = $18;    { Run=1, Size=8 }
  JPEG_AC_LUM_VAL_042 = $19;    { Run=1, Size=9 }
  JPEG_AC_LUM_VAL_043 = $1A;    { Run=1, Size=10 }
  JPEG_AC_LUM_VAL_044 = $25;    { Run=2, Size=5 }
  JPEG_AC_LUM_VAL_045 = $26;    { Run=2, Size=6 }
  JPEG_AC_LUM_VAL_046 = $27;    { Run=2, Size=7 }
  JPEG_AC_LUM_VAL_047 = $28;    { Run=2, Size=8 }
  
{ AC Luminance valeurs - Groupe 4 (indices 48-63) }
  JPEG_AC_LUM_VAL_048 = $29;    { Run=2, Size=9 }
  JPEG_AC_LUM_VAL_049 = $2A;    { Run=2, Size=10 }
  JPEG_AC_LUM_VAL_050 = $34;    { Run=3, Size=4 }
  JPEG_AC_LUM_VAL_051 = $35;    { Run=3, Size=5 }
  JPEG_AC_LUM_VAL_052 = $36;    { Run=3, Size=6 }
  JPEG_AC_LUM_VAL_053 = $37;    { Run=3, Size=7 }
  JPEG_AC_LUM_VAL_054 = $38;    { Run=3, Size=8 }
  JPEG_AC_LUM_VAL_055 = $39;    { Run=3, Size=9 }
  JPEG_AC_LUM_VAL_056 = $3A;    { Run=3, Size=10 }
  JPEG_AC_LUM_VAL_057 = $43;    { Run=4, Size=3 }
  JPEG_AC_LUM_VAL_058 = $44;    { Run=4, Size=4 }
  JPEG_AC_LUM_VAL_059 = $45;    { Run=4, Size=5 }
  JPEG_AC_LUM_VAL_060 = $46;    { Run=4, Size=6 }
  JPEG_AC_LUM_VAL_061 = $47;    { Run=4, Size=7 }
  JPEG_AC_LUM_VAL_062 = $48;    { Run=4, Size=8 }
  JPEG_AC_LUM_VAL_063 = $49;    { Run=4, Size=9 }
  
{ AC Luminance valeurs - Groupe 5 (indices 64-79) }
  JPEG_AC_LUM_VAL_064 = $4A;    { Run=4, Size=10 }
  JPEG_AC_LUM_VAL_065 = $53;    { Run=5, Size=3 }
  JPEG_AC_LUM_VAL_066 = $54;    { Run=5, Size=4 }
  JPEG_AC_LUM_VAL_067 = $55;    { Run=5, Size=5 }
  JPEG_AC_LUM_VAL_068 = $56;    { Run=5, Size=6 }
  JPEG_AC_LUM_VAL_069 = $57;    { Run=5, Size=7 }
  JPEG_AC_LUM_VAL_070 = $58;    { Run=5, Size=8 }
  JPEG_AC_LUM_VAL_071 = $59;    { Run=5, Size=9 }
  JPEG_AC_LUM_VAL_072 = $5A;    { Run=5, Size=10 }
  JPEG_AC_LUM_VAL_073 = $63;    { Run=6, Size=3 }
  JPEG_AC_LUM_VAL_074 = $64;    { Run=6, Size=4 }
  JPEG_AC_LUM_VAL_075 = $65;    { Run=6, Size=5 }
  JPEG_AC_LUM_VAL_076 = $66;    { Run=6, Size=6 }
  JPEG_AC_LUM_VAL_077 = $67;    { Run=6, Size=7 }
  JPEG_AC_LUM_VAL_078 = $68;    { Run=6, Size=8 }
  JPEG_AC_LUM_VAL_079 = $69;    { Run=6, Size=9 }
  
{ AC Luminance valeurs - Groupe 6 (indices 80-95) }
  JPEG_AC_LUM_VAL_080 = $6A;    { Run=6, Size=10 }
  JPEG_AC_LUM_VAL_081 = $73;    { Run=7, Size=3 }
  JPEG_AC_LUM_VAL_082 = $74;    { Run=7, Size=4 }
  JPEG_AC_LUM_VAL_083 = $75;    { Run=7, Size=5 }
  JPEG_AC_LUM_VAL_084 = $76;    { Run=7, Size=6 }
  JPEG_AC_LUM_VAL_085 = $77;    { Run=7, Size=7 }
  JPEG_AC_LUM_VAL_086 = $78;    { Run=7, Size=8 }
  JPEG_AC_LUM_VAL_087 = $79;    { Run=7, Size=9 }
  JPEG_AC_LUM_VAL_088 = $7A;    { Run=7, Size=10 }
  JPEG_AC_LUM_VAL_089 = $83;    { Run=8, Size=3 }
  JPEG_AC_LUM_VAL_090 = $84;    { Run=8, Size=4 }
  JPEG_AC_LUM_VAL_091 = $85;    { Run=8, Size=5 }
  JPEG_AC_LUM_VAL_092 = $86;    { Run=8, Size=6 }
  JPEG_AC_LUM_VAL_093 = $87;    { Run=8, Size=7 }
  JPEG_AC_LUM_VAL_094 = $88;    { Run=8, Size=8 }
  JPEG_AC_LUM_VAL_095 = $89;    { Run=8, Size=9 }
  
{ AC Luminance valeurs - Groupe 7 (indices 96-111) }
  JPEG_AC_LUM_VAL_096 = $8A;    { Run=8, Size=10 }
  JPEG_AC_LUM_VAL_097 = $92;    { Run=9, Size=2 }
  JPEG_AC_LUM_VAL_098 = $93;    { Run=9, Size=3 }
  JPEG_AC_LUM_VAL_099 = $94;    { Run=9, Size=4 }
  JPEG_AC_LUM_VAL_100 = $95;    { Run=9, Size=5 }
  JPEG_AC_LUM_VAL_101 = $96;    { Run=9, Size=6 }
  JPEG_AC_LUM_VAL_102 = $97;    { Run=9, Size=7 }
  JPEG_AC_LUM_VAL_103 = $98;    { Run=9, Size=8 }
  JPEG_AC_LUM_VAL_104 = $99;    { Run=9, Size=9 }
  JPEG_AC_LUM_VAL_105 = $9A;    { Run=9, Size=10 }
  JPEG_AC_LUM_VAL_106 = $A2;    { Run=10, Size=2 }
  JPEG_AC_LUM_VAL_107 = $A3;    { Run=10, Size=3 }
  JPEG_AC_LUM_VAL_108 = $A4;    { Run=10, Size=4 }
  JPEG_AC_LUM_VAL_109 = $A5;    { Run=10, Size=5 }
  JPEG_AC_LUM_VAL_110 = $A6;    { Run=10, Size=6 }
  JPEG_AC_LUM_VAL_111 = $A7;    { Run=10, Size=7 }
  
{ AC Luminance valeurs - Groupe 8 (indices 112-127) }
  JPEG_AC_LUM_VAL_112 = $A8;    { Run=10, Size=8 }
  JPEG_AC_LUM_VAL_113 = $A9;    { Run=10, Size=9 }
  JPEG_AC_LUM_VAL_114 = $AA;    { Run=10, Size=10 }
  JPEG_AC_LUM_VAL_115 = $B2;    { Run=11, Size=2 }
  JPEG_AC_LUM_VAL_116 = $B3;    { Run=11, Size=3 }
  JPEG_AC_LUM_VAL_117 = $B4;    { Run=11, Size=4 }
  JPEG_AC_LUM_VAL_118 = $B5;    { Run=11, Size=5 }
  JPEG_AC_LUM_VAL_119 = $B6;    { Run=11, Size=6 }
  JPEG_AC_LUM_VAL_120 = $B7;    { Run=11, Size=7 }
  JPEG_AC_LUM_VAL_121 = $B8;    { Run=11, Size=8 }
  JPEG_AC_LUM_VAL_122 = $B9;    { Run=11, Size=9 }
  JPEG_AC_LUM_VAL_123 = $BA;    { Run=11, Size=10 }
  JPEG_AC_LUM_VAL_124 = $C2;    { Run=12, Size=2 }
  JPEG_AC_LUM_VAL_125 = $C3;    { Run=12, Size=3 }
  JPEG_AC_LUM_VAL_126 = $C4;    { Run=12, Size=4 }
  JPEG_AC_LUM_VAL_127 = $C5;    { Run=12, Size=5 }
  
{ AC Luminance valeurs - Groupe 9 (indices 128-143) }
  JPEG_AC_LUM_VAL_128 = $C6;    { Run=12, Size=6 }
  JPEG_AC_LUM_VAL_129 = $C7;    { Run=12, Size=7 }
  JPEG_AC_LUM_VAL_130 = $C8;    { Run=12, Size=8 }
  JPEG_AC_LUM_VAL_131 = $C9;    { Run=12, Size=9 }
  JPEG_AC_LUM_VAL_132 = $CA;    { Run=12, Size=10 }
  JPEG_AC_LUM_VAL_133 = $D2;    { Run=13, Size=2 }
  JPEG_AC_LUM_VAL_134 = $D3;    { Run=13, Size=3 }
  JPEG_AC_LUM_VAL_135 = $D4;    { Run=13, Size=4 }
  JPEG_AC_LUM_VAL_136 = $D5;    { Run=13, Size=5 }
  JPEG_AC_LUM_VAL_137 = $D6;    { Run=13, Size=6 }
  JPEG_AC_LUM_VAL_138 = $D7;    { Run=13, Size=7 }
  JPEG_AC_LUM_VAL_139 = $D8;    { Run=13, Size=8 }
  JPEG_AC_LUM_VAL_140 = $D9;    { Run=13, Size=9 }
  JPEG_AC_LUM_VAL_141 = $DA;    { Run=13, Size=10 }
  JPEG_AC_LUM_VAL_142 = $E1;    { Run=14, Size=1 }
  JPEG_AC_LUM_VAL_143 = $E2;    { Run=14, Size=2 }
  
{ AC Luminance valeurs - Groupe 10 (indices 144-159) }
  JPEG_AC_LUM_VAL_144 = $E3;    { Run=14, Size=3 }
  JPEG_AC_LUM_VAL_145 = $E4;    { Run=14, Size=4 }
  JPEG_AC_LUM_VAL_146 = $E5;    { Run=14, Size=5 }
  JPEG_AC_LUM_VAL_147 = $E6;    { Run=14, Size=6 }
  JPEG_AC_LUM_VAL_148 = $E7;    { Run=14, Size=7 }
  JPEG_AC_LUM_VAL_149 = $E8;    { Run=14, Size=8 }
  JPEG_AC_LUM_VAL_150 = $E9;    { Run=14, Size=9 }
  JPEG_AC_LUM_VAL_151 = $EA;    { Run=14, Size=10 }
  JPEG_AC_LUM_VAL_152 = $F1;    { Run=15, Size=1 }
  JPEG_AC_LUM_VAL_153 = $F2;    { Run=15, Size=2 }
  JPEG_AC_LUM_VAL_154 = $F3;    { Run=15, Size=3 }
  JPEG_AC_LUM_VAL_155 = $F4;    { Run=15, Size=4 }
  JPEG_AC_LUM_VAL_156 = $F5;    { Run=15, Size=5 }
  JPEG_AC_LUM_VAL_157 = $F6;    { Run=15, Size=6 }
  JPEG_AC_LUM_VAL_158 = $F7;    { Run=15, Size=7 }
  JPEG_AC_LUM_VAL_159 = $F8;    { Run=15, Size=8 }
  
{ AC Luminance valeurs - Groupe 11 (indices 160-161) }
  JPEG_AC_LUM_VAL_160 = $F9;    { Run=15, Size=9 }
  JPEG_AC_LUM_VAL_161 = $FA;    { Run=15, Size=10 }
  
  JPEG_AC_LUM_VAL_COUNT = 162;  { Nombre total de valeurs AC luminance }

{ ============================================================
  TABLE HUFFMAN AC CHROMINANCE (CbCr) - Table 1
  BITS: nombre de codes Huffman de longueur 1 a 16 bits
  ============================================================ }

{ AC Chrominance BITS - 16 valeurs indiquant le nombre de codes par longueur }
  JPEG_AC_CHR_BITS_01 = 0;      { Codes de 1 bit: 0 }
  JPEG_AC_CHR_BITS_02 = 2;      { Codes de 2 bits: 2 }
  JPEG_AC_CHR_BITS_03 = 1;      { Codes de 3 bits: 1 }
  JPEG_AC_CHR_BITS_04 = 2;      { Codes de 4 bits: 2 }
  JPEG_AC_CHR_BITS_05 = 4;      { Codes de 5 bits: 4 }
  JPEG_AC_CHR_BITS_06 = 4;      { Codes de 6 bits: 4 }
  JPEG_AC_CHR_BITS_07 = 3;      { Codes de 7 bits: 3 }
  JPEG_AC_CHR_BITS_08 = 4;      { Codes de 8 bits: 4 }
  JPEG_AC_CHR_BITS_09 = 7;      { Codes de 9 bits: 7 }
  JPEG_AC_CHR_BITS_10 = 5;      { Codes de 10 bits: 5 }
  JPEG_AC_CHR_BITS_11 = 4;      { Codes de 11 bits: 4 }
  JPEG_AC_CHR_BITS_12 = 4;      { Codes de 12 bits: 4 }
  JPEG_AC_CHR_BITS_13 = 0;      { Codes de 13 bits: 0 }
  JPEG_AC_CHR_BITS_14 = 1;      { Codes de 14 bits: 1 }
  JPEG_AC_CHR_BITS_15 = 2;      { Codes de 15 bits: 2 }
  JPEG_AC_CHR_BITS_16 = 119;    { Codes de 16 bits: 119 }
  
{ AC Chrominance HUFFVAL - 162 valeurs au total
  Format: RRRRSSSS ou RRRR=run de zeros (0-15), SSSS=taille (0-10) }

{ AC Chrominance valeurs - Groupe 1 (indices 0-15) }
  JPEG_AC_CHR_VAL_000 = $00;    { EOB - End Of Block }
  JPEG_AC_CHR_VAL_001 = $01;    { Run=0, Size=1 }
  JPEG_AC_CHR_VAL_002 = $02;    { Run=0, Size=2 }
  JPEG_AC_CHR_VAL_003 = $03;    { Run=0, Size=3 }
  JPEG_AC_CHR_VAL_004 = $11;    { Run=1, Size=1 }
  JPEG_AC_CHR_VAL_005 = $04;    { Run=0, Size=4 }
  JPEG_AC_CHR_VAL_006 = $05;    { Run=0, Size=5 }
  JPEG_AC_CHR_VAL_007 = $21;    { Run=2, Size=1 }
  JPEG_AC_CHR_VAL_008 = $31;    { Run=3, Size=1 }
  JPEG_AC_CHR_VAL_009 = $06;    { Run=0, Size=6 }
  JPEG_AC_CHR_VAL_010 = $12;    { Run=1, Size=2 }
  JPEG_AC_CHR_VAL_011 = $41;    { Run=4, Size=1 }
  JPEG_AC_CHR_VAL_012 = $51;    { Run=5, Size=1 }
  JPEG_AC_CHR_VAL_013 = $07;    { Run=0, Size=7 }
  JPEG_AC_CHR_VAL_014 = $61;    { Run=6, Size=1 }
  JPEG_AC_CHR_VAL_015 = $71;    { Run=7, Size=1 }
  
{ AC Chrominance valeurs - Groupe 2 (indices 16-31) }
  JPEG_AC_CHR_VAL_016 = $13;    { Run=1, Size=3 }
  JPEG_AC_CHR_VAL_017 = $22;    { Run=2, Size=2 }
  JPEG_AC_CHR_VAL_018 = $32;    { Run=3, Size=2 }
  JPEG_AC_CHR_VAL_019 = $81;    { Run=8, Size=1 }
  JPEG_AC_CHR_VAL_020 = $08;    { Run=0, Size=8 }
  JPEG_AC_CHR_VAL_021 = $14;    { Run=1, Size=4 }
  JPEG_AC_CHR_VAL_022 = $42;    { Run=4, Size=2 }
  JPEG_AC_CHR_VAL_023 = $91;    { Run=9, Size=1 }
  JPEG_AC_CHR_VAL_024 = $A1;    { Run=10, Size=1 }
  JPEG_AC_CHR_VAL_025 = $B1;    { Run=11, Size=1 }
  JPEG_AC_CHR_VAL_026 = $C1;    { Run=12, Size=1 }
  JPEG_AC_CHR_VAL_027 = $09;    { Run=0, Size=9 }
  JPEG_AC_CHR_VAL_028 = $23;    { Run=2, Size=3 }
  JPEG_AC_CHR_VAL_029 = $33;    { Run=3, Size=3 }
  JPEG_AC_CHR_VAL_030 = $52;    { Run=5, Size=2 }
  JPEG_AC_CHR_VAL_031 = $F0;    { ZRL - Zero Run Length (16 zeros) }
  
{ AC Chrominance valeurs - Groupe 3 (indices 32-47) }
  JPEG_AC_CHR_VAL_032 = $15;    { Run=1, Size=5 }
  JPEG_AC_CHR_VAL_033 = $62;    { Run=6, Size=2 }
  JPEG_AC_CHR_VAL_034 = $72;    { Run=7, Size=2 }
  JPEG_AC_CHR_VAL_035 = $D1;    { Run=13, Size=1 }
  JPEG_AC_CHR_VAL_036 = $0A;    { Run=0, Size=10 }
  JPEG_AC_CHR_VAL_037 = $16;    { Run=1, Size=6 }
  JPEG_AC_CHR_VAL_038 = $24;    { Run=2, Size=4 }
  JPEG_AC_CHR_VAL_039 = $34;    { Run=3, Size=4 }
  JPEG_AC_CHR_VAL_040 = $E1;    { Run=14, Size=1 }
  JPEG_AC_CHR_VAL_041 = $25;    { Run=2, Size=5 }
  JPEG_AC_CHR_VAL_042 = $F1;    { Run=15, Size=1 }
  JPEG_AC_CHR_VAL_043 = $17;    { Run=1, Size=7 }
  JPEG_AC_CHR_VAL_044 = $18;    { Run=1, Size=8 }
  JPEG_AC_CHR_VAL_045 = $19;    { Run=1, Size=9 }
  JPEG_AC_CHR_VAL_046 = $1A;    { Run=1, Size=10 }
  JPEG_AC_CHR_VAL_047 = $26;    { Run=2, Size=6 }
  
{ AC Chrominance valeurs - Groupe 4 (indices 48-63) }
  JPEG_AC_CHR_VAL_048 = $27;    { Run=2, Size=7 }
  JPEG_AC_CHR_VAL_049 = $28;    { Run=2, Size=8 }
  JPEG_AC_CHR_VAL_050 = $29;    { Run=2, Size=9 }
  JPEG_AC_CHR_VAL_051 = $2A;    { Run=2, Size=10 }
  JPEG_AC_CHR_VAL_052 = $35;    { Run=3, Size=5 }
  JPEG_AC_CHR_VAL_053 = $36;    { Run=3, Size=6 }
  JPEG_AC_CHR_VAL_054 = $37;    { Run=3, Size=7 }
  JPEG_AC_CHR_VAL_055 = $38;    { Run=3, Size=8 }
  JPEG_AC_CHR_VAL_056 = $39;    { Run=3, Size=9 }
  JPEG_AC_CHR_VAL_057 = $3A;    { Run=3, Size=10 }
  JPEG_AC_CHR_VAL_058 = $43;    { Run=4, Size=3 }
  JPEG_AC_CHR_VAL_059 = $44;    { Run=4, Size=4 }
  JPEG_AC_CHR_VAL_060 = $45;    { Run=4, Size=5 }
  JPEG_AC_CHR_VAL_061 = $46;    { Run=4, Size=6 }
  JPEG_AC_CHR_VAL_062 = $47;    { Run=4, Size=7 }
  JPEG_AC_CHR_VAL_063 = $48;    { Run=4, Size=8 }
  
{ AC Chrominance valeurs - Groupe 5 (indices 64-79) }
  JPEG_AC_CHR_VAL_064 = $49;    { Run=4, Size=9 }
  JPEG_AC_CHR_VAL_065 = $4A;    { Run=4, Size=10 }
  JPEG_AC_CHR_VAL_066 = $53;    { Run=5, Size=3 }
  JPEG_AC_CHR_VAL_067 = $54;    { Run=5, Size=4 }
  JPEG_AC_CHR_VAL_068 = $55;    { Run=5, Size=5 }
  JPEG_AC_CHR_VAL_069 = $56;    { Run=5, Size=6 }
  JPEG_AC_CHR_VAL_070 = $57;    { Run=5, Size=7 }
  JPEG_AC_CHR_VAL_071 = $58;    { Run=5, Size=8 }
  JPEG_AC_CHR_VAL_072 = $59;    { Run=5, Size=9 }
  JPEG_AC_CHR_VAL_073 = $5A;    { Run=5, Size=10 }
  JPEG_AC_CHR_VAL_074 = $63;    { Run=6, Size=3 }
  JPEG_AC_CHR_VAL_075 = $64;    { Run=6, Size=4 }
  JPEG_AC_CHR_VAL_076 = $65;    { Run=6, Size=5 }
  JPEG_AC_CHR_VAL_077 = $66;    { Run=6, Size=6 }
  JPEG_AC_CHR_VAL_078 = $67;    { Run=6, Size=7 }
  JPEG_AC_CHR_VAL_079 = $68;    { Run=6, Size=8 }
  
{ AC Chrominance valeurs - Groupe 6 (indices 80-95) }
  JPEG_AC_CHR_VAL_080 = $69;    { Run=6, Size=9 }
  JPEG_AC_CHR_VAL_081 = $6A;    { Run=6, Size=10 }
  JPEG_AC_CHR_VAL_082 = $73;    { Run=7, Size=3 }
  JPEG_AC_CHR_VAL_083 = $74;    { Run=7, Size=4 }
  JPEG_AC_CHR_VAL_084 = $75;    { Run=7, Size=5 }
  JPEG_AC_CHR_VAL_085 = $76;    { Run=7, Size=6 }
  JPEG_AC_CHR_VAL_086 = $77;    { Run=7, Size=7 }
  JPEG_AC_CHR_VAL_087 = $78;    { Run=7, Size=8 }
  JPEG_AC_CHR_VAL_088 = $79;    { Run=7, Size=9 }
  JPEG_AC_CHR_VAL_089 = $7A;    { Run=7, Size=10 }
  JPEG_AC_CHR_VAL_090 = $82;    { Run=8, Size=2 }
  JPEG_AC_CHR_VAL_091 = $83;    { Run=8, Size=3 }
  JPEG_AC_CHR_VAL_092 = $84;    { Run=8, Size=4 }
  JPEG_AC_CHR_VAL_093 = $85;    { Run=8, Size=5 }
  JPEG_AC_CHR_VAL_094 = $86;    { Run=8, Size=6 }
  JPEG_AC_CHR_VAL_095 = $87;    { Run=8, Size=7 }
  
{ AC Chrominance valeurs - Groupe 7 (indices 96-111) }
  JPEG_AC_CHR_VAL_096 = $88;    { Run=8, Size=8 }
  JPEG_AC_CHR_VAL_097 = $89;    { Run=8, Size=9 }
  JPEG_AC_CHR_VAL_098 = $8A;    { Run=8, Size=10 }
  JPEG_AC_CHR_VAL_099 = $92;    { Run=9, Size=2 }
  JPEG_AC_CHR_VAL_100 = $93;    { Run=9, Size=3 }
  JPEG_AC_CHR_VAL_101 = $94;    { Run=9, Size=4 }
  JPEG_AC_CHR_VAL_102 = $95;    { Run=9, Size=5 }
  JPEG_AC_CHR_VAL_103 = $96;    { Run=9, Size=6 }
  JPEG_AC_CHR_VAL_104 = $97;    { Run=9, Size=7 }
  JPEG_AC_CHR_VAL_105 = $98;    { Run=9, Size=8 }
  JPEG_AC_CHR_VAL_106 = $99;    { Run=9, Size=9 }
  JPEG_AC_CHR_VAL_107 = $9A;    { Run=9, Size=10 }
  JPEG_AC_CHR_VAL_108 = $A2;    { Run=10, Size=2 }
  JPEG_AC_CHR_VAL_109 = $A3;    { Run=10, Size=3 }
  JPEG_AC_CHR_VAL_110 = $A4;    { Run=10, Size=4 }
  JPEG_AC_CHR_VAL_111 = $A5;    { Run=10, Size=5 }
  
{ AC Chrominance valeurs - Groupe 8 (indices 112-127) }
  JPEG_AC_CHR_VAL_112 = $A6;    { Run=10, Size=6 }
  JPEG_AC_CHR_VAL_113 = $A7;    { Run=10, Size=7 }
  JPEG_AC_CHR_VAL_114 = $A8;    { Run=10, Size=8 }
  JPEG_AC_CHR_VAL_115 = $A9;    { Run=10, Size=9 }
  JPEG_AC_CHR_VAL_116 = $AA;    { Run=10, Size=10 }
  JPEG_AC_CHR_VAL_117 = $B2;    { Run=11, Size=2 }
  JPEG_AC_CHR_VAL_118 = $B3;    { Run=11, Size=3 }
  JPEG_AC_CHR_VAL_119 = $B4;    { Run=11, Size=4 }
  JPEG_AC_CHR_VAL_120 = $B5;    { Run=11, Size=5 }
  JPEG_AC_CHR_VAL_121 = $B6;    { Run=11, Size=6 }
  JPEG_AC_CHR_VAL_122 = $B7;    { Run=11, Size=7 }
  JPEG_AC_CHR_VAL_123 = $B8;    { Run=11, Size=8 }
  JPEG_AC_CHR_VAL_124 = $B9;    { Run=11, Size=9 }
  JPEG_AC_CHR_VAL_125 = $BA;    { Run=11, Size=10 }
  JPEG_AC_CHR_VAL_126 = $C2;    { Run=12, Size=2 }
  JPEG_AC_CHR_VAL_127 = $C3;    { Run=12, Size=3 }
  
{ AC Chrominance valeurs - Groupe 9 (indices 128-143) }
  JPEG_AC_CHR_VAL_128 = $C4;    { Run=12, Size=4 }
  JPEG_AC_CHR_VAL_129 = $C5;    { Run=12, Size=5 }
  JPEG_AC_CHR_VAL_130 = $C6;    { Run=12, Size=6 }
  JPEG_AC_CHR_VAL_131 = $C7;    { Run=12, Size=7 }
  JPEG_AC_CHR_VAL_132 = $C8;    { Run=12, Size=8 }
  JPEG_AC_CHR_VAL_133 = $C9;    { Run=12, Size=9 }
  JPEG_AC_CHR_VAL_134 = $CA;    { Run=12, Size=10 }
  JPEG_AC_CHR_VAL_135 = $D2;    { Run=13, Size=2 }
  JPEG_AC_CHR_VAL_136 = $D3;    { Run=13, Size=3 }
  JPEG_AC_CHR_VAL_137 = $D4;    { Run=13, Size=4 }
  JPEG_AC_CHR_VAL_138 = $D5;    { Run=13, Size=5 }
  JPEG_AC_CHR_VAL_139 = $D6;    { Run=13, Size=6 }
  JPEG_AC_CHR_VAL_140 = $D7;    { Run=13, Size=7 }
  JPEG_AC_CHR_VAL_141 = $D8;    { Run=13, Size=8 }
  JPEG_AC_CHR_VAL_142 = $D9;    { Run=13, Size=9 }
  JPEG_AC_CHR_VAL_143 = $DA;    { Run=13, Size=10 }
  
{ AC Chrominance valeurs - Groupe 10 (indices 144-159) }
  JPEG_AC_CHR_VAL_144 = $E2;    { Run=14, Size=2 }
  JPEG_AC_CHR_VAL_145 = $E3;    { Run=14, Size=3 }
  JPEG_AC_CHR_VAL_146 = $E4;    { Run=14, Size=4 }
  JPEG_AC_CHR_VAL_147 = $E5;    { Run=14, Size=5 }
  JPEG_AC_CHR_VAL_148 = $E6;    { Run=14, Size=6 }
  JPEG_AC_CHR_VAL_149 = $E7;    { Run=14, Size=7 }
  JPEG_AC_CHR_VAL_150 = $E8;    { Run=14, Size=8 }
  JPEG_AC_CHR_VAL_151 = $E9;    { Run=14, Size=9 }
  JPEG_AC_CHR_VAL_152 = $EA;    { Run=14, Size=10 }
  JPEG_AC_CHR_VAL_153 = $F2;    { Run=15, Size=2 }
  JPEG_AC_CHR_VAL_154 = $F3;    { Run=15, Size=3 }
  JPEG_AC_CHR_VAL_155 = $F4;    { Run=15, Size=4 }
  JPEG_AC_CHR_VAL_156 = $F5;    { Run=15, Size=5 }
  JPEG_AC_CHR_VAL_157 = $F6;    { Run=15, Size=6 }
  JPEG_AC_CHR_VAL_158 = $F7;    { Run=15, Size=7 }
  JPEG_AC_CHR_VAL_159 = $F8;    { Run=15, Size=8 }
  
{ AC Chrominance valeurs - Groupe 11 (indices 160-161) }
  JPEG_AC_CHR_VAL_160 = $F9;    { Run=15, Size=9 }
  JPEG_AC_CHR_VAL_161 = $FA;    { Run=15, Size=10 }
  
  JPEG_AC_CHR_VAL_COUNT = 162;  { Nombre total de valeurs AC chrominance }

{ Indices des tables de Huffman dans le fichier JPEG }
  JPEG_HUFF_DC_LUM_ID = 0;      { Table DC luminance: classe=0, id=0 }
  JPEG_HUFF_DC_CHR_ID = 1;      { Table DC chrominance: classe=0, id=1 }
  JPEG_HUFF_AC_LUM_ID = 0;      { Table AC luminance: classe=1, id=0 }
  JPEG_HUFF_AC_CHR_ID = 1;      { Table AC chrominance: classe=1, id=1 }
  
{ Classe de table Huffman }
  JPEG_HUFF_CLASS_DC = 0;       { Table pour coefficients DC }
  JPEG_HUFF_CLASS_AC = 1;       { Table pour coefficients AC }
  
{ Constantes pour l'encodage Huffman }
  JPEG_HUFF_BITS_COUNT = 16;    { Nombre d'entrees dans le tableau BITS }
  JPEG_HUFF_MAX_CODE_LEN = 16;  { Longueur maximale d'un code Huffman }
  JPEG_DC_CATEGORY_COUNT = 12;  { Nombre de categories DC (0-11) }
  JPEG_AC_SYMBOL_COUNT = 256;   { Nombre de symboles AC possibles (RRRRSSSS) }
  
{ Valeurs speciales pour les coefficients AC }
  JPEG_AC_EOB = $00;            { End Of Block - fin du bloc DCT }
  JPEG_AC_ZRL = $F0;            { Zero Run Length - 16 zeros consecutifs }

{ ============================================================
  CONSTANTES JPEG - GENERATEUR INTEGRE (SANS OUTIL EXTERNE)
  Partie 4: Transformation DCT (Discrete Cosine Transform) 8x8
  ============================================================ }

{ La DCT (Discrete Cosine Transform) est une transformation mathematique
  qui convertit un bloc 8x8 de pixels en un bloc 8x8 de coefficients
  frequentiels. C'est le coeur de la compression JPEG.
  
  Formule de la DCT-II 2D:
  F(u,v) = (1/4) * C(u) * C(v) * SUM[x=0..7, y=0..7] f(x,y) *
           cos((2x+1)*u*pi/16) * cos((2y+1)*v*pi/16)
  
  ou C(k) = 1/sqrt(2) si k=0, sinon C(k) = 1
  
  Le coefficient DC (u=0,v=0) represente la moyenne du bloc.
  Les coefficients AC representent les variations de frequence. }

{ Constantes mathematiques pour la DCT }
  JPEG_PI = 3.14159265358979323846;   { PI pour les calculs trigonometriques }
  JPEG_DCT_SIZE = 8;                   { Taille du bloc DCT (8x8) }
  JPEG_DCT_SIZE2 = 64;                 { Nombre total de coefficients (8*8) }
  
{ Facteur de normalisation pour la DCT }
  JPEG_DCT_NORM = 0.25;                { 1/4 pour la normalisation 2D }
  JPEG_DCT_SQRT2_INV = 0.70710678118654752440; { 1/sqrt(2) pour C(0) }
  JPEG_DCT_SQRT8_INV = 0.35355339059327376220; { 1/sqrt(8) = 1/(2*sqrt(2)) }
  
{ Decalage pour centrer les pixels autour de zero avant DCT }
  JPEG_LEVEL_SHIFT = 128;              { Pour convertir 0..255 en -128..127 }

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 6
   Constantes pour l'encodage RLE (Run-Length Encoding) des coefficients AC
  ============================================================ }

{ Taille maximale du bloc RLE (63 coefficients AC maximum) }
  JPEG_RLE_MAX_PAIRS = 63;             { Maximum de paires (run, value) }

{ Valeur speciale pour marquer la fin de bloc (EOB = End Of Block) }
  JPEG_RLE_EOB = 0;                    { RunLength=0, Value=0 signifie EOB }

{ Valeur speciale pour les zeros etendus (ZRL = Zero Run Length) }
{ Quand plus de 15 zeros consecutifs, on utilise ZRL (F/0) }
  JPEG_RLE_ZRL_RUNLENGTH = 15;         { RunLength max avant ZRL }
  JPEG_RLE_ZRL_SYMBOL = $F0;           { Symbole ZRL = (15, 0) en hex }

{ Categories de magnitude pour les coefficients AC (0-10) }
{ Category N: valeur absolue dans [2^(N-1), 2^N - 1] pour N >= 1 }
  JPEG_AC_CAT_MIN = 0;                 { Categorie minimum (valeur 0) }
  JPEG_AC_CAT_MAX = 10;                { Categorie maximum (|val| <= 1023) }

{ Valeurs limites par categorie AC }
  JPEG_AC_MAX_VALUE = 1023;            { Valeur maximale AC encodable }
  JPEG_AC_MIN_VALUE = -1023;           { Valeur minimale AC encodable }

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 7
   Constantes pour l'encodeur Huffman bit par bit
  ============================================================ }

{ Taille du buffer de bits pour l'ecriture }
  JPEG_BIT_BUFFER_SIZE = 8192;         { Taille du buffer en octets }
  JPEG_BITS_PER_BYTE = 8;              { Bits par octet }

{ Codes Huffman speciaux - definis dans Partie 3 }
{ JPEG_HUFF_MAX_CODE_LEN deja defini plus haut }
  JPEG_HUFF_MAX_CODES = 256;           { Nombre max de codes par table }

{ Constantes pour le byte stuffing }
  JPEG_MARKER_ESCAPE = $FF;            { Marqueur a echapper }
  JPEG_STUFF_BYTE = $00;               { Octet de stuffing apres $FF }

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 8
   Constantes pour la conversion couleur RGB vers YCbCr
  ============================================================ }

{ Coefficients ITU-R BT.601 pour conversion RGB -> YCbCr }
{ Y  = 0.299*R + 0.587*G + 0.114*B }
{ Cb = 128 - 0.169*R - 0.331*G + 0.500*B }
{ Cr = 128 + 0.500*R - 0.419*G - 0.081*B }
  JPEG_RGB_Y_R  = 0.299;               { Coefficient Y pour R }
  JPEG_RGB_Y_G  = 0.587;               { Coefficient Y pour G }
  JPEG_RGB_Y_B  = 0.114;               { Coefficient Y pour B }
  JPEG_RGB_CB_R = -0.169;              { Coefficient Cb pour R }
  JPEG_RGB_CB_G = -0.331;              { Coefficient Cb pour G }
  JPEG_RGB_CB_B = 0.500;               { Coefficient Cb pour B }
  JPEG_RGB_CR_R = 0.500;               { Coefficient Cr pour R }
  JPEG_RGB_CR_G = -0.419;              { Coefficient Cr pour G }
  JPEG_RGB_CR_B = -0.081;              { Coefficient Cr pour B }
  JPEG_CHROMA_OFFSET = 128;            { Offset pour Cb et Cr }

{ Limites des composantes }
  JPEG_COMP_MIN = 0;                   { Valeur minimale composante }
  JPEG_COMP_MAX = 255;                 { Valeur maximale composante }

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 9
   Constantes pour le sous-echantillonnage chromatique
  ============================================================ }

{ Modes de sous-echantillonnage }
  JPEG_SUBSAMP_444 = 0;                { 4:4:4 - Pas de sous-echantillonnage }
  JPEG_SUBSAMP_422 = 1;                { 4:2:2 - Horizontal 2:1 }
  JPEG_SUBSAMP_420 = 2;                { 4:2:0 - Horizontal et vertical 2:1 }
  JPEG_SUBSAMP_411 = 3;                { 4:1:1 - Horizontal 4:1 }

{ Facteurs d'echantillonnage pour chaque mode }
{ En 4:2:0, Y est 2x2, Cb et Cr sont 1x1 }
  JPEG_SAMP_H_444 = 1;                 { Facteur H pour 4:4:4 }
  JPEG_SAMP_V_444 = 1;                 { Facteur V pour 4:4:4 }
  JPEG_SAMP_H_420 = 2;                 { Facteur H pour 4:2:0 }
  JPEG_SAMP_V_420 = 2;                 { Facteur V pour 4:2:0 }

{ Taille d'un MCU (Minimum Coded Unit) }
  JPEG_MCU_SIZE_444 = 8;               { MCU = 8x8 en 4:4:4 }
  JPEG_MCU_SIZE_420 = 16;              { MCU = 16x16 en 4:2:0 }

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 10
   Constantes pour la structure du fichier JPEG
  ============================================================ }

{ Marqueurs JPEG (tous precedent de $FF) }
  JPEG_MARKER_SOI  = $D8;              { Start Of Image }
  JPEG_MARKER_EOI  = $D9;              { End Of Image }
  JPEG_MARKER_APP0 = $E0;              { Application segment 0 (JFIF) }
  JPEG_MARKER_DQT  = $DB;              { Define Quantization Table }
  JPEG_MARKER_SOF0 = $C0;              { Start Of Frame (Baseline DCT) }
  JPEG_MARKER_DHT  = $C4;              { Define Huffman Table }
  JPEG_MARKER_SOS  = $DA;              { Start Of Scan }
  JPEG_MARKER_DRI  = $DD;              { Define Restart Interval }
  JPEG_MARKER_RST0 = $D0;              { Restart marker 0 }
  JPEG_MARKER_COM  = $FE;              { Comment }

{ Identifiants JFIF }
  JPEG_JFIF_MAJOR = 1;                 { Version majeure JFIF }
  JPEG_JFIF_MINOR = 1;                 { Version mineure JFIF }
  JPEG_JFIF_UNITS_NONE = 0;            { Pas d'unite (aspect ratio) }
  JPEG_JFIF_UNITS_DPI = 1;             { Pixels par pouce }
  JPEG_JFIF_UNITS_DPCM = 2;            { Pixels par cm }

{ Parametres par defaut de l'encodeur }
  JPEG_DEFAULT_QUALITY = 75;           { Qualite par defaut (1-100) }
  JPEG_DEFAULT_DPI = 72;               { Resolution par defaut }
{ JPEG_MAX_WIDTH, JPEG_MAX_HEIGHT, JPEG_MAX_COMPONENTS deja definis dans Partie 1 }

{ ============================================================
  TYPES
  ============================================================ }
Type
  { Type pour les tables de quantification JPEG 8x8 = 64 elements }
  TJPEGQuantTable = Array[0..63] Of Byte;
  
  { Types pour les tables de Huffman JPEG (Partie 3) }
  
  { Tableau BITS: nombre de codes de chaque longueur (1-16 bits) }
  TJPEGHuffBits = Array[0..15] Of Byte;
  
  { Tableau HUFFVAL pour les coefficients DC (12 categories max) }
  TJPEGHuffDCVal = Array[0..11] Of Byte;
  
  { Tableau HUFFVAL pour les coefficients AC (162 valeurs max) }
  TJPEGHuffACVal = Array[0..161] Of Byte;
  
  { Structure complete pour une table de Huffman DC }
  TJPEGHuffDCTable = Record
    Bits: TJPEGHuffBits;       { Nombre de codes par longueur }
    Values: TJPEGHuffDCVal;    { Valeurs associees aux codes }
    Count: Integer;            { Nombre total de valeurs }
  End;
  
  { Structure complete pour une table de Huffman AC }
  TJPEGHuffACTable = Record
    Bits: TJPEGHuffBits;       { Nombre de codes par longueur }
    Values: TJPEGHuffACVal;    { Valeurs associees aux codes }
    Count: Integer;            { Nombre total de valeurs }
  End;
  
  { Ensemble des 4 tables de Huffman pour JPEG baseline }
  TJPEGHuffTables = Record
    DC_Lum: TJPEGHuffDCTable;  { Table DC luminance (Y) }
    DC_Chr: TJPEGHuffDCTable;  { Table DC chrominance (Cb, Cr) }
    AC_Lum: TJPEGHuffACTable;  { Table AC luminance (Y) }
    AC_Chr: TJPEGHuffACTable;  { Table AC chrominance (Cb, Cr) }
  End;
  
  { Types pour la transformation DCT JPEG (Partie 4) }
  
  { Bloc 8x8 de pixels (valeurs entieres 0-255 ou -128..127 apres centrage) }
  TJPEGPixelBlock = Array[0..7, 0..7] Of Integer;
  
  { Bloc 8x8 de coefficients DCT (valeurs flottantes) }
  TJPEGDCTBlock = Array[0..7, 0..7] Of Real;
  
  { Bloc 8x8 de coefficients DCT quantifies (valeurs entieres) }
  TJPEGQuantBlock = Array[0..7, 0..7] Of Integer;
  
  { Table de cosinus pre-calcules pour DCT 8x8 }
  TJPEGCosTable = Array[0..7, 0..7] Of Real;
  
  { Types pour le Zigzag reordering JPEG (Partie 5) }
  
  { Tableau lineaire de 64 coefficients en ordre zigzag }
  TJPEGZigzagBlock = Array[0..63] Of Integer;
  
  { Table de correspondance pour conversion zigzag/matriciel }
  TJPEGZigzagTable = Array[0..63] Of Byte;
  
  { Types pour l'encodage RLE JPEG (Partie 6) }
  
  { Paire RLE: (RunLength, Value) pour un coefficient AC }
  { RunLength = nombre de zeros avant ce coefficient (0-15) }
  { Value = valeur du coefficient non-nul }
  TJPEGRLEPair = Record
    RunLength: Byte;           { Nombre de zeros precedents (0-15) }
    Value: Integer;            { Valeur du coefficient (-1023..1023) }
    Category: Byte;            { Categorie de magnitude (0-10) }
    IsEOB: Boolean;            { True si End-Of-Block }
    IsZRL: Boolean;            { True si Zero-Run-Length (16 zeros) }
  End;
  
  { Bloc RLE complet: tableau de paires pour les 63 coefficients AC }
  { Le coefficient DC (indice 0 du zigzag) est traite separement }
  TJPEGRLEBlock = Record
    Pairs: Array[0..62] Of TJPEGRLEPair;  { Paires RLE }
    Count: Integer;                        { Nombre de paires utilisees }
    DCValue: Integer;                      { Coefficient DC (zigzag[0]) }
    HasEOB: Boolean;                       { Bloc termine par EOB? }
  End;
  
  { Statistiques d'encodage RLE pour un bloc }
  TJPEGRLEStats = Record
    TotalPairs: Integer;       { Nombre total de paires RLE }
    ZRLCount: Integer;         { Nombre de symboles ZRL }
    EOBCount: Integer;         { Nombre de EOB (0 ou 1) }
    MaxRunLength: Integer;     { Plus long run de zeros }
    MaxCategory: Integer;      { Plus grande categorie utilisee }
    NonZeroCount: Integer;     { Nombre de coefficients non-nuls }
  End;

  { Types pour l'encodeur Huffman bit par bit JPEG (Partie 7) }
  
  { Code Huffman avec sa longueur }
  TJPEGHuffCode = Record
    Code: Word;                { Valeur du code (max 16 bits) }
    Length: Byte;              { Longueur en bits (1-16) }
  End;
  
  { Table de codes Huffman complete (256 entrees) }
  TJPEGHuffCodeTable = Array[0..255] Of TJPEGHuffCode;
  
  { Buffer de bits pour l'ecriture }
  TJPEGBitBuffer = Record
    Buffer: LongInt;           { Accumulateur de bits }
    BitCount: Integer;         { Nombre de bits dans le buffer }
    ByteBuffer: Array[0..JPEG_BIT_BUFFER_SIZE-1] Of Byte; { Buffer de sortie }
    ByteCount: Integer;        { Octets dans le buffer }
    TotalBits: LongInt;        { Total de bits ecrits }
    TotalBytes: LongInt;       { Total d'octets generes }
  End;
  
  { Statistiques de l'encodeur Huffman }
  TJPEGHuffStats = Record
    DCCodesWritten: LongInt;   { Codes DC ecrits }
    ACCodesWritten: LongInt;   { Codes AC ecrits }
    StuffBytesAdded: LongInt;  { Octets de stuffing ajoutes }
    TotalBitsWritten: LongInt; { Total de bits ecrits }
    TotalBytesOutput: LongInt; { Octets de sortie }
  End;
  
  { Types pour la conversion couleur RGB/YCbCr JPEG (Partie 8) }
  
  { Pixel RGB }
  TJPEGRGBPixel = Record
    R: Byte;                   { Rouge (0-255) }
    G: Byte;                   { Vert (0-255) }
    B: Byte;                   { Bleu (0-255) }
  End;
  
  { Pixel YCbCr }
  TJPEGYCbCrPixel = Record
    Y: Byte;                   { Luminance (0-255) }
    Cb: Byte;                  { Chrominance bleue (0-255) }
    Cr: Byte;                  { Chrominance rouge (0-255) }
  End;
  
  { Bloc 8x8 de pixels RGB }
  TJPEGRGBBlock = Array[0..7, 0..7] Of TJPEGRGBPixel;
  
  { Bloc 8x8 de pixels YCbCr }
  TJPEGYCbCrBlock = Array[0..7, 0..7] Of TJPEGYCbCrPixel;
  
  { Composante 8x8 (Y, Cb ou Cr) }
  TJPEGComponentBlock = Array[0..7, 0..7] Of Byte;
  
  { Statistiques de conversion couleur }
  TJPEGColorStats = Record
    PixelsConverted: LongInt;  { Nombre de pixels convertis }
    BlocksConverted: LongInt;  { Nombre de blocs convertis }
    ClippedY: LongInt;         { Valeurs Y ecretes }
    ClippedCb: LongInt;        { Valeurs Cb ecretees }
    ClippedCr: LongInt;        { Valeurs Cr ecretees }
  End;
  
  { Types pour le sous-echantillonnage chromatique JPEG (Partie 9) }
  
  { MCU (Minimum Coded Unit) en 4:2:0 }
  { Contient 4 blocs Y (2x2), 1 bloc Cb, 1 bloc Cr }
  TJPEGMCU420 = Record
    Y: Array[0..3] Of TJPEGComponentBlock;  { 4 blocs Y (16x16 pixels) }
    Cb: TJPEGComponentBlock;                 { 1 bloc Cb (sous-echantillonne) }
    Cr: TJPEGComponentBlock;                 { 1 bloc Cr (sous-echantillonne) }
  End;
  
  { MCU en 4:4:4 (pas de sous-echantillonnage) }
  TJPEGMCU444 = Record
    Y: TJPEGComponentBlock;    { 1 bloc Y }
    Cb: TJPEGComponentBlock;   { 1 bloc Cb }
    Cr: TJPEGComponentBlock;   { 1 bloc Cr }
  End;
  
  { Configuration du sous-echantillonnage }
  TJPEGSubsampConfig = Record
    Mode: Integer;             { Mode (444, 420, etc.) }
    HorizFactor: Integer;      { Facteur horizontal }
    VertFactor: Integer;       { Facteur vertical }
    MCUWidth: Integer;         { Largeur MCU en pixels }
    MCUHeight: Integer;        { Hauteur MCU en pixels }
    YBlocksPerMCU: Integer;    { Blocs Y par MCU }
  End;
  
  { Statistiques de sous-echantillonnage }
  TJPEGSubsampStats = Record
    MCUsProcessed: LongInt;    { MCUs traites }
    YBlocksOutput: LongInt;    { Blocs Y produits }
    CbBlocksOutput: LongInt;   { Blocs Cb produits }
    CrBlocksOutput: LongInt;   { Blocs Cr produits }
  End;
  
  { Types pour l'ecriture du fichier JPEG (Partie 10) }
  
  { Information d'une composante dans SOF }
  TJPEGComponentInfo = Record
    ID: Byte;                  { Identifiant (1=Y, 2=Cb, 3=Cr) }
    HSamp: Byte;               { Facteur echantillonnage horizontal }
    VSamp: Byte;               { Facteur echantillonnage vertical }
    QTableID: Byte;            { ID table de quantification }
  End;
  
  { En-tete JPEG complet }
  TJPEGHeader = Record
    Width: Word;               { Largeur image }
    Height: Word;              { Hauteur image }
    NumComponents: Byte;       { Nombre de composantes (3 pour YCbCr) }
    Precision: Byte;           { Bits par echantillon (8) }
    Components: Array[0..2] Of TJPEGComponentInfo;
  End;
  
  { Etat de l'encodeur JPEG }
  TJPEGEncoderState = Record
    Initialized: Boolean;      { Encodeur initialise? }
    Quality: Integer;          { Qualite (1-100) }
    SubsampMode: Integer;      { Mode sous-echantillonnage }
    LastDC_Y: Integer;         { Dernier DC Y (pour DPCM) }
    LastDC_Cb: Integer;        { Dernier DC Cb }
    LastDC_Cr: Integer;        { Dernier DC Cr }
    MCUsEncoded: LongInt;      { MCUs encodes }
    BytesWritten: LongInt;     { Octets ecrits }
  End;
  
  { Statistiques globales de l'encodeur }
  TJPEGEncodeStats = Record
    TotalMCUs: LongInt;        { Total MCUs }
    TotalBlocks: LongInt;      { Total blocs }
    TotalBytes: LongInt;       { Taille fichier }
    HeaderBytes: LongInt;      { Octets en-tete }
    DataBytes: LongInt;        { Octets donnees }
    CompressionRatio: Real;    { Ratio compression }
  End;

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
    SvgOutput    : Boolean;    { --svg ou -D DOT_IMAGE_FORMAT=svg }
    PngOutput    : Boolean;    { --png ou -D DOT_IMAGE_FORMAT=png }
    VdxOutput    : Boolean;    { --visio ou -D DOT_IMAGE_FORMAT=vdx }
    JpegOutput   : Boolean;    { --jpeg ou -jpg ou -D DOT_IMAGE_FORMAT=jpeg }
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
    ENT_DICTIONARY, ENT_SERVICE, ENT_SINGLETON, ENT_EXCEPTION,
    ENT_METHOD, ENT_PROCEDURE);

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

  { Types pour les macros et preprocesseur (TODO 20) }
  TMacro = Record
    Name       : String;            { Nom de la macro }
    Parameters : String;            { Parametres si fonction-like }
    Value      : String;            { Valeur de substitution }
    FileName   : String;            { Fichier de definition }
    Line       : Integer;           { Ligne de definition }
    IsFuncLike : Boolean;           { True si macro avec parametres }
    IsVariadic : Boolean;           { True si parametres variadiques }
  End;

  TPreprocessorState = (
    PP_ACTIVE,                      { Code actif (inclus) }
    PP_SKIPPING,                    { Code ignore (exclus par #if) }
    PP_DONE                         { Branche deja traitee }
  );

  TIfDefStack = Record
    State      : TPreprocessorState;{ Etat courant }
    WasActive  : Boolean;           { Une branche a ete active }
    Line       : Integer;           { Ligne du #if/#ifdef }
  End;

  { Types pour les espaces de noms et modules (TODO 21) }
  TNamespace = Record
    Name       : String;            { Nom du namespace }
    FullName   : String;            { Nom qualifie complet }
    ParentId   : Integer;           { ID du namespace parent, -1 si racine }
    FileName   : String;            { Fichier de definition }
    Line       : Integer;           { Ligne de debut }
    EndLine    : Integer;           { Ligne de fin }
    IsAnonymous: Boolean;           { Namespace anonyme }
    IsInline   : Boolean;           { Inline namespace C++11 }
    Language   : String;            { Langage source }
  End;

  TModule = Record
    Name       : String;            { Nom du module }
    FileName   : String;            { Fichier source }
    ExportList : String;            { Liste des exports separes par ; }
    ImportList : String;            { Liste des imports separes par ; }
    IsPartition: Boolean;           { Partition de module }
    IsInterface: Boolean;           { Module interface }
    Line       : Integer;           { Ligne de declaration }
  End;

  { Type pour l'index de recherche full-text (TODO 22) }
  TSearchIndex = Record
    Word       : String;            { Mot indexe }
    EntityId   : Integer;           { ID de l'entite }
    FileName   : String;            { Fichier de documentation }
    Anchor     : String;            { Ancre dans le fichier }
    Score      : Integer;           { Score de pertinence }
  End;

  { Types pour la validation et les avertissements (TODO 24) }
  TWarningKind = (
    WARN_UNDOC_FUNC,       { Fonction non documentee }
    WARN_UNDOC_PARAM,      { Parametre non documente }
    WARN_UNDOC_RETURN,     { Valeur de retour non documentee }
    WARN_UNDOC_CLASS,      { Classe non documentee }
    WARN_UNDOC_MEMBER,     { Membre non documente }
    WARN_UNDOC_FILE,       { Fichier non documente }
    WARN_INVALID_TAG,      { Balise Doxygen invalide }
    WARN_MISSING_PARAM,    { Parametre manquant dans @param }
    WARN_EXTRA_PARAM,      { Parametre en trop dans @param }
    WARN_TYPE_MISMATCH,    { Type ne correspond pas }
    WARN_BROKEN_LINK,      { Lien @see ou @ref casse }
    WARN_DUPLICATE_DOC,    { Documentation en double }
    WARN_CIRCULAR_DEP,     { Dependance circulaire }
    WARN_MISSING_INCLUDE,  { Fichier include manquant }
    WARN_SYNTAX_ERROR      { Erreur de syntaxe dans la doc }
  );

  TWarning = Record
    Kind     : TWarningKind;        { Type d'avertissement }
    FileName : String;              { Fichier concerne }
    Line     : Integer;             { Ligne concernee }
    Message  : String;              { Message d'avertissement }
    EntityId : Integer;             { Entite concernee, ou 0 }
  End;

  { Type pour les statistiques de couverture (TODO 25) }
  TStatistics = Record
    TotalFiles       : Integer;     { Nombre de fichiers traites }
    TotalLines       : Integer;     { Nombre de lignes de code }
    TotalEntities    : Integer;     { Nombre d'entites }
    DocumentedCount  : Integer;     { Entites documentees }
    UndocumentedCount: Integer;     { Entites non documentees }
    WarningCount     : Integer;     { Nombre d'avertissements }
    ErrorCount       : Integer;     { Nombre d'erreurs }
    ClassCount       : Integer;     { Nombre de classes }
    FunctionCount    : Integer;     { Nombre de fonctions }
    VariableCount    : Integer;     { Nombre de variables }
    NamespaceCount   : Integer;     { Nombre de namespaces }
    PageCount        : Integer;     { Nombre de pages custom }
    GroupCount       : Integer;     { Nombre de groupes }
    CoveragePercent  : Real;        { Pourcentage de couverture }
    ProcessingTime   : Real;        { Temps de traitement en secondes }
    OutputSize       : LongInt;     { Taille de la doc generee en octets }
  End;

  { Types pour le generateur PNG integre (sans outil externe) }
  TPngColor = Record
    R, G, B : Byte;                  { Composantes rouge, vert, bleu }
  End;

  TPngNode = Record
    Id     : String;                 { Identifiant du noeud }
    Name   : String;                 { Nom affiche }
    X, Y   : Integer;                { Position X, Y }
    W, H   : Integer;                { Largeur, Hauteur }
    Color  : TPngColor;              { Couleur du noeud }
    Shape  : String;                 { Forme: box, ellipse, record }
  End;

  TPngEdge = Record
    FromId : String;                 { Noeud source }
    ToId   : String;                 { Noeud destination }
    FromX, FromY : Integer;          { Position depart }
    ToX, ToY     : Integer;          { Position arrivee }
    Color  : TPngColor;              { Couleur de l'arete }
    Style  : String;                 { Style: solid, dashed }
    LabelText : String;              { Etiquette de l'arete }
  End;

  TPngGraph = Record
    Title   : String;                { Titre du graphe }
    Width   : Integer;               { Largeur de l'image }
    Height  : Integer;               { Hauteur de l'image }
    BgColor : TPngColor;             { Couleur de fond }
    Nodes   : Array[1..MAX_PNG_NODES] Of TPngNode;
    NodeCount : Integer;
    Edges   : Array[1..MAX_PNG_EDGES] Of TPngEdge;
    EdgeCount : Integer;
  End;

  TPngPixelRow = Array[0..PNG_MAX_WIDTH-1] Of TPngColor;

  { Types pour le generateur SVG integre (sans outil externe) }
  TSvgNode = Record
    Id       : String;               { Identifiant du noeud }
    Name     : String;               { Nom affiche }
    X, Y     : Integer;              { Position X, Y }
    W, H     : Integer;              { Largeur, Hauteur }
    FillColor: String;               { Couleur de remplissage (ex: #C8C8FF) }
    StrokeColor: String;             { Couleur de bordure }
    Shape    : String;               { Forme: rect, ellipse, record }
  End;

  TSvgEdge = Record
    FromId   : String;               { Noeud source }
    ToId     : String;               { Noeud destination }
    FromX, FromY : Integer;          { Position depart }
    ToX, ToY     : Integer;          { Position arrivee }
    StrokeColor  : String;           { Couleur de l'arete }
    Style        : String;           { Style: solid, dashed }
    LabelText    : String;           { Etiquette de l'arete }
  End;

  TSvgGraph = Record
    Title     : String;              { Titre du graphe }
    Width     : Integer;             { Largeur de l'image }
    Height    : Integer;             { Hauteur de l'image }
    BgColor   : String;              { Couleur de fond (ex: #FFFFFF) }
    Nodes     : Array[1..MAX_SVG_NODES] Of TSvgNode;
    NodeCount : Integer;
    Edges     : Array[1..MAX_SVG_EDGES] Of TSvgEdge;
    EdgeCount : Integer;
  End;

  { Types pour le generateur Visio VDX integre (sans outil externe) }
  TVdxNode = Record
    Id        : Integer;             { Identifiant unique du noeud (ShapeID) }
    Name      : String;              { Nom affiche }
    PinX      : Real;                { Position X du centre en pouces }
    PinY      : Real;                { Position Y du centre en pouces }
    Width     : Real;                { Largeur en pouces }
    Height    : Real;                { Hauteur en pouces }
    FillColor : String;              { Couleur de remplissage (ex: #C8C8FF) }
    LineColor : String;              { Couleur de bordure }
    TextId    : String;              { Identifiant texte pour recherche }
  End;

  TVdxEdge = Record
    Id        : Integer;             { Identifiant unique de l'arete (ShapeID) }
    FromId    : Integer;             { ShapeID du noeud source }
    ToId      : Integer;             { ShapeID du noeud destination }
    BeginX    : Real;                { Position X depart en pouces }
    BeginY    : Real;                { Position Y depart en pouces }
    EndX      : Real;                { Position X arrivee en pouces }
    EndY      : Real;                { Position Y arrivee en pouces }
    LineColor : String;              { Couleur de l'arete }
    LinePattern : Integer;           { Motif: 0=solide, 2=tirets }
    LabelText : String;              { Etiquette de l'arete }
  End;

  TVdxGraph = Record
    Title      : String;             { Titre du document }
    PageWidth  : Real;               { Largeur de page en pouces }
    PageHeight : Real;               { Hauteur de page en pouces }
    BgColor    : String;             { Couleur de fond }
    Nodes      : Array[1..MAX_VDX_NODES] Of TVdxNode;
    NodeCount  : Integer;
    Edges      : Array[1..MAX_VDX_EDGES] Of TVdxEdge;
    EdgeCount  : Integer;
    NextShapeId: Integer;            { Prochain ID de forme disponible }
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

  { Variables pour les graphes de dependances (TODO 18) }
  DepGraphOutputDir : String;
  DepGraphFormat    : String;
  DepGraphInitialized : Boolean;

  { Variables pour les diagrammes de classes (TODO 19) }
  ClassDiagOutputDir : String;
  ClassDiagFormat    : String;
  ClassDiagUmlLook   : Boolean;
  ClassDiagInitialized : Boolean;

  { Variables pour les macros et preprocesseur (TODO 20) }
  Macros            : Array[1..MAX_MACROS] Of TMacro;
  MacroCount        : Integer;
  PredefinedMacros  : Array[1..MAX_PREDEFINED] Of TMacro;
  PredefinedCount   : Integer;
  IfDefStack        : Array[1..MAX_INCLUDE_STACK] Of TIfDefStack;
  IfDefStackDepth   : Integer;
  MacrosInitialized : Boolean;

  { Variables pour les espaces de noms et modules (TODO 21) }
  Namespaces         : Array[1..MAX_NAMESPACES] Of TNamespace;
  NamespaceCount     : Integer;
  Modules            : Array[1..MAX_MODULES] Of TModule;
  ModuleCount        : Integer;
  NamespaceStack     : Array[1..MAX_NS_DEPTH] Of Integer;
  NamespaceStackDepth: Integer;
  NamespacesInitialized : Boolean;

  { Variables pour la recherche et indexation (TODO 22) }
  SearchIndex       : Array[1..MAX_SEARCH_ENTRIES] Of TSearchIndex;
  SearchCount       : Integer;
  SearchInitialized : Boolean;

  { Variables pour le support multi-fichiers (TODO 23) }
  SourceFiles        : Array[1..MAX_FILES] Of String;
  SourceCount        : Integer;
  ProcessedFiles     : Array[1..MAX_FILES] Of String;
  ProcessedCount     : Integer;
  MultiFileInitialized : Boolean;

  { Variables pour la validation et les avertissements (TODO 24) }
  Warnings           : Array[1..MAX_WARNINGS] Of TWarning;
  WarningCount       : Integer;
  ErrorCount         : Integer;
  ValidationInitialized : Boolean;

  { Variables pour le rapport final et statistiques (TODO 25) }
  Stats              : TStatistics;
  StartTime          : LongInt;
  StatsInitialized   : Boolean;

  { Variables pour le generateur PNG integre }
  PngGraph           : TPngGraph;
  PngInitialized     : Boolean;
  PngCrcTable        : Array[0..255] Of LongInt;
  PngCrcTableBuilt   : Boolean;

  { Variables pour le generateur SVG integre }
  SvgGraph           : TSvgGraph;
  SvgInitialized     : Boolean;

  { Variables pour le generateur Visio VDX integre }
  VdxGraph           : TVdxGraph;
  VdxInitialized     : Boolean;

  { Variables pour la transformation DCT JPEG (Partie 4) }
  JPEG_CosTable      : TJPEGCosTable;   { Table de cosinus pre-calcules }
  JPEG_DCTInitialized: Boolean;         { Table initialisee? }

  { Variables pour le Zigzag reordering JPEG (Partie 5) }
  JPEG_ZigzagTable   : TJPEGZigzagTable;  { Ordre matriciel -> zigzag }
  JPEG_InvZigzagTable: TJPEGZigzagTable;  { Ordre zigzag -> matriciel }
  JPEG_ZigzagInitialized: Boolean;        { Tables initialisees? }

  { Variables pour l'encodage RLE JPEG (Partie 6) }
  JPEG_RLEInitialized: Boolean;           { Module RLE initialise? }
  JPEG_RLEBlockCount : Integer;           { Compteur de blocs encodes }
  JPEG_RLETotalPairs : Integer;           { Total de paires RLE generees }
  JPEG_RLECategoryTable: Array[0..1023] Of Byte; { Table categorie pre-calculee }

  { Variables pour l'encodeur Huffman JPEG (Partie 7) }
  JPEG_HuffInitialized: Boolean;          { Encodeur Huffman initialise? }
  JPEG_BitBuffer: TJPEGBitBuffer;         { Buffer de bits }
  JPEG_HuffStats: TJPEGHuffStats;         { Statistiques Huffman }
  JPEG_DC_Lum_Codes: TJPEGHuffCodeTable;  { Codes DC luminance }
  JPEG_DC_Chr_Codes: TJPEGHuffCodeTable;  { Codes DC chrominance }
  JPEG_AC_Lum_Codes: TJPEGHuffCodeTable;  { Codes AC luminance }
  JPEG_AC_Chr_Codes: TJPEGHuffCodeTable;  { Codes AC chrominance }

  { Variables pour la conversion couleur JPEG (Partie 8) }
  JPEG_ColorInitialized: Boolean;         { Module couleur initialise? }
  JPEG_ColorStats: TJPEGColorStats;       { Statistiques conversion }
  JPEG_RGB_to_Y_Table: Array[0..255, 0..255, 0..255] Of Byte; { Table Y precalculee - trop grande, on calcule }
  JPEG_ColorConvCount: LongInt;           { Compteur de conversions }

  { Variables pour le sous-echantillonnage JPEG (Partie 9) }
  JPEG_SubsampInitialized: Boolean;       { Module sous-echantillonnage initialise? }
  JPEG_SubsampConfig: TJPEGSubsampConfig; { Configuration courante }
  JPEG_SubsampStats: TJPEGSubsampStats;   { Statistiques }

  { Variables pour l'ecriture fichier JPEG (Partie 10) }
  JPEG_EncoderState: TJPEGEncoderState;   { Etat de l'encodeur }
  JPEG_EncodeStats: TJPEGEncodeStats;     { Statistiques globales }
  JPEG_OutputFile: File;                  { Fichier de sortie }
  JPEG_FileOpen: Boolean;                 { Fichier ouvert? }

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

Function Min(A, B: Integer): Integer;
Begin
  If A < B Then Min := A Else Min := B;
End;

Function Max(A, B: Integer): Integer;
Begin
  If A > B Then Max := A Else Max := B;
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
    ENT_METHOD:     EntityKindToStr := 'method';
    ENT_PROCEDURE:  EntityKindToStr := 'procedure';
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

Function ExtractPascalParams(Const Line: String): String;
{ Extrait les parametres d'une declaration de fonction/procedure Pascal }
Var
  PStart, PEnd: Integer;
Begin
  ExtractPascalParams := '';
  PStart := Pos('(', Line);
  If PStart = 0 Then Exit;
  PEnd := Pos(')', Line);
  If (PEnd = 0) Or (PEnd <= PStart) Then Exit;
  ExtractPascalParams := Copy(Line, PStart + 1, PEnd - PStart - 1);
End;

Function ExtractPascalReturnType(Const Line: String): String;
{ Extrait le type de retour d'une fonction Pascal (apres le :) }
Var
  PColon, PEnd, PSemi, I: Integer;
  SearchStart: Integer;
Begin
  ExtractPascalReturnType := '';
  { Trouver le : apres la parenthese fermante }
  PEnd := Pos(')', Line);
  If PEnd = 0 Then 
    SearchStart := 1
  Else
    SearchStart := PEnd;
  PColon := 0;
  For I := SearchStart To Length(Line) Do
  Begin
    If Line[I] = ':' Then
    Begin
      PColon := I;
      Break;
    End;
  End;
  If PColon = 0 Then Exit;
  { Trouver la position du ; }
  PSemi := Pos(';', Line);
  If (PSemi = 0) Or (PSemi < PColon) Then 
    PSemi := Length(Line) + 1;
  { Extraire le type }
  ExtractPascalReturnType := TrimLine(Copy(Line, PColon + 1, PSemi - PColon - 1));
End;

Function ExtractPascalSignature(Const Line: String; IsProcedure: Boolean): String;
{ Extrait la signature complete d'une procedure/fonction Pascal }
Var
  PEnd: Integer;
Begin
  { Trouver la fin de la declaration (;) }
  PEnd := Pos(';', Line);
  If PEnd = 0 Then PEnd := Length(Line) + 1;
  ExtractPascalSignature := TrimLine(Copy(Line, 1, PEnd - 1));
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
  InRecord: Boolean;
  CurrentClass: String;
  CurrentRecordIdx: Integer;
  RecordFields: String;
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
  InRecord := False;
  CurrentClass := '';
  CurrentRecordIdx := 0;
  RecordFields := '';
  
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
      Begin
        AddEntity(ENT_STRUCT, Name, Name, FileName, LineNum, VIS_PUBLIC);
        InRecord := True;
        CurrentRecordIdx := EntityCount;
        RecordFields := '';
      End;
      Continue;
    End;
    
    { Collecter les champs si dans un record }
    If InRecord Then
    Begin
      { Detecter la fin du record }
      If (UpperLine = 'END;') Or (Copy(UpperLine, 1, 4) = 'END;') Or
         (Copy(UpperLine, 1, 3) = 'END') Then
      Begin
        { Stocker les champs dans la signature de l'entite }
        If (CurrentRecordIdx > 0) And (CurrentRecordIdx <= EntityCount) Then
          Entities[CurrentRecordIdx].Signature := RecordFields;
        InRecord := False;
        CurrentRecordIdx := 0;
        RecordFields := '';
      End
      Else
      Begin
        { Ajouter le champ a la liste }
        If (TrimmedLine <> '') And (Pos(':', TrimmedLine) > 0) Then
        Begin
          If RecordFields <> '' Then
            RecordFields := RecordFields + '; ';
          RecordFields := RecordFields + TrimmedLine;
        End;
      End;
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
        { Remplir les informations supplementaires }
        Entities[EntityCount].Signature := ExtractPascalSignature(TrimmedLine, True);
        Entities[EntityCount].Parameters := ExtractPascalParams(TrimmedLine);
        Entities[EntityCount].ReturnType := ''; { Procedure n'a pas de type retour }
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
        { Remplir les informations supplementaires }
        Entities[EntityCount].Signature := ExtractPascalSignature(TrimmedLine, False);
        Entities[EntityCount].Parameters := ExtractPascalParams(TrimmedLine);
        Entities[EntityCount].ReturnType := ExtractPascalReturnType(TrimmedLine);
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

{ Declaration forward pour ExtractFileName }
Function ExtractFileName(Const Path: String): String; Forward;

Procedure ExtractEntities(Const FileName: String; Lang: TSourceLanguage);
{ Dispatcher vers l extracteur specifique au langage }
Var
  BaseName: String;
Begin
  InitEntities;
  
  { Creer une entite ENT_FILE pour le fichier lui-meme }
  BaseName := ExtractFileName(FileName);
  AddEntity(ENT_FILE, BaseName, FileName, FileName, 1, VIS_PUBLIC);
  
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
  SetConfigOption('FILE_PATTERNS', '*.c *.cc *.cxx *.cpp *.c++ *.java '+
    '*.ii *.ixx *.ipp *.i++ *.inl *.idl *.ddl *.odl *.h *.hh *.hxx *.hpp *.h++ *.l *.cs '+
    '*.d *.php *.php4 *.php5 *.phtml *.inc *.m *.markdown *.md *.mm *.dox '+
    '*.py *.pyw *.f90 *.f95 *.f03 *.f08 *.f18 *.f *.for *.vhd *.vhdl *.ucf *.qsf '+
    '*.ice *.pas *.pp *.p', 0, False);
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
  WriteLn('  --svg             Generer la sortie au format SVG');
  WriteLn('                    (equivalent a -D DOT_IMAGE_FORMAT=svg)');
  WriteLn('  --png             Generer la sortie au format PNG');
  WriteLn('                    (equivalent a -D DOT_IMAGE_FORMAT=png)');
  WriteLn('  --jpeg, -jpg      Generer la sortie au format JPEG');
  WriteLn('                    (equivalent a -D DOT_IMAGE_FORMAT=jpeg)');
  WriteLn('  --visio           Generer la sortie au format Microsoft Visio (VDX)');
  WriteLn('                    (equivalent a -D DOT_IMAGE_FORMAT=visio)');
  WriteLn('  -D NOM=VALEUR     Definir une option de configuration');
  WriteLn('                    Ex: -D DOT_IMAGE_FORMAT=svg');
  WriteLn('                    Ex: -D DOT_IMAGE_FORMAT=png');
  WriteLn('                    Ex: -D DOT_IMAGE_FORMAT=jpeg');
  WriteLn('                    Ex: -D DOT_IMAGE_FORMAT=visio');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  doxygen                     Utiliser le Doxyfile du repertoire courant');
  WriteLn('  doxygen myconfig            Utiliser myconfig comme fichier de config');
  WriteLn('  doxygen -g                  Generer un Doxyfile par defaut');
  WriteLn('  doxygen -g myDoxyfile       Generer myDoxyfile');
  WriteLn('  doxygen -INPUT hello.c      Analyser hello.c directement');
  WriteLn('  doxygen -INPUT program.pas  Analyser program.pas directement');
  WriteLn('  doxygen --svg -INPUT test.c Generer la doc en SVG pour test.c');
  WriteLn('  doxygen --png -INPUT test.c Generer la doc en PNG pour test.c');
  WriteLn('  doxygen --jpeg -INPUT test.c Generer la doc en JPEG pour test.c');
  WriteLn('  doxygen -jpg -INPUT test.c  Generer la doc en JPEG pour test.c');
  WriteLn('  doxygen --visio -INPUT test.c Generer la doc en Visio pour test.c');
  WriteLn('  doxygen -D DOT_IMAGE_FORMAT=svg  Utiliser le format SVG');
  WriteLn('  doxygen -D DOT_IMAGE_FORMAT=png  Utiliser le format PNG');
  WriteLn('  doxygen -D DOT_IMAGE_FORMAT=jpeg Utiliser le format JPEG');
  WriteLn('  doxygen -D DOT_IMAGE_FORMAT=visio Utiliser le format Visio');
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
  O.SvgOutput    := False;
  O.PngOutput    := False;
  O.VdxOutput    := False;
  O.JpegOutput   := False;
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
    Else If (Arg = '--svg') Then
    Begin
      { Extension DEV-COOLS : format de sortie SVG }
      O.SvgOutput := True;
    End
    Else If (Arg = '--png') Then
    Begin
      { Extension DEV-COOLS : format de sortie PNG }
      O.PngOutput := True;
    End
    Else If (Arg = '--jpeg') Or (UpperArg = '-JPG') Then
    Begin
      { Extension DEV-COOLS : format de sortie JPEG }
      O.JpegOutput := True;
    End
    Else If (Arg = '--visio') Then
    Begin
      { Extension DEV-COOLS : format de sortie Microsoft Visio (VDX) }
      O.VdxOutput := True;
    End
    Else If (UpperArg = '-D') Then
    Begin
      { Option de definition : -D NOM=VALEUR }
      If I < ParamCount Then
      Begin
        Inc(I);
        Arg := ParamStr(I);
        { Verifier si c'est DOT_IMAGE_FORMAT=svg, png, jpeg ou visio }
        If Pos('DOT_IMAGE_FORMAT=', UpStr(Arg)) = 1 Then
        Begin
          If UpStr(Copy(Arg, 18, Length(Arg))) = 'SVG' Then
            O.SvgOutput := True
          Else If UpStr(Copy(Arg, 18, Length(Arg))) = 'PNG' Then
            O.PngOutput := True
          Else If (UpStr(Copy(Arg, 18, Length(Arg))) = 'JPEG') Or
                  (UpStr(Copy(Arg, 18, Length(Arg))) = 'JPG') Then
            O.JpegOutput := True
          Else If (UpStr(Copy(Arg, 18, Length(Arg))) = 'VISIO') Or
                  (UpStr(Copy(Arg, 18, Length(Arg))) = 'VDX') Then
            O.VdxOutput := True;
        End;
        { On pourrait ajouter d'autres definitions ici }
      End
      Else
        FatalError('Option -D requiert une definition NOM=VALEUR');
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

{ Declaration forward pour GenerateHtmlDocumentation (definie dans TODO 12) }
Procedure GenerateHtmlDocumentation; Forward;

{ Declarations forward pour les generateurs de diagrammes (TODO 17-19) }
Procedure GenerateCallGraphDocumentation; Forward;
Procedure GenerateDepGraphDocumentation; Forward;
Procedure GenerateClassDiagramDocumentation; Forward;

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

  { Extraire les entites du code source (TODO 08) }
  WriteLn;
  WriteLn('Extraction des entites du code source...');
  ExtractEntities(FileName, Lang);
  
  If EntityCount > 0 Then
  Begin
    ShowExtractedEntities;
    
    { Generer la documentation HTML (TODO 12) }
    WriteLn('Generation de la documentation HTML...');
    WriteLn;
    GenerateHtmlDocumentation;
    
    { Generer les diagrammes de classes si demande (TODO 19) }
    If (GetConfigValue('HAVE_DOT') = 'YES') Or
       (GetConfigValue('HAVE_DOT') = 'yes') Or
       Opts.SvgOutput Or Opts.PngOutput Or Opts.JpegOutput Or Opts.VdxOutput Then
    Begin
      { Definir le format de sortie }
      If Opts.SvgOutput Then
        ClassDiagFormat := 'svg'
      Else If Opts.PngOutput Then
        ClassDiagFormat := 'png'
      Else If Opts.VdxOutput Then
        ClassDiagFormat := 'vdx'
      Else
        ClassDiagFormat := 'png'; { Par defaut PNG }
      
      WriteLn;
      WriteLn('Generation des diagrammes de classes...');
      GenerateClassDiagramDocumentation;
      
      WriteLn;
      WriteLn('Generation des graphes d''appels...');
      GenerateCallGraphDocumentation;
      
      WriteLn;
      WriteLn('Generation des graphes de dependances...');
      GenerateDepGraphDocumentation;
    End;
  End
  Else
  Begin
    WriteLn('Aucune entite documentee trouvee.');
    WriteLn;
    WriteLn('Note: Pour generer de la documentation, ajoutez des commentaires');
    WriteLn('      Doxygen dans votre code source.');
  End;
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
  HtmlHeader := HtmlHeader + '<a href="functions.html">Fonctions</a>';
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
{ Ecrit le header HTML dans un fichier en plusieurs parties }
Begin
  Write(F, '<!DOCTYPE html><html><head>');
  Write(F, '<meta charset="UTF-8">');
  Write(F, '<title>', EscapeHtml(Title), ' - ', EscapeHtml(HtmlProjectName), '</title>');
  WriteLn(F, '<link rel="stylesheet" href="doxygen.css">');
  Write(F, '</head><body>');
  Write(F, '<div class="header"><h1>', EscapeHtml(HtmlProjectName), '</h1>');
  WriteLn(F, '<p>', EscapeHtml(HtmlProjectBrief), '</p></div>');
  Write(F, '<div class="nav">');
  Write(F, '<a href="index.html">Index</a>');
  Write(F, '<a href="classes.html">Classes</a>');
  Write(F, '<a href="functions.html">Fonctions</a>');
  WriteLn(F, '<a href="files.html">Fichiers</a>');
  Write(F, '</div><div class="content">');
End;

Procedure WriteHtmlFooter(Var F: Text);
{ Ecrit le footer HTML dans un fichier }
Begin
  Write(F, HtmlFooter);
End;

Procedure GenerateHtmlFile(Const Entity: TEntity; Var OutFile: Text);
{ Genere la page HTML pour une entite }
Var
  IsStruct: Boolean;
Begin
  WriteHtmlHeader(OutFile, Entity.Name);
  
  WriteLn(OutFile, '<div class="entity">');
  WriteLn(OutFile, '<h2>', EscapeHtml(EntityKindToStr(Entity.Kind)), ': ',
    EscapeHtml(Entity.Name), '</h2>');
  
  IsStruct := Entity.Kind In [ENT_STRUCT, ENT_CLASS, ENT_UNION];
  
  { Signature ou Champs selon le type d'entite }
  If Entity.Signature <> '' Then
  Begin
    WriteLn(OutFile, '<div class="signature">');
    If IsStruct Then
      WriteLn(OutFile, '<h3>Champs</h3>')
    Else
      WriteLn(OutFile, '<h3>Signature</h3>');
    WriteLn(OutFile, '<pre><code>', EscapeHtml(Entity.Signature), '</code></pre>');
    WriteLn(OutFile, '</div>');
  End;
  
  { Brief description }
  If Entity.BriefDesc <> '' Then
  Begin
    WriteLn(OutFile, '<div class="brief">');
    WriteLn(OutFile, '<h3>Resume</h3>');
    WriteLn(OutFile, '<p><strong>', EscapeHtml(Entity.BriefDesc), '</strong></p>');
    WriteLn(OutFile, '</div>');
  End;
  
  { Detailed description }
  If Entity.DetailedDesc <> '' Then
  Begin
    WriteLn(OutFile, '<div class="detailed">');
    WriteLn(OutFile, '<h3>Description detaillee</h3>');
    WriteLn(OutFile, '<p>', EscapeHtml(Entity.DetailedDesc), '</p>');
    WriteLn(OutFile, '</div>');
  End;
  
  { Parameters }
  If Entity.Parameters <> '' Then
  Begin
    WriteLn(OutFile, '<div class="parameters">');
    WriteLn(OutFile, '<h3>Parametres</h3>');
    WriteLn(OutFile, '<p><code>', EscapeHtml(Entity.Parameters), '</code></p>');
    WriteLn(OutFile, '</div>');
  End;
  
  { Return type }
  If Entity.ReturnType <> '' Then
  Begin
    WriteLn(OutFile, '<div class="returntype">');
    WriteLn(OutFile, '<h3>Type de retour</h3>');
    WriteLn(OutFile, '<p><code>', EscapeHtml(Entity.ReturnType), '</code></p>');
    WriteLn(OutFile, '</div>');
  End;
  
  { File location }
  WriteLn(OutFile, '<div class="location">');
  WriteLn(OutFile, '<h3>Emplacement</h3>');
  WriteLn(OutFile, '<p>Defini dans <code>', EscapeHtml(Entity.FileName), '</code>');
  If Entity.Line > 0 Then
    Write(OutFile, ' a la ligne ', Entity.Line);
  WriteLn(OutFile, '</p>');
  WriteLn(OutFile, '</div>');
  
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
  WriteLn(OutFile, '<li><a href="functions.html">Liste des fonctions</a></li>');
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

Procedure GenerateHtmlFunctions(Var OutFile: Text);
{ Genere la page de liste des fonctions (functions.html) }
Var
  I: Integer;
  HasFunctions: Boolean;
Begin
  WriteHtmlHeader(OutFile, 'Fonctions');
  
  WriteLn(OutFile, '<h1>Liste des fonctions</h1>');
  
  HasFunctions := False;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_FUNCTION, ENT_METHOD, ENT_PROCEDURE] Then
    Begin
      If Not HasFunctions Then
      Begin
        WriteLn(OutFile, '<ul>');
        HasFunctions := True;
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
  
  If HasFunctions Then
    WriteLn(OutFile, '</ul>')
  Else
    WriteLn(OutFile, '<p>Aucune fonction documentee.</p>');
  
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
  WriteLn(F, 'body{font-family:Arial,sans-serif;margin:0;padding:0}');
  WriteLn(F, '.header{background:#3f51b5;color:white;padding:20px}');
  WriteLn(F, '.header h1{margin:0}');
  WriteLn(F, '.nav{background:#f5f5f5;padding:10px}');
  WriteLn(F, '.nav a{margin-right:15px;color:#3f51b5;text-decoration:none}');
  WriteLn(F, '.content{padding:20px;max-width:1200px;margin:0 auto}');
  WriteLn(F, '.entity{margin-bottom:30px;padding:15px;background:#fafafa;border-radius:4px}');
  WriteLn(F, '.signature{background:#263238;color:#aed581;padding:10px;font-family:monospace}');
  WriteLn(F, '.footer{background:#f5f5f5;padding:15px;text-align:center;margin-top:40px}');
  WriteLn(F, 'table{border-collapse:collapse;width:100%}');
  WriteLn(F, 'th,td{border:1px solid #ddd;padding:10px;text-align:left}');
  WriteLn(F, 'th{background:#f5f5f5}');
  WriteLn(F, 'a{color:#3f51b5}');
  WriteLn(F, 'code{background:#f5f5f5;padding:2px 6px;border-radius:3px}');
  WriteLn(F, 'h1,h2{color:#333}');
  WriteLn(F, '.location{font-size:0.9em;color:#666}');
  WriteLn(F, 'ul{list-style-type:none;padding:0}');
  WriteLn(F, 'ul li{padding:5px 0}');
  
  Close(F);
  InfoMsg('Fichier CSS genere: doxygen.css');
End;

Procedure CreateHtmlDirectory;
{ Cree le repertoire de sortie HTML avec les repertoires parents }
Var
  ParentDir: String;
  P: Integer;
Begin
  { Creer d'abord le repertoire parent si necessaire }
  ParentDir := HtmlOutputDir;
  { Retirer le dernier / s'il y en a }
  If (Length(ParentDir) > 0) And (ParentDir[Length(ParentDir)] = '/') Then
    Delete(ParentDir, Length(ParentDir), 1);
  { Trouver le repertoire parent }
  P := Length(ParentDir);
  While (P > 0) And (ParentDir[P] <> '/') Do
    Dec(P);
  If P > 0 Then
  Begin
    ParentDir := Copy(ParentDir, 1, P - 1);
    { Creer le repertoire parent }
    {$I-}
    MkDir(ParentDir);
    {$I+}
    If IOResult <> 0 Then
      { Le repertoire existe peut-etre deja };
  End;
  { Creer le repertoire de sortie }
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
  
  { Generer la page des fonctions }
  Assign(F, HtmlOutputDir + 'functions.html');
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateHtmlFunctions(F);
    Close(F);
    InfoMsg('Page fonctions generee: functions.html');
  End
  Else
    WarnMsg('Impossible de creer functions.html');
  
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
  WriteLn('  Fichiers generes: ', EntityCount + 6);
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
  MemberFound: Boolean;
  EntityId: Integer;
Begin
  EntityId := EntityIdx;
  { Date courante }
  CurrentDate := 'April 2026';
  
  { Entete de la page MAN }
  GenerateManHeader(OutFile, Entity.Name, '3', CurrentDate, 
                    ManProjectName, MAN_MANUAL_DEFAULT);
  
  { Section NAME }
  GenerateManSection(OutFile, 'NAME');
  Write(OutFile, Entity.Name);
  If Entity.BriefDesc <> '' Then
    WriteLn(OutFile, ' \- ', EscapeMan(Entity.BriefDesc))
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
        WriteLn(OutFile, '(', EscapeMan(Entity.Parameters), ')');
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
  If Entity.DetailedDesc <> '' Then
    WriteLn(OutFile, EscapeMan(Entity.DetailedDesc))
  Else If Entity.BriefDesc <> '' Then
    WriteLn(OutFile, EscapeMan(Entity.BriefDesc))
  Else
    WriteLn(OutFile, 'No description available.');
  
  { Section MEMBERS pour les classes/structures }
  { Note: Les membres sont lies via ParentId, parcourir les entites }
  If Entity.Kind In [ENT_CLASS, ENT_STRUCT, ENT_UNION, ENT_ENUM] Then
  Begin
    MemberFound := False;
    For I := 1 To EntityCount Do
    Begin
      If Entities[I].ParentId = EntityId Then
      Begin
        If Not MemberFound Then
        Begin
          GenerateManSection(OutFile, 'MEMBERS');
          MemberFound := True;
        End;
        MemberEntity := Entities[I];
        GenerateManParagraph(OutFile);
        GenerateManBold(OutFile, MemberEntity.Name);
        WriteLn(OutFile);
        If MemberEntity.BriefDesc <> '' Then
          WriteLn(OutFile, EscapeMan(MemberEntity.BriefDesc));
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
  WriteLn(OutFile, 'Documentation generated by DOXYGEN.');
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

{ ============================================================
  GENERATEUR PNG INTEGRE (SANS OUTIL EXTERNE)
  
  Ce module permet de generer des fichiers PNG directement
  sans avoir besoin de Graphviz ou d'autres outils externes.
  Il inclut:
  - Table CRC32 pour les chunks PNG
  - Compression simple (non-compresse avec DEFLATE stored)
  - Dessin de lignes, rectangles, et texte simple
  - Parser DOT basique pour lire les fichiers .dot
  - Generation de l'image PNG
  ============================================================ }

Procedure BuildCrcTable;
{ Construit la table CRC32 utilisee par PNG }
Var
  I, J: Integer;
  C: LongInt;
Begin
  If PngCrcTableBuilt Then Exit;
  
  For I := 0 To 255 Do
  Begin
    C := I;
    For J := 0 To 7 Do
    Begin
      If (C And 1) <> 0 Then
        C := LongInt($EDB88320) Xor (C Shr 1)
      Else
        C := C Shr 1;
    End;
    PngCrcTable[I] := C;
  End;
  
  PngCrcTableBuilt := True;
End;

Function UpdateCrc(Crc: LongInt; Const Data: Array Of Byte; Len: Integer): LongInt;
{ Met a jour le CRC32 avec les donnees fournies }
Var
  I: Integer;
Begin
  If Not PngCrcTableBuilt Then BuildCrcTable;
  
  For I := 0 To Len - 1 Do
    Crc := PngCrcTable[(Crc Xor Data[I]) And $FF] Xor (Crc Shr 8);
  
  UpdateCrc := Crc;
End;

Function CalcCrc(Const Data: Array Of Byte; Len: Integer): LongInt;
{ Calcule le CRC32 des donnees }
Begin
  CalcCrc := UpdateCrc(LongInt($FFFFFFFF), Data, Len) Xor LongInt($FFFFFFFF);
End;

Procedure InitPngGraph;
{ Initialise le graphe PNG }
Var
  I: Integer;
Begin
  PngGraph.Title := '';
  PngGraph.Width := PNG_DEFAULT_WIDTH;
  PngGraph.Height := PNG_DEFAULT_HEIGHT;
  PngGraph.BgColor.R := 255;
  PngGraph.BgColor.G := 255;
  PngGraph.BgColor.B := 255;
  PngGraph.NodeCount := 0;
  PngGraph.EdgeCount := 0;
  
  For I := 1 To MAX_PNG_NODES Do
  Begin
    PngGraph.Nodes[I].Id := '';
    PngGraph.Nodes[I].Name := '';
    PngGraph.Nodes[I].X := 0;
    PngGraph.Nodes[I].Y := 0;
    PngGraph.Nodes[I].W := PNG_NODE_WIDTH;
    PngGraph.Nodes[I].H := PNG_NODE_HEIGHT;
    PngGraph.Nodes[I].Color.R := 200;
    PngGraph.Nodes[I].Color.G := 200;
    PngGraph.Nodes[I].Color.B := 255;
    PngGraph.Nodes[I].Shape := 'box';
  End;
  
  For I := 1 To MAX_PNG_EDGES Do
  Begin
    PngGraph.Edges[I].FromId := '';
    PngGraph.Edges[I].ToId := '';
    PngGraph.Edges[I].FromX := 0;
    PngGraph.Edges[I].FromY := 0;
    PngGraph.Edges[I].ToX := 0;
    PngGraph.Edges[I].ToY := 0;
    PngGraph.Edges[I].Color.R := 0;
    PngGraph.Edges[I].Color.G := 0;
    PngGraph.Edges[I].Color.B := 0;
    PngGraph.Edges[I].Style := 'solid';
    PngGraph.Edges[I].LabelText := '';
  End;
  
  PngInitialized := True;
End;

Function AddPngNode(Const Id, Name: String): Integer;
{ Ajoute un noeud au graphe PNG }
Var
  Idx: Integer;
Begin
  If Not PngInitialized Then InitPngGraph;
  
  If PngGraph.NodeCount >= MAX_PNG_NODES Then
  Begin
    AddPngNode := 0;
    Exit;
  End;
  
  Inc(PngGraph.NodeCount);
  Idx := PngGraph.NodeCount;
  
  PngGraph.Nodes[Idx].Id := Id;
  PngGraph.Nodes[Idx].Name := Name;
  PngGraph.Nodes[Idx].W := Length(Name) * PNG_FONT_WIDTH + 20;
  If PngGraph.Nodes[Idx].W < PNG_NODE_WIDTH Then
    PngGraph.Nodes[Idx].W := PNG_NODE_WIDTH;
  PngGraph.Nodes[Idx].H := PNG_NODE_HEIGHT;
  
  AddPngNode := Idx;
End;

Function FindPngNode(Const Id: String): Integer;
{ Trouve un noeud par son ID }
Var
  I: Integer;
Begin
  FindPngNode := 0;
  For I := 1 To PngGraph.NodeCount Do
  Begin
    If PngGraph.Nodes[I].Id = Id Then
    Begin
      FindPngNode := I;
      Exit;
    End;
  End;
End;

Function AddPngEdge(Const FromId, ToId: String): Integer;
{ Ajoute une arete au graphe PNG }
Var
  Idx: Integer;
Begin
  If Not PngInitialized Then InitPngGraph;
  
  If PngGraph.EdgeCount >= MAX_PNG_EDGES Then
  Begin
    AddPngEdge := 0;
    Exit;
  End;
  
  Inc(PngGraph.EdgeCount);
  Idx := PngGraph.EdgeCount;
  
  PngGraph.Edges[Idx].FromId := FromId;
  PngGraph.Edges[Idx].ToId := ToId;
  
  AddPngEdge := Idx;
End;

Procedure LayoutPngGraph;
{ Calcule la disposition des noeuds dans le graphe }
Var
  I, Row, Col: Integer;
  MaxCols, MaxRows: Integer;
  StartX, StartY: Integer;
Begin
  If PngGraph.NodeCount = 0 Then Exit;
  
  { Disposition simple en grille }
  MaxCols := 4;
  If PngGraph.NodeCount <= 4 Then MaxCols := PngGraph.NodeCount;
  MaxRows := (PngGraph.NodeCount + MaxCols - 1) Div MaxCols;
  
  { Calculer la taille de l'image }
  PngGraph.Width := MaxCols * (PNG_NODE_WIDTH + PNG_NODE_MARGIN * 2) + PNG_NODE_MARGIN * 2;
  PngGraph.Height := MaxRows * (PNG_NODE_HEIGHT + PNG_NODE_MARGIN * 2) + PNG_NODE_MARGIN * 2;
  
  If PngGraph.Width < PNG_DEFAULT_WIDTH Then PngGraph.Width := PNG_DEFAULT_WIDTH;
  If PngGraph.Height < 200 Then PngGraph.Height := 200;
  
  { Limiter la taille }
  If PngGraph.Width > PNG_MAX_WIDTH Then PngGraph.Width := PNG_MAX_WIDTH;
  If PngGraph.Height > PNG_MAX_HEIGHT Then PngGraph.Height := PNG_MAX_HEIGHT;
  
  { Positionner les noeuds }
  StartX := PNG_NODE_MARGIN * 2;
  StartY := PNG_NODE_MARGIN * 2;
  
  For I := 1 To PngGraph.NodeCount Do
  Begin
    Row := (I - 1) Div MaxCols;
    Col := (I - 1) Mod MaxCols;
    
    PngGraph.Nodes[I].X := StartX + Col * (PNG_NODE_WIDTH + PNG_NODE_MARGIN * 2);
    PngGraph.Nodes[I].Y := StartY + Row * (PNG_NODE_HEIGHT + PNG_NODE_MARGIN * 2);
  End;
  
  { Calculer les positions des aretes }
  For I := 1 To PngGraph.EdgeCount Do
  Begin
    { Trouver les noeuds source et destination }
    Row := FindPngNode(PngGraph.Edges[I].FromId);
    Col := FindPngNode(PngGraph.Edges[I].ToId);
    
    If (Row > 0) And (Col > 0) Then
    Begin
      { Position de depart: bas du noeud source }
      PngGraph.Edges[I].FromX := PngGraph.Nodes[Row].X + PngGraph.Nodes[Row].W Div 2;
      PngGraph.Edges[I].FromY := PngGraph.Nodes[Row].Y + PngGraph.Nodes[Row].H;
      
      { Position d'arrivee: haut du noeud destination }
      PngGraph.Edges[I].ToX := PngGraph.Nodes[Col].X + PngGraph.Nodes[Col].W Div 2;
      PngGraph.Edges[I].ToY := PngGraph.Nodes[Col].Y;
    End;
  End;
End;

Procedure WritePngByte(Var F: File; B: Byte);
{ Ecrit un octet dans le fichier PNG }
Begin
  BlockWrite(F, B, 1);
End;

Procedure WritePngWord(Var F: File; W: Word);
{ Ecrit un mot de 16 bits en big-endian }
Begin
  WritePngByte(F, Hi(W));
  WritePngByte(F, Lo(W));
End;

Procedure WritePngDWord(Var F: File; DW: LongInt);
{ Ecrit un mot de 32 bits en big-endian }
Begin
  WritePngByte(F, (DW Shr 24) And $FF);
  WritePngByte(F, (DW Shr 16) And $FF);
  WritePngByte(F, (DW Shr 8) And $FF);
  WritePngByte(F, DW And $FF);
End;

Procedure WritePngSignature(Var F: File);
{ Ecrit la signature PNG de 8 octets }
Begin
  WritePngByte(F, PNG_SIGNATURE_1);
  WritePngByte(F, PNG_SIGNATURE_2);
  WritePngByte(F, PNG_SIGNATURE_3);
  WritePngByte(F, PNG_SIGNATURE_4);
  WritePngByte(F, PNG_SIGNATURE_5);
  WritePngByte(F, PNG_SIGNATURE_6);
  WritePngByte(F, PNG_SIGNATURE_7);
  WritePngByte(F, PNG_SIGNATURE_8);
End;

Procedure WritePngChunk(Var F: File; ChunkType: String; Const Data: Array Of Byte; DataLen: LongInt);
{ Ecrit un chunk PNG complet avec CRC }
Var
  TypeAndData: Array Of Byte;
  I: LongInt;
  Crc: LongInt;
Begin
  { Longueur des donnees }
  WritePngDWord(F, DataLen);
  
  { Allouer le buffer pour type + donnees }
  SetLength(TypeAndData, DataLen + 4);
  
  { Type du chunk (4 caracteres) }
  For I := 1 To 4 Do
    TypeAndData[I - 1] := Ord(ChunkType[I]);
  
  { Copier les donnees }
  For I := 0 To DataLen - 1 Do
    TypeAndData[I + 4] := Data[I];
  
  { Ecrire le type }
  For I := 0 To 3 Do
    WritePngByte(F, TypeAndData[I]);
  
  { Ecrire les donnees }
  For I := 0 To DataLen - 1 Do
    WritePngByte(F, Data[I]);
  
  { Calculer et ecrire le CRC }
  Crc := CalcCrc(TypeAndData, DataLen + 4);
  WritePngDWord(F, Crc);
  
  { Liberer la memoire }
  SetLength(TypeAndData, 0);
End;

Procedure WritePngIHDR(Var F: File; Width, Height: Integer);
{ Ecrit le chunk IHDR }
Var
  Data: Array[0..12] Of Byte;
Begin
  { Largeur (4 bytes big-endian) }
  Data[0] := (Width Shr 24) And $FF;
  Data[1] := (Width Shr 16) And $FF;
  Data[2] := (Width Shr 8) And $FF;
  Data[3] := Width And $FF;
  
  { Hauteur (4 bytes big-endian) }
  Data[4] := (Height Shr 24) And $FF;
  Data[5] := (Height Shr 16) And $FF;
  Data[6] := (Height Shr 8) And $FF;
  Data[7] := Height And $FF;
  
  { Bit depth: 8 bits par canal }
  Data[8] := 8;
  
  { Color type: RGB (2) }
  Data[9] := PNG_COLOR_RGB;
  
  { Compression method: 0 (deflate) }
  Data[10] := PNG_COMPRESSION;
  
  { Filter method: 0 }
  Data[11] := 0;
  
  { Interlace method: 0 (pas d'entrelacement) }
  Data[12] := PNG_INTERLACE_NONE;
  
  WritePngChunk(F, 'IHDR', Data, 13);
End;

Procedure WritePngIDAT(Var F: File; Const Pixels: Array Of TPngPixelRow; Width, Height: Integer);
{ Ecrit le chunk IDAT avec les donnees d'image non-compressees }
Var
  RawData: Array Of Byte;
  CompData: Array Of Byte;
  RawLen, CompLen: LongInt;
  X, Y, Idx: Integer;
  Adler32: LongInt;
  S1, S2: LongInt;
  NumBlocks, BlockNum: Integer;
  CompIdx, SrcIdx: LongInt;
  ActualBlockLen, Remaining: LongInt;
Begin
  { Taille des donnees brutes: (1 + Width * 3) * Height }
  RawLen := (1 + Width * 3) * Height;
  SetLength(RawData, RawLen);
  
  { Construire les donnees brutes (filtre 0 = aucun pour chaque ligne) }
  Idx := 0;
  For Y := 0 To Height - 1 Do
  Begin
    { Octet de filtre (0 = aucun) }
    RawData[Idx] := PNG_FILTER_NONE;
    Inc(Idx);
    
    { Pixels RGB }
    For X := 0 To Width - 1 Do
    Begin
      RawData[Idx] := Pixels[Y][X].R;
      Inc(Idx);
      RawData[Idx] := Pixels[Y][X].G;
      Inc(Idx);
      RawData[Idx] := Pixels[Y][X].B;
      Inc(Idx);
    End;
  End;
  
  { Calculer Adler-32 des donnees brutes }
  S1 := 1;
  S2 := 0;
  For Idx := 0 To RawLen - 1 Do
  Begin
    S1 := (S1 + RawData[Idx]) Mod 65521;
    S2 := (S2 + S1) Mod 65521;
  End;
  Adler32 := (S2 Shl 16) Or S1;
  
  { Creer le flux zlib non-compresse (stored blocks) }
  { Les donnees sont divisees en blocs de 65535 bytes max }
  { Format: zlib header (2 bytes) + stored blocks + Adler-32 (4 bytes) }
  
  { Calculer le nombre de blocs necessaires }
  NumBlocks := (RawLen + 65534) Div 65535;
  If NumBlocks < 1 Then NumBlocks := 1;
  
  { Calculer la taille totale: header + (5 bytes header * nb blocs) + data + adler }
  CompLen := 2 + (5 * NumBlocks) + RawLen + 4;
  SetLength(CompData, CompLen);
  
  { En-tete zlib }
  CompData[0] := $78; { CMF: deflate, 32K window }
  CompData[1] := $01; { FLG: no dict, check bits }
  
  CompIdx := 2;
  SrcIdx := 0;
  
  { Ecrire les blocs stored }
  For BlockNum := 1 To NumBlocks Do
  Begin
    { Calculer la taille de ce bloc }
    Remaining := RawLen - SrcIdx;
    If Remaining > 65535 Then
      ActualBlockLen := 65535
    Else
      ActualBlockLen := Remaining;
    
    { BFINAL=1 si dernier bloc, BTYPE=00 (stored) }
    If BlockNum = NumBlocks Then
      CompData[CompIdx] := $01  { BFINAL=1 }
    Else
      CompData[CompIdx] := $00; { BFINAL=0 }
    Inc(CompIdx);
    
    { Longueur du bloc (little-endian) }
    CompData[CompIdx] := ActualBlockLen And $FF;
    Inc(CompIdx);
    CompData[CompIdx] := (ActualBlockLen Shr 8) And $FF;
    Inc(CompIdx);
    
    { Complement de la longueur }
    CompData[CompIdx] := (Not ActualBlockLen) And $FF;
    Inc(CompIdx);
    CompData[CompIdx] := ((Not ActualBlockLen) Shr 8) And $FF;
    Inc(CompIdx);
    
    { Copier les donnees de ce bloc }
    For Idx := 0 To ActualBlockLen - 1 Do
    Begin
      CompData[CompIdx] := RawData[SrcIdx];
      Inc(CompIdx);
      Inc(SrcIdx);
    End;
  End;
  
  { Adler-32 (big-endian) }
  CompData[CompIdx] := (Adler32 Shr 24) And $FF;
  CompData[CompIdx + 1] := (Adler32 Shr 16) And $FF;
  CompData[CompIdx + 2] := (Adler32 Shr 8) And $FF;
  CompData[CompIdx + 3] := Adler32 And $FF;
  
  WritePngChunk(F, 'IDAT', CompData, CompLen);
  
  SetLength(RawData, 0);
  SetLength(CompData, 0);
End;

Procedure WritePngIEND(Var F: File);
{ Ecrit le chunk IEND (fin du fichier PNG) }
Var
  EmptyData: Array[0..0] Of Byte;
Begin
  WritePngChunk(F, 'IEND', EmptyData, 0);
End;

Procedure DrawPngLine(Var Pixels: Array Of TPngPixelRow; X1, Y1, X2, Y2: Integer; 
                       Width, Height: Integer; Color: TPngColor);
{ Dessine une ligne dans le buffer de pixels (algorithme de Bresenham) }
Var
  DX, DY, SX, SY, Err, E2: Integer;
Begin
  DX := Abs(X2 - X1);
  If X1 < X2 Then SX := 1 Else SX := -1;
  DY := -Abs(Y2 - Y1);
  If Y1 < Y2 Then SY := 1 Else SY := -1;
  Err := DX + DY;
  
  While True Do
  Begin
    If (X1 >= 0) And (X1 < Width) And (Y1 >= 0) And (Y1 < Height) Then
      Pixels[Y1][X1] := Color;
    
    If (X1 = X2) And (Y1 = Y2) Then Break;
    
    E2 := 2 * Err;
    If E2 >= DY Then
    Begin
      If X1 = X2 Then Break;
      Err := Err + DY;
      X1 := X1 + SX;
    End;
    If E2 <= DX Then
    Begin
      If Y1 = Y2 Then Break;
      Err := Err + DX;
      Y1 := Y1 + SY;
    End;
  End;
End;

Procedure DrawPngRect(Var Pixels: Array Of TPngPixelRow; X, Y, W, H: Integer;
                       Width, Height: Integer; FillColor, BorderColor: TPngColor;
                       Filled: Boolean);
{ Dessine un rectangle dans le buffer de pixels }
Var
  I, J: Integer;
Begin
  { Remplissage }
  If Filled Then
  Begin
    For J := Y To Y + H - 1 Do
    Begin
      If (J >= 0) And (J < Height) Then
      Begin
        For I := X To X + W - 1 Do
        Begin
          If (I >= 0) And (I < Width) Then
            Pixels[J][I] := FillColor;
        End;
      End;
    End;
  End;
  
  { Bordure }
  DrawPngLine(Pixels, X, Y, X + W - 1, Y, Width, Height, BorderColor);
  DrawPngLine(Pixels, X + W - 1, Y, X + W - 1, Y + H - 1, Width, Height, BorderColor);
  DrawPngLine(Pixels, X + W - 1, Y + H - 1, X, Y + H - 1, Width, Height, BorderColor);
  DrawPngLine(Pixels, X, Y + H - 1, X, Y, Width, Height, BorderColor);
End;

Procedure DrawPngArrow(Var Pixels: Array Of TPngPixelRow; X1, Y1, X2, Y2: Integer;
                        Width, Height: Integer; Color: TPngColor);
{ Dessine une fleche de X1,Y1 vers X2,Y2 }
Var
  DX, DY: Integer;
  Len: Real;
  UX, UY: Real;
  AX, AY: Integer;
  ArrowLen: Integer;
Begin
  { Dessiner la ligne principale }
  DrawPngLine(Pixels, X1, Y1, X2, Y2, Width, Height, Color);
  
  { Dessiner la pointe de fleche }
  ArrowLen := 8;
  DX := X2 - X1;
  DY := Y2 - Y1;
  Len := Sqrt(DX * DX + DY * DY);
  
  If Len > 0 Then
  Begin
    UX := DX / Len;
    UY := DY / Len;
    
    { Points de la pointe }
    AX := X2 - Round(ArrowLen * UX + ArrowLen * 0.5 * UY);
    AY := Y2 - Round(ArrowLen * UY - ArrowLen * 0.5 * UX);
    DrawPngLine(Pixels, X2, Y2, AX, AY, Width, Height, Color);
    
    AX := X2 - Round(ArrowLen * UX - ArrowLen * 0.5 * UY);
    AY := Y2 - Round(ArrowLen * UY + ArrowLen * 0.5 * UX);
    DrawPngLine(Pixels, X2, Y2, AX, AY, Width, Height, Color);
  End;
End;

Procedure DrawPngText(Var Pixels: Array Of TPngPixelRow; X, Y: Integer;
                       Const Text: String; Width, Height: Integer; Color: TPngColor);
{ Dessine du texte simple (police bitmap 5x7 basique) }
Const
  { Police bitmap 5x7 pour les caracteres A-Z, a-z, 0-9 et quelques symboles }
  Font5x7: Array['0'..'z'] Of Array[0..6] Of Byte = (
    { 0 } ($3E, $51, $49, $45, $3E, $00, $00),
    { 1 } ($00, $42, $7F, $40, $00, $00, $00),
    { 2 } ($42, $61, $51, $49, $46, $00, $00),
    { 3 } ($21, $41, $45, $4B, $31, $00, $00),
    { 4 } ($18, $14, $12, $7F, $10, $00, $00),
    { 5 } ($27, $45, $45, $45, $39, $00, $00),
    { 6 } ($3C, $4A, $49, $49, $30, $00, $00),
    { 7 } ($01, $71, $09, $05, $03, $00, $00),
    { 8 } ($36, $49, $49, $49, $36, $00, $00),
    { 9 } ($06, $49, $49, $29, $1E, $00, $00),
    { : } ($00, $36, $36, $00, $00, $00, $00),
    { ; } ($00, $56, $36, $00, $00, $00, $00),
    { < } ($08, $14, $22, $41, $00, $00, $00),
    { = } ($14, $14, $14, $14, $14, $00, $00),
    { > } ($41, $22, $14, $08, $00, $00, $00),
    { ? } ($02, $01, $51, $09, $06, $00, $00),
    { @ } ($32, $49, $79, $41, $3E, $00, $00),
    { A } ($7E, $11, $11, $11, $7E, $00, $00),
    { B } ($7F, $49, $49, $49, $36, $00, $00),
    { C } ($3E, $41, $41, $41, $22, $00, $00),
    { D } ($7F, $41, $41, $22, $1C, $00, $00),
    { E } ($7F, $49, $49, $49, $41, $00, $00),
    { F } ($7F, $09, $09, $09, $01, $00, $00),
    { G } ($3E, $41, $49, $49, $7A, $00, $00),
    { H } ($7F, $08, $08, $08, $7F, $00, $00),
    { I } ($00, $41, $7F, $41, $00, $00, $00),
    { J } ($20, $40, $41, $3F, $01, $00, $00),
    { K } ($7F, $08, $14, $22, $41, $00, $00),
    { L } ($7F, $40, $40, $40, $40, $00, $00),
    { M } ($7F, $02, $0C, $02, $7F, $00, $00),
    { N } ($7F, $04, $08, $10, $7F, $00, $00),
    { O } ($3E, $41, $41, $41, $3E, $00, $00),
    { P } ($7F, $09, $09, $09, $06, $00, $00),
    { Q } ($3E, $41, $51, $21, $5E, $00, $00),
    { R } ($7F, $09, $19, $29, $46, $00, $00),
    { S } ($46, $49, $49, $49, $31, $00, $00),
    { T } ($01, $01, $7F, $01, $01, $00, $00),
    { U } ($3F, $40, $40, $40, $3F, $00, $00),
    { V } ($1F, $20, $40, $20, $1F, $00, $00),
    { W } ($3F, $40, $38, $40, $3F, $00, $00),
    { X } ($63, $14, $08, $14, $63, $00, $00),
    { Y } ($07, $08, $70, $08, $07, $00, $00),
    { Z } ($61, $51, $49, $45, $43, $00, $00),
    { [ } ($00, $7F, $41, $41, $00, $00, $00),
    { \ } ($02, $04, $08, $10, $20, $00, $00),
    { ] } ($00, $41, $41, $7F, $00, $00, $00),
    { ^ } ($04, $02, $01, $02, $04, $00, $00),
    { _ } ($40, $40, $40, $40, $40, $00, $00),
    { ` } ($00, $01, $02, $04, $00, $00, $00),
    { a } ($20, $54, $54, $54, $78, $00, $00),
    { b } ($7F, $48, $44, $44, $38, $00, $00),
    { c } ($38, $44, $44, $44, $20, $00, $00),
    { d } ($38, $44, $44, $48, $7F, $00, $00),
    { e } ($38, $54, $54, $54, $18, $00, $00),
    { f } ($08, $7E, $09, $01, $02, $00, $00),
    { g } ($0C, $52, $52, $52, $3E, $00, $00),
    { h } ($7F, $08, $04, $04, $78, $00, $00),
    { i } ($00, $44, $7D, $40, $00, $00, $00),
    { j } ($20, $40, $44, $3D, $00, $00, $00),
    { k } ($7F, $10, $28, $44, $00, $00, $00),
    { l } ($00, $41, $7F, $40, $00, $00, $00),
    { m } ($7C, $04, $18, $04, $78, $00, $00),
    { n } ($7C, $08, $04, $04, $78, $00, $00),
    { o } ($38, $44, $44, $44, $38, $00, $00),
    { p } ($7C, $14, $14, $14, $08, $00, $00),
    { q } ($08, $14, $14, $18, $7C, $00, $00),
    { r } ($7C, $08, $04, $04, $08, $00, $00),
    { s } ($48, $54, $54, $54, $20, $00, $00),
    { t } ($04, $3F, $44, $40, $20, $00, $00),
    { u } ($3C, $40, $40, $20, $7C, $00, $00),
    { v } ($1C, $20, $40, $20, $1C, $00, $00),
    { w } ($3C, $40, $30, $40, $3C, $00, $00),
    { x } ($44, $28, $10, $28, $44, $00, $00),
    { y } ($0C, $50, $50, $50, $3C, $00, $00),
    { z } ($44, $64, $54, $4C, $44, $00, $00)
  );
Var
  I, J, K, CharX: Integer;
  Ch: Char;
  Bits: Byte;
Begin
  CharX := X;
  For I := 1 To Length(Text) Do
  Begin
    Ch := Text[I];
    If (Ch >= '0') And (Ch <= 'z') Then
    Begin
      For J := 0 To 6 Do
      Begin
        Bits := Font5x7[Ch][J];
        For K := 0 To 4 Do
        Begin
          If (Bits And (1 Shl K)) <> 0 Then
          Begin
            If (CharX + K >= 0) And (CharX + K < Width) And 
               (Y + J >= 0) And (Y + J < Height) Then
              Pixels[Y + J][CharX + K] := Color;
          End;
        End;
      End;
    End;
    CharX := CharX + 6; { 5 pixels + 1 espace }
  End;
End;

Procedure ParseDotFile(Const DotFileName: String);
{ Parse un fichier DOT simple et remplit PngGraph }
Var
  F: Text;
  Line, TrimmedLine: String;
  I, P1, P2: Integer;
  NodeId, NodeName, FromNode, ToNode: String;
  InGraph: Boolean;
Begin
  If Not PngInitialized Then InitPngGraph;
  
  Assign(F, DotFileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  InGraph := False;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    
    { Supprimer les espaces en debut et fin }
    TrimmedLine := '';
    For I := 1 To Length(Line) Do
      If Line[I] > ' ' Then
      Begin
        TrimmedLine := Copy(Line, I, Length(Line));
        Break;
      End;
    
    For I := Length(TrimmedLine) DownTo 1 Do
      If TrimmedLine[I] > ' ' Then
      Begin
        TrimmedLine := Copy(TrimmedLine, 1, I);
        Break;
      End;
    
    If TrimmedLine = '' Then Continue;
    
    { Detecter le debut du graphe }
    If (Pos('digraph', TrimmedLine) = 1) Or (Pos('graph', TrimmedLine) = 1) Then
    Begin
      InGraph := True;
      { Extraire le titre du graphe }
      P1 := Pos('"', TrimmedLine);
      If P1 > 0 Then
      Begin
        P2 := Pos('"', Copy(TrimmedLine, P1 + 1, Length(TrimmedLine)));
        If P2 > 0 Then
          PngGraph.Title := Copy(TrimmedLine, P1 + 1, P2 - 1);
      End;
      Continue;
    End;
    
    If Not InGraph Then Continue;
    If TrimmedLine = '}' Then Break;
    
    { Ignorer les commentaires et directives }
    If (TrimmedLine[1] = '/') Or (Pos('rankdir', TrimmedLine) = 1) Or
       (Pos('node', TrimmedLine) = 1) Or (Pos('edge', TrimmedLine) = 1) Then
      Continue;
    
    { Detecter une arete: "A" -> "B" }
    P1 := Pos('->', TrimmedLine);
    If P1 > 0 Then
    Begin
      { Extraire les noeuds source et destination }
      FromNode := Copy(TrimmedLine, 1, P1 - 1);
      ToNode := Copy(TrimmedLine, P1 + 2, Length(TrimmedLine));
      
      { Nettoyer les guillemets et espaces }
      While (Length(FromNode) > 0) And (FromNode[Length(FromNode)] <= ' ') Do
        FromNode := Copy(FromNode, 1, Length(FromNode) - 1);
      While (Length(FromNode) > 0) And (FromNode[1] <= ' ') Do
        FromNode := Copy(FromNode, 2, Length(FromNode));
      While (Length(FromNode) > 0) And (FromNode[1] = '"') Do
        FromNode := Copy(FromNode, 2, Length(FromNode));
      While (Length(FromNode) > 0) And (FromNode[Length(FromNode)] = '"') Do
        FromNode := Copy(FromNode, 1, Length(FromNode) - 1);
      
      While (Length(ToNode) > 0) And (ToNode[Length(ToNode)] <= ' ') Do
        ToNode := Copy(ToNode, 1, Length(ToNode) - 1);
      While (Length(ToNode) > 0) And (ToNode[1] <= ' ') Do
        ToNode := Copy(ToNode, 2, Length(ToNode));
      While (Length(ToNode) > 0) And (ToNode[1] = '"') Do
        ToNode := Copy(ToNode, 2, Length(ToNode));
      
      { Enlever le point-virgule et les attributs }
      P2 := Pos(';', ToNode);
      If P2 > 0 Then ToNode := Copy(ToNode, 1, P2 - 1);
      P2 := Pos('[', ToNode);
      If P2 > 0 Then ToNode := Copy(ToNode, 1, P2 - 1);
      P2 := Pos('"', ToNode);
      If P2 > 0 Then ToNode := Copy(ToNode, 1, P2 - 1);
      
      { Ajouter les noeuds s'ils n'existent pas }
      If FindPngNode(FromNode) = 0 Then
        AddPngNode(FromNode, FromNode);
      If FindPngNode(ToNode) = 0 Then
        AddPngNode(ToNode, ToNode);
      
      { Ajouter l'arete }
      AddPngEdge(FromNode, ToNode);
      Continue;
    End;
    
    { Detecter une definition de noeud: "NodeName" [...] }
    P1 := Pos('"', TrimmedLine);
    If P1 > 0 Then
    Begin
      P2 := Pos('"', Copy(TrimmedLine, P1 + 1, Length(TrimmedLine)));
      If P2 > 0 Then
      Begin
        NodeId := Copy(TrimmedLine, P1 + 1, P2 - 1);
        NodeName := NodeId;
        
        { Verifier si ce n'est pas une arete }
        If Pos('->', TrimmedLine) = 0 Then
        Begin
          { Extraire le label si present }
          P1 := Pos('label=', TrimmedLine);
          If P1 > 0 Then
          Begin
            P1 := Pos('"', Copy(TrimmedLine, P1 + 6, Length(TrimmedLine)));
            If P1 > 0 Then
            Begin
              P2 := Pos('"', Copy(TrimmedLine, P1 + 1, Length(TrimmedLine)));
              { Le label serait ici, mais pour simplifier on garde l'ID }
            End;
          End;
          
          { Ajouter le noeud s'il n'existe pas }
          If FindPngNode(NodeId) = 0 Then
            AddPngNode(NodeId, NodeName);
        End;
      End;
    End;
  End;
  
  Close(F);
End;

Procedure RenderPngGraph(Const OutputFileName: String);
{ Genere le fichier PNG a partir du graphe }
Var
  F: File;
  Pixels: Array Of TPngPixelRow;
  I, X, Y: Integer;
  BorderColor, FillColor, TextColor, ArrowColor: TPngColor;
Begin
  If Not PngInitialized Then Exit;
  If PngGraph.NodeCount = 0 Then Exit;
  
  { Calculer la disposition }
  LayoutPngGraph;
  
  { Allouer le buffer de pixels }
  SetLength(Pixels, PngGraph.Height);
  
  { Initialiser avec la couleur de fond }
  For Y := 0 To PngGraph.Height - 1 Do
  Begin
    For X := 0 To PngGraph.Width - 1 Do
      Pixels[Y][X] := PngGraph.BgColor;
  End;
  
  { Dessiner les aretes }
  ArrowColor.R := 64;
  ArrowColor.G := 64;
  ArrowColor.B := 64;
  
  For I := 1 To PngGraph.EdgeCount Do
  Begin
    If (PngGraph.Edges[I].FromX > 0) Or (PngGraph.Edges[I].ToX > 0) Then
    Begin
      DrawPngArrow(Pixels, 
                   PngGraph.Edges[I].FromX, PngGraph.Edges[I].FromY,
                   PngGraph.Edges[I].ToX, PngGraph.Edges[I].ToY,
                   PngGraph.Width, PngGraph.Height, ArrowColor);
    End;
  End;
  
  { Dessiner les noeuds }
  BorderColor.R := 0;
  BorderColor.G := 0;
  BorderColor.B := 128;
  
  TextColor.R := 0;
  TextColor.G := 0;
  TextColor.B := 0;
  
  For I := 1 To PngGraph.NodeCount Do
  Begin
    FillColor := PngGraph.Nodes[I].Color;
    
    { Dessiner le rectangle du noeud }
    DrawPngRect(Pixels, 
                PngGraph.Nodes[I].X, PngGraph.Nodes[I].Y,
                PngGraph.Nodes[I].W, PngGraph.Nodes[I].H,
                PngGraph.Width, PngGraph.Height,
                FillColor, BorderColor, True);
    
    { Dessiner le texte du noeud }
    DrawPngText(Pixels,
                PngGraph.Nodes[I].X + 5,
                PngGraph.Nodes[I].Y + (PngGraph.Nodes[I].H - 7) Div 2,
                PngGraph.Nodes[I].Name,
                PngGraph.Width, PngGraph.Height, TextColor);
  End;
  
  { Dessiner le titre si present }
  If PngGraph.Title <> '' Then
  Begin
    TextColor.R := 0;
    TextColor.G := 0;
    TextColor.B := 0;
    DrawPngText(Pixels, 10, 10, PngGraph.Title, PngGraph.Width, PngGraph.Height, TextColor);
  End;
  
  { Ecrire le fichier PNG }
  Assign(F, OutputFileName);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    SetLength(Pixels, 0);
    Exit;
  End;
  
  { Signature PNG }
  WritePngSignature(F);
  
  { Chunk IHDR }
  WritePngIHDR(F, PngGraph.Width, PngGraph.Height);
  
  { Chunk IDAT }
  WritePngIDAT(F, Pixels, PngGraph.Width, PngGraph.Height);
  
  { Chunk IEND }
  WritePngIEND(F);
  
  Close(F);
  
  SetLength(Pixels, 0);
End;

Procedure RenderDotToPng(Const DotFile, PngFile: String);
{ Fonction principale: lit un fichier DOT et genere un PNG }
Begin
  { Reinitialiser le graphe }
  PngInitialized := False;
  InitPngGraph;
  
  { Parser le fichier DOT }
  ParseDotFile(DotFile);
  
  { Generer le PNG }
  RenderPngGraph(PngFile);
  
  If Not Opts.Quiet Then
    WriteLn('PNG genere (built-in): ', PngFile);
End;

{ ============================================================
  FIN DU GENERATEUR PNG INTEGRE
  ============================================================ }

{ ============================================================
  GENERATEUR SVG INTEGRE (SANS OUTIL EXTERNE)
  
  Ce module permet de generer des fichiers SVG directement
  sans avoir besoin de Graphviz ou d'autres outils externes.
  Il inclut:
  - Ecriture des balises XML/SVG
  - Dessin de lignes, rectangles, fleches et texte
  - Parser DOT pour lire les fichiers .dot
  - Generation de l'image SVG vectorielle
  ============================================================ }

Procedure InitSvgGraph;
{ Initialise le graphe SVG }
Var
  I: Integer;
Begin
  SvgGraph.Title := '';
  SvgGraph.Width := SVG_DEFAULT_WIDTH;
  SvgGraph.Height := SVG_DEFAULT_HEIGHT;
  SvgGraph.BgColor := '#FFFFFF';
  SvgGraph.NodeCount := 0;
  SvgGraph.EdgeCount := 0;
  
  For I := 1 To MAX_SVG_NODES Do
  Begin
    SvgGraph.Nodes[I].Id := '';
    SvgGraph.Nodes[I].Name := '';
    SvgGraph.Nodes[I].X := 0;
    SvgGraph.Nodes[I].Y := 0;
    SvgGraph.Nodes[I].W := SVG_NODE_WIDTH;
    SvgGraph.Nodes[I].H := SVG_NODE_HEIGHT;
    SvgGraph.Nodes[I].FillColor := '#C8C8FF';
    SvgGraph.Nodes[I].StrokeColor := '#000080';
    SvgGraph.Nodes[I].Shape := 'rect';
  End;
  
  For I := 1 To MAX_SVG_EDGES Do
  Begin
    SvgGraph.Edges[I].FromId := '';
    SvgGraph.Edges[I].ToId := '';
    SvgGraph.Edges[I].FromX := 0;
    SvgGraph.Edges[I].FromY := 0;
    SvgGraph.Edges[I].ToX := 0;
    SvgGraph.Edges[I].ToY := 0;
    SvgGraph.Edges[I].StrokeColor := '#404040';
    SvgGraph.Edges[I].Style := 'solid';
    SvgGraph.Edges[I].LabelText := '';
  End;
  
  SvgInitialized := True;
End;

Function AddSvgNode(Const Id, Name: String): Integer;
{ Ajoute un noeud au graphe SVG }
Var
  Idx: Integer;
Begin
  If Not SvgInitialized Then InitSvgGraph;
  
  If SvgGraph.NodeCount >= MAX_SVG_NODES Then
  Begin
    AddSvgNode := 0;
    Exit;
  End;
  
  Inc(SvgGraph.NodeCount);
  Idx := SvgGraph.NodeCount;
  
  SvgGraph.Nodes[Idx].Id := Id;
  SvgGraph.Nodes[Idx].Name := Name;
  { Calculer la largeur en fonction du texte }
  SvgGraph.Nodes[Idx].W := Length(Name) * 8 + 20;
  If SvgGraph.Nodes[Idx].W < SVG_NODE_WIDTH Then
    SvgGraph.Nodes[Idx].W := SVG_NODE_WIDTH;
  SvgGraph.Nodes[Idx].H := SVG_NODE_HEIGHT;
  
  AddSvgNode := Idx;
End;

Function AddSvgEdge(Const FromId, ToId: String): Integer;
{ Ajoute une arete au graphe SVG }
Var
  Idx: Integer;
Begin
  If Not SvgInitialized Then InitSvgGraph;
  
  If SvgGraph.EdgeCount >= MAX_SVG_EDGES Then
  Begin
    AddSvgEdge := 0;
    Exit;
  End;
  
  Inc(SvgGraph.EdgeCount);
  Idx := SvgGraph.EdgeCount;
  
  SvgGraph.Edges[Idx].FromId := FromId;
  SvgGraph.Edges[Idx].ToId := ToId;
  SvgGraph.Edges[Idx].StrokeColor := '#404040';
  SvgGraph.Edges[Idx].Style := 'solid';
  
  AddSvgEdge := Idx;
End;

Function FindSvgNode(Const Id: String): Integer;
{ Trouve un noeud par son ID }
Var
  I: Integer;
Begin
  FindSvgNode := 0;
  For I := 1 To SvgGraph.NodeCount Do
  Begin
    If SvgGraph.Nodes[I].Id = Id Then
    Begin
      FindSvgNode := I;
      Exit;
    End;
  End;
End;

Procedure LayoutSvgGraph;
{ Calcule la disposition automatique des noeuds }
Var
  I, Row, Col, MaxCols: Integer;
  StartX, StartY: Integer;
Begin
  If SvgGraph.NodeCount = 0 Then Exit;
  
  { Calculer le nombre de colonnes }
  MaxCols := 3;
  If SvgGraph.NodeCount < 3 Then MaxCols := SvgGraph.NodeCount;
  
  { Calculer les dimensions de l'image }
  SvgGraph.Width := MaxCols * (SVG_NODE_WIDTH + SVG_NODE_MARGIN * 2) + SVG_NODE_MARGIN * 2;
  SvgGraph.Height := ((SvgGraph.NodeCount + MaxCols - 1) Div MaxCols) * (SVG_NODE_HEIGHT + SVG_NODE_MARGIN * 2) + SVG_NODE_MARGIN * 4;
  
  If SvgGraph.Width < SVG_DEFAULT_WIDTH Then SvgGraph.Width := SVG_DEFAULT_WIDTH;
  If SvgGraph.Height < SVG_DEFAULT_HEIGHT Then SvgGraph.Height := SVG_DEFAULT_HEIGHT;
  
  { Positionner les noeuds }
  StartX := SVG_NODE_MARGIN;
  StartY := SVG_NODE_MARGIN + 30; { Espace pour le titre }
  
  For I := 1 To SvgGraph.NodeCount Do
  Begin
    Row := (I - 1) Div MaxCols;
    Col := (I - 1) Mod MaxCols;
    
    SvgGraph.Nodes[I].X := StartX + Col * (SVG_NODE_WIDTH + SVG_NODE_MARGIN * 2);
    SvgGraph.Nodes[I].Y := StartY + Row * (SVG_NODE_HEIGHT + SVG_NODE_MARGIN * 2);
  End;
  
  { Calculer les positions des aretes }
  For I := 1 To SvgGraph.EdgeCount Do
  Begin
    Row := FindSvgNode(SvgGraph.Edges[I].FromId);
    Col := FindSvgNode(SvgGraph.Edges[I].ToId);
    
    If (Row > 0) And (Col > 0) Then
    Begin
      { Point de depart: centre bas du noeud source }
      SvgGraph.Edges[I].FromX := SvgGraph.Nodes[Row].X + SvgGraph.Nodes[Row].W Div 2;
      SvgGraph.Edges[I].FromY := SvgGraph.Nodes[Row].Y + SvgGraph.Nodes[Row].H;
      
      { Point d'arrivee: centre haut du noeud destination }
      SvgGraph.Edges[I].ToX := SvgGraph.Nodes[Col].X + SvgGraph.Nodes[Col].W Div 2;
      SvgGraph.Edges[I].ToY := SvgGraph.Nodes[Col].Y;
    End;
  End;
End;

Function SvgEscapeText(Const S: String): String;
{ Echappe les caracteres speciaux pour SVG/XML }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    Case S[I] Of
      '<': R := R + '&lt;';
      '>': R := R + '&gt;';
      '&': R := R + '&amp;';
      '"': R := R + '&quot;';
      '''': R := R + '&apos;';
    Else
      R := R + S[I];
    End;
  End;
  SvgEscapeText := R;
End;

Procedure WriteSvgHeader(Var F: Text; Width, Height: Integer; Const BgColor: String);
{ Ecrit l'en-tete XML et SVG }
Begin
  WriteLn(F, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(F, '<svg xmlns="http://www.w3.org/2000/svg" ');
  WriteLn(F, '     width="', Width, '" height="', Height, '"');
  WriteLn(F, '     viewBox="0 0 ', Width, ' ', Height, '">');
  WriteLn(F);
  WriteLn(F, '  <!-- Genere par DOXYGEN.PAS - Generateur SVG integre -->');
  WriteLn(F, '  <!-- Sans outil externe - Copyright DEV-COOLS -->');
  WriteLn(F);
  WriteLn(F, '  <!-- Definitions (marqueur fleche) -->');
  WriteLn(F, '  <defs>');
  WriteLn(F, '    <marker id="arrowhead" markerWidth="', SVG_ARROW_SIZE, '" markerHeight="', SVG_ARROW_SIZE, '"');
  WriteLn(F, '            refX="', SVG_ARROW_SIZE, '" refY="', SVG_ARROW_SIZE Div 2, '"');
  WriteLn(F, '            orient="auto" markerUnits="strokeWidth">');
  WriteLn(F, '      <polygon points="0 0, ', SVG_ARROW_SIZE, ' ', SVG_ARROW_SIZE Div 2, ', 0 ', SVG_ARROW_SIZE, '"');
  WriteLn(F, '               fill="#404040" />');
  WriteLn(F, '    </marker>');
  WriteLn(F, '  </defs>');
  WriteLn(F);
  WriteLn(F, '  <!-- Fond -->');
  WriteLn(F, '  <rect width="100%" height="100%" fill="', BgColor, '" />');
  WriteLn(F);
End;

Procedure WriteSvgFooter(Var F: Text);
{ Ecrit le pied du fichier SVG }
Begin
  WriteLn(F, '</svg>');
End;

Procedure WriteSvgRect(Var F: Text; X, Y, W, H: Integer; 
                       Const FillColor, StrokeColor: String;
                       RoundedCorners: Boolean);
{ Dessine un rectangle }
Var
  Rx: Integer;
Begin
  If RoundedCorners Then Rx := 5 Else Rx := 0;
  
  Write(F, '  <rect x="', X, '" y="', Y, '"');
  Write(F, ' width="', W, '" height="', H, '"');
  If RoundedCorners Then
    Write(F, ' rx="', Rx, '" ry="', Rx, '"');
  Write(F, ' fill="', FillColor, '"');
  Write(F, ' stroke="', StrokeColor, '"');
  WriteLn(F, ' stroke-width="2" />');
End;

Procedure WriteSvgLine(Var F: Text; X1, Y1, X2, Y2: Integer;
                       Const StrokeColor, Style: String;
                       WithArrow: Boolean);
{ Dessine une ligne ou une fleche }
Var
  DashArray: String;
Begin
  If Style = 'dashed' Then
    DashArray := ' stroke-dasharray="5,5"'
  Else
    DashArray := '';
  
  Write(F, '  <line x1="', X1, '" y1="', Y1, '"');
  Write(F, ' x2="', X2, '" y2="', Y2, '"');
  Write(F, ' stroke="', StrokeColor, '"');
  Write(F, ' stroke-width="2"', DashArray);
  If WithArrow Then
    Write(F, ' marker-end="url(#arrowhead)"');
  WriteLn(F, ' />');
End;

Procedure WriteSvgText(Var F: Text; X, Y: Integer; Const Text: String;
                       FontSize: Integer; Const FillColor: String;
                       CenterHorizontal: Boolean);
{ Ecrit du texte }
Var
  Anchor: String;
Begin
  If CenterHorizontal Then
    Anchor := 'middle'
  Else
    Anchor := 'start';
  
  Write(F, '  <text x="', X, '" y="', Y, '"');
  Write(F, ' font-family="', SVG_FONT_FAMILY, '"');
  Write(F, ' font-size="', FontSize, '"');
  Write(F, ' fill="', FillColor, '"');
  Write(F, ' text-anchor="', Anchor, '"');
  WriteLn(F, '>', SvgEscapeText(Text), '</text>');
End;

Procedure RenderSvgGraph(Const OutputFileName: String);
{ Genere le fichier SVG a partir du graphe }
Var
  F: Text;
  I: Integer;
  CenterX, CenterY: Integer;
Begin
  If Not SvgInitialized Then Exit;
  If SvgGraph.NodeCount = 0 Then Exit;
  
  { Calculer la disposition }
  LayoutSvgGraph;
  
  { Ouvrir le fichier SVG }
  Assign(F, OutputFileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  { Ecrire l'en-tete SVG }
  WriteSvgHeader(F, SvgGraph.Width, SvgGraph.Height, SvgGraph.BgColor);
  
  { Ecrire le titre si present }
  If SvgGraph.Title <> '' Then
  Begin
    WriteLn(F, '  <!-- Titre -->');
    WriteSvgText(F, SvgGraph.Width Div 2, 20, SvgGraph.Title, 16, '#000000', True);
    WriteLn(F);
  End;
  
  { Dessiner les aretes d'abord (pour qu'elles soient derriere les noeuds) }
  WriteLn(F, '  <!-- Aretes -->');
  WriteLn(F, '  <g id="edges">');
  For I := 1 To SvgGraph.EdgeCount Do
  Begin
    If (SvgGraph.Edges[I].FromX > 0) Or (SvgGraph.Edges[I].ToX > 0) Then
    Begin
      WriteSvgLine(F, 
                   SvgGraph.Edges[I].FromX, SvgGraph.Edges[I].FromY,
                   SvgGraph.Edges[I].ToX, SvgGraph.Edges[I].ToY,
                   SvgGraph.Edges[I].StrokeColor,
                   SvgGraph.Edges[I].Style,
                   True); { Avec fleche }
    End;
  End;
  WriteLn(F, '  </g>');
  WriteLn(F);
  
  { Dessiner les noeuds }
  WriteLn(F, '  <!-- Noeuds -->');
  WriteLn(F, '  <g id="nodes">');
  For I := 1 To SvgGraph.NodeCount Do
  Begin
    { Rectangle du noeud }
    WriteSvgRect(F, 
                 SvgGraph.Nodes[I].X, SvgGraph.Nodes[I].Y,
                 SvgGraph.Nodes[I].W, SvgGraph.Nodes[I].H,
                 SvgGraph.Nodes[I].FillColor, SvgGraph.Nodes[I].StrokeColor,
                 True); { Coins arrondis }
    
    { Texte du noeud (centre dans le rectangle) }
    CenterX := SvgGraph.Nodes[I].X + SvgGraph.Nodes[I].W Div 2;
    CenterY := SvgGraph.Nodes[I].Y + SvgGraph.Nodes[I].H Div 2 + SVG_FONT_SIZE Div 3;
    WriteSvgText(F, CenterX, CenterY, SvgGraph.Nodes[I].Name, 
                 SVG_FONT_SIZE, '#000000', True);
  End;
  WriteLn(F, '  </g>');
  WriteLn(F);
  
  { Fermer le fichier SVG }
  WriteSvgFooter(F);
  Close(F);
End;

Procedure ParseDotFileForSvg(Const DotFile: String);
{ Parse un fichier DOT et construit le graphe SVG }
Var
  F: Text;
  Line, Token, NodeId, NodeLabel, FromId, ToId: String;
  P, P2: Integer;
  InQuotes: Boolean;
Begin
  Assign(F, DotFile);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    
    { Supprimer les espaces en debut et fin }
    While (Length(Line) > 0) And (Line[1] In [' ', #9]) Do
      Delete(Line, 1, 1);
    While (Length(Line) > 0) And (Line[Length(Line)] In [' ', #9]) Do
      Delete(Line, Length(Line), 1);
    
    { Ignorer les lignes vides et les commentaires }
    If (Line = '') Or (Copy(Line, 1, 2) = '//') Or (Copy(Line, 1, 1) = '#') Then
      Continue;
    
    { Detecter le titre du graphe }
    If (Copy(Line, 1, 6) = 'label=') Or (Copy(Line, 1, 6) = 'label ') Then
    Begin
      P := Pos('"', Line);
      If P > 0 Then
      Begin
        P2 := P + 1;
        While (P2 <= Length(Line)) And (Line[P2] <> '"') Do
          Inc(P2);
        SvgGraph.Title := Copy(Line, P + 1, P2 - P - 1);
      End;
      Continue;
    End;
    
    { Detecter les aretes (contiennent '->' ou '--') }
    P := Pos('->', Line);
    If P = 0 Then P := Pos('--', Line);
    
    If P > 0 Then
    Begin
      { Extraire le noeud source }
      FromId := Copy(Line, 1, P - 1);
      While (Length(FromId) > 0) And (FromId[Length(FromId)] In [' ', #9]) Do
        Delete(FromId, Length(FromId), 1);
      While (Length(FromId) > 0) And (FromId[1] In [' ', #9]) Do
        Delete(FromId, 1, 1);
      
      { Extraire le noeud destination }
      If Line[P+1] = '>' Then
        ToId := Copy(Line, P + 2, Length(Line))
      Else
        ToId := Copy(Line, P + 2, Length(Line));
      
      { Supprimer les attributs et le point-virgule }
      P2 := Pos('[', ToId);
      If P2 > 0 Then ToId := Copy(ToId, 1, P2 - 1);
      P2 := Pos(';', ToId);
      If P2 > 0 Then ToId := Copy(ToId, 1, P2 - 1);
      
      While (Length(ToId) > 0) And (ToId[Length(ToId)] In [' ', #9]) Do
        Delete(ToId, Length(ToId), 1);
      While (Length(ToId) > 0) And (ToId[1] In [' ', #9]) Do
        Delete(ToId, 1, 1);
      
      { S'assurer que les noeuds existent }
      If FindSvgNode(FromId) = 0 Then
        AddSvgNode(FromId, FromId);
      If FindSvgNode(ToId) = 0 Then
        AddSvgNode(ToId, ToId);
      
      { Ajouter l'arete }
      AddSvgEdge(FromId, ToId);
    End
    Else If (Pos('[', Line) > 0) And (Pos('label=', Line) > 0) Then
    Begin
      { C'est un noeud avec attributs }
      P := Pos('[', Line);
      NodeId := Copy(Line, 1, P - 1);
      While (Length(NodeId) > 0) And (NodeId[Length(NodeId)] In [' ', #9]) Do
        Delete(NodeId, Length(NodeId), 1);
      While (Length(NodeId) > 0) And (NodeId[1] In [' ', #9]) Do
        Delete(NodeId, 1, 1);
      
      { Extraire le label }
      P := Pos('label=', Line);
      If P > 0 Then
      Begin
        P := P + 6;
        If (P <= Length(Line)) And (Line[P] = '"') Then
        Begin
          Inc(P);
          P2 := P;
          InQuotes := True;
          While (P2 <= Length(Line)) And InQuotes Do
          Begin
            If Line[P2] = '"' Then
              InQuotes := False
            Else
              Inc(P2);
          End;
          NodeLabel := Copy(Line, P, P2 - P);
        End
        Else
        Begin
          P2 := P;
          While (P2 <= Length(Line)) And Not (Line[P2] In [',', ']', ' ', ';']) Do
            Inc(P2);
          NodeLabel := Copy(Line, P, P2 - P);
        End;
      End
      Else
        NodeLabel := NodeId;
      
      { Ajouter le noeud s'il n'existe pas deja }
      If FindSvgNode(NodeId) = 0 Then
        AddSvgNode(NodeId, NodeLabel);
    End;
  End;
  
  Close(F);
End;

Procedure RenderDotToSvg(Const DotFile, SvgFile: String);
{ Fonction principale: lit un fichier DOT et genere un SVG }
Begin
  { Reinitialiser le graphe }
  SvgInitialized := False;
  InitSvgGraph;
  
  { Parser le fichier DOT }
  ParseDotFileForSvg(DotFile);
  
  { Generer le SVG }
  RenderSvgGraph(SvgFile);
  
  If Not Opts.Quiet Then
    WriteLn('SVG genere (built-in): ', SvgFile);
End;

{ ============================================================
  FIN DU GENERATEUR SVG INTEGRE
  ============================================================ }

{ ============================================================
  GENERATEUR VISIO VDX INTEGRE (SANS OUTIL EXTERNE)
  
  Ce module permet de generer des fichiers Microsoft Visio au
  format VDX (Visio XML Drawing) directement sans avoir besoin
  de Microsoft Visio ou d'autres outils externes.
  Il inclut:
  - Ecriture du format XML Visio VDX
  - Definition des Masters (formes de base)
  - Creation de formes (rectangles pour les noeuds)
  - Creation de connecteurs (fleches pour les aretes)
  - Parser DOT pour lire les fichiers .dot
  - Generation du fichier VDX complet
  ============================================================ }

Procedure InitVdxGraph;
{ Initialise le graphe Visio VDX }
Var
  I: Integer;
Begin
  VdxGraph.Title := 'Doxygen Graph';
  VdxGraph.PageWidth := VDX_DEFAULT_WIDTH;
  VdxGraph.PageHeight := VDX_DEFAULT_HEIGHT;
  VdxGraph.BgColor := '#FFFFFF';
  VdxGraph.NodeCount := 0;
  VdxGraph.EdgeCount := 0;
  VdxGraph.NextShapeId := 1;
  
  For I := 1 To MAX_VDX_NODES Do
  Begin
    VdxGraph.Nodes[I].Id := 0;
    VdxGraph.Nodes[I].Name := '';
    VdxGraph.Nodes[I].PinX := 0.0;
    VdxGraph.Nodes[I].PinY := 0.0;
    VdxGraph.Nodes[I].Width := VDX_NODE_WIDTH;
    VdxGraph.Nodes[I].Height := VDX_NODE_HEIGHT;
    VdxGraph.Nodes[I].FillColor := '#C8C8FF';
    VdxGraph.Nodes[I].LineColor := '#000080';
    VdxGraph.Nodes[I].TextId := '';
  End;
  
  For I := 1 To MAX_VDX_EDGES Do
  Begin
    VdxGraph.Edges[I].Id := 0;
    VdxGraph.Edges[I].FromId := 0;
    VdxGraph.Edges[I].ToId := 0;
    VdxGraph.Edges[I].BeginX := 0.0;
    VdxGraph.Edges[I].BeginY := 0.0;
    VdxGraph.Edges[I].EndX := 0.0;
    VdxGraph.Edges[I].EndY := 0.0;
    VdxGraph.Edges[I].LineColor := '#404040';
    VdxGraph.Edges[I].LinePattern := 0;
    VdxGraph.Edges[I].LabelText := '';
  End;
  
  VdxInitialized := True;
End;

Function AddVdxNode(Const TextId, Name: String): Integer;
{ Ajoute un noeud au graphe Visio VDX }
Var
  Idx: Integer;
Begin
  If Not VdxInitialized Then InitVdxGraph;
  
  If VdxGraph.NodeCount >= MAX_VDX_NODES Then
  Begin
    AddVdxNode := 0;
    Exit;
  End;
  
  Inc(VdxGraph.NodeCount);
  Idx := VdxGraph.NodeCount;
  
  VdxGraph.Nodes[Idx].Id := VdxGraph.NextShapeId;
  Inc(VdxGraph.NextShapeId);
  VdxGraph.Nodes[Idx].Name := Name;
  VdxGraph.Nodes[Idx].TextId := TextId;
  VdxGraph.Nodes[Idx].Width := Length(Name) * 0.1 + 0.5;
  If VdxGraph.Nodes[Idx].Width < VDX_NODE_WIDTH Then
    VdxGraph.Nodes[Idx].Width := VDX_NODE_WIDTH;
  VdxGraph.Nodes[Idx].Height := VDX_NODE_HEIGHT;
  
  AddVdxNode := Idx;
End;

Function FindVdxNode(Const TextId: String): Integer;
{ Trouve un noeud par son TextId }
Var
  I: Integer;
Begin
  FindVdxNode := 0;
  For I := 1 To VdxGraph.NodeCount Do
  Begin
    If VdxGraph.Nodes[I].TextId = TextId Then
    Begin
      FindVdxNode := I;
      Exit;
    End;
  End;
End;

Function AddVdxEdge(Const FromTextId, ToTextId: String): Integer;
{ Ajoute une arete au graphe Visio VDX }
Var
  Idx, FromIdx, ToIdx: Integer;
Begin
  If Not VdxInitialized Then InitVdxGraph;
  
  If VdxGraph.EdgeCount >= MAX_VDX_EDGES Then
  Begin
    AddVdxEdge := 0;
    Exit;
  End;
  
  FromIdx := FindVdxNode(FromTextId);
  ToIdx := FindVdxNode(ToTextId);
  
  If (FromIdx = 0) Or (ToIdx = 0) Then
  Begin
    AddVdxEdge := 0;
    Exit;
  End;
  
  Inc(VdxGraph.EdgeCount);
  Idx := VdxGraph.EdgeCount;
  
  VdxGraph.Edges[Idx].Id := VdxGraph.NextShapeId;
  Inc(VdxGraph.NextShapeId);
  VdxGraph.Edges[Idx].FromId := VdxGraph.Nodes[FromIdx].Id;
  VdxGraph.Edges[Idx].ToId := VdxGraph.Nodes[ToIdx].Id;
  
  AddVdxEdge := Idx;
End;

Procedure LayoutVdxGraph;
{ Calcule la disposition des noeuds dans le graphe Visio }
Var
  I, Row, Col: Integer;
  MaxCols, MaxRows: Integer;
  StartX, StartY: Real;
  CellWidth, CellHeight: Real;
Begin
  If VdxGraph.NodeCount = 0 Then Exit;
  
  { Disposition simple en grille }
  MaxCols := 4;
  If VdxGraph.NodeCount <= 4 Then MaxCols := VdxGraph.NodeCount;
  MaxRows := (VdxGraph.NodeCount + MaxCols - 1) Div MaxCols;
  
  CellWidth := VDX_NODE_WIDTH + VDX_NODE_MARGIN;
  CellHeight := VDX_NODE_HEIGHT + VDX_NODE_MARGIN;
  
  StartX := 1;
  StartY := VdxGraph.PageHeight - 1;
  
  For I := 1 To VdxGraph.NodeCount Do
  Begin
    Row := (I - 1) Div MaxCols;
    Col := (I - 1) Mod MaxCols;
    
    VdxGraph.Nodes[I].PinX := StartX + Col * CellWidth + VDX_NODE_WIDTH / 2;
    VdxGraph.Nodes[I].PinY := StartY - Row * CellHeight - VDX_NODE_HEIGHT / 2;
  End;
  
  { Calculer les positions des aretes }
  For I := 1 To VdxGraph.EdgeCount Do
  Begin
    { Trouver les noeuds source et destination }
    For Row := 1 To VdxGraph.NodeCount Do
    Begin
      If VdxGraph.Nodes[Row].Id = VdxGraph.Edges[I].FromId Then
      Begin
        VdxGraph.Edges[I].BeginX := VdxGraph.Nodes[Row].PinX;
        VdxGraph.Edges[I].BeginY := VdxGraph.Nodes[Row].PinY - VDX_NODE_HEIGHT / 2;
      End;
      If VdxGraph.Nodes[Row].Id = VdxGraph.Edges[I].ToId Then
      Begin
        VdxGraph.Edges[I].EndX := VdxGraph.Nodes[Row].PinX;
        VdxGraph.Edges[I].EndY := VdxGraph.Nodes[Row].PinY + VDX_NODE_HEIGHT / 2;
      End;
    End;
  End;
End;

Function RealToStr(R: Real): String;
{ Convertit un nombre reel en chaine avec 4 decimales }
Var
  S: String;
Begin
  Str(R:0:4, S);
  RealToStr := S;
End;

Function VdxEscapeXml(Const S: String): String;
{ Echappe les caracteres speciaux XML }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    Case S[I] Of
      '<': R := R + '&lt;';
      '>': R := R + '&gt;';
      '&': R := R + '&amp;';
      '"': R := R + '&quot;';
      '''': R := R + '&apos;';
    Else
      R := R + S[I];
    End;
  End;
  VdxEscapeXml := R;
End;

Procedure WriteVdxHeader(Var F: Text);
{ Ecrit l'en-tete du fichier VDX }
Begin
  WriteLn(F, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  WriteLn(F, '<VisioDocument xmlns="', VDX_XMLNS, '" ');
  WriteLn(F, '  xmlns:vx="http://schemas.microsoft.com/visio/2006/extension"');
  WriteLn(F, '  xml:space="preserve">');
  WriteLn(F, '  <DocumentProperties>');
  WriteLn(F, '    <Title>', VdxEscapeXml(VdxGraph.Title), '</Title>');
  WriteLn(F, '    <Creator>DOXYGEN.PAS - DEV-COOLS</Creator>');
  WriteLn(F, '    <Company>Generated by Doxygen Clone</Company>');
  WriteLn(F, '  </DocumentProperties>');
  WriteLn(F, '  <DocumentSettings>');
  WriteLn(F, '    <GlueSettings>9</GlueSettings>');
  WriteLn(F, '    <SnapSettings>65847</SnapSettings>');
  WriteLn(F, '  </DocumentSettings>');
End;

Procedure WriteVdxColors(Var F: Text);
{ Ecrit la table des couleurs }
Begin
  WriteLn(F, '  <Colors>');
  WriteLn(F, '    <ColorEntry IX="0" RGB="#000000"/>');
  WriteLn(F, '    <ColorEntry IX="1" RGB="#FFFFFF"/>');
  WriteLn(F, '    <ColorEntry IX="2" RGB="#FF0000"/>');
  WriteLn(F, '    <ColorEntry IX="3" RGB="#00FF00"/>');
  WriteLn(F, '    <ColorEntry IX="4" RGB="#0000FF"/>');
  WriteLn(F, '    <ColorEntry IX="5" RGB="#FFFF00"/>');
  WriteLn(F, '    <ColorEntry IX="6" RGB="#FF00FF"/>');
  WriteLn(F, '    <ColorEntry IX="7" RGB="#00FFFF"/>');
  WriteLn(F, '    <ColorEntry IX="8" RGB="#C8C8FF"/>');
  WriteLn(F, '    <ColorEntry IX="9" RGB="#000080"/>');
  WriteLn(F, '    <ColorEntry IX="10" RGB="#404040"/>');
  WriteLn(F, '  </Colors>');
End;

Procedure WriteVdxFonts(Var F: Text);
{ Ecrit la table des polices }
Begin
  WriteLn(F, '  <FaceNames>');
  WriteLn(F, '    <FaceName ID="1" Name="Arial" CharSets="0"/>');
  WriteLn(F, '    <FaceName ID="2" Name="Calibri" CharSets="0"/>');
  WriteLn(F, '  </FaceNames>');
End;

Procedure WriteVdxStyleSheets(Var F: Text);
{ Ecrit les feuilles de style }
Begin
  WriteLn(F, '  <StyleSheets>');
  WriteLn(F, '    <StyleSheet ID="0" Name="No Style">');
  WriteLn(F, '      <Line>');
  WriteLn(F, '        <LineWeight>0.01041666666666667</LineWeight>');
  WriteLn(F, '        <LineColor>0</LineColor>');
  WriteLn(F, '        <LinePattern>1</LinePattern>');
  WriteLn(F, '      </Line>');
  WriteLn(F, '      <Fill>');
  WriteLn(F, '        <FillForegnd>1</FillForegnd>');
  WriteLn(F, '        <FillBkgnd>0</FillBkgnd>');
  WriteLn(F, '        <FillPattern>1</FillPattern>');
  WriteLn(F, '      </Fill>');
  WriteLn(F, '      <Char>');
  WriteLn(F, '        <Font>1</Font>');
  WriteLn(F, '        <Size>0.1388888888888889</Size>');
  WriteLn(F, '      </Char>');
  WriteLn(F, '    </StyleSheet>');
  WriteLn(F, '  </StyleSheets>');
End;

Procedure WriteVdxMasters(Var F: Text);
{ Ecrit les formes de base (Masters) }
Begin
  WriteLn(F, '  <Masters>');
  { Master pour le rectangle (noeud) }
  WriteLn(F, '    <Master ID="', VDX_MASTER_RECT, '" Name="Rectangle">');
  WriteLn(F, '      <PageSheet>');
  WriteLn(F, '        <PageProps>');
  WriteLn(F, '          <PageWidth>1</PageWidth>');
  WriteLn(F, '          <PageHeight>1</PageHeight>');
  WriteLn(F, '        </PageProps>');
  WriteLn(F, '      </PageSheet>');
  WriteLn(F, '      <Shapes>');
  WriteLn(F, '        <Shape ID="1" Type="Shape" Master="0">');
  WriteLn(F, '          <XForm>');
  WriteLn(F, '            <PinX>0.5</PinX>');
  WriteLn(F, '            <PinY>0.5</PinY>');
  WriteLn(F, '            <Width>1</Width>');
  WriteLn(F, '            <Height>0.5</Height>');
  WriteLn(F, '          </XForm>');
  WriteLn(F, '          <Geom IX="0">');
  WriteLn(F, '            <MoveTo IX="1"><X>0</X><Y>0</Y></MoveTo>');
  WriteLn(F, '            <LineTo IX="2"><X>1</X><Y>0</Y></LineTo>');
  WriteLn(F, '            <LineTo IX="3"><X>1</X><Y>0.5</Y></LineTo>');
  WriteLn(F, '            <LineTo IX="4"><X>0</X><Y>0.5</Y></LineTo>');
  WriteLn(F, '            <LineTo IX="5"><X>0</X><Y>0</Y></LineTo>');
  WriteLn(F, '          </Geom>');
  WriteLn(F, '        </Shape>');
  WriteLn(F, '      </Shapes>');
  WriteLn(F, '    </Master>');
  { Master pour le connecteur (arete) }
  WriteLn(F, '    <Master ID="', VDX_MASTER_CONNECTOR, '" Name="Dynamic connector">');
  WriteLn(F, '      <PageSheet>');
  WriteLn(F, '        <PageProps>');
  WriteLn(F, '          <PageWidth>1</PageWidth>');
  WriteLn(F, '          <PageHeight>1</PageHeight>');
  WriteLn(F, '        </PageProps>');
  WriteLn(F, '      </PageSheet>');
  WriteLn(F, '      <Shapes>');
  WriteLn(F, '        <Shape ID="1" Type="Shape" Master="0">');
  WriteLn(F, '          <XForm1D>');
  WriteLn(F, '            <BeginX>0</BeginX>');
  WriteLn(F, '            <BeginY>0</BeginY>');
  WriteLn(F, '            <EndX>1</EndX>');
  WriteLn(F, '            <EndY>1</EndY>');
  WriteLn(F, '          </XForm1D>');
  WriteLn(F, '          <Line>');
  WriteLn(F, '            <EndArrow>13</EndArrow>');
  WriteLn(F, '          </Line>');
  WriteLn(F, '          <Geom IX="0">');
  WriteLn(F, '            <MoveTo IX="1"><X>0</X><Y>0</Y></MoveTo>');
  WriteLn(F, '            <LineTo IX="2"><X>1</X><Y>1</Y></LineTo>');
  WriteLn(F, '          </Geom>');
  WriteLn(F, '        </Shape>');
  WriteLn(F, '      </Shapes>');
  WriteLn(F, '    </Master>');
  WriteLn(F, '  </Masters>');
End;

Procedure WriteVdxPage(Var F: Text);
{ Ecrit la page avec toutes les formes }
Var
  I: Integer;
Begin
  WriteLn(F, '  <Pages>');
  WriteLn(F, '    <Page ID="0" Name="Page-1">');
  WriteLn(F, '      <PageSheet>');
  WriteLn(F, '        <PageProps>');
  WriteLn(F, '          <PageWidth>', RealToStr(VdxGraph.PageWidth), '</PageWidth>');
  WriteLn(F, '          <PageHeight>', RealToStr(VdxGraph.PageHeight), '</PageHeight>');
  WriteLn(F, '        </PageProps>');
  WriteLn(F, '      </PageSheet>');
  WriteLn(F, '      <Shapes>');
  
  { Ecrire les noeuds }
  For I := 1 To VdxGraph.NodeCount Do
  Begin
    WriteLn(F, '        <Shape ID="', VdxGraph.Nodes[I].Id, '" Type="Shape" Master="', VDX_MASTER_RECT, '">');
    WriteLn(F, '          <XForm>');
    WriteLn(F, '            <PinX>', RealToStr(VdxGraph.Nodes[I].PinX), '</PinX>');
    WriteLn(F, '            <PinY>', RealToStr(VdxGraph.Nodes[I].PinY), '</PinY>');
    WriteLn(F, '            <Width>', RealToStr(VdxGraph.Nodes[I].Width), '</Width>');
    WriteLn(F, '            <Height>', RealToStr(VdxGraph.Nodes[I].Height), '</Height>');
    WriteLn(F, '            <LocPinX F="Width*0.5">', RealToStr(VdxGraph.Nodes[I].Width / 2), '</LocPinX>');
    WriteLn(F, '            <LocPinY F="Height*0.5">', RealToStr(VdxGraph.Nodes[I].Height / 2), '</LocPinY>');
    WriteLn(F, '          </XForm>');
    WriteLn(F, '          <Fill>');
    WriteLn(F, '            <FillForegnd>8</FillForegnd>');
    WriteLn(F, '            <FillPattern>1</FillPattern>');
    WriteLn(F, '          </Fill>');
    WriteLn(F, '          <Line>');
    WriteLn(F, '            <LineColor>9</LineColor>');
    WriteLn(F, '            <LineWeight>0.02</LineWeight>');
    WriteLn(F, '          </Line>');
    WriteLn(F, '          <Text>', VdxEscapeXml(VdxGraph.Nodes[I].Name), '</Text>');
    WriteLn(F, '        </Shape>');
  End;
  
  { Ecrire les aretes }
  For I := 1 To VdxGraph.EdgeCount Do
  Begin
    WriteLn(F, '        <Shape ID="', VdxGraph.Edges[I].Id, '" Type="Shape" Master="', VDX_MASTER_CONNECTOR, '">');
    WriteLn(F, '          <XForm1D>');
    WriteLn(F, '            <BeginX>', RealToStr(VdxGraph.Edges[I].BeginX), '</BeginX>');
    WriteLn(F, '            <BeginY>', RealToStr(VdxGraph.Edges[I].BeginY), '</BeginY>');
    WriteLn(F, '            <EndX>', RealToStr(VdxGraph.Edges[I].EndX), '</EndX>');
    WriteLn(F, '            <EndY>', RealToStr(VdxGraph.Edges[I].EndY), '</EndY>');
    WriteLn(F, '          </XForm1D>');
    WriteLn(F, '          <Line>');
    WriteLn(F, '            <LineColor>10</LineColor>');
    WriteLn(F, '            <EndArrow>13</EndArrow>');
    WriteLn(F, '          </Line>');
    WriteLn(F, '          <Geom IX="0">');
    WriteLn(F, '            <MoveTo IX="1"><X>0</X><Y>0</Y></MoveTo>');
    WriteLn(F, '            <LineTo IX="2"><X F="Width">1</X><Y F="Height">1</Y></LineTo>');
    WriteLn(F, '          </Geom>');
    WriteLn(F, '        </Shape>');
  End;
  
  WriteLn(F, '      </Shapes>');
  
  { Ecrire les connexions }
  If VdxGraph.EdgeCount > 0 Then
  Begin
    WriteLn(F, '      <Connects>');
    For I := 1 To VdxGraph.EdgeCount Do
    Begin
      WriteLn(F, '        <Connect FromSheet="', VdxGraph.Edges[I].Id, '" FromCell="BeginX" ToSheet="', VdxGraph.Edges[I].FromId, '"/>');
      WriteLn(F, '        <Connect FromSheet="', VdxGraph.Edges[I].Id, '" FromCell="EndX" ToSheet="', VdxGraph.Edges[I].ToId, '"/>');
    End;
    WriteLn(F, '      </Connects>');
  End;
  
  WriteLn(F, '    </Page>');
  WriteLn(F, '  </Pages>');
End;

Procedure WriteVdxFooter(Var F: Text);
{ Ecrit la fin du fichier VDX }
Begin
  WriteLn(F, '</VisioDocument>');
End;

Procedure RenderVdxGraph(Const OutputFileName: String);
{ Genere le fichier VDX a partir du graphe }
Var
  F: Text;
Begin
  If Not VdxInitialized Then Exit;
  If VdxGraph.NodeCount = 0 Then Exit;
  
  { Calculer la disposition }
  LayoutVdxGraph;
  
  { Ouvrir le fichier en ecriture }
  Assign(F, OutputFileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  { Ecrire le document VDX }
  WriteVdxHeader(F);
  WriteVdxColors(F);
  WriteVdxFonts(F);
  WriteVdxStyleSheets(F);
  WriteVdxMasters(F);
  WriteVdxPage(F);
  WriteVdxFooter(F);
  
  Close(F);
End;

Procedure ParseDotFileForVdx(Const DotFile: String);
{ Parse un fichier DOT et cree le graphe Visio VDX correspondant }
Var
  F: Text;
  Line, TrimLine: String;
  I, P1, P2: Integer;
  NodeId, NodeLabel, FromId, ToId: String;
  InGraph: Boolean;
Begin
  Assign(F, DotFile);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  InGraph := False;
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    
    { Trim de la ligne }
    TrimLine := '';
    For I := 1 To Length(Line) Do
      If (Line[I] <> ' ') And (Line[I] <> #9) Then
        TrimLine := TrimLine + Line[I];
    
    If TrimLine = '' Then Continue;
    
    { Detection du debut du graphe }
    If (Pos('digraph', Line) > 0) Or (Pos('graph', Line) > 0) Then
    Begin
      InGraph := True;
      Continue;
    End;
    
    If Not InGraph Then Continue;
    
    { Detection de la fin du graphe }
    If TrimLine = '}' Then
    Begin
      InGraph := False;
      Continue;
    End;
    
    { Detection d'une arete: node1 -> node2 }
    P1 := Pos('->', Line);
    If P1 > 0 Then
    Begin
      { Extraire FromId }
      FromId := '';
      For I := 1 To P1 - 1 Do
        If (Line[I] <> ' ') And (Line[I] <> #9) And (Line[I] <> '"') Then
          FromId := FromId + Line[I];
      
      { Extraire ToId }
      ToId := '';
      For I := P1 + 2 To Length(Line) Do
      Begin
        If (Line[I] = '[') Or (Line[I] = ';') Then Break;
        If (Line[I] <> ' ') And (Line[I] <> #9) And (Line[I] <> '"') Then
          ToId := ToId + Line[I];
      End;
      
      { Ajouter les noeuds s'ils n'existent pas }
      If FindVdxNode(FromId) = 0 Then
        AddVdxNode(FromId, FromId);
      If FindVdxNode(ToId) = 0 Then
        AddVdxNode(ToId, ToId);
      
      { Ajouter l'arete }
      AddVdxEdge(FromId, ToId);
      Continue;
    End;
    
    { Detection d'un noeud: node [label="..."] }
    P1 := Pos('[', Line);
    If P1 > 0 Then
    Begin
      { Extraire NodeId }
      NodeId := '';
      For I := 1 To P1 - 1 Do
        If (Line[I] <> ' ') And (Line[I] <> #9) And (Line[I] <> '"') Then
          NodeId := NodeId + Line[I];
      
      { Extraire le label si present }
      NodeLabel := NodeId;
      P2 := Pos('label=', Line);
      If P2 > 0 Then
      Begin
        NodeLabel := '';
        I := P2 + 6;
        If (I <= Length(Line)) And (Line[I] = '"') Then Inc(I);
        While (I <= Length(Line)) And (Line[I] <> '"') And (Line[I] <> ']') Do
        Begin
          NodeLabel := NodeLabel + Line[I];
          Inc(I);
        End;
      End;
      
      { Ajouter le noeud s'il n'existe pas }
      If FindVdxNode(NodeId) = 0 Then
        AddVdxNode(NodeId, NodeLabel);
    End;
  End;
  
  Close(F);
End;

Procedure RenderDotToVdx(Const DotFile, VdxFile: String);
{ Fonction principale: lit un fichier DOT et genere un VDX }
Begin
  { Reinitialiser le graphe }
  VdxInitialized := False;
  InitVdxGraph;
  
  { Parser le fichier DOT }
  ParseDotFileForVdx(DotFile);
  
  { Generer le VDX }
  RenderVdxGraph(VdxFile);
  
  If Not Opts.Quiet Then
    WriteLn('Visio VDX genere (built-in): ', VdxFile);
End;

{ ============================================================
  FIN DU GENERATEUR VISIO VDX INTEGRE
  ============================================================ }

Procedure RenderCallGraphImage(Const DotFile, ImageFile: String);
{ Genere l'image a partir du fichier DOT en utilisant les generateurs integres }
Var
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
  
  { Utiliser le generateur PNG integre pour le format PNG }
  If (Format = 'png') Or (Format = 'PNG') Then
  Begin
    RenderDotToPng(DotFile, ImageFile);
  End
  { Utiliser le generateur SVG integre pour le format SVG }
  Else If (Format = 'svg') Or (Format = 'SVG') Then
  Begin
    RenderDotToSvg(DotFile, ImageFile);
  End
  { Utiliser le generateur Visio VDX integre pour le format VDX }
  Else If (Format = 'vdx') Or (Format = 'VDX') Then
  Begin
    RenderDotToVdx(DotFile, ImageFile);
  End
  Else
  Begin
    { Pour les autres formats, afficher un message }
    If Not Opts.Quiet Then
    Begin
      WriteLn('Note: Le format ', Format, ' n''est pas directement supporte.');
      WriteLn('Les formats PNG, SVG et VDX (Visio) sont generes nativement sans outil externe.');
    End;
  End;
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
  TODO 18 - GENERATION DES GRAPHES DE DEPENDANCES (DEPENDENCY GRAPHS)
  ============================================================ }

Procedure InitDepGraph;
{ Initialise le generateur de graphes de dependances }
Begin
  DepGraphOutputDir := DEPGRAPH_OUTPUT_DIR;
  DepGraphFormat := 'png';
  DepGraphInitialized := True;
End;

Function GetDepGraphOutputDir: String;
Begin
  GetDepGraphOutputDir := DepGraphOutputDir;
End;

Procedure SetDepGraphOutputDir(Const Dir: String);
Begin
  DepGraphOutputDir := Dir;
End;

Function IsDepGraphInitialized: Boolean;
Begin
  IsDepGraphInitialized := DepGraphInitialized;
End;

Function GetDepGraphFormat: String;
Begin
  GetDepGraphFormat := DepGraphFormat;
End;

Procedure SetDepGraphFormat(Const Fmt: String);
Begin
  DepGraphFormat := Fmt;
End;

Function ExtractBaseFileName(Const FileName: String): String;
{ Extrait le nom de fichier sans chemin ni extension pour les graphes }
Var
  I, DotPos, SlashPos: Integer;
  Result: String;
Begin
  Result := FileName;
  { Trouver la derniere position du separateur de chemin }
  SlashPos := 0;
  For I := Length(FileName) DownTo 1 Do
  Begin
    If (FileName[I] = '/') Or (FileName[I] = '\') Then
    Begin
      SlashPos := I;
      Break;
    End;
  End;
  If SlashPos > 0 Then
    Result := Copy(FileName, SlashPos + 1, Length(FileName) - SlashPos);
  { Trouver le point de l'extension }
  DotPos := 0;
  For I := Length(Result) DownTo 1 Do
  Begin
    If Result[I] = '.' Then
    Begin
      DotPos := I;
      Break;
    End;
  End;
  If DotPos > 1 Then
    Result := Copy(Result, 1, DotPos - 1);
  ExtractBaseFileName := Result;
End;

Function ExtractDirPath(Const FileName: String): String;
{ Extrait le chemin du repertoire d'un fichier }
Var
  I: Integer;
  SlashPos: Integer;
Begin
  SlashPos := 0;
  For I := Length(FileName) DownTo 1 Do
  Begin
    If (FileName[I] = '/') Or (FileName[I] = '\') Then
    Begin
      SlashPos := I;
      Break;
    End;
  End;
  If SlashPos > 0 Then
    ExtractDirPath := Copy(FileName, 1, SlashPos - 1)
  Else
    ExtractDirPath := '.';
End;

Function DependencyKindColor(Kind: TDependencyKind; IsSystem: Boolean): String;
{ Retourne la couleur DOT pour un type de dependance }
Begin
  If IsSystem Then
    DependencyKindColor := DEPGRAPH_SYSTEM_COLOR
  Else
  Begin
    Case Kind Of
      DEP_INCLUDE, DEP_INCLUDE_LOCAL:
        DependencyKindColor := DEPGRAPH_LOCAL_COLOR;
      DEP_IMPORT, DEP_USES:
        DependencyKindColor := DEPGRAPH_INCLUDE_COLOR;
    Else
      DependencyKindColor := DEPGRAPH_INCLUDE_COLOR;
    End;
  End;
End;

Function SanitizeNodeId(Const S: String): String;
{ Convertit une chaine en ID de noeud DOT valide }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    If ((S[I] >= 'a') And (S[I] <= 'z')) Or
       ((S[I] >= 'A') And (S[I] <= 'Z')) Or
       ((S[I] >= '0') And (S[I] <= '9')) Or
       (S[I] = '_') Then
      R := R + S[I]
    Else
      R := R + '_';
  End;
  SanitizeNodeId := R;
End;

Procedure GenerateIncludeGraphDot(Const FileName: String; Var OutFile: Text);
{ Genere le graphe d'inclusion au format DOT (fichiers inclus par ce fichier) }
Var
  I: Integer;
  NodeId, TargetNodeId: String;
  EdgeColor: String;
Begin
  WriteLn(OutFile, '// Graphe d''inclusion pour: ', FileName);
  WriteLn(OutFile, 'digraph "IncludeGraph" {');
  WriteLn(OutFile, '  graph [rankdir=LR, fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  node [shape=', DEPGRAPH_NODE_SHAPE, ', fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', DEPGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Noeud principal (fichier source) }
  NodeId := SanitizeNodeId(ExtractBaseFileName(FileName));
  WriteLn(OutFile, '  ', NodeId, ' [label="', ExtractBaseFileName(FileName), '", style=filled, fillcolor="#FFECB3"];');
  WriteLn(OutFile);
  
  { Parcourir les dependances }
  For I := 1 To DependencyCount Do
  Begin
    If UpStr(Dependencies[I].SourceFile) = UpStr(FileName) Then
    Begin
      TargetNodeId := SanitizeNodeId(ExtractBaseFileName(Dependencies[I].TargetFile));
      EdgeColor := DependencyKindColor(Dependencies[I].Kind, Dependencies[I].IsSystem);
      
      { Creer le noeud cible }
      If Dependencies[I].IsSystem Then
        WriteLn(OutFile, '  ', TargetNodeId, ' [label="', ExtractBaseFileName(Dependencies[I].TargetFile), '", style=filled, fillcolor="', DEPGRAPH_SYSTEM_COLOR, '"];')
      Else
        WriteLn(OutFile, '  ', TargetNodeId, ' [label="', ExtractBaseFileName(Dependencies[I].TargetFile), '"];');
      
      { Creer l'arete }
      WriteLn(OutFile, '  ', NodeId, ' -> ', TargetNodeId, ' [color="', EdgeColor, '"];');
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, '  // Legende');
  WriteLn(OutFile, '  subgraph cluster_legend {');
  WriteLn(OutFile, '    label="Legende";');
  WriteLn(OutFile, '    style=dashed;');
  WriteLn(OutFile, '    legend_source [label="Fichier source", style=filled, fillcolor="#FFECB3"];');
  WriteLn(OutFile, '    legend_local [label="Include local", style=filled, fillcolor="white"];');
  WriteLn(OutFile, '    legend_system [label="Include systeme", style=filled, fillcolor="', DEPGRAPH_SYSTEM_COLOR, '"];');
  WriteLn(OutFile, '  }');
  WriteLn(OutFile, '}');
End;

Procedure GenerateIncludedByGraphDot(Const FileName: String; Var OutFile: Text);
{ Genere le graphe d'inclusion inverse au format DOT (fichiers qui incluent ce fichier) }
Var
  I: Integer;
  NodeId, SourceNodeId: String;
  EdgeColor: String;
Begin
  WriteLn(OutFile, '// Graphe d''inclusion inverse pour: ', FileName);
  WriteLn(OutFile, 'digraph "IncludedByGraph" {');
  WriteLn(OutFile, '  graph [rankdir=RL, fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  node [shape=', DEPGRAPH_NODE_SHAPE, ', fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', DEPGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Noeud principal (fichier cible) }
  NodeId := SanitizeNodeId(ExtractBaseFileName(FileName));
  WriteLn(OutFile, '  ', NodeId, ' [label="', ExtractBaseFileName(FileName), '", style=filled, fillcolor="#FFECB3"];');
  WriteLn(OutFile);
  
  { Parcourir les dependances inversement }
  For I := 1 To DependencyCount Do
  Begin
    If UpStr(Dependencies[I].TargetFile) = UpStr(FileName) Then
    Begin
      SourceNodeId := SanitizeNodeId(ExtractBaseFileName(Dependencies[I].SourceFile));
      EdgeColor := DependencyKindColor(Dependencies[I].Kind, Dependencies[I].IsSystem);
      
      { Creer le noeud source }
      WriteLn(OutFile, '  ', SourceNodeId, ' [label="', ExtractBaseFileName(Dependencies[I].SourceFile), '"];');
      
      { Creer l'arete (de source vers cible) }
      WriteLn(OutFile, '  ', SourceNodeId, ' -> ', NodeId, ' [color="', EdgeColor, '"];');
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, '  // Legende');
  WriteLn(OutFile, '  subgraph cluster_legend {');
  WriteLn(OutFile, '    label="Legende";');
  WriteLn(OutFile, '    style=dashed;');
  WriteLn(OutFile, '    legend_target [label="Fichier cible", style=filled, fillcolor="#FFECB3"];');
  WriteLn(OutFile, '    legend_includer [label="Fichier incluant"];');
  WriteLn(OutFile, '  }');
  WriteLn(OutFile, '}');
End;

Procedure GenerateDirectoryGraphDot(Const DirPath: String; Var OutFile: Text);
{ Genere le graphe de dependances entre repertoires }
Var
  I: Integer;
  SourceDir, TargetDir: String;
  SourceNodeId, TargetNodeId: String;
  DirPairs: Array[1..MAX_DEP_DIRS] Of Record
    SourceDir, TargetDir: String;
    Count: Integer;
  End;
  DirPairCount: Integer;
  J: Integer;
  Found: Boolean;
Begin
  WriteLn(OutFile, '// Graphe de dependances entre repertoires');
  WriteLn(OutFile, 'digraph "DirectoryGraph" {');
  WriteLn(OutFile, '  graph [rankdir=TB, fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  node [shape=', DEPGRAPH_DIR_SHAPE, ', fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', DEPGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Collecter les paires de repertoires uniques }
  DirPairCount := 0;
  For I := 1 To DependencyCount Do
  Begin
    SourceDir := ExtractDirPath(Dependencies[I].SourceFile);
    TargetDir := ExtractDirPath(Dependencies[I].TargetFile);
    
    { Ignorer les dependances au sein du meme repertoire }
    If SourceDir <> TargetDir Then
    Begin
      { Chercher si la paire existe deja }
      Found := False;
      For J := 1 To DirPairCount Do
      Begin
        If (DirPairs[J].SourceDir = SourceDir) And (DirPairs[J].TargetDir = TargetDir) Then
        Begin
          Inc(DirPairs[J].Count);
          Found := True;
          Break;
        End;
      End;
      
      { Ajouter la nouvelle paire }
      If Not Found And (DirPairCount < MAX_DEP_DIRS) Then
      Begin
        Inc(DirPairCount);
        DirPairs[DirPairCount].SourceDir := SourceDir;
        DirPairs[DirPairCount].TargetDir := TargetDir;
        DirPairs[DirPairCount].Count := 1;
      End;
    End;
  End;
  
  { Generer les noeuds et aretes }
  For I := 1 To DirPairCount Do
  Begin
    SourceNodeId := SanitizeNodeId(DirPairs[I].SourceDir);
    TargetNodeId := SanitizeNodeId(DirPairs[I].TargetDir);
    
    WriteLn(OutFile, '  ', SourceNodeId, ' [label="', DirPairs[I].SourceDir, '"];');
    WriteLn(OutFile, '  ', TargetNodeId, ' [label="', DirPairs[I].TargetDir, '"];');
    WriteLn(OutFile, '  ', SourceNodeId, ' -> ', TargetNodeId, ' [label="', DirPairs[I].Count, '"];');
  End;
  
  WriteLn(OutFile, '}');
End;

Procedure GenerateModuleGraphDot(Var OutFile: Text);
{ Genere le graphe de dependances entre modules (unites/packages) }
Var
  I: Integer;
  SourceNodeId, TargetNodeId: String;
Begin
  WriteLn(OutFile, '// Graphe de dependances entre modules');
  WriteLn(OutFile, 'digraph "ModuleGraph" {');
  WriteLn(OutFile, '  graph [rankdir=TB, fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  node [shape=', DEPGRAPH_NODE_SHAPE, ', fontname="', DEPGRAPH_FONT_NAME, '", fontsize=', DEPGRAPH_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [style=', DEPGRAPH_EDGE_STYLE, '];');
  WriteLn(OutFile);
  
  { Parcourir toutes les dependances de type module (USES, IMPORT, etc.) }
  For I := 1 To DependencyCount Do
  Begin
    If (Dependencies[I].Kind = DEP_USES) Or 
       (Dependencies[I].Kind = DEP_IMPORT) Or
       (Dependencies[I].Kind = DEP_MODULE) Or
       (Dependencies[I].Kind = DEP_PACKAGE) Then
    Begin
      SourceNodeId := SanitizeNodeId(ExtractBaseFileName(Dependencies[I].SourceFile));
      TargetNodeId := SanitizeNodeId(ExtractBaseFileName(Dependencies[I].TargetFile));
      
      { Creer les noeuds }
      WriteLn(OutFile, '  ', SourceNodeId, ' [label="', ExtractBaseFileName(Dependencies[I].SourceFile), '"];');
      WriteLn(OutFile, '  ', TargetNodeId, ' [label="', ExtractBaseFileName(Dependencies[I].TargetFile), '"];');
      
      { Creer l'arete }
      WriteLn(OutFile, '  ', SourceNodeId, ' -> ', TargetNodeId, ';');
    End;
  End;
  
  WriteLn(OutFile, '}');
End;

Procedure RenderDependencyGraphImage(Const DotFile, ImageFile: String);
{ Genere l'image a partir du fichier DOT en utilisant les generateurs integres }
Var
  Format: String;
  I: Integer;
Begin
  { Determiner le format a partir de l'extension }
  Format := 'png';
  For I := Length(ImageFile) DownTo 1 Do
  Begin
    If ImageFile[I] = '.' Then
    Begin
      Format := Copy(ImageFile, I + 1, Length(ImageFile) - I);
      Break;
    End;
  End;
  
  { Utiliser le generateur PNG integre pour le format PNG }
  If (Format = 'png') Or (Format = 'PNG') Then
  Begin
    RenderDotToPng(DotFile, ImageFile);
  End
  { Utiliser le generateur SVG integre pour le format SVG }
  Else If (Format = 'svg') Or (Format = 'SVG') Then
  Begin
    RenderDotToSvg(DotFile, ImageFile);
  End
  { Utiliser le generateur Visio VDX integre pour le format VDX }
  Else If (Format = 'vdx') Or (Format = 'VDX') Then
  Begin
    RenderDotToVdx(DotFile, ImageFile);
  End
  Else
  Begin
    { Pour les autres formats, afficher un message }
    If Not Opts.Quiet Then
    Begin
      WriteLn('Note: Le format ', Format, ' n''est pas directement supporte.');
      WriteLn('Les formats PNG, SVG et VDX (Visio) sont generes nativement sans outil externe.');
    End;
  End;
End;

Procedure GenerateDepGraphDocumentation;
{ Orchestrateur: genere tous les graphes de dependances }
Var
  I: Integer;
  DotFile: Text;
  DotFileName, ImageFileName: String;
  ProcessedFiles: Array[1..MAX_DEPENDENCIES] Of String;
  ProcessedCount: Integer;
  Found: Boolean;
  J: Integer;
Begin
  If Not DepGraphInitialized Then
    InitDepGraph;
  
  If DependencyCount = 0 Then
  Begin
    If Not Opts.Quiet Then
      WriteLn('Aucune dependance trouvee pour generer les graphes.');
    Exit;
  End;
  
  If Not Opts.Quiet Then
  Begin
    WriteLn('Generation des graphes de dependances...');
    WriteLn('  Repertoire de sortie: ', DepGraphOutputDir);
    WriteLn('  Nombre de dependances: ', DependencyCount);
  End;
  
  { Collecter les fichiers sources uniques }
  ProcessedCount := 0;
  For I := 1 To DependencyCount Do
  Begin
    { Verifier si le fichier source a deja ete traite }
    Found := False;
    For J := 1 To ProcessedCount Do
    Begin
      If UpStr(ProcessedFiles[J]) = UpStr(Dependencies[I].SourceFile) Then
      Begin
        Found := True;
        Break;
      End;
    End;
    
    If Not Found And (ProcessedCount < MAX_DEPENDENCIES) Then
    Begin
      Inc(ProcessedCount);
      ProcessedFiles[ProcessedCount] := Dependencies[I].SourceFile;
    End;
  End;
  
  { Generer un graphe d'inclusion pour chaque fichier source }
  For I := 1 To ProcessedCount Do
  Begin
    DotFileName := DepGraphOutputDir + '/' + DEPGRAPH_INC_PREFIX + 
                   SanitizeNodeId(ExtractBaseFileName(ProcessedFiles[I])) + '.dot';
    ImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_INC_PREFIX + 
                     SanitizeNodeId(ExtractBaseFileName(ProcessedFiles[I])) + '.' + DepGraphFormat;
    
    If Not Opts.Quiet Then
      WriteLn('  Graphe d''inclusion: ', ProcessedFiles[I]);
    
    Assign(DotFile, DotFileName);
    {$I-}
    Rewrite(DotFile);
    {$I+}
    If IOResult = 0 Then
    Begin
      GenerateIncludeGraphDot(ProcessedFiles[I], DotFile);
      Close(DotFile);
      RenderDependencyGraphImage(DotFileName, ImageFileName);
    End;
  End;
  
  { Collecter les fichiers cibles uniques pour les graphes "included by" }
  ProcessedCount := 0;
  For I := 1 To DependencyCount Do
  Begin
    Found := False;
    For J := 1 To ProcessedCount Do
    Begin
      If UpStr(ProcessedFiles[J]) = UpStr(Dependencies[I].TargetFile) Then
      Begin
        Found := True;
        Break;
      End;
    End;
    
    If Not Found And (ProcessedCount < MAX_DEPENDENCIES) Then
    Begin
      Inc(ProcessedCount);
      ProcessedFiles[ProcessedCount] := Dependencies[I].TargetFile;
    End;
  End;
  
  { Generer un graphe "included by" pour chaque fichier cible }
  For I := 1 To ProcessedCount Do
  Begin
    DotFileName := DepGraphOutputDir + '/' + DEPGRAPH_INCBY_PREFIX + 
                   SanitizeNodeId(ExtractBaseFileName(ProcessedFiles[I])) + '.dot';
    ImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_INCBY_PREFIX + 
                     SanitizeNodeId(ExtractBaseFileName(ProcessedFiles[I])) + '.' + DepGraphFormat;
    
    If Not Opts.Quiet Then
      WriteLn('  Graphe included-by: ', ProcessedFiles[I]);
    
    Assign(DotFile, DotFileName);
    {$I-}
    Rewrite(DotFile);
    {$I+}
    If IOResult = 0 Then
    Begin
      GenerateIncludedByGraphDot(ProcessedFiles[I], DotFile);
      Close(DotFile);
      RenderDependencyGraphImage(DotFileName, ImageFileName);
    End;
  End;
  
  { Generer le graphe de dependances entre repertoires }
  DotFileName := DepGraphOutputDir + '/' + DEPGRAPH_DIR_PREFIX + 'graph.dot';
  ImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_DIR_PREFIX + 'graph.' + DepGraphFormat;
  
  If Not Opts.Quiet Then
    WriteLn('  Graphe de repertoires');
  
  Assign(DotFile, DotFileName);
  {$I-}
  Rewrite(DotFile);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateDirectoryGraphDot('', DotFile);
    Close(DotFile);
    RenderDependencyGraphImage(DotFileName, ImageFileName);
  End;
  
  { Generer le graphe de modules }
  DotFileName := DepGraphOutputDir + '/' + DEPGRAPH_MOD_PREFIX + 'graph.dot';
  ImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_MOD_PREFIX + 'graph.' + DepGraphFormat;
  
  If Not Opts.Quiet Then
    WriteLn('  Graphe de modules');
  
  Assign(DotFile, DotFileName);
  {$I-}
  Rewrite(DotFile);
  {$I+}
  If IOResult = 0 Then
  Begin
    GenerateModuleGraphDot(DotFile);
    Close(DotFile);
    RenderDependencyGraphImage(DotFileName, ImageFileName);
  End;
  
  If Not Opts.Quiet Then
    WriteLn('Generation des graphes de dependances terminee.');
End;

Function CountIncludeDependencies(Const FileName: String): Integer;
{ Compte le nombre de fichiers inclus par un fichier }
Var
  I: Integer;
  Count: Integer;
Begin
  Count := 0;
  For I := 1 To DependencyCount Do
  Begin
    If UpStr(Dependencies[I].SourceFile) = UpStr(FileName) Then
      Inc(Count);
  End;
  CountIncludeDependencies := Count;
End;

Function CountIncludedByDependencies(Const FileName: String): Integer;
{ Compte le nombre de fichiers qui incluent un fichier }
Var
  I: Integer;
  Count: Integer;
Begin
  Count := 0;
  For I := 1 To DependencyCount Do
  Begin
    If UpStr(Dependencies[I].TargetFile) = UpStr(FileName) Then
      Inc(Count);
  End;
  CountIncludedByDependencies := Count;
End;

Function IsDepGraphEmpty: Boolean;
{ Verifie si des graphes de dependances peuvent etre generes }
Begin
  IsDepGraphEmpty := (DependencyCount = 0);
End;

Function GetDepGraphDotFileName(Const BaseFileName: String; GraphType: Integer): String;
{ Construit le nom du fichier DOT pour un graphe de dependances }
{ GraphType: 1=include, 2=included_by, 3=directory, 4=module }
Begin
  Case GraphType Of
    1: GetDepGraphDotFileName := DepGraphOutputDir + '/' + DEPGRAPH_INC_PREFIX + 
                                  SanitizeNodeId(BaseFileName) + '.dot';
    2: GetDepGraphDotFileName := DepGraphOutputDir + '/' + DEPGRAPH_INCBY_PREFIX + 
                                  SanitizeNodeId(BaseFileName) + '.dot';
    3: GetDepGraphDotFileName := DepGraphOutputDir + '/' + DEPGRAPH_DIR_PREFIX + 'graph.dot';
    4: GetDepGraphDotFileName := DepGraphOutputDir + '/' + DEPGRAPH_MOD_PREFIX + 'graph.dot';
  Else
    GetDepGraphDotFileName := DepGraphOutputDir + '/' + DEPGRAPH_DOT_FILE;
  End;
End;

Function GetDepGraphImageFileName(Const BaseFileName: String; GraphType: Integer): String;
{ Construit le nom du fichier image pour un graphe de dependances }
{ GraphType: 1=include, 2=included_by, 3=directory, 4=module }
Begin
  Case GraphType Of
    1: GetDepGraphImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_INC_PREFIX + 
                                    SanitizeNodeId(BaseFileName) + '.' + DepGraphFormat;
    2: GetDepGraphImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_INCBY_PREFIX + 
                                    SanitizeNodeId(BaseFileName) + '.' + DepGraphFormat;
    3: GetDepGraphImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_DIR_PREFIX + 
                                    'graph.' + DepGraphFormat;
    4: GetDepGraphImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_MOD_PREFIX + 
                                    'graph.' + DepGraphFormat;
  Else
    GetDepGraphImageFileName := DepGraphOutputDir + '/' + DEPGRAPH_PNG_FILE;
  End;
End;

{ ============================================================
  GENERATION DES DIAGRAMMES DE CLASSES (TODO 19)
  ============================================================ }

Procedure InitClassDiagram;
{ Initialise le generateur de diagrammes de classes }
Begin
  ClassDiagOutputDir := CLASSDIAG_OUTPUT_DIR;
  ClassDiagFormat := 'png';
  ClassDiagUmlLook := True;
  ClassDiagInitialized := True;
End;

Function GetClassDiagOutputDir: String;
{ Retourne le repertoire de sortie des diagrammes de classes }
Begin
  GetClassDiagOutputDir := ClassDiagOutputDir;
End;

Procedure SetClassDiagOutputDir(Const Dir: String);
{ Definit le repertoire de sortie des diagrammes de classes }
Begin
  If Dir <> '' Then
    ClassDiagOutputDir := Dir
  Else
    ClassDiagOutputDir := CLASSDIAG_OUTPUT_DIR;
End;

Function GetClassDiagFormat: String;
{ Retourne le format d'image des diagrammes de classes }
Begin
  GetClassDiagFormat := ClassDiagFormat;
End;

Procedure SetClassDiagFormat(Const Fmt: String);
{ Definit le format d'image des diagrammes de classes }
Var
  FmtUp: String;
Begin
  FmtUp := UpStr(Fmt);
  If (FmtUp = 'PNG') Or (FmtUp = 'SVG') Or (FmtUp = 'PDF') Or (FmtUp = 'EPS') Then
    ClassDiagFormat := Fmt
  Else
    ClassDiagFormat := 'png';
End;

Function GetClassDiagUmlLook: Boolean;
{ Retourne si le mode UML est active }
Begin
  GetClassDiagUmlLook := ClassDiagUmlLook;
End;

Procedure SetClassDiagUmlLook(UmlLook: Boolean);
{ Active ou desactive le mode UML }
Begin
  ClassDiagUmlLook := UmlLook;
End;

Function IsClassDiagInitialized: Boolean;
{ Verifie si le generateur de diagrammes de classes est initialise }
Begin
  IsClassDiagInitialized := ClassDiagInitialized;
End;

Function VisibilitySymbol(Vis: TEntityVisibility): String;
{ Retourne le symbole UML pour la visibilite }
Begin
  Case Vis Of
    VIS_PUBLIC:    VisibilitySymbol := '+';
    VIS_PROTECTED: VisibilitySymbol := '#';
    VIS_PRIVATE:   VisibilitySymbol := '-';
    VIS_PACKAGE:   VisibilitySymbol := '~';
  Else
    VisibilitySymbol := '';
  End;
End;

Function VisibilityColor(Vis: TEntityVisibility): String;
{ Retourne la couleur pour la visibilite }
Begin
  Case Vis Of
    VIS_PUBLIC:    VisibilityColor := CLASSDIAG_PUBLIC_COLOR;
    VIS_PROTECTED: VisibilityColor := CLASSDIAG_PROTECTED_COLOR;
    VIS_PRIVATE:   VisibilityColor := CLASSDIAG_PRIVATE_COLOR;
    VIS_PACKAGE:   VisibilityColor := CLASSDIAG_PUBLIC_COLOR;
  Else
    VisibilityColor := CLASSDIAG_PUBLIC_COLOR;
  End;
End;

Function EscapeDotLabel(Const S: String): String;
{ Echappe une chaine pour l'utiliser dans un label DOT }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    Case S[I] Of
      '"':  R := R + '\"';
      '\':  R := R + '\\';
      '<':  R := R + '\<';
      '>':  R := R + '\>';
      '|':  R := R + '\|';
      '{':  R := R + '\{';
      '}':  R := R + '\}';
    Else
      R := R + S[I];
    End;
  End;
  EscapeDotLabel := R;
End;

Function SanitizeClassNodeId(Const Name: String): String;
{ Cree un ID de noeud valide pour DOT a partir d'un nom de classe }
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    If ((Name[I] >= 'A') And (Name[I] <= 'Z')) Or
       ((Name[I] >= 'a') And (Name[I] <= 'z')) Or
       ((Name[I] >= '0') And (Name[I] <= '9')) Or
       (Name[I] = '_') Then
      R := R + Name[I]
    Else
      R := R + '_';
  End;
  If R = '' Then
    R := 'node';
  SanitizeClassNodeId := R;
End;

Procedure GenerateClassDiagramDot(Const EntityId: Integer; Var OutFile: Text);
{ Genere le diagramme de classe au format DOT montrant les membres et methodes }
Var
  I: Integer;
  MemberCount: Integer;
  MethodCount: Integer;
  E: TEntity;
  ClassName, NodeId: String;
  Label1: String;
Begin
  If (EntityId < 1) Or (EntityId > EntityCount) Then Exit;
  
  E := Entities[EntityId];
  If Not (E.Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) Then Exit;
  
  ClassName := E.Name;
  NodeId := SanitizeClassNodeId(ClassName);
  
  { En-tete DOT }
  WriteLn(OutFile, 'digraph "', ClassName, '" {');
  WriteLn(OutFile, '  rankdir=TB;');
  WriteLn(OutFile, '  fontname="', CLASSDIAG_FONT_NAME, '";');
  WriteLn(OutFile, '  fontsize=', CLASSDIAG_FONT_SIZE, ';');
  WriteLn(OutFile, '  node [shape=', CLASSDIAG_NODE_SHAPE, ', fontname="', 
          CLASSDIAG_FONT_NAME, '", fontsize=', CLASSDIAG_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [fontname="', CLASSDIAG_FONT_NAME, '", fontsize=', 
          CLASSDIAG_FONT_SIZE - 2, '];');
  WriteLn(OutFile);
  
  { Compter les membres et methodes }
  MemberCount := 0;
  MethodCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].ParentId = EntityId Then
    Begin
      If Entities[I].Kind = ENT_FUNCTION Then
        Inc(MethodCount)
      Else If Entities[I].Kind = ENT_VARIABLE Then
        Inc(MemberCount);
    End;
  End;
  
  { Creer le noeud de la classe avec format record }
  Label1 := '{';
  
  { Nom de la classe }
  If E.IsAbstract Then
    Label1 := Label1 + '\<\<abstract\>\>\\n'
  Else If E.Kind = ENT_INTERFACE Then
    Label1 := Label1 + '\<\<interface\>\>\\n';
  Label1 := Label1 + EscapeDotLabel(ClassName);
  
  { Section des attributs }
  Label1 := Label1 + '|';
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_VARIABLE) Then
    Begin
      Label1 := Label1 + VisibilitySymbol(Entities[I].Visibility) + ' ';
      Label1 := Label1 + EscapeDotLabel(Entities[I].Name);
      If Entities[I].ReturnType <> '' Then
        Label1 := Label1 + ' : ' + EscapeDotLabel(Entities[I].ReturnType);
      Label1 := Label1 + '\\l';
    End;
  End;
  
  { Section des methodes }
  Label1 := Label1 + '|';
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_FUNCTION) Then
    Begin
      Label1 := Label1 + VisibilitySymbol(Entities[I].Visibility) + ' ';
      Label1 := Label1 + EscapeDotLabel(Entities[I].Name);
      Label1 := Label1 + '(' + EscapeDotLabel(Entities[I].Parameters) + ')';
      If Entities[I].ReturnType <> '' Then
        Label1 := Label1 + ' : ' + EscapeDotLabel(Entities[I].ReturnType);
      Label1 := Label1 + '\\l';
    End;
  End;
  
  Label1 := Label1 + '}';
  
  { Ecrire le noeud }
  If E.Kind = ENT_INTERFACE Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_INTERFACE_COLOR, '", style=filled];')
  Else If E.IsAbstract Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_ABSTRACT_COLOR, '", style=filled];')
  Else
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_CLASS_COLOR, '", style=filled];');
  
  WriteLn(OutFile);
  WriteLn(OutFile, '}');
End;

Procedure GenerateCollaborationDiagramDot(Const EntityId: Integer; Var OutFile: Text);
{ Genere le diagramme de collaboration au format DOT montrant les relations }
Var
  I, J: Integer;
  E: TEntity;
  ClassName, NodeId, RelatedId: String;
  RelatedClasses: Array[1..100] Of String;
  RelatedCount: Integer;
  Found: Boolean;
Begin
  If (EntityId < 1) Or (EntityId > EntityCount) Then Exit;
  
  E := Entities[EntityId];
  If Not (E.Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) Then Exit;
  
  ClassName := E.Name;
  NodeId := SanitizeClassNodeId(ClassName);
  
  { En-tete DOT }
  WriteLn(OutFile, 'digraph "', ClassName, '_collaboration" {');
  WriteLn(OutFile, '  rankdir=LR;');
  WriteLn(OutFile, '  fontname="', CLASSDIAG_FONT_NAME, '";');
  WriteLn(OutFile, '  fontsize=', CLASSDIAG_FONT_SIZE, ';');
  WriteLn(OutFile, '  node [shape=box, fontname="', CLASSDIAG_FONT_NAME, 
          '", fontsize=', CLASSDIAG_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [fontname="', CLASSDIAG_FONT_NAME, '", fontsize=', 
          CLASSDIAG_FONT_SIZE - 2, '];');
  WriteLn(OutFile);
  
  { Noeud principal }
  WriteLn(OutFile, '  ', NodeId, ' [label="', ClassName, '", fillcolor="', 
          CLASSDIAG_CLASS_COLOR, '", style=filled];');
  
  { Collecter les classes utilisees par cette classe }
  RelatedCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].ParentId = EntityId Then
    Begin
      { Verifier si le type de retour est une classe connue }
      If Entities[I].ReturnType <> '' Then
      Begin
        For J := 1 To EntityCount Do
        Begin
          If (Entities[J].Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) And
             (Pos(Entities[J].Name, Entities[I].ReturnType) > 0) And
             (Entities[J].Name <> ClassName) Then
          Begin
            { Verifier si deja dans la liste }
            Found := False;
            For J := 1 To RelatedCount Do
            Begin
              If RelatedClasses[J] = Entities[J].Name Then
              Begin
                Found := True;
                Break;
              End;
            End;
            If (Not Found) And (RelatedCount < 100) Then
            Begin
              Inc(RelatedCount);
              RelatedClasses[RelatedCount] := Entities[J].Name;
            End;
          End;
        End;
      End;
    End;
  End;
  
  { Ajouter les noeuds et aretes pour les classes liees }
  For I := 1 To RelatedCount Do
  Begin
    RelatedId := SanitizeClassNodeId(RelatedClasses[I]);
    WriteLn(OutFile, '  ', RelatedId, ' [label="', RelatedClasses[I], '"];');
    WriteLn(OutFile, '  ', NodeId, ' -> ', RelatedId, 
            ' [arrowhead=', CLASSDIAG_EDGE_ASSOC, ', label="uses"];');
  End;
  
  { Ajouter les relations d'heritage }
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ChildId = EntityId Then
    Begin
      RelatedId := SanitizeClassNodeId(Inheritances[I].ParentName);
      WriteLn(OutFile, '  ', RelatedId, ' [label="', Inheritances[I].ParentName, 
              '", fillcolor="', CLASSDIAG_CLASS_COLOR, '", style=filled];');
      WriteLn(OutFile, '  ', NodeId, ' -> ', RelatedId, 
              ' [arrowhead=', CLASSDIAG_EDGE_INHERIT, ', style=solid];');
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, '}');
End;

Procedure GenerateInheritanceDiagramDot(Const EntityId: Integer; Var OutFile: Text);
{ Genere le diagramme d'heritage au format DOT (classes de base et derivees) }
Var
  I: Integer;
  E: TEntity;
  ClassName, NodeId, ParentId, ChildId: String;
Begin
  If (EntityId < 1) Or (EntityId > EntityCount) Then Exit;
  
  E := Entities[EntityId];
  If Not (E.Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) Then Exit;
  
  ClassName := E.Name;
  NodeId := SanitizeClassNodeId(ClassName);
  
  { En-tete DOT }
  WriteLn(OutFile, 'digraph "', ClassName, '_inheritance" {');
  WriteLn(OutFile, '  rankdir=BT;');
  WriteLn(OutFile, '  fontname="', CLASSDIAG_FONT_NAME, '";');
  WriteLn(OutFile, '  fontsize=', CLASSDIAG_FONT_SIZE, ';');
  WriteLn(OutFile, '  node [shape=box, fontname="', CLASSDIAG_FONT_NAME, 
          '", fontsize=', CLASSDIAG_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [fontname="', CLASSDIAG_FONT_NAME, '", fontsize=', 
          CLASSDIAG_FONT_SIZE - 2, ', arrowhead=', CLASSDIAG_EDGE_INHERIT, '];');
  WriteLn(OutFile);
  
  { Noeud principal (classe courante) }
  If E.Kind = ENT_INTERFACE Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', ClassName, 
            '", fillcolor="', CLASSDIAG_INTERFACE_COLOR, '", style=filled];')
  Else If E.IsAbstract Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', ClassName, 
            '", fillcolor="', CLASSDIAG_ABSTRACT_COLOR, '", style=filled];')
  Else
    WriteLn(OutFile, '  ', NodeId, ' [label="', ClassName, 
            '", fillcolor="', CLASSDIAG_CLASS_COLOR, '", style=filled];');
  
  { Classes de base (parents) }
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ChildId = EntityId Then
    Begin
      ParentId := SanitizeClassNodeId(Inheritances[I].ParentName);
      WriteLn(OutFile, '  ', ParentId, ' [label="', Inheritances[I].ParentName, '"];');
      WriteLn(OutFile, '  ', NodeId, ' -> ', ParentId, ';');
    End;
  End;
  
  { Classes derivees (enfants) }
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ParentId = EntityId Then
    Begin
      { Trouver le nom de la classe enfant }
      If (Inheritances[I].ChildId >= 1) And (Inheritances[I].ChildId <= EntityCount) Then
      Begin
        ChildId := SanitizeClassNodeId(Entities[Inheritances[I].ChildId].Name);
        WriteLn(OutFile, '  ', ChildId, ' [label="', 
                Entities[Inheritances[I].ChildId].Name, '"];');
        WriteLn(OutFile, '  ', ChildId, ' -> ', NodeId, ';');
      End;
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, '}');
End;

Function EntityVisibilityToStr(Vis: TEntityVisibility): String;
{ Convertit la visibilite en chaine }
Begin
  Case Vis Of
    VIS_PUBLIC:    EntityVisibilityToStr := 'public';
    VIS_PROTECTED: EntityVisibilityToStr := 'protected';
    VIS_PRIVATE:   EntityVisibilityToStr := 'private';
    VIS_PACKAGE:   EntityVisibilityToStr := 'package';
  Else
    EntityVisibilityToStr := '';
  End;
End;

Procedure GenerateUmlDiagramDot(Const EntityId: Integer; Var OutFile: Text; 
  UmlLook: Boolean);
{ Genere le diagramme UML complet au format DOT }
Var
  I: Integer;
  E: TEntity;
  ClassName, NodeId, ParentId: String;
  Label1: String;
Begin
  If (EntityId < 1) Or (EntityId > EntityCount) Then Exit;
  
  E := Entities[EntityId];
  If Not (E.Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) Then Exit;
  
  ClassName := E.Name;
  NodeId := SanitizeClassNodeId(ClassName);
  
  { En-tete DOT }
  WriteLn(OutFile, 'digraph "', ClassName, '_uml" {');
  WriteLn(OutFile, '  rankdir=BT;');
  WriteLn(OutFile, '  fontname="', CLASSDIAG_FONT_NAME, '";');
  WriteLn(OutFile, '  fontsize=', CLASSDIAG_FONT_SIZE, ';');
  WriteLn(OutFile, '  splines=ortho;');
  WriteLn(OutFile, '  node [shape=', CLASSDIAG_NODE_SHAPE, ', fontname="', 
          CLASSDIAG_FONT_NAME, '", fontsize=', CLASSDIAG_FONT_SIZE, '];');
  WriteLn(OutFile, '  edge [fontname="', CLASSDIAG_FONT_NAME, '", fontsize=', 
          CLASSDIAG_FONT_SIZE - 2, '];');
  WriteLn(OutFile);
  
  { Creer le noeud de la classe avec format UML }
  Label1 := '{';
  
  { Stereotypes }
  If E.Kind = ENT_INTERFACE Then
    Label1 := Label1 + '\<\<interface\>\>\\n';
  If E.IsAbstract Then
    Label1 := Label1 + '\<\<abstract\>\>\\n';
  
  { Nom de la classe }
  Label1 := Label1 + EscapeDotLabel(ClassName);
  
  { Section des attributs }
  Label1 := Label1 + '|';
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_VARIABLE) Then
    Begin
      If UmlLook Then
        Label1 := Label1 + VisibilitySymbol(Entities[I].Visibility) + ' '
      Else
        Label1 := Label1 + EscapeDotLabel(EntityVisibilityToStr(Entities[I].Visibility)) + ' ';
      Label1 := Label1 + EscapeDotLabel(Entities[I].Name);
      If Entities[I].ReturnType <> '' Then
        Label1 := Label1 + ' : ' + EscapeDotLabel(Entities[I].ReturnType);
      Label1 := Label1 + '\\l';
    End;
  End;
  
  { Section des operations }
  Label1 := Label1 + '|';
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_FUNCTION) Then
    Begin
      If UmlLook Then
        Label1 := Label1 + VisibilitySymbol(Entities[I].Visibility) + ' '
      Else
        Label1 := Label1 + EscapeDotLabel(EntityVisibilityToStr(Entities[I].Visibility)) + ' ';
      If Entities[I].IsAbstract Then
        Label1 := Label1 + '\<abstract\> ';
      If Entities[I].IsStatic Then
        Label1 := Label1 + '\<static\> ';
      Label1 := Label1 + EscapeDotLabel(Entities[I].Name);
      Label1 := Label1 + '(' + EscapeDotLabel(Entities[I].Parameters) + ')';
      If Entities[I].ReturnType <> '' Then
        Label1 := Label1 + ' : ' + EscapeDotLabel(Entities[I].ReturnType);
      Label1 := Label1 + '\\l';
    End;
  End;
  
  Label1 := Label1 + '}';
  
  { Ecrire le noeud principal }
  If E.Kind = ENT_INTERFACE Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_INTERFACE_COLOR, '", style=filled];')
  Else If E.IsAbstract Then
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_ABSTRACT_COLOR, '", style=filled];')
  Else
    WriteLn(OutFile, '  ', NodeId, ' [label="', Label1, '", fillcolor="', 
            CLASSDIAG_CLASS_COLOR, '", style=filled];');
  
  { Relations d'heritage }
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ChildId = EntityId Then
    Begin
      ParentId := SanitizeClassNodeId(Inheritances[I].ParentName);
      WriteLn(OutFile, '  ', ParentId, ' [label="', Inheritances[I].ParentName, 
              '", shape=box];');
      
      If Inheritances[I].Relation = REL_IMPLEMENTS Then
        WriteLn(OutFile, '  ', NodeId, ' -> ', ParentId, 
                ' [arrowhead=', CLASSDIAG_EDGE_INHERIT, ', style=dashed, label="implements"];')
      Else
        WriteLn(OutFile, '  ', NodeId, ' -> ', ParentId, 
                ' [arrowhead=', CLASSDIAG_EDGE_INHERIT, ', style=solid];');
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, '}');
End;

Procedure RenderClassDiagramImage(Const DotFile, ImageFile: String);
{ Genere l'image a partir du fichier DOT en utilisant les generateurs integres }
Var
  Format: String;
  I: Integer;
Begin
  { Determiner le format a partir de l'extension }
  Format := 'png';
  For I := Length(ImageFile) DownTo 1 Do
  Begin
    If ImageFile[I] = '.' Then
    Begin
      Format := Copy(ImageFile, I + 1, Length(ImageFile) - I);
      Break;
    End;
  End;
  
  { Utiliser le generateur PNG integre pour le format PNG }
  If (Format = 'png') Or (Format = 'PNG') Then
  Begin
    RenderDotToPng(DotFile, ImageFile);
  End
  { Utiliser le generateur SVG integre pour le format SVG }
  Else If (Format = 'svg') Or (Format = 'SVG') Then
  Begin
    RenderDotToSvg(DotFile, ImageFile);
  End
  { Utiliser le generateur Visio VDX integre pour le format VDX }
  Else If (Format = 'vdx') Or (Format = 'VDX') Then
  Begin
    RenderDotToVdx(DotFile, ImageFile);
  End
  Else
  Begin
    { Pour les autres formats, afficher un message }
    If Not Opts.Quiet Then
    Begin
      WriteLn('Note: Le format ', Format, ' n''est pas directement supporte.');
      WriteLn('Les formats PNG, SVG et VDX (Visio) sont generes nativement sans outil externe.');
    End;
  End;
End;

Procedure GeneratePlantUml(Const EntityId: Integer; Var OutFile: Text);
{ Genere le code PlantUML pour le diagramme de classe }
Var
  I: Integer;
  E: TEntity;
  ClassName: String;
Begin
  If (EntityId < 1) Or (EntityId > EntityCount) Then Exit;
  
  E := Entities[EntityId];
  If Not (E.Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE]) Then Exit;
  
  ClassName := E.Name;
  
  { En-tete PlantUML }
  WriteLn(OutFile, CLASSDIAG_PLANTUML_START);
  WriteLn(OutFile);
  WriteLn(OutFile, 'skinparam classAttributeIconSize 0');
  WriteLn(OutFile, 'skinparam classFontName ', CLASSDIAG_FONT_NAME);
  WriteLn(OutFile, 'skinparam classFontSize ', CLASSDIAG_FONT_SIZE);
  WriteLn(OutFile);
  
  { Declaration de la classe }
  If E.Kind = ENT_INTERFACE Then
    WriteLn(OutFile, 'interface ', ClassName, ' {')
  Else If E.IsAbstract Then
    WriteLn(OutFile, 'abstract class ', ClassName, ' {')
  Else
    WriteLn(OutFile, 'class ', ClassName, ' {');
  
  { Attributs }
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_VARIABLE) Then
    Begin
      Write(OutFile, '  ', VisibilitySymbol(Entities[I].Visibility), ' ');
      Write(OutFile, Entities[I].Name);
      If Entities[I].ReturnType <> '' Then
        Write(OutFile, ' : ', Entities[I].ReturnType);
      WriteLn(OutFile);
    End;
  End;
  
  WriteLn(OutFile, '  --');
  
  { Methodes }
  For I := 1 To EntityCount Do
  Begin
    If (Entities[I].ParentId = EntityId) And (Entities[I].Kind = ENT_FUNCTION) Then
    Begin
      Write(OutFile, '  ', VisibilitySymbol(Entities[I].Visibility), ' ');
      If Entities[I].IsAbstract Then
        Write(OutFile, '{abstract} ');
      If Entities[I].IsStatic Then
        Write(OutFile, '{static} ');
      Write(OutFile, Entities[I].Name, '(', Entities[I].Parameters, ')');
      If Entities[I].ReturnType <> '' Then
        Write(OutFile, ' : ', Entities[I].ReturnType);
      WriteLn(OutFile);
    End;
  End;
  
  WriteLn(OutFile, '}');
  WriteLn(OutFile);
  
  { Relations d'heritage }
  For I := 1 To InheritanceCount Do
  Begin
    If Inheritances[I].ChildId = EntityId Then
    Begin
      If Inheritances[I].Relation = REL_IMPLEMENTS Then
        WriteLn(OutFile, Inheritances[I].ParentName, ' <|.. ', ClassName)
      Else
        WriteLn(OutFile, Inheritances[I].ParentName, ' <|-- ', ClassName);
    End;
  End;
  
  WriteLn(OutFile);
  WriteLn(OutFile, CLASSDIAG_PLANTUML_END);
End;

Procedure GenerateClassDiagramDocumentation;
{ Orchestrateur: genere tous les diagrammes de classes }
Var
  I: Integer;
  DotFile: Text;
  DotFileName, ImageFileName, PlantUmlFileName: String;
  ClassCount: Integer;
Begin
  If Not ClassDiagInitialized Then
    InitClassDiagram;
  
  { Creer le repertoire de sortie }
  {$I-}
  MkDir(ClassDiagOutputDir);
  {$I+}
  If IOResult <> 0 Then; { Ignorer si existe deja }
  
  If Not Opts.Quiet Then
  Begin
    WriteLn('Generation des diagrammes de classes...');
    WriteLn('  Repertoire de sortie: ', ClassDiagOutputDir);
  End;
  
  ClassCount := 0;
  
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE] Then
    Begin
      Inc(ClassCount);
      
      { Diagramme de classe }
      DotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_CLASS_PREFIX + 
                     SanitizeClassNodeId(Entities[I].Name) + '.dot';
      ImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_CLASS_PREFIX + 
                       SanitizeClassNodeId(Entities[I].Name) + '.' + ClassDiagFormat;
      
      If Not Opts.Quiet Then
        WriteLn('  Classe: ', Entities[I].Name);
      
      Assign(DotFile, DotFileName);
      {$I-}
      Rewrite(DotFile);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateClassDiagramDot(I, DotFile);
        Close(DotFile);
        RenderClassDiagramImage(DotFileName, ImageFileName);
      End;
      
      { Diagramme de collaboration }
      DotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_COLLAB_PREFIX + 
                     SanitizeClassNodeId(Entities[I].Name) + '.dot';
      ImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_COLLAB_PREFIX + 
                       SanitizeClassNodeId(Entities[I].Name) + '.' + ClassDiagFormat;
      
      Assign(DotFile, DotFileName);
      {$I-}
      Rewrite(DotFile);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateCollaborationDiagramDot(I, DotFile);
        Close(DotFile);
        RenderClassDiagramImage(DotFileName, ImageFileName);
      End;
      
      { Diagramme d'heritage }
      DotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_INHERIT_PREFIX + 
                     SanitizeClassNodeId(Entities[I].Name) + '.dot';
      ImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_INHERIT_PREFIX + 
                       SanitizeClassNodeId(Entities[I].Name) + '.' + ClassDiagFormat;
      
      Assign(DotFile, DotFileName);
      {$I-}
      Rewrite(DotFile);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateInheritanceDiagramDot(I, DotFile);
        Close(DotFile);
        RenderClassDiagramImage(DotFileName, ImageFileName);
      End;
      
      { Diagramme UML }
      DotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_UML_PREFIX + 
                     SanitizeClassNodeId(Entities[I].Name) + '.dot';
      ImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_UML_PREFIX + 
                       SanitizeClassNodeId(Entities[I].Name) + '.' + ClassDiagFormat;
      
      Assign(DotFile, DotFileName);
      {$I-}
      Rewrite(DotFile);
      {$I+}
      If IOResult = 0 Then
      Begin
        GenerateUmlDiagramDot(I, DotFile, ClassDiagUmlLook);
        Close(DotFile);
        RenderClassDiagramImage(DotFileName, ImageFileName);
      End;
      
      { Code PlantUML }
      PlantUmlFileName := ClassDiagOutputDir + '/' + 
                          SanitizeClassNodeId(Entities[I].Name) + '.puml';
      
      Assign(DotFile, PlantUmlFileName);
      {$I-}
      Rewrite(DotFile);
      {$I+}
      If IOResult = 0 Then
      Begin
        GeneratePlantUml(I, DotFile);
        Close(DotFile);
      End;
    End;
  End;
  
  If Not Opts.Quiet Then
  Begin
    WriteLn('  Nombre de classes: ', ClassCount);
    WriteLn('Generation des diagrammes de classes terminee.');
  End;
End;

Function CountClassDiagrams: Integer;
{ Compte le nombre de classes pour lesquelles un diagramme peut etre genere }
Var
  I: Integer;
  Count: Integer;
Begin
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind In [ENT_CLASS, ENT_STRUCT, ENT_INTERFACE] Then
      Inc(Count);
  End;
  CountClassDiagrams := Count;
End;

Function IsClassDiagEmpty: Boolean;
{ Verifie s'il y a des classes pour generer des diagrammes }
Begin
  IsClassDiagEmpty := (CountClassDiagrams = 0);
End;

Function GetClassDiagDotFileName(Const ClassName: String; DiagType: Integer): String;
{ Construit le nom du fichier DOT pour un diagramme de classe }
{ DiagType: 1=class, 2=collab, 3=inherit, 4=uml }
Begin
  Case DiagType Of
    1: GetClassDiagDotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_CLASS_PREFIX + 
                                  SanitizeClassNodeId(ClassName) + '.dot';
    2: GetClassDiagDotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_COLLAB_PREFIX + 
                                  SanitizeClassNodeId(ClassName) + '.dot';
    3: GetClassDiagDotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_INHERIT_PREFIX + 
                                  SanitizeClassNodeId(ClassName) + '.dot';
    4: GetClassDiagDotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_UML_PREFIX + 
                                  SanitizeClassNodeId(ClassName) + '.dot';
  Else
    GetClassDiagDotFileName := ClassDiagOutputDir + '/' + CLASSDIAG_DOT_FILE;
  End;
End;

Function GetClassDiagImageFileName(Const ClassName: String; DiagType: Integer): String;
{ Construit le nom du fichier image pour un diagramme de classe }
{ DiagType: 1=class, 2=collab, 3=inherit, 4=uml }
Begin
  Case DiagType Of
    1: GetClassDiagImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_CLASS_PREFIX + 
                                    SanitizeClassNodeId(ClassName) + '.' + ClassDiagFormat;
    2: GetClassDiagImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_COLLAB_PREFIX + 
                                    SanitizeClassNodeId(ClassName) + '.' + ClassDiagFormat;
    3: GetClassDiagImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_INHERIT_PREFIX + 
                                    SanitizeClassNodeId(ClassName) + '.' + ClassDiagFormat;
    4: GetClassDiagImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_UML_PREFIX + 
                                    SanitizeClassNodeId(ClassName) + '.' + ClassDiagFormat;
  Else
    GetClassDiagImageFileName := ClassDiagOutputDir + '/' + CLASSDIAG_PNG_FILE;
  End;
End;

Function GetClassDiagPlantUmlFileName(Const ClassName: String): String;
{ Construit le nom du fichier PlantUML pour une classe }
Begin
  GetClassDiagPlantUmlFileName := ClassDiagOutputDir + '/' + 
                                  SanitizeClassNodeId(ClassName) + '.puml';
End;

{ ============================================================
  SUPPORT DES MACROS ET PREPROCESSEUR (TODO 20)
  ============================================================ }

Procedure InitMacros;
{ Initialise le systeme de macros }
Var
  I: Integer;
Begin
  MacroCount := 0;
  PredefinedCount := 0;
  IfDefStackDepth := 0;
  For I := 1 To MAX_MACROS Do
  Begin
    Macros[I].Name := '';
    Macros[I].Parameters := '';
    Macros[I].Value := '';
    Macros[I].FileName := '';
    Macros[I].Line := 0;
    Macros[I].IsFuncLike := False;
    Macros[I].IsVariadic := False;
  End;
  For I := 1 To MAX_PREDEFINED Do
  Begin
    PredefinedMacros[I].Name := '';
    PredefinedMacros[I].Parameters := '';
    PredefinedMacros[I].Value := '';
    PredefinedMacros[I].FileName := '';
    PredefinedMacros[I].Line := 0;
    PredefinedMacros[I].IsFuncLike := False;
    PredefinedMacros[I].IsVariadic := False;
  End;
  For I := 1 To MAX_INCLUDE_STACK Do
  Begin
    IfDefStack[I].State := PP_ACTIVE;
    IfDefStack[I].WasActive := False;
    IfDefStack[I].Line := 0;
  End;
  MacrosInitialized := True;
End;

Function GetMacroCount: Integer;
{ Retourne le nombre de macros definies }
Begin
  GetMacroCount := MacroCount;
End;

Function GetPredefinedCount: Integer;
{ Retourne le nombre de macros predefinies }
Begin
  GetPredefinedCount := PredefinedCount;
End;

Function IsMacrosInitialized: Boolean;
{ Verifie si le systeme de macros est initialise }
Begin
  IsMacrosInitialized := MacrosInitialized;
End;

Function IsMacrosEmpty: Boolean;
{ Verifie si aucune macro n'est definie }
Begin
  IsMacrosEmpty := (MacroCount = 0) And (PredefinedCount = 0);
End;

Function FindMacro(Const Name: String): Integer;
{ Cherche une macro par son nom, retourne l'index ou 0 si non trouvee }
Var
  I: Integer;
  UpName: String;
Begin
  FindMacro := 0;
  UpName := UpStr(Name);
  { Chercher d'abord dans les macros definies }
  For I := 1 To MacroCount Do
    If UpStr(Macros[I].Name) = UpName Then
    Begin
      FindMacro := I;
      Exit;
    End;
  { Chercher dans les macros predefinies }
  For I := 1 To PredefinedCount Do
    If UpStr(PredefinedMacros[I].Name) = UpName Then
    Begin
      FindMacro := -I; { Negatif pour indiquer predefinies }
      Exit;
    End;
End;

Function IsMacroDefined(Const Name: String): Boolean;
{ Verifie si une macro est definie }
Begin
  IsMacroDefined := FindMacro(Name) <> 0;
End;

Function GetMacro(Index: Integer): TMacro;
{ Retourne une macro par son index }
Var
  EmptyMacro: TMacro;
Begin
  EmptyMacro.Name := '';
  EmptyMacro.Parameters := '';
  EmptyMacro.Value := '';
  EmptyMacro.FileName := '';
  EmptyMacro.Line := 0;
  EmptyMacro.IsFuncLike := False;
  EmptyMacro.IsVariadic := False;
  
  If (Index >= 1) And (Index <= MacroCount) Then
    GetMacro := Macros[Index]
  Else
    GetMacro := EmptyMacro;
End;

Function GetPredefinedMacro(Index: Integer): TMacro;
{ Retourne une macro predefinie par son index }
Var
  EmptyMacro: TMacro;
Begin
  EmptyMacro.Name := '';
  EmptyMacro.Parameters := '';
  EmptyMacro.Value := '';
  EmptyMacro.FileName := '';
  EmptyMacro.Line := 0;
  EmptyMacro.IsFuncLike := False;
  EmptyMacro.IsVariadic := False;
  
  If (Index >= 1) And (Index <= PredefinedCount) Then
    GetPredefinedMacro := PredefinedMacros[Index]
  Else
    GetPredefinedMacro := EmptyMacro;
End;

Function AddMacro(Const Name, Params, Value, FileName: String; 
                  Line: Integer; FuncLike, Variadic: Boolean): Boolean;
{ Ajoute une nouvelle macro }
Var
  Idx: Integer;
Begin
  AddMacro := False;
  If MacroCount >= MAX_MACROS Then Exit;
  If Name = '' Then Exit;
  
  { Verifier si la macro existe deja }
  Idx := FindMacro(Name);
  If Idx > 0 Then
  Begin
    { Mettre a jour la macro existante }
    Macros[Idx].Parameters := Params;
    Macros[Idx].Value := Value;
    Macros[Idx].FileName := FileName;
    Macros[Idx].Line := Line;
    Macros[Idx].IsFuncLike := FuncLike;
    Macros[Idx].IsVariadic := Variadic;
    AddMacro := True;
    Exit;
  End;
  
  Inc(MacroCount);
  Macros[MacroCount].Name := Name;
  Macros[MacroCount].Parameters := Params;
  Macros[MacroCount].Value := Value;
  Macros[MacroCount].FileName := FileName;
  Macros[MacroCount].Line := Line;
  Macros[MacroCount].IsFuncLike := FuncLike;
  Macros[MacroCount].IsVariadic := Variadic;
  AddMacro := True;
End;

Function AddPredefinedMacro(Const Name, Value: String): Boolean;
{ Ajoute une macro predefinie (option -D de la config) }
Begin
  AddPredefinedMacro := False;
  If PredefinedCount >= MAX_PREDEFINED Then Exit;
  If Name = '' Then Exit;
  
  Inc(PredefinedCount);
  PredefinedMacros[PredefinedCount].Name := Name;
  PredefinedMacros[PredefinedCount].Parameters := '';
  PredefinedMacros[PredefinedCount].Value := Value;
  PredefinedMacros[PredefinedCount].FileName := '<predefined>';
  PredefinedMacros[PredefinedCount].Line := 0;
  PredefinedMacros[PredefinedCount].IsFuncLike := False;
  PredefinedMacros[PredefinedCount].IsVariadic := False;
  AddPredefinedMacro := True;
End;

Procedure RemoveMacro(Const Name: String);
{ Supprime une macro (#undef) }
Var
  I, Idx: Integer;
Begin
  Idx := FindMacro(Name);
  If Idx <= 0 Then Exit; { Macro non trouvee ou predefinie }
  
  { Decaler les macros suivantes }
  For I := Idx To MacroCount - 1 Do
    Macros[I] := Macros[I + 1];
  Dec(MacroCount);
  
  { Effacer la derniere entree }
  Macros[MacroCount + 1].Name := '';
  Macros[MacroCount + 1].Parameters := '';
  Macros[MacroCount + 1].Value := '';
End;

Function ParseMacroParams(Const ParamStr: String): Integer;
{ Parse les parametres d'une macro fonction-like }
{ Retourne le nombre de parametres }
Var
  I, Count, Depth: Integer;
Begin
  Count := 0;
  If ParamStr = '' Then
  Begin
    ParseMacroParams := 0;
    Exit;
  End;
  
  Count := 1;
  Depth := 0;
  For I := 1 To Length(ParamStr) Do
  Begin
    Case ParamStr[I] Of
      '(': Inc(Depth);
      ')': Dec(Depth);
      ',': If Depth = 0 Then Inc(Count);
    End;
  End;
  ParseMacroParams := Count;
End;

Function ExtractMacroName(Const Line: String; Var StartPos: Integer): String;
{ Extrait le nom d'une macro a partir de la position donnee }
Var
  I: Integer;
  Name: String;
Begin
  Name := '';
  I := StartPos;
  
  { Ignorer les espaces }
  While (I <= Length(Line)) And ((Line[I] = ' ') Or (Line[I] = #9)) Do
    Inc(I);
  
  { Lire le nom (identifiant C) }
  While (I <= Length(Line)) And 
        (((Line[I] >= 'A') And (Line[I] <= 'Z')) Or
         ((Line[I] >= 'a') And (Line[I] <= 'z')) Or
         ((Line[I] >= '0') And (Line[I] <= '9') And (Name <> '')) Or
         (Line[I] = '_')) Do
  Begin
    Name := Name + Line[I];
    Inc(I);
  End;
  
  StartPos := I;
  ExtractMacroName := Name;
End;

Function ExtractMacroValue(Const Line: String; StartPos: Integer): String;
{ Extrait la valeur d'une macro }
Var
  I: Integer;
  Value: String;
  InString: Boolean;
  StringChar: Char;
Begin
  Value := '';
  InString := False;
  StringChar := #0;
  I := StartPos;
  
  { Ignorer les espaces initiaux }
  While (I <= Length(Line)) And ((Line[I] = ' ') Or (Line[I] = #9)) Do
    Inc(I);
  
  { Lire la valeur jusqu'a la fin de ligne ou un commentaire }
  While I <= Length(Line) Do
  Begin
    If Not InString Then
    Begin
      { Detecter le debut d'une chaine }
      If (Line[I] = '"') Or (Line[I] = '''') Then
      Begin
        InString := True;
        StringChar := Line[I];
      End
      { Detecter un commentaire C }
      Else If (I < Length(Line)) And (Line[I] = '/') And 
              ((Line[I+1] = '/') Or (Line[I+1] = '*')) Then
        Break;
    End
    Else
    Begin
      { Detecter la fin d'une chaine }
      If (Line[I] = StringChar) And (I > 1) And (Line[I-1] <> '\') Then
        InString := False;
    End;
    Value := Value + Line[I];
    Inc(I);
  End;
  
  ExtractMacroValue := TrimStr(Value);
End;

Procedure ParseDefineLine(Const Line, FileName: String; LineNum: Integer);
{ Parse une ligne #define et ajoute la macro }
Var
  I, J: Integer;
  Name, Params, Value: String;
  IsFuncLike, IsVariadic: Boolean;
Begin
  I := 1;
  
  { Trouver le debut de #define }
  While (I <= Length(Line)) And ((Line[I] = ' ') Or (Line[I] = #9)) Do
    Inc(I);
  
  { Verifier que c'est bien #define }
  If (I + 6 > Length(Line)) Or (UpStr(Copy(Line, I, 7)) <> '#DEFINE') Then
    Exit;
  
  I := I + 7;
  
  { Extraire le nom }
  Name := ExtractMacroName(Line, I);
  If Name = '' Then Exit;
  
  { Verifier si c'est une macro fonction-like }
  IsFuncLike := False;
  IsVariadic := False;
  Params := '';
  
  If (I <= Length(Line)) And (Line[I] = '(') Then
  Begin
    IsFuncLike := True;
    Inc(I);
    J := I;
    While (J <= Length(Line)) And (Line[J] <> ')') Do
      Inc(J);
    If J > I Then
      Params := Copy(Line, I, J - I);
    I := J + 1;
    { Verifier si variadique (...) }
    If Pos('...', Params) > 0 Then
      IsVariadic := True;
  End;
  
  { Extraire la valeur }
  Value := ExtractMacroValue(Line, I);
  
  { Ajouter la macro }
  AddMacro(Name, Params, Value, FileName, LineNum, IsFuncLike, IsVariadic);
End;

Procedure ExtractMacros(Const FileName: String);
{ Scanne un fichier pour les directives #define }
Var
  F: Text;
  Line: String;
  LineNum: Integer;
  TrimmedLine: String;
Begin
  If Not MacrosInitialized Then InitMacros;
  
  {$I-}
  Assign(F, FileName);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNum := 0;
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNum);
    TrimmedLine := TrimStr(Line);
    
    { Detecter les directives preprocesseur }
    If (Length(TrimmedLine) > 0) And (TrimmedLine[1] = '#') Then
    Begin
      { #define }
      If (Length(TrimmedLine) >= 7) And 
         (UpStr(Copy(TrimmedLine, 1, 7)) = '#DEFINE') Then
        ParseDefineLine(Line, FileName, LineNum)
      { #undef }
      Else If (Length(TrimmedLine) >= 6) And 
              (UpStr(Copy(TrimmedLine, 1, 6)) = '#UNDEF') Then
      Begin
        { Extraire le nom et supprimer la macro }
        LineNum := 7; { Reutiliser comme position }
        RemoveMacro(ExtractMacroName(TrimmedLine, LineNum));
      End;
    End;
  End;
  
  Close(F);
End;

Function ExpandMacroSimple(Const Name: String): String;
{ Expande une macro simple (sans arguments) }
Var
  Idx: Integer;
Begin
  ExpandMacroSimple := Name;
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
  Begin
    If Not Macros[Idx].IsFuncLike Then
      ExpandMacroSimple := Macros[Idx].Value;
  End
  Else If Idx < 0 Then
  Begin
    Idx := -Idx;
    If Not PredefinedMacros[Idx].IsFuncLike Then
      ExpandMacroSimple := PredefinedMacros[Idx].Value;
  End;
End;

Function GetMacroValue(Const Name: String): String;
{ Retourne la valeur d'une macro }
Var
  Idx: Integer;
Begin
  GetMacroValue := '';
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    GetMacroValue := Macros[Idx].Value
  Else If Idx < 0 Then
    GetMacroValue := PredefinedMacros[-Idx].Value;
End;

Function GetMacroParams(Const Name: String): String;
{ Retourne les parametres d'une macro }
Var
  Idx: Integer;
Begin
  GetMacroParams := '';
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    GetMacroParams := Macros[Idx].Parameters
  Else If Idx < 0 Then
    GetMacroParams := PredefinedMacros[-Idx].Parameters;
End;

Function IsMacroFuncLike(Const Name: String): Boolean;
{ Verifie si une macro est fonction-like }
Var
  Idx: Integer;
Begin
  IsMacroFuncLike := False;
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    IsMacroFuncLike := Macros[Idx].IsFuncLike
  Else If Idx < 0 Then
    IsMacroFuncLike := PredefinedMacros[-Idx].IsFuncLike;
End;

Function IsMacroVariadic(Const Name: String): Boolean;
{ Verifie si une macro est variadique }
Var
  Idx: Integer;
Begin
  IsMacroVariadic := False;
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    IsMacroVariadic := Macros[Idx].IsVariadic
  Else If Idx < 0 Then
    IsMacroVariadic := PredefinedMacros[-Idx].IsVariadic;
End;

Procedure PushIfDefState(State: TPreprocessorState; Line: Integer);
{ Empile un nouvel etat #if }
Begin
  If IfDefStackDepth >= MAX_INCLUDE_STACK Then
  Begin
    WarnMsg('Profondeur maximale de #if atteinte');
    Exit;
  End;
  
  Inc(IfDefStackDepth);
  IfDefStack[IfDefStackDepth].State := State;
  IfDefStack[IfDefStackDepth].WasActive := (State = PP_ACTIVE);
  IfDefStack[IfDefStackDepth].Line := Line;
End;

Procedure PopIfDefState;
{ Depile l'etat #if courant }
Begin
  If IfDefStackDepth > 0 Then
    Dec(IfDefStackDepth);
End;

Function GetCurrentPPState: TPreprocessorState;
{ Retourne l'etat preprocesseur courant }
Begin
  If IfDefStackDepth = 0 Then
    GetCurrentPPState := PP_ACTIVE
  Else
    GetCurrentPPState := IfDefStack[IfDefStackDepth].State;
End;

Function IsPreprocessorActive: Boolean;
{ Verifie si le preprocesseur est en mode actif }
Var
  I: Integer;
Begin
  IsPreprocessorActive := True;
  For I := 1 To IfDefStackDepth Do
    If IfDefStack[I].State <> PP_ACTIVE Then
    Begin
      IsPreprocessorActive := False;
      Exit;
    End;
End;

Procedure HandleIfDef(Const MacroName: String; Line: Integer; IsNDef: Boolean);
{ Gere #ifdef ou #ifndef }
Var
  Defined: Boolean;
Begin
  Defined := IsMacroDefined(MacroName);
  If IsNDef Then
    Defined := Not Defined;
  
  If Not IsPreprocessorActive Then
    PushIfDefState(PP_SKIPPING, Line)
  Else If Defined Then
    PushIfDefState(PP_ACTIVE, Line)
  Else
    PushIfDefState(PP_SKIPPING, Line);
End;

Procedure HandleElse;
{ Gere #else }
Begin
  If IfDefStackDepth = 0 Then
  Begin
    WarnMsg('#else sans #if');
    Exit;
  End;
  
  If IfDefStack[IfDefStackDepth].WasActive Then
    IfDefStack[IfDefStackDepth].State := PP_DONE
  Else If IfDefStack[IfDefStackDepth].State = PP_SKIPPING Then
  Begin
    { Verifier si un niveau superieur est actif }
    If (IfDefStackDepth = 1) Or (IfDefStack[IfDefStackDepth - 1].State = PP_ACTIVE) Then
    Begin
      IfDefStack[IfDefStackDepth].State := PP_ACTIVE;
      IfDefStack[IfDefStackDepth].WasActive := True;
    End;
  End
  Else
    IfDefStack[IfDefStackDepth].State := PP_DONE;
End;

Procedure HandleEndIf;
{ Gere #endif }
Begin
  If IfDefStackDepth = 0 Then
  Begin
    WarnMsg('#endif sans #if');
    Exit;
  End;
  PopIfDefState;
End;

Function CountTotalMacros: Integer;
{ Compte le nombre total de macros (definies + predefinies) }
Begin
  CountTotalMacros := MacroCount + PredefinedCount;
End;

Function GetMacroFileName(Const Name: String): String;
{ Retourne le fichier de definition d'une macro }
Var
  Idx: Integer;
Begin
  GetMacroFileName := '';
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    GetMacroFileName := Macros[Idx].FileName
  Else If Idx < 0 Then
    GetMacroFileName := PredefinedMacros[-Idx].FileName;
End;

Function GetMacroLine(Const Name: String): Integer;
{ Retourne la ligne de definition d'une macro }
Var
  Idx: Integer;
Begin
  GetMacroLine := 0;
  Idx := FindMacro(Name);
  
  If Idx > 0 Then
    GetMacroLine := Macros[Idx].Line
  Else If Idx < 0 Then
    GetMacroLine := PredefinedMacros[-Idx].Line;
End;

Procedure ShowMacros;
{ Affiche la liste des macros pour debogage }
Var
  I: Integer;
Begin
  WriteLn('=== Macros definies (', MacroCount, ') ===');
  For I := 1 To MacroCount Do
  Begin
    Write('  ', Macros[I].Name);
    If Macros[I].IsFuncLike Then
      Write('(', Macros[I].Parameters, ')');
    WriteLn(' = ', Macros[I].Value);
  End;
  
  WriteLn;
  WriteLn('=== Macros predefinies (', PredefinedCount, ') ===');
  For I := 1 To PredefinedCount Do
  Begin
    Write('  ', PredefinedMacros[I].Name);
    WriteLn(' = ', PredefinedMacros[I].Value);
  End;
End;

{ ============================================================
  SUPPORT DES ESPACES DE NOMS ET MODULES (TODO 21)
  ============================================================ }

{ Initialise le systeme de namespaces et modules }
Procedure InitNamespaces;
Var
  I: Integer;
Begin
  NamespaceCount := 0;
  ModuleCount := 0;
  NamespaceStackDepth := 0;
  
  For I := 1 To MAX_NAMESPACES Do
  Begin
    Namespaces[I].Name := '';
    Namespaces[I].FullName := '';
    Namespaces[I].ParentId := -1;
    Namespaces[I].FileName := '';
    Namespaces[I].Line := 0;
    Namespaces[I].EndLine := 0;
    Namespaces[I].IsAnonymous := False;
    Namespaces[I].IsInline := False;
    Namespaces[I].Language := '';
  End;
  
  For I := 1 To MAX_MODULES Do
  Begin
    Modules[I].Name := '';
    Modules[I].FileName := '';
    Modules[I].ExportList := '';
    Modules[I].ImportList := '';
    Modules[I].IsPartition := False;
    Modules[I].IsInterface := False;
    Modules[I].Line := 0;
  End;
  
  For I := 1 To MAX_NS_DEPTH Do
    NamespaceStack[I] := -1;
  
  NamespacesInitialized := True;
End;

{ Cherche un namespace par nom complet }
Function FindNamespace(Const FullName: String): Integer;
Var
  I: Integer;
  UpperName: String;
Begin
  UpperName := UpStr(FullName);
  FindNamespace := -1;
  For I := 1 To NamespaceCount Do
    If UpStr(Namespaces[I].FullName) = UpperName Then
    Begin
      FindNamespace := I;
      Exit;
    End;
End;

{ Cherche un namespace par nom simple }
Function FindNamespaceByName(Const Name: String): Integer;
Var
  I: Integer;
  UpperName: String;
Begin
  UpperName := UpStr(Name);
  FindNamespaceByName := -1;
  For I := 1 To NamespaceCount Do
    If UpStr(Namespaces[I].Name) = UpperName Then
    Begin
      FindNamespaceByName := I;
      Exit;
    End;
End;

{ Ajoute un namespace }
Function AddNamespace(Const Name, FullName, FileName, Lang: String;
                      Line: Integer; ParentId: Integer;
                      IsAnon, IsInln: Boolean): Integer;
Begin
  If NamespaceCount >= MAX_NAMESPACES Then
  Begin
    WarnMsg('Nombre maximum de namespaces atteint');
    AddNamespace := -1;
    Exit;
  End;
  
  Inc(NamespaceCount);
  Namespaces[NamespaceCount].Name := Name;
  Namespaces[NamespaceCount].FullName := FullName;
  Namespaces[NamespaceCount].ParentId := ParentId;
  Namespaces[NamespaceCount].FileName := FileName;
  Namespaces[NamespaceCount].Line := Line;
  Namespaces[NamespaceCount].EndLine := 0;
  Namespaces[NamespaceCount].IsAnonymous := IsAnon;
  Namespaces[NamespaceCount].IsInline := IsInln;
  Namespaces[NamespaceCount].Language := Lang;
  
  AddNamespace := NamespaceCount;
End;

{ Cherche un module par nom }
Function FindModule(Const Name: String): Integer;
Var
  I: Integer;
  UpperName: String;
Begin
  UpperName := UpStr(Name);
  FindModule := -1;
  For I := 1 To ModuleCount Do
    If UpStr(Modules[I].Name) = UpperName Then
    Begin
      FindModule := I;
      Exit;
    End;
End;

{ Ajoute un module }
Function AddModule(Const Name, FileName: String; Line: Integer;
                   IsPart, IsIntf: Boolean): Integer;
Begin
  If ModuleCount >= MAX_MODULES Then
  Begin
    WarnMsg('Nombre maximum de modules atteint');
    AddModule := -1;
    Exit;
  End;
  
  Inc(ModuleCount);
  Modules[ModuleCount].Name := Name;
  Modules[ModuleCount].FileName := FileName;
  Modules[ModuleCount].ExportList := '';
  Modules[ModuleCount].ImportList := '';
  Modules[ModuleCount].IsPartition := IsPart;
  Modules[ModuleCount].IsInterface := IsIntf;
  Modules[ModuleCount].Line := Line;
  
  AddModule := ModuleCount;
End;

{ Ajoute un export a un module }
Procedure AddModuleExport(ModuleId: Integer; Const ExportName: String);
Begin
  If (ModuleId < 1) Or (ModuleId > ModuleCount) Then Exit;
  If Modules[ModuleId].ExportList = '' Then
    Modules[ModuleId].ExportList := ExportName
  Else
    Modules[ModuleId].ExportList := Modules[ModuleId].ExportList + ';' + ExportName;
End;

{ Ajoute un import a un module }
Procedure AddModuleImport(ModuleId: Integer; Const ImportName: String);
Begin
  If (ModuleId < 1) Or (ModuleId > ModuleCount) Then Exit;
  If Modules[ModuleId].ImportList = '' Then
    Modules[ModuleId].ImportList := ImportName
  Else
    Modules[ModuleId].ImportList := Modules[ModuleId].ImportList + ';' + ImportName;
End;

{ Empile un namespace courant }
Procedure PushNamespace(NsId: Integer);
Begin
  If NamespaceStackDepth >= MAX_NS_DEPTH Then
  Begin
    WarnMsg('Profondeur maximale de namespaces atteinte');
    Exit;
  End;
  Inc(NamespaceStackDepth);
  NamespaceStack[NamespaceStackDepth] := NsId;
End;

{ Depile le namespace courant }
Function PopNamespace: Integer;
Begin
  If NamespaceStackDepth <= 0 Then
  Begin
    PopNamespace := -1;
    Exit;
  End;
  PopNamespace := NamespaceStack[NamespaceStackDepth];
  NamespaceStack[NamespaceStackDepth] := -1;
  Dec(NamespaceStackDepth);
End;

{ Retourne le namespace courant }
Function GetCurrentNamespace: Integer;
Begin
  If NamespaceStackDepth > 0 Then
    GetCurrentNamespace := NamespaceStack[NamespaceStackDepth]
  Else
    GetCurrentNamespace := -1;
End;

{ Construit le nom complet d'un namespace }
Function BuildFullNamespaceName(Const Name: String; ParentId: Integer): String;
Begin
  If ParentId <= 0 Then
    BuildFullNamespaceName := Name
  Else If (ParentId <= NamespaceCount) And (Namespaces[ParentId].FullName <> '') Then
    BuildFullNamespaceName := Namespaces[ParentId].FullName + '::' + Name
  Else
    BuildFullNamespaceName := Name;
End;

{ Extrait un nom de namespace d'une ligne C++ }
Function ExtractCppNamespaceName(Const Line: String; Var IsAnon, IsInln: Boolean): String;
Var
  Pos1, Pos2: Integer;
  TmpLine: String;
Begin
  ExtractCppNamespaceName := '';
  IsAnon := False;
  IsInln := False;
  TmpLine := TrimStr(Line);
  
  { Detecter inline namespace }
  If Copy(TmpLine, 1, 6) = 'inline' Then
  Begin
    IsInln := True;
    TmpLine := TrimStr(Copy(TmpLine, 7, Length(TmpLine)));
  End;
  
  { Verifier si c'est un namespace }
  If Copy(TmpLine, 1, 9) <> 'namespace' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 10, Length(TmpLine)));
  
  { Namespace anonyme }
  If (TmpLine = '') Or (TmpLine[1] = '{') Then
  Begin
    IsAnon := True;
    ExtractCppNamespaceName := '<anonymous>';
    Exit;
  End;
  
  { Extraire le nom }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (((TmpLine[Pos1] >= 'A') And (TmpLine[Pos1] <= 'Z')) Or
         ((TmpLine[Pos1] >= 'a') And (TmpLine[Pos1] <= 'z')) Or
         ((TmpLine[Pos1] >= '0') And (TmpLine[Pos1] <= '9')) Or
         (TmpLine[Pos1] = '_') Or (TmpLine[Pos1] = ':')) Do
    Inc(Pos1);
  
  ExtractCppNamespaceName := Copy(TmpLine, 1, Pos1 - 1);
End;

{ Extrait un nom de package Java }
Function ExtractJavaPackageName(Const Line: String): String;
Var
  Pos1, Pos2: Integer;
  TmpLine: String;
Begin
  ExtractJavaPackageName := '';
  TmpLine := TrimStr(Line);
  
  If Copy(TmpLine, 1, 7) <> 'package' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 8, Length(TmpLine)));
  
  { Trouver la fin du nom (jusqu'au ; ou espace) }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (TmpLine[Pos1] <> ';') And (TmpLine[Pos1] <> ' ') Do
    Inc(Pos1);
  
  ExtractJavaPackageName := Copy(TmpLine, 1, Pos1 - 1);
End;

{ Extrait un nom de namespace C# }
Function ExtractCSharpNamespaceName(Const Line: String): String;
Var
  Pos1: Integer;
  TmpLine: String;
Begin
  ExtractCSharpNamespaceName := '';
  TmpLine := TrimStr(Line);
  
  If Copy(TmpLine, 1, 9) <> 'namespace' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 10, Length(TmpLine)));
  
  { Trouver la fin du nom }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (TmpLine[Pos1] <> '{') And (TmpLine[Pos1] <> ';') And 
        (TmpLine[Pos1] <> ' ') Do
    Inc(Pos1);
  
  ExtractCSharpNamespaceName := TrimStr(Copy(TmpLine, 1, Pos1 - 1));
End;

{ Extrait un nom de package Ada }
Function ExtractAdaPackageName(Const Line: String): String;
Var
  Pos1, Pos2: Integer;
  TmpLine, UpperLine: String;
Begin
  ExtractAdaPackageName := '';
  TmpLine := TrimStr(Line);
  UpperLine := UpStr(TmpLine);
  
  { package [body] Name is }
  If Copy(UpperLine, 1, 7) <> 'PACKAGE' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 8, Length(TmpLine)));
  UpperLine := UpStr(TmpLine);
  
  { Ignorer 'body' si present }
  If Copy(UpperLine, 1, 4) = 'BODY' Then
    TmpLine := TrimStr(Copy(TmpLine, 5, Length(TmpLine)));
  
  { Extraire le nom }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (TmpLine[Pos1] <> ' ') And (TmpLine[Pos1] <> ';') Do
    Inc(Pos1);
  
  ExtractAdaPackageName := Copy(TmpLine, 1, Pos1 - 1);
End;

{ Extrait un nom de module C++20 }
Function ExtractCpp20ModuleName(Const Line: String; Var IsExport: Boolean): String;
Var
  Pos1: Integer;
  TmpLine: String;
Begin
  ExtractCpp20ModuleName := '';
  IsExport := False;
  TmpLine := TrimStr(Line);
  
  { Verifier export module }
  If Copy(TmpLine, 1, 6) = 'export' Then
  Begin
    IsExport := True;
    TmpLine := TrimStr(Copy(TmpLine, 7, Length(TmpLine)));
  End;
  
  If Copy(TmpLine, 1, 6) <> 'module' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 7, Length(TmpLine)));
  
  { Extraire le nom jusqu'au ; }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (TmpLine[Pos1] <> ';') And (TmpLine[Pos1] <> ' ') Do
    Inc(Pos1);
  
  ExtractCpp20ModuleName := Copy(TmpLine, 1, Pos1 - 1);
End;

{ Extrait un import C++20 }
Function ExtractCpp20Import(Const Line: String): String;
Var
  Pos1: Integer;
  TmpLine: String;
Begin
  ExtractCpp20Import := '';
  TmpLine := TrimStr(Line);
  
  If Copy(TmpLine, 1, 6) <> 'import' Then Exit;
  TmpLine := TrimStr(Copy(TmpLine, 7, Length(TmpLine)));
  
  { Extraire le nom }
  Pos1 := 1;
  While (Pos1 <= Length(TmpLine)) And
        (TmpLine[Pos1] <> ';') And (TmpLine[Pos1] <> ' ') Do
    Inc(Pos1);
  
  ExtractCpp20Import := Copy(TmpLine, 1, Pos1 - 1);
End;

{ Extrait les namespaces d'un fichier }
Procedure ExtractNamespaces(Const FileName: String; Lang: TSourceLanguage);
Var
  F: Text;
  Line, NsName, PkgName, ModName: String;
  LineNo, ParentId, NsId, ModId: Integer;
  IsAnon, IsInln, IsExport: Boolean;
  UpperLang: String;
Begin
  If Not NamespacesInitialized Then InitNamespaces;
  
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Exit;
  
  LineNo := 0;
  UpperLang := UpStr(LanguageToStr(Lang));
  
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Inc(LineNo);
    Line := TrimStr(Line);
    If Line = '' Then Continue;
    
    { C++ namespace }
    If (Lang = LANG_CPP) Or (Lang = LANG_C) Then
    Begin
      If (Pos('namespace', Line) > 0) Then
      Begin
        NsName := ExtractCppNamespaceName(Line, IsAnon, IsInln);
        If NsName <> '' Then
        Begin
          ParentId := GetCurrentNamespace;
          NsId := AddNamespace(NsName, 
                               BuildFullNamespaceName(NsName, ParentId),
                               FileName, 'C++', LineNo, ParentId,
                               IsAnon, IsInln);
          If (NsId > 0) And (Pos('{', Line) > 0) Then
            PushNamespace(NsId);
        End;
      End
      Else If (Pos('module', Line) > 0) And (Pos(';', Line) > 0) Then
      Begin
        ModName := ExtractCpp20ModuleName(Line, IsExport);
        If ModName <> '' Then
        Begin
          ModId := FindModule(ModName);
          If ModId < 0 Then
            ModId := AddModule(ModName, FileName, LineNo, False, IsExport);
        End;
      End
      Else If (Pos('import', Line) > 0) And (Pos(';', Line) > 0) Then
      Begin
        ModName := ExtractCpp20Import(Line);
        If ModName <> '' Then
        Begin
          { Ajouter l'import au module courant si existant }
          If ModuleCount > 0 Then
            AddModuleImport(ModuleCount, ModName);
        End;
      End;
      
      { Detecter la fin d'un namespace }
      If (Pos('}', Line) > 0) And (NamespaceStackDepth > 0) Then
      Begin
        NsId := PopNamespace;
        If (NsId > 0) And (NsId <= NamespaceCount) Then
          Namespaces[NsId].EndLine := LineNo;
      End;
    End
    
    { Java package }
    Else If Lang = LANG_JAVA Then
    Begin
      If Pos('package', Line) = 1 Then
      Begin
        PkgName := ExtractJavaPackageName(Line);
        If PkgName <> '' Then
          AddNamespace(PkgName, PkgName, FileName, 'Java', LineNo, -1,
                       False, False);
      End;
    End
    
    { C# namespace }
    Else If Lang = LANG_CSHARP Then
    Begin
      If Pos('namespace', Line) > 0 Then
      Begin
        NsName := ExtractCSharpNamespaceName(Line);
        If NsName <> '' Then
        Begin
          ParentId := GetCurrentNamespace;
          NsId := AddNamespace(NsName,
                               BuildFullNamespaceName(NsName, ParentId),
                               FileName, 'C#', LineNo, ParentId,
                               False, False);
          If (NsId > 0) And (Pos('{', Line) > 0) Then
            PushNamespace(NsId);
        End;
      End
      Else If (Pos('}', Line) > 0) And (NamespaceStackDepth > 0) Then
      Begin
        NsId := PopNamespace;
        If (NsId > 0) And (NsId <= NamespaceCount) Then
          Namespaces[NsId].EndLine := LineNo;
      End;
    End
    
    { Ada package }
    Else If Lang = LANG_ADA Then
    Begin
      If (UpStr(Copy(Line, 1, 7)) = 'PACKAGE') Then
      Begin
        PkgName := ExtractAdaPackageName(Line);
        If PkgName <> '' Then
          AddNamespace(PkgName, PkgName, FileName, 'Ada', LineNo, -1,
                       False, False);
      End;
    End;
  End;
  
  Close(F);
End;

{ Construit la hierarchie des namespaces }
Procedure BuildNamespaceHierarchy;
Var
  I, J: Integer;
  ParentName: String;
  DotPos: Integer;
Begin
  For I := 1 To NamespaceCount Do
  Begin
    If Namespaces[I].ParentId < 0 Then
    Begin
      { Chercher le parent par le nom complet }
      ParentName := Namespaces[I].FullName;
      
      { Trouver le dernier separateur }
      DotPos := 0;
      For J := Length(ParentName) DownTo 1 Do
      Begin
        If (ParentName[J] = ':') Or (ParentName[J] = '.') Then
        Begin
          DotPos := J;
          Break;
        End;
      End;
      
      If DotPos > 1 Then
      Begin
        { Enlever :: ou . du debut }
        If (DotPos > 1) And (ParentName[DotPos-1] = ':') Then
          Dec(DotPos);
        ParentName := Copy(ParentName, 1, DotPos - 1);
        
        { Chercher le parent }
        For J := 1 To NamespaceCount Do
        Begin
          If (J <> I) And (Namespaces[J].FullName = ParentName) Then
          Begin
            Namespaces[I].ParentId := J;
            Break;
          End;
        End;
      End;
    End;
  End;
End;

{ Retourne les entites declarees dans un namespace }
Function GetNamespaceEntities(NamespaceId: Integer): String;
Var
  I: Integer;
  Result: String;
  NsFullName: String;
Begin
  GetNamespaceEntities := '';
  If (NamespaceId < 1) Or (NamespaceId > NamespaceCount) Then Exit;
  
  Result := '';
  NsFullName := Namespaces[NamespaceId].FullName;
  
  { Parcourir les entites pour trouver celles du namespace }
  For I := 1 To EntityCount Do
  Begin
    { Verifier si l'entite est dans le meme fichier et dans les lignes du namespace }
    If (Entities[I].FileName = Namespaces[NamespaceId].FileName) And
       (Entities[I].Line >= Namespaces[NamespaceId].Line) And
       ((Namespaces[NamespaceId].EndLine = 0) Or
        (Entities[I].Line <= Namespaces[NamespaceId].EndLine)) Then
    Begin
      If Result <> '' Then
        Result := Result + ';';
      Result := Result + Entities[I].Name;
    End;
  End;
  
  GetNamespaceEntities := Result;
End;

{ Retourne le nombre de namespaces }
Function GetNamespaceCount: Integer;
Begin
  GetNamespaceCount := NamespaceCount;
End;

{ Retourne le nombre de modules }
Function GetModuleCount: Integer;
Begin
  GetModuleCount := ModuleCount;
End;

{ Verifie si le systeme de namespaces est initialise }
Function IsNamespacesInitialized: Boolean;
Begin
  IsNamespacesInitialized := NamespacesInitialized;
End;

{ Verifie si la liste de namespaces est vide }
Function IsNamespacesEmpty: Boolean;
Begin
  IsNamespacesEmpty := (NamespaceCount = 0);
End;

{ Verifie si la liste de modules est vide }
Function IsModulesEmpty: Boolean;
Begin
  IsModulesEmpty := (ModuleCount = 0);
End;

{ Retourne un namespace par index }
Function GetNamespaceByIndex(Index: Integer): TNamespace;
Var
  Empty: TNamespace;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceByIndex := Namespaces[Index]
  Else
  Begin
    Empty.Name := '';
    Empty.FullName := '';
    Empty.ParentId := -1;
    Empty.FileName := '';
    Empty.Line := 0;
    Empty.EndLine := 0;
    Empty.IsAnonymous := False;
    Empty.IsInline := False;
    Empty.Language := '';
    GetNamespaceByIndex := Empty;
  End;
End;

{ Retourne un module par index }
Function GetModuleByIndex(Index: Integer): TModule;
Var
  Empty: TModule;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    GetModuleByIndex := Modules[Index]
  Else
  Begin
    Empty.Name := '';
    Empty.FileName := '';
    Empty.ExportList := '';
    Empty.ImportList := '';
    Empty.IsPartition := False;
    Empty.IsInterface := False;
    Empty.Line := 0;
    GetModuleByIndex := Empty;
  End;
End;

{ Verifie si un index de namespace est valide }
Function IsValidNamespaceIndex(Index: Integer): Boolean;
Begin
  IsValidNamespaceIndex := (Index >= 1) And (Index <= NamespaceCount);
End;

{ Verifie si un index de module est valide }
Function IsValidModuleIndex(Index: Integer): Boolean;
Begin
  IsValidModuleIndex := (Index >= 1) And (Index <= ModuleCount);
End;

{ Retourne le nom d'un namespace }
Function GetNamespaceName(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceName := Namespaces[Index].Name
  Else
    GetNamespaceName := '';
End;

{ Retourne le nom complet d'un namespace }
Function GetNamespaceFullName(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceFullName := Namespaces[Index].FullName
  Else
    GetNamespaceFullName := '';
End;

{ Retourne le fichier d'un namespace }
Function GetNamespaceFileName(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceFileName := Namespaces[Index].FileName
  Else
    GetNamespaceFileName := '';
End;

{ Retourne la ligne d'un namespace }
Function GetNamespaceLine(Index: Integer): Integer;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceLine := Namespaces[Index].Line
  Else
    GetNamespaceLine := 0;
End;

{ Retourne le parent d'un namespace }
Function GetNamespaceParent(Index: Integer): Integer;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    GetNamespaceParent := Namespaces[Index].ParentId
  Else
    GetNamespaceParent := -1;
End;

{ Verifie si un namespace est anonyme }
Function IsNamespaceAnonymous(Index: Integer): Boolean;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    IsNamespaceAnonymous := Namespaces[Index].IsAnonymous
  Else
    IsNamespaceAnonymous := False;
End;

{ Verifie si un namespace est inline }
Function IsNamespaceInline(Index: Integer): Boolean;
Begin
  If (Index >= 1) And (Index <= NamespaceCount) Then
    IsNamespaceInline := Namespaces[Index].IsInline
  Else
    IsNamespaceInline := False;
End;

{ Retourne le nom d'un module }
Function GetModuleName(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    GetModuleName := Modules[Index].Name
  Else
    GetModuleName := '';
End;

{ Retourne le fichier d'un module }
Function GetModuleFileName(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    GetModuleFileName := Modules[Index].FileName
  Else
    GetModuleFileName := '';
End;

{ Retourne les exports d'un module }
Function GetModuleExports(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    GetModuleExports := Modules[Index].ExportList
  Else
    GetModuleExports := '';
End;

{ Retourne les imports d'un module }
Function GetModuleImports(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    GetModuleImports := Modules[Index].ImportList
  Else
    GetModuleImports := '';
End;

{ Verifie si un module est une partition }
Function IsModulePartition(Index: Integer): Boolean;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    IsModulePartition := Modules[Index].IsPartition
  Else
    IsModulePartition := False;
End;

{ Verifie si un module est une interface }
Function IsModuleInterface(Index: Integer): Boolean;
Begin
  If (Index >= 1) And (Index <= ModuleCount) Then
    IsModuleInterface := Modules[Index].IsInterface
  Else
    IsModuleInterface := False;
End;

{ Compte les namespaces enfants d'un namespace }
Function CountChildNamespaces(ParentId: Integer): Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To NamespaceCount Do
    If Namespaces[I].ParentId = ParentId Then
      Inc(Count);
  CountChildNamespaces := Count;
End;

{ Compte les namespaces racines (sans parent) }
Function CountRootNamespaces: Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To NamespaceCount Do
    If Namespaces[I].ParentId <= 0 Then
      Inc(Count);
  CountRootNamespaces := Count;
End;

{ Compte les namespaces par langage }
Function CountNamespacesByLanguage(Const Lang: String): Integer;
Var
  I, Count: Integer;
  UpperLang: String;
Begin
  Count := 0;
  UpperLang := UpStr(Lang);
  For I := 1 To NamespaceCount Do
    If UpStr(Namespaces[I].Language) = UpperLang Then
      Inc(Count);
  CountNamespacesByLanguage := Count;
End;

{ Affiche les namespaces pour debogage }
Procedure ShowNamespaces;
Var
  I: Integer;
Begin
  WriteLn('=== Namespaces (', NamespaceCount, ') ===');
  For I := 1 To NamespaceCount Do
  Begin
    Write('  [', I, '] ');
    If Namespaces[I].IsAnonymous Then
      Write('<anonymous>')
    Else
      Write(Namespaces[I].FullName);
    Write(' (', Namespaces[I].Language, ')');
    If Namespaces[I].IsInline Then
      Write(' [inline]');
    WriteLn(' @ ', Namespaces[I].FileName, ':', Namespaces[I].Line);
    If Namespaces[I].ParentId > 0 Then
      WriteLn('      Parent: ', Namespaces[Namespaces[I].ParentId].FullName);
  End;
End;

{ Affiche les modules pour debogage }
Procedure ShowModules;
Var
  I: Integer;
Begin
  WriteLn('=== Modules (', ModuleCount, ') ===');
  For I := 1 To ModuleCount Do
  Begin
    Write('  [', I, '] ', Modules[I].Name);
    If Modules[I].IsInterface Then
      Write(' [interface]');
    If Modules[I].IsPartition Then
      Write(' [partition]');
    WriteLn(' @ ', Modules[I].FileName, ':', Modules[I].Line);
    If Modules[I].ExportList <> '' Then
      WriteLn('      Exports: ', Modules[I].ExportList);
    If Modules[I].ImportList <> '' Then
      WriteLn('      Imports: ', Modules[I].ImportList);
  End;
End;

{ ============================================================
  RECHERCHE ET INDEXATION FULL-TEXT (TODO 22)
  ============================================================ }

{ Initialise le systeme d'index de recherche }
Procedure InitSearchIndex;
Var
  I: Integer;
Begin
  SearchCount := 0;
  
  For I := 1 To MAX_SEARCH_ENTRIES Do
  Begin
    SearchIndex[I].Word := '';
    SearchIndex[I].EntityId := -1;
    SearchIndex[I].FileName := '';
    SearchIndex[I].Anchor := '';
    SearchIndex[I].Score := 0;
  End;
  
  SearchInitialized := True;
End;

{ Verifie si un mot est un stop word (mot commun a ignorer) }
Function IsStopWord(Const W: String): Boolean;
Var
  U: String;
Begin
  U := UpStr(W);
  IsStopWord := (U = 'THE') Or (U = 'A') Or (U = 'AN') Or
                (U = 'AND') Or (U = 'OR') Or (U = 'NOT') Or
                (U = 'IN') Or (U = 'ON') Or (U = 'AT') Or
                (U = 'TO') Or (U = 'FOR') Or (U = 'OF') Or
                (U = 'IS') Or (U = 'IT') Or (U = 'AS') Or
                (U = 'BY') Or (U = 'WITH') Or (U = 'FROM') Or
                (U = 'THIS') Or (U = 'THAT') Or (U = 'WHICH') Or
                (U = 'BE') Or (U = 'ARE') Or (U = 'WAS') Or
                (U = 'WERE') Or (U = 'BEEN') Or (U = 'BEING') Or
                (U = 'HAVE') Or (U = 'HAS') Or (U = 'HAD') Or
                (U = 'DO') Or (U = 'DOES') Or (U = 'DID') Or
                (U = 'WILL') Or (U = 'WOULD') Or (U = 'COULD') Or
                (U = 'SHOULD') Or (U = 'MAY') Or (U = 'MIGHT') Or
                (U = 'MUST') Or (U = 'SHALL') Or (U = 'CAN') Or
                (U = 'LE') Or (U = 'LA') Or (U = 'LES') Or
                (U = 'UN') Or (U = 'UNE') Or (U = 'DES') Or
                (U = 'DE') Or (U = 'DU') Or (U = 'ET') Or
                (U = 'OU') Or (U = 'POUR') Or (U = 'DANS') Or
                (U = 'SUR') Or (U = 'AVEC') Or (U = 'EST') Or
                (U = 'SONT') Or (U = 'QUI') Or (U = 'QUE') Or
                (U = 'VOID') Or (U = 'INT') Or (U = 'CHAR') Or
                (U = 'RETURN') Or (U = 'IF') Or (U = 'ELSE') Or
                (U = 'WHILE') Or (U = 'FOR') Or (U = 'VAR') Or
                (U = 'CONST') Or (U = 'TYPE') Or (U = 'BEGIN') Or
                (U = 'END') Or (U = 'PROCEDURE') Or (U = 'FUNCTION');
End;

{ Verifie si un caractere est alphanumerique }
Function IsAlphaNum(C: Char): Boolean;
Begin
  IsAlphaNum := ((C >= 'a') And (C <= 'z')) Or
                ((C >= 'A') And (C <= 'Z')) Or
                ((C >= '0') And (C <= '9')) Or
                (C = '_');
End;

{ Extrait les mots significatifs d'un texte }
Function ExtractWords(Const Text: String; Var Words: Array Of String;
  MaxWords: Integer): Integer;
Var
  I, J, Start, Count: Integer;
  InWord: Boolean;
  Word: String;
Begin
  Count := 0;
  InWord := False;
  Start := 1;
  
  For I := 1 To Length(Text) Do
  Begin
    If IsAlphaNum(Text[I]) Then
    Begin
      If Not InWord Then
      Begin
        InWord := True;
        Start := I;
      End;
    End
    Else
    Begin
      If InWord Then
      Begin
        InWord := False;
        Word := '';
        For J := Start To I - 1 Do
          Word := Word + Text[J];
        
        If (Length(Word) >= SEARCH_MIN_WORD_LEN) And
           (Length(Word) <= SEARCH_MAX_WORD_LEN) And
           (Not IsStopWord(Word)) Then
        Begin
          If Count < MaxWords Then
          Begin
            Inc(Count);
            Words[Count] := UpStr(Word);
          End;
        End;
      End;
    End;
  End;
  
  { Dernier mot si le texte ne finit pas par un separateur }
  If InWord Then
  Begin
    Word := '';
    For J := Start To Length(Text) Do
      Word := Word + Text[J];
    
    If (Length(Word) >= SEARCH_MIN_WORD_LEN) And
       (Length(Word) <= SEARCH_MAX_WORD_LEN) And
       (Not IsStopWord(Word)) Then
    Begin
      If Count < MaxWords Then
      Begin
        Inc(Count);
        Words[Count] := UpStr(Word);
      End;
    End;
  End;
  
  ExtractWords := Count;
End;

{ Ajoute une entree dans l'index de recherche }
Procedure AddSearchEntry(Const Word: String; EntityId: Integer;
  Const FileName, Anchor: String; Score: Integer);
Var
  I: Integer;
  Found: Boolean;
Begin
  If SearchCount >= MAX_SEARCH_ENTRIES Then Exit;
  If Word = '' Then Exit;
  
  { Verifier si l'entree existe deja }
  Found := False;
  For I := 1 To SearchCount Do
  Begin
    If (SearchIndex[I].Word = Word) And
       (SearchIndex[I].EntityId = EntityId) Then
    Begin
      { Mettre a jour le score si meilleur }
      If Score > SearchIndex[I].Score Then
        SearchIndex[I].Score := Score;
      Found := True;
      Break;
    End;
  End;
  
  If Not Found Then
  Begin
    Inc(SearchCount);
    SearchIndex[SearchCount].Word := Word;
    SearchIndex[SearchCount].EntityId := EntityId;
    SearchIndex[SearchCount].FileName := FileName;
    SearchIndex[SearchCount].Anchor := Anchor;
    SearchIndex[SearchCount].Score := Score;
  End;
End;

{ Construit l'index de recherche a partir des entites }
Procedure BuildSearchIndex;
Var
  I, J, WordCount: Integer;
  Words: Array[1..100] Of String;
  FileName, Anchor: String;
Begin
  If Not SearchInitialized Then
    InitSearchIndex;
  
  SearchCount := 0;
  
  For I := 1 To EntityCount Do
  Begin
    { Generer le nom de fichier et l'ancre }
    Case Entities[I].Kind Of
      ENT_FILE:
        FileName := LowerStr(Entities[I].Name) + '_8' +
                    Copy(Entities[I].Name, Pos('.', Entities[I].Name) + 1, 10) +
                    '.html';
      ENT_CLASS, ENT_STRUCT:
        FileName := 'class' + LowerStr(Entities[I].Name) + '.html';
      ENT_FUNCTION:
        FileName := Entities[I].FileName + '.html';
      Else
        FileName := 'index.html';
    End;
    Anchor := 'a' + IntToStr(I);
    
    { Indexer le nom de l'entite }
    WordCount := ExtractWords(Entities[I].Name, Words, 100);
    For J := 1 To WordCount Do
      AddSearchEntry(Words[J], I, FileName, Anchor, SEARCH_SCORE_NAME);
    
    { Indexer la description breve }
    If Entities[I].BriefDesc <> '' Then
    Begin
      WordCount := ExtractWords(Entities[I].BriefDesc, Words, 100);
      For J := 1 To WordCount Do
        AddSearchEntry(Words[J], I, FileName, Anchor, SEARCH_SCORE_BRIEF);
    End;
    
    { Indexer la description detaillee }
    If Entities[I].DetailedDesc <> '' Then
    Begin
      WordCount := ExtractWords(Entities[I].DetailedDesc, Words, 100);
      For J := 1 To WordCount Do
        AddSearchEntry(Words[J], I, FileName, Anchor, SEARCH_SCORE_DETAIL);
    End;
  End;
End;

{ Recherche dans l'index et retourne les resultats tries par pertinence }
Function SearchEntities(Const Query: String): String;
Var
  I, J, K, WordCount, ResultCount: Integer;
  Words: Array[1..20] Of String;
  ResultIds: Array[1..SEARCH_MAX_RESULTS] Of Integer;
  ResultScores: Array[1..SEARCH_MAX_RESULTS] Of Integer;
  TempId, TempScore: Integer;
  Result: String;
Begin
  Result := '';
  ResultCount := 0;
  
  { Extraire les mots de la requete }
  WordCount := ExtractWords(Query, Words, 20);
  If WordCount = 0 Then
  Begin
    SearchEntities := '';
    Exit;
  End;
  
  { Rechercher chaque mot dans l'index }
  For I := 1 To SearchCount Do
  Begin
    For J := 1 To WordCount Do
    Begin
      If Pos(Words[J], SearchIndex[I].Word) > 0 Then
      Begin
        { Verifier si l'entite est deja dans les resultats }
        K := 1;
        While (K <= ResultCount) And
              (ResultIds[K] <> SearchIndex[I].EntityId) Do
          Inc(K);
        
        If K > ResultCount Then
        Begin
          { Nouvelle entite }
          If ResultCount < SEARCH_MAX_RESULTS Then
          Begin
            Inc(ResultCount);
            ResultIds[ResultCount] := SearchIndex[I].EntityId;
            ResultScores[ResultCount] := SearchIndex[I].Score;
          End;
        End
        Else
        Begin
          { Ajouter au score existant }
          ResultScores[K] := ResultScores[K] + SearchIndex[I].Score;
        End;
      End;
    End;
  End;
  
  { Trier les resultats par score decroissant (tri a bulles) }
  For I := 1 To ResultCount - 1 Do
    For J := I + 1 To ResultCount Do
      If ResultScores[J] > ResultScores[I] Then
      Begin
        TempId := ResultIds[I];
        TempScore := ResultScores[I];
        ResultIds[I] := ResultIds[J];
        ResultScores[I] := ResultScores[J];
        ResultIds[J] := TempId;
        ResultScores[J] := TempScore;
      End;
  
  { Construire la chaine de resultats }
  For I := 1 To ResultCount Do
  Begin
    If Result <> '' Then Result := Result + ';';
    Result := Result + IntToStr(ResultIds[I]) + ':' +
              IntToStr(ResultScores[I]);
  End;
  
  SearchEntities := Result;
End;

{ Genere les fichiers de donnees de recherche }
Procedure GenerateSearchData(Const OutputDir: String);
Var
  F: Text;
  FileName: String;
  I: Integer;
Begin
  If Not SearchInitialized Then
    InitSearchIndex;
  
  If SearchCount = 0 Then
    BuildSearchIndex;
  
  { Generer le fichier searchdata.js }
  FileName := OutputDir + '/' + SEARCH_DATA_FILE;
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer ' + FileName);
    Exit;
  End;
  
  WriteLn(F, '// Donnees d''index de recherche generees par DOXYGEN');
  WriteLn(F, '// Date: ', DOXYGEN_DATE);
  WriteLn(F, 'var searchData = [');
  
  For I := 1 To SearchCount Do
  Begin
    Write(F, '  ["', SearchIndex[I].Word, '",');
    Write(F, SearchIndex[I].EntityId, ',');
    Write(F, '"', SearchIndex[I].FileName, '",');
    Write(F, '"', SearchIndex[I].Anchor, '",');
    Write(F, SearchIndex[I].Score, ']');
    If I < SearchCount Then
      WriteLn(F, ',')
    Else
      WriteLn(F);
  End;
  
  WriteLn(F, '];');
  Close(F);
End;

{ Genere la page HTML de recherche }
Procedure GenerateSearchHtml(Const OutputDir: String);
Var
  F: Text;
  FileName: String;
Begin
  FileName := OutputDir + '/' + SEARCH_HTML_FILE;
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer ' + FileName);
    Exit;
  End;
  
  WriteLn(F, HTML_DOCTYPE);
  WriteLn(F, '<html lang="fr">');
  WriteLn(F, '<head>');
  WriteLn(F, '  <meta charset="', HTML_CHARSET, '">');
  WriteLn(F, '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
  WriteLn(F, '  <title>Recherche - Documentation</title>');
  WriteLn(F, '  <link rel="stylesheet" href="', HTML_CSS_FILE, '">');
  WriteLn(F, '  <script src="', SEARCH_DATA_FILE, '"></script>');
  WriteLn(F, '  <script src="', SEARCH_INDEX_FILE, '"></script>');
  WriteLn(F, '</head>');
  WriteLn(F, '<body>');
  WriteLn(F, '  <div class="header">');
  WriteLn(F, '    <h1>Recherche dans la documentation</h1>');
  WriteLn(F, '  </div>');
  WriteLn(F, '  <div class="content">');
  WriteLn(F, '    <div class="search-box">');
  WriteLn(F, '      <input type="text" id="search-input" placeholder="Entrez votre recherche..." autofocus>');
  WriteLn(F, '      <button onclick="performSearch()">Rechercher</button>');
  WriteLn(F, '    </div>');
  WriteLn(F, '    <div id="search-results"></div>');
  WriteLn(F, '  </div>');
  WriteLn(F, '  <div class="footer">');
  WriteLn(F, '    <p>Genere par DOXYGEN ', DOXYGEN_VERSION, '</p>');
  WriteLn(F, '  </div>');
  WriteLn(F, '</body>');
  WriteLn(F, '</html>');
  
  Close(F);
End;

{ Ecrit le fichier JavaScript de recherche }
Procedure WriteSearchIndexJs(Const OutputDir: String);
Var
  F: Text;
  FileName: String;
Begin
  FileName := OutputDir + '/' + SEARCH_INDEX_FILE;
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer ' + FileName);
    Exit;
  End;
  
  WriteLn(F, '// Script de recherche genere par DOXYGEN');
  WriteLn(F, '// Version: ', DOXYGEN_VERSION);
  WriteLn(F, '');
  WriteLn(F, 'function performSearch() {');
  WriteLn(F, '  var query = document.getElementById("search-input").value.toUpperCase();');
  WriteLn(F, '  var results = [];');
  WriteLn(F, '  var seen = {};');
  WriteLn(F, '  ');
  WriteLn(F, '  if (query.length < 2) {');
  WriteLn(F, '    document.getElementById("search-results").innerHTML = ');
  WriteLn(F, '      "<p>Veuillez entrer au moins 2 caracteres.</p>";');
  WriteLn(F, '    return;');
  WriteLn(F, '  }');
  WriteLn(F, '  ');
  WriteLn(F, '  for (var i = 0; i < searchData.length; i++) {');
  WriteLn(F, '    var entry = searchData[i];');
  WriteLn(F, '    if (entry[0].indexOf(query) >= 0) {');
  WriteLn(F, '      var key = entry[1] + "-" + entry[2];');
  WriteLn(F, '      if (!seen[key]) {');
  WriteLn(F, '        seen[key] = true;');
  WriteLn(F, '        results.push({');
  WriteLn(F, '          word: entry[0],');
  WriteLn(F, '          id: entry[1],');
  WriteLn(F, '          file: entry[2],');
  WriteLn(F, '          anchor: entry[3],');
  WriteLn(F, '          score: entry[4]');
  WriteLn(F, '        });');
  WriteLn(F, '      }');
  WriteLn(F, '    }');
  WriteLn(F, '  }');
  WriteLn(F, '  ');
  WriteLn(F, '  results.sort(function(a, b) { return b.score - a.score; });');
  WriteLn(F, '  ');
  WriteLn(F, '  var html = "";');
  WriteLn(F, '  if (results.length === 0) {');
  WriteLn(F, '    html = "<p>Aucun resultat trouve pour: " + query + "</p>";');
  WriteLn(F, '  } else {');
  WriteLn(F, '    html = "<p>" + results.length + " resultat(s) trouve(s):</p>";');
  WriteLn(F, '    html += "<ul class=\"search-results-list\">";');
  WriteLn(F, '    for (var j = 0; j < Math.min(results.length, ', SEARCH_MAX_RESULTS, '); j++) {');
  WriteLn(F, '      var r = results[j];');
  WriteLn(F, '      html += "<li><a href=\"" + r.file + "#" + r.anchor + "\">";');
  WriteLn(F, '      html += r.word + "</a> (score: " + r.score + ")</li>";');
  WriteLn(F, '    }');
  WriteLn(F, '    html += "</ul>";');
  WriteLn(F, '  }');
  WriteLn(F, '  ');
  WriteLn(F, '  document.getElementById("search-results").innerHTML = html;');
  WriteLn(F, '}');
  WriteLn(F, '');
  WriteLn(F, '// Recherche a la pression de Entree');
  WriteLn(F, 'document.addEventListener("DOMContentLoaded", function() {');
  WriteLn(F, '  var input = document.getElementById("search-input");');
  WriteLn(F, '  if (input) {');
  WriteLn(F, '    input.addEventListener("keypress", function(e) {');
  WriteLn(F, '      if (e.key === "Enter") performSearch();');
  WriteLn(F, '    });');
  WriteLn(F, '  }');
  WriteLn(F, '});');
  
  Close(F);
End;

{ Trouve une entree dans l'index de recherche }
Function FindSearchEntry(Const Word: String; EntityId: Integer): Integer;
Var
  I: Integer;
Begin
  FindSearchEntry := -1;
  For I := 1 To SearchCount Do
    If (SearchIndex[I].Word = Word) And
       (SearchIndex[I].EntityId = EntityId) Then
    Begin
      FindSearchEntry := I;
      Exit;
    End;
End;

{ Retourne le nombre d'entrees dans l'index de recherche }
Function GetSearchCount: Integer;
Begin
  GetSearchCount := SearchCount;
End;

{ Retourne une entree de l'index de recherche }
Function GetSearchEntry(Index: Integer): TSearchIndex;
Var
  Empty: TSearchIndex;
Begin
  If (Index >= 1) And (Index <= SearchCount) Then
    GetSearchEntry := SearchIndex[Index]
  Else
  Begin
    Empty.Word := '';
    Empty.EntityId := -1;
    Empty.FileName := '';
    Empty.Anchor := '';
    Empty.Score := 0;
    GetSearchEntry := Empty;
  End;
End;

{ Verifie si l'index de recherche est initialise }
Function IsSearchInitialized: Boolean;
Begin
  IsSearchInitialized := SearchInitialized;
End;

{ Verifie si l'index de recherche est vide }
Function IsSearchEmpty: Boolean;
Begin
  IsSearchEmpty := (SearchCount = 0);
End;

{ Compte le nombre d'entrees pour un mot donne }
Function CountSearchEntriesForWord(Const Word: String): Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To SearchCount Do
    If SearchIndex[I].Word = Word Then
      Inc(Count);
  CountSearchEntriesForWord := Count;
End;

{ Compte le nombre d'entrees pour une entite donnee }
Function CountSearchEntriesForEntity(EntityId: Integer): Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To SearchCount Do
    If SearchIndex[I].EntityId = EntityId Then
      Inc(Count);
  CountSearchEntriesForEntity := Count;
End;

{ Retourne le score moyen de l'index }
Function GetAverageSearchScore: Integer;
Var
  I: Integer;
  Total: LongInt;
Begin
  If SearchCount = 0 Then
  Begin
    GetAverageSearchScore := 0;
    Exit;
  End;
  
  Total := 0;
  For I := 1 To SearchCount Do
    Total := Total + SearchIndex[I].Score;
  
  GetAverageSearchScore := Total Div SearchCount;
End;

{ Retourne le mot le plus indexe }
Function GetMostIndexedWord: String;
Var
  I, MaxCount, CurCount: Integer;
  MaxWord, CurWord: String;
Begin
  If SearchCount = 0 Then
  Begin
    GetMostIndexedWord := '';
    Exit;
  End;
  
  MaxWord := SearchIndex[1].Word;
  MaxCount := 1;
  
  For I := 1 To SearchCount Do
  Begin
    CurWord := SearchIndex[I].Word;
    CurCount := CountSearchEntriesForWord(CurWord);
    If CurCount > MaxCount Then
    Begin
      MaxCount := CurCount;
      MaxWord := CurWord;
    End;
  End;
  
  GetMostIndexedWord := MaxWord;
End;

{ Affiche l'index de recherche (debug) }
Procedure ShowSearchIndex;
Var
  I: Integer;
Begin
  WriteLn('=== INDEX DE RECHERCHE ===');
  WriteLn('Nombre d''entrees: ', SearchCount);
  WriteLn('Initialise: ', SearchInitialized);
  WriteLn;
  
  If SearchCount > 0 Then
  Begin
    WriteLn('Statistiques:');
    WriteLn('  Score moyen: ', GetAverageSearchScore);
    WriteLn('  Mot le plus indexe: ', GetMostIndexedWord);
    WriteLn;
  End;
  
  WriteLn('Entrees (max 50):');
  For I := 1 To Min(SearchCount, 50) Do
  Begin
    WriteLn('  [', I, '] ', SearchIndex[I].Word,
            ' -> Entite #', SearchIndex[I].EntityId,
            ' (score: ', SearchIndex[I].Score, ')');
    WriteLn('       Fichier: ', SearchIndex[I].FileName,
            '#', SearchIndex[I].Anchor);
  End;
  
  If SearchCount > 50 Then
    WriteLn('  ... et ', SearchCount - 50, ' autres entrees');
End;

{ ============================================================
  SUPPORT MULTI-FICHIERS ET RECURSIVITE (TODO 23)
  ============================================================ }

{ Initialise le systeme de gestion multi-fichiers }
Procedure InitMultiFile;
Var
  I: Integer;
Begin
  SourceCount := 0;
  ProcessedCount := 0;
  
  For I := 1 To MAX_FILES Do
  Begin
    SourceFiles[I] := '';
    ProcessedFiles[I] := '';
  End;
  
  MultiFileInitialized := True;
End;

{ Verifie si un caractere correspond a un caractere de pattern }
Function MatchChar(C, P: Char): Boolean;
Begin
  If P = '?' Then
    MatchChar := True
  Else
    MatchChar := (UpCase(C) = UpCase(P));
End;

{ Verifie si un nom de fichier correspond a un pattern glob }
Function MatchesPattern(Const FileName, Pattern: String): Boolean;
Var
  FI, PI: Integer;
  FLen, PLen: Integer;
  C, P: Char;
Begin
  MatchesPattern := False;
  FLen := Length(FileName);
  PLen := Length(Pattern);
  
  If PLen = 0 Then
  Begin
    MatchesPattern := (FLen = 0);
    Exit;
  End;
  
  { Pattern simple *.ext }
  If (Pattern[1] = '*') And (Pos('*', Copy(Pattern, 2, PLen - 1)) = 0) Then
  Begin
    { Verifier si le fichier se termine par le suffix apres * }
    If PLen = 1 Then
    Begin
      MatchesPattern := True;
      Exit;
    End;
    
    { Extraire le suffix apres * }
    If FLen >= (PLen - 1) Then
    Begin
      { Comparer les suffix }
      FI := FLen - (PLen - 2);
      PI := 2;
      While (PI <= PLen) And (FI <= FLen) Do
      Begin
        If Not MatchChar(FileName[FI], Pattern[PI]) Then
          Exit;
        Inc(FI);
        Inc(PI);
      End;
      MatchesPattern := (PI > PLen);
    End;
    Exit;
  End;
  
  { Pattern prefix prefix* }
  If (Pattern[PLen] = '*') And (Pos('*', Copy(Pattern, 1, PLen - 1)) = 0) Then
  Begin
    { Verifier si le fichier commence par le prefix }
    If FLen >= (PLen - 1) Then
    Begin
      For FI := 1 To PLen - 1 Do
      Begin
        If Not MatchChar(FileName[FI], Pattern[FI]) Then
          Exit;
      End;
      MatchesPattern := True;
    End;
    Exit;
  End;
  
  { Pattern exact sans wildcard }
  If Pos('*', Pattern) = 0 Then
  Begin
    If FLen <> PLen Then
      Exit;
    For FI := 1 To FLen Do
    Begin
      If Not MatchChar(FileName[FI], Pattern[FI]) Then
        Exit;
    End;
    MatchesPattern := True;
    Exit;
  End;
  
  { Pattern complexe avec * au milieu - comparaison simplifiee }
  FI := 1;
  PI := 1;
  While (FI <= FLen) And (PI <= PLen) Do
  Begin
    P := Pattern[PI];
    If P = '*' Then
    Begin
      { Avancer dans le fichier jusqu'a trouver le prochain caractere du pattern }
      Inc(PI);
      If PI > PLen Then
      Begin
        MatchesPattern := True;
        Exit;
      End;
      While (FI <= FLen) And Not MatchChar(FileName[FI], Pattern[PI]) Do
        Inc(FI);
    End
    Else
    Begin
      If Not MatchChar(FileName[FI], P) Then
        Exit;
      Inc(FI);
      Inc(PI);
    End;
  End;
  
  { Verifier si on a consomme tout le pattern }
  While (PI <= PLen) And (Pattern[PI] = '*') Do
    Inc(PI);
    
  MatchesPattern := (PI > PLen);
End;

{ Verifie si une extension correspond a un fichier source connu }
Function IsSourceExtension(Const Ext: String): Boolean;
Var
  E: String;
Begin
  E := UpStr(Ext);
  IsSourceExtension := (E = '.PAS') Or (E = '.PP') Or (E = '.P') Or
                       (E = '.C') Or (E = '.H') Or
                       (E = '.CPP') Or (E = '.CXX') Or (E = '.CC') Or
                       (E = '.HPP') Or (E = '.HXX') Or
                       (E = '.ADA') Or (E = '.ADB') Or (E = '.ADS') Or
                       (E = '.F') Or (E = '.F90') Or (E = '.F95') Or (E = '.FOR') Or
                       (E = '.JAVA') Or
                       (E = '.PY') Or
                       (E = '.CS') Or
                       (E = '.PHP');
End;

{ Extrait l'extension d'un nom de fichier }
Function ExtractFileExt(Const FileName: String): String;
Var
  I: Integer;
  Dot: Integer;
Begin
  Dot := 0;
  For I := Length(FileName) DownTo 1 Do
  Begin
    If FileName[I] = '.' Then
    Begin
      Dot := I;
      Break;
    End;
    If (FileName[I] = '/') Or (FileName[I] = '\') Then
      Break;
  End;
  
  If Dot > 0 Then
    ExtractFileExt := Copy(FileName, Dot, Length(FileName) - Dot + 1)
  Else
    ExtractFileExt := '';
End;

{ Calcule le chemin relatif d'un fichier par rapport a un chemin de base }
Function GetRelativePath(Const FullPath, BasePath: String): String;
Var
  FP, BP: String;
  I, CommonLen: Integer;
  Result: String;
Begin
  { Normaliser les chemins }
  FP := FullPath;
  BP := BasePath;
  
  { Si le chemin de base est vide, retourner le chemin complet }
  If BP = '' Then
  Begin
    GetRelativePath := FP;
    Exit;
  End;
  
  { Trouver la partie commune }
  CommonLen := 0;
  For I := 1 To Min(Length(FP), Length(BP)) Do
  Begin
    If UpCase(FP[I]) = UpCase(BP[I]) Then
      CommonLen := I
    Else
      Break;
  End;
  
  { Si pas de partie commune, retourner le chemin complet }
  If CommonLen = 0 Then
  Begin
    GetRelativePath := FP;
    Exit;
  End;
  
  { Retourner la partie apres le chemin de base }
  If CommonLen >= Length(BP) Then
    Result := Copy(FP, CommonLen + 1, Length(FP) - CommonLen)
  Else
    Result := FP;
    
  { Enlever le separateur initial si present }
  If Length(Result) > 0 Then
  Begin
    If (Result[1] = '/') Or (Result[1] = '\') Then
      Result := Copy(Result, 2, Length(Result) - 1);
  End;
  
  GetRelativePath := Result;
End;

{ Verifie si un fichier est dans la liste d'exclusion }
Function IsExcluded(Const FileName: String): Boolean;
Var
  ExcludePatterns: String;
  ExcludeList: String;
  Pattern: String;
  I, Start: Integer;
Begin
  IsExcluded := False;
  
  { Recuperer les patterns d'exclusion de la configuration }
  ExcludePatterns := GetConfigValue('EXCLUDE_PATTERNS');
  If ExcludePatterns = '' Then
    Exit;
    
  { Parser les patterns separes par des espaces }
  ExcludeList := ExcludePatterns + ' ';
  Start := 1;
  
  For I := 1 To Length(ExcludeList) Do
  Begin
    If ExcludeList[I] = ' ' Then
    Begin
      If I > Start Then
      Begin
        Pattern := Copy(ExcludeList, Start, I - Start);
        If MatchesPattern(FileName, Pattern) Then
        Begin
          IsExcluded := True;
          Exit;
        End;
        If MatchesPattern(ExtractFileName(FileName), Pattern) Then
        Begin
          IsExcluded := True;
          Exit;
        End;
      End;
      Start := I + 1;
    End;
  End;
End;

{ Verifie si un fichier a deja ete ajoute a la liste des sources }
Function IsFileInSourceList(Const FileName: String): Boolean;
Var
  I: Integer;
  FN: String;
Begin
  IsFileInSourceList := False;
  FN := UpStr(FileName);
  
  For I := 1 To SourceCount Do
  Begin
    If UpStr(SourceFiles[I]) = FN Then
    Begin
      IsFileInSourceList := True;
      Exit;
    End;
  End;
End;

{ Ajoute un fichier a la liste des sources }
Function AddSourceFile(Const FileName: String): Boolean;
Begin
  AddSourceFile := False;
  
  { Verifier la capacite }
  If SourceCount >= MAX_FILES Then
  Begin
    WarnMsg('Nombre maximum de fichiers atteint: ' + IntToStr(MAX_FILES));
    Exit;
  End;
  
  { Verifier si le fichier existe }
  If Not FileExists(FileName) Then
  Begin
    WarnMsg('Fichier non trouve: ' + FileName);
    Exit;
  End;
  
  { Verifier si le fichier est deja dans la liste }
  If IsFileInSourceList(FileName) Then
    Exit;
    
  { Verifier si le fichier est exclu }
  If IsExcluded(FileName) Then
    Exit;
    
  { Ajouter le fichier }
  Inc(SourceCount);
  SourceFiles[SourceCount] := FileName;
  AddSourceFile := True;
End;

{ Ajoute un fichier a la liste des fichiers traites }
Function AddProcessedFile(Const FileName: String): Boolean;
Begin
  AddProcessedFile := False;
  
  If ProcessedCount >= MAX_FILES Then
    Exit;
    
  Inc(ProcessedCount);
  ProcessedFiles[ProcessedCount] := FileName;
  AddProcessedFile := True;
End;

{ Verifie si un fichier a deja ete traite }
Function IsFileProcessed(Const FileName: String): Boolean;
Var
  I: Integer;
  FN: String;
Begin
  IsFileProcessed := False;
  FN := UpStr(FileName);
  
  For I := 1 To ProcessedCount Do
  Begin
    If UpStr(ProcessedFiles[I]) = FN Then
    Begin
      IsFileProcessed := True;
      Exit;
    End;
  End;
End;

{ Collecte les fichiers sources correspondant aux patterns }
Procedure CollectSourceFiles(Const Path: String; Recursive: Boolean);
Var
  SR: SearchRec;
  FilePatterns: String;
  Pattern: String;
  FullPath: String;
  I, Start: Integer;
  Ext: String;
  PatternsCopy: String;
Begin
  { Recuperer les patterns de fichiers }
  FilePatterns := GetConfigValue('FILE_PATTERNS');
  If FilePatterns = '' Then
    FilePatterns := '*.c *.cc *.cxx *.cpp *.h *.hh *.hxx *.hpp *.pas *.pp *.java *.py *.cs *.ada *.adb *.ads *.f *.f90';
  
  { Chercher tous les fichiers dans le repertoire }
  FindFirst(Path + '*.*', AnyFile, SR);
  While DosError = 0 Do
  Begin
    If (SR.Name <> '.') And (SR.Name <> '..') Then
    Begin
      { Verifier que c'est un fichier (pas un repertoire) }
      If (SR.Attr And Directory) = 0 Then
      Begin
        FullPath := Path + SR.Name;
        
        { Verifier si c'est un fichier source }
        Ext := ExtractFileExt(SR.Name);
        If IsSourceExtension(Ext) Then
        Begin
          { Verifier contre les patterns }
          PatternsCopy := FilePatterns + ' ';
          Start := 1;
          For I := 1 To Length(PatternsCopy) Do
          Begin
            If PatternsCopy[I] = ' ' Then
            Begin
              If I > Start Then
              Begin
                Pattern := Copy(PatternsCopy, Start, I - Start);
                If MatchesPattern(SR.Name, Pattern) Then
                Begin
                  AddSourceFile(FullPath);
                  Break;
                End;
              End;
              Start := I + 1;
            End;
          End;
        End;
      End;
    End;
    FindNext(SR);
  End;
  
  { Recherche recursive dans les sous-repertoires }
  If Recursive Then
  Begin
    FindFirst(Path + '*.*', Directory, SR);
    While DosError = 0 Do
    Begin
      If (SR.Attr And Directory) <> 0 Then
      Begin
        If (SR.Name <> '.') And (SR.Name <> '..') Then
        Begin
          FullPath := Path + SR.Name + '/';
          
          { Verifier si le repertoire est exclu }
          If Not IsExcluded(SR.Name) Then
            CollectSourceFiles(FullPath, True);
        End;
      End;
      FindNext(SR);
    End;
  End;
End;

{ Traite un repertoire et ses sous-repertoires }
Procedure ProcessDirectory(Const DirPath: String);
Var
  Recursive: Boolean;
  RecurseOpt: String;
Begin
  { Verifier si la recherche recursive est activee }
  RecurseOpt := GetConfigValue('RECURSIVE');
  Recursive := (UpStr(RecurseOpt) = 'YES') Or (UpStr(RecurseOpt) = 'TRUE') Or (RecurseOpt = '1');
  
  { Collecter les fichiers sources }
  CollectSourceFiles(DirPath, Recursive);
End;

{ Traite tous les fichiers sources collectes }
Procedure ProcessAllFiles;
Var
  I: Integer;
Begin
  InfoMsg('Traitement de ' + IntToStr(SourceCount) + ' fichier(s) source(s)...');
  
  For I := 1 To SourceCount Do
  Begin
    If Not IsFileProcessed(SourceFiles[I]) Then
    Begin
      InfoMsg('  Traitement: ' + SourceFiles[I]);
      
      { Traiter le fichier }
      ProcessInputFile(SourceFiles[I]);
      
      { Marquer comme traite }
      AddProcessedFile(SourceFiles[I]);
    End;
  End;
  
  InfoMsg('Traitement termine: ' + IntToStr(ProcessedCount) + ' fichier(s) traite(s)');
End;

{ Verifie si un repertoire existe }
Function DirectoryExists(Const DirPath: String): Boolean;
Var
  SR: SearchRec;
  Path: String;
Begin
  DirectoryExists := False;
  
  Path := DirPath;
  { Enlever le separateur final si present }
  If Length(Path) > 0 Then
  Begin
    If (Path[Length(Path)] = '/') Or (Path[Length(Path)] = '\') Then
      Path := Copy(Path, 1, Length(Path) - 1);
  End;
  
  FindFirst(Path, Directory, SR);
  If DosError = 0 Then
  Begin
    DirectoryExists := (SR.Attr And Directory) <> 0;
  End;
End;

{ Collecte et traite les fichiers depuis la configuration INPUT }
Procedure ProcessInputFromConfig;
Var
  InputValue: String;
  InputList: String;
  Item: String;
  I, Start: Integer;
Begin
  InputValue := GetConfigValue('INPUT');
  If InputValue = '' Then
  Begin
    WarnMsg('Aucun fichier ou repertoire d''entree specifie (INPUT)');
    Exit;
  End;
  
  { Initialiser le systeme multi-fichiers }
  InitMultiFile;
  
  { Parser les entrees separees par des espaces }
  InputList := InputValue + ' ';
  Start := 1;
  
  For I := 1 To Length(InputList) Do
  Begin
    If InputList[I] = ' ' Then
    Begin
      If I > Start Then
      Begin
        Item := Copy(InputList, Start, I - Start);
        
        { Verifier si c'est un fichier ou un repertoire }
        If FileExists(Item) Then
          AddSourceFile(Item)
        Else If DirectoryExists(Item) Then
        Begin
          { Ajouter un separateur si necessaire }
          If (Item[Length(Item)] <> '/') And (Item[Length(Item)] <> '\') Then
            Item := Item + '/';
          ProcessDirectory(Item);
        End
        Else
          WarnMsg('Entree non trouvee: ' + Item);
      End;
      Start := I + 1;
    End;
  End;
  
  { Traiter tous les fichiers collectes }
  If SourceCount > 0 Then
    ProcessAllFiles;
End;

{ ============================================================
  FONCTIONS ACCESSEUR POUR LE SUPPORT MULTI-FICHIERS (TODO 23)
  ============================================================ }

{ Retourne le nombre de fichiers sources collectes }
Function GetSourceCount: Integer;
Begin
  GetSourceCount := SourceCount;
End;

{ Retourne le nombre de fichiers traites }
Function GetProcessedCount: Integer;
Begin
  GetProcessedCount := ProcessedCount;
End;

{ Retourne un fichier source par son index }
Function GetSourceFile(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= SourceCount) Then
    GetSourceFile := SourceFiles[Index]
  Else
    GetSourceFile := '';
End;

{ Retourne un fichier traite par son index }
Function GetProcessedFile(Index: Integer): String;
Begin
  If (Index >= 1) And (Index <= ProcessedCount) Then
    GetProcessedFile := ProcessedFiles[Index]
  Else
    GetProcessedFile := '';
End;

{ Verifie si le systeme multi-fichiers est initialise }
Function IsMultiFileInitialized: Boolean;
Begin
  IsMultiFileInitialized := MultiFileInitialized;
End;

{ Verifie si la liste des sources est vide }
Function IsSourceListEmpty: Boolean;
Begin
  IsSourceListEmpty := (SourceCount = 0);
End;

{ Verifie si la liste des fichiers traites est vide }
Function IsProcessedListEmpty: Boolean;
Begin
  IsProcessedListEmpty := (ProcessedCount = 0);
End;

{ Retourne le pourcentage de fichiers traites }
Function GetProcessingProgress: Integer;
Begin
  If SourceCount = 0 Then
    GetProcessingProgress := 100
  Else
    GetProcessingProgress := (ProcessedCount * 100) Div SourceCount;
End;

{ Retourne le nombre de fichiers restant a traiter }
Function GetRemainingFileCount: Integer;
Begin
  GetRemainingFileCount := SourceCount - ProcessedCount;
End;

{ Vide la liste des fichiers sources }
Procedure ClearSourceList;
Var
  I: Integer;
Begin
  For I := 1 To SourceCount Do
    SourceFiles[I] := '';
  SourceCount := 0;
End;

{ Vide la liste des fichiers traites }
Procedure ClearProcessedList;
Var
  I: Integer;
Begin
  For I := 1 To ProcessedCount Do
    ProcessedFiles[I] := '';
  ProcessedCount := 0;
End;

{ Affiche les fichiers sources collectes (debug) }
Procedure ShowSourceFiles;
Var
  I: Integer;
Begin
  WriteLn('=== FICHIERS SOURCES COLLECTES ===');
  WriteLn('Nombre: ', SourceCount);
  WriteLn('Initialise: ', MultiFileInitialized);
  WriteLn;
  
  For I := 1 To Min(SourceCount, 50) Do
  Begin
    WriteLn('  [', I, '] ', SourceFiles[I]);
  End;
  
  If SourceCount > 50 Then
    WriteLn('  ... et ', SourceCount - 50, ' autres fichiers');
End;

{ Affiche les fichiers traites (debug) }
Procedure ShowProcessedFiles;
Var
  I: Integer;
Begin
  WriteLn('=== FICHIERS TRAITES ===');
  WriteLn('Nombre: ', ProcessedCount);
  WriteLn('Progression: ', GetProcessingProgress, '%');
  WriteLn;
  
  For I := 1 To Min(ProcessedCount, 50) Do
  Begin
    WriteLn('  [', I, '] ', ProcessedFiles[I]);
  End;
  
  If ProcessedCount > 50 Then
    WriteLn('  ... et ', ProcessedCount - 50, ' autres fichiers');
End;


{ ============================================================
  VALIDATION ET AVERTISSEMENTS (TODO 24)
  ============================================================ }

{ Initialise le systeme de validation }
Procedure InitValidation;
Begin
  WarningCount := 0;
  ErrorCount := 0;
  ValidationInitialized := True;
End;

{ Retourne le nom d'un type d'avertissement }
Function WarningKindName(Kind: TWarningKind): String;
Begin
  Case Kind Of
    WARN_UNDOC_FUNC:      WarningKindName := 'UNDOC_FUNC';
    WARN_UNDOC_PARAM:     WarningKindName := 'UNDOC_PARAM';
    WARN_UNDOC_RETURN:    WarningKindName := 'UNDOC_RETURN';
    WARN_UNDOC_CLASS:     WarningKindName := 'UNDOC_CLASS';
    WARN_UNDOC_MEMBER:    WarningKindName := 'UNDOC_MEMBER';
    WARN_UNDOC_FILE:      WarningKindName := 'UNDOC_FILE';
    WARN_INVALID_TAG:     WarningKindName := 'INVALID_TAG';
    WARN_MISSING_PARAM:   WarningKindName := 'MISSING_PARAM';
    WARN_EXTRA_PARAM:     WarningKindName := 'EXTRA_PARAM';
    WARN_TYPE_MISMATCH:   WarningKindName := 'TYPE_MISMATCH';
    WARN_BROKEN_LINK:     WarningKindName := 'BROKEN_LINK';
    WARN_DUPLICATE_DOC:   WarningKindName := 'DUPLICATE_DOC';
    WARN_CIRCULAR_DEP:    WarningKindName := 'CIRCULAR_DEP';
    WARN_MISSING_INCLUDE: WarningKindName := 'MISSING_INCLUDE';
    WARN_SYNTAX_ERROR:    WarningKindName := 'SYNTAX_ERROR';
  Else
    WarningKindName := 'UNKNOWN';
  End;
End;

{ Retourne la description d'un type d'avertissement }
Function WarningKindDescription(Kind: TWarningKind): String;
Begin
  Case Kind Of
    WARN_UNDOC_FUNC:      WarningKindDescription := 'fonction non documentee';
    WARN_UNDOC_PARAM:     WarningKindDescription := 'parametre non documente';
    WARN_UNDOC_RETURN:    WarningKindDescription := 'retour non documente';
    WARN_UNDOC_CLASS:     WarningKindDescription := 'classe non documentee';
    WARN_UNDOC_MEMBER:    WarningKindDescription := 'membre non documente';
    WARN_UNDOC_FILE:      WarningKindDescription := 'fichier non documente';
    WARN_INVALID_TAG:     WarningKindDescription := 'balise Doxygen invalide';
    WARN_MISSING_PARAM:   WarningKindDescription := 'parametre @param manquant';
    WARN_EXTRA_PARAM:     WarningKindDescription := 'parametre @param en trop';
    WARN_TYPE_MISMATCH:   WarningKindDescription := 'type ne correspond pas';
    WARN_BROKEN_LINK:     WarningKindDescription := 'lien @see/@ref casse';
    WARN_DUPLICATE_DOC:   WarningKindDescription := 'documentation en double';
    WARN_CIRCULAR_DEP:    WarningKindDescription := 'dependance circulaire';
    WARN_MISSING_INCLUDE: WarningKindDescription := 'fichier include manquant';
    WARN_SYNTAX_ERROR:    WarningKindDescription := 'erreur de syntaxe';
  Else
    WarningKindDescription := 'avertissement inconnu';
  End;
End;

{ Enregistre un avertissement }
Procedure ReportWarning(Kind: TWarningKind; Const FileName: String;
  Line: Integer; Const Msg: String);
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  If WarningCount < MAX_WARNINGS Then
  Begin
    Inc(WarningCount);
    Warnings[WarningCount].Kind := Kind;
    Warnings[WarningCount].FileName := FileName;
    Warnings[WarningCount].Line := Line;
    Warnings[WarningCount].Message := Msg;
    Warnings[WarningCount].EntityId := 0;
  End;
End;

{ Enregistre un avertissement avec ID d'entite }
Procedure ReportWarningForEntity(Kind: TWarningKind; Const FileName: String;
  Line: Integer; Const Msg: String; EntId: Integer);
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  If WarningCount < MAX_WARNINGS Then
  Begin
    Inc(WarningCount);
    Warnings[WarningCount].Kind := Kind;
    Warnings[WarningCount].FileName := FileName;
    Warnings[WarningCount].Line := Line;
    Warnings[WarningCount].Message := Msg;
    Warnings[WarningCount].EntityId := EntId;
  End;
End;

{ Enregistre une erreur }
Procedure ReportError(Const FileName: String; Line: Integer; Const Msg: String);
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  Inc(ErrorCount);
  { Affiche l'erreur immediatement }
  WriteLn('ERREUR: ', FileName, ':', Line, ': ', Msg);
End;

{ Verifie si une entite est documentee (a une description breve) }
Function IsEntityDocumented(EntId: Integer): Boolean;
Begin
  If (EntId < 1) Or (EntId > EntityCount) Then
    IsEntityDocumented := False
  Else
    IsEntityDocumented := Entities[EntId].BriefDesc <> '';
End;

{ Verifie si une entite est publique }
Function IsEntityPublic(EntId: Integer): Boolean;
Begin
  If (EntId < 1) Or (EntId > EntityCount) Then
    IsEntityPublic := False
  Else
    IsEntityPublic := Entities[EntId].Visibility = VIS_PUBLIC;
End;

{ Valide la documentation de toutes les entites }
Procedure ValidateDocumentation;
Var
  I: Integer;
  WarnKind: TWarningKind;
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  For I := 1 To EntityCount Do
  Begin
    { Verifier seulement les entites publiques }
    If IsEntityPublic(I) Then
    Begin
      If Not IsEntityDocumented(I) Then
      Begin
        { Determiner le type d'avertissement selon le type d'entite }
        Case Entities[I].Kind Of
          ENT_FUNCTION:
            WarnKind := WARN_UNDOC_FUNC;
          ENT_CLASS, ENT_STRUCT, ENT_INTERFACE:
            WarnKind := WARN_UNDOC_CLASS;
          ENT_FILE:
            WarnKind := WARN_UNDOC_FILE;
        Else
          WarnKind := WARN_UNDOC_MEMBER;
        End;
        
        ReportWarningForEntity(WarnKind, Entities[I].FileName, Entities[I].Line,
          'Entite publique non documentee: ' + Entities[I].Name, I);
      End;
    End;
  End;
End;

{ Valide les liens @see et @ref }
Procedure ValidateLinks;
Var
  I, J: Integer;
  Target: String;
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  For I := 1 To DocTagCount Do
  Begin
    If (DocTags[I].Kind = TAG_SEE) Or (DocTags[I].Kind = TAG_REF) Then
    Begin
      Target := DocTags[I].Content;
      
      { Verifier si la cible existe }
      If Target <> '' Then
      Begin
        J := FindEntityByName(Target);
        If J = -1 Then
        Begin
          ReportWarning(WARN_BROKEN_LINK, '', DocTags[I].Line,
            'Lien vers entite inexistante: ' + Target);
        End;
      End;
    End;
  End;
End;

{ Valide la coherence des parametres @param }
Procedure ValidateParams;
Var
  I, J: Integer;
  ParamName: String;
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  { Parcourir toutes les fonctions }
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_FUNCTION Then
    Begin
      { Verifier que chaque @param correspond a un vrai parametre }
      For J := 1 To DocTagCount Do
      Begin
        If DocTags[J].Kind = TAG_PARAM Then
        Begin
          ParamName := DocTags[J].ParamName;
          { Verifier si le parametre existe dans la signature }
          If (ParamName <> '') And (Pos(ParamName, Entities[I].Parameters) = 0) Then
          Begin
            { Note: cette verification est approximative }
            { Une vraie implementation parserait la liste de parametres }
          End;
        End;
      End;
    End;
  End;
End;

{ Affiche tous les avertissements collectes }
Procedure DisplayWarnings;
Var
  I: Integer;
Begin
  If WarningCount = 0 Then
  Begin
    WriteLn('Aucun avertissement.');
    Exit;
  End;
  
  WriteLn;
  WriteLn('=== AVERTISSEMENTS (', WarningCount, ') ===');
  WriteLn;
  
  For I := 1 To WarningCount Do
  Begin
    Write('AVERT [', WarningKindName(Warnings[I].Kind), ']: ');
    If Warnings[I].FileName <> '' Then
      Write(Warnings[I].FileName, ':');
    If Warnings[I].Line > 0 Then
      Write(Warnings[I].Line, ': ');
    WriteLn(Warnings[I].Message);
  End;
  
  WriteLn;
  If ErrorCount > 0 Then
    WriteLn('Erreurs: ', ErrorCount);
End;

{ Affiche un resume des avertissements par type }
Procedure DisplayWarningSummary;
Var
  I: Integer;
  Counts: Array[TWarningKind] Of Integer;
  K: TWarningKind;
Begin
  { Initialiser les compteurs }
  For K := WARN_UNDOC_FUNC To WARN_SYNTAX_ERROR Do
    Counts[K] := 0;
    
  { Compter les avertissements par type }
  For I := 1 To WarningCount Do
    Inc(Counts[Warnings[I].Kind]);
    
  WriteLn;
  WriteLn('=== RESUME DES AVERTISSEMENTS ===');
  WriteLn;
  
  For K := WARN_UNDOC_FUNC To WARN_SYNTAX_ERROR Do
  Begin
    If Counts[K] > 0 Then
      WriteLn('  ', WarningKindName(K), ': ', Counts[K]);
  End;
  
  WriteLn;
  WriteLn('Total: ', WarningCount, ' avertissement(s), ', ErrorCount, ' erreur(s)');
End;

{ Retourne le nombre d'entites non documentees }
Function GetUndocumentedEntities: Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If IsEntityPublic(I) And Not IsEntityDocumented(I) Then
      Inc(Count);
  End;
  GetUndocumentedEntities := Count;
End;

{ Retourne le nombre d'entites documentees }
Function GetDocumentedEntities: Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To EntityCount Do
  Begin
    If IsEntityDocumented(I) Then
      Inc(Count);
  End;
  GetDocumentedEntities := Count;
End;

{ Calcule le pourcentage de couverture de documentation }
Function GetDocumentationCoverage: Real;
Var
  Total, Documented: Integer;
Begin
  Total := EntityCount;
  If Total = 0 Then
  Begin
    GetDocumentationCoverage := 100.0;
    Exit;
  End;
  
  Documented := GetDocumentedEntities;
  GetDocumentationCoverage := (Documented * 100.0) / Total;
End;

{ ============================================================
  FONCTIONS ACCESSEUR POUR LA VALIDATION (TODO 24)
  ============================================================ }

{ Retourne le nombre d'avertissements }
Function GetWarningCount: Integer;
Begin
  GetWarningCount := WarningCount;
End;

{ Retourne le nombre d'erreurs }
Function GetErrorCount: Integer;
Begin
  GetErrorCount := ErrorCount;
End;

{ Retourne un avertissement par index }
Function GetWarning(Index: Integer): TWarning;
Var
  EmptyWarning: TWarning;
Begin
  If (Index >= 1) And (Index <= WarningCount) Then
    GetWarning := Warnings[Index]
  Else
  Begin
    EmptyWarning.Kind := WARN_UNDOC_FUNC;
    EmptyWarning.FileName := '';
    EmptyWarning.Line := 0;
    EmptyWarning.Message := '';
    EmptyWarning.EntityId := 0;
    GetWarning := EmptyWarning;
  End;
End;

{ Verifie si la validation est initialisee }
Function IsValidationInitialized: Boolean;
Begin
  IsValidationInitialized := ValidationInitialized;
End;

{ Verifie s'il n'y a aucun avertissement }
Function IsValidationClean: Boolean;
Begin
  IsValidationClean := (WarningCount = 0) And (ErrorCount = 0);
End;

{ Compte les avertissements d'un type specifique }
Function CountWarningsOfKind(Kind: TWarningKind): Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To WarningCount Do
  Begin
    If Warnings[I].Kind = Kind Then
      Inc(Count);
  End;
  CountWarningsOfKind := Count;
End;

{ Compte les avertissements pour un fichier specifique }
Function CountWarningsForFile(Const FileName: String): Integer;
Var
  I, Count: Integer;
  FileUp: String;
Begin
  Count := 0;
  FileUp := UpStr(FileName);
  For I := 1 To WarningCount Do
  Begin
    If UpStr(Warnings[I].FileName) = FileUp Then
      Inc(Count);
  End;
  CountWarningsForFile := Count;
End;

{ Compte les avertissements pour une entite specifique }
Function CountWarningsForEntity(EntId: Integer): Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To WarningCount Do
  Begin
    If Warnings[I].EntityId = EntId Then
      Inc(Count);
  End;
  CountWarningsForEntity := Count;
End;

{ Efface tous les avertissements }
Procedure ClearWarnings;
Begin
  WarningCount := 0;
  ErrorCount := 0;
End;

{ Lance toutes les validations }
Procedure RunAllValidations;
Begin
  If Not ValidationInitialized Then
    InitValidation;
    
  ClearWarnings;
  ValidateDocumentation;
  ValidateLinks;
  ValidateParams;
End;

{ Affiche l'etat de la validation (debug) }
Procedure ShowValidationStatus;
Begin
  WriteLn('=== ETAT DE LA VALIDATION ===');
  WriteLn('Initialisee: ', ValidationInitialized);
  WriteLn('Avertissements: ', WarningCount);
  WriteLn('Erreurs: ', ErrorCount);
  WriteLn('Entites documentees: ', GetDocumentedEntities);
  WriteLn('Entites non documentees: ', GetUndocumentedEntities);
  WriteLn('Couverture: ', GetDocumentationCoverage:0:1, '%');
  WriteLn;
  
  WriteLn('Avertissements par type:');
  WriteLn('  Fonctions non doc: ', CountWarningsOfKind(WARN_UNDOC_FUNC));
  WriteLn('  Classes non doc: ', CountWarningsOfKind(WARN_UNDOC_CLASS));
  WriteLn('  Membres non doc: ', CountWarningsOfKind(WARN_UNDOC_MEMBER));
  WriteLn('  Liens casses: ', CountWarningsOfKind(WARN_BROKEN_LINK));
  WriteLn('  Params en trop: ', CountWarningsOfKind(WARN_EXTRA_PARAM));
End;

{ ============================================================
  TODO 25 - RAPPORT FINAL ET STATISTIQUES DE COUVERTURE
  ============================================================ }

{ Formate une taille en octets de facon lisible }
Function FormatSize(Bytes: LongInt): String;
Var
  S: String;
Begin
  If Bytes < 1024 Then
    Str(Bytes, S)
  Else If Bytes < 1024 * 1024 Then
  Begin
    Str((Bytes / 1024):0:2, S);
    S := S + ' Ko';
  End
  Else
  Begin
    Str((Bytes / (1024 * 1024)):0:2, S);
    S := S + ' Mo';
  End;
  FormatSize := S;
End;

{ Formate un nombre reel }
Function FloatToStr(R: Real): String;
Var
  S: String;
Begin
  Str(R:0:2, S);
  FloatToStr := S;
End;

{ Initialise les statistiques }
Procedure InitStatistics;
Begin
  With Stats Do
  Begin
    TotalFiles := 0;
    TotalLines := 0;
    TotalEntities := 0;
    DocumentedCount := 0;
    UndocumentedCount := 0;
    WarningCount := 0;
    ErrorCount := 0;
    ClassCount := 0;
    FunctionCount := 0;
    VariableCount := 0;
    NamespaceCount := 0;
    PageCount := 0;
    GroupCount := 0;
    CoveragePercent := 0.0;
    ProcessingTime := 0.0;
    OutputSize := 0;
  End;
  StartTime := 0;
  StatsInitialized := True;
End;

{ Demarre le chronometre }
Procedure StartTimer;
Var
  Hour, Min, Sec, Sec100: Word;
Begin
  GetTime(Hour, Min, Sec, Sec100);
  StartTime := LongInt(Hour) * 3600 + LongInt(Min) * 60 + LongInt(Sec);
End;

{ Retourne le temps ecoule en secondes }
Function GetElapsedTime: Real;
Var
  Hour, Min, Sec, Sec100: Word;
  CurrentTime: LongInt;
Begin
  GetTime(Hour, Min, Sec, Sec100);
  CurrentTime := LongInt(Hour) * 3600 + LongInt(Min) * 60 + LongInt(Sec);
  GetElapsedTime := CurrentTime - StartTime;
End;

{ Collecte toutes les statistiques }
Procedure CollectStatistics;
Var
  I: Integer;
  DocCount, UndocCount: Integer;
Begin
  If Not StatsInitialized Then
    InitStatistics;
    
  { Compte les fichiers traites }
  Stats.TotalFiles := ProcessedCount;
  If Stats.TotalFiles = 0 Then
    Stats.TotalFiles := SourceCount;
    
  { Compte les entites par type }
  Stats.TotalEntities := EntityCount;
  Stats.ClassCount := 0;
  Stats.FunctionCount := 0;
  Stats.VariableCount := 0;
  
  For I := 1 To EntityCount Do
  Begin
    Case Entities[I].Kind Of
      ENT_CLASS, ENT_STRUCT, ENT_INTERFACE:
        Inc(Stats.ClassCount);
      ENT_FUNCTION:
        Inc(Stats.FunctionCount);
      ENT_VARIABLE, ENT_DEFINE:
        Inc(Stats.VariableCount);
    End;
  End;
  
  { Compte les namespaces }
  Stats.NamespaceCount := NamespaceCount;
  
  { Compte les pages et groupes }
  Stats.PageCount := 0;
  Stats.GroupCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If Entities[I].Kind = ENT_PAGE Then
      Inc(Stats.PageCount);
    If Entities[I].Kind = ENT_GROUP Then
      Inc(Stats.GroupCount);
  End;
  
  { Compte les entites documentees/non-documentees }
  DocCount := 0;
  UndocCount := 0;
  For I := 1 To EntityCount Do
  Begin
    If IsEntityDocumented(I) Then
      Inc(DocCount)
    Else
      Inc(UndocCount);
  End;
  Stats.DocumentedCount := DocCount;
  Stats.UndocumentedCount := UndocCount;
  
  { Calcule le pourcentage de couverture }
  If Stats.TotalEntities > 0 Then
    Stats.CoveragePercent := (Stats.DocumentedCount / Stats.TotalEntities) * 100.0
  Else
    Stats.CoveragePercent := 0.0;
    
  { Copie les compteurs d'avertissements et d'erreurs }
  Stats.WarningCount := WarningCount;
  Stats.ErrorCount := ErrorCount;
  
  { Calcule le temps de traitement }
  Stats.ProcessingTime := GetElapsedTime;
End;

{ Affiche le rapport final }
Procedure DisplayFinalReport;
Begin
  CollectStatistics;
  
  WriteLn;
  WriteLn('=== DOXYGEN - Rapport de generation ===');
  WriteLn;
  WriteLn('Fichiers traites     : ', Stats.TotalFiles);
  WriteLn('Lignes de code       : ', Stats.TotalLines);
  WriteLn('Entites documentees  : ', Stats.DocumentedCount);
  WriteLn('Entites non-doc      : ', Stats.UndocumentedCount);
  WriteLn('Couverture           : ', Stats.CoveragePercent:0:1, '%');
  WriteLn;
  WriteLn('Detail par type:');
  WriteLn('  Classes            : ', Stats.ClassCount);
  WriteLn('  Fonctions          : ', Stats.FunctionCount);
  WriteLn('  Variables          : ', Stats.VariableCount);
  WriteLn('  Namespaces         : ', Stats.NamespaceCount);
  WriteLn('  Pages              : ', Stats.PageCount);
  WriteLn('  Groupes            : ', Stats.GroupCount);
  WriteLn;
  WriteLn('Avertissements       : ', Stats.WarningCount);
  WriteLn('Erreurs              : ', Stats.ErrorCount);
  WriteLn('Temps de traitement  : ', Stats.ProcessingTime:0:1, ' s');
  If Stats.OutputSize > 0 Then
    WriteLn('Taille documentation : ', FormatSize(Stats.OutputSize));
  WriteLn;
  
  { Affichage du detail si mode Verbose }
  If Opts.Verbose Then
  Begin
    WriteLn('=== Detail par fichier ===');
    WriteLn('(Liste des fichiers traites)');
  End;
End;

{ Ecrit les statistiques au format XML }
Procedure WriteStatisticsXml(Var OutFile: Text);
Begin
  CollectStatistics;
  
  WriteLn(OutFile, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(OutFile, '<doxygen-statistics>');
  WriteLn(OutFile, '  <summary>');
  WriteLn(OutFile, '    <total-files>', Stats.TotalFiles, '</total-files>');
  WriteLn(OutFile, '    <total-lines>', Stats.TotalLines, '</total-lines>');
  WriteLn(OutFile, '    <total-entities>', Stats.TotalEntities, '</total-entities>');
  WriteLn(OutFile, '    <documented>', Stats.DocumentedCount, '</documented>');
  WriteLn(OutFile, '    <undocumented>', Stats.UndocumentedCount, '</undocumented>');
  WriteLn(OutFile, '    <coverage>', Stats.CoveragePercent:0:1, '</coverage>');
  WriteLn(OutFile, '  </summary>');
  WriteLn(OutFile, '  <entities>');
  WriteLn(OutFile, '    <classes>', Stats.ClassCount, '</classes>');
  WriteLn(OutFile, '    <functions>', Stats.FunctionCount, '</functions>');
  WriteLn(OutFile, '    <variables>', Stats.VariableCount, '</variables>');
  WriteLn(OutFile, '    <namespaces>', Stats.NamespaceCount, '</namespaces>');
  WriteLn(OutFile, '    <pages>', Stats.PageCount, '</pages>');
  WriteLn(OutFile, '    <groups>', Stats.GroupCount, '</groups>');
  WriteLn(OutFile, '  </entities>');
  WriteLn(OutFile, '  <diagnostics>');
  WriteLn(OutFile, '    <warnings>', Stats.WarningCount, '</warnings>');
  WriteLn(OutFile, '    <errors>', Stats.ErrorCount, '</errors>');
  WriteLn(OutFile, '  </diagnostics>');
  WriteLn(OutFile, '  <performance>');
  WriteLn(OutFile, '    <processing-time>', Stats.ProcessingTime:0:2, '</processing-time>');
  WriteLn(OutFile, '    <output-size>', Stats.OutputSize, '</output-size>');
  WriteLn(OutFile, '  </performance>');
  WriteLn(OutFile, '</doxygen-statistics>');
End;

{ Sauvegarde les statistiques dans un fichier XML }
Procedure SaveStatisticsXml(Const FileName: String);
Var
  F: Text;
Begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('Impossible de creer le fichier de statistiques: ' + FileName);
    Exit;
  End;
  
  WriteStatisticsXml(F);
  Close(F);
End;

{ Accesseurs pour les statistiques }
Function GetStatsTotalFiles: Integer;
Begin
  GetStatsTotalFiles := Stats.TotalFiles;
End;

Function GetStatsTotalLines: Integer;
Begin
  GetStatsTotalLines := Stats.TotalLines;
End;

Function GetStatsTotalEntities: Integer;
Begin
  GetStatsTotalEntities := Stats.TotalEntities;
End;

Function GetStatsDocumentedCount: Integer;
Begin
  GetStatsDocumentedCount := Stats.DocumentedCount;
End;

Function GetStatsUndocumentedCount: Integer;
Begin
  GetStatsUndocumentedCount := Stats.UndocumentedCount;
End;

Function GetStatsCoveragePercent: Real;
Begin
  GetStatsCoveragePercent := Stats.CoveragePercent;
End;

Function GetStatsClassCount: Integer;
Begin
  GetStatsClassCount := Stats.ClassCount;
End;

Function GetStatsFunctionCount: Integer;
Begin
  GetStatsFunctionCount := Stats.FunctionCount;
End;

Function GetStatsVariableCount: Integer;
Begin
  GetStatsVariableCount := Stats.VariableCount;
End;

Function GetStatsNamespaceCount: Integer;
Begin
  GetStatsNamespaceCount := Stats.NamespaceCount;
End;

Function GetStatsWarningCount: Integer;
Begin
  GetStatsWarningCount := Stats.WarningCount;
End;

Function GetStatsErrorCount: Integer;
Begin
  GetStatsErrorCount := Stats.ErrorCount;
End;

Function GetStatsProcessingTime: Real;
Begin
  GetStatsProcessingTime := Stats.ProcessingTime;
End;

Function GetStatsOutputSize: LongInt;
Begin
  GetStatsOutputSize := Stats.OutputSize;
End;

Function IsStatsInitialized: Boolean;
Begin
  IsStatsInitialized := StatsInitialized;
End;

Function IsStatsEmpty: Boolean;
Begin
  IsStatsEmpty := (Stats.TotalEntities = 0);
End;

{ Definit la taille de sortie }
Procedure SetStatsOutputSize(Size: LongInt);
Begin
  Stats.OutputSize := Size;
End;

{ Definit le nombre de lignes }
Procedure SetStatsTotalLines(Lines: Integer);
Begin
  Stats.TotalLines := Lines;
End;

{ Affiche l'etat des statistiques (debug) }
Procedure ShowStatsStatus;
Begin
  WriteLn('=== ETAT DES STATISTIQUES ===');
  WriteLn('Initialisees: ', StatsInitialized);
  WriteLn('Fichiers: ', Stats.TotalFiles);
  WriteLn('Lignes: ', Stats.TotalLines);
  WriteLn('Entites: ', Stats.TotalEntities);
  WriteLn('Documentees: ', Stats.DocumentedCount);
  WriteLn('Non documentees: ', Stats.UndocumentedCount);
  WriteLn('Couverture: ', Stats.CoveragePercent:0:1, '%');
  WriteLn('Classes: ', Stats.ClassCount);
  WriteLn('Fonctions: ', Stats.FunctionCount);
  WriteLn('Variables: ', Stats.VariableCount);
  WriteLn('Namespaces: ', Stats.NamespaceCount);
  WriteLn('Avertissements: ', Stats.WarningCount);
  WriteLn('Erreurs: ', Stats.ErrorCount);
  WriteLn('Temps: ', Stats.ProcessingTime:0:1, ' s');
  WriteLn('Taille sortie: ', FormatSize(Stats.OutputSize));
End;

{ ============================================================
  GENERATEUR JPEG INTEGRE - PARTIE 4
  Transformation DCT (Discrete Cosine Transform) 8x8
  ============================================================ }

{ La DCT est implementee en deux passes (separable):
  1. DCT horizontale sur chaque ligne
  2. DCT verticale sur chaque colonne
  
  Cela reduit la complexite de O(N^4) a O(N^3) pour un bloc NxN. }

Procedure JPEG_InitCosTable;
{ Initialise la table des cosinus pre-calcules pour la DCT 8x8
  cos((2x+1) * u * pi / 16) pour x,u = 0..7 }
Var
  X, U: Integer;
Begin
  For X := 0 To 7 Do
    For U := 0 To 7 Do
      JPEG_CosTable[X, U] := Cos((2.0 * X + 1.0) * U * JPEG_PI / 16.0);
  JPEG_DCTInitialized := True;
End;

Procedure JPEG_InitDCT;
{ Initialise le module DCT (tables de cosinus) }
Begin
  If Not JPEG_DCTInitialized Then
    JPEG_InitCosTable;
End;

Function JPEG_Alpha(U: Integer): Real;
{ Calcule le facteur de normalisation C(u) pour la DCT
  C(0) = 1/sqrt(2), C(u) = 1 pour u > 0 }
Begin
  If U = 0 Then
    JPEG_Alpha := JPEG_DCT_SQRT2_INV
  Else
    JPEG_Alpha := 1.0;
End;

Procedure JPEG_DCT_Forward(Var Pixels: TJPEGPixelBlock;
                           Var Coeffs: TJPEGDCTBlock);
{ Applique la DCT-II 2D sur un bloc 8x8 de pixels
  
  Entree:
    Pixels - Bloc 8x8 de pixels (valeurs 0-255 seront centrees)
  
  Sortie:
    Coeffs - Bloc 8x8 de coefficients DCT (valeurs flottantes)
  
  La transformation est effectuee en deux passes (separable):
  1. DCT 1D sur les lignes (horizontale)
  2. DCT 1D sur les colonnes (verticale)
  
  Formule DCT-II 2D:
  F(u,v) = (1/4) * C(u) * C(v) * SUM[x,y] (f(x,y) - 128) *
           cos((2x+1)*u*pi/16) * cos((2y+1)*v*pi/16)
}
Var
  U, V, X, Y: Integer;
  Sum: Real;
  Temp: TJPEGDCTBlock;
  CenteredPixel: Real;
Begin
  { S'assurer que les tables sont initialisees }
  If Not JPEG_DCTInitialized Then
    JPEG_InitCosTable;
  
  { Passe 1: DCT horizontale (sur les lignes) }
  For Y := 0 To 7 Do
  Begin
    For U := 0 To 7 Do
    Begin
      Sum := 0.0;
      For X := 0 To 7 Do
      Begin
        { Centrer les pixels autour de 0 (Level Shift) }
        CenteredPixel := Pixels[Y, X] - JPEG_LEVEL_SHIFT;
        Sum := Sum + CenteredPixel * JPEG_CosTable[X, U];
      End;
      { Appliquer le facteur de normalisation }
      Temp[Y, U] := Sum * JPEG_Alpha(U) * 0.5;
    End;
  End;
  
  { Passe 2: DCT verticale (sur les colonnes) }
  For U := 0 To 7 Do
  Begin
    For V := 0 To 7 Do
    Begin
      Sum := 0.0;
      For Y := 0 To 7 Do
        Sum := Sum + Temp[Y, U] * JPEG_CosTable[Y, V];
      { Appliquer le facteur de normalisation }
      Coeffs[V, U] := Sum * JPEG_Alpha(V) * 0.5;
    End;
  End;
End;

Procedure JPEG_DCT_Inverse(Var Coeffs: TJPEGDCTBlock;
                           Var Pixels: TJPEGPixelBlock);
{ Applique la DCT-II inverse (IDCT) sur un bloc 8x8 de coefficients
  
  Entree:
    Coeffs - Bloc 8x8 de coefficients DCT (valeurs flottantes)
  
  Sortie:
    Pixels - Bloc 8x8 de pixels reconstruits (valeurs 0-255)
  
  Formule IDCT:
  f(x,y) = (1/4) * SUM[u,v] C(u)*C(v) * F(u,v) *
           cos((2x+1)*u*pi/16) * cos((2y+1)*v*pi/16) + 128
}
Var
  U, V, X, Y: Integer;
  Sum: Real;
  Temp: TJPEGDCTBlock;
  PixelVal: Real;
Begin
  { S'assurer que les tables sont initialisees }
  If Not JPEG_DCTInitialized Then
    JPEG_InitCosTable;
  
  { Passe 1: IDCT verticale (sur les colonnes) }
  For U := 0 To 7 Do
  Begin
    For Y := 0 To 7 Do
    Begin
      Sum := 0.0;
      For V := 0 To 7 Do
        Sum := Sum + JPEG_Alpha(V) * Coeffs[V, U] * JPEG_CosTable[Y, V];
      Temp[Y, U] := Sum * 0.5;
    End;
  End;
  
  { Passe 2: IDCT horizontale (sur les lignes) }
  For Y := 0 To 7 Do
  Begin
    For X := 0 To 7 Do
    Begin
      Sum := 0.0;
      For U := 0 To 7 Do
        Sum := Sum + JPEG_Alpha(U) * Temp[Y, U] * JPEG_CosTable[X, U];
      PixelVal := Sum * 0.5 + JPEG_LEVEL_SHIFT;
      
      { Clipping: limiter a l'intervalle [0, 255] }
      If PixelVal < 0 Then
        Pixels[Y, X] := 0
      Else If PixelVal > 255 Then
        Pixels[Y, X] := 255
      Else
        Pixels[Y, X] := Round(PixelVal);
    End;
  End;
End;

Procedure JPEG_Quantize(Var Coeffs: TJPEGDCTBlock;
                        Var QuantTable: TJPEGQuantTable;
                        Var Quantized: TJPEGQuantBlock);
{ Quantifie les coefficients DCT avec la table de quantification
  
  Entree:
    Coeffs - Bloc 8x8 de coefficients DCT (flottants)
    QuantTable - Table de quantification 64 elements (ordre zigzag)
  
  Sortie:
    Quantized - Bloc 8x8 de coefficients quantifies (entiers)
  
  Formule: Fq(u,v) = Round(F(u,v) / Q(u,v))
}
Var
  U, V, Idx: Integer;
  QVal: Real;
Begin
  For V := 0 To 7 Do
  Begin
    For U := 0 To 7 Do
    Begin
      { L'index dans la table de quantification suit l'ordre ligne par ligne }
      Idx := V * 8 + U;
      QVal := QuantTable[Idx];
      If QVal < 1 Then QVal := 1;  { Eviter division par zero }
      Quantized[V, U] := Round(Coeffs[V, U] / QVal);
    End;
  End;
End;

Procedure JPEG_Dequantize(Var Quantized: TJPEGQuantBlock;
                          Var QuantTable: TJPEGQuantTable;
                          Var Coeffs: TJPEGDCTBlock);
{ Dequantifie les coefficients DCT (operation inverse)
  
  Formule: F(u,v) = Fq(u,v) * Q(u,v)
}
Var
  U, V, Idx: Integer;
Begin
  For V := 0 To 7 Do
  Begin
    For U := 0 To 7 Do
    Begin
      Idx := V * 8 + U;
      Coeffs[V, U] := Quantized[V, U] * QuantTable[Idx];
    End;
  End;
End;

Function JPEG_GetDCCoeff(Var Quantized: TJPEGQuantBlock): Integer;
{ Retourne le coefficient DC (position 0,0) d'un bloc quantifie }
Begin
  JPEG_GetDCCoeff := Quantized[0, 0];
End;

Function JPEG_CountNonZeroAC(Var Quantized: TJPEGQuantBlock): Integer;
{ Compte le nombre de coefficients AC non-nuls dans un bloc quantifie
  (tous les coefficients sauf le DC en position 0,0) }
Var
  U, V, Count: Integer;
Begin
  Count := 0;
  For V := 0 To 7 Do
    For U := 0 To 7 Do
      If Not ((V = 0) And (U = 0)) Then  { Exclure DC }
        If Quantized[V, U] <> 0 Then
          Inc(Count);
  JPEG_CountNonZeroAC := Count;
End;

Function JPEG_IsDCTInitialized: Boolean;
{ Indique si le module DCT est initialise }
Begin
  JPEG_IsDCTInitialized := JPEG_DCTInitialized;
End;

Procedure JPEG_ClearDCTBlock(Var Block: TJPEGDCTBlock);
{ Met a zero tous les coefficients d'un bloc DCT }
Var
  U, V: Integer;
Begin
  For V := 0 To 7 Do
    For U := 0 To 7 Do
      Block[V, U] := 0.0;
End;

Procedure JPEG_ClearPixelBlock(Var Block: TJPEGPixelBlock);
{ Met a zero tous les pixels d'un bloc }
Var
  X, Y: Integer;
Begin
  For Y := 0 To 7 Do
    For X := 0 To 7 Do
      Block[Y, X] := 0;
End;

Procedure JPEG_ClearQuantBlock(Var Block: TJPEGQuantBlock);
{ Met a zero tous les coefficients quantifies d'un bloc }
Var
  U, V: Integer;
Begin
  For V := 0 To 7 Do
    For U := 0 To 7 Do
      Block[V, U] := 0;
End;

{ ============================================================
  GENERATEUR JPEG INTEGRE - PARTIE 5
  Zigzag Reordering - Reorganisation des 64 coefficients DCT
  ============================================================ }

{ Dans JPEG, les 64 coefficients DCT d'un bloc 8x8 sont reorganises
  selon un parcours en zigzag avant l'encodage entropique.
  
  Ce parcours zigzag permet de grouper les coefficients de basse
  frequence (coin superieur gauche) au debut de la sequence lineaire
  et les hautes frequences (coin inferieur droit) a la fin.
  
  Comme les hautes frequences sont souvent nulles apres quantification,
  le parcours zigzag facilite l'encodage RLE (Run-Length Encoding).
  
  Parcours zigzag 8x8:
   0  1  5  6 14 15 27 28
   2  4  7 13 16 26 29 42
   3  8 12 17 25 30 41 43
   9 11 18 24 31 40 44 53
  10 19 23 32 39 45 52 54
  20 22 33 38 46 51 55 60
  21 34 37 47 50 56 59 61
  35 36 48 49 57 58 62 63 }

Procedure JPEG_InitZigzagTable;
{ Initialise les tables de correspondance zigzag
  - JPEG_ZigzagTable[i] = position matricielle pour position zigzag i
  - JPEG_InvZigzagTable[j] = position zigzag pour position matricielle j
  
  La position matricielle est: row * 8 + col
  La table utilise les constantes JPEG_ZZ_xx definies dans la Partie 2 }
Begin
  { Table zigzag: indice zigzag -> position matricielle }
  JPEG_ZigzagTable[0]  := JPEG_ZZ_00;   { 0 -> 0 }
  JPEG_ZigzagTable[1]  := JPEG_ZZ_01;   { 1 -> 1 }
  JPEG_ZigzagTable[2]  := JPEG_ZZ_02;   { 2 -> 8 }
  JPEG_ZigzagTable[3]  := JPEG_ZZ_03;   { 3 -> 16 }
  JPEG_ZigzagTable[4]  := JPEG_ZZ_04;   { 4 -> 9 }
  JPEG_ZigzagTable[5]  := JPEG_ZZ_05;   { 5 -> 2 }
  JPEG_ZigzagTable[6]  := JPEG_ZZ_06;   { 6 -> 3 }
  JPEG_ZigzagTable[7]  := JPEG_ZZ_07;   { 7 -> 10 }
  JPEG_ZigzagTable[8]  := JPEG_ZZ_08;   { 8 -> 17 }
  JPEG_ZigzagTable[9]  := JPEG_ZZ_09;   { 9 -> 24 }
  JPEG_ZigzagTable[10] := JPEG_ZZ_10;   { 10 -> 32 }
  JPEG_ZigzagTable[11] := JPEG_ZZ_11;   { 11 -> 25 }
  JPEG_ZigzagTable[12] := JPEG_ZZ_12;   { 12 -> 18 }
  JPEG_ZigzagTable[13] := JPEG_ZZ_13;   { 13 -> 11 }
  JPEG_ZigzagTable[14] := JPEG_ZZ_14;   { 14 -> 4 }
  JPEG_ZigzagTable[15] := JPEG_ZZ_15;   { 15 -> 5 }
  JPEG_ZigzagTable[16] := JPEG_ZZ_16;   { 16 -> 12 }
  JPEG_ZigzagTable[17] := JPEG_ZZ_17;   { 17 -> 19 }
  JPEG_ZigzagTable[18] := JPEG_ZZ_18;   { 18 -> 26 }
  JPEG_ZigzagTable[19] := JPEG_ZZ_19;   { 19 -> 33 }
  JPEG_ZigzagTable[20] := JPEG_ZZ_20;   { 20 -> 40 }
  JPEG_ZigzagTable[21] := JPEG_ZZ_21;   { 21 -> 48 }
  JPEG_ZigzagTable[22] := JPEG_ZZ_22;   { 22 -> 41 }
  JPEG_ZigzagTable[23] := JPEG_ZZ_23;   { 23 -> 34 }
  JPEG_ZigzagTable[24] := JPEG_ZZ_24;   { 24 -> 27 }
  JPEG_ZigzagTable[25] := JPEG_ZZ_25;   { 25 -> 20 }
  JPEG_ZigzagTable[26] := JPEG_ZZ_26;   { 26 -> 13 }
  JPEG_ZigzagTable[27] := JPEG_ZZ_27;   { 27 -> 6 }
  JPEG_ZigzagTable[28] := JPEG_ZZ_28;   { 28 -> 7 }
  JPEG_ZigzagTable[29] := JPEG_ZZ_29;   { 29 -> 14 }
  JPEG_ZigzagTable[30] := JPEG_ZZ_30;   { 30 -> 21 }
  JPEG_ZigzagTable[31] := JPEG_ZZ_31;   { 31 -> 28 }
  JPEG_ZigzagTable[32] := JPEG_ZZ_32;   { 32 -> 35 }
  JPEG_ZigzagTable[33] := JPEG_ZZ_33;   { 33 -> 42 }
  JPEG_ZigzagTable[34] := JPEG_ZZ_34;   { 34 -> 49 }
  JPEG_ZigzagTable[35] := JPEG_ZZ_35;   { 35 -> 56 }
  JPEG_ZigzagTable[36] := JPEG_ZZ_36;   { 36 -> 57 }
  JPEG_ZigzagTable[37] := JPEG_ZZ_37;   { 37 -> 50 }
  JPEG_ZigzagTable[38] := JPEG_ZZ_38;   { 38 -> 43 }
  JPEG_ZigzagTable[39] := JPEG_ZZ_39;   { 39 -> 36 }
  JPEG_ZigzagTable[40] := JPEG_ZZ_40;   { 40 -> 29 }
  JPEG_ZigzagTable[41] := JPEG_ZZ_41;   { 41 -> 22 }
  JPEG_ZigzagTable[42] := JPEG_ZZ_42;   { 42 -> 15 }
  JPEG_ZigzagTable[43] := JPEG_ZZ_43;   { 43 -> 23 }
  JPEG_ZigzagTable[44] := JPEG_ZZ_44;   { 44 -> 30 }
  JPEG_ZigzagTable[45] := JPEG_ZZ_45;   { 45 -> 37 }
  JPEG_ZigzagTable[46] := JPEG_ZZ_46;   { 46 -> 44 }
  JPEG_ZigzagTable[47] := JPEG_ZZ_47;   { 47 -> 51 }
  JPEG_ZigzagTable[48] := JPEG_ZZ_48;   { 48 -> 58 }
  JPEG_ZigzagTable[49] := JPEG_ZZ_49;   { 49 -> 59 }
  JPEG_ZigzagTable[50] := JPEG_ZZ_50;   { 50 -> 52 }
  JPEG_ZigzagTable[51] := JPEG_ZZ_51;   { 51 -> 45 }
  JPEG_ZigzagTable[52] := JPEG_ZZ_52;   { 52 -> 38 }
  JPEG_ZigzagTable[53] := JPEG_ZZ_53;   { 53 -> 31 }
  JPEG_ZigzagTable[54] := JPEG_ZZ_54;   { 54 -> 39 }
  JPEG_ZigzagTable[55] := JPEG_ZZ_55;   { 55 -> 46 }
  JPEG_ZigzagTable[56] := JPEG_ZZ_56;   { 56 -> 53 }
  JPEG_ZigzagTable[57] := JPEG_ZZ_57;   { 57 -> 60 }
  JPEG_ZigzagTable[58] := JPEG_ZZ_58;   { 58 -> 61 }
  JPEG_ZigzagTable[59] := JPEG_ZZ_59;   { 59 -> 54 }
  JPEG_ZigzagTable[60] := JPEG_ZZ_60;   { 60 -> 47 }
  JPEG_ZigzagTable[61] := JPEG_ZZ_61;   { 61 -> 55 }
  JPEG_ZigzagTable[62] := JPEG_ZZ_62;   { 62 -> 62 }
  JPEG_ZigzagTable[63] := JPEG_ZZ_63;   { 63 -> 63 }
  
  { Table inverse: position matricielle -> indice zigzag }
  JPEG_InvZigzagTable[0]  := 0;   JPEG_InvZigzagTable[1]  := 1;
  JPEG_InvZigzagTable[2]  := 5;   JPEG_InvZigzagTable[3]  := 6;
  JPEG_InvZigzagTable[4]  := 14;  JPEG_InvZigzagTable[5]  := 15;
  JPEG_InvZigzagTable[6]  := 27;  JPEG_InvZigzagTable[7]  := 28;
  JPEG_InvZigzagTable[8]  := 2;   JPEG_InvZigzagTable[9]  := 4;
  JPEG_InvZigzagTable[10] := 7;   JPEG_InvZigzagTable[11] := 13;
  JPEG_InvZigzagTable[12] := 16;  JPEG_InvZigzagTable[13] := 26;
  JPEG_InvZigzagTable[14] := 29;  JPEG_InvZigzagTable[15] := 42;
  JPEG_InvZigzagTable[16] := 3;   JPEG_InvZigzagTable[17] := 8;
  JPEG_InvZigzagTable[18] := 12;  JPEG_InvZigzagTable[19] := 17;
  JPEG_InvZigzagTable[20] := 25;  JPEG_InvZigzagTable[21] := 30;
  JPEG_InvZigzagTable[22] := 41;  JPEG_InvZigzagTable[23] := 43;
  JPEG_InvZigzagTable[24] := 9;   JPEG_InvZigzagTable[25] := 11;
  JPEG_InvZigzagTable[26] := 18;  JPEG_InvZigzagTable[27] := 24;
  JPEG_InvZigzagTable[28] := 31;  JPEG_InvZigzagTable[29] := 40;
  JPEG_InvZigzagTable[30] := 44;  JPEG_InvZigzagTable[31] := 53;
  JPEG_InvZigzagTable[32] := 10;  JPEG_InvZigzagTable[33] := 19;
  JPEG_InvZigzagTable[34] := 23;  JPEG_InvZigzagTable[35] := 32;
  JPEG_InvZigzagTable[36] := 39;  JPEG_InvZigzagTable[37] := 45;
  JPEG_InvZigzagTable[38] := 52;  JPEG_InvZigzagTable[39] := 54;
  JPEG_InvZigzagTable[40] := 20;  JPEG_InvZigzagTable[41] := 22;
  JPEG_InvZigzagTable[42] := 33;  JPEG_InvZigzagTable[43] := 38;
  JPEG_InvZigzagTable[44] := 46;  JPEG_InvZigzagTable[45] := 51;
  JPEG_InvZigzagTable[46] := 55;  JPEG_InvZigzagTable[47] := 60;
  JPEG_InvZigzagTable[48] := 21;  JPEG_InvZigzagTable[49] := 34;
  JPEG_InvZigzagTable[50] := 37;  JPEG_InvZigzagTable[51] := 47;
  JPEG_InvZigzagTable[52] := 50;  JPEG_InvZigzagTable[53] := 56;
  JPEG_InvZigzagTable[54] := 59;  JPEG_InvZigzagTable[55] := 61;
  JPEG_InvZigzagTable[56] := 35;  JPEG_InvZigzagTable[57] := 36;
  JPEG_InvZigzagTable[58] := 48;  JPEG_InvZigzagTable[59] := 49;
  JPEG_InvZigzagTable[60] := 57;  JPEG_InvZigzagTable[61] := 58;
  JPEG_InvZigzagTable[62] := 62;  JPEG_InvZigzagTable[63] := 63;
  
  JPEG_ZigzagInitialized := True;
End;

Procedure JPEG_InitZigzag;
{ Initialise le module Zigzag (tables de correspondance) }
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
End;

Procedure JPEG_QuantBlockToZigzag(Var Block: TJPEGQuantBlock;
                                   Var Zigzag: TJPEGZigzagBlock);
{ Convertit un bloc 8x8 quantifie en tableau lineaire ordre zigzag
  
  Entree:
    Block - Bloc 8x8 de coefficients quantifies (entiers)
  
  Sortie:
    Zigzag - Tableau lineaire de 64 coefficients en ordre zigzag
  
  Le coefficient DC (Block[0,0]) est toujours en Zigzag[0].
  Les coefficients AC suivent le parcours en zigzag. }
Var
  I, MatPos, Row, Col: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  For I := 0 To 63 Do
  Begin
    { Obtenir la position matricielle pour l'indice zigzag I }
    MatPos := JPEG_ZigzagTable[I];
    Row := MatPos Div 8;
    Col := MatPos Mod 8;
    Zigzag[I] := Block[Row, Col];
  End;
End;

Procedure JPEG_ZigzagToQuantBlock(Var Zigzag: TJPEGZigzagBlock;
                                   Var Block: TJPEGQuantBlock);
{ Convertit un tableau lineaire ordre zigzag en bloc 8x8 quantifie
  (operation inverse de JPEG_QuantBlockToZigzag)
  
  Entree:
    Zigzag - Tableau lineaire de 64 coefficients en ordre zigzag
  
  Sortie:
    Block - Bloc 8x8 de coefficients quantifies (entiers) }
Var
  I, MatPos, Row, Col: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  For I := 0 To 63 Do
  Begin
    { Obtenir la position matricielle pour l'indice zigzag I }
    MatPos := JPEG_ZigzagTable[I];
    Row := MatPos Div 8;
    Col := MatPos Mod 8;
    Block[Row, Col] := Zigzag[I];
  End;
End;

Procedure JPEG_DCTBlockToZigzag(Var Block: TJPEGDCTBlock;
                                 Var Zigzag: TJPEGZigzagBlock);
{ Convertit un bloc 8x8 DCT (flottant) en tableau lineaire zigzag (entier)
  Les valeurs sont arrondies a l'entier le plus proche.
  
  Note: Generalement, on utilise JPEG_QuantBlockToZigzag apres
  quantification. Cette fonction est utile pour debug/tests. }
Var
  I, MatPos, Row, Col: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  For I := 0 To 63 Do
  Begin
    MatPos := JPEG_ZigzagTable[I];
    Row := MatPos Div 8;
    Col := MatPos Mod 8;
    Zigzag[I] := Round(Block[Row, Col]);
  End;
End;

Procedure JPEG_ZigzagToDCTBlock(Var Zigzag: TJPEGZigzagBlock;
                                 Var Block: TJPEGDCTBlock);
{ Convertit un tableau lineaire zigzag (entier) en bloc 8x8 DCT (flottant)
  (operation inverse de JPEG_DCTBlockToZigzag) }
Var
  I, MatPos, Row, Col: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  For I := 0 To 63 Do
  Begin
    MatPos := JPEG_ZigzagTable[I];
    Row := MatPos Div 8;
    Col := MatPos Mod 8;
    Block[Row, Col] := Zigzag[I];
  End;
End;

Function JPEG_GetZigzagIndex(Row, Col: Integer): Integer;
{ Retourne l'indice zigzag pour une position matricielle (row, col)
  Row et Col doivent etre dans [0..7] }
Var
  MatPos: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  MatPos := Row * 8 + Col;
  If (MatPos >= 0) And (MatPos <= 63) Then
    JPEG_GetZigzagIndex := JPEG_InvZigzagTable[MatPos]
  Else
    JPEG_GetZigzagIndex := -1;  { Erreur: position invalide }
End;

Procedure JPEG_GetMatrixPos(ZigzagIdx: Integer; Var Row, Col: Integer);
{ Retourne la position matricielle (row, col) pour un indice zigzag
  ZigzagIdx doit etre dans [0..63] }
Var
  MatPos: Integer;
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  If (ZigzagIdx >= 0) And (ZigzagIdx <= 63) Then
  Begin
    MatPos := JPEG_ZigzagTable[ZigzagIdx];
    Row := MatPos Div 8;
    Col := MatPos Mod 8;
  End
  Else
  Begin
    Row := -1;  { Erreur: indice invalide }
    Col := -1;
  End;
End;

Function JPEG_FindLastNonZero(Var Zigzag: TJPEGZigzagBlock): Integer;
{ Trouve l'indice du dernier coefficient non-nul dans un bloc zigzag
  
  Retourne:
    -1 si tous les coefficients sont nuls (bloc vide)
    0..63 l'indice du dernier coefficient non-nul
  
  Cette fonction est utile pour l'encodage RLE car elle permet
  de savoir ou s'arrete la sequence de coefficients AC. }
Var
  I: Integer;
Begin
  For I := 63 DownTo 0 Do
  Begin
    If Zigzag[I] <> 0 Then
    Begin
      JPEG_FindLastNonZero := I;
      Exit;
    End;
  End;
  JPEG_FindLastNonZero := -1;  { Tous les coefficients sont nuls }
End;

Function JPEG_CountZerosBeforeIndex(Var Zigzag: TJPEGZigzagBlock;
                                     StartIdx, EndIdx: Integer): Integer;
{ Compte le nombre de zeros consecutifs entre StartIdx et EndIdx (inclus)
  
  Cette fonction est utile pour l'encodage RLE des coefficients AC.
  Dans JPEG, les zeros consecutifs sont encodes avec le coefficient
  non-nul suivant sous forme (RunLength, Value). }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := StartIdx To EndIdx Do
  Begin
    If (I >= 0) And (I <= 63) Then
    Begin
      If Zigzag[I] = 0 Then
        Inc(Count)
      Else
        Break;  { Arret au premier non-nul }
    End;
  End;
  JPEG_CountZerosBeforeIndex := Count;
End;

Function JPEG_GetZigzagDC(Var Zigzag: TJPEGZigzagBlock): Integer;
{ Retourne le coefficient DC (indice 0) du bloc zigzag }
Begin
  JPEG_GetZigzagDC := Zigzag[0];
End;

Procedure JPEG_SetZigzagDC(Var Zigzag: TJPEGZigzagBlock; Value: Integer);
{ Modifie le coefficient DC (indice 0) du bloc zigzag }
Begin
  Zigzag[0] := Value;
End;

Function JPEG_CountNonZeroZigzag(Var Zigzag: TJPEGZigzagBlock): Integer;
{ Compte le nombre total de coefficients non-nuls dans un bloc zigzag }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 0 To 63 Do
    If Zigzag[I] <> 0 Then
      Inc(Count);
  JPEG_CountNonZeroZigzag := Count;
End;

Function JPEG_CountNonZeroACZigzag(Var Zigzag: TJPEGZigzagBlock): Integer;
{ Compte le nombre de coefficients AC non-nuls (indices 1-63) }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To 63 Do  { Exclure DC (indice 0) }
    If Zigzag[I] <> 0 Then
      Inc(Count);
  JPEG_CountNonZeroACZigzag := Count;
End;

Procedure JPEG_ClearZigzagBlock(Var Zigzag: TJPEGZigzagBlock);
{ Met a zero tous les coefficients d'un bloc zigzag }
Var
  I: Integer;
Begin
  For I := 0 To 63 Do
    Zigzag[I] := 0;
End;

Procedure JPEG_CopyZigzagBlock(Var Src, Dest: TJPEGZigzagBlock);
{ Copie un bloc zigzag source vers un bloc destination }
Var
  I: Integer;
Begin
  For I := 0 To 63 Do
    Dest[I] := Src[I];
End;

Function JPEG_IsZigzagInitialized: Boolean;
{ Indique si le module Zigzag est initialise }
Begin
  JPEG_IsZigzagInitialized := JPEG_ZigzagInitialized;
End;

Function JPEG_GetZigzagTableValue(Index: Integer): Integer;
{ Retourne la valeur de la table zigzag a l'indice donne
  (position matricielle pour position zigzag) }
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  If (Index >= 0) And (Index <= 63) Then
    JPEG_GetZigzagTableValue := JPEG_ZigzagTable[Index]
  Else
    JPEG_GetZigzagTableValue := -1;
End;

Function JPEG_GetInvZigzagTableValue(Index: Integer): Integer;
{ Retourne la valeur de la table zigzag inverse a l'indice donne
  (position zigzag pour position matricielle) }
Begin
  If Not JPEG_ZigzagInitialized Then
    JPEG_InitZigzagTable;
  
  If (Index >= 0) And (Index <= 63) Then
    JPEG_GetInvZigzagTableValue := JPEG_InvZigzagTable[Index]
  Else
    JPEG_GetInvZigzagTableValue := -1;
End;

{ ============================================================
  GENERATEUR JPEG INTEGRE - PARTIE 6
  Encodage RLE (Run-Length Encoding) pour les coefficients AC
  ============================================================ }

{ Dans JPEG, les coefficients AC (indices 1-63 du bloc zigzag) sont
  encodes avec un schema RLE qui exploite les longues sequences de zeros.
  
  L'encodage RLE pour JPEG fonctionne ainsi:
  1. On parcourt les coefficients AC en ordre zigzag
  2. Pour chaque coefficient non-nul, on encode:
     - RunLength: nombre de zeros precedant ce coefficient (0-15)
     - Value: la valeur du coefficient
  3. Si plus de 15 zeros consecutifs: symbole ZRL (Zero Run Length)
  4. Apres le dernier coefficient non-nul: symbole EOB (End Of Block)
  
  Format du symbole AC: (RRRRSSSS, Amplitude)
  - RRRR = RunLength (4 bits, 0-15)
  - SSSS = Category/Size (4 bits, 0-10)
  - Amplitude = valeur encodee sur Category bits
  
  Categories de magnitude:
  Cat 0: valeur 0 (pas d'amplitude)
  Cat 1: |val| = 1            (1 bit)
  Cat 2: |val| = 2-3          (2 bits)
  Cat 3: |val| = 4-7          (3 bits)
  Cat 4: |val| = 8-15         (4 bits)
  Cat 5: |val| = 16-31        (5 bits)
  Cat 6: |val| = 32-63        (6 bits)
  Cat 7: |val| = 64-127       (7 bits)
  Cat 8: |val| = 128-255      (8 bits)
  Cat 9: |val| = 256-511      (9 bits)
  Cat 10: |val| = 512-1023    (10 bits)
  
  Symboles speciaux:
  - EOB (End Of Block): (0, 0) = $00 - fin du bloc
  - ZRL (Zero Run Length): (15, 0) = $F0 - 16 zeros consecutifs }

Procedure JPEG_InitRLECategoryTable;
{ Initialise la table de categories pre-calculee
  Pour chaque valeur absolue 0-1023, determine sa categorie (0-10) }
Var
  I, Cat, Threshold: Integer;
Begin
  { Categorie 0: valeur 0 uniquement }
  JPEG_RLECategoryTable[0] := 0;
  
  { Categories 1-10 }
  Threshold := 1;
  For Cat := 1 To 10 Do
  Begin
    { Cat N: valeurs de Threshold a 2*Threshold-1 }
    For I := Threshold To (Threshold * 2) - 1 Do
    Begin
      If I <= 1023 Then
        JPEG_RLECategoryTable[I] := Cat;
    End;
    Threshold := Threshold * 2;
  End;
End;

Procedure JPEG_InitRLE;
{ Initialise le module RLE (table de categories, compteurs) }
Begin
  If Not JPEG_RLEInitialized Then
  Begin
    JPEG_InitRLECategoryTable;
    JPEG_RLEBlockCount := 0;
    JPEG_RLETotalPairs := 0;
    JPEG_RLEInitialized := True;
  End;
End;

Function JPEG_GetACCategory(Value: Integer): Integer;
{ Retourne la categorie de magnitude d'un coefficient AC
  
  Entree:
    Value - Coefficient AC (-1023 a 1023)
  
  Retourne:
    0 si Value = 0
    1-10 selon la magnitude (log2(|Value|) + 1) }
Var
  AbsVal: Integer;
Begin
  If Not JPEG_RLEInitialized Then
    JPEG_InitRLE;
  
  If Value = 0 Then
    JPEG_GetACCategory := 0
  Else
  Begin
    AbsVal := Abs(Value);
    If AbsVal > JPEG_AC_MAX_VALUE Then
      AbsVal := JPEG_AC_MAX_VALUE;  { Saturation }
    JPEG_GetACCategory := JPEG_RLECategoryTable[AbsVal];
  End;
End;

Function JPEG_GetACAmplitude(Value: Integer; Category: Integer): Integer;
{ Calcule l'amplitude encodee pour un coefficient AC
  
  Dans JPEG, les valeurs negatives utilisent le complement a 1:
  - Positif: amplitude = value
  - Negatif: amplitude = value + 2^category - 1
  
  Exemple categorie 3 (valeurs 4-7 ou -7 a -4):
    +4 -> 100, +5 -> 101, +6 -> 110, +7 -> 111
    -4 -> 011, -5 -> 010, -6 -> 001, -7 -> 000 }
Var
  MaxVal: Integer;
Begin
  If Category = 0 Then
    JPEG_GetACAmplitude := 0
  Else If Value >= 0 Then
    JPEG_GetACAmplitude := Value
  Else
  Begin
    { Complement a 1 pour les negatifs }
    MaxVal := 1 Shl Category;  { 2^category }
    JPEG_GetACAmplitude := Value + MaxVal - 1;
  End;
End;

Function JPEG_DecodeACAmplitude(Amplitude, Category: Integer): Integer;
{ Decode une amplitude en valeur de coefficient AC
  (operation inverse de JPEG_GetACAmplitude)
  
  Entree:
    Amplitude - Valeur encodee sur Category bits
    Category - Categorie de magnitude (1-10)
  
  Retourne:
    Valeur du coefficient (-1023 a 1023) }
Var
  HalfRange: Integer;
Begin
  If Category = 0 Then
    JPEG_DecodeACAmplitude := 0
  Else
  Begin
    HalfRange := 1 Shl (Category - 1);  { 2^(category-1) }
    If Amplitude >= HalfRange Then
      JPEG_DecodeACAmplitude := Amplitude
    Else
      JPEG_DecodeACAmplitude := Amplitude - (HalfRange * 2) + 1;
  End;
End;

Procedure JPEG_InitRLEPair(Var Pair: TJPEGRLEPair);
{ Initialise une paire RLE a zero }
Begin
  Pair.RunLength := 0;
  Pair.Value := 0;
  Pair.Category := 0;
  Pair.IsEOB := False;
  Pair.IsZRL := False;
End;

Procedure JPEG_SetRLEPair(Var Pair: TJPEGRLEPair; 
                          Run: Integer; Val: Integer);
{ Initialise une paire RLE avec run-length et valeur
  Calcule automatiquement la categorie }
Begin
  If Run < 0 Then Run := 0;
  If Run > 15 Then Run := 15;
  
  Pair.RunLength := Run;
  Pair.Value := Val;
  Pair.Category := JPEG_GetACCategory(Val);
  Pair.IsEOB := (Run = 0) And (Val = 0);
  Pair.IsZRL := (Run = 15) And (Val = 0);
End;

Procedure JPEG_SetRLEPairEOB(Var Pair: TJPEGRLEPair);
{ Cree une paire EOB (End Of Block) }
Begin
  Pair.RunLength := 0;
  Pair.Value := 0;
  Pair.Category := 0;
  Pair.IsEOB := True;
  Pair.IsZRL := False;
End;

Procedure JPEG_SetRLEPairZRL(Var Pair: TJPEGRLEPair);
{ Cree une paire ZRL (Zero Run Length = 16 zeros) }
Begin
  Pair.RunLength := 15;
  Pair.Value := 0;
  Pair.Category := 0;
  Pair.IsEOB := False;
  Pair.IsZRL := True;
End;

Function JPEG_GetRLESymbol(Var Pair: TJPEGRLEPair): Byte;
{ Retourne le symbole JPEG (RRRRSSSS) pour une paire RLE
  
  RRRR = RunLength (4 bits haut)
  SSSS = Category (4 bits bas) }
Begin
  JPEG_GetRLESymbol := (Pair.RunLength Shl 4) Or Pair.Category;
End;

Procedure JPEG_InitRLEBlock(Var Block: TJPEGRLEBlock);
{ Initialise un bloc RLE vide }
Var
  I: Integer;
Begin
  Block.Count := 0;
  Block.DCValue := 0;
  Block.HasEOB := False;
  
  For I := 0 To 62 Do
    JPEG_InitRLEPair(Block.Pairs[I]);
End;

Procedure JPEG_EncodeACBlock(Var Zigzag: TJPEGZigzagBlock;
                              Var RLEBlock: TJPEGRLEBlock);
{ Encode les coefficients AC d'un bloc zigzag en paires RLE
  
  Entree:
    Zigzag - Bloc de 64 coefficients en ordre zigzag
             (indice 0 = DC, indices 1-63 = AC)
  
  Sortie:
    RLEBlock - Bloc RLE contenant les paires encodees
               et le coefficient DC }
Var
  I, ZeroRun, LastNonZero: Integer;
Begin
  If Not JPEG_RLEInitialized Then
    JPEG_InitRLE;
  
  JPEG_InitRLEBlock(RLEBlock);
  
  { Coefficient DC separe }
  RLEBlock.DCValue := Zigzag[0];
  
  { Trouver le dernier coefficient AC non-nul }
  LastNonZero := 0;
  For I := 63 DownTo 1 Do
  Begin
    If Zigzag[I] <> 0 Then
    Begin
      LastNonZero := I;
      Break;
    End;
  End;
  
  { Si tous les AC sont nuls, juste EOB }
  If LastNonZero = 0 Then
  Begin
    JPEG_SetRLEPairEOB(RLEBlock.Pairs[0]);
    RLEBlock.Count := 1;
    RLEBlock.HasEOB := True;
    Inc(JPEG_RLEBlockCount);
    Inc(JPEG_RLETotalPairs);
    Exit;
  End;
  
  { Encoder les coefficients AC jusqu'au dernier non-nul }
  ZeroRun := 0;
  I := 1;  { Commencer apres le DC }
  
  While I <= LastNonZero Do
  Begin
    If Zigzag[I] = 0 Then
    Begin
      Inc(ZeroRun);
      { Si plus de 15 zeros, emettre ZRL }
      If ZeroRun > 15 Then
      Begin
        JPEG_SetRLEPairZRL(RLEBlock.Pairs[RLEBlock.Count]);
        Inc(RLEBlock.Count);
        Inc(JPEG_RLETotalPairs);
        ZeroRun := ZeroRun - 16;
      End;
    End
    Else
    Begin
      { Coefficient non-nul: encoder avec le run de zeros }
      JPEG_SetRLEPair(RLEBlock.Pairs[RLEBlock.Count], ZeroRun, Zigzag[I]);
      Inc(RLEBlock.Count);
      Inc(JPEG_RLETotalPairs);
      ZeroRun := 0;
    End;
    Inc(I);
  End;
  
  { Ajouter EOB apres le dernier coefficient non-nul }
  If LastNonZero < 63 Then
  Begin
    JPEG_SetRLEPairEOB(RLEBlock.Pairs[RLEBlock.Count]);
    Inc(RLEBlock.Count);
    Inc(JPEG_RLETotalPairs);
    RLEBlock.HasEOB := True;
  End;
  
  Inc(JPEG_RLEBlockCount);
End;

Procedure JPEG_DecodeRLEBlock(Var RLEBlock: TJPEGRLEBlock;
                               Var Zigzag: TJPEGZigzagBlock);
{ Decode un bloc RLE en coefficients zigzag
  (operation inverse de JPEG_EncodeACBlock)
  
  Entree:
    RLEBlock - Bloc RLE avec paires et coefficient DC
  
  Sortie:
    Zigzag - Bloc de 64 coefficients en ordre zigzag }
Var
  I, ZigzagPos, J: Integer;
Begin
  { Initialiser le bloc zigzag a zero }
  For I := 0 To 63 Do
    Zigzag[I] := 0;
  
  { Coefficient DC }
  Zigzag[0] := RLEBlock.DCValue;
  
  { Decoder les paires RLE }
  ZigzagPos := 1;  { Position courante dans le bloc zigzag }
  
  For I := 0 To RLEBlock.Count - 1 Do
  Begin
    If RLEBlock.Pairs[I].IsEOB Then
    Begin
      { EOB: le reste du bloc est deja a zero }
      Break;
    End
    Else If RLEBlock.Pairs[I].IsZRL Then
    Begin
      { ZRL: 16 zeros }
      ZigzagPos := ZigzagPos + 16;
    End
    Else
    Begin
      { Paire normale: RunLength zeros puis Value }
      ZigzagPos := ZigzagPos + RLEBlock.Pairs[I].RunLength;
      If ZigzagPos <= 63 Then
        Zigzag[ZigzagPos] := RLEBlock.Pairs[I].Value;
      Inc(ZigzagPos);
    End;
    
    { Securite: ne pas depasser le bloc }
    If ZigzagPos > 63 Then
      Break;
  End;
End;

Function JPEG_CountRLEPairs(Var RLEBlock: TJPEGRLEBlock): Integer;
{ Retourne le nombre de paires RLE dans un bloc }
Begin
  JPEG_CountRLEPairs := RLEBlock.Count;
End;

Function JPEG_CountRLEZeroPairs(Var RLEBlock: TJPEGRLEBlock): Integer;
{ Compte le nombre de paires ZRL dans un bloc }
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 0 To RLEBlock.Count - 1 Do
    If RLEBlock.Pairs[I].IsZRL Then
      Inc(Count);
  JPEG_CountRLEZeroPairs := Count;
End;

Function JPEG_GetRLEBlockDC(Var RLEBlock: TJPEGRLEBlock): Integer;
{ Retourne le coefficient DC du bloc RLE }
Begin
  JPEG_GetRLEBlockDC := RLEBlock.DCValue;
End;

Procedure JPEG_SetRLEBlockDC(Var RLEBlock: TJPEGRLEBlock; Value: Integer);
{ Modifie le coefficient DC du bloc RLE }
Begin
  RLEBlock.DCValue := Value;
End;

Procedure JPEG_GetRLEStats(Var RLEBlock: TJPEGRLEBlock;
                           Var Stats: TJPEGRLEStats);
{ Calcule les statistiques d'un bloc RLE }
Var
  I, Run, Cat: Integer;
Begin
  Stats.TotalPairs := RLEBlock.Count;
  Stats.ZRLCount := 0;
  Stats.EOBCount := 0;
  Stats.MaxRunLength := 0;
  Stats.MaxCategory := 0;
  Stats.NonZeroCount := 0;
  
  For I := 0 To RLEBlock.Count - 1 Do
  Begin
    If RLEBlock.Pairs[I].IsZRL Then
      Inc(Stats.ZRLCount)
    Else If RLEBlock.Pairs[I].IsEOB Then
      Inc(Stats.EOBCount)
    Else
    Begin
      Inc(Stats.NonZeroCount);
      
      Run := RLEBlock.Pairs[I].RunLength;
      If Run > Stats.MaxRunLength Then
        Stats.MaxRunLength := Run;
      
      Cat := RLEBlock.Pairs[I].Category;
      If Cat > Stats.MaxCategory Then
        Stats.MaxCategory := Cat;
    End;
  End;
End;

Function JPEG_EstimateRLEBits(Var RLEBlock: TJPEGRLEBlock): Integer;
{ Estime le nombre de bits necessaires pour encoder un bloc RLE
  (sans compter le coefficient DC)
  
  Note: Ceci est une estimation simplifiee qui ne tient pas compte
  de l'encodage Huffman reel. Elle suppose que chaque symbole
  prend environ 8 bits + les bits d'amplitude. }
Var
  I, TotalBits: Integer;
Begin
  TotalBits := 0;
  
  For I := 0 To RLEBlock.Count - 1 Do
  Begin
    If RLEBlock.Pairs[I].IsEOB Then
      TotalBits := TotalBits + 4    { EOB: code court }
    Else If RLEBlock.Pairs[I].IsZRL Then
      TotalBits := TotalBits + 8    { ZRL: symbole seul }
    Else
      { Symbole (8 bits environ) + amplitude (category bits) }
      TotalBits := TotalBits + 8 + RLEBlock.Pairs[I].Category;
  End;
  
  JPEG_EstimateRLEBits := TotalBits;
End;

Procedure JPEG_CopyRLEBlock(Var Src, Dest: TJPEGRLEBlock);
{ Copie un bloc RLE source vers un bloc destination }
Var
  I: Integer;
Begin
  Dest.Count := Src.Count;
  Dest.DCValue := Src.DCValue;
  Dest.HasEOB := Src.HasEOB;
  
  For I := 0 To Src.Count - 1 Do
    Dest.Pairs[I] := Src.Pairs[I];
End;

Procedure JPEG_ClearRLEStats;
{ Remet a zero les compteurs globaux RLE }
Begin
  JPEG_RLEBlockCount := 0;
  JPEG_RLETotalPairs := 0;
End;

{ === Fonctions d'acces pour le module RLE === }

Function JPEG_IsRLEInitialized: Boolean;
{ Indique si le module RLE est initialise }
Begin
  JPEG_IsRLEInitialized := JPEG_RLEInitialized;
End;

Function JPEG_GetRLEBlockCount: Integer;
{ Retourne le nombre total de blocs encodes }
Begin
  JPEG_GetRLEBlockCount := JPEG_RLEBlockCount;
End;

Function JPEG_GetRLETotalPairs: Integer;
{ Retourne le nombre total de paires RLE generees }
Begin
  JPEG_GetRLETotalPairs := JPEG_RLETotalPairs;
End;

Function JPEG_GetRLEMaxPairs: Integer;
{ Retourne le nombre maximum de paires par bloc }
Begin
  JPEG_GetRLEMaxPairs := JPEG_RLE_MAX_PAIRS;
End;

Function JPEG_GetRLEMaxRunLength: Integer;
{ Retourne le run-length maximum (15) }
Begin
  JPEG_GetRLEMaxRunLength := JPEG_RLE_ZRL_RUNLENGTH;
End;

Function JPEG_GetRLEMaxCategory: Integer;
{ Retourne la categorie maximum (10) }
Begin
  JPEG_GetRLEMaxCategory := JPEG_AC_CAT_MAX;
End;

Function JPEG_GetRLEMaxACValue: Integer;
{ Retourne la valeur AC maximale encodable (1023) }
Begin
  JPEG_GetRLEMaxACValue := JPEG_AC_MAX_VALUE;
End;

Function JPEG_GetRLECategoryForValue(Value: Integer): Integer;
{ Retourne la categorie pour une valeur donnee }
Begin
  JPEG_GetRLECategoryForValue := JPEG_GetACCategory(Value);
End;

Function JPEG_IsRLEPairEOB(Var Pair: TJPEGRLEPair): Boolean;
{ Indique si une paire est un symbole EOB }
Begin
  JPEG_IsRLEPairEOB := Pair.IsEOB;
End;

Function JPEG_IsRLEPairZRL(Var Pair: TJPEGRLEPair): Boolean;
{ Indique si une paire est un symbole ZRL }
Begin
  JPEG_IsRLEPairZRL := Pair.IsZRL;
End;

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 7
   Procedures pour l'encodeur Huffman bit par bit
  ============================================================ }

Procedure JPEG_InitBitWriter;
{ Initialise le buffer de bits pour l'ecriture }
Begin
  JPEG_BitBuffer.Buffer := 0;
  JPEG_BitBuffer.BitCount := 0;
  JPEG_BitBuffer.ByteCount := 0;
  JPEG_BitBuffer.TotalBits := 0;
  JPEG_BitBuffer.TotalBytes := 0;
  
  JPEG_HuffStats.DCCodesWritten := 0;
  JPEG_HuffStats.ACCodesWritten := 0;
  JPEG_HuffStats.StuffBytesAdded := 0;
  JPEG_HuffStats.TotalBitsWritten := 0;
  JPEG_HuffStats.TotalBytesOutput := 0;
End;

Procedure JPEG_BuildHuffCodeTable(Var Bits: TJPEGHuffBits; 
                                   Var Values: Array Of Byte;
                                   ValueCount: Integer;
                                   Var CodeTable: TJPEGHuffCodeTable);
{ Construit une table de codes Huffman a partir de BITS et VALUES }
{ Algorithme: generer les codes canoniques de Huffman }
Var
  I, J, K, Idx: Integer;
  Code: Word;
  Symbol: Byte;
Begin
  { Initialiser la table avec des codes invalides }
  For I := 0 To 255 Do
  Begin
    CodeTable[I].Code := 0;
    CodeTable[I].Length := 0;
  End;
  
  { Generer les codes canoniques }
  Code := 0;
  Idx := 0;
  
  For I := 0 To 15 Do  { Pour chaque longueur de 1 a 16 bits }
  Begin
    For J := 0 To Bits[I] - 1 Do  { Pour chaque code de cette longueur }
    Begin
      If Idx < ValueCount Then
      Begin
        Symbol := Values[Idx];
        CodeTable[Symbol].Code := Code;
        CodeTable[Symbol].Length := I + 1;
        Inc(Code);
        Inc(Idx);
      End;
    End;
    Code := Code Shl 1;  { Decaler pour la longueur suivante }
  End;
End;

Procedure JPEG_InitHuffmanTables;
{ Initialise les tables de codes Huffman a partir des tables standard }
Var
  DCLumBits: TJPEGHuffBits;
  DCLumVals: Array[0..11] Of Byte;
  DCChrBits: TJPEGHuffBits;
  DCChrVals: Array[0..11] Of Byte;
  ACLumBits: TJPEGHuffBits;
  ACLumVals: Array[0..161] Of Byte;
  ACChrBits: TJPEGHuffBits;
  ACChrVals: Array[0..161] Of Byte;
  I: Integer;
Begin
  { Copier les tables de bits DC luminance }
  DCLumBits[0] := JPEG_DC_LUM_BITS_00; DCLumBits[1] := JPEG_DC_LUM_BITS_01;
  DCLumBits[2] := JPEG_DC_LUM_BITS_02; DCLumBits[3] := JPEG_DC_LUM_BITS_03;
  DCLumBits[4] := JPEG_DC_LUM_BITS_04; DCLumBits[5] := JPEG_DC_LUM_BITS_05;
  DCLumBits[6] := JPEG_DC_LUM_BITS_06; DCLumBits[7] := JPEG_DC_LUM_BITS_07;
  DCLumBits[8] := JPEG_DC_LUM_BITS_08; DCLumBits[9] := JPEG_DC_LUM_BITS_09;
  DCLumBits[10] := JPEG_DC_LUM_BITS_10; DCLumBits[11] := JPEG_DC_LUM_BITS_11;
  DCLumBits[12] := JPEG_DC_LUM_BITS_12; DCLumBits[13] := JPEG_DC_LUM_BITS_13;
  DCLumBits[14] := JPEG_DC_LUM_BITS_14; DCLumBits[15] := JPEG_DC_LUM_BITS_15;
  
  { Valeurs DC luminance }
  DCLumVals[0] := JPEG_DC_LUM_VAL_00; DCLumVals[1] := JPEG_DC_LUM_VAL_01;
  DCLumVals[2] := JPEG_DC_LUM_VAL_02; DCLumVals[3] := JPEG_DC_LUM_VAL_03;
  DCLumVals[4] := JPEG_DC_LUM_VAL_04; DCLumVals[5] := JPEG_DC_LUM_VAL_05;
  DCLumVals[6] := JPEG_DC_LUM_VAL_06; DCLumVals[7] := JPEG_DC_LUM_VAL_07;
  DCLumVals[8] := JPEG_DC_LUM_VAL_08; DCLumVals[9] := JPEG_DC_LUM_VAL_09;
  DCLumVals[10] := JPEG_DC_LUM_VAL_10; DCLumVals[11] := JPEG_DC_LUM_VAL_11;
  
  { Copier les tables de bits DC chrominance }
  DCChrBits[0] := JPEG_DC_CHR_BITS_00; DCChrBits[1] := JPEG_DC_CHR_BITS_01;
  DCChrBits[2] := JPEG_DC_CHR_BITS_02; DCChrBits[3] := JPEG_DC_CHR_BITS_03;
  DCChrBits[4] := JPEG_DC_CHR_BITS_04; DCChrBits[5] := JPEG_DC_CHR_BITS_05;
  DCChrBits[6] := JPEG_DC_CHR_BITS_06; DCChrBits[7] := JPEG_DC_CHR_BITS_07;
  DCChrBits[8] := JPEG_DC_CHR_BITS_08; DCChrBits[9] := JPEG_DC_CHR_BITS_09;
  DCChrBits[10] := JPEG_DC_CHR_BITS_10; DCChrBits[11] := JPEG_DC_CHR_BITS_11;
  DCChrBits[12] := JPEG_DC_CHR_BITS_12; DCChrBits[13] := JPEG_DC_CHR_BITS_13;
  DCChrBits[14] := JPEG_DC_CHR_BITS_14; DCChrBits[15] := JPEG_DC_CHR_BITS_15;
  
  { Valeurs DC chrominance }
  DCChrVals[0] := JPEG_DC_CHR_VAL_00; DCChrVals[1] := JPEG_DC_CHR_VAL_01;
  DCChrVals[2] := JPEG_DC_CHR_VAL_02; DCChrVals[3] := JPEG_DC_CHR_VAL_03;
  DCChrVals[4] := JPEG_DC_CHR_VAL_04; DCChrVals[5] := JPEG_DC_CHR_VAL_05;
  DCChrVals[6] := JPEG_DC_CHR_VAL_06; DCChrVals[7] := JPEG_DC_CHR_VAL_07;
  DCChrVals[8] := JPEG_DC_CHR_VAL_08; DCChrVals[9] := JPEG_DC_CHR_VAL_09;
  DCChrVals[10] := JPEG_DC_CHR_VAL_10; DCChrVals[11] := JPEG_DC_CHR_VAL_11;
  
  { Construire les tables de codes }
  JPEG_BuildHuffCodeTable(DCLumBits, DCLumVals, 12, JPEG_DC_Lum_Codes);
  JPEG_BuildHuffCodeTable(DCChrBits, DCChrVals, 12, JPEG_DC_Chr_Codes);
  
  { Pour AC, utiliser des valeurs par defaut (simplifiees) }
  For I := 0 To 15 Do
  Begin
    ACLumBits[I] := 0;
    ACChrBits[I] := 0;
  End;
  { Configuration AC simplifiee - en pratique, copier les constantes AC }
  ACLumBits[0] := 0; ACLumBits[1] := 2; ACLumBits[2] := 1; ACLumBits[3] := 3;
  ACLumBits[4] := 3; ACLumBits[5] := 2; ACLumBits[6] := 4; ACLumBits[7] := 3;
  
  { Initialiser les codes AC (simplifie) }
  For I := 0 To 161 Do
  Begin
    ACLumVals[I] := I Mod 256;
    ACChrVals[I] := I Mod 256;
  End;
  
  { Note: Pour une implementation complete, copier toutes les valeurs AC }
  JPEG_BuildHuffCodeTable(ACLumBits, ACLumVals, 162, JPEG_AC_Lum_Codes);
  JPEG_BuildHuffCodeTable(ACChrBits, ACChrVals, 162, JPEG_AC_Chr_Codes);
End;

Procedure JPEG_InitHuffman;
{ Initialise completement le module Huffman }
Begin
  JPEG_InitBitWriter;
  JPEG_InitHuffmanTables;
  JPEG_HuffInitialized := True;
End;

Procedure JPEG_WriteBitToBuffer(Bit: Integer);
{ Ecrit un seul bit dans le buffer }
Begin
  JPEG_BitBuffer.Buffer := (JPEG_BitBuffer.Buffer Shl 1) Or (Bit And 1);
  Inc(JPEG_BitBuffer.BitCount);
  Inc(JPEG_BitBuffer.TotalBits);
  
  { Si on a 8 bits, ecrire l'octet }
  If JPEG_BitBuffer.BitCount >= 8 Then
  Begin
    If JPEG_BitBuffer.ByteCount < JPEG_BIT_BUFFER_SIZE Then
    Begin
      JPEG_BitBuffer.ByteBuffer[JPEG_BitBuffer.ByteCount] := 
        JPEG_BitBuffer.Buffer And $FF;
      Inc(JPEG_BitBuffer.ByteCount);
      Inc(JPEG_BitBuffer.TotalBytes);
      
      { Byte stuffing: si $FF, ajouter $00 }
      If (JPEG_BitBuffer.Buffer And $FF) = $FF Then
      Begin
        If JPEG_BitBuffer.ByteCount < JPEG_BIT_BUFFER_SIZE Then
        Begin
          JPEG_BitBuffer.ByteBuffer[JPEG_BitBuffer.ByteCount] := $00;
          Inc(JPEG_BitBuffer.ByteCount);
          Inc(JPEG_BitBuffer.TotalBytes);
          Inc(JPEG_HuffStats.StuffBytesAdded);
        End;
      End;
    End;
    JPEG_BitBuffer.Buffer := 0;
    JPEG_BitBuffer.BitCount := 0;
  End;
End;

Procedure JPEG_WriteBits(Value: Word; NumBits: Integer);
{ Ecrit plusieurs bits dans le buffer (MSB first) }
Var
  I: Integer;
  Mask: Word;
Begin
  If NumBits <= 0 Then Exit;
  If NumBits > 16 Then NumBits := 16;
  
  { Ecrire du bit le plus significatif au moins significatif }
  Mask := 1 Shl (NumBits - 1);
  For I := 0 To NumBits - 1 Do
  Begin
    If (Value And Mask) <> 0 Then
      JPEG_WriteBitToBuffer(1)
    Else
      JPEG_WriteBitToBuffer(0);
    Mask := Mask Shr 1;
  End;
  
  Inc(JPEG_HuffStats.TotalBitsWritten, NumBits);
End;

Procedure JPEG_FlushBits;
{ Vide le buffer de bits en completant avec des 1 }
Begin
  While JPEG_BitBuffer.BitCount > 0 Do
    JPEG_WriteBitToBuffer(1);
End;

Function JPEG_GetDCCategory(Value: Integer): Integer;
{ Retourne la categorie pour une difference DC }
Var
  AbsVal: Integer;
  Cat: Integer;
Begin
  If Value < 0 Then AbsVal := -Value Else AbsVal := Value;
  
  Cat := 0;
  While AbsVal > 0 Do
  Begin
    AbsVal := AbsVal Shr 1;
    Inc(Cat);
  End;
  
  If Cat > 11 Then Cat := 11;
  JPEG_GetDCCategory := Cat;
End;

Function JPEG_GetDCAmplitude(Value: Integer; Category: Integer): Word;
{ Retourne l'amplitude encodee pour une difference DC }
Begin
  If Value >= 0 Then
    JPEG_GetDCAmplitude := Value
  Else
    JPEG_GetDCAmplitude := Value + (1 Shl Category) - 1;
End;

Procedure JPEG_EncodeDCCoeff(Value: Integer; IsLuminance: Boolean;
                             Var PrevDC: Integer);
{ Encode un coefficient DC avec codage differentiel et Huffman }
Var
  Diff, Category: Integer;
  Amplitude: Word;
  HuffCode: TJPEGHuffCode;
Begin
  { Calculer la difference DPCM }
  Diff := Value - PrevDC;
  PrevDC := Value;
  
  { Obtenir la categorie }
  Category := JPEG_GetDCCategory(Diff);
  
  { Ecrire le code Huffman pour la categorie }
  If IsLuminance Then
    HuffCode := JPEG_DC_Lum_Codes[Category]
  Else
    HuffCode := JPEG_DC_Chr_Codes[Category];
    
  If HuffCode.Length > 0 Then
    JPEG_WriteBits(HuffCode.Code, HuffCode.Length);
  
  { Ecrire l'amplitude si categorie > 0 }
  If Category > 0 Then
  Begin
    Amplitude := JPEG_GetDCAmplitude(Diff, Category);
    JPEG_WriteBits(Amplitude, Category);
  End;
  
  Inc(JPEG_HuffStats.DCCodesWritten);
End;

Procedure JPEG_EncodeACCoeff(RunLength: Integer; Value: Integer;
                             IsLuminance: Boolean);
{ Encode un coefficient AC avec son run-length et Huffman }
Var
  Category: Integer;
  Symbol: Byte;
  Amplitude: Word;
  HuffCode: TJPEGHuffCode;
Begin
  { Obtenir la categorie de la valeur }
  Category := JPEG_GetACCategory(Value);
  
  { Le symbole combine RunLength (4 bits haut) et Category (4 bits bas) }
  Symbol := (RunLength Shl 4) Or Category;
  
  { Ecrire le code Huffman pour le symbole }
  If IsLuminance Then
    HuffCode := JPEG_AC_Lum_Codes[Symbol]
  Else
    HuffCode := JPEG_AC_Chr_Codes[Symbol];
    
  If HuffCode.Length > 0 Then
    JPEG_WriteBits(HuffCode.Code, HuffCode.Length);
  
  { Ecrire l'amplitude si categorie > 0 }
  If Category > 0 Then
  Begin
    Amplitude := JPEG_GetACAmplitude(Value, Category);
    JPEG_WriteBits(Amplitude, Category);
  End;
  
  Inc(JPEG_HuffStats.ACCodesWritten);
End;

Procedure JPEG_EncodeEOB(IsLuminance: Boolean);
{ Encode un symbole End-Of-Block }
Var
  HuffCode: TJPEGHuffCode;
Begin
  { EOB = symbole (0, 0) }
  If IsLuminance Then
    HuffCode := JPEG_AC_Lum_Codes[0]
  Else
    HuffCode := JPEG_AC_Chr_Codes[0];
    
  If HuffCode.Length > 0 Then
    JPEG_WriteBits(HuffCode.Code, HuffCode.Length);
    
  Inc(JPEG_HuffStats.ACCodesWritten);
End;

Procedure JPEG_EncodeZRL(IsLuminance: Boolean);
{ Encode un symbole Zero-Run-Length (16 zeros) }
Var
  HuffCode: TJPEGHuffCode;
Begin
  { ZRL = symbole (15, 0) = $F0 }
  If IsLuminance Then
    HuffCode := JPEG_AC_Lum_Codes[$F0]
  Else
    HuffCode := JPEG_AC_Chr_Codes[$F0];
    
  If HuffCode.Length > 0 Then
    JPEG_WriteBits(HuffCode.Code, HuffCode.Length);
    
  Inc(JPEG_HuffStats.ACCodesWritten);
End;

Procedure JPEG_EncodeRLEBlockHuffman(Var RLEBlock: TJPEGRLEBlock;
                                      IsLuminance: Boolean;
                                      Var PrevDC: Integer);
{ Encode un bloc RLE complet avec Huffman }
Var
  I: Integer;
Begin
  { Encoder le coefficient DC }
  JPEG_EncodeDCCoeff(RLEBlock.DCValue, IsLuminance, PrevDC);
  
  { Encoder les paires AC }
  For I := 0 To RLEBlock.Count - 1 Do
  Begin
    If RLEBlock.Pairs[I].IsEOB Then
      JPEG_EncodeEOB(IsLuminance)
    Else If RLEBlock.Pairs[I].IsZRL Then
      JPEG_EncodeZRL(IsLuminance)
    Else
      JPEG_EncodeACCoeff(RLEBlock.Pairs[I].RunLength,
                         RLEBlock.Pairs[I].Value, IsLuminance);
  End;
End;

Function JPEG_GetBitBufferSize: Integer;
{ Retourne le nombre d'octets dans le buffer }
Begin
  JPEG_GetBitBufferSize := JPEG_BitBuffer.ByteCount;
End;

Function JPEG_GetTotalBitsWritten: LongInt;
{ Retourne le total de bits ecrits }
Begin
  JPEG_GetTotalBitsWritten := JPEG_HuffStats.TotalBitsWritten;
End;

{ === Fonctions d'acces pour le module Huffman (Partie 7) === }

Function JPEG_IsHuffmanInitialized: Boolean;
Begin
  JPEG_IsHuffmanInitialized := JPEG_HuffInitialized;
End;

Function JPEG_GetHuffDCCodesWritten: LongInt;
Begin
  JPEG_GetHuffDCCodesWritten := JPEG_HuffStats.DCCodesWritten;
End;

Function JPEG_GetHuffACCodesWritten: LongInt;
Begin
  JPEG_GetHuffACCodesWritten := JPEG_HuffStats.ACCodesWritten;
End;

Function JPEG_GetHuffStuffBytes: LongInt;
Begin
  JPEG_GetHuffStuffBytes := JPEG_HuffStats.StuffBytesAdded;
End;

Function JPEG_GetHuffTotalBits: LongInt;
Begin
  JPEG_GetHuffTotalBits := JPEG_HuffStats.TotalBitsWritten;
End;

Function JPEG_GetHuffTotalBytes: LongInt;
Begin
  JPEG_GetHuffTotalBytes := JPEG_BitBuffer.TotalBytes;
End;

Function JPEG_GetHuffBufferCount: Integer;
Begin
  JPEG_GetHuffBufferCount := JPEG_BitBuffer.ByteCount;
End;

Function JPEG_GetHuffMaxCodeLen: Integer;
Begin
  JPEG_GetHuffMaxCodeLen := JPEG_HUFF_MAX_CODE_LEN;
End;

Function JPEG_GetHuffMaxCodes: Integer;
Begin
  JPEG_GetHuffMaxCodes := JPEG_HUFF_MAX_CODES;
End;

Function JPEG_GetHuffBufferByte(Index: Integer): Byte;
Begin
  If (Index >= 0) And (Index < JPEG_BitBuffer.ByteCount) Then
    JPEG_GetHuffBufferByte := JPEG_BitBuffer.ByteBuffer[Index]
  Else
    JPEG_GetHuffBufferByte := 0;
End;

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 8
   Procedures pour la conversion couleur RGB vers YCbCr
  ============================================================ }

Procedure JPEG_InitColorConversion;
{ Initialise le module de conversion couleur }
Begin
  JPEG_ColorStats.PixelsConverted := 0;
  JPEG_ColorStats.BlocksConverted := 0;
  JPEG_ColorStats.ClippedY := 0;
  JPEG_ColorStats.ClippedCb := 0;
  JPEG_ColorStats.ClippedCr := 0;
  JPEG_ColorConvCount := 0;
  JPEG_ColorInitialized := True;
End;

Function JPEG_ClampByte(Value: Integer): Byte;
{ Limite une valeur a l'intervalle [0, 255] }
Begin
  If Value < 0 Then
    JPEG_ClampByte := 0
  Else If Value > 255 Then
    JPEG_ClampByte := 255
  Else
    JPEG_ClampByte := Value;
End;

Procedure JPEG_RGB_to_YCbCr_Pixel(R, G, B: Byte; Var Y, Cb, Cr: Byte);
{ Convertit un pixel RGB en YCbCr selon ITU-R BT.601 }
Var
  YVal, CbVal, CrVal: Real;
  YInt, CbInt, CrInt: Integer;
Begin
  { Calculer Y (luminance) }
  YVal := JPEG_RGB_Y_R * R + JPEG_RGB_Y_G * G + JPEG_RGB_Y_B * B;
  
  { Calculer Cb (chrominance bleue) }
  CbVal := JPEG_CHROMA_OFFSET + JPEG_RGB_CB_R * R + 
           JPEG_RGB_CB_G * G + JPEG_RGB_CB_B * B;
  
  { Calculer Cr (chrominance rouge) }
  CrVal := JPEG_CHROMA_OFFSET + JPEG_RGB_CR_R * R + 
           JPEG_RGB_CR_G * G + JPEG_RGB_CR_B * B;
  
  { Arrondir et limiter }
  YInt := Round(YVal);
  CbInt := Round(CbVal);
  CrInt := Round(CrVal);
  
  { Compter les valeurs ecretees }
  If (YInt < 0) Or (YInt > 255) Then Inc(JPEG_ColorStats.ClippedY);
  If (CbInt < 0) Or (CbInt > 255) Then Inc(JPEG_ColorStats.ClippedCb);
  If (CrInt < 0) Or (CrInt > 255) Then Inc(JPEG_ColorStats.ClippedCr);
  
  Y := JPEG_ClampByte(YInt);
  Cb := JPEG_ClampByte(CbInt);
  Cr := JPEG_ClampByte(CrInt);
  
  Inc(JPEG_ColorStats.PixelsConverted);
End;

Procedure JPEG_YCbCr_to_RGB_Pixel(Y, Cb, Cr: Byte; Var R, G, B: Byte);
{ Convertit un pixel YCbCr en RGB (inverse) }
Var
  RVal, GVal, BVal: Real;
  CbShift, CrShift: Real;
Begin
  CbShift := Cb - JPEG_CHROMA_OFFSET;
  CrShift := Cr - JPEG_CHROMA_OFFSET;
  
  { R = Y + 1.402 * Cr }
  RVal := Y + 1.402 * CrShift;
  
  { G = Y - 0.344 * Cb - 0.714 * Cr }
  GVal := Y - 0.344 * CbShift - 0.714 * CrShift;
  
  { B = Y + 1.772 * Cb }
  BVal := Y + 1.772 * CbShift;
  
  R := JPEG_ClampByte(Round(RVal));
  G := JPEG_ClampByte(Round(GVal));
  B := JPEG_ClampByte(Round(BVal));
End;

Procedure JPEG_RGB_to_YCbCr_Block(Var RGBBlock: TJPEGRGBBlock;
                                   Var YBlock, CbBlock, CrBlock: TJPEGComponentBlock);
{ Convertit un bloc 8x8 RGB en 3 blocs de composantes Y, Cb, Cr }
Var
  I, J: Integer;
  Y, Cb, Cr: Byte;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      JPEG_RGB_to_YCbCr_Pixel(RGBBlock[I, J].R,
                               RGBBlock[I, J].G,
                               RGBBlock[I, J].B,
                               Y, Cb, Cr);
      YBlock[I, J] := Y;
      CbBlock[I, J] := Cb;
      CrBlock[I, J] := Cr;
    End;
  
  Inc(JPEG_ColorStats.BlocksConverted);
End;

Procedure JPEG_YCbCr_to_RGB_Block(Var YBlock, CbBlock, CrBlock: TJPEGComponentBlock;
                                   Var RGBBlock: TJPEGRGBBlock);
{ Convertit 3 blocs de composantes Y, Cb, Cr en un bloc RGB }
Var
  I, J: Integer;
  R, G, B: Byte;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      JPEG_YCbCr_to_RGB_Pixel(YBlock[I, J],
                               CbBlock[I, J],
                               CrBlock[I, J],
                               R, G, B);
      RGBBlock[I, J].R := R;
      RGBBlock[I, J].G := G;
      RGBBlock[I, J].B := B;
    End;
End;

Procedure JPEG_ComponentBlockToPixelBlock(Var CompBlock: TJPEGComponentBlock;
                                           Var PixelBlock: TJPEGPixelBlock;
                                           CenterValues: Boolean);
{ Convertit un bloc de composante en bloc de pixels pour DCT }
{ CenterValues = True: soustrait 128 pour centrer autour de 0 }
Var
  I, J: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      If CenterValues Then
        PixelBlock[I, J] := CompBlock[I, J] - JPEG_LEVEL_SHIFT
      Else
        PixelBlock[I, J] := CompBlock[I, J];
    End;
End;

Procedure JPEG_PixelBlockToComponentBlock(Var PixelBlock: TJPEGPixelBlock;
                                           Var CompBlock: TJPEGComponentBlock;
                                           UncenterValues: Boolean);
{ Convertit un bloc de pixels en bloc de composante }
{ UncenterValues = True: ajoute 128 pour decentrer }
Var
  I, J: Integer;
  Val: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      If UncenterValues Then
        Val := PixelBlock[I, J] + JPEG_LEVEL_SHIFT
      Else
        Val := PixelBlock[I, J];
      CompBlock[I, J] := JPEG_ClampByte(Val);
    End;
End;

{ === Fonctions d'acces pour le module couleur (Partie 8) === }

Function JPEG_IsColorInitialized: Boolean;
Begin
  JPEG_IsColorInitialized := JPEG_ColorInitialized;
End;

Function JPEG_GetColorPixelsConverted: LongInt;
Begin
  JPEG_GetColorPixelsConverted := JPEG_ColorStats.PixelsConverted;
End;

Function JPEG_GetColorBlocksConverted: LongInt;
Begin
  JPEG_GetColorBlocksConverted := JPEG_ColorStats.BlocksConverted;
End;

Function JPEG_GetColorClippedY: LongInt;
Begin
  JPEG_GetColorClippedY := JPEG_ColorStats.ClippedY;
End;

Function JPEG_GetColorClippedCb: LongInt;
Begin
  JPEG_GetColorClippedCb := JPEG_ColorStats.ClippedCb;
End;

Function JPEG_GetColorClippedCr: LongInt;
Begin
  JPEG_GetColorClippedCr := JPEG_ColorStats.ClippedCr;
End;

Function JPEG_GetColorChromaOffset: Integer;
Begin
  JPEG_GetColorChromaOffset := JPEG_CHROMA_OFFSET;
End;

Function JPEG_GetColorCompMin: Integer;
Begin
  JPEG_GetColorCompMin := JPEG_COMP_MIN;
End;

Function JPEG_GetColorCompMax: Integer;
Begin
  JPEG_GetColorCompMax := JPEG_COMP_MAX;
End;

Function JPEG_GetColorConvCount: LongInt;
Begin
  JPEG_GetColorConvCount := JPEG_ColorConvCount;
End;

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 9
   Procedures pour le sous-echantillonnage chromatique
  ============================================================ }

Procedure JPEG_InitSubsampling(Mode: Integer);
{ Initialise le module de sous-echantillonnage }
Begin
  JPEG_SubsampConfig.Mode := Mode;
  
  Case Mode Of
    JPEG_SUBSAMP_444:
    Begin
      JPEG_SubsampConfig.HorizFactor := JPEG_SAMP_H_444;
      JPEG_SubsampConfig.VertFactor := JPEG_SAMP_V_444;
      JPEG_SubsampConfig.MCUWidth := JPEG_MCU_SIZE_444;
      JPEG_SubsampConfig.MCUHeight := JPEG_MCU_SIZE_444;
      JPEG_SubsampConfig.YBlocksPerMCU := 1;
    End;
    JPEG_SUBSAMP_420:
    Begin
      JPEG_SubsampConfig.HorizFactor := JPEG_SAMP_H_420;
      JPEG_SubsampConfig.VertFactor := JPEG_SAMP_V_420;
      JPEG_SubsampConfig.MCUWidth := JPEG_MCU_SIZE_420;
      JPEG_SubsampConfig.MCUHeight := JPEG_MCU_SIZE_420;
      JPEG_SubsampConfig.YBlocksPerMCU := 4;
    End;
  Else
    { Par defaut: 4:4:4 }
    JPEG_SubsampConfig.HorizFactor := 1;
    JPEG_SubsampConfig.VertFactor := 1;
    JPEG_SubsampConfig.MCUWidth := 8;
    JPEG_SubsampConfig.MCUHeight := 8;
    JPEG_SubsampConfig.YBlocksPerMCU := 1;
  End;
  
  JPEG_SubsampStats.MCUsProcessed := 0;
  JPEG_SubsampStats.YBlocksOutput := 0;
  JPEG_SubsampStats.CbBlocksOutput := 0;
  JPEG_SubsampStats.CrBlocksOutput := 0;
  
  JPEG_SubsampInitialized := True;
End;

Procedure JPEG_Subsample420_Block(Var SrcCb, SrcCr: Array Of TJPEGComponentBlock;
                                   Var DstCb, DstCr: TJPEGComponentBlock);
{ Sous-echantillonne 4 blocs Cb/Cr en 1 bloc (moyenne 2x2) }
{ SrcCb/Cr[0..3] = 4 blocs 8x8, DstCb/Cr = 1 bloc 8x8 resultant }
Var
  I, J, SrcI, SrcJ, BlkIdx: Integer;
  Sum: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      { Position dans la grille 2x2 de blocs }
      BlkIdx := ((I Div 4) * 2) + (J Div 4);
      SrcI := (I Mod 4) * 2;
      SrcJ := (J Mod 4) * 2;
      
      { Moyenne des 4 pixels correspondants pour Cb }
      Sum := SrcCb[BlkIdx, SrcI, SrcJ] +
             SrcCb[BlkIdx, SrcI, SrcJ + 1] +
             SrcCb[BlkIdx, SrcI + 1, SrcJ] +
             SrcCb[BlkIdx, SrcI + 1, SrcJ + 1];
      DstCb[I, J] := (Sum + 2) Div 4;  { +2 pour arrondi }
      
      { Moyenne pour Cr }
      Sum := SrcCr[BlkIdx, SrcI, SrcJ] +
             SrcCr[BlkIdx, SrcI, SrcJ + 1] +
             SrcCr[BlkIdx, SrcI + 1, SrcJ] +
             SrcCr[BlkIdx, SrcI + 1, SrcJ + 1];
      DstCr[I, J] := (Sum + 2) Div 4;
    End;
  
  Inc(JPEG_SubsampStats.CbBlocksOutput);
  Inc(JPEG_SubsampStats.CrBlocksOutput);
End;

Procedure JPEG_Upsample420_Block(Var SrcCb, SrcCr: TJPEGComponentBlock;
                                  Var DstCb, DstCr: Array Of TJPEGComponentBlock);
{ Sur-echantillonne 1 bloc Cb/Cr en 4 blocs (duplication) }
Var
  I, J, DstI, DstJ, BlkIdx: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      { Dupliquer chaque pixel dans une zone 2x2 de la destination }
      For BlkIdx := 0 To 3 Do
      Begin
        DstI := (I Mod 4) * 2 + ((BlkIdx Div 2) * 4);
        DstJ := (J Mod 4) * 2 + ((BlkIdx Mod 2) * 4);
        
        If (DstI < 8) And (DstJ < 8) Then
        Begin
          DstCb[BlkIdx, DstI, DstJ] := SrcCb[I, J];
          DstCr[BlkIdx, DstI, DstJ] := SrcCr[I, J];
        End;
      End;
    End;
End;

Procedure JPEG_CreateMCU444(Var YBlock, CbBlock, CrBlock: TJPEGComponentBlock;
                            Var MCU: TJPEGMCU444);
{ Cree un MCU 4:4:4 a partir de 3 blocs de composantes }
Var
  I, J: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      MCU.Y[I, J] := YBlock[I, J];
      MCU.Cb[I, J] := CbBlock[I, J];
      MCU.Cr[I, J] := CrBlock[I, J];
    End;
  
  Inc(JPEG_SubsampStats.MCUsProcessed);
  Inc(JPEG_SubsampStats.YBlocksOutput);
  Inc(JPEG_SubsampStats.CbBlocksOutput);
  Inc(JPEG_SubsampStats.CrBlocksOutput);
End;

Procedure JPEG_ExtractMCU444(Var MCU: TJPEGMCU444;
                              Var YBlock, CbBlock, CrBlock: TJPEGComponentBlock);
{ Extrait les 3 blocs d'un MCU 4:4:4 }
Var
  I, J: Integer;
Begin
  For I := 0 To 7 Do
    For J := 0 To 7 Do
    Begin
      YBlock[I, J] := MCU.Y[I, J];
      CbBlock[I, J] := MCU.Cb[I, J];
      CrBlock[I, J] := MCU.Cr[I, J];
    End;
End;

Function JPEG_GetSubsampMCUWidth: Integer;
{ Retourne la largeur du MCU en pixels }
Begin
  JPEG_GetSubsampMCUWidth := JPEG_SubsampConfig.MCUWidth;
End;

Function JPEG_GetSubsampMCUHeight: Integer;
{ Retourne la hauteur du MCU en pixels }
Begin
  JPEG_GetSubsampMCUHeight := JPEG_SubsampConfig.MCUHeight;
End;

{ === Fonctions d'acces pour le module sous-echantillonnage (Partie 9) === }

Function JPEG_IsSubsampInitialized: Boolean;
Begin
  JPEG_IsSubsampInitialized := JPEG_SubsampInitialized;
End;

Function JPEG_GetSubsampMode: Integer;
Begin
  JPEG_GetSubsampMode := JPEG_SubsampConfig.Mode;
End;

Function JPEG_GetSubsampHorizFactor: Integer;
Begin
  JPEG_GetSubsampHorizFactor := JPEG_SubsampConfig.HorizFactor;
End;

Function JPEG_GetSubsampVertFactor: Integer;
Begin
  JPEG_GetSubsampVertFactor := JPEG_SubsampConfig.VertFactor;
End;

Function JPEG_GetSubsampYBlocksPerMCU: Integer;
Begin
  JPEG_GetSubsampYBlocksPerMCU := JPEG_SubsampConfig.YBlocksPerMCU;
End;

Function JPEG_GetSubsampMCUsProcessed: LongInt;
Begin
  JPEG_GetSubsampMCUsProcessed := JPEG_SubsampStats.MCUsProcessed;
End;

Function JPEG_GetSubsampYBlocksOutput: LongInt;
Begin
  JPEG_GetSubsampYBlocksOutput := JPEG_SubsampStats.YBlocksOutput;
End;

Function JPEG_GetSubsampCbBlocksOutput: LongInt;
Begin
  JPEG_GetSubsampCbBlocksOutput := JPEG_SubsampStats.CbBlocksOutput;
End;

Function JPEG_GetSubsampCrBlocksOutput: LongInt;
Begin
  JPEG_GetSubsampCrBlocksOutput := JPEG_SubsampStats.CrBlocksOutput;
End;

Function JPEG_GetSubsampModeName(Mode: Integer): String;
Begin
  Case Mode Of
    JPEG_SUBSAMP_444: JPEG_GetSubsampModeName := '4:4:4';
    JPEG_SUBSAMP_422: JPEG_GetSubsampModeName := '4:2:2';
    JPEG_SUBSAMP_420: JPEG_GetSubsampModeName := '4:2:0';
    JPEG_SUBSAMP_411: JPEG_GetSubsampModeName := '4:1:1';
  Else
    JPEG_GetSubsampModeName := 'Unknown';
  End;
End;

{ ============================================================
   GENERATEUR JPEG INTEGRE - PARTIE 10
   Procedures pour l'ecriture de la structure du fichier JPEG
  ============================================================ }

Procedure JPEG_InitEncoder(Quality: Integer; SubsampMode: Integer);
{ Initialise l'encodeur JPEG complet }
Begin
  { Initialiser tous les modules }
  If Not JPEG_DCTInitialized Then JPEG_InitCosTable;
  If Not JPEG_ZigzagInitialized Then JPEG_InitZigzagTable;
  If Not JPEG_RLEInitialized Then JPEG_InitRLE;
  If Not JPEG_HuffInitialized Then JPEG_InitHuffman;
  If Not JPEG_ColorInitialized Then JPEG_InitColorConversion;
  If Not JPEG_SubsampInitialized Then JPEG_InitSubsampling(SubsampMode);
  
  { Configurer l'etat de l'encodeur }
  JPEG_EncoderState.Quality := Quality;
  If (JPEG_EncoderState.Quality < 1) Then JPEG_EncoderState.Quality := 1;
  If (JPEG_EncoderState.Quality > 100) Then JPEG_EncoderState.Quality := 100;
  
  JPEG_EncoderState.SubsampMode := SubsampMode;
  JPEG_EncoderState.LastDC_Y := 0;
  JPEG_EncoderState.LastDC_Cb := 0;
  JPEG_EncoderState.LastDC_Cr := 0;
  JPEG_EncoderState.MCUsEncoded := 0;
  JPEG_EncoderState.BytesWritten := 0;
  JPEG_EncoderState.Initialized := True;
  
  { Initialiser les statistiques }
  JPEG_EncodeStats.TotalMCUs := 0;
  JPEG_EncodeStats.TotalBlocks := 0;
  JPEG_EncodeStats.TotalBytes := 0;
  JPEG_EncodeStats.HeaderBytes := 0;
  JPEG_EncodeStats.DataBytes := 0;
  JPEG_EncodeStats.CompressionRatio := 0.0;
  
  JPEG_FileOpen := False;
End;

Procedure JPEG_WriteByteToFile(B: Byte);
{ Ecrit un octet dans le fichier JPEG }
Begin
  If JPEG_FileOpen Then
  Begin
    BlockWrite(JPEG_OutputFile, B, 1);
    Inc(JPEG_EncoderState.BytesWritten);
  End;
End;

Procedure JPEG_WriteWordToFile(W: Word);
{ Ecrit un mot (big-endian) dans le fichier JPEG }
Begin
  JPEG_WriteByteToFile(Hi(W));
  JPEG_WriteByteToFile(Lo(W));
End;

Procedure JPEG_WriteMarker(Marker: Byte);
{ Ecrit un marqueur JPEG ($FF suivi du marqueur) }
Begin
  JPEG_WriteByteToFile($FF);
  JPEG_WriteByteToFile(Marker);
End;

Procedure JPEG_WriteSOI;
{ Ecrit le marqueur Start Of Image }
Begin
  JPEG_WriteMarker(JPEG_MARKER_SOI);
End;

Procedure JPEG_WriteEOI;
{ Ecrit le marqueur End Of Image }
Begin
  JPEG_WriteMarker(JPEG_MARKER_EOI);
End;

Procedure JPEG_WriteAPP0;
{ Ecrit le segment APP0 (JFIF header) }
Begin
  JPEG_WriteMarker(JPEG_MARKER_APP0);
  JPEG_WriteWordToFile(16);       { Longueur du segment }
  { Identifier: "JFIF" + null }
  JPEG_WriteByteToFile(Ord('J'));
  JPEG_WriteByteToFile(Ord('F'));
  JPEG_WriteByteToFile(Ord('I'));
  JPEG_WriteByteToFile(Ord('F'));
  JPEG_WriteByteToFile(0);
  { Version }
  JPEG_WriteByteToFile(JPEG_JFIF_MAJOR);
  JPEG_WriteByteToFile(JPEG_JFIF_MINOR);
  { Units (0 = aspect ratio) }
  JPEG_WriteByteToFile(JPEG_JFIF_UNITS_NONE);
  { X density }
  JPEG_WriteWordToFile(1);
  { Y density }
  JPEG_WriteWordToFile(1);
  { Thumbnail dimensions }
  JPEG_WriteByteToFile(0);  { Xthumbnail }
  JPEG_WriteByteToFile(0);  { Ythumbnail }
End;

Procedure JPEG_WriteDQT(TableID: Byte; Var QTable: TJPEGQuantTable);
{ Ecrit un segment Define Quantization Table }
Var
  I: Integer;
Begin
  JPEG_WriteMarker(JPEG_MARKER_DQT);
  JPEG_WriteWordToFile(67);       { Longueur: 2 + 1 + 64 }
  { Precision (4 bits) + Table ID (4 bits) }
  JPEG_WriteByteToFile(TableID);  { 0 = 8-bit precision, ID = 0 ou 1 }
  { 64 valeurs de quantification en ordre zigzag }
  For I := 0 To 63 Do
    JPEG_WriteByteToFile(QTable[I]);
End;

Procedure JPEG_WriteSOF0(Width, Height: Word; NumComponents: Byte);
{ Ecrit le segment Start Of Frame (Baseline DCT) }
Begin
  JPEG_WriteMarker(JPEG_MARKER_SOF0);
  { Longueur = 8 + 3*NumComponents }
  JPEG_WriteWordToFile(8 + 3 * NumComponents);
  { Precision (8 bits) }
  JPEG_WriteByteToFile(8);
  { Hauteur et largeur }
  JPEG_WriteWordToFile(Height);
  JPEG_WriteWordToFile(Width);
  { Nombre de composantes }
  JPEG_WriteByteToFile(NumComponents);
  
  If JPEG_EncoderState.SubsampMode = JPEG_SUBSAMP_420 Then
  Begin
    { Y: ID=1, sampling 2x2, QTable 0 }
    JPEG_WriteByteToFile(1);
    JPEG_WriteByteToFile($22);  { 2 horizontal, 2 vertical }
    JPEG_WriteByteToFile(0);
    { Cb: ID=2, sampling 1x1, QTable 1 }
    JPEG_WriteByteToFile(2);
    JPEG_WriteByteToFile($11);  { 1 horizontal, 1 vertical }
    JPEG_WriteByteToFile(1);
    { Cr: ID=3, sampling 1x1, QTable 1 }
    JPEG_WriteByteToFile(3);
    JPEG_WriteByteToFile($11);
    JPEG_WriteByteToFile(1);
  End
  Else  { 4:4:4 }
  Begin
    { Y: ID=1, sampling 1x1, QTable 0 }
    JPEG_WriteByteToFile(1);
    JPEG_WriteByteToFile($11);
    JPEG_WriteByteToFile(0);
    { Cb: ID=2, sampling 1x1, QTable 1 }
    JPEG_WriteByteToFile(2);
    JPEG_WriteByteToFile($11);
    JPEG_WriteByteToFile(1);
    { Cr: ID=3, sampling 1x1, QTable 1 }
    JPEG_WriteByteToFile(3);
    JPEG_WriteByteToFile($11);
    JPEG_WriteByteToFile(1);
  End;
End;

Procedure JPEG_WriteDHT(TableClass, TableID: Byte; 
                         Var Bits: TJPEGHuffBits; 
                         Values: Array Of Byte; ValueCount: Integer);
{ Ecrit un segment Define Huffman Table }
Var
  I: Integer;
Begin
  JPEG_WriteMarker(JPEG_MARKER_DHT);
  { Longueur = 2 + 1 + 16 + ValueCount }
  JPEG_WriteWordToFile(19 + ValueCount);
  { Table class (4 bits) + Table ID (4 bits) }
  { Class: 0=DC, 1=AC }
  JPEG_WriteByteToFile((TableClass Shl 4) Or TableID);
  { 16 octets BITS }
  For I := 0 To 15 Do
    JPEG_WriteByteToFile(Bits[I]);
  { Valeurs HUFFVAL }
  For I := 0 To ValueCount - 1 Do
    JPEG_WriteByteToFile(Values[I]);
End;

Procedure JPEG_WriteSOS(NumComponents: Byte);
{ Ecrit le segment Start Of Scan }
Begin
  JPEG_WriteMarker(JPEG_MARKER_SOS);
  { Longueur = 6 + 2*NumComponents }
  JPEG_WriteWordToFile(6 + 2 * NumComponents);
  { Nombre de composantes dans le scan }
  JPEG_WriteByteToFile(NumComponents);
  { Pour chaque composante: ID + tables DC/AC }
  { Y: ID=1, DC table 0, AC table 0 }
  JPEG_WriteByteToFile(1);
  JPEG_WriteByteToFile($00);
  { Cb: ID=2, DC table 1, AC table 1 }
  JPEG_WriteByteToFile(2);
  JPEG_WriteByteToFile($11);
  { Cr: ID=3, DC table 1, AC table 1 }
  JPEG_WriteByteToFile(3);
  JPEG_WriteByteToFile($11);
  { Spectral selection start }
  JPEG_WriteByteToFile(0);
  { Spectral selection end }
  JPEG_WriteByteToFile(63);
  { Successive approximation }
  JPEG_WriteByteToFile(0);
End;

Procedure JPEG_WriteComment(Comment: String);
{ Ecrit un segment commentaire }
Var
  I, Len: Integer;
Begin
  Len := Length(Comment);
  If Len > 0 Then
  Begin
    JPEG_WriteMarker(JPEG_MARKER_COM);
    JPEG_WriteWordToFile(2 + Len);
    For I := 1 To Len Do
      JPEG_WriteByteToFile(Ord(Comment[I]));
  End;
End;

Procedure JPEG_FlushBitBufferToFile;
{ Ecrit le contenu du buffer de bits dans le fichier }
Var
  I: Integer;
Begin
  For I := 0 To JPEG_BitBuffer.ByteCount - 1 Do
    JPEG_WriteByteToFile(JPEG_BitBuffer.ByteBuffer[I]);
  JPEG_BitBuffer.ByteCount := 0;
End;

Procedure JPEG_OpenOutputFile(Filename: String);
{ Ouvre le fichier de sortie JPEG }
Begin
  Assign(JPEG_OutputFile, Filename);
  {$I-}
  Rewrite(JPEG_OutputFile, 1);
  {$I+}
  If IOResult = 0 Then
    JPEG_FileOpen := True
  Else
    JPEG_FileOpen := False;
End;

Procedure JPEG_CloseOutputFile;
{ Ferme le fichier de sortie JPEG }
Begin
  If JPEG_FileOpen Then
  Begin
    Close(JPEG_OutputFile);
    JPEG_FileOpen := False;
  End;
End;

Function JPEG_ScaleQuantTable(Var SrcTable: TJPEGQuantTable;
                               Var DstTable: TJPEGQuantTable;
                               Quality: Integer): Boolean;
{ Ajuste une table de quantification selon la qualite }
Var
  I: Integer;
  Scale: Real;
  Val: Integer;
Begin
  { Calculer le facteur d'echelle }
  If Quality < 50 Then
    Scale := 5000 / Quality
  Else
    Scale := 200 - Quality * 2;
    
  Scale := Scale / 100.0;
  
  For I := 0 To 63 Do
  Begin
    Val := Round(SrcTable[I] * Scale);
    If Val < 1 Then Val := 1;
    If Val > 255 Then Val := 255;
    DstTable[I] := Val;
  End;
  
  JPEG_ScaleQuantTable := True;
End;

Function JPEG_GetEncoderQuality: Integer;
Begin
  JPEG_GetEncoderQuality := JPEG_EncoderState.Quality;
End;

Function JPEG_GetEncoderBytesWritten: LongInt;
Begin
  JPEG_GetEncoderBytesWritten := JPEG_EncoderState.BytesWritten;
End;

Procedure JPEG_WriteAllDHTTables;
{ Ecrit les 4 tables Huffman standard (DC Lum, DC Chr, AC Lum, AC Chr) }
Var
  DCLumBits, DCChrBits: TJPEGHuffBits;
  ACLumBits, ACChrBits: TJPEGHuffBits;
  DCLumVals: Array[0..11] Of Byte;
  DCChrVals: Array[0..11] Of Byte;
  ACLumVals: Array[0..161] Of Byte;
  ACChrVals: Array[0..161] Of Byte;
  I: Integer;
Begin
  { Initialiser les tableaux BITS DC Luminance }
  DCLumBits[0] := JPEG_DC_LUM_BITS_00; DCLumBits[1] := JPEG_DC_LUM_BITS_01;
  DCLumBits[2] := JPEG_DC_LUM_BITS_02; DCLumBits[3] := JPEG_DC_LUM_BITS_03;
  DCLumBits[4] := JPEG_DC_LUM_BITS_04; DCLumBits[5] := JPEG_DC_LUM_BITS_05;
  DCLumBits[6] := JPEG_DC_LUM_BITS_06; DCLumBits[7] := JPEG_DC_LUM_BITS_07;
  DCLumBits[8] := JPEG_DC_LUM_BITS_08; DCLumBits[9] := JPEG_DC_LUM_BITS_09;
  DCLumBits[10] := JPEG_DC_LUM_BITS_10; DCLumBits[11] := JPEG_DC_LUM_BITS_11;
  DCLumBits[12] := JPEG_DC_LUM_BITS_12; DCLumBits[13] := JPEG_DC_LUM_BITS_13;
  DCLumBits[14] := JPEG_DC_LUM_BITS_14; DCLumBits[15] := JPEG_DC_LUM_BITS_15;
  
  { Initialiser les valeurs DC Luminance }
  DCLumVals[0] := JPEG_DC_LUM_VAL_00; DCLumVals[1] := JPEG_DC_LUM_VAL_01;
  DCLumVals[2] := JPEG_DC_LUM_VAL_02; DCLumVals[3] := JPEG_DC_LUM_VAL_03;
  DCLumVals[4] := JPEG_DC_LUM_VAL_04; DCLumVals[5] := JPEG_DC_LUM_VAL_05;
  DCLumVals[6] := JPEG_DC_LUM_VAL_06; DCLumVals[7] := JPEG_DC_LUM_VAL_07;
  DCLumVals[8] := JPEG_DC_LUM_VAL_08; DCLumVals[9] := JPEG_DC_LUM_VAL_09;
  DCLumVals[10] := JPEG_DC_LUM_VAL_10; DCLumVals[11] := JPEG_DC_LUM_VAL_11;
  
  { Initialiser les tableaux BITS DC Chrominance }
  DCChrBits[0] := JPEG_DC_CHR_BITS_00; DCChrBits[1] := JPEG_DC_CHR_BITS_01;
  DCChrBits[2] := JPEG_DC_CHR_BITS_02; DCChrBits[3] := JPEG_DC_CHR_BITS_03;
  DCChrBits[4] := JPEG_DC_CHR_BITS_04; DCChrBits[5] := JPEG_DC_CHR_BITS_05;
  DCChrBits[6] := JPEG_DC_CHR_BITS_06; DCChrBits[7] := JPEG_DC_CHR_BITS_07;
  DCChrBits[8] := JPEG_DC_CHR_BITS_08; DCChrBits[9] := JPEG_DC_CHR_BITS_09;
  DCChrBits[10] := JPEG_DC_CHR_BITS_10; DCChrBits[11] := JPEG_DC_CHR_BITS_11;
  DCChrBits[12] := JPEG_DC_CHR_BITS_12; DCChrBits[13] := JPEG_DC_CHR_BITS_13;
  DCChrBits[14] := JPEG_DC_CHR_BITS_14; DCChrBits[15] := JPEG_DC_CHR_BITS_15;
  
  { Initialiser les valeurs DC Chrominance }
  DCChrVals[0] := JPEG_DC_CHR_VAL_00; DCChrVals[1] := JPEG_DC_CHR_VAL_01;
  DCChrVals[2] := JPEG_DC_CHR_VAL_02; DCChrVals[3] := JPEG_DC_CHR_VAL_03;
  DCChrVals[4] := JPEG_DC_CHR_VAL_04; DCChrVals[5] := JPEG_DC_CHR_VAL_05;
  DCChrVals[6] := JPEG_DC_CHR_VAL_06; DCChrVals[7] := JPEG_DC_CHR_VAL_07;
  DCChrVals[8] := JPEG_DC_CHR_VAL_08; DCChrVals[9] := JPEG_DC_CHR_VAL_09;
  DCChrVals[10] := JPEG_DC_CHR_VAL_10; DCChrVals[11] := JPEG_DC_CHR_VAL_11;
  
  { Initialiser les tableaux BITS AC Luminance }
  ACLumBits[0] := JPEG_AC_LUM_BITS_01; ACLumBits[1] := JPEG_AC_LUM_BITS_02;
  ACLumBits[2] := JPEG_AC_LUM_BITS_03; ACLumBits[3] := JPEG_AC_LUM_BITS_04;
  ACLumBits[4] := JPEG_AC_LUM_BITS_05; ACLumBits[5] := JPEG_AC_LUM_BITS_06;
  ACLumBits[6] := JPEG_AC_LUM_BITS_07; ACLumBits[7] := JPEG_AC_LUM_BITS_08;
  ACLumBits[8] := JPEG_AC_LUM_BITS_09; ACLumBits[9] := JPEG_AC_LUM_BITS_10;
  ACLumBits[10] := JPEG_AC_LUM_BITS_11; ACLumBits[11] := JPEG_AC_LUM_BITS_12;
  ACLumBits[12] := JPEG_AC_LUM_BITS_13; ACLumBits[13] := JPEG_AC_LUM_BITS_14;
  ACLumBits[14] := JPEG_AC_LUM_BITS_15; ACLumBits[15] := JPEG_AC_LUM_BITS_16;
  
  { Initialiser les valeurs AC Luminance (162 valeurs) }
  For I := 0 To 161 Do
    ACLumVals[I] := 0;
  { Les premieres valeurs AC Lum }
  ACLumVals[0] := $01; ACLumVals[1] := $02;
  ACLumVals[2] := $03;
  ACLumVals[3] := $00; ACLumVals[4] := $04; ACLumVals[5] := $11;
  ACLumVals[6] := $05; ACLumVals[7] := $12; ACLumVals[8] := $21;
  ACLumVals[9] := $31; ACLumVals[10] := $41;
  ACLumVals[11] := $06; ACLumVals[12] := $13; ACLumVals[13] := $51; ACLumVals[14] := $61;
  ACLumVals[15] := $07; ACLumVals[16] := $22; ACLumVals[17] := $71;
  ACLumVals[18] := $14; ACLumVals[19] := $32; ACLumVals[20] := $81; ACLumVals[21] := $91; ACLumVals[22] := $A1;
  ACLumVals[23] := $08; ACLumVals[24] := $23; ACLumVals[25] := $42; ACLumVals[26] := $B1; ACLumVals[27] := $C1;
  ACLumVals[28] := $15; ACLumVals[29] := $52; ACLumVals[30] := $D1; ACLumVals[31] := $F0;
  ACLumVals[32] := $24; ACLumVals[33] := $33; ACLumVals[34] := $62; ACLumVals[35] := $72;
  
  { Initialiser les tableaux BITS AC Chrominance }
  ACChrBits[0] := JPEG_AC_CHR_BITS_01; ACChrBits[1] := JPEG_AC_CHR_BITS_02;
  ACChrBits[2] := JPEG_AC_CHR_BITS_03; ACChrBits[3] := JPEG_AC_CHR_BITS_04;
  ACChrBits[4] := JPEG_AC_CHR_BITS_05; ACChrBits[5] := JPEG_AC_CHR_BITS_06;
  ACChrBits[6] := JPEG_AC_CHR_BITS_07; ACChrBits[7] := JPEG_AC_CHR_BITS_08;
  ACChrBits[8] := JPEG_AC_CHR_BITS_09; ACChrBits[9] := JPEG_AC_CHR_BITS_10;
  ACChrBits[10] := JPEG_AC_CHR_BITS_11; ACChrBits[11] := JPEG_AC_CHR_BITS_12;
  ACChrBits[12] := JPEG_AC_CHR_BITS_13; ACChrBits[13] := JPEG_AC_CHR_BITS_14;
  ACChrBits[14] := JPEG_AC_CHR_BITS_15; ACChrBits[15] := JPEG_AC_CHR_BITS_16;
  
  { Initialiser les valeurs AC Chrominance (162 valeurs) }
  For I := 0 To 161 Do
    ACChrVals[I] := 0;
  { Les premieres valeurs AC Chr }
  ACChrVals[0] := $00; ACChrVals[1] := $01;
  ACChrVals[2] := $02;
  ACChrVals[3] := $03; ACChrVals[4] := $11;
  ACChrVals[5] := $04; ACChrVals[6] := $05; ACChrVals[7] := $21; ACChrVals[8] := $31;
  ACChrVals[9] := $06; ACChrVals[10] := $12; ACChrVals[11] := $41; ACChrVals[12] := $51;
  ACChrVals[13] := $07; ACChrVals[14] := $61; ACChrVals[15] := $71;
  ACChrVals[16] := $13; ACChrVals[17] := $22; ACChrVals[18] := $32; ACChrVals[19] := $81;
  
  { Ecrire les 4 tables DHT }
  JPEG_WriteDHT(0, 0, DCLumBits, DCLumVals, 12);   { DC Luminance (class 0, ID 0) }
  JPEG_WriteDHT(1, 0, ACLumBits, ACLumVals, 162);  { AC Luminance (class 1, ID 0) }
  JPEG_WriteDHT(0, 1, DCChrBits, DCChrVals, 12);   { DC Chrominance (class 0, ID 1) }
  JPEG_WriteDHT(1, 1, ACChrBits, ACChrVals, 162);  { AC Chrominance (class 1, ID 1) }
End;

Procedure JPEG_WriteDataByteStuffed(B: Byte);
{ Ecrit un octet de donnees avec byte stuffing ($FF -> $FF $00) }
Begin
  JPEG_WriteByteToFile(B);
  If B = $FF Then
    JPEG_WriteByteToFile($00);  { Byte stuffing }
End;

Procedure JPEG_WriteJPEGHeader(Width, Height: Word; Quality: Integer);
{ Ecrit l'en-tete complet du fichier JPEG }
Var
  QLumTable, QChrTable: TJPEGQuantTable;
  BaseLumTable, BaseChrTable: TJPEGQuantTable;
  I: Integer;
Begin
  { Creer les tables de base (ordre zigzag) }
  BaseLumTable[0] := JPEG_QL_00; BaseLumTable[1] := JPEG_QL_01;
  BaseLumTable[2] := JPEG_QL_02; BaseLumTable[3] := JPEG_QL_03;
  BaseLumTable[4] := JPEG_QL_04; BaseLumTable[5] := JPEG_QL_05;
  BaseLumTable[6] := JPEG_QL_06; BaseLumTable[7] := JPEG_QL_07;
  BaseLumTable[8] := JPEG_QL_08; BaseLumTable[9] := JPEG_QL_09;
  BaseLumTable[10] := JPEG_QL_10; BaseLumTable[11] := JPEG_QL_11;
  BaseLumTable[12] := JPEG_QL_12; BaseLumTable[13] := JPEG_QL_13;
  BaseLumTable[14] := JPEG_QL_14; BaseLumTable[15] := JPEG_QL_15;
  BaseLumTable[16] := JPEG_QL_16; BaseLumTable[17] := JPEG_QL_17;
  BaseLumTable[18] := JPEG_QL_18; BaseLumTable[19] := JPEG_QL_19;
  BaseLumTable[20] := JPEG_QL_20; BaseLumTable[21] := JPEG_QL_21;
  BaseLumTable[22] := JPEG_QL_22; BaseLumTable[23] := JPEG_QL_23;
  BaseLumTable[24] := JPEG_QL_24; BaseLumTable[25] := JPEG_QL_25;
  BaseLumTable[26] := JPEG_QL_26; BaseLumTable[27] := JPEG_QL_27;
  BaseLumTable[28] := JPEG_QL_28; BaseLumTable[29] := JPEG_QL_29;
  BaseLumTable[30] := JPEG_QL_30; BaseLumTable[31] := JPEG_QL_31;
  BaseLumTable[32] := JPEG_QL_32; BaseLumTable[33] := JPEG_QL_33;
  BaseLumTable[34] := JPEG_QL_34; BaseLumTable[35] := JPEG_QL_35;
  BaseLumTable[36] := JPEG_QL_36; BaseLumTable[37] := JPEG_QL_37;
  BaseLumTable[38] := JPEG_QL_38; BaseLumTable[39] := JPEG_QL_39;
  BaseLumTable[40] := JPEG_QL_40; BaseLumTable[41] := JPEG_QL_41;
  BaseLumTable[42] := JPEG_QL_42; BaseLumTable[43] := JPEG_QL_43;
  BaseLumTable[44] := JPEG_QL_44; BaseLumTable[45] := JPEG_QL_45;
  BaseLumTable[46] := JPEG_QL_46; BaseLumTable[47] := JPEG_QL_47;
  BaseLumTable[48] := JPEG_QL_48; BaseLumTable[49] := JPEG_QL_49;
  BaseLumTable[50] := JPEG_QL_50; BaseLumTable[51] := JPEG_QL_51;
  BaseLumTable[52] := JPEG_QL_52; BaseLumTable[53] := JPEG_QL_53;
  BaseLumTable[54] := JPEG_QL_54; BaseLumTable[55] := JPEG_QL_55;
  BaseLumTable[56] := JPEG_QL_56; BaseLumTable[57] := JPEG_QL_57;
  BaseLumTable[58] := JPEG_QL_58; BaseLumTable[59] := JPEG_QL_59;
  BaseLumTable[60] := JPEG_QL_60; BaseLumTable[61] := JPEG_QL_61;
  BaseLumTable[62] := JPEG_QL_62; BaseLumTable[63] := JPEG_QL_63;
  
  BaseChrTable[0] := JPEG_QC_00; BaseChrTable[1] := JPEG_QC_01;
  BaseChrTable[2] := JPEG_QC_02; BaseChrTable[3] := JPEG_QC_03;
  BaseChrTable[4] := JPEG_QC_04; BaseChrTable[5] := JPEG_QC_05;
  BaseChrTable[6] := JPEG_QC_06; BaseChrTable[7] := JPEG_QC_07;
  BaseChrTable[8] := JPEG_QC_08; BaseChrTable[9] := JPEG_QC_09;
  BaseChrTable[10] := JPEG_QC_10; BaseChrTable[11] := JPEG_QC_11;
  BaseChrTable[12] := JPEG_QC_12; BaseChrTable[13] := JPEG_QC_13;
  BaseChrTable[14] := JPEG_QC_14; BaseChrTable[15] := JPEG_QC_15;
  BaseChrTable[16] := JPEG_QC_16; BaseChrTable[17] := JPEG_QC_17;
  BaseChrTable[18] := JPEG_QC_18; BaseChrTable[19] := JPEG_QC_19;
  BaseChrTable[20] := JPEG_QC_20; BaseChrTable[21] := JPEG_QC_21;
  BaseChrTable[22] := JPEG_QC_22; BaseChrTable[23] := JPEG_QC_23;
  BaseChrTable[24] := JPEG_QC_24; BaseChrTable[25] := JPEG_QC_25;
  BaseChrTable[26] := JPEG_QC_26; BaseChrTable[27] := JPEG_QC_27;
  BaseChrTable[28] := JPEG_QC_28; BaseChrTable[29] := JPEG_QC_29;
  BaseChrTable[30] := JPEG_QC_30; BaseChrTable[31] := JPEG_QC_31;
  BaseChrTable[32] := JPEG_QC_32; BaseChrTable[33] := JPEG_QC_33;
  BaseChrTable[34] := JPEG_QC_34; BaseChrTable[35] := JPEG_QC_35;
  BaseChrTable[36] := JPEG_QC_36; BaseChrTable[37] := JPEG_QC_37;
  BaseChrTable[38] := JPEG_QC_38; BaseChrTable[39] := JPEG_QC_39;
  BaseChrTable[40] := JPEG_QC_40; BaseChrTable[41] := JPEG_QC_41;
  BaseChrTable[42] := JPEG_QC_42; BaseChrTable[43] := JPEG_QC_43;
  BaseChrTable[44] := JPEG_QC_44; BaseChrTable[45] := JPEG_QC_45;
  BaseChrTable[46] := JPEG_QC_46; BaseChrTable[47] := JPEG_QC_47;
  BaseChrTable[48] := JPEG_QC_48; BaseChrTable[49] := JPEG_QC_49;
  BaseChrTable[50] := JPEG_QC_50; BaseChrTable[51] := JPEG_QC_51;
  BaseChrTable[52] := JPEG_QC_52; BaseChrTable[53] := JPEG_QC_53;
  BaseChrTable[54] := JPEG_QC_54; BaseChrTable[55] := JPEG_QC_55;
  BaseChrTable[56] := JPEG_QC_56; BaseChrTable[57] := JPEG_QC_57;
  BaseChrTable[58] := JPEG_QC_58; BaseChrTable[59] := JPEG_QC_59;
  BaseChrTable[60] := JPEG_QC_60; BaseChrTable[61] := JPEG_QC_61;
  BaseChrTable[62] := JPEG_QC_62; BaseChrTable[63] := JPEG_QC_63;
  
  { Ajuster les tables selon la qualite }
  JPEG_ScaleQuantTable(BaseLumTable, QLumTable, Quality);
  JPEG_ScaleQuantTable(BaseChrTable, QChrTable, Quality);
  
  { Ecrire les segments de l'en-tete }
  JPEG_WriteSOI;                         { Start Of Image }
  JPEG_WriteAPP0;                        { JFIF header }
  JPEG_WriteComment('DOXYGEN');          { Commentaire generateur }
  JPEG_WriteDQT(0, QLumTable);           { Table quantification Y }
  JPEG_WriteDQT(1, QChrTable);           { Table quantification CbCr }
  JPEG_WriteSOF0(Width, Height, 3);      { Frame header (3 composantes YCbCr) }
  JPEG_WriteAllDHTTables;                { Tables Huffman (DC/AC Lum/Chr) }
  JPEG_WriteSOS(3);                      { Start Of Scan }
  
  { Enregistrer la taille de l'en-tete }
  JPEG_EncodeStats.HeaderBytes := JPEG_EncoderState.BytesWritten;
End;

Function JPEG_BeginEncode(Filename: String; Width, Height: Word;
                          Quality, SubsampMode: Integer): Boolean;
{ Commence l'encodage d'une image JPEG }
Begin
  { Initialiser l'encodeur }
  JPEG_InitEncoder(Quality, SubsampMode);
  
  { Ouvrir le fichier de sortie }
  JPEG_OpenOutputFile(Filename);
  If Not JPEG_FileOpen Then
  Begin
    JPEG_BeginEncode := False;
    Exit;
  End;
  
  { Ecrire l'en-tete JPEG }
  JPEG_WriteJPEGHeader(Width, Height, Quality);
  
  JPEG_BeginEncode := True;
End;

Function JPEG_EndEncode: Boolean;
{ Termine l'encodage d'une image JPEG }
Var
  I: Integer;
Begin
  If Not JPEG_FileOpen Then
  Begin
    JPEG_EndEncode := False;
    Exit;
  End;
  
  { Vider le buffer de bits avec padding }
  If JPEG_BitBuffer.BitCount > 0 Then
  Begin
    { Padding avec des 1 pour completer l'octet }
    While JPEG_BitBuffer.BitCount < 8 Do
    Begin
      JPEG_BitBuffer.Buffer := (JPEG_BitBuffer.Buffer Shl 1) Or 1;
      Inc(JPEG_BitBuffer.BitCount);
    End;
    { Ajouter l'octet au buffer }
    JPEG_BitBuffer.ByteBuffer[JPEG_BitBuffer.ByteCount] := JPEG_BitBuffer.Buffer And $FF;
    Inc(JPEG_BitBuffer.ByteCount);
    JPEG_BitBuffer.BitCount := 0;
    JPEG_BitBuffer.Buffer := 0;
  End;
  
  { Ecrire le buffer de bits avec byte stuffing }
  For I := 0 To JPEG_BitBuffer.ByteCount - 1 Do
    JPEG_WriteDataByteStuffed(JPEG_BitBuffer.ByteBuffer[I]);
  JPEG_BitBuffer.ByteCount := 0;
  
  { Ecrire le marqueur de fin }
  JPEG_WriteEOI;
  
  { Calculer les statistiques finales }
  JPEG_EncodeStats.TotalBytes := JPEG_EncoderState.BytesWritten;
  JPEG_EncodeStats.DataBytes := JPEG_EncodeStats.TotalBytes - JPEG_EncodeStats.HeaderBytes;
  
  { Fermer le fichier }
  JPEG_CloseOutputFile;
  
  JPEG_EndEncode := True;
End;

Function JPEG_GetFileStructureDescription: String;
{ Retourne une description de la structure du fichier JPEG }
Begin
  JPEG_GetFileStructureDescription := 
    'SOI -> APP0(JFIF) -> COM -> DQT(Y) -> DQT(CbCr) -> SOF0 -> DHT(DC/AC) -> SOS -> [Data] -> EOI';
End;

Function JPEG_GetMarkerName(Marker: Byte): String;
{ Retourne le nom d'un marqueur JPEG }
Begin
  Case Marker Of
    JPEG_MARKER_SOI:  JPEG_GetMarkerName := 'SOI (Start Of Image)';
    JPEG_MARKER_EOI:  JPEG_GetMarkerName := 'EOI (End Of Image)';
    JPEG_MARKER_APP0: JPEG_GetMarkerName := 'APP0 (JFIF Header)';
    JPEG_MARKER_DQT:  JPEG_GetMarkerName := 'DQT (Define Quantization Table)';
    JPEG_MARKER_SOF0: JPEG_GetMarkerName := 'SOF0 (Start Of Frame - Baseline)';
    JPEG_MARKER_DHT:  JPEG_GetMarkerName := 'DHT (Define Huffman Table)';
    JPEG_MARKER_SOS:  JPEG_GetMarkerName := 'SOS (Start Of Scan)';
    JPEG_MARKER_DRI:  JPEG_GetMarkerName := 'DRI (Define Restart Interval)';
    JPEG_MARKER_RST0: JPEG_GetMarkerName := 'RST0 (Restart Marker 0)';
    JPEG_MARKER_COM:  JPEG_GetMarkerName := 'COM (Comment)';
  Else
    JPEG_GetMarkerName := 'Unknown Marker';
  End;
End;

Function JPEG_GetNumDHTTables: Integer;
{ Retourne le nombre de tables DHT standard }
Begin
  JPEG_GetNumDHTTables := 4;  { DC Lum, AC Lum, DC Chr, AC Chr }
End;

Function JPEG_GetNumDQTTables: Integer;
{ Retourne le nombre de tables DQT standard }
Begin
  JPEG_GetNumDQTTables := 2;  { Luminance, Chrominance }
End;

Function JPEG_GetHeaderSize: LongInt;
{ Retourne la taille de l'en-tete en octets }
Begin
  JPEG_GetHeaderSize := JPEG_EncodeStats.HeaderBytes;
End;

Function JPEG_GetDataSize: LongInt;
{ Retourne la taille des donnees en octets }
Begin
  JPEG_GetDataSize := JPEG_EncodeStats.DataBytes;
End;

{ === Fonctions d'acces pour le module encodeur (Partie 10) === }

Function JPEG_IsEncoderInitialized: Boolean;
Begin
  JPEG_IsEncoderInitialized := JPEG_EncoderState.Initialized;
End;

Function JPEG_IsFileOpen: Boolean;
Begin
  JPEG_IsFileOpen := JPEG_FileOpen;
End;

Function JPEG_GetEncoderSubsampMode: Integer;
Begin
  JPEG_GetEncoderSubsampMode := JPEG_EncoderState.SubsampMode;
End;

Function JPEG_GetEncoderLastDC_Y: Integer;
Begin
  JPEG_GetEncoderLastDC_Y := JPEG_EncoderState.LastDC_Y;
End;

Function JPEG_GetEncoderLastDC_Cb: Integer;
Begin
  JPEG_GetEncoderLastDC_Cb := JPEG_EncoderState.LastDC_Cb;
End;

Function JPEG_GetEncoderLastDC_Cr: Integer;
Begin
  JPEG_GetEncoderLastDC_Cr := JPEG_EncoderState.LastDC_Cr;
End;

Function JPEG_GetEncoderMCUsEncoded: LongInt;
Begin
  JPEG_GetEncoderMCUsEncoded := JPEG_EncoderState.MCUsEncoded;
End;

Function JPEG_GetStatsTotalMCUs: LongInt;
Begin
  JPEG_GetStatsTotalMCUs := JPEG_EncodeStats.TotalMCUs;
End;

Function JPEG_GetStatsTotalBytes: LongInt;
Begin
  JPEG_GetStatsTotalBytes := JPEG_EncodeStats.TotalBytes;
End;

Function JPEG_GetStatsCompressionRatio: Real;
Begin
  JPEG_GetStatsCompressionRatio := JPEG_EncodeStats.CompressionRatio;
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
    { Appliquer l'option SVG si specifiee pour le mode InputFile }
    If Opts.SvgOutput Then
    Begin
      SetConfigOption('HAVE_DOT', 'YES', 0, False);
      SetConfigOption('DOT_IMAGE_FORMAT', 'svg', 0, False);
      If Not Opts.Quiet Then
        WriteLn('Format de sortie SVG active');
    End
    { Appliquer l'option PNG si specifiee pour le mode InputFile }
    Else If Opts.PngOutput Then
    Begin
      SetConfigOption('HAVE_DOT', 'YES', 0, False);
      SetConfigOption('DOT_IMAGE_FORMAT', 'png', 0, False);
      If Not Opts.Quiet Then
        WriteLn('Format de sortie PNG active');
    End
    { Appliquer l'option JPEG si specifiee pour le mode InputFile }
    Else If Opts.JpegOutput Then
    Begin
      SetConfigOption('HAVE_DOT', 'YES', 0, False);
      SetConfigOption('DOT_IMAGE_FORMAT', 'jpeg', 0, False);
      If Not Opts.Quiet Then
        WriteLn('Format de sortie JPEG active');
    End
    { Appliquer l'option Visio si specifiee pour le mode InputFile }
    Else If Opts.VdxOutput Then
    Begin
      SetConfigOption('HAVE_DOT', 'YES', 0, False);
      SetConfigOption('DOT_IMAGE_FORMAT', 'vdx', 0, False);
      If Not Opts.Quiet Then
        WriteLn('Format de sortie Microsoft Visio (VDX) active');
    End;
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
  
  { Appliquer l'option SVG si specifiee en ligne de commande }
  If Opts.SvgOutput Then
  Begin
    SetConfigOption('HAVE_DOT', 'YES', 0, False);
    SetConfigOption('DOT_IMAGE_FORMAT', 'svg', 0, False);
    If Not Opts.Quiet Then
      WriteLn('Format de sortie SVG active');
  End
  { Appliquer l'option PNG si specifiee en ligne de commande }
  Else If Opts.PngOutput Then
  Begin
    SetConfigOption('HAVE_DOT', 'YES', 0, False);
    SetConfigOption('DOT_IMAGE_FORMAT', 'png', 0, False);
    If Not Opts.Quiet Then
      WriteLn('Format de sortie PNG active');
  End
  { Appliquer l'option JPEG si specifiee en ligne de commande }
  Else If Opts.JpegOutput Then
  Begin
    SetConfigOption('HAVE_DOT', 'YES', 0, False);
    SetConfigOption('DOT_IMAGE_FORMAT', 'jpeg', 0, False);
    If Not Opts.Quiet Then
      WriteLn('Format de sortie JPEG active');
  End
  { Appliquer l'option Visio si specifiee en ligne de commande }
  Else If Opts.VdxOutput Then
  Begin
    SetConfigOption('HAVE_DOT', 'YES', 0, False);
    SetConfigOption('DOT_IMAGE_FORMAT', 'vdx', 0, False);
    If Not Opts.Quiet Then
      WriteLn('Format de sortie Microsoft Visio (VDX) active');
  End;
  
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
    WriteLn;
  End
  Else
  Begin
    WriteLn('Fichiers d''entree: ', GetConfigValue('INPUT'));
    WriteLn;
    
    { Traiter les fichiers d'entree et generer la documentation }
    If (GetConfigValue('GENERATE_HTML') = 'YES') Or
       (GetConfigValue('GENERATE_HTML') = 'yes') Or
       (GetConfigValue('GENERATE_HTML') = 'Yes') Or
       (GetConfigValue('GENERATE_HTML') = '') Then
    Begin
      { Traiter le fichier d'entree principal }
      ProcessInputFile(GetConfigValue('INPUT'));
    End
    Else
    Begin
      WriteLn('Generation HTML desactivee dans la configuration.');
      WriteLn('Activez GENERATE_HTML = YES pour generer la documentation.');
    End;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  Run;
End.
